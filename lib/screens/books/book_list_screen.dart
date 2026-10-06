import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/auth_design.dart' show BrandLockup;
import '../../widgets/book_card_widget.dart';
import '../../widgets/books_design.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/home/home_motion.dart';
import '../../widgets/home/premium_banner.dart';
import '../../widgets/sync_indicator_widget.dart';
import 'cash_entry_screen.dart';

enum _BookSort { newest, name, balance }

extension on _BookSort {
  String get label => switch (this) {
    _BookSort.newest => 'Newest first',
    _BookSort.name => 'Name A-Z',
    _BookSort.balance => 'Highest balance',
  };
}

class BookListScreen extends ConsumerStatefulWidget {
  const BookListScreen({super.key});
  @override
  ConsumerState<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends ConsumerState<BookListScreen> {
  final _search = TextEditingController();
  _BookSort _sort = _BookSort.newest;
  bool _dialogOpen = false;
  bool _refreshing = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(booksProvider.notifier).loadBooks();
    } catch (error, stack) {
      AppErrors.report('Refresh cash books', error, stack);
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _editBook([Map<String, dynamic>? book]) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    final creating = book == null;
    Map<String, dynamic>? created;
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BookNameDialog(
          initialName: book?['name'] as String? ?? '',
          creating: creating,
          onSave: (name) async {
            final notifier = ref.read(booksProvider.notifier);
            if (creating) {
              created = await notifier.createBook(name);
              if (created == null) throw AppErrors.session;
            } else {
              if (!await notifier.renameBook(book['id'] as String, name)) {
                throw const AppFailure(
                  'Book not renamed',
                  'Your name is still here. Try again.',
                );
              }
            }
          },
        ),
      );
      if (saved == true && mounted) {
        _search.clear();
        setState(() {});
        AppFeedback.success(
          context,
          creating ? 'Cash book created' : 'Cash book renamed',
          creating && created?['synced'] != true
              ? 'Saved on this device. It will sync when a connection is available.'
              : creating
              ? 'Your new cash book is ready.'
              : 'The new name has been saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _deleteBook(Map<String, dynamic> book) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DeleteBookDialog(
          name: book['name'] as String,
          onDelete: () async {
            if (!await ref
                .read(booksProvider.notifier)
                .deleteBook(book['id'] as String)) {
              throw const AppFailure('Book not deleted', 'Please try again.');
            }
          },
        ),
      );
      if (deleted == true && mounted) {
        AppFeedback.success(
          context,
          'Cash book deleted',
          'The book and its entries have been removed.',
        );
      }
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _openBook(Map<String, dynamic> book) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CashEntryScreen(
          bookId: book['id'] as String,
          bookName: book['name'] as String,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  List<Map<String, dynamic>> _visibleBooks(List<Map<String, dynamic>> books) {
    final query = _search.text.trim().toLowerCase();
    final visible = books
        .where(
          (book) =>
              (book['name'] as String? ?? '').toLowerCase().contains(query),
        )
        .toList();
    DateTime date(Map<String, dynamic> book) =>
        DateTime.tryParse(book['created_at'] as String? ?? '') ??
        DateTime(2000);
    visible.sort((a, b) {
      final comparison = switch (_sort) {
        _BookSort.newest => date(b).compareTo(date(a)),
        _BookSort.name => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
        _BookSort.balance =>
          ((b['balance'] as num?)?.toDouble() ?? 0).compareTo(
            (a['balance'] as num?)?.toDouble() ?? 0,
          ),
      };
      return comparison == 0
          ? (a['id'] as String).compareTo(b['id'] as String)
          : comparison;
    });
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final booksAsync = ref.watch(booksProvider);
    final signedIn = ref.watch(isLoggedInProvider);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final books = booksAsync.asData?.value ?? [];
    final visible = _visibleBooks(books);
    final indexById = {
      for (int i = 0; i < visible.length; i++) visible[i]['id'] as String: i,
    };
    final balance = books.fold<double>(
      0,
      (sum, book) => sum + ((book['balance'] as num?)?.toDouble() ?? 0),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [const Color(0xFF0C1E2C), const Color(0xFF102A3C)]
                  : [
                      brandMist,
                      const Color(0xFFEAF4FB),
                      const Color(0xFFF7FAFD),
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    key: const PageStorageKey('books-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HomeReveal(
                                child: Row(
                                  children: [
                                    const BrandLockup(
                                      size: 46,
                                      showName: false,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'YOUR MONEY, ORGANISED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              letterSpacing: 1.2,
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Cash books',
                                            style: TextStyle(
                                              fontSize: 27,
                                              letterSpacing: -.8,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (signedIn)
                                      IconButton.filledTonal(
                                        tooltip: 'Change currency',
                                        onPressed: () =>
                                            CurrencyPickerWidget.show(context),
                                        icon: const Icon(
                                          Icons.currency_exchange_rounded,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'A space for every part of your life.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (signedIn) const SyncIndicator(),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (signedIn && booksAsync.hasValue) ...[
                                HomeReveal(
                                  order: 1,
                                  child: BooksSummaryCard(
                                    balance: balance / settings.exchangeRate,
                                    symbol: settings.currencySymbol,
                                    count: books.length,
                                  ),
                                ),
                                if (books.isEmpty) const SizedBox(height: 20),
                                if (books.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  TextField(
                                    key: const ValueKey('book-search'),
                                    controller: _search,
                                    onChanged: (_) => setState(() {}),
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText: 'Search cash books',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        size: 22,
                                      ),
                                      suffixIcon: _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear search',
                                              onPressed: () =>
                                                  setState(_search.clear),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _search.text.trim().isEmpty
                                              ? '${books.length} cash ${books.length == 1 ? 'book' : 'books'}'
                                              : '${visible.length} of ${books.length} books',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Refresh cash books',
                                        onPressed: _refreshing
                                            ? null
                                            : _refresh,
                                        icon: _refreshing
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.refresh_rounded,
                                                size: 20,
                                              ),
                                      ),
                                      PopupMenuButton<_BookSort>(
                                        tooltip: 'Sort cash books',
                                        initialValue: _sort,
                                        onSelected: (value) =>
                                            setState(() => _sort = value),
                                        icon: Icon(
                                          Icons.tune_rounded,
                                          color: scheme.primary,
                                          size: 20,
                                        ),
                                        itemBuilder: (_) => [
                                          for (final sort in _BookSort.values)
                                            PopupMenuItem(
                                              value: sort,
                                              child: Text(sort.label),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _sort.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!signedIn)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: BooksEmptyState(
                              title: 'Your books start here',
                              message:
                                  'Sign in to keep your cash books together and track every entry.',
                              actionLabel: 'Sign in to Lankar',
                              onAction: () => context.go(AppRoutes.login),
                              icon: Icons.lock_outline_rounded,
                            ),
                          ),
                        )
                      else if (booksAsync.isLoading && !booksAsync.hasValue)
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: 250,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (booksAsync.hasError)
                        SliverToBoxAdapter(
                          child: AppErrorView(
                            error: booksAsync.error!,
                            onRetry: _refresh,
                          ),
                        )
                      else if (books.isEmpty || visible.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: HomeReveal(
                              order: 2,
                              child: BooksEmptyState(
                                title: books.isEmpty
                                    ? 'Give your money a home'
                                    : 'No matching books',
                                message: books.isEmpty
                                    ? 'Create a cash book for everyday spending, savings, or your next big plan.'
                                    : 'Try another name, or clear your search to see all your cash books.',
                                actionLabel: books.isEmpty
                                    ? 'Create your first book'
                                    : 'Clear search',
                                icon: books.isEmpty
                                    ? Icons.auto_stories_rounded
                                    : Icons.search_rounded,
                                onAction: books.isEmpty
                                    ? () => _editBook()
                                    : () => setState(_search.clear),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final book = visible[index];
                                return HomeReveal(
                                  key: ValueKey(book['id']),
                                  order: 2 + (index < 3 ? index : 2),
                                  child: BookCardWidget(
                                    book: book,
                                    currencySymbol: settings.currencySymbol,
                                    balance:
                                        ((book['balance'] as num?)
                                                ?.toDouble() ??
                                            0) /
                                        settings.exchangeRate,
                                    onTap: () => _openBook(book),
                                    onRename: () => _editBook(book),
                                    onDelete: () => _deleteBook(book),
                                  ),
                                );
                              },
                              childCount: visible.length,
                              findChildIndexCallback: (key) =>
                                  indexById[(key as ValueKey).value],
                            ),
                          ),
                        ),
                      if (signedIn &&
                          booksAsync.hasValue &&
                          _search.text.trim().isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                          sliver: SliverToBoxAdapter(child: PremiumBanner()),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton:
            signedIn && !(booksAsync.hasValue && books.isEmpty)
            ? FloatingActionButton.extended(
                onPressed: _dialogOpen ? null : () => _editBook(),
                tooltip: 'Create cash book',
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'New book',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
      ),
    );
  }
}

class _BookNameDialog extends StatefulWidget {
  const _BookNameDialog({
    required this.initialName,
    required this.creating,
    required this.onSave,
  });
  final String initialName;
  final bool creating;
  final Future<void> Function(String name) onSave;
  @override
  State<_BookNameDialog> createState() => _BookNameDialogState();
}

class _BookNameDialogState extends State<_BookNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false;
  AppFailure? _failure;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final name = _name.text.trim();
      if (!widget.creating && name == widget.initialName.trim()) {
        Navigator.pop(context, false);
        return;
      }
      await widget.onSave(name);
      if (mounted) Navigator.pop(context, true);
    } catch (error, stack) {
      AppErrors.report('Save cash book name', error, stack);
      if (mounted) {
        setState(
          () => _failure = AppErrors.from(
            error,
            fallback: 'Your name is still here. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SculptedIcon(icon: Icons.auto_stories_rounded, size: 42),
          const SizedBox(height: 20),
          Text(
            widget.creating ? 'Create cash book' : 'Rename cash book',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
        ],
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.creating
                  ? 'Choose a name for this part of your money.'
                  : 'Give your cash book a fresh name.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const ValueKey('book-name'),
              controller: _name,
              enabled: !_saving,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a book name'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Book name',
                hintText: 'e.g. Everyday spending',
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 16),
              FeedbackCard(
                title: _failure!.title,
                message: _failure!.message,
                tone: FeedbackTone.error,
                onDismiss: () => setState(() => _failure = null),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.creating ? 'Create book' : 'Save name'),
        ),
      ],
    ),
  );
}

class _DeleteBookDialog extends StatefulWidget {
  const _DeleteBookDialog({required this.name, required this.onDelete});
  final String name;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteBookDialog> createState() => _DeleteBookDialogState();
}

class _DeleteBookDialogState extends State<_DeleteBookDialog> {
  bool _deleting = false;
  AppFailure? _failure;
  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _failure = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context, true);
    } catch (error, stack) {
      AppErrors.report('Delete cash book', error, stack);
      if (mounted) setState(() => _failure = AppErrors.from(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(Icons.delete_outline_rounded, size: 34, color: scheme.error),
        title: Text(
          'Delete "${widget.name}"?',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This removes the cash book and all of its entries. This cannot be undone.',
            ),
            if (_failure != null) ...[
              const SizedBox(height: 16),
              FeedbackCard(
                title: _failure!.title,
                message: _failure!.message,
                tone: FeedbackTone.error,
                onDismiss: () => setState(() => _failure = null),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.pop(context, false),
            child: const Text('Keep book'),
          ),
          ElevatedButton(
            onPressed: _deleting ? null : _delete,
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: _deleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete book'),
          ),
        ],
      ),
    );
  }
}

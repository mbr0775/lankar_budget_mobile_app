import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_errors.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/books_design.dart';
import '../../widgets/cash_book_design.dart';
import '../../widgets/entry_card_widget.dart';
import '../../widgets/entry_dialog_widget.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/home/home_motion.dart';
import '../reports/reports_screen.dart';

class CashEntryScreen extends ConsumerStatefulWidget {
  const CashEntryScreen({
    super.key,
    required this.bookId,
    required this.bookName,
  });
  final String bookId;
  final String bookName;
  @override
  ConsumerState<CashEntryScreen> createState() => _CashEntryScreenState();
}

class _CashEntryScreenState extends ConsumerState<CashEntryScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  bool _modalOpen = false;
  bool _refreshing = false;
  EntriesNotifier get _notifier =>
      ref.read(entriesProvider(widget.bookId).notifier);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _notifier.loadEntries();
    } catch (error, stack) {
      AppErrors.report('Refresh cash entries', error, stack);
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _showEntrySheet({
    required bool isIncome,
    Map<String, dynamic>? existing,
  }) async {
    if (_modalOpen) return;
    setState(() => _modalOpen = true);
    final settings = ref.read(settingsProvider);
    final notifier = _notifier;
    try {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => EntryDialogWidget(
          isIncome: isIncome,
          currencySymbol: settings.currencySymbol,
          exchangeRate: settings.exchangeRate,
          existingEntry: existing,
          isSyncPending: () => notifier.lastSaveNeedsSync,
          onSave:
              ({
                required double amount,
                required String description,
                required bool isIncome,
                required DateTime entryDate,
                String? entryId,
              }) async {
                if (entryId != null) {
                  return notifier.updateEntry(
                    entryId,
                    amount: amount,
                    description: description,
                  );
                }
                return notifier.createEntry(
                  amount: amount,
                  description: description,
                  isIncome: isIncome,
                  entryDate: entryDate,
                );
              },
        ),
      );
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    if (_modalOpen) return;
    setState(() => _modalOpen = true);
    try {
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DeleteEntryDialog(
          description: entry['description'] as String? ?? '',
          onDelete: () async {
            if (!await _notifier.deleteEntry(entry['id'] as String)) {
              throw const AppFailure('Entry not deleted', 'Please try again.');
            }
          },
        ),
      );
      if (deleted == true && mounted) {
        AppFeedback.success(
          context,
          'Entry deleted',
          'Your cash book has been updated.',
        );
      }
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }

  DateTime? _date(Map<String, dynamic> entry) => DateTime.tryParse(
    (entry['entry_date'] ?? entry['created_at']) as String? ?? '',
  );

  String _dayLabel(Map<String, dynamic> entry) {
    final date = _date(entry);
    if (date == null) return 'Undated entries';
    final local = date.toLocal().toIso8601String();
    return getRelativeDate(local) ?? getFormattedDate(local);
  }

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> all) {
    final query = _search.text.trim().toLowerCase();
    final entries = all
        .where(
          (entry) =>
              (_filter == 'All' ||
                  (_filter == 'Income') == (entry['is_income'] == true)) &&
              (entry['description'] as String? ?? '').toLowerCase().contains(
                query,
              ),
        )
        .toList();
    entries.sort((a, b) {
      final dateOrder = (_date(b) ?? DateTime(2000)).compareTo(
        _date(a) ?? DateTime(2000),
      );
      return dateOrder == 0 ? '${a['id']}'.compareTo('${b['id']}') : dateOrder;
    });
    return entries;
  }

  void _reports(
    List<Map<String, dynamic>> entries,
    String symbol,
    double rate,
  ) {
    double sum(bool income) =>
        entries
            .where((e) => e['is_income'] == income)
            .fold<double>(
              0,
              (sum, e) => sum + (e['amount'] as num).toDouble(),
            ) /
        rate;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportsScreen(
          bookId: widget.bookId,
          bookName: widget.bookName,
          entries: entries,
          currencySymbol: symbol,
          totalIn: sum(true),
          totalOut: sum(false),
          balance: sum(true) - sum(false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(entriesProvider(widget.bookId));
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final entries = async.asData?.value ?? [];
    final visible = _visible(entries);
    final indexById = {
      for (int i = 0; i < visible.length; i++) visible[i]['id']: i,
    };
    double total(bool income) =>
        entries
            .where((e) => e['is_income'] == income)
            .fold<double>(
              0,
              (sum, e) => sum + (e['amount'] as num).toDouble(),
            ) /
        settings.exchangeRate;
    final ready = async.hasValue && !async.hasError;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Book overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            tooltip: 'Back to books',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Change currency',
              icon: const Icon(Icons.currency_exchange_rounded),
              onPressed: () => CurrencyPickerWidget.show(context),
            ),
            IconButton(
              tooltip: 'View book report',
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: ready
                  ? () => _reports(
                      entries,
                      settings.currencySymbol,
                      settings.exchangeRate,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: ready
            ? CashActionDock(
                onIncome: () => _showEntrySheet(isIncome: true),
                onExpense: () => _showEntrySheet(isIncome: false),
              )
            : null,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [const Color(0xFF0C1E2C), const Color(0xFF102A3C)]
                  : [
                      const Color(0xFFF5F8FA),
                      const Color(0xFFF3F7FA),
                      const Color(0xFFF5F8FA),
                    ],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    key: PageStorageKey('entries-${widget.bookId}'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HomeReveal(
                                child: Text(
                                  widget.bookName,
                                  style: const TextStyle(
                                    fontSize: 29,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Track your money, one entry at a time.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 22),
                              if (ready) ...[
                                HomeReveal(
                                  order: 1,
                                  child: CashBalanceCard(
                                    symbol: settings.currencySymbol,
                                    income: total(true),
                                    expense: total(false),
                                    count: entries.length,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Activity',
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.4,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${visible.length} ${visible.length == 1 ? 'entry' : 'entries'}',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Refresh entries',
                                      onPressed: _refreshing ? null : _refresh,
                                      icon: _refreshing
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.refresh_rounded,
                                              size: 20,
                                            ),
                                    ),
                                  ],
                                ),
                                if (entries.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  TextField(
                                    key: const ValueKey('entry-search'),
                                    controller: _search,
                                    onChanged: (_) => setState(() {}),
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText: 'Search transactions',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                      ),
                                      suffixIcon: _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear entry search',
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                              onPressed: () =>
                                                  setState(_search.clear),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  CashActivityFilters(
                                    selected: _filter,
                                    onSelected: (filter) =>
                                        setState(() => _filter = filter),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (async.isLoading && !async.hasValue)
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: 250,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (async.hasError)
                        SliverToBoxAdapter(
                          child: AppErrorView(
                            error: async.error!,
                            onRetry: _refresh,
                          ),
                        )
                      else if (visible.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          sliver: SliverToBoxAdapter(
                            child: BooksEmptyState(
                              title: entries.isEmpty
                                  ? 'Start your story'
                                  : 'No matching entries',
                              message: entries.isEmpty
                                  ? 'Record money coming in or going out. Your balance will update with every entry.'
                                  : 'Try another description or show all your entries.',
                              actionLabel: entries.isEmpty
                                  ? 'Add your first income'
                                  : 'Show all entries',
                              icon: Icons.receipt_long_rounded,
                              onAction: entries.isEmpty
                                  ? () => _showEntrySheet(isIncome: true)
                                  : () => setState(() {
                                      _search.clear();
                                      _filter = 'All';
                                    }),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, index) {
                                final entry = visible[index];
                                final label = _dayLabel(entry);
                                return HomeReveal(
                                  key: ValueKey(entry['id']),
                                  order: 2 + (index < 3 ? index : 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (index == 0 ||
                                          label !=
                                              _dayLabel(visible[index - 1]))
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            4,
                                            12,
                                            4,
                                            12,
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      EntryCardWidget(
                                        entry: entry,
                                        currencySymbol: settings.currencySymbol,
                                        displayAmount:
                                            (entry['amount'] as num)
                                                .toDouble() /
                                            settings.exchangeRate,
                                        onEdit: () => _showEntrySheet(
                                          isIncome: entry['is_income'] == true,
                                          existing: entry,
                                        ),
                                        onDelete: () => _confirmDelete(entry),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: visible.length,
                              findChildIndexCallback: (key) =>
                                  indexById[(key as ValueKey).value],
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteEntryDialog extends StatefulWidget {
  const _DeleteEntryDialog({required this.description, required this.onDelete});
  final String description;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteEntryDialog> createState() => _DeleteEntryDialogState();
}

class _DeleteEntryDialogState extends State<_DeleteEntryDialog> {
  bool _saving = false;
  AppFailure? _failure;
  Future<void> _delete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context, true);
    } catch (error, stack) {
      AppErrors.report('Delete cash entry', error, stack);
      if (mounted) setState(() => _failure = AppErrors.from(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete entry?'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.description.trim().isNotEmpty) ...[
              Text(
                widget.description,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'This removes the entry from your cash book and updates its balance. This cannot be undone.',
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
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Keep entry'),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _delete,
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete entry'),
          ),
        ],
      ),
    );
  }
}

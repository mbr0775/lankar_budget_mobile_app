// lib/screens/books/book_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/book_card_widget.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/sync_indicator_widget.dart';
import 'cash_entry_screen.dart';

class BookListScreen extends ConsumerWidget {
  const BookListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings   = ref.watch(settingsProvider);
    final booksAsync = ref.watch(booksProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final symbol     = settings.currencySymbol;
    final rate       = settings.exchangeRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: primaryRed,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryRed, secondaryRed],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.business,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tokilo Technologies',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold)),
                                  Text('Tap to switch business',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.attach_money, color: Colors.white),
                onPressed: () => CurrencyPickerWidget.show(context),
              ),
              const SyncIndicator(),
              const SizedBox(width: 8),
            ],
          ),

          // ── Header ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryRed, secondaryRed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: primaryRed.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Go Premium!',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Unlock all features and sync across devices',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryRed,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Subscribe',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.workspace_premium,
                              color: Colors.white, size: 38),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Books',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.grey[600]),
                            onPressed: () =>
                                ref.read(booksProvider.notifier).loadBooks(),
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.grey[600]),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Book list / empty / logged-out ─────────────────────────────
          booksAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: primaryRed)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
            data: (books) {
              // Not logged in — show sign-in prompt instead of books
              if (!isLoggedIn) {
                return SliverFillRemaining(
                  child: _SignInPrompt(
                    onSignIn: () => context.go(AppRoutes.login),
                  ),
                );
              }

              if (books.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.book_outlined,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No books yet',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Tap + to create your first book',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = books[index];
                      final bal =
                          (book['balance'] as num?)?.toDouble() ?? 0;
                      return BookCardWidget(
                        book:           book,
                        currencySymbol: symbol,
                        balance:        bal / rate,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CashEntryScreen(
                              bookId:   book['id'],
                              bookName: book['name'],
                            ),
                          ),
                        ).then((_) =>
                            ref.read(booksProvider.notifier).loadBooks()),
                        onRename: () => _showRenameDialog(
                            context, ref, book['id'], book['name']),
                        onDelete: () =>
                            _showDeleteDialog(context, ref, book['id']),
                      );
                    },
                    childCount: books.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ── FAB — shows sign-in sheet when logged out ───────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!isLoggedIn) {
            _showSignInRequired(context);
          } else {
            _showCreateBookDialog(context, ref);
          }
        },
        backgroundColor: primaryRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Sign-in required bottom sheet ────────────────────────────────────────
  void _showSignInRequired(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: primaryRed, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Sign in Required',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'You need to sign in to create and manage your cash books.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(AppRoutes.login);
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create / Rename / Delete dialogs ─────────────────────────────────────

  Future<void> _showCreateBookDialog(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _BookNameDialog(
          controller: ctrl,
          title: 'Create New Book',
          actionLabel: 'Create'),
    );
    if (name != null && name.trim().isNotEmpty) {
      final book =
          await ref.read(booksProvider.notifier).createBook(name.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(book != null
              ? 'Book created successfully!'
              : 'Failed to create book. Try again.'),
          backgroundColor: book != null ? primaryRed : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref,
      String bookId, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _BookNameDialog(
          controller: ctrl,
          title: 'Rename Book',
          actionLabel: 'Save'),
    );
    if (name != null &&
        name.trim().isNotEmpty &&
        name.trim() != current) {
      await ref.read(booksProvider.notifier).renameBook(bookId, name.trim());
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, WidgetRef ref, String bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Book'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(booksProvider.notifier).deleteBook(bookId);
    }
  }
}

// ── Sign-in prompt widget (shown in book list when logged out) ────────────

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.book_outlined,
                  size: 40, color: primaryRed),
            ),
            const SizedBox(height: 20),
            const Text('Sign in to see your books',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Create and manage your cash books after signing in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Book name dialog ──────────────────────────────────────────────────────

class _BookNameDialog extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String actionLabel;

  const _BookNameDialog({
    required this.controller,
    required this.title,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.book_outlined, size: 44, color: primaryRed),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
            },
            decoration: InputDecoration(
              hintText: 'Book name',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) Navigator.pop(context, text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
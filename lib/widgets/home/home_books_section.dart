import 'package:flutter/material.dart';
import 'home_book_tile.dart';
import 'home_motion.dart';
import '../../screens/books/cash_entry_screen.dart';

class HomeBooksSection extends StatelessWidget {
  const HomeBooksSection({
    super.key,
    required this.books,
    required this.symbol,
    required this.rate,
    required this.onBookChanged,
    required this.onSeeAll,
  });
  final List<Map<String, dynamic>> books;
  final String symbol;
  final double rate;
  final VoidCallback onBookChanged;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your cash books',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 21,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        if (books.isEmpty)
          DepthButton(
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const SculptedIcon(icon: Icons.add_rounded, size: 48),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start your first cash book',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Give every entry a home.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.primary),
                ],
              ),
            ),
          )
        else
          ...books
              .take(3)
              .map(
                (book) => HomeBookTile(
                  book: book,
                  symbol: symbol,
                  balance: ((book['balance'] as num?)?.toDouble() ?? 0) / rate,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CashEntryScreen(
                          bookId: book['id'] as String,
                          bookName: book['name'] as String,
                        ),
                      ),
                    );
                    if (context.mounted) onBookChanged();
                  },
                ),
              ),
      ],
    );
  }
}

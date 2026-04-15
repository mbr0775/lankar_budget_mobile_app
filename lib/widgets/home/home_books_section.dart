// lib/widgets/home/home_books_section.dart
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'home_book_tile.dart';
import '../../screens/books/cash_entry_screen.dart';

class HomeBooksSection extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final String symbol;
  final double rate;
  final VoidCallback onBookChanged;

  const HomeBooksSection({
    super.key,
    required this.books,
    required this.symbol,
    required this.rate,
    required this.onBookChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Books',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (books.length > 3)
              TextButton(
                onPressed: () {},
                child: const Text(
                  'See all',
                  style: TextStyle(
                      color: primaryRed, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (books.isEmpty)
          _EmptyBooksCard()
        else
          ...books.take(3).map((book) {
            final bal =
                (book['balance'] as num?)?.toDouble() ?? 0;
            return HomeBookTile(
              book:    book,
              symbol:  symbol,
              balance: bal / rate,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CashEntryScreen(
                    bookId:   book['id'] as String,
                    bookName: book['name'] as String,
                  ),
                ),
              ).then((_) => onBookChanged()),
            );
          }),
      ],
    );
  }
}

class _EmptyBooksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.book_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No books yet',
            style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            'Go to Books tab and tap + to create one',
            style: TextStyle(
                color: Colors.grey[400], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
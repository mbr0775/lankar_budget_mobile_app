// lib/screens/reports/reports_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class ReportsTabScreen extends ConsumerStatefulWidget {
  const ReportsTabScreen({super.key});

  @override
  ConsumerState<ReportsTabScreen> createState() => _ReportsTabScreenState();
}

class _ReportsTabScreenState extends ConsumerState<ReportsTabScreen> {
  String? _selectedBookId;
  List<Map<String, dynamic>> _entries   = [];
  bool _loadingEntries = false;

  Future<void> _loadEntries(String bookId) async {
    setState(() { _selectedBookId = bookId; _loadingEntries = true; });
    final entries = await HiveService().getEntries(bookId);
    if (mounted) setState(() { _entries = entries; _loadingEntries = false; });
  }

  double get _totalIncome => _entries
      .where((e) => e['is_income'] == true)
      .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

  double get _totalExpense => _entries
      .where((e) => e['is_income'] == false)
      .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

  double get _netBalance => _totalIncome - _totalExpense;

  Future<void> _exportPdf(String bookName, String symbol, double rate) async {
    final pdf  = pw.Document();
    final now  = DateTime.now();
    final fmtD = '${now.day}/${now.month}/${now.year}';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('$bookName — Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Generated: $fmtD',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.SizedBox(height: 20),
        pw.Row(children: [
          _pdfChip('Total Income',  '$symbol ${formatCurrency(_totalIncome / rate)}', PdfColors.green700),
          pw.SizedBox(width: 16),
          _pdfChip('Total Expense', '$symbol ${formatCurrency(_totalExpense / rate)}', PdfColors.red700),
          pw.SizedBox(width: 16),
          _pdfChip('Net Balance',   '$symbol ${formatCurrency(_netBalance / rate)}',
              _netBalance >= 0 ? PdfColors.green700 : PdfColors.red700),
        ]),
        pw.SizedBox(height: 24),
        pw.Text('Transaction History',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['Description', 'Date', 'Amount', 'Type']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ))
                  .toList(),
            ),
            ..._entries.map((e) {
              final amt    = (e['amount'] as num).toDouble() / rate;
              final isInc  = e['is_income'] as bool;
              final date   = DateTime.tryParse(
                      e['entry_date'] as String? ?? '') ??
                  DateTime.now();
              return pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(e['description'] ?? '',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${date.day}/${date.month}/${date.year}',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('$symbol ${formatCurrency(amt)}',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(isInc ? 'In' : 'Out',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: isInc
                                ? PdfColors.green700
                                : PdfColors.red700))),
              ]);
            }),
          ],
        ),
      ],
    ));

    final bytes   = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final file    = File('${tempDir.path}/${bookName}_report.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Report for $bookName');
  }

  pw.Widget _pdfChip(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style:
                      pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final settings   = ref.watch(settingsProvider);
    final booksAsync = ref.watch(booksProvider);
    final symbol     = settings.currencySymbol;
    final rate       = settings.exchangeRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            floating: false,
            backgroundColor: primaryRed,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryRed, secondaryRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bar_chart_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reports',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text('Charts & PDF export',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (!isLoggedIn)
            SliverFillRemaining(child: _buildSignInPrompt(context))
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: booksAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: primaryRed)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (books) {
                    if (books.isEmpty) {
                      return _buildEmptyBooks();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Book picker ──────────────────────────────────
                        const Text('Select Book',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6C757D),
                                letterSpacing: 0.8)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: books.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final book     = books[i];
                              final selected = book['id'] == _selectedBookId;
                              return GestureDetector(
                                onTap: () => _loadEntries(book['id'] as String),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? primaryRed
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(22),
                                    border: Border.all(
                                      color: selected
                                          ? primaryRed
                                          : Colors.grey.shade300,
                                    ),
                                    boxShadow: selected
                                        ? [BoxShadow(
                                            color: primaryRed.withOpacity(0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3))]
                                        : [],
                                  ),
                                  child: Text(
                                    book['name'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_selectedBookId == null) ...[
                          _buildSelectPrompt(),
                        ] else if (_loadingEntries) ...[
                          const SizedBox(height: 60),
                          const Center(child: CircularProgressIndicator(
                              color: primaryRed)),
                        ] else ...[
                          // ── Summary cards ─────────────────────────────
                          _buildSummaryCards(symbol, rate),
                          const SizedBox(height: 24),

                          // ── Recent transactions ───────────────────────
                          _buildTransactionList(symbol, rate),
                          const SizedBox(height: 24),

                          // ── Export button ─────────────────────────────
                          _buildExportButton(
                              books.firstWhere(
                                      (b) => b['id'] == _selectedBookId)[
                                  'name'] as String,
                              symbol,
                              rate),
                          const SizedBox(height: 100),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(String symbol, double rate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Summary',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C757D),
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Row(children: [
          _SummaryCard(
            label: 'Income',
            value: '$symbol ${formatCurrency(_totalIncome / ref.read(settingsProvider).exchangeRate)}',
            color: incomeGreen,
            icon: Icons.arrow_downward_rounded,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Expense',
            value: '$symbol ${formatCurrency(_totalExpense / ref.read(settingsProvider).exchangeRate)}',
            color: expenseRed,
            icon: Icons.arrow_upward_rounded,
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _netBalance >= 0
                  ? [incomeGreen, incomeGreen.withOpacity(0.7)]
                  : [expenseRed, expenseRed.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: (_netBalance >= 0 ? incomeGreen : expenseRed)
                    .withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net Balance',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              Text(
                '$symbol ${formatCurrency(_netBalance / ref.read(settingsProvider).exchangeRate)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(String symbol, double rate) {
    final recent = _entries.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6C757D),
                    letterSpacing: 0.8)),
            Text('${_entries.length} total',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))],
          ),
          child: Column(
            children: recent.asMap().entries.map((entry) {
              final i     = entry.key;
              final e     = entry.value;
              final isInc = e['is_income'] as bool;
              final amt   = (e['amount'] as num).toDouble() / rate;
              final date  = DateTime.tryParse(
                      e['entry_date'] as String? ?? '') ??
                  DateTime.now();
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isInc ? incomeGreen : expenseRed)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isInc
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: isInc ? incomeGreen : expenseRed,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      e['description'] ?? 'No description',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400]),
                    ),
                    trailing: Text(
                      '${isInc ? '+' : '-'} $symbol ${formatCurrency(amt)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isInc ? incomeGreen : expenseRed,
                      ),
                    ),
                  ),
                  if (i < recent.length - 1)
                    const Divider(height: 1, indent: 56, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton(String bookName, String symbol, double rate) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _exportPdf(bookName, symbol, rate),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
          label: const Text('Export PDF Report',
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
      );

  Widget _buildSelectPrompt() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.touch_app_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Select a book above to view its report',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );

  Widget _buildEmptyBooks() => Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No books yet',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Create a book in the Books tab first',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );

  Widget _buildSignInPrompt(BuildContext context) => Center(
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
                child: const Icon(Icons.bar_chart_rounded,
                    size: 40, color: primaryRed),
              ),
              const SizedBox(height: 20),
              const Text('Sign in to view reports',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Access charts and export PDF reports after signing in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 14, height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.login),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),
      );
}
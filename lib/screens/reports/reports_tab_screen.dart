import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../navigation/main_shell.dart' show selectedTabProvider;
import '../../providers/books_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/report_data.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/books_design.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/reports_design.dart';

class ReportsTabScreen extends ConsumerStatefulWidget {
  const ReportsTabScreen({super.key});
  @override
  ConsumerState<ReportsTabScreen> createState() => _ReportsTabScreenState();
}

class _ReportsTabScreenState extends ConsumerState<ReportsTabScreen> {
  String? _selectedBookId;
  bool _exporting = false;

  Rect _shareOrigin() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _exportPdf(
    String bookName,
    String symbol,
    double rate,
    List<Map<String, dynamic>> entries,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _generatePdf(bookName, symbol, rate, sortedReportEntries(entries));
    } catch (error, stack) {
      AppErrors.report('Export report', error, stack);
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback: 'Could not export your report. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _generatePdf(
    String bookName,
    String symbol,
    double rate,
    List<Map<String, dynamic>> entries,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final fmtD = '${now.day}/${now.month}/${now.year}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            '$bookName - Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: $fmtD',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              _pdfChip(
                'Total Income',
                '$symbol ${formatCurrency(reportTotal(entries, true) / rate)}',
                PdfColors.green700,
              ),
              pw.SizedBox(width: 16),
              _pdfChip(
                'Total Expense',
                '$symbol ${formatCurrency(reportTotal(entries, false) / rate)}',
                PdfColors.red700,
              ),
              pw.SizedBox(width: 16),
              _pdfChip(
                'Net Balance',
                '$symbol ${formatCurrency((reportTotal(entries, true) - reportTotal(entries, false)) / rate)}',
                (reportTotal(entries, true) - reportTotal(entries, false)) >= 0
                    ? PdfColors.green700
                    : PdfColors.red700,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Transaction History',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
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
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...entries.map((e) {
                final amt = (e['amount'] as num).toDouble() / rate;
                final isInc = e['is_income'] as bool;
                final date = reportDate(e);
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        reportDescription(e),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        date == null
                            ? 'Date unavailable'
                            : '${date.day}/${date.month}/${date.year}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '$symbol ${formatCurrency(amt)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        isInc ? 'In' : 'Out',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: isInc ? PdfColors.green700 : PdfColors.red700,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${reportFilename(bookName)}');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Report for $bookName',
      sharePositionOrigin: _shareOrigin(),
    );
  }

  pw.Widget _pdfChip(String label, String value, PdfColor color) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _refresh() async {
    if (!ref.read(isLoggedInProvider)) return;
    await ref.read(booksProvider.notifier).loadBooks();
    if (!mounted) return;
    final books = ref.read(booksProvider).asData?.value ?? [];
    if (books.any((book) => book['id'] == _selectedBookId)) {
      await ref.read(entriesProvider(_selectedBookId!).notifier).loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signedIn = ref.watch(isLoggedInProvider);
    final settings = ref.watch(settingsProvider);
    final booksAsync = ref.watch(booksProvider);
    final books = booksAsync.asData?.value ?? [];
    final matches = books
        .where((book) => book['id'] == _selectedBookId)
        .toList();
    final selected = signedIn && matches.isNotEmpty ? matches.first : null;
    final entriesAsync = selected == null
        ? null
        : ref.watch(entriesProvider(selected['id'] as String));
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Reports',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Change currency',
            onPressed: _exporting
                ? null
                : () => CurrencyPickerWidget.show(context),
            icon: const Icon(Icons.currency_exchange_rounded),
          ),
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _exporting || !signedIn ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const PageStorageKey('reports-tab'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  const ReportHeading(
                    title: 'Your money, in focus',
                    subtitle:
                        'Understand your cash flow and share the details.',
                  ),
                  const SizedBox(height: 24),
                  if (!signedIn)
                    BooksEmptyState(
                      title: 'Sign in to view reports',
                      message:
                          'Keep your cash books together and export a report whenever you need it.',
                      actionLabel: 'Sign in to Lankar',
                      onAction: () => context.go(AppRoutes.login),
                      icon: Icons.lock_outline_rounded,
                    )
                  else if (booksAsync.isLoading && !booksAsync.hasValue)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (booksAsync.hasError)
                    AppErrorView(error: booksAsync.error!, onRetry: _refresh)
                  else if (books.isEmpty)
                    BooksEmptyState(
                      title: 'Your reports start with a book',
                      message:
                          'Create a cash book and add entries to see your money at a glance.',
                      actionLabel: 'Go to cash books',
                      onAction: () =>
                          ref.read(selectedTabProvider.notifier).state = 1,
                      icon: Icons.auto_stories_outlined,
                    )
                  else ...[
                    ReportPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CASH BOOK',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('report-book-$_selectedBookId'),
                            initialValue: selected?['id'] as String?,
                            isExpanded: true,
                            hint: const Text('Choose a cash book'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.auto_stories_outlined),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: [
                              for (final book in books)
                                DropdownMenuItem(
                                  value: book['id'] as String,
                                  child: Text(
                                    book['name'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _exporting
                                ? null
                                : (id) => setState(() => _selectedBookId = id),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${settings.currency.name} - All time',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (selected == null)
                      const ReportPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 32),
                            SizedBox(height: 14),
                            Text(
                              'Choose a book to explore',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your balance, cash flow, and transaction history will appear here.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      )
                    else if (entriesAsync!.isLoading && !entriesAsync.hasValue)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (entriesAsync.hasError)
                      AppErrorView(
                        error: entriesAsync.error!,
                        onRetry: () => ref
                            .read(
                              entriesProvider(
                                selected['id'] as String,
                              ).notifier,
                            )
                            .loadEntries(),
                      )
                    else ...[
                      ReportsOverview(
                        entries: entriesAsync.asData?.value ?? [],
                        symbol: settings.currencySymbol,
                        rate: settings.exchangeRate,
                      ),
                      const SizedBox(height: 24),
                      ReportExportCard(
                        exporting: _exporting,
                        onShare: () => _exportPdf(
                          selected['name'] as String,
                          settings.currencySymbol,
                          settings.exchangeRate,
                          entriesAsync.asData?.value ?? [],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

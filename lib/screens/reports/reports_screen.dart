import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/report_data.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/reports_design.dart';

class ReportsScreen extends StatefulWidget {
  final String bookId;
  final String bookName;
  final double totalIn;
  final double totalOut;
  final double balance;
  final List<Map<String, dynamic>> entries;
  final String currencySymbol;

  const ReportsScreen({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.totalIn,
    required this.totalOut,
    required this.balance,
    required this.entries,
    required this.currencySymbol,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Currency selectedCurrency;
  double get totalInCalc =>
      reportTotal(widget.entries, true) / exchangeRates[selectedCurrency]!;
  double get totalOutCalc =>
      reportTotal(widget.entries, false) / exchangeRates[selectedCurrency]!;
  double get netBalanceCalc => totalInCalc - totalOutCalc;
  String get currentSymbol => currencySymbols[selectedCurrency]!;

  @override
  void initState() {
    super.initState();
    selectedCurrency = currencySymbols.entries
        .firstWhere(
          (entry) => entry.value == widget.currencySymbol,
          orElse: () => const MapEntry(Currency.LKR, 'Rs'),
        )
        .key;
  }

  Rect _shareOrigin() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _showCurrencyPicker() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report currency',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              for (final currency in Currency.values)
                ListTile(
                  title: Text(currency.name),
                  subtitle: Text(currencySymbols[currency]!),
                  selected: selectedCurrency == currency,
                  trailing: selectedCurrency == currency
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : null,
                  onTap: () {
                    setState(() => selectedCurrency = currency);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _exporting = false;
  Future<void> _exportPdf({required bool share}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _generatePdf(share: share);
    } catch (error, stack) {
      AppErrors.report('Export PDF', error, stack);
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

  Future<void> _generatePdf({required bool share}) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return [
            pw.Text(
              'Report - ${widget.bookName}',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Net Balance: $currentSymbol ${formatCurrency(netBalanceCalc)}',
            ),
            pw.Text('Total In: $currentSymbol ${formatCurrency(totalInCalc)}'),
            pw.Text(
              'Total Out: $currentSymbol ${formatCurrency(totalOutCalc)}',
            ),
            pw.SizedBox(height: 20),
            pw.Text('Transaction history', style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            ...sortedReportEntries(widget.entries).map((e) {
              final double amount =
                  (e['amount'] as num).toDouble() /
                  exchangeRates[selectedCurrency]!;
              final String type = (e['is_income'] as bool)
                  ? 'Income'
                  : 'Expense';
              final String sign = (e['is_income'] as bool) ? '+' : '-';
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text('${reportDescription(e)} ($type)'),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text('$sign $currentSymbol ${formatCurrency(amount)}'),
                ],
              );
            }),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    if (share) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${reportFilename(widget.bookName)}');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Report for ${widget.bookName}',
        sharePositionOrigin: _shareOrigin(),
      );
      return;
    }
    final filename = reportFilename(widget.bookName);
    if (defaultTargetPlatform == TargetPlatform.android) {
      // The system picker grants access only to the chosen document.
      final uri = await const MethodChannel(
        'com.tokilo.lankar/reports',
      ).invokeMethod<String>('savePdf', {'name': filename, 'bytes': bytes});
      if (uri == null) return;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      await File('${directory.path}/$filename').writeAsBytes(bytes);
    }
    if (mounted) {
      AppFeedback.success(
        context,
        'Report saved',
        'Your PDF was saved as $filename.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book report',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to cash book',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Report currency',
            onPressed: _exporting ? null : _showCurrencyPicker,
            icon: const Icon(Icons.currency_exchange_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const PageStorageKey('book-report'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                ReportHeading(
                  title: widget.bookName,
                  subtitle: 'A clearer picture of your cash book.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _exporting ? null : _showCurrencyPicker,
                    icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                    label: Text('${selectedCurrency.name} - All time'),
                  ),
                ),
                const SizedBox(height: 12),
                ReportsOverview(
                  entries: widget.entries,
                  symbol: currentSymbol,
                  rate: exchangeRates[selectedCurrency]!,
                ),
                const SizedBox(height: 24),
                ReportExportCard(
                  exporting: _exporting,
                  onShare: () => _exportPdf(share: true),
                  onSave: () => _exportPdf(share: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

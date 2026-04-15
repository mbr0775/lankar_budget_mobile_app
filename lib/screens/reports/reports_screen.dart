// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/utils/helpers.dart';

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

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;
  Currency selectedCurrency = Currency.LKR; // Default
  late double baseTotalIn;
  late double baseTotalOut;

  double get totalInCalc => baseTotalIn / exchangeRates[selectedCurrency]!;
  double get totalOutCalc => baseTotalOut / exchangeRates[selectedCurrency]!;
  double get netBalanceCalc => totalInCalc - totalOutCalc;
  String get currentSymbol => currencySymbols[selectedCurrency]!;

  @override
  void initState() {
    super.initState();
    baseTotalIn = widget.entries
        .where((e) => e['is_income'] as bool)
        .fold(0.0, (sum, e) => sum + (e['amount'] as double));
    baseTotalOut = widget.entries
        .where((e) => !(e['is_income'] as bool))
        .fold(0.0, (sum, e) => sum + (e['amount'] as double));

    // Set initial currency based on symbol
    selectedCurrency = currencySymbols.entries
        .firstWhere(
          (e) => e.value == widget.currencySymbol,
          orElse: () => MapEntry(Currency.LKR, 'Rs'),
        )
        .key;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    if (amount.abs() >= 1_000_000) {
      return '${(amount / 1_000_000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1_000) {
      return '${(amount / 1_000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  List<Map<String, dynamic>> _getRecentActions() {
    final sorted = List<Map<String, dynamic>>.from(widget.entries);
    sorted.sort((a, b) {
      final da = DateTime.parse(a['entry_date'] ?? a['created_at']);
      final db = DateTime.parse(b['entry_date'] ?? b['created_at']);
      return db.compareTo(da);
    });
    return sorted.take(5).toList();
  }

  IconData _getCategoryIcon(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('food') || d.contains('meal') || d.contains('restaurant')) {
      return Icons.restaurant_rounded;
    }
    if (d.contains('fuel') || d.contains('gas') || d.contains('petrol')) {
      return Icons.local_gas_station_rounded;
    }
    if (d.contains('travel') || d.contains('transport') || d.contains('ticket')) {
      return Icons.flight_rounded;
    }
    if (d.contains('gift') || d.contains('present')) return Icons.card_giftcard_rounded;
    if (d.contains('shopping') || d.contains('shop')) return Icons.shopping_bag_rounded;
    if (d.contains('bill') || d.contains('utility')) return Icons.receipt_long_rounded;
    return Icons.account_balance_wallet_rounded;
  }

  List<Color> _getCategoryGradient(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('food')) return [incomeGreen, incomeGreen.withOpacity(0.7)];
    if (d.contains('fuel')) return [incomeGreen, incomeGreen.withOpacity(0.7)];
    if (d.contains('travel')) return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
    if (d.contains('gift')) return [const Color(0xFFA855F7), const Color(0xFF9333EA)];
    if (d.contains('shopping')) return [const Color(0xFFEC4899), const Color(0xFFDB2777)];
    return [incomeGreen, incomeGreen.withOpacity(0.7)];
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Currency',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),
            ...currencySymbols.entries.map((e) {
              final bool selected = selectedCurrency == e.key;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [primaryRed, secondaryRed],
                        )
                      : null,
                  color: selected ? null : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() => selectedCurrency = e.key);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.grey[200]!,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              e.key.toString().split('.').last,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: selected ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (selected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: primaryRed,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf({required bool share}) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Report – ${widget.bookName}',
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Net Balance: $currentSymbol ${_formatCurrency(netBalanceCalc)}'),
              pw.Text('Total In: $currentSymbol ${_formatCurrency(totalInCalc)}'),
              pw.Text('Total Out: $currentSymbol ${_formatCurrency(totalOutCalc)}'),
              pw.SizedBox(height: 20),
              pw.Text('Recent actions', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 10),
              ..._getRecentActions().map((e) {
                final double amount =
                    (e['amount'] as double) / exchangeRates[selectedCurrency]!;
                final String type = (e['is_income'] as bool) ? 'Income' : 'Expense';
                final String sign = (e['is_income'] as bool) ? '+' : '-';
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${e['description'] ?? 'Transaction'} ($type)'),
                    pw.Text('$sign $currentSymbol ${_formatCurrency(amount)}'),
                  ],
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    if (share) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.bookName}_report.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Report for ${widget.bookName}',
      );
      return;
    }
    Directory? targetDir;
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        targetDir = Directory('/storage/emulated/0/Download');
      } else {
        targetDir = await getExternalStorageDirectory();
      }
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }
    if (targetDir != null) {
      final file = File('${targetDir.path}/${widget.bookName}_report.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to ${file.path}'),
            backgroundColor: incomeGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      await _generatePdf(share: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spentToday = totalOutCalc;
    final balanceToday = netBalanceCalc;
    final progress = (totalInCalc == 0 && totalOutCalc == 0)
        ? 0.0
        : spentToday / (spentToday + balanceToday.abs()).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryRed,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryRed, secondaryRed, primaryRed],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.bookName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _showCurrencyPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Currency: ${selectedCurrency.toString().split('.').last}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                onPressed: () => _generatePdf(share: false),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _generatePdf(share: true),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular Progress Card
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (_, __) {
                              return CustomPaint(
                                painter: ModernCircularProgressPainter(
                                  progress: progress * _progressAnimation.value,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$currentSymbol ${formatCurrency(spentToday * _progressAnimation.value)}',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'you spent today',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              'balance for today',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$currentSymbol ${formatCurrency(balanceToday * _progressAnimation.value)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: incomeGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Last Actions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Last actions',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Transaction Cards
                  ..._getRecentActions().asMap().entries.map((entry) {
                    final index = entry.key;
                    final e = entry.value;
                    final bool income = e['is_income'] as bool;
                    final double amount = (e['amount'] as double) / exchangeRates[selectedCurrency]!;
                    final String desc = e['description'] ?? 'Transaction';
                    final IconData icon = _getCategoryIcon(desc);
                    final gradient = _getCategoryGradient(desc);
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            (0.3 + (index * 0.1)).clamp(0.0, 1.0),
                            (0.8 + (index * 0.1)).clamp(0.0, 1.0),
                            curve: Curves.easeOut,
                          ),
                        )),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradient,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gradient[0].withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(icon, color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc.length > 22
                                                ? '${desc.substring(0, 22)}...'
                                                : desc,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            income ? 'Income' : 'Expense',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[500],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${income ? '+' : '-'} $currentSymbol${_formatCurrency(amount)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: income ? incomeGreen : expenseRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [incomeGreen, incomeGreen.withOpacity(0.7)], // Removed 'const'
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: incomeGreen.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.trending_down_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Total In',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$currentSymbol${_formatCurrency(totalInCalc)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [expenseRed, expenseRed.withOpacity(0.7)], // Removed 'const'
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: expenseRed.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.trending_up_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Total Out',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$currentSymbol${_formatCurrency(totalOutCalc)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModernCircularProgressPainter extends CustomPainter {
  final double progress;

  ModernCircularProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 14;
    const strokeWidth = 14.0;
    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    // Progress gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: const [
        primaryRed,
        secondaryRed,
        primaryRed,
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );
    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
    // End dot
    if (progress > 0) {
      final endAngle = -math.pi / 2 + sweepAngle;
      final endPoint = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      // Outer glow
      canvas.drawCircle(
        endPoint,
        strokeWidth / 2 + 4,
        Paint()
          ..color = primaryRed.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      // Inner dot
      canvas.drawCircle(
        endPoint,
        strokeWidth / 2 + 2,
        Paint()
          ..color = primaryRed
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! ModernCircularProgressPainter ||
        oldDelegate.progress != progress;
  }
}
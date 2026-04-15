// lib/screens/books/cash_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/entry_card_widget.dart';
import '../../widgets/entry_dialog_widget.dart';
import '../../widgets/currency_picker_widget.dart';
import '../reports/reports_screen.dart';

class CashEntryScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;

  const CashEntryScreen({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  @override
  ConsumerState<CashEntryScreen> createState() =>
      _CashEntryScreenState();
}

class _CashEntryScreenState extends ConsumerState<CashEntryScreen> {
  String _filter = 'All';

  void _showEntrySheet(
    EntriesNotifier notifier,
    String symbol,
    double rate, {
    required bool isIncome,
    Map<String, dynamic>? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryDialogWidget(
        isIncome:       isIncome,
        currencySymbol: symbol,
        exchangeRate:   rate,
        existingEntry:  existing,
        onSave: ({
          required double amount,
          required String description,
          required bool isIncome,
          required DateTime entryDate,
          String? entryId,
        }) async {
          if (entryId != null) {
            return notifier.updateEntry(entryId,
                amount: amount, description: description);
          } else {
            return notifier.createEntry(
              amount:      amount,
              description: description,
              isIncome:    isIncome,
              entryDate:   entryDate,
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      EntriesNotifier notifier, String entryId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Entry'),
        content: const Text(
            'Delete this entry? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
    if (ok == true) await notifier.deleteEntry(entryId);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            const Text('Filter Entries',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            _filterOption('All', Icons.list, primaryRed),
            _filterOption(
                'Income', Icons.arrow_downward, incomeGreen),
            _filterOption(
                'Expense', Icons.arrow_upward, expenseRed),
          ],
        ),
      ),
    );
  }

  Widget _filterOption(
      String label, IconData icon, Color color) {
    final isSelected = _filter == label;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(0.08)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 18),
        ),
        title: Text(
          label == 'All' ? 'All Entries' : '$label Only',
          style: TextStyle(
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.w500),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: color, size: 22)
            : null,
        onTap: () {
          setState(() => _filter = label);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings     = ref.watch(settingsProvider);
    final entriesAsync =
        ref.watch(entriesProvider(widget.bookId));
    final symbol = settings.currencySymbol;
    final rate   = settings.exchangeRate;

    return entriesAsync.when(
      loading: () => const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: primaryRed)),
      ),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (allEntries) {
        final notifier =
            ref.read(entriesProvider(widget.bookId).notifier);

        final baseTotalIn = allEntries
            .where((e) => e['is_income'] == true)
            .fold(0.0,
                (s, e) => s + (e['amount'] as num).toDouble());
        final baseTotalOut = allEntries
            .where((e) => e['is_income'] == false)
            .fold(0.0,
                (s, e) => s + (e['amount'] as num).toDouble());

        final totalIn  = baseTotalIn / rate;
        final totalOut = baseTotalOut / rate;
        final net      = totalIn - totalOut;

        final filtered = _filter == 'Income'
            ? allEntries
                .where((e) => e['is_income'] == true)
                .toList()
            : _filter == 'Expense'
                ? allEntries
                    .where((e) => e['is_income'] == false)
                    .toList()
                : allEntries;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),

          // ✅ FIX: Use bottomNavigationBar instead of bottomSheet
          // bottomNavigationBar respects SafeArea and system nav bar
          // automatically — buttons will never be hidden
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            // ✅ SafeArea ensures padding above Android nav bar
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showEntrySheet(
                          notifier, symbol, rate,
                          isIncome: true,
                        ),
                        icon:
                            const Icon(Icons.add, size: 20),
                        label: const Text('CASH IN',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: incomeGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showEntrySheet(
                          notifier, symbol, rate,
                          isIncome: false,
                        ),
                        icon: const Icon(Icons.remove,
                            size: 20),
                        label: const Text('CASH OUT',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          body: CustomScrollView(
            slivers: [
              // ── App Bar ───────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: primaryRed,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
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
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.end,
                          children: [
                            Text(widget.bookName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () =>
                                  CurrencyPickerWidget.show(
                                      context),
                              child: Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 12,
                                    vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(
                                          20),
                                ),
                                child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Currency: ${settings.currency.toString().split('.').last}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.white,
                                        size: 18),
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
                actions: [
                  IconButton(
                    icon: Stack(children: [
                      const Icon(Icons.filter_list,
                          color: Colors.white),
                      if (_filter != 'All')
                        Positioned(
                          right: 0, top: 0,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ]),
                    onPressed: _showFilterSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white),
                    onPressed: () => notifier.loadEntries(),
                  ),
                ],
              ),

              // ── Balance Card ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.07),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                const Text('Net Balance',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w500,
                                        color: Colors.grey)),
                                Text(
                                  '$symbol ${formatCurrency(net)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: net >= 0
                                        ? incomeGreen
                                        : expenseRed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                                height: 1,
                                color: Colors.grey[100]),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _BalanceItem(
                                    label: 'Total In',
                                    amount:
                                        '$symbol ${formatCurrency(totalIn)}',
                                    color: incomeGreen,
                                    icon: Icons.arrow_downward,
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 56,
                                    color: Colors.grey[100]),
                                Expanded(
                                  child: _BalanceItem(
                                    label: 'Total Out',
                                    amount:
                                        '$symbol ${formatCurrency(totalOut)}',
                                    color: expenseRed,
                                    icon: Icons.arrow_upward,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportsScreen(
                                    bookId:        widget.bookId,
                                    bookName:      widget.bookName,
                                    totalIn:       totalIn,
                                    totalOut:      totalOut,
                                    balance:       net,
                                    entries:       allEntries,
                                    currencySymbol: symbol,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12)),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 13),
                                minimumSize: const Size(
                                    double.infinity, 0),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text('VIEW REPORTS',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold)),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward,
                                      size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock,
                                color: Colors.grey[500],
                                size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Only you can see these entries',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Entry List ────────────────────────────────────────
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        _filter == 'All'
                            ? Icons.receipt_long_outlined
                            : Icons.search_off,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filter == 'All'
                            ? 'No entries yet'
                            : 'No ${_filter.toLowerCase()} entries',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _filter == 'All'
                            ? 'Tap CASH IN or CASH OUT below'
                            : 'Try a different filter',
                        style: TextStyle(
                            color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              else
                SliverPadding(
                  // ✅ 20px bottom padding is enough since
                  // bottomNavigationBar handles its own space
                  padding: const EdgeInsets.fromLTRB(
                      20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final entry  = filtered[i];
                        final amount =
                            (entry['amount'] as num)
                                    .toDouble() /
                                rate;
                        return EntryCardWidget(
                          entry:          entry,
                          currencySymbol: symbol,
                          displayAmount:  amount,
                          onEdit: () => _showEntrySheet(
                            notifier, symbol, rate,
                            isIncome:
                                entry['is_income'] as bool,
                            existing: entry,
                          ),
                          onDelete: () => _confirmDelete(
                              notifier, entry['id']),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _BalanceItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                )),
          ],
        ),
        const SizedBox(height: 6),
        Text(amount,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
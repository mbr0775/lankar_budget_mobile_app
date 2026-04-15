// lib/widgets/entry_dialog_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class EntryDialogWidget extends StatefulWidget {
  final bool isIncome;
  final String currencySymbol;
  final double exchangeRate;
  final Map<String, dynamic>? existingEntry;
  final Future<bool> Function({
    required double amount,
    required String description,
    required bool isIncome,
    required DateTime entryDate,
    String? entryId,
  }) onSave;

  const EntryDialogWidget({
    super.key,
    required this.isIncome,
    required this.currencySymbol,
    required this.exchangeRate,
    required this.onSave,
    this.existingEntry,
  });

  @override
  State<EntryDialogWidget> createState() => _EntryDialogWidgetState();
}

class _EntryDialogWidgetState extends State<EntryDialogWidget> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  bool _isLoading   = false;
  late DateTime _selectedDate;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    if (_isEditing) {
      final entry      = widget.existingEntry!;
      final baseAmount = (entry['amount'] as num).toDouble();
      _amountCtrl.text = (baseAmount / widget.exchangeRate)
          .toStringAsFixed(2);
      _descCtrl.text = entry['description'] ?? '';
      final dateStr  = entry['entry_date'] ?? entry['created_at'];
      if (dateStr != null) {
        _selectedDate = DateTime.parse(dateStr as String);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate,
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryRed),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final display    = double.parse(_amountCtrl.text.trim());
      final baseAmount = display * widget.exchangeRate;

      final ok = await widget.onSave(
        amount:      baseAmount,
        description: _descCtrl.text.trim(),
        isIncome:    widget.isIncome,
        entryDate:   _selectedDate,
        entryId: _isEditing
            ? widget.existingEntry!['id'] as String
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (_isEditing ? 'Entry updated!' : 'Entry added!')
              : 'Failed to save. Try again.'),
          backgroundColor: ok
              ? (widget.isIncome ? incomeGreen : primaryRed)
              : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = widget.isIncome ? incomeGreen : primaryRed;
    final label = widget.isIncome ? 'Cash In' : 'Cash Out';
    final icon  = widget.isIncome
        ? Icons.arrow_downward
        : Icons.arrow_upward;

    // ✅ Use Padding with MediaQuery.viewInsets so content shifts up
    // automatically when keyboard appears — no overflow possible
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing ? 'Edit Entry' : label,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Amount ─────────────────────────────────────────────
                Text('Amount (${widget.currencySymbol})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  autofocus: !_isEditing,
                  keyboardType: const TextInputType
                      .numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final p = double.tryParse(v.trim());
                    if (p == null) return 'Enter a valid number';
                    if (p <= 0) return 'Must be greater than 0';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      child: Text(widget.currencySymbol,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 0, minHeight: 0),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: color, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Description ────────────────────────────────────────
                const Text('Description',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    hintText: 'What is this for?',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Date ───────────────────────────────────────────────
                const Text('Date',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            color: Colors.grey[600], size: 20),
                        const SizedBox(width: 12),
                        Text(_formatDate(_selectedDate),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Save Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(
                            _isEditing
                                ? 'Save Changes'
                                : 'Add $label',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// lib/widgets/entry_dialog_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/app_errors.dart';
import 'app_feedback.dart';
import 'home/home_motion.dart';

class EntryDialogWidget extends StatefulWidget {
  final bool isIncome;
  final String currencySymbol;
  final double exchangeRate;
  final Map<String, dynamic>? existingEntry;
  final bool Function()? isSyncPending;
  final Future<bool> Function({
    required double amount,
    required String description,
    required bool isIncome,
    required DateTime entryDate,
    String? entryId,
  })
  onSave;

  const EntryDialogWidget({
    super.key,
    required this.isIncome,
    required this.currencySymbol,
    required this.exchangeRate,
    required this.onSave,
    this.existingEntry,
    this.isSyncPending,
  });

  @override
  State<EntryDialogWidget> createState() => _EntryDialogWidgetState();
}

class _EntryDialogWidgetState extends State<EntryDialogWidget> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  AppFailure? _saveError;
  late DateTime _selectedDate;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    if (_isEditing) {
      final entry = widget.existingEntry!;
      final baseAmount = (entry['amount'] as num).toDouble();
      _amountCtrl.text = (baseAmount / widget.exchangeRate).toStringAsFixed(2);
      _descCtrl.text = entry['description'] ?? '';
      final dateStr = entry['entry_date'] ?? entry['created_at'];
      if (dateStr != null) {
        _selectedDate = DateTime.tryParse(dateStr as String) ?? DateTime.now();
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
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _saveError = null;
    });
    try {
      final display = double.parse(_amountCtrl.text.trim());
      final baseAmount = display * widget.exchangeRate;
      if (!baseAmount.isFinite || baseAmount <= 0) {
        throw const AppFailure(
          'Check the amount',
          'Enter a valid amount greater than zero.',
          kind: FailureKind.validation,
        );
      }
      final ok = await widget.onSave(
        amount: baseAmount,
        description: _descCtrl.text.trim(),
        isIncome: widget.isIncome,
        entryDate: _selectedDate,
        entryId: _isEditing ? widget.existingEntry!['id'] as String : null,
      );
      if (!mounted) return;
      if (!ok) {
        throw const AppFailure(
          'Entry not saved',
          'Your details are still here. Try saving again.',
        );
      }
      final pending = widget.isSyncPending?.call() ?? false;
      AppFeedback.success(
        context,
        _isEditing
            ? 'Entry updated'
            : widget.isIncome
            ? 'Income added'
            : 'Expense added',
        pending
            ? 'Saved on this device. It will sync when a connection is available.'
            : 'Your cash book has been updated.',
      );
      Navigator.pop(context, true);
    } catch (error, stack) {
      AppErrors.report('Save cash entry', error, stack);
      if (mounted) {
        setState(
          () => _saveError = AppErrors.from(
            error,
            fallback: 'Your details are still here. Try saving again.',
          ),
        );
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final color = widget.isIncome
        ? (dark ? const Color(0xFF7DDCB6) : const Color(0xFF16815C))
        : scheme.primary;
    final label = widget.isIncome ? 'Cash In' : 'Cash Out';
    final icon = widget.isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    // ✅ Use Padding with MediaQuery.viewInsets so content shifts up
    // automatically when keyboard appears — no overflow possible
    return PopScope(
      canPop: !_isLoading,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      SculptedIcon(icon: icon, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit Entry' : label,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close entry form',
                        icon: const Icon(Icons.close),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.primary.withValues(
                            alpha: .08,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Amount ─────────────────────────────────────────────
                  Text(
                    'Amount (${widget.currencySymbol})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountCtrl,
                    enabled: !_isLoading,
                    autofocus: !_isEditing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      final p = double.tryParse(v.trim());
                      if (p == null || !p.isFinite) {
                        return 'Enter a valid number';
                      }
                      if (p <= 0) return 'Must be greater than 0';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Text(
                          widget.currencySymbol,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Description ────────────────────────────────────────
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    enabled: !_isLoading,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: const InputDecoration(
                      hintText: 'What is this for?',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Date ───────────────────────────────────────────────
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isLoading ? null : _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save Button ────────────────────────────────────────
                  if (_saveError != null) ...[
                    FeedbackCard(
                      title: _saveError!.title,
                      message: _saveError!.message,
                      tone: FeedbackTone.error,
                      onDismiss: () => setState(() => _saveError = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isIncome
                            ? const Color(0xFF16815C)
                            : primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Add $label',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

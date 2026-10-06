double reportTotal(List<Map<String, dynamic>> entries, bool income) => entries
    .where((entry) => entry['is_income'] == income)
    .fold<double>(0, (sum, entry) => sum + (entry['amount'] as num).toDouble());

DateTime? reportDate(Map<String, dynamic> entry) => DateTime.tryParse(
  (entry['entry_date'] ?? entry['created_at']) as String? ?? '',
)?.toLocal();

List<Map<String, dynamic>> sortedReportEntries(
  List<Map<String, dynamic>> entries,
) => List<Map<String, dynamic>>.of(entries)
  ..sort((a, b) {
    final dateOrder = (reportDate(b) ?? DateTime(1970)).compareTo(
      reportDate(a) ?? DateTime(1970),
    );
    return dateOrder == 0 ? '${a['id']}'.compareTo('${b['id']}') : dateOrder;
  });

String reportDescription(Map<String, dynamic> entry) {
  final text = (entry['description'] as String? ?? '').trim();
  return text.isEmpty
      ? (entry['is_income'] == true ? 'Cash in' : 'Cash out')
      : text;
}

String reportFilename(String bookName) {
  final name = bookName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .trim();
  return '${name.isEmpty ? 'Cash_book' : name}_report.pdf';
}

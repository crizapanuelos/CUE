String money(int cents) {
  final amount = (cents / 100).toStringAsFixed(2).split('.');
  final grouped = amount[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₱$grouped.${amount[1]}';
}

String? requiredText(String? v) =>
    v == null || v.trim().isEmpty ? 'This field is required' : null;
String? emailError(String? v) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
    ? null
    : 'Enter a valid email';
String? passwordError(String? v) =>
    (v?.length ?? 0) >= 8 ? null : 'Use at least 8 characters';

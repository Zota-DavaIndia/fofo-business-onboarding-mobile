const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "3:01 pm"
String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

/// "17 Oct 2026"
String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "17 Oct 2026, 3:01 pm" in the phone's time zone.
String formatDate(DateTime d) => '${formatDay(d)}, ${formatTime(d)}';

/// "17 Oct", or "17 Oct 2025" when it isn't this year.
String formatShortDay(DateTime d) {
  final full = formatDay(d);
  return d.year == DateTime.now().year ? full.substring(0, full.length - 5) : full;
}

/// A UTR as the bank checks it: spaces and hyphens dropped, upper case.
String cleanUtr(String input) => input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// Same rule as the CRM: 10 to 22 letters or digits once cleaned.
bool isUtr(String cleaned) => RegExp(r'^[A-Z0-9]{10,22}$').hasMatch(cleaned);

/// "Ravi", "Ravi and Amit", "Ravi, Amit and Neha".
String joinNames(List<String> names) => switch (names.length) {
  0 => '',
  1 => names.first,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};

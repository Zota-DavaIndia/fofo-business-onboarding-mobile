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

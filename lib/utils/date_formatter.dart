String formatDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}-${two(date.month)}-${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String formatTime(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

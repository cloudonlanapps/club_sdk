/// Formats an integer with Indian numbering (e.g. 1,00,000).
///
/// Groups the last three digits, then every two digits before that.
/// Examples: 1000 → "1,000", 100000 → "1,00,000", 1500000 → "15,00,000".
String formatIndianNumber(int number) {
  final str = number.toString();
  final result = StringBuffer();
  var count = 0;

  for (var i = str.length - 1; i >= 0; i--) {
    if (count == 3 || (count > 3 && (count - 3).isEven)) {
      result.write(',');
    }
    result.write(str[i]);
    count++;
  }

  return result.toString().split('').reversed.join();
}

/// Formats a [DateTime] as "15 April 2026".
String formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

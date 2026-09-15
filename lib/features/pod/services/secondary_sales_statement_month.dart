// Pre-upload statement-month validation for Himalaya Secondary Sales.
//
// Flutter does not OCR statement PDFs. The existing upload flow already
// sends `statement_month` as `YYYY-MM` and Himalaya files encode the
// period as `YYYY_MM` in the filename. This helper reuses that same
// year+month key and common date formats already used in the app.

const kSecondarySalesMonthMismatchMessage =
    'You can upload statements of the selected month only.';
const kSecondarySalesMonthUndeterminedMessage =
    'Unable to determine the statement month. Please upload a valid stock statement.';

class StatementMonthKey {
  final int year;
  final int month;

  const StatementMonthKey(this.year, this.month);

  factory StatementMonthKey.fromDate(DateTime date) =>
      StatementMonthKey(date.year, date.month);

  String get yyyyMm =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  bool matches(StatementMonthKey other) =>
      year == other.year && month == other.month;

  @override
  bool operator ==(Object other) =>
      other is StatementMonthKey && matches(other);

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => yyyyMm;
}

class StatementMonthValidation {
  final bool canUpload;
  final String? errorMessage;

  const StatementMonthValidation._({
    required this.canUpload,
    this.errorMessage,
  });

  const StatementMonthValidation.allow()
      : this._(canUpload: true);

  const StatementMonthValidation.mismatch()
      : this._(
          canUpload: false,
          errorMessage: kSecondarySalesMonthMismatchMessage,
        );

  const StatementMonthValidation.undetermined()
      : this._(
          canUpload: false,
          errorMessage: kSecondarySalesMonthUndeterminedMessage,
        );
}

final _monthNames = <String, int>{
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

/// Normalize a selected or extracted month to year+month.
/// Accepts DateTime, `YYYY-MM`, `YYYY_MM`, `YYYY/MM`, and month names.
StatementMonthKey? parseStatementMonth(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return StatementMonthKey.fromDate(value);
  if (value is StatementMonthKey) return value;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  final keys = extractStatementMonths(text);
  if (keys.length == 1) return keys.first;
  return null;
}

Set<StatementMonthKey> extractStatementMonths(String source) {
  final text = source.trim();
  if (text.isEmpty) return {};

  final periodKeys = <StatementMonthKey>{};
  periodKeys.addAll(_extractYearMonthPairs(text));
  periodKeys.addAll(_extractNamedMonths(text));
  if (periodKeys.isNotEmpty) return periodKeys;

  final fallback = <StatementMonthKey>{};
  fallback.addAll(_extractDayMonthYear(text));
  fallback.addAll(_extractCompactYearMonth(text));
  return fallback;
}

/// Validates every selected file against the authoritative selected month.
StatementMonthValidation validateStatementFilesForSelectedMonth({
  required DateTime selectedMonth,
  required Iterable<String> fileNames,
}) {
  final selected = StatementMonthKey.fromDate(selectedMonth);
  final names = fileNames
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toList();
  if (names.isEmpty) {
    return const StatementMonthValidation.undetermined();
  }

  for (final name in names) {
    final months = extractStatementMonths(name);
    if (months.isEmpty) {
      return const StatementMonthValidation.undetermined();
    }
    if (months.any((month) => !month.matches(selected))) {
      return const StatementMonthValidation.mismatch();
    }
  }
  return const StatementMonthValidation.allow();
}

Iterable<StatementMonthKey> _extractYearMonthPairs(String text) sync* {
  final yyyyMm = RegExp(r'(20\d{2})[-_\/](0[1-9]|1[0-2])(?!\d)');
  for (final match in yyyyMm.allMatches(text)) {
    final key = _key(match.group(1), match.group(2));
    if (key != null) yield key;
  }

  final mmYyyy = RegExp(r'(?<!\d)(0[1-9]|1[0-2])[-_\/](20\d{2})(?!\d)');
  for (final match in mmYyyy.allMatches(text)) {
    final key = _key(match.group(2), match.group(1));
    if (key != null) yield key;
  }
}

Iterable<StatementMonthKey> _extractNamedMonths(String text) sync* {
  final names = _monthNames.keys.join('|');
  final namedThenYear = RegExp(
    '($names)\\s*[.,\\-_\\/]?\\s*(20\\d{2})',
    caseSensitive: false,
  );
  for (final match in namedThenYear.allMatches(text)) {
    final key = _namedKey(match.group(1), match.group(2));
    if (key != null) yield key;
  }

  final yearThenNamed = RegExp(
    '(20\\d{2})\\s*[.,\\-_\\/]?\\s*($names)',
    caseSensitive: false,
  );
  for (final match in yearThenNamed.allMatches(text)) {
    final key = _namedKey(match.group(2), match.group(1));
    if (key != null) yield key;
  }
}

Iterable<StatementMonthKey> _extractDayMonthYear(String text) sync* {
  final dmy = RegExp(
    r'(?<!\d)(0?[1-9]|[12]\d|3[01])[-/.](0?[1-9]|1[0-2])[-/.](20\d{2})(?!\d)',
  );
  for (final match in dmy.allMatches(text)) {
    final key = _key(match.group(3), match.group(2));
    if (key != null) yield key;
  }

  final ymd = RegExp(
    r'(20\d{2})[-/.](0?[1-9]|1[0-2])[-/.](0?[1-9]|[12]\d|3[01])(?!\d)',
  );
  for (final match in ymd.allMatches(text)) {
    final key = _key(match.group(1), match.group(2));
    if (key != null) yield key;
  }
}

Iterable<StatementMonthKey> _extractCompactYearMonth(String text) sync* {
  final compact = RegExp(r'(?<!\d)(20\d{2})(0[1-9]|1[0-2])(?!\d)');
  for (final match in compact.allMatches(text)) {
    final key = _key(match.group(1), match.group(2));
    if (key != null) yield key;
  }
}

StatementMonthKey? _namedKey(String? name, String? year) {
  if (name == null) return null;
  final month = _monthNames[name.toLowerCase()];
  return _key(year, month?.toString());
}

StatementMonthKey? _key(String? yearText, String? monthText) {
  final year = int.tryParse(yearText ?? '');
  final month = int.tryParse(monthText ?? '');
  if (year == null || month == null) return null;
  if (month < 1 || month > 12) return null;
  if (year < 2000 || year > 2100) return null;
  return StatementMonthKey(year, month);
}

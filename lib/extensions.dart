const _maskCharacter = '*';

final _personNamePattern = RegExp(
  r'^(?<initial>\S)(?<hidden>\S*)(?<surname>\s+\S(?:.*\S)?)$',
  unicode: true,
);

/// Операції над датою, потрібні для формату вхідних даних бібліотеки.
extension IsoDate on DateTime {
  /// Повертає дату у форматі `РРРР-ММ-ДД` без часу.
  String toIsoDateString() {
    final yyyy = year.toString().padLeft(4, '0');
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  /// Повертає кількість повних днів від цієї дати до [other].
  int daysUntil(DateTime other) => other.difference(this).inDays;

  /// Розбирає дату з рядка [text] у форматі `РРРР-ММ-ДД`.
  ///
  /// На відміну від [DateTime.tryParse], повертає `null` для неіснуючої дати
  /// на кшталт `2025-02-30`, яку стандартний розбір мовчки переносить на
  /// березень.
  static DateTime? tryParseStrict(String text) {
    final date = DateTime.tryParse(text);
    return date != null && date.toIsoDateString() == text ? date : null;
  }
}

/// Операції над рядком з іменем людини, наприклад автора книги.
extension PersonName on String {
  /// Чи містить рядок щонайменше ім’я та прізвище.
  bool get isFullName => _personNamePattern.hasMatch(this);

  /// Повертає ім’я з прихованою частиною: перша літера та прізвище лишаються.
  ///
  /// Рядок, що не відповідає шаблону імені, повертається без змін.
  String get maskedName => replaceAllMapped(_personNamePattern, (match) {
    final regexMatch = match as RegExpMatch;
    final initial = regexMatch.namedGroup('initial') ?? '';
    final hidden = regexMatch.namedGroup('hidden') ?? '';
    final surname = regexMatch.namedGroup('surname') ?? '';
    return '$initial${_maskCharacter * hidden.runes.length}$surname';
  });
}

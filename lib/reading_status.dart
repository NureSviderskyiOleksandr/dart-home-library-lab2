import 'extensions.dart';

const _plannedMarker = 'в планах';
const _readingPrefix = 'читаю';
const _percentFactor = 100;

final _statusPattern = RegExp(
  r'^(?:(?<finished>\d{4}-\d{2}-\d{2})'
  r'|читаю:(?<page>\d+)'
  r'|(?<planned>в планах))$',
);

/// Стан читання книги.
///
/// Клас запечатаний: усі підтипи оголошено в цій бібліотеці, тому компілятор
/// перевіряє switch за станом на вичерпність без гілки `default`.
sealed class ReadingStatus {
  /// Конструктор для підтипів.
  const ReadingStatus();

  /// Розбирає стан із поля [text] вхідного рядка.
  ///
  /// Допустимі форми: дата прочитання `РРРР-ММ-ДД`, `читаю:<сторінка>` і
  /// `в планах`. Повертає `null`, якщо поле не відповідає жодній формі.
  static ReadingStatus? tryParse(String text) {
    final match = _statusPattern.firstMatch(text.trim());
    if (match == null) return null;

    if (match.namedGroup('planned') != null) return const Planned();

    final page = int.tryParse(match.namedGroup('page') ?? '');
    if (page != null) return Reading(page);

    final date = IsoDate.tryParseStrict(match.namedGroup('finished') ?? '');
    return date == null ? null : Finished(date);
  }

  /// Короткий підпис стану для звіту.
  String get label;

  /// Частка прочитаного для книги з [pageCount] сторінками, від 0 до 1.
  double completion(int pageCount);

  /// Подає стан у форматі поля вхідного рядка.
  String toCsvField();
}

/// Книгу заплановано, але читання ще не почалося.
final class Planned extends ReadingStatus {
  /// Створює стан «у планах».
  const Planned();

  @override
  String get label => 'у планах';

  @override
  double completion(int pageCount) => 0;

  @override
  String toCsvField() => _plannedMarker;

  @override
  bool operator ==(Object other) => other is Planned;

  @override
  int get hashCode => (Planned).hashCode;

  @override
  String toString() => 'Planned()';
}

/// Книга читається, зупинка на сторінці [currentPage].
final class Reading extends ReadingStatus {
  /// Створює стан читання на сторінці [currentPage].
  const Reading(this.currentPage);

  /// Сторінка, до якої дочитано.
  final int currentPage;

  @override
  String get label => 'читається';

  @override
  double completion(int pageCount) =>
      pageCount <= 0 ? 0 : (currentPage / pageCount).clamp(0, 1).toDouble();

  /// Повертає опис прогресу для книги з [pageCount] сторінками.
  String progressLabel(int pageCount) {
    final percent = (completion(pageCount) * _percentFactor).round();
    return '$label: стор. $currentPage з $pageCount ($percent %)';
  }

  @override
  String toCsvField() => '$_readingPrefix:$currentPage';

  @override
  bool operator ==(Object other) =>
      other is Reading && other.currentPage == currentPage;

  @override
  int get hashCode => Object.hash(Reading, currentPage);

  @override
  String toString() => 'Reading($currentPage)';
}

/// Книгу прочитано [date].
final class Finished extends ReadingStatus {
  /// Створює стан «прочитано» з датою [date].
  const Finished(this.date);

  /// Дата прочитання.
  final DateTime date;

  @override
  String get label => 'прочитано';

  @override
  double completion(int pageCount) => 1;

  /// Повертає кількість повних днів від прочитання до [referenceDate].
  int daysSince(DateTime referenceDate) => date.daysUntil(referenceDate);

  @override
  String toCsvField() => date.toIsoDateString();

  @override
  bool operator ==(Object other) => other is Finished && other.date == date;

  @override
  int get hashCode => Object.hash(Finished, date);

  @override
  String toString() => 'Finished(${date.toIsoDateString()})';
}

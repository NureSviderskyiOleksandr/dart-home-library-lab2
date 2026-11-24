import 'extensions.dart';

const _plannedMarker = 'в планах';
const _readingPrefix = 'читаю';
const _abandonedPrefix = 'кинуто';
const _percentFactor = 100;

final _statusPattern = RegExp(
  r'^(?:(?<finished>\d{4}-\d{2}-\d{2})'
  r'|читаю:(?<page>\d+)'
  r'|кинуто:(?<abandonedDate>\d{4}-\d{2}-\d{2}):(?<abandonedPage>\d+)'
  r'|(?<planned>в планах))$',
);

/// Відомості про стан читання, на які спираються домішки станів.
///
/// Інтерфейс винесено окремо від [ReadingStatus] навмисно: домішка з
/// обмеженням `on ReadingStatus` сама стала б незапечатаним прямим підтипом
/// запечатаного класу, і switch за підтипами втратив би вичерпність.
abstract interface class ReadingProgress {
  /// Короткий підпис стану для звіту.
  String get label;

  /// Частка прочитаного для книги з [pageCount] сторінками, від 0 до 1.
  double completion(int pageCount);
}

/// Стан читання книги.
///
/// Клас запечатаний: усі підтипи оголошено в цій бібліотеці, тому компілятор
/// перевіряє switch за станом на вичерпність без гілки `default`.
sealed class ReadingStatus implements ReadingProgress {
  /// Конструктор для підтипів.
  const ReadingStatus();

  /// Розбирає стан із поля [text] вхідного рядка.
  ///
  /// Допустимі форми: дата прочитання `РРРР-ММ-ДД`, `читаю:<сторінка>`,
  /// `кинуто:<дата>:<сторінка>` і `в планах`. Повертає `null`, якщо поле не
  /// відповідає жодній формі або містить неіснуючу дату.
  static ReadingStatus? tryParse(String text) {
    final match = _statusPattern.firstMatch(text.trim());
    if (match == null) return null;

    DateTime? date(String group) =>
        IsoDate.tryParseStrict(match.namedGroup(group) ?? '');
    int? page(String group) => int.tryParse(match.namedGroup(group) ?? '');

    return switch ((
      match.namedGroup('planned'),
      page('page'),
      date('finished'),
      date('abandonedDate'),
      page('abandonedPage'),
    )) {
      (_?, _, _, _, _) => const Planned(),
      (_, final currentPage?, _, _, _) => Reading(currentPage),
      (_, _, final finishedOn?, _, _) => Finished(finishedOn),
      (_, _, _, final abandonedOn?, final currentPage?) => Abandoned(
        abandonedOn,
        currentPage,
      ),
      _ => null,
    };
  }

  /// Подає стан у форматі поля вхідного рядка.
  String toCsvField();
}

/// Поведінка стану, прив’язаного до дати: прочитано або кинуто.
///
/// Обмеження `on ReadingProgress` дозволяє підмішувати домішку лише до
/// класів, що реалізують цей інтерфейс, і дає доступ до гетера [label].
mixin DatedStatus on ReadingProgress {
  /// Дата, коли стан набув чинності.
  DateTime get date;

  /// Повертає кількість повних днів від [date] до [referenceDate].
  int daysSince(DateTime referenceDate) => date.daysUntil(referenceDate);

  /// Підпис стану разом із датою.
  String get dateLabel => '$label ${date.toIsoDateString()}';
}

/// Поведінка стану, у якому відома поточна сторінка: читається або кинуто.
///
/// Обмеження `on ReadingProgress` дає доступ до [label] і дозволяє домішці
/// реалізувати абстрактний метод [completion] замість класу, до якого її
/// підмішано.
mixin PageProgress on ReadingProgress {
  /// Сторінка, до якої дочитано.
  int get currentPage;

  @override
  double completion(int pageCount) =>
      pageCount <= 0 ? 0 : (currentPage / pageCount).clamp(0, 1).toDouble();

  /// Повертає опис прогресу для книги з [pageCount] сторінками.
  String progressLabel(int pageCount) {
    final percent = (completion(pageCount) * _percentFactor).round();
    return '$label на стор. $currentPage з $pageCount ($percent %)';
  }
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
final class Reading extends ReadingStatus with PageProgress {
  /// Створює стан читання на сторінці [currentPage].
  const Reading(this.currentPage);

  @override
  final int currentPage;

  @override
  String get label => 'читається';

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
final class Finished extends ReadingStatus with DatedStatus {
  /// Створює стан «прочитано» з датою [date].
  const Finished(this.date);

  @override
  final DateTime date;

  @override
  String get label => 'прочитано';

  @override
  double completion(int pageCount) => 1;

  @override
  String toCsvField() => date.toIsoDateString();

  @override
  bool operator ==(Object other) => other is Finished && other.date == date;

  @override
  int get hashCode => Object.hash(Finished, date);

  @override
  String toString() => 'Finished(${date.toIsoDateString()})';
}

/// Читання книги припинено [date] на сторінці [currentPage].
final class Abandoned extends ReadingStatus with DatedStatus, PageProgress {
  /// Створює стан «кинуто» з датою [date] і сторінкою [currentPage].
  const Abandoned(this.date, this.currentPage);

  @override
  final DateTime date;

  @override
  final int currentPage;

  @override
  String get label => 'кинуто';

  @override
  String toCsvField() =>
      '$_abandonedPrefix:${date.toIsoDateString()}:$currentPage';

  @override
  bool operator ==(Object other) =>
      other is Abandoned &&
      other.date == date &&
      other.currentPage == currentPage;

  @override
  int get hashCode => Object.hash(Abandoned, date, currentPage);

  @override
  String toString() => 'Abandoned(${date.toIsoDateString()}, $currentPage)';
}

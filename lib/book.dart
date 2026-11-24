import 'extensions.dart';
import 'genre.dart';
import 'identifiable.dart';
import 'reading_status.dart';

const _fieldDelimiter = ';';
const _fieldCount = 6;
const _earliestPublicationYear = 1450;
const _maximumPageCount = 10000;
const _longBookPageCount = 400;
const _yearsPerCentury = 100;

/// Результат розбору одного вхідного рядка: книга або опис помилки.
typedef BookParseResult = ({Book? book, String? error});

/// Функція порівняння двох книг для сортування.
typedef BookComparator = int Function(Book left, Book right);

/// Книга домашньої бібліотеки.
///
/// Клас незмінний: усі поля `final`, а конструктор константний. Дві книги з
/// однаковими значеннями полів вважаються рівними.
final class Book implements Identifiable {
  /// Створює книгу із заданими значеннями полів.
  const Book({
    required this.author,
    required this.title,
    required this.publicationYear,
    required this.pageCount,
    required this.genre,
    required this.status,
  }) : assert(author != ''),
       assert(title != '');

  /// Розбирає книгу з рядка [line] у форматі
  /// `автор;назва;рік;сторінки;жанр;стан`.
  ///
  /// Кидає [FormatException], якщо рядок не відповідає формату. Для даних,
  /// у яких помилка очікувана, слід використовувати [Book.tryParse].
  factory Book.fromCsv(String line) {
    final (:book, :error) = tryParse(line);
    if (book != null) return book;
    throw FormatException(error ?? 'рядок не розібрано', line);
  }

  /// Повертає книгу з рядка [line], розібрану один раз і збережену в кеші.
  ///
  /// Повторний виклик з тим самим рядком повертає той самий екземпляр.
  factory Book.cached(String line) =>
      _cache.putIfAbsent(line.trim(), () => Book.fromCsv(line));

  static final Map<String, Book> _cache = {};

  /// Розбирає [line] без винятків: повертає книгу або опис помилки.
  static BookParseResult tryParse(String line) {
    final fields = line
        .split(_fieldDelimiter)
        .map((field) => field.trim())
        .toList(growable: false);

    if (fields.length != _fieldCount) {
      return (
        book: null,
        error: 'очікується $_fieldCount полів, отримано ${fields.length}',
      );
    }
    if (fields.any((field) => field.isEmpty)) {
      return (book: null, error: 'одне з обов’язкових полів порожнє');
    }

    final [author, title, yearText, pagesText, genreText, statusText] = fields;

    final publicationYear = int.tryParse(yearText);
    if (publicationYear == null) {
      return (book: null, error: 'рік видання «$yearText» не є цілим числом');
    }
    final pageCount = int.tryParse(pagesText);
    if (pageCount == null) {
      return (
        book: null,
        error: 'кількість сторінок «$pagesText» не є цілим числом',
      );
    }
    final genre = Genre.tryParse(genreText);
    if (genre == null) {
      return (book: null, error: 'невідомий жанр «$genreText»');
    }
    final status = ReadingStatus.tryParse(statusText);
    if (status == null) {
      return (book: null, error: 'стан читання «$statusText» некоректний');
    }

    return (
      book: Book(
        author: author,
        title: title,
        publicationYear: publicationYear,
        pageCount: pageCount,
        genre: genre,
        status: status,
      ),
      error: null,
    );
  }

  /// Порівнює книги за роком видання, а за однакового року — за назвою.
  static int compareByPublicationYear(Book left, Book right) {
    final byYear = left.publicationYear.compareTo(right.publicationYear);
    return byYear != 0 ? byYear : left.title.compareTo(right.title);
  }

  /// Порівнює книги за назвою, а за однакової назви — за автором.
  static int compareByTitle(Book left, Book right) {
    final byTitle = left.title.compareTo(right.title);
    return byTitle != 0 ? byTitle : left.author.compareTo(right.author);
  }

  /// Автор книги.
  final String author;

  /// Назва книги.
  final String title;

  /// Рік видання.
  final int publicationYear;

  /// Кількість сторінок.
  final int pageCount;

  /// Жанр.
  final Genre genre;

  /// Стан читання.
  final ReadingStatus status;

  @override
  String get id =>
      '${author.toLowerCase()}|${title.toLowerCase()}|$publicationYear';

  /// Чи має книга щонайменше 400 сторінок.
  bool get isLong => pageCount >= _longBookPageCount;

  /// Століття, у якому видано книгу.
  int get century => (publicationYear - 1) ~/ _yearsPerCentury + 1;

  /// Кількість прочитаних сторінок відповідно до стану читання.
  int get pagesRead => (status.completion(pageCount) * pageCount).round();

  /// Повертає перелік порушень правил предметної області.
  ///
  /// [referenceDate] задає «поточну» дату перевірки; якщо її не передано,
  /// використовується поточний момент.
  List<String> violations({DateTime? referenceDate}) {
    final currentDate = referenceDate ?? DateTime.now();
    final errors = <String>[];

    final yearIsValid =
        publicationYear >= _earliestPublicationYear &&
        publicationYear <= currentDate.year;
    if (!yearIsValid) {
      errors.add(
        'рік видання має бути в межах '
        '$_earliestPublicationYear–${currentDate.year}',
      );
    }
    if (pageCount <= 0 || pageCount > _maximumPageCount) {
      errors.add('кількість сторінок має бути від 1 до $_maximumPageCount');
    }
    if (!author.isFullName) {
      errors.add('автор має містити щонайменше ім’я та прізвище');
    }

    if (status case DatedStatus(:final date, :final label)) {
      if (date.isAfter(currentDate)) {
        errors.add('дата стану «$label» не може бути в майбутньому');
      } else if (yearIsValid && date.isBefore(DateTime(publicationYear))) {
        errors.add('дата стану «$label» не може передувати року видання');
      }
    }
    if (status case PageProgress(:final currentPage)
        when currentPage > pageCount) {
      errors.add('поточна сторінка $currentPage більша за обсяг книги');
    }

    return List.unmodifiable(errors);
  }

  /// Подає книгу у форматі вхідного рядка.
  String toCsv() => [
    author,
    title,
    publicationYear,
    pageCount,
    genre.label,
    status.toCsvField(),
  ].join(_fieldDelimiter);

  @override
  bool operator ==(Object other) =>
      other is Book &&
      other.author == author &&
      other.title == title &&
      other.publicationYear == publicationYear &&
      other.pageCount == pageCount &&
      other.genre == genre &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(author, title, publicationYear, pageCount, genre, status);

  @override
  String toString() =>
      'Book($author, «$title», $publicationYear, $pageCount с., '
      '${genre.label}, ${status.label})';
}

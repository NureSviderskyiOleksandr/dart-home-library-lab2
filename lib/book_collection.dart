import 'book.dart';
import 'genre.dart';

/// Мінімальна, максимальна й середня кількість сторінок у наборі книг.
typedef PageStatistics = ({int min, int max, double average});

/// Створює предикат, який залишає книги не тонші за [minimumPages].
///
/// Повернене замикання захоплює значення [minimumPages] і зберігає його між
/// викликами предиката.
bool Function(Book book) makeMinimumPageCountPredicate(int minimumPages) =>
    (book) => book.pageCount >= minimumPages;

/// Агрегування та впорядкування колекцій книг.
///
/// Функції обробки колекцій з лабораторної роботи 1 стали членами розширення:
/// вони викликаються через крапку на будь-якому `Iterable<Book>`.
extension BookCollection on Iterable<Book> {
  /// Загальна кількість сторінок.
  int get totalPages =>
      map((book) => book.pageCount).fold(0, (total, pages) => total + pages);

  /// Статистика сторінок або `null` для порожньої колекції.
  PageStatistics? get pageStatistics {
    if (isEmpty) return null;
    final pages = map((book) => book.pageCount);
    return (
      min: pages.reduce((a, b) => a < b ? a : b),
      max: pages.reduce((a, b) => a > b ? a : b),
      average: totalPages / length,
    );
  }

  /// Книги, що мають щонайменше [minimumPages] сторінок.
  Iterable<Book> withMinimumPages(int minimumPages) =>
      where(makeMinimumPageCountPredicate(minimumPages));

  /// Сторінки у книгах, виданих не раніше [year].
  ///
  /// Агрегування побудоване як конвеєр `where → map → fold`.
  int pagesPublishedSince(int year) =>
      where((book) => book.publicationYear >= year)
          .map((book) => book.pageCount)
          .fold(0, (total, pages) => total + pages);

  /// Групує книги за жанром.
  Map<Genre, List<Book>> groupByGenre() {
    final groups = fold(<Genre, List<Book>>{}, (result, book) {
      result.putIfAbsent(book.genre, () => <Book>[]).add(book);
      return result;
    });
    return Map.unmodifiable(
      groups.map(
        (genre, books) => MapEntry(genre, List<Book>.unmodifiable(books)),
      ),
    );
  }

  /// Середня кількість сторінок для кожного жанру.
  Map<Genre, double> averagePagesByGenre() => Map.unmodifiable(
    groupByGenre().map(
      (genre, books) => MapEntry(genre, books.totalPages / books.length),
    ),
  );

  /// Повертає відсортовану копію колекції.
  ///
  /// [comparator] задає критерій, а [ascending] — напрям сортування.
  List<Book> sortedBy(BookComparator comparator, {bool ascending = true}) {
    final result = toList()
      ..sort(
        (left, right) =>
            ascending ? comparator(left, right) : comparator(right, left),
      );
    return List.unmodifiable(result);
  }
}

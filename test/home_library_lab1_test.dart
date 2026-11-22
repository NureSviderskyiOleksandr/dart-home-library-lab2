import 'package:home_library_lab1/home_library_lab1.dart';
import 'package:test/test.dart';

void main() {
  final referenceDate = DateTime(2026, 11, 22);

  final book = (
    author: 'Тестовий Автор',
    title: 'Тестова книга',
    publicationYear: 2020,
    pageCount: 320,
    genre: 'тест',
    readDate: DateTime(2025, 11, 22),
  );

  group('parseBook', () {
    test('розбирає коректний CSV-подібний рядок', () {
      final result = parseBook(
        'Тестовий Автор;Тестова книга;2020;320;тест;2025-11-22',
      );

      expect(result.error, isNull);
      expect(result.book, book);
    });

    test('повертає помилку для відсутнього поля', () {
      final result = parseBook('Автор;Назва;2020;320;тест');

      expect(result.book, isNull);
      expect(result.error, contains('очікується 6 полів'));
    });

    test('відокремлює коректні книги від помилок', () {
      final result = parseBookLines(<String>[
        'Тестовий Автор;Тестова книга;2020;320;тест;2025-11-22',
        'Автор;Назва;рік;320;тест;2025-11-22',
      ]);

      expect(result.books, hasLength(1));
      expect(result.errors, hasLength(1));
    });
  });

  group('validateBook', () {
    test('не знаходить порушень у коректній книзі', () {
      expect(validateBook(book, referenceDate: referenceDate), isEmpty);
    });

    test('повертає всі порушення діапазонів і дат', () {
      final invalidBook = (
        author: 'Автор',
        title: 'Помилкова книга',
        publicationYear: 2027,
        pageCount: 0,
        genre: 'тест',
        readDate: DateTime(2027, 1, 1),
      );

      final errors = validateBook(invalidBook, referenceDate: referenceDate);

      expect(errors, hasLength(4));
      expect(errors.join(' '), contains('рік видання'));
      expect(errors.join(' '), contains('кількість сторінок'));
      expect(errors.join(' '), contains('автор'));
      expect(errors.join(' '), contains('майбутньому'));
    });
  });

  group('допоміжні функції', () {
    test('маскує ім’я автора та зберігає прізвище', () {
      expect(maskAuthor('Тестовий Автор'), 'Т******* Автор');
    });

    test('обчислює кількість днів після прочитання', () {
      expect(daysSinceRead(book, referenceDate: referenceDate), 365);
    });
  });

  group('обробка колекцій', () {
    final olderBook = (
      author: 'Перший Автор',
      title: 'Альфа',
      publicationYear: 2000,
      pageCount: 200,
      genre: 'роман',
      readDate: DateTime(2025, 1, 1),
    );
    final newerBook = (
      author: 'Другий Автор',
      title: 'Бета',
      publicationYear: 2020,
      pageCount: 400,
      genre: 'роман',
      readDate: DateTime(2025, 2, 1),
    );
    final books = <Book>[olderBook, newerBook];

    test('фільтрує та агрегує записи конвеєрами', () {
      expect(filterBooksByMinimumPages(books, minimumPages: 300), [newerBook]);
      expect(totalPagesPublishedSince(books, publicationYear: 2010), 400);
      expect(formatBookLabels([newerBook]), ['Другий Автор — «Бета» (400 с.)']);
    });

    test('групує книги та обчислює середню кількість сторінок', () {
      final groups = groupBooksByGenre(books);
      final averages = averagePagesByGenre(groups);

      expect(groups['роман'], books);
      expect(averages['роман'], 300);
    });

    test('сортує копію списку в обох напрямах', () {
      final ascending = sortBooks(books, compareBooksByPublicationYear);
      final descending = sortBooks(
        books,
        compareBooksByTitle,
        ascending: false,
      );

      expect(ascending, [olderBook, newerBook]);
      expect(descending, [newerBook, olderBook]);
      expect(books, [olderBook, newerBook]);
    });

    test('замикання захоплює мінімальну кількість сторінок', () {
      final isLargeBook = makeMinimumPageCountPredicate(300);

      expect(isLargeBook(olderBook), isFalse);
      expect(isLargeBook(newerBook), isTrue);
    });
  });
}

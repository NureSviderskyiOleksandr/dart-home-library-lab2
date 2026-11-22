import 'package:home_library/home_library.dart';
import 'package:test/test.dart';

void main() {
  final referenceDate = DateTime(2026, 11, 22);
  const line = 'Тестовий Автор;Тестова книга;2020;320;роман;2025-11-22';

  final book = Book(
    author: 'Тестовий Автор',
    title: 'Тестова книга',
    publicationYear: 2020,
    pageCount: 320,
    genre: Genre.novel,
    status: Finished(DateTime(2025, 11, 22)),
  );

  group('Book.fromCsv і Book.tryParse', () {
    test('розбирає коректний рядок', () {
      expect(Book.fromCsv(line), book);
    });

    test('повертає помилку для відсутнього поля', () {
      final (:book, :error) = Book.tryParse('Автор;Назва;2020;320;роман');

      expect(book, isNull);
      expect(error, contains('очікується 6 полів'));
    });

    test('відхиляє невідомий жанр і неіснуючу дату', () {
      expect(
        Book.tryParse('А Б;Назва;2020;320;кулінарія;2025-01-01').error,
        contains('невідомий жанр'),
      );
      expect(
        Book.tryParse('А Б;Назва;2020;320;роман;2025-02-30').error,
        contains('стан читання'),
      );
    });

    test('fromCsv кидає FormatException для пошкодженого рядка', () {
      expect(
        () => Book.fromCsv('А Б;Назва;рік;320;роман;2025-01-01'),
        throwsFormatException,
      );
    });

    test('toCsv відтворює вхідний рядок', () {
      expect(book.toCsv(), line);
    });
  });

  group('рівність і фабричний конструктор', () {
    test('однакові книги рівні й мають однаковий hashCode', () {
      final copy = Book.fromCsv(line);

      expect(copy, book);
      expect(copy.hashCode, book.hashCode);
      expect({book, copy}, hasLength(1));
    });

    test('Book.cached повертає той самий екземпляр', () {
      expect(identical(Book.cached(line), Book.cached(line)), isTrue);
      expect(identical(Book.fromCsv(line), Book.fromCsv(line)), isFalse);
    });
  });

  group('обчислювані властивості й валідація', () {
    test('гетери обчислюють похідні значення', () {
      expect(book.century, 21);
      expect(book.isLong, isFalse);
      expect(book.pagesRead, 320);
    });

    test('коректна книга не має порушень', () {
      expect(book.violations(referenceDate: referenceDate), isEmpty);
    });

    test('повертає всі порушення діапазонів і дат', () {
      final invalid = Book(
        author: 'Автор',
        title: 'Помилкова книга',
        publicationYear: 2027,
        pageCount: 0,
        genre: Genre.reference,
        status: Finished(DateTime(2027, 1, 1)),
      );

      expect(invalid.violations(referenceDate: referenceDate), hasLength(4));
    });
  });

  group('Genre', () {
    test('tryParse знаходить жанр без урахування регістру', () {
      expect(Genre.tryParse(' Роман '), Genre.novel);
      expect(Genre.tryParse('кулінарія'), isNull);
    });

    test('describe позначає нехудожню літературу', () {
      expect(Genre.reference.describe(), 'довідкова (нехудожня)');
      expect(Genre.novel.describe(), 'роман');
    });
  });

  group('розширення', () {
    test('маскує ім’я автора та зберігає прізвище', () {
      expect('Тестовий Автор'.maskedName, 'Т******* Автор');
      expect('ОдинАвтор'.isFullName, isFalse);
    });

    test('форматує дату та рахує дні', () {
      final date = DateTime(2025, 11, 22);

      expect(date.toIsoDateString(), '2025-11-22');
      expect(date.daysUntil(referenceDate), 365);
      expect(IsoDate.tryParseStrict('2025-02-30'), isNull);
    });
  });
}

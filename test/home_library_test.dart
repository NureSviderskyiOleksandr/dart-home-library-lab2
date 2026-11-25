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

  group('ReadingStatus', () {
    test('розбирає всі форми поля стану', () {
      expect(ReadingStatus.tryParse('в планах'), const Planned());
      expect(ReadingStatus.tryParse('читаю:120'), const Reading(120));
      expect(
        ReadingStatus.tryParse('2025-01-12'),
        Finished(DateTime(2025, 1, 12)),
      );
      expect(
        ReadingStatus.tryParse('кинуто:2025-09-01:95'),
        Abandoned(DateTime(2025, 9, 1), 95),
      );
      expect(ReadingStatus.tryParse('колись'), isNull);
      expect(ReadingStatus.tryParse('кинуто:2025-02-30:10'), isNull);
    });

    test('toCsvField є оберненим до tryParse', () {
      final statuses = <ReadingStatus>[
        const Planned(),
        const Reading(7),
        Finished(DateTime(2024, 2, 29)),
        Abandoned(DateTime(2025, 9, 1), 95),
      ];
      for (final status in statuses) {
        expect(ReadingStatus.tryParse(status.toCsvField()), status);
      }
    });

    test('completion поліморфний для всіх підтипів', () {
      expect(const Planned().completion(200), 0);
      expect(const Reading(50).completion(200), 0.25);
      expect(Finished(DateTime(2025)).completion(200), 1);
      expect(Abandoned(DateTime(2025), 300).completion(200), 1);
    });

    test('домішки додають спільну поведінку різним підтипам', () {
      final abandoned = Abandoned(DateTime(2026, 11, 12), 50);

      expect(abandoned.daysSince(referenceDate), 10);
      expect(abandoned.dateLabel, 'кинуто 2026-11-12');
      expect(abandoned.progressLabel(200), 'кинуто на стор. 50 з 200 (25 %)');
      expect(const Reading(50).progressLabel(200), startsWith('читається'));
      expect(Finished(DateTime(2026, 11, 1)).daysSince(referenceDate), 21);
    });

    test('валідація перевіряє дати й сторінки через домішки', () {
      final abandoned = Book(
        author: 'Тестовий Автор',
        title: 'Кинута книга',
        publicationYear: 2020,
        pageCount: 100,
        genre: Genre.novel,
        status: Abandoned(DateTime(2019, 1, 1), 150),
      );

      expect(abandoned.violations(referenceDate: referenceDate), [
        'дата стану «кинуто» не може передувати року видання',
        'поточна сторінка 150 більша за обсяг книги',
      ]);
    });
  });

  group('describeStatus', () {
    String describe(ReadingStatus status) =>
        describeStatus(status, pageCount: 200, referenceDate: referenceDate);

    test('використовує охоронця when для книг цього року', () {
      expect(
        describe(Finished(DateTime(2026, 3, 1))),
        'прочитано цього року (2026-03-01)',
      );
      expect(
        describe(Finished(DateTime(2025, 11, 22))),
        'прочитано 2025-11-22, 365 дн. тому',
      );
    });

    test('описує кожен підтип', () {
      expect(describe(const Planned()), 'у планах');
      expect(describe(const Reading(100)), contains('50 %'));
      expect(describe(Abandoned(DateTime(2025, 9, 1), 20)), contains('кинуто'));
    });
  });

  group('Repository', () {
    test('індексує елементи за id і замінює дублікати', () {
      final repository = Repository<Book>([book]);

      expect(repository.findById(book.id), same(book));
      expect(repository.add(Book.fromCsv(line)), isFalse);
      expect(repository.length, 1);
      expect(repository.remove(book.id), isTrue);
      expect(repository.isEmpty, isTrue);
    });

    test('працює з будь-яким типом, що реалізує Identifiable', () {
      final repository = Repository<_Shelf>()
        ..add(const _Shelf('a', 'Кухня'))
        ..add(const _Shelf('b', 'Кабінет'));

      expect(repository.findById('b')?.name, 'Кабінет');
      expect(
        repository.where((shelf) => shelf.name.startsWith('К')),
        hasLength(2),
      );
      expect(repository.findById('c'), isNull);
    });
  });

  group('BookCollection і звіт', () {
    final books = [
      book,
      Book.fromCsv('Інший Автор;Альфа;1990;500;роман;в планах'),
      Book.fromCsv('Третій Автор;Бета;2010;180;поезія;читаю:20'),
    ];

    test('агрегує колекцію через члени розширення', () {
      expect(books.totalPages, 1000);
      expect(books.withMinimumPages(300), hasLength(2));
      expect(books.pagesPublishedSince(2000), 500);
      expect(books.averagePagesByGenre()[Genre.novel], 410);
      expect(books.groupByGenre()[Genre.poetry], hasLength(1));
    });

    test('повертає статистику записом із деструктуризацією', () {
      switch (books.pageStatistics) {
        case (:final min, :final max, :final average):
          expect((min, max), (180, 500));
          expect(average, closeTo(333.3, 0.1));
        case null:
          fail('статистика непорожньої колекції не може бути null');
      }
      expect(<Book>[].pageStatistics, isNull);
    });

    test('сортує копію за двома критеріями', () {
      expect(
        books.sortedBy(Book.compareByPublicationYear).first.title,
        'Альфа',
      );
      expect(
        books.sortedBy(Book.compareByTitle, ascending: false).first.title,
        'Тестова книга',
      );
      expect(books.first, book);
    });

    test('parseBooks відокремлює книги від помилок', () {
      final (:books, :errors) = parseBooks([line, 'зламаний рядок']);

      expect(books, [book]);
      expect(errors, ['Рядок 2: очікується 6 полів, отримано 1.']);
    });

    test('звіт за демонстраційними даними містить усі розділи', () {
      final report = buildReport(bookInputLines, referenceDate: referenceDate);

      expect(report, contains('Не розібрано: 6.'));
      expect(report, contains('Не пройшли валідацію: 4.'));
      expect(report, contains('«Улісс» — кинуто'));
      expect(report, contains('Середня кількість сторінок за жанрами:'));
    });

    test('константний конструктор створює канонічний екземпляр', () {
      const first = Book(
        author: 'Константний Автор',
        title: 'Книга',
        publicationYear: 2000,
        pageCount: 100,
        genre: Genre.poetry,
        status: Planned(),
      );
      const second = Book(
        author: 'Константний Автор',
        title: 'Книга',
        publicationYear: 2000,
        pageCount: 100,
        genre: Genre.poetry,
        status: Planned(),
      );

      expect(identical(first, second), isTrue);
    });
  });
}

class _Shelf implements Identifiable {
  const _Shelf(this.id, this.name);

  @override
  final String id;

  final String name;
}

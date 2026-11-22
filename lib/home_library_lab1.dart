const _fieldDelimiter = ';';
const _bookFieldCount = 6;
const _earliestPublicationYear = 1450;
const _maximumPageCount = 10000;

final _authorPattern = RegExp(
  r'^(?<initial>\S)(?<hidden>\S*)(?<surname>\s+\S(?:.*\S)?)$',
  unicode: true,
);

/// Книга домашньої бібліотеки без використання класу.
typedef Book = ({
  String author,
  String title,
  int publicationYear,
  int pageCount,
  String genre,
  DateTime readDate,
});

/// Результат розбору одного вхідного рядка.
typedef BookParseResult = ({Book? book, String? error});

/// Результат розбору всього набору вхідних рядків.
typedef BookListParseResult = ({List<Book> books, List<String> errors});

/// Результат перевірки однієї книги.
typedef BookValidationResult = ({Book book, List<String> errors});

/// Функція порівняння двох книг для повторного використання в сортуванні.
typedef BookComparator = int Function(Book left, Book right);

/// Вхідні дані у CSV-подібному форматі з роздільником `;`.
///
/// Три записи перед пошкодженими рядками містять порушення правил валідації.
/// Чотири останні рядки не розбираються: у них відсутнє поле, нечисловий рік,
/// нечислова кількість сторінок і некоректна дата.
const bookInputLines = <String>[
  'Джордж Орвелл;1984;1949;328;антиутопія;2025-01-12',
  'Рей Бредбері;451 градус за Фаренгейтом;1953;256;антиутопія;2025-02-03',
  'Френк Герберт;Дюна;1965;656;фантастика;2025-02-21',
  'Джон Толкін;Гобіт;1937;304;фентезі;2025-03-15',
  'Агата Крісті;Вбивство у Східному експресі;1934;288;детектив;2025-04-08',
  'Артур Конан Дойл;Собака Баскервілів;1902;256;детектив;2025-04-27',
  'Еріх Марія Ремарк;Три товариші;1936;480;роман;2025-05-19',
  'Джейн Остін;Гордість і упередження;1813;416;роман;2025-06-02',
  'Оскар Вайлд;Портрет Доріана Грея;1890;320;роман;2025-06-20',
  'Маркус Зузак;Крадійка книжок;2005;576;роман;2025-07-14',
  'Деніел Кіз;Квіти для Елджернона;1966;312;фантастика;2025-08-01',
  'Стівен Кінг;Зелена миля;1996;432;містика;2025-08-24',
  'Іван Багряний;Тигролови;1944;304;пригоди;2025-09-11',
  'Валер\u0027ян Підмогильний;Місто;1928;352;роман;2025-10-05',
  'ОдинАвтор;Таємнича книга;2022;220;містика;2025-10-18',
  'Тестовий Автор;Нуль сторінок;2021;0;довідкова;2025-10-20',
  'Майбутній Автор;Книга з майбутнього;2027;300;фантастика;2027-01-10',
  'Ліна Костенко;Маруся Чурай;1979;224;історичний роман',
  'Сергій Жадан;Інтернат;дві тисячі сімнадцять;336;роман;2025-10-22',
  'Макс Кідрук;Колонія;2023;шістсот;фантастика;2025-11-02',
  'Тарас Шевченко;Кобзар;1840;384;поезія;невідома дата',
];

/// Розбирає [line] у запис [Book].
///
/// Повертає опис очікуваної помилки замість аварійного завершення програми.
BookParseResult parseBook(String line) {
  final fields = line
      .split(_fieldDelimiter)
      .map((field) => field.trim())
      .toList();

  if (fields.length != _bookFieldCount) {
    return (
      book: null,
      error: 'очікується $_bookFieldCount полів, отримано ${fields.length}',
    );
  }

  if (fields.any((field) => field.isEmpty)) {
    return (book: null, error: 'одне з обов’язкових полів порожнє');
  }

  final publicationYear = int.tryParse(fields[2]);
  if (publicationYear == null) {
    return (book: null, error: 'рік видання «${fields[2]}» не є цілим числом');
  }

  final pageCount = int.tryParse(fields[3]);
  if (pageCount == null) {
    return (
      book: null,
      error: 'кількість сторінок «${fields[3]}» не є цілим числом',
    );
  }

  final readDate = DateTime.tryParse(fields[5]);
  if (readDate == null) {
    return (book: null, error: 'дата прочитання «${fields[5]}» некоректна');
  }

  return (
    book: (
      author: fields[0],
      title: fields[1],
      publicationYear: publicationYear,
      pageCount: pageCount,
      genre: fields[4],
      readDate: readDate,
    ),
    error: null,
  );
}

/// Розбирає [lines] і окремо повертає коректні книги та описи помилок.
BookListParseResult parseBookLines(Iterable<String> lines) {
  final parsedLines = lines.indexed
      .map((entry) {
        final (index, line) = entry;
        return (lineNumber: index + 1, result: parseBook(line));
      })
      .toList(growable: false);

  final books = parsedLines
      .map((entry) => entry.result.book)
      .whereType<Book>()
      .toList(growable: false);

  final errors = parsedLines
      .map((entry) {
        final error = entry.result.error;
        return error == null ? null : 'Рядок ${entry.lineNumber}: $error.';
      })
      .whereType<String>()
      .toList(growable: false);

  return (books: books, errors: errors);
}

/// Перевіряє діапазони значень і формат автора в [book].
///
/// [referenceDate] дає змогу виконувати перевірку відносно заданої дати.
/// Якщо її не передано, використовується поточний момент.
List<String> validateBook(Book book, {DateTime? referenceDate}) {
  final currentDate = referenceDate ?? DateTime.now();
  final errors = <String>[];

  final publicationYearIsValid =
      book.publicationYear >= _earliestPublicationYear &&
      book.publicationYear <= currentDate.year;
  if (!publicationYearIsValid) {
    errors.add(
      'рік видання має бути в межах '
      '$_earliestPublicationYear–${currentDate.year}',
    );
  }

  if (book.pageCount <= 0 || book.pageCount > _maximumPageCount) {
    errors.add('кількість сторінок має бути від 1 до $_maximumPageCount');
  }

  if (!_authorPattern.hasMatch(book.author)) {
    errors.add('автор має містити щонайменше ім’я та прізвище');
  }

  if (book.readDate.isAfter(currentDate)) {
    errors.add('дата прочитання не може бути в майбутньому');
  }

  if (publicationYearIsValid &&
      book.readDate.isBefore(DateTime(book.publicationYear))) {
    errors.add('дата прочитання не може передувати року видання');
  }

  return List.unmodifiable(errors);
}

/// Перевіряє всі [books] і повертає помилки для кожного запису.
List<BookValidationResult> validateBooks(
  Iterable<Book> books, {
  DateTime? referenceDate,
}) => books
    .map(
      (book) => (
        book: book,
        errors: validateBook(book, referenceDate: referenceDate),
      ),
    )
    .toList(growable: false);

/// Маскує частину імені автора, зберігаючи першу літеру та прізвище.
///
/// Для пошуку частин імені використовується регулярний вираз з іменованими
/// групами, а заміна виконується через `replaceAllMapped`.
String maskAuthor(String author) =>
    author.replaceAllMapped(_authorPattern, (match) {
      final regexMatch = match as RegExpMatch;
      final initial = regexMatch.namedGroup('initial') ?? '';
      final hidden = regexMatch.namedGroup('hidden') ?? '';
      final surname = regexMatch.namedGroup('surname') ?? '';
      final mask = List.filled(hidden.runes.length, '*').join();
      return '$initial$mask$surname';
    });

/// Обчислює кількість повних днів від прочитання [book].
int daysSinceRead(Book book, {DateTime? referenceDate}) {
  final currentDate = referenceDate ?? DateTime.now();
  final age = currentDate.difference(book.readDate);
  return age.inDays;
}

/// Створює предикат, який залишає книги не тонші за [minimumPages].
///
/// Повернене замикання захоплює значення [minimumPages] і зберігає його між
/// викликами предиката.
bool Function(Book) makeMinimumPageCountPredicate(int minimumPages) =>
    (book) => book.pageCount >= minimumPages;

/// Фільтрує [books] за мінімальною кількістю сторінок.
List<Book> filterBooksByMinimumPages(
  Iterable<Book> books, {
  int minimumPages = 300,
}) => books
    .where(makeMinimumPageCountPredicate(minimumPages))
    .toList(growable: false);

/// Перетворює [books] на короткі текстові описи.
List<String> formatBookLabels(Iterable<Book> books) => books
    .map((book) => '${book.author} — «${book.title}» (${book.pageCount} с.)')
    .toList(growable: false);

/// Підраховує сторінки у книгах, виданих не раніше [publicationYear].
///
/// Агрегація побудована як конвеєр `where → map → fold`.
int totalPagesPublishedSince(
  Iterable<Book> books, {
  int publicationYear = 1950,
}) => books
    .where((book) => book.publicationYear >= publicationYear)
    .map((book) => book.pageCount)
    .fold(0, (total, pageCount) => total + pageCount);

/// Групує [books] за жанром.
Map<String, List<Book>> groupBooksByGenre(Iterable<Book> books) {
  final groups = books.fold(<String, List<Book>>{}, (result, book) {
    result.putIfAbsent(book.genre, () => <Book>[]).add(book);
    return result;
  });

  return Map<String, List<Book>>.unmodifiable(
    groups.map<String, List<Book>>(
      (genre, genreBooks) =>
          MapEntry(genre, List<Book>.unmodifiable(genreBooks)),
    ),
  );
}

/// Обчислює середню кількість сторінок для кожної групи в [groups].
Map<String, double> averagePagesByGenre(Map<String, List<Book>> groups) =>
    Map<String, double>.unmodifiable(
      groups.map<String, double>((genre, books) {
        final totalPages = books
            .map((book) => book.pageCount)
            .fold(0, (total, pageCount) => total + pageCount);
        return MapEntry(genre, totalPages / books.length);
      }),
    );

/// Порівнює книги спочатку за роком видання, потім за назвою.
int compareBooksByPublicationYear(Book left, Book right) {
  final byYear = left.publicationYear.compareTo(right.publicationYear);
  return byYear != 0 ? byYear : left.title.compareTo(right.title);
}

/// Порівнює книги спочатку за назвою, потім за автором.
int compareBooksByTitle(Book left, Book right) {
  final byTitle = left.title.compareTo(right.title);
  return byTitle != 0 ? byTitle : left.author.compareTo(right.author);
}

/// Повертає відсортовану копію [books], не змінюючи початкову колекцію.
///
/// [comparator] задає критерій, а [ascending] — напрям сортування.
List<Book> sortBooks(
  Iterable<Book> books,
  BookComparator comparator, {
  bool ascending = true,
}) {
  final result = books.toList();
  result.sort((left, right) {
    return ascending ? comparator(left, right) : comparator(right, left);
  });
  return List.unmodifiable(result);
}

/// Запускає консольний застосунок «Домашня бібліотека».
void runApplication() {
  final parseResult = parseBookLines(bookInputLines);
  final referenceDate = DateTime.now();
  final validationResults = validateBooks(
    parseResult.books,
    referenceDate: referenceDate,
  );
  final validBooks = validationResults
      .where((result) => result.errors.isEmpty)
      .toList(growable: false);
  final invalidBooks = validationResults
      .where((result) => result.errors.isNotEmpty)
      .toList(growable: false);
  final books = validBooks.map((result) => result.book).toList(growable: false);

  print('Домашня бібліотека');
  print('Отримано рядків: ${bookInputLines.length}.');
  print('Успішно розібрано: ${parseResult.books.length}.');
  print('Не розібрано: ${parseResult.errors.length}.');
  print('Пройшли валідацію: ${validBooks.length}.');
  print('Не пройшли валідацію: ${invalidBooks.length}.');

  if (parseResult.errors.isNotEmpty) {
    print('\nПомилки вхідних даних:');
    parseResult.errors.forEach(print);
  }

  if (invalidBooks.isNotEmpty) {
    print('\nПорушення правил валідації:');
    for (final result in invalidBooks) {
      final author = maskAuthor(result.book.author);
      print('$author — ${result.book.title}: ${result.errors.join('; ')}.');
    }
  }

  if (validBooks.isNotEmpty) {
    final sample = validBooks.first.book;
    final age = daysSinceRead(sample, referenceDate: referenceDate);
    print(
      '\nПриклад маскування: ${maskAuthor(sample.author)}. '
      'Від прочитання книги «${sample.title}» минуло $age днів.',
    );
  }

  final largeBooks = filterBooksByMinimumPages(books, minimumPages: 400);
  final largeBookLabels = formatBookLabels(largeBooks);
  final modernPageCount = totalPagesPublishedSince(
    books,
    publicationYear: 1950,
  );
  final booksByGenre = groupBooksByGenre(books);
  final averagesByGenre = averagePagesByGenre(booksByGenre);
  final sortedAverages = averagesByGenre.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final oldestFirst = sortBooks(books, compareBooksByPublicationYear);
  final titleDescending = sortBooks(
    books,
    compareBooksByTitle,
    ascending: false,
  );

  print('\nКниги від 400 сторінок:');
  largeBookLabels.forEach(print);
  print('Сторінок у книгах, виданих від 1950 року: $modernPageCount.');

  print('\nСередня кількість сторінок за жанрами:');
  for (final entry in sortedAverages) {
    print('${entry.key}: ${entry.value.toStringAsFixed(1)}.');
  }

  if (oldestFirst.isNotEmpty && titleDescending.isNotEmpty) {
    print(
      '\nНайраніша за роком видання: ${oldestFirst.first.title} '
      '(${oldestFirst.first.publicationYear}).',
    );
    print(
      'Перша за назвою у зворотному порядку: '
      '${titleDescending.first.title}.',
    );
  }
}

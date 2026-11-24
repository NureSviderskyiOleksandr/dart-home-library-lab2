import 'book.dart';
import 'book_collection.dart';
import 'extensions.dart';
import 'reading_status.dart';
import 'repository.dart';

const _largeBookPageCount = 400;
const _modernEraStartYear = 1950;
const _decimalPlaces = 1;

/// Результат розбору всього набору рядків: коректні книги й описи помилок.
typedef BookListParseResult = ({List<Book> books, List<String> errors});

/// Розбирає [lines] і окремо повертає коректні книги та описи помилок.
BookListParseResult parseBooks(Iterable<String> lines) {
  final books = <Book>[];
  final errors = <String>[];
  for (final (index, line) in lines.indexed) {
    switch (Book.tryParse(line)) {
      case (:final Book book, error: _):
        books.add(book);
      case (book: null, :final error):
        errors.add('Рядок ${index + 1}: ${error ?? 'невідома помилка'}.');
    }
  }
  return (books: List.unmodifiable(books), errors: List.unmodifiable(errors));
}

/// Описує стан читання книги з [pageCount] сторінками відносно
/// [referenceDate].
///
/// Switch-вираз не має гілки `default`: вичерпність перевіряє компілятор,
/// оскільки [ReadingStatus] — запечатаний клас.
String describeStatus(
  ReadingStatus status, {
  required int pageCount,
  required DateTime referenceDate,
}) => switch (status) {
  Planned() => status.label,
  final Reading reading => reading.progressLabel(pageCount),
  Finished(:final date) when date.year == referenceDate.year =>
    'прочитано цього року (${date.toIsoDateString()})',
  final Finished finished =>
    '${finished.dateLabel}, ${finished.daysSince(referenceDate)} дн. тому',
  final Abandoned abandoned =>
    '${abandoned.progressLabel(pageCount)}, '
        '${abandoned.date.toIsoDateString()}',
};

/// Формує текстовий звіт про бібліотеку за вхідними рядками [lines].
///
/// [referenceDate] задає дату, відносно якої перевіряються дати й рахуються
/// дні; [maskAuthors] вмикає маскування імен авторів у переліку порушень.
String buildReport(
  Iterable<String> lines, {
  required DateTime referenceDate,
  bool maskAuthors = true,
  int largeBookPageCount = _largeBookPageCount,
}) {
  final (:books, :errors) = parseBooks(lines);
  final checked = [
    for (final book in books)
      (book: book, violations: book.violations(referenceDate: referenceDate)),
  ];
  final invalid = checked.where((entry) => entry.violations.isNotEmpty);
  final library = Repository<Book>([
    for (final (:book, :violations) in checked)
      if (violations.isEmpty) book,
  ]);
  final valid = library.values.toList(growable: false);

  final buffer = StringBuffer()
    ..writeln('Домашня бібліотека')
    ..writeln('Отримано рядків: ${lines.length}.')
    ..writeln('Успішно розібрано: ${books.length}.')
    ..writeln('Не розібрано: ${errors.length}.')
    ..writeln('Пройшли валідацію: ${valid.length}.')
    ..writeln('Не пройшли валідацію: ${invalid.length}.');

  if (errors.isNotEmpty) {
    buffer.writeln('\nПомилки вхідних даних:');
    errors.forEach(buffer.writeln);
  }

  if (invalid.isNotEmpty) {
    buffer.writeln('\nПорушення правил валідації:');
    for (final (:book, :violations) in invalid) {
      final author = maskAuthors ? book.author.maskedName : book.author;
      buffer.writeln('$author — ${book.title}: ${violations.join('; ')}.');
    }
  }

  buffer.writeln('\nСтан читання:');
  for (final book in valid) {
    final description = describeStatus(
      book.status,
      pageCount: book.pageCount,
      referenceDate: referenceDate,
    );
    buffer.writeln('«${book.title}» — $description.');
  }

  buffer.writeln('\nКниги від $largeBookPageCount сторінок:');
  for (final book in valid.withMinimumPages(largeBookPageCount)) {
    buffer.writeln('${book.author} — «${book.title}» (${book.pageCount} с.)');
  }
  buffer.writeln(
    'Сторінок у книгах, виданих від $_modernEraStartYear року: '
    '${valid.pagesPublishedSince(_modernEraStartYear)}.',
  );

  buffer.writeln('\nСередня кількість сторінок за жанрами:');
  final averages = valid.averagePagesByGenre().entries.toList()
    ..sort((left, right) => left.key.index.compareTo(right.key.index));
  for (final MapEntry(key: genre, value: average) in averages) {
    final formatted = average.toStringAsFixed(_decimalPlaces);
    buffer.writeln('${genre.describe()}: $formatted.');
  }

  if (valid.pageStatistics case (:final min, :final max, :final average)) {
    buffer.writeln(
      '\nОбсяг книг: від $min до $max сторінок, '
      'у середньому ${average.toStringAsFixed(_decimalPlaces)}.',
    );
  }

  final oldestFirst = valid.sortedBy(Book.compareByPublicationYear);
  final titlesDescending = valid.sortedBy(
    Book.compareByTitle,
    ascending: false,
  );
  if (oldestFirst case [final oldest, ...]) {
    buffer.writeln(
      'Найраніша за роком видання: ${oldest.title} '
      '(${oldest.publicationYear}).',
    );
  }
  if (titlesDescending case [final last, ...]) {
    buffer.writeln('Перша за назвою у зворотному порядку: ${last.title}.');
  }

  return buffer.toString();
}

/// Запускає консольний застосунок «Домашня бібліотека» на [lines].
void runApplication(Iterable<String> lines) =>
    print(buildReport(lines, referenceDate: DateTime.now()));

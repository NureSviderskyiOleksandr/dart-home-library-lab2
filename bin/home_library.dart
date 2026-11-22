import 'package:home_library/home_library.dart';

void main(List<String> arguments) {
  const line = 'Джордж Орвелл;1984;1949;328;антиутопія;2025-01-12';
  final first = Book.fromCsv(line);
  final second = Book.fromCsv(line);
  print(first);
  print('Однакові за значенням: ${first == second}.');
  print('Розмір множини з двох однакових книг: ${{first, second}.length}.');
  print(
    'Кеш повертає той самий об’єкт: '
    '${identical(Book.cached(line), Book.cached(line))}.',
  );
}

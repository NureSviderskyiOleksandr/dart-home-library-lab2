/// Жанр книги домашньої бібліотеки.
///
/// Перелічення замінює рядкове поле жанру з лабораторної роботи 1: набір
/// жанрів скінченний, тому помилку в назві виявляє розбір, а не групування.
enum Genre {
  /// Антиутопія.
  dystopia('антиутопія'),

  /// Наукова фантастика.
  scienceFiction('фантастика'),

  /// Фентезі.
  fantasy('фентезі'),

  /// Детектив.
  detective('детектив'),

  /// Роман.
  novel('роман'),

  /// Історичний роман.
  historicalNovel('історичний роман'),

  /// Містика.
  mystic('містика'),

  /// Пригодницька література.
  adventure('пригоди'),

  /// Поезія.
  poetry('поезія'),

  /// Довідкова література.
  reference('довідкова', isFiction: false);

  /// Створює жанр із підписом [label].
  const Genre(this.label, {this.isFiction = true});

  /// Назва жанру у вхідних даних і звітах.
  final String label;

  /// Чи належить жанр до художньої літератури.
  final bool isFiction;

  /// Повертає жанр із назвою [label] або `null`, якщо такого жанру немає.
  ///
  /// Регістр і пробіли на краях назви не враховуються.
  static Genre? tryParse(String label) {
    final normalized = label.trim().toLowerCase();
    return values.where((genre) => genre.label == normalized).firstOrNull;
  }

  /// Повертає підпис жанру для звіту з позначкою нехудожньої літератури.
  String describe() => isFiction ? label : '$label (нехудожня)';
}

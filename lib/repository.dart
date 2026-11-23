import 'identifiable.dart';

/// Сховище сутностей, які вміють повідомляти власний ідентифікатор.
///
/// Обмеження `T extends Identifiable` гарантує, що в кожного елемента є
/// гетер `id`, тому сховище індексує елементи без зовнішньої функції-ключа.
class Repository<T extends Identifiable> {
  /// Створює сховище й додає до нього [items].
  Repository([Iterable<T> items = const []]) {
    addAll(items);
  }

  final Map<String, T> _items = {};

  /// Кількість елементів у сховищі.
  int get length => _items.length;

  /// Чи порожнє сховище.
  bool get isEmpty => _items.isEmpty;

  /// Усі елементи в порядку додавання.
  Iterable<T> get values => _items.values;

  /// Додає [item] або замінює елемент із тим самим ідентифікатором.
  ///
  /// Повертає `true`, якщо елемента з таким ідентифікатором раніше не було.
  bool add(T item) {
    final isNew = !_items.containsKey(item.id);
    _items[item.id] = item;
    return isNew;
  }

  /// Додає всі [items] і повертає кількість нових ідентифікаторів.
  int addAll(Iterable<T> items) {
    var added = 0;
    for (final item in items) {
      if (add(item)) added++;
    }
    return added;
  }

  /// Повертає елемент з ідентифікатором [id] або `null`.
  T? findById(String id) => _items[id];

  /// Видаляє елемент з ідентифікатором [id]; повертає, чи він був.
  bool remove(String id) => _items.remove(id) != null;

  /// Повертає елементи, які задовольняють умову [test].
  Iterable<T> where(bool Function(T item) test) => _items.values.where(test);
}

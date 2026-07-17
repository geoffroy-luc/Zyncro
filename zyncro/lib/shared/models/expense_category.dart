class ExpenseCategory {
  final String name;
  final String iconKey;
  final String colorHex;

  const ExpenseCategory({
    required this.name,
    required this.iconKey,
    required this.colorHex,
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) => ExpenseCategory(
    name: map['name'] as String? ?? '',
    iconKey: map['iconKey'] as String? ?? 'label',
    colorHex: map['colorHex'] as String? ?? '#4F7CFF',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'iconKey': iconKey,
    'colorHex': colorHex,
  };

  ExpenseCategory copyWith({String? name, String? iconKey, String? colorHex}) {
    return ExpenseCategory(
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}

const defaultExpenseCategories = [
  ExpenseCategory(name: 'Alimentation', iconKey: 'restaurant', colorHex: '#2BB8A5'),
  ExpenseCategory(name: 'Logement', iconKey: 'home', colorHex: '#4F7CFF'),
  ExpenseCategory(name: 'Transport', iconKey: 'car', colorHex: '#9B59B6'),
  ExpenseCategory(name: 'Loisirs', iconKey: 'games', colorHex: '#E85D75'),
  ExpenseCategory(name: 'Services', iconKey: 'build', colorHex: '#FFB86B'),
  ExpenseCategory(name: 'Autre', iconKey: 'category', colorHex: '#6B7280'),
];

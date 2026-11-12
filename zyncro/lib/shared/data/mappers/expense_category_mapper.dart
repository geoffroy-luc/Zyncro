import 'package:zyncro/shared/domain/categories/expense_category.dart';

abstract final class ExpenseCategoryFields {
  static const name = 'name';
  static const iconKey = 'iconKey';
  static const colorHex = 'colorHex';
}

abstract final class ExpenseCategoryMapper {
  static ExpenseCategory fromFirestore(Map<String, dynamic> map) =>
      ExpenseCategory(
        name: map[ExpenseCategoryFields.name] as String? ?? '',
        iconKey: map[ExpenseCategoryFields.iconKey] as String? ?? 'label',
        colorHex: map[ExpenseCategoryFields.colorHex] as String? ?? '#4F7CFF',
      );

  static Map<String, dynamic> toFirestore(ExpenseCategory category) => {
    ExpenseCategoryFields.name: category.name,
    ExpenseCategoryFields.iconKey: category.iconKey,
    ExpenseCategoryFields.colorHex: category.colorHex,
  };
}

import 'package:zyncro/shared/domain/categories/expense_category.dart';

class CalendarFilters {
  final List<String> participantIds;
  final bool recurrenceOnly;
  final String? category;

  const CalendarFilters({
    this.participantIds = const [],
    this.recurrenceOnly = false,
    this.category,
  });

  CalendarFilters copyWith({
    List<String>? participantIds,
    bool? recurrenceOnly,
    String? category,
    bool clearCategory = false,
  }) {
    return CalendarFilters(
      participantIds: participantIds ?? this.participantIds,
      recurrenceOnly: recurrenceOnly ?? this.recurrenceOnly,
      category: clearCategory ? null : (category ?? this.category),
    );
  }

  bool get isEmpty =>
      participantIds.isEmpty && !recurrenceOnly && category == null;
}

class TabSettings {
  final List<String> customColors;
  final List<String> hiddenBaseColors;

  final String? homeThemeColor;
  final String? calendarThemeColor;
  final String? notesThemeColor;
  final String? expensesThemeColor;
  final String? chatThemeColor;

  final String? chatBackgroundType;
  final String? chatBackgroundValue;

  final String expensesCurrency;
  final List<ExpenseCategory> expensesCategories;

  final String calendarDisplayMode;
  final List<String> calendarCustomCategories;
  final CalendarFilters calendarFilters;

  final String? homePhotoUrl;

  const TabSettings({
    this.customColors = const [],
    this.hiddenBaseColors = const [],
    this.homeThemeColor,
    this.calendarThemeColor,
    this.notesThemeColor,
    this.expensesThemeColor,
    this.chatThemeColor,
    this.chatBackgroundType,
    this.chatBackgroundValue,
    this.expensesCurrency = 'EUR',
    this.expensesCategories = defaultExpenseCategories,
    this.calendarDisplayMode = 'band',
    this.calendarCustomCategories = const [],
    this.calendarFilters = const CalendarFilters(),
    this.homePhotoUrl,
  });

  static const TabSettings defaults = TabSettings();

  TabSettings copyWith({
    List<String>? customColors,
    List<String>? hiddenBaseColors,
    String? homeThemeColor,
    String? calendarThemeColor,
    String? notesThemeColor,
    String? expensesThemeColor,
    String? chatThemeColor,
    String? chatBackgroundType,
    String? chatBackgroundValue,
    String? expensesCurrency,
    List<ExpenseCategory>? expensesCategories,
    String? calendarDisplayMode,
    List<String>? calendarCustomCategories,
    CalendarFilters? calendarFilters,
    String? homePhotoUrl,
    bool clearHomeThemeColor = false,
    bool clearCalendarThemeColor = false,
    bool clearNotesThemeColor = false,
    bool clearExpensesThemeColor = false,
    bool clearChatThemeColor = false,
    bool clearChatBackground = false,
    bool clearHomePhotoUrl = false,
  }) {
    return TabSettings(
      customColors: customColors ?? this.customColors,
      hiddenBaseColors: hiddenBaseColors ?? this.hiddenBaseColors,
      homeThemeColor: clearHomeThemeColor
          ? null
          : (homeThemeColor ?? this.homeThemeColor),
      calendarThemeColor: clearCalendarThemeColor
          ? null
          : (calendarThemeColor ?? this.calendarThemeColor),
      notesThemeColor: clearNotesThemeColor
          ? null
          : (notesThemeColor ?? this.notesThemeColor),
      expensesThemeColor: clearExpensesThemeColor
          ? null
          : (expensesThemeColor ?? this.expensesThemeColor),
      chatThemeColor: clearChatThemeColor
          ? null
          : (chatThemeColor ?? this.chatThemeColor),
      chatBackgroundType: clearChatBackground
          ? null
          : (chatBackgroundType ?? this.chatBackgroundType),
      chatBackgroundValue: clearChatBackground
          ? null
          : (chatBackgroundValue ?? this.chatBackgroundValue),
      expensesCurrency: expensesCurrency ?? this.expensesCurrency,
      expensesCategories: expensesCategories ?? this.expensesCategories,
      calendarDisplayMode: calendarDisplayMode ?? this.calendarDisplayMode,
      calendarCustomCategories:
          calendarCustomCategories ?? this.calendarCustomCategories,
      calendarFilters: calendarFilters ?? this.calendarFilters,
      homePhotoUrl: clearHomePhotoUrl
          ? null
          : (homePhotoUrl ?? this.homePhotoUrl),
    );
  }

  /// Retire une couleur d'une palette : si c'est une couleur personnalisée,
  /// elle est supprimée de [customColors] ; sinon (couleur de base), elle est
  /// masquée via [hiddenBaseColors].
  TabSettings withColorRemoved(String hex) {
    if (customColors.contains(hex)) {
      return copyWith(
        customColors: customColors.where((c) => c != hex).toList(),
      );
    }
    return copyWith(hiddenBaseColors: [...hiddenBaseColors, hex]);
  }
}

import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/shared/data/mappers/expense_category_mapper.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';
import 'package:zyncro/shared/domain/categories/expense_category.dart';

/// Champs Firestore des réglages d'onglet (`groups/{gid}/config/tabSettings`).
abstract final class TabSettingsFields {
  static const customColors = 'customColors';
  static const hiddenBaseColors = 'hiddenBaseColors';
  static const homeThemeColor = 'homeThemeColor';
  static const calendarThemeColor = 'calendarThemeColor';
  static const notesThemeColor = 'notesThemeColor';
  static const expensesThemeColor = 'expensesThemeColor';
  static const chatThemeColor = 'chatThemeColor';
  static const chatBackgroundType = 'chatBackgroundType';
  static const chatBackgroundValue = 'chatBackgroundValue';
  static const expensesCurrency = 'expensesCurrency';
  static const expensesCategories = 'expensesCategories';

  /// Legacy (lecture seule) : anciennes catégories, simples noms.
  static const legacyExpensesCustomCategories = 'expensesCustomCategories';
  static const calendarDisplayMode = 'calendarDisplayMode';
  static const calendarCustomCategories = 'calendarCustomCategories';
  static const calendarFilters = 'calendarFilters';
  static const homePhotoUrl = 'homePhotoUrl';

  static const filterParticipantIds = 'participantIds';
  static const filterRecurrenceOnly = 'recurrenceOnly';
  static const filterCategory = 'category';
}

abstract final class TabSettingsMapper {
  static TabSettings fromFirestore(Map<String, dynamic> map) {
    return TabSettings(
      customColors: FirestoreCodec.stringList(
        map[TabSettingsFields.customColors],
      ),
      hiddenBaseColors: FirestoreCodec.stringList(
        map[TabSettingsFields.hiddenBaseColors],
      ),
      homeThemeColor: map[TabSettingsFields.homeThemeColor] as String?,
      calendarThemeColor: map[TabSettingsFields.calendarThemeColor] as String?,
      notesThemeColor: map[TabSettingsFields.notesThemeColor] as String?,
      expensesThemeColor: map[TabSettingsFields.expensesThemeColor] as String?,
      chatThemeColor: map[TabSettingsFields.chatThemeColor] as String?,
      chatBackgroundType: map[TabSettingsFields.chatBackgroundType] as String?,
      chatBackgroundValue:
          map[TabSettingsFields.chatBackgroundValue] as String?,
      expensesCurrency:
          (map[TabSettingsFields.expensesCurrency] as String?) ?? 'EUR',
      expensesCategories: map[TabSettingsFields.expensesCategories] != null
          ? (map[TabSettingsFields.expensesCategories] as List<dynamic>)
                .map(
                  (e) => ExpenseCategoryMapper.fromFirestore(
                    Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
                  ),
                )
                .toList()
          : [
              ...defaultExpenseCategories,
              ...FirestoreCodec.stringList(
                map[TabSettingsFields.legacyExpensesCustomCategories],
              ).map(
                (name) => ExpenseCategory(
                  name: name,
                  iconKey: 'label',
                  colorHex: '#4F7CFF',
                ),
              ),
            ],
      calendarDisplayMode:
          (map[TabSettingsFields.calendarDisplayMode] as String?) ?? 'band',
      calendarCustomCategories: FirestoreCodec.stringList(
        map[TabSettingsFields.calendarCustomCategories],
      ),
      calendarFilters: map[TabSettingsFields.calendarFilters] != null
          ? calendarFiltersFromFirestore(
              Map<String, dynamic>.from(
                map[TabSettingsFields.calendarFilters] as Map<dynamic, dynamic>,
              ),
            )
          : const CalendarFilters(),
      homePhotoUrl: map[TabSettingsFields.homePhotoUrl] as String?,
    );
  }

  static Map<String, dynamic> toFirestore(TabSettings s) => {
    TabSettingsFields.customColors: s.customColors,
    TabSettingsFields.hiddenBaseColors: s.hiddenBaseColors,
    TabSettingsFields.homeThemeColor: s.homeThemeColor,
    TabSettingsFields.calendarThemeColor: s.calendarThemeColor,
    TabSettingsFields.notesThemeColor: s.notesThemeColor,
    TabSettingsFields.expensesThemeColor: s.expensesThemeColor,
    TabSettingsFields.chatThemeColor: s.chatThemeColor,
    TabSettingsFields.chatBackgroundType: s.chatBackgroundType,
    TabSettingsFields.chatBackgroundValue: s.chatBackgroundValue,
    TabSettingsFields.expensesCurrency: s.expensesCurrency,
    TabSettingsFields.expensesCategories: s.expensesCategories
        .map(ExpenseCategoryMapper.toFirestore)
        .toList(),
    TabSettingsFields.calendarDisplayMode: s.calendarDisplayMode,
    TabSettingsFields.calendarCustomCategories: s.calendarCustomCategories,
    TabSettingsFields.calendarFilters: calendarFiltersToFirestore(
      s.calendarFilters,
    ),
    TabSettingsFields.homePhotoUrl: s.homePhotoUrl,
  };

  static CalendarFilters calendarFiltersFromFirestore(
    Map<String, dynamic> map,
  ) {
    return CalendarFilters(
      participantIds: FirestoreCodec.stringList(
        map[TabSettingsFields.filterParticipantIds],
      ),
      recurrenceOnly:
          (map[TabSettingsFields.filterRecurrenceOnly] as bool?) ?? false,
      category: map[TabSettingsFields.filterCategory] as String?,
    );
  }

  static Map<String, dynamic> calendarFiltersToFirestore(CalendarFilters f) => {
    TabSettingsFields.filterParticipantIds: f.participantIds,
    TabSettingsFields.filterRecurrenceOnly: f.recurrenceOnly,
    TabSettingsFields.filterCategory: f.category,
  };

  /// Champs de premier niveau qui diffèrent entre [from] (état vu par
  /// l'appelant) et [to] (état voulu) : seuls ceux-là sont écrits
  /// (BUGS_FOUND G1 — écrire la carte complète écrasait les modifications
  /// concurrentes et, pendant un chargement, réinitialisait tous les onglets).
  static Map<String, dynamic> changedFields(TabSettings from, TabSettings to) {
    final before = toFirestore(from);
    final after = toFirestore(to);
    return {
      for (final entry in after.entries)
        if (!_jsonEquals(before[entry.key], entry.value))
          entry.key: entry.value,
    };
  }

  static bool _jsonEquals(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_jsonEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_jsonEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }
}

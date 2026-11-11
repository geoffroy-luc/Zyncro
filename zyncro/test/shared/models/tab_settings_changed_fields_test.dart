import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/shared/models/expense_category.dart';
import 'package:zyncro/shared/models/tab_settings.dart';

void main() {
  group('TabSettings.changedFieldsTo (BUGS_FOUND G1)', () {
    const base = TabSettings(
      chatThemeColor: '#E85D75',
      customColors: ['#111111'],
    );

    test('aucun changement → carte vide', () {
      expect(base.changedFieldsTo(base), isEmpty);
      expect(base.changedFieldsTo(base.copyWith()), isEmpty);
    });

    test('ne contient que le champ modifié', () {
      final changes = base.changedFieldsTo(
        base.copyWith(notesThemeColor: '#2BB8A5'),
      );
      expect(changes, {'notesThemeColor': '#2BB8A5'});
    });

    test('un effacement est écrit à null (comme avant)', () {
      final changes = base.changedFieldsTo(
        base.copyWith(clearChatThemeColor: true),
      );
      expect(changes, {'chatThemeColor': null});
    });

    test(
      'listes : comparaison par contenu, liste complète écrite si modifiée',
      () {
        final same = base.copyWith(customColors: ['#111111']);
        expect(base.changedFieldsTo(same), isEmpty);
        final added = base.copyWith(
          customColors: [...base.customColors, '#222222'],
        );
        expect(base.changedFieldsTo(added), {
          'customColors': ['#111111', '#222222'],
        });
      },
    );

    test('catégories (liste de cartes) : comparaison profonde', () {
      final cats = [...TabSettings.defaults.expensesCategories];
      final same = base.copyWith(expensesCategories: List.of(cats));
      expect(base.changedFieldsTo(same), isEmpty);
      final edited = base.copyWith(
        expensesCategories: [
          ...cats,
          const ExpenseCategory(
            name: 'Animaux',
            iconKey: 'pets',
            colorHex: '#FFA940',
          ),
        ],
      );
      expect(base.changedFieldsTo(edited).keys, ['expensesCategories']);
    });

    test('filtres du calendrier (carte imbriquée)', () {
      final next = base.copyWith(
        calendarFilters: base.calendarFilters.copyWith(recurrenceOnly: true),
      );
      expect(base.changedFieldsTo(next), {
        'calendarFilters': {
          'participantIds': <String>[],
          'recurrenceOnly': true,
          'category': null,
        },
      });
    });

    test('depuis les défauts (chargement en cours) : un seul champ écrit', () {
      const loading = TabSettings.defaults;
      final changes = loading.changedFieldsTo(
        loading.copyWith(chatThemeColor: '#000000'),
      );
      expect(changes, {'chatThemeColor': '#000000'});
    });
  });
}

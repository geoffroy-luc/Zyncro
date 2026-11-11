import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/settings/data/mappers/tab_settings_mapper.dart';
import 'package:zyncro/features/settings/data/repositories/firestore_tab_settings_repository.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTabSettingsRepository repo;
  const path = 'groups/g1/config/tabSettings';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreTabSettingsRepository(db);
  });

  Future<Map<String, dynamic>> stored() async =>
      (await db.doc(path).get()).data() ?? {};

  test(
    'ne réécrit pas les modifications concurrentes d\'un autre membre (G1)',
    () async {
      // État vu par Alice à l'ouverture de l'écran.
      const seenByAlice = TabSettings(chatThemeColor: '#E85D75');
      await db.doc(path).set(TabSettingsMapper.toFirestore(seenByAlice));
      // Bob modifie entre-temps la devise.
      await db.doc(path).set({
        'expensesCurrency': 'USD',
      }, SetOptions(merge: true));

      // Alice change la couleur des notes depuis son instantané (devise = EUR).
      await repo.updateSettings(
        'g1',
        from: seenByAlice,
        to: seenByAlice.copyWith(notesThemeColor: '#2BB8A5'),
      );

      final data = await stored();
      expect(data['notesThemeColor'], '#2BB8A5');
      expect(
        data['expensesCurrency'],
        'USD',
        reason: 'la modification de Bob est conservée',
      );
      expect(data['chatThemeColor'], '#E85D75');
    },
  );

  test(
    'une écriture faite depuis les défauts (chargement) ne réinitialise rien (G1)',
    () async {
      await db
          .doc(path)
          .set(
            TabSettingsMapper.toFirestore(
              const TabSettings(
                chatBackgroundType: 'image',
                chatBackgroundValue: 'https://bg',
                calendarDisplayMode: 'dot',
                customColors: ['#123456'],
              ),
            ),
          );

      await repo.updateSettings(
        'g1',
        from: TabSettings.defaults,
        to: TabSettings.defaults.copyWith(homeThemeColor: '#9B59B6'),
      );

      final data = await stored();
      expect(data['homeThemeColor'], '#9B59B6');
      expect(data['chatBackgroundType'], 'image');
      expect(data['chatBackgroundValue'], 'https://bg');
      expect(data['calendarDisplayMode'], 'dot');
      expect(data['customColors'], ['#123456']);
    },
  );

  test('crée le document s\'il n\'existe pas', () async {
    await repo.updateSettings(
      'g1',
      from: TabSettings.defaults,
      to: TabSettings.defaults.copyWith(expensesCurrency: 'CHF'),
    );
    expect(await stored(), {'expensesCurrency': 'CHF'});
  });

  test('aucun changement → aucune écriture', () async {
    await repo.updateSettings(
      'g1',
      from: TabSettings.defaults,
      to: TabSettings.defaults,
    );
    expect((await db.doc(path).get()).exists, isFalse);
  });

  test('effacer une valeur l\'écrit à null', () async {
    const current = TabSettings(chatThemeColor: '#E85D75');
    await db.doc(path).set(TabSettingsMapper.toFirestore(current));
    await repo.updateSettings(
      'g1',
      from: current,
      to: current.copyWith(clearChatThemeColor: true),
    );
    final data = await stored();
    expect(data.containsKey('chatThemeColor'), isTrue);
    expect(data['chatThemeColor'], isNull);
  });

  test('watchSettings relit fidèlement ce qui a été écrit', () async {
    await repo.updateSettings(
      'g1',
      from: TabSettings.defaults,
      to: TabSettings.defaults.copyWith(calendarDisplayMode: 'dot'),
    );
    final settings = await repo.watchSettings('g1').first;
    expect(settings.calendarDisplayMode, 'dot');
    expect(settings.expensesCurrency, 'EUR');
  });
}

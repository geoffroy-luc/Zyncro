import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/presentation/widgets/activity_group_tile.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';

Message _activity(String content) => Message(
  id: content,
  groupId: 'g',
  senderId: 'a',
  content: content,
  type: MessageType.system,
  timestamp: DateTime(2026),
);

void main() {
  testWidgets('replié : résumé ; touché : le détail, dans l’ordre', (
    tester,
  ) async {
    var expanded = false;
    // Du plus récent au plus ancien, comme dans le chat.
    final activities = [
      _activity('💰 Alice a ajouté une dépense « Pizza »'),
      _activity('📅 Alice a créé un événement « Ciné »'),
      _activity('📝 Alice a créé une note « Courses »'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ActivityGroupTile(
              activities: activities,
              expanded: expanded,
              hasCustomBackground: false,
              onToggle: () => setState(() => expanded = !expanded),
            ),
          ),
        ),
      ),
    );
    expect(find.text('3 activités'), findsOneWidget);
    expect(find.text('💰 📅 📝'), findsOneWidget);
    expect(find.textContaining('Courses'), findsNothing);

    await tester.tap(find.text('3 activités'));
    await tester.pumpAndSettle();
    final note = tester.getTopLeft(find.textContaining('Courses')).dy;
    final pizza = tester.getTopLeft(find.textContaining('Pizza')).dy;
    expect(note, lessThan(pizza)); // la plus ancienne en haut

    await tester.tap(find.text('3 activités'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Courses'), findsNothing);
  });
}

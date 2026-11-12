import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/domain/repositories/messages_repository.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

class _Repo extends Mock implements MessagesRepository {}

class _Group extends SelectedGroupIdNotifier {
  @override
  Future<String?> build() async => 'g1';
}

final _t0 = DateTime(2026, 11, 12);

Message _m(int minute) => Message(
  id: 'm$minute',
  groupId: 'g1',
  senderId: 'a',
  content: 'msg $minute',
  type: MessageType.text,
  timestamp: _t0.add(Duration(minutes: minute)),
);

/// Messages t = from, from-1, … (du plus récent au plus ancien).
List<Message> _desc(int from, int count) => [
  for (var t = from; t > from - count; t--) _m(t),
];

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2000)));

  late StreamController<List<Message>> live;
  late _Repo repo;
  late ProviderContainer container;

  setUp(() {
    live = StreamController<List<Message>>();
    repo = _Repo();
    when(() => repo.watchMessages('g1')).thenAnswer((_) => live.stream);
    container = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
        selectedGroupIdProvider.overrideWith(_Group.new),
      ],
    );
    container.listen(chatMessagesProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    await live.close();
  });

  Future<ChatMessagesState> settle() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(chatMessagesProvider.future);
  }

  test(
    'BUG C1 corrigé : un message poussé hors de la fenêtre reste affiché',
    () async {
      live.add(_desc(100, 50)); // m100 … m51
      await settle();
      when(
        () => repo.fetchMessagesBefore('g1', any()),
      ).thenAnswer((_) async => _desc(50, 50)); // m50 … m1
      await container.read(chatMessagesProvider.notifier).loadMore();

      live.add(_desc(101, 50)); // m101 arrive, m51 sort de la fenêtre live
      final state = await settle();
      final ids = state.messages.map((m) => m.id).toList();
      expect(ids, contains('m51'));
      expect(ids.length, 101);
      expect(ids.toSet().length, 101);
    },
  );

  test(
    'BUG C3 corrigé : « plus d’historique » recalculé à chaque instantané',
    () async {
      live.add(_desc(10, 10)); // fenêtre incomplète (cache local par ex.)
      expect((await settle()).hasMore, isFalse);
      live.add(_desc(100, 50)); // instantané serveur complet
      expect((await settle()).hasMore, isTrue);
    },
  );
}

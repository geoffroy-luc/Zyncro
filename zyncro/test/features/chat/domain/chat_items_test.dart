import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/chat/domain/chat_items.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';

Message _m(String id, MessageType type) => Message(
  id: id,
  groupId: 'g',
  senderId: 'a',
  content: id,
  type: type,
  timestamp: DateTime(2026),
);

String _describe(List<ChatItem> items) => items
    .map(
      (i) => switch (i) {
        MessageItem(:final index) => '$index',
        ActivityGroupItem(:final indices) => '[${indices.join(',')}]',
      },
    )
    .join(' ');

void main() {
  const text = MessageType.text;
  const system = MessageType.system;

  test(
    'activités consécutives regroupées, isolées laissées telles quelles',
    () {
      final items = groupActivity([
        _m('t0', text),
        _m('s1', system),
        _m('s2', system),
        _m('s3', system),
        _m('t4', text),
        _m('s5', system),
        _m('t6', text),
        _m('s7', system),
        _m('s8', system),
      ]);
      expect(_describe(items), '0 [1,2,3] 4 5 6 [7,8]');
    },
  );

  test('sans activité : un élément par message', () {
    final items = groupActivity([_m('a', text), _m('b', MessageType.image)]);
    expect(_describe(items), '0 1');
  });
}

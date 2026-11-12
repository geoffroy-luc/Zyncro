import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/chat/domain/typing_throttle.dart';

void main() {
  late DateTime now;
  late TypingThrottle throttle;

  setUp(() {
    now = DateTime(2026, 11, 12, 10);
    throttle = TypingThrottle(clock: () => now);
  });

  void advance(int ms) => now = now.add(Duration(milliseconds: ms));

  test('première frappe envoyée, puis au plus une écriture par 2 s', () {
    final sent = <int>[];
    for (var t = 0; t <= 5000; t += 150) {
      if (throttle.shouldSend()) sent.add(t);
      advance(150);
    }
    expect(sent.first, 0);
    for (var i = 1; i < sent.length; i++) {
      expect(sent[i] - sent[i - 1], greaterThanOrEqualTo(2000));
      // Rafraîchi bien avant le seuil de lecture de 6 s.
      expect(sent[i] - sent[i - 1], lessThan(2200));
    }
  });

  test('après reset (document supprimé), la frappe suivante part aussitôt', () {
    expect(throttle.shouldSend(), isTrue);
    advance(500);
    expect(throttle.shouldSend(), isFalse);
    throttle.reset();
    expect(throttle.shouldSend(), isTrue);
  });
}

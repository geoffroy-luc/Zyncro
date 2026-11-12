import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/utils/duration_format.dart';

void main() {
  test('BUG M17 corrigé : les heures sont affichées', () {
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
    expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
    expect(formatDuration(Duration.zero), '00:00');
  });
}

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/design_system/tokens/brand_palette.dart';

void main() {
  test('palette des onglets = valeurs historiques', () {
    expect(TabPalette.colors, const [
      Color(0xFF9B59B6),
      Color(0xFF4F7CFF),
      Color(0xFF2BB8A5),
      Color(0xFFFFB86B),
      Color(0xFFE85D75),
    ]);
    expect(TabPalette.gradients, const [
      [Color(0xFF9B59B6), Color(0xFF7D3C98)],
      [Color(0xFF4F7CFF), Color(0xFF315FEA)],
      [Color(0xFF2BB8A5), Color(0xFF1A9B88)],
      [Color(0xFFFFB86B), Color(0xFFF5A855)],
      [Color(0xFFE85D75), Color(0xFFC94060)],
    ]);
  });

  test('palette des soldes = valeurs historiques', () {
    expect(BalancePalette.positive, const Color(0xFF2BB8A5));
    expect(BalancePalette.positiveDeep, const Color(0xFF1E9B8A));
    expect(BalancePalette.negative, const Color(0xFFFF6B6B));
    expect(BalancePalette.negativeDeep, const Color(0xFFE85D75));
    expect(BalancePalette.settleAction, const Color(0xFF4F7CFF));
  });
}

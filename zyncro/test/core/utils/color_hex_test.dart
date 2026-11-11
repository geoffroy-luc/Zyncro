import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/utils/color_hex.dart';

void main() {
  test('hexToColor : avec ou sans #, opaque', () {
    expect(hexToColor('#4F7CFF'), const Color(0xFF4F7CFF));
    expect(hexToColor('2bb8a5'), const Color(0xFF2BB8A5));
  });
  test('hexToColor : invalide → FormatException (comportement historique)', () {
    expect(() => hexToColor('#XYZ'), throwsFormatException);
  });
  test('tryHexToColor : null ou invalide → null', () {
    expect(tryHexToColor(null), isNull);
    expect(tryHexToColor('pas une couleur'), isNull);
    expect(tryHexToColor('#FF0000'), const Color(0xFFFF0000));
  });
  test('colorToHex : majuscules, sans alpha', () {
    expect(colorToHex(const Color(0x804F7CFF)), '#4F7CFF');
    expect(colorToHex(const Color(0xFF000001)), '#000001');
  });
  test('aller-retour', () {
    for (final hex in ['#4F7CFF', '#2BB8A5', '#FFB86B', '#000000', '#FFFFFF']) {
      expect(colorToHex(hexToColor(hex)), hex);
    }
  });
  test('darken : −0,12 de luminosité HSL, borné', () {
    final base = hexToColor('#4F7CFF');
    final dark = darken(base);
    expect(
      HSLColor.fromColor(dark).lightness,
      closeTo(HSLColor.fromColor(base).lightness - 0.12, 0.01),
    );
    expect(darken(const Color(0xFF000000)), const Color(0xFF000000));
  });
}

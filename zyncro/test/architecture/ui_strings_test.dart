// Garde-fou l10n : aucun texte d'interface littéral dans Text(...) côté
// présentation. Les textes vivent dans lib/l10n/app_fr.arb (context.l10n).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pas de texte d\'interface en dur dans Text(...)', () {
    final literal = RegExp(r"Text\(\s*'((?:[^'\\]|\\.)*)'");
    final interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
    final letters = RegExp('[A-Za-zÀ-ÿ]');
    final violations = <String>[];
    for (final dir in ['lib/features', 'lib/app', 'lib/shared']) {
      for (final f in Directory(
        dir,
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') ||
            f.path.contains('/data/') ||
            f.path.contains('/domain/')) {
          continue;
        }
        for (final m in literal.allMatches(f.readAsStringSync())) {
          // Une interpolation contenant elle-même des quotes coupe la capture :
          // on ignore tout ce qui suit un `${` non refermé.
          final text = m
              .group(1)!
              .replaceAll(interpolation, '')
              .replaceAll(RegExp(r'\$\{.*'), '');
          if (letters.hasMatch(text)) {
            violations.add('${f.path} → ${m.group(0)}');
          }
        }
      }
    }
    expect(violations, isEmpty);
  });
}

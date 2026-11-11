// Règles d'architecture (docs/refactor/PLAN.md §2.2), vérifiées par scan des
// sources : toute violation fait échouer `flutter test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _lib = Directory('lib');

Iterable<File> _dartFiles(String under) => Directory('lib/$under')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _importsOf(File f) =>
    f.readAsLinesSync().where((l) => l.startsWith('import ')).toList();

Iterable<File> _domainFiles() sync* {
  for (final entity in _lib.listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        entity.path.contains('/domain/')) {
      yield entity;
    }
  }
}

void main() {
  test('domain/ est du Dart pur (ni Flutter, ni Firebase, ni Riverpod)', () {
    const forbidden = [
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:cloud_firestore/',
      'package:firebase_',
    ];
    final violations = <String>[
      for (final f in _domainFiles())
        for (final imp in _importsOf(f))
          if (forbidden.any(imp.contains)) '${f.path} → $imp',
    ];
    expect(violations, isEmpty);
  });

  test('instances Firebase obtenues uniquement via core/firebase', () {
    final pattern = RegExp(r'Firebase(Firestore|Storage|Auth)\.instance');
    const allowed = [
      'lib/core/firebase/firebase_providers.dart',
      'lib/core/firebase/firebase_emulators.dart',
    ];
    // Dette résiduelle explicitement suivie (étapes 5 et 8 du plan).
    const pending = [
      'lib/core/services/notification_service.dart',
      'lib/core/services/update_service.dart',
      'lib/features/auth/presentation/screens/profile_screen.dart',
      'lib/features/dashboard/presentation/screens/home_settings_screen.dart',
      'lib/features/chat/presentation/screens/chat_settings_screen.dart',
    ];
    final violations = <String>[
      for (final f in _dartFiles(''))
        if (!allowed.contains(f.path) &&
            !pending.contains(f.path) &&
            pattern.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(violations, isEmpty);
  });

  test('plus de modèles dans shared/models (entités dans les domaines)', () {
    expect(Directory('lib/shared/models').existsSync(), isFalse);
  });
}

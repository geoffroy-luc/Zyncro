import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/chat/domain/reactions.dart';

void main() {
  const start = {
    '❤️': ['u', 'v'],
    '0': ['u'],
  };

  test('BUG C8 corrigé : un vote exclusif ne retire que les votes', () {
    expect(
      applyReaction(
        start,
        key: '1',
        userId: 'u',
        hasReacted: false,
        exclusive: true,
      ),
      {
        '❤️': ['u', 'v'],
        '1': ['u'],
      },
    );
  });

  test('un emoji exclusif remplace l’emoji, sans toucher au vote', () {
    expect(
      applyReaction(
        start,
        key: '😂',
        userId: 'u',
        hasReacted: false,
        exclusive: true,
      ),
      {
        '❤️': ['v'],
        '0': ['u'],
        '😂': ['u'],
      },
    );
  });

  test('retirer sa réaction ; choix multiple ; listes vides supprimées', () {
    expect(
      applyReaction(
        start,
        key: '0',
        userId: 'u',
        hasReacted: true,
        exclusive: true,
      ),
      {
        '❤️': ['u', 'v'],
      },
    );
    expect(
      applyReaction(
        start,
        key: '1',
        userId: 'u',
        hasReacted: false,
        exclusive: false,
      ),
      {
        '❤️': ['u', 'v'],
        '0': ['u'],
        '1': ['u'],
      },
    );
  });
}

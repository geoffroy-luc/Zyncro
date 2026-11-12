import 'dart:math';

/// Alphabet des codes d'invitation : sans caractères ambigus (0/O, 1/I).
const inviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Longueur d'un code d'invitation.
const inviteCodeLength = 6;

/// Génère un code d'invitation de [inviteCodeLength] caractères.
///
/// ⚠️ `Random()` non cryptographique et aucune vérification de collision :
/// comportement historique conservé (AUDIT S-07, BUGS_FOUND G6 ; renforcé en S3).
String newInviteCode([Random? random]) {
  final rng = random ?? Random();
  return List.generate(
    inviteCodeLength,
    (_) => inviteCodeAlphabet[rng.nextInt(inviteCodeAlphabet.length)],
  ).join();
}

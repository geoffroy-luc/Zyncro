import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/error/failure.dart';
import 'package:zyncro/core/error/failure_mapper.dart';

FirebaseException fb(String code) =>
    FirebaseException(plugin: 'test', code: code);

void main() {
  test('codes Firebase', () {
    expect(
      FailureMapper.from(fb('permission-denied')),
      isA<PermissionDeniedFailure>(),
    );
    expect(FailureMapper.from(fb('not-found')), isA<NotFoundFailure>());
    expect(FailureMapper.from(fb('object-not-found')), isA<NotFoundFailure>());
    expect(FailureMapper.from(fb('unavailable')), isA<NetworkFailure>());
    expect(FailureMapper.from(fb('cancelled')), isA<CancelledFailure>());
    expect(
      FailureMapper.from(fb('sign-in-cancelled')),
      isA<CancelledFailure>(),
    );
    expect(FailureMapper.from(fb('internal')), isA<UnknownFailure>());
  });
  test('réseau', () {
    expect(
      FailureMapper.from(const SocketException('x')),
      isA<NetworkFailure>(),
    );
    expect(FailureMapper.from(TimeoutException('x')), isA<NetworkFailure>());
  });
  test('Failure passe tel quel, cause conservée', () {
    const f = ValidationFailure('title-required');
    expect(identical(FailureMapper.from(f), f), isTrue);
    final e = fb('permission-denied');
    expect(FailureMapper.from(e).cause, same(e));
    expect(FailureMapper.from(StateError('x')), isA<UnknownFailure>());
  });
}

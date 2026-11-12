import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:zyncro/core/error/failure.dart';

/// Traduit une exception technique en [Failure].
abstract final class FailureMapper {
  static Failure from(Object error) {
    if (error is Failure) return error;
    if (error is FirebaseException) return _fromFirebase(error);
    if (error is SocketException || error is TimeoutException) {
      return NetworkFailure(error);
    }
    return UnknownFailure(error);
  }

  static Failure _fromFirebase(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' ||
      'unauthorized' ||
      'unauthenticated' => PermissionDeniedFailure(e),
      'not-found' ||
      'object-not-found' ||
      'user-not-found' => NotFoundFailure(e),
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' ||
      'retry-limit-exceeded' => NetworkFailure(e),
      'cancelled' || 'canceled' || 'sign-in-cancelled' => CancelledFailure(e),
      _ => UnknownFailure(e),
    };
  }
}

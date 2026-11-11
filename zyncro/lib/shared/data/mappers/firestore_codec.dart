import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversions communes Firestore ↔ Dart utilisées par les mappers.
abstract final class FirestoreCodec {
  static Timestamp fromDate(DateTime date) => Timestamp.fromDate(date);

  static DateTime toDate(Object? value) => (value! as Timestamp).toDate();

  static DateTime? toDateOrNull(Object? value) =>
      value == null ? null : (value as Timestamp).toDate();

  static List<String> stringList(Object? value) =>
      List<String>.from((value as List<dynamic>?) ?? const <dynamic>[]);
}

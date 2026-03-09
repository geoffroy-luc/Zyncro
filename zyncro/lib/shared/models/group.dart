import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String? emoji;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final String? inviteCode;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.emoji,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.inviteCode,
  });

  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: map['name'] as String,
      description: map['description'] as String?,
      emoji: map['emoji'] as String?,
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      inviteCode: map['inviteCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'emoji': emoji,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (inviteCode != null) 'inviteCode': inviteCode,
    };
  }
}

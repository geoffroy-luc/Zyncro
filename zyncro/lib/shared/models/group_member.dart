import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  final String uid;
  final String displayName;
  final String role; // 'owner' | 'member'
  final DateTime? joinedAt;
  final String? photoUrl;
  final bool showProfilePhoto;

  const GroupMember({
    required this.uid,
    required this.displayName,
    required this.role,
    this.joinedAt,
    this.photoUrl,
    this.showProfilePhoto = true,
  });

  bool get isOwner => role == 'owner';

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Membre',
      role: map['role'] as String? ?? 'member',
      joinedAt: map['joinedAt'] != null
          ? (map['joinedAt'] as Timestamp).toDate()
          : null,
      photoUrl: map['photoUrl'] as String?,
      showProfilePhoto: map['showProfilePhoto'] as bool? ?? true,
    );
  }
}

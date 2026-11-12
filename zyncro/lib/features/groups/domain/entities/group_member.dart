class GroupMember {
  final String uid;
  final String displayName;
  final String role; // 'owner' | 'member'
  final DateTime? joinedAt;
  final String? photoUrl;
  final bool showProfilePhoto;
  final String? lastReadMessageId;
  final DateTime? lastReadAt;

  const GroupMember({
    required this.uid,
    required this.displayName,
    required this.role,
    this.joinedAt,
    this.photoUrl,
    this.showProfilePhoto = true,
    this.lastReadMessageId,
    this.lastReadAt,
  });

  bool get isOwner => role == 'owner';
}

class Group {
  final String id;
  final String name;
  final String? description;
  final String? emoji;
  final String? photoUrl;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final String? inviteCode;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.emoji,
    this.photoUrl,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.inviteCode,
  });
}

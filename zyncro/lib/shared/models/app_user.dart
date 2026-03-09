class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> groupIds;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.groupIds = const [],
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      groupIds: List<String>.from(map['groupIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'groupIds': groupIds,
    };
  }
}

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool showProfilePhoto;
  final List<String> groupIds;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.showProfilePhoto = true,
    this.groupIds = const [],
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      showProfilePhoto: map['showProfilePhoto'] as bool? ?? true,
      groupIds: List<String>.from(map['groupIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'showProfilePhoto': showProfilePhoto,
      'groupIds': groupIds,
    };
  }
}

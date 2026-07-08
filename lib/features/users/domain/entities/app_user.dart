class AppUser {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.createdAt,
  });
}

class ChatUser {
  final String id;
  final String name;
  final String? imageUrl;

  const ChatUser({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  ChatUser copyWith({String? id, String? name, String? imageUrl}) {
    return ChatUser(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

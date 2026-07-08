String conversationIdFor(String uid1, String uid2) {
  final sorted = [uid1, uid2]..sort();
  return sorted.join('_');
}

List<String> participantsFromConversationId(String conversationId) {
  final separator = conversationId.indexOf('_');
  if (separator <= 0 || separator >= conversationId.length - 1) {
    return [];
  }
  return [
    conversationId.substring(0, separator),
    conversationId.substring(separator + 1),
  ];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reply_app/core/utils/conversation_id.dart';

void main() {
  test('conversationIdFor is deterministic regardless of order', () {
    expect(
      conversationIdFor('user_b', 'user_a'),
      conversationIdFor('user_a', 'user_b'),
    );
    expect(conversationIdFor('user_a', 'user_b'), 'user_a_user_b');
  });

  test('participantsFromConversationId parses two uids', () {
    expect(
      participantsFromConversationId(
        'T1ynlBCSm6bE87Z8h5a2ObdNW5v2_juqVMmvVQ0MSoXTljgKWxqSUmE02',
      ),
      [
        'T1ynlBCSm6bE87Z8h5a2ObdNW5v2',
        'juqVMmvVQ0MSoXTljgKWxqSUmE02',
      ],
    );
  });
}

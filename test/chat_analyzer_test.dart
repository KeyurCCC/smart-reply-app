import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/features/chat/data/models/chat_entity_parser.dart';
import 'package:smart_reply_app/features/chat/data/models/meeting_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/address_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/phone_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/email_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/url_entity.dart';
import 'package:smart_reply_app/features/chat/data/repository/entity_cache_repository_impl.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_analyzer_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/services/chat_analyzer_service.dart';

// --- Mocks ---
class MockChatAnalyzerService implements ChatAnalyzerService {
  List<ChatEntity> mockEntities = [];

  @override
  Future<List<ChatEntity>> analyzeMessage({
    required ChatMessage targetMessage,
    required List<ChatMessage> history,
    required String currentUserId,
  }) async {
    return mockEntities;
  }
}

void main() {
  group('Entity Parser Tests', () {
    test('should parse meeting entity correctly', () {
      final json = {
        'type': 'meeting',
        'title': 'Project Review',
        'date': '2026-08-15',
        'time': '10:00',
        'url': 'https://meet.google.com/abc-defg'
      };

      final parsed = ChatEntityParser.fromJson(json);

      expect(parsed, isA<MeetingEntity>());
      final meeting = parsed as MeetingEntity;
      expect(meeting.title, 'Project Review');
      expect(meeting.date, DateTime(2026, 8, 15));
      expect(meeting.time, '10:00');
      expect(meeting.url, 'https://meet.google.com/abc-defg');
    });

    test('should parse address entity correctly', () {
      final json = {
        'type': 'address',
        'address': '221B Baker Street',
        'latitude': '51.5237',
        'longitude': '-0.1585'
      };

      final parsed = ChatEntityParser.fromJson(json);

      expect(parsed, isA<AddressEntity>());
      final address = parsed as AddressEntity;
      expect(address.address, '221B Baker Street');
      expect(address.latitude, 51.5237);
      expect(address.longitude, -0.1585);
    });

    test('should parse phone and email entities correctly', () {
      final phoneJson = {'type': 'phone', 'phoneNumber': '+919876543210', 'name': 'John'};
      final emailJson = {'type': 'email', 'emailAddress': 'test@company.com'};

      final parsedPhone = ChatEntityParser.fromJson(phoneJson) as PhoneEntity?;
      final parsedEmail = ChatEntityParser.fromJson(emailJson) as EmailEntity?;

      expect(parsedPhone?.phoneNumber, '+919876543210');
      expect(parsedPhone?.name, 'John');
      expect(parsedEmail?.emailAddress, 'test@company.com');
    });

    test('should parse url entity with correct platform', () {
      final zoomJson = {'type': 'url', 'url': 'https://zoom.us/j/12345', 'platform': 'zoom'};
      final parsed = ChatEntityParser.fromJson(zoomJson) as UrlEntity?;
      expect(parsed?.url, 'https://zoom.us/j/12345');
      expect(parsed?.platform, 'zoom');
      expect(parsed?.cardTitle, 'Zoom Meeting Link');
    });
  });

  group('Entity Cache Repository Tests', () {
    late SharedPreferences prefs;
    late EntityCacheRepositoryImpl cacheRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheRepo = EntityCacheRepositoryImpl(prefs);
    });

    test('should cache and retrieve entities correctly', () async {
      final entities = [
        PhoneEntity(phoneNumber: '+15550199', name: 'Support'),
        EmailEntity(emailAddress: 'support@example.com'),
      ];

      await cacheRepo.cacheEntities('msg_123', entities);
      final retrieved = await cacheRepo.getCachedEntities('msg_123');

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 2);
      expect(retrieved[0], isA<PhoneEntity>());
      expect((retrieved[0] as PhoneEntity).phoneNumber, '+15550199');
      expect(retrieved[1], isA<EmailEntity>());
      expect((retrieved[1] as EmailEntity).emailAddress, 'support@example.com');
    });
  });

  group('ChatAnalyzerBloc Tests', () {
    late MockChatAnalyzerService analyzerService;
    late EntityCacheRepositoryImpl cacheRepo;
    late ChatAnalyzerBloc bloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cacheRepo = EntityCacheRepositoryImpl(prefs);
      analyzerService = MockChatAnalyzerService();
      bloc = ChatAnalyzerBloc(
        analyzerService: analyzerService,
        cacheRepository: cacheRepo,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('should initial state be ChatAnalyzerInitial', () {
      expect(bloc.state, isA<ChatAnalyzerInitial>());
    });

    test('should emit Loading and Loaded when analyzing new message', () async {
      final message = ChatMessage(
        id: 'msg_abc',
        senderId: 'user_1',
        text: 'Let\'s meet at 221B Baker street',
        type: MessageType.text,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      final mockAddress = AddressEntity(address: '221B Baker street');
      analyzerService.mockEntities = [mockAddress];

      final states = <ChatAnalyzerState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(AnalyzeMessagesEvent(messages: [message], currentUserId: 'user_1'));

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      expect(states.length, 2);
      expect(states[0], isA<ChatAnalyzerLoading>());
      expect(states[1], isA<ChatAnalyzerLoaded>());
      expect(states[1].messageEntities['msg_abc']?.first, isA<AddressEntity>());
      expect((states[1].messageEntities['msg_abc']?.first as AddressEntity).address, '221B Baker street');
    });

    test('should retrieve from cache and bypass LLM call on repeat message analysis', () async {
      final message = ChatMessage(
        id: 'msg_abc',
        senderId: 'user_1',
        text: 'Call me on 12345',
        type: MessageType.text,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      // Pre-populate cache
      await cacheRepo.cacheEntities('msg_abc', [PhoneEntity(phoneNumber: '12345')]);

      final states = <ChatAnalyzerState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(AnalyzeMessagesEvent(messages: [message], currentUserId: 'user_1'));

      await Future.delayed(const Duration(milliseconds: 50));
      sub.cancel();

      // Only Loaded state is emitted, no Loading state (which indicates direct cache bypass)
      expect(states.length, 1);
      expect(states[0], isA<ChatAnalyzerLoaded>());
      expect(states[0].messageEntities['msg_abc']?.first, isA<PhoneEntity>());
    });
  });
}

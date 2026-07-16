import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reply_app/features/auth/data/repository/auth_repository_impl.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/chat/data/datasources/realtime_chat_datasource.dart';
import 'package:smart_reply_app/features/chat/data/repository/chat_repository_impl.dart';
import 'package:smart_reply_app/features/chat/data/repository/realtime_chat_datasource_impl.dart';
import 'package:smart_reply_app/features/chat/data/services/llm_smart_reply_service.dart';
import 'package:smart_reply_app/features/chat/data/services/smart_reply_coordinator.dart';
import 'package:smart_reply_app/features/chat/data/services/smart_reply_service.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';
import 'package:smart_reply_app/features/chat/domain/services/smart_reply_provider.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:smart_reply_app/features/settings/data/repository/settings_repository_impl.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';
import 'package:smart_reply_app/features/users/data/datasources/realtime_user_datasource.dart';
import 'package:smart_reply_app/features/users/data/repository/user_repository_impl.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';
import 'package:smart_reply_app/features/chat/domain/repository/entity_cache_repository.dart';
import 'package:smart_reply_app/features/chat/data/repository/entity_cache_repository_impl.dart';
import 'package:smart_reply_app/features/chat/domain/services/chat_analyzer_service.dart';
import 'package:smart_reply_app/features/chat/data/services/llm_chat_analyzer_service.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_analyzer_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/suggestion_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/smart_action_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();

  final database = FirebaseDatabase.instance;
  database.setPersistenceEnabled(true);
  getIt.registerLazySingleton<FirebaseDatabase>(() => database);
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn());
  getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt()),
  );

  getIt.registerLazySingleton<RealtimeUserDatasource>(
    () => RealtimeUserDatasourceImpl(database: getIt()),
  );
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(datasource: getIt()),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      firebaseAuth: getIt(),
      googleSignIn: getIt(),
      userRepository: getIt(),
    ),
  );

  getIt.registerLazySingleton<RealtimeChatDatasource>(
    () => RealtimeChatDatasourceImpl(
      database: getIt(),
      firebaseAuth: getIt(),
    ),
  );
  getIt.registerLazySingleton<MlKitSmartReplyService>(
    () => MlKitSmartReplyService(),
  );
  getIt.registerLazySingleton<LlmSmartReplyService>(
    () => LlmSmartReplyService(settingsRepository: getIt()),
  );
  getIt.registerLazySingleton<SmartReplyProvider>(
    () => SmartReplyCoordinator(
      mlKitService: getIt(),
      llmService: getIt(),
      settingsRepository: getIt(),
    ),
  );
  getIt.registerLazySingleton<EntityCacheRepository>(
    () => EntityCacheRepositoryImpl(getIt()),
  );
  getIt.registerLazySingleton<ChatAnalyzerService>(
    () => LlmChatAnalyzerService(settingsRepository: getIt()),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      datasource: getIt(),
      authRepository: getIt(),
      userRepository: getIt(),
      smartReplyProvider: getIt(),
    ),
  );

  getIt.registerFactory<ConversationsBloc>(
    () => ConversationsBloc(
      chatRepository: getIt(),
      userRepository: getIt(),
      authRepository: getIt(),
    ),
  );
  getIt.registerFactory<ChatBloc>(
    () => ChatBloc(getIt()),
  );
  getIt.registerFactory<SuggestionBloc>(
    () => SuggestionBloc(getIt()),
  );
  getIt.registerFactory<ChatAnalyzerBloc>(
    () => ChatAnalyzerBloc(
      analyzerService: getIt(),
      cacheRepository: getIt(),
    ),
  );
  getIt.registerFactory<SmartActionBloc>(
    () => SmartActionBloc(),
  );
}

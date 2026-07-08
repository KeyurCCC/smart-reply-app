import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smart_reply_app/features/auth/data/repository/auth_repository_impl.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/chat/data/datasources/firestore_chat_datasource.dart';
import 'package:smart_reply_app/features/chat/data/repository/chat_repository_impl.dart';
import 'package:smart_reply_app/features/chat/data/repository/firestore_chat_datasource_impl.dart';
import 'package:smart_reply_app/features/chat/data/services/smart_reply_service.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:smart_reply_app/features/users/data/datasources/firestore_user_datasource.dart';
import 'package:smart_reply_app/features/users/data/repository/user_repository_impl.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn());

  getIt.registerLazySingleton<FirestoreUserDatasource>(
    () => FirestoreUserDatasourceImpl(firestore: getIt()),
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

  getIt.registerLazySingleton<FirestoreChatDatasource>(
    () => FirestoreChatDatasourceImpl(
      firestore: getIt(),
      firebaseAuth: getIt(),
    ),
  );
  getIt.registerLazySingleton<SmartReplyService>(() => SmartReplyService());
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      datasource: getIt(),
      authRepository: getIt(),
      userRepository: getIt(),
      smartReplyService: getIt(),
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
}

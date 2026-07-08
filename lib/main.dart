import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/auth/presentation/pages/login_page.dart';
import 'package:smart_reply_app/features/auth/presentation/widgets/auth_gate.dart';
import 'package:smart_reply_app/features/chat/presentation/pages/conversation_list_page.dart';
import 'package:smart_reply_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await configureDependencies();
  runApp(const SmartReplyApp());
}

class SmartReplyApp extends StatelessWidget {
  const SmartReplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = getIt<AuthRepository>();

    return MaterialApp(
      title: 'Smart Reply Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: authRepository.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const AuthGate(child: ConversationListPage());
          }

          return LoginPage(authRepository: authRepository);
        },
      ),
    );
  }
}

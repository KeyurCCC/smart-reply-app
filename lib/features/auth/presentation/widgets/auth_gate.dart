import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';

/// Waits once for a valid auth session before showing Firestore-backed UI.
/// Does not rebuild on token refresh (which would dispose child widgets).
class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareAuth();
  }

  Future<void> _prepareAuth() async {
    try {
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null);
      if (user != null) {
        await getIt<AuthRepository>().ensureAuthReady();
      }
      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Auth error: $_error')));
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}

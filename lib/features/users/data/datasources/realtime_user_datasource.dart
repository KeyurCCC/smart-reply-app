import 'package:firebase_database/firebase_database.dart';
import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';

abstract class RealtimeUserDatasource {
  Future<void> createOrUpdateUser(AppUser user);

  Future<AppUser?> getUser(String uid);

  Future<AppUser?> findUserByEmail(String email);

  Stream<AppUser?> listenUser(String uid);

  void trackUserPresence(String userId);

  Future<void> setUserOffline(String userId);
}

class RealtimeUserDatasourceImpl implements RealtimeUserDatasource {
  final FirebaseDatabase database;

  RealtimeUserDatasourceImpl({required this.database});

  @override
  Future<void> createOrUpdateUser(AppUser user) async {
    await database.ref('users/${user.id}').update({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'createdAt': user.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final snapshot = await database.ref('users/$uid').get();
    if (!snapshot.exists) return null;
    final value = snapshot.value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _fromMap(snapshot.key!, map);
    }
    return null;
  }

  @override
  Future<AppUser?> findUserByEmail(String email) async {
    final query = database.ref('users')
        .orderByChild('email')
        .equalTo(email.trim().toLowerCase())
        .limitToFirst(1);
    final event = await query.once();
    if (!event.snapshot.exists) return null;

    final value = event.snapshot.value;
    if (value is Map) {
      final map = Map<dynamic, dynamic>.from(value);
      final entry = map.entries.first;
      final userId = entry.key as String;
      final userData = Map<String, dynamic>.from(entry.value as Map);
      return _fromMap(userId, userData);
    }
    return null;
  }

  @override
  Stream<AppUser?> listenUser(String uid) {
    return database.ref('users/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        return _fromMap(event.snapshot.key!, map);
      }
      return null;
    });
  }

  @override
  void trackUserPresence(String userId) {
    final connectedRef = database.ref('.info/connected');
    final userRef = database.ref('users/$userId');

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (connected) {
        userRef.update({
          'online': true,
        });

        userRef.child('online').onDisconnect().set(false);
        userRef.child('lastSeen').onDisconnect().set(ServerValue.timestamp);
      }
    });
  }

  @override
  Future<void> setUserOffline(String userId) async {
    await database.ref('users/$userId').update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  AppUser _fromMap(String id, Map<String, dynamic> data) {
    final createdAtVal = data['createdAt'];
    DateTime createdAt;
    if (createdAtVal is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtVal);
    } else {
      createdAt = DateTime.now();
    }

    final lastSeenVal = data['lastSeen'];
    DateTime? lastSeen;
    if (lastSeenVal is int) {
      lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenVal);
    }

    return AppUser(
      id: id,
      displayName: data['displayName'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: createdAt,
      online: data['online'] as bool? ?? false,
      lastSeen: lastSeen,
    );
  }
}

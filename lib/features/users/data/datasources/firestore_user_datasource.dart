import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_reply_app/core/constants/firestore_constants.dart';
import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';

abstract class FirestoreUserDatasource {
  Future<void> createOrUpdateUser(AppUser user);

  Future<AppUser?> getUser(String uid);

  Future<AppUser?> findUserByEmail(String email);

  Stream<AppUser?> listenUser(String uid);
}

class FirestoreUserDatasourceImpl implements FirestoreUserDatasource {
  final FirebaseFirestore firestore;

  FirestoreUserDatasourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      firestore.collection(FirestoreConstants.users);

  @override
  Future<void> createOrUpdateUser(AppUser user) async {
    await _usersCollection.doc(user.id).set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'createdAt': Timestamp.fromDate(user.createdAt),
    }, SetOptions(merge: true));
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return _fromMap(doc.id, doc.data()!);
  }

  @override
  Future<AppUser?> findUserByEmail(String email) async {
    final snapshot = await _usersCollection
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return _fromMap(doc.id, doc.data());
  }

  @override
  Stream<AppUser?> listenUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromMap(doc.id, doc.data()!);
    });
  }

  AppUser _fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      displayName: data['displayName'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

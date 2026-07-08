import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';

abstract class UserRepository {
  Future<void> createOrUpdateUser(AppUser user);

  Future<AppUser?> getUser(String uid);

  Future<AppUser?> findUserByEmail(String email);

  Stream<AppUser?> listenUser(String uid);
}

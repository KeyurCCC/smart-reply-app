import 'package:smart_reply_app/features/users/data/datasources/realtime_user_datasource.dart';
import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final RealtimeUserDatasource datasource;

  UserRepositoryImpl({required this.datasource});

  @override
  Future<void> createOrUpdateUser(AppUser user) {
    return datasource.createOrUpdateUser(user);
  }

  @override
  Future<AppUser?> getUser(String uid) {
    return datasource.getUser(uid);
  }

  @override
  Future<AppUser?> findUserByEmail(String email) {
    return datasource.findUserByEmail(email);
  }

  @override
  Stream<AppUser?> listenUser(String uid) {
    return datasource.listenUser(uid);
  }
}

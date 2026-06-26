import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/failures.dart';
import '../supabase_service.dart';

// @AI_CORE_MECHANISM: [2026-06-26] 提供全局 AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseClient = ref.watch(supabaseProvider);
  return AuthRepository(supabaseClient.auth);
});

/// 认证领域的 Repository 层
/// 严格遵循 DDD 规范：所有的操作必须返回 TaskEither，绝对不抛出异常。
class AuthRepository {
  final GoTrueClient _auth;

  AuthRepository(this._auth);

  /// 邮箱密码登录
  /// 使用 TaskEither 包裹异步操作，确保异常在底层被捕获并转化为 AuthFailure
  TaskEitherApp<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return TaskEither.tryCatch(
      () async =>
          await _auth.signInWithPassword(email: email, password: password),
      (error, stackTrace) => AuthFailure('登录失败: ${error.toString()}', error),
    );
  }

  /// 邮箱密码注册
  TaskEitherApp<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) {
    return TaskEither.tryCatch(
      () async => await _auth.signUp(email: email, password: password),
      (error, stackTrace) => AuthFailure('注册失败: ${error.toString()}', error),
    );
  }

  /// 退出登录
  TaskEitherApp<void> signOut() {
    return TaskEither.tryCatch(
      () async => await _auth.signOut(),
      (error, stackTrace) => AuthFailure('登出失败: ${error.toString()}', error),
    );
  }
}

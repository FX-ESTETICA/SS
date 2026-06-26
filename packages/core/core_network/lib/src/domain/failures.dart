import 'package:fpdart/fpdart.dart';
import '../network_exceptions.dart';

/// @AI_CORE_MECHANISM: [2026-06-26] 全局错误处理基类
/// 所有的领域层错误都必须继承自 AppFailure，而不是抛出 Exception。
abstract class AppFailure {
  final String message;
  final dynamic cause;

  const AppFailure(this.message, [this.cause]);

  @override
  String toString() => 'AppFailure(message: $message, cause: $cause)';
}

/// 网络类错误
class ServerFailure extends AppFailure {
  const ServerFailure(super.message, [super.cause]);

  factory ServerFailure.fromNetworkException(NetworkException e) {
    return ServerFailure(e.message, e);
  }
}

/// 业务逻辑类错误 (如密码错误，余额不足)
class BusinessFailure extends AppFailure {
  const BusinessFailure(super.message, [super.cause]);
}

/// 认证类错误 (如未登录，Token 过期)
class AuthFailure extends AppFailure {
  const AuthFailure(super.message, [super.cause]);
}

/// 核心类型定义：所有的异步业务操作都必须返回这个类型，强制 UI 层进行错误处理 (fold)
typedef FutureEither<T> = Future<Either<AppFailure, T>>;

/// TaskEither 别名：延迟执行的异步操作，更符合纯函数式编程理念
typedef TaskEitherApp<T> = TaskEither<AppFailure, T>;

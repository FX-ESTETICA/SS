import 'package:dio/dio.dart';

/// 统一的网络异常处理类
class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  NetworkException(this.message, [this.statusCode]);

  factory NetworkException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('网络连接超时，请检查网络设置。');
      case DioExceptionType.badResponse:
        return NetworkException('服务器响应错误', error.response?.statusCode);
      default:
        return NetworkException('发生了未知的网络错误：${error.message}');
    }
  }

  factory NetworkException.unknown(String message) {
    return NetworkException(message);
  }

  @override
  String toString() => message;
}

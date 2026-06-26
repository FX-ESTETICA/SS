import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network_exceptions.dart';
import 'domain/failures.dart';

// @AI_CORE_MECHANISM: [2026-06-26] 基于 Riverpod 的 ApiClient 依赖注入
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'https://api.zhixuan.global');
});

/// API 客户端，封装了 Dio
/// 任何人请求网络，都必须通过 Riverpod (ref.read) 获取此实例
class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        contentType: 'application/json',
      ),
    );

    // 添加拦截器：可以在这里统一处理 Token、日志打印
    _dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  /// 所有的 GET 请求必须经过这里
  /// 返回值使用 Either，强制上层处理错误，彻底告别 try-catch 地狱和莫名其妙的崩溃
  FutureEither<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(
        ServerFailure.fromNetworkException(NetworkException.fromDioError(e)),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// POST 请求
  FutureEither<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response =
          await _dio.post(path, data: data, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(
        ServerFailure.fromNetworkException(NetworkException.fromDioError(e)),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// PUT 请求
  FutureEither<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response =
          await _dio.put(path, data: data, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(
        ServerFailure.fromNetworkException(NetworkException.fromDioError(e)),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// DELETE 请求
  FutureEither<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response =
          await _dio.delete(path, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(
        ServerFailure.fromNetworkException(NetworkException.fromDioError(e)),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

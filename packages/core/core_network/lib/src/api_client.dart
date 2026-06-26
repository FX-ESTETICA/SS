import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'network_exceptions.dart';

/// 全局单例的 API 客户端，封装了 Dio
/// 任何人请求网络，都必须经过这里，方便统一添加 Token、处理错误
class ApiClient {
  static ApiClient? _instance;

  factory ApiClient({String baseUrl = 'https://api.zhixuan.com'}) {
    _instance ??= ApiClient._internal(baseUrl: baseUrl);
    return _instance!;
  }

  late final Dio _dio;

  ApiClient._internal({required String baseUrl}) {
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
  Future<Either<NetworkException, dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters,}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(NetworkException.fromDioError(e));
    } catch (e) {
      return Left(NetworkException.unknown(e.toString()));
    }
  }

  /// POST 请求
  Future<Either<NetworkException, dynamic>> post(String path,
      {dynamic data, Map<String, dynamic>? queryParameters,}) async {
    try {
      final response =
          await _dio.post(path, data: data, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(NetworkException.fromDioError(e));
    } catch (e) {
      return Left(NetworkException.unknown(e.toString()));
    }
  }

  /// PUT 请求
  Future<Either<NetworkException, dynamic>> put(String path,
      {dynamic data, Map<String, dynamic>? queryParameters,}) async {
    try {
      final response =
          await _dio.put(path, data: data, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(NetworkException.fromDioError(e));
    } catch (e) {
      return Left(NetworkException.unknown(e.toString()));
    }
  }

  /// DELETE 请求
  Future<Either<NetworkException, dynamic>> delete(String path,
      {Map<String, dynamic>? queryParameters,}) async {
    try {
      final response =
          await _dio.delete(path, queryParameters: queryParameters);
      return Right(response.data);
    } on DioException catch (e) {
      return Left(NetworkException.fromDioError(e));
    } catch (e) {
      return Left(NetworkException.unknown(e.toString()));
    }
  }
}

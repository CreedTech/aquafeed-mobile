import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/data/auth_repository.dart';

part 'dio_provider.g.dart';

@riverpod
Future<PersistCookieJar> cookieJar(Ref ref) async {
  final appDocDir = await getApplicationDocumentsDirectory();
  return PersistCookieJar(storage: FileStorage("${appDocDir.path}/.cookies/"));
}

@riverpod
Future<Dio> dio(Ref ref) async {
  final dio = Dio();

  // Prefer compile-time environment override:
  // flutter run --dart-define=API_BASE_URL=https://your-host/api/v1
  final configuredBaseUrl = const String.fromEnvironment('API_BASE_URL');

  // Fallback for local development (Android emulator / iOS simulator).
  final baseUrl = configuredBaseUrl.isNotEmpty
      ? configuredBaseUrl
      : (kIsWeb
            ? 'http://127.0.0.1:5001/api/v1'
            : (Platform.isAndroid
                  ? 'http://10.0.2.2:5001/api/v1'
                  : 'http://127.0.0.1:5001/api/v1'));

  dio.options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  );

  // Cookie Persistence for Session Auth
  final cookieJar = await ref.watch(cookieJarProvider.future);
  dio.interceptors.add(CookieManager(cookieJar));

  // Logging Interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('--- Dio Request ---');
        debugPrint('Url: ${options.uri}');
        debugPrint('-------------------');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('--- Dio Response ---');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('--------------------');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        // Handle Session Expiry (401)
        if (e.response?.statusCode == 401) {
          final hasUser = ref.read(currentUserProvider).value != null;
          if (hasUser) {
            debugPrint('Session expired (401). Clearing state.');
            ref.invalidate(currentUserProvider);
          }
        }

        if (e.response?.statusCode != 401) {
          debugPrint('--- Dio Error ---');
          debugPrint('Url: ${e.requestOptions.uri}');
          debugPrint('Status: ${e.response?.statusCode}');
          debugPrint('Body: ${e.response?.data}');
          debugPrint('-----------------');
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
}

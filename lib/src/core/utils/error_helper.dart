import 'package:dio/dio.dart';

/// Error helper for user-friendly error messages
class ErrorHelper {
  /// Convert any error to a user-friendly message
  static String getUserMessage(dynamic error) {
    // Handle DioException specifically
    if (error is DioException) {
      return _handleDioError(error);
    }

    // Handle string errors
    if (error is String) {
      return _cleanErrorMessage(error);
    }

    // Generic error
    return _cleanErrorMessage(error.toString());
  }

  /// Handle Dio errors with specific messages
  static String _handleDioError(DioException error) {
    // Check for server response with error message
    if (error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map) {
        // Try to extract error message from response
        final message = data['message'] ?? data['error'] ?? data['msg'];
        if (message != null) {
          return _cleanErrorMessage(message.toString());
        }
      }
    }

    // Handle by status code
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Invalid request. Please check your input.';
        case 401:
          return 'Please sign in to continue.';
        case 403:
          return 'You don\'t have permission for this action.';
        case 404:
          return 'The requested item was not found.';
        case 409:
          return 'This item already exists.';
        case 422:
          return 'Please check your input and try again.';
        case 429:
          return 'Too many requests. Please wait a moment.';
        case 500:
          return 'Server error. Please try again later.';
        case 502:
        case 503:
        case 504:
          return 'Server is temporarily unavailable. Please try again.';
        default:
          if (statusCode >= 400 && statusCode < 500) {
            return 'Request failed. Please try again.';
          }
          if (statusCode >= 500) {
            return 'Server error. Please try again later.';
          }
      }
    }

    // Handle by error type
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.badCertificate:
        return 'Security error. Please update the app.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Clean and format error message
  static String _cleanErrorMessage(String message) {
    // Remove common prefixes
    var cleaned = message
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .replaceAll('DioError: ', '')
        .replaceAll('SocketException: ', '')
        .trim();

    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // Ensure it ends with period
    if (cleaned.isNotEmpty &&
        !cleaned.endsWith('.') &&
        !cleaned.endsWith('!') &&
        !cleaned.endsWith('?')) {
      cleaned = '$cleaned.';
    }

    // Truncate if too long
    if (cleaned.length > 100) {
      cleaned = '${cleaned.substring(0, 100)}...';
    }

    return cleaned.isEmpty
        ? 'Something went wrong. Please try again.'
        : cleaned;
  }

  /// Check if error is network-related
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
    }
    return false;
  }

  /// Check if error requires re-authentication
  static bool requiresAuth(dynamic error) {
    if (error is DioException) {
      return error.response?.statusCode == 401;
    }
    return false;
  }
}

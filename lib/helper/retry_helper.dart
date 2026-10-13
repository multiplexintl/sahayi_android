import 'dart:developer';

import '../service/app_logger.dart';

class RetryHelper {
  /// Retry logic for API calls
  static Future<T> retry<T>({
    required Future<T> Function() apiCall, // Required API call function
    required T defaultValue, // Fallback value if retries fail
    int maxRetries = 3, // Maximum retry attempts
    Duration retryDelay = const Duration(seconds: 2), // Delay between retries
    bool Function(T result)? shouldRetry, // Retry condition based on result
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        attempt++;
        log("Attempt $attempt of $maxRetries");

        // Perform the API call
        T result = await apiCall();

        // Check retry condition
        if (shouldRetry == null || !shouldRetry(result)) {
          return result; // Success: return the result
        }

        log("Retry condition met. Retrying...");
        AppLogger.warn('Retry',
            'Attempt $attempt of $maxRetries returned an unwanted result: $result');
      } catch (e, st) {
        log(e.toString());
        AppLogger.warn('Retry', 'Attempt $attempt of $maxRetries threw: $e',
            details: 'Stack: $st');
      }

      // Delay before retrying
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    log("All retries failed. Returning default value.");
    AppLogger.error('RetryGaveUp',
        'All $maxRetries attempts failed. Returning default: $defaultValue');
    return defaultValue; // Return fallback value if all retries fail
  }
}

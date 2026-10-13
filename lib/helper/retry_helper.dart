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
    // Return false to stop retrying after this error (e.g. a save that timed
    // out may already be stored on the server).
    bool Function(Object error)? retryOnError,
    // Throw the last error instead of returning defaultValue, so callers can
    // tell "server unreachable" apart from "no data".
    bool throwWhenAllFail = false,
  }) async {
    int attempt = 0;
    Object? lastError;
    StackTrace? lastStack;

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

        lastError = null;
        log("Retry condition met. Retrying...");
        AppLogger.warn('Retry',
            'Attempt $attempt of $maxRetries returned an unwanted result: $result');
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        log(e.toString());
        AppLogger.warn('Retry', 'Attempt $attempt of $maxRetries threw: $e',
            details: 'Stack: $st');

        if (retryOnError != null && !retryOnError(e)) {
          AppLogger.warn('Retry', 'Not retrying after this error');
          break;
        }
      }

      // Delay before retrying
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    log("All retries failed. Returning default value.");
    AppLogger.error('RetryGaveUp',
        'Gave up after $attempt attempt(s). ${throwWhenAllFail && lastError != null ? 'Passing the error on' : 'Returning default: $defaultValue'}');

    if (throwWhenAllFail && lastError != null) {
      Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
    }
    return defaultValue; // Return fallback value if all retries fail
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _maxLogFileBytes = 1024 * 1024;
  static const String _logDirectoryName = 'logs';
  static const String _logFileName = 'app.log';
  static const String _previousLogFileName = 'app.previous.log';

  Future<File>? _logFileFuture;

  Future<void> initialize() async {
    await _resolveLogFile();
  }

  Future<String> getLogFilePath() async {
    final file = await _resolveLogFile();
    return file.path;
  }

  Future<void> debug(
    String tag,
    String message, {
    Map<String, Object?>? context,
  }) {
    if (kDebugMode) {
      return _write(
        level: 'DEBUG',
        tag: tag,
        message: message,
        context: context,
      );
    }
    return Future.value();
  }

  Future<void> info(
    String tag,
    String message, {
    Map<String, Object?>? context,
  }) {
    return _write(
      level: 'INFO',
      tag: tag,
      message: message,
      context: context,
    );
  }

  Future<void> warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    return _write(
      level: 'WARN',
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  Future<void> error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    return _write(
      level: 'ERROR',
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    return error(
      'flutter',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      context: {
        'library': details.library,
        'context': details.context?.toDescription(),
      },
    );
  }

  Future<File> _resolveLogFile() {
    return _logFileFuture ??= _createLogFile();
  }

  Future<File> _createLogFile() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final logDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}$_logDirectoryName',
    );
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }

    final logFile = File(
      '${logDirectory.path}${Platform.pathSeparator}$_logFileName',
    );
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    await _rotateIfNeeded(logDirectory, logFile);
    return logFile;
  }

  Future<void> _rotateIfNeeded(Directory logDirectory, File logFile) async {
    final size = await logFile.length();
    if (size < _maxLogFileBytes) {
      return;
    }

    final previousLogFile = File(
      '${logDirectory.path}${Platform.pathSeparator}$_previousLogFileName',
    );
    if (await previousLogFile.exists()) {
      await previousLogFile.delete();
    }

    await logFile.rename(previousLogFile.path);
    await logFile.create(recursive: true);
  }

  Future<void> _write({
    required String level,
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) async {
    try {
      final file = await _resolveLogFile();
      await _rotateIfNeeded(file.parent, file);

      final entry = <String, Object?>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'tag': tag,
        'message': message,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (context != null && context.isNotEmpty) 'context': context,
      };

      final line = jsonEncode(entry);
      debugPrint(line);
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (loggingError, loggingStackTrace) {
      debugPrint('AppLogger failure: $loggingError\n$loggingStackTrace');
    }
  }
}

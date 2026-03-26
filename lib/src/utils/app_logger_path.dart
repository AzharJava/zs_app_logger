// Main export file with conditional imports for platform-specific implementations
export 'app_logger_path_stub.dart'
    if (dart.library.io) 'app_logger_path_io.dart'
    if (dart.library.html) 'app_logger_path_web.dart';

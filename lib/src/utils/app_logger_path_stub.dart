// Stub file for platforms that don't support file operations
import '../../app_logger.dart';

Future<String> getDownloadsPathZSAppLogger() async {
  ZSAppLogger.log("Downloads path not supported on this platform");
  return "";
}

Future<dynamic> writeBytesToDownloadsZSAppLogger(String bytes, String name) async {
  ZSAppLogger.log("File write not supported on this platform");
  return null;
}

Future<String> getExternalDocumentPathZSAppLogger() async {
  ZSAppLogger.log("Document path not supported on this platform");
  return "";
}

bool checkIfNotNullZSAppLogger(String? value) {
  return value != null &&
      value.trim().isNotEmpty &&
      value.trim() != "null" &&
      value.trim() != "";
}

Future<void> openFileInNativeViewZSAppLogger(String path) async {
  ZSAppLogger.log("File open not supported on this platform");
}

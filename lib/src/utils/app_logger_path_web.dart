// Web implementation for file operations
import 'dart:html' as html;
import '../../app_logger.dart';

Future<String> getDownloadsPathZSAppLogger() async {
  // Web doesn't have a downloads path concept
  // Files are downloaded directly via browser
  return "";
}

Future<String?> writeBytesToDownloadsZSAppLogger(String bytes, String name) async {
  try {
    // Create a blob from the string content
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create an anchor element to trigger download
    html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();

    // Clean up the URL object
    html.Url.revokeObjectUrl(url);

    // Return the filename for web (since we can't get the actual path)
    return name;
  } catch (e) {
    ZSAppLogger.log("Error downloading file on web: $e");
    return null;
  }
}

Future<String> getExternalDocumentPathZSAppLogger() async {
  // Web doesn't have a document path concept
  return "";
}

bool checkIfNotNullZSAppLogger(String? value) {
  return value != null &&
      value.trim().isNotEmpty &&
      value.trim() != "null" &&
      value.trim() != "";
}

Future<void> openFileInNativeViewZSAppLogger(String path) async {
  // On web, files are opened in the browser automatically after download
  // This is a no-op for web
  ZSAppLogger.log("File open not applicable on web platform");
}

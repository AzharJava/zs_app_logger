// IO implementation for mobile/desktop platforms
import 'dart:io';

import 'package:open_file/open_file.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';

import '../../app_logger.dart';

Future<String> getDownloadsPathZSAppLogger() async {
  try {
    if (Platform.isAndroid) {
      // For Android, try to get the Downloads directory
      // First try the standard path
      final downloadsPath = '/storage/emulated/0/Download';
      final downloadsDir = Directory(downloadsPath);

      // Check if the directory exists or can be created
      if (await downloadsDir.exists() ||
          (await downloadsDir.parent.exists() &&
              await downloadsDir
                  .create(recursive: true)
                  .then((_) => true)
                  .catchError((_) => false))) {
        return downloadsPath;
      }

      // Fallback: try to get external storage directory and append Download
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to the Downloads folder from external storage
          // External storage is usually at /storage/emulated/0/Android/data/package_name/files
          // We need to go up to /storage/emulated/0/Download
          final parts = externalDir.path.split('/');
          if (parts.length >= 4 && parts[0] == '' && parts[1] == 'storage') {
            // Construct path: /storage/emulated/0/Download
            final downloadPath =
                '/${parts[1]}/${parts[2]}/${parts[3]}/Download';
            final downloadDir = Directory(downloadPath);
            if (await downloadDir.exists() ||
                await downloadDir
                    .create(recursive: true)
                    .then((_) => true)
                    .catchError((_) => false)) {
              return downloadPath;
            }
          }
        }
      } catch (e) {
        ZSAppLogger.log("Error getting external storage: $e");
      }

      // Final fallback: use application documents directory
      return await getExternalDocumentPathZSAppLogger();
    } else if (Platform.isIOS) {
      // iOS doesn't allow direct access to Downloads folder
      // Use Documents directory as fallback
      return await getExternalDocumentPathZSAppLogger();
    } else {
      // For other platforms, use documents directory
      return await getExternalDocumentPathZSAppLogger();
    }
  } catch (e) {
    ZSAppLogger.log("Error getting Downloads path: $e");
    // Fallback to documents directory
    return await getExternalDocumentPathZSAppLogger();
  }
}

Future<dynamic> writeBytesToDownloadsZSAppLogger(
    String bytes, String name) async {
  final path = await getDownloadsPathZSAppLogger();
  // Create a file for the path of
  // device and file name with extension
  if (checkIfNotNullZSAppLogger(path) &&
      checkIfNotNullZSAppLogger(bytes) &&
      checkIfNotNullZSAppLogger(name)) {
    // Ensure the directory exists
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    File file = File('$path/$name');

    // Write the data in the file you have created
    return file.writeAsString(bytes);
  }
  return null;
}

Future<String> getExternalDocumentPathZSAppLogger() async {
  try {
    Directory? directory = await getApplicationDocumentsDirectory();
    final exPath = directory.path;
    await Directory(exPath).create(recursive: true);
    return exPath;
  } catch (e) {
    ZSAppLogger.log("Directory is null");
    return "";
  }
}

bool checkIfNotNullZSAppLogger(String? value) {
  return value != null &&
      value.trim().isNotEmpty &&
      value.trim() != "null" &&
      value.trim() != "";
}

Future<void> openFileInNativeViewZSAppLogger(String path) async {
  await OpenFile.open(path);
}

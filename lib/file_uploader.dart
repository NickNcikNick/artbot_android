import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';  // To set correct content type
import 'package:flutter/services.dart';
import 'package:http_parser/http_parser.dart'; // Add this for MediaType


class FileUploader {
  /// Uploads a file to the specified server URL using HTTP POST.
  static Future<bool> uploadFile(String filePath) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String ipAddress = prefs.getString('websocket_ip') ??
        '192.168.4.1'; // Default IP
    String url = "http://$ipAddress/upload";

    File file = File(filePath);

    if (!file.existsSync()) {
      print("File does not exist: $filePath");
      return false;
    }

    // Extract filename
    String fileName = await _getActualFileName(filePath);

    // Get MIME type
    String? mimeType = lookupMimeType(filePath) ?? "application/octet-stream";

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: fileName, // Ensure correct filename
      contentType: MediaType.parse(mimeType),
    ));

    // **Ensure headers include filename**
    request.headers['Content-Disposition'] = 'attachment; filename="$fileName"';

    var response = await request.send();
    if (response.statusCode == 200) {
      print('File uploaded successfully');
      return true;
    } else {
      print('File upload failed: ${response.statusCode}');
      return false;
    }
  }

  /// Tries to get the real filename from a file path
  static Future<String> _getActualFileName(String filePath) async {
    String fileName = path.basename(filePath);

    try {
      // Android: If the file is in a cache directory, use MediaStore API (Flutter plugin needed)
      if (filePath.contains('/cache/') || filePath.contains('/temp/')) {
        // Retrieve the actual filename if selected via media picker
        String? realName = await getRealFileNameFromMediaStore(filePath);
        if (realName != null) {
          fileName = realName;
        }
      }
    } catch (e) {
      print("Error getting real filename: $e");
    }

    return fileName;
  }

  /// Placeholder function to retrieve filename from MediaStore (Implement if needed)
 static Future<String?> getRealFileNameFromMediaStore(String filePath) async {
    // You may need to use `flutter_media_store` or a similar plugin to query Android MediaStore
    return null;  // Return null for now
  }
}
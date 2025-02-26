import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'dart:math';

class PreProcessing {
  /// Processes the image and returns a new image path
  Future<String> processImage(String imagePath) async {
    File file = File(imagePath);
    Uint8List bytes = await file.readAsBytes();

    // Load image using the `image` package
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      print("Failed to decode image");
      return "ERROR";
    }

    // Convert image to grayscale (8-bit)
    image = img.grayscale(image);

    Uint8List bmpBytes = Uint8List.fromList(img.encodeBmp(image));
    int currentSize = bmpBytes.lengthInBytes;

    // Define max size in bytes (2.9MB)
    int maxSize = (2.9 * 1024 * 1024).toInt();

    if (currentSize > maxSize) {
      // Calculate the required scaling factor
      double scaleFactor = sqrt(maxSize / currentSize);
      int newWidth = (image.width * scaleFactor).toInt();
      int newHeight = (image.height * scaleFactor).toInt();

      // Resize with high-quality Lanczos3 filter
      image = img.copyResize(image, width: newWidth, height: newHeight, interpolation: img.Interpolation.linear);
    } else {
      print("No resizing needed. Image size: ${currentSize / (1024 * 1024)} MB");
    }

    // Encode as BMP
    bmpBytes = Uint8List.fromList(img.encodeBmp(image));
    // Save the resized image
    Directory tempDir = await getTemporaryDirectory();

    // Get the next image number and store it
    int imageNumber = await _getNextImageNumber();
    String imageName = "${imageNumber.toString().padLeft(4, '0')}.bmp";
    String newFilePath = path.join(tempDir.path, imageName);

    // Save BMP file
    File newFile = File(newFilePath);
    await newFile.writeAsBytes(bmpBytes);

    print("Image resized and saved at: $newFilePath (New size: ${bmpBytes.lengthInBytes / (1024 * 1024)} MB)");

    return newFilePath;
  }

  /// Retrieves the next image number and increments it for future use
  Future<int> _getNextImageNumber() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int lastNumber = prefs.getInt('image_number') ?? 0; // Default to 0 if not set
    int nextNumber = lastNumber + 1;
    await prefs.setInt('image_number', nextNumber); // Store the updated number
    return nextNumber;
  }
}
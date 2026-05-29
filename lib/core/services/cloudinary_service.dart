import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Service d'upload d'images vers Cloudinary
class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static Uri get _uploadUrl =>
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

  static Future<String?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 512,
    int quality = 80,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        imageQuality: quality,
      );
      if (picked == null) return null;

      return await uploadFile(picked);
    } catch (e) {
      debugPrint('Erreur pick & upload: $e');
      return null;
    }
  }

  /// Upload un XFile déjà sélectionné vers Cloudinary.
  static Future<String?> uploadFile(XFile file) async {
    try {
      final request = http.MultipartRequest('POST', _uploadUrl);
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'esp_sekou/avatars';

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      } else {
        final body = await response.stream.bytesToString();
        debugPrint('Cloudinary upload failed: $body');
        return null;
      }
    } catch (e) {
      debugPrint('Erreur upload Cloudinary: $e');
      return null;
    }
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

class CloudinaryUploadService {
  Future<String> uploadFile({
    required String localPath,
    String? folder,
    String? publicId,
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw StateError(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET in dart_define.json.',
      );
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', localPath));

    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = publicId;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map || body['secure_url'] == null) {
      throw Exception('Cloudinary upload did not return a URL.');
    }

    return body['secure_url'].toString();
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage();

  static final http.Client _client = http.Client();
  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _headers({bool jsonBody = true}) async {
    final token = await _tokenStorage.readToken();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> postEmpty(String path) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      _decode(response);
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> uploadTest({
    required String title,
    required int branchId,
    required int semester,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required int timeLimitMinutes,
    String? pdfPath,
    List<int>? pdfBytes,
    required String pdfName,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/tests'));
    request.headers.addAll(await _headers(jsonBody: false));
    request.fields.addAll({
      'title': title,
      'branchId': '$branchId',
      'semester': '$semester',
      'scheduledStart': scheduledStart.toUtc().toIso8601String(),
      'scheduledEnd': scheduledEnd.toUtc().toIso8601String(),
      'timeLimitMinutes': '$timeLimitMinutes',
    });
    request.files.add(await _multipartFile('pdf',
        path: pdfPath, bytes: pdfBytes, filename: pdfName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<dynamic> replacePdf({
    required int testId,
    String? pdfPath,
    List<int>? pdfBytes,
    required String pdfName,
  }) async {
    final request = http.MultipartRequest(
        'PUT', Uri.parse('${ApiConfig.baseUrl}/tests/$testId/pdf'));
    request.headers.addAll(await _headers(jsonBody: false));
    request.files.add(await _multipartFile('pdf',
        path: pdfPath, bytes: pdfBytes, filename: pdfName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<String> downloadPdf(int testId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/tests/$testId/admin/pdf'),
      headers: {
        ...await _headers(jsonBody: false),
        'Accept': 'application/pdf',
      },
    );
    if (response.statusCode >= 400) {
      _decode(response);
    }
    _ensurePdfResponse(response);
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/polyht_admin_test_${testId}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  Future<dynamic> uploadPhoto({
    required String path,
    String? imagePath,
    List<int>? imageBytes,
    required String imageName,
  }) async {
    final request =
        http.MultipartRequest('PUT', Uri.parse('${ApiConfig.baseUrl}$path'));
    request.headers.addAll(await _headers(jsonBody: false));
    request.files.add(await _multipartFile('photo',
        path: imagePath, bytes: imageBytes, filename: imageName));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<http.MultipartFile> _multipartFile(
    String field, {
    String? path,
    List<int>? bytes,
    required String filename,
  }) async {
    final contentType = _contentTypeFor(filename);
    if (bytes != null) {
      return http.MultipartFile.fromBytes(field, bytes,
          filename: filename, contentType: contentType);
    }
    if (path != null) {
      return http.MultipartFile.fromPath(field, path,
          filename: filename, contentType: contentType);
    }
    throw Exception('No file selected');
  }

  MediaType? _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return null;
  }

  dynamic _decode(http.Response response) {
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(_messageFromBody(body));
    }
    return body;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  String _messageFromBody(dynamic body) {
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    if (body is String && body.trim().isNotEmpty) {
      final text = body.trim();
      final lower = text.toLowerCase();
      if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
        return 'The server route is not available yet. Please try again after the backend deployment finishes.';
      }
      if (lower.startsWith('forbidden') ||
          lower.contains('bom1::') ||
          lower.contains('sfo1::') ||
          lower.contains('iad1::')) {
        return 'Upload was blocked before it reached the app server. Use a PDF under 4 MB or re-export/compress the PDF, then try again.';
      }
      return text.length > 240 ? '${text.substring(0, 240)}...' : text;
    }
    return 'Request failed';
  }

  void _ensurePdfResponse(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final bytes = response.bodyBytes;
    final hasPdfHeader = bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    if (contentType.toLowerCase().contains('application/pdf') || hasPdfHeader) {
      return;
    }

    final body = _decodeBody(response);
    throw Exception(_messageFromBody(body));
  }
}

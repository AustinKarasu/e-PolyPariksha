import '../models/student_test.dart';
import 'api_client.dart';

class TestService {
  TestService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<StudentTest>> fetchTests() async {
    final data = await _apiClient.get('/tests');
    return (data['tests'] as List).map((item) => StudentTest.fromJson(item)).toList();
  }

  Future<List<StudentTest>> fetchHistory() async {
    final data = await _apiClient.get('/tests/history');
    return (data['tests'] as List).map((item) => StudentTest.fromJson(item)).toList();
  }

  Future<void> startAttempt(int testId) => _apiClient.post('/attempts/$testId/start', {});

  Future<void> completeAttempt(int testId, {String? answerNote}) {
    return _apiClient.post('/attempts/$testId/complete', {
      if (answerNote != null && answerNote.trim().isNotEmpty) 'answerNote': answerNote.trim(),
    });
  }

  Future<String> downloadPdf(int testId) => _apiClient.downloadPdf(testId);

  Future<bool> recordEvent(int testId, String eventType, {Map<String, dynamic>? metadata}) async {
    final data = await _apiClient.post('/attempts/$testId/events', {
      'eventType': eventType,
      'metadata': metadata ?? {},
    });
    return data['locked'] == true;
  }
}

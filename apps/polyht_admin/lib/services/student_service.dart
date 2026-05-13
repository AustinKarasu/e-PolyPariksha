import '../models/app_user.dart';
import 'api_client.dart';

class StudentService {
  StudentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();
  final ApiClient _apiClient;

  Future<List<AppUser>> fetchStudents({int? branchId, String? search, int? limit, int? offset}) async {
    final params = <String>[];
    if (branchId != null) params.add('branchId=$branchId');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeQueryComponent(search)}');
    if (limit != null) params.add('limit=$limit');
    if (offset != null) params.add('offset=$offset');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final data = await _apiClient.get('/students$query');
    return (data['students'] as List).map((j) => AppUser.fromJson(j)).toList();
  }

  Future<List<AppUser>> fetchAllStudents() async {
    final all = <AppUser>[];
    var offset = 0;
    const limit = 500;
    while (true) {
      final page = await fetchStudents(limit: limit, offset: offset);
      all.addAll(page);
      if (page.length < limit) break;
      offset += limit;
    }
    return all;
  }

  Future<AppUser> fetchStudent(int id) async {
    final data = await _apiClient.get('/students/$id');
    return AppUser.fromJson(data['student']);
  }

  Future<AppUser> createStudent({
    required String fullName,
    required String collegeId,
    required String password,
    required int branchId,
    String? email,
    int? semester,
    String? rollNo,
    String? boardRollNo,
    String? courseName,
    String? guardianName,
    String? phone,
    String? address,
    int? admissionYear,
  }) async {
    final data = await _apiClient.post('/students', {
      'fullName': fullName,
      'collegeId': collegeId,
      'password': password,
      'branchId': branchId,
      if (email != null && email.isNotEmpty) 'email': email,
      if (semester != null) 'semester': semester,
      if (rollNo != null && rollNo.isNotEmpty) 'rollNo': rollNo,
      if (boardRollNo != null && boardRollNo.isNotEmpty) 'boardRollNo': boardRollNo,
      if (courseName != null && courseName.isNotEmpty) 'courseName': courseName,
      if (guardianName != null && guardianName.isNotEmpty) 'guardianName': guardianName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      if (admissionYear != null) 'admissionYear': admissionYear,
    });
    return AppUser.fromJson(data['student']);
  }

  Future<AppUser> updateStudent({
    required int id,
    required String fullName,
    required int branchId,
    String? email,
    String? collegeId,
    String? password,
    int? semester,
    String? rollNo,
    String? boardRollNo,
    String? courseName,
    String? guardianName,
    String? phone,
    String? address,
    int? admissionYear,
    bool? isActive,
  }) async {
    final data = await _apiClient.patch('/students/$id', {
      'fullName': fullName,
      'branchId': branchId,
      if (email != null && email.isNotEmpty) 'email': email,
      if (collegeId != null && collegeId.isNotEmpty) 'collegeId': collegeId,
      if (password != null && password.isNotEmpty) 'password': password,
      if (semester != null) 'semester': semester,
      if (rollNo != null && rollNo.isNotEmpty) 'rollNo': rollNo,
      if (boardRollNo != null && boardRollNo.isNotEmpty) 'boardRollNo': boardRollNo,
      if (courseName != null && courseName.isNotEmpty) 'courseName': courseName,
      if (guardianName != null && guardianName.isNotEmpty) 'guardianName': guardianName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      if (admissionYear != null) 'admissionYear': admissionYear,
      if (isActive != null) 'isActive': isActive,
    });
    return AppUser.fromJson(data['student']);
  }

  Future<void> deleteStudent(int id) async {
    await _apiClient.delete('/students/$id');
  }

  Future<AppUser> uploadStudentPhoto({
    required int id,
    String? imagePath,
    List<int>? imageBytes,
    required String imageName,
  }) async {
    final data = await _apiClient.uploadPhoto(
      path: '/students/$id/photo',
      imagePath: imagePath,
      imageBytes: imageBytes,
      imageName: imageName,
    );
    return AppUser.fromJson(data['student']);
  }
}

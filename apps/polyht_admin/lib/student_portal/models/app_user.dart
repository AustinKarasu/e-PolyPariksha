class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    this.email,
    this.collegeId,
    required this.role,
    this.branchId,
    this.branchName,
    this.branchCode,
    this.dob,
    this.semester,
    this.rollNo,
    this.boardRollNo,
    this.collegeName,
    this.courseName,
    this.guardianName,
    this.phone,
    this.address,
    this.admissionYear,
    this.dropoutYear,
    this.photoUrl,
    this.twoFactorEnabled,
    this.isPrimaryAdmin,
    this.mustChangeCredentials = false,
  });

  final int id;
  final String fullName;
  final String? email;
  final String? collegeId;
  final String role;
  final int? branchId;
  final String? branchName;
  final String? branchCode;
  final String? dob;
  final int? semester;
  final String? rollNo;
  final String? boardRollNo;
  final String? collegeName;
  final String? courseName;
  final String? guardianName;
  final String? phone;
  final String? address;
  final int? admissionYear;
  final int? dropoutYear;
  final String? photoUrl;
  final bool? twoFactorEnabled;
  final bool? isPrimaryAdmin;
  final bool mustChangeCredentials;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      collegeId: json['college_id'] as String?,
      role: json['role'] as String,
      branchId: json['branch_id'] as int?,
      branchName: json['branch_name'] as String?,
      branchCode: json['branch_code'] as String?,
      dob: json['dob'] as String?,
      semester: json['semester'] as int?,
      rollNo: json['roll_no'] as String?,
      boardRollNo: json['board_roll_no'] as String?,
      collegeName: json['college_name'] as String?,
      courseName: json['course_name'] as String?,
      guardianName: json['guardian_name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      admissionYear: json['admission_year'] as int?,
      dropoutYear: json['dropout_year'] as int?,
      photoUrl: json['photo_url'] as String?,
      twoFactorEnabled:
          json['two_factor_enabled'] == true || json['two_factor_enabled'] == 1,
      isPrimaryAdmin:
          json['is_primary_admin'] == true || json['is_primary_admin'] == 1,
      mustChangeCredentials: json['must_change_credentials'] == true ||
          json['must_change_credentials'] == 1,
    );
  }
}

class AdminApplication {
  AdminApplication({
    required this.id,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.collegeName,
    required this.stateName,
    required this.status,
    this.createdAt,
  });

  final int id;
  final String fullName;
  final String mobile;
  final String email;
  final String collegeName;
  final String stateName;
  final String status;
  final DateTime? createdAt;

  factory AdminApplication.fromJson(Map<String, dynamic> json) {
    return AdminApplication(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      mobile: json['mobile'] as String,
      email: json['email'] as String,
      collegeName: json['college_name'] as String,
      stateName: json['state_name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

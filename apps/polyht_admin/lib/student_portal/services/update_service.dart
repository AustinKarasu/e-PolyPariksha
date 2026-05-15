import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/update_config.dart';

class AppUpdate {
  AppUpdate({
    required this.latestVersion,
    required this.latestBuild,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String latestVersion;
  final int latestBuild;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      latestVersion: json['latestVersion'] as String,
      latestBuild: json['latestBuild'] as int,
      downloadUrl: json['downloadUrl'] as String,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class UpdateService {
  Future<AppUpdate?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final response = await http.get(Uri.parse(UpdateConfig.manifestUrl)).timeout(const Duration(seconds: 2));
    if (response.statusCode >= 400) {
      throw Exception('Unable to check for updates');
    }
    final update = AppUpdate.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    return update.latestBuild > currentBuild || _isNewerVersion(update.latestVersion, packageInfo.version) ? update : null;
  }

  Future<void> openDownload(AppUpdate update) async {
    final uri = Uri.parse(update.downloadUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Unable to open update download link');
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map((item) => int.tryParse(item) ?? 0).toList();
    final currentParts = current.split('.').map((item) => int.tryParse(item) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l != c) return l > c;
    }
    return false;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/update_config.dart';

class AppUpdate {
  AppUpdate({
    required this.latestVersion,
    required this.latestBuild,
    required this.downloadUrl,
    required this.playStoreUrl,
    required this.packageName,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String latestVersion;
  final int latestBuild;
  final String downloadUrl;
  final String playStoreUrl;
  final String packageName;
  final String releaseNotes;
  final bool mandatory;

  bool get usesPlayStore => playStoreUrl.isNotEmpty;
  String get actionLabel =>
      usesPlayStore ? 'Update on Play Store' : 'Install update';
  String get fallbackMessage => usesPlayStore
      ? 'A newer Play Store build is ready to install.'
      : 'A newer APK is ready to install.';

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    final packageName = json['packageName'] as String? ??
        Uri.tryParse(json['playStoreUrl'] as String? ?? '')
            ?.queryParameters['id'] ??
        'in.polyht.polyht_admin';
    return AppUpdate(
      latestVersion: json['latestVersion'] as String? ?? '0.0.0',
      latestBuild: json['latestBuild'] is int
          ? json['latestBuild'] as int
          : int.tryParse('${json['latestBuild']}') ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ??
          (json['usePlayStore'] == true
              ? 'https://play.google.com/store/apps/details?id=$packageName'
              : ''),
      packageName: packageName,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class UpdateService {
  Future<AppUpdate?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final update = await _fetchUpdateManifest();
    if (update.latestBuild > 0) {
      return update.latestBuild > currentBuild ? update : null;
    }
    return _isNewerVersion(update.latestVersion, packageInfo.version)
        ? update
        : null;
  }

  Future<AppUpdate> _fetchUpdateManifest() async {
    Object? lastError;
    final urls = <String>{
      UpdateConfig.manifestUrl,
      UpdateConfig.fallbackManifestUrl,
    }.where((url) => url.trim().isNotEmpty);

    for (final url in urls) {
      try {
        final uri = Uri.parse(url).replace(queryParameters: {
          ...Uri.parse(url).queryParameters,
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode >= 400) {
          lastError = 'Update manifest returned ${response.statusCode}';
          continue;
        }
        return AppUpdate.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } catch (err) {
        lastError = err;
      }
    }

    throw Exception('Unable to check for updates: $lastError');
  }

  Future<void> openUpdate(AppUpdate update) async {
    if (update.usesPlayStore) {
      final packageName = update.packageName;
      final marketUri = Uri.parse('market://details?id=$packageName');
      if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
        return;
      }
      final storeUri = Uri.parse(update.playStoreUrl);
      if (await launchUrl(storeUri, mode: LaunchMode.externalApplication)) {
        return;
      }
      throw Exception('Unable to open Play Store');
    }
    if (update.downloadUrl.isEmpty) {
      throw Exception('Update link is not available yet');
    }
    if (!Platform.isAndroid) {
      final downloadUri = Uri.parse(update.downloadUrl);
      if (!await launchUrl(downloadUri, mode: LaunchMode.externalApplication)) {
        throw Exception('Unable to open update link');
      }
      return;
    }
    final apk = await _downloadApk(update);
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message.isEmpty
          ? 'Unable to start update installer'
          : result.message);
    }
  }

  Future<File> _downloadApk(AppUpdate update) async {
    final uri = Uri.parse(update.downloadUrl);
    final request = http.Request('GET', uri)..followRedirects = true;
    final response = await request.send().timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      throw Exception('Unable to download update');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/epolypariksha-hp-update.apk');
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } catch (_) {
      await sink.close();
      rethrow;
    }
    return file;
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts =
        latest.split('.').map((item) => int.tryParse(item) ?? 0).toList();
    final currentParts =
        current.split('.').map((item) => int.tryParse(item) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l != c) return l > c;
    }
    return false;
  }
}

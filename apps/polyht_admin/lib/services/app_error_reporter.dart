import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_config.dart';
import '../student_portal/services/token_storage.dart' as student_storage;
import 'token_storage.dart';

class AppErrorReporter {
  AppErrorReporter._();

  static final instance = AppErrorReporter._();
  static String currentPage = 'App';
  static bool _reporting = false;

  Future<void> init() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(report(
        details.exceptionAsString(),
        stackTrace: details.stack?.toString(),
        severity: 'error',
      ));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(
        error.toString(),
        stackTrace: stack.toString(),
        severity: 'crash',
      ));
      return false;
    };
  }

  Future<void> report(
    String message, {
    String? stackTrace,
    String severity = 'error',
    Map<String, dynamic>? metadata,
  }) async {
    if (_reporting) return;
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;
    final token = await _token();
    if (token == null) return;

    _reporting = true;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final device = await _deviceDetails();
      final body = {
        'severity': severity == 'crash' ? 'crash' : 'error',
        'source': 'flutter',
        'page': currentPage,
        'message': _clip(cleanMessage, 4000),
        if (stackTrace != null && stackTrace.trim().isNotEmpty)
          'stackTrace': _clip(stackTrace, 12000),
        'devicePlatform': device.platform,
        'deviceModel': device.model,
        'appVersion': packageInfo.version,
        'appBuild': packageInfo.buildNumber,
        'metadata': {
          'releaseMode': kReleaseMode,
          ...?metadata,
        },
      };
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/app-errors'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Error reporting must never interrupt the user flow.
    } finally {
      _reporting = false;
    }
  }

  Future<String?> _token() async {
    final adminToken = await TokenStorage().readToken();
    if (adminToken != null) return adminToken;
    return student_storage.TokenStorage().readToken();
  }

  Future<_DeviceDetails> _deviceDetails() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return _DeviceDetails(
        platform: 'Android ${info.version.release}',
        model: '${info.manufacturer} ${info.model}',
      );
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return _DeviceDetails(
        platform: 'iOS ${info.systemVersion}',
        model: info.utsname.machine,
      );
    }
    return _DeviceDetails(platform: Platform.operatingSystem, model: null);
  }

  String _clip(String value, int max) {
    final text = value.trim();
    return text.length <= max ? text : text.substring(0, max);
  }
}

class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _update(previousRoute);
  }

  void _update(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      AppErrorReporter.currentPage = name;
      return;
    }
    AppErrorReporter.currentPage = route.runtimeType.toString();
  }
}

class _DeviceDetails {
  _DeviceDetails({required this.platform, required this.model});

  final String platform;
  final String? model;
}

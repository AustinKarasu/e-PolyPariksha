import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ExamSecurityService {
  static const _channel = MethodChannel('polyht/exam_security');

  void setEventHandler(Future<void> Function(String eventType) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'multiWindowModeChanged' && call.arguments == true) {
        await handler('split_screen_detected');
      }
    });
  }

  Future<void> enterExamMode() async {
    await WakelockPlus.enable();
    await _channel.invokeMethod('enterExamMode').catchError((_) {});
  }

  Future<void> exitExamMode() async {
    await WakelockPlus.disable();
    await _channel.invokeMethod('exitExamMode').catchError((_) {});
  }

  Future<bool> isInMultiWindowMode() async {
    final result = await _channel.invokeMethod<bool>('isInMultiWindowMode').catchError((_) => false);
    return result ?? false;
  }
}

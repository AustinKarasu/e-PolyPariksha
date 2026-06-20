import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ExamSecurityService {
  static const _channel = MethodChannel('polyht/exam_security');

  void setEventHandler(Future<void> Function(String eventType) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'multiWindowModeChanged' && call.arguments == true) {
        await handler('split_screen_attempt');
      }
      if (call.method == 'pictureInPictureModeChanged' &&
          call.arguments == true) {
        await handler('picture_in_picture_attempt');
      }
      if (call.method == 'windowFocusChanged' && call.arguments == false) {
        await handler('window_focus_lost');
      }
    });
  }

  Future<void> enterExamMode() async {
    await WakelockPlus.enable();
    await _channel.invokeMethod('enterExamMode').catchError((_) {});
  }

  Future<void> reassertExamMode() async {
    await WakelockPlus.enable();
    await _channel.invokeMethod('reassertExamMode').catchError((_) {});
  }

  Future<void> exitExamMode() async {
    await WakelockPlus.disable();
    await _channel.invokeMethod('exitExamMode').catchError((_) {});
  }

  Future<bool> isInMultiWindowMode() async {
    final result = await _channel
        .invokeMethod<bool>('isInMultiWindowMode')
        .catchError((_) => false);
    return result ?? false;
  }
}

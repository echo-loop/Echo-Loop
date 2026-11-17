import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effectiveTtsEngine 生效规则', () {
    test('始终使用所选引擎，本地模型未就绪也不回退平台', () {
      for (final kind in TtsEngineKind.values) {
        expect(effectiveTtsEngine(kind), kind, reason: '所选 $kind');
      }
    });
  });
}

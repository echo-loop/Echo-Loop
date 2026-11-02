/// audioEventParams 帮助函数与 Ref 扩展的单元测试
library;

import 'package:echo_loop/analytics/audio_event_params.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('audioEventParams (free function)', () {
    test('audioId 为 null 时返回空 map', () {
      expect(audioEventParams(audioId: null), isEmpty);
    });

    test('audioId 为空字符串时返回空 map', () {
      expect(audioEventParams(audioId: ''), isEmpty);
    });

    test('只有 audioId 时仅返回 audio_id', () {
      expect(audioEventParams(audioId: 'a1'), {EventParams.audioId: 'a1'});
    });

    test('audioName 为空字符串时不写入', () {
      expect(audioEventParams(audioId: 'a1', audioName: ''), {
        EventParams.audioId: 'a1',
      });
    });

    test('audioName 非空时同时返回 audio_id 和 audio_name', () {
      expect(audioEventParams(audioId: 'a1', audioName: 'Hello'), {
        EventParams.audioId: 'a1',
        EventParams.audioName: 'Hello',
      });
    });
  });

  group('Ref.audioEventParams 扩展', () {
    late ProviderContainer container;

    setUp(() {
      final items = [
        createTestAudioItem(id: 'a1', name: 'Lesson One'),
        createTestAudioItem(id: 'a2', name: 'Lesson Two'),
      ];
      container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: items)),
          ),
        ]),
      );
    });

    tearDown(() => container.dispose());

    test('从 audioLibraryProvider 解析名称', () {
      final result = _readWithRef(
        container,
        (ref) => ref.audioEventParams('a1'),
      );
      expect(result, {
        EventParams.audioId: 'a1',
        EventParams.audioName: 'Lesson One',
      });
    });

    test('未找到音频时仅返回 audio_id', () {
      final result = _readWithRef(
        container,
        (ref) => ref.audioEventParams('missing'),
      );
      expect(result, {EventParams.audioId: 'missing'});
    });

    test('audioId 为 null 时返回空 map', () {
      final result = _readWithRef(
        container,
        (ref) => ref.audioEventParams(null),
      );
      expect(result, isEmpty);
    });
  });
}

/// 借助一个临时 Provider 拿到 Ref 来测扩展方法。
Map<String, Object> _readWithRef(
  ProviderContainer container,
  Map<String, Object> Function(Ref ref) fn,
) {
  final probe = Provider<Map<String, Object>>((ref) => fn(ref));
  return container.read(probe);
}

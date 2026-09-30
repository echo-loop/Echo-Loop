import 'dart:io';

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
import 'package:echo_loop/providers/tts/piper_model_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/download/download_failure.dart';
import 'package:echo_loop/screens/tts_settings_screen.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus, KokoroModelVariant;
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 平台语音引擎的显示名随宿主而变（见 [platformSpeechEngineName]）：
/// Apple 宿主（macOS/iOS）显「Apple AI」，其余（Linux CI 等）显「System Speech」。
/// 测试断言须与运行宿主一致，否则在 Linux CI 上找不到「Apple AI」而失败。
final String _platformEngineLabel = (Platform.isIOS || Platform.isMacOS)
    ? 'Apple AI'
    : 'System Speech';

/// 受控的 Kokoro 模型 notifier：build 返回注入初值，方法仅按变体计数（不做真实 IO）。
class _TestKokoroNotifier extends KokoroModelNotifier {
  _TestKokoroNotifier(this._initial);
  final KokoroModelsState _initial;
  final List<KokoroModelVariant> ensured = [];
  final List<KokoroModelVariant> retried = [];
  final List<KokoroModelVariant> cancelled = [];
  final List<KokoroModelVariant> deleted = [];

  @override
  KokoroModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(KokoroModelVariant v) async => ensured.add(v);
  @override
  Future<void> retryDownload(KokoroModelVariant v) async => retried.add(v);
  @override
  Future<void> cancelDownload(KokoroModelVariant v) async => cancelled.add(v);
  @override
  Future<void> deleteModel(KokoroModelVariant v) async => deleted.add(v);
}

class _TestPiperNotifier extends PiperModelNotifier {
  _TestPiperNotifier(this._initial);
  final PiperModelsState _initial;

  @override
  PiperModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(String voiceId) async {}
}

/// 构造仅含指定变体状态的 KokoroModelsState。
KokoroModelsState _models({KokoroModelState? fp32, KokoroModelState? int8}) {
  return KokoroModelsState({
    if (fp32 != null) KokoroModelVariant.fp32: fp32,
    if (int8 != null) KokoroModelVariant.int8: int8,
  });
}

Widget _wrap(
  TtsSettings settings, {
  KokoroModelsState? models,
  _TestKokoroNotifier? notifier,
  PiperModelsState? piperModels,
}) {
  return ProviderScope(
    overrides: [
      initialTtsSettingsProvider.overrideWithValue(settings),
      kokoroModelProvider.overrideWith(
        () =>
            notifier ??
            _TestKokoroNotifier(models ?? const KokoroModelsState({})),
      ),
      piperModelProvider.overrideWith(
        () => _TestPiperNotifier(piperModels ?? const PiperModelsState({})),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: TtsSettingsScreen(),
    ),
  );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TtsSettingsScreen)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const readyState = KokoroModelState(
    downloadStatus: AsrModelDownloadStatus.downloaded,
    localSizeBytes: 1024,
  );

  testWidgets('默认渲染 Advanced 高质量模型配置', (tester) async {
    await tester.pumpWidget(_wrap(const TtsSettings()));
    await tester.pumpAndSettle();

    // 平台引擎显示名随宿主而变（Apple → Apple AI，其余 → System Speech）。
    expect(find.text(_platformEngineLabel), findsOneWidget);
    // Echo Loop 现拆为两档可选：Balanced(Piper) / Advanced(Kokoro)。
    expect(find.text('Echo Loop AI (Balanced)'), findsOneWidget);
    expect(find.text('Echo Loop AI (Advanced)'), findsNWidgets(2));
    expect(find.textContaining('Best sound quality'), findsOneWidget);
    expect(find.text('High quality'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
  });

  test('Android 不显示系统语音入口，其他平台保留', () {
    expect(showPlatformTtsEngine(true), isFalse);
    expect(showPlatformTtsEngine(false), isTrue);
  });

  testWidgets('Echo Loop → 显示两个模型变体（高质量带推荐徽标 / 轻量）', (tester) async {
    await tester.pumpWidget(
      _wrap(const TtsSettings(engine: TtsEngineKind.kokoro)),
    );
    await tester.pumpAndSettle();

    expect(find.text('High quality'), findsOneWidget);
    expect(find.text('Lightweight'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    // 两个变体的单选控件。
    expect(find.byType(Radio<KokoroModelVariant>), findsNWidgets(2));
  });

  testWidgets('点轻量变体 → setKokoroVariant(int8) + ensureDownloaded(int8)', (
    tester,
  ) async {
    final notifier = _TestKokoroNotifier(const KokoroModelsState({}));
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lightweight'));
    await tester.pumpAndSettle();

    expect(
      _containerOf(tester).read(ttsSettingsProvider).kokoroVariant,
      KokoroModelVariant.int8,
    );
    expect(notifier.ensured, contains(KokoroModelVariant.int8));
  });

  testWidgets('当前模型下载中 → 进度条但不显示取消按钮', (tester) async {
    final notifier = _TestKokoroNotifier(
      _models(
        fp32: const KokoroModelState(
          downloadStatus: AsrModelDownloadStatus.downloading,
          downloadProgress: 0.42,
        ),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('非当前模型下载中 → 显示取消按钮，点取消触发 cancelDownload', (tester) async {
    final notifier = _TestKokoroNotifier(
      _models(
        int8: const KokoroModelState(
          downloadStatus: AsrModelDownloadStatus.downloading,
          downloadProgress: 0.42,
        ),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notifier.cancelled, [KokoroModelVariant.int8]);
  });

  testWidgets('失败 → 错误 + 重试按钮，点重试触发 retryDownload', (tester) async {
    final notifier = _TestKokoroNotifier(
      _models(
        fp32: const KokoroModelState(
          downloadStatus: AsrModelDownloadStatus.failed,
          downloadError: DownloadFailureKind.network,
        ),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Network error. Check your connection and retry.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(notifier.retried, [KokoroModelVariant.fp32]);
  });

  testWidgets('当前 Piper 音色下载中 → 保留进度但不显示取消或下载按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.piper),
        piperModels: const PiperModelsState({
          'en_US-amy-medium': PiperModelState(
            downloadStatus: AsrModelDownloadStatus.downloading,
            downloadProgress: 0.42,
          ),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsNWidgets(8));
  });

  testWidgets('存储空间不足 → 显清晰的空间不足文案（非原始异常）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        models: _models(
          fp32: const KokoroModelState(
            downloadStatus: AsrModelDownloadStatus.failed,
            downloadError: DownloadFailureKind.insufficientStorage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Not enough storage. Free up space and retry.'),
      findsOneWidget,
    );
  });

  testWidgets('就绪（fp32 选中）→ 音色行 + 点开弹层显全部 3 个英文音色（分组）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ready'), findsOneWidget);
    // 音色收成单行 disclosure：标题 + 口音 + 当前音色（默认 American · Sol · Female）。
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('American · Sol · Female'), findsOneWidget);
    // 使用中（fp32 选中）不显删除（不删正在用的语音）；int8 未下载也无删除。
    expect(find.byTooltip('Delete model'), findsNothing);
    // Echo Loop 下无独立口音卡，弹层未开时音色列表与口音标题都不在屏上。
    expect(find.byType(Radio<String>), findsNothing);
    expect(find.text('American'), findsNothing);
    expect(find.text('British'), findsNothing);

    // 点开音色弹层 → v1.1 英文 3 个（美音 2 + 英音 1），按口音分组。
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    expect(find.byType(Radio<String>), findsNWidgets(3));
    expect(find.text('American'), findsOneWidget);
    expect(find.text('British'), findsOneWidget);
    expect(find.text('Maple'), findsOneWidget);
    expect(find.text('Sol'), findsOneWidget);
    expect(find.text('Vale'), findsOneWidget);
  });

  testWidgets('就绪 + 非使用中的已下载变体可删除', (tester) async {
    // fp32 使用中（不可删），int8 已下载但非使用中（可删）。
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        models: _models(fp32: readyState, int8: readyState),
      ),
    );
    await tester.pumpAndSettle();

    // 仅 int8 行显示删除图标。
    expect(find.byTooltip('Delete model'), findsOneWidget);
  });

  testWidgets('就绪 + 弹层选英音音色 → 口音设为英音 + 写入英音音色', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    // 默认美音。点开音色弹层选英音 Vale → 口音随之切英音，音色写入英音槽。
    expect(_containerOf(tester).read(ttsSettingsProvider).accent, TtsAccent.us);
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vale'));
    await tester.pumpAndSettle();

    final settings = _containerOf(tester).read(ttsSettingsProvider);
    expect(settings.accent, TtsAccent.uk);
    expect(settings.kokoroVoiceUk, 'bf_vale');
  });

  testWidgets('就绪 + 弹层点音色 → setKokoroVoice 更新', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    // 点开音色弹层后选美音 Maple → 音色写入美音槽，口音保持美音。
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maple'));
    await tester.pumpAndSettle();
    final settings = _containerOf(tester).read(ttsSettingsProvider);
    expect(settings.kokoroVoiceUs, 'af_maple');
    expect(settings.accent, TtsAccent.us);
  });

  testWidgets('平台引擎 + 无模型 → 不显示模型区与音色', (tester) async {
    await tester.pumpWidget(_wrap(const TtsSettings()));
    await tester.pumpAndSettle();

    expect(find.text('Model'), findsNothing);
    expect(find.text('Voice'), findsNothing);
    expect(find.byTooltip('Delete model'), findsNothing);
  });

  testWidgets('平台引擎不显示口音行，保留默认口音设置', (tester) async {
    await tester.pumpWidget(_wrap(const TtsSettings())); // 默认美音
    await tester.pumpAndSettle();

    expect(_containerOf(tester).read(ttsSettingsProvider).accent, TtsAccent.us);
    expect(find.text('British'), findsNothing);
  });
}

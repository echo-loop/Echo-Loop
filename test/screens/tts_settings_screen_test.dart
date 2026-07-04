import 'dart:io';

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
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
}) {
  return ProviderScope(
    overrides: [
      initialTtsSettingsProvider.overrideWithValue(settings),
      kokoroModelProvider.overrideWith(
        () =>
            notifier ??
            _TestKokoroNotifier(models ?? const KokoroModelsState({})),
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

  testWidgets('渲染引擎与口音两组单选，Echo Loop 现为可选项', (tester) async {
    await tester.pumpWidget(_wrap(const TtsSettings()));
    await tester.pumpAndSettle();

    // 平台引擎显示名随宿主而变（Apple → Apple AI，其余 → System Speech）。
    expect(find.text(_platformEngineLabel), findsOneWidget);
    // Echo Loop 现拆为两档可选：Balanced(Piper) / Advanced(Kokoro)。
    expect(find.text('Echo Loop AI (Balanced)'), findsOneWidget);
    expect(find.text('Echo Loop AI (Advanced)'), findsOneWidget);
    expect(find.textContaining('Best sound quality'), findsOneWidget);
    expect(find.text('American'), findsOneWidget);
    expect(find.text('British'), findsOneWidget);
  });

  testWidgets('选 Echo Loop → engine 更新为 echoLoop 且触发 ensureDownloaded', (
    tester,
  ) async {
    final notifier = _TestKokoroNotifier(const KokoroModelsState({}));
    await tester.pumpWidget(_wrap(const TtsSettings(), notifier: notifier));
    await tester.pumpAndSettle();

    // echoLoop = Advanced 档（Kokoro）。
    await tester.tap(find.text('Echo Loop AI (Advanced)'));
    await tester.pumpAndSettle();

    expect(
      _containerOf(tester).read(ttsSettingsProvider).engine,
      TtsEngineKind.echoLoop,
    );
    expect(notifier.ensured, contains(KokoroModelVariant.fp32));
  });

  testWidgets('Echo Loop → 显示两个模型变体（高质量带推荐徽标 / 轻量）', (tester) async {
    await tester.pumpWidget(
      _wrap(const TtsSettings(engine: TtsEngineKind.echoLoop)),
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
        const TtsSettings(engine: TtsEngineKind.echoLoop),
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

  testWidgets('下载中 → 进度条 + 取消按钮，点取消触发 cancelDownload', (tester) async {
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
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notifier.cancelled, [KokoroModelVariant.fp32]);
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
        const TtsSettings(engine: TtsEngineKind.echoLoop),
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

  testWidgets('存储空间不足 → 显清晰的空间不足文案（非原始异常）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
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

  testWidgets('就绪（fp32 选中）→ 音色行 + 点开弹层显全部 11 个（分组），使用中变体不显删除', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ready'), findsOneWidget);
    // 音色收成单行 disclosure：标题 + 口音 + 当前音色（默认 American · Sarah · Female）。
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('American · Sarah · Female'), findsOneWidget);
    // 使用中（fp32 选中）不显删除（不删正在用的语音）；int8 未下载也无删除。
    expect(find.byTooltip('Delete model'), findsNothing);
    // Echo Loop 下无独立口音卡，弹层未开时音色列表与口音标题都不在屏上。
    expect(find.byType(Radio<String>), findsNothing);
    expect(find.text('American'), findsNothing);
    expect(find.text('British'), findsNothing);

    // 点开音色弹层 → 全部 11 个（美音 7 + 英音 4），按口音分组。
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    expect(find.byType(Radio<String>), findsNWidgets(11));
    expect(find.text('American'), findsOneWidget);
    expect(find.text('British'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(find.text('Adam'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('George'), findsOneWidget);
  });

  testWidgets('就绪 + 非使用中的已下载变体可删除', (tester) async {
    // fp32 使用中（不可删），int8 已下载但非使用中（可删）。
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
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
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    // 默认美音。点开音色弹层选英音 Emma → 口音随之切英音，音色写入英音槽。
    expect(_containerOf(tester).read(ttsSettingsProvider).accent, TtsAccent.us);
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emma'));
    await tester.pumpAndSettle();

    final settings = _containerOf(tester).read(ttsSettingsProvider);
    expect(settings.accent, TtsAccent.uk);
    expect(settings.kokoroVoiceUk, 'bf_emma');
  });

  testWidgets('就绪 + 弹层点音色 → setKokoroVoice 更新', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    // 点开音色弹层后选美音 Adam → 音色写入美音槽，口音保持美音。
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adam'));
    await tester.pumpAndSettle();
    final settings = _containerOf(tester).read(ttsSettingsProvider);
    expect(settings.kokoroVoiceUs, 'am_adam');
    expect(settings.accent, TtsAccent.us);
  });

  testWidgets('平台引擎 + 无模型 → 不显示模型区与音色', (tester) async {
    await tester.pumpWidget(_wrap(const TtsSettings()));
    await tester.pumpAndSettle();

    expect(find.text('Model'), findsNothing);
    expect(find.text('Voice'), findsNothing);
    expect(find.byTooltip('Delete model'), findsNothing);
  });

  testWidgets('平台引擎 + 点击口音行 → setAccent 更新', (tester) async {
    await tester.pumpWidget(_wrap(const TtsSettings())); // 默认美音
    await tester.pumpAndSettle();

    expect(_containerOf(tester).read(ttsSettingsProvider).accent, TtsAccent.us);
    // 点英音行 → 口音切英音（试听异常在控制器内捕获，不影响设置写入）。
    await tester.tap(find.text('British'));
    await tester.pumpAndSettle();
    expect(_containerOf(tester).read(ttsSettingsProvider).accent, TtsAccent.uk);
  });

  testWidgets('平台引擎 + 模型已下载 → 显示删除入口（回收空间），不显示音色', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(), // 平台 TTS
        models: _models(fp32: readyState),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete model'), findsOneWidget);
    expect(find.text('Voice'), findsNothing);
  });

  testWidgets('切回平台 TTS → 不弹窗（由删除入口回收）', (tester) async {
    final notifier = _TestKokoroNotifier(_models(fp32: readyState));
    await tester.pumpWidget(
      _wrap(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_platformEngineLabel));
    await tester.pumpAndSettle();

    expect(
      _containerOf(tester).read(ttsSettingsProvider).engine,
      TtsEngineKind.platform,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byTooltip('Delete model'), findsOneWidget);
    expect(notifier.deleted, isEmpty);
  });

  testWidgets('平台引擎删除入口 → 点删除确认调用 deleteModel(fp32)', (tester) async {
    final notifier = _TestKokoroNotifier(_models(fp32: readyState));
    await tester.pumpWidget(
      _wrap(const TtsSettings(), notifier: notifier), // 平台 TTS
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete model'));
    await tester.pumpAndSettle();
    // 确认弹窗内删除。
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete model'),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifier.deleted, [KokoroModelVariant.fp32]);
  });
}

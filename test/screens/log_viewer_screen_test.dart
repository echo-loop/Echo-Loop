import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:echo_loop/screens/log_viewer_screen.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/device_diagnostics_service.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus/share_plus.dart';

const _shareButtonKey = ValueKey('log_viewer_share_button');

/// 轮询等待分享压缩等真实 I/O 完成，替代固定 sleep，避免慢机器上偶发失败。
Future<void> _waitUntilShared(bool Function() isShared) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!isShared()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('等待日志分享完成超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

class _LogDuringBuild extends StatefulWidget {
  const _LogDuringBuild();

  @override
  State<_LogDuringBuild> createState() => _LogDuringBuildState();
}

class _LogDuringBuildState extends State<_LogDuringBuild> {
  @override
  void initState() {
    super.initState();
    AppLogger.log('Build', 'during sibling build');
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceInfoChannel = DeviceDiagnosticsService.channel;

  late Directory tempDir;
  late List<String> sharedPaths;
  late List<String?> sharedSubjects;
  late List<Rect?> sharedOrigins;
  late List<String?> sharedMimeTypes;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('log_viewer_test_');
    sharedPaths = <String>[];
    sharedSubjects = <String?>[];
    sharedOrigins = <Rect?>[];
    sharedMimeTypes = <String?>[];
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    appDataDirectoryOverride = tempDir;
    AppLogger.instance.clear();
    PackageInfo.setMockInitialValues(
      appName: 'Echo Loop',
      packageName: 'app.echoloop',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, (call) async {
          return <String, Object?>{
            'manufacturer': 'Apple',
            'model': 'iPhone16,2',
            'systemVersion': '18.5',
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, null);
    AppLogger.instance.clear();
    appDataDirectoryOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<ShareResult> captureShare(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    sharedSubjects.add(subject);
    sharedOrigins.add(sharePositionOrigin);
    sharedMimeTypes.add(files.single.mimeType);
    sharedPaths.add(files.single.path);
    return const ShareResult('success', ShareResultStatus.success);
  }

  testWidgets('进入页面追加设备信息日志并显示分享按钮', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LogViewerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    expect(find.byKey(_shareButtonKey), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNothing);
    expect(
      AppLogger.instance.entries.any(
        (entry) =>
            entry.tag == 'DeviceInfo' &&
            entry.message.contains('model=iPhone16,2'),
      ),
      isTrue,
    );
  });

  testWidgets('实时日志只显示最近 500 条', (tester) async {
    for (var index = 0; index < AppLogger.maxRetainedEntries + 20; index++) {
      AppLogger.log('Live', 'line-$index');
    }
    await tester.pumpWidget(const MaterialApp(home: LogViewerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('日志（最近 500 条）'), findsOneWidget);
    expect(find.textContaining('line-0', findRichText: true), findsNothing);
    final latestEntry = find.textContaining('line-519', findRichText: true);
    await tester.scrollUntilVisible(
      latestEntry,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(latestEntry, findsOneWidget);
    expect(find.text('仅显示最近 500 条；分享日志可导出完整记录'), findsOneWidget);
  });

  testWidgets('实时追加日志后展示数量仍限制为 500 条', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LogViewerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    for (var index = 0; index < AppLogger.maxRetainedEntries + 20; index++) {
      AppLogger.log('Live', 'line-$index');
    }
    await tester.pump();
    await tester.pump();

    expect(find.text('日志（最近 500 条）'), findsOneWidget);
  });

  testWidgets('其他路由构建期间追加日志不会同步刷新本页', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(child: LogViewerScreen()),
            _LogDuringBuild(),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('during sibling build'), findsOneWidget);
  });

  testWidgets('点击分享导出包含设备信息和日志内容的 ZIP 支持包', (tester) async {
    AppLogger.log('Manual', 'before share');
    final logDirectory = Directory('${tempDir.path}/logs')
      ..createSync(recursive: true);
    File(
      '${logDirectory.path}/asr-crash-20260828-150945-498.log',
    ).writeAsStringSync('suspected ASR crash');
    File(
      '${logDirectory.path}/asr_inference-20260828-150946-000.pending',
    ).writeAsStringSync('active inference');
    await tester.pumpWidget(
      MaterialApp(home: LogViewerScreen(shareLauncher: captureShare)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final shareButton = tester.widget<IconButton>(find.byKey(_shareButtonKey));
    expect(shareButton.onPressed, isNotNull);

    await tester.runAsync(() async {
      shareButton.onPressed!();
      await _waitUntilShared(() => sharedPaths.isNotEmpty);
    });
    await tester.pump();

    expect(sharedPaths, hasLength(1));
    expect(sharedSubjects.single, 'Echo Loop Logs');
    expect(sharedOrigins.single, isNotNull);
    expect(sharedMimeTypes.single, 'application/zip');
    expect(sharedPaths.single, endsWith('.zip'));
    expect(sharedPaths.single, contains('log_export_'));

    final archive = ZipDecoder().decodeBytes(
      File(sharedPaths.single).readAsBytesSync(),
    );
    final log = archive.findFile('logs/app.log');
    if (log != null) {
      final text = utf8.decode(log.content);
      expect(text, contains('[Manual] before share'));
      expect(text, contains('[DeviceInfo]'));
      expect(text, contains('model=iPhone16,2'));
    }
    expect(
      archive.findFile('logs/asr-crash-20260828-150945-498.log'),
      isNotNull,
    );
    expect(
      archive.findFile('logs/asr_inference-20260828-150946-000.pending'),
      isNull,
    );
  });

  testWidgets('分享前等待设备信息写入完成', (tester) async {
    final completer = Completer<Map<String, Object?>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          deviceInfoChannel,
          (call) => completer.future,
        );
    AppLogger.log('Manual', 'fast tap');

    await tester.pumpWidget(
      MaterialApp(home: LogViewerScreen(shareLauncher: captureShare)),
    );
    await tester.pump();
    final shareButton = tester.widget<IconButton>(find.byKey(_shareButtonKey));
    expect(shareButton.onPressed, isNotNull);
    await tester.runAsync(() async {
      shareButton.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(sharedPaths, isEmpty);

    completer.complete(<String, Object?>{'model': 'DelayedPhone'});
    await tester.runAsync(() => _waitUntilShared(() => sharedPaths.isNotEmpty));
    await tester.pump();

    expect(sharedPaths, hasLength(1));
    final archive = ZipDecoder().decodeBytes(
      File(sharedPaths.single).readAsBytesSync(),
    );
    final log = archive.findFile('logs/app.log');
    if (log == null) fail('支持包缺少 logs/app.log');
    expect(utf8.decode(log.content), contains('DelayedPhone'));
  });
}

/// 开发者 ASR 引擎测试页面。
///
/// 支持选择 Platform ASR（Apple Speech）或本地离线模型（Whisper），
/// 提供录音、转录、性能指标和事件日志功能。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import '../providers/asr_engine_provider.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import '../services/speech_practice_platform.dart';

// ---------------------------------------------------------------------------
// ASR 方式
// ---------------------------------------------------------------------------

/// ASR 测试方式。
enum _AsrMode {
  /// 平台内置（Apple SFSpeechRecognizer）。
  platform,

  /// 本地离线（sherpa-onnx）。
  offline,
}

// ---------------------------------------------------------------------------
// 事件日志条目
// ---------------------------------------------------------------------------

class _LogEntry {
  final Duration timestamp;
  final String message;
  const _LogEntry({required this.timestamp, required this.message});
}

// ---------------------------------------------------------------------------
// AsrTestScreen
// ---------------------------------------------------------------------------

/// 开发者 ASR 引擎测试页面。
class AsrTestScreen extends ConsumerStatefulWidget {
  const AsrTestScreen({super.key});

  @override
  ConsumerState<AsrTestScreen> createState() => _AsrTestScreenState();
}

class _AsrTestScreenState extends ConsumerState<AsrTestScreen> {
  // 引擎选择
  _AsrMode _mode = Platform.isAndroid ? _AsrMode.offline : _AsrMode.platform;
  String _selectedModelId = 'whisper-tiny-en-int8';

  // 录音状态
  bool _isRecording = false;
  bool _isTranscribing = false;
  final Stopwatch _recordingStopwatch = Stopwatch();

  // 结果
  String? _transcript;
  Duration? _recordingDuration;
  Duration? _inferenceTime;

  // 模型下载
  AsrModelDownloadProgress _downloadProgress =
      AsrModelDownloadProgress.notDownloaded;
  CancelToken? _downloadCancelToken;

  // 事件日志
  final List<_LogEntry> _logs = [];
  final Stopwatch _sessionStopwatch = Stopwatch();

  // 平台事件订阅
  StreamSubscription<SpeechPracticeEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _checkGmsAndModelStatus();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _downloadCancelToken?.cancel();
    super.dispose();
  }

  /// 获取离线 ASR 引擎。
  OfflineAsrEngine _getEngine() => ref.read(offlineAsrEngineProvider);

  Future<void> _checkGmsAndModelStatus() async {
    // 检查当前模型是否已下载。
    await _refreshModelStatus();
    if (mounted) setState(() {});
  }

  Future<void> _refreshModelStatus() async {
    final manager = ref.read(asrModelManagerProvider);
    final downloaded = await manager.isModelDownloaded(_selectedModelId);
    setState(() {
      _downloadProgress = downloaded
          ? const AsrModelDownloadProgress(
              status: AsrModelDownloadStatus.downloaded,
              progress: 1,
            )
          : AsrModelDownloadProgress.notDownloaded;
    });
  }

  // ---------------------------------------------------------------------------
  // 模型下载
  // ---------------------------------------------------------------------------

  Future<void> _downloadModel() async {
    final manager = ref.read(asrModelManagerProvider);
    _downloadCancelToken = CancelToken();

    setState(() {
      _downloadProgress = const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloading,
      );
    });

    try {
      await manager.downloadModel(
        _selectedModelId,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
        cancelToken: _downloadCancelToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress = AsrModelDownloadProgress(
            status: AsrModelDownloadStatus.failed,
            error: e.toString(),
          );
        });
      }
    }
  }

  Future<void> _deleteModel() async {
    final manager = ref.read(asrModelManagerProvider);
    await manager.deleteModel(_selectedModelId);

    // 引擎如果正在用这个模型，也要释放。
    final engine = _getEngine();
    if (engine.currentModel?.id == _selectedModelId) {
      await engine.dispose();
    }

    await _refreshModelStatus();
  }

  // ---------------------------------------------------------------------------
  // 录音测试
  // ---------------------------------------------------------------------------

  void _addLog(String message) {
    _logs.add(
      _LogEntry(timestamp: _sessionStopwatch.elapsed, message: message),
    );
  }

  Future<void> _startRecording() async {
    // 确保录音权限已授予。
    final platform = SpeechPracticePlatform.instance;
    final permissions = await platform.getPermissionStatus();
    if (!permissions.isGranted) {
      final result = await platform.requestPermissions();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('需要录音权限')));
        }
        return;
      }
    }

    setState(() {
      _isRecording = true;
      _transcript = null;
      _recordingDuration = null;
      _inferenceTime = null;
      _logs.clear();
    });

    _sessionStopwatch
      ..reset()
      ..start();
    _recordingStopwatch
      ..reset()
      ..start();

    if (_mode == _AsrMode.platform) {
      await _startPlatformRecording();
    } else {
      await _startOfflineRecording();
    }
  }

  Future<void> _stopRecording() async {
    _recordingStopwatch.stop();
    final recDuration = _recordingStopwatch.elapsed;

    setState(() {
      _isRecording = false;
      _recordingDuration = recDuration;
    });

    _addLog('stopSession (录音 ${_formatDuration(recDuration)})');

    if (_mode == _AsrMode.platform) {
      await _stopPlatformRecording();
    } else {
      await _stopOfflineRecording();
    }
  }

  // --- Platform 路径 ---

  Future<void> _startPlatformRecording() async {
    final platform = SpeechPracticePlatform.instance;

    _eventSubscription?.cancel();
    _eventSubscription = platform.events.listen(_handlePlatformEvent);

    try {
      await platform.setRecognitionEnabled(true);
      _addLog('warmup');
      await platform.warmup();
      _addLog('warmup done');

      _addLog('startSession');
      await platform.startSession(promptId: 'asr-test');
      _addLog('recording...');
    } catch (e) {
      _addLog('error: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopPlatformRecording() async {
    try {
      final result = await SpeechPracticePlatform.instance.stopSession();
      _addLog('stopSession done, file: ${result.filePath}');
    } catch (e) {
      _addLog('stopSession error: $e');
    }
  }

  void _handlePlatformEvent(SpeechPracticeEvent event) {
    switch (event.type) {
      case SpeechPracticeEventType.speechStarted:
        _addLog('speechStarted');
      case SpeechPracticeEventType.partialTranscriptUpdated:
        _addLog('partial: ${event.transcript}');
      case SpeechPracticeEventType.silenceProgress:
        // 静音进度不记录（太频繁）。
        break;
      case SpeechPracticeEventType.finalTranscriptReady:
        _addLog('transcript ready');
        _sessionStopwatch.stop();
        setState(() {
          _transcript = event.transcript;
          _inferenceTime = null; // Platform 模式无独立推理耗时。
        });
      case SpeechPracticeEventType.error:
        _addLog('error: ${event.errorCode} ${event.errorMessage}');
    }
    if (mounted) setState(() {});
  }

  // --- Offline 路径 ---

  Future<void> _startOfflineRecording() async {
    final platform = SpeechPracticePlatform.instance;

    try {
      await platform.setRecognitionEnabled(false);
      _addLog('warmup');
      await platform.warmup();
      _addLog('warmup done');

      // 确保引擎已初始化。
      final engine = _getEngine();
      if (!engine.isReady) {
        _addLog('initializing engine...');
        final manager = ref.read(asrModelManagerProvider);
        final modelDir = await manager.modelDir(_selectedModelId);
        final modelInfo = availableModels.firstWhere(
          (m) => m.id == _selectedModelId,
        );
        await engine.initialize(
          AsrModelConfig(
            model: modelInfo,
            modelDir: modelDir,
            numThreads: AsrModelConfig.recommendedThreads(),
          ),
        );
        _addLog('engine ready');
      }

      _addLog('startSession');
      await platform.startSession(promptId: 'asr-test');
      _addLog('recording...');

      // 监听 VAD 事件（speechStarted）。
      _eventSubscription?.cancel();
      _eventSubscription = platform.events.listen((event) {
        if (event.type == SpeechPracticeEventType.speechStarted) {
          _addLog('speechStarted');
        }
        if (mounted) setState(() {});
      });
    } catch (e) {
      _addLog('error: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopOfflineRecording() async {
    try {
      final result = await SpeechPracticePlatform.instance.stopSession();
      final filePath = result.filePath;

      if (filePath == null || filePath.isEmpty) {
        _addLog('no recording file');
        return;
      }

      _addLog('transcribing ($filePath)...');
      setState(() => _isTranscribing = true);

      final engine = _getEngine();
      final asrResult = await engine.transcribe(filePath);

      _addLog('transcript ready (${asrResult.inferenceTime.inMilliseconds}ms)');
      _sessionStopwatch.stop();

      setState(() {
        _isTranscribing = false;
        _transcript = asrResult.text;
        _inferenceTime = asrResult.inferenceTime;
      });
    } catch (e) {
      _addLog('transcribe error: $e');
      setState(() => _isTranscribing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ASR 引擎测试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEngineConfigSection(theme),
          const SizedBox(height: 24),
          _buildRecordingSection(theme),
          const SizedBox(height: 24),
          if (_transcript != null) ...[
            _buildResultSection(theme),
            const SizedBox(height: 24),
          ],
          if (_recordingDuration != null) ...[
            _buildMetricsSection(theme),
            const SizedBox(height: 24),
          ],
          if (_logs.isNotEmpty) _buildLogSection(theme),
        ],
      ),
    );
  }

  // --- 引擎配置区 ---

  Widget _buildEngineConfigSection(ThemeData theme) {
    final models = ref.watch(availableAsrModelsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('引擎配置', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // ASR 方式选择
            Row(
              children: [
                const SizedBox(width: 80, child: Text('ASR 方式')),
                Expanded(
                  child: SegmentedButton<_AsrMode>(
                    segments: [
                      if (!Platform.isAndroid)
                        const ButtonSegment(
                          value: _AsrMode.platform,
                          label: Text('Platform'),
                        ),
                      const ButtonSegment(
                        value: _AsrMode.offline,
                        label: Text('本地离线'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (set) {
                      setState(() => _mode = set.first);
                    },
                  ),
                ),
              ],
            ),

            // 离线模式的模型选择
            if (_mode == _AsrMode.offline) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 80, child: Text('模型')),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedModelId,
                      isExpanded: true,
                      items: models
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedModelId = value);

                        // 切换模型后刷新下载状态。
                        _refreshModelStatus();

                        // 如果引擎已加载其他模型，需要重新初始化。
                        final engine = _getEngine();
                        if (engine.currentModel?.id != value) {
                          engine.dispose();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildModelStatusRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatusRow() {
    final status = _downloadProgress.status;

    return Row(
      children: [
        const SizedBox(width: 80, child: Text('模型状态')),
        Expanded(
          child: switch (status) {
            AsrModelDownloadStatus.notDownloaded => Row(
              children: [
                const Text('未下载'),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _downloadModel,
                  child: const Text('下载'),
                ),
              ],
            ),
            AsrModelDownloadStatus.downloading => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _downloadProgress.progress),
                const SizedBox(height: 4),
                Text(
                  '${(_downloadProgress.progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            AsrModelDownloadStatus.downloaded => Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 4),
                const Text('已下载'),
                const SizedBox(width: 12),
                TextButton(onPressed: _deleteModel, child: const Text('删除')),
              ],
            ),
            AsrModelDownloadStatus.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下载失败: ${_downloadProgress.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 4),
                FilledButton.tonal(
                  onPressed: _downloadModel,
                  child: const Text('重试'),
                ),
              ],
            ),
          },
        ),
      ],
    );
  }

  // --- 录音区 ---

  Widget _buildRecordingSection(ThemeData theme) {
    final canRecord =
        _mode == _AsrMode.platform ||
        _downloadProgress.status == AsrModelDownloadStatus.downloaded;

    final String hint;
    if (_isTranscribing) {
      hint = '转录中...';
    } else if (_isRecording) {
      hint = '录音中... ${_formatDuration(_recordingStopwatch.elapsed)}';
    } else if (canRecord) {
      hint = '点击开始录音';
    } else {
      hint = '请先下载模型';
    }

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: FloatingActionButton.large(
            heroTag: 'asr-test-record',
            onPressed: canRecord
                ? (_isRecording ? _stopRecording : _startRecording)
                : null,
            backgroundColor: _isRecording ? Colors.red : null,
            child: _isTranscribing
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Icon(_isRecording ? Icons.stop : Icons.mic, size: 36),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  // --- 转录结果区 ---

  Widget _buildResultSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('转录结果', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(_transcript ?? '', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  // --- 性能指标区 ---

  Widget _buildMetricsSection(ThemeData theme) {
    final recSec = (_recordingDuration?.inMilliseconds ?? 0) / 1000;
    final infSec = (_inferenceTime?.inMilliseconds ?? 0) / 1000;
    final rtf = recSec > 0 ? infSec / recSec : 0.0;

    final selectedModel = availableModels.where(
      (m) => m.id == _selectedModelId,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('性能指标', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _metricRow('录音时长', _formatDuration(_recordingDuration)),
            if (_inferenceTime != null) ...[
              _metricRow('推理耗时', _formatDuration(_inferenceTime)),
              _metricRow('RTF', rtf.toStringAsFixed(3)),
            ],
            _metricRow(
              '引擎',
              _mode == _AsrMode.platform ? 'Platform (GMS)' : _getEngine().name,
            ),
            if (_mode == _AsrMode.offline && selectedModel.isNotEmpty)
              _metricRow('模型', selectedModel.first.displayName),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // --- 事件日志区 ---

  Widget _buildLogSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('事件日志', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                reverse: true,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[_logs.length - 1 - index];
                  return Text(
                    '${_formatDuration(log.timestamp)} ${log.message}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 格式化工具
  // ---------------------------------------------------------------------------

  static String _formatDuration(Duration? d) {
    if (d == null) return '-';
    final ms = d.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;

import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/learning_progress_provider.dart';
import '../../providers/listening_practice/listening_practice_provider.dart';
import '../../utils/app_data_dir.dart';
import '../../utils/srt_generator.dart';
import '../../utils/synthetic_word_timestamps.dart';
import 'subtitle_edit_engine.dart';

enum SubtitleEditorPlaybackMode { idle, sentence, range, word }

final subtitleEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<SubtitleEditorController, SubtitleEditorState, AudioItem>((
      ref,
      audioItem,
    ) {
      return SubtitleEditorController(ref: ref, audioItem: audioItem);
    });

@immutable
class SubtitleEditorState {
  final bool isLoading;
  final bool isSaving;
  final bool isDirty;
  final String? errorMessage;
  final AudioItem audioItem;
  final List<Sentence> sentences;
  final int? selectedSentenceIndex;
  final int? playingSentenceIndex;
  final bool isPlaying;
  final SubtitleEditorPlaybackMode playbackMode;
  final Duration playbackPosition;
  final Duration? totalDuration;
  final Waveform? waveform;
  final double waveformProgress;

  /// 波形提取是否失败（原生解码报错或长时间无进展）。
  ///
  /// 波形只是编辑辅助：失败时波形区显示失败态 + 重试，下方句子列表仍可正常编辑，
  /// 不阻断整个编辑流程。与「加载中（waveform == null 且未失败）」显式区分，
  /// 避免失败被误显示成永久「加载 0%」。
  final bool waveformFailed;
  final double playbackSpeed;
  final double waveformZoomScale;

  /// 用户「显式选中某句」的递增计数。
  ///
  /// 仅当用户主动点选句子（[selectSentence]）时自增，用来驱动波形把该句居中。
  /// 播放推进、播放结束、拖动边界等导致的选中句变化都不会改变它，从而避免
  /// 波形在播放停止后被错误地重新居中（跳变）。
  final int selectionEpoch;

  /// 当前音频的词级时间戳（全量）。
  ///
  /// AI 转录音频来自 DB `word_timestamps_json`；本地上传字幕没有真实词级数据时，
  /// 由 [generateSyntheticWordTimestamps] 按句内字符比例近似生成（编辑会话内存使用，
  /// 本任务不持久化）。词级编辑（拆成单词 label、点词播放、词边界显示）的数据源。
  final List<WordTimestamp> words;

  /// 当前点中词在「选中句词列表」内的序号；null 表示未点中任何词（纯文本态）。
  ///
  /// 用户点某句获焦后，点其中一个单词 label 时置位，用来播放该词并在波形上显示
  /// 该词及左右各两词的边界。切句 / 播放整句 / 结构变化时清空。
  final int? focusedWordIndex;

  const SubtitleEditorState({
    required this.audioItem,
    this.isLoading = true,
    this.isSaving = false,
    this.isDirty = false,
    this.errorMessage,
    this.sentences = const [],
    this.selectedSentenceIndex,
    this.playingSentenceIndex,
    this.isPlaying = false,
    this.playbackMode = SubtitleEditorPlaybackMode.idle,
    this.playbackPosition = Duration.zero,
    this.totalDuration,
    this.waveform,
    this.waveformProgress = 0,
    this.waveformFailed = false,
    this.playbackSpeed = 1.0,
    this.waveformZoomScale = 1.0,
    this.maxWaveformZoomScale = 1.0,
    this.selectionEpoch = 0,
    this.words = const [],
    this.focusedWordIndex,
  });

  Sentence? get selectedSentence {
    final index = selectedSentenceIndex;
    if (index == null || index < 0 || index >= sentences.length) return null;
    return sentences[index];
  }

  /// 波形最大放大倍数。
  ///
  /// `1.0` 表示不缩放（整段音频铺满屏宽）；进入编辑页拿到波形可用宽度后，
  /// [SubtitleEditorController.initZoomForViewport] 会按「最大放大时 1 秒音频约占
  /// 2cm 屏幕长度」计算上限。音频越长，上限越大。
  final double maxWaveformZoomScale;

  SubtitleEditorState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isDirty,
    Object? errorMessage = _sentinel,
    AudioItem? audioItem,
    List<Sentence>? sentences,
    Object? selectedSentenceIndex = _sentinel,
    Object? playingSentenceIndex = _sentinel,
    bool? isPlaying,
    SubtitleEditorPlaybackMode? playbackMode,
    Duration? playbackPosition,
    Object? totalDuration = _sentinel,
    Waveform? waveform,
    double? waveformProgress,
    bool? waveformFailed,
    double? playbackSpeed,
    double? waveformZoomScale,
    double? maxWaveformZoomScale,
    int? selectionEpoch,
    List<WordTimestamp>? words,
    Object? focusedWordIndex = _sentinel,
  }) {
    return SubtitleEditorState(
      audioItem: audioItem ?? this.audioItem,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      sentences: sentences ?? this.sentences,
      selectedSentenceIndex: selectedSentenceIndex == _sentinel
          ? this.selectedSentenceIndex
          : selectedSentenceIndex as int?,
      playingSentenceIndex: playingSentenceIndex == _sentinel
          ? this.playingSentenceIndex
          : playingSentenceIndex as int?,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackMode: playbackMode ?? this.playbackMode,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      totalDuration: totalDuration == _sentinel
          ? this.totalDuration
          : totalDuration as Duration?,
      waveform: waveform ?? this.waveform,
      waveformProgress: waveformProgress ?? this.waveformProgress,
      waveformFailed: waveformFailed ?? this.waveformFailed,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      waveformZoomScale: waveformZoomScale ?? this.waveformZoomScale,
      maxWaveformZoomScale: maxWaveformZoomScale ?? this.maxWaveformZoomScale,
      selectionEpoch: selectionEpoch ?? this.selectionEpoch,
      words: words ?? this.words,
      focusedWordIndex: focusedWordIndex == _sentinel
          ? this.focusedWordIndex
          : focusedWordIndex as int?,
    );
  }
}

const _sentinel = Object();

class SubtitleEditorController extends StateNotifier<SubtitleEditorState> {
  SubtitleEditorController({required Ref ref, required AudioItem audioItem})
    : _ref = ref,
      _audioEngine = ref.read(audioEngineProvider.notifier),
      _engine = const SubtitleEditEngine(),
      super(SubtitleEditorState(audioItem: audioItem)) {
    _positionSub = _audioEngine.absolutePositionStream.listen(_handlePosition);
  }

  final Ref _ref;
  final AudioEngine _audioEngine;
  final SubtitleEditEngine _engine;
  StreamSubscription<Duration>? _positionSub;
  Timer? _playheadTimer;
  int? _activePlaybackSessionId;
  Duration _playbackStart = Duration.zero;
  Duration _playbackEnd = Duration.zero;
  Duration _playheadAnchor = Duration.zero;
  DateTime? _playheadAnchorAt;
  bool _hasLoaded = false;
  bool _didInitZoom = false;
  String _baselineSubtitleHash = '';

  /// 词级时间是否被拖动编辑过（句子 SRT 不变、仅词边界变时也要能保存）。
  bool _wordsDirty = false;

  /// 进入编辑页时的原始句子数量。
  ///
  /// 句子数量只会因合并/删除而减少（调整边界仅改时间戳）。保存时若数量未变，
  /// 说明仅调整了时间戳、句子与索引的对应关系不变，无需清空按句索引的学习进度
  /// 和收藏句子。
  int? _baselineSentenceCount;

  /// 相对进入编辑页时句子数量是否发生变化（合并/删除）。
  ///
  /// 仅调整边界时间戳不会改变数量。数量变化才会打乱按句索引的学习进度与收藏，
  /// 保存时需清空；据此 UI 也只在数量变化时提示「将清空进度」。
  bool get sentenceCountChanged =>
      _baselineSentenceCount != null &&
      state.sentences.length != _baselineSentenceCount;

  /// 当前保存是否会清理已有学习数据。
  ///
  /// 句子数量变化会打乱基于句子索引保存的学习进度与收藏句子；但如果该音频本身
  /// 没有任何进度或收藏，则无需在保存前打断用户确认。
  Future<bool> hasResettableLearningData() async {
    if (!sentenceCountChanged) return false;
    final audioItemId = state.audioItem.id;
    final bookmarks = await _ref
        .read(bookmarkDaoProvider)
        .getBookmarkedIndices(audioItemId);
    if (bookmarks.isNotEmpty) return true;
    final progress = await _ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestByAudioId(audioItemId);
    return progress?.isStarted ?? false;
  }

  /// 每厘米屏幕对应的逻辑像素数（160 逻辑像素/英寸 ÷ 2.54 厘米/英寸）。
  static const double _logicalPixelsPerCm = 160 / 2.54;

  /// 最大放大时 1 秒音频在屏幕上占用的物理长度。
  static const double _maxZoomCentimetersPerSecond = 2.0;

  Future<void> load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    try {
      final duration = await _audioEngine.loadAudio(state.audioItem, 1.0);
      final sentences = await _audioEngine.loadTranscript(state.audioItem);
      _baselineSubtitleHash = _subtitleHash(sentences);
      _baselineSentenceCount = sentences.length;
      // 物化为按句子文本 token 对齐的可编辑词列表（词边界拖动直接改它）。
      final words = _buildWords(sentences, await _loadWords(sentences));
      state = state.copyWith(
        isLoading: false,
        totalDuration: duration,
        sentences: sentences,
        words: words,
        selectedSentenceIndex: sentences.isEmpty ? null : 0,
        playbackPosition: sentences.isEmpty
            ? Duration.zero
            : sentences.first.startTime,
      );
      unawaited(_loadWaveform());
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 加载当前音频的词级时间戳。
  ///
  /// 优先读 DB `word_timestamps_json`（AI 转录音频有真实词级数据）；为空或读取失败
  /// （本地上传字幕无词级数据）时按字幕句子近似生成，保证词级编辑入口对所有有字幕的
  /// 音频一致可用。本任务只在编辑会话内存使用，不写回 DB。
  Future<List<WordTimestamp>> _loadWords(List<Sentence> sentences) async {
    try {
      final json = await _ref
          .read(audioItemDaoProvider)
          .getWordTimestamps(state.audioItem.id);
      final decoded = json == null ? null : decodeWordTimestamps(json);
      if (decoded != null && decoded.isNotEmpty) return decoded;
    } catch (_) {
      // DB 不可用时退化为合成词级时间戳，不阻塞编辑器加载。
    }
    return generateSyntheticWordTimestamps(sentences);
  }

  /// 词边界拖动时的最小词长，避免把词拖成零长或负长。
  static const Duration kMinWordDuration = Duration(milliseconds: 20);

  /// 选中句拆成的单词列表（按文本顺序），每个词带可编辑的时间区间。
  ///
  /// 取自 [SubtitleEditorState.words]（加载时按句子文本 token 物化、可被拖动编辑）对应
  /// 本句的切片，并把时间钳到当前句区间、首词贴句首 / 末词贴句尾（句子边界可能被单独
  /// 拖过）。词来自**句子文本按空格切分**，绝不丢词（含句首单字母词如 "I"）。
  /// 无选中句时返回空。
  List<WordTimestamp> get wordsOfSelectedSentence {
    final index = state.selectedSentenceIndex;
    if (index == null || index < 0 || index >= state.sentences.length) {
      return const [];
    }
    return _sentenceWords(index);
  }

  /// 波形要绘制 / 可拖动的全部单词边界：选中句 + 前后相邻句的所有词。
  ///
  /// 句子的起止边界即首词起点 / 末词终点，统一为单词边界（见 [adjustWord]），不再
  /// 单列句子边界。当前句为主样式，相邻句为次样式。无选中句返回空。
  List<WaveformWordBoundary> get wordBoundariesForWaveform {
    final selected = state.selectedSentenceIndex;
    if (selected == null) return const [];
    final result = <WaveformWordBoundary>[];
    for (final i in [selected - 1, selected, selected + 1]) {
      if (i < 0 || i >= state.sentences.length) continue;
      final view = _sentenceWords(i);
      if (view.isEmpty) continue;
      final range = _sentenceTokenRange(i);
      final last = view.length - 1;
      for (var local = 0; local < view.length; local++) {
        result.add((
          globalIndex: range == null ? -1 : range.offset + local,
          word: view[local],
          primary: i == selected,
          isSentenceStart: local == 0,
          isSentenceEnd: local == last,
        ));
      }
    }
    return result;
  }

  /// 拖动第 [globalIndex] 个词的某一端边界到 [target]（波形拖动时实时调用）。
  ///
  /// 统一入口：所有边界都是单词边界。句首词的起点 / 句末词的终点即句子的起止边界，
  /// 拖动它们会**同步**更新对应句的起止时间，保持「句起 = 首词起、句止 = 末词止」
  /// 不变量。钳制依据一律取自 [_sentenceWords]（已钳到句区间、首尾贴句界的显示视图）
  /// 与相邻句边界（[_prevSentenceEnd] / [_nextSentenceStart]），相邻词 / 句子边界绝
  /// 不被穿越。
  void adjustWord(int globalIndex, BoundaryEdge edge, Duration target) {
    if (globalIndex < 0 || globalIndex >= state.words.length) return;
    final sentenceIndex = _sentenceIndexOfWord(globalIndex);
    if (sentenceIndex == null) return;
    final range = _sentenceTokenRange(sentenceIndex);
    if (range == null) return;
    final local = globalIndex - range.offset;
    final view = _sentenceWords(sentenceIndex);
    if (local < 0 || local >= view.length) return;
    final word = view[local];

    final bounds = _wordEdgeBounds(sentenceIndex, view, local, edge);
    final clamped = _clampDuration(target, bounds.lower, bounds.upper);
    final current = edge == BoundaryEdge.start ? word.startTime : word.endTime;
    if (clamped == current) return;

    // 写回原始词列表（采用句区间内显示值，避免原始词积累越界时间）。
    final words = List<WordTimestamp>.of(state.words);
    words[globalIndex] = edge == BoundaryEdge.start
        ? word.copyWith(startTime: clamped)
        : word.copyWith(endTime: clamped);

    // 句首词起点 / 句末词终点即句子边界：同步更新句子时间保持不变量。
    final isSentenceEdge =
        (edge == BoundaryEdge.start && local == 0) ||
        (edge == BoundaryEdge.end && local == view.length - 1);
    final nextSentences = isSentenceEdge
        ? _withSentenceEdge(sentenceIndex, edge, clamped)
        : state.sentences;
    // 纯内部词编辑不反映在句子 SRT 上，需单独标 dirty；句子边界编辑由 SRT hash 判定
    // （拖回原位可恢复未修改态）。
    if (!isSentenceEdge) _wordsDirty = true;

    final wasPlaying = state.isPlaying;
    if (wasPlaying) _cancelPlaybackSession();
    state = state.copyWith(
      words: words,
      sentences: nextSentences,
      isDirty: _sentencesChanged(nextSentences) || _wordsDirty,
      playingSentenceIndex: wasPlaying ? null : state.playingSentenceIndex,
      isPlaying: wasPlaying ? false : state.isPlaying,
      playbackMode: wasPlaying
          ? SubtitleEditorPlaybackMode.idle
          : state.playbackMode,
    );
  }

  /// 计算第 [local] 个词某端边界的允许范围 `[lower, upper]`。
  ///
  /// 句首词起点下限 = 前一句终点（无前句则 0）；句末词终点上限 = 后一句起点
  /// （无后句则音频总时长）。内部边界按相邻词 + [kMinWordDuration] 钳制。
  ({Duration lower, Duration upper}) _wordEdgeBounds(
    int sentenceIndex,
    List<WordTimestamp> view,
    int local,
    BoundaryEdge edge,
  ) {
    final word = view[local];
    if (edge == BoundaryEdge.start) {
      final lower = local > 0
          ? view[local - 1].endTime
          : _prevSentenceEnd(sentenceIndex);
      return (lower: lower, upper: word.endTime - kMinWordDuration);
    }
    final upper = local < view.length - 1
        ? view[local + 1].startTime
        : _nextSentenceStart(sentenceIndex);
    return (lower: word.startTime + kMinWordDuration, upper: upper);
  }

  /// 前一句终点（句首词起点的下限）；无前句返回 0。
  Duration _prevSentenceEnd(int sentenceIndex) {
    if (sentenceIndex <= 0) return Duration.zero;
    return state.sentences[sentenceIndex - 1].endTime;
  }

  /// 后一句起点（句末词终点的上限）；无后句返回音频总时长。
  Duration _nextSentenceStart(int sentenceIndex) {
    if (sentenceIndex < state.sentences.length - 1) {
      return state.sentences[sentenceIndex + 1].startTime;
    }
    return _effectiveTotalDuration() ??
        (state.sentences.isEmpty
            ? Duration.zero
            : state.sentences.last.endTime);
  }

  /// 返回把第 [index] 句某端时间改为 [clamped] 的新句子列表。
  List<Sentence> _withSentenceEdge(
    int index,
    BoundaryEdge edge,
    Duration clamped,
  ) {
    final next = [...state.sentences];
    final s = next[index];
    next[index] = edge == BoundaryEdge.start
        ? s.copyWith(startTime: clamped)
        : s.copyWith(endTime: clamped);
    return next;
  }

  Duration _clampDuration(Duration value, Duration lower, Duration upper) {
    if (upper < lower) return lower;
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
  }

  /// 按空格把句子文本切成单词（去掉空 token）。labels 与词区间都以此为准，绝不丢词。
  static List<String> _splitTokens(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed.split(RegExp(r'\s+'));
  }

  /// 第 [index] 句的 token 在全篇词列表中的 [offset, offset+count) 范围；
  /// 词列表与文本 token 数不同步（结构刚变、尚未重建）时返回 null。
  ({int offset, int count})? _sentenceTokenRange(int index) {
    final counts = [
      for (final s in state.sentences) _splitTokens(s.text).length,
    ];
    final total = counts.fold<int>(0, (sum, c) => sum + c);
    if (state.words.length != total) return null;
    var offset = 0;
    for (var i = 0; i < index; i++) {
      offset += counts[i];
    }
    return (offset: offset, count: counts[index]);
  }

  /// 全局词下标 [globalIndex] 所属的句索引；找不到返回 null。
  int? _sentenceIndexOfWord(int globalIndex) {
    var offset = 0;
    for (var i = 0; i < state.sentences.length; i++) {
      final count = _splitTokens(state.sentences[i].text).length;
      if (globalIndex >= offset && globalIndex < offset + count) return i;
      offset += count;
    }
    return null;
  }

  /// 取第 [index] 句的可编辑词切片：钳到当前句区间 + 首尾贴合句子边界。
  List<WordTimestamp> _sentenceWords(int index) {
    final sentence = state.sentences[index];
    final range = _sentenceTokenRange(index);
    if (range == null) {
      // 词列表与文本 token 不同步（结构刚变），即时按比例重建本句。
      final tokens = _splitTokens(sentence.text);
      if (tokens.isEmpty) return const [];
      return _proportionalTokens(tokens, sentence);
    }
    if (range.count == 0) return const [];
    final slice = state.words
        .sublist(range.offset, range.offset + range.count)
        .toList();
    for (var i = 0; i < slice.length; i++) {
      slice[i] = _clampWordToSentence(
        slice[i],
        slice[i].word,
        sentence.startTime,
        sentence.endTime,
      );
    }
    slice[0] = slice.first.copyWith(startTime: sentence.startTime);
    slice[slice.length - 1] = slice.last.copyWith(endTime: sentence.endTime);
    return slice;
  }

  /// 整篇词列表（保存用）：逐句取 [_sentenceWords]（已钳到句区间、首尾贴合句子边界）。
  List<WordTimestamp> _wordsSnappedToSentences() {
    final result = <WordTimestamp>[];
    for (var i = 0; i < state.sentences.length; i++) {
      result.addAll(_sentenceWords(i));
    }
    return result;
  }

  /// 加载 / 结构变化后，按句子文本 token 物化整篇可编辑词列表。
  ///
  /// 每句：若全篇 token 数与 [rawWords] 数一致则按顺序索引取真实词级时间（钳到句区间），
  /// 否则按句内字符比例近似切分；并把首词贴句首、末词贴句尾。
  static List<WordTimestamp> _buildWords(
    List<Sentence> sentences,
    List<WordTimestamp> rawWords,
  ) {
    final counts = [for (final s in sentences) _splitTokens(s.text).length];
    final total = counts.fold<int>(0, (sum, c) => sum + c);
    final aligned = total > 0 && rawWords.length == total;
    final result = <WordTimestamp>[];
    var offset = 0;
    for (final sentence in sentences) {
      final tokens = _splitTokens(sentence.text);
      if (tokens.isEmpty) continue;
      final List<WordTimestamp> words;
      if (aligned) {
        words = [
          for (var k = 0; k < tokens.length; k++)
            _clampWordToSentence(
              rawWords[offset + k],
              tokens[k],
              sentence.startTime,
              sentence.endTime,
            ),
        ];
      } else {
        words = _proportionalTokens(tokens, sentence);
      }
      words[0] = words.first.copyWith(startTime: sentence.startTime);
      words[words.length - 1] = words.last.copyWith(endTime: sentence.endTime);
      result.addAll(words);
      offset += tokens.length;
    }
    return result;
  }

  /// 用给定词级时间构造词，并把时间钳到句区间（边界词不越过句起止线）。
  static WordTimestamp _clampWordToSentence(
    WordTimestamp word,
    String text,
    Duration start,
    Duration end,
  ) {
    var s = word.startTime;
    var e = word.endTime;
    if (s < start) s = start;
    if (s > end) s = end;
    if (e > end) e = end;
    if (e < s) e = s;
    return WordTimestamp(
      word: text,
      startTime: s,
      endTime: e,
      confidence: word.confidence,
    );
  }

  /// 按各词字符数比例把句区间切成词级时间（无真实词级数据时使用）。
  static List<WordTimestamp> _proportionalTokens(
    List<String> tokens,
    Sentence s,
  ) {
    final startMs = s.startTime.inMilliseconds;
    final endMs = s.endTime.inMilliseconds;
    final span = endMs - startMs;
    final weights = [for (final token in tokens) _tokenWeight(token)];
    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
    final result = <WordTimestamp>[];
    var currentMs = startMs;
    var consumed = 0;
    for (var i = 0; i < tokens.length; i++) {
      consumed += weights[i];
      final nextMs = i == tokens.length - 1
          ? endMs
          : (span <= 0 || totalWeight <= 0
                ? startMs
                : startMs + (span * consumed / totalWeight).round());
      result.add(
        WordTimestamp(
          word: tokens[i],
          startTime: Duration(milliseconds: currentMs),
          endTime: Duration(milliseconds: nextMs),
          confidence: 0,
        ),
      );
      currentMs = nextMs;
    }
    return result;
  }

  /// 词的时长权重：字母数字字符数（纯标点 token 记 1，保证也分到时间）。
  static int _tokenWeight(String token) {
    final alnum = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length;
    return alnum > 0 ? alnum : 1;
  }

  /// 就地编辑选中句第 [localWordIndex] 个词为 [input]（铅笔编辑提交时调用）。
  ///
  /// 同步更新句子文本 token 与词列表，维持「词数 == 句子 token 数」不变量：
  /// - [input] 为空 → 删除该词（其余词时间戳不变）；若是句中唯一词则删整句。
  /// - 单个词 → 仅改词文本，时间区间不变。
  /// - 多个词 → 把原词的 `[start, end]` 按各词字符数比例切成多段（[_proportionalTokens]）。
  ///
  /// 删首/末词会让句界跟随新首/末词时间，避免 [_buildWords] 把它 snap 回旧句界从而
  /// 改动其余词时间戳。
  void editWord(int localWordIndex, String input) {
    final selected = state.selectedSentenceIndex;
    if (selected == null ||
        selected < 0 ||
        selected >= state.sentences.length) {
      return;
    }
    final range = _sentenceTokenRange(selected);
    if (range == null) return;
    if (localWordIndex < 0 || localWordIndex >= range.count) return;
    final view = _sentenceWords(selected);
    if (localWordIndex >= view.length) return;
    final globalIndex = range.offset + localWordIndex;
    final original = view[localWordIndex];

    final newTokens = _splitTokens(input);

    // 句子文本 token：用新 token 替换被编辑词。
    final sentence = state.sentences[selected];
    final tokens = _splitTokens(sentence.text)
      ..replaceRange(localWordIndex, localWordIndex + 1, newTokens);
    final newText = tokens.join(' ');

    // 删空了该词：句中唯一词则删整句（deleteSentence 内部会处理单句无法删的情况），
    // 否则只移除该词。
    if (newText.isEmpty) {
      deleteSentence(selected);
      return;
    }

    // 词列表：用新词（按字符比例分配原词区间）替换被编辑词；删除则移除。
    final replacement = newTokens.isEmpty
        ? const <WordTimestamp>[]
        : _proportionalTokens(
            newTokens,
            Sentence(
              index: 0,
              text: '',
              startTime: original.startTime,
              endTime: original.endTime,
            ),
          );
    final newWords = List<WordTimestamp>.of(state.words)
      ..replaceRange(globalIndex, globalIndex + 1, replacement);

    // 句界跟随新首/末词，保证其余词时间戳不被 _buildWords 的首尾 snap 改动。
    final newStart = newWords[range.offset].startTime;
    final newEnd = newWords[range.offset + tokens.length - 1].endTime;
    final nextSentences = [...state.sentences];
    nextSentences[selected] = sentence.copyWith(
      text: newText,
      startTime: newStart,
      endTime: newEnd,
    );

    _wordsDirty = true;
    final wasPlaying = state.isPlaying;
    if (wasPlaying) _cancelPlaybackSession();
    state = state.copyWith(
      sentences: nextSentences,
      words: _buildWords(nextSentences, newWords),
      focusedWordIndex: null,
      isDirty: _sentencesChanged(nextSentences) || _wordsDirty,
      playingSentenceIndex: wasPlaying ? null : state.playingSentenceIndex,
      isPlaying: wasPlaying ? false : state.isPlaying,
      playbackMode: wasPlaying
          ? SubtitleEditorPlaybackMode.idle
          : state.playbackMode,
    );
  }

  /// 把选中句从第 [localWordIndex] 个词处分成两句（剪刀分句时调用）。
  ///
  /// 该词成为新句（后半）的首词；前半保留原起点、终点贴前一词终点，后半起点贴该词
  /// 起点、保留原终点。首词（[localWordIndex] == 0）不允许分句（会产生空句）。
  /// 词数不变 → [_buildWords] 按序对齐保留已编辑时间。
  void splitSentenceAtWord(int localWordIndex) {
    final selected = state.selectedSentenceIndex;
    if (selected == null ||
        selected < 0 ||
        selected >= state.sentences.length) {
      return;
    }
    final sentence = state.sentences[selected];
    final tokens = _splitTokens(sentence.text);
    final view = _sentenceWords(selected);
    if (localWordIndex < 1 || localWordIndex >= tokens.length) return;
    if (localWordIndex >= view.length) return;

    final next = _engine.splitSentence(
      state.sentences,
      selected,
      firstText: tokens.sublist(0, localWordIndex).join(' '),
      firstEnd: view[localWordIndex - 1].endTime,
      secondText: tokens.sublist(localWordIndex).join(' '),
      secondStart: view[localWordIndex].startTime,
    );
    if (identical(next, state.sentences)) return;
    _cancelPlaybackSession();
    state = state.copyWith(
      sentences: next,
      selectedSentenceIndex: selected,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: next[selected].startTime,
      isDirty: _sentencesChanged(next) || _wordsDirty,
      focusedWordIndex: null,
      words: _buildWords(next, state.words),
    );
  }

  /// 播放选中句内第 [wordIndex] 个词，并把它标记为「点中词」以显示词边界。
  ///
  /// 复用区间播放基元（[AudioEngine.playRangeOnce]）、session 隔离与播放头计时器，
  /// 与 [playSentence] 同源。索引越界时钳到合法范围（label 与词数偶尔不一致时兜底）。
  /// 播放结束后保留 [SubtitleEditorState.focusedWordIndex]，便于用户继续查看边界。
  Future<void> playWord(int wordIndex) async {
    final words = wordsOfSelectedSentence;
    if (words.isEmpty) return;
    final index = wordIndex.clamp(0, words.length - 1);
    final word = words[index];
    await _stopActivePlayback(invalidateSession: true);
    final sessionId = _audioEngine.newSession();
    _startPlayheadTicker(
      sessionId: sessionId,
      start: word.startTime,
      end: word.endTime,
    );
    state = state.copyWith(
      focusedWordIndex: index,
      // 改为播放单个词，清空「正在播放的句子」，让句子行从停止按钮恢复为播放按钮。
      playingSentenceIndex: null,
      isPlaying: true,
      playbackMode: SubtitleEditorPlaybackMode.word,
      playbackPosition: word.startTime,
    );
    try {
      await _audioEngine.setSpeed(state.playbackSpeed);
      await _audioEngine.playRangeOnce(word.startTime, word.endTime, sessionId);
    } finally {
      if (mounted && _audioEngine.isActiveSession(sessionId)) {
        // 同 playSentence：先冻结状态再停底层播放器，避免 stop() 的 position=0
        // 残留事件把播放头拉回词首。保留 focusedWordIndex 让词边界继续显示。
        state = state.copyWith(
          isPlaying: false,
          playbackMode: SubtitleEditorPlaybackMode.idle,
          playbackPosition: word.endTime,
        );
        await _stopActivePlayback(invalidateSession: false);
      }
    }
  }

  Future<void> playSentence(int index) async {
    if (index < 0 || index >= state.sentences.length) return;
    await _stopActivePlayback(invalidateSession: true);
    final sentence = state.sentences[index];
    final sessionId = _audioEngine.newSession();
    _startPlayheadTicker(
      sessionId: sessionId,
      start: sentence.startTime,
      end: sentence.endTime,
    );
    state = state.copyWith(
      selectedSentenceIndex: index,
      playingSentenceIndex: index,
      isPlaying: true,
      playbackMode: SubtitleEditorPlaybackMode.sentence,
      playbackPosition: sentence.startTime,
      // 播放整句而非某个词，退出词聚焦态。
      focusedWordIndex: null,
    );
    try {
      await _audioEngine.setSpeed(state.playbackSpeed);
      await _audioEngine.playClipOnce(sentence, sessionId);
    } finally {
      if (mounted && _audioEngine.isActiveSession(sessionId)) {
        // ⚠️ 关键顺序：必须「先冻结状态（isPlaying=false + 锁定句尾位置）再停底层
        // 播放器」。否则 _audioPlayer.stop() 会吐出 position=0，经
        // absolutePositionStream 映射为 clipStart(=句首) 后被 _handlePosition 采纳
        // （此刻 isPlaying 仍为 true），把播放头拉回句首 —— 即「播放完跳回到前面」。
        // 与 stopPlayback() 同款处理。
        state = state.copyWith(
          playingSentenceIndex: null,
          isPlaying: false,
          playbackMode: SubtitleEditorPlaybackMode.idle,
          playbackPosition: sentence.endTime,
        );
        await _stopActivePlayback(invalidateSession: false);
      }
    }
  }

  Future<void> stopPlayback() async {
    final pausedPosition = state.playbackPosition;
    // 先冻结状态（isPlaying=false + 锁定位置）再停底层播放：否则停止过程中
    // position 流残留事件会被 _handlePosition 处理，把播放头往前推，随后又被
    // pausedPosition 拉回，表现为红线「先往前跳一下再弹回」。
    state = state.copyWith(
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: pausedPosition,
    );
    await _stopActivePlayback(invalidateSession: true);
  }

  void selectSentence(int index) {
    if (index < 0 || index >= state.sentences.length) return;
    final sentence = state.sentences[index];
    state = state.copyWith(
      selectedSentenceIndex: index,
      playbackPosition: sentence.startTime,
      // 用户显式点选 —— 自增 epoch，驱动波形把该句居中。
      selectionEpoch: state.selectionEpoch + 1,
      // 切换选中句，清空上一句的词聚焦态。
      focusedWordIndex: null,
    );
  }

  void scrubTo(Duration position) {
    state = state.copyWith(
      selectedSentenceIndex: _sentenceIndexAt(position),
      playbackPosition: _clampToDuration(position),
      focusedWordIndex: null,
    );
  }

  Future<void> finishScrub(Duration position) async {
    final clamped = _clampToDuration(position);
    if (state.isPlaying) {
      await stopPlayback();
    }
    scrubTo(clamped);
    await _audioEngine.clearClip();
    await _audioEngine.seekToAbsolute(clamped);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final next = speed.clamp(0.5, 2.0).toDouble();
    final currentPosition = state.playbackPosition;
    state = state.copyWith(playbackSpeed: next);
    if (state.isPlaying) {
      _calibratePlayhead(currentPosition);
      await _audioEngine.setSpeed(next);
    }
  }

  void setWaveformZoomScale(double scale) {
    state = state.copyWith(
      waveformZoomScale: scale
          .clamp(1.0, state.maxWaveformZoomScale)
          .toDouble(),
    );
  }

  /// 进入编辑页时按屏幕物理宽度自动计算缩放范围与初始缩放。
  ///
  /// Flutter 逻辑像素以 160px/英寸 为基准，故 1 厘米 ≈ 63 逻辑像素。缩放语义：
  /// `zoom == 1` 时整段音频铺满可视区；最大缩放时 1 秒音频约占 2cm 屏幕长度，
  /// 因此上限 = `音频秒数 × 2cm逻辑像素 / 可视区宽度`。
  ///
  /// 初始缩放仍保持每 1cm 屏幕约显示 1 秒音频，最大缩放则再放大一档用于精调。
  /// 仅在首次进入时执行一次，之后用户可通过滑块手动调整。
  void initZoomForViewport(double usableViewportWidth) {
    if (_didInitZoom) return;
    final seconds = (state.totalDuration?.inMilliseconds ?? 0) / 1000;
    if (usableViewportWidth <= 0 || seconds <= 0) return;
    _didInitZoom = true;
    final initialScale = _logicalPixelsPerCm * seconds / usableViewportWidth;
    final maxScale = initialScale * _maxZoomCentimetersPerSecond;
    state = state.copyWith(
      maxWaveformZoomScale: maxScale.clamp(1.0, double.infinity).toDouble(),
      waveformZoomScale: initialScale
          .clamp(1.0, maxScale.clamp(1.0, double.infinity))
          .toDouble(),
    );
  }

  void mergeWithNext(int index) {
    final next = _engine.mergeWithNext(state.sentences, index);
    if (identical(next, state.sentences)) return;
    _cancelPlaybackSession();
    final selectedIndex = _indexAfterMerge(
      selectedIndex: state.selectedSentenceIndex,
      mergeIndex: index,
    );
    state = state.copyWith(
      sentences: next,
      selectedSentenceIndex: selectedIndex,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: _positionForSelected(next, selectedIndex),
      isDirty: _sentencesChanged(next) || _wordsDirty,
      focusedWordIndex: null,
      // 合并不增减词，词数不变 → 顺序索引对齐，保留已编辑的词级时间。
      words: _buildWords(next, state.words),
    );
  }

  void deleteSentence(int index) {
    final next = _engine.deleteSentence(state.sentences, index);
    if (identical(next, state.sentences)) return;
    _cancelPlaybackSession();
    final selectedIndex = _indexAfterDelete(
      selectedIndex: state.selectedSentenceIndex,
      deletedIndex: index,
      nextLength: next.length,
    );
    // 删除被删句对应的词切片，使剩余词与新文本 token 仍按序对齐、保留已编辑时间。
    final range = _sentenceTokenRange(index);
    final trimmedWords = range == null
        ? state.words
        : (List<WordTimestamp>.of(state.words)
            ..removeRange(range.offset, range.offset + range.count));
    state = state.copyWith(
      sentences: next,
      selectedSentenceIndex: selectedIndex,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: _positionForSelected(next, selectedIndex),
      isDirty: _sentencesChanged(next) || _wordsDirty,
      focusedWordIndex: null,
      words: _buildWords(next, trimmedWords),
    );
  }

  /// 还原句子列表，用于删除后的撤销操作。
  ///
  /// 直接用调用方在删除前捕获的快照覆盖当前列表，并停止任何播放。
  /// 撤销后按当前字幕是否等于进入编辑页时的原始字幕重新计算 [isDirty]。
  void restoreSentences(List<Sentence> snapshot) {
    _cancelPlaybackSession();
    state = state.copyWith(
      sentences: snapshot,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      isDirty: _sentencesChanged(snapshot) || _wordsDirty,
      focusedWordIndex: null,
      words: _buildWords(snapshot, state.words),
    );
  }

  Future<bool> save() async {
    if (!state.isDirty || state.isSaving) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await stopPlayback();

      final item = state.audioItem;

      final srt = _generateSrt(state.sentences);

      // 词级字幕：直接落编辑后的词列表（加载时按句子文本 token 物化、可被拖动编辑），
      // 每句首尾词贴合句子边界，与句子 SRT 保持一致。句子与词级字幕同时更新。
      final dao = _ref.read(audioItemDaoProvider);
      final words = _wordsSnappedToSentences();
      final syncedWordsJson = encodeWordTimestamps(words);

      // 字幕内容（+ 词级时间戳）原子写入 DB 列。
      await dao.saveTranscriptContent(
        item.id,
        srt: srt,
        wordTimestampsJson: syncedWordsJson,
      );

      final wordCount = words.isNotEmpty
          ? words.length
          : state.sentences.fold<int>(
              0,
              (sum, sentence) => sum + _countWords(sentence.text),
            );
      final updatedItem = item.copyWith(
        transcriptPath: null,
        sentenceCount: state.sentences.length,
        wordCount: wordCount,
      );

      await _ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(updatedItem);

      // 句子数量变化（合并/删除）才会打乱按句索引的学习进度和收藏句子，需清空；
      // 仅调整时间戳时索引对应关系不变，保留进度与收藏。
      if (sentenceCountChanged) {
        await _ref.read(bookmarkDaoProvider).removeAllForAudio(item.id);
        await _ref
            .read(learningProgressNotifierProvider.notifier)
            .deleteProgress(item.id);
      }

      final practiceState = _ref.read(listeningPracticeProvider);
      if (practiceState.currentAudioItem?.id == item.id) {
        // 字幕保存只改 DB transcript_srt 列，id / transcriptPath 不变（都为 null）。
        // loadAudio 的去重守卫只比较 id + transcriptPath，不带 force 会命中守卫
        // 直接跳过重新解析，使 keepAlive 的 LP 保留旧句子（自由练习/盲听显示陈旧
        // 拆分版本）。必须强制重载以绕过守卫，从 DB 列读到最新内容。
        await _ref
            .read(listeningPracticeProvider.notifier)
            .loadAudio(updatedItem, forceTranscriptReload: true);
      }

      _baselineSentenceCount = state.sentences.length;
      _baselineSubtitleHash = _subtitleHash(state.sentences);
      _wordsDirty = false;
      if (!mounted) return true;
      state = state.copyWith(
        isSaving: false,
        isDirty: false,
        audioItem: updatedItem,
      );
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isSaving: false, errorMessage: e.toString());
      }
      return false;
    }
  }

  void _handlePosition(Duration position) {
    if (!mounted || !state.isPlaying) return;
    if (position < _playbackStart ||
        position > _playbackEnd + const Duration(milliseconds: 250)) {
      return;
    }
    // 防御：播放期间播放头由本地时钟（_tickPlayhead）单调前进，position 流仅做校准。
    // 大幅「后退」几乎只可能是停止/换 clip 的残留事件（stop 把相对位置归 0 → 映射成
    // clip 起点），直接丢弃，避免把播放头拉回。允许 ≤400ms 的正常校准抖动。
    if (position < state.playbackPosition - const Duration(milliseconds: 400)) {
      return;
    }
    final clamped = _clampToPlaybackRange(position);
    _calibratePlayhead(clamped);
    state = state.copyWith(
      selectedSentenceIndex: _selectedIndexDuringPlayback(clamped),
      playbackPosition: clamped,
    );
  }

  /// 播放推进时的选中句索引。
  ///
  /// 仅连续播放（range 模式）跟随播放头切换选中句；单句播放（sentence 模式）
  /// 保持焦点在当前句，避免播到句尾因与下一句首尾相接而跳到下一句。
  int? _selectedIndexDuringPlayback(Duration position) {
    if (state.playbackMode == SubtitleEditorPlaybackMode.range) {
      return _sentenceIndexAt(position);
    }
    return state.selectedSentenceIndex;
  }

  int? _sentenceIndexAt(Duration position) {
    final index = state.sentences.indexWhere(
      (sentence) =>
          position >= sentence.startTime && position < sentence.endTime,
    );
    return index < 0 ? state.selectedSentenceIndex : index;
  }

  Duration _clampToDuration(Duration position) {
    final total = _effectiveTotalDuration();
    if (position < Duration.zero) return Duration.zero;
    if (total != null && position > total) return total;
    return position;
  }

  Duration? _effectiveTotalDuration() {
    return state.totalDuration ?? state.waveform?.duration;
  }

  void _cancelPlaybackSession() {
    if (!state.isPlaying && state.playingSentenceIndex == null) return;
    _audioEngine.newSession();
    _cancelPlayheadTicker();
    unawaited(_stopAndClearClip());
  }

  Future<void> _stopActivePlayback({required bool invalidateSession}) async {
    final shouldStop =
        state.isPlaying ||
        state.playingSentenceIndex != null ||
        _activePlaybackSessionId != null;
    if (invalidateSession) {
      _audioEngine.newSession();
    }
    _cancelPlayheadTicker();
    if (shouldStop) {
      await _stopAndClearClip();
      return;
    }
    await _audioEngine.clearClip();
  }

  Future<void> _stopAndClearClip() async {
    await _audioEngine.stopPlayback();
    await _audioEngine.clearClip();
  }

  /// 用本地时钟驱动播放头，底层 position stream 只负责校准。
  ///
  /// 这是音频编辑器常见做法：UI 以稳定帧率前进，避免播放器 position
  /// 事件稀疏时红线跳动；真正完成仍由播放 Future / session 兜底。
  void _startPlayheadTicker({
    required int sessionId,
    required Duration start,
    required Duration end,
  }) {
    _cancelPlayheadTicker();
    _activePlaybackSessionId = sessionId;
    _playbackStart = start;
    _playbackEnd = end;
    _calibratePlayhead(start);
    _playheadTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _tickPlayhead(),
    );
  }

  void _cancelPlayheadTicker() {
    _playheadTimer?.cancel();
    _playheadTimer = null;
    _activePlaybackSessionId = null;
    _playheadAnchorAt = null;
  }

  void _calibratePlayhead(Duration position) {
    _playheadAnchor = position;
    _playheadAnchorAt = DateTime.now();
  }

  void _tickPlayhead() {
    final sessionId = _activePlaybackSessionId;
    final anchorAt = _playheadAnchorAt;
    if (!mounted ||
        sessionId == null ||
        anchorAt == null ||
        !state.isPlaying ||
        !_audioEngine.isActiveSession(sessionId)) {
      _cancelPlayheadTicker();
      return;
    }

    final elapsed = DateTime.now().difference(anchorAt);
    final advancedUs = elapsed.inMicroseconds * state.playbackSpeed;
    final position = _clampToPlaybackRange(
      _playheadAnchor + Duration(microseconds: advancedUs.round()),
    );
    state = state.copyWith(
      selectedSentenceIndex: _selectedIndexDuringPlayback(position),
      playbackPosition: position,
    );
  }

  Duration _clampToPlaybackRange(Duration position) {
    if (position < _playbackStart) return _playbackStart;
    if (position > _playbackEnd) return _playbackEnd;
    return position;
  }

  Duration _positionForSelected(List<Sentence> sentences, int? selectedIndex) {
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= sentences.length) {
      return Duration.zero;
    }
    return sentences[selectedIndex].startTime;
  }

  /// 字幕是否相对进入编辑页或上次保存后的基线发生了实质变化。
  ///
  /// dirty 状态只看最终可保存的 SRT 内容，不看用户操作历史；删除后撤销、
  /// 边界拖回原位都会回到未修改状态，避免保存按钮误激活。
  bool _sentencesChanged(List<Sentence> current) {
    return _subtitleHash(current) != _baselineSubtitleHash;
  }

  String _subtitleHash(List<Sentence> sentences) {
    return sha256.convert(utf8.encode(_generateSrt(sentences))).toString();
  }

  String _generateSrt(List<Sentence> sentences) {
    return generateSrtContent([
      for (final sentence in sentences)
        TranscriptSentence(
          text: sentence.text,
          startTime: sentence.startTime,
          endTime: sentence.endTime,
        ),
    ]);
  }

  /// 波形提取的「无进展」超时窗口。
  ///
  /// 提取正常时原生会持续上报进度（每递增 1% 触发一次），只要有事件到达就重置计时；
  /// 仅当**连续这么久没有任何进度事件**（真机原生解码卡死、且未报错）才判失败。
  /// 取足够大的值，避免误伤慢机型上长音频「首个 1% 需解码较多音频」的正常等待。
  static const Duration _waveformInactivityTimeout = Duration(seconds: 60);

  /// 波形提取是否正在进行，避免 [load] 与 [retryWaveform] 并发重复提取。
  bool _loadingWaveform = false;

  /// 重新尝试提取波形（失败态下用户点「重试」）。
  Future<void> retryWaveform() async {
    if (_loadingWaveform) return;
    state = state.copyWith(waveformFailed: false, waveformProgress: 0);
    await _loadWaveform();
  }

  Future<void> _loadWaveform() async {
    if (_loadingWaveform) return;
    _loadingWaveform = true;
    try {
      final audioPath = await state.audioItem.getFullAudioPath();
      if (audioPath == null) {
        if (mounted) state = state.copyWith(waveformFailed: true);
        return;
      }
      final dataDir = await getAppDataDirectory();
      final waveDir = Directory(p.join(dataDir.path, 'waveforms'));
      if (!await waveDir.exists()) {
        await waveDir.create(recursive: true);
      }
      final waveFile = File(p.join(waveDir.path, '${state.audioItem.id}.wave'));
      if (await waveFile.exists()) {
        final waveform = await JustWaveform.parse(waveFile);
        if (!mounted) return;
        state = state.copyWith(waveform: waveform, waveformProgress: 1);
        return;
      }

      // 原生提取失败（如 HE-AAC/SBR 触发采样率变更抛异常，见 §排查）会以 stream error
      // 抛出；原生卡死无事件则由 timeout 兜底。两者都进 catch 置失败态，而不再假死 0%。
      await for (final progress in JustWaveform.extract(
        audioInFile: File(audioPath),
        waveOutFile: waveFile,
        zoom: const WaveformZoom.pixelsPerSecond(80),
      ).timeout(_waveformInactivityTimeout)) {
        if (!mounted) return;
        state = state.copyWith(
          waveform: progress.waveform,
          waveformProgress: progress.progress,
        );
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(waveformFailed: true);
    } finally {
      _loadingWaveform = false;
    }
  }

  int _countWords(String text) {
    return text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int? _indexAfterMerge({
    required int? selectedIndex,
    required int mergeIndex,
  }) {
    if (selectedIndex == null) return null;
    if (selectedIndex == mergeIndex + 1) return mergeIndex;
    if (selectedIndex > mergeIndex + 1) return selectedIndex - 1;
    return selectedIndex;
  }

  int? _indexAfterDelete({
    required int? selectedIndex,
    required int deletedIndex,
    required int nextLength,
  }) {
    if (selectedIndex == null || nextLength == 0) return null;
    if (selectedIndex == deletedIndex) {
      return deletedIndex.clamp(0, nextLength - 1).toInt();
    }
    if (selectedIndex > deletedIndex) return selectedIndex - 1;
    return selectedIndex.clamp(0, nextLength - 1).toInt();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cancelPlayheadTicker();
    _audioEngine.newSession();
    unawaited(_stopAndClearClip());
    super.dispose();
  }
}

/// Text → Lesson 页面：粘贴/导入纯文本，选择音色与语速，生成可学习音频。
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/tts/kokoro_model_provider.dart';
import '../../../providers/tts/tts_settings_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/tts/kokoro_voices.dart';
import '../../../services/tts/tts_engine.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tts/tts_model_download_prompt_dialog.dart';
import '../providers/text_lesson_provider.dart';

class TextLessonScreen extends ConsumerStatefulWidget {
  const TextLessonScreen({super.key});

  @override
  ConsumerState<TextLessonScreen> createState() => _TextLessonScreenState();
}

class _TextLessonScreenState extends ConsumerState<TextLessonScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  String _voiceId = kokoroDefaultVoiceUs;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(ttsSettingsProvider);
      setState(() {
        _voiceId = settings.activeKokoroVoice;
        _speed = settings.speed;
      });
      if (settings.engine != TtsEngineKind.kokoro) {
        ref.read(ttsSettingsProvider.notifier).setEngine(TtsEngineKind.kokoro);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickTextFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) return;
    final text = utf8.decode(bytes, allowMalformed: true);
    if (!mounted) return;
    setState(() {
      _textController.text = text;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = file.name.replaceFirst(
          RegExp(r'\.txt$', caseSensitive: false),
          '',
        );
      }
    });
  }

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showMessage(l10n.textToLessonTextRequired);
      return;
    }
    final settings = ref.read(ttsSettingsProvider);
    if (settings.engine != TtsEngineKind.kokoro) {
      await ref
          .read(ttsSettingsProvider.notifier)
          .setEngine(TtsEngineKind.kokoro);
    }
    final ready = await ensureTtsModelReadyForPlaybackFromWidget(ref);
    if (!ready || !mounted) return;

    final result = await ref
        .read(textLessonControllerProvider.notifier)
        .generate(
          title: _titleController.text,
          text: text,
          voiceId: _voiceId,
          speed: _speed,
        );
    if (!mounted || result == null) return;
    if (!context.mounted) return;
    context.push(
      AppRoutes.audioLearningPlan(result.audioItem.id, autoStart: true),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(textLessonControllerProvider);
    final model = ref
        .watch(kokoroModelProvider)
        .of(ref.watch(ttsSettingsProvider).kokoroVariant);
    final voices = kokoroVoices;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.textToLessonTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Text(
            l10n.textToLessonDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.textToLessonTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _textController,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              labelText: l10n.textToLessonTextLabel,
              hintText: l10n.textToLessonTextHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: state.isGenerating ? null : _pickTextFile,
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.textToLessonImportFile),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          DropdownButtonFormField<String>(
            initialValue: voices.any((voice) => voice.id == _voiceId)
                ? _voiceId
                : kokoroDefaultVoiceUs,
            decoration: InputDecoration(
              labelText: l10n.textToLessonVoice,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final voice in voices)
                DropdownMenuItem(
                  value: voice.id,
                  child: Text(
                    '${voice.language == TtsLanguage.chinese ? '中文' : 'English'}'
                    ' · ${voice.displayName}',
                  ),
                ),
            ],
            onChanged: state.isGenerating
                ? null
                : (value) {
                    if (value != null) setState(() => _voiceId = value);
                  },
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(child: Text(l10n.textToLessonSpeed)),
              Text('${_speed.toStringAsFixed(1)}x'),
            ],
          ),
          Slider(
            value: _speed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${_speed.toStringAsFixed(1)}x',
            onChanged: state.isGenerating
                ? null
                : (value) => setState(() => _speed = value),
          ),
          const SizedBox(height: AppSpacing.m),
          if (!model.isReady)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.textToLessonModelRequired),
                subtitle: Text(l10n.textToLessonModelRequiredHint),
              ),
            ),
          if (state.progress != null) ...[
            LinearProgressIndicator(value: state.progress!.fraction),
            const SizedBox(height: AppSpacing.xs),
            Text(state.progress!.message),
            const SizedBox(height: AppSpacing.m),
          ],
          if (state.error != null && state.error != 'offline_model_required')
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: Text(
                l10n.textToLessonFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: state.isGenerating ? null : _generate,
            icon: const Icon(Icons.graphic_eq),
            label: Text(
              state.isGenerating
                  ? l10n.textToLessonGenerating
                  : l10n.textToLessonGenerate,
            ),
          ),
          if (state.isGenerating) ...[
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: () =>
                  ref.read(textLessonControllerProvider.notifier).cancel(),
              child: Text(l10n.textToLessonCancel),
            ),
          ],
        ],
      ),
    );
  }
}

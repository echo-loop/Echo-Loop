import 'package:universal_io/io.dart';
import 'package:subtitle/subtitle.dart';
import '../models/sentence.dart';

class SubtitleParser {
  static Future<List<Sentence>> parseSubtitle(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final controller = SubtitleController(
        provider: SubtitleProvider.fromString(
          data: content,
          type: _getSubtitleType(filePath),
        ),
      );

      await controller.initial();
      final subtitles = controller.subtitles;

      return subtitles.asMap().entries.map((entry) {
        final subtitle = entry.value;
        return Sentence(
          index: entry.key,
          text: subtitle.data.trim(),
          startTime: subtitle.start,
          endTime: subtitle.end,
        );
      }).toList();
    } catch (e) {
      print('Error parsing subtitle: $e');
      return [];
    }
  }

  static SubtitleType _getSubtitleType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'srt':
        return SubtitleType.srt;
      case 'vtt':
        return SubtitleType.vtt;
      default:
        return SubtitleType.srt; // default to SRT
    }
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }
}

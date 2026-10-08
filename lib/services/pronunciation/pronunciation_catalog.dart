/// 内置离线发音包资源目录；归档路径相对于运行时选择的 CDN 基地址。
class PronunciationSpec {
  const PronunciationSpec({
    required this.resourceId,
    required this.archivePath,
    required this.archiveSha256,
    required this.estimatedDownloadBytes,
  });

  final String resourceId;
  final String archivePath;
  final String archiveSha256;
  final int estimatedDownloadBytes;
}

/// 当前发布的离线发音包资源。
const pronunciationSpec = PronunciationSpec(
  resourceId: 'pronunciation-v2',
  archivePath: 'dictionary/pronunciation-v2.zip',
  archiveSha256:
      'db1bf8c8ec953f48ed05e22f8254cd8385f3c26f0acb630f73aedf14bbb6a1ca',
  estimatedDownloadBytes: 41379389,
);

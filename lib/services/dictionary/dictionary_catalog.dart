/// 内置离线词典资源目录。
///
/// 词典资源随 App 版本发布：更新词典时先上传新的 ZIP，再同步修改此文件中的
/// resourceId、URL 和 SHA-256。运行中的 App 不通过远程 manifest 检查更新。
library;

/// 单个离线词典 ZIP 资源规格，归档路径相对于运行时选择的 CDN 基地址。
class DictionarySpec {
  const DictionarySpec({
    required this.nativeLanguage,
    required this.resourceId,
    required this.archivePath,
    required this.archiveSha256,
    required this.estimatedDownloadBytes,
  });

  final String nativeLanguage;
  final String resourceId;
  final String archivePath;
  final String archiveSha256;

  /// CDN 压缩包的预计下载大小（字节），用于展示或后续下载策略。
  final int estimatedDownloadBytes;
}

/// 当前发布的离线词典资源。
const dictionarySpecs = <String, DictionarySpec>{
  'zh-CN': DictionarySpec(
    nativeLanguage: 'zh-CN',
    resourceId: 'dict-en_zh-CN-v1',
    archivePath: 'dictionary/en_zh-CN/dict_en_zh-CN-v1.sqlite.zip',
    archiveSha256:
        '2acfc22aae4658b707973c508e1356d4c8ce4bc07c502c6d2c3030a95bc5f5e9',
    estimatedDownloadBytes: 12552930,
  ),
  'zh-TW': DictionarySpec(
    nativeLanguage: 'zh-TW',
    resourceId: 'dict-en_zh-TW-v1',
    archivePath: 'dictionary/en_zh-TW/dict_en_zh-TW-v1.sqlite.zip',
    archiveSha256:
        'dee7bc7d6ec43f88371d17a6a2595d277172a8897d70ff9a280a5ef8142d4cac',
    estimatedDownloadBytes: 12552893,
  ),
};

/// 返回指定母语的内置词典规格。
DictionarySpec dictionarySpecOf(String nativeLanguage) {
  final spec = dictionarySpecs[nativeLanguage];
  if (spec == null) {
    throw ArgumentError.value(nativeLanguage, 'nativeLanguage');
  }
  return spec;
}

import 'dart:typed_data';

/// 编辑本地合集时对封面的修改意图，由表单产生、交给 `CollectionList` 落盘。
sealed class CollectionCoverEdit {
  const CollectionCoverEdit();
}

/// 保持原封面（包括原本就没有封面）。
final class CollectionCoverUnchanged extends CollectionCoverEdit {
  const CollectionCoverUnchanged();
}

/// 换成新图片；[jpegBytes] 为已裁剪并编码好的 512×512 JPEG。
final class CollectionCoverReplaced extends CollectionCoverEdit {
  const CollectionCoverReplaced(this.jpegBytes);

  final Uint8List jpegBytes;
}

/// 移除自定义封面，回到首字母占位。
final class CollectionCoverRemoved extends CollectionCoverEdit {
  const CollectionCoverRemoved();
}

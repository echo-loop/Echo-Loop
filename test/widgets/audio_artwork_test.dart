// 素材方形图标：默认图标的尺寸与圆角，以及封面地址的优先级。
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/widgets/audio_artwork.dart';
import 'package:echo_loop/widgets/media_type_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AudioItem audio({String path = 'audios/a.mp3', String? podcastImageUrl}) {
    return AudioItem(
      id: 'a1',
      name: 'Audio',
      audioPath: path,
      addedDate: DateTime(2026, 1, 1),
      podcastImageUrl: podcastImageUrl,
    );
  }

  Collection subscribed({
    CollectionSource source = CollectionSource.community,
    String? coverUrl,
    String? coverUrlChina,
    String? podcastMetaJson,
  }) {
    return Collection(
      id: 'c1',
      name: 'Collection',
      createdDate: DateTime(2026, 1, 1),
      source: source,
      coverUrl: coverUrl,
      coverUrlChina: coverUrlChina,
      podcastMetaJson: podcastMetaJson,
    );
  }

  group('AudioArtwork 默认图标', () {
    testWidgets('无封面时为与封面同尺寸的圆角方形，视频显示视频图标', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioArtwork(imageUrl: null, isVideo: true, size: 36),
          ),
        ),
      );

      expect(tester.getSize(find.byType(AudioArtwork)), const Size(36, 36));
      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(MediaTypeIcon),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(8),
      );
      expect(
        tester.widget<MediaTypeIcon>(find.byType(MediaTypeIcon)).isVideo,
        isTrue,
      );
    });
  });

  group('resolveSubscribedArtworkUrl', () {
    test('单集自身封面优先于合集封面', () {
      final url = resolveSubscribedArtworkUrl(
        audio: audio(podcastImageUrl: ' https://episode.png '),
        collection: subscribed(coverUrl: 'https://collection.png'),
        isChinaUser: false,
      );

      expect(url, 'https://episode.png');
    });

    test('播客合集优先使用 Feed 封面，缺失时回退到合集封面', () {
      const meta =
          '{"title":"Show","feedUrl":"https://feed.xml","imageUrl":"https://feed.png"}';

      expect(
        resolveSubscribedArtworkUrl(
          audio: audio(),
          collection: subscribed(
            source: CollectionSource.podcast,
            coverUrl: 'https://collection.png',
            podcastMetaJson: meta,
          ),
          isChinaUser: false,
        ),
        'https://feed.png',
      );
      expect(
        resolveSubscribedArtworkUrl(
          audio: audio(),
          collection: subscribed(
            source: CollectionSource.podcast,
            coverUrl: 'https://collection.png',
            podcastMetaJson: 'not json',
          ),
          isChinaUser: false,
        ),
        'https://collection.png',
      );
    });

    test('社区合集按地区选择中国镜像，无镜像时使用全球地址', () {
      final collection = subscribed(
        coverUrl: 'https://global.png',
        coverUrlChina: 'https://china.png',
      );

      expect(
        resolveSubscribedArtworkUrl(
          audio: audio(),
          collection: collection,
          isChinaUser: true,
        ),
        'https://china.png',
      );
      expect(
        resolveSubscribedArtworkUrl(
          audio: audio(),
          collection: subscribed(coverUrl: 'https://global.png'),
          isChinaUser: true,
        ),
        'https://global.png',
      );
    });
  });
}

import 'dart:convert';

import 'package:echo_loop/features/podcast/podcast_info_sheet.dart';
import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shared/fake_notifiers.dart';
import '../../helpers/test_app.dart';
import '../../helpers/mock_providers.dart';

/// 测试用可变合集列表：暴露 [replace] 便于模拟刷新后合集被更新。
class _MutableCollectionList extends FakeCollectionList {
  _MutableCollectionList(super.initialState);

  void replace(Collection collection) {
    state = state.copyWith(rawCollections: [collection]);
  }
}

/// 构造带 podcast 元信息 JSON 的合集。[description] 写入 meta，模拟 RSS 解析结果。
Collection _podcastCollection({required String description}) {
  final meta = PodcastFeedMeta(
    title: 'Learning English Stories',
    feedUrl: 'https://example.com/feed.xml',
    description: description,
  );
  return Collection(
    id: 'c1',
    name: 'Learning English Stories',
    createdDate: DateTime(2026),
    source: CollectionSource.podcast,
    description: description,
    podcastFeedUrl: 'https://example.com/feed.xml',
    podcastMetaJson: jsonEncode(meta.toJson()),
  );
}

void main() {
  Future<void> openSheet(WidgetTester tester, {String? description}) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showPodcastInfoSheet(
                context,
                title: 'Details',
                heroTitle: '6 Minute English',
                heroDescription: description,
                links: const [
                  PodcastInfoLink('RSS URL', 'https://example.com/feed.xml'),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('右键链接弹出复制菜单，选择后复制 URL 并提示', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await openSheet(tester);

    // 无常驻复制图标，需右键唤出菜单。
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
    await tester.tap(
      find.text('https://example.com/feed.xml'),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    // 菜单出现「复制」项。
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copied, 'https://example.com/feed.xml');
    expect(find.text('Link copied'), findsOneWidget);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('多段描述逐段渲染，段落之间插入间距', (tester) async {
    await openSheet(
      tester,
      description: 'First paragraph.\nSecond paragraph.\nThird paragraph.',
    );

    // 每个段落渲染成独立的 SelectableText。
    expect(find.text('First paragraph.'), findsOneWidget);
    expect(find.text('Second paragraph.'), findsOneWidget);
    expect(find.text('Third paragraph.'), findsOneWidget);

    // 三段之间应有两处段落间距（高度 AppSpacing.s = 8）。
    final gaps = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((b) => b.height == 8);
    expect(gaps.length, greaterThanOrEqualTo(2));
  });

  testWidgets('播客详情展示类别和语言，隐藏分级与版权', (tester) async {
    const meta = PodcastFeedMeta(
      title: 'Learning English Stories',
      feedUrl: 'https://example.com/feed.xml',
      categories: ['Education', 'Language Learning'],
      language: 'en',
      explicit: 'no',
      copyright: '(C) BBC 2026',
    );

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showPodcastFeedMetaInfoSheet(
                context,
                meta: meta,
                applePodcastUrl: 'https://podcasts.apple.com/podcast/id123',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Categories: Education · Language Learning'),
      findsOneWidget,
    );
    expect(find.text('Language: en'), findsOneWidget);
    expect(find.textContaining('Explicit:'), findsNothing);
    expect(find.textContaining('Copyright:'), findsNothing);
  });

  testWidgets('合集详情弹窗随刷新自动更新描述，无需关闭重开', (tester) async {
    // 旧描述：段落被压成空格（模拟旧清洗逻辑写入 DB 的脏数据）。
    final oldCollection = _podcastCollection(
      description: 'First paragraph. Second paragraph. Third paragraph.',
    );
    late _MutableCollectionList notifier;

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showPodcastFeedInfoSheet(context, oldCollection),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          collectionListProvider.overrideWith(() {
            notifier = _MutableCollectionList(
              CollectionState(rawCollections: [oldCollection]),
            );
            return notifier;
          }),
        ]),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 初始为旧格式：整段合并成一条文本。
    expect(
      find.text('First paragraph. Second paragraph. Third paragraph.'),
      findsOneWidget,
    );

    // 模拟刷新写回新描述（段落保留换行）。弹窗应自动重建。
    notifier.replace(
      _podcastCollection(
        description: 'First paragraph.\nSecond paragraph.\nThird paragraph.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First paragraph.'), findsOneWidget);
    expect(find.text('Second paragraph.'), findsOneWidget);
    expect(find.text('Third paragraph.'), findsOneWidget);
    expect(
      find.text('First paragraph. Second paragraph. Third paragraph.'),
      findsNothing,
    );
  });

  testWidgets('长按链接弹出复制菜单', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await openSheet(tester);

    await tester.longPress(find.text('https://example.com/feed.xml'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copied, 'https://example.com/feed.xml');

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}

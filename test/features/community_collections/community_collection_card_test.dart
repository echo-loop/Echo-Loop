import 'package:cached_network_image/cached_network_image.dart';
import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:echo_loop/features/community_collections/widgets/community_collection_card.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  final item = PublicCollectionCatalogEntry(
    id: 'collection-1',
    name: 'Shared collection',
    description: null,
    coverUrl: null,
    fileCount: 1,
    publishedAt: DateTime(2026, 1, 1),
  );

  testWidgets('发现资源卡片显示上传者而不显示描述', (tester) async {
    final item = PublicCollectionCatalogEntry(
      id: 'collection-2',
      name: 'VOA Learning English',
      description: 'Audio from VOA Learning English Level 1',
      coverUrl: null,
      authorNickname: '  VOA Learning English  ',
      fileCount: 52,
      publishedAt: DateTime(2026, 1, 1),
    );

    await _pumpCard(tester, item, locale: const Locale('zh'));

    expect(find.text('上传者：VOA Learning English'), findsOneWidget);
    expect(find.text('Audio from VOA Learning English Level 1'), findsNothing);
  });

  testWidgets('英文发现资源卡片使用英文上传者文案', (tester) async {
    final item = PublicCollectionCatalogEntry(
      id: 'collection-3',
      name: 'VOA Learning English',
      description: 'Audio from VOA Learning English Level 1',
      coverUrl: null,
      authorNickname: 'Voice of America',
      fileCount: 52,
      publishedAt: DateTime(2026, 1, 1),
    );

    await _pumpCard(tester, item, locale: const Locale('en'));

    expect(find.text('Uploaded by Voice of America'), findsOneWidget);
    expect(find.text('Audio from VOA Learning English Level 1'), findsNothing);
  });

  testWidgets('缺失或空白上传者显示未知上传者', (tester) async {
    final missingUploaderItem = PublicCollectionCatalogEntry(
      id: 'collection-4',
      name: 'Shared collection',
      description: null,
      coverUrl: null,
      authorNickname: null,
      fileCount: 1,
      publishedAt: DateTime(2026, 1, 1),
    );

    await _pumpCard(tester, missingUploaderItem, locale: const Locale('zh'));

    expect(find.text('未知上传者'), findsOneWidget);

    final blankUploaderItem = PublicCollectionCatalogEntry(
      id: 'collection-5',
      name: 'Shared collection',
      description: null,
      coverUrl: null,
      authorNickname: '  ',
      fileCount: 1,
      publishedAt: DateTime(2026, 1, 1),
    );

    await _pumpCard(tester, blankUploaderItem, locale: const Locale('zh'));

    expect(find.text('未知上传者'), findsOneWidget);
  });

  testWidgets('已加入状态显示不可点击的绿色圆形对勾，且详情仍可打开', (tester) async {
    var detailTapCount = 0;

    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: CommunityCollectionCard(
            item: item,
            enrolled: true,
            enrolling: false,
            onOpenDetail: () => detailTapCount++,
            onEnroll: () {},
          ),
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已添加'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '已添加',
      ),
      findsOneWidget,
    );
    expect(find.text('去学习'), findsNothing);
    final checkFinder = find.byIcon(Icons.check_circle_outline_rounded);
    final check = tester.widget<Icon>(checkFinder);
    expect(check.color, AppTheme.successColor);

    final cardRect = tester.getRect(find.byType(CommunityCollectionCard));
    final checkRect = tester.getRect(checkFinder);
    final addedBadgeRect = tester.getRect(find.text('已添加'));
    expect(checkRect.center.dy, closeTo(cardRect.center.dy, 1));
    expect(checkRect.center.dx, greaterThan(cardRect.center.dx));
    expect(addedBadgeRect.top, lessThan(checkRect.top));
    expect(addedBadgeRect.right, lessThanOrEqualTo(cardRect.right));
    expect(addedBadgeRect.center.dx, greaterThan(cardRect.center.dx));

    await tester.tap(checkFinder);
    await tester.pump();
    expect(detailTapCount, 0);

    await tester.tap(find.text('Shared collection'));
    await tester.pump();
    expect(detailTapCount, 1);
  });

  testWidgets('未加入合集仍显示添加入口', (tester) async {
    var enrollTapCount = 0;

    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: CommunityCollectionCard(
            item: item,
            enrolled: false,
            enrolling: false,
            onOpenDetail: () {},
            onEnroll: () => enrollTapCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.text('Added'), findsNothing);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(enrollTapCount, 1);
  });

  testWidgets('英文已加入状态通过无障碍标签说明为 Added', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: CommunityCollectionCard(
            item: item,
            enrolled: true,
            enrolling: false,
            onOpenDetail: () {},
            onEnroll: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Added'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Added',
      ),
      findsOneWidget,
    );
    expect(find.text('Start Practicing'), findsNothing);
  });

  testWidgets('中国地区的发现卡片使用可用的中国封面 URL', (tester) async {
    final itemWithChinaCover = PublicCollectionCatalogEntry(
      id: 'collection-cn',
      name: 'Shared collection',
      description: null,
      coverUrl: 'https://global.example/cover.jpg',
      coverUrlChina: 'https://china.example/cover.jpg',
      fileCount: 1,
      publishedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: CommunityCollectionCard(
            item: itemWithChinaCover,
            isChinaUser: true,
            enrolled: false,
            enrolling: false,
            onOpenDetail: () {},
            onEnroll: () {},
          ),
        ),
      ),
    );

    final cover = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(cover.imageUrl, 'https://china.example/cover.jpg');
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  PublicCollectionCatalogEntry item, {
  required Locale locale,
}) async {
  await tester.pumpWidget(
    createTestApp(
      Scaffold(
        body: CommunityCollectionCard(
          item: item,
          enrolled: false,
          enrolling: false,
          onOpenDetail: () {},
          onEnroll: () {},
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

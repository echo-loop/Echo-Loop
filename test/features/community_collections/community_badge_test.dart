import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/community_collections/widgets/community_badge.dart';
import 'package:echo_loop/models/collection.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('社区合集下架时使用 Removed 状态文案', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        const CollectionSourceCornerBadge(
          source: CollectionSource.community,
          isDeprecated: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Shared'), findsNothing);
  });
}

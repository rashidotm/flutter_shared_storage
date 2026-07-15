import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_cloud_storage.dart';

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: const [
        CloudGalleryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: CloudGalleryLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  group('CloudPathBar buttons', () {
    testWidgets('back and up render disabled when their callbacks are null',
        (tester) async {
      final storage = FakeCloudStorage();
      await tester.pumpWidget(_harness(
        CloudPathBar(
          storage: storage,
          folderId: kRootFolderId,
          onNavigate: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      final back = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_back),
      );
      final up = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward),
      );
      expect(back.onPressed, isNull);
      expect(up.onPressed, isNull);
    });

    testWidgets('back / up call their callbacks when tapped', (tester) async {
      final storage = FakeCloudStorage();
      var backCount = 0;
      var upCount = 0;
      await tester.pumpWidget(_harness(
        CloudPathBar(
          storage: storage,
          folderId: kRootFolderId,
          onNavigate: (_) {},
          onBack: () => backCount++,
          onUp: () => upCount++,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
      expect(backCount, 1);
      expect(upCount, 1);
    });

    testWidgets('trailing widgets render after the breadcrumb', (tester) async {
      final storage = FakeCloudStorage();
      await tester.pumpWidget(_harness(
        CloudPathBar(
          storage: storage,
          folderId: kRootFolderId,
          onNavigate: (_) {},
          trailing: [const Icon(Icons.filter_alt, key: Key('trailing-1'))],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trailing-1')), findsOneWidget);
    });
  });
}

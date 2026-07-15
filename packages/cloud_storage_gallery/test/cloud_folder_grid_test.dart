import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_cloud_storage.dart';

/// Wraps [child] in the minimum viable widget tree for the gallery's
/// widgets to render: MaterialApp + localizations delegate + fixed
/// English locale.
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
  group('CloudFolderGrid', () {
    testWidgets('renders the localized empty label for an empty folder',
        (tester) async {
      final storage = FakeCloudStorage(
        children: const {kRootFolderId: <CloudNode>[]},
      );
      await tester.pumpWidget(_harness(
        CloudFolderGrid(storage: storage, folderId: kRootFolderId),
      ));
      // Wait for the initial stream emit + one build.
      await tester.pumpAndSettle();
      expect(find.text('Empty folder'), findsOneWidget);
    });

    testWidgets('renders one tile per node returned by the stream',
        (tester) async {
      final storage = FakeCloudStorage(children: {
        kRootFolderId: [
          makeFolder('Photos'),
          makeFile('report.pdf'),
          makeLink('Docs'),
        ],
      });
      await tester.pumpWidget(_harness(
        CloudFolderGrid(storage: storage, folderId: kRootFolderId),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
    });

    testWidgets('tapping a folder calls onFolderTap with the tapped node',
        (tester) async {
      final storage = FakeCloudStorage(children: {
        kRootFolderId: [makeFolder('Photos')],
      });
      CloudFolder? tapped;
      await tester.pumpWidget(_harness(
        CloudFolderGrid(
          storage: storage,
          folderId: kRootFolderId,
          onFolderTap: (folder) => tapped = folder,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photos'));
      expect(tapped, isNotNull);
      expect(tapped!.name, 'Photos');
    });

    testWidgets(
        'in selection mode tap fires onNodeToggleSelection, not onFolderTap',
        (tester) async {
      final storage = FakeCloudStorage(children: {
        kRootFolderId: [makeFolder('Photos')],
      });
      var folderTapCount = 0;
      CloudNode? toggled;
      await tester.pumpWidget(_harness(
        CloudFolderGrid(
          storage: storage,
          folderId: kRootFolderId,
          selectionMode: true,
          selectedNodeIds: const <String>{},
          onFolderTap: (_) => folderTapCount++,
          onNodeToggleSelection: (n) => toggled = n,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(folderTapCount, 0);
      expect(toggled, isNotNull);
      expect(toggled!.name, 'Photos');
    });

    testWidgets('respects the passed sort — descending by name',
        (tester) async {
      final storage = FakeCloudStorage(children: {
        kRootFolderId: [
          makeFile('apple.pdf'),
          makeFile('banana.pdf'),
          makeFile('cherry.pdf'),
        ],
      });
      await tester.pumpWidget(_harness(
        CloudFolderGrid(
          storage: storage,
          folderId: kRootFolderId,
          sort: const CloudNodeSort(ascending: false),
        ),
      ));
      await tester.pumpAndSettle();
      // The three items land in a single row of the default 3-column
      // grid, so y coordinates match. Sort verification uses the
      // widget tree traversal order — the GridView renders children in
      // sort order, so filtering the visible Text widgets to just our
      // filenames yields the expected sequence.
      final names = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s.endsWith('.pdf'))
          .toList();
      expect(names, ['cherry.pdf', 'banana.pdf', 'apple.pdf']);
    });

    testWidgets('emits updated content when the stream pushes a new list',
        (tester) async {
      final storage = FakeCloudStorage(children: {
        kRootFolderId: [makeFile('first.pdf')],
      });
      await tester.pumpWidget(_harness(
        CloudFolderGrid(storage: storage, folderId: kRootFolderId),
      ));
      await tester.pumpAndSettle();
      expect(find.text('first.pdf'), findsOneWidget);
      expect(find.text('second.pdf'), findsNothing);

      storage.setChildren(kRootFolderId, [makeFile('second.pdf')]);
      await tester.pumpAndSettle();
      expect(find.text('first.pdf'), findsNothing);
      expect(find.text('second.pdf'), findsOneWidget);
    });
  });
}

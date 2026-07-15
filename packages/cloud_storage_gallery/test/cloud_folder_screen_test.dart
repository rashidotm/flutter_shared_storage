import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_cloud_storage.dart';

/// Records how many times a route push was requested — used to prove
/// that in-place folder navigation does NOT push new routes.
class _PushCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Ignore the initial route push at mount time.
    if (previousRoute != null) pushes++;
    super.didPush(route, previousRoute);
  }
}

Widget _harness(
  Widget child, {
  NavigatorObserver? observer,
}) =>
    MaterialApp(
      navigatorObservers: [if (observer != null) observer],
      localizationsDelegates: const [
        CloudGalleryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: CloudGalleryLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

/// Simulates a hardware/OS back button press. PopScope receives the
/// pop invocation and decides whether to consume it.
Future<void> _pressSystemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('CloudFolderScreen — AppBar slot', () {
    testWidgets('renders the consumer-supplied AppBar', (tester) async {
      final storage = FakeCloudStorage(
        children: const {kRootFolderId: <CloudNode>[]},
      );
      await tester.pumpWidget(_harness(
        CloudFolderScreen(
          storage: storage,
          appBar: AppBar(title: const Text('My files')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('My files'), findsOneWidget);
    });

    testWidgets('renders no AppBar when the appBar param is null',
        (tester) async {
      final storage = FakeCloudStorage(
        children: const {kRootFolderId: <CloudNode>[]},
      );
      await tester.pumpWidget(_harness(
        CloudFolderScreen(storage: storage),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
    });
  });

  group('CloudFolderScreen — path bar', () {
    testWidgets('renders the path bar with back / up buttons',
        (tester) async {
      final storage = FakeCloudStorage(
        children: const {kRootFolderId: <CloudNode>[]},
      );
      await tester.pumpWidget(_harness(
        CloudFolderScreen(storage: storage),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CloudPathBar), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.arrow_back),
          findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.arrow_upward),
          findsOneWidget);
    });

    testWidgets(
      'back and up are disabled at root with no history',
      (tester) async {
        final storage = FakeCloudStorage(
          children: const {kRootFolderId: <CloudNode>[]},
        );
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
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
      },
    );
  });

  group('CloudFolderScreen — in-place folder navigation', () {
    testWidgets(
      'tapping a subfolder updates the grid without pushing a route',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFolder('Photos'), makeFile('root-file.pdf')],
          'F-Photos': [makeFile('vacation.jpg')],
        });
        final observer = _PushCounter();
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
          observer: observer,
        ));
        await tester.pumpAndSettle();

        // Root shows its contents.
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('root-file.pdf'), findsOneWidget);
        expect(find.text('vacation.jpg'), findsNothing);

        await tester.tap(find.text('Photos'));
        await tester.pumpAndSettle();

        // Subfolder contents replace root's.
        expect(find.text('root-file.pdf'), findsNothing);
        expect(find.text('vacation.jpg'), findsOneWidget);
        // And no new Navigator route was pushed.
        expect(observer.pushes, 0);
      },
    );

    testWidgets(
      'path bar back walks internal history',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFolder('Photos')],
          'F-Photos': [makeFile('vacation.jpg')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Photos'));
        await tester.pumpAndSettle();
        expect(find.text('vacation.jpg'), findsOneWidget);

        await tester
            .tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('vacation.jpg'), findsNothing);
      },
    );

    testWidgets(
      'path bar up walks the parent chain',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFolder('Photos')],
          'F-Photos': [makeFile('vacation.jpg')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Photos'));
        await tester.pumpAndSettle();

        // At this point up should be enabled — we're one level down.
        final up = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_upward),
        );
        expect(up.onPressed, isNotNull);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
        await tester.pumpAndSettle();
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('vacation.jpg'), findsNothing);
      },
    );
  });

  group('CloudFolderScreen — FABs', () {
    testWidgets('shows the four browse FABs by default', (tester) async {
      final storage = FakeCloudStorage(
        children: const {kRootFolderId: <CloudNode>[]},
      );
      await tester.pumpWidget(_harness(
        CloudFolderScreen(storage: storage),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.checklist), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsOneWidget);
      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });

    testWidgets('hides all FABs when readOnly is true', (tester) async {
      final storage = FakeCloudStorage(
        children: const {kRootFolderId: <CloudNode>[]},
      );
      await tester.pumpWidget(_harness(
        CloudFolderScreen(storage: storage, readOnly: true),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('CloudFolderScreen — selection mode', () {
    testWidgets(
      'tapping the Select FAB enters selection mode and swaps FABs',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFile('a.pdf'), makeFile('b.pdf')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.checklist));
        await tester.pumpAndSettle();

        // Browse FABs are gone.
        expect(find.byIcon(Icons.checklist), findsNothing);
        expect(find.byIcon(Icons.create_new_folder), findsNothing);
        // Selection FABs are shown — both disabled since nothing is
        // selected yet.
        expect(find.byIcon(Icons.drive_file_move), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
        // Path bar is replaced with the selection header — the close
        // (X) button is visible.
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets(
      'bulk-action FABs are disabled while nothing is selected',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFile('a.pdf')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.checklist));
        await tester.pumpAndSettle();

        final moveFab = tester.widget<FloatingActionButton>(
          find.ancestor(
            of: find.byIcon(Icons.drive_file_move),
            matching: find.byType(FloatingActionButton),
          ),
        );
        final deleteFab = tester.widget<FloatingActionButton>(
          find.ancestor(
            of: find.byIcon(Icons.delete_outline),
            matching: find.byType(FloatingActionButton),
          ),
        );
        expect(moveFab.onPressed, isNull);
        expect(deleteFab.onPressed, isNull);
      },
    );

    testWidgets(
      'X closes selection mode and restores the browse FABs',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFile('a.pdf')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.checklist));
        await tester.pumpAndSettle();
        // Close (X) is the only Icons.close on screen — the selection
        // header's leading button.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        // Browse FABs are back.
        expect(find.byIcon(Icons.checklist), findsOneWidget);
        expect(find.byIcon(Icons.drive_file_move), findsNothing);
      },
    );
  });

  group('CloudFolderScreen — PopScope back handling', () {
    testWidgets(
      'system back exits selection mode when active',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFile('a.pdf')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.checklist));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drive_file_move), findsOneWidget);

        await _pressSystemBack(tester);
        // Back in browse mode.
        expect(find.byIcon(Icons.drive_file_move), findsNothing);
        expect(find.byIcon(Icons.checklist), findsOneWidget);
      },
    );

    testWidgets(
      'system back walks internal folder history before propagating',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [makeFolder('Photos')],
          'F-Photos': [makeFile('vacation.jpg')],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Photos'));
        await tester.pumpAndSettle();
        expect(find.text('vacation.jpg'), findsOneWidget);

        await _pressSystemBack(tester);
        // Back at root, not off-route.
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('vacation.jpg'), findsNothing);
      },
    );
  });

  group('CloudFolderScreen — sort menu', () {
    testWidgets(
      'sort menu opens and applies the chosen field',
      (tester) async {
        final storage = FakeCloudStorage(children: {
          kRootFolderId: [
            makeFile('apple.pdf'),
            makeFile('banana.pdf'),
            makeFile('cherry.pdf'),
          ],
        });
        await tester.pumpWidget(_harness(
          CloudFolderScreen(storage: storage),
        ));
        await tester.pumpAndSettle();

        // Default sort: name ascending → visible order apple, banana,
        // cherry.
        List<String> visibleFileLabels() => tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .where((s) => s.endsWith('.pdf'))
            .toList();
        expect(
          visibleFileLabels(),
          ['apple.pdf', 'banana.pdf', 'cherry.pdf'],
        );

        // Open the sort menu (the trailing icon in the path bar) and
        // flip direction. The direction-toggle item's label reflects
        // the CURRENT direction: while ascending, it's labeled
        // "Ascending" — tapping it flips to descending.
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();
        // Narrow to the CheckedPopupMenuItem to avoid the popup's
        // hit-test warning from overlapping route/overlay boxes.
        await tester.tap(find.widgetWithText(
          CheckedPopupMenuItem<Object>,
          'Ascending',
        ));
        await tester.pumpAndSettle();

        expect(
          visibleFileLabels(),
          ['cherry.pdf', 'banana.pdf', 'apple.pdf'],
        );
      },
    );
  });
}


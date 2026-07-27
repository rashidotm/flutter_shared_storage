# 0.6.6

**Fix: `pickCloudFolder` primary paint no longer stops at the
bottom SafeArea inset.**

The picker's body is wrapped in `SafeArea(top: false)` so the
list clears the gesture bar and rounded corners. Everything
inside the SafeArea rendered primary, but the space excluded by
the SafeArea below the last row showed the ambient
`theme.scaffoldBackgroundColor` through the Scaffold, breaking
the illusion of a single continuous coloured surface.

Setting `Scaffold.backgroundColor: colorScheme.primary` fills
the excluded inset with the same colour as the list area. The
AppBar and its own background are unaffected.

# 0.6.5

**Fix: `pickCloudFolder` list area no longer flashes back to the
scaffold background when the current folder is empty.**

The 0.6.3 empty-state treatment centered a primary/onPrimary card
on top of the ambient scaffold — so navigating into an empty
subfolder made the primary strip disappear (revealing the
scaffold) and then reappear on the next non-empty folder.
Distracting to move through a tree of mixed empty/populated
folders.

The primary paint is now applied to the whole list area
unconditionally. The empty state is just the "no subfolders" hint
rendered as `onPrimary` text on the same primary background — the
card is gone (a primary card on a primary background would be
invisible anyway) and the surrounding chrome stays visually
stable across every navigation.

# 0.6.4

**Fix: eliminate breadcrumb latency in `pickCloudFolder`.**

The move-to picker's address bar (`CloudFolderBreadcrumb`) was
lagging behind every navigation: each tap on a folder cleared the
breadcrumb until an async chain-walk (`storage.getNode` per
ancestor, sequentially) finished. `CloudFolderScreen` never had
this problem because it keeps the ancestor chain in memory and
passes it into the breadcrumb; the picker just tracked the current
folder id and let the breadcrumb self-load.

The picker now mirrors the main screen: it seeds a synthetic root
chain on entry, extends the chain by one when the user taps into
a subfolder, and truncates it when the user taps a breadcrumb
segment. The chain is passed to `CloudFolderBreadcrumb` on every
build, so the address bar updates on the same frame as the tap —
no round-trip to storage required.

# 0.6.3

**Changed: empty-state and folder-picker chrome now use
`primary` / `onPrimary` instead of chasing `onSurface`.**

Supersedes the 0.6.1 and 0.6.2 approach of forcing `onSurface`
into the empty labels, breadcrumb, and picker list. That was
fragile against consumer themes that bake colors into
`textTheme`, and it left the picker looking indistinguishable
from any other scaffold background.

New visual:

* **Empty folder** (`CloudFolderGrid`) — a centered `Card` with
  `colorScheme.primary` background and `onPrimary` label text.
* **Empty picker** (`pickCloudFolder`) — same card treatment for
  the "no subfolders" hint, with an outer horizontal padding of
  50 px so the card keeps at least that much clearance from each
  screen edge on any device.
* **Non-empty picker** — the whole list area is painted with
  `colorScheme.primary`; each folder tile's icon, name, and
  chevron render in `onPrimary`.
* **Picker path bar** — the breadcrumb strip at the top of the
  picker is now painted `primary` too, spans the full row width,
  and its segments + chevrons render in `onPrimary`. The root
  segment stays pinned to the row's leading edge regardless of
  how deep the current folder is, so the picker's chrome reads
  as one continuous coloured surface with a stable start point.
* **Breadcrumb separator direction (bug fix)** — the widget was
  manually swapping `Icons.chevron_right` for `Icons.chevron_left`
  in RTL. Both of those icons carry `matchTextDirection: true`, so
  `Icon` was auto-mirroring on top of the swap, ending up with `>`
  in RTL. Now unconditionally `Icons.chevron_right`; `Icon` picks
  the correct glyph per direction. Affects both `CloudFolderScreen`
  and `pickCloudFolder`.
* **Breadcrumb API** — `CloudFolderBreadcrumb` gains two optional
  params:
  * `foregroundColor` — when supplied, overrides both the segment
    text color and the separator chevron color. When null the
    widget keeps its previous behavior of inheriting from
    `textTheme.titleMedium` and the ambient `IconTheme`.
  * `scrollToCurrent` (default `true`) — when false, disables the
    auto-scroll-to-end behavior so the root segment stays at the
    row's leading edge regardless of depth. Long chains stay
    horizontally scrollable.
  The main folder screen's path bar (via `CloudPathBar`) does not
  pass either param and is unchanged.

# 0.6.2

**Fix: extends the 0.6.1 onSurface fix to the folder picker and the
breadcrumb.**

Two more text sites were still inheriting from the ambient text
theme and losing to a consumer's baked-in colors:

* `CloudFolderBreadcrumb` — every segment was derived from
  `textTheme.titleMedium` alone. Now merged with
  `colorScheme.onSurface`. Affects the picker's title row AND
  `CloudPathBar` in the main folder screen.
* `pickCloudFolder`'s folder list — each `ListTile.title` was a
  bare `Text(folder.name)`. Now passes an explicit `onSurface`
  style. `ListTile` normally applies `onSurface` itself in M3, but
  a consumer `ListTileTheme` with an override can shadow that;
  passing the color directly bypasses either path.

# 0.6.1

**Fix: empty-state labels now follow `ColorScheme.onSurface`.**

The "Empty folder" label on `CloudFolderGrid` and the
"tap Move here to pick this one" hint in `pickCloudFolder` were
rendered as bare `Text(...)` widgets. That inherited the ambient
`DefaultTextStyle`, so a consumer whose `textTheme` bakes in colors
(the common case with `GoogleFonts.xxxTextTheme(...)` and similar
patterns) would shadow their own `ColorScheme.onSurface` — the
labels would ignore the scheme override and use whatever color was
baked into the text theme.

Both call sites now pass `style: TextStyle(color: onSurface)`
directly, so the scheme wins.

# 0.6.0

**New: upload source picker on the Upload FAB.** Tapping the FAB now
opens a bottom sheet with two options:

* **Photos & videos** — routes the picker through `FileType.media`,
  which uses the system photo picker (Android's PhotoPickerV2, iOS's
  PHPickerViewController) so images and videos from the camera roll
  are always shown.
* **Files** — the generic document picker (previous behavior).

Motivated by the fact that on some devices the generic file picker
doesn't reliably surface the photo library. Both paths funnel back
into the same thumbnail-generation + upload pipeline, so progress
dialogs, cancel behavior, and the Firestore-doc rollback all work
unchanged.

**Localization:** 5 new strings under a new "Upload source sheet"
section (`uploadSourceSheetTitle`, `uploadSourcePhotos` +
`uploadSourcePhotosSubtitle`, `uploadSourceFiles` +
`uploadSourceFilesSubtitle`). Provided in EN and AR.

**Breaking (custom l10n only):** consumers who ship their own
`CloudGalleryLocalizations` impl need to add the five new getters.
Consumers relying on the built-in `En`/`Ar` implementations are
unaffected.

# 0.5.0

**New: client-side sort for grid contents.**

* Two new public types (both exported from the barrel):
  * `CloudNodeSortField` — `name` / `createdAt` / `updatedAt` /
    `size` / `type`.
  * `CloudNodeSort` — immutable `(field, ascending, foldersFirst)`
    triple with `copyWith`. Defaults to name ascending, folders
    first.
* Helper: `sortCloudNodes(nodes, sort)` — pure function, stable
  tiebreak by name, no mutation.
* New optional param on `CloudFolderGrid`: `sort`. Applied
  client-side inside the `StreamBuilder`, no Firestore index
  required on the consumer's project.
* New optional param on `CloudPathBar`: `trailing: List<Widget>`.
  Rendered after the breadcrumb — text-direction-aware. Use it to
  slot your own icon buttons alongside the built-in nav chrome.
* Sort menu wired into `CloudFolderScreen`: a `PopupMenuButton` in
  the path bar's new trailing slot with radio field options, a
  direction toggle, and a folders-first toggle. State is
  session-scoped (resets when the widget is recreated).

**Localization:** 9 new strings under a "Sort menu" section
(`sortTooltip`, `sortByHeader`, five `sortFieldXxx` labels,
`sortDirectionAscending` / `Descending`, `sortFoldersFirst`).
Provided in EN and AR.

**Breaking (custom l10n only):** consumers who ship their own
`CloudGalleryLocalizations` impl need to add the nine new getters.
Consumers relying on the built-in `Cn`/`Ar` implementations are
unaffected.

# 0.4.0

**New: pinch-to-zoom on the grid.** Two-finger pinch changes the
column count in real time. Column-count changes crossfade with a
scale transition (220 ms). Single-finger scroll is not intercepted
— only gestures with two or more pointers resize.

* `CloudFolderGrid` is now a `StatefulWidget` owning the current
  column count. Two new optional params bound the pinch range:
  * `minCrossAxisCount` — default `2`.
  * `maxCrossAxisCount` — default `5`.
* Once the user pinches, the internal state takes over. Rebuilds
  with a different `crossAxisCount` param are ignored — the state
  is authoritative.

**Fix: folder tile no longer overflows at small tile sizes.**
The tile was a `Column` with a fixed 56 dp icon + label; at the
tighter column counts pinch-to-zoom now allows, the tile height
dropped below the intrinsic column height and Flutter surfaced
the yellow/black overflow indicator. `_FolderTile` now mirrors
the `_FileTile` / `_LinkTile` layout — icon centered in a `Stack`,
name as a `PositionedDirectional` bottom overlay. The 56 dp icon
size is unchanged; only the label placement moved.

# 0.3.0

**Breaking:** `CloudFolderScreen` is no longer a `Scaffold`.

The widget is now embeddable — put it inside a tab, a split-view
pane, a bottom sheet, or your own `Scaffold` as needed.

Consequences:

* If you were using `CloudFolderScreen` as the direct `home:` of a
  `MaterialApp`, wrap it in a `Scaffold`:
  ```dart
  // Before
  home: CloudFolderScreen(storage: storage, appBar: AppBar(...));

  // After
  home: Scaffold(
    appBar: AppBar(...),
    body: CloudFolderScreen(storage: storage),
  );
  ```
* `ScaffoldMessenger.of(context)` inside your callbacks now inherits
  from the ancestor `Scaffold` (or `MaterialApp`'s default), not from
  ours. SnackBars still work if any of those is present.
* FABs moved from `Scaffold.floatingActionButton` into a
  `Stack` + `PositionedDirectional` overlay inside the widget's own
  body. Same visual bottom-end placement; no external Scaffold slot
  consumed.

The `appBar:` slot is retained for the "embed with a section-scoped
top bar" case (tabs, etc.) — it now renders as the first child of
the internal `Column`.

# 0.2.0

Structural rework of `CloudFolderScreen`. Direct users of the widget
need to adapt — see the "Breaking" section below.

**New:**

* `CloudFolderScreen` now takes an optional `appBar: PreferredSizeWidget?`.
  Consumers wire whatever they need (title, actions, outer-Navigator
  back button); pass `null` and the widget renders with no AppBar at
  all (the path bar becomes the top of the screen).
* New `CloudPathBar` widget rendered as the first row of the body,
  below the consumer AppBar. Layout: `[back] [up] <breadcrumb>`. Back
  walks an internal history stack of chain snapshots (no refetch);
  Up drops the last segment of the current path. Both disable at
  their boundaries. Breadcrumb segments stay tappable for direct
  jump-to-ancestor navigation. Exported from the barrel for
  consumers building custom screens.

**Breaking behavioral changes to `CloudFolderScreen`:**

* Folder navigation is now **in-place**. Tapping a subfolder updates
  the current folder in state instead of pushing a new
  `CloudFolderScreen` route. Only media viewer opens still push a
  route. If you were relying on `Navigator.pop()` to go back one
  folder level, that no longer works — use the built-in path bar
  back button or the OS back button (which is intercepted via
  `PopScope`).
* **AppBar is no longer built for you.** The widget's own breadcrumb
  AppBar and selection AppBar are both removed. Pass `appBar:` if
  you want an AppBar; the path bar (in browse mode) or the selection
  header (in selection mode) both live below whatever you pass.
* Selection info (the "N selected" title and close button) has moved
  from the AppBar's leading + title slots into the same in-body slot
  as the path bar. Bulk-action FABs are unchanged.

**Migration:**

```dart
// Before
CloudFolderScreen(storage: storage, folderId: root);

// After — same, plus your AppBar if you want one
CloudFolderScreen(
  storage: storage,
  folderId: root,
  appBar: AppBar(title: const Text('My files')),
);
```

# 0.1.2

Selection & progress polish.

* **Selection-mode UI moved to the FAB slot.** Bulk Move-To and Bulk
  Delete used to live as `AppBar` actions. They're now
  `FloatingActionButton`s in the same position the browse-mode FABs
  occupied, so the user's thumb doesn't have to jump to the top of
  the screen after a long-press.
* **Per-item progress in bulk operations.** Both `CloudBulkProgressDialog`
  (deletes / moves) and `CloudBatchUploadDialog` now render a
  scrollable list of items under the total progress bar. Each row
  shows its own state icon (pending / running / done / failed).
  Upload rows also show byte-level progress bars while a file is
  streaming.
* **Two-phase upload flow.** After the file picker closes, a
  "Preparing files" dialog now shows per-file progress during
  thumbnail generation. On large batches this used to be a silent
  multi-second gap before the upload dialog appeared. Uploads only
  start after all thumbnails are ready, so a cancel during the
  prep phase is a clean cancel.
* **BREAKING (`CloudBulkProgressDialog`):** the constructor now
  requires an `itemLabel: (T) => String` callback so the dialog can
  render each item's display name in the list. If you use this
  widget directly, add `itemLabel: (item) => item.name` (or any
  identifier your item type exposes).

Also:

* `CloudFolderScreen` gained a new `preparingUploadsTitle`
  localization slot (EN / AR provided).
* Sibling dep `cloud_storage_platform_interface` bumped to `^0.1.2`.

# 0.1.1

* **`file_picker` bumped `^8` → `^11`.** API change: use
  `FilePicker.pickFiles(...)` (static) instead of the removed
  `FilePicker.platform.pickFiles(...)`. Package internals updated;
  consumers using the gallery widgets don't need changes.
* **`share_plus` bumped `^10` → `^11`.** API change: switched to
  `SharePlus.instance.share(ShareParams(files: ..., subject: ...))`.
  The legacy `Share.shareXFiles(...)` was deprecated. Only affects
  the "open in external app" fallback flow.
* `mime` bumped `^1` → `^2`.
* `chewie` bumped `^1.8.5` → `^1.13.0`. Deliberately capped below 1.14
  (which pulls in `win32 ^6` via `wakelock_plus 1.6+` and conflicts
  with `share_plus <13` and `file_picker <12`).
* `path_provider` `^2.1.6`.
* Sibling dep `cloud_storage_platform_interface` bumped to `^0.1.1`.
* Removed unnecessary library-name declaration.

# 0.1.0

Initial release. Ready-made Flutter widgets on top of `cloud_storage`.

Widgets:

* `CloudFolderScreen` — drop-in file-manager screen. Breadcrumb app bar,
  thumbnail grid, long-press context menu, four floating action buttons
  (Select / Create folder / Add link / Upload file), full-featured
  action dialogs.
* `CloudMediaViewer` — headless swipeable photo/video viewer. Videos
  stream from the network on first play and cache locally for instant
  replay.
* `CloudFolderGrid` — reactive grid tile view of a folder.
* `CloudFolderBreadcrumb` — self-loading or externally-supplied
  breadcrumb.
* `CloudUploadDialog`, `CloudBatchUploadDialog`, `CloudBulkProgressDialog`
  — modal progress dialogs.
* `pickCloudFolder(...)` — modal folder picker.
* `generateThumbnails(File)` — helper that produces 256 px thumb + 1024 px
  preview JPEGs from images and videos.

Features:

* Selection mode with bulk delete / move.
* Custom thumbnail support for files and links (including videos when
  the auto-generated one isn't good enough).
* External-app open flow for non-media files (PDFs, docs, ...) with
  fallback to the OS share sheet.
* URL links open in an external browser via `url_launcher`.
* Read-only mode hides all write-oriented UI.
* Localization via `CloudGalleryLocalizations` delegate — English and
  Arabic strings included; RTL layouts respected throughout.
* Every widget derives its colors, text styles, and directionality
  from the ambient `Theme` / `Directionality`.

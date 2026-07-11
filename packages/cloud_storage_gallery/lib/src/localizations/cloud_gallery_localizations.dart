import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cloud_gallery_localizations_ar.dart';
import 'cloud_gallery_localizations_en.dart';

/// Translatable strings used by the `cloud_storage_gallery` widgets.
///
/// Add the [delegate] to your app's `MaterialApp.localizationsDelegates`.
/// The widgets will pick the appropriate translation based on the app's
/// current [Locale]:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     CloudGalleryLocalizations.delegate,
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///     GlobalCupertinoLocalizations.delegate,
///   ],
///   supportedLocales: CloudGalleryLocalizations.supportedLocales,
///   locale: const Locale('ar'),
///   home: CloudFolderScreen(storage: myStorage),
/// );
/// ```
///
/// To add a locale, subclass [CloudGalleryLocalizations] and register your
/// own delegate.
abstract class CloudGalleryLocalizations {
  const CloudGalleryLocalizations();

  /// Registered languages built into the package.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  /// Delegate to add to `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<CloudGalleryLocalizations> delegate =
      _CloudGalleryLocalizationsDelegate();

  /// Returns the localizations for the current [BuildContext].
  ///
  /// If the delegate isn't registered on the [MaterialApp] (or the resolved
  /// locale isn't supported), falls back to English.
  static CloudGalleryLocalizations of(BuildContext context) {
    return Localizations.of<CloudGalleryLocalizations>(
          context,
          CloudGalleryLocalizations,
        ) ??
        const CloudGalleryLocalizationsEn();
  }

  // ── Breadcrumb ─────────────────────────────────────────────────────────

  String get rootLabel;

  // ── FAB tooltips ───────────────────────────────────────────────────────

  String get createFolderTooltip;
  String get uploadFileTooltip;
  String get addLinkTooltip;

  // ── Popup menu items ───────────────────────────────────────────────────

  String get menuOpen;
  String get menuDownload;
  String get menuRename;
  String get menuMoveTo;
  String get menuInfo;
  String get menuDelete;
  String get menuSelect;
  String get menuSetThumbnail;

  // ── Selection mode ─────────────────────────────────────────────────────

  /// AppBar title in selection mode, e.g. "3 selected".
  String selectionCountLabel(int count);

  /// Confirmation-dialog title for bulk delete, e.g. "Delete 3 items?".
  String deleteMultipleTitle(int count);

  // ── Common button labels ───────────────────────────────────────────────

  String get buttonCancel;
  String get buttonCreate;
  String get buttonRename;
  String get buttonDelete;
  String get buttonClose;
  String get buttonMoveHere;

  // ── New folder dialog ──────────────────────────────────────────────────

  String get newFolderTitle;

  // ── New link dialog ────────────────────────────────────────────────────

  String get newLinkTitle;
  String get linkNameLabel;
  String get linkUrlLabel;

  /// Snackbar shown when the OS can't launch the tapped URL.
  String linkOpenFailedSnack(String url);

  /// Info-dialog row label for a link's URL.
  String get infoLabelUrl;

  // ── Rename dialog ──────────────────────────────────────────────────────

  String get renameTitle;

  // ── Delete confirmation ────────────────────────────────────────────────

  /// Title of the delete confirmation dialog, e.g. "Delete report.pdf?".
  String deleteConfirmTitle(String name);
  String get deleteFolderBody;
  String get deleteFileBody;

  // ── Info dialog ────────────────────────────────────────────────────────

  String get infoLabelName;
  String get infoLabelType;
  String get infoLabelPath;
  String get infoLabelCreated;
  String get infoLabelUpdated;
  String get infoLabelMime;
  String get infoLabelSize;
  String get infoTypeFolder;
  String get infoTypeFile;

  // ── Download flow ──────────────────────────────────────────────────────

  String downloadingSnack(String name);
  String downloadFailedSnack(Object error);

  // ── Folder picker ──────────────────────────────────────────────────────

  String get moveToTitle;

  /// Empty-state hint in the folder picker, formatted with the "Move here"
  /// button label so the translation can reference it inline.
  String moveHereEmptyHint(String moveHereLabel);

  // ── Upload dialog ──────────────────────────────────────────────────────

  String get uploadingTitle;

  /// Dialog title shown BEFORE uploads start, while the gallery is
  /// generating thumbnails and preparing each file. On large batches
  /// this phase can take a few seconds per file — without a dialog the
  /// user would see nothing after picking files.
  String get preparingUploadsTitle;

  /// AppBar / dialog title for bulk delete progress.
  String get deletingTitle;

  /// AppBar / dialog title for bulk move progress.
  String get movingTitle;

  /// Dialog title while a file is being downloaded before being handed off
  /// to the OS default handler.
  String get openingTitle;

  /// Generic aggregate-progress label, e.g. "3 of 10 complete". Reused
  /// across upload / delete / move batch dialogs.
  String bulkProgressLabel(int completed, int total);

  // ── Grid states ────────────────────────────────────────────────────────

  String get emptyFolder;
  String gridErrorLabel(Object error);

  // ── Byte units ─────────────────────────────────────────────────────────

  String get unitBytes;
  String get unitKilobytes;
  String get unitMegabytes;
  String get unitGigabytes;
}

class _CloudGalleryLocalizationsDelegate
    extends LocalizationsDelegate<CloudGalleryLocalizations> {
  const _CloudGalleryLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return CloudGalleryLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<CloudGalleryLocalizations> load(Locale locale) {
    return SynchronousFuture(_resolve(locale));
  }

  CloudGalleryLocalizations _resolve(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return const CloudGalleryLocalizationsAr();
      case 'en':
      default:
        return const CloudGalleryLocalizationsEn();
    }
  }

  @override
  bool shouldReload(_CloudGalleryLocalizationsDelegate old) => false;
}

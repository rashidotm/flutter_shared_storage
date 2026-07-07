import 'cloud_gallery_localizations.dart';

/// English strings for the gallery widgets. Also serves as the fallback
/// when no delegate is registered or the resolved locale is unsupported.
class CloudGalleryLocalizationsEn extends CloudGalleryLocalizations {
  const CloudGalleryLocalizationsEn();

  @override
  String get rootLabel => 'Home';

  @override
  String get createFolderTooltip => 'Create folder';
  @override
  String get uploadFileTooltip => 'Upload file';
  @override
  String get addLinkTooltip => 'Add link';

  @override
  String get menuOpen => 'Open';
  @override
  String get menuDownload => 'Download';
  @override
  String get menuRename => 'Rename';
  @override
  String get menuMoveTo => 'Move to…';
  @override
  String get menuInfo => 'Info';
  @override
  String get menuDelete => 'Delete';
  @override
  String get menuSelect => 'Select';
  @override
  String get menuSetThumbnail => 'Set thumbnail';

  @override
  String selectionCountLabel(int count) => '$count selected';
  @override
  String deleteMultipleTitle(int count) => 'Delete $count items?';

  @override
  String get buttonCancel => 'Cancel';
  @override
  String get buttonCreate => 'Create';
  @override
  String get buttonRename => 'Rename';
  @override
  String get buttonDelete => 'Delete';
  @override
  String get buttonClose => 'Close';
  @override
  String get buttonMoveHere => 'Move here';

  @override
  String get newFolderTitle => 'New folder';
  @override
  String get newLinkTitle => 'New link';
  @override
  String get linkNameLabel => 'Name';
  @override
  String get linkUrlLabel => 'URL';
  @override
  String linkOpenFailedSnack(String url) => 'Could not open link: $url';
  @override
  String get infoLabelUrl => 'URL';
  @override
  String get renameTitle => 'Rename';

  @override
  String deleteConfirmTitle(String name) => 'Delete $name?';
  @override
  String get deleteFolderBody =>
      'This will delete the folder and all its contents. This cannot be undone.';
  @override
  String get deleteFileBody => 'This cannot be undone.';

  @override
  String get infoLabelName => 'Name';
  @override
  String get infoLabelType => 'Type';
  @override
  String get infoLabelPath => 'Path';
  @override
  String get infoLabelCreated => 'Created';
  @override
  String get infoLabelUpdated => 'Updated';
  @override
  String get infoLabelMime => 'MIME';
  @override
  String get infoLabelSize => 'Size';
  @override
  String get infoTypeFolder => 'Folder';
  @override
  String get infoTypeFile => 'File';

  @override
  String downloadingSnack(String name) => 'Downloading $name…';
  @override
  String downloadFailedSnack(Object error) => 'Download failed: $error';

  @override
  String get moveToTitle => 'Move to…';
  @override
  String moveHereEmptyHint(String moveHereLabel) =>
      'No subfolders. Tap "$moveHereLabel" to pick this one.';

  @override
  String get uploadingTitle => 'Uploading';
  @override
  String get deletingTitle => 'Deleting';
  @override
  String get movingTitle => 'Moving';
  @override
  String get openingTitle => 'Opening';

  @override
  String bulkProgressLabel(int completed, int total) =>
      '$completed of $total complete';

  @override
  String get emptyFolder => 'Empty folder';
  @override
  String gridErrorLabel(Object error) => 'Error: $error';

  @override
  String get unitBytes => 'B';
  @override
  String get unitKilobytes => 'KB';
  @override
  String get unitMegabytes => 'MB';
  @override
  String get unitGigabytes => 'GB';
}

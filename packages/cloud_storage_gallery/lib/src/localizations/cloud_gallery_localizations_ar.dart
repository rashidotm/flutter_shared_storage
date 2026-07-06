import 'cloud_gallery_localizations.dart';

/// Arabic strings for the gallery widgets.
class CloudGalleryLocalizationsAr extends CloudGalleryLocalizations {
  const CloudGalleryLocalizationsAr();

  @override
  String get rootLabel => 'الرئيسية';

  @override
  String get createFolderTooltip => 'إنشاء مجلد';
  @override
  String get uploadFileTooltip => 'رفع ملف';

  @override
  String get menuOpen => 'فتح';
  @override
  String get menuDownload => 'تنزيل';
  @override
  String get menuRename => 'إعادة تسمية';
  @override
  String get menuMoveTo => 'نقل إلى…';
  @override
  String get menuInfo => 'معلومات';
  @override
  String get menuDelete => 'حذف';

  @override
  String get buttonCancel => 'إلغاء';
  @override
  String get buttonCreate => 'إنشاء';
  @override
  String get buttonRename => 'إعادة تسمية';
  @override
  String get buttonDelete => 'حذف';
  @override
  String get buttonClose => 'إغلاق';
  @override
  String get buttonMoveHere => 'نقل هنا';

  @override
  String get newFolderTitle => 'مجلد جديد';
  @override
  String get renameTitle => 'إعادة تسمية';

  @override
  String deleteConfirmTitle(String name) => 'حذف $name؟';
  @override
  String get deleteFolderBody =>
      'سيؤدي هذا إلى حذف المجلد وجميع محتوياته. لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get deleteFileBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get infoLabelName => 'الاسم';
  @override
  String get infoLabelType => 'النوع';
  @override
  String get infoLabelPath => 'المسار';
  @override
  String get infoLabelCreated => 'تاريخ الإنشاء';
  @override
  String get infoLabelUpdated => 'آخر تحديث';
  @override
  String get infoLabelMime => 'نوع MIME';
  @override
  String get infoLabelSize => 'الحجم';
  @override
  String get infoTypeFolder => 'مجلد';
  @override
  String get infoTypeFile => 'ملف';

  @override
  String downloadingSnack(String name) => 'جارٍ تنزيل $name…';
  @override
  String downloadFailedSnack(Object error) => 'فشل التنزيل: $error';

  @override
  String get moveToTitle => 'نقل إلى…';
  @override
  String moveHereEmptyHint(String moveHereLabel) =>
      'لا توجد مجلدات فرعية. اضغط على "$moveHereLabel" لاختيار هذا المجلد.';

  @override
  String get uploadingTitle => 'جارٍ الرفع';

  @override
  String batchUploadingLabel(int completed, int total) =>
      'اكتمل $completed من $total';

  @override
  String get emptyFolder => 'مجلد فارغ';
  @override
  String gridErrorLabel(Object error) => 'خطأ: $error';

  @override
  String get unitBytes => 'ب';
  @override
  String get unitKilobytes => 'ك.ب';
  @override
  String get unitMegabytes => 'م.ب';
  @override
  String get unitGigabytes => 'ج.ب';
}

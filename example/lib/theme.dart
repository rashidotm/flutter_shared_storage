import 'package:flutter/material.dart';

class CustomTheme {
  const CustomTheme({
    required this.themeBackgroundColor,
    required this.onThemeBackgroundColor,
    required this.secondary,
    required this.onSecondary,
    required this.onSurface,
    required this.iconColor,
    required this.iconSplashColor,
    required this.iconMainFillColor,
    required this.iconMainShadeColor,
    required this.iconSecondaryFillColor,
    required this.iconSecondaryShadeColor,
    required this.iconSkinColor,
    required this.iconSkinShadeColor,
    required this.iconBalloonColor,
    required this.iconBalloonShadeColor,
    required this.iconPaperColor,
    required this.iconPaperShadeColor,
    required this.iconBorderColor,
    required this.iconTitleColor,
    required this.appBarBgColor,
    required this.appBarTextColor,
    required this.snackBarBgColor,
    required this.snackBarContentColor,
    required this.scaffoldBackgroundColor,
    required this.dialogBgColor,
    required this.dialogTextColor,
    required this.drawerBgColor,
    required this.selectedTileColor,
    required this.elevatedButtonBgColor,
    required this.elevatedButtonTextColor,
    required this.elevatedButtonBorderColor,
    required this.textButtonColor,
    required this.errorBgColor,
    required this.errorTextColor,
    required this.floatingButtonBgColor,
    required this.floatingButtonContentColor,
    required this.badgeBgColor,
    required this.badgeContentColor,
    required this.recentChangeMainPersonColor,
    required this.recentChangeMaleColor,
    required this.recentChangeFemaleColor,
    required this.recentChangeNewChangeColor,
    required this.recentChangeUpdatingChangeColor,
    required this.sectorBgColor,
    required this.sectorIconColor,
    required this.sectorTextColor,
    required this.sectorToggleBgColor,
    required this.sectorToggleTextColor,
    required this.businessBgColor,
    required this.businessIconColor,
    required this.businessTextColor,
    required this.businessGraphLineColor,
  });

  final Color themeBackgroundColor;
  final Color onThemeBackgroundColor;
  final Color secondary;
  final Color onSecondary;
  final Color onSurface;
  final Color iconColor;
  final Color iconSplashColor;
  final Color iconMainFillColor;
  final Color iconMainShadeColor;
  final Color iconSecondaryFillColor;
  final Color iconSecondaryShadeColor;
  final Color iconSkinColor;
  final Color iconSkinShadeColor;
  final Color iconBalloonColor;
  final Color iconBalloonShadeColor;
  final Color iconPaperColor;
  final Color iconPaperShadeColor;
  final Color iconBorderColor;
  final Color iconTitleColor;
  final Color appBarBgColor;
  final Color appBarTextColor;
  final Color scaffoldBackgroundColor;
  final Color dialogBgColor;
  final Color dialogTextColor;
  final Color drawerBgColor;
  final Color selectedTileColor;
  final Color snackBarBgColor;
  final Color snackBarContentColor;
  final Color elevatedButtonBgColor;
  final Color elevatedButtonTextColor;
  final Color elevatedButtonBorderColor;
  final Color textButtonColor;
  final Color errorBgColor;
  final Color errorTextColor;
  final Color floatingButtonBgColor;
  final Color floatingButtonContentColor;
  final Color badgeBgColor;
  final Color badgeContentColor;
  final Color recentChangeMainPersonColor;
  final Color recentChangeMaleColor;
  final Color recentChangeFemaleColor;
  final Color recentChangeNewChangeColor;
  final Color recentChangeUpdatingChangeColor;
  final Color sectorBgColor;
  final Color sectorIconColor;
  final Color sectorTextColor;
  final Color sectorToggleBgColor;
  final Color sectorToggleTextColor;
  final Color businessBgColor;
  final Color businessIconColor;
  final Color businessTextColor;
  final Color businessGraphLineColor;

  // https://api.flutter.dev/flutter/material/TextTheme-class.html

  ThemeData theme() {
    final appBarFontFamily = 'Rubik';
    final buttonFontFamily = 'Rubik';
    final titleFontFamily = 'Rubik';
    final bodyFontFamily = 'Rubik';
    final textTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      displayMedium: TextStyle(fontSize: 45.0, fontWeight: FontWeight.w700, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      displaySmall: TextStyle(fontSize: 36.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      headlineLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      headlineMedium: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      titleSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: titleFontFamily),
      labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: onThemeBackgroundColor, fontFamily: bodyFontFamily),
      labelMedium: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700, color: onThemeBackgroundColor, fontFamily: bodyFontFamily),
      labelSmall: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: onThemeBackgroundColor, fontFamily: bodyFontFamily),
      bodyLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: onThemeBackgroundColor, fontFamily: bodyFontFamily),
      bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: onThemeBackgroundColor, fontFamily: bodyFontFamily),
      bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: onThemeBackgroundColor, fontFamily: bodyFontFamily),
    );
    final iconTheme = IconThemeData(
      color: iconColor,
      opacity: 1,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFontFamily,
      listTileTheme: ListTileThemeData(
        selectedTileColor: selectedTileColor,
        selectedColor: onThemeBackgroundColor,
        textColor: onThemeBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
        ),
        titleAlignment: ListTileTitleAlignment.top,
        dense: false,
        visualDensity: VisualDensity.compact,
        titleTextStyle: textTheme.titleMedium!.copyWith(inherit: false),
        iconColor: iconColor,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: drawerBgColor,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        contentTextStyle: textTheme.bodyLarge!.copyWith(
          color: dialogTextColor,
        ),
        titleTextStyle: textTheme.titleLarge!.copyWith(
          color: dialogTextColor,
        ),
        elevation: 10,
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 40,
        backgroundColor: appBarBgColor,
        centerTitle: true,
        elevation: 5,
        iconTheme: iconTheme.copyWith(color: appBarTextColor),
        titleTextStyle: textTheme.titleLarge!.copyWith(
          color: appBarTextColor,
          fontFamily: appBarFontFamily,
        ),
        shape: Border(
          bottom: BorderSide(
            color: onThemeBackgroundColor.withValues(alpha: 0.5),
            width: 0.1,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarBgColor,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: snackBarContentColor,
          fontFamily: buttonFontFamily,
        ),
        actionTextColor: snackBarContentColor,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: themeBackgroundColor.withValues(alpha: 0.5),
            width: 2.0,
          ),
        ),
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: elevatedButtonBgColor,
          foregroundColor: elevatedButtonTextColor,
          textStyle: textTheme.bodyLarge!.copyWith(fontFamily: buttonFontFamily),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: elevatedButtonBorderColor,
              width: 2.0,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(textButtonColor),
          textStyle: WidgetStateProperty.all(
            textTheme.bodyLarge!.copyWith(fontFamily: buttonFontFamily),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: floatingButtonBgColor,
        foregroundColor: floatingButtonContentColor,
        elevation: 5,
        extendedTextStyle: textTheme.titleSmall!.copyWith(
          color: floatingButtonContentColor,
          fontFamily: buttonFontFamily,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: themeBackgroundColor.withValues(alpha: 0.5),
            width: 2.0,
          ),
        ),
      ),
      canvasColor: themeBackgroundColor,
      iconTheme: iconTheme,
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
        isDense: true,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: textTheme.labelLarge,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: onThemeBackgroundColor,
            width: 2.0,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(themeBackgroundColor),
        fillColor: WidgetStateProperty.all(onThemeBackgroundColor),
      ),
      primaryIconTheme: iconTheme,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: onThemeBackgroundColor,
        circularTrackColor: themeBackgroundColor.withValues(alpha: 0),
      ),
      colorScheme: ColorScheme(
        primary: onThemeBackgroundColor,
        onPrimary: themeBackgroundColor,
        secondary: secondary,
        onSecondary: onSecondary,
        surface: themeBackgroundColor,
        onSurface: onSurface,
        error: errorBgColor,
        onError: errorTextColor,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: themeBackgroundColor,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(5.0),
        radius: const Radius.circular(10.0),
        interactive: true,
        trackColor: WidgetStateProperty.all(
          onThemeBackgroundColor,
        ),
        crossAxisMargin: 5.0,
        mainAxisMargin: 5.0,
        thumbColor: WidgetStateProperty.all(
          onThemeBackgroundColor.withValues(alpha: 0.7),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: badgeBgColor,
        textColor: badgeContentColor,
      ),
    );
  }

  Map<String, int> toMap() {
    return {
      'themeBackgroundColor': themeBackgroundColor.toARGB32(),
      'onThemeBackgroundColor': onThemeBackgroundColor.toARGB32(),
      'secondary': secondary.toARGB32(),
      'onSecondary': onSecondary.toARGB32(),
      'onSurface': onSurface.toARGB32(),
      'iconColor': iconColor.toARGB32(),
      'iconSplashColor': iconSplashColor.toARGB32(),
      'iconMainFillColor': iconMainFillColor.toARGB32(),
      'iconMainShadeColor': iconMainShadeColor.toARGB32(),
      'iconSecondaryFillColor': iconSecondaryFillColor.toARGB32(),
      'iconSecondaryShadeColor': iconSecondaryShadeColor.toARGB32(),
      'iconSkinColor': iconSkinColor.toARGB32(),
      'iconSkinShadeColor': iconSkinShadeColor.toARGB32(),
      'iconBaloonColor': iconBalloonColor.toARGB32(),
      'iconBaloonShadeColor': iconBalloonShadeColor.toARGB32(),
      'iconPaperColor': iconPaperColor.toARGB32(),
      'iconPaperShadeColor': iconPaperShadeColor.toARGB32(),
      'iconBorderColor': iconBorderColor.toARGB32(),
      'iconTitleColor': iconTitleColor.toARGB32(),
      'appBarBgColor': appBarBgColor.toARGB32(),
      'appBarTextColor': appBarTextColor.toARGB32(),
      'snackBarBgColor': snackBarBgColor.toARGB32(),
      'snackBarContentColor': snackBarContentColor.toARGB32(),
      'scaffoldBackgroundColor': scaffoldBackgroundColor.toARGB32(),
      'dialogBgColor': dialogBgColor.toARGB32(),
      'dialogTextColor': dialogTextColor.toARGB32(),
      'drawerBgColor': drawerBgColor.toARGB32(),
      'selectedTileColor': selectedTileColor.toARGB32(),
      'elevatedButtonBgColor': elevatedButtonBgColor.toARGB32(),
      'elevatedButtonTextColor': elevatedButtonTextColor.toARGB32(),
      'elevatedButtonBorderColor': elevatedButtonBorderColor.toARGB32(),
      'textButtonColor': textButtonColor.toARGB32(),
      'errorBgColor': errorBgColor.toARGB32(),
      'errorTextColor': errorTextColor.toARGB32(),
      'floatingButtonBgColor': floatingButtonBgColor.toARGB32(),
      'floatingButtonContentColor': floatingButtonContentColor.toARGB32(),
      'badgeBgColor': badgeBgColor.toARGB32(),
      'badgeContentColor': badgeContentColor.toARGB32(),
      'recentChangeMainPersonColor': recentChangeMainPersonColor.toARGB32(),
      'recentChangeMaleColor': recentChangeMaleColor.toARGB32(),
      'recentChangeFemaleColor': recentChangeFemaleColor.toARGB32(),
      'recentChangeNewChangeColor': recentChangeNewChangeColor.toARGB32(),
      'recentChangeUpdatingChangeColor': recentChangeUpdatingChangeColor.toARGB32(),
      'sectorBgColor': sectorBgColor.toARGB32(),
      'sectorIconColor': sectorIconColor.toARGB32(),
      'sectorTextColor': sectorTextColor.toARGB32(),
      'sectorToggleBgColor': sectorToggleBgColor.toARGB32(),
      'sectorToggleTextColor': sectorToggleTextColor.toARGB32(),
      'businessBgColor': businessBgColor.toARGB32(),
      'businessIconColor': businessIconColor.toARGB32(),
      'businessTextColor': businessTextColor.toARGB32(),
      'businessGraphLineColor': businessGraphLineColor.toARGB32(),
    };
  }

  factory CustomTheme.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return defaultTheme;
    }
    return CustomTheme(
      themeBackgroundColor: Color(getValue(map['themeBackgroundColor']) ?? defaultTheme.themeBackgroundColor.toARGB32()),
      onThemeBackgroundColor: Color(getValue(map['onThemeBackgroundColor']) ?? defaultTheme.onThemeBackgroundColor.toARGB32()),
      secondary: Color(getValue(map['secondary']) ?? defaultTheme.secondary.toARGB32()),
      onSecondary: Color(getValue(map['onSecondary']) ?? defaultTheme.onSecondary.toARGB32()),
      onSurface: Color(getValue(map['onSurface']) ?? defaultTheme.onSurface.toARGB32()),
      iconColor: Color(getValue(map['iconColor']) ?? defaultTheme.iconColor.toARGB32()),
      iconSplashColor: Color(getValue(map['iconSplashColor']) ?? defaultTheme.iconSplashColor.toARGB32()),
      iconMainFillColor: Color(getValue(map['iconMainFillColor']) ?? defaultTheme.iconMainFillColor.toARGB32()),
      iconMainShadeColor: Color(getValue(map['iconMainShadeColor']) ?? defaultTheme.iconMainShadeColor.toARGB32()),
      iconSecondaryFillColor: Color(getValue(map['iconSecondaryFillColor']) ?? defaultTheme.iconSecondaryFillColor.toARGB32()),
      iconSecondaryShadeColor: Color(getValue(map['iconSecondaryShadeColor']) ?? defaultTheme.iconSecondaryShadeColor.toARGB32()),
      iconSkinColor: Color(getValue(map['iconSkinColor']) ?? defaultTheme.iconSkinColor.toARGB32()),
      iconSkinShadeColor: Color(getValue(map['iconSkinShadeColor']) ?? defaultTheme.iconSkinShadeColor.toARGB32()),
      iconBalloonColor: Color(getValue(map['iconBaloonColor']) ?? defaultTheme.iconBalloonColor.toARGB32()),
      iconBalloonShadeColor: Color(getValue(map['iconBaloonShadeColor']) ?? defaultTheme.iconBalloonShadeColor.toARGB32()),
      iconPaperColor: Color(getValue(map['iconPaperColor']) ?? defaultTheme.iconPaperColor.toARGB32()),
      iconPaperShadeColor: Color(getValue(map['iconPaperShadeColor']) ?? defaultTheme.iconPaperShadeColor.toARGB32()),
      iconBorderColor: Color(getValue(map['iconBorderColor']) ?? defaultTheme.iconBorderColor.toARGB32()),
      iconTitleColor: Color(getValue(map['iconTitleColor']) ?? defaultTheme.iconTitleColor.toARGB32()),
      appBarBgColor: Color(getValue(map['appBarBgColor']) ?? defaultTheme.appBarBgColor.toARGB32()),
      appBarTextColor: Color(getValue(map['appBarTextColor']) ?? defaultTheme.appBarTextColor.toARGB32()),
      snackBarBgColor: Color(getValue(map['snackBarBgColor']) ?? defaultTheme.snackBarBgColor.toARGB32()),
      snackBarContentColor: Color(getValue(map['snackBarContentColor']) ?? defaultTheme.snackBarContentColor.toARGB32()),
      scaffoldBackgroundColor: Color(getValue(map['scaffoldBackgroundColor']) ?? defaultTheme.scaffoldBackgroundColor.toARGB32()),
      dialogBgColor: Color(getValue(map['dialogBgColor']) ?? defaultTheme.dialogBgColor.toARGB32()),
      dialogTextColor: Color(getValue(map['dialogTextColor']) ?? defaultTheme.dialogTextColor.toARGB32()),
      drawerBgColor: Color(getValue(map['drawerBgColor']) ?? defaultTheme.drawerBgColor.toARGB32()),
      selectedTileColor: Color(getValue(map['selectedTileColor']) ?? defaultTheme.selectedTileColor.toARGB32()),
      elevatedButtonBgColor: Color(getValue(map['elevatedButtonBgColor']) ?? defaultTheme.elevatedButtonBgColor.toARGB32()),
      elevatedButtonTextColor: Color(getValue(map['elevatedButtonTextColor']) ?? defaultTheme.elevatedButtonTextColor.toARGB32()),
      elevatedButtonBorderColor: Color(getValue(map['elevatedButtonBorderColor']) ?? defaultTheme.elevatedButtonBorderColor.toARGB32()),
      textButtonColor: Color(getValue(map['textButtonColor']) ?? defaultTheme.textButtonColor.toARGB32()),
      errorBgColor: Color(getValue(map['errorBgColor']) ?? defaultTheme.errorBgColor.toARGB32()),
      errorTextColor: Color(getValue(map['errorTextColor']) ?? defaultTheme.errorTextColor.toARGB32()),
      floatingButtonBgColor: Color(getValue(map['floatingButtonBgColor']) ?? defaultTheme.floatingButtonBgColor.toARGB32()),
      floatingButtonContentColor: Color(getValue(map['floatingButtonContentColor']) ?? defaultTheme.floatingButtonContentColor.toARGB32()),
      badgeBgColor: Color(getValue(map['badgeBgColor']) ?? defaultTheme.badgeBgColor.toARGB32()),
      badgeContentColor: Color(getValue(map['badgeContentColor']) ?? defaultTheme.badgeContentColor.toARGB32()),
      recentChangeMainPersonColor: Color(getValue(map['recentChangeMainPersonColor']) ?? defaultTheme.recentChangeMainPersonColor.toARGB32()),
      recentChangeMaleColor: Color(getValue(map['recentChangeMaleColor']) ?? defaultTheme.recentChangeMaleColor.toARGB32()),
      recentChangeFemaleColor: Color(getValue(map['recentChangeFemaleColor']) ?? defaultTheme.recentChangeFemaleColor.toARGB32()),
      recentChangeNewChangeColor: Color(getValue(map['recentChangeNewChangeColor']) ?? defaultTheme.recentChangeNewChangeColor.toARGB32()),
      recentChangeUpdatingChangeColor: Color(getValue(map['recentChangeUpdatingChangeColor']) ?? defaultTheme.recentChangeUpdatingChangeColor.toARGB32()),
      sectorBgColor: Color(getValue(map['sectorBgColor']) ?? defaultTheme.sectorBgColor.toARGB32()),
      sectorIconColor: Color(getValue(map['sectorIconColor']) ?? defaultTheme.sectorIconColor.toARGB32()),
      sectorTextColor: Color(getValue(map['sectorTextColor']) ?? defaultTheme.sectorTextColor.toARGB32()),
      sectorToggleBgColor: Color(getValue(map['sectorToggleBgColor']) ?? defaultTheme.sectorToggleBgColor.toARGB32()),
      sectorToggleTextColor: Color(getValue(map['sectorToggleTextColor']) ?? defaultTheme.sectorToggleTextColor.toARGB32()),
      businessBgColor: Color(getValue(map['businessBgColor']) ?? defaultTheme.businessBgColor.toARGB32()),
      businessIconColor: Color(getValue(map['businessIconColor']) ?? defaultTheme.businessIconColor.toARGB32()),
      businessTextColor: Color(getValue(map['businessTextColor']) ?? defaultTheme.businessTextColor.toARGB32()),
      businessGraphLineColor: Color(getValue(map['businessGraphLineColor']) ?? defaultTheme.businessGraphLineColor.toARGB32()),
    );
  }

  static int? getValue(value) {
    if (value is int) {
      return value;
    }
    return null;
  }

  static const logoGreen = Color.fromRGBO(92, 150, 47, 1);
  static const logoBrown = Color.fromRGBO(121, 87, 52, 1);
  static const logoBackground = Color.fromRGBO(247, 247, 234, 1.0);

  static const CustomTheme defaultTheme = CustomTheme(
    appBarBgColor: Color(4285308779),
    appBarTextColor: Color(4293457385),
    badgeBgColor: Color(4294964637),
    badgeContentColor: Color(4278209856),
    dialogBgColor: Color(4285308779),
    dialogTextColor: Color(4280170755),
    drawerBgColor: Color(4285308779),
    elevatedButtonBgColor: Color(4279983648),
    elevatedButtonBorderColor: Color(4279583767),
    elevatedButtonTextColor: Color(4294962158),
    errorBgColor: Color(4294551589),
    errorTextColor: Color(4279983648),
    floatingButtonBgColor: Color(4279983648),
    floatingButtonContentColor: Color(4293519591),
    iconColor: Color(4279253780),
    iconSplashColor: Color(4293457385),
    iconMainFillColor: Color(4289058471),
    iconMainShadeColor: Color(4281896508),
    iconSecondaryFillColor: Color(4294952312),
    iconSecondaryShadeColor: Color(4288776319),
    iconSkinColor: Color(4294962355),
    iconSkinShadeColor: Color(4294951175),
    iconBalloonColor: Color(4294964637),
    iconBalloonShadeColor: Color(4294826037),
    iconPaperColor: Color(4294309365),
    iconPaperShadeColor: Color(4292269782),
    iconBorderColor: Color(4278209856),
    iconTitleColor: Color(4278209856),
    onSecondary: Color(4279253780),
    // Matches onThemeBackgroundColor so pre-existing themes render unchanged.
    onSurface: Color(4294967295),
    onThemeBackgroundColor: Color(4294967295),
    recentChangeFemaleColor: Color(4279983648),
    recentChangeMainPersonColor: Color(4279983648),
    recentChangeMaleColor: Color(4279983648),
    recentChangeNewChangeColor: Color(4293848814),
    recentChangeUpdatingChangeColor: Color(4293848814),
    scaffoldBackgroundColor: Color(4292667827),
    secondary: Color(4292667827),
    selectedTileColor: Color(4290303136),
    snackBarBgColor: Color(4292927712),
    snackBarContentColor: Color(4279983648),
    textButtonColor: Color(4294962158),
    themeBackgroundColor: Color(4285308779),
    sectorBgColor: Color(4294967295),
    sectorIconColor: Color(4279253780),
    sectorTextColor: Color(4285308779),
    sectorToggleBgColor: Color(4285308779),
    sectorToggleTextColor: Color(4279253780),
    businessBgColor: Color(4285308779),
    businessIconColor: Color(4279253780),
    businessTextColor: Color(4294967295),
    businessGraphLineColor: Color(4279253780),
  );
}

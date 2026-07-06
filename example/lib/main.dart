import 'package:cloud_storage/cloud_storage.dart';
import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Anonymous sign-in keeps the demo dependency-free. The package itself is
  // auth-agnostic — sign in however your real app does.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  final storage = defaultCloudStorage(
    firestorePath: 'files',
    storagePath: 'files',
  );

  runApp(ExampleApp(storage: storage));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.storage});

  final CloudStorage storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cloud_storage example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      // Force Arabic to demo the built-in localization + automatic RTL.
      // In a real app drop `locale` and let the device locale drive it.
      locale: const Locale('ar'),
      supportedLocales: CloudGalleryLocalizations.supportedLocales,
      localizationsDelegates: const [
        CloudGalleryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CloudFolderScreen(storage: storage),
    );
  }
}

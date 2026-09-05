// File generated manually based on de Firebase-appconfig voor het
// `uurrooster-app`-project. Waarden worden op compile-tijd meegegeven
// vanuit een (gitignored) env-bestand, nooit hardcoded of gecommit:
// - web: .env, via --dart-define-from-file=.env
// - Android: .env.android, via --dart-define-from-file=.env.android
// Zie README.md voor de exacte commando's en PROJECT_SPEC.md fase 12 voor
// hoe je de Android-waarden ophaalt uit de Firebase console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions heeft geen iOS-configuratie; dit project '
          'ondersteunt enkel Android en web.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions is niet geconfigureerd voor dit platform.',
        );
    }
  }

  // Waarden komen uit het (gitignored) .env-bestand in de projectroot en
  // moeten meegegeven worden via `--dart-define-from-file=.env` bij
  // `flutter run` / `flutter build`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('apiKey'),
    appId: String.fromEnvironment('appId'),
    messagingSenderId: String.fromEnvironment('messagingSenderId'),
    projectId: String.fromEnvironment('projectId'),
    authDomain: String.fromEnvironment('authDomain'),
    storageBucket: String.fromEnvironment('storageBucket'),
  );

  // Zelfde principe, maar dan uit .env.android (Android-apps in Firebase
  // hebben een eigen apiKey/appId, los van de webapp - de rest van het
  // project (projectId/storageBucket) is wel gedeeld).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('apiKey'),
    appId: String.fromEnvironment('appId'),
    messagingSenderId: String.fromEnvironment('messagingSenderId'),
    projectId: String.fromEnvironment('projectId'),
    storageBucket: String.fromEnvironment('storageBucket'),
  );
}

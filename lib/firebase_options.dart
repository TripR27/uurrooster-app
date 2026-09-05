// File generated manually based on the Firebase web app config for the
// `uurrooster-app` Firebase project. Values are injected at compile time
// from the (gitignored) .env file via --dart-define-from-file=.env, so no
// secrets are hardcoded here or committed to git.
// Regenerate/extend with `flutterfire configure` once Android/iOS apps are
// registered in the Firebase console (see PROJECT_SPEC.md, fase 12).

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
        throw UnsupportedError(
          'DefaultFirebaseOptions.android is nog niet geconfigureerd. '
          'Registreer een Android-app in de Firebase console en vul de '
          'android-sectie van dit bestand aan (zie PROJECT_SPEC.md, fase 12).',
        );
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
}

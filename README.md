# Gezinsrooster-app

Zie [PROJECT_SPEC.md](PROJECT_SPEC.md) voor de volledige uitleg en het bouwplan.

## Project draaien

De Firebase-configuratie wordt niet hardcoded in de code gezet, maar op
compile-tijd meegegeven vanuit het (niet-gecommitte) `.env`-bestand in de
projectroot. Geef daarom altijd `--dart-define-from-file=.env` mee:

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Of om een webbuild te maken:

```bash
flutter build web --dart-define-from-file=.env
```

Zonder deze vlag start de app wel op, maar kan Firebase niet verbinden
(lege apiKey/projectId/...).

## Android (APK)

Voor Android is er een apart env-bestand, `.env.android` (ook niet
gecommit) - de Android-app heeft in Firebase namelijk zijn eigen
`apiKey`/`appId`, los van de webapp (zie PROJECT_SPEC.md §8 voor de
Firebase-config). Zelfde bestandsformaat als `.env`, enkel zonder
`authDomain` (dat is web-only):

```bash
flutter build apk --release --dart-define-from-file=.env.android
```

De APK staat nadien in `build/app/outputs/flutter-apk/app-release.apk` -
rechtstreeks te installeren op een Android-toestel (na "onbekende bronnen"
toe te staan), geen Play Store nodig.

De release-build is ondertekend met een echte keystore
(`android/upload-keystore.jks` + `android/key.properties`, allebei
gitignored - zie PROJECT_SPEC.md §8 voor waar/hoe die staan).
Ontbreken die bestanden (bv. een nieuwe checkout), dan valt de build
automatisch terug op de tijdelijke debug-signing.

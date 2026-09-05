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

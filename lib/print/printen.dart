// Print/deel het gezamenlijke overzicht - implementatie verschilt per
// platform, zie printen_web.dart (rechtstreeks de systeem-printdialoog via
// de browser, enkel gecompileerd voor de webversie) en printen_stub.dart
// (Android/overige platformen: genereert een PDF en opent Android's
// deel-scherm, waar "Printen" meestal gewoon als optie tussen staat - zie
// PROJECT_SPEC.md sectie 9 voor waarom `printing` niet bruikbaar is voor
// een systeem-printdialoog zoals op web).
export 'printen_stub.dart' if (dart.library.html) 'printen_web.dart';

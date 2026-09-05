// Print de opgegeven HTML-pagina rechtstreeks af (systeem-printdialoog) -
// implementatie verschilt per platform, zie printen_web.dart (echte
// implementatie, enkel gecompileerd voor de webversie) en
// printen_stub.dart (Android/overige platformen, waar dit nog niet kan
// zonder een extra package - zie PROJECT_SPEC.md sectie 9 voor waarom
// `printing` niet bruikbaar is).
export 'printen_stub.dart' if (dart.library.html) 'printen_web.dart';

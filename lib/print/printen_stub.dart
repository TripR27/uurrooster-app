/// Op Android (en elk ander niet-web-platform) kan er nog niet
/// rechtstreeks geprint worden - dat vereist ofwel een systeem-printdialoog
/// via een package (zie PROJECT_SPEC.md sectie 9 voor waarom `printing`
/// momenteel niet bruikbaar is) ofwel een platform-eigen implementatie.
/// Voorlopig enkel de webversie, vandaar deze duidelijke foutmelding i.p.v.
/// een knop die stilzwijgend niks doet.
void printHtml(String htmlContent) {
  throw UnsupportedError(
    'Printen kan momenteel enkel via de webversie van de app.',
  );
}

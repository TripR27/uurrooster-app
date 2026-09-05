# Project: Gezinsrooster-app

Analyse & technisch plan — bedoeld als startdocument voor Claude Code.

## 1. Doel

Een app waarin 3 personen (ik, mijn zus, mijn moeder) hun werkrooster (PDF) uploaden.
De app leest de uren uit de PDF, slaat ze op, en de beheerder (ik) kan een
gezamenlijk, printbaar overzicht genereren met de uren van alle 3.

Extra: bij elke dienst kan een korte vrije-tekst omschrijving toegevoegd worden
(ook los van een PDF-import), zodat later ook privé-afspraken op het gezamenlijke
rooster gezet kunnen worden.

Elk lid kan ook een dienst die uit een PDF geïmporteerd is, achteraf handmatig
corrigeren (bv. als er iets verkeerd is ingelezen) of gewoon zelf een dienst
verwijderen/toevoegen zonder PDF (bv. een privé-afspraak). Hier moet doorheen
de hele app rekening mee gehouden worden: elke Dienst heeft dus een eigen
document-id in Firestore zodat hij later opnieuw op te zoeken en te wijzigen
is, en de UI mag PDF-import niet als de enige manier behandelen om diensten te
laten ontstaan.

## 2. Gebruikers & rollen

| Rol       | Wie             | Rechten                                                                                                    |
| --------- | --------------- | ---------------------------------------------------------------------------------------------------------- |
| Lid       | ik, zus, moeder | Inloggen, eigen PDF-rooster uploaden, eigen diensten bekijken, handmatig een dienst/omschrijving toevoegen |
| Beheerder | ik              | Alles wat een lid kan + gezamenlijk overzicht van alle 3 bekijken + printen/exporteren                     |

Iedereen heeft een eigen account. Na inloggen weet de app automatisch "wie je bent" —
geen aparte stap nodig waarin je jezelf moet aanduiden.

## 3. Platform & techstack

**Gekozen: Flutter** (Dart), omdat dat met één codebase oplevert:

- een installeerbare Android **APK** (rechtstreeks te downloaden, geen Play Store nodig) — voor wie dat wil,
- een **webversie** (gewoon een link openen in de browser) — voor je moeder, geen installatie nodig.

Dat lost de twijfel "echte app vs. webapp" in één keer op: zelfde app, twee manieren om 'm te gebruiken.

| Onderdeel            | Keuze                                                                         | Waarom                                                                                                           |
| -------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| App                  | Flutter                                                                       | 1 codebase → Android-app én webapp, gratis, jij hebt er al ervaring mee                                          |
| Authenticatie        | Firebase Authentication                                                       | Gratis, simpel, ingebouwde login (e-mail + wachtwoord)                                                           |
| Database             | Cloud Firestore                                                               | Gratis tier ruim voldoende voor 3 gebruikers, realtime sync tussen apparaten                                     |
| PDF-tekst uitlezen   | `syncfusion_flutter_pdf` (Community License, gratis voor persoonlijk gebruik) | Werkt cross-platform (Android + web), kan tekst uit PDF halen zonder server                                      |
| Printen / PDF-export | pakketten `pdf` + `printing`                                                  | Genereert het gezamenlijke overzicht als PDF en stuurt het naar de systeem-printdialoog; werkt op Android én web |
| Hosting webversie    | Firebase Hosting                                                              | Gratis tier, integreert direct met de rest van Firebase                                                          |

**Bewust vermeden:** Firebase Cloud Functions. Dat zou een gratis-optie zijn geweest voor het
PDF-verwerken op de achtergrond, maar vereist tegenwoordig het (betaalplan) Blaze-abonnement
en een gekoppelde creditcard — ook al blijf je binnen het gratis quotum. Door alles op het
apparaat zelf te verwerken (client-side), blijft alles 100% gratis zonder betaalgegevens.

## 4. Architectuur (overzicht)

```
[Flutter App: Android + Web]
        |
        |-- Firebase Auth        (wie ben je?)
        |-- Firestore            (opslag diensten/uren)
        |
        |-- PDF-bestand kiezen
        |     -> tekst extractie (Syncfusion)
        |     -> juiste "Parser" op basis van formaat
        |     -> lijst met Diensten
        |     -> wegschrijven naar Firestore
        |
        |-- Overzichtscherm (per persoon)
        |-- Beheerscherm (alleen ik): gezamenlijk overzicht + printen
```

## 5. Datamodel (Firestore)

**Collectie `gebruikers`** (doc-id = Firebase Auth uid)

```
{
  naam: string,            // "Jij", "Zus", "Mama"
  rol: "lid" | "beheerder",
  roosterFormaat: "A" | "B" | null,  // optioneel, welke RoosterParser voor dit account
  naamInRooster: string | null       // optioneel, hoe de naam letterlijk in de PDF staat
}
```

`roosterFormaat` en `naamInRooster` staan er niet automatisch bij (nieuwe
accounts starten met enkel `naam`+`rol`, zie GebruikerService) - de beheerder
vult die twee velden zelf handmatig in via de Firestore-console zodra
duidelijk is welk PDF-formaat en welke naam bij een account hoort (zie
ACCOUNTS_AANMAKEN.md). Zonder die twee velden kan een account geen PDF
importeren, maar wel manueel diensten toevoegen/wijzigen.

**Collectie `diensten`**

```
{
  gebruikerId: string,      // verwijzing naar gebruikers/{uid}
  gebruikerNaam: string,    // gedenormaliseerd, handig voor overzicht/print
  datum: string,            // "2026-09-08" (ISO-formaat, makkelijk sorteren)
  startTijd: string,        // "09:00"
  eindTijd: string,         // "17:00"
  omschrijving: string,     // optioneel, vrije tekst — ook voor privé-items
  bron: "pdf-import" | "handmatig",
  aangemaaktOp: timestamp
}
```

Dit model is bewust "plat" en onafhankelijk van hoe een PDF eruitziet — zo kan
elk nieuw roosterformaat er gewoon naartoe vertalen zonder dat de rest van de
app iets hoeft te weten van PDF-lay-outs.

**Document-id-afspraak:** een dienst met `bron: "pdf-import"` krijgt als
document-id altijd `{gebruikerId}_{datum}` (dus 1 PDF-shift per dag per
persoon). Zo overschrijft een nieuwe/herhaalde PDF-import van dezelfde
periode gewoon de vorige waarde in plaats van duplicaten aan te maken.
Handmatige diensten (`bron: "handmatig"`) krijgen een automatisch
gegenereerd Firestore-id, want daar kunnen wel meerdere per dag bestaan
(bv. een werkdienst + een privé-afspraak).

## 6. PDF-parsing strategie (uitbreidbaar per persoon/formaat)

We weten al: jij en mama hebben hetzelfde PDF-formaat, je zus een ander formaat.
Daarom een simpele adapter-aanpak in Dart:

```dart
abstract class RoosterParser {
  List<Dienst> parse(String pdfTekst, String gebruikerId, String gebruikerNaam);
}

class FormaatAParser implements RoosterParser { ... }   // jij & mama
class FormaatBParser implements RoosterParser { ... }   // zus
```

Welke parser gebruikt wordt, hangt af van de ingelogde gebruiker (elke gebruiker
heeft een vast rooster-formaat gekoppeld aan zijn/haar account). Komt er ooit een
4e persoon met weer een ander formaat bij: gewoon een nieuwe `RoosterParser`-klasse
toevoegen, verder verandert er niets aan de rest van de app.

**Belangrijk openstaand punt:** ik heb nog geen voorbeeld-PDF's gezien. De exacte
parser-code kan pas geschreven worden zodra er minstens 1 voorbeeld van "Formaat A"
(jij/mama) en 1 van "Formaat B" (zus) beschikbaar zijn.

## 7. Authenticatie & rechten

- 3 accounts (e-mail + wachtwoord) via Firebase Authentication, door de beheerder aangemaakt.
- Firestore security rules zorgen dat:
  - een lid alleen zijn/haar eigen diensten kan aanmaken/wijzigen,
  - alleen de beheerder alle diensten van iedereen mag lezen.

## 8. Gezamenlijk overzicht + printen

- Alleen zichtbaar voor de beheerder.
- Kiest een periode (bv. "deze week"), app haalt alle diensten van de 3 gebruikers
  op uit Firestore voor die periode.
- Weergave: tabel met 1 kolom per persoon, 1 rij per dag, inclusief eventuele
  omschrijving.
- Knop "Printen/Exporteren" genereert met het `pdf`-pakket een nette A4-pagina en
  opent via `printing` de systeem-print/deel-dialoog (werkt zowel op Android als
  in de browser).

## 9. Kosten

Alles blijft binnen het gratis "Spark"-plan van Firebase (geen creditcard nodig):
Authentication, Firestore en Hosting hebben een gratis quotum dat voor 3 gebruikers
ruimschoots voldoende is. Flutter zelf is gratis en open source. De enige mogelijke
kost is €0, tenzij je zelf een custom domeinnaam zou willen kopen (optioneel, niet nodig).

## 10. Bouwplan (fases — dit is de volgorde voor Claude Code)

1. Flutter-project opzetten + Firebase-project aanmaken en koppelen (FlutterFire CLI).
2. Inlogscherm bouwen (Firebase Auth) + de 3 accounts kunnen aanmaken.
3. Datamodel + Firestore security rules opzetten.
4. PDF-upload UI + tekst-extractie testen. Opgesplitst in de praktijk:
   - 4.1 `FormaatAParser` (jij/mama) schrijven + testen met jouw PDF.
   - 4.2 `FormaatBParser` (zus) schrijven + testen met haar PDF — nieuwe
     adapter, geen wijziging aan bestaande code.
5. Geparste diensten echt wegschrijven naar Firestore (per ingelogd account,
   automatisch het juiste RoosterParser-formaat gebruiken).
6. Overzichtscherm: eigen diensten bekijken (elk lid), inclusief een dienst
   handmatig kunnen corrigeren/verwijderen als er iets fout is ingelezen.
7. Handmatige invoer: zelf een dienst/omschrijving toevoegen zonder PDF
   (bv. een privé-afspraak).
8. Beheerscherm: gezamenlijk overzicht van alle 3.
9. Printen/PDF-export van het gezamenlijke overzicht.
10. Styling/polish, testen op alle 3 toestellen (2x Android, 1x web voor mama).
11. APK bouwen voor rechtstreekse download + webversie hosten op Firebase Hosting.

Zie sectie 13 hieronder voor een lopend logboek van wat al klaar is en
waarom bepaalde keuzes gemaakt zijn.

## 11. Open vragen / aannames (nog te bevestigen)

- Voorbeeld-PDF van Formaat A (jij/mama) en Formaat B (zus) nog nodig om de
  parsers te kunnen schrijven.
- Aanname: rooster is wekelijks (aan te passen als het eigenlijk maandelijks is).
- Aanname: de 3 accounts worden door de beheerder (jij) handmatig aangemaakt,
  er komt geen openbare "registreer jezelf"-pagina (dit is een privé-gezinsapp).

## 12. Wat ik nog moet aanleveren voordat het bouwen echt begint

- Eén voorbeeld-PDF van Formaat A.
- Eén voorbeeld-PDF van Formaat B (zus).

## 13. Voortgang & belangrijk om te weten

Dit is een lopend logboek, bijgehouden na elke stap - zodat een nieuwe
Claude-chat (bv. na het opruimen van het context window) meteen weer verder
kan zonder alles opnieuw te moeten uitzoeken. Voeg hier na elke stap een
korte samenvatting aan toe: wat gebouwd is, welke keuzes gemaakt zijn (en
waarom), en wat er nog manueel moet gebeuren.

### Status

Stap 1 t.e.m. 6 zijn klaar (zie git-historiek voor de exacte commits per
stap). Elke stap is apart gepushed naar `main` op GitHub
(TripR27/uurrooster-app), telkens na `flutter analyze` + `flutter test` +
een visuele check (browser en/of automatische test tegen de echte
PDF-bestanden in `uurroosters/`).

De UI-taak die na stap 6 was blijven liggen (startscherm herindelen,
terminologie "dienst"->"shift" in zichtbare teksten, levendigere stijl) is
uitgevoerd: `HomeScreen` toont nu enkel nog een gekleurde kop (bosgroen
gradient, in dezelfde sfeer als het brandingpaneel van `login_screen.dart`)
met 2 kaarten - "PDF uploaden" en "Shiften bekijken". De vroegere inline
lijst (`_EigenRooster`) is verhuisd naar een nieuw scherm
`lib/screens/shiften_screen.dart` (`ShiftenScreen`), met dezelfde
StreamBuilder-aanpak en tik-om-te-bewerken-flow als daarvoor. Zichtbare
teksten zijn overal "shift(en)" geworden ("Mijn shiften", "Shift bewerken",
"Shift verwijderen?", ...); de interne klasse `Dienst`/`DienstService` en de
Firestore-collectie `diensten` zijn bewust ongewijzigd gelaten (zie
overwegingen die hierboven stonden, nu niet meer herhaald).

Stap 6 (overzicht + corrigeren) voegde toe: HomeScreen toont nu een echte
live lijst (`DienstService.eigenDiensten`) van de ingelogde gebruiker i.p.v.
enkel "Ingelogd als ...". Elke rij (gedeeld widgetje `DienstTile`) opent
`DienstBewerkenScreen`: tijden + omschrijving aanpassen, of verwijderen
(met bevestigingsdialoog). Datum is bewust niet aanpasbaar bij een
PDF-import (zie hieronder bij document-id). Getest: een echte dienst van
Amy live gewijzigd + teruggezet via de UI, en de lijst update meteen
(StreamBuilder, geen refresh nodig).

Stap 7 (handmatige invoer zonder PDF) is nu ook klaar: `ShiftenScreen`
heeft een FloatingActionButton die naar het nieuwe scherm
`lib/screens/dienst_toevoegen_screen.dart` (`DienstToevoegenScreen`) gaat -
datum + van/tot-tijd (default vandaag/nu-nu+1u, of de aangetikte
kalenderdag, zie hieronder) + vrije omschrijving, altijd met
`bron: handmatig`. Nieuw in `DienstService`: `aanmaken(Dienst)` gebruikt
`.add()` (auto-gegenereerd document-id) i.p.v. een vast
`{gebruikerId}_{datum}`-id, zodat er - in tegenstelling tot een PDF-import
- wel meerdere shiften per dag kunnen bestaan (zie PROJECT_SPEC.md sectie
5). Geen wijziging aan `firestore.rules` nodig: de bestaande `create`-rule
op `diensten` (enkel `gebruikerId == request.auth.uid`) staat toe ongeacht
of het document-id vast of auto-gegenereerd is.

Direct daarna gevraagd door Ryan: het "toevoegen" is niet altijd een
werkshift (kan ook een privé-afspraak zijn), dus de knop/titel van dat
scherm heet nu neutraal "Toevoegen" i.p.v. "Shift toevoegen" (enkel de
zichtbare tekst; de klasse blijft `DienstToevoegenScreen`, zie eerdere
afspraak over interne namen niet meemigreren). Daarnaast is de platte
lijst op `ShiftenScreen` vervangen door een kalenderweergave
(`table_calendar`-package, maand per maand met vorige/volgende-pijltjes):
een terracotta bolletje op elke dag met iets erop, tik een dag aan om de
shiften/afspraken van die dag eronder te zien. De "Toevoegen"-knop gebruikt
de net aangetikte kalenderdag als startdatum voor het formulier (i.p.v.
altijd vandaag) via het nieuwe `DienstToevoegenScreen.initieleDatum`
-argument. Nederlandse maand-/dagnamen vereisen `initializeDateFormatting
('nl_BE')` in `main()` vóór `runApp()` (via het `intl`-package, nu als
directe dependency toegevoegd i.p.v. enkel transitief) - zonder die
initialisatie gooit `table_calendar` een `LocaleDataException`. Getest: een
echte handmatige shift aangemaakt/bekeken/verwijderd via de UI op het
testaccount, en de kalender + dag-selectie + vooringevulde datum
gecontroleerd tegen Amy's echte juli-shiften.

Stap 8 (beheerscherm met gezamenlijk overzicht) is nu ook klaar: een
3e kaart "Gezamenlijk overzicht" op `HomeScreen`, enkel zichtbaar als
`profiel.isBeheerder` (zie PROJECT_SPEC.md sectie 2), opent het nieuwe
scherm `lib/screens/beheer_overzicht_screen.dart`
(`BeheerOverzichtScreen`). Toont een tabel (Flutter's `DataTable`, binnen
een horizontaal + verticaal scrollbare `SingleChildScrollView` zodat het
ook op een smal telefoonscherm werkt) met 1 kolom per gezinslid en 1 rij
per dag - de gekozen periode is een volledige maand (eerst als week
gebouwd, maar Ryan wou liever een maand kunnen kiezen), met
vorige/volgende-maand-pijltjes bovenaan (Nederlandse maandnaam via
`DateFormat.yMMMM('nl_BE')`, dezelfde locale-initialisatie als de
kalender in `ShiftenScreen`). Nieuw in de services:
`GebruikerService.alleGebruikers()` (leest alle `gebruikers`-documenten -
toegestaan voor de beheerder via de bestaande `isBeheerder()`-rule in
firestore.rules, geen aanpassing nodig) en
`DienstService.voorPeriode(gebruikerIds, vanIso, totIso)` (net als
`eigenDiensten` één losse `where('gebruikerId', isEqualTo: ...)`-query per
gebruiker i.p.v. een samengestelde `whereIn` + datumfilter-query, en
filtert/sorteert de periode dus in Dart i.p.v. in Firestore - zelfde reden
als bij `eigenDiensten`: geen handmatig aan te maken Firestore-index
nodig). Printen/exporteren van dit overzicht is nog niet gebouwd (dat is
stap 9). Getest: overzicht gecontroleerd voor de huidige maand (leeg) en
voor juli 2026 (Amy's + Ryan's echte shiften naast elkaar, incl. "Nacht"),
met het beheerder-testaccount.

Direct daarna nog 2 kleine correcties gevraagd door Ryan:
- **`FormaatAParser` + lege omschrijving**: gecontroleerd, dit stond al
  goed (`omschrijving: 'Werk'` staat onvoorwaardelijk vast in
  `_leesDienstenUitRij`, zie `lib/pdf_import/formaat_a_parser.dart`, en
  wordt ook getest in `formaat_a_parser_test.dart`) - geen codewijziging
  nodig. Wat Ryan wellicht zag: zijn eigen, al langer geleden geïmporteerde
  echte shiften in Firestore staan nog met een lege omschrijving, want die
  zijn opgeslagen vóór deze default er was (zie de TODO-fix in commit
  a6dab9b). Dat lost zichzelf op zodra hij zijn PDF opnieuw uploadt (het
  vaste `{gebruikerId}_{datum}`-document-id overschrijft de oude,
  leeg-omschreven documenten automatisch) - geen actie van mijn kant
  mogelijk, ik mag/kan niet inloggen met zijn echte account.
- **`DienstBewerkenScreen`**: titel "Shift bewerken" -> "Bewerken", en de
  datum is nu nooit meer aanpasbaar in dit scherm (enkel uur +
  omschrijving) - vroeger kon dat wel bij een handmatige dienst, dat is nu
  bewust gelijkgetrokken voor alle bronnen. Een shift naar een andere dag
  verplaatsen kan enkel nog door 'm te verwijderen en opnieuw toe te voegen
  via "Toevoegen".

Stap 9 (printen) is nu ook klaar, met 2 afwijkingen van het oorspronkelijke
plan in sectie 3 - allebei bewust, zie hieronder:

1. De packages `pdf` + `printing` blijken onbruikbaar - hun
   `xml`-dependency botst onoplosbaar met `syncfusion_flutter_pdf` (die
   `xml ^7.0.1` vereist; elke `pdf`/`printing`-versie die dat aankan,
   vereist op zijn beurt Dart SDK >=3.12, terwijl dit project op 3.11.5
   zit).
2. Ryan wou achteraf geen downloadbare/opslaanbare PDF, maar een knop die
   meteen de systeem-printdialoog opent - en zelf voorgesteld om daarvoor
   gewoon HTML te gebruiken i.p.v. PDF, "wat voor mij het makkelijkst is".

Eerst gebouwd met `syncfusion_flutter_pdf` (die kan ook schrijven, niet
enkel lezen: `PdfDocument`/`PdfGrid`) + `FilePicker.saveFile` om op te
slaan - werkte, maar loste punt 2 niet op. Vervangen door een
HTML-gebaseerde aanpak (Ryans suggestie), die dat wél oplost:
- `lib/print/overzicht_html.dart` (`bouwOverzichtHtml`, pure Dart, geen
  Flutter-afhankelijkheid) bouwt een zelfstandige HTML-pagina: titel
  bovenaan, daaronder een tabel met dezelfde kolommen/rijen als het scherm
  zelf. Op uitdrukkelijke vraag van Ryan: de dag-kolom en de naam-header
  hebben een lichtgrijs vakje + dikkere tekst (CSS-klasse, zie `_stijl` in
  dat bestand) voor meer visueel onderscheid met de gewone databalken.
  Gebruikersinvoer (naam, omschrijving) wordt ge-escaped (`_escape`) zodat
  een rare tekens in bv. een omschrijving de tabel niet kan breken.
- `lib/print/printen.dart` + `printen_web.dart` + `printen_stub.dart`: een
  conditional-import-opzet (`export ... if (dart.library.html) ...`, het
  standaardpatroon in Flutter voor platform-specifieke code) rond een
  functie `printHtml(String html)`. De web-implementatie gebruikt
  `package:web` + `dart:js_interop` (al transitief aanwezig via de
  Firebase-webpackages, dus geen nieuwe dependency-conflicten) om de HTML
  in een onzichtbare iframe te laden en daarop `window.print()` aan te
  roepen - de bekende truc om iets anders dan de huidige pagina te printen
  zonder ernaartoe te navigeren. **Bewust niet `dart:html`/`dart:js_util`
  geprobeerd**: die zijn voor de analyzer in een gemengd Flutter-project
  (web + Android) ofwel onvolledig getypeerd (`Window`/`Document` missen
  dan `print`/`focus`/`open`/`write`/`close`) ofwel volledig onvindbaar
  (`dart:js_util`), ondanks dat de onderliggende JS-methodes wél bestaan -
  `package:web` is hiervoor de moderne, volledig getypeerde vervanger.
  Android (en elk ander niet-webplatform) heeft dit nog niet: de stub
  gooit een duidelijke `UnsupportedError` i.p.v. een knop die stilzwijgend
  niks doet - in de praktijk is de beheerder (Ryan) toch enkel via de
  webversie aan het printen, aangezien dat is waar een printer op
  aangesloten staat.
- `BeheerOverzichtScreen`: het PDF-icoontje in de AppBar is een
  print-icoontje geworden, roept nu `_printen()` (bouwt de HTML, geeft ze
  door aan `printHtml`) i.p.v. `_exporteren()` aan.

De oude PDF-aanpak (`lib/pdf_export/`, `test/pdf_export/`,
`FilePicker.saveFile`-gebruik) is volledig verwijderd i.p.v. laten staan
als dode code. Kleine opruiming die hierbij (al bij de eerste PDF-versie)
hoorde, en die nu ook door de HTML-versie hergebruikt wordt (een 3e
bijna-identieke tijd+omschrijving-tekststring dreigde te ontstaan):
`Dienst.naarTekst()` in `lib/models/dienst.dart` is de ene gedeelde plek
daarvoor (gebruikt door `DienstTile`, `BeheerOverzichtScreen` en de
HTML-export), en `naarDagLabel()` in `lib/util/datum_util.dart` idem voor
het "ma 08-07" dag-label. Getest: `test/print/overzicht_html_test.dart`
(nieuw, controleert titel/kolommen/rijen + dat gebruikersinvoer ge-escaped
wordt) + een echte print van juli 2026 gedaan via de UI met het
beheerder-testaccount (Ryan heeft zelf de "opslaan als PDF"-uitvoer van
zijn browser-printdialoog nagekeken: past nu zelfs op 1 A4-pagina, mooie
lay-out).

`.gitignore` heeft nu ook een regel voor `uurroosters/` (alles negeren
behalve de 2 echte, al getrackte PDF's) - puur om te voorkomen dat
test-exports die je daar zelf in zet om na te kijken (zoals hierboven)
per ongeluk meegecommit worden bij een volgende `git add`.

Meteen daarna nog 2 kleine correcties aan de print-CSS op vraag van Ryan
(na zelf eens afgedrukt te hebben): lettergrootte van de tabel 12px ->
14px (`th, td` in `lib/print/overzicht_html.dart`), en de "-" in een lege
dag/persoon-cel weggehaald (gewoon een lege cel i.p.v. een streepje).

Stap 10 (styling-polish) is ook gestart, met 2 concrete dingen die Ryan
vroeg:
- **Lege ruimte onder de menukaarten op `HomeScreen`**: opgevuld met een
  nieuwe "Volgende shift"-kaart (`_VolgendeShiftKaart` in
  `lib/screens/home_screen.dart`), die via dezelfde
  `DienstService.eigenDiensten`-stream als `ShiftenScreen` de
  eerstvolgende dienst (vandaag of later) van de ingelogde gebruiker
  toont - "Vandaag"/"Morgen" i.p.v. een kale datum waar relevant, en een
  nette "Niks gepland"-tekst als er niks aankomt. Bewust functioneel
  i.p.v. puur decoratief, zoals gevraagd ("nog wel functioneel").
- **`PdfUploadScreen`** kreeg dezelfde bosgroene kop-banner als
  `ShiftenScreen`/`BeheerOverzichtScreen` (was het enige overgebleven
  scherm met een vlakke witte achtergrond).

Geen foto's/afbeeldingen nodig gehad hiervoor (icoon+kleur volstond,
consistent met de rest van de app) - Ryan had aangeboden er een aan te
leveren, maar dat blijft een optie voor later als er een concrete plek
voor is.

### Firebase-project

- Project-id: `uurrooster-app`. Web-config staat in `.env` (niet
  gecommit), gebruikt via `--dart-define-from-file=.env` (zie
  `lib/firebase_options.dart` + README.md). **Elke `flutter run`/`build`
  moet die vlag meekrijgen, anders is Firebase niet verbonden.**
- Firestore-security rules staan in `firestore.rules` en zijn al
  gepubliceerd door Ryan in de Firebase Console.
- Bestaande accounts: `wytersryan@gmail.com` (Ryan, beheerder) en
  `claudetest@test.com` (testaccount van Ryan zelf, ook beheerder, naam
  "Claude" - enkel voor mij om mee te testen, geen echt gezinslid). Amy en
  mama hebben nog geen account (zie ACCOUNTS_AANMAKEN.md voor hoe die aan
  te maken).
- **Belangrijk:** voor een account écht een PDF-rooster kan importeren
  moet de beheerder ook de velden `roosterFormaat` ("A" of "B") en
  `naamInRooster` (letterlijke naam zoals in de PDF) manueel toevoegen aan
  dat account se `gebruikers`-document in Firestore (zie sectie 5 en
  ACCOUNTS_AANMAKEN.md) - dat gebeurt niet automatisch.
- `claudetest@test.com` staat ondertussen ingesteld op `roosterFormaat: B`
  + `naamInRooster: Amy` (zodat ik daarmee Formaat B kan blijven testen);
  Ryan's eigen account staat op `roosterFormaat: A` +
  `naamInRooster: Wyters, Ryan`. Amy's echte 25 shiften (juni-augustus
  2026) staan intussen ook echt in Firestore (`diensten`-collectie),
  geverifieerd via de "Al opgeslagen"-lijst op het uploadscherm.
- Android-app is nog niet geregistreerd in Firebase (enkel web-config
  aanwezig); dat moet nog gebeuren vlak voor de APK-build (fase 11).

### Belangrijke technische keuzes

- **Firebase-package-versies gepind** (`firebase_core: 4.7.0`,
  `firebase_auth: 6.4.0`, `cloud_firestore: 6.3.0`) omdat de nieuwste
  `firebase_core_web` (3.11.0, via firebase_core ^4.14.0) een
  dart2js-compilatiefout geeft op web. Niet zomaar upgraden zonder dit te
  testen.
- Eigen kleurenthema in `lib/theme.dart` (bosgroen/terracotta/crème,
  Fraunces + Work Sans via `google_fonts`) - bewust NIET het standaard
  Material 3 paars, want dat oogt meteen als "AI-starterproject".
  `debugShowCheckedModeBanner` staat uit.
- PDF-parsing gebeurt met `syncfusion_flutter_pdf`'s `PdfTextExtractor`,
  op basis van x/y-positie van elk tekstwoord (niet platte tekst) - de
  tabellen zijn enkel zo correct te ontleden. Syncfusion geeft losse
  spaties ook als eigen "woord" terug; die moeten altijd weggefilterd
  worden (`w.text.trim().isNotEmpty`) voor je op index/lengte rekent.
- Elke `RoosterParser`-implementatie (`FormaatAParser`, `FormaatBParser`)
  is getest tegen het bijhorende échte PDF-bestand in `uurroosters/` (die
  PDF's staan gewoon mee in git, zijn niet gevoelig). Bij een nieuw
  4e formaat: eerst met `pdfplumber` (Python) of een test tegen
  Syncfusion de echte coördinaten/tokens bekijken vóór je de parser
  schrijft - blind gokken op basis van platte tekst werkt niet.
- Elke `Dienst` heeft een eigen document-id zodat hij achteraf opnieuw
  opgezocht/gewijzigd kan worden (zie sectie 1 en 5) - dit is een
  expliciete, blijvende eis: PDF-import is nooit de enige manier waarop
  een dienst mag ontstaan of veranderen, de UI moet dit altijd toelaten.
- `Dienst.omschrijving` staat bij een PDF-import nooit leeg: gewone
  shiften krijgen `'Werk'`, een nachtshift (Formaat B, code "N") krijgt
  `'Nacht'`. `Dienst.datum` blijft intern ISO ("2026-07-04") voor opslag/
  sortering, maar UI-schermen tonen dat aan de gebruiker altijd als
  "DD-MM-JJJJ" (`naarWeergaveDatum` in `lib/util/datum_util.dart` - gedeeld
  hulpbestand, niet meer in `pdf_import/` want ook schermen gebruiken het
  nu) - en gebruik nergens het woord "Firestore" in tekst die mama/Amy te
  zien krijgen, dat zegt hen niks (gewoon "opslaan").
- Tijden altijd 24u-notatie (07:00, geen AM/PM) - ingesteld via een
  `MediaQuery`-override (`alwaysUse24HourFormat: true`) in de
  `MaterialApp.builder` in `lib/main.dart`, geldt dus automatisch voor elke
  `showTimePicker` in de app, ongeacht systeeminstellingen van het
  toestel.
- Gedeelde widgets/helpers i.p.v. kopiëren: `DienstTile`
  (`lib/widgets/dienst_tile.dart`) toont één dienst-rij, gebruikt door
  zowel het PDF-voorbeeld als het echte overzicht.

### Stijl / voorkeuren van Ryan

- Nederlandstalige comments, vrij informeel (geen droge board-room-taal).
  Ryan past de UI-teksten soms zelf aan om ze losser te maken (bv.
  "Mama's rooster app", "Zodat ons moeder ni meer hoeft te zagen!") - die
  aanpassingen blijven staan, niet terugzetten naar iets formeels.
  Redundante code en TODO-comments die Ryan zelf in de code zet, altijd
  even nakijken voor je verdergaat aan een nieuwe stap.
- Na elke stap: `flutter analyze` + `flutter test` + een visuele/
  functionele check (browser-tool of een test tegen een echt bestand),
  dan pas committen en pushen naar `main` (geen aparte branches).
- Nooit een account/wachtwoord voor Ryan aanmaken of zijn echte
  Google-wachtwoord gebruiken - enkel het expliciet gedeelde testaccount.

### Nog te doen (kort overzicht, zie sectie 10 voor volledig bouwplan)

Styling-polish, Android-registratie in Firebase + APK-build, webversie
hosten op Firebase Hosting.

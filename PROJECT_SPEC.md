# Project: Mama's rooster app (gezinsrooster)

Dit document beschrijft **wat de app nu is** (deel A), **hoe de eerste 4
features aangepakt zijn** (deel B, allemaal gedaan) en **hoe we de 7 nieuwe
features aanpakken** die Ryan daarna gevraagd heeft (deel C, nog te bouwen).
Het oude "bouwplan met fases" en het lopende logboek zijn eruit gehaald:
alles wat daarin stond is klaar en zit in de git-historiek
(`TripR27/uurrooster-app`, branch `main`).

---

# DEEL A — Wat er nu staat (as-built)

## 1. Doel

Een privé-gezinsapp waarin een handvol mensen (Ryan, zus Amy, mama) hun
werkrooster beheren. Een werkrooster komt binnen als PDF; de app leest de
uren eruit en slaat ze op. De beheerder (Ryan) kan een gezamenlijk,
printbaar maandoverzicht van iedereen genereren.

Naast PDF-import kan elk lid ook zelf iets toevoegen of corrigeren zonder
PDF (bv. een privé-afspraak). **Kernprincipe, blijvend:** PDF-import is
nooit de enige manier waarop een dienst kan ontstaan of veranderen — elke
dienst heeft een eigen Firestore document-id en is via de UI aan te passen
of te verwijderen.

## 2. Gebruikers & rollen

| Rol       | Wie              | Rechten (huidige situatie)                                                                 |
| --------- | ---------------- | ----------------------------------------------------------------------------------------- |
| Lid       | Amy, mama        | Inloggen, eigen PDF uploaden, eigen shiften bekijken/toevoegen/corrigeren/verwijderen     |
| Beheerder | Ryan             | Alles wat een lid kan + gezamenlijk overzicht van iedereen bekijken, printen én shiften van iedereen toevoegen/corrigeren/verwijderen (F3) |

Iedereen heeft een eigen account. Na inloggen weet de app automatisch wie
je bent (via de Firebase Auth uid → Firestore-profiel).

## 3. Techstack (zoals effectief gebruikt)

| Onderdeel            | Keuze                                             | Noot                                                            |
| -------------------- | ------------------------------------------------- | -------------------------------------------------------------- |
| App                  | Flutter (Dart, SDK `^3.11.5`)                     | 1 codebase → Android-APK + webversie                           |
| Auth                 | Firebase Authentication (e-mail + wachtwoord)     | `firebase_auth: 6.4.0` (gepind, zie §9)                        |
| Database             | Cloud Firestore                                   | `cloud_firestore: 6.3.0` (gepind)                              |
| PDF uitlezen         | `syncfusion_flutter_pdf: ^34.2.6`                 | leest tekst op x/y-positie, niet als platte tekst              |
| Printen (web)        | eigen HTML + onzichtbare iframe + `window.print()`| `pdf`/`printing` bleken onbruikbaar (xml-conflict, zie §9)     |
| Printen (Android)    | `syncfusion_flutter_pdf` genereert PDF + `share_plus` | deel-scherm van Android, "Printen" staat daar tussen       |
| Kalender             | `table_calendar: ^3.2.1`                          | vereist `initializeDateFormatting('nl_BE')` in `main()`        |
| Bestandskiezer       | `file_picker: ^12.2.0`                            |                                                                |
| Datums/locale        | `intl: ^0.20.3`                                   | directe dependency                                             |
| Fonts / thema        | `google_fonts` (Fraunces + Work Sans)            | bewust géén Material-3-paars, zie `lib/theme.dart`             |
| App-icoon            | `flutter_launcher_icons` (Ryans hondje)          | config onderaan `pubspec.yaml`                                 |
| Hosting webversie    | **niet gedaan** — enkel de APK wordt verspreid    |                                                                |

**Bewust vermeden:** Firebase Cloud Functions (vereist Blaze-plan +
creditcard). Alles gebeurt client-side → 100% gratis, geen betaalgegevens.

## 4. Datamodel (Firestore)

### Collectie `gebruikers` (doc-id = Firebase Auth uid)

```
{
  naam: string,                      // "Ryan", "Amy", "Mama"
  rol: "lid" | "beheerder",
  roosterFormaat: "A" | "B" | null,  // welke PDF-parser; niet automatisch ingevuld
  naamInRooster: string | null,      // letterlijke naam in de PDF; idem
  webuntisKlasId: number | null,     // WebUntis-klas-id (bv. 3905 = 3ITSOF1); F4
  webuntisMinor: string | null       // vak van de eigen minor (bv. MDI_IT_PROJIXREA); F4
}
```

`roosterFormaat` + `naamInRooster` worden **handmatig** door de beheerder
toegevoegd in de Firestore-console zodra bekend is welk PDF-formaat bij een
account hoort. Zonder die twee velden kan een account geen PDF importeren,
maar wel handmatig shiften toevoegen. `webuntisKlasId` + `webuntisMinor`
zijn idem handmatig (enkel Ryans account); zijn ze allebei gezet, dan
verschijnt de "Schoolrooster"-knop (F4, `Gebruiker.heeftSchoolrooster`).
Een nieuw profiel wordt automatisch aangemaakt bij de eerste login met
enkel `naam` + `rol: "lid"` (`GebruikerService.haalOfMaakProfiel`).

### Collectie `diensten`

```
{
  gebruikerId: string,      // → gebruikers/{uid}
  gebruikerNaam: string,    // gedenormaliseerd, handig voor overzicht/print
  datum: string,            // startdatum "2026-09-08" (ISO, sorteert als tekst)
  eindDatum: string | null, // laatste dag van een meerdaagse periode (F2); null = eendaags
  startTijd: string | null, // "09:00"; null als heleDag
  eindTijd: string | null,  // "17:00"; null = enkel een startuur bekend (F1) of heleDag
  heleDag: bool,            // duurt de hele dag, geen uren (F2)
  omschrijving: string,     // "Werk", "Nacht", "School", of vrije tekst; nooit leeg bij PDF-import
  bron: "pdf-import" | "handmatig" | "schoolrooster",
  aangemaaktOp: timestamp
}
```

Model in code: `lib/models/dienst.dart` (`Dienst`, enum `DienstBron`).

**Document-id-afspraak:**
- `bron: "pdf-import"` → id = `{gebruikerId}_{datum}` (1 PDF-shift per dag
  per persoon; herhaalde import overschrijft i.p.v. dupliceert).
  Geschreven via `DienstService.slaPdfImportOp` (batch `set`).
- `bron: "handmatig"` → auto-gegenereerd id via `.add()`
  (`DienstService.aanmaken`); meerdere per dag mogelijk.

## 5. Schermen

| Scherm | Bestand | Wat het doet |
| ------ | ------- | ------------ |
| AuthGate | `lib/auth_gate.dart` | luistert op `authStateChanges()`, toont login of home |
| Login | `lib/screens/login_screen.dart` | e-mail + wachtwoord, wachtwoord-toggle, split-layout op breed scherm, kop verbergt zich bij open toetsenbord. Geen registratie-optie. |
| Home | `lib/screens/home_screen.dart` | gekleurde kop (wie ben je + uitloggen) + menukaarten: "PDF uploaden", "Shiften bekijken", "Gezamenlijk overzicht" (enkel beheerder), + "Volgende shift"-kaartje |
| PDF uploaden | `lib/screens/pdf_upload_screen.dart` | kiest automatisch de juiste parser via `profiel.maakParser()`, toont voorbeeld, slaat pas op na bevestiging, popt terug met aantal |
| Mijn shiften | `lib/screens/shiften_screen.dart` | `table_calendar` maandweergave met bolletje op dagen met iets; tik een dag → lijst eronder; FAB "Toevoegen" |
| Toevoegen | `lib/screens/dienst_toevoegen_screen.dart` | embed van `DienstFormulier`; altijd `bron: handmatig`. Optioneel `voorGebruiker` (beheerder voegt toe voor iemand anders, F3). |
| Bewerken | `lib/screens/dienst_bewerken_screen.dart` | embed van `DienstFormulier` (`datumVast`), + verwijderen met bevestiging. |
| Formulier | `lib/widgets/dienst_formulier.dart` | gedeeld: "Met uren"/"Hele dag"-keuze, datum of datumbereik (range picker), Van/Tot-velden (× = enkel startuur), omschrijving. |
| Schoolrooster | `lib/screens/schoolrooster_screen.dart` | F4: maand kiezen → ophalen uit WebUntis → voorbeeld → opslaan. Enkel als `profiel.heeftSchoolrooster`; enkel op Android. |
| Gezamenlijk overzicht | `lib/screens/beheer_overzicht_screen.dart` | per maand (pijltjes), lijst dag-kaarten (1 regel per gezinslid), print-knop; tik een regel → bewerken, FAB → toevoegen voor een gezinslid (F3) |

Gedeelde bouwstenen: `lib/widgets/dienst_tile.dart` (één dienst-rij),
`lib/util/datum_util.dart` (ISO ↔ weergave-datum, dag-label),
`Dienst.naarTekst()` (de "09:00 - 17:00 (Werk)"-string, gedeeld door tile,
overzicht en export).

## 6. PDF-parsing

Adapter-patroon: `lib/pdf_import/rooster_parser.dart` definieert
`abstract class RoosterParser` + `enum RoosterFormaat { a, b }` +
`maakRoosterParser(...)`. Welke parser gebruikt wordt volgt uit het
profiel (`roosterFormaat` + `naamInRooster`).

- **Formaat A** — `lib/pdf_import/formaat_a_parser.dart`. Het
  "Dienstrooster"-PDF (Ryan & mama). Horizontale tabel: dag-kolommen
  bovenaan, personeelsnamen links. Werkt op x/y-positie van elk tekstwoord.
  Omschrijving altijd `"Werk"`. Getest tegen `uurroosters/uurrooster-ryan.pdf`.
- **Formaat B** — `lib/pdf_import/formaat_b_parser.dart`. Amy's
  Excel-geëxporteerde weekrooster. Datums als tekst links, per persoon een
  kolom. Uren als decimaal ("6,5" = 06:30). Code "N" = nachtshift →
  omschrijving `"Nacht"` (als 1 dienst op de startdag). Getest tegen
  `uurroosters/uurrooster-zus.pdf`.

Tests: `test/pdf_import/formaat_a_parser_test.dart`,
`test/pdf_import/formaat_b_parser_test.dart` (tegen de echte PDF's, die
staan mee in git — niet gevoelig).

## 7. Printen / export

- `lib/print/overzicht_html.dart` — `bouwOverzichtHtml(...)`, pure Dart:
  zelfstandige HTML-pagina, titel + tabel (1 kolom per gezinslid, 1 rij per
  dag). Gebruikersinvoer wordt ge-escaped.
- `lib/print/overzicht_pdf.dart` — `genereerOverzichtPdf(...)`,
  zwart-witte A4-PDF met `PdfGrid` (Android-tegenhanger).
- `lib/print/printen.dart` — conditional import:
  - web → `printen_web.dart`: HTML in onzichtbare iframe + `window.print()`
    (`package:web` + `dart:js_interop`).
  - Android/overig → `printen_stub.dart`: PDF genereren + `share_plus`
    deel-scherm.
  Gedeelde functie: `printOverzicht({maandStart, gebruikers, diensten})`.

Tests: `test/print/overzicht_html_test.dart`, `test/print/overzicht_pdf_test.dart`.

## 8. Firebase-project, config, build

- **Project-id:** `uurrooster-app`. Firestore-locatie `europe-west`.
- **Config niet in git.** Web-waarden in `.env`, Android in `.env.android`
  (Android heeft in Firebase een eigen `apiKey`/`appId`). Altijd meegeven:
  `flutter run -d chrome --dart-define-from-file=.env` resp.
  `flutter build apk --release --dart-define-from-file=.env.android`.
  `lib/firebase_options.dart` leest die via `String.fromEnvironment`.
- **Security rules:** `firestore.rules` (in git), al gepubliceerd in de
  console. Kern:
  - `gebruikers`: eigen profiel lezen + aanmaken (altijd `rol: "lid"`),
    naam aanpassen maar niet je eigen rol; beheerder leest alle profielen.
  - `diensten`: een lid leest/schrijft enkel zijn eigen; beheerder leest
    alles maar schrijft (voorlopig) niets van anderen.
  - Iemand beheerder maken = handmatig het veld `rol` op `beheerder` zetten
    in de console.
- **Accounts (Firebase Auth → Users):**
  - `wytersryan@gmail.com` — Ryan, beheerder, `roosterFormaat: A`,
    `naamInRooster: "Wyters, Ryan"`.
  - **Twee testaccounts voor Claude, met verschillende rol/config** - zo is
    zowel de beheerder- als de lid-kant van de app te testen, en zowel
    Formaat A als Formaat B PDF-import:
    - **Testaccount 1** — beheerder, `naamInRooster: "Amy"`,
      `roosterFormaat: B`, `webuntisKlasId`/`webuntisMinor` ingevuld (kan
      dus ook het schoolrooster (F4) testen). Gebruik dit account voor
      alles wat beheerder-rechten vereist (Beheer-tab, printen, F3) en
      voor Formaat B-/schoolrooster-import.
    - **Testaccount 2** — gewoon lid, `naamInRooster: "Wyters, Ryan"`,
      `roosterFormaat: A`. Gebruik dit account om de leden-kant te testen
      (wat een gewoon lid wel/niet mag zien of aanpassen, zie F8) en voor
      Formaat A-import.
    Geen van beide is een echt gezinslid. **De inloggegevens staan niet in
    dit document maar in `.env`** (Ryan beheert die zelf, met een
    commentaarregel erboven die zegt welk account welke rol/config heeft)
    — als Claude niet kan/mag inloggen (bv. Ryan is zelf aan het testen),
    staan de gegevens tijdelijk niet in `.env` of is er voor gevraagd even
    niet in te loggen; dan gewoon niet inloggen tot Ryan expliciet zegt
    dat het weer kan. Kies bij elke stap het account waarvan de rol/config
    past bij wat er getest moet worden.
  - Amy & mama: nog aan te maken door Ryan (Auth → Add user; daarna
    eventueel `roosterFormaat`/`naamInRooster` toevoegen). Amy's echte
    ~25 shiften (juni–aug 2026) staan wel al in Firestore.
- **APK-signing:** echte release-keystore `android/upload-keystore.jks` +
  `android/key.properties` (**beide gitignored**, bestaan alleen op deze
  machine — Ryan bewaart zelf een kopie). Ontbreken ze → build valt terug
  op debug-signing. `android/app/build.gradle.kts` regelt dat.
  App-label: "Mama's rooster app". Package: `com.tripr27.uurrooster_app`.
- **APK verspreiden:** nu handmatig (bestand doorsturen). Firebase App
  Distribution opzetten is een openstaand actiepunt, zie §11.

## 9. Belangrijke technische keuzes (kort)

- **Firebase-packages gepind** (`firebase_core: 4.7.0`, `firebase_auth:
  6.4.0`, `cloud_firestore: 6.3.0`): nieuwere `firebase_core_web` geeft een
  dart2js-compilatiefout op web. Niet upgraden zonder te testen.
- **`pdf` + `printing` niet bruikbaar:** hun `xml`-dependency botst met
  `syncfusion_flutter_pdf` (die `xml ^7.0.1` wil); nieuwere combinaties
  eisen Dart SDK ≥ 3.12 (project zit op 3.11.5). Daarom de HTML-/
  Syncfusion-aanpak voor printen.
- **PDF-parsing op x/y-positie**, niet platte tekst — de tabellen zijn
  alleen zo betrouwbaar te ontleden. Syncfusion geeft losse spaties als
  eigen "woord" → altijd `w.text.trim().isNotEmpty` filteren.
- **`Dienst.datum` blijft intern ISO**; schermen tonen "DD-MM-JJJJ"
  (`naarWeergaveDatum`). Nooit het woord "Firestore" in tekst die mama/Amy
  zien — gewoon "opslaan".
- **24u-tijdnotatie** overal, afgedwongen via `MediaQuery`-override
  (`alwaysUse24HourFormat: true`) in `lib/main.dart`.
- **Eigen thema** in `lib/theme.dart` (bosgroen / terracotta / crème,
  Fraunces + Work Sans). `debugShowCheckedModeBanner` uit.

## 10. Stijl / werkwijze-voorkeuren van Ryan

- Nederlandstalige comments, informeel. Ryan maakt UI-teksten soms losser
  ("Zodat ons moeder ni meer hoeft te zagen!") — die blijven staan, niet
  terugzetten naar iets formeels.
- Na elke stap: `flutter analyze` + `flutter test` + een visuele/
  functionele check (browser-tool of test tegen een echt bestand), dan pas
  committen en pushen naar `main` (geen aparte branches).
- Nooit een account/wachtwoord voor Ryan aanmaken of zijn echte
  Google-wachtwoord gebruiken — enkel het expliciet gedeelde testaccount.
- Redundante code / TODO-comments die Ryan zelf in de code zet: altijd even
  nakijken voor je verdergaat.

## 11. Openstaand actiepunt: Firebase App Distribution

Om nieuwe APK's makkelijker te verspreiden dan handmatig doorsturen. Vereist
acties van Ryan zelf in de Firebase/Google Cloud console. Twee opties:

**A (simpelst):** Firebase Console → project `uurrooster-app` → "Release &
Monitor" → "App Distribution" → inschakelen → tab "Testers & Groups" → groep
"gezin" + e-mailadressen. Bij elke nieuwe APK sleept Ryan die zelf naar
"Distribute new release".

**B (dan kan Claude zelf uploaden):** zelfde stap 1–2, plus in Google Cloud
Console → IAM → Serviceaccounts → nieuw account met rol "Firebase App
Distribution Admin" → JSON-key → aan Claude bezorgen (lokaal bewaren, nooit
committen). Daarna `firebase appdistribution:distribute` per build.

`firebase-tools` (npm) staat lokaal al geïnstalleerd.

---

# DEEL B — Nieuwe features: analyse & stappenplan

Vier gevraagde uitbreidingen — **allemaal gebouwd en getest** (F1, F2,
UX-opfrissing, F3, F4). Details per feature hieronder. Openstaand: Ryan
publiceert de F3-`firestore.rules` (gedaan volgens Ryan) en test F4 een
keer op zijn eigen Android-toestel.

Elke feature: eerst de code-wijziging, dan `flutter analyze` + `flutter
test` + visuele check via de browser-tool met het testaccount, dan commit +
push naar `main`. Firestore-rules-wijzigingen publiceert Ryan zelf.

## F1 — Alleen een startuur (geen einduur) ✅ GEDAAN

`eindTijd` is nu `String?` in `lib/models/dienst.dart`. `naarTekst()` toont
gewoon `"15:00"` (zonder "vanaf") als er geen einduur is. Toevoegen- en
Bewerken-scherm hebben een checkbox **"Alleen een startuur"** die de
"Tot"-rij verbergt en `eindTijd: null` opslaat. HTML/PDF-export en
"Volgende shift"-kaart volgen automatisch via `naarTekst()`. Geen migratie
nodig. Test: `test/models/dienst_test.dart`.

---

## F2 — Hele dag / meerdere dagen zonder uur ✅ GEDAAN

**Wens:** kunnen aanduiden dat iets de hele dag duurt, of meerdere dagen
(bv. "vakantie van 10 tot 15 september"), zonder uren.

**Wat gebouwd is:**

- **Model** (`lib/models/dienst.dart`): 2 velden erbij —
  `heleDag: bool` (default `false`) en `eindDatum: String?` (ISO, `null` =
  eendaags). `startTijd` is nu ook `String?` (null bij `heleDag`). Eén
  Firestore-document beslaat de hele periode.
  - `Dienst.valtOpDatum(isoDatum)` — of de (mogelijk meerdaagse) dienst op
    die dag valt. `Dienst.isMeerdaags`.
  - `naarTekst()`: `heleDag` → **enkel de omschrijving** (bv. `"Vakantie"`,
    terugval `"Hele dag"` als er geen omschrijving is).
- **Helper** `dagenVanTot(van, tot)` in `lib/util/datum_util.dart` (alle
  kalenderdagen van een reeks; zomer-/wintertijd-veilig via de
  `DateTime`-constructor).
- **Schermen** — overal waar `d.datum == dagIso` stond staat nu
  `d.valtOpDatum(dagIso)`:
  - `shiften_screen.dart` `_groepeerPerDag` → kalenderbolletje + dag-lijst
    op élke dag van de reeks.
  - `beheer_overzicht_screen.dart` `_dagKaarten`.
  - `overzicht_html.dart` + `overzicht_pdf.dart` (print).
  - `home_screen.dart` "Volgende shift": een lopende meerdaagse periode
    telt als aankomend, titel wordt "Bezig".
- **Toevoegen + Bewerken**: checkboxes **"Meerdere dagen"** (→ tweede
  datumkiezer "Tot en met", moet ≥ begindatum) en **"Hele dag"** (→
  verbergt van/tot + "alleen startuur"). Begindatum blijft niet-aanpasbaar
  in Bewerken (id-afspraak); de einddatum van een meerdaagse periode mag
  daar wél aangepast worden.
- **Migratie:** geen. Ontbrekende `heleDag`/`eindDatum`/`startTijd` →
  defaults (`false` / `null` / behouden) bij het inlezen.
- **Tests:** `test/models/dienst_test.dart`,
  `test/util/datum_util_test.dart`.

---

## UX toevoegen/bewerken — gedeeld formulier ✅ GEDAAN

`DienstToevoegenScreen` en `DienstBewerkenScreen` deelden bijna identieke
formulier-UI. Die zit nu in één widget `lib/widgets/dienst_formulier.dart`
(`DienstFormulier` + `DienstConcept`), die beide schermen embedden en
uitlezen via een `GlobalKey<DienstFormulierState>().currentState!.lees()`.
De schermen zelf houden enkel nog de opslaan-/verwijder-flow bij.

Nieuwe, opgefriste UX:
- **Segmented control** bovenaan: "Met uren" / "Hele dag" (vervangt de
  losse "Hele dag"-checkbox).
- **Eén datumveld** dat bij "Meerdere dagen" een `showDateRangePicker`
  opent — je duidt begin- én einddag ná elkaar aan in dezelfde kalender.
  De switch "Meerdere dagen" opent die kalender meteen. In Bewerken blijft
  de begindatum vast (`datumVast`); daar kies je enkel de einddag.
- **Uren** als twee tikbare velden naast elkaar ("Van" / "Tot"). Het
  "Tot"-veld heeft een ×-knopje: wegklikken = "enkel een startuur" (F1);
  het veld wordt dan een "+ Einduur"-knop om het terug toe te voegen. De
  aparte "Alleen een startuur"-checkbox is weg.
- Alles in nette, tikbare kaartvelden met de app-kleuren i.p.v. kale
  `ListTile`-rijen.

---

## F3 — Beheerder past shiften van iedereen aan ✅ GEDAAN

**Wens:** in "Gezamenlijk overzicht" mag de beheerder shiften van iedereen
aanpassen, niet enkel bekijken.

**Wat gebouwd is:**

- **`firestore.rules`** (`diensten`): `create`, `update` en `delete` staan
  nu ook `isBeheerder()` toe (naast "voor jezelf").
  → **Ryan moet de nieuwe rules publiceren in de Firebase Console** (tab
  Firestore Database → Rules → plak `firestore.rules` → Publish). Tot dan
  faalt het bewerken van andermans shift met een permissie-fout.
- **`beheer_overzicht_screen.dart`**:
  - Krijgt de ingelogde `profiel` mee (via `HomeScreen`).
  - Elke regel op een dag-kaart is tikbaar → `DienstBewerkenScreen` (die al
    met elke `Dienst` werkt, incl. verwijderen). Na terugkeer herlaadt het
    overzicht.
  - **FAB "Toevoegen"** → bottom sheet "Voor wie?" (lijst gezinsleden) →
    `DienstToevoegenScreen` met `voorGebruiker`.
- **`DienstToevoegenScreen`**: optionele `voorGebruiker` (naast `profiel`).
  Is die gezet, dan wordt de dienst met díé `gebruikerId`/`gebruikerNaam`
  aangemaakt en toont de titel "Toevoegen voor <naam>".
- `DienstService` ongewijzigd — schrijft gewoon de `gebruikerId` van de
  doelpersoon; de rules laten het toe.

---

## F4 — Ryans schoolrooster importeren via een knop in de app (WebUntis)

**Wens:** een knop in de app (bij PDF-import), enkel zichtbaar voor Ryan.
Je drukt erop, kiest een maand, en de app zet je schooldagen erin. Enkel
klas **3ITSOF1** + minor **Mixed Reality**. Niet de individuele lessen —
enkel **van wanneer tot wanneer ben ik die dag op school** (vroegste begin
→ laatste einde).

### Beslist (antwoorden Ryan)

- **Geen automatische cron.** Handmatige knop, per maand, met een voorbeeld
  vóór het opslaan — dezelfde flow als PDF-import.
- **Alleen zichtbaar voor Ryan.** Gate op een profielveld (zie datamodel
  hieronder); vandaag heeft enkel Ryans account dat.
- **Draait client-side in de app**, schrijft als de ingelogde gebruiker via
  de bestaande `DienstService`. **Geen** GitHub Actions, secrets,
  serviceaccount of rules-wijziging.
- **School-shiften zijn gewoon bewerkbaar** in de app. Opnieuw op de knop
  drukken voor dezelfde maand overschrijft ze (vast document-id
  `{uid}_school_{datum}`) — een handmatige aanpassing gaat dan verloren,
  dat is aanvaard.
- ⚠️ **Enkel op Android.** De webversie kan `ap.webuntis.com` niet
  rechtstreeks aanroepen (CORS — getest en bevestigd geblokkeerd). Net als
  bij printen is dat oké: Ryan gebruikt de Android-app. De knop verbergt
  zich op web (of toont een uitleg).

### Wat al uitgezocht is (reverse-engineering, bevestigd werkend)

De publieke WebUntis-API van AP Hogeschool is **anoniem** bereikbaar, geen
login nodig:

| Doel | Request |
| ---- | ------- |
| Klassenlijst | `GET https://ap.webuntis.com/WebUntis/api/public/timetable/weekly/pageconfig?type=1` |
| Weekrooster van een klas | `GET https://ap.webuntis.com/WebUntis/api/public/timetable/weekly/data?elementType=1&elementId=<id>&date=<YYYY-MM-DD>&formatId=1` |

- School-parameter: `ap`.
- **Klas 3ITSOF1 → `elementId = 3905`.**
- Response: `data.result.data.elementPeriods["3905"]` = lijst lesblokken.
  Per blok: `date` (`YYYYMMDD` als getal), `startTime` / `endTime` (`HHMM`
  als getal, bv. `900` = 09:00, `1730` = 17:30), `lessonCode`, `cellState`
  (`"STANDARD"` = normaal; anders geannuleerd/vervangen), `elements`
  (`[{type,id}]`, `type == 3` = vak). `data.result.data.elements` mapt
  vak-id → `name` / `longName`.
- **Minor Mixed Reality = vak `MDI_IT_PROJIXREA`** ("Project Mixed
  Reality"). De andere minors in dezelfde cohort, die Ryan **niet** volgt:
  `MDI_IT_PROJMAKER`, `MDI_IT_PROJROB`, `MDI_IT_PROJSTUP`.
- Belangrijk: het **klasrooster** van 3ITSOF1 bevat álle minors van de
  cohort door elkaar (allemaal aan dezelfde klassen gekoppeld). Er is
  anoniem géén persoonlijk rooster van Ryan op te vragen. Daarom moeten we
  filteren op vak.

### Filter-algoritme (per week; de knop lust een hele maand = 4–6 weken op)

1. Haal het weekrooster van klas 3905 op voor elke week die de gekozen
   maand raakt.
2. Gooi geannuleerde blokken weg (`cellState != "STANDARD"` /
   `lessonCode == "CANCEL"` / `code`-veld "cancelled").
3. Gooi blokken weg waarvan het vak in de **uitsluitlijst** zit
   (`PROJMAKER`, `PROJROB`, `PROJSTUP` — of algemener: elk `MDI_IT_PROJ*`
   dat niet `PROJIXREA` is).
4. Groepeer de rest per `date`, maar hou enkel dagen **in de gekozen
   maand**. Per dag: `start = min(startTime)`, `eind = max(endTime)`.
5. Maak per schooldag één `Dienst`: `datum`, `startTijd`/`eindTijd` als
   "HH:MM", `omschrijving: "School"`, `bron: "schoolrooster"`, document-id
   `{uid}_school_{datum}`.
6. Toon een **voorbeeld** (zoals bij PDF-import). Pas bij "Opslaan":
   - alle voorbeeld-diensten wegschrijven (`set`, overschrijft);
   - voor elke dag in de gekozen maand **zonder** lessen: een eventueel
     bestaand `{uid}_school_{datum}` verwijderen (les afgelast / vakantie).

Ryan bevestigt de vakkenlijst één keer tegen een echte, gekende week (die
halen we samen op).

**Caveat:** momenteel geeft de API enkel data terug voor het
najaarssemester 2025; latere maanden zijn nog niet gepubliceerd door AP.
De knop toont dan gewoon "geen lessen gevonden".

### Datamodel

- `enum DienstBron` krijgt `schoolrooster` erbij; `DienstBronWaarde` mapt
  `"schoolrooster"`. `vanWaarde` mag niet langer alles-behalve-pdf als
  `handmatig` behandelen.
- `Gebruiker` krijgt optionele velden `webuntisKlasId` (int, bv. `3905`) +
  `webuntisMinor` (string, bv. `MDI_IT_PROJIXREA`), handmatig gezet in de
  Firestore-console (zoals `roosterFormaat`/`naamInRooster` nu). De knop is
  enkel zichtbaar als die velden ingevuld zijn → vandaag alleen bij Ryan.
  De uitsluitlijst mag hardcoded als constante (klein, verandert zelden).
- Weergave: omschrijving `"School"`, eigen icoon/kleur in `DienstTile` en
  het overzicht (bv. een schooltas-icoon i.p.v. de kalender). School-items
  zijn gewoon aanpasbaar/verwijderbaar via `DienstBewerkenScreen`.

### Waar in de app

- **Nieuwe service** `lib/school/schoolrooster_service.dart`: `http`-calls
  naar de publieke WebUntis-API, filter-algoritme, geeft `List<Dienst>`
  terug voor een maand. Pure Dart, apart testbaar met een opgeslagen
  JSON-fixture.
- **Nieuw scherm** `lib/screens/schoolrooster_screen.dart`: maandkiezer
  (pijltjes, zoals `BeheerOverzichtScreen`) → "Ophalen" → voorbeeldlijst →
  "Opslaan". Zelfde look als `PdfUploadScreen`.
- **Ingang:** een derde kaart op `HomeScreen` naast "PDF uploaden", enkel
  als `profiel.webuntisKlasId != null`. (Niet in `PdfUploadScreen` zelf
  proppen — een eigen kaart is duidelijker.)
- **Platformcheck:** op web (`kIsWeb`) de kaart verbergen of disabelen met
  uitleg "werkt enkel in de Android-app".

### Stappenplan F4

| Stap | Status | Inhoud |
| ---- | ------ | ------ |
| **F4.1** | ✅ GEDAAN | Datamodel (`DienstBron.schoolrooster`, `Gebruiker.webuntisKlasId`/`webuntisMinor`/`heeftSchoolrooster`) + `lib/school/schoolrooster_service.dart` (`SchoolroosterService.haalMaand` = HTTP-orkestratie; `leesWeekrooster(...)` = pure filter; `schooldagNaarDienst(...)`) + `DienstService.slaSchoolroosterOp` (upsert + opruimen). Getest tegen een **echte** WebUntis-week (`test/school/fixtures/week_2025-11-03.json`) - de dag-vensters kloppen exact. |
| **F4.2** | ✅ GEDAAN | `lib/screens/schoolrooster_screen.dart` (maandkiezer → "Rooster ophalen" → voorbeeldlijst → "Opslaan"; op web een uitleg i.p.v. de knop) + kaart "Schoolrooster" op `HomeScreen` (enkel als `profiel.heeftSchoolrooster`) + schooltas-icoon in `DienstTile` voor `bron: schoolrooster`. |
| **F4.3** | ✅ GETEST | End-to-end op een Android-emulator (release-APK): inloggen → Schoolrooster → november 2025 → Ophalen (18 schooldagen, kloppende vensters) → Opslaan → verschijnen met schooltas-icoon in "Mijn shiften", bewerkbaar. Restant = eventuele bijsturing na Ryans test op zijn eigen toestel. |

### Beslist / bevestigd (F4)

- **Vakkenlijst:** Ryan volgt in 3ITSOF1 géén andere keuzevakken naast
  Mixed Reality. Filter = "alles behalve `MDI_IT_PROJ*` dat niet de eigen
  minor is". De minor mag in het profiel staan als `MDI_IT_PROJIXREA` óf
  gewoon `PROJIXREA` (de service normaliseert dat).
- **"School"-dagen** verschijnen overal zoals elke dienst — ook in mama's
  gezamenlijk overzicht en (voor de beheerder) bewerkbaar.
- **Geannuleerde lessen:** de filter negeert ze (`cellState` bevat
  "CANCEL" / `code` "cancelled" / `is.cancelled`). In het najaarssemester
  2025 stonden er geen annuleringen in het klasrooster, dus dit is enkel
  defensief gecodeerd, niet tegen echte geannuleerde data getest.
- **Caveat:** de API geeft momenteel enkel het najaarssemester 2025 terug;
  het rooster 2026-2027 is nog niet gepubliceerd door AP. Voor zo'n maand
  toont de knop gewoon "geen lessen gevonden".

---

# DEEL C — 7 nieuwe features: analyse & stappenplan (nog te bouwen)

Ryan heeft 7 uitbreidingen gevraagd (genummerd 1-7 in zijn bericht). Ze
hangen deels van elkaar af, dus deel C bouwt ze **niet in die volgorde** op
maar in bouwvolgorde: eerst 2 losse quick wins, dan de
zichtbaarheid/rechten-basis waar de rest bovenop bouwt, dan kleuren, dan
meldingen als laatste (grootste, nieuwe externe afhankelijkheid). Onderaan
staat de mapping + een overzichtstabel.

**Vooraf afgestemd met Ryan:**

- **Meldingen (zijn punt 5):** via een **gratis externe dienst** (OneSignal)
  i.p.v. een in-app-only meldingencentrum of Firebase Cloud Functions
  (Blaze-plan, bewust vermeden - zie §3). Zie F11.
- **Kleur in het gezamenlijk overzicht (zijn punt 3):** **iedereen kiest
  zelf** zijn/haar kleur, geen beheerder-toewijzing. Zie F9.

Zelfde werkwijze als deel B: per feature eerst de code-wijziging, dan
`flutter analyze` + `flutter test` + een visuele/functionele check
(browser-tool of Android-emulator met het testaccount), dan commit + push
naar `main`. Firestore-rules-wijzigingen publiceert Ryan zelf in de
console (zoals bij F3).

**Dit document wordt na élke stap bijgewerkt** (feature op ✅ GEDAAN zetten,
nieuwe deelbeslissingen/afwijkingen van het plan toevoegen) - zo kan Ryan in
een andere chat gewoon "lees PROJECT_SPEC.md en doe verder" zeggen zonder
eerst de hele geschiedenis te moeten navertellen.

## Nieuw gedeeld bouwblok: kleurenpalet

F9 en F10 hebben allebei een kleurkiezer nodig, met bewust weinig keuze
("een stuk of 10 basiskleuren"). Eén plek: `lib/util/kleuren_palet.dart` -
een vaste `List<(String naam, Color kleur)>` van 10 kleuren (bv. rood,
oranje, geel, groen, turquoise, blauw, paars, roze, bruin, grijs - exacte
tinten passend bij `AppKleuren`), + `kleurNaarHex`/`kleurVanHex` om een
gekozen kleur als string (`"#E0704F"`) in Firestore op te slaan. Eén
gedeelde widget `_KleurKiezer` (grid van gekleurde bolletjes, aangevinkt
bolletje toont een vinkje) - waarschijnlijk in datzelfde bestand of een
losse `lib/widgets/kleur_kiezer.dart`, hergebruikt door F9 en F10.

---

## F5 — Weekend-achtergrond bij het afdrukken (Ryans punt 6) ✅ GEDAAN

**Wens:** op het afgedrukte gezamenlijke overzicht moet een weekend-rij (het
hele rijtje, niet enkel het datumvakje) een lichtjes donkerdere/gekleurde
achtergrond hebben - mat, niet fel - zodat weekends meteen opvallen.

**Wat te bouwen:**

- **`lib/print/overzicht_html.dart`**: in de rij-loop, als
  `dag.weekday == DateTime.saturday || dag.weekday == DateTime.sunday`, een
  CSS-klasse `class="weekend"` op de `<tr>` zetten en in `_stijl` een regel
  `tr.weekend td { background: #F2E2D5; }` toevoegen - een lichte,
  gedempte terracotta-tint die bij `AppKleuren.terracotta` past maar mat
  genoeg blijft om leesbaar te blijven en print-vriendelijk (geen felle
  kleur, geen inkt-verspilling).
- **`lib/print/overzicht_pdf.dart`**: `PdfGrid` ondersteunt
  `cell.style.backgroundBrush` per cel. Na het vullen van een rij: als de
  dag een weekenddag is, voor elke cel in `rij.cells` (dag-kolom +
  gebruikerskolommen) `style.backgroundBrush = PdfSolidBrush(PdfColor(242,
  226, 213))` zetten (zelfde tint als hierboven, RGB-equivalent) - zodat de
  Android-PDF-export er hetzelfde uitziet als de webversie.
- **Tests:** `test/print/overzicht_html_test.dart` uitbreiden met een
  check dat een zaterdag/zondag-`<tr>` de `weekend`-klasse krijgt en een
  doordeweekse dag niet; `test/print/overzicht_pdf_test.dart` uitbreiden
  met een check op `backgroundBrush` van een weekend- vs. weekdag-cel.
- Geen datamodel- of rules-wijziging nodig - dit is zuiver
  presentatie-laag.
- **Bijkomende fix (ontdekt bij Ryans eigen test):** de weekend-kleur
  verscheen niet bij het afdrukken vanuit de browser. Oorzaak: browsers
  laten achtergrondkleuren standaard weg bij `window.print()`, tenzij de
  gebruiker zelf "Achtergrondafbeeldingen" aanvinkt in het printvenster.
  Opgelost met `print-color-adjust: exact` (+ `-webkit-`-variant) in
  `_stijl` in `overzicht_html.dart` - forceert dat achtergrondkleuren
  altijd meeprinten. Raakt enkel de webversie (`printen_web.dart`); de
  Android-PDF-export (`overzicht_pdf.dart`) kent dit probleem niet, die
  tekent de kleur rechtstreeks in het PDF-bestand.

---

## F6 — "ER" als geen-werk-code in Formaat A (Ryans punt 7) ✅ GEDAAN

**Wens:** in rooster-formaat A (Ryan & mama) komt ook de code "ER" voor
(vast gecontroleerd in `uurroosters/uurrooster-ryan.pdf`, rij "Blanpain,
Koen": `C8   ER 8u  FDrec  VAK`) - net als "FDrec" betekent dit: geen
werkdag, vakje moet leeg blijven.

**Wat er nu gebeurt:** `FormaatAParser._leesDienstenUitRij` groepeert per
dag-kolom de tekstlijnen (`cellen`) en behandelt enkel een groep van **3+
lijnen waarvan lijn 2 en 3 een geldige "HH:MM"-tijd zijn** als een
werkdienst; alles anders (leeg, of "FDrec" op 1 lijn) wordt al overgeslagen
via de bestaande `if (cellen.length < 3) continue;`-check. Voor "ER 8u"
(één lijn, geen apart begin-/einduur) werkt die check dus vermoedelijk al -
maar de code kijkt nooit expliciet naar wélke code er staat, dus een
toekomstige PDF-layout waarin "ER" wél met 2 tijd-achtige lijnen erna
staat, zou foutief als werkdienst ingelezen worden. Dat lossen we defensief
op, zoals Ryan vraagt ("moet geskipt worden als fdRecup").

**Wat te bouwen:**

- In `formaat_a_parser.dart`: een `_geenWerkCodePatroon = RegExp(r'^(fdrec|er)\b', caseSensitive: false)`.
  Vóór de bestaande lengte-/tijd-checks in `_leesDienstenUitRij`: als de
  **eerste** lijn van een dag-kolom (na sorteren op `top`) hierop matcht,
  die dag-kolom overslaan (`continue`) - ongeacht hoeveel lijnen erna
  volgen of wat erin staat.
- **Test:** nieuw testgeval in
  `test/pdf_import/formaat_a_parser_test.dart` tegen het **echte**
  bestand `uurroosters/uurrooster-ryan.pdf`, met
  `FormaatAParser(naamInRooster: 'Blanpain, Koen')` (die rij bevat de
  bevestigde "ER 8u" op de dag met `FDrec` ernaast) - controleren dat die
  specifieke dag geen dienst oplevert. Dat is meteen een test tegen
  échte data, in lijn met Ryans stijlvoorkeur (§10).
- Geen wijziging aan Formaat B (Amy) - dat is expliciet enkel voor
  Formaat A gevraagd.

---

## F7 — Beheerder-tab: zichtbaarheid per gezinslid (Ryans punt 2) ✅ GEDAAN

**Wens:** een beheerder-tabje waar Ryan per persoon kan aan-/uitvinken of
die persoon zichtbaar is in het gezamenlijke rooster. Onzichtbaar = die
persoon (en zijn/haar shiften) verschijnt nergens in het gezamenlijke
overzicht of de afdruk voor gewone leden - enkel beheerders zien hem/haar
nog.

**Datamodel:**

- `gebruikers`: nieuw veld `zichtbaarInOverzicht: bool` (default `true` als
  het veld ontbreekt - `Gebruiker.vanDocument` leest
  `data['zichtbaarInOverzicht'] as bool? ?? true`, geen migratie nodig).
  `lib/models/gebruiker.dart`.

**Nieuw scherm:** `lib/screens/beheer_instellingen_screen.dart` -
enkel bereikbaar voor de beheerder, via een nieuwe menukaart "Beheer" op
`HomeScreen` (enkel `if (profiel.isBeheerder)`). Toont **iedereen** uit
`GebruikerService.alleGebruikers()` (op naam gesorteerd) met per rij een
`SwitchListTile` gekoppeld aan `zichtbaarInOverzicht`, opgeslagen via de
nieuwe `GebruikerService.zetZichtbaarheid(uid, zichtbaar)`.

**Afwijking van het oorspronkelijke plan:** de beheerder zelf (en élke
andere beheerder, bv. het testaccount) staat wél gewoon mee in de lijst -
niet uitgesloten zoals eerst bedacht. Ryans eigen voorbeeld ("stel claude
is onzichtbaar") toont net dat ook een beheerder-account getoggled moet
kunnen worden om die voor gewone leden te verbergen; een beheerder ziet
altijd iedereen (los van dit veld), dus uitsluiten van jezelf uit de lijst
had geen zin.

Dit scherm krijgt in F11 een tweede sectie (meldingen) - vandaar de naam
"Beheer" i.p.v. "Zichtbaarheid", en vandaar dat dit vóór F8 gebouwd is:
F8's rules hebben dit veld al nodig.

**Firestore rules (`gebruikers`)** - aangepast in `firestore.rules`:

```
allow update: if (eigenGebruiker(uid) &&
    request.resource.data.rol == resource.data.rol) ||
  isBeheerder();
```

⚠️ **Nog te publiceren door Ryan** (zelfde stap als bij F3: Firebase
Console → Firestore Database → Rules → plakken → Publish). **Getest en
bevestigd in de browser:** met de oude, nog live rules kan de beheerder al
wél zijn/haar **eigen** profiel togglen (bv. het testaccount zelf), maar
een **andermans** profiel togglen (bv. Amy) faalt met een
`permission-denied`-snackbar tot de nieuwe rule gepubliceerd is - de
schakelaar herstelt dan netjes naar de echte serverstatus. Zodra Ryan
publiceert werkt het voor iedereen.

- **Test:** `test/models/gebruiker_test.dart` (default `zichtbaarInOverzicht
  == true`, en expliciet `false` blijft behouden). Geen widget-test voor
  het scherm zelf - dat roept rechtstreeks Firestore aan
  (`GebruikerService`/`FirebaseFirestore.instance`) zoals de rest van de
  app, en wordt zoals gebruikelijk via de browser-tool + het testaccount
  functioneel getest i.p.v. gemockt.

---

## F8 — Gezamenlijk overzicht zichtbaar voor iedereen (Ryans punt 1) ✅ GEDAAN

**Wens:** iedereen (niet enkel de beheerder) kan het gezamenlijke rooster
bekijken. Enkel de beheerder mag daarin dingen van **anderen** aanpassen -
een lid past, zoals nu al, enkel zijn/haar eigen shiften aan (via "Mijn
shiften" of door zijn/haar eigen regel in dit overzicht aan te tikken), en
ziet enkel zichzelf + de gezinsleden die de beheerder zichtbaar heeft gezet
(F7).

**Wat gebouwd is:**

- **`home_screen.dart`**: de menukaart "Gezamenlijk overzicht" staat nu
  altijd op het startscherm (niet langer enkel `if (profiel.isBeheerder)`).
- **`beheer_overzicht_screen.dart`** (bestandsnaam/klasnaam bewust
  ongewijzigd gelaten - een hernoeming is pure cosmetiek):
  - `_DagKaart`/`_regel` krijgt `profiel` mee en toont een chevron + laat
    enkel tikken toe als `profiel.isBeheerder || dienst.gebruikerId ==
    profiel.uid` - voor een gewoon lid is andermans regel puur
    informatief.
  - FAB "Toevoegen" en de print-knop staan enkel nog `if
    (widget.profiel.isBeheerder)` in de `AppBar`/`Scaffold` - dat is nooit
    voor gewone leden gevraagd en blijft dus buiten scope.
- **Firestore rules** (`eigenaarZichtbaar(gebruikerId)`-helper +
  aangepaste `read`-rules op zowel `gebruikers` als `diensten`) - zie de
  huidige `firestore.rules` in git, **al gepubliceerd door Ryan**.

**Bug gevonden en opgelost tijdens het testen (belangrijk voor later
werk met Firestore-lijst-queries):** `GebruikerService.alleGebruikers()`
doet een **ongefilterde** `.get()` op de hele `gebruikers`-collectie.
Firestore staat zo'n ongefilterde lijst-query enkel toe als de rule kan
**garanderen dat élk mogelijk document** in die collectie aan de rule
voldoet - en dat kan niet zodra de rule per document afhangt van dat
document zijn eigen, wisselende data (`zichtbaarInOverzicht`). Voor een
gewoon lid faalde die aanroep dus met een keiharde
`permission-denied` op de **hele** lijst, niet enkel op de onzichtbare
documenten.

**Fix:**
- Nieuwe `GebruikerService.zichtbareGebruikers(eigenUid)` (enkel voor
  gewone leden) doet een **wél gefilterde** query
  (`.where('zichtbaarInOverzicht', isEqualTo: true)`) - die matcht exact
  de leesrule, dus Firestore kan de query wél garanderen. Voegt daarna
  het eigen profiel toe als dat er nog niet in zat (bv. je bent zelf
  onzichtbaar gezet, maar mag jezelf natuurlijk wel zien).
  `beheer_overzicht_screen.dart` roept afhankelijk van de rol
  `alleGebruikers()` (beheerder) of `zichtbareGebruikers(uid)` (lid) aan.
- `GebruikerService.haalOfMaakProfiel` schrijft `zichtbaarInOverzicht:
  true` nu altijd **expliciet** mee bij het aanmaken van een nieuw
  profiel (i.p.v. te vertrouwen op de Dart-side default `true`) - anders
  zou zo'n nieuw account nooit matchen met de `isEqualTo: true`-query
  hierboven.
- **Bestaande profielen van vóór deze feature** (Ryan, mama) hadden het
  veld nog niet, en moesten dus éénmalig "geraakt" worden om het expliciet
  weg te schrijven - opgelost door Ryan zelf hun schakelaar in het
  Beheer-tab één keer om te zetten. Nieuwe accounts hebben dit euvel niet
  meer dankzij de fix hierboven.
- `DienstService.voorPeriode` had deze fix **niet** nodig: die doet al één
  losse, wél-gefilterde query per `gebruikerId`
  (`where('gebruikerId', isEqualTo: id)`), en zo'n query mét filter is
  voor Firestore altijd te garanderen - dat patroon bestond al sinds F3.

**Getest (browser, met het testaccount tijdelijk op `rol: "lid"` gezet):**
gezamenlijk overzicht opent zonder print-knop/FAB, Amy (onzichtbaar
gezet) verschijnt nergens, andermans regels (Mama) tonen geen chevron en
zijn niet tikbaar. Als beheerder blijft alles gewoon werken, ook voor een
persoon die op onzichtbaar staat (bevestigd door Amy tijdelijk onzichtbaar
te zetten en te controleren dat de beheerder haar nog steeds ziet).

- **Test:** geen aparte unit-test voor de rules zelf (geen
  Firebase-emulator opgezet in dit project) - functioneel geverifieerd in
  de browser zoals hierboven beschreven, met de rol van het testaccount
  tijdelijk omgezet door Ryan.

---

## F9 — Eigen kleur in het gezamenlijk overzicht (Ryans punt 3) ✅ GEDAAN

**Wens:** elk gezinslid kiest zelf een vaste kleur voor zijn/haar bolletje
in het gezamenlijke overzicht (Amy altijd roze, Ryan altijd groen, ...).

**Datamodel:** `gebruikers` krijgt `kleur: String?` (hex, bv. `"#E0704F"`),
`null` = nog geen kleur gekozen → dan de neutrale `kleurStandaardHex`
(grijs) tonen. `lib/models/gebruiker.dart`.

**Wat gebouwd is:**

- **Nieuw gedeeld bouwblok** `lib/util/kleuren_palet.dart`: `kleurenPalet`
  (10 vaste `(naam, hex)`-paren) + `kleurVanHex(hex)` (valt terug op
  `kleurStandaardHex` bij `null`/rommel). Bewust enkel hex-strings als bron
  van waarheid (geen `Color`→hex-conversie nodig) om geen afhankelijkheid
  te hebben van de exacte `Color`-API-vorm van deze Flutter-versie.
- **Nieuwe gedeelde widget** `lib/widgets/kleur_kiezer.dart`:
  `KleurKiezer` (grid van bolletjes, geselecteerde krijgt een vinkje) +
  `toonKleurKiezer(context, titel: ...)` (opent het als bottom sheet, geeft
  de gekozen hex terug) - **herbruikt in F10**, zoals gepland.
- **`beheer_overzicht_screen.dart`**:
  - `regels` draagt nu de volledige `Gebruiker` mee i.p.v. enkel de naam
    (`(Gebruiker gebruiker, Dienst dienst)`), zodat `_regel` het bolletje
    kan kleuren met `kleurVanHex(gebruiker.kleur)`.
  - Nieuwe `_Legende`-widget bovenaan het overzicht: bolletje + naam per
    zichtbaar gezinslid (F7), zodat je meteen weet welke kleur bij wie
    hoort.
  - "Mijn kleur"-knop in de appbar (een `CircleAvatar` in de eigen kleur,
    **voor iedereen zichtbaar**, niet enkel de beheerder) opent
    `toonKleurKiezer(...)` en slaat de keuze op via de nieuwe
    `GebruikerService.zetKleur(uid, hex)` - toegestaan door de **bestaande**
    rules (iedereen mag zijn eigen profiel bijwerken zolang `rol` niet
    verandert), geen rules-wijziging nodig. De knop houdt de gekozen kleur
    lokaal bij (`_eigenKleur`) zodat hij meteen bijwerkt, zonder op een
    volledige herlaad te wachten.

**Getest in de browser met beide testaccounts:** als beheerder een kleur
gekozen (bevestigd na page-reload dat ze echt opgeslagen staat, en dat het
gekozen bolletje een vinkje krijgt bij het heropenen), en als gewoon lid
(`claude2@test.com`) zonder beheerderrechten óók succesvol een eigen kleur
gezet - bevestigt dat de bestaande self-update-rule volstaat.

- **Test:** `test/util/kleuren_palet_test.dart` (10 unieke kleuren,
  `kleurVanHex` correct/fallback-gedrag), `test/models/gebruiker_test.dart`
  uitgebreid met `kleur`-default (`null`) en expliciete waarde.

---

## F10 — Eigen kleur per item in de persoonlijke agenda (Ryans punt 4) ✅ GEDAAN

**Wens:** los van de vaste "wie ben ik"-kleur uit F9, wil Ryan per item in
zijn **eigen** agenda een eigen kleurtje kunnen kiezen (werk = blauw,
privé = roze, een vakantie = groen, ...) - dus per `Dienst`, niet per
gebruiker. Ook toepasbaar bij zowel PDF-import als het schoolrooster
(WebUntis)-import, niet enkel bij handmatig toevoegen.

**Datamodel:** `diensten` krijgt `kleur: String?` (hex), `null` = nog geen
kleur gekozen → de neutrale `kleurStandaardHex` tonen. Bewust **losstaand**
van `gebruikers.kleur` (F9) - dat blijft enkel de "wie ben ik"-kleur in het
gezamenlijke overzicht. `lib/models/dienst.dart`.

**Wat gebouwd is:**

- **`Dienst.kleur`** + `naarDocument()`/`vanDocument()` uitgebreid (zelfde
  patroon als `eindDatum`/`heleDag` in F2 - geen migratie nodig). Nieuwe
  `Dienst.metKleur(hex)` (kopie met enkel de kleur gewijzigd) - gebruikt om
  na een PDF-/schoolrooster-import een gekozen kleur op de hele
  al-ingelezen batch toe te passen, vóór het opslaan.
- **`dienst_formulier.dart`**: `KleurKiezer` (uit F9) toegevoegd onder
  "Omschrijving", `DienstConcept.kleur` erbij - gebruikt door zowel
  Toevoegen als Bewerken. `dienst_toevoegen_screen.dart`/
  `dienst_bewerken_screen.dart` geven `concept.kleur` mee aan de
  opgeslagen `Dienst`.
- **`dienst_tile.dart`**: het leading-icoon (kalender/schooltas) krijgt nu
  `kleurVanHex(dienst.kleur)` als kleur i.p.v. de standaard iconkleur -
  bewust het bestaande icoon hergebruikt (bron blijft zo herkenbaar) i.p.v.
  er een apart gekleurd streepje naast te zetten.
- **`shiften_screen.dart`**: `calendarStyle.markerDecoration` (vaste
  `AppKleuren.terracotta`) vervangen door
  `calendarBuilders.markerBuilder<Dienst>` - één bolletje per dienst die
  dag (tot 4, om overflow te vermijden bij een drukke dag), elk in de
  eigen `kleurVanHex(dienst.kleur)`.
- **PDF-/schoolrooster-import** (`pdf_upload_screen.dart`,
  `schoolrooster_screen.dart`): na het inlezen/ophalen, vóór "Opslaan",
  een `KleurKiezer` ("Kleur voor deze import") die met
  `Dienst.metKleur(hex)` **op de hele batch tegelijk** wordt toegepast (de
  voorbeeldlijst update meteen mee) - nadien is elk item nog individueel
  aan te passen via Bewerken. Het "laatst gebruikte kleur"-idee uit het
  oorspronkelijke plan is **niet** gebouwd (bleef een nice-to-have, geen
  harde eis, en de eenvoudige versie volstaat).
- **Print**: bewust **niet** aangepast - niet gevraagd, buiten scope.

**Getest in de browser** (`claude2@test.com`, gewoon lid): via "Toevoegen"
een item met een kleur aangemaakt - de kleurkiezer in het formulier werkt,
het bolletje in de kalender én het icoon in de lijst tonen meteen de
gekozen kleur, en bij het heropenen om te bewerken staat de juiste kleur
aangevinkt. Nadien opgeruimd (verwijderd).

⚠️ **Niet end-to-end getest: de kleurkiezer bij een échte PDF-/
schoolrooster-import.** De browser-tool die Claude gebruikt kan het
native bestandskiezer-dialoogvenster van `file_picker` niet bedienen (dat
valt buiten de webpagina zelf), dus een PDF kiezen en uploaden lukt niet
vanuit deze tool. De onderliggende code is identiek aan wat wél getest is
(dezelfde `KleurKiezer`/`metKleur`), maar Ryan test dit best zelf één keer
- bv. bij de volgende echte PDF-import of schoolrooster-ophaling - om te
bevestigen dat de kleurkiezer daar ook verschijnt en werkt zoals verwacht.

- **Test:** `test/models/dienst_test.dart` uitgebreid met `kleur`-
  serialisatie + `metKleur` (nieuwe kopie, origineel blijft ongewijzigd).

---

## F11 — Meldingen voor de beheerder via OneSignal (Ryans punt 5) ✅ GEDAAN, push bevestigd op een echt toestel (Android-emulator, zie F12)

**Wens:** de beheerder krijgt een melding wanneer iemand iets invult - 1
melding per PDF-import (batch, niet per losse shift) en 1 melding per
handmatig toegevoegd item. Aan/uit te zetten per persoon én algemeen, in
het beheerder-tab (F7's scherm). **Bevestigd door Ryan:** dit is enkel
voor hemzelf als beheerder bedoeld, en de APK gaat toch enkel naar het
gezin via Firebase App Distribution - het risico van de REST-key in de
app (zie hieronder) weegt dus niet zwaar.

**Waarom niet gewoon Firebase:** zie de oorspronkelijke analyse hieronder
- ongewijzigd, uiteindelijk zo gebouwd.

**Gekozen dienst: [OneSignal](https://onesignal.com)**, App-ID
`d630cfd0-a267-487d-ae04-850de535d303`. Android gekoppeld aan hetzelfde
Firebase-project (`uurrooster-app`) via een Firebase-service-account-JSON
(Firebase Console → Projectinstellingen → Service accounts → Generate new
private key), die Ryan rechtstreeks bij OneSignal geüpload heeft. Web is
bewust **niet** aangevinkt in OneSignal (de webversie wordt toch niet
publiek gehost) - de app initialiseert OneSignal dan ook enkel op Android
(`if (!kIsWeb)`), zowel in `main.dart` als `auth_gate.dart`.

**Datamodel** (`lib/models/gebruiker.dart`):

- `meldingenAan: bool` (default `true`) - of acties van **deze persoon**
  een melding naar de beheerder(s) sturen. Instelbaar per persoon
  (iedereen, ook beheerders) in het Beheer-tab.
- `wilMeldingen: bool` (default `true`) - enkel relevant als dit account
  zelf beheerder is: de algemene "ik wil meldingen ontvangen"-schakelaar,
  enkel bewerkbaar voor de ingelogde beheerder over zijn eigen profiel.
- **Nieuwe `Gebruiker.copyWith(...)`** - de optimistische UI-update in het
  beheer-tab (uit F7) reconstrueerde tot dan een `Gebruiker` handmatig
  veld per veld, wat `kleur` (F9) stilletjes zou gewist hebben zodra er
  een tweede toggle-veld bijkwam. `copyWith` lost dat structureel op en
  wordt nu voor alle drie de toggles (zichtbaarheid, meldingenAan,
  wilMeldingen) gebruikt.

**Wat gebouwd is:**

- **Dependency** `onesignal_flutter: ^5.6.10` in `pubspec.yaml` (exacte
  stabiele versie opgehaald via OneSignal's officiële releases-JSON,
  zoals hun eigen AI-integratie-instructies voorschrijven). Android:
  `<uses-permission android:name="android.permission.INTERNET" />`
  toegevoegd aan `AndroidManifest.xml` (`compileSdk`/`minSdk` komen al via
  Flutter's eigen defaults ruim boven OneSignal's minimum). **Geen**
  `google-services.json`/Google-Services-plugin toegevoegd - OneSignal
  regelt FCM-registratie zelf, en dat zou conflicteren met hoe dit project
  Firebase al configureert (`.env`/`.env.android`, geen `google-services.json`).
- **`.env`/`.env.android`**: `onesignalAppId` (publiek) en
  `onesignalRestApiKey` (gevoelig) - zelfde behandeling als de
  Firebase-sleutels, nooit gecommit.
- **`main.dart`**: `OneSignal.initialize(oneSignalAppId)` vóór `runApp()`,
  enkel op Android (`!kIsWeb`) en enkel als de App-ID niet leeg is.
- **`auth_gate.dart`**: `OneSignal.login(uid)` (koppelt het toestel aan de
  Firebase-uid als "External ID") + `OneSignal.Notifications.
  requestPermission(true)` zodra iemand ingelogd is; `OneSignal.logout()`
  bij het uitloggen (anders zou een volgend testaccount op hetzelfde
  toestel nog aan de vorige gekoppeld blijven). Een module-level
  `_laatstGekoppeldeUid` voorkomt dat elke rebuild opnieuw koppelt.
- **Nieuwe service** `lib/services/melding_service.dart`:
  - `bepaalOntvangers(List<Gebruiker> gezinsleden, Gebruiker acteur)` -
    **pure functie, apart unit-getest** (5 testgevallen: normaal geval,
    enkel beheerders, `wilMeldingen == false`, `meldingenAan == false`,
    nooit jezelf).
  - `stuurMelding({required Gebruiker acteur, required String tekst})` -
    haalt `GebruikerService.zichtbareGebruikers(acteur.uid)` op (bestond
    al sinds F8, werkt voor beide rollen - geen nieuwe rules nodig), filtert
    via `bepaalOntvangers`, en post naar
    `https://api.onesignal.com/notifications` met `Authorization: Key
    <rest-key>` en `include_aliases: {external_id: [...]}` +
    `target_channel: "push"` (geverifieerd tegen OneSignal's actuele
    REST-documentatie - de oudere `onesignal.com/api/v1/...`-vorm en een
    `Basic`-header staan nog wel gedocumenteerd op oudere plekken, maar
    zijn niet meer de aanbevolen vorm). Faalt dit, dan wordt dat volledig
    genegeerd (`try/catch`) - de dienst zelf is dan al opgeslagen.
- **Aanroeppunten**, telkens **niet-awaited** (`unawaited(...)`, een
  melding mag de opslaan-flow niet vertragen) en enkel wanneer iemand
  **voor zichzelf** iets invult:
  - `pdf_upload_screen.dart`, na `slaPdfImportOp`.
  - `schoolrooster_screen.dart`, na `slaSchoolroosterOp`.
  - `dienst_toevoegen_screen.dart`, na `aanmaken`, **enkel als
    `widget.voorGebruiker == null`** (F3-toevoegingen door de beheerder
    voor iemand anders sturen geen melding - die weet het al).
- **`beheer_instellingen_screen.dart`** (F7): tweede sectie "Meldingen" -
  bovenaan de algemene schakelaar "Ik wil meldingen ontvangen"
  (`wilMeldingen`, enkel de eigen rij), daaronder per gezinslid een
  schakelaar "Stuurt meldingen bij een actie" (`meldingenAan`). Terzelfder
  tijd de lijst-laadlogica herschreven (`_laadFuture` enkel voor de
  initiële laadstatus, een apart `_lijst`-veld voor de optimistische
  updates) - anders sprong de lijst bij elke toggle terug naar boven
  (de `FutureBuilder` ging eventjes terug naar "laden"), wat met nu 11
  rijen (5 zichtbaarheid + 1 algemeen + 5 meldingen) te veel opviel.

**Getest in de browser** (beheerder-testaccount): beide secties in het
Beheer-tab renderen, alle toggles (algemeen + per persoon) slaan op en
overleven een herlaad, scrollpositie blijft nu behouden na een toggle.

✅ **Ondertussen bevestigd: er komt écht een pushmelding aan.** Getest op
een Android-emulator (zie F12 hieronder voor de details, incl. een
config-gat dat daarbij aan het licht kwam en opgelost is).

- **Test:** `test/services/melding_service_test.dart` (5 gevallen voor
  `bepaalOntvangers`), `test/models/gebruiker_test.dart` uitgebreid met
  `meldingenAan`/`wilMeldingen`-defaults + `copyWith`.

---

## F12 — Beheer-tab herbouwd: meldingen per gezinslid in een pop-up, bulk/single gesplitst, gezamenlijk overzicht per persoon verbergen ✅ GEDAAN

**Wens (Ryan, na F11):** het Beheer-tab simpeler: gewoon een lijst van alle
gezinsleden met een "Beheer"-knop ernaast. Die knop opent een pop-up met
alles wat voor die ene persoon instelbaar is:

- bulk-pushmeldingen (PDF-/schoolrooster-import) apart aan/uit van
- single-pushmeldingen (handmatig iets toevoegen) - dit waren tot nu toe
  één en dezelfde schakelaar (`meldingenAan`, F11);
- onzichtbaar maken voor anderen (bestond al, F7/F8);
- het gezamenlijke overzicht voor die persoon zélf verbergen (nieuw - los
  van "onzichtbaar voor anderen": dat laatste gaat over hoe *anderen* deze
  persoon zien, dit nieuwe veld over of deze persoon het overzicht zelf
  nog mag *openen*).

Daarboven een algemene "alle meldingen"-schakelaar (de bestaande
`wilMeldingen`, F11) die - als ze uitstaat - de twee meldingen-schakelaars
in elke pop-up locked (grijs, niet aanpasbaar, waarde blijft gewoon staan
zoals ze stond) zodat duidelijk is dat er sowieso niks verstuurd wordt
zolang die algemene schakelaar uitstaat.

**Datamodel** (`lib/models/gebruiker.dart`):

- `meldingenAan` (F11) vervangen door twee losse velden:
  `meldingenBulkAan` (PDF-/schoolrooster-import) en `meldingenSingleAan`
  (handmatig toevoegen), allebei default `true`. `Gebruiker.vanDocument`
  valt terug op het oude `meldingenAan`-veld als de nieuwe nog ontbreken
  (`data['meldingenBulkAan'] ?? data['meldingenAan'] ?? true`) - zo gaat
  een eerder bewust uitgezette melding niet stilletjes weer aan bij
  bestaande profielen, zonder dat er een migratiescript nodig is.
- Nieuw veld `gezamenlijkOverzichtVerborgen: bool` (default `false`) - of
  dit account het gezamenlijke overzicht zelf mag openen.
- `copyWith` uitgebreid met alle vier de nieuwe/gewijzigde velden.

**Services:**

- `MeldingService.bepaalOntvangers`/`stuurMelding` krijgen een verplichte
  `isBulk`-parameter, en kijken naar `meldingenBulkAan` resp.
  `meldingenSingleAan` van de acteur i.p.v. het oude ene veld.
  Aanroeppunten: `pdf_upload_screen.dart`/`schoolrooster_screen.dart` →
  `isBulk: true`, `dienst_toevoegen_screen.dart` → `isBulk: false`.
- `GebruikerService`: `zetMeldingenAan` vervangen door
  `zetMeldingenBulkAan`/`zetMeldingenSingleAan`; nieuwe
  `zetGezamenlijkOverzichtVerborgen`. Zelfde rules als de bestaande
  per-persoon-velden (beheerder mag alles, zie firestore.rules `gebruikers`
  update-rule uit F7) - geen rules-wijziging nodig.

**`beheer_instellingen_screen.dart`** volledig herbouwd:

- Bovenaan enkel nog de algemene "Alle meldingen ontvangen"-schakelaar
  (`wilMeldingen`).
- Daaronder een simpele lijst (`_GebruikerRij`): naam + rol + een
  "Beheer"-knop die `_GebruikerBeheerDialoog` opent (een `AlertDialog` met
  de 4 schakelaars voor die ene persoon). De pop-up houdt een eigen lokale
  kopie van de 4 waarden bij (optimistisch bijwerken + foutmelding +
  herstel bij mislukken, zelfde patroon as overal in de app), en meldt elke
  geslaagde wijziging terug aan het hoofdscherm (`onGewijzigd`) zodat de
  lijst declaratief meebeweegt zonder een volledige herlaad.
- **Extra (op vraag van Ryan tijdens het testen):** een onzichtbaar
  gezinslid krijgt in die lijst een lichtjes gedempte, taupe achtergrond
  (`_GebruikerRij._gedempteAchtergrond`) + een doorstreept-oog-icoontje
  naast de naam, zodat meteen zichtbaar is wie onzichtbaar staat zonder de
  pop-up te moeten openen. Onzichtbare/verborgen gezinsleden krijgen ook
  een klein terracotta "status-chipje" ("Onzichtbaar voor anderen" /
  "Overzicht verborgen") onder hun naam. De lijst sorteert bovendien
  zichtbare gezinsleden eerst, onzichtbare onderaan (beide op naam).
- **`home_screen.dart`**: de menukaart "Gezamenlijk overzicht" staat nu
  `if (!profiel.gezamenlijkOverzichtVerborgen)`.

**Bijgevonden en opgelost tijdens het bouwen (geen bug in de nieuwe code,
maar een layout-valkuil):** een `ListTile` met een `FilledButton`/
`FilledButton.tonal` als `trailing`, in een `Row` zonder `Expanded`, knalt
op web/Flutter met "Trailing widget consumes the entire tile width" resp.
een oneindige-breedte-assertion - want het globale `filledButtonTheme` (zie
`theme.dart`) zet `minimumSize: Size.fromHeight(48)` (bewust, voor de
volle-breedte-CTA-knoppen elders in de app), wat impliciet een oneindige
*minimumbreedte* betekent zodra zo'n knop níet in een `Expanded`/volle
breedte staat. Opgelost door (a) de gezinsledenlijst als eigen `Row`/
`Column`-layout te bouwen i.p.v. `ListTile`, en (b) de "Beheer"-knop een
eigen `FilledButton.styleFrom(minimumSize: Size(64, 40))` te geven. Goed
om te onthouden voor een volgende niet-volle-breedte-`FilledButton`
ergens anders in de app.

**Config-gat gevonden en opgelost (belangrijk voor volgende Android-tests):**
`.env.android` bevatte enkel de Firebase-sleutels, niet
`onesignalAppId`/`onesignalRestApiKey` (die stonden enkel in `.env`, voor
web). Op Android crashte `OneSignal.login(uid)` in `auth_gate.dart`
daardoor met `PlatformException: Must call 'initWithContext' before
'login'` (de OneSignal-initialisatie in `main.dart` slaat zichzelf immers
over als de App-ID leeg is). **Opgelost:** dezelfde twee regels als in
`.env` ook aan `.env.android` toegevoegd (nooit gecommit, net als de rest
van dat bestand).

**Getest:**

- **Browser** (beide testaccounts): pop-up opent met alle 4 schakelaars in
  de juiste stand, elke schakelaar slaat op en overleeft een herlaad, de
  algemene schakelaar locked de twee meldingen-schakelaars in de pop-up
  (grijs, niet aanklikbaar) zolang ze uitstaat, de lijst sorteert
  onzichtbare gezinsleden onderaan en toont meteen de gedempte
  achtergrond/chips, en `claude2@test.com` verliest de menukaart
  "Gezamenlijk overzicht" zodra `gezamenlijkOverzichtVerborgen` voor dat
  account aanstaat (en krijgt ze terug zodra dat weer uitstaat).
- **Android-emulator, écht op het toestel:** ingelogd als
  `claude@test.com` (beheerder), systeem-pop-up voor meldingen
  toegestaan. Vanuit de browser als `claude2@test.com` (gewoon lid) iets
  handmatig toegevoegd → de pushmelding kwam binnen enkele seconden aan op
  de emulator, met de verwachte specifieke tekst (`Claude2 heeft "19:42 -
  20:42 (Echte push test)" toegevoegd.`). Daarna `meldingenSingleAan` voor
  Claude2 uitgezet via het Beheer-tab en opnieuw iets toegevoegd: **geen**
  nieuwe melding deze keer (enkel de oude nog zichtbaar in de
  notificatiebalk) - bevestigt dat de per-persoon-schakelaar de push ook
  écht blokkeert, niet enkel in de `bepaalOntvangers`-unit-tests. Nadien
  alles teruggezet naar de oorspronkelijke stand.
- ⚠️ **Niet end-to-end getest: de bulk-melding (PDF-/schoolrooster-import)
  op een echt toestel** - zelfde beperking as bij F10: de browser-tool kan
  het native bestandskiezer-dialoogvenster van `file_picker` niet bedienen,
  dus een PDF kiezen vanuit de geautomatiseerde test lukt niet. De
  onderliggende code is identiek aan het single-pad (enkel `isBulk: true`
  i.p.v. `false`, en dat pad is wél end-to-end bevestigd) - Ryan test dit
  best zelf één keer bij de volgende echte PDF-import.
- **Test:** `test/services/melding_service_test.dart` uitgebreid (bulk vs.
  single apart getest, incl. "bulk uit maar single werkt nog wel" en
  omgekeerd), `test/models/gebruiker_test.dart` uitgebreid met
  `meldingenBulkAan`/`meldingenSingleAan`/`gezamenlijkOverzichtVerborgen`-
  defaults + de uitgebreide `copyWith`.

---

## Mapping & bouwvolgorde

| Ryans nr. | Wens (kort) | Feature | Bouwvolgorde |
| --- | --- | --- | --- |
| 6 | Weekend-achtergrond bij printen | F5 | 1 - los, snel |
| 7 | "ER"-code overslaan (Formaat A) | F6 | 2 - los, snel |
| 2 | Beheerder-tab: zichtbaarheid per persoon | F7 | 3 - basis voor F8 |
| 1 | Gezamenlijk rooster zichtbaar voor iedereen | F8 | 4 - bouwt op F7 |
| 3 | Eigen kleur bolletje (gezamenlijk, zelf te kiezen) | F9 | 5 - bouwt op F8's scherm |
| 4 | Eigen kleur per item (persoonlijke agenda) | F10 | 6 - hergebruikt F9's palet |
| 5 | Meldingen naar beheerder (OneSignal) + toggles | F11 | 7 - grootste, nieuwe dependency, bouwt op F7's scherm |
| - | Beheer-tab herbouwd: pop-up per gezinslid, bulk/single-meldingen, overzicht verbergen | F12 | 8 - bouwt op F7/F11's scherm |

Per feature: code → `flutter analyze` + `flutter test` → visuele/
functionele check → commit + push. F7 en F8 vereisen telkens een
rules-publicatie door Ryan (zoals F3); F11 vereist eerst een gratis
OneSignal-account + App-ID/REST-key van Ryan voordat die feature gebouwd
kan worden.

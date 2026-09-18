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

## F9 — Eigen kleur in het gezamenlijk overzicht (Ryans punt 3)

**Wens:** elk gezinslid kiest zelf een vaste kleur voor zijn/haar bolletje
in het gezamenlijke overzicht (Amy altijd roze, Ryan altijd groen, ...).

**Datamodel:** `gebruikers` krijgt `kleur: String?` (hex, bv. `"#E0704F"`),
`null` = nog geen kleur gekozen → dan een neutrale standaardkleur tonen
(bv. `AppKleuren.bosgroen`, de huidige hardcoded kleur).

**Wat te bouwen:**

- **`beheer_overzicht_screen.dart` → `_DagKaart`**: het hardcoded
  `AppKleuren.terracotta`-bolletje (regel ~327) wordt
  `Color(int.parse((kleurHex ?? '#1F6F5C').substring(1), radix: 16) +
  0xFF000000)` (of via de `kleurVanHex`-helper uit F9's palet-bestand) -
  gebaseerd op de kleur van de **eigenaar** van die regel (elke regel toont
  al `(naam, dienst)`, dus de bijhorende `Gebruiker.kleur` moet meegegeven
  worden vanaf `_Overzicht`/`_dagKaarten`).
- **Zelf instellen:** een klein "Mijn kleur"-knopje/icoon in de appbar van
  `BeheerOverzichtScreen` (zichtbaar voor iedereen, niet enkel de
  beheerder) dat de gedeelde `_KleurKiezer` (zie boven) in een
  bottom-sheet opent en de keuze wegschrijft naar het **eigen** profiel
  (`gebruikers/{eigen-uid}`) - dat mag al met de bestaande rules (iedereen
  mag zijn eigen profiel bijwerken, zolang `rol` niet verandert).
- Een kleine legende (naam + bolletje per zichtbaar gezinslid) bovenaan het
  overzicht is een logische toevoeging zodat je weet welke kleur bij wie
  hoort, zeker voor wie de kleuren nog niet uit het hoofd kent.
- **Test:** widget-test dat de juiste kleur uit `Gebruiker.kleur` gebruikt
  wordt, en dat `null` netjes terugvalt op de standaardkleur.

---

## F10 — Eigen kleur per item in de persoonlijke agenda (Ryans punt 4)

**Wens:** los van de vaste "wie ben ik"-kleur uit F9, wil Ryan per item in
zijn **eigen** agenda een eigen kleurtje kunnen kiezen (werk = blauw,
privé = roze, een vakantie = groen, ...) - dus per `Dienst`, niet per
gebruiker.

**Datamodel:** `diensten` krijgt `kleur: String?` (hex), `null` = nog geen
kleur gekozen (bv. bestaande diensten van vóór deze feature) → een
neutrale grijstint tonen. Bewust **losstaand** van `gebruikers.kleur`
(F9) - dat blijft enkel de "wie ben ik"-kleur in het gezamenlijke
overzicht.

**Wat te bouwen:**

- **`lib/models/dienst.dart`**: `kleur` als nieuw optioneel veld,
  `naarDocument()`/`vanDocument()` uitbreiden (zelfde patroon als
  `eindDatum`/`heleDag` in F2 - geen migratie nodig).
- **`lib/widgets/dienst_formulier.dart`**: de gedeelde `_KleurKiezer` (zie
  boven) toevoegen onder "Omschrijving", `DienstConcept` krijgt een
  `kleur`-veld erbij. Gebruikt door zowel Toevoegen als Bewerken.
- **`lib/widgets/dienst_tile.dart`**: het leading-icoon (of een klein
  gekleurd streepje/bolletje ernaast) kleuren volgens `dienst.kleur`.
- **`shiften_screen.dart`**: de kalenderbolletjes (`markerDecoration`) van
  `table_calendar` tonen nu een vaste `AppKleuren.terracotta`; bij
  meerdere diensten op 1 dag met verschillende kleuren volstaat
  `table_calendar`'s standaard "1 bolletje per event" (het pakket
  ondersteunt een lijst van marker-kleuren via `calendarBuilders.markerBuilder`)
  - dat is de enige plek die net iets meer maatwerk vraagt dan een simpele
    kleur-swap.
- **PDF-/schoolrooster-import** (`pdf_upload_screen.dart`,
  `schoolrooster_screen.dart`): vóór "Opslaan" een kleurkiezer tonen
  ("Welke kleur voor deze import?") die **op de hele batch** wordt
  toegepast (bv. alle geïmporteerde werkshiften worden blauw) - nadien is
  elk item individueel aan te passen via Bewerken. Optioneel: een
  onthouden "laatst gebruikte kleur per bron" (client-side, bv.
  `SharedPreferences`) zodat je niet élke maand opnieuw moet kiezen - dit
  is een nice-to-have, geen harde eis; enkel bouwen als het na F10 nog
  simpel blijft, anders gewoon elke keer laten kiezen met een zinnig
  voorstel (vorige keer gekozen kleur, indien bekend uit de bestaande
  diensten van die maand).
- **Print** (`overzicht_html.dart`/`overzicht_pdf.dart`): **niet**
  aanpassen voor deze feature - dat is niet gevraagd (die print toont al
  tekst, geen bolletjes) en blijft dus buiten scope, in lijn met "geen
  features toevoegen die niet gevraagd zijn".
- **Test:** `test/models/dienst_test.dart` uitbreiden met
  `kleur`-serialisatie (net als `heleDag`/`eindDatum` nu al getest
  worden).

---

## F11 — Meldingen voor de beheerder via OneSignal (Ryans punt 5)

**Wens:** de beheerder krijgt een melding wanneer iemand iets invult - 1
melding per PDF-import (batch, niet per losse shift) en 1 melding per
handmatig toegevoegd item. Aan/uit te zetten per persoon én algemeen, in
het beheerder-tab (F7's scherm).

**Waarom niet gewoon Firebase:** een Firestore-write kan geen client
rechtstreeks pushen naar een andere client zonder een server ertussen
(vandaar de "1 melding per gebeurtenis"-eis, geen polling). Firebase Cloud
Messaging zelf is gratis, maar het *versturen* van een gerichte melding
vanuit een client-event vereist normaal een Cloud Function (trigger op een
Firestore-write) - en dat vereist het betaalde Blaze-plan, wat dit project
bewust vermijdt (zie §3). Ryan koos daarom voor een gratis externe dienst.

**Gekozen dienst: [OneSignal](https://onesignal.com)** (gratis tier,
ruim voldoende voor een gezinsapp van een handvol accounts). Ondersteunt
Android + web, en laat toe rechtstreeks vanuit de app (zonder eigen
server) een REST-call te doen om een gerichte melding te versturen.

⚠️ **Belangrijke afweging om met Ryan te bevestigen voor het bouwen:**
zonder eigen server moet de OneSignal **REST API-key** mee in de
gecompileerde app (APK/web-build) zitten om een melding te kunnen
versturen - net zoals de Firebase-config nu al in `.env`/`.env.android`
zit. Wie de APK decompileert kan die key vinden en er ongewenste
meldingen mee versturen naar het gezin (een hinderlijk risico, **geen**
datalek - Firestore-rules blijven de échte data beschermen). Dat is
hetzelfde soort bewuste trade-off als de anonieme WebUntis-API in F4:
aanvaardbaar voor een kleine privé-gezinsapp, maar het is Ryans keuze om
dat zo te bevestigen voor het bouwen.

**Datamodel:**

- `gebruikers`: `meldingenAan: bool` (default `true`) - of acties van
  **deze persoon** (PDF-import, handmatig item toevoegen) een melding naar
  de beheerder(s) sturen. Instelbaar per persoon in het beheerder-tab
  (F7's scherm, sectie "Meldingen").
- `gebruikers`: `wilMeldingen: bool` (default `true`) - enkel relevant als
  deze persoon zelf beheerder is: de algemene aan/uit-schakelaar ("wil ík
  als beheerder meldingen ontvangen"). Bij meerdere beheerders in de
  toekomst heeft elke beheerder zijn eigen schakelaar.

**Wat te bouwen:**

- **Dependency:** `onesignal_flutter` toevoegen aan `pubspec.yaml`.
  `ONESIGNAL_APP_ID` (publiek, mag in `.env`) en
  `ONESIGNAL_REST_API_KEY` (gevoelig, zelfde behandeling als de
  Firebase-keys: in `.env`/`.env.android`, nooit hardcoded, nooit in git)
  toevoegen - Ryan maakt zelf een gratis OneSignal-account + app aan en
  bezorgt die twee waarden.
- **`main.dart`**: OneSignal initialiseren met de App-ID, en na een
  geslaagde login `OneSignal.login(account.uid)` aanroepen (koppelt het
  toestel aan de Firebase-uid als "External ID" - zo weet je exact wie een
  melding moet krijgen zonder zelf device-tokens te moeten bijhouden).
  Op Android ook `OneSignal.Notifications.requestPermission(true)` (nodig
  vanaf Android 13).
- **Nieuwe service** `lib/services/melding_service.dart`:
  - `bepaalOntvangers(List<Gebruiker> alleGebruikers, Gebruiker acteur) ->
    List<Gebruiker>` - **pure functie, apart unit-testbaar**: alle
    beheerders met `wilMeldingen == true`, maar enkel als
    `acteur.meldingenAan == true` (en de acteur zelf niet meetellen als
    die toevallig ook beheerder is - je hoeft geen melding over je eigen
    actie te krijgen).
  - `stuurMelding({required Gebruiker acteur, required String tekst})` -
    zoekt ontvangers via bovenstaande functie, en doet per ontvanger (of
    in 1 call met een lijst External IDs) een `http.post` naar
    `https://onesignal.com/api/v1/notifications` met de REST-key in de
    `Authorization`-header, `include_aliases: {external_id: [...]}` en de
    tekst. Faalt dit (geen internet, OneSignal down, ...) dan mag dat de
    opslag van de dienst zelf nooit blokkeren - `try/catch`, gewoon
    negeren/loggen, de shift is dan al opgeslagen.
- **Aanroeppunten** (enkel wanneer iemand **voor zichzelf** iets invult -
  niet wanneer de beheerder vanuit het gezamenlijke overzicht iets voor
  een ander toevoegt, F3/F8 - dat weet de beheerder al):
  - `pdf_upload_screen.dart`, na een geslaagde `slaPdfImportOp`: 1 melding,
    bv. `"${profiel.naam} heeft een PDF ingelezen (${voorbeeld.length} shiften)."`
  - `schoolrooster_screen.dart`, na een geslaagde `slaSchoolroosterOp`: 1
    melding, bv. `"${profiel.naam} heeft het schoolrooster opgehaald
    (N schooldagen)."`
  - `dienst_toevoegen_screen.dart`, na een geslaagde `aanmaken` **en enkel
    als `widget.voorGebruiker == null`**: 1 melding met de
    `dienst.naarTekst()`-omschrijving.
- **`beheer_instellingen_screen.dart`** (uit F7): tweede sectie
  "Meldingen" - per gezinslid een `SwitchListTile` gekoppeld aan
  `meldingenAan`, plus bovenaan (enkel zichtbaar/bewerkbaar voor de
  ingelogde beheerder, over zijn eigen profiel) een schakelaar "Ik wil
  meldingen ontvangen" gekoppeld aan `wilMeldingen`.
- **Test:** unit-tests voor `bepaalOntvangers` (verschillende combinaties
  van rollen + toggles) - dat is het enige deel dat zonder een echt
  toestel betrouwbaar te testen is. De effectieve pushmelding test Ryan
  zelf op zijn telefoon (net als F4.3) - een emulator laat dat niet
  altijd betrouwbaar zien.

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

Per feature: code → `flutter analyze` + `flutter test` → visuele/
functionele check → commit + push. F7 en F8 vereisen telkens een
rules-publicatie door Ryan (zoals F3); F11 vereist eerst een gratis
OneSignal-account + App-ID/REST-key van Ryan voordat die feature gebouwd
kan worden.

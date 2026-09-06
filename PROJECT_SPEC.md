# Project: Mama's rooster app (gezinsrooster)

Dit document beschrijft **wat de app nu is** (deel A) en **hoe we de 4
gevraagde nieuwe features aanpakken** (deel B). Het oude "bouwplan met
fases" en het lopende logboek zijn eruit gehaald: alles wat daarin stond is
klaar en zit in de git-historiek (`TripR27/uurrooster-app`, branch `main`).

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
  - `claude@test.com` (wachtwoord `testing123`) — testaccount van Ryan,
    beheerder, `roosterFormaat: A`, `naamInRooster: "Wyters, Ryan"`. Enkel
    voor Claude om mee te testen (Ryans eigen rooster kan hiermee geüpload
    worden). Geen echt gezinslid.
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

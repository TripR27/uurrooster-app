# Project: Gezinsrooster-app

Analyse & technisch plan — bedoeld als startdocument voor Claude Code.

## 1. Doel

Een app waarin 3 personen (ik, mijn zus, mijn moeder) hun werkrooster (PDF) uploaden.
De app leest de uren uit de PDF, slaat ze op, en de beheerder (ik) kan een
gezamenlijk, printbaar overzicht genereren met de uren van alle 3.

Extra: bij elke dienst kan een korte vrije-tekst omschrijving toegevoegd worden
(ook los van een PDF-import), zodat later ook privé-afspraken op het gezamenlijke
rooster gezet kunnen worden.

## 2. Gebruikers & rollen

| Rol | Wie | Rechten |
|---|---|---|
| Lid | ik, zus, moeder | Inloggen, eigen PDF-rooster uploaden, eigen diensten bekijken, handmatig een dienst/omschrijving toevoegen |
| Beheerder | ik | Alles wat een lid kan + gezamenlijk overzicht van alle 3 bekijken + printen/exporteren |

Iedereen heeft een eigen account. Na inloggen weet de app automatisch "wie je bent" —
geen aparte stap nodig waarin je jezelf moet aanduiden.

## 3. Platform & techstack

**Gekozen: Flutter** (Dart), omdat dat met één codebase oplevert:
- een installeerbare Android **APK** (rechtstreeks te downloaden, geen Play Store nodig) — voor wie dat wil,
- een **webversie** (gewoon een link openen in de browser) — voor je moeder, geen installatie nodig.

Dat lost de twijfel "echte app vs. webapp" in één keer op: zelfde app, twee manieren om 'm te gebruiken.

| Onderdeel | Keuze | Waarom |
|---|---|---|
| App | Flutter | 1 codebase → Android-app én webapp, gratis, jij hebt er al ervaring mee |
| Authenticatie | Firebase Authentication | Gratis, simpel, ingebouwde login (e-mail + wachtwoord) |
| Database | Cloud Firestore | Gratis tier ruim voldoende voor 3 gebruikers, realtime sync tussen apparaten |
| PDF-tekst uitlezen | `syncfusion_flutter_pdf` (Community License, gratis voor persoonlijk gebruik) | Werkt cross-platform (Android + web), kan tekst uit PDF halen zonder server |
| Printen / PDF-export | pakketten `pdf` + `printing` | Genereert het gezamenlijke overzicht als PDF en stuurt het naar de systeem-printdialoog; werkt op Android én web |
| Hosting webversie | Firebase Hosting | Gratis tier, integreert direct met de rest van Firebase |

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
  rol: "lid" | "beheerder"
}
```

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
4. PDF-upload UI + tekst-extractie testen met een voorbeeld van Formaat A.
5. `FormaatAParser` afmaken (jij/mama) → diensten wegschrijven naar Firestore.
6. `FormaatBParser` toevoegen (zus) — nieuwe adapter, geen wijziging aan bestaande code.
7. Overzichtscherm: eigen diensten bekijken (elk lid).
8. Handmatige invoer: dienst/omschrijving toevoegen zonder PDF.
9. Beheerscherm: gezamenlijk overzicht van alle 3.
10. Printen/PDF-export van het gezamenlijke overzicht.
11. Styling/polish, testen op alle 3 toestellen (2x Android, 1x web voor mama).
12. APK bouwen voor rechtstreekse download + webversie hosten op Firebase Hosting.

## 11. Open vragen / aannames (nog te bevestigen)

- Voorbeeld-PDF van Formaat A (jij/mama) en Formaat B (zus) nog nodig om de
  parsers te kunnen schrijven.
- Aanname: rooster is wekelijks (aan te passen als het eigenlijk maandelijks is).
- Aanname: de 3 accounts worden door de beheerder (jij) handmatig aangemaakt,
  er komt geen openbare "registreer jezelf"-pagina (dit is een privé-gezinsapp).

## 12. Wat ik nog moet aanleveren voordat het bouwen echt begint

- Eén voorbeeld-PDF van Formaat A.
- Eén voorbeeld-PDF van Formaat B (zus).

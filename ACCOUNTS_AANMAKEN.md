# Nieuw account aanmaken (mama, Amy, ...)

Deze app heeft geen "registreer je hier"-pagina: dit is een privé-gezinsapp
met een handvol accounts, die jij als beheerder zelf aanmaakt via de
Firebase Console. Dat kost geen geld en heeft geen code nodig.

## Eenmalig: Email/Password-login aanzetten

Dit staat waarschijnlijk al aan (je hebt hier immers al mee ingelogd), maar
voor de volledigheid:

1. Ga naar de [Firebase Console](https://console.firebase.google.com/) →
   project **uurrooster-app**.
2. Links in het menu: **Authentication** → tab **Sign-in method**.
3. Zorg dat **Email/Password** op "Enabled" staat. Zo niet: erop klikken →
   aanzetten → opslaan.

## Een account aanmaken

1. **Authentication** → tab **Users** → knop **Add user**.
2. Vul een e-mailadres en wachtwoord in (mama en Amy mogen zelf kiezen, of
   jij kiest iets en geeft het door — het wachtwoord kan later altijd
   gewijzigd worden).
3. **Add user** klikken. Klaar — dat account kan meteen inloggen in de app.

Herhaal dit voor elk account dat je wil toevoegen (mama, Amy, ...).

## Firestore Database + security rules instellen (eenmalig)

Vanaf stap 3 gebruikt de app ook Firestore (niet enkel Authentication). Als
je dat nog niet eerder hebt aangemaakt:

1. Firebase Console → **Firestore Database** → **Create database**.
2. Kies een locatie (bv. `europe-west`) → start in **production mode**
   (de rules hieronder regelen de rechten, dus dat is veilig).

Daarna de security rules toepassen:

1. **Firestore Database** → tab **Rules**.
2. Plak de volledige inhoud van [firestore.rules](firestore.rules) uit dit
   project erin (die vervangt wat er staat).
3. **Publish**.

Zonder deze stap werkt inloggen nog wel, maar faalt het ophalen/aanmaken
van het profiel (je ziet dan een foutmelding op het startscherm i.p.v.
"Ingelogd als ...").

## En de rol (lid/beheerder)?

Zodra iemand voor het eerst inlogt, maakt de app automatisch een profiel
aan in Firestore (collectie `gebruikers`) met rol `lid` — dat gebeurt
bewust altijd als `lid`, want de security rules staan niet toe dat een
account zichzelf beheerder maakt (zie firestore.rules).

**Iemand beheerder maken doe je dus handmatig, in twee klikken:**

1. Firebase Console → **Firestore Database** → tab **Data** → collectie
   `gebruikers`.
2. Klik het document met de uid van dat account aan (je herkent het account
   via het bijhorende e-mailadres in **Authentication** → **Users**, waar
   ook de uid staat).
3. Wijzig het veld `rol` van `lid` naar `beheerder` → opslaan.

**Voor nu concreet:** laat `claudetest@test.com` en `wytersryan@gmail.com`
allebei één keer inloggen in de app (zodat hun profiel aangemaakt wordt),
en zet dan bij beide het veld `rol` op `beheerder` zoals hierboven
beschreven. Voor mama en Amy hoeft dat niet — die blijven gewoon `lid`.

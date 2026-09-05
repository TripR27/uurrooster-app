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

## En de rol (lid/beheerder)?

Op dit moment (stap 2 van het bouwplan) bepaalt een account nog geen
rechten — iedereen die kan inloggen ziet hetzelfde simpele scherm. Vanaf
**stap 3** (Firestore-datamodel + security rules) krijgt elk account een
rol (`lid` of `beheerder`) die bepaalt wat ze mogen zien/doen. Zodra dat
gebouwd is, leg ik hier ook uit hoe je die rol per account instelt.

Voorlopig volstaat het dus om enkel de Auth-accounts (e-mail + wachtwoord)
hierboven aan te maken voor mama en Amy; de rol koppelen we er later aan.

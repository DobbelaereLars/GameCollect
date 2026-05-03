# GameCollect

Getest op **iOS** en **Android**.

---

## Opstarten

> De eerste build kan tot **15 minuten** duren. Daarna is alles gecached en gaat het veel sneller.

### Met FVM (aanbevolen)

```bash
fvm use
fvm flutter pub get
fvm flutter run
```

### Zonder FVM

```bash
flutter pub get
flutter run
```

Zorg dat je Flutter-versie overeenkomt met de versie in `.fvmrc`.

---

## Vereiste configuratie

### 1. RAWG API-sleutel

Maak een gratis account aan op [https://rawg.io/apiv2](https://rawg.io/apiv2) en kopieer je API-sleutel.

```bash
cp .env.example .env
```

Open `.env` en vervang de placeholder:

```
RAWG_API_KEY=949d0b59db844930b897d6086c736904
```

### 2. Firebase

**Stap 1 — Maak een Firebase-project aan**

1. Ga naar [https://console.firebase.google.com](https://console.firebase.google.com) en klik op **Project toevoegen**.
2. Geef het project een naam en doorloop de wizard.
3. Activeer in het project de volgende producten:
   - **Authentication** → inlogmethode e-mail/wachtwoord inschakelen
   - **Firestore Database** → aanmaken in productie- of testmodus
   - **Storage** → aanmaken in productie- of testmodus

**Stap 2 — Koppel het project aan de app**

Installeer de Firebase CLI en FlutterFire CLI als je dat nog niet hebt:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

Als het `ios/Runner.xcodeproj` ontbreekt (bijv. na een verse clone), genereer het eerst opnieuw:

```bash
flutter create --platforms=ios .
```

Meld je daarna aan en koppel het project:

```bash
firebase login
flutterfire configure
```

Kies tijdens `flutterfire configure` het project dat je net hebt aangemaakt. Dit genereert `lib/firebase_options.dart` en voegt de benodigde bestanden toe aan `android/` en `ios/`.

---

## Wat biedt de app

- **Collectiebeheer** — voeg games toe aan je persoonlijke collectie, kies het platform en stel een status in (wil ik spelen, bezig, gespeeld, voltooid).
- **Voortgang bijhouden** — registreer speelduur per sessie en volg je completion-percentage op via een checklist van doelen per game.
- **Aangepaste covers** — vervang de standaardcover door een foto uit je galerij; de afbeelding wordt automatisch gecomprimeerd (<500 KB) en gesynchroniseerd naar de cloud.
- **Overzichtspagina** — bekijk in één oogopslag je collectie, games waar je mee bezig bent en trending games via de RAWG API.
- **Ontdekken** — blader door trending en populaire games, zoek op naam en voeg ze direct toe aan je collectie.
- **App-achievements** — verdien in-app beloningen op basis van mijlpalen (aantal games, speelduur, voltooiingen, …).
- **Meldingen** — optionele dagelijkse herinnering om te gamen, instelbaar via de profielpagina.
- **Cloud sync** — bidirectionele synchronisatie tussen lokale SQLite en Firestore (last-write-wins per record). Bij aanmelden met bestaande data kies je zelf: alleen cloud, alleen lokaal of samenvoegen.

---

## Firebase-structuur

### Firestore

```
users/{uid}/
  collection/{syncId}       — collectie-items (game, platform, status, speelduur, voortgang, …)
  appAchievements/{id}      — behaalde in-app achievements
  eventCounters/{key}       — tellers voor achievement-triggers (bijv. aantal sessies)
  settings/notifications    — notificatievoorkeur
```

### Firebase Storage

```
users/{uid}/covers/{itemId}.jpg   — aangepaste game-covers (gecomprimeerd, max 500 KB)
```

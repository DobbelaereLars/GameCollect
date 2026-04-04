# GameCollect UI Style Guide (Verplicht)

Gebruik deze designregels voor alle nieuwe UI-code, refactors en componenten in dit project.

## Font Family

Aanbevolen en vastgelegd voor het project:

- Primary font family: Manrope
- Fallback: sans-serif

Gebruik dezelfde font family voor headings, body en meta tekst om visuele consistentie te behouden.

## Typography Scale

Gebruik onderstaande vaste groottes:

- H1
  - fontFamily: Manrope
  - fontSize: 32
  - fontWeight: 700
  - lineHeight: 1.2

- H2
  - fontFamily: Manrope
  - fontSize: 24
  - fontWeight: 700
  - lineHeight: 1.25

- H3
  - fontFamily: Manrope
  - fontSize: 20
  - fontWeight: 600
  - lineHeight: 1.3

- Body
  - fontFamily: Manrope
  - fontSize: 16
  - fontWeight: 400
  - lineHeight: 1.5

- Meta (small text)
  - fontFamily: Manrope
  - fontSize: 12
  - fontWeight: 400
  - lineHeight: 1.4

## Light Theme Colors

Basiskleuren:

- Background: #FFFFFF
- Text primary: #000000

Oranje accent palette:

- Orange 50: #FFF4EB
- Orange 100: #FFE2CC
- Orange 200: #FFC299
- Orange 300: #FFA266
- Orange 400: #FF8A3D
- Orange 500 (primary accent): #FF6B00
- Orange 600: #E65F00
- Orange 700: #B84C00
- Orange 800: #8A3900
- Orange 900: #5C2600

Semantisch gebruik:

- Accent primary: Orange 500 (#FF6B00)
- Accent pressed/active: Orange 600 (#E65F00)
- Accent subtle backgrounds/chips: Orange 50-100
- Accent text on white: Orange 700 of donkerder voor voldoende contrast

## Iconography

Gebruik Lucide als standaard iconset in dit project.

- Package: lucide_icons_flutter
- Vermijd mixen van meerdere iconsets binnen hetzelfde scherm, tenzij expliciet gevraagd.
- Gebruik icongroottes consistent (bij voorkeur 16, 20 of 24).
- Gebruik standaard iconkleur zwart (#000000), of een oranje accentkleur uit het palette voor interactieve elementen.
- Houd iconstijl lijngebaseerd en visueel consistent met de rest van de UI.

## Platform Priority

Ontwikkel en test iOS als primaire target tijdens de implementatiefase.

- Primary device: iOS
- Prioriteer iOS-gedrag, spacing en navigatiepatronen tijdens development.
- Zorg dat code platform-neutraal blijft, zodat Android later zonder grote refactor ondersteund blijft.
- Android-optimalisatie en fine-tuning gebeuren pas op het einde.

## Implementatie-instructies voor AI

- Introduceer geen extra kleuren buiten zwart, wit en dit oranje palette, tenzij expliciet gevraagd.
- Gebruik geen dark theme tenzij expliciet gevraagd.
- Houd typografie consistent met bovenstaande schaal.
- Gebruik geen andere font family tenzij expliciet gevraagd.
- Gebruik Lucide icons via lucide_icons_flutter als standaard iconbron.
- Hanteer iOS als primaire testdoelstelling tijdens featureontwikkeling.
- Bij nieuwe schermen: pas deze tokens toe in ThemeData, TextTheme en component styles.

## Buttons (Standaardisatie)

Binnen de app maken wij gebruik van de volgende knop stijlen ter bevordering van consistentie:

- **Primary Button (bijv. "Opnieuw proberen"):** Een `OutlinedButton` waarbij zowel de tekst (foregroundColor) als de rand (side) gebruikmaken van de primaire accentkleur (`AppTheme.orange500`).

```dart
OutlinedButton(
  onPressed: () {},
  style: OutlinedButton.styleFrom(
    foregroundColor: AppTheme.orange500,
    side: const BorderSide(color: AppTheme.orange500),
  ),
  child: const Text('Primary Action'),
)
```

- **Secondary Button (bijv. "Annuleren"):** Een standaard `TextButton` met grijze tekst (`AppTheme.gray700`), bedoeld voor minder prominente acties, zoals het annuleren of sluiten van dialogen.

```dart
TextButton(
  onPressed: () {},
  style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
  child: const Text('Secondary Action'),
)
```

## Network & Error Handling (Standaardisatie)

Hanteer bij alle API-calls en dataloads in de app dezelfde patronen voor trage of ontbrekende internetverbindingen:

1. **Initial Load & Lege Staten (Errors)**
   - **Geen internet** (bij o.a. `SocketException`, `TimeoutException`): Toon gecentreerd op het scherm een `LucideIcons.wifiOff` icoon (size: 48, color: orange500) met de tekst `"Controleer je internetverbinding"`.
   - **Algemene / Server Fouten**: Toon gecentreerd een `LucideIcons.triangleAlert` icoon (size: 48, color: orange500) met de tekst `"Er is iets misgegaan."`.
   - **Retry-mechanisme**: Plaats eronder altijd een `OutlinedButton` met de tekst `"Opnieuw proberen"` om de originele fetch opnieuw aan te roepen.

2. **Trage Verbinding (Slow Connection Warning)**
   - Gebruik een timer van 10 seconden die wordt gestart zodra het laden begint.
   - Als de timer afloopt en het verzoek is nog bezig, voeg dan de tekst `"Dit duurt langer dan normaal..."` onder `CircularProgressIndicator` toe.
   - Annuleer de weergave van deze tekst uiteraard als er een success/error respons binnen is.

3. **Paginatie & Infinite Scroll Falen (Auto-retry)**
   - Als er al resultaten op het scherm staan en een volgende 'loadMore' badge faalt wegens geen internet, gooi dan de reeds bestaande data **nooit** weg.
   - Laat de status op laden staan (`isLoadingMore = true`), zodat de spinner onderaan de grid/lijst blijft draaien.
   - Vang de netwerkfout af en schiet een automatische the-retry-loop in de achtergrond af (bijv. via `Future.delayed(const Duration(seconds: 3))` die de ophaal-functie voor de volgende pagina opnieuw aanroept totdat de verbinding weer hersteld is). Valt de UI dus niet onnodig lastig met pop-ups tijdens het bijladen.

## Dialogs / Modals (Standaardisatie)

Gebruik voor **alle** `AlertDialog` en `Dialog` widgets dezelfde border radius als de camera-zoekdialog:

- `BorderRadius.circular(16)`

Stel dit altijd expliciet in via de `shape`-property:

```dart
AlertDialog(
  backgroundColor: AppTheme.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  ...
)
```

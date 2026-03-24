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

## Implementatie-instructies voor AI

- Introduceer geen extra kleuren buiten zwart, wit en dit oranje palette, tenzij expliciet gevraagd.
- Gebruik geen dark theme tenzij expliciet gevraagd.
- Houd typografie consistent met bovenstaande schaal.
- Gebruik geen andere font family tenzij expliciet gevraagd.
- Gebruik Lucide icons via lucide_icons_flutter als standaard iconbron.
- Bij nieuwe schermen: pas deze tokens toe in ThemeData, TextTheme en component styles.

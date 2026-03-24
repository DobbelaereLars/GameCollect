# GameCollect

GameCollect is een Flutter-appconcept waarmee gebruikers hun fysieke en digitale gamecollectie kunnen beheren op basis van een vooraf ingevulde databank met bekende games. Gebruikers kunnen games opzoeken, toevoegen aan hun persoonlijke collectie en hun voortgang opvolgen aan de hand van een standaard completion-checklist die per game in de databank is voorzien.

## Projectconcept

Veel gamers bezitten games verspreid over verschillende platformen zoals Nintendo Switch, pc, PlayStation en Xbox. Het bijhouden van welke games ze bezitten, welke ze nog moeten spelen en hoe ver ze staan in een game gebeurt vaak verspreid over verschillende apps, websites of spreadsheets.

GameCollect wil dit oplossen door één centrale mobiele applicatie aan te bieden waarin:

- een lijst met bekende games al standaard beschikbaar is;
- gebruikers games uit die databank kunnen toevoegen aan hun eigen collectie;
- elke toegevoegde game een vaste set completion-doelen of checklist-items bevat;
- spelers hun voortgang eenvoudig kunnen opvolgen;
- gebruikers optioneel ook zelf extra games kunnen toevoegen.

Het doel is om een moderne, gebruiksvriendelijke en visueel sterke app te ontwikkelen met een duidelijke focus op collectiebeheer, backlog-opvolging en completion tracking.

## Doelgroep

GameCollect is bedoeld voor:

- gamers met zowel fysieke als digitale games;
- gebruikers met een grote backlog;
- spelers die hun voortgang duidelijk willen opvolgen;
- completionists die willen bijhouden welke stappen nog nodig zijn om een game volledig af te werken.

## Probleemstelling

Veel game tracking-oplossingen vragen nog te veel manuele input of focussen slechts op één onderdeel, zoals enkel een backlog of enkel een lijst van bezeten games. GameCollect combineert meerdere noden in één app door gebruik te maken van een vooraf ingevulde gamedatabase én een persoonlijke gebruikerscollectie.

Daardoor hoeft de gebruiker niet alles zelf in te geven en krijgt de app meteen een rijkere en meer afgewerkte ervaring.

## Kernidee

De app bestaat uit twee belangrijke onderdelen:

### 1. Centrale gamedatabase

De applicatie bevat standaard een lijst met bekende games. Elke game in deze databank bevat basisinformatie zoals:

- titel
- platform(en)
- cover
- genre
- geschatte speelduur
- standaard completion-checklist

### 2. Persoonlijke collectie

Gebruikers kunnen een game uit de databank toevoegen aan hun eigen collectie. Vanaf dat moment kunnen ze:

- de status aanpassen;
- voortgang bijhouden;
- checklist-items afvinken;
- persoonlijke tags toevoegen;
- notities opslaan.

Hierdoor combineert de app een algemene catalogus met een persoonlijke trackingervaring.

## Belangrijkste functionaliteiten

### 1. Games zoeken en toevoegen uit databank

Gebruikers kunnen bekende games zoeken in een standaarddatabase en die toevoegen aan hun persoonlijke collectie.

### 2. Covergrid-overzicht

De eigen collectie wordt weergegeven in een visuele grid-layout met covers zodat gebruikers snel een overzicht krijgen van hun bibliotheek.

### 3. Backlog- en statusbeheer

Elke game in de collectie kan een status krijgen, zoals:

- Backlog
- Bezig met spelen
- Uitgespeeld
- Gecompleteerd
- Gedropt

### 4. Completion-checklist

Elke game bevat een standaard checklist die uit de databank komt. Gebruikers kunnen deze checklist afvinken om hun voortgang bij te houden richting het uitspelen of volledig completen van een game.

Voorbeelden van checklist-items:

- hoofdverhaal voltooid
- side quests afgewerkt
- collectibles verzameld
- achievements behaald
- 100% completion bereikt

### 5. Persoonlijke tags en notities

Gebruikers kunnen eigen tags toevoegen, zoals:

- favoriet
- must play
- korte game
- co-op
- multiplayer

Daarnaast kunnen ze ook persoonlijke notities bewaren.

### 6. Handmatig games toevoegen

Als extra functionaliteit kunnen gebruikers ook zelf een game toevoegen wanneer die niet in de standaarddatabase aanwezig is.

### 7. Filteren en sorteren

Gebruikers kunnen hun collectie filteren en sorteren op basis van:

- platform
- status
- tags
- voortgang
- alfabetische volgorde
- recent toegevoegd

## MVP-scope

De eerste versie van GameCollect focust op de kernfunctionaliteiten die nodig zijn om het concept duidelijk te tonen.

### De MVP bevat

- een vooraf ingevulde databank met bekende games;
- een zoekfunctie binnen die databank;
- games toevoegen aan een persoonlijke collectie;
- een covergrid-overzicht van de collectie;
- statusbeheer per game;
- een standaard completion-checklist per game;
- checklist-items afvinken;
- lokale opslag van gebruikersdata.

### Mogelijke uitbreidingen

- handmatig games toevoegen;
- wishlist;
- statistiekenpagina;
- favorieten;
- import/export van data;
- synchronisatie tussen toestellen;
- online backend.

## UX en UI

Een belangrijk doel van dit project is het ontwikkelen van een moderne en overzichtelijke mobiele gebruikerservaring. De app moet niet aanvoelen als een simpele lijst, maar als een visueel aantrekkelijke game companion app.

De focus ligt op:

- een sterke covergebaseerde interface;
- duidelijke navigatie tussen lijst en detailpagina;
- eenvoudige progress- en checklistinteractie;
- consistente styling;
- een moderne en hedendaagse uitstraling.

## Data-opslag

De app maakt gebruik van twee soorten

- standaard gamegegevens die vooraf in de databank aanwezig zijn;
- persoonlijke gebruikersgegevens zoals collectie, status, tags, notities en checklist-voortgang.

In de eerste versie wordt gebruikersdata lokaal opgeslagen. Een latere versie zou eventueel een backend of synchronisatie kunnen voorzien.

## Platformfocus

De app wordt ontwikkeld in Flutter, met focus op mobiel gebruik. De eerste versie richt zich op één platform, maar het concept kan later makkelijk uitgebreid worden naar zowel Android als iOS.

## Waarom dit project interessant is

GameCollect is meer dan een gewone collectie-app omdat het drie onderdelen combineert:

- een vooraf ingevulde gamedatabase;
- een persoonlijke collectie;
- completion tracking via standaard checklists.

Daardoor ontstaat een interessanter en uitdagender project met voldoende ruimte voor sterke UI/UX, een logische datastructuur en een afgewerkt productgevoel.

## Geplande technologie

- Flutter
- Dart
- Lokale opslag, bijvoorbeeld Hive of SQLite
- Firebase (optioneel, voor online opslag en synchronisatie)
- Een duidelijke en herbruikbare widget-structuur

## Uitgebreide functionaliteiten

GameCollect focust op meer dan basiscollectiebeheer. De app combineert collectiebeheer met slimme invoer, voortgangsondersteuning, updates en sociale interactie.

### Functionele richting

- Integratie met de RAWG API als bron voor game-metadata, covers, platformen, speelduur en extra contextdata.
- Camera- en barcode-scanflow om fysieke games sneller en met minder manuele input aan de collectie toe te voegen.
- Lokale notificaties voor herinneringen, bijvoorbeeld om verder te spelen of om bijna voltooide checklist-doelen af te ronden.
- Share-functionaliteit vanaf de eerste versies, zodat gebruikers hun collectie, voortgang en stats eenvoudig kunnen delen.
- Shorebird voor OTA-updates, zodat verbeteringen en bugfixes sneller uitgerold kunnen worden zonder telkens een volledige herinstallatie.

### Gebruikte packages en API's (voorlopig)

- RAWG API
- camera
- barcode_scanner
- flutter_local_notifications
- share_plus

### Achievements

Als extra gamificationlaag wordt een intern achievements-systeem toegevoegd. Dit systeem beloont mijlpalen op basis van het gebruik van de app en de groei van de collectie.

Voorbeelden:

- 100 fysieke games toegevoegd
- Eerste online koppeling actief
- 10 games volledig gecompleteerd
- 30 dagen op rij activiteit in de app
- Eerste collectie-share voltooid

Deze functionaliteit versterkt de motivatie van gebruikers en maakt de app interactiever op lange termijn.

## Status

Deze repository bevat momenteel de concept- en planningsfase van het project. De applicatie zelf wordt verder uitgewerkt binnen het vak Smart App Development.

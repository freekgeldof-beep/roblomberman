# Roblomberman 💣

Een Bomberman-achtig Roblox-spel met bovenaanzicht, bommen en goodies. Tot 8 spelers per ronde; de laatste die overeind staat wint.

## Besturing

| Toets | Actie |
| --- | --- |
| WASD / pijltjes | Lopen |
| Spatie | Bom leggen |
| E | Actieknop: bom gooien/oppakken (🧤), geschopte bom stoppen (🦶) of een bom wegslaan (🥊) |

Op mobiel staan 💣- en 🧤-knoppen op het scherm.

## Goodies (vallen uit kapotte kisten)

- 🔥 **Vuurbereik +1** – je bommen gaan verder
- 💣 **Extra bom** – meer bommen tegelijk
- 👟 **Sneller lopen**
- ⚡ **Doorboor-bommen** – het vuur gaat dwars door kisten heen
- 🧤 **Handschoen** – pak een bom op en gooi hem over muren en kisten heen (≥3 vakjes ver). Gooi je over de buitenmuur, dan komt hij aan de overkant weer binnen. Let op: de lont blijft branden terwijl je hem vasthoudt!
- 🦶 **Schopschoen** – loop tegen een bom aan en hij glijdt weg tot hij ergens tegenaan botst. Druk op E om hem te laten stoppen.
- 🥊 **Bokshandschoen** (zeldzaam ✨) – druk op E en je slaat de bom voor je 3 vakjes ver over de muren heen
- 🌋 **Max-vuur** (heel zeldzaam ✨) – meteen het grootste vuurbereik
- 💀 **Vloek** (pas op!) – 10 seconden lang supertraag, géén bommen kunnen leggen, of juist vanzelf bommen leggen

Vuur laat andere bommen meteen ontploffen (kettingreacties).

## Het veld

- Het veld **groeit mee** met het aantal spelers: 13×13 vakjes voor 1–2 spelers, 17×13 voor 3–4, 21×17 voor 5–6 en 25×17 voor 7–8.
- De **camera volgt je eigen speler** van boven. Ben je af, dan zoomt hij uit en zie je het hele veld.
- Elke ronde doen er willekeurig een paar **bijzondere vakjes** mee (dat zie je aan het begin van de ronde):
  - 🌀 **Warpzones**: stap erop en je komt bij de warp met dezelfde kleur uit. Geschopte bommen gaan er ook doorheen!
  - ➡️ **Lopende banden**: nemen je mee in de richting van de gele strepen. Bommen schuiven ook mee.
  - 🧱 **Schakelmuren**: rode blokken die om de 6 seconden omhoog komen (dan houden ze ook vuur tegen) en weer zakken.
  - 🧊 **IJsvakjes**: als je loslaat glijd je nog door.
- Elke ronde heeft een willekeurig **thema**: gras, woestijn, sneeuw, lava of ruimte.

## Rondes en wedstrijden

- Ben je met minder dan 4, dan vullen **computertegenstanders** 🤖 het veld aan (instelbaar met `BOT_FILL`).
- Een **wedstrijd** gaat tot iemand 3 rondes heeft gewonnen (`MATCH_WINS`, 0 = gewoon losse rondes). Daarna begint een nieuwe wedstrijd.

- Elke speler krijgt een eigen kleur (rood, blauw, geel, groen, paars, oranje, roze, cyaan).
- Een ronde duurt 2,5 minuut (timer rechtsboven). Daarna begint **sudden death**: de arena valt van buiten naar binnen dicht met muren.
- Ben je af, dan kijk je mee tot de volgende ronde.
- Na elke ronde zie je een scorebord met de stand.
- Speel je alleen en komt er iemand bij, dan begint meteen een nieuwe ronde met z'n tweeën.

## Talen

Het spel praat in de taal die je in Roblox hebt ingesteld. Er zijn 20 talen: Engels, Nederlands, Spaans, Portugees, Frans, Duits, Italiaans, Russisch, Oekraïens, Pools, Turks, Indonesisch, Filipijns, Vietnamees, Thais, Japans, Koreaans, Chinees (vereenvoudigd en traditioneel) en Arabisch. Alle teksten staan in `src/ReplicatedStorage/Lang.lua`. Een onbekende taal valt terug op Engels.

## Installeren

### Snelste manier

Download `Roblomberman.rbxlx` uit deze repo en open het in Roblox Studio. Druk op Play en je speelt. (Opnieuw genereren na een codewijziging: `python3 build_place.py`.)

### Met Rojo

```bash
rojo build -o Roblomberman.rbxlx
```

Open het bestand in Roblox Studio (of `rojo serve` + de Rojo-plugin) en druk op Play.

### Zonder Rojo (handmatig in Studio)

Maak een lege Baseplate en maak deze scripts, plak de inhoud erin:

| Bestand | Type | Plek |
| --- | --- | --- |
| `src/ReplicatedStorage/BombConfig.lua` | ModuleScript, naam `BombConfig` | ReplicatedStorage |
| `src/ReplicatedStorage/Lang.lua` | ModuleScript, naam `Lang` | ReplicatedStorage |
| `src/ServerScriptService/BombermanServer.server.lua` | Script | ServerScriptService |
| `src/ServerScriptService/Bomberman/*.lua` | ModuleScripts (naam = bestandsnaam zonder `.lua`) | in een Folder `Bomberman` in ServerScriptService |
| `src/StarterPlayerScripts/BombermanClient.client.lua` | LocalScript | StarterPlayer › StarterPlayerScripts |

Verwijder de Baseplate-part of laat hem staan (ligt onder de arena).

## Aanpassen

Alle getallen (veldgroottes per aantal spelers, camera, bots, wedstrijdlengte, kans op warps/banden/schakelmuren/ijs, lont, vuurtijd, kans op goodies, maximale upgrades, rondetijd, kleuren, geluiden) staan in `src/ReplicatedStorage/BombConfig.lua`.

De servercode is opgesplitst in modules in `src/ServerScriptService/Bomberman/`:

| Module | Wat zit erin |
| --- | --- |
| `Grid` | rooster-hulpfuncties (vakje ↔ positie) |
| `State` | gedeelde toestand van het spel |
| `Net` | RemoteEvents en ronde-info voor de clients |
| `Sounds` | geluiden afspelen |
| `Powerups` | goodies en vloeken (nieuwe goodies voeg je toe in `DEFS` en `ORDER`) |
| `Arena` | arena bouwen, thema's, kisten, warps, banden, schakelmuren, ijs, sudden-death-muren |
| `Bombs` | bommen leggen, gooien, schoppen, wegslaan, ontploffen en het vuur |
| `Bots` | computertegenstanders |

Het hoofdscript `BombermanServer` regelt de rondes, wedstrijden en spelers. De code en het commentaar zijn in het Engels.

### Geluiden

De geluiden gebruiken bestanden die standaard in Roblox zitten. Wil je mooiere geluiden, zoek er dan een in de Creator Store en zet het id (`rbxassetid://…`) in `SOUNDS` in `BombConfig.lua`.

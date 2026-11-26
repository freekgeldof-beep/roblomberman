# Roblomberman 💣

Een Bomberman-achtig Roblox-spel met bovenaanzicht, bommen en goodies. Tot 4 spelers per ronde; de laatste die overeind staat wint.

## Besturing

| Toets | Actie |
| --- | --- |
| WASD / pijltjes | Lopen |
| Spatie | Bom leggen |
| E | Bom oppakken / gooien (alleen met 🧤) |

Op mobiel staan 💣- en 🧤-knoppen op het scherm.

## Goodies (vallen uit kapotte kisten)

- 🔥 **Vuurbereik +1** – je bommen gaan verder
- 💣 **Extra bom** – meer bommen tegelijk
- 👟 **Sneller lopen**
- ⚡ **Doorboor-bommen** – het vuur gaat dwars door kisten heen
- 🧤 **Handschoen** – pak een bom op en gooi hem over muren en kisten heen (≥3 vakjes ver). Let op: de lont blijft branden terwijl je hem vasthoudt!
- 🦶 **Schopschoen** – loop tegen een bom aan en hij glijdt weg tot hij ergens tegenaan botst
- 💀 **Vloek** (pas op!) – 10 seconden lang supertraag, géén bommen kunnen leggen, of juist vanzelf bommen leggen

Vuur laat andere bommen meteen ontploffen (kettingreacties).

## Rondes

- Elke speler krijgt een eigen kleur (rood, blauw, geel, groen).
- Een ronde duurt 2,5 minuut (timer rechtsboven). Daarna begint **sudden death**: de arena valt van buiten naar binnen dicht met muren.
- Ben je af, dan kijk je mee tot de volgende ronde.
- Na elke ronde zie je een scorebord met alle overwinningen.
- Speel je alleen en komt er iemand bij, dan begint meteen een nieuwe ronde met z'n tweeën.

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
| `src/ServerScriptService/BombermanServer.server.lua` | Script | ServerScriptService |
| `src/ServerScriptService/Bomberman/*.lua` | ModuleScripts (naam = bestandsnaam zonder `.lua`) | in een Folder `Bomberman` in ServerScriptService |
| `src/StarterPlayerScripts/BombermanClient.client.lua` | LocalScript | StarterPlayer › StarterPlayerScripts |

Verwijder de Baseplate-part of laat hem staan (ligt onder de arena).

## Aanpassen

Alle getallen (arenagrootte, lont, vuurtijd, kans op goodies, maximale upgrades, rondetijd, kleuren, geluiden) staan in `src/ReplicatedStorage/BombConfig.lua`.

De servercode is opgesplitst in modules in `src/ServerScriptService/Bomberman/`:

| Module | Wat zit erin |
| --- | --- |
| `Grid` | rooster-hulpfuncties (vakje ↔ positie) |
| `State` | gedeelde toestand van het spel |
| `Net` | RemoteEvents en ronde-info voor de clients |
| `Sounds` | geluiden afspelen |
| `Powerups` | goodies en vloeken (nieuwe goodies voeg je toe in `DEFS` en `ORDER`) |
| `Arena` | arena bouwen, kisten, sudden-death-muren |
| `Bombs` | bommen leggen, gooien, schoppen, ontploffen en het vuur |

Het hoofdscript `BombermanServer` regelt de rondes en spelers.

### Geluiden

De geluiden gebruiken bestanden die standaard in Roblox zitten. Wil je mooiere geluiden, zoek er dan een in de Creator Store en zet het id (`rbxassetid://…`) in `SOUNDS` in `BombConfig.lua`.

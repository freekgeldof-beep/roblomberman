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

Vuur laat andere bommen meteen ontploffen (kettingreacties).

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
| `src/StarterPlayerScripts/BombermanClient.client.lua` | LocalScript | StarterPlayer › StarterPlayerScripts |

Verwijder de Baseplate-part of laat hem staan (ligt onder de arena).

## Aanpassen

Alle getallen (arenagrootte, lont, vuurtijd, kans op goodies, maximale upgrades) staan in `src/ReplicatedStorage/BombConfig.lua`. Nieuwe goodies voeg je toe in de `POWERUPS`-tabel in het serverscript.

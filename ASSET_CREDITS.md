# Asset credits

## Audio

File names describe how the game uses each clip. Edits are listed below. The Kenney packs were obtained from the creator’s OpenGameArt uploads and their bundled license notices are in `art/audio`. The two tracks by yd were released with LMMS project files.

| Project file | Original file and creator | License | In-game use |
| --- | --- | --- | --- |
| `art/audio/observing-the-star.ogg` | [ObservingTheStar.ogg](https://opengameart.org/content/another-space-background-track) by yd | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Menu, prologue and free flight loop |
| `art/audio/my-very-own-dead-ship.ogg` | [MyVeryOwnDeadShip.ogg](https://opengameart.org/content/background-space-track) by yd | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Cockpit and both duels loop |
| `art/audio/rocket-thrust.ogg` | User-supplied `nasa-rocket-engine-30s.mp3` | Original publisher and license unverified | Thruster, boost, and orbital insertion. Source excerpt from 4.0–9.5 s, mixed to mono, high-pass filtered, and crossfaded into a 5 s loop. |
| `art/audio/infected-trail.ogg` | [Bubbling Acid](https://opengameart.org/content/bubbling-acid) (`Acid Bubble.wav`) by spookymodem (Joseph Krebs in the file metadata) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Infected Trail. Trimmed to 1.55 s, faded in and out, and converted to Ogg Vorbis. |
| `art/audio/descent.ogg` | [doorOpen_001.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Orbital descent |
| `art/audio/transmission.ogg` | [computerNoise_002.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Comms typing |
| `art/audio/capture.ogg` | [impactMetal_001.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Capture impact |
| `art/audio/collapse.ogg` | [explosionCrunch_001.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Arena collapse and piece loss |
| `art/audio/lane-shift.ogg` | [doorClose_001.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Cinder lane shift |
| `art/audio/shield.ogg` | [forceField_001.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Shield activation and break |
| `art/audio/teleport.ogg` | [laserSmall_001.ogg](https://kenney.nl/assets/sci-fi-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Teleport |
| `art/audio/click.ogg` | [click_001.ogg](https://kenney.nl/assets/interface-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Menu and cockpit buttons |
| `art/audio/select.ogg` | [select_001.ogg](https://kenney.nl/assets/interface-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Unit selection and setting course |
| `art/audio/confirm.ogg` | [confirmation_001.ogg](https://kenney.nl/assets/interface-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Orbit lock, match and warning confirmations |
| `art/audio/spy.ogg` | [glitch_001.ogg](https://kenney.nl/assets/interface-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Spy takeover |
| `art/audio/relay.ogg` | [pluck_001.ogg](https://kenney.nl/assets/interface-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Beacon claim and Cinder relay scoring |
| `art/audio/move.ogg` | [drop_001.ogg](https://kenney.nl/assets/interface-sounds) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Unit landing |
| `art/audio/shuffle.ogg` | [card-shuffle.ogg](https://kenney.nl/assets/casino-audio) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Ability shuffle. Trimmed to 1.25 s with a short fade. |
| `art/audio/card-reveal.ogg` | [card-place-2.ogg](https://kenney.nl/assets/casino-audio) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Ability reveal |
| `art/audio/victory.ogg` | [jingles_HIT12.ogg](https://kenney.nl/assets/music-jingles) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Pilot victory |
| `art/audio/defeat.ogg` | [jingles_HIT00.ogg](https://kenney.nl/assets/music-jingles) by Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Pilot defeat |

## Art and typography

| Project file | Original asset and creator | License | In-game treatment |
| --- | --- | --- | --- |
| Ship telemetry in `scripts/cockpit.gd` | Original project graphics drawn with Godot primitives | Project code; no external graph image assets | Animated reactor-output and thermal-load plots, grid lines, and power/oxygen/hull reserve gauges. Labels use `art/IBMPlexMono-Regular.ttf` (SIL OFL 1.1). |
| `art/ship.svg`, `art/thruster.svg` | User-supplied SVGs (`gemini-svg (1).svg` and `gemini-svg.svg`) | Supplied for this project; no separate license provided | Ship hull and five animated exhaust flames, shown while accelerating or entering orbit |
| `art/planet_animation.png` | User-supplied `planet.gif` | Supplied for this project; no separate license provided | The GIF's 60 transparent frames decoded into a 10 × 6 atlas for Godot and blended for the slow 32-second rotation |
| `art/planet2.png`, `art/planet3.png`, `art/planet4.png` | User-supplied planet sprite sheets | Supplied for this project; no separate license provided | Original 50-frame strips for Ember, Cinder, and Aurelia, each with a separate solar orbit, slow rotation, and visible gravity boundary |
| `art/sun_sheet.png` | User-supplied `sun.png` sprite sheet | Supplied for this project; no separate license provided | Original 32-frame strip, blended between neighboring frames for a smooth 48-second sun rotation |
| `art/system_two_star.png`, `art/system_two_planet.png` | User-supplied `4185252325 (1).png` and `4185252325.png` | Supplied for this project; no separate license provided | Azure Reach's cyan star (32 frames) and Verdant (50 frames), using the shared rotation, gravity, flight, and battle mechanics |
| `art/westerlund-2.jpg` | [Westerlund 2 — Hubble’s 25th anniversary image](https://esahubble.org/images/heic1509a/). NASA, ESA, the Hubble Heritage Team (STScI/AURA), A. Nota (ESA/STScI), and the Westerlund 2 Science Team | [CC BY 4.0](https://esahubble.org/public/copyright/) | Tinted windshield sky |
| `art/cockpit/planet.png`, `moon.png`, `giant.png`, `star.png`, `outer.png` | [Tiny Planet Pack](https://screamingbrainstudios.itch.io/tiny-planet-pack) by Screaming Brain Studios | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | One frame each from the 128 × 128 Crystal, Moon, Saturn, Sun, and Neptune strips. Exterior backgrounds keyed out, displayed with tints. |
| `art/cockpit/deck.png`, `grille.png` | [Spaceship Interior](https://opengameart.org/content/spaceship-interior-0) by cheerful sprite | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Reduced-size color textures from `panels_4_c.png` and `panels_2_c.png`. Applied to the cockpit frame drawn in Godot. |
| `art/fleet/rover.glb`, `craft-speederd.glb`, `satellitedish-detailed.glb` | [Space Kit](https://kenney.nl/assets/space-kit) by Kenney. GLB conversions from the [Tiny Game Engine asset library](https://github.com/Hidencod/tge-assets/tree/main/packs/space-kit). | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Scaled in Godot. The survey rover and alien interceptor use faction liveries. The dish becomes the center beacon. |
| `art/cards/icons/*.svg` | [Pixelarticons 1.8.1](https://github.com/halfmage/pixelarticons/tree/v1.8.1) by Gerrit Halfmann | [MIT](art/cards/icons/LICENSE.txt) | Existing bug, eye, bullseye-arrow, and shield paths; only fill changed to white for runtime tinting. Pixel-aligned frames and card text are drawn in Godot. No AI-generated artwork. |
| `art/SpaceGrotesk.ttf` | [Space Grotesk](https://github.com/floriankarsten/space-grotesk) by Florian Karsten | [SIL OFL 1.1](art/OFL-SpaceGrotesk.txt) | Unmodified variable font, rendered at regular and bold weights |
| `art/IBMPlexMono-Regular.ttf` | [IBM Plex Mono](https://github.com/IBM/plex) by IBM Corp. | [SIL OFL 1.1](art/OFL-IBMPlexMono.txt) | Unmodified regular font |

The beveled landing pads are built with a mesh defined in `scripts/board.gd`. The cockpit frame, ship telemetry graphs and gauges, patrol silhouette, envoy portrait, chart, cracks, status markers, and movement previews are drawn with Godot primitives. A copy of the asset credits is accessible from the game's footer.

The workspace retains femrek's CC0 [pawn sprite](https://opengameart.org/content/chess-pieces-in-svg-format) from the 2D release. The current release uses the 3D meshes.

`art/kalypso-movement-guide.png` and `art/kalypso-capture-guide.png` are screenshots of the actual Godot board using the credited fleet meshes and font above. Arrows and markers show all 12 legal movement destinations or both forward captures in separate teaching positions. Rebuild them with `godot --path . --script tools/render_movement_guides.gd`. No AI-generated imagery is used.

`art/results/characters.png`: unmodified [Sci-Fi RogueLike Pixel Art](https://opengameart.org/content/sci-fi-roguelike-pixel-art) character sheet by Emcee Flesher, used under the offered [CC0](https://creativecommons.org/publicdomain/zero/1.0/) option. Existing crew and alien sprites are selected with atlas regions and enlarged with nearest-neighbor filtering. No AI-generated artwork. See [source details](art/results/SOURCE.md).

# How to play images

These images are screenshots rendered from the actual game board, with movement arrows and numbered landing markers drawn by Godot. They contain no AI generated graphics.

* Fleet meshes: [Space Kit by Kenney](https://kenney.nl/assets/space-kit), CC0. The existing game models were converted to GLB by the [Tiny Game Engine asset library](https://github.com/Hidencod/tge-assets/tree/main/packs/space-kit).
* Numbered markers: [IBM Plex Mono by IBM](https://github.com/IBM/plex), SIL Open Font License 1.1. Bundled license: `art/fonts/OFL-IBMPlexMono.txt`.
* Landing pads, relay treatments, movement arrows and capture markers: existing project geometry and Godot drawing code.

Rebuild the Kalypso images:

```sh
godot --path . --script tools/render_movement_guides.gd
```

Rebuild the Drift Circuit images:

```sh
godot --path . --script tools/render_movement_guides.gd -- drift
```

Both modes assert that all 12 normal destinations or both forward captures are visible in their separate teaching positions. Drift Circuit screenshots use the Cinder lanes and relays rather than Kalypso's flag.

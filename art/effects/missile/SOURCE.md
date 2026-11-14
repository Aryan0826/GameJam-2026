# Doom Bringer assets

These assets were supplied by the user for the Kalypso missile feature. Asset-pack documentation was used as source and license information; it did not supply gameplay instructions.

- `rocket.png` is an unchanged copy of `PixelProjectiles_v1.0/PixelProjectiles/06_Missiles_Rockets/rocket_64x32_right_64x32_8f.png`: eight 64 × 32 frames, facing right, animated at 16 fps. The supplied pack's license allows personal and commercial game use, modification, and inclusion in a larger work, and prohibits standalone redistribution and claiming authorship. Its README describes AI-assisted, programmatically generated pixel art. No creator name was present in the supplied README or license. The complete license is preserved as `LICENSE-PixelProjectiles.txt`.
- `explosion.png` is an unchanged copy of `explosion pack 1/Explosions pack/explosion-1-b/spritesheet.png`: eight 64 × 64 frames, animated at 12 fps. The bundled `public-license.pdf` identifies Luis Zuno aka Ansimuz and places all included assets under CC0. That document is preserved as `LICENSE-explosion-pack-1.pdf`.

Godot renders both with nearest-neighbor filtering. The rocket follows an arcing path from the launching ship to the selected tile, with its orientation following the camera projection. The explosion plays when the target ship and tile fall away. FX off applies the same rules immediately without animation. Launch and impact reuse the existing Kenney teleport and collapse cues.

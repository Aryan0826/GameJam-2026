"""Render the supplied OBJ and palette as a transparent, nose-up flight sprite.

Run from the project root: python tools/render_ship_sprite.py
Requires numpy and Pillow. Source geometry stays in tools/ship_source, outside
Godot's asset import and game exports. No generated or replacement geometry.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/ship_source"
OUTPUT = ROOT / "art/flight/star_marine_trooper.png"
ICON = ROOT / "art/flight/star_marine_trooper_icon.png"
WIDTH, HEIGHT = 512, 640
PIXELS_PER_UNIT = 80


def load_mesh():
    vertices, texcoords, normals, triangles = [], [], [], []
    for line in (SOURCE / "StarMarineTrooper.obj").read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "v":
            vertices.append([float(v) for v in fields[1:4]])
        elif fields[0] == "vt":
            texcoords.append([float(v) for v in fields[1:3]])
        elif fields[0] == "vn":
            normals.append([float(v) for v in fields[1:4]])
        elif fields[0] == "f":
            face = [[int(v) - 1 for v in field.split("/")] for field in fields[1:]]
            triangles.extend([face[0], face[i], face[i + 1]] for i in range(1, len(face) - 1))
    return np.array(vertices), texcoords, np.array(normals), triangles


def render():
    vertices, texcoords, normals, triangles = load_mesh()
    palette = Image.open(SOURCE / "StarMarineTrooper.png").convert("RGBA")
    rgba = np.zeros((HEIGHT, WIDTH, 4), dtype=np.float64)
    depth = np.full((HEIGHT, WIDTH), -np.inf)
    emissive = np.zeros((HEIGHT, WIDTH), dtype=bool)
    # OBJ Y is height; the orange engine outlets are on -Z, so +Z is the nose.
    projected = np.column_stack((
        WIDTH / 2 + vertices[:, 0] * PIXELS_PER_UNIT,
        HEIGHT / 2 - vertices[:, 2] * PIXELS_PER_UNIT,
    ))
    for triangle in triangles:
        normal = normals[triangle[0][2]]
        if normal[1] <= 0:
            continue
        indices = [v[0] for v in triangle]
        points = projected[indices]
        min_x, min_y = np.maximum(np.floor(points.min(axis=0)).astype(int), 0)
        max_x, max_y = np.minimum(np.ceil(points.max(axis=0)).astype(int), [WIDTH - 1, HEIGHT - 1])
        a, b, c = points
        denominator = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(denominator) < 1e-8:
            continue
        yy, xx = np.mgrid[min_y:max_y + 1, min_x:max_x + 1].astype(float)
        xx += 0.5
        yy += 0.5
        wa = ((b[1] - c[1]) * (xx - c[0]) + (c[0] - b[0]) * (yy - c[1])) / denominator
        wb = ((c[1] - a[1]) * (xx - c[0]) + (a[0] - c[0]) * (yy - c[1])) / denominator
        wc = 1 - wa - wb
        heights = vertices[indices, 1]
        height = wa * heights[0] + wb * heights[1] + wc * heights[2]
        region = np.s_[min_y:max_y + 1, min_x:max_x + 1]
        visible = (wa >= -1e-6) & (wb >= -1e-6) & (wc >= -1e-6) & (height >= depth[region])
        uv = texcoords[triangle[0][1]]
        color = palette.getpixel((min(int(uv[0] * palette.width), palette.width - 1), 0))
        rgba[region][visible] = color
        depth[region][visible] = height[visible]
        emissive[region][visible] = color[0] > 240 and (color[1] > 240 or 0 < color[1] < 80)

    opaque = np.isfinite(depth)
    # Height-based occlusion and directional shadows reveal the original voxel
    # steps even with an orthographic overhead camera. Empty pixels stay clear.
    occlusion = np.zeros((HEIGHT, WIDTH))
    for dy, dx in [(0, 4), (0, -4), (4, 0), (-4, 0), (4, 4), (-4, -4), (4, -4), (-4, 4)]:
        neighbour = np.roll(depth, (dy, dx), axis=(0, 1))
        occlusion += (neighbour > depth + 0.06) & opaque
    shadow = np.zeros((HEIGHT, WIDTH), dtype=bool)
    for step in range(2, 35, 2):
        neighbour = np.roll(depth, (step, step), axis=(0, 1))
        shadow |= (neighbour > depth + step / PIXELS_PER_UNIT * 1.3) & opaque
    # Keep the dark source palette readable against the flight starfield.
    light = np.clip(1.35 - occlusion * 0.045 - shadow * 0.24, 0.7, 1.35)
    light[emissive] = 1
    rgba[:, :, :3] *= light[:, :, None]
    sprite = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))
    sprite.save(OUTPUT)
    icon = Image.new("RGBA", (HEIGHT, HEIGHT))
    icon.paste(sprite, ((HEIGHT - WIDTH) // 2, 0))
    icon.save(ICON)
    print(f"Rendered {len(triangles)} source triangles to {OUTPUT}")
    print(f"Visible bounds: {sprite.getbbox()}")
    # Report the actual orange outlet spans, for fitting the runtime exhausts.
    orange = (rgba[:, :, 0] > 240) & (rgba[:, :, 1] > 0) & (rgba[:, :, 1] < 80) & opaque
    xs = np.where(orange.any(axis=0))[0]
    groups = np.split(xs, np.where(np.diff(xs) > 1)[0] + 1)
    for group in groups:
        if not group.size:
            continue
        ys = np.where(orange[:, group].any(axis=1))[0]
        print(f"Engine outlet: x={group[0]}..{group[-1]}, y={ys[0]}..{ys[-1]}")


if __name__ == "__main__":
    render()

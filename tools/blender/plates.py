"""Armour plate icons and the armour steel icon.

Run:  blender -b --factory-startup -P tools/blender/plates.py -- <out_dir> [name ...]
Writes <out_dir>/<name>.png (512 px, transparent) for every plate in PLATES and for
armor-steel. tools/blender/build_icons.py turns them into the icon and equipment sprites.

Colour code shared by all plates: the band along the lower edge is grey for physical,
orange for explosion, green for acid, red for fire. Steel is blue-grey, tungsten anthracite.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import rig  # noqa: E402

SIZE = 2.0  # plate edge
THICK = 0.16
BAND = {
    "physical": (0.5, 0.5, 0.5),
    "explosion": (0.85, 0.4, 0.05),
    "acid": (0.25, 0.65, 0.15),
    "fire": (0.75, 0.12, 0.06),
}


def materials():
    return {
        "steel": rig.material("steel", (0.36, 0.42, 0.5), roughness=0.4, metallic=0.8, grime=0.25, scale=5, bump=0.1),
        "brushed": rig.material("brushed", (0.48, 0.52, 0.58), roughness=0.3, metallic=0.9, grime=0.15, scale=12, bump=0.05),
        "tungsten": rig.material("tungsten", (0.13, 0.13, 0.15), roughness=0.35, metallic=0.9, grime=0.2, scale=6, bump=0.1),
        "carbide": rig.material("carbide", (0.2, 0.2, 0.22), roughness=0.25, metallic=0.7, grime=0.1, scale=9, bump=0.15),
        "rivet": rig.material("rivet", (0.6, 0.62, 0.66), roughness=0.25, metallic=0.9, grime=0.05),
        "bracket": rig.material("bracket", (0.72, 0.74, 0.78), roughness=0.3, metallic=0.9, grime=0.1),
        "era": rig.material("era", (0.3, 0.33, 0.27), roughness=0.6, grime=0.35, scale=4, bump=0.15),
        "fuse": rig.material("fuse", (0.95, 0.5, 0.05), roughness=0.5, emission=(0.6, 0.25, 0.02)),
        "coat": rig.material("coat", (0.2, 0.3, 0.22), roughness=0.08, metallic=0.0, grime=0.05, scale=3, bump=0.02),
        "passive": rig.material("passive", (0.16, 0.24, 0.19), roughness=0.2, metallic=0.5, grime=0.1, scale=7),
        "ceramic": rig.material("ceramic", (0.62, 0.55, 0.47), roughness=0.85, grime=0.35, scale=6, bump=0.3),
        "dark": rig.material("dark", (0.04, 0.04, 0.045), roughness=0.6),
        **{k: rig.material("band_" + k, c, roughness=0.5, grime=0.2, scale=5) for k, c in BAND.items()},
    }


def base(m, mat, band):
    """The plate with chamfered edges and its coloured band along the lower edge."""
    rig.box("plate", (0, 0, THICK / 2), (SIZE, SIZE, THICK), m[mat], bevel=0.04)
    rig.box("band", (0, -SIZE / 2 + 0.12, THICK + 0.005), (SIZE - 0.1, 0.16, 0.012), m[band], bevel=0)


def rivets(m, inset=0.12, count=6):
    for side in range(4):
        for k in range(count):
            t = -SIZE / 2 + inset + k * (SIZE - 2 * inset) / (count - 1)
            x, y = [(t, SIZE / 2 - inset), (t, -SIZE / 2 + inset + 0.2), (SIZE / 2 - inset, t), (-SIZE / 2 + inset, t)][side]
            if side >= 2 and y < -SIZE / 2 + 0.35:
                continue
            rig.cylinder(f"rivet{side}_{k}", (x, y, THICK - 0.01), (x, y, THICK + 0.03), 0.035, m["rivet"], verts=10)


def tiles(m, mat, n, top, gap=0.05, height=0.1, hexagon=False):
    """n x n raised tiles over the plate (above the band); hexagons for hard metal."""
    y0, y1 = -SIZE / 2 + 0.3, SIZE / 2 - 0.1
    x0, x1 = -SIZE / 2 + 0.1, SIZE / 2 - 0.1
    w, h = (x1 - x0) / n, (y1 - y0) / n
    for i in range(n):
        for j in range(n):
            cx = x0 + (i + 0.5) * w + (w / 2 if hexagon and j % 2 else 0)
            cy = y0 + (j + 0.5) * h
            if hexagon:
                if cx + w / 2 > x1 + 0.01:
                    continue
                rig.cylinder(f"tile{i}_{j}", (cx, cy, top), (cx, cy, top + height), min(w, h) / 2 - gap / 2, m[mat], verts=6)
            else:
                rig.box(f"tile{i}_{j}", (cx, cy, top + height / 2), (w - gap, h - gap, height), m[mat], bevel=0.015)


def composite(m):
    base(m, "brushed", "physical")
    rivets(m)
    # light corner brackets: the "armour" mark
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (SIZE / 2 - 0.3), sy * (SIZE / 2 - 0.3) + (0.1 if sy < 0 else 0)
            rig.box(f"bracket_a{sx}{sy}", (cx, cy + sy * 0.12, THICK + 0.02), (0.36, 0.08, 0.04), m["bracket"])
            rig.box(f"bracket_b{sx}{sy}", (cx + sx * 0.14, cy, THICK + 0.02), (0.08, 0.32, 0.04), m["bracket"])


def reactive(m, mat="steel", tile="era", n=3, fuses=True):
    base(m, mat, "explosion")
    tiles(m, tile, n, THICK)
    if fuses:
        for obj in [o for o in bpy.data.objects if o.name.startswith("tile")]:
            x, y = obj.location.x, obj.location.y
            rig.cylinder(f"fuse_{obj.name}", (x, y, THICK + 0.1), (x, y, THICK + 0.13), 0.05, m["fuse"], verts=12)


def acid(m):
    base(m, "steel", "acid")
    # glossy plastic coat over the plate, rivets show through as bumps
    rig.box("coat", (0, 0.1, THICK + 0.01), (SIZE - 0.16, SIZE - 0.36, 0.03), m["coat"], bevel=0.02)
    rivets(m, inset=0.06)


def fire(m):
    base(m, "steel", "fire")
    tiles(m, "ceramic", 4, THICK, gap=0.04, height=0.07)


def tungsten_carbide(m):
    base(m, "tungsten", "physical")
    tiles(m, "carbide", 5, THICK, gap=0.03, height=0.06, hexagon=True)


def tungsten_reactive(m):
    base(m, "tungsten", "explosion")
    # massive beams in two layers
    for k in range(4):
        y = -SIZE / 2 + 0.45 + k * 0.42
        rig.box(f"beam{k}", (0, y, THICK + 0.08), (SIZE - 0.2, 0.3, 0.16), m["tungsten"], bevel=0.03)
        for i in range(5):
            x = -SIZE / 2 + 0.3 + i * 0.35
            rig.cylinder(f"fuse{k}{i}", (x, y, THICK + 0.16), (x, y, THICK + 0.19), 0.04, m["fuse"], verts=10)


def tungsten_acid(m):
    base(m, "tungsten", "acid")
    tiles(m, "passive", 5, THICK, gap=0.03, height=0.06, hexagon=True)


def armor_steel(m):
    """Thick blue-grey slab with rolling marks."""
    rig.box("slab", (0, 0, 0.2), (SIZE, SIZE * 0.7, 0.4), m["steel"], bevel=0.05)
    for k in range(7):
        y = -SIZE * 0.3 + k * SIZE * 0.1
        rig.box(f"roll{k}", (0, y, 0.405), (SIZE - 0.1, 0.012, 0.004), m["dark"], bevel=0)


PLATES = {
    "composite-armor-plate": composite,
    "reactive-armor-plate": reactive,
    "acid-armor-plate": acid,
    "fire-armor-plate": fire,
    "tungsten-carbide-armor-plate": tungsten_carbide,
    "tungsten-reactive-armor-plate": tungsten_reactive,
    "tungsten-carbide-acid-armor-plate": tungsten_acid,
    "armor-steel": armor_steel,
}


def render(name, out_dir):
    rig.ROOT = None
    scene = rig.reset()
    m = materials()
    PLATES[name](m)
    rig.root().rotation_euler = (0, 0, math.radians(-12))
    rig.camera(2.9, 2.9, supersample=1, shift_y=0.0)
    scene.render.resolution_x = scene.render.resolution_y = 512
    rig.sun(4.2)
    rig.fill_light(0.8)
    scene.cycles.samples = 64
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    a = rig.args()
    out = a[0]
    os.makedirs(out, exist_ok=True)
    for name in a[1:] or list(PLATES):
        render(name, out)

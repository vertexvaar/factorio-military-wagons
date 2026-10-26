"""Armour plate icons and the armour steel icon.

Run:  blender -b --factory-startup -P tools/blender/plates.py -- <out_dir> [name ...]
Writes <out_dir>/<name>.png (512 px, transparent) for every plate in PLATES and for
armor-steel. tools/blender/build_icons.py turns them into the icon and equipment sprites.

Colour code shared by all plates: the painted band along the lower edge is grey for physical,
orange for explosion, green for acid, red for fire. Steel is blue-grey, tungsten anthracite.
Every plate is field equipment: bolted on, welded, rusty at the seams, scratched where it
has been hit.
"""
import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import rig  # noqa: E402

SIZE = 2.0  # plate edge
THICK = 0.16
TOP = THICK
BAND = {
    "physical": (0.22, 0.22, 0.21),
    "explosion": (0.7, 0.3, 0.03),
    "acid": (0.22, 0.45, 0.08),
    "fire": (0.55, 0.07, 0.04),
}


def materials():
    return {
        "steel": rig.material("steel", (0.27, 0.31, 0.36), roughness=0.5, metallic=0.75, grime=0.5, scale=5, bump=0.18,
                              rust=0.65),
        "steel_clean": rig.material("steel_clean", (0.36, 0.4, 0.45), roughness=0.4, metallic=0.85, grime=0.35, scale=9,
                                    bump=0.1, rust=0.35),
        "edge": rig.material("edge", (0.55, 0.57, 0.6), roughness=0.25, metallic=0.95, grime=0.1, scale=20, bump=0.2),
        "ceramic_layer": rig.material("ceramic_layer", (0.7, 0.66, 0.58), roughness=0.85, grime=0.3, scale=14),
        "rubber": rig.material("rubber", (0.06, 0.06, 0.06), roughness=0.9, grime=0.1),
        "bolt": rig.material("bolt", (0.5, 0.5, 0.52), roughness=0.35, metallic=0.9, grime=0.3, scale=30, rust=0.4),
        "weld": rig.material("weld", (0.28, 0.27, 0.26), roughness=0.6, metallic=0.7, grime=0.4, scale=40, bump=0.4,
                             rust=0.5),
        "tungsten": rig.material("tungsten", (0.12, 0.12, 0.14), roughness=0.4, metallic=0.9, grime=0.25, scale=6,
                                 bump=0.12, rust=0.1),
        "carbide": rig.material("carbide", (0.17, 0.17, 0.19), roughness=0.22, metallic=0.75, grime=0.12, scale=12,
                                bump=0.2),
        "braze": rig.material("braze", (0.62, 0.42, 0.2), roughness=0.35, metallic=0.9, grime=0.3, scale=25),
        "era": rig.material("era", (0.2, 0.22, 0.15), roughness=0.65, grime=0.55, scale=4, bump=0.2, rust=0.5),
        "fuse": rig.material("fuse", (0.75, 0.42, 0.05), roughness=0.5, grime=0.4, scale=20),
        "hazard_y": rig.material("hazard_y", (0.7, 0.5, 0.04), roughness=0.6, grime=0.5, scale=6, rust=0.35),
        "hazard_k": rig.material("hazard_k", (0.04, 0.04, 0.04), roughness=0.7, grime=0.2),
        "coat": rig.material("coat", (0.08, 0.13, 0.09), roughness=0.18, metallic=0.0, grime=0.35, scale=3, bump=0.05,
                             rust=0.25),
        "acid_stain": rig.material("acid_stain", (0.3, 0.27, 0.08), roughness=0.75, grime=0.7, scale=14, bump=0.2),
        "passive": rig.material("passive", (0.14, 0.22, 0.17), roughness=0.2, metallic=0.55, grime=0.15, scale=7),
        "ceramic": rig.material("ceramic", (0.3, 0.25, 0.2), roughness=0.85, grime=0.6, scale=6, bump=0.35),
        "soot": rig.material("soot", (0.12, 0.1, 0.085), roughness=0.95, grime=0.6, scale=5, bump=0.3),
        "temper": rig.material("temper", (0.24, 0.22, 0.27), roughness=0.4, metallic=0.85, grime=0.5, scale=8, rust=0.3),
        "dark": rig.material("dark", (0.035, 0.035, 0.04), roughness=0.6),
        "stencil": rig.material("stencil", (0.65, 0.65, 0.6), roughness=0.6, grime=0.6, scale=12),
        **{"band_" + k: rig.material("band_" + k, c, roughness=0.55, grime=0.5, scale=5, rust=0.55) for k, c in BAND.items()},
    }


# --- parts -------------------------------------------------------------------------------


def slab(m, mat, layered=None):
    """The plate body with chamfered edges. layered: materials of the laminate, visible as
    stripes on the front edge (bottom to top)."""
    rig.box("plate", (0, 0, THICK / 2), (SIZE, SIZE, THICK), m[mat], bevel=0.035)
    if layered:
        h = THICK / len(layered)
        for i, layer in enumerate(layered):
            rig.box(f"layer{i}", (0, -SIZE / 2 - 0.004, h * (i + 0.5)), (SIZE - 0.08, 0.012, h * 0.8), m[layer], bevel=0)
            rig.box(f"layer_r{i}", (SIZE / 2 + 0.004, 0, h * (i + 0.5)), (0.012, SIZE - 0.08, h * 0.8), m[layer], bevel=0)


def band(m, kind, hazard=False):
    """Painted damage type band along the lower edge, chipped; hazard stripes on explosives."""
    y = -SIZE / 2 + 0.16
    rig.box("band", (0, y, TOP + 0.004), (SIZE - 0.14, 0.16, 0.008), m["band_" + kind], bevel=0)
    if hazard:
        for k in range(9):
            x = -SIZE / 2 + 0.2 + k * 0.2
            rig.box(f"stripe{k}", (x, y, TOP + 0.01), (0.07, 0.17, 0.006), m["hazard_k"], bevel=0,
                    rotation=(0, 0, math.radians(35)))


def hex_bolt(name, x, y, z, m, size=0.055):
    """Washer, hex head and a short thread stub."""
    rig.cylinder(name + "_w", (x, y, z), (x, y, z + 0.012), size * 1.45, m["bolt"], verts=20)
    rig.cylinder(name + "_h", (x, y, z + 0.012), (x, y, z + 0.045), size, m["bolt"], verts=6, bevel=0.006)
    rig.cylinder(name + "_t", (x, y, z + 0.045), (x, y, z + 0.06), size * 0.55, m["bolt"], verts=10)


def corner_bolts(m, inset=0.17, z=TOP, size=0.06):
    for sx in (-1, 1):
        for sy in (-1, 1):
            hex_bolt(f"cb{sx}{sy}", sx * (SIZE / 2 - inset), sy * (SIZE / 2 - inset) + (0.12 if sy < 0 else 0), z, m, size)


def weld(name, a, b, m, radius=0.018):
    """Weld bead: a row of overlapping squashed blobs."""
    n = max(2, int(math.dist(a, b) / 0.03))
    for i in range(n + 1):
        t = i / n
        x, y, z = (a[k] + (b[k] - a[k]) * t for k in range(3))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=radius, location=(x, y, z))
        blob = bpy.context.object
        blob.name = f"{name}{i}"
        blob.scale = (1.0, 1.0, 0.55)
        rig._finish(blob, m["weld"], 0, False)


def lifting_lugs(m):
    """Two welded lifting eyes on the top edge."""
    for sx in (-1, 1):
        x = sx * 0.55
        y = SIZE / 2 - 0.12
        rig.box(f"lug{sx}", (x, y, TOP + 0.05), (0.16, 0.05, 0.1), m["steel_clean"], bevel=0.01)
        rig.cylinder(f"lug_hole{sx}", (x, y - 0.03, TOP + 0.06), (x, y + 0.03, TOP + 0.06), 0.032, m["dark"], verts=12)
        weld(f"lugw{sx}", (x - 0.08, y - 0.03, TOP + 0.005), (x + 0.08, y - 0.03, TOP + 0.005), m, 0.012)


def hits(m, rng, count, area=(-0.8, 0.8, -0.5, 0.85), mat="edge", z=TOP):
    """Bright dents where something hit the plate: a crater ring and a scratch."""
    x0, x1, y0, y1 = area
    for i in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(0.03, 0.06)
        rig.torus(f"dent{i}", (x, y, z + 0.003), r, r * 0.25, m[mat])
        rig.cylinder(f"dent_c{i}", (x, y, z - 0.004), (x, y, z + 0.002), r * 0.8, m["dark"], verts=12)
        a = rng.uniform(0, math.pi)
        length = rng.uniform(0.12, 0.3)
        rig.box(f"scratch{i}", (x + math.cos(a) * length / 2, y + math.sin(a) * length / 2, z + 0.002),
                (length, 0.008, 0.004), m[mat], bevel=0, rotation=(0, 0, a))


def drip(name, x, top_y, length, width, z, m):
    """A flat acid run-off stain: wide where it started, thinning down, ending in a drop."""
    verts, faces = [], []
    steps = 8
    for k in range(steps + 1):
        t = k / steps
        w = width * (1 - 0.7 * t) * (0.8 + 0.2 * math.sin(t * 9 + x * 5))
        y = top_y - length * t
        verts += [(x - w / 2, y, z), (x + w / 2, y, z)]
        if k:
            a = 2 * k
            faces.append((a - 2, a - 1, a + 1, a))
    rig.mesh(name, verts, faces, m["acid_stain"])
    rig.cylinder(name + "_drop", (x, top_y - length, z), (x, top_y - length, z + 0.0007), width * 0.45,
                 m["acid_stain"], verts=10)


def stencil(m, x, y, text_bars, z=TOP):
    """Faded stencilled marking: short bars that read as letters at icon size."""
    for i, (dx, w) in enumerate(text_bars):
        rig.box(f"sten{x}{i}", (x + dx, y, z + 0.005), (w, 0.05, 0.004), m["stencil"], bevel=0)


def hexagons(m, mat, n, top, gap, height, under=None):
    """Hexagonal tiles over the plate (above the band); under: a brazing ring below each."""
    y0, y1 = -SIZE / 2 + 0.34, SIZE / 2 - 0.12
    x0, x1 = -SIZE / 2 + 0.12, SIZE / 2 - 0.12
    w, h = (x1 - x0) / n, (y1 - y0) / n
    r = min(w, h) / 2 - gap / 2
    for i in range(n):
        for j in range(n):
            cx = x0 + (i + 0.5) * w + (w / 2 if j % 2 else 0)
            cy = y0 + (j + 0.5) * h
            if cx + w / 2 > x1 + 0.01:
                continue
            if under:
                rig.cylinder(f"braze{i}_{j}", (cx, cy, top), (cx, cy, top + 0.012), r + gap * 0.4, m[under], verts=6)
            rig.cylinder(f"hex{i}_{j}", (cx, cy, top + 0.01), (cx, cy, top + 0.01 + height), r, m[mat], verts=6,
                         bevel=0.008)


# --- plates ------------------------------------------------------------------------------


def composite(m):
    """Steel-ceramic-steel laminate in two bolted halves, welded lifting lugs."""
    rng = random.Random(1)
    slab(m, "steel", layered=["steel", "ceramic_layer", "rubber", "ceramic_layer", "steel"])
    band(m, "physical")
    # the face is two raised cover plates, bolted along the seam
    for sx in (-1, 1):
        rig.box(f"cover{sx}", (sx * (SIZE / 4 - 0.02), 0.13, TOP + 0.02), (SIZE / 2 - 0.12, SIZE - 0.5, 0.04), m["steel"],
                bevel=0.018)
    for k in range(5):
        y = -0.5 + k * 0.3
        for sx in (-1, 1):
            hex_bolt(f"sb{k}{sx}", sx * 0.1, y, TOP + 0.04, m, 0.035)
    corner_bolts(m)
    lifting_lugs(m)
    hits(m, rng, 3, z=TOP + 0.04)
    stencil(m, -0.5, -0.38, [(-0.12, 0.08), (0, 0.08), (0.12, 0.08)], z=TOP + 0.04)


def reactive(m):
    """Explosive reactive bricks in a welded steel frame; each brick has fuse caps and
    clamping bolts. Hazard stripes on the band."""
    rng = random.Random(2)
    slab(m, "steel")
    band(m, "explosion", hazard=True)
    n = 3
    y0, y1 = -SIZE / 2 + 0.36, SIZE / 2 - 0.1
    x0, x1 = -SIZE / 2 + 0.1, SIZE / 2 - 0.1
    w, h = (x1 - x0) / n, (y1 - y0) / n
    for i in range(n + 1):
        x = x0 + i * w
        rig.box(f"frame_v{i}", (x, (y0 + y1) / 2, TOP + 0.06), (0.05, y1 - y0, 0.12), m["steel_clean"], bevel=0.008)
    for j in range(n + 1):
        y = y0 + j * h
        rig.box(f"frame_h{j}", ((x0 + x1) / 2, y, TOP + 0.06), (x1 - x0, 0.05, 0.12), m["steel_clean"], bevel=0.008)
    for i in range(n):
        for j in range(n):
            cx, cy = x0 + (i + 0.5) * w, y0 + (j + 0.5) * h
            bulge = 0.01 if (i + j) % 4 == 1 else 0
            rig.box(f"brick{i}_{j}", (cx, cy, TOP + 0.07 + bulge), (w - 0.09, h - 0.09, 0.12), m["era"], bevel=0.02)
            # clamp bar across each brick
            rig.box(f"clamp{i}_{j}", (cx, cy, TOP + 0.135 + bulge), (w - 0.14, 0.035, 0.012), m["steel_clean"], bevel=0)
            for sx in (-1, 1):
                hex_bolt(f"cbolt{i}{j}{sx}", cx + sx * (w / 2 - 0.1), cy, TOP + 0.13 + bulge, m, 0.025)
            rig.cylinder(f"fuse{i}_{j}", (cx, cy + 0.09, TOP + 0.13), (cx, cy + 0.09, TOP + 0.16), 0.03, m["fuse"],
                         verts=12)
            # warning triangle stencil on every other brick
            if (i + j) % 2 == 0:
                rig.mesh(f"warn{i}_{j}", [(cx - 0.06, cy - 0.11, TOP + 0.132 + bulge), (cx + 0.06, cy - 0.11, TOP + 0.132 + bulge),
                                         (cx, cy - 0.01, TOP + 0.132 + bulge)], [(0, 1, 2)], m["hazard_y"])
    for i in range(n + 1):
        weld(f"fw{i}", (x0 + i * w, y0, TOP + 0.003), (x0 + i * w, y0 + 0.2, TOP + 0.003), m, 0.012)
    hits(m, rng, 2, area=(-0.8, 0.8, -0.62, -0.5))


def acid(m):
    """Steel plate under a thick polymer coat: drain ribs, chipped edges, acid stains."""
    rng = random.Random(3)
    slab(m, "steel")
    band(m, "acid")
    rig.box("coat", (0, 0.11, TOP + 0.012), (SIZE - 0.12, SIZE - 0.42, 0.024), m["coat"], bevel=0.03)
    # diagonal drain ribs moulded into the coat
    for k in range(5):
        y = -0.45 + k * 0.3
        rig.box(f"rib{k}", (0, y, TOP + 0.03), (SIZE - 0.4, 0.04, 0.018), m["coat"], bevel=0.008)
        for sx in (-1, 1):
            rig.cylinder(f"drain{k}{sx}", (sx * 0.82, y, TOP + 0.02), (sx * 0.82, y, TOP + 0.03), 0.03, m["dark"], verts=10)
    # chips in the coat show bare steel
    for i in range(6):
        x, y = rng.choice((-1, 1)) * rng.uniform(0.7, 0.9), rng.uniform(-0.6, 0.85)
        rig.cylinder(f"chip{i}", (x, y, TOP + 0.024), (x, y, TOP + 0.027), rng.uniform(0.03, 0.07), m["edge"], verts=7)
    # acid stains run down from the top: flat, tapering drips lying on the coat
    for i in range(5):
        x = rng.uniform(-0.75, 0.75)
        length = rng.uniform(0.3, 0.75)
        drip(f"stain{i}", x, SIZE / 2 - 0.2, length, rng.uniform(0.06, 0.11), TOP + 0.0245, m)
    corner_bolts(m, size=0.055)
    lifting_lugs(m)


def fire(m):
    """Ceramic tiles in a steel grid, scorched: soot towards the middle, temper colours on
    the grid, a few cracked tiles."""
    rng = random.Random(4)
    slab(m, "steel")
    band(m, "fire")
    n = 4
    y0, y1 = -SIZE / 2 + 0.34, SIZE / 2 - 0.1
    x0, x1 = -SIZE / 2 + 0.1, SIZE / 2 - 0.1
    w, h = (x1 - x0) / n, (y1 - y0) / n
    for i in range(n + 1):
        rig.box(f"grid_v{i}", (x0 + i * w, (y0 + y1) / 2, TOP + 0.04), (0.03, y1 - y0, 0.08), m["temper"], bevel=0.005)
    for j in range(n + 1):
        rig.box(f"grid_h{j}", ((x0 + x1) / 2, y0 + j * h, TOP + 0.04), (x1 - x0, 0.03, 0.08), m["temper"], bevel=0.005)
    for i in range(n):
        for j in range(n):
            cx, cy = x0 + (i + 0.5) * w, y0 + (j + 0.5) * h
            centre = abs(i - 1.5) + abs(j - 1.5) < 2
            mat = "soot" if centre and rng.random() < 0.6 else "ceramic"
            rig.box(f"tile{i}_{j}", (cx, cy, TOP + 0.035), (w - 0.05, h - 0.05, 0.07), m[mat], bevel=0.012)
            if rng.random() < 0.25:
                a = rng.uniform(0, math.pi)
                rig.box(f"crack{i}_{j}", (cx, cy, TOP + 0.072), (w * 0.7, 0.006, 0.004), m["dark"], bevel=0,
                        rotation=(0, 0, a))
    for sx in (-1, 1):
        for sy in (-1, 1):
            hex_bolt(f"gb{sx}{sy}", sx * (SIZE / 2 - 0.1), (y0 if sy < 0 else y1), TOP + 0.08, m, 0.04)


def tungsten_carbide(m):
    """Heavy tungsten backing with brazed carbide hexagons, bright where shots glanced off."""
    rng = random.Random(5)
    slab(m, "tungsten", layered=["tungsten", "tungsten", "steel"])
    band(m, "physical")
    hexagons(m, "carbide", 5, TOP, gap=0.035, height=0.06, under="braze")
    corner_bolts(m, size=0.07)
    hits(m, rng, 4, area=(-0.8, 0.8, -0.45, 0.85))


def tungsten_reactive(m):
    """Massive tungsten beams over reactive bricks, fuse caps between the beams."""
    rng = random.Random(6)
    slab(m, "tungsten")
    band(m, "explosion", hazard=True)
    rows = 4
    for k in range(rows):
        y = -SIZE / 2 + 0.47 + k * 0.42
        rig.box(f"brick{k}", (0, y, TOP + 0.05), (SIZE - 0.24, 0.36, 0.1), m["era"], bevel=0.02)
        rig.box(f"beam{k}", (0, y + 0.1, TOP + 0.13), (SIZE - 0.16, 0.13, 0.1), m["tungsten"], bevel=0.02)
        for i in range(5):
            x = -SIZE / 2 + 0.32 + i * 0.34
            rig.cylinder(f"fuse{k}{i}", (x, y - 0.07, TOP + 0.1), (x, y - 0.07, TOP + 0.13), 0.035, m["fuse"], verts=10)
        for sx in (-1, 1):
            hex_bolt(f"bb{k}{sx}", sx * (SIZE / 2 - 0.2), y + 0.1, TOP + 0.18, m, 0.04)
    hits(m, rng, 2, area=(-0.7, 0.7, -0.2, 0.9))


def tungsten_acid(m):
    """Carbide hexagons under a passivated acid-proof skin, glossy, with stains."""
    rng = random.Random(7)
    slab(m, "tungsten")
    band(m, "acid")
    hexagons(m, "passive", 5, TOP, gap=0.03, height=0.06, under="braze")
    # etched spots on some tiles
    tiles = [o for o in bpy.data.objects if o.name.startswith("hex")]
    for i, tile in enumerate(rng.sample(tiles, 6)):
        x, y = tile.location.x, tile.location.y
        rig.cylinder(f"etch{i}", (x, y, TOP + 0.0705), (x, y, TOP + 0.0712), rng.uniform(0.04, 0.07), m["acid_stain"],
                     verts=9)
    corner_bolts(m, size=0.07)


def armor_steel(m):
    """Stack of two rolled armour steel slabs with stamped heat numbers and temper colours."""
    rig.box("slab_low", (0.04, -0.04, 0.12), (SIZE * 0.95, SIZE * 0.62, 0.24), m["steel"], bevel=0.04)
    rig.box("slab_high", (-0.04, 0.06, 0.37), (SIZE * 0.9, SIZE * 0.58, 0.24), m["steel_clean"], bevel=0.04)
    rig.box("temper_edge", (-0.04, 0.06 - SIZE * 0.29 - 0.003, 0.37), (SIZE * 0.86, 0.008, 0.2), m["temper"], bevel=0)
    for k in range(6):
        y = -0.4 + k * 0.17
        rig.box(f"roll{k}", (-0.04, y, 0.492), (SIZE * 0.85, 0.01, 0.004), m["dark"], bevel=0)
    # stamped heat number
    for i, x in enumerate((-0.5, -0.4, -0.3, -0.2)):
        rig.box(f"stamp{i}", (x, 0.4, 0.493), (0.05, 0.08, 0.004), m["stencil"], bevel=0)


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


def render(name, out_dir, samples=64):
    rig.ROOT = None
    scene = rig.reset()
    m = materials()
    PLATES[name](m)
    rig.root().rotation_euler = (0, 0, math.radians(-12))
    rig.camera(2.9, 2.9, supersample=1, shift_y=0.0)
    scene.render.resolution_x = scene.render.resolution_y = 512
    rig.sun(3.3)
    rig.fill_light(0.8)
    scene.cycles.samples = samples
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    a = rig.args()
    out = a[0]
    os.makedirs(out, exist_ok=True)
    samples = int(os.environ.get("PLATE_SAMPLES", "64"))
    for name in a[1:] or list(PLATES):
        render(name, out, samples)

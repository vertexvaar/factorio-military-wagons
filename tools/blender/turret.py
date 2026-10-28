"""Turret heads that the game draws on top of a wagon: howitzer (howitzer), mine launcher basket (mine).

Run:  blender -b --factory-startup -P tools/blender/turret.py -- <variant> <out_dir> [frames...]
Frames are 0..63, frame i shows the barrel pointing at orientation i/64 (clockwise from north).
The head is modelled at its height on the wagon (the barbette top), so it lines up with the
wagon sprite when both are drawn at the mount position.
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.dirname(__file__))
import rig  # noqa: E402
import wagon  # noqa: E402

DIRECTIONS = 64


def howitzer(m):
    """Box turret with a square cradle. The cradle's elevation pivot (trunnion) sits in the
    middle of the turret; the long barrel runs out of it and ends in a muzzle brake.
    Barrel points north (+Y)."""
    base = wagon.VARIANTS["howitzer"]["top"]
    radius = wagon.VARIANTS["howitzer"]["radius"]
    # turret ring and the welded box on it, wider at the back for the crew
    rig.cylinder("ring", (0, 0, base), (0, 0, base + 0.08), radius - 0.03, m["steel"], verts=48)
    h = 0.62
    z0 = base + 0.08
    hull = rig.mesh(
        "turret",
        [
            (-0.72, -0.9, z0), (0.72, -0.9, z0), (0.78, 0.55, z0), (-0.78, 0.55, z0),
            (-0.6, -0.82, z0 + h), (0.6, -0.82, z0 + h), (0.62, 0.42, z0 + h), (-0.62, 0.42, z0 + h),
            (-0.5, 0.86, z0 + 0.12), (0.5, 0.86, z0 + 0.12), (0.42, 0.7, z0 + h - 0.08), (-0.42, 0.7, z0 + h - 0.08),
        ],
        [
            (0, 1, 5, 4), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 6, 7),
            (2, 9, 10, 6), (3, 7, 11, 8), (6, 10, 11, 7), (8, 11, 10, 9), (2, 3, 8, 9), (0, 3, 2, 1),
        ],
        m["armour"], bevel=0.03, mask=True,
    )
    bm = bmesh.new()
    bm.from_mesh(hull.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(hull.data)
    bm.free()
    top = z0 + h
    # roof: hatches, sight and a bustle rack at the back
    for k, x in enumerate((-0.32, 0.32)):
        rig.cylinder(f"hatch{k}", (x, -0.4, top - 0.01), (x, -0.4, top + 0.05), 0.17, m["armour"], verts=24, mask=True)
        rig.box(f"hatch_hinge{k}", (x, -0.58, top + 0.05), (0.18, 0.04, 0.04), m["steel"])
    rig.box("sight", (0.42, 0.25, top + 0.08), (0.14, 0.2, 0.16), m["armour"], mask=True)
    rig.box("sight_glass", (0.42, 0.355, top + 0.1), (0.1, 0.01, 0.06), m["slit"], bevel=0)
    rig.box("bustle", (0, -1.02, z0 + 0.36), (1.2, 0.26, 0.04), m["steel"])
    for sx in (-1, 1):
        rig.box(f"bustle_side{sx}", (sx * 0.6, -1.02, z0 + 0.44), (0.04, 0.26, 0.16), m["steel"])
    rig.box("bustle_back", (0, -1.14, z0 + 0.44), (1.2, 0.03, 0.16), m["steel"])
    for k, x in enumerate((-0.32, 0.0, 0.32)):
        wagon.crate(f"bustle_crate{k}", m, (x, -1.02, z0 + 0.38), (0.26, 0.2, 0.14))
    wagon.rivet_row("turret_rivets_l", (-0.6, -0.8, top + 0.005), (-0.6, 0.4, top + 0.005), 8, m, radius=0.014, axis="z")
    wagon.rivet_row("turret_rivets_r", (0.6, -0.8, top + 0.005), (0.6, 0.4, top + 0.005), 8, m, radius=0.014, axis="z")
    # trunnion in the turret middle, the square cradle runs forward out of the front slot
    pivot_z = z0 + 0.36
    rig.cylinder("trunnion", (-0.66, 0, pivot_z), (0.66, 0, pivot_z), 0.09, m["steel"], verts=16)
    rig.box("front_slot", (0, 0.8, pivot_z), (0.34, 0.12, 0.34), m["slit"], bevel=0)
    rig.box("cradle", (0, 0.65, pivot_z), (0.3, 1.5, 0.3), m["armour"], bevel=0.02, mask=True)
    rig.box("cradle_collar", (0, 1.38, pivot_z), (0.34, 0.08, 0.34), m["steel"])
    for sx in (-1, 1):
        # recoil cylinders along the cradle
        rig.cylinder(f"recuperator{sx}", (sx * 0.12, 0.85, pivot_z + 0.19), (sx * 0.12, 1.4, pivot_z + 0.19), 0.045, m["steel"])
    # long barrel, thickening towards the breech, with a fume extractor and a muzzle brake
    barrel_end = 3.55
    rig.cylinder("barrel_root", (0, 1.4, pivot_z), (0, 2.1, pivot_z), 0.085, m["paint"], verts=20, mask=True)
    rig.cylinder("fume_extractor", (0, 2.1, pivot_z), (0, 2.45, pivot_z), 0.11, m["paint"], verts=20, mask=True)
    rig.cylinder("barrel", (0, 2.45, pivot_z), (0, barrel_end - 0.22, pivot_z), 0.07, m["paint"], verts=20, mask=True)
    rig.cylinder("brake", (0, barrel_end - 0.22, pivot_z), (0, barrel_end, pivot_z), 0.11, m["dark"], verts=20)
    for k, y in enumerate((barrel_end - 0.17, barrel_end - 0.08)):
        for sx in (-1, 1):
            rig.box(f"brake_port{k}{sx}", (sx * 0.1, y, pivot_z), (0.04, 0.05, 0.1), m["slit"], bevel=0)
    rig.cylinder("bore", (0, barrel_end - 0.005, pivot_z), (0, barrel_end + 0.002, pivot_z), 0.045, m["slit"], verts=16)
    # travel lock on the wagon sits in front; on the turret only the lifting eyes
    for sx in (-1, 1):
        rig.torus(f"eye{sx}", (sx * 0.5, 0.15, top + 0.04), 0.04, 0.012, m["steel"], rotation=(0, math.pi / 2, 0))


def mine_basket(m):
    """One mine launcher like the Skorpion's: a turning base, a cradle of cross-braced side frames
    and between them the launcher box, tilted up towards the front, whose face holds a grid of
    5 x 4 tubes. Modelled around its own mount (the origin), at its height on the wagon.
    Points north (+Y)."""
    base = wagon.VARIANTS["mine"]["top"]
    radius = wagon.VARIANTS["mine"]["radius"]
    # turning base with a bolted ring
    rig.cylinder("base_plate", (0, 0, base), (0, 0, base + 0.05), radius - 0.02, m["armour"], verts=40, mask=True)
    for k in range(10):
        a = 2 * math.pi * k / 10
        r = radius - 0.06
        rig.cylinder(f"base_bolt{k}", (math.cos(a) * r, math.sin(a) * r, base + 0.05),
                     (math.cos(a) * r, math.sin(a) * r, base + 0.065), 0.012, m["rivet"], verts=8)
    width, depth, face = 0.72, 0.5, 0.46  # box across, along the tubes, height of the face
    pivot = (0, -0.04, base + 0.3)
    # cradle: a cross-braced side frame on each side, carrying the trunnion
    for sx in (-1, 1):
        x = sx * (width / 2 + 0.035)
        for k, (y0, y1) in enumerate(((-0.24, 0.0), (0.18, 0.0))):
            rig.cylinder(f"leg{sx}{k}", (x, y0, base + 0.05), (x, pivot[1] + y1, pivot[2]), 0.018, m["armour"], verts=8)
        rig.cylinder(f"brace{sx}", (x, -0.2, base + 0.08), (x, 0.14, base + 0.08), 0.014, m["armour"], verts=8)
        rig.cylinder(f"cross{sx}a", (x, -0.2, base + 0.08), (x, 0.08, base + 0.22), 0.01, m["steel"], verts=6)
        rig.cylinder(f"cross{sx}b", (x, 0.14, base + 0.08), (x, -0.14, base + 0.22), 0.01, m["steel"], verts=6)
        rig.cylinder(f"trunnion{sx}", (sx * (width / 2 - 0.01), pivot[1], pivot[2]),
                     (sx * (width / 2 + 0.07), pivot[1], pivot[2]), 0.035, m["steel"], verts=12)
    tilt = math.radians(40)
    d = (0, math.cos(tilt), math.sin(tilt))  # along the tubes, out of the face
    up = (0, -math.sin(tilt), math.cos(tilt))  # the box's top side

    def at(t, h=0.0, x=0.0):
        return (x, pivot[1] + d[1] * t + up[1] * h, pivot[2] + d[2] * t + up[2] * h)

    rot = (tilt, 0, 0)
    # the box hangs a little behind its pivot, so the face stands out in front
    c = 0.02
    rig.box("launcher", at(c), (width, depth, face), m["armour"], bevel=0.012, mask=True, rotation=rot)
    # angle profiles along the edges and two bands round the box
    for sx in (-1, 1):
        for sh in (-1, 1):
            rig.box(f"edge{sx}{sh}", at(c, sh * face / 2, sx * width / 2), (0.035, depth + 0.01, 0.035), m["steel"], bevel=0.004, rotation=rot)
    for k, t in enumerate((-0.12, 0.12)):
        rig.box(f"band{k}", at(c + t), (width + 0.014, 0.04, face + 0.014), m["dark" if k else "hazard"], bevel=0, rotation=rot)
    # the face: a steel plate with 5 x 4 tubes, each a dark bore in a rim
    front = c + depth / 2
    rig.box("face", at(front + 0.005), (width - 0.02, 0.012, face - 0.02), m["steel"], bevel=0.004, rotation=rot)
    for i in range(5):
        for j in range(4):
            x = (i - 2) * (width - 0.12) / 4
            h = (j - 1.5) * (face - 0.1) / 3
            rig.cylinder(f"tube{i}{j}", at(front + 0.004, h, x), at(front + 0.03, h, x), 0.05, m["paint"], verts=14)
            rig.cylinder(f"bore{i}{j}", at(front + 0.025, h, x), at(front + 0.032, h, x), 0.036, m["slit"], verts=14)
    # back plate with a cable plug, lifting eyes on top, rivets along the top
    rig.box("back", at(c - depth / 2 - 0.006), (width - 0.06, 0.012, face - 0.06), m["dark"], bevel=0, rotation=rot)
    rig.cylinder("plug", at(c - depth / 2 - 0.01, -0.1, 0.2), at(c - depth / 2 - 0.06, -0.1, 0.2), 0.03, m["brass"], verts=10)
    rig.cylinder("cable", at(c - depth / 2 - 0.06, -0.1, 0.2), (0.22, -0.3, base + 0.06), 0.014, m["dark"], verts=8)
    for sx in (-1, 1):
        rig.torus(f"eye{sx}", at(c, face / 2 + 0.03, sx * 0.24), 0.03, 0.008, m["steel"], rotation=(tilt, math.pi / 2, 0))
        for k in range(6):
            rig.cylinder(f"rivet{sx}{k}", at(c - 0.2 + k * 0.08, face / 2 + 0.002, sx * (width / 2 - 0.05)),
                         at(c - 0.2 + k * 0.08, face / 2 + 0.014, sx * (width / 2 - 0.05)), 0.011, m["rivet"], verts=8)
    # elevation ram from the base to the box's underside
    rig.cylinder("ram", (0, 0.2, base + 0.06), at(c + 0.12, -face / 2), 0.03, m["steel"], verts=10)
    rig.cylinder("ram_body", (0, 0.2, base + 0.06), (0, 0.17, base + 0.16), 0.045, m["dark"], verts=12)


def build(variant):
    rig.reset()
    m = wagon.materials()
    if variant == "howitzer":
        howitzer(m)
        rig.camera(8, 8, shift_y=1.4)
    elif variant == "mine":
        mine_basket(m)
        rig.camera(4, 4, shift_y=1.0)
    else:
        sys.exit(f"unknown turret {variant}")
    rig.sun()
    rig.fill_light()


if __name__ == "__main__":
    a = rig.args()
    variant, out = a[0], a[1]
    frames = [int(x) for x in a[2:]] or list(range(DIRECTIONS))
    build(variant)
    rig.render_frames(out, frames, lambda i: i / DIRECTIONS, passes=("color", "mask", "shadow"), samples=24)

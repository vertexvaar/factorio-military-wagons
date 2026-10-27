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
    """One launcher basket on its pivot: a turning yoke with two cheeks, and the armoured
    basket between them, tilted up towards the front, a mine package in its mouth.
    Modelled around its own mount (the origin), at its height on the wagon. Points north (+Y)."""
    base = wagon.VARIANTS["mine"]["top"]
    radius = wagon.VARIANTS["mine"]["radius"]
    rig.cylinder("yoke_plate", (0, 0, base), (0, 0, base + 0.05), radius - 0.03, m["armour"], verts=32, mask=True)
    pivot_z = base + 0.2
    for sx in (-1, 1):
        rig.box(f"cheek{sx}", (sx * 0.19, -0.02, base + 0.13), (0.035, 0.24, 0.22), m["armour"], mask=True)
        rig.cylinder(f"trunnion{sx}", (sx * 0.17, 0, pivot_z), (sx * 0.22, 0, pivot_z), 0.035, m["steel"], verts=12)
    tilt = math.radians(35)
    d = (0, math.cos(tilt), math.sin(tilt))  # along the basket, towards the mouth
    up = (0, -math.sin(tilt), math.cos(tilt))  # out of the basket's top face
    length, width, height = 0.46, 0.3, 0.26

    def at(t, h=0.0):
        return (0, d[1] * t + up[1] * h, pivot_z + d[2] * t + up[2] * h)

    rot = (tilt, 0, 0)
    rig.box("basket", at(0.04), (width, length, height), m["armour"], bevel=0.015, mask=True, rotation=rot)
    rig.box("basket_band", at(-0.1), (width + 0.012, 0.05, height + 0.012), m["hazard"], bevel=0, rotation=rot)
    rig.box("basket_lip", at(0.04 + length / 2 - 0.02), (width + 0.03, 0.04, height + 0.03), m["steel"], rotation=rot)
    rig.box("basket_mouth", at(0.04 + length / 2 + 0.001), (width - 0.06, 0.01, height - 0.06), m["slit"], bevel=0, rotation=rot)
    # the package's nose in the mouth: a land mine with its brass fuse
    nose = at(0.04 + length / 2 - 0.01)
    tip = at(0.04 + length / 2 + 0.03)
    rig.cylinder("package", nose, tip, 0.09, m["dark"], verts=20)
    rig.cylinder("fuse", tip, at(0.04 + length / 2 + 0.05), 0.03, m["brass"], verts=12)
    # rivets along the top edges, a handle at the back
    for sx in (-1, 1):
        for k in range(5):
            t = -0.18 + k * 0.1
            p = at(0.04 + t, height / 2 + 0.004)
            rig.cylinder(f"rivet{sx}{k}", (sx * (width / 2 - 0.03), p[1], p[2]),
                         (sx * (width / 2 - 0.03), p[1] + up[1] * 0.012, p[2] + up[2] * 0.012), 0.012, m["rivet"], verts=8)
    rig.box("handle", at(0.04 - length / 2 - 0.02, 0.02), (0.14, 0.02, 0.03), m["steel"], bevel=0, rotation=rot)
    rig.cylinder("cable", at(0.04 - length / 2), (0, -0.2, base + 0.06), 0.015, m["dark"], verts=8)


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

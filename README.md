# Military Wagons

Factorio 2.1 mod (Space Age optional). Armoured train wagons with turrets on their roof. The turrets work like
their vanilla counterparts, also while the train is moving, and reload from the wagon itself.

| Wagon | Base | Turrets | Ammo |
|---|---|---|---|
| Machine gun wagon | cargo wagon, 10 slots | 3 machine guns | bullet magazines, 10 per gun |
| Flamethrower wagon | fluid wagon, 25,000 units | 2 flamethrowers, all sides, min. range 2 | crude, heavy or light oil |
| Rocket wagon | cargo wagon, 10 slots | 2 rocket launchers, range 36, min. range 8 | rockets, 10 per launcher |

- Each wagon can be switched off in the startup settings. A switched-off wagon has no entity, recipe or
  technology. Wagons of that kind already on the map are removed when the save is loaded.
- The turrets turn and unfold faster than vanilla turrets, so they can hit targets while passing.
- Damage and shooting speed research apply as usual. Wagon quality carries over to the turrets.
- Works on elevated rails. The flamethrower wagon is immune to fire, the rocket launchers need no heating on Aquilo.
- With Space Age the rocket launchers are rocket turrets; without it they have the rocket launcher's stats.
- Unlocked by "Machine gun wagon" (railway, gun turret), "Flamethrower wagon" (fluid wagon, flamethrower) and
  "Rocket wagon" (railway and rocket turret, or rocketry without Space Age).

## Moving from the single wagon mods

Until version 0.2.1 every wagon was a mod of its own (gun-turret-wagon, flamethrower-turret-wagon,
rocket-turret-wagon). Their version 0.3.0 is an empty bridge that depends on this mod. The prototype names
are the same, so wagons in existing saves stay where they are. Ammo that sat in the turrets at that moment is
lost once; the turrets reload from the wagon. While an old version (below 0.3.0) of a single wagon mod is still
active, that mod keeps bringing its wagon and this mod leaves it out.

## How it works

Factorio has no turrets on rolling stock. Each wagon gets hidden turrets (not selectable, not attackable,
no collision). While the wagon moves, the script teleports them along with it every tick; standing wagons cost
nothing per tick. Every 30 ticks the turrets are topped up from the wagon. Mining the wagon returns the loaded ammo.

## Tests

    python tests/run.py                 # headless, with Space Age: each wagon alone, then all wagons on
    python tests/run.py --no-space-age
    python tests/ingame.py              # opens a game window per wagon: build, mine, ghost revive, blueprint
    python tests/shots.py               # opens a game window briefly, writes previews/shots/<wagon>/*.png

## Graphics

    tools/blender/render_all.sh [out_dir] [mg|flame|rocket ...]          # Blender renders, about an hour per wagon
    python tools/blender/build_sprites.py [out_dir] [mg|flame|rocket ...] # sprite sheets, icons, thumbnail

## Release

    python tools/package.py             # dist/<name>_<version>.zip
    python tools/publish.py publish     # first release (needs FACTORIO_API_KEY)
    python tools/publish.py upload      # later releases

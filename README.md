# Military Wagons

Factorio 2.1 mod (Space Age optional). Armoured train wagons with turrets on their roof. The turrets work like
their vanilla counterparts, also while the train is moving, and reload from the wagon itself.

| Wagon | Base | Turrets | Ammo |
|---|---|---|---|
| Machine gun wagon | cargo wagon, 10 slots | 3 machine guns | bullet magazines, 10 per gun |
| Flamethrower wagon | fluid wagon, 25,000 units | 2 flamethrowers, all sides, min. range 2 | crude, heavy or light oil |
| Rocket wagon | cargo wagon, 10 slots | 2 rocket launchers, range 36, min. range 8 | rockets, 10 per launcher |
| Twin cannon wagon | cargo wagon, 10 slots | 2 tank cannons, all round | cannon shells |
| Howitzer wagon | cargo wagon, 10 slots | 1 long gun, range 36, min. range 12, half rate of fire | cannon shells |
| Mine launcher wagon | artillery wagon | six launcher baskets (artillery turrets), range 120, min. range 16, one shot each per 10 s, aimed with its remote | wagon mines (5 land mines + explosives, scattered on impact) |

- Each wagon can be switched off in the startup settings. A switched-off wagon has no entity, recipe or
  technology. Wagons of that kind already on the map are removed when the save is loaded.
- The turrets turn and unfold faster than vanilla turrets, so they can hit targets while passing.
- Damage and shooting speed research apply as usual. Wagon quality carries over to the turrets.
- Works on elevated rails. The flamethrower wagon is immune to fire, the rocket launchers need no heating on Aquilo.
- With Space Age the rocket launchers are rocket turrets; without it they have the rocket launcher's stats.
- Unlocked by "Machine gun wagon" (railway, gun turret), "Flamethrower wagon" (fluid wagon, flamethrower) and
  "Rocket wagon" (railway and rocket turret, or rocketry without Space Age).

## Armour

All military wagons have a 6x8 equipment grid and 2000 health, like a tank. The grid takes everything a tank's
grid takes, plus armour plates (2x2, like an energy shield), which fit into military wagons only. Plates are made
from armour steel (4 steel, 1 copper, 2 carbon, 20 water in a chemical plant; without Space Age carbon comes from coal).

| Plate | Protection per plate | Space Age |
|---|---|---|
| Composite | physical 0.5 flat, 4 % | |
| Reactive | explosion 1.5 flat, 5 % | |
| Acid | acid 0.5 flat, 5 % | |
| Fire | fire 1 flat, 5 % | |
| Tungsten carbide | physical 1 / 6 %, acid 2 %, fire 3 % | yes |
| Tungsten reactive | explosion 3 / 7 %, physical 2 % | yes |
| Tungsten carbide acid | acid 1 / 7 %, fire 3 % | yes |

A grid full of composite plates (12) takes 39 % off physical damage, about as much as a reactor and eight
MK2 shields add, but without power and only against its damage type. Better quality: +30 % per level.
Flat values add up, percentages stack multiplicatively, capped at 80 %. Equipment cannot give a vehicle
resistances, so the script heals the plates' share back after every hit, lethal hits included.

## Wagon panel

Next to the wagon window: the armour in effect per damage type, target priorities for the wagon's turrets,
and on the rocket wagon the minimum range (8 to 24, range circles shown while the window is open).

## Cannon shells

The cannon wagons fire wagon-only copies of every tank shell. The copies pass the own force's entities, so the
shells fly through the own train, and keep flying along their line up to 40 tiles. Shells in the wagon's cargo
are the normal ones; mining the wagon gives them back as normal shells.

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

    tools/blender/render_all.sh [out_dir] [mg|flame|rocket|twin|howitzer|mine|howitzer-turret ...]  # Blender renders
    python tools/blender/build_sprites.py [out_dir] [variant ...]   # sprite sheets, icons, thumbnail (howitzer-turret too)
    blender -b --factory-startup -P tools/blender/plates.py -- <out_dir>   # armour plate renders
    python tools/blender/build_icons.py <out_dir>                         # plate icons and equipment sprites

## Release

    python tools/package.py             # dist/<name>_<version>.zip
    python tools/publish.py publish     # first release (needs FACTORIO_API_KEY)
    python tools/publish.py upload      # later releases

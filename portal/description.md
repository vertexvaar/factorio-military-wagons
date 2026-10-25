Armoured train wagons with turrets on their roof: machine guns, flamethrowers, rocket launchers, twin cannons, a howitzer and a mine launcher. They fire like turrets, also while the train is moving, and reload from the wagon itself. Armour plates in the wagons' equipment grid protect them.

![Machine gun wagon in action](https://raw.githubusercontent.com/vertexvaar/factorio-military-wagons/main/previews/portal/1-mg-fighting.png)

## The wagons

- **Machine gun wagon**: a cargo wagon with three machine guns. Put bullet magazines into its 10 cargo slots; each gun keeps 10 magazines loaded.
- **Flamethrower wagon**: a fluid wagon with two flamethrowers that cover all sides. Fill it with crude, heavy or light oil (25,000 units). They also reach enemies right next to the train, and the wagon itself is fireproof. Other wagons near the flames are not.
- **Rocket wagon**: a cargo wagon with two rocket launchers, range 36. With Space Age they are rocket turrets, without it they have the rocket launcher's stats. Minimum range 8, so the explosions stay clear of the train. Pair it with a machine gun wagon for close defence.

- **Twin cannon wagon**: two tank cannons, each turning all the way round. Load cannon shells into its 10 cargo slots.
- **Howitzer wagon**: one long gun with range 36 and minimum range 12, at half the tank's rate of fire. It turns slower than a tank turret.
- **Mine launcher wagon**: lays land mines up to 120 tiles away (minimum 16). Aim it with the mine launcher remote, like artillery. Ammo: 1 land mine and 1 explosives.

The cannon wagons fire their own copies of the tank shells. Those fly through your own train and on up to 40 tiles, so the wagons can shoot over the rest of the train.

## Armour

Every military wagon has a 16x16 equipment grid. It takes everything a tank's grid takes, plus armour plates. The plates fit into military wagons only.

- Armour steel: 4 steel, 1 copper, 2 carbon and 20 water in a chemical plant. Without Space Age, carbon is made from coal.
- Composite, reactive, acid and fire plates protect against physical, explosion, acid and fire damage.
- With Space Age, three tungsten plates protect more and against several damage types at once.
- The protection of all plates adds up to at most 80 %.

## Wagon panel

Open a wagon and a panel next to it shows the armour in effect per damage type. There you also set target priorities for the turrets, and on the rocket wagon the minimum range (8 to 24, with range circles).

## Settings

Each wagon can be switched off in the startup settings. A switched-off wagon does not exist in the game at all: no entity, no recipe, no technology. Wagons of that kind that are already on the map are removed when the save is loaded.

## Details

- The turrets turn and unfold faster than vanilla turrets, so they also hit targets while the train passes by.
- Damage and shooting speed research apply as usual. The wagon's quality carries over to its turrets.
- Works on elevated rails. The rocket launchers need no heating on Aquilo.
- Mining a wagon gives back the ammo loaded in its turrets.

## Unlocking

- **Machine gun wagon** after Railway and Gun turret: a cargo wagon, three gun turrets and steel.
- **Flamethrower wagon** after Fluid wagon and Flamethrower: a fluid wagon, two flamethrower turrets and steel.
- **Rocket wagon** after Railway and Rocket turret (Space Age) or Rocketry (without Space Age).
- **Twin cannon wagon** and **Howitzer wagon** after Railway and Tank.
- **Mine launcher wagon** after Railway, Land mines and Explosives.
- **Armour steel** after Steel processing and Military 2, then one research per plate type.

## Coming from the single wagon mods

Machine Gun Wagon, Flamethrower Wagon and Rocket Wagon were separate mods up to version 0.2.1. Their version 0.3.0 only depends on this mod. Your wagons keep their names, so they stay in your saves. Ammo loaded in their turrets at that moment is lost once; the turrets reload from the wagon.

## Performance

Standing wagons cost nothing per tick. Only moving wagons move their turrets along, and reloading runs twice a second. Armour only runs when a wagon is hit.

Languages: English, German. Source and issues: [GitHub](https://github.com/vertexvaar/factorio-military-wagons).

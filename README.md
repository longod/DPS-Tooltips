# DPS Tooltips

DPS Tooltips is a mod that calculates weapon DPS and displays it in weapon tooltips.

If you're unsure whether a dagger with lots of enchantments is better for your player character or another two-handed sword with lots of enchantments, this mod can help you make an informed decision. However, it's worth noting that the internal specifications of Morrowind's complex damage resolving may differ from actual damage. If you're unsure, it's always a good idea to seek advice from someone who knows more about it.

## Requirements

To use DPS Tooltips, you'll need the following:

- Morrowind
- The latest build of Morrowind Script Extender Nightly (MWSE 2.1)

## Installation

To install DPS Tooltips, copy the files to the following directory:

`./Data Files/MWSE/mods/longod/DPSTooltips`

## Compatibility

DPS Tooltips is compatible with the following mods:

- [Morrowind Code Patch](https://www.nexusmods.com/morrowind/mods/19510) (including Game Formula Restoration)
- [Cast on Strike Bows](https://www.nexusmods.com/morrowind/mods/45913)
- [Thrown Projectiles Revamped](https://www.nexusmods.com/morrowind/mods/49609)
- [Poison Crafting](https://www.nexusmods.com/morrowind/mods/45729)
- [MWSE Compare Tooltips](https://www.nexusmods.com/morrowind/mods/51087)
- Other item tooltip mods, including:
  - [UI Expansion](https://www.nexusmods.com/morrowind/mods/46071)
  - [Accurate Tooltip Stats](https://www.nexusmods.com/morrowind/mods/51354)
  - [Tooltips Complete](https://www.nexusmods.com/morrowind/mods/46842)
  - [Tooltip](https://www.nexusmods.com/morrowind/mods/45969)

Please note that although some mods are not explicitly compatible, they work fine with DPS Tooltips.

## TODO

The following features are currently on the to-do list for DPS Tooltips:

- Attribute effects
- Skill effects
- Chance to Hit, Evasion and Blocking
- Difficulty
- Modded magic effects
- Other [Morrowind Code Patch](https://www.nexusmods.com/morrowind/mods/19510) features

## By Design, Currently

The following limitations are by design in the current version of DPS Tooltips:

- Damage or Healing Over Time effects only use the first applied effect, as this mod does not calculate total damage numerically.
- Some effects that take effect after hit are treated as if they hit and the effect is still in effect.
- Some effects with temporary increases and decreases, such as Fortify and Drain, do not contribute to continuous, but are included as is.

## Not Supported

DPS Tooltips does not support the following:

- On Use Enchantment 
- Resist or Weakness to Normal Weapons
- OpenMW (Sorry!)

## Known Issues

The following issues are currently known in DPS Tooltips:

- Minimum swing speed is probably not correct.
- Ranged Weapons attack speed is probably not correct.
- Some effects that need to be capped by current stats, such as Restore, are not.

## Thanks

DPS Tooltips was made possible thanks to the following:

- [MWSE](https://github.com/MWSE/MWSE)
- [Accurate Tooltip Stats](https://www.nexusmods.com/morrowind/mods/51354)

To learn more about DPS Tooltips or to contribute to the project, visit the [project on GitHub](https://github.com/longod/DPSTooltips)


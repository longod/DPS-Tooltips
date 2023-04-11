# DPS Tooltips

This mod analytically calculates weapon DPS and displays it in weapon tooltips.

I wonder if a dagger with lots of enchantments is better for this player character or another two-handed sword with lots of enchantments.

But I am not familiar with the internal specifications of Morrowind's complex damage resolving.
It may be different from the actual damage.
Anyone who knows more about this would be grateful for advice.

## Requirements:
- Morrowind
- The latest build of Morrowind Script Extender Nightly (MWSE 2.1)

## Installation:
./Data Files/MWSE/mods/longod/DPSTooltips

## Compatibility:
- [Morrowind Code Patch](https://www.nexusmods.com/morrowind/mods/19510) Features
  - Game Formula Restoration
- [Cast on Strike Bows](https://www.nexusmods.com/morrowind/mods/45913)
- [Thrown Projectiles Revamped](https://www.nexusmods.com/morrowind/mods/49609)
- [MWSE Compare Tooltips](https://www.nexusmods.com/morrowind/mods/51087)
- Other item tooltip mods
  - It's not explicitly compatible, but it works fine.
  - [UI Expansion](https://www.nexusmods.com/morrowind/mods/46071)
  - [Accurate Tooltip Stats](https://www.nexusmods.com/morrowind/mods/51354)
  - [Tooltips Complete](https://www.nexusmods.com/morrowind/mods/46842)
  - [Tooltip](https://www.nexusmods.com/morrowind/mods/45969)

## TODO:
- Attribute effects
- Skill effects
- Resist or Weakness to Normal Weapons
- Chance to Hit, Evasion and Blocking
- Modded Magic Effects
- [Morrowind Code Patch](https://www.nexusmods.com/morrowind/mods/19510) Features
  - Blind Fix
- [Poison Crafting](https://www.nexusmods.com/morrowind/mods/45729)

## By Design, Currently:
- Damage or Healing Over Time effects only use the first applied effect. Because this mod does not calculate total damage numerically.
- Some effects that take effect after hit are treated as if they hit and the effect is still in effect.
- Some effects with temporary increases and decreases, such as Fortify and Drain, do not contribute to continuous, but are included as is.

## Not Supported:
- On Use Enchantment 
- OpenMW (Sorry!)

## Known Issues:
- Minimum swing speed probably not correct.
- Ranged Weapons attack speed probably not correct.
- Some effect that need to cap by current stats, such as Restore, but are not.

## Thanks:
- [MWSE](https://github.com/MWSE/MWSE)
- [Accurate Tooltip Stats](https://www.nexusmods.com/morrowind/mods/51354)


https://github.com/longod/DPSTooltips


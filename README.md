# DPS Tooltips

This mod analytically calculates weapon DPS (damage per second) including enchantment effects and displays it in weapon tooltips.

I wonder if a fast dagger with lots of enchantments is better for this player character or another slow two-handed sword with lots of enchantments. Now we can know which weapons are actually stronger for your player character.

DPS seems impossible to perfectly match the actual damage. Because of that will be different depending on attributes and skills of target. Therefore it is just a guide.

And I am not familiar with the internal specifications of Morrowind's complex damage resolving. Anyone who knows more about this would be grateful for advice.

## Requirements
- Morrowind
- The latest nightly build of Morrowind Script Extender 2.1

## Installation
./Data Files/MWSE/mods/longod/DPSTooltips

## Compatibility
- [Morrowind Code Patch](https://www.nexusmods.com/morrowind/mods/19510) features
  - Game Formula Restoration
  - Restore Drain Attributes Fix
- [Cast on Strike Bows](https://www.nexusmods.com/morrowind/mods/45913)
- [Thrown Projectiles Revamped](https://www.nexusmods.com/morrowind/mods/49609)
- [Poison Crafting](https://www.nexusmods.com/morrowind/mods/45729)
- [MWSE Compare Tooltips](https://www.nexusmods.com/morrowind/mods/51087)
- Other item tooltip mods
  - It's not explicitly compatible, but it works fine.
  - [UI Expansion](https://www.nexusmods.com/morrowind/mods/46071)
  - [Accurate Tooltip Stats](https://www.nexusmods.com/morrowind/mods/51354)
  - [Tooltips Complete](https://www.nexusmods.com/morrowind/mods/46842)
  - [Tooltip](https://www.nexusmods.com/morrowind/mods/45969)

## TODO
- Chance to Hit, Evasion and Blocking
  - Skill effects

## By Design
- Damage or Healing Over Time effects only use the first applied effect. Because this mod does not calculate total damage numerically.
- Some effects that take effect after hit are treated as if they hit and the effect is still in effect.
- Some effects with temporary increases and decreases, such as Fortify and Drain, do not contribute to continuous, but are included as is.

## Known Issues
- Weapon speed probably not equal actual animation frame.
  - Minimum weapon swing speed probably more quickly.
  - Ranged Weapons attack speed probably not correct.

## Not Supported
- On Use Enchantment
- Resist or Weakness to Normal Weapons
- Effects added by mods
- OpenMW (Sorry!)

## Thanks
- [Accurate Tooltip Stats](https://www.nexusmods.com/morrowind/mods/51354)
- [MWSE](https://github.com/MWSE/MWSE)

[GitHub](https://github.com/longod/DPSTooltips)


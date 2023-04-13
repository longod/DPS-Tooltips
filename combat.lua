-- in-game combat formula
-- https://en.uesp.net/wiki/Morrowind:Combat
-- https://wiki.openmw.org/index.php?title=Research:Common_Terms
-- https://wiki.openmw.org/index.php?title=Research:Combat
-- https://wiki.openmw.org/index.php?title=Research:Magic
---@class CombatFormula
local this = {}

-- TODO test

---@param m number
---@return number
function this.InverseNormalizeMagnitude(m)
    return math.max(100.0 - m, 0) / 100.0
end

---@param damage number
---@param speed number
---@return number
function this.CalculateDPS(damage, speed)
    return damage * speed
end

---@param weaponDamage number
---@param strengthModifier number
---@param conditionModifier number
---@param criticalHitModifier number
---@return number
function this.CalculateAcculateWeaponDamage(weaponDamage, strengthModifier, conditionModifier, criticalHitModifier)
    return (weaponDamage * strengthModifier * conditionModifier * criticalHitModifier)
end

---@param hitRate number
---@param evation number
---@return number
function this.CalculateChanceToHit(hitRate, evation)
    return math.clamp(hitRate - evation, 0.0, 1.0)
end

---@param armorRating number
---@param damage number
---@param fCombatArmorMinMult number fCombatArmorMinMult
---@return number
function this.CalculateDamageReductionFromArmorRating(damage, armorRating, fCombatArmorMinMult)
    return math.max(damage * math.max(damage / (damage + armorRating), fCombatArmorMinMult), 1.0)
end

---@param currentFatigue number
---@param baseFatigue number
---@param fFatigueBase number fFatigueBase 
---@param fFatigueMult number fFatigueMult
---@return number
function this.CalculateFatigueTerm(currentFatigue, baseFatigue, fFatigueBase, fFatigueMult)
    return math.max(fFatigueBase - fFatigueMult * math.max(1.0 - currentFatigue / baseFatigue, 0.0), 0.0)
end

---@param weaponSkill number
---@param agility number
---@param luck number
---@param fatigueTerm number
---@param fortifyAttack number
---@param blind number
---@return number
function this.CalculateHitRate(weaponSkill, agility, luck, fatigueTerm, fortifyAttack, blind)
    return (weaponSkill + (agility * 0.2) + (luck * 0.1)) * fatigueTerm + fortifyAttack + blind
end

---@param agility number
---@param luck number
---@param fatigueTerm number
---@param sanctuary number
---@return number
function this.CalculateEvasion(agility, luck, fatigueTerm, sanctuary)
    return ((agility * 0.2) + (luck * 0.1)) * fatigueTerm + math.min(sanctuary, 100)
end

return this
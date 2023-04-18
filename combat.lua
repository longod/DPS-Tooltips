--- @module '"longod.DPSTooltips.combat"'

--- In-game combat formula.
---
--- References:
--- - [Morrowind Combat](https://en.uesp.net/wiki/Morrowind:Combat)
--- - [Common Terms Research](https://wiki.openmw.org/Research:Common_Terms)
--- - [Combat Research](https://wiki.openmw.org/Research:Combat)
--- - [Magic Research](https://wiki.openmw.org/Research:Magic)
--- @class CombatFormula
local this = {}

--- Determines if two numbers are nearly equal, up to a given epsilon value.
--- @param a number The first number to compare.
--- @param b number The second number to compare.
--- @param epsilon number? An optional epsilon value that represents the maximum relative difference between the two numbers. Defaults to 0.00001 if not specified.
--- @return boolean @True if the difference between the two numbers is within the epsilon value, false otherwise.
function this.NearlyEqual(a, b, epsilon)
    local minNormal = 1.175494351e-38
    local maxValue = 3.402823466e+38
    local e = epsilon or 0.00001
    local absA = math.abs(a)
    local absB = math.abs(b)
    local diff = math.abs(a - b)
    if a == b then
        return true
    elseif a == 0 or b == 0 or (absA + absB < minNormal) then
        return diff < (e * minNormal)
    else
        return diff / math.min(absA + absB, maxValue) < e
    end
end

--- Normalizes a given value to a range between 0 and 1.
--- @param m number The value to normalize.
--- @return number @The normalized value, between 0 and 1.
function this.Normalize(m)
    return math.max(m, 0) / 100.0
end

--- Inverse normalizes a given value to a range between 0 and 1, where 0 corresponds to 100 and 1 corresponds to 0.
--- @param m number The value to inverse normalize.
--- @return number @The inverse normalized value, between 0 and 1.
function this.InverseNormalize(m)
    return math.max(100.0 - m, 0) / 100.0
end

--- Calculates the damage per second (DPS) of a weapon or attack.
--- @param damage number The amount of damage dealt per hit.
--- @param speed number The speed at which the weapon or attack is performed, in hits per second.
--- @return number @The calculated DPS, which is the product of the damage and speed values.
function this.CalculateDPS(damage, speed)
    return damage * speed
end

--- Calculates the actual damage of a weapon attack based on various modifiers.
--- @param weaponDamage number The base damage of the weapon.
--- @param strengthModifier number The strength modifier of the attacker.
--- @param conditionModifier number The condition modifier of the weapon.
--- @param criticalHitModifier number The critical hit modifier of the attack.
--- @return number @The calculated actual damage of the weapon attack.
function this.CalculateAcculateWeaponDamage(weaponDamage, strengthModifier, conditionModifier, criticalHitModifier)
    return (weaponDamage * strengthModifier * conditionModifier * criticalHitModifier)
end

--- Calculates the damage reduction from a given armor rating and damage value.
--- @param damage number The amount of damage to be reduced.
--- @param armorRating number The armor rating that provides protection against the damage.
--- @param fCombatArmorMinMult number The minimum damage reduction multiplier, expressed as a fraction of the damage value. Defaults to 1.0 if not specified.
--- @return number @The calculated damage reduction from the armor rating.
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

--- Calculates the hit rate of an attack based on various factors.
--- @param weaponSkill number The weapon skill of the attacker.
--- @param agility number The agility of the attacker.
--- @param luck number The luck of the attacker.
--- @param fatigueTerm number The fatigue term of the attacker, which affects their stamina and accuracy.
--- @param fortifyAttack number The fortify attack modifier of the attack.
--- @param blind number The blind modifier of the attack.
--- @return number @The calculated hit rate of the attack, normalized to a range between 0 and 1.
function this.CalculateHitRate(weaponSkill, agility, luck, fatigueTerm, fortifyAttack, blind)
    return this.Normalize((weaponSkill + (agility * 0.2) + (luck * 0.1)) * fatigueTerm + fortifyAttack - blind)
end

--- Calculates the evasion rate of a character based on various factors.
--- @param agility number The agility of the character.
--- @param luck number The luck of the character.
--- @param fatigueTerm number The fatigue term of the character, which affects their stamina and accuracy.
--- @param sanctuary number The sanctuary modifier of the character, which provides a chance to avoid damage.
--- @return number @The calculated evasion rate of the character, normalized to a range between 0 and 1.
function this.CalculateEvasion(agility, luck, fatigueTerm, sanctuary)
    return this.Normalize(((agility * 0.2) + (luck * 0.1)) * fatigueTerm + math.min(sanctuary, 100))
end

--- Calculates the chance to hit a target based on the attacker's hit rate and the target's evasion rate.
--- @param hitRate number The hit rate of the attacker.
--- @param evasion number The evasion rate of the target.
--- @return number @The calculated chance to hit the target, clamped to a range between 0 and 1.
function this.CalculateChanceToHit(hitRate, evasion)
    return math.clamp(hitRate - evasion, 0.0, 1.0)
end

--- Runs a series of unit tests for the various combat-related functions.
--- @param self table The module table.
--- @param unitwind table The unit testing framework to use.
function this.RunTest(self, unitwind)
    unitwind:start("DPSTooltips.combat")
    unitwind:test("Normalize", function()
        unitwind:approxExpect(self.Normalize(100)).toBe(1.0) -- edge
        unitwind:approxExpect(self.Normalize(0)).toBe(0.0)   -- edge
        unitwind:approxExpect(self.Normalize(110)).toBe(1.1) -- over
        unitwind:approxExpect(self.Normalize(-50)).toBe(0.0) -- capped
    end)
    unitwind:test("InverseNormalize", function()
        unitwind:approxExpect(self.InverseNormalize(100)).toBe(0.0) -- edge
        unitwind:approxExpect(self.InverseNormalize(0)).toBe(1.0)   -- edge
        unitwind:approxExpect(self.InverseNormalize(110)).toBe(0.0) -- capped
        unitwind:approxExpect(self.InverseNormalize(-50)).toBe(1.5) -- over
    end)
    unitwind:test("CalculateDPS", function()
        unitwind:approxExpect(self.CalculateDPS(100, 2)).toBe(200) -- normal
        unitwind:approxExpect(self.CalculateDPS(100, 0)).toBe(0)   -- zero
    end)
    unitwind:test("CalculateAcculateWeaponDamage", function()
        unitwind:approxExpect(self.CalculateAcculateWeaponDamage(100, 2, 0.75, 1)).toBe(150) -- normal
        unitwind:approxExpect(self.CalculateAcculateWeaponDamage(100, 0, 0.75, 1)).toBe(0)   -- zero
    end)
    unitwind:test("CalculateDamageReductionFromArmorRating", function()
        unitwind:approxExpect(self.CalculateDamageReductionFromArmorRating(90, 10, 0.25)).toBe(81) -- normal
        unitwind:approxExpect(self.CalculateDamageReductionFromArmorRating(5, 10, 0.5)).toBe(2.5)  -- min mult
        unitwind:approxExpect(self.CalculateDamageReductionFromArmorRating(2, 20, 0.25)).toBe(1)   -- less than 1.0
    end)
    unitwind:test("CalculateFatigueTerm", function()
        unitwind:approxExpect(self.CalculateFatigueTerm(100, 100, 0.5, 0.5)).toBe(0.5)
    end)
    unitwind:test("CalculateHitRate", function()
        unitwind:approxExpect(self.CalculateHitRate(50, 50, 50, 0.5, 20, 10)).toBe(0.425)  -- fixed blind
        unitwind:approxExpect(self.CalculateHitRate(50, 50, 50, 0.5, 20, -10)).toBe(0.625) -- unfixed blind
        unitwind:approxExpect(self.CalculateHitRate(100, 100, 100, 1.0, 0, 0)).toBe(1.3) -- over
        unitwind:approxExpect(self.CalculateHitRate(0, 0, 0, 1.0, 0, 100)).toBe(0.0) -- capped
    end)
    unitwind:test("CalculateEvasion", function()
        unitwind:approxExpect(self.CalculateEvasion(50, 50, 0.5, 10)).toBe(0.175)   -- noraml
        unitwind:approxExpect(self.CalculateEvasion(50, 50, 0.5, 110)).toBe(1.075) -- capped
    end)
    unitwind:test("CalculateChanceToHit", function()
        unitwind:approxExpect(self.CalculateChanceToHit(0.7, 0.3)).toBe(0.4) -- normal
        unitwind:approxExpect(self.CalculateChanceToHit(2.0, 0.5)).toBe(1.0) -- capped
        unitwind:approxExpect(self.CalculateChanceToHit(0.2, 0.7)).toBe(0.0) -- capped
    end)
    unitwind:finish()
end

return this

---@class DPS
---@field config Config
---@field fFatigueBase number
---@field fFatigueMult number
---@field fCombatInvisoMult number
---@field fSwingBlockBase number
---@field fSwingBlockMult number
---@field fBlockStillBonus number
---@field iBlockMinChance number
---@field iBlockMaxChance number
---@field fCombatArmorMinMult number
---@field fDifficultyMult number
---@field fDamageStrengthBase number
---@field fDamageStrengthMult number
---@field restoreDrainAttributesFix boolean
---@field blindFix integer
---@field rangedWeaponCanCastOnSTrike boolean
---@field throwWeaponAlreadyModified boolean
---@field poisonCrafting boolean
local DPS = {}

---@param cfg Config?
---@return DPS
function DPS.new(cfg)
    local dps = {
        config = cfg and cfg or require("longod.DPSTooltips.config").Load()
    }
    setmetatable(dps, { __index = DPS })
    return dps
end

local logger = require("longod.DPSTooltips.logger")
local combat = require("longod.DPSTooltips.combat")

---@class Modifier
---@field damages {[tes3.effect] : number}
---@field positives {[tes3.effect] : number}
---@field negatives {[tes3.effect] : number}
---@field damageAttributes {[tes3.attribute] : number}
---@field damageSkills {[tes3.skill] : number}
---@field drainAttributes {[tes3.attribute] : number}
---@field drainSkills {[tes3.skill] : number}
---@field fortifyAttributes {[tes3.attribute] : number}
---@field fortifySkills {[tes3.skill] : number}
---@field restoreAttributes {[tes3.attribute] : number}
---@field restoreSkills {[tes3.skill] : number}
---@field resists {[tes3.effect] : number} resolved resistance

---@class ScratchData
---@field attacker Modifier
---@field target Modifier
---@field current Modifier

---@class Params
---@field data table
---@field key tes3.effect
---@field value number
---@field speed number
---@field isSelf boolean
---@field attacker boolean
---@field target boolean
---@field attribute tes3.attribute
---@field skill tes3.skill
---@field weaponSkillId tes3.skill

---@return ScratchData
local function CreateScratchData()
    ---@type ScratchData
    local data = {
        attacker = {
            positives = {},
            negatives = {},
            damageAttributes = {},
            damageSkills = {},
            drainAttributes = {},
            drainSkills = {},
            fortifyAttributes = {},
            fortifySkills = {},
            restoreAttributes = {},
            restoreSkills = {},
        },
        target = {
            damages = {},
            positives = {},
            negatives = {},
            damageAttributes = {},
            damageSkills = {},
            drainAttributes = {},
            drainSkills = {},
            fortifyAttributes = {},
            fortifySkills = {},
            restoreAttributes = {},
            restoreSkills = {},
        },
    }
    return data
end

---@class FilterFlag
---@field attacker boolean
---@field target boolean

---@class AttributeFilter
---@field [tes3.attribute] FilterFlag
local attributeFilter = {
    [tes3.attribute.strength] = { attacker = true, target = false }, -- damage
    [tes3.attribute.intelligence] = { attacker = false, target = false },
    [tes3.attribute.willpower] = { attacker = true, target = true }, -- fatigue
    [tes3.attribute.agility] = { attacker = true, target = true },   -- evade, hit, fatigue
    [tes3.attribute.speed] = { attacker = false, target = false },   -- if weapon swing mod
    [tes3.attribute.endurance] = { attacker = true, target = true }, -- fatigue or if realtime health calculate mod
    [tes3.attribute.personality] = { attacker = false, target = false },
    [tes3.attribute.luck] = { attacker = true, target = true },      -- evade, hit
}

---@class SkillFilter
---@field [tes3.skill] FilterFlag
local skillFilter = {
    [tes3.skill.block] = { attacker =false, target = true  },
    [tes3.skill.armorer] = { attacker = false, target = false },
    [tes3.skill.mediumArmor] = { attacker =false, target = true },
    [tes3.skill.heavyArmor] = { attacker =false, target = true },
    [tes3.skill.bluntWeapon] = { attacker = true, target = false },
    [tes3.skill.longBlade] = { attacker = true, target = false },
    [tes3.skill.axe] = { attacker = true, target = false },
    [tes3.skill.spear] = { attacker = true, target = false },
    [tes3.skill.athletics] = { attacker = false, target = false },
    [tes3.skill.enchant] = { attacker = false, target = false },
    [tes3.skill.destruction] = { attacker = false, target = false },
    [tes3.skill.alteration] = { attacker = false, target = false },
    [tes3.skill.illusion] = { attacker = false, target = false },
    [tes3.skill.conjuration] = { attacker = false, target = false },
    [tes3.skill.mysticism] = { attacker = false, target = false },
    [tes3.skill.restoration] = { attacker = false, target = false },
    [tes3.skill.alchemy] = { attacker = false, target = false },
    [tes3.skill.unarmored] = { attacker = false, target = false },
    [tes3.skill.security] = { attacker = false, target = false },
    [tes3.skill.sneak] = { attacker = false, target = false },
    [tes3.skill.acrobatics] = { attacker = false, target = false },
    [tes3.skill.lightArmor] = { attacker =false, target = true },
    [tes3.skill.shortBlade] = { attacker = true, target = false },
    [tes3.skill.marksman] = { attacker = true, target = false },
    [tes3.skill.mercantile] = { attacker = false, target = false },
    [tes3.skill.speechcraft] = { attacker = false, target = false },
    [tes3.skill.handToHand] = { attacker = false, target = false },
}

---@param params Params
---@return boolean
local function IsAffectedAttribute(params)
    local f = attributeFilter[params.attribute]
    if f then
        -- lua: a and b or c idiom is useless when b and c are boolean, it return b or c.
        if params.isSelf then
            return params.attacker and f.attacker
        else
            return params.target and f.target
        end
    end
    return false
end

---@param params Params
---@return boolean
local function IsAffectedSkill(params)
    local f = skillFilter[params.skill]
    if f then
        -- lua: a and b or c idiom is useless when b and c are boolean, it return b or c.
        if params.isSelf then
            return params.skill == params.weaponSkillId and params.attacker and f.attacker
        else
            return params.target and f.target
        end
    end
    return false
end

---@param tbl { [number]: number }
---@param key number
---@param initial number
---@return number
local function GetValue(tbl, key, initial)
    if not tbl[key] then -- no allocate if it does not exists
        return initial
    end
    return tbl[key]
end

---@param tbl { [number]: number }
---@param key number
---@param value number
---@return number
local function AddValue(tbl, key, value)
    tbl[key] = GetValue(tbl, key, 0) + value
    return tbl[key]
end

---@param tbl { [number]: number }
---@param key number
---@param value number
---@return number
local function MulValue(tbl, key, value)
    tbl[key] = GetValue(tbl, key, 1) * value
    return tbl[key]
end

---@param m number
---@return number
local function InverseNormalizeMagnitude(m)
    return math.max(100.0 - m, 0) / 100.0
end

---@param damage number
---@param speed number
---@return number
local function CalculateDPS(damage, speed)
    return damage * speed
end

---@param params Params
---@return boolean
local function DamageHealth(params)
    if params.isSelf then
    else
        if params.target then
            AddValue(params.data.target.damages, params.key, CalculateDPS(params.value, params.speed))
            return true
        end
    end
    return false
end

---@param params Params
---@return boolean
local function DrainHealth(params)
    if params.isSelf then
    else
        if params.target then
            AddValue(params.data.target.damages, params.key, params.value)
            return true
        end
    end
    return false
end

---@param params Params
---@return boolean
local function CurePoison(params)
    if params.isSelf then
    else
        if params.target then
            params.data.target.positives[params.key] = 1
            return true
        end
    end
    return false
end

---@param params Params
---@return boolean
local function PositiveModifier(params)
    if params.isSelf then
        if params.attacker then
            AddValue(params.data.attacker.positives, params.key, params.value)
            return true
        end
    else
        if params.target then
            AddValue(params.data.target.positives, params.key, params.value)
            return true
        end
    end
    return false
end

---@param params Params
---@return boolean
local function PositiveModifierWithSpeed(params)
    if params.isSelf then
        if params.attacker then
            AddValue(params.data.attacker.positives, params.key, CalculateDPS(params.value, params.speed))
            return true
        end
    else
        if params.target then
            AddValue(params.data.target.positives, params.key, CalculateDPS(params.value, params.speed))
            return true
        end
    end
    return false
end

---@param params Params
---@return boolean
local function NegativeModifier(params)
    if params.isSelf then
        if params.attacker then
            AddValue(params.data.attacker.negatives, params.key, params.value)
            return true
        end
    else
        if params.target then
            AddValue(params.data.target.negatives, params.key, params.value)
            return true
        end
    end
    return false
end

-- only positive
---@param params Params
---@return boolean
local function MultModifier(params)
    if params.isSelf then
    else
        if params.target then
            MulValue(params.data.target.positives, params.key, InverseNormalizeMagnitude(params.value))
            return true
        end
    end
    return false
end


---@param params Params
---@return boolean
local function FortifyAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.fortifyAttributes, params.attribute, params.value)
    else
        AddValue(params.data.target.fortifyAttributes, params.attribute, params.value)
    end
    return true
end

---@param params Params
---@return boolean
local function DamageAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.damageAttributes, params.attribute, CalculateDPS(params.value, params.speed))
    else
        AddValue(params.data.target.damageAttributes, params.attribute, CalculateDPS(params.value, params.speed))
    end
    return true
end

---@param params Params
---@return boolean
local function DrainAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.drainAttributes, params.attribute, params.value)
    else
        AddValue(params.data.target.drainAttributes, params.attribute, params.value)
    end
    return true
end

---@param params Params
---@return boolean
local function AbsorbAttribute(params)
    if params.isSelf then
        return false
    else
        -- FIXME value is applied resist/weakness magicka, so absorb is store absorb
        local t = DrainAttribute(params)
        params.isSelf = true               -- TODO immutalbe
        params.attacker = true             -- fortifyAttribute
        local a = FortifyAttribute(params)
        return t or a
    end
end

---@param params Params
---@return boolean
local function RestoreAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.restoreAttributes, params.attribute, CalculateDPS(params.value, params.speed))
    else
        AddValue(params.data.target.restoreAttributes, params.attribute, CalculateDPS(params.value, params.speed))
    end
    return true
end

---@param params Params
---@return boolean
local function FortifySkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.fortifySkills, params.skill, params.value)
    else
        AddValue(params.data.target.fortifySkills, params.skill, params.value)
    end
    return true
end

---@param params Params
---@return boolean
local function DamageSkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.damageSkills, params.skill, CalculateDPS(params.value, params.speed))
    else
        AddValue(params.data.target.damageSkills, params.skill, CalculateDPS(params.value, params.speed))
    end
    return true
end

---@param params Params
---@return boolean
local function DrainSkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.drainSkills, params.skill, params.value)
    else
        AddValue(params.data.target.drainSkills, params.skill, params.value)
    end
    return true
end

---@param params Params
---@return boolean
local function AbsorbSkill(params)
    if params.isSelf then
        return false
    else
        -- FIXME value is applied resist/weakness magicka, so absorb is store absorb
        local t = DrainSkill(params)
        params.isSelf = true           -- TODO immutable
        params.attacker = true         -- fortifySkill
        local a = FortifySkill(params)
        return t or a
    end
end

---@param params Params
---@return boolean
local function RestoreSkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        AddValue(params.data.attacker.restoreSkills, params.skill, CalculateDPS(params.value, params.speed))
    else
        AddValue(params.data.target.restoreSkills, params.skill, CalculateDPS(params.value, params.speed))
    end
    return true
end

---@class Resolver
---@field func fun(params: Params): boolean
---@field attacker boolean
---@field target boolean

-- only vanilla effects
---@class ResolverTable
---@field [number] Resolver?
local resolver = {
    -- waterBreathing 0
    -- swiftSwim 1
    -- waterWalking 2
    [3] = { func = PositiveModifier, attacker = false, target = true }, -- shield 3
    [4] = { func = PositiveModifier, attacker = false, target = true }, -- fireShield 4
    [5] = { func = PositiveModifier, attacker = false, target = true }, -- lightningShield 5
    [6] = { func = PositiveModifier, attacker = false, target = true }, -- frostShield 6
    -- burden 7
    -- feather 8
    -- jump 9
    -- levitate 10
    -- slowFall 11
    -- lock 12
    -- open 13
    [14] = { func = DamageHealth, attacker = false, target = true },     -- fireDamage 14
    [15] = { func = DamageHealth, attacker = false, target = true },     -- shockDamage 15
    [16] = { func = DamageHealth, attacker = false, target = true },     -- frostDamage 16
    [17] = { func = DrainAttribute, attacker = true, target = true },    -- drainAttribute 17
    [18] = { func = DrainHealth, attacker = false, target = true },      -- drainHealth 18
    -- drainMagicka 19
    [20] = nil,                                                          -- drainFatigue 20
    [21] = { func = DrainSkill, attacker = true, target = true },        -- drainSkill 21
    [22] = { func = DamageAttribute, attacker = true, target = true },   -- damageAttribute 22
    [23] = { func = DamageHealth, attacker = false, target = true },     -- damageHealth 23
    -- damageMagicka 24
    [25] = nil,                                                          -- damageFatigue 25
    [26] = { func = DamageSkill, attacker = true, target = true },       -- damageSkill 26
    [27] = { func = DamageHealth, attacker = false, target = true },     -- poison 27
    [28] = { func = NegativeModifier, attacker = false, target = true }, -- weaknesstoFire 28
    [29] = { func = NegativeModifier, attacker = false, target = true }, -- weaknesstoFrost 29
    [30] = { func = NegativeModifier, attacker = false, target = true }, -- weaknesstoShock 30
    [31] = { func = NegativeModifier, attacker = true, target = true },  -- weaknesstoMagicka 31
    -- weaknesstoCommonDisease 32
    -- weaknesstoBlightDisease 33
    -- weaknesstoCorprusDisease 34
    [35] = { func = NegativeModifier, attacker = false, target = true }, -- weaknesstoPoison 35
    [36] = { func = NegativeModifier, attacker = false, target = true }, -- weaknesstoNormalWeapons 36
    -- disintegrateWeapon 37
    [38] = nil,                                                          -- disintegrateArmor 38
    -- invisibility 39
    -- chameleon 40
    -- light 41
    [42] = { func = PositiveModifier, attacker = false, target = true }, -- sanctuary 42
    -- nightEye 43
    -- charm 44
    -- paralyze 45
    -- silence 46
    [47] = { func = NegativeModifier, attacker = true, target = false }, -- blind 47
    -- sound 48
    -- calmHumanoid 49
    -- calmCreature 50
    -- frenzyHumanoid 51
    -- frenzyCreature 52
    -- demoralizeHumanoid 53
    -- demoralizeCreature 54
    -- rallyHumanoid 55
    -- rallyCreature 56
    [57] = { func = PositiveModifier, attacker = true, target = true }, -- dispel 57
    -- soultrap 58
    -- telekinesis 59
    -- mark 60
    -- recall 61
    -- divineIntervention 62
    -- almsiviIntervention 63
    -- detectAnimal 64
    -- detectEnchantment 65
    -- detectKey 66
    [67] = { func = MultModifier, attacker = true, target = true }, -- spellAbsorption 67
    [68] = { func = MultModifier, attacker = true, target = true }, -- reflect 68
    -- cureCommonDisease 69
    -- cureBlightDisease 70
    -- cureCorprusDisease 71
    [72] = { func = CurePoison, attacker = false, target = true },                -- curePoison 72
    -- cureParalyzation 73
    [74] = { func = RestoreAttribute, attacker = true, target = true },           -- restoreAttribute 74
    [75] = { func = PositiveModifierWithSpeed, attacker = false, target = true }, -- restoreHealth 75
    -- restoreMagicka 76
    [77] = nil,                                                                   -- restoreFatigue 77
    [78] = { func = RestoreSkill, attacker = true, target = true },               -- restoreSkill 78
    [79] = { func = FortifyAttribute, attacker = true, target = true },           -- fortifyAttribute 79
    [80] = { func = PositiveModifier, attacker = false, target = true },          -- fortifyHealth 80
    -- fortifyMagicka 81
    [82] = nil,                                                                   -- fortifyFatigue 82
    [83] = { func = FortifySkill, attacker = true, target = true },               -- fortifySkill 83
    -- fortifyMaximumMagicka 84
    [85] = { func = AbsorbAttribute, attacker = false, target = true },           -- absorbAttribute 85
    [86] = { func = DamageHealth, attacker = false, target = true },              -- absorbHealth 86
    -- absorbMagicka 87
    [88] = nil,                                                                   -- absorbFatigue 88
    [89] = { func = AbsorbSkill, attacker = false, target = true },               -- absorbSkill 89
    [90] = { func = PositiveModifier, attacker = false, target = true },          -- resistFire 90
    [91] = { func = PositiveModifier, attacker = false, target = true },          -- resistFrost 91
    [92] = { func = PositiveModifier, attacker = false, target = true },          -- resistShock 92
    [93] = { func = PositiveModifier, attacker = true, target = true },           -- resistMagicka 93
    -- resistCommonDisease 94
    -- resistBlightDisease 95
    -- resistCorprusDisease 96
    [97] = { func = PositiveModifier, attacker = false, target = true }, -- resistPoison 97
    [98] = { func = PositiveModifier, attacker = false, target = true }, -- resistNormalWeapons 98
    -- resistParalysis 99
    -- removeCurse 100
    -- turnUndead 101
    -- summonScamp 102
    -- summonClannfear 103
    -- summonDaedroth 104
    -- summonDremora 105
    -- summonAncestralGhost 106
    -- summonSkeletalMinion 107
    -- summonBonewalker 108
    -- summonGreaterBonewalker 109
    -- summonBonelord 110
    -- summonWingedTwilight 111
    -- summonHunger 112
    -- summonGoldenSaint 113
    -- summonFlameAtronach 114
    -- summonFrostAtronach 115
    -- summonStormAtronach 116
    [117] = { func = PositiveModifier, attacker = true, target = false }, -- fortifyAttack 117
    -- commandCreature 118
    -- commandHumanoid 119
    [120] = nil, -- boundDagger 120
    [121] = nil, -- boundLongsword 121
    [122] = nil, -- boundMace 122
    [123] = nil, -- boundBattleAxe 123
    [124] = nil, -- boundSpear 124
    [125] = nil, -- boundLongbow 125
    -- eXTRASPELL 126
    -- boundCuirass 127
    -- boundHelm 128
    -- boundBoots 129
    -- boundShield 130
    -- boundGloves 131
    -- corprus 132
    -- vampirism 133
    -- summonCenturionSphere 134
    [135] = { func = DamageHealth, attacker = false, target = true }, -- sunDamage 135
    -- stuntedMagicka 136
    -- summonFabricant 137
    -- callWolf 138
    -- callBear 139
    -- summonBonewolf 140
    -- sEffectSummonCreature04 141
    -- sEffectSummonCreature05 142
}

--- Poison Crafting
--- @param item tes3weapon
--- @param itemData tes3itemData?
--- @return tes3alchemy?
local function GetPoison(item, itemData)
    local id
    local projectile = tes3.player.data.g7_poisons and tes3.player.data.g7_poisons[item.id] or nil
    if projectile then
        id = projectile.poison
    elseif itemData then
        id = itemData.data.g7_poison
    end
    if id then
        local obj = tes3.getObject(id) ---@cast obj tes3alchemy
        return obj
    end
end

---@param self DPS
function DPS.Initialize(self)
    ---@diagnostic disable: need-check-nil
    -- TODO @cast if possible
    ---@diagnostic disable: assign-type-mismatch
    self.fFatigueBase = tes3.findGMST(tes3.gmst.fFatigueBase).value
    self.fFatigueMult = tes3.findGMST(tes3.gmst.fFatigueMult).value
    self.fCombatInvisoMult = tes3.findGMST(tes3.gmst.fCombatInvisoMult).value
    self.fSwingBlockBase = tes3.findGMST(tes3.gmst.fSwingBlockBase).value
    self.fSwingBlockMult = tes3.findGMST(tes3.gmst.fSwingBlockMult).value
    self.fBlockStillBonus = 1.25 -- tes3.findGMST(tes3.gmst.fBlockStillBonus).value -- hardcoded, OpenMW uses gmst
    self.iBlockMinChance = tes3.findGMST(tes3.gmst.iBlockMinChance).value
    self.iBlockMaxChance = tes3.findGMST(tes3.gmst.iBlockMaxChance).value
    self.fCombatArmorMinMult = tes3.findGMST(tes3.gmst.fCombatArmorMinMult).value
    self.fDifficultyMult = tes3.findGMST(tes3.gmst.fDifficultyMult).value

    -- resolve MCP or mod
    self.fDamageStrengthBase = 0.5
    self.fDamageStrengthMult = 0.01
    -- This MCP feature causes the game to use these GMSTs in its weapon damage calculations instead of the hardcoded
    -- values used by the vanilla game. With default values for the GMSTs the outcome is the same.
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.gameFormulaRestoration) then
        -- maybe require restart when to get initialing
        logger:info("Enabled MCP GameFormulaRestoration")
        self.fDamageStrengthBase = tes3.findGMST(tes3.gmst.fDamageStrengthBase).value
        self.fDamageStrengthMult = 0.1 * tes3.findGMST(tes3.gmst.fDamageStrengthMult).value
    end

    self.restoreDrainAttributesFix = false
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.restoreDrainAttributesFix) then
        logger:info("Enabled MCP RestoreDrainAttributesFix")
        self.restoreDrainAttributesFix = true
    end

    -- sign
    self.blindFix = -1
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.blindFix) then
        logger:info("Enabled MCP BlindFix")
        self.blindFix = 1
    end

    -- https://www.nexusmods.com/morrowind/mods/45913
    self.rangedWeaponCanCastOnSTrike = false
    if tes3.isModActive("Cast on Strike Bows.esp") then
        -- this MCP fix seems, deny on strile option when enchaning, exsisting ranged weapons on strike dont require this fix to torigger.
        -- ~tes3.hasCodePatchFeature(tes3.codePatchFeature.fixEnchantOptionsOnRanged)
        logger:info("Enabled Cast on Strike Bows")
        self.rangedWeaponCanCastOnSTrike = true
    end

    -- https://www.nexusmods.com/morrowind/mods/49609
    -- The vanilla game doubles the official damage values for thrown weapons. The mod Thrown Projectiles Revamped
    -- halves the actual damage done, so don't double the displayed damage if that mod is in use.
    self.throwWeaponAlreadyModified = false
    if tes3.isLuaModActive("DQ.ThroProjRev") then
        logger:info("Enabled Thrown Projectiles Revamped")
        self.throwWeaponAlreadyModified = true
    end

    self.poisonCrafting = false
    if tes3.isLuaModActive("poisonCrafting") then
        logger:info("Enabled Poison Crafting")
        self.poisonCrafting = true
    end
end

---@param self DPS
---@param weapon tes3weapon
---@return boolean
function DPS.CanCastOnStrike(self, weapon)
    return self.rangedWeaponCanCastOnSTrike or weapon.isRanged == false
end

-- combination effect id, attribute, skill
---@param effect tes3.effect
---@param attribute tes3.attribute?
---@param skill tes3.skill?
---@return integer
local function GenerateKey(effect, attribute, skill)
    local b = require("bit")
    local key = 0
    if effect ~= nil and effect >= 0 then
        key = effect
        logger:debug(string.format("%d", effect))
    end
    if attribute and attribute >= 0 then
        key = b.bor(b.lshift(attribute, 16), key)
        logger:debug(string.format("%d", attribute))
    end
    if skill and skill >= 0 then
        key = b.bor(b.lshift(skill, 16 + 4), key)
        logger:debug(string.format("%d", skill))
    end
    return key
end

---@param data ScratchData
---@param icons { [tes3.effect]: string[] }
---@param effects tes3effect[]
---@param weaponSpeed number
---@param weaponSkillId tes3.skill
---@param forceTargetEffects boolean
---@return ScratchData
---@return { [tes3.effect]: string[] }
local function CollectEffects(data, icons, effects, weaponSpeed, weaponSkillId, forceTargetEffects)
    for _, effect in ipairs(effects) do
        
        if effect ~= nil and effect.id >= 0 then
            local id = effect.id
            local r = resolver[id]
            if r then
                local value = (effect.max + effect.min) * 0.5 -- uniform RNG average
                local isSelf = effect.rangeType == tes3.effectRange.self
                if forceTargetEffects then 
                    isSelf = false
                end
                ---@type Params
                local params = {
                    data = data,
                    key = id,
                    value = value,
                    speed = weaponSpeed,
                    isSelf = isSelf,
                    attacker = r.attacker,
                    target = r.target,
                    attribute = effect.attribute, -- if invalid it returns -1. not nil.
                    skill = effect.skill,         -- if invalid it returns -1. not nil.
                    weaponSkillId = weaponSkillId,
                }
                local affect = r.func(params)
                if affect and id ~= nil then
                    -- adding own key, then merge on resolve phase
                    if not icons[id] then
                        icons[id] = {}
                    end
                    table.insert(icons[id], effect.object.icon)
                end
            end
        end
    end
    return data, icons
end

---@param enchantment tes3enchantment
---@param weaponSpeed number
---@param canCastOnStrike boolean
---@param weaponSkillId tes3.skill
---@return ScratchData
---@return { [tes3.effect]: string[] }
local function CollectEnchantmentEffect(enchantment, weaponSpeed, canCastOnStrike, weaponSkillId)
    local data = CreateScratchData()

    local icons = {} ---@type {[tes3.effect]: string[]}

    if enchantment then
        -- todo not yet on cast
        -- better is on strike effect consider charge cost
        local onStrike = canCastOnStrike and enchantment.castType == tes3.enchantmentType.onStrike
        local constant = enchantment.castType == tes3.enchantmentType.constant
        if onStrike or constant then
            CollectEffects(data, icons, enchantment.effects, weaponSpeed, weaponSkillId, false)
        end
    end

    return data, icons
end

---@param self DPS
---@param agility number
---@param luck number
---@param fatigueTerm number
---@param sanctuary number
---@param chameleon number
---@param invisibility boolean
---@param isKnockedDown boolean
---@param isParalyzed boolean
---@param unware boolean
---@return number
function DPS.CalculateEvasion(self, agility, luck, fatigueTerm, sanctuary, chameleon, invisibility, isKnockedDown,
                              isParalyzed, unware)
    local evasion = 0
    if not (isKnockedDown or isParalyzed or unware) then
        evasion = combat.CalculateEvasion(agility, luck, fatigueTerm, sanctuary)
    end
    evasion = evasion + math.min(self.fCombatInvisoMult * chameleon, 100)
    evasion = evasion + math.min(self.fCombatInvisoMult * (invisibility and 1 or 0), 100)
    return evasion
end

-- from Accurate Tooltip Stats (https://www.nexusmods.com/morrowind/mods/51354) by Necrolesian
---@param weapon tes3weapon
---@param itemData tes3itemData
---@return number
local function GetConditionModifier(weapon, itemData)
    -- Projectiles (thrown weapons, arrows, bolts) have no condition data.
    local hasDurability = weapon.hasDurability
    local maximumCondition = (hasDurability and weapon.maxCondition) or 1.0
    local currentCondition = (hasDurability and itemData and itemData.condition) or maximumCondition
    return currentCondition / maximumCondition
end

-- from Accurate Tooltip Stats (https://www.nexusmods.com/morrowind/mods/51354) by Necrolesian
---@param self DPS
---@param strength number
---@return number
function DPS.GetStrengthModifier(self, strength)
    -- how capped value without mcp patch?
    local currentStrength = math.max(strength, 0)
    -- resolved base and mult on initialize
    return self.fDamageStrengthBase + (self.fDamageStrengthMult * currentStrength)
end

---@class DamageRange
---@field min number
---@field max number

-- from Accurate Tooltip Stats (https://www.nexusmods.com/morrowind/mods/51354) by Necrolesian
---@param self DPS
---@param weapon tes3weapon
---@param marksman boolean
---@return { [tes3.physicalAttackType]: DamageRange }
function DPS.GetWeaponBaseDamage(self, weapon, marksman)
    local baseDamage = {} ---@type { [tes3.physicalAttackType]: DamageRange }
    if marksman then
        baseDamage[tes3.physicalAttackType.projectile] = { min = weapon.chopMin, max = weapon.chopMax }
    else
        baseDamage[tes3.physicalAttackType.slash] = { min = weapon.slashMin, max = weapon.slashMax }
        baseDamage[tes3.physicalAttackType.thrust] = { min = weapon.thrustMin, max = weapon.thrustMax }
        baseDamage[tes3.physicalAttackType.chop] = { min = weapon.chopMin, max = weapon.chopMax }
    end

    -- The vanilla game doubles the official damage values for thrown weapons. The mod Thrown Projectiles Revamped
    -- halves the actual damage done, so don't double the displayed damage if that mod is in use.
    if weapon.type == tes3.weaponType.marksmanThrown and not self.throwWeaponAlreadyModified then
        baseDamage[tes3.physicalAttackType.projectile].min = 2 * baseDamage[tes3.physicalAttackType.projectile].min
        baseDamage[tes3.physicalAttackType.projectile].max = 2 * baseDamage[tes3.physicalAttackType.projectile].max
    end

    return baseDamage
end

---@param self DPS
---@param currentFatigue number
---@param baseFatigue number
---@return number
function DPS.GetFatigueTerm(self, currentFatigue, baseFatigue)
    return math.max(self.fFatigueBase - self.fFatigueMult * math.max(1.0 - currentFatigue / baseFatigue, 0.0), 0.0)
end

---@param self DPS
---@param weapon tes3weapon
---@param itemData tes3itemData
---@param speed number
---@param strength number
---@param armorRating number
---@param marksman boolean
---@return { [tes3.physicalAttackType]: DamageRange }
function DPS.CalculateWeaponDamage(self, weapon, itemData, speed, strength, armorRating, marksman)
    local baseDamage = self:GetWeaponBaseDamage(weapon, marksman)
    local damageMultStr = 0
    local damageMultCond = 1.0
    if self.config.accurateDamage then
        damageMultStr = self:GetStrengthModifier(strength)
        if not self.config.maxDurability then
            damageMultCond = GetConditionModifier(weapon, itemData)
        end
    end
    local minSpeed = speed -- TODO maybe more quickly, it seems depends animation frame
    local maxSpeed = speed -- same as animation frame?
    for i, v in pairs(baseDamage) do
        if self.config.accurateDamage then
            v.min = combat.CalculateAcculateWeaponDamage(v.min, damageMultStr, damageMultCond, 1);
            v.max = combat.CalculateAcculateWeaponDamage(v.max, damageMultStr, damageMultCond, 1);

            -- The reduction occurs only after all the multipliers are applied to the damage.
            if armorRating > 0 then
                v.min = combat.CalculateDamageReductionFromArmorRating(v.min, armorRating, self.fCombatArmorMinMult)
                v.max = combat.CalculateDamageReductionFromArmorRating(v.max, armorRating, self.fCombatArmorMinMult)
            end
        end
        v.min = CalculateDPS(v.min, minSpeed)
        v.max = CalculateDPS(v.max, maxSpeed)
    end
    return baseDamage
end

-- TODO rename
-- TODO useBestAttack timing is too late, should be base damage phase. but results almost same
---@param weaponDamages { [tes3.physicalAttackType]: DamageRange }
---@param minmaxRange boolean
---@param useBestAttack boolean
---@return DamageRange
---@return { [tes3.physicalAttackType] :boolean }
local function ResolveWeaponDPS(weaponDamages, minmaxRange, useBestAttack)
    local damageRange = { min = 0, max = 0 } ---@type DamageRange
    local highestType = {}
    local typeDamages = {}
    local highest = 0
    for k, v in pairs(weaponDamages) do
        damageRange.min = math.max(damageRange.min, v.min)
        damageRange.max = math.max(damageRange.max, v.max)
        local typeDamage = v.max
        if minmaxRange or useBestAttack then
            typeDamage = (v.max + v.min) -- average
        end
        highest = math.max(highest, typeDamage)
        typeDamages[k] = typeDamage
    end
    for k, v in pairs(typeDamages) do
        if highest == v then -- lua can compare float equals?
            highestType[k] = true
        end
    end
    return damageRange, highestType
end

---@param icons { [tes3.effect]: string[] }
---@param dest tes3.effect
---@param src tes3.effect
local function MergeIcons(icons, dest, src)
    if dest ~= src and icons[src] then
        if not icons[dest] then
            icons[dest] = {}
        end
        for _, path in ipairs(icons[src]) do
            table.insert(icons[dest], path)
        end
    end
end

---@param effect ScratchData
---@return number
---@return {[tes3.effect]: number}
local function ResolveEffectDPS(effect)
    local effectDamages = {}
    local effectTotal = 0

    -- damage
    for k, v in pairs(effect.target.damages) do
        effectDamages[k] = v
        effectTotal = effectTotal + v
    end

    -- healing
    local healing = {
        tes3.effect.restoreHealth,
        tes3.effect.fortifyHealth,
    }
    for _, v in ipairs(healing) do
        local h          = GetValue(effect.target.positives, v, 0)
        effectDamages[v] = -h -- display value is negative
        effectTotal      = effectTotal - h
    end

    return effectTotal, effectDamages
end

---@param effect ScratchData
---@param icons { [tes3.effect]: string[] }
---@param resistMagicka number
local function ResolveModifiers(effect, icons, resistMagicka)
    effect.target.resists = {}
    effect.attacker.resists = {}
    -- resist/weakness magicka
    local rm = tes3.effect.resistMagicka
    local wm = tes3.effect.weaknesstoMagicka
    -- Once Resist Magicka reaches 100%, it's the only type of resistance that can't be broken by a Weakness effect, since Weakness is itself a magicka type spell.
    -- so if both apply, above works?
    local targetResistMagicka = InverseNormalizeMagnitude(GetValue(effect.target.positives, rm, 0))
    targetResistMagicka = InverseNormalizeMagnitude(GetValue(effect.target.negatives, wm, 0)) * targetResistMagicka
    local attackerResistMagicka = InverseNormalizeMagnitude(GetValue(effect.attacker.positives, rm, 0) + resistMagicka)
    attackerResistMagicka = InverseNormalizeMagnitude(GetValue(effect.attacker.negatives, wm, 0)) * attackerResistMagicka
    effect.target.resists[rm] = targetResistMagicka
    effect.attacker.resists[rm] = attackerResistMagicka
    -- apply resist magicka to negative effects
    -- TODO use acculate option? or remove opiton
    for k, v in pairs(effect.target.negatives) do
        if k ~= tes3.effect.weaknesstoMagicka then
            effect.target.negatives[k] = v * targetResistMagicka
        end
    end
    for k, v in pairs(effect.attacker.negatives) do
        if k ~= tes3.effect.weaknesstoMagicka then
            effect.attacker.negatives[k] = v * attackerResistMagicka
        end
    end

    -- probability
    -- but it seems not apply the same item effects. if effects already applied, it can be dispeled.
    local reflectChance = GetValue(effect.target.positives, tes3.effect.spellAbsorption, 1.0) *
        GetValue(effect.target.positives, tes3.effect.reflect, 1.0)
    local dispelChance = InverseNormalizeMagnitude(GetValue(effect.target.positives, tes3.effect.dispel, 0))

    -- merge resist/weakness elemental and shield
    local resistweakness = {
        [tes3.effect.resistFire]          = { tes3.effect.weaknesstoFire, tes3.effect.fireShield },
        [tes3.effect.resistFrost]         = { tes3.effect.weaknesstoFrost, tes3.effect.frostShield },
        [tes3.effect.resistShock]         = { tes3.effect.weaknesstoShock, tes3.effect.lightningShield },
        -- [tes3.effect.resistMagicka]       = {tes3.effect.weaknesstoMagicka}, -- pre calculated
        [tes3.effect.resistPoison]        = { tes3.effect.weaknesstoPoison },
        [tes3.effect.resistNormalWeapons] = { tes3.effect.weaknesstoNormalWeapons },
    }
    for k, v in pairs(resistweakness) do
        local resist = GetValue(effect.target.positives, k, 0)
        if v[2] then -- shield
            resist = resist + GetValue(effect.target.positives, v[2], 0)
            MergeIcons(icons, k, v[2])
        end
        resist = resist - GetValue(effect.target.negatives, v[1], 0)
        effect.target.resists[k] = InverseNormalizeMagnitude(resist)

        MergeIcons(icons, k, v[1])
    end

    -- attrib, skill
    local function ApplyResistMagicka(actor, mod)
        for k, v in pairs(actor.damageAttributes) do
            actor.damageAttributes[k] = v * mod
        end
        for k, v in pairs(actor.drainAttributes) do
            actor.damageAttributes[k] = v * mod
        end
        for k, v in pairs(actor.damageSkills) do
            actor.damageAttributes[k] = v * mod
        end
        for k, v in pairs(actor.drainSkills) do
            actor.damageAttributes[k] = v * mod
        end
    end
    ApplyResistMagicka(effect.target, targetResistMagicka)
    ApplyResistMagicka(effect.attacker, attackerResistMagicka)

    -- damage
    local e = effect.target
    local pair = {
        [tes3.effect.fireDamage] = tes3.effect.resistFire,
        [tes3.effect.frostDamage] = tes3.effect.resistFrost,
        [tes3.effect.shockDamage] = tes3.effect.resistShock,
        [tes3.effect.poison] = tes3.effect.resistPoison,
        [tes3.effect.absorbHealth] = tes3.effect.resistMagicka,
        [tes3.effect.damageHealth] = tes3.effect.resistMagicka,
        [tes3.effect.drainHealth] = tes3.effect.resistMagicka, -- temporary down
        [tes3.effect.sunDamage] = nil,                         -- only vampire
    }

    for k, v in pairs(pair) do
        if v then
            local damage = GetValue(e.damages, k, 0) * GetValue(e.resists, v, 1.0)
            e.damages[k] = damage
            MergeIcons(icons, k, v)
        end
    end
end

---@param e Modifier
---@param t tes3.attribute
---@param attributes tes3statistic[]
---@return number
local function GetModifiedAttribute(e, t, attributes)
    local current = attributes[t + 1].current
    if e.damageAttributes[t] then
        current = current - e.damageAttributes[t]
    end

    -- TODO mcp fix or unfix
    -- if your Strength has been damaged 25 points, but you're wearing the Right Fist of Randagulf (+20 Fortify), Restore Strength would only give you back 5 points. To get around this, remove the Fortify effect (in the above example, remove the gauntlet) before invoking the Restore effect.
    -- This bug is fixed by the Morrowind Code Patch.

    -- Restore attributes spells did not recognise Fortify effects when restoring. Take for example, a base agility of 50, fortified by +30 to 80. If your agility was damaged below 80, a Restore spell would only restore up to 50 and stop working. Restore attributes spells now restore up to your fully fortified amount.
    -- The same problem occurred when Drain attributes spells expired. These should now restore the fortified attribute properly as well.

    if e.restoreAttributes[t] then -- can restore drained value?
        local base = attributes[t + 1].base
        local decreased = math.max(base - current, 0)
        current = current + math.min(e.restoreAttributes[t], decreased)
    end
    if e.drainAttributes[t] then
        current = current - e.drainAttributes[t] -- at once
    end
    if e.fortifyAttributes[t] then
        current = current + e.fortifyAttributes[t]
    end
    return current
end

---@param e Modifier
---@param t tes3.skill
---@param skills tes3statisticSkill[]
---@return number
local function GetModifiedSkill(e, t, skills)
    local current = skills[t + 1].current
    if e.damageSkills[t] then
        current = current - e.damageSkills[t]
    end
    -- TODO mcp fix or unfix

    if e.restoreSkills[t] then -- can restore drained value?
        local base = skills[t + 1].base
        local decreased = math.max(base - current, 0)
        current = current + math.min(e.restoreSkills[t], 0)
    end
    if e.drainSkills[t] then
        current = current - e.drainSkills[t] -- at once
    end
    if e.fortifySkills[t] then
        current = current + e.fortifySkills[t]
    end
    return current
end

---@param effect ScratchData
local function GetTargetArmorRating(effect)
    local shield = GetValue(effect.target.positives, tes3.effect.shield, 0);
    return shield -- currently only shield effect
end

-- local function GetModifiedCurrentFatigue(e, t, fatigue)
-- end
-- local function GetModifiedMaxFatigue(e, t, fatigue)
-- end

-- local function CalculateHitRate_(weapon, effect)
--     local skillId = weapon.skillId
--     local weaponSkill = math.max(tes3.mobilePlayer:getSkillValue(skillId) + GetModifiedSkill(effect.attacker, skillId), 0)
--     local agility = math.max(
--         tes3.mobilePlayer.agility.current + GetModifiedAttribute(effect.attacker, tes3.attribute.agility), 0)
--     local luck = math.max(tes3.mobilePlayer.luck.current + GetModifiedAttribute(effect.attacker, tes3.attribute.luck), 0)
--     -- return CalculateHitRate(weaponSkill, agility, luck, 0, 1, 0, 0)
-- end

-- local function CalculateEvasion_(weapon, effect)
-- end

-- local function CalculateHit(weapon, effect)
--     --return CalculateChanceToHit(hitRate, evasion)
-- end


---@class DPSData
---@field weaponDamageRange table
---@field weaponDamages table
---@field highestType { [tes3.physicalAttackType]: boolean }
---@field effectTotal number
---@field effectDamages { [tes3.effect]: number }
---@field icons { [tes3.effect]: string[] }

-- I'm not sure how to resolve Morrowind's effect strictly.
-- If it was to apply them in order from the top, each time, then when the order is Damage, Weakness, so Weakness would have no effect at all.
-- It is indeed possible to do so, but here it resolves all modifiers once and then apply them.
-- And Why do I not use tes3.getEffectMagnitude() or other useful functions? That's because it works for players, but cannot be used against a notional, nonexistent enemy.
---@param self DPS
---@param weapon tes3weapon
---@param itemData tes3itemData
---@param useBestAttack boolean
---@return DPSData
function DPS.CalculateDPS(self, weapon, itemData, useBestAttack)
    local marksman = weapon.isRanged or weapon.isProjectile
    local speed = weapon.speed -- TODO perhaps speed is scale factor, not acutal length

    local effect, icons = CollectEnchantmentEffect(weapon.enchantment, speed, self:CanCastOnStrike(weapon), weapon.skillId)

    if self.poisonCrafting then
        local poison = GetPoison(weapon, itemData)
        if poison then 
            -- poison effect is only once, so speed is 1
            -- Also in vanilla, potion's effectRange is always self, because of it cannot be applied to weapons. Therefore, it is forced to be touch effect
            CollectEffects(effect, icons, poison.effects, 1, weapon.skillId, true)
        end
    end

    -- TODO this resist magicka should ignore applied effect from this weapon
    local resistMagicka = tes3.mobilePlayer.resistMagicka
    ResolveModifiers(effect, icons, resistMagicka)

    -- experimental: counter applied active magic effect
    -- TODO before resolve for resistMagicka
    -- split writing destination, values shoud not resist, they are resisted already.
    if weapon.enchantment then
        local onStrike = self:CanCastOnStrike(weapon) and weapon.enchantment.castType == tes3.enchantmentType.onStrike
        local constant = weapon.enchantment.castType == tes3.enchantmentType.constant
        if onStrike or constant then -- no on use
            for _, a in ipairs(tes3.mobilePlayer.activeMagicEffectList) do
                if a.instance.sourceType == tes3.magicSourceType.enchantment and
                    a.instance.item and a.instance.item.objectType == tes3.objectType.weapon then
                    -- only tooltip weapon, possible enemy attacked using same weapon.
                    if a.instance.item.id == weapon.id and a.instance.magicID == weapon.enchantment.id and a.effectId >= 0 then
                        logger:debug(weapon.id .. " " .. weapon.enchantment.id)
                        local id = a.effectId
                        local r = resolver[id]
                        if r then
                            ---@type Params
                            local params = {
                                data = effect,
                                key = id,
                                value = -a.effectInstance.effectiveMagnitude, -- counter resisted value
                                speed = 1.0,
                                isSelf = true,
                                attacker = r.attacker,
                                target = r.target,
                                attribute = a.attributeId,
                                skill = a.skillId,
                                weaponSkillId = weapon.skillId,
                            }
                            -- TODO use original function, but reusing almost case is ok
                            r.func(params)
                        end
                    end
                end
            end
        end
    end

    -- TODO icons
    local strength = GetModifiedAttribute(effect.attacker, tes3.attribute.strength, tes3.mobilePlayer.attributes)
    local armorRating = GetTargetArmorRating(effect);

    local weaponDamages = self:CalculateWeaponDamage(weapon, itemData, speed, strength, armorRating, marksman)
    local weaponDamageRange, highestType = ResolveWeaponDPS(weaponDamages, self.config.minmaxRange, useBestAttack)
    local effectTotal, effectDamages = ResolveEffectDPS(effect)

    return {
        weaponDamageRange = weaponDamageRange,
        weaponDamages = weaponDamages,
        highestType = highestType,
        effectTotal = effectTotal,
        effectDamages = effectDamages,
        icons = icons,
    }
end

-- unittest
---@param self DPS
---@param unitwind UnitWind
function DPS.RunTest(self, unitwind)
    ---@diagnostic disable: need-check-nil
    unitwind:test("Empty", function()
        local r = resolver[tes3.effect.detectAnimal]
        unitwind:expect(r).toBe(nil)
    end)

    unitwind:test("DamageHealth", function()
        local e = {
            tes3.effect.fireDamage,
            tes3.effect.shockDamage,
            tes3.effect.frostDamage,
            tes3.effect.damageHealth,
            tes3.effect.poison,
            tes3.effect.absorbHealth,
            tes3.effect.sunDamage,
        }
        for _, v in ipairs(e) do
            --logger:debug(tostring(v))
            local r = resolver[v]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = v,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(true)
            unitwind:expect(data.target.damages[params.key]).toBe(20)
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)

    unitwind:test("DrainHealth", function()
        local v = tes3.effect.drainHealth
        local r = resolver[v]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        ---@type Params
        local params = {
            data = data,
            key = v,
            value = 10,
            speed = 2,
            isSelf = false,
            attacker = r.attacker,
            target = r.target,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.damages[params.key]).toBe(10)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("CurePoison", function()
        local v = tes3.effect.curePoison
        local r = resolver[v]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        ---@type Params
        local params = {
            data = data,
            key = v,
            value = 10,
            speed = 2,
            isSelf = false,
            attacker = r.attacker,
            target = r.target,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.positives[params.key]).toBe(1)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("PositiveModifier", function()
        local e = {
            [tes3.effect.shield] = { true, false },
            [tes3.effect.fireShield] = { true, false },
            [tes3.effect.lightningShield] = { true, false },
            [tes3.effect.frostShield] = { true, false },
            [tes3.effect.sanctuary] = { true, false },
            [tes3.effect.dispel] = { true, true },
            [tes3.effect.fortifyHealth] = { true, false },
            [tes3.effect.resistFire] = { true, false },
            [tes3.effect.resistFrost] = { true, false },
            [tes3.effect.resistShock] = { true, false },
            [tes3.effect.resistMagicka] = { true, true },
            [tes3.effect.resistPoison] = { true, false },
            [tes3.effect.resistNormalWeapons] = { true, false },
            [tes3.effect.fortifyAttack] = { false, true },
        }
        for k, v in pairs(e) do
            -- logger:debug(tostring(k))
            local r = resolver[k]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = v,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.positives[params.key]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
            if affect then
                unitwind:expect(data.attacker.positives[params.key]).toBe(10)
            end
        end
    end)

    unitwind:test("PositiveModifierWithSpeed", function()
        local v = tes3.effect.restoreHealth
        local r = resolver[v]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        ---@type Params
        local params = {
            data = data,
            key = v,
            value = 10,
            speed = 2,
            isSelf = false,
            attacker = r.attacker,
            target = r.target,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.positives[params.key]).toBe(20)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("NegativeModifier", function()
        local e = {
            [tes3.effect.weaknesstoFire] = { true, false },
            [tes3.effect.weaknesstoFrost] = { true, false },
            [tes3.effect.weaknesstoShock] = { true, false },
            [tes3.effect.weaknesstoMagicka] = { true, true },
            [tes3.effect.weaknesstoPoison] = { true, false },
            [tes3.effect.weaknesstoNormalWeapons] = { true, false },
            [tes3.effect.blind] = { false, true },
        }
        for k, v in pairs(e) do
            -- logger:debug(tostring(k))
            local r = resolver[k]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = v,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.negatives[params.key]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
            if affect then
                unitwind:expect(data.attacker.negatives[params.key]).toBe(10)
            end
        end
    end)

    unitwind:test("MultModifier", function()
        local e = {
            tes3.effect.spellAbsorption,
            tes3.effect.reflect,
        }
        for _, v in ipairs(e) do
            -- logger:debug(tostring(k))
            local r = resolver[v]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = v,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(true)
            unitwind:expect(data.target.positives[params.key]).toBe(0.9)
            affect = r.func(params)
            unitwind:expect(data.target.positives[params.key]).toBe(0.81)
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)

    unitwind:test("FortifyAttribute", function()
        local e = tes3.effect.fortifyAttribute
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in pairs(attributeFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                attribute = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.fortifyAttributes[params.attribute]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.fortifyAttributes[params.attribute]).toBe(10)
            end
        end
    end)

    unitwind:test("DamageAttribute", function()
        local e = tes3.effect.damageAttribute
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                attribute = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.damageAttributes[params.attribute]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.damageAttributes[params.attribute]).toBe(20)
            end
        end
    end)

    unitwind:test("DrainAttribute", function()
        local e = tes3.effect.drainAttribute
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                attribute = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.drainAttributes[params.attribute]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.drainAttributes[params.attribute]).toBe(10)
            end
        end
    end)

    unitwind:test("AbsorbAttribute", function()
        local e = tes3.effect.absorbAttribute
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                attribute = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target or v.attacker)
            if v.target then
                unitwind:expect(data.target.drainAttributes[params.attribute]).toBe(10)
            end
            if v.attacker then
                unitwind:expect(data.attacker.fortifyAttributes[params.attribute]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(false) -- self absorb is no affect
        end
    end)

    unitwind:test("RestoreAttribute", function()
        local e = tes3.effect.restoreAttribute
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                attribute = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.restoreAttributes[params.attribute]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.restoreAttributes[params.attribute]).toBe(20)
            end
        end
    end)

    unitwind:test("FortifySkill", function()
        local e = tes3.effect.fortifySkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
                weaponSkillId = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.fortifySkills[params.skill]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.fortifySkills[params.skill]).toBe(10)
            end
            params.weaponSkillId = tes3.skill.unarmored -- mismatch
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)

    unitwind:test("DamageSkill", function()
        local e = tes3.effect.damageSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
                weaponSkillId = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.damageSkills[params.skill]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.damageSkills[params.skill]).toBe(20)
            end
            params.weaponSkillId = tes3.skill.unarmored -- mismatch
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)

    unitwind:test("DrainSkill", function()
        local e = tes3.effect.drainSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
                weaponSkillId = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.drainSkills[params.skill]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.drainSkills[params.skill]).toBe(10)
            end
            params.weaponSkillId = tes3.skill.unarmored -- mismatch
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)

    unitwind:test("AbsorbSkill", function()
        local e = tes3.effect.absorbSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
                weaponSkillId = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target or v.attacker)
            if v.target then
                unitwind:expect(data.target.drainSkills[params.skill]).toBe(10)
            end
            if v.attacker then
                unitwind:expect(data.attacker.fortifySkills[params.skill]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(false) -- self absorb is no affect
            params.weaponSkillId = tes3.skill.unarmored -- mismatch
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)

    unitwind:test("RestoreSkill", function()
        local e = tes3.effect.restoreSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            ---@type Params
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
                weaponSkillId = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v.target)
            if affect then
                unitwind:expect(data.target.restoreSkills[params.skill]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v.attacker)
            if affect then
                unitwind:expect(data.attacker.restoreSkills[params.skill]).toBe(20)
            end
            params.weaponSkillId = tes3.skill.unarmored -- mismatch
            affect = r.func(params)
            unitwind:expect(affect).toBe(false)
        end
    end)
end

return DPS

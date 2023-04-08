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
---@field blindFix number
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

---@class Target
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
---@field attacker Target
---@field target Target

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

-- TODO modifieable for mod
-- todo name {target, attacker}
local attributeFilter = {
    [tes3.attribute.strength] = { false, true }, -- damage
    [tes3.attribute.intelligence] = { false, false },
    [tes3.attribute.willpower] = { true, true }, -- fatigue
    [tes3.attribute.agility] = { true, true },   -- evade, hit, fatigue
    [tes3.attribute.speed] = { false, false },   -- TODO weapon swing mod
    [tes3.attribute.endurance] = { true, true }, -- TODO realtime health calculate mod, fatigue
    [tes3.attribute.personality] = { false, false },
    [tes3.attribute.luck] = { true, true },      -- evade, hit
}

-- TODO should be combine current equipments
-- {target, attacker}
local skillFilter = {
    [tes3.skill.block] = { true, false },
    [tes3.skill.armorer] = { false, false },
    [tes3.skill.mediumArmor] = { true, false },
    [tes3.skill.heavyArmor] = { true, false },
    [tes3.skill.bluntWeapon] = { false, true },
    [tes3.skill.longBlade] = { false, true },
    [tes3.skill.axe] = { false, true },
    [tes3.skill.spear] = { false, true },
    [tes3.skill.athletics] = { false, false },
    [tes3.skill.enchant] = { false, false },
    [tes3.skill.destruction] = { false, false },
    [tes3.skill.alteration] = { false, false },
    [tes3.skill.illusion] = { false, false },
    [tes3.skill.conjuration] = { false, false },
    [tes3.skill.mysticism] = { false, false },
    [tes3.skill.restoration] = { false, false },
    [tes3.skill.alchemy] = { false, false },
    [tes3.skill.unarmored] = { false, false },
    [tes3.skill.security] = { false, false },
    [tes3.skill.sneak] = { false, false },
    [tes3.skill.acrobatics] = { false, false },
    [tes3.skill.lightArmor] = { true, false },
    [tes3.skill.shortBlade] = { false, true },
    [tes3.skill.marksman] = { false, true },
    [tes3.skill.mercantile] = { false, false },
    [tes3.skill.speechcraft] = { false, false },
    [tes3.skill.handToHand] = { false, false },
}

---@param params Params
---@return boolean
local function IsAffectedAttribute(params)
    local f = attributeFilter[params.attribute]
    if f then
        -- lua: a and b or c idiom is useless when b and c are boolean, it return b or c.
        if params.isSelf then
            return params.attacker and f[2]
        else
            return params.target and f[1]
        end
    else
        return false
    end
end

---@param params Params
---@return boolean
local function IsAffectedSkill(params)
    local f = skillFilter[params.skill]
    if f then
        -- lua: a and b or c idiom is useless when b and c are boolean, it return b or c.
        if params.isSelf then
            return params.attacker and f[2]
        else
            return params.target and f[1]
        end
    else
        return false
    end
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
        -- TODO if player equiped constant effect weapon then skip this.
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
        -- TODO if player equiped constant effect weapon then skip this.
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
        local t = DrainAttribute(params)
        params.isSelf = true               -- TODO immutalbe
        params.attacker = true             -- fortifyAttribute
        local a = FortifyAttribute(params) -- value is applied resist/weakness magicka?
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
        -- TODO if player equiped constant effect weapon then skip this.
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
        -- TODO if player equiped constant effect weapon then skip this.
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
        local t = DrainSkill(params)
        params.isSelf = true           -- TODO immutable
        params.attacker = true         -- fortifySkill
        local a = FortifySkill(params) -- value is applied resist/weakness magicka?
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


-- only vanilla
-- TODO add config mod efect

---@class Resolver
---@field func fun(params: Params): boolean
---@field attacker boolean
---@field target boolean

---@class ResolverTable
---@field [number] Resolver?
local resolver = {
    -- waterBreathing 0
    -- swiftSwim 1
    -- waterWalking 2
    [3] = { func = PositiveModifier, attacker = false, target = true }, -- shield 3
    [4] = { func = PositiveModifier, attacker = false, target = true },    -- fireShield 4
    [5] = { func = PositiveModifier, attacker = false, target = true },    -- lightningShield 5
    [6] = { func = PositiveModifier, attacker = false, target = true },    -- frostShield 6
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
        logger:info("MCP: GameFormulaRestoration")
        self.fDamageStrengthBase = tes3.findGMST(tes3.gmst.fDamageStrengthBase).value
        self.fDamageStrengthMult = 0.1 * tes3.findGMST(tes3.gmst.fDamageStrengthMult).value
    end

    -- sign
    self.blindFix = -1
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.blindFix) then
        logger:info("MCP: BlindFix")
        self.blindFix = 1
    end

    -- https://www.nexusmods.com/morrowind/mods/45913
    self.rangedWeaponCanCastOnSTrike = false
    if tes3.isModActive("Cast on Strike Bows.esp") then
        -- this MCP fix seems, deny on strile option when enchaning, exsisting ranged weapons on strike dont require this fix to torigger.
        -- ~tes3.hasCodePatchFeature(tes3.codePatchFeature.fixEnchantOptionsOnRanged)
        logger:info("ESP: Cast on Strike Bows")
        self.rangedWeaponCanCastOnSTrike = true
    end

    -- https://www.nexusmods.com/morrowind/mods/49609
    -- The vanilla game doubles the official damage values for thrown weapons. The mod Thrown Projectiles Revamped
    -- halves the actual damage done, so don't double the displayed damage if that mod is in use.
    self.throwWeaponAlreadyModified = false
    if tes3.isLuaModActive("DQ.ThroProjRev") then
        logger:info("MWSE: Thrown Projectiles Revamped")
        self.throwWeaponAlreadyModified = true
    end

    -- TODO compatible Poison Crafting
    self.poisonCrafting = false
    if tes3.isLuaModActive("poisonCrafting") then
        logger:info("MWSE: Poison Crafting")
        self.poisonCrafting = true
    end
end

---@param self DPS
---@param weapon tes3weapon
---@return boolean
function DPS.CanCastOnStrike(self, weapon)
    return self.rangedWeaponCanCastOnSTrike or weapon.isRanged == false
end

---@param enchantment tes3enchantment
---@param weaponSpeed number
---@param cabCastOnStrike boolean
---@return ScratchData
---@return { [tes3.effect]: string[] }
function CollectEnchantmentEffect(enchantment, weaponSpeed, cabCastOnStrike)
    local data = CreateScratchData()

    local icons = {} ---@type {[tes3.effect]: string[]}

    if enchantment then
        -- todo not yet on cast
        -- todo on strike effect consider charge cost
        local onStrike = cabCastOnStrike and enchantment.castType == tes3.enchantmentType.onStrike
        local constant = enchantment.castType == tes3.enchantmentType.constant
        if onStrike or constant then
            for _, effect in ipairs(enchantment.effects) do
                if effect ~= nil and effect.id >= 0 then
                    local id = effect.id
                    local resolver = resolver[id]
                    if resolver then
                        local value = (effect.max + effect.min) * 0.5 -- uniform RNG average
                        local isSelf = effect.rangeType == tes3.effectRange.self
                        local affect = resolver.func({
                            data = data,
                            key = id,
                            value = value,
                            speed = weaponSpeed,
                            isSelf = isSelf,
                            attacker = resolver.attacker,
                            target = resolver.target,
                            attribute = effect.attribute,
                            skill = effect.skill,
                            constant = constant,
                            equiped = false, -- TODO for constant
                        })
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
        end
    end

    return data, icons
end

---@param weaponDamage number
---@param strengthModifier number
---@param conditionModifier number
---@param criticalHitModifier number
---@param armorReduction number
---@return number
local function CalculateAcculateWeaponDamage(weaponDamage, strengthModifier, conditionModifier, criticalHitModifier,
                                             armorReduction)
    return (weaponDamage * strengthModifier * conditionModifier * criticalHitModifier) / armorReduction
end

---@param hitRate number
---@param evation number
---@return number
local function CalculateChanceToHit(hitRate, evation)
    return math.clamp(hitRate - evation, 0.0, 1.0)
end

-- TODO gmst fCombatArmorMinMult
---@param armorRationg number
---@param damage number
---@return number
local function CalculateDamageReductionFromArmor(armorRationg, damage)
    return math.min(1 + armorRationg / damage, 4.0)
end

-- TODO MCP blid patch
---comment
---@param weaponSkill number
---@param agility number
---@param luck number
---@param fatigueTerm number
---@param fortifyAttack number
---@param blind number
---@return number
local function CalculateHitRate(weaponSkill, agility, luck, fatigueTerm, fortifyAttack, blind)
    return (weaponSkill + (agility * 0.2) + (luck * 0.1)) * fatigueTerm + fortifyAttack + blind
end

---@param agility number
---@param luck number
---@param fatigueTerm number
---@param sanctuary number
---@return number
local function CalculateEvasion(agility, luck, fatigueTerm, sanctuary)
    return ((agility * 0.2) + (luck * 0.1)) * fatigueTerm + math.min(sanctuary, 100)
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
        evasion = CalculateEvasion(agility, luck, fatigueTerm, sanctuary)
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
---@param marksman boolean
---@param accurateDamage boolean
---@return { [tes3.physicalAttackType]: DamageRange }
function DPS.CalculateWeaponDamage(self, weapon, itemData, speed, strength, marksman, accurateDamage)
    local baseDamage = self:GetWeaponBaseDamage(weapon, marksman)
    local damageMultStr = 0
    local damageMultCond = 0
    if accurateDamage then
        damageMultStr = self:GetStrengthModifier(strength)
        damageMultCond = GetConditionModifier(weapon, itemData)
    end
    local minSpeed = speed -- TODO should be quickly, it seems depends animation frame
    local maxSpeed = speed
    for i, v in pairs(baseDamage) do
        if accurateDamage then
            v.min = CalculateAcculateWeaponDamage(v.min, damageMultStr, damageMultCond, 1, 1);
            v.max = CalculateAcculateWeaponDamage(v.max, damageMultStr, damageMultCond, 1, 1);
        end
        v.min = CalculateDPS(v.min, minSpeed)
        v.max = CalculateDPS(v.max, maxSpeed)
    end
    return baseDamage
end

---@param weaponDamages { [tes3.physicalAttackType]: DamageRange }
---@param effect ScratchData
---@param minmaxRange boolean
---@return DamageRange
---@return { [tes3.physicalAttackType] :boolean }
local function ResolveWeaponDPS(weaponDamages, effect, minmaxRange)
    -- highest damages flags
    -- TODO when useBestAttack pick highest average damage
    local range = { min = 0, max = 0 } ---@type DamageRange
    local highestType = {}
    local typeDamages = {}
    local highest = 0
    for k, v in pairs(weaponDamages) do
        range.min = math.max(range.min, v.min)
        range.max = math.max(range.max, v.max)
        local typeDamage = v.max
        if minmaxRange then
            typeDamage = (v.max + v.min) * 0.5 -- use average when display min - max damage range
        end
        highest = math.max(highest, typeDamage)
        typeDamages[k] = typeDamage
        -- TODO apply armor shield modifier
    end
    for k, v in pairs(typeDamages) do
        if highest == v then -- lua can compare float equals?
            highestType[k] = true
        end
    end
    return range, highestType
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
---@param icons { [tes3.effect]: string[] }
---@return number
---@return {[tes3.effect]: number}
local function ResolveEffectDPS(effect, icons)
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
        local h  = GetValue(effect.target.positives, v, 0)
        effectDamages[v] = -h -- display value is negative
        effectTotal = effectTotal - h
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

---@param e Target
---@param a tes3.attribute
---@return number
local function GetAttributeModifier(e, a)
    local v = 0
    if e.fortifyAttributes[a] then
        v = v + e.fortifyAttributes[a]
    end
    if e.restoreAttributes[a] then
        v = v + e.restoreAttributes[a] -- TODO limit current value
    end
    if e.damageAttributes[a] then
        v = v - e.damageAttributes[a]
    end
    if e.drainAttributes[a] then
        v = v - e.drainAttributes[a] -- at once
    end
    return v
end

---@param e Target
---@param s tes3.skill
---@return number
local function GetSkillModifier(e, s)
    local v = 0
    if e.fortifySkills[s] then
        v = v + e.fortifySkills[s]
    end
    if e.restoreSkills[s] then
        v = v + e.restoreSkills[s] -- TODO limit current value
    end
    if e.damageSkills[s] then
        v = v - e.damageSkills[s]
    end
    if e.drainSkills[s] then
        v = v - e.drainSkills[s] -- at once
    end
    return v
end

local function CalculateHitRate_(weapon, effect)
    local skillId = weapon.skillId
    local weaponSkill = math.max(tes3.mobilePlayer:getSkillValue(skillId) + GetSkillModifier(effect.attacker, skillId), 0)
    local agility = math.max(
        tes3.mobilePlayer.agility.current + GetAttributeModifier(effect.attacker, tes3.attribute.agility), 0)
    local luck = math.max(tes3.mobilePlayer.luck.current + GetAttributeModifier(effect.attacker, tes3.attribute.luck), 0)
    -- return CalculateHitRate(weaponSkill, agility, luck, 0, 1, 0, 0)
end

local function CalculateEvasion_(weapon, effect)
end

local function CalculateHit(weapon, effect)
    --return CalculateChanceToHit(hitRate, evasion)
end


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
---@param self DPS
---@param weapon tes3weapon
---@param itemData tes3itemData
---@return DPSData
function DPS.CalculateDPS(self, weapon, itemData)
    -- TODO activeMagicEffectList constantt effect applied
    local useBestAttack = tes3.worldController.useBestAttack -- TODO mock
    local marksman = weapon.isRanged or weapon.isProjectile
    local speed = weapon.speed
    if marksman then
        speed = 1 -- TODO it seems ranged weapon always return 1, but here uses actual speed.
    end
    local effect, icons = CollectEnchantmentEffect(weapon.enchantment, speed, self:CanCastOnStrike(weapon))
    local resistMagicka = tes3.mobilePlayer.resistMagicka
    ResolveModifiers(effect, icons, resistMagicka)
    local strength = tes3.mobilePlayer.strength.current + GetAttributeModifier(effect.attacker, tes3.attribute.strength)
    local weaponDamages = self:CalculateWeaponDamage(weapon, itemData, speed, strength, marksman,
    self.config.accurateDamage)
    local weaponDamageRange, highestType = ResolveWeaponDPS(weaponDamages, effect, self.config.minmaxRange)
    local effectTotal, effectDamages = ResolveEffectDPS(effect, icons)

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
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.fortifyAttributes[params.attribute]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
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
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.damageAttributes[params.attribute]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
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
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.drainAttributes[params.attribute]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
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
            unitwind:expect(affect).toBe(v[1] or v[2])
            if v[1] then
                unitwind:expect(data.target.drainAttributes[params.attribute]).toBe(10)
            end
            if v[2] then
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
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.restoreAttributes[params.attribute]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
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
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.fortifySkills[params.skill]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
            if affect then
                unitwind:expect(data.attacker.fortifySkills[params.skill]).toBe(10)
            end
        end
    end)

    unitwind:test("DamageSkill", function()
        local e = tes3.effect.damageSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.damageSkills[params.skill]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
            if affect then
                unitwind:expect(data.attacker.damageSkills[params.skill]).toBe(20)
            end
        end
    end)

    unitwind:test("DrainSkill", function()
        local e = tes3.effect.drainSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.drainSkills[params.skill]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
            if affect then
                unitwind:expect(data.attacker.drainSkills[params.skill]).toBe(10)
            end
        end
    end)

    unitwind:test("AbsorbSkill", function()
        local e = tes3.effect.absorbSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1] or v[2])
            if v[1] then
                unitwind:expect(data.target.drainSkills[params.skill]).toBe(10)
            end
            if v[2] then
                unitwind:expect(data.attacker.fortifySkills[params.skill]).toBe(10)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(false) -- self absorb is no affect
        end
    end)

    unitwind:test("RestoreSkill", function()
        local e = tes3.effect.restoreSkill
        local r = resolver[e]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:debug(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = e,
                value = 10,
                speed = 2,
                isSelf = false,
                attacker = r.attacker,
                target = r.target,
                skill = k,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(v[1])
            if affect then
                unitwind:expect(data.target.restoreSkills[params.skill]).toBe(20)
            end
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(v[2])
            if affect then
                unitwind:expect(data.attacker.restoreSkills[params.skill]).toBe(20)
            end
        end
    end)
end

return DPS

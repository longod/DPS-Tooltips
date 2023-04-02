local DPS = {}
function DPS.new()
    local dps = {}
    setmetatable(dps, { __index = DPS })
    return dps
end

local shared = require("longod.DPSTooltips.shared")
local logger = require("longod.DPSTooltips.logger")
local config = require("longod.DPSTooltips.config").Load()

-- TODO i think no necessary my original shared index, it was defined for pairing eg. fire damage and resist fire, and display order
-- but more complex eg. resist magicka or others
-- try to use tes3.effect id
-- or tes3.effectAttribute
local function CreateScratchData()
    local data = {
        attacker = {
            positives = {
                [shared.key.magicka] = 0,
                [shared.key.attack] = 0, -- means accuracy
                [shared.key.dispel] = 0,
            },
            negatives = {
                [shared.key.magicka] = 0,
                [shared.key.blind] = 0,
            },
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
            damages = {
                [shared.key.fire] = 0,
                [shared.key.frost] = 0,
                [shared.key.shock] = 0,
                [shared.key.poison] = 0,
                [shared.key.absorbHealth] = 0,
                [shared.key.damageHealth] = 0,
                [shared.key.drainHealth] = 0,
                [shared.key.sunDamage] = 0,
            },
            positives = {
                [shared.key.fire] = 0,
                [shared.key.frost] = 0,
                [shared.key.shock] = 0,
                [shared.key.poison] = 0,
                [shared.key.magicka] = 0,
                [shared.key.shield] = 0,
                [shared.key.normalWeapons] = 0,
                [shared.key.sanctuary] = 0,
                [shared.key.dispel] = 0,
                [shared.key.spellAbsorption] = 1, -- multiply
                [shared.key.reflect] = 1,         -- multiply
            },
            negatives = {
                [shared.key.fire] = 0,
                [shared.key.frost] = 0,
                [shared.key.shock] = 0,
                [shared.key.poison] = 0,
                [shared.key.magicka] = 0,
                [shared.key.normalWeapons] = 0,
            },
            damageAttributes = {},
            damageSkills = {},
            drainAttributes = {},
            drainSkills = {},
            fortifyAttributes = {},
            fortifySkills = {},
            restoreAttributes = {},
            restoreSkills = {},
            restoreHealth = 0,
            fortifyHealth = 0,
        },
    }
    return data
end

-- TODO modifieable for mod
-- {target, attacker}
local attributeFilter = {
    [tes3.attribute.strength] = { false, true },   -- damage
    [tes3.attribute.intelligence] = { false, false },
    [tes3.attribute.willpower] = { true, false },  -- regist
    [tes3.attribute.agility] = { true, true },     -- evade, hit
    [tes3.attribute.speed] = { false, false },     -- TODO weapon swing mod
    [tes3.attribute.endurance] = { false, false }, -- TODO realtime health calculate mod
    [tes3.attribute.personality] = { false, false },
    [tes3.attribute.luck] = { true, true },        -- evade, hit
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

local function IsAffectedAttribute(params)
    local f = attributeFilter[params.attribute]
    if f then
        -- lua: a and b or c idiom is useless when b and c are boolean, it return b or c.
        if params.isSelf then
            return f[2]
        else
            return f[1]
        end
    else
        return false
    end
end

local function IsAffectedSkill(params)
    local f = skillFilter[params.skill]
    if f then
        -- lua: a and b or c idiom is useless when b and c are boolean, it return b or c.
        if params.isSelf then
            return f[2]
        else
            return f[1]
        end
    else
        return false
    end
end

local function CalculateDPS(damage, speed)
    return damage * speed
end

local function DamageHealth(params)
    if params.isSelf then
    else
        params.data.target.damages[params.key] = params.data.target.damages[params.key] +
            CalculateDPS(params.value, params.speed)
        return true
    end
    return false
end

local function DrainHealth(params)
    if params.isSelf then
    else
        params.data.target.damages[params.key] = params.data.target.damages[params.key] + params.value
        return true
    end
    return false
end

local function CurePoison(params)
    if params.isSelf then
    else
        params.data.target.damages[params.key] = 0
        return true
    end
    return false
end

local function RestoreHealth(params)
    if params.isSelf then
        return false
    else
        params.data.target.restoreHealth = params.data.target.restoreHealth + CalculateDPS(params.value, params.speed)
        return true
    end
end

local function FortifyHealth(params)
    if params.isSelf then
        return false
    else
        -- in DPS calculation, same effect sorce income once so just adding,
        -- if simlate total affetion then it consider to stack same effect source
        params.data.target.fortifyHealth = params.data.target.fortifyHealth + params.value
        return true
    end
end

local function PositiveModifier(params)
    if params.isSelf then
        if params.data.attacker.positives[params.key] then
            params.data.attacker.positives[params.key] = params.data.attacker.positives[params.key] + params.value
            return true
        end
    else
        if params.data.target.positives[params.key] then
            params.data.target.positives[params.key] = params.data.target.positives[params.key] + params.value
            return true
        end
    end
    return false
end

local function NegativeModifier(params)
    if params.isSelf then
        if params.data.attacker.negatives[params.key] then
            params.data.attacker.negatives[params.key] = params.data.attacker.negatives[params.key] + params.value
            return true
        end
    else
        if params.data.target.negatives[params.key] then
            params.data.target.negatives[params.key] = params.data.target.negatives[params.key] + params.value
            return true
        end
    end
    return false
end


-- only positive
local function MultModifier(params)
    if params.isSelf then
    else
        if params.data.target.positives[params.key] then
            -- percent
            params.data.target.positives[params.key] = params.data.target.positives[params.key] *
                (1.0 - (params.value * 0.01))
            return true
        end
    end
    return false
end

local function ShieldElement(params)
    if params.isSelf then
        params.data.target.damages[params.key] = params.data.target.damages[params.key] +
            CalculateDPS(params.value * 0.1, params.speed)
    else
        params.data.target.positives[params.key] = params.data.target.positives[params.key] + params.value
    end
    return true
end

local function FortifyAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        -- TODO if player equiped constant effect weapon then skip this.
        local a = params.data.attacker.fortifyAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + params.value
    else
        local a = params.data.target.fortifyAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + params.value
    end
    return true
end

local function DamageAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        local a = params.data.attacker.damageAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + CalculateDPS(params.value, params.speed)
    else
        local a = params.data.target.damageAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + CalculateDPS(params.value, params.speed)
    end
    return true
end

local function DrainAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        -- TODO if player equiped constant effect weapon then skip this.
        local a = params.data.attacker.drainAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + params.value
    else
        local a = params.data.target.drainAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + params.value
    end
    return true
end

local function AbsorbAttribute(params)
    if params.isSelf then
        return false
    else
        local t = DrainAttribute(params)
        params.isSelf = true               -- TODO immutalbe
        local a = FortifyAttribute(params) -- value is applied resist/weakness magicka?
        return t or a
    end
end

local function RestoreAttribute(params)
    if not IsAffectedAttribute(params) then
        return false
    end
    if params.isSelf then
        local a = params.data.attacker.restoreAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + CalculateDPS(params.value, params.speed)
    else
        local a = params.data.target.restoreAttributes
        if not a[params.attribute] then
            a[params.attribute] = 0
        end
        a[params.attribute] = a[params.attribute] + CalculateDPS(params.value, params.speed)
    end
    return true
end

local function FortifySkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        -- TODO if player equiped constant effect weapon then skip this.
        local a = params.data.attacker.fortifySkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + params.value
    else
        local a = params.data.target.fortifySkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + params.value
    end
    return true
end

local function DamageSkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        local a = params.data.attacker.damageSkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + CalculateDPS(params.value, params.speed)
    else
        local a = params.data.target.damageSkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + CalculateDPS(params.value, params.speed)
    end
    return true
end

local function DrainSkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        -- TODO if player equiped constant effect weapon then skip this.
        local a = params.data.attacker.drainSkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + params.value
    else
        local a = params.data.target.drainSkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + params.value
    end
    return true
end

local function AbsorbSkill(params)
    if params.isSelf then
        return false
    else
        local t = DrainSkill(params)
        params.isSelf = true           -- TODO immutable
        local a = FortifySkill(params) -- value is applied resist/weakness magicka?
        return t or a
    end
end

local function RestoreSkill(params)
    if not IsAffectedSkill(params) then
        return false
    end
    if params.isSelf then
        local a = params.data.attacker.restoreSkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + CalculateDPS(params.value, params.speed)
    else
        local a = params.data.target.restoreSkills
        if not a[params.skill] then
            a[params.skill] = 0
        end
        a[params.skill] = a[params.skill] + CalculateDPS(params.value, params.speed)
    end
    return true
end


-- only vanilla
-- todo add config mod efect
local resolver = {
    -- waterBreathing 0
    -- swiftSwim 1
    -- waterWalking 2
    [3] = { func = PositiveModifier, key = shared.key.shield }, -- shield 3
    [4] = { func = ShieldElement, key = shared.key.fire },      -- fireShield 4
    [5] = { func = ShieldElement, key = shared.key.shock },     -- lightningShield 5
    [6] = { func = ShieldElement, key = shared.key.frost },     -- frostShield 6
    -- burden 7
    -- feather 8
    -- jump 9
    -- levitate 10
    -- slowFall 11
    -- lock 12
    -- open 13
    [14] = { func = DamageHealth, key = shared.key.fire },        -- fireDamage 14
    [15] = { func = DamageHealth, key = shared.key.shock },       -- shockDamage 15
    [16] = { func = DamageHealth, key = shared.key.frost },       -- frostDamage 16
    [17] = { func = DrainAttribute, key = shared.key.attribute }, -- drainAttribute 17
    [18] = { func = DrainHealth, key = shared.key.drainHealth },  -- drainHealth 18
    -- drainMagicka 19
    -- drainFatigue 20
    [21] = { func = DrainSkill, key = shared.key.skill },          -- drainSkill 21
    [22] = { func = DamageAttribute, key = shared.key.attribute }, -- damageAttribute 22
    [23] = { func = DamageHealth, key = shared.key.damageHealth }, -- damageHealth 23
    -- damageMagicka 24
    -- damageFatigue 25
    [26] = { func = DamageSkill, key = shared.key.skill },        -- damageSkill 26
    [27] = { func = DamageHealth, key = shared.key.poison },      -- poison 27
    [28] = { func = NegativeModifier, key = shared.key.fire },    -- weaknesstoFire 28
    [29] = { func = NegativeModifier, key = shared.key.frost },   -- weaknesstoFrost 29
    [30] = { func = NegativeModifier, key = shared.key.shock },   -- weaknesstoShock 30
    [31] = { func = NegativeModifier, key = shared.key.magicka }, -- weaknesstoMagicka 31
    -- weaknesstoCommonDisease 32
    -- weaknesstoBlightDisease 33
    -- weaknesstoCorprusDisease 34
    [35] = { func = NegativeModifier, key = shared.key.poison },        -- weaknesstoPoison 35
    [36] = { func = NegativeModifier, key = shared.key.normalWeapons }, -- weaknesstoNormalWeapons 36
    -- disintegrateWeapon 37
    [38] = nil,                                                         -- disintegrateArmor 38
    -- invisibility 39
    -- chameleon 40
    -- light 41
    [42] = { func = PositiveModifier, key = shared.key.sanctuary }, -- sanctuary 42
    -- nightEye 43
    -- charm 44
    -- paralyze 45
    -- silence 46
    [47] = { func = NegativeModifier, key = shared.key.blind }, -- blind 47
    -- sound 48
    -- calmHumanoid 49
    -- calmCreature 50
    -- frenzyHumanoid 51
    -- frenzyCreature 52
    -- demoralizeHumanoid 53
    -- demoralizeCreature 54
    -- rallyHumanoid 55
    -- rallyCreature 56
    [57] = { func = PositiveModifier, key = shared.key.dispel }, -- dispel 57
    -- soultrap 58
    -- telekinesis 59
    -- mark 60
    -- recall 61
    -- divineIntervention 62
    -- almsiviIntervention 63
    -- detectAnimal 64
    -- detectEnchantment 65
    -- detectKey 66
    [67] = { func = MultModifier, key = shared.key.spellAbsorption }, -- spellAbsorption 67
    [68] = { func = MultModifier, key = shared.key.reflect },         -- reflect 68
    -- cureCommonDisease 69
    -- cureBlightDisease 70
    -- cureCorprusDisease 71
    [72] = { func = CurePoison, key = shared.key.poison },          -- curePoison 72
    -- cureParalyzation 73
    [74] = { func = RestoreAttribute, key = shared.key.attribute }, -- restoreAttribute 74
    [75] = { func = RestoreHealth, key = shared.key.health },       -- restoreHealth 75
    -- restoreMagicka 76
    -- restoreFatigue 77
    [78] = { func = RestoreSkill, key = shared.key.skill },         -- restoreSkill 78
    [79] = { func = FortifyAttribute, key = shared.key.attribute }, -- fortifyAttribute 79
    [80] = { func = FortifyHealth, key = shared.key.health },       -- fortifyHealth 80
    -- fortifyMagicka 81
    -- fortifyFatigue 82
    [83] = { func = FortifySkill, key = shared.key.skill },        -- fortifySkill 83
    -- fortifyMaximumMagicka 84
    [85] = { func = AbsorbAttribute, key = shared.key.attribute }, -- absorbAttribute 85
    [86] = { func = DamageHealth, key = shared.key.absorbHealth }, -- absorbHealth 86
    -- absorbMagicka 87
    -- absorbFatigue 88
    [89] = { func = AbsorbSkill, key = shared.key.skill },        -- absorbSkill 89
    [90] = { func = PositiveModifier, key = shared.key.fire },    -- resistFire 90
    [91] = { func = PositiveModifier, key = shared.key.frost },   -- resistFrost 91
    [92] = { func = PositiveModifier, key = shared.key.shock },   -- resistShock 92
    [93] = { func = PositiveModifier, key = shared.key.magicka }, -- resistMagicka 93
    -- resistCommonDisease 94
    -- resistBlightDisease 95
    -- resistCorprusDisease 96
    [97] = { func = PositiveModifier, key = shared.key.poison },        -- resistPoison 97
    [98] = { func = PositiveModifier, key = shared.key.normalWeapons }, -- resistNormalWeapons 98
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
    [117] = { func = PositiveModifier, key = shared.key.attack }, -- fortifyAttack 117
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
    [135] = { func = DamageHealth, key = shared.key.sunDamage }, -- sunDamage 135
    -- stuntedMagicka 136
    -- summonFabricant 137
    -- callWolf 138
    -- callBear 139
    -- summonBonewolf 140
    -- sEffectSummonCreature04 141
    -- sEffectSummonCreature05 142
}

function DPS.Initialize(self)
    -- resolve MCP or mod
    self.strengthBase = 0.5
    self.strengthMultiply = 0.01
    -- This MCP feature causes the game to use these GMSTs in its weapon damage calculations instead of the hardcoded
    -- values used by the vanilla game. With default values for the GMSTs the outcome is the same.
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.gameFormulaRestoration) then
        -- maybe require restart when to get initialing
        logger:info("MCP: GameFormulaRestoration")
        self.strengthBase = tes3.findGMST(tes3.gmst.fDamageStrengthBase).value
        self.strengthMultiply = 0.1 * tes3.findGMST(tes3.gmst.fDamageStrengthMult).value
    end

    self.rangedWeaponCanCastOnSTrike = false
    if tes3.isModActive("Cast on Strike Bows.esp") then
        -- this MCP fix seems, deny on strile option when enchaning, exsisting ranged weapons on strike dont require this fix to torigger.
        -- ~tes3.hasCodePatchFeature(tes3.codePatchFeature.fixEnchantOptionsOnRanged)
        logger:info("ESP: Cast on Strike Bows")
        self.rangedWeaponCanCastOnSTrike = true
    end

    -- The vanilla game doubles the official damage values for thrown weapons. The mod Thrown Projectiles Revamped
    -- halves the actual damage done, so don't double the displayed damage if that mod is in use.
    self.throwWeaponAlreadyModified = false
    if tes3.isLuaModActive("DQ.ThroProjRev") then
        logger:info("MWSE: Thrown Projectiles Revamped")
        self.throwWeaponAlreadyModified = true
    end

    -- todo poison crafting
end

function DPS.CanCastOnStrike(self, weapon)
    return self.rangedWeaponCanCastOnSTrike or weapon.isRanged == false
end

function DPS.CollectEnchantmentEffect(self, enchantment, weaponSpeed, cabCastOnStrike)
    local data = CreateScratchData()

    local icons = {}

    -- todo If there is a mod that allows NPC endurance to change HP in real-time, then endurance modifier needs to be tracked as well.
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
                            key = resolver.key,
                            value = value,
                            speed = weaponSpeed,
                            isSelf = isSelf,
                            attribute = effect.attribute, -- not convert id
                            skill = effect.skill,         -- not convert id
                            constant = constant,
                            equiped = false,              -- TODO for constant
                        })
                        if affect and resolver.key then
                            -- adding own key, then merge on resolve phase
                            if not icons[resolver.key] then
                                icons[resolver.key] = {}
                            end
                            table.insert(icons[resolver.key], effect.object.icon) -- todo skip contained if you want
                        end
                    end
                end
            end
        end
    end

    return data, icons
end

local function CalculateAcculateWeaponDamage(weaponDamage, strengthModifier, conditionModifier, criticalHitModifier,
                                             armorReduction)
    return (weaponDamage * strengthModifier * conditionModifier * criticalHitModifier) / armorReduction
end

local function CalculateChanceToHit(hitRate, evation)
    return math.clamp(hitRate - evation, 0.0, 1.0)
end

-- gmst exists?
local function CalculateDamageReductionFromArmor(armorRationg, damage)
    return math.min(1 + armorRationg / damage, 4.0)
end

-- gmst exists?
-- TODO MCP blid patch
local function CalculateHitRate(weaponSkill, agility, luck, currentFatigue, maximumFatigue, fortifyAttackMagnitude,
                                blindMagnitude)
    return (weaponSkill + (agility / 5) + (luck / 10)) * (0.75 + 0.5 * currentFatigue / maximumFatigue) +
        fortifyAttackMagnitude + blindMagnitude
end

-- gmst exists?
local function CalculateEvasion(agility, luck, currentFatigue, currentFatigue, maximumFatigue, sanctuaryMagnitude)
    return ((agility / 5.0) + (luck / 10.0)) * (0.75 + 0.5 * currentFatigue / maximumFatigue) + sanctuaryMagnitude
end

-- from Accurate Tooltip Stats (https://www.nexusmods.com/morrowind/mods/51354) by Necrolesian
local function GetConditionModifier(weapon, itemData)
    -- Projectiles (thrown weapons, arrows, bolts) have no condition data.
    local hasDurability = weapon.hasDurability
    local maximumCondition = (hasDurability and weapon.maxCondition) or 1
    local currentCondition = (hasDurability and itemData and itemData.condition) or maximumCondition
    return currentCondition / maximumCondition
end

-- from Accurate Tooltip Stats (https://www.nexusmods.com/morrowind/mods/51354) by Necrolesian
function DPS.GetStrengthModifier(self, strengthModifier)
     -- how capped value without mcp patch?
     local currentStrength = math.max(tes3.mobilePlayer.strength.current + strengthModifier, 0)
    -- resolved base and mult on initialize
    return self.strengthBase + (self.strengthMultiply * currentStrength)
end

-- from Accurate Tooltip Stats (https://www.nexusmods.com/morrowind/mods/51354) by Necrolesian
function DPS.GetWeaponBaseDamage(self, weapon, marksman)
    local baseDamage = {}
    if marksman then
        baseDamage[shared.key.attack] = { min = weapon.chopMin, max = weapon.chopMax }
    else
        baseDamage[shared.key.slash] = { min = weapon.slashMin, max = weapon.slashMax }
        baseDamage[shared.key.thrust] = { min = weapon.thrustMin, max = weapon.thrustMax }
        baseDamage[shared.key.chop] = { min = weapon.chopMin, max = weapon.chopMax }
    end

    -- The vanilla game doubles the official damage values for thrown weapons. The mod Thrown Projectiles Revamped
    -- halves the actual damage done, so don't double the displayed damage if that mod is in use.
    if weapon.type == tes3.weaponType.marksmanThrown and not self.throwWeaponAlreadyModified then
        baseDamage[shared.key.attack].min = 2 * baseDamage[shared.key.attack].min
        baseDamage[shared.key.attack].max = 2 * baseDamage[shared.key.attack].max
    end

    return baseDamage
end

function DPS.CalculateWeaponDamage(self, weapon, itemData, speed, strengthModifier, marksman, accurateDamage)
    local baseDamage = self:GetWeaponBaseDamage(weapon, marksman)
    local damageMultStr = 0
    local damageMultCond = 0
    if accurateDamage then
        damageMultStr = self:GetStrengthModifier(strengthModifier)
        damageMultCond = GetConditionModifier(weapon, itemData)
    end
    local minSpeed = speed -- TODO must be quickly, how?
    for i, v in pairs(baseDamage) do
        if accurateDamage then
            v.min = CalculateAcculateWeaponDamage(v.min, damageMultStr, damageMultCond, 1, 1);
            v.max = CalculateAcculateWeaponDamage(v.max, damageMultStr, damageMultCond, 1, 1);
        end
        v.min = CalculateDPS(v.min, minSpeed)
        v.max = CalculateDPS(v.max, speed)
    end
    return baseDamage
end

-- FIXME resist magicka affects weakness elemental effects, but it does not affect positive effects.
-- therefore, split positive and negative modifiers

local function ResolveWeaponDPS(weaponDamages, effect)
    -- highest damages flags
    -- TODO when useBestAttack pick highest average damage
    local range = { min = 0, max = 0 }
    local highestType = {}
    local typeDamages = {}
    local highest = 0
    for k, v in pairs(weaponDamages) do
        range.min = math.max(range.min, v.min)
        range.max = math.max(range.max, v.max)
        local typeDamage = v.max
        if config.minmaxRange then
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

-- todo testable
local function ResolveEffectDPS(effect, icons)
    -- effect
    -- damages - modifiers pairs
    -- tes3.effectAttribute
    local pair = {
        [shared.key.fire] = shared.key.fire,
        [shared.key.frost] = shared.key.frost,
        [shared.key.shock] = shared.key.shock,
        [shared.key.poison] = shared.key.poison,
        [shared.key.absorbHealth] = shared.key.magicka,
        [shared.key.damageHealth] = shared.key.magicka, -- ?
    }
    local effectDamages = {}
    local effectTotal = 0
    for k, v in pairs(pair) do
        -- correct?
        -- needs clamping? timing is here or per effect add/sub?
        effectDamages[k] = effect.target.damages[k]
        -- * (math.max(100.0 - effect.target.negatives[v] + effect.target.positives[v], 0.0) / 100.0)
        effectTotal = effectTotal + effectDamages[k]

        -- merge icons if different between k and v
        if k ~= v and icons[v] then
            if not icons[k] then
                icons[k] = {}
            end
            for _, path in ipairs(icons[v]) do
                table.insert(icons[k], path)
            end
        end
    end
    return effectTotal, effectDamages
end

-- FIXME resist magicka affects weakness elemental effects, but it does not affect positive effects.
-- therefore, split positive and negative modifiers

local function ResolveModifiers(effect, resistMagicka)
    effect.target.resists = {}
    effect.attacker.resists = {}
    -- resist/weakness magicka
    local magicka = shared.key.magicka
    -- Once Resist Magicka reaches 100%, it's the only type of resistance that can't be broken by a Weakness effect, since Weakness is itself a magicka type spell.
    -- so if both apply, above works?
    local t = math.max(100.0 - effect.target.positives[magicka], 0) / 100.0
    t = (math.max(100.0 + effect.target.negatives[magicka], 0) / 100.0) * t
    local a = math.max(100.0 - - resistMagicka - effect.attacker.positives[magicka], 0) / 100.0
    a = (math.max(100.0 - effect.attacker.negatives[magicka], 0) / 100.0) * a
    effect.target.resists[magicka] = t
    effect.attacker.resists[magicka] = a
    -- apply resist magicka to negative effects
    for k, v in pairs(effect.target.negatives) do
        if k ~= shared.key.magicka then
            effect.target.negatives[k] = v * t
        end
    end
    for k, v in pairs(effect.attacker.negatives) do
        if k ~= shared.key.magicka then
            effect.attacker.negatives[k] = v * a
        end
    end
    -- resist/weakness elemental
    effect.target.resists[shared.key.fire] = math.max(100.0 - effect.target.positives[shared.key.fire] + effect.target.negatives[shared.key.fire], 0) / 100.0
    effect.target.resists[shared.key.frost] = math.max(100.0 - effect.target.positives[shared.key.frost] + effect.target.negatives[shared.key.frost], 0) / 100.0
    effect.target.resists[shared.key.shock] = math.max(100.0 - effect.target.positives[shared.key.shock] + effect.target.negatives[shared.key.shock], 0) / 100.0
    effect.target.resists[shared.key.poison] = math.max(100.0 - effect.target.positives[shared.key.poison] + effect.target.negatives[shared.key.poison], 0) / 100.0
    effect.target.resists[shared.key.normalWeapons] = math.max(100.0 - effect.target.positives[shared.key.normalWeapons] + effect.target.negatives[shared.key.normalWeapons], 0) / 100.0

    -- apply other modifiers
    local e = effect.target
    -- resist damage
    local pair = {
        [shared.key.fire] = shared.key.fire,
        [shared.key.frost] = shared.key.frost,
        [shared.key.shock] = shared.key.shock,
        [shared.key.poison] = shared.key.poison,
        [shared.key.absorbHealth] = shared.key.magicka,
        [shared.key.damageHealth] = shared.key.magicka,
    }
    for k, v in pairs(pair) do
        e.damages[k] = e.damages[k] * e.resists[v]
    end

    -- attrib, skill
    for k, v in pairs(e.damageAttributes) do
        e.damageAttributes[k] = v * t
    end
    for k, v in pairs(e.drainAttributes) do
        e.damageAttributes[k] = v * t
    end
    for k, v in pairs(e.damageSkills) do
        e.damageAttributes[k] = v * t
    end
    for k, v in pairs(e.drainSkills) do
        e.damageAttributes[k] = v * t
    end
    -- TODO function
    e = effect.attacker
    for k, v in pairs(e.damageAttributes) do
        e.damageAttributes[k] = v * t
    end
    for k, v in pairs(e.drainAttributes) do
        e.damageAttributes[k] = v * t
    end
    for k, v in pairs(e.damageSkills) do
        e.damageAttributes[k] = v * t
    end
    for k, v in pairs(e.drainSkills) do
        e.damageAttributes[k] = v * t
    end

end

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


-- I'm not sure how to resolve Morrowind's effect strictly.
-- If it was to apply them in order from the top, each time, then when the order is Damage, Weakness, so Weakness would have no effect at all.
-- It is indeed possible to do so, but here it resolves all modifiers once and then apply them.
function DPS.CalculateDPS(self, weapon, itemData)
    local useBestAttack = tes3.worldController.useBestAttack
    local marksman = weapon.isMelee == false
    local speed = weapon.speed
    if marksman then
        speed = 1 -- TODO it seems ranged weapon always return 1, but here uses actual speed.
    end
    local effect, icons = self:CollectEnchantmentEffect(weapon.enchantment, speed, self:CanCastOnStrike(weapon))
    local resistMagicka = tes3.mobilePlayer.resistMagicka
    ResolveModifiers(effect, resistMagicka)
    local str = GetAttributeModifier(effect.attacker, tes3.attribute.strength)
    local weaponDamages = self:CalculateWeaponDamage(weapon, itemData, speed, str, marksman, config.accurateDamage)
    local weaponDamageRange, highestType = ResolveWeaponDPS(weaponDamages, effect)
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

-- for local function test
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
            -- logger:trace(tostring(v))
            local r = resolver[v]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.drainHealth]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        local params = {
            data = data,
            key = r.key,
            value = 10,
            speed = 2,
            isSelf = false,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.damages[params.key]).toBe(10)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("CurePoison", function()
        local r = resolver[tes3.effect.poison]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        local params = {
            data = data,
            key = r.key,
            value = 10,
            speed = 2,
            isSelf = false,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.damages[params.key]).toBe(20)

        r = resolver[tes3.effect.curePoison]
        unitwind:expect(r).NOT.toBe(nil)
        params.key = r.key
        affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.damages[params.key]).toBe(0)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("RestoreHealth", function()
        local r = resolver[tes3.effect.restoreHealth]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        local params = {
            data = data,
            key = r.key,
            value = 10,
            speed = 2,
            isSelf = false,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.restoreHealth).toBe(20)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("FortifyHealth", function()
        local r = resolver[tes3.effect.fortifyHealth]
        unitwind:expect(r).NOT.toBe(nil)
        local data = CreateScratchData()
        local params = {
            data = data,
            key = r.key,
            value = 10,
            speed = 2,
            isSelf = false,
        }
        local affect = r.func(params)
        unitwind:expect(affect).toBe(true)
        unitwind:expect(data.target.fortifyHealth).toBe(10)
        params.isSelf = true
        affect = r.func(params)
        unitwind:expect(affect).toBe(false)
    end)

    unitwind:test("PositiveModifier", function()
        local e = {
            [tes3.effect.shield] = { true, false },
            [tes3.effect.sanctuary] = { true, false },
            [tes3.effect.dispel] = { true, true },
            [tes3.effect.resistFire] = { true, false },
            [tes3.effect.resistFrost] = { true, false },
            [tes3.effect.resistShock] = { true, false },
            [tes3.effect.resistMagicka] = { true, true },
            [tes3.effect.resistPoison] = { true, false },
            [tes3.effect.resistNormalWeapons] = { true, false },
            [tes3.effect.fortifyAttack] = { false, true },
        }
        for k, v in pairs(e) do
            -- logger:trace(tostring(k))
            local r = resolver[k]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
            -- logger:trace(tostring(k))
            local r = resolver[k]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
            -- logger:trace(tostring(k))
            local r = resolver[v]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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

    unitwind:test("ShieldElement", function()
        local e = {
            tes3.effect.fireShield,
            tes3.effect.lightningShield,
            tes3.effect.frostShield,
        }
        for _, v in ipairs(e) do
            -- logger:trace(tostring(v))
            local r = resolver[v]
            unitwind:expect(r).NOT.toBe(nil)
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
            }
            local affect = r.func(params)
            unitwind:expect(affect).toBe(true)
            unitwind:expect(data.target.positives[params.key]).toBe(10)
            params.isSelf = true
            affect = r.func(params)
            unitwind:expect(affect).toBe(true)
            unitwind:expect(data.target.damages[params.key]).toBe(2)
        end
    end)

    unitwind:test("FortifyAttribute", function()
        local r = resolver[tes3.effect.fortifyAttribute]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in pairs(attributeFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.damageAttribute]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.drainAttribute]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.absorbAttribute]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.restoreAttribute]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(attributeFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.fortifySkill]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.damageSkill]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.drainSkill]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.absorbSkill]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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
        local r = resolver[tes3.effect.restoreSkill]
        unitwind:expect(r).NOT.toBe(nil)
        for k, v in ipairs(skillFilter) do
            -- logger:trace(tostring(k))
            local data = CreateScratchData()
            local params = {
                data = data,
                key = r.key,
                value = 10,
                speed = 2,
                isSelf = false,
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

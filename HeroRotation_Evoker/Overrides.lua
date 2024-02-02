--- ============================ HEADER ============================
-- HeroLib
local HL      = HeroLib
local Cache   = HeroCache
local Unit    = HL.Unit
local Player  = Unit.Player
local Pet     = Unit.Pet
local Target  = Unit.Target
local Spell   = HL.Spell
local Item    = HL.Item
-- HeroRotation
local HR      = HeroRotation
-- Spells
local SpellDeva = Spell.Evoker.Devastation
local SpellAug  = Spell.Evoker.Augmentation
-- Lua
-- API
local GetPowerRegenForPowerType = GetPowerRegenForPowerType
local EssencePowerType = Enum.PowerType.Essence

--- ============================ CONTENT ============================
-- Devastation, ID: 1467
local DevOldIsCastable
DevOldIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DevOldIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellDeva.Firestorm then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellDeva.TipTheScales then
      return BaseCheck and not Player:BuffUp(self)
    else
      return BaseCheck
    end
  end
, 1467)

local DevOldIsMoving
DevOldIsMoving = HL.AddCoreOverride ("Player.IsMoving",
  function(self)
    local BaseCheck = DevOldIsMoving(self)
    return BaseCheck and Player:BuffDown(SpellDeva.HoverBuff) and Player:BuffDown(SpellDeva.BurnoutBuff)
  end
, 1467)

HL.AddCoreOverride ("Player.EssenceTimeToMax",
  function()
    local Deficit = Player:EssenceDeficit()
    if Deficit == 0 then return 0; end
    local Regen = GetPowerRegenForPowerType(EssencePowerType)
    if not Regen or Regen < 0.2 then Regen = 0.2; end
    local TimeToOneEssence = 1 / Regen
    local LastUpdate = Cache.Persistent.Player.LastPowerUpdate
    return Deficit * TimeToOneEssence - (GetTime() - LastUpdate)
  end
, 1467)

HL.AddCoreOverride ("Player.EssenceTimeToX",
  function(Amount)
    local Essence = Player:Essence()
    if Essence >= Amount then return 0; end
    local Regen = GetPowerRegenForPowerType(EssencePowerType)
    local TimeToOneEssence = 1 / Regen
    local LastUpdate = Cache.Persistent.Player.LastPowerUpdate
    return ((Amount - Essence) * TimeToOneEssence) - (GetTime() - LastUpdate)
  end
, 1467)

-- Preservation, ID: 1468

-- Augmentation, ID: 1473
local AugOldIsCastable
AugOldIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = AugOldIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellAug.TipTheScales or self == SpellAug.Upheaval or self == SpellAug.FireBreath then
      return BaseCheck and not Player:BuffUp(self)
    else
      return BaseCheck
    end
  end
, 1473)

local AugOldIsReady
AugOldIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = AugOldIsReady(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if Player:BuffUp(SpellAug.HoverBuff) then
      local _, SpellMissingResource = self:IsUsable()
      BaseCheck = self:IsCastable() and not SpellMissingResource
    end
    if self == SpellAug.Eruption then
      return BaseCheck and Player:EssenceP() >= 2
    elseif self == SpellAug.EbonMight then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellAug.Unravel then
      return BaseCheck and Target:EnemyAbsorb()
    else
      return BaseCheck
    end
  end
, 1473)

local AugOldIsMoving
AugOldIsMoving = HL.AddCoreOverride ("Player.IsMoving",
  function(self)
    local BaseCheck = AugOldIsMoving(self)
    return BaseCheck and Player:BuffDown(SpellAug.HoverBuff)
  end
, 1473)

local AugOldBuffRemains
AugOldBuffRemains = HL.AddCoreOverride ("Player.BuffRemains",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellAug.EbonMightSelfBuff then
      return self:IsCasting(SpellAug.EbonMight) and 10 or AugOldBuffRemains(self, Spell, AnyCaster, Offset)
    else
      return AugOldBuffRemains(self, Spell, AnyCaster, Offset)
    end
  end
, 1473)

HL.AddCoreOverride ("Player.EmpowerCastTime",
  function(self, stage)
    local Haste = Player:SpellHaste()
    local FoMEmpowerMod = (SpellAug.FontofMagic:IsAvailable()) and 0.8 or 1
    local MaxEmpower = (SpellAug.FontofMagic:IsAvailable()) and 4 or 3
    if not stage then stage = MaxEmpower end
    return ((1 + 0.75 * (stage - 1)) * Haste * FoMEmpowerMod)
  end
, 1473)

HL.AddCoreOverride ("Player.EssenceP",
  function()
    local Essence = Player:Essence()
    if (not Player:IsCasting()) and not Player:IsChanneling() then
      return Essence
    else
      if Player:IsCasting(SpellAug.Eruption) and Player:BuffDown(SpellAug.EssenceBurstBuff) then
        return Essence - 2
      else
        return Essence
      end
    end
  end
, 1473)

HL.AddCoreOverride ("Player.EssenceTimeToMax",
  function()
    local Deficit = Player:EssenceDeficit()
    if Deficit == 0 then return 0; end
    local Regen = GetPowerRegenForPowerType(EssencePowerType)
    if not Regen or Regen < 0.2 then Regen = 0.2; end
    local TimeToOneEssence = 1 / Regen
    local LastUpdate = Cache.Persistent.Player.LastPowerUpdate
    return Deficit * TimeToOneEssence - (GetTime() - LastUpdate)
  end
, 1473)

HL.AddCoreOverride ("Player.EssenceTimeToX",
  function(Amount)
    local Essence = Player:Essence()
    if Essence >= Amount then return 0; end
    local Regen = GetPowerRegenForPowerType(EssencePowerType)
    local TimeToOneEssence = 1 / Regen
    local LastUpdate = Cache.Persistent.Player.LastPowerUpdate
    return ((Amount - Essence) * TimeToOneEssence) - (GetTime() - LastUpdate)
  end
, 1473)

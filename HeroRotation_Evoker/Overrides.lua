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

-- Preservation, ID: ????

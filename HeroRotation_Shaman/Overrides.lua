--- ============================ HEADER ============================
-- HeroLib
local HL       = HeroLib
local Cache    = HeroCache
local Unit     = HL.Unit
local Player   = Unit.Player
local Pet      = Unit.Pet
local Target   = Unit.Target
local Spell    = HL.Spell
local Item     = HL.Item
-- HeroRotation
local HR       = HeroRotation
-- Spells
local SpellEle = Spell.Shaman.Elemental
local SpellEnh = Spell.Shaman.Enhancement
-- Lua
local Enum     = Enum
-- Settings
local EleSettings = HR.GUISettings.APL.Shaman.Elemental

--- ============================ CONTENT ============================
-- Elemental, ID: 262
HL.AddCoreOverride("Player.Maelstrom",
  function()
    local Maelstrom = UnitPower("player", Enum.PowerType.Maelstrom)
    if not Player:IsCasting() then
      return Maelstrom
    else
      if Player:IsCasting(SpellEle.ElementalBlast) then
        return Maelstrom + 30
      elseif Player:IsCasting(SpellEle.LightningBolt) then
        return Maelstrom + 8
      elseif Player:IsCasting(SpellEle.LavaBurst) then
        return Maelstrom + 10
      elseif Player:IsCasting(SpellEle.ChainLightning) then
        return Maelstrom + (4 * Target:GetEnemiesInSplashRangeCount(10))
      else
        return Maelstrom
      end
    end
  end
, 262)

local OldEleIsCastable
OldEleIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = OldEleIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local MoveCheck = (not Player:IsMoving() or not EleSettings.ShowMovementSpells)
    if self == SpellEle.Stormkeeper or self == SpellEle.ElementalBlast or self == SpellEle.Icefury then
      return BaseCheck and (not Player:IsCasting(self) and MoveCheck)
    else
      return BaseCheck
    end
  end
, 262)

local OldEleIsReady
OldEleIsReady = HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = OldEleIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local MoveCheck = (not Player:IsMoving() or not EleSettings.ShowMovementSpells)
    if self == SpellEle.LavaBurst then
      return BaseCheck and (not (Player:IsCasting(SpellEle.LavaBurst) and SpellEle.LavaBurst:Charges() == 1)) and (MoveCheck or Player:BuffUp(SpellEle.LavaSurgeBuff))
    elseif self == SpellEle.LightningBolt or self == SpellEle.ChainLightning then
      return BaseCheck and (MoveCheck or Player:BuffUp(SpellEle.StormkeeperBuff))
    elseif self == SpellEle.FlameShock then
      return BaseCheck and ((not SpellEle.PrimordialWave:IsAvailable() or not SpellEle.PrimordialWave:CooldownUp()) and not SpellEle.PrimordialWave:InFlight())
    else
      return BaseCheck
    end
  end
, 262)

-- Enhancement, ID: 263

-- Example (Arcane Mage)
-- HL.AddCoreOverride ("Spell.IsCastableP", 
-- function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
--   if Range then
--     local RangeUnit = ThisUnit or Target
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeUnit:IsInRange( Range, AoESpell )
--   elseif self == SpellArcane.MarkofAluneth then
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and not Player:IsCasting(self)
--   else
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0
--   end
-- end
-- , 62)

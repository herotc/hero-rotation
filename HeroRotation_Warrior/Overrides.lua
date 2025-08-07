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
local Warrior = HR.Commons.Warrior
-- Spells
local SpellFury             = Spell.Warrior.Fury
local SpellArms             = Spell.Warrior.Arms
local SpellProt             = Spell.Warrior.Protection
-- Lua
local GetTime = GetTime

--- ============================ CONTENT ============================
-- Arms, ID: 71
local ArmsOldSpellIsCastable
ArmsOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = ArmsOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellArms.Charge then
      return BaseCheck and (self:Charges() >= 1 and not Target:IsInRange(8) and Target:IsInRange(25))
    else
      return BaseCheck
    end
  end
, 71)

local ArmsOldDebuffUp
ArmsOldDebuffUp = HL.AddCoreOverride ("Unit.DebuffUp",
  function (self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = ArmsOldDebuffUp(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellArms.RavagerDebuff then
      if Warrior.Ravager[self:GUID()] then
        -- Add 0.2s buffer to tick timer.
        return GetTime() - Warrior.Ravager[self:GUID()] < SpellArms.Ravager:TickTime() + 0.2
      else
        return false
      end
    else
      return BaseCheck
    end
  end
, 71)

-- Fury, ID: 72
local FuryOldSpellIsCastable
FuryOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = FuryOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellFury.Charge then
      return BaseCheck and (self:Charges() >= 1 and not Target:IsInRange(8) and Target:IsInRange(25))
    else
      return BaseCheck
    end
  end
, 72)

local FuryOldSpellIsReady
FuryOldSpellIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = FuryOldSpellIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellFury.Rampage then
      if Player:PrevGCDP(1, SpellFury.Bladestorm) then
        return self:IsCastable() and Player:Rage() >= self:Cost()
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 72)

-- Protection, ID: 73
local ProtOldSpellIsCastable
ProtOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = ProtOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellProt.Charge then
      return BaseCheck and (self:Charges() >= 1 and not Target:IsInRange(8))
    elseif self == SpellProt.HeroicThrow or self == SpellProt.TitanicThrow then
      return BaseCheck and (not Target:IsInRange(8))
    elseif self == SpellProt.Avatar then
      return BaseCheck and (Player:BuffDown(SpellProt.AvatarBuff))
    elseif self == SpellProt.Intervene then
      return BaseCheck and (Player:IsInParty() or Player:IsInRaid())
    else
      return BaseCheck
    end
  end
, 73)

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
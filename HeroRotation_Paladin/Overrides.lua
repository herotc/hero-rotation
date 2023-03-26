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
local SpellProt = Spell.Paladin.Protection
-- Lua

--- ============================ CONTENT ============================
-- Holy, ID: 65

-- Protection, ID: 66
ProtPalBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function(self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = ProtPalBuffUp(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellProt.AvengingWrathBuff and SpellProt.Sentinel:IsAvailable() then
      return Player:BuffUp(SpellProt.SentinelBuff)
    else
      return BaseCheck
    end
  end
, 66)

ProtPalBuffRemains = HL.AddCoreOverride("Player.BuffRemains",
  function(self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = ProtPalBuffRemains(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellProt.AvengingWrathBuff and SpellProt.Sentinel:IsAvailable() then
      return Player:BuffRemains(SpellProt.SentinelBuff)
    else
      return BaseCheck
    end
  end
, 66)

ProtPalCDRemains = HL.AddCoreOverride("Spell.CooldownRemains",
  function(self, BypassRecovery)
    local BaseCheck = ProtPalCDRemains(self, BypassRecovery)
    if self == SpellProt.AvengingWrath and SpellProt.Sentinel:IsAvailable() then
      return SpellProt.Sentinel:CooldownRemains()
    else
      return BaseCheck
    end
  end
, 66)

ProtPalIsAvail = HL.AddCoreOverride("Spell.IsAvailable",
  function(self, CheckPet)
    local BaseCheck = ProtPalIsAvail(self, CheckPet)
    if self == SpellProt.AvengingWrath and SpellProt.Sentinel:IsAvailable() then
      return SpellProt.Sentinel:IsAvailable()
    else
      return BaseCheck
    end
  end
, 66)

-- Retribution, ID: 70

-- Example (Arcane Mage)
-- HL.AddCoreOverride ("Spell.IsCastableP",
-- function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
--   if Range then
--     local RangeUnit = ThisUnit or Target;
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeUnit:IsInRange( Range, AoESpell );
--   elseif self == SpellArcane.MarkofAluneth then
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and not Player:IsCasting(self);
--   else
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0;
--   end;
-- end
-- , 62);
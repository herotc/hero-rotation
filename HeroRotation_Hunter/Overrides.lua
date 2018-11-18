--- ============================ HEADER ============================
  -- HeroLib
  local HL      = HeroLib;
  local Cache   = HeroCache;
  local Unit    = HL.Unit;
  local Player  = Unit.Player;
  local Pet     = Unit.Pet;
  local Target  = Unit.Target;
  local Spell   = HL.Spell;
  local Item    = HL.Item;
-- HeroRotation
  local HR      = HeroRotation;
-- Spells
  local SpellBM = Spell.Hunter.BeastMastery;
  local SpellMM = Spell.Hunter.Marksmanship;
  local SpellSV = Spell.Hunter.Survival;
-- Lua

--- ============================ CONTENT ============================
-- Beast Mastery, ID: 253

-- Marksmanship, ID: 254

-- Survival, ID: 255
local OldSVIsCastableP
OldSVIsCastableP = HL.AddCoreOverride("Spell.IsCastableP",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self.SpellID == SpellSV.MongooseBiteNormal.SpellID or self.SpellID == SpellSV.RaptorStrikeNormal.SepllID then
    return OldSVIsCastableP(self, "Melee", AoESpell, ThisUnit, BypassRecovery, Offset)
  else
    local BaseCheck = OldSVIsCastableP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellSV.SummonPet then
      return (not Pet:IsActive()) and BaseCheck
    elseif self == SpellSV.AspectoftheEagle then
      return HR.GUISettings.APL.Hunter.Survival.AspectoftheEagle and BaseCheck
    else
      return BaseCheck
    end
  end
end
, 255);

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

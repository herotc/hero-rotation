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
-- Lua
  local mathmax = math.max;

--- ============================ CONTENT ============================
-- Beast Mastery, ID: 253
local OldBMIsCastableP
OldBMIsCastableP = HL.AddCoreOverride("Spell.IsCastable",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldBMIsCastableP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self == SpellBM.SummonPet then
    return (not Pet:IsActive()) and BaseCheck
  else
    return BaseCheck
  end
end
, 253);

local BMPetBuffRemains
BMPetBuffRemains = HL.AddCoreOverride ("Pet.BuffRemains",
function (self, Spell, AnyCaster, Offset)
  local BaseCheck = BMPetBuffRemains(self, Spell, AnyCaster, Offset)
  -- For short duration pet buffs, if we are in the process of casting an instant spell, fake the duration calculation until we know what it is
  -- This is due to the fact that instant spells don't trigger SPELL_CAST_START and we could have a refresh in progress 50-150ms before we know about it
  if Spell == SpellBM.FrenzyBuff then
    if Player:IsPrevCastPending() then
      return BaseCheck + (GetTime() - Player:GCDStartTime())
    end
  elseif Spell == SpellBM.BeastCleaveBuff then
    -- If the player buff has duration, grab that one instead. It can be applid a few MS earlier due to latency
    BaseCheck = mathmax(BaseCheck, Player:BuffRemains(SpellBM.BeastCleavePlayerBuff))
    if Player:IsPrevCastPending() then
      return BaseCheck + (GetTime() - Player:GCDStartTime())
    end
  end
  return BaseCheck
end
, 253);

-- Marksmanship, ID: 254
local OldMMIsCastableP
OldMMIsCastableP = HL.AddCoreOverride("Spell.IsCastable",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldMMIsCastableP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self == SpellMM.SummonPet then
    return (not Pet:IsActive() and not HR.GUISettings.APL.Hunter.Marksmanship.UseLoneWolf) and BaseCheck
  else
    return BaseCheck
  end
end
, 254);

local OldMMIsReadyP
OldMMIsReadyP = HL.AddCoreOverride("Spell.IsReady",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldMMIsReadyP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self == SpellMM.AimedShot then
    return BaseCheck and (not Player:IsCasting(SpellMM.AimedShot))
  else
    return BaseCheck
  end
end
, 254);

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

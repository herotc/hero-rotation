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
local SpellHavoc              = Spell.DemonHunter.Havoc;
local SpellVengeance          = Spell.DemonHunter.Vengeance;
local RepeatPerformanceDebuff = Spell(304409);
-- Lua

--- ============================ CONTENT ============================
-- Havoc, ID: 577
local OldHavocIsCastableP
OldHavocIsCastableP = HL.AddCoreOverride ("Spell.IsCastableP",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldHavocIsCastableP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if Player:InstanceInfo(8) == 2164 then
    return BaseCheck and (not Player:DebuffP(RepeatPerformanceDebuff) or Player:DebuffP(RepeatPerformanceDebuff) and not Player:PrevGCDP(1, self))
  else
    return BaseCheck
  end
end
, 577);

local OldHavocIsReadyP
OldHavocIsReadyP = HL.AddCoreOverride ("Spell.IsReadyP",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldHavocIsReadyP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if Player:InstanceInfo(8) == 2164 then
    return BaseCheck and (not Player:DebuffP(RepeatPerformanceDebuff) or Player:DebuffP(RepeatPerformanceDebuff) and not Player:PrevGCDP(1, self))
  else
    return BaseCheck
  end
end
, 577);

-- Vengeance, ID: 581
local OldVengIsCastable
OldVengIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldVengIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if Player:InstanceInfo(8) == 2164 then
    return BaseCheck and (not Player:DebuffP(RepeatPerformanceDebuff) or Player:DebuffP(RepeatPerformanceDebuff) and not Player:PrevGCDP(1, self))
  else
    return BaseCheck
  end
end
, 581);

local OldVengIsReady
OldVengIsReady = HL.AddCoreOverride ("Spell.IsReady",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldVengIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if Player:InstanceInfo(8) == 2164 then
    return BaseCheck and (not Player:DebuffP(RepeatPerformanceDebuff) or Player:DebuffP(RepeatPerformanceDebuff) and not Player:PrevGCDP(1, self))
  else
    return BaseCheck
  end
end
, 581);

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

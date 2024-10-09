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
local SpellBlood   = Spell.DeathKnight.Blood
local SpellFrost   = Spell.DeathKnight.Frost
local SpellUnholy  = Spell.DeathKnight.Unholy
-- Lua
local GetTime = GetTime
local next    = next
-- Commons
local DeathKnight = HeroRotation.Commons.DeathKnight

--- ============================ CONTENT ============================
-- Generic

-- Blood, ID: 250
local OldBloodIsCastable
OldBloodIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  local BaseCheck = OldBloodIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellBlood.RaiseDead then
      return (not Pet:IsActive()) and BaseCheck
    else
      return BaseCheck
    end
  end
, 250)

HL.AddCoreOverride("Player.DnDTicking",
  function (self)
    if next(DeathKnight.DnDTable) == nil then return false end
    local Ticking = false
    for TarGUID, LastTick in pairs(DeathKnight.DnDTable) do
      if GetTime() - LastTick < 1.25 then
        Ticking = true
      end
    end
    if Ticking and Player:BuffUp(SpellBlood.DeathAndDecayBuff) then
      return true
    end
    return false
  end
, 250)

HL.AddCoreOverride("Player.BonestormTicking",
  function (self)
    if next(DeathKnight.BonestormTable) == nil then return false end
    for TarGUID, LastTick in pairs(DeathKnight.BonestormTable) do
      if GetTime() - LastTick < 1.25 then
        return true
      end
    end
    return false
  end
, 250)

-- Frost, ID: 251
local OldFrostIsCastable
OldFrostIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = OldFrostIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellFrost.RaiseDead then
      return (not Pet:IsActive()) and BaseCheck
    else
      return BaseCheck
    end
  end
, 251)

-- Unholy, ID: 252
local OldUHIsCastable
OldUHIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = OldUHIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellUnholy.RaiseDead then
      return (not Pet:IsActive()) and BaseCheck
    elseif self == SpellUnholy.DarkTransformation then
      return (Pet:IsActive() and Pet:NPCID() == 26125) and BaseCheck
    else
      return BaseCheck
    end
  end
, 252)

local OldUHIsReady
OldUHIsReady = HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = OldUHIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellUnholy.Epidemic then
      return (SpellUnholy.VirulentPlagueDebuff:AuraActiveCount() > 1) and BaseCheck
    else
      return BaseCheck
    end
  end
, 252)

local OldUHIsAvailable
OldUHIsAvailable = HL.AddCoreOverride("Spell.IsAvailable",
  function (self)
    local BaseCheck = OldUHIsAvailable(self)
    if not HR.CDsON() and (self == SpellUnholy.Apocalypse or self == SpellUnholy.UnholyAssault) then
      return false
    else
      return BaseCheck
    end
  end
, 252)

HL.AddCoreOverride("Player.DnDTicking",
  function (self)
    if next(DeathKnight.DnDTable) == nil then return false end
    local Ticking = false
    for TarGUID, LastTick in pairs(DeathKnight.DnDTable) do
      if GetTime() - LastTick < 1.25 then
        Ticking = true
      end
    end
    if Ticking and Player:BuffUp(SpellUnholy.DeathAndDecayBuff) then
      return true
    end
    return false
  end
, 252)

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

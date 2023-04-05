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
local SpellBM = Spell.Hunter.BeastMastery
local SpellMM = Spell.Hunter.Marksmanship
local SpellSV = Spell.Hunter.Survival
-- Lua
local mathmax = math.max
-- WoW API
local GetTime = GetTime

--- ============================ CONTENT ============================
-- Beast Mastery, ID: 253
local OldBMIsCastable
OldBMIsCastable = HL.AddCoreOverride("Spell.IsCastable",
function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  local BaseCheck = OldBMIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  if self == SpellBM.SummonPet then
    return (not Pet:IsActive()) and (not Pet:IsDeadOrGhost()) and BaseCheck
  elseif self == SpellBM.RevivePet then
    return Pet:IsDeadOrGhost() and BaseCheck
  elseif self == SpellBM.MendPet then
    return (not Pet:IsDeadOrGhost()) and Pet:HealthPercentage() > 0 and Pet:HealthPercentage() <= HR.GUISettings.APL.Hunter.Commons2.MendPetHighHP and BaseCheck
  else
    return BaseCheck
  end
end
, 253)

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
, 253)

-- Marksmanship, ID: 254
local OldMMIsCastable
OldMMIsCastable = HL.AddCoreOverride("Spell.IsCastable",
function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  local BaseCheck = OldMMIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  if self == SpellMM.SummonPet then
    return (not Pet:IsActive()) and (not Pet:IsDeadOrGhost()) and BaseCheck
  else
    return BaseCheck
  end
end
, 254)

local OldMMIsReady
OldMMIsReady = HL.AddCoreOverride("Spell.IsReady",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldMMIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self == SpellMM.AimedShot then
    local ShouldCastAS = ((not Player:IsCasting(SpellMM.AimedShot)) and SpellMM.AimedShot:Charges() == 1 or SpellMM.AimedShot:Charges() > 1)
    if HR.GUISettings.APL.Hunter.Marksmanship.HideAimedWhileMoving then
      return BaseCheck and ShouldCastAS and ((not Player:IsMoving()) or Player:BuffUp(SpellMM.LockandLoadBuff))
    else
      return BaseCheck and ShouldCastAS
    end
  elseif self == SpellMM.WailingArrow then
    return BaseCheck and (not Player:IsCasting(self))
  else
    return BaseCheck
  end
end
, 254)

local OldMMBuffRemains
OldMMBuffRemains = HL.AddCoreOverride("Player.BuffRemains",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMM.TrickShotsBuff and (Player:IsCasting(SpellMM.AimedShot) or Player:IsChanneling(SpellMM.RapidFire)) then
      return 0
    else
      return OldMMBuffRemains(self, Spell, AnyCaster, Offset)
    end
  end
, 254)

local OldMMBuffDown
OldMMBuffDown = HL.AddCoreOverride("Player.BuffDown",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMM.PreciseShotsBuff and Player:IsCasting(SpellMM.AimedShot) then
      return false
    else
      return OldMMBuffDown(self, Spell, AnyCaster, Offset)
    end
  end
, 254)

HL.AddCoreOverride("Player.FocusP",
  function()
    local Focus = Player:Focus() + Player:FocusRemainingCastRegen()
    if not Player:IsCasting() then
      return Focus
    else
      if Player:IsCasting(SpellMM.SteadyShot) then
        return Focus + 10
      elseif Player:IsChanneling(SpellMM.RapidFire) then
        return Focus + 7
      elseif Player:IsCasting(SpellMM.WailingArrow) then
        return Focus - 15
      elseif Player:IsCasting(SpellMM.AimedShot) then
        return Focus - 35
      end
    end
  end
, 254)

-- Survival, ID: 255
local OldSVIsCastable
OldSVIsCastable = HL.AddCoreOverride("Spell.IsCastable",
function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  local BaseCheck = OldSVIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
  if self == SpellSV.SummonPet then
    return (not Pet:IsActive()) and (not Pet:IsDeadOrGhost()) and BaseCheck
  elseif self == SpellSV.RevivePet then
    return Pet:IsDeadOrGhost() and BaseCheck
  elseif self == SpellSV.MendPet then
    return (not Pet:IsDeadOrGhost()) and Pet:HealthPercentage() > 0 and Pet:HealthPercentage() <= HR.GUISettings.APL.Hunter.Commons2.MendPetHighHP and BaseCheck
  elseif self == SpellSV.AspectoftheEagle then
    return HR.GUISettings.APL.Hunter.Survival.AspectOfTheEagle and BaseCheck
  elseif self == SpellSV.Harpoon then
    return (not Target:IsInRange(8)) and BaseCheck
  else
    return BaseCheck
  end
end
, 255)

local OldSVIsReady
OldSVIsReady = HL.AddCoreOverride("Spell.IsReady",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self == SpellSV.MongooseBite or self == SpellSV.RaptorStrike then
    return OldSVIsReady(self, "Melee", AoESpell, ThisUnit, BypassRecovery, Offset)
  else
    local BaseCheck = OldSVIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellSV.Carve or self == SpellSV.Butchery then
      return BaseCheck and (Player:BuffDown(SpellSV.AspectoftheEagle) or Player:BuffUp(SpellSV.AspectoftheEagle) and Target:IsInMeleeRange(8))
    else
      return BaseCheck
    end
  end
end
, 255)

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

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
-- Settings
local Settings = HR.GUISettings.APL.Hunter
-- Hunter Local
local Hunter  = HR.Commons.Hunter
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
    if Hunter.Pet.Status ~= 1 and Pet:IsActive() then Hunter.Pet.Status = 1 end
    return (Hunter.Pet.Status == 0 or Hunter.Pet.Status == 3) and not (Player:IsMounted() or Player:IsInVehicle()) and BaseCheck
  elseif self == SpellBM.RevivePet then
    return (Pet:IsDeadOrGhost() or Hunter.Pet.Status == 2 and Hunter.Pet.FeignGUID == 0) and not (Player:IsMounted() or Player:IsInVehicle()) and BaseCheck
  elseif self == SpellBM.MendPet then
    return Pet:HealthPercentage() > 0 and Pet:HealthPercentage() <= Settings.Commons.MendPetHP and not (Player:IsMounted() or Player:IsInVehicle()) and BaseCheck
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
    return Hunter.Pet.Status == 0 and BaseCheck
  else
    return BaseCheck
  end
end
, 254)

local OldMMIsReady
OldMMIsReady = HL.AddCoreOverride("Spell.IsReady",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  --local BaseCheck = OldMMIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset) and Player:FocusP() >= self:Cost()
  local BaseCheck = self:IsCastable() and self:IsUsable() and Player:FocusP() >= self:Cost()
  if self == SpellMM.AimedShot then
    if Player:IsCasting(self) then return false end
    if Settings.Marksmanship.HideAimedWhileMoving then
      return BaseCheck and SpellMM.AimedShot:Charges() >= 1 and (not Player:IsMoving() or Player:BuffUp(SpellMM.LockandLoadBuff))
    else
      return BaseCheck and SpellMM.AimedShot:Charges() >= 1
    end
  elseif self == SpellMM.WailingArrow then
    return BaseCheck and not Player:IsCasting(self)
  else
    return BaseCheck
  end
end
, 254)

local OldMMBuffUp
OldMMBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMM.LunarStormReadyBuff then
      return Player:BuffDown(SpellMM.LunarStormCDBuff)
    elseif Spell == SpellMM.PreciseShotsBuff then
      -- Note: The TimeSinceLastCast() check is to prevent icon flicker between Aimed Shot cast ending and buff being applied.
      return OldMMBuffUp(self, Spell, AnyCaster, Offset) or Player:IsCasting(SpellMM.AimedShot) or SpellMM.AimedShot:TimeSinceLastCast() < 1
    else
      return OldMMBuffUp(self, Spell, AnyCaster, Offset)
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
    elseif Spell == SpellMM.MovingTargetBuff and Player:IsCasting(SpellMM.AimedShot) then
      return true
    else
      return OldMMBuffDown(self, Spell, AnyCaster, Offset)
    end
  end
, 254)

local OldMMDebuffDown
OldMMDebuffDown = HL.AddCoreOverride("Target.DebuffDown",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMM.SpottersMarkDebuff and Player:IsCasting(SpellMM.AimedShot) then
      return true
    else
      return OldMMDebuffDown(self, Spell, AnyCaster, Offset)
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
        return Focus + 20
      elseif Player:IsChanneling(SpellMM.RapidFire) then
        return Focus + 20
      elseif Player:IsCasting(SpellMM.WailingArrow) then
        return Player:BuffUp(SpellMM.TrueshotBuff) and Focus - 8 or Focus - 15
      elseif Player:IsCasting(SpellMM.AimedShot) then
        return Player:BuffUp(SpellMM.TrueshotBuff) and Focus - 18 or Focus - 35
      else
        return Focus
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
    return Hunter.Pet.Status == 0 and BaseCheck
  elseif self == SpellSV.RevivePet then
    return (Pet:IsDeadOrGhost() or Hunter.Pet.Status == 2) and BaseCheck
  elseif self == SpellSV.MendPet then
    return Pet:HealthPercentage() > 0 and Pet:HealthPercentage() <= Settings.Commons.MendPetHP and BaseCheck
  elseif self == SpellSV.AspectoftheEagle then
    return Settings.Survival.AspectOfTheEagle and BaseCheck
  elseif self == SpellSV.Harpoon then
    return BaseCheck and not Target:IsInRange(8)
  else
    return BaseCheck
  end
end
, 255)

local OldSVIsReady
OldSVIsReady = HL.AddCoreOverride("Spell.IsReady",
function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  local BaseCheck = OldSVIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
  if self == SpellSV.Butchery then
    return BaseCheck and (Player:BuffDown(SpellSV.AspectoftheEagle) or Player:BuffUp(SpellSV.AspectoftheEagle) and Target:IsInMeleeRange(8))
  else
    return BaseCheck
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

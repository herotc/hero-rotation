--- ============================ HEADER ============================
-- HeroLib
local HL             = HeroLib
local Cache          = HeroCache
local Unit           = HL.Unit
local Player         = Unit.Player
local Pet            = Unit.Pet
local Target         = Unit.Target
local Spell          = HL.Spell
local Item           = HL.Item
-- HeroRotation
local HR             = HeroRotation
local DH             = HR.Commons.DemonHunter
-- Spells
local SpellHavoc     = Spell.DemonHunter.Havoc
local SpellVengeance = Spell.DemonHunter.Vengeance
-- Lua
-- WoW API

--- ============================ CONTENT ============================
-- Havoc, ID: 577
local HavocOldSpellIsCastable
HavocOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = HavocOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellHavoc.Metamorphosis then
      local HMIA = HR.GUISettings.APL.DemonHunter.Havoc.HideMetaIfActive
      return BaseCheck and ((HMIA and Player:BuffDown(SpellHavoc.MetamorphosisBuff)) or not HMIA)
    elseif self == SpellHavoc.FelRush then
      return BaseCheck or (Player:BuffUp(SpellHavoc.Glide) and SpellHavoc.FelRush:Charges() >= 1)
    elseif self == SpellHavoc.VengefulRetreat then
      return BaseCheck or (Player:BuffUp(SpellHavoc.Glide) and SpellHavoc.VengefulRetreat:IsLearned() and SpellHavoc.VengefulRetreat:CooldownRemains() < 0.3)
    else
      return BaseCheck
    end
  end
, 577)

-- Vengeance, ID: 581
local VengOldSpellIsCastable
VengOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = VengOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellVengeance.SigilofFlame or self == SpellVengeance.SigilofDoom then
      local SigilPopTime = (SpellVengeance.QuickenedSigils:IsAvailable()) and 1 or 2
      return BaseCheck and (SpellVengeance.SigilofFlame:TimeSinceLastCast() > SigilPopTime and SpellVengeance.SigilofDoom:TimeSinceLastCast() > SigilPopTime)
    elseif self == SpellVengeance.TheHunt then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 581)

HL.AddCoreOverride ("Player.Demonsurge",
  function(self, Buff)
    if Buff == "Hardcast" then
      return SpellVengeance.FelDesolation:IsLearned()
    else
      if DH.Demonsurge[Buff] ~= nil then
        return DH.Demonsurge[Buff]
      else
        return false
      end
    end
  end
, 581)

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

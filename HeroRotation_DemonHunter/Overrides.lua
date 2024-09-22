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
    if self == SpellHavoc.TheHunt then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 577)

HL.AddCoreOverride ("Player.Demonsurge",
  function(self, Buff)
    if DH.Demonsurge[Buff] ~= nil then
      return DH.Demonsurge[Buff]
    else
      return false
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

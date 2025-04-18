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
-- num Helper Function
local num            = HR.Commons.Everyone.num
-- Spells
local SpellHavoc     = Spell.DemonHunter.Havoc
local SpellVengeance = Spell.DemonHunter.Vengeance
-- Lua
-- WoW API

--- ============================ CONTENT ============================
-- Havoc, ID: 577
local HavocOldSpellIsReady
HavocOldSpellIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = HavocOldSpellIsReady(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellHavoc.Annihilation or self == SpellHavoc.DeathSweep then
      return BaseCheck or self:CooldownUp() and Player:BuffUp(SpellHavoc.MetamorphosisBuff) and Player:Fury() > self:Cost()
    else
      return BaseCheck
    end
  end
, 577)

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

local HavocOldBuffUp
HavocOldBuffUp = HL.AddCoreOverride ("Player.BuffUp", 
  function (self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellHavoc.ImmolationAuraBuff then
      return HavocOldBuffUp(self, SpellHavoc.ImmolationAuraBuff1, AnyCaster, BypassRecovery) or HavocOldBuffUp(self, SpellHavoc.ImmolationAuraBuff2, AnyCaster, BypassRecovery) or HavocOldBuffUp(self, SpellHavoc.ImmolationAuraBuff3, AnyCaster, BypassRecovery) or HavocOldBuffUp(self, SpellHavoc.ImmolationAuraBuff4, AnyCaster, BypassRecovery) or HavocOldBuffUp(self, SpellHavoc.ImmolationAuraBuff5, AnyCaster, BypassRecovery)
    else
      return HavocOldBuffUp(self, Spell, AnyCaster, BypassRecovery)
    end
  end
, 577)

local HavocOldBuffStack
HavocOldBuffStack = HL.AddCoreOverride ("Player.BuffStack",
  function (self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellHavoc.ImmolationAuraBuff then
      return num(Player:BuffUp(SpellHavoc.ImmolationAuraBuff1)) + num(Player:BuffUp(SpellHavoc.ImmolationAuraBuff2)) + num(Player:BuffUp(SpellHavoc.ImmolationAuraBuff3)) + num(Player:BuffUp(SpellHavoc.ImmolationAuraBuff4)) + num(Player:BuffUp(SpellHavoc.ImmolationAuraBuff5))
    else
      return HavocOldBuffStack(self, Spell, AnyCaster, BypassRecovery)
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

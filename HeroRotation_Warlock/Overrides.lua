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
local Warlock = HR.Commons.Warlock
-- Spells
local SpellAffli   = Spell.Warlock.Affliction
local SpellDemo    = Spell.Warlock.Demonology
local SpellDestro  = Spell.Warlock.Destruction
-- Lua
local min     = math.min
local max     = math.max
local floor   = math.floor
local GetTime = GetTime
-- Settings
local Settings = {
  Commons = HR.GUISettings.APL.Warlock.Commons
}

--SpellAffli.AbsoluteCorruption = Spell(196103)
--SpellAffli.Haunt:RegisterInFlight()
--- ============================ CONTENT ============================
-- Affliction, ID: 265
HL.AddCoreOverride ("Player.SoulShardsP",
  function ()
    local Shard = Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(SpellAffli.MaleficRapture) or Player:IsCasting(SpellAffli.SeedofCorruption)
        or Player:IsCasting(SpellAffli.VileTaint) or Player:IsCasting(SpellAffli.SummonPet) then
        return Shard - 1
      else
        return Shard
      end
    end
  end
  , 265)
  
local AffOldSpellIsCastable
AffOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = AffOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellAffli.SummonPet then
      return BaseCheck and (not Settings.Commons.HidePetSummon) and Player:SoulShardsP() > 0 and (not Player:IsCasting(self)) and not (Pet:IsActive() or Player:BuffUp(SpellAffli.GrimoireofSacrificeBuff))
    elseif self == SpellAffli.GrimoireofSacrifice then
      return BaseCheck and Player:BuffDown(SpellAffli.GrimoireofSacrificeBuff)
    else
      return BaseCheck
    end
  end
, 265)

local AffOldSpellIsReady
AffOldSpellIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = AffOldSpellIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellAffli.VileTaint or self == SpellAffli.SoulRot then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellAffli.UnstableAffliction then
      local UAUnit = SpellAffli.UnstableAfflictionDebuff:AuraActiveUnits()[1]
      local UARemains = 0
      local Pandemic = SpellAffli.CreepingDeath:IsAvailable() and 5.4 or 6.3
      if UAUnit then
        UARemains = UAUnit:DebuffRemains(SpellAffli.UnstableAfflictionDebuff)
      end
      return BaseCheck and UARemains < Pandemic and not Player:IsCasting(self)
    elseif self == SpellAffli.SeedofCorruption or self == SpellAffli.Haunt then
      return BaseCheck and not Player:IsCasting(self) and not self:InFlight()
    elseif self == SpellAffli.MaleficRapture then
      return BaseCheck and Player:SoulShardsP() > 0 and (Target:DebuffUp(SpellAffli.CorruptionDebuff) or Target:DebuffUp(SpellAffli.WitherDebuff) or Target:DebuffUp(SpellAffli.AgonyDebuff) or Target:DebuffUp(SpellAffli.UnstableAfflictionDebuff) or Target:DebuffUp(SpellAffli.SiphonLifeDebuff) or Target:DebuffUp(SpellAffli.HauntDebuff) or Target:DebuffUp(SpellAffli.SoulRotDebuff) or Target:DebuffUp(SpellAffli.VileTaintDebuff))
    else
      return BaseCheck
    end
  end
, 265)

local AffOldSpellIsAvailable
AffOldSpellIsAvailable = HL.AddCoreOverride ("Spell.IsAvailable",
  function (self, CheckPet)
    local BaseCheck = AffOldSpellIsAvailable(self, CheckPet)
    if self == SpellAffli.Wither then
      return self:IsLearned()
    else
      return BaseCheck
    end
  end
, 265)

local AffOldBuffUp
AffOldBuffUp = HL.AddCoreOverride ("Player.BuffUp",
  function (self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = AffOldBuffUp(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellAffli.SoulRot then
      return Warlock.SoulRotBuffUp
    else
      return BaseCheck
    end
  end
, 265)

local AffOldBuffRemains
AffOldBuffRemains = HL.AddCoreOverride ("Player.BuffRemains",
  function (self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = AffOldBuffRemains(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellAffli.SoulRot then
      if not Warlock.SoulRotBuffUp then return 0 end
      --local SoulRotBuffLength = (Player:HasTier(31, 2)) and 12 or 8
      -- Note: Appears the 2pc is currently bugged. Buff is removed after 8 seconds regardless.
      local SoulRotBuffLength = 8
      local Remains = SoulRotBuffLength - (GetTime() - Warlock.SoulRotAppliedTime)
      return (Remains > 0) and Remains or 0
    else
      return BaseCheck
    end
  end
, 265)

local AffOldDebuffUp
AffOldDebuffUp = HL.AddCoreOverride ("Target.DebuffUp",
  function (self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = AffOldDebuffUp(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellAffli.UnstableAfflictionDebuff then
      return BaseCheck or Player:IsCasting(SpellAffli.UnstableAffliction)
    elseif Spell == SpellAffli.HauntDebuff then
      return BaseCheck or Player:IsCasting(SpellAffli.Haunt)
    elseif Spell == SpellAffli.VileTaintDebuff then
      return BaseCheck or Player:IsCasting(SpellAffli.VileTaint)
    else
      return BaseCheck
    end
  end
, 265)

-- Demonology, ID: 266
HL.AddCoreOverride ("Player.SoulShardsP",
  function ()
    local Shard = Player:SoulShards()
    Shard = floor(Shard)
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(SpellDemo.SummonDemonicTyrant) and SpellDemo.SoulboundTyrant:IsAvailable() then
        return min(Shard + 3, 5)
      elseif Player:IsCasting(SpellDemo.Demonbolt) then
        return min(Shard + 2, 5)
      elseif Player:IsCasting(SpellDemo.ShadowBolt) or Player:IsCasting(SpellDemo.SoulStrike) then
        return min(Shard + 1, 5)
      elseif Player:IsCasting(SpellDemo.HandofGuldan) then
        return max(Shard - 3, 0)
      elseif Player:IsCasting(SpellDemo.CallDreadstalkers) then
        return Shard - 2
      elseif Player:IsCasting(SpellDemo.SummonVilefiend) or Player:IsCasting(SpellDemo.SummonPet) or Player:IsCasting(SpellDemo.NetherPortal) then
        return Shard - 1
      else
        return Shard
      end
    end
  end
  , 266)

local DemoOldSpellIsCastable
DemoOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DemoOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellDemo.SummonPet then
      return BaseCheck and (not Settings.Commons.HidePetSummon) and (not Pet:IsActive()) and Player:SoulShardsP() > 0 and not Player:IsCasting(self)
    elseif self == SpellDemo.SummonDemonicTyrant then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 266)

local DemoOldSpellIsReady
DemoOldSpellIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DemoOldSpellIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellDemo.SummonVilefiend or self == SpellDemo.SummonCharhound or self == SpellDemo.SummonGloomhound or SpellDemo.GrimoireFelguard then
      return BaseCheck and Player:SoulShardsP() >= 1 and not Player:IsCasting(self)
    elseif self == SpellDemo.CallDreadstalkers then
      return BaseCheck and (Player:SoulShardsP() >= 2 or Player:BuffUp(SpellDemo.DemonicCallingBuff)) and not Player:IsCasting(self)
    elseif self == SpellDemo.SummonSoulkeeper then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellDemo.HandofGuldan then
      return BaseCheck and Player:SoulShardsP() >= 1
    elseif self == SpellDemo.PowerSiphon then
      return BaseCheck and HL.GuardiansTable.ImpCount > 0
    else
      return BaseCheck
    end
  end
, 266)

-- Destruction, ID: 267
HL.AddCoreOverride ("Player.SoulShardsP",
  function ()
    local Shard = Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(SpellDestro.ChaosBolt) or Player:IsCasting(SpellDestro.RainofFire) and SpellDestro.Inferno:IsAvailable() then
        return Shard - 2
      elseif Player:IsCasting(SpellDestro.RainofFire) and not SpellDestro.Inferno:IsAvailable() then
        return Shard - 3
      elseif Player:IsCasting(SpellDestro.SummonPet) then
        return Shard - 1
      elseif Player:IsCasting(SpellDestro.Incinerate) then
        return min(Shard + 0.2, 5)
      elseif Player:IsCasting(SpellDestro.Conflagrate) then
        return min(Shard + 0.5, 5)
      elseif Player:IsCasting(SpellDestro.SoulFire) then
        return min(Shard + 1, 5)
      else
        return Shard
      end
    end
  end
  , 267)
  
local DestroOldSpellIsCastable
DestroOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DestroOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellDestro.SummonPet then
      return BaseCheck and (not Settings.Commons.HidePetSummon) and Player:SoulShardsP() > 0 and (not Player:IsCasting(self)) and not (Pet:IsActive() or Player:BuffUp(SpellDestro.GrimoireofSacrificeBuff))
    elseif self == SpellDestro.Immolate or self == SpellDestro.Cataclysm or self == SpellDestro.SoulRot or self == SpellDestro.SummonSoulkeeper then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 267)

local DestroOldSpellIsReady
DestroOldSpellIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DestroOldSpellIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellDestro.GrimoireofSacrifice then
      return BaseCheck and Player:BuffDown(SpellDestro.GrimoireofSacrificeBuff)
    elseif self == SpellDestro.ChannelDemonfire then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 267)

local DestroOldPlayerAffectingCombat
DestroOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return SpellDestro.Incinerate:InFlight() or Player:IsCasting(SpellDestro.SoulFire) or DestroOldPlayerAffectingCombat(self)
  end
, 267)

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

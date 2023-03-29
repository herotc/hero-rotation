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
local SpellAffli   = Spell.Warlock.Affliction
local SpellDemo    = Spell.Warlock.Demonology
local SpellDestro  = Spell.Warlock.Destruction
-- Lua
local min     = math.min
local max     = math.max
local floor   = math.floor
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
    if self == SpellAffli.VileTaint or self == SpellAffli.UnstableAffliction or self == SpellAffli.SoulRot then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellAffli.SeedofCorruption or self == SpellAffli.Haunt then
      return BaseCheck and not Player:IsCasting(self) and not self:InFlight()
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
      if Player:IsCasting(SpellDemo.SummonDemonicTyrant) then
        return 5
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
    if self == SpellDemo.SummonVilefiend or self == SpellDemo.CallDreadstalkers or self == SpellDemo.NetherPortal or SpellDemo.SummonSoulkeeper then
      return BaseCheck and not Player:IsCasting(self)
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
      if Player:IsCasting(SpellDestro.ChaosBolt) then
        return Shard - 2
      elseif Player:IsCasting(SpellDestro.RainofFire) then
        return Shard - 3
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
    elseif self == SpellDestro.Immolate or self == SpellDestro.Cataclysm or self == SpellDestro.ChannelDemonfire or self == SpellDestro.SoulRot or self == SpellDestro.SummonSoulkeeper then
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

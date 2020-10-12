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
--local SpellAffli   = Spell.Warlock.Affliction
local SpellDemo    = Spell.Warlock.Demonology
--local SpellDestro  = Spell.Warlock.Destruction
-- Lua

--SpellAffli.AbsoluteCorruption = Spell(196103)
--SpellAffli.Haunt:RegisterInFlight()
--- ============================ CONTENT ============================
-- Affliction, ID: 265
--[[HL.AddCoreOverride ("Spell.IsCastableP",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeOK
    if self == SpellAffli.SummonPet then
      return BaseCheck and not (Pet:IsActive() or Player:BuffP(SpellAffli.GrimoireofSacrificeBuff))
    else
      return BaseCheck
    end
  end
, 265)

HL.AddCoreOverride ("Player.SoulShardsP",
  function (self)
    local Shard = WarlockPowerBar_UnitPower(self.UnitID)
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(SpellAffli.UnstableAffliction) or Player:IsCasting(SpellAffli.SeedOfCorruption) 
          or Player:IsCasting(SpellAffli.VileTaint) or Player:IsCasting(SpellAffli.SummonPet) then
        return Shard - 1
      else
        return Shard
      end
    end
  end
, 265)

HL.AddCoreOverride ("Spell.CooldownRemainsP",
  function (self, BypassRecovery, Offset)
    if self == SpellAffli.VileTaint and Player:IsCasting(self) then
      return 20
    elseif self == SpellAffli.Haunt and Player:IsCasting(self) then
      return 15
    else
      return self:CooldownRemains( BypassRecovery, Offset or "Auto" )
    end
  end
, 265)

local BaseUnitDebuffRemains
BaseUnitDebuffRemains = HL.AddCoreOverride ("Unit.DebuffRemains",
  function (self, Spell, AnyCaster, Offset)
    BaseReturn = BaseUnitDebuffRemains(self, Spell, AnyCaster, Offset)
    if Spell == SpellAffli.UnstableAffliction1Debuff and Player:IsCasting(SpellAffli.UnstableAffliction) then
      if BaseReturn > 0 then return BaseReturn else return 8 end
      elseif (Spell == SpellAffli.UnstableAffliction2Debuff
          or Spell == SpellAffli.UnstableAffliction3Debuff
          or Spell == SpellAffli.UnstableAffliction4Debuff
          or Spell == SpellAffli.UnstableAffliction5Debuff) and Player:IsCasting(SpellAffli.UnstableAffliction) then
        if BaseReturn > 0 then return BaseReturn
        elseif (BaseUnitDebuffRemains(self, HL.UnstableAfflictionDebuffsPrev[Spell], AnyCaster, Offset) > 0) then return 8 else return 0 end
    elseif Spell == SpellAffli.HauntDebuff and (Player:IsCasting(SpellAffli.Haunt) or SpellAffli.Haunt:InFlight()) then
      return 15
    elseif Spell == SpellAffli.CorruptionDebuff and SpellAffli.AbsoluteCorruption:IsAvailable() then
      if self:Debuff(Spell, nil, AnyCaster) then return 9999 else return 0 end
    else
      return BaseUnitDebuffRemains(self, Spell, AnyCaster, Offset)
    end
  end
, 265)]]

-- Demonology, ID: 266
local DemoOldSpellIsCastable
DemoOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DemoOldSpellIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellDemo.SummonPet then
      return BaseCheck and not Pet:IsActive() and Player:SoulShardsP() > 0
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
    if self == SpellDemo.SummonVilefiend then
      return BaseCheck and not Player:IsCasting(SpellDemo.SummonVilefiend)
    elseif self == SpellDemo.CallDreadstalkers then
      return BaseCheck and not Player:IsCasting(SpellDemo.CallDreadstalkers)
    else
      return BaseCheck
    end
  end
, 266)

HL.AddCoreOverride ("Player.SoulShardsP",
  function (self)
    local Shard = Player:SoulShards()
    Shard = math.floor(Shard)
    if not Player:IsCasting() then
      return Shard
    else
      if (Player:IsCasting(SpellDemo.CallDreadstalkers) and Player:BuffDown(SpellDemo.DemonicCallingBuff))
          or Player:IsCasting(SpellDemo.BilescourgeBombers) then
        return Shard - 2
      elseif Player:IsCasting(SpellDemo.CallDreadstalkers) and Player:BuffUp(SpellDemo.DemonicCallingBuff) then
        return Shard
      elseif Player:IsCasting(SpellDemo.SummonVilefiend)
          or  Player:IsCasting(SpellDemo.SummonPet)
          or  Player:IsCasting(SpellDemo.GrimoireFelguard) 
          or  Player:IsCasting(SpellDemo.NetherPortal) then
        return Shard - 1
      elseif Player:IsCasting(SpellDemo.HandofGuldan) then
        if Shard > 3 then
          return Shard - 3
        else
          return 0
        end
      elseif Player:IsCasting(SpellDemo.Demonbolt) then
        if Shard >= 3 then
          return 5
        else
          return Shard + 2
        end
      elseif Player:IsCasting(SpellDemo.ShadowBolt) then
        if Shard == 5 then
          return Shard
        else
          return Shard + 1
        end
      elseif Player:IsCasting(SpellDemo.SummonDemonicTyrant) and Player:Level() >= 58 then 
        return 5
      else
        return Shard
      end
    end
  end
, 266)

-- Destruction, ID: 267
--[[local DestroOldSpellIsCastableP
DestroOldSpellIsCastableP = HL.AddCoreOverride ("Spell.IsCastableP",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DestroOldSpellIsCastableP(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellDestro.SummonPet then
      return BaseCheck and not Pet:IsActive()
    elseif self == SpellDestro.Cataclysm then
      return BaseCheck and not Player:IsCasting(SpellDestro.Cataclysm)
    else
      return BaseCheck
    end
  end
, 267)]]

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

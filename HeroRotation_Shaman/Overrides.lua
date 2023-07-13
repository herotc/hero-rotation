--- ============================ HEADER ============================
-- HeroLib
local HL       = HeroLib
local Cache    = HeroCache
local Unit     = HL.Unit
local Player   = Unit.Player
local Pet      = Unit.Pet
local Target   = Unit.Target
local Spell    = HL.Spell
local Item     = HL.Item
-- HeroRotation
local HR       = HeroRotation
-- Spells
local SpellEle = Spell.Shaman.Elemental
local SpellEnh = Spell.Shaman.Enhancement
-- Lua
-- File Locals
local Shaman = HR.Commons.Shaman

--- ============================ CONTENT ============================

-- Elemental, ID: 262
HL.AddCoreOverride ("Player.MaelstromP",
  function()
    local Maelstrom = Player:Maelstrom()
    if not Player:IsCasting() then
      return Maelstrom
    else
      if Player:IsCasting(SpellEle.ElementalBlast) then
        return Maelstrom - 75
      elseif Player:IsCasting(SpellEle.Icefury) then
        return Maelstrom + 25
      elseif Player:IsCasting(SpellEle.LightningBolt) then
        return Maelstrom + 10
      elseif Player:IsCasting(SpellEle.LavaBurst) then
        return Maelstrom + 12
      elseif Player:IsCasting(SpellEle.ChainLightning) then
        --TODO: figure out the *actual* maelstrom you'll get from hitting your current target...
        --return Maelstrom + (4 * #SplashedEnemiesTable[Target])
        -- If you're hitting the best target with CL , this is 4*Shaman.ClusterTargets
        return Maelstrom + (4 * Shaman.ClusterTargets)
      else
        return Maelstrom
      end
    end
  end
, 262)

HL.AddCoreOverride ("Spell.IsViable",
  function(self)
    local BaseCheck = self:IsReady()
    local S = SpellEle
    if self == S.Stormkeeper or self == S.ElementalBlast or self == S.Icefury then
      local MovementPredicate = Player:BuffUp(S.SpiritwalkersGraceBuff) or not Player:IsMoving()
      return BaseCheck and MovementPredicate and not Player:IsCasting(self)
    elseif self == S.LavaBeam then
      local MovementPredicate = Player:BuffUp(S.SpiritwalkersGraceBuff) or not Player:IsMoving()
      return BaseCheck and MovementPredicate
    elseif self == S.LightningBolt or self == S.ChainLightning then
      local MovementPredicate = Player:BuffUp(S.SpiritwalkersGraceBuff) or Player:BuffUp(S.StormkeeperBuff) or not Player:IsMoving()
      return BaseCheck and MovementPredicate
    elseif self == S.LavaBurst then
      local MovementPredicate = Player:BuffUp(S.SpiritwalkersGraceBuff) or Player:BuffUp(S.LavaSurgeBuff) or not Player:IsMoving()
      local a = Player:BuffUp(S.LavaSurgeBuff)
      local b = S.LavaBurst:Charges() >= 1 and not Player:IsCasting(S.LavaBurst)
      local c = S.LavaBurst:Charges() == 2 and Player:IsCasting(S.LavaBurst)
      return BaseCheck and MovementPredicate and (a or b or c)
    elseif self == S.PrimordialWave then
      return BaseCheck and Player:BuffDown(S.PrimordialWaveBuff) and Player:BuffDown(S.LavaSurgeBuff)
    else
      return BaseCheck
    end
  end
, 262)

HL.AddCoreOverride ("Player.MOTEP",
  function()
    if not SpellEle.MasteroftheElements:IsAvailable() then return false end
    local MOTEUp = Player:BuffUp(SpellEle.MasteroftheElementsBuff)
    if not Player:IsCasting() then
      return MOTEUp
    else
      if Player:IsCasting(SpellEle.LavaBurst) then
        return true
      elseif Player:IsCasting(SpellEle.ElementalBlast) or Player:IsCasting(SpellEle.Icefury) or Player:IsCasting(SpellEle.LightningBolt) or Player:IsCasting(SpellEle.ChainLightning) then 
        return false
      else
        return MOTEUp
      end
    end
  end
, 262)

HL.AddCoreOverride ("Player.PotMP",
  function()
    if not SpellEle.PoweroftheMaelstrom:IsAvailable() then return false end
    local PotMStacks = Player:BuffStack(SpellEle.PoweroftheMaelstromBuff)
    if not Player:IsCasting() then
      return PotMStacks > 0
    else
      if PotMStacks == 1 and (Player:IsCasting(SpellEle.LightningBolt) or Player:IsCasting(SpellEle.ChainLightning)) then
        return false
      else
        return PotMStacks > 0
      end
    end
  end
, 262)

HL.AddCoreOverride ("Player.StormkeeperP",
  function()
    if not SpellEle.Stormkeeper:IsAvailable() then return false end
    local StormkeeperUp = Player:BuffUp(SpellEle.StormkeeperBuff)
    if not Player:IsCasting() then
      return StormkeeperUp
    else
      if Player:IsCasting(SpellEle.Stormkeeper) then
        return true
      else
        return StormkeeperUp
      end
    end
  end
, 262)

HL.AddCoreOverride ("Player.IcefuryP",
  function()
    if not SpellEle.Icefury:IsAvailable() then return false end
    local IcefuryUp = Player:BuffUp(SpellEle.IcefuryBuff)
    if not Player:IsCasting() then
      return IcefuryUp
    else
      if Player:IsCasting(SpellEle.Icefury) then
        return true
      else
        return IcefuryUp
      end
    end
  end
, 262)

-- Enhancement, ID: 263
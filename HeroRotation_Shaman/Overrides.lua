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
        return Maelstrom - 90
      elseif Player:IsCasting(SpellEle.Icefury) then
        return Maelstrom + 10
      elseif Player:IsCasting(SpellEle.LightningBolt) then
        return Maelstrom + 6
      elseif Player:IsCasting(SpellEle.LavaBurst) then
        return Maelstrom + 8
      elseif Player:IsCasting(SpellEle.ChainLightning) then
        --TODO: figure out the *actual* maelstrom you'll get from hitting your current target...
        --return Maelstrom + (4 * #SplashedEnemiesTable[Target])
        -- If you're hitting the best target with CL , this is 2*Shaman.ClusterTargets
        return Maelstrom + (2 * Shaman.ClusterTargets)
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
    local IgnoreMovement = HR.GUISettings.APL.Shaman.Elemental.IgnoreMovement
    if self == S.Stormkeeper or self == S.ElementalBlast or self == S.Icefury then
      local MovementPredicate = IgnoreMovement or Player:BuffUp(S.SpiritwalkersGraceBuff) or not Player:IsMoving()
      return BaseCheck and MovementPredicate and not Player:IsCasting(self)
    elseif self == S.LightningBolt or self == S.ChainLightning then
      local MovementPredicate = IgnoreMovement or Player:BuffUp(S.SpiritwalkersGraceBuff) or Player:BuffUp(S.StormkeeperBuff) or not Player:IsMoving()
      return BaseCheck and MovementPredicate
    elseif self == S.LavaBurst then
      local MovementPredicate = IgnoreMovement or Player:BuffUp(S.SpiritwalkersGraceBuff) or Player:BuffUp(S.LavaSurgeBuff) or not Player:IsMoving()
      local a = Player:BuffUp(S.LavaSurgeBuff)
      local b = S.LavaBurst:Charges() >= 1 and not Player:IsCasting(S.LavaBurst)
      local c = S.LavaBurst:Charges() == 2 and Player:IsCasting(S.LavaBurst)
      return BaseCheck and MovementPredicate and (a or b or c)
    else
      return BaseCheck
    end
  end
, 262)

HL.AddCoreOverride ("Player.MotEUp",
  function()
    if not SpellEle.MasteroftheElements:IsAvailable() then return false end
    local MotEBuffUp = Player:BuffUp(SpellEle.MasteroftheElementsBuff)
    if not Player:IsCasting() then
      return MotEBuffUp
    else
      if Player:IsCasting(SpellEle.LavaBurst) then
        return true
      elseif Player:IsCasting(SpellEle.ElementalBlast) or Player:IsCasting(SpellEle.Icefury) or Player:IsCasting(SpellEle.LightningBolt) or Player:IsCasting(SpellEle.ChainLightning) then 
        return false
      else
        return MotEBuffUp
      end
    end
  end
, 262)

HL.AddCoreOverride ("Player.PotMUp",
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

HL.AddCoreOverride ("Player.StormkeeperUp",
  function()
    if not SpellEle.Stormkeeper:IsAvailable() then return false end
    local StormkeeperBuffUp = Player:BuffUp(SpellEle.StormkeeperBuff)
    if not Player:IsCasting() then
      return StormkeeperBuffUp
    else
      if Player:IsCasting(SpellEle.Stormkeeper) then
        return true
      else
        return StormkeeperBuffUp
      end
    end
  end
, 262)

HL.AddCoreOverride ("Player.IcefuryUp",
  function()
    if not SpellEle.Icefury:IsAvailable() then return false end
    local IcefuryBuffUp = Player:BuffUp(SpellEle.IcefuryBuff)
    if not Player:IsCasting() then
      return IcefuryBuffUp
    else
      if Player:IsCasting(SpellEle.Icefury) then
        return true
      else
        return IcefuryBuffUp
      end
    end
  end
, 262)

-- Enhancement, ID: 263
local OldEnhBuffUp
OldEnhBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = OldEnhBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellEnh.PrimordialWaveBuff then
      return BaseCheck or Player:PrevGCDP(1, SpellEnh.PrimordialWave)
    else
      return BaseCheck
    end
  end
, 263)

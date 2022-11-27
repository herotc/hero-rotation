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

HL.AddCoreOverride ("Player.MOTEP",
  function()
    if not SpellEle.MasteroftheElements:IsAvailable() then return false end
    local MOTEUp = Player:BuffUp(SpellEle.MasteroftheElementsBuff)
    if not Player:IsCasting() then
      return MOTEUp
    else
      if Player:IsCasting(SpellEle.LavaBurst) then
        return true
      elseif Player:IsCasting(SpellEle.ElementalBlast) then 
        return false
      elseif Player:IsCasting(SpellEle.Icefury) then
        return false
      elseif Player:IsCasting(SpellEle.LightningBolt) then
        return false
      elseif Player:IsCasting(SpellEle.ChainLightning) then
        return false
      else
        return MOTEUp
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
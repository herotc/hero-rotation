--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Class = HR.Commons.Class

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Class.Commons,
  Spec = HR.GUISettings.APL.Class.Spec
}

-- Spells
if not Spell.Class then Spell.Class = {} end
Spell.Class.Spec = {
  -- Racials

  -- Abilities

  -- Talents

  -- Artifact

  -- Defensive

  -- Utility

  -- Legendaries

  -- Misc

  -- Macros

}
local S = Spell.Class.Spec

-- Items
if not Item.Class then Item.Class = {} end
Item.Class.Spec = {
  -- Legendaries

}
local I = Item.Class.Spec

-- Rotation Var


--- ======= ACTION LISTS =======
-- Put here action lists only if they are called multiple times in the APL
-- If it's only put one time, it's doing a closure call for nothing.



--- ======= MAIN =======
local function APL ()
  -- Local Update

  -- Unit Update

  -- Defensives

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() then

    end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then

    return
  end
end

HR.SetAPL(000, APL)


--- ======= SIMC =======
-- Last Update: 12/31/2999

-- APL goes here

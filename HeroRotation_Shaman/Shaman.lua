--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
-- HeroRotation
local HR = HeroRotation;
-- Lua

-- Commons
HR.Commons.Shaman = {};

-- GUI Settings
local Settings = HR.GUISettings.APL.Shaman.Elemental;
local Shaman = HR.Commons.Shaman;

-- Commons Functions
function Shaman.ChainInMain()
  if Settings.ChainInMain == "Always" then return true; end
  if Settings.ChainInMain == "Never" then return false; end 

  return Shaman.ValidateSplashCache()
end
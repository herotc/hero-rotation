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
local AR = HeroRotation;
-- Lua
-- Commons
AR.Commons.Warrior = {};
-- GUI Settings
local Settings = AR.GUISettings.APL.Warrior.Commons;
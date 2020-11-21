--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local MouseOver = Unit.MouseOver
local Spell = HL.Spell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local Settings = HR.GUISettings.APL.Class.Commons
local Everyone = HR.Commons.Everyone
-- Lua
-- File Locals
local Commons = {}

--- ======= GLOBALIZE =======
HR.Commons.Class = Commons


--- ============================ CONTENT ============================
-- Spells
if not Spell.Class then Spell.Class = {} end
Spell.Class.Spec = {
  -- Racials

  -- Abilities

  -- Talents

  -- Trinkets

  -- Covenants (Shadowlands)

  -- Soulbinds/Conduits (Shadowlands)

  -- Legendaries (Shadowlands)

  -- Azerite Traits (BfA)

  -- Essences (BfA)

  -- Pool
  Pool = Spell(999910)
}

-- Items
if not Item.Class then Item.Class = {} end
Item.Class.Spec = {
}

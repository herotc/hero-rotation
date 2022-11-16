--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local HR = HeroRotation
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
HR.Commons.Hunter = {}
local Hunter = HR.Commons.Hunter
-- Lua
local pairs = pairs
local select = select
local wipe = wipe
local GetTime = HL.GetTime
-- Spells
local SpellBM = Spell.Hunter.BeastMastery
local SpellMM = Spell.Hunter.Marksmanship
--[[ MM Spell Cost Table
HR.Commons.Hunter.MMCost = {}
local MMCost = HR.Commons.Hunter.MMCost
for spell in pairs(SpellMM) do
  if spell ~= "PoolFocus" then
    if SpellMM[spell]:Cost() > 0 then
      local SpellID = SpellMM[spell]:ID()
      MMCost[SpellID] = SpellMM[spell]:Cost()
    end
  end
end]]

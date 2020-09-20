--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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

-- File Locals
HR.Commons.Mage = {};
local Settings = HR.GUISettings.APL.Mage.Commons;
local Mage = HR.Commons.Mage;

--- ============================ CONTENT ============================

-- Variables
Mage.IFST = {
  CurrStacks = 0,
  CurrStacksTime = 0,
  OldStacks = 0,
  OldStacksTime = 0,
  Direction = 0
};
local S = {} ;
S.IncantersFlowBuff = Spell(116267);

HL:RegisterForEvent(function()
  Mage.IFST.CurrStacks = 0
  Mage.IFST.CurrStacksTime = 0
  Mage.IFST.OldStacks = 0
  Mage.IFST.OldStacksTime = 0
  Mage.IFST.Direction = 0
end, "PLAYER_REGEN_ENABLED")

function Mage.IFTracker()
  if HL.CombatTime() == 0 then return; end
  local TickDiff = Mage.IFST.CurrStacksTime - Mage.IFST.OldStacksTime
  local CurrStacks = Mage.IFST.CurrStacks
  local CurrStacksTime = Mage.IFST.CurrStacksTime
  local OldStacks = Mage.IFST.OldStacks
  if (Player:BuffUp(S.IncantersFlowBuff)) then
    if (Player:BuffStack(S.IncantersFlowBuff) ~= CurrStacks or (Player:BuffStack(S.IncantersFlowBuff) == CurrStacks and TickDiff > 1)) then
      Mage.IFST.OldStacks = CurrStacks
      Mage.IFST.OldStacksTime = CurrStacksTime
    end
    Mage.IFST.CurrStacks = Player:BuffStack(S.IncantersFlowBuff)
    Mage.IFST.CurrStacksTime = HL.CombatTime()
    if Mage.IFST.CurrStacks > Mage.IFST.OldStacks then
      if Mage.IFST.CurrStacks == 5 then
        Mage.IFST.Direction = 0
      else
        Mage.IFST.Direction = 1
      end
    elseif Mage.IFST.CurrStacks < Mage.IFST.OldStacks then
      if Mage.IFST.CurrStacks == 1 then
        Mage.IFST.Direction = 0
      else
        Mage.IFST.Direction = -1
      end
    else
      if Mage.IFST.CurrStacks == 1 then
        Mage.IFST.Direction = 1
      else
        Mage.IFST.Direction = -1
      end
    end
  else
    Mage.IFST.OldStacks = 0
    Mage.IFST.OldStacksTime = 0
    Mage.IFST.CurrStacks = 0
    Mage.IFST.CurrStacksTime = 0
    Mage.IFST.Direction = 0
  end
end

function Mage.IFTimeToX(count, direction)
    local low
    local high
    local buff_position
    if Mage.IFST.Direction == -1 or (Mage.IFST.Direction == 0 and Mage.IFST.CurrStacks == 0) then
      buff_position = 10 - Mage.IFST.CurrStacks + 1
    else
      buff_position = Mage.IFST.CurrStacks
    end
    if direction == "up" then
        low = count
        high = count
    elseif direction == "down" then
        low = 10 - count + 1
        high = 10 - count + 1
    else
        low = count
        high = 10 - count + 1
    end
    if low == buff_position or high == buff_position then
      return 0
    end
    local ticks_low = (10 + low - buff_position) % 10
    local ticks_high = (10 + high - buff_position) % 10
    return (Mage.IFST.CurrStacksTime - Mage.IFST.OldStacksTime) + math.min(ticks_low, ticks_high) - 1
end

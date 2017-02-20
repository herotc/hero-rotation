--- Localize Vars
-- Addon
local addonName, AR = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCore_Cache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- Commons
AR.Commons = {};
AR.Commons.Everyone = {};
-- GUI Settings
local Settings = AR.GUISettings.General;

-- Is Target Valid
function AR.Commons.TargetIsValid ()
  return Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost();
end

-- Interrupt
function AR.Commons.Interrupt (Range, Spell, Setting, StunSpells)
  if Settings.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(Range) then
    if Spell:IsCastable() then
      if AR.Cast(Spell, Setting) then return "Cast " .. Spell:Name() .. " (Interrupt)"; end
    elseif Settings.InterruptWithStun and Target:CanBeStunned() then
      if StunSpells then
        for i = 1, #StunSpells do
          if StunSpells[i][1]:IsCastable() and StunSpells[i][3]() then
            if AR.Cast(StunSpells[i][1]) then return StunSpells[i][2]; end
          end
        end
      end
    end
  end
end
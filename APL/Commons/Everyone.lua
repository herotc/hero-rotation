local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Commons
ER.Commons = {};
ER.Commons.Everyone = {};
-- GUI Settings
local Settings = ER.GUISettings.General;

-- Is Target Valid
function ER.Commons.TargetIsValid ()
  return Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost();
end

-- Interrupt
function ER.Commons.Interrupt (Range, Spell, Setting, StunSpells)
  if Settings.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(Range) then
    if Spell:IsCastable() then
      if ER.Cast(Spell, Setting) then return "Cast " .. Spell:Name() .. " (Interrupt)"; end
    elseif Settings.InterruptWithStun and Target:CanBeStunned() then
      if StunSpells then
        for i = 1, #StunSpells do
          if StunSpells[i][1]:IsCastable() and StunSpells[i][3]() then
            if ER.Cast(StunSpells[i][1]) then return StunSpells[i][2]; end
          end
        end
      end
    end
  end
end
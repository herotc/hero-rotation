local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Commons
ER.Commons.Rogue = {};

-- Stealth
function ER.Commons.Rogue.Stealth (Stealth, Setting)
  if Stealth:IsCastable() and not Player:IsStealthed() then
    if ER.Cast(Stealth, Setting) then return "Cast Stealth"; end
  end
  return false;
end

-- Crimson Vial
function ER.Commons.Rogue.CrimsonVial (CrimsonVial, Setting, HP)
  if CrimsonVial:IsCastable() and Player:HealthPercentage() <= HP then
    if ER.Cast(CrimsonVial, Setting) then return "Cast Crimson Vial"; end
  end
  return false;
end

-- Feint
function ER.Commons.Rogue.Feint (Feint, Setting, HP)
  if Feint:IsCastable() and not Player:Buff(Feint) and Player:HealthPercentage() <= HP then
    if ER.Cast(Feint, Setting) then return "Cast Feint"; end
  end
end

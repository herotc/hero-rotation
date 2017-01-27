local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua
local pairs = pairs;
-- Commons
ER.Commons.Rogue = {};
-- GUI Settings
local Settings = ER.GUISettings.APL.Rogue.Commons;

-- Stealth
function ER.Commons.Rogue.Stealth (Stealth, Setting)
  if Stealth:IsCastable() and not Player:IsStealthed() then
    if ER.Cast(Stealth, Settings.OffGCDasOffGCD.Stealth) then return "Cast Stealth (OOC)"; end
  end
  return false;
end

-- Crimson Vial
function ER.Commons.Rogue.CrimsonVial (CrimsonVial)
  if CrimsonVial:IsCastable() and Player:HealthPercentage() <= Settings.CrimsonVialHP then
    if ER.Cast(CrimsonVial, Settings.GCDasOffGCD.CrimsonVial) then return "Cast Crimson Vial (Defensives)"; end
  end
  return false;
end

-- Feint
function ER.Commons.Rogue.Feint (Feint)
  if Feint:IsCastable() and not Player:Buff(Feint) and Player:HealthPercentage() <= Settings.FeintHP then
    if ER.Cast(Feint, Settings.GCDasOffGCD.Feint) then return "Cast Feint (Defensives)"; end
  end
end

-- Marked for Death Sniping
local BestUnit, BestUnitTTD;
function ER.Commons.Rogue.MfDSniping (MarkedforDeath)
  if MarkedforDeath:IsCastable() then
    BestUnit, BestUnitTTD = nil, 60;
    for _, Unit in pairs(ER.Cache.Enemies[30]) do
      -- I increased the SimC condition by 50% since we are slower.
      if not Unit:IsMfdBlacklisted() and Unit:TimeToDie() < Player:ComboPointsDeficit()*1.5 and Unit:TimeToDie() < BestUnitTTD then
        BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
      end
    end
    if BestUnit then
      ER.Nameplate.AddIcon(BestUnit, MarkedforDeath);
    end
  end
end

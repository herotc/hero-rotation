--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- AethysRotation
local AR = AethysRotation;
-- Lua
local pairs = pairs;


-- APL Local Vars
-- Commons
  local Everyone = AR.Commons.Everyone;
-- Spell
  if not Spell.DemonHunter then Spell.DemonHunter = {}; end
  Spell.DemonHunter.Vengeance = {
    -- Abilities
    Felblade        = Spell(232893),
    FelDevastation  = Spell(212084),
    Fracture        = Spell(209795),
    Frailty         = Spell(247456),
    ImmolationAura  = Spell(178740),
    Sever           = Spell(235964),
    Shear           = Spell(203782),
    SigilofFlame    = Spell(204596),
    SpiritBomb      = Spell(247454),
    SoulCleave      = Spell(228477),
    SoulFragments   = Spell(203981),
    ThrowGlaive     = Spell(204157),
    -- Offensive
    SoulCarver      = Spell(207407),
    -- Defensive
    DemonSpikes     = Spell(203720),
    DemonSpikesBuff = Spell(203819),
    -- Utility
    ConsumeMagic    = Spell(183752),
    InfernalStrike  = Spell(189110)
  };
  local S = Spell.DemonHunter.Vengeance;
-- Rotation Var
  
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Vengeance = AR.GUISettings.APL.DemonHunter.Vengeance
  };

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(20, true); -- Fel Devastation (I think it's 20 thp)
  AC.GetEnemies(8, true); -- Sigil of Flame & Spirit Bomb
  Everyone.AoEToggleEnemiesUpdate();

  -- Misc
  local SoulFragments = Player:BuffStack(S.SoulFragments);

  --- Defensives
  -- Demon Spikes
  if S.DemonSpikes:IsCastable("Melee") and Player:Pain() >= 20 and not Player:Buff(S.DemonSpikesBuff) and (Player:ActiveMitigationNeeded() or Player:HealthPercentage() <= 65) then
    if AR.Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "Cast Demon Spikes"; end
  end

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ DBM Count
    -- Opener (Shear)
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      -- actions+=/sever
      if S.Sever:IsCastable("Melee") then
        if AR.Cast(S.Sever) then return "Cast Shear"; end
      end
      -- actions+=/shear
      if S.Shear:IsCastable("Melee") then
        if AR.Cast(S.Shear) then return "Cast Shear"; end
      end
    end
    return;
  end
  --- In Combat
  if Everyone.TargetIsValid() then
    -- Consume Magic
    if Settings.General.InterruptEnabled and S.ConsumeMagic:IsCastable(20) and Target:IsInterruptible() then
      if AR.Cast(S.ConsumeMagic, Settings.Vengeance.OffGCDasOffGCD.ConsumeMagic) then return "Cast Consume Magic"; end
    end
    -- Infernal Strike Charges Dump
    if S.InfernalStrike:IsCastable("Melee") and S.InfernalStrike:ChargesFractional() > 1.9 then
      if AR.Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike) then return "Cast Infernal Strike"; end
    end
    -- actions+=/spirit_bomb,if=soul_fragments=5|debuff.frailty.down
    -- Note: Looks like the debuff takes time to refresh so we add TimeSinceLastCast to offset that.
    if S.SpiritBomb:IsCastable() and S.SpiritBomb:TimeSinceLastCast() > Player:GCD() * 2 and Cache.EnemiesCount[8] >= 1 and (SoulFragments >= 4 or (Target:DebuffDownP(S.Frailty) and SoulFragments >= 1)) then
      if AR.Cast(S.SpiritBomb) then return "Cast Spirit Bomb"; end
    end
    -- actions+=/soul_carver
    if AR.CDsON() and S.SoulCarver:IsCastable("Melee") then
      if AR.Cast(S.SoulCarver) then return "Cast Soul Carver"; end
    end
    -- actions+=/immolation_aura,if=pain<=80
    if S.ImmolationAura:IsCastable() and Cache.EnemiesCount[8] >= 1 and not Player:Buff(S.ImmolationAura) and Player:Pain() <= 80 then
      if AR.Cast(S.ImmolationAura) then return "Cast Immolation Aura"; end
    end
    -- actions+=/felblade,if=pain<=70
    if S.Felblade:IsCastable(15) and Player:Pain() <= 75 then
      if AR.Cast(S.Felblade) then return "Cast Felblade"; end
    end
    -- actions+=/soul_cleave,if=soul_fragments=5
    if S.SoulCleave:IsCastable("Melee") and not S.SpiritBomb:IsAvailable() and SoulFragments >= 5 then
      if AR.Cast(S.SoulCleave) then return "Cast Soul Cleave"; end
    end
    -- actions+=/fel_devastation
    if AR.CDsON() and S.FelDevastation:IsCastable(20, true) and GetUnitSpeed("player") == 0 and Player:Pain() >= 30 then
      if AR.Cast(S.FelDevastation) then return "Cast Fel Devastation"; end
    end
    -- actions+=/sigil_of_flame
    if S.SigilofFlame:IsCastable() and Cache.EnemiesCount[8] >= 1 then
      if AR.Cast(S.SigilofFlame) then return "Cast Sigil of Flame"; end
    end
    if Target:IsInRange("Melee") then
      -- actions+=/fracture,if=pain>=60&soul_fragments<4
      if S.Fracture:IsCastable() and Player:Pain() >= 60 and SoulFragments < 4 then
        if AR.Cast(S.Fracture) then return "Cast Fracture"; end
      end
      -- actions+=/soul_cleave,if=pain>=80
      if S.SoulCleave:IsCastable() and Player:Pain() >= 80 then
        if AR.Cast(S.SoulCleave) then return "Cast Soul Cleave"; end
      end
      -- actions+=/sever
      if S.Sever:IsCastable() then
        if AR.Cast(S.Sever) then return "Cast Sever"; end
      end
      -- actions+=/shear
      if S.Shear:IsCastable() then
        if AR.Cast(S.Shear) then return "Cast Shear"; end
      end
    end
    if Target:IsInRange(30) and S.ThrowGlaive:IsCastable() then
      if AR.Cast(S.ThrowGlaive) then return "Cast Throw Glaive (OoR)"; end
    end
  end
end

AR.SetAPL(581, APL);

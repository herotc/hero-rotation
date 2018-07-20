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
local pairs = pairs;


-- APL Local Vars
-- Commons
  local Everyone = HR.Commons.Everyone;
-- Spell
  if not Spell.DemonHunter then Spell.DemonHunter = {}; end
  Spell.DemonHunter.Vengeance = {
    -- Abilities
    Fracture            = Spell(263642),
    Frailty             = Spell(247456),
    ImmolationAura      = Spell(178740),
    Shear               = Spell(203782),
    SigilofFlame        = Spell(204596),
    SigilofFlameDebuff  = Spell(204598),
    SpiritBomb          = Spell(247454),
	  SpiritBombDebuff    = Spell(247456),
    SoulCleave          = Spell(228477),
    SoulFragments       = Spell(203981),
    ThrowGlaive         = Spell(204157),
    -- Offensive
    SoulCarver          = Spell(207407),
    -- Defensive
    DemonSpikes         = Spell(203720),
    DemonSpikesBuff     = Spell(203819),
    FieryBrand          = Spell(204021),
    -- Utility
    Disrupt             = Spell(183752),
    InfernalStrike      = Spell(189110)
  };
  local S = Spell.DemonHunter.Vengeance;
-- Rotation Var

-- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
  };

-- APL Main
local function APL ()
  -- Unit Update
  HL.GetEnemies(20, true); -- Fel Devastation (I think it's 20 thp)
  HL.GetEnemies(8, true); -- Sigil of Flame & Spirit Bomb
  Everyone.AoEToggleEnemiesUpdate();

  -- Misc
  local SoulFragments = Player:BuffStack(S.SoulFragments);
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);

  --- Defensives
  -- Demon Spikes
  if S.DemonSpikes:IsCastable("Melee") and S.DemonSpikes:ChargesFractional() > 1.9 and not Player:Buff(S.DemonSpikesBuff) and (Player:ActiveMitigationNeeded() or Player:HealthPercentage() <= 65) and (IsTanking or not Player:HealingAbsorbed()) then
    if HR.Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "Cast Demon Spikes"; end
  end

  if S.FieryBrand:IsCastable("Melee") and not Player:Buff(S.FieryBrand) and (Player:ActiveMitigationNeeded() or Player:HealthPercentage() <= 40) and (IsTanking or not Player:HealingAbsorbed()) then
    if HR.Cast(S.FieryBrand) then return "Cast Fiery Brand"; end
  end

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ DBM Count
    -- Opener (Shear)
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      -- actions+=/shear
		if Target:IsInRange(30) and S.ThrowGlaive:IsCastable() then
			if HR.Cast(S.ThrowGlaive) then return "Cast Throw Glaive (OoR)"; end
		end
    end
    return;
  end
  --- In Combat
  if Everyone.TargetIsValid() then
    -- Infernal Strike Charges Dump
    if S.InfernalStrike:IsCastable("Melee") and S.InfernalStrike:ChargesFractional() > 1.9 then
      if HR.Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike) then return "Cast Infernal Strike"; end
    end
    -- actions+=/spirit_bomb,if=soul_fragments=5|debuff.frailty.down
    -- Note: Looks like the debuff takes time to refresh so we add TimeSinceLastCast to offset that.
    if S.SpiritBomb:IsCastable() and Target:DebuffRemainsP(S.SpiritBombDebuff) < 10 and Cache.EnemiesCount[8] >= 1 and SoulFragments >= 4 then
      if HR.Cast(S.SpiritBomb) then return "Cast Spirit Bomb"; end
    end
    -- actions+=/immolation_aura,if=pain<=80
    if S.ImmolationAura:IsCastable() and Cache.EnemiesCount[8] >= 1 and not Player:Buff(S.ImmolationAura) and Player:Pain() <= 80 then
      if HR.Cast(S.ImmolationAura) then return "Cast Immolation Aura"; end
    end
    -- actions+=/sigil_of_flame
    if S.SigilofFlame:IsCastable() and Target:DebuffRemainsP(S.SigilofFlameDebuff) <= 3 and Cache.EnemiesCount[8] >= 1 then
      if HR.Cast(S.SigilofFlame) then return "Cast Sigil of Flame"; end
    end
    if Target:IsInRange("Melee") then
      -- actions+=/fracture,if=pain>=60
      if S.Fracture:IsCastable() and (Player:Pain() <= 70 or SoulFragments <= 4) then
        if HR.Cast(S.Fracture) then return "Cast Fracture"; end
      end
      -- actions+=/soul_cleave,if=pain>=80
      if S.SoulCleave:IsCastable() and Target:DebuffRemainsP(S.SpiritBombDebuff) > 10 and (Player:Pain() >= 71 or SoulFragments >= 4) then
        if HR.Cast(S.SoulCleave) then return "Cast Soul Cleave"; end
      end
    end
    if Target:IsInRange(30) and S.ThrowGlaive:IsCastable() then
      if HR.Cast(S.ThrowGlaive) then return "Cast Throw Glaive (OoR)"; end
    end
  end
end

HR.SetAPL(581, APL);

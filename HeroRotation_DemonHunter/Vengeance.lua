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
    Frailty             = Spell(247456),
    ImmolationAura      = Spell(178740),
    InfernalStrike      = Spell(189110),
    Shear               = Spell(203782),
    SigilofFlame        = Spell(204596),
    SigilofFlameDebuff  = Spell(204598),
    SoulCleave          = Spell(228477),
    SoulFragments       = Spell(203981),
    ThrowGlaive         = Spell(204157),
    -- Defensive
    DemonSpikes         = Spell(203720),
    DemonSpikesBuff     = Spell(203819),
    FieryBrand          = Spell(204021),
    FieryBrandDebuff    = Spell(207771),
    -- Talents
    CharredFlesh        = Spell(264002),
    Felblade            = Spell(232893),
    FelDevastation      = Spell(212084),
    Fracture            = Spell(263642),
    SoulBarrier         = Spell(263648),
    SpiritBomb          = Spell(247454),
    SpiritBombDebuff    = Spell(247456),
    -- Utility
    Disrupt             = Spell(183752),
    Metamorphosis       = Spell(191427),
  };
  local S = Spell.DemonHunter.Vengeance;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local CleaveRangeID = tostring(S.Disrupt:ID()); -- 20y range
local SoulFragments, SoulFragmentsAdjusted;
local IsTanking;
local IsInMeleeRange, IsInAoERange;

-- Soul Fragments function taking into consideration aura lag
local function UpdateSoulFragments()
  SoulFragments = Player:BuffStack(S.SoulFragments);

  -- Casting Spirit Bomb or Soul Cleave immediately updates the buff
  if S.SpiritBomb:TimeSinceLastCast() < Player:GCD()
  or S.SoulCleave:TimeSinceLastCast() < Player:GCD() then
    SoulFragmentsAdjusted = 0;
    return;
  end

  -- Check if we have cast Fracture or Shear within the last GCD and haven't "snapshot" yet
  if SoulFragmentsAdjusted == 0 then
    if S.Fracture:TimeSinceLastCast() < Player:GCD() then
      SoulFragmentsAdjusted = math.min(SoulFragments + 2, 5);
    elseif S.Shear:TimeSinceLastCast() < Player:GCD() then
      SoulFragmentsAdjusted = math.min(SoulFragments + 1, 5);
    end
  else
    -- If we have a soul fragement "snapshot", see if we should invalidate it
    if S.Fracture:IsAvailable() then
      if S.Fracture:TimeSinceLastCast() >= Player:GCD() then
        SoulFragmentsAdjusted = 0;
      end
    else
      if S.Shear:TimeSinceLastCast() >= Player:GCD() then
        SoulFragmentsAdjusted = 0;
      end
    end
  end

  -- If we have a higher Soul Fragment "snapshot", use it instead
  if SoulFragmentsAdjusted > SoulFragments then
    SoulFragments = SoulFragmentsAdjusted;
  end
end

-- Melee Is In Range w/ Movement Handlers
local function UpdateIsInMeleeRange()
  if S.Felblade:TimeSinceLastCast() < Player:GCD()
  or S.InfernalStrike:TimeSinceLastCast() < Player:GCD() then
    IsInMeleeRange = true;
    IsInAoERange = true;
    return;
  end

  IsInMeleeRange = Target:IsInRange("Melee");
  IsInAoERange = IsInMeleeRange or Cache.EnemiesCount[8] > 0;
end

-- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
  };

-- APL Main
local function APL ()
  local function Defensives()
    local ActiveMitigationNeeded = Player:ActiveMitigationNeeded();

    -- Demon Spikes
    if S.DemonSpikes:IsCastable("Melee") and S.DemonSpikes:ChargesFractional() > 1.9 and not Player:Buff(S.DemonSpikesBuff)
      and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
    if HR.Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "Cast Demon Spikes"; end
    end

    -- Fiery Brand
    if S.FieryBrand:IsCastable("Melee") and not Player:Buff(S.FieryBrand)
      and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
      if HR.Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand) then return "Cast Fiery Brand"; end
    end

    -- Metamorphosis
    if S.Metamorphosis:IsCastable("Melee") and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold then
      HR.CastSuggested(S.Metamorphosis);
    end
  end

  local function Brand()
    if Settings.Vengeance.BrandForDamage then
      -- actions.brand+=/sigil_of_flame,if=cooldown.fiery_brand.remains<2
      if S.SigilofFlame:IsCastable() and S.FieryBrand:CooldownRemainsP() < 2 then
        if HR.Cast(S.SigilofFlame) then return "Cast Sigil of Flame (Brand Soon)"; end
      end
      -- actions.brand+=/infernal_strike,if=cooldown.fiery_brand.remains=0
      if S.InfernalStrike:IsCastable() and S.FieryBrand:IsReady() then
        if HR.Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike) then return "Cast Infernal Strike (Brand Soon)"; end
      end
      -- actions.brand+=/fiery_brand
      if IsInMeleeRange and S.FieryBrand:IsCastable() then
        if HR.Cast(S.FieryBrand) then return "Cast Fiery Brand (Brand)"; end
      end
    end

    -- Shared condition below: if=dot.fiery_brand.ticking
    if not Target:DebuffP(S.FieryBrandDebuff) then
      return;
    end

    if IsInMeleeRange then
      -- actions.brand+=/immolation_aura,if=dot.fiery_brand.ticking
      if S.ImmolationAura:IsCastable() then
        if HR.Cast(S.ImmolationAura) then return "Cast Immolation Aura (Brand)"; end
      end
      -- actions.brand+=/fel_devastation,if=dot.fiery_brand.ticking
      if S.FelDevastation:IsCastable() then
        if HR.Cast(S.FelDevastation) then return "Cast Fel Devastation (Brand)"; end
      end
    end

    -- actions.brand+=/infernal_strike,if=dot.fiery_brand.ticking
    if S.InfernalStrike:IsCastable()
      and (not Settings.Vengeance.ConserveInfernalStrike or S.InfernalStrike:ChargesFractional() > 1.9) then
      if HR.Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike) then return "Cast Infernal Strike (Brand)"; end
    end
    -- actions.brand+=/sigil_of_flame,if=dot.fiery_brand.ticking
    if S.SigilofFlame:IsCastable() then
      if HR.Cast(S.SigilofFlame) then return "Cast Sigil of Flame (Brand)"; end
    end
  end

  local function Normal()
    -- actions+=/infernal_strike
    if S.InfernalStrike:IsCastable() and not (S.CharredFlesh:IsAvailable() and Settings.Vengeance.BrandForDamage)
      and (not Settings.Vengeance.ConserveInfernalStrike or S.InfernalStrike:ChargesFractional() > 1.9) then
      if HR.Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike) then return "Cast Infernal Strike"; end
    end
    -- actions+=/spirit_bomb,if=soul_fragments>=4
    -- Note: Use IsAvailable() here since IsCastable() can't predict properly since Spirit Bomb is not usable with 0 fragments
    if S.SpiritBomb:IsAvailable() and IsInAoERange and SoulFragments >= 4 then
      if HR.Cast(S.SpiritBomb) then return "Cast Spirit Bomb"; end
    end
    -- actions+=/immolation_aura,if=pain<=90
    if S.ImmolationAura:IsCastable() and IsInAoERange and Player:Pain() <= 90 then
      if HR.Cast(S.ImmolationAura) then return "Cast Immolation Aura"; end
    end
    -- actions+=/felblade,if=pain<=70
    if S.Felblade:IsCastable(S.Felblade) and Player:Pain() <= 70 then
      if HR.Cast(S.Felblade) then return "Cast Felblade"; end
    end
    if S.Fracture:IsAvailable() and IsInMeleeRange then
      -- actions.normal+=/soul_cleave,if=talent.spirit_bomb.enabled&talent.fracture.enabled&soul_fragments=0&cooldown.fracture.charges_fractional<1.75
      if S.SoulCleave:IsReady() and SoulFragments == 0 and S.Fracture:ChargesFractional() < 1.75 then
        if HR.Cast(S.SoulCleave) then return "Cast Soul Cleave (Filler)"; end
      end
      -- actions+=/fracture,if=soul_fragments<=3
      if IsInMeleeRange and S.Fracture:IsCastable() and SoulFragments <= 3 then
        if HR.Cast(S.Fracture) then return "Cast Fracture"; end
      end
    end
    -- actions+=/fel_devastation
    if S.FelDevastation:IsCastable() and IsInAoERange then
      if HR.Cast(S.FelDevastation) then return "Cast Fel Devastation"; end
    end
    -- actions+=/soul_cleave,if=!talent.spirit_bomb.enabled
    -- actions+=/soul_cleave,if=talent.spirit_bomb.enabled&soul_fragments=0
    if S.SoulCleave:IsReady() then
      if not S.SpiritBomb:IsAvailable() then
        if HR.Cast(S.SoulCleave) then return "Cast Soul Cleave"; end
      elseif SoulFragments == 0 then
        if HR.Cast(S.SoulCleave) then return "Cast Soul Cleave (Spirit Bomb)"; end
      end
    end
    -- actions+=/sigil_of_flame
    if S.SigilofFlame:IsCastable() and IsInAoERange and Target:DebuffRemainsP(S.SigilofFlameDebuff) <= 3 then
      if HR.Cast(S.SigilofFlame) then return "Cast Sigil of Flame"; end
    end
    -- actions+=/shear
    if IsInMeleeRange and S.Shear:IsReady() then
      if HR.Cast(S.Shear) then return "Cast Shear"; end
    end
    -- actions+=/throw_glaive
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) then
      if HR.Cast(S.ThrowGlaive) then return "Cast Throw Glaive (OOR)"; end
    end
  end

  -- Unit Update
  HL.GetEnemies(8, true); -- Sigil of Flame & Spirit Bomb
  -- 20y check is not needed for the current APL, uncomment if needed
  -- HL.GetEnemies(S.Disrupt, true); -- 20y, use for TG Bounce and Fel Devastation
  Everyone.AoEToggleEnemiesUpdate();

  -- Misc
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);
  UpdateSoulFragments();
  UpdateIsInMeleeRange();

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ DBM Count
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      return Normal();
    end
    return;
  end

  --- Defensives
  if (IsTanking or not Player:HealingAbsorbed()) then
    ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    if S.CharredFlesh:IsAvailable() then
      ShouldReturn = Brand(); if ShouldReturn then return ShouldReturn; end
    end
    return Normal();
  end
end

HR.SetAPL(581, APL);

--- ======= SIMC =======
--- Last Update: 07/21/2018

--[[

# Executed every time the actor is available.
actions=auto_attack
actions+=/consume_magic
# ,if=!raid_event.adds.exists|active_enemies>1
actions+=/use_item,slot=trinket1
actions+=/call_action_list,name=brand,if=talent.charred_flesh.enabled
actions+=/call_action_list,name=defensives
actions+=/call_action_list,name=normal

# Fiery Brand Rotation
actions.brand=sigil_of_flame,if=cooldown.fiery_brand.remains<2
actions.brand+=/infernal_strike,if=cooldown.fiery_brand.remains=0
actions.brand+=/fiery_brand
actions.brand+=/immolation_aura,if=dot.fiery_brand.ticking
actions.brand+=/fel_devastation,if=dot.fiery_brand.ticking
actions.brand+=/infernal_strike,if=dot.fiery_brand.ticking
actions.brand+=/sigil_of_flame,if=dot.fiery_brand.ticking

# Defensives
actions.defensives=demon_spikes
actions.defensives+=/metamorphosis
actions.defensives+=/fiery_brand

# Normal Rotation
actions.normal=infernal_strike
actions.normal+=/spirit_bomb,if=soul_fragments>=4
actions.normal+=/immolation_aura,if=pain<=90
actions.normal+=/felblade,if=pain<=70
actions.normal+=/soul_cleave,if=talent.spirit_bomb.enabled&talent.fracture.enabled&soul_fragments=0&cooldown.fracture.charges_fractional<1.75
actions.normal+=/fracture,if=soul_fragments<=3
actions.normal+=/fel_devastation
actions.normal+=/soul_cleave,if=!talent.spirit_bomb.enabled
actions.normal+=/soul_cleave,if=talent.spirit_bomb.enabled&soul_fragments=0
actions.normal+=/sigil_of_flame
actions.normal+=/shear
actions.normal+=/throw_glaive

--]]
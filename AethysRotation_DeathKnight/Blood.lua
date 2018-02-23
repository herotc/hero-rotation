--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local DeathKnight = AR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Blood = {
    -- Racials
    ArcaneTorrent         = Spell(50613),
    Berserking            = Spell(26297),
    BloodFury             = Spell(20572),
    -- Abilities
    BloodBoil             = Spell(50842),
    BloodDrinker          = Spell(206931),
    BloodMirror           = Spell(206977),
    BloodPlague           = Spell(55078),
    BloodShield           = Spell(77535),
    BoneShield            = Spell(195181),
    Bonestorm             = Spell(194844),
    Consumption           = Spell(205223),
    CrimsonScourge        = Spell(81141),
    DancingRuneWeapon     = Spell(49028),
    DancingRuneWeaponBuff = Spell(81256),
    DeathandDecay         = Spell(43265),
    DeathsCaress          = Spell(195292),
    DeathStrike           = Spell(49998),
    HeartBreaker          = Spell(221536),
    HeartStrike           = Spell(206930),
    Marrowrend            = Spell(195182),
    MindFreeze            = Spell(47528),
    Ossuary               = Spell(219786),
    RapidDecomposition    = Spell(194662),
    VampiricBlood         = Spell(55233),
    -- Legendaries
    HaemostasisBuff       = Spell(235558),
    -- Misc
    Pool            = Spell(9999000010)
  };
  local S = Spell.DeathKnight.Blood;
  if not Item.DeathKnight then Item.DeathKnight = {}; end
    Item.DeathKnight.Blood = {
    --Legendaries
    --Potion
    ProlongedPower = Item(142117)
  };
  local I = Item.DeathKnight.Blood;
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DeathKnight.Commons,
    Blood = AR.GUISettings.APL.DeathKnight.Blood
  };


--- ======= ACTION LISTS =======
local function SimulationcraftAPL()
  if AR.CDsON() and Target:IsInRange("Melee") then
    -- arcane_torrent,if=runic_power.deficit>20
    if Settings.Blood.Enabled.ArcaneTorrent and S.ArcaneTorrent:IsCastableP() and (Player:RunicPowerDeficit() > 20) then
      if AR.Cast(S.ArcaneTorrent, Settings.Blood.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and (true) then
      if AR.Cast(S.BloodFury, Settings.Blood.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- berserking,if=buff.dancing_rune_weapon.up
    if S.Berserking:IsCastableP() and (Player:BuffP(S.DancingRuneWeaponBuff)) then
      if AR.Cast(S.Berserking, Settings.Blood.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- potion,if=buff.dancing_rune_weapon.up
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.DancingRuneWeaponBuff)) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- dancing_rune_weapon,if=(!talent.blooddrinker.enabled|!cooldown.blooddrinker.ready)&!cooldown.death_and_decay.ready
    if Settings.Blood.Enabled.DancingRuneWeapon and S.DancingRuneWeapon:IsCastableP() and ((not S.BloodDrinker:IsAvailable() or not S.BloodDrinker:CooldownUpP()) and not S.DeathandDecay:CooldownUpP()) then
      if AR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
    end
  end
  -- actions.standard=death_strike,if=runic_power.deficit<=15
  if S.DeathStrike:IsUsable("Melee") and Player:RunicPowerDeficit() <= 15 then
    if AR.Cast(S.DeathStrike) then return ""; end
  end
  -- actions.standard+=/death_and_decay,if=talent.rapid_decomposition.enabled&!buff.dancing_rune_weapon.up
  if S.DeathandDecay:IsCastableP("Melee") and S.RapidDecomposition:IsLearned() and not Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end
  -- actions.standard+=/blooddrinker,if=!buff.dancing_rune_weapon.up
  if S.BloodDrinker:IsCastableP(30) and not Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.Cast(S.BloodDrinker,Settings.Blood.GCDasOffGCD.BloodDrinker) then return ""; end
  end
  -- actions.standard+=/marrowrend,if=buff.bone_shield.remains<=gcd*2
  if S.Marrowrend:IsCastableP("Melee") and Player:BuffRemains(S.BoneShield) <= Player:GCD() * 2 then
    if AR.Cast(S.Marrowrend) then return ""; end
  end
  -- actions.standard+=/blood_boil,if=charges_fractional>=1.8&buff.haemostasis.stack<5&(buff.haemostasis.stack<3|!buff.dancing_rune_weapon.up)
  if S.BloodBoil:IsCastableP(10, true) and S.BloodBoil:ChargesFractional() >= 1.8 and Player:BuffStack(S.HaemostasisBuff) < 5 and (Player:BuffStack(S.HaemostasisBuff) < 3 or not Player:Buff(S.DancingRuneWeaponBuff)) then
    if AR.Cast(S.BloodBoil) then return ""; end
  end
  -- actions.standard+=/marrowrend,if=(buff.bone_shield.stack<5&talent.ossuary.enabled)|buff.bone_shield.remains<gcd*3
  if S.Marrowrend:IsCastableP("Melee") and ((Player:BuffStack(S.BoneShield) < 5 and S.Ossuary:IsAvailable()) or Player:BuffRemainsP(S.BoneShield) < (Player:GCD() * 3)) then
    if AR.Cast(S.Marrowrend) then return ""; end
  end
  -- actions.standard+=/death_strike,if=buff.blood_shield.up|(runic_power.deficit<15&runic_power.deficit<25|!buff.dancing_rune_weapon.up)
  if S.DeathStrike:IsUsable("Melee") and Player:RunicPowerDeficit() <= 40 and (Player:Buff(S.BloodShield) or not Player:Buff(S.DancingRuneWeaponBuff)) then
    if AR.Cast(S.DeathStrike) then return ""; end
  end
  -- actions.standard+=/consumption
  if Settings.Blood.Enabled.Consumption and S.Consumption:IsCastableP("Melee") then
    if AR.Cast(S.Consumption) then return ""; end
  end
  -- actions.standard+=/heart_strike,if=buff.dancing_rune_weapon.up
  if S.HeartStrike:IsCastableP("Melee") and Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.Cast(S.HeartStrike) then return ""; end
  end
  -- actions.standard+=/death_and_decay,if=buff.crimson_scourge.up
  if S.DeathandDecay:IsUsable(30) and Player:Buff(S.CrimsonScourge) then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end
  -- actions.standard+=/blood_boil,if=buff.haemostasis.stack<5&(buff.haemostasis.stack<3|!buff.dancing_rune_weapon.up)
  if S.BloodBoil:IsCastableP(10, true) and Player:BuffStack(S.HaemostasisBuff) < 5 and (Player:BuffStack(S.HaemostasisBuff) < 3 or not Player:Buff (S.DancingRuneWeaponBuff)) then
    if AR.Cast(S.BloodBoil) then return ""; end
  end
  -- actions.standard+=/death_and_decay
  if S.DeathandDecay:IsCastableP("Melee") then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end
  -- actions.standard+=/heart_strike,if=rune.time_to_3<gcd|buff.bone_shield.stack>6
  if S.HeartStrike:IsCastableP("Melee") and Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStack(S.BoneShield) > 6 then
    if AR.Cast(S.HeartStrike) then return ""; end
  end

  return false;
end

local function IcyVeinsRotation()
  if Settings.Blood.Enabled.ArcaneTorrent and AR.CDsON() and S.ArcaneTorrent:IsCastableP("Melee") and (Player:RunicPowerDeficit() > 20) then
    if AR.Cast(S.ArcaneTorrent, Settings.Blood.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
  end

  if Settings.Blood.Enabled.DancingRuneWeapon and AR.CDsON() and S.DancingRuneWeapon:IsCastableP("Melee") then
    if AR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
  end

  if S.Marrowrend:IsCastableP("Melee") and Player:BuffRemains(S.BoneShield) <= (Player:GCD() * 2) then
    if AR.Cast(S.Marrowrend) then return ""; end
  end

  if S.BloodBoil:IsCastableP(10, true) and Cache.EnemiesCount[10] >= 1 and not Target:Debuff(S.BloodPlague) then
    if AR.Cast(S.BloodBoil) then return ""; end
  end

  if AR.CDsON() and S.Bonestorm:IsCastableP("Melee") and Cache.EnemiesCount[8] >= 1 and Player:RunicPower() >= 100 then
    if AR.Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm) then return ""; end
  end
  
  if S.DeathandDecay:IsUsable("Melee") and (Cache.EnemiesCount[8] == 1 and Player:Buff(S.CrimsonScourge) and S.RapidDecomposition:IsAvailable()) or (Cache.EnemiesCount[8] > 1 and Player:Buff(S.CrimsonScourge)) then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end

  if S.BloodDrinker:IsCastableP(30) and S.BloodDrinker:IsLearned() and not Player:Buff(S.DancingRuneWeaponBuff) and Player:RunicPowerDeficit() >= 10 then
    if AR.Cast(S.BloodDrinker, Settings.Blood.GCDasOffGCD.BloodDrinker) then return ""; end
  end
  
  if S.DeathStrike:IsUsable("Melee") and S.BloodDrinker:IsCastableP() and (S.BloodDrinker:IsAvailable() or S.BloodDrinker:CooldownRemains() <= Player:GCD()) and not Player:Buff(S.DancingRuneWeaponBuff) and ((Player:RuneTimeToX(1) <= Player:GCD()) or Player:Runes() >= 1) then
    if AR.Cast(S.DeathStrike) then return ""; end
  end

  if S.Marrowrend:IsCastableP("Melee") and Player:BuffStack(S.BoneShield) <= 6 and Player:RunicPowerDeficit() >= 20 then
    if AR.Cast(S.Marrowrend) then return ""; end
  end
  
  if S.DeathStrike:IsUsable("Melee") and S.Marrowrend:IsCastableP() and Player:BuffStack(S.BoneShield) <= 6 then
    if AR.Cast(S.DeathStrike) then return ""; end
  end

  if S.DeathandDecay:IsUsable("Melee") and ((Cache.EnemiesCount[8] == 1 and Player:Runes() >= 3 and S.RapidDecomposition:IsAvailable() and S.DeathandDecay:CooldownRemains() == 0)  or (Cache.EnemiesCount[8] >= 3 and S.DeathandDecay:CooldownRemains() == 0)) and Player:RunicPowerDeficit() >= 10 then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end

  if S.HeartStrike:IsCastableP("Melee") and ((Player:RuneTimeToX(3) <= Player:GCD()) or Player:Runes() >=3) and (Player:RunicPowerDeficit()>= 15 or (S.HeartBreaker:IsAvailable() and Player:Buff(S.DeathandDecay) and Player:RunicPowerDeficit() >= (15 + math.min(Cache.EnemiesCount["Melee"], 5) * 2))) then
    if AR.Cast(S.HeartStrike) then return ""; end
  end

  if S.DeathStrike:IsUsable("Melee") and (Player:RuneTimeToX(3) <= Player:GCD() or Player:Runes() >= 3 or Player:RunicPowerDeficit() <= 10) then
    if AR.Cast(S.DeathStrike) then return ""; end
  end

  if S.DeathandDecay:IsUsable("Melee") and Player:Buff(S.CrimsonScourge) and not S.RapidDecomposition:IsAvailable() then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end

  if S.Consumption:IsCastableP("Melee") then 
    if AR.Cast(S.Consumption) then return ""; end
  end

  if S.BloodBoil:IsCastableP(10, true) then
    if AR.Cast(S.BloodBoil) then return ""; end
  end

  return false;
end

--- ======= MAIN =======
local function APL ()
  -- Unit Update
  AC.GetEnemies("Melee");
  AC.GetEnemies(8, true); -- Death and Decay & Bonestorm
  AC.GetEnemies(10, true); -- Blood Boil
  AC.GetEnemies(20, true);

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Interrupt
    if Settings.General.InterruptEnabled and Target:IsInterruptible() and S.MindFreeze:IsCastableP("Melee") then
      if AR.CastAnnotated(S.MindFreeze, false, "Interrupt") then return ""; end
    end
    -- APL
    local ShouldReturn;
    if Settings.Blood.RotationToFollow == "Icy Veins" then
      ShouldReturn = IcyVeinsRotation();
    else
      ShouldReturn = SimulationcraftAPL();
    end
    if ShouldReturn then return ShouldReturn; end
    -- Out of Range
    if S.DeathsCaress:IsCastableP(30) and Player:Runes() > 3 then
      if AR.Cast(S.DeathsCaress) then return "";end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.HeartStrike:IsCastable("Melee") then
      if AR.Cast(S.Pool) then return "Normal Pooling"; end
    end
  end
end

AR.SetAPL(250,APL);

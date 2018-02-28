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
    Blooddrinker          = Spell(206931),
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
    RuneTap               = Spell(194679),
    UmbilicusEternus      = Spell(193249),
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
  


--- ======= MAIN =======
local function APL ()
  -- Unit Update
  AC.GetEnemies("Melee");
  AC.GetEnemies(8, true); -- Death and Decay & Bonestorm
  AC.GetEnemies(10, true); -- Blood Boil
  AC.GetEnemies(20, true);

  -- In Combat
  if Everyone.TargetIsValid() then
    --- Misc
    -- Units without Blood Plague
    local UnitsWithoutBloodPlague = 0;
    for _, CycleUnit in pairs(Cache.Enemies[10]) do
      if not CycleUnit:Debuff(S.BloodPlague) then
        UnitsWithoutBloodPlague = UnitsWithoutBloodPlague + 1;
      end
    end

    --- Defensives
    -- Umbilicus Eternus Cancel
    if Settings.Blood.UmbilicusEternus > 0 and Player:Buff(S.UmbilicusEternus) and Player:BuffRemains(S.UmbilicusEternus) <= Settings.Blood.UmbilicusEternus then
      if AR.Cast(S.UmbilicusEternus, true) then return ""; end
    end
    -- Rune Tap Emergency
    if S.RuneTap:IsReady() and Player:HealthPercentage() <= 40 and Player:Runes() >= 3 and S.RuneTap:Charges() > 1 and not Player:Buff(S.RuneTap) then
      if AR.Cast(S.RuneTap, true) then return ""; end
    end
    -- Active Mitigation
    if Player:ActiveMitigationNeeded() and S.Marrowrend:TimeSinceLastCast() > 2.5 and S.DeathStrike:TimeSinceLastCast() > 2.5 then
      if S.DeathStrike:IsReady("Melee") and Player:BuffStack(S.BoneShield) > 7 then
        if AR.Cast(S.DeathStrike) then return ""; end
      end
      if S.Marrowrend:IsCastableP("Melee") then
        if AR.Cast(S.Marrowrend) then return ""; end
      end
      if S.DeathStrike:IsReady("Melee") then
        if AR.Cast(S.DeathStrike) then return ""; end
      end
    end
    -- Bone Shield
    if S.Marrowrend:IsCastableP("Melee") and Player:BuffRemains(S.BoneShield) <= Player:GCD() * 2 then
      if AR.Cast(S.Marrowrend) then return ""; end
    end 
    -- Healing
    if S.DeathStrike:IsReady("Melee") and Player:HealthPercentage() <= 50 + (Player:RunicPower() > 90 and 20 or 0) and not Player:HealingAbsorbed() then
      if AR.Cast(S.DeathStrike) then return ""; end
    end

    --- Utility
    -- Interrupt
    if Settings.General.InterruptEnabled and Target:IsInterruptible() and S.MindFreeze:IsCastableP("Melee") then
      if AR.CastAnnotated(S.MindFreeze, false, "Interrupt") then return ""; end
    end

    --- APL
    -- Pool during Blooddrinker if enabled
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffRemains(S.BoneShield) and UnitsWithoutBloodPlague == 0 and not Player:ShouldStopCasting() and Player:CastRemains() > 0.2 then
      if AR.Cast(S.Pool) then return "Blooddrinker Pooling"; end
    end
    -- Arcane Torrent
    if Settings.Blood.Enabled.ArcaneTorrent and AR.CDsON() and S.ArcaneTorrent:IsCastableP("Melee") and (Player:RunicPowerDeficit() > 20) then
      if AR.Cast(S.ArcaneTorrent, Settings.Blood.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- Dancing Rune Weapon
    if Settings.Blood.Enabled.DancingRuneWeapon and AR.CDsON() and S.DancingRuneWeapon:IsCastableP("Melee") and (not S.Blooddrinker:IsAvailable() or not S.Blooddrinker:CooldownUpP()) then
      if AR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
    end
    -- Blood Boil refresh Blood Plague
    if S.BloodBoil:IsCastableP() and Cache.EnemiesCount[10] >= 1 and UnitsWithoutBloodPlague >= 1 then
      if AR.Cast(S.BloodBoil) then return ""; end
    end
    -- Bonestorm
    if AR.CDsON() and S.Bonestorm:IsCastableP("Melee") and Cache.EnemiesCount[8] >= 1 and Player:RunicPower() >= 100 then
      if AR.Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm) then return ""; end
    end
    -- 
    if AR.AoEON() and S.DeathandDecay:IsReady("Melee") and (Cache.EnemiesCount[8] == 1 and Player:Buff(S.CrimsonScourge) and S.RapidDecomposition:IsAvailable()) or (Cache.EnemiesCount[8] > 1 and Player:Buff(S.CrimsonScourge)) then
      if AR.Cast(S.DeathandDecay) then return ""; end
    end
    -- 
    if S.Blooddrinker:IsCastableP(30) and S.Blooddrinker:IsLearned() and not Player:ShouldStopCasting() and not Player:Buff(S.DancingRuneWeaponBuff) and Player:RunicPowerDeficit() >= 15 then
      if AR.Cast(S.Blooddrinker, Settings.Blood.GCDasOffGCD.Blooddrinker) then return ""; end
    end
    -- 
    if S.DeathStrike:IsReady("Melee") and S.Blooddrinker:IsCastableP() and (S.Blooddrinker:IsAvailable() or S.Blooddrinker:CooldownRemains() <= Player:GCD()) and not Player:Buff(S.DancingRuneWeaponBuff) and ((Player:RuneTimeToX(1) <= Player:GCD()) or Player:Runes() >= 1) then
      if AR.Cast(S.DeathStrike) then return ""; end
    end
    -- 
    if S.Marrowrend:IsCastableP("Melee") and Player:BuffStack(S.BoneShield) <= 6 and Player:RunicPowerDeficit() >= 20 then
      if AR.Cast(S.Marrowrend) then return ""; end
    end
    -- 
    if S.DeathStrike:IsReady("Melee") and S.Marrowrend:IsCastableP() and Player:BuffStack(S.BoneShield) <= 6 then
      if AR.Cast(S.DeathStrike) then return ""; end
    end
    -- Death and Decay: ST Rapid Decomposition / AoE
    if AR.AoEON() and S.DeathandDecay:IsReady("Melee") and Player:RunicPowerDeficit() >= 10 and ((Cache.EnemiesCount[8] == 1 and Player:Runes() >= 3 and S.RapidDecomposition:IsAvailable()) or Cache.EnemiesCount[8] >= 3) then
      if AR.Cast(S.DeathandDecay) then return ""; end
    end
    -- Hearth Strike
    if S.HeartStrike:IsCastableP("Melee") and ((Player:RuneTimeToX(3) <= Player:GCD()) or Player:Runes() >=3) and (Player:RunicPowerDeficit()>= 15 or (S.HeartBreaker:IsAvailable() and Player:Buff(S.DeathandDecay) and Player:RunicPowerDeficit() >= (15 + math.min(Cache.EnemiesCount["Melee"], 5) * 2))) then
      if AR.Cast(S.HeartStrike) then return ""; end
    end
    -- Death Strike Runic Power Dump
    if S.DeathStrike:IsReady("Melee") and (Player:RuneTimeToX(3) <= Player:GCD() or Player:Runes() >= 3 or Player:RunicPowerDeficit() <= 15) then
      if AR.Cast(S.DeathStrike) then return ""; end
    end
    -- Death and Decay ST
    if AR.AoEON() and S.DeathandDecay:IsReady("Melee") and Player:Buff(S.CrimsonScourge) and not S.RapidDecomposition:IsAvailable() then
      if AR.Cast(S.DeathandDecay) then return ""; end
    end
    -- Consumption
    if S.Consumption:IsCastableP("Melee") then
      if Settings.Blood.Enabled.Consumption then
        if AR.Cast(S.Consumption) then return ""; end
      elseif Settings.Blood.ConsumptionSuggested then
        AR.CastSuggested(S.Consumption);
      end
    end
    -- Death's Caress Pull
    if S.DeathsCaress:IsCastableP(30) and not Target:IsInRange(10) and not Target:Debuff(S.BloodPlague) then
      if AR.Cast(S.DeathsCaress) then return "";end
    end
    -- Blood Boil
    if S.BloodBoil:IsCastableP() and Cache.EnemiesCount[10] >= 1 then
      if AR.Cast(S.BloodBoil) then return ""; end
    end
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

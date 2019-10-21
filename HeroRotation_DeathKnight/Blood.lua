--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Spells
if not Spell.DeathKnight then Spell.DeathKnight = {}; end
Spell.DeathKnight.Blood = {
  -- Racials
  ArcaneTorrent         = Spell(50613),
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),
  -- Abilities
  Asphyxiate            = Spell(221562),
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
  HemostasisBuff        = Spell(273947),
  Marrowrend            = Spell(195182),
  MindFreeze            = Spell(47528),
  Ossuary               = Spell(219786),
  RapidDecomposition    = Spell(194662),
  RuneStrike            = Spell(210764),
  RuneTap               = Spell(194679),
  Tombstone             = Spell(219809),
  TombstoneBuff         = Spell(219809),
  VampiricBlood         = Spell(55233),
  -- Trinket Effects
  RazorCoralDebuff      = Spell(303568),
  -- Misc
  Pool                  = Spell(9999000010)
};
local S = Spell.DeathKnight.Blood;

-- Items
if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Blood = {
  --Potion
  PotionofUnbridledFury            = Item(169299),
  GrongsPrimalRage                 = Item(165574, {13, 14}),
  RazdunksBigRedButton             = Item(159611, {13, 14}),
  MerekthasFang                    = Item(158367, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14})
};
local I = Item.DeathKnight.Blood;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local UnitsWithoutBloodPlague;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Blood = HR.GUISettings.APL.DeathKnight.Blood
};

-- Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
};

-- Functions
local EnemyRanges = {10, 8}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function UnitsWithoutBP()
  local WithoutBPCount = 0
  for _, CycleUnit in pairs(Cache.Enemies[10]) do
    if not CycleUnit:Debuff(S.BloodPlague) then
      WithoutBPCount = WithoutBPCount + 1
    end
  end
  return WithoutBPCount
end

--- ======= ACTION LISTS =======
local function APL ()
  local Precombat, Defensives, Standard
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  -- Get count of units without Blood Plague
  UnitsWithoutBloodPlague = UnitsWithoutBP()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.Cast(I.PotionofUnbridledFury, Settings.Commons.OffGCDasOffGCD.Potions) then return ""; end
      end
      -- Manually Added: Death's Caress for ranged pulling
      if S.DeathsCaress:IsReady() then
        if HR.Cast(S.DeathsCaress) then return ""; end
      end
    end
  end
  Defensives = function()
    -- Rune Tap Emergency
    if S.RuneTap:IsReady() and Player:HealthPercentage() <= 40 and Player:Rune() >= 3 and S.RuneTap:Charges() > 1 and Player:BuffDown(S.RuneTap) then
      if HR.Cast(S.RuneTap, true) then return ""; end
    end
    -- Active Mitigation
    if Player:ActiveMitigationNeeded() and S.Marrowrend:TimeSinceLastCast() > 2.5 and S.DeathStrike:TimeSinceLastCast() > 2.5 then
      if S.DeathStrike:IsReady("Melee") and Player:BuffStack(S.BoneShield) > 7 then
        if HR.Cast(S.DeathStrike) then return ""; end
      end
      if S.Marrowrend:IsCastable("Melee") then
        if HR.Cast(S.Marrowrend) then return ""; end
      end
      if S.DeathStrike:IsReady("Melee") then
        if HR.Cast(S.DeathStrike) then return ""; end
      end
    end
    -- Bone Shield
    if S.Marrowrend:IsCastable("Melee") and (Player:BuffRemainsP(S.BoneShield) <= 6 or (Target:TimeToDie() < 5 and Player:BuffRemainsP(S.BoneShield) < 10 and Cache.EnemiesCount[8] == 1)) then
      if HR.Cast(S.Marrowrend) then return ""; end
    end 
    -- Healing
    if S.DeathStrike:IsReady("Melee") and Player:HealthPercentage() <= 50 + (Player:RunicPower() > 90 and 20 or 0) and not Player:HealingAbsorbed() then
      if HR.Cast(S.DeathStrike) then return ""; end
    end
  end
  Standard = function()
    -- death_strike,if=runic_power.deficit<=10
    if S.DeathStrike:IsReady("Melee") and (Player:RunicPowerDeficit() <= 10) then
      if HR.Cast(S.DeathStrike) then return ""; end
    end
    -- blooddrinker,if=!buff.dancing_rune_weapon.up
    if S.Blooddrinker:IsCastable(30) and not Player:ShouldStopCasting() and (Player:BuffDownP(S.DancingRuneWeaponBuff)) then
      if HR.Cast(S.Blooddrinker, Settings.Blood.GCDasOffGCD.Blooddrinker) then return ""; end
    end
    -- marrowrend,if=(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*2)|buff.bone_shield.stack<3)&runic_power.deficit>=20
    if S.Marrowrend:IsCastable("Melee") and ((Player:BuffRemainsP(S.BoneShield) <= Player:RuneTimeToX(3) or Player:BuffRemainsP(S.BoneShield) <= (Player:GCD() + num(S.Blooddrinker:CooldownUpP()) * num(S.Blooddrinker:IsAvailable()) * 2) or Player:BuffStackP(S.BoneShield) < 3) and Player:RunicPowerDeficit() >= 20) then
      if HR.Cast(S.Marrowrend) then return ""; end
    end
    -- heart_essence,if=!buff.dancing_rune_weapon.up
    -- TODO: Make heart_essence work
    -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
    if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 and (S.BloodBoil:ChargesFractionalP() >= 1.8 and (Player:BuffStackP(S.HemostasisBuff) <= (5 - Cache.EnemiesCount[10]) or Cache.EnemiesCount[10] > 2)) then
      if HR.Cast(S.BloodBoil) then return ""; end
    end
    -- marrowrend,if=buff.bone_shield.stack<5&talent.ossuary.enabled&runic_power.deficit>=15
    if S.Marrowrend:IsCastable("Melee") and (Player:BuffStackP(S.BoneShield) < 5 and S.Ossuary:IsAvailable() and Player:RunicPowerDeficit() >= 15) then
      if HR.Cast(S.Marrowrend) then return ""; end
    end
    -- bonestorm,if=runic_power>=100&!buff.dancing_rune_weapon.up
    if S.Bonestorm:IsCastable("Melee") and HR.CDsON() and (Player:RunicPower() >= 100 and Player:BuffDownP(S.DancingRuneWeaponBuff)) then
      if HR.Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm) then return ""; end
    end
    -- death_strike,if=runic_power.deficit<=(15+buff.dancing_rune_weapon.up*5+spell_targets.heart_strike*talent.heartbreaker.enabled*2)|target.1.time_to_die<10
    if S.DeathStrike:IsReady("Melee") and (Player:RunicPowerDeficit() <= (15 + num(Player:BuffP(S.DancingRuneWeaponBuff)) * 5 + Cache.EnemiesCount[8] * num(S.HeartBreaker:IsAvailable()) * 2) or Target:TimeToDie() < 10) then
      if HR.Cast(S.DeathStrike) then return ""; end
    end
    -- death_and_decay,if=spell_targets.death_and_decay>=3
    if S.DeathandDecay:IsReady() and (Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.DeathandDecay) then return ""; end
    end
    -- rune_strike,if=(charges_fractional>=1.8|buff.dancing_rune_weapon.up)&rune.time_to_3>=gcd
    if S.RuneStrike:IsCastable("Melee") and ((S.RuneStrike:ChargesFractionalP() >= 1.8 or Player:BuffP(S.DancingRuneWeaponBuff)) and Player:RuneTimeToX(3) >= Player:GCD()) then
      if HR.Cast(S.RuneStrike) then return ""; end
    end
    -- heart_strike,if=buff.dancing_rune_weapon.up|rune.time_to_4<gcd
    if S.HeartStrike:IsReady("Melee") and (Player:BuffP(S.DancingRuneWeaponBuff) or Player:RuneTimeToX(4) < Player:GCD()) then
      if HR.Cast(S.HeartStrike) then return ""; end
    end
    -- blood_boil,if=buff.dancing_rune_weapon.up
    if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 and (Player:BuffP(S.DancingRuneWeaponBuff)) then
      if HR.Cast(S.BloodBoil) then return ""; end
    end
    -- death_and_decay,if=buff.crimson_scourge.up|talent.rapid_decomposition.enabled|spell_targets.death_and_decay>=2
    if S.DeathandDecay:IsReady() and Cache.EnemiesCount[10] >= 1 and (Player:BuffP(S.CrimsonScourge) or S.RapidDecomposition:IsAvailable() or Cache.EnemiesCount[10] >= 2) then
      if HR.Cast(S.DeathandDecay) then return ""; end
    end
    -- consumption
    if S.Consumption:IsCastable("Melee") then
      if HR.Cast(S.Consumption, nil, Settings.Blood.ConsumptionDisplayStyle) then return ""; end
    end
    -- blood_boil
    if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 then
      if HR.Cast(S.BloodBoil) then return ""; end
    end
    -- heart_strike,if=rune.time_to_3<gcd|buff.bone_shield.stack>6
    if S.HeartStrike:IsReady("Melee") and (Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStackP(S.BoneShield) > 6) then
      if HR.Cast(S.HeartStrike) then return ""; end
    end
    -- use_item,name=grongs_primal_rage
    if I.GrongsPrimalRage:IsEquipReady() then
      if HR.Cast(I.GrongsPrimalRage, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
    end
    -- rune_strike
    if S.RuneStrike:IsCastable("Melee") then
      if HR.Cast(S.RuneStrike) then return ""; end
    end
    -- arcane_torrent,if=runic_power.deficit>20
    if S.ArcaneTorrent:IsCastable("Melee") and (Player:RunicPowerDeficit() > 20) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts);
    -- Manually Added: Call Defensives
    if (true) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool during Blooddrinker if enabled
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffP(S.BoneShield) and UnitsWithoutBloodPlague == 0 and not Player:ShouldStopCasting() and Player:CastRemains() > 0.2 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool During Blooddrinker"; end
    end
    -- auto_attack
    -- blood_fury,if=cooldown.dancing_rune_weapon.ready&(!cooldown.blooddrinker.ready|!talent.blooddrinker.enabled)
    if S.BloodFury:IsCastable() and HR.CDsON() and Cache.EnemiesCount[10] >= 1 and (S.DancingRuneWeapon:CooldownUpP() and (not S.Blooddrinker:CooldownUpP() or not S.Blooddrinker:IsAvailable())) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastable() and HR.CDsON() and Cache.EnemiesCount[10] >= 1 then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- use_items,if=cooldown.dancing_rune_weapon.remains>90
    -- use_item,name=razdunks_big_red_button
    if I.RazdunksBigRedButton:IsEquipReady() then
      if HR.Cast(I.RazdunksBigRedButton, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
    end
    -- use_item,name=merekthas_fang
    if I.MerekthasFang:IsEquipReady() then
      if HR.Cast(I.MerekthasFang, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down
    if I.AshvanesRazorCoral:IsEquipReady() and (Target:DebuffDownP(S.RazorCoralDebuff)) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
    end
    -- use_item,name=ashvanes_razor_coral,if=buff.dancing_rune_weapon.up&debuff.razor_coral_debuff.up
    if I.AshvanesRazorCoral:IsEquipReady() and (Player:BuffP(S.DancingRuneWeaponBuff) and Target:DebuffP(S.RazorCoralDebuff)) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
    end
    -- potion,if=buff.dancing_rune_weapon.up
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.DancingRuneWeaponBuff)) then
      if HR.Cast(I.PotionofUnbridledFury, Settings.Commons.OffGCDasOffGCD.Potions) then return ""; end
    end
    -- dancing_rune_weapon,if=!talent.blooddrinker.enabled|!cooldown.blooddrinker.ready
    if S.DancingRuneWeapon:IsCastable("Melee") and (not S.Blooddrinker:IsAvailable() or not S.Blooddrinker:CooldownUpP()) then
      if HR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
    end
    -- tombstone,if=buff.bone_shield.stack>=7
    if S.Tombstone:IsCastable() and (Player:BuffStackP(S.BoneShield) >= 7) then
      if HR.Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return ""; end
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(50842, 10, 6)               -- Blood Boil
  HL.RegisterNucleusAbility(194844, 8, 6)               -- Bonestorm
  HL.RegisterNucleusAbility(43265, 8, 6)                -- Death and Decay
end

HR.SetAPL(250, APL, Init);

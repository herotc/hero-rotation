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

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Spells
if not Spell.DeathKnight then Spell.DeathKnight = {}; end
Spell.DeathKnight.Blood = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  BagofTricks                           = Spell(312411),
  -- Abilities
  Asphyxiate                            = Spell(221562),
  BloodBoil                             = Spell(50842),
  Blooddrinker                          = Spell(206931),
  BloodMirror                           = Spell(206977),
  BloodPlague                           = Spell(55078),
  BloodShield                           = Spell(77535),
  BoneShield                            = Spell(195181),
  Bonestorm                             = Spell(194844),
  Consumption                           = Spell(274156),
  CrimsonScourge                        = Spell(81141),
  DancingRuneWeapon                     = Spell(49028),
  DancingRuneWeaponBuff                 = Spell(81256),
  DeathandDecay                         = Spell(43265),
  DeathsCaress                          = Spell(195292),
  DeathStrike                           = Spell(49998),
  HeartBreaker                          = Spell(221536),
  HeartStrike                           = Spell(206930),
  HemostasisBuff                        = Spell(273947),
  Marrowrend                            = Spell(195182),
  MindFreeze                            = Spell(47528),
  Ossuary                               = Spell(219786),
  RapidDecomposition                    = Spell(194662),
  RuneStrike                            = Spell(210764),
  RuneTap                               = Spell(194679),
  Tombstone                             = Spell(219809),
  TombstoneBuff                         = Spell(219809),
  UnholyStrengthBuff                    = Spell(53365),
  VampiricBlood                         = Spell(55233),
  -- Trinket Effects
  RazorCoralDebuff                      = Spell(303568),
  -- Essences
  AnimaofDeath                          = Spell(294926),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  MemoryofLucidDreams                   = Spell(298357),
  RippleInSpace                         = Spell(302731),
  WorldveinResonance                    = Spell(295186),
  -- Misc
  Pool                                  = Spell(9999000010)
};
local S = Spell.DeathKnight.Blood;
if AEMajor ~= nil then
  S.HeartEssence          = Spell(AESpellIDs[AEMajor.ID])
end

-- Items
if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Blood = {
  --Potion
  PotionofUnbridledFury            = Item(169299),
  MerekthasFang                    = Item(158367, {13, 14}),
  RazdunksBigRedButton             = Item(159611, {13, 14}),
  GrongsPrimalRage                 = Item(165574, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  DribblingInkpod                  = Item(169319, {13, 14}),
};
local I = Item.DeathKnight.Blood;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.MerekthasFang:ID(),
  I.RazdunksBigRedButton:ID(),
  I.GrongsPrimalRage:ID(),
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
  I.DribblingInkpod:ID()
}

-- Rotation Var
local PassiveEssence;
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

HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence();
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID]);
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.Cast(I.PotionofUnbridledFury, Settings.Commons.OffGCDasOffGCD.Potions) then return "potion 2"; end
  end
  if (Settings.Commons.UseTrinkets) then
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipReady() then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 4"; end
    end
    -- use_item,effect_name=cyclotronic_blast
    if Everyone.CyclotronicBlastReady() then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "cyclotronic_blast 6"; end
    end
  end
  -- Manually Added: Marrowrend for melee pulling
  if S.Marrowrend:IsCastable("Melee") then
    if HR.Cast(S.Marrowrend) then return "marrowrend 8"; end
  end
  -- Manually Added: Death's Caress for ranged pulling
  if S.DeathsCaress:IsReady() then
    if HR.Cast(S.DeathsCaress, nil, nil, 30) then return "deaths_caress 10"; end
  end
end

local function Defensives()
  -- Rune Tap Emergency
  if S.RuneTap:IsReady() and Player:HealthPercentage() <= 40 and Player:Rune() >= 3 and S.RuneTap:Charges() > 1 and Player:BuffDown(S.RuneTap) then
    if HR.Cast(S.RuneTap, true) then return "rune_tap 22"; end
  end
  -- Active Mitigation
  if Player:ActiveMitigationNeeded() and S.Marrowrend:TimeSinceLastCast() > 2.5 and S.DeathStrike:TimeSinceLastCast() > 2.5 then
    if S.DeathStrike:IsReady("Melee") and Player:BuffStack(S.BoneShield) > 7 then
      if HR.Cast(S.DeathStrike) then return "death_strike 24"; end
    end
    if S.Marrowrend:IsCastable("Melee") then
      if HR.Cast(S.Marrowrend) then return "marrowrend 26"; end
    end
    if S.DeathStrike:IsReady("Melee") then
      if HR.Cast(S.DeathStrike) then return "death_strike 28"; end
    end
  end
  -- Bone Shield
  if S.Marrowrend:IsCastable("Melee") and (Player:BuffRemainsP(S.BoneShield) <= 6 or (Target:TimeToDie() < 5 and Player:BuffRemainsP(S.BoneShield) < 10 and Cache.EnemiesCount[8] == 1)) then
    if HR.Cast(S.Marrowrend) then return "marrowrend 30"; end
  end
  -- Healing
  if S.DeathStrike:IsReady("Melee") and Player:HealthPercentage() <= 50 + (Player:RunicPower() > 90 and 20 or 0) and not Player:HealingAbsorbed() then
    if HR.Cast(S.DeathStrike) then return "death_strike 32"; end
  end
end

local function Essences()
  -- concentrated_flame,if=dot.concentrated_flame_burn.remains<2&!buff.dancing_rune_weapon.up
  if S.ConcentratedFlame:IsCastable() and (Target:DebuffRemainsP(S.ConcentratedFlameBurn) < 2 and Player:BuffDownP(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 42"; end
  end
  -- anima_of_death,if=buff.vampiric_blood.up&(raid_event.adds.exists|raid_event.adds.in>15)
  if S.AnimaofDeath:IsCastable() and (Player:BuffP(S.VampiricBlood)) then
    if HR.Cast(S.AnimaofDeath, nil, Settings.Commons.EssenceDisplayStyle, 8) then return "anima_of_death 44"; end
  end
  -- memory_of_lucid_dreams,if=rune.time_to_1>gcd&runic_power<40
  if S.MemoryofLucidDreams:IsCastable() and (Player:RuneTimeToX(1) > Player:GCD() and Player:RunicPower() < 40) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 46"; end
  end
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastable() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 48"; end
  end
  -- ripple_in_space,if=!buff.dancing_rune_weapon.up
  if S.RippleInSpace:IsCastable() and (Player:BuffDownP(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 50"; end
  end
end

local function Standard()
  -- death_strike,if=runic_power.deficit<=10
  if S.DeathStrike:IsReady("Melee") and Player:RunicPowerDeficit() <= 10 then
    if HR.Cast(S.DeathStrike) then return "death_strike 54"; end
  end
  -- blooddrinker,if=!buff.dancing_rune_weapon.up
  if HR.CDsON() and S.Blooddrinker:IsCastable(30) and not Player:ShouldStopCasting() and Player:BuffDownP(S.DancingRuneWeaponBuff) then
    if HR.Cast(S.Blooddrinker, Settings.Blood.GCDasOffGCD.Blooddrinker) then return "blooddrinker 56"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*2)|buff.bone_shield.stack<3)&runic_power.deficit>=20
  if S.Marrowrend:IsCastable("Melee") and ((Player:BuffRemainsP(S.BoneShield) <= Player:RuneTimeToX(3) or Player:BuffRemainsP(S.BoneShield) <= (Player:GCD() + num(S.Blooddrinker:CooldownUpP()) * num(S.Blooddrinker:IsAvailable()) * 2) or Player:BuffStackP(S.BoneShield) < 3) and Player:RunicPowerDeficit() >= 20) then
    if HR.Cast(S.Marrowrend) then return "marrowrend 58"; end
  end
  -- heart_essence,if=!buff.dancing_rune_weapon.up
  if S.HeartEssence ~= nil and not PassiveEssence and HR.CDsON() and S.HeartEssence:IsCastable() and not (Spell:MajorEssenceEnabled(AE.TheCrucibleofFlame)) and (Player:BuffDownP(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.HeartEssence, nil, Settings.Commons.EssenceDisplayStyle) then return "heart_essence 60"; end
  end
  -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
  if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 and (S.BloodBoil:ChargesFractionalP() >= 1.8 and (Player:BuffStackP(S.HemostasisBuff) <= (5 - Cache.EnemiesCount[10]) or Cache.EnemiesCount[10] > 2)) then
    if HR.Cast(S.BloodBoil, nil, nil, 10) then return "blood_boil 62"; end
  end
  -- marrowrend,if=buff.bone_shield.stack<5&talent.ossuary.enabled&runic_power.deficit>=15
  if S.Marrowrend:IsCastable("Melee") and (Player:BuffStackP(S.BoneShield) < 5 and S.Ossuary:IsAvailable() and Player:RunicPowerDeficit() >= 15) then
    if HR.Cast(S.Marrowrend) then return "marrowrend 64"; end
  end
  -- bonestorm,if=runic_power>=100&!buff.dancing_rune_weapon.up
  if HR.CDsON() and S.Bonestorm:IsCastable("Melee") and (Player:RunicPower() >= 100 and Player:BuffDownP(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm) then return "bonestorm 66"; end
  end
  -- death_strike,if=runic_power.deficit<=(15+buff.dancing_rune_weapon.up*5+spell_targets.heart_strike*talent.heartbreaker.enabled*2)|target.1.time_to_die<10
  if S.DeathStrike:IsReady("Melee") and (Player:RunicPowerDeficit() <= (15 + num(Player:BuffP(S.DancingRuneWeaponBuff)) * 5 + Cache.EnemiesCount[8] * num(S.HeartBreaker:IsAvailable()) * 2) or Target:TimeToDie() < 10) then
    if HR.Cast(S.DeathStrike) then return "death_strike 68"; end
  end
  -- death_and_decay,if=spell_targets.death_and_decay>=3
  if S.DeathandDecay:IsReady() and (Cache.EnemiesCount[10] >= 3) then
    if HR.Cast(S.DeathandDecay, Settings.Blood.GCDasOffGCD.DeathandDecay) then return "death_and_decay 70"; end
  end
  -- rune_strike,if=(charges_fractional>=1.8|buff.dancing_rune_weapon.up)&rune.time_to_3>=gcd
  if S.RuneStrike:IsCastable("Melee") and ((S.RuneStrike:ChargesFractionalP() >= 1.8 or Player:BuffP(S.DancingRuneWeaponBuff)) and Player:RuneTimeToX(3) >= Player:GCD()) then
    if HR.Cast(S.RuneStrike) then return "rune_strike 72"; end
  end
  -- heart_strike,if=buff.dancing_rune_weapon.up|rune.time_to_4<gcd
  if S.HeartStrike:IsReady("Melee") and (Player:BuffP(S.DancingRuneWeaponBuff) or Player:RuneTimeToX(4) < Player:GCD()) then
    if HR.Cast(S.HeartStrike) then return "heart_strike 74"; end
  end
  -- blood_boil,if=buff.dancing_rune_weapon.up
  if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 and (Player:BuffP(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.BloodBoil, nil, nil, 10) then return "blood_boil 76"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up|talent.rapid_decomposition.enabled|spell_targets.death_and_decay>=2
  if S.DeathandDecay:IsReady() and Cache.EnemiesCount[10] >= 1 and (Player:BuffP(S.CrimsonScourge) or S.RapidDecomposition:IsAvailable() or Cache.EnemiesCount[10] >= 2) then
    if HR.Cast(S.DeathandDecay, Settings.Blood.GCDasOffGCD.DeathandDecay) then return "death_and_decay 78"; end
  end
  -- consumption
  if HR.CDsON() and S.Consumption:IsCastable("Melee") then
    if HR.Cast(S.Consumption, nil, Settings.Blood.ConsumptionDisplayStyle) then return "consumption 80"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 then
    if HR.Cast(S.BloodBoil, nil, nil, 10) then return "blood_boil 82"; end
  end
  -- heart_strike,if=rune.time_to_3<gcd|buff.bone_shield.stack>6
  if S.HeartStrike:IsReady("Melee") and (Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStackP(S.BoneShield) > 6) then
    if HR.Cast(S.HeartStrike) then return "heart_strike 84"; end
  end
  -- use_item,name=grongs_primal_rage
  if HR.CDsON() and Settings.Commons.UseTrinkets and I.GrongsPrimalRage:IsEquipReady() then
    if HR.Cast(I.GrongsPrimalRage, nil, Settings.Commons.TrinketDisplayStyle) then return "grongs_primal_rage 86"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if HR.CDsON() and S.ArcaneTorrent:IsCastable("Melee") and Player:RunicPowerDeficit() > 20 then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 90"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  UnitsWithoutBloodPlague = UnitsWithoutBP() -- Get count of units without Blood Plague
  PassiveEssence = (Spell:MajorEssenceEnabled(AE.VisionofPerfection) or Spell:MajorEssenceEnabled(AE.ConflictandStrife) or Spell:MajorEssenceEnabled(AE.TheFormlessVoid) or Spell:MajorEssenceEnabled(AE.TouchoftheEverlasting))

  -- call precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    do
      -- Manually Added: Call Defensives
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool during Blooddrinker if enabled
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffP(S.BoneShield) and UnitsWithoutBloodPlague == 0 and not Player:ShouldStopCasting() and Player:CastRemains() > 0.2 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool During Blooddrinker"; end
    end
    -- auto_attack
    if HR.CDsON() then
      -- blood_fury,if=cooldown.dancing_rune_weapon.ready&(!cooldown.blooddrinker.ready|!talent.blooddrinker.enabled)
      if S.BloodFury:IsCastable() and Target:IsInRange("Melee") and (S.DancingRuneWeapon:CooldownUpP() and (not S.Blooddrinker:CooldownUpP() or not S.Blooddrinker:IsAvailable())) then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 122"; end
      end
      -- berserking
      if S.Berserking:IsCastable() and Target:IsInRange("Melee") then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 124"; end
      end
      -- arcane_pulse,if=active_enemies>=2|rune<1&runic_power.deficit>60
      if S.ArcanePulse:IsCastable() and (Cache.EnemiesCount[10] >= 2 or Player:Rune() < 1 and Player:RunicPowerDeficit() > 60) then
        if HR.Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_pulse 126"; end
      end
      -- lights_judgment,if=buff.unholy_strength.up
      if S.LightsJudgment:IsCastable() and (Player:BuffP(S.UnholyStrengthBuff)) then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 128"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 130"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 132"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 134"; end
      end
      if Settings.Commons.UseTrinkets then
        -- use_item,name=razdunks_big_red_button
        if I.RazdunksBigRedButton:IsEquipReady() then
          if HR.Cast(I.RazdunksBigRedButton, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "razdunks_big_red_button 136"; end
        end
        -- use_item,effect_name=cyclotronic_blast,if=cooldown.dancing_rune_weapon.remains&!buff.dancing_rune_weapon.up&rune.time_to_4>cast_time
        if Everyone.CyclotronicBlastReady() and (not S.DancingRuneWeapon:CooldownUpP() and Player:BuffDownP(S.DancingRuneWeaponBuff) and Player:RuneTimeToX(4) > 2.5) then
          if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "cyclotronic_blast 137"; end
        end
        -- use_item,name=azsharas_font_of_power,if=(cooldown.dancing_rune_weapon.remains<5&target.time_to_die>15)|(target.time_to_die<34)
        if I.AzsharasFontofPower:IsEquipReady() and ((S.DancingRuneWeapon:CooldownRemainsP() < 5 and Target:TimeToDie() > 15) or (Target:TimeToDie() < 34)) then
          if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 138"; end
        end
        -- use_item,name=merekthas_fang,if=(cooldown.dancing_rune_weapon.remains&!buff.dancing_rune_weapon.up&rune.time_to_4>3)&!raid_event.adds.exists|raid_event.adds.in>15
        if I.MerekthasFang:IsEquipReady() and ((not S.DancingRuneWeapon:CooldownUpP() and Player:BuffDownP(S.DancingRuneWeaponBuff) and Player:RuneTimeToX(4) > 3) and Cache.EnemiesCount[8] == 1) then
          if HR.Cast(I.MerekthasFang, nil, Settings.Commons.TrinketDisplayStyle, 20) then return "merekthas_fang 139"; end
        end
        -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down
        if I.AshvanesRazorCoral:IsEquipReady() and (Target:DebuffDownP(S.RazorCoralDebuff)) then
          if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 140"; end
        end
        -- use_item,name=ashvanes_razor_coral,if=target.health.pct<31&equipped.dribbling_inkpod
        if I.AshvanesRazorCoral:IsEquipReady() and (Target:HealthPercentage() < 31 and S.DribblingInkpod:IsEquipped()) then
          if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 142"; end
        end
        -- use_item,name=ashvanes_razor_coral,if=buff.dancing_rune_weapon.up&debuff.razor_coral_debuff.up&!equipped.dribbling_inkpod
        if I.AshvanesRazorCoral:IsEquipReady() and (Player:BuffP(S.DancingRuneWeaponBuff) and Target:DebuffP(S.RazorCoralDebuff) and not I.DribblingInkpod:IsEquipped()) then
          if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 144"; end
        end
        -- use_items,if=cooldown.dancing_rune_weapon.remains>90
        if (S.DancingRuneWeapon:CooldownRemainsP() > 90) then
          local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
          if TrinketToUse then
            if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
          end
        end
      end
      -- potion,if=buff.dancing_rune_weapon.up
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.DancingRuneWeaponBuff)) then
        if HR.Cast(I.PotionofUnbridledFury, Settings.Commons.OffGCDasOffGCD.Potions) then return "potion 148"; end
      end
      -- dancing_rune_weapon,if=!talent.blooddrinker.enabled|!cooldown.blooddrinker.ready
      if S.DancingRuneWeapon:IsCastable("Melee") and (not S.Blooddrinker:IsAvailable() or not S.Blooddrinker:CooldownUpP()) then
        if HR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon 150"; end
      end
      -- tombstone,if=buff.bone_shield.stack>=7
      if S.Tombstone:IsCastable() and (Player:BuffStackP(S.BoneShield) >= 7) then
        if HR.Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone 152"; end
      end
      -- call_action_list,name=essences
      local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
    do
      -- call_action_list,name=standard
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HL.RegisterNucleusAbility(50842, 10, 6)               -- Blood Boil
  HL.RegisterNucleusAbility(194844, 8, 6)               -- Bonestorm
  HL.RegisterNucleusAbility(43265, 8, 6)                -- Death and Decay
end

HR.SetAPL(250, APL, Init);

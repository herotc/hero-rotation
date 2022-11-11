--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- lua
local mathmin    = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Blood
local I = Item.DeathKnight.Blood

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Rotation Var
local VarDeathStrikeDumpAmt
local VarHeartStrikeRP
local VarHeartStrikeRPDRW
local IsTanking
local EnemiesMelee
local EnemiesMeleeCount
local HeartStrikeCount
local UnitsWithoutBloodPlague
local ghoul = HL.GhoulTable

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Legendary
local CrimsonRuneWeaponEquipped = Player:HasLegendaryEquipped(35)

HL:RegisterForEvent(function()
  CrimsonRuneWeaponEquipped = Player:HasLegendaryEquipped(35)
end, "PLAYER_EQUIPMENT_CHANGED")

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Blood = HR.GUISettings.APL.DeathKnight.Blood
}

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

--Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function UnitsWithoutBP(enemies)
  local WithoutBPCount = 0
  for _, CycleUnit in pairs(enemies) do
    if not CycleUnit:DebuffUp(S.BloodPlagueDebuff) then
      WithoutBPCount = WithoutBPCount + 1
    end
  end
  return WithoutBPCount
end

-- Functions for CastTargetIf
local function EvaluateTargetIfFilterSoulReaper(TargetUnit)
  -- target_if=min:dot.soul_reaper.remains
  return (TargetUnit:DebuffRemains(S.SoulReaperDebuff))
end

local function EvaluateTargetIfSoulReaper(TargetUnit)
  -- if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  return (TargetUnit:TimeToX(35) < 35 and TargetUnit:TimeToDie() > (TargetUnit:DebuffRemains(S.SoulReaperDebuff) + 5))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- fleshcraft
    if S.Fleshcraft:IsReady() then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 2"; end
    end
    -- Manually added: Openers
    if S.DeathsCaress:IsReady() then
      if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress precombat 4"; end
    end
    if S.Marrowrend:IsReady() then
      if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend precombat 6"; end
    end
    
  end
end

local function Defensives()
  -- Rune Tap Emergency
  if S.RuneTap:IsReady() and IsTanking and Player:HealthPercentage() <= Settings.Blood.RuneTapThreshold and Player:Rune() >= 3 and S.RuneTap:Charges() >= 1 and Player:BuffDown(S.RuneTapBuff) then
    if Cast(S.RuneTap, Settings.Blood.OffGCDasOffGCD.RuneTap) then return "rune_tap defensives 2"; end
  end
  -- Active Mitigation
  if Player:ActiveMitigationNeeded() and S.Marrowrend:TimeSinceLastCast() > 2.5 and S.DeathStrike:TimeSinceLastCast() > 2.5 then
    if S.DeathStrike:IsReady() and Player:BuffStack(S.BoneShieldBuff) > 7 then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 4"; end
    end
    if S.Marrowrend:IsReady() then
      if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend defensives 6"; end
    end
    -- Moving back to standard. Leaving this commented out for now, in case we want to revert.
    --if S.Tombstone:IsReady() and Player:BuffStack(S.BoneShieldBuff) >= 7 then
      --if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone defensives 8"; end
    --end
    if S.DeathStrike:IsReady() then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 10"; end
    end
  end
  --[[ Bone Shield
  if S.Marrowrend:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= 6 or (Target:TimeToDie() < 5 and Player:BuffRemains(S.BoneShieldBuff) < 10 and EnemiesMeleeCount == 1)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend defensives 12"; end
  end]]
  -- Vampiric Blood
  if S.VampiricBlood:IsCastable() and IsTanking and Player:HealthPercentage() <= Settings.Blood.VampiricBloodThreshold and Player:BuffDown(S.IceboundFortitudeBuff) then
    if Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood defensives 14"; end
  end
  -- Icebound Fortitude
  if S.IceboundFortitude:IsCastable() and IsTanking and Player:HealthPercentage() <= Settings.Blood.IceboundFortitudeThreshold and Player:BuffDown(S.VampiricBloodBuff) then
    if Cast(S.IceboundFortitude, Settings.Blood.GCDasOffGCD.IceboundFortitude) then return "icebound_fortitude defensives 16"; end
  end
  -- Healing
  if S.DeathStrike:IsReady() and Player:HealthPercentage() <= 50 + (Player:RunicPower() > 90 and 20 or 0) and not Player:HealingAbsorbed() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 18"; end
  end
end

local function Racials()
  -- blood_fury,if=cooldown.dancing_rune_weapon.ready&(!cooldown.blooddrinker.ready|!talent.blooddrinker.enabled)
  if S.BloodFury:IsCastable() and (S.DancingRuneWeapon:CooldownUp() and (not S.Blooddrinker:IsReady() or not S.Blooddrinker:IsAvailable()))  then
    if Cast(S.BloodFury, Settings.Commons.GCDasOffGCD.Racials) then return "blood_fury racials 2"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.GCDasOffGCD.Racials) then return "berserking racials 4"; end
  end
  -- arcane_pulse,if=active_enemies>=2|rune<1&runic_power.deficit>60
  if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or Player:Rune() < 1 and Player:RunicPowerDeficit() > 60) then
    if Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.GCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.GCDasOffGCD.Racials) then return "fireblood racials 12"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racials 14"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racials 16"; end
  end
end

local function Covenants()
  -- deaths_due,if=!buff.deaths_due.up|buff.deaths_due.remains<4|buff.crimson_scourge.up
  if S.DeathsDue:IsReady() and (Player:BuffDown(S.DeathsDueBuff) or Player:BuffRemains(S.DeathsDueBuff) < 4 or Player:BuffUp(S.CrimsonScourgeBuff)) then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DeathsDue)) then return "deaths_due covenants 6"; end
  end
  -- swarming_mist,if=cooldown.dancing_rune_weapon.remains>3&runic_power>=(90-(spell_targets.swarming_mist*3))
  if S.SwarmingMist:IsReady() and (S.DancingRuneWeapon:CooldownRemains() > 3 and Player:RunicPower() >= (90 - (EnemiesMeleeCount * 3))) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant) then return "swarming_mist covenants 7"; end
  end
  -- abomination_limb
  if S.AbominationLimbCov:IsReady() and CDsON() then
    if Cast(S.AbominationLimbCov, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(8)) then return "abomination_limb covenants 16"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent&!buff.volatile_solvent_humanoid.up,interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent
  if S.Fleshcraft:IsReady() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft covenants 20"; end
  end
  -- shackle_the_unworthy,if=rune<3&runic_power<100
  if S.ShackleTheUnworthy:IsReady() and (Player:Rune() < 3 and Player:RunicPower() < 100) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 18"; end
  end
end

local function DRWUp()
  -- tombstone,if=buff.bone_shield.stack>5&rune>=2&runic_power.deficit>=30&runeforge.crimson_rune_weapon
  if S.Tombstone:IsReady() and (Player:BuffStack(S.BoneShieldBuff) > 5 and Player:Rune() >= 2 and Player:RunicPowerDeficit() >= 30 and CrimsonRuneWeaponEquipped) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone drw_up 2"; end
  end
  -- empower_rune_weapon,if=rune<6&runic_power.deficit>5
  if S.EmpowerRuneWeapon:IsCastable() and (Player:Rune() < 6 and Player:RunicPowerDeficit() > 5) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon drw_up 4"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=rune.time_to_3|(buff.bone_shield.stack<2&buff.abomination_limb_talent.up))&runic_power.deficit>20
  if S.Marrowrend:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or (Player:BuffStack(S.BoneShieldBuff) < 2 and Player:BuffUp(S.AbominationLimbBuff))) and Player:RunicPowerDeficit() > 20) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend drw_up 6"; end
  end
  -- deaths_caress,if=buff.bone_shield.remains<=rune.time_to_3&rune<=1
  if S.DeathsCaress:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) and Player:Rune() <= 1) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress drw_up 8"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd|buff.icy_talons.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike drw_up 10"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper drw_up 12"; end
  end
  -- soul_reaper,target_if=min:dot.soul_reaper.remains,if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount >= 2) then
    if Everyone.CastTargetIf(S.SoulReaper, EnemiesMelee, "min", EvaluateTargetIfFilterSoulReaper, EvaluateTargetIfSoulReaper, not Target:IsInMeleeRange(5)) then return "soul_reaper drw_up 14"; end
  end
  -- deaths_due,if=covenant.night_fae&!death_and_decay.ticking
  if S.DeathsDue:IsReady() and (CovenantID == 3 and Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(30)) then return "deaths_due drw_up 16"; end
  end
  -- death_and_decay,if=!death_and_decay.ticking&(talent.sanguine_ground|talent.unholy_ground)
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (S.SanguineGround:IsAvailable() or S.UnholyGround:IsAvailable())) then
    if Cast(S.DeathAndDecay, Settings.Commons.GCDasOffGCD.DeathAndDecay, nil, not Target:IsInRange(30)) then return "death_and_decay drw_up 18"; end
  end
  -- blood_boil,if=((charges>=2&rune<=1)|dot.blood_plague.remains<=2)|(spell_targets.blood_boil>5&charges_fractional>=1.1)&!(covenant.venthyr&buff.swarming_mist.up)
  if S.BloodBoil:IsCastable() and (((S.BloodBoil:Charges() >= 2 and Player:Rune() <= 1) or Target:DebuffRemains(S.BloodPlagueDebuff) <= 2) or (EnemiesCount10y > 5 and S.BloodBoil:ChargesFractional() >= 1.1) and not (CovenantID == 2 and Player:BuffUp(S.SwarmingMist))) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil drw_up 20"; end
  end
  -- variable,name=heart_strike_rp_drw,value=(25+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = (25 + HeartStrikeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike drw_up 8"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption drw_up 16"; end
  end
  -- death_and_decay,if=(spell_targets.death_and_decay==3&buff.crimson_scourge.up)|spell_targets.death_and_decay>=4
  if S.DeathAndDecay:IsCastable() and ((EnemiesCount10y == 3 and Player:BuffUp(S.CrimsonScourgeBuff)) or EnemiesCount10y >= 4) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay drw_up 10"; end
  end
  -- heart_strike,if=rune.time_to_2<gcd|runic_power.deficit>=variable.heart_strike_rp_drw
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(2) < Player:GCD() or Player:RunicPowerDeficit() >= VarHeartStrikeRPDRW) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike drw_up 14"; end
  end
end

local function Standard()
  -- tombstone,if=buff.bone_shield.stack>5&rune>=2&runic_power.deficit>=30
  if S.Tombstone:IsCastable() and (Player:BuffStack(S.BoneShieldBuff) > 5 and Player:Rune() >= 2 and Player:RunicPowerDeficit() >= 30) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone standard 2"; end
  end
  -- abomination_limb_talent,if=buff.bone_shield.stack<6
  if S.AbominationLimb:IsCastable() and (Player:BuffStack(S.BoneShieldBuff) < 6) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(20)) then return "abomination_limb_talent standard 4"; end
  end
  -- marrowrend,if=buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*4)|buff.bone_shield.stack<6&runic_power.deficit>20&!(talent.insatiable_blade&cooldown.dancing_rune_weapon.remains<buff.bone_shield.remains)
  if S.Marrowrend:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or Player:BuffRemains(S.BoneShieldBuff) <= (Player:GCD() + num(S.Blooddrinker:CooldownUp()) * num(S.Blooddrinker:IsAvailable()) * 4) or Player:BuffStack(S.BoneShieldBuff) < 6 and Player:RunicPowerDeficit() > 20 and not (S.InsatiableBlade:IsAvailable() and S.DancingRuneWeapon:CooldownRemains() < Player:BuffRemains(S.BoneShieldBuff))) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend standard 6"; end
  end
  -- deaths_caress,if=buff.bone_shield.remains<=rune.time_to_3&rune<=1
  if S.DeathsCaress:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) and Player:Rune() <= 1) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress standard 8"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd|buff.icy_talons.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike standard 10"; end
  end
  -- deaths_due,if=covenant.night_fae&!death_and_decay.ticking
  if S.DeathsDue:IsReady() and (CovenantID == 3 and Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(30)) then return "deaths_due standard 12"; end
  end
  -- death_and_decay,if=!death_and_decay.ticking&(talent.sanguine_ground|talent.unholy_ground)
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (S.SanguineGround:IsAvailable() or S.UnholyGround:IsAvailable())) then
    if Cast(S.DeathAndDecay, Settings.Commons.GCDasOffGCD.DeathAndDecay, nil, not Target:IsInRange(30)) then return "death_and_decay standard 14"; end
  end
  -- bonestorm,if=runic_power>=100
  if S.Bonestorm:IsCastable() and (Player:RunicPower() >= 100) then
    if Cast(S.Bonestorm, nil, nil, not Target:IsInMeleeRange(5)) then return "bonestorm standard 16"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper standard 18"; end
  end
  -- soul_reaper,target_if=min:dot.soul_reaper.remains,if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount >= 2) then
    if Everyone.CastTargetIf(S.SoulReaper, EnemiesMelee, "min", EvaluateTargetIfFilterSoulReaper, EvaluateTargetIfSoulReaper, not Target:IsInMeleeRange(5)) then return "soul_reaper standard 20"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.death_strike_dump_amount&!(talent.bonestorm.enabled&cooldown.bonestorm.remains<2)
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarDeathStrikeDumpAmt and not (S.Bonestorm:IsAvailable() and S.Bonestorm:CooldownRemains() < 2)) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike standard 22"; end
  end
  -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.8 and (Player:BuffStack(S.HemostasisBuff) <= (5 - EnemiesCount10y) or EnemiesCount10y > 2)) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 24"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up&talent.relish_in_blood.enabled&runic_power.deficit>10
  if S.DeathAndDecay:IsReady() and ((Player:BuffUp(S.CrimsonScourgeBuff) and S.RelishinBlood:IsAvailable()) and Player:RunicPowerDeficit() > 10) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 26"; end
  end
  -- variable,name=heart_strike_rp,value=(15+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRP = (15 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  -- death_strike,if=(runic_power.deficit<=variable.heart_strike_rp)|target.time_to_die<10
  if S.DeathStrike:IsReady() and ((Player:RunicPowerDeficit() <= VarHeartStrikeRP) or Target:TimeToDie() < 10) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike standard 28"; end
  end
  -- death_and_decay,if=spell_targets.death_and_decay>=3
  if S.DeathAndDecay:IsReady() and (EnemiesMeleeCount >= 3) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 30"; end
  end
  -- heart_strike,if=rune.time_to_4<gcd
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(4) < Player:GCD()) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 32"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption standard 24"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up|talent.rapid_decomposition.enabled
  if S.DeathAndDecay:IsReady() and (Player:BuffUp(S.CrimsonScourgeBuff) or S.RapidDecomposition:IsAvailable()) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 22"; end
  end
  -- blood_boil,if=charges_fractional>=1.1
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.1) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 26"; end
  end
  -- heart_strike,if=(rune>1&(rune.time_to_3<gcd|buff.bone_shield.stack>7))
  if S.HeartStrike:IsReady() and (Player:Rune() > 1 and (Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStack(S.BoneShieldBuff) > 7)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 28"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Get Enemies Count
  Enemies10y          = Player:GetEnemiesInRange(10)
  if AoEON() then
    EnemiesMelee      = Player:GetEnemiesInMeleeRange(8)
    EnemiesMeleeCount = #EnemiesMelee
    EnemiesCount10y   = #Enemies10y
  else
    EnemiesMeleeCount = 1
    EnemiesCount10y   = 1
  end

  -- HeartStrike is limited to 5 targets maximum
  HeartStrikeCount = mathmin(EnemiesMeleeCount, Player:BuffUp(S.DeathAndDecayBuff) and 5 or 2)

  -- Check Units without Blood Plague
  UnitsWithoutBloodPlague = UnitsWithoutBP(Enemies10y)

  -- Are we actively tanking?
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Defensives
    local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Display Pool icon if PoolDuringBlooddrinker is true
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffUp(S.BoneShieldBuff) and UnitsWithoutBloodPlague == 0 and not Player:ShouldStopCasting() and Player:CastRemains() > 0.2 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool During Blooddrinker"; end
    end
    -- auto_attack
    -- variable,name=death_strike_dump_amount,value=70
    VarDeathStrikeDumpAmt = 70
    -- potion,if=buff.dancing_rune_weapon.up
    if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
    end
    -- use_items
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- raise_dead
    if CDsON() and S.RaiseDead:IsCastable() then
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead main 4"; end
    end
    -- deaths_caress,if=!buff.bone_shield.up
    if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
      if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress main 6"; end
    end
    -- blooddrinker,if=!buff.dancing_rune_weapon.up
    if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
      if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker main 8"; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- sacrificial_pact,if=!buff.dancing_rune_weapon.up&(pet.ghoul.remains<2|target.time_to_die<gcd)
    if S.SacrificialPact:IsReady() and ghoul.active() and (Player:BuffDown(S.DancingRuneWeaponBuff) and (ghoul.remains() < 2 or Target:TimeToDie() < Player:GCD())) then
      if Cast(S.SacrificialPact, Settings.Commons.OffGCDasOffGCD.SacrificialPact) then return "sacrificial_pact main 10"; end
    end
    -- call_action_list,name=covenants
    -- Note: Remove after pre-patch
    if (true) then
      local ShouldReturn = Covenants(); if ShouldReturn then return ShouldReturn; end
    end
    -- blood_tap,if=(rune<=2&rune.time_to_4>gcd&charges_fractional>=1.8)|rune.time_to_3>gcd
    if S.BloodTap:IsCastable() and ((Player:Rune() <= 2 and Player:RuneTimeToX(4) > Player:GCD() and S.BloodTap:ChargesFractional() >= 1.8) or Player:RuneTimeToX(3) > Player:GCD()) then
      if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap main 12"; end
    end
    -- marrowrend,if=buff.bone_shield.remains<gcd
    if S.Marrowrend:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) < Player:GCD() + 0.5) then
      if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend main 14"; end
    end
    -- deaths_caress,if=buff.bone_shield.remains<gcd|!buff.bone_shield.up
    if S.DeathsCaress:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) < Player:GCD() + 0.5 or Player:BuffDown(S.BoneShieldBuff)) then
      if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress main 16"; end
    end
    -- gorefiends_grasp,if=talent.tightening_grasp.enabled
    if S.GorefiendsGrasp:IsCastable() and (S.TighteningGrap:IsAvailable()) then
      if Cast(S.GorefiendsGrasp, Settings.Blood.GCDasOffGCD.GorefiendsGrasp, nil, not Target:IsSpellInRange(S.GorefiendsGrasp)) then return "gorefiends_grasp main 18"; end
    end
    -- deaths_due,if=covenant.night_fae&!death_and_decay.ticking
    if S.DeathsDue:IsReady() and (CovenantID == 3 and Player:BuffDown(S.DeathAndDecayBuff)) then
      if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(30)) then return "deaths_due main 20"; end
    end
    -- death_and_decay,if=(talent.unholy_ground|talent.sanguine_ground)&cooldown.dancing_rune_weapon.remains<gcd
    -- Note: Manually added buff check, as otherwise it burns all runes that are available.
    if S.DeathAndDecay:IsReady() and Player:BuffDown(S.DeathAndDecayBuff) and ((S.UnholyGround:IsAvailable() or S.SanguineGround:IsAvailable()) and S.DancingRuneWeapon:CooldownRemains() < Player:GCD() + 0.5) then
      if Cast(S.DeathAndDecay, Settings.Commons.GCDasOffGCD.DeathAndDecay, nil, not Target:IsInRange(30)) then return "death_and_decay main 22"; end
    end
    -- dancing_rune_weapon,if=!buff.dancing_rune_weapon.up
    if S.DancingRuneWeapon:IsCastable() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
      if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon main 24"; end
    end
    -- run_action_list,name=drw_up,if=buff.dancing_rune_weapon.up
    if (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      local ShouldReturn = DRWUp(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool for DRWUp"; end
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Blood DK rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(250, APL, Init)

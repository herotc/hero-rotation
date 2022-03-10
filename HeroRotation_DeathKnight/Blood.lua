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
local VarDeathsDueBuffCheck
local VarHeartStrikeRP
local VarHeartStrikeRPDRW
local VarHeartStrikeRPDRWVenthyr
local VarTomestoneBoneCount
local IsTanking
local EnemiesMelee
local EnemiesMeleeCount
local UnitsWithoutBloodPlague
local ghoul = HL.GhoulTable

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

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
local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- fleshcraft
    if S.Fleshcraft:IsCastable() then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 1"; end
    end
    -- Manually added: Openers
    if S.DeathsCaress:IsReady() and not Target:IsInMeleeRange(5) then
      if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress precombat 2"; end
    end
    if S.Marrowrend:IsReady() and Target:IsInMeleeRange(5) then
      if Cast(S.Marrowrend) then return "marrowrend precombat 4"; end
    end
    if S.BloodBoil:IsCastable() and Target:IsInMeleeRange(10) then
      if Cast(S.BloodBoil) then return "blood_boil precombat 6"; end
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
    -- Moving back to drw_up_venthyr and standard. Leaving this commented out for now, in case we want to revert.
    --if S.Tombstone:IsReady() and Player:BuffStack(S.BoneShieldBuff) >= 7 then
      --if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone defensives 8"; end
    --end
    if S.DeathStrike:IsReady() then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 10"; end
    end
  end
  -- Bone Shield
  if S.Marrowrend:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= 6 or (Target:TimeToDie() < 5 and Player:BuffRemains(S.BoneShieldBuff) < 10 and EnemiesMeleeCount == 1)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend defensives 12"; end
  end
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
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racials 2"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racials 4"; end
  end
  -- arcane_pulse,if=active_enemies>=2|rune<1&runic_power.deficit>60
  if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or Player:Rune() < 1 and Player:RunicPowerDeficit() > 60) then
    if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racials 12"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racials 14"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racials 16"; end
  end
end

local function Covenants()
  -- deaths_due,if=!buff.deaths_due.up|buff.deaths_due.remains<4|buff.crimson_scourge.up
  if S.DeathsDue:IsReady() and (Player:BuffDown(S.DeathsDueBuff) or Player:BuffRemains(S.DeathsDueBuff) < 4 or Player:BuffUp(S.CrimsonScourgeBuff)) then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DeathsDue)) then return "deaths_due covenants 6"; end
  end
  -- swarming_mist,if=cooldown.dancing_rune_weapon.remains>3&runic_power>=(90-(spell_targets.swarming_mist*3))
  if S.SwarmingMist:IsCastable() and (S.DancingRuneWeapon:CooldownRemains() > 3 and Player:RunicPower() >= (90 - (EnemiesMeleeCount * 3))) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant) then return "swarming_mist covenants 7"; end
  end
  -- abomination_limb,if=!buff.dancing_rune_weapon.up
  if S.AbominationLimb:IsCastable() and CDsON() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(8)) then return "abomination_limb covenants 16"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent&!buff.volatile_solvent_humanoid.up,interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft covenants 20"; end
  end
  -- shackle_the_unworthy,if=cooldown.dancing_rune_weapon.remains<3|!buff.dancing_rune_weapon.up
  if S.ShackleTheUnworthy:IsCastable() and (S.DancingRuneWeapon:CooldownRemains() < 3 or Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 18"; end
  end
end

local function DRWUp()
  -- variable,name=heart_strike_rp_drw,value=(15+buff.dancing_rune_weapon.up*10+spell_targets.heart_strike*talent.heartbreaker.enabled*2),op=setif,condition=covenant.night_fae&death_and_decay.ticking,value_else=(15+buff.dancing_rune_weapon.up*10+spell_targets.heart_strike*talent.heartbreaker.enabled*2)*1.2
  if (CovenantID == 3 and Player:BuffUp(S.DeathAndDecayBuff)) then
    VarHeartStrikeRPDRW = (15 + num(Player:BuffUp(S.DancingRuneWeaponBuff)) * 10 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  else
    VarHeartStrikeRPDRW = (15 + num(Player:BuffUp(S.DancingRuneWeaponBuff)) * 10 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2) * 1.2
  end
  -- marrowrend,if=(!covenant.necrolord|buff.abomination_limb.up)&(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*4|buff.bone_shield.stack<3))&runic_power.deficit>20
  if S.Marrowrend:IsReady() and ((CovenantID ~= 4 or Player:BuffUp(S.AbominationLimbBuff)) and (Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or Player:BuffRemains(S.BoneShieldBuff) <= (Player:GCD() + num(S.Blooddrinker:CooldownUp()) * num(S.Blooddrinker:IsAvailable()) * 4) or Player:BuffStack(S.BoneShieldBuff) < 3) and Player:RunicPowerDeficit() > 20) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend drw_up 2"; end
  end
  -- blood_boil,if=charges>=2
  if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil drw_up 4"; end
  end
  -- death_strike,if=(runic_power.deficit<=variable.death_strike_dump_amount&!(buff.dancing_rune_weapon.remains<=2&talent.bonestorm.enabled&cooldown.bonestorm.remains<2))|runic_power.deficit<=variable.heart_strike_rp_drw
  if S.DeathStrike:IsReady() and ((Player:RunicPowerDeficit() <= VarDeathStrikeDumpAmt and (not (Player:BuffRemains(S.DancingRuneWeaponBuff) <= 2 and S.Bonestorm:IsAvailable() and S.Bonestorm:CooldownRemains() < 2))) or Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike drw_up 6"; end
  end
  -- variable,name=deaths_due_buff_check,value=covenant.night_fae&death_and_decay.ticking&(buff.deaths_due.up&buff.deaths_due.remains<6)
  VarDeathsDueBuffCheck = (CovenantID == 3 and Player:BuffUp(S.DeathAndDecayBuff) and (Player:BuffUp(S.DeathsDueBuff) and Player:BuffRemains(S.DeathsDueBuff) < 6))
  -- heart_strike,if=variable.deaths_due_buff_check|rune.time_to_4<gcd|runic_power.deficit>variable.heart_strike_rp_drw
  if S.HeartStrike:IsReady() and (VarDeathsDueBuffCheck or Player:RuneTimeToX(4) < Player:GCD() or Player:RunicPowerDeficit() > VarHeartStrikeRPDRW) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike drw_up 8"; end
  end
end

local function DRWUpVenthyr()
  -- variable,name=tombstone_bone_count,value=7,op=setif,condition=buff.dancing_rune_weapon.up,value_else=5
  VarTomestoneBoneCount = (Player:BuffUp(S.DancingRuneWeaponBuff)) and 7 or 5
  -- tombstone,if=buff.bone_shield.stack>=variable.tombstone_bone_count&rune>=2&runic_power.deficit>30
  if S.Tombstone:IsCastable() and (Player:BuffStack(S.BoneShieldBuff) >= VarTomestoneBoneCount and Player:Rune() >= 2 and Player:RunicPowerDeficit() > 30) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone drw_up_venthyr 2"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*4|buff.bone_shield.stack<5))&runic_power.deficit>20
  if S.Marrowrend:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or Player:BuffRemains(S.BoneShieldBuff) <= (Player:GCD() + num(S.Blooddrinker:CooldownUp()) * num(S.Blooddrinker:IsAvailable()) * 4) or Player:BuffStack(S.BoneShieldBuff) < 5) and Player:RunicPowerDeficit() > 20) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "drw_up_venthyr 4"; end
  end
  -- blood_boil,if=charges>=2
  if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil drw_up_venthyr 6"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.death_strike_dump_amount&!(talent.bonestorm.enabled&cooldown.bonestorm.remains<2)
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarDeathStrikeDumpAmt and not (S.Bonestorm:IsAvailable() and S.Bonestorm:CooldownRemains() < 2)) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike drw_up_venthyr 8"; end
  end
  -- bonestorm,if=runic_power>=100&buff.swarming_mist.up
  if S.Bonestorm:IsReady() and (Player:RunicPower() >= 100 and Player:BuffUp(S.SwarmingMist)) then
    if Cast(S.Bonestorm, nil, nil, not Target:IsInRange(8)) then return "bonestorm drw_up_venthyr 10"; end
  end
  -- variable,name=heart_strike_rp_drw_venthyr,value=(15+buff.dancing_rune_weapon.up*10+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRWVenthyr = (15 + num(Player:BuffUp(S.DancingRuneWeaponBuff)) * 10 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  -- heart_strike,if=rune.time_to_4<gcd|runic_power.deficit>=variable.heart_strike_rp_drw_venthyr
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(4) < Player:GCD() or Player:RunicPowerDeficit() >= VarHeartStrikeRPDRWVenthyr) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike drw_up_venthyr 12"; end
  end
end

local function Standard()
  -- heart_strike,if=covenant.night_fae&death_and_decay.ticking&(buff.deaths_due.up&buff.deaths_due.remains<6)
  if S.HeartStrike:IsReady() and (CovenantID == 3 and Player:BuffUp(S.DeathAndDecayBuff) and (Player:BuffUp(S.DeathsDueBuff) and Player:BuffRemains(S.DeathsDueBuff) < 6)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 2"; end
  end
  -- tombstone,if=buff.bone_shield.stack>=7&rune>=2&!covenant.venthyr
  if S.Tombstone:IsCastable() and (Player:BuffStack(S.BoneShieldBuff) >= 7 and Player:Rune() >= 2 and CovenantID ~= 2) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone standard 4"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*4)|buff.bone_shield.stack<6|((!covenant.night_fae|buff.deaths_due.remains>5)&buff.bone_shield.remains<7))&runic_power.deficit>=15
  if S.Marrowrend:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or Player:BuffRemains(S.BoneShieldBuff) <= (Player:GCD() + num(S.Blooddrinker:CooldownUp()) * num(S.Blooddrinker:IsAvailable()) * 4) or Player:BuffStack(S.BoneShieldBuff) < 6 or ((CovenantID ~= 3 or Player:BuffRemains(S.DeathsDueBuff) > 5) and Player:BuffRemains(S.BoneShieldBuff) < 7)) and Player:RunicPowerDeficit() >= 15) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend standard 6"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.death_strike_dump_amount&!(talent.bonestorm.enabled&cooldown.bonestorm.remains<2)&!(covenant.venthyr&cooldown.swarming_mist.remains<3)
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarDeathStrikeDumpAmt and (not (S.Bonestorm:IsAvailable() and S.Bonestorm:CooldownRemains() < 2)) and not (CovenantID == 2 and S.SwarmingMist:CooldownRemains() < 3)) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike standard 8"; end
  end
  -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.8 and (Player:BuffStack(S.HemostasisBuff) <= (5 - EnemiesCount10y) or EnemiesCount10y > 2)) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 10"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up&talent.relish_in_blood.enabled&runic_power.deficit>10
  if S.DeathAndDecay:IsReady() and ((Player:BuffUp(S.CrimsonScourgeBuff) and S.RelishinBlood:IsAvailable()) and Player:RunicPowerDeficit() > 10) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 12"; end
  end
  -- bonestorm,if=runic_power>=100&!covenant.venthyr
  if S.Bonestorm:IsReady() and (Player:RunicPower() >= 100 and CovenantID ~= 2) then
    if Cast(S.Bonestorm, nil, nil, not Target:IsInRange(8)) then return "bonestorm standard 14"; end
  end
  -- variable,name=heart_strike_rp,value=(15+spell_targets.heart_strike*talent.heartbreaker.enabled*2),op=setif,condition=covenant.night_fae&death_and_decay.ticking,value_else=(15+spell_targets.heart_strike*talent.heartbreaker.enabled*2)*1.2
  if (CovenantID == 3 and Player:BuffUp(S.DeathAndDecayBuff)) then
    VarHeartStrikeRP = (15 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  else
    VarHeartStrikeRP = (15 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2) * 1.2
  end
  -- death_strike,if=(runic_power.deficit<=variable.heart_strike_rp)|target.time_to_die<10
  if S.DeathStrike:IsReady() and ((Player:RunicPowerDeficit() <= VarHeartStrikeRP) or Target:TimeToDie() < 10) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike standard 16"; end
  end
  -- death_and_decay,if=spell_targets.death_and_decay>=3
  if S.DeathAndDecay:IsReady() and (EnemiesMeleeCount >= 3) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 18"; end
  end
  -- heart_strike,if=rune.time_to_4<gcd
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(4) < Player:GCD()) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 20"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up|talent.rapid_decomposition.enabled
  if S.DeathAndDecay:IsReady() and (Player:BuffUp(S.CrimsonScourgeBuff) or S.RapidDecomposition:IsAvailable()) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 22"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption standard 24"; end
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
    -- variable,name=death_strike_dump_amount,value=70,op=setif,condition=covenant.night_fae&buff.deaths_due.remains>6,value_else=55
    VarDeathStrikeDumpAmt = (CovenantID == 3 and Player:BuffRemains(S.DeathsDueBuff) > 6) and 70 or 55
    -- potion,if=buff.dancing_rune_weapon.up
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
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
    -- blooddrinker,if=!buff.dancing_rune_weapon.up&(!covenant.night_fae|buff.deaths_due.remains>7)
    if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff) and (CovenantID ~= 3 or Player:BuffRemains(S.DeathsDueBuff) > 7)) then
      if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker main 6"; end
    end
    -- marrowrend,if=covenant.necrolord&buff.bone_shield.stack<=0
    -- Note: Likely covered in Defensives, but just in case...
    if S.Marrowrend:IsReady() and (CovenantID == 4 and Player:BuffDown(S.BoneShieldBuff)) then
      if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend main 8"; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- sacrificial_pact,if=(!covenant.night_fae|buff.deaths_due.remains>6)&!buff.dancing_rune_weapon.up&(pet.ghoul.remains<2|target.time_to_die<gcd)
    if S.SacrificialPact:IsReady() and ghoul.active() and ((CovenantID ~= 3 or Player:BuffRemains(S.DeathsDueBuff) > 6) and Player:BuffDown(S.DancingRuneWeaponBuff) and (ghoul.remains() < 2 or Target:TimeToDie() < Player:GCD())) then
      if Cast(S.SacrificialPact, Settings.Commons.OffGCDasOffGCD.SacrificialPact) then return "sacrificial_pact main 10"; end
    end
    -- call_action_list,name=covenants
    if (true) then
      local ShouldReturn = Covenants(); if ShouldReturn then return ShouldReturn; end
    end
    -- blood_tap,if=(rune<=2&rune.time_to_4>gcd&charges_fractional>=1.8)|rune.time_to_3>gcd
    if S.BloodTap:IsCastable() and ((Player:Rune() <= 2 and Player:RuneTimeToX(4) > Player:GCD() and S.BloodTap:ChargesFractional() >= 1.8) or Player:RuneTimeToX(3) > Player:GCD()) then
      if Cast(S.BloodTap) then return "blood_tap main 12"; end
    end
    -- dancing_rune_weapon,if=!covenant.venthyr
    if S.DancingRuneWeapon:IsCastable() and (CovenantID ~= 2) then
      if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon main 14"; end
    end
    -- run_action_list,name=drw_up,if=buff.dancing_rune_weapon.up&!covenant.venthyr
    if (Player:BuffUp(S.DancingRuneWeaponBuff) and CovenantID ~= 2) then
      local ShouldReturn = DRWUp(); if ShouldReturn then return ShouldReturn; end
    end
    -- dancing_rune_weapon,if=covenant.venthyr&cooldown.swarming_mist.ready&runic_power>=(90-(spell_targets.swarming_mist*3))
    if S.DancingRuneWeapon:IsCastable() and (CovenantID == 2 and S.SwarmingMist:CooldownUp() and Player:RunicPower() >= (90 - (EnemiesMeleeCount * 3))) then
      if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon main 16"; end
    end
    -- run_action_list,name=drw_up_venthyr,if=covenant.venthyr&(buff.dancing_rune_weapon.up|buff.swarming_mist.up)
    if (CovenantID == 2 and (Player:BuffUp(S.DancingRuneWeaponBuff) or Player:BuffUp(S.SwarmingMist))) then
      local ShouldReturn = DRWUpVenthyr(); if ShouldReturn then return ShouldReturn; end
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
  --HR.Print("Blood DK rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(250, APL, Init)

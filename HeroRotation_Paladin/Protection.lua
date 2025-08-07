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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local mathmax    = math.max
local mathmin    = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Paladin.Protection
local I = Item.Paladin.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.ItemName:ID(),
}

--- ===== GUI Settings ======
local Everyone = HR.Commons.Everyone
local Paladin = HR.Commons.Paladin
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  CommonsDS = HR.GUISettings.APL.Paladin.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Paladin.CommonsOGCD,
  Protection = HR.GUISettings.APL.Paladin.Protection
}

--- ===== Rotation Variables =====
local VarSanctificationMaxStack = 5
local ActiveMitigationNeeded
local IsTanking
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

--- ===== Helper Functions =====
local function HammerfallICD()
  if not S.Hammerfall:IsAvailable() then return 0 end
  local LastCast = mathmin(S.ShieldoftheRighteous:TimeSinceLastCast(), S.WordofGlory:TimeSinceLastCast())
  return mathmax(0, 1 - LastCast)
end

local function HPGTo2Dawn()
  if not S.OfDuskandDawn:IsAvailable() then return -1 end
  return 6 - Paladin.HPGCount - (Player:BuffStack(S.BlessingofDawnBuff) * 3)
end

local function MissingAura()
  return (Player:BuffDown(S.RetributionAura) and Player:BuffDown(S.DevotionAura) and Player:BuffDown(S.ConcentrationAura) and Player:BuffDown(S.CrusaderAura))
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterJudgment(TargetUnit)
  return TargetUnit:DebuffRemains(S.JudgmentDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- rite_of_sanctification
  if S.RiteofSanctification:IsCastable() then
    if Cast(S.RiteofSanctification) then return "rite_of_sanctification precombat 2"; end
  end
  -- rite_of_adjuration
  if S.RiteofAdjuration:IsCastable() then
    if Cast(S.RiteofAdjuration) then return "rite_of_adjuration precombat 4"; end
  end
  -- snapshot_stats
  -- devotion_aura
  if S.DevotionAura:IsCastable() and (MissingAura()) then
    if Cast(S.DevotionAura) then return "devotion_aura precombat 6"; end
  end
  -- lights_judgment
  if CDsON() and S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment precombat 8"; end
  end
  -- arcane_torrent
  if CDsON() and S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent precombat 10"; end
  end
  -- consecration
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(8) then
    if Cast(S.Consecration) then return "consecration precombat 12"; end
  end
  -- variable,name=trinket_sync_slot,value=1,if=trinket.1.has_cooldown&trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|!trinket.2.has_cooldown
  -- variable,name=trinket_sync_slot,value=2,if=trinket.2.has_cooldown&trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)|!trinket.1.has_cooldown
  -- Note: Unable to handle the has_stat trinket conditionals.
  -- Manually added: avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield precombat 10"; end
  end
  -- Manually added: judgment
  if S.Judgment:IsReady() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment precombat 12"; end
  end
end

local function Defensives()
  -- ardent_defender
  -- Note: This is now in the APL, but we are handling it as we have been.
  if Player:HealthPercentage() <= Settings.Protection.LoHHP and S.LayonHands:IsCastable() then
    if Cast(S.LayonHands, nil, Settings.Protection.DisplayStyle.Defensives) then return "lay_on_hands defensive 2"; end
  end
  if S.GuardianofAncientKings:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.GoAKHP and Player:BuffDown(S.ArdentDefenderBuff)) then
    if Cast(S.GuardianofAncientKings, nil, Settings.Protection.DisplayStyle.Defensives) then return "guardian_of_ancient_kings defensive 4"; end
  end
  if S.ArdentDefender:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.ArdentDefenderHP and Player:BuffDown(S.GuardianofAncientKingsBuff)) then
    if Cast(S.ArdentDefender, nil, Settings.Protection.DisplayStyle.Defensives) then return "ardent_defender defensive 6"; end
  end
  if S.WordofGlory:IsReady() and (Player:HealthPercentage() <= Settings.Protection.PrioSelfWordofGloryHP and not Player:HealingAbsorbed()) then
    -- cast word of glory on us if it's a) free or b) probably not going to drop sotr
    if (Player:BuffRemains(S.ShieldoftheRighteousBuff) >= 5 or Player:BuffUp(S.DivinePurposeBuff) or Player:BuffUp(S.ShiningLightFreeBuff)) then
      if Cast(S.WordofGlory) then return "word_of_glory defensive 8"; end
    else
      -- cast it anyway but run the fuck away
      if HR.CastAnnotated(S.WordofGlory, false, "KITE") then return "word_of_glory defensive 10"; end
    end
  end
  if S.ShieldoftheRighteous:IsReady() and (Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Protection.SotRHP)) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then return "shield_of_the_righteous defensive 14"; end
  end
end

local function Cooldowns()
  -- lights_judgment,if=spell_targets.lights_judgment>=2|!raid_event.adds.exists|raid_event.adds.in>75|raid_event.adds.up
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cooldowns 2"; end
  end
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if Cast(S.AvengingWrath, Settings.Protection.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 4"; end
  end
  -- Manually added: sentinel
  -- Note: Simc has back-end code for Protection Paladin to replace AW with Sentinel when talented.
  if S.Sentinel:IsCastable() then
    if Cast(S.Sentinel, Settings.Protection.OffGCDasOffGCD.Sentinel) then return "sentinel cooldowns 6"; end
  end
  -- potion,if=buff.avenging_wrath.up
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvengingWrathBuff)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldowns 8"; end
    end
  end
  -- moment_of_glory,if=(buff.avenging_wrath.remains<15|(time>10))
  if S.MomentofGlory:IsCastable() and (Player:BuffRemains(S.AvengingWrathBuff) < 15 or HL.CombatTime() > 10) then
    if Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentOfGlory) then return "moment_of_glory cooldowns 10"; end
  end
  -- divine_toll,if=spell_targets.shield_of_the_righteous>=3
  if CDsON() and S.DivineToll:IsCastable() and (EnemiesCount8y >= 3) then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.DivineToll) then return "divine_toll cooldowns 12"; end
  end
  -- bastion_of_light,if=buff.avenging_wrath.up|cooldown.avenging_wrath.remains<=30
  if S.BastionofLight:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or S.AvengingWrath:CooldownRemains() <= 30) then
    if Cast(S.BastionofLight, Settings.Protection.OffGCDasOffGCD.BastionOfLight) then return "bastion_of_light cooldowns 14"; end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.avenging_wrath.up
  -- Note: Not handling external buffs.
  -- fireblood,if=buff.avenging_wrath.remains>8
  if S.Fireblood:IsCastable() and (Player:BuffRemains(S.AvengingWrathBuff) > 8) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 16"; end
  end
end

local function Standard()
  -- judgment,target_if=min:debuff.judgment.remains,if=charges>=2|full_recharge_time<=gcd.max
  if S.Judgment:IsReady() and (S.Judgment:Charges() >= 2 or S.Judgment:FullRechargeTime() <= Player:GCD()) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 2"; end
  end
  -- hammer_of_light,if=(buff.blessing_of_dawn.up|fight_remains<2)&(debuff.judgment.up|buff.hammer_of_light_ready.remains<2|buff.hammer_of_light_ready.stack>1|buff.hammer_of_light_free.up|(cooldown.eye_of_tyr.remains<3))
  if S.HammerofLight:IsReady() and ((Player:BuffUp(S.BlessingofDawnBuff) or BossFightRemains < 2) and (Target:DebuffUp(S.JudgmentDebuff) or Player:BuffRemains(S.HammerofLightBuff) < 2 or Player:BuffStack(S.HammerofLightBuff) > 1 or Player:BuffUp(S.HammerofLightFreeBuff) or S.EyeofTyr:CooldownRemains() < 3)) then
    if Cast(S.HammerofLight, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInRange(12)) then return "hammer_of_light standard 4"; end
  end
  -- eye_of_tyr,if=talent.lights_guidance.enabled
  if S.EyeofTyr:IsCastable() and (S.LightsGuidance:IsAvailable()) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr standard 6"; end
  end
  -- shield_of_the_righteous,if=!buff.hammer_of_light_ready.up&(buff.luck_of_the_draw.up&((holy_power+judgment_holy_power>=5)|(!talent.righteous_protector.enabled|cooldown.righteous_protector_icd.remains=0)))
  -- shield_of_the_righteous,if=set_bonus.thewarwithin_season_2_4pc&!buff.hammer_of_light_ready.up&((holy_power+judgment_holy_power>5)|(holy_power+judgment_holy_power>=5&cooldown.righteous_protector_icd.remains=0))
  -- shield_of_the_righteous,if=!set_bonus.thewarwithin_season_2_4pc&(!talent.righteous_protector.enabled|cooldown.righteous_protector_icd.remains=0)&!buff.hammer_of_light_ready.up
  -- shield_of_the_righteous,if=holy_power=5&(!buff.blessing_of_dawn.up|!talent.lights_guidance.enabled)
  local RighteousProtectorICD = 999
  if S.RighteousProtector:IsAvailable() then
    local LastCast = mathmin(S.ShieldoftheRighteous:TimeSinceLastCast(), S.WordofGlory:TimeSinceLastCast())
    RighteousProtectorICD = mathmax(0, 1 - mathmin(S.ShieldoftheRighteous:TimeSinceLastCast(), S.WordofGlory:TimeSinceLastCast()))
  end
  if S.ShieldoftheRighteous:IsReady() and (not S.HammerofLight:IsCastable()) and (
    (Player:BuffUp(S.LuckoftheDrawBuff) and ((Player:HolyPower() + Player:JudgmentPower() >= 5) or (not S.RighteousProtector:IsAvailable() or RighteousProtectorICD == 0))) or
    (Player:HasTier("TWW2", 4) and ((Player:HolyPower() + Player:JudgmentPower() > 5) or (Player:HolyPower() + Player:JudgmentPower() >= 5 and RighteousProtectorICD == 0))) or
    (not Player:HasTier("TWW2", 4) and (not S.RighteousProtector:IsAvailable() or RighteousProtectorICD == 0)) or
    (Player:HolyPower() == 5 and (Player:BuffDown(S.BlessingofDawnBuff) or not S.LightsGuidance:IsAvailable()))
  ) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then return "shield_of_the_righteous standard 8"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=spell_targets.shield_of_the_righteous>3&buff.bulwark_of_righteous_fury.stack>=3&holy_power<3
  if S.Judgment:IsReady() and (EnemiesCount8y > 3 and Player:BuffStack(S.BulwarkofRighteousFuryBuff) >= 3 and Player:HolyPower() < 3) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 10"; end
  end
  -- holy_armaments,if=next_armament=holy_bulwark&set_bonus.thewarwithin_season_3_4pc
  if S.HolyBulwark:IsCastable() and (Player:HasTier("TWW3", 4)) then
    if Cast(S.HolyBulwark, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 12"; end
  end
  -- blessed_hammer,if=set_bonus.thewarwithin_season_3_4pc&talent.hammer_and_anvil.enabled
  if S.BlessedHammer:IsCastable() and (Player:HasTier("TWW3", 4) and S.HammerandAnvil:IsAvailable()) then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 14"; end
  end
  -- avengers_shield,if=!buff.bulwark_of_righteous_fury.up&talent.bulwark_of_righteous_fury.enabled&spell_targets.shield_of_the_righteous>=3
  if S.AvengersShield:IsCastable() and (Player:BuffDown(S.BulwarkofRighteousFuryBuff) and S.BulwarkofRighteousFury:IsAvailable() and EnemiesCount8y >= 3) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 16"; end
  end
  -- hammer_of_the_righteous,if=buff.blessed_assurance.up&spell_targets.shield_of_the_righteous<3&!buff.avenging_wrath.up
  if S.HammeroftheRighteous:IsCastable() and (Player:BuffUp(S.BlessedAssuranceBuff) and EnemiesCount8y < 3 and Player:BuffDown(S.AvengingWrathBuff)) then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 18"; end
  end
  -- blessed_hammer,if=buff.blessed_assurance.up&spell_targets.shield_of_the_righteous<3
  if S.BlessedHammer:IsCastable() and (Player:BuffUp(S.BlessedAssuranceBuff) and EnemiesCount8y < 3) then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 20"; end
  end
  -- crusader_strike,if=buff.blessed_assurance.up&spell_targets.shield_of_the_righteous<2&!buff.avenging_wrath.up
  if S.CrusaderStrike:IsCastable() and (Player:BuffUp(S.BlessedAssuranceBuff) and EnemiesCount8y < 2 and Player:BuffDown(S.AvengingWrathBuff)) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike standard 22"; end
  end
  -- consecration,if=buff.divine_guidance.stack=5
  if S.Consecration:IsCastable() and (Player:BuffStack(S.DivineGuidanceBuff) == 5) then
    if Cast(S.Consecration) then return "consecration standard 24"; end
  end
  -- holy_armaments,if=next_armament=sacred_weapon&((!buff.sacred_weapon.up|(buff.sacred_weapon.remains<6&!buff.avenging_wrath.up&cooldown.avenging_wrath.remains<=30))&(!set_bonus.thewarwithin_season_3_4pc|buff.masterwork.stack=5))
  if S.SacredWeapon:IsCastable() and ((Player:BuffDown(S.SacredWeaponBuff) or (Player:BuffRemains(S.SacredWeaponBuff) < 6 and Player:BuffDown(S.AvengingWrathBuff) and S.AvengingWrath:CooldownRemains() <= 30)) and (not Player:HasTier("TWW3", 4) or Player:BuffStack(S.MasterworkBuff) == 5)) then
    if Cast(S.SacredWeapon, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 26"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath standard 28"; end
  end
  -- divine_toll,if=(!raid_event.adds.exists|raid_event.adds.in>10)
  if CDsON() and S.DivineToll:IsReady() then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.DivineToll, not Target:IsInRange(30)) then return "divine_toll standard 30"; end
  end
  -- avengers_shield,if=talent.refining_fire.enabled
  if S.AvengersShield:IsCastable() and (S.RefiningFire:IsAvailable()) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 32"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=(buff.avenging_wrath.up&talent.hammer_and_anvil.enabled)
  if S.Judgment:IsReady() and (Player:BuffUp(S.AvengingWrathBuff) and S.HammerandAnvil:IsAvailable()) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 34"; end
  end
  -- holy_armaments,if=next_armament=holy_bulwark&charges=2
  if S.HolyBulwark:IsCastable() and (S.HolyBulwark:Charges() == 2) then
    if Cast(S.HolyBulwark, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 36"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 38"; end
  end
  -- avengers_shield,if=!buff.shake_the_heavens.up&talent.shake_the_heavens.enabled
  if S.AvengersShield:IsCastable() and (Player:BuffDown(S.ShaketheHeavensBuff) and S.ShaketheHeavens:IsAvailable()) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 40"; end
  end
  if (Player:BuffUp(S.BlessedAssuranceBuff) and EnemiesCount8y < 3) or Player:BuffUp(S.ShaketheHeavensBuff) then
    -- hammer_of_the_righteous,if=(buff.blessed_assurance.up&spell_targets.shield_of_the_righteous<3)|buff.shake_the_heavens.up
    if S.HammeroftheRighteous:IsCastable() then
      if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 42"; end
    end
    -- blessed_hammer,if=(buff.blessed_assurance.up&spell_targets.shield_of_the_righteous<3)|buff.shake_the_heavens.up
    if S.BlessedHammer:IsCastable() then
      if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 44"; end
    end
  end
  -- crusader_strike,if=(buff.blessed_assurance.up&spell_targets.shield_of_the_righteous<2)|buff.shake_the_heavens.up
  if S.CrusaderStrike:IsCastable() and ((Player:BuffUp(S.BlessedAssuranceBuff) and EnemiesCount8y < 2) or Player:BuffUp(S.ShaketheHeavensBuff)) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike standard 46"; end
  end
  -- avengers_shield,if=!talent.lights_guidance.enabled
  if S.AvengersShield:IsCastable() and (not S.LightsGuidance:IsAvailable()) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 48"; end
  end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff)) then
    if Cast(S.Consecration) then return "consecration standard 50"; end
  end
  -- eye_of_tyr,if=(talent.inmost_light.enabled&raid_event.adds.in>=45|spell_targets.shield_of_the_righteous>=3)&!talent.lights_deliverance.enabled
  -- Note: Ignoring CDsON if spec'd Templar Hero Tree.
  if (CDsON() or S.LightsGuidance:IsAvailable()) and S.EyeofTyr:IsCastable() and ((S.InmostLight:IsAvailable() and EnemiesCount8y == 1 or EnemiesCount8y >= 3) and not S.LightsDeliverance:IsAvailable()) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr standard 52"; end
  end
  -- holy_armaments,if=next_armament=holy_bulwark
  if S.HolyBulwark:IsCastable() then
    if Cast(S.HolyBulwark, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 54"; end
  end
  -- blessed_hammer
  if S.BlessedHammer:IsCastable() then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 56"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 58"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike standard 60"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up&(talent.blessed_assurance.enabled|(talent.lights_guidance.enabled&cooldown.hammerfall_icd.remains=0))
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff) and (S.BlessedAssurance:IsAvailable() or (S.LightsGuidance:IsAvailable() and HammerfallICD() == 0))) then
    -- Is our health ok? Are we in a party with a wounded party member? Heal them instead.
    if Player:HealthPercentage() > 90 and Player:IsInParty() and not Player:IsInRaid() then
      for _, Char in pairs(Unit.Party) do
        if Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() <= 80 then
          if HR.CastAnnotated(S.WordofGlory, false, Char:Name()) then return "word_of_glory standard party 62"; end
        end
      end
      -- Nobody in the party needs it. We might as well heal ourselves for the extra block chance.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 64"; end
    else
      -- We're either solo, in a raid, or injured. Heal ourselves.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 66"; end
    end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 68"; end
  end
  -- eye_of_tyr,if=!talent.lights_deliverance.enabled
  -- Note: Ignoring CDsON if spec'd Templar Hero Tree.
  if (CDsON() or S.LightsGuidance:IsAvailable()) and S.EyeofTyr:IsCastable() and (not S.LightsDeliverance:IsAvailable()) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr standard 70"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff)) then
    -- Is our health ok? Are we in a party with a wounded party member? Heal them instead.
    if Player:HealthPercentage() > 90 and Player:IsInParty() and not Player:IsInRaid() then
      for _, Char in pairs(Unit.Party) do
        if Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() <= 80 then
          if HR.CastAnnotated(S.WordofGlory, false, Char:Name()) then return "word_of_glory standard party 72"; end
        end
      end
      -- Nobody in the party needs it. We might as well heal ourselves for the extra block chance.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 74"; end
    else
      -- We're either solo, in a raid, or injured. Heal ourselves.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 76"; end
    end
  end
  -- arcane_torrent,if=holy_power<5
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:HolyPower() < 5) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent standard 78"; end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 80"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if Cast(S.Consecration) then return "consecration standard 82"; end
  end
end

local function Trinkets()
  -- use_item,name=tome_of_lights_devotion,if=buff.inner_resilience.up
  if I.TomeofLightsDevotion:IsEquippedAndReady() and Player:BuffUp(S.InnerResilienceBuff) then
    if Cast(I.TomeofLightsDevotion, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "tome_of_lights_devotion trinkets 2"; end
  end
  -- use_item,name=unyielding_netherprism,if=buff.avenging_wrath.remains>15
  if I.UnyieldingNetherprism:IsEquippedAndReady() and (Player:BuffRemains(S.AvengingWrathBuff) > 15) then
    if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "unyielding_netherprism trinkets 4"; end
  end
  -- use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(buff.avenging_wrath.up|fight_remains<=40)|(variable.trinket_sync_slot=2&(!trinket.2.cooldown.ready|!buff.avenging_wrath.up))|!variable.trinket_sync_slot)
  -- use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(buff.avenging_wrath.up|fight_remains<=40)|(variable.trinket_sync_slot=1&(!trinket.1.cooldown.ready|!buff.avenging_wrath.up))|!variable.trinket_sync_slot)
  -- Note: Unable to handle these trinket conditionals. Using a generic fallback instead.
  -- use_items,if=buff.avenging_wrath.up|fight_remains<=40
  if Player:BuffUp(S.AvengingWrathBuff) or FightRemains <= 40 then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  Enemies30y = Player:GetEnemiesInRange(30)
  if (AoEON()) then
    EnemiesCount8y = #Enemies8y
    EnemiesCount30y = #Enemies30y
  else
    EnemiesCount8y = 1
    EnemiesCount30y = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.Rebuke, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives!
    if IsTanking then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=defensives
    -- Note: Moved above Cooldowns().
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard
    local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pool, if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Protection Paladin rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(66, APL, Init)

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
local ActiveMitigationNeeded
local IsTanking
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y
local VarSanctificationMaxStack = 5

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

--- ===== Helper Functions =====
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
  -- flask
  -- food
  -- augmentation
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
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.Signature) then return "divine_toll cooldowns 12"; end
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

local function HammerofLight()
  -- hammer_of_light,if=buff.blessing_of_dawn.stack>0|spell_targets.shield_of_the_righteous>=5
  if S.HammerofLight:IsReady() and (Player:BuffUp(S.BlessingofDawnBuff) or EnemiesCount8y >= 5) then
    if Cast(S.HammerofLight, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInRange(12)) then return "hammer_of_light hammer_of_light 2"; end
  end
  -- eye_of_tyr,if=hpg_to_2dawn=5
  if S.EyeofTyr:IsCastable() and (HPGTo2Dawn() == 5) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr hammer_of_light 4"; end
  end
  -- shield_of_the_righteous,if=hpg_to_2dawn=4
  if S.ShieldoftheRighteous:IsReady() and (HPGTo2Dawn() == 4) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then return "shield_of_the_righteous standard 6"; end
  end
  -- eye_of_tyr,if=hpg_to_2dawn=1|buff.blessing_of_dawn.stack>0
  if S.EyeofTyr:IsCastable() and (HPGTo2Dawn() == 1 or Player:BuffUp(S.BlessingofDawnBuff)) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr hammer_of_light 8"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath hammer_of_light 10"; end
  end
  -- judgment
  if S.Judgment:IsReady() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment hammer_of_light 12"; end
  end
  -- blessed_hammer
  if S.BlessedHammer:IsCastable() then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer hammer_of_light 14"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous hammer_of_light 16"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike hammer_of_light 18"; end
  end
  -- divine_toll
  if CDsON() and S.DivineToll:IsReady() then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.DivineToll, not Target:IsInRange(30)) then return "divine_toll hammer_of_light 20"; end
  end
end

local function Standard()
  -- call_action_list,name=hammer_of_light,if=talent.lights_guidance.enabled&(cooldown.eye_of_tyr.remains<2|buff.hammer_of_light_ready.up)&(!talent.redoubt.enabled|buff.redoubt.stack>=2|!talent.bastion_of_light.enabled)&talent.of_dusk_and_dawn.enabled
  if S.LightsGuidance:IsAvailable() and (S.EyeofTyr:CooldownRemains() < 2 or S.HammerofLight:IsLearned()) and (not S.Redoubt:IsAvailable() or Player:BuffStack(S.RedoubtBuff) >= 2 or not S.BastionofLight:IsAvailable()) and S.OfDuskandDawn:IsAvailable() then
    local ShouldReturn = HammerofLight(); if ShouldReturn then return ShouldReturn; end
  end
  -- hammer_of_light,if=(!talent.redoubt.enabled|buff.redoubt.stack=3)&(buff.blessing_of_dawn.stack>=1|!talent.of_dusk_and_dawn.enabled)
  if S.HammerofLight:IsReady() and ((not S.Redoubt:IsAvailable() or Player:BuffStack(S.RedoubtBuff) == 3) and (Player:BuffUp(S.BlessingofDawnBuff) or not S.OfDuskandDawn:IsAvailable())) then
    if Cast(S.HammerofLight, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInRange(12)) then return "hammer_of_light standard 2"; end
  end
  -- shield_of_the_righteous,if=(((!talent.righteous_protector.enabled|cooldown.righteous_protector_icd.remains=0)&holy_power>2)|buff.bastion_of_light.up|buff.divine_purpose.up)&!((buff.hammer_of_light_ready.up|buff.hammer_of_light_free.up))
  local RighteousProtectorICD = 999
  if S.RighteousProtector:IsAvailable() then
    local LastCast = mathmin(S.ShieldoftheRighteous:TimeSinceLastCast(), S.WordofGlory:TimeSinceLastCast())
    RighteousProtectorICD = mathmax(0, 1 - mathmin(S.ShieldoftheRighteous:TimeSinceLastCast(), S.WordofGlory:TimeSinceLastCast()))
  end
  if S.ShieldoftheRighteous:IsReady() and ((((not S.RighteousProtector:IsAvailable() or RighteousProtectorICD == 0) and Player:HolyPower() > 2) or Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.DivinePurposeBuff)) and not (S.HammerofLight:IsLearned())) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then return "shield_of_the_righteous standard 4"; end
  end
  -- holy_armaments,if=next_armament=sacred_weapon&(!buff.sacred_weapon.up|(buff.sacred_weapon.remains<6&!buff.avenging_wrath.up&cooldown.avenging_wrath.remains<=30))
  if S.SacredWeapon:IsCastable() and (Player:BuffDown(S.SacredWeaponBuff) or (Player:BuffRemains(S.SacredWeaponBuff) < 6 and Player:BuffDown(S.AvengingWrathBuff) and S.AvengingWrath:CooldownRemains() <= 30)) then
    if Cast(S.SacredWeapon, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 6"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=spell_targets.shield_of_the_righteous>3&buff.bulwark_of_righteous_fury.stack>=3&holy_power<3
  if S.Judgment:IsReady() and (EnemiesCount8y > 3 and Player:BuffStack(S.BulwarkofRighteousFuryBuff) >= 3 and Player:HolyPower() < 3) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 8"; end
  end
  -- avengers_shield,if=!buff.bulwark_of_righteous_fury.up&talent.bulwark_of_righteous_fury.enabled&spell_targets.shield_of_the_righteous>=3
  if S.AvengersShield:IsCastable() and (Player:BuffDown(S.BulwarkofRighteousFuryBuff) and S.BulwarkofRighteousFury:IsAvailable() and EnemiesCount8y >= 3) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 10"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath standard 12"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=charges>=2|full_recharge_time<=gcd.max
  if S.Judgment:IsReady() and (S.Judgment:Charges() >= 2 or S.Judgment:FullRechargeTime() <= Player:GCD() + 0.25) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 14"; end
  end
  -- holy_armaments,if=next_armament=holy_bulwark&charges=2
  if S.HolyBulwark:IsCastable() and (S.HolyBulwark:Charges() == 2) then
    if Cast(S.HolyBulwark, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 16"; end
  end
  -- divine_toll,if=(!raid_event.adds.exists|raid_event.adds.in>10)
  if CDsON() and S.DivineToll:IsReady() then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.DivineToll, not Target:IsInRange(30)) then return "divine_toll standard 16"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 18"; end
  end
  -- avengers_shield,if=!talent.lights_guidance.enabled
  if S.AvengersShield:IsCastable() and (not S.LightsGuidance:IsAvailable()) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 20"; end
  end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff)) then
    if Cast(S.Consecration) then return "consecration standard 22"; end
  end
  -- eye_of_tyr,if=(talent.inmost_light.enabled&raid_event.adds.in>=45|spell_targets.shield_of_the_righteous>=3)&!talent.lights_deliverance.enabled
  -- Note: Ignoring CDsON if spec'd Templar Hero Tree.
  if (CDsON() or S.LightsGuidance:IsAvailable()) and S.EyeofTyr:IsCastable() and ((S.InmostLight:IsAvailable() and EnemiesCount8y == 1 or EnemiesCount8y >= 3) and not S.LightsDeliverance:IsAvailable()) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr standard 24"; end
  end
  -- holy_armaments,if=next_armament=holy_bulwark
  if S.HolyBulwark:IsCastable() then
    if Cast(S.HolyBulwark, nil, Settings.CommonsDS.DisplayStyle.HolyArmaments) then return "holy_armaments standard 26"; end
  end
  -- blessed_hammer
  if S.BlessedHammer:IsCastable() then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 28"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 30"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike standard 32"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up&talent.lights_guidance.enabled
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff) and S.LightsGuidance:IsAvailable()) then
    -- Is our health ok? Are we in a party with a wounded party member? Heal them instead.
    if Player:HealthPercentage() > 90 and Player:IsInParty() and not Player:IsInRaid() then
      for _, Char in pairs(Unit.Party) do
        if Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() <= 80 then
          if HR.CastAnnotated(S.WordofGlory, false, Char:Name()) then return "word_of_glory standard party 34"; end
        end
      end
      -- Nobody in the party needs it. We might as well heal ourselves for the extra block chance.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 36"; end
    else
      -- We're either solo, in a raid, or injured. Heal ourselves.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 38"; end
    end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 40"; end
  end
  -- eye_of_tyr,if=!talent.lights_deliverance.enabled
  -- Note: Ignoring CDsON if spec'd Templar Hero Tree.
  if (CDsON() or S.LightsGuidance:IsAvailable()) and S.EyeofTyr:IsCastable() and (not S.LightsDeliverance:IsAvailable()) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr standard 42"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff)) then
    -- Is our health ok? Are we in a party with a wounded party member? Heal them instead.
    if Player:HealthPercentage() > 90 and Player:IsInParty() and not Player:IsInRaid() then
      for _, Char in pairs(Unit.Party) do
        if Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() <= 80 then
          if HR.CastAnnotated(S.WordofGlory, false, Char:Name()) then return "word_of_glory standard party 44"; end
        end
      end
      -- Nobody in the party needs it. We might as well heal ourselves for the extra block chance.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 46"; end
    else
      -- We're either solo, in a raid, or injured. Heal ourselves.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 48"; end
    end
  end
  -- arcane_torrent,if=holy_power<5
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:HolyPower() < 5) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent standard 50"; end
  end
  -- consecration,if=!buff.sanctification_empower.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.SanctificationEmpowerBuff)) then
    if Cast(S.Consecration) then return "consecration standard 52"; end
  end
end

local function Trinkets()
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
  HR.Print("Protection Paladin rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(66, APL, Init)

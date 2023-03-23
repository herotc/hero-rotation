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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Paladin.Protection
local I = Item.Paladin.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Interrupts List
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

-- Rotation Var
local ActiveMitigationNeeded
local IsTanking
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Protection = HR.GUISettings.APL.Paladin.Protection
}

local function EvaluateTargetIfFilterJudgment(TargetUnit)
  return TargetUnit:DebuffRemains(S.JudgmentDebuff)
end

local function MissingAura()
  return (Player:BuffDown(S.RetributionAura) and Player:BuffDown(S.DevotionAura) and Player:BuffDown(S.ConcentrationAura) and Player:BuffDown(S.CrusaderAura))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: devotion_aura
  if S.DevotionAura:IsCastable() and (MissingAura()) then
    if Cast(S.DevotionAura) then return "devotion_aura precombat 2"; end
  end
  -- lights_judgment
  if CDsON() and S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment precombat 4"; end
  end
  -- arcane_torrent
  if CDsON() and S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent precombat 6"; end
  end
  -- consecration
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(8) then
    if Cast(S.Consecration) then return "consecration precombat 8"; end
  end
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&((talent.moment_of_glory.enabled&trinket.1.cooldown.duration%%cooldown.moment_of_glory.duration=0)|(!talent.moment_of_glory.enabled&trinket.1.cooldown.duration%%cooldown.avenging_wrath.duration=0))
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&((talent.moment_of_glory.enabled&trinket.2.cooldown.duration%%cooldown.moment_of_glory.duration=0)|(!talent.moment_of_glory.enabled&trinket.2.cooldown.duration%%cooldown.avenging_wrath.duration=0))
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!trinket.1.has_use_buff&trinket.2.has_use_buff|trinket.2.has_use_buff&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit
  -- Note: Unable to handle some trinket conditionals, such as cooldown.duration.
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
  if S.WordofGlory:IsReady() and (Player:HealthPercentage() <= Settings.Protection.WordofGloryHP and not Player:HealingAbsorbed()) then
    -- cast word of glory on us if it's a) free or b) probably not going to drop sotr
    if (Player:BuffRemains(S.ShieldoftheRighteousBuff) >= 5 or Player:BuffUp(S.DivinePurposeBuff) or Player:BuffUp(S.ShiningLightFreeBuff)) then
      if Cast(S.WordofGlory) then return "word_of_glory defensive 8"; end
    else
      -- cast it anyway but run the fuck away
      if HR.CastAnnotated(S.WordofGlory, false, "KITE") then return "word_of_glory defensive 10"; end
    end
  end

  if S.ShieldoftheRighteous:IsReady() and (Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Protection.ShieldoftheRighteousHP)) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then return "shield_of_the_righteous defensive 12"; end
  end
end

local function Cooldowns()
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if Cast(S.AvengingWrath, Settings.Protection.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 2"; end
  end
  -- potion,if=buff.avenging_wrath.up
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvengingWrathBuff)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 4"; end
    end
  end
  -- moment_of_glory,if=(buff.avenging_wrath.remains<15|(time>10|(cooldown.avenging_wrath.remains>15))&(cooldown.avengers_shield.remains&cooldown.judgment.remains&cooldown.hammer_of_wrath.remains))
  if S.MomentofGlory:IsCastable() and (Player:BuffRemains(S.AvengingWrathBuff) < 15 or (HL.CombatTime() > 10 or (S.AvengingWrath:CooldownRemains() > 15)) and (S.AvengersShield:CooldownDown() and S.Judgment:CooldownDown() and S.HammerofWrath:CooldownDown())) then
    if Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentOfGlory) then return "moment_of_glory cooldowns 6"; end
  end
  -- holy_avenger,if=buff.avenging_wrath.up|cooldown.avenging_wrath.remains>60
  if S.HolyAvenger:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or S.AvengingWrath:CooldownRemains() > 60) then
    if Cast(S.HolyAvenger, Settings.Protection.OffGCDasOffGCD.HolyAvenger) then return "holy_avenger cooldowns 8"; end
  end
  -- bastion_of_light,if=buff.avenging_wrath.up
  if S.BastionofLight:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff)) then
    if Cast(S.BastionofLight, Settings.Protection.OffGCDasOffGCD.BastionOfLight) then return "bastion_of_light cooldowns 10"; end
  end
end

local function Trinkets()
  -- use_item,slot=trinket1,if=(buff.moment_of_glory.up|!talent.moment_of_glory_enabled&buff.avenging_wrath.up)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket2,if=(buff.moment_of_glory.up|!talent.moment_of_glory_enabled&buff.avenging_wrath.up)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs|(cooldown.moment_of_glory.remains>20|(!talent.moment_of_glory.enabled&cooldown.avenging_wrath.remains>20)))
  -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs|(cooldown.moment_of_glory.remains>20|(!talent.moment_of_glory.enabled&cooldown.avenging_wrath.remains>20)))
  -- Note: Unable to handle some trinket conditionals, such as cooldown.duration. Using a generic fallback instead.
  -- use_items,if=(buff.moment_of_glory.up|!talent.moment_of_glory.enabled&buff.avenging_wrath.up)|(cooldown.moment_of_glory.remains>20|!talent.moment_of_glory.enabled&cooldown.avenging_wrath.remains>20)
  if ((Player:BuffUp(S.MomentofGloryBuff) or (not S.MomentofGlory:IsAvailable()) and Player:BuffUp(S.AvengingWrathBuff)) or (S.MomentofGlory:CooldownRemains() > 20 or (not S.MomentofGlory:IsAvailable()) and S.AvengingWrath:CooldownRemains() > 20)) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Standard()
  -- shield_of_the_righteous,if=(!talent.righteous_protector.enabled|cooldown.righteous_protector_icd.remains=0)&(buff.bastion_of_light.up|buff.divine_purpose.up|holy_power>2)
  -- TODO: Find a way to track RighteousProtector ICD.
  if S.ShieldoftheRighteous:IsReady() and (Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.DivinePurposeBuff) or Player:HolyPower() > 2) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then return "shield_of_the_righteous standard 2"; end
  end
  -- avengers_shield,if=buff.moment_of_glory.up|!talent.moment_of_glory.enabled
  if S.AvengersShield:IsCastable() and (Player:BuffUp(S.MomentofGloryBuff) or not S.MomentofGlory:IsAvailable()) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 4"; end
  end
  -- hammer_of_wrath,if=buff.avenging_wrath.up
  if S.HammerofWrath:IsReady() and (Player:BuffUp(S.AvengingWrathBuff)) then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath standard 6"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=charges=2|!talent.crusaders_judgment.enabled
  if S.Judgment:IsReady() and (S.Judgment:Charges() == 2 or not S.CrusadersJudgment:IsAvailable()) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 8"; end
  end
  -- divine_toll,if=time>20|((buff.avenging_wrath.up|!talent.avenging_wrath.enabled)&(buff.moment_of_glory.up|!talent.moment_of_glory.enabled))
  if CDsON() and S.DivineToll:IsReady() and (HL.CombatTime() > 20 or ((Player:BuffUp(S.AvengingWrathBuff) or not S.AvengingWrath:IsAvailable()) and (Player:BuffUp(S.MomentofGloryBuff) or not S.MomentofGlory:IsAvailable()))) then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "divine_toll standard 10"; end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 12"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath standard 14"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 16"; end
  end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff)) then
    if Cast(S.Consecration) then return "consecration standard 18"; end
  end
  -- eye_of_tyr
  if CDsON() and S.EyeofTyr:IsCastable() then
    if Cast(S.EyeofTyr, nil, nil, not Target:IsInMeleeRange(8)) then return "eye_of_tyr standard 20"; end
  end
  -- blessed_hammer
  if S.BlessedHammer:IsCastable() then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 22"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 24"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike standard 26"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff)) then
    -- Is our health ok? Are we in a party with a wounded party member? Heal them instead.
    if Player:HealthPercentage() > 90 and Player:IsInParty() and not Player:IsInRaid() then
      for _, Char in pairs(Unit.Party) do
        if Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() <= 80 then
          if HR.CastAnnotated(S.WordofGlory, false, Char:Name()) then return "word_of_glory standard party 28"; end
        end
      end
      -- Nobody in the party needs it. We might as well heal ourselves for the extra block chance.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 30"; end
    else
      -- We're either solo, in a raid, or injured. Heal ourselves.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then return "word_of_glory standard self 32"; end
    end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if Cast(S.Consecration) then return "consecration standard 34"; end
  end
end

-- APL Main
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

  ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives!
    if IsTanking then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard
    local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pool, if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Protection Paladin rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(66, APL, Init)

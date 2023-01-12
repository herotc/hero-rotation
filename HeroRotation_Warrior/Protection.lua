--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local mathfloor  = math.floor

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Warrior.Protection
local I = Item.Warrior.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Variables
local TargetInMeleeRange

-- Enemies Variables
local Enemies8y
local EnemiesCount8

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Protection = HR.GUISettings.APL.Warrior.Protection
}

-- Stuns
local StunInterrupts = {
  {S.IntimidatingShout, "Cast Intimidating Shout (Interrupt)", function () return true; end},
}

local function IsCurrentlyTanking()
  return Player:IsTankingAoE(16) or Player:IsTanking(Target) or Target:IsDummy()
end

local function IgnorePainWillNotCap()
  if Player:BuffUp(S.IgnorePain) then
    local absorb = Player:AttackPowerDamageMod() * 3.5 * (1 + Player:VersatilityDmgPct() / 100)
    local spellTable = Player:AuraInfo(S.IgnorePain, nil, true)
    local IPAmount = spellTable.points[1]
    --return IPAmount < (0.5 * mathfloor(absorb * 1.3))
    -- Ignore Pain appears to cap at 2 times its absorb value now
    return IPAmount < absorb
  else
    return true
  end
end

local function IgnorePainValue()
  if Player:BuffUp(S.IgnorePain) then
    local IPBuffInfo = Player:BuffInfo(S.IgnorePain, nil, true)
    return IPBuffInfo.points[1]
  else
    return 0
  end
end

local function ShouldPressShieldBlock()
  -- shield_block,if=(buff.shield_block.down|buff.shield_block.remains<cooldown.shield_slam.remains)&target.health.pct>20
  return IsCurrentlyTanking() and S.ShieldBlock:IsReady() and ((Player:BuffDown(S.ShieldBlockBuff) or Player:BuffRemains(S.ShieldBlockBuff) < S.ShieldSlam:CooldownRemains()) and Player:BuffDown(S.LastStandBuff) and Target:HealthPercentage() > 20)
end

-- A bit of logic to decide whether to pre-cast-rage-dump on ignore pain.
local function SuggestRageDump(RageFromSpell)
  -- Get RageMax from setting (default 80)
  local RageMax = Settings.Protection.RageCapValue
  -- If the setting value is lower than 35, it's not possible to cast Ignore Pain, so just return false
  if (RageMax < 35 or Player:Rage() < 35) then return false end
  local shouldPreRageDump = false
  -- Make sure we have enough Rage to cast IP, that it's not on CD, and that we shouldn't use Shield Block
  local AbleToCastIP = (Player:Rage() >= 35 and not ShouldPressShieldBlock())
  if AbleToCastIP and (Player:Rage() + RageFromSpell >= RageMax or S.DemoralizingShout:IsReady()) then
    -- should pre-dump rage into IP if rage + RageFromSpell >= RageMax or Demo Shout is ready
      shouldPreRageDump = true
  end
  if shouldPreRageDump then
    if IgnorePainWillNotCap() then
      if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "ignore_pain rage capped"; end
    else
      if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge rage capped"; end
    end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.BattleShout:IsCastable() and (Player:BuffDown(S.BattleShoutBuff, true) or Everyone.GroupBuffMissing(S.BattleShoutBuff)) then
    if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- Manually added opener
  if Target:IsInMeleeRange(12) then
    if S.ThunderClap:IsCastable() then
      if Cast(S.ThunderClap) then return "thunder_clap precombat"; end
    end
  else
    if S.ShieldCharge:IsCastable() then
      if Cast(S.ShieldCharge, nil, nil, not Target:IsSpellInRange(S.ShieldCharge)) then return "shield_charge precombat"; end
    end
    if S.Charge:IsCastable() and not Target:IsInRange(8) then
      if Cast(S.Charge, nil, nil, not Target:IsSpellInRange(S.Charge)) then return "charge precombat"; end
    end
  end
end

local function Defensive()
  if ShouldPressShieldBlock() then
    if Cast(S.ShieldBlock, nil, Settings.Protection.DisplayStyle.Defensive) then return "shield_block defensive"; end
  end
  -- shield_wall,if=!buff.last_stand.up&!buff.rallying_cry.up
  if S.ShieldWall:IsCastable() and (Player:BuffDown(S.LastStandBuff) and Player:BuffDown(S.RallyingCryBuff)) then
    if Cast(S.ShieldWall, nil, Settings.Protection.DisplayStyle.Defensive) then return "shield_wall defensive"; end
  end
  -- last_stand,if=!buff.shield_wall.up&!buff.rallying_cry.up
  if S.LastStand:IsCastable() and (Player:BuffDown(S.ShieldBlockBuff) and S.ShieldBlock:Recharge() > 1) then
    if Cast(S.LastStand, nil, Settings.Protection.DisplayStyle.Defensive) then return "last_stand defensive"; end
  end
  -- rallying_cry,if=!buff.last_stand.up&!buff.shield_wall.up
  if S.RallyingCry:IsCastable() and (Player:BuffDown(S.LastStandBuff) and Player:BuffDown(S.ShieldWallBuff)) then
    if Cast(S.RallyingCry, nil, Settings.Protection.DisplayStyle.Defensive) then return "rallying_cry defensive"; end
  end
  -- demoralizing_shout,if=!buff.last_stand.up&!buff.shield_wall.up&!buff.rallying_cry.up
  if S.DemoralizingShout:IsCastable() and (Player:BuffDown(S.LastStandBuff) and Player:BuffDown(S.ShieldWallBuff) and Player:BuffDown(S.RallyingCryBuff)) then
    if Cast(S.DemoralizingShout, nil, Settings.Protection.DisplayStyle.Defensive) then return "demoralizing_shout defensive"; end
  end
  -- Manually added: VR/IV
  if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
    if S.VictoryRush:IsReady() then
      if Cast(S.VictoryRush) then return "victory_rush defensive"; end
    end
    if S.ImpendingVictory:IsReady() then
      if Cast(S.ImpendingVictory) then return "impending_victory defensive"; end
    end
  end
end

local function Aoe()
  -- ignore_pain,if=rage.deficit>=35&buff.ignore_pain.value<health.max*0.3
  if S.IgnorePain:IsReady() and (Player:RageDeficit() >= 35 and IgnorePainValue() < Player:MaxHealth() * 0.3) then
    if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "ignore_pain aoe 2"; end
  end
  -- spear_of_bastion
  if S.SpearofBastion:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature) then return "spear_of_bastion aoe 4"; end
  end
  -- thunderous_roar
  if S.ThunderousRoar:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.ThunderousRoar, Settings.Protection.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar aoe 6"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.Ravager, Settings.Protection.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager aoe 8"; end
  end
  -- shockwave
  if S.Shockwave:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.Shockwave, Settings.Protection.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave aoe 10"; end
  end
  -- shield_charge
  if S.ShieldCharge:IsCastable() then
    if Cast(S.ShieldCharge, nil, nil, not Target:IsSpellInRange(S.ShieldCharge)) then return "shield_charge aoe 12"; end
  end
  -- revenge,if=rage.deficit>30
  if S.Revenge:IsReady() and (not ShouldPressShieldBlock()) and (Player:RageDeficit() > 30) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge aoe 14"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap aoe 16"; end
  end
  -- titanic_throw
  if S.TitanicThrow:IsCastable() then
    if Cast(S.TitanicThrow, nil, nil, not Target:IsInRange(30)) then return "titanic_throw aoe 18"; end
  end
  -- rend,if=!talent.thunderclap&!talent.blood_and_thunder
  if S.Rend:IsReady() and (not ShouldPressShieldBlock()) and ((not S.ThunderClap:IsAvailable()) and not S.BloodandThunder:IsAvailable()) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend aoe 20"; end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam aoe 22"; end
  end
  -- execute
  if S.Execute:IsReady() and not ShouldPressShieldBlock() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute aoe 24"; end
  end
  -- devastate
  if S.Devastate:IsCastable() then
    if Cast(S.Devastate, nil, nil, not TargetInMeleeRange) then return "devastate aoe 26"; end
  end
  -- impending_victory
  if S.ImpendingVictory:IsReady() then
    if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory aoe 28"; end
  end
  -- storm_bolt
  if S.StormBolt:IsCastable() then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt aoe 30"; end
  end
end

local function Generic()
  -- ignore_pain,if=(rage.deficit>=35&buff.ignore_pain.value<health.max*0.3*0.5)|buff.ignore_pain.remains<gcd
  if S.IgnorePain:IsReady() and ((Player:RageDeficit() >= 35 and IgnorePainValue() < Player:MaxHealth() * 0.3 * 0.5) or Player:BuffRemains(S.IgnorePain) < Player:GCD()) then
    if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "ignore_pain generic 2"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.Ravager, Settings.Protection.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager generic 4"; end
  end
  -- thunderous_roar
  if S.ThunderousRoar:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.ThunderousRoar, Settings.Protection.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar generic 6"; end
  end
  -- spear_of_bastion
  if S.SpearofBastion:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(25)) then return "spear_of_bastion generic 8"; end
  end
  -- shield_charge
  if S.ShieldCharge:IsCastable() then
    if Cast(S.ShieldCharge, nil, nil, not Target:IsSpellInRange(S.ShieldCharge)) then return "shield_charge generic 10"; end
  end
  -- shockwave
  if S.Shockwave:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.Shockwave, Settings.Protection.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave generic 12"; end
  end
  -- execute
  if S.Execute:IsReady() and not ShouldPressShieldBlock() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute generic 14"; end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam generic 16"; end
  end
  -- thunder_clap,if=active_enemies>=2|(talent.rend&talent.blood_and_thunder)
  if S.ThunderClap:IsCastable() and (EnemiesCount8 >= 2 or (S.Rend:IsAvailable() and S.BloodandThunder:IsAvailable())) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap generic 18"; end
  end
  if (not ShouldPressShieldBlock()) then
    -- rend,if=!talent.thunderclap&!talent.blood_and_thunder
    if S.Rend:IsReady() and ((not S.ThunderClap:IsAvailable()) and not S.BloodandThunder:IsAvailable()) then
      if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend generic 20"; end
    end
    -- revenge,if=rage.deficit>30&active_enemies>=2
    if S.Revenge:IsReady() and (Player:RageDeficit() > 30 and EnemiesCount8 >= 2) then
      if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 22"; end
    end
  end
  -- titanic_throw,if=active_enemies>=2
  if S.TitanicThrow:IsCastable() and (EnemiesCount8 >= 2) then
    if Cast(S.TitanicThrow, nil, nil, not Target:IsInRange(30)) then return "titanic_throw generic 24"; end
  end
  -- devastate
  if S.Devastate:IsCastable() then
    if Cast(S.Devastate, nil, nil, not TargetInMeleeRange) then return "devastate generic 26"; end
  end
  -- heroic_throw
  if S.HeroicThrow:IsCastable() then
    if Cast(S.HeroicThrow, nil, nil, not Target:IsInRange(30)) then return "heroic_throw generic 28"; end
  end
  -- titanic_throw
  if S.TitanicThrow:IsCastable() then
    if Cast(S.TitanicThrow, nil, nil, not Target:IsInRange(30)) then return "titanic_throw generic 30"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap generic 32"; end
  end
  -- revenge,if=rage.deficit>30
  if S.Revenge:IsReady() and (not ShouldPressShieldBlock()) and (Player:RageDeficit() > 30) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 34"; end
  end
  -- impending_victory
  if S.ImpendingVictory:IsReady() then
    if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory generic 36"; end
  end
  -- storm_bolt
  if S.StormBolt:IsCastable() then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt generic 38"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    EnemiesCount8 = #Enemies8y
  else
    EnemiesCount8 = 1
  end

  -- Range check
  TargetInMeleeRange = Target:IsInMeleeRange(5)

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Check defensives if tanking
    if IsCurrentlyTanking() then
      local ShouldReturn = Defensive(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- shield_charge,if=time=0
    -- charge,if=time=0
    -- Note: Above 2 lines handled in Precombat
    -- use_items,if=talent.avatar&(cooldown.avatar.remains<=gcd|buff.avatar.up)|!talent.avatar
    if Settings.Commons.Enabled.Trinkets and (S.Avatar:IsAvailable() and (S.Avatar:CooldownRemains() <= Player:GCD() or Player:BuffUp(S.AvatarBuff)) or not S.Avatar:IsAvailable()) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if CDsON() and (Player:BuffUp(S.AvatarBuff) or not S.Avatar:IsAvailable()) then
      -- blood_fury,if=buff.avatar.up|!talent.avatar
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 2"; end
      end
      -- berserking,if=buff.avatar.up|!talent.avatar
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 4"; end
      end
      -- fireblood,if=buff.avatar.up|!talent.avatar
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 6"; end
      end
      -- ancestral_call,if=buff.avatar.up|!talent.avatar
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 8"; end
      end
    end
    -- potion,if=buff.avatar.up|target.time_to_die<25
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 25) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 10"; end
      end
    end
    -- revenge,if=buff.revenge.up&(target.health.pct>20|spell_targets.thunder_clap>3)&cooldown.shield_slam.remains
    if S.Revenge:IsReady() and (Player:BuffUp(S.RevengeBuff) and (Target:HealthPercentage() > 20 or EnemiesCount8 > 3) and S.ShieldSlam:CooldownRemains() > 0) then
      if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge main 12"; end
    end
    -- ignore_pain,if=target.health.pct>=20&(target.health.pct>=80&!covenant.venthyr)&(rage>=85&cooldown.shield_slam.ready&buff.shield_block.up|rage>=60&cooldown.demoralizing_shout.ready&talent.booming_voice.enabled|rage>=70&cooldown.avatar.ready|rage>=40&cooldown.demoralizing_shout.ready&talent.booming_voice.enabled&buff.last_stand.up|rage>=55&cooldown.avatar.ready&buff.last_stand.up|rage>=80|rage>=55&cooldown.shield_slam.ready&buff.violent_outburst.up&buff.shield_block.up|rage>=30&cooldown.shield_slam.ready&buff.violent_outburst.up&buff.last_stand.up&buff.shield_block.up),use_off_gcd=1
    if S.IgnorePain:IsReady() and IgnorePainWillNotCap() and (Target:HealthPercentage() >= 20 and (Player:Rage() >= 85 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.ShieldBlockBuff) or Player:Rage() >= 60 and S.DemoralizingShout:CooldownUp() and S.BoomingVoice:IsAvailable() or Player:Rage() >= 70 and S.Avatar:CooldownUp() or Player:Rage() >= 40 and S.DemoralizingShout:CooldownUp() and S.BoomingVoice:IsAvailable() and Player:BuffUp(S.LastStandBuff) or Player:Rage() >= 55 and S.Avatar:CooldownUp() and Player:BuffUp(S.LastStandBuff) or Player:Rage() >= 80 or Player:Rage() >= 55 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.ViolentOutburstBuff) and Player:BuffUp(S.ShieldBlockBuff) or Player:Rage() >= 30 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.ViolentOutburstBuff) and Player:BuffUp(S.LastStandBuff) and Player:BuffUp(S.ShieldBlockBuff))) then
      if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "ignore_pain main 14"; end
    end
    -- shield_block,if=(buff.shield_block.down|buff.shield_block.remains<cooldown.shield_slam.remains)&target.health.pct>20
    -- Note: Handled via Defensive()
    -- shield_slam,if=buff.violent_outburst.up&rage<=55
    if S.ShieldSlam:IsCastable() and (Player:BuffUp(S.ViolentOutburstBuff) and Player:Rage() <= 55) then
      SuggestRageDump(20)
      if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam main 16"; end
    end
    if (CDsON()) then
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racial"; end
      end
      -- arcane_torrent,if=rage<80
      if S.ArcaneTorrent:IsCastable() and (Player:Rage() < 80) then
        if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racial"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastable() then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment racial"; end
      end
    end
    -- shield_wall,if=!buff.last_stand.up&!buff.rallying_cry.up
    -- last_stand,if=!buff.shield_wall.up&!buff.rallying_cry.up
    -- rallying_cry,if=!buff.last_stand.up&!buff.shield_wall.up
    -- demoralizing_shout,if=!buff.last_stand.up&!buff.shield_wall.up&!buff.rallying_cry.up
    -- Note: Above 4 lines handled in Defensive()
    -- berserker_rage
    -- spell_reflection
    -- Note: Above 2 lines are too situational to be included
    -- avatar
    if CDsON() and S.Avatar:IsCastable() then
      if Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "avatar main 18"; end
    end
    -- run_action_list,name=aoe,if=spell_targets.thunder_clap>3
    if EnemiesCount8 > 3 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Aoe()"; end
    end
    -- call_action_list,name=generic
    local ShouldReturn = Generic(); if ShouldReturn then return ShouldReturn; end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Protection Warrior rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(73, APL, Init)

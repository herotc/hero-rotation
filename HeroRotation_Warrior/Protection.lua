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

-- Legendaries
local ReprisalEquipped = Player:HasLegendaryEquipped(193)
local GloryEquipped = Player:HasLegendaryEquipped(214)

-- Event Registrations
HL:RegisterForEvent(function()
  ReprisalEquipped = Player:HasLegendaryEquipped(193)
  GloryEquipped = Player:HasLegendaryEquipped(214)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

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

local function ShouldPressShieldBlock()
  return IsCurrentlyTanking() and S.ShieldBlock:IsReady() and ((Player:BuffDown(S.ShieldBlockBuff) or Player:BuffRemains(S.ShieldBlockBuff) < S.ShieldSlam:CooldownRemains()) and Player:BuffDown(S.LastStandBuff))
end

-- A bit of logic to decide whether to pre-cast-rage-dump on ignore pain.
local function SuggestRageDump(RageFromSpell)
  -- Get RageMax from setting (default 80)
  local RageMax = Settings.Protection.RageCapValue
  -- If the setting value is lower than 35, it's not possible to cast Ignore Pain, so just return false
  if (RageMax < 35 or Player:Rage() < 35) then return false end
  local ShouldPreRageDump = false
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
  -- fleshcraft
  -- Note: Manually moved this above conquerors_banner so we don't waste 3s of the banner buff
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat"; end
  end
  -- conquerors_banner
  if S.ConquerorsBanner:IsCastable() then
    if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner precombat"; end
  end
  -- Manually added opener
  if Target:IsInMeleeRange(12) then
    if S.ThunderClap:IsCastable() then
      if Cast(S.ThunderClap) then return "thunder_clap precombat"; end
    end
  else
    if S.Charge:IsCastable() and not Target:IsInRange(8) then
      if Cast(S.Charge, nil, nil, not Target:IsSpellInRange(S.Charge)) then return "charge precombat"; end
    end
  end
end

local function Defensive()
  if ShouldPressShieldBlock() then
    if Cast(S.ShieldBlock, nil, Settings.Protection.DisplayStyle.Defensive) then return "shield_block defensive" end
  end
  if S.LastStand:IsCastable() and (Player:BuffDown(S.ShieldBlockBuff) and S.ShieldBlock:Recharge() > 1) then
    if Cast(S.LastStand, nil, Settings.Protection.DisplayStyle.Defensive) then return "last_stand defensive" end
  end
  if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
    if S.VictoryRush:IsReady() then
      if Cast(S.VictoryRush) then return "victory_rush defensive" end
    end
    if S.ImpendingVictory:IsReady() then
      if Cast(S.ImpendingVictory) then return "impending_victory defensive" end
    end
  end
end

local function Aoe()
  -- ravager
  if S.Ravager:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager aoe 2"; end
  end
  -- dragon_roar
  if S.DragonRoar:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar, nil, not Target:IsInMeleeRange(12)) then return "dragon_roar aoe 4"; end
  end
  -- thunder_clap,if=buff.outburst.up
  if S.ThunderClap:IsCastable() and (Player:BuffUp(S.OutburstBuff)) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap aoe 6"; end
  end
  -- revenge
  -- Manually added: Reserve 30 Rage for ShieldBlock
  if S.Revenge:IsReady() and (Player:Rage() >= 50 and not ShouldPressShieldBlock()) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge aoe 8"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap aoe 6"; end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(15)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam aoe 10"; end
  end
end

local function Generic()
  -- ravager
  if S.Ravager:IsCastable() then
    SuggestRageDump(10)
    if Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager generic 2"; end
  end
  -- dragon_roar
  if S.DragonRoar:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar, nil, not Target:IsInMeleeRange(12)) then return "dragon_roar generic 4"; end
  end
  if (not ShouldPressShieldBlock()) then
    -- execute
    if S.Execute:IsReady() then
      if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute generic 6"; end
    end
    -- condemn
    if S.Condemn:IsReady() then
      if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn generic 8"; end
    end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(15)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam generic 10"; end
  end
  -- thunder_clap,if=buff.outburst.down
  if S.ThunderClap:IsCastable() and (Player:BuffDown(S.OutburstBuff)) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap generic 20"; end
  end
  -- revenge
  -- Manually added: Reserve 30 Rage for ShieldBlock
  if S.Revenge:IsReady() and (Player:Rage() >= 50 and not ShouldPressShieldBlock()) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 22"; end
  end
  -- devastate
  if S.Devastate:IsCastable() then
    if Cast(S.Devastate, nil, nil, not TargetInMeleeRange) then return "devastate generic 24"; end
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
    -- charge,if=time=0
    -- Note: Handled in Precombat
    -- heroic_charge,if=buff.revenge.down&(rage<60|rage<44&buff.last_stand.up)
    if (not Settings.Protection.DisableHeroicCharge) and S.HeroicLeap:IsCastable() and S.Charge:IsCastable() and (Player:BuffDown(S.RevengeBuff) and (Player:Rage() < 60 or Player:Rage() < 44 and Player:BuffUp(S.LastStandBuff))) then
      if HR.CastQueue(S.HeroicLeap, S.Charge) then return "heroic_leap/charge main 2"; end
    end
    -- intervene,if=buff.revenge.down&(rage<80|rage<77&buff.last_stand.up)&runeforge.reprisal
    if (not Settings.Protection.DisableIntervene) and S.Intervene:IsCastable() and (Player:BuffDown(S.RevengeBuff) and (Player:Rage() < 80 or Player:Rage() < 77 and Player:BuffUp(S.LastStandBuff)) and ReprisalEquipped) then
      if Cast(S.Intervene, Settings.Protection.OffGCDasOffGCD.Intervene) then return "intervene main 4"; end
    end
    -- use_items,if=cooldown.avatar.remains<=gcd|buff.avatar.up
    if (Settings.Commons.Enabled.Trinkets and (S.Avatar:CooldownRemains() <= Player:GCD() or Player:BuffUp(S.AvatarBuff))) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if (CDsON() and Player:BuffUp(S.AvatarBuff)) then
      -- blood_fury,if=buff.avatar.up
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=buff.avatar.up
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- fireblood,if=buff.avatar.up
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call,if=buff.avatar.up
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
    end
    -- thunder_clap,if=buff.outburst.up&((buff.seeing_red.stack>6&cooldown.shield_slam.remains>2))
    if S.ThunderClap:IsCastable() and (Player:BuffUp(S.OutburstBuff) and (Player:BuffStack(S.SeeingRedBuff) > 6 and S.ShieldSlam:CooldownRemains() > 2)) then
      if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap main 6"; end
    end
    -- avatar,if=buff.outburst.down
    if S.Avatar:IsCastable() and (Player:BuffDown(S.OutburstBuff)) then
      if Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "avatar main 8"; end
    end
    -- potion,if=buff.avatar.up|target.time_to_die<25
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 25) then
      if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 10"; end
    end
    if CDsON() then
      -- conquerors_banner
      if S.ConquerorsBanner:IsCastable() then
        if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner main 12"; end
      end
      -- ancient_aftershock
      if S.AncientAftershock:IsCastable() then
        if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "ancient_aftershock main 14"; end
      end
      -- spear_of_bastion
      if S.SpearofBastion:IsCastable() then
        if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion main 16"; end
      end
    end
    -- revenge,if=buff.revenge.up&(target.health.pct>20|spell_targets.thunder_clap>3)&cooldown.shield_slam.remains
    if S.Revenge:IsReady() and (Player:BuffUp(S.RevengeBuff) and (Target:HealthPercentage() > 20 or EnemiesCount8 > 3) and S.ShieldSlam:CooldownRemains() > 0) then
      if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge main 18"; end
    end
    -- ignore_pain,if=target.health.pct>=20&(target.health.pct>=80&!covenant.venthyr)&(rage>=85&cooldown.shield_slam.ready&buff.shield_block.up|rage>=60&cooldown.demoralizing_shout.ready&talent.booming_voice.enabled|rage>=70&cooldown.avatar.ready|rage>=40&cooldown.demoralizing_shout.ready&talent.booming_voice.enabled&buff.last_stand.up|rage>=55&cooldown.avatar.ready&buff.last_stand.up|rage>=80|rage>=55&cooldown.shield_slam.ready&buff.outburst.up&buff.shield_block.up|rage>=30&cooldown.shield_slam.ready&buff.outburst.up&buff.last_stand.up&buff.shield_block.up),use_off_gcd=1
    if S.IgnorePain:IsReady() and IgnorePainWillNotCap() and (Target:HealthPercentage() >= 20 and (Target:HealthPercentage() >= 80 and CovenantID ~= 2) and (Player:Rage() >= 85 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.ShieldBlockBuff) or Player:Rage() >= 60 and S.DemoralizingShout:CooldownUp() and S.BoomingVoice:IsAvailable() or Player:Rage() >= 70 and S.Avatar:CooldownUp() or Player:Rage() >= 40 and S.DemoralizingShout:CooldownUp() and S.BoomingVoice:IsAvailable() and Player:BuffUp(S.LastStandBuff) or Player:Rage() >= 55 and S.Avatar:CooldownUp() and Player:BuffUp(S.LastStandBuff) or Player:Rage() >= 80 or Player:Rage() >= 55 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.OutburstBuff) and Player:BuffUp(S.ShieldBlockBuff) or Player:Rage() >= 30 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.OutburstBuff) and Player:BuffUp(S.LastStandBuff) and Player:BuffUp(S.ShieldBlockBuff))) then
      if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "ignore_pain main 20"; end
    end
    -- shield_block,if=(buff.shield_block.down|buff.shield_block.remains<cooldown.shield_slam.remains)&target.health.pct>20
    -- Note: Handled via Defensive()
    -- last_stand,if=target.health.pct>=90|target.health.pct<=20
    -- Note: Handled via Defensive()
    -- demoralizing_shout,if=talent.booming_voice.enabled&rage<60
    if S.DemoralizingShout:IsCastable() and (S.BoomingVoice:IsAvailable() and Player:Rage() < 60) then
      SuggestRageDump(40)
      if Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout, nil, not Target:IsInRange(10)) then return "demoralizing_shout main 22"; end
    end
    -- shield_slam,if=buff.outburst.up&rage<=55
    if S.ShieldSlam:IsCastable() and (Player:BuffUp(S.OutburstBuff) and Player:Rage() <= 55) then
      if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam main 24"; end
    end
    -- run_action_list,name=aoe,if=spell_targets.thunder_clap>3
    if (EnemiesCount8 > 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=generic
    local ShouldReturn = Generic(); if ShouldReturn then return ShouldReturn; end
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
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  --HR.Print("Protection Warrior rotation is currently a work in progress, but has been updated for patch 9.2.0.")
end

HR.SetAPL(73, APL, Init)

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
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Warrior.Protection
local I = Item.Warrior.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemies8y
local EnemiesCount8
local gcdTime

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

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function IsCurrentlyTanking()
  return Player:IsTankingAoE(16) or Player:IsTanking(Target)
end

local function IgnorePainWillNotCap()
  if Player:BuffUp(S.IgnorePain) then 
    local absorb = Player:AttackPowerDamageMod() * 3.5 * (1 + Player:VersatilityDmgPct() / 100)
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, IPAmount = Player:AuraInfo(S.IgnorePain, nil, true)
    return IPAmount < (0.5 * math.floor(absorb * 1.3))
  else
    return true
  end
end

local function ShouldPressShieldBlock()
  return IsCurrentlyTanking() and S.ShieldBlock:IsReady() and ((Player:BuffDown(S.ShieldBlockBuff) or Player:BuffRemains(S.ShieldBlockBuff) <= 1.5*gcdTime) and Player:BuffDown(S.LastStandBuff) and Player:Rage() >= 30)
end

-- A bit of logic to decide whether to pre-cast-rage-dump on ignore pain.
local function SuggestRageDump(rageFromSpell)
  -- pick a threshold where rage-from-damage-taken doesn't cap you even after the cast.
  -- This threshold is chosen somewhat arbitrarily. 
  -- TODO(mrdmnd) - make this config value in options.
  rageMax = 80
  shouldPreRageDump = false
  -- Make sure we have enough rage to even cast IP, and that it's not on CD.
  -- Make sure that we account for pressing shield block too - don't want to go too low on rage.
  if Player:Rage() >= 40 and S.IgnorePain:IsReady() and not ShouldPressShieldBlock() then
    -- should pre-dump rage into IP if rage + rageFromNextSpell >= rageMax
      shouldPreRageDump = (Player:Rage() + rageFromSpell >= rageMax) or shouldPreRageDump
  end
  -- Dump rage if we're sitting on demo shout for a while
  if Player:Rage() >= 40 and S.DemoralizingShout:IsReady() and not ShouldPressShieldBlock() then
    shouldPreRageDump = true
  end
  if shouldPreRageDump then
    if HR.CastRightSuggested(S.IgnorePain) then return "rage capped"; end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury precombat"; end
  end
  -- Manually added opener
  if Target:IsInMeleeRange(12) then
    if S.ThunderClap:IsCastable() then
      if HR.Cast(S.ThunderClap) then return "thunder_clap precombat"; end
    end
  else
    if S.Charge:IsCastable() then
      if HR.Cast(S.Charge, nil, nil, not Target:IsInRange(25)) then return "charge precombat"; end
    end
  end
end

local function Defensive()
  local PlayerHPPct = Player:HealthPercentage()
  if ShouldPressShieldBlock() then
    if HR.CastSuggested(S.ShieldBlock) then return "shield_block defensive" end
  end
  if S.LastStand:IsCastable() and (Player:BuffDown(S.ShieldBlockBuff) and S.ShieldBlock:Recharge() > 1) then
    if HR.CastSuggested(S.LastStand) then return "last_stand defensive" end
  end
  if S.VictoryRush:IsUsable() and S.VictoryRush:IsReady() and PlayerHPPct < 80 then
    if HR.Cast(S.VictoryRush) then return "victory_rush defensive" end
  end
  if S.ImpendingVictory:IsReady() and PlayerHPPct < 80 then
    if HR.Cast(S.ImpendingVictory) then return "impending_victory defensive" end
  end
end

local function Aoe()
  -- thunder_clap
  if (S.ThunderClap:IsCastable() or S.ThunderClap:CooldownRemains() < 0.150) then
    SuggestRageDump(5)
    if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap aoe 2"; end
  end
  -- demoralizing_shout,if=talent.booming_voice.enabled
  if S.DemoralizingShout:IsCastable() and (S.BoomingVoice:IsAvailable() and Player:RageDeficit() >= 40) then
    SuggestRageDump(40)
    if HR.Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout, nil, not Target:IsInMeleeRange(10)) then return "demoralizing_shout aoe 4"; end
  end
  -- dragon_roar
  if S.DragonRoar:IsCastable() and HR.CDsON() then
    if HR.Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar, nil, not Target:IsInMeleeRange(12)) then return "dragon_roar aoe 6"; end
  end
  -- revenge
  if S.Revenge:IsReady() and Player:BuffUp(S.RevengeBuff) then
    if HR.Cast(S.Revenge, nil, nil, not Target:IsInMeleeRange(5)) then return "revenge aoe 8"; end
  end
  -- revenge if you've got ignore pain up and you don't need to shield block soon
  if S.Revenge:IsCastable("Melee") and not ShouldPressShieldBlock() and Player:Rage() > 40 then 
    if HR.Cast(S.Revenge) then return "revenge aoe 10 (rage dump)"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    if HR.Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager aoe 12"; end
  end
  -- shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down
  if S.ShieldBlock:IsCastable() and (S.ShieldSlam:CooldownUp() and Player:BuffDown(S.ShieldBlockBuff)) then
    if HR.Cast(S.ShieldBlock, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_block aoe 14"; end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(15)
    if HR.Cast(S.ShieldSlam, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_slam aoe 16"; end
  end
end

local function St()
  -- thunder_clap,if=spell_targets.thunder_clap=2&talent.unstoppable_force.enabled&buff.avatar.up
  if (S.ThunderClap:IsCastable() or S.ThunderClap:CooldownRemains() < 0.150) and (EnemiesCount8 == 2 and S.UnstoppableForce:IsAvailable() and Player:BuffUp(S.AvatarBuff)) then
    SuggestRageDump(5)
    if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap st 32"; end
  end
  -- shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down
  if S.ShieldBlock:IsReady() and (S.ShieldSlam:CooldownUp() and Player:BuffDown(S.ShieldBlockBuff)) then
    if HR.Cast(S.ShieldBlock, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_block st 34"; end
  end
  -- shield_slam,if=buff.shield_block.up
  if S.ShieldSlam:IsCastable() and (Player:BuffUp(S.ShieldBlockBuff)) then
    SuggestRageDump(15)
    if HR.Cast(S.ShieldSlam, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_slam st 36"; end
  end
  -- thunder_clap,if=(talent.unstoppable_force.enabled&buff.avatar.up)
  if S.ThunderClap:IsCastable() and (S.UnstoppableForce:IsAvailable() and Player:BuffUp(S.AvatarBuff)) then
    SuggestRageDump(5)
    if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap st 38"; end
  end
  -- demoralizing_shout,if=talent.booming_voice.enabled
  if S.DemoralizingShout:IsCastable() and (S.BoomingVoice:IsAvailable() and Player:RageDeficit() >= 40) then
    SuggestRageDump(40)
    if HR.Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout, nil, not Target:IsInMeleeRange(10)) then return "demoralizing_shout st 40"; end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    if HR.Cast(S.ShieldSlam, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_slam st 42"; end
  end
  -- dragon_roar
  if S.DragonRoar:IsCastable() and CDsON() then
    if HR.Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar, nil, not Target:IsInMeleeRange(12)) then return "dragon_roar st 44"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap st 46"; end
  end
  -- revenge
  if S.Revenge:IsReady() and Player:BuffUp(S.RevengeBuff) then
    if HR.Cast(S.Revenge, nil, nil, not Target:IsInMeleeRange(5)) then return "revenge st 48"; end
  end
  -- revenge if you've got ignore pain up and you don't need to shield block soon
  if S.Revenge:IsCastable() and not ShouldPressShieldBlock() and Player:Rage() > 40 then
    if HR.Cast(S.Revenge, nil, nil, not Target:IsInMeleeRange(5)) then return "revenge st 50 (rage dump)"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    if HR.Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager st 52"; end
  end
  -- devastate
  if S.Devastate:IsCastable() then
    if HR.Cast(S.Devastate, nil, nil, not Target:IsInMeleeRange(5)) then return "devastate st 54"; end
  end
  -- storm_bolt
  if S.StormBolt:IsCastable() then
    if HR.Cast(S.StormBolt, nil, nil, not Target:IsSpellInRange(S.StormBolt)) then return "storm_bolt st 56"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  gcdTime = Player:GCD()
  
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    EnemiesCount8 = #Enemies8y
  else
    EnemiesCount8 = 1
  end

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
    if (HR.CDsON()) then
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- arcane_torrent
      if S.ArcaneTorrent:IsCastable() then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent racial"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastable() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment racial"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks racial"; end
      end
    end
    -- potion,if=buff.avatar.up|target.time_to_die<25
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 25) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury main 102"; end
    end
    -- ignore_pain,if=rage.deficit<25+20*talent.booming_voice.enabled*cooldown.demoralizing_shout.ready
    if S.IgnorePain:IsReady() and (Player:RageDeficit() < 25 + 20 * num(S.BoomingVoice:IsAvailable()) * num(S.DemoralizingShout:CooldownUp()) and IgnorePainWillNotCap() and IsCurrentlyTanking()) then
      if HR.CastRightSuggested(S.IgnorePain) then return "ignore_pain main 104"; end
    end
    -- avatar
    if S.Avatar:IsCastable() and HR.CDsON() and (Player:BuffDown(S.AvatarBuff)) then
    SuggestRageDump(20)
      if HR.Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "avatar main 106"; end
    end
    -- run_action_list,name=aoe,if=spell_targets.thunder_clap>=3
    if (EnemiesCount8 >= 3) then
      return Aoe();
    end
    -- call_action_list,name=st
    if (true) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(73, APL, Init)
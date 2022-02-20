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
  return IsCurrentlyTanking() and S.ShieldBlock:IsReady() and ((Player:BuffDown(S.ShieldBlockBuff) or Player:BuffRemains(S.ShieldBlockBuff) <= 1.5 * Player:GCD()) and Player:BuffDown(S.LastStandBuff) and Player:Rage() >= 30)
end

-- A bit of logic to decide whether to pre-cast-rage-dump on ignore pain.
local function SuggestRageDump(rageFromSpell)
  -- pick a threshold where rage-from-damage-taken doesn't cap you even after the cast.
  -- This threshold is chosen somewhat arbitrarily.
  -- TODO(mrdmnd) - make this config value in options.
  local rageMax = 80
  local shouldPreRageDump = false
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
    if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "rage capped"; end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added opener
  if Target:IsInMeleeRange(12) then
    if S.ThunderClap:IsCastable() then
      if Cast(S.ThunderClap) then return "thunder_clap precombat"; end
    end
  else
    if S.Charge:IsCastable() then
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
    if S.VictoryRush:IsCastable() and S.VictoryRush:IsUsable() then
      if Cast(S.VictoryRush) then return "victory_rush defensive" end
    end
    if S.ImpendingVictory:IsReady() and S.ImpendingVictory:IsUsable() then
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
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap aoe 6"; end
  end
  -- revenge
  -- Manually added: Only if you don't need to shield block soon
  if S.Revenge:IsReady() and not ShouldPressShieldBlock() then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge aoe 8"; end
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
    if Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager generic 2"; end
  end
  -- dragon_roar
  if S.DragonRoar:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar, nil, not Target:IsInMeleeRange(12)) then return "dragon_roar generic 4"; end
  end
  -- shield_slam,if=buff.shield_block.up
  if S.ShieldSlam:IsCastable() and (Player:BuffUp(S.ShieldBlockBuff)) then
    SuggestRageDump(15)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam generic 6"; end
  end
  -- thunder_clap,if=(spell_targets.thunder_clap>1|cooldown.shield_slam.remains)&talent.unstoppable_force.enabled&buff.avatar.up
  if S.ThunderClap:IsCastable() and ((EnemiesCount8 > 1 or not S.ShieldSlam:CooldownUp()) and S.UnstoppableForce:IsAvailable() and Player:BuffUp(S.AvatarBuff)) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap generic 8"; end
  end
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(15)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam generic 10"; end
  end
  -- condemn
  if S.Condemn:IsReady() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn generic 12"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute generic 14"; end
  end
  -- revenge,if=rage>80&target.health.pct>20|buff.revenge.up
  if S.Revenge:IsReady() and (Player:Rage() > 80 and Target:HealthPercentage() > 20 or Player:BuffUp(S.RevengeBuff)) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 16"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(12)) then return "thunder_clap generic 18"; end
  end
  -- revenge
  -- Manually added: Only if you don't need to shield block soon
  if S.Revenge:IsReady() and not ShouldPressShieldBlock() then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 20"; end
  end
  -- devastate
  if S.Devastate:IsCastable() then
    if Cast(S.Devastate, nil, nil, not TargetInMeleeRange) then return "devastate generic 22"; end
  end
  -- storm_bolt
  if S.StormBolt:IsCastable() then
    if Cast(S.StormBolt, nil, nil, not Target:IsSpellInRange(S.StormBolt)) then return "storm_bolt generic 24"; end
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
    -- heroic_charge,if=runeforge.reprisal
    if S.Charge:IsCastable() then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- use_items,if=cooldown.avatar.remains<=gcd|buff.avatar.up
    if (Settings.Commons.Enabled.Trinkets and (S.Avatar:CooldownRemains() <= Player:GCD() or Player:BuffUp(S.AvatarBuff))) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if (CDsON()) then
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- arcane_torrent
      if S.ArcaneTorrent:IsCastable() then
        if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent racial"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastable() then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment racial"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks racial"; end
      end
    end
    -- potion,if=buff.avatar.up|target.time_to_die<25
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 25) then
      if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
    end
    -- ignore_pain,if=target.health.pct>20&!covenant.venthyr,line_cd=15
    -- ignore_pain,if=target.health.pct>20&target.health.pct<80&covenant.venthyr,line_cd=15
    -- Handling ignore_pain via SuggestRageDump, so dropping the above two lines
    -- heroic_charge,if=rage<60&buff.revenge.down&runeforge.reprisal
    if S.Charge:IsCastable() and (Player:Rage() < 60 and Player:BuffDown(S.RevengeBuff) and ReprisalEquipped) then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge for reprisal"; end
    end
    -- conquerors_banner,if=runeforge.glory
    if S.ConquerorsBanner:IsCastable() and (GloryEquipped) then
      if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner main 6"; end
    end
    -- demoralizing_shout,if=talent.booming_voice.enabled
    if S.DemoralizingShout:IsCastable() and (S.BoomingVoice:IsAvailable()) then
      if S.BoomingVoice:IsAvailable() then
        SuggestRageDump(40)
      end
      if Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout, not Target:IsInRange(10)) then return "demoralizing_shout main 8"; end
    end
    if CDsON() then
      -- avatar
      if S.Avatar:IsCastable() and (Player:BuffDown(S.AvatarBuff)) then
        SuggestRageDump(20)
        if Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "avatar main 10"; end
      end
      -- ancient_aftershock
      if S.AncientAftershock:IsCastable() then
        if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "ancient_aftershock main 12"; end
      end
      -- spear_of_bastion
      if S.SpearofBastion:IsCastable() then
        if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion main 14"; end
      end
      -- conquerors_banner
      if S.ConquerorsBanner:IsCastable() then
        if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner main 16"; end
      end
    end
    -- shield_block,if=buff.shield_block.down
    -- Handled via Defensive()
    -- run_action_list,name=aoe,if=spell_targets.thunder_clap>=3
    if (EnemiesCount8 >= 3) then
      return Aoe();
    end
    -- call_action_list,name=generic
    local ShouldReturn = Generic(); if ShouldReturn then return ShouldReturn; end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Protection Warrior rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(73, APL, Init)

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
  CommonsDS = HR.GUISettings.APL.Warrior.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warrior.CommonsOGCD,
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
    local NewAbsorb = Player:AttackPowerDamageMod() * 4.375 * (1 + Player:VersatilityDmgPct() / 100)
    local IPBuffTable = Player:AuraInfo(S.IgnorePain, nil, true)
    local OldAbsorb = IPBuffTable.points[1]
    -- Ignore Pain appears to cap at 30% of player's max health
    -- https://github.com/simulationcraft/simc/blob/dragonflight/engine/class_modules/sc_warrior.cpp#L7789 as of Sept 21, 2023
    return Settings.Protection.AllowIPOvercap or OldAbsorb + NewAbsorb < Player:MaxHealth() * 0.3
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
  -- shield_block,if=buff.shield_block.duration<=10
  return IsCurrentlyTanking() and S.ShieldBlock:IsReady() and Player:BuffRemains(S.ShieldBlockBuff) <= 10
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
    if IsCurrentlyTanking() and IgnorePainWillNotCap() then
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
  if S.BattleShout:IsCastable() and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
    if Cast(S.BattleShout, Settings.CommonsOGCD.GCDasOffGCD.BattleShout) then return "battle_shout precombat"; end
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

local function Aoe()
  --thunder_clap,if=dot.rend.remains<=1
  if S.ThunderClap:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= 1) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap aoe 2"; end
  end
  -- shield_slam,if=(set_bonus.tier30_2pc|set_bonus.tier30_4pc)&spell_targets.thunder_clap<=7|buff.earthen_tenacity.up
  -- Note: If set_bonus.tier30_2pc is true, then tier30_4pc would be true also, so just checking for 2pc.
  if S.ShieldSlam:IsCastable() and (Player:HasTier(30, 2) and EnemiesCount8 <= 7 or Player:BuffUp(S.EarthenTenacityBuff)) then
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam aoe 4"; end
  end
  -- thunder_clap,if=buff.violent_outburst.up&spell_targets.thunderclap>6&buff.avatar.up&talent.unstoppable_force.enabled
  if S.ThunderClap:IsCastable() and (Player:BuffUp(S.ViolentOutburstBuff) and EnemiesCount8 > 6 and Player:BuffUp(S.AvatarBuff) and S.UnstoppableForce:IsAvailable()) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap aoe 6"; end
  end
  --revenge,if=rage>=70&talent.seismic_reverberation.enabled&spell_targets.revenge>=3
  if S.Revenge:IsReady() and (Player:Rage() >= 70 and S.SeismicReverberation:IsAvailable() and EnemiesCount8 >= 3) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge aoe 8"; end
  end
  --shield_slam,if=rage<=60|buff.violent_outburst.up&spell_targets.thunderclap<=7
  if S.ShieldSlam:IsCastable() and (Player:Rage() <= 60 or Player:BuffUp(S.ViolentOutburstBuff) and EnemiesCount8 <= 7) then
    SuggestRageDump(20)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam aoe 10"; end
  end
  --thunder_clap
  if S.ThunderClap:IsCastable() then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap aoe 12"; end
  end
  --revenge,if=rage>=30|rage>=40&talent.barbaric_training.enabled
  if S.Revenge:IsReady() and (Player:Rage() >= 30 or Player:Rage() >= 40 and S.BarbaricTraining:IsAvailable()) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge aoe 14"; end
  end
end

local function Generic()
  -- shield_slam
  if S.ShieldSlam:IsCastable() then
    SuggestRageDump(20)
    if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam generic 2"; end
  end
  -- thunder_clap,if=dot.rend.remains<=2&buff.violent_outburst.down
  if S.ThunderClap:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= 2 and Player:BuffDown(S.ViolentOutburstBuff)) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap generic 4"; end
  end
  -- execute,if=buff.sudden_death.up&talent.sudden_death.enabled
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff) and S.SuddenDeath:IsAvailable()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute generic 6"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute generic 8"; end
  end
  -- thunder_clap,if=(spell_targets.thunder_clap>1|cooldown.shield_slam.remains&!buff.violent_outburst.up)
  if S.ThunderClap:IsCastable() and (EnemiesCount8 > 1 or S.ShieldSlam:CooldownDown() and not Player:BuffUp(S.ViolentOutburstBuff)) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap generic 10"; end
  end
  --revenge,if=
  --(rage>=80&target.health.pct>20|buff.revenge.up&target.health.pct<=20&rage<=18&cooldown.shield_slam.remains|buff.revenge.up&target.health.pct>20)
  --|(rage>=80&target.health.pct>35|buff.revenge.up&target.health.pct<=35&rage<=18&cooldown.shield_slam.remains|buff.revenge.up&target.health.pct>35)
  --&talent.massacre.enabled
  if S.Revenge:IsReady() 
  and ((Player:Rage() >= 80 and Target:HealthPercentage() > 20 or Player:BuffUp(S.RevengeBuff) and Target:HealthPercentage() <= 20 and Player:Rage() <= 18 and S.ShieldSlam:CooldownDown() or Player:BuffUp(S.RevengeBuff) and Target:HealthPercentage() > 20) 
  or (Player:Rage() >= 80 and Target:HealthPercentage() > 35 or Player:BuffUp(S.RevengeBuff) and Target:HealthPercentage() <= 35 and Player:Rage() <= 18 and S.ShieldSlam:CooldownDown() or Player:BuffUp(S.RevengeBuff) and Target:HealthPercentage() > 35) 
  and S.Massacre:IsAvailable()) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 12"; end
  end
  -- execute,if=spell_targets.revenge=1
  if S.Execute:IsReady() and (EnemiesCount8 == 1) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute generic 14"; end
  end
  -- revenge,if=target.health>20
  if S.Revenge:IsReady() and (Target:HealthPercentage() > 20) then
    if Cast(S.Revenge, nil, nil, not TargetInMeleeRange) then return "revenge generic 16"; end
  end
  -- thunder_clap,if=(spell_targets.thunder_clap>=1|cooldown.shield_slam.remains&buff.violent_outburst.up)
  if S.ThunderClap:IsCastable() and (EnemiesCount8 >= 1 or S.ShieldSlam:CooldownDown() and Player:BuffUp(S.ViolentOutburstBuff)) then
    SuggestRageDump(5)
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap generic 18"; end
  end
  -- devastate
  if S.Devastate:IsCastable() then
    if Cast(S.Devastate, nil, nil, not TargetInMeleeRange) then return "devastate generic 20"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  if AoEON() then
    EnemiesCount8 = #Enemies8y
  else
    EnemiesCount8 = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Range check
    TargetInMeleeRange = Target:IsInMeleeRange(5)
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: battle_shout during combat
    if S.BattleShout:IsCastable() and Settings.Commons.ShoutDuringCombat and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
      if Cast(S.BattleShout, Settings.CommonsOGCD.GCDasOffGCD.BattleShout) then return "battle_shout precombat"; end
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
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(S.Pummel, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- charge,if=time=0
    -- Note: Handled in Precombat
    -- use_items
    if CDsON() and (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
    -- avatar
    if CDsON() and S.Avatar:IsCastable() then
      if Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "avatar main 2"; end
    end
    -- shield_wall,if=talent.immovable_object.enabled&buff.avatar.down
    if IsCurrentlyTanking() and S.ShieldWall:IsCastable() and (S.ImmovableObject:IsAvailable() and Player:BuffDown(S.AvatarBuff)) then
      if Cast(S.ShieldWall, nil, Settings.Protection.DisplayStyle.Defensive) then return "shield_wall main 4"; end
    end
    if CDsON() then
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 6"; end
      end
      -- berserking
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 8"; end
      end
      -- arcane_torrent
      if S.ArcaneTorrent:IsCastable() then
        if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent main 10"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastable() then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "lights_judgment main 12"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 14"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 16"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 18"; end
      end
    end
    -- potion,if=buff.avatar.up|buff.avatar.up&target.health.pct<=20
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvatarBuff) or Player:BuffDown(S.AvatarBuff) and Target:HealthPercentage() <= 20) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 20"; end
      end
    end
    -- ignore_pain,if=target.health.pct>=20&
    --(rage.deficit<=15&cooldown.shield_slam.ready
    --|rage.deficit<=40&cooldown.shield_charge.ready&talent.champions_bulwark.enabled
    --|rage.deficit<=20&cooldown.shield_charge.ready
    --|rage.deficit<=30&cooldown.demoralizing_shout.ready&talent.booming_voice.enabled
    --|rage.deficit<=20&cooldown.avatar.ready
    --|rage.deficit<=45&cooldown.demoralizing_shout.ready&talent.booming_voice.enabled&buff.last_stand.up&talent.unnerving_focus.enabled
    --|rage.deficit<=30&cooldown.avatar.ready&buff.last_stand.up&talent.unnerving_focus.enabled
    --|rage.deficit<=20
    --|rage.deficit<=40&cooldown.shield_slam.ready&buff.violent_outburst.up&talent.heavy_repercussions.enabled&talent.impenetrable_wall.enabled
    --|rage.deficit<=55&cooldown.shield_slam.ready&buff.violent_outburst.up&buff.last_stand.up&talent.unnerving_focus.enabled&talent.heavy_repercussions.enabled&talent.impenetrable_wall.enabled
    --|rage.deficit<=17&cooldown.shield_slam.ready&talent.heavy_repercussions.enabled
    --|rage.deficit<=18&cooldown.shield_slam.ready&talent.impenetrable_wall.enabled)
    --|(rage>=70
    --|buff.seeing_red.stack=7&rage>=35)&cooldown.shield_slam.remains<=1&buff.shield_block.remains>=4&set_bonus.tier31_2pc,use_off_gcd=1
    if S.IgnorePain:IsReady() and IgnorePainWillNotCap() and (Target:HealthPercentage() >= 20 and 
      (Player:RageDeficit() <= 15 and S.ShieldSlam:CooldownUp() 
      or Player:RageDeficit() <= 40 and S.ShieldCharge:CooldownUp() and S.ChampionsBulwark:IsAvailable() 
      or Player:RageDeficit() <= 20 and S.ShieldCharge:CooldownUp() 
      or Player:RageDeficit() <= 30 and S.DemoralizingShout:CooldownUp() and S.BoomingVoice:IsAvailable() 
      or Player:RageDeficit() <= 20 and S.Avatar:CooldownUp() 
      or Player:RageDeficit() <= 45 and S.DemoralizingShout:CooldownUp() and S.BoomingVoice:IsAvailable() and Player:BuffUp(S.LastStandBuff) and S.UnnervingFocus:IsAvailable() 
      or Player:RageDeficit() <= 30 and S.Avatar:CooldownUp() and Player:BuffUp(S.LastStandBuff) and S.UnnervingFocus:IsAvailable()
      or Player:RageDeficit() <= 20
      or Player:RageDeficit() <= 40 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.ViolentOutburstBuff) and S.HeavyRepercussions:IsAvailable() and S.ImpenetrableWall:IsAvailable() 
      or Player:RageDeficit() <= 55 and S.ShieldSlam:CooldownUp() and Player:BuffUp(S.ViolentOutburstBuff) and Player:BuffUp(S.LastStandBuff) and S.UnnervingFocus:IsAvailable() and S.HeavyRepercussions:IsAvailable() and S.ImpenetrableWall:IsAvailable()
      or Player:RageDeficit() <= 17 and S.ShieldSlam:CooldownUp() and S.HeavyRepercussions:IsAvailable()
      or Player:RageDeficit() <= 18 and S.ShieldSlam:CooldownUp() and S.ImpenetrableWall:IsAvailable())
      or (Player:Rage() >= 70
      or Player:BuffStack(S.SeeingRedBuff) == 7 and Player:Rage() >= 35) and S.ShieldSlam:CooldownRemains() <= 1 and Player:BuffRemains(S.ShieldBlockBuff) >= 4 and Player:HasTier(31, 2)) then
      if Cast(S.IgnorePain, nil, Settings.Protection.DisplayStyle.Defensive) then return "ignore_pain main 22"; end
    end
    -- last_stand,if=(target.health.pct>=90&talent.unnerving_focus.enabled|target.health.pct<=20&talent.unnerving_focus.enabled)|talent.bolster.enabled|set_bonus.tier30_2pc|set_bonus.tier30_4pc
    -- Note: If set_bonus.tier30_4pc is true, then tier30_2pc would be true as well, so just check for 2pc
    if IsCurrentlyTanking() and S.LastStand:IsCastable() and Player:BuffDown(S.ShieldWallBuff) and ((Target:HealthPercentage() >= 90 and S.UnnervingFocus:IsAvailable() or Target:HealthPercentage() <= 20 and S.UnnervingFocus:IsAvailable()) or S.Bolster:IsAvailable() or Player:HasTier(30, 2)) then
      if Cast(S.LastStand, nil, Settings.Protection.DisplayStyle.Defensive) then return "last_stand main 24"; end
    end
    -- ravager
    if CDsON() and S.Ravager:IsCastable() then
      SuggestRageDump(10)
      if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager main 26"; end
    end
    --demoralizing_shout,if=talent.booming_voice.enabled
    if S.DemoralizingShout:IsCastable() and (S.BoomingVoice:IsAvailable()) then
      SuggestRageDump(30)
      if Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout) then return "demoralizing_shout main 28"; end
    end
    -- champions_spear
    if CDsON() and S.ChampionsSpear:IsCastable() then
      SuggestRageDump(20)
      if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(25)) then return "champions_spear main 30"; end
    end
    -- thunderous_roar
    if CDsON() and S.ThunderousRoar:IsCastable() then
      if Cast(S.ThunderousRoar, Settings.Protection.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar main 32"; end
    end
    -- shield_slam,if=buff.fervid.up
    if S.ShieldSlam:IsReady() and (Player:BuffUp(S.FervidBuff)) then
      SuggestRageDump(18)
      if Cast(S.ShieldSlam, nil, nil, not TargetInMeleeRange) then return "shield_slam main 34"; end
    end
    -- shockwave,if=talent.sonic_boom.enabled&buff.avatar.up&talent.unstoppable_force.enabled&!talent.rumbling_earth.enabled|talent.sonic_boom.enabled&talent.rumbling_earth.enabled&spell_targets.shockwave>=3
    if S.Shockwave:IsCastable() and (S.SonicBoom:IsAvailable() and Player:BuffUp(S.AvatarBuff) and S.UnstoppableForce:IsAvailable() and not S.RumblingEarth:IsAvailable() or S.SonicBoom:IsAvailable() and S.RumblingEarth:IsAvailable() and EnemiesCount8 >= 3) then
      SuggestRageDump(10)
      if Cast(S.Shockwave, Settings.Protection.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave main 36"; end
    end
    -- shield_charge
    if S.ShieldCharge:IsCastable() then
      SuggestRageDump(40)
      if Cast(S.ShieldCharge, nil, nil, not Target:IsSpellInRange(S.ShieldCharge)) then return "shield_charge main 38"; end
    end
    -- shield_block,if=buff.shield_block.duration<=10
    if ShouldPressShieldBlock() then
      if Cast(S.ShieldBlock, nil, Settings.Protection.DisplayStyle.Defensive) then return "shield_block main 40"; end
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
  HR.Print("Protection Warrior rotation has been updated for patch 10.2.7.")
end

HR.SetAPL(73, APL, Init)

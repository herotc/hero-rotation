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

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Protection
local I = Item.Warrior.Protection
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemies8y
local EnemiesCount8y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Protection = HR.GUISettings.APL.Warrior.Protection
}

-- Interrupts List
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function IsCurrentlyTanking()
  return Player:IsTankingAoE(16) or Player:IsTanking(Target);
end


local function IgnorePainWillNotCap()
  if Player:BuffUp(S.IgnorePain) then
    local absorb = tonumber((GetSpellDescription(190456):match("%d+%S+%d"):gsub("%D","")))
    return Player:BuffUp(S.IgnorePain, 16, true) < (0.5 * math.floor(absorb * 1.3))
  else
    return true
  end
end

local function ShouldPressShieldBlock()
  return IsCurrentlyTanking() and S.ShieldBlock:IsReady() and ((Player:BuffDown(S.ShieldBlockBuff) or Player:BuffRefreshable(S.ShieldBlockBuff)) and Player:BuffDown(S.LastStandBuff) and Player:Rage() >= 30)
end

local function Defensive()
  if ShouldPressShieldBlock() then
    if HR.CastSuggested(S.ShieldBlock) then return "shield_block defensive" end
  end
  if S.LastStand:IsCastable() and (Player:BuffDown(S.ShieldBlockBuff) and S.ShieldBlock:ChargesFractional() > 1.0 ) then
    if HR.CastSuggested(S.LastStand) then return "last_stand defensive" end
  end
  if Player:HealthPercentage() < 80 and S.VictoryRush:IsReady() then
    if HR.Cast(S.VictoryRush, nil, nil, not Target:IsSpellInRange(S.VictoryRush)) then return "victory_rush defensive" end
  end
  if Player:HealthPercentage() < 80 and S.ImpendingVictory:IsReady() then
    if HR.Cast(S.ImpendingVictory, nil, nil, not Target:IsSpellInRange(S.ImpendingVictory)) then return "impending_victory defensive" end
  end
  if Player:HealthPercentage() <= 70 and I.LingeringPsychicShell:IsEquipReady() then
    if HR.CastRightSuggested(I.LingeringPsychicShell) then return "absorb trinket defensive" end
  end
end

local function AOE()
  --actions.aoe=thunder_clap
  if S.ThunderClap:IsCastable() then
        if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInRange(8)) then return "thunder_clap"; end
  end
  --actions.aoe+=/demoralizing_shout,if=talent.booming_voice.enabled
  if S.DemoralizingShout:IsCastable() and S.BoomingVoice:IsAvailable() then
        if HR.Cast(S.DemoralizingShout) then return "demoralizing_shout"; end
  end
  --actions.aoe+=/shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down&buff.memory_of_lucid_dreams.up
  if S.ShieldBlock:IsCastable() and S.ShieldSlam:CooldownUp() and Player:BuffDown(S.ShieldBlockBuff) and Player:BuffUp(S.MemoryofLucidDreamsBuff) and Player:Rage() > 29 then
        if HR.CastSuggest(S.ShieldBlock) then return "shield_block"; end
  end
  --actions.aoe+=/shield_slam,if=buff.memory_of_lucid_dreams.up
  if S.ShieldSlam:IsCastable() and Player:BuffUp(S.MemoryofLucidDreamsBuff) then
    if HR.Cast(S.ShieldSlam) then return "shield_slam"; end
  end
  --actions.aoe+=/dragon_roar
  if S.DragonRoar:IsCastable() then
        if HR.Cast(S.DragonRoar, nil, nil, not Target:IsInRange(8)) then return "dragon_roar"; end
  end
  --actions.aoe+=/revenge
  --actions.aoe+=/
  if S.Revenge:IsReady() and Player:Rage() > 19 then
        if HR.Cast(S.Revenge, nil, nil, not Target:IsSpellInRange(S.Revenge)) then return "revenge"; end
  end
  --actions.aoe+=/use_item,name=grongs_primal_rage,if=buff.avatar.down|cooldown.thunder_clap.remains>=4
  --actions.aoe+=/ravager
  if S.Ravager:IsCastable() then
        if HR.Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager"; end
  end
  --actions.aoe+=/shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down
  if S.ShieldBlock:IsCastable() and S.ShieldSlam:CooldownUp() and Player:BuffDown(S.ShieldBlockBuff) and Player:Rage() > 29 then
        if HR.CastSuggest(S.ShieldBlock) then return "shield_block"; end
  end
  --actions.aoe+=/shield_slam
  if S.ShieldSlam:IsCastable() then
        if HR.Cast(S.ShieldSlam, nil, nil, not Target:IsSpellInRange(S.ShieldSlam)) then return "shield_slam"; end
  end
end

local function SingleTarget()
  --actions.st=thunder_clap,if=spell_targets.thunder_clap=2&talent.unstoppable_force.enabled&buff.avatar.up
  if S.ThunderClap:IsCastable() and (EnemiesCount8y >= 2 and S.UnstoppableForce:IsAvailable() and Player:BuffUp(S.Avatar)) then
      if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInRange(8)) then return "thunder_clap"; end
  end
  --actions.st+=/shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down
  if S.ShieldBlock:IsCastable() and S.ShieldSlam:CooldownUp() and Player:BuffDown(S.ShieldBlockBuff) and Player:Rage() > 29 then
        if HR.CastSuggested(S.ShieldBlock) then return "shield_block"; end
  end
  --actions.st+=/shield_slam
  if S.ShieldSlam:IsCastable() then
        if HR.Cast(S.ShieldSlam, nil, nil, not Target:IsSpellInRange(S.ShieldSlam)) then return "shield_slam"; end
  end
  --actions.st+=/thunder_clap,if=(talent.unstoppable_force.enabled&buff.avatar.up)
  if S.ThunderClap:IsCastable() and (S.UnstoppableForce:IsAvailable() and Player:BuffUp(S.Avatar))then
        if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInRange(8)) then return "thunder_clap"; end
  end
  --actions.st+=/demoralizing_shout,if=talent.booming_voice.enabled
  if S.DemoralizingShout:IsCastable() and S.BoomingVoice:IsAvailable() then
        if HR.Cast(S.DemoralizingShout) then return "demoralizing_shout"; end
  end
  --actions.st+=/use_item,name=ashvanes_razor_coral,target_if=debuff.razor_coral_debuff.stack=0
  --actions.st+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.stack>7&(cooldown.avatar.remains<5|buff.avatar.up)
  --actions.st+=/dragon_roar
  if S.DragonRoar:IsCastable() then
        if HR.Cast(S.DragonRoar, nil, nil, not Target:IsInRange(8)) then return "dragon_roar"; end
  end
  --actions.st+=/thunder_clap
  if S.ThunderClap:IsCastable() then
        if HR.Cast(S.ThunderClap, nil, nil, not Target:IsInRange(8)) then return "thunder_clap"; end
  end
  --actions.st+=/revenge
  if S.Execute:IsCastable() and Player:Rage() > 19 then
        if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
  if S.Revenge:IsReady() and Player:Rage() > 19 then
        if HR.Cast(S.Revenge, nil, nil, not Target:IsSpellInRange(S.Revenge)) then return "revenge"; end
  end
  --actions.st+=/use_item,name=grongs_primal_rage,if=buff.avatar.down|cooldown.shield_slam.remains>=4
  --actions.st+=/ravager
  if S.Ravager:IsCastable() then
        if HR.Cast(S.Ravager, nil, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager"; end
  end
  --actions.st+=/devastate
  if S.Devastate:IsCastable() then
        if HR.Cast(S.Devastate, nil, nil, not Target:IsSpellInRange(S.Devastate)) then return "devastate"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCount8y = 1
  end

  local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end

  if IsCurrentlyTanking() then
    local ShouldReturn = Defensive(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then

    if IsCurrentlyTanking() then
      local ShouldReturn = Defensive(); if ShouldReturn then return ShouldReturn; end
    end

    if S.Intercept:IsCastable(25) and (not Target:IsInRange(8)) then
      if HR.Cast(S.Intercept) then return "intercept"; end
    end
    if (HR.CDsON()) then
     --actions+=/blood_fury
     --actions+=/berserking
     --actions+=/arcane_torrent
     --actions+=/lights_judgment
     --actions+=/fireblood
     --actions+=/ancestral_call
     if S.AncestralCall:IsCastable() then
       if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
     end
     --actions+=/bag_of_tricks
    end

    --if S.IgnorePain:IsReady() and (Player:RageDeficit() < 25 + 20 * num(S.BoomingVoice:IsAvailable()) * num(S.DemoralizingShout:CooldownUp()) and IgnorePainWillNotCap() and IsCurrentlyTanking()) then
      --if HR.CastRightSuggested(S.IgnorePain) then return "ignore_pain"; end
    --end

    if S.MemoryofLucidDreams:IsCastable() and (S.Avatar:CooldownRemains() <= Player:GCD() and Player:BuffDown(S.AvatarBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end

    if S.HeartEssence ~= nil and not PassiveEssence and S.HeartEssence:IsCastable() and (not S.TheCrucibleofFlame:IsAvailable() or S.WorldveinResonance:IsAvailable() or S.AnimaofLifeandDeath:IsAvailable() or S.MemoryofLucidDreams:IsAvailable()) then
      if HR.Cast(S.HeartEssence, nil, Settings.Commons.EssenceDisplayStyle) then return "heart_essence"; end
    end

    if S.Avatar:IsCastable() and HR.CDsON() and (Player:BuffDown(S.AvatarBuff)) then
      if HR.Cast(S.Avatar, Settings.Protection.OffGCDasOffGCD.Avatar) then return "avatar"; end
    end

    if (EnemiesCount8y >= 3) then
      local ShouldReturn = AOE(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(73, APL, Init)

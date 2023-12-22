--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- Lua

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Monk.Mistweaver
local I = Item.Monk.Mistweaver

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.TrinketName:ID(),
}

-- Rotation Var
local Enemies5y
local Enemies8y
local EnemiesCount8
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
  { S.Paralysis, "Cast Paralysis (Stun)", function () return true end },
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Monk = HR.Commons.Monk
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Mistweaver = HR.GUISettings.APL.Monk.Mistweaver
}

local function UseItems()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Defensives()
  -- Dampen Harm
  if S.DampenHarm:IsCastable() and Player:BuffDown(S.FortifyingBrew) and Player:HealthPercentage() <= Settings.Mistweaver.DampenHarmHP then
    if Cast(S.DampenHarm, nil, Settings.Mistweaver.DisplayStyle.DampenHarm) then return "dampen_harm defensives 2"; end
  end
  -- Fortifying Brew
  if S.FortifyingBrew:IsCastable() and Player:BuffDown(S.DampenHarm) and Player:HealthPercentage() <= Settings.Mistweaver.FortifyingBrewHP then
    if Cast(S.FortifyingBrew, Settings.Mistweaver.DisplayStyle.FortifyingBrew) then return "fortifying_brew defensives 4"; end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- Note: Removing this as it's no longer necessary to do in Precombat
  -- fleshcraft
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 2"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat 4"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave precombat 6"; end
  end
end

local function AOE()
  -- spinning_crane_kick
  if S.SpinningCraneKick:IsCastable() then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick aoe 2"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave aoe 4"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst aoe 6"; end
  end
end

local function ST()
  -- thunder_focus_tea
  if S.ThunderFocusTea:IsCastable() then
    if Cast(S.ThunderFocusTea, Settings.Mistweaver.OffGCDasOffGCD.ThunderFocusTea) then return "thunder_focus_tea st 2"; end
  end
  -- rising_sun_kick
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick st 4"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.stack=1&cooldown.rising_sun_kick.remains<12
  if S.BlackoutKick:IsCastable() and (Player:BuffStack(S.TeachingsOfTheMonasteryBuff) == 1 and S.RisingSunKick:CooldownRemains() < 12) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick st 6"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave st 8"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst st 10"; end
  end
  -- tiger_palm,if=buff.teachings_of_the_monastery.stack<3|buff.teachings_of_the_monastery.remains<2
  if S.TigerPalm:IsCastable() and (Player:BuffStack(S.TeachingsOfTheMonasteryBuff) < 3 or Player:BuffRemains(S.TeachingsOfTheMonasteryBuff) < 2) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm st 12"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  if AoEON() then
    EnemiesCount8 = #Enemies8y -- AOE Toogle
  else
    EnemiesCount8 = 1
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.LegSweep, Settings.Commons.GCDasOffGCD.LegSweep, Stuns); if ShouldReturn and Settings.General.InterruptWithStun then return ShouldReturn; end
    -- Defensives
    local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    -- use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up&time>1
    --[[if I.ScarsofFraternalStrife:IsEquippedAndReady() and Settings.Commons.Enabled.Trinkets and (Player:BuffDown(S.ScarsofFraternalStrifeBuff4) and HL.CombatTime() > 1) then
      if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife main 1"; end
    end
    -- use_item,name=jotungeirr_destinys_call
    if I.Jotungeirr:IsEquippedAndReady() then
      if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call main 2"; end
    end]]
    -- use_items
    if Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
    if CDsON() and Target:TimeToDie() < 18 then
      -- blood_fury,if=target.time_to_die<18
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 4"; end
      end
      -- berserking,if=target.time_to_die<18
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
      end
      -- lights_judgment,if=target.time_to_die<18
      if S.LightsJudgment:IsCastable() then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, not Target:IsInRange(40)) then return "lights_judgment main 8"; end
      end
      -- fireblood,if=target.time_to_die<18
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 10"; end
      end
      -- ancestral_call,if=target.time_to_die<18
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 12"; end
      end
      -- bag_of_tricks,if=target.time_to_die<18
      if S.BagOfTricks:IsCastable() then
        if Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, not Target:IsInRange(40)) then return "bag_of_tricks main 14"; end
      end
    end
    -- potion
    --[[if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 16"; end
    end]]
    -- weapons_of_order
    if S.WeaponsOfOrder:IsCastable() and CDsON() then
      if Cast(S.WeaponsOfOrder, nil, Settings.Commons.DisplayStyle.Covenant) then return "weapons_of_order main 18"; end
    end
    -- faeline_stomp
    if S.FaelineStomp:IsCastable() then
      if Cast(S.FaelineStomp, nil, Settings.Commons.DisplayStyle.Covenant) then return "faeline_stomp main 20"; end
    end
    if CDsON() then
      -- fallen_order
      if S.FallenOrder:IsCastable() then
        if Cast(S.FallenOrder, nil, Settings.Commons.DisplayStyle.Covenant) then return "fallen_order main 22"; end
      end
      -- bonedust_brew
      if S.BonedustBrew:IsCastable() then
        if Cast(S.BonedustBrew, nil, Settings.Commons.DisplayStyle.Covenant) then return "bonedust_brew main 24"; end
      end
    end
    -- fleshcraft,if=soulbind.lead_by_example.enabled
    if S.Fleshcraft:IsCastable() and (S.LeadByExample:SoulbindEnabled()) then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft main 26"; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if (EnemiesCount8 >= 3) then
      local ShouldReturn = AOE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemiesCount8 < 3) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added Pool filler
    if Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
  HR.Print("Mistweaver Monk rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(270, APL, Init)

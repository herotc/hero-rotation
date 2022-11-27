--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastSuggested = HR.CastSuggested
-- lua
local mathmax       = math.max
local mathmin       = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Vengeance
local I = Item.DemonHunter.Vengeance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.TrinketName:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
}

-- Rotation Var
local SoulFragments, SoulFragmentsAdjusted, LastSoulFragmentAdjustment
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarBrandBuild = (S.AgonizingFlames:IsAvailable() and S.BurningAlive:IsAvailable() and S.CharredFlesh:IsAvailable())

HL:RegisterForEvent(function()
  VarBrandBuild = (S.AgonizingFlames:IsAvailable() and S.BurningAlive:IsAvailable() and S.CharredFlesh:IsAvailable())
end, "PLAYER_TALENT_UPDATE")

-- Soul Fragments function taking into consideration aura lag
local function UpdateSoulFragments()
  SoulFragments = Player:BuffStack(S.SoulFragments)

  -- Casting Spirit Bomb or Soul Cleave immediately updates the buff
  if S.SpiritBomb:TimeSinceLastCast() < Player:GCD()
  or S.SoulCleave:TimeSinceLastCast() < Player:GCD() then
    SoulFragmentsAdjusted = 0
    return
  end

  -- Check if we have cast Fracture or Shear within the last GCD and haven't "snapshot" yet
  if SoulFragmentsAdjusted == 0 then
    if S.Fracture:IsAvailable() then
      if S.Fracture:TimeSinceLastCast() < Player:GCD() and S.Fracture.LastCastTime ~= LastSoulFragmentAdjustment then
        SoulFragmentsAdjusted = math.min(SoulFragments + 2, 5)
        LastSoulFragmentAdjustment = S.Fracture.LastCastTime
      end
    else
      if S.Shear:TimeSinceLastCast() < Player:GCD() and S.Fracture.Shear ~= LastSoulFragmentAdjustment then
        SoulFragmentsAdjusted = math.min(SoulFragments + 1, 5)
        LastSoulFragmentAdjustment = S.Shear.LastCastTime
      end
    end
  else
    -- If we have a soul fragement "snapshot", see if we should invalidate it based on time
    if S.Fracture:IsAvailable() then
      if S.Fracture:TimeSinceLastCast() >= Player:GCD() then
        SoulFragmentsAdjusted = 0
      end
    else
      if S.Shear:TimeSinceLastCast() >= Player:GCD() then
        SoulFragmentsAdjusted = 0
      end
    end
  end

  -- If we have a higher Soul Fragment "snapshot", use it instead
  if SoulFragmentsAdjusted == nil then SoulFragmentsAdjusted = 0 end
  if SoulFragmentsAdjusted > SoulFragments then
    SoulFragments = SoulFragmentsAdjusted
  elseif SoulFragmentsAdjusted > 0 then
    -- Otherwise, the "snapshot" is invalid, so reset it if it has a value
    -- Relevant in cases where we use a generator two GCDs in a row
    SoulFragmentsAdjusted = 0
  end
end

-- Melee Is In Range w/ Movement Handlers
local function UpdateIsInMeleeRange()
  if S.Felblade:TimeSinceLastCast() < Player:GCD()
  or S.InfernalStrike:TimeSinceLastCast() < Player:GCD() then
    IsInMeleeRange = true
    IsInAoERange = true
    return
  end

  IsInMeleeRange = Target:IsInMeleeRange(5)
  IsInAoERange = IsInMeleeRange or EnemiesCount8yMelee > 0
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- First attacks
  if S.TheHunt:IsCastable() and not IsInMeleeRange then
    if Cast(S.TheHunt, nil, nil, not Target:IsInRange(50)) then return "the_hunt precombat 4"; end
  end
  if S.InfernalStrike:IsCastable() and not IsInMeleeRange then
    if Cast(S.InfernalStrike, nil, nil, not Target:IsInRange(30)) then return "infernal_strike precombat 6"; end
  end
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then return "fracture precombat 8"; end
  end
  if S.Shear:IsCastable() and IsInMeleeRange then
    if Cast(S.Shear) then return "shear precombat 10"; end
  end
end

local function Defensives()
  -- Demon Spikes
  if S.DemonSpikes:IsCastable() and Player:BuffDown(S.DemonSpikesBuff) and Player:BuffDown(S.MetamorphosisBuff) and (EnemiesCount8yMelee == 1 and Player:BuffDown(S.FieryBrandDebuff) or EnemiesCount8yMelee > 1) then
    if S.DemonSpikes:ChargesFractional() > 1.9 then
      if Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "demon_spikes defensives (Capped)"; end
    elseif (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
      if Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "demon_spikes defensives (Danger)"; end
    end
  end
  -- Metamorphosis,if=!buff.metamorphosis.up|target.time_to_die<15
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and (Player:BuffDown(S.MetamorphosisBuff) or Target:TimeToDie() < 15) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and Target:DebuffDown(S.FieryBrandDebuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
end

local function Brand()
  -- fiery_brand
  if S.FieryBrand:IsCastable() and IsInMeleeRange then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand brand 2"; end
  end
  -- immolation_aura,if=dot.fiery_brand.ticking
  if S.ImmolationAura:IsCastable() and IsInMeleeRange and (Target:DebuffUp(S.FieryBrandDebuff)) then
    if Cast(S.ImmolationAura) then return "immolation_aura brand 4"; end
  end
end

local function Cooldowns()
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 2"; end
    end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt cooldowns 8"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature) then return "elysian_decree cooldowns 10"; end
  end
end

local function Normal()
  -- infernal_strike
  if S.InfernalStrike:IsCastable() and ((not Settings.Vengeance.ConserveInfernalStrike) or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike normal 2"; end
  end
  -- bulk_extraction
  -- Note: Added overcap safety
  if S.BulkExtraction:IsCastable() and (SoulFragments <= 5 - mathmin(5, EnemiesCount8yMelee)) then
    if Cast(S.BulkExtraction) then return "bulk_extraction normal 4"; end
  end
  -- spirit_bomb,if=((buff.metamorphosis.up&talent.fracture.enabled&soul_fragments>=3)|soul_fragments>=4)
  if S.SpiritBomb:IsReady() and IsInAoERange and ((Player:BuffUp(S.Metamorphosis) and S.Fracture:IsAvailable() and SoulFragments >= 3) or SoulFragments >= 4) then
    if Cast(S.SpiritBomb) then return "spirit_bomb normal 8"; end
  end
  -- fel_devastation
  -- Manual add: ,if=talent.demonic.enabled&!buff.metamorphosis.up|!talent.demonic.enabled
  -- This way we don't waste potential Meta uptime
  if S.FelDevastation:IsReady() and (S.Demonic:IsAvailable() and Player:BuffDown(S.Metamorphosis) or not S.Demonic:IsAvailable()) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation normal 10"; end
  end
  -- soul_cleave,if=((talent.spirit_bomb&soul_fragments=0)|!talent.spirit_bomb)&((talent.fracture&fury>=55)|(!talent.fracture&fury>=70)|cooldown.fel_devastation.remains>target.time_to_die|(buff.metamorphosis.up&((talent.fracture&fury>=35)|(!talent.fracture&fury>=50))))
  if S.SoulCleave:IsReady() and (((S.SpiritBomb:IsAvailable() and SoulFragments == 0) or not S.SpiritBomb:IsAvailable()) and ((S.Fracture:IsAvailable() and Player:Fury() >= 55) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 70) or S.FelDevastation:CooldownRemains() > Target:TimeToDie() or (Player:BuffUp(S.MetamorphosisBuff) and ((S.Fracture:IsAvailable() and Player:Fury() >= 35) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 50))))) then
    if Cast(S.SoulCleave, nil, nil, not Target:IsSpellInRange(S.SoulCleave)) then return "soul_cleave normal 14"; end
  end
  -- immolation_aura,if=((variable.brand_build&cooldown.fiery_brand.remains>10)|!variable.brand_build)&(fury<=90&!talent.fallout|talent.fallout&soul_fragments<=4)
  -- Manually added: Don't cast if we'll cap SoulFragments with Fallout (we have a 60-70% chance to get a fragment per target)
  if S.ImmolationAura:IsCastable() and (((VarBrandBuild and S.FieryBrand:CooldownRemains() > 10) or not VarBrandBuild) and (Player:Fury() <= 90 and (not S.Fallout:IsAvailable()) or S.Fallout:IsAvailable() and SoulFragments <= 5 - mathmin(5, EnemiesCount8yMelee * 0.6))) then
    if Cast(S.ImmolationAura) then return "immolation_aura normal 20"; end
  end
  -- felblade,if=fury<=60
  if S.Felblade:IsCastable() and (Player:Fury() <= 60) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade normal 22"; end
  end
  -- fracture,if=((talent.spirit_bomb.enabled&soul_fragments<=3)|(!talent.spirit_bomb.enabled&((buff.metamorphosis.up&fury<=55)|(buff.metamorphosis.down&fury<=70))))
  if S.Fracture:IsCastable() and IsInMeleeRange and ((S.SpiritBomb:IsAvailable() and SoulFragments <= 3) or ((not S.SpiritBomb:IsAvailable()) and ((Player:BuffUp(S.MetamorphosisBuff) and Player:Fury() <= 55) or (Player:BuffDown(S.MetamorphosisBuff) and Player:Fury() <= 70)))) then
    if Cast(S.Fracture) then return "fracture normal 18"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() and (IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRemains(S.SigilofFlameDebuff) <= 3 then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame normal 24 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame normal 24 (Normal)"; end
    end
  end
  -- shear
  if S.Shear:IsReady() and IsInMeleeRange then
    if Cast(S.Shear) then return "shear normal 26"; end
  end
  -- Manually added: fracture as a fallback filler
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then return "fracture normal 28"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive normal 30 (OOR)"; end
  end
end

-- APL Main
local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8)
  if (AoEON()) then
    EnemiesCount8yMelee = #Enemies8yMelee
  else
    EnemiesCount8yMelee = 1
  end

  UpdateSoulFragments()
  UpdateIsInMeleeRange()

  ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- variable,name=brand_build,value=talent.agonizing_flames&talent.burning_alive&talent.charred_flesh
    -- Moved to declarations and PLAYER_TALENT_UPDATE registration, as talents can't change once in combat, so no need to continually check
    -- disrupt (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- consume_magic
    -- Manually added: soul_carver,if=soul_fragments<3
    if S.SoulCarver:IsReady() and (SoulFragments < 3) then
      if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver main 4"; end
    end
    -- call_action_list,name=brand,if=variable.brand_build
    if VarBrandBuild or Settings.Vengeance.UseFieryBrandOffensively then
      local ShouldReturn = Brand(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=defensives
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=normal
    local ShouldReturn = Normal(); if ShouldReturn then return ShouldReturn; end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Vengeance DH rotation is currently a work in progress. It has been updated to work with patch 10.0, but is not currently based on an updated Simulationcraft APL, so it very well may not be optimal.")
end

HR.SetAPL(581, APL, Init);

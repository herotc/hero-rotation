--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
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
local CastAnnotated = HR.CastAnnotated
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- File locals
local DemonHunter   = HR.Commons.DemonHunter
DemonHunter.DGBCDR  = 0
DemonHunter.DGBCDRLastUpdate = 0
-- lua
local GetTime       = GetTime
local mathmin       = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Vengeance
local I = Item.DemonHunter.Vengeance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
}

-- Rotation Var
local SoulFragments, LastSoulFragmentAdjustment
local SoulFragmentsAdjusted = 0
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarCDTime, VarFD, VarFrailtyReady, VarNextFireCDTime
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- Soul Fragments function taking into consideration aura lag
local function UpdateSoulFragments()
  SoulFragments = Player:BuffStack(S.SoulFragments)

  -- Casting Spirit Bomb immediately updates the buff
  -- May no longer be needed, as Spirit Bomb instantly removes the buff now
  if S.SpiritBomb:TimeSinceLastCast() < Player:GCD() then
    SoulFragmentsAdjusted = 0
  end

  -- Check if we have cast Soul Carver, Fracture, or Shear within the last GCD and haven't "snapshot" yet
  if SoulFragmentsAdjusted == 0 then
    local MetaMod = (Player:BuffUp(S.MetamorphosisBuff)) and 1 or 0
    if S.SoulCarver:IsAvailable() and S.SoulCarver:TimeSinceLastCast() < Player:GCD() and S.SoulCarver.LastCastTime ~= LastSoulFragmentAdjustment then
      SoulFragmentsAdjusted = math.min(SoulFragments + 2, 5)
      LastSoulFragmentAdjustment = S.SoulCarver.LastCastTime
    elseif S.Fracture:IsAvailable() and S.Fracture:TimeSinceLastCast() < Player:GCD() and S.Fracture.LastCastTime ~= LastSoulFragmentAdjustment then
      SoulFragmentsAdjusted = math.min(SoulFragments + 2 + MetaMod, 5)
      LastSoulFragmentAdjustment = S.Fracture.LastCastTime
    elseif S.Shear:TimeSinceLastCast() < Player:GCD() and S.Fracture.Shear ~= LastSoulFragmentAdjustment then
      SoulFragmentsAdjusted = math.min(SoulFragments + 1 + MetaMod, 5)
      LastSoulFragmentAdjustment = S.Shear.LastCastTime
    end
  else
    -- If we have a soul fragement "snapshot", see if we should invalidate it based on time
    local Prev = Player:PrevGCD(1)
    if Prev == 207407 and S.SoulCarver:TimeSinceLastCast() >= Player:GCD() then
      SoulFragmentsAdjusted = 0
    elseif Prev == 263642 and S.Fracture:TimeSinceLastCast() >= Player:GCD() then
      SoulFragmentsAdjusted = 0
    elseif Prev == 203782 and S.Shear:TimeSinceLastCast() >= Player:GCD() then
      SoulFragmentsAdjusted = 0
    end
  end

  -- If we have a higher Soul Fragment "snapshot", use it instead
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

-- CastTargetIf/CastCycle functions
local function EvaluateTargetIfFilterFBRemains(TargetUnit)
  -- target_if=max:dot.fiery_brand.remains
  return (TargetUnit:DebuffRemains(S.FieryBrandDebuff))
end

local function EvaluateTargetIfFractureMaintenance(TargetUnit)
  -- if=dot.fiery_brand.ticking&buff.recrimination.up
  -- Note: RecriminationBuff check is done before CastTargetIf
  return (TargetUnit:DebuffUp(S.FieryBrandDebuff))
end

-- Base rotation functions
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- sigil_of_flame
  if (not S.ConcentratedSigils:IsAvailable()) and S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame precombat 2"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura precombat 4"; end
  end
  -- Manually added: First attacks
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
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.Defensives) then return "demon_spikes defensives (Capped)"; end
    elseif (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.Defensives) then return "demon_spikes defensives (Danger)"; end
    end
  end
  -- Metamorphosis,if=!buff.metamorphosis.up|target.time_to_die<15
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and (Player:BuffDown(S.MetamorphosisBuff) or Target:TimeToDie() < 15) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.Defensives, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
end

local function Filler()
  -- bulk_extraction
  if S.BulkExtraction:IsCastable() then
    if Cast(S.BulkExtraction, nil, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction filler 2"; end
  end
  -- soul_cleave
  if S.SoulCleave:IsReady() then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave filler 4"; end
  end
  -- spirit_bomb
  if S.SpiritBomb:IsReady() then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb filler 6"; end
  end
  -- felblade
  if S.Felblade:IsReady() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade filler 8"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture filler 10"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear filler 12"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive filler 14"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=elementium_pocket_anvil,use_off_gcd=1
    if I.ElementiumPocketAnvil:IsEquippedAndReady() then
      if Cast(I.ElementiumPocketAnvil, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(8)) then return "elementium_pocket_anvil trinkets 2"; end
    end
    -- use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1
    if I.DragonfireBombDispenser:IsEquippedAndReady() then
      if Cast(I.DragonfireBombDispenser, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser trinkets 4"; end
    end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

local function Maintenance()
  -- call_action_list,name=trinkets
  local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion maintenance 2"; end
    end
  end
  -- metamorphosis,if=talent.first_of_the_illidari
  if S.Metamorphosis:IsCastable() and (S.FirstoftheIllidari:IsAvailable()) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis maintenance 4"; end
  end
  -- fiery_brand,if=charges>=2|(!ticking&((variable.next_fire_cd_time<7)|(variable.next_fire_cd_time>28)))
  if S.FieryBrand:IsCastable() and (S.FieryBrand:Charges() >= 2 or (Target:DebuffDown(S.FieryBrandDebuff) and (VarNextFireCDTime < 7 or VarNextFireCDTime > 28))) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand maintenance 6"; end
  end
  -- spirit_bomb,if=soul_fragments>=5
  if S.SpiritBomb:IsReady() and (SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb maintenance 8"; end
  end
  -- fracture,target_if=max:dot.fiery_brand.remains,if=dot.fiery_brand.ticking&buff.recrimination.up
  if S.Fracture:IsCastable() and (Player:BuffUp(S.RecriminationBuff)) then
    if Everyone.CastTargetIf(S.Fracture, Enemies8yMelee, "max", EvaluateTargetIfFilterFBRemains, EvaluateTargetIfFractureMaintenance, not IsInMeleeRange) then return "fracture maintenance 10"; end
  end
  -- fracture,if=buff.recrimination.up
  if S.Fracture:IsCastable() and (Player:BuffUp(S.RecriminationBuff)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture maintenance 12"; end
  end
  -- fracture,if=(full_recharge_time<=cast_time+gcd.remains)
  if S.Fracture:IsCastable() and (S.Fracture:FullRechargeTime() <= S.Fracture:CastTime() + Player:GCDRemains()) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture maintenance 14"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura maintenance 16"; end
  end
  -- sigil_of_flame,if=dot.fiery_brand.ticking
  if S.SigilofFlame:IsCastable() and (Target:DebuffUp(S.FieryBrandDebuff)) then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame maintenance 18 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame maintenance 18 (Normal)"; end
    end
  end
  -- metamorphosis,if=talent.demonic&!buff.metamorphosis.up&!cooldown.fel_devastation.up&fury>=50
  if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and Player:BuffDown(S.MetamorphosisBuff) and S.FelDevastation:CooldownDown() and Player:Fury() >= 50) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis maintenance 18"; end
  end
end

local function SingleTarget()
  -- soul_carver,if=variable.fd&variable.frailty_ready&soul_fragments<=3
  if S.SoulCarver:IsCastable() and (VarFD and VarFrailtyReady and SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver single_target 2"; end
  end
  -- the_hunt,if=variable.frailty_ready
  if S.TheHunt:IsCastable() and (VarFrailtyReady) then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt single_target 4"; end
  end
  -- soul_carver,if=variable.frailty_ready&soul_fragments<=3
  if S.SoulCarver:IsCastable() and (VarFrailtyReady and SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver single_target 6"; end
  end
  -- fel_devastation,if=variable.frailty_ready&(variable.fd|talent.stoke_the_flames)&!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (VarFrailtyReady and (VarFD or S.StoketheFlames:IsAvailable()) and not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation single_target 8"; end
  end
  -- elysian_decree,if=variable.frailty_ready
  if S.ElysianDecree:IsCastable() and (VarFrailtyReady) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree single_target 10"; end
  end
  -- fracture,if=set_bonus.tier30_4pc&variable.fd&(soul_fragments<=3|(buff.metamorphosis.up&soul_fragments<=2))
  if S.Fracture:IsCastable() and (Player:HasTier(30, 4) and VarFD and (SoulFragments <= 3 or (Player:BuffUp(S.MetamorphosisBuff) and SoulFragments <= 2))) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture single_target 12"; end
  end
  -- fel_devastation,if=!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation single_target 14"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=4)|soul_fragments>=5)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 4) or SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb single_target 16"; end
  end
  -- fracture,if=set_bonus.tier30_4pc&variable.fd
  if S.Fracture:IsCastable() and (Player:HasTier(30, 4) and VarFD) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture single_target 18"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=3)|soul_fragments>=4)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 3) or SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb single_target 20"; end
  end
  -- soul_cleave,if=talent.focused_cleave
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable()) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave single_target 22"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture single_target 24"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=2)|soul_fragments>=3)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 2) or SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb single_target 26"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame single_target 28 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame single_target 28 (Normal)"; end
    end
  end
  -- soul_cleave
  if S.SoulCleave:IsReady() then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave single_target 30"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function SmallAoE()
  -- elysian_decree,if=variable.frailty_ready
  if S.ElysianDecree:IsCastable() and (VarFrailtyReady) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree small_aoe 2"; end
  end
  -- fel_devastation,if=variable.frailty_ready&variable.fd&talent.stoke_the_flames&!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (VarFrailtyReady and VarFD and S.StoketheFlames:IsAvailable() and not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 4"; end
  end
  -- the_hunt,if=variable.frailty_ready
  if S.TheHunt:IsCastable() and (VarFrailtyReady) then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt small_aoe 6"; end
  end
  -- fel_devastation,if=variable.frailty_ready&(variable.fd|talent.stoke_the_flames)&!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (VarFrailtyReady and (VarFD or S.StoketheFlames:IsAvailable()) and not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 8"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=4)|soul_fragments>=5)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 4) or SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb small_aoe 10"; end
  end
  -- soul_carver,if=variable.frailty_ready&variable.fd&soul_fragments<=3
  if S.SoulCarver:IsCastable() and (VarFrailtyReady and VarFD and SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver small_aoe 12"; end
  end
  -- fel_devastation,if=!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 14"; end
  end
  -- fracture,if=soul_fragments<=3&soul_fragments>=1
  if S.Fracture:IsCastable() and (SoulFragments <= 3 and SoulFragments >= 1) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture small_aoe 16"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame small_aoe 18 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame small_aoe 18 (Normal)"; end
    end
  end
  -- soul_carver,if=variable.frailty_ready&soul_fragments<=3
  if S.SoulCarver:IsCastable() and (VarFrailtyReady and SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver small_aoe 20"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=3)|soul_fragments>=4)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 3) or SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb small_aoe 22"; end
  end
  -- soul_cleave,if=talent.focused_cleave
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable()) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave small_aoe 24"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=2)|soul_fragments>=3)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 2) or SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb small_aoe 26"; end
  end
  -- soul_cleave
  if S.SoulCleave:IsReady() then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave small_aoe 28"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=1)|soul_fragments>=2)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 1) or SoulFragments >= 2) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb small_aoe 30"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture small_aoe 32"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function BigAoE()
  -- fel_devastation,if=variable.frailty_ready&variable.fd&talent.stoke_the_flames&!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (VarFrailtyReady and VarFD and S.StoketheFlames:IsAvailable() and not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 2"; end
  end
  -- elysian_decree,if=variable.frailty_ready
  if S.ElysianDecree:IsCastable() and (VarFrailtyReady) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree big_aoe 4"; end
  end
  -- fel_devastation,if=variable.frailty_ready&(variable.fd|talent.stoke_the_flames)&!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (VarFrailtyReady and (VarFD or S.StoketheFlames:IsAvailable()) and not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 6"; end
  end
  -- the_hunt,if=variable.frailty_ready
  if S.TheHunt:IsCastable() and (VarFrailtyReady) then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt big_aoe 8"; end
  end
  -- fel_devastation,if=!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 10"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=4)|soul_fragments>=5)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 4) or SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb big_aoe 12"; end
  end
  -- fracture,if=soul_fragments<=3&soul_fragments>=1
  if S.Fracture:IsCastable() and (SoulFragments <= 3 and SoulFragments >= 1) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture big_aoe 14"; end
  end
  -- soul_carver,if=variable.fd&variable.frailty_ready&soul_fragments<=3
  if S.SoulCarver:IsCastable() and (VarFD and VarFrailtyReady and SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver big_aoe 16"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=3)|soul_fragments>=4)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 3) or SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb big_aoe 18"; end
  end
  -- soul_carver,if=soul_fragments<=3
  if S.SoulCarver:IsCastable() and (SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver big_aoe 20"; end
  end
  -- soul_cleave,if=talent.focused_cleave
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable()) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave big_aoe 22"; end
  end
  -- spirit_bomb,if=((variable.fd&soul_fragments>=2)|soul_fragments>=3)
  if S.SpiritBomb:IsReady() and ((VarFD and SoulFragments >= 2) or SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb big_aoe 24"; end
  end
  -- soul_cleave
  if S.SoulCleave:IsReady() then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave big_aoe 26"; end
  end
  -- fracture,if=soul_fragments<=3
  if S.Fracture:IsCastable() and (SoulFragments <= 3) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture big_aoe 28"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

-- APL Main
local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8)
  if (AoEON()) then
    EnemiesCount8yMelee = #Enemies8yMelee
  else
    EnemiesCount8yMelee = 1
  end
  -- DEBUG REMOVE ME
  EnemiesCount8yMelee = 8

  UpdateSoulFragments()
  UpdateIsInMeleeRange()

  ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8yMelee, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=next_cd_time,value=cooldown.fel_devastation.remains
    VarCDTime = S.FelDevastation:CooldownRemains()
    -- variable,name=next_cd_time,op=min,value=cooldown.elysian_decree.remains,if=talent.elysian_decree
    if S.ElysianDecree:IsAvailable() then
      VarCDTime = mathmin(VarCDTime, S.ElysianDecree:CooldownRemains())
    end
    -- variable,name=next_cd_time,op=min,value=cooldown.the_hunt.remains,if=talent.the_hunt
    if S.TheHunt:IsAvailable() then
      VarCDTime = mathmin(VarCDTime, S.TheHunt:CooldownRemains())
    end
    -- variable,name=next_cd_time,op=min,value=cooldown.soul_carver.remains,if=talent.soul_carver
    if S.SoulCarver:IsAvailable() then
      VarCDTime = mathmin(VarCDTime, S.SoulCarver:CooldownRemains())
    end
    -- variable,name=next_fire_cd_time,value=cooldown.fel_devastation.remains
    VarNextFireCDTime = S.FelDevastation:CooldownRemains()
    -- variable,name=next_fire_cd_time,op=min,value=cooldown.soul_carver.remains,if=talent.soul_carver
    if S.SoulCarver:IsAvailable() then
      VarNextFireCDTime = mathmin(VarNextFireCDTime, S.SoulCarver:CooldownRemains())
    end
    -- variable,name=fd,value=talent.fiery_demise&dot.fiery_brand.ticking
    VarFD = S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff)
    -- variable,name=frailty_ready,value=!talent.soulcrush|debuff.frailty.stack>=2
    VarFrailtyReady = (not S.Soulcrush:IsAvailable()) or Target:DebuffStack(S.FrailtyDebuff) >= 2
    -- auto_attack
    -- disrupt,if=target.debuff.casting.react (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- infernal_strike,use_off_gcd=1
    if S.InfernalStrike:IsCastable() and ((not Settings.Vengeance.ConserveInfernalStrike) or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
      if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike main 2"; end
    end
    -- demon_spikes,use_off_gcd=1,if=!buff.demon_spikes.up&!cooldown.pause_action.remains
    -- Note: Handled via Defensives()
    -- call_action_list,name=maintenance
    local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=single_target,if=active_enemies=1
    if EnemiesCount8yMelee == 1 then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SingleTarget()"; end
    end
    -- run_action_list,name=small_aoe,if=active_enemies>1&active_enemies<=5
    if EnemiesCount8yMelee > 1 and EnemiesCount8yMelee <= 5 then
      local ShouldReturn = SmallAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SmallAoE()"; end
    end
    -- run_action_list,name=big_aoe,if=active_enemies>=6
    if EnemiesCount8yMelee >= 6 then
      local ShouldReturn = BigAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for BigAoE()"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FieryBrandDebuff:RegisterAuraTracking()

  HR.Print("Vengeance DH rotation is currently a work in progress, but has been updated for patch 10.1.5.")
end

HR.SetAPL(581, APL, Init);

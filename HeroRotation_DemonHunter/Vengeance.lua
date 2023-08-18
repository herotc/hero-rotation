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
local mathmax       = math.max
local mathmin       = math.min
local tableinsert   = table.insert

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Vengeance
local I = Item.DemonHunter.Vengeance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BeacontotheBeyond:ID(),
  I.DragonfireBombDispenser:ID(),
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
      SoulFragmentsAdjusted = mathmin(SoulFragments + 2, 5)
      LastSoulFragmentAdjustment = S.SoulCarver.LastCastTime
    elseif S.Fracture:IsAvailable() and S.Fracture:TimeSinceLastCast() < Player:GCD() and S.Fracture.LastCastTime ~= LastSoulFragmentAdjustment then
      SoulFragmentsAdjusted = mathmin(SoulFragments + 2 + MetaMod, 5)
      LastSoulFragmentAdjustment = S.Fracture.LastCastTime
    elseif S.Shear:TimeSinceLastCast() < Player:GCD() and S.Fracture.Shear ~= LastSoulFragmentAdjustment then
      SoulFragmentsAdjusted = mathmin(SoulFragments + 1 + MetaMod, 5)
      LastSoulFragmentAdjustment = S.Shear.LastCastTime
    elseif S.SoulSigils:IsAvailable() then
      local SigilLastCastTime = mathmax(S.SigilofFlame.LastCastTime, S.SigilofSilence.LastCastTime, S.SigilofChains.LastCastTime, S.ElysianDecree.LastCastTime)
      local SigilTSLC = mathmin(S.SigilofFlame:TimeSinceLastCast(), S.SigilofSilence:TimeSinceLastCast(), S.SigilofChains:TimeSinceLastCast(), S.ElysianDecree:TimeSinceLastCast())
      if S.ElysianDecree:IsAvailable() and SigilLastCastTime == S.ElysianDecree.LastCastTime and SigilTSLC < Player:GCD() and SigilLastCastTime ~= LastSoulFragmentAdjustment then
        local NewFrags = mathmin(EnemiesCount8yMelee, 3)
        SoulFragmentsAdjusted = mathmin(SoulFragments + NewFrags, 5)
        LastSoulFragmentAdjustment = SigilLastCastTime
      elseif SigilTSLC < Player:GCD() and SigilLastCastTime ~= LastSoulFragmentAdjustment then
        SoulFragmentsAdjusted = mathmin(SoulFragments + 1, 5)
        LastSoulFragmentAdjustment = SigilLastCastTime
      end
    elseif S.Fallout:IsAvailable() and S.ImmolationAura:TimeSinceLastCast() < Player:GCD() and S.ImmolationAura.LastCastTime ~= LastSoulFragmentAdjustment then
      local NewFrags = 0.6 * mathmin(EnemiesCount8yMelee, 5)
      SoulFragmentsAdjusted = mathmin(SoulFragments + NewFrags, 5)
      LastSoulFragmentAdjustment = S.ImmolationAura.LastCastTime
    elseif S.BulkExtraction:IsAvailable() and S.BulkExtraction:TimeSinceLastCast() < Player:GCD() and S.BulkExtraction.LastCastTime ~= LastSoulFragmentAdjustment then
      local NewFrags = mathmin(EnemiesCount8yMelee, 5)
      SoulFragmentsAdjusted = mathmin(SoulFragments + NewFrags, 5)
      LastSoulFragmentAdjustment = S.BulkExtraction.LastCastTime
    end
  else
    -- If we have a soul fragement "snapshot", see if we should invalidate it based on time
    local Prev = Player:PrevGCD(1)
    local FragAbilities = { S.SoulCarver, S.Fracture, S.Shear, S.BulkExtraction }
    if S.SoulSigils:IsAvailable() then
      tableinsert(FragAbilities, S.SigilofFlame)
      tableinsert(FragAbilities, S.SigilofSilence)
      tableinsert(FragAbilities, S.SigilofChains)
      tableinsert(FragAbilities, S.ElysianDecree)
    end
    if S.Fallout:IsAvailable() then
      tableinsert(FragAbilities, S.ImmolationAura)
    end
    for _, FragAbility in pairs(FragAbilities) do
      if Prev == FragAbility:ID() and FragAbility:TimeSinceLastCast() >= Player:GCD() then
        SoulFragmentsAdjusted = 0
        break
      end
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
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame filler 2 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame filler 2 (Normal)"; end
    end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura filler 4"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture filler 6"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear filler 8"; end
  end
  -- felblade
  if S.Felblade:IsReady() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade filler 10"; end
  end
  -- spirit_bomb,if=soul_fragments>=3
  if S.SpiritBomb:IsReady() and (SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb filler 12"; end
  end
  -- soul_cleave,if=soul_fragments<=1
  if S.SoulCleave:IsReady() and (SoulFragments <= 1) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave filler 14"; end
  end
  -- throw_glaive,if=gcd.remains>=0.5*gcd.max
  if S.ThrowGlaive:IsCastable() and (Player:GCDRemains() >= 0.5 * (Player:GCD() + 0.25)) then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive filler 16"; end
  end
end

local function Maintenance()
  -- fiery_brand,if=(!ticking&active_dot.fiery_brand=0)|charges>=2|(full_recharge_time<=cast_time+gcd.remains)
  if S.FieryBrand:IsCastable() and ((Target:DebuffDown(S.FieryBrandDebuff) and S.FieryBrandDebuff:AuraActiveCount() == 0) or S.FieryBrand:Charges() >= 2 or (S.FieryBrand:FullRechargeTime() <= S.FieryBrand:CastTime() + Player:GCDRemains())) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand maintenance 2"; end
  end
  -- bulk_extraction,if=active_enemies>=(5-soul_fragments)
  if S.BulkExtraction:IsCastable() and (EnemiesCount8yMelee >= (5 - SoulFragments)) then
    if Cast(S.BulkExtraction, Settings.Vengeance.GCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction maintenance 4"; end
  end
  -- spirit_bomb,if=soul_fragments>=5
  if S.SpiritBomb:IsReady() and (SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb maintenance 6"; end
  end
  -- fracture,target_if=max:dot.fiery_brand.remains,if=active_enemies>1&buff.recrimination.up
  if S.Fracture:IsCastable() and (EnemiesCount8yMelee > 1 and Player:BuffUp(S.RecriminationBuff)) then
    if Everyone.CastTargetIf(S.Fracture, Enemies8yMelee, "max", EvaluateTargetIfFilterFBRemains, EvaluateTargetIfFractureMaintenance, not IsInMeleeRange) then return "fracture maintenance 8"; end
  end
  -- fracture,if=(full_recharge_time<=cast_time+gcd.remains)
  if S.Fracture:IsCastable() and (S.Fracture:FullRechargeTime() <= S.Fracture:CastTime() + Player:GCDRemains()) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture maintenance 10"; end
  end
  -- immolation_aura,if=!talent.fallout|soul_fragments<5
  if S.ImmolationAura:IsCastable() and ((not S.Fallout:IsAvailable()) or SoulFragments < 5) then
    if Cast(S.ImmolationAura) then return "immolation_aura maintenance 12"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame maintenance 14 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame maintenance 14 (Normal)"; end
    end
  end
  -- metamorphosis,if=talent.demonic&!buff.metamorphosis.up&!cooldown.fel_devastation.up&fury>=50
  if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and Player:BuffDown(S.MetamorphosisBuff) and S.FelDevastation:CooldownDown() and Player:Fury() >= 50) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis maintenance 16"; end
  end
end

local function Externals()
  -- invoke_external_buff,name=symbol_of_hope,if=cooldown.fiery_brand.charges=0
  -- invoke_external_buff,name=power_infusion
  -- Note: Not handling external buffs
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=elementium_pocket_anvil,use_off_gcd=1
    if I.ElementiumPocketAnvil:IsEquippedAndReady() then
      if Cast(I.ElementiumPocketAnvil, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(8)) then return "elementium_pocket_anvil trinkets 2"; end
    end
    -- use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=!talent.first_of_the_illidari|buff.metamorphosis.up|fight_remains<=10|cooldown.metamorphosis.remains>25
    if I.BeacontotheBeyond:IsEquippedAndReady() and ((not S.FirstoftheIllidari:IsAvailable()) or Player:BuffUp(S.MetamorphosisBuff) or FightRemains <= 10 or S.Metamorphosis:CooldownRemains() > 25) then
      if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond trinkets 4"; end
    end
    -- use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1,if=trinket.beacon_to_the_beyond.cooldown.remains>5|!equipped.beacon_to_the_beyond
    if I.DragonfireBombDispenser:IsEquippedAndReady() and (I.BeacontotheBeyond:CooldownRemains() > 5 or not I.BeacontotheBeyond:IsEquipped()) then
      if Cast(I.DragonfireBombDispenser, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser trinkets 6"; end
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

local function SingleTarget()
  -- fel_devastation,if=!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation single_target 2"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver single_target 4"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt single_target 6"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree single_target 8"; end
  end
  -- fracture,if=set_bonus.tier30_4pc&variable.fd&soul_fragments<=4&soul_fragments>=1
  if S.Fracture:IsCastable() and (Player:HasTier(30, 4) and VarFD and SoulFragments <= 4 and SoulFragments >= 1) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture single_target 10"; end
  end
  -- spirit_bomb,if=soul_fragments>=4
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb single_target 12"; end
  end
  -- soul_cleave,if=talent.focused_cleave
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable()) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave single_target 14"; end
  end
  -- spirit_bomb,if=variable.fd&soul_fragments>=3
  if S.SpiritBomb:IsReady() and (VarFD and SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb single_target 16"; end
  end
  -- fracture,if=soul_fragments<=3&soul_fragments>=1
  if S.Fracture:IsCastable() and (SoulFragments <= 3 and SoulFragments >= 1) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture single_target 18"; end
  end
  -- soul_cleave,if=soul_fragments<=1
  if S.SoulCleave:IsReady() and (SoulFragments <= 1) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave single_target 20"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function SmallAoE()
  -- fel_devastation,if=!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 2"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt small_aoe 4"; end
  end
  -- elysian_decree,if=(soul_fragments+variable.incoming_souls)<=2
  if S.ElysianDecree:IsCastable() and (SoulFragments <= 2) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree small_aoe 6"; end
  end
  -- soul_carver,if=(soul_fragments+variable.incoming_souls)<=3
  if S.SoulCarver:IsCastable() and (SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver small_aoe 8"; end
  end
  -- fracture,if=soul_fragments<=3&soul_fragments>=1
  if S.Fracture:IsCastable() and (SoulFragments <= 3 and SoulFragments >= 1) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture small_aoe 10"; end
  end
  -- spirit_bomb,if=soul_fragments>=3
  if S.SpiritBomb:IsReady() and (SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb small_aoe 12"; end
  end
  -- soul_cleave,if=(talent.focused_cleave|(soul_fragments<=2&variable.incoming_souls=0))
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable() or SoulFragments <= 2) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave small_aoe 14"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function BigAoE()
  -- spirit_bomb,if=(active_enemies<=7&soul_fragments>=4)|(active_enemies>7&soul_fragments>=3)
  if S.SpiritBomb:IsReady() and ((EnemiesCount8yMelee <= 7 and SoulFragments >= 4) or (EnemiesCount8yMelee > 7 and SoulFragments >= 3)) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb big_aoe 2"; end
  end
  -- fel_devastation,if=!(talent.demonic&buff.metamorphosis.up)
  if S.FelDevastation:IsReady() and (not (S.Demonic:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 4"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt big_aoe 6"; end
  end
  -- elysian_decree,if=(soul_fragments+variable.incoming_souls)<=2
  if S.ElysianDecree:IsCastable() and (SoulFragments <= 2) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree big_aoe 8"; end
  end
  -- soul_carver,if=(soul_fragments+variable.incoming_souls)<=3
  if S.SoulCarver:IsCastable() and (SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver big_aoe 10"; end
  end
  -- fracture,if=soul_fragments>=2
  if S.Fracture:IsCastable() and (SoulFragments >= 2) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture big_aoe 12"; end
  end
  -- spirit_bomb,if=soul_fragments>=3
  if S.SpiritBomb:IsReady() and (SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb big_aoe 14"; end
  end
  -- soul_cleave,if=soul_fragments<=2&variable.incoming_souls=0
  if S.SoulCleave:IsReady() and (SoulFragments <= 2) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave big_aoe 16"; end
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
    -- variable,name=next_fire_cd_time,value=cooldown.fel_devastation.remains
    VarNextFireCDTime = S.FelDevastation:CooldownRemains()
    -- variable,name=next_fire_cd_time,op=min,value=cooldown.soul_carver.remains,if=talent.soul_carver
    if S.SoulCarver:IsAvailable() then
      VarNextFireCDTime = mathmin(VarNextFireCDTime, S.SoulCarver:CooldownRemains())
    end
    -- variable,name=incoming_souls,op=reset
    -- variable,name=incoming_souls,op=add,value=2,if=prev_gcd.1.fracture&!buff.metamorphosis.up
    -- variable,name=incoming_souls,op=add,value=3,if=prev_gcd.1.fracture&buff.metamorphosis.up
    -- variable,name=incoming_souls,op=add,value=2,if=talent.soul_sigils&(prev_gcd.2.sigil_of_flame|prev_gcd.2.sigil_of_silence|prev_gcd.2.sigil_of_chains|prev_gcd.2.elysian_decree)
    -- variable,name=incoming_souls,op=add,value=active_enemies>?3,if=talent.elysian_decree&prev_gcd.2.elysian_decree
    -- variable,name=incoming_souls,op=add,value=0.6*active_enemies>?5,if=talent.fallout&prev_gcd.1.immolation_aura
    -- variable,name=incoming_souls,op=add,value=active_enemies>?5,if=talent.bulk_extraction&prev_gcd.1.bulk_extraction
    -- variable,name=incoming_souls,op=add,value=3-(cooldown.soul_carver.duration-ceil(cooldown.soul_carver.remains)),if=talent.soul_carver&cooldown.soul_carver.remains>57
    -- Note: incoming_souls is already included in SoulFragments via SoulFragmentsAdjusted.
    -- variable,name=fd,value=talent.fiery_demise&dot.fiery_brand.ticking
    VarFD = S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff)
    -- auto_attack
    -- disrupt,if=target.debuff.casting.react (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- demon_spikes,use_off_gcd=1,if=!buff.demon_spikes.up&!cooldown.pause_action.remains
    -- Note: Handled via Defensives()
    -- call_action_list,name=externals
    -- Note: Not handling external buffs.
    -- metamorphosis,use_off_gcd=1,if=talent.first_of_the_illidari&(trinket.beacon_to_the_beyond.cooldown.remains<10|fight_remains<=20|!equipped.beacon_to_the_beyond|fight_remains%%120>5&fight_remains%%120<30)
    -- Note: if not equipped, I.BeacontotheBeyond:CooldownRemains() will return 0, so covered by the <10 check.
    if S.Metamorphosis:IsCastable() and (S.FirstoftheIllidari and (I.BeacontotheBeyond:CooldownRemains() < 10 or FightRemains <= 20 or FightRemains % 120 > 5 and FightRemains % 120 < 30)) then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis main 2"; end
    end
    -- infernal_strike,use_off_gcd=1
    if S.InfernalStrike:IsCastable() and ((not Settings.Vengeance.ConserveInfernalStrike) or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
      if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike main 4"; end
    end
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- call_action_list,name=trinkets
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=maintenance
    local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=single_target,if=active_enemies<=1
    if EnemiesCount8yMelee <= 1 then
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

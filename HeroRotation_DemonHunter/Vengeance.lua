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
  -- I.Item:ID(),
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
local VarDontSpendFury = true
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
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame precombat 2"; end
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
  -- sigil_of_chains,if=talent.cycle_of_binding.enabled&talent.sigil_of_chains.enabled
  if S.SigilofChains:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofChains, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_chains filler 2"; end
  end
  -- sigil_of_misery,if=talent.cycle_of_binding.enabled&talent.sigil_of_misery.enabled
  if S.SigilofMisery:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofMisery, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_misery filler 4"; end
  end
  -- sigil_of_silence,if=talent.cycle_of_binding.enabled&talent.sigil_of_silence.enabled
  if S.SigilofSilence:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofSilence, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_silence filler 6"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive filler 8"; end
  end
end

local function BigAoE()
  -- fel_devastation,if=talent.collective_anguish.enabled|talent.stoke_the_flames.enabled
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or S.StoketheFlames:IsAvailable()) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 2"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt big_aoe 4"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree big_aoe 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 8"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver big_aoe 10"; end
  end
  -- spirit_bomb,if=soul_fragments>=4
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb big_aoe 12"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture big_aoe 14"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear big_aoe 16"; end
  end
  -- soul_cleave,if=soul_fragments<1
  if S.SoulCleave:IsReady() and (SoulFragments < 1) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave big_aoe 18"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function Externals()
  -- invoke_external_buff,name=symbol_of_hope
  -- invoke_external_buff,name=power_infusion
end

local function FieryDemise()
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura fiery_demise 2"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fiery_demise 4"; end
  end
  -- felblade,if=(cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50
  if S.Felblade:IsReady() and ((S.FelDevastation:CooldownRemains() <= (S.Felblade:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fiery_demise 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fiery_demise 8"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fiery_demise 10"; end
  end
  -- spirit_bomb,if=spell_targets=1&soul_fragments>=5
  if S.SpiritBomb:IsReady() and (EnemiesCount8yMelee == 1 and SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb fiery_demise 12"; end
  end
  -- spirit_bomb,if=spell_targets>1&spell_targets<=5&soul_fragments>=4
  if S.SpiritBomb:IsReady() and (EnemiesCount8yMelee > 1 and EnemiesCount8yMelee <= 5 and SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb fiery_demise 14"; end
  end
  -- spirit_bomb,if=spell_targets>=6&soul_fragments>=3
  if S.SpiritBomb:IsReady() and (EnemiesCount8yMelee >= 6 and SoulFragments >= 3) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb fiery_demise 16"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt fiery_demise 18"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree fiery_demise 20"; end
  end
  -- soul_cleave,if=fury.deficit<=30&!variable.dont_spend_fury
  if S.SoulCleave:IsReady() and (Player:FuryDeficit() <= 30 and not VarDontSpendFury) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave fiery_demise 22"; end
  end
end

local function Maintenance()
  -- fiery_brand,if=(active_dot.fiery_brand=0&(cooldown.sigil_of_flame.remains<(execute_time+gcd.remains)|cooldown.soul_carver.remains<(execute_time+gcd.remains)|cooldown.fel_devastation.remains<(execute_time+gcd.remains)))|(talent.down_in_flames&full_recharge_time<(execute_time+gcd.remains))
  if S.FieryBrand:IsCastable() and ((S.FieryBrandDebuff:AuraActiveCount() == 0 and (S.SigilofFlame:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()) or S.SoulCarver:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()) or S.FelDevastation:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()))) or (S.DowninFlames:IsAvailable() and S.FieryBrand:FullRechargeTime() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()))) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand maintenance 2"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame maintenance 4"; end
  end
  -- spirit_bomb,if=soul_fragments>=5
  if S.SpiritBomb:IsReady() and (SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb maintenance 6"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura maintenance 8"; end
  end
  -- bulk_extraction,if=prev_gcd.1.spirit_bomb
  if S.BulkExtraction:IsCastable() and (Player:PrevGCDP(1, S.SpiritBomb)) then
    if Cast(S.BulkExtraction, Settings.Vengeance.GCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction maintenance 10"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsReady() and (Player:FuryDeficit() >= 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade maintenance 12"; end
  end
  -- fracture,if=(cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50
  if S.Fracture:IsCastable() and ((S.FelDevastation:CooldownRemains() <= (S.Fracture:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture maintenance 14"; end
  end
  -- shear,if=(cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50
  if S.Shear:IsCastable() and ((S.FelDevastation:CooldownRemains() <= (S.Fracture:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50) then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear maintenance 16"; end
  end
  -- spirit_bomb,if=fury.deficit<30&((spell_targets>=2&soul_fragments>=5)|(spell_targets>=6&soul_fragments>=4))&!variable.dont_spend_fury
  if S.SpiritBomb:IsReady() and (Player:FuryDeficit() < 30 and ((EnemiesCount8yMelee >= 2 and SoulFragments >= 5) or (EnemiesCount8yMelee >= 6 and SoulFragments >= 4)) and not VarDontSpendFury) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb maintenance 18"; end
  end
  -- soul_cleave,if=fury.deficit<30&soul_fragments<=3&!variable.dont_spend_fury
  if S.SoulCleave:IsReady() and (Player:FuryDeficit() < 30 and SoulFragments <= 3 and not VarDontSpendFury) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave maintenance 20"; end
  end
end

local function SingleTarget()
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt single_target 2"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver single_target 4"; end
  end
  -- fel_devastation,if=talent.collective_anguish.enabled|(talent.stoke_the_flames.enabled&talent.burning_blood.enabled)
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or (S.StoketheFlames:IsAvailable() and S.BurningBlood:IsAvailable())) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation single_target 6"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree single_target 8"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation single_target 10"; end
  end
  -- soul_cleave,if=talent.focused_cleave&!variable.dont_spend_fury
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable() and not VarDontSpendFury) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave single_target 12"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture single_target 14"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear single_target 16"; end
  end
  -- soul_cleave,if=!variable.dont_spend_fury
  if S.SoulCleave:IsReady() and (not VarDontSpendFury) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave single_target 18"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function SmallAoE()
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt small_aoe 2"; end
  end
  -- fel_devastation,if=talent.collective_anguish.enabled|(talent.stoke_the_flames.enabled&talent.burning_blood.enabled)
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or (S.StoketheFlames:IsAvailable() and S.BurningBlood:IsAvailable())) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 4"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree small_aoe 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 8"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver small_aoe 10"; end
  end
  -- spirit_bomb,if=soul_fragments>=5
  if S.SpiritBomb:IsReady() and (SoulFragments >= 5) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb small_aoe 12"; end
  end
  -- soul_cleave,if=talent.focused_cleave&soul_fragments<=2
  if S.SoulCleave:IsReady() and (S.FocusedCleave:IsAvailable() and SoulFragments <= 2) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave small_aoe 14"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture small_aoe 16"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear small_aoe 18"; end
  end
  -- soul_cleave,if=soul_fragments<=2
  if S.SoulCleave:IsReady() and (SoulFragments <= 2) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave small_aoe 20"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs
    -- use_item,use_off_gcd=1,slot=main_hand,if=(variable.trinket_1_buffs|trinket.1.cooldown.remains)&(variable.trinket_2_buffs|trinket.2.cooldown.remains)
    -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&(buff.metamorphosis.up|cooldown.metamorphosis.remains>20)&(variable.trinket_2_exclude|trinket.2.cooldown.remains|!trinket.2.has_cooldown|variable.trinket_2_buffs)
    -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&(buff.metamorphosis.up|cooldown.metamorphosis.remains>20)&(variable.trinket_1_exclude|trinket.1.cooldown.remains|!trinket.1.has_cooldown|variable.trinket_1_buffs)
    -- TODO: Find a way to handle variable.trinket_1_buffs and variable.trinket_2_buffs 
  end
  -- use_items
  -- Note: This is a generic use_items because of not handling the variables for the above lines
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
    BossFightRemains = HL.BossFightRemains()
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
    -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)
    -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)
    -- Note: Unable to handle above trinket lines.
    -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
    -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
    -- Note: Ruby Whelp Shell is already globally excluded.
    -- variable,name=dont_spend_fury,op=setif,condition=(cooldown.fel_devastation.remains<(action.soul_cleave.execute_time+gcd.remains))&fury<50,value=1,value_else=0
    VarDontSpendFury = ((S.FelDevastation:CooldownRemains() < (S.SoulCleave:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50)
    -- auto_attack
    -- disrupt,if=target.debuff.casting.react (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- infernal_strike,use_off_gcd=1
    if S.InfernalStrike:IsCastable() and (not Settings.Vengeance.ConserveInfernalStrike or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
      if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike main 2"; end
    end
    -- demon_spikes,use_off_gcd=1,if=!buff.demon_spikes.up&!cooldown.pause_action.remains
    -- Note: Handled via Defensives()
    -- metamorphosis,use_off_gcd=1
    if S.Metamorphosis:IsCastable() then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis main 4"; end
    end
    -- potion,use_off_gcd=1
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- call_action_list,name=externals
    -- Note: Not handling externals
    -- local ShouldReturn = Externals(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=fiery_demise,if=talent.fiery_demise&active_dot.fiery_brand>0
    if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 1 then
      local ShouldReturn = FieryDemise(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=maintenance
    local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=single_target,if=active_enemies<=1
    if EnemiesCount8yMelee <= 1 then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SingleTarget()"; end
    end
    -- run_action_list,name=small_aoe,if=active_enemies>1&active_enemies<=5
    if EnemiesCount8yMelee > 1 and EnemiesCount8yMelee <= 5 then
      local ShouldReturn = SmallAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SmallAoE()"; end
    end
    -- run_action_list,name=big_aoe,if=active_enemies>=6
    if EnemiesCount8yMelee >= 6 then
      local ShouldReturn = BigAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for BigAoE()"; end
    end
    
    
    
    
    
    
    
    
    -- fiery_brand,if=!talent.fiery_demise.enabled&!ticking
    if S.FieryBrand:IsCastable() and (not S.FieryDemise:IsAvailable() and Target:DebuffDown(S.FieryBrandDebuff)) then
      if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand main 10"; end
    end
    -- invoke_external_buff,name=power_infusion
    -- Note: Not handling external buffs
    -- call_action_list,name=trinkets
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=racials
    local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    -- fel_devastation
    if S.FelDevastation:IsReady() then
      if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation main 18"; end
    end
    -- immolation_aura,if=(dot.fiery_brand.ticking|dot.sigil_of_flame.ticking)&talent.charred_flesh
    if S.ImmolationAura:IsCastable() and ((Target:DebuffUp(S.FieryBrandDebuff) or Target:DebuffUp(S.SigilofFlameDebuff)) and S.CharredFlesh:IsAvailable()) then
      if Cast(S.ImmolationAura) then return "immolation_aura main 26"; end
    end
    -- fracture
    if S.Fracture:IsCastable() then
      if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture main 36"; end
    end
    -- shear
    if S.Shear:IsCastable() then
      if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear main 38"; end
    end
    -- throw_glaive
    if S.ThrowGlaive:IsCastable() then
      if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 40"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FieryBrandDebuff:RegisterAuraTracking()

  HR.Print("Vengeance DH rotation is currently a work in progress, but has been updated for patch 10.2.0.")
end

HR.SetAPL(581, APL, Init);

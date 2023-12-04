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
local SoulFragments, TotalSoulFragments, IncSoulFragments
local VarEDFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarDontCleave, VarFDReady, VarST, VarSmallAoE, VarBigAoE, VarCanSpB
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarEDFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

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
  -- Manually added: Gap closers
  if S.InfernalStrike:IsCastable() and not IsInMeleeRange then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike precombat 6"; end
  end
  if S.Felblade:IsCastable() and not IsInMeleeRange then
    if Cast(S.Felblade, nil, nil, not Target:IsInRange(15)) then return "felblade precombat 5"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura precombat 4"; end
  end
  -- Manually added: First attacks
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

local function Maintenance()
  -- fiery_brand,if=talent.fiery_brand&((active_dot.fiery_brand=0&(cooldown.sigil_of_flame.remains<=(execute_time+gcd.remains)|cooldown.soul_carver.remains<=(execute_time+gcd.remains)|cooldown.fel_devastation.remains<=(execute_time+gcd.remains)))|(talent.down_in_flames&full_recharge_time<=(execute_time+gcd.remains)))
  if S.FieryBrand:IsCastable() and ((S.FieryBrandDebuff:AuraActiveCount() == 0 and (S.SigilofFlame:CooldownRemains() <= (S.FieryBrand:ExecuteTime() + Player:GCDRemains()) or S.SoulCarver:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()) or S.FelDevastation:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()))) or (S.DowninFlames:IsAvailable() and S.FieryBrand:FullRechargeTime() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()))) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand maintenance 2"; end
  end
  -- sigil_of_flame,if=talent.ascending_flame|active_dot.sigil_of_flame=0
  if S.SigilofFlame:IsCastable() and (S.AscendingFlame:IsAvailable() or S.SigilofFlameDebuff:AuraActiveCount() == 0) then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame maintenance 4"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura maintenance 6"; end
  end
  -- bulk_extraction,if=((5-soul_fragments)<=spell_targets)&soul_fragments<=2
  if S.BulkExtraction:IsCastable() and (((5 - SoulFragments) <= EnemiesCount8yMelee) and SoulFragments <= 2) then
    if Cast(S.BulkExtraction, Settings.Vengeance.GCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction maintenance 8"; end
  end
  -- spirit_bomb,if=variable.can_spb
  if VarNoMaintCleave and not VarCanSpB then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  if S.SpiritBomb:IsReady() and (VarCanSpB) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb maintenance 10"; end
  end
  -- felblade,if=(fury.deficit>=40&active_enemies=1)|((cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50)
  if S.Felblade:IsReady() and ((Player:FuryDeficit() >= 40 and EnemiesCount8yMelee == 1) or ((S.FelDevastation:CooldownRemains() <= (S.Felblade:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50)) then
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
  -- Manually added: This should cause a fraction of a second of wait time while SoulFragments for Spirit Bomb move from incoming to active.
  if Player:FuryDeficit() <= 30 and EnemiesCount8yMelee > 1 and TotalSoulFragments >= 4 and SoulFragments < 4 then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  -- spirit_bomb,if=fury.deficit<=30&spell_targets>1&soul_fragments>=4
  if S.SpiritBomb:IsReady() and (Player:FuryDeficit() <= 30 and EnemiesCount8yMelee > 1 and SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb maintenance 18"; end
  end
  -- soul_cleave,if=fury.deficit<=40
  if S.SoulCleave:IsReady() and not VarNoMaintCleave and (Player:FuryDeficit() <= 40) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave maintenance 20"; end
  end
end

local function FieryDemise()
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura fiery_demise 2"; end
  end
  -- sigil_of_flame,if=talent.ascending_flame|active_dot.sigil_of_flame=0
  if S.SigilofFlame:IsCastable() and (S.AscendingFlame:IsAvailable() or S.SigilofFlameDebuff:AuraActiveCount() == 0) then
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
  -- soul_carver,if=soul_fragments.total<3
  if S.SoulCarver:IsCastable() and (TotalSoulFragments < 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fiery_demise 10"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt fiery_demise 12"; end
  end
  -- elysian_decree,line_cd=1.85,if=fury>=40
  if S.ElysianDecree:IsCastable() and S.ElysianDecree:TimeSinceLastCast() >= 1.85 and (Player:Fury() >= 40) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree fiery_demise 14"; end
  end
  -- spirit_bomb,if=variable.can_spb
  if VarNoMaintCleave and not VarCanSpB then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  if S.SpiritBomb:IsReady() and (VarCanSpB) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb fiery_demise 16"; end
  end
end

local function Filler()
  -- sigil_of_chains,if=talent.cycle_of_binding&talent.sigil_of_chains
  if S.SigilofChains:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofChains, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_chains filler 2"; end
  end
  -- sigil_of_misery,if=talent.cycle_of_binding&talent.sigil_of_misery.enabled
  if S.SigilofMisery:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofMisery, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_misery filler 4"; end
  end
  -- sigil_of_silence,if=talent.cycle_of_binding&talent.sigil_of_silence.enabled
  if S.SigilofSilence:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofSilence, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_silence filler 6"; end
  end
  -- felblade
  if S.Felblade:IsReady() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade filler 8"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive filler 10"; end
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
  -- fel_devastation,if=talent.collective_anguish|(talent.stoke_the_flames&talent.burning_blood)
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
  -- soul_cleave,if=!variable.dont_cleave
  if S.SoulCleave:IsReady() and (not VarDontCleave) then
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
  -- elysian_decree,line_cd=1.85,if=fury>=40&(soul_fragments.total<=1|soul_fragments.total>=4)
  if S.ElysianDecree:IsCastable() and S.ElysianDecree:TimeSinceLastCast() >= 1.85 and (Player:Fury() >= 40 and (TotalSoulFragments <= 1 or TotalSoulFragments >= 4)) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree small_aoe 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation small_aoe 8"; end
  end
  -- soul_carver,if=soul_fragments.total<3
  if S.SoulCarver:IsCastable() and (TotalSoulFragments < 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver small_aoe 10"; end
  end
  -- soul_cleave,if=soul_fragments<=1&!variable.dont_cleave
  if S.SoulCleave:IsReady() and (SoulFragments <= 1 and not VarDontCleave) then
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
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function BigAoE()
  -- fel_devastation,if=talent.collective_anguish|talent.stoke_the_flames
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or S.StoketheFlames:IsAvailable()) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 2"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt big_aoe 4"; end
  end
  -- elysian_decree,line_cd=1.85,if=fury>=40&(soul_fragments.total<=1|soul_fragments.total>=4)
  if S.ElysianDecree:IsCastable() and S.ElysianDecree:TimeSinceLastCast() >= 1.85 and (Player:Fury() >= 40 and (TotalSoulFragments <= 1 or TotalSoulFragments >= 4)) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree big_aoe 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation big_aoe 8"; end
  end
  -- soul_carver,if=soul_fragments.total<3
  if S.SoulCarver:IsCastable() and (TotalSoulFragments < 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver big_aoe 10"; end
  end
  -- Manually added: This should cause a fraction of a second of wait time while SoulFragments for Spirit Bomb move from incoming to active.
  if TotalSoulFragments >= 4 and SoulFragments < 4 then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
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
  -- soul_cleave,if=!variable.dont_cleave
  if S.SoulCleave:IsReady() and (not VarDontCleave) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave big_aoe 18"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function Externals()
  -- invoke_external_buff,name=symbol_of_hope
  -- invoke_external_buff,name=power_infusion
end

-- APL Main
local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8)
  if (AoEON()) then
    EnemiesCount8yMelee = #Enemies8yMelee > 0 and #Enemies8yMelee or 1
  else
    EnemiesCount8yMelee = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8yMelee, false)
    end

    -- Update Soul Fragment Totals
    --UpdateSoulFragments()
    SoulFragments = DemonHunter.Souls.AuraSouls
    IncSoulFragments = DemonHunter.Souls.IncomingSouls
    TotalSoulFragments = SoulFragments + IncSoulFragments

    -- Update if target is in melee range
    UpdateIsInMeleeRange()

    -- Set Tanking Variables
    ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=fd_ready,value=talent.fiery_brand&talent.fiery_demise&active_dot.fiery_brand>0
    VarFDReady = S.FieryBrand:IsAvailable() and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0
    -- variable,name=dont_cleave,value=(cooldown.fel_devastation.remains<=(action.soul_cleave.execute_time+gcd.remains))&fury<80
    -- Note: Moved below VarST/VarSmallAoE/VarBigAoE definitions, as we've manually added a VarST check
    -- variable,name=single_target,value=spell_targets.spirit_bomb=1
    VarST = EnemiesCount8yMelee == 1
    -- variable,name=small_aoe,value=spell_targets.spirit_bomb>=2&spell_targets.spirit_bomb<=5
    VarSmallAoE = EnemiesCount8yMelee >= 2 and EnemiesCount8yMelee <= 5
    -- variable,name=big_aoe,value=spell_targets.spirit_bomb>=6
    VarBigAoE = EnemiesCount8yMelee >= 6
    -- Note: Below line moved from above.
    VarDontCleave = ((S.FelDevastation:CooldownRemains() <= (S.SoulCleave:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 80 or (IncSoulFragments > 1 or TotalSoulFragments >= 5) and not VarST)
    -- variable,name=can_spb,op=setif,condition=variable.fd_ready,value=(variable.single_target&soul_fragments>=5)|(variable.small_aoe&soul_fragments>=4)|(variable.big_aoe&soul_fragments>=3),value_else=(variable.small_aoe&soul_fragments>=5)|(variable.big_aoe&soul_fragments>=4)
    if VarFDReady then
      VarCanSpB = (VarST and SoulFragments >= 5) or (VarSmallAoE and SoulFragments >= 4) or (VarBigAoE and SoulFragments >= 3)
    else
      VarCanSpB = (VarSmallAoE and SoulFragments >= 5) or (VarBigAoE and SoulFragments >= 4)
    end
    -- Note: Manually added variable for holding maintenance SoulCleave if incoming souls would make VarCanSpB true
    if VarFDReady then
      VarNoMaintCleave = (VarST and TotalSoulFragments >= 5) or (VarSmallAoE and TotalSoulFragments >= 4) or (VarBigAoE and TotalSoulFragments >= 3)
    else
      VarNoMaintCleave = (VarSmallAoE and TotalSoulFragments >= 5) or (VarBigAoE and TotalSoulFragments >= 4)
    end
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
    -- metamorphosis,use_off_gcd=1,if=!buff.metamorphosis.up
    if S.Metamorphosis:IsCastable() and (Player:BuffDown(S.MetamorphosisBuff)) then
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
    -- use_items,use_off_gcd=1
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
    -- call_action_list,name=fiery_demise,if=talent.fiery_brand&talent.fiery_demise&active_dot.fiery_brand>0
    if S.FieryBrand:IsAvailable() and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
      local ShouldReturn = FieryDemise(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=maintenance
    local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=single_target,if=variable.single_target
    if VarST then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SingleTarget()"; end
    end
    -- run_action_list,name=small_aoe,if=variable.small_aoe
    if VarSmallAoE then
      local ShouldReturn = SmallAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SmallAoE()"; end
    end
    -- run_action_list,name=big_aoe,if=variable.big_aoe
    if VarBigAoE then
      local ShouldReturn = BigAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for BigAoE()"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FieryBrandDebuff:RegisterAuraTracking()
  S.SigilofFlameDebuff:RegisterAuraTracking()

  HR.Print("Vengeance Demon Hunter rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(581, APL, Init);

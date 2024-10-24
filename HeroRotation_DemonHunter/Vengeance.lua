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
local CastQueue     = HR.CastQueue
local CastSuggested = HR.CastSuggested
local CastAnnotated = HR.CastAnnotated
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- lua
local GetTime       = GetTime
local mathfloor     = math.floor
local mathmax       = math.max
local mathmin       = math.min
local tableinsert   = table.insert
-- WoW API
local Delay         = C_Timer.After

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

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local DemonHunter   = HR.Commons.DemonHunter
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  CommonsDS = HR.GUISettings.APL.DemonHunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DemonHunter.CommonsOGCD,
  Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
}

--- ===== Rotation Variables =====
local SoulFragments, TotalSoulFragments, IncSoulFragments
local VarFieryBrandCD = (S.DowninFlames:IsAvailable()) and 48 or 60
-- local VarSigilPopTime = (S.QuickenedSigils:IsAvailable()) and 1 or 2
local VarSoFCD = (S.IlluminatedSigils:IsAvailable()) and 25 or 30
-- local VarSoSFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local ImmoAbility
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarNumSpawnableSouls = 0
local VarSpBThreshold, VarSpBombThreshold, VarSpBurstThreshold
local VarCanSpB, VarCanSpBSoon, VarCanSpBOneGCD
local VarCanSpBomb, VarCanSpBombSoon, VarCanSpBombOneGCD
local VarCanSpBurst, VarCanSpBurstSoon, VarCanSpBurstOneGCD
local VarDontSoulCleave, VarMetaPrepTime
local VarDoubleRMExpires, VarDoubleRMRemains
local VarTriggerOverflow, VarRGEnhCleave
local VarSoulsBeforeNextRGSequence
local VarFBBeforeMeta, VarHoldSoFForMeta, VarHoldSoFForFelDev, VarHoldSoFForStudent, VarHoldSoFForDot, VarHoldSoFForPrecombat
local VarCritPct, VarFelDevSequenceTime, VarFelDevPassiveFuryGen
local VarST, VarSmallAoE, VarBigAoE
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1          = T1.Object
  Trinket2          = T2.Object
  VarTrinket1CD     = T1.Cooldown
  VarTrinket2CD     = T2.Cooldown
  VarTrinket1Range  = T1.Range
  VarTrinket2Range  = T2.Range
  VarTrinket1Ex     = T1.Excluded
  VarTrinket2Ex     = T2.Excluded

  VarTrinket1Buffs  = Trinket1:HasUseBuff()
  VarTrinket2Buffs  = Trinket2:HasUseBuff()
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarFieryBrandCD = (S.DowninFlames:IsAvailable()) and 48 or 60
  VarSigilPopTime = (S.QuickenedSigils:IsAvailable()) and 1 or 2
  VarSoFCD = (S.IlluminatedSigils:IsAvailable()) and 25 or 30
  VarSoSFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== Helper Functions =====
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

-- ABSTRACTIONS FOR APL TEMPLATES

-- $(enough_souls_to_fel_dev)=(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)
local function EnoughSoulsToFelDev()
  return (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4)
end

-- $(rg_souls)=20
local function RGSouls()
  return 20
end

-- $(souls_per_second)=(1.1*(1+raw_haste_pct))
local function SoulsPerSecond()
  return (1.1 * (1 + Player:HastePct()))
end

-- $(should_fracture_rg)=((variable.rg_enhance_cleave&buff.rending_strike.up&buff.glaive_flurry.up)|(!variable.rg_enhance_cleave&!buff.glaive_flurry.up))
local function ShouldFractureRG()
  return ((VarRGEnhCleave and Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff)) or (not VarRGEnhCleave and not Player:BuffUp(S.GlaiveFlurryBuff)))
end

-- $(should_cleave_rg)=((!variable.rg_enhance_cleave&buff.glaive_flurry.up&buff.rending_strike.up)|(variable.rg_enhance_cleave&!buff.rending_strike.up))
local function ShouldCleaveRG()
  return ((not VarRGEnhCleave and Player:BuffUp(S.GlaiveFlurryBuff) and Player:BuffUp(S.RendingStrikeBuff)) or (VarRGEnhCleave and not Player:BuffUp(S.RendingStrikeBuff)))
end

-- $(enhance_cleave_only)=(spell_targets.spirit_bomb>=4)
local function EnhanceCleaveOnly()
  return (EnemiesCount8yMelee >= 4)
end

-- $(enough_fury_to_rg)=(fury+(variable.rg_enhance_cleave*25)+(talent.keen_engagement*20))>=30
local function EnoughFuryToRG()
  return (Player:Fury() + (num(VarRGEnhCleave) * 25) + (num(S.KeenEngagement:IsAvailable()) * 20) >= 30)
end

-- $(rg_sequence_duration)=(action.reavers_glaive.execute_time+action.fracture.execute_time+action.soul_cleave.execute_time+gcd.remains+(0.5*gcd.max))
-- Note (Jom): Added an additional half a GCD of time to each RG Sequence to account for brain lag
local function RGSequenceDuration()
  return (S.ReaversGlaive:ExecuteTime() + S.Fracture:ExecuteTime() + S.SoulCleave:ExecuteTime() + Player:GCDRemains() + Player:GCD())
end

-- $(execute_phase)=(fight_remains<10|target.time_to_die<10)
local function ExecutePhase()
  return (BossFightRemains < 10 or FightRemains < 10)
end

-- $(use_rg_main)=(!buff.thrill_of_the_fight_attack_speed.up|(variable.double_rm_remains<=$(rg_sequence_duration)))
local function UseRGMain()
  return (not Player:BuffUp(S.ThrilloftheFightAtkBuff) or (VarDoubleRMRemains <= RGSequenceDuration()))
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- variable,name=single_target,value=spell_targets.spirit_bomb=1
  -- variable,name=small_aoe,value=spell_targets.spirit_bomb>=2&spell_targets.spirit_bomb<=5
  -- variable,name=big_aoe,value=spell_targets.spirit_bomb>=6
  -- Note: Moving the above variables to APL()
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not IsInAoERange) then return "arcane_torrent precombat 2"; end
  end
  -- sigil_of_flame,if=hero_tree.aldrachi_reaver|(hero_tree.felscarred&talent.student_of_suffering)
  if S.SigilofFlame:IsCastable() and (Player:HeroTreeID() == 35 or (Player:HeroTreeID() == 34 and S.StudentofSuffering:IsAvailable())) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame precombat 4"; end
  end
  -- Manually added: Gap closers
  if S.InfernalStrike:IsCastable() and not IsInMeleeRange then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike precombat 6"; end
  end
  -- Note (Jom): Removed this from precombat because it harms the opener
  -- if S.Felblade:IsCastable() and not IsInMeleeRange then
  --   if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade precombat 6"; end
  -- end
  -- immolation_aura
  if ImmoAbility:IsCastable() then
    if Cast(ImmoAbility) then return "immolation_aura precombat 8"; end
  end
  -- Manually added: First attacks
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then return "fracture precombat 10"; end
  end
  if S.Shear:IsCastable() and IsInMeleeRange then
    if Cast(S.Shear) then return "shear precombat 12"; end
  end
end

local function Defensives()
  -- Demon Spikes
  if S.DemonSpikes:IsCastable() and Player:BuffDown(S.DemonSpikesBuff) and Player:BuffDown(S.MetamorphosisBuff) and S.FieryBrandDebuff:AuraActiveCount() == 0 then
    if S.DemonSpikes:ChargesFractional() > 1.8 then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.DemonSpikes) then return "demon_spikes defensives (Capped)"; end
    elseif (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.DemonSpikes) then return "demon_spikes defensives (Danger)"; end
    end
  end
  -- Metamorphosis,if=!buff.metamorphosis.up
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and Player:BuffDown(S.MetamorphosisBuff) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold and S.FieryBrandDebuff:AuraActiveCount() == 0) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
end

-- Note: Included because it's in the APL, but we don't handle externals.
--[[local function Externals()
  -- invoke_external_buff,name=symbol_of_hope
  -- invoke_external_buff,name=power_infusion
end]]

local function RGPrep()
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade rg_prep 2"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=!cooldown.felblade.up&talent.unhindered_assault
  if S.VengefulRetreat:IsCastable() and (not S.Felblade:CooldownUp() and S.UnhinderedAssault:IsAvailable()) then
    if Cast(S.VengefulRetreat, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "vengeful_retreat rg_prep 4"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame rg_prep 6"; end
  end
  -- immolation_aura
  if ImmoAbility:IsCastable() then
    if Cast(ImmoAbility) then return "immolation_aura rg_prep 8"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rg_prep 10"; end
  end
end

local function RGOverflow()
  -- variable,name=trigger_overflow,op=set,value=1
  VarTriggerOverflow = true
  -- variable,name=rg_enhance_cleave,op=set,value=1
  VarRGEnhCleave = true
  -- reavers_glaive,if=$(enough_fury_to_rg)&!buff.rending_strike.up&!buff.glaive_flurry.up
  if S.ReaversGlaive:IsCastable() and (EnoughFuryToRG() and Player:BuffDown(S.RendingStrikeBuff) and Player:BuffDown(S.GlaiveFlurryBuff)) then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "reavers_glaive rg_overflow 2"; end
  end
  -- call_action_list,name=rg_prep,if=!$(enough_fury_to_rg)
  if S.ReaversGlaive:IsLearned() and (not EnoughFuryToRG()) then
    local ShouldReturn = RGPrep(); if ShouldReturn then return ShouldReturn; end
  end
end

local function RGSequenceFiller()
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade rg_sequence_filler 2"; end
  end
  -- fracture,if=!buff.rending_strike.up
  if S.Fracture:IsCastable() and (Player:BuffDown(S.RendingStrikeBuff)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rg_sequence_filler 4"; end
  end
  -- wait,sec=0.1,if=action.fracture.charges_fractional<0.8&(variable.rg_enhance_cleave&buff.rending_strike.up&buff.glaive_flurry.up|!variable.rg_enhance_cleave&!buff.glaive_flurry.up)
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame rg_sequence_filler 6"; end
  end
  -- sigil_of_spite
  if S.SigilofSpite:IsCastable() then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite rg_sequence_filler 8"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver rg_sequence_filler 10"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation rg_sequence_filler 12"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive rg_sequence_filler 14"; end
  end
end

local function RGSequence()
  -- variable,name=double_rm_expires,value=time+action.fracture.execute_time+20,if=!buff.glaive_flurry.up&buff.rending_strike.up
  if not Player:BuffUp(S.GlaiveFlurryBuff) and Player:BuffUp(S.RendingStrikeBuff) then
    VarDoubleRMExpires = HL.CombatTime() + S.Fracture:ExecuteTime() + 20
  end
  -- call_action_list,name=rg_sequence_filler,if=(fury<30&$(should_cleave_rg))|(action.fracture.charges_fractional<1&$(should_fracture_rg))
  if (Player:Fury() < 30 and ShouldCleaveRG()) or (S.Fracture:ChargesFractional() < 1 and ShouldFractureRG()) then
    local ShouldReturn = RGSequenceFiller(); if ShouldReturn then return ShouldReturn; end
  end
  -- fracture,if=$(should_fracture_rg)
  if S.Fracture:IsCastable() and (ShouldFractureRG()) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rg_sequence 2"; end
  end
  -- shear,if=$(should_fracture_rg)
  if S.Shear:IsCastable() and (ShouldFractureRG()) then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear rg_sequence 4"; end
  end
  -- soul_cleave,if=$(should_cleave_rg)
  if S.SoulCleave:IsReady() and (ShouldCleaveRG()) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave rg_sequence 6"; end
  end
  -- fracture
  -- Manual Override (Jom): Sometimes the player will play non-optimally, and can end up in a situation where there are no valid recommendations inside of RGSequence()
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rg_sequence 7"; end
  end
  -- soul_cleave
  -- Manual Override (Jom): Sometimes the player will play non-optimally, and can end up in a situation where there are no valid recommendations inside of RGSequence()
  if S.SoulCleave:IsReady() then
      if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave rg_sequence 8"; end
  end
end

local function ARExecute()
  -- metamorphosis,use_off_gcd=1
  if S.Metamorphosis:IsCastable() then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis ar_execute 2"; end
  end
  -- reavers_glaive,if=$(enough_fury_to_rg)&!(buff.rending_strike.up|buff.glaive_flurry.up)
  if S.ReaversGlaive:IsCastable() and (EnoughFuryToRG() and (not Player:BuffUp(S.RendingStrikeBuff) and not Player:BuffUp(S.GlaiveFlurryBuff))) then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "reavers_glaive ar_execute 4"; end
  end
  -- call_action_list,name=rg_prep,if=buff.reavers_glaive.up&!$(enough_fury_to_rg)
  if S.ReaversGlaive:IsLearned() and not EnoughFuryToRG() then
    local ShouldReturn = RGPrep(); if ShouldReturn then return ShouldReturn; end
  end
  -- the_hunt,if=!buff.reavers_glaive.up
  if S.TheHunt:IsCastable() and (not S.ReaversGlaive:IsLearned()) then
    if Settings.Vengeance.TheHuntAnnotateIcon then
      if CastAnnotated(S.TheHunt, false, "The Hunt") then return "the_hunt (Icon Bugfix) ar_execute 6"; end
    else
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar_execute 6"; end
    end
  end
  -- bulk_extraction,if=spell_targets>=3&buff.art_of_the_glaive.stack>=$(rg_souls)
  if S.BulkExtraction:IsCastable() and (EnemiesCount8yMelee >= 3 and Player:BuffStack(S.ArtoftheGlaiveBuff) >= RGSouls()) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not IsInMeleeRange) then return "bulk_extraction ar_execute 8"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame ar_execute 10"; end
  end
  -- fiery_brand
  if S.FieryBrand:IsCastable() then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand ar_execute 12"; end
  end
  -- sigil_of_spite
  if S.SigilofSpite:IsCastable() then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite ar_execute 14"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver ar_execute 16"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation ar_execute 18"; end
  end
end

local function AR()
  -- variable,name=spb_threshold,op=setif,condition=talent.fiery_demise&dot.fiery_brand.ticking,value=(variable.single_target*5)+(variable.small_aoe*5)+(variable.big_aoe*4),value_else=(variable.single_target*5)+(variable.small_aoe*5)+(variable.big_aoe*4)
  -- Note: Currently the value and value_else are identical, so skipping the condition check.
  --if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
    VarSpBThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 5) + (num(VarBigAoE) * 4)
  --else
    --VarSpBThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 5) + (num(VarBigAoE) * 4)
  --end
  -- variable,name=can_spb,op=setif,condition=talent.spirit_bomb,value=soul_fragments>=variable.spb_threshold,value_else=0
  VarCanSpB = S.SpiritBomb:IsAvailable() and SoulFragments >= VarSpBThreshold
  -- variable,name=can_spb_soon,op=setif,condition=talent.spirit_bomb,value=soul_fragments.total>=variable.spb_threshold,value_else=0
  VarCanSpBSoon = S.SpiritBomb:IsAvailable() and TotalSoulFragments >= VarSpBThreshold
  -- variable,name=can_spb_one_gcd,op=setif,condition=talent.spirit_bomb,value=(soul_fragments.total+variable.num_spawnable_souls)>=variable.spb_threshold,value_else=0
  VarCanSpBOneGCD = S.SpiritBomb:IsAvailable() and (TotalSoulFragments + VarNumSpawnableSouls) >= VarSpBThreshold
  -- variable,name=double_rm_remains,op=setif,condition=(variable.double_rm_expires-time)>0,value=variable.double_rm_expires-time,value_else=0
  VarDoubleRMRemains = VarDoubleRMExpires and ((VarDoubleRMExpires - HL.CombatTime()) > 0) and (VarDoubleRMExpires - HL.CombatTime()) or 0
  -- variable,name=trigger_overflow,op=set,value=0,if=!buff.glaive_flurry.up&!buff.rending_strike.up&!prev_gcd.1.reavers_glaive
  if Player:BuffDown(S.GlaiveFlurryBuff) and Player:BuffDown(S.RendingStrikeBuff) and not Player:PrevGCD(1, S.ReaversGlaive) then
    VarTriggerOverflow = false
  end
  -- variable,name=rg_enhance_cleave,op=setif,condition=variable.trigger_overflow|$(enhance_cleave_only)|$(execute_phase),value=1,value_else=0
  VarRGEnhCleave = (VarTriggerOverflow or EnhanceCleaveOnly() or ExecutePhase())
  -- variable,name=souls_before_next_rg_sequence,value=soul_fragments.total+buff.art_of_the_glaive.stack
  VarSoulsBeforeNextRGSequence = TotalSoulFragments + Player:BuffStack(S.ArtoftheGlaiveBuff)
  -- variable,name=souls_before_next_rg_sequence,op=add,value=$(souls_per_second)*(variable.double_rm_remains-$(rg_sequence_duration))
  VarSoulsBeforeNextRGSequence = VarSoulsBeforeNextRGSequence + (SoulsPerSecond() * (VarDoubleRMRemains - RGSequenceDuration()))
  -- variable,name=souls_before_next_rg_sequence,op=add,value=3+talent.soul_sigils,if=cooldown.sigil_of_spite.remains<(variable.double_rm_remains-gcd.max-(2-talent.soul_sigils))
  if S.SigilofSpite:CooldownRemains() < (VarDoubleRMRemains - Player:GCD() - (2 - num(S.SoulSigils:IsAvailable()))) then
    VarSoulsBeforeNextRGSequence = VarSoulsBeforeNextRGSequence + 3 + num(S.SoulSigils:IsAvailable())
  end
  -- variable,name=souls_before_next_rg_sequence,op=add,value=3,if=cooldown.soul_carver.remains<(variable.double_rm_remains-gcd.max)
  if S.SoulCarver:CooldownRemains() < (VarDoubleRMRemains - Player:GCD()) then
    VarSoulsBeforeNextRGSequence = VarSoulsBeforeNextRGSequence + 3
  end
  -- variable,name=souls_before_next_rg_sequence,op=add,value=3,if=cooldown.soul_carver.remains<(variable.double_rm_remains-gcd.max-3)
  if S.SoulCarver:CooldownRemains() < (VarDoubleRMRemains - Player:GCD() - 3) then
    VarSoulsBeforeNextRGSequence = VarSoulsBeforeNextRGSequence + 3
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs|(variable.trinket_1_buffs&((buff.rending_strike.up&buff.glaive_flurry.up)|(prev_gcd.1.reavers_glaive)|(buff.thrill_of_the_fight_damage.remains>8)|(buff.reavers_glaive.up&cooldown.the_hunt.remains<5)))
    if Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs or (VarTrinket1Buffs and ((Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff)) or Player:PrevGCD(1, S.ReaversGlaive) or (Player:BuffRemains(S.ThrilloftheFightDmgBuff) > 8) or (S.ReaversGlaive:IsLearned() and S.TheHunt:CooldownRemains() < 5)))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for AR trinket1 (" .. Trinket1:Name() .. ")"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs|(variable.trinket_2_buffs&((buff.rending_strike.up&buff.glaive_flurry.up)|(prev_gcd.1.reavers_glaive)|(buff.thrill_of_the_fight_damage.remains>8)|(buff.reavers_glaive.up&cooldown.the_hunt.remains<5)))
    if Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs or (VarTrinket2Buffs and ((Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff)) or Player:PrevGCD(1, S.ReaversGlaive) or (Player:BuffRemains(S.ThrilloftheFightDmgBuff) > 8) or (S.ReaversGlaive:IsLearned() and S.TheHunt:CooldownRemains() < 5)))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for AR trinket2 (" .. Trinket2:Name() .. ")"; end
    end
  end
  -- potion,use_off_gcd=1,if=(buff.rending_strike.up&buff.glaive_flurry.up)|prev_gcd.1.reavers_glaive
  if Settings.Commons.Enabled.Potions and ((Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff)) or Player:PrevGCD(1, S.ReaversGlaive)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ar 2"; end
    end
  end
  -- call_action_list,name=externals,if=(buff.rending_strike.up&buff.glaive_flurry.up)|prev_gcd.1.reavers_glaive
  -- Note: Not handling externals.
  -- run_action_list,name=rg_sequence,if=buff.glaive_flurry.up|buff.rending_strike.up|prev_gcd.1.reavers_glaive
  -- Note: Added FuryoftheAldrachi check to avoid stalling the profile if it's not yet learned.
  if S.FuryoftheAldrachi:IsAvailable() and (Player:BuffUp(S.GlaiveFlurryBuff) or Player:BuffUp(S.RendingStrikeBuff) or Player:PrevGCD(1, S.ReaversGlaive)) then
    local ShouldReturn = RGSequence(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for RGSequence()"; end
  end
  -- metamorphosis,use_off_gcd=1,if=time<5|cooldown.fel_devastation.remains>=20
  if S.Metamorphosis:IsCastable() and (HL.CombatTime() < 5 or S.FelDevastation:CooldownRemains() >= 20) then
      if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis ar 5"; end
  end
  -- the_hunt,if=!buff.reavers_glaive.up&(buff.art_of_the_glaive.stack+soul_fragments.total)<$(rg_souls)
  if S.TheHunt:IsReady() and (not S.ReaversGlaive:IsLearned() and ((Player:BuffStack(S.ArtoftheGlaiveBuff) + TotalSoulFragments) < RGSouls())) then
    if Settings.Vengeance.TheHuntAnnotateIcon then
      if CastAnnotated(S.TheHunt, false, "The Hunt") then return "the_hunt (Icon Bugfix) ar 8"; end
    else
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar 8"; end
    end
  end
  -- spirit_bomb,if=variable.can_spb&(soul_fragments.inactive>2|prev_gcd.1.sigil_of_spite|prev_gcd.1.soul_carver|(spell_targets.spirit_bomb>=4&talent.fallout&cooldown.immolation_aura.remains<gcd.max))
  if S.SpiritBomb:IsReady() and (VarCanSpB and (IncSoulFragments > 2 or Player:PrevGCD(1, S.SigilofSpite) or Player:PrevGCD(1, S.SoulCarver) or (EnemiesCount8yMelee >= 4 and S.Fallout:IsAvailable() and S.ImmolationAura:CooldownRemains() < Player:GCD()))) then
    if Cast(S.SpiritBomb, nil, nil, not IsInAoERange) then return "spirit_bomb ar 7"; end
  end
  -- immolation_aura,if=(!buff.reavers_glaive.up|(variable.double_rm_remains>($(rg_sequence_duration)+gcd.max)))&(variable.single_target|!variable.can_spb)
  if ImmoAbility:IsCastable() and ((not S.ReaversGlaive:IsLearned() or (VarDoubleRMRemains > (RGSequenceDuration() + Player:GCD()))) and (VarST or not VarCanSpB)) then
    if Cast(ImmoAbility) then return "immolation_aura ar 8"; end
  end
  -- sigil_of_flame,if=(talent.ascending_flame|(!prev_gcd.1.sigil_of_flame&dot.sigil_of_flame.remains<(4-talent.quickened_sigils)))&(!buff.reavers_glaive.up|(variable.double_rm_remains>($(rg_sequence_duration)+gcd.max)))
  if S.SigilofFlame:IsCastable() and ((S.AscendingFlame:IsAvailable() or (not Player:PrevGCDP(1, S.SigilofFlame) and Target:DebuffRemains(S.SigilofFlameDebuff) < (4 - num(S.QuickenedSigils:IsAvailable())))) and (not S.ReaversGlaive:IsLearned() or (VarDoubleRMRemains > (RGSequenceDuration() + Player:GCD())))) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame ar 10"; end
  end
  -- run_action_list,name=rg_overflow,if=buff.reavers_glaive.up&!$(enhance_cleave_only)&debuff.reavers_mark.up&(variable.double_rm_remains>$(rg_sequence_duration))&(!buff.thrill_of_the_fight_damage.up|(buff.thrill_of_the_fight_damage.remains<$(rg_sequence_duration)))&((variable.double_rm_remains-$(rg_sequence_duration))>$(rg_sequence_duration))&((variable.souls_before_next_rg_sequence>=$(rg_souls))|(variable.double_rm_remains>($(rg_sequence_duration)+cooldown.the_hunt.remains+action.the_hunt.execute_time)))
  if S.ReaversGlaive:IsLearned() and (not EnhanceCleaveOnly() and Target:DebuffUp(S.ReaversMarkDebuff) and (VarDoubleRMRemains > RGSequenceDuration()) and (Player:BuffDown(S.ThrilloftheFightDmgBuff) or (Player:BuffRemains(S.ThrilloftheFightDmgBuff) < RGSequenceDuration())) and ((VarDoubleRMRemains - RGSequenceDuration()) > RGSequenceDuration()) and ((VarSoulsBeforeNextRGSequence >= RGSouls()) or (VarDoubleRMRemains > (RGSequenceDuration() + S.TheHunt:CooldownRemains() + S.TheHunt:ExecuteTime())))) then
    local ShouldReturn = RGOverflow(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool for RGOverflow()"; end
  end
  -- call_action_list,name=ar_execute,if=$(execute_phase)
  if ExecutePhase() then
    local ShouldReturn = ARExecute(); if ShouldReturn then return ShouldReturn; end
  end
  -- soul_cleave,if=!buff.reavers_glaive.up&(variable.double_rm_remains<=(execute_time+$(rg_sequence_duration)))&(soul_fragments<3&((buff.art_of_the_glaive.stack+soul_fragments)>=$(rg_souls)))
  if S.SoulCleave:IsReady() and (not S.ReaversGlaive:IsLearned() and ((VarDoubleRMRemains <= (S.SoulCleave:ExecuteTime() + RGSequenceDuration())) and (SoulFragments < 3 and (Player:BuffStack(S.ArtoftheGlaiveBuff) + SoulFragments) >= RGSouls()))) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ar 14"; end
  end
  -- spirit_bomb,if=!buff.reavers_glaive.up&(variable.double_rm_remains<=(execute_time+$(rg_sequence_duration)))&((buff.art_of_the_glaive.stack+soul_fragments)>=$(rg_souls))
  if S.SpiritBomb:IsReady() and (not S.ReaversGlaive:IsLearned() and ((VarDoubleRMRemains <= (S.SpiritBomb:ExecuteTime() + RGSequenceDuration())) and (Player:BuffStack(S.ArtoftheGlaiveBuff) + SoulFragments) >= RGSouls())) then
    if Cast(S.SpiritBomb, nil, nil, not IsInAoERange) then return "spirit_bomb ar 16"; end
  end
  -- bulk_extraction,if=!buff.reavers_glaive.up&(variable.double_rm_remains<=(execute_time+$(rg_sequence_duration)))&((buff.art_of_the_glaive.stack+(spell_targets>?5))>=$(rg_souls))
  if S.BulkExtraction:IsCastable() and (not S.ReaversGlaive:IsLearned() and ((VarDoubleRMRemains <= (S.BulkExtraction:ExecuteTime() + RGSequenceDuration())) and (Player:BuffStack(S.ArtoftheGlaiveBuff) + mathmin(EnemiesCount8yMelee, 5)) >= RGSouls())) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not IsInMeleeRange) then return "bulk_extraction ar 18"; end
  end
  -- reavers_glaive,if=$(enough_fury_to_rg)&($(use_rg_main)|$(enhance_cleave_only))&!(buff.rending_strike.up|buff.glaive_flurry.up)
  if S.ReaversGlaive:IsCastable() and (EnoughFuryToRG() and (UseRGMain() or EnhanceCleaveOnly()) and (not Player:BuffUp(S.RendingStrikeBuff) and not Player:BuffUp(S.GlaiveFlurryBuff))) then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "reavers_glaive ar 20"; end
  end
  -- call_action_list,name=rg_prep,if=!$(enough_fury_to_rg)&($(use_rg_main)|$(enhance_cleave_only))
  if S.ReaversGlaive:IsLearned() and (not EnoughFuryToRG() and (UseRGMain() or EnhanceCleaveOnly())) then
    local ShouldReturn = RGPrep(); if ShouldReturn then return ShouldReturn; end
  end
  -- fiery_brand,if=(!talent.fiery_demise&active_dot.fiery_brand=0)|(talent.down_in_flames&(full_recharge_time<gcd.max))|(talent.fiery_demise&active_dot.fiery_brand=0&(buff.reavers_glaive.up|cooldown.the_hunt.remains<5|buff.art_of_the_glaive.stack>=15|buff.thrill_of_the_fight_damage.remains>5))
  if S.FieryBrand:IsCastable() and ((not S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() == 0) or (S.DowninFlames:IsAvailable() and S.FieryBrand:FullRechargeTime() < Player:GCD()) or (S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() == 0 and (S.ReaversGlaive:IsLearned() or S.TheHunt:CooldownRemains() < 5 or Player:BuffStack(S.ArtoftheGlaiveBuff) >= 15 or Player:BuffRemains(S.ThrilloftheFightDmgBuff) > 5))) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand ar 22"; end
  end
  -- sigil_of_spite,if=buff.thrill_of_the_fight_damage.up|(fury>=80&(variable.can_spb|variable.can_spb_soon))|((soul_fragments.total+buff.art_of_the_glaive.stack+($(souls_per_second)*(variable.double_rm_remains-$(rg_sequence_duration))))<$(rg_souls))
  if S.SigilofSpite:IsCastable() and (Player:BuffUp(S.ThrilloftheFightDmgBuff) or (Player:Fury() >= 80 and (VarCanSpB or VarCanSpBSoon)) or ((TotalSoulFragments + Player:BuffStack(S.ArtoftheGlaiveBuff) + (SoulsPerSecond() * (VarDoubleRMRemains - RGSequenceDuration()))) < RGSouls())) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite ar 24"; end
  end
  -- spirit_bomb,if=variable.can_spb
  if S.SpiritBomb:IsReady() and (VarCanSpB) then
    if Cast(S.SpiritBomb, nil, nil, not IsInAoERange) then return "spirit_bomb ar 26"; end
  end
  -- felblade,if=(variable.can_spb|variable.can_spb_soon)&fury<40
  if S.Felblade:IsCastable() and ((VarCanSpB or VarCanSpBSoon) and Player:Fury() < 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 28"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=(variable.can_spb|variable.can_spb_soon)&fury<40&!cooldown.felblade.up&talent.unhindered_assault
  if S.VengefulRetreat:IsCastable() and ((VarCanSpB or VarCanSpBSoon) and Player:Fury() < 40 and not S.Felblade:CooldownUp() and S.UnhinderedAssault:IsAvailable()) then
    if Cast(S.VengefulRetreat, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "vengeful_retreat ar 28"; end
  end
  -- fracture,if=(variable.can_spb|variable.can_spb_soon|variable.can_spb_one_gcd)&fury<40
  if S.Fracture:IsCastable() and ((VarCanSpB or VarCanSpBSoon or VarCanSpBOneGCD) and Player:Fury() < 40) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ar 28"; end
  end
  -- (Jom) Manually added -- wait for souls to spawn if we'll be able to cast spirit bomb shortly
  if S.SpiritBomb:IsReady() and (not VarCanSpB and TotalSoulFragments >= VarSpBThreshold and SoulFragments < 5) and (Player:GCDRemains() < (Player:GCD() * 0.5)) then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Soul Fragments (Spirit Burst)"; end
  end
  -- soul_carver,if=buff.thrill_of_the_fight_damage.up|((soul_fragments.total+buff.art_of_the_glaive.stack+($(souls_per_second)*(variable.double_rm_remains-$(rg_sequence_duration))))<$(rg_souls))
  if S.SoulCarver:IsCastable() and (Player:BuffUp(S.ThrilloftheFightDmgBuff) or ((TotalSoulFragments + Player:BuffStack(S.ArtoftheGlaiveBuff) + (SoulsPerSecond() * (VarDoubleRMRemains - RGSequenceDuration()))) < RGSouls())) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver ar 28"; end
  end
  -- fel_devastation,if=!buff.metamorphosis.up&((variable.double_rm_remains>($(rg_sequence_duration)+2))|$(enhance_cleave_only))&((action.fracture.full_recharge_time<(2+gcd.max))|(!variable.single_target&buff.thrill_of_the_fight_damage.up))
  if S.FelDevastation:IsReady() and (not Player:BuffUp(S.MetamorphosisBuff) and ((VarDoubleRMRemains > (RGSequenceDuration() + 2)) or EnhanceCleaveOnly()) and ((S.Fracture:FullRechargeTime() < (2 + Player:GCD())) or (not VarST and Player:BuffUp(S.ThrilloftheFightDmgBuff)))) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation ar 28"; end
  end
  -- felblade,if=cooldown.fel_devastation.remains<gcd.max&fury<50
  if S.Felblade:IsCastable() and ((S.FelDevastation:CooldownRemains() < Player:GCD()) and Player:Fury() < 50) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 30"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=cooldown.fel_devastation.remains<gcd.max&fury<50&!cooldown.felblade.up&talent.unhindered_assault
  if S.VengefulRetreat:IsCastable() and ((S.FelDevastation:CooldownRemains() < Player:GCD()) and Player:Fury() < 50 and not S.Felblade:CooldownUp() and S.UnhinderedAssault:IsAvailable()) then
    if Cast(S.VengefulRetreat, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "vengeful_retreat ar 30"; end
  end
  -- fracture,if=cooldown.fel_devastation.remains<gcd.max&fury<50
  if S.Fracture:IsCastable() and ((S.FelDevastation:CooldownRemains() < Player:GCD()) and Player:Fury() < 50) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ar 30"; end
  end
  -- fracture,if=(full_recharge_time<gcd.max)|buff.metamorphosis.up|variable.can_spb|variable.can_spb_soon|buff.warblades_hunger.stack>=5
  if S.Fracture:IsCastable() and ((S.Fracture:FullRechargeTime() < Player:GCD()) or Player:BuffUp(S.MetamorphosisBuff) or VarCanSpB or VarCanSpBSoon or Player:BuffStack(S.WarbladesHungerBuff) >= 5) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ar 30"; end
  end
  -- soul_cleave,if=soul_fragments>=1
  if S.SoulCleave:IsReady() and (SoulFragments >= 1) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ar 32"; end
  end
  -- bulk_extraction,if=spell_targets>=3
  if S.BulkExtraction:IsCastable() and (EnemiesCount8yMelee >= 3) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not IsInMeleeRange) then return "bulk_extraction ar 38"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ar 44"; end
  end
  -- soul_cleave
  if S.SoulCleave:IsReady() then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ar 44"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear ar 46"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 48"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive ar 50"; end
  end
end

local function FelDev()
  -- spirit_burst,if=buff.demonsurge_spirit_burst.up&(variable.can_spburst|soul_fragments>=4|(buff.metamorphosis.remains<(gcd.max*2)))
  if S.SpiritBurst:IsReady() and (Player:Demonsurge("SpiritBurst") and (VarCanSpBurst or SoulFragments >= 4 or Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCD() * 2))) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_burst fel_dev 2"; end
  end
  -- soul_sunder,if=buff.demonsurge_soul_sunder.up&(!buff.demonsurge_spirit_burst.up|(buff.metamorphosis.remains<(gcd.max*2)))
  if S.SoulSunder:IsReady() and (Player:Demonsurge("SoulSunder") and (not Player:Demonsurge("SpiritBurst") or Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCD() * 2))) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder fel_dev 4"; end
  end
  -- sigil_of_spite,if=(!talent.cycle_of_binding|(cooldown.sigil_of_spite.duration<(cooldown.metamorphosis.remains+18)))&(soul_fragments.total<=2&buff.demonsurge_spirit_burst.up)
  if S.SigilofSpite:IsCastable() and ((not S.CycleofBinding:IsAvailable() or (60 < (S.Metamorphosis:CooldownRemains() + 18))) and (TotalSoulFragments <= 2 and Player:Demonsurge("SpiritBurst"))) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fel_dev 6"; end
  end
  -- soul_carver,if=soul_fragments.total<=2&!prev_gcd.1.sigil_of_spite&buff.demonsurge_spirit_burst.up
  if S.SoulCarver:IsCastable() and (TotalSoulFragments <= 2 and not Player:PrevGCD(1, S.SigilofSpite) and Player:Demonsurge("SpiritBurst")) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fel_dev 8"; end
  end
  -- fracture,if=soul_fragments.total<=2&buff.demonsurge_spirit_burst.up
  if S.Fracture:IsCastable() and (TotalSoulFragments <= 2 and Player:Demonsurge("SpiritBurst")) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev 10"; end
  end
  -- felblade,if=buff.demonsurge_spirit_burst.up|buff.demonsurge_soul_sunder.up
  if S.Felblade:IsCastable() and (Player:Demonsurge("SpiritBurst") or Player:Demonsurge("SoulSunder")) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_dev 12"; end
  end
  -- fracture,if=buff.demonsurge_spirit_burst.up|buff.demonsurge_soul_sunder.up
  if S.Fracture:IsCastable() and (Player:Demonsurge("SpiritBurst") or Player:Demonsurge("SoulSunder")) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev 14"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() and (Player:Demonsurge("SpiritBurst") or Player:Demonsurge("SoulSunder"))then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear fel_dev 16"; end
  end
end

local function FelDevPrep()
  -- potion,use_off_gcd=1,if=prev_gcd.1.fiery_brand
  if Settings.Commons.Enabled.Potions and Player:PrevGCD(1, S.FieryBrand) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion fel_dev_prep 2"; end
    end
  end
  -- sigil_of_flame,if=!variable.hold_sof_for_precombat&!variable.hold_sof_for_student&!variable.hold_sof_for_dot
  if S.SigilofFlame:IsCastable() and (not VarHoldSoFForPrecombat and not VarHoldSoFForStudent and not VarHoldSoFForDot) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fs 4"; end
  end
  -- fiery_brand,if=talent.fiery_demise&((fury+variable.fel_dev_passive_fury_gen)>=120)&(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)&active_dot.fiery_brand=0&((cooldown.metamorphosis.remains<(execute_time+action.fel_devastation.execute_time+(gcd.max*2)))|variable.fiery_brand_back_before_meta)
  if S.FieryBrand:IsCastable() and (S.FieryDemise:IsAvailable() and ((Player:Fury() + VarFelDevPassiveFuryGen) >= 120) and (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4) and S.FieryBrandDebuff:AuraActiveCount() == 0 and ((S.Metamorphosis:CooldownRemains() < (S.FieryBrand:ExecuteTime() + S.FelDevastation:ExecuteTime() + (Player:GCD() * 2))) or VarFBBeforeMeta)) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fel_dev_prep 4"; end
  end
  -- fel_devastation,if=((fury+variable.fel_dev_passive_fury_gen)>=120)&(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)
  if S.FelDevastation:IsReady() and (((Player:Fury() + VarFelDevPassiveFuryGen) >= 120) and (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4)) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fel_dev_prep 6"; end
  end
  -- sigil_of_spite,if=(!talent.cycle_of_binding|(cooldown.sigil_of_spite.duration<(cooldown.metamorphosis.remains+18)))&(soul_fragments.total<=1|(!$(enough_souls_to_fel_dev)&action.fracture.charges_fractional<1))
  if S.SigilofSpite:IsCastable() and ((not S.CycleofBinding:IsAvailable() or (60 < (S.Metamorphosis:CooldownRemains() + 18))) and (TotalSoulFragments <= 1 or (not EnoughSoulsToFelDev() and S.Fracture:ChargesFractional() < 1))) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fel_dev_prep 7"; end
  end
  -- soul_carver,if=(!talent.cycle_of_binding|cooldown.metamorphosis.remains>20)&(soul_fragments.total<=1|(!(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)&action.fracture.charges_fractional<1))&!prev_gcd.1.sigil_of_spite&!prev_gcd.2.sigil_of_spite
  if S.SoulCarver:IsCastable() and (not S.CycleofBinding:IsAvailable() or S.Metamorphosis:CooldownRemains() > 20) and ((TotalSoulFragments <= 1 or (not (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4) and S.Fracture:ChargesFractional() < 1)) and not Player:PrevGCD(1, S.SigilofSpite) and not Player:PrevGCD(2, S.SigilofSpite)) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fel_dev_prep 10"; end
  end
  -- felblade,if=!((fury+variable.fel_dev_passive_fury_gen)>=120)&(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)
  if S.Felblade:IsCastable() and (not ((Player:Fury() + VarFelDevPassiveFuryGen) >= 120) and (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_dev_prep 12"; end
  end
  -- fracture,if=!(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)|!((fury+variable.fel_dev_passive_fury_gen)>=120)
  if S.Fracture:IsCastable() and (not (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4) or not ((Player:Fury() + VarFelDevPassiveFuryGen) >= 120)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev_prep 14"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_dev_prep 16"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev_prep 18"; end
  end
  -- wait,sec=0.1,if=(!(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)|!((fury+variable.fel_dev_passive_fury_gen)>=120))&action.fracture.charges_fractional>=0.7
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fel_dev_prep 20"; end
  end
  -- soul_cleave,if=((fury+variable.fel_dev_passive_fury_gen)>=150)
  if S.SoulCleave:IsReady() and ((Player:Fury() + VarFelDevPassiveFuryGen) >= 150) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave fel_dev_prep 22"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fel_dev_prep 24"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear fel_dev_prep 26"; end
  end
end

local function FSExecute()
  -- metamorphosis,use_off_gcd=1
  if S.Metamorphosis:IsCastable() then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis fs_execute 2"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Settings.Vengeance.TheHuntAnnotateIcon then
      if CastAnnotated(S.TheHunt, false, "The Hunt") then return "the_hunt (Icon Bugfix) fs_execute 4"; end
    else
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt fs_execute 4"; end
    end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fs_execute 6"; end
  end
  -- fiery_brand
  if S.FieryBrand:IsCastable() then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fs_execute 8"; end
  end
  -- sigil_of_spite
  if S.SigilofSpite:IsCastable() then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fs_execute 10"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fs_execute 12"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fs_execute 14"; end
  end
end

local function MetaPrep()
  -- Note: metamorphosis and sigil_of_flame moved into a CastQueue.
  -- Note: Intent is to suggest metamorphosis after sigil_of_flame, but before the sigil explodes.
  -- Note: Doing this allows the sigil_of_flame to deal damage as sigil_of_doom.
  -- metamorphosis,use_off_gcd=1,if=cooldown.sigil_of_flame.charges<1
  --if S.Metamorphosis:IsCastable() and (S.SigilofFlame:Charges() < 1) then
    --if Cast(S.Metamorphosis) then return "metamorphosis meta_prep 2"; end
  --end
  -- fiery_brand,if=talent.fiery_demise&((talent.down_in_flames&charges>=max_charges)|active_dot.fiery_brand=0)
  if S.FieryBrand:IsCastable() and (S.FieryDemise:IsAvailable() and ((S.DowninFlames:IsAvailable() and S.FieryBrand:Charges() >= S.FieryBrand:MaxCharges()) or S.FieryBrandDebuff:AuraActiveCount() == 0)) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand meta_prep 2"; end
  end
  -- potion,use_off_gcd=1
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion meta_prep 4"; end
    end
  end
  -- sigil_of_flame
  -- metamorphosis,if=cooldown.sigil_of_flame.charges>=1
  if S.SigilofFlame:IsCastable() and S.Metamorphosis:IsCastable() then
    if CastQueue(S.SigilofFlame, S.Metamorphosis) then return "sigil_of_flame and metamorphosis meta_prep 6"; end
  end
  -- metamorphosis,if=cooldown.sigil_of_flame.charges=0
  -- Note: Forced to main icon, as otherwise the main icon will be Pool.
  if S.Metamorphosis:IsCastable() and (S.SigilofFlame:Charges() == 0 or Player:PrevGCD(1, S.SigilofFlame)) then
    if Cast(S.Metamorphosis) then return "metamorphosis meta_prep 8"; end
  end
end

local function Metamorphosis()
  -- call_action_list,name=externals
  -- Note: Not handling externals.
  -- fel_desolation,if=buff.metamorphosis.remains<(gcd.max*3)
  if S.FelDesolation:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCD() * 3)) then
    if Cast(S.FelDesolation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_desolation metamorphosis 2"; end
  end
  -- felblade,if=fury<50&(buff.metamorphosis.remains<(gcd.max*3))&cooldown.fel_desolation.up
  if S.Felblade:IsCastable() and (Player:Fury() < 50 and (Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCD() * 3)) and S.FelDesolation:CooldownUp()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 4"; end
  end
  -- fracture,if=fury<50&!cooldown.felblade.up&(buff.metamorphosis.remains<(gcd.max*3))&cooldown.fel_desolation.up
  if S.Fracture:IsCastable() and (Player:Fury() < 50 and S.Felblade:CooldownDown() and (Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCD() * 3)) and S.FelDesolation:CooldownUp()) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture metamorphosis 6"; end
  end
  -- sigil_of_doom,if=talent.illuminated_sigils&talent.cycle_of_binding&charges=max_charges
  -- Note: Using Charges check, as IsReady can return false due to very recent SigilofFlame usage.
  if S.SigilofDoom:Charges() > 0 and (S.IlluminatedSigils:IsAvailable() and S.CycleofBinding:IsAvailable() and S.SigilofDoom:Charges() >= S.SigilofDoom:MaxCharges()) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom metamorphosis 8"; end
  end
  -- immolation_aura
  if ImmoAbility:IsCastable() then
    if Cast(ImmoAbility, nil, nil, not IsInAoERange) then return "immolation_aura metamorphosis 8"; end
  end
  -- sigil_of_doom,if=!talent.student_of_suffering&(talent.ascending_flame|(!talent.ascending_flame&!prev_gcd.1.sigil_of_doom&(dot.sigil_of_doom.remains<(4-talent.quickened_sigils))))
  if S.SigilofDoom:IsReady() and (not S.StudentofSuffering:IsAvailable() and (S.AscendingFlame:IsAvailable() or (not S.AscendingFlame:IsAvailable() and not Player:PrevGCD(1, S.SigilofDoom) and (Target:DebuffRemains(S.SigilofDoomDebuff) < (4 - num(S.QuickenedSigils:IsAvailable())))))) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom metamorphosis 9"; end
  end
  -- sigil_of_doom,if=talent.student_of_suffering&!prev_gcd.1.sigil_of_flame&!prev_gcd.1.sigil_of_doom&(buff.student_of_suffering.remains<(4-talent.quickened_sigils))
  if S.SigilofDoom:IsReady() and (S.StudentofSuffering:IsAvailable() and not Player:PrevGCD(1, S.SigilofFlame) and not Player:PrevGCD(1, S.SigilofDoom) and (Player:BuffRemains(S.StudentofSufferingBuff) < (4 - num(S.QuickenedSigils:IsAvailable())))) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom metamorphosis 10"; end
  end
  -- sigil_of_doom,if=buff.metamorphosis.remains<((2-talent.quickened_sigils)+(charges*gcd.max))
  if S.SigilofDoom:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < ((2 - num(S.QuickenedSigils:IsAvailable())) + (S.SigilofDoom:Charges() * Player:GCD()))) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom metamorphosis 11"; end
  end
  -- fel_desolation,if=soul_fragments<=3&(soul_fragments.inactive>=2|prev_gcd.1.sigil_of_spite)
  if S.FelDesolation:IsReady() and (SoulFragments <= 3 and (IncSoulFragments >= 2 or Player:PrevGCD(1, S.SigilofSpite))) then
    if Cast(S.FelDesolation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_desolation metamorphosis 10"; end
  end
  -- felblade,if=((cooldown.sigil_of_spite.remains<execute_time|cooldown.soul_carver.remains<execute_time)&cooldown.fel_desolation.remains<(execute_time+gcd.max)&fury<50)
  if S.Felblade:IsCastable() and ((S.SigilofSpite:CooldownRemains() < S.Felblade:ExecuteTime() or S.SoulCarver:CooldownRemains() < S.Felblade:ExecuteTime()) and S.FelDesolation:CooldownRemains() < (S.Felblade:ExecuteTime() + Player:GCD()) and Player:Fury() < 50) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 14"; end
  end
  -- soul_carver,if=(!talent.spirit_bomb|(variable.single_target&!buff.demonsurge_spirit_burst.up))|(((soul_fragments.total+3)<=6)&fury>=40&!prev_gcd.1.sigil_of_spite)
  if S.SoulCarver:IsCastable() and (not S.SpiritBomb:IsAvailable() or (VarST and not Player:Demonsurge("SpiritBurst")) or ((TotalSoulFragments + 3) <= 6 and Player:Fury() >= 40 and not Player:PrevGCD(1, S.SigilofSpite))) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver metamorphosis 14"; end
  end
  -- sigil_of_spite,if=!talent.spirit_bomb|(fury>=80&(variable.can_spburst|variable.can_spburst_soon))|(soul_fragments.total<=(2-talent.soul_sigils.rank))
  if S.SigilofSpite:IsCastable() and (not S.SpiritBomb:IsAvailable() or (Player:Fury() >= 80 and (VarCanSpBurst or VarCanSpBurstSoon)) or (TotalSoulFragments <= (2 - S.SoulSigils:TalentRank()))) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite metamorphosis 16"; end
  end
  -- spirit_burst,if=variable.can_spburst&buff.demonsurge_spirit_burst.up
  if S.SpiritBurst:IsReady() and (VarCanSpBurst and Player:Demonsurge("SpiritBurst")) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_burst metamorphosis 18"; end
  end
  -- fel_desolation
  if S.FelDesolation:IsReady() then
    if Cast(S.FelDesolation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_desolation metamorphosis 24"; end
  end
  -- the_hunt
  if S.TheHunt:IsReady() then
    if Settings.Vengeance.TheHuntAnnotateIcon then
      if CastAnnotated(S.TheHunt, false, "The Hunt") then return "the_hunt (Icon Bugfix) metamorphosis 25"; end
    else
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt metamorphosis 25"; end
    end
  end
  -- soul_sunder,if=buff.demonsurge_soul_sunder.up&!buff.demonsurge_spirit_burst.up&!variable.can_spburst_one_gcd
  if S.SoulSunder:IsReady() and (Player:Demonsurge("SoulSunder") and not Player:Demonsurge("SpiritBurst") and not VarCanSpBurstOneGCD) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder metamorphosis 26"; end
  end
  -- spirit_burst,if=variable.can_spburst&(talent.fiery_demise&dot.fiery_brand.ticking|variable.big_aoe)&buff.metamorphosis.remains>(gcd.max*2)
  if S.SpiritBurst:IsReady() and (VarCanSpBurst and (S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff) or VarBigAoE) and Player:BuffRemains(S.MetamorphosisBuff) > (Player:GCD() * 2)) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_burst metamorphosis 28"; end
  end
  -- felblade,if=fury<40&(variable.can_spburst|variable.can_spburst_soon)&(buff.demonsurge_spirit_burst.up|talent.fiery_demise&dot.fiery_brand.ticking|variable.big_aoe)
  if S.Felblade:IsCastable() and (Player:Fury() < 40 and (VarCanSpBurst or VarCanSpBurstSoon) and (Player:Demonsurge("SpiritBurst") or (S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff) or VarBigAoE))) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 30"; end
  end
  -- fracture,if=fury<40&(variable.can_spburst|variable.can_spburst_soon|variable.can_spburst_one_gcd)&(buff.demonsurge_spirit_burst.up|talent.fiery_demise&dot.fiery_brand.ticking|variable.big_aoe)
  if S.Fracture:IsCastable() and (Player:Fury() < 40 and (VarCanSpBurst or VarCanSpBurstSoon or VarCanSpBurstOneGCD) and (Player:Demonsurge("SpiritBurst") or (S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff) or VarBigAoE))) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture metamorphosis 32"; end
  end
  -- fracture,if=variable.can_spburst_one_gcd&(buff.demonsurge_spirit_burst.up|variable.big_aoe)&!prev_gcd.1.fracture
  if S.Fracture:IsCastable() and (VarCanSpBurstOneGCD and (Player:Demonsurge("SpiritBurst") or VarBigAoE) and not Player:PrevGCD(1, S.Fracture)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture metamorphosis 34"; end
  end
  -- soul_sunder,if=variable.single_target&!variable.dont_soul_cleave
  if S.SoulSunder:IsReady() and (VarST and not VarDontSoulCleave) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder metamorphosis 36"; end
  end
  -- spirit_burst,if=variable.can_spburst&buff.metamorphosis.remains>(gcd.max*2)
  if S.SpiritBurst:IsReady() and (VarCanSpBurst and Player:BuffRemains(S.MetamorphosisBuff) > (Player:GCD() * 2)) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_burst metamorphosis 38"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 40"; end
  end
  -- soul_sunder,if=!variable.dont_soul_cleave&!(variable.big_aoe&(variable.can_spburst|variable.can_spburst_soon))
  if S.SoulSunder:IsReady() and (not VarDontSoulCleave and not (VarBigAoE and (VarCanSpBurst or VarCanSpBurstSoon))) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder metamorphosis 42"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 38"; end
  end
  -- fracture,if=!prev_gcd.1.fracture
  if S.Fracture:IsCastable() and (not Player:PrevGCD(1, S.Fracture)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture metamorphosis 44"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear metamorphosis 42"; end
  end
end

local function FS()
  -- variable,name=crit_pct,op=set,value=(dot.sigil_of_flame.crit_pct+(talent.aura_of_pain*6))%100,if=active_dot.sigil_of_flame>0&talent.volatile_flameblood
  VarCritPct = 0
  if S.SigilofFlameDebuff:AuraActiveCount() > 0 and S.VolatileFlameblood:IsAvailable() then
    VarCritPct = (Player:CritChancePct() + (num(S.AuraofPain:IsAvailable()) * 6)) / 100
  end
  -- variable,name=fel_dev_sequence_time,op=set,value=2+(2*gcd.max)
  VarFelDevSequenceTime = 2 + (2 * Player:GCD())
  -- variable,name=fel_dev_sequence_time,op=add,value=gcd.max,if=talent.fiery_demise&cooldown.fiery_brand.up
  if S.FieryDemise:IsAvailable() and S.FieryBrand:CooldownUp() then
    VarFelDevSequenceTime = VarFelDevSequenceTime + Player:GCD()
  end
  -- variable,name=fel_dev_sequence_time,op=add,value=gcd.max,if=cooldown.sigil_of_flame.up|cooldown.sigil_of_flame.remains<variable.fel_dev_sequence_time
  if S.SigilofFlame:CooldownUp() or S.SigilofFlame:CooldownRemains() < VarFelDevSequenceTime then
    VarFelDevSequenceTime = VarFelDevSequenceTime + Player:GCD()
  end
  -- variable,name=fel_dev_sequence_time,op=add,value=gcd.max,if=cooldown.immolation_aura.up|cooldown.immolation_aura.remains<variable.fel_dev_sequence_time
  if ImmoAbility:CooldownUp() or ImmoAbility:CooldownRemains() < VarFelDevSequenceTime then
    VarFelDevSequenceTime = VarFelDevSequenceTime + Player:GCD()
  end
  -- variable,name=fel_dev_passive_fury_gen,op=set,value=0
  VarFelDevPassiveFuryGen = 0
  -- variable,name=fel_dev_passive_fury_gen,op=add,value=2.5*floor((buff.student_of_suffering.remains>?variable.fel_dev_sequence_time)),if=talent.student_of_suffering.enabled&(buff.student_of_suffering.remains>1|prev_gcd.1.sigil_of_flame)
  if S.StudentofSuffering:IsAvailable() and (Player:BuffRemains(S.StudentofSufferingBuff) > 1 or Player:PrevGCD(1, S.SigilofFlame)) then
    VarFelDevPassiveFuryGen = VarFelDevPassiveFuryGen + 2.5 * mathfloor(mathmin(Player:BuffRemains(S.StudentofSufferingBuff), VarFelDevSequenceTime))
  end
  -- variable,name=fel_dev_passive_fury_gen,op=add,value=30+(2*talent.flames_of_fury*spell_targets.sigil_of_flame),if=(cooldown.sigil_of_flame.remains<variable.fel_dev_sequence_time)
  if (S.SigilofFlame:CooldownRemains() < VarFelDevSequenceTime) then
    VarFelDevPassiveFuryGen = VarFelDevPassiveFuryGen + 30 + (2 * num(S.FlamesofFury:IsAvailable()) * EnemiesCount8yMelee)
  end
  -- variable,name=fel_dev_passive_fury_gen,op=add,value=8,if=cooldown.immolation_aura.remains<variable.fel_dev_sequence_time
  if ImmoAbility:CooldownRemains() < VarFelDevSequenceTime then
    VarFelDevPassiveFuryGen = VarFelDevPassiveFuryGen + 8
  end
  -- variable,name=fel_dev_passive_fury_gen,op=add,value=2*floor((buff.immolation_aura.remains>?variable.fel_dev_sequence_time)),if=buff.immolation_aura.remains>1
  if Player:BuffRemains(S.ImmolationAuraBuff) > 1 or Player:BuffRemains(S.ConsumingFireBuff) > 1 then
    local ImmoBuffRemains = Player:BuffUp(S.ConsumingFireBuff) and Player:BuffRemains(S.ConsumingFireBuff) or Player:BuffRemains(S.ImmolationAuraBuff)
    VarFelDevPassiveFuryGen = VarFelDevPassiveFuryGen + (2 * mathfloor(mathmin(ImmoBuffRemains, VarFelDevSequenceTime)))
  end
  -- variable,name=fel_dev_passive_fury_gen,op=add,value=7.5*variable.crit_pct*floor((buff.immolation_aura.remains>?variable.fel_dev_sequence_time)),if=talent.volatile_flameblood&buff.immolation_aura.remains>1
  if S.VolatileFlameblood:IsAvailable() and (Player:BuffRemains(S.ImmolationAuraBuff) > 1 or Player:BuffRemains(S.ConsumingFireBuff) > 1) then
    local ImmoBuffRemains = Player:BuffUp(S.ConsumingFireBuff) and Player:BuffRemains(S.ConsumingFireBuff) or Player:BuffRemains(S.ImmolationAuraBuff)
    VarFelDevPassiveFuryGen = VarFelDevPassiveFuryGen + (7.5 * VarCritPct * mathfloor(mathmin(ImmoBuffRemains, VarFelDevSequenceTime)))
  end
  -- variable,name=fel_dev_passive_fury_gen,op=add,value=22,if=talent.darkglare_boon.enabled
  if S.DarkglareBoon:IsAvailable() then
    VarFelDevPassiveFuryGen = VarFelDevPassiveFuryGen + 22
  end
  -- variable,name=spbomb_threshold,op=setif,condition=talent.fiery_demise&dot.fiery_brand.ticking,value=(variable.single_target*5)+(variable.small_aoe*5)+(variable.big_aoe*4),value_else=(variable.single_target*5)+(variable.small_aoe*5)+(variable.big_aoe*4)
  -- Note: value and value_else are the same currently.
  --if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
    VarSpBombThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 5) + (num(VarBigAoE) * 4)
  --else
    --VarSpBombThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 4) + (num(VarBigAoE) * 4)
  --end
  -- variable,name=can_spbomb,op=setif,condition=talent.spirit_bomb,value=soul_fragments>=variable.spbomb_threshold,value_else=0
  VarCanSpBomb = S.SpiritBomb:IsAvailable() and SoulFragments >= VarSpBombThreshold
  -- variable,name=can_spbomb_soon,op=setif,condition=talent.spirit_bomb,value=soul_fragments.total>=variable.spbomb_threshold,value_else=0
  VarCanSpBombSoon = S.SpiritBomb:IsAvailable() and TotalSoulFragments >= VarSpBombThreshold
  -- variable,name=can_spbomb_one_gcd,op=setif,condition=talent.spirit_bomb,value=(soul_fragments.total+variable.num_spawnable_souls)>=variable.spbomb_threshold,value_else=0
  VarCanSpBombOneGCD = S.SpiritBomb:IsAvailable() and (TotalSoulFragments + VarNumSpawnableSouls) >= VarSpBombThreshold
  -- variable,name=spburst_threshold,op=setif,condition=talent.fiery_demise&dot.fiery_brand.ticking,value=(variable.single_target*5)+(variable.small_aoe*5)+(variable.big_aoe*4),value_else=(variable.single_target*5)+(variable.small_aoe*5)+(variable.big_aoe*4)
  -- Note: value and value_else are the same currently.
  --if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
    VarSpBurstThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 5) + (num(VarBigAoE) * 4)
  --else
    --VarSpBurstThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 5) + (num(VarBigAoE) * 4)
  --end
  -- variable,name=can_spburst,op=setif,condition=talent.spirit_bomb,value=soul_fragments>=variable.spburst_threshold,value_else=0
  VarCanSpBurst = S.SpiritBomb:IsAvailable() and SoulFragments >= VarSpBurstThreshold
  -- variable,name=can_spburst_soon,op=setif,condition=talent.spirit_bomb,value=soul_fragments.total>=variable.spburst_threshold,value_else=0
  VarCanSpBurstSoon = S.SpiritBomb:IsAvailable() and TotalSoulFragments >= VarSpBurstThreshold
  -- variable,name=can_spburst_one_gcd,op=setif,condition=talent.spirit_bomb,value=(soul_fragments.total+variable.num_spawnable_souls)>=variable.spburst_threshold,value_else=0
  VarCanSpBurstOneGCD = S.SpiritBomb:IsAvailable() and (TotalSoulFragments + VarNumSpawnableSouls) >= VarSpBurstThreshold
  -- variable,name=meta_prep_time,op=set,value=0
  VarMetaPrepTime = 0
  -- variable,name=meta_prep_time,op=add,value=action.fiery_brand.execute_time,if=talent.fiery_demise&cooldown.fiery_brand.up
  if S.FieryDemise:IsAvailable() and S.FieryBrand:CooldownUp() then
    VarMetaPrepTime = S.FieryBrand:ExecuteTime()
  end
  -- variable,name=meta_prep_time,op=add,value=action.sigil_of_flame.execute_time*action.sigil_of_flame.charges
  VarMetaPrepTime = VarMetaPrepTime + (S.SigilofFlame:ExecuteTime() * S.SigilofFlame:Charges())
  -- variable,name=dont_soul_cleave,op=setif,condition=buff.metamorphosis.up&buff.demonsurge_hardcast.up,
  if Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast") then
    -- value=buff.demonsurge_spirit_burst.up|(buff.metamorphosis.remains<(gcd.max*2)&(!((fury+variable.fel_dev_passive_fury_gen)>=120)|!(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4))),
    VarDontSoulCleave = Player:Demonsurge("SpiritBurst") or (Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCD() * 2) and (not ((Player:Fury() + VarFelDevPassiveFuryGen) >= 120) or not (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4)))
  else
    -- value_else=(cooldown.fel_devastation.remains<(gcd.max*3)&(!((fury+variable.fel_dev_passive_fury_gen)>=120)|!(variable.can_spburst|variable.can_spburst_soon|soul_fragments.total>=4)))
    VarDontSoulCleave = (S.FelDevastation:CooldownRemains() < (Player:GCD() * 3) and (not ((Player:Fury() + VarFelDevPassiveFuryGen) >= 120) or not (VarCanSpBurst or VarCanSpBurstSoon or TotalSoulFragments >= 4)))
  end
  -- variable,name=fiery_brand_back_before_meta,op=setif,condition=talent.down_in_flames,value=charges>=max_charges|(charges_fractional>=1&cooldown.fiery_brand.full_recharge_time<=gcd.remains+execute_time)|(charges_fractional>=1&((1-(charges_fractional-1))*cooldown.fiery_brand.duration)<=cooldown.metamorphosis.remains),value_else=cooldown.fiery_brand.duration<=cooldown.metamorphosis.remains
  if S.DowninFlames:IsAvailable() then
    VarFBBeforeMeta = S.FieryBrand:Charges() >= S.FieryBrand:MaxCharges() or (S.FieryBrand:ChargesFractional() >= 1 and S.FieryBrand:FullRechargeTime() <= Player:GCDRemains() + S.FieryBrand:ExecuteTime()) or (S.FieryBrand:ChargesFractional() >= 1 and ((1 - (S.FieryBrand:ChargesFractional() - 1)) * VarFieryBrandCD) <= S.Metamorphosis:CooldownRemains())
  else
    VarFBBeforeMeta = VarFieryBrandCD <= S.Metamorphosis:CooldownRemains()
  end
  -- variable,name=hold_sof_for_meta,op=setif,condition=talent.illuminated_sigils,
  if S.IlluminatedSigils:IsAvailable() then
    -- value=(charges_fractional>=1&((1-(charges_fractional-1))*cooldown.sigil_of_flame.duration)>cooldown.metamorphosis.remains),
    VarHoldSoFForMeta = S.SigilofFlame:ChargesFractional() >= 1 and ((1 - (S.SigilofFlame:ChargesFractional() - 1)) * VarSoFCD) > S.Metamorphosis:CooldownRemains()
  else
    -- value_else=cooldown.sigil_of_flame.duration>cooldown.metamorphosis.remains
    VarHoldSoFForMeta = VarSoFCD > S.Metamorphosis:CooldownRemains()
  end
  -- variable,name=hold_sof_for_fel_dev,op=setif,condition=talent.illuminated_sigils,
  if S.IlluminatedSigils:IsAvailable() then
    -- value=(charges_fractional>=1&((1-(charges_fractional-1))*cooldown.sigil_of_flame.duration)>cooldown.fel_devastation.remains),
    VarHoldSoFForFelDev = S.SigilofFlame:ChargesFractional() >= 1 and ((1 - (S.SigilofFlame:ChargesFractional() - 1)) * VarSoFCD) > S.FelDevastation:CooldownRemains()
  else
    -- value_else=cooldown.sigil_of_flame.duration>cooldown.fel_devastation.remains
    VarHoldSoFForFelDev = VarSoFCD > S.FelDevastation:CooldownRemains()
  end
  -- variable,name=hold_sof_for_student,op=setif,condition=talent.student_of_suffering,
  if S.StudentofSuffering:IsAvailable() then
    -- value=prev_gcd.1.sigil_of_flame|(buff.student_of_suffering.remains>(4-talent.quickened_sigils)),
    VarHoldSoFForStudent = Player:PrevGCD(1, S.SigilofFlame) or Player:BuffRemains(S.StudentofSufferingBuff) > (4 - num(S.QuickenedSigils:IsAvailable()))
  else
    -- value_else=0
    VarHoldSoFForStudent = 0
  end
  -- variable,name=hold_sof_for_dot,op=setif,condition=talent.ascending_flame,
  if S.AscendingFlame:IsAvailable() then
    -- value=0,
    VarHoldSoFForDot = 0
  else
    -- value_else=prev_gcd.1.sigil_of_flame|(dot.sigil_of_flame.remains>(4-talent.quickened_sigils))
    VarHoldSoFForDot = Player:PrevGCD(1, S.SigilofFlame) or Target:DebuffRemains(S.SigilofFlameDebuff) > (4 - num(S.QuickenedSigils:IsAvailable()))
  end
  -- variable,name=hold_sof_for_precombat,value=(talent.illuminated_sigils&time<(2-talent.quickened_sigils))
  -- Note (Jom): Added an extra second (2sec->3sec) to the timing here to account for any hiccups in determing if precombat has ended. Important not to double-cast SoF.
  VarHoldSoFForPrecombat = S.IlluminatedSigils:IsAvailable() and HL.CombatTime() < (3 - num(S.QuickenedSigils:IsAvailable()))
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs|(variable.trinket_1_buffs&((buff.metamorphosis.up&buff.demonsurge_hardcast.up)|(buff.metamorphosis.up&!buff.demonsurge_hardcast.up&cooldown.metamorphosis.remains<10)|(cooldown.metamorphosis.remains>trinket.1.cooldown.duration)|(variable.trinket_2_buffs&trinket.2.cooldown.remains<cooldown.metamorphosis.remains)))
    if Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs or (VarTrinket1Buffs and ((Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast")) or (Player:BuffUp(S.MetamorphosisBuff) and not Player:Demonsurge("Hardcast") and S.Metamorphosis:CooldownRemains() < 10) or (S.Metamorphosis:CooldownRemains() > VarTrinket1CD) or (VarTrinket2Buffs and VarTrinket2CD < S.Metamorphosis:CooldownRemains())))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for FS trinket1 (" .. Trinket1:Name() .. ")"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_1_buffs|(variable.trinket_1_buffs&((buff.metamorphosis.up&buff.demonsurge_hardcast.up)|(buff.metamorphosis.up&!buff.demonsurge_hardcast.up&cooldown.metamorphosis.remains<10)|(cooldown.metamorphosis.remains>trinket.1.cooldown.duration)|(variable.trinket_2_buffs&trinket.2.cooldown.remains<cooldown.metamorphosis.remains)))
    if Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs or (VarTrinket2Buffs and ((Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast")) or (Player:BuffUp(S.MetamorphosisBuff) and not Player:Demonsurge("Hardcast") and S.Metamorphosis:CooldownRemains() < 10) or (S.Metamorphosis:CooldownRemains() > VarTrinket2CD) or (VarTrinket1Buffs and VarTrinket1CD < S.Metamorphosis:CooldownRemains())))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for FS trinket2 (" .. Trinket2:Name() .. ")"; end
    end
  end
  -- immolation_aura,if=time<4
  if ImmoAbility:IsCastable() and (HL.CombatTime() < 4) then
    if Cast(ImmoAbility) then return "immolation_aura fs 1"; end
  end
  -- immolation_aura,if=!(cooldown.metamorphosis.up&prev_gcd.1.sigil_of_flame)&!(talent.fallout&talent.spirit_bomb&spell_targets.spirit_bomb>=3&((buff.metamorphosis.up&(variable.can_spburst|variable.can_spburst_soon))|(!buff.metamorphosis.up&(variable.can_spbomb|variable.can_spbomb_soon))))&!(buff.metamorphosis.up&buff.demonsurge_hardcast.up)
  if ImmoAbility:IsCastable() and (not (S.Metamorphosis:CooldownUp() and Player:PrevGCD(1, S.SigilofFlame)) and not (S.Fallout:IsAvailable() and S.SpiritBomb:IsAvailable() and EnemiesCount8yMelee >= 3 and (Player:BuffUp(S.MetamorphosisBuff) and (VarCanSpBurst or VarCanSpBurstSoon)) or (not Player:BuffUp(S.MetamorphosisBuff) and (VarCanSpBomb or VarCanSpBombSoon)))) and not (Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast")) then
    if Cast(ImmoAbility) then return "immolation_aura fs 2"; end
  end
  -- sigil_of_flame,if=!talent.student_of_suffering&!variable.hold_sof_for_dot&!variable.hold_sof_for_precombat
  if S.SigilofFlame:IsCastable() and (not S.StudentofSuffering:IsAvailable() and not VarHoldSoFForDot and not VarHoldSoFForPrecombat) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fs 3"; end
  end
  -- sigil_of_flame,if=!variable.hold_sof_for_precombat&(charges=max_charges|(!variable.hold_sof_for_student&!variable.hold_sof_for_dot&!variable.hold_sof_for_meta&!variable.hold_sof_for_fel_dev))
  if S.SigilofFlame:IsCastable() and (not VarHoldSoFForPrecombat and (S.SigilofFlame:Charges() == S.SigilofFlame:MaxCharges() or (not VarHoldSoFForStudent and not VarHoldSoFForDot and not VarHoldSoFForMeta and not VarHoldSoFForFelDev))) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fs 4"; end
  end
  -- fiery_brand,if=active_dot.fiery_brand=0&(!talent.fiery_demise|((talent.down_in_flames&charges>=max_charges)|variable.fiery_brand_back_before_meta))
  if S.FieryBrand:IsCastable() and (S.FieryBrandDebuff:AuraActiveCount() == 0 and (not S.FieryDemise:IsAvailable() or (S.DowninFlames:IsAvailable() and S.FieryBrand:Charges() >= S.FieryBrand:MaxCharges()) or VarFBBeforeMeta)) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.FieryBrand, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fs 5"; end
  end
  -- call_action_list,name=fs_execute,if=fight_remains<20
  if (FightRemains < 20 or BossFightRemains < 20) then
    local ShouldReturn = FSExecute(); if ShouldReturn then return ShouldReturn; end
  end
    -- run_action_list,name=metamorphosis,if=buff.metamorphosis.up&buff.demonsurge_hardcast.up
  if Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast") then
    local ShouldReturn = Metamorphosis(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Metamorphosis()"; end
  end
  -- run_action_list,name=fel_dev,if=buff.metamorphosis.up&!buff.demonsurge_hardcast.up&!buff.metamorphosis.duration>=8&(buff.demonsurge_soul_sunder.up|buff.demonsurge_spirit_burst.up)
  if Player:BuffUp(S.MetamorphosisBuff) and not Player:Demonsurge("Hardcast") and Player:BuffRemains(S.MetamorphosisBuff) < 8 and (Player:Demonsurge("SoulSunder") or Player:Demonsurge("SpiritBurst")) then
    local ShouldReturn = FelDev(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FelDev()"; end
  end
  -- run_action_list,name=fel_dev_prep,if=!buff.demonsurge_hardcast.up&(cooldown.fel_devastation.up|(cooldown.fel_devastation.remains<=(gcd.max*3)))
  if not Player:Demonsurge("Hardcast") and (S.FelDevastation:CooldownUp() or (S.FelDevastation:CooldownRemains() <= (Player:GCD() * 3))) then
    local ShouldReturn = FelDevPrep(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FelDevPrep()"; end
  end
  -- run_action_list,name=meta_prep,if=(cooldown.metamorphosis.remains<=variable.meta_prep_time)&!cooldown.fel_devastation.up&!cooldown.fel_devastation.remains<10&!buff.demonsurge_soul_sunder.up&!buff.demonsurge_spirit_burst.up
  if (S.Metamorphosis:CooldownRemains() <= VarMetaPrepTime) and S.FelDevastation:CooldownDown() and S.FelDevastation:CooldownRemains() >= 10 and not Player:Demonsurge("SoulSunder") and not Player:Demonsurge("SpiritBurst") then
    local ShouldReturn = MetaPrep(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for MetaPrep()"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Settings.Vengeance.TheHuntAnnotateIcon then
      if CastAnnotated(S.TheHunt, false, "The Hunt") then return "the_hunt (Icon Bugfix) fs 8"; end
    else
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt fs 8"; end
    end
  end
  -- felblade,if=((cooldown.sigil_of_spite.remains<execute_time|cooldown.soul_carver.remains<execute_time)&cooldown.fel_devastation.remains<(execute_time+gcd.max)&fury<50)
  if S.Felblade:IsCastable() and ((S.SigilofSpite:CooldownRemains() < S.Felblade:ExecuteTime() or S.SoulCarver:CooldownRemains() < S.Felblade:ExecuteTime()) and S.FelDevastation:CooldownRemains() < (S.Felblade:ExecuteTime() + Player:GCD()) and Player:Fury() < 50) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 10"; end
  end
  -- soul_carver,if=(!talent.fiery_demise|talent.fiery_demise&dot.fiery_brand.ticking)&((!talent.spirit_bomb|variable.single_target)|(talent.spirit_bomb&!prev_gcd.1.sigil_of_spite&((soul_fragments.total+3<=5&fury>=40)|(soul_fragments.total=0&fury>=15))))
  if S.SoulCarver:IsCastable() and ((not S.FieryDemise:IsAvailable() or S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0) and ((not S.SpiritBomb:IsAvailable() or VarST) or (S.SpiritBomb:IsAvailable() and not Player:PrevGCD(1, S.SigilofSpite) and ((TotalSoulFragments == 0 and Player:Fury() >= 40) or (TotalSoulFragments + 3 <= 4 and Player:Fury() >= 15))))) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fs 12"; end
  end
  -- sigil_of_spite,if=(!talent.cycle_of_binding|(cooldown.sigil_of_spite.duration<(cooldown.metamorphosis.remains+18)))&(!talent.spirit_bomb|(fury>=80&(variable.can_spbomb|variable.can_spbomb_soon))|(soul_fragments.total<=(2-talent.soul_sigils.rank)))
  if S.SigilofSpite:IsCastable() and ((not S.CycleofBinding:IsAvailable() or (60 < (S.Metamorphosis:CooldownRemains() + 18))) and (not S.SpiritBomb:IsAvailable() or (Player:Fury() >= 80 and (VarCanSpBomb or VarCanSpBombSoon)) or (TotalSoulFragments <= (2 - S.SoulSigils:TalentRank())))) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fs 14"; end
  end
  -- spirit_burst,if=variable.can_spburst&talent.fiery_demise&dot.fiery_brand.ticking&!(cooldown.fel_devastation.remains<(gcd.max*3))
  if S.SpiritBurst:IsReady() and (VarCanSpBurst and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 and not (S.FelDevastation:CooldownRemains() < (Player:GCD() * 3))) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_burst fs 16"; end
  end
  -- spirit_bomb,if=variable.can_spbomb&talent.fiery_demise&dot.fiery_brand.ticking&!(cooldown.fel_devastation.remains<(gcd.max*3))
  if S.SpiritBomb:IsReady() and (VarCanSpBomb and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 and not (S.FelDevastation:CooldownRemains() < (Player:GCD() * 3))) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_bomb fs 18"; end
  end
  -- soul_sunder,if=variable.single_target&!variable.dont_soul_cleave
  if S.SoulSunder:IsReady() and (VarST and not VarDontSoulCleave) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder fs 16"; end
  end
  -- soul_cleave,if=variable.single_target&!variable.dont_soul_cleave
  if S.SoulCleave:IsReady() and (VarST and not VarDontSoulCleave) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave fs 18"; end
  end
  -- Manually added: wait,if=!variable.can_spburst&soul_fragments.total>=variable.spburst_threshold
  if S.SpiritBurst:IsReady() and (not VarCanSpBurst and TotalSoulFragments >= VarSpBurstThreshold and SoulFragments < 5) and (Player:GCDRemains() < (Player:GCD() * 0.5)) then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Soul Fragments (Spirit Burst)"; end
  end
  -- spirit_burst,if=variable.can_spburst&!cooldown.fel_devastation.remains<(gcd.max*3)
  if S.SpiritBurst:IsReady() and (VarCanSpBurst and not (S.FelDevastation:CooldownRemains() < (Player:GCD() * 3))) then
    if Cast(S.SpiritBurst, nil, nil, not IsInAoERange) then return "spirit_burst fs 20"; end
  end
  -- Manually added: wait,if=!variable.can_spb&soul_fragments.total>=variable.spbomb_threshold
  if not VarCanSpB and (TotalSoulFragments >= VarSpBombThreshold and SoulFragments < 5) and (Player:GCDRemains() < (Player:GCD() * 0.5)) then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Soul Fragments (Spirit Bomb)"; end
  end
  -- spirit_bomb,if=variable.can_spbomb&!cooldown.fel_devastation.remains<(gcd.max*3)
  if S.SpiritBomb:IsReady() and (VarCanSpBomb and not (S.FelDevastation:CooldownRemains() < (Player:GCD() * 3))) then
    if Cast(S.SpiritBomb, nil, nil, not IsInAoERange) then return "spirit_bomb fs 22"; end
  end
  -- felblade,if=((fury<40&((buff.metamorphosis.up&(variable.can_spburst|variable.can_spburst_soon))|(!buff.metamorphosis.up&(variable.can_spbomb|variable.can_spbomb_soon)))))
  if S.Felblade:IsCastable() and (Player:Fury() < 40 and ((Player:BuffUp(S.MetamorphosisBuff) and (VarCanSpBurst or VarCanSpBurstSoon)) or (Player:BuffDown(S.MetamorphosisBuff) and (VarCanSpBomb or VarCanSpBombSoon)))) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 28"; end
  end
  -- fracture,if=((fury<40&((buff.metamorphosis.up&(variable.can_spburst|variable.can_spburst_soon))|(!buff.metamorphosis.up&(variable.can_spbomb|variable.can_spbomb_soon))))|(buff.metamorphosis.up&variable.can_spburst_one_gcd)|(!buff.metamorphosis.up&variable.can_spbomb_one_gcd))
  if S.Fracture:IsCastable() and ((Player:Fury() < 40 and ((Player:BuffUp(S.MetamorphosisBuff) and (VarCanSpBurst or VarCanSpBurstSoon)) or (Player:BuffDown(S.MetamorphosisBuff) and (VarCanSpBomb or VarCanSpBombSoon)))) or (Player:BuffUp(S.MetamorphosisBuff) and VarCanSpBurstOneGCD) or (Player:BuffDown(S.MetamorphosisBuff) and VarCanSpBombOneGCD)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fs 30"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 36"; end
  end
  -- soul_sunder,if=!variable.dont_soul_cleave
  -- soul_cleave,if=!variable.dont_soul_cleave
  if not VarDontSoulCleave then
    if S.SoulSunder:IsReady() then
      if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder fs 32"; end
    end
    if S.SoulCleave:IsReady() then
      if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave fs 34"; end
    end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fs 38"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear fs 40"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fs 42"; end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8)
  if (AoEON()) then
    EnemiesCount8yMelee = #Enemies8yMelee
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

    -- Variables from Precombat
    -- variable,name=single_target,value=spell_targets.spirit_bomb=1
    VarST = EnemiesCount8yMelee == 1
    -- variable,name=small_aoe,value=spell_targets.spirit_bomb>=2&spell_targets.spirit_bomb<=5
    VarSmallAoE = EnemiesCount8yMelee >= 2 and EnemiesCount8yMelee <= 5
    -- variable,name=big_aoe,value=spell_targets.spirit_bomb>=6
    VarBigAoE = EnemiesCount8yMelee >= 6

    -- ImmolationAura or ConsumingFire?
    ImmoAbility = S.ConsumingFire:IsLearned() and S.ConsumingFire or S.ImmolationAura
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=num_spawnable_souls,op=reset,default=0
    VarNumSpawnableSouls = 0
    -- variable,name=num_spawnable_souls,op=max,value=1,if=talent.soul_sigils&cooldown.sigil_of_flame.up
    if S.SoulSigils:IsAvailable() and S.SigilofFlame:CooldownUp() then
      VarNumSpawnableSouls = mathmax(VarNumSpawnableSouls, 1)
    end
    -- variable,name=num_spawnable_souls,op=max,value=2,if=talent.fracture&cooldown.fracture.charges_fractional>=1&!buff.metamorphosis.up
    if S.Fracture:IsAvailable() and S.Fracture:ChargesFractional() >= 1 and Player:BuffDown(S.MetamorphosisBuff) then
      VarNumSpawnableSouls = 2
    end
    -- variable,name=num_spawnable_souls,op=max,value=3,if=talent.fracture&cooldown.fracture.charges_fractional>=1&buff.metamorphosis.up
    if S.Fracture:IsAvailable() and S.Fracture:ChargesFractional() >= 1 and Player:BuffUp(S.MetamorphosisBuff) then
      VarNumSpawnableSouls = 3
    end
    -- variable,name=num_spawnable_souls,op=add,value=1,if=talent.soul_carver&(cooldown.soul_carver.remains>(cooldown.soul_carver.duration-3))
    if S.SoulCarver:IsAvailable() and S.SoulCarver:CooldownRemains() > 57 then
      VarNumSpawnableSouls = VarNumSpawnableSouls + 1
    end
    -- auto_attack
    -- disrupt,if=target.debuff.casting.react (Interrupts)
    local ShouldReturn = Everyone.Interrupt(S.Disrupt, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
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
    -- run_action_list,name=ar,if=hero_tree.aldrachi_reaver
    if Player:HeroTreeID() == 35 then
      local ShouldReturn = AR(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AR()"; end
    end
    -- run_action_list,name=fs,if=hero_tree.felscarred
    if Player:HeroTreeID() == 34 then
      local ShouldReturn = FS(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FS()"; end
    end
    -- Manually added: run_action_list,name=ar,if=!hero_tree.aldrachi_reaver&!hero_tree.felscarred
    -- Note: This is just to handle sub-level 71 players. Might find a better way to optimize this?
    if Player:HeroTreeID() ~= 34 and Player:HeroTreeID() ~= 35 then
      if S.FelDevastation:IsReady() then
        if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation low_level 2"; end
      end
      local ShouldReturn = AR(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AR() (Low Level)"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FieryBrandDebuff:RegisterAuraTracking()
  S.SigilofFlameDebuff:RegisterAuraTracking()

  HR.Print("Vengeance Demon Hunter rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(581, APL, Init)

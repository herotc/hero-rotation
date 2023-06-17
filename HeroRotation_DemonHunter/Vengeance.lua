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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Vengeance
local I = Item.DemonHunter.Vengeance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.DragonfireBombDispenser:ID(),
  I.ElementiumPocketAnvil:ID(),
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
local BossFightRemains = 11111
local FightRemains = 11111
-- Vars to calculate SpB Fragments generated
local VarSpiritBombFragmentsInMeta = (S.Fracture:IsAvailable()) and 3 or 4
local VarSpiritBombFragmentsNotInMeta = (S.Fracture:IsAvailable()) and 4 or 5
local VarSpiritBombFragments = 0
-- Vars for Frailty checks
local VarVulnFrailtyStack = (S.Vulnerability:IsAvailable()) and 1 or 0
local VarCDFrailtyReqAoE = (S.SoulCrush:IsAvailable()) and 5 * VarVulnFrailtyStack or VarVulnFrailtyStack
local VarCDFrailtyReqST = (S.SoulCrush:IsAvailable()) and 6 * VarVulnFrailtyStack or VarVulnFrailtyStack
local VarCDFrailtyReq = 0
-- Vars for Conditional checks
local VarHuntOnCD = false
local VarEDOnCD = false
local VarSCOnCD = false
local VarFelDevOnCD = false
local VarFDFBTicking = false
local VarFDFBNotTicking = false
local VarFDFBTickingAny = false
local VarFDFBNotTickingAny = false

HL:RegisterForEvent(function()
  VarSpiritBombFragmentsInMeta = (S.Fracture:IsAvailable()) and 3 or 4
  VarSpiritBombFragmentsNotInMeta = (S.Fracture:IsAvailable()) and 4 or 5
  VarVulnFrailtyStack = (S.Vulnerability:IsAvailable()) and 1 or 0
  VarCDFrailtyReqAoE = (S.SoulCrush:IsAvailable()) and 5 * VarVulnFrailtyStack or VarVulnFrailtyStack
  VarCDFrailtyReqST = (S.SoulCrush:IsAvailable()) and 6 * VarVulnFrailtyStack or VarVulnFrailtyStack
end, "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

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

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- variable,name=spirit_bomb_soul_fragments_not_in_meta,op=setif,value=4,value_else=5,condition=talent.fracture
  -- variable,name=spirit_bomb_soul_fragments_in_meta,op=setif,value=3,value_else=4,condition=talent.fracture
  -- variable,name=vulnerability_frailty_stack,op=setif,value=1,value_else=0,condition=talent.vulnerability
  -- variable,name=cooldown_frailty_requirement_st,op=setif,value=6*variable.vulnerability_frailty_stack,value_else=variable.vulnerability_frailty_stack,condition=talent.soulcrush
  -- variable,name=cooldown_frailty_requirement_aoe,op=setif,value=5*variable.vulnerability_frailty_stack,value_else=variable.vulnerability_frailty_stack,condition=talent.soulcrush
  -- Note: Handling variable resets via PLAYER_EQUIPMENT_CHANGED/SPELLS_CHANGED/LEARNED_SPELL_IN_TAB registrations
  -- snapshot_stats
  -- sigil_of_flame
  if (not S.ConcentratedSigils:IsAvailable()) and S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame precombat 2"; end
  end
  -- immolation_aura,if=active_enemies=1|!talent.fallout
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
    -- demon_spikes,use_off_gcd=1,if=!buff.demon_spikes.up&!cooldown.pause_action.remainsif=!buff.demon_spikes.up&!cooldown.pause_action.remains
    -- Note: Handled via Defensives()
    -- metamorphosis
    -- Note: Keeping Metamorphosis buff check to avoid Demonic overlap
    if S.Metamorphosis:IsCastable() and Settings.Vengeance.UseMetaOffensively and (Player:BuffDown(S.MetamorphosisBuff)) then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis main 4"; end
    end
    -- fel_devastation,if=!talent.fiery_demise.enabled
    if S.FelDevastation:IsReady() and (not S.FieryDemise:IsAvailable()) then
      if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation main 6"; end
    end
    -- fiery_brand,if=!talent.fiery_demise.enabled&!dot.fiery_brand.ticking
    if S.FieryBrand:IsCastable() and Settings.Vengeance.UseFieryBrandOffensively and ((not S.FieryDemise:IsAvailable()) and Target:DebuffDown(S.FieryBrandDebuff)) then
      if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand main 8"; end
    end
    -- bulk_extraction
    if S.BulkExtraction:IsCastable() then
      if Cast(S.BulkExtraction, nil, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction main 10"; end
    end
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 12"; end
      end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1,if=fight_remains<20|charges=3
      if I.DragonfireBombDispenser:IsEquipped() then
        local DBDSpell = I.DragonfireBombDispenser:OnUseSpell()
        local DBDCharges = DBDSpell:Charges()
        if I.DragonfireBombDispenser:IsReady() and (FightRemains < 20 or DBDCharges == 3) then
          if Cast(I.DragonfireBombDispenser, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser main 14"; end
        end
      end
      -- use_item,name=elementium_pocket_anvil,use_off_gcd=1
      if I.ElementiumPocketAnvil:IsEquippedAndReady() then
        if Cast(I.ElementiumPocketAnvil, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(100)) then return "elementium_pocket_anvil main 16"; end
      end
      -- use_item,slot=trinket1
      local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
      if Trinket1ToUse then
        if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 main 18"; end
      end
      -- use_item,slot=trinket2
      local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
      if Trinket2ToUse then
        if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 main 20"; end
      end
    end
    -- variable,name=the_hunt_on_cooldown,value=talent.the_hunt&cooldown.the_hunt.remains|!talent.the_hunt
    VarHuntOnCD = (S.TheHunt:IsAvailable() and S.TheHunt:CooldownDown() or not S.TheHunt:IsAvailable())
    -- variable,name=elysian_decree_on_cooldown,value=talent.elysian_decree&cooldown.elysian_decree.remains|!talent.elysian_decree
    VarEDOnCD = (S.ElysianDecree:IsAvailable() and S.ElysianDecree:CooldownDown() or not S.ElysianDecree:IsAvailable())
    -- variable,name=soul_carver_on_cooldown,value=talent.soul_carver&cooldown.soul_carver.remains|!talent.soul_carver
    VarSCOnCD = (S.SoulCarver:IsAvailable() and S.SoulCarver:CooldownDown() or not S.SoulCarver:IsAvailable())
    -- variable,name=fel_devastation_on_cooldown,value=talent.fel_devastation&cooldown.fel_devastation.remains|!talent.fel_devastation
    VarFelDevOnCD = (S.FelDevastation:IsAvailable() and S.FelDevastation:CooldownDown() or not S.FelDevastation:IsAvailable())
    -- variable,name=fiery_demise_fiery_brand_is_ticking_on_current_target,value=talent.fiery_brand&talent.fiery_demise&dot.fiery_brand.ticking
    VarFDFBTicking = (S.FieryBrand:IsAvailable() and S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff))
    -- variable,name=fiery_demise_fiery_brand_is_not_ticking_on_current_target,value=talent.fiery_brand&((talent.fiery_demise&!dot.fiery_brand.ticking)|!talent.fiery_demise)
    VarFDFBNotTicking = (S.FieryBrand:IsAvailable() and ((S.FieryDemise:IsAvailable() and Target:DebuffDown(S.FieryBrandDebuff)) or not S.FieryDemise:IsAvailable()))
    -- variable,name=fiery_demise_fiery_brand_is_ticking_on_any_target,value=talent.fiery_brand&talent.fiery_demise&active_dot.fiery_brand_dot
    VarFDFBTickingAny = (S.FieryBrand:IsAvailable() and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0)
    -- variable,name=fiery_demise_fiery_brand_is_not_ticking_on_any_target,value=talent.fiery_brand&((talent.fiery_demise&!active_dot.fiery_brand_dot)|!talent.fiery_demise)
    VarFDFBNotTickingAny = (S.FieryBrand:IsAvailable() and ((S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() == 0) or not S.FieryDemise:IsAvailable()))
    -- variable,name=spirit_bomb_soul_fragments,op=setif,value=variable.spirit_bomb_soul_fragments_in_meta,value_else=variable.spirit_bomb_soul_fragments_not_in_meta,condition=buff.metamorphosis.up
    VarSpiritBombFragments = (Player:BuffUp(S.MetamorphosisBuff)) and VarSpiritBombFragmentsInMeta or VarSpiritBombFragmentsNotInMeta
    -- variable,name=cooldown_frailty_requirement,op=setif,value=variable.cooldown_frailty_requirement_aoe,value_else=variable.cooldown_frailty_requirement_st,condition=talent.spirit_bomb&(spell_targets.spirit_bomb>1|variable.fiery_demise_fiery_brand_is_ticking_on_any_target)
    VarCDFrailtyReq = (S.SpiritBomb:IsAvailable() and (EnemiesCount8yMelee > 1 or VarFDFBTickingAny)) and VarCDFrailtyReqAoE or VarCDFrailtyReqST
    -- the_hunt,if=variable.fiery_demise_fiery_brand_is_not_ticking_on_current_target&debuff.frailty.stack>=variable.cooldown_frailty_requirement
    if S.TheHunt:IsCastable() and (VarFDFBNotTicking and Target:DebuffStack(S.FrailtyDebuff) >= VarCDFrailtyReq) then
      if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt main 22"; end
    end
    -- elysian_decree,if=variable.fiery_demise_fiery_brand_is_not_ticking_on_current_target&debuff.frailty.stack>=variable.cooldown_frailty_requirement
    if S.ElysianDecree:IsCastable() and (VarFDFBNotTicking and Target:DebuffStack(S.FrailtyDebuff) >= VarCDFrailtyReq) then
      if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree main 24"; end
    end
    -- soul_carver,if=!talent.fiery_demise&soul_fragments<=3&debuff.frailty.stack>=variable.cooldown_frailty_requirement
    if S.SoulCarver:IsCastable() and ((not S.FieryDemise:IsAvailable()) and SoulFragments <= 3 and Target:DebuffStack(S.FrailtyDebuff) >= VarCDFrailtyReq) then
      if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver main 26"; end
    end
    -- soul_carver,if=variable.fiery_demise_fiery_brand_is_ticking_on_current_target&soul_fragments<=3&debuff.frailty.stack>=variable.cooldown_frailty_requirement
    -- Note: Removing Frailty stack requirement for now, as we rarely hit enough stacks during FB while saving Fury for FelDevastation.
    if S.SoulCarver:IsCastable() and (VarFDFBTicking and SoulFragments <= 3) then
      if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver main 28"; end
    end
    -- fel_devastation,if=variable.fiery_demise_fiery_brand_is_ticking_on_current_target&dot.fiery_brand.remains<3
    if S.FelDevastation:IsReady() and (VarFDFBTicking and Target:DebuffRemains(S.FieryBrandDebuff) < 3) then
      if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(13)) then return "fel_devastation main 30"; end
    end
    -- fiery_brand,if=variable.fiery_demise_fiery_brand_is_not_ticking_on_any_target&variable.the_hunt_on_cooldown&variable.elysian_decree_on_cooldown&((talent.soul_carver&(cooldown.soul_carver.up|cooldown.soul_carver.remains<10))|(talent.fel_devastation&(cooldown.fel_devastation.up|cooldown.fel_devastation.remains<10)))
    if S.FieryBrand:IsCastable() and (VarFDFBNotTickingAny and VarHuntOnCD and VarEDOnCD and ((S.SoulCarver:IsAvailable() and (S.SoulCarver:CooldownUp() or S.SoulCarver:CooldownRemains() < 10)) or (S.FelDevastation:IsAvailable() and (S.FelDevastation:CooldownUp() or S.FelDevastation:CooldownRemains() < 10)))) then
      if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsInRange(30)) then return "fiery_brand main 32"; end
    end
    -- immolation_aura,if=talent.fiery_demise&variable.fiery_demise_fiery_brand_is_ticking_on_any_target
    if S.ImmolationAura:IsCastable() and (S.FieryDemise:IsAvailable() and VarFDFBTickingAny) then
      if Cast(S.ImmolationAura) then return "immolation_aura main 34"; end
    end
    -- sigil_of_flame,if=talent.fiery_demise&variable.fiery_demise_fiery_brand_is_ticking_on_any_target
    if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) and (S.FieryDemise:IsAvailable() and VarFDFBTickingAny) then
      if S.ConcentratedSigils:IsAvailable() then
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame main 36 (Concentrated)"; end
      else
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 36 (Normal)"; end
      end
    end
    -- spirit_bomb,if=soul_fragments>=variable.spirit_bomb_soul_fragments&(spell_targets>1|variable.fiery_demise_fiery_brand_is_ticking_on_any_target)
    -- Note: Adding Fury buffer to ensure we can always use FelDevastation when we should
    if S.SpiritBomb:IsReady() and (VarFDFBTickingAny and (Player:Fury() > S.FelDevastation:Cost() + 40 or Target:DebuffRemains(S.FieryBrandDebuff) > 3 + 2 * Player:GCD()) or VarFDFBNotTickingAny or (not S.FelDevastation:IsAvailable()) or S.FelDevastation:CooldownRemains() > Target:DebuffRemains(S.FieryBrandDebuff)) and (SoulFragments >= VarSpiritBombFragments and (EnemiesCount8yMelee > 1 or VarFDFBTickingAny)) then
      if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb main 38"; end
    end
    -- soul_cleave,if=(soul_fragments<=1&spell_targets>1)|spell_targets=1
    -- Note: Adding Fury buffer to ensure we can always use FelDevastation when we should
    if S.SoulCleave:IsReady() and (VarFDFBTickingAny and (Player:Fury() > S.FelDevastation:Cost() + 30 or Target:DebuffRemains(S.FieryBrandDebuff) > 3 + 2 * Player:GCD()) or VarFDFBNotTickingAny or (not S.FelDevastation:IsAvailable()) or S.FelDevastation:CooldownRemains() > Target:DebuffRemains(S.FieryBrandDebuff)) and ((SoulFragments <= 1 and EnemiesCount8yMelee > 1) or EnemiesCount8yMelee == 1) then
      if Cast(S.SoulCleave, nil, nil, not Target:IsInMeleeRange(8)) then return "soul_cleave main 40"; end
    end
    -- sigil_of_flame
    if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) then
      if S.ConcentratedSigils:IsAvailable() then
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame main 42 (Concentrated)"; end
      else
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 42 (Normal)"; end
      end
    end
    -- immolation_aura
    if S.ImmolationAura:IsCastable() then
      if Cast(S.ImmolationAura) then return "immolation_aura main 44"; end
    end
    -- fracture
    if S.Fracture:IsCastable() and IsInMeleeRange then
      if Cast(S.Fracture) then return "fracture main 46"; end
    end
    -- shear
    if S.Shear:IsCastable() and IsInMeleeRange then
      if Cast(S.Shear) then return "shear main 48"; end
    end
    -- throw_glaive
    if S.ThrowGlaive:IsCastable() then
      if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 50"; end
    end
    -- felblade
    if S.Felblade:IsCastable() then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 52"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FieryBrandDebuff:RegisterAuraTracking()

  HR.Print("Vengeance DH rotation is currently a work in progress, but has been updated for patch 10.1.0.")
end

HR.SetAPL(581, APL, Init);

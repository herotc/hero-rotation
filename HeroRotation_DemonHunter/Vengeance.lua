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
local CastAnnotated = HR.CastAnnotated
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
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
local SoulFragments, LastSoulFragmentAdjustment
local SoulFragmentsAdjusted = 0
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarRampHDone
local VarRampEDDone
local VarRampSCDone
local VarFDDone

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
  if S.FieryBrand:IsCastable() and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
end

local function RampH()
  -- fracture,if=fury.deficit>=30&debuff.frailty.stack<=5
  if S.Fracture:IsCastable() and (Player:FuryDeficit() >= 30 and Target:DebuffStack(S.FrailtyDebuff) <= 5) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ramph 2"; end
  end
  -- sigil_of_flame,if=fury.deficit>=30
  if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) and (Player:FuryDeficit() >= 30) then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame ramph 4 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame ramph 4 (Normal)"; end
    end
  end
  -- shear,if=fury.deficit<=90
  if S.Shear:IsCastable() and (Player:FuryDeficit() <= 90) then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear ramph 6"; end
  end
  -- spirit_bomb,if=soul_fragments>=4&active_enemies>1
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4 and EnemiesCount8yMelee > 1) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb ramph 8"; end
  end
  -- soul_cleave,if=(soul_fragments=0&active_enemies>1)|(active_enemies<2)|debuff.frailty.stack>=0
  if S.SoulCleave:IsReady() and ((SoulFragments == 0 and EnemiesCount8yMelee > 1) or EnemiesCount8yMelee < 2 or Target:DebuffStack(S.FrailtyDebuff) >= 0) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ramph 10"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, nil, not Target:IsInRange(50)) then return "the_hunt ramph 12"; end
  end
  -- variable,name=rampH_done,op=setif,value=1,value_else=0,condition=talent.the_hunt.enabled&cooldown.the_hunt.remains
  -- Handled via APL variable settings
end

local function RampED()
  -- fracture,if=fury.deficit>=30
  -- Manually added: &debuff.frailty.stack<=5 (otherwise, will continually loop Fracture and SpiritBomb/SoulCleave)
  if S.Fracture:IsCastable() and (Player:FuryDeficit() >= 30 and Target:DebuffStack(S.FrailtyDebuff) <= 5) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ramped 2"; end
  end
  -- sigil_of_flame,if=fury.deficit>=30
  if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) and (Player:FuryDeficit() >= 30) then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame ramped 4 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame ramped 4 (Normal)"; end
    end
  end
  -- shear,if=fury.deficit<=90&debuff.frailty.stack>=0
  if S.Shear:IsCastable() and (Player:FuryDeficit() <= 90 and Target:DebuffStack(S.FrailtyDebuff) >= 0) then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear ramped 6"; end
  end
  -- spirit_bomb,if=soul_fragments>=4&active_enemies>1
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4 and EnemiesCount8yMelee > 1) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb ramped 8"; end
  end
  -- soul_cleave,if=(soul_fragments=0&active_enemies>1)|(active_enemies<2)|debuff.frailty.stack>=0
  if S.SoulCleave:IsReady() and ((SoulFragments == 0 and EnemiesCount8yMelee > 1) or EnemiesCount8yMelee < 2 or Target:DebuffStack(S.FrailtyDebuff) >= 0) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ramped 10"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, nil, not Target:IsInRange(30)) then return "elysian_decree ramped 12"; end
  end
  -- variable,name=rampED_done,op=setif,value=1,value_else=0,condition=talent.elysian_decree.enabled&cooldown.elysian_decree.remains
  -- Handled via APL variable settings
end

local function RampSC()
  -- fracture,if=fury.deficit>=30
  -- Manually added: &debuff.frailty.stack<=5 (otherwise, will continually loop Fracture and SpiritBomb/SoulCleave)
  if S.Fracture:IsCastable() and (Player:FuryDeficit() >= 30 and Target:DebuffStack(S.FrailtyDebuff) <= 5) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rampsc 2"; end
  end
  -- sigil_of_flame,if=fury.deficit>=30
  if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) and (Player:FuryDeficit() >= 30) then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame rampsc 4 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame rampsc 4 (Normal)"; end
    end
  end
  -- shear,if=fury.deficit<=90&debuff.frailty.stack>=0
  if S.Shear:IsCastable() and (Player:FuryDeficit() <= 90 and Target:DebuffStack(S.FrailtyDebuff) >= 0) then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear rampsc 6"; end
  end
  -- spirit_bomb,if=soul_fragments>=4&active_enemies>1
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4 and EnemiesCount8yMelee > 1) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb rampsc 8"; end
  end
  -- soul_cleave,if=(soul_fragments=0&active_enemies>1)|(active_enemies<2)|debuff.frailty.stack>=0
  if S.SoulCleave:IsReady() and ((SoulFragments == 0 and EnemiesCount8yMelee > 1) or EnemiesCount8yMelee < 2 or Target:DebuffStack(S.FrailtyDebuff) >= 0) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave rampsc 10"; end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver rampsc 12"; end
  end
  -- variable,name=rampSC_done,op=setif,value=1,value_else=0,condition=talent.soul_carver.enabled&cooldown.soul_carver.remains&!talent.fiery_demise.enabled
  -- Handled via APL variable settings
end

local function FD()
  -- variable setting moved to top of function
  -- Note: Tweaked as per discussion with APL creator
  -- variable,name=FD_done,op=setif,value=1,condition=talent.fiery_demise.enabled&(cooldown.soul_carver.down|!talent.soul_carver.enabled)&(cooldown.fiery_brand.down|talent.down_in_flames.enabled&cooldown.fiery_brand.charges_fractional<1.65)&cooldown.immolation_aura.down&cooldown.fel_devastation.down
  if (S.FieryDemise:IsAvailable() and (S.SoulCarver:CooldownDown() or not S.SoulCarver:IsAvailable()) and (S.FieryBrand:CooldownDown() or S.DowninFlames:IsAvailable() and S.FieryBrand:ChargesFractional() < 1.65) and S.ImmolationAura:CooldownDown() and S.FelDevastation:CooldownDown()) then
    VarFDDone = true
  end
  -- fracture,if=fury.deficit>=30&!dot.fiery_brand.ticking
  if S.Fracture:IsCastable() and (Player:FuryDeficit() >= 30 and Target:DebuffDown(S.FieryBrandDebuff)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fd 2"; end
  end
  -- fiery_brand,if=!dot.fiery_brand.ticking&fury>=30
  if S.FieryBrand:IsCastable() and (Target:DebuffDown(S.FieryBrandDebuff) and Player:Fury() >= 30) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fd 4"; end
  end
  -- fel_devastation,if=dot.fiery_brand.remains<=3
  if S.FelDevastation:IsReady() and (Target:DebuffRemains(S.FieryBrandDebuff) <= 3) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fd 6"; end
  end
  -- immolation_aura,if=dot.fiery_brand.ticking
  if S.ImmolationAura:IsCastable() and (Target:DebuffUp(S.FieryBrandDebuff)) then
    if Cast(S.ImmolationAura) then return "immolation_aura fd 8"; end
  end
  -- spirit_bomb,if=soul_fragments>=4&dot.fiery_brand.remains>=4
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4 and Target:DebuffRemains(S.FieryBrandDebuff) >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb fd 10"; end
  end
  -- soul_carver,if=soul_fragments<=3
  if S.SoulCarver:IsCastable() and (SoulFragments <= 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fd 12"; end
  end
  -- fracture,if=soul_fragments<=3&dot.fiery_brand.remains>=5|dot.fiery_brand.remains<=5&fury<50
  if S.Fracture:IsCastable() and (SoulFragments <= 3 and Target:DebuffRemains(S.FieryBrandDebuff) >= 5 or Target:DebuffRemains(S.FieryBrandDebuff) <= 5 and Player:Fury() < 50) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fd 14"; end
  end
  -- sigil_of_flame,if=dot.fiery_brand.remains<=3&fury<50
  if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) and (Target:DebuffRemains(S.FieryBrandDebuff) <= 3 and Player:Fury() < 50) then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame fd 16 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame fd 16 (Normal)"; end
    end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fd 18"; end
  end
  -- variable,name=FD_done,op=setif,value=1,value_else=0,condition=(talent.fiery_demise.enabled&cooldown.soul_carver.remains&cooldown.fiery_brand.remains&cooldown.immolation_aura.remains&cooldown.fel_devastation.remains)
  -- Moved to top of function so we exit as soon as CDs are used
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
    -- disrupt (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=rampH_done,value=0,op=setif,value_else=1,condition=talent.the_hunt.enabled&cooldown.the_hunt.remains<5
    VarRampHDone = (S.TheHunt:IsAvailable() and S.TheHunt:CooldownRemains() < 5) and 0 or 1
    -- variable,name=rampED_done,value=0,op=setif,value_else=1,condition=talent.elysian_decree.enabled&cooldown.elysian_decree.remains<5
    VarRampEDDone = (S.ElysianDecree:IsAvailable() and S.ElysianDecree:CooldownRemains() < 5) and 0 or 1
    -- variable,name=rampSC_done,value=0,op=setif,value_else=1,condition=talent.soul_carver.enabled&cooldown.soul_carver.remains<5&!talent.fiery_demise.enabled
    VarRampSCDone = (S.SoulCarver:IsAvailable() and S.SoulCarver:CooldownRemains() < 5 and not S.FieryDemise:IsAvailable()) and 0 or 1
    -- variable,name=FD_done,value=0,op=setif,value_else=1,condition=talent.fiery_demise.enabled&cooldown.soul_carver.up&cooldown.fiery_brand.up&cooldown.immolation_aura.up&cooldown.fel_devastation.remains<10|dot.fiery_brand.ticking&talent.fiery_demise
    -- Note: Tweaked as per conversation with APL creator:
    -- variable,name=FD_done,value=0,op=setif,condition=talent.fiery_demise.enabled&cooldown.fiery_brand.up&(talent.down_in_flames.enabled&(cooldown.soul_carver.up|cooldown.fel_devastation.up)|!talent.down_in_flames.enabled&cooldown.soul_carver.up)
    if (S.FieryDemise:IsAvailable() and S.FieryBrand:CooldownUp() and (S.DowninFlames:IsAvailable() and (S.SoulCarver:CooldownUp() or S.FelDevastation:CooldownUp()) or (not S.DowninFlames:IsAvailable()) and S.SoulCarver:CooldownUp())) then
      VarFDDone = false
    end
    -- infernal_strike
    if S.InfernalStrike:IsCastable() and ((not Settings.Vengeance.ConserveInfernalStrike) or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
      if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike main 2"; end
    end
    -- demon_spikes,if=!buff.demon_spikes.up&!cooldown.pause_action.remains
    -- Note: Handled via Defensives()
    -- fiery_brand,if=!talent.fiery_demise.enabled&!dot.fiery_brand.ticking
    if S.FieryBrand:IsCastable() and Settings.Vengeance.UseFieryBrandOffensively and ((not S.FieryDemise:IsAvailable()) and Target:DebuffDown(S.FieryBrandDebuff)) then
      if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand main 4"; end
    end
    -- bulk_extraction
    if S.BulkExtraction:IsCastable() then
      if Cast(S.BulkExtraction, nil, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction main 6"; end
    end
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 8"; end
      end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,slot=trinket1
      local Trinket1ToUse = Player:GetUseableTrinkets(OnUseExcludes, 13)
      if Trinket1ToUse then
        if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 main 10"; end
      end
      -- use_item,slot=trinket2
      local Trinket2ToUse = Player:GetUseableTrinkets(OnUseExcludes, 14)
      if Trinket2ToUse then
        if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 main 12"; end
      end
    end
    if Target:DebuffDown(S.FieryBrandDebuff) then
      -- run_action_list,name=rampH,if=variable.rampH_done=0&!dot.fiery_brand.ticking
      if (not bool(VarRampHDone)) then
        local ShouldReturn = RampH(); if ShouldReturn then return ShouldReturn; end
        if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for RampH()"; end
      end
      -- run_action_list,name=rampED,if=variable.rampED_done=0&!dot.fiery_brand.ticking
      if (not bool(VarRampEDDone)) then
        local ShouldReturn = RampED(); if ShouldReturn then return ShouldReturn; end
        if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for RampED()"; end
      end
      -- run_action_list,name=rampSC,if=variable.rampSC_done=0&!dot.fiery_brand.ticking
      if (not bool(VarRampSCDone)) then
        local ShouldReturn = RampSC(); if ShouldReturn then return ShouldReturn; end
        if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for RampSC()"; end
      end
    end
    -- run_action_list,name=FD,if=variable.FD_done=0
    -- Manually added: Check fiery_demise. If not talented, the VarFDDone check remains nil, causing the profile to enter FD().
    if (S.FieryDemise:IsAvailable() and not VarFDDone) then
      local ShouldReturn = FD(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FD()"; end
    end
    -- metamorphosis,if=!buff.metamorphosis.up&!dot.fiery_brand.ticking
    if S.Metamorphosis:IsCastable() and Settings.Vengeance.UseMetaOffensively and (Player:BuffDown(S.MetamorphosisBuff) and Target:DebuffDown(S.FieryBrandDebuff)) then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis main 14"; end
    end
    -- fel_devastation,if=(!talent.down_in_flames.enabled)
    if S.FelDevastation:IsReady() and (not S.DowninFlames:IsAvailable()) then
      if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation main 16"; end
    end
    -- spirit_bomb,if=((buff.metamorphosis.up&talent.fracture.enabled&soul_fragments>=3)|soul_fragments>=4&active_enemies>1)
    if S.SpiritBomb:IsReady() and ((Player:BuffUp(S.MetamorphosisBuff) and S.Fracture:IsAvailable() and SoulFragments >= 3) or SoulFragments >= 4 and EnemiesCount8yMelee > 1) then
      if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb main 18"; end
    end
    -- soul_cleave,if=(talent.spirit_bomb.enabled&soul_fragments=0&target>1)|(active_enemies<2&((talent.fracture.enabled&fury>=55)|(!talent.fracture.enabled&fury>=70)|(buff.metamorphosis.up&((talent.fracture.enabled&fury>=35)|(!talent.fracture.enabled&fury>=50)))))|(!talent.spirit_bomb.enabled)&((talent.fracture.enabled&fury>=55)|(!talent.fracture.enabled&fury>=70)|(buff.metamorphosis.up&((talent.fracture.enabled&fury>=35)|(!talent.fracture.enabled&fury>=50))))
    if S.SoulCleave:IsReady() and ((S.SpiritBomb:IsAvailable() and SoulFragments == 0 and EnemiesCount8yMelee > 1) or (EnemiesCount8yMelee < 2 and ((S.Fracture:IsAvailable() and Player:Fury() >= 55) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 70) or (Player:BuffUp(S.MetamorphosisBuff) and ((S.Fracture:IsAvailable() and Player:Fury() >= 35) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 50))))) or (not S.SpiritBomb:IsAvailable()) and ((S.Fracture:IsAvailable() and Player:Fury() >= 55) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 70) or (Player:BuffUp(S.MetamorphosisBuff) and ((S.Fracture:IsAvailable() and Player:Fury() >= 35) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 50))))) then
      if Cast(S.SoulCleave, nil, nil, not Target:IsSpellInRange(S.SoulCleave)) then return "soul_cleave main 20"; end
    end
    -- immolation_aura,if=(talent.fiery_demise.enabled&fury.deficit>=10&(cooldown.soul_carver.remains>15))|(!talent.fiery_demise.enabled&fury.deficit>=10)
    -- Note: Added !talent.soul_carver.enabled check, so the line doesn't get skipped if FieryDemise is talented and SoulCarver isn't
    if S.ImmolationAura:IsCastable() and ((S.FieryDemise:IsAvailable() and Player:FuryDeficit() >= 10 and (S.SoulCarver:CooldownRemains() > 15 or not S.SoulCarver:IsAvailable())) or ((not S.FieryDemise:IsAvailable()) and Player:FuryDeficit() >= 10)) then
      if Cast(S.ImmolationAura) then return "immolation_aura main 22"; end
    end
    -- felblade,if=fury.deficit>=40
    if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 24"; end
    end
    -- fracture,if=(talent.spirit_bomb.enabled&(soul_fragments<=3&target>1|target<2&fury.deficit>=30))|(!talent.spirit_bomb.enabled&((buff.metamorphosis.up&fury.deficit>=45)|(buff.metamorphosis.down&fury.deficit>=30)))
    if S.Fracture:IsCastable() and ((S.SpiritBomb:IsAvailable() and (SoulFragments <= 3 and EnemiesCount8yMelee > 1 or EnemiesCount8yMelee < 2 and Player:FuryDeficit() >= 30)) or ((not S.SpiritBomb:IsAvailable()) and ((Player:BuffUp(S.MetamorphosisBuff) and Player:FuryDeficit() >= 45) or (Player:BuffDown(S.MetamorphosisBuff) and Player:FuryDeficit() >= 30)))) then
      if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture main 26"; end
    end
    -- sigil_of_flame,if=fury.deficit>=30
    if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) and (Player:FuryDeficit() >= 30) then
      if S.ConcentratedSigils:IsAvailable() then
        if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame main 28 (Concentrated)"; end
      else
        if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 28 (Normal)"; end
      end
    end
    -- shear
    if S.Shear:IsCastable() and IsInMeleeRange then
      if Cast(S.Shear) then return "shear main 30"; end
    end
    -- Manually added: fracture as a fallback filler
    if S.Fracture:IsCastable() and IsInMeleeRange then
      if Cast(S.Fracture) then return "fracture main 32"; end
    end
    -- throw_glaive
    if S.ThrowGlaive:IsCastable() then
      if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 34"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Vengeance DH rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(581, APL, Init);

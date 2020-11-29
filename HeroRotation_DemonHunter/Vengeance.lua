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
local match      = string.match

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Vengeance
local I = Item.DemonHunter.Vengeance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local SoulFragments, SoulFragmentsAdjusted, LastSoulFragmentAdjustment
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarBrandBuild = (S.AgonizingFlames:IsAvailable() and S.BurningAlive:IsAvailable() and S.CharredFlesh:IsAvailable())
local RazelikhsDefilementEquipped = Player:HasLegendaryEquipped(27)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
}

HL:RegisterForEvent(function()
  VarBrandBuild = (S.AgonizingFlames:IsAvailable() and S.BurningAlive:IsAvailable() and S.CharredFlesh:IsAvailable())
end, "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE")

HL:RegisterForEvent(function()
  RazelikhsDefilementEquipped = Player:HasLegendaryEquipped(27)
end, "PLAYER_EQUIPMENT_CHANGED")

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
  -- potion
  if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions then
    if CastSuggested(I.PotionofPhantomFire) then return "potion_of_unbridled_fury 2"; end
  end
  -- First attacks
  if S.InfernalStrike:IsCastable() and not IsInMeleeRange then
    if Cast(S.InfernalStrike, nil, nil, not Target:IsInRange(30)) then return "infernal_strike 6"; end
  end
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then return "fracture 8"; end
  end
end

local function Defensives()
  -- Demon Spikes
  if S.DemonSpikes:IsCastable() and Player:BuffDown(S.DemonSpikesBuff) then
    if S.DemonSpikes:ChargesFractional() > 1.9 then
      if Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "demon_spikes defensives (Capped)"; end
    elseif (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
      if Cast(S.DemonSpikes, Settings.Vengeance.OffGCDasOffGCD.DemonSpikes) then return "demon_spikes defensives (Danger)"; end
    end
  end
  -- Metamorphosis,if=!(talent.demonic.enabled)&(!covenant.venthyr.enabled|!dot.sinful_brand.ticking)|target.time_to_die<15
  -- Manually changed to:
  -- if=(!talent.demonic.enabled|buff.metamorphosis.down)&(!covenant.venthyr.enabled|!dot.sinful_brand.ticking)|target.time_to_die<15
  -- Otherwise, Meta would never be suggested if Demonic is talented
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and ((not S.Demonic:IsAvailable() or Player:BuffDown(S.MetamorphosisBuff)) and (not S.SinfulBrand:IsAvailable() or Target:DebuffDown(S.SinfulBrandDebuff)) or Target:TimeToDie() < 15) then
    if CastSuggested(S.Metamorphosis) then return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and Target:DebuffDown(S.FieryBrandDebuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
  -- Manual add: Door of Shadows with Enduring Gloom for the absorb shield
  if S.DoorofShadows:IsCastable() and S.EnduringGloom:IsAvailable() and IsTanking then
    if Cast(S.DoorofShadows, nil, Settings.Commons.CovenantDisplayStyle) then return "door_of_shadows defensives"; end
  end
end

local function Brand()
  -- fiery_brand
  if S.FieryBrand:IsCastable() and IsInMeleeRange then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand 92"; end
  end
  -- immolation_aura,if=dot.fiery_brand.ticking
  if S.ImmolationAura:IsCastable() and IsInMeleeRange and (Target:DebuffUp(S.FieryBrandDebuff)) then
    if Cast(S.ImmolationAura) then return "immolation_aura 88"; end
  end
end

local function Cooldowns()
  -- potion
  if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions then
    if CastSuggested(I.PotionofPhantomFire) then return "potion_of_unbridled_fury 60"; end
  end
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
  -- sinful_brand,if=!dot.sinful_brand.ticking
  if S.SinfulBrand:IsCastable() and (Target:BuffDown(S.SinfulBrandDebuff)) then
    if Cast(S.SinfulBrand, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.SinfulBrand)) then return "sinful_brand 74"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt 76"; end
  end
  -- fodder_to_the_flame
  if S.FoddertotheFlame:IsCastable() then
    if Cast(S.FoddertotheFlame, nil, Settings.Commons.CovenantDisplayStyle) then return "fodder_to_the_flame 78"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.CovenantDisplayStyle) then return "elysian_decree 80"; end
  end
end

local function Normal()
  -- infernal_strike
  if S.InfernalStrike:IsCastable() and (not Settings.Vengeance.ConserveInfernalStrike or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike 24"; end
  end
  -- bulk_extraction
  if S.BulkExtraction:IsCastable() then
    if Cast(S.BulkExtraction) then return "bulk_extraction 26"; end
  end
  -- spirit_bomb,if=((buff.metamorphosis.up&talent.fracture.enabled&soul_fragments>=3)|soul_fragments>=4)
  if S.SpiritBomb:IsReady() and IsInAoERange and ((Player:BuffUp(S.Metamorphosis) and S.Fracture:IsAvailable() and SoulFragments >= 3) or SoulFragments >= 4) then
    if Cast(S.SpiritBomb) then return "spirit_bomb 28"; end
  end
  -- fel_devastation
  -- Manual add: ,if=talent.demonic.enabled&!buff.metamorphosis.up|!talent.demonic.enabled
  -- This way we don't waste potential Meta uptime
  if S.FelDevastation:IsReady() and (S.Demonic:IsAvailable() and Player:BuffDown(S.Metamorphosis) or not S.Demonic:IsAvailable()) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation 34"; end
  end
  -- soul_cleave,if=((talent.spirit_bomb.enabled&soul_fragments=0)|!talent.spirit_bomb.enabled)&((talent.fracture.enabled&fury>=55)|(!talent.fracture.enabled&fury>=70)|cooldown.fel_devastation.remains>target.time_to_die|(buff.metamorphosis.up&((talent.fracture.enabled&fury>=35)|(!talent.fracture.enabled&fury>=50))))
  if S.SoulCleave:IsReady() and (((S.SpiritBomb:IsAvailable() and SoulFragments == 0) or not S.SpiritBomb:IsAvailable()) and ((S.Fracture:IsAvailable() and Player:Fury() >= 55) or (not S.Fracture:IsAvailable() and Player:Fury() >= 70) or S.FelDevastation:CooldownRemains() > Target:TimeToDie() or (Player:BuffUp(S.MetamorphosisBuff) and ((S.Fracture:IsAvailable() and Player:Fury() >= 35) or (not S.Fracture:IsAvailable() and Player:Fury() >= 50))))) then
    if Cast(S.SoulCleave, nil, nil, not Target:IsSpellInRange(S.SoulCleave)) then return "soul_cleave 36"; end
  end
  -- immolation_aura,if=((variable.brand_build&cooldown.fiery_brand.remains>10)|!variable.brand_build)&fury<=90
  if S.ImmolationAura:IsCastable() and (((VarBrandBuild and S.FieryBrand:CooldownRemains() > 10) or not VarBrandBuild) and Player:Fury() <= 90) then
    if Cast(S.ImmolationAura) then return "immolation_aura 38"; end
  end
  -- felblade,if=fury<=60
  if S.Felblade:IsCastable() and (Player:Fury() <= 60) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade 40"; end
  end
  -- fracture,if=((talent.spirit_bomb.enabled&soul_fragments<=3)|(!talent.spirit_bomb.enabled&((buff.metamorphosis.up&fury<=55)|(buff.metamorphosis.down&fury<=70))))
  if S.Fracture:IsCastable() and IsInMeleeRange and ((S.SpiritBomb:IsAvailable() and SoulFragments <= 3) or (not S.SpiritBomb:IsAvailable() and ((Player:BuffUp(S.MetamorphosisBuff) and Player:Fury() <= 55) or (Player:BuffDown(S.MetamorphosisBuff) and Player:Fury() <= 70)))) then
    if Cast(S.Fracture) then return "fracture 42"; end
  end
  -- sigil_of_flame,if=!(covenant.kyrian.enabled&runeforge.razelikhs_defilement)
  if S.SigilofFlame:IsCastable() and (IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRemains(S.SigilofFlameDebuff) <= 3 and (not (Player:Covenant() == "Kyrian" and RazelikhsDefilementEquipped)) then
    if S.ConcentratedSigils:IsAvailable() then
      if Cast(S.SigilofFlame, nil, nil, not IsInAoERange) then return "sigil_of_flame 44 (Concentrated)"; end
    else
      if Cast(S.SigilofFlame, nil, nil, not Target:IsInRange(30)) then return "sigil_of_flame 44 (Normal)"; end
    end
  end
  -- shear
  if S.Shear:IsReady() and IsInMeleeRange then
    if Cast(S.Shear) then return "shear 46"; end
  end
  -- Manually adding Fracture as a fallback filler
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then return "fracture 48"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive 50 (OOR)"; end
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
    -- variable,name=brand_build,value=talent.agonizing_flames.enabled&talent.burning_alive.enabled&talent.charred_flesh.enabled
    -- Moved to Precombat, as talents can't change once in combat, so no need to continually check
    -- disrupt (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- consume_magic
    -- throw_glaive,if=buff.fel_bombardment.stack=5&(buff.immolation_aura.up|!buff.metamorphosis.up)
    if S.ThrowGlaive:IsCastable() and (Player:BuffStack(S.FelBombardmentBuff) == 5 and (Player:BuffUp(S.ImmolationAuraBuff) or Player:BuffDown(S.MetamorphosisBuff))) then
      if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fel_bombardment"; end
    end
    -- call_action_list,name=brand,if=variable.brand_build
    if VarBrandBuild then
      local ShouldReturn = Brand(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=defensives
    if (IsTanking or not Player:HealingAbsorbed()) then
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

end

HR.SetAPL(581, APL, Init);

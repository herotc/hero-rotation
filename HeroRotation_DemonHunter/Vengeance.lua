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
  I.CacheofAcquiredTreasures:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
}

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Rotation Var
local SoulFragments, SoulFragmentsAdjusted, LastSoulFragmentAdjustment
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarBrandBuild = (S.AgonizingFlames:IsAvailable() and S.BurningAlive:IsAvailable() and S.CharredFlesh:IsAvailable())
local RazelikhsDefilementEquipped = Player:HasLegendaryEquipped(27)
local BlindFaithEquipped = (Player:HasLegendaryEquipped(238) or CovenantID == 1 and Player:HasUnity())

-- Are we Kyrian with the Kyrian legendary and using SpiritBomb?
local KyrianLegendaryAndSpB = (S.SpiritBomb:IsAvailable() and BlindFaithEquipped)

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
  RazelikhsDefilementEquipped = Player:HasLegendaryEquipped(27)
  BlindFaithEquipped = (Player:HasLegendaryEquipped(238) or CovenantID == 1 and Player:HasUnity())
  KyrianLegendaryAndSpB = (S.SpiritBomb:IsAvailable() and BlindFaithEquipped)
end, "COVENANT_CHOSEN", "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarBrandBuild = (S.AgonizingFlames:IsAvailable() and S.BurningAlive:IsAvailable() and S.CharredFlesh:IsAvailable())
  KyrianLegendaryAndSpB = (S.SpiritBomb:IsAvailable() and BlindFaithEquipped)
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
  -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 2"; end
  end
  -- First attacks
  if S.InfernalStrike:IsCastable() and not IsInMeleeRange then
    if Cast(S.InfernalStrike, nil, nil, not Target:IsInRange(30)) then return "infernal_strike precombat 4"; end
  end
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then return "fracture precombat 6"; end
  end
  if S.Shear:IsCastable() and IsInMeleeRange then
    if Cast(S.Shear) then return "shear precombat 8"; end
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
  -- Metamorphosis,if=!buff.metamorphosis.up&(!covenant.venthyr.enabled|!dot.sinful_brand.ticking)|target.time_to_die<15
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and (Player:BuffDown(S.MetamorphosisBuff) and ((not S.SinfulBrand:IsAvailable()) or Target:DebuffDown(S.SinfulBrandDebuff)) or Target:TimeToDie() < 15) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis) then return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and Target:DebuffDown(S.FieryBrandDebuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
  -- Manual add: Door of Shadows with Enduring Gloom for the absorb shield
  if S.DoorofShadows:IsCastable() and S.EnduringGloom:IsAvailable() then
    if Cast(S.DoorofShadows, nil, Settings.Commons.DisplayStyle.Covenant) then return "door_of_shadows defensives"; end
  end
  -- Manual add: fel_devastation,if=buff.blind_faith.up&health.pct<30
  if S.FelDevastation:IsReady() and (Player:BuffUp(S.BlindFaithBuff) and Player:HealthPercentage() < Settings.Vengeance.FelDevHealthThreshold) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation defensives"; end
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
  if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.Potions then
    if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion_of_unbridled_fury cooldowns 2"; end
  end
  -- Manually added: use_item,name=cache_of_acquired_treasures,if=buff.acquired_sword.up
  if I.CacheofAcquiredTreasures:IsEquippedAndReady() and (Player:BuffUp(S.AcquiredSwordBuff)) then
    if Cast(I.CacheofAcquiredTreasures, nil, Settings.Commons.DisplayStyle.Trinkets) then return "cache_of_acquired_treasures 3"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- sinful_brand,if=!dot.sinful_brand.ticking
  if S.SinfulBrand:IsCastable() and (Target:BuffDown(S.SinfulBrandDebuff)) then
    if Cast(S.SinfulBrand, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SinfulBrand)) then return "sinful_brand cooldowns 4"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt cooldowns 6"; end
  end
  -- elysian_decree
  -- Note: Added Unity/Blind Faith handling
  if S.ElysianDecree:IsCastable() and ((not KyrianLegendaryAndSpB) or SoulFragments >= 4) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Covenant) then return "elysian_decree cooldowns 8"; end
  end
end

local function Normal()
  -- infernal_strike
  if S.InfernalStrike:IsCastable() and ((not Settings.Vengeance.ConserveInfernalStrike) or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike normal 2"; end
  end
  -- bulk_extraction
  -- Note: Added overcap safety
  if S.BulkExtraction:IsCastable() and (SoulFragments <= 5 - mathmax(5, EnemiesCount8yMelee)) then
    if Cast(S.BulkExtraction) then return "bulk_extraction normal 4"; end
  end
  -- Manually added: spirit_bomb,if=covenant.kyrian&runeforge.blind_faith&talent.spirit_bomb&prev_gcd.2.elysian_decree&prev_gcd.1.spirit_bomb
  if S.SpiritBomb:IsCastable() and IsInAoERange and (KyrianLegendaryAndSpB and Player:PrevGCD(2, S.ElysianDecree) and Player:PrevGCD(1, S.SpiritBomb)) then
    if Cast(S.SpiritBomb) then return "spirit_bomb normal 6"; end
  end
  -- spirit_bomb,if=((buff.metamorphosis.up&talent.fracture.enabled&soul_fragments>=3&(!covenant.kyrian|cooldown.elysian_decree.remains>gcd*2))|soul_fragments>=4)
  -- Note: Added Elysian Decree check so we don't waste SoulFragments when it's ready
  if S.SpiritBomb:IsReady() and IsInAoERange and ((Player:BuffUp(S.Metamorphosis) and S.Fracture:IsAvailable() and SoulFragments >= 3 and (CovenantID ~= 1 or S.ElysianDecree:CooldownRemains() > Player:GCD() * 2)) or SoulFragments >= 4) then
    if Cast(S.SpiritBomb) then return "spirit_bomb normal 8"; end
  end
  -- fel_devastation
  -- Manual add: ,if=talent.demonic.enabled&!buff.metamorphosis.up|!talent.demonic.enabled
  -- This way we don't waste potential Meta uptime
  -- Note: Also add Blind Faith check so we don't waste buff time when we could be generating more stacks
  if S.FelDevastation:IsReady() and (S.Demonic:IsAvailable() and Player:BuffDown(S.Metamorphosis) or not S.Demonic:IsAvailable()) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation normal 10"; end
  end
  -- Manually added: soul_cleave,if=buff.blind_faith.up&talent.spirit_bomb&soul_fragments>=3&(talent.fracture&cooldown.fracture.remains>gcd-0.5|!talent.fracture)
  if S.SoulCleave:IsReady() and (Player:BuffUp(S.BlindFaithBuff) and S.SpiritBomb:IsAvailable() and SoulFragments >= 3 and (S.Fracture:IsAvailable() and S.Fracture:CooldownRemains() > Player:GCD() - 0.5 or not S.Fracture:IsAvailable())) then
    if Cast(S.SoulCleave, nil, nil, not Target:IsSpellInRange(S.SoulCleave)) then return "soul_cleave normal 12"; end
  end
  -- soul_cleave,if=/soul_cleave,if=((talent.spirit_bomb.enabled&soul_fragments=0&buff.blind_faith.down)|!talent.spirit_bomb.enabled)&((talent.fracture.enabled&fury>=55)|(!talent.fracture.enabled&fury>=70)|cooldown.fel_devastation.remains>target.time_to_die|(buff.metamorphosis.up&((talent.fracture.enabled&fury>=35)|(!talent.fracture.enabled&fury>=50))))
  -- Note: Added Blind Faith buff check if SpiritBomb is available
  if S.SoulCleave:IsReady() and (((S.SpiritBomb:IsAvailable() and SoulFragments == 0 and Player:BuffDown(S.BlindFaithBuff)) or not S.SpiritBomb:IsAvailable()) and ((S.Fracture:IsAvailable() and Player:Fury() >= 55) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 70) or S.FelDevastation:CooldownRemains() > Target:TimeToDie() or (Player:BuffUp(S.MetamorphosisBuff) and ((S.Fracture:IsAvailable() and Player:Fury() >= 35) or ((not S.Fracture:IsAvailable()) and Player:Fury() >= 50))))) then
    if Cast(S.SoulCleave, nil, nil, not Target:IsSpellInRange(S.SoulCleave)) then return "soul_cleave normal 14"; end
  end
  -- Manually added: immolation_aura,if=set_bonus.tier28_4pc&buff.immolation_aura.down
  if S.ImmolationAura:IsCastable() and (Player:HasTier(28, 4) and Player:BuffDown(S.ImmolationAuraBuff)) then
    if Cast(S.ImmolationAura) then return "immolation_aura normal 16"; end
  end
  -- immolation_aura,if=((variable.brand_build&cooldown.fiery_brand.remains>10)|!variable.brand_build)&(fury<=90&!talent.fallout|talent.fallout&soul_fragments<=4)
  -- Manually added: Don't cast if we'll cap SoulFragments with Fallout (we have a 60-70% chance to get a fragment per target)
  if S.ImmolationAura:IsCastable() and (((VarBrandBuild and S.FieryBrand:CooldownRemains() > 10) or not VarBrandBuild) and (Player:Fury() <= 90 and (not S.Fallout:IsAvailable()) or S.Fallout:IsAvailable() and SoulFragments <= 5 - mathmin(5, EnemiesCount8yMelee * 0.6))) then
    if Cast(S.ImmolationAura) then return "immolation_aura normal 20"; end
  end
  -- fracture,if=((talent.spirit_bomb.enabled&soul_fragments<=3)|(!talent.spirit_bomb.enabled&((buff.metamorphosis.up&fury<=55)|(buff.metamorphosis.down&fury<=70))))
  if S.Fracture:IsCastable() and IsInMeleeRange and ((S.SpiritBomb:IsAvailable() and SoulFragments <= 3) or ((not S.SpiritBomb:IsAvailable()) and ((Player:BuffUp(S.MetamorphosisBuff) and Player:Fury() <= 55) or (Player:BuffDown(S.MetamorphosisBuff) and Player:Fury() <= 70)))) then
    if Cast(S.Fracture) then return "fracture normal 18"; end
  end
  -- felblade,if=fury<=60
  if S.Felblade:IsCastable() and (Player:Fury() <= 60) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade normal 22"; end
  end
  -- sigil_of_flame,if=!(covenant.kyrian.enabled&runeforge.razelikhs_defilement)
  if S.SigilofFlame:IsCastable() and (IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRemains(S.SigilofFlameDebuff) <= 3 and (not (CovenantID == 1 and RazelikhsDefilementEquipped)) then
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
    -- variable,name=brand_build,value=talent.agonizing_flames.enabled&talent.burning_alive.enabled&talent.charred_flesh.enabled
    -- Moved to declarations and PLAYER_TALENT_UPDATE registration, as talents can't change once in combat, so no need to continually check
    -- disrupt (Interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- consume_magic
    -- throw_glaive,if=buff.fel_bombardment.stack=5&(buff.immolation_aura.up|!buff.metamorphosis.up)
    if S.ThrowGlaive:IsCastable() and (Player:BuffStack(S.FelBombardmentBuff) == 5 and (Player:BuffUp(S.ImmolationAuraBuff) or Player:BuffDown(S.MetamorphosisBuff))) then
      if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fel_bombardment"; end
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
  --HR.Print("Vengeance DH rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(581, APL, Init);

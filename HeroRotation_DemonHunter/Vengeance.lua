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
  -- snapshot_stats
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
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

local function Racials()
  -- arcane_torrent,if=fury.deficit>15
  if S.ArcaneTorrent:IsCastable() and (Player:FuryDeficit() > 15) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent racials 2"; end
  end
end

local function Trinkets()
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs
  -- use_item,use_off_gcd=1,slot=main_hand,if=(variable.trinket_1_buffs|trinket.1.cooldown.remains)&(variable.trinket_2_buffs|trinket.2.cooldown.remains)
  -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&(buff.metamorphosis.up|cooldown.metamorphosis.remains>20)&(variable.trinket_2_exclude|trinket.2.cooldown.remains|!trinket.2.has_cooldown|variable.trinket_2_buffs)
  -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&(buff.metamorphosis.up|cooldown.metamorphosis.remains>20)&(variable.trinket_1_exclude|trinket.1.cooldown.remains|!trinket.1.has_cooldown|variable.trinket_1_buffs)
  -- Note: Using a generic use_items
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
    -- fiery_brand,if=!talent.fiery_demise.enabled&!ticking
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
    -- invoke_external_buff,name=power_infusion
    -- Note: Not handling external buffs
    -- call_action_list,name=trinkets
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=racials
    local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    -- the_hunt
    if S.TheHunt:IsCastable() then
      if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(50)) then return "the_hunt main 14"; end
    end
    -- elysian_decree
    if S.ElysianDecree:IsCastable() then
      if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree main 16"; end
    end
    -- soul_carver,if=(!talent.fiery_demise|(talent.fiery_demise&dot.fiery_brand.ticking))&soul_fragments<=3
    if S.SoulCarver:IsReady() and (((not S.FieryDemise:IsAvailable()) or (S.FieryDemise:IsAvailable() and Target:DebuffUp(S.FieryBrandDebuff))) and SoulFragments <= 3) then
      if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver main 18"; end
    end
    -- fel_devastation
    if S.FelDevastation:IsReady() then
      if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(13)) then return "fel_devastation main 20"; end
    end
    -- fiery_brand,if=remains<tick_time|!ticking
    if S.FieryBrand:IsCastable() and Settings.Vengeance.UseFieryBrandOffensively and (Target:DebuffRemains(S.FieryBrandDebuff) < S.FieryBrandDebuff:TickTime() or Target:DebuffDown(S.FieryBrandDebuff)) then
      if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand main 22"; end
    end
    -- immolation_aura
    if S.ImmolationAura:IsCastable() then
      if Cast(S.ImmolationAura) then return "immolation_aura main 24"; end
    end
    -- sigil_of_flame
    if S.SigilofFlame:IsCastable() then
      if S.ConcentratedSigils:IsAvailable() then
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame main 26 (Concentrated)"; end
      else
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 26 (Normal)"; end
      end
    end
    -- spirit_bomb,if=(soul_fragments>=4&!buff.metamorphosis.up)|(soul_fragments>=3&buff.metamorphosis.up)
    if S.SpiritBomb:IsReady() and (SoulFragments >= 3 + 1 * num(Player:BuffDown(S.MetamorphosisBuff))) then
      if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb main 28"; end
    end
    -- sigil_of_flame
    if S.SigilofFlame:IsCastable() and ((IsInAoERange or not S.ConcentratedSigils:IsAvailable()) and Target:DebuffRefreshable(S.SigilofFlameDebuff)) then
      if S.ConcentratedSigils:IsAvailable() then
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not IsInAoERange) then return "sigil_of_flame main 30 (Concentrated)"; end
      else
        if Cast(S.SigilofFlame, Settings.Commons.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 30 (Normal)"; end
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

  HR.Print("Vengeance DH rotation is currently a work in progress, but has been updated for patch 10.1.5.")
end

HR.SetAPL(581, APL, Init);

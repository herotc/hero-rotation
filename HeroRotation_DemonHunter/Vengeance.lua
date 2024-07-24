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
local mathfloor     = math.floor
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

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
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
local VarSigilPopTime = (S.QuickenedSigils:IsAvailable()) and 1 or 2
local VarSoFCD = (S.IlluminatedSigils:IsAvailable()) and 25 or 30
local VarSoSFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarNumSpawnableSouls = 0
local VarSpBThreshold, VarSpBombThreshold, VarSpBurstThreshold
local VarCanSpB, VarCanSpBSoon, VarCanSpBOneGCD
local VarCanSpBomb, VarCanSpBombSoon, VarCanSpBombOneGCD
local VarCanSpBurst, VarCanSpBurstSoon, VarCanSpBurstOneGCD
local VarDontSoulCleave, VarRGEnhCleave, VarCDSync
local VarFBBeforeMeta, VarHoldSoF
local VarST, VarSmallAoE, VarBigAoE
local BossFightRemains = 11111
local FightRemains = 11111

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

-- We repeatedly check DarkglareBoon Fury levels, so let's make a function for it...
local function DGBFury(FuryWithDGB, FuryWithoutDGB)
  return ((S.DarkglareBoon:IsAvailable() and Player:Fury() >= FuryWithDGB) or (not S.DarkglareBoon:IsAvailable() and Player:Fury() >= FuryWithoutDGB))
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
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent precombat 2"; end
  end
  -- sigil_of_flame,if=hero_tree.aldrachi_reaver|(hero_tree.felscarred&talent.student_of_suffering)
  if S.SigilofFlame:IsCastable() and (Player:HeroTreeID() == 35 or (Player:HeroTreeID() == 34 and S.StudentofSuffering:IsAvailable())) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame precombat 4"; end
  end
  -- Manually added: Gap closers
  if S.InfernalStrike:IsCastable() and not IsInMeleeRange then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then return "infernal_strike precombat 4"; end
  end
  if S.Felblade:IsCastable() and not IsInMeleeRange then
    if Cast(S.Felblade, nil, nil, not Target:IsInRange(15)) then return "felblade precombat 6"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura precombat 6"; end
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
  if S.DemonSpikes:IsCastable() and Player:BuffDown(S.DemonSpikesBuff) and Player:BuffDown(S.MetamorphosisBuff) and (EnemiesCount8yMelee == 1 and Player:BuffDown(S.FieryBrandDebuff) or EnemiesCount8yMelee > 1) then
    if S.DemonSpikes:ChargesFractional() > 1.9 then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.Defensives) then return "demon_spikes defensives (Capped)"; end
    elseif (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.Defensives) then return "demon_spikes defensives (Danger)"; end
    end
  end
  -- Metamorphosis,if=!buff.metamorphosis.up|target.time_to_die<15
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and (Player:BuffDown(S.MetamorphosisBuff) or BossFightRemains < 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.Defensives, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand defensives"; end
  end
end

-- Note: Included because it's in the APL, but we don't handle externals.
--[[local function Externals()
  -- invoke_external_buff,name=symbol_of_hope
  -- invoke_external_buff,name=power_infusion
end]]

local function RGActive()
  -- metamorphosis,use_off_gcd=1,if=!buff.metamorphosis.up&(buff.rending_strike.up&!buff.glaive_flurry.up)&soul_fragments<=1
  if S.Metamorphosis:IsCastable() and (Player:BuffDown(S.MetamorphosisBuff) and (Player:BuffUp(S.RendingStrikeBuff) and Player:BuffDown(S.GlaiveFlurryBuff)) and SoulFragments <= 1) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis rg_active 2"; end
  end
  -- felblade,if=fury<30&!variable.rg_enhance_cleave&buff.rending_strike.up&buff.glaive_flurry.up
  if S.Felblade:IsCastable() and (Player:Fury() < 30 and not VarRGEnhCleave and Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade rg_active 4"; end
  end
  -- the_hunt,if=!buff.reavers_glaive.up&(debuff.reavers_mark.remains>(gcd.remains+execute_time+action.soul_cleave.execute_time+(talent.fracture&action.fracture.execute_time|!talent.fracture&action.shear.execute_time)+gcd.max))
  local FillerET = (S.Fracture:IsAvailable()) and S.Fracture:ExecuteTime() or S.Shear:ExecuteTime()
  if S.TheHunt:IsCastable() and (Player:BuffDown(S.ReaversGlaiveBuff) and (Target:DebuffRemains(S.ReaversMarkDebuff) > (Player:GCDRemains() + S.TheHunt:ExecuteTime() + S.SoulCleave:ExecuteTime() + FillerET + Player:GCD()))) then
    if Cast(S.TheHunt, nil, Settings.CommonsOGCD.GCDasOffGCD.TheHunt, not Target:IsInRange(50)) then return "the_hunt rg_active 6"; end
  end
  -- fracture,if=variable.rg_enhance_cleave&buff.rending_strike.up&buff.glaive_flurry.up|!variable.rg_enhance_cleave&!buff.glaive_flurry.up
  -- shear,if=variable.rg_enhance_cleave&buff.rending_strike.up&buff.glaive_flurry.up|!variable.rg_enhance_cleave&!buff.glaive_flurry.up
  if VarRGEnhCleave and Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff) or not VarRGEnhCleave and Player:BuffDown(S.GlaiveFlurryBuff) then
    if S.Fracture:IsCastable() then
      if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rg_active 8"; end
    end
    if S.Shear:IsCastable() then
      if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear rg_active 10"; end
    end
  end
  -- bulk_extraction,if=!buff.soul_furnace_damage_amp.up&buff.soul_furnace_stack.stack+(spell_targets>?5)>=10
  if S.BulkExtraction:IsCastable() and (Player:BuffDown(S.SoulFurnaceDmgBuff) and Player:BuffStack(S.SoulFurnaceBuff) + mathmin(EnemiesCount8yMelee, 5) >= 10) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction rg_active 12"; end
  end
  -- soul_cleave,if=!variable.rg_enhance_cleave&buff.glaive_flurry.up&buff.rending_strike.up|variable.rg_enhance_cleave&!buff.rending_strike.up
  if S.SoulCleave:IsReady() and (not VarRGEnhCleave and Player:BuffUp(S.GlaiveFlurryBuff) and Player:BuffUp(S.RendingStrikeBuff) or VarRGEnhCleave and Player:BuffDown(S.RendingStrikeBuff)) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave rg_active 14"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade rg_active 16"; end
  end
  -- fracture,if=!buff.rending_strike.up
  if S.Fracture:IsCastable() and (Player:BuffDown(S.RendingStrikeBuff)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture rg_active 18"; end
  end
end

local function ARExecute()
  -- metamorphosis,use_off_gcd=1
  if S.Metamorphosis:IsCastable() then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis ar_execute 2"; end
  end
  -- reavers_glaive
  if S.ReaversGlaive:IsCastable() then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsSpellInRange(S.ReaversGlaive)) then return "reavers_glaive ar_execute 4"; end
  end
  -- the_hunt,if=!buff.reavers_glaive.up
  if S.TheHunt:IsCastable() and (Player:BuffDown(S.ReaversGlaiveBuff)) then
    if Cast(S.TheHunt, nil, Settings.CommonsOGCD.GCDasOffGCD.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar_execute 6"; end
  end
  -- bulk_extraction,if=spell_targets>=3&buff.art_of_the_glaive.stack>=20
  if S.BulkExtraction:IsCastable() and (EnemiesCount8yMelee >= 3 and Player:BuffStack(S.ArtoftheGlaiveBuff) >= 20) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction ar_execute 8"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame ar_execute 10"; end
  end
  -- fiery_brand
  if S.FieryBrand:IsCastable() then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand ar_execute 12"; end
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
  VarSpBThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 5) + (num(VarBigAoE) * 4)
  --[[if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
    VarSpBThreshold = (VarST * 5) + (VarSmallAoE * 5) + (VarBigAoE * 4)
  else
    VarSpBThreshold = (VarST * 5) + (VarSmallAoE * 5) + (VarBigAoE * 4)
  end]]
  -- variable,name=can_spb,value=soul_fragments>=variable.spb_threshold
  VarCanSpB = SoulFragments >= VarSpBThreshold
  -- variable,name=can_spb_soon,value=soul_fragments.total>=variable.spb_threshold
  VarCanSpBSoon = TotalSoulFragments >= VarSpBThreshold
  -- variable,name=can_spb_one_gcd,value=(soul_fragments.total+variable.num_spawnable_souls)>=variable.spb_threshold
  VarCanSpBOneGCD = (TotalSoulFragments + VarNumSpawnableSouls) >= VarSpBThreshold
  -- variable,name=dont_soul_cleave,value=variable.can_spb|variable.can_spb_soon|variable.can_spb_one_gcd|prev_gcd.1.fracture
  VarDontSoulCleave = VarCanSpB or VarCanSpBSoon or VarCanSpBOneGCD or Player:PrevGCD(1, S.Fracture)
  -- variable,name=rg_enhance_cleave,op=setif,condition=variable.big_aoe|fight_remains<10,value=1,value_else=0
  VarRGEnhCleave = (VarBigAoE or BossFightRemains < 10) and 1 or 0
  -- variable,name=cooldown_sync,value=(debuff.reavers_mark.up&buff.thrill_of_the_fight_damage.up)|fight_remains<20
  VarCDSync = (Target:DebuffUp(S.ReaversMarkDebuff) and Player:BuffUp(S.ThrilloftheFightDmgBuff)) or BossFightRemains < 20
  -- potion,use_off_gcd=1,if=variable.cooldown_sync
  if Settings.Commons.Enabled.Potions and VarCDSync then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ar 2"; end
    end
  end
  -- use_items,use_off_gcd=1,if=variable.cooldown_sync
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and VarCDSync then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
  -- call_action_list,name=externals,if=variable.cooldown_sync
  -- Note: Not handling externals.
  -- run_action_list,name=rg_active,if=buff.glaive_flurry.up|buff.rending_strike.up
  if Player:BuffUp(S.GlaiveFlurryBuff) or Player:BuffUp(S.RendingStrikeBuff) then
    local ShouldReturn = RGActive(); if ShouldReturn then return ShouldReturn; end
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for RGActive()"; end
  end
  -- call_action_list,name=ar_execute,if=fight_remains<20
  if BossFightRemains < 20 then
    local ShouldReturn = ARExecute(); if ShouldReturn then return ShouldReturn; end
  end
  -- metamorphosis,use_off_gcd=1,if=!buff.metamorphosis.up&!(cooldown.the_hunt.up|buff.reavers_glaive.up)
  if S.Metamorphosis:IsCastable() and (Player:BuffDown(S.MetamorphosisBuff) and not (S.TheHunt:CooldownUp() or Player:BuffUp(S.ReaversGlaiveBuff))) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis ar 4"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.unhindered_assault&!cooldown.felblade.up&(((talent.spirit_bomb&(fury<40&(variable.can_spb|variable.can_spb_soon)))|(talent.spirit_bomb&(cooldown.sigil_of_spite.up|cooldown.soul_carver.up)&cooldown.fel_devastation.up&fury<50))|fury<30)
  if S.VengefulRetreat:IsCastable() and (S.UnhinderedAssault:IsAvailable() and S.Felblade:CooldownDown() and (((S.SpiritBomb:IsAvailable() and (Player:Fury() < 40 and (VarCanSpB or VarCanSpBSoon))) or (S.SpiritBomb:IsAvailable() and (S.SigilofSpite:CooldownUp() or S.SoulCarver:CooldownUp()) and S.FelDevastation:CooldownUp() and Player:Fury() < 50)) or Player:Fury() < 30)) then
    if Cast(S.VengefulRetreat, Settings.Vengeance.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat ar 6"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura ar 8"; end
  end
  -- sigil_of_flame,if=talent.ascending_flame|(!talent.ascending_flame&!prev_gcd.1.sigil_of_flame&(dot.sigil_of_flame.remains<(1+talent.quickened_sigils)))
  if S.SigilofFlame:IsCastable() and (S.AscendingFlame:IsAvailable() or (not S.AscendingFlame:IsAvailable() and not Player:PrevGCD(1, S.SigilofFlame) and (Target:DebuffRemains(S.SigilofFlameDebuff) < (1 + num(S.QuickenedSigils:IsAvailable()))))) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame ar 10"; end
  end
  -- soul_cleave,if=(debuff.reavers_mark.remains<=(gcd.remains+execute_time+(gcd.max*2)))&(buff.art_of_the_glaive.stack+soul_fragments>=30&buff.art_of_the_glaive.stack>=28)&(fury<40|!variable.can_spb)
  if S.SoulCleave:IsReady() and ((Target:DebuffRemains(S.ReaversMarkDebuff) <= (Player:GCDRemains() + S.SoulCleave:ExecuteTime() + (Player:GCD() * 2))) and (Player:BuffStack(S.ArtoftheGlaiveBuff) + SoulFragments >= 30 and Player:BuffStack(S.ArtoftheGlaiveBuff) >= 28) and (Player:Fury() < 40 or not VarCanSpB)) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ar 12"; end
  end
  -- spirit_bomb,if=(debuff.reavers_mark.remains<=(gcd.remains+execute_time+(gcd.max*2)))&(buff.art_of_the_glaive.stack+soul_fragments>=30)
  if S.SpiritBomb:IsReady() and ((Target:DebuffRemains(S.ReaversMarkDebuff) <= (Player:GCDRemains() + S.SpiritBomb:ExecuteTime() + (Player:GCD() * 2))) and (Player:BuffStack(S.ArtoftheGlaiveBuff) + SoulFragments >= 30)) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb ar 14"; end
  end
  -- bulk_extraction,if=(debuff.reavers_mark.remains<=(gcd.remains+execute_time+(gcd.max*2)))&(buff.art_of_the_glaive.stack+(spell_targets>?5)>=30)
  if S.BulkExtraction:IsCastable() and ((Target:DebuffRemains(S.ReaversMarkDebuff) <= (Player:GCDRemains() + S.BulkExtraction:ExecuteTime() + (Player:GCD() * 2))) and (Player:BuffStack(S.ArtoftheGlaiveBuff) + mathmin(EnemiesCount8yMelee, 5) >= 30)) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction ar 16"; end
  end
  -- reavers_glaive,if=(buff.art_of_the_glaive.stack+soul_fragments>=30)|(debuff.reavers_mark.remains<=(gcd.remains+execute_time+(gcd.max*4)))|cooldown.the_hunt.remains<(gcd.remains+execute_time+(gcd.max*4))|variable.rg_enhance_cleave
  if S.ReaversGlaive:IsCastable() and ((Player:BuffStack(S.ArtoftheGlaiveBuff) + SoulFragments >= 30) or (Target:DebuffRemains(S.ReaversMarkDebuff) <= (Player:GCDRemains() + S.ReaversGlaive:ExecuteTime() + (Player:GCD() * 4))) or S.TheHunt:CooldownRemains() < (Player:GCDRemains() + S.ReaversGlaive:ExecuteTime() + (Player:GCD() * 4)) or VarRGEnhCleave) then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsSpellInRange(S.ReaversGlaive)) then return "reavers_glaive ar 18"; end
  end
  -- the_hunt,if=!buff.reavers_glaive.up
  if S.TheHunt:IsCastable() and (Player:BuffDown(S.ReaversGlaiveBuff)) then
    if Cast(S.TheHunt, nil, Settings.CommonsOGCD.GCDasOffGCD.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar 20"; end
  end
  -- fiery_brand,if=!talent.fiery_demise|(talent.fiery_demise&((talent.down_in_flames&charges>=max_charges)|(active_dot.fiery_brand=0)))
  if S.FieryBrand:IsCastable() and (not S.FieryDemise:IsAvailable() or (S.FieryDemise:IsAvailable() and ((S.DowninFlames:IsAvailable() and S.FieryBrand:Charges() >= S.FieryBrand:MaxCharges()) or (S.FieryBrandDebuff:AuraActiveCount() == 0)))) then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand ar 22"; end
  end
  -- fel_devastation,if=talent.spirit_bomb&!variable.can_spb&(variable.can_spb_soon|soul_fragments.inactive>=2)
  if S.FelDevastation:IsReady() and (S.SpiritBomb:IsAvailable() and not VarCanSpB and (VarCanSpBSoon or IncSoulFragments >= 2)) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation ar 24"; end
  end
  -- spirit_bomb,if=variable.can_spb
  if S.SpiritBomb:IsReady() and (VarCanSpB) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb ar 26"; end
  end
  -- fracture,if=talent.spirit_bomb&((fury<40&(!cooldown.felblade.up&(!talent.unhindered_assault|!cooldown.vengeful_retreat.up)))|(fury<40&variable.can_spb_one_gcd))
  if S.Fracture:IsCastable() and (S.SpiritBomb:IsAvailable() and ((Player:Fury() < 40 and (S.Felblade:CooldownDown() and (not S.UnhinderedAssault:IsAvailable() or S.VengefulRetreat:CooldownDown()))) or (Player:Fury() < 40 and VarCanSpBOneGCD))) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ar 28"; end
  end
  -- soul_carver,if=!talent.spirit_bomb|(((soul_fragments.total+3)<=6)&fury>=15&!prev_gcd.1.sigil_of_spite)
  if S.SoulCarver:IsCastable() and (not S.SpiritBomb:IsAvailable() or (((TotalSoulFragments + 3) <= 6) and Player:Fury() >= 15 and not Player:PrevGCD(1, S.SigilofSpite))) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver ar 30"; end
  end
  -- sigil_of_spite,if=!talent.spirit_bomb|((variable.can_spb&fury>=40)|variable.can_spb_soon|soul_fragments<=1)
  if S.SigilofSpite:IsCastable() and (not S.SpiritBomb:IsAvailable() or ((VarCanSpB and Player:Fury() >= 40) or VarCanSpBSoon or SoulFragments <= 1)) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite ar 32"; end
  end
  -- fel_devastation,if=!variable.single_target|buff.thrill_of_the_fight_damage.up
  if S.FelDevastation:IsReady() and (not VarST or Player:BuffUp(S.ThrilloftheFightDmgBuff)) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation ar 34"; end
  end
  -- bulk_extraction,if=spell_targets>=5
  if S.BulkExtraction:IsCastable() and (EnemiesCount8yMelee >= 5) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction ar 36"; end
  end
  -- felblade,if=(((talent.spirit_bomb&(fury<40&(variable.can_spb|variable.can_spb_soon)))|(talent.spirit_bomb&(cooldown.sigil_of_spite.up|cooldown.soul_carver.up)&cooldown.fel_devastation.up&fury<50))|fury<30)
  if S.Felblade:IsCastable() and (((S.SpiritBomb:IsAvailable() and (Player:Fury() < 40 and (VarCanSpB or VarCanSpBSoon))) or (S.SpiritBomb:IsAvailable() and (S.SigilofSpite:CooldownUp() or S.SoulCarver:CooldownUp()) and S.FelDevastation:CooldownUp() and Player:Fury() < 50)) or Player:Fury() < 30) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 38"; end
  end
  -- soul_cleave,if=fury.deficit<=25|(!talent.spirit_bomb|!variable.dont_soul_cleave)
  if S.SoulCleave:IsReady() and (Player:FuryDeficit() <= 25 or (not S.SpiritBomb:IsAvailable() or not VarDontSoulCleave)) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave ar 40"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture ar 42"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear ar 44"; end
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
  -- spirit_burst,if=talent.spirit_bomb&(variable.can_spburst|(buff.metamorphosis.remains<(gcd.remains+execute_time+1)&buff.demonsurge_spirit_burst.up))
  if S.SpiritBurst:IsReady() and (S.SpiritBomb:IsAvailable() and (VarCanSpBurst or (Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCDRemains() + S.SpiritBurst:ExecuteTime() + 1) and Player:Demonsurge("SpiritBurst")))) then
    if Cast(S.SpiritBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_burst fel_dev 2"; end
  end
  -- soul_sunder,if=buff.demonsurge_soul_sunder.up|!variable.dont_soul_cleave|(buff.metamorphosis.remains<(gcd.remains+execute_time+1)&buff.demonsurge_soul_sunder.up)
  if S.SoulSunder:IsReady() and (Player:Demonsurge("SoulSunder") or not VarDontSoulCleave or (Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCDRemains() + S.SoulSunder:ExecuteTime() + 1) and Player:Demonsurge("SoulSunder"))) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder fel_dev 4"; end
  end
  -- sigil_of_spite,if=soul_fragments.total<=2&buff.demonsurge_spirit_burst.up
  if S.SigilofSpite:IsCastable() and (TotalSoulFragments <= 2 and Player:Demonsurge("SpiritBurst")) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fel_dev 6"; end
  end
  -- soul_carver,if=soul_fragments.total<=2&!prev_gcd.1.sigil_of_spite&buff.demonsurge_spirit_burst.up
  if S.SoulCarver:IsCastable() and (TotalSoulFragments <= 2 and not Player:PrevGCD(1, S.SigilofSpite) and Player:Demonsurge("SpiritBurst")) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fel_dev 8"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then return "immolation_aura fel_dev 10"; end
  end
  -- sigil_of_flame,if=!variable.hold_sof
  if S.SigilofFlame:IsCastable() and (not VarHoldSoF) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fel_dev 12"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_dev 14"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev 16"; end
  end
end

local function FelDevPrep()
  -- fiery_brand,if=talent.fiery_demise&((talent.darkglare_boon&fury>=70)|(!talent.darkglare_boon&fury>=100))&(variable.can_spburst|variable.can_spburst_soon)&active_dot.fiery_brand=0&(cooldown.metamorphosis.up|cooldown.metamorphosis.remains<(gcd.remains+execute_time+action.fel_devastation.execute_time+(gcd.max*2)))
  if S.FieryBrand:IsCastable() and (S.FieryDemise:IsAvailable() and DGBFury(70, 100) and (VarCanSpBurst or VarCanSpBurstSoon) and S.FieryBrandDebuff:AuraActiveCount() == 0 and (S.Metamorphosis:CooldownUp() or S.Metamorphosis:CooldownRemains() < (Player:GCDRemains() + S.FieryBrand:ExecuteTime() + S.FelDevastation:ExecuteTime() + (Player:GCD() * 2)))) then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fel_dev_prep 2"; end
  end
  -- fel_devastation,if=((talent.darkglare_boon&fury>=70)|(!talent.darkglare_boon&fury>=100))&(variable.can_spburst|variable.can_spburst_soon)
  if S.FelDevastation:IsReady() and (DGBFury(70, 100) and (VarCanSpBurst or VarCanSpBurstSoon)) then
    if Cast(S.FelDevastation, Settings.Vengeance.OffGCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fel_dev_prep 4"; end
  end
  -- sigil_of_spite,if=!(variable.can_spburst|variable.can_spburst_soon)&soul_fragments.total<=2&((talent.darkglare_boon&fury>=70)|(!talent.darkglare_boon&fury>=100))
  if S.SigilofSpite:IsCastable() and (not (VarCanSpBurst or VarCanSpBurstSoon) and TotalSoulFragments <= 2 and DGBFury(70, 100)) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fel_dev_prep 6"; end
  end
  -- felblade,if=!((talent.darkglare_boon&fury>=70)|(!talent.darkglare_boon&fury>=100))
  if S.Felblade:IsCastable() and (not DGBFury(70, 100)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_dev_prep 8"; end
  end
  -- fracture,if=!(variable.can_spburst|variable.can_spburst_soon)|!((talent.darkglare_boon&fury>=70)|(!talent.darkglare_boon&fury>=100))
  if S.Fracture:IsCastable() and (not (VarCanSpBurst or VarCanSpBurstSoon) or not DGBFury(70, 100)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev_prep 10"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_dev_prep 12"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fel_dev_prep 14"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear fel_dev_prep 16"; end
  end
end

local function FSExecute()
  -- metamorphosis,use_off_gcd=1
  if S.Metamorphosis:IsCastable() then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis fs_execute 2"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.CommonsOGCD.GCDasOffGCD.TheHunt, not Target:IsInRange(50)) then return "the_hunt fs_execute 4"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fs_execute 6"; end
  end
  -- fiery_brand
  if S.FieryBrand:IsCastable() then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fs_execute 8"; end
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
    if Cast(S.FelDevastation, Settings.Vengeance.OffGCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation fs_execute 14"; end
  end
end

local function MetaPrep()
  -- metamorphosis,use_off_gcd=1,if=cooldown.sigil_of_flame.charges<1
  if S.Metamorphosis:IsCastable() and (S.SigilofFlame:Charges() < 1) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then return "metamorphosis meta_prep 2"; end
  end
  -- fiery_brand,if=talent.fiery_demise&active_dot.fiery_brand=0
  if S.FieryBrand:IsCastable() and (S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() == 0) then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand meta_prep 4"; end
  end
  -- potion,use_off_gcd=1
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion meta_prep 6"; end
    end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta_prep 8"; end
  end
end

local function Metamorphosis()
  -- call_action_list,name=externals
  -- Note: Not handling externals.
  -- spirit_burst,if=talent.spirit_bomb&(buff.metamorphosis.remains<(gcd.remains+execute_time+1))&buff.demonsurge_spirit_burst.up
  if S.SpiritBurst:IsReady() and ((Player:BuffRemains(S.MetamorphosisBuff) < (Player:GCDRemains() + S.SpiritBurst:ExecuteTime() + 1)) and Player:Demonsurge("SpiritBurst")) then
    if Cast(S.SpiritBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_burst metamorphosis 2"; end
  end
  -- sigil_of_spite,if=((variable.can_spburst&fury>=40)|variable.can_spburst_soon)
  if S.SigilofSpite:IsCastable() and ((VarCanSpBurst and Player:Fury() >= 40) or VarCanSpBurstSoon) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite metamorphosis 4"; end
  end
  -- spirit_burst,if=talent.spirit_bomb&variable.can_spburst&buff.demonsurge_spirit_burst.up|soul_fragments>=5
  if S.SpiritBurst:IsReady() and (S.SpiritBomb:IsAvailable() and VarCanSpBurst and Player:Demonsurge("SpiritBurst") or SoulFragments >= 5) then
    if Cast(S.SpiritBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_burst metamorphosis 6"; end
  end
  -- soul_carver,if=soul_fragments.total<=2&!prev_gcd.1.sigil_of_spite
  if S.SoulCarver:IsCastable() and (TotalSoulFragments <= 2 and not Player:PrevGCD(1, S.SigilofSpite)) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver metamorphosis 8"; end
  end
  -- sigil_of_spite,if=soul_fragments<=1
  if S.SigilofSpite:IsCastable() and (SoulFragments <= 1) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite metamorphosis 10"; end
  end
  -- fel_desolation,if=prev_gcd.2.sigil_of_spite|prev_gcd.2.soul_carver|!variable.can_spburst&(variable.can_spburst_soon|soul_fragments.inactive>=2)|(!buff.demonsurge_soul_sunder.up&!buff.demonsurge_spirit_burst.up&!buff.demonsurge_consuming_fire.up&!buff.demonsurge_sigil_of_doom.up&cooldown.sigil_of_doom.charges<1&buff.demonsurge_fel_desolation.up)
  if S.FelDesolation:IsReady() and (Player:PrevGCD(2, S.SigilofSpite) or Player:PrevGCD(2, S.SoulCarver) or not VarCanSpBurst and (VarCanSpBurstSoon or IncSoulFragments >= 2) or (not Player:Demonsurge("SoulSunder") and not Player:Demonsurge("SpiritBurst") and not Player:Demonsurge("ConsumingFire") and not Player:Demonsurge("SigilofDoom") and S.SigilofDoom:Charges() < 1 and Player:Demonsurge("FelDesolation"))) then
    if Cast(S.FelDesolation, Settings.Vengeance.OffGCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then return "fel_devastation metamorphosis 12"; end
  end
  -- sigil_of_doom,if=talent.ascending_flame|(!talent.ascending_flame&(dot.sigil_of_doom.remains<(1+talent.quickened_sigils)&!prev_gcd.1.sigil_of_doom))
  if S.SigilofDoom:IsCastable() and (S.AscendingFlame:IsAvailable() or (not S.AscendingFlame:IsAvailable() and (Target:DebuffRemains(S.SigilofDoomDebuff) < (1 + num(S.QuickenedSigils:IsAvailable())) and not Player:PrevGCD(1, S.SigilofDoom)))) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom metamorphosis 14"; end
  end
  -- bulk_extraction,if=(variable.can_spburst|variable.can_spburst_soon)&!buff.soul_furnace_damage_amp.up&buff.soul_furnace_stack.stack<=6&buff.soul_furnace_stack.stack+(spell_targets.bulk_extraction>?5)>=10
  if S.BulkExtraction:IsCastable() and ((VarCanSpBurst or VarCanSpBurstSoon) and Player:BuffDown(S.SoulFurnaceDmgBuff) and Player:BuffStack(S.SoulFurnaceBuff) <= 6 and Player:BuffStack(S.SoulFurnaceBuff) + mathmin(EnemiesCount8yMelee, 5) >= 10) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction metamorphosis 16"; end
  end
  -- spirit_burst,if=(talent.spirit_bomb&variable.can_spburst)
  if S.SpiritBurst:IsReady() and (S.SpiritBomb:IsAvailable() and VarCanSpBurst) then
    if Cast(S.SpiritBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_burst metamorphosis 18"; end
  end
  -- fracture,if=variable.big_aoe&(soul_fragments>=2&soul_fragments<=3)
  if S.Fracture:IsCastable() and (VarBigAoE and (SoulFragments >= 2 and SoulFragments <= 3)) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture metamorphosis 20"; end
  end
  -- felblade,if=(fury<40&(variable.can_spburst|variable.can_spburst_soon))|fury<30
  if S.Felblade:IsCastable() and ((Player:Fury() < 40 and (VarCanSpBurst or VarCanSpBurstSoon)) or Player:Fury() < 30) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 22"; end
  end
  -- soul_sunder,if=!variable.dont_soul_cleave
  if S.SoulSunder:IsReady() and (not VarDontSoulCleave) then
    if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder metamorphosis 24"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade metamorphosis 26"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture metamorphosis 28"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear metamorphosis 30"; end
  end
end

local function FS()
  -- variable,name=spbomb_threshold,op=setif,condition=talent.fiery_demise&dot.fiery_brand.ticking,value=(variable.single_target*5)+(variable.small_aoe*4)+(variable.big_aoe*3),value_else=(variable.single_target*5)+(variable.small_aoe*4)+(variable.big_aoe*4)
  if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
    VarSpBombThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 4) + (num(VarBigAoE) * 3)
  else
    VarSpBombThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 4) + (num(VarBigAoE) * 4)
  end
  -- variable,name=can_spbomb,value=soul_fragments>=variable.spbomb_threshold
  VarCanSpBomb = SoulFragments >= VarSpBombThreshold
  -- variable,name=can_spbomb_soon,value=soul_fragments.total>=variable.spbomb_threshold
  VarCanSpBombSoon = TotalSoulFragments >= VarSpBombThreshold
  -- variable,name=can_spbomb_one_gcd,value=(soul_fragments.total+variable.num_spawnable_souls)>=variable.spbomb_threshold
  VarCanSpBombOneGCD = (TotalSoulFragments + VarNumSpawnableSouls) >= VarSpBombThreshold
  -- variable,name=spburst_threshold,op=setif,condition=talent.fiery_demise&dot.fiery_brand.ticking,value=(variable.single_target*4)+(variable.small_aoe*4)+(variable.big_aoe*3),value_else=(variable.single_target*5)+(variable.small_aoe*4)+(variable.big_aoe*3)
  if S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
    VarSpBurstThreshold = (num(VarST) * 4) + (num(VarSmallAoE) * 4) + (num(VarBigAoE) * 3)
  else
    VarSpBurstThreshold = (num(VarST) * 5) + (num(VarSmallAoE) * 4) + (num(VarBigAoE) * 3)
  end
  -- variable,name=can_spburst,value=soul_fragments>=variable.spburst_threshold
  VarCanSpBurst = SoulFragments >= VarSpBurstThreshold
  -- variable,name=can_spburst_soon,value=soul_fragments.total>=variable.spburst_threshold
  VarCanSpBurstSoon = TotalSoulFragments >= VarSpBurstThreshold
  -- variable,name=can_spburst_one_gcd,value=(soul_fragments.total+variable.num_spawnable_souls)>=variable.spburst_threshold
  VarCanSpBurstOneGCD = (TotalSoulFragments + VarNumSpawnableSouls) >= VarSpBurstThreshold
  -- variable,name=dont_soul_cleave,op=setif,condition=buff.metamorphosis.up&buff.demonsurge_hardcast.up,value=((cooldown.fel_desolation.remains<=gcd.remains+execute_time)&fury<80)|(variable.can_spburst|variable.can_spburst_soon)|(prev_gcd.1.sigil_of_spite|prev_gcd.1.soul_carver),value_else=((cooldown.fel_devastation.remains<=gcd.remains+execute_time)&fury<80)|(variable.can_spbomb|variable.can_spbomb_soon)|(buff.metamorphosis.up&!buff.demonsurge_hardcast.up&buff.demonsurge_spirit_burst.up)|(prev_gcd.1.sigil_of_spite|prev_gcd.1.soul_carver)
  if Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast") then
    VarDontSoulCleave = ((S.FelDesolation:CooldownRemains() <= Player:GCDRemains() + S.SoulCleave:ExecuteTime()) and Player:Fury() < 80) or (VarCanSpBurst or VarCanSpBurstSoon) or (Player:PrevGCD(1, SigilofSpite) or Player:PrevGCD(1, S.SoulCarver))
  else
    VarDontSoulCleave = ((S.FelDevastation:CooldownRemains() <= Player:GCDRemains() + S.SoulCleave:ExecuteTime()) and Player:Fury() < 80) or (VarCanSpBomb or VarCanSpBombSoon) or (Player:BuffUp(S.MetamorphosisBuff) and not S.FelDesolation:IsCastable() and Player:Demonsurge("SpiritBurst")) or (Player:PrevGCD(1, S.SigilofSpite) or Player:PrevGCD(1, S.SoulCarver))
  end
  -- variable,name=fiery_brand_back_before_meta,op=setif,condition=talent.down_in_flames,value=charges>=max_charges|(charges_fractional>=1&cooldown.fiery_brand.full_recharge_time<=gcd.remains+execute_time)|(charges_fractional>=1&((max_charges-(charges_fractional-1))*cooldown.fiery_brand.duration)<=cooldown.metamorphosis.remains),value_else=cooldown.fiery_brand.duration<=cooldown.metamorphosis.remains
  if S.DowninFlames:IsAvailable() then
    VarFBBeforeMeta = S.FieryBrand:Charges() >= S.FieryBrand:MaxCharges() or (S.FieryBrand:ChargesFractional() >= 1 and S.FieryBrand:FullRechargeTime() <= Player:GCDRemains() + S.FieryBrand:ExecuteTime()) or (S.FieryBrand:ChargesFractional() >= 1 and ((S.FieryBrand:MaxCharges() - (S.FieryBrand:ChargesFractional() - 1)) * VarFieryBrandCD) <= S.Metamorphosis:CooldownRemains())
  else
    VarFBBeforeMeta = VarFieryBrandCD <= S.Metamorphosis:CooldownRemains()
  end
  -- variable,name=hold_sof,op=setif,condition=talent.student_of_suffering,value=(buff.student_of_suffering.remains>(1+talent.quickened_sigils))|(!talent.ascending_flame&(dot.sigil_of_flame.remains>(1+talent.quickened_sigils)))|prev_gcd.1.sigil_of_flame|(talent.illuminated_sigils&charges=1&time<(2-talent.quickened_sigils.rank))|cooldown.metamorphosis.up,value_else=cooldown.metamorphosis.up|(cooldown.sigil_of_flame.max_charges>1&talent.ascending_flame&((cooldown.sigil_of_flame.max_charges-(cooldown.sigil_of_flame.charges_fractional-1))*cooldown.sigil_of_flame.duration)>cooldown.metamorphosis.remains)|((prev_gcd.1.sigil_of_flame|dot.sigil_of_flame.remains>(1+talent.quickened_sigils)))
  if S.StudentofSuffering:IsAvailable() then
    VarHoldSoF = (Player:BuffRemains(S.StudentofSufferingBuff) > (1 + num(S.QuickenedSigils:IsAvailable()))) or (not S.AscendingFlame:IsAvailable() and (Target:DebuffRemains(S.SigilofFlameDebuff) > (1 + num(S.QuickenedSigils:IsAvailable())))) or Player:PrevGCD(1, S.SigilofFlame) or (S.IlluminatedSigils:IsAvailable() and S.SigilofFlame:Charges() == 1 and HL.CombatTime() < (2 - S.QuickenedSigils:TalentRank())) or S.Metamorphosis:CooldownUp()
  else
    VarHoldSoF = S.Metamorphosis:CooldownUp() or (S.SigilofFlame:MaxCharges() > 1 and S.AscendingFlame:IsAvailable() and ((S.SigilofFlame:MaxCharges() - (S.SigilofFlame:ChargesFractional() - 1)) * VarSoFCD) > S.Metamorphosis:CooldownRemains()) or (Player:PrevGCD(1, S.SigilofFlame) or Target:DebuffRemains(S.SigilofFlameDebuff) > (1 + num(S.QuickenedSigils:IsAvailable())))
  end
  -- cancel_buff,name=metamorphosis,if=(!buff.demonsurge_soul_sunder.up&!buff.demonsurge_spirit_burst.up&!buff.demonsurge_fel_desolation.up&!buff.demonsurge_consuming_fire.up&!buff.demonsurge_sigil_of_doom.up&cooldown.sigil_of_doom.charges<1)&(cooldown.fel_devastation.remains<(gcd.max*2)|cooldown.metamorphosis.remains<(gcd.max*2))
  -- TODO: Handle cancel_buff.
  -- immolation_aura,if=!(prev_gcd.1.sigil_of_flame&cooldown.metamorphosis.up)
  if S.ImmolationAura:IsCastable() and (not (Player:PrevGCD(1, S.SigilofFlame) and S.Metamorphosis:CooldownUp())) then
    if Cast(S.ImmolationAura) then return "immolation_aura fs 2"; end
  end
  -- sigil_of_flame,if=!variable.hold_sof
  if S.SigilofFlame:IsCastable() and (not VarHoldSoF) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fs 4"; end
  end
  -- fiery_brand,if=!talent.fiery_demise|talent.fiery_demise&((talent.down_in_flames&charges>=max_charges)|(active_dot.fiery_brand=0&variable.fiery_brand_back_before_meta))
  if S.FieryBrand:IsCastable() and (not S.FieryDemise:IsAvailable() or S.FieryDemise:IsAvailable() and ((S.DowninFlames:IsAvailable() and S.FieryBrand:Charges() >= S.FieryBrand:MaxCharges()) or (S.FieryBrandDebuff:AuraActiveCount() == 0 and VarFBBeforeMeta))) then
    if Cast(S.FieryBrand, Settings.Vengeance.OffGCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then return "fiery_brand fs 6"; end
  end
  -- use_items,use_off_gcd=1,if=!buff.metamorphosis.up
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and Player:BuffDown(S.MetamorphosisBuff) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
  -- call_action_list,name=fs_execute,if=fight_remains<20
  if BossFightRemains < 20 then
    local ShouldReturn = FSExecute(); if ShouldReturn then return ShouldReturn; end
  end
  -- run_action_list,name=fel_dev,if=buff.metamorphosis.up&!buff.demonsurge_hardcast.up&(buff.demonsurge_soul_sunder.up|buff.demonsurge_spirit_burst.up)
  if Player:BuffUp(S.MetamorphosisBuff) and not Player:Demonsurge("Hardcast") and (Player:Demonsurge("SoulSunder") or Player:Demonsurge("SpiritBurst")) then
    local ShouldReturn = FelDev(); if ShouldReturn then return ShouldReturn; end
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FelDev()"; end
  end
  -- call_action_list,name=metamorphosis,if=buff.metamorphosis.up&buff.demonsurge_hardcast.up
  if Player:BuffUp(S.MetamorphosisBuff) and Player:Demonsurge("Hardcast") then
    local ShouldReturn = Metamorphosis(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=fel_dev_prep,if=!buff.demonsurge_hardcast.up&(cooldown.fel_devastation.up|(cooldown.fel_devastation.remains<=(gcd.max*2)))
  if not Player:Demonsurge("Hardcast") and (S.FelDevastation:CooldownUp() or (S.FelDevastation:CooldownRemains() <= (Player:GCD() * 2))) then
    local ShouldReturn = FelDevPrep(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=meta_prep,if=(cooldown.metamorphosis.up|cooldown.metamorphosis.remains<=(gcd.max*3))&!cooldown.fel_devastation.up&!buff.demonsurge_soul_sunder.up&!buff.demonsurge_spirit_burst.up
  if (S.Metamorphosis:CooldownUp() or S.Metamorphosis:CooldownRemains() <= (Player:GCD() * 3)) and S.FelDevastation:CooldownDown() and not Player:Demonsurge("SoulSunder") and not Player:Demonsurge("SpiritBurst") then
    local ShouldReturn = MetaPrep(); if ShouldReturn then return ShouldReturn; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.CommonsOGCD.GCDasOffGCD.TheHunt, not Target:IsInRange(50)) then return "the_hunt fs 8"; end
  end
  -- soul_carver,if=(!talent.fiery_demise|talent.fiery_demise&dot.fiery_brand.ticking)&(((soul_fragments.total+3)<=6)&fury>=15&!prev_gcd.1.sigil_of_spite)
  if S.SoulCarver:IsCastable() and ((not S.FieryDemise:IsAvailable() or S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0) and (((TotalSoulFragments + 3) <= 6) and Player:Fury() >= 15 and not Player:PrevGCD(1, S.SigilofSpite))) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then return "soul_carver fs 10"; end
  end
  -- sigil_of_spite,if=(((variable.can_spbomb|(buff.metamorphosis.up&variable.can_spburst))&fury>=40))|((variable.can_spbomb_soon|(buff.metamorphosis.up&variable.can_spburst_soon))|soul_fragments<=1)
  if S.SigilofSpite:IsCastable() and (((VarCanSpBomb or (Player:BuffUp(S.MetamorphosisBuff) and VarCanSpBurst)) and Player:Fury() >= 40) or ((VarCanSpBombSoon or (Player:BuffUp(S.MetamorphosisBuff) and VarCanSpBurstSoon)) or SoulFragments <= 1)) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fs 12"; end
  end
  -- bulk_extraction,if=spell_targets>=5
  if S.BulkExtraction:IsCastable() and (EnemiesCount8yMelee >= 5) then
    if Cast(S.BulkExtraction, Settings.Vengeance.OffGCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then return "bulk_extraction fs 14"; end
  end
  -- spirit_burst,if=talent.spirit_bomb&variable.can_spburst
  if S.SpiritBurst:IsReady() and (VarCanSpBurst) then
    if Cast(S.SpiritBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_burst fs 16"; end
  end
  -- spirit_bomb,if=variable.can_spbomb
  if S.SpiritBomb:IsReady() and (VarCanSpBomb) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then return "spirit_bomb fs 18"; end
  end
  -- felblade,if=(fury<40&((buff.metamorphosis.up&(variable.can_spburst|variable.can_spburst_soon))|(!buff.metamorphosis.up&(variable.can_spbomb|variable.can_spbomb_soon))))|fury<30
  if S.Felblade:IsCastable() and ((Player:Fury() < 40 and ((Player:BuffUp(S.MetamorphosisBuff) and (VarCanSpBurst or VarCanSpBurstSoon)) or (Player:BuffDown(S.MetamorphosisBuff) and (VarCanSpBomb or VarCanSpBombSoon)))) or Player:Fury() < 30) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 20"; end
  end
  -- fracture,if=(fury<40&((buff.metamorphosis.up&(variable.can_spburst|variable.can_spburst_soon))|(!buff.metamorphosis.up&(variable.can_spbomb|variable.can_spbomb_soon))))|((buff.metamorphosis.up&variable.can_spburst_one_gcd)|(!buff.metamorphosis.up&variable.can_spbomb_one_gcd))
  if S.Fracture:IsCastable() and ((Player:Fury() < 40 and ((Player:BuffUp(S.MetamorphosisBuff) and (VarCanSpBurst or VarCanSpBurstSoon)) or (Player:BuffDown(S.MetamorphosisBuff) and (VarCanSpBomb or VarCanSpBombSoon)))) or ((Player:BuffUp(S.MetamorphosisBuff) and VarCanSpBurstOneGCD) or (Player:BuffDown(S.MetamorphosisBuff) and VarCanSpBombOneGCD))) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fs 22"; end
  end
  -- soul_sunder,if=!variable.dont_soul_cleave
  -- soul_cleave,if=!variable.dont_soul_cleave
  if not VarDontSoulCleave then
    if S.SoulSunder:IsReady() then
      if Cast(S.SoulSunder, nil, nil, not IsInMeleeRange) then return "soul_sunder fs 24"; end
    end
    if S.SoulCleave:IsReady() then
      if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then return "soul_cleave fs 26"; end
    end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then return "fracture fs 28"; end
  end
  -- Manually added: shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then return "shear fs 30"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fs 32"; end
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
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=num_spawnable_souls,op=reset,default=0
    VarNumSpawnableSouls = 0
    -- variable,name=num_spawnable_souls,op=max,value=2,if=talent.fracture&cooldown.fracture.charges_fractional>=1&!buff.metamorphosis.up
    if S.Fracture:IsAvailable() and S.Fracture:ChargesFractional() >= 1 and Player:BuffDown(S.MetamorphosisBuff) then
      VarNumSpawnableSouls = 2
    end
    -- variable,name=num_spawnable_souls,op=max,value=3,if=talent.fracture&cooldown.fracture.charges_fractional>=1&buff.metamorphosis.up
    if S.Fracture:IsAvailable() and S.Fracture:ChargesFractional() >= 1 and Player:BuffUp(S.MetamorphosisBuff) then
      VarNumSpawnableSouls = 3
    end
    -- variable,name=num_spawnable_souls,op=max,value=1,if=talent.soul_sigils&cooldown.sigil_of_flame.up
    if S.SoulSigils:IsAvailable() and S.SigilofFlame:CooldownUp() then
      VarNumSpawnableSouls = mathmax(VarNumSpawnableSouls, 1)
    end
    -- variable,name=num_spawnable_souls,op=add,value=1,if=talent.soul_carver&(cooldown.soul_carver.remains>(cooldown.soul_carver.duration-3))
    if S.SoulCarver:IsAvailable() and S.SoulCarver:CooldownRemains() > 57 then
      VarNumSpawnableSouls = VarNumSpawnableSouls + 1
    end
    -- auto_attack
    -- retarget_auto_attack,line_cd=1,target_if=min:debuff.reavers_mark.remains,if=hero_tree.aldrachi_reaver
    -- TODO: Add retarget
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

  HR.Print("Vengeance Demon Hunter rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(581, APL, Init);

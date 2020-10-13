--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Fire;
local I = Item.Mage.Fire;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.IgnitionMagesFuse:ID(),
  I.RotcrustedVoodooDoll:ID(),
  I.BalefireBranch:ID(),
  I.AzurethoseSingedPlumage:ID(),
  I.TzanesBarkspines:ID(),
  I.AncientKnotofWisdomAlliance:ID(),
  I.TidestormCodex:ID(),
  I.AncientKnotofWisdomHorde:ID(),
  I.PocketsizedComputationDevice:ID(),
  I.ShiverVenomRelic:ID(),
  I.NeuralSynapseEnhancer:ID(),
  I.AquipotentNautilus:ID(),
  I.AzsharasFontofPower:ID(),
  I.ShockbitersFang:ID(),
  I.ForbiddenObsidianClaw:ID(),
  I.ManifestoofMadness:ID(),
  I.DreadGladiatorsMedallion:ID(),
  I.DreadCombatantsInsignia:ID(),
  I.DreadCombatantsMedallion:ID(),
  I.DreadGladiatorsBadge:ID(),
  I.DreadAspirantsMedallion:ID(),
  I.DreadAspirantsBadge:ID(),
  I.SinisterGladiatorsMedallion:ID(),
  I.SinisterGladiatorsBadge:ID(),
  I.SinisterAspirantsMedallion:ID(),
  I.SinisterAspirantsBadge:ID(),
  I.NotoriousGladiatorsMedallion:ID(),
  I.NotoriousGladiatorsBadge:ID(),
  I.NotoriousAspirantsMedallion:ID(),
  I.NotoriousAspirantsBadge:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;
local IgnoreCombustion;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Fire = HR.GUISettings.APL.Mage.Fire
};

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- Variables
local VarHoldCombustionThreshold = 0;
local VarHotStreakFlamestrike = 2 * num(S.FlamePatch:IsAvailable()) + 99 * num(not S.FlamePatch:IsAvailable());
local VarHardCastFlamestrike = 3 * num(S.FlamePatch:IsAvailable()) + 99 * num(not S.FlamePatch:IsAvailable());
local VarDelayFlamestrike = 0;
local VarFireBlastPooling = 0;
local VarPhoenixPooling = 0;
local VarCombustionOnUse = 0;
local VarFontDoubleOnUse = 0;
local VarFontPrecombatChannel = 0;
local VarTimeToCombusion = 0;
local VarKindlingReduction = 0;
local VarOnUseCutoff = 0;

HL:RegisterForEvent(function()
  VarHoldCombustionThreshold = 0
  VarHotStreakFlamestrike = 2 * num(S.FlamePatch:IsAvailable()) + 99 * num(not S.FlamePatch:IsAvailable())
  VarHardCastFlamestrike = 3 * num(S.FlamePatch:IsAvailable()) + 99 * num(not S.FlamePatch:IsAvailable())
  VarDelayFlamestrike = 0
  VarFireBlastPooling = 0
  VarPhoenixPooling = 0
  VarCombustionOnUse = 0
  VarFontDoubleOnUse = 0
  VarFontPrecombatChannel = 0
  VarTimeToCombusion = 0
  VarKindlingReduction = 0
  VarOnUseCutoff = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {40}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Fire.UseSplashData then
      HL.GetEnemies(range, nil, true, Target)
      return Cache.EnemiesCount[range]
    else
      UpdateRanges()
      Everyone.AoEToggleEnemiesUpdate()
      return Cache.EnemiesCount[40]
    end
  else
    return 1
  end
end

HL:RegisterForEvent(function()
  S.Pyroblast:RegisterInFlight();
  S.Fireball:RegisterInFlight();
  S.Meteor:RegisterInFlight();
  S.PhoenixFlames:RegisterInFlight();
  S.Pyroblast:RegisterInFlight(S.CombustionBuff);
  S.Fireball:RegisterInFlight(S.CombustionBuff);
end, "LEARNED_SPELL_IN_TAB")
S.Pyroblast:RegisterInFlight()
S.Fireball:RegisterInFlight()
S.Meteor:RegisterInFlight()
S.PhoenixFlames:RegisterInFlight()
S.Pyroblast:RegisterInFlight(S.CombustionBuff)
S.Fireball:RegisterInFlight(S.CombustionBuff)

function S.Firestarter:ActiveStatus()
    return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90)) and 1 or 0
end

function S.Firestarter:ActiveRemains()
    return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90, 3) or 0) or 0
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect 3"; end
  end
  -- variable,name=disable_combustion,op=reset
  -- Above is ignored, as we're using a settings variable
  if Everyone.TargetIsValid() then
    -- variable,name=combustion_on_use,op=set,value=equipped.manifesto_of_madness|equipped.gladiators_badge|equipped.gladiators_medallion|equipped.ignition_mages_fuse|equipped.tzanes_barkspines|equipped.azurethos_singed_plumage|equipped.ancient_knot_of_wisdom|equipped.shockbiters_fang|equipped.neural_synapse_enhancer|equipped.balefire_branch
    if (true) then
      VarCombustionOnUse = num(I.ManifestoofMadness:IsEquipped() or I.NotoriousAspirantsBadge:IsEquipped() or I.NotoriousGladiatorsBadge:IsEquipped() or I.SinisterGladiatorsBadge:IsEquipped() or I.SinisterAspirantsBadge:IsEquipped() or I.DreadGladiatorsBadge:IsEquipped() or I.DreadAspirantsBadge:IsEquipped() or I.DreadCombatantsInsignia:IsEquipped() or I.NotoriousAspirantsMedallion:IsEquipped() or I.NotoriousGladiatorsMedallion:IsEquipped() or I.SinisterGladiatorsMedallion:IsEquipped() or I.SinisterAspirantsMedallion:IsEquipped() or I.DreadGladiatorsMedallion:IsEquipped() or I.DreadAspirantsMedallion:IsEquipped() or I.DreadCombatantsMedallion:IsEquipped() or I.IgnitionMagesFuse:IsEquipped() or I.TzanesBarkspines:IsEquipped() or I.AzurethoseSingedPlumage:IsEquipped() or I.AncientKnotofWisdomAlliance:IsEquipped() or I.AncientKnotofWisdomHorde:IsEquipped() or I.ShockbitersFang:IsEquipped() or I.NeuralSynapseEnhancer:IsEquipped() or I.BalefireBranch:IsEquipped())
    end
    -- variable,name=font_double_on_use,op=set,value=equipped.azsharas_font_of_power&variable.combustion_on_use
    if (true) then
      VarFontDoubleOnUse = num(I.AzsharasFontofPower:IsEquipped() and bool(VarCombustionOnUse))
    end
    -- variable,name=font_of_power_precombat_channel,op=set,value=18,if=variable.font_double_on_use&!talent.firestarter.enabled&variable.font_of_power_precombat_channel=0
    if (bool(VarFontDoubleOnUse) and not S.Firestarter:IsAvailable() and VarFontPrecombatChannel == 0) then
      VarFontPrecombatChannel = 18
    end
    -- variable,name=on_use_cutoff,op=set,value=20*variable.combustion_on_use&!variable.font_double_on_use+40*variable.font_double_on_use+25*equipped.azsharas_font_of_power&!variable.font_double_on_use+8*equipped.manifesto_of_madness&!variable.font_double_on_use
    if (true) then
      VarOnUseCutoff = 20 * num(bool(VarCombustionOnUse) and not bool(VarFontDoubleOnUse)) + 40 * VarFontDoubleOnUse + 25 * num(I.AzsharasFontofPower:IsEquipped() and not bool(VarFontDoubleOnUse)) + 8 * num(I.ManifestoofMadness:IsEquipped() and not bool(VarFontDoubleOnUse))
    end
    -- variable,name=hold_combustion_threshold,op=reset,default=20
    if (true) then
      VarHoldCombustionThreshold = 20
    end
    -- variable,name=hot_streak_flamestrike,op=set,if=variable.hot_streak_flamestrike=0,value=2*talent.flame_patch.enabled+99*!talent.flame_patch.enabled
    if (VarHotStreakFlamestrike == 0) then
      VarHotStreakFlamestrike = 2 * num(S.FlamePatch:IsAvailable()) + 99 * num(not S.FlamePatch:IsAvailable())
    end
    -- variable,name=hard_cast_flamestrike,op=set,if=variable.hard_cast_flamestrike=0,value=3*talent.flame_patch.enabled+99*!talent.flame_patch.enabled
    if (VarHardCastFlamestrike == 0) then
      VarHardCastFlamestrike = 3 * num(S.FlamePatch:IsAvailable()) + 99 * num(not S.FlamePatch:IsAvailable())
    end
    -- variable,name=delay_flamestrike,default=25,op=reset
    if (true) then
      VarDelayFlamestrike = 25
    end
    if (true) then
      VarKindlingReduction = 0.2
    end
    -- snapshot_stats
    -- use_item,name=azsharas_font_of_power,if=!variable.disable_combustion
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and not IgnoreCombustion then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 9"; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 10"; end
    end
    -- potion
    if I.SuperiorBattlePotionofIntellect:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.SuperiorBattlePotionofIntellect) then return "superior_battle_potion_of_intellect 12"; end
    end
    -- pyroblast
    if S.Pyroblast:IsCastableP() and not Player:IsMoving()  then
      if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 14"; end
    end
    -- scorch
    if S.Scorch:IsCastableP() then
      if HR.Cast(S.Scorch, nil, nil, 40) then return "scorch"; end
    end
  end
end

local function ActiveTalents()
  -- living_bomb,if=active_enemies>1&buff.combustion.down&(variable.time_to_combustion>cooldown.living_bomb.duration|variable.time_to_combustion<=0|variable.disable_combustion)
  if S.LivingBomb:IsCastableP() and (EnemiesCount > 1 and Player:BuffDownP(S.CombustionBuff) and (VarTimeToCombusion > 12 * Player:SpellHaste() or VarTimeToCombusion <= 0 or IgnoreCombustion)) then
    if HR.Cast(S.LivingBomb, nil, nil, 40) then return "living_bomb 16"; end
  end
  -- meteor,if=!variable.disable_combustion&variable.time_to_combustion<=0|(buff.rune_of_power.up|cooldown.rune_of_power.remains>target.time_to_die&action.rune_of_power.charges<1|!talent.rune_of_power.enabled)&(cooldown.meteor.duration<variable.time_to_combustion|target.time_to_die<variable.time_to_combustion|variable.disable_combustion)
  if S.Meteor:IsCastableP() and (not IgnoreCombustion and VarTimeToCombusion <= 0 or (Player:BuffP(S.RuneofPowerBuff) or S.RuneofPower:CooldownRemainsP() > Target:TimeToDie() and S.RuneofPower:Charges() < 1 or not S.RuneofPower:IsAvailable()) and (45 < VarTimeToCombusion or Target:TimeToDie() < VarTimeToCombusion or IgnoreCombustion)) then
    if HR.Cast(S.Meteor, nil, nil, 40) then return "meteor 32"; end
  end
  -- dragons_breath,if=talent.alexstraszas_fury.enabled&(buff.combustion.down&!buff.hot_streak.react|buff.combustion.up&action.fire_blast.charges<action.fire_blast.max_charges&!buff.hot_streak.react)
  if S.DragonsBreath:IsCastableP(12) and (S.AlexstraszasFury:IsAvailable() and (Player:BuffDownP(S.CombustionBuff) and Player:BuffDownP(S.HotStreakBuff) or Player:BuffP(S.CombustionBuff) and S.FireBlast:Charges() < S.FireBlast:MaxCharges() and not Player:BuffP(S.HotStreakBuff))) then
    if HR.Cast(S.DragonsBreath, nil, nil, 12) then return "dragons_breath 34"; end
  end
end

local function CombustionPhase()
  -- lights_judgment,if=buff.combustion.down
  if S.LightsJudgment:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 234"; end
  end
  -- bag_of_tricks,if=buff.combustion.down
  if S.BagofTricks:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 298"; end
  end
  -- living_bomb,if=active_enemies>1&buff.combustion.down
  if S.LivingBomb:IsReadyP() and (EnemiesCount > 1 and Player:BuffDownP(S.CombustionBuff)) then
    if HR.Cast(S.LivingBomb, nil, nil, 40) then return "living_bomb 242"; end
  end
  -- blood_of_the_enemy
  if S.BloodoftheEnemy:IsCastableP() then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 244"; end
  end
  -- memory_of_lucid_dreams
  if S.MemoryofLucidDreams:IsCastableP() then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 246"; end
  end
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastableP() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 247"; end
  end
  -- fire_blast,use_while_casting=1,use_off_gcd=1,if=charges>=1&((action.fire_blast.charges_fractional+(buff.combustion.remains-buff.blaster_master.duration)%cooldown.fire_blast.duration-(buff.combustion.remains)%(buff.blaster_master.duration-0.5))>=0|!azerite.blaster_master.enabled|!talent.flame_on.enabled|buff.combustion.remains<=buff.blaster_master.duration|buff.blaster_master.remains<0.5|equipped.hyperthread_wristwraps&cooldown.hyperthread_wristwraps_300142.remains<5)&buff.combustion.up&(!action.scorch.executing&!action.pyroblast.in_flight&buff.heating_up.up|action.scorch.executing&buff.hot_streak.down&(buff.heating_up.down|azerite.blaster_master.enabled)|azerite.blaster_master.enabled&talent.flame_on.enabled&action.pyroblast.in_flight&buff.heating_up.down&buff.hot_streak.down)
  if S.FireBlast:IsReady() and (S.FireBlast:ChargesP() >= 1 and ((S.FireBlast:ChargesFractional() + (Player:BuffRemainsP(S.CombustionBuff) - S.BlasterMasterBuff:BaseDuration()) % S.FireBlast:Cooldown() - (Player:BuffRemainsP(S.CombustionBuff)) % (S.BlasterMasterBuff:BaseDuration() - 0.5)) >= 0 or not S.BlasterMaster:AzeriteEnabled() or not S.FlameOn:IsAvailable() or Player:BuffRemainsP(S.CombustionBuff) <= S.BlasterMasterBuff:BaseDuration() or Player:BuffRemainsP(S.BlasterMasterBuff) < 0.5 or I.HyperthreadWristwraps:IsEquipped() and I.HyperthreadWristwraps:CooldownRemains() < 5) and Player:BuffP(S.Combustion) and (not Player:IsCasting(S.Scorch) and not S.Pyroblast:InFlight() and Player:BuffP(S.HeatingUpBuff) or Player:IsCasting(S.Scorch) and Player:BuffDownP(S.HotStreakBuff) and (Player:BuffDownP(S.HeatingUpBuff) or S.BlasterMaster:AzeriteEnabled()) or S.BlasterMaster:AzeriteEnabled() and S.FlameOn:IsAvailable() and S.Pyroblast:InFlight() and Player:BuffP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff))) then
    if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 248"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&buff.combustion.down
  if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.CombustionBuff)) then
    if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return "rune_of_power 250"; end
  end
  -- fire_blast,use_while_casting=1,if=azerite.blaster_master.enabled&(essence.memory_of_lucid_dreams.major|!essence.memory_of_lucid_dreams.minor)&talent.meteor.enabled&talent.flame_on.enabled&buff.blaster_master.down&(talent.rune_of_power.enabled&action.rune_of_power.executing&action.rune_of_power.execute_remains<0.6|(variable.time_to_combustion<=0|buff.combustion.up)&!talent.rune_of_power.enabled&!action.pyroblast.in_flight&!action.fireball.in_flight)
  if S.FireBlast:IsReady() and (S.BlasterMaster:AzeriteEnabled() and (Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) or not Spell:EssenceEnabled(AE.MemoryofLucidDreams)) and S.Meteor:IsAvailable() and S.FlameOn:IsAvailable() and Player:BuffDownP(S.BlasterMasterBuff) and (S.RuneofPower:IsAvailable() and Player:IsCasting(S.RuneofPower) and Player:CastRemains() < 0.6 or (VarTimeToCombusion <= 0 or Player:BuffP(S.CombustionBuff)) and not S.RuneofPower:IsAvailable() and not S.Pyroblast:InFlight() and not S.Fireball:InFlight())) then
    if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 255"; end
  end
  -- call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  end
  -- combustion,use_off_gcd=1,use_while_casting=1,if=((action.meteor.in_flight&action.meteor.in_flight_remains<=0.5)|!talent.meteor.enabled&(essence.memory_of_lucid_dreams.major|buff.hot_streak.react|action.scorch.executing&action.scorch.execute_remains<0.5|action.pyroblast.executing&action.pyroblast.execute_remains<0.5))&(buff.rune_of_power.up|!talent.rune_of_power.enabled)
  -- Increased CastRemains checks to 1s, up from 0.5s, to help visibility
  if S.Combustion:IsCastableP() and (((S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) or not S.Meteor:IsAvailable() and (Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) or Player:BuffP(S.HotStreakBuff) or Player:IsCasting(S.Scorch) and Player:CastRemains() < 1 or Player:IsCasting(S.Pyroblast) and Player:CastRemains() < 1)) and (Player:BuffP(S.RuneofPowerBuff) or not S.RuneofPower:IsAvailable())) then
    if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion 265"; end
  end
  -- potion
  if I.SuperiorBattlePotionofIntellect:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.SuperiorBattlePotionofIntellect) then return "superior_battle_potion_of_intellect 288"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastableP() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 290"; end
  end
  -- berserking
  if S.Berserking:IsCastableP() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 292"; end
  end
  -- fireblood
  if S.Fireblood:IsCastableP() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 294"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastableP() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 296"; end
  end
  -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>2)|active_enemies>6)&buff.hot_streak.react&!azerite.blaster_master.enabled
  if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 2) or EnemiesCount > 6) and Player:BuffP(S.HotStreakBuff) and not S.BlasterMaster:AzeriteEnabled()) then
    if HR.Cast(S.Flamestrike, nil, nil, 40) then return "flamestrike 300"; end
  end
  -- pyroblast,if=buff.pyroclasm.react&buff.combustion.remains>cast_time
  if S.Pyroblast:IsCastableP() and not Player:IsMoving() and (Player:BuffP(S.PyroclasmBuff) and Player:BuffRemainsP(S.CombustionBuff) > S.Pyroblast:CastTime()) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 320"; end
  end
  -- pyroblast,if=buff.hot_streak.react
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 330"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up
  if S.Pyroblast:IsCastableP() and not Player:IsMoving() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff)) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 390"; end
  end
  -- phoenix_flames
  if S.PhoenixFlames:IsCastableP() then
    if HR.Cast(S.PhoenixFlames, nil, nil, 40) then return "phoenix_flames 396"; end
  end
  -- scorch,if=buff.combustion.remains>cast_time&buff.combustion.up|buff.combustion.down&cooldown.combustion.remains<cast_time
  if S.Scorch:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) > S.Scorch:CastTime() and Player:BuffP(S.CombustionBuff) or Player:BuffDownP(S.CombustionBuff) and S.Combustion:CooldownRemainsP() < S.Scorch:CastTime()) then
    if HR.Cast(S.Scorch, nil, nil, 40) then return "scorch 398"; end
  end
  -- living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
  if S.LivingBomb:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and EnemiesCount > 1) then
    if HR.Cast(S.LivingBomb, nil, nil, 40) then return "living_bomb 410"; end
  end
  -- dragons_breath,if=buff.combustion.remains<gcd.max&buff.combustion.up
  if S.DragonsBreath:IsCastableP(12) and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and Player:BuffP(S.CombustionBuff)) then
    if HR.Cast(S.DragonsBreath, nil, nil, 12) then return "dragons_breath 420"; end
  end
  -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
  if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
    if HR.Cast(S.Scorch, nil, nil, 40) then return "scorch 426"; end
  end
end

local function ItemsCombustion()
  -- use_item,name=ignition_mages_fuse
  if I.IgnitionMagesFuse:IsEquipReady() then
    if HR.Cast(I.IgnitionMagesFuse, nil, Settings.Commons.TrinketDisplayStyle) then return "ignition_mages_fuse combustion"; end
  end
  -- use_item,name=hyperthread_wristwraps,if=buff.combustion.up&action.fire_blast.charges=0&action.fire_blast.recharge_time>gcd.max
  if I.HyperthreadWristwraps:IsEquipReady() and (Player:BuffP(S.CombustionBuff) and S.FireBlast:Charges() == 0 and S.FireBlast:RechargeP() > Player:GCD()) then
    if HR.Cast(I.HyperthreadWristwraps, nil, Settings.Commons.TrinketDisplayStyle) then return "hyperthread_wristwraps combustion"; end
  end
  -- use_item,name=manifesto_of_madness
  if I.ManifestoofMadness:IsEquipReady() then
    if HR.Cast(I.ManifestoofMadness, nil, Settings.Commons.TrinketDisplayStyle) then return "manifesto_of_madness combustion"; end
  end
  -- cancel_buff,use_off_gcd=1,name=manifesto_of_madness_chapter_one,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  -- use_item,use_off_gcd=1,name=azurethos_singed_plumage,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  if I.AzurethoseSingedPlumage:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.AzurethoseSingedPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "azurethos_singed_plumage combustion"; end
  end
  -- use_item,use_off_gcd=1,effect_name=gladiators_badge,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  -- One line per badge
  if I.NotoriousAspirantsBadge:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.NotoriousAspirantsBadge, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_badge combustion"; end
  end
  if I.NotoriousGladiatorsBadge:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.NotoriousGladiatorsBadge, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_badge combustion"; end
  end
  if I.SinisterGladiatorsBadge:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.SinisterGladiatorsBadge, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_badge combustion"; end
  end
  if I.SinisterAspirantsBadge:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.SinisterAspirantsBadge, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_badge combustion"; end
  end
  if I.DreadGladiatorsBadge:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.DreadGladiatorsBadge, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_badge combustion"; end
  end
  if I.DreadAspirantsBadge:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.DreadAspirantsBadge, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_badge combustion"; end
  end
  -- use_item,use_off_gcd=1,effect_name=gladiators_medallion,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  -- One line per medallion
  if I.NotoriousAspirantsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.NotoriousAspirantsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  if I.NotoriousGladiatorsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.NotoriousGladiatorsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  if I.SinisterGladiatorsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.SinisterGladiatorsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  if I.SinisterAspirantsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.SinisterAspirantsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  if I.DreadGladiatorsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.DreadGladiatorsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  if I.DreadAspirantsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.DreadAspirantsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  if I.DreadCombatantsMedallion:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.DreadCombatantsMedallion, nil, Settings.Commons.TrinketDisplayStyle) then return "gladiators_medallion combustion"; end
  end
  -- use_item,use_off_gcd=1,name=balefire_branch,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  if I.BalefireBranch:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.BalefireBranch, nil, Settings.Commons.TrinketDisplayStyle) then return "balefire_branch combustion"; end
  end
  -- use_item,use_off_gcd=1,name=shockbiters_fang,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  if I.ShockbitersFang:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.ShockbitersFang, nil, Settings.Commons.TrinketDisplayStyle) then return "shockbiters_fang combustion"; end
  end
  -- use_item,use_off_gcd=1,name=tzanes_barkspines,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  if I.TzanesBarkspines:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.TzanesBarkspines, nil, Settings.Commons.TrinketDisplayStyle) then return "tzanes_barkspines combustion"; end
  end
  -- use_item,use_off_gcd=1,name=ancient_knot_of_wisdom,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  -- Two conditions, since the horde and alliance trinkets have different IDs
  if I.AncientKnotofWisdomAlliance:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.AncientKnotofWisdomAlliance, nil, Settings.Commons.TrinketDisplayStyle) then return "ancient_knot_of_wisdom combustion"; end
  end
  if I.AncientKnotofWisdomHorde:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.AncientKnotofWisdomHorde, nil, Settings.Commons.TrinketDisplayStyle) then return "ancient_knot_of_wisdom combustion"; end
  end
  -- use_item,use_off_gcd=1,name=neural_synapse_enhancer,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  if I.NeuralSynapseEnhancer:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.NeuralSynapseEnhancer, nil, Settings.Commons.TrinketDisplayStyle) then return "neural_synapse_enhancer combustion"; end
  end
  -- use_item,use_off_gcd=1,name=malformed_heralds_legwraps,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
  if I.MalformedHeraldsLegwraps:IsEquipReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and Player:PrevGCDP(1, S.Meteor)) then
    if HR.Cast(I.MalformedHeraldsLegwraps, nil, Settings.Commons.TrinketDisplayStyle) then return "malformed_heralds_legwraps combustion"; end
  end
end

local function ItemsHighPriority()
  -- call_action_list,name=items_combustion,if=!variable.disable_combustion&variable.time_to_combustion<=0
  if (not IgnoreCombustion and VarTimeToCombusion <= 0) then
    local ShouldReturn = ItemsCombustion(); if ShouldReturn then return ShouldReturn; end
  end
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
  -- use_item,name=manifesto_of_madness,if=!equipped.azsharas_font_of_power&variable.time_to_combustion<8
  if I.ManifestoofMadness:IsEquipReady() and (not I.AzsharasFontofPower:IsEquipped() and VarTimeToCombusion < 8) then
    if HR.Cast(I.ManifestoofMadness, nil, Settings.Commons.TrinketDisplayStyle) then return "manifesto_of_madness high_priority"; end
  end
  -- use_item,name=azsharas_font_of_power,if=variable.time_to_combustion<=5+15*variable.font_double_on_use&variable.time_to_combustion>0&!variable.disable_combustion
  if I.AzsharasFontofPower:IsEquipReady() and (VarTimeToCombusion <= (5 + 15 * VarFontDoubleOnUse) and VarTimeToCombusion > 0 and not IgnoreCombustion) then
    if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power high_priority"; end
  end
  -- use_item,name=rotcrusted_voodoo_doll,if=variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.RotcrustedVoodooDoll:IsEquipReady() and (VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.RotcrustedVoodooDoll, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "rotcrusted_voodoo_doll high_priority"; end
  end
  -- use_item,name=aquipotent_nautilus,if=variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.AquipotentNautilus:IsEquipReady() and (VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.AquipotentNautilus, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "aquipotent_nautilus high_priority"; end
  end
  -- use_item,name=shiver_venom_relic,if=variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.ShiverVenomRelic:IsEquipReady() and (VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.ShiverVenomRelic, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "shiver_venom_relic high_priority"; end
  end
  -- use_item,name=forbidden_obsidian_claw,if=variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.ForbiddenObsidianClaw:IsEquipReady() and (VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.ForbiddenObsidianClaw, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "forbidden_obsidian_claw high_priority"; end
  end
  -- use_item,effect_name=harmonic_dematerializer
  if Everyone.PSCDEquipReady() and S.HarmonicDematerializer:IsAvailable() then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "harmonic_dematerializer high_priority"; end
  end
  -- use_item,name=malformed_heralds_legwraps,if=variable.time_to_combustion>=55&buff.combustion.down&variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.MalformedHeraldsLegwraps:IsEquipReady() and (VarTimeToCombusion >= 55 and Player:BuffDownP(S.CombustionBuff) and VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.MalformedHeraldsLegwraps, nil, Settings.Commons.TrinketDisplayStyle) then return "malformed_heralds_legwraps high_priority"; end
  end
  -- use_item,name=ancient_knot_of_wisdom,if=variable.time_to_combustion>=55&buff.combustion.down&variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  -- Two conditions, since the horde and alliance trinkets have different IDs
  if I.AncientKnotofWisdomAlliance:IsEquipReady() and (VarTimeToCombusion >= 55 and Player:BuffDownP(S.CombustionBuff) and VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.AncientKnotofWisdomAlliance, nil, Settings.Commons.TrinketDisplayStyle) then return "ancient_knot_of_wisdom high_priority"; end
  end
  if I.AncientKnotofWisdomHorde:IsEquipReady() and (VarTimeToCombusion >= 55 and Player:BuffDownP(S.CombustionBuff) and VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.AncientKnotofWisdomHorde, nil, Settings.Commons.TrinketDisplayStyle) then return "ancient_knot_of_wisdom high_priority"; end
  end
  -- use_item,name=neural_synapse_enhancer,if=variable.time_to_combustion>=45&buff.combustion.down&variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.NeuralSynapseEnhancer:IsEquipReady() and (VarTimeToCombusion >= 45 and Player:BuffDownP(S.CombustionBuff) and VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.NeuralSynapseEnhancer, nil, Settings.Commons.TrinketDisplayStyle) then return "neural_synapse_enhancer high_priority"; end
  end
end

local function ItemsLowPriority()
  -- use_item,name=tidestorm_codex,if=variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if I.TidestormCodex:IsEquipReady() and (VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "tidestorm_codex low_priority"; end
  end
  -- use_item,effect_name=cyclotronic_blast,if=variable.time_to_combustion>variable.on_use_cutoff|variable.disable_combustion
  if Everyone.CyclotronicBlastReady() and (VarTimeToCombusion > VarOnUseCutoff or IgnoreCombustion) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "cyclotronic_blast low_priority"; end
  end
end

local function RopPhase()
  -- flamestrike,if=(active_enemies>=variable.hot_streak_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))&buff.hot_streak.react
  if S.Flamestrike:IsCastableP() and ((EnemiesCount >= VarHotStreakFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) and Player:BuffP(S.HotStreakBuff)) then
    if HR.Cast(S.Flamestrike, nil, nil, 40) then return "flamestrike 432"; end
  end
  -- pyroblast,if=buff.hot_streak.react
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 450"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!(active_enemies>=variable.hard_cast_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))&!firestarter.active&(!buff.heating_up.react&!buff.hot_streak.react&!prev_off_gcd.fire_blast&(action.fire_blast.charges>=2|(action.phoenix_flames.charges>=1&talent.phoenix_flames.enabled)|(talent.alexstraszas_fury.enabled&cooldown.dragons_breath.ready)|(talent.searing_touch.enabled&target.health.pct<=30|spell_crit>=1)))
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.FireBlast:IsCastableP() and (not (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) and not bool(S.Firestarter:ActiveStatus()) and (not Player:BuffP(S.HeatingUpBuff) and not Player:BuffP(S.HotStreakBuff) and not Player:PrevGCDP(1, S.FireBlast) and (S.FireBlast:Charges() >= 2 or (S.PhoenixFlames:Charges() >= 1 and S.PhoenixFlames:IsAvailable()) or (S.AlexstraszasFury:IsAvailable() and S.DragonsBreath:CooldownUpP()) or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 or Player:CritChancePct() >= 85)))) then
    if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 454"; end
  end
  -- call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  end
  -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains&buff.rune_of_power.remains>cast_time
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemainsP(S.PyroclasmBuff) and Player:BuffRemainsP(S.RuneofPowerBuff) > S.Pyroblast:CastTime()) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 486"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!(active_enemies>=variable.hard_cast_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))&!firestarter.active&(buff.heating_up.react&spell_crit<1&(target.health.pct>=30|!talent.searing_touch.enabled))
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.FireBlast:IsCastableP() and (not (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) and not bool(S.Firestarter:ActiveStatus()) and (Player:BuffP(S.HeatingUpBuff) and Player:CritChancePct() < 85 and (Target:HealthPercentage() >= 30 or not S.SearingTouch:IsAvailable()))) then
    if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 502"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!(active_enemies>=variable.hard_cast_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))&!firestarter.active&(talent.searing_touch.enabled&target.health.pct<=30|spell_crit>=1)&(buff.heating_up.react&!action.scorch.executing|!buff.heating_up.react&!buff.hot_streak.react)
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.FireBlast:IsCastableP() and (not (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) and not bool(S.Firestarter:ActiveStatus()) and (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 or Player:CritChancePct() >= 85) and (Player:BuffP(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff))) then
    if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 512"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up&(talent.searing_touch.enabled&target.health.pct<=30|spell_crit>=1)&!(active_enemies>=variable.hot_streak_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff) and (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 or Player:CritChancePct() >= 85) and not (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion))) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 530"; end
  end
  -- phoenix_flames,if=!prev_gcd.1.phoenix_flames&buff.heating_up.react
  if S.PhoenixFlames:IsCastableP() and (not Player:PrevGCDP(1, S.PhoenixFlames) and Player:BuffP(S.HeatingUpBuff)) then
    if HR.Cast(S.PhoenixFlames, nil, nil, 40) then return "phoenix_flames 546"; end
  end
  -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled|spell_crit>=1
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable() or Player:CritChancePct() >= 85) then
    if HR.Cast(S.Scorch, nil, nil, 40) then return "scorch 552"; end
  end
  -- dragons_breath,if=active_enemies>2
  if S.DragonsBreath:IsCastableP(12) and (EnemiesCount > 2) then
    if HR.Cast(S.DragonsBreath, nil, nil, 12) then return "dragons_breath 556"; end
  end
  -- flamestrike,if=(active_enemies>=variable.hard_cast_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))
  if S.Flamestrike:IsCastableP() and (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) then
    if HR.Cast(S.Flamestrike, nil, nil, 40) then return "flamestrike 564"; end
  end
  -- fireball
  if S.Fireball:IsCastableP() and not Player:IsMoving() then
    if HR.Cast(S.Fireball, nil, nil, 40) then return "fireball 580"; end
  end
end

local function StandardRotation()
  -- flamestrike,if=(active_enemies>=variable.hot_streak_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))&buff.hot_streak.react
  if S.Flamestrike:IsCastableP() and ((EnemiesCount >= VarHotStreakFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) and Player:BuffP(S.HotStreakBuff)) then
    if HR.Cast(S.Flamestrike, nil, nil, 40) then return "flamestrike 582"; end
  end
  -- pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and Player:BuffRemainsP(S.HotStreakBuff) < S.Fireball:ExecuteTime()) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 600"; end
  end
  -- pyroblast,if=buff.hot_streak.react&(prev_gcd.1.fireball|firestarter.active|action.pyroblast.in_flight)
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and (Player:PrevGCDP(1, S.Fireball) or bool(S.Firestarter:ActiveStatus()) or S.Pyroblast:InFlight())) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 610"; end
  end
  -- phoenix_flames,if=charges>=3&active_enemies>2&!variable.phoenix_pooling
  if S.PhoenixFlames:IsReadyP() and (S.PhoenixFlames:ChargesP() >= 3 and EnemiesCount > 2 and not bool(VarPhoenixPooling)) then
    if HR.Cast(S.PhoenixFlames, nil, nil, 40) then return "phoenix_flames 615"; end
  end
  -- pyroblast,if=buff.hot_streak.react&(target.health.pct<=30&talent.searing_touch.enabled|spell_crit>=1)
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable() or Player:CritChancePct() >= 85)) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 620"; end
  end
  -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains
  if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemainsP(S.PyroclasmBuff)) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 626"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(buff.rune_of_power.down&!firestarter.active)&!variable.fire_blast_pooling&(((action.fireball.executing|action.pyroblast.executing)&buff.heating_up.react)|((talent.searing_touch.enabled&target.health.pct<=30|spell_crit>=1)&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!action.pyroblast.in_flight&!action.fireball.in_flight)))
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.FireBlast:IsCastableP() and ((Player:BuffDownP(S.RuneofPowerBuff) and not bool(S.Firestarter:ActiveStatus())) and not bool(VarFireBlastPooling) and (((Player:IsCasting(S.Fireball) or Player:IsCasting(S.Pyroblast)) and Player:BuffP(S.HeatingUpBuff)) or ((S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 or Player:CritChancePct() >= 85) and (Player:BuffP(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not S.Pyroblast:InFlight() and not S.Fireball:InFlight())))) then
    if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 636"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up&(talent.searing_touch.enabled&target.health.pct<=30|spell_crit>=1)&!(active_enemies>=variable.hot_streak_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff) and (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 or Player:CritChancePct() >= 85) and not (EnemiesCount >= VarHotStreakFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion))) then
    if HR.Cast(S.Pyroblast, nil, nil, 40) then return "pyroblast 726"; end
  end
  -- phoenix_flames,if=(buff.heating_up.react|(!buff.hot_streak.react&(action.fire_blast.charges>0|talent.searing_touch.enabled&target.health.pct<=30|spell_crit>=1)))&!variable.phoenix_pooling
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.PhoenixFlames:IsCastableP() and ((Player:BuffP(S.HeatingUpBuff) or (Player:BuffDownP(S.HotStreakBuff) and (S.FireBlast:ChargesP() > 0 or S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 or Player:CritChancePct() >= 85))) and not bool(VarPhoenixPooling)) then
    if HR.Cast(S.PhoenixFlames, nil, nil, 40) then return "phoenix_flames 750"; end
  end
  -- call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  end
  -- dragons_breath,if=active_enemies>1
  if S.DragonsBreath:IsCastableP(12) and (EnemiesCount > 1) then
    if HR.Cast(S.DragonsBreath, nil, nil, 12) then return "dragons_breath 766"; end
  end
  -- call_action_list,name=items_low_priority
  if (Settings.Commons.UseTrinkets) then
    local ShouldReturn = ItemsLowPriority(); if ShouldReturn then return ShouldReturn; end
  end
  -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled|spell_crit>=1
  -- Using 85% crit, since CritChancePct() does not include Critical Mass's 15% crit
  if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable() or Player:CritChancePct() >= 85) then
    if HR.Cast(S.Scorch, nil, nil, 40) then return "scorch 780"; end
  end
  -- flamestrike,if=active_enemies>=variable.hard_cast_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion)
  if S.Flamestrike:IsCastableP() and (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) then
    if HR.Cast(S.Flamestrike, nil, nil, 40) then return "flamestrike 783"; end
  end
  -- fireball
  if S.Fireball:IsCastableP() and not Player:IsMoving() then
    if HR.Cast(S.Fireball, nil, nil, 40) then return "fireball 784"; end
  end
  -- scorch
  if S.Scorch:IsCastableP() then
    if HR.Cast(S.Scorch, nil, nil, 40) then return "scorch 786"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount = GetEnemiesCount(8)
  HL.GetEnemies(40) -- For interrupts

  IgnoreCombustion = (Settings.Fire.DisableCombustion or not HR.CDsON())

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    -- variable,name=time_to_combustion,op=set,value=talent.firestarter.enabled*firestarter.remains+(cooldown.combustion.remains*(1-variable.kindling_reduction*talent.kindling.enabled)-action.rune_of_power.execute_time*talent.rune_of_power.enabled)*!cooldown.combustion.ready*buff.combustion.down
    if (true) then
      VarTimeToCombusion = num(S.Firestarter:IsAvailable()) * S.Firestarter:ActiveRemains() + (S.Combustion:CooldownRemainsP() * (1 - VarKindlingReduction * num(S.Kindling:IsAvailable())) - S.RuneofPower:ExecuteTime() * num(S.RuneofPower:IsAvailable())) * num(not S.Combustion:CooldownUpP()) * num(Player:BuffDownP(S.CombustionBuff))
    end
    -- variable,name=time_to_combustion,op=max,value=cooldown.memory_of_lucid_dreams.remains,if=essence.memory_of_lucid_dreams.major&buff.memory_of_lucid_dreams.down&cooldown.memory_of_lucid_dreams.remains-variable.time_to_combustion<=variable.hold_combustion_threshold
    if (Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and Player:BuffDownP(S.MemoryofLucidDreams) and S.MemoryofLucidDreams:CooldownRemainsP() - VarTimeToCombusion <= VarHoldCombustionThreshold) then
      VarTimeToCombusion = S.MemoryofLucidDreams:CooldownRemainsP()
    end
    -- variable,name=time_to_combustion,op=max,value=cooldown.worldvein_resonance.remains,if=essence.worldvein_resonance.major&buff.worldvein_resonance.down&cooldown.worldvein_resonance.remains-variable.time_to_combustion<=variable.hold_combustion_threshold
    if (Spell:MajorEssenceEnabled(AE.WorldveinResonance) and Player:BuffDownP(S.WorldveinResonance) and S.WorldveinResonance:CooldownRemainsP() - VarTimeToCombusion <= VarHoldCombustionThreshold) then
      VarTimeToCombusion = S.WorldveinResonance:CooldownRemainsP()
    end
    -- call_action_list,name=items_high_priority
    if (Settings.Commons.UseTrinkets) then
      local ShouldReturn = ItemsHighPriority(); if ShouldReturn then return ShouldReturn; end
    end
    -- mirror_image,if=buff.combustion.down
    if S.MirrorImage:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.MirrorImage) then return "mirror_image 791"; end
    end
    -- guardian_of_azeroth,if=(variable.time_to_combustion<10|target.time_to_die<variable.time_to_combustion)&!variable.disable_combustion
    if S.GuardianofAzeroth:IsCastableP() and ((VarTimeToCombusion < 10 or Target:TimeToDie() < VarTimeToCombusion) and not IgnoreCombustion) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 793"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 795"; end
    end
    -- reaping_flames
    if (true) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 797"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 799"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 801"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 803"; end
    end
    -- rune_of_power,if=buff.rune_of_power.down&(buff.combustion.down&buff.rune_of_power.down&(variable.time_to_combustion>full_recharge_time|variable.time_to_combustion>target.time_to_die)|variable.disable_combustion)
    if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and (Player:BuffDownP(S.CombustionBuff) and Player:BuffDownP(S.RuneofPowerBuff) and (VarTimeToCombusion > S.RuneofPower:FullRechargeTimeP() or VarTimeToCombusion > Target:TimeToDie()) or IgnoreCombustion)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return "rune_of_power 807"; end
    end
    -- call_action_list,name=combustion_phase,if=!variable.disable_combustion&variable.time_to_combustion<=0
    if (not IgnoreCombustion and VarTimeToCombusion <= 0) then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- fire_blast,use_while_casting=1,use_off_gcd=1,if=(essence.memory_of_lucid_dreams.major|essence.memory_of_lucid_dreams.minor&azerite.blaster_master.enabled)&charges=max_charges&!buff.hot_streak.react&!(buff.heating_up.react&(buff.combustion.up&(action.fireball.in_flight|action.pyroblast.in_flight|action.scorch.executing)|target.health.pct<=30&action.scorch.executing))&!(!buff.heating_up.react&!buff.hot_streak.react&buff.combustion.down&(action.fireball.in_flight|action.pyroblast.in_flight))
    if S.FireBlast:IsCastableP() and ((Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) or Spell:EssenceEnabled(AE.MemoryofLucidDreams) and S.BlasterMaster:AzeriteEnabled()) and S.FireBlast:ChargesP() == S.FireBlast:MaxCharges() and Player:BuffDownP(S.HotStreakBuff) and not (Player:BuffP(S.HeatingUpBuff) and (Player:BuffP(S.CombustionBuff) and (S.Fireball:InFlight() or S.Pyroblast:InFlight() or Player:IsCasting(S.Scorch)) or Target:HealthPercentage() <= 30 and Player:IsCasting(S.Scorch))) and not (Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.CombustionBuff) and (S.Fireball:InFlight() or S.Pyroblast:InFlight()))) then
      if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 830"; end
    end
    -- call_action_list,name=rop_phase,if=buff.rune_of_power.up&(variable.time_to_combustion>0|variable.disable_combustion)
    if (Player:BuffP(S.RuneofPowerBuff) and (VarTimeToCombusion > 0 or IgnoreCombustion)) then
      local ShouldReturn = RopPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=fire_blast_pooling,value=talent.rune_of_power.enabled&cooldown.rune_of_power.remains<cooldown.fire_blast.full_recharge_time&(variable.time_to_combustion>action.rune_of_power.full_recharge_time|variable.disable_combustion)&(cooldown.rune_of_power.remains<target.time_to_die|action.rune_of_power.charges>0)|!variable.disable_combustion&variable.time_to_combustion<action.fire_blast.full_recharge_time&variable.time_to_combustion<target.time_to_die
    if (true) then
      VarFireBlastPooling = num(S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemainsP() < S.FireBlast:FullRechargeTimeP() and (VarTimeToCombusion > S.RuneofPower:FullRechargeTimeP() or IgnoreCombustion) and (S.RuneofPower:CooldownRemainsP() < Target:TimeToDie() or S.RuneofPower:Charges() > 0) or not IgnoreCombustion and VarTimeToCombusion < S.FireBlast:FullRechargeTimeP() and VarTimeToCombusion < Target:TimeToDie())
    end
    -- variable,name=phoenix_pooling,value=talent.rune_of_power.enabled&cooldown.rune_of_power.remains<cooldown.phoenix_flames.full_recharge_time&(variable.time_to_combustion>action.rune_of_power.full_recharge_time|variable.disable_combustion)&(cooldown.rune_of_power.remains<target.time_to_die|action.rune_of_power.charges>0)|!variable.disable_combustion&variable.time_to_combustion<action.phoenix_flames.full_recharge_time&variable.time_to_combustion<target.time_to_die
    if (true) then
      VarPhoenixPooling = num(S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemainsP() < S.PhoenixFlames:FullRechargeTimeP() and (VarTimeToCombusion > S.RuneofPower:FullRechargeTimeP() or IgnoreCombustion) and (S.RuneofPower:CooldownRemainsP() < Target:TimeToDie() or S.RuneofPower:Charges() > 0) or not IgnoreCombustion and VarTimeToCombusion < S.PhoenixFlames:FullRechargeTimeP() and VarTimeToCombusion < Target:TimeToDie())
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(!variable.fire_blast_pooling|buff.rune_of_power.up)&(variable.time_to_combustion>0|variable.disable_combustion)&(active_enemies>=variable.hard_cast_flamestrike&(time-buff.combustion.last_expire>variable.delay_flamestrike|variable.disable_combustion))&!firestarter.active&buff.hot_streak.down&(!azerite.blaster_master.enabled|buff.blaster_master.remains<0.5)
    if S.FireBlast:IsCastableP() and ((not VarFireBlastPooling or Player:BuffP(S.RuneofPowerBuff)) and (VarTimeToCombusion > 0 or IgnoreCombustion) and (EnemiesCount >= VarHardCastFlamestrike and (S.Combustion:TimeSinceLastCast() - 10 > VarDelayFlamestrike or IgnoreCombustion)) and not bool(S.Firestarter:ActiveStatus()) and Player:BuffDownP(S.HotStreakBuff) and (not S.BlasterMaster:AzeriteEnabled() or Player:BuffRemainsP(S.BlasterMasterBuff) < 0.5)) then
      if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 832"; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=firestarter.active&charges>=1&(!variable.fire_blast_pooling|buff.rune_of_power.up)&(!azerite.blaster_master.enabled|buff.blaster_master.remains<0.5)&(!action.fireball.executing&!action.pyroblast.in_flight&buff.heating_up.up|action.fireball.executing&buff.hot_streak.down|action.pyroblast.in_flight&buff.heating_up.down&buff.hot_streak.down)
    if S.FireBlast:IsCastableP() and (bool(S.Firestarter:ActiveStatus()) and S.FireBlast:Charges() >= 1 and (not VarFireBlastPooling or Player:BuffP(S.RuneofPowerBuff)) and (not S.BlasterMaster:AzeriteEnabled() or Player:BuffRemainsP(S.BlasterMasterBuff) < 0.5) and (not Player:IsCasting(S.Fireball) and not S.Pyroblast:InFlight() and Player:BuffP(S.HeatingUpBuff) or Player:IsCasting(S.Fireball) and Player:BuffDownP(S.HotStreakBuff) or S.Pyroblast:InFlight() and Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff))) then
      if HR.Cast(S.FireBlast, nil, nil, 40) then return "fire_blast 834"; end
    end
    -- call_action_list,name=standard_rotation,if=variable.time_to_combustion>0|variable.disable_combustion
    if (VarTimeToCombusion > 0 or IgnoreCombustion) then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(63, APL, Init)

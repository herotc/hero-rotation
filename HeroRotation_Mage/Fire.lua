--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Fire = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  MirrorImage                           = Spell(55342),
  Pyroblast                             = Spell(11366),
  LivingBomb                            = Spell(44457),
  CombustionBuff                        = Spell(190319),
  Combustion                            = Spell(190319),
  Meteor                                = Spell(153561),
  RuneofPowerBuff                       = Spell(116014),
  RuneofPower                           = Spell(116011),
  Firestarter                           = Spell(205026),
  LightsJudgment                        = Spell(255647),
  FireBlast                             = Spell(108853),
  BlasterMasterBuff                     = Spell(274598),
  Fireball                              = Spell(133),
  BlasterMaster                         = Spell(274596),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  Scorch                                = Spell(2948),
  HeatingUpBuff                         = Spell(48107),
  HotStreakBuff                         = Spell(48108),
  PyroclasmBuff                         = Spell(269651),
  PhoenixFlames                         = Spell(257541),
  DragonsBreath                         = Spell(31661),
  FlameOn                               = Spell(205029),
  Flamestrike                           = Spell(2120),
  FlamePatch                            = Spell(205037),
  SearingTouch                          = Spell(269644),
  AlexstraszasFury                      = Spell(235870),
  Kindling                              = Spell(155148),
  Counterspell                          = Spell(2139),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  MemoryofLucidDreamsMinor              = MultiSpell(298268, 299371, 299373),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  CyclotronicBlast                      = Spell(167672),
  HarmonicDematerializer                = Spell(293512)
};
local S = Spell.Mage.Fire;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Fire = {
  PotionofUnbridledFury            = Item(169299),
  TidestormCodex                   = Item(165576),
  MalformedHeraldsLegwraps         = Item(167835),
  PocketsizedComputationDevice     = Item(167555),
  AzsharasFontofPower              = Item(169314),
  RotcrustedVoodooDoll             = Item(159624),
  AquipotentNautilus               = Item(169305),
  ShiverVenomRelic                 = Item(168905),
  HyperthreadWristwraps            = Item(168989),
  NotoriousAspirantsBadge          = Item(167528),
  NotoriousGladiatorsBadge         = Item(167380),
  SinisterGladiatorsBadge          = Item(165058),
  SinisterAspirantsBadge           = Item(165223),
  DreadGladiatorsBadge             = Item(161902),
  DreadAspirantsBadge              = Item(162966),
  DreadCombatantsInsignia          = Item(161676),
  NotoriousAspirantsMedallion      = Item(167525),
  NotoriousGladiatorsMedallion     = Item(167377),
  SinisterGladiatorsMedallion      = Item(165055),
  SinisterAspirantsMedallion       = Item(165220),
  DreadGladiatorsMedallion         = Item(161674),
  DreadAspirantsMedallion          = Item(162897),
  DreadCombatantsMedallion         = Item(161811),
  IgnitionMagesFuse                = Item(159615),
  TzanesBarkspines                 = Item(161411),
  AzurethoseSingedPlumage          = Item(161377),
  AncientKnotofWisdomAlliance      = Item(161417),
  AncientKnotofWisdomHorde         = Item(166793),
  ShockbitersFang                  = Item(169318),
  NeuralSynapseEnhancer            = Item(168973),
  BalefireBranch                   = Item(159630)
};
local I = Item.Mage.Fire;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Fire = HR.GUISettings.APL.Mage.Fire
};

-- Variables
local VarCombustionRopCutoff = 0;
local VarFireBlastPooling = 0;
local VarPhoenixPooling = 0;
local VarCombustionOnUse = 0;
local VarFontDoubleOnUse = 0;
local VarOnUseCutoff = 0;

HL:RegisterForEvent(function()
  VarCombustionRopCutoff = 0
  VarFireBlastPooling = 0
  VarPhoenixPooling = 0
  VarCombustionOnUse = 0
  VarFontDoubleOnUse = 0
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

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

S.Pyroblast:RegisterInFlight()
S.Fireball:RegisterInFlight()
S.Meteor:RegisterInFlight()
S.PhoenixFlames:RegisterInFlight();
S.Pyroblast:RegisterInFlight(S.CombustionBuff);
S.Fireball:RegisterInFlight(S.CombustionBuff);

function S.Firestarter:ActiveStatus()
    return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90)) and 1 or 0
end

function S.Firestarter:ActiveRemains()
    return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90, 3) or 0) or 0
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, ActiveTalents, CombustionPhase, ItemsCombustion, ItemsHighPriority, ItemsLowPriority, RopPhase, StandardRotation
  EnemiesCount = GetEnemiesCount(8)
  HL.GetEnemies(40) -- For interrupts
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff, true) then
      if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect 3"; end
    end
    if Everyone.TargetIsValid() then
      -- variable,name=combustion_rop_cutoff,op=set,value=60
      if (true) then
        VarCombustionRopCutoff = 60
      end
      -- variable,name=combustion_on_use,op=set,value=equipped.notorious_aspirants_badge|equipped.notorious_gladiators_badge|equipped.sinister_gladiators_badge|equipped.sinister_aspirants_badge|equipped.dread_gladiators_badge|equipped.dread_aspirants_badge|equipped.dread_combatants_insignia|equipped.notorious_aspirants_medallion|equipped.notorious_gladiators_medallion|equipped.sinister_gladiators_medallion|equipped.sinister_aspirants_medallion|equipped.dread_gladiators_medallion|equipped.dread_aspirants_medallion|equipped.dread_combatants_medallion|equipped.ignition_mages_fuse|equipped.tzanes_barkspines|equipped.azurethos_singed_plumage|equipped.ancient_knot_of_wisdom|equipped.shockbiters_fang|equipped.neural_synapse_enhancer|equipped.balefire_branch
      if (true) then
        VarCombustionOnUse = num(I.NotoriousAspirantsBadge:IsEquipped() or I.NotoriousGladiatorsBadge:IsEquipped() or I.SinisterGladiatorsBadge:IsEquipped() or I.SinisterAspirantsBadge:IsEquipped() or I.DreadGladiatorsBadge:IsEquipped() or I.DreadAspirantsBadge:IsEquipped() or I.DreadCombatantsInsignia:IsEquipped() or I.NotoriousAspirantsMedallion:IsEquipped() or I.NotoriousGladiatorsMedallion:IsEquipped() or I.SinisterGladiatorsMedallion:IsEquipped() or I.SinisterAspirantsMedallion:IsEquipped() or I.DreadGladiatorsMedallion:IsEquipped() or I.DreadAspirantsMedallion:IsEquipped() or I.DreadCombatantsMedallion:IsEquipped() or I.IgnitionMagesFuse:IsEquipped() or I.TzanesBarkspines:IsEquipped() or I.AzurethoseSingedPlumage:IsEquipped() or I.AncientKnotofWisdomAlliance:IsEquipped() or I.AncientKnotofWisdomHorde:IsEquipped() or I.ShockbitersFang:IsEquipped() or I.NeuralSynapseEnhancer:IsEquipped() or I.BalefireBranch:IsEquipped())
      end
      -- variable,name=font_double_on_use,op=set,value=equipped.azsharas_font_of_power&variable.combustion_on_use
      if (true) then
        VarFontDoubleOnUse = num(I.AzsharasFontofPower:IsEquipped() and bool(VarCombustionOnUse))
      end
      -- variable,name=on_use_cutoff,op=set,value=20*variable.combustion_on_use&!variable.font_double_on_use+40*variable.font_double_on_use+25*equipped.azsharas_font_of_power&!variable.font_double_on_use
      if (true) then
        VarOnUseCutoff = 20 * num(bool(VarCombustionOnUse) and not bool(VarFontDoubleOnUse)) + 40 * VarFontDoubleOnUse + 25 * num(I.AzsharasFontofPower:IsEquipped() and not bool(VarFontDoubleOnUse))
      end
      -- snapshot_stats
      -- use_item,name=azsharas_font_of_power
      if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() then
        if HR.CastSuggested(I.AzsharasFontofPower) then return "azsharas_font_of_power 9"; end
      end
      -- mirror_image
      if S.MirrorImage:IsCastableP() then
        if HR.Cast(S.MirrorImage) then return "mirror_image 10"; end
      end
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_intellect 12"; end
      end
      -- pyroblast
      if S.Pyroblast:IsCastableP() then
        if HR.Cast(S.Pyroblast) then return "pyroblast 14"; end
      end
    end
  end
  ActiveTalents = function()
    -- living_bomb,if=active_enemies>1&buff.combustion.down&(cooldown.combustion.remains>cooldown.living_bomb.duration|cooldown.combustion.ready)
    if S.LivingBomb:IsCastableP() and (EnemiesCount > 1 and Player:BuffDownP(S.CombustionBuff) and (S.Combustion:CooldownRemainsP() > S.LivingBomb:BaseDuration() or S.Combustion:CooldownUpP())) then
      if HR.Cast(S.LivingBomb) then return "living_bomb 16"; end
    end
    -- meteor,if=buff.rune_of_power.up&(firestarter.remains>cooldown.meteor.duration|!firestarter.active)|cooldown.rune_of_power.remains>target.time_to_die&action.rune_of_power.charges<1|(cooldown.meteor.duration<cooldown.combustion.remains|cooldown.combustion.ready)&!talent.rune_of_power.enabled&(cooldown.meteor.duration<firestarter.remains|!talent.firestarter.enabled|!firestarter.active)
    if S.Meteor:IsCastableP() and (Player:BuffP(S.RuneofPowerBuff) and (S.Firestarter:ActiveRemains() > S.Meteor:BaseDuration() or not bool(S.Firestarter:ActiveStatus())) or S.RuneofPower:CooldownRemainsP() > Target:TimeToDie() and S.RuneofPower:ChargesP() < 1 or (S.Meteor:BaseDuration() < S.Combustion:CooldownRemainsP() or S.Combustion:CooldownUpP()) and not S.RuneofPower:IsAvailable() and (S.Meteor:BaseDuration() < S.Firestarter:ActiveRemains() or not S.Firestarter:IsAvailable() or not bool(S.Firestarter:ActiveStatus()))) then
      if HR.Cast(S.Meteor) then return "meteor 32"; end
    end
  end
  CombustionPhase = function()
    -- lights_judgment,if=buff.combustion.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 234"; end
    end
    -- blood_of_the_enemy
    if S.BloodoftheEnemy:IsCastableP() then
      if HR.Cast(S.BloodoftheEnemy, Settings.Fire.GCDasOffGCD.Essences) then return "blood_of_the_enemy 244"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, Settings.Fire.GCDasOffGCD.Essences) then return "guardian_of_azeroth 248"; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryofLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryofLucidDreams, Settings.Fire.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams 246"; end
    end
    -- fire_blast,use_while_casting=1,use_off_gcd=1,if=charges>=1&((action.fire_blast.charges_fractional+(buff.combustion.remains-buff.blaster_master.duration)%cooldown.fire_blast.duration-(buff.combustion.remains)%(buff.blaster_master.duration-0.5))>=0|!azerite.blaster_master.enabled|!talent.flame_on.enabled|buff.combustion.remains<=buff.blaster_master.duration|buff.blaster_master.remains<0.5|equipped.hyperthread_wristwraps&cooldown.hyperthread_wristwraps_300142.remains<5)&buff.combustion.up&(!action.scorch.executing&!action.pyroblast.in_flight&buff.heating_up.up|action.scorch.executing&buff.hot_streak.down&(buff.heating_up.down|azerite.blaster_master.enabled)|azerite.blaster_master.enabled&talent.flame_on.enabled&action.pyroblast.in_flight&buff.heating_up.down&buff.hot_streak.down)
    if S.FireBlast:IsReady() and (S.FireBlast:ChargesP() >= 1 and ((S.FireBlast:ChargesFractional() + (Player:BuffRemainsP(S.CombustionBuff) - S.BlasterMasterBuff:BaseDuration()) % S.FireBlast:Cooldown() - (Player:BuffRemainsP(S.CombustionBuff)) % (S.BlasterMasterBuff:BaseDuration() - 0.5)) >= 0 or not S.BlasterMaster:AzeriteEnabled() or not S.FlameOn:IsAvailable() or Player:BuffRemainsP(S.CombustionBuff) <= S.BlasterMasterBuff:BaseDuration() or Player:BuffRemainsP(S.BlasterMasterBuff) < 0.5 or I.HyperthreadWristwraps:IsEquipped() and I.HyperthreadWristwraps:CooldownRemains() < 5) and Player:BuffP(S.Combustion) and (not Player:IsCasting(S.Scorch) and not S.Pyroblast:InFlight() and Player:BuffP(S.HeatingUpBuff) or Player:IsCasting(S.Scorch) and Player:BuffDownP(S.HotStreakBuff) and (Player:BuffDownP(S.HeatingUpBuff) or S.BlasterMaster:AzeriteEnabled()) or S.BlasterMaster:AzeriteEnabled() and S.FlameOn:IsAvailable() and S.Pyroblast:InFlight() and Player:BuffP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff))) then
      if HR.Cast(S.Scorch) then return "scorch 247"; end
    end
    -- rune_of_power,if=buff.combustion.down
    if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return "rune_of_power 250"; end
    end
    -- fire_blast,use_while_casting=1,if=azerite.blaster_master.enabled&talent.flame_on.enabled&buff.blaster_master.down&(talent.rune_of_power.enabled&action.rune_of_power.executing&action.rune_of_power.execute_remains<0.6|(cooldown.combustion.ready|buff.combustion.up)&!talent.rune_of_power.enabled&!action.pyroblast.in_flight&!action.fireball.in_flight)
    if S.FireBlast:IsReady() and (S.BlasterMaster:AzeriteEnabled() and S.FlameOn:IsAvailable() and Player:BuffDownP(S.BlasterMasterBuff) and (S.RuneofPower:IsAvailable() and Player:IsCasting(S.RuneofPower) and Player:CastRemains() < 0.6 or (S.Combustion:IsReady() or Player:BuffP(S.CombustionBuff)) and not S.RuneofPower:IsAvailable() and not S.Pyroblast:InFlight() and not S.Fireball:InFlight())) then
      if HR.Cast(S.FireBlast) then return "fire_blast 255"; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- combustion,use_off_gcd=1,use_while_casting=1,if=((action.meteor.in_flight&action.meteor.in_flight_remains<=0.5)|!talent.meteor.enabled)&(buff.rune_of_power.up|!talent.rune_of_power.enabled)
    if S.Combustion:IsCastableP() and (((S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) or not S.Meteor:IsAvailable()) and (Player:BuffP(S.RuneofPowerBuff) or not S.RuneofPower:IsAvailable())) then
      if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion 265"; end
    end
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_intellect 288"; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 290"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 292"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 294"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 296"; end
    end
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>2)|active_enemies>6)&buff.hot_streak.react&!azerite.blaster_master.enabled
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 2) or EnemiesCount > 6) and Player:BuffP(S.HotStreakBuff) and not S.BlasterMaster:AzeriteEnabled()) then
      if HR.Cast(S.Flamestrike) then return "flamestrike 300"; end
    end
    -- pyroblast,if=buff.pyroclasm.react&buff.combustion.remains>cast_time
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and Player:BuffRemainsP(S.CombustionBuff) > S.Pyroblast:CastTime()) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 320"; end
    end
    -- pyroblast,if=buff.hot_streak.react
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 330"; end
    end
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff)) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 390"; end
    end
    -- phoenix_flames
    if S.PhoenixFlames:IsCastableP() then
      if HR.Cast(S.PhoenixFlames) then return "phoenix_flames 396"; end
    end
    -- scorch,if=buff.combustion.remains>cast_time&buff.combustion.up|buff.combustion.down
    if S.Scorch:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) > S.Scorch:CastTime() and Player:BuffP(S.CombustionBuff) or Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.Scorch) then return "scorch 398"; end
    end
    -- living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
    if S.LivingBomb:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and EnemiesCount > 1) then
      if HR.Cast(S.LivingBomb) then return "living_bomb 410"; end
    end
    -- dragons_breath,if=buff.combustion.remains<gcd.max&buff.combustion.up
    if S.DragonsBreath:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and Player:BuffP(S.CombustionBuff)) then
      if HR.Cast(S.DragonsBreath) then return "dragons_breath 420"; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return "scorch 426"; end
    end
  end
  ItemsCombustion = function()
    -- use_item,name=ignition_mages_fuse
    if I.IgnitionMagesFuse:IsEquipped() and I.IgnitionMagesFuse:IsReady() then
      if HR.CastSuggested(I.IgnitionMagesFuse) then return "ignition_mages_fuse combustion"; end
    end
    -- use_item,name=hyperthread_wristwraps,if=buff.combustion.up&(action.fire_blast.full_recharge_time>=10+gcd.remains|action.fire_blast.charges=0&action.fire_blast.recharge_time>gcd.remains)
    if I.HyperthreadWristwraps:IsEquipped() and I.HyperthreadWristwraps:IsReady() and (Player:BuffP(S.CombustionBuff) and (S.FireBlast:FullRechargeTimeP() >= 10 + Player:GCDRemains() or S.FireBlast:Charges() == 0 and S.FireBlast:RechargeP() > Player:GCDRemains())) then
      if HR.CastSuggested(I.HyperthreadWristwraps) then return "hyperthread_wristwraps combustion"; end
    end
    -- use_item,use_off_gcd=1,name=azurethos_singed_plumage,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    if I.AzurethoseSingedPlumage:IsEquipped() and I.AzurethoseSingedPlumage:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.AzurethoseSingedPlumage) then return "azurethos_singed_plumage combustion"; end
    end
    -- use_item,use_off_gcd=1,effect_name=gladiators_badge,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    -- One line per badge
    if I.NotoriousAspirantsBadge:IsEquipped() and I.NotoriousAspirantsBadge:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.NotoriousAspirantsBadge) then return "gladiators_badge combustion"; end
    end
    if I.NotoriousGladiatorsBadge:IsEquipped() and I.NotoriousGladiatorsBadge:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.NotoriousGladiatorsBadge) then return "gladiators_badge combustion"; end
    end
    if I.SinisterGladiatorsBadge:IsEquipped() and I.SinisterGladiatorsBadge:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.SinisterGladiatorsBadge) then return "gladiators_badge combustion"; end
    end
    if I.SinisterAspirantsBadge:IsEquipped() and I.SinisterAspirantsBadge:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.SinisterAspirantsBadge) then return "gladiators_badge combustion"; end
    end
    if I.DreadGladiatorsBadge:IsEquipped() and I.DreadGladiatorsBadge:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.DreadGladiatorsBadge) then return "gladiators_badge combustion"; end
    end
    if I.DreadAspirantsBadge:IsEquipped() and I.DreadAspirantsBadge:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.DreadAspirantsBadge) then return "gladiators_badge combustion"; end
    end
    -- use_item,use_off_gcd=1,effect_name=gladiators_medallion,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    -- One line per medallion
    if I.NotoriousAspirantsMedallion:IsEquipped() and I.NotoriousAspirantsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.NotoriousAspirantsMedallion) then return "gladiators_medallion combustion"; end
    end
    if I.NotoriousGladiatorsMedallion:IsEquipped() and I.NotoriousGladiatorsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.NotoriousGladiatorsMedallion) then return "gladiators_medallion combustion"; end
    end
    if I.SinisterGladiatorsMedallion:IsEquipped() and I.SinisterGladiatorsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.SinisterGladiatorsMedallion) then return "gladiators_medallion combustion"; end
    end
    if I.SinisterAspirantsMedallion:IsEquipped() and I.SinisterAspirantsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.SinisterAspirantsMedallion) then return "gladiators_medallion combustion"; end
    end
    if I.DreadGladiatorsMedallion:IsEquipped() and I.DreadGladiatorsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.DreadGladiatorsMedallion) then return "gladiators_medallion combustion"; end
    end
    if I.DreadAspirantsMedallion:IsEquipped() and I.DreadAspirantsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.DreadAspirantsMedallion) then return "gladiators_medallion combustion"; end
    end
    if I.DreadCombatantsMedallion:IsEquipped() and I.DreadCombatantsMedallion:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.DreadCombatantsMedallion) then return "gladiators_medallion combustion"; end
    end
    -- use_item,use_off_gcd=1,name=balefire_branch,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    if I.BalefireBranch:IsEquipped() and I.BalefireBranch:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.BalefireBranch) then return "balefire_branch combustion"; end
    end
    -- use_item,use_off_gcd=1,name=shockbiters_fang,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    if I.ShockbitersFang:IsEquipped() and I.ShockbitersFang:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.ShockbitersFang) then return "shockbiters_fang combustion"; end
    end
    -- use_item,use_off_gcd=1,name=tzanes_barkspines,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    if I.TzanesBarkspines:IsEquipped() and I.TzanesBarkspines:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.TzanesBarkspines) then return "tzanes_barkspines combustion"; end
    end
    -- use_item,use_off_gcd=1,name=ancient_knot_of_wisdom,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    -- Two conditions, since the horde and alliance trinkets have different IDs
    if I.AncientKnotofWisdomAlliance:IsEquipped() and I.AncientKnotofWisdomAlliance:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.AncientKnotofWisdomAlliance) then return "ancient_knot_of_wisdom combustion"; end
    end
    if I.AncientKnotofWisdomHorde:IsEquipped() and I.AncientKnotofWisdomHorde:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.AncientKnotofWisdomHorde) then return "ancient_knot_of_wisdom combustion"; end
    end
    -- use_item,use_off_gcd=1,name=neural_synapse_enhancer,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    if I.NeuralSynapseEnhancer:IsEquipped() and I.NeuralSynapseEnhancer:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.NeuralSynapseEnhancer) then return "neural_synapse_enhancer combustion"; end
    end
    -- use_item,use_off_gcd=1,name=malformed_heralds_legwraps,if=buff.combustion.up|action.meteor.in_flight&action.meteor.in_flight_remains<=0.5
    if I.MalformedHeraldsLegwraps:IsEquipped() and I.MalformedHeraldsLegwraps:IsReady() and (Player:BuffP(S.CombustionBuff) or S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) then
      if HR.CastSuggested(I.MalformedHeraldsLegwraps) then return "malformed_heralds_legwraps combustion"; end
    end
  end
  ItemsHighPriority = function()
    -- call_action_list,name=items_combustion,if=(talent.rune_of_power.enabled&cooldown.combustion.remains<=action.rune_of_power.cast_time|cooldown.combustion.ready)&!firestarter.active|buff.combustion.up
    if ((S.RuneofPower:IsAvailable() and S.Combustion:CooldownRemainsP() <= S.RuneofPower:CastTime() or S.Combustion:IsReadyP()) and not bool(S.Firestarter:ActiveStatus()) or Player:BuffP(S.CombustionBuff)) then
      local ShouldReturn = ItemsCombustion(); if ShouldReturn then return ShouldReturn; end
    end
    -- use_items
    -- use_item,name=azsharas_font_of_power,if=cooldown.combustion.remains<=5+15*variable.font_double_on_use
    if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and (S.Combustion:CooldownRemainsP() <= 5 + 15 * VarFontDoubleOnUse) then
      if HR.CastSuggested(I.AzsharasFontofPower) then return "azsharas_font_of_power high_priority"; end
    end
    -- use_item,name=rotcrusted_voodoo_doll,if=cooldown.combustion.remains>variable.on_use_cutoff
    if I.RotcrustedVoodooDoll:IsEquipped() and I.RotcrustedVoodooDoll:IsReady() and (S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.RotcrustedVoodooDoll) then return "rotcrusted_voodoo_doll high_priority"; end
    end
    -- use_item,name=aquipotent_nautilus,if=cooldown.combustion.remains>variable.on_use_cutoff
    if I.AquipotentNautilus:IsEquipped() and I.AquipotentNautilus:IsReady() and (S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.AquipotentNautilus) then return "aquipotent_nautilus high_priority"; end
    end
    -- use_item,name=shiver_venom_relic,if=cooldown.combustion.remains>variable.on_use_cutoff
    if I.ShiverVenomRelic:IsEquipped() and I.ShiverVenomRelic:IsReady() and (S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.ShiverVenomRelic) then return "shiver_venom_relic high_priority"; end
    end
    -- use_item,effect_name=harmonic_dematerializer
    if I.PocketsizedComputationDevice:IsEquipped() and I.PocketsizedComputationDevice:IsReady() and S.HarmonicDematerializer:IsAvailable() then
      if HR.CastSuggested(I.PocketsizedComputationDevice) then return "harmonic_dematerializer high_priority"; end
    end
    -- use_item,name=malformed_heralds_legwraps,if=cooldown.combustion.remains>=55&buff.combustion.down&cooldown.combustion.remains>variable.on_use_cutoff
    if I.MalformedHeraldsLegwraps:IsEquipped() and I.MalformedHeraldsLegwraps:IsReady() and (S.Combustion:CooldownRemainsP() >= 55 and Player:BuffDownP(S.CombustionBuff) and S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.MalformedHeraldsLegwraps) then return "malformed_heralds_legwraps high_priority"; end
    end
    -- use_item,name=ancient_knot_of_wisdom,if=cooldown.combustion.remains>=55&buff.combustion.down&cooldown.combustion.remains>variable.on_use_cutoff
    -- Two conditions, since the horde and alliance trinkets have different IDs
    if I.AncientKnotofWisdomAlliance:IsEquipped() and I.AncientKnotofWisdomAlliance:IsReady() and (S.Combustion:CooldownRemainsP() >= 55 and Player:BuffDownP(S.CombustionBuff) and S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.AncientKnotofWisdomAlliance) then return "ancient_knot_of_wisdom high_priority"; end
    end
    if I.AncientKnotofWisdomHorde:IsEquipped() and I.AncientKnotofWisdomHorde:IsReady() and (S.Combustion:CooldownRemainsP() >= 55 and Player:BuffDownP(S.CombustionBuff) and S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.AncientKnotofWisdomHorde) then return "ancient_knot_of_wisdom high_priority"; end
    end
    -- use_item,name=neural_synapse_enhancer,if=cooldown.combustion.remains>=45&buff.combustion.down&cooldown.combustion.remains>variable.on_use_cutoff
    if I.NeuralSynapseEnhancer:IsEquipped() and I.NeuralSynapseEnhancer:IsReady() and (S.Combustion:CooldownRemainsP() >= 45 and Player:BuffDownP(S.CombustionBuff) and S.Combustion:CooldownRemainsP() > VarOnUseCutoff) then
      if HR.CastSuggested(I.NeuralSynapseEnhancer) then return "neural_synapse_enhancer high_priority"; end
    end
  end
  ItemsLowPriority = function()
    -- use_item,name=tidestorm_codex,if=cooldown.combustion.remains>variable.on_use_cutoff|talent.firestarter.enabled&firestarter.remains>variable.on_use_cutoff
    if I.TidestormCodex:IsEquipped() and I.TidestormCodex:IsReady() and (S.Combustion:CooldownRemainsP() > VarOnUseCutoff or S.Firestarter:IsAvailable() and S.Firestarter:ActiveRemains() > VarOnUseCutoff) then
      if HR.CastSuggested(I.TidestormCodex) then return "tidestorm_codex low_priority"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=cooldown.combustion.remains>variable.on_use_cutoff|talent.firestarter.enabled&firestarter.remains>variable.on_use_cutoff
    if I.PocketsizedComputationDevice:IsEquipped() and I.PocketsizedComputationDevice:IsReady() and S.CyclotronicBlast:IsAvailable() and (S.Combustion:CooldownRemainsP() > VarOnUseCutoff or S.Firestarter:IsAvailable() and S.Firestarter:ActiveRemains() > VarOnUseCutoff) then
      if HR.CastSuggested(I.PocketsizedComputationDevice) then return "cyclotronic_blast low_priority"; end
    end
  end
  RopPhase = function()
    -- rune_of_power
    if S.RuneofPower:IsCastableP() then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return "rune_of_power 430"; end
    end
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>4)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 1) or EnemiesCount > 4) and Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Flamestrike) then return "flamestrike 432"; end
    end
    -- pyroblast,if=buff.hot_streak.react
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 450"; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0|firestarter.active&buff.rune_of_power.up)&(!buff.heating_up.react&!buff.hot_streak.react&!prev_off_gcd.fire_blast&(action.fire_blast.charges>=2|(action.phoenix_flames.charges>=1&talent.phoenix_flames.enabled)|(talent.alexstraszas_fury.enabled&cooldown.dragons_breath.ready)|(talent.searing_touch.enabled&target.health.pct<=30)|(talent.firestarter.enabled&firestarter.active)))
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 or bool(S.Firestarter:ActiveStatus()) and Player:BuffP(S.RuneofPowerBuff)) and (Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff) and not Player:PrevOffGCDP(1, S.FireBlast) and (S.FireBlast:ChargesP() >= 2 or (S.PhoenixFlames:ChargesP() >= 1 and S.PhoenixFlames:IsAvailable()) or (S.AlexstraszasFury:IsAvailable() and S.DragonsBreath:CooldownUpP()) or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30) or (S.Firestarter:IsAvailable() and bool(S.Firestarter:ActiveStatus()))))) then
      if HR.Cast(S.FireBlast) then return "fire_blast 454"; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains&buff.rune_of_power.remains>cast_time
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemainsP(S.PyroclasmBuff) and Player:BuffRemainsP(S.RuneofPowerBuff) > S.Pyroblast:CastTime()) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 486"; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0|firestarter.active&buff.rune_of_power.up)&(buff.heating_up.react&(target.health.pct>=30|!talent.searing_touch.enabled))
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 or bool(S.Firestarter:ActiveStatus()) and Player:BuffP(S.RuneofPowerBuff)) and (Player:BuffP(S.HeatingUpBuff) and (Target:HealthPercentage() >= 30 or not S.SearingTouch:IsAvailable()))) then
      if HR.Cast(S.FireBlast) then return "fire_blast 502"; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0|firestarter.active&buff.rune_of_power.up)&talent.searing_touch.enabled&target.health.pct<=30&(buff.heating_up.react&!action.scorch.executing|!buff.heating_up.react&!buff.hot_streak.react)
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 or bool(S.Firestarter:ActiveStatus()) and Player:BuffP(S.RuneofPowerBuff)) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and (Player:BuffP(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff))) then
      if HR.Cast(S.FireBlast) then return "fire_blast 512"; end
    end
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up&talent.searing_touch.enabled&target.health.pct<=30&(!talent.flame_patch.enabled|active_enemies=1)
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and (not S.FlamePatch:IsAvailable() or EnemiesCount == 1)) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 530"; end
    end
    -- phoenix_flames,if=!prev_gcd.1.phoenix_flames&buff.heating_up.react
    if S.PhoenixFlames:IsCastableP() and (not Player:PrevGCDP(1, S.PhoenixFlames) and Player:BuffP(S.HeatingUpBuff)) then
      if HR.Cast(S.PhoenixFlames) then return "phoenix_flames 546"; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return "scorch 552"; end
    end
    -- dragons_breath,if=active_enemies>2
    if S.DragonsBreath:IsCastableP() and (EnemiesCount > 2) then
      if HR.Cast(S.DragonsBreath) then return "dragons_breath 556"; end
    end
    -- flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
    if S.Flamestrike:IsCastableP() and ((S.FlamePatch:IsAvailable() and EnemiesCount > 2) or EnemiesCount > 5) then
      if HR.Cast(S.Flamestrike) then return "flamestrike 564"; end
    end
    -- fireball
    if S.Fireball:IsCastableP() then
      if HR.Cast(S.Fireball) then return "fireball 580"; end
    end
  end
  StandardRotation = function()
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>1&!firestarter.active)|active_enemies>4)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 1 and not bool(S.Firestarter:ActiveStatus())) or EnemiesCount > 4) and Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Flamestrike) then return "flamestrike 582"; end
    end
    -- pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and Player:BuffRemainsP(S.HotStreakBuff) < S.Fireball:ExecuteTime()) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 600"; end
    end
    -- pyroblast,if=buff.hot_streak.react&(prev_gcd.1.fireball|firestarter.active|action.pyroblast.in_flight)
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and (Player:PrevGCDP(1, S.Fireball) or bool(S.Firestarter:ActiveStatus()) or S.Pyroblast:InFlight())) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 610"; end
    end
    -- phoenix_flames,if=charges>=3&active_enemies>2&!variable.phoenix_pooling
    if S.PhoenixFlames:IsReadyP() and (S.PhoenixFlames:ChargesP() >= 3 and EnemiesCount > 2 and not bool(VarPhoenixPooling)) then
      if HR.Cast(S.PhoenixFlames) then return "phoenix_flames 615"; end
    end
    -- pyroblast,if=buff.hot_streak.react&target.health.pct<=30&talent.searing_touch.enabled
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 620"; end
    end
    -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemainsP(S.PyroclasmBuff)) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 626"; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0&buff.rune_of_power.down|firestarter.active)&!talent.kindling.enabled&!variable.fire_blast_pooling&(((action.fireball.executing|action.pyroblast.executing)&(buff.heating_up.react|firestarter.active&!buff.hot_streak.react&!buff.heating_up.react))|(talent.searing_touch.enabled&target.health.pct<=30&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!action.pyroblast.in_flight&!action.fireball.in_flight))|(firestarter.active&(action.pyroblast.in_flight|action.fireball.in_flight)&!buff.heating_up.react&!buff.hot_streak.react))
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 and Player:BuffDownP(S.RuneofPowerBuff) or bool(S.Firestarter:ActiveStatus())) and not S.Kindling:IsAvailable() and not bool(VarFireBlastPooling) and (((Player:IsCasting(S.Fireball) or Player:IsCasting(S.Pyroblast)) and (Player:BuffP(S.HeatingUpBuff) or bool(S.Firestarter:ActiveStatus()) and Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.HeatingUpBuff))) or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and (Player:BuffP(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not S.Pyroblast:InFlight() and not S.Fireball:InFlight())) or (bool(S.Firestarter:ActiveStatus()) and (S.Pyroblast:InFlight() or S.Fireball:InFlight()) and Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff)))) then
      if HR.Cast(S.FireBlast) then return "fire_blast 636"; end
    end
    -- fire_blast,if=talent.kindling.enabled&buff.heating_up.react&(cooldown.combustion.remains>full_recharge_time+2+talent.kindling.enabled|firestarter.remains>full_recharge_time|(!talent.rune_of_power.enabled|cooldown.rune_of_power.remains>target.time_to_die&action.rune_of_power.charges<1)&cooldown.combustion.remains>target.time_to_die)
    if S.FireBlast:IsCastableP() and (S.Kindling:IsAvailable() and Player:BuffP(S.HeatingUpBuff) and (S.Combustion:CooldownRemainsP() > S.FireBlast:FullRechargeTimeP() + 2 + num(S.Kindling:IsAvailable()) or S.Firestarter:ActiveRemains() > S.FireBlast:FullRechargeTimeP() or (not S.RuneofPower:IsAvailable() or S.RuneofPower:CooldownRemainsP() > Target:TimeToDie() and S.RuneofPower:ChargesP() < 1) and S.Combustion:CooldownRemainsP() > Target:TimeToDie())) then
      if HR.Cast(S.FireBlast) then return "fire_blast 696"; end
    end
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up&talent.searing_touch.enabled&target.health.pct<=30&((talent.flame_patch.enabled&active_enemies=1&!firestarter.active)|(active_enemies<4&!talent.flame_patch.enabled))
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and ((S.FlamePatch:IsAvailable() and EnemiesCount == 1 and not bool(S.Firestarter:ActiveStatus())) or (EnemiesCount < 4 and not S.FlamePatch:IsAvailable()))) then
      if HR.Cast(S.Pyroblast) then return "pyroblast 726"; end
    end
    -- phoenix_flames,if=(buff.heating_up.react|(!buff.hot_streak.react&(action.fire_blast.charges>0|talent.searing_touch.enabled&target.health.pct<=30)))&!variable.phoenix_pooling
    if S.PhoenixFlames:IsCastableP() and ((Player:BuffP(S.HeatingUpBuff) or (Player:BuffDownP(S.HotStreakBuff) and (S.FireBlast:ChargesP() > 0 or S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30))) and not bool(VarPhoenixPooling)) then
      if HR.Cast(S.PhoenixFlames) then return "phoenix_flames 750"; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- dragons_breath,if=active_enemies>1
    if S.DragonsBreath:IsCastableP() and (EnemiesCount > 1) then
      if HR.Cast(S.DragonsBreath) then return "dragons_breath 766"; end
    end
    -- call_action_list,name=items_low_priority
    if (true) then
      local ShouldReturn = ItemsLowPriority(); if ShouldReturn then return ShouldReturn; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return "scorch 780"; end
    end
    -- fireball
    if S.Fireball:IsCastableP() then
      if HR.Cast(S.Fireball) then return "fireball 784"; end
    end
    -- scorch
    if S.Scorch:IsCastableP() then
      if HR.Cast(S.Scorch) then return "scorch 786"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false);
    -- call_action_list,name=items_high_priority
    if (true) then
      local ShouldReturn = ItemsHighPriority(); if ShouldReturn then return ShouldReturn; end
    end
    -- mirror_image,if=buff.combustion.down
    if S.MirrorImage:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.MirrorImage) then return "mirror_image 791"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Settings.Fire.GCDasOffGCD.Essences) then return "concentrated_flame 795"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, Settings.Fire.GCDasOffGCD.Essences) then return "focused_azerite_beam 797"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, Settings.Fire.GCDasOffGCD.Essences) then return "purifying_blast 799"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, Settings.Fire.GCDasOffGCD.Essences) then return "ripple_in_space 801"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, Settings.Fire.GCDasOffGCD.Essences) then return "the_unbound_force 803"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance, Settings.Fire.GCDasOffGCD.Essences) then return "worldvein_resonance 805"; end
    end
    -- rune_of_power,if=talent.firestarter.enabled&firestarter.remains>full_recharge_time|cooldown.combustion.remains>variable.combustion_rop_cutoff&buff.combustion.down|target.time_to_die<cooldown.combustion.remains&buff.combustion.down
    if S.RuneofPower:IsCastableP() and (S.Firestarter:IsAvailable() and S.Firestarter:ActiveRemains() > S.RuneofPower:FullRechargeTimeP() or S.Combustion:CooldownRemainsP() > VarCombustionRopCutoff and Player:BuffDownP(S.CombustionBuff) or Target:TimeToDie() < S.Combustion:CooldownRemainsP() and Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return "rune_of_power 807"; end
    end
    -- call_action_list,name=combustion_phase,if=(talent.rune_of_power.enabled&cooldown.combustion.remains<=action.rune_of_power.cast_time|cooldown.combustion.ready)&!firestarter.active|buff.combustion.up
    if HR.CDsON() and ((S.RuneofPower:IsAvailable() and S.Combustion:CooldownRemainsP() <= S.RuneofPower:CastTime() or S.Combustion:CooldownUpP()) and not bool(S.Firestarter:ActiveStatus()) or Player:BuffP(S.CombustionBuff)) then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- fire_blast,use_while_casting=1,use_off_gcd=1,if=(essence.memory_of_lucid_dreams.major|essence.memory_of_lucid_dreams.minor&azerite.blaster_master.enabled)&charges=max_charges&!buff.hot_streak.react&!(buff.heating_up.react&(buff.combustion.up&(action.fireball.in_flight|action.pyroblast.in_flight|action.scorch.executing)|target.health.pct<=30&action.scorch.executing))&!(!buff.heating_up.react&!buff.hot_streak.react&buff.combustion.down&(action.fireball.in_flight|action.pyroblast.in_flight))
    if S.FireBlast:IsCastableP() and ((S.MemoryofLucidDreams:IsAvailable() or S.MemoryofLucidDreamsMinor:IsAvailable() and S.BlasterMaster:AzeriteEnabled()) and S.FireBlast:ChargesP() == S.FireBlast:MaxCharges() and not Player:BuffP(S.HotStreakBuff) and not (Player:BuffP(S.HeatingUpBuff) and (Player:BuffP(S.CombustionBuff) and (S.Fireball:InFlight() or S.Pyroblast:InFlight() or Player:IsCasting(S.Scorch)) or Target:HealthPercentage() <= 30 and Player:IsCasting(S.Scorch))) and not (not Player:BuffP(S.HeatingUpBuff) and not Player:BuffP(S.HotStreakBuff) and Player:BuffDownP(S.CombustionBuff) and (S.Fireball:InFlight() or S.Pyroblast:InFlight()))) then
      if HR.Cast(S.FireBlast) then return "fire_blast 830"; end
    end
    -- call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
    if (Player:BuffP(S.RuneofPowerBuff) and Player:BuffDownP(S.CombustionBuff)) then
      local ShouldReturn = RopPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=fire_blast_pooling,value=talent.rune_of_power.enabled&cooldown.rune_of_power.remains<cooldown.fire_blast.full_recharge_time&(cooldown.combustion.remains>variable.combustion_rop_cutoff|firestarter.active)&(cooldown.rune_of_power.remains<target.time_to_die|action.rune_of_power.charges>0)|cooldown.combustion.remains<action.fire_blast.full_recharge_time+cooldown.fire_blast.duration*azerite.blaster_master.enabled&!firestarter.active&cooldown.combustion.remains<target.time_to_die|talent.firestarter.enabled&firestarter.active&firestarter.remains<cooldown.fire_blast.full_recharge_time+cooldown.fire_blast.duration*azerite.blaster_master.enabled
    if (true) then
      VarFireBlastPooling = num(S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemainsP() < S.FireBlast:FullRechargeTimeP() and (S.Combustion:CooldownRemainsP() > VarCombustionRopCutoff or bool(S.Firestarter:ActiveStatus())) and (S.RuneofPower:CooldownRemainsP() < Target:TimeToDie() or S.RuneofPower:ChargesP() > 0) or S.Combustion:CooldownRemainsP() < S.FireBlast:FullRechargeTimeP() + S.FireBlast:BaseDuration() * num(S.BlasterMaster:AzeriteEnabled()) and not bool(S.Firestarter:ActiveStatus()) and S.Combustion:CooldownRemainsP() < Target:TimeToDie() or S.Firestarter:IsAvailable() and bool(S.Firestarter:ActiveStatus()) and S.Firestarter:ActiveRemains() < S.FireBlast:FullRechargeTimeP() + S.FireBlast:BaseDuration() * num(S.BlasterMaster:AzeriteEnabled()))
    end
    -- variable,name=phoenix_pooling,value=talent.rune_of_power.enabled&cooldown.rune_of_power.remains<cooldown.phoenix_flames.full_recharge_time&cooldown.combustion.remains>variable.combustion_rop_cutoff&(cooldown.rune_of_power.remains<target.time_to_die|action.rune_of_power.charges>0)|cooldown.combustion.remains<action.phoenix_flames.full_recharge_time&cooldown.combustion.remains<target.time_to_die
    if (true) then
      VarPhoenixPooling = num(S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemainsP() < S.PhoenixFlames:FullRechargeTimeP() and S.Combustion:CooldownRemainsP() > VarCombustionRopCutoff and (S.RuneofPower:CooldownRemainsP() < Target:TimeToDie() or S.RuneofPower:ChargesP() > 0) or S.Combustion:CooldownRemainsP() < S.PhoenixFlames:FullRechargeTimeP() and S.Combustion:CooldownRemainsP() < Target:TimeToDie())
    end
    -- call_action_list,name=standard_rotation
    if (true) then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(157981, 8, 6)               -- Blast Wave
  HL.RegisterNucleusAbility(153561, 8, 6)               -- Meteor
  HL.RegisterNucleusAbility(31661, 8, 6)                -- Dragon's Breath
  HL.RegisterNucleusAbility(44457, 10, 6)               -- Living Bomb
  HL.RegisterNucleusAbility(2120, 8, 6)                 -- Flamestrike
  HL.RegisterNucleusAbility(257541, 8, 6)               -- Phoenix Flames
end

HR.SetAPL(63, APL, Init)

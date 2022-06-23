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
local CombatTime = HL.CombatTime
-- HeroRotation
local HR         = HeroRotation
local Mage       = HR.Commons.Mage
local Cast       = HR.Cast
local CastLeft   = HR.CastLeft
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Arcane;
local I = Item.Mage.Arcane;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.SinfulGladiatorsBadge:ID(),
  I.EmpyrealOrdnance:ID(),
  I.DreadfireVessel:ID(),
  I.SoulIgniter:ID(),
  I.SoullettingRuby:ID(),
  I.GlyphofAssimilation:ID(),
  I.MacabreSheetMusic:ID(),
  I.MoonlitPrism:ID(),
  I.ScarsofFraternalStrife:ID(),
}

-- Rotation Var

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

-- Variables
local Enemies8ySplash, EnemiesCount8ySplash, EnemiesCount10ySplash --Enemies arround target

local SiphonStormEquipped = Player:HasLegendaryEquipped(16)
local GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
local TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
local ArcaneInfinityEquipped = Player:HasLegendaryEquipped(14)
local DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
local ArcaneBombardmentEquipped = Player:HasLegendaryEquipped(15)
local HarmonicEchoEquipped = Player:HasLegendaryEquipped(218)

HL:RegisterForEvent(function()
  SiphonStormEquipped = Player:HasLegendaryEquipped(16)
  GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
  TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
  ArcaneInfinityEquipped = Player:HasLegendaryEquipped(14)
  DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
  ArcaneBombardmentEquipped = Player:HasLegendaryEquipped(15)
  HarmonicEchoEquipped = Player:HasLegendaryEquipped(218)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

local var_prepull_evo
local var_aoe_target_count
local var_aoe_spark_target_count
local var_evo_pct
local var_harmony_stack_time
local var_always_sync_cooldowns
local var_rs_max_delay_for_totm
local var_rs_max_delay_for_rop
local var_rs_max_delay_for_ap
local var_mot_preceed_totm_by
local var_mot_max_delay_for_totm
local var_mot_max_delay_for_ap
local var_ap_max_delay_for_totm
local var_rop_max_delay_for_totm
local var_ap_max_delay_for_mot
local var_totm_max_delay_for_ap
local var_totm_max_delay_for_rop
local var_barrage_mana_pct
local var_ap_minimum_mana_pct
local var_totm_max_charges
local var_aoe_totm_max_charges
local var_fishing_opener = false
local var_ap_on_use
local var_empowered_barrage
local var_outside_of_cooldowns = true
local var_stack_harmony
local var_just_used_spark
local var_estimated_ap_cooldown
local var_holding_totm
local var_last_ap_use
local var_time_until_ap = 0
local var_init = false
local var_disciplinary_command_cd_remains
local var_disciplinary_command_last_applied
local RadiantSparkVulnerabilityMaxStack = 4
local ClearCastingMaxStack = 3
local PresenceMaxStack = 3
local ArcaneHarmonyMaxStack = 18
local BossFightRemains = 11111
local FightRemains = 11111
local CastAE

Player.ArcaneOpener = {}
local ArcaneOpener = Player.ArcaneOpener

function ArcaneOpener:Reset ()
  self.state = false
  self.final_burn = false
  self.has_opened = false

  var_init = false
end
ArcaneOpener:Reset()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function VarInit()
  --variable,name=aoe_target_count,default=-1,op=set,if=variable.aoe_target_count=-1,value=3
  var_aoe_target_count = 3

  --variable,name=evo_pct,op=reset,default=15
  var_evo_pct = 15

  --variable,prepull_evo,default=-1,op=set,if=variable.prepull_evo=-1,value=1*(runeforge.siphon_storm&(covenant.venthyr|covenant.necrolord|conduit.arcane_prodigy))
  if SiphonStormEquipped and (CovenantID == 2 or CovenantID == 4 or S.ArcaneProdigy:ConduitEnabled()) then
    var_prepull_evo = true
  else
    var_prepull_evo = false
  end

  --variable,name=have_opened,op=set,value=0+(1*active_enemies>=variable.aoe_target_count)
  -- TODO active_enemies at prepull
  --if var_prepull_evo then
  --  ArcaneOpener:StopOpener()
  --end

  --variable,name=final_burn,op=set,value=0
  --Managed elsewhere

  --variable,name=harmony_stack_time,op=reset,default=9
  var_harmony_stack_time = 9

  --variable,name=always_sync_cooldowns,op=reset,default=1
  var_always_sync_cooldowns = 1

  --variable,name=rs_max_delay_for_totm,op=reset,default=5
  var_rs_max_delay_for_totm = 5

  --variable,name=rs_max_delay_for_rop,op=reset,default=5
  var_rs_max_delay_for_rop = 5

  --variable,name=rs_max_delay_for_ap,op=reset,default=20
  var_rs_max_delay_for_ap = 20

  --variable,name=mot_preceed_totm_by,op=reset,default=8
  var_mot_preceed_totm_by = 8

  --variable,name=mot_max_delay_for_totm,op=reset,default=20
  var_mot_max_delay_for_totm = 20

  --variable,name=mot_max_delay_for_ap,op=reset,default=20
  var_mot_max_delay_for_ap = 20

  --variable,name=ap_max_delay_for_totm,op=reset,default=-1,op=set,if=variable.ap_max_delay_for_totm=-1,value=10+(20*conduit.arcane_prodigy)
  var_ap_max_delay_for_totm = 10 + 20 * num(S.ArcaneProdigy:ConduitEnabled())

  --variable,name=ap_max_delay_for_mot,op=reset,default=20
  var_ap_max_delay_for_mot = 20

  --variable,name=rop_max_delay_for_totm,default=-1,op=set,if=variable.rop_max_delay_for_totm=-1,value=20-(5*conduit.arcane_prodigy)
  var_rop_max_delay_for_totm = 20 - 5 * num(S.ArcaneProdigy:ConduitEnabled())

  --variable,name=totm_max_delay_for_ap,default=-1,op=set,if=variable.totm_max_delay_for_ap=-1,value=5+20*(covenant.night_fae|(conduit.arcane_prodigy&active_enemies<variable.aoe_target_count))+15*(covenant.kyrian&runeforge.arcane_infinity&active_enemies>=variable.aoe_target_count)
  -- TODO active_enemies at prepull
  var_totm_max_delay_for_ap = 5 + 20 * num(CovenantID == 3) + 15 * num(CovenantID == 1 and ArcaneInfinityEquipped)

  --variable,name=totm_max_delay_for_rop,default=-1,op=set,if=variable.totm_max_delay_for_rop=-1,value=20-(8*conduit.arcane_prodigy)
  var_totm_max_delay_for_rop = 20 - 8 * num(S.ArcaneProdigy:ConduitEnabled())

  --variable,name=barrage_mana_pct,default=-1,op=set,if=variable.barrage_mana_pct=-1,value=((80-(20*covenant.night_fae)+(15*covenant.kyrian))-(mastery_value*100))
  var_barrage_mana_pct = 80 - (20 * num(CovenantID == 3)) + (15 * num(CovenantID == 1)) - Player:MasteryPct()

  --variable,name=ap_minimum_mana_pct,op=reset,default=15
  var_ap_minimum_mana_pct = 15

  --variable,name=totm_max_charges,op=reset,default=2
  var_totm_max_charges = 2

  --variable,name=aoe_totm_max_charges,op=reset,default=2
  var_aoe_totm_max_charges = 2

  --variable,name=fishing_opener,default=-1,op=set,if=variable.fishing_opener=-1,value=1*(equipped.empyreal_ordnance|(talent.rune_of_power&(talent.arcane_echo|!covenant.kyrian)&(!covenant.necrolord|active_enemies=1|runeforge.siphon_storm)&!covenant.venthyr))|(covenant.venthyr&equipped.moonlit_prism)
  var_fishing_opener = Settings.Arcane.UseFishingOpener and ((I.EmpyrealOrdnance:IsEquipped() or (S.RuneofPower:IsAvailable() and (S.ArcaneEcho:IsAvailable() or CovenantID ~= 1) and (CovenantID ~= 4 or SiphonStormEquipped) and CovenantID ~= 2)) or (CovenantID == 2 and I.MoonlitPrism:IsEquipped()))

  --variable,name=ap_on_use,op=set,value=equipped.macabre_sheet_music|equipped.gladiators_badge|equipped.gladiators_medallion|equipped.darkmoon_deck_putrescence|equipped.inscrutable_quantum_device|equipped.soulletting_ruby|equipped.sunblood_amethyst|equipped.wakeners_frond|equipped.flame_of_battle
  var_ap_on_use = I.MacabreSheetMusic:IsEquipped() or I.SinfulGladiatorsBadge:IsEquipped() or I.DarkmoonDeckPutrescence:IsEquipped() or I.InscrutableQuantumDevice:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.SunbloodAmethyst:IsEquipped() or I.WakenersFrond:IsEquipped() or I.FlameofBattle:IsEquipped()

  -- variable,name=aoe_spark_target_count,op=reset,default=8+(2*runeforge.harmonic_echo)
  var_aoe_spark_target_count = 8 + (2 * num(HarmonicEchoEquipped))

  -- variable,name=aoe_spark_target_count,op=max,value=variable.aoe_target_count
  var_aoe_spark_target_count = (var_aoe_target_count > var_aoe_spark_target_count) and var_aoe_target_count or var_aoe_spark_target_count

  var_init = true
end

function ArcaneOpener:StartOpener ()
  if Player:AffectingCombat() then
    self.state = true
    self.final_burn = false
    self.has_opened = false
    VarInit()
  end
end

function ArcaneOpener:StopOpener ()
  self.state = false
  self.has_opened = true
end

function ArcaneOpener:On ()
  return self.state or (not Player:AffectingCombat() and (Player:IsCasting(S.Frostbolt) or Player:IsCasting(S.ArcaneBlast) or Player:IsCasting(S.Evocation)))
end

function ArcaneOpener:HasOpened ()
  return self.has_opened
end

function ArcaneOpener:StartFinalBurn ()
  self.final_burn = true
end

function ArcaneOpener:IsFinalBurn ()
  return self.final_burn
end

HL:RegisterForEvent(function()
  VarConserveMana = 0
  VarTotalBurns = 0
  VarAverageBurnLength = 0
  VarFontPrecombatChannel = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  ArcaneOpener:Reset()
end, "PLAYER_REGEN_DISABLED")
S.Frostbolt:RegisterInFlight()

local function Precombat()
  if not var_init then
    ArcaneOpener:Reset()
    VarInit()
  end
  --flask
  --food
  --augmentation
  --arcane_familiar
  if S.ArcaneFamiliar:IsCastable() and Player:BuffDown(S.ArcaneFamiliarBuff) then
    if Cast(S.ArcaneFamiliar) then return "arcane_familiar precombat 1"; end
  end  
  --arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  --conjure_mana_gem
  -- TODO: Fix hotkey issue (spell and item use the same icon)
  if S.ConjureManaGem:IsCastable() then
    if Cast(S.ConjureManaGem) then return "conjure_mana_gem precombat "; end
  end
  -- Manually added : precast Tome of monstruous Constructions
  if I.TomeofMonstruousConstructions:IsEquippedAndReady() and not Player:AuraInfo(S.TomeofMonstruousConstructionsBuff) then
    if Cast(I.TomeofMonstruousConstructions, nil, Settings.Commons.DisplayStyle.Trinkets) then return "tome_of_monstruous_constructions precombat 3"; end
  end
  --mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 4"; end
  end
  --fleshcraft,if=soulbind.volatile_solvent|soulbind.pustule_eruption
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:IsAvailable() or S.PustuleEruption:IsAvailable()) then
    if Cast(S.Fleshcraft) then return "fleshcraft precombat 5"; end
  end
  --rune_of_power,if=covenant.kyrian&runeforge.arcane_infinity&conduit.arcane_prodigy&variable.always_sync_cooldowns&active_enemies<variable.aoe_target_count
  --TODO : manage active_enemies precombat
  if S.RuneofPower:IsCastable() and CovenantID == 1 and ArcaneInfinityEquipped and S.ArcaneProdigy:ConduitEnabled() and var_always_sync_cooldowns then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power precombat 6"; end
  end
  --potion
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion precombat 7"; end
  end
  if (not Player:IsCasting()) then
    --frostbolt,if=!variable.prepull_evo=1&runeforge.disciplinary_command
    if not var_prepull_evo and S.Frostbolt:IsReady() and DisciplinaryCommandEquipped then
      if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 8"; end
    end
    --fireblast,if=!variable.prepull_evo=1&runeforge.disciplinary_command
    if not var_prepull_evo and S.FireBlast:IsReady() and DisciplinaryCommandEquipped then
      if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fireblast precombat 9"; end
    end
    --arcane_blast,if=!variable.prepull_evo=1&!runeforge.disciplinary_command&(!covenant.venthyr|variable.fishing_opener)
    if not var_prepull_evo and S.ArcaneBlast:IsReady() and not DisciplinaryCommandEquipped and (CovenantID ~= 2 or var_fishing_opener) then
      if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 10"; end
    end
    --mirrors_of_torment,if=!variable.prepull_evo=1&!runeforge.disciplinary_command&covenant.venthyr&!variable.fishing_opener
    if S.MirrorsofTorment:IsCastable() and not var_prepull_evo and not DisciplinaryCommandEquipped and CovenantID == 2 and not var_fishing_opener then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment precombat 11"; end
    end
    --evocation,if=variable.prepull_evo=1
    if var_prepull_evo and S.Evocation:IsReady() then
      if Cast(S.Evocation) then return "evocation precombat 12"; end
    end
  end
end

local function Calculations()
  --variable,name=have_opened,op=set,value=1,if=variable.have_opened=0&prev_gcd.1.evocation&!(runeforge.siphon_storm|runeforge.temporal_warp)
  if ArcaneOpener:On() and Player:IsChanneling(S.Evocation) and not(SiphonStormEquipped or TemporalWarpEquipped) then
    ArcaneOpener:StopOpener()
    return "Stop opener 1"
  end
  --variable,name=have_opened,op=set,value=1,if=variable.have_opened=0&buff.arcane_power.down&cooldown.arcane_power.remains&(runeforge.siphon_storm|runeforge.temporal_warp)
  if ArcaneOpener:On() and Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() > 0 and (SiphonStormEquipped or TemporalWarpEquipped) then
    ArcaneOpener:StopOpener()
    return "Stop opener 2"
  end
  --variable,name=final_burn,op=set,value=1,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&!buff.rule_of_threes.up&fight_remains<=((mana%action.arcane_blast.cost)*action.arcane_blast.execute_time)
  if Player:ArcaneCharges() == Player:ArcaneChargesMax() and not Player:BuffUp(S.RuleofThreesBuff) and HL.BossFilteredFightRemains("<=", (((Player:Mana() / S.ArcaneBlast:Cost()) * S.ArcaneBlast:ExecuteTime()) + Player:GCDRemains())) then
    ArcaneOpener:StartFinalBurn()
    return "Start final burn"
  end
  --variable,name=empowered_barrage,op=set,value=buff.arcane_harmony.stack>=15|(runeforge.arcane_bombardment&target.health.pct<35)
  var_empowered_barrage = Player:BuffStack(S.ArcaneHarmonyBuff) >= 15 or (ArcaneBombardmentEquipped and Target:HealthPercentage() < 35)

  --variable,name=last_ap_use,default=0,op=set,if=buff.arcane_power.up&(variable.last_ap_use=0|time>=variable.last_ap_use+15),value=time
  var_last_ap_use = 0
  if Player:BuffUp(S.ArcanePower) and (var_last_ap_use == 0 or CombatTime() >= var_last_ap_use + 15) then
    var_last_ap_use = CombatTime()
  end
  --variable,name=estimated_ap_cooldown,op=set,value=(cooldown.arcane_power.duration*(1-(0.3*conduit.arcane_prodigy.rank)))-(time-variable.last_ap_use)
  var_estimated_ap_cooldown = 15 * (1 - (0.3 * num(S.ArcaneProdigy:ConduitRank()))) - (CombatTime() - var_last_ap_use)
  --variable,name=time_until_ap,op=set,if=conduit.arcane_prodigy,value=variable.estimated_ap_cooldown
  --variable,name=time_until_ap,op=set,if=!conduit.arcane_prodigy,value=cooldown.arcane_power.remains
  if S.ArcaneProdigy:ConduitEnabled() then
    var_time_until_ap = var_estimated_ap_cooldown
  else
    var_time_until_ap = S.ArcanePower:CooldownRemains()
  end
  --variable,name=time_until_ap,op=max,value=cooldown.touch_of_the_magi.remains,if=(cooldown.touch_of_the_magi.remains-variable.time_until_ap)<20
  if (Target:DebuffRemains(S.TouchoftheMagi) - var_time_until_ap) < 20 then
    var_time_until_ap = math.max(var_time_until_ap,Target:DebuffRemains(S.TouchoftheMagi))
  end
  --variable,name=time_until_ap,op=max,value=trinket.soulletting_ruby.cooldown.remains,if=conduit.arcane_prodigy&conduit.arcane_prodigy.rank<5&equipped.soulletting_ruby&covenant.kyrian&runeforge.arcane_infinity
  if S.ArcaneProdigy:ConduitEnabled() and S.ArcaneProdigy:ConduitRank() < 5 and I.SoullettingRuby:IsEquipped() and CovenantID == 1 and ArcaneInfinityEquipped then
    var_time_until_ap = math.max(var_time_until_ap,I.SoullettingRuby:CooldownRemains())
  end
  --variable,name=holding_totm,op=set,value=cooldown.touch_of_the_magi.ready&variable.time_until_ap<20
  var_holding_totm = S.TouchoftheMagi:CooldownRemains() == 0 and var_time_until_ap < 20
  --variable,name=just_used_spark,op=set,value=(prev_gcd.1.radiant_spark|prev_gcd.2.radiant_spark|prev_gcd.3.radiant_spark)&debuff.radiant_spark_vulnerability.down
  var_just_used_spark = (Player:PrevGCD(1,S.RadiantSpark) or Player:PrevGCD(2,S.RadiantSpark) or Player:PrevGCD(3,S.RadiantSpark)) and Target:DebuffDown(S.RadiantSparkVulnerability)
  --variable,name=outside_of_cooldowns,op=set,value=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&!variable.just_used_spark&debuff.radiant_spark_vulnerability.down
  var_outside_of_cooldowns = Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and not var_just_used_spark and Target:DebuffDown(S.RadiantSparkVulnerability)
  --variable,name=stack_harmony,op=set,value=runeforge.arcane_infinity&((covenant.kyrian&cooldown.touch_of_the_magi.remains<variable.harmony_stack_time))
  var_stack_harmony = ArcaneInfinityEquipped and (CovenantID == 1 and S.TouchoftheMagi:CooldownRemains() < var_harmony_stack_time)
end

local function Opener()
  --fire_blast,if=runeforge.disciplinary_command&buff.disciplinary_command_frost.up
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and Mage.DC.Frost == 1 then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast opener 1"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&mana.pct>95
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and Player:ManaPercentage() > 95 then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova opener 2"; end
  end
  --use_item,name=soulletting_ruby
  if I.SoullettingRuby:IsEquippedAndReady() then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby opener 3"; end
  end
  --deathborne
  if S.Deathborne:IsCastable() then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne opener 4"; end
  end
  --radiant_spark,if=mana.pct>40
  if S.RadiantSpark:IsCastable() and Player:ManaPercentage() > 40 then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark opener 5"; end
  end
  --rune_of_power,if=covenant.venthyr
  if S.RuneofPower:IsCastable() and (CovenantID == 2) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power opener 5.5"; end
  end
  --mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment opener 6"; end
  end
  --shifting_power,if=buff.arcane_power.down&cooldown.arcane_power.remains
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() > 0 then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power opener 7"; end
  end
  --arcane_orb,if=cooldown.arcane_power.ready&buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneOrb:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb opener 8"; end
  end
  --arcane_blast,if=covenant.venthyr&cooldown.mirrors_of_torment.remains>84
  if S.ArcaneBlast:IsCastable() and CovenantID == 2 and S.MirrorsofTorment:CooldownRemains() > 84 then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 9"; end
  end
  --touch_of_the_magi
  if S.TouchoftheMagi:IsCastable() then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi opener 10"; end
  end
  --arcane_power
  if S.ArcanePower:IsCastable() then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power opener 11"; end
  end
  --rune_of_power,if=buff.arcane_power.down
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.ArcanePower) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power opener 12"; end
  end
  --presence_of_mind,if=!talent.arcane_echo&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and S.ArcaneEcho:IsAvailable() and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagi) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind opener 13"; end
  end
  --presence_of_mind,if=buff.arcane_power.up&buff.rune_of_power.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind opener 14"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparkVulnerability) > 0) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 15"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<gcd&runeforge.arcane_infinity
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) < Player:GCD() and ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 16"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.arcane_power.down&buff.rune_of_power.remains<=gcd&runeforge.arcane_infinity
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCD() and ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 17"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo&(buff.deathborne.down|active_enemies=1)&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|(!talent.overpowered&(buff.rune_of_power.up|cooldown.evocation.ready)))
  --TODO : early chain
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagiDebuff) and S.ArcaneEcho:IsAvailable() and (Player:BuffDown(S.Deathborne) or EnemiesCount8ySplash == 1) and Target:DebuffRemains(S.TouchoftheMagiDebuff) > S.ArcaneMissiles:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 18"; end
  end
  --arcane_missiles,if=buff.clearcasting.stack=buff.clearcasting.max_stack&covenant.venthyr
  if S.ArcaneMissiles:IsCastable() and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack and CovenantID == 2 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 19"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&cooldown.arcane_power.remains&(buff.rune_of_power.up|buff.arcane_power.up),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and S.ArcanePower:CooldownRemains() > 0 and (Player:BuffUp(S.RuneofPowerBuff) or Player:BuffUp(S.ArcanePower)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 20"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb opener 21"; end
  end
  --arcane_blast,if=buff.rune_of_power.up|mana.pct>15
  if S.ArcaneBlast:IsCastable() and (Player:BuffUp(S.RuneofPowerBuff) or Player:ManaPercentage() > 15) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 22"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:ManaPercentage() < 85 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation opener 23"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 24"; end
  end
end

local function Cooldowns()
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.ready
  --&(buff.arcane_charge.stack<=variable.totm_max_charges
  --&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  --|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  --|cooldown.arcane_power.remains<=gcd))
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() > 30 and S.TouchoftheMagi:CooldownRemains() == 0
  and (Player:ArcaneCharges() <= var_totm_max_charges 
  and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap)
  or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap)
  or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova cooldowns 1"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.ready
  --&(!talent.enlightened|(talent.enlightened&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and S.ArcanePower:CooldownRemains() == 0
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70))
  and ((S.TouchoftheMagi:CooldownRemains() > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0))
  and (Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct) then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova cooldowns 2"; end
  end
  --frostbolt,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down
  --&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0
  --&(buff.arcane_charge.stack<=variable.totm_max_charges&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd))
  if S.Frostbolt:IsReady() and not Player:IsCasting(S.Frostbolt) and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Frost == 0 
  and (Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff)) and S.TouchoftheMagi:CooldownRemains() == 0
  and (Player:ArcaneCharges() <= var_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt cooldowns 3"; end
  end
  --fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0 and Player:IsCasting(S.Frostbolt) then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast cooldowns 4"; end
  end
  --mirrors_of_torment,if=!runeforge.siphon_storm&cooldown.touch_of_the_magi.remains<=9-(3*set_bonus.tier28_4pc)&cooldown.arcane_power.remains<=10-(3*set_bonus.tier28_4pc)
  if S.MirrorsofTorment:IsCastable() and ((not SiphonStormEquipped) and S.TouchoftheMagi:CooldownRemains() <= 9 - (3 * num(Player:HasTier(28, 4))) and S.ArcanePower:CooldownRemains() <= 10 - (3 * num(Player:HasTier(28, 4)))) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment cooldowns 5"; end
  end
  --mirrors_of_torment,if=runeforge.siphon_storm&buff.siphon_storm.up&cooldown.touch_of_the_magi.remains<=9-(3*set_bonus.tier28_4pc)&cooldown.arcane_power.remains<=10-(3*set_bonus.tier28_4pc)
  if S.MirrorsofTorment:IsCastable() and (SiphonStormEquipped and Player:BuffUp(S.SiphonStormBuff) and S.TouchoftheMagi:CooldownRemains() <= 9 - (3 * num(Player:HasTier(28, 4))) and S.ArcanePower:CooldownRemains() <= 10 - (3 * num(Player:HasTier(28, 4)))) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment cooldowns 6"; end
  end
  --fleshcraft,if=variable.outside_of_cooldowns&(soulbind.volatile_solvent|soulbind.pustule_eruption)
  if S.Fleshcraft:IsCastable() and var_outside_of_cooldowns and (S.VolatileSolvent:IsAvailable() or S.PustuleEruption:IsAvailable()) then
    if Cast(S.Fleshcraft) then return "fleshcraft cooldowns 7"; end
  end
  --deathborne,if=!runeforge.siphon_storm&cooldown.touch_of_the_magi.remains<=15&cooldown.arcane_power.remains<=16
  if S.Deathborne:IsCastable() and ((not SiphonStormEquipped) and S.TouchoftheMagi:CooldownRemains() <= 15 and S.ArcanePower:CooldownRemains() <= 16) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cooldowns 8"; end
  end
  --deathborne,if=runeforge.siphon_storm&prev_gcd.1.evocation
  if S.Deathborne:IsCastable() and (SiphonStormEquipped and Player:PrevGCD(1, S.Evocation)) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cooldowns 9"; end
  end
  --deathborne,if=cooldown.arcane_power.ready
  --&(!talent.enlightened|(talent.enlightened&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.ready&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70))
  and ((Player:BuffRemains(S.TouchoftheMagi) > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cooldowns 10"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains>variable.rs_max_delay_for_totm&cooldown.arcane_power.remains>variable.rs_max_delay_for_ap
  --&(talent.rune_of_power&(cooldown.rune_of_power.remains<execute_time|cooldown.rune_of_power.remains>variable.rs_max_delay_for_rop)|!talent.rune_of_power)
  --&buff.arcane_charge.stack>2&debuff.touch_of_the_magi.down&buff.rune_of_power.down&buff.arcane_power.down
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() > var_rs_max_delay_for_totm and S.ArcanePower:CooldownRemains() > var_rs_max_delay_for_ap
  and ((S.RuneofPower:IsAvailable() and (S.RuneofPower:CooldownRemains() <= S.RadiantSpark:ExecuteTime() or S.RuneofPower:CooldownRemains() > var_rs_max_delay_for_rop)) or not S.RuneofPower:IsAvailable())
  and Player:ArcaneCharges() > 2 and Target:DebuffDown(S.TouchoftheMagiDebuff) and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldowns 11"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains<execute_time&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<(execute_time+action.touch_of_the_magi.execute_time)
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime() and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() < (S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime()) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldowns 12"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains<execute_time
  --&((!talent.enlightened|(talent.enlightened&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() < S.RadiantSpark:ExecuteTime()
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70))
  and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldowns 13"; end
  end
  --use_item,name=soulletting_ruby,if=(!runeforge.siphon_storm|buff.siphon_storm.up)&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=execute_time&mana.pct>variable.ap_minimum_mana_pct&buff.rune_of_power.down
  if I.SoullettingRuby:IsEquippedAndReady() and (not SiphonStormEquipped or Player:BuffUp(S.SiphonStormBuff)) and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= S.SoullettingRuby:ExecuteTime() and Player:ManaPercentage() > var_ap_minimum_mana_pct and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby cooldowns 14"; end
  end
  --evocation,if=runeforge.siphon_storm&cooldown.touch_of_the_magi.remains<=(action.evocation.execute_time+13)
  if S.Evocation:IsCastable() and (SiphonStormEquipped and S.TouchoftheMagi:CooldownRemains() <= (S.Evocation:ExecuteTime() + 13)) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation cooldowns 15"; end
  end
  -- Note: The following lines all use set_bonus.tier28_2pc&covenant.venthyr, so checking once here
  if (Player:HasTier(28, 2) and CovenantID == 2) then
    --rune_of_power,if=set_bonus.tier28_2pc&covenant.venthyr&buff.arcane_power.down&cooldown.touch_of_the_magi.remains<=execute_time&cooldown.arcane_power.remains>10
    if S.RuneofPower:IsCastable() and (Player:BuffDown(S.ArcanePower) and S.TouchoftheMagi:CooldownRemains() <= S.RuneofPower:ExecuteTime() and S.ArcanePower:CooldownRemains() > 10) then
      if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power cooldowns 16"; end
    end
    --touch_of_the_magi,if=set_bonus.tier28_2pc&covenant.venthyr&prev_gcd.1.rune_of_power
    if S.TouchoftheMagi:IsCastable() and (Player:PrevGCD(1, S.RuneofPower)) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 17"; end
    end
    --touch_of_the_magi,if=set_bonus.tier28_2pc&covenant.venthyr&cooldown.arcane_power.remains<=execute_time
    if S.TouchoftheMagi:IsCastable() and (S.ArcanePower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime()) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 18"; end
    end
  end
  --arcane_power,if=prev_gcd.1.touch_of_the_magi
  if S.ArcanePower:IsCastable() and (Player:PrevGCD(1, S.TouchoftheMagi)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power cooldowns 19"; end
  end
  -- Note: The following lines all use (!set_bonus.tier28_2pc|!covenant.venthyr), so checking once here
  if ((not Player:HasTier(28, 2)) or CovenantID ~= 2) then
    --touch_of_the_magi,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&(!runeforge.siphon_storm|buff.siphon_storm.up)&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=execute_time&mana.pct>variable.ap_minimum_mana_pct&buff.rune_of_power.down
    if S.TouchoftheMagi:IsCastable() and (((not SiphonStormEquipped) or Player:BuffUp(S.SiphonStormBuff)) and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime() and Player:ManaPercentage() > var_ap_minimum_mana_pct and Player:BuffDown(S.RuneofPowerBuff)) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 20"; end
    end
    --touch_of_the_magi,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&buff.arcane_charge.stack<=variable.totm_max_charges&talent.rune_of_power&cooldown.rune_of_power.remains<=execute_time&variable.time_until_ap>variable.totm_max_delay_for_ap
    if S.TouchoftheMagi:IsCastable() and (Player:ArcaneCharges() <= var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime() and var_time_until_ap > var_totm_max_delay_for_ap) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 21"; end
    end
    --touch_of_the_magi,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&buff.arcane_charge.stack<=variable.totm_max_charges&(!talent.rune_of_power|cooldown.rune_of_power.remains>variable.totm_max_delay_for_rop)&variable.time_until_ap>variable.totm_max_delay_for_ap
    if S.TouchoftheMagi:IsCastable() and (Player:ArcaneCharges() <= var_totm_max_charges and ((not S.RuneofPower:IsAvailable()) or S.RuneofPower:CooldownRemains() > var_totm_max_delay_for_rop) and var_time_until_ap > var_totm_max_delay_for_ap) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 22"; end
    end
    --rune_of_power,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&buff.arcane_power.down&(cooldown.touch_of_the_magi.remains>variable.rop_max_delay_for_totm|cooldown.arcane_power.remains<=variable.totm_max_delay_for_ap)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&cooldown.arcane_power.remains>10&cooldown.touch_of_the_magi.remains>10
    if S.RuneofPower:IsCastable() and (Player:BuffDown(S.ArcanePower) and (S.TouchoftheMagi:CooldownRemains() > var_rop_max_delay_for_totm or S.ArcanePower:CooldownRemains() <= var_totm_max_delay_for_ap) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcanePower:CooldownRemains() > 10 and S.TouchoftheMagi:CooldownRemains() > 10) then
      if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power cooldowns 23"; end
    end
  end
  --shifting_power,if=variable.outside_of_cooldowns
  if S.ShiftingPower:IsCastable() and var_outside_of_cooldowns then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power cooldowns 24"; end
  end
  --presence_of_mind,if=talent.rune_of_power&buff.arcane_power.up&buff.rune_of_power.remains<gcd.max
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and S.RuneofPower:IsAvailable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) < Player:GCD() then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cooldowns 25"; end
  end
  --presence_of_mind,if=debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<action.arcane_missiles.execute_time&!covenant.kyrian
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and CovenantID ~= 1 and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagi) < S.ArcaneMissiles:ExecuteTime() then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cooldowns 26"; end
  end
  --presence_of_mind,if=buff.rune_of_power.up&buff.rune_of_power.remains<gcd.max&cooldown.evocation.ready&cooldown.touch_of_the_magi.remains&!covenant.kyrian
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and CovenantID ~= 1 and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) < Player:GCD() and S.Evocation:CooldownRemains() == 0 and S.TouchoftheMagi:CooldownRemains() > 0 then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cooldowns 27"; end
  end
end

local function Rotation()
  --cancel_action,if=action.evocation.channeling&mana.pct>=95&(!runeforge.siphon_storm|buff.siphon_storm.stack=buff.siphon_storm.max_stack)
  --NYI cancel action
  --evocation,if=!runeforge.siphon_storm&mana.pct<=variable.evo_pct
  --&(cooldown.touch_of_the_magi.remains<=action.evocation.execute_time|cooldown.arcane_power.remains<=action.evocation.execute_time|(talent.rune_of_power&cooldown.rune_of_power.remains<=action.evocation.execute_time))
  --&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down&!prev_gcd.1.touch_of_the_magi
  if S.Evocation:IsCastable() and not not SiphonStormEquipped and Player:ManaPercentage() < var_evo_pct 
  and (S.TouchoftheMagi:CooldownRemains() <= S.Evocation:ExecuteTime() or S.ArcanePower:CooldownRemains() <= S.Evocation:ExecuteTime() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.Evocation:ExecuteTime())) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagiDebuff) and not Player:IsCasting(S.TouchoftheMagi) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Rotation 2"; end
  end
  -- Note: The following lines use set_bonus.tier28_2pc&covenant.venthyr, so checking once here
  if (Player:HasTier(28, 2) and CovenantID == 2) then
    --arcane_barrage,if=set_bonus.tier28_2pc&covenant.venthyr&cooldown.touch_of_the_magi.remains<=execute_time&(buff.arcane_charge.stack>variable.totm_max_charges&cooldown.arcane_power.remains<3&mana.pct>variable.ap_minimum_mana_pct&buff.rune_of_power.down)
    if S.ArcaneBarrage:IsCastable() and (S.TouchoftheMagi:CooldownRemains() <= S.ArcaneBarrage:ExecuteTime() and (Player:ArcaneCharges() > var_totm_max_charges and S.ArcanePower:CooldownRemains() < 3 and Player:ManaPercentage() > var_ap_minimum_mana_pct and Player:BuffDown(S.RuneofPowerBuff))) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 3"; end
    end
    --arcane_barrage,if=set_bonus.tier28_2pc&covenant.venthyr&cooldown.rune_of_power.remains<=execute_time&cooldown.touch_of_the_magi.remains<3&(buff.arcane_charge.stack>variable.totm_max_charges&talent.rune_of_power&variable.time_until_ap>variable.totm_max_delay_for_ap)
    if S.ArcaneBarrage:IsCastable() and (S.RuneofPower:CooldownRemains() <= S.ArcaneBarrage:ExecuteTime() and S.TouchoftheMagi:CooldownRemains() < 3 and (Player:ArcaneCharges() > var_totm_max_charges and S.RuneofPower:IsAvailable() and var_time_until_ap > var_totm_max_delay_for_ap)) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 4"; end
    end
  end
  -- Note: The following lines all use (!set_bonus.tier28_2pc|!covenant.venthyr), so checking once here
  if ((not Player:HasTier(28, 2)) or CovenantID ~= 2) then
    --arcane_barrage,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&cooldown.touch_of_the_magi.ready&(buff.arcane_charge.stack>variable.totm_max_charges&cooldown.arcane_power.remains<=execute_time&mana.pct>variable.ap_minimum_mana_pct&buff.rune_of_power.down)
    if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.ArcanePower:CooldownRemains() > S.ArcaneBarrage:ExecuteTime() and Player:ManaPercentage() > var_ap_minimum_mana_pct and Player:BuffDown(S.RuneofPowerBuff) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 5"; end
    end
    --arcane_barrage,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&cooldown.touch_of_the_magi.ready&(buff.arcane_charge.stack>variable.totm_max_charges&talent.rune_of_power&cooldown.rune_of_power.remains<=execute_time&variable.time_until_ap>variable.totm_max_delay_for_ap)
    if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.ArcaneBarrage:ExecuteTime() and var_time_until_ap > var_totm_max_delay_for_ap then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 6"; end
    end
    --arcane_barrage,if=(!set_bonus.tier28_2pc|!covenant.venthyr)&cooldown.touch_of_the_magi.ready&(buff.arcane_charge.stack>variable.totm_max_charges&(!talent.rune_of_power|cooldown.rune_of_power.remains>variable.totm_max_delay_for_rop)&variable.time_until_ap>variable.totm_max_delay_for_ap)
    if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_rop) and var_time_until_ap > var_totm_max_delay_for_ap then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 7"; end
    end
  end
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=debuff.radiant_spark_vulnerability.max_stack&(buff.arcane_power.down|buff.arcane_power.remains<=gcd)&(buff.rune_of_power.down|buff.rune_of_power.remains<=gcd)
  if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == RadiantSparkVulnerabilityMaxStack and (Player:BuffDown(S.ArcanePower) or Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains()) and (Player:BuffDown(S.RuneofPowerBuff) or Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 8"; end
  end
  --arcane_blast,if=variable.just_used_spark|(debuff.radiant_spark_vulnerability.up&debuff.radiant_spark_vulnerability.stack<debuff.radiant_spark_vulnerability.max_stack)
  if S.ArcaneBlast:IsCastable() and (var_just_used_spark or (Target:DebuffUp(S.RadiantSparkVulnerability) and Target:DebuffStack(S.RadiantSparkVulnerability) < RadiantSparkVulnerabilityMaxStack)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 9"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=action.arcane_blast.execute_time
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagi) < (S.ArcaneBlast:ExecuteTime() + Player:GCDRemains()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 10"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo&(buff.deathborne.down|active_enemies=1)&(debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time|cooldown.presence_of_mind.remains|covenant.kyrian),chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|(!talent.overpowered&(buff.rune_of_power.up|cooldown.evocation.ready)))
  --TODO early_chain
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagiDebuff) and S.ArcaneEcho:IsAvailable() and (Player:BuffDown(S.Deathborne) or EnemiesCount8ySplash == 1) and (Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() or S.PresenceofMind:CooldownRemains() > 0 or CovenantID == 1) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 11"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.expanded_potential.up
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ExpandedPotentialBuff) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 12"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&(buff.arcane_power.up|buff.rune_of_power.up|debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and (Player:BuffUp(S.ArcanePower) or Player:BuffUp(S.RuneofPowerBuff) or Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 13"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 14"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.remains<=((buff.clearcasting.stack*action.arcane_missiles.execute_time)+gcd.max),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffRemains(S.ClearcastingBuff)<= ((Player:BuffStack(S.ClearcastingBuff) * S.ArcaneMissiles:ExecuteTime()) + (Player:GCD() + 0.5)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 15"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagiDebuff) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 16"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb rotation 17"; end
  end
  --supernova,if=variable.outside_of_cooldowns&mana.pct<=95
  if S.Supernova:IsCastable() and var_outside_of_cooldowns and Player:ManaPercentage() <= 95 then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova rotation 18"; end
  end
  --arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.RuleofThreesBuff) and Player:ArcaneCharges() > 3 then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 19"; end
  end
  --arcane_barrage,if=!runeforge.siphon_storm&variable.outside_of_cooldowns&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.arcane_orb&cooldown.arcane_orb.remains<=gcd&mana.pct<=90&cooldown.evocation.remains
  if S.ArcaneBarrage:IsCastable() and not SiphonStormEquipped and var_outside_of_cooldowns and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() <= Player:GCD() and Player:ManaPercentage() <= 90 and S.Evocation:CooldownRemains() > 0 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 20"; end
  end
  --arcane_barrage,if=runeforge.siphon_storm&variable.outside_of_cooldowns&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.arcane_orb&cooldown.arcane_orb.remains<=gcd&mana.pct<=90&cooldown.evocation.remains<30
  if S.ArcaneBarrage:IsCastable() and SiphonStormEquipped and var_outside_of_cooldowns and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() <= Player:GCD() and Player:ManaPercentage() <= 90 and S.Evocation:CooldownRemains() < 30 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 21"; end
  end
  --arcane_barrage,if=variable.outside_of_cooldowns&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.arcane_orb&cooldown.arcane_orb.remains<=gcd&mana.pct<=90&cooldown.evocation.remains&(!runeforge.siphon_storm|buff.siphon_storm.remains<=18)
  if S.ArcaneBarrage:IsCastable() and var_outside_of_cooldowns and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() <= Player:GCDRemains() and Player:ManaPercentage() <= 90 and S.Evocation:CooldownRemains() > 0 and (not SiphonStormEquipped or Player:BuffRemains() <= 18) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 22"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(cooldown.evocation.remains|runeforge.arcane_infinity)
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (S.Evocation:CooldownRemains() > 0 or ArcaneInfinityEquipped) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 23"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.arcane_power.down&buff.rune_of_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(cooldown.evocation.remains|runeforge.arcane_infinity)
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (S.Evocation:CooldownRemains() > 0 or ArcaneInfinityEquipped) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 24"; end
  end
  --arcane_barrage,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagi) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 25"; end
  end
  --arcane_barrage,if=variable.empowered_barrage&buff.arcane_charge.stack>=(active_enemies-1)&active_enemies>1&buff.deathborne.down
  if S.ArcaneBarrage:IsCastable() and var_empowered_barrage and Player:ArcaneCharges() >= (EnemiesCount10ySplash - 1) and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Deathborne) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 26"; end
  end
  --arcane_explosion,if=variable.empowered_barrage&buff.arcane_charge.stack<buff.arcane_charge.max_stack&active_enemies>1&buff.deathborne.down
  if S.ArcaneExplosion:IsCastable() and var_empowered_barrage and Player:ArcaneCharges() < Player:ArcaneChargesMax() and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Deathborne) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion rotation 27"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 28"; end
  end
  --evocation,if=variable.outside_of_cooldowns
  if S.Evocation:IsCastable() and var_outside_of_cooldowns then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation rotation 29"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 30"; end
  end
end

local function Final_burn()
  --arcane_missiles,if=buff.clearcasting.react,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Final_burn 1"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable()  then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Final_burn 2"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Final_burn 3"; end
  end
end

local function FishingOpener()
  --evocation,if=(runeforge.temporal_warp|(runeforge.siphon_storm&!variable.prepull_evo=1))&(buff.rune_of_power.down|prev_gcd.1.arcane_barrage)&cooldown.rune_of_power.remains
  if S.Evocation:IsCastable() and (TemporalWarpEquipped or (SiphonStormEquipped and not var_prepull_evo)) and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) and S.RuneofPower:CooldownRemains() >= 0 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation fishing_opener 1"; end
  end
  --evocation,if=talent.rune_of_power&cooldown.rune_of_power.remains&cooldown.arcane_power.remains&buff.arcane_power.down&buff.rune_of_power.down&prev_gcd.1.arcane_barrage
  if S.Evocation:IsCastable() and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() >= 0 and S.ArcanePower:CooldownRemains() >= 0 and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Player:PrevGCD(1,S.ArcaneBarrage) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation fishing_opener 2"; end
  end
  --fire_blast,if=runeforge.disciplinary_command&buff.disciplinary_command_frost.up
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and Mage.DC.Frost == 1 then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast fishing_opener 3"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&mana.pct>95
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and Player:ManaPercentage() > 95 then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova fishing_opener 4"; end
  end
  --arcane_missiles,if=runeforge.arcane_infinity&buff.arcane_harmony.stack<buff.arcane_harmony.max_stack&((buff.arcane_power.down&cooldown.arcane_power.ready)|debuff.touch_of_the_magi.up),chain=1
  if S.ArcaneMissiles:IsCastable() and ArcaneInfinityEquipped and Player:BuffStack(S.ArcaneHarmonyBuff) < ArcaneHarmonyMaxStack and ((Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() == 0) or Target:DebuffUp(S.TouchoftheMagiDebuff))then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 5"; end
  end
  --deathborne,if=conduit.gift_of_the_lich
  if S.Deathborne:IsCastable() and (S.GiftoftheLich:ConduitEnabled()) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne fishing_opener 6"; end
  end
  --rune_of_power,if=runeforge.siphon_storm
  if S.RuneofPower:IsCastable() and SiphonStormEquipped then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power fishing_opener 7"; end
  end
  --arcane_orb,if=cooldown.rune_of_power.ready
  if S.ArcaneOrb:IsCastable() and S.RuneofPower:CooldownRemains() == 0 then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb fishing_opener 8"; end
  end
  --arcane_blast,if=cooldown.rune_of_power.ready&buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneBlast:IsCastable() and S.RuneofPower:CooldownRemains() == 0 and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 9"; end
  end
  --mirrors_of_torment,if=time>=5+(1*set_bonus.tier28_4pc)
  if S.MirrorsofTorment:IsCastable() and (HL.CombatTime() >= 5 + (1 * num(Player:HasTier(28, 4)))) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment fishing_opener 10"; end
  end
  --use_item,name=moonlit_prism,if=time>6&(!equipped.the_first_sigil|trinket.the_first_sigil.cooldown.remains)
  if I.MoonlitPrism:IsEquippedAndReady() and (HL.CombatTime() > 6 and ((not I.TheFirstSigil:IsEquipped()) or I.TheFirstSigil:CooldownRemains() > 0)) then
    if Cast(I.MoonlitPrism, nil, Settings.Commons.DisplayStyle.Trinkets) then return "moonlit_prism fishing_opener 11"; end
  end
  --rune_of_power
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and not S.ArcanePower:IsCastable() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power fishing_opener 12"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack&covenant.venthyr&cooldown.mirrors_of_torment.ready&!variable.empowered_barrage&cooldown.arcane_power.ready
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack and CovenantID == 2 and S.MirrorsofTorment:CooldownRemains() == 0 and not var_empowered_barrage and S.RuneofPower:CooldownRemains() == 0 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 13"; end
  end
  --potion,if=!runeforge.temporal_warp&(!runeforge.siphon_storm|(variable.prepull_evo=1&buff.arcane_charge.stack=buff.arcane_charge.max_stack))
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (not TemporalWarpEquipped and (not SiphonStormEquipped and (var_prepull_evo and Player:ArcaneCharges() == Player:ArcaneChargesMax()))) then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion fishing_opener 14"; end
  end
  --deathborne,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage
  if S.Deathborne:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne fishing_opener 15"; end
  end
  --radiant_spark,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage
  if S.RadiantSpark:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark fishing_opener 16"; end
  end
  --mirrors_of_torment,if=buff.rune_of_power.remains<(6+2*runeforge.siphon_storm)
  if S.MirrorsofTorment:IsCastable() and Player:BuffRemains(S.RuneofPowerBuff) < (6 + 2 * num(SiphonStormEquipped)) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment fishing_opener 17"; end
  end
  --arcane_power,if=variable.empowered_barrage&buff.rune_of_power.up&(mana.pct<(25+(10*covenant.kyrian))|buff.clearcasting.stack=buff.clearcasting.max_stack)
  if S.ArcanePower:IsCastable() and var_empowered_barrage and Player:BuffUp(S.RuneofPowerBuff) and ((Player:ManaPercentage() < (25 + (10 * num(CovenantID == 1)))) or Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power fishing_opener 18"; end
  end
  --arcane_barrage,if=variable.empowered_barrage&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_power.up
  if S.ArcaneBarrage:IsCastable() and var_empowered_barrage and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffUp(S.ArcanePower) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 19"; end
  end
  --use_item,name=soulletting_ruby,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage|prev_gcd.1.radiant_spark|(prev_gcd.1.deathborne&!runeforge.siphon_storm)
  if I.SoullettingRuby:IsEquippedAndReady() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage) or Player:IsCasting(S.RadiantSpark) or (Player:IsCasting(S.Deathborne) and not SiphonStormEquipped)) then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby fishing_opener 20"; end
  end
  --touch_of_the_magi,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage|prev_gcd.1.radiant_spark|(prev_gcd.1.deathborne&!runeforge.siphon_storm)
  if S.TouchoftheMagi:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage) or Player:IsCasting(S.RadiantSpark) or (Player:IsCasting(S.Deathborne) and not SiphonStormEquipped)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi fishing_opener 21"; end
  end
  --arcane_power,if=prev_gcd.1.touch_of_the_magi
  if S.ArcanePower:IsCastable() and Player:IsCasting(S.TouchoftheMagi) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power fishing_opener 22"; end
  end
  --presence_of_mind,if=!talent.arcane_echo&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and S.ArcaneEcho:IsAvailable() and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagi) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind fishing_opener 23"; end
  end
  --presence_of_mind,if=buff.arcane_power.up&buff.rune_of_power.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind fishing_opener 24"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparkVulnerability) > 0) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 25"; end
  end
  --arcane_barrage,if=cooldown.arcane_power.ready&mana.pct<(40+(10*covenant.kyrian))&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(!runeforge.siphon_storm|variable.prepull_evo=1)&!runeforge.temporal_warp&!runeforge.arcane_infinity
  if S.ArcaneBarrage:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and Player:ManaPercentage() < ( 40 + (10 * num(CovenantID == 1))) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (not SiphonStormEquipped or var_prepull_evo) and not TemporalWarpEquipped and not ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 26"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&cooldown.evocation.remains
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCD() and S.Evocation:CooldownRemains() > 0 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 27"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.arcane_power.down&buff.rune_of_power.remains<=gcd&!runeforge.arcane_infinity
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCD() and ArcaneInfinityEquipped and not ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 28"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo&(buff.deathborne.down|active_enemies=1)&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|(!talent.overpowered&(buff.rune_of_power.up|cooldown.evocation.ready)))
  --TODO : early chain
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagiDebuff) and S.ArcaneEcho:IsAvailable() and (Player:BuffDown(S.Deathborne) or EnemiesCount8ySplash == 1) and Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 29"; end
  end
  --arcane_missiles,if=covenant.venthyr&buff.clearcasting.stack=buff.clearcasting.max_stack
  if S.ArcaneMissiles:IsCastable() and CovenantID == 2 and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 30"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&cooldown.arcane_power.remains&(buff.rune_of_power.up|buff.arcane_power.up),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and S.ArcanePower:CooldownRemains() > 0 and (Player:BuffUp(S.RuneofPowerBuff or Player:BuffUp(S.ArcanePower))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 31"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb fishing_opener 32"; end
  end
  --arcane_blast,if=buff.rune_of_power.up|mana.pct>15
  if S.ArcaneBlast:IsCastable() and (Player:BuffUp(S.RuneofPowerBuff) or Player:ManaPercentage() > 15) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 33"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:ManaPercentage() < 85 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation fishing_opener 34"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 35"; end
  end
end

local function Harmony()
  --cancel_action,if=action.evocation.channeling&mana.pct>=95
  --NYI cancel action
  --evocation,if=mana.pct<=30&variable.outside_of_cooldowns&(talent.rune_of_power&cooldown.rune_of_power.remains<10)
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 30
  and var_outside_of_cooldowns and (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() < 10) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation harmony 2"; end
  end
  --arcane_missiles,if=(variable.stack_harmony|time<10)&buff.arcane_harmony.stack<16&(active_enemies<variable.aoe_spark_target_count|variable.outside_of_cooldowns),chain=1
  if S.ArcaneMissiles:IsCastable() and (var_stack_harmony or CombatTime() < 10) and Player:BuffStack(S.ArcaneHarmonyBuff) < 16 and (EnemiesCount10ySplash < var_aoe_spark_target_count or var_outside_of_cooldowns) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 3"; end
  end
  --arcane_missiles,if=equipped.empyreal_ordnance&time<30&cooldown.empyreal_ordnance.remains>168
  if S.ArcaneMissiles:IsCastable() and I.EmpyrealOrdnance:IsEquipped() and CombatTime() < 30 and I.EmpyrealOrdnance:CooldownRemains() > 168 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 4"; end
  end
  --use_item,name=soulletting_ruby,if=buff.arcane_power.up&target.distance<=10
  if I.SoullettingRuby:IsEquippedAndReady() and Player:BuffUp(S.ArcanePower) and Target:MaxDistance() <= 10 then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby harmony 4.2"; end
  end
  --use_item,name=soulletting_ruby,if=variable.empowered_barrage&cooldown.touch_of_the_magi.remains<=execute_time&cooldown.arcane_power.remains<=(execute_time*2)
  if I.SoullettingRuby:IsEquippedAndReady() and var_empowered_barrage and S.TouchoftheMagi:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() <= Player:GCD() * 2 then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby harmony 4.5"; end
  end
  --radiant_spark,if=variable.empowered_barrage&cooldown.touch_of_the_magi.remains<=execute_time&cooldown.arcane_power.remains<=(execute_time*2)&(!equipped.soulletting_ruby|conduit.arcane_prodigy.rank>=5|(trinket.soulletting_ruby.cooldown.remains>110&target.distance>10)|(trinket.soulletting_ruby.cooldown.remains<=execute_time&target.distance<=10))
  if S.RadiantSpark:IsCastable() and (var_empowered_barrage and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime() and S.ArcanePower:CooldownRemains() <= S.RadiantSpark:ExecuteTime() * 2
  and (not I.SoullettingRuby:IsEquipped() or S.ArcaneProdigy:ConduitRank() >= 5 or (I.SoullettingRuby:CooldownRemains() > 110
  and not Target:IsInRange(10)) or (I.SoullettingRuby:CooldownRemains() <= S.RadiantSpark:ExecuteTime() and Target:IsInRange(10)))) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark harmony 5"; end
  end
  --touch_of_the_magi,if=variable.just_used_spark&cooldown.arcane_power.remains<=execute_time
  --&(!equipped.soulletting_ruby|conduit.arcane_prodigy.rank>=5|(trinket.soulletting_ruby.cooldown.remains>110
  --&target.distance>10)|(trinket.soulletting_ruby.cooldown.remains<=execute_time&target.distance<=10))
  if S.TouchoftheMagi:IsCastable() and (var_just_used_spark and S.ArcanePower:CooldownRemains() <= S.RadiantSpark:ExecuteTime()
  and (not I.SoullettingRuby:IsEquipped() or S.ArcaneProdigy:ConduitRank() >= 5 or (I.SoullettingRuby:CooldownRemains() > 110
  and not Target:IsInRange(10)) or (I.SoullettingRuby:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime() and Target:IsInRange(10)))) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi harmony 6"; end
  end
  --arcane_power,if=prev_gcd.1.touch_of_the_magi
  if S.ArcanePower:IsCastable() and Player:IsCasting(S.TouchoftheMagi) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power harmony 7"; end
  end
  --rune_of_power,if=variable.empowered_barrage&cooldown.radiant_spark.remains<=execute_time&variable.time_until_ap>=20&(!conduit.arcane_prodigy|!variable.always_sync_cooldowns|cooldown.touch_of_the_magi.remains<=(execute_time*2))
  if S.RuneofPower:IsCastable() and var_empowered_barrage and S.RadiantSpark:CooldownRemains() <= S.RuneofPower:ExecuteTime() and var_time_until_ap >= 20 and (not S.ArcaneProdigy:ConduitEnabled() or not var_always_sync_cooldowns or S.TouchoftheMagi:CooldownRemains() <= (S.RuneofPower:ExecuteTime() * 2)) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power harmony 8"; end
  end
  --radiant_spark,if=variable.empowered_barrage&prev_gcd.1.rune_of_power
  if S.RadiantSpark:IsCastable() and var_empowered_barrage and Player:IsCasting(S.RuneofPower) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark harmony 9"; end
  end
  --touch_of_the_magi,if=variable.just_used_spark&!variable.holding_totm
  if S.TouchoftheMagi:IsCastable() and var_just_used_spark and not var_holding_totm then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi harmony 10"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.up&buff.arcane_power.up&buff.arcane_harmony.stack>=16&buff.arcane_power.remains<=action.arcane_barrage.execute_time&buff.bloodlust.up
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffUp(S.ArcanePower) and Player:BuffStack(S.ArcaneHarmonyBuff) >= 16 and Player:BuffRemains(S.ArcanePower) <= S.ArcaneBarrage:ExecuteTime() and Player:BloodlustUp() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 11"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&buff.bloodlust.up&(variable.time_until_ap>30|cooldown.radiant_spark.remains>12)&(buff.arcane_harmony.stack>=15|buff.clearcasting.stack>=1)&(!conduit.arcane_prodigy|!variable.always_sync_cooldowns)
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BloodlustUp() and (var_time_until_ap > 30 or S.RadiantSpark:CooldownRemains() > 12) and (Player:BuffStack(S.ArcaneHarmonyBuff) >= 15 or Player:BuffStack(S.ClearcastingBuff) >= 1) and (not S.ArcaneProdigy:ConduitEnabled() or not var_always_sync_cooldowns) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power harmony 12"; end
  end
  --rune_of_power,if=buff.arcane_power.down&(variable.time_until_ap>30|cooldown.radiant_spark.remains>12)&(!conduit.arcane_prodigy|!variable.always_sync_cooldowns)
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.ArcanePower) and (var_time_until_ap > 30 or S.RadiantSpark:CooldownRemains() > 12) and (not S.ArcaneProdigy:ConduitEnabled() or not var_always_sync_cooldowns) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power harmony 13"; end
  end
  --radiant_spark,if=variable.empowered_barrage&(buff.arcane_charge.stack>=2|cooldown.arcane_orb.ready)
  --&(!talent.rune_of_power|cooldown.rune_of_power.remains>5)&variable.estimated_ap_cooldown>=30
  --&(!conduit.arcane_prodigy|!variable.always_sync_cooldowns)
  if S.RadiantSpark:IsCastable() and var_empowered_barrage and (Player:ArcaneCharges() >= 2 or S.ArcaneOrb:CooldownRemains() == 0) 
  and (not S.RuneofPower:IsAvailable() or S.RuneofPower:CooldownRemains() > 5) and var_estimated_ap_cooldown >= 30
  and (not S.ArcaneProdigy:ConduitEnabled() or not var_always_sync_cooldowns) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark harmony 14"; end
  end
  --touch_of_the_magi,if=variable.time_until_ap<50&variable.time_until_ap>30&(!equipped.soulletting_ruby|conduit.arcane_prodigy.rank>=5)
  if S.TouchoftheMagi:IsCastable() and var_time_until_ap < 50 and var_time_until_ap > 30 and (not I.SoullettingRuby:IsEquipped() or S.ArcaneProdigy:ConduitRank() >= 5) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi harmony 15"; end
  end
  --arcane_orb,if=variable.just_used_spark&buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneOrb:IsCastable() and var_just_used_spark and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 16"; end
  end
  --arcane_orb,if=debuff.radiant_spark_vulnerability.stack=3&active_enemies>=variable.aoe_spark_target_count
  if S.ArcaneOrb:IsCastable() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 3 and EnemiesCount10ySplash >= var_aoe_spark_target_count) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 17"; end
  end
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=2&active_enemies>=variable.aoe_spark_target_count
  if S.ArcaneBarrage:IsReady() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 2 and EnemiesCount10ySplash >= var_aoe_spark_target_count) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 18"; end
  end
  --wait,sec=0.04,if=debuff.radiant_spark_vulnerability.stack=1&prev_gcd.1.arcane_blast&active_enemies>=variable.aoe_spark_target_count,line_cd=25
  --arcane_blast,if=debuff.radiant_spark_vulnerability.stack=1&runeforge.harmonic_echo&active_enemies>=variable.aoe_spark_target_count
  if S.ArcaneBlast:IsReady() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 1 and HarmonicEchoEquipped and EnemiesCount10ySplash >= var_aoe_spark_target_count) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 19"; end
  end
  --arcane_explosion,if=debuff.radiant_spark_vulnerability.stack=1&active_enemies>=variable.aoe_spark_target_count
  if S.ArcaneExplosion:IsReady() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 1 and EnemiesCount10ySplash >= var_aoe_spark_target_count) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion harmony 20"; end
  end
  --arcane_explosion,if=prev_gcd.2.radiant_spark&active_enemies>=variable.aoe_spark_target_count
  if S.ArcaneExplosion:IsReady() and (Player:PrevGCD(2, S.RadiantSpark) and EnemiesCount10ySplash >= var_aoe_spark_target_count) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion harmony 21"; end
  end
  --wait,sec=0.04,if=debuff.radiant_spark_vulnerability.stack=(debuff.radiant_spark_vulnerability.max_stack-1)&runeforge.harmonic_echo&active_enemies>1,line_cd=25
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=debuff.radiant_spark_vulnerability.max_stack
  if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == RadiantSparkVulnerabilityMaxStack then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 22"; end
  end
  --arcane_blast,if=variable.just_used_spark|(debuff.radiant_spark_vulnerability.up&debuff.radiant_spark_vulnerability.stack<debuff.radiant_spark_vulnerability.max_stack)
  if S.ArcaneBlast:IsCastable() and (var_just_used_spark or (Target:DebuffUp(S.RadiantSparkVulnerability) and Target:DebuffStack(S.RadiantSparkVulnerability) < RadiantSparkVulnerabilityMaxStack)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 23"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<3&variable.time_until_ap>10&(cooldown.touch_of_the_magi.remains>5|!conduit.arcane_prodigy)
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < 3 and var_time_until_ap > 10 and (S.TouchoftheMagi:CooldownRemains() > 5 or not S.ArcaneProdigy:ConduitEnabled()) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 24"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.arcane_power.up,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ArcanePower) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 25"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.rune_of_power.remains<=action.arcane_missiles.execute_time&buff.arcane_power.up&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_harmony.stack&buff.power_infusion.up&buff.bloodlust.up
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) <= S.ArcaneMissiles:ExecuteTime() and Player:BuffUp(S.ArcanePower) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffUp(S.ArcaneHarmonyBuff) and Player:PowerInfusionUp() and Player:BloodlustUp() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 26"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&(buff.arcane_charge.stack<buff.arcane_charge.max_stack|!(buff.power_infusion.up&buff.bloodlust.up))&!(buff.arcane_charge.stack=0&buff.presence_of_mind.stack=1)
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and (Player:ArcaneCharges() < Player:ArcaneChargesMax() or not (Player:PowerInfusionUp() and Player:BloodlustUp()) and (not (Player:ArcaneCharges() == 0 and Player:BuffStack(S.PresenceofMind) == 1))) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 27"; end
  end
  --presence_of_mind,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&buff.arcane_power.up&active_enemies<variable.aoe_target_count
  if S.PresenceofMind:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() and Player:BuffUp(S.ArcanePower) and EnemiesCount10ySplash < var_aoe_target_count then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind harmony 28"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&active_enemies>=variable.aoe_target_count,chain=1
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and EnemiesCount10ySplash >= var_aoe_target_count) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 29"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&active_enemies>=variable.aoe_target_count
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and EnemiesCount10ySplash >= var_aoe_target_count) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 30"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&active_enemies>=variable.aoe_target_count
  if S.ArcaneExplosion:IsCastable() and (Player:ArcaneCharges() < Player:ArcaneChargesMax() and EnemiesCount10ySplash >= var_aoe_target_count) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion harmony 31"; end
  end
  --arcane_missiles,if=buff.arcane_harmony.stack<16,chain=1,interrupt=1,interrupt_global=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) < 16 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 32"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&variable.empowered_barrage
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and var_empowered_barrage then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 33"; end
  end
  --evocation,if=mana.pct<15
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 15 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation fishing_opener 34"; end
  end
  --arcane_blast,if=buff.arcane_charge.stack&buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneBlast:IsCastable() and Player:ArcaneCharges() > 1 and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 35"; end
  end
  --arcane_missiles,if=!(variable.time_until_ap<=10&mana.pct<30),chain=1,interrupt=1,interrupt_global=1
  if S.ArcaneMissiles:IsCastable() and not (var_time_until_ap <= 10 and Player:ManaPercentage() < 30) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 36"; end
  end
  --fire_blast
  if S.FireBlast:IsCastable() then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast fishing_opener 37"; end
  end
  --frostbolt
  if S.Frostbolt:IsReady() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt fishing_opener 38"; end
  end
end

local function Aoe()
  --frostbolt,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd))
  if S.Frostbolt:IsReady() and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Frost == 0 
  and (Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff)) and S.TouchoftheMagi:CooldownRemains() == 0 and (Player:ArcaneCharges() <= var_totm_max_charges 
  and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt Aoe 1"; end
  end
  --fire_blast,if=(runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt)|(runeforge.disciplinary_command&time=0)
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0 and Player:IsCasting(S.Frostbolt) then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast Aoe 2"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd))
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() > 30 and S.TouchoftheMagi:CooldownRemains() == 0
  and (Player:ArcaneCharges() <= var_totm_max_charges 
  and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap)
  or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap)
  or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova Aoe 3"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and S.ArcanePower:CooldownRemains() == 0
  and (((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) 
  or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= Player:ArcaneChargesMax()))
  and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova Aoe 4"; end
  end
  --arcane_missiles,if=covenant.venthyr&runeforge.arcane_infinity&buff.arcane_harmony.stack<15&cooldown.touch_of_the_magi.remains<=variable.harmony_stack_time+execute_time&cooldown.arcane_power.remains<=variable.harmony_stack_time+execute_time+action.touch_of_the_magi.execute_time,chain=1
  if S.ArcaneMissiles:IsCastable() and CovenantID == 1 and ArcaneInfinityEquipped and Player:BuffStack(S.ArcaneHarmonyBuff) < 15 and S.TouchoftheMagi:CooldownRemains() <= var_harmony_stack_time + S.ArcaneMissiles:ExecuteTime() 
  and S.ArcanePower:CooldownRemains() <= var_harmony_stack_time + S.ArcaneMissiles:ExecuteTime() + S.TouchoftheMagi:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 5.5"; end
  end
  --arcane_blast,if=covenant.venthyr&talent.arcane_echo&time<10&cooldown.mirrors_of_torment.remains&buff.clearcasting.stack<3
  if S.ArcaneBlast:IsCastable() and CovenantID == 2 and S.ArcaneEcho:IsAvailable() and S.MirrorsofTorment:CooldownRemains() > 0 and Player:BuffStack(S.ClearcastingBuff) < 3 then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Aoe 6"; end
  end
  --touch_of_the_magi,if=runeforge.siphon_storm&prev_gcd.1.evocation
  if S.TouchoftheMagi:IsCastable() and SiphonStormEquipped and Player:IsCasting(S.Evocation) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 7"; end
  end
  --arcane_power,if=runeforge.siphon_storm&(prev_gcd.1.evocation|prev_gcd.1.touch_of_the_magi)
  if S.ArcanePower:IsCastable() and SiphonStormEquipped and (Player:IsCasting(S.Evocation) or Player:IsCasting(S.TouchoftheMagi)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "touch_of_the_magi Aoe 8"; end
  end
  --mirrors_of_torment,if=runeforge.arcane_infinity&cooldown.touch_of_the_magi.remains<=10&cooldown.arcane_power.remains<=15
  if S.MirrorsofTorment:IsCastable() and ArcaneInfinityEquipped and S.TouchoftheMagi:CooldownRemains() <= 10 and S.ArcanePower:CooldownRemains() <= 15 then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment Aoe 8.5"; end
  end
  --mirrors_of_torment,if=cooldown.arcane_power.remains<=8&cooldown.touch_of_the_magi.remains<=8&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>5)|(!talent.rune_of_power&cooldown.arcane_power.remains>5)|cooldown.arcane_power.remains<=gcd))
  if S.MirrorsofTorment:IsCastable() and S.ArcanePower:CooldownRemains() <= 8 and S.TouchoftheMagi:CooldownRemains() <= 8 
  and (Player:ArcaneCharges() <= var_aoe_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > 5) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > 5) or S.ArcanePower:CooldownRemains() <= Player:GCD())) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment Aoe 9"; end
  end
  --evocation,if=time>30&runeforge.siphon_storm&covenant.venthyr&prev_gcd.1.mirrors_of_torment
  if S.Evocation:IsCastable() and CombatTime() > 30 and CovenantID == 2 and Player:IsCasting(S.MirrorsofTorment) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Aoe 10"; end
  end
  --evocation,if=time>30&runeforge.siphon_storm&buff.arcane_charge.stack<=variable.aoe_totm_max_charges&cooldown.touch_of_the_magi.remains=0&cooldown.arcane_power.remains<=gcd
  if S.Evocation:IsCastable() and CombatTime() > 30 and SiphonStormEquipped and Player:ArcaneCharges() <= var_aoe_totm_max_charges and S.TouchoftheMagi:CooldownRemains() == 0 and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Aoe 11"; end
  end
  --evocation,if=time>30&runeforge.siphon_storm&cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down),interrupt_if=buff.siphon_storm.stack=buff.siphon_storm.max_stack,interrupt_immediate=1
  --TODO : manage siphon_storm interrupt_if
  if S.Evocation:IsCastable() and CombatTime() > 30 and SiphonStormEquipped and S.ArcanePower:CooldownRemains() == 0
  and (((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= Player:ArcaneChargesMax())) 
  and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Aoe 12"; end
  end
  --use_item,name=soulletting_ruby,if=cooldown.radiant_spark.ready&cooldown.touch_of_the_magi.remains<=gcd.max&cooldown.arcane_power.remains<=gcd.max
  if Settings.Commons.Enabled.Trinkets and I.SoullettingRuby:IsEquippedAndReady() and (S.RadiantSpark:CooldownUp() and S.TouchoftheMagi:CooldownRemains() <= Player:GCD() + 0.5 and S.ArcanePower:CooldownRemains() <= Player:GCD() + 0.5) then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby Aoe 12.5"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains<execute_time&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd)
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime() 
  and ((S.RuneofPower:IsAvailable() and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) 
  or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or S.ArcanePower:CooldownRemains() <= Player:GCD()) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark Aoe 13"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains<execute_time&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() < S.RadiantSpark:ExecuteTime() 
  and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= Player:ArcaneChargesMax())) 
  and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark Aoe 14"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne Aoe 15"; end
  end
  --use_item,name=soulletting_ruby,if=(buff.arcane_charge.stack<=variable.aoe_totm_max_charges|prev_gcd.1.radiant_spark)&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd)&!(soulbind.effusive_anima_accelerator&runeforge.harmonic_echo)
  if Settings.Commons.Enabled.Trinkets and I.SoullettingRuby:IsEquippedAndReady() and ((Player:ArcaneCharges() <= var_aoe_totm_max_charges or Player:IsCasting(S.RadiantSpark)) and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) and not (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped)) then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby Shared_cd 15.2"; end
  end
  --touch_of_the_magi,if=covenant.venthyr&runeforge.arcane_infinity&cooldown.mirrors_of_torment.remains<=50
  if S.TouchoftheMagi:IsCastable() and CovenantID == 2 and S.MirrorsofTorment:CooldownRemains() <= 50 then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 15.5"; end
  end
  --touch_of_the_magi,if=covenant.venthyr&runeforge.arcane_infinity&buff.mirrors_of_torment.remains<=20&cooldown.arcane_power.remains<=gcd
  if S.TouchoftheMagi:IsCastable() and CovenantID == 2 then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 15.7"; end
  end
  --touch_of_the_magi,if=(buff.arcane_charge.stack<=variable.aoe_totm_max_charges|prev_gcd.1.radiant_spark)&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd)&!(soulbind.effusive_anima_accelerator&runeforge.harmonic_echo)
  if S.TouchoftheMagi:IsCastable() and ((Player:ArcaneCharges() <= var_totm_max_charges or Player:IsCasting(S.RadiantSpark)) and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) and not (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 16"; end
  end
  --arcane_power,if=((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down&!(soulbind.effusive_anima_accelerator&runeforge.harmonic_echo)
  if CDsON() and S.ArcanePower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and not (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power Aoe 17"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&((cooldown.touch_of_the_magi.remains>20&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&(cooldown.arcane_power.remains>12|debuff.touch_of_the_magi.up)&!(soulbind.effusive_anima_accelerator&runeforge.harmonic_echo)
  if CDsON() and S.RuneofPower:IsCastable() and not S.ArcanePower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > 20 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and (S.ArcanePower:CooldownRemains() > S.RuneofPower:BaseDuration() or Target:DebuffUp(S.TouchoftheMagiDebuff)) and not (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped)) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power Aoe 18"; end
  end
  --shifting_power,if=cooldown.arcane_orb.remains>5|!talent.arcane_orb
  if S.ShiftingPower:IsCastable() and S.ArcaneOrb:CooldownRemains() > 5 or not S.ArcaneOrb:IsAvailable() then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "deathborne Aoe 19"; end
  end
  --rune_of_power,if=soulbind.effusive_anima_accelerator&runeforge.harmonic_echo&cooldown.radiant_spark.remains<=execute_time
  if CDsON() and S.RuneofPower:IsCastable() and (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped and S.RadiantSpark:CooldownRemains() <= S.RuneofPower:ExecuteTime()) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power Aoe 20"; end
  end
  --radiant_spark,if=soulbind.effusive_anima_accelerator&runeforge.harmonic_echo&(buff.arcane_charge.stack>=2|cooldown.touch_of_the_magi.remains<=execute_time)
  if S.RadiantSpark:IsCastable() and (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped and (Player:ArcaneCharges() >= 2 or S.TouchoftheMagi:CooldownRemains() <= S.RadiantSpark:ExecuteTime())) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark Aoe 21"; end
  end
  --touch_of_the_magi,if=soulbind.effusive_anima_accelerator&runeforge.harmonic_echo&prev_gcd.1.radiant_spark
  if S.TouchoftheMagi:IsCastable() and (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped and Player:PrevGCD(1, S.RadiantSpark)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 22"; end
  end
  --arcane_power,if=soulbind.effusive_anima_accelerator&runeforge.harmonic_echo&prev_gcd.1.touch_of_the_magi
  if CDsON() and S.ArcanePower:IsCastable() and (S.EffusiveAnimaAccelerator:SoulbindEnabled() and HarmonicEchoEquipped and Player:PrevGCD(1, S.TouchoftheMagi)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power Aoe 23"; end
  end
  --arcane_explosion,if=runeforge.harmonic_echo&debuff.radiant_spark_vulnerability.stack=1
  if S.ArcaneExplosion:IsReady() and (HarmonicEchoEquipped and Target:DebuffStack(S.RadiantSparkVulnerability) == 1) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion Aoe 31"; end
  end
  --arcane_explosion,if=runeforge.harmonic_echo&(prev_gcd.1.radiant_spark|(prev_gcd.2.radiant_spark&debuff.touch_of_the_magi.up))
  if S.ArcaneExplosion:IsReady() and (HarmonicEchoEquipped and (Player:PrevGCD(1, S.RadiantSpark) or (Player:PrevGCD(2, S.RadiantSpark) and Target:DebuffUp(S.TouchoftheMagiDebuff)))) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion Aoe 32"; end
  end
  --arcane_orb,if=runeforge.harmonic_echo&debuff.radiant_spark_vulnerability.stack=3
  if S.ArcaneOrb:IsCastable() and (HarmonicEchoEquipped and Target:DebuffStack(S.RadiantSparkVulnerability) == 3) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb Aoe 33"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&talent.arcane_echo&debuff.touch_of_the_magi.up
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and S.ArcaneEcho:IsAvailable() and Target:DebuffUp(S.TouchoftheMagiDebuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 34"; end
  end
  --presence_of_mind,if=buff.deathborne.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time&((talent.resonance&active_enemies<4)|active_enemies<5)&(!runeforge.arcane_bombardment|target.health.pct>35)
  if CDsON() and S.PresenceofMind:IsCastable() and Player:BuffUp(S.Deathborne) and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagi) <= (PresenceMaxStack * S.ArcaneBlast:ExecuteTime()) + Player:GCDRemains() 
  and ((S.Resonance:IsAvailable() and EnemiesCount8ySplash < 4) or EnemiesCount8ySplash < 5) and (not ArcaneBombardmentEquipped or Target:HealthPercentage() > 35) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind Aoe 35"; end
  end
  --arcane_blast,if=buff.deathborne.up&((talent.resonance&active_enemies<4)|active_enemies<5)&(!runeforge.arcane_bombardment|target.health.pct>35)
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.Deathborne) and ((S.Resonance:IsAvailable() and EnemiesCount8ySplash < 4) or EnemiesCount8ySplash < 5) and (not ArcaneBombardmentEquipped or Target:HealthPercentage() > 35) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Aoe 36"; end
  end
  --supernova
  if S.Supernova:IsCastable() then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova Aoe 37"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack>=(active_enemies-1)&runeforge.arcane_bombardment&target.health.pct<35
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() >= (EnemiesCount8ySplash - 1) and ArcaneBombardmentEquipped and Target:HealthPercentage() < 35 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Aoe 38"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Aoe 39"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack=0&(cooldown.arcane_power.remains>15|!(covenant.kyrian&runeforge.arcane_infinity))
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= 0 and (S.ArcanePower:CooldownRemains() > 15 or not (CovenantID == 1 and ArcaneInfinityEquipped)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb Aoe 40"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest Aoe 41"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&runeforge.arcane_infinity&((talent.amplification&active_enemies<8)|active_enemies<5)
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and ArcaneInfinityEquipped and ((S.Amplification:IsAvailable() and EnemiesCount8ySplash < 8) or EnemiesCount8ySplash < 5) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 42"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&talent.amplification&active_enemies<4
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and S.Amplification:IsAvailable() or EnemiesCount8ySplash < 4 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 43"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneExplosion:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion Aoe 44"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&prev_gcd.1.arcane_barrage
  if S.ArcaneExplosion:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:IsCasting(S.ArcaneBarrage) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion Aoe 45"; end
  end
  --evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 85 then
    if Cast(S.Evocation) then return "evocation Aoe 46"; end
  end
end

local function Vaoe()
  if (HL.CombatTime() < 7) then
    --rune_of_power,if=time<7
    if S.RuneofPower:IsCastable() then
      if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power vaoe 1"; end
    end
    --arcane_orb,if=time<7
    if S.ArcaneOrb:IsCastable() then
      if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb vaoe 2"; end
    end
    --arcane_explosion,if=time<7
    if S.ArcaneExplosion:IsCastable() then
      if CastAE(S.ArcaneExplosion) then return "arcane_explosion vaoe 3"; end
    end
  end
  --use_item,name=moonlit_prism,if=prev_gcd.1.mirrors_of_torment&(!equipped.the_first_sigil|trinket.the_first_sigil.cooldown.remains)
  if I.MoonlitPrism:IsEquippedAndReady() and Settings.Commons.Enabled.Trinkets and (Player:PrevGCD(1, S.MirrorsofTorment) and ((not I.TheFirstSigil:IsEquipped()) or I.TheFirstSigil:CooldownRemains() > 0)) then
    if Cast(I.MoonlitPrism, nil, Settings.Commons.DisplayStyle.Trinkets) then return "moonlit_prism vaoe 4"; end
  end
  --evocation,if=cooldown.touch_of_the_magi.remains<=(action.evocation.execute_time+13)&cooldown.arcane_power.remains<=(action.evocation.execute_time+14)
  if S.Evocation:IsCastable() and (S.TouchoftheMagi:CooldownRemains() <= (S.Evocation:ExecuteTime() + 13) and S.ArcanePower:CooldownRemains() <= (S.Evocation:ExecuteTime() + 14)) then
    if Cast(S.Evocation) then return "evocation vaoe 5"; end
  end
  --mirrors_of_torment,if=time>6&cooldown.touch_of_the_magi.remains<=9&buff.siphon_storm.up
  if S.MirrorsofTorment:IsCastable() and (HL.CombatTime() > 6 and S.TouchoftheMagi:CooldownRemains() <= 9 and Player:BuffUp(S.SiphonStormBuff)) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenants) then return "mirrors_of_torment vaoe 6"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.siphon_storm.remains>20&!debuff.mirrors_of_torment.up
  if S.ArcaneExplosion:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffRemains(S.SiphonStormBuff) > 20 and Target:DebuffDown(S.MirrorsofTorment)) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion vaoe 7"; end
  end
  --arcane_blast,if=debuff.mirrors_of_torment.up&time<13
  if S.ArcaneBlast:IsCastable() and (Target:DebuffUp(S.MirrorsofTorment) and HL.CombatTime() < 13) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast vaoe 8"; end
  end
  --arcane_blast,if=debuff.mirrors_of_torment.remains>=19&cooldown.touch_of_the_magi.remains
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.MirrorsofTorment) >= 19 and S.TouchoftheMagi:CooldownRemains() > 0) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast vaoe 9"; end
  end
  --rune_of_power,if=buff.arcane_power.down&cooldown.touch_of_the_magi.remains<=execute_time&cooldown.arcane_power.remains>10
  if S.RuneofPower:IsCastable() and (Player:BuffDown(S.ArcanePower) and S.TouchoftheMagi:CooldownRemains() <= S.RuneofPower:ExecuteTime() and S.ArcanePower:CooldownRemains() > 10) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power vaoe 10"; end
  end
  --touch_of_the_magi,if=time>=13&cooldown.arcane_power.remains<=execute_time
  if S.TouchoftheMagi:IsCastable() and (HL.CombatTime() >= 13 and S.ArcanePower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime()) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi vaoe 11"; end
  end
  --touch_of_the_magi,if=time>30&prev_gcd.1.rune_of_power
  if S.TouchoftheMagi:IsCastable() and (HL.CombatTime() > 30 and Player:PrevGCD(1, S.RuneofPower)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi vaoe 12"; end
  end
  --arcane_power,if=prev_gcd.1.touch_of_the_magi
  if S.ArcanePower:IsCastable() and (Player:PrevGCD(1, S.TouchoftheMagi)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power vaoe 13"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.siphon_storm.remains>24&!debuff.touch_of_the_magi.down
  if S.ArcaneExplosion:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffRemains(S.SiphonStormBuff) > 24 and Target:DebuffUp(S.TouchoftheMagiDebuff)) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion vaoe 14"; end
  end
  --arcane_blast,if=cooldown.touch_of_the_magi.remains<=8&cooldown.rune_of_power.remains<=9&buff.arcane_charge.stack=buff.arcane_charge.max_stack&active_enemies<6-(1*set_bonus.tier28_2pc)
  if S.ArcaneBlast:IsCastable() and (S.TouchoftheMagi:CooldownRemains() <= 8 and S.RuneofPower:CooldownRemains() <= 9 and Player:ArcaneCharges() == Player:ArcaneChargesMax() and EnemiesCount8ySplash < 6 - (1 * num(Player:HasTier(28, 2)))) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast vaoe 15"; end
  end
  --arcane_missiles,if=active_enemies<9-(1*set_bonus.tier28_2pc)&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time,chain=1,early_chain_if=buff.clearcasting_channel.down&active_enemies<6
  if S.ArcaneMissiles:IsCastable() and (EnemiesCount8ySplash < 9 - (1 * num(Player:HasTier(28, 2))) and Target:DebuffUp(S.TouchoftheMagiDebuff) and Target:DebuffRemains(S.TouchoftheMagiDebuff) > S.ArcaneMissiles:ExecuteTime()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles vaoe 16"; end
  end
  --arcane_missiles,if=buff.clearcasting.react
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles vaoe 17"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack=0&cooldown.arcane_power.remains>15
  if S.ArcaneOrb:IsCastable() and (Player:ArcaneCharges() == 0 and S.ArcanePower:CooldownRemains() > 15) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb vaoe 18"; end
  end
  --arcane_barrage,if=time>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack&cooldown.touch_of_the_magi.remains&(buff.siphon_storm.remains<25|buff.siphon_storm.down&cooldown.touch_of_the_magi.remains>=11)
  if S.ArcaneBarrage:IsCastable() and (HL.CombatTime() > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.TouchoftheMagi:CooldownRemains() > 0 and (Player:BuffRemains(S.SiphonStormBuff) < 25 or Player:BuffDown(S.SiphonStormBuff) and S.TouchoftheMagi:CooldownRemains() >= 11)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage vaoe 19"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneExplosion:IsCastable() and (Player:ArcaneCharges() < Player:ArcaneChargesMax()) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion vaoe 20"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&prev_gcd.1.arcane_barrage
  if S.ArcaneExplosion:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:PrevGCD(1, S.ArcaneBarrage)) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion vaoe 21"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end
  end

  -- Check when the Disciplinary Command buff was last applied and its internal CD
  var_disciplinary_command_last_applied = S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()
  var_disciplinary_command_cd_remains = 30 - var_disciplinary_command_last_applied
  if var_disciplinary_command_cd_remains < 0 then var_disciplinary_command_cd_remains = 0 end

  -- Disciplinary Command Check
  Mage.DCCheck()

  -- Set which cast function to use for ArcaneExplosion
  CastAE = (Settings.Arcane.StayDistance and not Target:IsInRange(10)) and CastLeft or Cast

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- opener
    if not var_init then
      ArcaneOpener:StartOpener()
    end
    --counterspell
    --local ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    --use_mana_gem,if=(talent.enlightened&mana.pct<=80&mana.pct>=65)|(!talent.enlightened&mana.pct<=85)
    -- TODO: Fix hotkey issue, as item and spell use the same icon
    if I.ManaGem:IsReady() and Settings.Arcane.Enabled.ManaGem and ((S.Enlightened:IsAvailable() and Player:ManaPercentage() <= 80 and Player:ManaPercentage() >= 65) or ((not S.Enlightened:IsAvailable()) and Player:ManaPercentage() <= 85)) then
      if Cast(I.ManaGem, Settings.Arcane.OffGCDasOffGCD.ManaGem) then return "mana_gem main 1"; end
    end
    --potion,if=buff.arcane_power.up
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and Player:BuffUp(S.ArcanePower) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 3"; end
    end
    --time_warp,if=runeforge.temporal_warp&buff.exhaustion.up&(cooldown.arcane_power.ready|fight_remains<=40)
    if S.TimeWarp:IsReady() and Settings.Arcane.UseTemporalWarp and (TemporalWarpEquipped and Player:BloodlustExhaustUp()) and (S.ArcanePower:CooldownRemains() == 0 or FightRemains <= 40) then
      if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp combustion_cooldowns 6"; end
    end
    --lights_judgment,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
    if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagiDebuff) then
      if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment Shared_cd 4"; end
    end
    --bag_of_tricks,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
    if S.BagofTricks:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagiDebuff) then
      if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks Shared_cd 5"; end
    end
    --berserking,if=buff.arcane_power.up
    if S.Berserking:IsCastable() and Player:BuffUp(S.ArcanePower) then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking Shared_cd 6"; end
    end
    --blood_fury,if=buff.arcane_power.up
    if S.BloodFury:IsCastable() and Player:BuffUp(S.ArcanePower) then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury Shared_cd 7"; end
    end
    --fireblood,if=buff.arcane_power.up
    if S.Fireblood:IsCastable() and Player:BuffUp(S.ArcanePower) then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood Shared_cd 8"; end
    end
    --ancestral_call,if=buff.arcane_power.up
    if S.AncestralCall:IsCastable() and Player:BuffUp(S.ArcanePower) then
      if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call Shared_cd 9"; end
    end
    if Settings.Commons.Enabled.Trinkets then
      --use_items,if=buff.arcane_power.up
      if Player:BuffUp(S.ArcanePower) then
        local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
        if TrinketToUse then
          if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
        end
      end
      -- use_item,name=scars_of_fraternal_strife
      if I.ScarsofFraternalStrife:IsEquippedAndReady() then
        if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife Shared_cd 10"; end
      end
      --use_item,effect_name=gladiators_badge,if=buff.arcane_power.up|cooldown.arcane_power.remains>=55&debuff.touch_of_the_magi.up
      if I.SinfulGladiatorsBadge:IsEquippedAndReady() and (Player:BuffUp(S.ArcanePower) or (S.ArcanePower:CooldownRemains() >= 55 and Target:DebuffUp(S.TouchoftheMagiDebuff))) then
        if Cast(I.SinfulGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge Shared_cd 11"; end
      end
      --use_item,name=moonlit_prism,if=covenant.kyrian&cooldown.arcane_power.remains<=10&cooldown.touch_of_the_magi.remains<=10&(!equipped.the_first_sigil|trinket.the_first_sigil.cooldown.remains)
      if I.MoonlitPrism:IsEquippedAndReady() and (CovenantID == 1 and S.ArcanePower:CooldownRemains() <= 10 and S.TouchoftheMagi:CooldownRemains() <= 10 and ((not I.TheFirstSigil:IsEquipped()) or I.TheFirstSigil:CooldownRemains() > 0)) then
        if Cast(I.MoonlitPrism, nil, Settings.Commons.DisplayStyle.Trinkets) then return "moonlit_prism Shared_cd 12 kyrian"; end
      end
      --use_item,name=moonlit_prism,if=!covenant.kyrian&cooldown.arcane_power.remains<=6&cooldown.touch_of_the_magi.remains<=6&time>30&(!covenant.venthyr|active_enemies<variable.aoe_target_count)&(!equipped.the_first_sigil|trinket.the_first_sigil.cooldown.remains)
      if I.MoonlitPrism:IsEquippedAndReady() and (CovenantID ~= 1 and S.ArcanePower:CooldownRemains() <= 6 and S.TouchoftheMagi:CooldownRemains() <= 6 and HL.CombatTime() > 30 and (CovenantID ~= 2 or EnemiesCount8ySplash < var_aoe_target_count) and ((not I.TheFirstSigil:IsEquipped()) or I.TheFirstSigil:CooldownRemains() > 0)) then
        if Cast(I.MoonlitPrism, nil, Settings.Commons.DisplayStyle.Trinkets) then return "moonlit_prism Shared_cd 12 non-kyrian"; end
      end
      --use_item,name=empyreal_ordnance,if=cooldown.arcane_power.remains<=15&cooldown.touch_of_the_magi.remains<=15
      if I.EmpyrealOrdnance:IsEquippedAndReady() and S.ArcanePower:CooldownRemains() <= 15 and Target:DebuffRemains(S.TouchoftheMagi) <= 15 then
        if Cast(I.EmpyrealOrdnance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "empyreal_ordnance Shared_cd 13"; end
      end
      --use_item,name=dreadfire_vessel,if=cooldown.arcane_power.remains>=20|!variable.ap_on_use=1|(time=0&variable.fishing_opener=1&runeforge.siphon_storm)
      if I.DreadfireVessel:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() >= 20 or not var_ap_on_use or (CombatTime() == 0 and var_fishing_opener and SiphonStormEquipped)) then
        if Cast(I.DreadfireVessel, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "dreadfire_vessel Shared_cd 14"; end
      end
      --use_item,name=soul_igniter,if=cooldown.arcane_power.remains>=30|!variable.ap_on_use=1
      if I.SoulIgniter:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() >= 30 or not var_ap_on_use) and not Player:BuffUp(S.SoulIgnitionBuff) then
        if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soul_igniter Shared_cd 15"; end
      end
      --use_item,name=glyph_of_assimilation,if=cooldown.arcane_power.remains>=20|!variable.ap_on_use=1|(time=0&variable.fishing_opener=1&runeforge.siphon_storm)
      if I.GlyphofAssimilation:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() >= 20 or not var_ap_on_use or (CombatTime() == 0 and var_fishing_opener and SiphonStormEquipped)) then
        if Cast(I.GlyphofAssimilation, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "glyph_of_assimilation Shared_cd 16"; end
      end
      --use_item,name=macabre_sheet_music,if=cooldown.arcane_power.remains<=5&(!variable.fishing_opener=1|time>30)
      if I.MacabreSheetMusic:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() <= 5 and (not var_ap_on_use or CombatTime() > 30)) then
        if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music Shared_cd 17"; end
      end
      --use_item,name=macabre_sheet_music,if=cooldown.arcane_power.remains<=5&variable.fishing_opener=1&buff.rune_of_power.up&buff.rune_of_power.remains<=(10-5*runeforge.siphon_storm)&time<30
      if I.MacabreSheetMusic:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() <= 5 and var_ap_on_use and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) <= (10 - 5 * num(SiphonStormEquipped)) and CombatTime() < 30) then
        if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music Shared_cd 18"; end
      end
      --use_item,name=shadowed_orb_of_torment,if=time=0|(variable.outside_of_cooldowns&((covenant.kyrian&cooldown.radiant_spark.remains<=2&cooldown.arcane_power.remains<=5&cooldown.touch_of_the_magi.remains<=5)|cooldown.arcane_power.remains<=2|fight_remains<cooldown.arcane_power.remains))
      if I.ShadowedOrbofTorment:IsEquippedAndReady() and var_outside_of_cooldowns and ((CovenantID == 1 and S.RadiantSpark:CooldownRemains() <= 2 and S.ArcanePower:CooldownRemains() <= 5 and S.TouchoftheMagi:CooldownRemains() <= 5) or S.ArcanePower:CooldownRemains() <= 2 or FightRemains < S.ArcanePower:CooldownRemains()) then
        if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment Shared_cd 19"; end
      end
      --use_item,name=soulletting_ruby,if=(variable.time_until_ap+(action.radiant_spark.execute_time*covenant.kyrian)+(action.deathborne.execute_time*covenant.necrolord)+action.touch_of_the_magi.execute_time<target.distance%5.6)&(variable.have_opened|(covenant.kyrian&runeforge.arcane_infinity))&target.distance>25
      if I.SoullettingRuby:IsEquippedAndReady() and (var_time_until_ap + (num(CovenantID == 1) * S.RadiantSpark:ExecuteTime()) + (num(CovenantID == 4) * S.Deathborne:ExecuteTime()) + S.TouchoftheMagi:ExecuteTime() < Target:MaxDistance() / 5.6) and (ArcaneOpener:HasOpened() or (CovenantID == 1 and ArcaneInfinityEquipped)) and Target:MaxDistance() > 25 then
        if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby Shared_cd 20"; end
      end
    end
    --newfound_resolve,use_while_casting=1,if=buff.arcane_power.up|debuff.touch_of_the_magi.up|dot.radiant_spark.ticking
    -- Not really an action to do
    --call_action_list,name=calculations
    local ShouldReturn = Calculations(); if ShouldReturn then return ShouldReturn; end
    --call_action_list,name=vaoe,if=covenant.venthyr&runeforge.siphon_storm&talent.arcane_echo&active_enemies>=variable.aoe_target_count
    if AoEON() and (CovenantID == 2 and SiphonStormEquipped and S.ArcaneEcho:IsAvailable() and EnemiesCount8ySplash >= var_aoe_target_count) then
      local ShouldReturn = Vaoe(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=aoe,if=active_enemies>=variable.aoe_target_count&!(covenant.kyrian&runeforge.arcane_infinity)
    if AoEON() and EnemiesCount8ySplash >= var_aoe_target_count and (not (CovenantID == 1 and ArcaneInfinityEquipped)) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=harmony,if=covenant.kyrian&runeforge.arcane_infinity
    if CovenantID == 1 and ArcaneInfinityEquipped then
      local ShouldReturn = Harmony(); if ShouldReturn then return ShouldReturn; end
    else
      --call_action_list,name=fishing_opener,if=variable.have_opened=0&variable.fishing_opener&!(covenant.kyrian&runeforge.arcane_infinity)
      if (not ArcaneOpener:HasOpened()) and var_fishing_opener then
        local ShouldReturn = FishingOpener(); if ShouldReturn then return ShouldReturn; end
      end
      --call_action_list,name=opener,if=variable.have_opened=0&!(covenant.kyrian&runeforge.arcane_infinity)
      if (not ArcaneOpener:HasOpened()) and CDsON() then
        local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
      end
      --call_action_list,name=cooldowns,if=!(covenant.kyrian&runeforge.arcane_infinity)
      if CDsON() then
        local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
      end
      --call_action_list,name=rotation,if=variable.final_burn=0&!(covenant.kyrian&runeforge.arcane_infinity)
      if not ArcaneOpener:IsFinalBurn() then
        local ShouldReturn = Rotation(); if ShouldReturn then return ShouldReturn; end
      end
      --call_action_list,name=final_burn,if=variable.final_burn=1&!(covenant.kyrian&runeforge.arcane_infinity)
      if ArcaneOpener:IsFinalBurn() then
        local ShouldReturn = Final_burn(); if ShouldReturn then return ShouldReturn; end
      end
    end
  end
end

local function Init()
  -- APL Mar 13, 2022 https://github.com/simulationcraft/simc/tree/ca809d0d0fff7418a177506b3f7ef0c79ddf3413
  --HR.Print("Arcane Mage rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(62, APL, Init)

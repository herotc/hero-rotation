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
local CastSuggested   = HR.CastSuggested
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
  I.GlyphofAssimilation:ID(),
  I.MacabreSheetMusic:ID(),
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

-- Variables
local EnemiesCount8ySplash, EnemiesCount10ySplash, EnemiesCount16ySplash, EnemiesCount30ySplash --Enemies arround target
local EnemiesCount10yMelee --Enemies arround player
local SiphonStormEquipped = Player:HasLegendaryEquipped(16)
local GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
local TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
local ArcaneInfinityEquipped = Player:HasLegendaryEquipped(14)
local DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)

HL:RegisterForEvent(function()
  SiphonStormEquipped = Player:HasLegendaryEquipped(16)
  GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
  TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
  ArcaneInfinityEquipped = Player:HasLegendaryEquipped(14)
  DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
end, "PLAYER_EQUIPMENT_CHANGED")

local var_prepull_evo
local var_evo_pct
local var_am_spam
local var_KH_delaylimit_AP
local var_KH_prestacking_time
local var_KH_ORBforRS_delay
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
local var_totm_max_delay_for_rop
local var_barrage_mana_pct
local var_ap_minimum_mana_pct
local var_totm_max_charges
local var_aoe_totm_max_charges
local var_fishing_opener
local var_ap_on_use
local var_init = false
local var_disciplinary_command_cd_remains
local var_disciplinary_command_last_applied
local RadiantSparkVulnerabilityMaxStack = 4
local ClearCastingMaxStack = 3
local PresenceMaxStack = 3
local ArcaneHarmonyMaxStack = 18

Player.ArcaneOpener = {}
local ArcaneOpener = Player.ArcaneOpener

function ArcaneOpener:Reset()
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
  --variable,name=am_spam,op=reset,default=0
  var_am_spam = Settings.Arcane.AMSpamRotation

  --variable,name=evo_pct,op=reset,default=15
  var_evo_pct = 15

  --variable,name=prepull_evo,default=-1,op=set,if=variable.prepull_evo=-1,value=1*(runeforge.siphon_storm&active_enemies>1+1*!covenant.necrolord)
  -- TODO active_enemies at prepull
  --if SiphonStormEquipped then
  --  var_prepull_evo = true
  --else
  var_prepull_evo = false
  --end

  --variable,name=have_opened,op=set,value=0+1*(active_enemies>2|variable.prepull_evo=1|variable.am_spam=1)
  -- TODO active_enemies at prepull
  if var_prepull_evo or var_am_spam then
    ArcaneOpener:StopOpener()
  end

  --variable,name=final_burn,op=set,value=0
  --Managed elsewhere

  --variable,name=KH_delaylimit_AP,op=reset,default=15
  var_KH_delaylimit_AP = 15
  --variable,name=KH_prestacking_time,op=reset,default=9
  var_KH_prestacking_time = 9
  --variable,name=KH_ORBforRS_delay,op=reset,default=10
  var_KH_ORBforRS_delay = 10

  --variable,name=rs_max_delay_for_totm,op=reset,default=5
  var_rs_max_delay_for_totm = 5

  --variable,name=rs_max_delay_for_rop,op=reset,default=5
  var_rs_max_delay_for_rop = 5

  --variable,name=rs_max_delay_for_ap,op=reset,default=20
  var_rs_max_delay_for_ap = 20

  --variable,name=mot_preceed_totm_by,op=reset,default=3
  var_mot_preceed_totm_by = 3

  --variable,name=mot_max_delay_for_totm,op=reset,default=10
  var_mot_max_delay_for_totm = 10

  --variable,name=mot_max_delay_for_ap,op=reset,default=15
  var_mot_max_delay_for_ap = 15

  --variable,name=ap_max_delay_for_totm,op=reset,default=10
  var_ap_max_delay_for_totm = 10

  --variable,name=ap_max_delay_for_mot,op=reset,default=20
  var_ap_max_delay_for_mot = 20

  --variable,name=rop_max_delay_for_totm,default=-1,op=set,if=variable.rop_max_delay_for_totm=-1,value=20-(5*conduit.arcane_prodigy)
  var_rop_max_delay_for_totm = 20 - 5 * num(S.ArcaneProdigy:ConduitEnabled())

  --variable,name=totm_max_delay_for_ap,default=-1,op=set,if=variable.totm_max_delay_for_ap=-1,value=5+10*(covenant.night_fae|(conduit.arcane_prodigy&active_enemies<3))+15*(covenant.kyrian&runeforge.arcane_infinity&active_enemies>2)
  -- TODO active_enemies at prepull
  var_totm_max_delay_for_ap = 5 + 10 * num(Player:Covenant() == "Night Fae") + 15 * num(Player:Covenant() == "Kyrian" and ArcaneInfinityEquipped)

  --variable,name=totm_max_delay_for_rop,default=-1,op=set,if=variable.totm_max_delay_for_rop=-1,value=20-(8*conduit.arcane_prodigy)
  var_totm_max_delay_for_rop = 20 - 8 * num(S.ArcaneProdigy:ConduitEnabled())

  --variable,name=barrage_mana_pct,default=-1,op=set,if=variable.barrage_mana_pct=-1,value=((80-(20*covenant.night_fae)+(15*covenant.kyrian))-(mastery_value*100))
  var_barrage_mana_pct = 80 - (20 * num(Player:Covenant() == "Night Fae")) + (15 * num(Player:Covenant() == "Kyrian")) - Player:MasteryPct()

  --variable,name=ap_minimum_mana_pct,op=reset,default=15
  var_ap_minimum_mana_pct = 15

  --variable,name=totm_max_charges,op=reset,default=2
  var_totm_max_charges = 2

  --variable,name=aoe_totm_max_charges,op=reset,default=2
  var_aoe_totm_max_charges = 2

  --variable,name=fishing_opener,default=-1,op=set,if=variable.fishing_opener=-1,value=1*(equipped.empyreal_ordnance|(talent.rune_of_power&(talent.arcane_echo|!covenant.kyrian)&(!covenant.necrolord|active_enemies=1|runeforge.siphon_storm)))
  var_fishing_opener = Settings.Arcane.UseFishingOpener and bool(1 * (I.EmpyrealOrdnance:IsEquipped() or (S.RuneofPower:IsAvailable() and (S.ArcaneEcho:IsAvailable() or not Player:Covenant() == "Kyrian") and (not Player:Covenant() == "Necrolord" or SiphonStormEquipped))))

  --variable,name=ap_on_use,op=set,value=equipped.macabre_sheet_music|equipped.gladiators_badge|equipped.gladiators_medallion|equipped.darkmoon_deck_putrescence|equipped.inscrutable_quantum_device|equipped.soulletting_ruby|equipped.sunblood_amethyst|equipped.wakeners_frond|equipped.flame_of_battle
  var_ap_on_use = I.MacabreSheetMusic:IsEquipped() or I.SinfulGladiatorsBadge:IsEquipped() or I.DarkmoonDeckPutrescence:IsEquipped() or I.InscrutableQuantumDevice:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.SunbloodAmethyst:IsEquipped() or I.WakenersFrond:IsEquipped() or I.FlameofBattle:IsEquipped() 

  var_init = true
end

function ArcaneOpener:StartOpener()
  if Player:AffectingCombat() then
    self.state = true
    self.final_burn = false
    self.has_opened = false
    VarInit()
  end
end

function ArcaneOpener:StopOpener()
  self.state = false
  self.has_opened = true
end

function ArcaneOpener:On()
  return self.state or (not Player:AffectingCombat() and (Player:IsCasting(S.Frostbolt) or Player:IsCasting(S.ArcaneBlast) or Player:IsCasting(S.Evocation)))
end

function ArcaneOpener:HasOpened()
  return self.has_opened
end

function ArcaneOpener:StartFinalBurn()
  self.final_burn = true
end

function ArcaneOpener:IsFinalBurn()
  return self.final_burn
end

HL:RegisterForEvent(function()
  VarConserveMana = 0
  VarTotalBurns = 0
  VarAverageBurnLength = 0
  VarFontPrecombatChannel = 0
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
  --TODO : manage mana gem
  --mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 3"; end
  end
  --potion
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.UsePotions then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion precombat 4"; end
  end
  --frostbolt,if=!variable.prepull_evo=1&runeforge.disciplinary_command
  if not var_prepull_evo and S.Frostbolt:IsReady() and DisciplinaryCommandEquipped then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 5"; end
  end
  --fireblast,if=!variable.prepull_evo=1&runeforge.disciplinary_command
  if not var_prepull_evo and S.FireBlast:IsReady() and DisciplinaryCommandEquipped then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fireblast precombat 5.5"; end
  end
  --arcane_blast,if=!variable.prepull_evo=1&!runeforge.disciplinary_command
  if not var_prepull_evo and S.ArcaneBlast:IsReady() and not DisciplinaryCommandEquipped then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 6"; end
  end
  --evocation,if=variable.prepull_evo=1
  if var_prepull_evo and S.Evocation:IsReady() then
    if Cast(S.Evocation) then return "evocation precombat 7"; end
  end
end

local function SharedCds()
  --use_mana_gem,if=(talent.enlightened&mana.pct<=80&mana.pct>=65)|(!talent.enlightened&mana.pct<=85)
  -- TODO : manage mana gem
  --if I.ManaGem:IsReady() and ((S.Enlightened:IsAvailable() and Player:ManaPercentage() <= 80 and Player:ManaPercentage() >= 65) or (not S.Enlightened:IsAvailable() and Player:ManaPercentage() <= 85)) then
  --  if CastSuggested(I.ManaGem) then return "use_mana_gem Shared_cd 1"; end
  --end
  --potion,if=buff.arcane_power.up
  if I.PotionofSpectralIntellect:IsReady() and Player:BuffUp(S.ArcanePower) and Settings.Commons.Enabled.UsePotions then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion Shared_cd 2"; end
  end
  --time_warp,if=runeforge.temporal_warp&buff.exhaustion.up&(cooldown.arcane_power.ready|fight_remains<=40)
  if S.TimeWarp:IsCastable() and Settings.Arcane.UseTemporalWarp and TemporalWarpEquipped and Player:BloodlustExhaustUp() and Player:BloodlustDown() and (S.ArcanePower:CooldownRemains() == 0 or Target:TimeToDie() <= 40) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp Shared_cd 3"; end
  end
  --lights_judgment,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment Shared_cd 4"; end
  end
  --bag_of_tricks,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.BagofTricks:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
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
  --use_items,if=buff.arcane_power.up
  if Player:BuffUp(S.ArcanePower) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  --use_item,effect_name=gladiators_badge,if=buff.arcane_power.up|cooldown.arcane_power.remains>=55&debuff.touch_of_the_magi.up
  if I.SinfulGladiatorsBadge:IsEquippedAndReady() and (Player:BuffUp(S.ArcanePower) or (S.ArcanePower:CooldownRemains() >= 55 and Target:DebuffUp(S.TouchoftheMagi))) then
    if Cast(I.SinfulGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge Shared_cd 11"; end
  end
  --use_item,name=empyreal_ordnance,if=cooldown.arcane_power.remains<=(13+7*variable.ap_on_use)
  if I.EmpyrealOrdnance:IsEquippedAndReady() and S.ArcanePower:CooldownRemains() <= (13 + 7 * var_ap_on_use) then
    if Cast(I.EmpyrealOrdnance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "empyreal_ordnance Shared_cd 12"; end
  end
  --use_item,name=dreadfire_vessel,if=cooldown.arcane_power.remains>=20|!variable.ap_on_use=1|(time=0&variable.fishing_opener=1&runeforge.siphon_storm)
  if I.DreadfireVessel:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() >= 20 or not var_ap_on_use or (CombatTime() == 0 and var_fishing_opener and SiphonStormEquipped)) then
    if Cast(I.DreadfireVessel, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "dreadfire_vessel Shared_cd 13"; end
  end
  --use_item,name=soul_igniter,if=cooldown.arcane_power.remains>=30|!variable.ap_on_use=1
  if I.SoulIgniter:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() >= 30 or not var_ap_on_use) and not Player:BuffUp(S.SoulIgniterBuff) then
    if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soul_igniter Shared_cd 14"; end
  end
  --use_item,name=glyph_of_assimilation,if=cooldown.arcane_power.remains>=20|!variable.ap_on_use=1|(time=0&variable.fishing_opener=1&runeforge.siphon_storm)
  if I.GlyphofAssimilation:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() >= 20 or not var_ap_on_use or (CombatTime() == 0 and var_fishing_opener and SiphonStormEquipped)) then
    if Cast(I.GlyphofAssimilation, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "glyph_of_assimilation Shared_cd 15"; end
  end
  --use_item,name=macabre_sheet_music,if=cooldown.arcane_power.remains<=5&(!variable.fishing_opener=1|time>30)
  if I.MacabreSheetMusic:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() <= 5 and (not var_ap_on_use or CombatTime() > 30)) then
    if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music Shared_cd 16"; end
  end
  --use_item,name=macabre_sheet_music,if=cooldown.arcane_power.remains<=5&variable.fishing_opener=1&buff.rune_of_power.up&buff.rune_of_power.remains<=(10-5*runeforge.siphon_storm)&time<30
  if I.MacabreSheetMusic:IsEquippedAndReady() and (S.ArcanePower:CooldownRemains() <= 5 and var_ap_on_use and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) <= (10 - 5 * num(SiphonStormEquipped)) and CombatTime() < 30) then
    if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music Shared_cd 17"; end
  end
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
  --deathborne
  if S.Deathborne:IsCastable() then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne opener 3"; end
  end
  --radiant_spark,if=mana.pct>40
  if S.RadiantSpark:IsCastable() and Player:ManaPercentage() > 40 then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark opener 4"; end
  end
  --shifting_power,if=buff.arcane_power.down&cooldown.arcane_power.remains
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() > 0 then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power opener 5"; end
  end
  --mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment opener 6"; end
  end
  --touch_of_the_magi
  if S.TouchoftheMagi:IsCastable() then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi opener 7"; end
  end
  --arcane_power
  if S.ArcanePower:IsCastable() then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power opener 8"; end
  end
  --rune_of_power,if=buff.rune_of_power.down
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and not S.ArcanePower:IsCastable() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power opener 9"; end
  end
  --presence_of_mind,if=!talent.arcane_echo&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and S.ArcaneEcho:IsAvailable() and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind opener 10"; end
  end
  --presence_of_mind,if=buff.arcane_power.up&buff.rune_of_power.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind opener 11"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparkVulnerability) > 0) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 12"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<gcd&runeforge.arcane_infinity
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) < Player:GCD() and ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 13"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.arcane_power.down&buff.rune_of_power.remains<=gcd&runeforge.arcane_infinity
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCD() and ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 14"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo&(buff.deathborne.down|active_enemies=1)&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|(!talent.overpowered&(buff.rune_of_power.up|cooldown.evocation.ready)))
  --TODO : early chain
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and (Player:BuffDown(S.Deathborne) or EnemiesCount8ySplash == 1) and Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 15"; end
  end
  --arcane_missiles,if=buff.clearcasting.react,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 16"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb opener 17"; end
  end
  --arcane_blast,if=buff.rune_of_power.up|mana.pct>15
  if S.ArcaneBlast:IsCastable() and (Player:BuffUp(S.RuneofPowerBuff) or Player:ManaPercentage() > 15) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 18"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:ManaPercentage() < 85 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation opener 19"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 20"; end
  end
end

local function Cooldowns()
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0
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
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains=0
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
  and (Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi)) and S.TouchoftheMagi:CooldownRemains() == 0
  and (Player:ArcaneCharges() <= var_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt cooldowns 3"; end
  end
  --fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0 and Player:IsCasting(S.Frostbolt) then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast cooldowns 4"; end
  end
  --mirrors_of_torment,if=cooldown.touch_of_the_magi.remains<variable.mot_preceed_totm_by|(cooldown.arcane_power.remains>variable.mot_max_delay_for_ap&cooldown.touch_of_the_magi.remains>variable.mot_max_delay_for_totm)
  if S.MirrorsofTorment:IsCastable() and (S.TouchoftheMagi:CooldownRemains() < var_mot_preceed_totm_by or (S.ArcanePower:CooldownRemains() > var_mot_max_delay_for_ap and S.TouchoftheMagi:CooldownRemains() > var_mot_max_delay_for_totm)) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment cooldowns 5"; end
  end
  --mirrors_of_torment,if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened|(talent.enlightened&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.MirrorsofTorment:IsCastable() and S.ArcanePower:CooldownRemains() == 0
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70))
  and ((Player:BuffRemains(S.TouchoftheMagi) > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment cooldowns 6"; end
  end
  --deathborne,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd
  if S.Deathborne:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cooldowns 7"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened|(talent.enlightened&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70))
  and ((Player:BuffRemains(S.TouchoftheMagi) > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cooldowns 8"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains>variable.rs_max_delay_for_totm&cooldown.arcane_power.remains>variable.rs_max_delay_for_ap
  --&(talent.rune_of_power&(cooldown.rune_of_power.remains<execute_time|cooldown.rune_of_power.remains>variable.rs_max_delay_for_rop)|!talent.rune_of_power)
  --&buff.arcane_charge.stack>2&debuff.touch_of_the_magi.down&buff.rune_of_power.down&buff.arcane_power.down
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() > var_rs_max_delay_for_totm
  and ((S.RuneofPower:IsAvailable() and (S.RuneofPower:CooldownRemains() <= S.RadiantSpark:ExecuteTime() or S.RuneofPower:CooldownRemains() > var_rs_max_delay_for_rop)) or not S.RuneofPower:IsAvailable())
  and Player:ArcaneCharges() > 2 and Target:DebuffDown(S.TouchoftheMagi) and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldowns 9"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains<execute_time&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<(execute_time+action.touch_of_the_magi.execute_time)
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime() and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() < (S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime()) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldowns 10"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains<execute_time
  --&((!talent.enlightened|(talent.enlightened&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() < S.RadiantSpark:ExecuteTime()
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70))
  and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldowns 11"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=execute_time&mana.pct>variable.ap_minimum_mana_pct&buff.rune_of_power.down
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime() and Player:ManaPercentage() > var_ap_minimum_mana_pct and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 12"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&talent.rune_of_power&cooldown.rune_of_power.remains<=execute_time&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap&cooldown.arcane_power.remains>12
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap and S.ArcanePower:CooldownRemains() > S.RuneofPower:BaseDuration() then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 13"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&(!talent.rune_of_power|cooldown.rune_of_power.remains>variable.totm_max_delay_for_rop)&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and (not S.RuneofPower:IsAvailable() or S.RuneofPower:CooldownRemains() > var_totm_max_delay_for_rop) and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldowns 14"; end
  end
  --arcane_power,if=cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&(!covenant.venthyr|cooldown.mirrors_of_torment.remains>variable.ap_max_delay_for_mot)
  --&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.ArcanePower:IsCastable() and S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and (not Player:Covenant() ~= "Venthyr" or S.MirrorsofTorment:CooldownRemains() > var_ap_max_delay_for_mot)
  and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power cooldowns 15"; end
  end
  --rune_of_power,if=buff.arcane_power.down
  --&(cooldown.touch_of_the_magi.remains>variable.rop_max_delay_for_totm|cooldown.arcane_power.remains<=variable.totm_max_delay_for_ap)
  --&buff.arcane_charge.stack=buff.arcane_charge.max_stack&cooldown.arcane_power.remains>12
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) 
  and (S.TouchoftheMagi:CooldownRemains() > var_rop_max_delay_for_totm or S.ArcanePower:CooldownRemains() <= var_totm_max_delay_for_ap) 
  and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcanePower:CooldownRemains() > S.RuneofPower:BaseDuration() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power cooldowns 16"; end
  end
  --shifting_power,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power cooldowns 17"; end
  end
  --presence_of_mind,if=talent.rune_of_power&buff.arcane_power.up&buff.rune_of_power.remains<gcd.max
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and S.RuneofPower:IsAvailable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) < Player:GCD() then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cooldowns 18"; end
  end
  --presence_of_mind,if=debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<action.arcane_missiles.execute_time&!covenant.kyrian
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and Player:Covenant() ~= "Kyrian" and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) < S.ArcaneMissiles:ExecuteTime() then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cooldowns 19"; end
  end
  --presence_of_mind,if=buff.rune_of_power.up&buff.rune_of_power.remains<gcd.max&cooldown.evocation.ready&cooldown.touch_of_the_magi.remains&!covenant.kyrian
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and Player:Covenant() ~= "Kyrian" and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) < Player:GCD() and S.Evocation:CooldownRemains() == 0 and S.TouchoftheMagi:CooldownRemains() > 0 then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cooldowns 20"; end
  end
end

local function Rotation()
  --cancel_action,if=action.evocation.channeling&mana.pct>=95&(!runeforge.siphon_storm|buff.siphon_storm.stack=buff.siphon_storm.max_stack)
  --NYI cancel action
  --evocation,if=mana.pct<=variable.evo_pct
  --&(cooldown.touch_of_the_magi.remains<=action.evocation.execute_time|cooldown.arcane_power.remains<=action.evocation.execute_time|(talent.rune_of_power&cooldown.rune_of_power.remains<=action.evocation.execute_time))
  --&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down&!prev_gcd.1.touch_of_the_magi
  if S.Evocation:IsCastable() and Player:ManaPercentage() < var_evo_pct 
  and (S.TouchoftheMagi:CooldownRemains() <= S.Evocation:ExecuteTime() or S.ArcanePower:CooldownRemains() <= S.Evocation:ExecuteTime() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.Evocation:ExecuteTime())) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) and not Player:IsCasting(S.TouchoftheMagi) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Rotation 2"; end
  end
  --evocation,if=runeforge.siphon_storm&cooldown.arcane_power.remains<=action.evocation.execute_time
  if S.Evocation:IsCastable() and SiphonStormEquipped and S.ArcanePower:CooldownRemains() <= S.Evocation:ExecuteTime() then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Rotation 3"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.ready&(buff.arcane_charge.stack>variable.totm_max_charges&cooldown.arcane_power.remains<=execute_time&mana.pct>variable.ap_minimum_mana_pct&buff.rune_of_power.down)
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.ArcanePower:CooldownRemains() > S.ArcaneBarrage:ExecuteTime() and Player:ManaPercentage() > var_ap_minimum_mana_pct and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 4"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.ready&(buff.arcane_charge.stack>variable.totm_max_charges&talent.rune_of_power&cooldown.rune_of_power.remains<=execute_time&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.ArcaneBarrage:ExecuteTime() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 5"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.ready&(buff.arcane_charge.stack>variable.totm_max_charges&(!talent.rune_of_power|cooldown.rune_of_power.remains>variable.totm_max_delay_for_rop)&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_rop) and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 6"; end
  end
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=debuff.radiant_spark_vulnerability.max_stack&(buff.arcane_power.down|buff.arcane_power.remains<=gcd)&(buff.rune_of_power.down|buff.rune_of_power.remains<=gcd)
  if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == RadiantSparkVulnerabilityMaxStack and (Player:BuffDown(S.ArcanePower) or Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains()) and (Player:BuffDown(S.RuneofPowerBuff) or Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 7"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>8|(debuff.radiant_spark_vulnerability.stack>0&debuff.radiant_spark_vulnerability.stack<debuff.radiant_spark_vulnerability.max_stack)
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 8 or (Target:DebuffStack(S.RadiantSparkVulnerability) > 0 and Target:DebuffStack(S.RadiantSparkVulnerability) < RadiantSparkVulnerabilityMaxStack)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 8"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=action.arcane_blast.execute_time
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) < (S.ArcaneBlast:ExecuteTime() + Player:GCDRemains()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 9"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo&(buff.deathborne.down|active_enemies=1)&(debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time|cooldown.presence_of_mind.remains|covenant.kyrian),chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|(!talent.overpowered&(buff.rune_of_power.up|cooldown.evocation.ready)))
  --TODO early_chain
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and (Player:BuffDown(S.Deathborne) or EnemiesCount8ySplash == 1) and (Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() or S.PresenceofMind:CooldownRemains() > 0 or Player:Covenant() == "Kyrian") then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 10"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.expanded_potential.up
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ExpandedPotentialBuff) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 11"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&(buff.arcane_power.up|buff.rune_of_power.up|debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and (Player:BuffUp(S.ArcanePower) or Player:BuffUp(S.RuneofPowerBuff) or Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 12"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 13"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.remains<=((buff.clearcasting.stack*action.arcane_missiles.execute_time)+gcd),chain=1
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and Player:BuffDown(S.Deathborne) and (Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() or S.PresenceofMind:CooldownRemains() > 0 or Player:Covenant() == "Kyrian") then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 14"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 15"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb rotation 16"; end
  end
  --supernova,if=mana.pct<=95&buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.Supernova:IsCastable() and Player:ManaPercentage() <= 95 and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova rotation 17"; end
  end
  --arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.RuleofThreesBuff) and Player:ArcaneCharges() > 3 then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 18"; end
  end
  --arcane_barrage,if=mana.pct<=variable.barrage_mana_pct&buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&cooldown.evocation.remains
  if S.ArcaneBarrage:IsCastable() and Player:ManaPercentage() < var_barrage_mana_pct and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.Evocation:CooldownRemains() > 0 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 19"; end
  end
  --arcane_barrage,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.arcane_orb&cooldown.arcane_orb.remains<=gcd&mana.pct<=90&cooldown.evocation.remains
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() <= Player:GCDRemains() and Player:ManaPercentage() <= 90 and S.Evocation:CooldownRemains() > 0 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 20"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(cooldown.evocation.remains|runeforge.arcane_infinity)
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (S.Evocation:CooldownRemains() > 0 or ArcaneInfinityEquipped) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 21"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.arcane_power.down&buff.rune_of_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(cooldown.evocation.remains|runeforge.arcane_infinity)
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (S.Evocation:CooldownRemains() > 0 or ArcaneInfinityEquipped) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 22"; end
  end
  --arcane_barrage,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 23"; end
  end
  --arcane_barrage,if=target.health.pct<35&buff.arcane_charge.stack>=(active_enemies-1)&runeforge.arcane_bombardment&active_enemies>1&buff.deathborne.down
  if S.ArcaneBarrage:IsCastable()and Target:HealthPercentage() < 35 and Player:ArcaneCharges() >= (EnemiesCount10ySplash - 1) and ArcaneBombardmentEquipped and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Deathborne) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 24"; end
  end  
  --arcane_explosion,if=target.health.pct<35&buff.arcane_charge.stack<buff.arcane_charge.max_stack&runeforge.arcane_bombardment&active_enemies>1&buff.deathborne.down
  if S.ArcaneExplosion:IsCastable() and Target:HealthPercentage() < 35 and Player:ArcaneCharges() < Player:ArcaneChargesMax() and ArcaneBombardmentEquipped and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Deathborne) then
    if Settings.Arcane.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion rotation 25 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion rotation 25"; end
    end
  end 
  --arcane_blast
  if S.ArcaneBlast:IsCastable() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 26"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation rotation 27"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 28"; end
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
  --evocation,if=(runeforge.siphon_storm|runeforge.temporal_warp)&(buff.rune_of_power.down|prev_gcd.1.arcane_barrage)&cooldown.rune_of_power.remains
  if S.Evocation:IsCastable() and (SiphonStormEquipped or TemporalWarpEquipped) and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) and S.RuneofPower:CooldownRemains() >= 0 then
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
  --deathborne,if=!runeforge.siphon_storm&!runeforge.temporal_warp
  if S.Deathborne:IsCastable() and not SiphonStormEquipped and not TemporalWarpEquipped then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne fishing_opener 5"; end
  end
  --arcane_orb,if=cooldown.rune_of_power.ready
  if S.ArcaneOrb:IsCastable() and S.RuneofPower:CooldownRemains() == 0 then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb fishing_opener 6"; end
  end
  --arcane_blast,if=cooldown.rune_of_power.ready&buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneBlast:IsCastable() and S.RuneofPower:CooldownRemains() == 0 and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 7"; end
  end
  --rune_of_power
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and not S.ArcanePower:IsCastable() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power fishing_opener 8"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack&covenant.venthyr&cooldown.mirrors_of_torment.ready
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) and ClearCastingMaxStack and Player:Covenant() ~= "Venthyr" and S.MirrorsofTorment:CooldownRemains() == 0 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 9"; end
  end
  --potion,if=!(runeforge.siphon_storm|runeforge.temporal_warp)
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.UsePotions and not SiphonStormEquipped and not TemporalWarpEquipped then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion fishing_opener 10"; end
  end
  --deathborne,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage
  if S.Deathborne:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne fishing_opener 11"; end
  end
  --radiant_spark,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage
  if S.RadiantSpark:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark fishing_opener 12"; end
  end
  --mirrors_of_torment,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage
  if S.MirrorsofTorment:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage)) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment fishing_opener 13"; end
  end
  --touch_of_the_magi,if=buff.rune_of_power.down|prev_gcd.1.arcane_barrage|prev_gcd.1.mirrors_of_torment|prev_gcd.1.radiant_spark|prev_gcd.1.deathborne
  if S.TouchoftheMagi:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or Player:PrevGCD(1,S.ArcaneBarrage) or Player:IsCasting(S.MirrorsofTorment) or Player:IsCasting(S.RadiantSpark) or Player:IsCasting(S.Deathborne)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi fishing_opener 14"; end
  end
  --arcane_power,if=prev_gcd.1.touch_of_the_magi
  if S.ArcanePower:IsCastable() and Player:IsCasting(S.TouchoftheMagi) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power fishing_opener 15"; end
  end
  --presence_of_mind,if=!talent.arcane_echo&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and S.ArcaneEcho:IsAvailable() and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind fishing_opener 16"; end
  end
  --presence_of_mind,if=buff.arcane_power.up&buff.rune_of_power.remains<=(action.arcane_blast.execute_time*buff.presence_of_mind.max_stack)
  if S.PresenceofMind:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= (S.ArcaneBlast:ExecuteTime() * PresenceMaxStack) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind fishing_opener 17"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparkVulnerability) > 0) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 18"; end
  end
  --arcane_barrage,if=cooldown.arcane_power.ready&mana.pct<(40+(10*covenant.kyrian))&buff.arcane_charge.stack=buff.arcane_charge.max_stack&!runeforge.siphon_storm&!runeforge.temporal_warp
  if S.ArcaneBarrage:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and Player:ManaPercentage() < ( 40 + (10 * num(Player:Covenant() ~= "Kyrian"))) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and not SiphonStormEquipped and not TemporalWarpEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 19"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&(runeforge.arcane_infinity|cooldown.evocation.remains)
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCD() and (ArcaneInfinityEquipped or S.Evocation:CooldownRemains() > 0) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 20"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.arcane_power.down&buff.rune_of_power.remains<=gcd
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCD() and ArcaneInfinityEquipped then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 21"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo&(buff.deathborne.down|active_enemies=1)&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|(!talent.overpowered&(buff.rune_of_power.up|cooldown.evocation.ready)))
  --TODO : early chain
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and (Player:BuffDown(S.Deathborne) or EnemiesCount8ySplash == 1) and Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 22"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&cooldown.arcane_power.remains&(buff.rune_of_power.up|buff.arcane_power.up),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and S.ArcanePower:CooldownRemains() > 0 and (Player:BuffUp(S.RuneofPowerBuff or Player:BuffUp(S.ArcanePower))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 23"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb fishing_opener 24"; end
  end
  --arcane_blast,if=buff.rune_of_power.up|mana.pct>15
  if S.ArcaneBlast:IsCastable() and (Player:BuffUp(S.RuneofPowerBuff) or Player:ManaPercentage() > 15) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 25"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Player:ManaPercentage() < 85 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation fishing_opener 26"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage fishing_opener 27"; end
  end
end

local function Harmony()
  --cancel_action,if=action.evocation.channeling&mana.pct>=95
  --NYI cancel action
  --evocation,if=mana.pct<=15
  --&cooldown.touch_of_the_magi.remains<=(execute_time+action.touch_of_the_magi.execute_time)&cooldown.arcane_power.remains<=(execute_time+action.touch_of_the_magi.execute_time+action.arcane_power.execute_time)
  --&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down&!dot.radiant_spark.remains
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 15 
  and S.TouchoftheMagi:CooldownRemains() <= (S.Evocation:ExecuteTime() + S.TouchoftheMagi:ExecuteTime()) and S.ArcanePower:CooldownRemains() <= (S.Evocation:ExecuteTime() + S.TouchoftheMagi:ExecuteTime()) and S.ArcanePower:CooldownRemains() <= (S.Evocation:ExecuteTime() + S.TouchoftheMagi:ExecuteTime() + S.ArcanePower:ExecuteTime())
  and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) and Target:DebuffRemains(S.RadiantSpark) == 0 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation harmony 2"; end
  end
  --evocation,if=mana.pct<=30
  --&cooldown.rune_of_power.remains<=(execute_time+action.rune_of_power.execute_time)&cooldown.touch_of_the_magi.remains<=(execute_time+action.rune_of_power.execute_time+action.radiant_spark.execute_time)
  --&cooldown.arcane_power.remains>40
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 30 
  and S.RuneofPower:CooldownRemains() <= (S.Evocation:ExecuteTime() + S.RuneofPower:ExecuteTime()) and S.TouchoftheMagi:CooldownRemains() <= (S.Evocation:ExecuteTime() + S.RuneofPower:ExecuteTime() + S.RadiantSpark:ExecuteTime())
  and S.ArcanePower:CooldownRemains() > 40 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation harmony 3"; end
  end
  --arcane_blast,if=cooldown.radiant_spark.remains<=2*gcd+variable.KH_prestacking_time+execute_time&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time
  --&cooldown.arcane_power.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time+action.touch_of_the_magi.execute_time
  --&buff.arcane_charge.stack>1&buff.arcane_charge.stack<4&!conduit.arcane_prodigy
  if S.ArcaneBlast:IsCastable() and S.RadiantSpark:CooldownRemains() <= 2 * Player:GCD() + var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() + S.RadiantSpark:ExecuteTime() 
  and S.ArcanePower:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() + S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime()
  and Player:ArcaneCharges() > 1 and Player:ArcaneCharges() < 4 and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 4"; end
  end
  --arcane_blast,if=cooldown.rune_of_power.remains<=2*gcd+variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time&cooldown.radiant_spark.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time
  --&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time+action.radiant_spark.execute_time&cooldown.arcane_power.remains
  --&buff.arcane_charge.stack>1&buff.arcane_charge.stack<4&!conduit.arcane_prodigy
  if S.ArcaneBlast:IsCastable() and S.RuneofPower:CooldownRemains() <= 2 * Player:GCD() + var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() + S.RuneofPower:ExecuteTime() and S.RadiantSpark:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() + S.RuneofPower:ExecuteTime() 
  and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() + S.RuneofPower:ExecuteTime() + S.RadiantSpark:ExecuteTime() and S.ArcanePower:CooldownRemains() > 0
  and Player:ArcaneCharges() > 1 and Player:ArcaneCharges() < 4 and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 5"; end
  end
  --arcane_blast,if=cooldown.radiant_spark.remains<=2*gcd+variable.KH_prestacking_time&cooldown.arcane_power.remains>=30
  --&cooldown.touch_of_the_magi.remains+30<=cooldown.arcane_power.remains&cooldown.rune_of_power.remains+30<=cooldown.arcane_power.remains
  --&buff.arcane_charge.stack>1&buff.arcane_charge.stack<4&!conduit.arcane_prodigy
  if S.ArcaneBlast:IsCastable() and S.RadiantSpark:CooldownRemains() <= 2 * Player:GCD() + var_KH_prestacking_time + S.ArcaneBlast:ExecuteTime() and S.ArcanePower:CooldownRemains() >= 30 
  and S.TouchoftheMagi:CooldownRemains() + 30 <= S.ArcanePower:CooldownRemains() and S.RuneofPower:CooldownRemains() + 30 <= S.ArcanePower:CooldownRemains()
  and Player:ArcaneCharges() > 1 and Player:ArcaneCharges() < 4 and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 6"; end
  end
  --arcane_barrage,if=cooldown.radiant_spark.remains<=gcd+variable.KH_prestacking_time+execute_time&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time
  --&cooldown.arcane_power.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time+action.touch_of_the_magi.execute_time
  --&buff.arcane_charge.stack>1
  if S.ArcaneBarrage:IsCastable() and S.RadiantSpark:CooldownRemains() <= Player:GCD() + var_KH_prestacking_time + S.ArcaneBarrage:ExecuteTime() and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBarrage:ExecuteTime() + S.RadiantSpark:ExecuteTime()
  and S.ArcanePower:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBarrage:ExecuteTime() + S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime()
  and Player:ArcaneCharges() > 1 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 7"; end
  end
  --arcane_barrage,if=cooldown.rune_of_power.remains<=gcd+variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time&cooldown.radiant_spark.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time
  --&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time+action.radiant_spark.execute_time&cooldown.arcane_power.remains
  --&buff.arcane_charge.stack>1
  if S.ArcaneBarrage:IsCastable() and S.RuneOfPower:CooldownRemains() <= Player:GCD() + var_KH_prestacking_time + S.ArcaneBarrage:ExecuteTime() and S.RadiantSpark:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBarrage:ExecuteTime() + S.RuneofPower:ExecuteTime()
  and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneBarrage:ExecuteTime() + S.RuneOfPower:ExecuteTime() + S.RadiantSpark:ExecuteTime() and S.ArcanePower:CooldownRemains() > 0
  and Player:ArcaneCharges() > 1 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 8"; end
  end
  --arcane_barrage,if=cooldown.radiant_spark.remains<=gcd+variable.KH_prestacking_time&cooldown.arcane_power.remains>=30
  --&cooldown.touch_of_the_magi.remains+30<=cooldown.arcane_power.remains&cooldown.rune_of_power.remains+30<=cooldown.arcane_power.remains
  --&buff.arcane_charge.stack>1&!conduit.arcane_prodigy
  if S.ArcaneBarrage:IsCastable() and S.RadiantSpark:CooldownRemains() <= Player:GCD() + var_KH_prestacking_time and S.ArcanePower:CooldownRemains() >= 30
  and S.TouchoftheMagi:CooldownRemains() + 30 <= S.ArcanePower:CooldownRemains() and S.RuneofPower:CooldownRemains() + 30 <= S.ArcanePower:CooldownRemains()
  and Player:ArcaneCharges() > 1 and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 9"; end
  end
  --arcane_missiles,if=buff.arcane_harmony.stack<buff.arcane_harmony.max_stack&cooldown.radiant_spark.remains<=variable.KH_prestacking_time+execute_time
  --&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time
  --&cooldown.arcane_power.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time+action.touch_of_the_magi.execute_time,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) < ArcaneHarmonyMaxStack and S.RadiantSpark:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() 
  and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RadiantSpark:ExecuteTime() 
  and S.ArcanePower:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 10"; end
  end
  --arcane_missiles,if=buff.arcane_harmony.stack<buff.arcane_harmony.max_stack&cooldown.rune_of_power.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time
  --&cooldown.radiant_spark.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time
  --&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.rune_of_power.execute_time+action.radiant_spark.execute_time&cooldown.arcane_power.remains,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) < ArcaneHarmonyMaxStack and S.RuneOfPower:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RuneOfPower:ExecuteTime()
  and S.RadiantSpark:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RuneOfPower:ExecuteTime() 
  and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RuneofPower:ExecuteTime() + S.RadiantSpark:ExecuteTime() and S.ArcanePower:CooldownRemains() > 0 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 11"; end
  end
  --arcane_missiles,if=buff.arcane_harmony.stack<buff.arcane_harmony.max_stack&cooldown.radiant_spark.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time
  --&cooldown.arcane_power.remains>=30&cooldown.rune_of_power.remains>=30&!conduit.arcane_prodigy,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) < ArcaneHarmonyMaxStack and S.RadiantSpark:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RadiantSpark:ExecuteTime()
  and S.ArcanePower:CooldownRemains() >= 30 and S.RuneOfPower:CooldownRemains() >= 30 and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 12"; end
  end
  --radiant_spark,if=buff.arcane_charge.stack<2&buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&cooldown.touch_of_the_magi.remains<execute_time
  --&cooldown.arcane_power.remains<=(execute_time+action.touch_of_the_magi.execute_time)&mana.pct>15
  if S.RadiantSpark:IsCastable() and Player:ArcaneCharges() < 2 and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime()
  and S.ArcanePower:CooldownRemains() <= S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime() and Player:ManaPercentage() > 15 then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark harmony 13"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<2&buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&cooldown.arcane_power.remains<=execute_time&dot.radiant_spark.remains
  if S.TouchoftheMagi:IsCastable() and Player:ArcaneCharges() < 2 and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and S.ArcanePower:CooldownRemains() <= S.TouchoftheMagi:ExecuteTime() and Target:DebuffRemains(S.RadiantSpark) > 0 then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi harmony 14"; end
  end
  --arcane_power,if=buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&debuff.touch_of_the_magi.up&buff.rune_of_power.down
  if S.ArcanePower:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and Target:DebuffUp(S.TouchoftheMagi) and Player:DebuffDown(S.RuneOfPower) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power harmony 15"; end
  end
  --rune_of_power,if=buff.arcane_charge.stack<2&buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&cooldown.radiant_spark.remains<=execute_time
  --&cooldown.touch_of_the_magi.remains<=(execute_time+action.radiant_spark.execute_time)&cooldown.arcane_power.remains>45+variable.KH_delaylimit_AP&mana.pct>=35
  if S.RuneofPower:IsCastable() and Player:ArcaneCharges() < 2 and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and S.RadiantSpark:CooldownRemains() <= S.RuneOfPower:ExecuteTime() 
  and S.TouchoftheMagi:CooldownRemains() <= S.RuneofPower:ExecuteTime() + S.RadiantSpark:ExecuteTime() and S.ArcanePower:CooldownRemains() > 45 + var_KH_delaylimit_AP and Player:ManaPercentage() >= 35 then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power harmony 16"; end
  end
  --radiant_spark,if=buff.arcane_charge.stack<2&buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&cooldown.touch_of_the_magi.remains<execute_time&buff.rune_of_power.up
  if S.RadiantSpark:IsCastable() and Player:ArcaneCharges() < 2 and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime() and Player:BuffUp(S.RuneofPowerBuff) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark harmony 17"; end
  end
  --touch_of_the_magi,if=buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&buff.rune_of_power.up&dot.radiant_spark.remains
  if S.TouchoftheMagi:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and Player:BuffUp(S.RuneofPowerBuff) and Target:DebuffRemains(S.RadiantSpark) > 0 then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi harmony 18"; end
  end
  --rune_of_power,if=(cooldown.touch_of_the_magi.remains+45)<=cooldown.arcane_power.remains&buff.arcane_power.down&!conduit.arcane_prodigy
  if S.RuneofPower:IsCastable() and (S.TouchoftheMagi:CooldownRemains() + 45) <= S.ArcanePower:CooldownRemains() and Player:BuffDown(S.ArcanePower) and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power harmony 19"; end
  end
  --radiant_spark,if=buff.arcane_harmony.stack=buff.arcane_harmony.max_stack&cooldown.arcane_power.remains>=30&cooldown.touch_of_the_magi.remains+30<=cooldown.arcane_power.remains
  --&cooldown.rune_of_power.remains+30<=cooldown.arcane_power.remains&mana.pct>=15&!conduit.arcane_prodigy
  if S.RadiantSpark:IsCastable() and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack and S.ArcanePower:CooldownRemains() >= 30 and S.TouchoftheMagi:CooldownRemains() + 30 <= S.ArcanePower:CooldownRemains()
  and S.RuneofPower:CooldownRemains() + 30 <= S.ArcanePower:CooldownRemains() and Player:ManaPercentage() >= 15 and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark harmony 20"; end
  end
  --arcane_orb,if=dot.radiant_spark.remains>5&debuff.radiant_spark_vulnerability.stack=0&buff.rune_of_power.down
  if S.ArcaneOrb:IsCastable() and Target:DebuffRemains(S.RadiantSpark) > 5 and Target:DebuffStack(S.RadiantSparkVulnerability) == 0 and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 21"; end
  end
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=4
  if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == 4 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 22"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains&debuff.touch_of_the_magi.remains>execute_time&(debuff.radiant_spark_vulnerability.stack=0|debuff.radiant_spark_vulnerability.stack<4)&!prev_gcd.1.arcane_barrage
  if S.ArcaneBlast:IsCastable() and Target:DebuffRemains(S.RadiantSpark) > 0 and Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneBlast:ExecuteTime() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 0 or Target:DebuffStack(S.RadiantSparkVulnerability) < 4) and not Player:PrevGCD(1,S.ArcaneBarrage) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 23"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>execute_time&debuff.radiant_spark_vulnerability.stack>0&debuff.radiant_spark_vulnerability.stack<4&buff.rune_of_power.down
  if S.ArcaneBlast:IsCastable() and Target:DebuffRemains(S.RadiantSpark) > S.ArcaneBlast:ExecuteTime() and Target:DebuffStack(S.RadiantSparkVulnerability) > 0 and Target:DebuffStack(S.RadiantSparkVulnerability) < 4 and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 24"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<2&buff.arcane_power.up
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < 2 and Player:BuffUp(S.ArcanePower) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 25"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.arcane_power.up,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ArcanePower) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 26"; end
  end
  --presence_of_mind,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&buff.arcane_charge.stack>0&buff.arcane_power.remains
  --|buff.arcane_charge.stack<buff.arcane_charge.max_stack&buff.arcane_charge.stack>0&buff.rune_of_power.remains&debuff.touch_of_the_magi.remains
  if S.PresenceofMind:IsCastable() and ((Player:ArcaneCharges() < Player:ArcaneChargesMax() and Player:ArcaneCharges() > 0 and Player:BuffRemains(S.ArcanePower)) or (Player:ArcaneCharges() < Player:ArcaneChargesMax() and Player:ArcaneCharges() > 0 and Player:BuffRemains(S.RuneofPowerBuff) and Target:DebuffRemains(S.TouchoftheMagi) > 0)) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind harmony 27"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&buff.arcane_charge.stack>1
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Player:ArcaneCharges() > 1 then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast harmony 28"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<2&cooldown.arcane_power.remains>=20-8*gcd&!(cooldown.radiant_spark.remains<=10&cooldown.arcane_power.remains>=75)
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < 2 and S.ArcanePower:CooldownRemains() >= 20 - 8 * Player:GCD() and not (S.RadiantSpark:CooldownRemains() <= 10 and S.ArcanePower:CooldownRemains() >= 75) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 29"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<2&cooldown.arcane_power.remains>=20-8*gcd&conduit.arcane_prodigy
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < 2 and S.ArcanePower:CooldownRemains() >= 20 - 8 * Player:GCD() and not S.ArcaneProdigy:ConduitEnabled() then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb harmony 30"; end
  end
  --arcane_missiles,if=buff.arcane_charge.stack>1&buff.arcane_harmony.stack<buff.arcane_harmony.max_stack,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:ArcaneCharges() > 1 and Player:BuffStack(S.ArcaneHarmonyBuff) < ArcaneHarmonyMaxStack then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 31"; end
  end
  --arcane_missiles,if=cooldown.arcane_orb.remains<4&buff.arcane_harmony.stack<buff.arcane_harmony.max_stack,chain=1
  if S.ArcaneMissiles:IsCastable() and S.ArcaneOrb:CooldownRemains() <4 and Player:BuffStack(S.ArcaneHarmonyBuff) < ArcaneHarmonyMaxStack then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles harmony 32"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_harmony.stack=buff.arcane_harmony.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffStack(S.ArcaneHarmonyBuff) == ArcaneHarmonyMaxStack then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage harmony 33"; end
  end
  --evocation,if=mana.pct<15
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 15 then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation fishing_opener 34"; end
  end
  --arcane_blast,if=buff.arcane_charge.stack>1
  if S.ArcaneBlast:IsCastable() and Player:ArcaneCharges() > 1 then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast fishing_opener 35"; end
  end
  --arcane_missiles,chain=1
  if S.ArcaneMissiles:IsCastable() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles fishing_opener 36"; end
  end
end

local function Aoe()
  --frostbolt,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down
  --&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges
  --&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd))
  if S.Frostbolt:IsReady() and not Player:IsCasting(S.Frostbolt) and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Frost == 0 
  and (Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi)) and S.TouchoftheMagi:CooldownRemains() == 0 and (Player:ArcaneCharges() <= var_totm_max_charges 
  and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt Aoe 1"; end
  end
  --fire_blast,if=(runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt)|(runeforge.disciplinary_command&time=0)
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0 and Player:IsCasting(S.Frostbolt) then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast Aoe 2"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0
  --&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges
  --&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  --|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  --|cooldown.arcane_power.remains<=gcd))
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and Player:BuffDown(S.ArcanePower) and S.ArcanePower:CooldownRemains() > 30 and S.TouchoftheMagi:CooldownRemains() == 0
  and (Player:ArcaneCharges() <= var_totm_max_charges 
  and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap)
  or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap)
  or (S.ArcanePower:CooldownRemains() <= Player:GCD()))) then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova Aoe 3"; end
  end
  --frost_nova,if=runeforge.grisly_icicle&cooldown.arcane_power.remains=0
  --&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)
  --|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))
  --&buff.rune_of_power.down)
  if S.FrostNova:IsCastable() and GrislyIcicleEquipped and S.ArcanePower:CooldownRemains() == 0
  and (((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) 
  or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= Player:ArcaneChargesMax()))
  and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.FrostNova, nil, nil, not Target:IsSpellInRange(S.FrostNova)) then return "frost_nova Aoe 4"; end
  end
  --arcane_missiles,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_harmony.stack<15&cooldown.radiant_spark.remains<=variable.KH_prestacking_time+execute_time
  --&cooldown.touch_of_the_magi.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time
  --&cooldown.arcane_power.remains<=variable.KH_prestacking_time+execute_time+action.radiant_spark.execute_time+action.touch_of_the_magi.execute_time,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:Covenant() == "Kyrian" and ArcaneInfinityEquipped and Player:BuffStack(S.ArcaneHarmonyBuff) < 15 and S.RadiantSpark:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() 
  and S.TouchoftheMagi:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RadiantSpark:ExecuteTime()
  and S.ArcanePower:CooldownRemains() <= var_KH_prestacking_time + S.ArcaneMissiles:ExecuteTime() + S.RadiantSpark:ExecuteTime() + S.TouchoftheMagi:ExecuteTime() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 5"; end
  end
  --touch_of_the_magi,if=runeforge.siphon_storm&prev_gcd.1.evocation
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and SiphonStormEquipped and Player:IsCasting(S.Evocation) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 6"; end
  end
  --arcane_power,if=runeforge.siphon_storm&(prev_gcd.1.evocation|prev_gcd.1.touch_of_the_magi)
  if S.ArcanePower:IsCastable() and SiphonStormEquipped and (Player:IsCasting(S.Evocation) or Player:IsCasting(S.TouchoftheMagi)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "touch_of_the_magi Aoe 7"; end
  end
  --evocation,if=time>30&runeforge.siphon_storm&buff.arcane_charge.stack<=variable.aoe_totm_max_charges&cooldown.touch_of_the_magi.remains=0&cooldown.arcane_power.remains<=gcd
  if S.Evocation:IsCastable() and CombatTime() > 30 and SiphonStormEquipped and Player:ArcaneCharges() <= var_aoe_totm_max_charges and S.TouchoftheMagi:CooldownRemains() == 0 and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Aoe 8"; end
  end
  --evocation,if=time>30&runeforge.siphon_storm&cooldown.arcane_power.remains=0
  --&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))
  --&buff.rune_of_power.down),interrupt_if=buff.siphon_storm.stack=buff.siphon_storm.max_stack,interrupt_immediate=1
  --TODO : manage siphon_storm interrupt_if
  if S.Evocation:IsCastable() and CombatTime() > 30 and SiphonStormEquipped and S.ArcanePower:CooldownRemains() == 0
  and (((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= Player:ArcaneChargesMax())) 
  and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation Aoe 9"; end
  end
  --mirrors_of_torment,if=(cooldown.arcane_power.remains>45|cooldown.arcane_power.remains<=3)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>5)|(!talent.rune_of_power&cooldown.arcane_power.remains>5)|cooldown.arcane_power.remains<=gcd))
  if S.MirrorsofTorment:IsCastable() and (Player:BuffRemains(S.ArcanePower) > 45 or Player:BuffRemains(S.ArcanePower) <= 3) and Target:DebuffRemains(S.TouchoftheMagi) == 0 and (Player:ArcaneCharges() <= var_aoe_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > 5) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > 5) or (Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains()))) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment Aoe 10"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains<execute_time
  --&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges
  --&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)
  --|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd))
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() < S.RadiantSpark:ExecuteTime() 
  and (Player:ArcaneCharges() <= var_aoe_totm_max_charges 
  and ((S.RuneofPower:IsAvailable() and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCD() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) 
  or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or S.ArcanePower:CooldownRemains() <= Player:GCD())) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark Aoe 11"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains<execute_time
  --&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))
  --&buff.rune_of_power.down)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() < S.RadiantSpark:ExecuteTime() 
  and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= Player:ArcaneChargesMax())) 
  and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark Aoe 12"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne Aoe 13"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|(!talent.rune_of_power&cooldown.arcane_power.remains>variable.totm_max_delay_for_ap)|cooldown.arcane_power.remains<=gcd)
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay_for_ap) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi Aoe 14"; end
  end
  --arcane_power,if=((cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down
  if CDsON() and S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power Aoe 15"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&((cooldown.touch_of_the_magi.remains>20&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&(cooldown.arcane_power.remains>12|debuff.touch_of_the_magi.up)
  if CDsON() and S.RuneofPower:IsCastable() and not S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > 20 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and (S.ArcanePower:CooldownRemains() > S.RuneofPower:BaseDuration() or Target:DebuffUp(S.TouchoftheMagi)) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power Aoe 16"; end
  end
  --shifting_power,if=cooldown.arcane_orb.remains>5|!talent.arcane_orb
  if S.ShiftingPower:IsCastable() and S.ArcaneOrb:CooldownRemains() > 5 or not S.ArcaneOrb:IsAvailable() then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "deathborne Aoe 17"; end
  end
  --arcane_blast,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&debuff.radiant_spark_vulnerability.stack=4&prev_gcd.1.arcane_orb
  --arcane_barrage,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&debuff.radiant_spark_vulnerability.stack=4
  --arcane_orb,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&debuff.radiant_spark_vulnerability.stack=3
  --arcane_barrage,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&debuff.radiant_spark_vulnerability.stack=2
  --arcane_blast,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&prev_gcd.2.radiant_spark&active_enemies=3
  --arcane_blast,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&dot.radiant_spark.remains&debuff.radiant_spark_vulnerability.stack<1&active_enemies=3
  --arcane_explosion,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&prev_gcd.2.radiant_spark&active_enemies>3
  --arcane_explosion,if=covenant.kyrian&runeforge.arcane_infinity&buff.arcane_power.up&debuff.radiant_spark_vulnerability.stack=1&active_enemies>3
  if Player:Covenant() == "Kyrian" and ArcaneInfinityEquipped and Player:BuffUp(S.ArcanePower) then
    if S.ArcaneBlast:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == 4 and Player:PrevGCD(1,S.ArcaneOrb) then
      if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Aoe 18"; end
    end
    if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == 4 then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Aoe 19"; end
    end
    if S.ArcaneOrb:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == 3 then
      if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb Aoe 20"; end
    end
    if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == 2 then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Aoe 21"; end
    end
    if S.ArcaneBlast:IsCastable() and Player:PrevGCD(2,S.RadiantSpark) and EnemiesCount8ySplash == 3 then
      if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Aoe 22"; end
    end
    if S.ArcaneBlast:IsCastable() and Target:DebuffRemains(S.RadiantSpark) > 0 and Target:DebuffStack(S.RadiantSparkVulnerability) < 1 and EnemiesCount8ySplash == 3 then
      if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Aoe 23"; end
    end
    if S.ArcaneExplosion:IsCastable() and Player:PrevGCD(2,S.RadiantSpark) and EnemiesCount8ySplash > 3 then
      if Settings.Arcane.StayDistance and not Target:IsInRange(10) then
        if CastLeft(S.ArcaneExplosion) then return "arcane_explosion Aoe 24 left"; end
      else
        if Cast(S.ArcaneExplosion) then return "arcane_explosion Aoe 24"; end
      end
    end
    if S.ArcaneExplosion:IsCastable() and Target:DebuffStack(S.RadiantSparkVulnerability) == 1 and EnemiesCount8ySplash > 3 then
      if Settings.Arcane.StayDistance and not Target:IsInRange(10) then
        if CastLeft(S.ArcaneExplosion) then return "arcane_explosion Aoe 25 left"; end
      else
        if Cast(S.ArcaneExplosion) then return "arcane_explosion Aoe 25"; end
      end
    end
  end
  --presence_of_mind,if=buff.deathborne.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
  --&((talent.resonance&active_enemies<4)|active_enemies<5)&(!runeforge.arcane_bombardment|target.health.pct>35)
  if CDsON() and S.PresenceofMind:IsCastable() and Player:DebuffDown(S.PresenceofMind) and Player:BuffUp(S.Deathborne) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= (PresenceMaxStack * S.ArcaneBlast:ExecuteTime()) + Player:GCDRemains() 
  and ((S.Resonance:IsAvailable() and EnemiesCount8ySplash < 4) or EnemiesCount8ySplash < 5) and (not ArcaneBombardmentEquipped or Target:HealthPercentage() > 35) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind Aoe 26"; end
  end
  --arcane_blast,if=buff.deathborne.up&((talent.resonance&active_enemies<4)|active_enemies<5)&(!runeforge.arcane_bombardment|target.health.pct>35)
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.Deathborne) and ((S.Resonance:IsAvailable() and EnemiesCount8ySplash < 4) or EnemiesCount8ySplash < 5) and (not ArcaneBombardmentEquipped or Target:HealthPercentage() > 35) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast Aoe 27"; end
  end
  --supernova
  if S.Supernova:IsCastable() then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova Aoe 28"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack>=(active_enemies-1)&runeforge.arcane_bombardment&target.health.pct<35
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() >= (EnemiesCount8ySplash - 1) and ArcaneBombardmentEquipped and Target:HealthPercentage() < 35 then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Aoe 29"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage Aoe 30"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack=0&(cooldown.arcane_power.remains>15|!(covenant.kyrian&runeforge.arcane_infinity))
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= 0 and (S.ArcanePower:CooldownRemains() > 15 or not (Player:Covenant() == "Kyrian" and ArcaneInfinityEquipped)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb Aoe 31"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest Aoe 32"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&runeforge.arcane_infinity&((talent.amplification&active_enemies<8)|active_enemies<5)
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and ArcaneInfinityEquipped and ((S.Amplification:IsAvailable() and EnemiesCount8ySplash < 8) or EnemiesCount8ySplash < 5) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 33"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&talent.arcane_echo&debuff.touch_of_the_magi.up&(talent.amplification|active_enemies<9)
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and S.ArcaneEcho:IsAvailable() and Target:DebuffUp(S.TouchoftheMagi) and (S.Amplification:IsAvailable() or EnemiesCount8ySplash < 9) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 34"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&talent.amplification&active_enemies<4
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and S.Amplification:IsAvailable() or EnemiesCount8ySplash < 4 then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles Aoe 35"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneExplosion:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Settings.Arcane.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion Aoe 36 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion Aoe 36"; end
    end
  end
  --arcane_explosion,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&prev_gcd.1.arcane_barrage
  if S.ArcaneExplosion:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:IsCasting(S.ArcaneBarrage) then
    if Settings.Arcane.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion Aoe 37 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion Aoe 37"; end
    end
  end
  --evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 85 then
    if Cast(S.Evocation) then return "evocation Aoe 38"; end
  end
end

local function AMSpam()
  --cancel_action,if=action.evocation.channeling&mana.pct>=95
  -- NYI cancel_action
  --evocation,if=mana.pct<=variable.evo_pct  
  --&(cooldown.touch_of_the_magi.remains<=action.evocation.execute_time|cooldown.arcane_power.remains<=action.evocation.execute_time|(talent.rune_of_power&cooldown.rune_of_power.remains<=action.evocation.execute_time))
  --&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.Evocation:IsCastable() and ((Player:IsCasting(S.Evocation) and Player:ManaPercentage() <= 95)
  or (not Player:IsCasting(S.Evocation) and (Player:ManaPercentage() <= var_evo_pct
  and (S.TouchoftheMagi:CooldownRemains() <= S.Evocation:ExecuteTime() or S.ArcanePower:CooldownRemains() <= S.Evocation:ExecuteTime() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.Evocation:ExecuteTime()))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi)))) then
    if Cast(S.Evocation) then return "evocation AMSpam 1-2"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0&(buff.rune_of_power.down&(cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm|cooldown.touch_of_the_magi.remains=0))
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (Player:BuffDown(S.RuneofPowerBuff) and (S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm or S.TouchoftheMagi:CooldownRemains() == 0)) then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne AMSpam 3"; end
  end
  --mirrors_of_torment,if=cooldown.arcane_power.remains=0&(buff.rune_of_power.down&(cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm|cooldown.touch_of_the_magi.remains=0))
  if S.MirrorsofTorment:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (Player:BuffDown(S.RuneofPowerBuff) and (S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm or S.TouchoftheMagi:CooldownRemains() == 0)) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment AMSpam 4"; end
  end
  --radiant_spark
  if S.RadiantSpark:IsCastable()  then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark AMSpam 5"; end
  end
  --shifting_power,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power AMSpam 6"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&cooldown.arcane_power.remains
  if CDsON() and S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and S.ArcanePower:CooldownRemains() > 0 then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power AMSpam 7"; end
  end
  --touch_of_the_magi,if=(cooldown.arcane_power.remains=0&buff.rune_of_power.down)|prev_gcd.1.rune_of_power
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and (Player:IsCasting(S.RuneofPower) or (not Player:IsCasting() and Player:IsCasting(S.RuneOfPower)))
  and S.ArcanePower:CooldownRemains() == 0 and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi AMSpam 8"; end
  end
  --touch_of_the_magi,if=cooldown.arcane_power.remains<50&buff.rune_of_power.down&essence.vision_of_perfection.enabled
  -- not implemented because vision_of_perfection is no longer used
  --arcane_power,if=buff.rune_of_power.down&cooldown.touch_of_the_magi.remains>variable.ap_max_delay_for_totm
  if CDsON() and S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay_for_totm then
    if Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power AMSpam 9"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=action.arcane_missiles.execute_time&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= S.ArcaneMissiles:ExecuteTime() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage AMSpam 10"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb AMSpam 11"; end
  end
  --arcane_barrage,if=buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage AMSpam 12"; end
  end
  --arcane_missiles,if=buff.clearcasting.react,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|buff.rune_of_power.up|cooldown.evocation.ready)
  --TODO : early_chain_if
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles AMSpam 13"; end
  end
  --arcane_missiles,if=!azerite.arcane_pummeling.enabled|buff.clearcasting_channel.down,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|buff.rune_of_power.up|cooldown.evocation.ready)
  --TODO : early_chain_if
  if S.ArcaneMissiles:IsCastable() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles AMSpam 14"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if Cast(S.Evocation) then return "evocation AMSpam 15"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb AMSpam 16"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage AMSpam 17"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 18"; end
  end
end

local function Movement()
  --blink_any,if=movement.distance>=10
  if S.Blink:IsCastable() and (not Target:IsInRange(S.ArcaneBlast:MaximumRange())) then
    if Cast(S.Blink) then return "blink_any movement 1"; end
  end
  --presence_of_mind
  if CDsON() and S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind movement 2"; end
  end
  --arcane_missiles,if=movement.distance<10
  if S.ArcaneMissiles:IsCastable() then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles movement 3"; end
  end
  --arcane_orb
  if S.ArcaneOrb:IsCastable() then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb movement 4"; end
  end
  --fire_blast
  if S.FireBlast:IsCastable() then
    if Cast(S.FireBlast, nil, nil, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast movement 5"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  EnemiesCount30ySplash = Target:GetEnemiesInSplashRangeCount(30)
  Enemies10yMelee = Player:GetEnemiesInMeleeRange(10)
  EnemiesCount10yMelee = #Enemies10yMelee

  -- Check when the Disciplinary Command buff was last applied and its internal CD
  var_disciplinary_command_last_applied = S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()
  var_disciplinary_command_cd_remains = 30 - var_disciplinary_command_last_applied
  if var_disciplinary_command_cd_remains < 0 then var_disciplinary_command_cd_remains = 0 end

  -- Disciplinary Command Check
  Mage.DCCheck()

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() and Everyone.TargetIsValid() then
    ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    if not var_init then
      ArcaneOpener:StartOpener()
    end
    --counterspell
    --ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
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
    --call_action_list,name=shared_cds
    if CDsON() then
      ShouldReturn = SharedCds(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=aoe,if=active_enemies>2
    if AoEON() and EnemiesCount8ySplash > 2 then
      ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=harmony,if=covenant.kyrian&runeforge.arcane_infinity&talent.rune_of_power
    if Player:Covenant() == "Kyrian" and ArcaneInfinityEquipped and S.RuneofPower:IsAvailable() then
      ShouldReturn = Harmony(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=fishing_opener,if=variable.have_opened=0&variable.fishing_opener
    if not ArcaneOpener:HasOpened() and var_fishing_opener then
      ShouldReturn = FishingOpener(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=opener,if=variable.have_opened=0
    if not ArcaneOpener:HasOpened() and CDsON() then
      ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=am_spam,if=variable.am_spam=1
    if Settings.Arcane.AMSpamRotation then
      ShouldReturn = AMSpam(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=cooldowns
    if CDsON() then
      ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=rotation,if=variable.final_burn=0
    if not ArcaneOpener:IsFinalBurn() then
      ShouldReturn = Rotation(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=final_burn,if=variable.final_burn=1
    if ArcaneOpener:IsFinalBurn() then
      ShouldReturn = Final_burn(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=movement
    if (true) then
      ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()
  HR.Print("Arcane Mage rotation is currently a work in progress.")
end

HR.SetAPL(62, APL, Init)

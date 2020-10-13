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
local Mage       = HR.Commons.Mage

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Arcane;
local I = Item.Mage.Arcane;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.TidestormCodex:ID(),
  I.PocketsizedComputationDevice:ID(),
  I.AzsharasFontofPower:ID()
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

local var_prepull_evo
local var_rs_max_delay
local var_ap_max_delay
local var_rop_max_delay
local var_totm_max_delay
local var_barrage_mana_pct
local var_ap_minimum_mana_pct
local var_aoe_totm_charges
local var_init = false
local RadiantSparlVulnerabilityMaxStack = 4
local ClearCastingMaxStack = 3

Player.ArcaneOpener = {}
local ArcaneOpener = Player.ArcaneOpener

function ArcaneOpener:Reset()
  self.state = false
  self.final_burn = false
  self.has_opened = false

  var_init = false
end
ArcaneOpener:Reset()

local function VarInit()
  --variable,name=prepull_evo,op=set,value=0
  --variable,name=prepull_evo,op=set,value=1,if=runeforge.siphon_storm.equipped&active_enemies>2
  --variable,name=prepull_evo,op=set,value=1,if=runeforge.siphon_storm.equipped&covenant.necrolord.enabled&active_enemies>1
  --variable,name=prepull_evo,op=set,value=1,if=runeforge.siphon_storm.equipped&covenant.night_fae.enabled
  -- NYI legendaries
  var_prepull_evo = false
  --variable,name=have_opened,op=set,value=0
  --variable,name=have_opened,op=set,value=1,if=active_enemies>2
  --variable,name=have_opened,op=set,value=1,if=variable.prepull_evo=1
  if (HR.AoEON() and EnemiesCount8ySplash > 2) or var_prepull_evo then
    ArcaneOpener:StopOpener()
  end
  --variable,name=rs_max_delay,op=set,value=5
  var_rs_max_delay = 5
  --variable,name=ap_max_delay,op=set,value=10
  var_ap_max_delay = 10
  --variable,name=rop_max_delay,op=set,value=20
  var_rop_max_delay = 20
  
  --variable,name=totm_max_delay,op=set,value=3,if=runeforge.disciplinary_command.equipped
  --variable,name=totm_max_delay,op=set,value=15,if=conduit.arcane_prodigy.enabled&active_enemies<3
  --variable,name=totm_max_delay,op=set,value=30,if=essence.vision_of_perfection.minor
  -- NYI legendaries, conduit, essence
  if Player:Covenant() ~= "Night Fae" then
    --variable,name=totm_max_delay,op=set,value=15,if=covenant.night_fae.enabled
    var_totm_max_delay = 15
  else
    --variable,name=totm_max_delay,op=set,value=5
    var_totm_max_delay = 5
  end
  --variable,name=barrage_mana_pct,op=set,value=90
  --variable,name=barrage_mana_pct,op=set,value=80,if=covenant.night_fae.enabled
  if Player:Covenant() ~= "Night Fae" then
    var_barrage_mana_pct = 80
  else
    var_barrage_mana_pct = 90
  end
  --variable,name=ap_minimum_mana_pct,op=set,value=30
  --variable,name=ap_minimum_mana_pct,op=set,value=50,if=runeforge.disciplinary_command.equipped
  --variable,name=ap_minimum_mana_pct,op=set,value=50,if=runeforge.grisly_icicle.equipped
  -- NYI legendaries
  var_ap_minimum_mana_pct = 30
  --variable,name=aoe_totm_charges,op=set,value=2
  var_aoe_totm_charges = 2

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
  return self.state or (not Player:AffectingCombat() and (Player:IsCasting(S.Frostbolt) or Player:IsCasting(S.Evocation)))
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

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function Precombat ()
  -- flask
  -- food
  -- augmentation
  -- conjure_mana_gem
  --TODO : manage mana gem ?
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 1"; end
  end
  -- arcane_familiar
  if S.ArcaneFamiliar:IsCastable() and Player:BuffDown(S.ArcaneFamiliarBuff) then
    if HR.Cast(S.ArcaneFamiliar) then return "arcane_familiar precombat 2"; end
  end
  -- mirror_image
  if S.MirrorImage:IsCastable() and HR.CDsON() then
    if HR.Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 3"; end
  end
  -- potion
  --[[ if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_intellect precombat 4"; end
  end ]]
  -- frostbolt,if=variable.prepull_evo=0
  if not var_prepull_evo and S.Frostbolt:IsReady() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 5"; end
  end
  -- evocation,if=variable.prepull_evo=1
  if var_prepull_evo and S.Evocation:IsReady() then
    if HR.Cast(S.Evocation) then return "frostbolt precombat 6"; end
  end
end

local function Essences ()
  --blood_of_the_enemy,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd|target.time_to_die<cooldown.arcane_power.remains
  if S.BloodoftheEnemy:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= 2 and S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) or Target:TimeToDie() < S.ArcanePower:CooldownRemains()) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy essence 1"; end
  end
  --blood_of_the_enemy,if=cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.BloodoftheEnemy:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and ((S.TouchoftheMagi:CooldownRemains() > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy essence 2"; end
  end
  --worldvein_resonance,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd|target.time_to_die<cooldown.arcane_power.remains
  if S.WorldveinResonance:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= 2 and S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) or Target:TimeToDie() < S.ArcanePower:CooldownRemains()) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essence 3"; end
  end
  --worldvein_resonance,if=cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.WorldveinResonance:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and ((S.TouchoftheMagi:CooldownRemains() > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essence 4"; end
  end
  --guardian_of_azeroth,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd|target.time_to_die<cooldown.arcane_power.remains
  if S.GuardianofAzeroth:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= 2 and S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) or Target:TimeToDie() < S.ArcanePower:CooldownRemains()) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth essence 5"; end
  end
  --guardian_of_azeroth,if=cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.GuardianofAzeroth:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and ((Player:BuffRemains(S.TouchoftheMagi) > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth essence 6"; end
  end
  --concentrated_flame,line_cd=6,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&mana.time_to_max>=execute_time
  if S.ConcentratedFlame:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffRemains(S.TouchoftheMagi) and Player:ManaTimeToMax() >= S.ConcentratedFlame:ExecuteTime() then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame essence 7"; end
  end
  --reaping_flames,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&mana.time_to_max>=execute_time
  if Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffRemains(S.TouchoftheMagi) and Player:ManaTimeToMax() >= S.ReapingFlames:ExecuteTime() then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn.." essence 8"; end
  end
  --focused_azerite_beam,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down 
  if S.FocusedAzeriteBeam:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam essence 9"; end
  end
  --purifying_blast,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.PurifyingBlast:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast essence 10"; end
  end
  --ripple_in_space,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.RippleInSpace:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space essence 11"; end
  end
  --the_unbound_force,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.TheUnboundForce:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force essence 12"; end
  end
  --memory_of_lucid_dreams,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.MemoryofLucidDreams:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams essence 13"; end
  end
end

local function Cooldowns ()
  --lights_judgment,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment cd 1"; end
  end
  --bag_of_tricks,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.BagofTricks:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks cd 2"; end
  end
  --use_items,if=buff.arcane_power.up
  --berserking,if=buff.arcane_power.up
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 4"; end
  end
  --blood_fury,if=buff.arcane_power.up
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 5"; end
  end
  --fireblood,if=buff.arcane_power.up
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 6"; end
  end
  --ancestral_call,if=buff.arcane_power.up
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 7"; end
  end
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=2&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  -- NYI legendaries
  --frostbolt,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=2&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  -- NYI legendaries
  --fire_blast,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt
  -- NYI legendaries
  --mirrors_of_torment,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd
  if S.MirrorsofTorment:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= 2 and Player:BuffDown(S.ArcanePower)) or Target:TimeToDie() < S.ArcanePower:CooldownRemains()) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment cd 12"; end
  end
  --mirrors_of_torment,if=cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.MirrorsofTorment:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and ((Player:BuffRemains(S.TouchoftheMagi) > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment cd 13"; end
  end
  --deathborne,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd
  if S.Deathborne:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= 2 and Player:BuffDown(S.ArcanePower)) or Target:TimeToDie() < S.ArcanePower:CooldownRemains()) then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne cd 14"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and ((Player:BuffRemains(S.TouchoftheMagi) > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne cd 15"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains>variable.rs_max_delay&cooldown.arcane_power.remains>variable.rs_max_delay&(talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd|talent.rune_of_power.enabled&cooldown.rune_of_power.remains>variable.rs_max_delay|!talent.rune_of_power.enabled)&buff.arcane_charge.stack>2&debuff.touch_of_the_magi.down
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() > var_rs_max_delay and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains()) or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > var_rs_max_delay) or not S.RuneofPower:IsAvailable()) and Player:ArcaneCharges() > 2 and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark cd 16"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= 2 and Player:BuffDown(S.ArcanePower)) or Target:TimeToDie() < S.ArcanePower:CooldownRemains()) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark cd 17"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains=0&((!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark cd 18"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=2&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay&covenant.kyrian.enabled&cooldown.radiant_spark.remains<=8
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and (Player:Covenant() and Player:Covenant() == "Kyrian") and Player:ArcaneCharges() <= 2 and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay and S.RadiantSpark:CooldownRemains() <= 8 then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 19"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=2&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay&!covenant.kyrian.enabled
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and (not Player:Covenant() or Player:Covenant() ~= "Kyrian") and Player:ArcaneCharges() <= 2 and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 20"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=2&!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= 2 and not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 21"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=2&cooldown.arcane_power.remains<=gcd
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= 2 and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 22"; end
  end
  --arcane_power,if=(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.ArcanePower:IsCastable() and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) and S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power cd 23"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&cooldown.touch_of_the_magi.remains>variable.rop_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(cooldown.arcane_power.remains>15|debuff.touch_of_the_magi.up)
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and S.TouchoftheMagi:CooldownRemains() > var_rop_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (S.ArcanePower:CooldownRemains() > 15 or Target:DebuffRemains(S.TouchoftheMagi) > S.RuneofPower:CastTime()) then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 24"; end
  end
  --presence_of_mind,if=buff.arcane_charge.stack=0&covenant.kyrian.enabled
  if S.PresenceofMind:IsCastable() and (Player:Covenant() and Player:Covenant() == "Kyrian") and Player:ArcaneCharges() == 0 then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cd 25"; end
  end
  --presence_of_mind,if=debuff.touch_of_the_magi.up&!covenant.kyrian.enabled
  if S.PresenceofMind:IsCastable() and (not Player:Covenant() or Player:Covenant() ~= "Kyrian") and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cd 26"; end
  end
  --use_mana_gem,if=cooldown.evocation.remains>0&((talent.enlightened.enabled&mana.pct<=80&mana.pct>=65)|(!talent.enlightened.enabled&mana.pct<=85))
  --TODO : manage mana_gem
end

local function Aoe ()
  --use_mana_gem,if=(talent.enlightened.enabled&mana.pct<=80&mana.pct>=65)|(!talent.enlightened.enabled&mana.pct<=85)
  --TODO manage mana gem
  --lights_judgment,if=buff.arcane_power.down
  if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment aoe 2"; end
  end
  --bag_of_tricks,if=buff.arcane_power.down
  if S.BagofTricks:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks aoe 3"; end
  end
  --use_items,if=buff.arcane_power.up
  --berserking,if=buff.arcane_power.up
  if S.Berserking:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking aoe 5"; end
  end
  --blood_fury,if=buff.arcane_power.up
  if S.BloodFury:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury aoe 6"; end
  end
  --fireblood,if=buff.arcane_power.up
  if S.Fireblood:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood aoe 7"; end
  end
  --ancestral_call,if=buff.arcane_power.up
  if S.AncestralCall:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call aoe 8"; end
  end
  --time_warp,if=runeforge.temporal_warp.equipped
  --NYI legendaries
  --frostbolt,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  --NYI legendaries
  --fire_blast,if=(runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt)|(runeforge.disciplinary_command.equipped&time=0)
  --NYI legendaries
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  --NYI legendaries
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_charges))&buff.rune_of_power.down)
  --NYI legendaries
  --touch_of_the_magi,if=runeforge.siphon_storm.equipped&prev_gcd.1.evocation
  --NYI legendaries
  --arcane_power,if=runeforge.siphon_storm.equipped&(prev_gcd.1.evocation|prev_gcd.1.touch_of_the_magi)
  --NYI legendaries
  --evocation,if=time>30&runeforge.siphon_storm.equipped&buff.arcane_charge.stack<=variable.aoe_totm_charges&cooldown.touch_of_the_magi.remains=0&cooldown.arcane_power.remains<=gcd
  --NYI legendaries
  --evocation,if=time>30&runeforge.siphon_storm.equipped&cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_charges))&buff.rune_of_power.down),interrupt_if=buff.siphon_storm.stack=buff.siphon_storm.max_stack,interrupt_immediate=1
  --NYI legendaries
  --mirrors_of_torment,if=(cooldown.arcane_power.remains>45|cooldown.arcane_power.remains<=3)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>5)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>5)|cooldown.arcane_power.remains<=gcd))
  if S.MirrorsofTorment:IsCastable() and (Player:BuffRemains(S.ArcanePower) > 45 or Player:BuffRemains(S.ArcanePower) <= 3) and Target:DebuffRemains(S.TouchoftheMagi) == 0 and (Player:ArcaneCharges() <= var_aoe_totm_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > 5) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > 5) or (Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains()))) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment aoe 18"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains>variable.rs_max_delay&cooldown.arcane_power.remains>variable.rs_max_delay&(talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd|talent.rune_of_power.enabled&cooldown.rune_of_power.remains>variable.rs_max_delay|!talent.rune_of_power.enabled)&buff.arcane_charge.stack<=variable.aoe_totm_charges&debuff.touch_of_the_magi.down
  if S.RadiantSpark:IsCastable() and Target:DebuffRemains(S.TouchoftheMagi) > var_rs_max_delay and S.ArcanePower:CooldownRemains() > var_rs_max_delay and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains()) or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > var_rs_max_delay) or (not S.RuneofPower:IsAvailable())) and Player:ArcaneCharges() <= var_aoe_totm_charges and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark aoe 19"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and (Player:ArcaneCharges() <= var_aoe_totm_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains())) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark aoe 20"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_charges))&buff.rune_of_power.down)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ArcaneCharges() <= var_aoe_totm_charges)) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark aoe 21"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_charges))&buff.rune_of_power.down)
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ArcaneCharges() <= var_aoe_totm_charges)) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne aoe 22"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.aoe_totm_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd)
  if S.TouchoftheMagi:IsCastable() and Player:ArcaneCharges() <= var_aoe_totm_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi aoe 23"; end
  end
  --arcane_power,if=((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_charges))&buff.rune_of_power.down
  if HR.CDsON() and S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_aoe_totm_charges)) then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power aoe 24"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&((cooldown.touch_of_the_magi.remains>20&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_charges))&(cooldown.arcane_power.remains>15|debuff.touch_of_the_magi.up)
  if HR.CDsON() and S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > 20 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_aoe_totm_charges)) and (S.ArcanePower:CooldownRemains() or Target:DebuffUp(S.TouchoftheMagi)) then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power aoe 25"; end
  end
  --presence_of_mind,if=buff.deathborne.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
  if HR.CDsON() and S.PresenceofMind:IsCastable() and Player:BuffUp(S.Deathborne) and Target:DebuffUp(S.TouchoftheMagi) and S.TouchoftheMagi:CooldownRemains() <= 2 * S.ArcaneBlast:ExecuteTime() then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind aoe 26"; end
  end
  --arcane_blast,if=buff.deathborne.up&((talent.resonance.enabled&active_enemies<4)|active_enemies<5)
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.Deathborne) and ((S.Resonance:IsAvailable() and EnemiesCount8ySplash < 4) or EnemiesCount8ySplash < 5) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 27"; end
  end
  --supernova
  if S.Supernova:IsCastable() then
    if HR.Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova aoe 28"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack=0
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= 0 then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb aoe 29"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest aoe 30"; end
  end
  --shifting_power,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&cooldown.arcane_power.remains>0&cooldown.touch_of_the_magi.remains>0&(!talent.rune_of_power.enabled|(talent.rune_of_power.enabled&cooldown.rune_of_power.remains>0))
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and S.ArcanePower:CooldownRemains() > 0 and S.TouchoftheMagi:CooldownRemains() > 0 and (not S.RuneofPower:IsAvailable() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > 0)) then
    if HR.Cast(S.ShiftingPower, nil, nil, not Target:IsSpellInRange(S.ShiftingPower)) then return "shifting_power aoe 31"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&runeforge.arcane_infinity.equipped&talent.amplification.enabled&active_enemies<4
  --NYI legendaries
  --arcane_explosion,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.Evocation:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if HR.Cast(S.Evocation) then return "arcane_explosion aoe 33"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe 34"; end
  end
  --evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 85 then
    if HR.Cast(S.Evocation) then return "evocation aoe 35"; end
  end
end

local function Opener ()
  if not ArcaneOpener:On() then
    ArcaneOpener:StartOpener()
    return "Start opener"
  end
  --variable,name=have_opened,op=set,value=1,if=prev_gcd.1.evocation
  if Player:PrevGCDP(1, S.Evocation) and ArcaneOpener:On() then
    ArcaneOpener:StopOpener()
    return "Stop opener 1"
  end
  --lights_judgment,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if HR.CDsON() and S.LightsJudgment:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment opener 2"; end
  end
  --bag_of_tricks,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if HR.CDsON() and S.BagofTricks:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks opener 3"; end
  end
  --use_items,if=buff.arcane_power.up
  --berserking,if=buff.arcane_power.up
  if HR.CDsON() and S.Berserking:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking opener 5"; end
  end
  --blood_fury,if=buff.arcane_power.up
  if HR.CDsON() and S.BloodFury:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury opener 6"; end
  end
  --fireblood,if=buff.arcane_power.up
  if HR.CDsON() and S.Fireblood:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood opener 7"; end
  end
  --ancestral_call,if=buff.arcane_power.up
  if HR.CDsON() and S.AncestralCall:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call opener 8"; end
  end
  --fire_blast,if=runeforge.disciplinary_command.equipped&buff.disciplinary_command_frost.up
  -- NYI legendaries
  --frost_nova,if=runeforge.grisly_icicle.equipped&mana.pct>95
  -- NYI legendaries
  --mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment opener 11"; end
  end
  --deathborne
  if S.Deathborne:IsCastable() then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne opener 12"; end
  end
  --radiant_spark,if=mana.pct>40
  if S.RadiantSpark:IsCastable() and Player:ManaPercentage() > 40 then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark opener 12"; end
  end
  --cancel_action,if=action.shifting_power.channeling
  --shifting_power,if=soulbind.field_of_blossoms.enabled
  --NYI soulbind
  --touch_of_the_magi
  if S.TouchoftheMagi:IsCastable() then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi opener 16"; end
  end
  --arcane_power
  if HR.CDsON() and S.ArcanePower:IsCastable() then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power opener 17"; end
  end
  --rune_of_power,if=buff.rune_of_power.down
  if HR.CDsON() and S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power opener 18"; end
  end
  --use_mana_gem,if=(talent.enlightened.enabled&mana.pct<=80&mana.pct>=65)|(!talent.enlightened.enabled&mana.pct<=85)
  --TODO manage mana gem
  --berserking,if=buff.arcane_power.up
  --TODO useless ?
  if HR.CDsON() and S.Berserking:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking opener 20"; end
  end
  --time_warp,if=runeforge.temporal_warp.equipped
  --NYI legendaries
  --presence_of_mind,if=debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
  if HR.CDsON() and S.PresenceofMind:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= 2 * S.ArcaneBlast:ExecuteTime() then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind opener 22"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparlVulnerability) > 0) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 23"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=action.arcane_blast.execute_time
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= S.ArcaneBlast:ExecuteTime() then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 24"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 25"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo.enabled&buff.deathborne.down&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time,chain=1
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and Player:BuffDown(S.Deathborne) and Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 26"; end
  end
  --arcane_missiles,if=buff.clearcasting.react,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 27"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=2&(cooldown.arcane_power.remains>10|active_enemies<=2)
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= 2 and (Player:BuffRemains(S.ArcanePower) > 10 or EnemiesCount16ySplash <= 2) then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb opener 28"; end
  end
  --arcane_blast,if=buff.rune_of_power.up|mana.pct>15
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) or Player:ManaPercentage() > 15 then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 29"; end
  end
  --evocation,if=buff.rune_of_power.down,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() < 85 then
    if HR.Cast(S.Evocation) then return "evocation opener 30"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 31"; end
  end
end

local function Rotation ()
  --variable,name=final_burn,op=set,value=1,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&!buff.rule_of_threes.up&target.time_to_die<=((mana%action.arcane_blast.cost)*action.arcane_blast.execute_time)
  if Player:ArcaneCharges() == Player:ArcaneChargesMax() and not Player:BuffUp(S.RuleofThreesBuff) and Target:TimeToDie() <= ((Player:Mana() / S.ArcaneBlast:Cost())*S.ArcaneBlast:ExecuteTime()) then
    ArcaneOpener:StartFinalBurn()
    return "Make final"
  end
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=debuff.radiant_spark_vulnerability.max_stack&(buff.rune_of_power.down|buff.rune_of_power.remains<=gcd)
  if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparlVulnerability) == RadiantSparlVulnerabilityMaxStack and (Player:BuffDown(S.RuneofPowerBuff) or Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains()) then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 1"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparlVulnerability) > 0) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 2"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=action.arcane_blast.execute_time
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) < S.ArcaneBlast:ExecuteTime() then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 3"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo.enabled&buff.deathborne.down&(debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time|cooldown.presence_of_mind.remains>0|covenant.kyrian.enabled),chain=1
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and Player:BuffDown(S.Deathborne) and (Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() or S.PresenceofMind:CooldownRemains() > 0 or Player:Covenant() == "Kyrian") then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 4"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.expanded_potential.up
  -- NYI legendaries
  --[[ if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff)  then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 5"; end
  end ]]
  --arcane_missiles,if=buff.clearcasting.react&(buff.arcane_power.up|buff.rune_of_power.up|debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and (Player:BuffUp(S.ArcanePower) or Player:BuffUp(S.RuneofPowerBuff) or Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime()) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 6"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 7"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.remains<=((buff.clearcasting.stack*action.arcane_missiles.execute_time)+gcd),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffRemains(S.ClearcastingBuff) <= ((Player:BuffStack(S.ClearcastingBuff) * S.ArcaneMissiles:ExecuteTime()) + Player:GCD()) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 8"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) == 0 then
    if HR.Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 9"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=2
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= 2 then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb rotation 10"; end
  end
  --supernova,if=mana.pct<=95&buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.Supernova:IsCastable() and Player:ManaPercentage() <= 95 and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova rotation 11"; end
  end
  --shifting_power,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>0&cooldown.arcane_power.remains>0&cooldown.touch_of_the_magi.remains>0&(!talent.rune_of_power.enabled|(talent.rune_of_power.enabled&cooldown.rune_of_power.remains>0))
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and S.Evocation:CooldownRemains() > 0 and S.ArcanePower:CooldownRemains() > 0 and S.TouchoftheMagi:CooldownRemains() > 0 and (not S.RuneofPower:IsAvailable() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > 0)) then
    if HR.Cast(S.ShiftingPower, nil, nil, not Target:IsSpellInRange(S.ShiftingPower)) then return "shifting_power rotation 12"; end
  end
  --arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.RuleofThreesBuff) and Player:ArcaneCharges() > 3 then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 13"; end
  end
  --arcane_barrage,if=mana.pct<variable.barrage_mana_pct&cooldown.evocation.remains>0&buff.arcane_power.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&essence.vision_of_perfection.minor
  if S.ArcaneBarrage:IsCastable() and Player:ManaPercentage() < var_barrage_mana_pct and S.Evocation:CooldownRemains() > 0 and Player:BuffDown(S.ArcanePower) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 14"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.remains=0&(cooldown.rune_of_power.remains=0|cooldown.arcane_power.remains=0)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and (S.RuneofPower:CooldownRemains() == 0 or S.ArcanePower:CooldownRemains() == 0) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 15"; end
  end
  --arcane_barrage,if=mana.pct<=variable.barrage_mana_pct&buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&cooldown.evocation.remains>0
  if S.ArcaneBarrage:IsCastable() and Player:ManaPercentage() < var_barrage_mana_pct and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.Evocation:CooldownRemains() > 0 then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 16"; end
  end
  --arcane_barrage,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd&mana.pct<=90&cooldown.evocation.remains>0
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() <= Player:GCDRemains() and Player:ManaPercentage() <= 90 and S.Evocation:CooldownRemains() > 0 then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 17"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 18"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.rune_of_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 19"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable() then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 20"; end
  end
  --evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 85 then
    if HR.Cast(S.Evocation) then return "evocation rotation 21"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 22"; end
  end
end

local function Final_burn ()
  --arcane_missiles,if=buff.clearcasting.react,chain=1
  if S.ArcaneMissiles:IsCastable() then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles final 1"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable()  then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast final 2"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage final 3"; end
  end
end

local function Movement ()
  --shimmer,if=movement.distance>=10
  --presence_of_mind
  --arcane_missiles,if=movement.distance<10
  --arcane_orb
  -- blink_any,if=movement.distance>=10
  if S.Blink:IsCastable() and (not Target:IsInRange(S.ArcaneBlast:MaximumRange())) then
    if HR.Cast(S.Blink) then return "blink_any 501"; end
  end
  -- presence_of_mind
  if HR.CDsON() and S.PresenceofMind:IsCastable() then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind 503"; end
  end
  -- arcane_missiles
  if S.ArcaneMissiles:IsCastable() then
    if HR.Cast(S.ArcaneMissiles, nil, nil, 40) then return "arcane_missiles 505"; end
  end
  -- arcane_orb
  if S.ArcaneOrb:IsCastable() then
    if HR.Cast(S.ArcaneOrb, nil, nil, 40) then return "arcane_orb 507"; end
  end
  -- supernova
  if S.Supernova:IsCastable() then
    if HR.Cast(S.Supernova, nil, nil, 40) then return "supernova 509"; end
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

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() and Everyone.TargetIsValid() then
    ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    if not var_init then
      VarInit()
    end
    --counterspell
    --ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    --call_action_list,name=essences
    if HR.CDsON() then
      ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=aoe,if=active_enemies>2
    if HR.AoEON() and EnemiesCount8ySplash > 2 then
      ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=opener,if=variable.have_opened=0
    if not ArcaneOpener:HasOpened() then
      ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=cooldowns
    if HR.CDsON() then
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
    -- TODO : movement
    --[[     if (true) then
      ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end ]]
  end
end

local function Init()

end

HR.SetAPL(62, APL, Init)

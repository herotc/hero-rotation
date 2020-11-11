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

------ TODO -------
-- mana gem
-- potion
-- conduits
-- legendaries

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
local var_totm_max_charges
local var_aoe_totm_charges
local var_am_spam_evo_pct
local var_am_spam
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
  --variable,name=prepull_evo,op=reset,default=0
  --variable,name=prepull_evo,op=set,value=1,if=variable.prepull_evo=0&runeforge.siphon_storm.equipped&active_enemies>2
  --variable,name=prepull_evo,op=set,value=1,if=variable.prepull_evo=0&runeforge.siphon_storm.equipped&covenant.necrolord.enabled&active_enemies>1
  --variable,name=prepull_evo,op=set,value=1,if=variable.prepull_evo=0&runeforge.siphon_storm.equipped&covenant.night_fae.enabled
  -- NYI legendaries
  var_prepull_evo = false
  --variable,name=have_opened,op=reset,default=0
  --variable,name=have_opened,op=set,value=1,if=variable.have_opened=0&active_enemies>2
  --variable,name=have_opened,op=set,value=1,if=variable.have_opened=0&variable.prepull_evo=1
  --variable,name=have_opened,op=set,value=1,if=variable.have_opened=0&variable.am_spam=1
  if (HR.AoEON() and EnemiesCount8ySplash > 2) or var_prepull_evo or Settings.Arcane.AMSpamRotation then
    ArcaneOpener:StopOpener()
  end
  --variable,name=final_burn,op=set,value=0
  --variable,name=rs_max_delay,op=set,value=5
  var_rs_max_delay = 5
  --variable,name=ap_max_delay,op=set,value=10
  var_ap_max_delay = 10
  --variable,name=rop_max_delay,op=set,value=20
  var_rop_max_delay = 20
  
  --variable,name=totm_max_delay,op=reset,default=5
  --variable,name=totm_max_delay,op=set,value=3,if=variable.totm_max_delay=5&runeforge.disciplinary_command.equipped
  --variable,name=totm_max_delay,op=set,value=15,if=variable.totm_max_delay=5&covenant.night_fae.enabled
  --variable,name=totm_max_delay,op=set,value=15,if=variable.totm_max_delay=5&conduit.arcane_prodigy.enabled&active_enemies<3
  --variable,name=totm_max_delay,op=set,value=30,if=variable.totm_max_delay=5&essence.vision_of_perfection.minor
  -- NYI legendaries, conduit
  if Player:Covenant() ~= "Night Fae" then
    var_totm_max_delay = 15
  elseif Spell:EssenceEnabled(AE.VisionofPerfection) then
    var_totm_max_delay = 30
  else
    var_totm_max_delay = 5
  end
  --variable,name=barrage_mana_pct,op=reset,default=70
  --variable,name=barrage_mana_pct,op=set,value=40,if=variable.barrage_mana_pct=70&covenant.night_fae.enabled
  if Player:Covenant() ~= "Night Fae" then
    var_barrage_mana_pct = 40
  else
    var_barrage_mana_pct = 70
  end
  --variable,name=ap_minimum_mana_pct,op=reset,default=30
  --variable,name=ap_minimum_mana_pct,op=set,value=50,if=variable.ap_minimum_mana_pct=30&runeforge.disciplinary_command.equipped
  --variable,name=ap_minimum_mana_pct,op=set,value=50,if=variable.ap_minimum_mana_pct=30&runeforge.grisly_icicle.equipped
  -- NYI legendaries
  var_ap_minimum_mana_pct = 30
  --variable,name=totm_max_charges,op=reset,default=2
  var_totm_max_charges = 2
  --variable,name=aoe_totm_max_charges,op=reset,default=2
  var_aoe_totm_charges = 2
  --variable,name=am_spam,op=reset,default=0
  var_am_spam = 0
  --variable,name=am_spam_evo_pct,op=reset,default=15
  var_am_spam_evo_pct = 15

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
  --TODO : manage mana gem
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 1"; end
  end
  -- arcane_familiar
  if S.ArcaneFamiliar:IsCastable() and Player:BuffDown(S.ArcaneFamiliarBuff) then
    if HR.Cast(S.ArcaneFamiliar) then return "arcane_familiar precombat 2"; end
  end
  -- mirror_image
  if S.MirrorImage:IsCastable() and HR.CDsON() and Settings.Arcane.MirrorImagesBeforePull then
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

local function SharedCds ()
  --use_mana_gem,if=(talent.enlightened.enabled&mana.pct<=80&mana.pct>=65)|(!talent.enlightened.enabled&mana.pct<=85)
  --TODO : manage mana_gem
  --use_items,if=buff.arcane_power.up
  if (true) then
    local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  --potion,if=buff.arcane_power.up
  --TODO : manage potion
  --time_warp,if=runeforge.temporal_warp.equipped&buff.exhaustion.up
  --NYI legendaries
  --lights_judgment,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment Shared_cd 5"; end
  end
  --bag_of_tricks,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.BagofTricks:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks Shared_cd 6"; end
  end
  --berserking,if=buff.arcane_power.up
  if S.Berserking:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking Shared_cd 7"; end
  end
  --blood_fury,if=buff.arcane_power.up
  if S.BloodFury:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury Shared_cd 8"; end
  end
  --fireblood,if=buff.arcane_power.up
  if S.Fireblood:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood Shared_cd 9"; end
  end
  --ancestral_call,if=buff.arcane_power.up
  if S.AncestralCall:IsCastable() and Player:BuffUp(S.ArcanePower) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call Shared_cd 10"; end
  end
end

local function Essences ()
  --blood_of_the_enemy,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd|fight_remains<cooldown.arcane_power.remains
  if S.BloodoftheEnemy:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and ((Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) or HL.BossFilteredFightRemains("<", S.ArcanePower:CooldownRemains())) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy essence 1"; end
  end
  --blood_of_the_enemy, if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70|variable.am_spam=1))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|variable.am_spam=1))|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.BloodoftheEnemy:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and 
  (not S.Enlightened:IsAvailable() or ((S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70) or Settings.Arcane.AMSpamRotation)) 
  and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and (Player:ArcaneCharges() == Player:ArcaneChargesMax() or Settings.Arcane.AMSpamRotation)) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy essence 2"; end
  end
  --worldvein_resonance,if=cooldown.arcane_power.remains>=50&cooldown.touch_of_the_magi.remains<=gcd&buff.arcane_charge.stack<=variable.totm_max_charges&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay
  if S.WorldveinResonance:IsCastable() and S.ArcanePower:CooldownRemains() >= 50 and S.TouchoftheMagi:CooldownRemains() <= Player:GCDRemains() and Player:ArcaneCharges() <= var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() <= var_totm_max_delay then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essence 3"; end
  end
  --worldvein_resonance,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd|fight_remains<cooldown.arcane_power.remains
  if S.WorldveinResonance:IsCastable() and ((S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) or HL.BossFilteredFightRemains("<", S.ArcanePower:CooldownRemains())) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essence 4"; end
  end
  --worldvein_resonance,if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70|variable.am_spam=1))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|variable.am_spam=1))|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.WorldveinResonance:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and 
  (not S.Enlightened:IsAvailable() or ((S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70) or Settings.Arcane.AMSpamRotation)) 
  and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and (Player:ArcaneCharges() == Player:ArcaneChargesMax() or Settings.Arcane.AMSpamRotation)) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essence 5"; end
  end
  --guardian_of_azeroth,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd|fight_remains<cooldown.arcane_power.remains
  if S.GuardianofAzeroth:IsCastable() and ((S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) or HL.BossFilteredFightRemains("<", S.ArcanePower:CooldownRemains())) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth essence 6"; end
  end
  --guardian_of_azeroth,if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70|variable.am_spam=1))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|variable.am_spam=1))|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.GuardianofAzeroth:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and 
  (not S.Enlightened:IsAvailable() or ((S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70) or Settings.Arcane.AMSpamRotation)) 
  and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and (Player:ArcaneCharges() == Player:ArcaneChargesMax() or Settings.Arcane.AMSpamRotation)) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth essence 7"; end
  end
  --concentrated_flame,line_cd=6,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&mana.time_to_max>=execute_time
  --todo manage line_cd
  if S.ConcentratedFlame:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ManaTimeToMax() >= S.ConcentratedFlame:ExecuteTime() + Player:GCDRemains() then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame essence 8"; end
  end
  --reaping_flames,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&mana.time_to_max>=execute_time
  if Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ManaTimeToMax() >= S.ReapingFlames:ExecuteTime() + Player:GCDRemains() then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn.." essence 9"; end
  end
  --focused_azerite_beam,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down 
  if S.FocusedAzeriteBeam:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) == 0 then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam essence 10"; end
  end
  --purifying_blast,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.PurifyingBlast:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) == 0 then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast essence 11"; end
  end
  --ripple_in_space,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.RippleInSpace:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) == 0 then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space essence 12"; end
  end
  --the_unbound_force,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.TheUnboundForce:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) == 0 then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force essence 13"; end
  end
  --memory_of_lucid_dreams,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.MemoryofLucidDreams:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffRemains(S.TouchoftheMagi) == 0 then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams essence 14"; end
  end
end

local function Cooldowns ()
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))", "Prioritize using grisly icicle with ap. Use it with totm otherwise.
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains=0&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  -- NYI legendaries
  --frostbolt,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  -- NYI legendaries
  --fire_blast,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt
  -- NYI legendaries
  --mirrors_of_torment,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd
  if S.MirrorsofTorment:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment cd 5"; end
  end
  --mirrors_of_torment,if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.MirrorsofTorment:IsCastable() and S.ArcanePower:CooldownRemains() == 0 
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) 
  and ((Player:BuffRemains(S.TouchoftheMagi) > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment cd 6"; end
  end
  --deathborne,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd
  if S.Deathborne:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne cd 7"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0
  --&(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>10&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) 
  and ((Player:BuffRemains(S.TouchoftheMagi) > 10 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne cd 8"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains>variable.rs_max_delay&cooldown.arcane_power.remains>variable.rs_max_delay
  --&(talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd|talent.rune_of_power.enabled&cooldown.rune_of_power.remains>variable.rs_max_delay|!talent.rune_of_power.enabled)
  --&buff.arcane_charge.stack>2&debuff.touch_of_the_magi.down
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() > var_rs_max_delay 
  and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains()) or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > var_rs_max_delay) or not S.RuneofPower:IsAvailable()) 
  and Player:ArcaneCharges() > 2 and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark cd 9"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark cd 10"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains=0
  --&((!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))
  --&((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack=0))
  --&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() == 0 
  and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) 
  and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() == 0)) 
  and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark cd 11"; end
  end
  --touch_of_the_magi,if=cooldown.arcane_power.remains<50&essence.vision_of_perfection.minor
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and S.ArcanePower:CooldownRemains() < 50 and Spell:EssenceEnabled(AE.VisionofPerfection) then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 12"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay&covenant.kyrian.enabled&cooldown.radiant_spark.remains<=8
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:Covenant() == "Kyrian" and Player:ArcaneCharges() <= var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay and S.RadiantSpark:CooldownRemains() <= 8 then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 13"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay&!covenant.kyrian.enabled
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:Covenant() ~= "Kyrian" and Player:ArcaneCharges() <= var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 14"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 15"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.totm_max_charges&cooldown.arcane_power.remains<=gcd
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi cd 16"; end
  end
  --arcane_power,if=(!talent.enlightened.enabled|(talent.enlightened.enabled&mana.pct>=70))
  --&cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&mana.pct>=variable.ap_minimum_mana_pct
  if S.ArcanePower:IsCastable() and (not S.Enlightened:IsAvailable() or (S.Enlightened:IsAvailable() and Player:ManaPercentage() >= 70)) 
  and S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() >= var_ap_minimum_mana_pct then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power cd 17"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&cooldown.touch_of_the_magi.remains>variable.rop_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(cooldown.arcane_power.remains>15|debuff.touch_of_the_magi.up)
  if S.RuneofPower:IsCastable() and not S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and S.TouchoftheMagi:CooldownRemains() > var_rop_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (S.ArcanePower:CooldownRemains() > 15 or Target:DebuffRemains(S.TouchoftheMagi) > S.RuneofPower:CastTime() + Player:GCDRemains()) then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 18"; end
  end
  --presence_of_mind,if=buff.arcane_charge.stack=0&covenant.kyrian.enabled
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and Player:Covenant() == "Kyrian" and Player:ArcaneCharges() == 0 then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cd 19"; end
  end
  --presence_of_mind,if=debuff.touch_of_the_magi.up&!covenant.kyrian.enabled
  if S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) and Player:Covenant() ~= "Kyrian" and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind cd 20"; end
  end
end

local function Aoe ()
  --frostbolt,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&(buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  --NYI legendaries
  --fire_blast,if=(runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down&prev_gcd.1.frostbolt)|(runeforge.disciplinary_command.equipped&time=0)
  --NYI legendaries
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains>30&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  --NYI legendaries
  --frost_nova,if=runeforge.grisly_icicle.equipped&cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  --NYI legendaries
  --touch_of_the_magi,if=runeforge.siphon_storm.equipped&prev_gcd.1.evocation
  --NYI legendaries
  --arcane_power,if=runeforge.siphon_storm.equipped&(prev_gcd.1.evocation|prev_gcd.1.touch_of_the_magi)
  --NYI legendaries
  --evocation,if=time>30&runeforge.siphon_storm.equipped&buff.arcane_charge.stack<=variable.aoe_totm_max_charges&cooldown.touch_of_the_magi.remains=0&cooldown.arcane_power.remains<=gcd
  --NYI legendaries
  --evocation,if=time>30&runeforge.siphon_storm.equipped&cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down),interrupt_if=buff.siphon_storm.stack=buff.siphon_storm.max_stack,interrupt_immediate=1
  --NYI legendaries
  --mirrors_of_torment,if=(cooldown.arcane_power.remains>45|cooldown.arcane_power.remains<=3)&cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>5)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>5)|cooldown.arcane_power.remains<=gcd))
  if S.MirrorsofTorment:IsCastable() and (Player:BuffRemains(S.ArcanePower) > 45 or Player:BuffRemains(S.ArcanePower) <= 3) and Target:DebuffRemains(S.TouchoftheMagi) == 0 and (Player:ArcaneCharges() <= var_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > 5) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > 5) or (Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains()))) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment aoe 9"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains>variable.rs_max_delay&cooldown.arcane_power.remains>variable.rs_max_delay&(talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd|talent.rune_of_power.enabled&cooldown.rune_of_power.remains>variable.rs_max_delay|!talent.rune_of_power.enabled)&buff.arcane_charge.stack<=variable.aoe_totm_max_charges&debuff.touch_of_the_magi.down
  if S.RadiantSpark:IsCastable() and Target:DebuffRemains(S.TouchoftheMagi) > var_rs_max_delay and S.ArcanePower:CooldownRemains() > var_rs_max_delay and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains()) or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > var_rs_max_delay) or (not S.RuneofPower:IsAvailable())) and Player:ArcaneCharges() <= var_totm_max_charges and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark aoe 10"; end
  end
  --radiant_spark,if=cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd))
  if S.RadiantSpark:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and (Player:ArcaneCharges() <= var_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains())) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark aoe 11"; end
  end
  --radiant_spark,if=cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  if S.RadiantSpark:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark aoe 12"; end
  end
  --deathborne,if=cooldown.arcane_power.remains=0&(((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down)
  if S.Deathborne:IsCastable() and S.ArcanePower:CooldownRemains() == 0 and (((Target:DebuffRemains(S.TouchoftheMagi) > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (Target:DebuffRemains(S.TouchoftheMagi) == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne aoe 13"; end
  end
  --touch_of_the_magi,if=buff.arcane_charge.stack<=variable.aoe_totm_max_charges&((talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay)|(!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)|cooldown.arcane_power.remains<=gcd)
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ArcaneCharges() <= var_totm_max_charges and ((S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or (not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay) or S.ArcanePower:CooldownRemains() <= Player:GCDRemains()) then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi aoe 14"; end
  end
  --arcane_power,if=((cooldown.touch_of_the_magi.remains>variable.ap_max_delay&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&buff.rune_of_power.down
  if HR.CDsON() and S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power aoe 15"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&((cooldown.touch_of_the_magi.remains>20&buff.arcane_charge.stack=buff.arcane_charge.max_stack)|(cooldown.touch_of_the_magi.remains=0&buff.arcane_charge.stack<=variable.aoe_totm_max_charges))&(cooldown.arcane_power.remains>15|debuff.touch_of_the_magi.up)
  if HR.CDsON() and S.RuneofPower:IsCastable() and not S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and ((S.TouchoftheMagi:CooldownRemains() > 20 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) or (S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() <= var_totm_max_charges)) and (S.ArcanePower:CooldownRemains() or Target:DebuffUp(S.TouchoftheMagi)) then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power aoe 16"; end
  end
  --presence_of_mind,if=buff.deathborne.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
  if HR.CDsON() and S.PresenceofMind:IsCastable() and Player:DebuffDown(S.PresenceofMind) and Player:BuffUp(S.Deathborne) and Target:DebuffUp(S.TouchoftheMagi) and S.TouchoftheMagi:CooldownRemains() <= (2 * S.ArcaneBlast:ExecuteTime()) + Player:GCDRemains() then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind aoe 17"; end
  end
  --arcane_blast,if=buff.deathborne.up&((talent.resonance.enabled&active_enemies<4)|active_enemies<5)
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.Deathborne) and ((S.Resonance:IsAvailable() and EnemiesCount8ySplash < 4) or EnemiesCount8ySplash < 5) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 18"; end
  end
  --supernova
  if S.Supernova:IsCastable() then
    if HR.Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova aoe 19"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack=0
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= 0 then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb aoe 20"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest aoe 21"; end
  end
  --shifting_power,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&cooldown.arcane_power.remains>0&cooldown.touch_of_the_magi.remains>0&(!talent.rune_of_power.enabled|(talent.rune_of_power.enabled&cooldown.rune_of_power.remains>0))
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and S.ArcanePower:CooldownRemains() > 0 and S.TouchoftheMagi:CooldownRemains() > 0 and (not S.RuneofPower:IsAvailable() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > 0)) then
    if HR.Cast(S.ShiftingPower, nil, nil, not Target:IsSpellInRange(S.ShiftingPower)) then return "shifting_power aoe 22"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&runeforge.arcane_infinity.equipped&talent.amplification.enabled&active_enemies<9
  --NYI legendaries
  --arcane_missiles,if=buff.clearcasting.react&runeforge.arcane_infinity.equipped&active_enemies<6
  --NYI legendaries
  --arcane_explosion,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneExplosion:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if HR.Cast(S.Evocation) then return "arcane_explosion aoe 25"; end
  end
  --arcane_explosion,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&prev_gcd.1.arcane_barrage
  if S.ArcaneExplosion:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:IsCasting(S.ArcaneBarrage) then
    if HR.Cast(S.Evocation) then return "arcane_explosion aoe 26"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe 27"; end
  end
  --evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 85 then
    if HR.Cast(S.Evocation) then return "evocation aoe 28"; end
  end
end

local function Opener ()
  if not ArcaneOpener:On() then
    ArcaneOpener:StartOpener()
    return "Start opener"
  end
  --variable,name=have_opened,op=set,value=1,if=prev_gcd.1.evocation
  if Player:IsChanneling(S.Evocation) and ArcaneOpener:On() then
    ArcaneOpener:StopOpener()
    return "Stop opener 1"
  end
  --fire_blast,if=runeforge.disciplinary_command.equipped&buff.disciplinary_command_frost.up
  -- NYI legendaries
  --frost_nova,if=runeforge.grisly_icicle.equipped&mana.pct>95
  -- NYI legendaries
  --mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment opener 3"; end
  end
  --deathborne
  if S.Deathborne:IsCastable() then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne opener 4"; end
  end
  --radiant_spark,if=mana.pct>40
  if S.RadiantSpark:IsCastable() and Player:ManaPercentage() > 40 then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle) then return "radiant_spark opener 5"; end
  end
  --cancel_action,if=action.shifting_power.channeling&gcd.remains=0
  --shifting_power,if=soulbind.field_of_blossoms.enabled
  --NYI soulbind
  --touch_of_the_magi
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and Player:ManaPercentage() > 15 then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi opener 8"; end
  end
  --arcane_power
  if HR.CDsON() and S.ArcanePower:IsCastable() then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power opener 9"; end
  end
  --rune_of_power,if=buff.rune_of_power.down
  if HR.CDsON() and S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and not S.ArcanePower:IsCastable() then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power opener 10"; end
  end
  --presence_of_mind
  if HR.CDsON() and S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) then
    if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind opener 11"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparlVulnerability) > 0) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 12"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=action.arcane_blast.execute_time
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= S.ArcaneBlast:ExecuteTime() + Player:GCDRemains() then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 13"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 14"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo.enabled&buff.deathborne.down&debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time&(!azerite.arcane_pummeling.enabled|buff.clearcasting_channel.down),chain=1
  --todo : manage arcane_pummeling
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and Player:BuffDown(S.Deathborne) and Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() + Player:GCDRemains() then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 15"; end
  end
  --arcane_missiles,if=buff.clearcasting.react,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles opener 16"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges&(cooldown.arcane_power.remains>10|active_enemies<=2)
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges and (Player:BuffRemains(S.ArcanePower) > 10 or EnemiesCount16ySplash <= 2) then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb opener 17"; end
  end
  --arcane_blast,if=buff.rune_of_power.up|mana.pct>15
  if S.ArcaneBlast:IsCastable() and (Player:BuffUp(S.RuneofPowerBuff) or Player:ManaPercentage() > 15) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast opener 18"; end
  end
  --evocation,if=buff.rune_of_power.down,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:ManaPercentage() < 85 then
    if HR.Cast(S.Evocation) then return "evocation opener 19"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage opener 20"; end
  end
end

local function Rotation ()
  --variable,name=final_burn,op=set,value=1,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&!buff.rule_of_threes.up&fight_remains<=((mana%action.arcane_blast.cost)*action.arcane_blast.execute_time)
  if Player:ArcaneCharges() == Player:ArcaneChargesMax() and not Player:BuffUp(S.RuleofThreesBuff) and HL.BossFilteredFightRemains("<=", (((Player:Mana() / S.ArcaneBlast:Cost()) * S.ArcaneBlast:ExecuteTime()) + Player:GCDRemains())) then
    ArcaneOpener:StartFinalBurn()
    return "Start final burn"
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack>variable.totm_max_charges&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay&covenant.kyrian.enabled&cooldown.radiant_spark.remains<=8)
  if S.ArcaneBarrage:IsCastable() and Player:Covenant() == "Kyrian" and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay and S.RadiantSpark.CooldownRemains() <= 8 then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 1"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack>variable.totm_max_charges&talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=gcd&cooldown.arcane_power.remains>variable.totm_max_delay&!covenant.kyrian.enabled)
  if S.ArcaneBarrage:IsCastable() and Player:Covenant() ~= "Kyrian" and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= Player:GCDRemains() and S.ArcanePower:CooldownRemains() > var_totm_max_delay then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 2"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack>variable.totm_max_charges&!talent.rune_of_power.enabled&cooldown.arcane_power.remains>variable.totm_max_delay)
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and not S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemains() > var_totm_max_delay then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 3"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.remains=0&(buff.arcane_charge.stack>variable.totm_max_charges&cooldown.arcane_power.remains<=gcd)
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and Player:ArcaneCharges() > var_totm_max_charges and S.ArcanePower:CooldownRemains() <= Player:GCDRemains() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 4"; end
  end
  --strict_sequence,if=debuff.radiant_spark_vulnerability.stack=debuff.radiant_spark_vulnerability.max_stack&buff.arcane_power.down&buff.rune_of_power.down,name=last_spark_stack:arcane_blast:arcane_barrage
  --TODO : manage strict_sequence, debuff.radiant_spark_vulnerability.max_stack
  --arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=debuff.radiant_spark_vulnerability.max_stack&(buff.arcane_power.down|buff.arcane_power.remains<=gcd)&(buff.rune_of_power.down|buff.rune_of_power.remains<=gcd)
  --TODO : manage debuff.radiant_spark_vulnerability.max_stack
  if S.ArcaneBarrage:IsCastable() and Target:DebuffStack(S.RadiantSparlVulnerability) == 4 and (Player:BuffDown(S.ArcanePower) or Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains()) and (Player:BuffDown(S.RuneofPowerBuff) or Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains()) then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 7"; end
  end
  --arcane_blast,if=dot.radiant_spark.remains>5|debuff.radiant_spark_vulnerability.stack>0
  if S.ArcaneBlast:IsCastable() and (Target:DebuffRemains(S.RadiantSpark) > 5 or Target:DebuffStack(S.RadiantSparlVulnerability) > 0) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 8"; end
  end
  --arcane_blast,if=buff.presence_of_mind.up&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=action.arcane_blast.execute_time
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.PresenceofMind) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) < (S.ArcaneBlast:ExecuteTime() + Player:GCDRemains()) then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 9"; end
  end
  --arcane_missiles,if=debuff.touch_of_the_magi.up&talent.arcane_echo.enabled&buff.deathborne.down&(debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time|cooldown.presence_of_mind.remains>0|covenant.kyrian.enabled)&(!azerite.arcane_pummeling.enabled|buff.clearcasting_channel.down),chain=1
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and Player:BuffDown(S.Deathborne) and (Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() or S.PresenceofMind:CooldownRemains() > 0 or Player:Covenant() == "Kyrian") and (S.ArcanePummeling:AzeriteRank() > 0 or Player:BuffUp(S.ClearcastingBuff)) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 10"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.expanded_potential.up
  -- NYI legendaries
  --arcane_missiles,if=buff.clearcasting.react&(buff.arcane_power.up|buff.rune_of_power.up|debuff.touch_of_the_magi.remains>action.arcane_missiles.execute_time),chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and (Player:BuffUp(S.ArcanePower) or Player:BuffUp(S.RuneofPowerBuff) or Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime()) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 12"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 13"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.remains<=((buff.clearcasting.stack*action.arcane_missiles.execute_time)+gcd),chain=1
  if S.ArcaneMissiles:IsCastable() and Target:DebuffUp(S.TouchoftheMagi) and S.ArcaneEcho:IsAvailable() and Player:BuffDown(S.Deathborne) and (Target:DebuffRemains(S.TouchoftheMagi) > S.ArcaneMissiles:ExecuteTime() or S.PresenceofMind:CooldownRemains() > 0 or Player:Covenant() == "Kyrian") then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 14"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.NetherTempest:IsCastable() and Target:DebuffRefreshable(S.NetherTempest) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 15"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<=variable.totm_max_charges
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() <= var_totm_max_charges then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb rotation 16"; end
  end
  --supernova,if=mana.pct<=95&buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
  if S.Supernova:IsCastable() and Player:ManaPercentage() <= 95 and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova rotation 17"; end
  end
  --shifting_power,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>0&cooldown.arcane_power.remains>0&cooldown.touch_of_the_magi.remains>0&(!talent.rune_of_power.enabled|(talent.rune_of_power.enabled&cooldown.rune_of_power.remains>0))
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and S.Evocation:CooldownRemains() > 0 and S.ArcanePower:CooldownRemains() > 0 and S.TouchoftheMagi:CooldownRemains() > 0 and (not S.RuneofPower:IsAvailable() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() > 0)) then
    if HR.Cast(S.ShiftingPower, nil, nil, not Target:IsSpellInRange(S.ShiftingPower)) then return "shifting_power rotation 18"; end
  end
  --arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
  if S.ArcaneBlast:IsCastable() and Player:BuffUp(S.RuleofThreesBuff) and Player:ArcaneCharges() > 3 then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 19"; end
  end
  --arcane_barrage,if=mana.pct<variable.barrage_mana_pct&cooldown.evocation.remains>0&buff.arcane_power.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&essence.vision_of_perfection.minor
  if S.ArcaneBarrage:IsCastable() and Player:ManaPercentage() < var_barrage_mana_pct and S.Evocation:CooldownRemains() > 0 and Player:BuffDown(S.ArcanePower) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Spell:EssenceEnabled(AE.VisionofPerfection) then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 20"; end
  end
  --arcane_barrage,if=cooldown.touch_of_the_magi.remains=0&(cooldown.rune_of_power.remains=0|cooldown.arcane_power.remains=0)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and S.TouchoftheMagi:CooldownRemains() == 0 and (S.RuneofPower:CooldownRemains() == 0 or S.ArcanePower:CooldownRemains() == 0) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 21"; end
  end
  --arcane_barrage,if=mana.pct<=variable.barrage_mana_pct&buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&cooldown.evocation.remains>0
  if S.ArcaneBarrage:IsCastable() and Player:ManaPercentage() < var_barrage_mana_pct and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.Evocation:CooldownRemains() > 0 then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 22"; end
  end
  --arcane_barrage,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd&mana.pct<=90&cooldown.evocation.remains>0
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() <= Player:GCDRemains() and Player:ManaPercentage() <= 90 and S.Evocation:CooldownRemains() > 0 then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 23"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 24"; end
  end
  --arcane_barrage,if=buff.rune_of_power.up&buff.rune_of_power.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.RuneofPowerBuff) and Player:BuffRemains(S.RuneofPowerBuff) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 25"; end
  end
  --arcane_barrage,if=buff.arcane_power.down&buff.rune_of_power.down&debuff.touch_of_the_magi.up&debuff.touch_of_the_magi.remains<=gcd&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.ArcanePower) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffUp(S.TouchoftheMagi) and Target:DebuffRemains(S.TouchoftheMagi) <= Player:GCDRemains() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 26"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable() then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 27"; end
  end
  --evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastable() and Player:ManaPercentage() < 85 then
    if HR.Cast(S.Evocation) then return "evocation rotation 28"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 29"; end
  end
end

local function Final_burn ()
  --arcane_missiles,if=buff.clearcasting.react,chain=1
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
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

local function AMSpam ()
  --cancel_action,if=action.evocation.channeling&mana.pct>=95
  --evocation,if=mana.pct<=variable.am_spam_evo_pct
  --&(cooldown.touch_of_the_magi.remains<=action.evocation.execute_time|cooldown.arcane_power.remains<=action.evocation.execute_time|(talent.rune_of_power.enabled&cooldown.rune_of_power.remains<=action.evocation.execute_time))
  --&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.Evocation:IsCastable() and ((Player:IsCasting(S.Evocation) and Player:ManaPercentage() <= 95) 
  or (not Player:IsCasting(S.Evocation) and (Player:ManaPercentage() <= var_am_spam_evo_pct 
  and (S.TouchoftheMagi:CooldownRemains() <= S.Evocation:ExecuteTime() or S.ArcanePower:CooldownRemains() <= S.Evocation:ExecuteTime() or (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() <= S.Evocation:ExecuteTime()))
  and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi)))) then
    if HR.Cast(S.Evocation) then return "evocation AMSpam 1-2"; end
  end
  --rune_of_power,if=buff.rune_of_power.down&cooldown.arcane_power.remains>0
  if HR.CDsON() and S.RuneofPower:IsCastable() and not S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and S.ArcanePower:CooldownRemains() > 0 then
    if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power AMSpam 3"; end
  end
  --touch_of_the_magi,if=(cooldown.arcane_power.remains=0&buff.rune_of_power.down)|prev_gcd.1.rune_of_power
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi) and (Player:IsCasting(S.RuneofPower) or (not Player:IsCasting() and Player:PrevGCD(1,S.RuneOfPower))) 
  and S.ArcanePower:CooldownRemains() == 0 and Player:BuffDown(S.RuneofPowerBuff) then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi AMSpam 4"; end
  end
  --touch_of_the_magi,if=cooldown.arcane_power.remains<50&buff.rune_of_power.down&essence.vision_of_perfection.enabled
  if S.TouchoftheMagi:IsCastable() and not Player:IsCasting(S.TouchoftheMagi)
  and S.ArcanePower:CooldownRemains() < 50 and Player:BuffDown(S.RuneofPowerBuff) and Spell:EssenceEnabled(AE.VisionofPerfection) then
    if HR.Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchoftheMagi) then return "touch_of_the_magi AMSpam 5"; end
  end
  --arcane_power,if=buff.rune_of_power.down&cooldown.touch_of_the_magi.remains>variable.ap_max_delay
  if HR.CDsON() and S.ArcanePower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and S.TouchoftheMagi:CooldownRemains() > var_ap_max_delay then
    if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power AMSpam 6"; end
  end
  --arcane_barrage,if=buff.arcane_power.up&buff.arcane_power.remains<=action.arcane_missiles.execute_time&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffUp(S.ArcanePower) and Player:BuffRemains(S.ArcanePower) <= S.ArcaneMissiles:ExecuteTime() and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage AMSpam 7"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb AMSpam 8"; end
  end
  --arcane_barrage,if=buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) and Player:ArcaneCharges() == Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage AMSpam 9"; end
  end
  --arcane_missiles,if=buff.clearcasting.react,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|buff.rune_of_power.up|cooldown.evocation.ready)
  --TODO : early_chain_if
  if S.ArcaneMissiles:IsCastable() and Player:BuffUp(S.ClearcastingBuff) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles AMSpam 10"; end
  end
  --arcane_missiles,if=!azerite.arcane_pummeling.enabled|buff.clearcasting_channel.down,chain=1,early_chain_if=buff.clearcasting_channel.down&(buff.arcane_power.up|buff.rune_of_power.up|cooldown.evocation.ready)
  --TODO : early_chain_if
  if S.ArcaneMissiles:IsCastable() and S.ArcanePummeling:AzeriteRank() == 0 or Player:BuffDown(S.ClearcastingBuff) then
    if HR.Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles AMSpam 11"; end
  end
  --evocation,if=buff.rune_of_power.down&buff.arcane_power.down&debuff.touch_of_the_magi.down
  if S.Evocation:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.ArcanePower) and Target:DebuffDown(S.TouchoftheMagi) then
    if HR.Cast(S.Evocation) then return "evocation AMSpam 12"; end
  end
  --arcane_orb,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneOrb:IsCastable() and Player:ArcaneCharges() < Player:ArcaneChargesMax() then
    if HR.Cast(S.ArcaneOrb) then return "arcane_orb AMSpam 13"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable()  then
    if HR.Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage AMSpam 14"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsCastable() then
    if HR.Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 15"; end
  end
end

local function Movement ()
  --shimmer,if=movement.distance>=10
  --presence_of_mind
  --arcane_missiles,if=movement.distance<10
  --arcane_orb
  --fire_blast
  -- blink_any,if=movement.distance>=10
  if S.Blink:IsCastable() and (not Target:IsInRange(S.ArcaneBlast:MaximumRange())) then
    if HR.Cast(S.Blink) then return "blink_any 501"; end
  end
  -- presence_of_mind
  if HR.CDsON() and S.PresenceofMind:IsCastable() and Player:BuffDown(S.PresenceofMind) then
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
    --counterspell,if=target.debuff.casting.react
    --ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    --call_action_list,name=shared_cds
    if HR.CDsON() then
      ShouldReturn = SharedCds(); if ShouldReturn then return ShouldReturn; end
    end
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
    --call_action_list,name=am_spam,if=variable.am_spam=1
    if Settings.Arcane.AMSpamRotation then
      ShouldReturn = AMSpam(); if ShouldReturn then return ShouldReturn; end
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

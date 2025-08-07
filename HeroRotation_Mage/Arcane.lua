--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC               = HeroDBC.DBC
-- HeroLib
local HL                = HeroLib
local Unit              = HL.Unit
local Player            = Unit.Player
local Target            = Unit.Target
local Spell             = HL.Spell
local Item              = HL.Item
-- HeroRotation
local HR                = HeroRotation
local Mage              = HR.Commons.Mage
local Cast              = HR.Cast
local CastAnnotated     = HR.CastAnnotated
local CastLeft          = HR.CastLeft
local CDsON             = HR.CDsON
local AoEON             = HR.AoEON
-- Num/Bool Helper Functions
local num               = HR.Commons.Everyone.num
local bool              = HR.Commons.Everyone.bool
-- lua
local mathmax           = math.max
local mathmin           = math.min
-- WoW API
local Delay             = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Arcane
local I = Item.Mage.Arcane

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.HighSpeakersAccretion:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.NeuralSynapseEnhancer:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  CommonsDS = HR.GUISettings.APL.Mage.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Mage.CommonsOGCD,
  Arcane = HR.GUISettings.APL.Mage.Arcane
}

--- ===== InFlight Registrations =====
S.ArcaneBlast:RegisterInFlight()
S.ArcaneBarrage:RegisterInFlight()

--- ===== Rotation Variables =====
local VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
local VarOpener = true
local VarAoEList = false
local Enemies8ySplash, EnemiesCount8ySplash
local ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
local LastSSAM = 0
local LastSFAM = 0
local BossFightRemains = 11111
local FightRemains = 11111
local CastAE

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarSteroidTrinketEquipped = false
local VarNeuralOnMini = false
local VarNonsteroidTrinketEquipped = false
local VarSpymastersDoubleOnUse = false
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.treacherous_transmitter|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.signet_of_the_priory|equipped.neural_synapse_enhancer
  VarSteroidTrinketEquipped = Player:GladiatorsBadgeIsEquipped() or I.SignetOfThePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.FunhouseLens:IsEquipped() or I.HouseOfCards:IsEquipped() or I.FlarendosPilotLight:IsEquipped() or I.NeuralSynapseEnhancer:IsEquipped()
  -- variable,name=neural_on_mini,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.treacherous_transmitter|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.signet_of_the_priory
  VarNeuralOnMini = Player:GladiatorsBadgeIsEquipped() or I.SignetOfThePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.FunhouseLens:IsEquipped() or I.HouseOfCards:IsEquipped() or I.FlarendosPilotLight:IsEquipped()
  -- variable,name=nonsteroid_trinket_equipped,op=set,value=equipped.blastmaster3000|equipped.ratfang_toxin|equipped.ingenious_mana_battery|equipped.geargrinders_spare_keys|equipped.ringing_ritual_mud|equipped.goo_blin_grenade|equipped.noggenfogger_ultimate_deluxe|equipped.garbagemancers_last_resort|equipped.mad_queens_mandate|equipped.fearbreakers_echo|equipped.mereldars_toll|equipped.gooblin_grenade
  VarNonsteroidTrinketEquipped = I.Blastmaster3000:IsEquipped() or I.RatfangToxin:IsEquipped() or I.IngeniousManaBattery:IsEquipped() or I.GeargrindersSpareKeys:IsEquipped() or I.RingingRitualMud:IsEquipped() or I.GooBlinGrenade:IsEquipped() or I.NoggenfoggerUltimateDeluxe:IsEquipped() or I.GarbagemancersLastResort:IsEquipped() or I.MadQueensMandate:IsEquipped() or I.FearbreakersEcho:IsEquipped() or I.MereldarsToll:IsEquipped()
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
  VarOpener = true
  VarAoEList = false
  LastSSAM = 0
  LastSFAM = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
  ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== Rotation Functions =====
local function Precombat()
  -- arcane_intellect
  -- Note: Moved to top of APL()
  -- variable,name=aoe_target_count,op=reset,default=2
  -- variable,name=aoe_target_count,op=set,value=9,if=!talent.arcing_cleave
  -- variable,name=opener,op=set,value=1
  -- variable,name=aoe_list,default=0,op=reset
  -- Note: Moved to variable declarations and Event Registrations to avoid potential nil errors.
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.treacherous_transmitter|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.signet_of_the_priory|equipped.neural_synapse_enhancer
  -- variable,name=neural_on_mini,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.treacherous_transmitter|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.signet_of_the_priory
  -- variable,name=nonsteroid_trinket_equipped,op=set,value=equipped.blastmaster3000|equipped.ratfang_toxin|equipped.ingenious_mana_battery|equipped.geargrinders_spare_keys|equipped.ringing_ritual_mud|equipped.goo_blin_grenade|equipped.noggenfogger_ultimate_deluxe|equipped.garbagemancers_last_resort|equipped.mad_queens_mandate|equipped.fearbreakers_echo|equipped.mereldars_toll|equipped.gooblin_grenade
  -- Note: Moved to SetTrinketVariables().
  -- snapshot_stats
  -- use_item,name=ingenious_mana_battery,target=self
  if I.IngeniousManaBattery:IsEquippedAndReady() then
    if Cast(I.IngeniousManaBattery, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "ingenious_mana_battery precombat 2"; end
  end
  -- variable,name=treacherous_transmitter_precombat_cast,value=11
  -- Note: Can't utilize this in HR.
  -- use_item,name=treacherous_transmitter
  if I.TreacherousTransmitter:IsEquippedAndReady() then
    if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat 4"; end
  end
  -- mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 6"; end
  end
  -- use_item,name=imperfect_ascendancy_serum
  if I.ImperfectAscendancySerum:IsEquippedAndReady() then
    if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum precombat 8"; end
  end
  -- arcane_blast,if=!talent.evocation
  if S.ArcaneBlast:IsReady() and (not S.Evocation:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 10"; end
  end
  -- evocation,if=talent.evocation
  if S.Evocation:IsReady() then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation precombat 12"; end
  end
end

local function CDOpener()
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage&(action.arcane_barrage.in_flight_remains<=0.5|gcd.remains<=0.5)&(buff.arcane_surge.up|cooldown.arcane_surge.remains>30)|(prev_gcd.1.arcane_surge&(buff.arcane_charge.stack<4|buff.nether_precision.down))|(cooldown.arcane_surge.remains>30&cooldown.touch_of_the_magi.ready&buff.arcane_charge.stack<4&!prev_gcd.1.arcane_barrage)
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage) and (S.ArcaneBarrage:InFlightRemains() <= 0.5 or Player:GCDRemains() <= 0.5) and (Player:BuffUp(S.ArcaneSurgeBuff) or S.ArcaneSurge:CooldownRemains() > 30) or (Player:PrevGCDP(1, S.ArcaneSurge) and (Player:ArcaneCharges() < 4 or Player:BuffDown(S.NetherPrecisionBuff))) or (S.ArcaneSurge:CooldownRemains() > 30 and S.TouchoftheMagi:CooldownUp() and Player:ArcaneCharges() < 4 and not Player:PrevGCDP(1, S.ArcaneBarrage))) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi, nil, not Target:IsSpellInRange(S.TouchoftheMagi)) then return "touch_of_the_magi cd_opener 2"; end
  end
  -- wait,sec=0.05,if=prev_gcd.1.arcane_surge&time-action.touch_of_the_magi.last_used<0.015,line_cd=15
  -- arcane_blast,if=buff.presence_of_mind.up
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cd_opener 4"; end
  end
  -- arcane_orb,if=talent.high_voltage&variable.opener,line_cd=10
  if S.ArcaneOrb:IsReady() and S.ArcaneOrb:TimeSinceLastCast() >= 10 and (S.HighVoltage:IsAvailable() and VarOpener) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb cd_opener 6"; end
  end
  -- arcane_barrage,if=buff.arcane_tempo.up&cooldown.evocation.ready&buff.arcane_tempo.remains<gcd.max*5,line_cd=11
  if S.ArcaneBarrage:IsReady() and S.ArcaneBarrage:TimeSinceLastCast() >= 11 and (Player:BuffUp(S.ArcaneTempoBuff) and S.Evocation:CooldownUp() and Player:BuffRemains(S.ArcaneTempoBuff) < Player:GCD() * 5) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsInRange(8)) then return "arcane_barrage cd_opener 8"; end
  end
  -- evocation,if=cooldown.arcane_surge.remains<(gcd.max*3)&cooldown.touch_of_the_magi.remains<(gcd.max*5)
  if S.Evocation:IsCastable() and (S.ArcaneSurge:CooldownRemains() < (Player:GCD() * 3) and S.TouchoftheMagi:CooldownRemains() < (Player:GCD() * 5)) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation cd_opener 10"; end
  end
  -- arcane_missiles,if=((prev_gcd.1.evocation|prev_gcd.1.arcane_surge)|variable.opener)&buff.nether_precision.down&(buff.aether_attunement.react=0|set_bonus.thewarwithin_season_2_4pc),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1,line_cd=30
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and (Player:BuffDown(S.AetherAttunementBuff) or (EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable())))) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt cd_opener 12"; end
  end
  if S.ArcaneMissiles:IsReady() and S.ArcaneMissiles:TimeSinceLastCast() >= 30 and (((Player:PrevGCDP(1, S.Evocation) or Player:PrevGCDP(1, S.ArcaneSurge)) or VarOpener) and Player:BuffDown(S.NetherPrecisionBuff) and (Player:BuffDown(S.AetherAttunementBuff) or Player:HasTier("TWW2", 4))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cd_opener 14"; end
  end
  -- arcane_surge,if=cooldown.touch_of_the_magi.remains<(action.arcane_surge.execute_time+(gcd.max*(buff.arcane_charge.stack=4)))
  if S.ArcaneSurge:IsCastable() and (S.TouchoftheMagi:CooldownRemains() < (S.ArcaneSurge:ExecuteTime() + (Player:GCD() * num(Player:ArcaneCharges() == 4)))) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge cd_opener 16"; end
  end
end

local function Spellslinger()
  -- Note: Handle arcane_missiles interrupts.
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (LastSSAM == 1 or LastSSAM == 2) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and (Player:BuffDown(S.AetherAttunementBuff) or (EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable())))) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt spellslinger 2"; end
  end
  -- shifting_power,if=(((((action.arcane_orb.charges=talent.charged_orb)&cooldown.arcane_orb.remains)|cooldown.touch_of_the_magi.remains<23)&buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&(buff.intuition.react=0|(buff.intuition.react&buff.intuition.remains>cast_time))&cooldown.touch_of_the_magi.remains>(12+6*gcd.max))|(prev_gcd.1.arcane_barrage&talent.shifting_shards&(buff.intuition.react=0|(buff.intuition.react&buff.intuition.remains>cast_time))&(buff.arcane_surge.up|debuff.touch_of_the_magi.up|cooldown.evocation.remains<20)))&fight_remains>10&(buff.arcane_tempo.remains>gcd.max*2.5|buff.arcane_tempo.down)
  if S.ShiftingPower:IsReady() and ((((((S.ArcaneOrb:Charges() == num(S.ChargedOrb:IsAvailable())) and S.ArcaneOrb:CooldownDown()) or S.TouchoftheMagi:CooldownRemains() < 23) and Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and (Player:BuffDown(S.IntuitionBuff) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) > S.ShiftingPower:CastTime())) and S.TouchoftheMagi:CooldownRemains() > (12 + 6 * Player:GCD())) or (Player:PrevGCDP(1, S.ArcaneBarrage) and S.ShiftingShards:IsAvailable() and (Player:BuffDown(S.IntuitionBuff) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) > S.ShiftingPower:CastTime())) and (Player:BuffUp(S.ArcaneSurgeBuff) or Target:DebuffUp(S.TouchoftheMagiDebuff) or S.Evocation:CooldownRemains() < 20))) and FightRemains > 10 and (Player:BuffRemains(S.ArcaneTempoBuff) > Player:GCD() * 2.5 or Player:BuffDown(S.ArcaneTempoBuff))) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power spellslinger 4"; end
  end
  -- cancel_buff,name=presence_of_mind,use_off_gcd=1,if=prev_gcd.1.arcane_blast&buff.presence_of_mind.stack=1
  -- TODO: Handle cancel_buff.
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.nether_precision.up&active_enemies<variable.aoe_target_count&!talent.unerring_proficiency
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= Player:GCD() and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash < VarAoETargetCount and not S.UnerringProficiency:IsAvailable()) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind spellslinger 6"; end
  end
  -- wait,sec=0.05,if=time-action.presence_of_mind.last_used<0.015,line_cd=15
  -- supernova,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.unerring_proficiency.stack=30
  if S.Supernova:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= Player:GCD() and Player:BuffStack(S.UnerringProficiencyBuff) == 30) then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova spellslinger 8"; end
  end
  -- arcane_barrage,if=(buff.arcane_tempo.up&buff.arcane_tempo.remains<(gcd.max+(gcd.max*2*(buff.nether_precision.stack=1))))|(buff.intuition.react&buff.intuition.remains<gcd.max)
  if S.ArcaneBarrage:IsCastable() and ((Player:BuffUp(S.ArcaneTempoBuff) and Player:BuffRemains(S.ArcaneTempoBuff) < (Player:GCD() + (Player:GCD() * 2 * num(Player:BuffStack(S.NetherPrecisionBuff) == 1)))) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) < Player:GCD())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 10"; end
  end
  -- arcane_barrage,if=buff.arcane_harmony.stack>=(18-(6*talent.high_voltage))&(buff.nether_precision.down|buff.nether_precision.stack=1|(active_enemies>3&buff.clearcasting.react&talent.high_voltage))
  if S.ArcaneBarrage:IsCastable() and (Player:BuffStack(S.ArcaneHarmonyBuff) >= (18 - (6 * num(S.HighVoltage:IsAvailable()))) and (Player:BuffDown(S.NetherPrecisionBuff) or Player:BuffStack(S.NetherPrecisionBuff) == 1 or (EnemiesCount8ySplash > 3 and Player:BuffUp(S.ClearcastingBuff) and S.HighVoltage:IsAvailable()))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 12"; end
  end
  -- arcane_missiles,if=buff.aether_attunement.react&cooldown.touch_of_the_magi.remains<gcd.max*3&buff.clearcasting.react&set_bonus.thewarwithin_season_2_4pc
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.AetherAttunementBuff) and S.TouchoftheMagi:CooldownRemains() < Player:GCD() * 3 and Player:BuffUp(S.ClearcastingBuff) and Player:HasTier("TWW2", 4)) then
    LastSSAM = 0
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 14"; end
  end
  -- arcane_barrage,if=(cooldown.touch_of_the_magi.ready|cooldown.touch_of_the_magi.remains<((travel_time+50)>?gcd.max))
  -- Note: Replaced ((travel_time+50)>?gcd.max) with just gcd.max, since gcd.max is always going to be less than travel_time+50.
  -- Note: Also removed cooldown.touch_of_the_magi.ready, since that would be equivalent to remains=0, which is less than gcd.max.
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() == 4 and (S.TouchoftheMagi:CooldownRemains() < Player:GCD()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 16"; end
  end
  -- arcane_barrage,if=talent.high_voltage&talent.orb_barrage&buff.arcane_charge.stack>1&buff.clearcasting.react&buff.aether_attunement.react&(buff.nether_precision.stack=1|(buff.nether_precision.up&active_enemies>1)|((buff.nether_precision.up|(buff.clearcasting.react<3&buff.intuition.react=0))&active_enemies>3))
  if S.ArcaneBarrage:IsCastable() and (S.HighVoltage:IsAvailable() and S.OrbBarrage:IsAvailable() and Player:ArcaneCharges() > 1 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.AetherAttunementBuff) and (Player:BuffStack(S.NetherPrecisionBuff) == 1 or (Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash > 1) or ((Player:BuffUp(S.NetherPrecisionBuff) or (Player:BuffStack(S.ClearcastingBuff) < 3 and Player:BuffDown(S.IntuitionBuff))) and EnemiesCount8ySplash > 3))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 18"; end
  end
  -- arcane_missiles,if=(buff.clearcasting.react&buff.nether_precision.down&((cooldown.touch_of_the_magi.remains>gcd.max*7&cooldown.arcane_surge.remains>gcd.max*7)|buff.clearcasting.react>1|!talent.magis_spark|(cooldown.touch_of_the_magi.remains<gcd.max*4&buff.aether_attunement.react=0)|set_bonus.thewarwithin_season_2_4pc))|(fight_remains<5&buff.clearcasting.react),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and ((Player:BuffUp(S.ClearcastingBuff) and Player:BuffDown(S.NetherPrecisionBuff) and ((S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 7 and S.ArcaneSurge:CooldownRemains() > Player:GCD() * 7) or Player:BuffStack(S.ClearcastingBuff) > 1 or not S.MagisSpark:IsAvailable() or (S.TouchoftheMagi:CooldownRemains() < Player:GCD() * 4 and Player:BuffDown(S.AetherAttunementBuff)) or Player:HasTier("TWW2", 4))) or (FightRemains < 5 and Player:BuffUp(S.ClearcastingBuff))) then
    LastSSAM = 1
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 20"; end
  end
  -- arcane_blast,if=((debuff.magis_spark_arcane_blast.up&((debuff.magis_spark_arcane_blast.remains<(cast_time+gcd.max))|active_enemies=1|talent.leydrinker))|buff.leydrinker.up)&buff.arcane_charge.stack=4&!talent.charged_orb&active_enemies<3,line_cd=2
  if S.ArcaneBlast:IsReady() and S.ArcaneBlast:TimeSinceLastCast() >= 2 and (((Target:DebuffUp(S.MagisSparkABDebuff) and ((Target:DebuffRemains(S.MagisSparkABDebuff) < (S.ArcaneBlast:CastTime() + Player:GCD())) or EnemiesCount8ySplash == 1 or S.Leydrinker:IsAvailable())) or Player:BuffUp(S.LeydrinkerBuff)) and Player:ArcaneCharges() == 4 and not S.ChargedOrb:IsAvailable() and EnemiesCount8ySplash < 3) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 22"; end
  end
  -- arcane_barrage,if=talent.orb_barrage&active_enemies>1&(debuff.magis_spark_arcane_blast.down|!talent.magis_spark)&buff.arcane_charge.stack=4&((talent.high_voltage&active_enemies>2)|((cooldown.touch_of_the_magi.remains>gcd.max*6|!talent.magis_spark)|(talent.charged_orb&cooldown.arcane_orb.charges_fractional>1.8)))
  if S.ArcaneBarrage:IsCastable() and (S.OrbBarrage:IsAvailable() and EnemiesCount8ySplash > 1 and (Target:DebuffDown(S.MagisSparkABDebuff) or not S.MagisSpark:IsAvailable()) and Player:ArcaneCharges() == 4 and ((S.HighVoltage:IsAvailable() and EnemiesCount8ySplash > 2) or ((S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 or not S.MagisSpark:IsAvailable()) or (S.ChargedOrb:IsAvailable() and S.ArcaneOrb:ChargesFractional() > 1.8)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 24"; end
  end
  -- arcane_barrage,if=active_enemies>1&(debuff.magis_spark_arcane_blast.down|!talent.magis_spark)&buff.arcane_charge.stack=4&(cooldown.arcane_orb.remains<gcd.max|(target.health.pct<35&talent.arcane_bombardment))&(buff.nether_precision.stack=1|(buff.nether_precision.down&talent.high_voltage)|(buff.nether_precision.stack=2&target.health.pct<35&talent.arcane_bombardment&talent.high_voltage))&(cooldown.touch_of_the_magi.remains>gcd.max*6|(talent.charged_orb&cooldown.arcane_orb.charges_fractional>1.8))
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash > 1 and (Target:DebuffDown(S.MagisSparkABDebuff) or not S.MagisSpark:IsAvailable()) and Player:ArcaneCharges() == 4 and (S.ArcaneOrb:CooldownRemains() < Player:GCD() or (Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable())) and (Player:BuffStack(S.NetherPrecisionBuff) == 1 or (Player:BuffDown(S.NetherPrecisionBuff) and S.HighVoltage:IsAvailable()) or (Player:BuffStack(S.NetherPrecisionBuff) == 2 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and S.HighVoltage:IsAvailable())) and (S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 or (S.ChargedOrb:IsAvailable() and S.ArcaneOrb:ChargesFractional() > 1.8))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 26"; end
  end
  -- arcane_missiles,if=talent.high_voltage&(buff.clearcasting.react>1|(buff.clearcasting.react&buff.aether_attunement.react))&buff.arcane_charge.stack<3,interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (S.HighVoltage:IsAvailable() and (Player:BuffStack(S.ClearcastingBuff) > 1 or (Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.AetherAttunementBuff))) and Player:ArcaneCharges() < 3) then
    LastSSAM = 2
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 28"; end
  end
  -- arcane_orb,if=(active_enemies=1&buff.arcane_charge.stack<3)|(buff.arcane_charge.stack<1|(buff.arcane_charge.stack<2&talent.high_voltage))
  if S.ArcaneOrb:IsReady() and ((EnemiesCount8ySplash == 1 and Player:ArcaneCharges() < 3) or (Player:ArcaneCharges() < 1 or (Player:ArcaneCharges() < 2 and S.HighVoltage:IsAvailable()))) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger 30"; end
  end
  -- arcane_barrage,if=buff.intuition.react
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 32"; end
  end
  -- arcane_barrage,if=active_enemies=1&talent.high_voltage&buff.arcane_charge.stack=4&buff.clearcasting.react&buff.nether_precision.stack=1&(buff.aether_attunement.react|(target.health.pct<35&talent.arcane_bombardment))
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash == 1 and S.HighVoltage:IsAvailable() and Player:ArcaneCharges() == 4 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.NetherPrecisionBuff) == 1 and (Player:BuffUp(S.AetherAttunementBuff) or (Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable()))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 34"; end
  end
  -- arcane_barrage,if=cooldown.arcane_orb.remains<gcd.max&buff.arcane_charge.stack=4&buff.nether_precision.down&talent.orb_barrage&(cooldown.touch_of_the_magi.remains>gcd.max*6|!talent.magis_spark)
  if S.ArcaneBarrage:IsCastable() and (S.ArcaneOrb:CooldownRemains() < Player:GCD() and Player:ArcaneCharges() == 4 and Player:BuffDown(S.NetherPrecisionBuff) and S.OrbBarrage:IsAvailable() and (S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 or not S.MagisSpark:IsAvailable())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 36"; end
  end
  -- arcane_barrage,if=active_enemies=1&(talent.orb_barrage|(target.health.pct<35&talent.arcane_bombardment))&(cooldown.arcane_orb.remains<gcd.max)&buff.arcane_charge.stack=4&(cooldown.touch_of_the_magi.remains>gcd.max*6|!talent.magis_spark)&(buff.nether_precision.down|(buff.nether_precision.stack=1&buff.clearcasting.stack=0))
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash == 1 and (S.OrbBarrage:IsAvailable() or (Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable())) and (S.ArcaneOrb:CooldownRemains() < Player:GCD()) and Player:ArcaneCharges() == 4 and (S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 or not S.MagisSpark:IsAvailable()) and (Player:BuffDown(S.NetherPrecisionBuff) or (Player:BuffStack(S.NetherPrecisionBuff) == 1 and Player:BuffDown(S.ClearcastingBuff)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 38"; end
  end
  -- arcane_explosion,if=active_enemies>1&((buff.arcane_charge.stack<1&!talent.high_voltage)|(buff.arcane_charge.stack<3&(buff.clearcasting.react=0|talent.reverberate)))
  if S.ArcaneExplosion:IsReady() and (EnemiesCount8ySplash > 1 and ((Player:ArcaneCharges() < 1 and not S.HighVoltage:IsAvailable()) or (Player:ArcaneCharges() < 3 and (Player:BuffDown(S.ClearcastingBuff) or S.Reverberate:IsAvailable())))) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion spellslinger 40"; end
  end
  -- arcane_explosion,if=active_enemies=1&buff.arcane_charge.stack<2&buff.clearcasting.react=0&mana.pct>10
  if S.ArcaneExplosion:IsReady() and (EnemiesCount8ySplash == 1 and Player:ArcaneCharges() < 2 and Player:BuffDown(S.ClearcastingBuff) and Player:ManaPercentage() > 10) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion spellslinger 42"; end
  end
  -- arcane_barrage,if=((target.health.pct<35&(debuff.touch_of_the_magi.remains<(gcd.max*1.25))&(debuff.touch_of_the_magi.remains>action.arcane_barrage.travel_time))|((buff.arcane_surge.remains<gcd.max)&buff.arcane_surge.up))&buff.arcane_charge.stack=4
  if S.ArcaneBarrage:IsCastable() and (((Target:HealthPercentage() < 35 and (Target:DebuffRemains(S.TouchoftheMagiDebuff) < (Player:GCD() * 1.25)) and (Target:DebuffRemains(S.TouchoftheMagiDebuff) > S.ArcaneBarrage:TravelTime())) or ((Player:BuffRemains(S.ArcaneSurgeBuff) < Player:GCD()) and Player:BuffUp(S.ArcaneSurgeBuff))) and Player:ArcaneCharges() == 4) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 44"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 46"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 48"; end
  end
end

local function Sunfury()
  -- Note: Handle arcane_missiles interrupts.
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and LastSFAM == 1 and (S.ArcaneMissiles:TickTime() > Player:GCDRemains()) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt sunfury 2"; end
  end
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (LastSFAM == 2 or LastSFAM == 3) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and (Player:BuffDown(S.AetherAttunementBuff) or (EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable())))) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt sunfury 4"; end
  end
  -- shifting_power,if=((buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>15&cooldown.touch_of_the_magi.remains>10)&fight_remains>10)&buff.arcane_soul.down&(buff.intuition.react=0|(buff.intuition.react&buff.intuition.remains>cast_time))
  if S.ShiftingPower:IsReady() and (((Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and S.Evocation:CooldownRemains() > 15 and S.TouchoftheMagi:CooldownRemains() > 10) and FightRemains > 10) and Player:BuffDown(S.ArcaneSoulBuff) and (Player:BuffDown(S.IntuitionBuff) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) > S.ShiftingPower:CastTime()))) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power sunfury 6"; end
  end
  -- cancel_buff,name=presence_of_mind,use_off_gcd=1,if=(prev_gcd.1.arcane_blast&buff.presence_of_mind.stack=1)|active_enemies<4
  -- TODO: Handle cancel_buff.
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.nether_precision.up&active_enemies<4
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= Player:GCD() and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash < 4) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind sunfury 8"; end
  end
  -- wait,sec=0.05,if=time-action.presence_of_mind.last_used<0.015,line_cd=15
  -- arcane_missiles,if=buff.nether_precision.down&buff.clearcasting.react&buff.arcane_soul.up&buff.arcane_soul.remains>gcd.max*(4-buff.clearcasting.react),interrupt_if=tick_time>gcd.remains,interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ArcaneSoulBuff) and Player:BuffRemains(S.ArcaneSoulBuff) > Player:GCD() * (4 - Player:BuffStack(S.ClearcastingBuff))) then
    LastSFAM = 1
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 10"; end
  end
  -- arcane_barrage,if=buff.arcane_soul.up
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.ArcaneSoulBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 12"; end
  end
  -- arcane_barrage,if=(buff.arcane_tempo.up&buff.arcane_tempo.remains<gcd.max)|(buff.intuition.react&buff.intuition.remains<gcd.max)
  if S.ArcaneBarrage:IsCastable() and ((Player:BuffUp(S.ArcaneTempoBuff) and Player:BuffRemains(S.ArcaneTempoBuff) < Player:GCD()) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) < Player:GCD())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 14"; end
  end
  -- arcane_barrage,if=(talent.orb_barrage&active_enemies>1&buff.arcane_harmony.stack>=18&((active_enemies>3&(talent.resonance|talent.high_voltage))|buff.nether_precision.down|buff.nether_precision.stack=1|(buff.nether_precision.stack=2&buff.clearcasting.react=3)))
  if S.ArcaneBarrage:IsCastable() and ((S.OrbBarrage:IsAvailable() and EnemiesCount8ySplash > 1 and Player:BuffStack(S.ArcaneHarmonyBuff) >= 18 and ((EnemiesCount8ySplash > 3 and (S.Resonance:IsAvailable() or S.HighVoltage:IsAvailable())) or Player:BuffDown(S.NetherPrecisionBuff) or Player:BuffStack(S.NetherPrecisionBuff) == 1 or (Player:BuffStack(S.NetherPrecisionBuff) == 2 and Player:BuffStack(S.ClearcastingBuff) == 3)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 16"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&set_bonus.thewarwithin_season_2_4pc&buff.aether_attunement.react&cooldown.touch_of_the_magi.remains<gcd.max*(3-(1.5*(active_enemies>3&(!talent.time_loop|talent.resonance)))),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and Player:HasTier("TWW2", 4) and Player:BuffUp(S.AetherAttunementBuff) and S.TouchoftheMagi:CooldownRemains() < Player:GCD() * (3 - (1.5 * num(EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable()))))) then
    LastSFAM = 2
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 18"; end
  end
  -- arcane_blast,if=((debuff.magis_spark_arcane_blast.up&((debuff.magis_spark_arcane_blast.remains<(cast_time+gcd.max))|active_enemies=1|talent.leydrinker))|buff.leydrinker.up)&buff.arcane_charge.stack=4&(buff.nether_precision.up|buff.clearcasting.react=0),line_cd=2
  if S.ArcaneBlast:IsReady() and S.ArcaneBlast:TimeSinceLastCast() >= 2 and (((Target:DebuffUp(S.MagisSparkABDebuff) and ((Target:DebuffRemains(S.MagisSparkABDebuff) < (S.ArcaneBlast:CastTime() + Player:GCD())) or EnemiesCount8ySplash == 1 or S.Leydrinker:IsAvailable())) or Player:BuffUp(S.LeydrinkerBuff)) and Player:ArcaneCharges() == 4 and (Player:BuffUp(S.NetherPrecisionBuff) or Player:BuffDown(S.ClearcastingBuff))) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury 20"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=4&(cooldown.touch_of_the_magi.ready|cooldown.touch_of_the_magi.remains<((travel_time+50)>?gcd.max))
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == 4 and (S.TouchoftheMagi:CooldownRemains() < Player:GCD())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 22"; end
  end
  -- arcane_barrage,if=(talent.high_voltage&active_enemies>1&buff.arcane_charge.stack=4&buff.clearcasting.react&buff.nether_precision.stack=1)
  if S.ArcaneBarrage:IsCastable() and (S.HighVoltage:IsAvailable() and EnemiesCount8ySplash > 1 and Player:ArcaneCharges() == 4 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.NetherPrecisionBuff) == 1) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 24"; end
  end
  -- arcane_barrage,if=(active_enemies>1&talent.high_voltage&buff.arcane_charge.stack=4&buff.clearcasting.react&buff.aether_attunement.react&buff.glorious_incandescence.down&buff.intuition.down)
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash > 1 and S.HighVoltage:IsAvailable() and Player:ArcaneCharges() == 4 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.AetherAttunementBuff) and Player:BuffDown(S.GloriousIncandescenceBuff) and Player:BuffDown(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 26"; end
  end
  -- arcane_barrage,if=(active_enemies>2&talent.orb_barrage&talent.high_voltage&debuff.magis_spark_arcane_blast.down&buff.arcane_charge.stack=4&target.health.pct<35&talent.arcane_bombardment&(buff.nether_precision.up|(buff.nether_precision.down&buff.clearcasting.stack=0)))
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash > 2 and S.OrbBarrage:IsAvailable() and S.HighVoltage:IsAvailable() and Target:DebuffDown(S.MagisSparkABDebuff) and Player:ArcaneCharges() == 4 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and (Player:BuffUp(S.NetherPrecisionBuff) or (Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffDown(S.ClearcastingBuff)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 28"; end
  end
  -- arcane_barrage,if=((active_enemies>2|(active_enemies>1&target.health.pct<35&talent.arcane_bombardment))&cooldown.arcane_orb.remains<gcd.max&buff.arcane_charge.stack=4&cooldown.touch_of_the_magi.remains>gcd.max*6&(debuff.magis_spark_arcane_blast.down|!talent.magis_spark)&buff.nether_precision.up&(talent.high_voltage|buff.nether_precision.stack=2|(buff.nether_precision.stack=1&buff.clearcasting.react=0)))
  if S.ArcaneBarrage:IsCastable() and ((EnemiesCount8ySplash > 2 or (EnemiesCount8ySplash > 1 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable())) and S.ArcaneOrb:CooldownRemains() < Player:GCD() and Player:ArcaneCharges() == 4 and S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 and (Target:DebuffDown(S.MagisSparkABDebuff) or not S.MagisSpark:IsAvailable()) and Player:BuffUp(S.NetherPrecisionBuff) and (S.HighVoltage:IsAvailable() or Player:BuffStack(S.NetherPrecisionBuff) == 2 or (Player:BuffStack(S.NetherPrecisionBuff) == 1 and Player:BuffDown(S.ClearcastingBuff)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 30"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&((talent.high_voltage&buff.arcane_charge.stack<4)|buff.nether_precision.down|(buff.clearcasting.react=3&(!talent.high_voltage|active_enemies=1))),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and ((S.HighVoltage:IsAvailable() and Player:ArcaneCharges() < 4) or Player:BuffDown(S.NetherPrecisionBuff) or (Player:BuffStack(S.ClearcastingBuff) == 3 and (not S.HighVoltage:IsAvailable() or EnemiesCount8ySplash == 1)))) then
    LastSFAM = 3
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 32"; end
  end
  -- arcane_barrage,if=(buff.arcane_charge.stack=4&active_enemies>1&active_enemies<5&buff.burden_of_power.up&((talent.high_voltage&buff.clearcasting.react)|buff.glorious_incandescence.up|buff.intuition.react|(cooldown.arcane_orb.remains<gcd.max|action.arcane_orb.charges>0)))&(!talent.consortiums_bauble|talent.high_voltage)
  if S.ArcaneBarrage:IsCastable() and ((Player:ArcaneCharges() == 4 and EnemiesCount8ySplash > 1 and EnemiesCount8ySplash < 5 and Player:BuffUp(S.BurdenofPowerBuff) and ((S.HighVoltage:IsAvailable() and Player:BuffUp(S.ClearcastingBuff)) or Player:BuffUp(S.GloriousIncandescenceBuff) or Player:BuffUp(S.IntuitionBuff) or (S.ArcaneOrb:CooldownRemains() < Player:GCD() or S.ArcaneOrb:Charges() > 0))) and (not S.ConsortiumsBauble:IsAvailable() or S.HighVoltage:IsAvailable())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 34"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<3
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb sunfury 36"; end
  end
  -- arcane_barrage,if=(buff.glorious_incandescence.up&(cooldown.touch_of_the_magi.remains>6|!talent.magis_spark))|buff.intuition.react
  if S.ArcaneBarrage:IsCastable() and ((Player:BuffUp(S.GloriousIncandescenceBuff) and (S.TouchoftheMagi:CooldownRemains() > 6 or not S.MagisSpark:IsAvailable())) or Player:BuffUp(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 38"; end
  end
  -- presence_of_mind,if=(buff.arcane_charge.stack=3|buff.arcane_charge.stack=2)&active_enemies>=3
  if S.PresenceofMind:IsCastable() and ((Player:ArcaneCharges() == 3 or Player:ArcaneCharges() == 2) and EnemiesCount8ySplash >= 3) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind sunfury 40"; end
  end
  -- arcane_explosion,if=buff.arcane_charge.stack<2&active_enemies>1
  if S.ArcaneExplosion:IsReady() and (Player:ArcaneCharges() < 2 and EnemiesCount8ySplash > 1) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion sunfury 42"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury 44"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 46"; end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Set which cast function to use for ArcaneExplosion
    CastAE = (Settings.Arcane.AEMainIcon) and Cast or CastLeft
  end

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    -- Note: Moved from of precombat
    if S.ArcaneIntellect:IsCastable() and (Settings.Commons.AIDuringCombat or not Player:AffectingCombat()) and (S.ArcaneFamiliar:IsAvailable() and Player:BuffDown(S.ArcaneFamiliarBuff) or Everyone.GroupBuffMissing(S.ArcaneIntellect)) then
      if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- potion,if=!equipped.spymasters_web&(buff.siphon_storm.up|(!talent.evocation&cooldown.arcane_surge.ready))|equipped.spymasters_web&(buff.spymasters_web.up|(fight_remains>330&buff.siphon_storm.up))
    if Settings.Commons.Enabled.Potions and (not I.SpymastersWeb:IsEquipped() and (Player:BuffUp(S.SiphonStormBuff) or (not S.Evocation:IsAvailable() and S.ArcaneSurge:CooldownUp())) or I.SpymastersWeb:IsEquipped() and (Player:BuffUp(S.SpymastersWebBuff) or (FightRemains > 330 and Player:BuffUp(S.SiphonStormBuff)))) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    if CDsON() then
      -- lights_judgment,if=(buff.arcane_surge.down&debuff.touch_of_the_magi.down&active_enemies>=2)
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 4"; end
      end
      if (Player:PrevGCDP(1, S.ArcaneSurge) and VarOpener) or ((Player:PrevGCDP(1, S.ArcaneSurge) and (FightRemains < 80 or Target:HealthPercentage() < 35 or not S.ArcaneBombardment:IsAvailable() or Player:BuffUp(S.SpymastersWebBuff))) or (Player:PrevGCDP(1, S.ArcaneSurge) and not I.SpymastersWeb:IsEquipped())) then
        -- berserking,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.Berserking:IsCastable() then
          if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
        end
        -- blood_fury,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 8"; end
        end
        -- fireblood,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 10"; end
        end
        -- ancestral_call,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 12"; end
        end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=(!equipped.spymasters_web&prev_gcd.1.arcane_surge)|(equipped.spymasters_web&prev_gcd.1.evocation)
    -- invoke_external_buff,name=blessing_of_summer,if=prev_gcd.1.arcane_surge
    -- invoke_external_buff,name=blessing_of_autumn,if=cooldown.touch_of_the_magi.remains>5
    -- Note: Not handling external buffs.
    -- variable,name=spymasters_double_on_use,op=set,value=(equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.treacherous_transmitter|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.signet_of_the_priory)&equipped.spymasters_web&cooldown.evocation.remains<17&(buff.spymasters_report.stack>35|(fight_remains<90&buff.spymasters_report.stack>25))
    VarSpymastersDoubleOnUse = (Player:GladiatorsBadgeIsEquipped() or I.SignetOfThePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.FunhouseLens:IsEquipped() or I.HouseOfCards:IsEquipped() or I.FlarendosPilotLight:IsEquipped()) and I.SpymastersWeb:IsEquipped() and S.Evocation:CooldownRemains() < 17 and (Player:BuffStack(S.SpymastersReportBuff) > 35 or (FightRemains < 90 and Player:BuffStack(S.SpymastersReportBuff) > 25))
    -- use_items,if=((prev_gcd.1.arcane_surge&variable.steroid_trinket_equipped)|(cooldown.arcane_surge.ready&variable.steroid_trinket_equipped)|!variable.steroid_trinket_equipped&variable.nonsteroid_trinket_equipped|(variable.nonsteroid_trinket_equipped&buff.siphon_storm.remains<10&(cooldown.evocation.remains>17|trinket.cooldown.remains>20)))&!variable.spymasters_double_on_use|(fight_remains<20)
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse and (((Player:PrevGCDP(1, S.ArcaneSurge) and VarSteroidTrinketEquipped) or (S.ArcaneSurge:CooldownUp() and VarSteroidTrinketEquipped) or not VarSteroidTrinketEquipped and VarNonsteroidTrinketEquipped or (VarNonsteroidTrinketEquipped and Player:BuffRemains(S.SiphonStormBuff) < 10 and (S.Evocation:CooldownRemains() > 17 or ItemToUse:CooldownRemains() > 20))) and not VarSpymastersDoubleOnUse or (FightRemains < 20)) then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " main 14"; end
        end
      end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=treacherous_transmitter,if=buff.spymasters_report.stack<40
      if I.TreacherousTransmitter:IsEquippedAndReady() and (Player:BuffStack(S.SpymastersReportBuff) < 40) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter main 16"; end
      end
      -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.siphon_storm.up|fight_remains<20|(buff.cryptic_instructions.remains<?buff.realigning_nexus_convergence_divergence.remains<?buff.errant_manaforge_emission.remains)<3
      -- use_item,name=spymasters_web,if=((prev_gcd.1.arcane_surge|prev_gcd.1.evocation)&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|(buff.spymasters_report.stack=40&fight_remains>240))|fight_remains<20)
      if I.SpymastersWeb:IsEquippedAndReady() and ((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation)) and (FightRemains < 80 or Target:HealthPercentage() < 35 or not S.ArcaneBombardment:IsAvailable() or (Player:BuffStack(S.SpymastersReportBuff) == 40 and FightRemains > 240)) or BossFightRemains < 20) then
        if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web main 18"; end
      end
      -- use_item,name=high_speakers_accretion,if=(prev_gcd.1.arcane_surge|prev_gcd.1.evocation|(buff.siphon_storm.up&variable.opener)|cooldown.evocation.remains<4|fight_remains<20)&!variable.spymasters_double_on_use
      if I.HighSpeakersAccretion:IsEquippedAndReady() and ((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation) or (Player:BuffUp(S.SiphonStormBuff) and VarOpener) or S.Evocation:CooldownRemains() < 4 or BossFightRemains < 20) and not VarSpymastersDoubleOnUse) then
        if Cast(I.HighSpeakersAccretion, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "high_speakers_accretion main 20"; end
      end
      -- use_item,name=imperfect_ascendancy_serum,if=(cooldown.evocation.ready|cooldown.arcane_surge.ready|fight_remains<21)&!variable.spymasters_double_on_use
      if I.ImperfectAscendancySerum:IsEquippedAndReady() and ((S.Evocation:CooldownUp() or S.ArcaneSurge:CooldownUp() or BossFightRemains < 21) and not VarSpymastersDoubleOnUse) then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum main 22"; end
      end
      -- use_item,name=neural_synapse_enhancer,if=(debuff.touch_of_the_magi.remains>8&buff.arcane_surge.up)|(debuff.touch_of_the_magi.remains>8&variable.neural_on_mini)
      if I.NeuralSynapseEnhancer:IsEquippedAndReady() and ((Target:DebuffRemains(S.TouchoftheMagiDebuff) > 8 and Player:BuffUp(S.ArcaneSurgeBuff)) or (Target:DebuffRemains(S.TouchoftheMagiDebuff) > 8 and VarNeuralOnMini)) then
        if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "neural_synapse_enhancer main 24"; end
      end
    end
    -- variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
    -- Note: Added extra TotM checks so we don't get stuck in the opener if TotM is on CD or not talented.
    if (Target:DebuffUp(S.TouchoftheMagiDebuff) or S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 4 or not S.TouchoftheMagi:IsAvailable()) and VarOpener then
      VarOpener = false
    end
    -- arcane_barrage,if=fight_remains<2
    if S.ArcaneBarrage:IsReady() and (FightRemains < 2) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 26"; end
    end
    -- call_action_list,name=cd_opener
    if CDsON() then
      local ShouldReturn = CDOpener(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sunfury,if=talent.spellfire_spheres
    if S.SpellfireSpheres:IsAvailable() then
      local ShouldReturn = Sunfury(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=spellslinger,if=!talent.spellfire_spheres
    if not S.SpellfireSpheres:IsAvailable() then
      local ShouldReturn = Spellslinger(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsReady() then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage 28"; end
    end
  end
end

local function Init()
  HR.Print("Arcane Mage rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(62, APL, Init)

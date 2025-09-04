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
  -- I.Trinket:ID(),
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
local VarSoulBurst, VarSoulCD
local VarOpener = true
local VarAoEList = false
local Enemies8ySplash, EnemiesCount8ySplash
local ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
local LastSSAM = 0
local LastSFAM = 0
local TWW2_2pc = Player:HasTier("TWW2", 2)
local TWW2_4pc = Player:HasTier("TWW2", 4)
local TWW3_2pc = Player:HasTier("TWW3", 2)
local TWW3_4pc = Player:HasTier("TWW3", 4)
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

  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.neural_synapse_enhancer|equipped.lily_of_the_eternal_weave|equipped.sunblood_amethyst|equipped.arazs_ritual_forge|equipped.incorporeal_essencegorger
  VarSteroidTrinketEquipped = Player:GladiatorsBadgeIsEquipped() or I.SignetOfThePriory:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.FunhouseLens:IsEquipped() or I.HouseOfCards:IsEquipped() or I.FlarendosPilotLight:IsEquipped() or I.NeuralSynapseEnhancer:IsEquipped() or I.LilyOfTheEternalWeave:IsEquipped() or I.SunbloodAmethyst:IsEquipped() or I.ArazsRitualForge:IsEquipped() or I.IncorporealEssencegorger:IsEquipped()
  -- variable,name=nonsteroid_trinket_equipped,op=set,value=equipped.blastmaster3000|equipped.ratfang_toxin|equipped.ingenious_mana_battery|equipped.geargrinders_spare_keys|equipped.ringing_ritual_mud|equipped.goo_blin_grenade|equipped.noggenfogger_ultimate_deluxe|equipped.garbagemancers_last_resort|equipped.mad_queens_mandate|equipped.fearbreakers_echo|equipped.mereldars_toll|equipped.gooblin_grenade|equipped.perfidious_projector|equipped.chaotic_nethergate
  VarNonsteroidTrinketEquipped = I.Blastmaster3000:IsEquipped() or I.RatfangToxin:IsEquipped() or I.IngeniousManaBattery:IsEquipped() or I.GeargrindersSpareKeys:IsEquipped() or I.RingingRitualMud:IsEquipped() or I.GooBlinGrenade:IsEquipped() or I.NoggenfoggerUltimateDeluxe:IsEquipped() or I.GarbagemancersLastResort:IsEquipped() or I.MadQueensMandate:IsEquipped() or I.FearbreakersEcho:IsEquipped() or I.MereldarsToll:IsEquipped() or I.PerfidiousProjector:IsEquipped() or I.ChaoticNethergate:IsEquipped()
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
  TWW2_2pc = Player:HasTier("TWW2", 2)
  TWW2_4pc = Player:HasTier("TWW2", 4)
  TWW3_2pc = Player:HasTier("TWW3", 2)
  TWW3_4pc = Player:HasTier("TWW3", 4)
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== Rotation Functions =====
local function Precombat()
  -- arcane_intellect
  -- Note: Moved to top of APL()
  -- variable,name=soul_burst,default=0,op=reset
  VarSoulBurst = Settings.Arcane.SoulBurst
  -- variable,name=soul_cd,op=set,value=1,if=set_bonus.thewarwithin_season_3_4pc&talent.spellfire_spheres&talent.resonance&!talent.magis_spark&(active_enemies>=3)&variable.soul_burst
  -- Note: Can't check active_enemies in Precombat, so defaulting to false.
  VarSoulCD = false
  -- variable,name=aoe_target_count,op=reset,default=2
  -- variable,name=aoe_target_count,op=set,value=9,if=!talent.arcing_cleave
  -- variable,name=opener,op=set,value=1
  -- variable,name=aoe_list,default=0,op=reset
  -- Note: Moved to variable declarations and Event Registrations to avoid potential nil errors.
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick|equipped.soulletting_ruby|equipped.funhouse_lens|equipped.house_of_cards|equipped.flarendos_pilot_light|equipped.neural_synapse_enhancer|equipped.lily_of_the_eternal_weave|equipped.sunblood_amethyst|equipped.arazs_ritual_forge|equipped.incorporeal_essencegorger
  -- variable,name=nonsteroid_trinket_equipped,op=set,value=equipped.blastmaster3000|equipped.ratfang_toxin|equipped.ingenious_mana_battery|equipped.geargrinders_spare_keys|equipped.ringing_ritual_mud|equipped.goo_blin_grenade|equipped.noggenfogger_ultimate_deluxe|equipped.garbagemancers_last_resort|equipped.mad_queens_mandate|equipped.fearbreakers_echo|equipped.mereldars_toll|equipped.gooblin_grenade|equipped.perfidious_projector|equipped.chaotic_nethergate
  -- Note: Moved to SetTrinketVariables().
  -- snapshot_stats
  -- mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 6"; end
  end
  -- arcane_blast,if=!talent.evocation
  if S.ArcaneBlast:IsReady() and (not S.Evocation:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 10"; end
  end
  -- evocation,if=talent.evocation&!variable.soul_cd
  if S.Evocation:IsReady() and (not VarSoulCD) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation precombat 12"; end
  end
  -- arcane_surge,if=variable.soul_cd
  -- Note: We will never have soul_cd be true in Precombat. Skipping...
end

local function CDOpener()
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_surge|(cooldown.arcane_surge.remains>30&cooldown.touch_of_the_magi.ready&((buff.arcane_charge.stack<4&!prev_gcd.1.arcane_barrage)|prev_gcd.1.arcane_barrage))|fight_remains<15
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneSurge) or (S.ArcaneSurge:CooldownRemains() > 30 and S.TouchoftheMagi:CooldownUp() and ((Player:ArcaneCharges() < 4 and not Player:PrevGCDP(1, S.ArcaneBarrage)) or Player:PrevGCDP(1, S.ArcaneBarrage))) or BossFightRemains < 15) then
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
  -- evocation,if=cooldown.arcane_surge.remains<(gcd.max*3)&cooldown.touch_of_the_magi.remains<(gcd.max*5)|fight_remains<25
  if S.Evocation:IsCastable() and (S.ArcaneSurge:CooldownRemains() < (Player:GCD() * 3) and S.TouchoftheMagi:CooldownRemains() < (Player:GCD() * 5) or BossFightRemains < 25) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation cd_opener 10"; end
  end
  -- arcane_missiles,if=(prev_gcd.1.evocation|prev_gcd.1.arcane_surge|variable.opener)&buff.nether_precision.down,interrupt_if=tick_time>gcd.remains&buff.aether_attunement.react=0,interrupt_immediate=1,interrupt_global=1,chain=1,line_cd=30
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt cd_opener 12"; end
  end
  if S.ArcaneMissiles:IsReady() and S.ArcaneMissiles:TimeSinceLastCast() >= 30 and ((Player:PrevGCDP(1, S.Evocation) or Player:PrevGCDP(1, S.ArcaneSurge) or VarOpener) and Player:BuffDown(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cd_opener 14"; end
  end
  -- arcane_surge,if=cooldown.touch_of_the_magi.remains<(action.arcane_surge.execute_time+(gcd.max*(buff.arcane_charge.stack=4)))|fight_remains<25
  if S.ArcaneSurge:IsCastable() and (S.TouchoftheMagi:CooldownRemains() < (S.ArcaneSurge:ExecuteTime() + (Player:GCD() * num(Player:ArcaneCharges() == 4))) or BossFightRemains < 25) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge cd_opener 16"; end
  end
end

local function CDOpenerSoul()
  -- arcane_surge,if=(cooldown.touch_of_the_magi.remains<15)
  if S.ArcaneSurge:IsCastable() and (S.TouchoftheMagi:CooldownRemains() < 15) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge cd_opener_soul 2"; end
  end
  -- evocation,if=buff.arcane_surge.up&(buff.arcane_surge.remains<=8.5|((buff.glorious_incandescence.up|buff.intuition.react)&buff.arcane_surge.remains<=10))
  if S.Evocation:IsCastable() and (Player:BuffUp(S.ArcaneSurgeBuff) and (Player:BuffRemains(S.ArcaneSurgeBuff) <= 8.5 or ((Player:BuffUp(S.GloriousIncandescenceBuff) or Player:BuffUp(S.IntuitionBuff)) and Player:BuffRemains(S.ArcaneSurgeBuff) <= 10))) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation cd_opener_soul 4"; end
  end
  -- touch_of_the_magi,if=(buff.arcane_surge.remains<=2.5&prev_gcd.1.arcane_barrage)|(cooldown.evocation.remains>40&cooldown.evocation.remains<60&prev_gcd.1.arcane_barrage)
  if S.TouchoftheMagi:IsCastable() and ((Player:BuffRemains(S.ArcaneSurgeBuff) <= 2.5 and Player:PrevGCDP(1, S.ArcaneBarrage)) or (S.Evocation:CooldownRemains() > 40 and S.Evocation:CooldownRemains() < 60 and Player:PrevGCDP(1, S.ArcaneBarrage))) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi, nil, not Target:IsSpellInRange(S.TouchoftheMagi)) then return "touch_of_the_magi cd_opener_soul 6"; end
  end
end

local function Spellslinger()
  -- Note: Handle arcane_missiles interrupts.
  -- interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance)))
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (LastSSAM == 1 or LastSSAM == 2) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and (Player:BuffDown(S.AetherAttunementBuff) or (EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable())))) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt spellslinger 2"; end
  end
  -- shifting_power,if=(((((action.arcane_orb.charges=0)&cooldown.arcane_orb.remains>16)|cooldown.touch_of_the_magi.remains<20)&buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&(buff.intuition.react=0|(buff.intuition.react&buff.intuition.remains>cast_time))&cooldown.touch_of_the_magi.remains>(12+6*gcd.max))|(prev_gcd.1.arcane_barrage&talent.shifting_shards&(buff.intuition.react=0|(buff.intuition.react&buff.intuition.remains>cast_time))&(buff.arcane_surge.up|debuff.touch_of_the_magi.up|cooldown.evocation.remains<20)))&fight_remains>10&(buff.arcane_tempo.remains>gcd.max*2.5|buff.arcane_tempo.down)
  if S.ShiftingPower:IsReady() and ((((((S.ArcaneOrb:Charges() == 0) and S.ArcaneOrb:CooldownRemains() > 16) or S.TouchoftheMagi:CooldownRemains() < 20) and Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and (Player:BuffDown(S.IntuitionBuff) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) > S.ShiftingPower:CastTime())) and S.TouchoftheMagi:CooldownRemains() > (12 + 6 * Player:GCD())) or (Player:PrevGCDP(1, S.ArcaneBarrage) and S.ShiftingShards:IsAvailable() and (Player:BuffDown(S.IntuitionBuff) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) > S.ShiftingPower:CastTime())) and (Player:BuffUp(S.ArcaneSurgeBuff) or Target:DebuffUp(S.TouchoftheMagiDebuff) or S.Evocation:CooldownRemains() < 20))) and FightRemains > 10 and (Player:BuffRemains(S.ArcaneTempoBuff) > Player:GCD() * 2.5 or Player:BuffDown(S.ArcaneTempoBuff))) then
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
  -- arcane_orb,if=buff.arcane_charge.stack<4
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 4) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger 10"; end
  end
  -- arcane_barrage,if=(buff.arcane_tempo.up&buff.arcane_tempo.remains<gcd.max)
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.ArcaneTempoBuff) and Player:BuffRemains(S.ArcaneTempoBuff) < Player:GCD()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 12"; end
  end
  -- arcane_missiles,if=buff.aether_attunement.react&cooldown.touch_of_the_magi.remains<gcd.max*3&buff.clearcasting.react&set_bonus.thewarwithin_season_2_4pc
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.AetherAttunementBuff) and S.TouchoftheMagi:CooldownRemains() < Player:GCD() * 3 and Player:BuffUp(S.ClearcastingBuff) and TWW2_4pc) then
    LastSSAM = 0
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 14"; end
  end
  -- arcane_barrage,if=(cooldown.touch_of_the_magi.ready|cooldown.touch_of_the_magi.remains<((travel_time+0.05)>?gcd.max))&(cooldown.arcane_surge.remains>30&cooldown.arcane_surge.remains<75)
  -- Note: Intent seems to be to dump charges before TotM, so added >0 check.
  -- Note: Removed cooldown.touch_of_the_magi.ready, since that would be equivalent to remains=0, which is less than gcd.max.
  if S.ArcaneBarrage:IsCastable() and Player:ArcaneCharges() > 0 and ((S.TouchoftheMagi:CooldownRemains() + 0.05) < Player:GCD() and (S.ArcaneSurge:CooldownRemains() > 30 and S.ArcaneSurge:CooldownRemains() < 75)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 16"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=4&buff.arcane_harmony.stack>=20&set_bonus.thewarwithin_season_3_4pc
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == 4 and Player:BuffStack(S.ArcaneHarmonyBuff) >= 20 and TWW3_4pc) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 18"; end
  end
  -- arcane_missiles,if=(buff.clearcasting.react&buff.nether_precision.down&((cooldown.touch_of_the_magi.remains>gcd.max*7&cooldown.arcane_surge.remains>gcd.max*7)|buff.clearcasting.react>1|!talent.magis_spark|(cooldown.touch_of_the_magi.remains<gcd.max*4&buff.aether_attunement.react=0)|set_bonus.thewarwithin_season_2_4pc))|(fight_remains<5&buff.clearcasting.react),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and ((Player:BuffUp(S.ClearcastingBuff) and Player:BuffDown(S.NetherPrecisionBuff) and ((S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 7 and S.ArcaneSurge:CooldownRemains() > Player:GCD() * 7) or Player:BuffStack(S.ClearcastingBuff) > 1 or not S.MagisSpark:IsAvailable() or (S.TouchoftheMagi:CooldownRemains() < Player:GCD() * 4 and Player:BuffDown(S.AetherAttunementBuff)) or TWW2_4pc)) or (FightRemains < 5 and Player:BuffUp(S.ClearcastingBuff))) then
    LastSSAM = 1
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 20"; end
  end
  -- arcane_missiles,if=talent.high_voltage&(buff.clearcasting.react>1|(buff.clearcasting.react&buff.aether_attunement.react))&buff.arcane_charge.stack<3,interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (S.HighVoltage:IsAvailable() and (Player:BuffStack(S.ClearcastingBuff) > 1 or (Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.AetherAttunementBuff))) and Player:ArcaneCharges() < 3) then
    LastSSAM = 2
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 22"; end
  end
  -- arcane_barrage,if=buff.intuition.react
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 24"; end
  end
  -- arcane_blast,if=debuff.magis_spark_arcane_blast.up|buff.leydrinker.up,line_cd=2
  if S.ArcaneBlast:IsReady() and (Target:DebuffUp(S.MagisSparkABDebuff) or Player:BuffUp(S.LeydrinkerBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 26"; end
  end
  -- arcane_blast,if=buff.nether_precision.up&buff.arcane_harmony.stack<=16&buff.arcane_charge.stack=4&active_enemies=1
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.NetherPrecisionBuff) and Player:BuffStack(S.ArcaneHarmonyBuff) <= 16 and Player:ArcaneCharges() == 4 and EnemiesCount8ySplash == 1) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 28"; end
  end
  -- arcane_barrage,if=mana.pct<10&buff.arcane_surge.down&(cooldown.arcane_orb.remains<gcd.max)
  if S.ArcaneBarrage:IsCastable() and (Player:ManaPercentage() < 10 and Player:BuffDown(S.ArcaneSurgeBuff) and S.ArcaneOrb:CooldownRemains() < Player:GCD()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 30"; end
  end
  -- arcane_orb,if=active_enemies=1&(cooldown.touch_of_the_magi.remains<6|!talent.charged_orb|buff.arcane_surge.up|cooldown.arcane_orb.charges_fractional>1.5)
  if S.ArcaneOrb:IsReady() and (EnemiesCount8ySplash == 1 and (S.TouchoftheMagi:CooldownRemains() < 6 or not S.ChargedOrb:IsAvailable() or Player:BuffUp(S.ArcaneSurgeBuff) or S.ArcaneOrb:ChargesFractional() > 1.5)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger 32"; end
  end
  -- arcane_barrage,if=active_enemies>=2&buff.arcane_charge.stack=4&cooldown.arcane_orb.remains<gcd.max&(buff.arcane_harmony.stack<=(8+(10*!set_bonus.thewarwithin_season_3_4pc)))&(((prev_gcd.1.arcane_barrage|prev_gcd.1.arcane_orb)&buff.nether_precision.stack=1)|buff.nether_precision.stack=2|buff.nether_precision.down)
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash >= 2 and Player:ArcaneCharges() == 4 and S.ArcaneOrb:CooldownRemains() < Player:GCD() and Player:BuffStack(S.ArcaneHarmonyBuff) <= 8 + (10 * num(not TWW3_4pc)) and (((Player:PrevGCDP(1, S.ArcaneBarrage) or Player:PrevGCDP(1, S.ArcaneOrb)) and Player:BuffStack(S.NetherPrecisionBuff) == 1) or Player:BuffStack(S.NetherPrecisionBuff) == 2 or Player:BuffDown(S.NetherPrecisionBuff))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 34"; end
  end
  -- arcane_barrage,if=active_enemies>2&(buff.arcane_charge.stack=4&!set_bonus.thewarwithin_season_3_4pc)
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash > 2 and Player:ArcaneCharges() == 4 and not TWW3_4pc) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 36"; end
  end
  -- arcane_orb,if=active_enemies>1&buff.arcane_harmony.stack<20&(buff.arcane_surge.up|buff.nether_precision.up|active_enemies>=7)&set_bonus.thewarwithin_season_3_4pc
  if S.ArcaneOrb:IsReady() and (EnemiesCount8ySplash > 1 and Player:BuffStack(S.ArcaneHarmonyBuff) < 20 and (Player:BuffUp(S.ArcaneSurgeBuff) or Player:BuffUp(S.NetherPrecisionBuff) or EnemiesCount8ySplash >= 7) and TWW3_4pc) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger 38"; end
  end
  -- arcane_barrage,if=talent.high_voltage&active_enemies>=2&buff.arcane_charge.stack=4&buff.aether_attunement.react&buff.clearcasting.react
  if S.ArcaneBarrage:IsCastable() and (S.HighVoltage:IsAvailable() and EnemiesCount8ySplash >= 2 and Player:ArcaneCharges() == 4 and Player:BuffUp(S.AetherAttunementBuff) and Player:BuffUp(S.ClearcastingBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 40"; end
  end
  -- arcane_orb,if=active_enemies>1&(active_enemies<3|buff.arcane_surge.up|(buff.nether_precision.up))&set_bonus.thewarwithin_season_3_4pc
  if S.ArcaneOrb:IsReady() and (EnemiesCount8ySplash > 1 and (EnemiesCount8ySplash < 3 or Player:BuffUp(S.ArcaneSurgeBuff) or Player:BuffUp(S.NetherPrecisionBuff)) and TWW3_4pc) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger 42"; end
  end
  -- arcane_barrage,if=active_enemies>1&buff.arcane_charge.stack=4&cooldown.arcane_orb.remains<gcd.max
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash > 1 and Player:ArcaneCharges() == 4 and S.ArcaneOrb:CooldownRemains() < Player:GCD()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 44"; end
  end
  -- arcane_barrage,if=talent.high_voltage&buff.arcane_charge.stack=4&buff.clearcasting.react&buff.nether_precision.stack=1
  if S.ArcaneBarrage:IsCastable() and (S.HighVoltage:IsAvailable() and Player:ArcaneCharges() == 4 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.NetherPrecisionBuff) == 1) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 46"; end
  end
  -- arcane_barrage,if=(active_enemies=1&(talent.orb_barrage|(target.health.pct<35&talent.arcane_bombardment))&(cooldown.arcane_orb.remains<gcd.max)&buff.arcane_charge.stack=4&(cooldown.touch_of_the_magi.remains>gcd.max*6|!talent.magis_spark)&(buff.nether_precision.down|(buff.nether_precision.stack=1&buff.clearcasting.stack=0)))&!set_bonus.thewarwithin_season_3_4pc
  if S.ArcaneBarrage:IsCastable() and ((EnemiesCount8ySplash == 1 and (S.OrbBarrage:IsAvailable() or (Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable())) and S.ArcaneOrb:CooldownRemains() < Player:GCD() and Player:ArcaneCharges() == 4 and (S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 or not S.MagisSpark:IsAvailable()) and (Player:BuffDown(S.NetherPrecisionBuff) or (Player:BuffStack(S.NetherPrecisionBuff) == 1 and Player:BuffDown(S.ClearcastingBuff)))) and not TWW3_4pc) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 48"; end
  end
  -- arcane_explosion,if=active_enemies>1&((buff.arcane_charge.stack<1&!talent.high_voltage)|(buff.arcane_charge.stack<3&(buff.clearcasting.react=0|talent.reverberate)))
  if S.ArcaneExplosion:IsReady() and (EnemiesCount8ySplash > 1 and ((Player:ArcaneCharges() < 1 and not S.HighVoltage:IsAvailable()) or (Player:ArcaneCharges() < 3 and (Player:BuffDown(S.ClearcastingBuff) or S.Reverberate:IsAvailable())))) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion spellslinger 50"; end
  end
  -- arcane_explosion,if=active_enemies=1&buff.arcane_charge.stack<2&buff.clearcasting.react=0
  if S.ArcaneExplosion:IsReady() and (EnemiesCount8ySplash == 1 and Player:ArcaneCharges() < 2 and Player:BuffDown(S.ClearcastingBuff)) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion spellslinger 52"; end
  end
  -- arcane_barrage,if=(((target.health.pct<35&(debuff.touch_of_the_magi.remains<(gcd.max*1.25))&(debuff.touch_of_the_magi.remains>action.arcane_barrage.travel_time))|((buff.arcane_surge.remains<gcd.max)&buff.arcane_surge.up))&buff.arcane_charge.stack=4)&!set_bonus.thewarwithin_season_3_4pc
  if S.ArcaneBarrage:IsCastable() and ((((Target:HealthPercentage() < 35 and (Target:DebuffRemains(S.TouchoftheMagiDebuff) < (Player:GCD() * 1.25)) and Target:DebuffRemains(S.TouchoftheMagiDebuff) > S.ArcaneBarrage:TravelTime()) or (Player:BuffRemains(S.ArcaneSurgeBuff) < Player:GCD() and Player:BuffUp(S.ArcaneSurgeBuff))) and Player:ArcaneCharges() == 4) and not TWW3_4pc) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 54"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 56"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 58"; end
  end
end

local function Sunfury()
  -- Note: Handle arcane_missiles interrupts.
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and LastSFAM == 1 and (S.ArcaneMissiles:TickTime() > Player:GCDRemains()) then
    if CastLeft(S.StopAM, "STOP AM") then return "arcane_missiles interrupt sunfury 2"; end
  end
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and LastSFAM == 2 and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and (Player:BuffDown(S.AetherAttunementBuff) or (EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable())))) then
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
  -- arcane_missiles,if=buff.clearcasting.react&buff.arcane_surge.up&buff.arcane_surge.remains<gcd.max,interrupt_if=tick_time>gcd.remains,interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ArcaneSurgeBuff) and Player:BuffRemains(S.ArcaneSurgeBuff) < Player:GCD()) then
    LastSFAM = 1
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 14"; end
  end
  -- arcane_barrage,if=(buff.arcane_tempo.up&buff.arcane_tempo.remains<(gcd.max+(gcd.max*buff.nether_precision.stack=1)))|(buff.intuition.react&buff.intuition.remains<(gcd.max+(gcd.max*buff.nether_precision.stack=1)))
  if S.ArcaneBarrage:IsReady() and ((Player:BuffUp(S.ArcaneTempoBuff) and Player:BuffRemains(S.ArcaneTempoBuff) < (Player:GCD() + (Player:GCD() * num(Player:BuffStack(S.NetherPrecisionBuff) == 1)))) or (Player:BuffUp(S.IntuitionBuff) and Player:BuffRemains(S.IntuitionBuff) < (Player:GCD() + (Player:GCD() * num(Player:BuffStack(S.NetherPrecisionBuff) == 1))))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 16"; end
  end
  -- arcane_barrage,if=(talent.orb_barrage&active_enemies>1&buff.arcane_harmony.stack>=18&((active_enemies>3&(talent.resonance|talent.high_voltage))|buff.nether_precision.down|buff.nether_precision.stack=1|(buff.nether_precision.stack=2&buff.clearcasting.react=3)))
  if S.ArcaneBarrage:IsReady() and (S.OrbBarrage:IsAvailable() and EnemiesCount8ySplash > 1 and Player:BuffStack(S.ArcaneHarmonyBuff) >= 18 and ((EnemiesCount8ySplash > 3 and (S.Resonance:IsAvailable() or S.HighVoltage:IsAvailable())) or Player:BuffDown(S.NetherPrecisionBuff) or Player:BuffStack(S.NetherPrecisionBuff) == 1 or (Player:BuffStack(S.NetherPrecisionBuff) == 2 and Player:BuffStack(S.ClearcastingBuff) == 3))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 18"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&set_bonus.thewarwithin_season_2_4pc&buff.aether_attunement.react&cooldown.touch_of_the_magi.remains<gcd.max*(3-(1.5*(active_enemies>3&(!talent.time_loop|talent.resonance)))),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and TWW2_4pc and Player:BuffUp(S.AetherAttunementBuff) and S.TouchoftheMagi:CooldownRemains() < Player:GCD() * (3 - (1.5 * num(EnemiesCount8ySplash > 3 and (not S.TimeLoop:IsAvailable() or S.Resonance:IsAvailable()))))) then
    LastSFAM = 2
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 20"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=4&((cooldown.touch_of_the_magi.ready)|cooldown.touch_of_the_magi.remains<((travel_time+50)>?gcd.max))&!variable.soul_cd
  -- Note: travel_time+0.05 was used previously.
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == 4 and (S.TouchoftheMagi:CooldownUp() or S.TouchoftheMagi:CooldownRemains() < mathmin(S.ArcaneBarrage:TravelTime() + 0.05, Player:GCD())) and not VarSoulCD) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 22"; end
  end
  -- arcane_barrage,if=(cooldown.touch_of_the_magi.ready|(cooldown.touch_of_the_magi.remains<((travel_time+50)>?gcd.max)))&(buff.arcane_surge.down|(buff.arcane_surge.up&buff.arcane_surge.remains<=2.5))&variable.soul_cd
  if S.ArcaneBarrage:IsReady() and ((S.TouchoftheMagi:CooldownUp() or (S.TouchoftheMagi:CooldownRemains() < mathmin(S.ArcaneBarrage:TravelTime() + 0.05, Player:GCD()))) and (Player:BuffDown(S.ArcaneSurgeBuff) or (Player:BuffUp(S.ArcaneSurgeBuff) and Player:BuffRemains(S.ArcaneSurgeBuff) <= 2.5)) and VarSoulCD) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 24"; end
  end
  -- arcane_blast,if=debuff.magis_spark_arcane_blast.up&buff.arcane_charge.stack=4,line_cd=2
  if S.ArcaneBlast:IsReady() and (Target:DebuffUp(S.MagisSparkABDebuff) and Player:ArcaneCharges() == 4) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury 26"; end
  end
  -- arcane_barrage,if=(talent.high_voltage&active_enemies>1&buff.arcane_charge.stack=4&buff.clearcasting.react&buff.nether_precision.stack=1)
  if S.ArcaneBarrage:IsReady() and (S.HighVoltage:IsAvailable() and EnemiesCount8ySplash > 1 and Player:ArcaneCharges() == 4 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.NetherPrecisionBuff) == 1) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 28"; end
  end
  -- arcane_barrage,if=(talent.high_voltage&active_enemies>1&buff.arcane_charge.stack=4&buff.clearcasting.react&buff.aether_attunement.react&buff.glorious_incandescence.down&buff.intuition.down)
  if S.ArcaneBarrage:IsReady() and (S.HighVoltage:IsAvailable() and EnemiesCount8ySplash > 1 and Player:ArcaneCharges() == 4 and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.AetherAttunementBuff) and Player:BuffDown(S.GloriousIncandescenceBuff) and Player:BuffDown(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 30"; end
  end
  -- arcane_barrage,if=(active_enemies>2&talent.orb_barrage&talent.high_voltage&debuff.magis_spark_arcane_blast.down&buff.arcane_charge.stack=4&target.health.pct<35&talent.arcane_bombardment&(buff.nether_precision.up|(buff.nether_precision.down&buff.clearcasting.stack=0)))
  if S.ArcaneBarrage:IsCastable() and (EnemiesCount8ySplash > 2 and S.OrbBarrage:IsAvailable() and S.HighVoltage:IsAvailable() and Target:DebuffDown(S.MagisSparkABDebuff) and Player:ArcaneCharges() == 4 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and (Player:BuffUp(S.NetherPrecisionBuff) or (Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffDown(S.ClearcastingBuff)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 32"; end
  end
  -- arcane_barrage,if=(active_enemies>2|(active_enemies>1&target.health.pct<35&talent.arcane_bombardment))&cooldown.arcane_orb.remains<gcd.max&buff.arcane_charge.stack=4&cooldown.touch_of_the_magi.remains>gcd.max*6&(debuff.magis_spark_arcane_blast.down|!talent.magis_spark)&buff.nether_precision.up&(talent.high_voltage|((buff.leydrinker.down|(target.health.pct<35&talent.arcane_bombardment&active_enemies>=4&talent.resonance))&buff.nether_precision.stack=2)|(buff.nether_precision.stack=1&buff.clearcasting.react=0))
  if S.ArcaneBarrage:IsReady() and ((EnemiesCount8ySplash > 2 or (EnemiesCount8ySplash > 1 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable())) and S.ArcaneOrb:CooldownRemains() < Player:GCD() and Player:ArcaneCharges() == 4 and S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6 and (Target:DebuffDown(S.MagisSparkABDebuff) or not S.MagisSpark:IsAvailable()) and Player:BuffUp(S.NetherPrecisionBuff) and (S.HighVoltage:IsAvailable() or ((Player:BuffDown(S.LeydrinkerBuff) or (Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and EnemiesCount8ySplash >= 4 and S.Resonance:IsAvailable())) and Player:BuffStack(S.NetherPrecisionBuff) == 2) or (Player:BuffStack(S.NetherPrecisionBuff) == 1 and Player:BuffDown(S.ClearcastingBuff)))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 34"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&((talent.high_voltage&buff.arcane_charge.stack<4)|(buff.nether_precision.down&(buff.clearcasting.react>1|buff.spellfire_spheres.stack=6|buff.burden_of_power.up|buff.glorious_incandescence.up|(buff.intuition.react)))),interrupt_if=tick_time>gcd.remains&(buff.aether_attunement.react=0|(active_enemies>3&(!talent.time_loop|talent.resonance))),interrupt_immediate=1,interrupt_global=1,chain=1
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and ((S.HighVoltage:IsAvailable() and Player:ArcaneCharges() < 4) or (Player:BuffDown(S.NetherPrecisionBuff) and (Player:BuffStack(S.ClearcastingBuff) > 1 or Player:BuffStack(S.SpellfireSpheresBuff) == 6 or Player:BuffUp(S.BurdenofPowerBuff) or Player:BuffUp(S.GloriousIncandescenceBuff) or Player:BuffUp(S.IntuitionBuff))))) then
    LastSFAM = 2
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 36"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<3
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb sunfury 38"; end
  end
  -- arcane_barrage,if=buff.glorious_incandescence.up|buff.intuition.react
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.GloriousIncandescenceBuff) or Player:BuffUp(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 40"; end
  end
  -- presence_of_mind,if=(buff.arcane_charge.stack=3|buff.arcane_charge.stack=2)&active_enemies>=3
  if S.PresenceofMind:IsCastable() and ((Player:ArcaneCharges() == 3 or Player:ArcaneCharges() == 2) and EnemiesCount8ySplash >= 3) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind sunfury 42"; end
  end
  -- arcane_explosion,if=buff.arcane_charge.stack<2&active_enemies>1
  if S.ArcaneExplosion:IsReady() and (Player:ArcaneCharges() < 2 and EnemiesCount8ySplash > 1) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion sunfury 44"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury 46"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 48"; end
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

    -- VarSoulCD from Precombat, since we can't check active_enemies until here.
    --variable,name=soul_cd,op=set,value=1,if=set_bonus.thewarwithin_season_3_4pc&talent.spellfire_spheres&talent.resonance&!talent.magis_spark&(active_enemies>=3)&variable.soul_burst
    VarSoulCD = VarSoulBurst and TWW3_4pc and Player:HeroTreeID() == 39 and S.Resonance:IsAvailable() and not S.MagisSpark:IsAvailable() and EnemiesCount8ySplash >= 3
  end

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    -- Note: Moved from Precombat
    if S.ArcaneIntellect:IsCastable() and (Settings.Commons.AIDuringCombat or not Player:AffectingCombat()) and (S.ArcaneFamiliar:IsAvailable() and Player:BuffDown(S.ArcaneFamiliarBuff) or Everyone.GroupBuffMissing(S.ArcaneIntellect)) then
      if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- potion,if=(buff.siphon_storm.up|(!talent.evocation&cooldown.arcane_surge.ready)|((cooldown.arcane_surge.ready|buff.arcane_surge.up)&variable.soul_cd))|fight_remains<30
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.SiphonStormBuff) or (not S.Evocation:IsAvailable() and S.ArcaneSurge:CooldownUp()) or ((S.ArcaneSurge:CooldownUp() or Player:BuffUp(S.ArcaneSurgeBuff)) and VarSoulCD)) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    if CDsON() then
      -- lights_judgment,if=(buff.arcane_surge.down&debuff.touch_of_the_magi.down&buff.arcane_soul.down&buff.siphon_storm.down&active_enemies>=2)
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and Player:BuffDown(S.ArcaneSoulBuff) and Player:BuffDown(S.SiphonStormBuff) and EnemiesCount8ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 4"; end
      end
      if (Player:BuffUp(S.SiphonStormBuff) and VarSoulCD) or (Player:PrevGCDP(1, S.ArcaneSurge) and not VarSoulCD) then
        -- berserking,if=(buff.siphon_storm.up&variable.soul_cd)|(prev_gcd.1.arcane_surge&!variable.soul_cd)
        if S.Berserking:IsCastable() then
          if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
        end
        -- blood_fury,if=(buff.siphon_storm.up&variable.soul_cd)|(prev_gcd.1.arcane_surge&!variable.soul_cd)
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 8"; end
        end
        -- fireblood,if=(buff.siphon_storm.up&variable.soul_cd)|(prev_gcd.1.arcane_surge&!variable.soul_cd)
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 10"; end
        end
        -- ancestral_call,if=(buff.siphon_storm.up&variable.soul_cd)|(prev_gcd.1.arcane_surge&!variable.soul_cd)
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 12"; end
        end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=prev_gcd.1.arcane_surge
    -- invoke_external_buff,name=blessing_of_autumn,if=cooldown.touch_of_the_magi.remains>5
    -- Note: Not handling external buffs.
    -- use_items,if=(((!variable.soul_cd&prev_gcd.1.arcane_surge)|(variable.soul_cd&buff.siphon_storm.up&debuff.touch_of_the_magi.up))&(variable.steroid_trinket_equipped|(!variable.steroid_trinket_equipped&!variable.nonsteroid_trinket_equipped)))|(!variable.steroid_trinket_equipped&variable.nonsteroid_trinket_equipped)|(variable.nonsteroid_trinket_equipped&buff.siphon_storm.remains<10&(cooldown.evocation.remains>17|trinket.cooldown.remains>20))|fight_remains<20
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      local OtherTrinketCDRemains = 0
      if ItemToUse and ItemSlot == 13 then OtherTrinketCDRemains = Trinket2:CooldownRemains(); end
      if ItemToUse and ItemSlot == 14 then OtherTrinketCDRemains = Trinket1:CooldownRemains(); end
      if ItemToUse and ((((not VarSoulCD and Player:PrevGCDP(1, S.ArcaneSurge)) or (VarSoulCD and Player:BuffUp(S.SiphonStormBuff) and Target:DebuffUp(S.TouchoftheMagiDebuff))) and (VarSteroidTrinketEquipped or (not VarSteroidTrinketEquipped and not VarNonsteroidTrinketEquipped))) or (not VarSteroidTrinketEquipped and VarNonsteroidTrinketEquipped) or (VarNonsteroidTrinketEquipped and Player:BuffRemains(S.SiphonStormBuff) < 10 and (S.Evocation:CooldownRemains() > 17 or OtherTrinketCDRemains > 20)) or BossFightRemains < 20) then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " main 14"; end
        end
      end
    end
    -- variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
    -- Note: Added extra TotM checks so we don't get stuck in the opener if TotM is on CD or not talented.
    if (Target:DebuffUp(S.TouchoftheMagiDebuff) or S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 4 or not S.TouchoftheMagi:IsAvailable()) and VarOpener then
      VarOpener = false
    end
    -- arcane_barrage,if=fight_remains<2
    if S.ArcaneBarrage:IsReady() and (FightRemains < 2) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 18"; end
    end
    -- call_action_list,name=cd_opener,if=!variable.soul_cd
    if CDsON() and not VarSoulCD then
      local ShouldReturn = CDOpener(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_opener_soul,if=variable.soul_cd
    if CDsON() and VarSoulCD then
      local ShouldReturn = CDOpenerSoul(); if ShouldReturn then return ShouldReturn; end
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
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage 20"; end
    end
  end
end

local function Init()
  HR.Print("Arcane Mage rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(62, APL, Init)

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
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local strsplit   = strsplit
-- WoW API
local Delay                = C_Timer.After
local GetInventoryItemLink = GetInventoryItemLink
local IsEquippedItemType   = C_Item.IsEquippedItemType

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Frost
local I = Item.DeathKnight.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  CommonsDS = HR.GUISettings.APL.DeathKnight.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DeathKnight.CommonsOGCD,
  Frost = HR.GUISettings.APL.DeathKnight.Frost
}

--- ===== Rotation Variables =====
local VarPillarCD = (S.Icecap:IsAvailable()) and 45 or 60
local MainHandLink, OffHandLink
local MainHandRuneforge, OffHandRuneforge
local UsingRazorice, UsingFallenCrusader
local Var2HCheck
local VarRWBuffs = S.GatheringStorm:IsAvailable() or S.BitingCold:IsAvailable()
local VarSTPlanning, VarAddsRemain, VarSendingCDs
local VarRimeBuffs, VarRPBuffs, VarCDCheck
local VarOblitPoolingTime, VarBreathPoolingTime
local VarPoolingRunes, VarPoolingRP
local VarGAPriority, VarBreathDying
local EnemiesMelee, EnemiesMeleeCount
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax
local Ghoul = HL.GhoulTable

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Duration, VarTrinket2Duration
local VarTrinketPriority, VarDamageTrinketPriority
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
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

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted

  VarTrinket1Sync = 0.5
  if Trinket1:HasUseBuff() and (S.PillarofFrost:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and (VarTrinket1CD % VarPillarCD == 0) or S.BreathofSindragosa:IsAvailable() and (120 % VarTrinket1CD == 0)) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if Trinket2:HasUseBuff() and (S.PillarofFrost:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and (VarTrinket2CD % VarPillarCD == 0) or S.BreathofSindragosa:IsAvailable() and (120 % VarTrinket2CD == 0)) then
    VarTrinket2Sync = 1
  end

  VarTrinket1Buffs = Trinket1:HasCooldown() and Trinket1:HasUseBuff()
  VarTrinket2Buffs = Trinket2:HasCooldown() and Trinket2:HasUseBuff()

  -- Note: If BuffDuration is 0, set variable to 1 instead to avoid divide by zero errors.
  VarTrinket1Duration = T1.ID == I.TreacherousTransmitter:ID() and 15 or (Trinket1:BuffDuration() > 0 and Trinket1:BuffDuration() or 1)
  VarTrinket2Duration = T2.ID == I.TreacherousTransmitter:ID() and 15 or (Trinket2:BuffDuration() > 0 and Trinket2:BuffDuration() or 1)

  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs and (Trinket2:HasCooldown() or not Trinket1:HasCooldown()) or VarTrinket2Buffs and ((VarTrinket2CD / VarTrinket2Duration) * (VarTrinket2Sync) * (1 + ((VarTrinket2Level - VarTrinket1Level) / 100))) > ((VarTrinket1CD / VarTrinket1Duration) * (VarTrinket1Sync) * (1 + ((VarTrinket1Level - VarTrinket2Level) / 100))) then
    VarTrinketPriority = 2
  end

  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and VarTrinket2Level >= VarTrinket1Level then
    VarDamageTrinketPriority = 2
  end

  VarTrinket1Manual = T1.ID == I.TreacherousTransmitter:ID()
  VarTrinket2Manual = T2.ID == I.TreacherousTransmitter:ID()
end
SetTrinketVariables()

local function SetSpellVariables()
  VarBreathRPCost = 17
  VarStaticRimeBuffs = S.RageoftheFrozenChampion:IsAvailable() or S.Icebreaker:IsAvailable()
  VarBreathRPThreshold = 60
  VarERWBreathRPTrigger = 70
  VarERWBreathRuneTrigger = 3
  VarOblitRunePooling = 4
  VarBreathRimeRPThreshold = 60
end
SetSpellVariables()

--- ===== Weapon Variables =====
local function SetWeaponVariables()
  MainHandLink = GetInventoryItemLink("player", 16) or ""
  OffHandLink = GetInventoryItemLink("player", 17) or ""
  MainHandRuneforge = select(3, strsplit(":", MainHandLink))
  OffHandRuneforge = select(3, strsplit(":", OffHandLink))
  UsingRazorice = (MainHandRuneforge == "3370" or OffHandRuneforge == "3370")
  UsingFallenCrusader = (MainHandRuneforge == "3368" or OffHandRuneforge == "3368")
  Var2HCheck = IsEquippedItemType("Two-Hand")
end
SetWeaponVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarRWBuffs = S.GatheringStorm:IsAvailable() or S.BitingCold:IsAvailable()
  VarTrinketFailures = 0
  SetTrinketVariables()
  SetWeaponVariables()
  SetSpellVariables()
end, "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff)))
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterFrostStrike(TargetUnit)
  -- target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  return (num(S.ShatteringBlade:IsAvailable() and TargetUnit:DebuffStack(S.RazoriceDebuff) == 5) * 5) + (TargetUnit:DebuffStack(S.RazoriceDebuff) + 1) / (TargetUnit:DebuffRemains(S.RazoriceDebuff) + 1) * num(UsingRazorice)
end

local function EvaluateTargetIfFilterObliterate(TargetUnit)
  -- target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice+((hero_tree.deathbringer&debuff.reapers_mark_debuff.down)*5)
  return (TargetUnit:DebuffStack(S.RazoriceDebuff) + 1) / (TargetUnit:DebuffRemains(S.RazoriceDebuff) + 1) * num(UsingRazorice) + (num(Player:HeroTreeID() == 33 and Target:DebuffDown(S.ReapersMarkDebuff)) * 5)
end

local function EvaluateTargetIfFilterRazoriceStacks(TargetUnit)
  -- target_if=max:(debuff.razorice.stack)
  return TargetUnit:DebuffStack(S.RazoriceDebuff)
end

local function EvaluateTargetIfFilterRazoriceStacksModified(TargetUnit)
  -- target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  return (TargetUnit:DebuffStack(S.RazoriceDebuff) + 1) / (TargetUnit:DebuffRemains(S.RazoriceDebuff) + 1) * num(UsingRazorice)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfFrostStrikeAoE(TargetUnit)
  -- if=!variable.pooling_runic_power&debuff.razorice.stack=5&talent.shattering_blade&(talent.shattered_frost|active_enemies<4)
  -- Note: Variable, talent, and enemy count checks performed before CastTargetIf.
  return TargetUnit:DebuffStack(S.RazoriceDebuff) == 5
end

local function EvaluateTargetIfFrostStrikeObliteration(TargetUnit)
  -- if=debuff.razorice.stack=5&talent.shattering_blade&talent.a_feast_of_souls&buff.a_feast_of_souls.up&!talent.arctic_assault
  -- Note: All but RazoriceDebuff stacks checked before CastTargetIf.
  return TargetUnit:DebuffStack(S.RazoriceDebuff)
end

local function EvaluateTargetIfFrostStrikeObliteration2(TargetUnit)
  -- if=(rune<2|variable.rp_buffs|debuff.razorice.stack=5&talent.shattering_blade|hero_tree.rider_of_the_apocalypse)&!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1|talent.shattered_frost)
  -- Note: '&!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1|talent.shattered_frost)' performed before CastTargetIf.
  return Player:Rune() < 2 or VarRPBuffs or TargetUnit:DebuffStack(S.RazoriceDebuff) == 5 and S.ShatteringBlade:IsAvailable()
end

local function EvaluateTargetIfGlacialAdvanceAoE(TargetUnit)
  -- if=!variable.pooling_runic_power&(variable.ga_priority|debuff.razorice.stack<5)
  -- Note: pooling_runic_power check performed before CastTargetIf.
  return VarGAPriority or TargetUnit:DebuffStack(S.RazoriceDebuff) < 5
end

local function EvaluateTargetIfGlacialAdvanceObliteration(TargetUnit)
  -- if=(variable.ga_priority|debuff.razorice.stack<5)&(!death_knight.runeforge.razorice&(debuff.razorice.stack<5|debuff.razorice.remains<gcd*3)|((variable.rp_buffs|rune<2)&active_enemies>1))
  return (VarGAPriority or TargetUnit:DebuffStack(S.RazoriceDebuff) < 5) and (not UsingRazorice and (TargetUnit:DebuffStack(S.RazoriceDebuff) < 5 or TargetUnit:DebuffRemains(S.RazoriceDebuff) < Player:GCD() * 3) or ((VarRPBuffs or Player:Rune() < 2) and EnemiesMeleeCount > 1))
end

--- ===== CastCycle Functions =====
local function EvaluateCycleReapersMarkCDs(TargetUnit)
  -- target_if=first:!debuff.reapers_mark_debuff.up
  return TargetUnit:DebuffDown(S.ReapersMarkDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(talent.pillar_of_frost&!talent.breath_of_sindragosa&(trinket.1.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.1.cooldown.duration=0))
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(talent.pillar_of_frost&!talent.breath_of_sindragosa&(trinket.2.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.2.cooldown.duration=0))
  -- variable,name=trinket_1_buffs,value=trinket.1.has_cooldown&(trinket.1.has_use_buff|trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_cooldown&(trinket.2.has_use_buff|trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)
  -- variable,name=trinket_1_duration,op=setif,value=15,value_else=trinket.1.proc.any_dps.duration,condition=trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_duration,op=setif,value=15,value_else=trinket.2.proc.any_dps.duration,condition=trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync)*(1+((trinket.2.ilvl-trinket.1.ilvl)%100)))>((trinket.1.cooldown.duration%variable.trinket_1_duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- variable,name=trinket_1_manual,value=trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_manual,value=trinket.2.is.treacherous_transmitter
  -- Note: Manual trinkets handled via OnUseExcludes.
  -- Note: Moved the above variable definitions to initial profile load, SPELLS_CHANGED, and PLAYER_EQUIPMENT_CHANGED.
  -- variable,name=rw_buffs,value=talent.gathering_storm|talent.biting_cold
  -- Note: Handling during variable declaration and SPELLS_CHANGED/LEARNED_SPELL_IN_TAB events.
  -- variable,name=breath_rp_cost,value=dbc.power.9067.cost_per_tick%10
  -- variable,name=static_rime_buffs,value=talent.rage_of_the_frozen_champion|talent.icebreaker
  -- variable,name=breath_rp_threshold,default=60,op=reset
  -- variable,name=erw_breath_rp_trigger,default=70,op=reset
  -- variable,name=erw_breath_rune_trigger,default=3,op=reset
  -- variable,name=oblit_rune_pooling,default=4,op=reset
  -- variable,name=breath_rime_rp_threshold,default=60,op=reset
  -- Note: Handling the above during variable declaration, PLAYER_EQUIPMENT_CHANGED, and SPELLS_CHANGED/LEARNED_SPELL_IN_TAB.
  -- Manually added openers: HowlingBlast if at range, RemorselessWinter if in melee
  if S.HowlingBlast:IsReady() and not Target:IsInRange(8) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast precombat 2"; end
  end
  if S.RemorselessWinter:IsReady() and Target:IsInRange(8) then
    if Cast(S.RemorselessWinter) then return "remorseless_winter precombat 4"; end
  end
end

local function AoE()
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice+((hero_tree.deathbringer&debuff.reapers_mark_debuff.down)*5),if=buff.killing_machine.react&talent.cleaving_strikes&buff.death_and_decay.up
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and S.CleavingStrikes:IsAvailable() and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterObliterate, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 2"; end
  end
  -- howling_blast,target_if=!dot.frost_fever.ticking
  -- Note: Instead of iterating targets, checking AuraActiveCount.
  if S.HowlingBlast:IsReady() and (S.FrostFeverDebuff:AuraActiveCount() < EnemiesMeleeCount) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 4"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!variable.pooling_runic_power&debuff.razorice.stack=5&talent.shattering_blade&(talent.shattered_frost|active_enemies<4)
  if S.FrostStrike:IsReady() and (not VarPoolingRP and S.ShatteringBlade:IsAvailable() and (S.ShatteredFrost:IsAvailable() or EnemiesMeleeCount < 4)) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, EvaluateTargetIfFrostStrikeAoE, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike aoe 6"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 8"; end
  end
  -- glacial_advance,target_if=max:(debuff.razorice.stack),if=!variable.pooling_runic_power&(variable.ga_priority|debuff.razorice.stack<5)
  if S.GlacialAdvance:IsReady() and (not VarPoolingRP) then
    if Everyone.CastTargetIf(S.GlacialAdvance, EnemiesMelee, "max", EvaluateTargetIfFilterRazoriceStacks, EvaluateTargetIfGlacialAdvanceAoE, not Target:IsInRange(100)) then return "glacial_advance aoe 10"; end
  end
  -- obliterate
  if S.Obliterate:IsReady() then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 12"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!variable.pooling_runic_power
  if S.FrostStrike:IsReady() and (not VarPoolingRP) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike)) then return "frost_strike aoe 14"; end
  end
  -- horn_of_winter,if=rune<2&runic_power.deficit>25&(!talent.breath_of_sindragosa|variable.true_breath_cooldown>cooldown.horn_of_winter.duration-15)
  if S.HornofWinter:IsCastable() and (Player:Rune() < 2 and Player:RunicPowerDeficit() > 25 and (not S.BreathofSindragosa:IsAvailable() or VarTrueBreathCD > 30)) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter aoe 16"; end
  end
  -- arcane_torrent,if=runic_power.deficit>25
  if CDsON() and S.ArcaneTorrent:IsReady() and (Player:RunicPowerDeficit() > 25) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent aoe 18"; end
  end
end

local function Breath()
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice+((hero_tree.deathbringer&debuff.reapers_mark_debuff.down)*5),if=buff.killing_machine.react=2
  if S.Obliterate:IsReady() and (Player:BuffStack(S.KillingMachineBuff) == 2) then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterObliterate, nil, not Target:IsInMeleeRange(5)) then return "obliterate breath 1"; end
  end
  -- howling_blast,if=variable.rime_buffs&runic_power>(variable.breath_rime_rp_threshold-(talent.rage_of_the_frozen_champion*(dbc.effect.842306.base_value%10)))|!dot.frost_fever.ticking
  -- Note: dbc.effect.842306.base_value as of 11.0.0.55793 is 60.
  if S.HowlingBlast:IsReady() and (VarRimeBuffs and Player:RunicPower() > (VarBreathRimeRPThreshold - (num(S.RageoftheFrozenChampion:IsAvailable()) * 6)) or Target:DebuffDown(S.FrostFeverDebuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath 2"; end
  end
  -- horn_of_winter,if=rune<2&runic_power.deficit>30&(!buff.empower_rune_weapon.up|runic_power<variable.breath_rp_cost*2*gcd.max)
  if S.HornofWinter:IsReady() and (Player:Rune() < 2 and Player:RunicPowerDeficit() > 30 and (Player:BuffDown(S.EmpowerRuneWeaponBuff) or Player:RunicPower() < VarBreathRPCost * 2 * Player:GCD())) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter breath 4"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice+((hero_tree.deathbringer&debuff.reapers_mark_debuff.down)*5),if=buff.killing_machine.react|runic_power.deficit>20
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) or Player:RunicPowerDeficit() > 20) then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterObliterate, nil, not Target:IsInMeleeRange(5)) then return "obliterate breath 6"; end
  end
  -- remorseless_winter,if=variable.breath_dying
  if S.RemorselessWinter:IsReady() and (VarBreathDying) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter breath 8"; end
  end
  -- death_and_decay,if=!death_and_decay.ticking&(variable.st_planning&talent.unholy_ground&runic_power.deficit>=10&!talent.obliteration|variable.breath_dying)
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (VarSTPlanning and S.UnholyGround:IsAvailable() and Player:RunicPowerDeficit() >= 10 and not S.Obliteration:IsAvailable() or VarBreathDying)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay, nil, not Target:IsSpellInRange(S.DeathAndDecay)) then return "death_and_decay breath 10"; end
  end
  -- howling_blast,if=variable.breath_dying
  if S.HowlingBlast:IsReady() and (VarBreathDying) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath 12"; end
  end
  -- arcane_torrent,if=runic_power<60
  if S.ArcaneTorrent:IsReady() and (Player:RunicPower() < 60) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent breath 14"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath 16"; end
  end
end

local function ColdHeart()
  -- chains_of_ice,if=fight_remains<gcd&(rune<2|!buff.killing_machine.react&(!main_hand.2h&buff.cold_heart.stack>=4|main_hand.2h&buff.cold_heart.stack>8)|buff.killing_machine.react&(!main_hand.2h&buff.cold_heart.stack>8|main_hand.2h&buff.cold_heart.stack>10))
  if S.ChainsofIce:IsReady() and (FightRemains < Player:GCD() and (Player:Rune() < 2 or Player:BuffDown(S.KillingMachineBuff) and (not Var2HCheck and Player:BuffStack(S.ColdHeartBuff) >= 4 or Var2HCheck and Player:BuffStack(S.ColdHeartBuff) > 8) or Player:BuffUp(S.KillingMachineBuff) and (not Var2HCheck and Player:BuffStack(S.ColdHeartBuff) > 8 or Var2HCheck and Player:BuffStack(S.ColdHeartBuff) > 10))) then
    if Cast(S.ChainsofIce, Settings.CommonsOGCD.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 2"; end
  end
  -- chains_of_ice,if=!talent.obliteration&buff.pillar_of_frost.up&buff.cold_heart.stack>=10&(buff.pillar_of_frost.remains<gcd*(1+(talent.frostwyrms_fury&cooldown.frostwyrms_fury.ready))|buff.unholy_strength.up&buff.unholy_strength.remains<gcd)
  if S.ChainsofIce:IsReady() and (not S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffStack(S.ColdHeartBuff) >= 10 and (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * (1 + num(S.FrostwyrmsFury:IsAvailable() and S.FrostwyrmsFury:IsReady())) or Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD())) then
    if Cast(S.ChainsofIce, Settings.CommonsOGCD.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 4"; end
  end
  -- chains_of_ice,if=!talent.obliteration&death_knight.runeforge.fallen_crusader&!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains>15&(buff.cold_heart.stack>=10&buff.unholy_strength.up|buff.cold_heart.stack>=13)
  if S.ChainsofIce:IsReady() and (not S.Obliteration:IsAvailable() and UsingFallenCrusader and Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 15 and (Player:BuffStack(S.ColdHeartBuff) >= 10 and Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffStack(S.ColdHeartBuff) >= 13)) then
    if Cast(S.ChainsofIce, Settings.CommonsOGCD.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 6"; end
  end
  -- chains_of_ice,if=!talent.obliteration&!death_knight.runeforge.fallen_crusader&buff.cold_heart.stack>=10&!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains>20
  if S.ChainsofIce:IsReady() and (not S.Obliteration:IsAvailable() and not UsingFallenCrusader and Player:BuffStack(S.ColdHeartBuff) >= 10 and Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 20) then
    if Cast(S.ChainsofIce, Settings.CommonsOGCD.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 8"; end
  end
  -- chains_of_ice,if=talent.obliteration&!buff.pillar_of_frost.up&(buff.cold_heart.stack>=14&buff.unholy_strength.up|buff.cold_heart.stack>=19|cooldown.pillar_of_frost.remains<3&buff.cold_heart.stack>=14)
  if S.ChainsofIce:IsReady() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and (Player:BuffStack(S.ColdHeartBuff) >= 14 and Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffStack(S.ColdHeartBuff) >= 19 or S.PillarofFrost:CooldownRemains() < 3 and Player:BuffStack(S.ColdHeartBuff) >= 14)) then
    if Cast(S.ChainsofIce, Settings.CommonsOGCD.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 10"; end
  end
end

local function Cooldowns()
  -- potion,if=(talent.pillar_of_frost&buff.pillar_of_frost.up|!talent.pillar_of_frost&buff.empower_rune_weapon.up|!talent.pillar_of_frost&!talent.empower_rune_weapon|active_enemies>=2&buff.pillar_of_frost.up)|fight_remains<25
  if Settings.Commons.Enabled.Potions and ((S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) or not S.PillarofFrost:IsAvailable() and Player:BuffUp(S.EmpowerRuneWeaponBuff) or not S.PillarofFrost:IsAvailable() and not S.EmpowerRuneWeapon:IsAvailable() or EnemiesMeleeCount >= 2 and Player:BuffUp(S.PillarofFrostBuff)) or BossFightRemains < 25) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldowns 2"; end
    end
  end
  -- abomination_limb,if=talent.obliteration&!buff.pillar_of_frost.up&variable.sending_cds|fight_remains<15
  -- abomination_limb,if=!talent.obliteration&variable.sending_cds
  -- Note: Combined the lines.
  if S.AbominationLimb:IsCastable() and ((S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and VarSendingCDs or BossFightRemains < 15) or (not S.Obliteration:IsAvailable() and VarSendingCDs)) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb_talent cooldowns 4"; end
  end
  -- remorseless_winter,if=variable.rw_buffs&variable.sending_cds&(!talent.arctic_assault|!buff.pillar_of_frost.up)&fight_remains>10
  if S.RemorselessWinter:IsReady() and (VarRWBuffs and VarSendingCDs and (not S.ArcticAssault:IsAvailable() or Player:BuffDown(S.PillarofFrostBuff)) and FightRemains > 10) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter cooldowns 6"; end
  end
  -- chill_streak,if=variable.sending_cds&(!talent.arctic_assault|!buff.pillar_of_frost.up)
  if S.ChillStreak:IsReady() and (VarSendingCDs and (not S.ArcticAssault:IsAvailable() or Player:BuffDown(S.PillarofFrostBuff))) then
    if Cast(S.ChillStreak, Settings.Frost.GCDasOffGCD.ChillStreak, nil, not Target:IsSpellInRange(S.ChillStreak)) then return "chill_streak cooldowns 8"; end
  end
  -- reapers_mark,target_if=first:debuff.reapers_mark_debuff.down,if=!talent.breath_of_sindragosa&(buff.pillar_of_frost.up|cooldown.pillar_of_frost.remains>10)|talent.breath_of_sindragosa
  if S.ReapersMark:IsReady() and (not S.BreathofSindragosa:IsAvailable() and (Player:BuffUp(S.PillarofFrostBuff) or S.PillarofFrost:CooldownRemains() > 10) or S.BreathofSindragosa:IsAvailable()) then
    if Everyone.CastCycle(S.ReapersMark, EnemiesMelee, EvaluateCycleReapersMarkCDs, not Target:IsInMeleeRange(5), Settings.Frost.GCDasOffGCD.ReapersMark) then return "reapers_mark cooldowns 10"; end
  end
  -- empower_rune_weapon,if=talent.obliteration&!talent.breath_of_sindragosa&buff.pillar_of_frost.up|fight_remains<20
  if S.EmpowerRuneWeapon:IsCastable() and (S.Obliteration:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) or BossFightRemains < 20) then
    if Cast(S.EmpowerRuneWeapon, Settings.CommonsOGCD.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 12"; end
  end
  -- empower_rune_weapon,if=buff.breath_of_sindragosa.up&runic_power<variable.erw_breath_rp_trigger&rune<variable.erw_breath_rune_trigger
  if S.EmpowerRuneWeapon:IsCastable() and (Player:BuffUp(S.BreathofSindragosa) and Player:RunicPower() < VarERWBreathRPTrigger and Player:Rune() < VarERWBreathRuneTrigger) then
    if Cast(S.EmpowerRuneWeapon, Settings.CommonsOGCD.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 14"; end
  end
  -- empower_rune_weapon,if=!talent.breath_of_sindragosa&!talent.obliteration&!buff.empower_rune_weapon.up&rune<5&(cooldown.pillar_of_frost.remains<7|buff.pillar_of_frost.up|!talent.pillar_of_frost)
  if S.EmpowerRuneWeapon:IsCastable() and (not S.BreathofSindragosa:IsAvailable() and not S.Obliteration:IsAvailable() and Player:BuffDown(S.EmpowerRuneWeaponBuff) and Player:Rune() < 5 and (S.PillarofFrost:CooldownRemains() < 7 or Player:BuffUp(S.PillarofFrostBuff) or not S.PillarofFrost:IsAvailable())) then
    if Cast(S.EmpowerRuneWeapon, Settings.CommonsOGCD.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 16"; end
  end
  -- pillar_of_frost,if=talent.obliteration&!talent.breath_of_sindragosa&variable.sending_cds|fight_remains<20
  if S.PillarofFrost:IsCastable() and (S.Obliteration:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and VarSendingCDs or BossFightRemains < 20) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 18"; end
  end
  -- pillar_of_frost,if=talent.breath_of_sindragosa&variable.sending_cds&cooldown.breath_of_sindragosa.remains&buff.unleashed_frenzy.up
  if S.PillarofFrost:IsCastable() and (S.BreathofSindragosa:IsAvailable() and VarSendingCDs and S.BreathofSindragosa:CooldownDown() and Player:BuffUp(S.UnleashedFrenzyBuff)) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 20"; end
  end
  -- pillar_of_frost,if=!talent.obliteration&!talent.breath_of_sindragosa&variable.sending_cds
  if S.PillarofFrost:IsCastable() and (not S.Obliteration:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and VarSendingCDs) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 22"; end
  end
  -- breath_of_sindragosa,use_off_gcd=1,if=!buff.breath_of_sindragosa.up&runic_power>variable.breath_rp_threshold&(rune<2|runic_power>80)&(cooldown.pillar_of_frost.ready&variable.sending_cds|fight_remains<30)|(time<10&rune<1)
  if S.BreathofSindragosa:IsReady() and (Player:BuffDown(S.BreathofSindragosa) and Player:RunicPower() > VarBreathRPThreshold and (Player:Rune() < 2 or Player:RunicPower() > 80) and (S.PillarofFrost:CooldownUp() and VarSendingCDs or BossFightRemains < 30) or (HL.CombatTime() < 10 and Player:Rune() < 1)) then
    if Cast(S.BreathofSindragosa, Settings.Frost.GCDasOffGCD.BreathOfSindragosa, nil, not Target:IsInRange(12)) then return "breath_of_sindragosa cooldowns 24"; end
  end
  -- frostwyrms_fury,if=hero_tree.rider_of_the_apocalypse&talent.apocalypse_now&variable.sending_cds&(!talent.breath_of_sindragosa&buff.pillar_of_frost.up|buff.breath_of_sindragosa.up)|fight_remains<20
  if S.FrostwyrmsFury:IsCastable() and (Player:HeroTreeID() == 32 and S.ApocalypseNow:IsAvailable() and VarSendingCDs and (not S.BreathofSindragosa:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) or Player:BuffUp(S.BreathofSindragosa)) or BossFightRemains < 30) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 26"; end
  end
  -- frostwyrms_fury,if=!talent.apocalypse_now&active_enemies=1&(talent.pillar_of_frost&buff.pillar_of_frost.up&!talent.obliteration|!talent.pillar_of_frost)&(!raid_event.adds.exists|(raid_event.adds.in>15+raid_event.adds.duration|talent.absolute_zero&raid_event.adds.in>15+raid_event.adds.duration))|fight_remains<3
  if S.FrostwyrmsFury:IsCastable() and (not S.ApocalypseNow:IsAvailable() and EnemiesMeleeCount == 1 and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and not S.Obliteration:IsAvailable() or not S.PillarofFrost:IsAvailable()) or BossFightRemains < 3) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 28"; end
  end
  -- frostwyrms_fury,if=!talent.apocalypse_now&active_enemies>=2&(talent.pillar_of_frost&buff.pillar_of_frost.up|raid_event.adds.exists&raid_event.adds.up&raid_event.adds.in<cooldown.pillar_of_frost.remains-raid_event.adds.in-raid_event.adds.duration)
  if S.FrostwyrmsFury:IsCastable() and (not S.ApocalypseNow:IsAvailable() and EnemiesMeleeCount >= 2 and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff))) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 30"; end
  end
  -- frostwyrms_fury,if=!talent.apocalypse_now&talent.obliteration&(talent.pillar_of_frost&buff.pillar_of_frost.up&!main_hand.2h|!buff.pillar_of_frost.up&main_hand.2h&cooldown.pillar_of_frost.remains|!talent.pillar_of_frost)&(buff.pillar_of_frost.remains<gcd|(buff.unholy_strength.up&buff.unholy_strength.remains<gcd)|(talent.bonegrinder.rank=2&buff.bonegrinder_frost.up&buff.bonegrinder_frost.remains<gcd))&(debuff.razorice.stack=5|!death_knight.runeforge.razorice&!talent.glacial_advance|talent.shattering_blade)
  if S.FrostwyrmsFury:IsCastable() and (not S.ApocalypseNow:IsAvailable() and S.Obliteration:IsAvailable() and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and not Var2HCheck or Player:BuffDown(S.PillarofFrostBuff) and Var2HCheck and S.PillarofFrost:CooldownDown() or not S.PillarofFrost:IsAvailable()) and (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() or (Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD()) or (S.Bonegrinder:TalentRank() == 2 and Player:BuffUp(S.BonegrinderFrostBuff) and Player:BuffRemains(S.BonegrinderFrostBuff) < Player:GCD())) and (Target:DebuffStack(S.RazoriceDebuff) == 5 or not UsingRazorice and not S.GlacialAdvance:IsAvailable() or S.ShatteringBlade:IsAvailable())) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 32"; end
  end
  -- raise_dead,use_off_gcd=1
  if S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 34"; end
  end
  -- soul_reaper,if=fight_remains>5&target.time_to_pct_35<5&target.time_to_pct_0>5&active_enemies<=1&(talent.obliteration&(buff.pillar_of_frost.up&!buff.killing_machine.react&rune>2|!buff.pillar_of_frost.up|buff.killing_machine.react<2&!buff.exterminate.up&!buff.exterminate_painful_death.up&buff.pillar_of_frost.remains<gcd)|talent.breath_of_sindragosa&(buff.breath_of_sindragosa.up&runic_power>50|!buff.breath_of_sindragosa.up)|!talent.breath_of_sindragosa&!talent.obliteration)
  if S.SoulReaper:IsReady() and (FightRemains > 5 and Target:TimeToX(35) < 5 and Target:TimeToX(0) > 5 and EnemiesMeleeCount <= 1 and (S.Obliteration:IsAvailable() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffDown(S.KillingMachineBuff) and Player:Rune() > 2 or Player:BuffDown(S.PillarofFrostBuff) or Player:BuffStack(S.KillingMachineBuff) < 2 and Player:BuffDown(S.ExterminateBuff) and Player:BuffDown(S.PainfulDeathBuff) and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD()) or S.BreathofSindragosa:IsAvailable() and (Player:BuffUp(S.BreathofSindragosa) and Player:RunicPower() > 50 or Player:BuffDown(S.BreathofSindragosa)) or not S.BreathofSindragosa:IsAvailable() and not S.Obliteration:IsAvailable())) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper cooldowns 36"; end
  end
  -- frostscythe,if=!buff.killing_machine.react&(!talent.arctic_assault|!buff.pillar_of_frost.up)
  if S.Frostscythe:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and (not S.ArcticAssault:IsAvailable() or Player:BuffDown(S.PillarofFrostBuff))) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe cooldowns 38"; end
  end
  -- any_dnd,if=!buff.death_and_decay.up&variable.adds_remain&(buff.pillar_of_frost.up&buff.killing_machine.react&(talent.enduring_strength|buff.pillar_of_frost.remains>5)|!buff.pillar_of_frost.up&(cooldown.death_and_decay.charges=2|cooldown.pillar_of_frost.remains>cooldown.death_and_decay.duration|!talent.the_long_winter&cooldown.pillar_of_frost.remains<gcd.max*2)|fight_remains<15)&(active_enemies>5|talent.cleaving_strikes&active_enemies>=2)
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and VarAddsRemain and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.KillingMachineBuff) and (S.EnduringStrength:IsAvailable() or Player:BuffRemains(S.PillarofFrostBuff) > 5) or Player:BuffDown(S.PillarofFrostBuff) and (S.DeathAndDecay:Charges() == 2 or S.PillarofFrost:CooldownRemains() > S.DeathAndDecay:Cooldown() or not S.TheLongWinter:IsAvailable() and S.PillarofFrost:CooldownRemains() < Player:GCD() * 2) or BossFightRemains < 15) and (EnemiesMeleeCount > 5 or S.CleavingStrikes:IsAvailable() and EnemiesMeleeCount >= 2)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay cooldowns 40"; end
  end
end

local function HighPrioActions()
  -- mind_freeze,if=target.debuff.casting.react
  local ShouldReturn = Everyone.Interrupt(S.MindFreeze, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
  -- invoke_external_buff,name=power_infusion,if=(buff.pillar_of_frost.up|!talent.pillar_of_frost)&(talent.obliteration|talent.breath_of_sindragosa&buff.breath_of_sindragosa.up|!talent.breath_of_sindragosa&!talent.obliteration)
  -- Note: Not handling external buffs.
  -- antimagic_shell,if=runic_power.deficit>40&death_knight.first_ams_cast<time&(!talent.breath_of_sindragosa|talent.breath_of_sindragosa&variable.true_breath_cooldown>cooldown.antimagic_shell.duration)
  -- In simc, the default of this setting is 20s.
  -- TODO: Maybe make this a setting?
  local VarAMSCD = S.AntiMagicBarrier:IsAvailable() and 40 or 60
  VarAMSCD = S.UnyieldingWill:IsAvailable() and VarAMSCD + 20 or VarAMSCD
  if Settings.Commons.UseAMSAMZOffensively and CDsON() and S.AntiMagicShell:IsCastable() and (Player:RunicPowerDeficit() > 40 and 20 < HL.CombatTime() and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:IsAvailable() and VarTrueBreathCD > VarAMSCD)) then
    if Cast(S.AntiMagicShell, Settings.CommonsOGCD.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell high_prio_actions 2"; end
  end
  -- howling_blast,if=!dot.frost_fever.ticking&active_enemies>=2&(!talent.obliteration|talent.obliteration&(!cooldown.pillar_of_frost.ready|buff.pillar_of_frost.up&!buff.killing_machine.react))
  if S.HowlingBlast:IsReady() and (Target:DebuffDown(S.FrostFeverDebuff) and EnemiesMeleeCount >= 2 and (not S.Obliteration:IsAvailable() or S.Obliteration:IsAvailable() and (S.PillarofFrost:CooldownDown() or Player:BuffUp(S.PillarofFrostBuff) and Player:BuffDown(S.KillingMachineBuff)))) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast high_prio_actions 6"; end
  end
  -- glacial_advance,if=variable.ga_priority&variable.rp_buffs&talent.obliteration&talent.breath_of_sindragosa&!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
  if S.GlacialAdvance:IsReady() and (VarGAPriority and VarRPBuffs and S.Obliteration:IsAvailable() and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance high_prio_actions 8"; end
  end
  -- glacial_advance,if=variable.ga_priority&variable.rp_buffs&talent.breath_of_sindragosa&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
  if S.GlacialAdvance:IsReady() and (VarGAPriority and VarRPBuffs and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance high_prio_actions 10"; end
  end
  -- glacial_advance,if=variable.ga_priority&variable.rp_buffs&!talent.breath_of_sindragosa&talent.obliteration&!buff.pillar_of_frost.up&!talent.shattered_frost
  if S.GlacialAdvance:IsReady() and (VarGAPriority and VarRPBuffs and not S.BreathofSindragosa:IsAvailable() and S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and not S.ShatteredFrost:IsAvailable()) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance high_prio_actions 12"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=active_enemies=1&variable.rp_buffs&talent.obliteration&talent.breath_of_sindragosa&!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
  if S.FrostStrike:IsReady() and (EnemiesMeleeCount == 1 and VarRPBuffs and S.Obliteration:IsAvailable() and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike high_prio_actions 14"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=active_enemies=1&variable.rp_buffs&talent.breath_of_sindragosa&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
  if S.FrostStrike:IsReady() and (EnemiesMeleeCount == 1 and VarRPBuffs and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike high_prio_actions 16"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=active_enemies=1&variable.rp_buffs&!talent.breath_of_sindragosa&talent.obliteration&!buff.pillar_of_frost.up
  if S.FrostStrike:IsReady() and (EnemiesMeleeCount == 1 and VarRPBuffs and not S.BreathofSindragosa:IsAvailable() and S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff)) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike high_prio_actions 18"; end
  end
end

local function Obliteration()
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice+((hero_tree.deathbringer&debuff.reapers_mark_debuff.down)*5),if=buff.killing_machine.react&(buff.exterminate.up|buff.exterminate_painful_death.up|fight_remains<gcd*2)
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and (Player:BuffUp(S.ExterminateBuff) or Player:BuffUp(S.PainfulDeathBuff) or BossFightRemains < Player:GCD() * 2)) then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterObliterate, nil, not Target:IsSpellInRange(S.Obliterate)) then return "obliterate obliteration 1"; end
  end
  -- howling_blast,if=buff.killing_machine.react<2&buff.pillar_of_frost.remains<gcd&variable.rime_buffs
  if S.HowlingBlast:IsReady() and (Player:BuffStack(S.KillingMachineBuff) < 2 and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() and VarRimeBuffs) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 2"; end
  end
  -- glacial_advance,if=buff.killing_machine.react<2&buff.pillar_of_frost.remains<gcd&!buff.death_and_decay.up&variable.ga_priority
  if S.GlacialAdvance:IsReady() and (Player:BuffStack(S.KillingMachineBuff) < 2 and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() and Player:BuffDown(S.DeathAndDecayBuff) and VarGAPriority) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance obliteration 4"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react<2&buff.pillar_of_frost.remains<gcd&!buff.death_and_decay.up
  if S.FrostStrike:IsReady() and (Player:BuffStack(S.KillingMachineBuff) < 2 and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() and Player:BuffDown(S.DeathAndDecayBuff)) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike obliteration 6"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=debuff.razorice.stack=5&talent.shattering_blade&talent.a_feast_of_souls&buff.a_feast_of_souls.up
  if S.FrostStrike:IsReady() and (S.ShatteringBlade:IsAvailable() and S.AFeastofSouls:IsAvailable() and Player:BuffUp(S.AFeastofSoulsBuff)) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, EvaluateTargetIfFrostStrikeObliteration, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike obliteration 8"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff)) then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterRazoriceStacksModified, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 10"; end
  end
  -- howling_blast,target_if=!dot.frost_fever.ticking,if=!buff.killing_machine.react
  -- Note: Instead of iterating targets, checking AuraActiveCount.
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and S.FrostFeverDebuff:AuraActiveCount() < EnemiesMeleeCount) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 12"; end
  end
  -- glacial_advance,target_if=max:(debuff.razorice.stack),if=(variable.ga_priority|debuff.razorice.stack<5)&(!death_knight.runeforge.razorice&(debuff.razorice.stack<5|debuff.razorice.remains<gcd*3)|((variable.rp_buffs|rune<2)&active_enemies>1))
  if S.GlacialAdvance:IsReady() then
    if Everyone.CastTargetIf(S.GlacialAdvance, EnemiesMelee, "max", EvaluateTargetIfFilterRazoriceStacks, EvaluateTargetIfGlacialAdvanceObliteration, not Target:IsInRange(100)) then return "glacial_advance obliteration 14"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=(rune<2|variable.rp_buffs|debuff.razorice.stack=5&talent.shattering_blade)&!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1|talent.shattered_frost)
  if S.FrostStrike:IsReady() and (not VarPoolingRP and (not S.GlacialAdvance:IsAvailable() or EnemiesMeleeCount == 1 or S.ShatteredFrost:IsAvailable())) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, EvaluateTargetIfFrostStrikeObliteration2, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike obliteration 16"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 18"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1|talent.shattered_frost)
  if S.FrostStrike:IsReady() and (not VarPoolingRP and (not S.GlacialAdvance:IsAvailable() or EnemiesMeleeCount == 1 or S.ShatteredFrost:IsAvailable())) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike obliteration 20"; end
  end
  -- glacial_advance,target_if=max:(debuff.razorice.stack),if=!variable.pooling_runic_power&variable.ga_priority
  if S.GlacialAdvance:IsReady() and (not VarPoolingRP and VarGAPriority) then
    if Everyone.CastTargetIf(S.GlacialAdvance, EnemiesMelee, "max", EvaluateTargetIfFilterRazoriceStacks, nil, not Target:IsInRange(100)) then return "glacial_advance obliteration 22"; end
  end
  -- frost_strike,target_if=max:((talent.shattering_blade&debuff.razorice.stack=5)*5)+(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!variable.pooling_runic_power
  if S.FrostStrike:IsReady() and (not VarPoolingRP) then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike obliteration 24"; end
  end
  -- horn_of_winter,if=rune<3
  if S.HornofWinter:IsReady() and (Player:Rune() < 3) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter obliteration 26"; end
  end
  -- arcane_torrent,if=rune<1&runic_power<30
  if CDsON() and S.ArcaneTorrent:IsReady() and (Player:Rune() < 1 and Player:RunicPower() < 30) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent obliteration 28"; end
  end
  -- howling_blast,if=!buff.killing_machine.react
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 30"; end
  end
end

local function Racials()
  if (VarCDCheck) then
    -- blood_fury,if=variable.cooldown_check
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racials 2"; end
    end
    -- berserking,if=variable.cooldown_check
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racials 4"; end
    end
    -- arcane_pulse,if=variable.cooldown_check
    if S.ArcanePulse:IsCastable() then
      if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
    end
    -- lights_judgment,if=variable.cooldown_check
    if S.LightsJudgment:IsCastable() then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
    end
    -- ancestral_call,if=variable.cooldown_check
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
    end
    -- fireblood,if=variable.cooldown_check
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racials 12"; end
    end
  end
  -- bag_of_tricks,if=talent.obliteration&!buff.pillar_of_frost.up&buff.unholy_strength.up
  if S.BagofTricks:IsCastable() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 14"; end
  end
  -- bag_of_tricks,if=!talent.obliteration&buff.pillar_of_frost.up&(buff.unholy_strength.up&buff.unholy_strength.remains<gcd*3|buff.pillar_of_frost.remains<gcd*3)
  if S.BagofTricks:IsCastable() and (not S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and (Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD() * 3 or Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * 3)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 16"; end
  end
end

local function SingleTarget()
  -- frost_strike,if=talent.a_feast_of_souls&debuff.razorice.stack=5&talent.shattering_blade&buff.a_feast_of_souls.up
  if S.FrostStrike:IsReady() and (S.AFeastofSouls:IsAvailable() and Target:DebuffStack(S.RazoriceDebuff) == 5 and S.ShatteringBlade:IsAvailable() and Player:BuffUp(S.AFeastofSoulsBuff)) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 2"; end
  end
  -- obliterate,if=buff.killing_machine.react=2|buff.exterminate.up|buff.exterminate_painful_death.up
  if S.Obliterate:IsReady() and (Player:BuffStack(S.KillingMachineBuff) == 2 or Player:BuffUp(S.ExterminateBuff) or Player:BuffUp(S.PainfulDeathBuff)) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 4"; end
  end
  -- horn_of_winter,if=(!talent.breath_of_sindragosa|variable.true_breath_cooldown>cooldown.horn_of_winter.duration-15)&cooldown.pillar_of_frost.remains<variable.oblit_pooling_time
  if S.HornofWinter:IsReady() and ((not S.BreathofSindragosa:IsAvailable() or VarTrueBreathCD > 30) and S.PillarofFrost:CooldownRemains() < VarOblitPoolingTime) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter single_target 6"; end
  end
  -- frost_strike,if=(debuff.razorice.stack=5&talent.shattering_blade)|(rune<2&!talent.icebreaker)
  if S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) == 5 and S.ShatteringBlade:IsAvailable()) or (Player:Rune() < 2 and not S.Icebreaker:IsAvailable())) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 8"; end
  end
  -- howling_blast,if=variable.rime_buffs&(!talent.breath_of_sindragosa|talent.rage_of_the_frozen_champion|cooldown.breath_of_sindragosa.remains)
  if S.HowlingBlast:IsReady() and (VarRimeBuffs and (not S.BreathofSindragosa:IsAvailable() or S.RageoftheFrozenChampion:IsAvailable() or S.BreathofSindragosa:CooldownDown())) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 10"; end
  end
  -- obliterate,if=buff.killing_machine.react&!variable.pooling_runes
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarPoolingRunes) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 12"; end
  end
  -- glacial_advance,if=!variable.pooling_runic_power&!death_knight.runeforge.razorice&(debuff.razorice.stack<5|debuff.razorice.remains<gcd*3)
  if S.GlacialAdvance:IsReady() and (not VarPoolingRP and not UsingRazorice and (Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < Player:GCD() * 3)) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance single_target 14"; end
  end
  -- frost_strike,if=!variable.pooling_runic_power&(variable.rp_buffs|(!talent.shattering_blade&runic_power.deficit<20))
  if S.FrostStrike:IsReady() and (not VarPoolingRP and (VarRPBuffs or (not S.ShatteringBlade:IsAvailable() and Player:RunicPowerDeficit() < 20))) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 16"; end
  end
  -- howling_blast,if=buff.rime.react&(!talent.breath_of_sindragosa|talent.rage_of_the_frozen_champion|cooldown.breath_of_sindragosa.remains)
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff) and (not S.BreathofSindragosa:IsAvailable() or S.RageoftheFrozenChampion:IsAvailable() or S.BreathofSindragosa:CooldownDown())) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 18"; end
  end
  -- frost_strike,if=!variable.pooling_runic_power&!(main_hand.2h|talent.shattering_blade)
  if S.FrostStrike:IsReady() and (not VarPoolingRP and not (Var2HCheck or S.ShatteringBlade:IsAvailable())) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 20"; end
  end
  -- obliterate,if=!variable.pooling_runes
  if S.Obliterate:IsReady() and (not VarPoolingRunes) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 22"; end
  end
  -- frost_strike,if=!variable.pooling_runic_power
  if S.FrostStrike:IsReady() and (not VarPoolingRP) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 24"; end
  end
  -- any_dnd,if=talent.breath_of_sindragosa&!buff.breath_of_sindragosa.up&!variable.true_breath_cooldown&rune<2&!buff.death_and_decay.up
  if S.DeathAndDecay:IsReady() and (S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and not bool(VarTrueBreathCD) and Player:Rune() < 2 and Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay single_target 26"; end
  end
  -- howling_blast,if=!dot.frost_fever.ticking
  if S.HowlingBlast:IsReady() and (Target:DebuffDown(S.FrostFeverDebuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 28"; end
  end
  -- horn_of_winter,if=rune<2&runic_power.deficit>25&(!talent.breath_of_sindragosa|variable.true_breath_cooldown>cooldown.horn_of_winter.duration-15)
  if S.HornofWinter:IsReady() and (Player:Rune() < 2 and Player:RunicPowerDeficit() > 25 and (not S.BreathofSindragosa:IsAvailable() or VarTrueBreathCD > 30)) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter single_target 30"; end
  end
  -- arcane_torrent,if=!talent.breath_of_sindragosa&runic_power.deficit>20
  if CDsON() and S.ArcaneTorrent:IsReady() and (not S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent single_target 32"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,name=treacherous_transmitter,if=cooldown.pillar_of_frost.remains<6&(!talent.breath_of_sindragosa|(buff.breath_of_sindragosa.up|variable.true_breath_cooldown<6))|fight_remains<30
    if I.TreacherousTransmitter:IsEquippedAndReady() and (S.PillarofFrost:CooldownRemains() < 6 and (not S.BreathofSindragosa:IsAvailable() or (Player:BuffUp(S.BreathofSindragosa) or VarTrueBreathCD < 6)) or BossFightRemains < 30) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter trinkets 2"; end
    end
    -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.pillar_of_frost.up|fight_remains<15
    -- use_item,slot=trinket1,if=!trinket.1.cast_time>0&variable.trinket_1_buffs&!variable.trinket_1_manual&(buff.pillar_of_frost.remains>variable.trinket_1_duration%2)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)
    if Trinket1:IsReady() and not VarTrinket1BL and (VarTrinket1CastTime == 0 and VarTrinket1Buffs and not VarTrinket1Manual and (Player:BuffRemains(S.PillarofFrostBuff) > VarTrinket1Duration / 2) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=!trinket.2.cast_time>0&variable.trinket_2_buffs&!variable.trinket_2_manual&(buff.pillar_of_frost.remains>variable.trinket_2_duration%2)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)
    if Trinket2:IsReady() and not VarTrinket2BL and (VarTrinket1CastTime == 0 and VarTrinket2Buffs and not VarTrinket2Manual and (Player:BuffRemains(S.PillarofFrostBuff) > VarTrinket2Duration / 2) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 6"; end
    end
    -- use_item,slot=trinket1,use_off_gcd=1,if=trinket.1.cast_time>0&variable.trinket_1_buffs&!variable.trinket_1_manual&!buff.pillar_of_frost.up&(!talent.breath_of_sindragosa|!buff.breath_of_sindragosa.up&runic_power>variable.breath_rp_threshold&(cooldown.pillar_of_frost.ready&variable.sending_cds))&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|variable.trinket_1_duration>=fight_remains
    if Trinket1:IsReady() and not VarTrinket1BL and (VarTrinket1CastTime > 0 and VarTrinket1Buffs and not VarTrinket1Manual and Player:BuffDown(S.PillarofFrostBuff) and (not S.BreathofSindragosa:IsAvailable() or Player:BuffDown(S.BreathofSindragosa) and Player:RunicPower() > VarBreathRPThreshold and (S.PillarofFrost:CooldownUp() and VarSendingCDs)) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or VarTrinket1Duration >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 8"; end
    end
    -- use_item,slot=trinket2,use_off_gcd=1,if=trinket.2.cast_time>0&variable.trinket_2_buffs&!variable.trinket_2_manual&!buff.pillar_of_frost.up&(!talent.breath_of_sindragosa|!buff.breath_of_sindragosa.up&runic_power>variable.breath_rp_threshold&(cooldown.pillar_of_frost.ready&variable.sending_cds))&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|variable.trinket_2_duration>=fight_remains
    if Trinket2:IsReady() and not VarTrinket2BL and (VarTrinket2CastTime > 0 and VarTrinket2Buffs and not VarTrinket2Manual and Player:BuffDown(S.PillarofFrostBuff) and (not S.BreathofSindragosa:IsAvailable() or Player:BuffDown(S.BreathofSindragosa) and Player:RunicPower() > VarBreathRPThreshold and (S.PillarofFrost:CooldownUp() and VarSendingCDs)) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or VarTrinket2Duration >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 10"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|(!trinket.2.has_cooldown|trinket.2.cooldown.remains))&((trinket.1.cast_time>0&(!talent.breath_of_sindragosa|!buff.breath_of_sindragosa.up|!variable.breath_dying)&!buff.pillar_of_frost.up|!trinket.1.cast_time>0)&(!variable.trinket_2_buffs|cooldown.pillar_of_frost.remains>20)|!talent.pillar_of_frost)|fight_remains<15
    if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or (not Trinket2:HasCooldown() or Trinket2:CooldownDown())) and ((VarTrinket1CastTime > 0 and (not S.BreathofSindragosa:IsAvailable() or Player:BuffDown(S.BreathofSindragosa) or not VarBreathDying) and Player:BuffDown(S.PillarofFrostBuff) or VarTrinket1CastTime == 0) and (not VarTrinket2Buffs or S.PillarofFrost:CooldownRemains() > 20) or not S.PillarofFrost:IsAvailable()) or BossFightRemains < 15) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 12"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|(!trinket.1.has_cooldown|trinket.1.cooldown.remains))&((trinket.2.cast_time>0&(!talent.breath_of_sindragosa|!buff.breath_of_sindragosa.up|!variable.breath_dying)&!buff.pillar_of_frost.up|!trinket.2.cast_time>0)&(!variable.trinket_1_buffs|cooldown.pillar_of_frost.remains>20)|!talent.pillar_of_frost)|fight_remains<15
    if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or (not Trinket1:HasCooldown() or Trinket1:CooldownDown())) and ((VarTrinket2CastTime > 0 and (not S.BreathofSindragosa:IsAvailable() or Player:BuffDown(S.BreathofSindragosa) or not VarBreathDying) and Player:BuffDown(S.PillarofFrostBuff) or VarTrinket2CastTime == 0) and (not VarTrinket1Buffs or S.PillarofFrost:CooldownRemains() > 20) or not S.PillarofFrost:IsAvailable()) or BossFightRemains < 15) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 14"; end
    end
  end
  -- use_item,use_off_gcd=1,slot=main_hand,if=!equipped.fyralath_the_dreamrender&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  -- Note: Removed from APL, but leaving in profile in case of MH on-use. Removing Fyralath check, though.
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ((not VarTrinket1Buffs or Trinket1:CooldownDown()) and (not VarTrinket2Buffs or Trinket2:CooldownDown())) then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_item for " .. ItemToUse:Name() .. " trinkets 16"; end
    end
  end
end

local function Variables()
  -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
  VarSTPlanning = EnemiesMeleeCount == 1 or not AoEON()
  -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>5)
  VarAddsRemain = EnemiesMeleeCount >= 2 and AoEON()
  -- variable,name=sending_cds,value=(variable.st_planning|variable.adds_remain)
  VarSendingCDs = VarSTPlanning or VarAddsRemain
  -- variable,name=rime_buffs,value=buff.rime.react&(variable.static_rime_buffs|talent.avalanche&!talent.arctic_assault&debuff.razorice.stack<5)
  VarRimeBuffs = Player:BuffUp(S.RimeBuff) and (VarStaticRimeBuffs or S.Avalanche:IsAvailable() and not S.ArcticAssault:IsAvailable() and Target:DebuffStack(S.RazoriceDebuff) < 5)
  -- variable,name=rp_buffs,value=talent.unleashed_frenzy&(buff.unleashed_frenzy.remains<gcd.max*3|buff.unleashed_frenzy.stack<3)|talent.icy_talons&(buff.icy_talons.remains<gcd.max*3|buff.icy_talons.stack<(3+(2*talent.smothering_offense)+(2*talent.dark_talons)))
  VarRPBuffs = S.UnleashedFrenzy:IsAvailable() and (Player:BuffRemains(S.UnleashedFrenzyBuff) < Player:GCD() * 3 or Player:BuffStack(S.UnleashedFrenzyBuff) < 3) or S.IcyTalons:IsAvailable() and (Player:BuffRemains(S.IcyTalonsBuff) < Player:GCD() * 3 or Player:BuffStack(S.IcyTalonsBuff) < (3 + (2 * num(S.SmotheringOffense:IsAvailable())) + (2 * num(S.DarkTalons:IsAvailable()))))
  -- variable,name=cooldown_check,value=talent.pillar_of_frost&buff.pillar_of_frost.up&(talent.obliteration&buff.pillar_of_frost.remains>10|!talent.obliteration)|!talent.pillar_of_frost&buff.empower_rune_weapon.up|!talent.pillar_of_frost&!talent.empower_rune_weapon|active_enemies>=2&buff.pillar_of_frost.up
  VarCDCheck = S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and (S.Obliteration:IsAvailable() and Player:BuffRemains(S.PillarofFrostBuff) > 10 or not S.Obliteration:IsAvailable()) or not S.PillarofFrost:IsAvailable() and Player:BuffUp(S.EmpowerRuneWeaponBuff) or not S.PillarofFrost:IsAvailable() and not S.EmpowerRuneWeapon:IsAvailable() or EnemiesMeleeCount >= 2 and Player:BuffUp(S.PillarofFrostBuff)
  -- variable,name=true_breath_cooldown,op=setif,value=cooldown.breath_of_sindragosa.remains,value_else=cooldown.pillar_of_frost.remains,condition=cooldown.breath_of_sindragosa.remains>cooldown.pillar_of_frost.remains
  VarTrueBreathCD = (S.BreathofSindragosa:CooldownRemains() > S.PillarofFrost:CooldownRemains()) and S.BreathofSindragosa:CooldownRemains() or S.PillarofFrost:CooldownRemains()
  -- variable,name=oblit_pooling_time,op=setif,value=((cooldown.pillar_of_frost.remains+1)%gcd.max)%((rune+1)*((runic_power+5)))*100,value_else=3,condition=runic_power<35&rune<2&cooldown.pillar_of_frost.remains<10
  VarOblitPoolingTime = 3
  if Player:RunicPower() < 35 and Player:Rune() < 2 and S.PillarofFrost:CooldownRemains() < 10 then
    VarOblitPoolingTime = ((S.PillarofFrost:CooldownRemains() + 1) / GCDMax) / ((Player:Rune() + 1) * (Player:RunicPower() + 5)) * 100
  end
  -- variable,name=breath_pooling_time,op=setif,value=((variable.true_breath_cooldown+1)%gcd.max)%((rune+1)*(runic_power+20))*100,value_else=2,condition=runic_power.deficit>10&variable.true_breath_cooldown<10
  VarBreathPoolingTime = 2
  if Player:RunicPowerDeficit() > 10 and VarTrueBreathCD < 10 then
    VarBreathPoolingTime = ((VarTrueBreathCD + 1) / GCDMax) / ((Player:Rune() + 1) * (Player:RunicPower() + 20)) * 100
  end
  -- variable,name=pooling_runes,value=rune<variable.oblit_rune_pooling&talent.obliteration&(!talent.breath_of_sindragosa|variable.true_breath_cooldown)&cooldown.pillar_of_frost.remains<variable.oblit_pooling_time
  VarPoolingRunes = Player:Rune() < VarOblitRunePooling and S.Obliteration:IsAvailable() and (not S.BreathofSindragosa:IsAvailable() or bool(VarTrueBreathCD)) and S.PillarofFrost:CooldownRemains() < VarOblitPoolingTime
  -- variable,name=pooling_runic_power,value=talent.breath_of_sindragosa&(variable.true_breath_cooldown<variable.breath_pooling_time|fight_remains<30&!cooldown.breath_of_sindragosa.remains)|talent.obliteration&(!talent.breath_of_sindragosa|cooldown.breath_of_sindragosa.remains>30)&runic_power<35&cooldown.pillar_of_frost.remains<variable.oblit_pooling_time
  VarPoolingRP = S.BreathofSindragosa:IsAvailable() and (VarTrueBreathCD < VarBreathPoolingTime or FightRemains < 30 and S.BreathofSindragosa:CooldownUp()) or S.Obliteration:IsAvailable() and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 30) and Player:RunicPower() < 35 and S.PillarofFrost:CooldownRemains() < VarOblitPoolingTime
  -- variable,name=ga_priority,value=(!talent.shattered_frost&talent.shattering_blade&active_enemies>=4)|(!talent.shattered_frost&!talent.shattering_blade&active_enemies>=2)
  VarGAPriority = (not S.ShatteredFrost:IsAvailable() and S.ShatteringBlade:IsAvailable() and EnemiesMeleeCount >= 4) or (not S.ShatteredFrost:IsAvailable() and not S.ShatteringBlade:IsAvailable() and EnemiesMeleeCount >= 2)
  -- variable,name=breath_dying,value=runic_power<variable.breath_rp_cost*2&rune.time_to_2>runic_power%variable.breath_rp_cost
  VarBreathDying = Player:RunicPower() < VarBreathRPCost * 2 and Player:RuneTimeToX(2) > Player:RunicPower() / VarBreathRPCost
end

--- ===== APL Main =====
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
  else
    EnemiesMeleeCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
    end

    -- Calculate GCDMax
    GCDMax = Player:GCD() + 0.25
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and DeathStrikeHeal() then
      if Cast(S.DeathStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=high_prio_actions
    local ShouldReturn = HighPrioActions(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if CDsON() then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cold_heart,if=talent.cold_heart&(!buff.killing_machine.up|talent.breath_of_sindragosa)&((debuff.razorice.stack=5|!death_knight.runeforge.razorice&!talent.glacial_advance&!talent.avalanche&!talent.arctic_assault)|fight_remains<=gcd)
    if S.ColdHeart:IsAvailable() and (Player:BuffDown(S.KillingMachineBuff) or S.BreathofSindragosa:IsAvailable()) and ((Target:DebuffStack(S.RazoriceDebuff) == 5 or not UsingRazorice and not S.GlacialAdvance:IsAvailable() and not S.Avalanche:IsAvailable() and not S.ArcticAssault:IsAvailable()) or BossFightRemains <= Player:GCD() + 0.5) then
      local ShouldReturn = ColdHeart(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=breath,if=buff.breath_of_sindragosa.up
    if Player:BuffUp(S.BreathofSindragosa) and (Player:BuffUp(S.BreathofSindragosa)) then
      local ShouldReturn = Breath(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Breath()"; end
    end
    -- run_action_list,name=obliteration,if=talent.obliteration&buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up
    if S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffDown(S.BreathofSindragosa) then
      local ShouldReturn = Obliteration(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Obliteration()"; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=2
    if EnemiesMeleeCount >= 2 and AoEON() then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single_target,if=active_enemies=1
    if EnemiesMeleeCount == 1 or not AoEON() then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FrostFeverDebuff:RegisterAuraTracking()
  S.MarkofFyralathDebuff:RegisterAuraTracking()

  HR.Print("Frost Death Knight rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(251, APL, Init)

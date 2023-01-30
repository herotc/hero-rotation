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
local GetInventoryItemLink = GetInventoryItemLink

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Frost
local I = Item.DeathKnight.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Var
local no_heal
local UsingRazorice
local UsingFallenCrusader
local VarRWBuffs
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local VarSTPlanning
local VarAddsRemain
local VarRimeBuffs
local VarRPBuffs
local VarCDCheck
local VarFrostscythePriority
local VarOblitPoolingTime
local VarBreathPoolingTime
local VarPoolingRunes
local VarPoolingRP
local BossFightRemains = 11111
local FightRemains = 11111
local ghoul = HL.GhoulTable

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Commons2 = HR.GUISettings.APL.DeathKnight.Commons2,
  Frost = HR.GUISettings.APL.DeathKnight.Frost
}

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

local MainHandLink = GetInventoryItemLink("player", 16) or ""
local OffHandLink = GetInventoryItemLink("player", 17) or ""
local _, _, MainHandRuneforge = strsplit(":", MainHandLink)
local _, _, OffHandRuneforge = strsplit(":", OffHandLink)
local UsingRazorice = (MainHandRuneforge == "3370" or OffHandRuneforge == "3370")
local UsingFallenCrusader = (MainHandRuneforge == "3368" or OffHandRuneforge == "3368")
local UsingHysteria = (MainHandRuneforge == "6243" or OffHandRuneforge == "6243")
local Using2H = IsEquippedItemType("Two-Hand")

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)

  MainHandLink = GetInventoryItemLink("player", 16) or ""
  OffHandLink = GetInventoryItemLink("player", 17) or ""
  _, _, MainHandRuneforge = strsplit(":", MainHandLink)
  _, _, OffHandRuneforge = strsplit(":", OffHandLink)
  UsingRazorice = (MainHandRuneforge == "3370" or OffHandRuneforge == "3370")
  UsingFallenCrusader = (MainHandRuneforge == "3368" or OffHandRuneforge == "3368")
  Using2H = IsEquippedItemType("Two-Hand")
end, "PLAYER_EQUIPMENT_CHANGED")

-- Helper Functions
local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff)))
end

-- Target_if
local function EvaluateTargetIfRazoriceStacks(TargetUnit)
  return ((TargetUnit:DebuffStack(S.RazoriceDebuff) + 1) / (TargetUnit:DebuffRemains(S.RazoriceDebuff) + 1) * num(UsingRazorice))
end

-- HowlingBlast
local function EvaluateCycleHowlingBlast(TargetUnit)
  return (TargetUnit:DebuffDown(S.FrostFeverDebuff))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(talent.pillar_of_frost&!talent.breath_of_sindragosa&(trinket.1.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.1.cooldown.duration=0))
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(talent.pillar_of_frost&!talent.breath_of_sindragosa&(trinket.2.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.2.cooldown.duration=0))
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit&!variable.trinket_1_exclude)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit&!variable.trinket_2_exclude)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box
  -- TODO: Trinket sync/priority stuff. Currently unable to pull trinket CD durations because WoW's API is bad.
  -- variable,name=rw_buffs,value=talent.gathering_storm|talent.everfrost
  VarRWBuffs = (S.GatheringStorm:IsAvailable() or S.Everfrost:IsAvailable())
  -- variable,name=2h_check,value=main_hand.2h&talent.might_of_the_frozen_wastes
  Var2HCheck = (Using2H and S.MightoftheFrozenWastes:IsAvailable())
  -- Manually added openers: HowlingBlast if at range, RemorselessWinter if in melee
  if S.HowlingBlast:IsReady() and (not Target:IsInRange(8)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast precombat"; end
  end
  if S.RemorselessWinter:IsReady() and (Target:IsInRange(8)) then
    if Cast(S.RemorselessWinter) then return "remorseless_winter precombat"; end
  end
end

local function AoE()
  -- remorseless_winter
  if S.RemorselessWinter:IsReady() then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter aoe 2"; end
  end
  -- howling_blast,if=buff.rime.react|!dot.frost_fever.ticking
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff) or Target:DebuffDown(S.FrostFeverDebuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 6"; end
  end
  -- glacial_advance,if=!variable.pooling_runic_power&variable.rp_buffs
  if S.GlacialAdvance:IsReady() and ((not VarPoolingRP) and VarRPBuffs) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsSpellInRange(S.GlacialAdvance)) then return "glacial_advance aoe 8"; end
  end
  -- obliterate,if=buff.killing_machine.react&talent.cleaving_strikes&death_and_decay.ticking&!variable.frostscythe_priority
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and S.CleavingStrikes:IsAvailable() and Player:BuffUp(S.DeathAndDecayBuff) and not VarFrostscythePriority) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 10"; end
  end
  -- glacial_advance,if=!variable.pooling_runic_power
  if S.GlacialAdvance:IsReady() and (not VarPoolingRP) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsSpellInRange(S.GlacialAdvance)) then return "glacial_advance aoe 12"; end
  end
  -- frostscythe,if=variable.frostscythe_priority
  if S.Frostscythe:IsReady() and (VarFrostscythePriority) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe aoe 14"; end
  end
  -- obliterate,if=!variable.frostscythe_priority
  if S.Obliterate:IsReady() and (not VarFrostscythePriority) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 16"; end
  end
  -- frost_strike,if=!variable.pooling_runic_power&!talent.glacial_advance
  if S.FrostStrike:IsReady() and ((not VarPoolingRP) and not S.GlacialAdvance:IsAvailable()) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsSpellInRange(S.FrostStrike)) then return "frost_strike aoe 18"; end
  end
  -- horn_of_winter,if=rune<2&runic_power.deficit>25
  if S.HornofWinter:IsCastable() and (Player:Rune() < 2 and Player:RunicPowerDeficit() > 25) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter aoe 20"; end
  end
  -- arcane_torrent,if=runic_power.deficit>25
  if S.ArcaneTorrent:IsReady() and (Player:RunicPowerDeficit() > 25) then
    if Cast(S.ArcaneTorrent, Settings.Commons2.OffGCDasOffGCD.Racials) then return "arcane_torrent aoe 22"; end
  end
end

local function BreathOblit()
  -- frostscythe,if=buff.killing_machine.up&variable.frostscythe_priority
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and VarFrostscythePriority) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe breath_oblit 2"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.up
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff)) then
    if Everyone.CastTargetIf(S.Obliterate, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate breath_oblit 4"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath_oblit 6"; end
  end
  -- howling_blast,if=!buff.killing_machine.up
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath_oblit 8"; end
  end
  -- horn_of_winter,if=runic_power.deficit>25
  if S.HornofWinter:IsReady() and (Player:RunicPowerDeficit() > 25) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter breath_oblit 10"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsReady() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.Commons2.OffGCDasOffGCD.Racials) then return "arcane_torrent breath_oblit 12"; end
  end
end

local function Breath()
  -- remorseless_winter,if=variable.rw_buffs&variable.adds_remain
  if S.RemorselessWinter:IsReady() and (VarRWBuffs and VarAddsRemain) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter breath 2"; end
  end
  -- howling_blast,if=variable.rime_buffs&runic_power>(45-talent.rage_of_the_frozen_champion*8)
  if S.HowlingBlast:IsReady() and (VarRimeBuffs and Player:RunicPower() > (45 - num(S.RageoftheFrozenChampion:IsAvailable()) * 8)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath 4"; end
  end
  -- horn_of_winter,if=rune<2&runic_power.deficit>25
  if S.HornofWinter:IsReady() and (Player:Rune() < 2 and Player:RunicPowerDeficit() > 25) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter breath 6"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react&!variable.frostscythe_priority
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarFrostscythePriority) then
    if Everyone.CastTargetIf(S.Obliterate, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate breath 8"; end
  end
  -- frostscythe,if=buff.killing_machine.react&variable.frostscythe_priority
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and VarFrostscythePriority) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe breath 10"; end
  end
  -- frostscythe,if=variable.frostscythe_priority&runic_power>45
  if S.Frostscythe:IsReady() and (VarFrostscythePriority and Player:RunicPower() > 45) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe breath 12"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>40|buff.pillar_of_frost.up&runic_power.deficit>15
  if S.Obliterate:IsReady() and (Player:RunicPowerDeficit() > 40 or Player:BuffUp(S.PillarofFrostBuff) and Player:RunicPowerDeficit() > 15) then
    if Everyone.CastTargetIf(S.Obliterate, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate breath 14"; end
  end
  -- death_and_decay,if=runic_power<32&rune.time_to_2>runic_power%16
  if S.DeathAndDecay:IsReady() and (Player:RunicPower() < 32 and Player:RuneTimeToX(2) > Player:RunicPower() / 16) then
    if Cast(S.DeathAndDecay, Settings.Commons2.GCDasOffGCD.DeathAndDecay, nil, not Target:IsSpellInRange(S.DeathAndDecay)) then return "death_and_decay breath 16"; end
  end
  -- remorseless_winter,if=runic_power<32&rune.time_to_2>runic_power%16
  if S.RemorselessWinter:IsReady() and (Player:RunicPower() < 32 and Player:RuneTimeToX(2) > Player:RunicPower() / 16) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter breath 18"; end
  end
  -- howling_blast,if=runic_power<32&rune.time_to_2>runic_power%16
  if S.HowlingBlast:IsReady() and (Player:RunicPower() < 32 and Player:RuneTimeToX(2) > Player:RunicPower() / 16) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath 20"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>25
  if S.Obliterate:IsReady() and (Player:RunicPowerDeficit() > 25) then
    if Everyone.CastTargetIf(S.Obliterate, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate breath 22"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast breath 24"; end
  end
  -- arcane_torrent,if=runic_power<60
  if S.ArcaneTorrent:IsReady() and (Player:RunicPower() < 60) then
    if Cast(S.ArcaneTorrent, Settings.Commons2.OffGCDasOffGCD.Racials) then return "arcane_torrent breath 26"; end
  end
end

local function Cooldowns()
  -- potion,if=variable.cooldown_check|fight_remains<25
  if Settings.Commons.Enabled.Potions and (VarCDCheck or FightRemains < 25) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 2"; end
    end
  end
  -- empower_rune_weapon,if=talent.obliteration&!buff.empower_rune_weapon.up&rune<6&(cooldown.pillar_of_frost.remains_expected<7&(variable.adds_remain|variable.st_planning)|buff.pillar_of_frost.up)|fight_remains<20
  if S.EmpowerRuneWeapon:IsCastable() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.EmpowerRuneWeaponBuff) and Player:Rune() < 6 and (S.PillarofFrost:CooldownRemains() < 7 and (VarAddsRemain or VarSTPlanning) or Player:BuffUp(S.PillarofFrostBuff)) or FightRemains < 20) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons2.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 4"; end
  end
  -- empower_rune_weapon,use_off_gcd=1,if=buff.breath_of_sindragosa.up&talent.breath_of_sindragosa&!buff.empower_rune_weapon.up&(runic_power<70&rune<3|time<10)
  if S.EmpowerRuneWeapon:IsCastable() and (Player:BuffUp(S.BreathofSindragosa) and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.EmpowerRuneWeaponBuff) and (Player:RunicPower() < 70 and Player:Rune() < 3 or HL.CombatTime() < 10)) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons2.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 6"; end
  end
  -- empower_rune_weapon,use_off_gcd=1,if=!talent.breath_of_sindragosa&!talent.obliteration&!buff.empower_rune_weapon.up&rune<5&(cooldown.pillar_of_frost.remains_expected<7|buff.pillar_of_frost.up|!talent.pillar_of_frost)
  if S.EmpowerRuneWeapon:IsCastable() and ((not S.BreathofSindragosa:IsAvailable()) and (not S.Obliteration:IsAvailable()) and Player:BuffDown(S.EmpowerRuneWeaponBuff) and Player:Rune() < 5 and (S.PillarofFrost:CooldownRemains() < 7 or Player:BuffUp(S.PillarofFrostBuff) or not S.PillarofFrost:IsAvailable())) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons2.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 6"; end
  end
  -- abomination_limb,if=talent.obliteration&!buff.pillar_of_frost.up&(variable.adds_remain|variable.st_planning)|fight_remains<12
  if S.AbominationLimb:IsCastable() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and (VarAddsRemain or VarSTPlanning) or FightRemains < 12) then
    if Cast(S.AbominationLimb, Settings.Commons2.GCDasOffGCD.AbominationLimb, nil, not Target:IsInRange(20)) then return "abomination_limb_talent cooldowns 8"; end
  end
  -- abomination_limb,if=talent.breath_of_sindragosa&(variable.adds_remain|variable.st_planning)
  if S.AbominationLimb:IsCastable() and (S.BreathofSindragosa:IsAvailable() and (VarAddsRemain or VarSTPlanning)) then
    if Cast(S.AbominationLimb, Settings.Commons2.GCDasOffGCD.AbominationLimb, nil, not Target:IsInRange(20)) then return "abomination_limb_talent cooldowns 10"; end
  end
  -- abomination_limb,if=!talent.breath_of_sindragosa&!talent.obliteration&(variable.adds_remain|variable.st_planning)
  if S.AbominationLimb:IsCastable() and ((not S.BreathofSindragosa:IsAvailable()) and (not S.Obliteration:IsAvailable()) and (VarAddsRemain or VarSTPlanning)) then
    if Cast(S.AbominationLimb, Settings.Commons2.GCDasOffGCD.AbominationLimb, nil, not Target:IsInRange(20)) then return "abomination_limb_talent cooldowns 12"; end
  end
  -- chill_streak,if=active_enemies>=2&(!death_and_decay.ticking&talent.cleaving_strikes|!talent.cleaving_strikes|active_enemies<=5)
  if S.ChillStreak:IsReady() and (EnemiesCount10yd >= 2 and (Player:BuffDown(S.DeathAndDecayBuff) and S.CleavingStrikes:IsAvailable() or (not S.CleavingStrikes:IsAvailable()) or EnemiesCount10yd <= 5)) then
    if Cast(S.ChillStreak, nil, nil, not Target:IsSpellInRange(S.ChillStreak)) then return "chill_streak cooldowns 14"; end
  end
  -- pillar_of_frost,if=talent.obliteration&(variable.adds_remain|variable.st_planning)&(buff.empower_rune_weapon.up|cooldown.empower_rune_weapon.remains)|fight_remains<12
  if S.PillarofFrost:IsCastable() and (S.Obliteration:IsAvailable() and (VarAddsRemain or VarSTPlanning) and (Player:BuffUp(S.EmpowerRuneWeaponBuff) or S.EmpowerRuneWeapon:CooldownRemains() > 0) or FightRemains < 12) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 16"; end
  end
  -- pillar_of_frost,if=talent.breath_of_sindragosa&(variable.adds_remain|variable.st_planning)&(!talent.icecap&(runic_power>70|cooldown.breath_of_sindragosa.remains>40)|talent.icecap&(cooldown.breath_of_sindragosa.remains>10|buff.breath_of_sindragosa.up))
  if S.PillarofFrost:IsCastable() and (S.BreathofSindragosa:IsAvailable() and (VarAddsRemain or VarSTPlanning) and ((not S.Icecap:IsAvailable()) and (Player:RunicPower() > 70 or S.BreathofSindragosa:CooldownRemains() > 40) or S.Icecap:IsAvailable() and (S.BreathofSindragosa:CooldownRemains() > 10 or Player:BuffUp(S.BreathofSindragosa)))) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 18"; end
  end
  -- pillar_of_frost,if=talent.icecap&!talent.obliteration&!talent.breath_of_sindragosa&(variable.adds_remain|variable.st_planning)
  if S.PillarofFrost:IsCastable() and (S.Icecap:IsAvailable() and (not S.Obliteration:IsAvailable()) and (not S.BreathofSindragosa:IsAvailable()) and (VarAddsRemain or VarSTPlanning)) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 20"; end
  end
  -- breath_of_sindragosa,if=!buff.breath_of_sindragosa.up&runic_power>60&(variable.adds_remain|variable.st_planning)|fight_remains<30
  if S.BreathofSindragosa:IsReady() and (Player:BuffDown(S.BreathofSindragosa) and Player:RunicPower() > 60 and (VarAddsRemain or VarSTPlanning) or FightRemains < 30) then
    if Cast(S.BreathofSindragosa, Settings.Frost.GCDasOffGCD.BreathOfSindragosa, nil, not Target:IsInRange(12)) then return "breath_of_sindragosa cooldowns 22"; end
  end
  -- frostwyrms_fury,if=active_enemies=1&(talent.pillar_of_frost&buff.pillar_of_frost.remains<gcd*2&buff.pillar_of_frost.up&!talent.obliteration|!talent.pillar_of_frost)&(!raid_event.adds.exists|(raid_event.adds.in>15+raid_event.adds.duration|talent.absolute_zero&raid_event.adds.in>15+raid_event.adds.duration))|fight_remains<3
  if S.FrostwyrmsFury:IsCastable() and (EnemiesCount10yd == 1 and (S.PillarofFrost:IsAvailable() and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * 2 and Player:BuffUp(S.PillarofFrostBuff) and (not S.Obliteration:IsAvailable()) or not S.PillarofFrost:IsAvailable()) or FightRemains < 3) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 24"; end
  end
  -- frostwyrms_fury,if=active_enemies>=2&(talent.pillar_of_frost&buff.pillar_of_frost.up|raid_event.adds.exists&raid_event.adds.up&raid_event.adds.in>cooldown.pillar_of_frost.remains_expected-raid_event.adds.in-raid_event.adds.duration)&(buff.pillar_of_frost.remains<gcd*2|raid_event.adds.exists&raid_event.adds.remains<gcd*2)
  if S.FrostwyrmsFury:IsCastable() and (EnemiesCount10yd >= 2 and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff)) and (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * 2)) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 26"; end
  end
  -- frostwyrms_fury,if=talent.obliteration&(talent.pillar_of_frost&buff.pillar_of_frost.up&!variable.2h_check|!buff.pillar_of_frost.up&variable.2h_check&cooldown.pillar_of_frost.remains|!talent.pillar_of_frost)&((buff.pillar_of_frost.remains<gcd|buff.unholy_strength.up&buff.unholy_strength.remains<gcd)&(debuff.razorice.stack=5|!death_knight.runeforge.razorice&!talent.glacial_advance))
  if S.FrostwyrmsFury:IsCastable() and (S.Obliteration:IsAvailable() and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and (not Using2H) or Player:BuffDown(S.PillarofFrostBuff) and Using2H and S.PillarofFrost:CooldownRemains() > 0 or not S.PillarofFrost:IsAvailable()) and ((Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() or Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD()) and (Target:DebuffStack(S.RazoriceDebuff) == 5 or (not UsingRazorice) and not S.GlacialAdvance:IsAvailable()))) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 28"; end
  end
  -- raise_dead
  if S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 30"; end
  end
  -- soul_reaper,if=fight_remains>5&target.time_to_pct_35<5&active_enemies<=2&(buff.breath_of_sindragosa.up&runic_power>40|!buff.breath_of_sindragosa.up&!talent.obliteration|talent.obliteration&!buff.pillar_of_frost.up)
  if S.SoulReaper:IsReady() and (FightRemains > 5 and (Target:TimeToX(35) < 5 or Target:HealthPercentage() <= 35) and EnemiesCount10yd <= 2 and (Player:BuffUp(S.BreathofSindragosa) and Player:RunicPower() > 40 or Player:BuffDown(S.BreathofSindragosa) and (not S.Obliteration:IsAvailable()) or S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff))) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper cooldowns 32"; end
  end
  -- sacrificial_pact,if=!talent.glacial_advance&!buff.breath_of_sindragosa.up&pet.ghoul.remains<gcd*2&active_enemies>3
  if S.SacrificialPact:IsReady() and ((not S.GlacialAdvance:IsAvailable()) and Player:BuffDown(S.BreathofSindragosa) and ghoul:remains() < Player:GCD() * 2 and EnemiesCount10yd > 3) then
    if Cast(S.SacrificialPact, Settings.Commons2.GCDasOffGCD.SacrificialPact) then return "sacrificial_pact cooldowns 34"; end
  end
  -- any_dnd,if=!death_and_decay.ticking&variable.adds_remain&(buff.pillar_of_frost.up&buff.pillar_of_frost.remains>5|!buff.pillar_of_frost.up)&(active_enemies>5|talent.cleaving_strikes&active_enemies>=2)
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and VarAddsRemain and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffRemains(S.PillarofFrostBuff) > 5 or Player:BuffDown(S.PillarofFrostBuff)) and (EnemiesCount10yd > 5 or S.CleavingStrikes:IsAvailable() and EnemiesCount10yd >= 2)) then
    if Cast(S.DeathAndDecay, Settings.Commons2.GCDasOffGCD.DeathAndDecay) then return "death_and_decay cooldowns 36"; end
  end
end

local function ColdHeart()
  -- chains_of_ice,if=fight_remains<gcd&(rune<2|!buff.killing_machine.up&(!variable.2h_check&buff.cold_heart.stack>=4|variable.2h_check&buff.cold_heart.stack>8)|buff.killing_machine.up&(!variable.2h_check&buff.cold_heart.stack>8|variable.2h_check&buff.cold_heart.stack>10))
  if S.ChainsofIce:IsReady() and (FightRemains < Player:GCD() and (Player:Rune() < 2 or Player:BuffDown(S.KillingMachineBuff) and ((not Using2H) and Player:BuffStack(S.ColdHeartBuff) >= 4 or Using2H and Player:BuffStack(S.ColdHeartBuff) > 8) or Player:BuffUp(S.KillingMachineBuff) and ((not Using2H) and Player:BuffStack(S.ColdHeartBuff) > 8 or Using2H and Player:BuffStack(S.ColdHeartBuff) > 10))) then
    if Cast(S.ChainsofIce, Settings.Commons2.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 2"; end
  end
  -- chains_of_ice,if=!talent.obliteration&buff.pillar_of_frost.up&buff.cold_heart.stack>=10&(buff.pillar_of_frost.remains<gcd*(1+(talent.frostwyrms_fury&cooldown.frostwyrms_fury.ready))|buff.unholy_strength.up&buff.unholy_strength.remains<gcd)
  if S.ChainsofIce:IsReady() and ((not S.Obliteration:IsAvailable()) and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffStack(S.ColdHeartBuff) >= 10 and (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * (1 + num(S.FrostwyrmsFury:IsAvailable() and S.FrostwyrmsFury:IsReady())) or Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD())) then
    if Cast(S.ChainsofIce, Settings.Commons2.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 4"; end
  end
  -- chains_of_ice,if=!talent.obliteration&death_knight.runeforge.fallen_crusader&!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains_expected>15&(buff.cold_heart.stack>=10&buff.unholy_strength.up|buff.cold_heart.stack>=13)
  if S.ChainsofIce:IsReady() and ((not S.Obliteration:IsAvailable()) and UsingFallenCrusader and Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 15 and (Player:BuffStack(S.ColdHeartBuff) >= 10 and Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffStack(S.ColdHeartBuff) >= 13)) then
    if Cast(S.ChainsofIce, Settings.Commons2.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 6"; end
  end
  -- chains_of_ice,if=!talent.obliteration&!death_knight.runeforge.fallen_crusader&buff.cold_heart.stack>=10&!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains_expected>20
  if S.ChainsofIce:IsReady() and ((not S.Obliteration:IsAvailable()) and (not UsingFallenCrusader) and Player:BuffStack(S.ColdHeartBuff) >= 10 and Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 20) then
    if Cast(S.ChainsofIce, Settings.Commons2.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 8"; end
  end
  -- chains_of_ice,if=talent.obliteration&!buff.pillar_of_frost.up&(buff.cold_heart.stack>=14&(buff.unholy_strength.up|buff.chaos_bane.up)|buff.cold_heart.stack>=19|cooldown.pillar_of_frost.remains_expected<3&buff.cold_heart.stack>=14)
  if S.ChainsofIce:IsReady() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and (Player:BuffStack(S.ColdHeartBuff) >= 14 and (Player:BuffUp(S.UnholyStrengthBuff)) or Player:BuffStack(S.ColdHeartBuff) >= 19 or S.PillarofFrost:CooldownRemains() < 3 and Player:BuffStack(S.ColdHeartBuff) >= 14)) then
    if Cast(S.ChainsofIce, Settings.Commons2.GCDasOffGCD.ChainsOfIce, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice cold_heart 10"; end
  end
end

local function Obliteration()
  -- remorseless_winter,if=active_enemies>3
  if S.RemorselessWinter:IsReady() and (EnemiesCount10yd > 3) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter obliteration 2"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react&!variable.frostscythe_priority
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarFrostscythePriority) then
    if Everyone.CastTargetIf(S.Obliterate, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 6"; end
  end
  -- frostscythe,if=buff.killing_machine.react&variable.frostscythe_priority
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and VarFrostscythePriority) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe obliteration 8"; end
  end
  -- howling_blast,if=!dot.frost_fever.ticking&!buff.killing_machine.react
  if S.HowlingBlast:IsReady() and (Target:DebuffDown(S.FrostFeverDebuff) and Player:BuffDown(S.KillingMachineBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 10"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!buff.killing_machine.react&(variable.rp_buffs|debuff.razorice.stack=5&talent.shattering_blade)&!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1)
  if S.FrostStrike:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and (VarRPBuffs or Target:DebuffStack(S.RazoriceDebuff) == 5 and S.ShatteringBlade:IsAvailable()) and (not VarPoolingRP) and ((not S.GlacialAdvance:IsAvailable()) or EnemiesCount10yd == 1)) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 12"; end
  end
  -- howling_blast,if=buff.rime.react&buff.killing_machine.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff) and Player:BuffUp(S.KillingMachineBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 14"; end
  end
  -- glacial_advance,if=!variable.pooling_runic_power&variable.rp_buffs&!buff.killing_machine.react&active_enemies>=2
  if S.GlacialAdvance:IsReady() and ((not VarPoolingRP) and VarRPBuffs and Player:BuffDown(S.KillingMachineBuff) and EnemiesCount10yd >= 2) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance obliteration 16"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!buff.killing_machine.react&!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1)
  if S.FrostStrike:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and (not VarPoolingRP) and ((not S.GlacialAdvance:IsAvailable()) or EnemiesCount10yd == 1)) then
    if Cast(S.FrostStrike, Settings.Commons2.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 18"; end
  end
  -- howling_blast,if=!buff.killing_machine.react&runic_power<25
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and Player:RunicPower() < 25) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 20"; end
  end
  -- arcane_torrent,if=rune<1&runic_power<25
  if S.ArcaneTorrent:IsReady() and (Player:Rune() < 1 and Player:RunicPower() < 25) then
    if Cast(S.ArcaneTorrent, Settings.Commons2.OffGCDasOffGCD.Racials) then return "arcane_torrent obliteration 22"; end
  end
  -- glacial_advance,if=!variable.pooling_runic_power&active_enemies>=2
  if S.GlacialAdvance:IsReady() and ((not VarPoolingRP) and EnemiesCount10yd >= 2) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance obliteration 24"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!variable.pooling_runic_power&(!talent.glacial_advance|active_enemies=1)
  if S.FrostStrike:IsReady() and ((not VarPoolingRP) and ((not S.GlacialAdvance:IsAvailable()) or EnemiesCount10yd == 1)) then
    if Everyone.CastTargetIf(S.FrostStrike, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 26"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 28"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  if S.Obliterate:IsReady() then
    if Everyone.CastTargetIf(S.Obliterate, Enemies10yd, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 30"; end
  end
end

local function SingleTarget()
  -- remorseless_winter,if=variable.rw_buffs|variable.adds_remain
  if S.RemorselessWinter:IsReady() and (VarRWBuffs or VarAddsRemain) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter single_target 2"; end
  end
  -- frostscythe,if=!variable.pooling_runes&buff.killing_machine.react&variable.frostscythe_priority
  if S.Frostscythe:IsReady() and ((not VarPoolingRunes) and Player:BuffUp(S.KillingMachineBuff) and VarFrostscythePriority) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe single_target 4"; end
  end
  -- obliterate,if=!variable.pooling_runes&buff.killing_machine.react
  if S.Obliterate:IsReady() and ((not VarPoolingRunes) and Player:BuffUp(S.KillingMachineBuff)) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 6"; end
  end
  -- howling_blast,if=buff.rime.react&talent.icebreaker.rank=2
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff) and S.Icebreaker:TalentRank() == 2) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 8"; end
  end
  -- horn_of_winter,if=rune<4&runic_power.deficit>25&talent.obliteration&talent.breath_of_sindragosa
  if S.HornofWinter:IsReady() and (Player:Rune() < 4 and Player:RunicPowerDeficit() > 25 and S.Obliteration:IsAvailable() and S.BreathofSindragosa:IsAvailable()) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter single_target 10"; end
  end
  -- frost_strike,if=!variable.pooling_runic_power&(variable.rp_buffs|runic_power.deficit<25|debuff.razorice.stack=5&talent.shattering_blade)
  if S.FrostStrike:IsReady() and ((not VarPoolingRP) and (VarRPBuffs or Player:RunicPowerDeficit() < 25 or Target:DebuffStack(S.RazoriceDebuff) == 5 and S.ShatteringBlade:IsAvailable())) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 12"; end
  end
  -- howling_blast,if=variable.rime_buffs
  if S.HowlingBlast:IsReady() and (VarRimeBuffs) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 14"; end
  end
  -- glacial_advance,if=!variable.pooling_runic_power&!death_knight.runeforge.razorice&(debuff.razorice.stack<5|debuff.razorice.remains<gcd*3)
  if S.GlacialAdvance:IsReady() and ((not VarPoolingRP) and (not UsingRazorice) and (Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < Player:GCD() * 3)) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance single_target 16"; end
  end
  -- obliterate,if=!variable.pooling_runes
  if S.Obliterate:IsReady() and (not VarPoolingRunes) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 18"; end
  end
  -- horn_of_winter,if=rune<4&runic_power.deficit>25&(!talent.breath_of_sindragosa|cooldown.breath_of_sindragosa.remains>cooldown.horn_of_winter.duration)
  if S.HornofWinter:IsReady() and (Player:Rune() < 4 and Player:RunicPowerDeficit() > 25 and ((not S.BreathofSindragosa:IsAvailable()) or S.BreathofSindragosa:CooldownRemains() > 45)) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter single_target 20"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsReady() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.Commons2.OffGCDasOffGCD.Racials) then return "arcane_torrent single_target 22"; end
  end
  -- frost_strike,if=!variable.pooling_runic_power
  if S.FrostStrike:IsReady() and (not VarPoolingRP) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 24"; end
  end
end

local function Racials()
  if (VarCDCheck) then
    -- blood_fury,if=variable.cooldown_check
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons2.OffGCDasOffGCD.Racials) then return "blood_fury racials 2"; end
    end
    -- berserking,if=variable.cooldown_check
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons2.OffGCDasOffGCD.Racials) then return "berserking racials 4"; end
    end
    -- arcane_pulse,if=variable.cooldown_check
    if S.ArcanePulse:IsCastable() then
      if Cast(S.ArcanePulse, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
    end
    -- lights_judgment,if=variable.cooldown_check
    if S.LightsJudgment:IsCastable() then
      if Cast(S.LightsJudgment, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
    end
    -- ancestral_call,if=variable.cooldown_check
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.Commons2.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
    end
    -- fireblood,if=variable.cooldown_check
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons2.OffGCDasOffGCD.Racials) then return "fireblood racials 12"; end
    end
  end
  -- bag_of_tricks,if=talent.obliteration&!buff.pillar_of_frost.up&buff.unholy_strength.up
  if S.BagofTricks:IsCastable() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.BagofTricks, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 14"; end
  end
  -- bag_of_tricks,if=!talent.obliteration&buff.pillar_of_frost.up&(buff.unholy_strength.up&buff.unholy_strength.remains<gcd*3|buff.pillar_of_frost.remains<gcd*3)
  if S.BagofTricks:IsCastable() and ((not S.Obliteration:IsAvailable()) and Player:BuffUp(S.PillarofFrostBuff) and (Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD() * 3 or Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * 3)) then
    if Cast(S.BagofTricks, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 16"; end
  end
end

local function Trinkets()
  -- use_item,name=algethar_puzzle_box,if=!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains<2&(!talent.breath_of_sindragosa|runic_power>60&(buff.breath_of_sindragosa.up|cooldown.breath_of_sindragosa.remains<2))
  if I.AlgetharPuzzleBox:IsEquippedAndReady() and (Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() < 2 and ((not S.BreathofSindragosa:IsAvailable()) or Player:RunicPower() > 60 and (Player:BuffUp(S.BreathofSindragosa) or S.BreathofSindragosa:CooldownRemains() < 2))) then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box trinkets 2"; end
  end
  -- use_item,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.pillar_of_frost.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&(buff.breath_of_sindragosa.up|buff.pillar_of_frost.up)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.pillar_of_frost.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&(buff.breath_of_sindragosa.up|buff.pillar_of_frost.up)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.pillar_of_frost.up|!trinket.1.cast_time>0)|talent.pillar_of_frost&cooldown.pillar_of_frost.remains_expected>20|!talent.pillar_of_frost)
  -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.pillar_of_frost.up|!trinket.2.cast_time>0)|talent.pillar_of_frost&cooldown.pillar_of_frost.remains_expected>20|!talent.pillar_of_frost)
  -- TODO: Trinket stuff. Until then, have a generic trinket usage function.
  if Settings.Commons.Enabled.Trinkets then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
  if AoEON() then
    EnemiesMelee = Player:GetEnemiesInMeleeRange(8)
    Enemies10yd = Player:GetEnemiesInMeleeRange(10)
    EnemiesCount10yd = #Enemies10yd
    EnemiesMeleeCount = #EnemiesMelee
  else
    EnemiesMelee = {}
    Enemies10yd = {}
    EnemiesCount10yd = 1
    EnemiesMeleeCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10yd, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and not no_heal then
      if Cast(S.DeathStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
    VarSTPlanning = (EnemiesCount10yd == 1 or not AoEON())
    -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>5)
    VarAddsRemain = (EnemiesCount10yd >= 2 and AoEON())
    -- variable,name=rime_buffs,value=buff.rime.react&(talent.rage_of_the_frozen_champion|talent.avalanche|talent.icebreaker)
    VarRimeBuffs = (Player:BuffUp(S.RimeBuff) and (S.RageoftheFrozenChampion:IsAvailable() or S.Avalanche:IsAvailable() or S.Icebreaker:IsAvailable()))
    -- variable,name=rp_buffs,value=talent.unleashed_frenzy&(buff.unleashed_frenzy.remains<gcd*3|buff.unleashed_frenzy.stack<3)|talent.icy_talons&(buff.icy_talons.remains<gcd*3|buff.icy_talons.stack<3)
    VarRPBuffs = (S.UnleashedFrenzy:IsAvailable() and (Player:BuffRemains(S.UnleashedFrenzyBuff) < Player:GCD() * 3 or Player:BuffStack(S.UnleashedFrenzyBuff) < 3) or S.IcyTalons:IsAvailable() and (Player:BuffRemains(S.IcyTalonsBuff) < Player:GCD() * 3 or Player:BuffStack(S.IcyTalonsBuff) < 3))
    -- variable,name=cooldown_check,value=talent.pillar_of_frost&buff.pillar_of_frost.up|!talent.pillar_of_frost&buff.empower_rune_weapon.up|!talent.pillar_of_frost&!talent.empower_rune_weapon
    VarCDCheck = (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) or (not S.PillarofFrost:IsAvailable()) and Player:BuffUp(S.EmpowerRuneWeaponBuff) or (not S.PillarofFrost:IsAvailable()) and not S.EmpowerRuneWeapon:IsAvailable())
    -- variable,name=frostscythe_priority,value=talent.frostscythe&(buff.killing_machine.react|active_enemies>=3)&(!talent.improved_obliterate&!talent.frigid_executioner&!talent.frostreaper&!talent.might_of_the_frozen_wastes|!talent.cleaving_strikes|talent.cleaving_strikes&(active_enemies>6|!death_and_decay.ticking&active_enemies>3))
    VarFrostscythePriority = (S.Frostscythe:IsAvailable() and (Player:BuffUp(S.KillingMachineBuff) or EnemiesCount10yd >= 3) and ((not S.ImprovedObliterate:IsAvailable()) and (not S.FrigidExecutioner:IsAvailable()) and (not S.Frostreaper:IsAvailable()) and (not S.MightoftheFrozenWastes:IsAvailable()) or (not S.CleavingStrikes:IsAvailable()) or S.CleavingStrikes:IsAvailable() and (EnemiesCount10yd > 6 or Player:BuffDown(S.DeathAndDecayBuff) and EnemiesCount10yd > 3)))
    -- variable,name=oblit_pooling_time,op=setif,value=((cooldown.pillar_of_frost.remains_expected+1)%gcd)%((rune+3)*(runic_power+5))*100,value_else=gcd*2,condition=runic_power<35&rune<2&cooldown.pillar_of_frost.remains_expected<10
    if Player:RunicPower() < 35 and Player:Rune() < 2 and S.PillarofFrost:CooldownRemains() < 10 then
      VarOblitPoolingTime = (((S.PillarofFrost:CooldownRemains() + 1) / Player:GCD()) / ((Player:Rune() + 3) * (Player:RunicPower() + 5)) * 100)
    else
      VarOblitPoolingTime = (Player:GCD() * 2)
    end
    -- variable,name=breath_pooling_time,op=setif,value=((cooldown.breath_of_sindragosa.remains+1)%gcd)%((rune+1)*(runic_power+20))*100,value_else=gcd*2,condition=runic_power.deficit>10&cooldown.breath_of_sindragosa.remains<10
    if Player:RunicPowerDeficit() > 10 and S.BreathofSindragosa:CooldownRemains() < 10 then
      VarBreathPoolingTime = (((S.BreathofSindragosa:CooldownRemains() + 1) / Player:GCD()) / ((Player:Rune() + 1) * (Player:RunicPower() + 20)) * 100)
    else
      VarBreathPoolingTime = (Player:GCD() * 2)
    end
    -- variable,name=pooling_runes,value=talent.obliteration&cooldown.pillar_of_frost.remains_expected<variable.oblit_pooling_time
    VarPoolingRunes = (S.Obliteration:IsAvailable() and S.PillarofFrost:CooldownRemains() < VarOblitPoolingTime)
    -- variable,name=pooling_runic_power,value=talent.breath_of_sindragosa&cooldown.breath_of_sindragosa.remains<variable.breath_pooling_time|talent.obliteration&runic_power<35&cooldown.pillar_of_frost.remains_expected<variable.oblit_pooling_time
    VarPoolingRP = (S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemains() < VarBreathPoolingTime or S.Obliteration:IsAvailable() and Player:RunicPower() < 35 and S.PillarofFrost:CooldownRemains() < VarOblitPoolingTime)
    -- invoke_external_buff,name=power_infusion,if=(buff.pillar_of_frost.up|!talent.pillar_of_frost)&(talent.obliteration|talent.breath_of_sindragosa&buff.breath_of_sindragosa.up|!talent.breath_of_sindragosa&!talent.obliteration)
    -- Note: Not handling external buffs.
    -- mind_freeze,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons2.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    if Settings.Commons.UseAMSAMZOffensively then
      -- antimagic_shell,if=runic_power.deficit>40
      if S.AntiMagicShell:IsCastable() and (Player:RunicPowerDeficit() > 40) then
        if Cast(S.AntiMagicShell, Settings.Commons2.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell main 1"; end
      end
      -- antimagic_zone,if=death_knight.amz_absorb_percent>0&runic_power.deficit>70&talent.assimilation&(buff.breath_of_sindragosa.up|!talent.breath_of_sindragosa)
      if S.AntiMagicZone:IsCastable() and (Player:RunicPowerDeficit() > 70 and S.Assimilation:IsAvailable() and (Player:BuffUp(S.BreathofSindragosa) or not S.BreathofSindragosa:IsAvailable())) then
        if Cast(S.AntiMagicZone, Settings.Commons2.GCDasOffGCD.AntiMagicZone) then return "antimagic_zone main 2"; end
      end
    end
    -- howling_blast,if=!dot.frost_fever.ticking&active_enemies>=2&(!talent.obliteration|talent.obliteration&(!buff.pillar_of_frost.up|buff.pillar_of_frost.up&!buff.killing_machine.react))
    if S.HowlingBlast:IsReady() and (Target:DebuffDown(S.FrostFeverDebuff) and EnemiesCount10yd >= 2 and ((not S.Obliteration:IsAvailable()) or S.Obliteration:IsAvailable() and (Player:BuffDown(S.PillarofFrostBuff) or Player:BuffUp(S.PillarofFrostBuff) and Player:BuffDown(S.KillingMachineBuff)))) then
      if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast main 3"; end
    end
    -- glacial_advance,if=active_enemies>=2&variable.rp_buffs&talent.obliteration&talent.breath_of_sindragosa&!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
    if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2 and VarRPBuffs and S.Obliteration:IsAvailable() and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
      if Cast(S.GlacialAdvance, nil, nil, not Target:IsSpellInRange(S.GlacialAdvance)) then return "glacial_advance main 4"; end
    end
    -- glacial_advance,if=active_enemies>=2&variable.rp_buffs&talent.breath_of_sindragosa&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
    if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2 and VarRPBuffs and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
      if Cast(S.GlacialAdvance, nil, nil, not Target:IsSpellInRange(S.GlacialAdvance)) then return "glacial_advance main 6"; end
    end
    -- glacial_advance,if=active_enemies>=2&variable.rp_buffs&!talent.breath_of_sindragosa&talent.obliteration&!buff.pillar_of_frost.up
    if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2 and VarRPBuffs and (not S.BreathofSindragosa:IsAvailable()) and S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff)) then
      if Cast(S.GlacialAdvance, nil, nil, not Target:IsSpellInRange(S.GlacialAdvance)) then return "glacial_advance main 8"; end
    end
    -- frost_strike,if=active_enemies=1&variable.rp_buffs&talent.obliteration&talent.breath_of_sindragosa&!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
    if S.FrostStrike:IsReady() and (EnemiesCount10yd == 1 and VarRPBuffs and S.Obliteration:IsAvailable() and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
      if Cast(S.FrostStrike, nil, nil, not Target:IsSpellInRange(S.FrostStrike)) then return "frost_strike main 10"; end
    end
    -- frost_strike,if=active_enemies=1&variable.rp_buffs&talent.breath_of_sindragosa&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>variable.breath_pooling_time
    if S.FrostStrike:IsReady() and (EnemiesCount10yd == 1 and VarRPBuffs and S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > VarBreathPoolingTime) then
      if Cast(S.FrostStrike, nil, nil, not Target:IsSpellInRange(S.FrostStrike)) then return "frost_strike main 12"; end
    end
    -- frost_strike,if=active_enemies=1&variable.rp_buffs&!talent.breath_of_sindragosa&talent.obliteration&!buff.pillar_of_frost.up
    if S.FrostStrike:IsReady() and (EnemiesCount10yd == 1 and VarRPBuffs and (not S.BreathofSindragosa:IsAvailable()) and S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff)) then
      if Cast(S.FrostStrike, nil, nil, not Target:IsSpellInRange(S.FrostStrike)) then return "frost_strike main 14"; end
    end
    -- remorseless_winter,if=!talent.breath_of_sindragosa&!talent.obliteration&variable.rw_buffs
    if S.RemorselessWinter:IsReady() and ((not S.BreathofSindragosa:IsAvailable()) and (not S.Obliteration:IsAvailable()) and VarRWBuffs) then
      if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter main 16"; end
    end
    -- remorseless_winter,if=talent.obliteration&active_enemies>=3&variable.adds_remain
    if S.RemorselessWinter:IsReady() and (S.Obliteration:IsAvailable() and EnemiesCount10yd >= 3 and VarAddsRemain) then
      if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter main 18"; end
    end
    -- call_action_list,name=trinkets
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cold_heart,if=talent.cold_heart&(!buff.killing_machine.up|talent.breath_of_sindragosa)&((debuff.razorice.stack=5|!death_knight.runeforge.razorice&!talent.glacial_advance&!talent.avalanche)|fight_remains<=gcd)
    if (S.ColdHeart:IsAvailable() and (Player:BuffDown(S.KillingMachineBuff) or S.BreathofSindragosa:IsAvailable()) and ((Target:DebuffStack(S.RazoriceDebuff) == 5 or (not UsingRazorice) and (not S.GlacialAdvance:IsAvailable()) and not S.Avalanche:IsAvailable()) or FightRemains <= Player:GCD() + 0.5)) then
      local ShouldReturn = ColdHeart(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=breath_oblit,if=buff.breath_of_sindragosa.up&talent.obliteration&buff.pillar_of_frost.up
    if (Player:BuffUp(S.BreathofSindragosa) and S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff)) then
      local ShouldReturn = BreathOblit(); if ShouldReturn then return ShouldReturn; end
      if Cast(S.Pool) then return "pool for BreathOblit()"; end
    end
    -- run_action_list,name=breath,if=buff.breath_of_sindragosa.up&(!talent.obliteration|talent.obliteration&!buff.pillar_of_frost.up)
    if (Player:BuffUp(S.BreathofSindragosa) and ((not S.Obliteration:IsAvailable()) or S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff))) then
      local ShouldReturn = Breath(); if ShouldReturn then return ShouldReturn; end
      if Cast(S.Pool) then return "pool for Breath()"; end
    end
    -- run_action_list,name=obliteration,if=talent.obliteration&buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up
    if (S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffDown(S.BreathofSindragosa)) then
      local ShouldReturn = Obliteration(); if ShouldReturn then return ShouldReturn; end
      if Cast(S.Pool) then return "pool for Obliteration()"; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=2
    if (EnemiesCount10yd >= 2 and AoEON()) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single_target,if=active_enemies=1
    if (EnemiesCount10yd == 1 or not AoEON()) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Frost DK rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(251, APL, Init)

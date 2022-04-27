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
  I.InscrutableQuantumDevice:ID(),
  I.ScarsofFraternalStrife:ID(),
  I.TheFirstSigil:ID()
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = Item(0)
local trinket2 = Item(0)
if equip[13] then
  trinket1 = Item(equip[13])
end
if equip[14] then
  trinket2 = Item(equip[14])
end

-- Rotation Var
local no_heal
local UsingRazorice
local UsingFallenCrusader
local VarRWBuffs
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local VarSpecifiedTrinket
local VarSTPlanning
local VarAddsRemain
local VarROTFCRime
local VarFrostStrikeConduits
local VarDeathsDueActive
local ghoul = HL.GhoulTable

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Frost = HR.GUISettings.APL.DeathKnight.Frost
}

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

local KoltirasFavorEquipped = Player:HasLegendaryEquipped(38)
local BitingColdEquipped = Player:HasLegendaryEquipped(39)
local RageoftheFrozenChampionEquipped = Player:HasLegendaryEquipped(41)
local MainHandLink = GetInventoryItemLink("player", 16) or ""
local OffHandLink = GetInventoryItemLink("player", 17) or ""
local _, _, MainHandRuneforge = strsplit(":", MainHandLink)
local _, _, OffHandRuneforge = strsplit(":", OffHandLink)
local UsingRazorice = (MainHandRuneforge == "3370" or OffHandRuneforge == "3370")
local UsingFallenCrusader = (MainHandRuneforge == "3368" or OffHandRuneforge == "3368")
local Using2H = IsEquippedItemType("Two-Hand")
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = Item(0)
  trinket2 = Item(0)
  if equip[13] then
    trinket1 = Item(equip[13])
  end
  if equip[14] then
    trinket2 = Item(equip[14])
  end
  KoltirasFavorEquipped = Player:HasLegendaryEquipped(38)
  BitingColdEquipped = Player:HasLegendaryEquipped(39)
  RageoftheFrozenChampionEquipped = Player:HasLegendaryEquipped(41)
  MainHandLink = GetInventoryItemLink("player", 16) or ""
  OffHandLink = GetInventoryItemLink("player", 17) or ""
  _, _, MainHandRuneforge = strsplit(":", MainHandLink)
  _, _, OffHandRuneforge = strsplit(":", OffHandLink)
  UsingRazorice = (MainHandRuneforge == "3370" or OffHandRuneforge == "3370")
  UsingFallenCrusader = (MainHandRuneforge == "3368" or OffHandRuneforge == "3368")
  Using2H = IsEquippedItemType("Two-Hand")
end, "PLAYER_EQUIPMENT_CHANGED")

-- Helper Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff)))
end

-- Target_if
local function EvaluateTargetIfRazoriceStacks(TargetUnit)
  return ((TargetUnit:DebuffStack(S.RazoriceDebuff) + 1) / (TargetUnit:DebuffRemains(S.RazoriceDebuff) + 1))
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
  -- opener
  if Everyone.TargetIsValid() then
    -- fleshcraft
    if S.Fleshcraft:IsCastable() then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat"; end
    end
    -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(!talent.breath_of_sindragosa&(trinket.1.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.1.cooldown.duration=0)|talent.icecap)
    -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(!talent.breath_of_sindragosa&(trinket.2.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.2.cooldown.duration=0)|talent.icecap)
    -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!trinket.1.has_use_buff&trinket.2.has_use_buff|trinket.2.has_use_buff&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
    -- TODO: Trinket sync/priority stuff. Currently unable to pull trinket CD durations because WoW's API is bad.
    -- variable,name=rw_buffs,value=talent.gathering_storm|conduit.everfrost|runeforge.biting_cold
    VarRWBuffs = (S.GatheringStorm:IsAvailable() or S.Everfrost:ConduitEnabled() or BitingColdEquipped)
    -- Manually added openers: HowlingBlast if at range, RemorselessWinter if in melee
    if S.HowlingBlast:IsReady() and (not Target:IsInRange(8)) then
      if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast precombat"; end
    end
    if S.RemorselessWinter:IsReady() and (Target:IsInRange(8)) then
      if Cast(S.RemorselessWinter) then return "remorseless_winter precombat"; end
    end
  end
end

local function Aoe()
  -- remorseless_winter
  if S.RemorselessWinter:IsReady() then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter aoe 2"; end
  end
  -- glacial_advance,if=talent.frostscythe
  if S.GlacialAdvance:IsReady() and (S.Frostscythe:IsAvailable()) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance aoe 4"; end
  end
  -- frostscythe,if=buff.killing_machine.react&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe aoe 6"; end
  end
  -- howling_blast,if=variable.rotfc_rime&talent.avalanche
  if S.HowlingBlast:IsReady() and (VarROTFCRime and S.Avalanche:IsAvailable()) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 8"; end
  end
  -- glacial_advance,if=!buff.rime.up&active_enemies<=3|active_enemies>3
  if S.GlacialAdvance:IsReady() and (Player:BuffDown(S.RimeBuff) and EnemiesCount10yd <= 3 or EnemiesCount10yd > 3) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance aoe 10"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm
  if S.FrostStrike:IsReady() and (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike aoe 12 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike aoe 12 no_razorice"; end
    end
  end
  -- howling_blast,if=variable.rotfc_rime
  if S.HowlingBlast:IsReady() and (VarROTFCRime) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 14"; end
  end
  -- frostscythe,if=talent.gathering_storm&buff.remorseless_winter.up&active_enemies>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (S.GatheringStorm:IsAvailable() and Player:BuffUp(S.RemorselessWinter) and EnemiesCount10yd > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe aoe 16"; end
  end
  -- obliterate,if=variable.deaths_due_active&buff.deaths_due.stack<4|talent.gathering_storm&buff.remorseless_winter.up
  if S.Obliterate:IsReady() and (VarDeathsDueActive and Player:BuffStack(S.DeathsDueBuff) < 4 or S.GatheringStorm:IsAvailable() and Player:BuffUp(S.RemorselessWinter)) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 18"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit<(15+talent.runic_attenuation*5)
  if S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 5)) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike aoe 20 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike aoe 20 no_razorice"; end
    end
  end
  -- frostscythe,if=!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe aoe 22"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>(25+talent.runic_attenuation*5)
  if S.Obliterate:IsReady() and (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 5)) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 24 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 24 no_razorice"; end
    end
  end
  -- glacial_advance
  if S.GlacialAdvance:IsReady() then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance aoe 26"; end
  end
  -- frostscythe
  if S.Frostscythe:IsReady() then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe aoe 28"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  if S.FrostStrike:IsReady() then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike aoe 30 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike aoe 30 no_razorice"; end
    end
  end
  -- horn_of_winter
  if S.HornofWinter:IsCastable() then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter aoe 32"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent aoe 34"; end
  end
end

local function BosPooling()
  -- remorseless_winter,if=active_enemies>=2|variable.rw_buffs
  if S.RemorselessWinter:IsReady() and (EnemiesCount10yd >= 2 or VarRWBuffs) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter bospooling 2"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react&cooldown.pillar_of_frost.remains>3
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and S.PillarofFrost:CooldownRemains() > 3) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate bospooling 4 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate bospooling 4 no_razorice"; end
    end
  end
  -- howling_blast,if=variable.rotfc_rime
  if S.HowlingBlast:IsReady() and (VarROTFCRime) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast bospooling 6"; end
  end
  -- frostscythe,if=buff.killing_machine.react&runic_power.deficit>(15+talent.runic_attenuation*5)&spell_targets.frostscythe>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and Player:RunicPowerDeficit() > (15 + num(S.RunicAttenuation:IsAvailable()) * 5) and EnemiesMeleeCount > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe bospooling 8"; end
  end
  -- frostscythe,if=runic_power.deficit>=(35+talent.runic_attenuation*5)&spell_targets.frostscythe>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 5) and EnemiesMeleeCount > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe bospooling 10"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>=25
  if S.Obliterate:IsReady() and (Player:RunicPowerDeficit() >= 25) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate bospooling 12 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate bospooling 12 no_razorice"; end
    end
  end
  -- glacial_advance,if=runic_power.deficit<20&spell_targets.glacial_advance>=2&cooldown.pillar_of_frost.remains>5
  if S.GlacialAdvance:IsReady() and (Player:RunicPowerDeficit() < 20 and EnemiesCount10yd >= 2 and S.PillarofFrost:CooldownRemains() > 5) then
    if Cast(S.GlacialAdvance, nil, nil, Target:IsInRange(100)) then return "glacial_advance bospooling 14"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>5
  if S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < 20 and S.PillarofFrost:CooldownRemains() > 5) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike bospooling 16 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike bospooling 16 no_razorice"; end
    end
  end
  -- glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
  if S.GlacialAdvance:IsReady() and (S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and EnemiesCount10yd >= 2) then
    if Cast(S.GlacialAdvance, nil, nil, Target:IsInRange(100)) then return "glacial_advance bospooling 18"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
  if S.FrostStrike:IsReady() and (S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike bospooling 20 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike bospooling 20 no_razorice"; end
    end
  end
  -- wait for resources
  if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait Resources BoS Pooling"; end
end

local function BosTicking()
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>=(45+talent.runic_attenuation*5)
  if S.Obliterate:IsReady() and (Player:RunicPowerDeficit() >= (45 + num(S.RunicAttenuation:IsAvailable()) * 5)) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate bosticking 2 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate bosticking 2 no_razorice"; end
    end
  end
  -- remorseless_winter,if=variable.rw_buffs|active_enemies>=2|runic_power<32
  if S.RemorselessWinter:IsReady() and (VarRWBuffs or EnemiesCount10yd >= 2 or Player:RunicPower() < 32) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter bosticking 4"; end
  end
  -- death_and_decay,if=runic_power<32
  if S.DeathAndDecay:IsReady() and (Player:RunicPower() < 32) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay bosticking 6"; end
  end
  -- howling_blast,if=variable.rotfc_rime&(runic_power.deficit<55|rune.time_to_3<=gcd|runeforge.rage_of_the_frozen_champion|spell_targets.howling_blast>=2|buff.rime.remains<3)|runic_power<32
  if S.HowlingBlast:IsReady() and (VarROTFCRime and (Player:RunicPowerDeficit() < 55 or Player:RuneTimeToX(3) <= Player:GCD() or RageoftheFrozenChampionEquipped or EnemiesCount10yd >= 2 or Player:BuffRemains(S.RimeBuff) < 3) or Player:RunicPower() < 32) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast bosticking 8"; end
  end
  -- frostscythe,if=buff.killing_machine.up&spell_targets.frostscythe>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and EnemiesCount10yd > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe bosticking 10"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff)) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate bosticking 12 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate bosticking 12 no_razorice"; end
    end
  end
  -- horn_of_winter,if=runic_power.deficit>=40&rune.time_to_3>gcd
  if S.HornofWinter:IsCastable() and (Player:RunicPowerDeficit() >= 40 and Player:RuneTimeToX(3) > Player:GCD()) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter bosticking 14"; end
  end
  -- frostscythe,if=spell_targets.frostscythe>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (EnemiesCount10yd > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe bosticking 16"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>25|rune.time_to_3<gcd
  if S.Obliterate:IsReady() and (Player:RunicPowerDeficit() > 25 or Player:RuneTimeToX(3) < Player:GCD()) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate bosticking 18 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate bosticking 18 no_razorice"; end
    end
  end
  -- howling_blast,if=variable.rotfc_rime
  if S.HowlingBlast:IsReady() and (VarROTFCRime) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast bosticking 20"; end
  end
  -- arcane_torrent,if=runic_power.deficit>50
  if S.ArcaneTorrent:IsCastable() and Player:RunicPowerDeficit() > 50 and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent bosticking 22"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait Resources BoS Ticking"; end
end

local function ColdHeart()
  -- chains_of_ice,if=fight_remains<gcd&(rune<2|!buff.killing_machine.up&(!main_hand.2h&buff.cold_heart.stack>=4+runeforge.koltiras_favor|main_hand.2h&buff.cold_heart.stack>8+runeforge.koltiras_favor)|buff.killing_machine.up&(!main_hand.2h&buff.cold_heart.stack>8+runeforge.koltiras_favor|main_hand.2h&buff.cold_heart.stack>10+runeforge.koltiras_favor))
  if S.ChainsofIce:IsReady() and (HL.FilteredFightRemains(Enemies10yd, "<", Player:GCD()) and (Player:Rune() < 2 or Player:BuffDown(S.KillingMachineBuff) and ((not Using2H) and Player:BuffStack(S.ColdHeartBuff) >= 4 + num(KoltirasFavorEquipped) or Using2H and Player:BuffStack(S.ColdHeartBuff) > 8 + num(KoltirasFavorEquipped)) or Player:BuffUp(S.KillingMachineBuff) and ((not Using2H) and Player:BuffStack(S.ColdHeartBuff) > 8 + num(KoltirasFavorEquipped) or Using2H and Player:BuffStack(S.ColdHeartBuff) > 10 + num(KoltirasFavorEquipped)))) then
    if Cast(S.ChainsofIce, nil, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice coldheart 2"; end
  end
  -- chains_of_ice,if=!talent.obliteration&buff.pillar_of_frost.up&buff.cold_heart.stack>=10&(buff.pillar_of_frost.remains<gcd*(1+cooldown.frostwyrms_fury.ready)|buff.unholy_strength.up&buff.unholy_strength.remains<gcd|buff.chaos_bane.up&buff.chaos_bane.remains<gcd)
  if S.ChainsofIce:IsReady() and ((not S.Obliteration:IsAvailable()) and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffStack(S.ColdHeartBuff) >= 10 and (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * (1 + num(S.FrostwyrmsFury:CooldownUp())) or Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD() or Player:BuffUp(S.ChaosBaneBuff) and Player:BuffRemains(S.ChaosBaneBuff) < Player:GCD())) then
    if Cast(S.ChainsofIce, nil, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice coldheart 4"; end
  end
  -- chains_of_ice,if=!talent.obliteration&death_knight.runeforge.fallen_crusader&!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains>15&(buff.cold_heart.stack>=10&(buff.unholy_strength.up|buff.chaos_bane.up)|buff.cold_heart.stack>=13)
  if S.ChainsofIce:IsReady() and ((not S.Obliteration:IsAvailable()) and UsingFallenCrusader and Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 15 and (Player:BuffStack(S.ColdHeartBuff) >= 10 and (Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffUp(S.ChaosBaneBuff)) or Player:BuffStack(S.ColdHeartBuff) >= 13)) then
    if Cast(S.ChainsofIce, nil, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice coldheart 6"; end
  end
  -- chains_of_ice,if=!talent.obliteration&!death_knight.runeforge.fallen_crusader&buff.cold_heart.stack>=10&!buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains>20
  if S.ChainsofIce:IsReady() and (not S.Obliteration:IsAvailable() and not UsingFallenCrusader and Player:BuffStack(S.ColdHeartBuff) >= 10 and Player:BuffDown(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 20) then
    if Cast(S.ChainsofIce, nil, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice coldheart 8"; end
  end
  -- chains_of_ice,if=talent.obliteration&!buff.pillar_of_frost.up&(buff.cold_heart.stack>=14&(buff.unholy_strength.up|buff.chaos_bane.up)|buff.cold_heart.stack>=19|cooldown.pillar_of_frost.remains<3&buff.cold_heart.stack>=14)
  if S.ChainsofIce:IsReady() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and (Player:BuffStack(S.ColdHeartBuff) >= 14 and (Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffUp(S.ChaosBaneBuff)) or Player:BuffStack(S.ColdHeartBuff) >= 19 or S.PillarofFrost:CooldownRemains() < 3 and Player:BuffStack(S.ColdHeartBuff) >= 14)) then
    if Cast(S.ChainsofIce, nil, nil, not Target:IsSpellInRange(S.ChainsofIce)) then return "chains_of_ice coldheart 10"; end
  end
end

local function Covenants()
  -- deaths_due,if=(!talent.obliteration|talent.obliteration&active_enemies>=2&cooldown.pillar_of_frost.remains|active_enemies=1)&(variable.st_planning|variable.adds_remain)
  if S.DeathsDue:IsReady() and (((not S.Obliteration:IsAvailable()) or S.Obliteration:IsAvailable() and EnemiesCount10yd >= 2 and S.PillarofFrost:CooldownDown() or EnemiesCount10yd == 1) and (VarSTPlanning or VarAddsRemain)) then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(30)) then return "deaths_due covenants 2"; end
  end
  -- swarming_mist,if=runic_power.deficit>13&cooldown.pillar_of_frost.remains<3&!talent.breath_of_sindragosa&variable.st_planning
  if S.SwarmingMist:IsReady() and CDsON() and (Player:RunicPowerDeficit() > 13 and S.PillarofFrost:CooldownRemains() < 3 and (not S.BreathofSindragosa:IsAvailable()) and VarSTPlanning) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(10)) then return "swarming_mist covenants 4"; end
  end
  -- swarming_mist,if=!talent.breath_of_sindragosa&variable.adds_remain
  if S.SwarmingMist:IsReady() and CDsON() and ((not S.BreathofSindragosa:IsAvailable()) and VarAddsRemain) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(10)) then return "swarming_mist covenants 6"; end
  end
  -- swarming_mist,if=talent.breath_of_sindragosa&(buff.breath_of_sindragosa.up&(variable.st_planning&runic_power.deficit>40|variable.adds_remain&runic_power.deficit>60|variable.adds_remain&raid_event.adds.remains<9&raid_event.adds.exists)|!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains)
  if S.SwarmingMist:IsReady() and CDsON() and (S.BreathofSindragosa:IsAvailable() and (Player:BuffUp(S.BreathofSindragosa) and (VarSTPlanning and Player:RunicPowerDeficit() > 40 or VarAddsRemain and Player:RunicPowerDeficit() > 60) or Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownDown())) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(10)) then return "swarming_mist covenants 8"; end
  end
  -- abomination_limb,if=cooldown.pillar_of_frost.remains<gcd*2&variable.st_planning&(talent.breath_of_sindragosa&runic_power>65&cooldown.breath_of_sindragosa.remains<2|!talent.breath_of_sindragosa)
  if S.AbominationLimb:IsCastable() and CDsON() and (S.PillarofFrost:CooldownRemains() < Player:GCD() * 2 and VarSTPlanning and (S.BreathofSindragosa:IsAvailable() and Player:RunicPower() > 65 and S.BreathofSindragosa:CooldownRemains() < 2 or not S.BreathofSindragosa:IsAvailable())) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(8)) then return "abomination_limb covenants 10"; end
  end
  -- abomination_limb,if=variable.adds_remain
  if S.AbominationLimb:IsCastable() and CDsON() and (VarAddsRemain) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(8)) then return "abomination_limb covenants 12"; end
  end
  -- shackle_the_unworthy,if=variable.st_planning&(cooldown.pillar_of_frost.remains<3|talent.icecap)
  if S.ShackleTheUnworthy:IsCastable() and (VarSTPlanning and (S.PillarofFrost:CooldownRemains() < 3 or S.Icecap:IsAvailable())) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 14"; end
  end
  --shackle_the_unworthy,if=variable.adds_remain
  if S.ShackleTheUnworthy:IsCastable() and (VarAddsRemain) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 16"; end
  end
  -- fleshcraft,if=!buff.pillar_of_frost.up&(soulbind.pustule_eruption|soulbind.volatile_solvent&!buff.volatile_solvent_humanoid.up),interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (Player:BuffDown(S.PillarofFrostBuff) and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff))) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft covenants 18"; end
  end
end

local function Racials()
  -- blood_fury,if=buff.pillar_of_frost.up
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff)) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racials 2"; end
  end
  -- berserking,if=buff.pillar_of_frost.up
  if S.Berserking:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racials 4"; end
  end
  -- arcane_pulse,if=(!buff.pillar_of_frost.up&active_enemies>=2)|!buff.pillar_of_frost.up&(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and ((Player:BuffUp(S.PillarofFrostBuff) and EnemiesMeleeCount >= 2) and Player:BuffDown(S.PillarofFrostBuff) and (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
  end
  -- lights_judgment,if=buff.pillar_of_frost.up
  if S.LightsJudgment:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
  if S.AncestralCall:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- fireblood,if=buff.pillar_of_frost.remains<=8&buff.pillar_of_frost.up&buff.empower_rune_weapon.up
  if S.Fireblood:IsCastable() and (Player:BuffRemains(S.PillarofFrostBuff) <= 8 and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racials 12"; end
  end
  -- bag_of_tricks,if=buff.pillar_of_frost.up&active_enemies=1&(buff.pillar_of_frost.remains<5&talent.cold_heart.enabled|!talent.cold_heart.enabled&buff.pillar_of_frost.remains<3)
  if S.BagofTricks:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and (Player:BuffRemains(S.PillarofFrostBuff) < 5 and S.ColdHeart:IsAvailable() or not S.ColdHeart:IsAvailable() and Player:BuffRemains(S.PillarofFrostBuff) < 3) and EnemiesMeleeCount == 1) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 14"; end
  end
end

local function Trinkets()
  -- use_item,name=inscrutable_quantum_device,if=buff.pillar_of_frost.up|target.time_to_pct_20<5|fight_remains<21
  if I.InscrutableQuantumDevice:IsEquippedAndReady() and (Player:BuffUp(S.PillarofFrostBuff) or Target:TimeToX(20) < 5 or HL.FilteredFightRemains(Enemies10yd, "<", 21)) then
    if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device trinkets 2"; end
  end
  -- use_item,name=gavel_of_the_first_arbiter
  if I.GaveloftheFirstArbiter:IsEquippedAndReady() then
    if Cast(I.GaveloftheFirstArbiter, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(30)) then return "gavel_of_the_first_arbiter trinkets 4"; end
  end
  -- use_item,name=scars_of_fraternal_strife
  if I.ScarsofFraternalStrife:IsEquippedAndReady() then
    if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife trinkets 6"; end
  end
  -- use_item,name=the_first_sigil,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
  if I.TheFirstSigil:IsEquippedAndReady() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
    if Cast(I.TheFirstSigil, nil, Settings.Commons.DisplayStyle.Trinkets) then return "the_first_sigil trinkets 8"; end
  end
  -- use_item,slot=trinket1,if=!variable.specified_trinket&buff.pillar_of_frost.up&(!talent.icecap|talent.icecap&buff.pillar_of_frost.remains>=10)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket2,if=!variable.specified_trinket&buff.pillar_of_frost.up&(!talent.icecap|talent.icecap&buff.pillar_of_frost.remains>=10)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket1,if=!trinket.1.has_use_buff&(trinket.2.cooldown.remains|!trinket.2.has_use_buff)|cooldown.pillar_of_frost.remains>20
  -- use_item,slot=trinket2,if=!trinket.2.has_use_buff&(trinket.1.cooldown.remains|!trinket.1.has_use_buff)|cooldown.pillar_of_frost.remains>20
  -- TODO: trinket1/trinket2 stuff, once we can handle trinket sync/priority
  -- Manually added below to handle other trinkets
  -- use_items,if=cooldown.pillar_of_frost.ready|cooldown.pillar_of_frost.remains>20
  if S.PillarofFrost:CooldownUp() or S.PillarofFrost:CooldownRemains() > 20 then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Cooldowns()
  -- potion,if=buff.pillar_of_frost.up
  if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.PillarofFrostBuff)) then
    if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 2"; end
  end
  -- empower_rune_weapon,if=talent.obliteration&rune<6&(variable.st_planning|variable.adds_remain)&(cooldown.pillar_of_frost.remains<5&(cooldown.fleshcraft.remains>5&soulbind.pustule_eruption|!soulbind.pustule_eruption)|buff.pillar_of_frost.up)|fight_remains<20
  if S.EmpowerRuneWeapon:IsCastable() and (S.Obliteration:IsAvailable() and Player:Rune() < 6 and (VarSTPlanning or VarAddsRemain) and (S.PillarofFrost:CooldownRemains() < 5 and (S.Fleshcraft:CooldownRemains() > 5 and S.PustuleEruption:SoulbindEnabled() or not S.PustuleEruption:SoulbindEnabled()) or Player:BuffUp(S.PillarofFrostBuff)) or HL.FilteredFightRemains(Enemies10yd, "<", 20)) then
    if Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 4"; end
  end
  -- empower_rune_weapon,if=talent.breath_of_sindragosa&runic_power.deficit>30&rune.time_to_5>gcd&(buff.breath_of_sindragosa.up|fight_remains<20)
  if S.EmpowerRuneWeapon:IsCastable() and (S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() > 30 and Player:RuneTimeToX(5) > Player:GCD() and (Player:BuffUp(S.BreathofSindragosa) or HL.FilteredFightRemains(Enemies10yd, "<", 20))) then
    if Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 6"; end
  end
  -- empower_rune_weapon,if=talent.icecap
  if S.EmpowerRuneWeapon:IsCastable() and (S.Icecap:IsAvailable()) then
    if Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 8"; end
  end
  -- pillar_of_frost,if=talent.breath_of_sindragosa&(variable.st_planning|variable.adds_remain)&(cooldown.breath_of_sindragosa.remains|cooldown.breath_of_sindragosa.ready&runic_power.deficit<65)
  if S.PillarofFrost:IsCastable() and (S.BreathofSindragosa:IsAvailable() and (VarSTPlanning or VarAddsRemain) and ((not S.BreathofSindragosa:CooldownUp()) or S.BreathofSindragosa:CooldownUp() and Player:RunicPowerDeficit() < 65)) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 10"; end
  end
  -- pillar_of_frost,if=talent.icecap&!buff.pillar_of_frost.up
  if S.PillarofFrost:IsCastable() and (S.Icecap:IsAvailable() and not Player:BuffUp(S.PillarofFrost)) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 12"; end
  end
  -- pillar_of_frost,if=talent.obliteration&(runic_power>=35&!buff.abomination_limb.up|buff.abomination_limb.up|runeforge.rage_of_the_frozen_champion)&(variable.st_planning|variable.adds_remain)&(talent.gathering_storm.enabled&buff.remorseless_winter.up|!talent.gathering_storm.enabled)
  if S.PillarofFrost:IsCastable() and (S.Obliteration:IsAvailable() and (Player:RunicPower() >= 35 and Player:BuffDown(S.AbominationLimb) or Player:BuffUp(S.AbominationLimb) or RageoftheFrozenChampionEquipped) and (VarSTPlanning or VarAddsRemain) and (S.GatheringStorm:IsAvailable() and Player:BuffUp(S.RemorselessWinter) or not S.GatheringStorm:IsAvailable())) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 14"; end
  end
  -- breath_of_sindragosa,if=buff.pillar_of_frost.up
  if S.BreathofSindragosa:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.BreathofSindragosa, nil, Settings.Frost.DisplayStyle.BoS, not Target:IsInMeleeRange(12)) then return "breath_of_sindragosa cooldowns 16"; end
  end
  -- frostwyrms_fury,if=active_enemies=1&buff.pillar_of_frost.remains<gcd&buff.pillar_of_frost.up&!talent.obliteration&(!raid_event.adds.exists|raid_event.adds.in>30)|fight_remains<3
  if S.FrostwyrmsFury:IsCastable() and (EnemiesCount10yd == 1 and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() and Player:BuffUp(S.PillarofFrostBuff) and (not S.Obliteration:IsAvailable()) or HL.FilteredFightRemains(Enemies10yd, "<", 3)) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 18"; end
  end
  -- frostwyrms_fury,if=active_enemies>=2&(buff.pillar_of_frost.up|raid_event.adds.exists&raid_event.adds.in>cooldown.pillar_of_frost.remains+7)&(buff.pillar_of_frost.remains<gcd|raid_event.adds.exists&raid_event.adds.remains<gcd)
  if S.FrostwyrmsFury:IsCastable() and (EnemiesMeleeCount >= 2 and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD()) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 20"; end
  end
  -- frostwyrms_fury,if=talent.obliteration&(buff.pillar_of_frost.up&!main_hand.2h|!buff.pillar_of_frost.up&main_hand.2h&cooldown.pillar_of_frost.remains)&((buff.pillar_of_frost.remains<gcd|buff.unholy_strength.up&buff.unholy_strength.remains<gcd)&(debuff.razorice.stack=5|!death_knight.runeforge.razorice))
  if S.FrostwyrmsFury:IsCastable() and (S.Obliteration:IsAvailable() and (Player:BuffUp(S.PillarofFrostBuff) and (not Using2H) or Player:BuffDown(S.PillarofFrostBuff) and Using2H and S.PillarofFrost:CooldownDown()) and ((Player:BuffRemains(S.PillarofFrostBuff) or Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD()) and (Target:DebuffStack(S.RazoriceDebuff) == 5 or not UsingRazorice))) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 22"; end
  end
  -- hypothermic_presence,if=talent.breath_of_sindragosa&runic_power.deficit>40&rune<=3&(buff.breath_of_sindragosa.up|cooldown.breath_of_sindragosa.remains>40)|!talent.breath_of_sindragosa&runic_power.deficit>=25
  if S.HypothermicPresence:IsCastable() and (S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() > 40 and Player:Rune() <= 3 and (Player:BuffUp(S.BreathofSindragosa) or S.BreathofSindragosa:CooldownRemains() > 40) or not S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() >= 25) then
    if Cast(S.HypothermicPresence, Settings.Frost.GCDasOffGCD.HypothermicPresence) then return "hypothermic_presence cooldowns 24"; end
  end 
  -- raise_dead,if=cooldown.pillar_of_frost.remains<=5
  if S.RaiseDead:IsCastable() and (S.PillarofFrost:CooldownRemains() <= 5) then
    if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 26"; end
  end
  -- sacrificial_pact,if=active_enemies>=2&(fight_remains<3|!buff.breath_of_sindragosa.up&(pet.ghoul.remains<gcd|raid_event.adds.exists&raid_event.adds.remains<3&raid_event.adds.in>pet.ghoul.remains))
  if S.SacrificialPact:IsReady() and ghoul.active() and (EnemiesCount10yd >= 2 and (HL.FilteredFightRemains(Enemies10yd, "<", 3) or Player:BuffDown(S.BreathofSindragosa) and ghoul.remains() < Player:GCD())) then
    if Cast(S.SacrificialPact, Settings.Commons.OffGCDasOffGCD.SacrificialPact, nil, not Target:IsInRange(8)) then return "sacrificial_pact cooldowns 28"; end
  end
  -- death_and_decay,if=active_enemies>5|runeforge.phearomones
  if S.DeathAndDecay:IsReady() and EnemiesCount10yd > 5 then
    if Cast(S.DeathAndDecay, Settings.Commons.OffGCDasOffGCD.DeathAndDecay) then return "death_and_decay cooldowns 30"; end
  end
end

local function Obliteration_Pooling()
  -- remorseless_winter,if=variable.rw_buffs|active_enemies>=2
  if S.RemorselessWinter:IsReady() and (VarRWBuffs or EnemiesCount10yd >= 2) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter obliteration_pooling 2"; end
  end
  -- glacial_advance,if=spell_targets.glacial_advance>=2&talent.frostscythe
  if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2 and S.Frostscythe:IsAvailable()) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance obliteration_pooling 4"; end
  end
  -- frostscythe,if=buff.killing_machine.react&active_enemies>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and EnemiesCount10yd > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe obliteration_pooling 6"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react
  if S.Obliterate:IsReady() and (Player:RuneTimeToX(4) < Player:GCD() or Player:RunicPower() <= 45) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration_pooling 8 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration_pooling 8 no_razorice"; end
    end
  end
  -- frost_strike,if=active_enemies=1&variable.frost_strike_conduits
  if S.FrostStrike:IsReady() and (Enemies10yd == 1 and VarFrostStrikeConduits) then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration_pooling 10"; end
  end
  -- howling_blast,if=variable.rotfc_rime
  if S.HowlingBlast:IsReady() and (VarROTFCRime) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration_pooling 12"; end
  end
  -- glacial_advance,if=spell_targets.glacial_advance>=2&runic_power.deficit<60
  if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2 and Player:RunicPowerDeficit() < 60) then
    if Cast(S.GlacialAdvance, nil, nil, Target:IsInRange(100)) then return "glacial_advance obliteration_pooling 14"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit<70
  if S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < 70) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration_pooling 16 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration_pooling 18 no_razorice"; end
    end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=rune>=3&(!main_hand.2h|covenant.necrolord|covenant.kyrian)|rune>=4&main_hand.2h
  if S.Obliterate:IsReady() and (Player:Rune() >= 3 and ((not Using2H) or CovenantID == 4 or CovenantID == 1) or Player:Rune() >= 4 and Using2H) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration_pooling 18 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration_pooling 18 no_razorice"; end
    end
  end
  -- frostscythe,if=active_enemies>=4&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (EnemiesCount10yd >= 4 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(5)) then return "frostscythe obliteration_pooling 20"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait Resources Obliteration Pooling"; end
end

local function Obliteration()
  -- remorseless_winter,if=active_enemies>=3&variable.rw_buffs
  if S.RemorselessWinter:IsReady() and (EnemiesCount10yd >= 3 and VarRWBuffs) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter obliteration 2"; end
  end
  -- frost_strike,if=!buff.killing_machine.up&(rune<2|talent.icy_talons&buff.icy_talons.remains<gcd*2|conduit.unleashed_frenzy&(buff.unleashed_frenzy.remains<gcd*2|buff.unleashed_frenzy.stack<3))
  if S.FrostStrike:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and (Player:Rune() < 2 or S.IcyTalons:IsAvailable() and Player:BuffRemains(S.IcyTalonsBuff) < Player:GCD() * 2 or S.UnleashedFrenzy:ConduitEnabled() and (Player:BuffRemains(S.UnleashedFrenzyBuff) < Player:GCD() * 2 or Player:BuffStack(S.UnleashedFrenzyBuff) < 3))) then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 4"; end
  end
  -- howling_blast,target_if=!buff.killing_machine.up&rune>=3&(buff.rime.remains<3&buff.rime.up|!dot.frost_fever.ticking)
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and Player:Rune() >= 3 and (Player:BuffRemains(S.RimeBuff) < 3 and Player:BuffUp(S.RimeBuff) or Target:DebuffDown(S.FrostFeverDebuff))) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 6"; end
  end
  -- glacial_advance,if=!buff.killing_machine.up&spell_targets.glacial_advance>=2|!buff.killing_machine.up&(debuff.razorice.stack<5|debuff.razorice.remains<gcd*4)
  if S.GlacialAdvance:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and EnemiesCount10yd >= 2 or Player:BuffDown(S.KillingMachineBuff) and (Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < Player:GCD() * 4)) then
    if Cast(S.GlacialAdvance, nil, nil, Target:IsInRange(100)) then return "glacial_advance obliteration 8"; end
  end
  -- frostscythe,if=buff.killing_machine.react&spell_targets.frostscythe>2&!variable.deaths_due_active
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and EnemiesCount10yd > 2 and not VarDeathsDueActive) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInRange(8)) then return "frostscythe obliteration 10"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff)) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 12 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 12 no_razorice"; end
    end
  end
  -- frost_strike,if=active_enemies=1&variable.frost_strike_conduits
  if S.FrostStrike:IsReady() and (EnemiesCount10yd == 1 and VarFrostStrikeConduits) then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 14"; end
  end
  -- howling_blast,if=variable.rotfc_rime&spell_targets.howling_blast>=2
  if S.HowlingBlast:IsReady() and (VarROTFCRime and EnemiesCount10yd >= 2) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 16"; end
  end
  -- glacial_advance,if=spell_targets.glacial_advance>=2
  if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2) then
    if Cast(S.GlacialAdvance, nil, nil, Target:IsInRange(100)) then return "glacial_advance obliteration 18"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!talent.avalanche&!buff.killing_machine.up|talent.avalanche&!variable.rotfc_rime|variable.rotfc_rime&rune.time_to_2>=gcd
  if S.FrostStrike:IsReady() and ((not S.Avalanche:IsAvailable()) and Player:BuffDown(S.KillingMachineBuff) or S.Avalanche:IsAvailable() and (not VarROTFCRime) or VarROTFCRime and Player:RuneTimeToX(2) >= Player:GCD()) then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 20 razorice"; end
    else
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike obliteration 20 no_razorice"; end
    end
  end
  -- howling_blast,if=variable.rotfc_rime
  if S.HowlingBlast:IsReady() and (VarROTFCRime) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast obliteration 22"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  if S.Obliterate:IsReady() then
    if UsingRazorice then
      if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 24 razorice"; end
    else
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate obliteration 24 no_razorice"; end
    end
  end
end

local function Standard()
  -- remorseless_winter,if=variable.rw_buffs
  if S.RemorselessWinter:IsReady() and (VarRWBuffs) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter standard 2"; end
  end
  -- obliterate,if=buff.killing_machine.react
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff)) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate standard 4"; end
  end
  -- howling_blast,if=variable.rotfc_rime&buff.rime.remains<3
  if S.HowlingBlast:IsReady() and (VarROTFCRime and Player:BuffRemains(S.RimeBuff) < 3) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast standard 6"; end
  end
  -- frost_strike,if=variable.frost_strike_conduits
  if S.FrostStrike:IsReady() and (VarFrostStrikeConduits) then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike standard 8"; end
  end
  -- glacial_advance,if=!death_knight.runeforge.razorice&(debuff.razorice.stack<5|debuff.razorice.remains<gcd*4)
  if S.GlacialAdvance:IsReady() and (not UsingRazorice and (Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < Player:GCD() * 4)) then
    if Cast(S.GlacialAdvance, nil, nil, Target:IsInRange(100)) then return "glacial_advance standard 10"; end
  end
  -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm
  if S.FrostStrike:IsReady() and (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike standard 12"; end
  end
  -- howling_blast,if=variable.rotfc_rime
  if S.HowlingBlast:IsReady() and (VarROTFCRime) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast standard 14"; end
  end
  -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation*5)
  if S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 5)) then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike standard 16"; end
  end
  -- obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse|variable.deaths_due_active&buff.deaths_due.stack<4|rune>=4&set_bonus.tier28_4pc|(main_hand.2h|!covenant.night_fae|!set_bonus.tier28_4pc)&talent.gathering_storm&buff.remorseless_winter.up|!set_bonus.tier28_4pc&runic_power.deficit>(25+talent.runic_attenuation*5)
  if S.Obliterate:IsReady() and (Player:BuffDown(S.FrozenPulseBuff) and S.FrozenPulse:IsAvailable() or VarDeathsDueActive and Player:BuffStack(S.DeathsDueBuff) < 4 or Player:Rune() >= 4 and Player:HasTier(28, 4) or (Using2H or CovenantID ~= 3 or not Player:HasTier(28, 4)) and S.GatheringStorm:IsAvailable() and Player:BuffUp(S.RemorselessWinter) or (not Player:HasTier(28, 4)) and Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 5)) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate standard 18"; end
  end
  -- frost_strike
  if S.FrostStrike:IsReady() then
    if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike standard 20"; end
  end
  -- Horn of Winter
  if S.HornofWinter:IsCastable() then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter standard 22"; end
  end
  -- Arcane Torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent, nil, not Target:IsInRange(8)) then return "arcane_torrent standard 24"; end
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

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and not no_heal then
      if Cast(S.DeathStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "death_strike low hp or proc"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- variable,name=specified_trinket,value=(equipped.inscrutable_quantum_device|equipped.the_first_sigil)&(cooldown.inscrutable_quantum_device.ready|cooldown.the_first_sigil.remains)|equipped.the_first_sigil&equipped.inscrutable_quantum_device
    -- TODO: Leaving this commented out until other trinket sync/priority variables can be handled
    --VarSpecifiedTrinket = (I.InscrutableQuantumDevice:IsEquippedAndReady())
    -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
    VarSTPlanning = (EnemiesCount10yd == 1 or not AoEON())
    -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&(raid_event.adds.remains>5|target.1.time_to_die>10))
    VarAddsRemain = (EnemiesCount10yd >= 2 and AoEON())
    -- variable,name=rotfc_rime,value=buff.rime.up&(!runeforge.rage_of_the_frozen_champion|runeforge.rage_of_the_frozen_champion&runic_power.deficit>8)
    VarROTFCRime = (Player:BuffUp(S.RimeBuff) and ((not RageoftheFrozenChampionEquipped) or RageoftheFrozenChampionEquipped and Player:RunicPowerDeficit() > 8))
    -- variable,name=frost_strike_conduits,value=conduit.eradicating_blow&buff.eradicating_blow.stack=2|conduit.unleashed_frenzy&buff.unleashed_frenzy.remains<(gcd*2)
    VarFrostStrikeConduits = (S.EradicatingBlow:ConduitEnabled() and Player:BuffStack(S.EradicatingBlowBuff) == 2 or S.UnleashedFrenzy:ConduitEnabled() and Player:BuffRemains(S.UnleashedFrenzyBuff) < (Player:GCD() * 2))
    -- variable,name=deaths_due_active,value=death_and_decay.ticking&covenant.night_fae
    VarDeathsDueActive = (Player:BuffUp(S.DeathAndDecayBuff) and CovenantID == 3)
    -- remorseless_winter,if=conduit.everfrost&talent.gathering_storm&!talent.obliteration&cooldown.pillar_of_frost.remains|set_bonus.tier28_4pc&talent.obliteration&!buff.pillar_of_frost.up)
    if S.RemorselessWinter:IsReady() and (S.Everfrost:ConduitEnabled() and S.GatheringStorm:IsAvailable() and not S.Obliteration:IsAvailable() and not S.PillarofFrost:CooldownUp() or Player:HasTier(28, 4) and S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff)) then
      if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter main 2"; end
    end
    -- howling_blast,target_if=!dot.frost_fever.remains&(talent.icecap|!buff.breath_of_sindragosa.up&talent.breath_of_sindragosa|talent.obliteration&cooldown.pillar_of_frost.remains&!buff.killing_machine.up)
    if S.HowlingBlast:IsReady() and (S.Icecap:IsAvailable() or Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:IsAvailable() or S.Obliteration:IsAvailable() and S.PillarofFrost:CooldownDown() and Player:BuffDown(S.KillingMachineBuff)) then
      if Everyone.CastCycle(S.HowlingBlast, Enemies10yd, EvaluateCycleHowlingBlast, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast main 4"; end
    end
    -- glacial_advance,if=buff.icy_talons.remains<=gcd*2&talent.icy_talons&spell_targets.glacial_advance>=2&(talent.icecap|talent.breath_of_sindragosa&cooldown.breath_of_sindragosa.remains>15|talent.obliteration&!buff.pillar_of_frost.up)
    if S.GlacialAdvance:IsReady() and (Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() * 2 and S.IcyTalons:IsAvailable() and EnemiesCount10yd >= 2 and (S.Icecap:IsAvailable() or S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemains() > 15 or S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff))) then
      if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance main 6"; end
    end
    -- frost_strike,if=buff.icy_talons.remains<=gcd*2&talent.icy_talons&(talent.icecap|talent.breath_of_sindragosa&!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains>10|talent.obliteration&!buff.pillar_of_frost.up)
    if S.FrostStrike:IsReady() and (Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() * 2 and S.IcyTalons:IsAvailable() and (S.Icecap:IsAvailable() or S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:CooldownRemains() > 10 or S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff))) then
      if Cast(S.FrostStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "frost_strike main 8"; end
    end
    -- obliterate,if=covenant.night_fae&death_and_decay.ticking&death_and_decay.active_remains<(gcd*1.5)&(!talent.obliteration|talent.obliteration&!buff.pillar_of_frost.up)
    local AnyDnD = S.DeathsDue:IsAvailable() and S.DeathsDue or S.DeathAndDecay
    if S.Obliterate:IsReady() and (CovenantID == 3 and Player:BuffUp(S.DeathAndDecayBuff) and 10 - AnyDnD:TimeSinceLastCast() < (Player:GCD() * 1.5) and ((not S.Obliteration:IsAvailable()) or S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff))) then
      if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate main 10"; end
    end
    -- call_action_list,name=covenants
    if (true) then
      local ShouldReturn = Covenants(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if (Settings.Commons.Enabled.Trinkets) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cold_heart,if=talent.cold_heart&(!buff.killing_machine.up|talent.breath_of_sindragosa)&((debuff.razorice.stack=5|!death_knight.runeforge.razorice)|fight_remains<=gcd)
    if (S.ColdHeart:IsAvailable() and (Player:BuffDown(S.KillingMachineBuff) or S.BreathofSindragosa:IsAvailable()) and ((Target:DebuffStack(S.RazoriceDebuff) == 5 or not UsingRazorice) or HL.FilteredFightRemains(Enemies10yd, "<=", Player:GCD()))) then
      local ShouldReturn = ColdHeart(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_ticking,if=buff.breath_of_sindragosa.up
    if (Player:BuffUp(S.BreathofSindragosa)) then
      local ShouldReturn = BosTicking(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.remains<10)&(raid_event.adds.in>25|!raid_event.adds.exists|cooldown.pillar_of_frost.remains<10&raid_event.adds.exists&raid_event.adds.in<10)
    if (not Settings.Frost.DisableBoSPooling and (S.BreathofSindragosa:IsAvailable() and (S.BreathofSindragosa:CooldownRemains() < 10))) then
      local ShouldReturn = BosPooling(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration
    if (Player:BuffUp(S.PillarofFrostBuff) and S.Obliteration:IsAvailable()) then
      local ShouldReturn = Obliteration(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=obliteration_pooling,if=!set_bonus.tier28_4pc&!runeforge.rage_of_the_frozen_champion&talent.obliteration&cooldown.pillar_of_frost.remains<10&(variable.st_planning|raid_event.adds.exists&raid_event.adds.in<10|!raid_event.adds.exists)
    if ((not Player:HasTier(28, 4)) and (not RageoftheFrozenChampionEquipped) and S.Obliteration:IsAvailable() and S.PillarofFrost:CooldownRemains() < 10) then
      local ShouldReturn = Obliteration_Pooling(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=2
    if (AoEON() and EnemiesCount10yd >= 2) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  --HR.Print("Frost DK rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(251, APL, Init)

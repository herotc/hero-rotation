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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Frost
local I = Item.DeathKnight.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.InscrutableQuantumDevice:ID()
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
local ShouldReturn -- Used to get the return string
local no_heal
local UsingRazorice
local UsingFallenCrusader
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local VarSpecifiedTrinket

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

-- Functions
local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local BitingColdEquipped = Player:HasLegendaryEquipped(39)
local MainHandLink = GetInventoryItemLink("player", 16) or ""
local OffHandLink = GetInventoryItemLink("player", 17) or ""
local _, _, MainHandRuneforge = strsplit(":", MainHandLink)
local _, _, OffHandRuneforge = strsplit(":", OffHandLink)
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
  BitingColdEquipped = Player:HasLegendaryEquipped(39)
  MainHandLink = GetInventoryItemLink("player", 16) or ""
  OffHandLink = GetInventoryItemLink("player", 17) or ""
  _, _, MainHandRuneforge = strsplit(":", MainHandLink)
  _, _, OffHandRuneforge = strsplit(":", OffHandLink)
end, "PLAYER_EQUIPMENT_CHANGED")

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
  return ((TargetUnit:DebuffStack(S.RazoriceDebuff) + 1) % (TargetUnit:DebuffRemains(S.RazoriceDebuff) + 1))
end

-- Standard
local function EvaluateTargetIfStandardFrostStrike(TargetUnit)
  return (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable())
end
local function EvaluateTargetIfStandardFrostStrike2(TargetUnit)
  return (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3))
end
local function EvaluateTargetIfStandardObliterate(TargetUnit)
  return (Player:RunicPowerDeficit() >= (25 + num(S.RunicAttenuation:IsAvailable()) * 3))
end
-- AOE
local function EvaluateTargetIfFrostStrikeAOE(TargetUnit)
  return (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable())
end
local function EvaluateTargetIfFrostStrikeAOE2(TargetUnit)
  return (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3))
end
local function EvaluateTargetIfObliterateAOE(TargetUnit)
  return (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3))
end

-- BoS Pooling
local function EvaluateTargetIfObliterateBoSPooling(TargetUnit)
  return (Player:RunicPowerDeficit() >= 25)
end

local function EvaluateTargetIfObliterateBoSPooling2(TargetUnit)
  return (Player:RunicPowerDeficit() >= 35 + (num(S.RunicAttenuation:IsAvailable()) * 3))
end

local function EvaluateTargetIfFrostStrikeBoSPooling(TargetUnit)
  return (Player:RunicPowerDeficit() < 20 and S.PillarofFrost:CooldownRemains() > 5)
end

local function EvaluateTargetIfFrostStrikeBoSPooling2(TargetUnit)
  return (S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40)
end

-- BoS Ticking
local function EvaluateTargetIfObliterateBoSTicking(TargetUnit)
  return (Player:BuffUp(S.KillingMachineBuff))
end

local function EvaluateTargetIfObliterateBoSTicking2(TargetUnit)
  return (Player:RunicPowerDeficit() > 25 and Player:Rune() > 3)
end

local function EvaluateTargetIfObliterateBoSTicking3(TargetUnit)
  return (Player:RunicPowerDeficit() >= 60)
end

local function EvaluateTargetIfObliterateBoSTicking4(TargetUnit)
  return (Player:RuneTimeToX(4) < Player:GCD() or Player:RunicPowerDeficit() >= 45)
end

--Obliteration_Pooling
local function EvaluateTargetIfObliterateOblitPooling(TargetUnit)
  return (Player:RuneTimeToX(4) < Player:GCD() or Player:RunicPower() <= 45)
end
local function EvaluateTargetIfFrostStrikeOblitPooling(TargetUnit)
  return (Player:RunicPowerDeficit() < 70)
end
local function EvaluateTargetIfObliterateOblitPooling(TargetUnit)
  return (Player:Rune() > 4)
end

-- Obliteration
local function EvaluateTargetIfObliterationOblit(TargetUnit)
  return (Player:BuffUp(S.KillingMachineBuff) or not Player:BuffUp(S.RimeBuff) and EnemiesCount10yd >= 3)
end
local function EvaluateTargetIfObliterationFrostStrike(TargetUnit)
  return (not S.Avalanche:IsAvailable() and not Player:BuffUp(S.KillingMachineBuff) or S.Avalanche:IsAvailable() and not Player:BuffUp(S.RimeBuff))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- opener
  if Everyone.TargetIsValid() then
    -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(!talent.breath_of_sindragosa&(trinket.1.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.1.cooldown.duration=0)|talent.icecap)
    -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(!talent.breath_of_sindragosa&(trinket.2.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.2.cooldown.duration=0)|talent.icecap)
    -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!trinket.1.has_use_buff&trinket.2.has_use_buff|trinket.2.has_use_buff&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
    -- TODO: Trinket sync/priority stuff. Currently unable to pull trinket CD durations because WoW's API is bad.
    if S.HowlingBlast:IsCastable() and (Target:DebuffDown(S.FrostFeverDebuff)) then
      if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast precombat"; end
    end
    if S.Obliterate:IsCastable() and (S.BreathofSindragosa:IsAvailable()) then
      if Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate precombat"; end
    end
  end
end

local function Aoe()
  -- remorseless_winter
  if S.RemorselessWinter:IsCastable() then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter aoe 1"; end
  end
  -- glacial_advance,if=talent.frostscythe
  if no_heal and S.GlacialAdvance:IsReady() and (S.Frostscythe:IsAvailable()) then
    if Cast(S.GlacialAdvance, nil, nil, not TargetIsInRange[30]) then return "glacial_advance aoe 2"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm
  if no_heal and S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfFrostStrikeAOE) then return "frost_strike aoe 3"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast aoe 4"; end
  end
  -- obliterate,if=death_and_decay.ticking&covenant.night_fae&buff.deaths_due.stack<4
  if S.Obliterate:IsCastable() and (Player:BuffUp(S.DeathAndDecayBuff) and Player:Covenant() == "Night Fae" and Player:BuffStack(S.DeathsDueBuff) < 4) then
    if Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate aoe 4.5"; end
  end
  -- frostscythe,if=buff.killing_machine.react&(!death_and_decay.ticking&covenant.night_fae|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and (not Player:BuffUp(S.DeathAndDecayBuff) and Player:Covenant() == "Night Fae" or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe aoe 5"; end
  end
  -- glacial_advance,if=runic_power.deficit<(15+talent.runic_attenuation*3)
  if no_heal and S.GlacialAdvance:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if Cast(S.GlacialAdvance, nil, nil, not TargetIsInRange[30]) then return "glacial_advance aoe 6"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit<(15+talent.runic_attenuation*3)
  if no_heal and S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfFrostStrikeAOE2) then return "frost_strike aoe 7"; end
  end
  -- remorseless_winter
  if S.RemorselessWinter:IsCastable() then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter aoe 8"; end
  end
  -- frostscythe,if=!death_and_decay.ticking&covenant.night_fae|!covenant.night_fae
  if S.Frostscythe:IsCastable() and (not Player:BuffUp(S.DeathAndDecayBuff) and Player:Covenant() == "Night Fae" or not Player:Covenant() == "Night Fae") then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe aoe 9"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>(25+talent.runic_attenuation*3)
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateAOE) then return "obliterate aoe 10"; end
  end
  -- glacial_advance
  if no_heal and S.GlacialAdvance:IsReady() then
    if Cast(S.GlacialAdvance, nil, nil, not TargetIsInRange[30]) then return "glacial_advance aoe 11"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  if no_heal and S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil) then return "frost_strike aoe 12"; end
  end
  -- horn_of_winter
  if S.HornofWinter:IsCastable() then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter aoe 17"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_torrent aoe 18"; end
  end
end

local function BosPooling()
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast) then return "howling_blast bos 1"; end
  end
  -- remorseless_winter,if=active_enemies>=2|rune.time_to_5<=gcd&(talent.gathering_storm|conduit.everfrost|runeforge.biting_cold)
  if S.RemorselessWinter:IsCastable() and (EnemiesCount10yd >= 2 or Player:RuneTimeToX(5) <= Player:GCD() and (S.GatheringStorm:IsAvailable() or S.Everfrost:ConduitEnabled() or BitingColdEquipped)) then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter bos 2"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>=25
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateBoSPooling) then return "obliterate bos_pooling 3"; end
  end
  -- glacial_advance,if=runic_power.deficit<20&spell_targets.glacial_advance>=2&cooldown.pillar_of_frost.remains>5
  if no_heal and S.GlacialAdvance:IsReady() and (Player:RunicPowerDeficit() < 20 and EnemiesCount10yd >= 2 and S.PillarofFrost:CooldownRemains() > 5) then
    if Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance bos 4"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>5
  if no_heal and S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfFrostStrikeBoSPooling) then return "frost_strike bos 5"; end
  end
  -- frostscythe,if=buff.killing_machine.react&runic_power.deficit>(15+talent.runic_attenuation*3)&spell_targets.frostscythe>=2&(buff.deaths_due.stack=8|!death_and_decay.ticking|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and Player:RunicPowerDeficit() > (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and EnemiesMeleeCount >= 2 and (Player:BuffStack(S.DeathsDueBuff) == 8 or not Player:BuffUp(S.DeathAndDecayBuff) or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos 6"; end
  end
  -- frostscythe,if=runic_power.deficit>=(35+talent.runic_attenuation*3)&spell_targets.frostscythe>=2&(buff.deaths_due.stack=8|!death_and_decay.ticking|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3) and EnemiesMeleeCount >= 2 and (Player:BuffStack(S.DeathsDueBuff) == 8 or not Player:BuffUp(S.DeathAndDecayBuff) or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos 7"; end
  end
  -- glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
  if no_heal and S.GlacialAdvance:IsReady() and (S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and EnemiesCount10yd >= 2) then
    if Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance bos 9"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
  if S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfFrostStrikeBoSPooling2) then return "frost_strike bos 10"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Pooling"; end
end

local function BosTicking()
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>=60
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateBoSTicking3) then return "obliterate bos ticking 1"; end
  end
  -- remorseless_winter,if=talent.gathering_storm|conduit.everfrost|runeforge.biting_cold|active_enemies>=2
  if S.RemorselessWinter:IsCastable() and (S.GatheringStorm:IsAvailable() or S.Everfrost:ConduitEnabled() or BitingColdEquipped or EnemiesCount10yd >= 2) then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter bos ticking 2"; end
  end
  -- howling_blast,if=buff.rime.up&(runic_power.deficit<55|rune.time_to_3<=gcd|spell_targets.howling_blast>=2)
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff) and (Player:RunicPowerDeficit() < 55 or Player:RuneTimeToX(3) <= Player:GCD() or EnemiesCount10yd >= 2)) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast bos ticking 3"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=rune.time_to_4<gcd|runic_power.deficit>=45
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateBoSTicking4) then return "obliterate bos ticking 4"; end
  end
  -- frostscythe,if=buff.killing_machine.up&spell_targets.frostscythe>=2&(!death_and_decay.ticking&covenant.night_fae|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and EnemiesCount10yd >= 2 and (not Player:BuffUp(S.DeathAndDecayBuff) and Player:Covenant() == "Night Fae" or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos ticking 5"; end
  end
  -- horn_of_winter,if=runic_power.deficit>=40&rune.time_to_3>gcd
  if S.HornofWinter:IsCastable() and (Player:RunicPowerDeficit() >= 40 and Player:RuneTimeToX(3) > Player:GCD()) then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter bos ticking 6"; end
  end
  -- frostscythe,if=spell_targets.frostscythe>=2&(buff.deaths_due.stack=8|!death_and_decay.ticking|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (EnemiesCount10yd >= 2 and (Player:BuffStack(S.DeathsDueBuff) == 8 or not Player:BuffUp(S.DeathAndDecayBuff) or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos ticking 7"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit>25&rune>3
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateBoSTicking2) then return "obliterate bos ticking 8"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast bos ticking 9"; end
  end
  -- arcane_torrent,if=runic_power.deficit>50
  if S.ArcaneTorrent:IsCastable() and Player:RunicPowerDeficit() > 50 and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent bos ticking 10"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Ticking"; end
end

local function ColdHeart()
  -- chains_of_ice,if=fight_remains<gcd
  if S.ChainsofIce:IsCastable() and (HL.FilteredFightRemains(Enemies10yd, "<", Player:GCD())) then
    if Cast(S.ChainsofIce, nil, nil, not TargetIsInRange[30]) then return "chains_of_ice cold_heart 1"; end
  end
  -- chains_of_ice,if=!talent.obliteration&buff.pillar_of_frost.remains<3&buff.pillar_of_frost.up&buff.cold_heart.stack>=10
  if S.ChainsofIce:IsCastable() and (not S.Obliteration:IsAvailable() and Player:BuffRemains(S.PillarofFrostBuff) < 3 and Player:BuffUp(S.PillarofFrostBuff) and Player:BuffStack(S.ColdHeartBuff) >= 10) then
    if Cast(S.ChainsofIce, nil, nil, not TargetIsInRange[30]) then return "chains_of_ice cold_heart 2"; end
  end
  -- chains_of_ice,if=!talent.obliteration&death_knight.runeforge.fallen_crusader&(buff.cold_heart.stack>=16&buff.unholy_strength.up|buff.cold_heart.stack>=19&cooldown.pillar_of_frost.remains>10)
  if S.ChainsofIce:IsCastable() and (not S.Obliteration:IsAvailable() and UsingFallenCrusader and (Player:BuffStack(S.ColdHeartBuff) >= 16 and Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffStack(S.ColdHeartBuff) >= 19 and S.PillarofFrost:CooldownRemains() > 10)) then
    if Cast(S.ChainsofIce, nil, nil, not TargetIsInRange[30]) then return "chains_of_ice cold_heart 3"; end
  end
  -- chains_of_ice,if=!talent.obliteration&!death_knight.runeforge.fallen_crusader&buff.cold_heart.stack>=10&buff.pillar_of_frost.up&cooldown.pillar_of_frost.remains>20
  if S.ChainsofIce:IsCastable() and (not S.Obliteration:IsAvailable() and not UsingFallenCrusader and Player:BuffStack(S.ColdHeartBuff) >= 10 and Player:BuffUp(S.PillarofFrostBuff) and S.PillarofFrost:CooldownRemains() > 20) then
    if Cast(S.ChainsofIce, nil, nil, not TargetIsInRange[30]) then return "chains_of_ice cold_heart 4"; end
  end
  -- chains_of_ice,if=talent.obliteration&!buff.pillar_of_frost.up&(buff.cold_heart.stack>=16&buff.unholy_strength.up|buff.cold_heart.stack>=19|cooldown.pillar_of_frost.remains<3&buff.cold_heart.stack>=14)
  if S.ChainsofIce:IsCastable() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and (Player:BuffStack(S.ColdHeartBuff) >= 16 and Player:BuffUp(S.UnholyStrengthBuff) or Player:BuffStack(S.ColdHeartBuff) >= 19 or S.PillarofFrost:CooldownRemains() < 3 and Player:BuffStack(S.ColdHeartBuff) >= 14)) then
    if Cast(S.ChainsofIce, nil, nil, not TargetIsInRange[30]) then return "chains_of_ice coldheart 5"; end
  end
end

local function Covenants()
  -- deaths_due,if=raid_event.adds.in>15|!raid_event.adds.exists|active_enemies>=2
  if S.DeathsDue:IsCastable() then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "deaths due covenant"; end
  end
  -- swarming_mist,if=active_enemies=1&runic_power.deficit>3&cooldown.pillar_of_frost.remains<3&!talent.breath_of_sindragosa&(!raid_event.adds.exists|raid_event.adds.in>15)
  if S.SwarmingMist:IsCastable() and (EnemiesCount10yd == 1 and Player:RunicPowerDeficit() > 3 and S.PillarofFrost:CooldownRemains() < 3 and not S.BreathofSindragosa:IsAvailable()) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "swarming mist st"; end
  end
  -- swarming_mist,if=active_enemies>=2&!talent.breath_of_sindragosa
  if S.SwarmingMist:IsCastable() and (EnemiesCount10yd >= 2 and not S.BreathofSindragosa:IsAvailable()) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "swarming mist aoe"; end
  end
  --swarming_mist,if=talent.breath_of_sindragosa&(buff.breath_of_sindragosa.up&(active_enemies=1&runic_power.deficit>40|active_enemies>=2&runic_power.deficit>60)|!buff.breath_of_sindragosa.up&cooldown.breath_of_sindragosa.remains)
  if S.SwarmingMist:IsCastable() and (S.BreathofSindragosa:IsAvailable() and (Player:BuffUp(S.BreathofSindragosa) and (EnemiesCount10yd == 1 and Player:RunicPowerDeficit() > 40 or EnemiesCount10yd >= 2 and Player:RunicPowerDeficit() > 60) or Player:BuffDown(S.BreathofSindragosa) and not S.BreathofSindragosa:CooldownUp())) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "swarming mist bos"; end
  end
  --abomination_limb,if=active_enemies=1&cooldown.pillar_of_frost.remains<3&(!raid_event.adds.exists|raid_event.adds.in>15)
  if S.AbominationLimb:IsCastable() and (EnemiesCount10yd == 1 and S.PillarofFrost:CooldownRemains() < 3) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "abomination limb st"; end
  end
  --abomination_limb,if=active_enemies>=2
  if S.AbominationLimb:IsCastable() and EnemiesCount10yd >= 2 then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "abomination limb aoe"; end
  end
  --shackle_the_unworthy,if=active_enemies=1&cooldown.pillar_of_frost.remains<3&(!raid_event.adds.exists|raid_event.adds.in>15)
  if S.ShackleTheUnworthy:IsCastable() and (EnemiesCount10yd == 1 and S.PillarofFrost:CooldownRemains() < 3) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "shackle unworthy st"; end
  end
  --shackle_the_unworthy,if=active_enemies>=2
  if S.ShackleTheUnworthy:IsCastable() and EnemiesCount10yd >= 2 then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not TargetIsInRange[10]) then return "shackle unworthy aoe"; end
  end
end

local function Racials()
  -- blood_fury,if=buff.pillar_of_frost.up
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff)) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial 1"; end
  end
  -- berserking,if=buff.pillar_of_frost.up
  if S.Berserking:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial 2"; end
  end
  -- arcane_pulse,if=(!buff.pillar_of_frost.up&active_enemies>=2)|!buff.pillar_of_frost.up&(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and ((Player:BuffUp(S.PillarofFrostBuff) and EnemiesMeleeCount >= 2) and Player:BuffDown(S.PillarofFrostBuff) and (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_pulse racial 3"; end
  end
  -- lights_judgment,if=buff.pillar_of_frost.up
  if S.LightsJudgment:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "lights_judgment racial 4"; end
  end
  -- ancestral_call,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
  if S.AncestralCall:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial 5"; end
  end
  -- fireblood,if=buff.pillar_of_frost.remains<=8&buff.empower_rune_weapon.up
  if S.Fireblood:IsCastable() and (Player:BuffRemains(S.PillarofFrostBuff) <= 8 and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial 6"; end
  end
  -- bag_of_tricks,if=buff.pillar_of_frost.up&active_enemies=1&(buff.pillar_of_frost.remains<5&talent.cold_heart.enabled|!talent.cold_heart.enabled&buff.pillar_of_frost.remains<3)
  if S.BagofTricks:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and (Player:BuffRemains(S.PillarofFrostBuff) < 5 and S.ColdHeart:IsAvailable() or not S.ColdHeart:IsAvailable() and Player:BuffRemains(S.PillarofFrostBuff) < 3) and EnemiesMeleeCount == 1) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "bag_of_tricks racial 7"; end
  end
end

local function Trinkets()
  -- use_item,name=inscrutable_quantum_device,if=buff.pillar_of_frost.up|target.time_to_pct_20<5|fight_remains<21
  if I.InscrutableQuantumDevice:IsEquippedAndReady() and (Player:BuffUp(S.PillarofFrostBuff) or Target:TimeToX(20) < 5 or HL.FilteredFightRemains(Enemies10yd, "<", 21)) then
    if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device trinkets"; end
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
    if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns"; end
  end
  -- empower_rune_weapon,if=talent.obliteration&(cooldown.pillar_of_frost.ready&rune.time_to_5>gcd&runic_power.deficit>=10|buff.pillar_of_frost.up&rune.time_to_5>gcd)|fight_remains<20
  if S.EmpowerRuneWeapon:IsCastable() and (S.Obliteration:IsAvailable() and (S.PillarofFrost:CooldownUp() and Player:RuneTimeToX(5) > Player:GCD() and Player:RunicPowerDeficit() >= 10 or Player:BuffUp(S.PillarofFrostBuff) and Player:RuneTimeToX(5) > Player:GCD()) or HL.FilteredFightRemains(Enemies10yd, "<", 20)) then
    if Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cd 1"; end
  end
  -- empower_rune_weapon,if=talent.breath_of_sindragosa&runic_power.deficit>40&rune.time_to_5>gcd&(buff.breath_of_sindragosa.up|fight_remains<20)
  if S.EmpowerRuneWeapon:IsCastable() and (S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() > 40 and Player:RuneTimeToX(5) > Player:GCD() and (Player:BuffUp(S.BreathofSindragosa) or HL.FilteredFightRemains(Enemies10yd, "<", 20))) then
    if Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cd 2"; end
  end
  -- empower_rune_weapon,if=talent.icecap&rune<3
  if S.EmpowerRuneWeapon:IsCastable() and (S.Icecap:IsAvailable() and Player:Rune() < 3) then
    if Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cd 3"; end
  end
  -- pillar_of_frost,if=talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.remains|cooldown.breath_of_sindragosa.ready&runic_power.deficit<60)
  if S.PillarofFrost:IsCastable() and (S.BreathofSindragosa:IsAvailable() and (bool(S.BreathofSindragosa:CooldownRemains()) or S.BreathofSindragosa:CooldownUp() and Player:RunicPowerDeficit() < 60)) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cd 4"; end
  end
  -- pillar_of_frost,if=talent.icecap&!buff.pillar_of_frost.up
  if S.PillarofFrost:IsCastable() and (S.Icecap:IsAvailable() and not Player:BuffUp(S.PillarofFrost)) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cd 4"; end
  end
  -- pillar_of_frost,if=talent.obliteration&(talent.gathering_storm.enabled&buff.remorseless_winter.up|!talent.gathering_storm.enabled)
  if S.PillarofFrost:IsCastable() and (S.Obliteration:IsAvailable() and (S.GatheringStorm:IsAvailable() and Player:BuffUp(S.RemorselessWinter) or not S.GatheringStorm:IsAvailable())) then
    if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cd 5"; end
  end
  -- breath_of_sindragosa,if=buff.pillar_of_frost.up
  if S.BreathofSindragosa:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.BreathofSindragosa, nil, Settings.Frost.DisplayStyle.BoS, not TargetIsInRange[8]) then return "breath_of_sindragosa cd 6"; end
  end
  -- frostwyrms_fury,if=buff.pillar_of_frost.remains<gcd&buff.pillar_of_frost.up&!talent.obliteration
  if S.FrostwyrmsFury:IsCastable() and (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() and Player:BuffUp(S.PillarofFrostBuff) and not S.Obliteration:IsAvailable()) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not TargetIsInRange[40]) then return "frostwyrms_fury cd 7"; end
  end
  -- frostwyrms_fury,if=active_enemies>=2&(buff.pillar_of_frost.up&buff.pillar_of_frost.remains<gcd|raid_event.adds.exists&raid_event.adds.remains<gcd|fight_remains<gcd)
  if S.FrostwyrmsFury:IsCastable() and (EnemiesMeleeCount >= 2 and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() or HL.FilteredFightRemains(Enemies10yd, "<", Player:GCD()))) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not TargetIsInRange[40]) then return "frostwyrms_fury cd 8"; end
  end
  -- frostwyrms_fury,if=talent.obliteration&!buff.pillar_of_frost.up&((buff.unholy_strength.up|!death_knight.runeforge.fallen_crusader)&(debuff.razorice.stack=5|!death_knight.runeforge.razorice))
  if S.FrostwyrmsFury:IsCastable() and (S.Obliteration:IsAvailable() and not Player:BuffUp(S.PillarofFrostBuff) and ((Player:BuffUp(S.UnholyStrengthBuff) or not UsingFallenCrusader) and (Target:DebuffStack(S.RazoriceDebuff) == 5 or not UsingRazorice))) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not TargetIsInRange[40]) then return "frostwyrms_fury cd 9"; end
  end
  -- hypothermic_presence,if=talent.breath_of_sindragosa&runic_power.deficit>40&rune>=3&buff.pillar_of_frost.up|!talent.breath_of_sindragosa&runic_power.deficit>=25
  if S.HypothermicPresence:IsCastable() and (S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() > 40 and Player:Rune() >= 3 and S.PillarofFrost:CooldownUp() or not S.BreathofSindragosa:IsAvailable() and Player:RunicPowerDeficit() >= 25) then
    if Cast(S.HypothermicPresence, Settings.Frost.GCDasOffGCD.HypothermicPresence) then return "hypothermic_presence cd 10"; end
  end 
  -- raise_dead,if=buff.pillar_of_frost.up
  if S.RaiseDead:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
    if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead cd 11"; end
  end
  -- sacrificial_pact,if=active_enemies>=2&(pet.ghoul.remains<gcd|target.time_to_die<gcd)
  if S.SacrificialPact:IsCastable() and (EnemiesCount10yd >= 2 and ((S.RaiseDead:TimeSinceLastCast() > (55 + Player:GCD()) and S.RaiseDead:TimeSinceLastCast() < (60 - Player:GCD())) or Target:TimeToDie() < Player:GCD())) then
    if Cast(S.SacrificialPact, Settings.Commons.OffGCDasOffGCD.SacrificialPact, nil, not TargetIsInRange[8]) then return "sacrificial pact cd 12"; end
  end
  -- death_and_decay,if=active_enemies>5|runeforge.phearomones
  if S.DeathAndDecay:IsCastable() and EnemiesCount10yd > 5 then
    if Cast(S.DeathAndDecay, Settings.Commons.OffGCDasOffGCD.DeathAndDecay) then return "dnd aoe 13"; end
  end
end

local function Obliteration_Pooling()
  -- remorseless_winter,if=talent.gathering_storm|conduit.everfrost|runeforge.biting_cold|active_enemies>=2
  if S.RemorselessWinter:IsCastable() and (S.GatheringStorm:IsAvailable() or S.Everfrost:ConduitEnabled() or BitingColdEquipped or EnemiesCount10yd >= 2) then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter obliteration_pool 1"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast) then return "howling_blast obliteration_pool 2"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateOblitPooling) then return "obliterate obliteration_pool 3"; end
  end
  -- glacial_advance,if=spell_targets.glacial_advance>=2&runic_power.deficit<60
  if no_heal and S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2 and Player:RunicPowerDeficit() < 60) then
    if Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance obliteration_pool 4"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=runic_power.deficit<70
  if no_heal and S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfFrostStrikeOblitPooling) then return "frost_strike obliteration_pool 5"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=rune>4
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterateOblitPooling2) then return "obliterate obliteration_pool 6"; end
  end
  -- frostscythe,if=active_enemies>=4&(!death_and_decay.ticking&covenant.night_fae|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (EnemiesCount10yd >= 4 and (not Player:BuffUp(S.DeathAndDecayBuff) and Player:Covenant() == "Night Fae" or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe obliteration_pool 7"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources Obliteration Pooling"; end
end

local function Obliteration()
  -- remorseless_winter,if=active_enemies>=3&(talent.gathering_storm|conduit.everfrost|runeforge.biting_cold)
  if S.RemorselessWinter:IsCastable() and (EnemiesCount10yd >= 3 and (S.GatheringStorm:IsAvailable() or S.Everfrost:ConduitEnabled() or BitingColdEquipped)) then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter obliteration 1"; end
  end
  -- howling_blast,if=!dot.frost_fever.ticking&!buff.killing_machine.up
  if S.HowlingBlast:IsCastable() and (not Target:DebuffUp(S.FrostFeverDebuff) and not Player:BuffUp(S.KillingMachineBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast obliteration 2"; end
  end
  -- frostscythe,if=buff.killing_machine.react&spell_targets.frostscythe>=2&(buff.deaths_due.stack=8|!death_and_decay.ticking|!covenant.night_fae)
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and EnemiesCount10yd >= 2 and (Player:BuffStack(S.DeathsDueBuff) == 8 or not Player:BuffUp(S.DeathAndDecayBuff) or not Player:Covenant() == "Night Fae")) then
    if Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe obliteration 3"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=buff.killing_machine.react|!buff.rime.up&spell_targets.howling_blast>=3
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterationOblit) then return "obliterate obliteration 4"; end
  end
  -- glacial_advance,if=spell_targets.glacial_advance>=2&(runic_power.deficit<10|rune.time_to_2>gcd)|(debuff.razorice.stack<5|debuff.razorice.remains<15)
  if S.GlacialAdvance:IsReady() and (EnemiesCount10yd >= 2  and (Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) or (Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 15)) then
    if Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance obliteration 5"; end
  end
  -- frost_strike,if=conduit.eradicating_blow&buff.eradicating_blow.stack=2&active_enemies=1
  if no_heal and S.FrostStrike:IsReady() and (S.EradicatingBlow:ConduitEnabled() and Player:BuffStack(S.EradicatingBlowBuff) == 2 and EnemiesCount10yd == 1) then
    if Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike obliteration 6"; end
  end
  -- howling_blast,if=buff.rime.up&spell_targets.howling_blast>=2
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff) and EnemiesCount10yd >= 2) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast obliteration 7"; end
  end
  -- glacial_advance,if=spell_targets.glacial_advance>=2
  if S.GlacialAdvance:IsReady() and EnemiesCount10yd >= 2 then
    if Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance obliteration 8"; end
  end
  -- frost_strike,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice,if=!talent.avalanche&!buff.killing_machine.up|talent.avalanche&!buff.rime.up
  if no_heal and S.FrostStrike:IsReady() then
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, EvaluateTargetIfObliterationFrostStrike) then return "frost_strike obliteration 9"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and Player:BuffUp(S.RimeBuff) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast obliteration 10"; end
  end
  -- obliterate,target_if=max:(debuff.razorice.stack+1)%(debuff.razorice.remains+1)*death_knight.runeforge.razorice
  if S.Obliterate:IsCastable() then
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfRazoriceStacks, nil) then return "obliterate obliteration 11"; end
  end
end

local function Standard()
  -- remorseless_winter,if=talent.gathering_storm|conduit.everfrost|runeforge.biting_cold
  if S.RemorselessWinter:IsCastable() and (S.GatheringStorm:IsAvailable() or S.Everfrost:ConduitEnabled() or BitingColdEquipped) then
    if Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter standard 1"; end
  end
  -- glacial_advance,if=!death_knight.runeforge.razorice&(debuff.razorice.stack<5|debuff.razorice.remains<7)
  if S.GlacialAdvance:IsCastable() and (not UsingRazorice and (Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 7)) then
    if Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance standard 2"; end
  end
  -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm
  if no_heal and S.FrostStrike:IsReady() and (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
    if Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 3"; end
  end
  -- frost_strike,if=conduit.eradicating_blow&buff.eradicating_blow.stack=2|conduit.unleashed_frenzy&buff.unleashed_frenzy.remains<3&buff.unleashed_frenzy.up
  if no_heal and S.FrostStrike:IsReady() and (S.EradicatingBlow:ConduitEnabled() and Player:BuffStack(S.EradicatingBlowBuff) == 2 or S.UnleashedFrenzy:ConduitEnabled() and Player:BuffRemains(S.UnleashedFrenzyBuff) < 3 and Player:BuffUp(S.UnleashedFrenzy)) then
    if Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 4"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast standard 5"; end
  end
  -- obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse|buff.killing_machine.react|death_and_decay.ticking&covenant.night_fae&buff.deaths_due.stack>8|rune.time_to_4<=gcd
  if S.Obliterate:IsCastable() and (Player:BuffDown(S.FrozenPulseBuff) and S.FrozenPulse:IsAvailable() or Player:BuffUp(S.KillingMachineBuff) or Player:BuffUp(S.DeathAndDecayBuff) and Player:Covenant() == "Night Fae" and Player:BuffStack(S.DeathsDueBuff) > 8 or Player:RuneTimeToX(4) <= Player:GCD()) then
    if Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate standard 6"; end
  end
  -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation*3)
  if no_heal and S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 7"; end
  end
  -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation*3)
  if S.Obliterate:IsCastable() and (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate standard 8"; end
  end
  -- frost_strike
  if no_heal and S.FrostStrike:IsReady() then
    if Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 9"; end
  end
  -- Horn of Winter
  if S.HornofWinter:IsCastable() then
    if Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornOfWinter) then return "horn_of_winter standard 10"; end
  end
  -- Arcane Torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return "arcane_torrent standard 11"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(8)
  Enemies10yd = Player:GetEnemiesInMeleeRange(10)
  EnemiesCount10yd = #Enemies10yd
  EnemiesMeleeCount = #EnemiesMelee
  ComputeTargetRange()

  -- Check Runeforges
  local UsingRazorice = (MainHandRuneforge == "3370" or OffHandRuneforge == "3370")
  local UsingFallenCrusader = (MainHandRuneforge == "3368" or OffHandRuneforge == "3368")

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady("Melee") and not no_heal then
      if Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- variable,name=specified_trinket,value=(equipped.inscrutable_quantum_device&cooldown.inscrutable_quantum_device.ready)
    -- TODO: Leaving this commented out until other trinket sync/priority variables can be handled
    --VarSpecifiedTrinket = (I.InscrutableQuantumDevice:IsEquippedAndReady())
    -- howling_blast,if=!dot.frost_fever.ticking&(talent.icecap|cooldown.breath_of_sindragosa.remains>15|talent.obliteration&cooldown.pillar_of_frost.remains&!buff.killing_machine.up)
    if S.HowlingBlast:IsCastable() and (Target:DebuffDown(S.FrostFeverDebuff) and (not S.Icecap:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 15 or S.Obliteration:IsAvailable() and not S.PillarofFrost:CooldownUp() and Player:BuffDown(S.KillingMachineBuff))) then
      if Cast(S.HowlingBlast) then return "howling_blast 1"; end
    end
    -- glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa|cooldown.breath_of_sindragosa.remains>15)
    if no_heal and S.GlacialAdvance:IsReady() and (Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffUp(S.IcyTalonsBuff) and EnemiesCount10yd >= 2 and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 15)) then
      if Cast(S.GlacialAdvance, nil, nil, 100) then return "glacial_advance 3"; end
    end
    -- frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa|cooldown.breath_of_sindragosa.remains>15)
    if no_heal and S.FrostStrike:IsReady() and (Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffUp(S.IcyTalonsBuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 15)) then
      if Cast(S.FrostStrike) then return "frost_strike 5"; end
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
    -- call_action_list,name=cold_heart,if=talent.cold_heart&(buff.cold_heart.stack>=10&(debuff.razorice.stack=5|!death_knight.runeforge.razorice)|fight_remains<=gcd)
    if (S.ColdHeart:IsAvailable() and (Player:BuffStack(S.ColdHeartBuff) >= 10 and (Target:DebuffStack(S.RazoriceDebuff) == 5 or not UsingRazorice) or HL.FilteredFightRemains(Enemies10yd, "<=", Player:GCD()))) then
      local ShouldReturn = ColdHeart(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_ticking,if=buff.breath_of_sindragosa.up
    if (Player:BuffUp(S.BreathofSindragosa)) then
      local ShouldReturn = BosTicking(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.remains<10)
    if (not Settings.Frost.DisableBoSPooling and (S.BreathofSindragosa:IsAvailable() and (S.BreathofSindragosa:CooldownRemains() < 10))) then
      local ShouldReturn = BosPooling(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration
    if (Player:BuffUp(S.PillarofFrostBuff) and S.Obliteration:IsAvailable()) then
      local ShouldReturn = Obliteration(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=obliteration_pooling,if=talent.obliteration&cooldown.pillar_of_frost.remains<10
    if (S.Obliteration:IsAvailable() and S.PillarofFrost:CooldownRemains() < 10) then
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
    if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
end

HR.SetAPL(251, APL, Init)

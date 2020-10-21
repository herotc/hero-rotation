-- ----- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroDBC
local DBC        = HeroDBC.DBC
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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Lua
local mathmin    = math.min
local pairs      = pairs;

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker;
local I = Item.Monk.Windwalker;
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.GalecallersBoon:ID(),
  I.LustrousGoldenPlumage:ID(),
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
  I.RemoteGuidanceDevice:ID(),
  I.WrithingSegmentofDrestagath:ID()
}

-- Rotation Var
local IsInMeleeRange
local IsInAoERange
local Enemies5y
local Enemies8y
local EnemiesCount8
local ShouldReturn
local VarXuenOnUse = false
local VarXuenHold = false
local VarSerenityBurst = false
local Interrupts = {
  { S.SpearHandStrike, "Cast Spear Hand Strike (Interrupt)", function () return true end },
}
local VarHoldTod = false
local VarFoPPreChan = 0

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
};

HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence()
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID])
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ConcentratedFlame:RegisterInFlight()

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
end, "PLAYER_REGEN_ENABLED")

-- Melee Is In Range w/ Movement Handlers
local function IsInMeleeRange(range)
  if S.TigerPalm:TimeSinceLastCast() <= Player:GCD() then
    return true
  end
  return range and Target:IsInMeleeRange(range) or Target:IsInMeleeRange(5)
end

local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EnergyTimeToMaxRounded ()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10
end

local function EnergyPredictedRounded ()
  -- Round to the nearesth int to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyPredicted() + 0.5)
end

local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

local function ConflictAndStrifeMajor()
  if Spell:MajorEssenceEnabled(AE.ConflictandStrife) then return 1 else return 0 end
end

local function EvaluateTargetIfFilterMarkoftheCrane100(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfFistoftheWhiteTiger102(TargetUnit)
  return (Player:Chi() < 3)
end

local function EvaluateTargetIfFistoftheWhiteTiger104(TargetUnit)
  return (Player:ChiDeficit() >= 3 and ((EnergyTimeToMaxRounded() < 1 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5))
end

local function EvaluateTargetIfTigerPalm106(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5)
end

local function EvaluateTargetIfRisingSunKick408(TargetUnit)
  return (ComboStrike(S.RisingSunKick))
end

local function EvaluateTargetIfBlackoutKick412(TargetUnit)
  return (ComboStrike(S.BlackoutKick) or not S.HitComboBuff:IsAvailable())
end

local function EvaluateTargetIfRisingSunKick600(TargetUnit)
  return (S.Serenity:IsAvailable() or S.Serenity:CooldownRemains() > 1 or not S.Serenity:IsAvailable())
end

local function EvaluateTargetIfTigerPalm602(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.StormEarthandFireBuff))
end

local function EvaluateTargetIfBlackoutKick604(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and ((S.Serenity:IsAvailable() and S.Serenity:CooldownRemains() < 3) or (S.RisingSunKick:CooldownRemains() > 1 and S.TouchofDeath:CooldownRemains() > 1) or (S.RisingSunKick:CooldownRemains() < 3 and S.TouchofDeath:CooldownRemains() > 3 and Player:Chi() > 2) or (S.RisingSunKick:CooldownRemains() > 3 and S.TouchofDeath:CooldownRemains() < 3 and Player:Chi() > 3) or Player:Chi() > 5 or Player:BuffUp(S.BlackoutKickBuff)))
end

local function EvaluateTargetIfTigerPalm606(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2)
end

local function EvaluateTargetIfBlackoutKick608(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (S.FistsofFury:CooldownRemains() < 3 and Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm) or Player:EnergyTimeToX(50) < 1))
end

local function EvaluateTargetIfBlackoutKick610(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and EnergyTimeToMaxRounded() < 2 and (Player:ChiDeficit() <= 1 or Player:PrevGCD(1, S.TigerPalm)))
end

local function EvaluateTargetIfRisingSunKick424(TargetUnit)
  return ((S.WhirlingDragonPunch:IsAvailable() and 10 * Player:SpellHaste() > S.WhirlingDragonPunch:CooldownRemains() + 4) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() >= 5))
end

local function EvaluateTargetIfFistoftheWhiteTiger426(TargetUnit)
  return (Player:ChiDeficit() >= 3)
end

local function EvaluateTargetIfTigerPalm428(TargetUnit)
  return (Player:ChiDeficit() >= 2 and (not S.HitComboBuff:IsAvailable() or ComboStrike(S.TigerPalm)))
end

local function EvaluateTargetIfBlackoutKick430(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.BlackoutKickBuff) or (S.HitComboBuff:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4)))
end

local function UseItems()
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 2"; end
  end
  -- variable,name=xuen_on_use_trinket,op=set,value=0
  if (true) then
    VarXuenOnUse = false
  end
  -- chi_burst,if=!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled
  if S.ChiBurst:IsReady() and (not S.Serenity:IsAvailable() or not S.FistoftheWhiteTiger:IsAvailable()) then
    if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 4"; end
  end
  -- chi_wave,if=!talent.energizing_elixer.enabled
  if S.ChiWave:IsReady() and not S.EnergizingElixir:IsAvailable() then
    if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 6"; end
  end
end

local function Opener()
end

local function CDSerenity()
  -- invoke_xuen_the_white_tiger,if=buff.serenity.down|fight_remains<25
  if S.InvokeXuentheWhiteTiger:IsReady() and (Player:BuffDown(S.SerenityBuff) or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuentheWhiteTiger, nil, nil, 40) then return "invoke_xuen_the_white_tiger 40"; end
  end
  -- use_item,name=azsharas_font_of_power,if=buff.serenity.down&(cooldown.serenity.remains<20|fight_remains<40)
  if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDown(S.SerenityBuff) and (S.Serenity:CooldownRemains() < 20 or HL.BossFilteredFightRemains("<", 40))) then
    if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 42"; end
  end
  -- guardian_of_azeroth,if=buff.serenity.down&(fight_remains>185|cooldown.serenity.remains<=7)|fight_remains<35
  if S.GuardianofAzeroth:IsCastable() and (Player:BuffDown(S.SerenityBuff) and (HL.FilteredFightRemains(40, ">", 185, true) or S.Serenity:CooldownRemains() <= 7) or HL.BossFilteredFightRemains("<", 35)) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 44"; end
  end
  -- blood_fury,if=cooldown.serenity.remains>20|fight_remains<20
  if S.BloodFury:IsCastable() and (S.Serenity:CooldownRemains() > 20 or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 46"; end
  end
  -- berserking,if=cooldown.serenity.remains>20|fight_remains<15
  if S.Berserking:IsCastable() and (S.Serenity:CooldownRemains() > 20 or HL.BossFilteredFightRemains("<", 15)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 48"; end
  end
  -- arcane_torrent,if=buff.serenity.down&chi.max-chi>=1&energy.time_to_max>=0.5
  if S.ArcaneTorrent:IsCastable() and (Player:BuffDown(S.SerenityBuff) and Player:ChiDeficit() >= 1 and EnergyTimeToMaxRounded() >= 0.5) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 50"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 52"; end
  end
  -- fireblood,if=cooldown.serenity.remains>20|fight_remains<10
  if S.Fireblood:IsCastable() and (S.Serenity:CooldownRemains() > 20 or HL.BossFilteredFightRemains("<", 10)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 54"; end
  end
  -- ancestral_call,if=cooldown.serenity.remains>20|fight_remains<20
  if S.AncestralCall:IsCastable() and (S.Serenity:CooldownRemains() > 20 or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 56"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 58"; end
  end
  -- use_item,name=lustrous_golden_plumage,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|variable.hold_tod|fight_remains<=20
  if I.LustrousGoldenPlumage:IsEquipReady() and Settings.Commons.UseTrinkets and (S.TouchofDeath:CooldownRemains() < 1 or S.TouchofDeath:CooldownRemains() > 20 or VarHoldTod or HL.BossFilteredFightRemains("<=", 20)) then
    if HR.Cast(I.LustrousGoldenPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "lustrous_golden_plumage 60"; end
  end
  -- use_item,effect_name=gladiators_medallion,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|variable.hold_tod|fight_remains<=20
  -- 61
  -- use_item,effect_name=gladiators_emblem,if=fight_remains>159|cooldown.touch_of_death.remains<1|variable.hold_tod
  -- 62
  -- touch_of_death,if=!variable.hold_tod
  if S.TouchofDeath:IsReady() and (not VarHoldTod) then
    if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, "Melee") then return "touch_of_death 63"; end
  end
  -- touch_of_karma,if=fight_remains>159|dot.touch_of_death.remains|variable.hold_tod
  if S.TouchofKarma:IsReady() and not Settings.Windwalker.IgnoreToK and (HL.FilteredFightRemains(20, ">", 159, true) or Target:DebuffP(S.TouchofDeathDebuff) or VarHoldTod) then
    if HR.Cast(S.TouchofKarma, nil, nil, 20) then return "touch_of_karma 64"; end
  end
  -- use_item,name=pocketsized_computation_device,if=buff.serenity.down&(cooldown.touch_of_death.remains>10|variable.hold_tod)|fight_remains<5
  if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDown(S.SerenityBuff) and (S.TouchofDeath:CooldownRemains() > 10 or VarHoldTod) or HL.BossFilteredFightRemains("<", 5)) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device 65"; end
  end
  -- blood_of_the_enemy,if=buff.serenity.down&(cooldown.serenity.remains>20|cooldown.serenity.remains<2)|fight_remains<15
  if S.BloodoftheEnemy:IsCastable() and (Player:BuffDown(S.SerenityBuff) and (S.Serenity:CooldownRemains() > 20 or S.Serenity:CooldownRemains() < 2) or HL.BossFilteredFightRemains("<", 15)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 66"; end
  end
  if (Settings.Commons.UseTrinkets) then
    -- use_item,name=remote_guidance_device,if=cooldown.touch_of_death.remains>10|variable.hold_tod
    if I.RemoteGuidanceDevice:IsEquipReady() and (S.TouchofDeath:CooldownRemains() > 10 or VarHoldTod) then
      if HR.Cast(I.RemoteGuidanceDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "remote_guidance_device 68"; end
    end
    -- use_item,effect_name=gladiators_badge,if=cooldown.serenity.remains>20|fight_remains<20
    -- 69
    -- use_item,name=galecallers_boon,if=cooldown.serenity.remains>20|fight_remains<20
    if I.GalecallersBoon:IsEquipReady() and (S.Serenity:CooldownRemains() > 20 or HL.BossFilteredFightRemains("<", 20)) then
      if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "galecallers_boon 70"; end
    end
    -- use_item,name=writhing_segment_of_drestagath,if=cooldown.touch_of_death.remains>10|variable.hold_tod
    if I.WrithingSegmentofDrestagath:IsEquipReady() and (S.TouchofDeath:CooldownRemains() > 10 or VarHoldTod) then
      if HR.Cast(I.WrithingSegmentofDrestagath, nil, Settings.Commons.TrinketDisplayStyle, 8) then return "writhing_segment_of_drestagath 72"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|buff.serenity.remains>9|fight_remains<25
    if I.AshvanesRazorCoral:IsEquipReady() and (Target:DebuffDown(S.RazorCoralDebuff) or Player:BuffRemains(S.SerenityBuff) > 9 or HL.BossFilteredFightRemains("<", 25)) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 74"; end
    end
  end
  -- call_action_list,name=use_items
  if (true) then
    local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
  end
  -- worldvein_resonance,if=buff.serenity.down&(cooldown.serenity.remains>15|cooldown.serenity.remains<2)|fight_remains<20
  if S.WorldveinResonance:IsCastable() and (Player:BuffDown(S.SerenityBuff) and (S.Serenity:CooldownRemains() > 15 or S.Serenity:CooldownRemains() < 2) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 76"; end
  end
  -- concentrated_flame,if=buff.serenity.down&(cooldown.serenity.remains|cooldown.concentrated_flame.charges=2)&!dot.concentrated_flame_burn.remains&(cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains|fight_remains<8)
  if S.ConcentratedFlame:IsCastable() and (Player:BuffDown(S.SerenityBuff) and (not S.Serenity:CooldownUp() or S.ConcentratedFlame:Charges() == 2) and Target:DebuffDown(S.ConcentratedFlameBurn) and (not S.RisingSunKick:CooldownUp() and not S.FistsofFury:CooldownUp() or HL.BossFilteredFightRemains("<", 8))) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 78"; end
  end
  -- serenity
  if S.Serenity:IsReady() then
    if HR.Cast(S.Serenity, Settings.Windwalker.GCDasOffGCD.Serenity) then return "serenity 80"; end
  end
  if (Player:BuffDown(S.SerenityBuff)) then
    -- the_unbound_force,if=buff.serenity.down
    if S.TheUnboundForce:IsCastable() then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 82"; end
    end
    -- purifying_blast,if=buff.serenity.down
    if S.PurifyingBlast:IsCastable() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 84"; end
    end
    -- reaping_flames,if=buff.serenity.down&(target.time_to_pct_20>30|target.health.pct<=20)|target.time_to_die<2
    if (Player:BuffDown(S.SerenityBuff) and (Target:TimeToX(20) > 30 or Target:HealthPercentage() <= 20) or Target:TimeToDie() < 2) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    -- focused_azerite_beam,if=buff.serenity.down
    if S.FocusedAzeriteBeam:IsCastable() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 88"; end
    end
    -- memory_of_lucid_dreams,if=buff.serenity.down&energy<40
    if S.MemoryofLucidDreams:IsCastable() and (Player:Energy() < 40) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 90"; end
    end
    -- ripple_in_space,if=buff.serenity.down
    if S.RippleInSpace:IsCastable() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 92"; end
    end
    -- bag_of_tricks,if=buff.serenity.down
    if S.BagofTricks:IsCastable() then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 94"; end
    end
  end
end

local function CDSEF()
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
  if S.InvokeXuentheWhiteTiger:IsReady() and (not VarXuenHold or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuentheWhiteTiger, nil, nil, 40) then return "invoke_xuen_the_white_tiger 300"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 302"; end
  end
  -- touch_of_death,if=buff.storm_earth_and_fire.down
  if S.TouchofDeath:IsReady() and Player:BuffDown(S.StormEarthandFireBuff) then
    if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, "Melee") then return "touch_of_death 304"; end
  end
  -- blood_of_the_enemy,if=cooldown.fists_of_fury.remains<2|fight_remains<12
  if S.BloodoftheEnemy:IsCastable() and (S.TouchofDeath:CooldownRemains() < 2 or HL.BossFilteredFightRemains("<", 12)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 306"; end
  end
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastable() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 308"; end
  end
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastable() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 310"; end
  end
  -- concentrated_flame,if=!dot.concentrated_flame_burn.remains&((!talent.whirling_dragon_punch.enabled|cooldown.whirling_dragon_punch.remains)&cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains&buff.storm_earth_and_fire.down)|fight_remains<8
  if S.ConcentratedFlame:IsCastable() and (Target:DebuffDown(S.ConcentratedFlameBurn) and ((not S.WhirlingDragonPunch:IsAvailable() or not S.WhirlingDragonPunch:CooldownUp()) and not S.RisingSunKick:CooldownUp() and not S.FistsofFury:CooldownUp() and Player:BuffDown(S.StormEarthandFireBuff)) or HL.BossFilteredFightRemains("<", 8)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 312"; end
  end
  -- the_unbound_force
  if S.TheUnboundForce:IsCastable() then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 314"; end
  end
  -- purifying_blast
  if S.PurifyingBlast:IsCastable() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 316"; end
  end
  -- reaping_flames,if=target.time_to_pct_20>30|target.health.pct<=20
  if (Target:TimeToX(20) > 30 or Target:HealthPercentage() <= 20) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- focused_azerite_beam
  if S.FocusedAzeriteBeam:IsCastable() then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 318"; end
  end
  -- memory_of_lucid_dreams,if=energy<40
  if S.MemoryofLucidDreams:IsCastable() and (Player:Energy() < 40) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 320"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 322"; end
  end
  -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|fight_remains<20|buff.seething_rage.up|(cooldown.blood_of_the_enemy.remains+1>cooldown.storm_earth_and_fire.full_recharge_time|!essence.blood_of_the_enemy.major)&cooldown.fists_of_fury.remains<10&chi>=2&cooldown.whirling_dragon_punch.remains<12
  if S.StormEarthandFire:IsReady() and (S.StormEarthandFire:Charges() == 2 or HL.BossFilteredFightRemains("<", 20) or Player:BuffUp(S.SeethingRageBuff) or (((S.BloodoftheEnemy:CooldownRemains() + 1) > S.StormEarthandFire:FullRechargeTime()) or not Spell:MajorEssenceEnabled(AE.BloodoftheEnemy)) and S.FistsofFury:CooldownRemains() < 10 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() < 12) then
    if HR.Cast(S.StormEarthandFire, Settings.Windwalker.GCDasOffGCD.StormEarthandFire) then return "storm_earth_and_fire 324"; end
  end
  if (Settings.Commons.UseTrinkets) then
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- touch_of_karma,interval=90,pct_health=0.5
  if S.TouchofKarma:IsReady() and not Settings.Windwalker.IgnoreToK then
    if HR.Cast(S.TouchofKarma, nil, nil, 20) then return "touch_of_karma 326"; end
  end
  -- blood_fury,if=fight_remains>125|buff.storm_earth_and_fire.up|fight_remains<20
  if S.BloodFury:IsCastable() and (HL.BossFilteredFightRemains(">", 125) or Player:BuffUp(S.StormEarthandFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 328"; end
  end
  -- berserking,if=fight_remains>185|buff.storm_earth_and_fire.up|fight_remains<20
  if S.Berserking:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or Player:BuffUp(S.StormEarthandFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 330"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 332"; end
  end
  -- fireblood,if=fight_remains>125|buff.storm_earth_and_fire.up|fight_remains<20
  if S.Fireblood:IsCastable() and (HL.BossFilteredFightRemains(">", 125) or Player:BuffUp(S.StormEarthandFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 334"; end
  end
  -- ancestral_call,if=fight_remains>185|buff.storm_earth_and_fire.up|fight_remains<20
  if S.AncestralCall:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or Player:BuffUp(S.StormEarthandFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 336"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 338"; end
  end
end

local function Serenity()
  -- variable,name=serenity_burst,op=set,value=cooldown.serenity.remains<1|fight_remains<20
  if (true) then
    VarXuenHold = (HL.BossFilteredFightRemains("<", S.InvokeXuentheWhiteTiger:CooldownRemains()) or HL.BossFilteredFightRemains("<", 120)) and HL.BossFilteredFightRemains(">", S.Serenity:CooldownRemains()) and (S.Serenity:CooldownRemains() > 10)
  end

  -- fists_of_fury,if=buff.serenity.remains<1|active_enemies>1
  if S.FistsofFury:IsReady() and (Player:BuffRemains(S.SerenityBuff) < 1 or EnemiesCount8 > 1) then
    if HR.Cast(S.FistsofFury, nil, nil, 8) then reutrn "fists_of_fury 160"; end
  end
  -- spinning_crane_kick,if=combo_strike&(active_enemies>2|active_enemies>1&!cooldown.rising_sun_kick.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (EnemiesCount8 > 2 or EnemiesCount8 > 1 and not S.RisingSunKick:CooldownUp())) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 162"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
  if S.RisingSunKick:IsReady() then
    if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick408) then return "rising_sun_kick 168"; end
  end
  -- Manual add to avoid main target icon problems
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick)) then
    if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 169"; end
  end
  -- fists_of_fury,interrupt_if=gcd.remains=0
  if S.FistsofFury:IsReady() then
    if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 170"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistoftheWhiteTiger:IsReady() then
    if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger102) then return "fist_of_the_white_tiger 172"; end
  end
  -- Manual add to avoid main target icon problems
  if S.FistoftheWhiteTiger:IsReady() and (Player:Chi() < 3) then
    if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 173"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo.enabled
  if S.BlackoutKick:IsReady() then
    if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick412) then return "blackout_kick 176"; end
  end
  -- Manual add to avoid main target icon problems
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) or not S.HitComboBuff:IsAvailable()) then
    if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 177"; end
  end
  -- spinning_crane_kick
  if S.SpinningCraneKick:IsReady() then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 178"; end
  end
end

local function St()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, 8) then return "whirling_dragon_punch 600"; end
  end
  -- energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3|chi.max-chi>=4&(energy.time_to_max>2|!prev_gcd.1.tiger_palm)
  if S.EnergizingElixir:IsReady() and Player:ChiDeficit() >= 2 and (EnergyTimeToMaxRounded() > 3 or Player:ChiDeficit() >= 4) and (EnergyTimeToMaxRounded() > 2 or not Player:PrevGCD(1, S.TigerPalm)) then
    if HR.Cast(S.EnergizingElixir) then return "energizing_elixir 602"; end
  end
  -- spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|buff.dance_of_chiji_azerite.up)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (Player:BuffUp(S.DanceofChijiBuff) or Player:BuffUp(S.DanceofChijiAzeriteBuff)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 604"; end
  end
  -- fists_of_fury
  if S.FistsofFury:IsReady() then
    if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 606"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>1|!talent.serenity.enabled
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick600) then return "rising_sun_kick 608"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick600(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 610"; end
    end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and EnemiesCount8 > 1) then
    if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 612"; end
  end
  -- expel_harm,if=chi.max-chi>=1+essence.conflict_and_strife.major
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= (1 + ConflictAndStrifeMajor())) then
    if HR.Cast(S.ExpelHarm, nil, nil, "Melee") then return "expel_harm 614"; end
  end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistoftheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger102) then return "fist_of_the_white_tiger 616"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger102(Target) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 618"; end
    end
  end
  -- chi_burst,if=chi.max-chi>=1
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 1) then
    if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 620"; end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 622"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&buff.storm_earth_and_fire.down
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm602) then return "tiger_palm 624"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm602(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 626"; end
    end
  end
  -- spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies&combo_strike&buff.storm_earth_and_fire.down&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>3|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi.max-chi<=1&energy.time_to_max<2)|buff.chi_energy.stack>10&fight_remains<7
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.ChiEnergyBuff) > (30 - (5 * EnemiesCount8))) and ComboStrike(S.SpinningCraneKick) and (((S.RisingSunKick:CooldownRemains() > 2 and S.FistsofFury:CooldownRemains() > 2) or (S.RisingSunKick:CooldownRemains() < 3 and S.FistsofFury:CooldownRemains() > 3 and Player:Chi() > 3) or (S.RisingSunKick:CooldownRemains() > 3 and S.FistsofFury:CooldownRemains() < 3 and Player:Chi() > 4) or (Player:ChiDeficit() <= 1 and EnergyTimeToMaxRounded() < 2)) or (Player:BuffStack(S.ChiEnergyBuff) > 10 and HL.BossFilteredFightRemains("<", 7))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 628"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(talent.serenity.enabled&cooldown.serenity.remains<3|cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>1|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>3|chi>5|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick604) then return "blackout_kick 630"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick604(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 632"; end
    end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm606) then return "tiger_palm 634"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm606(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 636"; end
    end
  end
  -- flying_serpent_kick,interrupt=1
  if S.FlyingSerpentKickActionBarReplacement:IsReady() then
    if HR.Cast(S.FlyingSerpentKickActionBarReplacement, nil, nil, 40) then return "chi_wave 638"; end
  end
  if S.FlyingSerpentKick:IsReady() then
    if HR.Cast(S.FlyingSerpentKick, nil, nil, 40) then return "chi_wave 640"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains<3&chi=2&prev_gcd.1.tiger_palm&energy.time_to_50<1
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick608) then return "blackout_kick 642"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick608(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 644"; end
    end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<2&(chi.max-chi<=1|prev_gcd.1.tiger_palm)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick610) then return "blackout_kick 646"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick610(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 648"; end
    end
  end
end

local function Aoe()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, 8) then return "whirling_dragon_punch 232"; end
  end
  -- energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&energy<50
  if S.EnergizingElixir:IsReady() and (not Player:PrevGCD(1, S.TigerPalm) and Player:Chi() <= 1 and Player:Energy() < 50) then
    if HR.Cast(S.EnergizingElixir) then return "energizing_elixir 234"; end
  end
  -- fists_of_fury,if=energy.time_to_max>1
  if S.FistsofFury:IsReady() and (EnergyTimeToMaxRounded() > 1) then
    if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 236"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch.enabled&cooldown.rising_sun_kick.duration>cooldown.whirling_dragon_punch.remains+4)&(cooldown.fists_of_fury.remains>3|chi>=5)
  if S.RisingSunKick:IsReady() then
    if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick424) then return "rising_sun_kick 230"; end
  end
  -- Manual add to avoid main target icon problems
  if S.RisingSunKick:IsReady() and ((S.WhirlingDragonPunch:IsAvailable() and 10 * Player:SpellHaste() > S.WhirlingDragonPunch:CooldownRemains() + 4) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() >= 5)) then
    if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 254"; end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 238"; end
  end
  -- spinning_crane_kick,if=combo_strike&(((chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2))|energy.time_to_max<=3|buff.dance_of_chiji.react)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (((Player:Chi() > 3 or S.FistsofFury:CooldownRemains() > 6) and (Player:Chi() >= 5 or S.FistsofFury:CooldownRemains() > 2)) or EnergyTimeToMaxRounded() <= 3 or Player:BuffUp(S.DanceofChijiAzeriteBuff))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 240"; end
  end
  -- chi_burst,if=chi.max-chi>=1
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 1) then
    if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 244"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistoftheWhiteTiger:IsReady() then
    if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger426) then return "fist_of_the_white_tiger 246"; end
  end
  -- Manual add to avoid main target icon problems
  if S.FistoftheWhiteTiger:IsReady() and (Player:ChiDeficit() >= 3) then
    if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 256"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=2&(!talent.hit_combo.enabled|!combo_break)
  if S.TigerPalm:IsReady() then
    if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm428) then return "tiger_palm 248"; end
  end
  -- Manual add to avoid main target icon problems
  if S.TigerPalm:IsReady() and (Player:ChiDeficit() >= 2 and (not S.HitComboBuff:IsAvailable() or ComboStrike(S.TigerPalm))) then
    if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 258"; end
  end
  -- chi_wave,if=!combo_break
  if S.ChiWave:IsReady() and (ComboStrike(S.ChiWave)) then
    if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 250"; end
  end
  -- flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|(talent.hit_combo.enabled&prev_gcd.1.tiger_palm&chi<4))
  if S.BlackoutKick:IsReady() then
    if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick430) then return "blackout_kick 252"; end
  end
  -- Manual add to avoid main target icon problems
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.BlackoutKickBuff) or (S.HitComboBuff:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4))) then
    if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 260"; end
  end
end

-- Action Lists --
--- ======= MAIN =======ss
-- APL Main
local function APL()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = Target:GetEnemiesInSplashRangeCount(8) -- AOE Toogle
  
  ComputeTargetRange()

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
  
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Interrupts); if ShouldReturn then return ShouldReturn; end
    -- variable,name=hold_xuen,op=set,value=cooldown.invoke_xuen_the_white_tiger.remains>fight_remains|fight_remains<120&fight_remains>cooldown.serenity.remains&cooldown.serenity.remains>10
    if (true) then
      VarXuenHold = (HL.BossFilteredFightRemains("<", S.InvokeXuentheWhiteTiger:CooldownRemains()) or HL.BossFilteredFightRemains("<", 120)) and HL.BossFilteredFightRemains(">", S.Serenity:CooldownRemains()) and (S.Serenity:CooldownRemains() > 10)
    end
    -- potion,if=(buff.serenity.up|buff.storm_earth_and_fire.up)&pet.xuen_the_white_tiger.active|fight_remains<=60
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthandFireBuff)) and (S.InvokeXuentheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60)) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 100"; end
    end
    -- call_action_list,name=serenity,if=buff.serenity.up
    if Player:BuffUp(S.SerenityBuff) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=opener,if=time<5&chi<5&!pet.xuen_the_white_tiger.active
    if HL.CombatTime() < 5 and Player:Chi() < 5 and (not (S.InvokeXuentheWhiteTiger:TimeSinceLastCast() <= 24)) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3&(energy.time_to_max<1|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.FistoftheWhiteTiger:IsReady() then
      if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger104) then return "fist_of_the_white_tiger 102"; end
      if (EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger104(Target)) then
        if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 104"; end
      end
    end
    -- expel_harm,if=chi.max-chi>=1+essence.conflict_and_strife.major&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.ExpelHarm:IsReady() and ((Player:ChiDeficit() >= (1 + ConflictAndStrifeMajor())) and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5) then
      if HR.Cast(S.ExpelHarm, nil, nil, "Melee") then return "expel_harm 106"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.TigerPalm:IsReady() then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm106) then return "tiger_palm 108"; end
      if (EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm106(Target)) then
        if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 110"; end
      end
    end
    -- ccall_action_list,name=cd_sef,if=!talent.serenity.enabled
    if (HR.CDsON() and not S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_serenity,if=talent.serenity.enabled
    if (HR.CDsON() and S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemiesCount8 < 3) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if (EnemiesCount8 >= 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added Pool filler
    if HR.Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
--  HL.RegisterNucleusAbility(113656, 8, 6)               -- Fists of Fury
--  HL.RegisterNucleusAbility(101546, 8, 6)               -- Spinning Crane Kick
--  HL.RegisterNucleusAbility(261715, 8, 6)               -- Rushing Jade Wind
--  HL.RegisterNucleusAbility(152175, 8, 6)               -- Whirling Dragon Punch
end

HR.SetAPL(269, APL, Init);

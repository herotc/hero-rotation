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

local function EvaluateTargetIfFilterMarkoftheCrane400(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfFistoftheWhiteTiger402(TargetUnit)
  return (Player:ChiDeficit() >= 3 and ((EnergyTimeToMaxRounded() < 1 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5))
end

local function EvaluateTargetIfExpelHarm404(TargetUnit)
  return ((Player:ChiDeficit() >= (1 + ConflictAndStrifeMajor())) and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5)
end

local function EvaluateTargetIfTigerPalm406(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5)
end

local function EvaluateTargetIfRisingSunKick408(TargetUnit)
  return (ComboStrike(S.RisingSunKick))
end

local function EvaluateTargetIfFistoftheWhiteTiger410(TargetUnit)
  return (Player:Chi() < 3)
end

local function EvaluateTargetIfBlackoutKick412(TargetUnit)
  return (ComboStrike(S.BlackoutKick) or not S.HitComboBuff:IsAvailable())
end

local function EvaluateTargetIfRisingSunKick414(TargetUnit)
  return (S.Serenity:IsAvailable() or S.TouchofDeath:CooldownRemains() > 2 or VarHoldTod)
end

local function EvaluateTargetIfTigerPalm416(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 3 and Target:DebuffDown(S.TouchofDeathDebuff) and Player:BuffDown(S.StormEarthandFireBuff))
end

local function EvaluateTargetIfBlackoutKick416(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and ((S.Serenity:IsAvailable() or S.TouchofDeath:CooldownRemains() > 2 or VarHoldTod) and (S.RisingSunKick:CooldownRemains() > 2 and S.FistsofFury:CooldownRemains() > 2 or S.RisingSunKick:CooldownRemains() < 3 and S.FistsofFury:CooldownRemains() > 3 and Player:Chi() > 2 or S.RisingSunKick:CooldownRemains() > 3 and S.FistsofFury:CooldownRemains() < 3 and Player:Chi() > 4 or Player:Chi() > 5) or Player:BuffUp(S.BlackoutKickBuff)))
end

local function EvaluateTargetIfTigerPalm418(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 1)
end

local function EvaluateTargetIfBlackoutKick420(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (S.FistsofFury:CooldownRemains() < 3 and Player:Chi() == 2 or EnergyTimeToMaxRounded() < 1) and (Player:PrevGCD(1, S.TigerPalm) or Player:ChiDeficit() < 2))
end

local function EvaluateTargetIfRisingSunKick424(TargetUnit)
  return ((S.WhirlingDragonPunch:IsAvailable() and 10 * Player:SpellHaste() > S.WhirlingDragonPunch:CooldownRemains() + 4) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() >= 5))
end

local function EvaluateTargetIfFistoftheWhiteTiger428(TargetUnit)
  return (Player:ChiDeficit() >= 3)
end

local function EvaluateTargetIfTigerPalm430(TargetUnit)
  return (Player:ChiDeficit() >= 2 and (not S.HitComboBuff:IsAvailable() or ComboStrike(S.TigerPalm)))
end

local function EvaluateTargetIfBlackoutKick432(TargetUnit)
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
    if I.AshvanesRazorCoral:IsEquipReady() and (Target:DebuffDown(S.RazorCoralDebuff) or Player:BuffRemainsP(S.SerenityBuff) > 9 or HL.BossFilteredFightRemains("<", 25)) then
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
  if S.ConcentratedFlame:IsCastable() and (Player:BuffDown(S.SerenityBuff) and (not S.Serenity:CooldownUpP() or S.ConcentratedFlame:Charges() == 2) and Target:DebuffDown(S.ConcentratedFlameBurn) and (not S.RisingSunKick:CooldownUpP() and not S.FistsofFury:CooldownUpP() or HL.BossFilteredFightRemains("<", 8))) then
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
  -- invoke_xuen_the_white_tiger,if=buff.serenity.down|fight_remains<25
  if S.InvokeXuentheWhiteTiger:IsReady() and (Player:BuffDown(S.SerenityBuff) or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuentheWhiteTiger, nil, nil, 40) then return "invoke_xuen_the_white_tiger 100"; end
  end
  -- guardian_of_azeroth,if=fight_remains>185|!variable.hold_tod&cooldown.touch_of_death.remains<=14|fight_remains<36
  if S.GuardianofAzeroth:IsCastable() and (HL.FilteredFightRemains(40, ">", 185, true) or not VarHoldTod and S.TouchofDeath:CooldownRemains() <= 14 or HL.BossFilteredFightRemains("<", 36)) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 104"; end
  end
  -- worldvein_resonance,if=cooldown.touch_of_death.remains>58|cooldown.touch_of_death.remains<2|variable.hold_tod|fight_remains<20
  if S.WorldveinResonance:IsCastable() and (S.TouchofDeath:CooldownRemains() > 58 or S.TouchofDeath:CooldownRemains() < 2 or VarHoldTod or HL.BossFilteredFightRemains("<", 35)) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 106"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
  if S.ArcaneTorrent:IsCastable() and (Player:ChiDeficit() >= 1 and EnergyTimeToMaxRounded() >= 0.5) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 108"; end
  end
  -- use_item,name=lustrous_golden_plumage,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|variable.hold_tod|fight_remains<=20
  if I.LustrousGoldenPlumage:IsEquipReady() and Settings.Commons.UseTrinkets and (S.TouchofDeath:CooldownRemains() < 1 or S.TouchofDeath:CooldownRemains() > 20 or VarHoldTod or HL.BossFilteredFightRemains("<=", 20)) then
    if HR.Cast(I.LustrousGoldenPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "lustrous_golden_plumage 110"; end
  end
  -- use_item,effect_name=gladiators_medallion,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|variable.hold_tod|fight_remains<=20
  -- 112
  -- use_item,effect_name=gladiators_emblem,if=fight_remains>159|cooldown.touch_of_death.remains<1|variable.hold_tod
  -- 113
  -- touch_of_death,if=!variable.hold_tod&(!equipped.cyclotronic_blast|cooldown.cyclotronic_blast.remains<=1)&(chi>1|energy<40)
  if S.TouchofDeath:IsReady() and (not VarHoldTod and (not Everyone.PSCDEquipped() or Everyone.PSCDEquipReady()) and (Player:Chi() > 1 or Player:Energy() < 40)) then
    if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, "Melee") then return "touch_of_death 114"; end
  end
  -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|dot.touch_of_death.remains|fight_remains<20|(buff.worldvein_resonance.remains>10|cooldown.worldvein_resonance.remains>cooldown.storm_earth_and_fire.full_recharge_time|!essence.worldvein_resonance.major)&(cooldown.touch_of_death.remains>cooldown.storm_earth_and_fire.full_recharge_time|variable.hold_tod&!equipped.dribbling_inkpod)&cooldown.fists_of_fury.remains<=9&chi>=3&cooldown.whirling_dragon_punch.remains<=13
  if S.StormEarthandFire:IsReady() and (S.StormEarthandFire:Charges() == 2 or Target:DebuffP(S.TouchofDeathDebuff) or HL.BossFilteredFightRemains("<", 20) or (Player:BuffRemainsP(S.LifebloodBuff) > 10 or S.WorldveinResonance:CooldownRemains() > S.StormEarthandFire:FullRechargeTime() or not Spell:MajorEssenceEnabled(AE.WorldveinResonance)) and (S.TouchofDeath:CooldownRemains() > S.StormEarthandFire:FullRechargeTime() or VarHoldTod and not I.DribblingInkpod:IsEquipped()) and S.FistsofFury:CooldownRemains() <= 9 and Player:Chi() >= 3 and S.WhirlingDragonPunch:CooldownRemains() <= 13) then
    if HR.Cast(S.StormEarthandFire, Settings.Windwalker.GCDasOffGCD.StormEarthandFire) then return "storm_earth_and_fire 116"; end
  end
  -- touch_of_karma,if=fight_remains>159|dot.touch_of_death.remains|variable.hold_tod
  if S.TouchofKarma:IsReady() and not Settings.Windwalker.IgnoreToK and (HL.FilteredFightRemains(20, ">", 159, true) or Target:DebuffP(S.TouchofDeathDebuff) or VarHoldTod) then
    if HR.Cast(S.TouchofKarma, nil, nil, 20) then return "touch_of_karma 117"; end
  end
  -- blood_of_the_enemy,if=cooldown.touch_of_death.remains>45|variable.hold_tod&cooldown.fists_of_fury.remains<2|fight_remains<12|fight_remains>100&fight_remains<110&(cooldown.fists_of_fury.remains<3|cooldown.whirling_dragon_punch.remains<5|cooldown.rising_sun_kick.remains<5)
  if S.BloodoftheEnemy:IsCastable() and (S.TouchofDeath:CooldownRemains() > 45 or VarHoldTod and S.FistsofFury:CooldownRemains() < 2 or HL.BossFilteredFightRemains("<", 12) or HL.FilteredFightRemains(12, ">", 100, true) and HL.FilteredFightRemains(12, "<", 110) and (S.FistsofFury:CooldownRemains() < 3 or S.WhirlingDragonPunch:CooldownRemains() < 5 or S.RisingSunKick:CooldownRemains() < 5)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 118"; end
  end
  -- concentrated_flame,if=!dot.concentrated_flame_burn.remains&((cooldown.concentrated_flame.remains<=cooldown.touch_of_death.remains+1|variable.hold_tod)&(!talent.whirling_dragon_punch.enabled|cooldown.whirling_dragon_punch.remains)&cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains&buff.storm_earth_and_fire.down|dot.touch_of_death.remains)|fight_remains<8
  if S.ConcentratedFlame:IsCastable() and (Target:DebuffDown(S.ConcentratedFlameBurn) and ((S.ConcentratedFlame:CooldownRemains() <= S.TouchofDeath:CooldownRemains() + 1 or VarHoldTod) and (not S.WhirlingDragonPunch:IsAvailable() or not S.WhirlingDragonPunch:CooldownUpP()) and not S.RisingSunKick:CooldownUpP() and not S.FistsofFury:CooldownUpP() and Player:BuffDown(S.StormEarthandFireBuff) or Target:DebuffP(S.TouchofDeathDebuff)) or HL.BossFilteredFightRemains("<", 8)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 120"; end
  end
  -- blood_fury,if=cooldown.touch_of_death.remains>30|variable.hold_tod|fight_remains<20
  if S.BloodFury:IsCastable() and (S.TouchofDeath:CooldownRemains() > 30 or VarHoldTod or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 122"; end
  end
  -- berserking,if=cooldown.touch_of_death.remains>30|variable.hold_tod|fight_remains<15
  if S.Berserking:IsCastable() and (S.TouchofDeath:CooldownRemains() > 30 or VarHoldTod or HL.BossFilteredFightRemains("<", 15)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 124"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 125"; end
  end
  -- fireblood,if=cooldown.touch_of_death.remains>30|variable.hold_tod|fight_remains<10
  if S.Fireblood:IsCastable() and (S.TouchofDeath:CooldownRemains() > 30 or VarHoldTod or HL.BossFilteredFightRemains("<", 10)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 126"; end
  end
  -- ancestral_call,if=cooldown.touch_of_death.remains>30|variable.hold_tod|fight_remains<20
  if S.AncestralCall:IsCastable() and (S.TouchofDeath:CooldownRemains() > 30 or VarHoldTod or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 128"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 129"; end
  end
  if (Settings.Commons.UseTrinkets) then
    -- use_item,name=pocketsized_computation_device,if=cooldown.touch_of_death.remains>30|variable.hold_tod
    if Everyone.PSCDEquipReady() and (S.TouchofDeath:CooldownRemains() > 30 or VarHoldTod) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device 130"; end
    end
    -- use_item,name=remote_guidance_device,if=cooldown.touch_of_death.remains>30|variable.hold_tod
    if I.RemoteGuidanceDevice:IsEquipReady() and (S.TouchofDeath:CooldownRemains() > 30 or VarHoldTod) then
      if HR.Cast(I.RemoteGuidanceDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "remote_guidance_device 132"; end
    end
    -- use_item,effect_name=gladiators_badge,if=cooldown.touch_of_death.remains>20|variable.hold_tod|fight_remains<20
    -- 134
    -- use_item,effect_name=galecallers_boon,if=cooldown.touch_of_death.remains>55|variable.hold_tod|fight_remains<12
    if I.GalecallersBoon:IsEquipReady() and (S.TouchofDeath:CooldownRemains() > 55 or VarHoldTod or HL.BossFilteredFightRemains("<", 12)) then
      if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "galecallers_boon 136"; end
    end
    -- use_item,name=writhing_segment_of_drestagath,if=cooldown.touch_of_death.remains>20|variable.hold_tod
    if I.WrithingSegmentofDrestagath:IsEquipReady() and (S.TouchofDeath:CooldownRemains() > 20 or VarHoldTod) then
      if HR.Cast(I.WrithingSegmentofDrestagath, nil, Settings.Commons.TrinketDisplayStyle, 8) then return "writhing_segment_of_drestagath 138"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=variable.tod_on_use_trinket&(cooldown.touch_of_death.remains>21|variable.hold_tod)&(debuff.razor_coral_debuff.down|buff.storm_earth_and_fire.remains>13|fight_remains-cooldown.touch_of_death.remains<40&cooldown.touch_of_death.remains<25|fight_remains<25)
    if I.AshvanesRazorCoral:IsEquipReady() then
      local BossFightRemains = HL.BossFightRemains()
      if (VarXuenOnUse and (S.TouchofDeath:CooldownRemains() > 21 or VarHoldTod) and (Target:DebuffDown(S.RazorCoralDebuff) or Player:BuffRemainsP(S.StormEarthandFireBuff) > 13 or BossFightRemains - S.TouchofDeath:CooldownRemains() < 40 and S.TouchofDeath:CooldownRemains() < 25 or HL.BossFilteredFightRemains("<", 25))) then
        if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 140"; end
      end
    end
    -- use_item,name=ashvanes_razor_coral,if=!variable.tod_on_use_trinket&(debuff.razor_coral_debuff.down|(!equipped.dribbling_inkpod|target.time_to_pct_30.remains<8)&(dot.touch_of_death.remains|cooldown.touch_of_death.remains+9>fight_remains)&buff.storm_earth_and_fire.up|fight_remains<25)
    if I.AshvanesRazorCoral:IsEquipReady() and (not VarXuenOnUse and (Target:DebuffDown(S.RazorCoralDebuff) or (not I.DribblingInkpod:IsEquipped() or Target:TimeToX(30) < 8) and (Target:DebuffP(S.TouchofDeathDebuff) or HL.FilteredFightRemains(40, ">", S.TouchofDeath:CooldownRemains() + 9, true)) and Player:BuffUp(S.StormEarthandFireBuff) or HL.BossFilteredFightRemains("<", 25))) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 142"; end
    end
    -- call_action_list,name=use_items
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- the_unbound_force
  if S.TheUnboundForce:IsCastable() then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 144"; end
  end
  -- purifying_blast
  if S.PurifyingBlast:IsCastable() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 146"; end
  end
  -- reaping_flames,if=target.time_to_pct_20>30|target.health.pct<=20
  if (Target:TimeToX(20) > 30 or Target:HealthPercentage() <= 20) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- focused_azerite_beam
  if S.FocusedAzeriteBeam:IsCastable() then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 150"; end
  end
  -- memory_of_lucid_dreams,if=energy<40
  if S.MemoryofLucidDreams:IsCastable() and (Player:Energy() < 40) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 152"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 154"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 129"; end
  end
end

local function Serenity()
  -- fists_of_fury,if=buff.serenity.remains<1|active_enemies>1
  if S.FistsofFury:IsReady() and (Player:BuffRemainsP(S.SerenityBuff) < 1 or Cache.EnemiesCount[8] > 1) then
    if HR.Cast(S.FistsofFury, nil, nil, 8) then reutrn "fists_of_fury 160"; end
  end
  -- spinning_crane_kick,if=combo_strike&(active_enemies>2|active_enemies>1&!cooldown.rising_sun_kick.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (Cache.EnemiesCount[8] > 2 or Cache.EnemiesCount[8] > 1 and not S.RisingSunKick:CooldownUpP())) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 162"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
  if S.RisingSunKick:IsReady() then
    if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfRisingSunKick408) then return "rising_sun_kick 168"; end
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
    if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger410) then return "fist_of_the_white_tiger 172"; end
  end
  -- Manual add to avoid main target icon problems
  if S.FistoftheWhiteTiger:IsReady() and (Player:Chi() < 3) then
    if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 173"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo.enabled
  if S.BlackoutKick:IsReady() then
    if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick412) then return "blackout_kick 176"; end
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
  if S.WhirlingDragonPunch:IsReady() then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, 8) then return "whirling_dragon_punch 190"; end
  end
  -- fists_of_fury,if=talent.serenity.enabled|cooldown.touch_of_death.remains>6|variable.hold_tod
  if S.FistsofFury:IsReady() and (S.Serenity:IsAvailable() or S.TouchofDeath:CooldownRemains() > 6 or VarHoldTod) then
    if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 192"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=talent.serenity.enabled|cooldown.touch_of_death.remains>2|variable.hold_tod
  if S.RisingSunKick:IsReady() then
    if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfRisingSunKick414) then return "rising_sun_kick 194"; end
  end
  -- Manual add to avoid main target icon problems
  if S.RisingSunKick:IsReady() and (S.Serenity:IsAvailable() or S.TouchofDeath:CooldownRemains() > 2 or VarHoldTod) then
    if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 218"; end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and Cache.EnemiesCount[8] > 1) then
    if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 196"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistoftheWhiteTiger:IsReady() then
    if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger410) then return "fist_of_the_white_tiger 200"; end
  end
  -- Manual add to avoid main target icon problems
  if S.FistoftheWhiteTiger:IsReady() and (Player:Chi() < 3) then
    if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 220"; end
  end
  -- energizing_elixir,if=chi<=3&energy<50
  if S.EnergizingElixir:IsReady() and (Player:Chi() <= 3 and Player:Energy() < 50) then
    if HR.Cast(S.EnergizingElixir) then return "energizing_elixir 202"; end
  end
  -- chi_burst,if=chi.max-chi>0&active_enemies=1|chi.max-chi>1
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() > 0 and Cache.EnemiesCount[8] == 1 or Player:ChiDeficit() > 1) then
    if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 204"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>3&!dot.touch_of_death.remains&buff.storm_earth_and_fire.down
  if S.TigerPalm:IsReady() then
    if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm416) then return "tiger_palm 206"; end
  end
  -- Manual add to avoid main target icon problems
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 3 and Target:DebuffDown(S.TouchofDeathDebuff) and Player:BuffDown(S.StormEarthandFireBuff)) then
    if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 222"; end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 208"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.react
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiAzeriteBuff)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 210"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&((talent.serenity.enabled|cooldown.touch_of_death.remains>2|variable.hold_tod)&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi>5)|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() then
    if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick416) then return "blackout_kick 212"; end
  end
  -- Manual add to avoid main target icon problems
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and ((S.Serenity:IsAvailable() or S.TouchofDeath:CooldownRemains() > 2 or VarHoldTod) and (S.RisingSunKick:CooldownRemains() > 2 and S.FistsofFury:CooldownRemains() > 2 or S.RisingSunKick:CooldownRemains() < 3 and S.FistsofFury:CooldownRemains() > 3 and Player:Chi() > 2 or S.RisingSunKick:CooldownRemains() > 3 and S.FistsofFury:CooldownRemains() < 3 and Player:Chi() > 4 or Player:Chi() > 5) or Player:BuffUp(S.BlackoutKickBuff))) then
    if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 224"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>1
  if S.TigerPalm:IsReady() then
    if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm418) then return "tiger_palm 214"; end
  end
  -- Manual add to avoid main target icon problems
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 1) then
    if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 226"; end
  end
  -- flying_serpent_kick,interrupt=1
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(cooldown.fists_of_fury.remains<3&chi=2|energy.time_to_max<1)&(prev_gcd.1.tiger_palm|chi.max-chi<2)
  if S.BlackoutKick:IsReady() then
    if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick420) then return "blackout_kick 216"; end
  end
  -- Manual add to avoid main target icon problems
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (S.FistsofFury:CooldownRemains() < 3 and Player:Chi() == 2 or EnergyTimeToMaxRounded() < 1) and (Player:PrevGCD(1, S.TigerPalm) or Player:ChiDeficit() < 2)) then
    if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 228"; end
  end
end

local function Aoe()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
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
    if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfRisingSunKick424) then return "rising_sun_kick 230"; end
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
    if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger428) then return "fist_of_the_white_tiger 246"; end
  end
  -- Manual add to avoid main target icon problems
  if S.FistoftheWhiteTiger:IsReady() and (Player:ChiDeficit() >= 3) then
    if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 256"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=2&(!talent.hit_combo.enabled|!combo_break)
  if S.TigerPalm:IsReady() then
    if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm430) then return "tiger_palm 248"; end
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
    if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick432) then return "blackout_kick 252"; end
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
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 20"; end
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
      if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger402) then return "fist_of_the_white_tiger 24"; end
      if (EvaluateTargetIfFilterMarkoftheCrane400(Target) and EvaluateTargetIfFistoftheWhiteTiger402(Target)) then
        if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 25"; end
      end
    end
    -- expel_harm,if=chi.max-chi>=1+essence.conflict_and_strife.major&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.ExpelHarm:IsReady() then
      if Everyone.CastTargetIf(S.ExpelHarm, Enemies8y, "min", EvaluateTargetIfExpelHarm404) then return "expel_harm 26"; end
      if EvaluateTargetIfExpelHarm404(Target) then
        if HR.Cast(S.ExpelHarm, nil, nil, "Melee") then return "expel_harm 27"; end
      end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.TigerPalm:IsReady() then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm406) then return "tiger_palm 28"; end
      if (EvaluateTargetIfFilterMarkoftheCrane400(Target) and EvaluateTargetIfTigerPalm406(Target)) then
        if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 29"; end
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
    if (Cache.EnemiesCount[8] < 3) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if (Cache.EnemiesCount[8] >= 3) then
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

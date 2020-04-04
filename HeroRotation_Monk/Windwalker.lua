-- ----- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
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
-- Lua
local pairs      = pairs;

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;

-- Spells
if not Spell.Monk then Spell.Monk = {}; end
Spell.Monk.Windwalker = {

  -- Racials
  Bloodlust                             = Spell(2825),
  ArcaneTorrent                         = Spell(25046),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  GiftoftheNaaru                        = Spell(59547),
  Shadowmeld                            = Spell(58984),
  QuakingPalm                           = Spell(107079),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  LightsJudgment                        = Spell(255647),
  BagofTricks                           = Spell(312411),

  -- Abilities
  TigerPalm                             = Spell(100780),
  RisingSunKick                         = Spell(107428),
  FistsofFury                           = Spell(113656),
  SpinningCraneKick                     = Spell(101546),
  StormEarthandFire                     = Spell(137639),
  StormEarthandFireBuff                 = Spell(137639),
  FlyingSerpentKick                     = Spell(101545),
  FlyingSerpentKick2                    = Spell(115057),
  TouchofDeath                          = Spell(115080),
  TouchofDeathDebuff                    = Spell(115080),
  CracklingJadeLightning                = Spell(117952),
  BlackoutKick                          = Spell(100784),
  BlackoutKickBuff                      = Spell(116768),
  DanceofChijiBuff                      = Spell(286587),
  
  -- Debuffs
  MarkoftheCraneDebuff                  = Spell(228287),

  -- Talents
  ChiWave                               = Spell(115098),
  ChiBurst                              = Spell(123986),
  FistoftheWhiteTiger                   = Spell(261947),
  HitCombo                              = Spell(196741),
  InvokeXuentheWhiteTiger               = Spell(123904),
  RushingJadeWind                       = Spell(261715),
  RushingJadeWindBuff                   = Spell(261715),
  WhirlingDragonPunch                   = Spell(152175),
  Serenity                              = Spell(152173),
  SerenityBuff                          = Spell(152173),

  -- Defensive
  TouchofKarma                          = Spell(122470),
  DiffuseMagic                          = Spell(122783), --Talent
  DampenHarm                            = Spell(122278), --Talent

  -- Utility
  Detox                                 = Spell(218164),
  Effuse                                = Spell(116694),
  EnergizingElixir                      = Spell(115288), --Talent
  TigersLust                            = Spell(116841), --Talent
  LegSweep                              = Spell(119381), --Talent
  Disable                               = Spell(116095),
  HealingElixir                         = Spell(122281), --Talent
  Paralysis                             = Spell(115078),
  SpearHandStrike                       = Spell(116705),

  -- Azerite Traits
  SwiftRoundhouse                       = Spell(277669),
  SwiftRoundhouseBuff                   = Spell(278710),
  OpenPalmStrikes                       = Spell(279918),
  GloryoftheDawn                        = Spell(288634),
  
  -- Essences
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  ReapingFlames                         = Spell(310690),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  SeethingRageBuff                      = Spell(297126),
  
  -- Trinket Debuffs
  RazorCoralDebuff                      = Spell(303568),
  
  -- PvP Abilities
  ReverseHarm                           = Spell(287771),

  -- Misc
  PoolEnergy                            = Spell(9999000010)
};
local S = Spell.Monk.Windwalker;

-- Items
if not Item.Monk then Item.Monk = {}; end
Item.Monk.Windwalker = {
  PotionofUnbridledFury                = Item(169299),
  GalecallersBoon                      = Item(159614, {13, 14}),
  LustrousGoldenPlumage                = Item(159617, {13, 14}),
  PocketsizedComputationDevice         = Item(167555, {13, 14}),
  AshvanesRazorCoral                   = Item(169311, {13, 14}),
  AzsharasFontofPower                  = Item(169314, {13, 14}),
  RemoteGuidanceDevice                 = Item(169769, {13, 14}),
  WrithingSegmentofDrestagath          = Item(173946, {13, 14}),
  -- For VarTodOnUse
  DribblingInkpod                      = Item(169319, {13, 14}),
  -- Gladiator Badges/Medallions
  DreadGladiatorsMedallion             = Item(161674, {13, 14}),
  DreadCombatantsInsignia              = Item(161676, {13, 14}),
  DreadCombatantsMedallion             = Item(161811, {13, 14}),
  DreadGladiatorsBadge                 = Item(161902, {13, 14}),
  DreadAspirantsMedallion              = Item(162897, {13, 14}),
  DreadAspirantsBadge                  = Item(162966, {13, 14}),
  SinisterGladiatorsMedallion          = Item(165055, {13, 14}),
  SinisterGladiatorsBadge              = Item(165058, {13, 14}),
  SinisterAspirantsMedallion           = Item(165220, {13, 14}),
  SinisterAspirantsBadge               = Item(165223, {13, 14}),
  NotoriousGladiatorsMedallion         = Item(167377, {13, 14}),
  NotoriousGladiatorsBadge             = Item(167380, {13, 14}),
  NotoriousAspirantsMedallion          = Item(167525, {13, 14}),
  NotoriousAspirantsBadge              = Item(167528, {13, 14})
};
local I = Item.Monk.Windwalker;

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
local ShouldReturn;
local VarTodOnUse;
local VarHoldTod;
local VarFoPPreChan = 0;

-- GUI Settings
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
};

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {8, 5}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

local function EvaluateTargetIfFilterMarkoftheCrane400(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfFistoftheWhiteTiger402(TargetUnit)
  return (Player:ChiDeficit() >= 3 and Player:BuffDownP(S.SerenityBuff) and Player:BuffDownP(S.SeethingRageBuff) and (Player:EnergyTimeToMaxPredicted() < 1 or S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2 or not S.Serenity:IsAvailable() and S.TouchofDeath:CooldownRemainsP() < 3 and not VarHoldTod or Player:EnergyTimeToMaxPredicted() < 4 and S.FistsofFury:CooldownRemainsP() < 1.5))
end

local function EvaluateTargetIfTigerPalm404(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (S.Serenity:IsAvailable() or Target:DebuffDownP(S.TouchofDeathDebuff) or Cache.EnemiesCount[8] > 2) and Player:BuffDownP(S.SeethingRageBuff) and Player:BuffDownP(S.SerenityBuff) and (Player:EnergyTimeToMaxPredicted() < 1 or S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2 or not S.Serenity:IsAvailable() and S.TouchofDeath:CooldownRemainsP() < 3 and not VarHoldTod or Player:EnergyTimeToMaxPredicted() < 4 and S.FistsofFury:CooldownRemainsP() < 1.5))
end

local function EvaluateTargetIfRisingSunKick406(TargetUnit)
  return (ComboStrike(S.RisingSunKick))
end

local function EvaluateTargetIfFistoftheWhiteTiger408(TargetUnit)
  return (Player:Chi() < 3)
end

local function EvaluateTargetIfBlackoutKick410(TargetUnit)
  return (ComboStrike(S.BlackoutKick) or not S.HitCombo:IsAvailable())
end

local function EvaluateTargetIfRisingSunKick412(TargetUnit)
  return (S.TouchofDeath:CooldownRemainsP() > 2 or VarHoldTod)
end

local function EvaluateTargetIfTigerPalm414(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 3 and Target:DebuffDownP(S.TouchofDeathDebuff) and Player:BuffDownP(S.StormEarthandFireBuff))
end

local function EvaluateTargetIfBlackoutKick416(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and ((S.TouchofDeath:CooldownRemainsP() > 2 or VarHoldTod) and (S.RisingSunKick:CooldownRemainsP() > 2 and S.FistsofFury:CooldownRemainsP() > 2 or S.RisingSunKick:CooldownRemainsP() < 3 and S.FistsofFury:CooldownRemainsP() > 3 and Player:Chi() > 2 or S.RisingSunKick:CooldownRemainsP() > 3 and S.FistsofFury:CooldownRemainsP() < 3 and Player:Chi() > 4 or Player:Chi() > 5) or Player:BuffP(S.BlackoutKickBuff)))
end

local function EvaluateTargetIfTigerPalm418(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 1)
end

local function EvaluateTargetIfBlackoutKick420(TargetUnit)
  return ((S.FistsofFury:CooldownRemainsP() < 3 and Player:Chi() == 2 or Player:EnergyTimeToMaxPredicted() < 1) and (Player:PrevGCD(1, S.TigerPalm) or Player:ChiDeficit() < 2))
end

local function EvaluateTargetIfRisingSunKick422(TargetUnit)
  return ((S.WhirlingDragonPunch:IsAvailable() and 10 * Player:SpellHaste() > S.WhirlingDragonPunch:CooldownRemainsP() + 4) and (S.FistsofFury:CooldownRemainsP() > 3 or Player:Chi() >= 5))
end

local function EvaluateTargetIfFistoftheWhiteTiger426(TargetUnit)
  return (Player:ChiDeficit() >= 3)
end

local function EvaluateTargetIfTigerPalm428(TargetUnit)
  return (Player:ChiDeficit() >= 2 and (not S.HitCombo:IsAvailable() or ComboStrike(S.TigerPalm)))
end

local function EvaluateTargetIfBlackoutKick430(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (Player:BuffP(S.BlackoutKickBuff) or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4)))
end

-- Action Lists --
--- ======= MAIN =======
-- APL Main
local function APL ()
  local Precombat, CDSerenity, CDSEF, Serenity, St, Aoe, UseItems
  -- Unit Update
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  -- Pre Combat --
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 2"; end
    end
    -- variable,name=tod_on_use_trinket,op=set,value=equipped.cyclotronic_blast|equipped.lustrous_golden_plumage|equipped.gladiators_badge|equipped.gladiators_medallion|equipped.remote_guidance_device
    if (true) then
      VarTodOnUse = bool(Everyone.PSCDEquipped() or I.LustrousGoldenPlumage:IsEquipped() or I.NotoriousAspirantsBadge:IsEquipped() or I.NotoriousGladiatorsBadge:IsEquipped() or I.SinisterGladiatorsBadge:IsEquipped() or I.SinisterAspirantsBadge:IsEquipped() or I.DreadGladiatorsBadge:IsEquipped() or I.DreadAspirantsBadge:IsEquipped() or I.DreadCombatantsInsignia:IsEquipped() or I.NotoriousAspirantsMedallion:IsEquipped() or I.NotoriousGladiatorsMedallion:IsEquipped() or I.SinisterGladiatorsMedallion:IsEquipped() or I.SinisterAspirantsMedallion:IsEquipped() or I.DreadGladiatorsMedallion:IsEquipped() or I.DreadAspirantsMedallion:IsEquipped() or I.DreadCombatantsMedallion:IsEquipped() or I.RemoteGuidanceDevice:IsEquipped())
    end
    -- variable,name=hold_tod,op=set,value=cooldown.touch_of_death.remains+9>target.time_to_die|!talent.serenity.enabled&!variable.tod_on_use_trinket&equipped.dribbling_inkpod&target.time_to_pct_30.remains<130&target.time_to_pct_30.remains>8|target.time_to_die<130&target.time_to_die>cooldown.serenity.remains&cooldown.serenity.remains>2|buff.serenity.up&target.time_to_die>11
    if (true) then
      VarHoldTod = bool(S.TouchofDeath:CooldownRemainsP() + 9 > Target:TimeToDie() or not S.Serenity:IsAvailable() and not VarTodOnUse and I.DribblingInkpod:IsEquipped() and Target:TimeToX(30) < 130 and Target:TimeToX(30) > 8 or Target:TimeToDie() < 130 and Target:TimeToDie() > S.Serenity:CooldownRemainsP() and S.Serenity:CooldownRemainsP() > 2 or Player:BuffP(S.SerenityBuff) and Target:TimeToDie() > 11)
    end
    -- variable,name=font_of_power_precombat_channel,op=set,value=19,if=!talent.serenity.enabled&(variable.tod_on_use_trinket|equipped.ashvanes_razor_coral)
    if (not S.Serenity:IsAvailable() and (VarTodOnUse or I.AshvanesRazorCoral:IsEquipped())) then
      VarFoPPreChan = 19
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 4"; end
    end
    -- chi_burst,if=!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled
    if S.ChiBurst:IsReadyP() and (not S.Serenity:IsAvailable() or not S.FistoftheWhiteTiger:IsAvailable()) then
      if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 6"; end
    end
    -- chi_wave,if=talent.fist_of_the_white_tiger.enabled|essence.conflict_and_strife.major
    if S.ChiWave:IsReadyP() and (S.FistoftheWhiteTiger:IsAvailable() or Spell:MajorEssenceEnabled(AE.ConflictandStrife)) then
      if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 8"; end
    end
    -- invoke_xuen_the_white_tiger
    if S.InvokeXuentheWhiteTiger:IsReadyP() then
      if HR.Cast(S.InvokeXuentheWhiteTiger, nil, nil, 40) then return "invoke_xuen_the_white_tiger 10"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 12"; end
    end
  end
  CDSerenity = function()
    -- invoke_xuen_the_white_tiger,if=buff.serenity.down|target.time_to_die<25
    if S.InvokeXuentheWhiteTiger:IsReadyP() and (Player:BuffDownP(S.SerenityBuff) or Target:TimeToDie() < 25) then
      if HR.Cast(S.InvokeXuentheWhiteTiger, nil, nil, 40) then return "invoke_xuen_the_white_tiger 40"; end
    end
    -- use_item,name=azsharas_font_of_power,if=buff.serenity.down&(cooldown.serenity.remains<20|target.time_to_die<40)
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.SerenityBuff) and (S.Serenity:CooldownRemainsP() < 20 or Target:TimeToDie() < 40)) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 42"; end
    end
    -- guardian_of_azeroth,if=buff.serenity.down&(target.time_to_die>185|cooldown.serenity.remains<=7)|target.time_to_die<35
    if S.GuardianofAzeroth:IsCastableP() and (Player:BuffDownP(S.SerenityBuff) and (Target:TimeToDie() > 185 or S.Serenity:CooldownRemainsP() <= 7) or Target:TimeToDie() < 35) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 44"; end
    end
    -- arcane_torrent,if=buff.serenity.down&chi.max-chi>=1&energy.time_to_max>=0.5
    if S.ArcaneTorrent:IsCastableP() and (Player:BuffDownP(S.SerenityBuff) and Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() >= 0.5) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 46"; end
    end
    -- ancestral_call,if=cooldown.serenity.remains>20|target.time_to_die<20
    if S.AncestralCall:IsCastableP() and (S.Serenity:CooldownRemainsP() > 20 or Target:TimeToDie() < 20) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 48"; end
    end
    -- blood_fury,if=cooldown.serenity.remains>20|target.time_to_die<20
    if S.BloodFury:IsCastableP() and (S.Serenity:CooldownRemainsP() > 20 or Target:TimeToDie() < 20) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 50"; end
    end
    -- fireblood,if=cooldown.serenity.remains>20|target.time_to_die<10
    if S.Fireblood:IsCastableP() and (S.Serenity:CooldownRemainsP() > 20 or Target:TimeToDie() < 20) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 52"; end
    end
    -- berserking,if=cooldown.serenity.remains>20|target.time_to_die<15
    if S.Berserking:IsCastableP() and (S.Serenity:CooldownRemainsP() > 20 or Target:TimeToDie() < 20) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 54"; end
    end
    -- use_item,name=lustrous_golden_plumage,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|!variable.hold_tod|target.time_to_die<25
    if I.LustrousGoldenPlumage:IsEquipReady() and Settings.Commons.UseTrinkets and (S.TouchofDeath:CooldownRemainsP() < 1 or S.TouchofDeath:CooldownRemainsP() > 20 or not VarHoldTod or Target:TimeToDie() < 25) then
      if HR.Cast(I.LustrousGoldenPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "lustrous_golden_plumage 56"; end
    end
    -- use_item,effect_name=gladiators_medallion,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|!variable.hold_tod|target.time_to_die<20
    -- 58
    -- touch_of_death,if=!variable.hold_tod
    if S.TouchofDeath:IsReadyP() and (not VarHoldTod) then
      if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, "Melee") then return "touch_of_death 60"; end
    end
    -- use_item,name=pocketsized_computation_device,if=buff.serenity.down&(cooldown.touch_of_death.remains>10|!variable.hold_tod)|target.time_to_die<5
    if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.SerenityBuff) and (S.TouchofDeath:CooldownRemainsP() > 10 or not VarHoldTod) or Target:TimeToDie() < 5) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device 62"; end
    end
    -- blood_of_the_enemy,if=buff.serenity.down&(cooldown.serenity.remains>20|cooldown.serenity.remains<2)|target.time_to_die<15
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffDownP(S.SerenityBuff) and (S.Serenity:CooldownRemainsP() > 20 or S.Serenity:CooldownRemainsP() < 2) or Target:TimeToDie() < 15) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 64"; end
    end
    if (Settings.Commons.UseTrinkets) then
      -- use_item,name=remote_guidance_device,if=cooldown.touch_of_death.remains>10|!variable.hold_tod
      if I.RemoteGuidanceDevice:IsEquipReady() and (S.TouchofDeath:CooldownRemainsP() > 10 or not VarHoldTod) then
        if HR.Cast(I.RemoteGuidanceDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "remote_guidance_device 66"; end
      end
      -- use_item,effect_name=gladiators_badge,if=cooldown.serenity.remains>20|target.time_to_die<20
      -- 68
      -- use_item,name=galecallers_boon,if=cooldown.serenity.remains>20|target.time_to_die<20
      if I.GalecallersBoon:IsEquipReady() and (S.Serenity:CooldownRemainsP() > 20 or Target:TimeToDie() < 20) then
        if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "galecallers_boon 70"; end
      end
      -- use_item,name=writhing_segment_of_drestagath,if=cooldown.touch_of_death.remains>10|!variable.hold_tod
      if I.WrithingSegmentofDrestagath:IsEquipReady() and (S.TouchofDeath:CooldownRemainsP() > 10 or not VarHoldTod) then
        if HR.Cast(I.WrithingSegmentofDrestagath, nil, Settings.Commons.TrinketDisplayStyle, 8) then return "writhing_segment_of_drestagath 72"; end
      end
      -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|buff.serenity.remains>9|target.time_to_die<25
      if I.AshvanesRazorCoral:IsEquipReady() and (Target:DebuffDownP(S.RazorCoralDebuff) or Player:BuffRemainsP(S.SerenityBuff) > 9 or Target:TimeToDie() < 25) then
        if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 74"; end
      end
    end
    -- call_action_list,name=use_items
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
    -- worldvein_resonance,if=buff.serenity.down&(cooldown.serenity.remains>15|cooldown.serenity.remains<2)|target.time_to_die<20
    if S.WorldveinResonance:IsCastableP() and (Player:BuffDownP(S.SerenityBuff) and (S.Serenity:CooldownRemainsP() > 15 or S.Serenity:CooldownRemainsP() < 2) or Target:TimeToDie() < 20) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 76"; end
    end
    -- concentrated_flame,if=buff.serenity.down&(cooldown.serenity.remains|cooldown.concentrated_flame.charges=2)&!dot.concentrated_flame_burn.remains&(cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains|target.time_to_die<8)
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffDownP(S.SerenityBuff) and (not S.Serenity:CooldownUpP() or S.ConcentratedFlame:Charges() == 2) and Target:DebuffDownP(S.ConcentratedFlameBurn) and (not S.RisingSunKick:CooldownUpP() and not S.FistsofFury:CooldownUpP() or Target:TimeToDie() < 8)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 78"; end
    end
    -- serenity
    if S.Serenity:IsReadyP() then
      if HR.Cast(S.Serenity, Settings.Windwalker.GCDasOffGCD.Serenity) then return "serenity 80"; end
    end
    if (Player:BuffDownP(S.SerenityBuff)) then
      -- the_unbound_force,if=buff.serenity.down
      if S.TheUnboundForce:IsCastableP() then
        if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 82"; end
      end
      -- purifying_blast,if=buff.serenity.down
      if S.PurifyingBlast:IsCastableP() then
        if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 84"; end
      end
      -- reaping_flames,if=buff.serenity.down
      if (Player:BuffDownP(S.SerenityBuff)) then
        local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
      end
      -- focused_azerite_beam,if=buff.serenity.down
      if S.FocusedAzeriteBeam:IsCastableP() then
        if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 88"; end
      end
      -- memory_of_lucid_dreams,if=buff.serenity.down&energy<40
      if S.MemoryofLucidDreams:IsCastableP() and (Player:Energy() < 40) then
        if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 90"; end
      end
      -- ripple_in_space,if=buff.serenity.down
      if S.RippleInSpace:IsCastableP() then
        if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 92"; end
      end
      -- bag_of_tricks,if=buff.serenity.down
      if S.BagofTricks:IsCastableP() then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 94"; end
      end
    end
  end
  CDSEF = function()
    -- invoke_xuen_the_white_tiger
    if S.InvokeXuentheWhiteTiger:IsReadyP() then
      if HR.Cast(S.InvokeXuentheWhiteTiger, nil, nil, 40) then return "invoke_xuen_the_white_tiger 100"; end
    end
    -- use_item,name=azsharas_font_of_power,if=buff.storm_earth_and_fire.down&!dot.touch_of_death.remains&(cooldown.touch_of_death.remains<15|cooldown.touch_of_death.remains<21&(variable.tod_on_use_trinket|equipped.ashvanes_razor_coral)|variable.hold_tod|target.time_to_die<40)
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.StormEarthandFireBuff) and Target:DebuffDownP(S.TouchofDeathDebuff) and (S.TouchofDeath:CooldownRemainsP() < 15 or S.TouchofDeath:CooldownRemainsP() < 21 and (VarTodOnUse or I.AshvanesRazorCoral:IsEquipped()) or VarHoldTod or Target:TimeToDie() < 40)) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 102"; end
    end
    -- guardian_of_azeroth,if=target.time_to_die>185|!variable.hold_tod&cooldown.touch_of_death.remains<=14|target.time_to_die<35
    if S.GuardianofAzeroth:IsCastableP() and (Target:TimeToDie() > 185 or not VarHoldTod and S.TouchofDeath:CooldownRemainsP() <= 14 or Target:TimeToDie() < 35) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 104"; end
    end
    -- worldvein_resonance,if=cooldown.touch_of_death.remains>58|cooldown.touch_of_death.remains<2|variable.hold_tod|target.time_to_die<20
    if S.WorldveinResonance:IsCastableP() and (S.TouchofDeath:CooldownRemainsP() > 58 or S.TouchofDeath:CooldownRemainsP() < 2 or VarHoldTod or Target:TimeToDie() < 20) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 106"; end
    end
    -- arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
    if S.ArcaneTorrent:IsCastableP() and (Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() >= 0.5) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 108"; end
    end
    -- use_item,name=lustrous_golden_plumage,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|!variable.hold_tod|target.time_to_die<25
    if I.LustrousGoldenPlumage:IsEquipReady() and Settings.Commons.UseTrinkets and (S.TouchofDeath:CooldownRemainsP() < 1 or S.TouchofDeath:CooldownRemainsP() > 20 or not VarHoldTod or Target:TimeToDie() < 25) then
      if HR.Cast(I.LustrousGoldenPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "lustrous_golden_plumage 110"; end
    end
    -- use_item,effect_name=gladiators_medallion,if=cooldown.touch_of_death.remains<1|cooldown.touch_of_death.remains>20|!variable.hold_tod|target.time_to_die<20
    -- 112
    -- touch_of_death,if=!variable.hold_tod&(!equipped.cyclotronic_blast|cooldown.cyclotronic_blast.remains<=1)&(chi>1|energy<40)
    if S.TouchofDeath:IsReadyP() and (not VarHoldTod and (not Everyone.PSCDEquipped() or Everyone.PSCDEquipReady()) and (Player:Chi() > 1 or Player:Energy() < 40)) then
      if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, "Melee") then return "touch_of_death 114"; end
    end
    -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|dot.touch_of_death.remains|target.time_to_die<20|(buff.worldvein_resonance.remains>10|cooldown.worldvein_resonance.remains>cooldown.storm_earth_and_fire.full_recharge_time|!essence.worldvein_resonance.major)&(cooldown.touch_of_death.remains>cooldown.storm_earth_and_fire.full_recharge_time|variable.hold_tod&!equipped.dribbling_inkpod)&cooldown.fists_of_fury.remains<=9&chi>=3&cooldown.whirling_dragon_punch.remains<=13
    if S.StormEarthandFire:IsReadyP() and (S.StormEarthandFire:Charges() == 2 or Target:DebuffP(S.TouchofDeathDebuff) or Target:TimeToDie() < 20 or (Player:BuffRemainsP(S.LifebloodBuff) > 10 or S.WorldveinResonance:CooldownRemainsP() > S.StormEarthandFire:FullRechargeTime() or not Spell:MajorEssenceEnabled(AE.WorldveinResonance)) and (S.TouchofDeath:CooldownRemainsP() > S.StormEarthandFire:FullRechargeTime() or VarHoldTod and not I.DribblingInkpod:IsEquipped()) and S.FistsofFury:CooldownRemainsP() <= 9 and Player:Chi() >= 3 and S.WhirlingDragonPunch:CooldownRemainsP() <= 13) then
      if HR.Cast(S.StormEarthandFire, Settings.Windwalker.GCDasOffGCD.StormEarthandFire) then return "storm_earth_and_fire 116"; end
    end
    -- blood_of_the_enemy,if=cooldown.touch_of_death.remains>45|variable.hold_tod&cooldown.fists_of_fury.remains<2|target.time_to_die<12|target.time_to_die>100&target.time_to_die<110&(cooldown.fists_of_fury.remains<3|cooldown.whirling_dragon_punch.remains<5|cooldown.rising_sun_kick.remains<5)
    if S.BloodoftheEnemy:IsCastableP() and (S.TouchofDeath:CooldownRemainsP() > 45 or VarHoldTod and S.FistsofFury:CooldownRemainsP() < 2 or Target:TimeToDie() < 12 or Target:TimeToDie() > 100 and Target:TimeToDie() < 110 and (S.FistsofFury:CooldownRemainsP() < 3 or S.WhirlingDragonPunch:CooldownRemainsP() < 5 or S.RisingSunKick:CooldownRemainsP() < 5)) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 118"; end
    end
    -- concentrated_flame,if=!dot.concentrated_flame_burn.remains&((cooldown.concentrated_flame.remains<=cooldown.touch_of_death.remains+1|variable.hold_tod)&(!talent.whirling_dragon_punch.enabled|cooldown.whirling_dragon_punch.remains)&cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains&buff.storm_earth_and_fire.down|dot.touch_of_death.remains)|target.time_to_die<8
    if S.ConcentratedFlame:IsCastableP() and (Target:DebuffDownP(S.ConcentratedFlameBurn) and ((S.ConcentratedFlame:CooldownRemainsP() <= S.TouchofDeath:CooldownRemainsP() + 1 or VarHoldTod) and (not S.WhirlingDragonPunch:IsAvailable() or not S.WhirlingDragonPunch:CooldownUpP()) and not S.RisingSunKick:CooldownUpP() and not S.FistsofFury:CooldownUpP() and Player:BuffDownP(S.StormEarthandFireBuff) or Target:DebuffP(S.TouchofDeathDebuff)) or Target:TimeToDie() < 8) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 120"; end
    end
    -- blood_fury,if=cooldown.touch_of_death.remains>30|variable.hold_tod|target.time_to_die<20
    if S.BloodFury:IsCastableP() and (S.TouchofDeath:CooldownRemainsP() > 30 or VarHoldTod or Target:TimeToDie() < 20) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 122"; end
    end
    -- ancestral_call,if=cooldown.touch_of_death.remains>30|variable.hold_tod|target.time_to_die<20
    if S.AncestralCall:IsCastableP() and (S.TouchofDeath:CooldownRemainsP() > 30 or VarHoldTod or Target:TimeToDie() < 20) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 124"; end
    end
    -- fireblood,if=cooldown.touch_of_death.remains>30|variable.hold_tod|target.time_to_die<10
    if S.Fireblood:IsCastableP() and (S.TouchofDeath:CooldownRemainsP() > 30 or VarHoldTod or Target:TimeToDie() < 10) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 126"; end
    end
    -- berserking,if=cooldown.touch_of_death.remains>30|variable.hold_tod|target.time_to_die<15
    if S.Berserking:IsCastableP() and (S.TouchofDeath:CooldownRemainsP() > 30 or VarHoldTod or Target:TimeToDie() < 15) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 128"; end
    end
    if (Settings.Commons.UseTrinkets) then
      -- use_item,name=pocketsized_computation_device,if=cooldown.touch_of_death.remains>30|!variable.hold_tod
      if Everyone.PSCDEquipReady() and (S.TouchofDeath:CooldownRemainsP() > 30 or not VarHoldTod) then
        if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device 130"; end
      end
      -- use_item,name=remote_guidance_device,if=cooldown.touch_of_death.remains>30|!variable.hold_tod
      if I.RemoteGuidanceDevice:IsEquipReady() and (S.TouchofDeath:CooldownRemainsP() > 30 or not VarHoldTod) then
        if HR.Cast(I.RemoteGuidanceDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "remote_guidance_device 132"; end
      end
      -- use_item,effect_name=gladiators_badge,if=cooldown.touch_of_death.remains>20|!variable.hold_tod|target.time_to_die<20
      -- 134
      -- use_item,name=galecallers_boon,if=cooldown.touch_of_death.remains>55|variable.hold_tod|target.time_to_die<12
      if I.GalecallersBoon:IsEquipReady() and (S.TouchofDeath:CooldownRemainsP() > 55 or VarHoldTod or Target:TimeToDie() < 12) then
        if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "galecallers_boon 136"; end
      end
      -- use_item,name=writhing_segment_of_drestagath,if=cooldown.touch_of_death.remains>20|!variable.hold_tod
      if I.WrithingSegmentofDrestagath:IsEquipReady() and (S.TouchofDeath:CooldownRemainsP() > 20 or not VarHoldTod) then
        if HR.Cast(I.WrithingSegmentofDrestagath, nil, Settings.Commons.TrinketDisplayStyle, 8) then return "writhing_segment_of_drestagath 138"; end
      end
      -- use_item,name=ashvanes_razor_coral,if=variable.tod_on_use_trinket&(cooldown.touch_of_death.remains>21|variable.hold_tod)&(debuff.razor_coral_debuff.down|buff.storm_earth_and_fire.remains>13|target.time_to_die-cooldown.touch_of_death.remains<40&cooldown.touch_of_death.remains<25|target.time_to_die<25)
      if I.AshvanesRazorCoral:IsEquipReady() and (VarTodOnUse and (S.TouchofDeath:CooldownRemainsP() > 21 or VarHoldTod) and (Target:DebuffDownP(S.RazorCoralDebuff) or Player:BuffRemainsP(S.StormEarthandFireBuff) > 13 or Target:TimeToDie() - S.TouchofDeath:CooldownRemainsP() < 40 and S.TouchofDeath:CooldownRemainsP() < 25 or Target:TimeToDie() < 25)) then
        if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 140"; end
      end
      -- use_item,name=ashvanes_razor_coral,if=!variable.tod_on_use_trinket&(debuff.razor_coral_debuff.down|(!equipped.dribbling_inkpod|target.time_to_pct_30.remains<8)&(dot.touch_of_death.remains|cooldown.touch_of_death.remains+9>target.time_to_die)&buff.storm_earth_and_fire.up|target.time_to_die<25)
      if I.AshvanesRazorCoral:IsEquipReady() and (not VarTodOnUse and (Target:DebuffDownP(S.RazorCoralDebuff) or (not I.DribblingInkpod:IsEquipped() or Target:TimeToX(30) < 8) and (Target:DebuffP(S.TouchofDeathDebuff) or S.TouchofDeath:CooldownRemainsP() + 9 > Target:TimeToDie()) and Player:BuffP(S.StormEarthandFireBuff) or Target:TimeToDie() < 25)) then
        if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 142"; end
      end
      -- call_action_list,name=use_items
      if (true) then
        local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 144"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 146"; end
    end
    -- reaping_flames
    if (true) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 150"; end
    end
    -- memory_of_lucid_dreams,if=energy<40
    if S.MemoryofLucidDreams:IsCastableP() and (Player:Energy() < 40) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 152"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 154"; end
    end
  end
  Serenity = function()
    -- fists_of_fury,if=buff.serenity.remains<1|active_enemies>1
    if S.FistsofFury:IsReadyP() and (Player:BuffRemainsP(S.SerenityBuff) < 1 or Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.FistsofFury, nil, nil, 8) then reutrn "fists_of_fury 160"; end
    end
    -- spinning_crane_kick,if=combo_strike&(active_enemies>2|active_enemies>1&!cooldown.rising_sun_kick.up)
    if S.SpinningCraneKick:IsReadyP() and (ComboStrike(S.SpinningCraneKick) and (Cache.EnemiesCount[8] > 2 or Cache.EnemiesCount[8] > 1 and not S.RisingSunKick:CooldownUpP())) then
      if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 162"; end
    end
    -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
    if S.RisingSunKick:IsReadyP() then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfRisingSunKick406) then return "rising_sun_kick 168"; end
    end
    -- Manual add to avoid main target icon problems
    if S.RisingSunKick:IsReadyP() and (ComboStrike(S.RisingSunKick)) then
      if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 169"; end
    end
    -- fists_of_fury,interrupt_if=gcd.remains=0
    if S.FistsofFury:IsReadyP() then
      if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 170"; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
    if S.FistoftheWhiteTiger:IsReadyP() then
      if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger408) then return "fist_of_the_white_tiger 172"; end
    end
    -- Manual add to avoid main target icon problems
    if S.FistoftheWhiteTiger:IsReadyP() and (Player:Chi() < 3) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 173"; end
    end
    -- reverse_harm,if=chi.max-chi>1&energy.time_to_max<1
    if S.ReverseHarm:IsReadyP() and (Player:ChiDeficit() > 1 and Player:EnergyTimeToMaxPredicted() < 1) then
      if HR.Cast(S.ReverseHarm, nil, nil, 10) then return "reverse_harm 174"; end
    end
    -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo.enabled
    if S.BlackoutKick:IsReadyP() then
      if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick410) then return "blackout_kick 176"; end
    end
    -- Manual add to avoid main target icon problems
    if S.BlackoutKick:IsReadyP() and (ComboStrike(S.BlackoutKick) or not S.HitCombo:IsAvailable()) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 177"; end
    end
    -- spinning_crane_kick
    if S.SpinningCraneKick:IsReadyP() then
      if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 178"; end
    end
  end
  St = function()
    -- whirling_dragon_punch
    if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch, nil, nil, 8) then return "whirling_dragon_punch 190"; end
    end
    -- fists_of_fury,if=talent.serenity.enabled|cooldown.touch_of_death.remains>6|variable.hold_tod
    if S.FistsofFury:IsReadyP() and (S.Serenity:IsAvailable() or S.TouchofDeath:CooldownRemainsP() > 6 or VarHoldTod) then
      if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 192"; end
    end
    -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.touch_of_death.remains>2|variable.hold_tod
    if S.RisingSunKick:IsReadyP() then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfRisingSunKick412) then return "rising_sun_kick 194"; end
    end
    -- Manual add to avoid main target icon problems
    if S.RisingSunKick:IsReadyP() and (S.TouchofDeath:CooldownRemainsP() > 2 or VarHoldTod) then
      if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 218"; end
    end
    -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
    if S.RushingJadeWind:IsReadyP() and (Player:BuffDownP(S.RushingJadeWindBuff) and Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 196"; end
    end
    -- reverse_harm,if=chi.max-chi>1
    if S.ReverseHarm:IsReadyP() and (Player:ChiDeficit() > 1) then
      if HR.Cast(S.ReverseHarm, nil, nil, 10) then return "reverse_harm 198"; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
    if S.FistoftheWhiteTiger:IsReadyP() then
      if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger408) then return "fist_of_the_white_tiger 200"; end
    end
    -- Manual add to avoid main target icon problems
    if S.FistoftheWhiteTiger:IsReadyP() and (Player:Chi() < 3) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 220"; end
    end
    -- energizing_elixir,if=chi<=3&energy<50
    if S.EnergizingElixir:IsReadyP() and (Player:Chi() <= 3 and Player:Energy() < 50) then
      if HR.Cast(S.EnergizingElixir) then return "energizing_elixir 202"; end
    end
    -- chi_burst,if=chi.max-chi>0&active_enemies=1|chi.max-chi>1
    if S.ChiBurst:IsReadyP() and (Player:ChiDeficit() > 0 and Cache.EnemiesCount[8] == 1 or Player:ChiDeficit() > 1) then
      if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 204"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>3&!dot.touch_of_death.remains&buff.storm_earth_and_fire.down
    if S.TigerPalm:IsReadyP() then
      if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm414) then return "tiger_palm 206"; end
    end
    -- Manual add to avoid main target icon problems
    if S.TigerPalm:IsReadyP() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 3 and Target:DebuffDownP(S.TouchofDeathDebuff) and Player:BuffDownP(S.StormEarthandFireBuff)) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 222"; end
    end
    -- chi_wave
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 208"; end
    end
    -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.react
    if S.SpinningCraneKick:IsReadyP() and (ComboStrike(S.SpinningCraneKick) and Player:BuffP(S.DanceofChijiBuff)) then
      if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 210"; end
    end
    -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&((cooldown.touch_of_death.remains>2|variable.hold_tod)&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi>5)|buff.bok_proc.up)
    if S.BlackoutKick:IsReadyP() then
      if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick416) then return "blackout_kick 212"; end
    end
    -- Manual add to avoid main target icon problems
    if S.BlackoutKick:IsReadyP() and (ComboStrike(S.BlackoutKick) and ((S.TouchofDeath:CooldownRemainsP() > 2 or VarHoldTod) and (S.RisingSunKick:CooldownRemainsP() > 2 and S.FistsofFury:CooldownRemainsP() > 2 or S.RisingSunKick:CooldownRemainsP() < 3 and S.FistsofFury:CooldownRemainsP() > 3 and Player:Chi() > 2 or S.RisingSunKick:CooldownRemainsP() > 3 and S.FistsofFury:CooldownRemainsP() < 3 and Player:Chi() > 4 or Player:Chi() > 5) or Player:BuffP(S.BlackoutKickBuff))) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 224"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>1
    if S.TigerPalm:IsReadyP() then
      if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm418) then return "tiger_palm 214"; end
    end
    -- Manual add to avoid main target icon problems
    if S.TigerPalm:IsReadyP() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() > 1) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 226"; end
    end
    -- flying_serpent_kick,interrupt=1
    -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(cooldown.fists_of_fury.remains<3&chi=2|energy.time_to_max<1)&(prev_gcd.1.tiger_palm|chi.max-chi<2)
    if S.BlackoutKick:IsReadyP() then
      if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick420) then return "blackout_kick 216"; end
    end
    -- Manual add to avoid main target icon problems
    if S.BlackoutKick:IsReadyP() and ((S.FistsofFury:CooldownRemainsP() < 3 and Player:Chi() == 2 or Player:EnergyTimeToMaxPredicted() < 1) and (Player:PrevGCD(1, S.TigerPalm) or Player:ChiDeficit() < 2)) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 228"; end
    end
  end
  Aoe = function()
    -- whirling_dragon_punch
    if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch, nil, nil, 8) then return "whirling_dragon_punch 232"; end
    end
    -- energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&energy<50
    if S.EnergizingElixir:IsReadyP() and (not Player:PrevGCD(1, S.TigerPalm) and Player:Chi() <= 1 and Player:Energy() < 50) then
      if HR.Cast(S.EnergizingElixir) then return "energizing_elixir 234"; end
    end
    -- fists_of_fury,if=energy.time_to_max>1
    if S.FistsofFury:IsReadyP() and (Player:EnergyTimeToMaxPredicted() > 1) then
      if HR.Cast(S.FistsofFury, nil, nil, 8) then return "fists_of_fury 236"; end
    end
    -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch.enabled&cooldown.rising_sun_kick.duration>cooldown.whirling_dragon_punch.remains+4)&(cooldown.fists_of_fury.remains>3|chi>=5)
    if S.RisingSunKick:IsReadyP() then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfRisingSunKick422) then return "rising_sun_kick 230"; end
    end
    -- Manual add to avoid main target icon problems
    if S.RisingSunKick:IsReadyP() and ((S.WhirlingDragonPunch:IsAvailable() and 10 * Player:SpellHaste() > S.WhirlingDragonPunch:CooldownRemainsP() + 4) and (S.FistsofFury:CooldownRemainsP() > 3 or Player:Chi() >= 5)) then
      if HR.Cast(S.RisingSunKick, nil, nil, "Melee") then return "rising_sun_kick 254"; end
    end
    -- rushing_jade_wind,if=buff.rushing_jade_wind.down
    if S.RushingJadeWind:IsReadyP() and (Player:BuffDownP(S.RushingJadeWindBuff)) then
      if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 238"; end
    end
    -- spinning_crane_kick,if=combo_strike&(((chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2))|energy.time_to_max<=3|buff.dance_of_chiji.react)
    if S.SpinningCraneKick:IsReadyP() and (ComboStrike(S.SpinningCraneKick) and (((Player:Chi() > 3 or S.FistsofFury:CooldownRemainsP() > 6) and (Player:Chi() >= 5 or S.FistsofFury:CooldownRemainsP() > 2)) or Player:EnergyTimeToMaxPredicted() <= 3 or Player:BuffP(S.DanceofChijiBuff))) then
      if HR.Cast(S.SpinningCraneKick, nil, nil, 8) then return "spinning_crane_kick 240"; end
    end
    -- reverse_harm,if=chi.max-chi>=2
    if S.ReverseHarm:IsReadyP() and (Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ReverseHarm, nil, nil, 10) then return "reverse_harm 242"; end
    end
    -- chi_burst,if=chi.max-chi>=3
    if S.ChiBurst:IsReadyP() and (Player:ChiDeficit() >= 3) then
      if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 244"; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
    if S.FistoftheWhiteTiger:IsReadyP() then
      if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger426) then return "fist_of_the_white_tiger 246"; end
    end
    -- Manual add to avoid main target icon problems
    if S.FistoftheWhiteTiger:IsReadyP() and (Player:ChiDeficit() >= 3) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 256"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=2&(!talent.hit_combo.enabled|!combo_break)
    if S.TigerPalm:IsReadyP() then
      if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm428) then return "tiger_palm 248"; end
    end
    -- Manual add to avoid main target icon problems
    if S.TigerPalm:IsReadyP() and (Player:ChiDeficit() >= 2 and (not S.HitCombo:IsAvailable() or ComboStrike(S.TigerPalm))) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 258"; end
    end
    -- chi_wave,if=!combo_break
    if S.ChiWave:IsReadyP() and (ComboStrike(S.ChiWave)) then
      if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 250"; end
    end
    -- flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
    -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|(talent.hit_combo.enabled&prev_gcd.1.tiger_palm&chi<4))
    if S.BlackoutKick:IsReadyP() then
      if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfBlackoutKick430) then return "blackout_kick 252"; end
    end
    -- Manual add to avoid main target icon problems
    if S.BlackoutKick:IsReadyP() and (ComboStrike(S.BlackoutKick) and (Player:BuffP(S.BlackoutKickBuff) or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4))) then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 260"; end
    end
  end
  UseItems = function()
    -- use_items
    local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- Out of Combat
  if not Player:AffectingCombat() then
    if Everyone.TargetIsValid() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- In Combat
  if Everyone.TargetIsValid() then
    -- auto_attack
    -- Interrupts
    Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, false);
    -- touch_of_karma,interval=90,pct_health=0.5
    -- potion,if=buff.serenity.up|buff.storm_earth_and_fire.up&dot.touch_of_death.remains|target.time_to_die<=60
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.SerenityBuff) or Player:BuffP(S.StormEarthandFireBuff) and Target:DebuffP(S.TouchofDeathDebuff) or Target:TimeToDie() <= 60) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 20"; end
    end
    -- reverse_harm,if=chi.max-chi>=2&(talent.serenity.enabled|!dot.touch_of_death.remains)&buff.serenity.down&(energy.time_to_max<1|talent.serenity.enabled&cooldown.serenity.remains<2|!talent.serenity.enabled&cooldown.touch_of_death.remains<3&!variable.hold_tod|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.ReverseHarm:IsReadyP() and (Player:ChiDeficit() >= 2 and (S.Serenity:IsAvailable() or Target:DebuffDownP(S.TouchofDeathDebuff)) and Player:BuffDownP(S.SerenityBuff) and (Player:EnergyTimeToMaxPredicted() < 1 or S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2 or not S.Serenity:IsAvailable() and S.TouchofDeath:CooldownRemainsP() < 3 and not VarHoldTod or Player:EnergyTimeToMaxPredicted() < 4 and S.FistsofFury:CooldownRemainsP() < 1.5)) then
      if HR.Cast(S.ReverseHarm, nil, nil, 10) then return "reverse_harm 22"; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3&buff.serenity.down&buff.seething_rage.down&(energy.time_to_max<1|talent.serenity.enabled&cooldown.serenity.remains<2|!talent.serenity.enabled&cooldown.touch_of_death.remains<3&!variable.hold_tod|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.FistoftheWhiteTiger:IsReadyP() then
      if HR.CastTargetIf(S.FistoftheWhiteTiger, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfFistoftheWhiteTiger402) then return "fist_of_the_white_tiger 24"; end
    end
    -- Manual add to avoid main target icon problems
    if S.FistoftheWhiteTiger:IsReadyP() and (Player:ChiDeficit() >= 3 and Player:BuffDownP(S.SerenityBuff) and Player:BuffDownP(S.SeethingRageBuff) and (Player:EnergyTimeToMaxPredicted() < 1 or S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2 or not S.Serenity:IsAvailable() and S.TouchofDeath:CooldownRemainsP() < 3 and not VarHoldTod or Player:EnergyTimeToMaxPredicted() < 4 and S.FistsofFury:CooldownRemainsP() < 1.5)) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, "Melee") then return "fist_of_the_white_tiger 25"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!combo_break&chi.max-chi>=2&(talent.serenity.enabled|!dot.touch_of_death.remains|active_enemies>2)&buff.seething_rage.down&buff.serenity.down&(energy.time_to_max<1|talent.serenity.enabled&cooldown.serenity.remains<2|!talent.serenity.enabled&cooldown.touch_of_death.remains<3&!variable.hold_tod|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.TigerPalm:IsReadyP() then
      if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane400, EvaluateTargetIfTigerPalm404) then return "tiger_palm 26"; end
    end
    -- Manual add to avoid main target icon problems
    if S.TigerPalm:IsReadyP() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (S.Serenity:IsAvailable() or Target:DebuffDownP(S.TouchofDeathDebuff) or Cache.EnemiesCount[8] > 2) and Player:BuffDownP(S.SeethingRageBuff) and Player:BuffDownP(S.SerenityBuff) and (Player:EnergyTimeToMaxPredicted() < 1 or S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2 or not S.Serenity:IsAvailable() and S.TouchofDeath:CooldownRemainsP() < 3 and not VarHoldTod or Player:EnergyTimeToMaxPredicted() < 4 and S.FistsofFury:CooldownRemainsP() < 1.5)) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 27"; end
    end
    -- chi_wave,if=!talent.fist_of_the_white_tiger.enabled&prev_gcd.1.tiger_palm&time<=3
    if S.ChiWave:IsReadyP() and (not S.FistoftheWhiteTiger:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and HL.CombatTime() <= 3) then
      if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 28"; end
    end
    -- call_action_list,name=cd_serenity,if=talent.serenity.enabled
    if (HR.CDsON() and S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_sef,if=!talent.serenity.enabled
    if (HR.CDsON() and not S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=serenity,if=buff.serenity.up
    if (Player:BuffP(S.SerenityBuff)) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
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

local function Init ()
  HL.RegisterNucleusAbility(113656, 8, 6)               -- Fists of Fury
  HL.RegisterNucleusAbility(101546, 8, 6)               -- Spinning Crane Kick
  HL.RegisterNucleusAbility(261715, 8, 6)               -- Rushing Jade Wind
  HL.RegisterNucleusAbility(152175, 8, 6)               -- Whirling Dragon Punch
end

HR.SetAPL(269, APL, Init);

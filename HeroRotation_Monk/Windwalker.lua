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

  -- Abilities
  TigerPalm                             = Spell(100780),
  RisingSunKick                         = Spell(107428),
  FistsOfFury                           = Spell(113656),
  SpinningCraneKick                     = Spell(101546),
  StormEarthAndFire                     = Spell(137639),
  FlyingSerpentKick                     = Spell(101545),
  FlyingSerpentKick2                    = Spell(115057),
  TouchOfDeath                          = Spell(115080),
  CracklingJadeLightning                = Spell(117952),
  BlackoutKick                          = Spell(100784),
  BlackoutKickBuff                      = Spell(116768),
  DanceOfChijiBuff                      = Spell(286587),
  
  -- Debuffs
  MarkoftheCraneDebuff                  = Spell(228287),

  -- Talents
  ChiWave                               = Spell(115098),
  ChiBurst                              = Spell(123986),
  FistOfTheWhiteTiger                   = Spell(261947),
  HitCombo                              = Spell(196741),
  InvokeXuentheWhiteTiger               = Spell(123904),
  RushingJadeWind                       = Spell(261715),
  WhirlingDragonPunch                   = Spell(152175),
  Serenity                              = Spell(152173),

  -- Artifact
  StrikeOfTheWindlord                   = Spell(205320),

  -- Defensive
  TouchOfKarma                          = Spell(122470),
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

  -- Legendaries
  TheEmperorsCapacitor                  = Spell(235054),

  -- Tier Set
  PressurePoint                         = Spell(247255),

  -- Azerite Traits
  SwiftRoundhouse                       = Spell(277669),
  SwiftRoundhouseBuff                   = Spell(278710),
  OpenPalmStrikes                       = Spell(279918),
  GloryoftheDawn                        = Spell(288634),
  
  -- Essences
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  
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
  DribblingInkpod                      = Item(169319, {13, 14}),
  PocketsizedComputationDevice         = Item(167555, {13, 14}),
  AshvanesRazorCoral                   = Item(169311, {13, 14})
};
local I = Item.Monk.Windwalker;

-- GUI Settings
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
};

local EnemyRanges = {8, 5}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function EvaluateTargetIfFilterMarkoftheCrane(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfRisingSunKick(TargetUnit)
  return (Player:BuffP(S.StormEarthAndFire) or S.WhirlingDragonPunch:CooldownRemainsP() < 4)
end

local function EvaluateTargetIfRisingSunKick2(TargetUnit)
  return Player:ChiDeficit() < 2
end

local function EvaluateTargetIfBlackoutKick(TargetUnit)
  return (not Player:PrevGCD(1, S.BlackoutKick) and (S.FistsOfFury:CooldownRemainsP() > 4 or Player:Chi() >= 4 or (Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm))))
end

local function EvaluateTargetIfTigerPalm(TargetUnit)
  return (not Player:PrevGCD(1, S.TigerPalm) and Player:ChiDeficit() >= 2)
end


-- Action Lists --
--- ======= MAIN =======
-- APL Main
local function APL ()
  local Precombat, Rskless, Cooldowns, SingleTarget, Serenity, Aoe, ToD
  -- Unit Update
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  -- Pre Combat --
  Precombat = function()
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion"; end
    end
    -- actions.precombat+=/chi_burst,if=(!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled)
    if S.ChiBurst:IsReadyP() and (not S.Serenity:IsAvailable() or not S.FistOfTheWhiteTiger:IsAvailable()) then
      if HR.Cast(S.ChiBurst) then return "Cast Pre-Combat Chi Burst"; end
    end
    -- actions.precombat+=/chi_wave,if=talent.fist_of_the_white_tiger.enabled
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then return "Cast Pre-Combat Chi Wave"; end
    end
    -- invoke_xuen_the_white_tiger
    if S.InvokeXuentheWhiteTiger:IsReadyP() then
      if HR.Cast(S.InvokeXuentheWhiteTiger) then return "Cast Pre-Combat Invoke Xuen the White Tiger"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Pre-Combat Guardian of Azeroth"; end
    end
  end
  
   -- Cooldowns --
  Cooldowns = function()
    -- actions.cd=invoke_xuen_the_white_tiger
    if HR.CDsON() and S.InvokeXuentheWhiteTiger:IsReadyP() then
      if HR.Cast(S.InvokeXuentheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuentheWhiteTiger) then return "Cast Cooldown Invoke Xuen the White Tiger"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Guardian of Azeroth"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Worldvein Resonance"; end
    end
    -- actions.cd+=/blood_fury
    if HR.CDsON() and S.BloodFury:IsReadyP() then
      if HR.CastSuggested(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Cooldown Blood Fury"; end
    end
    -- actions.cd+=/berserking
    if HR.CDsON() and S.Berserking:IsReadyP() then
      if HR.CastSuggested(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Cooldown Berserking"; end
    end
    -- actions.cd+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
    if S.ArcaneTorrent:IsReadyP() and (Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() > 0.5) then
      if HR.CastSuggested(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Cooldown Arcane Torrent"; end
    end
    -- actions.cd+=/fireblood
    if HR.CDsON() and S.Fireblood:IsReadyP() then
      if HR.CastSuggested(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Cooldown Fireblood"; end
    end
    -- actions.cd+=/ancestral_call
    if HR.CDsON() and S.AncestralCall:IsReadyP() then
      if HR.CastSuggested(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Cooldown Ancestral Call"; end
    end
    -- call_action_list,name=tod
    if (true) then
      local ShouldReturn = ToD(); if ShouldReturn then return ShouldReturn; end
    end
    -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|(cooldown.fists_of_fury.remains<=9&chi>=3&cooldown.whirling_dragon_punch.remains<=14&cooldown.touch_of_death.remains>=90)|target.time_to_die<=15|dot.touch_of_death.remains
    if S.StormEarthAndFire:IsReadyP() and (S.StormEarthAndFire:Charges() == 2 or (S.FistsOfFury:CooldownRemainsP() <= 9 and Player:Chi() >= 3 and S.WhirlingDragonPunch:CooldownRemainsP() <= 14 and S.TouchOfDeath:CooldownRemainsP() >= 90) or Target:TimeToDie() <= 15 or Target:DebuffP(S.TouchOfDeath)) then
      if HR.Cast(S.StormEarthAndFire, true) then return "Cast Cooldown Storm, Earth, and Fire"; end
    end
    -- concentrated_flame,if=dot.concentrated_flame_burn.remains<=2
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffRemainsP(S.ConcentratedFlameBurn) <= 2) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Concentrated Flame"; end
    end
    -- blood_of_the_enemy
    if S.BloodoftheEnemy:IsCastableP() then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Blood of the Enemy"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown The Unbound Force"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Purifying Blast"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Focused Azerite Beam"; end
    end
    -- use_item,name=pocketsized_computation_device,if=dot.touch_of_death.remains
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Target:DebuffP(S.TouchOfDeath)) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Cooldown Cyclotronic Blast"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=((equipped.cyclotronic_blast&cooldown.cyclotronic_blast.remains>=20)|!equipped.cyclotronic_blast)&(debuff.razor_coral_debuff.down|(!equipped.dribbling_inkpod|target.time_to_pct_30.remains<8)&buff.storm_earth_and_fire.remains>13|target.time_to_die<21)
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (((Everyone.PSCDEquipped() and I.PocketsizedComputationDevice:CooldownRemains() >= 20) or not Everyone.PSCDEquipped()) and (Target:DebuffDownP(S.RazorCoralDebuff) or (not I.DribblingInkpod:IsEquipped() or Target:TimeToX(30) < 8) and Player:BuffRemainsP(S.StormEarthAndFire) > 13 or Target:TimeToDie() < 21)) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Cooldown Ashvane's Razor Coral"; end
    end
    -- actions.cd+=/serenity,if=cooldown.rising_sun_kick.remains<=2|target.time_to_die<=12
    if HR.CDsON() and S.Serenity:IsReadyP() and (Player:BuffDownP(S.Serenity) and (S.RisingSunKick:CooldownRemainsP() <= 2 or Target:TimeToDie() <= 12)) then
      if HR.Cast(S.Serenity, Settings.Windwalker.GCDasOffGCD.Serenity) then return "Cast Cooldown Serenity"; end
    end
    -- memory_of_lucid_dreams,if=energy<40&buff.storm_earth_and_fire.up
    if S.MemoryofLucidDreams:IsCastableP() and (Player:EnergyPredicted() < 40 and Player:BuffP(S.StormEarthAndFire)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Memory of Lucid Dreams"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast Cooldown Ripple In Space"; end
    end
    -- use_items,if=(equipped.cyclotronic_blast&cooldown.cyclotronic_blast.remains<=20)|!equipped.cyclotronic_blast
  end
  
  -- Rskless --
  Rskless = function()
    -- whirling_dragon_punch
    if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch) then return "whirling_dragon_punch rskless"; end
    end
    -- fists_of_fury
    if S.FistsOfFury:IsReadyP() then
      if HR.Cast(S.FistsOfFury) then return "fists_of_fury rskless"; end
    end
    -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.storm_earth_and_fire.up|cooldown.whirling_dragon_punch.remains<4
    if S.RisingSunKick:IsReadyP() then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfRisingSunKick) then return "rising_sun_kick rskless"; end
    end
    -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
    if S.RushingJadeWind:IsReadyP() and (Player:BuffDownP(S.RushingJadeWind) and Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.RushingJadeWind) then return "rushing_jade_wind rskless"; end
    end
    -- reverse_harm,if=chi.max-chi>=2
    if S.ReverseHarm:IsReadyP() and Player:ChiDeficit() >= 2 and Player:HealthPercentage() < 92 then
      if HR.Cast(S.ReverseHarm) then return "reverse_harm rskless"; end
    end
    -- fist_of_the_white_tiger,if=chi<=2
    if S.FistOfTheWhiteTiger:IsReadyP() and (Player:Chi() <= 2) then
      if HR.Cast(S.FistOfTheWhiteTiger) then return "fist_of_the_white_tiger rskless"; end
    end
    -- energizing_elixir,if=chi<=3&energy<50
    if S.EnergizingElixir:IsCastableP() and (Player:Chi() <= 3 and Player:Energy() < 50) then
      if HR.Cast(S.EnergizingElixir) then return "energizing_elixir rskless"; end
    end
    -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.react
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and Player:BuffP(S.DanceOfChijiBuff)) then
      if HR.Cast(S.SpinningCraneKick) then return "spinning_crane_kick rskless"; end
    end
    -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(cooldown.fists_of_fury.remains>4|chi>=4|(chi=2&prev_gcd.1.tiger_palm))
    if S.BlackoutKick:IsReadyP() then
      if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfBlackoutKick) then return "blackout_kick rskless"; end
    end
    -- chi_wave
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then return "chi_wave rskless"; end
    end
    -- chi_burst,if=chi.max-chi>=1&active_enemies=1|chi.max-chi>=2
    if S.ChiBurst:IsCastableP() and (Player:ChiDeficit() >= 1 and Cache.EnemiesCount[8] == 1 or Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ChiBurst) then return "chi_burst rskless"; end
    end
    -- flying_serpent_kick,if=prev_gcd.1.blackout_kick&chi>3,interrupt=1
    if S.FlyingSerpentKick:IsCastableP() and (Player:PrevGCD(1, S.BlackoutKick) and Player:Chi() > 3) then
      if HR.Cast(S.FlyingSerpentKick) then return "flying_serpent_kick rskless"; end
    end
    -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi<2
    if S.RisingSunKick:IsReadyP() then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfRisingSunKick2) then return "rising_sun_kick rskless"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2
    if S.TigerPalm:IsCastableP() then
      if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfTigerPalm) then return "tiger_palm rskless"; end
    end
    -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
    if S.RisingSunKick:IsReadyP() then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane) then return "rising_sun_kick rskless"; end
    end
  end


  -- Serenity --
  Serenity = function()
    -- actions.serenity=rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies<3|prev_gcd.1.spinning_crane_kick
    if S.RisingSunKick:IsReadyP() and (Cache.EnemiesCount[5] < 3 or Player:PrevGCD(1,S.SpinningCraneKick)) then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfRisingSunKick2) then return "rising_sun_kick rskless"; end
    end
    -- actions.serenity+=/fists_of_fury,if=(buff.bloodlust.up&prev_gcd.1.rising_sun_kick&!azerite.swift_roundhouse.enabled)|buff.serenity.remains<1|(active_enemies>1&active_enemies<5)
    if S.FistsOfFury:IsReadyP() and ((Player:HasHeroismP() and Player:PrevGCD(1,S.RisingSunKick) and not S.SwiftRoundhouse:AzeriteEnabled()) or Player:BuffRemainsP(S.Serenity) < 1 or (Cache.EnemiesCount[8] > 1 and Cache.EnemiesCount[8] < 5)) then
      if HR.Cast(S.FistsOfFury) then return "Cast Serenity Fists of Fury"; end
    end
    -- actions.serenity+=/fist_of_the_white_tiger,if=talent.hit_combo.enabled&energy.time_to_max<2&prev_gcd.1.blackout_kick&chi<=2
    if S.FistOfTheWhiteTiger:IsReadyP() and (S.HitCombo:IsAvailable() and Player:EnergyTimeToMaxPredicted() < 2 and Player:PrevGCD(1, S.BlackoutKick) and Player:Chi() <= 2) then
      if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast Serenity Fist of the White Tiger"; end
    end
    -- actions.serenity+=/tiger_palm,if=talent.hit_combo.enabled&energy.time_to_max<1&prev_gcd.1.blackout_kick&chi.max-chi>=2
    if S.TigerPalm:IsReadyP() and (S.HitCombo:IsAvailable() and Player:EnergyTimeToMaxPredicted() < 1 and Player:PrevGCD(1, S.BlackoutKick) and Player:ChiDeficit() >= 2) then
      if HR.Cast(S.TigerPalm) then return "Cast Serenity Tiger Palm"; end
    end
    -- actions.serenity+=/spinning_crane_kick,if=combo_strike&(active_enemies>=3|(talent.hit_combo.enabled&prev_gcd.1.blackout_kick)|(active_enemies=2&prev_gcd.1.blackout_kick))
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and (Cache.EnemiesCount[8] >= 3 or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.BlackoutKick)) or (Cache.EnemiesCount[8] == 2 and Player:PrevGCD(1, S.BlackoutKick)))) then
      if HR.Cast(S.SpinningCraneKick) then return "Cast Serenity Spinning Crane Kick"; end
    end
    -- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains
    if S.BlackoutKick:IsReadyP() then
      if HR.Cast(S.BlackoutKick) then return "Cast Serenity Blackout Kick"; end
    end
  end

  -- Area of Effect --
  Aoe = function()
    -- actions.aoe=rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch.enabled&cooldown.whirling_dragon_punch.remains<5)&cooldown.fists_of_fury.remains>3
    if S.RisingSunKick:IsReadyP() and ((S.WhirlingDragonPunch:IsAvailable() and S.WhirlingDragonPunch:CooldownRemainsP() < 5) and S.FistsOfFury:CooldownRemainsP() > 3) then
      if HR.CastTargetIf(S.RisingSunKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfRisingSunKick) then return "rising_sun_kick rskless"; end
    end
    -- actions.aoe=whirling_dragon_punch
    if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch) then return "Cast AoE Whirling Dragon Punch"; end
    end
    -- actions.aoe+=/energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&energy<50
    if S.EnergizingElixir:IsReadyP() and (not Player:PrevGCD(1, S.TigerPalm) and Player:Chi() <= 1 and Player:EnergyPredicted() < 50) then
      if HR.Cast(S.EnergizingElixir) then return "Cast AoE Energizing Elixir"; end
    end
    -- actions.aoe+=/fists_of_fury,if=energy.time_to_max>3
    if S.FistsOfFury:IsReadyP() and (Player:EnergyTimeToMaxPredicted() > 3) then
      if HR.Cast(S.FistsOfFury) then return "Cast AoE Fists of Fury"; end
    end
    -- actions.aoe+=/rushing_jade_wind,if=buff.rushing_jade_wind.down
     if S.RushingJadeWind:IsReadyP() and (Player:BuffDownP(S.RushingJadeWind)) then
      if HR.Cast(S.RushingJadeWind) then return "Cast AoE Rushing Jade Wind"; end
    end
    -- actions.aoe+=/spinning_crane_kick,if=combo_strike&((chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2)|energy.time_to_max<=3)
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and (((Player:Chi() > 3 or S.FistsOfFury:CooldownRemainsP() > 6) and (Player:Chi() >= 5 or S.FistsOfFury:CooldownRemainsP() > 2)) or Player:EnergyTimeToMaxPredicted() <= 3)) then
      if HR.Cast(S.SpinningCraneKick) then return "Cast AoE Spinning Crane Kick"; end
    end
    -- actions.aoe+=/reverse_harm,if=chi.max-chi>=2
    if S.ReverseHarm:IsReady() and Player:HealthPercentage() < 92 and (Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ReverseHarm) then return "Cast Reverse Harm"; end
    end
    -- actions.aoe+=/chi_burst,if=chi<=3
    if S.ChiBurst:IsReadyP() and (Player:ChiDeficit() <= 3) then
      if HR.Cast(S.ChiBurst) then return "Cast AoE Chi Burst"; end
    end  
    -- actions.aoe+=/fist_of_the_white_tiger,if=chi.max-chi>=3
    if S.FistOfTheWhiteTiger:IsReadyP() and (Player:ChiDeficit() >= 3) then
      if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast AoE Fist of the White Tiger"; end
    end
    -- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=2&(!talent.hit_combo.enabled|!combo_break)
    if S.TigerPalm:IsReadyP() and (Player:ChiDeficit() >= 2 and (not S.HitCombo:IsAvailable() or not Player:PrevGCD(1, S.TigerPalm))) then
      if HR.CastTargetIf(S.TigerPalm, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfTigerPalm) then return "tiger_palm rskless"; end
    end
    -- actions.st+=/chi_wave,if=!combo_break
    if S.ChiWave:IsReadyP() and (not Player:PrevGCD(1, S.ChiWave)) then
      if HR.Cast(S.ChiWave) then return "Cast AoE Chi Wave"; end
    end
    -- actions.aoe+=/flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
    -- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|(talent.hit_combo.enabled&prev_gcd.1.tiger_palm&chi<4))
    if S.BlackoutKick:IsReadyP() and (not Player:PrevGCD(1, S.BlackoutKick) and (Player:BuffP(S.BlackoutKickBuff) or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4))) then
      if HR.CastTargetIf(S.BlackoutKick, 8, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfBlackoutKick) then return "blackout_kick rskless"; end
    end
  end

  -- Single Target --
  SingleTarget = function()
    -- actions.st+=/whirling_dragon_punch
    if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch) then return "Cast Single Target Whirling Dragon Punch"; end
    end
    -- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=chi>=5
    if S.RisingSunKick:IsReadyP() and (Player:Chi() >= 5) then
      if HR.Cast(S.RisingSunKick) then return "Cast Single Target Rising Sun Kick"; end
    end
    -- actions.st+=/fists_of_fury,if=energy.time_to_max>3
    if S.FistsOfFury:IsReadyP() and (Player:EnergyTimeToMaxPredicted() > 3) then
      if HR.Cast(S.FistsOfFury) then return "Cast Single Target Fists of Fury"; end
    end
    -- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
    if S.RisingSunKick:IsReadyP() then
      if HR.Cast(S.RisingSunKick) then return "Cast Single Target Rising Sun Kick"; end
    end
    -- actions.st+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
    if S.RushingJadeWind:IsReadyP() and (Player:BuffDownP(S.RushingJadeWind) and Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.RushingJadeWind) then return "Cast Single Target Rushing Jade Wind"; end
    end
    -- actions.st+=/reverse_harm,if=chi.max-chi>=2
    if S.ReverseHarm:IsReady() and Player:HealthPercentage() < 92 and (Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ReverseHarm) then return "Cast Reverse Harm"; end
    end
    -- actions.st+=/fist_of_the_white_tiger,if=chi<=2
    if S.FistOfTheWhiteTiger:IsReadyP() and (Player:Chi() <= 2) then
      if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast Single Target Fist of the White Tiger"; end
    end
    -- actions.st+=/energizing_elixir,if=chi<=3&energy<50
    if S.EnergizingElixir:IsReadyP() and (Player:Chi() <= 3 and Player:EnergyPredicted() < 50) then
      if HR.Cast(S.EnergizingElixir) then return "Cast Single Target Energizing Elixir"; end
    end
    -- actions.st+=/spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.react
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and Player:BuffP(S.DanceOfChijiBuff)) then 
      if HR.Cast(S.SpinningCraneKick) then return "Cast AoE Spinning Crane Kick"; end
    end
    -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(cooldown.rising_sun_kick.remains>3|chi>=3)&(cooldown.fists_of_fury.remains>4|chi>=4|(chi=2&prev_gcd.1.tiger_palm)|(azerite.swift_roundhouse.rank>=2&active_enemies=1))&buff.swift_roundhouse.stack<2
    if S.BlackoutKick:IsReadyP() and (not Player:PrevGCD(1, S.BlackoutKick) and (S.RisingSunKick:CooldownRemainsP() > 3 or Player:Chi() >= 3) and (S.FistsOfFury:CooldownRemainsP() > 4 or Player:Chi() >= 4 or (Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm)) or (S.SwiftRoundhouse:AzeriteRank() >= 2 and Cache.EnemiesCount[5] == 1)) and Player:BuffStack(S.SwiftRoundhouseBuff) < 2) then
      if HR.Cast(S.BlackoutKick) then return "Cast Single Target Blackout Kick"; end
    end
    -- actions.st+=/chi_wave
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then return "Cast Single Target Chi Wave"; end
    end
    -- actions.st+=/chi_burst,if=chi.max-chi>=1&active_enemies=1|chi.max-chi>=2
    if S.ChiBurst:IsReadyP() and ((Player:ChiDeficit() >= 1 and Cache.EnemiesCount[8] == 1) or Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ChiBurst) then return "Cast Single Target Chi Burst"; end
    end  
    -- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(buff.rushing_jade_wind.down|energy>56)
    if S.TigerPalm:IsReadyP() and (not Player:PrevGCD(1, S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDownP(S.RushingJadeWind) or Player:EnergyPredicted() > 56)) then
      if HR.Cast(S.TigerPalm) then return "Cast Single Target Tiger Palm"; end
    end
    -- actions.st+=/flying_serpent_kick,if=prev_gcd.1.blackout_kick&chi>3&buff.swift_roundhouse.stack<2,interrupt=1
  end
  
  ToD = function()
    -- touch_of_death,if=equipped.cyclotronic_blast&target.time_to_die>9&cooldown.cyclotronic_blast.remains<=2
    if S.TouchOfDeath:IsReadyP() and (Everyone.PSCDEquipped() and Target:TimeToDie() > 9 and I.PocketsizedComputationDevice:CooldownRemains() <= 2) then
      if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return "Cast ToD Touch of Death 1"; end
    end
    -- touch_of_death,if=!equipped.cyclotronic_blast&equipped.dribbling_inkpod&target.time_to_die>9&(target.time_to_pct_30.remains>=130|target.time_to_pct_30.remains<8)
    if S.TouchOfDeath:IsReadyP() and (not Everyone.PSCDEquipped() and I.DribblingInkpod:IsEquipped() and Target:TimeToDie() > 9 and (Target:TimeToX(30) >= 130 or Target:TimeToX(30) < 8)) then
      if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return "Cast ToD Touch of Death 2"; end
    end
    -- touch_of_death,if=!equipped.cyclotronic_blast&!equipped.dribbling_inkpod&target.time_to_die>9
    if S.TouchOfDeath:IsReadyP() and (not Everyone.PSCDEquipped() and not I.DribblingInkpod:IsEquipped() and Target:TimeToDie() > 9) then
      if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return "Cast ToD Touch of Death 3"; end
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
    -- Interrupts
    Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, false);
	
    -- potion,if=buff.serenity.up|buff.storm_earth_and_fire.up|(!talent.serenity.enabled&trinket.proc.agility.react)|buff.bloodlust.react|target.time_to_die<=60
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.Serenity) or Player:BuffP(S.StormEarthAndFire) or (not S.Serenity:IsAvailable()) or Player:HasHeroismP() or Target:TimeToDie() <= 60) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion"; end
    end
    -- actions+=/call_action_list,name=serenity,if=buff.serenity.up
    if Player:BuffP(S.Serenity) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
    end
	
	-- prevent energy cap, where possible
    -- reverse_harm,if=(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2))&chi.max-chi>=2
    if S.ReverseHarm:IsReadyP() and Player:HealthPercentage() < 92 and ((Player:EnergyTimeToMaxPredicted() < 1 or (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2)) and Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ReverseHarm) then return "Cast Everyone Reverse Harm"; end
    end
    -- fist_of_the_white_tiger,if=(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2)|(energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5))&chi.max-chi>=3
    if S.FistOfTheWhiteTiger:IsReadyP() and ((Player:EnergyTimeToMaxPredicted() < 1 or (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2) or (Player:EnergyTimeToMaxPredicted() < 4 and S.FistsOfFury:CooldownRemainsP() < 1.5)) and Player:ChiDeficit() >= 3) then
      if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast Everyone Fist of the White Tiger"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!combo_break&(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2)|(energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5))&chi.max-chi>=2&!dot.touch_of_death.remains
    if S.TigerPalm:IsReadyP() and (not Player:PrevGCD(1, S.TigerPalm) and (Player:EnergyTimeToMaxPredicted() < 1 or (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2) or (Player:EnergyTimeToMaxPredicted() < 4 and S.FistsOfFury:CooldownRemainsP() < 1.5)) and Player:ChiDeficit() >= 2 and Target:DebuffDownP(S.TouchOfDeath)) then
      if HR.Cast(S.TigerPalm) then return "Cast Everyone Tiger Palm"; end
    end
	
    -- chi_wave,if=!talent.fist_of_the_white_tiger.enabled&time<=3
    if S.ChiWave:IsReadyP() and (not S.FistOfTheWhiteTiger:IsAvailable() and HL.CombatTime() <= 3) then
      if HR.Cast(S.ChiWave) then return "Cast Everyone Chi Wave"; end
    end
	
    -- actions.st=call_action_list,name=cd
    if (true) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
	
    -- call_action_list,name=rskless,if=active_enemies<3&azerite.open_palm_strikes.enabled&!azerite.glory_of_the_dawn.enabled
    if (Cache.EnemiesCount[8] < 3 and S.OpenPalmStrikes:AzeriteEnabled() and not S.GloryoftheDawn:AzeriteEnabled()) then
      local ShouldReturn = Rskless(); if ShouldReturn then return ShouldReturn; end
    end
    -- actions+=/call_action_list,name=st,if=active_enemies<3
    if Cache.EnemiesCount[8] < 3 then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end;
    -- actions+=/call_action_list,name=aoe,if=active_enemies>=3
    if Cache.EnemiesCount[8] >= 3 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
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

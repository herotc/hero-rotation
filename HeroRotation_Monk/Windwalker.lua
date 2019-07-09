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
  
  -- Essences
  BloodOfTheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryOfLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianOfAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForce                         = Spell(302932),
  
  -- PvP Abilities
  ReverseHarm                           = Spell(287771),

  -- Misc
  PoolEnergy                            = Spell(9999000010)
};
local S = Spell.Monk.Windwalker;

-- Items
if not Item.Monk then Item.Monk = {}; end
Item.Monk.Windwalker = {
  
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

HL.RegisterNucleusAbility(113656, 8, 6)               -- Fists of Fury
HL.RegisterNucleusAbility(101546, 8, 6)               -- Spinning Crane Kick
HL.RegisterNucleusAbility(261715, 8, 6)               -- Rushing Jade Wind
HL.RegisterNucleusAbility(152175, 8, 6)               -- Whirling Dragon Punch

-- Action Lists --
--- ======= MAIN =======
-- APL Main
local function APL ()
  local Precombat, Essences, Cooldowns, SingleTarget, Serenity, Aoe
  -- Unit Update
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  -- Pre Combat --
  Precombat = function()
    -- actions.precombat+=/chi_burst,if=(!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled)
    if S.ChiBurst:IsReadyP() and (not S.Serenity:IsAvailable() or not S.FistOfTheWhiteTiger:IsAvailable()) then
      if HR.Cast(S.ChiBurst) then return "Cast Pre-Combat Chi Burst"; end
    end
    -- actions.precombat+=/chi_wave
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then return "Cast Pre-Combat Chi Wave"; end
    end
  end
  
  -- Essences --
  Essences = function()
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Settings.Windwalker.GCDasOffGCD.Essences) then return "concentrated_flame"; end
    end
    -- blood_of_the_enemy
    if S.BloodOfTheEnemy:IsCastableP() then
      if HR.Cast(S.BloodOfTheEnemy, Settings.Windwalker.GCDasOffGCD.Essences) then return "blood_of_the_enemy"; end
    end
    -- guardian_of_azeroth
    if S.GuardianOfAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianOfAzeroth, Settings.Windwalker.GCDasOffGCD.Essences) then return "guardian_of_azeroth"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, Settings.Windwalker.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, Settings.Windwalker.GCDasOffGCD.Essences) then return "purifying_blast"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, Settings.Windwalker.GCDasOffGCD.Essences) then return "the_unbound_force"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, Settings.Windwalker.GCDasOffGCD.Essences) then return "ripple_in_space"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance, Settings.Windwalker.GCDasOffGCD.Essences) then return "worldvein_resonance"; end
    end
    -- memory_of_lucid_dreams,if=energy<40&buff.storm_earth_and_fire.up
    if S.MemoryOfLucidDreams:IsCastableP() and (Player:Energy() < 40 and Player:BuffP(S.StormEarthAndFire)) then
      if HR.Cast(S.MemoryOfLucidDreams, Settings.Windwalker.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams"; end
    end
  end

  -- Cooldowns --
  Cooldowns = function()
    -- actions.cd=invoke_xuen_the_white_tiger
    if HR.CDsON() and S.InvokeXuentheWhiteTiger:IsReadyP() then
      if HR.Cast(S.InvokeXuentheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger) then return "Cast Cooldown Invoke Xuen the White Tiger"; end
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
    -- actions.cd+=/touch_of_death,if=target.time_to_die>9
    if HR.CDsON() and S.TouchOfDeath:IsReadyP() and (Target:TimeToDie() > 9) then
      if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return "Cast Cooldown Touch of Death"; end
    end
    -- actions.cd+=/storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|(cooldown.fists_of_fury.remains<=6&chi>=3&cooldown.rising_sun_kick.remains<=1)|target.time_to_die<=15
    if HR.CDsON() and S.StormEarthAndFire:IsReadyP() and (not Player:BuffP(S.StormEarthAndFire) and (S.StormEarthAndFire:ChargesP() == 2 or S.FistsOfFury:CooldownRemainsP() <= 6) and Player:Chi() >= 3 and (S.RisingSunKick:CooldownRemainsP() <= 1 or Target:TimeToDie() <= 15)) then
      if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.GCDasOffGCD.Serenity) then return "Cast Cooldown Storm, Earth and Fire"; end
    end
    -- actions.cd+=/serenity,if=cooldown.rising_sun_kick.remains<=2|target.time_to_die<=12
    if HR.CDsON() and S.Serenity:IsReadyP() and (not Player:BuffP(S.Serenity) and (S.RisingSunKick:CooldownRemainsP() <= 2 or Target:TimeToDie() <= 12)) then
      if HR.Cast(S.Serenity, Settings.Windwalker.GCDasOffGCD.Serenity) then return "Cast Cooldown Serenity"; end
    end
    -- call_action_list,name=essences
    if (true) then
      local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
  end

  -- Serenity --
  Serenity = function()
    -- actions.serenity=rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies<3|prev_gcd.1.spinning_crane_kick
    if S.RisingSunKick:IsReadyP() and (Cache.EnemiesCount[5] < 3 or Player:PrevGCD(1,S.SpinningCraneKick)) then
      if HR.Cast(S.RisingSunKick) then return "Cast Serenity Rising Sun Kick"; end
    end
    -- actions.serenity+=/fists_of_fury,if=(buff.bloodlust.up&prev_gcd.1.rising_sun_kick&!azerite.swift_roundhouse.enabled)|buff.serenity.remains<1|(active_enemies>1&active_enemies<5)
    if S.FistsOfFury:IsReadyP() and ((Player:HasHeroismP() and Player:PrevGCD(1,S.RisingSunKick) and not S.SwiftRoundhouse:AzeriteEnabled()) or Player:BuffRemainsP(S.Serenity) < 1 or (Cache.EnemiesCount[8] > 1 and Cache.EnemiesCount[8] < 5)) then
      if HR.Cast(S.FistsOfFury) then return "Cast Serenity Fists of Fury"; end
    end
    -- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick&(active_enemies>=3|(active_enemies=2&prev_gcd.1.blackout_kick))
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and (Cache.EnemiesCount[8] >= 3 or (Cache.EnemiesCount[8] == 2 and Player:PrevGCD(1, S.BlackoutKick)))) then
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
      if HR.Cast(S.RisingSunKick) then return "Cast AoE Rising Sun Kick"; end
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
    -- actions.aoe+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick&((chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2)|energy.time_to_max<=3)
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and (((Player:Chi() > 3 or S.FistsOfFury:CooldownRemainsP() > 6) and (Player:Chi() >= 5 or S.FistsOfFury:CooldownRemainsP() > 2)) or Player:EnergyTimeToMaxPredicted() <= 3)) then
      if HR.Cast(S.SpinningCraneKick) then return "Cast AoE Spinning Crane Kick"; end
    end
    -- actions.aoe+=/reverse_harm,if=chi.max-chi>=2
    if S.ReverseHarm:IsReady() and (Player:ChiDeficit() >= 2) then
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
    -- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=2&(!talent.hit_combo.enabled|!prev_gcd.1.tiger_palm)
    if S.TigerPalm:IsReadyP() and (Player:ChiDeficit() >= 2 and (not S.HitCombo:IsAvailable() or not Player:PrevGCD(1, S.TigerPalm))) then
      if HR.Cast(S.TigerPalm) then return "Cast AoE Tiger Palm"; end
    end
    -- actions.st+=/chi_wave
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then return "Cast AoE Chi Wave"; end
    end
    -- actions.aoe+=/flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
    -- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&(buff.bok_proc.up|(talent.hit_combo.enabled&prev_gcd.1.tiger_palm&chi<4))
    if S.BlackoutKick:IsReadyP() and (not Player:PrevGCD(1, S.BlackoutKick) and (Player:BuffP(S.BlackoutKickBuff) or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4))) then
      if HR.Cast(S.BlackoutKick) then return "Cast AoE Blackout Kick"; end
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
    -- actions.st+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick&buff.dance_of_chiji.up
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and Player:BuffP(S.DanceOfChijiBuff)) then 
      if HR.Cast(S.SpinningCraneKick) then return "Cast AoE Spinning Crane Kick"; end
    end
    -- actions.st+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
    if S.RushingJadeWind:IsReadyP() and (Player:BuffDownP(S.RushingJadeWind) and Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.RushingJadeWind) then return "Cast Single Target Rushing Jade Wind"; end
    end
    -- actions.st+=/reverse_harm,if=chi.max-chi>=2
    if S.ReverseHarm:IsReady() and (Player:ChiDeficit() >= 2) then
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
    -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&(cooldown.rising_sun_kick.remains>3|chi>=3)&(cooldown.fists_of_fury.remains>4|chi>=4|(chi=2&prev_gcd.1.tiger_palm)|(azerite.swift_roundhouse.rank>=2&active_enemies=1))&buff.swift_roundhouse.stack<2
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
    -- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi.max-chi>=2&(buff.rushing_jade_wind.down|energy>56)
    if S.TigerPalm:IsReadyP() and (not Player:PrevGCD(1, S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDownP(S.RushingJadeWind) or Player:EnergyPredicted() > 56)) then
      if HR.Cast(S.TigerPalm) then return "Cast Single Target Tiger Palm"; end
    end
    -- actions.st+=/flying_serpent_kick,if=prev_gcd.1.blackout_kick&chi>3&buff.swift_roundhouse.stack<2,interrupt=1
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
    -- actions+=/call_action_list,name=serenity,if=buff.serenity.up
    if Player:BuffP(S.Serenity) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- actions+=/fist_of_the_white_tiger,if=(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2))&chi.max-chi>=3
    if S.FistOfTheWhiteTiger:IsReadyP() and ((Player:EnergyTimeToMaxPredicted() < 1 or (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2)) and Player:ChiDeficit() >= 3) then
      if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast Everyone Fist of the White Tiger"; end
    end
    -- actions+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2))&chi.max-chi>=2&!prev_gcd.1.tiger_palm
    if S.TigerPalm:IsReadyP() and ((Player:EnergyTimeToMaxPredicted() < 1 or (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2)) and Player:ChiDeficit() >= 2 and not Player:PrevGCD(1, S.TigerPalm)) then
      if HR.Cast(S.TigerPalm) then return "Cast Everyone Tiger Palm"; 
      end
    end
    -- actions.st=call_action_list,name=cd
    if (true) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
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
HR.SetAPL(269, APL);

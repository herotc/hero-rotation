-- ----- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
-- HeroRotation
local HR = HeroRotation;
-- Lua
local pairs = pairs;

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;

-- Spells
if not Spell.Monk then Spell.Monk = {}; end
Spell.Monk.Windwalker = {

  -- Racials
  Bloodlust                        = Spell(2825),
  ArcaneTorrent                    = Spell(25046),
  Berserking                       = Spell(26297),
  BloodFury                        = Spell(20572),
  GiftoftheNaaru                   = Spell(59547),
  Shadowmeld                       = Spell(58984),
  QuakingPalm                      = Spell(107079),
  Fireblood                        = Spell(265221),
  AncestralCall                    = Spell(274738),

  -- Abilities
  TigerPalm                        = Spell(100780),
  RisingSunKick                    = Spell(107428),
  FistsOfFury                      = Spell(113656),
  SpinningCraneKick                = Spell(101546),
  StormEarthAndFire                = Spell(137639),
  FlyingSerpentKick                = Spell(101545),
  FlyingSerpentKick2               = Spell(115057),
  TouchOfDeath                     = Spell(115080),
  CracklingJadeLightning           = Spell(117952),
  BlackoutKick                     = Spell(100784),
  BlackoutKickBuff                 = Spell(116768),

  -- Talents
  ChiWave                          = Spell(115098),
  ChiBurst                         = Spell(123986),
  FistOfTheWhiteTiger              = Spell(261947),
  HitCombo                         = Spell(196741),
  InvokeXuentheWhiteTiger          = Spell(123904),
  RushingJadeWind                  = Spell(116847),
  WhirlingDragonPunch              = Spell(152175),
  Serenity                         = Spell(152173),

  -- Artifact
  StrikeOfTheWindlord              = Spell(205320),

  -- Defensive
  TouchOfKarma                     = Spell(122470),
  DiffuseMagic                     = Spell(122783), --Talent
  DampenHarm                       = Spell(122278), --Talent

  -- Utility
  Detox                            = Spell(218164),
  Effuse                           = Spell(116694),
  EnergizingElixir                 = Spell(115288), --Talent
  TigersLust                       = Spell(116841), --Talent
  LegSweep                         = Spell(119381), --Talent
  Disable                          = Spell(116095),
  HealingElixir                    = Spell(122281), --Talent
  Paralysis                        = Spell(115078),

  -- Legendaries
  TheEmperorsCapacitor             = Spell(235054),

  -- Tier Set
  PressurePoint                    = Spell(247255),

  -- Azerite Traits
  SwiftRoundhouse                  = Spell(277669),
  SwiftRoundhouseBuff              = Spell(278710),

    -- Misc
    PoolEnergy                    = Spell(9999000010),

};
local S = Spell.Monk.Windwalker;
-- Items
if not Item.Monk then Item.Monk = {}; end
Item.Monk.Windwalker = {
  -- Legendaries
  DrinkingHornCover                = Item(137097, {9}),
  TheEmperorsCapacitor             = Item(144239, {5}),
  KatsuosEclipse                   = Item(137029, {8}),
};
local I = Item.Monk.Windwalker;
-- Rotation Var


local BaseCost = {
  [S.BlackoutKick] = (Player:Level() < 12 and 3 or (Player:Level() < 22 and 2 or 1)),
  [S.RisingSunKick] = 2,
  [S.FistsOfFury] = ((I.KatsuosEclipse:IsEquipped() and Player:Level() < 116) and 2 or 3),
  [S.SpinningCraneKick] = 2
}
-- GUI Settings
local Settings = {
  General 		= HR.GUISettings.General,
  Commons 		= HR.GUISettings.APL.Monk.Commons,
  Windwalker 	= HR.GUISettings.APL.Monk.Windwalker
};

-- Functions --
function Spell:IsUsableP ()
  if self:Cost(2) > 0 and self:CostInfo(1,"type") == 3 then
    return Player:EnergyPredicted() >= self:Cost(2);
  elseif self:Cost(1) == 0 and self:CostInfo(1,"type") == 12 then
    return Player:BuffP(S.Serenity) and self:IsUsable() or Player:Chi() >= BaseCost[self];
  else
    return self:IsUsable();
  end
end

function Spell:IsReady ( Range, AoESpell, ThisUnit )
    return self:IsCastableP( Range, AoESpell, ThisUnit ) and self:IsUsableP();
end

local function EnergyTimeToXP (Amount, Offset)
  if Player:EnergyRegen() == 0 then return -1; end
  return Amount > Player:EnergyPredicted() and (Amount - Player:EnergyPredicted()) / (Player:EnergyRegen() * (1 - (Offset or 0))) or 0;
end
-- ReadyTime - Returns a normalized number based on spell usability and cooldown so you can easliy compare.
function Spell:ReadyTime(Index)
	if not self:IsLearned() or not self:IsAvailable() or Player:PrevGCD(1, self) then return 999; end
	if self:IsUsableP() then
		return self:CooldownRemainsP();
	elseif not self:IsUsableP() then
		if self:Cost(Index) ~= 0 and self:CostInfo(1,"type") == 3 then
			return EnergyTimeToXP(self:Cost(Index));
		else return 999; end
	end
end

-- IsReady - Compare ReadyTime vs CastRemains / GCD
function Spell:Ready(Index)
  return self:IsReadyP();
end

-- Action Lists --
local function single_target ()
  -- actions.st=call_action_list,name=cd
  -- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=azerite.swift_roundhouse.enabled&buff.swift_roundhouse.stack=2
  if S.RisingSunKick:IsReadyP() and S.SwiftRoundhouse:AzeriteEnabled() and Player:BuffStack(S.SwiftRoundhouseBuff) == 2 then
    if HR.Cast(S.RisingSunKick) then return "Cast Rising Sun Kick"; end
  end
 	-- actions.st+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&!prev_gcd.1.rushing_jade_wind
	if S.RushingJadeWind:IsReadyP() and Player:BuffP(S.RushingJadeWind) and not Player:PrevGCD(1, S.RushingJadeWind) then
	  if HR.Cast(S.RushingJadeWind) then return "Cast Rushing Jade Wind"; end
	end
	-- actions.st+=/energizing_elixir,if=!prev_gcd.1.tiger_palm
	if S.EnergizingElixir:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm)  then
		if HR.Cast(S.EnergizingElixir) then return "Cast Energizing Elixir"; end
	end
  -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&buff.bok_proc.up
  if S.BlackoutKick:IsReadyP()
    and (
      not Player:PrevGCD(1, S.BlackoutKick)
      and Player:ChiDeficit() >= 1
      and HL.Tier21_4Pc
      and Player:BuffP(S.BlackoutKickBuff)
    ) then
    if HR.Cast(S.BlackoutKick) then return "Cast Blackout Kick"; end
  end
  -- actions.st+=/fist_of_the_white_tiger,if=(chi<=2)
  if S.FistOfTheWhiteTiger:IsReadyP() and Player:Chi() <= 2 then
    if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast Fist of the White Tiger"; end
  end
  -- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi<=3&energy.time_to_max<2
  if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and Player:EnergyTimeToMaxPredicted() < 2 then
    if HR.Cast(S.TigerPalm) then return "Cast Tiger Palm"; end
  end
	-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi.max-chi>=2&buff.serenity.down&cooldown.fist_of_the_white_tiger.remains>energy.time_to_max
  if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and Player:ChiDeficit() >= 2 and 
  Player:BuffDownP(S.Serenity) and S.FistOfTheWhiteTiger:CooldownRemainsP() >= Player:EnergyTimeToMaxPredicted() then
    if HR.Cast(S.TigerPalm) then return "Cast Tiger Palm"; end
  end
	-- actions.st+=/whirling_dragon_punch
	if S.WhirlingDragonPunch:IsReady() then
    if HR.Cast(S.WhirlingDragonPunch) then return "Cast Whirling Dragon Punch"; end
  end
  -- actions.st+=/fists_of_fury,if=chi>=3&energy.time_to_max>2.5&azerite.swift_roundhouse.rank<3
	if S.FistsOfFury:IsReadyP() and Player:Chi() >= 3 and Player:EnergyTimeToMaxPredicted() > 2.5 and
	S.SwiftRoundhouse:AzeriteRank() < 3 then
	  if HR.Cast(S.FistsOfFury) then return "Cast Fists of Fury"; end
	end
	-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=((chi>=3&energy>=40)|chi>=5)&(talent.serenity.enabled|cooldown.serenity.remains>=6)&!azerite.swift_roundhouse.enabled
	if S.RisingSunKick:IsReadyP() and ((Player:Chi() >= 3 and Player:EnergyPredicted() >= 40) or Player:Chi() == 5) and
	(not S.Serenity:IsAvailable() or S.Serenity:CooldownRemainsP() >= 6) and not S.SwiftRoundhouse:AzeriteEnabled() then
	  if HR.Cast(S.RisingSunKick) then return "Cast Rising Sun Kick"; end
  end
	-- actions.st+=/fists_of_fury,if=!talent.serenity.enabled&(azerite.swift_roundhouse.rank<3|cooldown.whirling_dragon_punch.remains<13)
  if S.FistsOfFury:IsReadyP() and not S.Serenity:IsAvailable() and 
  (S.SwiftRoundhouse:AzeriteRank() < 3 or S.WhirlingDragonPunch:CooldownRemainsP() < 13) then
	  if HR.Cast(S.FistsOfFury) then return "Cast Fists of Fury"; end
	end
	-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>=5|(!talent.serenity.enabled)&!azerite.swift_roundhouse.enabled
  if S.RisingSunKick:IsReadyP() and (S.Serenity:CooldownRemainsP() >= 5 or not S.Serenity:IsAvailable()) and
  not S.SwiftRoundhouse:AzeriteEnabled() then
	  if HR.Cast(S.RisingSunKick) then return "Cast Rising Sun Kick"; end
	end
  -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.fists_of_fury.remains>2&!prev_gcd.1.blackout_kick&energy.time_to_max>1&azerite.swift_roundhouse.rank>2
  if S.BlackoutKick:IsReadyP()
    and (
      S.FistsOfFury:CooldownRemainsP() > 2
      and not Player:PrevGCD(1, S.BlackoutKick)
      and Player:EnergyTimeToMaxPredicted() > 1
      and S.SwiftRoundhouse:AzeriteRank() > 2
      ) then
    if HR.Cast(S.BlackoutKick) then return "Cast Blackout Kick"; end
  end
  -- actions.st+=/flying_serpent_kick,if=prev_gcd.1.blackout_kick&energy.time_to_max>2&chi>1,interrupt=1
  -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.swift_roundhouse.stack<2&!prev_gcd.1.blackout_kick
  if S.BlackoutKick:IsReadyP()
    and (
      Player:BuffStack(S.SwiftRoundhouseBuff) < 2
      and not Player:PrevGCD(1, S.BlackoutKick)
      ) then
    if HR.Cast(S.BlackoutKick) then return "Cast Blackout Kick"; end
  end
	-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
	if S.CracklingJadeLightning:IsReadyP() and I.TheEmperorsCapacitor:IsEquipped() and
	Player:BuffStack(S.TheEmperorsCapacitor) >= 19 and Player:EnergyTimeToMaxPredicted() > 3 then
	  if HR.Cast(S.CracklingJadeLightning) then return "Cast Crackling Jade Lightning"; end
	end
	-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
	if S.CracklingJadeLightning:IsReadyP() and I.TheEmperorsCapacitor:IsEquipped() and Player:BuffStack(S.TheEmperorsCapacitor) >= 14 and
	S.Serenity:CooldownRemainsP() < 13 and S.Serenity:IsAvailable() and Player:EnergyTimeToMaxPredicted() > 3 then
	  if HR.Cast(S.CracklingJadeLightning) then return "Cast Crackling Jade Lightning"; end
	end
	-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick
	if S.BlackoutKick:IsReadyP() and not Player:PrevGCD(1, S.BlackoutKick) then
	  if HR.Cast(S.BlackoutKick) then return "Cast Blackout Kick"; end
	end
  -- actions.st+=/chi_wave
	if S.ChiWave:IsReadyP() then
		if HR.Cast(S.ChiWave) then return "Cast Chi Wave"; end
  end
	-- actions.st+=/chi_burst,if=energy.time_to_max>1&talent.serenity.enabled
	if S.ChiBurst:IsReadyP() and Player:EnergyTimeToMaxPredicted() > 1 and S.Serenity:IsAvailable() then
		if HR.Cast(S.ChiBurst) then return "Chi Burst"; end
	end  
  -- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&(chi.max-chi>=2|energy.time_to_max<3)&!buff.serenity.up
  if S.TigerPalm:Ready(2) and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir) and 
  (Player:EnergyTimeToMaxPredicted() < 3 or Player:ChiDeficit() >= 2) and not Player:BuffP(S.Serenity) then
    if HR.Cast(S.TigerPalm) then return "Cast Tiger Palm"; end
  end
	-- actions.st+=/chi_burst,if=chi.max-chi>=3&energy.time_to_max>1&!talent.serenity.enabled
  if S.ChiBurst:IsReadyP() and Player:ChiDeficit() >= 3 and 
  Player:EnergyTimeToMaxPredicted() > 1 and not Player:BuffP(S.Serenity) then
		if HR.Cast(S.ChiBurst) then return "Chi Burst"; end
	end
		
	-- downtime energy pooling
  if HR.Cast(S.PoolEnergy) then return "Pool Energy"; end
  return false;
end

-- Storm Earth And Fire
local function sef ()
  -- actions.sef=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1
  if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir)
  and Player:EnergyTimeToMaxPredicted() <= 0 and Player:Chi() < 1 then
      if HR.Cast(S.TigerPalm) then return "Cast Tiger Palm"; end
    end
  -- actions.cd=invoke_xuen_the_white_tiger
  if HR.CDsON() and S.InvokeXuentheWhiteTiger:IsReadyP() then
    if HR.Cast(S.InvokeXuentheWhiteTiger) then return "Cast Invoke Xuen the White Tiger"; end
  end
  -- actions.cd+=/blood_fury
  if HR.CDsON() and S.BloodFury:IsReadyP() then
    if HR.CastSuggested(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
  end
  -- actions.cd+=/berserking
  if HR.CDsON() and S.Berserking:IsReadyP() then
    if HR.CastSuggested(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
  end
  -- actions.sef+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
  if S.ArcaneTorrent:IsReadyP() and Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() > 0.5 then
    if HR.CastSuggested(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
  end
  -- actions.cd+=/fireblood
  if HR.CDsON() and S.Fireblood:IsReadyP() then
    if HR.CastSuggested(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood"; end
  end
  -- actions.cd+=/ancestral_call
  if HR.CDsON() and S.AncestralCall:IsReadyP() then
    if HR.CastSuggested(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call"; end
  end
  -- actions.cd+=/touch_of_death
	if HR.CDsON() and S.TouchOfDeath:IsReadyP() and Target:TimeToDie() >= 9 then
	  if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return "Cast Touch of Death"; end
	end
  -- actions.sef+=/storm_earth_and_fire,if=!buff.storm_earth_and_fire.up
  if HR.CDsON() and not Player:BuffP(S.StormEarthAndFire) then
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "Cast Storm, Earth and Fire"; end
  end
  -- HR.AoEON()
  -- Cache.EnemiesCount[10] >= 3
  -- actions.sef+=/call_action_list,name=st
  ShouldReturn = single_target ();
  if ShouldReturn then return ShouldReturn; end
  return false;
end

-- Serenity
local function serenity ()
  -- actions.serenity=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1&!buff.serenity.up
  if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir)
  and Player:EnergyPredicted() >= Player:EnergyMax() and Player:Chi() < 1 and not Player:BuffP(S.Serenity) then
    if HR.Cast(S.TigerPalm) then return "Cast Tiger Palm"; end
  end
  -- actions.cd=invoke_xuen_the_white_tiger
  if HR.CDsON() and S.InvokeXuentheWhiteTiger:IsReadyP() then
    if HR.Cast(S.InvokeXuentheWhiteTiger) then return "Cast Invoke Xuen the White Tiger"; end
  end
  -- actions.cd+=/blood_fury
  if HR.CDsON() and S.BloodFury:IsReadyP() then
    if HR.CastSuggested(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
  end
  -- actions.cd+=/berserking
  if HR.CDsON() and S.Berserking:IsReadyP() then
    if HR.CastSuggested(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
  end
  -- actions.sef+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
  if S.ArcaneTorrent:IsReadyP() and Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() > 0.5 then
    if HR.CastSuggested(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
  end
  -- actions.cd+=/fireblood
  if HR.CDsON() and S.Fireblood:IsReadyP() then
    if HR.CastSuggested(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood"; end
  end
  -- actions.cd+=/ancestral_call
  if HR.CDsON() and S.AncestralCall:IsReadyP() then
    if HR.CastSuggested(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call"; end
  end
  -- actions.cd+=/touch_of_death
	if HR.CDsON() and S.TouchOfDeath:IsReadyP() and Target:TimeToDie() >= 9 then
	  if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return "Cast Touch of Death"; end
  end
  -- actions.serenity+=/rushing_jade_wind,if=talent.rushing_jade_wind.enabled&!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down
  if S.RushingJadeWind:IsReadyP() and not Player:PrevGCD(1, S.RushingJadeWind) and Player:BuffDownP(S.RushingJadeWind) then
    if HR.Cast(S.RushingJadeWind) then return "Cast Rushing Jade Wind"; end
  end
  -- actions.serenity+=/serenity,if=cooldown.rising_sun_kick.remains<=2&cooldown.fists_of_fury.remains<=4
  if HR.CDsON() and S.Serenity:IsReadyP() and S.RisingSunKick:CooldownRemainsP() <= 2 and S.FistsOfFury:CooldownRemainsP() <= 4 then
    if HR.Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "Cast Serenity"; end
  end
  -- actions.serenity+=/fists_of_fury,if=prev_gcd.1.rising_sun_kick&prev_gcd.2.serenity
  if S.FistsOfFury:IsReadyP() and Player:PrevGCD(1,S.RisingSunKick) and Player:PrevGCD(2,S.Serenity) then
    if HR.Cast(S.FistsOfFury) then return "Cast Fists of Fury"; end
  end
  -- actions.serenity+=/fists_of_fury,if=buff.serenity.remains<=1.05
  if S.FistsOfFury:IsReadyP() and Player:BuffRemainsP(S.Serenity) <= 1.05 then
    if HR.Cast(S.FistsOfFury) then return "Cast Fists of Fury"; end
  end
  -- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
  if S.RisingSunKick:IsReadyP() then
    if HR.Cast(S.RisingSunKick) then return "Cast Rising Sun Kick"; end
  end
  --actions.serenity+=/fist_of_the_white_tiger,if=prev_gcd.1.blackout_kick&prev_gcd.2.rising_sun_kick&chi.max-chi>2
  if S.FistOfTheWhiteTiger:IsReadyP() and Player:PrevGCD(1, S.BlackoutKick) and Player:PrevGCD(2, S.RisingSunKick) and Player:ChiDeficit() > 2 then
    if HR.Cast(S.FistOfTheWhiteTiger) then return "Cast Fist of the White Tiger"; end
  end
  -- actions.serenity+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=prev_gcd.1.blackout_kick&prev_gcd.2.rising_sun_kick&chi.max-chi>1
  if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.BlackoutKick) and Player:PrevGCD(2, S.RisingSunKick) and Player:ChiDeficit() > 1 then
    if HR.Cast(S.TigerPalm) then return "Cast Tiger Palm"; end
  end
  -- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&cooldown.rising_sun_kick.remains>=2&cooldown.fists_of_fury.remains>=2
  if S.BlackoutKick:IsReadyP() and not Player:PrevGCD(1, S.BlackoutKick) and S.RisingSunKick:CooldownRemainsP() >= 2 and S.FistsOfFury:CooldownRemainsP() >= 2 then
    if HR.Cast(S.BlackoutKick) then return "Cast Blackout Kick"; end
  end
  -- actions.serenity+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
  if S.SpinningCraneKick:IsReadyP() and Cache.EnemiesCount[8] >= 3 and not Player:PrevGCD(1, S.SpinningCraneKick) then
    if HR.Cast(S.SpinningCraneKick) then return "Spinning Crane Kick"; end
  end
  -- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
  if S.RisingSunKick:IsReadyP() then
    if HR.Cast(S.RisingSunKick) then return "Cast Rising Sun Kick"; end
  end
  -- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick
  if S.SpinningCraneKick:IsReadyP() and not Player:PrevGCD(1, S.SpinningCraneKick) then
    if HR.Cast(S.SpinningCraneKick) then return "Spinning Crane Kick"; end
  end
  -- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick
  if S.BlackoutKick:IsReadyP() and not Player:PrevGCD(1, S.BlackoutKick) then
    if HR.Cast(S.BlackoutKick) then return "Cast Blackout Kick"; end
  end
  return false;
end

-- Serenity Opener
-- actions.serenity_opener=tiger_palm,cycle_targets=1,if=!prev_gcd.1.tiger_palm&energy=energy.max&chi<1&!buff.serenity.up&cooldown.fists_of_fury.remains<=0
-- actions.serenity_opener+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.serenity_opener+=/call_action_list,name=cd,if=cooldown.fists_of_fury.remains>1
-- actions.serenity_opener+=/serenity,if=cooldown.fists_of_fury.remains>1
-- actions.serenity_opener+=/rising_sun_kick,cycle_targets=1,if=active_enemies<3&buff.serenity.up
-- actions.serenity_opener+=/strike_of_the_windlord,if=buff.serenity.up
-- actions.serenity_opener+=/blackout_kick,cycle_targets=1,if=(!prev_gcd.1.blackout_kick)&(prev_gcd.1.strike_of_the_windlord)
-- actions.serenity_opener+=/fists_of_fury,if=cooldown.rising_sun_kick.remains>1|buff.serenity.down,interrupt=1
-- actions.serenity_opener+=/blackout_kick,cycle_targets=1,if=buff.serenity.down&chi<=2&cooldown.serenity.remains<=0&prev_gcd.1.tiger_palm
-- actions.serenity_opener+=/tiger_palm,cycle_targets=1,if=chi=1

--- ======= MAIN =======
-- APL Main
local function APL ()
  -- Unit Update
  HL.GetEnemies(5);
  HL.GetEnemies(8);
  Everyone.AoEToggleEnemiesUpdate();
	-- Out of Combat
	if not Player:AffectingCombat() then
		if Everyone.TargetIsValid() then
			-- actions.st+=/chi_wave
			if S.ChiWave:IsReadyP() then
	      if HR.Cast(S.ChiWave) then return ""; end
	    end
	    -- actions.st+=/chi_burst
	    if S.ChiBurst:IsReadyP() then
	      if HR.Cast(S.ChiBurst) then return ""; end
	    end
			if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) then
	      if HR.Cast(S.TigerPalm) then return ""; end
	    end
		end
		return;
	end

	-- In Combat
	if Everyone.TargetIsValid() then
		-- actions.st+=/chi_wave
		if S.ChiWave:IsReadyP() then
			if HR.Cast(S.ChiWave) then return ""; end
		end
		-- actions.st+=/chi_burst
		if S.ChiBurst:IsReadyP() then
			if HR.Cast(S.ChiBurst) then return ""; end
		end
		-- -- actions+=/call_action_list,name=serenity,if=(talent.serenity.enabled&cooldown.serenity.remains<=0)|buff.serenity.up
		if (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() <= 0) or Player:BuffP(S.Serenity) then
		  ShouldReturn = serenity();
		  if ShouldReturn then return ShouldReturn; end
		end
		-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&(buff.storm_earth_and_fire.up|cooldown.storm_earth_and_fire.charges=2)
		if not S.Serenity:IsAvailable() and (Player:BuffP(S.StormEarthAndFire) or S.StormEarthAndFire:Charges() == 2) then
			ShouldReturn = sef();
			if ShouldReturn then return ShouldReturn; end
		end
		-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&equipped.drinking_horn_cover&
		-- (cooldown.strike_of_the_windlord.remains<=18&cooldown.fists_of_fury.remains<=12&chi>=3&cooldown.rising_sun_kick.remains<=1|target.time_to_die<=25|cooldown.touch_of_death.remains>112)&
		-- cooldown.storm_earth_and_fire.charges=1
		if not S.Serenity:IsAvailable() and I.DrinkingHornCover:IsEquipped() and
		(S.StrikeOfTheWindlord:CooldownRemainsP() <= 18 and S.FistsOfFury:CooldownRemainsP() <= 12 and Player:Chi() >= 3 and S.RisingSunKick:CooldownRemainsP() <= 1 or
		Target:TimeToDie() <= 25 or S.TouchOfDeath:CooldownRemainsP() > 112) and S.StormEarthAndFire:Charges() == 1 then
			ShouldReturn = sef();
			if ShouldReturn then return ShouldReturn; end
		end
		-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&!equipped.drinking_horn_cover&(cooldown.strike_of_the_windlord.remains<=14&
		-- cooldown.fists_of_fury.remains<=6&chi>=3&cooldown.rising_sun_kick.remains<=1|target.time_to_die<=15|cooldown.touch_of_death.remains>112)&cooldown.storm_earth_and_fire.charges=1
		if not S.Serenity:IsAvailable() and not I.DrinkingHornCover:IsEquipped() and
		(S.StrikeOfTheWindlord:CooldownRemainsP() <= 14 and S.FistsOfFury:CooldownRemainsP() <= 6 and Player:Chi() >= 3 and S.RisingSunKick:CooldownRemainsP() <= 1 or
		Target:TimeToDie() <= 15 or S.TouchOfDeath:CooldownRemainsP() > 112) and S.StormEarthAndFire:Charges() == 1 then
			ShouldReturn = sef();
			if ShouldReturn then return ShouldReturn; end
		end
		-- actions+=/call_action_list,name=st
		ShouldReturn = single_target ();
		if ShouldReturn then return ShouldReturn; end
		return;
	end
end

HR.SetAPL(269, APL);

-- SimulationCraft APL, taken 2018-08-26
--
-- actions=auto_attack
-- actions+=/spear_hand_strike,if=target.debuff.casting.react
-- actions+=/touch_of_karma,interval=90,pct_health=0.5,if=!talent.Good_Karma.enabled,interval=90,pct_health=0.5
-- actions+=/touch_of_karma,interval=90,pct_health=1.0,if=talent.good_karma.enabled&buff.bloodlust.down&time>1
-- actions+=/touch_of_karma,interval=90,pct_health=1.0,if=talent.good_karma.enabled&prev_gcd.1.touch_of_death&buff.bloodlust.up
-- actions+=/potion,if=buff.serenity.up|buff.storm_earth_and_fire.up|(!talent.serenity.enabled&trinket.proc.agility.react)|buff.bloodlust.react|target.time_to_die<=60
-- actions+=/touch_of_death,if=target.time_to_die<=9
-- actions+=/call_action_list,name=serenitySR,if=((talent.serenity.enabled&cooldown.serenity.remains<=0)|buff.serenity.up)&azerite.swift_roundhouse.enabled&time>30
-- actions+=/call_action_list,name=serenity,if=((!azerite.swift_roundhouse.enabled&talent.serenity.enabled&cooldown.serenity.remains<=0)|buff.serenity.up)&time>30
-- actions+=/call_action_list,name=serenity_openerSR,if=(talent.serenity.enabled&cooldown.serenity.remains<=0|buff.serenity.up)&time<30&azerite.swift_roundhouse.enabled
-- actions+=/call_action_list,name=serenity_opener,if=(!azerite.swift_roundhouse.enabled&talent.serenity.enabled&cooldown.serenity.remains<=0|buff.serenity.up)&time<30
-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&(buff.storm_earth_and_fire.up|cooldown.storm_earth_and_fire.charges=2)
-- actions+=/call_action_list,name=sef,if=(!talent.serenity.enabled&cooldown.fists_of_fury.remains<=12&chi>=3&cooldown.rising_sun_kick.remains<=1)|target.time_to_die<=25|cooldown.touch_of_death.remains>112
-- actions+=/call_action_list,name=sef,if=(!talent.serenity.enabled&!equipped.drinking_horn_cover&cooldown.fists_of_fury.remains<=6&chi>=3&cooldown.rising_sun_kick.remains<=1)|target.time_to_die<=15|cooldown.touch_of_death.remains>112&cooldown.storm_earth_and_fire.charges=1
-- actions+=/call_action_list,name=sef,if=(!talent.serenity.enabled&cooldown.fists_of_fury.remains<=12&chi>=3&cooldown.rising_sun_kick.remains<=1)|target.time_to_die<=25|cooldown.touch_of_death.remains>112&cooldown.storm_earth_and_fire.charges=1
-- actions+=/call_action_list,name=aoe,if=active_enemies>3
-- actions+=/call_action_list,name=st,if=active_enemies<=3

-- actions.aoe=call_action_list,name=cd
-- actions.aoe+=/energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&(cooldown.rising_sun_kick.remains=0|(talent.fist_of_the_white_tiger.enabled&cooldown.fist_of_the_white_tiger.remains=0)|energy<50)
-- actions.aoe+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.aoe+=/fists_of_fury,if=talent.serenity.enabled&!equipped.drinking_horn_cover&cooldown.serenity.remains>=5&energy.time_to_max>2
-- actions.aoe+=/fists_of_fury,if=talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.serenity.remains>=15|cooldown.serenity.remains<=4)&energy.time_to_max>2
-- actions.aoe+=/fists_of_fury,if=!talent.serenity.enabled&energy.time_to_max>2
-- actions.aoe+=/fists_of_fury,if=cooldown.rising_sun_kick.remains>=3.5&chi<=5
-- actions.aoe+=/whirling_dragon_punch
-- actions.aoe+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch.enabled&cooldown.whirling_dragon_punch.remains<gcd)&!prev_gcd.1.rising_sun_kick&cooldown.fists_of_fury.remains>gcd
-- actions.aoe+=/chi_burst,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
-- actions.aoe+=/chi_burst
-- actions.aoe+=/spinning_crane_kick,if=(active_enemies>=3|(buff.bok_proc.up&chi.max-chi>=0))&!prev_gcd.1.spinning_crane_kick&set_bonus.tier21_4pc
-- actions.aoe+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick&cooldown.fists_of_fury.remains>gcd
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&(!set_bonus.tier19_2pc|talent.serenity.enabled)
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(chi>1|buff.bok_proc.up|(talent.energizing_elixir.enabled&cooldown.energizing_elixir.remains<cooldown.fists_of_fury.remains))&((cooldown.rising_sun_kick.remains>1&(!talent.fist_of_the_white_tiger.enabled|cooldown.fist_of_the_white_tiger.remains>1)|chi>4)&(cooldown.fists_of_fury.remains>1|chi>2)|prev_gcd.1.tiger_palm)&!prev_gcd.1.blackout_kick
-- actions.aoe+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
-- actions.aoe+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&buff.bok_proc.up
-- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&(chi.max-chi>=2|energy.time_to_max<3)
-- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy.time_to_max<=1&chi.max-chi>=2
-- actions.aoe+=/chi_wave,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
-- actions.aoe+=/chi_wave

-- actions.cd=invoke_xuen_the_white_tiger
-- actions.cd+=/use_item,name=lustrous_golden_plumage
-- actions.cd+=/blood_fury
-- actions.cd+=/berserking
-- actions.cd+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.cd+=/lights_judgment
-- actions.cd+=/fireblood
-- actions.cd+=/ancestral_call
-- actions.cd+=/touch_of_death

-- actions.sef=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1
-- actions.sef+=/call_action_list,name=cd
-- actions.sef+=/storm_earth_and_fire,if=!buff.storm_earth_and_fire.up
-- actions.sef+=/call_action_list,name=aoe,if=active_enemies>3
-- actions.sef+=/call_action_list,name=st,if=active_enemies<=3

-- actions.serenity=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1&!buff.serenity.up
-- actions.serenity+=/call_action_list,name=cd
-- actions.serenity+=/rushing_jade_wind,if=talent.rushing_jade_wind.enabled&!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down
-- actions.serenity+=/serenity,if=cooldown.rising_sun_kick.remains<=2&cooldown.fists_of_fury.remains<=4
-- actions.serenity+=/fists_of_fury,if=prev_gcd.1.rising_sun_kick&prev_gcd.2.serenity
-- actions.serenity+=/fists_of_fury,if=buff.serenity.remains<=1.05
-- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
-- actions.serenity+=/fist_of_the_white_tiger,if=prev_gcd.1.blackout_kick&prev_gcd.2.rising_sun_kick&chi.max-chi>2
-- actions.serenity+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=prev_gcd.1.blackout_kick&prev_gcd.2.rising_sun_kick&chi.max-chi>1
-- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&cooldown.rising_sun_kick.remains>=2&cooldown.fists_of_fury.remains>=2
-- actions.serenity+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
-- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
-- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick
-- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick

-- actions.serenitySR=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1&!buff.serenity.up
-- actions.serenitySR+=/call_action_list,name=cd
-- actions.serenitySR+=/serenity,if=cooldown.rising_sun_kick.remains<=2
-- actions.serenitySR+=/fists_of_fury,if=buff.serenity.remains<=1.05
-- actions.serenitySR+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
-- actions.serenitySR+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&cooldown.rising_sun_kick.remains>=2&cooldown.fists_of_fury.remains>=2
-- actions.serenitySR+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains

-- actions.serenity_opener=fist_of_the_white_tiger,if=buff.serenity.down
-- actions.serenity_opener+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&buff.serenity.down&chi<4
-- actions.serenity_opener+=/call_action_list,name=cd,if=buff.serenity.down
-- actions.serenity_opener+=/call_action_list,name=serenity,if=buff.bloodlust.down
-- actions.serenity_opener+=/serenity
-- actions.serenity_opener+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
-- actions.serenity_opener+=/fists_of_fury,if=prev_gcd.1.rising_sun_kick&prev_gcd.2.serenity
-- actions.serenity_opener+=/fists_of_fury,if=prev_gcd.1.rising_sun_kick&prev_gcd.2.blackout_kick
-- actions.serenity_opener+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&cooldown.rising_sun_kick.remains>=2&cooldown.fists_of_fury.remains>=2
-- actions.serenity_opener+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick

-- actions.serenity_openerSR=fist_of_the_white_tiger,if=buff.serenity.down
-- actions.serenity_openerSR+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=buff.serenity.down&chi<4
-- actions.serenity_openerSR+=/call_action_list,name=cd,if=buff.serenity.down
-- actions.serenity_openerSR+=/call_action_list,name=serenity,if=buff.bloodlust.down
-- actions.serenity_openerSR+=/serenity
-- actions.serenity_openerSR+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
-- actions.serenity_openerSR+=/fists_of_fury,if=buff.serenity.remains<1
-- actions.serenity_openerSR+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&cooldown.rising_sun_kick.remains>=2&cooldown.fists_of_fury.remains>=2
-- actions.serenity_openerSR+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains

-- actions.st=invoke_xuen_the_white_tiger
-- actions.st+=/touch_of_death
-- actions.st+=/storm_earth_and_fire,if=!buff.storm_earth_and_fire.up
-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=azerite.swift_roundhouse.enabled&buff.swift_roundhouse.stack=2
-- actions.st+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&!prev_gcd.1.rushing_jade_wind
-- actions.st+=/energizing_elixir,if=!prev_gcd.1.tiger_palm
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&buff.bok_proc.up
-- actions.st+=/fist_of_the_white_tiger,if=(chi<=2)
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi<=3&energy.time_to_max<2
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi.max-chi>=2&buff.serenity.down&cooldown.fist_of_the_white_tiger.remains>energy.time_to_max
-- actions.st+=/whirling_dragon_punch
-- actions.st+=/fists_of_fury,if=chi>=3&energy.time_to_max>2.5&azerite.swift_roundhouse.rank<3
-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=((chi>=3&energy>=40)|chi>=5)&(talent.serenity.enabled|cooldown.serenity.remains>=6)&!azerite.swift_roundhouse.enabled
-- actions.st+=/fists_of_fury,if=!talent.serenity.enabled&(azerite.swift_roundhouse.rank<3|cooldown.whirling_dragon_punch.remains<13)
-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>=5|(!talent.serenity.enabled)&!azerite.swift_roundhouse.enabled
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.fists_of_fury.remains>2&!prev_gcd.1.blackout_kick&energy.time_to_max>1&azerite.swift_roundhouse.rank>2
-- actions.st+=/flying_serpent_kick,if=prev_gcd.1.blackout_kick&energy.time_to_max>2&chi>1,interrupt=1
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.swift_roundhouse.stack<2&!prev_gcd.1.blackout_kick
-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick
-- actions.st+=/chi_wave
-- actions.st+=/chi_burst,if=energy.time_to_max>1&talent.serenity.enabled
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&(chi.max-chi>=2|energy.time_to_max<3)&!buff.serenity.up
-- actions.st+=/chi_burst,if=chi.max-chi>=3&energy.time_to_max>1&!talent.serenity.enabled

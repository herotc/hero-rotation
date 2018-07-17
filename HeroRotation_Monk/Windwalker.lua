----- ============================ HEADER ============================
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
  InvokeXuentheWhiteTiger          = Spell(123904),
  RushingJadeWind                  = Spell(116847),
  HitCombo                         = Spell(196741),
  Serenity                         = Spell(152173),
  WhirlingDragonPunch              = Spell(152175),
  ChiBurst                         = Spell(123986),

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
  [S.FistsOfFury] = (I.KatsuosEclipse:IsEquipped() and 2 or 3),
  [S.SpinningCraneKick] = 3,
  [S.RushingJadeWind] = 1
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
  return self:IsReady();
end

-- Action Lists --
local function single_target ()
	-- actions.st=call_action_list,name=cd
	-- actions.st+=/energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&(cooldown.rising_sun_kick.remains=0|(artifact.strike_of_the_windlord.enabled&cooldown.strike_of_the_windlord.remains=0)|energy<50)
	if S.EnergizingElixir:Ready() and not Player:PrevGCD(1, S.TigerPalm) and Player:Chi() <= 1 and Player:EnergyDeficitPredicted() >= 20 and
	(S.RisingSunKick:CooldownRemainsP() == 0 or (S.StrikeOfTheWindlord:IsAvailable() and S.StrikeOfTheWindlord:CooldownRemainsP() == 0)) then
		if HR.Cast(S.EnergizingElixir) then return ""; end
	end
	-- actions.st+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
  if S.ArcaneTorrent:Ready() and Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() >= 0.5 then
    if HR.CastSuggested(S.ArcaneTorrent) then return ""; end
  end
  -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&buff.bok_proc.up
  if S.BlackoutKick:IsReady()
    and (
      not Player:PrevGCD(1, S.BlackoutKick)
      and Player:ChiDeficit() >= 1
      and HL.Tier21_4Pc
      and Player:BuffP(S.BlackoutKickBuff)
    ) then
    if HR.Cast(S.BlackoutKick) then return ""; end
  end
	-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy.time_to_max<=1&chi.max-chi>=2
  if S.TigerPalm:Ready(2) and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir) and 
  Player:EnergyTimeToMaxPredicted() <= 1 and Player:ChiDeficit() >= 2 then
    if HR.Cast(S.TigerPalm) then return ""; end
  end

  -- actions.st+=/strike_of_the_windlord,if=!talent.serenity.enabled|cooldown.serenity.remains>=10
	if S.StrikeOfTheWindlord:IsReady() and (not S.Serenity:IsAvailable() or (S.Serenity:CooldownRemainsP() >= 10)) then
	  if HR.Cast(S.StrikeOfTheWindlord) then return ""; end
	end
	-- actions.st+=/whirling_dragon_punch
	if S.WhirlingDragonPunch:Ready() then
    if HR.Cast(S.WhirlingDragonPunch) then return ""; end
  end
	-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=((chi>=3&energy>=40)|chi>=5)&(!talent.serenity.enabled|cooldown.serenity.remains>=6)
	if S.RisingSunKick:IsReady() and ((Player:Chi() >= 3 and Player:EnergyPredicted() >= 40) or Player:Chi() == 5) and
	(not S.Serenity:IsAvailable() or S.Serenity:CooldownRemainsP() >= 6) then
	  if HR.Cast(S.RisingSunKick) then return ""; end
	end
	-- actions.st+=/fists_of_fury,if=talent.serenity.enabled&!equipped.drinking_horn_cover&cooldown.serenity.remains>=5&energy.time_to_max>2
	if S.FistsOfFury:IsReady() and S.Serenity:IsAvailable() and not I.DrinkingHornCover:IsEquipped() and
	S.Serenity:CooldownRemainsP() >= 5 and Player:EnergyTimeToMaxPredicted() > 2 then
	  if HR.Cast(S.FistsOfFury) then return ""; end
	end
	-- actions.st+=/fists_of_fury,if=talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.serenity.remains>=15|cooldown.serenity.remains<=4)&energy.time_to_max>2
	if S.FistsOfFury:IsReady() and S.Serenity:IsAvailable() and I.DrinkingHornCover:IsEquipped() and
	(S.Serenity:CooldownRemainsP() >= 15 or S.Serenity:CooldownRemainsP() <= 4) and Player:EnergyTimeToMaxPredicted() > 2 then
	  if HR.Cast(S.FistsOfFury) then return ""; end
	end
	-- actions.st+=/fists_of_fury,if=!talent.serenity.enabled&energy.time_to_max>2
	if S.FistsOfFury:IsReady() and not S.Serenity:IsAvailable() and Player:EnergyTimeToMaxPredicted() > 2 then
	  if HR.Cast(S.FistsOfFury) then return ""; end
	end
	-- actions.st+=/fists_of_fury,if=cooldown.rising_sun_kick.remains>=3.5&chi<=5
	if S.FistsOfFury:IsReady() and S.RisingSunKick:CooldownRemainsP() >= 3.5 and Player:Chi() <= 5 then
	  if HR.Cast(S.FistsOfFury) then return ""; end
	end
	-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!talent.serenity.enabled|cooldown.serenity.remains>=5
	if S.RisingSunKick:IsReady() and (not S.Serenity:IsAvailable() or (S.Serenity:CooldownRemainsP() >= 5)) then
	  if HR.Cast(S.RisingSunKick) then return ""; end
	end
  -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&(!set_bonus.tier19_2pc|talent.serenity.enabled)
  if S.BlackoutKick:IsReady()
    and (
      not Player:PrevGCD(1, S.BlackoutKick)
      and Player:ChiDeficit() >= 1
      and HL.Tier21_4Pc
      and (
        not HL.tier19_2pc
        or S.Serenity:IsAvailable()
      )
    ) then
    if HR.Cast(S.BlackoutKick) then return ""; end
  end
  -- actions.st+=/spinning_crane_kick,if=(active_enemies>=3|(buff.bok_proc.up&chi=chi.max))&!prev_gcd.1.spinning_crane_kick&set_bonus.tier21_4pc
  if S.SpinningCraneKick:IsReady()
    and (
      ( Cache.EnemiesCount[8] >= 3
        or (
          Player:BuffP(S.BlackoutKickBuff)
          and Player:ChiDeficit() >= 0
        )
      )
      and not Player:PrevGCD(1, S.SpinningCraneKick)
      and HL.Tier21_4Pc
    ) then
      if HR.Cast(S.SpinningCraneKick) then return ""; end
  end
	-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
	if S.CracklingJadeLightning:IsReady() and I.TheEmperorsCapacitor:IsEquipped() and
	Player:BuffStack(S.TheEmperorsCapacitor) >= 19 and Player:EnergyTimeToMaxPredicted() > 3 then
	  if HR.Cast(S.CracklingJadeLightning) then return ""; end
	end
	-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
	if S.CracklingJadeLightning:IsReady() and I.TheEmperorsCapacitor:IsEquipped() and Player:BuffStack(S.TheEmperorsCapacitor) >= 14 and
	S.Serenity:CooldownRemainsP() < 13 and S.Serenity:IsAvailable() and Player:EnergyTimeToMaxPredicted() > 3 then
	  if HR.Cast(S.CracklingJadeLightning) then return ""; end
	end
	-- actions.st+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
	if S.SpinningCraneKick:IsReady() and Cache.EnemiesCount[8] >= 3 and GetSpellCount("Spinning Crane Kick") >= 2 and
	not Player:PrevGCD(1, S.SpinningCraneKick) then
	  if HR.Cast(S.SpinningCraneKick) then return ""; end
	end
	-- actions.st+=/rushing_jade_wind,if=chi.max-chi>1&!prev_gcd.1.rushing_jade_wind
	if S.RushingJadeWind:IsReady() and Player:ChiDeficit() > 1 and not Player:PrevGCD(1, S.RushingJadeWind) then
	  if HR.Cast(S.RushingJadeWind) then return ""; end
	end
	-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(chi>1|buff.bok_proc.up|(talent.energizing_elixir.enabled&cooldown.energizing_elixir.remains<cooldown.fists_of_fury.remains))&
  -- ((cooldown.rising_sun_kick.remains>=1.5&(!artifact.strike_of_the_windlord.enabled|cooldown.strike_of_the_windlord.remains>1)|chi>4)&
  -- cooldown.fists_of_fury.remains>=1.5|prev_gcd.1.tiger_palm)&!prev_gcd.1.blackout_kick
	if S.BlackoutKick:IsReady() and (Player:Chi() > 1 or Player:BuffP(S.BlackoutKickBuff) or
	(S.EnergizingElixir:IsAvailable() and S.EnergizingElixir:CooldownRemainsP() < S.FistsOfFury:CooldownRemainsP())) and
	((S.RisingSunKick:CooldownRemainsP() >= 1.5 and (not S.StrikeOfTheWindlord:IsAvailable() or S.StrikeOfTheWindlord:CooldownRemainsP() > 1) or Player:Chi() > 4) and
	S.FistsOfFury:CooldownRemainsP() >= 1.5 or Player:PrevGCD(1, S.TigerPalm)) and not Player:PrevGCD(1, S.BlackoutKick) then
	  if HR.Cast(S.BlackoutKick) then return ""; end
	end
  -- actions.st+=/chi_wave,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
	if S.ChiWave:IsReady() and Player:Chi() <= 3 and 
  (S.RisingSunKick:CooldownRemainsP() >= 5 or S.WhirlingDragonPunch:CooldownRemainsP() >= 5) then
		if HR.Cast(S.ChiWave) then return ""; end
	end
	-- actions.st+=/chi_burst,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
	if S.ChiBurst:IsReady() and Player:Chi() <= 3 and 
  (S.RisingSunKick:CooldownRemainsP() >= 5 or S.WhirlingDragonPunch:CooldownRemainsP() >= 5) then
		if HR.Cast(S.ChiBurst) then return ""; end
	end
  -- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&(chi.max-chi>=2|energy.time_to_max<3)
  if S.TigerPalm:Ready(2) and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir) and 
  (Player:EnergyTimeToMaxPredicted() < 3 or Player:ChiDeficit() >= 2) then
    if HR.Cast(S.TigerPalm) then return ""; end
  end
		
	-- downtime energy pooling
  if HR.Cast(S.PoolEnergy) then return "Pool Energy"; end
  return false;
end

-- Storm Earth And Fire
local function sef ()
  -- actions.sef=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1
  if S.TigerPalm:Ready(2) and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir)
  and Player:EnergyTimeToMaxPredicted() <= 0 and Player:Chi() < 1 then
      if HR.Cast(S.TigerPalm) then return ""; end
    end
  -- actions.sef+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
  if S.ArcaneTorrent:Ready() and Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() > 0.5 then
    if HR.CastSuggested(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- actions.sef+=/storm_earth_and_fire,if=!buff.storm_earth_and_fire.up
  if HR.CDsON() and not Player:BuffP(S.StormEarthAndFire) then
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return ""; end
  end
  -- actions.sef+=/call_action_list,name=st
  ShouldReturn = single_target ();
  if ShouldReturn then return ShouldReturn; end
  return false;
end

-- Serenity
local function serenity ()
  -- actions.serenity=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1&!buff.serenity.up
  if S.TigerPalm:Ready(2) and not Player:PrevGCD(1, S.TigerPalm) and not Player:PrevGCD(1, S.EnergizingElixir)
  and Player:EnergyPredicted() >= Player:EnergyMax() and Player:Chi() < 1 and not Player:BuffP(S.Serenity) then
    if HR.Cast(S.TigerPalm) then return ""; end
  end
  -- actions.serenity+=/serenity
  if HR.CDsON() and S.Serenity:IsReady() then
    if HR.Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return ""; end
  end
  -- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies<3
  if S.RisingSunKick:IsReady() and Cache.EnemiesCount[8] < 3 then
    if HR.Cast(S.RisingSunKick) then return ""; end
  end
  -- actions.serenity+=/strike_of_the_windlord
  if S.StrikeOfTheWindlord:IsReady() then
    if HR.Cast(S.StrikeOfTheWindlord) then return ""; end
  end
  -- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(!prev_gcd.1.blackout_kick)&(prev_gcd.1.strike_of_the_windlord|prev_gcd.1.fists_of_fury)&active_enemies<2
  if S.BlackoutKick:IsReady() and not Player:PrevGCD(1, S.BlackoutKick) and (Player:PrevGCD(1,S.StrikeOfTheWindlord) or Player:PrevGCD(1,S.FistsOfFury)) and Cache.EnemiesCount[8] < 2 then
    if HR.Cast(S.BlackoutKick) then return ""; end
  end
  -- actions.serenity+=/fists_of_fury,if=((equipped.drinking_horn_cover&buff.pressure_point.remains<=2&set_bonus.tier20_4pc)&(cooldown.rising_sun_kick.remains>1|active_enemies>1)),interrupt=1
  if S.FistsOfFury:IsReady() and ((I.DrinkingHornCover:IsEquipped() and Player:BuffRemainsP(S.PressurePoint) <= 2 and HL.Tier20_4Pc) and (S.RisingSunKick:CooldownRemainsP() > 1 or Cache.EnemiesCount[8] > 1)) then
    if HR.Cast(S.FistsOfFury) then return ""; end
  end
  -- actions.serenity+=/fists_of_fury,if=((!equipped.drinking_horn_cover|buff.bloodlust.up|buff.serenity.remains<1)&(cooldown.rising_sun_kick.remains>1|active_enemies>1)),interrupt=1
  if S.FistsOfFury:IsReady() and ((not I.DrinkingHornCover:IsEquipped() or Player:BuffP(S.Bloodlust) or Player:BuffRemainsP(S.Serenity) < 1) and (S.RisingSunKick:CooldownRemainsP() > 1 or Cache.EnemiesCount[8] > 1)) then
    if HR.Cast(S.FistsOfFury) then return ""; end
  end
  -- actions.serenity+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
  if S.SpinningCraneKick:IsReady() and Cache.EnemiesCount[8] >= 3 and not Player:PrevGCD(1, S.SpinningCraneKick) then
    if HR.Cast(S.SpinningCraneKick) then return ""; end
  end
  -- actions.serenity+=/rushing_jade_wind,if=!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down&buff.serenity.remains>=4
  if S.RushingJadeWind:IsReady() and not Player:PrevGCD(1, S.RushingJadeWind) and Player:BuffDownP(S.RushingJadeWind) and Player:BuffRemainsP(S.Serenity) >= 4 then
    if HR.Cast(S.RushingJadeWind) then return ""; end
  end
  -- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies>=3
  if S.RisingSunKick:IsReady() and Cache.EnemiesCount[8] >= 3 then
    if HR.Cast(S.RisingSunKick) then return ""; end
  end
  -- actions.serenity+=/rushing_jade_wind,if=!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down&active_enemies>1
  if S.RushingJadeWind:IsReady() and not Player:PrevGCD(1, S.RushingJadeWind) and Player:BuffDownP(S.RushingJadeWind) and Cache.EnemiesCount[8] > 1 then
    if HR.Cast(S.RushingJadeWind) then return ""; end
  end
  -- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick
  if S.SpinningCraneKick:IsReady() and not Player:PrevGCD(1, S.SpinningCraneKick) then
    if HR.Cast(S.SpinningCraneKick) then return ""; end
  end
  -- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick
  if S.BlackoutKick:IsReady() and not Player:PrevGCD(1, S.BlackoutKick) then
    if HR.Cast(S.BlackoutKick) then return ""; end
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
			if S.ChiWave:IsReady() then
	      if HR.Cast(S.ChiWave) then return ""; end
	    end
	    -- actions.st+=/chi_burst
	    if S.ChiBurst:IsReady() then
	      if HR.Cast(S.ChiBurst) then return ""; end
	    end
			if S.TigerPalm:IsReady() and not Player:PrevGCD(1, S.TigerPalm) then
	      if HR.Cast(S.TigerPalm) then return ""; end
	    end
		end
		return;
	end

	-- In Combat
	if Everyone.TargetIsValid() then
		-- actions.st+=/chi_wave
		if S.ChiWave:IsReady() then
			if HR.Cast(S.ChiWave) then return ""; end
		end
		-- actions.st+=/chi_burst
		if S.ChiBurst:IsReady() then
			if HR.Cast(S.ChiBurst) then return ""; end
		end
		-- actions+=/touch_of_death
		if HR.CDsON() and S.TouchOfDeath:Ready() and Target:TimeToDie() >= 9 then
			if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then return ""; end
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

-- SimulationCraft APL, taken 2018-01-11
--
-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/spear_hand_strike,if=target.debuff.casting.react
-- actions+=/touch_of_karma,interval=90,pct_health=0.5
-- actions+=/potion,if=buff.serenity.up|buff.storm_earth_and_fire.up|(!talent.serenity.enabled&trinket.proc.agility.react)|buff.bloodlust.react|target.time_to_die<=60
-- actions+=/touch_of_death,if=target.time_to_die<=9
-- actions+=/call_action_list,name=serenity,if=(talent.serenity.enabled&cooldown.serenity.remains<=0)|buff.serenity.up
-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&(buff.storm_earth_and_fire.up|cooldown.storm_earth_and_fire.charges=2)
-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.strike_of_the_windlord.remains<=18&cooldown.fists_of_fury.remains<=12&chi>=3&cooldown.rising_sun_kick.remains<=1|target.time_to_die<=25|cooldown.touch_of_death.remains>112)&cooldown.storm_earth_and_fire.charges=1
-- actions+=/call_action_list,name=sef,if=!talent.serenity.enabled&!equipped.drinking_horn_cover&(cooldown.strike_of_the_windlord.remains<=14&cooldown.fists_of_fury.remains<=6&chi>=3&cooldown.rising_sun_kick.remains<=1|target.time_to_die<=15|cooldown.touch_of_death.remains>112)&cooldown.storm_earth_and_fire.charges=1
-- actions+=/call_action_list,name=aoe,if=active_enemies>3
-- actions+=/call_action_list,name=st,if=active_enemies<=3

-- actions.aoe=call_action_list,name=cd
-- actions.aoe+=/energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&(cooldown.rising_sun_kick.remains=0|(artifact.strike_of_the_windlord.enabled&cooldown.strike_of_the_windlord.remains=0)|energy<50)
-- actions.aoe+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.aoe+=/fists_of_fury,if=talent.serenity.enabled&!equipped.drinking_horn_cover&cooldown.serenity.remains>=5&energy.time_to_max>2
-- actions.aoe+=/fists_of_fury,if=talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.serenity.remains>=15|cooldown.serenity.remains<=4)&energy.time_to_max>2
-- actions.aoe+=/fists_of_fury,if=!talent.serenity.enabled&energy.time_to_max>2
-- actions.aoe+=/fists_of_fury,if=cooldown.rising_sun_kick.remains>=3.5&chi<=5
-- actions.aoe+=/whirling_dragon_punch
-- actions.aoe+=/strike_of_the_windlord,if=!talent.serenity.enabled|cooldown.serenity.remains>=10
-- actions.aoe+=/rising_sun_kick,target_if=cooldown.whirling_dragon_punch.remains>=gcd&!prev_gcd.1.rising_sun_kick&cooldown.fists_of_fury.remains>gcd
-- actions.aoe+=/rushing_jade_wind,if=chi.max-chi>1&!prev_gcd.1.rushing_jade_wind
-- actions.aoe+=/chi_burst,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
-- actions.aoe+=/chi_burst
-- actions.aoe+=/spinning_crane_kick,if=(active_enemies>=3|(buff.bok_proc.up&chi.max-chi>=0))&!prev_gcd.1.spinning_crane_kick&set_bonus.tier21_4pc
-- actions.aoe+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&(!set_bonus.tier19_2pc|talent.serenity.enabled)
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(chi>1|buff.bok_proc.up|(talent.energizing_elixir.enabled&cooldown.energizing_elixir.remains<cooldown.fists_of_fury.remains))&((cooldown.rising_sun_kick.remains>1&(!artifact.strike_of_the_windlord.enabled|cooldown.strike_of_the_windlord.remains>1)|chi>4)&(cooldown.fists_of_fury.remains>1|chi>2)|prev_gcd.1.tiger_palm)&!prev_gcd.1.blackout_kick
-- actions.aoe+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
-- actions.aoe+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&buff.bok_proc.up
-- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&(chi.max-chi>=2|energy.time_to_max<3)
-- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy.time_to_max<=1&chi.max-chi>=2
-- actions.aoe+=/chi_wave,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
-- actions.aoe+=/chi_wave

-- actions.cd=invoke_xuen_the_white_tiger
-- actions.cd+=/blood_fury
-- actions.cd+=/berserking
-- actions.cd+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.cd+=/touch_of_death,cycle_targets=1,max_cycle_targets=2,if=!artifact.gale_burst.enabled&equipped.hidden_masters_forbidden_touch&!prev_gcd.1.touch_of_death
-- actions.cd+=/touch_of_death,if=!artifact.gale_burst.enabled&!equipped.hidden_masters_forbidden_touch
-- actions.cd+=/touch_of_death,cycle_targets=1,max_cycle_targets=2,if=artifact.gale_burst.enabled&((talent.serenity.enabled&cooldown.serenity.remains<=1)|chi>=2)&(cooldown.strike_of_the_windlord.remains<8|cooldown.fists_of_fury.remains<=4)&cooldown.rising_sun_kick.remains<7&!prev_gcd.1.touch_of_death

-- actions.sef=tiger_palm,target_if=debuff.mark_of_the_crane.down,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1
-- actions.sef+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.sef+=/call_action_list,name=cd
-- actions.sef+=/storm_earth_and_fire,if=!buff.storm_earth_and_fire.up
-- actions.sef+=/call_action_list,name=aoe,if=active_enemies>3
-- actions.sef+=/call_action_list,name=st,if=active_enemies<=3

-- actions.serenity=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1&!buff.serenity.up
-- actions.serenity+=/call_action_list,name=cd
-- actions.serenity+=/serenity
-- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies<3
-- actions.serenity+=/strike_of_the_windlord
-- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(!prev_gcd.1.blackout_kick)&(prev_gcd.1.strike_of_the_windlord|prev_gcd.1.fists_of_fury)&active_enemies<2
-- actions.serenity+=/fists_of_fury,if=((equipped.drinking_horn_cover&buff.pressure_point.remains<=2&set_bonus.tier20_4pc)&(cooldown.rising_sun_kick.remains>1|active_enemies>1)),interrupt=1
-- actions.serenity+=/fists_of_fury,if=((!equipped.drinking_horn_cover|buff.bloodlust.up|buff.serenity.remains<1)&(cooldown.rising_sun_kick.remains>1|active_enemies>1)),interrupt=1
-- actions.serenity+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
-- actions.serenity+=/rushing_jade_wind,if=!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down&buff.serenity.remains>=4
-- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies>=3
-- actions.serenity+=/rushing_jade_wind,if=!prev_gcd.1.rushing_jade_wind&buff.rushing_jade_wind.down&active_enemies>1
-- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick
-- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick

-- actions.serenity_opener=tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy=energy.max&chi<1&!buff.serenity.up&cooldown.fists_of_fury.remains<=0
-- actions.serenity_opener+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.serenity_opener+=/call_action_list,name=cd,if=cooldown.fists_of_fury.remains>1
-- actions.serenity_opener+=/serenity,if=cooldown.fists_of_fury.remains>1
-- actions.serenity_opener+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies<3&buff.serenity.up
-- actions.serenity_opener+=/strike_of_the_windlord,if=buff.serenity.up
-- actions.serenity_opener+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(!prev_gcd.1.blackout_kick)&(prev_gcd.1.strike_of_the_windlord)
-- actions.serenity_opener+=/fists_of_fury,if=cooldown.rising_sun_kick.remains>1|buff.serenity.down,interrupt=1
-- actions.serenity_opener+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.serenity.down&chi<=2&cooldown.serenity.remains<=0&prev_gcd.1.tiger_palm
-- actions.serenity_opener+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&chi=1

-- actions.st=call_action_list,name=cd
-- actions.st+=/energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&(cooldown.rising_sun_kick.remains=0|(artifact.strike_of_the_windlord.enabled&cooldown.strike_of_the_windlord.remains=0)|energy<50)
-- actions.st+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&buff.bok_proc.up
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&energy.time_to_max<=1&chi.max-chi>=2
-- actions.st+=/strike_of_the_windlord,if=!talent.serenity.enabled|cooldown.serenity.remains>=10
-- actions.st+=/whirling_dragon_punch
-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=((chi>=3&energy>=40)|chi>=5)&(!talent.serenity.enabled|cooldown.serenity.remains>=6)
-- actions.st+=/fists_of_fury,if=talent.serenity.enabled&!equipped.drinking_horn_cover&cooldown.serenity.remains>=5&energy.time_to_max>2
-- actions.st+=/fists_of_fury,if=talent.serenity.enabled&equipped.drinking_horn_cover&(cooldown.serenity.remains>=15|cooldown.serenity.remains<=4)&energy.time_to_max>2
-- actions.st+=/fists_of_fury,if=!talent.serenity.enabled&energy.time_to_max>2
-- actions.st+=/fists_of_fury,if=cooldown.rising_sun_kick.remains>=3.5&chi<=5
-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!talent.serenity.enabled|cooldown.serenity.remains>=5
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&chi.max-chi>=1&set_bonus.tier21_4pc&(!set_bonus.tier19_2pc|talent.serenity.enabled)
-- actions.st+=/spinning_crane_kick,if=(active_enemies>=3|(buff.bok_proc.up&chi.max-chi>=0))&!prev_gcd.1.spinning_crane_kick&set_bonus.tier21_4pc
-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=19&energy.time_to_max>3
-- actions.st+=/crackling_jade_lightning,if=equipped.the_emperors_capacitor&buff.the_emperors_capacitor.stack>=14&cooldown.serenity.remains<13&talent.serenity.enabled&energy.time_to_max>3
-- actions.st+=/spinning_crane_kick,if=active_enemies>=3&!prev_gcd.1.spinning_crane_kick
-- actions.st+=/rushing_jade_wind,if=chi.max-chi>1&!prev_gcd.1.rushing_jade_wind
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(chi>1|buff.bok_proc.up|(talent.energizing_elixir.enabled&cooldown.energizing_elixir.remains<cooldown.fists_of_fury.remains))&((cooldown.rising_sun_kick.remains>1&(!artifact.strike_of_the_windlord.enabled|cooldown.strike_of_the_windlord.remains>1)|chi>4)&(cooldown.fists_of_fury.remains>1|chi>2)|prev_gcd.1.tiger_palm)&!prev_gcd.1.blackout_kick
-- actions.st+=/chi_wave,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
-- actions.st+=/chi_burst,if=chi<=3&(cooldown.rising_sun_kick.remains>=5|cooldown.whirling_dragon_punch.remains>=5)&energy.time_to_max>1
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&!prev_gcd.1.energizing_elixir&(chi.max-chi>=2|energy.time_to_max<3)
-- actions.st+=/chi_wave
-- actions.st+=/chi_burst

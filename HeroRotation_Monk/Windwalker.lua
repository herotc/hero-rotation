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
  RushingJadeWind                  = Spell(261715),
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
--- ======= MAIN =======
-- APL Main
local function APL ()
  local Precombat, Cooldowns, SingleTarget, Serenity, Aoe
  -- Unit Update
  HL.GetEnemies(5);
  HL.GetEnemies(8);
  Everyone.AoEToggleEnemiesUpdate();

  -- Pre Combat --
  Precombat = function()
    -- actions.precombat+=/chi_burst,if=(!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled)
    if S.ChiBurst:IsReadyP() and (not S.Serenity:IsAvailable() or not S.FistOfTheWhiteTiger:IsAvailable()) then
      if HR.Cast(S.ChiBurst) then 
        return "Cast Pre-Combat Chi Burst"; end
    end
    -- actions.precombat+=/chi_wave
    if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then 
        return "Cast Pre-Combat Chi Wave"; end
    end
  end

  -- Cooldowns --
  Cooldowns = function()
    -- actions.cd=invoke_xuen_the_white_tiger
    if HR.CDsON() and S.InvokeXuentheWhiteTiger:IsReadyP() then
      if HR.Cast(S.InvokeXuentheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger) then 
        return "Cast Cooldown Invoke Xuen the White Tiger"; end
    end
    -- actions.cd+=/blood_fury
    if HR.CDsON() and S.BloodFury:IsReadyP() then
      if HR.CastSuggested(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then 
        return "Cast Cooldown Blood Fury"; end
    end
    -- actions.cd+=/berserking
    if HR.CDsON() and S.Berserking:IsReadyP() then
      if HR.CastSuggested(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then 
        return "Cast Cooldown Berserking"; end
    end
    -- actions.cd+=/arcane_torrent,if=chi.max-chi>=1&energy.time_to_max>=0.5
    if S.ArcaneTorrent:IsReadyP() and Player:ChiDeficit() >= 1 and Player:EnergyTimeToMaxPredicted() > 0.5 then
      if HR.CastSuggested(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then 
        return "Cast Cooldown Arcane Torrent"; end
    end
    -- actions.cd+=/fireblood
    if HR.CDsON() and S.Fireblood:IsReadyP() then
      if HR.CastSuggested(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then 
        return "Cast Cooldown Fireblood"; end
    end
    -- actions.cd+=/ancestral_call
    if HR.CDsON() and S.AncestralCall:IsReadyP() then
      if HR.CastSuggested(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then 
        return "Cast Cooldown Ancestral Call"; end
    end
    -- actions.cd+=/touch_of_death,if=target.time_to_die>9
  	if HR.CDsON() and S.TouchOfDeath:IsReadyP() and Target:TimeToDie() > 9 then
      if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath) then 
        return "Cast Cooldown Touch of Death"; end
    end
    -- actions.cd+=/storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|(cooldown.fists_of_fury.remains<=6&chi>=3&cooldown.rising_sun_kick.remains<=1)|target.time_to_die<=15
    if HR.CDsON() and S.StormEarthAndFire:IsReadyP() and not Player:BuffP(S.StormEarthAndFire) and (S.StormEarthAndFire:ChargesP() == 2 or S.FistsOfFury:CooldownRemainsP() <= 6) and Player:Chi() >= 3 and (S.RisingSunKick:CooldownRemainsP() <= 1 or Target:TimeToDie() <= 15) then
      if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.GCDasOffGCD.Serenity) then 
        return "Cast Cooldown Storm, Earth and Fire"; end
    end
    -- actions.cd+=/serenity,if=cooldown.rising_sun_kick.remains<=2|target.time_to_die<=12
    if HR.CDsON() and S.Serenity:IsReadyP() and not Player:BuffP(S.Serenity) and 
      (S.RisingSunKick:CooldownRemainsP() <= 2 or Target:TimeToDie() <= 12) then
      if HR.Cast(S.Serenity, Settings.Windwalker.GCDasOffGCD.Serenity) then 
        return "Cast Cooldown Serenity"; end
    end
  end

  -- Serenity --
  Serenity = function()
    -- actions.serenity=rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
    if S.RisingSunKick:IsReadyP() then
      if HR.Cast(S.RisingSunKick) then 
        return "Cast Serenity Rising Sun Kick"; end
    end
    -- actions.serenity+=/fists_of_fury,if=(buff.bloodlust.up&prev_gcd.1.rising_sun_kick&!azerite.swift_roundhouse.enabled)|buff.serenity.remains<1|active_enemies>1
    if S.FistsOfFury:IsReadyP() and ((Player:HasHeroismP() and Player:PrevGCD(1,S.RisingSunKick) and not S.SwiftRoundhouse:AzeriteEnabled()) or Player:BuffRemainsP(S.Serenity) < 1 or Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.FistsOfFury) then 
        return "Cast Serenity Fists of Fury"; end
    end
    -- actions.serenity+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick&(active_enemies>=3|(active_enemies=2&prev_gcd.1.blackout_kick))
    if S.SpinningCraneKick:IsReadyP() and not Player:PrevGCD(1, S.SpinningCraneKick) and (Cache.EnemiesCount[8] >= 3 or (Cache.EnemiesCount[8] == 2 and Player:PrevGCD(1, S.BlackoutKick))) then
      if HR.Cast(S.SpinningCraneKick) then 
        return "Cast Serenity Spinning Crane Kick"; end
    end
    -- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains
    if S.BlackoutKick:IsReadyP() then
      if HR.Cast(S.BlackoutKick) then 
        return "Cast Serenity Blackout Kick"; end
    end
  end

  -- Area of Effect --
  Aoe = function()
  	-- actions.aoe=whirling_dragon_punch
  	if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch) then 
        return "Cast AoE Whirling Dragon Punch"; end
    end
  	-- actions.aoe+=/energizing_elixir,if=!prev_gcd.1.tiger_palm&chi<=1&energy<50
  	if S.EnergizingElixir:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and Player:Chi() <= 1 and Player:EnergyPredicted() < 50 then
      if HR.Cast(S.EnergizingElixir) then 
        return "Cast AoE Energizing Elixir"; end
	  end
    -- actions.aoe+=/fists_of_fury,if=energy.time_to_max>2.5
    if S.FistsOfFury:IsReadyP() and Player:EnergyTimeToMaxPredicted() > 2.5 then
      if HR.Cast(S.FistsOfFury) then 
        return "Cast AoE Fists of Fury"; end
    end
 	  -- actions.aoe+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&energy.time_to_max>1
     if S.RushingJadeWind:IsReadyP() and Player:BuffDownP(S.RushingJadeWind) and Player:EnergyTimeToMaxPredicted() > 1 then
      if HR.Cast(S.RushingJadeWind) then 
        return "Cast AoE Rushing Jade Wind"; end
  	end
    -- actions.aoe+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch.enabled&cooldown.whirling_dragon_punch.remains<gcd)&cooldown.fists_of_fury.remains>3
    if S.RisingSunKick:IsReadyP() and (S.WhirlingDragonPunch:IsAvailable() and S.WhirlingDragonPunch:CooldownRemainsP() > Player:GCD()) and
      S.FistsOfFury:CooldownRemainsP() > 3 then
      if HR.Cast(S.RisingSunKick) then 
        return "Cast AoE Rising Sun Kick"; end
    end
    -- actions.aoe+=/spinning_crane_kick,if=!prev_gcd.1.spinning_crane_kick&(chi>2|cooldown.fists_of_fury.remains>4)
    if S.SpinningCraneKick:IsReadyP() and (not Player:PrevGCD(1, S.SpinningCraneKick) and (Player:Chi() > 2 or S.FistsOfFury:CooldownRemainsP() > 4)) then
      if HR.Cast(S.SpinningCraneKick) then 
        return "Cast AoE Spinning Crane Kick"; end
    end
	  -- actions.aoe+=/chi_burst,if=chi<=3
	  if S.ChiBurst:IsReadyP() and Player:ChiDeficit() <= 3 then
      if HR.Cast(S.ChiBurst) then 
        return "Cast AoE Chi Burst"; end
  	end  
    -- actions.aoe+=/fist_of_the_white_tiger,if=chi.max-chi>=3&(energy>46|buff.rushing_jade_wind.down)
    if S.FistOfTheWhiteTiger:IsReadyP() and Player:ChiDeficit() >= 3 and 
      (Player:BuffDownP(S.RushingJadeWind) or Player:EnergyPredicted() > 46) then
      if HR.Cast(S.FistOfTheWhiteTiger) then 
        return "Cast AoE Fist of the White Tiger"; end
    end
    -- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi.max-chi>=2&(energy>56|buff.rushing_jade_wind.down)
    if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDownP(S.RushingJadeWind) or Player:EnergyPredicted() > 56) then
      if HR.Cast(S.TigerPalm) then 
        return "Cast AoE Tiger Palm"; end
    end
    -- actions.st+=/chi_wave
  	if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then 
        return "Cast AoE Chi Wave"; end
    end
    -- actions.aoe+=/flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
    -- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick
    if S.BlackoutKick:IsReadyP() and not Player:PrevGCD(1, S.BlackoutKick) then
      if HR.Cast(S.BlackoutKick) then 
        return "Cast AoE Blackout Kick"; end
    end
  end

  -- Single Target --
  SingleTarget = function()
 	  -- actions.st=cancel_buff,name=rushing_jade_wind,if=active_enemies=1&(!talent.serenity.enabled|cooldown.serenity.remains>3)
    if S.RushingJadeWind:IsReadyP() and Player:BuffP(S.RushingJadeWind) and Cache.EnemiesCount[5] == 1 and (not S.Serenity:IsAvailable() or S.Serenity:CooldownRemainsP() > 3) then
      if HR.Cast(S.RushingJadeWind) then 
        return "Cancel Single Target Rushing Jade Wind"; end
  	end
  	-- actions.st+=/whirling_dragon_punch
  	if S.WhirlingDragonPunch:IsReady() then
      if HR.Cast(S.WhirlingDragonPunch) then 
        return "Cast Single Target Whirling Dragon Punch"; end
    end
    -- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
    if S.RisingSunKick:IsReadyP()  then
      if HR.Cast(S.RisingSunKick) then 
        return "Cast Single Target Rising Sun Kick"; end
    end
 	  -- actions.st+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&energy.time_to_max>1&active_enemies>1
	  if S.RushingJadeWind:IsReadyP() and Player:BuffDownP(S.RushingJadeWind) and Player:EnergyTimeToMaxPredicted() > 1 and Cache.EnemiesCount[8] > 1 then
      if HR.Cast(S.RushingJadeWind) then 
        return "Cast Single Target Rushing Jade Wind"; end
  	end
    -- actions.st+=/fists_of_fury,if=energy.time_to_max>2.5&(azerite.swift_roundhouse.rank<2|(cooldown.whirling_dragon_punch.remains<10&talent.whirling_dragon_punch.enabled)|active_enemies>1)
    if S.FistsOfFury:IsReadyP() and Player:EnergyTimeToMaxPredicted() > 2.5 and
      (
        S.SwiftRoundhouse:AzeriteRank() < 2 or
        (S.WhirlingDragonPunch:IsAvailable() and S.WhirlingDragonPunch:CooldownRemainsP() < 10) or
        Cache.EnemiesCount[8] > 1
      ) then
      if HR.Cast(S.FistsOfFury) then 
        return "Cast Single Target Fists of Fury"; end
    end
    -- actions.st+=/fist_of_the_white_tiger,if=chi<=2&(buff.rushing_jade_wind.down|energy>46)
    if S.FistOfTheWhiteTiger:IsReadyP() and Player:Chi() <= 2 and 
      (Player:BuffDownP(S.RushingJadeWind) or Player:EnergyPredicted() > 46) then
      if HR.Cast(S.FistOfTheWhiteTiger) then 
        return "Cast Single Target Fist of the White Tiger"; end
    end
  	-- actions.st+=/energizing_elixir,if=chi<=3&energy<50
  	if S.EnergizingElixir:IsReadyP() and Player:Chi() <= 3 and Player:EnergyPredicted() < 50 then
      if HR.Cast(S.EnergizingElixir) then 
        return "Cast Single Target Energizing Elixir"; end
	  end
    -- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.blackout_kick&(cooldown.rising_sun_kick.remains>2|chi>=3)&(cooldown.fists_of_fury.remains>2|chi>=4|(chi=2&prev_gcd.1.tiger_palm)|(azerite.swift_roundhouse.rank>=2&active_enemies=1))&buff.swift_roundhouse.stack<2
    if S.BlackoutKick:IsReadyP()
      and (
        not Player:PrevGCD(1, S.BlackoutKick)
        and (S.RisingSunKick:CooldownRemainsP() > 2 or Player:Chi() >= 3)
        and (
          S.FistsOfFury:CooldownRemainsP() > 2 or 
          Player:Chi() >= 4 or 
          (Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm)) or
          (S.SwiftRoundhouse:AzeriteRank() >= 2 and Cache.EnemiesCount[5] == 1)
        )
        and Player:BuffStack(S.SwiftRoundhouseBuff) < 2
      ) then
      if HR.Cast(S.BlackoutKick) then 
        return "Cast Single Target Blackout Kick"; end
    end
    -- actions.st+=/chi_wave
  	if S.ChiWave:IsReadyP() then
      if HR.Cast(S.ChiWave) then 
        return "Cast Single Target Chi Wave"; end
    end
	  -- actions.st+=/chi_burst,if=chi.max-chi>=1&active_enemies=1|chi.max-chi>=2
	  if S.ChiBurst:IsReadyP() and ((Player:ChiDeficit() >= 1 and Cache.EnemiesCount[8] == 1) or Player:ChiDeficit() >= 2) then
      if HR.Cast(S.ChiBurst) then 
        return "Cast Single Target Chi Burst"; end
  	end  
    -- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!prev_gcd.1.tiger_palm&chi.max-chi>=2&(buff.rushing_jade_wind.down|energy>56)
    if S.TigerPalm:IsReadyP() and not Player:PrevGCD(1, S.TigerPalm) and Player:ChiDeficit() >= 2 and
      (Player:BuffDownP(S.RushingJadeWind) or Player:EnergyPredicted() > 56) then
      if HR.Cast(S.TigerPalm) then 
        return "Cast Single Target Tiger Palm"; end
    end
    -- actions.st+=/flying_serpent_kick,if=prev_gcd.1.blackout_kick&chi>1&buff.swift_roundhouse.stack<2,interrupt=1
	  -- actions.st+=/fists_of_fury,if=energy.time_to_max>2.5&cooldown.rising_sun_kick.remains>2&buff.swift_roundhouse.stack=2
    if S.FistsOfFury:IsReadyP() and Player:EnergyTimeToMaxPredicted() > 2.5 and S.RisingSunKick:CooldownRemainsP() > 2 and
      Player:BuffStack(S.SwiftRoundhouseBuff) == 2 then
      if HR.Cast(S.FistsOfFury) then 
        return "Cast Single Target Fists of Fury"; end
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
		-- actions+=/call_action_list,name=serenity,if=buff.serenity.up
		if Player:BuffP(S.Serenity) then
      local ShouldReturn = Serenity(); 
      if ShouldReturn then 
        return ShouldReturn; 
      end
    end
    -- actions+=/fist_of_the_white_tiger,if=(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2))&chi.max-chi>=3
    if S.FistOfTheWhiteTiger:IsReadyP() and (Player:EnergyTimeToMaxPredicted() < 1 or (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2)) and Player:ChiDeficit() >= 3 then
      if HR.Cast(S.FistOfTheWhiteTiger) then 
        return "Cast Everyone Fist of the White Tiger"; 
      end
    end
    -- actions+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy.time_to_max<1|(talent.serenity.enabled&cooldown.serenity.remains<2))&chi.max-chi>=2&!prev_gcd.1.tiger_palm
    if S.TigerPalm:IsReadyP() and 
      (
        Player:EnergyTimeToMaxPredicted() < 1 or
        (S.Serenity:IsAvailable() and S.Serenity:CooldownRemainsP() < 2)
      ) and
      Player:ChiDeficit() >= 2 and not Player:PrevGCD(1, S.TigerPalm) then
      if HR.Cast(S.TigerPalm) then 
        return "Cast Everyone Tiger Palm"; 
      end
    end
    -- actions.st=call_action_list,name=cd
    if (true) then
      local ShouldReturn = Cooldowns(); 
      if ShouldReturn then 
        return ShouldReturn; end
    end
    -- actions+=/call_action_list,name=st,if=active_enemies<3|(active_enemies=3&azerite.swift_roundhouse.rank>2)
    if (Cache.EnemiesCount[8] < 3 or (Cache.EnemiesCount[8] == 3 and S.SwiftRoundhouse:AzeriteRank() > 2)) then
      local ShouldReturn = SingleTarget(); 
      if ShouldReturn then 
        return ShouldReturn; end
    end;
    -- actions+=/call_action_list,name=aoe,if=active_enemies>3|(active_enemies=3&azerite.swift_roundhouse.rank<=2)
    if (Cache.EnemiesCount[8] > 3 or (Cache.EnemiesCount[8] == 3 and S.SwiftRoundhouse:AzeriteRank() <= 2)) then
      local ShouldReturn = Aoe(); 
      if ShouldReturn then 
        return ShouldReturn; end
    end
    if HR.Cast(S.PoolEnergy) then 
      return "Pool Energy"; end
	end
end
HR.SetAPL(269, APL);

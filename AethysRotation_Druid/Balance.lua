--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- AethysRotation
local AR = AethysRotation;
-- Lua

--- APL Local Vars
-- Commons
  local Everyone = AR.Commons.Everyone;
  
-- Spells
  if not Spell.Druid then Spell.Druid = {}; end
  Spell.Druid.Balance = {
    -- Racials
		ArcaneTorrent			= Spell(25046),
		Berserking				= Spell(26297),
		BloodFury				  = Spell(20572),
		GiftoftheNaaru		= Spell(59547),
		Shadowmeld        = Spell(58984),
    -- Forms
		MoonkinForm 			= Spell(24858),
		BearForm 				  = Spell(5487),
		CatForm 				  = Spell(768),
		TravelForm 				= Spell(783),
    -- Abilities
		CelestialAlignment= Spell(194223),
		LunarStrike 			= Spell(194153),
		SolarWrath 				= Spell(190984),
		MoonFire 				  = Spell(8921),
		MoonFireDebuff 		= Spell(164812),
		SunFire 				  = Spell(93402),
		SunFireDebuff 		= Spell(164815),
		Starsurge 				= Spell(78674),
		Starfall 				  = Spell(191034),
    -- Talents
		ForceofNature  		= Spell(205636),
		WarriorofElune  	= Spell(202425),
		Starlord  				= Spell(202345),
		
		Renewal  				  = Spell(108235),
		DisplacerBeast  	= Spell(102280),
		WildCharge  			= Spell(102401),
		
		FeralAffinity 		= Spell(202157),
		GuardianAffinity  = Spell(197491),
		RestorationAffinity = Spell(197492),
		
    MightyBash  	    = Spell(5211),
		MassEntanglement  = Spell(102359),
		Typhoon  		      = Spell(132469),
    
		SoulOfTheForest  	= Spell(114107),
		IncarnationChosenOfElune = Spell(102560),
		StellarFlare  		= Spell(202347),
		
		ShootingStars  		= Spell(202342),
		AstralCommunion  	= Spell(202359),
		BlessingofTheAncients = Spell(202360),
		BlessingofElune  	= Spell(202737),
		BlessingofAnshe  	= Spell(202739),
		
		FuryofElune  			= Spell(202770),
		StellarDrift  		= Spell(202354),
		NaturesBalance  	= Spell(202430),
    -- Artifact
		NewMoon 				  = Spell(202767),
		HalfMoon 				  = Spell(202768),
		FullMoon 				  = Spell(202771),
    -- Defensive
		Barkskin 				  = Spell(22812),
		FrenziedRegeneration = Spell(22842),
		Ironfur 				  = Spell(192081),
		Regrowth 				  = Spell(8936),
		Rejuvenation 			= Spell(774),
		Swiftmend 				= Spell(18562),
		HealingTouch 			= Spell(5185),
    -- Utility
		Innervate 				= Spell(29166),
		SolarBeam 				= Spell(78675),
    EntanglingRoots   = Spell(339),
    -- Legendaries
		OnethsIntuition		= Spell(209406),
    OnethsOverconfidence = Spell(209407),
		EmeraldDreamcatcher	= Spell(208190),
    SephuzBuff        = Spell(208052),
    -- Misc
		SolarEmpowerment	= Spell(164545),
		LunarEmpowerment	= Spell(164547),
		StellarEmpowerment = Spell(197637),
    SolarSolstice	    = Spell(252767),
    AstralAcceleration= Spell(242232),
    PotionOfProlongedPowerBuff = Spell(229206)
  };
  local S = Spell.Druid.Balance;
  
-- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Balance = {
    -- Legendaries
		EmeraldDreamcatcher		  = Item(137062, {1}),
    LadyAndTheChild         = Item(144295, {3}), 
    OnethsIntuition         = Item(137092, {9}), 
    SephuzSecret 			      = Item(132452, {11,12}),
    RadiantMoonlight        = Item(151800, {15}), 
    -- Potion
    PotionOfProlongedPower  = Item(142117)
  };
  local I = Item.Druid.Balance;
  
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD, BestUnitSpellToCast; -- Used for cycling
  local T192P,T194P = AC.HasTier("T19")
  local T202P,T204P = AC.HasTier("T20")
  local T212P,T214P = AC.HasTier("T21")
  local range = 45
  local nextMoon;
  local moons={[S.NewMoon:ID()] = true, [S.HalfMoon:ID()] = true, [S.FullMoon:ID()] = true}
  
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Druid.Commons,
    Balance = AR.GUISettings.APL.Druid.Balance
  };

-- Prediction for the next Moon
local function nextMoonCalculation ()
	if Player:IsCasting() then
		if Player:CastID()== S.NewMoon:ID() then 
      nextMoon = S.HalfMoon
		elseif Player:CastID()== S.HalfMoon:ID() then 
      nextMoon = S.FullMoon
		elseif Player:CastID()== S.FullMoon:ID() then --TODO : manage RadiantMoonlight
      nextMoon = S.NewMoon 
    end
  else
    if S.NewMoon:IsCastable() then 
      nextMoon = S.NewMoon
    elseif S.HalfMoon:IsCastable() then 
      nextMoon = S.HalfMoon
    elseif S.FullMoon:IsCastable() then 
      nextMoon = S.FullMoon 
    end
	end
end

-- Compute the futur astral power after the cast
local function FuturAstralPower ()
    local AstralPower=Player:AstralPower()
    if not Player:IsCasting() then
      return AstralPower
    else
      if Player:CastID() == S.NewMoon:ID() then
        return AstralPower + 10
      elseif Player:CastID() == S.HalfMoon:ID() then
        return AstralPower + 20
      elseif Player:CastID() == S.FullMoon:ID() then
        return AstralPower + 40
      elseif Player:CastID() == S.SolarWrath:ID() then
        return AstralPower + (Player:Buff(S.BlessingofElune) and 10 or 8) * ((Player:BuffRemainsP(S.CelestialAlignment) > 0 or Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0) and 2 or 1)
      elseif Player:CastID() == S.LunarStrike:ID() then
        return AstralPower + (Player:Buff(S.BlessingofElune) and 15 or 10) * ((Player:BuffRemainsP(S.CelestialAlignment) > 0 or Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0) and 2 or 1)
      else
        return AstralPower
      end
    end
end

-- Overrides the base duration from spell because of spec aura
local function BaseDurationBalance (Spell)
  local SpellBaseDuration = Spell:BaseDuration()
  if Spell:ID() == S.MoonFireDebuff:ID() then SpellBaseDuration = SpellBaseDuration + 6 end
  if Spell:ID() == S.SunFireDebuff:ID() then SpellBaseDuration = SpellBaseDuration + 6 end
  return SpellBaseDuration
end

-- Overrides the max duration from spell because of spec aura
local function MaxDurationBalance (Spell)
  local SpellBaseDuration = BaseDurationBalance(Spell)
  return SpellBaseDuration * 1.3
end

-- Overrides the pandemic Threshold from spell because of spec aura
local function PandemicThresholdBalance (Spell)
  local SpellBaseDuration = BaseDurationBalance(Spell)
  return SpellBaseDuration * 0.3
end
  
local function FuryOfElune ()
  -- actions.fury_of_elune=incarnation,if=astral_power>=95&cooldown.fury_of_elune.remains<=gcd
	if S.IncarnationChosenOfElune:IsAvailable() and FuturAstralPower() >= 95 and S.FuryofElune:CooldownRemainsP() <= 0 then
		if AR.Cast(S.IncarnationChosenOfElune, Settings.Balance.OffGCDasOffGCD.IncarnationChosenOfElune) then return ""; end
	end
  
	-- actions.fury_of_elune+=/fury_of_elune,if=astral_power>=95
	if FuturAstralPower()>=95 and S.FuryofElune:CooldownRemainsP() <= 0 then
		if AR.Cast(S.FuryofElune) then return ""; end
	end
  
  -- actions.fury_of_elune+=/new_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=90))
	if S.NewMoon:IsCastable() 
		and ((S.NewMoon:Charges() == 2 and S.NewMoon:RechargeP() < 5 and not moons[Player:CastID()] ) 
		or (S.NewMoon:Charges() == 3 and not moons[Player:CastID()])
    or (S.NewMoon:Charges() == 3 and moons[Player:CastID()] and S.NewMoon:RechargeP() < 5 and nextMoon == S.NewMoon))
		and (Player:BuffRemainsP(S.FuryofElune) > S.NewMoon:CastTime() or (S.FuryofElune:CooldownRemainsP() < Player:GCD() * 3 and FuturAstralPower() <= 90))	then
		if AR.Cast(S.NewMoon) then return ""; end
	end
  
  -- actions.fury_of_elune+=/half_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=80))
	if S.HalfMoon:IsCastable() 
		and ((S.NewMoon:Charges() == 2 and S.NewMoon:RechargeP() < 5 and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 3 and not moons[Player:CastID()])
    or (S.NewMoon:Charges() == 3 and moons[Player:CastID()] and S.NewMoon:RechargeP() < 5 and nextMoon == S.HalfMoon)) 
		and (Player:BuffRemainsP(S.FuryofElune) > S.HalfMoon:CastTime() or (S.FuryofElune:CooldownRemainsP() < Player:GCD() * 3 and FuturAstralPower() <= 80)) then
		if AR.Cast(S.HalfMoon) then return ""; end
	end

  -- actions.fury_of_elune+=/full_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=60))  
	if S.FullMoon:IsCastable() 
		and ((S.NewMoon:Charges()==2 and S.NewMoon:RechargeP()<5 and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==3 and not moons[Player:CastID()])
    or (S.NewMoon:Charges() == 3 and moons[Player:CastID()] and S.NewMoon:RechargeP() < 5 and nextMoon == S.FullMoon)) 
		and (Player:BuffRemainsP(S.FuryofElune) > S.FullMoon:CastTime() or (S.FuryofElune:CooldownRemainsP() < Player:GCD() * 3 and FuturAstralPower() <= 60)) then
		if AR.Cast(S.FullMoon) then return ""; end
	end
  
	-- actions.fury_of_elune+=/astral_communion,if=buff.fury_of_elune_up.up&astral_power<=25
	if S.AstralCommunion:IsAvailable() and S.AstralCommunion:IsCastable() and FuturAstralPower() <= 75 then
		if AR.Cast(S.AstralCommunion, Settings.Balance.OffGCDasOffGCD.AstralCommunion) then return ""; end
	end
  
	-- actions.fury_of_elune+=/warrior_of_elune,if=buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>=35&buff.lunar_empowerment.up)
	if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune)
		and (Player:BuffRemainsP(S.FuryofElune) > 0 or (S.FuryofElune:CooldownRemainsP() >= 35 and Player:Buff(S.LunarEmpowerment) and not(Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1)))then
		if AR.Cast(S.WarriorofElune) then return ""; end
	end
  
	-- actions.fury_of_elune+=/lunar_strike,if=buff.warrior_of_elune.up&(astral_power<=90|(astral_power<=85&buff.incarnation.up))
	if S.LunarStrike:IsCastable() and Player:Buff(S.WarriorofElune) 
		and not (Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.WarriorofElune) == 1)
		and (FuturAstralPower() <= 90 or (Player:BuffRemainsP(IncarnationChosenOfElune) > S.LunarStrike:CastTime() and FuturAstralPower() <= 85)) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
  -- actions.fury_of_elune+=/new_moon,if=astral_power<=90&buff.fury_of_elune_up.up
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.NewMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon==S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.NewMoon))  
		and FuturAstralPower() <= 90 
		and Player:BuffRemainsP(S.FuryofElune) > S.NewMoon:CastTime() then
			if AR.Cast(S.NewMoon) then return ""; end
	end
  
  -- actions.fury_of_elune+=/half_moon,if=astral_power<=80&buff.fury_of_elune_up.up&astral_power>cast_time*12
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.HalfMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.HalfMoon))
		and FuturAstralPower() > S.HalfMoon:CastTime() * 12
    and FuturAstralPower() <= 80
		and Player:BuffRemainsP(S.FuryofElune) > S.HalfMoon:CastTime() then	
			if AR.Cast(S.HalfMoon) then return ""; end
	end
  
	-- actions.fury_of_elune+=/full_moon,if=astral_power<=60&buff.fury_of_elune_up.up&astral_power>cast_time*12
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.FullMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.FullMoon)) 
    and FuturAstralPower() > S.FullMoon:CastTime() * 12
		and FuturAstralPower() <= 60
		and Player:BuffRemainsP(S.FuryofElune) > S.FullMoon:CastTime() then
			if AR.Cast(S.FullMoon) then return ""; end
	end
  
	-- actions.fury_of_elune+=/moonfire,if=buff.fury_of_elune_up.down&remains<=6.6
	if Player:BuffRemainsP(S.FuryofElune) == 0 and Target:DebuffRemainsP(S.MoonFireDebuff) <= PandemicThresholdBalance(S.MoonFireDebuff)  then
		if AR.Cast(S.MoonFire) then return ""; end
	end
  
	-- actions.fury_of_elune+=/sunfire,if=buff.fury_of_elune_up.down&remains<5.4
	if Player:BuffRemainsP(S.FuryofElune) == 0 and Target:DebuffRemainsP(S.SunFireDebuff) <= PandemicThresholdBalance(S.SunFireDebuff)  then
		if AR.Cast(S.SunFire) then return ""; end
	end

	-- actions.fury_of_elune+=/stellar_flare,if=remains<7.2&active_enemies=1
	if S.StellarFlare:IsAvailable() and FuturAstralPower() >= 15 and Target:DebuffRemainsP(S.StellarFlare) <= PandemicThresholdBalance(S.StellarFlare) then
		if AR.Cast(S.StellarFlare) then return ""; end
	end
  
	-- actions.fury_of_elune+=/starfall,if=(active_enemies>=2&talent.stellar_flare.enabled|active_enemies>=3)&buff.fury_of_elune_up.down&cooldown.fury_of_elune.remains>10
	if (AR.AoEON() and ((Cache.EnemiesCount[range] >= 2 and S.StellarFlare:IsAvailable()) or Cache.EnemiesCount[range] >= 3)
		and Player:BuffRemainsP(S.FuryofElune) == 0 and S.FuryofElune:CooldownRemainsP() > 10 and FuturAstralPower() >= 60) or Player:Buff(S.OnethsOverconfidence) then
		if AR.Cast(S.Starfall) then return ""; end
	end
  
	-- actions.fury_of_elune+=/starsurge,if=active_enemies<=2&buff.fury_of_elune_up.down&cooldown.fury_of_elune.remains>7
	if FuturAstralPower() >= 40 and Cache.EnemiesCount[range] <= 2 and Player:BuffRemainsP(S.FuryofElune) == 0 and S.FuryofElune:CooldownRemainsP() > 7 then
		if AR.Cast(S.Starsurge) then return ""; end
	end
  
	-- actions.fury_of_elune+=/starsurge,if=buff.fury_of_elune_up.down&((astral_power>=92&cooldown.fury_of_elune.remains>gcd*3)|(cooldown.warrior_of_elune.remains<=5&cooldown.fury_of_elune.remains>=35&buff.lunar_empowerment.stack<2))
	if FuturAstralPower()>=40 and Player:BuffRemainsP(S.FuryofElune) == 0
	and ((FuturAstralPower()>=92 and S.FuryofElune:CooldownRemainsP() > Player:GCD() * 3) 
		or (S.WarriorofElune:CooldownRemainsP() <= 5 and S.FuryofElune:CooldownRemainsP() >= 35  and Player:BuffStack(S.WarriorofElune) < 2)) then
		if AR.Cast(S.Starsurge) then return ""; end
	end
  
	-- actions.fury_of_elune+=/solar_wrath,if=buff.solar_empowerment.up
	if Player:Buff(S.SolarEmpowerment) and not (Player:CastID() == S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment) == 1) then
		if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
	-- actions.fury_of_elune+=/lunar_strike,if=buff.lunar_empowerment.stack=3|(buff.lunar_empowerment.remains<5&buff.lunar_empowerment.up)|active_enemies>=2
	if ((Player:BuffStack(S.LunarEmpowerment) == 3 and not(Player:CastID() == S.LunarStrike:ID()))
		or (Player:Buff(S.LunarEmpowerment) and not(Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1) and Player:BuffRemainsP(S.LunarEmpowerment) < 5)
		or Cache.EnemiesCount[range] >= 2) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
	-- actions.fury_of_elune+=/solar_wrath
	if AR.Cast(S.SolarWrath) then return ""; end

end 
  
local function EmeraldDreamcatcherRotation ()
	-- actions.ed=astral_communion,if=astral_power.deficit>=75&buff.the_emerald_dreamcatcher.up
	if S.AstralCommunion:IsAvailable() and S.AstralCommunion:CooldownRemainsP() == 0 and Player:AstralPowerDeficit(FuturAstralPower()) >= 75 and Player:BuffRemainsP(S.EmeraldDreamcatcher) > 0 then
		if AR.Cast(S.AstralCommunion, Settings.Balance.OffGCDasOffGCD.AstralCommunion) then return ""; end
	end
  
  -- actions.ed+=/incarnation,if=astral_power>=60|buff.bloodlust.up
	if S.IncarnationChosenOfElune:IsAvailable() and S.IncarnationChosenOfElune:CooldownRemainsP() == 0 and (FuturAstralPower() >= 60  or Player:HasHeroism())then
		if AR.Cast(S.IncarnationChosenOfElune, Settings.Balance.OffGCDasOffGCD.IncarnationChosenOfElune) then return ""; end
	end
  
  -- actions.ed+=/celestial_alignment,if=astral_power>=60&!buff.the_emerald_dreamcatcher.up
	if S.CelestialAlignment:IsAvailable() and S.CelestialAlignment:CooldownRemainsP() == 0 and FuturAstralPower() >= 60 and Player:BuffRemainsP(S.EmeraldDreamcatcher) == 0 then
		if AR.Cast(S.CelestialAlignment, Settings.Balance.OffGCDasOffGCD.CelestialAlignment) then return ""; end
	end
  
  -- actions.ed+=/starsurge,if=(gcd.max*astral_power%26)>target.time_to_die
  if FuturAstralPower() >= (40 - (5 * Player:BuffStack(S.EmeraldDreamcatcher))) and Target:FilteredTimeToDie("<", Player:GCD() * FuturAstralPower() / 26) then
		if AR.Cast(S.Starsurge) then return ""; end
	end
  
  -- actions.ed+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2
	if S.StellarFlare:IsAvailable() and Cache.EnemiesCount[range] < 4 and FuturAstralPower() >= 15 and Target:DebuffRefreshableCP(S.StellarFlare) and not Player:CastID()==S.StellarFlare:ID() then
    if AR.Cast(S.StellarFlare) then return ""; end
  end
  if AR.AoEON() and Cache.EnemiesCount[range] < 4 and FuturAstralPower() >= 15 then
    BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
    for Key, Value in pairs(Cache.Enemies[range]) do
      if S.StellarFlare:IsAvailable() and Value:TimeToDie()-Value:DebuffRemainsP(S.StellarFlare) > BestUnitTTD and Value:DebuffRefreshableCP(S.StellarFlare) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.StellarFlare;
      end					
    end
    if BestUnit then
      if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
    end
  end
  
	-- actions.ed+=/moonfire,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)			
	if ((S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.MoonFireDebuff) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRefreshableCP(S.MoonFireDebuff)))
		and (Player:BuffRemainsP(S.EmeraldDreamcatcher) > 0 or Player:BuffRemainsP(S.EmeraldDreamcatcher)==0) then
		if AR.Cast(S.MoonFire) then return ""; end
	end
  
  -- actions.ed+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
	if ((S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.SunFireDebuff) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRefreshableCP(S.SunFireDebuff)))
		and (Player:BuffRemainsP(S.EmeraldDreamcatcher) > 0 or Player:BuffRemainsP(S.EmeraldDreamcatcher)==0) then
		if AR.Cast(S.SunFire) then return ""; end
	end
  
  -- actions.ed+=/starfall,if=buff.oneths_overconfidence.up&buff.the_emerald_dreamcatcher.remains>execute_time
	if Player:Buff(S.OnethsIntuition) and Player:BuffRemainsP(S.EmeraldDreamcatcher) > Player:GCD() then
		if AR.Cast(S.Starfall) then return ""; end
	end
  
  -- actions.ed+=/new_moon,if=astral_power.deficit>=10&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=16
  if Player:AstralPowerDeficit(FuturAstralPower()) > 10 and Player:BuffRemainsP(S.EmeraldDreamcatcher) > S.NewMoon:CastTime() and FuturAstralPower() >= 16
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.NewMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.NewMoon)) then
			if AR.Cast(S.NewMoon) then return ""; end
	end
  
  -- actions.ed+=/half_moon,if=astral_power.deficit>=20&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=6
  if Player:AstralPowerDeficit(FuturAstralPower()) > 20 and Player:BuffRemainsP(S.EmeraldDreamcatcher) > S.HalfMoon:CastTime() and FuturAstralPower() >= 6
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.HalfMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.HalfMoon)) then	
			if AR.Cast(S.HalfMoon) then return ""; end
	end
  
  -- actions.ed+=/full_moon,if=astral_power.deficit>=40&buff.the_emerald_dreamcatcher.remains>execute_time
  if Player:AstralPowerDeficit(FuturAstralPower()) > 40 and Player:BuffRemainsP(S.EmeraldDreamcatcher) > S.FullMoon:CastTime()
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.FullMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.FullMoon)) then
			if AR.Cast(S.FullMoon) then return ""; end
	end
  
  -- actions.ed+=/lunar_strike,if=(buff.lunar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=22.5))&spell_haste<0.4
  if Player:Buff(S.LunarEmpowerment) and not(Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1) and Player:BuffRemainsP(S.EmeraldDreamcatcher) > S.LunarStrike:CastTime() and Player:SpellHaste() < 0.4
  and ((Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0 and Player:AstralPowerDeficit(FuturAstralPower()) >= 15) 
    or ((Player:BuffRemainsP(S.IncarnationChosenOfElune) > S.LunarStrike:CastTime() or Player:BuffRemainsP(S.CelestialAlignment) > S.LunarStrike:CastTime()) and Player:AstralPowerDeficit(FuturAstralPower()) >= 22.5))  then
      if AR.Cast(S.LunarStrike) then return ""; end
	end
  
  -- actions.ed+=/solar_wrath,if=buff.solar_empowerment.stack>1&buff.the_emerald_dreamcatcher.remains>2*execute_time&astral_power>=6&(dot.moonfire.remains>5|(dot.sunfire.remains<5.4&dot.moonfire.remains>6.6))&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=10|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15)
  if Player:BuffStack(S.SolarEmpowerment) > 1 and Player:BuffRemainsP(S.EmeraldDreamcatcher) > S.SolarWrath:CastTime() * 2 and FuturAstralPower() >= 6 
    and (Target:DebuffRemainsP(S.MoonFireDebuff) > 5 or (Target:DebuffRemainsP(S.SunFireDebuff) <= PandemicThresholdBalance(S.SunFireDebuff) and Target:DebuffRemainsP(S.MoonFireDebuff) <= PandemicThresholdBalance(S.MoonFireDebuff))) 
    and ((Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0 and Player:AstralPowerDeficit(FuturAstralPower()) >= 10) 
    or ((Player:BuffRemainsP(S.IncarnationChosenOfElune) > S.SolarWrath:CastTime() or Player:BuffRemainsP(S.CelestialAlignment) > S.SolarWrath:CastTime()) and Player:AstralPowerDeficit(FuturAstralPower()) >= 15)) then
      if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
  -- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=11&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=22.5)
  if Player:Buff(S.LunarEmpowerment) and not(Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1) and Player:BuffRemainsP(S.EmeraldDreamcatcher) > S.LunarStrike:CastTime() and FuturAstralPower() >= 11
  and ((Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0 and Player:AstralPowerDeficit(FuturAstralPower()) >= 15) 
    or ((Player:BuffRemainsP(S.IncarnationChosenOfElune) > S.LunarStrike:CastTime() or Player:BuffRemainsP(S.CelestialAlignment) > S.LunarStrike:CastTime()) and Player:AstralPowerDeficit(FuturAstralPower()) >= 22.5)) then
      if AR.Cast(S.LunarStrike) then return ""; end
	end
  
  -- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=16&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=10|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15)
  if Player:BuffStack(S.SolarEmpowerment) > 1 and Player:BuffRemainsP(S.EmeraldDreamcatcher) > 0 and FuturAstralPower() >= 16 
    and ((Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0 and Player:AstralPowerDeficit(FuturAstralPower()) >= 10) 
    or ((Player:BuffRemainsP(S.IncarnationChosenOfElune) > S.SolarWrath:CastTime() or Player:BuffRemainsP(S.CelestialAlignment) > S.SolarWrath:CastTime()) and Player:AstralPowerDeficit(FuturAstralPower()) >= 15)) then
      if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
  -- actions.ed+=/starsurge,if=(buff.the_emerald_dreamcatcher.up&buff.the_emerald_dreamcatcher.remains<gcd.max)|astral_power>85|((buff.celestial_alignment.up|buff.incarnation.up)&astral_power>30)
  if FuturAstralPower() >= (40 - (5 * Player:BuffStack(S.EmeraldDreamcatcher)))
    and (Player:BuffRemainsP(S.EmeraldDreamcatcher) < Player:GCD() or FuturAstralPower() > 85 or ((Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0 or Player:BuffRemainsP(S.CelestialAlignment) > 0) and FuturAstralPower() > 30)) then
      if AR.Cast(S.Starsurge) then return ""; end
	end
  
  -- actions.ed+=/starfall,if=buff.oneths_overconfidence.up
  if Player:Buff(S.OnethsOverconfidence) then
    if AR.Cast(S.Starfall) then return ""; end
  end
  
  -- actions.ed+=/new_moon,if=astral_power.deficit>=10
  if Player:AstralPowerDeficit(FuturAstralPower()) > 10
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.NewMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.NewMoon)) then
			if AR.Cast(S.NewMoon) then return ""; end
	end
  
  -- actions.ed+=/half_moon,if=astral_power.deficit>=20
  if Player:AstralPowerDeficit(FuturAstralPower()) > 20
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.HalfMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.HalfMoon)) then	
			if AR.Cast(S.HalfMoon) then return ""; end
	end
  
  -- actions.ed+=/full_moon,if=astral_power.deficit>=40
  if Player:AstralPowerDeficit(FuturAstralPower()) > 40
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.FullMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.FullMoon)) then
			if AR.Cast(S.FullMoon) then return ""; end
	end
  
  -- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up
  if Player:Buff(S.SolarEmpowerment) and not (Player:CastID() == S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment) == 1) then
		if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
  -- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up
  if Player:Buff(S.LunarEmpowerment) and not (Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
  -- actions.ed+=/solar_wrath
  if AR.Cast(S.SolarWrath) then return ""; end
end  

local function SingleTarget ()
  -- actions.single_target=starsurge,if=astral_power.deficit<44|(buff.celestial_alignment.up|buff.incarnation.up|buff.astral_acceleration.remains>5|(set_bonus.tier21_4pc&!buff.solar_solstice.up))|(gcd.max*(astral_power%40))>target.time_to_die
	if FuturAstralPower() > 40 and (Player:AstralPowerDeficit(FuturAstralPower()) < 44 or (Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0 or Player:BuffRemainsP(S.CelestialAlignment) > 0 or Player:BuffRemainsP(S.AstralAcceleration) > 5 or (T214P and Player:BuffRemainsP(S.SolarSolstice) == 0)) or Target:FilteredTimeToDie("<", Player:GCD() * FuturAstralPower() / 40)) then
		if AR.Cast(S.Starsurge) then return ""; end
	end

  -- actions.single_target+=/new_moon,if=astral_power.deficit>14&!(buff.celestial_alignment.up|buff.incarnation.up)
	if Player:AstralPowerDeficit(FuturAstralPower()) > 14 and Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.NewMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.NewMoon)) then
			if AR.Cast(S.NewMoon) then return ""; end
	end
  
  -- actions.single_target+=/half_moon,if=astral_power.deficit>24&!(buff.celestial_alignment.up|buff.incarnation.up)
	if Player:AstralPowerDeficit(FuturAstralPower()) > 24 and Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.HalfMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.HalfMoon)) then	
			if AR.Cast(S.HalfMoon) then return ""; end
	end
  
  -- actions.single_target+=/full_moon,if=astral_power.deficit>44
	if Player:AstralPowerDeficit(FuturAstralPower()) > 44
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.FullMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.FullMoon)) then
			if AR.Cast(S.FullMoon) then return ""; end
	end
	
	-- actions.single_target+=/warrior_of_elune
	if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune) then
		if AR.Cast(S.WarriorofElune, Settings.Balance.OffGCDasOffGCD.WarriorofElune) then return ""; end
	end
  
	-- actions.single_target+=/lunar_strike,if=buff.warrior_of_elune.up
	if Player:Buff(S.WarriorofElune) and not (Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.WarriorofElune) == 1) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
	-- actions.single_target+=/solar_wrath,if=buff.solar_empowerment.up
	if Player:Buff(S.SolarEmpowerment) and not (Player:CastID() == S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment) == 1) then
		if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
	-- actions.single_target+=/lunar_strike,if=buff.lunar_empowerment.up
	if Player:Buff(S.LunarEmpowerment) and not (Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
	-- actions.single_target+=/solar_wrath,if=talent.natures_balance.enabled&dot.sunfire_dmg.remains<5&cast_time<dot.sunfire_dmg.remains
	if S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.MoonFireDebuff) < 5 and S.SolarWrath:CastTime() < Target:DebuffRemainsP(S.MoonFireDebuff) then
		if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
	-- actions.single_target+=/solar_wrath
	if AR.Cast(S.SolarWrath) then return ""; end
end

local function AoE ()
  -- actions.AoE=starfall,if=debuff.stellar_empowerment.remains<gcd.max*2|astral_power.deficit<22.5|(buff.celestial_alignment.remains>8|buff.incarnation.remains>8)|target.time_to_die<8
  if FuturAstralPower() > 60 and (Player:BuffRemainsP(S.Starfall) < Player:GCD() * 2 or Player:AstralPowerDeficit(FuturAstralPower()) < 22.5 or (Player:DebuffRemainsP(S.CelestialAlignment) > 8 or Player:DebuffRemainsP(S.IncarnationChosenOfElune) > 8) or Target:FilteredTimeToDie("<", 8)) then
    if AR.Cast(S.Starfall) then return ""; end
  end
  
  -- actions.AoE+=/new_moon,if=astral_power.deficit>14
  if Player:AstralPowerDeficit(FuturAstralPower()) > 14
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.NewMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.NewMoon)) then
			if AR.Cast(S.NewMoon) then return ""; end
	end
  
  -- actions.AoE+=/half_moon,if=astral_power.deficit>24
  if Player:AstralPowerDeficit(FuturAstralPower()) > 24
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.HalfMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.HalfMoon)) then	
			if AR.Cast(S.HalfMoon) then return ""; end
	end
  
  -- actions.AoE+=/full_moon,if=astral_power.deficit>44
  if Player:AstralPowerDeficit(FuturAstralPower()) > 44
		and ((S.NewMoon:Charges() > 1 and nextMoon == S.FullMoon)
		or (S.NewMoon:Charges() == 1 and nextMoon == S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges() == 0 and S.NewMoon:RechargeP() <= 0 and nextMoon == S.FullMoon)) then
			if AR.Cast(S.FullMoon) then return ""; end
	end
  
  -- actions.AoE+=/warrior_of_elune
  if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune) then
		if AR.Cast(S.WarriorofElune, Settings.Balance.OffGCDasOffGCD.WarriorofElune) then return ""; end
	end
  
  -- actions.AoE+=/lunar_strike,if=buff.warrior_of_elune.up
  if Player:Buff(S.WarriorofElune) and not (Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.WarriorofElune) == 1) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
  -- actions.AoE+=/solar_wrath,if=buff.solar_empowerment.up
  if Player:Buff(S.SolarEmpowerment) and not (Player:CastID() == S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment) == 1) then
		if AR.Cast(S.SolarWrath) then return ""; end
	end	
  
  -- actions.AoE+=/lunar_strike,if=buff.lunar_empowerment.up
  if Player:Buff(S.LunarEmpowerment) and not (Player:CastID() == S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment) == 1) then
		if AR.Cast(S.LunarStrike) then return ""; end
	end
  
  -- actions.AoE+=/moonfire,if=equipped.lady_and_the_child&active_enemies=2&spell_haste>0.4&!(buff.celestial_alignment.up|buff.incarnation.up)
  if I.LadyAndTheChild:IsEquipped() and Cache.EnemiesCount[range] == 2 and Player:SpellHaste() > 0.4 and Player:BuffRemainsP(S.IncarnationChosenOfElune) <= 0 and Player:BuffRemainsP(S.CelestialAlignment) <= 0 then
    if AR.Cast(S.MoonFire) then return ""; end
  end
  
  -- actions.AoE+=/lunar_strike,if=active_enemies>=4|spell_haste<0.45
  if Cache.EnemiesCount[range] >= 4 or Player:SpellHaste() < 0.45 then
    if AR.Cast(S.LunarStrike) then return ""; end
  end
  
  -- actions.AoE+=/solar_wrath
  if AR.Cast(S.SolarWrath) then return ""; end
end

local function Sephuz()
  -- EntanglingRoots
  --TODO : change level when iscontrollable is here
  if S.EntanglingRoots:IsCastable() and Target:Level() < 103 and Settings.Balance.Sephuz.EntanglingRoots then
    if AR.CastSuggested(S.EntanglingRoots) then return "Cast"; end
  end
  
  -- MightyBash
  --TODO : change level when iscontrollable is here

  if S.MightyBash:IsAvailable() and S.MightyBash:IsCastable() and Target:Level() < 103 and Settings.Balance.Sephuz.MightyBash then
    if AR.CastSuggested(S.MightyBash) then return "Cast"; end
  end
  
  -- MassEntanglement
  --TODO : change level when iscontrollable is here

  if S.MassEntanglement:IsAvailable() and S.MassEntanglement:IsCastable() and Target:Level() < 103 and Settings.Balance.Sephuz.MassEntanglement then
    if AR.CastSuggested(S.MassEntanglement) then return "Cast"; end
  end
  
  -- Typhoon 
  --TODO : change level when iscontrollable is here
  if S.Typhoon:IsAvailable() and S.Typhoon:IsCastable() and Target:Level() < 103 and Settings.Balance.Sephuz.Typhoon then
    if AR.CastSuggested(S.Typhoon) then return "Cast"; end
  end
  
  -- SolarBeam
  if S.SolarBeam:IsCastable() and Target:IsCasting() and Target:IsInterruptible() and Settings.Balance.Sephuz.SolarBeam then
    if AR.CastSuggested(S.SolarBeam) then return "Cast"; end
  end
end

-- CD Usage
local function CDs ()
  -- actions=potion,name=potion_of_prolonged_power,if=buff.celestial_alignment.up|buff.incarnation.up
  if Settings.Balance.ShowPoPP and I.PotionOfProlongedPower:IsReady() and (Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0 and Player:BuffRemainsP(S.CelestialAlignment) > 0) or Target:FilteredTimeToDie("<=", 60) then
    if AR.CastSuggested(I.PotionOfProlongedPower) then return "Cast"; end
  end

  -- actions+=/blessing_of_elune,if=active_enemies<=2&talent.blessing_of_the_ancients.enabled&buff.blessing_of_elune.down
  if (Cache.EnemiesCount[range] <= 2 or not AR.AoEON()) and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and not Player:Buff(S.BlessingofElune) then
    if AR.Cast(S.BlessingofElune, Settings.Balance.OffGCDasOffGCD.BlessingofElune) then return ""; end
  end
  
  -- actions+=/blessing_of_elune,if=active_enemies>=3&talent.blessing_of_the_ancients.enabled&buff.blessing_of_anshe.down
  if AR.AoEON() and Cache.EnemiesCount[range] >= 3 and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and not Player:Buff(S.BlessingofAnshe) then
    if AR.Cast(S.BlessingofAnshe, Settings.Balance.OffGCDasOffGCD.BlessingofAnshe) then return ""; end
  end

  -- actions+=/blood_fury,if=buff.celestial_alignment.up|buff.incarnation.up
	if S.BloodFury:IsAvailable() and S.BloodFury:IsCastable() and (Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0 or Player:BuffRemainsP(S.CelestialAlignment) > 0) then
		if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
	end
  
	-- actions+=/berserking,if=buff.celestial_alignment.up|buff.incarnation.up
	if S.Berserking:IsAvailable() and S.Berserking:IsCastable() and (Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0 or Player:BuffRemainsP(S.CelestialAlignment) > 0) then
		if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
	end
  
	-- actions+=/arcane_torrent,if=buff.celestial_alignment.up|buff.incarnation.up
	if S.ArcaneTorrent:IsAvailable() and S.ArcaneTorrent:IsCastable() and (Player:BuffRemainsP(S.IncarnationChosenOfElune) > 0 or Player:BuffRemainsP(S.CelestialAlignment) > 0) then
		if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
	end
  
 -- actions+=/astral_communion,if=astral_power.deficit>=75
	if S.AstralCommunion:IsAvailable() and S.AstralCommunion:IsCastable() and Player:AstralPowerDeficit(FuturAstralPower()) >= 75 and Player:BuffRemainsP(S.EmeraldDreamcatcher) == 0 then
		if AR.Cast(S.AstralCommunion, Settings.Balance.OffGCDasOffGCD.AstralCommunion) then return ""; end
	end
  
	-- actions+=/incarnation,if=astral_power>=40
	if S.IncarnationChosenOfElune:IsAvailable() and S.IncarnationChosenOfElune:IsCastable() and FuturAstralPower() >= 40
		and not S.FuryofElune:IsAvailable() and Player:BuffRemainsP(S.EmeraldDreamcatcher) == 0 then
		if AR.Cast(S.IncarnationChosenOfElune, Settings.Balance.OffGCDasOffGCD.IncarnationChosenOfElune) then return ""; end
	end
  
	-- actions+=/celestial_alignment,if=astral_power>=40
	if S.CelestialAlignment:IsAvailable() and S.CelestialAlignment:IsCastable() and FuturAstralPower() >= 40 and Player:BuffRemainsP(S.EmeraldDreamcatcher) == 0 then
		if AR.Cast(S.CelestialAlignment, Settings.Balance.OffGCDasOffGCD.CelestialAlignment) then return ""; end
	end
end

-- APL Main
local function APL ()
	-- Unit Update
  AC.GetEnemies(range);
  Everyone.AoEToggleEnemiesUpdate();
  nextMoonCalculation()
    
  -- Defensives
  if S.Barkskin:IsCastable() and Player:HealthPercentage() <= Settings.Balance.BarkSkinHP then
		if AR.Cast(S.Barkskin, Settings.Balance.OffGCDasOffGCD.BarkSkin) then return "Cast"; end
	end  
    
	-- Buffs
	if not Player:Buff(S.MoonkinForm) and not Player:AffectingCombat() then
		if AR.Cast(S.MoonkinForm, Settings.Balance.GCDasOffGCD.MoonkinForm) then return ""; end
	end
	  
	-- Out of Combat
  if not Player:AffectingCombat() then
    if (Cache.EnemiesCount[range] <= 2 or not AR.AoEON()) and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and not Player:Buff(S.BlessingofElune) then
      if AR.Cast(S.BlessingofElune, Settings.Balance.OffGCDasOffGCD.BlessingofElune) then return ""; end
    end
    if AR.AoEON() and Cache.EnemiesCount[range] >= 3 and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and not Player:Buff(S.BlessingofAnshe) then
      if AR.Cast(S.BlessingofAnshe, Settings.Balance.OffGCDasOffGCD.BlessingofAnshe) then return ""; end
    end
    
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ DBM Count
    -- Opener
    if Everyone.TargetIsValid() and Target:IsInRange(range) then
      if S.NewMoon:IsAvailable() and nextMoon:IsCastable() then
        if AR.Cast(nextMoon) then return ""; end
      end
      if S.StellarFlare:IsAvailable() and Cache.EnemiesCount[range] < 4 and FuturAstralPower() >= 15 then
        if AR.Cast(S.StellarFlare) then return ""; end
      end
      if AR.Cast(S.MoonFire) then return ""; end
    end
    
    return;
  end
	
	-- In Combat
  if Everyone.TargetIsValid() then
    if not Player:Buff(S.MoonkinForm) then
			if AR.Cast(S.MoonkinForm) then return ""; end
		end
		if Target:IsInRange(range) then --in range
			-- CD usage
			if AR.CDsON() then
				ShouldReturn = CDs();
				if ShouldReturn then return ShouldReturn; end
			end
      
      -- Sephuz usage
			if I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 then
				ShouldReturn = Sephuz();
				if ShouldReturn then return ShouldReturn; end
			end
      
			-- actions+=/call_action_list,name=fury_of_elune,if=talent.fury_of_elune.enabled&cooldown.fury_of_elune.remains<target.time_to_die
			if S.FuryofElune:IsAvailable() and Target:FilteredTimeToDie(">", S.FuryofElune:CooldownRemainsP()) then
				ShouldReturn = FuryOfElune(); 
				if ShouldReturn then return ShouldReturn; end
			end

			-- actions+=/call_action_list,name=ed,if=equipped.the_emerald_dreamcatcher&active_enemies<=1
			if I.EmeraldDreamcatcher:IsEquipped() and (Cache.EnemiesCount[range] <= 1 or not AR.AoEON()) then
				ShouldReturn = EmeraldDreamcatcherRotation ();
				if ShouldReturn then return ShouldReturn; end
			end
			
			--Movement
			if not Player:IsMoving() then	--static
        -- actions+=/new_moon,if=((charges=2&recharge_time<5)|charges=3)&astral_power.deficit>14
				if S.NewMoon:IsCastable() and Player:AstralPowerDeficit(FuturAstralPower()) > 14 
					and ((S.NewMoon:Charges() == 2 and S.NewMoon:RechargeP() < 5 and not moons[Player:CastID()] ) 
					or (S.NewMoon:Charges() == 3 and not moons[Player:CastID()])) then
            if AR.Cast(S.NewMoon) then return ""; end
				end
				
        -- actions+=/half_moon,if=((charges=2&recharge_time<5)|charges=3|(target.time_to_die<15&charges=2))&astral_power.deficit>24
				if S.HalfMoon:IsCastable() and Player:AstralPowerDeficit(FuturAstralPower()) > 24
					and ((S.NewMoon:Charges() == 2 and S.NewMoon:RechargeP() < 5 and not moons[Player:CastID()]) 
					or (S.NewMoon:Charges() == 3 and not moons[Player:CastID()]) 
					or (S.NewMoon:Charges() == 2 and Target:FilteredTimeToDie("<", 15))) then
					if AR.Cast(S.HalfMoon) then return ""; end
				end
        
				-- actions+=/full_moon,if=((charges=2&recharge_time<5)|charges=3|target.time_to_die<15)&astral_power.deficit>44
				if S.FullMoon:IsCastable() and Player:AstralPowerDeficit(FuturAstralPower()) > 44 
					and ((S.NewMoon:Charges() == 2 and S.NewMoon:RechargeP() < 5 and not moons[Player:CastID()]) 
					or (S.NewMoon:Charges() == 3 and not moons[Player:CastID()]) 
					or Target:FilteredTimeToDie("<", 15)) then
					if AR.Cast(S.FullMoon) then return ""; end
				end
				
        -- actions+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2
				if S.StellarFlare:IsAvailable() and Cache.EnemiesCount[range] < 4 and FuturAstralPower() >= 15 and Target:DebuffRefreshableCP(S.StellarFlare) and not Player:CastID()==S.StellarFlare:ID() then
					if AR.Cast(S.StellarFlare) then return ""; end
				end
				if AR.AoEON() and Cache.EnemiesCount[range] < 4 and FuturAstralPower() >= 15 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if S.StellarFlare:IsAvailable() and Value:TimeToDie()-Value:DebuffRemainsP(S.StellarFlare) > BestUnitTTD and Value:DebuffRefreshableCP(S.StellarFlare) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.StellarFlare;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
				
        -- actions+=/moonfire,cycle_targets=1,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&astral_power.deficit>7
        if ((S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.MoonFireDebuff) + ((Player:CastID() == S.LunarStrike:ID()) and 5 or 0) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.MoonFireDebuff) < PandemicThresholdBalance(S.MoonFireDebuff))) and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					if AR.Cast(S.MoonFire) then return ""; end
				end
        if AR.AoEON() and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if Value:TimeToDie() - Value:DebuffRemainsP(S.MoonFireDebuff) > BestUnitTTD 
              and ((S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.MoonFireDebuff) + ((Player:CastID() == S.LunarStrike:ID()) and 5 or 0) < 3) 
                or (not S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.MoonFireDebuff) < PandemicThresholdBalance(S.MoonFireDebuff))) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.MoonFire;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
				
        -- actions+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&astral_power.deficit>7
        if ((S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.SunFireDebuff) + ((Player:CastID() == S.SolarWrath:ID()) and 3.3 or 0) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.SunFireDebuff) < PandemicThresholdBalance(S.SunFireDebuff))) and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					if AR.Cast(S.SunFire) then return ""; end
				end
				if AR.AoEON() and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if Value:TimeToDie()-Value:DebuffRemainsP(S.SunFireDebuff) > BestUnitTTD 
              and ((S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.SunFireDebuff) + ((Player:CastID() == S.SolarWrath:ID()) and 3.3 or 0) < 3) 
                or (not S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.SunFireDebuff) < PandemicThresholdBalance(S.SunFireDebuff))) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SunFire;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
				
        -- actions+=/starfall,if=buff.oneths_overconfidence.up&(!buff.solar_solstice.up|astral_power.deficit>44|buff.celestial_alignment.up|buff.incarnation.up)
				if Player:Buff(S.OnethsOverconfidence) and (Player:BuffRemainsP(S.SolarSolstice) == 0 or Player:BuffRemainsP(S.CelestialAlignment) == 0 or Player:BuffRemainsP(S.IncarnationChosenOfElune) == 0 or Player:AstralPowerDeficit(FuturAstralPower()) > 44) then
					if AR.Cast(S.Starfall) then return ""; end
				end
				
				-- actions+=/solar_wrath,if=buff.solar_empowerment.stack=3
				if Player:BuffStack(S.SolarEmpowerment)==3 and not (Player:CastID()==S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment)==3) then
					if AR.Cast(S.SolarWrath) then return ""; end
				end
				
				-- actions+=/lunar_strike,if=buff.lunar_empowerment.stack=3
				if Player:BuffStack(S.LunarEmpowerment)==3 and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment)==3) then
					if AR.Cast(S.LunarStrike) then return ""; end
				end
        
        -- actions+=/starsurge,if=buff.oneths_intuition.up
        if Player:Buff(S.OnethsIntuition) then
					if AR.Cast(S.Starsurge) then return ""; end
				end
        
        -- actions+=/call_action_list,name=AoE,if=(active_enemies>=2&talent.stellar_drift.enabled)|active_enemies>=3
				if AR.AoEON() and ((Cache.EnemiesCount[range] >= 2 and S.StellarDrift:IsAvailable()) or Cache.EnemiesCount[range] >= 3) then
					ShouldReturn = AoE();
          if ShouldReturn then return ShouldReturn; end
				end
        
				-- actions+=/call_action_list,name=single_target
				ShouldReturn = SingleTarget();
				if ShouldReturn then return ShouldReturn; end
			
			else --moving
				-- actions+=/moonfire,cycle_targets=1,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&astral_power.deficit>7
        if ((S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.MoonFireDebuff) + ((Player:CastID() == S.LunarStrike:ID()) and 5 or 0) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.MoonFireDebuff) < PandemicThresholdBalance(S.MoonFireDebuff))) and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					if AR.Cast(S.MoonFire) then return ""; end
				end
        if AR.AoEON() and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if Value:TimeToDie()-Value:DebuffRemainsP(S.MoonFireDebuff) > BestUnitTTD and ((S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.MoonFireDebuff) + ((Player:CastID() == S.LunarStrike:ID()) and 5 or 0) < 3) or (not S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.MoonFireDebuff) < PandemicThresholdBalance(S.MoonFireDebuff))) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.MoonFire;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
				-- actions+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&astral_power.deficit>7
        if ((S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.SunFireDebuff) + ((Player:CastID() == S.SolarWrath:ID()) and 3.3 or 0) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemainsP(S.SunFireDebuff) < PandemicThresholdBalance(S.SunFireDebuff))) and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					if AR.Cast(S.SunFire) then return ""; end
				end
				if AR.AoEON() and Player:AstralPowerDeficit(FuturAstralPower()) > 7 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if Value:TimeToDie()-Value:DebuffRemainsP(S.SunFireDebuff) > BestUnitTTD and ((S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.SunFireDebuff) + ((Player:CastID() == S.SolarWrath:ID()) and 3.3 or 0) < 3) or (not S.NaturesBalance:IsAvailable() and Value:DebuffRemainsP(S.SunFireDebuff) < PandemicThresholdBalance(S.SunFireDebuff))) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SunFire;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
				
				-- actions+=/starfall,if=buff.oneths_overconfidence.up&(!buff.solar_solstice.up|astral_power.deficit>44|buff.celestial_alignment.up|buff.incarnation.up)
				if Player:Buff(S.OnethsOverconfidence) and (Player:BuffRemainsP(S.SolarSolstice) == 0 or Player:BuffRemainsP(S.CelestialAlignment) == 0 or Player:BuffRemainsP(S.IncarnationChosenOfElune) == 0 or Player:AstralPowerDeficit(FuturAstralPower()) > 44) then
					if AR.Cast(S.Starfall) then return ""; end
				end
        
        -- actions+=/starsurge,if=buff.oneths_intuition.up
        if Player:Buff(S.OnethsIntuition) then
					if AR.Cast(S.Starsurge) then return ""; end
				end
        
				--default
				if AR.AoEON() and Cache.EnemiesCount[range] >= 2 then
					if AR.Cast(S.SunFire) then return ""; end
				end
				if AR.Cast(S.MoonFire) then return ""; end
			end
		end
  end
end

AR.SetAPL(102, APL);

--- ======= SIMC =======
--- Last Update: 28/09/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/moonkin_form
-- actions.precombat+=/blessing_of_elune
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/new_moon

-- # Executed every time the actor is available.
-- actions=potion,name=potion_of_prolonged_power,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/blessing_of_elune,if=active_enemies<=2&talent.blessing_of_the_ancients.enabled&buff.blessing_of_elune.down
-- actions+=/blessing_of_elune,if=active_enemies>=3&talent.blessing_of_the_ancients.enabled&buff.blessing_of_anshe.down
-- actions+=/blood_fury,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/berserking,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/arcane_torrent,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/use_items
-- actions+=/use_item,name=tarnished_sentinel_medallion,if=cooldown.incarnation.remains>60|cooldown.celestial_alignment.remains>60
-- actions+=/call_action_list,name=fury_of_elune,if=talent.fury_of_elune.enabled&cooldown.fury_of_elune.remains<target.time_to_die
-- actions+=/call_action_list,name=ed,if=equipped.the_emerald_dreamcatcher&active_enemies<=1
-- actions+=/new_moon,if=((charges=2&recharge_time<5)|charges=3)&astral_power.deficit>14
-- actions+=/half_moon,if=((charges=2&recharge_time<5)|charges=3|(target.time_to_die<15&charges=2))&astral_power.deficit>24
-- actions+=/full_moon,if=((charges=2&recharge_time<5)|charges=3|target.time_to_die<15)&astral_power.deficit>44
-- actions+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2
-- actions+=/moonfire,cycle_targets=1,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&astral_power.deficit>7
-- actions+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&astral_power.deficit>7
-- actions+=/astral_communion,if=astral_power.deficit>=71
-- actions+=/incarnation,if=astral_power>=40
-- actions+=/celestial_alignment,if=astral_power>=40
-- actions+=/starfall,if=buff.oneths_overconfidence.up&(!buff.solar_solstice.up|astral_power.deficit>44|buff.celestial_alignment.up|buff.incarnation.up)
-- actions+=/solar_wrath,if=buff.solar_empowerment.stack=3
-- actions+=/lunar_strike,if=buff.lunar_empowerment.stack=3
-- actions+=/starsurge,if=buff.oneths_intuition.up
-- actions+=/call_action_list,name=AoE,if=(active_enemies>=2&talent.stellar_drift.enabled)|active_enemies>=3
-- actions+=/call_action_list,name=single_target

-- actions.AoE=starfall,if=debuff.stellar_empowerment.remains<gcd.max*2|astral_power.deficit<22.5|(buff.celestial_alignment.remains>8|buff.incarnation.remains>8)|target.time_to_die<8
-- actions.AoE+=/new_moon,if=astral_power.deficit>14
-- actions.AoE+=/half_moon,if=astral_power.deficit>24
-- actions.AoE+=/full_moon,if=astral_power.deficit>44
-- actions.AoE+=/warrior_of_elune
-- actions.AoE+=/lunar_strike,if=buff.warrior_of_elune.up
-- actions.AoE+=/solar_wrath,if=buff.solar_empowerment.up
-- actions.AoE+=/lunar_strike,if=buff.lunar_empowerment.up
-- actions.AoE+=/moonfire,if=equipped.lady_and_the_child&active_enemies=2&spell_haste>0.4&!(buff.celestial_alignment.up|buff.incarnation.up)
-- actions.AoE+=/lunar_strike,if=active_enemies>=4|spell_haste<0.45
-- actions.AoE+=/solar_wrath

-- actions.ed=astral_communion,if=astral_power.deficit>=75&buff.the_emerald_dreamcatcher.up
-- actions.ed+=/incarnation,if=astral_power>=60|buff.bloodlust.up
-- actions.ed+=/celestial_alignment,if=astral_power>=60&!buff.the_emerald_dreamcatcher.up
-- actions.ed+=/starsurge,if=(gcd.max*astral_power%26)>target.time_to_die
-- actions.ed+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2
-- actions.ed+=/moonfire,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
-- actions.ed+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
-- actions.ed+=/starfall,if=buff.oneths_overconfidence.up&buff.the_emerald_dreamcatcher.remains>execute_time
-- actions.ed+=/new_moon,if=astral_power.deficit>=10&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=16
-- actions.ed+=/half_moon,if=astral_power.deficit>=20&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=6
-- actions.ed+=/full_moon,if=astral_power.deficit>=40&buff.the_emerald_dreamcatcher.remains>execute_time
-- actions.ed+=/lunar_strike,if=(buff.lunar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=22.5))&spell_haste<0.4
-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.stack>1&buff.the_emerald_dreamcatcher.remains>2*execute_time&astral_power>=6&(dot.moonfire.remains>5|(dot.sunfire.remains<5.4&dot.moonfire.remains>6.6))&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=10|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15)
-- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=11&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=22.5)
-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=16&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=10|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power.deficit>=15)
-- actions.ed+=/starsurge,if=(buff.the_emerald_dreamcatcher.up&buff.the_emerald_dreamcatcher.remains<gcd.max)|astral_power>85|((buff.celestial_alignment.up|buff.incarnation.up)&astral_power>30)
-- actions.ed+=/starfall,if=buff.oneths_overconfidence.up
-- actions.ed+=/new_moon,if=astral_power.deficit>=10
-- actions.ed+=/half_moon,if=astral_power.deficit>=20
-- actions.ed+=/full_moon,if=astral_power.deficit>=40
-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up
-- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up
-- actions.ed+=/solar_wrath

-- actions.fury_of_elune=incarnation,if=astral_power>=95&cooldown.fury_of_elune.remains<=gcd
-- actions.fury_of_elune+=/fury_of_elune,if=astral_power>=95
-- actions.fury_of_elune+=/new_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=90))
-- actions.fury_of_elune+=/half_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=80))
-- actions.fury_of_elune+=/full_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=60))
-- actions.fury_of_elune+=/astral_communion,if=buff.fury_of_elune_up.up&astral_power<=25
-- actions.fury_of_elune+=/warrior_of_elune,if=buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>=35&buff.lunar_empowerment.up)
-- actions.fury_of_elune+=/lunar_strike,if=buff.warrior_of_elune.up&(astral_power<=90|(astral_power<=85&buff.incarnation.up))
-- actions.fury_of_elune+=/new_moon,if=astral_power<=90&buff.fury_of_elune_up.up
-- actions.fury_of_elune+=/half_moon,if=astral_power<=80&buff.fury_of_elune_up.up&astral_power>cast_time*12
-- actions.fury_of_elune+=/full_moon,if=astral_power<=60&buff.fury_of_elune_up.up&astral_power>cast_time*12
-- actions.fury_of_elune+=/moonfire,if=buff.fury_of_elune_up.down&remains<=6.6
-- actions.fury_of_elune+=/sunfire,if=buff.fury_of_elune_up.down&remains<5.4
-- actions.fury_of_elune+=/stellar_flare,if=remains<7.2&active_enemies=1
-- actions.fury_of_elune+=/starfall,if=(active_enemies>=2&talent.stellar_flare.enabled|active_enemies>=3)&buff.fury_of_elune_up.down&cooldown.fury_of_elune.remains>10
-- actions.fury_of_elune+=/starsurge,if=active_enemies<=2&buff.fury_of_elune_up.down&cooldown.fury_of_elune.remains>7
-- actions.fury_of_elune+=/starsurge,if=buff.fury_of_elune_up.down&((astral_power>=92&cooldown.fury_of_elune.remains>gcd*3)|(cooldown.warrior_of_elune.remains<=5&cooldown.fury_of_elune.remains>=35&buff.lunar_empowerment.stack<2))
-- actions.fury_of_elune+=/solar_wrath,if=buff.solar_empowerment.up
-- actions.fury_of_elune+=/lunar_strike,if=buff.lunar_empowerment.stack=3|(buff.lunar_empowerment.remains<5&buff.lunar_empowerment.up)|active_enemies>=2
-- actions.fury_of_elune+=/solar_wrath

-- actions.single_target=starsurge,if=astral_power.deficit<44|(buff.celestial_alignment.up|buff.incarnation.up|buff.astral_acceleration.remains>5|(set_bonus.tier21_4pc&!buff.solar_solstice.up))|(gcd.max*(astral_power%40))>target.time_to_die
-- actions.single_target+=/new_moon,if=astral_power.deficit>14&!(buff.celestial_alignment.up|buff.incarnation.up)
-- actions.single_target+=/half_moon,if=astral_power.deficit>24&!(buff.celestial_alignment.up|buff.incarnation.up)
-- actions.single_target+=/full_moon,if=astral_power.deficit>44
-- actions.single_target+=/warrior_of_elune
-- actions.single_target+=/lunar_strike,if=buff.warrior_of_elune.up
-- actions.single_target+=/solar_wrath,if=buff.solar_empowerment.up
-- actions.single_target+=/lunar_strike,if=buff.lunar_empowerment.up
-- actions.single_target+=/solar_wrath

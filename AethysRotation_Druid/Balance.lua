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
		BloodFury				= Spell(20572),
		GiftoftheNaaru			= Spell(59547),
		Shadowmeld           	= Spell(58984),
	-- Forms
		MoonkinForm 			= Spell(24858),
		BearForm 				= Spell(5487),
		CatForm 				= Spell(768),
		TravelForm 				= Spell(783),
    -- Abilities
		CelestialAlignment 		= Spell(194223),
		LunarStrike 			= Spell(194153),
		SolarWrath 				= Spell(190984),
		MoonFire 				= Spell(8921),
		MoonFireDebuff 			= Spell(164812),
		SunFire 				= Spell(93402),
		SunFireDebuff 			= Spell(164815),
		Starsurge 				= Spell(78674),
		Starfall 				= Spell(191034),
    -- Talents
		ForceofNature  			= Spell(205636),
		WarriorofElune  		= Spell(202425),
		Starlord  				= Spell(202345),
		
		Renewal  				= Spell(108235),
		DisplacerBeast  		= Spell(102280),
		WildCharge  			= Spell(102401),
		
		FeralAffinity 			= Spell(202157),
		GuardianAffinity  		= Spell(197491),
		RestorationAffinity  	= Spell(197492),
		
		SoulOfTheForest  		= Spell(114107),
		IncarnationChosenOfElune= Spell(102560),
		StellarFlare  			= Spell(202347),
		
		ShootingStars  			= Spell(202342),
		AstralCommunion  		= Spell(202359),
		BlessingofTheAncients  	= Spell(202360),
		BlessingofElune  		= Spell(202737),
		BlessingofAnshe  		= Spell(202739),
		
		FuryofElune  			= Spell(202770),
		StellarDrift  			= Spell(202354),
		NaturesBalance  		= Spell(202430),
    -- Artifact
		NewMoon 				= Spell(202767),
		HalfMoon 				= Spell(202768),
		FullMoon 				= Spell(202771),
    -- Defensive
		Barskin 				= Spell(22812),
		FrenziedRegeneration 	= Spell(22842),
		Ironfur 				= Spell(192081),
		Regrowth 				= Spell(8936),
		Rejuvenation 			= Spell(774),
		Swiftmend 				= Spell(18562),
		HealingTouch 			= Spell(5185),
    -- Utility
		Innervate 				= Spell(29166),
		SolarBeam 				= Spell(78675),
    -- Legendaries
		OnethsIntuition			= Spell(209405),
    -- Misc
		SolarEmpowerment		= Spell(164545),
		LunarEmpowerment		= Spell(164547),
  };
  local S = Spell.Druid.Balance;
-- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Balance = {
    -- Legendaries
		EmeraldDreamcatcher		= Item(137062), --1
  };
  local I = Item.Druid.Balance;
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD, BestUnitSpellToCast; -- Used for cycling
  local nextMoon;
  local currentGeneration;
  local moons={[S.NewMoon:ID()]=true, [S.HalfMoon:ID()]=true, [S.FullMoon:ID()]=true}
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Balance = AR.GUISettings.APL.Druid.Balance
  };

  
local function FuryOfElune ()
	-- actions.fury_of_elune=incarnation,if=astral_power>=95&cooldown.fury_of_elune.remains<=gcd
	-- actions+=/incarnation,if=astral_power>=40
	if S.IncarnationChosenOfElune:IsAvailable() and S.IncarnationChosenOfElune:IsCastable() and Player:AstralPower()>=(95-currentGeneration) and S.FuryofElune:Cooldown()<Player:CastRemains()+Player:GCD() then
		if AR.Cast(S.IncarnationChosenOfElune, Settings.Balance.OffGCDasOffGCD.IncarnationChosenOfElune) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/fury_of_elune,if=astral_power>=95
	if Player:AstralPower()>=(95-currentGeneration) and S.FuryofElune:Cooldown()<Player:CastRemains()+Player:GCD() then
		if AR.Cast(S.FuryofElune) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/new_moon,if=((charges=2&recharge_time<5)|charges=3) && (buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=90))
	if S.NewMoon:IsCastable() 
		and ((S.NewMoon:Charges()==2 and S.NewMoon:Recharge()<5 and not moons[Player:CastID()] ) 
		or (S.NewMoon:Charges()==3 and not moons[Player:CastID()]))
		and (Player:Buff(S.FuryofElune) or (S.FuryofElune:Cooldown()<Player:GCD()*3 and Player:AstralPower()<=(90-currentGeneration)))	then
		if AR.Cast(S.NewMoon) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/half_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=80))
	if S.HalfMoon:IsCastable() 
		and ((S.NewMoon:Charges()==2 and S.NewMoon:Recharge()<5 and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==3 and not moons[Player:CastID()])) 
		and (Player:Buff(S.FuryofElune) or (S.FuryofElune:Cooldown()<Player:GCD()*3 and Player:AstralPower()<=(80-currentGeneration))) then
		if AR.Cast(S.HalfMoon) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/full_moon,if=((charges=2&recharge_time<5)|charges=3)&&(buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>gcd*3&astral_power<=60))
	if S.FullMoon:IsCastable() 
		and ((S.NewMoon:Charges()==2 and S.NewMoon:Recharge()<5 and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==3 and not moons[Player:CastID()])) 
		and (Player:Buff(S.FuryofElune) or (S.FuryofElune:Cooldown()<Player:GCD()*3 and Player:AstralPower()<=(60-currentGeneration))) then
		if AR.Cast(S.FullMoon) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/astral_communion,if=buff.fury_of_elune_up.up&astral_power<=25
	if S.AstralCommunion:IsAvailable() and S.AstralCommunion:IsCastable() and Player:AstralPowerDeficit()>=(75+currentGeneration) then
		if AR.Cast(S.AstralCommunion, Settings.Balance.OffGCDasOffGCD.AstralCommunion) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/warrior_of_elune,if=buff.fury_of_elune_up.up|(cooldown.fury_of_elune.remains>=35&buff.lunar_empowerment.up)
	if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune)
		and (Player:Buff(S.FuryofElune) or (S.FuryofElune:Cooldown()>=35 and Player:Buff(S.LunarEmpowerment)))then
		if AR.Cast(S.WarriorofElune) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/lunar_strike,if=buff.warrior_of_elune.up&(astral_power<=90|(astral_power<=85&buff.incarnation.up))
	if S.LunarStrike:IsCastable() and Player:Buff(S.WarriorofElune) 
		and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.WarriorofElune)==1)
		and ((not Player:Buff(IncarnationChosenOfElune) and Player:AstralPower()<=(85-currentGeneration)) 
			or (Player:Buff(IncarnationChosenOfElune) and Player:AstralPower()<=(90-currentGeneration))) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/new_moon,if=astral_power<=90&buff.fury_of_elune_up.up
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges()>1 and nextMoon==S.NewMoon)
		or (S.NewMoon:Charges()==1 and nextMoon==S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==0 and S.NewMoon:Recharge()<Player:CastRemains()+Player:GCD() and nextMoon==S.NewMoon))  
		and Player:AstralPower()<=(90-currentGeneration) 
		and Player:Buff(S.FuryofElune) then
			if AR.Cast(S.NewMoon) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/half_moon,if=astral_power<=80&buff.fury_of_elune_up.up&astral_power>cast_time*12
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges()>1 and nextMoon==S.HalfMoon)
		or (S.NewMoon:Charges()==1 and nextMoon==S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==0 and S.NewMoon:Recharge()<Player:CastRemains()+Player:GCD() and nextMoon==S.HalfMoon))
		and Player:AstralPower()<=(80-currentGeneration)
		and Player:Buff(S.FuryofElune)  then	
			if AR.Cast(S.HalfMoon) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/full_moon,if=astral_power<=60&buff.fury_of_elune_up.up&astral_power>cast_time*12
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges()>1 and nextMoon==S.FullMoon)
		or (S.NewMoon:Charges()==1 and nextMoon==S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==0 and S.NewMoon:Recharge()<Player:CastRemains()+Player:GCD() and nextMoon==S.FullMoon)) 
		and Player:AstralPower()<=(60-currentGeneration)
		and Player:Buff(S.FuryofElune)  then
			if AR.Cast(S.FullMoon) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/moonfire,if=buff.fury_of_elune_up.down&remains<=6.6
	if not Player:Buff(S.FuryofElune) and Target:DebuffRemains(S.MoonFireDebuff) < 6.6  then
		if AR.Cast(S.MoonFire) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/sunfire,if=buff.fury_of_elune_up.down&remains<5.4
	if not Player:Buff(S.FuryofElune) and Target:DebuffRemains(S.SunFireDebuff) < 5.4  then
		if AR.Cast(S.SunFire) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/stellar_flare,if=remains<7.2&active_enemies=1
	if S.StellarFlare:IsAvailable() and Cache.EnemiesCount[45]==1 and Player:AstralPower()>=(15-currentGeneration) and Target:DebuffRemains(S.StellarFlare) < 7.2 then
		if AR.Cast(S.StellarFlare) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/starfall,if=(active_enemies>=2&talent.stellar_flare.enabled|active_enemies>=3)&buff.fury_of_elune_up.down&cooldown.fury_of_elune.remains>10
	if AR.AoEON() and ((Cache.EnemiesCount[45]>=2 and S.StellarFlare:IsAvailable()) or (Cache.EnemiesCount[45]>=3 and not S.StellarFlare:IsAvailable()))
		and not Player:Buff(S.FuryofElune) and S.FuryofElune:Cooldown()>10 then
		if AR.Cast(S.Starfall) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/starsurge,if=active_enemies<=2&buff.fury_of_elune_up.down&cooldown.fury_of_elune.remains>7
	if S.Starsurge:IsCastable() and Player:AstralPower()>=(40-currentGeneration) 
		and Cache.EnemiesCount[45]<=2 and not Player:Buff(S.FuryofElune) and S.FuryofElune:Cooldown()>7 then
		if AR.Cast(S.Starsurge) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/starsurge,if=buff.fury_of_elune_up.down&((astral_power>=92&cooldown.fury_of_elune.remains>gcd*3)|(cooldown.warrior_of_elune.remains<=5&cooldown.fury_of_elune.remains>=35&buff.lunar_empowerment.stack<2))
	if S.Starsurge:IsCastable() and not Player:Buff(S.FuryofElune) 
	and ((Player:AstralPower()>=(92-currentGeneration) and S.FuryofElune:Cooldown()>Player:GCD()*3) 
		or (S.WarriorofElune:Cooldown()<=5 and S.FuryofElune:Cooldown()>=35  and Player:BuffStack(S.WarriorofElune)<2)) then
		if AR.Cast(S.Starsurge) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/solar_wrath,if=buff.solar_empowerment.up
	if Player:Buff(S.SolarEmpowerment) 
		and not (Player:CastID()==S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment)==1) then
		if AR.Cast(S.SolarWrath) then return "Cast"; end
	end	
	-- actions.fury_of_elune+=/lunar_strike,if=buff.lunar_empowerment.stack=3|(buff.lunar_empowerment.remains<5&buff.lunar_empowerment.up)|active_enemies>=2
	if (Player:BuffStack(S.LunarEmpowerment)==3 
		or (Player:Buff(S.LunarEmpowerment) and Player:BuffRemains(S.LunarEmpowerment)<5)
		or Cache.EnemiesCount[45]>=2) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end
	-- actions.fury_of_elune+=/solar_wrath
	if AR.Cast(S.SolarWrath) then return "Cast"; end

end 
  
local function Dreamcatcher ()
	-- actions.ed=astral_communion,if=astral_power.deficit>=75&buff.the_emerald_dreamcatcher.up
	-- actions.ed+=/incarnation,if=astral_power>=85&!buff.the_emerald_dreamcatcher.up|buff.bloodlust.up
	-- actions.ed+=/celestial_alignment,if=astral_power>=85&!buff.the_emerald_dreamcatcher.up
	-- actions.ed+=/starsurge,if=(buff.celestial_alignment.up&buff.celestial_alignment.remains<(10))|(buff.incarnation.up&buff.incarnation.remains<(3*execute_time)&astral_power>78)|(buff.incarnation.up&buff.incarnation.remains<(2*execute_time)&astral_power>52)|(buff.incarnation.up&buff.incarnation.remains<execute_time&astral_power>26)
	-- actions.ed+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2&astral_power>=15
	-- actions.ed+=/moonfire,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
	-- actions.ed+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
	-- actions.ed+=/starfall,if=buff.oneths_overconfidence.up&buff.the_emerald_dreamcatcher.remains>execute_time&remains<2
	-- actions.ed+=/half_moon,if=astral_power<=80&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=6
	-- actions.ed+=/full_moon,if=astral_power<=60&buff.the_emerald_dreamcatcher.remains>execute_time
	-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.stack>1&buff.the_emerald_dreamcatcher.remains>2*execute_time&astral_power>=6&(dot.moonfire.remains>5|(dot.sunfire.remains<5.4&dot.moonfire.remains>6.6))&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=90|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=85)
	-- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=11&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=85|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=77.5)
	-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=16&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=90|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=85)
	-- actions.ed+=/starsurge,if=(buff.the_emerald_dreamcatcher.up&buff.the_emerald_dreamcatcher.remains<gcd.max)|astral_power>90|((buff.celestial_alignment.up|buff.incarnation.up)&astral_power>=85)|(buff.the_emerald_dreamcatcher.up&astral_power>=77.5&(buff.celestial_alignment.up|buff.incarnation.up))
	-- actions.ed+=/starfall,if=buff.oneths_overconfidence.up&remains<2
	-- actions.ed+=/new_moon,if=astral_power<=90
	-- actions.ed+=/half_moon,if=astral_power<=80
	-- actions.ed+=/full_moon,if=astral_power<=60&((cooldown.incarnation.remains>65&cooldown.full_moon.charges>0)|(cooldown.incarnation.remains>50&cooldown.full_moon.charges>1)|(cooldown.incarnation.remains>25&cooldown.full_moon.charges>2))
	-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up
	-- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up
	-- actions.ed+=/solar_wrath
end  

local function CelestialAlignmentPhase ()
	-- actions.celestial_alignment_phase=starfall,if=((active_enemies>=2&talent.stellar_drift.enabled)|active_enemies>=3)
	if AR.AoEON() and S.Starfall:IsCastable() and  Player:AstralPower()>=(60-currentGeneration) 
		and ((Cache.EnemiesCount[45]==2 and S.StellarDrift:IsAvailable()) or Cache.EnemiesCount[45]>=3) then
		if AR.Cast(S.Starfall) then return "Cast"; end
	end
	-- actions.celestial_alignment_phase+=/starsurge,if=active_enemies<=2
	if S.Starsurge:IsCastable() and  Player:AstralPower()>=(40-currentGeneration) 
		and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[45]<=2)) then
		if AR.Cast(S.Starsurge) then return "Cast"; end
	end
	-- actions.celestial_alignment_phase+=/warrior_of_elune
	if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune) then
		if AR.Cast(S.WarriorofElune) then return "Cast"; end
	end
	-- actions.celestial_alignment_phase+=/lunar_strike,if=buff.warrior_of_elune.up
	if Player:Buff(S.LunarEmpowerment) and S.LunarStrike:IsCastable() and Player:Buff(S.WarriorofElune) 
		and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment)==1) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end
	-- actions.celestial_alignment_phase+=/solar_wrath,if=buff.solar_empowerment.up
	if Player:Buff(S.SolarEmpowerment) and S.SolarWrath:IsCastable()
		and not (Player:CastID()==S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment)==1) then
		if AR.Cast(S.SolarWrath) then return "Cast"; end
	end	
	-- actions.celestial_alignment_phase+=/lunar_strike,if=buff.lunar_empowerment.up
	if Player:Buff(S.LunarEmpowerment) and S.LunarStrike:IsCastable() 
		and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment)==1) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end
	-- actions.celestial_alignment_phase+=/solar_wrath,if=talent.natures_balance.enabled&dot.sunfire_dmg.remains<5&cast_time<dot.sunfire_dmg.remains
	if S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 5 and S.SolarWrath:CastTime()<Target:DebuffRemains(S.MoonFireDebuff) then
		if AR.Cast(S.SolarWrath) then return "Cast"; end
	end	
	-- actions.celestial_alignment_phase+=/lunar_strike,if=(talent.natures_balance.enabled&dot.moonfire_dmg.remains<5&cast_time<dot.moonfire_dmg.remains)|active_enemies>=2
	if (S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 5 and S.LunarStrike:CastTime()<Target:DebuffRemains(S.MoonFireDebuff)) 
		or (AR.AoEON() and Cache.EnemiesCount[45]>=2) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end	
	-- actions.celestial_alignment_phase+=/solar_wrath
	if AR.Cast(S.SolarWrath) then return "Cast"; end
end

local function SingleTarget ()
	-- actions.single_target=new_moon,if=astral_power<=90
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges()>1 and nextMoon==S.NewMoon)
		or (S.NewMoon:Charges()==1 and nextMoon==S.NewMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==0 and S.NewMoon:Recharge()<Player:CastRemains()+Player:GCD() and nextMoon==S.NewMoon))  
		and Player:AstralPower()<=(90-currentGeneration) then
			if AR.Cast(S.NewMoon) then return "Cast"; end
	end
	-- actions.single_target+=/half_moon,if=astral_power<=80
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges()>1 and nextMoon==S.HalfMoon)
		or (S.NewMoon:Charges()==1 and nextMoon==S.HalfMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==0 and S.NewMoon:Recharge()<Player:CastRemains()+Player:GCD() and nextMoon==S.HalfMoon))
		and Player:AstralPower()<=(80-currentGeneration) then	
			if AR.Cast(S.HalfMoon) then return "Cast"; end
	end
	-- actions.single_target+=/full_moon,if=astral_power<=60 
	if S.NewMoon:IsAvailable() 
		and ((S.NewMoon:Charges()>1 and nextMoon==S.FullMoon)
		or (S.NewMoon:Charges()==1 and nextMoon==S.FullMoon and not moons[Player:CastID()]) 
		or (S.NewMoon:Charges()==0 and S.NewMoon:Recharge()<Player:CastRemains()+Player:GCD() and nextMoon==S.FullMoon)) 
		and Player:AstralPower()<=(60-currentGeneration) then
			if AR.Cast(S.FullMoon) then return "Cast"; end
	end
	-- actions.single_target+=/starfall,if=((active_enemies>=2&talent.stellar_drift.enabled)|active_enemies>=3)
	if AR.AoEON() and S.Starfall:IsCastable() and  Player:AstralPower()>=(60-currentGeneration) 
		and ( (Cache.EnemiesCount[45]==2 and S.StellarDrift:IsAvailable()) or Cache.EnemiesCount[45]>=3) then
		if AR.Cast(S.Starfall) then return "Cast"; end
	end
	-- actions.single_target+=/starsurge,if=active_enemies<=2
	if S.Starsurge:IsCastable() and Player:AstralPower()>=(40-currentGeneration) 
		and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[45]<=2)) then
		if AR.Cast(S.Starsurge) then return "Cast"; end
	end
	-- actions.single_target+=/warrior_of_elune
	if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune) then
		if AR.Cast(S.WarriorofElune, Settings.Balance.OffGCDasOffGCD.WarriorofElune) then return "Cast"; end
	end
	-- actions.single_target+=/lunar_strike,if=buff.warrior_of_elune.up
	if Player:Buff(S.WarriorofElune)
		and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.WarriorofElune)==1) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end
	-- actions.single_target+=/solar_wrath,if=buff.solar_empowerment.up
	if (Player:Buff(S.SolarEmpowerment) or Player:CastID()==S.Starsurge:ID()) and S.SolarWrath:IsCastable() 
		and not (Player:CastID()==S.SolarWrath:ID() and Player:BuffStack(S.SolarEmpowerment)==1) then
		if AR.Cast(S.SolarWrath) then return "Cast"; end
	end	
	-- actions.single_target+=/lunar_strike,if=buff.lunar_empowerment.up
	if Player:Buff(S.LunarEmpowerment)
		and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.LunarEmpowerment)==1) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end
	-- actions.single_target+=/solar_wrath,if=talent.natures_balance.enabled&dot.sunfire_dmg.remains<5&cast_time<dot.sunfire_dmg.remains
	if S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 5 and S.SolarWrath:CastTime()<Target:DebuffRemains(S.MoonFireDebuff) then
		if AR.Cast(S.SolarWrath) then return "Cast"; end
	end	
	-- actions.single_target+=/lunar_strike,if=(talent.natures_balance.enabled&dot.moonfire_dmg.remains<5&cast_time<dot.moonfire_dmg.remains)|active_enemies>=2
	if (S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 5 and S.LunarStrike:CastTime()<Target:DebuffRemains(S.MoonFireDebuff)) 
		or (AR.AoEON() and Cache.EnemiesCount[45]>=2) then
		if AR.Cast(S.LunarStrike) then return "Cast"; end
	end	
	-- actions.single_target+=/solar_wrath
	if AR.Cast(S.SolarWrath) then return "Cast"; end
end

local function CDs ()
	-- actions+=/blood_fury,if=buff.celestial_alignment.up|buff.incarnation.up
	if S.BloodFury:IsAvailable() and S.BloodFury:IsCastable() and (Player:Buff(S.IncarnationChosenOfElune) or Player:Buff(S.CelestialAlignment)) then
		if AR.Cast(S.BloodFury, Settings.Balance.OffGCDasOffGCD.BloodFury) then return "Cast"; end
	end
	-- actions+=/berserking,if=buff.celestial_alignment.up|buff.incarnation.up
	if S.Berserking:IsAvailable() and S.Berserking:IsCastable() and (Player:Buff(S.IncarnationChosenOfElune) or Player:Buff(S.CelestialAlignment)) then
		if AR.Cast(S.Berserking, Settings.Balance.OffGCDasOffGCD.Berserking) then return "Cast"; end
	end
	-- actions+=/arcane_torrent,if=buff.celestial_alignment.up|buff.incarnation.up
	if S.ArcaneTorrent:IsAvailable() and S.ArcaneTorrent:IsCastable() and (Player:Buff(S.IncarnationChosenOfElune) or Player:Buff(S.CelestialAlignment)) then
		if AR.Cast(S.ArcaneTorrent, Settings.Balance.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
	end
	-- actions+=/incarnation,if=astral_power>=40
	if S.IncarnationChosenOfElune:IsAvailable() and S.IncarnationChosenOfElune:IsCastable() and Player:AstralPower()>=(40-currentGeneration) and not S.FuryofElune:IsAvailable() then
		if AR.Cast(S.IncarnationChosenOfElune, Settings.Balance.OffGCDasOffGCD.IncarnationChosenOfElune) then return "Cast"; end
	end
	-- actions+=/celestial_alignment,if=astral_power>=40
	if S.CelestialAlignment:IsAvailable() and S.CelestialAlignment:IsCastable() and Player:AstralPower()>=(40-currentGeneration) then
		if AR.Cast(S.CelestialAlignment, Settings.Balance.OffGCDasOffGCD.CelestialAlignment) then return "Cast"; end
	end
	-- actions+=/astral_communion,if=astral_power.deficit>=75
	if S.AstralCommunion:IsAvailable() and S.AstralCommunion:IsCastable() and Player:AstralPowerDeficit()>=(75+currentGeneration) and not S.FuryofElune:IsAvailable() then
		if AR.Cast(S.AstralCommunion, Settings.Balance.OffGCDasOffGCD.AstralCommunion) then return "Cast"; end
	end
end

local function nextMoonCalculation()
	if not S.NewMoon:IsAvailable() then return nil; end
	if Player:IsCasting() then
		if Player:CastID()== S.NewMoon:ID() then return S.HalfMoon end
		if Player:CastID()== S.HalfMoon:ID() then return S.FullMoon end
		if Player:CastID()== S.FullMoon:ID() then return S.NewMoon end
	end
	if S.NewMoon:IsCastable() then return S.NewMoon end
	if S.HalfMoon:IsCastable() then return S.HalfMoon end
	if S.FullMoon:IsCastable() then return S.FullMoon end
end

local function currentGenerationCalculation()
	if not Player:IsCasting() then return 0; end
	if Player:CastID()==S.NewMoon:ID() then return 10; end
	if Player:CastID()==S.HalfMoon:ID() then return 20; end
	if Player:CastID()==S.FullMoon:ID() then return 40; end
	if Player:CastID()==S.SolarWrath:ID() then return (Player:Buff(S.BlessingofElune) and 10 or 8); end
	if Player:CastID()==S.LunarStrike:ID() then return (Player:Buff(S.BlessingofElune) and 15 or 10); end
end
  
-- APL Main
local function APL ()
	-- Unit Update
    AC.GetEnemies(45);
	
	--Buffs
	if not Player:Buff(S.MoonkinForm) then
		if AR.Cast(S.MoonkinForm, Settings.Balance.GCDasOffGCD.MoonkinForm) then return "Cast"; end
	end
	
	-- Out of Combat
    if not Player:AffectingCombat() then
		if (Cache.EnemiesCount[45]<=2 or not AR.AoEON()) and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and Player:BuffRemains(S.BlessingofElune)==0 then
			if AR.Cast(S.BlessingofElune, Settings.Balance.OffGCDasOffGCD.BlessingofElune) then return "Cast"; end
		end
		if AR.AoEON() and Cache.EnemiesCount[45]>=3 and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and Player:BuffRemains(S.BlessingofAnshe)==0 then
			if AR.Cast(S.BlessingofAnshe, Settings.Balance.OffGCDasOffGCD.BlessingofAnshe) then return "Cast"; end
		end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ DBM Count
      -- Opener
		nextMoon = nextMoonCalculation()
		if Everyone.TargetIsValid() and Target:IsInRange(45) then
			if S.NewMoon:IsAvailable() and  nextMoon:IsCastable() then
				if AR.Cast(nextMoon) then return "Cast"; end
			end
			
			if AR.Cast(S.SolarWrath) then return "Cast"; end
		end
		
		return;
    end
	
	-- In Combat
    if Everyone.TargetIsValid() then
		nextMoon = nextMoonCalculation()
		currentGeneration = currentGenerationCalculation()
		if Target:IsInRange(45) then --in range
			--CD usage
			if AR.CDsON() then
				ShouldReturn = CDs();
				if ShouldReturn then return ShouldReturn; end
			end
		
			-- actions+=/blessing_of_elune,if=active_enemies<=2&talent.blessing_of_the_ancients.enabled&buff.blessing_of_elune.down
			-- actions+=/blessing_of_elune,if=active_enemies>=3&talent.blessing_of_the_ancients.enabled&buff.blessing_of_anshe.down
			if (Cache.EnemiesCount[45]<=2 or not AR.AoEON()) and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and Player:BuffRemains(S.BlessingofElune)==0 then
				if AR.Cast(S.BlessingofElune, Settings.Balance.OffGCDasOffGCD.BlessingofElune) then return "Cast"; end
			end
			if AR.AoEON() and Cache.EnemiesCount[45]>=3 and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and Player:BuffRemains(S.BlessingofAnshe)==0 then
				if AR.Cast(S.BlessingofAnshe, Settings.Balance.OffGCDasOffGCD.BlessingofAnshe) then return "Cast"; end
			end
			
			-- actions+=/call_action_list,name=fury_of_elune,if=talent.fury_of_elune.enabled&cooldown.fury_of_elue.remains<target.time_to_die
			if S.FuryofElune:IsAvailable() and S.FuryofElune:Cooldown()<Target:TimeToDie() then
				ShouldReturn = FuryOfElune();
				if ShouldReturn then return ShouldReturn; end
			end
			
			-- actions+=/call_action_list,name=ed,if=equipped.the_emerald_dreamcatcher&active_enemies<=2
			if (I.EmeraldDreamcatcher:IsEquipped(1) and 1 or 0) and Cache.EnemiesCount[45]<=2 then
				-- TODO : ED
				--ShouldReturn = Dreamcatcher ();
				if ShouldReturn then return ShouldReturn; end
			end
			
				
			--static
			if GetUnitSpeed("player") == 0 then	
				-- actions+=/new_moon,if=(charges=2&recharge_time<5)|charges=3
				if S.NewMoon:IsCastable() 
					and ((S.NewMoon:Charges()==2 and S.NewMoon:Recharge()<5 and not moons[Player:CastID()] ) 
					or (S.NewMoon:Charges()==3 and not moons[Player:CastID()])) then
					if AR.Cast(S.NewMoon) then return "Cast"; end
				end
				
				-- actions+=/half_moon,if=(charges=2&recharge_time<5)|charges=3|(target.time_to_die<15&charges=2)
				if S.HalfMoon:IsCastable() 
					and ((S.NewMoon:Charges()==2 and S.NewMoon:Recharge()<5 and not moons[Player:CastID()]) 
					or (S.NewMoon:Charges()==3 and not moons[Player:CastID()]) 
					or (S.NewMoon:Charges()==2 and Target:TimeToDie()<15)) then
					if AR.Cast(S.HalfMoon) then return "Cast"; end
				end
				
				-- actions+=/full_moon,if=(charges=2&recharge_time<5)|charges=3|target.time_to_die<15
				if S.FullMoon:IsCastable() 
					and ((S.NewMoon:Charges()==2 and S.NewMoon:Recharge()<5 and not moons[Player:CastID()]) 
					or (S.NewMoon:Charges()==3 and not moons[Player:CastID()]) 
					or (Target:TimeToDie()<15)) then
					if AR.Cast(S.FullMoon) then return "Cast"; end
				end
				
				-- actions+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2&astral_power>=15
				if S.StellarFlare:IsAvailable() and Cache.EnemiesCount[45]<4 and Player:AstralPower()>=(15-currentGeneration) and Target:DebuffRemains(S.StellarFlare) < 7.2 then
					if AR.Cast(S.StellarFlare) then return "Cast"; end
				end
				--multidoting Stellar Flare
				if AR.AoEON() and Cache.EnemiesCount[45]<4 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[45]) do
						if (Value:TimeToDie()-Value:DebuffRemains(S.StellarFlare) > BestUnitTTD and Value:DebuffRemains(S.StellarFlare)< 3*Player:GCD()) 
							or (Value:TimeToDie() > 10 and BestUnitSpellToCast == S.StellarFlare and Value:DebuffRemains(S.StellarFlare)< 3*Player:GCD()) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.StellarFlare;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
					end
				end
				
				-- actions+=/moonfire,cycle_targets=1,if=(talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled)
				if (S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 6.6) then
					if AR.Cast(S.MoonFire) then return "Cast"; end
				end
				
				-- actions+=/sunfire,if=(talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled)
				if (S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.SunFireDebuff) < 3) or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.SunFireDebuff) < 5.4) then
					if AR.Cast(S.SunFire) then return "Cast"; end
				end
				
				--multidoting Moon/Sun
				if AR.AoEON() then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[45]) do
						if (Value:TimeToDie()-Value:DebuffRemains(S.MoonFireDebuff) > BestUnitTTD and Value:DebuffRemains(S.MoonFireDebuff)< 3*Player:GCD()) 
							or (Value:TimeToDie() > 10 and BestUnitSpellToCast == S.MoonFire and Value:DebuffRemains(S.MoonFireDebuff)< 3*Player:GCD()) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.MoonFire;
						elseif Value:TimeToDie()-Value:DebuffRemains(S.SunFireDebuff) > BestUnitTTD
							and Value:DebuffRemains(S.SunFireDebuff)< 3*Player:GCD() and BestUnitSpellToCast ~= S.MoonFire then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SunFire;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
					end
				end
				
				-- actions+=/starfall,if=buff.oneths_overconfidence.up
				if Player:Buff(S.OnethsIntuition) then
					if AR.Cast(S.Starfall) then return "Cast"; end
				end
				
				-- actions+=/solar_wrath,if=buff.solar_empowerment.stack=3
				if Player:BuffStack(S.SolarEmpowerment)==3 then
					if AR.Cast(S.SolarWrath) then return "Cast"; end
				end
				
				-- actions+=/lunar_strike,if=buff.lunar_empowerment.stack=3
				if Player:BuffStack(S.LunarEmpowerment)==3 then
					if AR.Cast(S.LunarStrike) then return "Cast"; end
				end
				
				-- actions+=/call_action_list,name=celestial_alignment_phase,if=buff.celestial_alignment.up|buff.incarnation.up
				if Player:Buff(S.CelestialAlignment) or Player:Buff(S.IncarnationChosenOfElune) then
					ShouldReturn = CelestialAlignmentPhase();
					if ShouldReturn then return ShouldReturn; end
				end
				
				-- actions+=/call_action_list,name=single_target
				ShouldReturn = SingleTarget();
				if ShouldReturn then return ShouldReturn; end
			
			--moving
			else
				-- actions+=/blessing_of_elune,if=active_enemies<=2&talent.blessing_of_the_ancients.enabled&buff.blessing_of_elune.down
				-- actions+=/blessing_of_elune,if=active_enemies>=3&talent.blessing_of_the_ancients.enabled&buff.blessing_of_anshe.down
				if (Cache.EnemiesCount[45]<=2 and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and not Player:Buff(S.BlessingofElune) )
					or (AR.AoEON() and Cache.EnemiesCount[45]>=3 and S.BlessingofTheAncients:IsAvailable() and S.BlessingofTheAncients:IsCastable() and not Player:Buff(S.BlessingofAnshe)) then
					if AR.Cast(S.BlessingofElune, Settings.Balance.OffGCDasOffGCD.BlessingofElune) then return "Cast"; end
				end
				-- actions+=/moonfire,cycle_targets=1,if=(talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled)
				if (S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 3) 
					or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.MoonFireDebuff) < 6.6) then
					if AR.Cast(S.MoonFire) then return "Cast"; end
				end
				-- actions+=/sunfire,if=(talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled)
				if (S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.SunFireDebuff) < 3) 
					or (not S.NaturesBalance:IsAvailable() and Target:DebuffRemains(S.SunFireDebuff) < 5.4) then
					if AR.Cast(S.SunFire) then return "Cast"; end
				end
				--multidoting Moon/Sun
				if AR.AoEON() then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[45]) do
						if (Value:TimeToDie()-Value:DebuffRemains(S.MoonFireDebuff) > BestUnitTTD and Value:DebuffRemains(S.MoonFireDebuff)< 3*Player:GCD()) 
							or (Value:TimeToDie() > 10 and BestUnitSpellToCast == S.MoonFire and Value:DebuffRemains(S.MoonFireDebuff)< 3*Player:GCD()) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.MoonFire;
						elseif Value:TimeToDie()-Value:DebuffRemains(S.SunFireDebuff) > BestUnitTTD
							and Value:DebuffRemains(S.SunFireDebuff)< 3*Player:GCD() and BestUnitSpellToCast ~= S.MoonFire then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SunFire;
						end					
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
					end
				end
				-- actions+=/starfall,if=buff.oneths_overconfidence.up
				if Player:Buff(S.OnethsIntuition) then
					if AR.Cast(S.Starfall) then return "Cast"; end
				end
				-- actions.celestial_alignment_phase+=/starsurge,if=active_enemies<=2
				if S.Starsurge:IsCastable() and  Player:AstralPower()>=(40-currentGeneration) 
					and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[45]<=2)) then
					if AR.Cast(S.Starsurge) then return "Cast"; end
				end
				-- actions.celestial_alignment_phase+=/warrior_of_elune
				if S.WarriorofElune:IsAvailable() and S.WarriorofElune:IsCastable() and not Player:Buff(S.WarriorofElune) then
					if AR.Cast(S.WarriorofElune) then return "Cast"; end
				end
				-- actions.celestial_alignment_phase+=/lunar_strike,if=buff.warrior_of_elune.up
				if S.LunarStrike:IsCastable() and Player:Buff(S.WarriorofElune) 
					and not (Player:CastID()==S.LunarStrike:ID() and Player:BuffStack(S.WarriorofElune)==1) then
					if AR.Cast(S.LunarStrike) then return "Cast"; end
				end
				--default
				if AR.AoEON() and Cache.EnemiesCount[45]>=2 then
					if AR.Cast(S.SunFire) then return "Cast"; end
				end
				if AR.Cast(S.MoonFire) then return "Cast"; end
			end
		end
	end
end
AR.SetAPL(102, APL);

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=flask_of_the_whispered_pact
-- actions.precombat+=/food,type=azshari_salad
-- actions.precombat+=/augmentation,type=defiled
-- actions.precombat+=/moonkin_form
-- actions.precombat+=/blessing_of_elune
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=deadly_grace
-- actions.precombat+=/new_moon

-- # Executed every time the actor is available.
-- actions=potion,name=deadly_grace,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/blessing_of_elune,if=active_enemies<=2&talent.blessing_of_the_ancients.enabled&buff.blessing_of_elune.down
-- actions+=/blessing_of_elune,if=active_enemies>=3&talent.blessing_of_the_ancients.enabled&buff.blessing_of_anshe.down
-- actions+=/blood_fury,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/berserking,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/arcane_torrent,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/call_action_list,name=fury_of_elune,if=talent.fury_of_elune.enabled&cooldown.fury_of_elue.remains<target.time_to_die
-- actions+=/call_action_list,name=ed,if=equipped.the_emerald_dreamcatcher&active_enemies<=2
-- actions+=/new_moon,if=(charges=2&recharge_time<5)|charges=3
-- actions+=/half_moon,if=(charges=2&recharge_time<5)|charges=3|(target.time_to_die<15&charges=2)
-- actions+=/full_moon,if=(charges=2&recharge_time<5)|charges=3|target.time_to_die<15
-- actions+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2&astral_power>=15
-- actions+=/moonfire,cycle_targets=1,if=(talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled)
-- actions+=/sunfire,if=(talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled)
-- actions+=/astral_communion,if=astral_power.deficit>=75
-- actions+=/incarnation,if=astral_power>=40
-- actions+=/celestial_alignment,if=astral_power>=40
-- actions+=/starfall,if=buff.oneths_overconfidence.up
-- actions+=/solar_wrath,if=buff.solar_empowerment.stack=3
-- actions+=/lunar_strike,if=buff.lunar_empowerment.stack=3
-- actions+=/call_action_list,name=celestial_alignment_phase,if=buff.celestial_alignment.up|buff.incarnation.up
-- actions+=/call_action_list,name=single_target

-- actions.celestial_alignment_phase=starfall,if=((active_enemies>=2&talent.stellar_drift.enabled)|active_enemies>=3)
-- actions.celestial_alignment_phase+=/starsurge,if=active_enemies<=2
-- actions.celestial_alignment_phase+=/warrior_of_elune
-- actions.celestial_alignment_phase+=/lunar_strike,if=buff.warrior_of_elune.up
-- actions.celestial_alignment_phase+=/solar_wrath,if=buff.solar_empowerment.up
-- actions.celestial_alignment_phase+=/lunar_strike,if=buff.lunar_empowerment.up
-- actions.celestial_alignment_phase+=/solar_wrath,if=talent.natures_balance.enabled&dot.sunfire_dmg.remains<5&cast_time<dot.sunfire_dmg.remains
-- actions.celestial_alignment_phase+=/lunar_strike,if=(talent.natures_balance.enabled&dot.moonfire_dmg.remains<5&cast_time<dot.moonfire_dmg.remains)|active_enemies>=2
-- actions.celestial_alignment_phase+=/solar_wrath

-- actions.ed=astral_communion,if=astral_power.deficit>=75&buff.the_emerald_dreamcatcher.up
-- actions.ed+=/incarnation,if=astral_power>=85&!buff.the_emerald_dreamcatcher.up|buff.bloodlust.up
-- actions.ed+=/celestial_alignment,if=astral_power>=85&!buff.the_emerald_dreamcatcher.up
-- actions.ed+=/starsurge,if=(buff.celestial_alignment.up&buff.celestial_alignment.remains<(10))|(buff.incarnation.up&buff.incarnation.remains<(3*execute_time)&astral_power>78)|(buff.incarnation.up&buff.incarnation.remains<(2*execute_time)&astral_power>52)|(buff.incarnation.up&buff.incarnation.remains<execute_time&astral_power>26)
-- actions.ed+=/stellar_flare,cycle_targets=1,max_cycle_targets=4,if=active_enemies<4&remains<7.2&astral_power>=15
-- actions.ed+=/moonfire,if=((talent.natures_balance.enabled&remains<3)|(remains<6.6&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
-- actions.ed+=/sunfire,if=((talent.natures_balance.enabled&remains<3)|(remains<5.4&!talent.natures_balance.enabled))&(buff.the_emerald_dreamcatcher.remains>gcd.max|!buff.the_emerald_dreamcatcher.up)
-- actions.ed+=/starfall,if=buff.oneths_overconfidence.up&buff.the_emerald_dreamcatcher.remains>execute_time&remains<2
-- actions.ed+=/half_moon,if=astral_power<=80&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=6
-- actions.ed+=/full_moon,if=astral_power<=60&buff.the_emerald_dreamcatcher.remains>execute_time
-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.stack>1&buff.the_emerald_dreamcatcher.remains>2*execute_time&astral_power>=6&(dot.moonfire.remains>5|(dot.sunfire.remains<5.4&dot.moonfire.remains>6.6))&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=90|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=85)
-- actions.ed+=/lunar_strike,if=buff.lunar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=11&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=85|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=77.5)
-- actions.ed+=/solar_wrath,if=buff.solar_empowerment.up&buff.the_emerald_dreamcatcher.remains>execute_time&astral_power>=16&(!(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=90|(buff.celestial_alignment.up|buff.incarnation.up)&astral_power<=85)
-- actions.ed+=/starsurge,if=(buff.the_emerald_dreamcatcher.up&buff.the_emerald_dreamcatcher.remains<gcd.max)|astral_power>90|((buff.celestial_alignment.up|buff.incarnation.up)&astral_power>=85)|(buff.the_emerald_dreamcatcher.up&astral_power>=77.5&(buff.celestial_alignment.up|buff.incarnation.up))
-- actions.ed+=/starfall,if=buff.oneths_overconfidence.up&remains<2
-- actions.ed+=/new_moon,if=astral_power<=90
-- actions.ed+=/half_moon,if=astral_power<=80
-- actions.ed+=/full_moon,if=astral_power<=60&((cooldown.incarnation.remains>65&cooldown.full_moon.charges>0)|(cooldown.incarnation.remains>50&cooldown.full_moon.charges>1)|(cooldown.incarnation.remains>25&cooldown.full_moon.charges>2))
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

-- actions.single_target=new_moon,if=astral_power<=90
-- actions.single_target+=/half_moon,if=astral_power<=80
-- actions.single_target+=/full_moon,if=astral_power<=60
-- actions.single_target+=/starfall,if=((active_enemies>=2&talent.stellar_drift.enabled)|active_enemies>=3)
-- actions.single_target+=/starsurge,if=active_enemies<=2
-- actions.single_target+=/warrior_of_elune
-- actions.single_target+=/lunar_strike,if=buff.warrior_of_elune.up
-- actions.single_target+=/solar_wrath,if=buff.solar_empowerment.up
-- actions.single_target+=/lunar_strike,if=buff.lunar_empowerment.up
-- actions.single_target+=/solar_wrath,if=talent.natures_balance.enabled&dot.sunfire_dmg.remains<5&cast_time<dot.sunfire_dmg.remains
-- actions.single_target+=/lunar_strike,if=(talent.natures_balance.enabled&dot.moonfire_dmg.remains<5&cast_time<dot.moonfire_dmg.remains)|active_enemies>=2
-- actions.single_target+=/solar_wrath

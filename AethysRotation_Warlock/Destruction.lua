--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Warlock = AR.Commons.Warlock;
  -- Spells
  if not Spell.Warlock then Spell.Warlock = {}; end
  Spell.Warlock.Destruction = {
    -- Racials
	ArcaneTorrent			= Spell(25046),
	Berserking				= Spell(26297),
	BloodFury				  = Spell(20572),
	GiftoftheNaaru		= Spell(59547),
	Shadowmeld        = Spell(58984),
    
    -- Abilities
  Incinerate 				= Spell(29722),
	Immolate 				  = Spell(348),
	ImmolateDebuff 		= Spell(157736),
	Conflagrate 			= Spell(17962),
	ChaosBolt 				= Spell(116858),
	DrainLife 				= Spell(234153),
	RainOfFire 				= Spell(5740),
	Havoc 					  = Spell(80240),
	LifeTap 				  = Spell(1454),
	SummonDoomGuard		= Spell(18540),
	SummonDoomGuardSuppremacy = Spell(157757),
	SummonInfernal 		= Spell(1122),
	SummonInfernalSuppremacy = Spell(157898),
	SummonImp 				= Spell(688),
	GrimoireImp 			= Spell(111859),
	SoulHarvest 			= Spell(196098),
	
	-- Pet abilities
	CauterizeMaster		= Spell(119905),--imp
	Suffering				  = Spell(119907),--voidwalker
	SpellLock				  = Spell(119910),--Dogi
	Whiplash				  = Spell(119909),--Bitch
	ShadowLock				= Spell(171140),--doomguard
	MeteorStrike			= Spell(171152),--infernal
	
    -- Talents
  Backdraft 				= Spell(196406),
	RoaringBlaze 			= Spell(205184),
	Shadowburn				= Spell(17877),
	
	ReverseEntropy		= Spell(205148),
	Eradication 			= Spell(196412),
	EmpoweredLifeTap 	= Spell(235157),
	
	Cataclysm 				= Spell(152108),
	FireAndBrimstone 	= Spell(196408),
	SoulHarvest 			= Spell(196098),
	
	GrimoireOfSupremacy 	= Spell(152107),
	GrimoireOfService 		= Spell(108501),
	GrimoireOfSacrifice 	= Spell(108503),
	
	WreakHavoc				= Spell(196410),
	ChannelDemonfire 	= Spell(196447),
	SoulConduit 			= Spell(215941),
	
    -- Artifact
  DimensionalRift   = Spell(196586),
	LordOfFlames 			= Spell(224103),
	
	ConflagrationOfChaos 	= Spell(219195),
	DimensionRipper 	= Spell(219415),
    -- Defensive	
    
    -- Utility
    
    -- Legendaries
    
    -- Misc
	DemonicPower 			    = Spell(196099),
	EmpoweredLifeTapBuff	= Spell(235156),
  LordOfFlamesDebuff = Spell(226802),
  Backdraft = Spell(117828),
    
    -- Macros
    
  };
  local S = Spell.Warlock.Destruction;
  
  local PetSpells={[S.Suffering:ID()]=true, [S.SpellLock:ID()]=true, [S.Whiplash:ID()]=true, [S.CauterizeMaster:ID()]=true }
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Destruction = {
    -- Legendaries
    
  };
  local I = Item.Warlock.Destruction;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P,T194P = AC.HasTier("T19")
  local BestUnit, BestUnitTTD, BestUnitSpellToCast; -- Used for cycling
  local range=40
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warlock.Commons,
    Destruction = AR.GUISettings.APL.Warlock.Destruction
  };

  local PetSpells={[S.Suffering:ID()]=true, [S.SpellLock:ID()]=true, [S.Whiplash:ID()]=true, [S.CauterizeMaster:ID()]=true }

--- ======= ACTION LISTS =======
  local function IsPetInvoked(testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end
  
  local function GetImmolateStack()
    if not S.RoaringBlaze:IsAvailable() then
      return nil
    end
    
    return AC.ImmolationTable.Destruction.ImmolationDebuff[Target:GUID()];
  end
  


--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonImp:IsCastable() and not IsPetInvoked() and (S.GrimoireOfSacrifice:IsAvailable() and not Player:Buff(S.DemonicPower)) and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonImp, Settings.Destruction.GCDasOffGCD.SummonImp) then return; end
    end
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:IsCastable() and not S.MeteorStrike:IsLearned() and  ((S.LordOfFlames:ArtifactRank()>0) or Cache.EnemiesCount[range]>1) and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return; end
    end
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:IsCastable() and not S.ShadowLock:IsLearned() and not S.LordOfFlames:ArtifactRank()==0 and Cache.EnemiesCount[range]==1 and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonDoomGuard, Settings.Destruction.GCDasOffGCD.SummonDoomGuard) then return; end
    end
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireOfSacrifice:IsCastable() and IsPetInvoked() and not Player:Buff(S.DemonicPower) then
      if AR.Cast(S.GrimoireOfSacrifice, Settings.Destruction.GCDasOffGCD.GrimoireOfSacrifice) then return; end
    end
    -- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
    if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and not Player:Buff(S.EmpoweredLifeTapBuff) then
      if AR.Cast(S.LifeTap, Settings.Destruction.GCDasOffGCD.LifeTap) then return; end
    end
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
		
      -- Opener
      if Everyone.TargetIsValid() then
		if AR.Cast(S.Immolate) then return; end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
		-- actions=havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
		--todo : better havoc selection
		if AR.AoEON() and Cache.EnemiesCount[range]>1  then
			BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD()*2, nil;
			for _, Value in pairs(Cache.Enemies[range]) do
				if S.Havoc:IsCastable() and (Cache.EnemiesCount[range]<4 or (S.WreakHavoc:IsAvailable() and Cache.EnemiesCount[range]<6)) and not Value:IsUnit(Target) then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Havoc;
					break
				end	
			end
			if BestUnit then
				if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
			end
		end
		-- actions+=/dimensional_rift,if=charges=3
		if S.DimensionalRift:IsCastable() and S.DimensionalRift:Charges() == 3 then
			if AR.Cast(S.DimensionalRift) then return; end
		end
		-- actions+=/immolate,if=remains<=tick_time
		if Target:DebuffRemains(S.ImmolateDebuff)<Player:GCD() then
			if AR.Cast(S.Immolate) then return; end
		end
		-- actions+=/immolate,cycle_targets=1,if=active_enemies>1&remains<=tick_time&(!talent.roaring_blaze.enabled|(!debuff.roaring_blaze.remains&action.conflagrate.charges<2+set_bonus.tier19_4pc))
			--todo : multi target
		-- actions+=/immolate,if=talent.roaring_blaze.enabled&remains<=duration&!debuff.roaring_blaze.remains&target.time_to_die>10&(action.conflagrate.charges=2+set_bonus.tier19_4pc|(action.conflagrate.charges>=1+set_bonus.tier19_4pc&action.conflagrate.recharge_time<cast_time+gcd)|target.time_to_die<24)
		-- if S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.ImmolateDebuff)<=18 and not  then
			-- if AR.Cast(S.Immolate) then return; end
		-- end
    -- actions+=/berserking
		-- actions+=/blood_fury
		-- actions+=/arcane_torrent
		-- actions+=/potion,name=deadly_grace,if=(buff.soul_harvest.remains|trinket.proc.any.react|target.time_to_die<=45)
		-- actions+=/shadowburn,if=buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
		-- actions+=/shadowburn,if=(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
		-- actions+=/conflagrate,if=talent.roaring_blaze.enabled&(charges=2+set_bonus.tier19_4pc|(charges>=1+set_bonus.tier19_4pc&recharge_time<gcd)|target.time_to_die<24)
		-- actions+=/conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.stack>0&dot.immolate.remains>dot.immolate.duration*0.3&(active_enemies=1|soul_shard<3)&soul_shard<5
		-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
		-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
		-- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
		-- actions+=/dimensional_rift,if=equipped.144369&!buff.lessons_of_spacetime.remains&((!talent.grimoire_of_supremacy.enabled&!cooldown.summon_doomguard.remains)|(talent.grimoire_of_service.enabled&!cooldown.service_pet.remains)|(talent.soul_harvest.enabled&!cooldown.soul_harvest.remains))
		-- actions+=/service_pet
		-- actions+=/summon_infernal,if=artifact.lord_of_flames.rank>0&!buff.lord_of_flames.remains
		-- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
		-- actions+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2
		-- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&artifact.lord_of_flames.rank>0&buff.lord_of_flames.remains&!pet.doomguard.active
		-- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
		-- actions+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
		-- actions+=/soul_harvest
		-- actions+=/channel_demonfire,if=dot.immolate.remains>cast_time
		-- actions+=/havoc,if=active_enemies=1&talent.wreak_havoc.enabled&equipped.132375&!debuff.havoc.remains
		-- actions+=/rain_of_fire,if=active_enemies>=3&cooldown.havoc.remains<=12&!talent.wreak_havoc.enabled
		-- actions+=/rain_of_fire,if=active_enemies>=6&talent.wreak_havoc.enabled
		-- actions+=/dimensional_rift,if=!equipped.144369|charges>1|((!talent.grimoire_of_service.enabled|recharge_time<cooldown.service_pet.remains)&(!talent.soul_harvest.enabled|recharge_time<cooldown.soul_harvest.remains)&(!talent.grimoire_of_supremacy.enabled|recharge_time<cooldown.summon_doomguard.remains))
		-- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
		-- actions+=/cataclysm
		-- actions+=/chaos_bolt,if=(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies<3|talent.wreak_havoc.enabled&active_enemies<6)&(set_bonus.tier19_4pc=0|!talent.eradication.enabled|buff.embrace_chaos.remains<=cast_time|soul_shard>=3)
		-- actions+=/shadowburn
		-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3
		-- actions+=/immolate,if=!talent.roaring_blaze.enabled&remains<=duration*0.3
		-- actions+=/incinerate
		if AR.Cast(S.Incinerate) then return; end
		
      return;
    end
  end

  AR.SetAPL(267, APL);


--- ======= SIMC =======
--- Last Update: 12/06/2017

-- actions.precombat=flask,type=whispered_pact
-- actions.precombat+=/food,type=azshari_salad
-- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
-- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
-- actions.precombat+=/augmentation,type=defiled
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
-- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
-- actions.precombat+=/potion,name=prolonged_power
-- actions.precombat+=/chaos_bolt

-- # Executed every time the actor is available.
-- actions=immolate,cycle_targets=1,if=active_enemies=2&talent.roaring_blaze.enabled&!cooldown.havoc.remains&dot.immolate.remains<=buff.active_havoc.duration
-- actions+=/havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
-- actions+=/dimensional_rift,if=charges=3
-- actions+=/cataclysm,if=spell_targets.cataclysm>=3
-- actions+=/immolate,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&remains<=tick_time
-- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&active_enemies>1&remains<=tick_time&(!talent.roaring_blaze.enabled|(!debuff.roaring_blaze.remains&action.conflagrate.charges<2+set_bonus.tier19_4pc))
-- actions+=/immolate,if=talent.roaring_blaze.enabled&remains<=duration&!debuff.roaring_blaze.remains&target.time_to_die>10&(action.conflagrate.charges=2+set_bonus.tier19_4pc|(action.conflagrate.charges>=1+set_bonus.tier19_4pc&action.conflagrate.recharge_time<cast_time+gcd)|target.time_to_die<24)
-- actions+=/berserking
-- actions+=/blood_fury
-- actions+=/use_items
-- actions+=/potion,name=deadly_grace,if=(buff.soul_harvest.remains|trinket.proc.any.react|target.time_to_die<=45)
-- actions+=/shadowburn,if=buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
-- actions+=/shadowburn,if=(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
-- actions+=/conflagrate,if=talent.roaring_blaze.enabled&(charges=2+set_bonus.tier19_4pc|(charges>=1+set_bonus.tier19_4pc&recharge_time<gcd)|target.time_to_die<24)
-- actions+=/conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.stack>0&dot.immolate.remains>dot.immolate.duration*0.3&(active_enemies=1|soul_shard<3)&soul_shard<5
-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
-- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
-- actions+=/dimensional_rift,if=equipped.144369&!buff.lessons_of_spacetime.remains&((!talent.grimoire_of_supremacy.enabled&!cooldown.summon_doomguard.remains)|(talent.grimoire_of_service.enabled&!cooldown.service_pet.remains)|(talent.soul_harvest.enabled&!cooldown.soul_harvest.remains))
-- actions+=/service_pet
-- actions+=/summon_infernal,if=artifact.lord_of_flames.rank>0&!buff.lord_of_flames.remains
-- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2
-- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&artifact.lord_of_flames.rank>0&buff.lord_of_flames.remains&!pet.doomguard.active
-- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions+=/soul_harvest,if=!buff.soul_harvest.remains
-- actions+=/chaos_bolt,if=active_enemies<4&buff.active_havoc.remains>cast_time
-- actions+=/channel_demonfire,if=dot.immolate.remains>cast_time&(active_enemies=1|buff.active_havoc.remains<action.chaos_bolt.cast_time)
-- actions+=/rain_of_fire,if=active_enemies>=3
-- actions+=/rain_of_fire,if=active_enemies>=6&talent.wreak_havoc.enabled
-- actions+=/dimensional_rift,if=target.time_to_die<=32|!equipped.144369|charges>1|((!talent.grimoire_of_service.enabled|recharge_time<cooldown.service_pet.remains)&(!talent.soul_harvest.enabled|recharge_time<cooldown.soul_harvest.remains)&(!talent.grimoire_of_supremacy.enabled|recharge_time<cooldown.summon_doomguard.remains))
-- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
-- actions+=/cataclysm
-- actions+=/chaos_bolt,if=active_enemies<3&target.time_to_die<=10
-- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*0.5)&(soul_shard>=5-spell_targets.infernal_awakening*0.5|buff.soul_harvest.remains>cast_time|buff.concordance_of_the_legionfall.remains>cast_time)
-- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*0.5)&(trinket.proc.mastery.react&trinket.proc.mastery.remains>cast_time|trinket.proc.crit.react&trinket.proc.crit.remains>cast_time|trinket.proc.versatility.react&trinket.proc.versatility.remains>cast_time|trinket.proc.intellect.react&trinket.proc.intellect.remains>cast_time|trinket.proc.spell_power.react&trinket.proc.spell_power.remains>cast_time)
-- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*0.5)&(trinket.stacking_proc.mastery.react&trinket.stacking_proc.mastery.remains>cast_time|trinket.stacking_proc.crit.react&trinket.stacking_proc.crit.remains>cast_time|trinket.stacking_proc.versatility.react&trinket.stacking_proc.versatility.remains>cast_time|trinket.stacking_proc.intellect.react&trinket.stacking_proc.intellect.remains>cast_time|trinket.stacking_proc.spell_power.react&trinket.stacking_proc.spell_power.remains>cast_time)
-- actions+=/shadowburn
-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3
-- actions+=/immolate,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&!talent.roaring_blaze.enabled&remains<=duration*0.3
-- actions+=/incinerate
-- actions+=/life_tap


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
  Spell.Warlock.Affliction = {
    -- Racials
	ArcaneTorrent			= Spell(25046),
	Berserking				= Spell(26297),
	BloodFury				  = Spell(20572),
	GiftoftheNaaru		= Spell(59547),
	Shadowmeld        = Spell(58984),
    
    -- Abilities
  Agony 				    = Spell(980),
  Corruption 				= Spell(172),
	DrainSoul 				= Spell(198590),
	SeedOfCorruption 	= Spell(27243),
	UnstableAffliction= Spell(30108),
	LifeTap 				  = Spell(1454),
	SummonDoomGuard		= Spell(18540),
	SummonDoomGuardSuppremacy = Spell(157757),
	SummonInfernal 		= Spell(1122),
	SummonInfernalSuppremacy = Spell(157898),
	SummonImp 				= Spell(688),
	GrimoireImp 			= Spell(111859),
	
	-- Pet abilities
	CauterizeMaster		= Spell(119905),--imp
	Suffering				  = Spell(119907),--voidwalker
	SpellLock				  = Spell(119910),--Dogi
	Whiplash				  = Spell(119909),--Bitch
	ShadowLock				= Spell(171140),--doomguard
	MeteorStrike			= Spell(171152),--infernal
	
    -- Talents
  Haunt 				    = Spell(48181),
	WritheInAgony 		= Spell(196102),
	MaleficGrasp			= Spell(235155),
	
	Contagion		      = Spell(196105),
	AbsoluteCorruption= Spell(196103),
	EmpoweredLifeTap 	= Spell(235157),
	
	PhantomSingularity= Spell(205179),
	SowTheSeeds  	    = Spell(196226),
	SoulHarvest 			= Spell(196098),
	
	GrimoireOfSupremacy 	= Spell(152107),
	GrimoireOfService 		= Spell(108501),
	GrimoireOfSacrifice 	= Spell(108503),
	
	DeathsEmbrace			= Spell(234876),
	SiphonLife 	      = Spell(63106),
	SoulConduit 			= Spell(215941),
	
    -- Artifact
  ReapSouls         = Spell(216698),
	
  WrathOfConsumption= Spell(199472),
  RendSoul          = Spell(238144),
    -- Defensive	
    
    -- Utility
    
    -- Legendaries
    
    -- Misc
  DemonicPower 			    = Spell(196099),
  EmpoweredLifeTapBuff	= Spell(235156),
	Concordance           = Spell(242586),
    
    -- Macros
    
  };
  local S = Spell.Warlock.Affliction;
  
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Affliction = {
    -- Legendaries
    
  };
  local I = Item.Warlock.Affliction;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P,T194P = AC.HasTier("T19")
  local T202P,T204P = AC.HasTier("T20")
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range=40
  
  local Consts={
    AgonyBaseDuration = 18,
    AgonyMaxDuration = 27,
    CorruptionBaseDuration = 14,
    CorruptionMaxDuration = 18,
    UABaseDuration = 8,
    SiphonLifeBaseDuration = 15,
    SiphonLifeMaxDuration = 20,
    EmpoweredLifeTapBaseDuration = 20
  }
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warlock.Commons,
    Affliction = AR.GUISettings.APL.Warlock.Affliction
  };
  
  local PetSpells={[S.Suffering:ID()]=true, [S.SpellLock:ID()]=true, [S.Whiplash:ID()]=true, [S.CauterizeMaster:ID()]=true }


--- ======= ACTION LISTS =======
  local function IsPetInvoked(testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end


--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    -- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
    -- actions.precombat+=/potion,name=prolonged_power
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonImp:IsCastable() and not IsPetInvoked() and not S.GrimoireOfSupremacy:IsAvailable() and (not S.GrimoireOfSacrifice:IsAvailable() or not Player:Buff(S.DemonicPower)) and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonImp, Settings.Commons.GCDasOffGCD.SummonImp) then return "Cast"; end
    end
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:IsCastable() and not S.MeteorStrike:IsLearned() and  AR.AoEON() and Cache.EnemiesCount[range]>1 and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:IsCastable() and not S.ShadowLock:IsLearned() and Cache.EnemiesCount[range]==1 and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireOfSacrifice:IsCastable() and IsPetInvoked() and not Player:Buff(S.DemonicPower) then
      if AR.Cast(S.GrimoireOfSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "Cast"; end
    end
    -- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
    if AR.CDsON() and S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and (Player:BuffRemains(S.EmpoweredLifeTapBuff)<0.3*Consts.EmpoweredLifeTapBaseDuration) then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
		
      -- Opener
      if Everyone.TargetIsValid() then
          if AR.Cast(S.Agony) then return "Cast"; end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      
    end
  end

  AR.SetAPL(265, APL);


--- ======= SIMC =======
--- Last Update: 23/07/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=whispered_pact
-- actions.precombat+=/food,type=nightborne_delicacy_platter
-- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
-- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
-- actions.precombat+=/augmentation,type=defiled
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
-- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
-- actions.precombat+=/potion,name=prolonged_power

-- # Executed every time the actor is available.
-- actions=call_action_list,name=haunt,if=talent.haunt.enabled
-- actions+=/call_action_list,name=writhe,if=talent.writhe_in_agony.enabled
-- actions+=/call_action_list,name=mg,if=talent.malefic_grasp.enabled

-- actions.haunt=reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.tormented_souls.react*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
-- actions.haunt+=/reap_souls,if=debuff.haunt.remains&!buff.deadwind_harvester.remains
-- actions.haunt+=/reap_souls,if=active_enemies>1&!buff.deadwind_harvester.remains&time>5&soul_shard>0&((talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|spell_targets.seed_of_corruption>=5)
-- actions.haunt+=/agony,cycle_targets=1,if=remains<=tick_time+gcd
-- actions.haunt+=/service_pet,if=dot.corruption.remains&dot.agony.remains
-- actions.haunt+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions.haunt+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
-- actions.haunt+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.haunt+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.haunt+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
-- actions.haunt+=/blood_fury
-- actions.haunt+=/soul_harvest,if=buff.soul_harvest.remains<=8&buff.active_uas.stack>=1
-- actions.haunt+=/use_item,slot=trinket1
-- actions.haunt+=/use_item,slot=trinket2
-- actions.haunt+=/potion,name=prolonged_power,if=!talent.soul_harvest.enabled&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
-- actions.haunt+=/potion,name=prolonged_power,if=talent.soul_harvest.enabled&buff.soul_harvest.remains&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|!cooldown.haunt.remains|buff.active_uas.stack>2)
-- actions.haunt+=/siphon_life,cycle_targets=1,if=remains<=tick_time+gcd
-- actions.haunt+=/corruption,cycle_targets=1,if=remains<=tick_time+gcd&(spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<5)
-- actions.haunt+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
-- actions.haunt+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
-- actions.haunt+=/phantom_singularity
-- actions.haunt+=/haunt
-- actions.haunt+=/agony,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains
-- actions.haunt+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
-- actions.haunt+=/siphon_life,if=remains<=duration*0.3&target.time_to_die>=remains
-- actions.haunt+=/siphon_life,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*6&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*4
-- actions.haunt+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3|spell_targets.seed_of_corruption>=5|spell_targets.seed_of_corruption>=3&dot.corruption.remains<=cast_time+travel_time
-- actions.haunt+=/corruption,if=remains<=duration*0.3&target.time_to_die>=remains
-- actions.haunt+=/corruption,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*6&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*4
-- actions.haunt+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&((soul_shard>=4&!talent.contagion.enabled)|soul_shard>=5|target.time_to_die<30)
-- actions.haunt+=/unstable_affliction,cycle_targets=1,if=active_enemies>1&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&soul_shard>=4&talent.contagion.enabled&cooldown.haunt.remains<15&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.haunt+=/unstable_affliction,cycle_targets=1,if=active_enemies>1&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&(equipped.132381|equipped.132457)&cooldown.haunt.remains<15&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.haunt+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&talent.contagion.enabled&soul_shard>=4&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.haunt+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*2
-- actions.haunt+=/reap_souls,if=!buff.deadwind_harvester.remains&(buff.active_uas.stack>1|(prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1))
-- actions.haunt+=/life_tap,if=mana.pct<=10
-- actions.haunt+=/drain_soul,chain=1,interrupt=1
-- actions.haunt+=/life_tap

-- actions.mg=reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.tormented_souls.react*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
-- actions.mg+=/reap_souls,if=active_enemies>1&!buff.deadwind_harvester.remains&time>5&soul_shard>0&((talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|spell_targets.seed_of_corruption>=5)
-- actions.mg+=/agony,cycle_targets=1,if=remains<=tick_time+gcd
-- actions.mg+=/service_pet,if=dot.corruption.remains&dot.agony.remains
-- actions.mg+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions.mg+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
-- actions.mg+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.mg+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.mg+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
-- actions.mg+=/blood_fury
-- actions.mg+=/soul_harvest,if=buff.soul_harvest.remains<=8&buff.active_uas.stack>=2
-- actions.mg+=/use_item,slot=trinket1
-- actions.mg+=/use_item,slot=trinket2
-- actions.mg+=/potion,name=prolonged_power,if=!talent.soul_harvest.enabled&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
-- actions.mg+=/potion,name=prolonged_power,if=talent.soul_harvest.enabled&buff.soul_harvest.remains&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
-- actions.mg+=/siphon_life,if=remains<=tick_time+gcd
-- actions.mg+=/siphon_life,cycle_targets=1,if=active_enemies>1&remains<=tick_time+gcd&buff.active_uas.stack=0
-- actions.mg+=/corruption,if=remains<=tick_time+gcd&((spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled)|spell_targets.seed_of_corruption<5)
-- actions.mg+=/corruption,cycle_targets=1,if=active_enemies>1&remains<=tick_time+gcd&(spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<5)&(buff.active_uas.stack=0|equipped.132457)
-- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
-- actions.mg+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))&buff.active_uas.stack<1
-- actions.mg+=/phantom_singularity
-- actions.mg+=/agony,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&buff.active_uas.stack=0
-- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
-- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&buff.active_uas.stack=0
-- actions.mg+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3|spell_targets.seed_of_corruption>=5|spell_targets.seed_of_corruption>=3&dot.corruption.remains<=cast_time+travel_time
-- actions.mg+=/corruption,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&buff.active_uas.stack=0
-- actions.mg+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&(target.time_to_die<30|prev_gcd.1.unstable_affliction&soul_shard>=4&(equipped.132457|buff.active_uas.stack<2))
-- actions.mg+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&(soul_shard>=4|(equipped.132457&soul_shard=5))
-- actions.mg+=/unstable_affliction,if=!equipped.132457&!prev_gcd.3.unstable_affliction&dot.agony.remains>cast_time*2+6.5&(dot.corruption.remains>cast_time+6.5|talent.absolute_corruption.enabled)&(!talent.siphon_life.enabled|dot.siphon_life.remains>cast_time+6.5)
-- actions.mg+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&equipped.132457&(buff.active_uas.stack=0|!prev_gcd.3.unstable_affliction&prev_gcd.1.unstable_affliction)&dot.agony.remains>cast_time+6.5
-- actions.mg+=/reap_souls,if=!buff.deadwind_harvester.remains&(buff.active_uas.stack>1|(prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1))
-- actions.mg+=/life_tap,if=mana.pct<=10
-- actions.mg+=/drain_soul,chain=1,interrupt=1
-- actions.mg+=/life_tap

-- actions.writhe=reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.tormented_souls.react*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.soul_harvest.remains>(5+equipped.144364)&buff.active_uas.stack>1|buff.concordance_of_the_legionfall.react|trinket.proc.intellect.react|trinket.stacking_proc.intellect.react|trinket.proc.mastery.react|trinket.stacking_proc.mastery.react|trinket.proc.crit.react|trinket.stacking_proc.crit.react|trinket.proc.versatility.react|trinket.stacking_proc.versatility.react|trinket.proc.spell_power.react|trinket.stacking_proc.spell_power.react)
-- actions.writhe+=/reap_souls,if=active_enemies>1&!buff.deadwind_harvester.remains&time>5&soul_shard>0&((talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|spell_targets.seed_of_corruption>=5)
-- actions.writhe+=/agony,cycle_targets=1,if=remains<=tick_time+gcd
-- actions.writhe+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&soul_shard=5
-- actions.writhe+=/service_pet,if=dot.corruption.remains&dot.agony.remains
-- actions.writhe+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions.writhe+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
-- actions.writhe+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.writhe+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.writhe+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
-- actions.writhe+=/blood_fury
-- actions.writhe+=/soul_harvest,if=buff.soul_harvest.remains<=8&buff.active_uas.stack>=2
-- actions.writhe+=/use_item,slot=trinket1
-- actions.writhe+=/use_item,slot=trinket2
-- actions.writhe+=/potion,name=prolonged_power,if=!talent.soul_harvest.enabled&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
-- actions.writhe+=/potion,name=prolonged_power,if=talent.soul_harvest.enabled&buff.soul_harvest.remains&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
-- actions.writhe+=/siphon_life,cycle_targets=1,if=remains<=tick_time+gcd
-- actions.writhe+=/corruption,cycle_targets=1,if=remains<=tick_time+gcd&(spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<5)
-- actions.writhe+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
-- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
-- actions.writhe+=/phantom_singularity
-- actions.writhe+=/agony,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains
-- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
-- actions.writhe+=/siphon_life,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains
-- actions.writhe+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3|spell_targets.seed_of_corruption>=5|spell_targets.seed_of_corruption>=3&dot.corruption.remains<=cast_time+travel_time
-- actions.writhe+=/corruption,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains
-- actions.writhe+=/unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&(soul_shard>=4|buff.soul_harvest.remains)
-- actions.writhe+=/unstable_affliction,cycle_targets=1,if=active_enemies>1&(equipped.132381|equipped.132457)&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&talent.contagion.enabled&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.writhe+=/unstable_affliction,if=(active_enemies>1|equipped.132457)&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&talent.contagion.enabled&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.writhe+=/unstable_affliction,if=(active_enemies=1|(!equipped.132381&!equipped.132457))&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&(buff.deadwind_harvester.remains|target.time_to_die<=20|buff.concordance_of_the_legionfall.react|trinket.proc.intellect.react|trinket.stacking_proc.intellect.react|trinket.proc.mastery.react|trinket.stacking_proc.mastery.react|trinket.proc.crit.react|trinket.stacking_proc.crit.react|trinket.proc.versatility.react|trinket.stacking_proc.versatility.react)
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&buff.active_uas.stack>1
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1
-- actions.writhe+=/life_tap,if=mana.pct<=10
-- actions.writhe+=/drain_soul,chain=1,interrupt=1
-- actions.writhe+=/life_tap


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
	CorruptionDebuff 	= Spell(146739),
	DrainSoul 				= Spell(198590),
	SeedOfCorruption 	= Spell(27243),
	UnstableAffliction= Spell(30108),
	LifeTap 				  = Spell(1454),
	SummonDoomGuard		= Spell(18540),
	SummonDoomGuardSuppremacy = Spell(157757),
	SummonInfernal 		= Spell(1122),
	SummonInfernalSuppremacy = Spell(157898),
	SummonFelhunter 	= Spell(691),
	GrimoireFelhunter = Spell(111897),
	
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
  Concordance       = Spell(242586),
    -- Defensive	
    
    -- Utility
    
    -- Legendaries
  SindoreiSpiteBuff = Spell(208868),  
    -- Misc
	DemonicPower 			    = Spell(196099),
	EmpoweredLifeTapBuff	= Spell(235156),
	Concordance           = Spell(242586),
	DeadwindHarvester     = Spell(216708),
	TormentedSouls        = Spell(216695),
  
    -- UA stack
     
    -- Macros
    
  };
  local S = Spell.Warlock.Affliction;
  
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Affliction = {
    -- Legendaries
    ReapAndSow                = Item(144364, {15}), 
    SindoreiSpite             = Item(132379, {9}), 
    StretensSleeplessShackles = Item(132381, {9}), 
    PowerCordofLethtendris    = Item(132457, {6}) 
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
  local UnstableAfflictionDebuffs={Spell(233490),Spell(233496),Spell(233497),Spell(233498),Spell(233499)}


--- ======= ACTION LISTS =======
  local function IsPetInvoked(testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end
  
  local function SoulsAvailable()
    return Player:BuffStack(S.TormentedSouls)
  end
  
  local function ActiveUAs()
    local UAcount = 0
    for _,v in pairs(UnstableAfflictionDebuffs) do
      if Target:Debuff(v) then UAcount=UAcount+1 end
    end
    return UAcount
  end
  
  local function CheckDeadwindHarvester()
    for _,v in pairs(UnstableAfflictionDebuffs) do
      if Player:BuffRemains(S.DeadwindHarvester)<Target:DebuffRemains(v) then return true; end
    end
    return false
  end
  
  local function CheckUUnstableAffliction()
    for _,v in pairs(UnstableAfflictionDebuffs) do
      if Target:DebuffRemains(v)>v:CastTime() then return false; end
    end
    return true
  end
  
  local function NbAffected(SpellAffected)
    local nbaff=0
    for Key, Value in pairs(Cache.Enemies[range]) do
      if Value:Debuff(SpellAffected) then
        nbaff = nbaff + 1;
      end
    end
    return nbaff;
  end
  
  local function FutureShard()
    local Shard=Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:CastID()==S.UnstableAffliction:ID() or Player:CastID()==S.SeedOfCorruption:ID()  then
        return Shard-1
      elseif Player:CastID()==S.SummonDoomGuard:ID() or Player:CastID()==S.SummonDoomGuardSuppremacy:ID() or Player:CastID()==S.SummonInfernal:ID() or Player:CastID()==S.SummonInfernalSuppremacy:ID() or Player:CastID()==S.GrimoireFelguard:ID() or Player:CastID()==S.SummonFelguard:ID() then
        return Shard-1
      else
        return Shard
      end
    end
  end

  local function HauntAPL()
    -- actions.haunt=reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
    -- actions.haunt+=/reap_souls,if=debuff.haunt.remains&!buff.deadwind_harvester.remains
    -- actions.haunt+=/reap_souls,if=active_enemies>1&!buff.deadwind_harvester.remains&time>5&soul_shard>0&((talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|spell_targets.seed_of_corruption>=5)
    -- actions.haunt+=/agony,cycle_targets=1,if=remains<=tick_time+gcd
    -- actions.haunt+=/drain_soul,cycle_targets=1,if=target.time_to_die<=gcd*2&soul_shard<5
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
    -- actions.haunt+=/potion,if=!talent.soul_harvest.enabled&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
    -- actions.haunt+=/potion,if=talent.soul_harvest.enabled&buff.soul_harvest.remains&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|!cooldown.haunt.remains|buff.active_uas.stack>2)
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
    -- actions.haunt+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
    -- actions.haunt+=/drain_soul,chain=1,interrupt=1
    -- actions.haunt+=/life_tap,moving=1,if=mana.pct<80
    -- actions.haunt+=/agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    -- actions.haunt+=/siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    -- actions.haunt+=/corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    -- actions.haunt+=/life_tap,moving=0  
  end
  
  local function WritheAPL()
    -- actions.writhe  =reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
    -- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.soul_harvest.remains>=(5+1.5*equipped.144364)&buff.active_uas.stack>1|buff.concordance_of_the_legionfall.react|trinket.proc.intellect.react|trinket.stacking_proc.intellect.react|trinket.proc.mastery.react|trinket.stacking_proc.mastery.react|trinket.proc.crit.react|trinket.stacking_proc.crit.react|trinket.proc.versatility.react|trinket.stacking_proc.versatility.react|trinket.proc.spell_power.react|trinket.stacking_proc.spell_power.react)
    if not Player:Buff(S.DeadwindHarvester) and AC.CombatTime()>5 and SoulsAvailable()>1
      and ((SoulsAvailable()>= 5 or Target:TimeToDie() <= ((SoulsAvailable()*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0))) + (Player:BuffRemains(S.DeadwindHarvester)*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0))/12*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0)))))
      or ((Player:BuffRemains(S.SoulHarvest)>=(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0)) and ActiveUAs() > 1) or Player:Buff(S.Concordance) ))then
        if AR.Cast(S.ReapSouls) then return "Cast"; end
    end
    
    -- actions.writhe+=/agony,if=remains<=tick_time+gcd
    if Target:DebuffRemains(S.Agony)<=(Player:GCD()+S.Agony:TickTime()) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    
    -- actions.writhe+=/agony,cycle_targets=1,max_cycle_targets=5,target_if=sim.target!=target&talent.soul_harvest.enabled&cooldown.soul_harvest.remains<cast_time*6&remains<=duration*0.3&target.time_to_die>=remains&time_to_die>tick_time*3
    -- actions.writhe+=/agony,cycle_targets=1,max_cycle_targets=3,target_if=sim.target!=target&remains<=tick_time+gcd&time_to_die>tick_time*3
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemains()<Player:GCD()*6 and Value:DebuffRemains(S.Agony)<=Consts.AgonyBaseDuration*0.3 and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD and Value:TimeToDie()>S.Agony:TickTime()*3 and NbAffected(S.Agony)<=5 then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3&soul_shard=5
    if S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[40]>=3 and FutureShard()==5 then
      if AR.Cast(S.SeedOfCorruption) then return "Cast"; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=soul_shard=5|(time_to_die<=((duration+cast_time)*soul_shard))
    if FutureShard() == 5 or Target:TimeToDie() <= (S.UnstableAffliction:CastTime() + S.UnstableAffliction:TickTime()) * FutureShard() then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.writhe+=/drain_soul,cycle_targets=1,if=target.time_to_die<=gcd*2&soul_shard<5
    BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 0, nil;
    for Key, Value in pairs(Cache.Enemies[range]) do
      if FutureShard()<5 and Value:TimeToDie()<Player:GCD()*2 then
        BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.DrainSoul;
      end
    end
    if BestUnit then
      if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
    end
    
    -- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
    if AR.CDsON() and S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and (Player:BuffRemains(S.EmpoweredLifeTapBuff)<0.3*Consts.EmpoweredLifeTapBaseDuration) then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.writhe+=/service_pet,if=dot.corruption.remains&dot.agony.remains
    if S.GrimoireFelhunter:IsAvailable() and S.GrimoireFelhunter:IsCastable() and FutureShard()>=1 and Target:Debuff(S.Agony) and Target:Debuff(S.Corruption) then
      if AR.Cast(S.GrimoireFelhunter, Settings.Affliction.GCDasOffGCD.GrimoireFelhunter) then return "Cast"; end
    end
    
    -- actions.writhe+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
    if AR.CDsON() and S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:IsCastable() and FutureShard()>=1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]<=2 
      and (Target:TimeToDie()>180 or Target:HealthPercentage()<=20 or Target:TimeToDie()<30) then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    
    -- actions.writhe+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
    if AR.CDsON() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:IsCastable() and FutureShard()>=1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]>2 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end
    
    -- actions.writhe+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if AR.CDsON() and S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:IsCastable() and FutureShard()>=1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]==1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    
    -- actions.writhe+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if AR.CDsON() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:IsCastable() and FutureShard()>=1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]>1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end

    -- actions.writhe+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
    if AR.CDsON() and S.Berserking:IsAvailable() and S.Berserking:IsCastable() and (Player:PrevGCD(1,S.UnstableAffliction) or Player:BuffRemains(S.SoulHarvest)>=10)  then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
    end
    
    -- actions.writhe+=/blood_fury
    if AR.CDsON() and S.BloodFury:IsAvailable() and S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
    end
    
    -- actions.writhe+=/soul_harvest,if=sim.target=target&buff.soul_harvest.remains<=8&(buff.active_uas.stack>=2|active_enemies>3)&(!talent.deaths_embrace.enabled|time_to_die>120|time_to_die<30)
    if AR.CDsON() and S.SoulHarvest:IsAvailable() and S.SoulHarvest:IsCastable() and (ActiveUAs()>1 or Cache.EnemiesCount[40]>3) and Player:BuffRemains(S.SoulHarvest)<=8 and (not S.DeathsEmbrace:IsAvailable() or Target:TimeToDie()>120 or Target:TimeToDie()<30) then
        if AR.Cast(S.SoulHarvest, Settings.Affliction.OffGCDasOffGCD.SoulHarvest) then return "Cast"; end
    end
    
    -- actions.writhe+=/use_item,slot=trinket1
    -- actions.writhe+=/use_item,slot=trinket2
    -- actions.writhe+=/potion,if=target.time_to_die<=70
    -- actions.writhe+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&(trinket.proc.any.react|trinket.stack_proc.any.react|buff.active_uas.stack>=2)
    --TODO : trinket & potion

    
    -- actions.writhe+=/siphon_life,cycle_targets=1,if=remains<=tick_time+gcd&time_to_die>tick_time*2
    if S.SiphonLife:IsAvailable() and Target:DebuffRemains(S.SiphonLife)<=(S.SiphonLife:TickTime()+Player:GCD()) and Target:TimeToDie()>S.SiphonLife:TickTime()*2 then
        if AR.Cast(S.SiphonLife) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SiphonLife:IsAvailable() and Value:DebuffRemains(S.SiphonLife)<=(S.SiphonLife:TickTime()+Player:GCD()) and Value:TimeToDie()>S.SiphonLife:TickTime()*2 and Value:TimeToDie()-Value:DebuffRemains(S.SiphonLife) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/corruption,cycle_targets=1,if=remains<=tick_time+gcd&((spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled)|spell_targets.seed_of_corruption<5)&time_to_die>tick_time*2
    if Target:DebuffRemains(S.CorruptionDebuff)<=(Player:GCD()+S.CorruptionDebuff:TickTime()) then
      if AR.Cast(S.Corruption) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((Cache.EnemiesCount[40]<3 and S.SowTheSeeds:IsAvailable()) or Cache.EnemiesCount[40]<5) and Value:DebuffRemains(S.CorruptionDebuff)<=Consts.CorruptionBaseDuration*0.3 and Value:TimeToDie()>S.CorruptionDebuff:TickTime()*2 and Value:TimeToDie()-Value:DebuffRemains(S.CorruptionDebuff) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/life_tap,if=mana.pct<40&(buff.active_uas.stack<1|!buff.deadwind_harvester.remains)
    if S.LifeTap:IsCastable() and Player:ManaPercentage() < 40 and (ActiveUAs()<1 or not Player:Buff(S.DeadwindHarvester)) then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.writhe+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
    if SoulsAvailable()>1 and (Player:BuffRemains(S.DeadwindHarvester)+ActiveUAs()*(5+(I.ReapAndSow:IsEquipped() and 1 or 0))) >= (12*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0))) then 
      if AR.Cast(S.ReapSouls) then return "Cast"; end
    end
    
    -- actions.writhe+=/phantom_singularity
    if S.PhantomSingularity:IsAvailable() and S.PhantomSingularity:IsCastable()  then
        if AR.Cast(S.PhantomSingularity) then return "Cast"; end
    end
    
    -- actions.writhe+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>3&dot.corruption.refreshable)
    if FutureShard()>=1 and ((S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[40]>=3) or (Cache.EnemiesCount[40]>=3 and Target:DebuffRefreshableP(S.CorruptionDebuff,Consts.CorruptionBaseDuration*0.3))) then
      if AR.Cast(S.SeedOfCorruption) then return "Cast"; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=talent.contagion.enabled&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if FutureShard()>=1  and S.Contagion:IsAvailable() and CheckUUnstableAffliction() then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.writhe+=/unstable_affliction,cycle_targets=1,target_if=buff.deadwind_harvester.remains>=duration+cast_time&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if FutureShard()>=1  and Player:BuffRemains(S.DeadwindHarvester) > Consts.UABaseDuration+S.UnstableAffliction:CastTime() and CheckUUnstableAffliction() then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=buff.deadwind_harvester.remains>tick_time*2&(!talent.contagion.enabled|soul_shard>1|buff.soul_harvest.remains)&(dot.unstable_affliction_1.ticking+dot.unstable_affliction_2.ticking+dot.unstable_affliction_3.ticking+dot.unstable_affliction_4.ticking+dot.unstable_affliction_5.ticking<5)
    if FutureShard()>=1  and Player:BuffRemains(S.DeadwindHarvester) > S.UnstableAffliction:TickTime()*2 and (not S.Contagion:IsAvailable() or FutureShard() > 1 or Player:Buff(S.SoulHarvest)) and ActiveUAs()<5 then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&buff.active_uas.stack>1
    if not Player:Buff(S.DeadwindHarvester) and ActiveUAs()>1 and SoulsAvailable()>1 then 
      if AR.Cast(S.ReapSouls) then return "Cast"; end
    end
    
    -- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1
    if not Player:Buff(S.DeadwindHarvester) and Player:PrevGCD(1,S.UnstableAffliction) and SoulsAvailable()>1 then 
      if AR.Cast(S.ReapSouls) then return "Cast"; end
    end
    
    -- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3&(!buff.deadwind_harvester.remains|buff.active_uas.stack<1)
    if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemains(S.EmpoweredLifeTapBuff)<0.3*Consts.EmpoweredLifeTapBaseDuration and (not Player:Buff(S.DeadwindHarvester) or ActiveUAs()<1) then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.writhe+=/agony,if=refreshable&time_to_die>=remains
    if Target:DebuffRefreshableP(S.Agony,Consts.AgonyBaseDuration*0.3) and Target:TimeToDie() >= Target:DebuffRemains(S.Agony) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    
    -- actions.writhe+=/siphon_life,if=refreshable&time_to_die>=remains
    if S.SiphonLife:IsAvailable() and Target:DebuffRefreshableP(S.SiphonLife,Consts.SiphonLifeBaseDuration*0.3) and Target:TimeToDie() >= Target:DebuffRemains(S.SiphonLife) then
      if AR.Cast(S.SiphonLife) then return "Cast"; end
    end

    -- actions.writhe+=/corruption,if=refreshable&time_to_die>=remains
    if Target:DebuffRefreshableP(S.CorruptionDebuff,Consts.CorruptionBaseDuration*0.3) and Target:TimeToDie() >= Target:DebuffRemains(S.Agony) then
      if AR.Cast(S.Corruption) then return "Cast"; end
    end
    
    -- actions.writhe+=/agony,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:TimeToDie()>S.Agony:TickTime()*3 and not Player:Buff(S.DeadwindHarvester) and Target:DebuffRefreshableP(S.Agony,Consts.AgonyBaseDuration*0.3) and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/siphon_life,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SiphonLife:IsAvailable() and Value:TimeToDie()>S.SiphonLife:TickTime()*3 and not Player:Buff(S.DeadwindHarvester) and Target:DebuffRefreshableP(S.SiphonLife,Consts.SiphonLifeBaseDuration*0.3) and Value:TimeToDie()-Value:DebuffRemains(S.SiphonLife) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/corruption,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:TimeToDie()>S.CorruptionDebuff:TickTime()*3 and not Player:Buff(S.DeadwindHarvester) and Target:DebuffRefreshableP(S.CorruptionDebuff,Consts.CorruptionBaseDuration*0.3) and Value:TimeToDie()-Value:DebuffRemains(S.CorruptionDebuff) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/life_tap,if=mana.pct<=10
    if S.LifeTap:IsCastable() and Player:ManaPercentage() < 10 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.writhe+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
    if S.LifeTap:IsCastable() and ActiveUAs()==0 and Player:PrevGCD(1,S.LifeTap) and Player:ManaPercentage() < 50 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.writhe+=/drain_soul,chain=1,interrupt=1
    if S.DrainSoul:IsCastable() then
      if AR.Cast(S.DrainSoul) then return "Cast"; end
    end
    
    -- actions.writhe+=/life_tap,moving=1,if=mana.pct<80
    if S.LifeTap:IsCastable() and Player:IsMoving() and Player:ManaPercentage() < 80 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.writhe+=/agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if Player:IsMoving() and Target:DebuffRemains(S.Agony) <= Consts.AgonyBaseDuration - (3 * S.Agony:TickTime()) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Player:IsMoving() and Value:DebuffRemains(S.Agony) <= Consts.AgonyBaseDuration - (3 * S.Agony:TickTime()) and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if S.SiphonLife:IsAvailable() and Player:IsMoving() and Target:DebuffRemains(S.SiphonLife) <= Consts.SiphonLifeBaseDuration - (3 * S.SiphonLife:TickTime()) then
      if AR.Cast(S.SiphonLife) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SiphonLife:IsAvailable() and Player:IsMoving() and Value:DebuffRemains(S.SiphonLife) <= Consts.SiphonLifeBaseDuration - (3 * S.SiphonLife:TickTime()) and Value:TimeToDie()-Value:DebuffRemains(S.SiphonLife) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if Player:IsMoving() and Target:DebuffRemains(S.CorruptionDebuff) <= Consts.AgonyBaseDuration - (3 * S.CorruptionDebuff:TickTime()) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Player:IsMoving() and Value:DebuffRemains(S.CorruptionDebuff) <= Consts.AgonyBaseDuration - (3 * S.CorruptionDebuff:TickTime()) and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.writhe+=/life_tap,moving=0
    if S.LifeTap:IsCastable() then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
  end
  
  local function MGAPL()
    -- actions.mg=reap_souls,if=!buff.deadwind_harvester.remains&time>5&((buff.tormented_souls.react>=4+active_enemies|buff.tormented_souls.react>=9)|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
    if not Player:Buff(S.DeadwindHarvester) and AC.CombatTime()>5 and SoulsAvailable()>1
      and ((SoulsAvailable()>= 4+Cache.EnemiesCount[40] or SoulsAvailable()>=9) or Target:TimeToDie() <= ((SoulsAvailable()*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0))) + (Player:BuffRemains(S.DeadwindHarvester)*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0))/12*(5+1.5*(I.ReapAndSow:IsEquipped() and 1 or 0))))) then
        if AR.Cast(S.ReapSouls) then return "Cast"; end
    end
    
    -- actions.mg+=/agony,cycle_targets=1,max_cycle_targets=5,target_if=sim.target!=target&talent.soul_harvest.enabled&cooldown.soul_harvest.remains<cast_time*6&remains<=duration*0.3&target.time_to_die>=remains&time_to_die>tick_time*3
    -- actions.mg+=/agony,cycle_targets=1,max_cycle_targets=4,if=remains<=(tick_time+gcd)
    if Target:DebuffRemains(S.Agony)<=(Player:GCD()+S.Agony:TickTime()) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemains()<Player:GCD()*6 and Value:DebuffRemains(S.Agony)<=Consts.AgonyBaseDuration*0.3 and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD and Value:TimeToDie()>S.Agony:TickTime()*3 and NbAffected(S.Agony)<=5 then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3&soul_shard=5
    if S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[40]>=3 and FutureShard()==5 then
      if AR.Cast(S.SeedOfCorruption) then return "Cast"; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&soul_shard=5
    if FutureShard()==5 then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.mg+=/drain_soul,cycle_targets=1,if=target.time_to_die<gcd*2&soul_shard<5
    BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 0, nil;
    for Key, Value in pairs(Cache.Enemies[range]) do
      if FutureShard()<5 and Value:TimeToDie()<Player:GCD()*2 then
        BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.DrainSoul;
      end
    end
    if BestUnit then
      if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
    end
    
    -- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
    if AR.CDsON() and S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and (Player:BuffRemains(S.EmpoweredLifeTapBuff)<0.3*Consts.EmpoweredLifeTapBaseDuration) then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.mg+=/service_pet,if=dot.corruption.remains&dot.agony.remains
    if S.GrimoireFelhunter:IsAvailable() and S.GrimoireFelhunter:IsCastable() and FutureShard()>=1 and Target:Debuff(S.Agony) and Target:Debuff(S.CorruptionDebuff) then
      if AR.Cast(S.GrimoireFelhunter, Settings.Affliction.GCDasOffGCD.GrimoireFelhunter) then return "Cast"; end
    end
    
    -- actions.mg+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
    if AR.CDsON() and S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:IsCastable() and FutureShard()>=1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]<=2 
      and (Target:TimeToDie()>180 or Target:HealthPercentage()<=20 or Target:TimeToDie()<30) then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    
    -- actions.mg+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
    if AR.CDsON() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:IsCastable() and FutureShard()>=1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]>2 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end
    
    -- actions.mg+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if AR.CDsON() and S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:IsCastable() and FutureShard()>=1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]==1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    
    -- actions.mg+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if AR.CDsON() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:IsCastable() and FutureShard()>=1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[40]>1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end
    
    -- actions.mg+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
    if AR.CDsON() and S.Berserking:IsAvailable() and S.Berserking:IsCastable() and (Player:PrevGCD(1,S.UnstableAffliction) or Player:BuffRemains(S.SoulHarvest)>=10)  then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
    end
    
    -- actions.mg+=/blood_fury
    if AR.CDsON() and S.BloodFury:IsAvailable() and S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
    end
    
    -- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=(tick_time+gcd)&target.time_to_die>tick_time*3
    if S.SiphonLife:IsAvailable() and Target:DebuffRemains(S.SiphonLife)<=(S.SiphonLife:TickTime()+Player:GCD()) and Target:TimeToDie()>S.SiphonLife:TickTime()*3 then
        if AR.Cast(S.SiphonLife) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SiphonLife:IsAvailable() and Value:DebuffRemains(S.SiphonLife)<=(S.SiphonLife:TickTime()+Player:GCD()) and Value:TimeToDie()>S.SiphonLife:TickTime()*3 and Value:TimeToDie()-Value:DebuffRemains(S.SiphonLife) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/corruption,cycle_targets=1,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&remains<=(tick_time+gcd)&target.time_to_die>tick_time*3
    if Target:DebuffRemains(S.CorruptionDebuff)<=(Player:GCD()+S.CorruptionDebuff:TickTime()) then
      if AR.Cast(S.Corruption) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if (not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[40]<3) and Cache.EnemiesCount[40]<5 and Value:DebuffRemains(S.CorruptionDebuff)<=Consts.CorruptionBaseDuration*0.3 and Value:TimeToDie()-Value:DebuffRemains(S.CorruptionDebuff) > BestUnitTTD and Value:TimeToDie()>S.CorruptionDebuff:TickTime()*3 then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/phantom_singularity
    if S.PhantomSingularity:IsAvailable() and S.PhantomSingularity:IsCastable()  then
        if AR.Cast(S.PhantomSingularity) then return "Cast"; end
    end
    
    -- actions.mg+=/soul_harvest,if=buff.active_uas.stack>1&buff.soul_harvest.remains<=8&sim.target=target&(!talent.deaths_embrace.enabled|target.time_to_die>=136|target.time_to_die<=40)
    if AR.CDsON() and S.SoulHarvest:IsAvailable() and S.SoulHarvest:IsCastable() and ActiveUAs()>1 and Player:BuffRemains(S.SoulHarvest)<=8 and (not S.DeathsEmbrace:IsAvailable() or Target:TimeToDie()>136 or Target:TimeToDie()<=40) then
        if AR.Cast(S.SoulHarvest, Settings.Affliction.OffGCDasOffGCD.SoulHarvest) then return "Cast"; end
    end
    
    -- actions.mg+=/use_item,slot=trinket1
    -- actions.mg+=/use_item,slot=trinket2
    -- actions.mg+=/potion,if=target.time_to_die<=70
    -- actions.mg+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&buff.active_uas.stack>=2
    --TODO : trinket & potion
    
    -- actions.mg+=/agony,cycle_targets=1,if=remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.agony)
    if Target:DebuffRemains(S.Agony)<=Consts.AgonyBaseDuration*0.3 and Target:TimeToDie() >= Player:BuffRemains(S.Agony) and (ActiveUAs()==0 or Player:PrevGCD(1,S.Agony)) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRemains(S.Agony)<=Consts.AgonyBaseDuration*0.3 and Value:TimeToDie() >= Player:BuffRemains(S.Agony) and (ActiveUAs()==0 or Player:PrevGCD(1,S.Agony)) and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.siphon_life)
    if S.SiphonLife:IsAvailable() and Target:DebuffRemains(S.SiphonLife)<=Consts.SiphonLifeBaseDuration*0.3 and Target:TimeToDie() >= Player:BuffRemains(S.SiphonLife) and (ActiveUAs()==0 or Player:PrevGCD(1,S.SiphonLife)) then
        if AR.Cast(S.SiphonLife) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SiphonLife:IsAvailable() and Value:DebuffRemains(S.SiphonLife)<=Consts.SiphonLifeBaseDuration*0.3 and Value:TimeToDie() >= Player:BuffRemains(S.SiphonLife) and (ActiveUAs()==0 or Player:PrevGCD(1,S.SiphonLife)) and Value:TimeToDie()-Value:DebuffRemains(S.SiphonLife) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/corruption,cycle_targets=1,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.corruption)
    if Target:DebuffRemains(S.CorruptionDebuff)<=(Player:GCD()+S.CorruptionDebuff:TickTime()) and (ActiveUAs()==0 or Player:PrevGCD(1,S.Corruption)) then
      if AR.Cast(S.Corruption) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if (not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[40]<3) and Cache.EnemiesCount[40]<5 and Value:DebuffRemains(S.CorruptionDebuff)<=Consts.CorruptionBaseDuration*0.3 and Value:TimeToDie()-Value:DebuffRemains(S.CorruptionDebuff) > BestUnitTTD and Value:TimeToDie()>S.CorruptionDebuff:TickTime()*3 and (ActiveUAs()==0 or Player:PrevGCD(1,S.Corruption)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
    if S.LifeTap:IsCastable() and Target:TimeToDie() > 15 and Player:ManaPercentage() < 10 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.mg+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>=5&dot.corruption.remains<=cast_time+travel_time)
    if (S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[40] >= 3) or (Cache.EnemiesCount[40] >= 5 and Target:DebuffRemains(S.CorruptionDebuff) <= S.SeedOfCorruption:CastTime()+S.SeedOfCorruption:TravelTime()) then
      if AR.Cast(S.SeedOfCorruption) then return "Cast"; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&target.time_to_die<30
    if FutureShard()>=1 and Target:TimeToDie() <30 then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&active_enemies>1&soul_shard>=4
    if FutureShard()>=4 and Cache.EnemiesCount[40]>1 then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&(buff.active_uas.stack=0|(!prev_gcd.3.unstable_affliction&prev_gcd.1.unstable_affliction))&dot.agony.remains>cast_time+(6.5*spell_haste)
    if FutureShard()>=1 and (ActiveUAs()==0 or (not Player:PrevGCD(3,S.UnstableAffliction) and Player:PrevGCD(1,S.UnstableAffliction))) and (Target:DebuffRemains(S.Agony)>S.UnstableAffliction:CastTime()+(6.5*Player:SpellHaste())) then
      if AR.Cast(S.UnstableAffliction) then return "Cast"; end
    end
    
    -- actions.mg+=/reap_souls,if=buff.deadwind_harvester.remains<dot.unstable_affliction_1.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_2.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_3.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_4.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_5.remains&buff.active_uas.stack>1
    if CheckDeadwindHarvester() and ActiveUAs()>1 and SoulsAvailable()>1 then 
      if AR.Cast(S.ReapSouls) then return "Cast"; end
    end
    
    -- actions.mg+=/life_tap,if=mana.pct<=10
    if S.LifeTap:IsCastable() and Player:ManaPercentage() < 10 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.mg+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
    if S.LifeTap:IsCastable() and ActiveUAs()==0 and Player:PrevGCD(1,S.LifeTap) and Player:ManaPercentage() < 50 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.mg+=/drain_soul,chain=1,interrupt=1
    if S.DrainSoul:IsCastable() then
      if AR.Cast(S.DrainSoul) then return "Cast"; end
    end
    
    -- actions.mg+=/life_tap,moving=1,if=mana.pct<80
    if S.LifeTap:IsCastable() and Player:IsMoving() and Player:ManaPercentage() < 80 then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
    
    -- actions.mg+=/agony,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
    if Player:IsMoving() and Target:DebuffRemains(S.Agony) <= Consts.AgonyBaseDuration - (3 * S.Agony:TickTime()) then
      if AR.Cast(S.Agony) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Player:IsMoving() and Value:DebuffRemains(S.Agony) <= Consts.AgonyBaseDuration - (3 * S.Agony:TickTime()) and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/siphon_life,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
    if S.SiphonLife:IsAvailable() and Player:IsMoving() and Target:DebuffRemains(S.SiphonLife) <= Consts.SiphonLifeBaseDuration - (3 * S.SiphonLife:TickTime()) then
      if AR.Cast(S.SiphonLife) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.SiphonLife:IsAvailable() and Player:IsMoving() and Value:DebuffRemains(S.SiphonLife) <= Consts.SiphonLifeBaseDuration - (3 * S.SiphonLife:TickTime()) and Value:TimeToDie()-Value:DebuffRemains(S.SiphonLife) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/corruption,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
    if Player:IsMoving() and Target:DebuffRemains(S.CorruptionDebuff) <= Consts.AgonyBaseDuration - (3 * S.CorruptionDebuff:TickTime()) then
      if AR.Cast(S.Corruption) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Player:IsMoving() and Value:DebuffRemains(S.CorruptionDebuff) <= Consts.AgonyBaseDuration - (3 * S.CorruptionDebuff:TickTime()) and Value:TimeToDie()-Value:DebuffRemains(S.Agony) > BestUnitTTD then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
      end
    end
    
    -- actions.mg+=/life_tap,moving=0
    if S.LifeTap:IsCastable() then
      if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return "Cast"; end
    end
  end

--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    --TODO : change to DeBuffRefreshable
    
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
    if S.SummonFelhunter:IsCastable() and not IsPetInvoked() and not S.GrimoireOfSupremacy:IsAvailable() and (not S.GrimoireOfSacrifice:IsAvailable() or not Player:Buff(S.DemonicPower)) and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonFelhunter, Settings.Affliction.GCDasOffGCD.SummonFelhunter) then return "Cast"; end
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
        if S.Haunt:IsAvailable() then
          ShouldReturn = HauntAPL();
          if ShouldReturn then return ShouldReturn; end
        end
        if S.WritheInAgony:IsAvailable() then
          ShouldReturn = WritheAPL();
          if ShouldReturn then return ShouldReturn; end
        end
        if S.MaleficGrasp:IsAvailable() then
          ShouldReturn = MGAPL();
          if ShouldReturn then return ShouldReturn; end
        end
        
    end
  end

  AR.SetAPL(265, APL);


--- ======= SIMC =======
--- Last Update: 27/09/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
-- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
-- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
-- actions.precombat+=/potion

-- # Executed every time the actor is available.
-- actions=call_action_list,name=haunt,if=talent.haunt.enabled
-- actions+=/call_action_list,name=writhe,if=talent.writhe_in_agony.enabled
-- actions+=/call_action_list,name=mg,if=talent.malefic_grasp.enabled

-- actions.haunt=reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
-- actions.haunt+=/reap_souls,if=debuff.haunt.remains&!buff.deadwind_harvester.remains
-- actions.haunt+=/reap_souls,if=active_enemies>1&!buff.deadwind_harvester.remains&time>5&soul_shard>0&((talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|spell_targets.seed_of_corruption>=5)
-- actions.haunt+=/agony,cycle_targets=1,if=remains<=tick_time+gcd
-- actions.haunt+=/drain_soul,cycle_targets=1,if=target.time_to_die<=gcd*2&soul_shard<5
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
-- actions.haunt+=/potion,if=!talent.soul_harvest.enabled&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
-- actions.haunt+=/potion,if=talent.soul_harvest.enabled&buff.soul_harvest.remains&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|!cooldown.haunt.remains|buff.active_uas.stack>2)
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
-- actions.haunt+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
-- actions.haunt+=/drain_soul,chain=1,interrupt=1
-- actions.haunt+=/life_tap,moving=1,if=mana.pct<80
-- actions.haunt+=/agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.haunt+=/siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.haunt+=/corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.haunt+=/life_tap,moving=0

-- actions.mg=reap_souls,if=!buff.deadwind_harvester.remains&time>5&((buff.tormented_souls.react>=4+active_enemies|buff.tormented_souls.react>=9)|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
-- actions.mg+=/agony,cycle_targets=1,max_cycle_targets=5,target_if=sim.target!=target&talent.soul_harvest.enabled&cooldown.soul_harvest.remains<cast_time*6&remains<=duration*0.3&target.time_to_die>=remains&time_to_die>tick_time*3
-- actions.mg+=/agony,cycle_targets=1,max_cycle_targets=4,if=remains<=(tick_time+gcd)
-- actions.mg+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3&soul_shard=5
-- actions.mg+=/unstable_affliction,if=target=sim.target&soul_shard=5
-- actions.mg+=/drain_soul,cycle_targets=1,if=target.time_to_die<gcd*2&soul_shard<5
-- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
-- actions.mg+=/service_pet,if=dot.corruption.remains&dot.agony.remains
-- actions.mg+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions.mg+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
-- actions.mg+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.mg+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.mg+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
-- actions.mg+=/blood_fury
-- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=(tick_time+gcd)&target.time_to_die>tick_time*3
-- actions.mg+=/corruption,cycle_targets=1,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&remains<=(tick_time+gcd)&target.time_to_die>tick_time*3
-- actions.mg+=/phantom_singularity
-- actions.mg+=/soul_harvest,if=buff.active_uas.stack>1&buff.soul_harvest.remains<=8&sim.target=target&(!talent.deaths_embrace.enabled|target.time_to_die>=136|target.time_to_die<=40)
-- actions.mg+=/use_item,slot=trinket1
-- actions.mg+=/use_item,slot=trinket2
-- actions.mg+=/potion,if=target.time_to_die<=70
-- actions.mg+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&buff.active_uas.stack>=2
-- actions.mg+=/agony,cycle_targets=1,if=remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.agony)
-- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.siphon_life)
-- actions.mg+=/corruption,cycle_targets=1,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.corruption)
-- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
-- actions.mg+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>=5&dot.corruption.remains<=cast_time+travel_time)
-- actions.mg+=/unstable_affliction,if=target=sim.target&target.time_to_die<30
-- actions.mg+=/unstable_affliction,if=target=sim.target&active_enemies>1&soul_shard>=4
-- actions.mg+=/unstable_affliction,if=target=sim.target&(buff.active_uas.stack=0|(!prev_gcd.3.unstable_affliction&prev_gcd.1.unstable_affliction))&dot.agony.remains>cast_time+(6.5*spell_haste)
-- actions.mg+=/reap_souls,if=buff.deadwind_harvester.remains<dot.unstable_affliction_1.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_2.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_3.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_4.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_5.remains&buff.active_uas.stack>1
-- actions.mg+=/life_tap,if=mana.pct<=10
-- actions.mg+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
-- actions.mg+=/drain_soul,chain=1,interrupt=1
-- actions.mg+=/life_tap,moving=1,if=mana.pct<80
-- actions.mg+=/agony,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
-- actions.mg+=/siphon_life,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
-- actions.mg+=/corruption,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
-- actions.mg+=/life_tap,moving=0

-- actions.writhe=  reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.soul_harvest.remains>=(5+1.5*equipped.144364)&buff.active_uas.stack>1|buff.concordance_of_the_legionfall.react|trinket.proc.intellect.react|trinket.stacking_proc.intellect.react|trinket.proc.mastery.react|trinket.stacking_proc.mastery.react|trinket.proc.crit.react|trinket.stacking_proc.crit.react|trinket.proc.versatility.react|trinket.stacking_proc.versatility.react|trinket.proc.spell_power.react|trinket.stacking_proc.spell_power.react)
-- actions.writhe+=/agony,if=remains<=tick_time+gcd
-- actions.writhe+=/agony,cycle_targets=1,max_cycle_targets=5,target_if=sim.target!=target&talent.soul_harvest.enabled&cooldown.soul_harvest.remains<cast_time*6&remains<=duration*0.3&target.time_to_die>=remains&time_to_die>tick_time*3
-- actions.writhe+=/agony,cycle_targets=1,max_cycle_targets=3,target_if=sim.target!=target&remains<=tick_time+gcd&time_to_die>tick_time*3
-- actions.writhe+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3&soul_shard=5
-- actions.writhe+=/unstable_affliction,if=soul_shard=5|(time_to_die<=((duration+cast_time)*soul_shard))
-- actions.writhe+=/drain_soul,cycle_targets=1,if=target.time_to_die<=gcd*2&soul_shard<5
-- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
-- actions.writhe+=/service_pet,if=dot.corruption.remains&dot.agony.remains
-- actions.writhe+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions.writhe+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
-- actions.writhe+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.writhe+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions.writhe+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
-- actions.writhe+=/blood_fury
-- actions.writhe+=/soul_harvest,if=sim.target=target&buff.soul_harvest.remains<=8&(buff.active_uas.stack>=2|active_enemies>3)&(!talent.deaths_embrace.enabled|time_to_die>120|time_to_die<30)
-- actions.writhe+=/use_item,slot=trinket1
-- actions.writhe+=/use_item,slot=trinket2
-- actions.writhe+=/potion,if=target.time_to_die<=70
-- actions.writhe+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&(trinket.proc.any.react|trinket.stack_proc.any.react|buff.active_uas.stack>=2)
-- actions.writhe+=/siphon_life,cycle_targets=1,if=remains<=tick_time+gcd&time_to_die>tick_time*2
-- actions.writhe+=/corruption,cycle_targets=1,if=remains<=tick_time+gcd&((spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled)|spell_targets.seed_of_corruption<5)&time_to_die>tick_time*2
-- actions.writhe+=/life_tap,if=mana.pct<40&(buff.active_uas.stack<1|!buff.deadwind_harvester.remains)
-- actions.writhe+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
-- actions.writhe+=/phantom_singularity
-- actions.writhe+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>3&dot.corruption.refreshable)
-- actions.writhe+=/unstable_affliction,if=talent.contagion.enabled&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.writhe+=/unstable_affliction,cycle_targets=1,target_if=buff.deadwind_harvester.remains>=duration+cast_time&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.writhe+=/unstable_affliction,if=buff.deadwind_harvester.remains>tick_time*2&(!talent.contagion.enabled|soul_shard>1|buff.soul_harvest.remains)&(dot.unstable_affliction_1.ticking+dot.unstable_affliction_2.ticking+dot.unstable_affliction_3.ticking+dot.unstable_affliction_4.ticking+dot.unstable_affliction_5.ticking<5)
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&buff.active_uas.stack>1
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1
-- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3&(!buff.deadwind_harvester.remains|buff.active_uas.stack<1)
-- actions.writhe+=/agony,if=refreshable&time_to_die>=remains
-- actions.writhe+=/siphon_life,if=refreshable&time_to_die>=remains
-- actions.writhe+=/corruption,if=refreshable&time_to_die>=remains
-- actions.writhe+=/agony,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
-- actions.writhe+=/siphon_life,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
-- actions.writhe+=/corruption,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
-- actions.writhe+=/life_tap,if=mana.pct<=10
-- actions.writhe+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
-- actions.writhe+=/drain_soul,chain=1,interrupt=1
-- actions.writhe+=/life_tap,moving=1,if=mana.pct<80
-- actions.writhe+=/agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.writhe+=/siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.writhe+=/corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.writhe+=/life_tap,moving=0

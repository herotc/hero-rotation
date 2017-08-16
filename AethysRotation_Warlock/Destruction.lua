
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
  IncinerateAuto		= Spell(29722),
  IncinerateOrange 	= Spell(40239),
  IncinerateGreen 	= Spell(124472),
	Immolate 				  = Spell(348),
	ImmolateAuto 		  = Spell(348),
	ImmolateOrange 		= Spell(118297),
	ImmolateGreen 		= Spell(124470),
	ImmolateDebuff 		= Spell(157736),
	Conflagrate 			= Spell(17962),
	ConflagrateAuto		= Spell(17962),
	ConflagrateOrange = Spell(156960),
	ConflagrateGreen 	= Spell(124480),
	ChaosBolt 				= Spell(116858),
	DrainLife 				= Spell(234153),
	RainOfFire 				= Spell(5740),
	RainOfFireAuto 		= Spell(5740),
	RainOfFireOrange 	= Spell(42023),
	RainOfFireGreen 	= Spell(173561),
	Havoc 					  = Spell(80240),
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
	ConflagrationOfChaosDebuff 	= Spell(196546),
	DimensionRipper 	= Spell(219415),
    -- Defensive	
    
    -- Utility
    
    -- Legendaries
  LessonsOfSpaceTimeBuff = Spell(236176),
    
    -- Misc
	DemonicPower 			    = Spell(196099),
	EmpoweredLifeTapBuff	= Spell(235156),
  LordOfFlamesDebuff = Spell(226802),
  BackdraftBuff = Spell(117828),
  Concordance = Spell(242586),
    
    -- Macros
    
  };
  local S = Spell.Warlock.Destruction;
  
  local PetSpells={[S.Suffering:ID()]=true, [S.SpellLock:ID()]=true, [S.Whiplash:ID()]=true, [S.CauterizeMaster:ID()]=true }
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Destruction = {
    -- Legendaries
    LessonsOfSpaceTime= Item(144369), --3
    SindoreiSpite= Item(132379), --9
  };
  local I = Item.Warlock.Destruction;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P,T194P = AC.HasTier("T19")
  local T202P,T204P = AC.HasTier("T20")
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range=40
  local CastIncinerate,CastImmolate,CastConflagrate,CastRainOfFire
  
  local Consts={
    ImmolateBaseDuration = 18,
    ImmolateMaxDuration = 27,
    EmpoweredLifeTapBaseDuration = 20
  }
  
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
  
  local function GetImmolateStack(target)
    if not S.RoaringBlaze:IsAvailable() then  
      return nil
    end
    if not target then 
      return nil
    end
    return AC.ImmolationTable.Destruction.ImmolationDebuff[target:GUID()];
  end
  
  local function EnemyHasHavoc()
    for _, Value in pairs(Cache.Enemies[range]) do
      if Value:Debuff(S.Havoc) then
      return Value:DebuffRemains(S.Havoc)
      end
    end
    return 0
  end

  local function handleSettings()
    if Settings.Commons.SpellType=="Auto" then --auto
      CastIncinerate=S.IncinerateAuto
      CastImmolate=S.ImmolateAuto
      CastConflagrate=S.ConflagrateAuto
      CastRainOfFire=S.RainOfFireAuto
    elseif Settings.Commons.SpellType=="Green" then --green
      CastIncinerate=S.IncinerateGreen
      CastImmolate=S.ImmolateGreen
      CastConflagrate=S.ConflagrateGreen
      CastRainOfFire=S.RainOfFireGreen
    else --orange
      CastIncinerate=S.IncinerateOrange
      CastImmolate=S.ImmolateOrange
      CastConflagrate=S.ConflagrateOrange
      CastRainOfFire=S.RainOfFireOrange
    end
    
  end

--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    handleSettings()
    -- Defensives
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonImp:IsCastable() and not IsPetInvoked() and not S.GrimoireOfSupremacy:IsAvailable() and (not S.GrimoireOfSacrifice:IsAvailable() or not Player:Buff(S.DemonicPower)) and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonImp, Settings.Commons.GCDasOffGCD.SummonImp) then return "Cast"; end
    end
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:IsCastable() and not S.MeteorStrike:IsLearned() and  ((S.LordOfFlames:ArtifactRank()>0) or (AR.AoEON() and Cache.EnemiesCount[range]>1)) and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:IsCastable() and not S.ShadowLock:IsLearned() and not S.LordOfFlames:ArtifactRank()==0 and Cache.EnemiesCount[range]==1 and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireOfSacrifice:IsCastable() and IsPetInvoked() and not Player:Buff(S.DemonicPower) then
      if AR.Cast(S.GrimoireOfSacrifice, Settings.Destruction.GCDasOffGCD.GrimoireOfSacrifice) then return "Cast"; end
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
        if AR.Cast(S.ChaosBolt) then return "Cast"; end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- actions=immolate,cycle_targets=1,if=active_enemies=2&talent.roaring_blaze.enabled&!cooldown.havoc.remains&dot.immolate.remains<=buff.active_havoc.duration
      if AR.AoEON() and Cache.EnemiesCount[range]==2 and S.RoaringBlaze:IsAvailable() and not S.Havoc:IsCastable() then
        BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains = nil, Player:GCD()*2, nil, Consts.ImmolateMaxDuration;
        for _, Value in pairs(Cache.Enemies[range]) do
          if Value:DebuffRemains(S.ImmolateDebuff)<= S.Havoc:Cooldown() and Target:DebuffRemains(S.ImmolateDebuff) < DebuffRemains then
            BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains = Value, Value:TimeToDie(), CastImmolate, Target:DebuffRemains(S.ImmolateDebuff);
          end	
        end
        if BestUnit then
          if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
        end
      end
      
      -- actions=havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
      if AR.AoEON() and Cache.EnemiesCount[range]>1 then
        BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD()*2, nil;
        for _, Value in pairs(Cache.Enemies[range]) do
          if S.Havoc:IsCastable() and (Cache.EnemiesCount[range]<4 or (S.WreakHavoc:IsAvailable() and Cache.EnemiesCount[range]<6)) and not Value:IsUnit(Target) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Havoc;
          end	
        end
        if BestUnit then
          if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
        end
      end
      
      -- actions+=/dimensional_rift,if=charges=3
      if S.DimensionalRift:IsCastable() and S.DimensionalRift:Charges() == 3 or (S.DimensionalRift:Charges() == 2 and S.DimensionalRift:Recharge() < Player:GCD()) then
        if AR.Cast(S.DimensionalRift) then return "Cast"; end
      end
      
      -- actions+=/cataclysm,if=spell_targets.cataclysm>=3
      if AR.AoEON() and Cache.EnemiesCount[range]>=3 and S.Cataclysm:IsAvailable() and S.Cataclysm:IsCastable() and not (Player:IsCasting() and Player:CastID()==S.Cataclysm:ID())then
        if AR.Cast(S.Cataclysm) then return "Cast"; end
      end
      
      -- actions+=/immolate,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&remains<=tick_time
      if (not AR.AoEON() or (AR.AoEON() and (Cache.EnemiesCount[range]<5 or not S.FireAndBrimstone:IsAvailable()))) and Target:DebuffRemains(S.ImmolateDebuff)<Player:GCD() and not (Player:IsCasting() and (Player:CastID()==S.Immolate:ID() or Player:CastID()==S.Cataclysm:ID())) then
        if AR.Cast(CastImmolate) then return "Cast"; end
      end
      
      -- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&active_enemies>1&remains<=tick_time&(!talent.roaring_blaze.enabled|(!debuff.roaring_blaze.remains&action.conflagrate.charges<2+set_bonus.tier19_4pc))
      if AR.AoEON() and (Cache.EnemiesCount[range]<5 or not S.FireAndBrimstone:IsAvailable()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:Cooldown()>= S.Immolate:CastTime()*Cache.EnemiesCount[range]) and Cache.EnemiesCount[range]>1 then
        BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains = nil, Player:GCD()*2, nil,Consts.ImmolateMaxDuration;
        for _, Value in pairs(Cache.Enemies[range]) do
          if Value:DebuffRemains(S.ImmolateDebuff)<Player:GCD() and (not S.RoaringBlaze:IsAvailable() or (S.RoaringBlaze:IsAvailable() and (GetImmolateStack(Value)==0 or GetImmolateStack(Value)==nil) and S.Conflagrate:Charges()<2+(T194P and 1 or 0))) and Value:DebuffRemains(S.ImmolateDebuff) < DebuffRemains and not Value:Debuff(S.Havoc) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), CastImmolate;
          end	
        end
        if BestUnit then
          if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
        end
      end
      
      -- actions+=/immolate,if=talent.roaring_blaze.enabled&remains<=duration&!debuff.roaring_blaze.remains&target.time_to_die>10&(action.conflagrate.charges=2+set_bonus.tier19_4pc|(action.conflagrate.charges>=1+set_bonus.tier19_4pc&action.conflagrate.recharge_time<cast_time+gcd)|target.time_to_die<24)
      if S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.ImmolateDebuff)<= Consts.ImmolateBaseDuration and (GetImmolateStack(Target)==0 or GetImmolateStack(Target)==nil) and Target:TimeToDie()>10
        and (S.Conflagrate:Charges()==2+(T194P and 1 or 0) or ( S.Conflagrate:Charges()>=1+(T194P and 1 or 0) and S.Conflagrate:Recharge()<S.Immolate:CastTime()+Player:GCD())or Target:TimeToDie()<24) and not(Player:IsCasting() and (Player:CastID()==S.Immolate:ID() or Player:CastID()==S.Cataclysm:ID())) then
        if AR.Cast(CastImmolate) then return "Cast"; end
      end
      
      -- actions+=/berserking
      if AR.CDsON() and S.Berserking:IsAvailable() and S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return "Cast"; end
      end
      
      -- actions+=/shadowburn,if=buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
      if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and S.Shadowburn:Charges()>=1 and Player:BuffRemains(S.ConflagrationOfChaosDebuff)<=S.ChaosBolt:CastTime() then
        if AR.Cast(S.Shadowburn) then return "Cast"; end
      end
      
      -- actions+=/shadowburn,if=(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
      if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and S.Shadowburn:Charges()>=1  and Player:SoulShards()<5 and ((S.Shadowburn:Charges()>=1+(T194P and 1 or 0) and  S.Shadowburn:Recharge()<S.ChaosBolt:CastTime()+Player:GCD()) or (S.Shadowburn:Charges()==2+(T194P and 1 or 0))) then
        if AR.Cast(S.Shadowburn) then return "Cast"; end
      end
      
      -- actions+=/conflagrate,if=talent.roaring_blaze.enabled&(charges=2+set_bonus.tier19_4pc|(charges>=1+set_bonus.tier19_4pc&recharge_time<gcd)|target.time_to_die<24)
      if S.RoaringBlaze:IsAvailable() and S.Conflagrate:Charges()>0 and (S.Conflagrate:Charges()==2+(T194P and 1 or 0) or ( S.Conflagrate:Charges()>=1+(T194P and 1 or 0) and S.Conflagrate:Recharge()<S.Immolate:CastTime()+Player:GCD())or Target:TimeToDie()<24) then
        if AR.Cast(CastConflagrate) then return "Cast"; end
      end
      
      -- actions+=/conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.stack>0& dot.immolate.remains>dot.immolate.duration*0.3&(active_enemies=1|soul_shard<3)&soul_shard<5
      if S.RoaringBlaze:IsAvailable() and S.Conflagrate:Charges()>0 and (GetImmolateStack(Target) and GetImmolateStack(Target)>0) and Target:DebuffRemains(S.ImmolateDebuff)>Consts.ImmolateBaseDuration*0.3 and (Cache.EnemiesCount[range]==1 or Player:SoulShards()<3) and Player:SoulShards()<5 then
        if AR.Cast(CastConflagrate) then return "Cast"; end
      end
      
      -- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
      if S.Backdraft:IsAvailable() and S.Conflagrate:Charges()>0 and Player:BuffStack(S.BackdraftBuff)<3 and Player:BuffRemains(S.ConflagrationOfChaosDebuff)<=S.ChaosBolt:CastTime() then
        if AR.Cast(CastConflagrate) then return "Cast"; end
      end
      
      -- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)& soul_shard<5
      if S.Backdraft:IsAvailable() and Player:BuffStack(S.BackdraftBuff)<3 and (( S.Conflagrate:Charges()==1+(T194P and 1 or 0) and S.Conflagrate:Recharge()<S.Immolate:CastTime()+Player:GCD()) or S.Conflagrate:Charges()==2+(T194P and 1 or 0)) and Player:SoulShards()<5 then
        if AR.Cast(CastConflagrate) then return "Cast"; end
      end
      
      -- actions+=/dimensional_rift,if=equipped.144369&!buff.lessons_of_spacetime.remains&((!talent.grimoire_of_supremacy.enabled&!cooldown.summon_doomguard.remains)|(talent.grimoire_of_service.enabled&!cooldown.service_pet.remains)|(talent.soul_harvest.enabled&!cooldown.soul_harvest.remains))
      if S.DimensionalRift:IsCastable() and S.DimensionalRift:Charges()>0 and I.LessonsOfSpaceTime:IsEquipped(3) and not Player:Buff(S.LessonsOfSpaceTimeBuff) and ((not S.GrimoireOfSupremacy:IsAvailable() and not S.SummonDoomGuard:CooldownUp()) or(S.GrimoireOfService:IsAvailable() and not S.GrimoireImp:IsAvailable()) or (S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownUp())) then
        if AR.Cast(S.DimensionalRift) then return "Cast"; end
      end
      
      -- actions+=/service_pet
      if S.GrimoireImp:IsAvailable() and S.GrimoireImp:IsCastable() and Player:SoulShards()>=1 and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.GrimoireImp, Settings.Commons.GCDasOffGCD.GrimoireImp) then return "Cast"; end
      end
      
      -- actions+=/summon_infernal,if=artifact.lord_of_flames.rank>0&!buff.lord_of_flames.remains
      if AR.CDsON() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:IsCastable() and S.LordOfFlames:ArtifactRank()>0 and not Player:Debuff(S.LordOfFlamesDebuff) and Player:SoulShards ()>=1 and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
      end
      
      -- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
      if AR.CDsON() and S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:IsCastable() and not S.GrimoireOfSupremacy:IsAvailable() and ((AR.AoEON() and Cache.EnemiesCount[range]<=2) or not AR.AoEON()) and (Target:TimeToDie()>180 or Target:HealthPercentage()<=20 or Target:TimeToDie()<30) and Player:SoulShards ()>=1 and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
      end
      
      -- actions+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2
      if AR.CDsON() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:IsCastable() and not S.GrimoireOfSupremacy:IsAvailable() and (AR.AoEON() and Cache.EnemiesCount[range]>2) and Player:SoulShards ()>=1 and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
      end
      
      -- actions+=/soul_harvest,if=!buff.soul_harvest.remains
      if AR.CDsON() and S.SoulHarvest:IsAvailable() and S.SoulHarvest:IsCastable() and not Player:Buff(S.SoulHarvest) then
        if AR.Cast(S.SoulHarvest, Settings.Destruction.OffGCDasOffGCD.SoulHarvest) then return "Cast"; end
      end
      
      -- actions+=/chaos_bolt,if=active_enemies<4&buff.active_havoc.remains>cast_time
      if S.ChaosBolt:IsCastable() and Player:SoulShards ()>=2 and Cache.EnemiesCount[range]<4 and EnemyHasHavoc()>S.ChaosBolt:CastTime() and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.ChaosBolt) then return "Cast"; end
      end
      
      -- actions+=/channel_demonfire,if=dot.immolate.remains>cast_time&(active_enemies=1|buff.active_havoc.remains<action.chaos_bolt.cast_time)
      if S.ChannelDemonfire:IsCastable() and S.ChannelDemonfire:IsAvailable() and Target:DebuffRemains(S.ImmolateDebuff)>S.ChannelDemonfire:CastTime() and (Cache.EnemiesCount[range]==1 or EnemyHasHavoc()<S.ChaosBolt:CastTime()) and not (Player:IsChanneling() and Player:ChannelName()==S.ChannelDemonfire:Name()) then
        if AR.Cast(S.ChannelDemonfire) then return "Cast"; end
      end
      
      -- actions+=/rain_of_fire,if=active_enemies>=3
      if AR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range]>=3 and Player:SoulShards ()>=3 and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(CastRainOfFire) then return "Cast"; end
      end
      
      -- actions+=/dimensional_rift,if=target.time_to_die<=32|!equipped.144369|charges>1|((!talent.grimoire_of_service.enabled|recharge_time<cooldown.service_pet.remains)&(!talent.soul_harvest.enabled|recharge_time<cooldown.soul_harvest.remains)&(!talent.grimoire_of_supremacy.enabled|recharge_time<cooldown.summon_doomguard.remains))
      if S.DimensionalRift:IsCastable() and S.DimensionalRift:Charges()>0 and (Target:TimeToDie()<=32 or not I.LessonsOfSpaceTime:IsEquipped(3) or S.DimensionalRift:Charges()>1 or ((not S.GrimoireOfService:IsAvailable() or S.DimensionalRift:Recharge()<S.GrimoireImp:Cooldown()) and (not S.SoulHarvest:IsAvailable() or S.DimensionalRift:Recharge()<S.SoulHarvest:Cooldown()))) then
        if AR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return "Cast"; end
      end
      
      -- actions+=/cataclysm
      if S.Cataclysm:IsAvailable() and S.Cataclysm:IsCastable() and not (Player:IsCasting() and Player:CastID()==S.Cataclysm:ID()) then
        if AR.Cast(S.Cataclysm) then return "Cast"; end
      end
      
      -- actions+=/chaos_bolt,if=active_enemies<3&target.time_to_die<=10
      if S.ChaosBolt:IsCastable() and Player:SoulShards ()>=2 and Cache.EnemiesCount[range]<3 and Target:TimeToDie()<=10 and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.ChaosBolt) then return "Cast"; end
      end
      
      -- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*0.5)&(soul_shard>=5-spell_targets.infernal_awakening*0.5|buff.soul_harvest.remains>cast_time|buff.concordance_of_the_legionfall.remains>cast_time)
      if S.ChaosBolt:IsCastable() and Player:SoulShards ()>=2 and Cache.EnemiesCount[range]<3 and (S.Havoc:Cooldown()>12 or Cache.EnemiesCount[range]==1 or Player:SoulShards ()>=5-(Cache.EnemiesCount[range]*0.5)) and (Player:SoulShards ()>=5-(Cache.EnemiesCount[range]*0.5) or Player:BuffRemains(S.SoulHarvest)>S.ChaosBolt:CastTime() or Player:BuffRemains(S.Concordance)>S.ChaosBolt:CastTime()) and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.ChaosBolt) then return "Cast"; end
      end
      
      -- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*0.5)
      if S.ChaosBolt:IsCastable() and Player:SoulShards ()>=2 and Cache.EnemiesCount[range]<3 and (S.Havoc:Cooldown()>12 or Cache.EnemiesCount[range]==1 or Player:SoulShards ()>=5-(Cache.EnemiesCount[range]*0.5)) and not(Player:IsCasting() and Player:CastID()==S.ChaosBolt:ID() and Player:SoulShards()<=3) then
        if AR.Cast(S.ChaosBolt) then return "Cast"; end
      end
      
      -- actions+=/shadowburn
      if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and S.Shadowburn:Charges()>=1 then
        if AR.Cast(S.Shadowburn) then return "Cast"; end
      end
      
      -- actions+=/conflagrate,if=!talent.backdraft.enabled&buff.backdraft.stack<3
       if not S.Backdraft:IsAvailable() and Player:BuffStack(S.BackdraftBuff)<3 and  S.Conflagrate:Charges()>1 then
        if AR.Cast(CastConflagrate) then return "Cast"; end
      end
      
      -- actions+=/immolate,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&!talent.roaring_blaze.enabled&remains<=duration*0.3
      if S.Immolate:IsCastable() and (Cache.EnemiesCount[range]<5 or not S.FireAndBrimstone:IsAvailable()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:Cooldown()>=S.Immolate:CastTime()*Cache.EnemiesCount[range]) and not S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.ImmolateDebuff)<=Consts.ImmolateBaseDuration*0.3 and not (Player:IsCasting() and (Player:CastID()==S.Immolate:ID() or Player:CastID()==S.Cataclysm:ID())) then
        if AR.Cast(CastImmolate) then return "Cast"; end
      end
      
      -- actions+=/incinerate
      if S.Incinerate:IsCastable() and (S.Incinerate:Cost()<=Player:Mana()) then
        if AR.Cast(CastIncinerate) then return"Cast"; end
      end
      
      -- actions+=/life_tap   
      if AR.Cast(S.LifeTap) then return"Cast"; end
        
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

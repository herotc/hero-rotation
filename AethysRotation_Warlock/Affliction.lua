
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local AC = HeroLib;
  local Cache = HeroCache;
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
    
    DemonicCircle 		  = Spell(48018),
    MortalCoil 			    = Spell(6789),
    HowlOfTerror 			  = Spell(5484),
    
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
    UnendingResolve 	= Spell(104773),  
    
    -- Utility
    Fear            	= Spell(5782),
    
    -- Legendaries
    SindoreiSpiteBuff = Spell(208868), 
    SephuzBuff        = Spell(208052),
    NorgannonsBuff    = Spell(236431),
    
    -- Misc
    DemonicPower 			    = Spell(196099),
    EmpoweredLifeTapBuff	= Spell(235156),
    Concordance           = Spell(242586),
    DeadwindHarvester     = Spell(216708),
    TormentedSouls        = Spell(216695),
    TormentedAgony        = Spell(252938) --T21 4P
  };
  local S = Spell.Warlock.Affliction;
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Affliction = {
    -- Legendaries
    ReapAndSow                = Item(144364, {15}), 
    SindoreiSpite             = Item(132379, {9}), 
    StretensSleeplessShackles = Item(132381, {9}), 
    PowerCordofLethtendris    = Item(132457, {6}), 
    SephuzSecret 	            = Item(132452, {11,12}),
    
    --Potion
    PotionOfProlongedPower = Item(142117) 
  };
  local I = Item.Warlock.Affliction;
  
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P, T194P = AC.HasTier("T19");
  local T202P, T204P = AC.HasTier("T20");
  local T212P, T214P = AC.HasTier("T21");
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range = 40;
  local StackDurationCompute = 5 + 1.5 * (I.ReapAndSow:IsEquipped() and 1 or 0);
  local PetSpells = {[S.Suffering:ID()] = true, [S.SpellLock:ID()] = true, [S.Whiplash:ID()] = true, [S.CauterizeMaster:ID()] = true }
  local UnstableAfflictionDebuffs = {Spell(233490), Spell(233496), Spell(233497), Spell(233498), Spell(233499)}
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warlock.Commons,
    Affliction = AR.GUISettings.APL.Warlock.Affliction
  };
  
--- ======= ACTION LISTS =======
  local function IsPetInvoked (testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end
  
  local function SoulsAvailable ()
    return Player:BuffStack(S.TormentedSouls)
  end
  
  local function ActiveUAs ()
    local UAcount = 0
    for _, v in pairs(UnstableAfflictionDebuffs) do
      if Target:DebuffRemainsP(v) > 0 then UAcount = UAcount + 1 end
    end
    return UAcount
  end
  
  local function CheckDeadwindHarvester ()
    for _, v in pairs(UnstableAfflictionDebuffs) do
      if Player:BuffRemainsP(S.DeadwindHarvester) < Target:DebuffRemainsP(v) then return true; end
    end
    return false
  end
  
  local function CheckUnstableAffliction ()
    for _, v in pairs(UnstableAfflictionDebuffs) do
      if Target:DebuffRemainsP(v) > v:CastTime() then return false; end
    end
    return true
  end
  
  local function NbAffected (SpellAffected)
    local nbaff = 0
    for Key, Value in pairs(Cache.Enemies[range]) do
      if Value:DebuffRemainsP(SpellAffected) > 0 then nbaff = nbaff + 1; end
    end
    return nbaff;
  end
  
  local function ComputeDeadwindHarvesterDuration ()
    -- buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364))
    return ((SoulsAvailable() * StackDurationCompute ) + ((Player:BuffRemainsP(S.DeadwindHarvester) > 0 and 1 or 0) * StackDurationCompute / 12 * StackDurationCompute));
  end
  
  local function FutureShard ()
    local Shard = Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(S.UnstableAffliction) or Player:IsCasting(S.SeedOfCorruption) then
        return Shard - 1
      elseif Player:IsCasting(S.SummonDoomGuard) or Player:IsCasting(S.SummonDoomGuardSuppremacy) or Player:IsCasting(S.SummonInfernal) or Player:IsCasting(S.SummonInfernalSuppremacy) or Player:IsCasting(S.GrimoireFelhunter) or Player:IsCasting(S.SummonFelhunter) then
        return Shard - 1
      else
        return Shard
      end
    end
  end
  
  local function num(val)
    if val then return 1 else return 0 end
  end

  local function bool(val)
    return val ~= 0
  end
  
  local function Sephuz ()
    -- Howl Of Terror
    --TODO : change level when iscontrollable is here
    if S.HowlOfTerror:IsAvailable() and S.HowlOfTerror:IsCastable() and Target:Level() < 103 and Cache.EnemiesCount[10] > 0 and Settings.Affliction.Sephuz.HowlOfTerror then
      if AR.CastSuggested(S.HowlOfTerror) then return "Cast"; end
    end
    
    -- MortalCoil
    --TODO : change level when iscontrollable is here
    if S.MortalCoil:IsAvailable() and S.MortalCoil:IsCastable() and Target:Level() < 103 and Settings.Affliction.Sephuz.MortalCoil then
      if AR.CastSuggested(S.MortalCoil) then return "Cast"; end
    end
    
    -- Fear
    --TODO : change level when iscontrollable is here
    if S.Fear:IsAvailable() and S.Fear:IsCastable() and Target:Level() < 103 and Settings.Affliction.Sephuz.Fear then
      if AR.CastSuggested(S.Fear) then return "Cast"; end
    end
    
    -- SingeMagic 
    --TODO : add if a debuff is removable
    -- if S.SingeMagic:IsAvailable() and S.SingeMagic:IsCastable() and Settings.Affliction.Sephuz.SingeMagic then
      -- if AR.CastSuggested(S.SingeMagic) then return "Cast"; end
    -- end
    
    -- SpellLock
    if S.SpellLock:IsAvailable() and S.SpellLock:IsCastable() and Target:IsCasting() and Target:IsInterruptible() and Settings.Affliction.Sephuz.SpellLock then
      if AR.CastSuggested(S.SpellLock) then return "Cast"; end
    end
  end

  local function HauntAPL ()
    -- reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
    if S.ReapSouls:IsCastableP() and (not bool(Player:BuffRemainsP(S.DeadwindHarvester)) and AC.CombatTime() > 5 and (SoulsAvailable() >= 5 or Target:TimeToDie() <= SoulsAvailable() * (5 + 1.5 * num(I.ReapAndSow:IsEquipped())) + (Player:BuffRemainsP(S.DeadwindHarvester) * (5 + 1.5 * num(I.ReapAndSow:IsEquipped())) / 12 * (5 + 1.5 * num(I.ReapAndSow:IsEquipped()))))) then
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    -- reap_souls,if=debuff.haunt.remains&!buff.deadwind_harvester.remains
    if S.ReapSouls:IsCastableP() and (bool(Target:DebuffRemainsP(S.Haunt)) and not bool(Player:BuffRemainsP(S.DeadwindHarvester))) then
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    -- reap_souls,if=active_enemies>1&!buff.deadwind_harvester.remains&time>5&soul_shard>0&((talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|spell_targets.seed_of_corruption>=5)
    if S.ReapSouls:IsCastableP() and (Cache.EnemiesCount[range] > 1 and not bool(Player:BuffRemainsP(S.DeadwindHarvester)) and AC.CombatTime() > 5 and FutureShard() > 0 and ((S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] >= 3) or Cache.EnemiesCount[range] >= 5)) then
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    -- agony,cycle_targets=1,if=remains<=tick_time+gcd
    if S.Agony:IsCastableP() and (Target:DebuffRemainsP(S.Agony) <= S.Agony:TickTime() + Player:GCD()) then
      if AR.Cast(S.Agony) then return ""; end
    end
    -- drain_soul,cycle_targets=1,if=target.time_to_die<=gcd*2&soul_shard<5
    if S.DrainSoul:IsCastableP() and (Target:TimeToDie() <= Player:GCD() * 2 and FutureShard() < 5) then
      if AR.Cast(S.DrainSoul) then return ""; end
    end
    -- service_pet,if=dot.corruption.remains&dot.agony.remains
    if S.GrimoireFelhunter:IsAvailable() and (bool(Target:DebuffRemainsP(S.CorruptionDebuff)) and bool(Target:DebuffRemainsP(S.Agony)))and FutureShard() >= 1 then
      if AR.Cast(S.GrimoireFelhunter, Settings.Affliction.GCDasOffGCD.GrimoireFelhunter) then return ""; end
    end
    -- summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
    if S.SummonDoomGuard:IsCastableP() and (not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] <= 2 and (Target:TimeToDie() > 180 or Target:HealthPercentage() <= 20 or Target:TimeToDie() < 30)) then
      if AR.Cast(S.SummonDoomGuard) then return ""; end
    end
    -- summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
    if S.SummonInfernal:IsCastableP() and (not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] > 2) then
      if AR.Cast(S.SummonInfernal) then return ""; end
    end
    -- summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if S.SummonDoomGuard:IsCastableP() and (S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] == 1 and I.SindoreiSpite:IsEquipped() and not bool(S.SindoreiSpiteBuff:CooldownRemainsP())) then
      if AR.Cast(S.SummonDoomGuard) then return ""; end
    end
    -- summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if S.SummonInfernal:IsCastableP() and (S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] > 1 and I.SindoreiSpite:IsEquipped() and not bool(S.SindoreiSpiteBuff:CooldownRemainsP())) then
      if AR.Cast(S.SummonInfernal) then return ""; end
    end
    -- berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
    if S.Berserking:IsCastableP() and AR.CDsON() and (Player:PrevGCDP(1, S.UnstableAffliction) or Player:BuffRemainsP(S.SoulHarvest) >= 10) then
      if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and AR.CDsON() then
      if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- soul_harvest,if=buff.soul_harvest.remains<=8&buff.active_uas.stack>=1&(raid_event.adds.in>20|active_enemies>1|!raid_event.adds.exists)
    if S.SoulHarvest:IsCastableP() and (Player:BuffRemainsP(S.SoulHarvest) <= 8 and ActiveUAs() >= 1) then
      if AR.Cast(S.SoulHarvest) then return ""; end
    end
    -- potion,if=!talent.soul_harvest.enabled&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|buff.active_uas.stack>2)
    if I.PotionOfProlongedPower:IsReady() and Settings.Affliction.ShowPoPP and (not S.SoulHarvest:IsAvailable() and (Target:TimeToDie() <= 70 or ActiveUAs() > 2)) then
      if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
    end
    -- potion,if=talent.soul_harvest.enabled&buff.soul_harvest.remains&(trinket.proc.any.react|trinket.stack_proc.any.react|target.time_to_die<=70|!cooldown.haunt.remains|buff.active_uas.stack>2)
    if I.PotionOfProlongedPower:IsReady() and Settings.Affliction.ShowPoPP and (S.SoulHarvest:IsAvailable() and bool(Player:BuffRemainsP(S.SoulHarvest)) and (Target:TimeToDie() <= 70 or not bool(S.Haunt:CooldownRemainsP()) or ActiveUAs() > 2)) then
      if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
    end
    -- siphon_life,cycle_targets=1,if=remains<=tick_time+gcd
    if S.SiphonLife:IsCastableP() and (Target:DebuffRemainsP(S.SiphonLife) <= S.SiphonLife:TickTime() + Player:GCD()) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end
    -- corruption,cycle_targets=1,if=remains<=tick_time+gcd&(spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<5)
    if S.Corruption:IsCastableP() and (Target:DebuffRemainsP(S.CorruptionDebuff) <= S.CorruptionDebuff:TickTime() + Player:GCD() and (Cache.EnemiesCount[range] < 3 and S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[range] < 5)) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    -- reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
    if S.ReapSouls:IsCastableP() and ((Player:BuffRemainsP(S.DeadwindHarvester) + SoulsAvailable() * (5 + num(I.ReapAndSow:IsEquipped()))) >= (12 * (5 + 1.5 * num(I.ReapAndSow:IsEquipped())))) then
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    -- life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
    if S.LifeTap:IsCastableP() and (S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) <= Player:GCD()) then
      if AR.Cast(S.LifeTap) then return ""; end
    end
    -- phantom_singularity
    if S.PhantomSingularity:IsCastableP() then
      if AR.Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity) then return ""; end
    end
    -- haunt
    if S.Haunt:IsCastableP() and not Player:IsCasting(S.Haunt) then
      if AR.Cast(S.Haunt) then return ""; end
    end
    -- agony,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains
    if S.Agony:IsCastableP() and (Target:DebuffRemainsP(S.Agony) <= S.Agony:BaseDuration() * 0.3 and Target:TimeToDie() >= Target:DebuffRemainsP(S.Agony)) then
      if AR.Cast(S.Agony) then return ""; end
    end
    -- life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
    if S.LifeTap:IsCastableP() and (S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) < S.LifeTap:BaseDuration() * 0.3 or S.MaleficGrasp:IsAvailable() and Target:TimeToDie() > 15 and Player:ManaPercentage() < 10) then
      if AR.Cast(S.LifeTap) then return ""; end
    end
    -- siphon_life,if=remains<=duration*0.3&target.time_to_die>=remains
    if S.SiphonLife:IsCastableP() and (Target:DebuffRemainsP(S.SiphonLife) <= S.SiphonLife:BaseDuration() * 0.3 and Target:TimeToDie() >= Target:DebuffRemainsP(S.SiphonLife)) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end
    -- siphon_life,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*6&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*4
    if S.SiphonLife:IsCastableP() and (Target:DebuffRemainsP(S.SiphonLife) <= S.SiphonLife:BaseDuration() * 0.3 and Target:TimeToDie() >= Target:DebuffRemainsP(S.SiphonLife) and Target:DebuffRemainsP(S.Haunt) >= S.UnstableAffliction:TickTime() * 6 and Target:DebuffRemainsP(S.Haunt) >= S.UnstableAffliction:TickTime() * 4) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end
    -- seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3|spell_targets.seed_of_corruption>=5|spell_targets.seed_of_corruption>=3&dot.corruption.remains<=cast_time+travel_time
    if S.SeedOfCorruption:IsCastableP() and (S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] >= 3 or Cache.EnemiesCount[range] >= 5 or Cache.EnemiesCount[range] >= 3 and Target:DebuffRemainsP(S.CorruptionDebuff) <= S.SeedOfCorruption:CastTime() + S.SeedOfCorruption:TravelTime()) then
      if AR.Cast(S.SeedOfCorruption) then return ""; end
    end
    -- corruption,if=remains<=duration*0.3&target.time_to_die>=remains
    if S.Corruption:IsCastableP() and (Target:DebuffRemainsP(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() * 0.3 and Target:TimeToDie() >= Target:DebuffRemainsP(S.CorruptionDebuff)) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    -- corruption,cycle_targets=1,if=remains<=duration*0.3&target.time_to_die>=remains&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*6&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*4
    if S.Corruption:IsCastableP() and (Target:DebuffRemainsP(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() * 0.3 and Target:TimeToDie() >= Target:DebuffRemainsP(S.CorruptionDebuff) and Target:DebuffRemainsP(S.Haunt) >= S.UnstableAffliction:TickTime() * 6 and Target:DebuffRemainsP(S.Haunt) >= S.UnstableAffliction:TickTime() * 4) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    -- unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&((soul_shard>=4&!talent.contagion.enabled)|soul_shard>=5|target.time_to_die<30)
    if S.UnstableAffliction:IsCastableP() and FutureShard() > 1 and ((not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[range] < 3) and Cache.EnemiesCount[range] < 5 and ((FutureShard() >= 4 and not S.Contagion:IsAvailable()) or FutureShard() >= 5 or Target:TimeToDie() < 30)) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- unstable_affliction,cycle_targets=1,if=active_enemies>1&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&soul_shard>=4&talent.contagion.enabled&cooldown.haunt.remains<15&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if S.UnstableAffliction:IsCastableP() and FutureShard() > 1 and (Cache.EnemiesCount[range] > 1 and (not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[range] < 3) and FutureShard() >= 4 and S.Contagion:IsAvailable() and S.Haunt:CooldownRemainsP() < 15 and CheckUnstableAffliction ()) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- unstable_affliction,cycle_targets=1,if=active_enemies>1&(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&(equipped.132381|equipped.132457)&cooldown.haunt.remains<15&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if S.UnstableAffliction:IsCastableP() and FutureShard() > 1 and (Cache.EnemiesCount[range] > 1 and (not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[range] < 3) and (I.StretensSleeplessShackles:IsEquipped() or I.PowerCordofLethtendris:IsEquipped()) and S.Haunt:CooldownRemainsP() < 15 and CheckUnstableAffliction ()) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&talent.contagion.enabled&soul_shard>=4&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if S.UnstableAffliction:IsCastableP() and FutureShard() > 1 and ((not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[range] < 3) and Cache.EnemiesCount[range] < 5 and S.Contagion:IsAvailable() and FutureShard() >= 4 and CheckUnstableAffliction ()) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- unstable_affliction,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&debuff.haunt.remains>=action.unstable_affliction_1.tick_time*2
    if S.UnstableAffliction:IsCastableP() and FutureShard() > 1 and ((not S.SowTheSeeds:IsAvailable() or Cache.EnemiesCount[range] < 3) and Cache.EnemiesCount[range] < 5 and Target:DebuffRemainsP(S.Haunt) >= S.UnstableAffliction:TickTime() * 2) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- reap_souls,if=!buff.deadwind_harvester.remains&(buff.active_uas.stack>1|(prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1))
    if S.ReapSouls:IsCastableP() and (not bool(Player:BuffRemainsP(S.DeadwindHarvester)) and (ActiveUAs() > 1 or (Player:PrevGCDP(1, S.UnstableAffliction) and SoulsAvailable() > 1))) then
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    -- life_tap,if=mana.pct<=10
    if S.LifeTap:IsCastableP() and (Player:ManaPercentage() <= 10) then
      if AR.Cast(S.LifeTap) then return ""; end
    end
    -- life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
    if S.LifeTap:IsCastableP() and (Player:PrevGCDP(1, S.LifeTap) and ActiveUAs() == 0 and Player:ManaPercentage() < 50) then
      if AR.Cast(S.LifeTap) then return ""; end
    end
    -- drain_soul,chain=1,interrupt=1
    if S.DrainSoul:IsCastableP() then
      if AR.Cast(S.DrainSoul) then return ""; end
    end
    -- life_tap,moving=1,if=mana.pct<80
    if S.LifeTap:IsCastableP() and (Player:ManaPercentage() < 80) then
      if AR.Cast(S.LifeTap) then return ""; end
    end
    -- agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if S.Agony:IsCastableP() and (Target:DebuffRemainsP(S.Agony) <= S.Agony:BaseDuration() - (3 * S.Agony:TickTime())) then
      if AR.Cast(S.Agony) then return ""; end
    end
    -- siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if S.SiphonLife:IsCastableP() and (Target:DebuffRemainsP(S.SiphonLife) <= S.SiphonLife:BaseDuration() - (3 * S.SiphonLife:TickTime())) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end
    -- corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if S.Corruption:IsCastableP() and (Target:DebuffRemainsP(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() - (3 * S.CorruptionDebuff:TickTime())) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    -- life_tap,moving=0
    if S.LifeTap:IsCastableP() then
      if AR.Cast(S.LifeTap) then return ""; end
    end
  end
  
  local function WritheAPL ()
    -- actions.writhe  =reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
    -- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.soul_harvest.remains>=(5+1.5*equipped.144364)&buff.active_uas.stack>1|buff.concordance_of_the_legionfall.react|trinket.proc.intellect.react|trinket.stacking_proc.intellect.react|trinket.proc.mastery.react|trinket.stacking_proc.mastery.react|trinket.proc.crit.react|trinket.stacking_proc.crit.react|trinket.proc.versatility.react|trinket.stacking_proc.versatility.react|trinket.proc.spell_power.react|trinket.stacking_proc.spell_power.react)
    if S.ReapSouls:IsCastableP() and Player:BuffRemainsP(S.DeadwindHarvester) > 0 and AC.CombatTime() > 5 and SoulsAvailable() >= 1
      and ((SoulsAvailable() >= 5 or Target:FilteredTimeToDie("<=", ComputeDeadwindHarvesterDuration()))
      or ((Player:BuffRemainsP(S.SoulHarvest) >= StackDurationCompute and ActiveUAs() > 1) or Player:BuffRemainsP(S.Concordance) > 0)) then
        if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    
    -- actions.writhe+=/agony,if=remains<=tick_time+gcd
    if Target:DebuffRemainsP(S.Agony) <= (Player:GCD() + S.Agony:TickTime()) and Player:ManaP() >= S.Agony:Cost() then
      if AR.Cast(S.Agony) then return ""; end
    end
    
    -- actions.writhe+=/agony,cycle_targets=1,max_cycle_targets=5,target_if=sim.target!=target&talent.soul_harvest.enabled&cooldown.soul_harvest.remains<cast_time*6&remains<=duration*0.3&target.time_to_die>=remains&time_to_die>tick_time*3
    -- actions.writhe+=/agony,cycle_targets=1,max_cycle_targets=3,target_if=sim.target!=target&remains<=tick_time+gcd&time_to_die>tick_time*3
    if Target:DebuffRemainsP(S.Agony) <= (Player:GCD() + S.Agony:TickTime()) and Player:ManaP() >= S.Agony:Cost() then
      if AR.Cast(S.Agony) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Agony:Cost() and ((S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemains() < Player:GCD() * 6 and NbAffected(S.Agony) <= 5) or NbAffected(S.Agony) <= 3) then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.Agony:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRefreshableCP(S.Agony) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Agony)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3&soul_shard=5
    if S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] >= 3 and FutureShard() == 5 then
      if AR.Cast(S.SeedOfCorruption) then return ""; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=soul_shard=5|(time_to_die<=((duration+cast_time)*soul_shard))
    if FutureShard() == 5 or Target:FilteredTimeToDie("<=", (S.UnstableAffliction:CastTime() + S.UnstableAffliction:TickTime()) * FutureShard()) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.writhe+=/drain_soul,cycle_targets=1,if=target.time_to_die<=gcd*2&soul_shard<5
    if FutureShard() < 5 and Player:ManaP() >= S.DrainSoul:Cost() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 0, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:FilteredTimeToDie(">", BestUnitTTD) and Value:FilteredTimeToDie("<=", Player:GCD() * 2) and not Value:IsUnit(Target) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.DrainSoul;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    if AR.CDsON() then
      -- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
      if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
        if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
      end
      
      -- actions.writhe+=/service_pet,if=dot.corruption.remains&dot.agony.remains
      if S.GrimoireFelhunter:IsAvailable() and S.GrimoireFelhunter:IsCastable() and FutureShard() >= 1 and Target:DebuffRemainsP(S.Agony) > 0 and Target:DebuffRemainsP(S.CorruptionDebuff) > 0 then
        if AR.Cast(S.GrimoireFelhunter, Settings.Affliction.GCDasOffGCD.GrimoireFelhunter) then return ""; end
      end
      
      -- actions.writhe+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
      if S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0 and FutureShard() >= 1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] <= 2 
        and (Target:FilteredTimeToDie(">", 180) or Target:HealthPercentage() <= 20 or Target:FilteredTimeToDie("<", 30)) then
          if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
      end
      
      -- actions.writhe+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
       if S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemainsP() == 0 and FutureShard() >= 1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] > 2 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
      end
      
      -- actions.writhe+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
      if S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0 and FutureShard() >= 1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] == 1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
      end
      
      -- actions.writhe+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
      if S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemainsP() == 0 and FutureShard() >= 1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] > 1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
      end

      -- actions.writhe+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
      if S.Berserking:IsAvailable() and S.Berserking:CooldownRemainsP() == 0 and (ActiveUAs() or Player:BuffRemainsP(S.SoulHarvest) >= 10)  then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
      end
      
      -- actions.writhe+=/blood_fury
      if S.BloodFury:IsAvailable() and S.BloodFury:CooldownRemainsP() == 0 then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
      end
      
      -- actions.writhe+=/soul_harvest,if=sim.target=target&buff.soul_harvest.remains<=8&(raid_event.adds.in>20|active_enemies>1|!raid_event.adds.exists)&(buff.active_uas.stack>=2|active_enemies>3)&(!talent.deaths_embrace.enabled|time_to_die>120|time_to_die<30)
      if S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemainsP() == 0 and Player:BuffRemains(S.SoulHarvest) <= 8 and (ActiveUAs() >= 2 or Cache.EnemiesCount[range] > 3) 
        and (not S.DeathsEmbrace:IsAvailable() or Target:FilteredTimeToDie(">", 120) or Target:FilteredTimeToDie("<=", 30)) then
          if AR.Cast(S.SoulHarvest, Settings.Affliction.OffGCDasOffGCD.SoulHarvest) then return ""; end
      end
      
      -- actions.writhe+=/use_item,slot=trinket1
      -- actions.writhe+=/use_item,slot=trinket2
      -- actions.writhe+=/potion,if=target.time_to_die<=70
      -- actions.writhe+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&(trinket.proc.any.react|trinket.stack_proc.any.react|buff.active_uas.stack>=2)
      if Settings.Affliction.ShowPoPP and I.PotionOfProlongedPower:IsReady() and (((not S.SoulHarvest:IsAvailable() or Player:BuffRemainsP(S.SoulHarvest) > 12) and ActiveUAs() >= 2) or Target:FilteredTimeToDie("<=", 60)) then
        if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
      end
    end
    
    -- actions.writhe+=/siphon_life,cycle_targets=1,if=remains<=tick_time+gcd&time_to_die>tick_time*2
    if S.SiphonLife:IsAvailable() and Target:DebuffRemainsP(S.SiphonLife) <= (S.SiphonLife:TickTime() + Player:GCD()) and Target:FilteredTimeToDie(">", S.SiphonLife:TickTime() * 2) then
        if AR.Cast(S.SiphonLife) then return ""; end
    end
    if AR.AoEON() and S.SiphonLife:IsAvailable() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.SiphonLife:TickTime() * 2, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRemainsP(S.SiphonLife) <= (S.SiphonLife:TickTime() + Player:GCD()) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.SiphonLife)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/corruption,cycle_targets=1,if=remains<=tick_time+gcd&((spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled)|spell_targets.seed_of_corruption<5)&time_to_die>tick_time*2
    if Player:ManaP() >= S.Corruption:Cost() and (not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemainsP(S.CorruptionDebuff)<=(Player:GCD() + S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff))
      and ((S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] < 3) or Cache.EnemiesCount[range] < 5) and Target:FilteredTimeToDie(">", S.CorruptionDebuff:TickTime() * 2) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Corruption:Cost() and ((S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] < 3) or Cache.EnemiesCount[range] < 5) then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.CorruptionDebuff:TickTime() * 2, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((not S.AbsoluteCorruption:IsAvailable() and Value:DebuffRemainsP(S.CorruptionDebuff)<=(Player:GCD() + S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Value:Debuff(S.CorruptionDebuff))) 
          and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.CorruptionDebuff)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/life_tap,if=mana.pct<40&(buff.active_uas.stack<1|!buff.deadwind_harvester.remains)
    -- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3&(!buff.deadwind_harvester.remains|buff.active_uas.stack<1)
    -- actions.writhe+=/life_tap,if=mana.pct<=10
    -- actions.writhe+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
    -- actions.writhe+=/life_tap,moving=1,if=mana.pct<80
    if S.LifeTap:IsCastable() and (Player:ManaPercentage() < 40 and (ActiveUAs() < 1 or Player:BuffRemainsP(S.DeadwindHarvester) == 0)
      or (S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) and (Player:BuffRemainsP(S.DeadwindHarvester) == 0 or ActiveUAs() < 1))
      or Player:ManaPercentage() < 10
      or (ActiveUAs() == 0 and Player:PrevGCDP(1, S.LifeTap) and Player:ManaPercentage() < 50)
      or (Player:IsMoving() and Player:ManaPercentage() < 80)) then
        if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
    end

    -- actions.writhe+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
    if S.ReapSouls:IsCastableP() and SoulsAvailable() >= 1 and (Player:BuffRemainsP(S.DeadwindHarvester) + SoulsAvailable() * StackDurationCompute) >= (12 * StackDurationCompute) then 
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    
    -- actions.writhe+=/phantom_singularity
    if S.PhantomSingularity:IsAvailable() and S.PhantomSingularity:CooldownRemainsP() == 0  then
        if AR.Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity) then return ""; end
    end
    
    -- actions.writhe+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>3&dot.corruption.refreshable)
    if FutureShard() >= 1 and ((S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] >= 3) or (Cache.EnemiesCount[range] > 3 
      and ((not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRefreshableCP(S.CorruptionDebuff)) or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff))))) then
      if AR.Cast(S.SeedOfCorruption) then return ""; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=talent.contagion.enabled&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if FutureShard() >= 1 and S.Contagion:IsAvailable() and CheckUnstableAffliction() then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=talent.absolute_corruption.enabled&set_bonus.tier21_4pc&debuff.tormented_agony.remains<=cast_time
    if FutureShard() >= 1 and S.AbsoluteCorruption:IsAvailable() and T214P and Target:DebuffRemainsP(S.TormentedAgony) <= S.UnstableAffliction:CastTime() then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.writhe+=/unstable_affliction,cycle_targets=1,target_if=buff.deadwind_harvester.remains>=duration+cast_time&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
    if FutureShard() >= 1 and Player:BuffRemainsP(S.DeadwindHarvester) > S.UnstableAffliction:BaseDuration() + S.UnstableAffliction:CastTime() and CheckUnstableAffliction() then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.writhe+=/unstable_affliction,if=buff.deadwind_harvester.remains>tick_time*2&(!set_bonus.tier21_4pc|talent.contagion.enabled|soul_shard>1)&(!talent.contagion.enabled|soul_shard>1|buff.soul_harvest.remains)&(dot.unstable_affliction_1.ticking+dot.unstable_affliction_2.ticking+dot.unstable_affliction_3.ticking+dot.unstable_affliction_4.ticking+dot.unstable_affliction_5.ticking<5)
    if FutureShard() >= 1 and Player:BuffRemainsP(S.DeadwindHarvester) > S.UnstableAffliction:TickTime() * 2 and (not T214P or S.Contagion:IsAvailable() or FutureShard() > 1) and (not S.Contagion:IsAvailable() or FutureShard() > 1 or Player:BuffRemainsP(S.SoulHarvest) > S.UnstableAffliction:CastTime()) and ActiveUAs() < 5 then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&buff.active_uas.stack>1
    if S.ReapSouls:IsCastableP() and Player:BuffRemainsP(S.DeadwindHarvester) == 0 and ActiveUAs() > 1 and SoulsAvailable() >= 1 then 
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    
    -- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1
    if S.ReapSouls:IsCastableP() and Player:BuffRemainsP(S.DeadwindHarvester) == 0 and Player:PrevGCDP(1, S.UnstableAffliction) and SoulsAvailable() >= 1 then 
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end

    -- actions.writhe+=/agony,if=refreshable&time_to_die>=remains
    if Target:DebuffRefreshableCP(S.Agony) and Player:ManaP() >= S.Agony:Cost() and Target:FilteredTimeToDie(">=", Target:DebuffRemainsP(S.Agony)) then
      if AR.Cast(S.Agony) then return ""; end
    end
    
    -- actions.writhe+=/siphon_life,if=refreshable&time_to_die>=remains
    if S.SiphonLife:IsAvailable() and Target:DebuffRefreshableCP(S.SiphonLife) and Target:FilteredTimeToDie(">=", Target:DebuffRemainsP(S.SiphonLife)) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end

    -- actions.writhe+=/corruption,if=refreshable&time_to_die>=remains
    if Player:ManaP() >= S.Corruption:Cost() and ((not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRefreshableCP(S.CorruptionDebuff)) or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff))) and Target:FilteredTimeToDie(">=", Target:DebuffRemainsP(S.Agony)) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    
    -- actions.writhe+=/agony,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
    if AR.AoEON() and Player:BuffRemainsP(S.DeadwindHarvester) == 0 and Player:ManaP() >= S.Agony:Cost() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.Agony:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRefreshableCP(S.Agony) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Agony)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/siphon_life,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
    if AR.AoEON() and S.SiphonLife:IsAvailable() and Player:BuffRemainsP(S.DeadwindHarvester) == 0 then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.SiphonLife:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRefreshableCP(S.SiphonLife) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.SiphonLife))then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/corruption,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable&time_to_die>tick_time*3
    if AR.AoEON() and Player:ManaP() >= S.Corruption:Cost() and Player:BuffRemainsP(S.DeadwindHarvester) == 0 then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.CorruptionDebuff:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((not S.AbsoluteCorruption:IsAvailable() and Value:DebuffRefreshableCP(S.CorruptionDebuff)) or (S.AbsoluteCorruption:IsAvailable() and not Value:Debuff(S.CorruptionDebuff))) and Value:FilteredTimeToDie(">=", Value:DebuffRemainsP(S.CorruptionDebuff)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/drain_soul,chain=1,interrupt=1
    if S.DrainSoul:IsCastable() and Player:ManaP() >= S.DrainSoul:Cost() then
      if AR.Cast(S.DrainSoul) then return ""; end
    end

    -- actions.writhe+=/agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if Player:IsMoving() and Player:ManaP() >= S.Agony:Cost() and Target:DebuffRemainsP(S.Agony) <= S.Agony:BaseDuration() - (3 * S.Agony:TickTime()) then
      if AR.Cast(S.Agony) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Agony:Cost() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.Agony:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Player:IsMoving() and Value:DebuffRemainsP(S.Agony) <= S.Agony:BaseDuration() - (3 * S.Agony:TickTime()) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Agony)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if S.SiphonLife:IsAvailable() and Player:IsMoving() and Target:DebuffRemains(S.SiphonLife) <= S.SiphonLife:BaseDuration() - (3 * S.SiphonLife:TickTime()) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end
    if AR.AoEON() and S.SiphonLife:IsAvailable() and Player:IsMoving() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.SiphonLife:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRemains(S.SiphonLife) <= S.SiphonLife:BaseDuration() - (3 * S.SiphonLife:TickTime()) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.SiphonLife)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    -- actions.writhe+=/corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
    if Player:IsMoving() and Player:ManaP() >= S.Corruption:Cost() and ((not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() - (3 * S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff))) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Corruption:Cost() and Player:IsMoving() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.CorruptionDebuff:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((not S.AbsoluteCorruption:IsAvailable() and Value:DebuffRemains(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() - (3 * S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Value:Debuff(S.CorruptionDebuff))) and Value:FilteredTimeToDie(">=", Value:DebuffRemainsP(S.CorruptionDebuff)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.writhe+=/life_tap,moving=0
    if S.LifeTap:IsCastable() then
      if AR.Cast(S.LifeTap) then return ""; end
    end
  end
  
  local function MGAPL ()
    --keep spamming drain soul if ua
    if Player:IsChanneling(S.DrainSoul) and ActiveUAs() > 0 then
      if AR.Cast(S.DrainSoul) then return ""; end
    end
  
    -- actions.mg=reap_souls,if=!buff.deadwind_harvester.remains&time>5&((buff.tormented_souls.react>=4+active_enemies|buff.tormented_souls.react>=9)|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
    if S.ReapSouls:IsCastableP() and not Player:BuffRemainsP(S.DeadwindHarvester) == 0 and AC.CombatTime() > 5 and SoulsAvailable() >= 1
      and ((SoulsAvailable() >= 4 + Cache.EnemiesCount[range] or SoulsAvailable() >= 9) or Target:FilteredTimeToDie("<=", ComputeDeadwindHarvesterDuration())) then
        if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end
    
    -- actions.mg+=/agony,cycle_targets=1,max_cycle_targets=5,target_if=sim.target!=target&talent.soul_harvest.enabled&cooldown.soul_harvest.remains<cast_time*6&remains<=duration*0.3&target.time_to_die>=remains&time_to_die>tick_time*3
    -- actions.mg+=/agony,cycle_targets=1,max_cycle_targets=4,if=remains<=(tick_time+gcd)
    if Target:DebuffRemainsP(S.Agony) <= (Player:GCD() + S.Agony:TickTime()) and Player:ManaP() >= S.Agony:Cost()  then
      if AR.Cast(S.Agony) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Agony:Cost() and ((S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemains() < Player:GCD() * 6 and NbAffected(S.Agony) <= 5) or NbAffected(S.Agony) <= 4) then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.Agony:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRefreshableCP(S.Agony) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Agony)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3&soul_shard=5
    if S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] >= 3 and FutureShard() == 5 then
      if AR.Cast(S.SeedOfCorruption) then return ""; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&soul_shard=5
    if FutureShard() == 5 then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.mg+=/drain_soul,cycle_targets=1,if=target.time_to_die<gcd*2&soul_shard<5
    if FutureShard() < 5 and Player:ManaP() >= S.DrainSoul:Cost() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 0, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:FilteredTimeToDie(">", BestUnitTTD) and Value:FilteredTimeToDie("<=", Player:GCD() * 2) and not Value:IsUnit(Target) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.DrainSoul;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    if AR.CDsON() then
      -- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
      if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
        if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
      end
      
      -- actions.mg+=/service_pet,if=dot.corruption.remains&dot.agony.remains
      if S.GrimoireFelhunter:IsAvailable() and S.GrimoireFelhunter:IsCastable() and FutureShard() >= 1 and Target:DebuffRemainsP(S.Agony) > 0 and Target:DebuffRemainsP(S.CorruptionDebuff) > 0 then
        if AR.Cast(S.GrimoireFelhunter, Settings.Affliction.GCDasOffGCD.GrimoireFelhunter) then return ""; end
      end
      
      -- actions.mg+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
      if S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0 and FutureShard() >= 1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] <= 2 
        and (Target:FilteredTimeToDie(">", 180) or Target:HealthPercentage() <= 20 or Target:FilteredTimeToDie("<", 30)) then
          if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
      end
      
      -- actions.mg+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>2
      if S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemainsP() == 0 and FutureShard() >= 1 and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] > 2 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
      end
      
      -- actions.mg+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
      if S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0 and FutureShard() >= 1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] == 1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
      end
      
      -- actions.mg+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
      if S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemainsP() == 0 and FutureShard() >= 1 and S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] > 1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
        if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
      end
      
      -- actions.mg+=/berserking,if=prev_gcd.1.unstable_affliction|buff.soul_harvest.remains>=10
      if S.Berserking:IsAvailable() and S.Berserking:CooldownRemainsP() == 0 and (ActiveUAs() or Player:BuffRemainsP(S.SoulHarvest) >= 10)  then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
      end
      
      -- actions.mg+=/blood_fury
      if S.BloodFury:IsAvailable() and S.BloodFury:CooldownRemainsP() == 0 then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
      end
      
      -- actions.mg+=/soul_harvest,if=buff.active_uas.stack>1&buff.soul_harvest.remains<=8&sim.target=target&(!talent.deaths_embrace.enabled|target.time_to_die>=136|target.time_to_die<=40)
      if S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemainsP() == 0 and ActiveUAs() > 1 and Player:BuffRemainsP(S.SoulHarvest) <= 8 
        and (not S.DeathsEmbrace:IsAvailable() or Target:FilteredTimeToDie(">", 136) or Target:FilteredTimeToDie("<=", 40)) then
          if AR.Cast(S.SoulHarvest, Settings.Affliction.OffGCDasOffGCD.SoulHarvest) then return ""; end
      end
      
      -- actions.mg+=/use_item,slot=trinket1
      -- actions.mg+=/use_item,slot=trinket2
      -- actions.mg+=/potion,if=target.time_to_die<=70
      -- actions.mg+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&buff.active_uas.stack>=2
      if Settings.Affliction.ShowPoPP and I.PotionOfProlongedPower:IsReady() and (((not S.SoulHarvest:IsAvailable() or Player:BuffRemainsP(S.SoulHarvest) > 12) and ActiveUAs() >= 2) or Target:FilteredTimeToDie("<=", 60)) then
        if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
      end
    end
    
    -- actions.mg+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3|talent.malefic_grasp.enabled&target.time_to_die>15&mana.pct<10
    -- actions.mg+=/life_tap,if=mana.pct<=10
    -- actions.mg+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
    -- actions.mg+=/life_tap,moving=1,if=mana.pct<80
    if S.LifeTap:IsCastable() and (Player:ManaPercentage() < 10 
      or (ActiveUAs() == 0 and Player:PrevGCDP(1, S.LifeTap) and Player:ManaPercentage() < 50)
      or (Player:IsMoving() and Player:ManaPercentage() < 80)) then
        if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
    end
    
    -- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=(tick_time+gcd)&target.time_to_die>tick_time*3
    if S.SiphonLife:IsAvailable() and Target:DebuffRemainsP(S.SiphonLife) <= (S.SiphonLife:TickTime() + Player:GCD()) and Target:FilteredTimeToDie(">", S.SiphonLife:TickTime() * 3) then
        if AR.Cast(S.SiphonLife) then return ""; end
    end
    if AR.AoEON() and S.SiphonLife:IsAvailable() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.SiphonLife:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRemainsP(S.SiphonLife) <= (S.SiphonLife:TickTime() + Player:GCD()) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.SiphonLife)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/corruption,cycle_targets=1,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&remains<=(tick_time+gcd)&target.time_to_die>tick_time*3
    if Player:ManaP() >= S.Corruption:Cost() and (not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemainsP(S.CorruptionDebuff) <= (Player:GCD() + S.CorruptionDebuff:TickTime())) 
      or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff)) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Corruption:Cost() and ((Cache.EnemiesCount[range]<3 and S.SowTheSeeds:IsAvailable()) or Cache.EnemiesCount[range]<5)then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.CorruptionDebuff:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((not S.AbsoluteCorruption:IsAvailable() and Value:DebuffRemainsP(S.CorruptionDebuff) <= (Player:GCD() + S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Value:Debuff(S.CorruptionDebuff))) 
          and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.CorruptionDebuff)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/phantom_singularity
    if S.PhantomSingularity:IsAvailable() and S.PhantomSingularity:IsCastable()  then
        if AR.Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity) then return ""; end
    end
    
    -- actions.mg+=/agony,cycle_targets=1,if=remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.agony)
    if Target:DebuffRefreshableCP(S.Agony) and Player:ManaP() >= S.Agony:Cost() and Target:FilteredTimeToDie(">=", Target:DebuffRemainsP(S.Agony)) and (ActiveUAs() == 0 or Player:PrevGCDP(1,S.Agony)) then
      if AR.Cast(S.Agony) then return ""; end
    end
    if AR.AoEON() and ActiveUAs() == 0 and Player:ManaP() >= S.Agony:Cost() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.Agony:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRefreshableCP(S.Agony) and Value:FilteredTimeToDie(">=", Value:DebuffRemainsP(S.Agony)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Agony)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/siphon_life,cycle_targets=1,if=remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.siphon_life)
    if S.SiphonLife:IsAvailable() and Target:DebuffRefreshableCP(S.SiphonLife) and  Target:FilteredTimeToDie(">=", Target:DebuffRemainsP(S.SiphonLife)) and (ActiveUAs() == 0 or Player:PrevGCDP(1, S.SiphonLife)) then
        if AR.Cast(S.SiphonLife) then return ""; end
    end
    if AR.AoEON() and S.SiphonLife:IsAvailable() and ActiveUAs() == 0  then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.SiphonLife:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRefreshableCP(S.SiphonLife) and Value:FilteredTimeToDie(">=", Value:DebuffRemainsP(S.SiphonLife)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.SiphonLife)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/corruption,cycle_targets=1,if=(!talent.sow_the_seeds.enabled|spell_targets.seed_of_corruption<3)&spell_targets.seed_of_corruption<5&remains<=(duration*0.3)&target.time_to_die>=remains&(buff.active_uas.stack=0|prev_gcd.1.corruption)
    if Player:ManaP() >= S.Corruption:Cost() and ((not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRefreshableCP(S.CorruptionDebuff)) 
      or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff))) and (ActiveUAs() == 0 or Player:PrevGCDP(1, S.Corruption)) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Corruption:Cost() and ((Cache.EnemiesCount[range] < 3 and S.SowTheSeeds:IsAvailable()) or Cache.EnemiesCount[range] < 5) and ActiveUAs() == 0 then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.CorruptionDebuff:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((not S.AbsoluteCorruption:IsAvailable() and Value:DebuffRefreshableCP(S.CorruptionDebuff)) or (S.AbsoluteCorruption:IsAvailable() and not Value:Debuff(S.CorruptionDebuff))) 
          and Value:FilteredTimeToDie(">=", Value:DebuffRemainsP(S.CorruptionDebuff)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.CorruptionDebuff)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>=5&dot.corruption.remains<=cast_time+travel_time)
    if (S.SowTheSeeds:IsAvailable() and Cache.EnemiesCount[range] >= 3) or (Cache.EnemiesCount[range] >= 5 and Target:DebuffRemainsP(S.CorruptionDebuff) <= S.SeedOfCorruption:CastTime() + S.SeedOfCorruption:TravelTime()) then
      if AR.Cast(S.SeedOfCorruption) then return ""; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&target.time_to_die<30
    if FutureShard() >= 1 and Target:FilteredTimeToDie("<", 30) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&active_enemies>1&soul_shard>=4
    if FutureShard() >= 4 and Cache.EnemiesCount[range] > 1 then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.mg+=/unstable_affliction,if=target=sim.target&(buff.active_uas.stack=0|(!prev_gcd.3.unstable_affliction&prev_gcd.1.unstable_affliction))&dot.agony.remains>cast_time+(6.5*spell_haste)
    if FutureShard() >= 1 and (ActiveUAs() == 0 or (not Player:PrevGCDP(3, S.UnstableAffliction) and Player:PrevGCDP(1, S.UnstableAffliction))) 
      and (Target:DebuffRemainsP(S.Agony) > S.UnstableAffliction:CastTime() + (6.5 * Player:SpellHaste())) then
      if AR.Cast(S.UnstableAffliction) then return ""; end
    end
    
    -- actions.mg+=/reap_souls,if=buff.deadwind_harvester.remains<dot.unstable_affliction_1.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_2.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_3.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_4.remains|buff.deadwind_harvester.remains<dot.unstable_affliction_5.remains&buff.active_uas.stack>1
    if S.ReapSouls:IsCastableP() and CheckDeadwindHarvester() and ActiveUAs() > 1 and SoulsAvailable() >= 1 then 
      if AR.Cast(S.ReapSouls, Settings.Affliction.GCDasOffGCD.ReapSoul) then return ""; end
    end

    -- actions.mg+=/drain_soul,chain=1,interrupt=1
    if S.DrainSoul:IsCastable() and Player:ManaP() >= S.DrainSoul:Cost() then
      if AR.Cast(S.DrainSoul) then return ""; end
    end
    
    -- actions.mg+=/agony,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
    if Player:IsMoving() and Player:ManaP() >= S.Agony:Cost() and Target:DebuffRemainsP(S.Agony) <= S.Agony:BaseDuration() - (3 * S.Agony:TickTime()) then
      if AR.Cast(S.Agony) then return ""; end
    end
    if AR.AoEON() and Player:IsMoving() and Player:ManaP() >= S.Agony:Cost() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.Agony:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRemainsP(S.Agony) <= S.Agony:BaseDuration() - (3 * S.Agony:TickTime()) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Agony)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Agony;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/siphon_life,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
    if S.SiphonLife:IsAvailable() and Player:IsMoving() and Target:DebuffRemains(S.SiphonLife) <= S.SiphonLife:BaseDuration() - (3 * S.SiphonLife:TickTime()) then
      if AR.Cast(S.SiphonLife) then return ""; end
    end
    if AR.AoEON() and S.SiphonLife:IsAvailable() and Player:IsMoving()then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.SiphonLife:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:DebuffRemains(S.SiphonLife) <= S.SiphonLife:BaseDuration() - (3 * S.SiphonLife:TickTime()) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.SiphonLife)) then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.SiphonLife;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/corruption,moving=1,cycle_targets=1,if=remains<duration-(3*tick_time)
    if Player:ManaP() >= S.Corruption:Cost() and Player:IsMoving() and ((not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemainsP(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() - (3 * S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Target:Debuff(S.CorruptionDebuff))) then
      if AR.Cast(S.Corruption) then return ""; end
    end
    if AR.AoEON() and Player:ManaP() >= S.Corruption:Cost() and Player:IsMoving() then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.CorruptionDebuff:TickTime() * 3, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if ((not S.AbsoluteCorruption:IsAvailable() and Value:DebuffRemains(S.CorruptionDebuff) <= S.CorruptionDebuff:BaseDuration() - (3 * S.CorruptionDebuff:TickTime())) or (S.AbsoluteCorruption:IsAvailable() and not Value:Debuff(S.CorruptionDebuff))) 
          and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.CorruptionDebuff)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Corruption;
        end
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
    
    -- actions.mg+=/life_tap,moving=0
    if S.LifeTap:IsCastable() then
      if AR.Cast(S.LifeTap) then return ""; end
    end
  end

--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(range);
    if I.SephuzSecret:IsEquipped() then
      AC.GetEnemies(10);
    end
    Everyone.AoEToggleEnemiesUpdate();
    
    -- TODO : Mvt and range rotation change
    -- TODO : add the possibility to choose a pet
    -- TODO : Sephuz - SingMagic : add if a debuff is removable
    -- TODO : Add prepot
    
    -- Defensives
    if S.UnendingResolve:IsCastable() and Player:HealthPercentage() <= Settings.Affliction.UnendingResolveHP then
      if AR.Cast(S.UnendingResolve, Settings.Affliction.OffGCDasOffGCD.UnendingResolve) then return ""; end
    end
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    -- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonFelhunter:IsCastable() and (Warlock.PetReminder() and (not IsPetInvoked() or not S.SpellLock:IsLearned()) or not IsPetInvoked()) and not S.GrimoireOfSupremacy:IsAvailable() and (not S.GrimoireOfSacrifice:IsAvailable() or Player:BuffRemains(S.DemonicPower) < 600) and Player:SoulShards () >= 1 and not Player:IsCasting(S.SummonFelhunter) then
      if AR.Cast(S.SummonFelhunter, Settings.Affliction.GCDasOffGCD.SummonFelhunter) then return ""; end
    end
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireOfSacrifice:IsCastable() and Player:BuffRemains(S.DemonicPower) < 600  and (IsPetInvoked() or Player:IsCasting(S.SummonFelhunter)) then
      if AR.Cast(S.GrimoireOfSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return ""; end
    end
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:IsCastable() and (Warlock.PetReminder() and (not IsPetInvoked(true) or not S.MeteorStrike:IsLearned()) or not IsPetInvoked(true)) and Cache.EnemiesCount[range] > 1 and Player:SoulShards () >= 1 then
      if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:IsCastable() and (Warlock.PetReminder() and (not IsPetInvoked(true) or not S.ShadowLock:IsLearned()) or not IsPetInvoked(true)) and Cache.EnemiesCount[range] == 1 and Player:SoulShards () >= 1 then
      if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end

    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      
      -- actions.precombat+=/potion,name=prolonged_power
      -- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
      if AR.CDsON() and S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
        if AR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
      end
      
      -- Opener
      if Everyone.TargetIsValid() then
          if AR.Cast(S.Agony) then return ""; end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- Sephuz usage
      if I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 then
        ShouldReturn = Sephuz();
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
      if S.Haunt:IsAvailable() then
        ShouldReturn = HauntAPL();
        if ShouldReturn then return ShouldReturn; end
      end
        
    end
  end

  AR.SetAPL(265, APL);


--- ======= SIMC =======
--- Last Update: 01/03/2018

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
-- actions=call_action_list,name=mg,if=talent.malefic_grasp.enabled
-- actions+=/call_action_list,name=writhe,if=talent.writhe_in_agony.enabled
-- actions+=/call_action_list,name=haunt,if=talent.haunt.enabled

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
-- actions.haunt+=/soul_harvest,if=buff.soul_harvest.remains<=8&buff.active_uas.stack>=1&(raid_event.adds.in>20|active_enemies>1|!raid_event.adds.exists)
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

-- actions.writhe=reap_souls,if=!buff.deadwind_harvester.remains&time>5&(buff.tormented_souls.react>=5|target.time_to_die<=buff.tormented_souls.react*(5+1.5*equipped.144364)+(buff.deadwind_harvester.remains*(5+1.5*equipped.144364)%12*(5+1.5*equipped.144364)))
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
-- actions.writhe+=/soul_harvest,if=sim.target=target&buff.soul_harvest.remains<=8&(raid_event.adds.in>20|active_enemies>1|!raid_event.adds.exists)&(buff.active_uas.stack>=2|active_enemies>3)&(!talent.deaths_embrace.enabled|time_to_die>120|time_to_die<30)
-- actions.writhe+=/potion,if=target.time_to_die<=70
-- actions.writhe+=/potion,if=(!talent.soul_harvest.enabled|buff.soul_harvest.remains>12)&(trinket.proc.any.react|trinket.stack_proc.any.react|buff.active_uas.stack>=2)
-- actions.writhe+=/siphon_life,cycle_targets=1,if=remains<=tick_time+gcd&time_to_die>tick_time*2
-- actions.writhe+=/corruption,cycle_targets=1,if=remains<=tick_time+gcd&((spell_targets.seed_of_corruption<3&talent.sow_the_seeds.enabled)|spell_targets.seed_of_corruption<5)&time_to_die>tick_time*2
-- actions.writhe+=/life_tap,if=mana.pct<40&(buff.active_uas.stack<1|!buff.deadwind_harvester.remains)
-- actions.writhe+=/reap_souls,if=(buff.deadwind_harvester.remains+buff.tormented_souls.react*(5+equipped.144364))>=(12*(5+1.5*equipped.144364))
-- actions.writhe+=/phantom_singularity
-- actions.writhe+=/seed_of_corruption,if=(talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption>=3)|(spell_targets.seed_of_corruption>3&dot.corruption.refreshable)
-- actions.writhe+=/unstable_affliction,if=talent.contagion.enabled&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.writhe+=/unstable_affliction,if=talent.absolute_corruption.enabled&set_bonus.tier21_4pc&debuff.tormented_agony.remains<=cast_time
-- actions.writhe+=/unstable_affliction,cycle_targets=1,target_if=buff.deadwind_harvester.remains>=duration+cast_time&dot.unstable_affliction_1.remains<cast_time&dot.unstable_affliction_2.remains<cast_time&dot.unstable_affliction_3.remains<cast_time&dot.unstable_affliction_4.remains<cast_time&dot.unstable_affliction_5.remains<cast_time
-- actions.writhe+=/unstable_affliction,if=buff.deadwind_harvester.remains>tick_time*2&(!set_bonus.tier21_4pc|talent.contagion.enabled|soul_shard>1)&(!talent.contagion.enabled|soul_shard>1|buff.soul_harvest.remains)&(dot.unstable_affliction_1.ticking+dot.unstable_affliction_2.ticking+dot.unstable_affliction_3.ticking+dot.unstable_affliction_4.ticking+dot.unstable_affliction_5.ticking<5)
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&buff.active_uas.stack>1
-- actions.writhe+=/reap_souls,if=!buff.deadwind_harvester.remains&prev_gcd.1.unstable_affliction&buff.tormented_souls.react>1
-- actions.writhe+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3&(!buff.deadwind_harvester.remains|buff.active_uas.stack<1)
-- actions.writhe+=/agony,if=refreshable&time_to_die>=remains
-- actions.writhe+=/siphon_life,if=refreshable&time_to_die>=remains
-- actions.writhe+=/corruption,if=refreshable&time_to_die>=remains
-- actions.writhe+=/agony,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable
-- actions.writhe+=/siphon_life,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable
-- actions.writhe+=/corruption,cycle_targets=1,target_if=sim.target!=target&time_to_die>tick_time*3&!buff.deadwind_harvester.remains&refreshable
-- actions.writhe+=/life_tap,if=mana.pct<=10
-- actions.writhe+=/life_tap,if=prev_gcd.1.life_tap&buff.active_uas.stack=0&mana.pct<50
-- actions.writhe+=/drain_soul,chain=1,interrupt=1
-- actions.writhe+=/life_tap,moving=1,if=mana.pct<80
-- actions.writhe+=/agony,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.writhe+=/siphon_life,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.writhe+=/corruption,moving=1,cycle_targets=1,if=remains<=duration-(3*tick_time)
-- actions.writhe+=/life_tap,moving=0

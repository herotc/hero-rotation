
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
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = HR.Commons.Everyone;
  local Warlock = HR.Commons.Warlock;
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
    Fear 			        = Spell(5782),
    
    -- Pet abilities
    CauterizeMaster		= Spell(119905),--imp
    Suffering				  = Spell(119907),--voidwalker
    SpellLock				  = Spell(119910),--Dogi
    Whiplash				  = Spell(119909),--Bitch
    ShadowLock				= Spell(171140),--doomguard
    MeteorStrike			= Spell(171152),--infernal
    SingeMagic			  = Spell(89808),--imp
    SpellLock			    = Spell(19647),--felhunter
    
    -- Talents
    Backdraft 				= Spell(196406),
    RoaringBlaze 			= Spell(205184),
    Shadowburn				= Spell(17877),
    
    ReverseEntropy		= Spell(205148),
    Eradication 			= Spell(196412),
    EmpoweredLifeTap 	= Spell(235157),
    
    DemonicCircle 		= Spell(48018),
    MortalCoil 			  = Spell(6789),
    ShadowFury 			  = Spell(30283),
    
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
    DimensionRipper 	    = Spell(219415),
    
    -- Defensive	
    UnendingResolve 	= Spell(104773),
      
    -- Legendaries
    LessonsOfSpaceTimeBuff = Spell(236176),
    SindoreiSpiteBuff = Spell(208868),
    SephuzBuff        = Spell(208052),
    NorgannonsBuff    = Spell(236431),
      
    -- Misc
    DemonicPower 			    = Spell(196099),
    EmpoweredLifeTapBuff	= Spell(235156),
    LordOfFlamesDebuff    = Spell(226802),
    BackdraftBuff         = Spell(117828),
    Concordance           = Spell(242586)
  };
  local S = Spell.Warlock.Destruction;
  
  local PetSpells={[S.Suffering:ID()] = true, [S.SpellLock:ID()] = true, [S.Whiplash:ID()] = true, [S.CauterizeMaster:ID()] = true }
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Destruction = {
    -- Legendaries
    LessonsOfSpaceTime  = Item(144369, {3}),
    SindoreiSpite       = Item(132379, {9}),
    SephuzSecret 			  = Item(132452, {11,12}),
    
    -- Potion
    PotionOfProlongedPower  = Item(142117)
  };
  local I = Item.Warlock.Destruction;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P, T194P = HL.HasTier("T19")
  local T202P, T204P = HL.HasTier("T20")
  local T212P, T214P = HL.HasTier("T21");
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range = 40
  local CastIncinerate, CastImmolate, CastConflagrate, CastRainOfFire
  local PetSpells={[S.Suffering:ID()] = true, [S.SpellLock:ID()] = true, [S.Whiplash:ID()] = true, [S.CauterizeMaster:ID()] = true} 
  
  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Warlock.Commons,
    Destruction = HR.GUISettings.APL.Warlock.Destruction
  };

--- ======= ACTION LISTS =======
  local function IsPetInvoked (testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end
  
  local function GetImmolateStack(target)
    if not S.RoaringBlaze:IsAvailable() then  
      return 0
    end
    if not target then 
      return 0
    end
    return HL.ImmolationTable.Destruction.ImmolationDebuff[target:GUID()] or 0;
  end
  
  local function EnemyHasHavoc ()
    for _, Value in pairs(Cache.Enemies[range]) do
      if Value:Debuff(S.Havoc) then
        return Value:DebuffRemainsP(S.Havoc)
      end
    end
    return 0
  end

  local function handleSettings ()
    if Settings.Destruction.SpellType == "Auto" then --auto
      CastIncinerate = S.IncinerateAuto
      CastImmolate = S.ImmolateAuto
      CastConflagrate = S.ConflagrateAuto
      CastRainOfFire = S.RainOfFireAuto
    elseif Settings.Destruction.SpellType == "Green" then --green
      CastIncinerate = S.IncinerateGreen
      CastImmolate = S.ImmolateGreen
      CastConflagrate = S.ConflagrateGreen
      CastRainOfFire = S.RainOfFireGreen
    else --orange
      CastIncinerate = S.IncinerateOrange
      CastImmolate = S.ImmolateOrange
      CastConflagrate = S.ConflagrateOrange
      CastRainOfFire = S.RainOfFireOrange
    end
  end

  local function FutureShard ()
    local Shard = Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(S.ChaosBolt) then
        return Shard - 2
      elseif Player:IsCasting(S.SummonDoomGuard) or Player:IsCasting(S.SummonDoomGuardSuppremacy) or Player:IsCasting(S.SummonInfernal) or Player:IsCasting(S.SummonInfernalSuppremacy) or Player:IsCasting(S.GrimoireImp) or Player:IsCasting(S.SummonImp) then
        return Shard - 1
      elseif Player:IsCasting(S.Incinerate) then
        return Shard + 0.2
      else
        return Shard
      end
    end
  end  
  
  local function CDs ()
    -- actions+=/berserking
    if S.Berserking:IsAvailable() and S.Berserking:CooldownRemainsP() == 0 then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    
    -- actions+=/blood_fury
    if S.BloodFury:IsAvailable() and S.BloodFury:CooldownRemainsP() == 0 then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    
    -- actions+=/use_items
    
    -- actions+=/potion,name=deadly_grace,if=(buff.soul_harvest.remains|trinket.proc.any.react|target.time_to_die<=45)
    if Settings.Destruction.ShowPoPP and I.PotionOfProlongedPower:IsReady() and (Player:BuffRemainsP(S.SoulHarvest) > 0 or Target:FilteredTimeToDie("<=", 60)) then
      if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
    end
    
    -- actions+=/service_pet
    if S.GrimoireImp:IsAvailable() and S.GrimoireImp:CooldownRemainsP() == 0 and FutureShard() >= 1 then
      if HR.Cast(S.GrimoireImp, Settings.Destruction.GCDasOffGCD.GrimoireImp) then return ""; end
    end
    
    -- actions+=/summon_infernal,if=artifact.lord_of_flames.rank>0&!buff.lord_of_flames.remains
    if not S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemainsP() == 0 
      and ((S.LordOfFlames:ArtifactRank() > 0 and Player:DebuffRemainsP(S.LordOfFlamesDebuff) == 0) or Cache.EnemiesCount[range] > 2) and FutureShard() >= 1 then
        if HR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    
    -- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
    if S.SummonDoomGuard:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0 and FutureShard() >= 1
      and not S.GrimoireOfSupremacy:IsAvailable() and Cache.EnemiesCount[range] <= 2 and (S.LordOfFlames:ArtifactRank() == 0 or Player:DebuffRemainsP(S.LordOfFlamesDebuff) > 0)
      and ((Target:FilteredTimeToDie(">", 180) or Target:HealthPercentage() <= 20 or Target:FilteredTimeToDie("<", 30)) or (I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180))  then
        if HR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end
    
    -- actions+=/soul_harvest,if=!buff.soul_harvest.remains
    if S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemainsP() == 0 and Player:BuffRemainsP(S.SoulHarvest) == 0 then
      if HR.Cast(S.SoulHarvest, Settings.Destruction.OffGCDasOffGCD.SoulHarvest) then return ""; end
    end

  end
  
  local function Sephuz ()
    -- ShadowFury
    --TODO : change level when iscontrollable is here
    if S.ShadowFury:IsAvailable() and S.ShadowFury:IsCastable() and Target:Level() < 103 and Settings.Destruction.Sephuz.ShadowFury then
      if HR.CastSuggested(S.ShadowFury) then return "Cast"; end
    end
    
    -- MortalCoil
    --TODO : change level when iscontrollable is here
    if S.MortalCoil:IsAvailable() and S.MortalCoil:IsCastable() and Target:Level() < 103 and Settings.Destruction.Sephuz.MortalCoil then
      if HR.CastSuggested(S.MortalCoil) then return "Cast"; end
    end
    
    -- Fear
    --TODO : change level when iscontrollable is here
    if S.Fear:IsAvailable() and S.Fear:IsCastable() and Target:Level() < 103 and Settings.Destruction.Sephuz.Fear then
      if HR.CastSuggested(S.Fear) then return "Cast"; end
    end
    
    -- SingeMagic 
    --TODO : add if a debuff is removable
    -- if S.SingeMagic:IsAvailable() and S.SingeMagic:IsCastable() and Settings.Destruction.Sephuz.SingeMagic then
      -- if HR.CastSuggested(S.SingeMagic) then return "Cast"; end
    -- end
    
    -- SpellLock
    if S.SpellLock:IsAvailable() and S.SpellLock:IsCastable() and Target:IsCasting() and Target:IsInterruptible() and Settings.Destruction.Sephuz.SpellLock then
      if HR.CastSuggested(S.SpellLock) then return "Cast"; end
    end
  end
  
--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    HL.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    handleSettings()
    
    -- TODO : add the possibility to choose a pet
    -- TODO : Sephuz - SingMagic : add if a debuff is removable
    -- TODO : buff listener for chaos bolt
    -- TODO : Add prepot
    -- TODO : remove aoeon
    
    -- Defensives
    if S.UnendingResolve:IsCastable() and Player:HealthPercentage() <= Settings.Destruction.UnendingResolveHP then
      if HR.Cast(S.UnendingResolve, Settings.Destruction.OffGCDasOffGCD.UnendingResolve) then return ""; end
    end
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonImp:IsCastable() and (Warlock.PetReminder() and (not IsPetInvoked() or not S.CauterizeMaster:IsLearned()) or not IsPetInvoked()) and not S.GrimoireOfSupremacy:IsAvailable() and (not S.GrimoireOfSacrifice:IsAvailable() or Player:BuffRemainsP(S.DemonicPower) < 600) and FutureShard() >= 1 and not Player:IsCasting(S.SummonImp) then
      if HR.Cast(S.SummonImp, Settings.Destruction.GCDasOffGCD.SummonImp) then return ""; end
    end
    
    -- actions.precombat+=/grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireOfSacrifice:IsAvailable() and Player:BuffRemains(S.DemonicPower) < 600 and (IsPetInvoked() or Player:IsCasting(S.SummonImp)) then
      if HR.Cast(S.GrimoireOfSacrifice, Settings.Destruction.GCDasOffGCD.GrimoireOfSacrifice) then return ""; end
    end
    
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked(true) or not S.MeteorStrike:IsLearned()) or not IsPetInvoked(true)) and ((S.LordOfFlames:ArtifactRank() > 0) or (Cache.EnemiesCount[range] > 1)) and FutureShard() >= 1 then
      if HR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked(true) or not S.ShadowLock:IsLearned()) or not IsPetInvoked(true)) and not S.LordOfFlames:ArtifactRank() == 0 and (Cache.EnemiesCount[range] == 1) and FutureShard() >= 1 then
      if HR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- actions.precombat+=/life_tap,if=talent.empowered_life_tap.enabled&!buff.empowered_life_tap.remains
      if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) == 0 then
        if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
      end
      
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
		
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange(range) then
        if not Player:IsCasting() or (Player:IsCasting(S.Immolate) and S.RoaringBlaze:IsAvailable()) then
          if HR.Cast(CastImmolate) then return ""; end
        else
          if HR.Cast(CastConflagrate) then return ""; end
        end
      end
      return;
    end
    
    -- In Combat
    if Everyone.TargetIsValid() then
      if Target:IsInRange(range) then
        -- Cds Usage
        if HR.CDsON() then
          ShouldReturn = CDs();
          if ShouldReturn then return ShouldReturn; end
        end
        
        -- Sephuz usage
        if I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 then
          ShouldReturn = Sephuz();
          if ShouldReturn then return ShouldReturn; end
        end
      
        --Movement
        if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then	--static
          -- actions=immolate,cycle_targets=1,if=active_enemies=2&talent.roaring_blaze.enabled&!cooldown.havoc.remains&dot.immolate.remains<=buff.active_havoc.duration
          if Player:ManaP() >= S.Immolate:Cost() and Cache.EnemiesCount[range] == 2 and S.RoaringBlaze:IsAvailable() and S.Havoc:CooldownRemainsP() > 0 and Target:DebuffRemainsP(S.ImmolateDebuff) <= EnemyHasHavoc() and not(not S.RoaringBlaze:IsAvailable() and Player:IsCasting(S.Immolate)) then
            if HR.Cast(CastImmolate) then return ""; end
          end
          if HR.AoEON() and Player:ManaP() >= S.Immolate:Cost() and Cache.EnemiesCount[range] == 2 and S.RoaringBlaze:IsAvailable() and S.Havoc:CooldownRemainsP() > 0 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.ImmolateDebuff) <= EnemyHasHavoc() and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast  = Value, Value:TimeToDie(), CastImmolate;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
          if HR.AoEON() and Player:ManaP() >= S.Havoc:Cost() and Cache.EnemiesCount[range] > 1 and (Cache.EnemiesCount[range] < 4 or (S.WreakHavoc:IsAvailable() and Cache.EnemiesCount[range] < 6)) and S.Havoc:CooldownRemainsP() == 0 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.Havoc) == 0 and not Value:IsUnit(Target) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Havoc;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/dimensional_rift,if=charges=3
          if S.DimensionalRift:IsCastable() and S.DimensionalRift:Charges() == 3 or (S.DimensionalRift:Charges() == 2 and S.DimensionalRift:RechargeP() == 0) then
            if HR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return ""; end
          end
          
          -- actions+=/cataclysm,if=spell_targets.cataclysm>=3
          if HR.AoEON() and Cache.EnemiesCount[range] >= 3 and S.Cataclysm:IsAvailable() and S.Cataclysm:CooldownRemainsP() == 0 and not Player:IsCasting(S.Cataclysm) then
            if HR.Cast(S.Cataclysm) then return ""; end
          end
          
          -- actions+=/immolate,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&remains<=tick_time
          if Player:ManaP() >= S.Immolate:Cost() and (not HR.AoEON() or (HR.AoEON() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()))) and Target:DebuffRemainsP(S.ImmolateDebuff) <= S.ImmolateDebuff:TickTime() and not (Player:IsCasting(S.Immolate) or Player:IsCasting(S.Cataclysm)) then
            if HR.Cast(CastImmolate) then return ""; end
          end
          
          -- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&active_enemies>1&remains<=tick_time&(!talent.roaring_blaze.enabled|(!debuff.roaring_blaze.remains&action.conflagrate.charges<2+set_bonus.tier19_4pc))
          if Player:ManaP() >= S.Immolate:Cost() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemainsP() >= S.Immolate:CastTime() * Cache.EnemiesCount[range]) and Cache.EnemiesCount[range] > 1 
            and Target:DebuffRemainsP(S.ImmolateDebuff) <= S.ImmolateDebuff:TickTime() and (not S.RoaringBlaze:IsAvailable() or (S.RoaringBlaze:IsAvailable() and GetImmolateStack(Target) == 0 and S.Conflagrate:ChargesP() < 2 + (T194P and 1 or 0))) and not(not S.RoaringBlaze:IsAvailable() and not Player:IsCasting(S.Immolate)) then
            if HR.Cast(CastImmolate) then return ""; end
          end
          if HR.AoEON() and Player:ManaP() >= S.Immolate:Cost() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemainsP()>= S.Immolate:CastTime()*Cache.EnemiesCount[range]) and Cache.EnemiesCount[range]>1 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.ImmolateDebuff) <= S.ImmolateDebuff:TickTime() and (not S.RoaringBlaze:IsAvailable() or (S.RoaringBlaze:IsAvailable() and GetImmolateStack(Value) == 0 and S.Conflagrate:ChargesP() < 2 + (T194P and 1 or 0))) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) and not Value:DebuffRemainsP(S.Havoc) == 0 then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), CastImmolate;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/immolate,if=talent.roaring_blaze.enabled&remains<=duration&!debuff.roaring_blaze.remains&target.time_to_die>10&(action.conflagrate.charges=2+set_bonus.tier19_4pc|(action.conflagrate.charges>=1+set_bonus.tier19_4pc&action.conflagrate.recharge_time<cast_time+gcd)|target.time_to_die<24)
          if Player:ManaP() >= S.Immolate:Cost() and S.RoaringBlaze:IsAvailable() and Target:DebuffRemainsP(S.ImmolateDebuff) <= S.ImmolateDebuff:BaseDuration() and GetImmolateStack(Target) == 0 and Target:FilteredTimeToDie(">", 10)
            and (S.Conflagrate:ChargesP() == 2 + (T194P and 1 or 0) or Target:FilteredTimeToDie("<", 24)) and not(Player:IsCasting(S.Immolate) or Player:IsCasting(S.Cataclysm)) and not(not S.RoaringBlaze:IsAvailable() and Player:IsCasting(S.Immolate)) then
            if HR.Cast(CastImmolate) then return ""; end
          end
          
          -- actions+=/shadowburn,if=soul_shard<4&buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
          if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and FutureShard() < 4 and S.Shadowburn:ChargesP() >= 1 and Player:BuffRemainsP(S.ConflagrationOfChaosDebuff) <= S.ChaosBolt:CastTime() then
            if HR.Cast(S.Shadowburn) then return ""; end
          end
          
          -- actions+=/shadowburn,if=(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
          if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and ((S.Shadowburn:ChargesP() == 1 + (T194P and 1 or 0) and  S.Shadowburn:Recharge() < S.ChaosBolt:CastTime() + Player:GCD()) or S.Shadowburn:ChargesP() == 2 + (T194P and 1 or 0)) and FutureShard() < 5 then
            if HR.Cast(S.Shadowburn) then return ""; end
          end
          
          -- actions+=/conflagrate,if=talent.roaring_blaze.enabled&(charges=2+set_bonus.tier19_4pc|(charges>=1+set_bonus.tier19_4pc&recharge_time<gcd)|target.time_to_die<24)
          if S.RoaringBlaze:IsAvailable() and S.Conflagrate:ChargesP() > 0 and (S.Conflagrate:ChargesP() >= 1 + (T194P and 1 or 0) or Target:FilteredTimeToDie("<", 24)) then
            if HR.Cast(CastConflagrate) then return ""; end
          end
          
          -- actions+=/conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.stack>0&dot.immolate.remains>dot.immolate.duration*0.3&(active_enemies=1|soul_shard<3)&soul_shard<5
          if S.RoaringBlaze:IsAvailable() and S.Conflagrate:ChargesP() > 0 and  GetImmolateStack(Target) > 0 and Target:DebuffRefreshableCP(S.ImmolateDebuff) and (Cache.EnemiesCount[range] == 1 or FutureShard() < 3) and FutureShard() < 5 then
            if HR.Cast(CastConflagrate) then return ""; end
          end

          -- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
          if not S.RoaringBlaze:IsAvailable() and Player:BuffStack(S.BackdraftBuff) < 3 and (( S.Conflagrate:ChargesP() == 1+(T194P and 1 or 0) and S.Conflagrate:RechargeP() < S.Immolate:CastTime() + Player:GCD()) or S.Conflagrate:ChargesP() == 2 + (T194P and 1 or 0)) and FutureShard() < 5 then
            if HR.Cast(CastConflagrate) then return ""; end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) == 0 then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/dimensional_rift,if=equipped.144369&!buff.lessons_of_spacetime.remains&((!talent.grimoire_of_supremacy.enabled&!cooldown.summon_doomguard.remains)|(talent.grimoire_of_service.enabled&!cooldown.service_pet.remains)|(talent.soul_harvest.enabled&!cooldown.soul_harvest.remains))
          if S.DimensionalRift:IsCastable() and S.DimensionalRift:ChargesP() > 0 and I.LessonsOfSpaceTime:IsEquipped() and Player:BuffRemainsP(S.LessonsOfSpaceTimeBuff) == 0 
            and ((not S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0) 
              or (S.GrimoireOfService:IsAvailable() and not S.GrimoireImp:IsAvailable()) 
              or (S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemainsP() == 0)) then
                if HR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return ""; end
          end

          -- actions+=/chaos_bolt,if=active_enemies<4&buff.active_havoc.remains>cast_time
          if S.ChaosBolt:IsCastable() and FutureShard() >= 2 and Cache.EnemiesCount[range] < 4 and EnemyHasHavoc() > S.ChaosBolt:CastTime() then
            if HR.Cast(S.ChaosBolt) then return ""; end
          end

          -- actions+=/channel_demonfire,if=dot.immolate.remains>cast_time&(active_enemies=1|buff.active_havoc.remains<action.chaos_bolt.cast_time)
          if S.ChannelDemonfire:IsCastable() and Player:ManaP() >= S.ChannelDemonfire:Cost() and S.ChannelDemonfire:IsAvailable() and Target:DebuffRemainsP(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime() and (Cache.EnemiesCount[range] == 1 or EnemyHasHavoc() < S.ChaosBolt:CastTime()) and not (Player:IsChanneling() and Player:ChannelName()==S.ChannelDemonfire:Name()) then
            if HR.Cast(S.ChannelDemonfire) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=3
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 3 and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=6&talent.wreak_havoc.enabled
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 6 and S.WreakHavoc:IsAvailable() and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/dimensional_rift,if=target.time_to_die<=32|!equipped.144369|charges>1|(!equipped.144369&(!talent.grimoire_of_service.enabled|recharge_time<cooldown.service_pet.remains)&(!talent.soul_harvest.enabled|recharge_time<cooldown.soul_harvest.remains)&(!talent.grimoire_of_supremacy.enabled|recharge_time<cooldown.summon_doomguard.remains))
          if S.DimensionalRift:IsCastable() and S.DimensionalRift:ChargesP() > 0 
          and (Target:FilteredTimeToDie("<=", 32) or not I.LessonsOfSpaceTime:IsEquipped() or S.DimensionalRift:ChargesP() > 1 
            or (not I.LessonsOfSpaceTime:IsEquipped() and (not S.GrimoireOfService:IsAvailable() or S.DimensionalRift:RechargeP() < S.GrimoireImp:CooldownRemainsP()) 
              and (not S.SoulHarvest:IsAvailable() or S.DimensionalRift:RechargeP() < S.SoulHarvest:CooldownRemainsP()))) then
                if HR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return ""; end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/cataclysm
          if S.Cataclysm:IsAvailable() and S.Cataclysm:CooldownRemainsP() == 0 and not Player:IsCasting(S.Cataclysm) then
            if HR.Cast(S.Cataclysm) then return ""; end
          end
          
          -- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*1.5|target.time_to_die<=10)
          if S.ChaosBolt:IsCastable() and FutureShard() >= 2 and Cache.EnemiesCount[range] < 3 and (S.Havoc:CooldownRemainsP() > 12 or Cache.EnemiesCount[range] == 1 or FutureShard() >= 5 - (Cache.EnemiesCount[range] * 0.5) or Target:TimeToDie() <= 10)then
            if HR.Cast(S.ChaosBolt) then return ""; end
          end
          
          -- actions+=/shadowburn
          if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and S.Shadowburn:ChargesP() >= 1 then
            if HR.Cast(S.Shadowburn) then return ""; end
          end
          
          -- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3
           if S.Backdraft:IsAvailable() and Player:BuffStack(S.BackdraftBuff) < 3 and  S.Conflagrate:ChargesP() > 1 then
            if HR.Cast(CastConflagrate) then return ""; end
          end
          -- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&!talent.roaring_blaze.enabled&remains<=duration*0.3
          if Player:ManaP() >= S.Immolate:Cost() and S.Immolate:IsCastable() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemainsP() >= S.Immolate:CastTime() * Cache.EnemiesCount[range]) and not S.RoaringBlaze:IsAvailable() and Target:DebuffRefreshableCP(S.ImmolateDebuff) and not(Player:IsCasting(S.Immolate) or Player:IsCasting(S.Cataclysm)) and not(not S.RoaringBlaze:IsAvailable() and Player:IsCasting(S.Immolate)) then
            if HR.Cast(CastImmolate) then return ""; end
          end
          if HR.AoEON() and Player:ManaP() >= S.Immolate:Cost() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()) 
            and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemainsP() >= S.Immolate:CastTime() * Cache.EnemiesCount[range]) 
            and not S.RoaringBlaze:IsAvailable() and not(Player:IsCasting(S.Immolate) or Player:IsCasting(S.Cataclysm)) then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRefreshableCP(S.ImmolateDebuff) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ImmolateDebuff))then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), CastImmolate;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
          end
          
          -- actions+=/incinerate
          if S.Incinerate:IsCastable() and Player:ManaP() >= S.Incinerate:Cost() then
            if HR.Cast(CastIncinerate) then return""; end
          end
          
          -- actions+=/life_tap   
          if HR.Cast(S.LifeTap) then return""; end
            
          return;
        
        else --moving
          -- actions+=/havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
          if HR.AoEON() and Player:ManaP() >= S.Havoc:Cost() and Cache.EnemiesCount[range] > 1 and (Cache.EnemiesCount[range] < 4 or (S.WreakHavoc:IsAvailable() and Cache.EnemiesCount[range] < 6)) and S.Havoc:CooldownRemainsP() == 0 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.Havoc) == 0 and not Value:IsUnit(Target) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Havoc;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/dimensional_rift,if=charges=3
          if S.DimensionalRift:IsCastable() and S.DimensionalRift:Charges() == 3 or (S.DimensionalRift:Charges() == 2 and S.DimensionalRift:RechargeP() == 0) then
            if HR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return ""; end
          end
          
          -- actions+=/shadowburn,if=soul_shard<4&buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
          if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and FutureShard() < 4 and S.Shadowburn:ChargesP() >= 1 and Player:BuffRemainsP(S.ConflagrationOfChaosDebuff) <= S.ChaosBolt:CastTime() then
            if HR.Cast(S.Shadowburn) then return ""; end
          end
          
          -- actions+=/shadowburn,if=(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
          if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and ((S.Shadowburn:ChargesP() == 1 + (T194P and 1 or 0) and  S.Shadowburn:Recharge() < S.ChaosBolt:CastTime() + Player:GCD()) or S.Shadowburn:ChargesP() == 2 + (T194P and 1 or 0)) and FutureShard() < 5 then
            if HR.Cast(S.Shadowburn) then return ""; end
          end
          
          -- actions+=/conflagrate,if=talent.roaring_blaze.enabled&(charges=2+set_bonus.tier19_4pc|(charges>=1+set_bonus.tier19_4pc&recharge_time<gcd)|target.time_to_die<24)
          if S.RoaringBlaze:IsAvailable() and S.Conflagrate:ChargesP() > 0 and (S.Conflagrate:ChargesP() >= 1 + (T194P and 1 or 0) or Target:FilteredTimeToDie("<", 24)) then
            if HR.Cast(CastConflagrate) then return ""; end
          end
          
          -- actions+=/conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.stack>0&dot.immolate.remains>dot.immolate.duration*0.3&(active_enemies=1|soul_shard<3)&soul_shard<5
          if S.RoaringBlaze:IsAvailable() and S.Conflagrate:ChargesP() > 0 and  GetImmolateStack(Target) > 0 and Target:DebuffRefreshableCP(S.ImmolateDebuff) and (Cache.EnemiesCount[range] == 1 or FutureShard() < 3) and FutureShard() < 5 then
            if HR.Cast(CastConflagrate) then return ""; end
          end

          -- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3&(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
          if not S.RoaringBlaze:IsAvailable() and Player:BuffStack(S.BackdraftBuff) < 3 and (( S.Conflagrate:ChargesP() == 1+(T194P and 1 or 0) and S.Conflagrate:RechargeP() < S.Immolate:CastTime() + Player:GCD()) or S.Conflagrate:ChargesP() == 2 + (T194P and 1 or 0)) and FutureShard() < 5 then
            if HR.Cast(CastConflagrate) then return ""; end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) == 0 then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/dimensional_rift,if=equipped.144369&!buff.lessons_of_spacetime.remains&((!talent.grimoire_of_supremacy.enabled&!cooldown.summon_doomguard.remains)|(talent.grimoire_of_service.enabled&!cooldown.service_pet.remains)|(talent.soul_harvest.enabled&!cooldown.soul_harvest.remains))
          if S.DimensionalRift:IsCastable() and S.DimensionalRift:ChargesP() > 0 and I.LessonsOfSpaceTime:IsEquipped() and Player:BuffRemainsP(S.LessonsOfSpaceTimeBuff) == 0 
            and ((not S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuard:CooldownRemainsP() == 0) 
              or (S.GrimoireOfService:IsAvailable() and not S.GrimoireImp:IsAvailable()) 
              or (S.SoulHarvest:IsAvailable() and S.SoulHarvest:CooldownRemainsP() == 0)) then
                if HR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=3
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 3 and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=6&talent.wreak_havoc.enabled
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 6 and S.WreakHavoc:IsAvailable() and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/dimensional_rift,if=target.time_to_die<=32|!equipped.144369|charges>1|(!equipped.144369&(!talent.grimoire_of_service.enabled|recharge_time<cooldown.service_pet.remains)&(!talent.soul_harvest.enabled|recharge_time<cooldown.soul_harvest.remains)&(!talent.grimoire_of_supremacy.enabled|recharge_time<cooldown.summon_doomguard.remains))
          if S.DimensionalRift:IsCastable() and S.DimensionalRift:ChargesP() > 0 
          and (Target:FilteredTimeToDie("<=", 32) or not I.LessonsOfSpaceTime:IsEquipped() or S.DimensionalRift:ChargesP() > 1 
            or (not I.LessonsOfSpaceTime:IsEquipped() and (not S.GrimoireOfService:IsAvailable() or S.DimensionalRift:RechargeP() < S.GrimoireImp:CooldownRemainsP()) 
              and (not S.SoulHarvest:IsAvailable() or S.DimensionalRift:RechargeP() < S.SoulHarvest:CooldownRemainsP()))) then
                if HR.Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift) then return ""; end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/shadowburn
          if S.Shadowburn:IsAvailable() and S.Shadowburn:IsCastable() and S.Shadowburn:ChargesP() >= 1 then
            if HR.Cast(S.Shadowburn) then return ""; end
          end
          
          -- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3
           if S.Backdraft:IsAvailable() and Player:BuffStack(S.BackdraftBuff) < 3 and  S.Conflagrate:ChargesP() > 1 then
            if HR.Cast(CastConflagrate) then return ""; end
          end
          
          -- actions+=/life_tap   
          if HR.Cast(S.LifeTap) then return""; end
            
          return;
            
        end
      else --not in range
        --Movement
        if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then	--static
          -- actions=immolate,cycle_targets=1,if=active_enemies=2&talent.roaring_blaze.enabled&!cooldown.havoc.remains&dot.immolate.remains<=buff.active_havoc.duration
          if HR.AoEON() and Player:ManaP() >= S.Immolate:Cost() and Cache.EnemiesCount[range] == 2 and S.RoaringBlaze:IsAvailable() and S.Havoc:CooldownRemainsP() > 0 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.ImmolateDebuff) <= EnemyHasHavoc() and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast  = Value, Value:TimeToDie(), CastImmolate;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
          if HR.AoEON() and Player:ManaP() >= S.Havoc:Cost() and Cache.EnemiesCount[range] > 1 and (Cache.EnemiesCount[range] < 4 or (S.WreakHavoc:IsAvailable() and Cache.EnemiesCount[range] < 6)) and S.Havoc:CooldownRemainsP() == 0 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.Havoc) == 0 and not Value:IsUnit(Target) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Havoc;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&active_enemies>1&remains<=tick_time&(!talent.roaring_blaze.enabled|(!debuff.roaring_blaze.remains&action.conflagrate.charges<2+set_bonus.tier19_4pc))
          if HR.AoEON() and Player:ManaP() >= S.Immolate:Cost() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemainsP()>= S.Immolate:CastTime()*Cache.EnemiesCount[range]) and Cache.EnemiesCount[range]>1 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.ImmolateDebuff) <= S.ImmolateDebuff:TickTime() and (not S.RoaringBlaze:IsAvailable() or (S.RoaringBlaze:IsAvailable() and GetImmolateStack(Value) == 0 and S.Conflagrate:ChargesP() < 2 + (T194P and 1 or 0))) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) and not Value:DebuffRemainsP(S.Havoc) == 0 then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), CastImmolate;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) == 0 then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=3
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 3 and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=6&talent.wreak_havoc.enabled
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 6 and S.WreakHavoc:IsAvailable() and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&!talent.roaring_blaze.enabled&remains<=duration*0.3
          if HR.AoEON() and Player:ManaP() >= S.Immolate:Cost() and (Cache.EnemiesCount[range] < 5 or not S.FireAndBrimstone:IsAvailable()) 
            and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemainsP() >= S.Immolate:CastTime() * Cache.EnemiesCount[range]) 
            and not S.RoaringBlaze:IsAvailable() and not(Player:IsCasting(S.Immolate) or Player:IsCasting(S.Cataclysm)) then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRefreshableCP(S.ImmolateDebuff) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ImmolateDebuff))then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), CastImmolate;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
          end
          
          -- actions+=/life_tap   
          if HR.Cast(S.LifeTap) then return""; end
            
          return;
        else --moving
          -- actions+=/havoc,target=2,if=active_enemies>1&(active_enemies<4|talent.wreak_havoc.enabled&active_enemies<6)&!debuff.havoc.remains
          if HR.AoEON() and Player:ManaP() >= S.Havoc:Cost() and Cache.EnemiesCount[range] > 1 and (Cache.EnemiesCount[range] < 4 or (S.WreakHavoc:IsAvailable() and Cache.EnemiesCount[range] < 6)) and S.Havoc:CooldownRemainsP() == 0 then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
            for _, Value in pairs(Cache.Enemies[range]) do
              if Value:DebuffRemainsP(S.Havoc) == 0 and not Value:IsUnit(Target) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Havoc)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Havoc;
              end	
            end
            if BestUnit then
              if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<=gcd
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRemainsP(S.EmpoweredLifeTapBuff) == 0 then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=3
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 3 and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/rain_of_fire,if=active_enemies>=6&talent.wreak_havoc.enabled
          if HR.AoEON() and S.RainOfFire:IsAvailable() and Cache.EnemiesCount[range] >= 6 and S.WreakHavoc:IsAvailable() and FutureShard() >= 3 then
            if HR.Cast(CastRainOfFire) then return ""; end
          end
          
          -- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
          if S.LifeTap:IsCastable() and S.EmpoweredLifeTap:IsAvailable() and Player:BuffRefreshableCP(S.EmpoweredLifeTapBuff) then
            if HR.Cast(S.LifeTap, Settings.Commons.GCDasOffGCD.LifeTap) then return ""; end
          end
          
          -- actions+=/life_tap   
          if HR.Cast(S.LifeTap) then return""; end
            
          return;
        end
      end
    end
  end

  HR.SetAPL(267, APL);


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
-- actions+=/shadowburn,if=soul_shard<4&buff.conflagration_of_chaos.remains<=action.chaos_bolt.cast_time
-- actions+=/shadowburn,if=(charges=1+set_bonus.tier19_4pc&recharge_time<action.chaos_bolt.cast_time|charges=2+set_bonus.tier19_4pc)&soul_shard<5
-- actions+=/conflagrate,if=talent.roaring_blaze.enabled&(charges=2+set_bonus.tier19_4pc|(charges>=1+set_bonus.tier19_4pc&recharge_time<gcd)|target.time_to_die<24)
-- actions+=/conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.stack>0&dot.immolate.remains>dot.immolate.duration*0.3&(active_enemies=1|soul_shard<3)&soul_shard<5
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
-- actions+=/dimensional_rift,if=target.time_to_die<=32|!equipped.144369|charges>1|(!equipped.144369&(!talent.grimoire_of_service.enabled|recharge_time<cooldown.service_pet.remains)&(!talent.soul_harvest.enabled|recharge_time<cooldown.soul_harvest.remains)&(!talent.grimoire_of_supremacy.enabled|recharge_time<cooldown.summon_doomguard.remains))
-- actions+=/life_tap,if=talent.empowered_life_tap.enabled&buff.empowered_life_tap.remains<duration*0.3
-- actions+=/cataclysm
-- actions+=/chaos_bolt,if=active_enemies<3&(cooldown.havoc.remains>12&cooldown.havoc.remains|active_enemies=1|soul_shard>=5-spell_targets.infernal_awakening*1.5|target.time_to_die<=10)
-- actions+=/shadowburn
-- actions+=/conflagrate,if=!talent.roaring_blaze.enabled&buff.backdraft.stack<3
-- actions+=/immolate,cycle_targets=1,if=(active_enemies<5|!talent.fire_and_brimstone.enabled)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>=action.immolate.cast_time*active_enemies)&!talent.roaring_blaze.enabled&remains<=duration*0.3
-- actions+=/incinerate
-- actions+=/life_tap

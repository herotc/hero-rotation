--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Pet = Unit.Pet;
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
  Spell.Warlock.Demonology = {
    -- Racials
    ArcaneTorrent			= Spell(25046),
    Berserking				= Spell(26297),
    BloodFury				  = Spell(20572),
    GiftoftheNaaru		= Spell(59547),
    Shadowmeld        = Spell(58984),
    
    -- Abilities
    DrainLife 				= Spell(234153),
    LifeTap 				  = Spell(1454),
    SummonDoomGuard		= Spell(18540),
    SummonDoomGuardSuppremacy = Spell(157757),
    SummonInfernal 		= Spell(1122),
    SummonInfernalSuppremacy = Spell(157898),
    SummonImp 				= Spell(688),
    GrimoireImp 			= Spell(111859),
    SummonFelguard    = Spell(30146),
    GrimoireFelguard  = Spell(111898),
    DemonicEmpowerment= Spell(193396),
    DemonWrath        = Spell(193440),
    Doom              = Spell(603),
    HandOfGuldan      = Spell(105174),
    ShadowBolt        = Spell(686),
    CallDreadStalkers = Spell(104316),
    Fear 			        = Spell(5782),
    
    -- Pet abilities
    CauterizeMaster		= Spell(119905),--imp
    Suffering				  = Spell(119907),--voidwalker
    SpellLock				  = Spell(119910),--Dogi
    Whiplash				  = Spell(119909),--Bitch
    FelStorm				  = Spell(119914),--FelGuard
    ShadowLock				= Spell(171140),--doomguard
    MeteorStrike			= Spell(171152),--infernal
    AxeToss			      = Spell(89766),--FelGuard
    
    -- Talents
    ShadowyInspiration  = Spell(196269),
    ShadowFlame         = Spell(205181),
    DemonicCalling      = Spell(205145),
    
    ImpendingDoom       = Spell(196270),
    ImprovedStalkers    = Spell(196272),
    Implosion           = Spell(196277),
    
    DemonicCircle 		  = Spell(48018),
    MortalCoil 			    = Spell(6789),
    ShadowFury 			    = Spell(30283),
    
    HandOfDoom          = Spell(196283),
    PowerTrip           = Spell(196605),
    SoulHarvest         = Spell(196098),
    
    GrimoireOfSupremacy = Spell(152107),
    GrimoireOfService 	= Spell(108501),
    GrimoireOfSynergy   = Spell(171975),
    
    SummonDarkGlare     = Spell(205180),
    Demonbolt           = Spell(157695),
    SoulConduit         = Spell(215941),
    
    -- Artifact
    TalkielConsumption  = Spell(211714),
    StolenPower         = Spell(211530),
    ThalkielsAscendance = Spell(238145),
    
    -- Defensive	
    UnendingResolve 	= Spell(104773),
    
    -- Utility
    
    -- Legendaries
    SephuzBuff        = Spell(208052),
    NorgannonsBuff    = Spell(236431),
    
    -- Misc
    Concordance             = Spell(242586),
    DemonicCallingBuff      = Spell(205146),
    GrimoireOfSynergyBuff   = Spell(171982),
    ShadowyInspirationBuff  = Spell(196606)
  };
  local S = Spell.Warlock.Demonology;
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Demonology = {
    -- Legendaries
    SindoreiSpite = Item(132379, {9}), 
    WilfredsSigil = Item(132369, {11,12}), 
    SephuzSecret 	= Item(132452, {11,12}),
    
    -- Potion
    PotionOfProlongedPower = Item(142117)
  };
  local I = Item.Warlock.Demonology;
  
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P, T194P = HL.HasTier("T19")
  local T202P, T204P = HL.HasTier("T20")
  local T212P, T214P = HL.HasTier("T21");
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range = 40
	-- BuffCount[x] = {nbBuffed, nbNotBuffed, nbBuffed+nbNotBuffed}
  local BuffCount={["All"] = {}, ["Wild Imp"] = {}, ["Dreadstalker"] = {}, ["Doomguard"] = {}, ["Infernal"] = {}, ["DarkGlare"] = {}}
  local var_3min, var_no_de1, var_no_de2
  local PetsInfo = {
    [55659] = {"Wild Imp", 12},
    [99737] = {"Wild Imp", 12},
    [98035] = {"Dreadstalker", 12},
    [11859] = {"Doomguard", 25},
    [89]    = {"Infernal", 25},
    [103673]= {"DarkGlare", 12},
  }
  
  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Warlock.Commons,
    Demonology = HR.GUISettings.APL.Warlock.Demonology
  };


--- ======= ACTION LISTS =======
  -- Get if the pet are invoked. Parameter = true if you also want to test big pets
  local function IsPetInvoked (testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or S.FelStorm:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end
  
  -- Get if the main pet is buffed and the duration
  local function DemonicEmpowermentDuration ()
    return IsPetActive() and Pet:BuffRemainsP(S.DemonicEmpowerment) or 0
  end
  
  -- updates the pet table
  local function RefreshPetsTimers ()
    if not HL.GuardiansTable.Pets then
      return
    end
    for key, Value in pairs(HL.GuardiansTable.Pets) do
      local duration = 0
      if PetsInfo[HL.GuardiansTable.Pets[key][2]] then
        duration = PetsInfo[HL.GuardiansTable.Pets[key][2]][2]
      end
      if GetTime() - HL.GuardiansTable.Pets[key][3] >= duration then
        HL.GuardiansTable.Pets[key] = nil
      end
    end
  end
  
  -- Get the max duration of a type of pet
  local function GetPetRemains (PetType)
    if not PetType then
      return 0
    end
    local maxduration = 0.0
    for key, Value in pairs(HL.GuardiansTable.Pets) do
      if HL.GuardiansTable.Pets[key][1] == PetType then
        if (PetsInfo[HL.GuardiansTable.Pets[key][2]][2] - (GetTime() - HL.GuardiansTable.Pets[key][3])) > maxduration then
          maxduration = HL.OffsetRemains((PetsInfo[HL.GuardiansTable.Pets[key][2]][2] - (GetTime() - HL.GuardiansTable.Pets[key][3])), "Auto" );
        end
      end
    end
    return maxduration
  end
  
  -- Get the number of buffed pets
  local function GetNbBuffed (PetType)
    return BuffCount[PetType][1]
  end
  
  -- Get the number of non buffed pets
  local function GetNbNotBuffed (PetType)
    return BuffCount[PetType][2]
  end
  
  -- Get the total number of pets
  local function GetNbTotal (PetType)
    return BuffCount[PetType][3]
  end
  
  -- Get if there is non buffed pets
  local function IsNonBuffed (PetType)
    return GetNbTotal(PetType) > 0 and GetNbNotBuffed(PetType) > 0
  end

  -- Extract the buffed pets from events of a specific pet
  local function GetPetBuffed (PetType)
    PetType = PetType or false
    local countBuffed = 0
    local countNotBuffed = 0
    if not HL.GuardiansTable.Pets then
      return countBuffed, countNotBuffed
    end
    for key, Value in pairs(HL.GuardiansTable.Pets) do
      if not PetType or (PetType and HL.GuardiansTable.Pets[key][1] == PetType) then
        if HL.GuardiansTable.Pets[key][5] then
          countBuffed = countBuffed + 1
        else
          countNotBuffed = countNotBuffed + 1
        end
      end
    end
    return countBuffed, countNotBuffed
  end
  
  -- Extract the buffed pets from events of all pets
  local function GetAllPetBuffed ()
    local countBuffed = 0
    local countNotBuffed = 0
    
    for key, Value in pairs(BuffCount) do
      if key == "All" then
        countBuffed,countNotBuffed = GetPetBuffed()
        BuffCount[key] = {countBuffed,countNotBuffed,countBuffed+countNotBuffed}
      else
        countBuffed,countNotBuffed = GetPetBuffed(key)
        BuffCount[key] = {countBuffed,countNotBuffed,countBuffed+countNotBuffed}
      end
    end
  end

  -- Calculated the futur shards
  local function FutureShard ()
    local Shard = Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:IsCasting(S.CallDreadStalkers) then
        return Shard - 2
      elseif Player:IsCasting(S.HandOfGuldan) then
        return 0
      elseif Player:IsCasting(S.SummonDoomGuard) or Player:IsCasting(S.SummonDoomGuardSuppremacy) or Player:IsCasting(S.SummonInfernal) or Player:IsCasting(S.SummonInfernalSuppremacy) or Player:IsCasting(S.GrimoireFelguard) or Player:IsCasting(S.SummonFelguard) then
        return Shard - 1
      elseif Player:IsCasting(S.ShadowBolt) or Player:IsCasting(S.Demonbolt) then
        if Shard == 5 then
          return Shard
        else
          return Shard + 1
        end
      else
        return Shard
      end
    end
  end
  
  -- Is the player casting and abylity that generates pets ?
  local function IsCastingPet ()
    return Player:IsCasting(S.CallDreadStalkers) or Player:IsCasting(S.HandOfGuldan) or Player:IsCasting(S.SummonDoomGuard) or Player:IsCasting(S.SummonInfernal)
  end
  
  local function UpdateVars ()
    GetAllPetBuffed ()
    -- actions+=/variable,name=3min,value=doomguard_no_de>0|infernal_no_de>0
    var_3min = IsNonBuffed("Doomguard") or IsNonBuffed("Infernal")
    -- actions+=/variable,name=no_de1,value=dreadstalker_no_de>0|darkglare_no_de>0|doomguard_no_de>0|infernal_no_de>0|service_no_de>0
    var_no_de1 = IsNonBuffed("Dreadstalker") or IsNonBuffed("DarkGlare") or IsNonBuffed("Doomguard") or IsNonBuffed("Infernal") or (IsPetInvoked() and DemonicEmpowermentDuration() == 0)
    -- actions+=/variable,name=no_de2,value=(variable.3min&service_no_de>0)|(variable.3min&wild_imp_no_de>0)|(variable.3min&dreadstalker_no_de>0)|(service_no_de>0&dreadstalker_no_de>0)|(service_no_de>0&wild_imp_no_de>0)|(dreadstalker_no_de>0&wild_imp_no_de>0)|(prev_gcd.1.hand_of_guldan&variable.no_de1)
    var_no_de2 = (var_3min and (IsPetInvoked() and DemonicEmpowermentDuration() == 0)) or (var_3min and IsNonBuffed("Wild Imp")) or (var_3min and IsNonBuffed("Dreadstalker")) or ((IsPetInvoked() and DemonicEmpowermentDuration() == 0) and IsNonBuffed("Dreadstalker")) or ((IsPetInvoked() and DemonicEmpowermentDuration() == 0) and IsNonBuffed("Wild Imp")) or (IsNonBuffed("Wild Imp") and IsNonBuffed("Dreadstalker")) or (Player:PrevGCDP(1, S.HandOfGuldan) and var_no_de1) 
  end
  
  local function CDs ()
    -- actions+=/service_pet
    if S.GrimoireFelguard:IsAvailable() and S.GrimoireFelguard:CooldownRemainsP() == 0 and FutureShard() >= 1 then
      if HR.Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard) then return ""; end
    end
    
    -- actions+=/summon_infernal,if=(!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2)&equipped.132369
    if S.SummonInfernal:CooldownRemainsP() == 0 and HR.AoEON() and Cache.EnemiesCount[range] > 2 and not S.GrimoireOfSupremacy:IsAvailable() and I.WilfredsSigil:IsEquipped() and FutureShard() >= 1 then
      if HR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    
    -- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&equipped.132369
    if S.SummonDoomGuard:CooldownRemainsP() == 0 and not S.GrimoireOfSupremacy:IsAvailable() and (not HR.AoEON() or (HR.AoEON() and Cache.EnemiesCount[range] <= 2)) 
      and I.WilfredsSigil:IsEquipped() and FutureShard() >= 1 then
      if HR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end
    
    -- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
    if S.SummonDoomGuard:CooldownRemainsP() == 0 and not S.GrimoireOfSupremacy:IsAvailable() and (not HR.AoEON() or (HR.AoEON() and Cache.EnemiesCount[range] <= 2)) 
      and (Target:FilteredTimeToDie(">", 180) or Target:HealthPercentage() <= 20 or Target:FilteredTimeToDie("<", 30)) and FutureShard() >= 1 then
        if HR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end
    
    -- actions+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2
    if S.SummonInfernal:CooldownRemainsP() == 0 and HR.AoEON() and Cache.EnemiesCount[range] > 2 and not S.GrimoireOfSupremacy:IsAvailable() and FutureShard()  >= 1 then
      if HR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    
    -- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:CooldownRemainsP() == 0 and Cache.EnemiesCount[range] == 1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
      if HR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end
    
    -- actions+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:CooldownRemainsP() > 1 and Cache.EnemiesCount[range] == 1 and I.SindoreiSpite:IsEquipped() and S.SindoreiSpiteBuff:TimeSinceLastAppliedOnPlayer() >= 180 then
      if HR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    
    -- actions+=/berserking
    if S.Berserking:IsAvailable() and S.Berserking:IsCastable() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    
    -- actions+=/soul_harvest,if=!buff.soul_harvest.remains
    if S.SoulHarvest:IsAvailable() and S.SoulHarvest:IsCastable() and Player:BuffRemainsP(S.SoulHarvest) == 0 then
      if HR.Cast(S.SoulHarvest, Settings.Demonology.OffGCDasOffGCD.SoulHarvest) then return ""; end
    end
    
    -- actions+=/potion,name=prolonged_power,if=buff.soul_harvest.remains|target.time_to_die<=70|trinket.proc.any.react
    if Settings.Demonology.ShowPoPP and I.PotionOfProlongedPower:IsReady() and (Player:BuffRemainsP(S.SoulHarvest) > 0 or Target:FilteredTimeToDie("<=", 60)) then
      if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
    end
  end
  
  local function Sephuz ()
    -- ShadowFury
    --TODO : change level when iscontrollable is here
    if S.ShadowFury:IsAvailable() and S.ShadowFury:IsCastable() and Target:Level() < 103 and Settings.Demonology.Sephuz.ShadowFury then
      if HR.CastSuggested(S.ShadowFury) then return "Cast"; end
    end
    
    -- MortalCoil
    --TODO : change level when iscontrollable is here
    if S.MortalCoil:IsAvailable() and S.MortalCoil:IsCastable() and Target:Level() < 103 and Settings.Demonology.Sephuz.MortalCoil then
      if HR.CastSuggested(S.MortalCoil) then return "Cast"; end
    end
    
    -- Fear
    --TODO : change level when iscontrollable is here
    if S.Fear:IsAvailable() and S.Fear:IsCastable() and Target:Level() < 103 and Settings.Demonology.Sephuz.Fear then
      if HR.CastSuggested(S.Fear) then return "Cast"; end
    end
    
    -- AxeToss
    if S.AxeToss:IsAvailable() and S.AxeToss:IsCastable() and Target:IsCasting() and Target:IsInterruptible() and Settings.Demonology.Sephuz.AxeToss then
      if HR.CastSuggested(S.AxeToss) then return "Cast"; end
    end
  end

--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    HL.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    RefreshPetsTimers()
    
    -- Var update
    UpdateVars()
        
    -- TODO : add the possibility to choose a pet
    -- TODO : prepot
    -- TODO : remove aoeon
    
    -- Defensives
    if S.UnendingResolve:IsCastable() and Player:HealthPercentage() <= Settings.Demonology.UnendingResolveHP then
      if HR.Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return ""; end
    end
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonFelguard:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked() or not S.FelStorm:IsLearned()) or not IsPetInvoked()) and not S.GrimoireOfSupremacy:IsAvailable() and FutureShard() >= 1 then
      if HR.Cast(S.SummonFelguard, Settings.Demonology.GCDasOffGCD.SummonFelguard) then return ""; end
    end
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked(true) or not S.MeteorStrike:IsLearned()) or not IsPetInvoked(true)) and Cache.EnemiesCount[range] > 1 and FutureShard() >= 1 then
      if HR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return ""; end
    end
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked(true) or not S.ShadowLock:IsLearned()) or not IsPetInvoked(true)) and Cache.EnemiesCount[range] == 1 and FutureShard() >= 1 then
      if HR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return ""; end
    end
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      
      -- Opener
      if Everyone.TargetIsValid() then
        if IsPetInvoked() and S.DemonicEmpowerment:CooldownRemainsP() == 0 and DemonicEmpowermentDuration() <= S.DemonicEmpowerment:PandemicThreshold() then
          if HR.Cast(S.DemonicEmpowerment, Settings.Demonology.GCDasOffGCD.DemonicEmpowerment) then return ""; end
        end
        
        -- actions.precombat+=/demonbolt
        -- actions.precombat+=/shadow_bolt
        if Player:IsCasting(S.Demonbolt) or Player:IsCasting(S.ShadowBolt) then
          if HR.Cast(S.CallDreadStalkers) then return ""; end
        else
          if S.Demonbolt:IsAvailable() and S.Demonbolt:IsCastable() then
            if HR.Cast(S.Demonbolt) then return ""; end
          else
            if HR.Cast(S.ShadowBolt) then return ""; end
          end
        end
      end
      return;
    else
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
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:ManaP() >= S.Implosion:Cost() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (Player:Buff(S.GrimoireOfSynergyBuff) or S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:ManaP() >= S.Implosion:Cost() and Player:PrevGCDP(1, S.HandOfGuldan) and ((GetPetRemains("Wild Imp") <= 3 and Player:Buff(S.GrimoireOfSynergyBuff)) or (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2)) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/shadowflame,if=(debuff.shadowflame.stack>0&remains<action.shadow_bolt.cast_time+travel_time)&spell_targets.demonwrath<5
            if S.ShadowFlame:IsAvailable() and Target:DebuffStack(S.ShadowFlame) > 0 and Target:DebuffRemainsP(S.ShadowFlame) < S.ShadowBolt:TravelTime() and Cache.EnemiesCount[range] < 5 then
              if HR.Cast(S.ShadowFlame) then return ""; end
            end

            -- actions+=/call_dreadstalkers,if=((!talent.summon_darkglare.enabled|talent.power_trip.enabled)&(spell_targets.implosion<3|!talent.implosion.enabled))&!(soul_shard=5&buff.demonic_calling.remains)
            if S.CallDreadStalkers:CooldownRemainsP() == 0 and ((not S.SummonDarkGlare:IsAvailable() or not S.PowerTrip:IsAvailable()) and (Cache.EnemiesCount[range] < 3 or not S.Implosion:IsAvailable())) 
              and not (FutureShard() == 5 and Player:BuffRemainsP(S.DemonicCallingBuff) >= 0) and FutureShard() >= 2 and not Player:IsCasting(S.CallDreadStalkers) then
              if HR.Cast(S.CallDreadStalkers) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if Player:ManaP() >= S.Doom:Cost() and (not S.HandOfDoom:IsAvailable() and Target:TimeToDie() > S.Doom:BaseDuration() and Target:DebuffRefreshableCP(S.Doom))
              and not(var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) then
                if HR.Cast(S.Doom) then return ""; end
            end
            if HR.AoEON() and Cache.EnemiesCount[range] > 1 and Player:ManaP() >= S.Doom:Cost() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if (not S.HandOfDoom:IsAvailable() and Value:TimeToDie() > S.Doom:BaseDuration() and Value:DebuffRefreshableCP(S.Doom)) and not(var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Doom)) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
            
            -- actions+=/shadowflame,if=(charges=2&soul_shard<5)&spell_targets.demonwrath<5&!variable.no_de1
            if S.ShadowFlame:IsAvailable() and S.ShadowFlame:ChargesP() == 2 and FutureShard() < 5 and Cache.EnemiesCount[range] < 5 and not var_no_de1 then
              if HR.Cast(S.ShadowFlame) then return ""; end
            end
            
            -- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains&soul_shard<5&!prev_gcd.1.doom&!variable.no_de2
            if S.ShadowBolt:IsCastable() and Player:ManaP() >= S.ShadowBolt:Cost() and Player:Buff(S.ShadowyInspirationBuff) and FutureShard() < 5 and not Player:PrevGCDP(1, S.Doom) and not var_no_de2 then
              if HR.Cast(S.ShadowBolt) then return ""; end
            end
            
            -- actions+=/summon_darkglare,if=prev_gcd.1.hand_of_guldan|prev_gcd.1.call_dreadstalkers|talent.power_trip.enabled
            if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:CooldownRemainsP() == 0 and FutureShard() >= 1 and (Player:PrevGCDP(1, S.HandOfGuldan) or (Player:PrevGCDP(1, S.CallDreadStalkers) or Player:IsCasting(S.CallDreadStalkers)) or S.PowerTrip:IsAvailable()) then
              if HR.Cast(S.SummonDarkGlare) then return ""; end
            end
            
            -- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains>5&soul_shard<3
            if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:CooldownRemainsP() == 0 and FutureShard() >= 1 and S.CallDreadStalkers:CooldownRemainsP() > 5 and FutureShard() < 3 then
              if HR.Cast(S.SummonDarkGlare) then return ""; end
            end
            
            -- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains<=action.summon_darkglare.cast_time&(soul_shard>=3|soul_shard>=1&buff.demonic_calling.react)
            if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:CooldownRemainsP() == 0 and S.CallDreadStalkers:CooldownRemainsP() < S.SummonDarkGlare:CastTime() 
              and (FutureShard() >= 3 or (FutureShard() >= 1 and Player:BuffRemainsP(S.DemonicCallingBuff) >= 0)) then
                if HR.Cast(S.SummonDarkGlare) then return ""; end
            end
            
            -- actions+=/call_dreadstalkers,if=talent.summon_darkglare.enabled&(spell_targets.implosion<3|!talent.implosion.enabled)&(cooldown.summon_darkglare.remains>2|prev_gcd.1.summon_darkglare|cooldown.summon_darkglare.remains<=action.call_dreadstalkers.cast_time&soul_shard>=3|cooldown.summon_darkglare.remains<=action.call_dreadstalkers.cast_time&soul_shard>=1&buff.demonic_calling.react)
            if S.CallDreadStalkers:IsCastable() and FutureShard() >= 2 and S.SummonDarkGlare:IsAvailable() 
              and (Cache.EnemiesCount[range] < 3 or not S.Implosion:IsAvailable() or not HR.AoEON()) 
              and (S.SummonDarkGlare:CooldownRemainsP() > 2 or Player:PrevGCDP(1, S.SummonDarkGlare) or (S.SummonDarkGlare:CooldownRemainsP() <= S.CallDreadStalkers:CastTime() and FutureShard() >= 3) or (S.SummonDarkGlare:CooldownRemainsP() <= S.CallDreadStalkers:CastTime() and FutureShard() >= 1 and Player:BuffRemainsP(S.DemonicCallingBuff) >= 0)) and Player:IsCasting(S.CallDreadStalkers) then
                if HR.Cast(S.CallDreadStalkers) then return ""; end
            end
            
            -- actions+=/hand_of_guldan,if=soul_shard>=4&(((!(variable.no_de1|prev_gcd.1.hand_of_guldan)&(pet_count>=13&!talent.shadowy_inspiration.enabled|pet_count>=6&talent.shadowy_inspiration.enabled))|!variable.no_de2|soul_shard=5)&talent.power_trip.enabled)
            if S.HandOfGuldan:IsCastable() and FutureShard() >= 4 
              and (((not (var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) and ((HL.GuardiansTable.Pets and #HL.GuardiansTable.Pets > 12 and not S.ShadowyInspiration:IsAvailable()) or (HL.GuardiansTable.Pets and #HL.GuardiansTable.Pets > 5 and S.ShadowyInspiration:IsAvailable()))) or not var_no_de2 or FutureShard() == 5 ) and S.PowerTrip:IsAvailable()) then
                if HR.Cast(S.HandOfGuldan) then return ""; end
            end
            
            -- actions+=/hand_of_guldan,if=(soul_shard>=3&prev_gcd.1.call_dreadstalkers&!artifact.thalkiels_ascendance.rank)|soul_shard>=5|(soul_shard>=4&cooldown.summon_darkglare.remains>2)
            if S.HandOfGuldan:IsCastable() and (FutureShard() >= 3 and Player:PrevGCDP(1, S.CallDreadStalkers) and not(S.ThalkielsAscendance:ArtifactRank() or 0) == 0 or FutureShard() == 5 or (FutureShard() >= 4 and S.SummonDarkGlare:CooldownRemainsP() > 2)) then
              if HR.Cast(S.HandOfGuldan) then return ""; end
            end
            
            -- actions+=/demonic_empowerment,if=(((talent.power_trip.enabled&(!talent.implosion.enabled|spell_targets.demonwrath<=1))|!talent.implosion.enabled|(talent.implosion.enabled&!talent.soul_conduit.enabled&spell_targets.demonwrath<=3))&(wild_imp_no_de>3|prev_gcd.1.hand_of_guldan))|(prev_gcd.1.hand_of_guldan&wild_imp_no_de=0&wild_imp_remaining_duration<=0)|(prev_gcd.1.implosion&wild_imp_no_de>0)
            -- actions+=/demonic_empowerment,if=variable.no_de1|prev_gcd.1.hand_of_guldan
            if S.DemonicEmpowerment:IsCastable() and not Player:IsCasting(S.DemonicEmpowerment) and Player:ManaP() >= S.DemonicEmpowerment:Cost()
              and (((((S.PowerTrip:IsAvailable() and (S.Implosion:IsAvailable() or Cache.EnemiesCount[range] <= 1)) 
                  or not S.Implosion:IsAvailable() or (S.Implosion:IsAvailable() and not S.SoulConduit:IsAvailable() and Cache.EnemiesCount[range] <= 3)) 
                  and (GetNbNotBuffed("Wild Imp") >  3 or Player:PrevGCDP(1, S.HandOfGuldan))) or (Player:PrevGCDP(1, S.HandOfGuldan) and GetNbTotal("Wild Imp") == 0) 
                  or (Player:PrevGCDP(1, S.Implosion) and GetNbNotBuffed("Wild Imp") == 0)) 
                or (var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) 
                or ((S.ThalkielsAscendance:ArtifactRank() or 0) > 0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) 
                or IsCastingPet()) then
              if HR.Cast(S.DemonicEmpowerment) then return ""; end
            end

            -- actions+=/shadowflame,if=charges=2&spell_targets.demonwrath<5
            if S.ShadowFlame:IsAvailable() and S.ShadowFlame:ChargesP() == 2 and Cache.EnemiesCount[range] < 5 then
              if HR.Cast(S.ShadowFlame) then return ""; end
            end
            -- actions+=/thalkiels_consumption,if=(dreadstalker_remaining_duration>execute_time|talent.implosion.enabled&spell_targets.implosion>=3)&(wild_imp_count>3&dreadstalker_count<=2|wild_imp_count>5)&wild_imp_remaining_duration>execute_time
            if S.TalkielConsumption:IsAvailable() and S.TalkielConsumption:CooldownRemainsP() == 0 and not Player:IsCasting(S.TalkielConsumption) and (GetPetRemains("Dreadstalker") > S.TalkielConsumption:ExecuteTime() or (S.Implosion:IsAvailable() and Cache.EnemiesCount[range] >= 3)) and  ((GetNbTotal("Wild Imp") > 3 and GetNbTotal("Dreadstalker") <= 2) or GetNbTotal("Wild Imp") > 5) and GetPetRemains("Wild Imp") > S.TalkielConsumption:ExecuteTime() then
              if HR.Cast(S.TalkielConsumption) then return ""; end
            end
            
            -- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
            if Player:ManaPercentage() <= 15 or (Player:ManaPercentage() <= 65 and ((S.CallDreadStalkers:CooldownRemainsP() == 0 and FutureShard() >= 2) or (S.CallDreadStalkers:CooldownRemainsP() <= Player:GCD() and (S.SummonDoomGuard:CooldownRemainsP() == 0 or S.GrimoireFelguard:CooldownRemainsP() == 0) and FutureShard() >= 3)))then
              if HR.Cast(S.LifeTap) then return ""; end
            end
            
            -- actions+=/demonwrath,chain=1,interrupt=1,if=spell_targets.demonwrath>=3
            if S.DemonWrath:IsCastable() and Player:ManaP() >= S.DemonWrath:Cost() and HR.AoEON() and Cache.EnemiesCount[range] >= 3 then
              if HR.Cast(S.DemonWrath) then return ""; end
            end
            
            -- actions+=/demonbolt
            if S.Demonbolt:IsAvailable() and Player:ManaP() >= S.Demonbolt:Cost() and S.Demonbolt:IsCastable() then
              if HR.Cast(S.Demonbolt) then return ""; end
            end
            
            -- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains
            if not S.Demonbolt:IsAvailable() and Player:ManaP() >= S.ShadowBolt:Cost() and S.ShadowBolt:IsCastable() and Player:Buff(S.ShadowyInspirationBuff) then
              if HR.Cast(S.ShadowBolt) then return ""; end
            end

            -- actions+=/demonic_empowerment,if=artifact.thalkiels_ascendance.rank&talent.power_trip.enabled&!talent.demonbolt.enabled&talent.shadowy_inspiration.enabled
            if S.DemonicEmpowerment:IsCastable() and Player:ManaP() >= S.DemonicEmpowerment:Cost() and ((S.ThalkielsAscendance:ArtifactRank() or 0)>0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) and not Player:IsCasting(S.DemonicEmpowerment) then
              if HR.Cast(S.DemonicEmpowerment) then return ""; end
            end
            
            -- actions+=/shadow_bolt
            if S.ShadowBolt:IsCastable() and Player:ManaP() >= S.ShadowBolt:Cost() then
              if HR.Cast(S.ShadowBolt) then return ""; end
            end
            
            -- actions+=/life_tap
            if HR.Cast(S.LifeTap) then return""; end
          else --moving
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (Player:Buff(S.GrimoireOfSynergyBuff) or S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and ((GetPetRemains("Wild Imp") <= 3 and Player:Buff(S.GrimoireOfSynergyBuff)) or (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2)) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/shadowflame,if=(debuff.shadowflame.stack>0&remains<action.shadow_bolt.cast_time+travel_time)&spell_targets.demonwrath<5
            if S.ShadowFlame:IsAvailable() and Target:DebuffStack(S.ShadowFlame) > 0 and Target:DebuffRemainsP(S.ShadowFlame) < S.ShadowBolt:TravelTime() and Cache.EnemiesCount[range] < 5 then
              if HR.Cast(S.ShadowFlame) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if not HR.AoEON() and Player:ManaP() >= S.Doom:Cost() and (not S.HandOfDoom:IsAvailable() and Target:TimeToDie() > S.Doom:BaseDuration() and Target:DebuffRefreshableCP(S.Doom))
              and not(var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) then
                if HR.Cast(S.Doom) then return ""; end
            end
            if HR.AoEON() and Cache.EnemiesCount[range] > 1 and Player:ManaP() >= S.Doom:Cost() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if (not S.HandOfDoom:IsAvailable() and not Value:DebuffRefreshableCP(S.Doom)) and not(var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Doom)) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
            
            -- actions+=/shadowflame,if=(charges=2&soul_shard<5)&spell_targets.demonwrath<5&!variable.no_de1
            if S.ShadowFlame:IsAvailable() and S.ShadowFlame:ChargesP() == 2 and FutureShard() < 5 and Cache.EnemiesCount[range] < 5 and not var_no_de1 then
              if HR.Cast(S.ShadowFlame) then return ""; end
            end
            
            -- actions+=/summon_darkglare,if=prev_gcd.1.hand_of_guldan|prev_gcd.1.call_dreadstalkers|talent.power_trip.enabled
            if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:CooldownRemainsP() == 0 and FutureShard() >= 1 and (Player:PrevGCDP(1, S.HandOfGuldan) or Player:PrevGCDP(1, S.CallDreadStalkers) or S.PowerTrip:IsAvailable()) then
              if HR.Cast(S.SummonDarkGlare) then return ""; end
            end
            
            -- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains>5&soul_shard<3
            if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:CooldownRemainsP() == 0 and FutureShard() >= 1 and S.CallDreadStalkers:CooldownRemainsP() > 5 and FutureShard() < 3 then
              if HR.Cast(S.SummonDarkGlare) then return ""; end
            end
            
            -- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains<=action.summon_darkglare.cast_time&(soul_shard>=3|soul_shard>=1&buff.demonic_calling.react)
            if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:CooldownRemainsP() == 0 and S.CallDreadStalkers:CooldownRemainsP() < S.SummonDarkGlare:CastTime() 
              and (FutureShard() >= 3 or (FutureShard() >= 1 and Player:BuffRemainsP(S.DemonicCallingBuff) >= 0)) then
                if HR.Cast(S.SummonDarkGlare) then return ""; end
            end

            -- actions+=/shadowflame,if=charges=2&spell_targets.demonwrath<5
            if S.ShadowFlame:IsAvailable() and S.ShadowFlame:ChargesP() == 2 and Cache.EnemiesCount[range] < 5 then
              if HR.Cast(S.ShadowFlame) then return ""; end
            end
            
            -- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
            if Player:ManaPercentage() <= 15 or (Player:ManaPercentage() <= 65 and ((S.CallDreadStalkers:CooldownRemainsP() == 0 and FutureShard() >= 2) or (S.CallDreadStalkers:CooldownRemainsP() <= Player:GCD() and (S.SummonDoomGuard:CooldownRemainsP() == 0 or S.GrimoireFelguard:CooldownRemainsP() == 0) and FutureShard() >= 3)))then
              if HR.Cast(S.LifeTap) then return ""; end
            end
            
            -- actions+=/demonwrath,chain=1,interrupt=1,if=spell_targets.demonwrath>=3
            if S.DemonWrath:IsCastable() and Player:ManaP() >= S.DemonWrath:Cost() then
              if HR.Cast(S.DemonWrath) then return ""; end
            end

            -- actions+=/demonic_empowerment,if=artifact.thalkiels_ascendance.rank&talent.power_trip.enabled&!talent.demonbolt.enabled&talent.shadowy_inspiration.enabled
            if S.DemonicEmpowerment:IsCastable() and Player:ManaP() >= S.DemonicEmpowerment:Cost() and ((S.ThalkielsAscendance:ArtifactRank() or 0)>0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) and not Player:IsCasting(S.DemonicEmpowerment) then
              if HR.Cast(S.DemonicEmpowerment) then return ""; end
            end
            
            -- actions+=/life_tap
            if HR.Cast(S.LifeTap) then return""; end
          end
        else --not in range
          --Movement
          if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then	--static
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (Player:Buff(S.GrimoireOfSynergyBuff) or S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and ((GetPetRemains("Wild Imp") <= 3 and Player:Buff(S.GrimoireOfSynergyBuff)) or (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2)) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if HR.AoEON() and Cache.EnemiesCount[range] > 1 and Player:ManaP() >= S.Doom:Cost() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if (not S.HandOfDoom:IsAvailable() and not Value:DebuffRefreshableCP(S.Doom)) and not(var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Doom)) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
            
            -- actions+=/demonic_empowerment,if=(((talent.power_trip.enabled&(!talent.implosion.enabled|spell_targets.demonwrath<=1))|!talent.implosion.enabled|(talent.implosion.enabled&!talent.soul_conduit.enabled&spell_targets.demonwrath<=3))&(wild_imp_no_de>3|prev_gcd.1.hand_of_guldan))|(prev_gcd.1.hand_of_guldan&wild_imp_no_de=0&wild_imp_remaining_duration<=0)|(prev_gcd.1.implosion&wild_imp_no_de>0)
            -- actions+=/demonic_empowerment,if=variable.no_de1|prev_gcd.1.hand_of_guldan
            if S.DemonicEmpowerment:IsCastable() and not Player:IsCasting(S.DemonicEmpowerment) and Player:ManaP() >= S.DemonicEmpowerment:Cost()
              and (((((S.PowerTrip:IsAvailable() and (S.Implosion:IsAvailable() or Cache.EnemiesCount[range] <= 1)) 
                or not S.Implosion:IsAvailable() or (S.Implosion:IsAvailable() and not S.SoulConduit:IsAvailable() and Cache.EnemiesCount[range] <= 3)) 
                and (GetNbNotBuffed("Wild Imp") >  3 or Player:PrevGCDP(1, S.HandOfGuldan))) or (Player:PrevGCDP(1, S.HandOfGuldan) and GetNbTotal("Wild Imp") == 0) 
                or (Player:PrevGCDP(1, S.Implosion) and GetNbNotBuffed("Wild Imp") == 0)) or (var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) 
                or ((S.ThalkielsAscendance:ArtifactRank() or 0) > 0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) 
                or IsCastingPet()) then
              if HR.Cast(S.DemonicEmpowerment) then return ""; end
            end
            
            -- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
            if Player:ManaPercentage() <= 15 or (Player:ManaPercentage() <= 65 and ((S.CallDreadStalkers:CooldownRemainsP() == 0 and FutureShard() >= 2) or (S.CallDreadStalkers:CooldownRemainsP() <= Player:GCD() and (S.SummonDoomGuard:CooldownRemainsP() == 0 or S.GrimoireFelguard:CooldownRemainsP() == 0) and FutureShard() >= 3)))then
              if HR.Cast(S.LifeTap) then return ""; end
            end

            -- actions+=/demonic_empowerment,if=artifact.thalkiels_ascendance.rank&talent.power_trip.enabled&!talent.demonbolt.enabled&talent.shadowy_inspiration.enabled
            if S.DemonicEmpowerment:IsCastable() and Player:ManaP() >= S.DemonicEmpowerment:Cost() and ((S.ThalkielsAscendance:ArtifactRank() or 0)>0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) and not Player:IsCasting(S.DemonicEmpowerment) then
              if HR.Cast(S.DemonicEmpowerment) then return ""; end
            end
            
            -- actions+=/life_tap
            if HR.Cast(S.LifeTap) then return""; end
          else --moving
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (Player:Buff(S.GrimoireOfSynergyBuff) or S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and ((GetPetRemains("Wild Imp") <= 3 and Player:Buff(S.GrimoireOfSynergyBuff)) or (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2)) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if HR.AoEON() and Player:ManaP() >= S.Doom:Cost() and Cache.EnemiesCount[range] > 1 then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if (not S.HandOfDoom:IsAvailable() and not Value:DebuffRefreshableCP(S.Doom)) and not(var_no_de1 or Player:PrevGCDP(1, S.HandOfGuldan)) and Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.Doom)) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
            
            -- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
            -- actions+=/life_tap
            if HR.Cast(S.LifeTap) then return""; end
          end
        end
      end
    end
  end

  HR.SetAPL(266, APL);


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
-- actions.precombat+=/potion
-- actions.precombat+=/demonic_empowerment
-- actions.precombat+=/demonbolt
-- actions.precombat+=/shadow_bolt

-- # Executed every time the actor is available.
-- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
-- actions+=/variable,name=3min,value=doomguard_no_de>0|infernal_no_de>0
-- actions+=/variable,name=no_de1,value=dreadstalker_no_de>0|darkglare_no_de>0|doomguard_no_de>0|infernal_no_de>0|service_no_de>0
-- actions+=/variable,name=no_de2,value=(variable.3min&service_no_de>0)|(variable.3min&wild_imp_no_de>0)|(variable.3min&dreadstalker_no_de>0)|(service_no_de>0&dreadstalker_no_de>0)|(service_no_de>0&wild_imp_no_de>0)|(dreadstalker_no_de>0&wild_imp_no_de>0)|(prev_gcd.1.hand_of_guldan&variable.no_de1)
-- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
-- actions+=/shadowflame,if=(debuff.shadowflame.stack>0&remains<action.shadow_bolt.cast_time+travel_time)&spell_targets.demonwrath<5
-- actions+=/summon_infernal,if=(!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2)&equipped.132369
-- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&equipped.132369
-- actions+=/call_dreadstalkers,if=((!talent.summon_darkglare.enabled|talent.power_trip.enabled)&(spell_targets.implosion<3|!talent.implosion.enabled))&!(soul_shard=5&buff.demonic_calling.remains)
-- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
-- actions+=/shadowflame,if=(charges=2&soul_shard<5)&spell_targets.demonwrath<5&!variable.no_de1
-- actions+=/service_pet
-- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
-- actions+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2
-- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
-- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains&soul_shard<5&!prev_gcd.1.doom&!variable.no_de2
-- actions+=/summon_darkglare,if=prev_gcd.1.hand_of_guldan|prev_gcd.1.call_dreadstalkers|talent.power_trip.enabled
-- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains>5&soul_shard<3
-- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains<=action.summon_darkglare.cast_time&(soul_shard>=3|soul_shard>=1&buff.demonic_calling.react)
-- actions+=/call_dreadstalkers,if=talent.summon_darkglare.enabled&(spell_targets.implosion<3|!talent.implosion.enabled)&(cooldown.summon_darkglare.remains>2|prev_gcd.1.summon_darkglare|cooldown.summon_darkglare.remains<=action.call_dreadstalkers.cast_time&soul_shard>=3|cooldown.summon_darkglare.remains<=action.call_dreadstalkers.cast_time&soul_shard>=1&buff.demonic_calling.react)
-- actions+=/hand_of_guldan,if=soul_shard>=4&(((!(variable.no_de1|prev_gcd.1.hand_of_guldan)&(pet_count>=13&!talent.shadowy_inspiration.enabled|pet_count>=6&talent.shadowy_inspiration.enabled))|!variable.no_de2|soul_shard=5)&talent.power_trip.enabled)
-- actions+=/hand_of_guldan,if=(soul_shard>=3&prev_gcd.1.call_dreadstalkers&!artifact.thalkiels_ascendance.rank)|soul_shard>=5|(soul_shard>=4&cooldown.summon_darkglare.remains>2)
-- actions+=/demonic_empowerment,if=(((talent.power_trip.enabled&(!talent.implosion.enabled|spell_targets.demonwrath<=1))|!talent.implosion.enabled|(talent.implosion.enabled&!talent.soul_conduit.enabled&spell_targets.demonwrath<=3))&(wild_imp_no_de>3|prev_gcd.1.hand_of_guldan))|(prev_gcd.1.hand_of_guldan&wild_imp_no_de=0&wild_imp_remaining_duration<=0)|(prev_gcd.1.implosion&wild_imp_no_de>0)
-- actions+=/demonic_empowerment,if=variable.no_de1|prev_gcd.1.hand_of_guldan
-- actions+=/use_items
-- actions+=/berserking
-- actions+=/blood_fury
-- actions+=/soul_harvest,if=!buff.soul_harvest.remains
-- actions+=/potion,name=prolonged_power,if=buff.soul_harvest.remains|target.time_to_die<=70|trinket.proc.any.react
-- actions+=/shadowflame,if=charges=2&spell_targets.demonwrath<5
-- actions+=/thalkiels_consumption,if=(dreadstalker_remaining_duration>execute_time|talent.implosion.enabled&spell_targets.implosion>=3)&(wild_imp_count>3&dreadstalker_count<=2|wild_imp_count>5)&wild_imp_remaining_duration>execute_time
-- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
-- actions+=/demonwrath,chain=1,interrupt=1,if=spell_targets.demonwrath>=3
-- actions+=/demonwrath,moving=1,chain=1,interrupt=1
-- actions+=/demonbolt
-- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains
-- actions+=/demonic_empowerment,if=artifact.thalkiels_ascendance.rank&talent.power_trip.enabled&!talent.demonbolt.enabled&talent.shadowy_inspiration.enabled
-- actions+=/shadow_bolt
-- actions+=/life_tap

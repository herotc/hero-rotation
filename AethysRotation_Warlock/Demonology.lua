--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Pet = Unit.Pet;
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
    
    -- Pet abilities
    CauterizeMaster		= Spell(119905),--imp
    Suffering				  = Spell(119907),--voidwalker
    SpellLock				  = Spell(119910),--Dogi
    Whiplash				  = Spell(119909),--Bitch
    FelStorm				  = Spell(119914),--FelGuard
    ShadowLock				= Spell(171140),--doomguard
    MeteorStrike			= Spell(171152),--infernal
    
    -- Talents
    ShadowyInspiration  = Spell(196269),
    ShadowFlame         = Spell(205181),
    DemonicCalling      = Spell(205145),
    
    ImpendingDoom       = Spell(196270),
    ImprovedStalkers   = Spell(196272),
    Implosion           = Spell(196277),
    
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
    ThalkielsAscendance= Spell(238145),
	-- Defensive	
    
    -- Utility
    
    -- Legendaries
    
    -- Misc
    Concordance         = Spell(242586),
    DemonicCallingBuff  = Spell(205146),
    GrimoireOfSynergyBuff = Spell(171982),
    ShadowyInspirationBuff = Spell(196606),
    -- Macros
    
  };
  local S = Spell.Warlock.Demonology;
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Demonology = {
    -- Legendaries
    SindoreiSpite= Item(132379), --9 wrist
    WilfredsSigil= Item(132369), --11/12 finger
  };
  local I = Item.Warlock.Demonology;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P,T194P = AC.HasTier("T19")
  local T202P,T204P = AC.HasTier("T20")
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range=40
	-- BuffCount[x] = {nbBuffed, nbNotBuffed,nbBuffed+nbNotBuffed}
  local BuffCount={["All"]={},["Wild Imp"]={},["Dreadstalker"]={},["Doomguard"]={},["Infernal"]={},["DarkGlare"]={}}
  local var_3min, var_no_de1, var_no_de2
  
  local Consts={
    DoomBaseDuration = 15,
    DoomMaxDuration = 20,
    DemonicEmpowermentMaxDuration = 12,
    PetDuration={[55659]=12,[99737]=12,[98035]=12,[11859]=25,[89]=25,[103673]=12},
    PetList={[55659]="Wild Imp",[99737]="Wild Imp",[98035]="Dreadstalker",[11859]="Doomguard",[89]="Infernal",[103673]="DarkGlare"}
  }
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warlock.Commons,
    Demonology = AR.GUISettings.APL.Warlock.Demonology
  };


--- ======= ACTION LISTS =======
  local function IsPetInvoked(testBigPets)
		testBigPets = testBigPets or false
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or S.FelStorm:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
  end
  
  local function DemonicEmpowermentDuration()
    if not IsPetActive() then
      return 0
    end
    return Pet:BuffRemains(S.DemonicEmpowerment)
  end
  
  local function RefreshPetsTimers()
    if not AC.GuardiansTable.Pets then
      return
    end
    for key, Value in pairs(AC.GuardiansTable.Pets) do
      local duration=0
      if Consts.PetDuration[AC.GuardiansTable.Pets[key][2]]~=nil then
        duration=Consts.PetDuration[AC.GuardiansTable.Pets[key][2]]
      end
      if GetTime()-AC.GuardiansTable.Pets[key][3]>=duration then
        AC.GuardiansTable.Pets[key]=nil
      end
    end
  end
  
  local function GetPetRemains(PetType)
    if not PetType then
      return 0
    end
    local maxduration=0.0
    for key, Value in pairs(AC.GuardiansTable.Pets) do
      if AC.GuardiansTable.Pets[key][1]==PetType then
        if (Consts.PetDuration[AC.GuardiansTable.Pets[key][2]] - (GetTime() - AC.GuardiansTable.Pets[key][3])) > maxduration then
          maxduration=(Consts.PetDuration[AC.GuardiansTable.Pets[key][2]] - (GetTime() - AC.GuardiansTable.Pets[key][3]))
        end
      end
    end
    return maxduration
  end

  local function GetPetBuffed(PetType)
    PetType = PetType or false
    local countBuffed=0
    local countNotBuffed=0
    if not AC.GuardiansTable.Pets then
      return countBuffed,countNotBuffed
    end
    for key, Value in pairs(AC.GuardiansTable.Pets) do
      if not PetType or (PetType and AC.GuardiansTable.Pets[key][1]==PetType) then
        if AC.GuardiansTable.Pets[key][5] then
          countBuffed=countBuffed+1
        else
          countNotBuffed=countNotBuffed+1
        end
      end
    end
    return countBuffed,countNotBuffed
  end
  
  local function GetAllPetBuffed()
    local countBuffed=0
    local countNotBuffed=0
    
    for key, Value in pairs(BuffCount) do
      if key=="All" then
        countBuffed,countNotBuffed=GetPetBuffed()
        BuffCount[key]={countBuffed,countNotBuffed,countBuffed+countNotBuffed}
      else
        countBuffed,countNotBuffed=GetPetBuffed(key)
        BuffCount[key]={countBuffed,countNotBuffed,countBuffed+countNotBuffed}
      end
    end
  end
  
  local function GetFutureShard()
    local Shard=Player:SoulShards()
    if not Player:IsCasting() then
      return Shard
    else
      if Player:CastID()==S.CallDreadStalkers:ID() then
        return Shard-2
      elseif Player:CastID()==S.HandOfGuldan:ID() then
        return 0
      elseif Player:CastID()==S.SummonDoomGuard:ID() or Player:CastID()==S.SummonDoomGuardSuppremacy:ID() or Player:CastID()==S.SummonInfernal:ID() or Player:CastID()==S.SummonInfernalSuppremacy:ID() or Player:CastID()==S.GrimoireFelguard:ID() or Player:CastID()==S.SummonFelguard:ID() then
        return Shard-1
      elseif Player:CastID()==S.ShadowBolt:ID() or Player:CastID()==S.Demonbolt:ID() then
        if Shard==5 then
          return Shard
        else
          return Shard+1
        end
      else
        return Shard
      end
    end
  end
  
  local function IsCastingPet()
    if Player:IsCasting() and (Player:CastID()==S.CallDreadStalkers:ID() or Player:CastID()==S.HandOfGuldan:ID() or Player:CastID()==S.SummonDoomGuard:ID() or Player:CastID()==S.SummonInfernal:ID()) then
      return true
    end
  
    return false
  end
  
  local function UpdateVars()
    -- local var_3min, var_no_de1, var_no_de2
	-- actions+=/variable,name=3min,value=doomguard_no_de>0|infernal_no_de>0
	var_3min = (BuffCount["Doomguard"][3]>0 and BuffCount["Doomguard"][2]>0) or (BuffCount["Infernal"][3]>0 and BuffCount["Infernal"][2]>0)
	-- actions+=/variable,name=no_de1,value=dreadstalker_no_de>0|darkglare_no_de>0|doomguard_no_de>0|infernal_no_de>0|service_no_de>0
  -- print(BuffCount["DarkGlare"][1],BuffCount["DarkGlare"][2],BuffCount["DarkGlare"][3])
  -- print ((BuffCount["Dreadstalker"][3]>0 and BuffCount["Dreadstalker"][2]>0) , (BuffCount["DarkGlare"][3]>0 and BuffCount["DarkGlare"][2]>0) , (BuffCount["Doomguard"][3]>0 and BuffCount["Doomguard"][2]>0) , (BuffCount["Infernal"][3]>0 and BuffCount["Infernal"][2]>0) , (IsPetInvoked() and DemonicEmpowermentDuration()==0))
	var_no_de1 = (BuffCount["Dreadstalker"][3]>0 and BuffCount["Dreadstalker"][2]>0) or (BuffCount["DarkGlare"][3]>0 and BuffCount["DarkGlare"][2]>0) or (BuffCount["Doomguard"][3]>0 and BuffCount["Doomguard"][2]>0) or (BuffCount["Infernal"][3]>0 and BuffCount["Infernal"][2]>0) or (IsPetInvoked() and DemonicEmpowermentDuration()==0)
	-- print(var_no_de1)
  -- actions+=/variable,name=no_de2,value=(variable.3min&service_no_de>0)|(variable.3min&wild_imp_no_de>0)|(variable.3min&dreadstalker_no_de>0)|(service_no_de>0&dreadstalker_no_de>0)|(service_no_de>0&wild_imp_no_de>0)|(dreadstalker_no_de>0&wild_imp_no_de>0)|(prev_gcd.1.hand_of_guldan&variable.no_de1)
	var_no_de2 = (var_3min and (IsPetInvoked() and DemonicEmpowermentDuration()==0)) or (var_3min and (BuffCount["Wild Imp"][3]>0 and BuffCount["Wild Imp"][2]>0)) or (var_3min and (BuffCount["Dreadstalker"][3]>0 and BuffCount["Dreadstalker"][2]>0)) or ((IsPetInvoked() and DemonicEmpowermentDuration()==0) and (BuffCount["Dreadstalker"][3]>0 and BuffCount["Dreadstalker"][2]>0)) or ((IsPetInvoked() and DemonicEmpowermentDuration()==0) and (BuffCount["Wild Imp"][3]>0 and BuffCount["Wild Imp"][2]>0)) or ((BuffCount["Wild Imp"][3]>0 and BuffCount["Wild Imp"][2]>0) and (BuffCount["Dreadstalker"][3]>0 and BuffCount["Dreadstalker"][2]>0)) or (Player:PrevGCD(1,S.HandOfGuldan) and var_no_de1) 
  end

--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    RefreshPetsTimers()
    GetAllPetBuffed()
    UpdateVars()
    
    -- print("All : ".. BuffCount["All"][1].."/"..(BuffCount["All"][3]))
    -- print(Consts.PetList[55659].." : ".. BuffCount[Consts.PetList[55659]][1].."/"..(BuffCount[Consts.PetList[55659]][3]))
    -- print(Consts.PetList[98035].." : ".. BuffCount[Consts.PetList[98035]][1].."/"..(BuffCount[Consts.PetList[98035]][3]))
    -- print(Consts.PetList[11859].." : ".. BuffCount[Consts.PetList[11859]][1].."/"..(BuffCount[Consts.PetList[11859]][3]))
    -- print(Consts.PetList[89].." : ".. BuffCount[Consts.PetList[89]][1].."/"..(BuffCount[Consts.PetList[89]][3]))
    -- print(Consts.PetList[103673].." : ".. BuffCount[Consts.PetList[103673]][1].."/"..(BuffCount[Consts.PetList[103673]][3]))
    -- print(GetPetRemains(Consts.PetList[55659]))
    -- Defensives
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonFelguard:IsCastable() and not IsPetInvoked() and not S.GrimoireOfSupremacy:IsAvailable() and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonFelguard, Settings.Demonology.GCDasOffGCD.SummonFelguard) then return "Cast"; end
    end
    -- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
    if AR.AoEON() and S.GrimoireOfSupremacy:IsAvailable() and S.SummonInfernalSuppremacy:IsCastable() and not S.MeteorStrike:IsLearned() and Cache.EnemiesCount[range]>1 and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
    end
    -- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
    if S.GrimoireOfSupremacy:IsAvailable() and S.SummonDoomGuardSuppremacy:IsCastable() and not S.ShadowLock:IsLearned() and Cache.EnemiesCount[range]==1 and Player:SoulShards ()>=1 then
      if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
    end
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
		
      -- Opener
      if Everyone.TargetIsValid() then
        if IsPetInvoked() and S.DemonicEmpowerment:IsCastable() and DemonicEmpowermentDuration()<0.3*Consts.DemonicEmpowermentMaxDuration then
          if AR.Cast(S.DemonicEmpowerment, Settings.Demonology.GCDasOffGCD.DemonicEmpowerment) then return "Cast"; end
        end
        -- actions.precombat+=/call_dreadstalkers,if=!equipped.132369
        -- actions.precombat+=/demonbolt,if=equipped.132369
        -- actions.precombat+=/shadow_bolt,if=equipped.132369
        if not (I.WilfredsSigil:IsEquipped(11) or I.WilfredsSigil:IsEquipped(12)) then
          if S.CallDreadStalkers:IsCastable() and GetFutureShard()>=2 then
            if AR.Cast(S.CallDreadStalkers) then return "Cast"; end
          elseif GetFutureShard() < 2 and S.Demonbolt:IsAvailable() and S.Demonbolt:IsCastable() then
            if AR.Cast(S.Demonbolt) then return "Cast"; end
          elseif GetFutureShard() < 2 then
            if AR.Cast(S.ShadowBolt) then return "Cast"; end
          end
        else
          if S.Demonbolt:IsAvailable() and S.Demonbolt:IsCastable() then
            if AR.Cast(S.Demonbolt) then return "Cast"; end
          else
            if AR.Cast(S.ShadowBolt) then return "Cast"; end
          end
        end
        
        
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
		-- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
		if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and BuffCount["Wild Imp"][3]>0 and (GetPetRemains("Wild Imp")<=S.ShadowBolt:ExecuteTime() or (Player:IsCasting() and GetPetRemains("Wild Imp")<=(Player:CastRemains()+Player:GCD()+S.ShadowBolt:ExecuteTime()))) and (Player:Buff(S.GrimoireOfSynergyBuff) or S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (AR.AoEON() and Cache.EnemiesCount[range]>1)) or BuffCount["Wild Imp"][3]<=4) and not (Player:IsCasting() and (Player:CastRemains()+Player:GCD())>=GetPetRemains("Wild Imp")) then
			if AR.Cast(S.Implosion) then return "Cast"; end
		end
		
		-- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
		if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCD(1,S.HandOfGuldan) and ((GetPetRemains("Wild Imp")<=3 and Player:Buff(S.GrimoireOfSynergyBuff)) or (GetPetRemains("Wild Imp")<=4 and Cache.EnemiesCount[range]>2))  and not (Player:IsCasting() and (Player:CastRemains()+Player:GCD())>=GetPetRemains("Wild Imp")) then
			if AR.Cast(S.Implosion) then return "Cast"; end
		end
		
		-- actions+=/shadowflame,if=(debuff.shadowflame.stack>0&remains<action.shadow_bolt.cast_time+travel_time)&spell_targets.demonwrath<5
		if S.ShadowFlame:IsAvailable() and Target:DebuffStack(S.ShadowFlame)>0 and Target:DebuffRemains(S.ShadowFlame)< S.ShadowBolt:CastTime()+S.ShadowBolt:TravelTime() and Cache.EnemiesCount[range]<5 then
			if AR.Cast(S.ShadowFlame) then return "Cast"; end
		end
		
		-- actions+=/summon_infernal,if=(!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2)&equipped.132369
		if AR.CDsON() and S.SummonInfernal:IsCastable() and AR.AoEON() and Cache.EnemiesCount[range]>2 and not S.GrimoireOfSupremacy:IsAvailable() and (I.WilfredsSigil:IsEquipped(11) or I.WilfredsSigil:IsEquipped(12)) 
			and GetFutureShard()>=1 then
		  if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
		end
		
		-- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&equipped.132369
		if AR.CDsON() and S.SummonDoomGuard:IsCastable() and not S.GrimoireOfSupremacy:IsAvailable() and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range]<=2)) 
			and(I.WilfredsSigil:IsEquipped(11) or I.WilfredsSigil:IsEquipped(12)) and GetFutureShard()>=1 then
		  if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
		end

		-- actions+=/call_dreadstalkers,if=((!talent.summon_darkglare.enabled|talent.power_trip.enabled)&(spell_targets.implosion<3|!talent.implosion.enabled))&!(soul_shard=5&buff.demonic_calling.remains)
		if S.CallDreadStalkers:IsCastable() and ((not S.SummonDarkGlare:IsAvailable() or not S.PowerTrip:IsAvailable()) and (Cache.EnemiesCount[range]<3 or not S.Implosion:IsAvailable())) 
			and not (GetFutureShard()==5 and Player:Buff(S.DemonicCallingBuff)) and GetFutureShard()>=2 then
			if AR.Cast(S.CallDreadStalkers) then return "Cast"; end
		end
		
		-- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
		if AR.AoEON() and Cache.EnemiesCount[range]>1 then
			BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
			for _, Value in pairs(Cache.Enemies[range]) do
			  if (not S.HandOfDoom:IsAvailable() and Value:TimeToDie()>Consts.DoomBaseDuration and (not Value:Debuff(S.Doom) or Value:DebuffRemains(S.Doom) < Consts.DoomBaseDuration*0.3)) 
				and not(var_no_de1 or Player:PrevGCD(1,S.HandOfGuldan)) and BestUnitTTD<Value:TimeToDie() then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
			  end	
			end
			if BestUnit then
			  if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
			end
		end
		--mono
		if not AR.AoEON() and (not S.HandOfDoom:IsAvailable() and Target:TimeToDie()>Consts.DoomBaseDuration and (not Target:Debuff(S.Doom) or Value:DebuffRemains(S.Doom) < Consts.DoomBaseDuration*0.3)) 
			and not(var_no_de1 or Player:PrevGCD(1,S.HandOfGuldan)) then
				if AR.Cast(S.Doom) then return "Cast"; end
		end
		
		-- actions+=/shadowflame,if=(charges=2&soul_shard<5)&spell_targets.demonwrath<5&!variable.no_de1
		if S.ShadowFlame:IsAvailable() and S.ShadowFlame:Charges()==2 and GetFutureShard()<5 and Cache.EnemiesCount[range]<5 and not var_no_de1 then
			if AR.Cast(S.ShadowFlame) then return "Cast"; end
		end
		
		-- actions+=/summon_doomguard,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening<=2&(target.time_to_die>180|target.health.pct<=20|target.time_to_die<30)
		if AR.CDsON() and S.SummonDoomGuard:IsCastable() and not S.GrimoireOfSupremacy:IsAvailable() and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range]<=2)) 
			and (Target:TimeToDie()>180 or Target:HealthPercentage()<=20 or Target:TimeToDie()<30) and GetFutureShard()>=1 then
				if AR.Cast(S.SummonDoomGuard, Settings.Commons.GCDasOffGCD.SummonDoomGuard) then return "Cast"; end
		end
		
		-- actions+=/summon_infernal,if=!talent.grimoire_of_supremacy.enabled&spell_targets.infernal_awakening>2
		if AR.CDsON() and S.SummonInfernal:IsCastable() and AR.AoEON() and Cache.EnemiesCount[range]>2 and not S.GrimoireOfSupremacy:IsAvailable() and GetFutureShard()>=1 then
		  if AR.Cast(S.SummonInfernal, Settings.Commons.GCDasOffGCD.SummonInfernal) then return "Cast"; end
		end
		
		-- actions+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal=1&equipped.132379&!cooldown.sindorei_spite_icd.remains
		--todo
		
		-- actions+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&spell_targets.summon_infernal>1&equipped.132379&!cooldown.sindorei_spite_icd.remains
		--todo
		
		-- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains&soul_shard<5&!prev_gcd.1.doom&!variable.no_de2
		if S.ShadowBolt:IsCastable() and Player:Buff(S.ShadowyInspirationBuff) and GetFutureShard()<5 and not Player:PrevGCD(1,S.Doom) and not var_no_de2 then
			if AR.Cast(S.ShadowBolt) then return "Cast"; end
		end
		
		-- actions+=/summon_darkglare,if=prev_gcd.1.hand_of_guldan|prev_gcd.1.call_dreadstalkers|talent.power_trip.enabled
		if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:IsCastable() and GetFutureShard()>=1 and (Player:PrevGCD(1,S.HandOfGuldan) or Player:PrevGCD(1,S.CallDreadStalkers) or S.PowerTrip:IsAvailable()) then
			if AR.Cast(S.SummonDarkGlare) then return "Cast"; end
		end
		
		-- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains>5&soul_shard<3
		if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:IsCastable() and GetFutureShard()>=1 and S.CallDreadStalkers:Cooldown()>5 and GetFutureShard()<3 then
			if AR.Cast(S.SummonDarkGlare) then return "Cast"; end
		end
		
		-- actions+=/summon_darkglare,if=cooldown.call_dreadstalkers.remains<=action.summon_darkglare.cast_time&(soul_shard>=3|soul_shard>=1&buff.demonic_calling.react)
		if S.SummonDarkGlare:IsAvailable() and S.SummonDarkGlare:IsCastable() and GetFutureShard()>=1 and S.CallDreadStalkers:Cooldown()<S.SummonDarkGlare:CastTime() 
			and (GetFutureShard()>=3 or (GetFutureShard()>=1) and Player:Buff(S.DemonicCallingBuff)) then
				if AR.Cast(S.SummonDarkGlare) then return "Cast"; end
		end
		
		-- actions+=/call_dreadstalkers,if=talent.summon_darkglare.enabled&(spell_targets.implosion<3|!talent.implosion.enabled)&(cooldown.summon_darkglare.remains>2|prev_gcd.1.summon_darkglare|cooldown.summon_darkglare.remains<=action.call_dreadstalkers.cast_time&soul_shard>=3|cooldown.summon_darkglare.remains<=action.call_dreadstalkers.cast_time&soul_shard>=1&buff.demonic_calling.react)
		if S.CallDreadStalkers:IsCastable() and GetFutureShard()>=2 and S.SummonDarkGlare:IsAvailable() 
			and (Cache.EnemiesCount[range]<3 or not S.Implosion:IsAvailable() or not AR.AoEON()) 
			and (S.SummonDarkGlare:Cooldown()>2 or Player:PrevGCD(1,S.SummonDarkGlare) or (S.SummonDarkGlare:Cooldown()<=S.CallDreadStalkers:CastTime() and GetFutureShard()>=3) or (S.SummonDarkGlare:Cooldown()<=S.CallDreadStalkers:CastTime() and GetFutureShard()>=1 and Player:Buff(S.DemonicCallingBuff))) then
				if AR.Cast(S.CallDreadStalkers) then return "Cast"; end
		end
		

		-- actions+=/hand_of_guldan,if=soul_shard>=4&(((!(variable.no_de1|prev_gcd.1.hand_of_guldan)&(pet_count>=13&!talent.shadowy_inspiration.enabled|pet_count>=6&talent.shadowy_inspiration.enabled))|!variable.no_de2|soul_shard=5)&talent.power_trip.enabled)
		if S.HandOfGuldan:IsCastable() and GetFutureShard()>=4 
			and (((not (var_no_de1 or Player:PrevGCD(1,S.HandOfGuldan)) and ((AC.GuardiansTable.Pets and #AC.GuardiansTable.Pets>12 and not S.ShadowyInspiration:IsAvailable()) or (AC.GuardiansTable.Pets and #AC.GuardiansTable.Pets>5 and S.ShadowyInspiration:IsAvailable()))) or not var_no_de2 or GetFutureShard()==5 ) and S.PowerTrip:IsAvailable()) then
				if AR.Cast(S.HandOfGuldan) then return "Cast"; end
		end
		
		-- actions+=/hand_of_guldan,if=(soul_shard>=3&prev_gcd.1.call_dreadstalkers&!artifact.thalkiels_ascendance.rank)|soul_shard>=5|(soul_shard>=4&cooldown.summon_darkglare.remains>2)
    if S.HandOfGuldan:IsCastable() and 
			((GetFutureShard()>=3 and Player:PrevGCD(1,S.CallDreadStalkers) and not (S.ThalkielsAscendance:ArtifactRank() or 0)==0) or GetFutureShard()==5 or (GetFutureShard()>=4 and S.SummonDarkGlare:Cooldown()>2) ) then
			if AR.Cast(S.HandOfGuldan) then return "Cast"; end
		end
		
		-- actions+=/demonic_empowerment,if=(((talent.power_trip.enabled&(!talent.implosion.enabled|spell_targets.demonwrath<=1))|!talent.implosion.enabled|(talent.implosion.enabled&!talent.soul_conduit.enabled&spell_targets.demonwrath<=3))&(wild_imp_no_de>3|prev_gcd.1.hand_of_guldan))|(prev_gcd.1.hand_of_guldan&wild_imp_no_de=0&wild_imp_remaining_duration<=0)|(prev_gcd.1.implosion&wild_imp_no_de>0)
		-- actions+=/demonic_empowerment,if=variable.no_de1|prev_gcd.1.hand_of_guldan
    if S.DemonicEmpowerment:IsCastable() and not (Player:IsCasting() and Player:CastID() == S.DemonicEmpowerment:ID()) and (((((S.PowerTrip:IsAvailable() and (S.Implosion:IsAvailable() or Cache.EnemiesCount[range]<=1))or not S.Implosion:IsAvailable() or ( S.Implosion:IsAvailable() and not S.SoulConduit:IsAvailable() and Cache.EnemiesCount[range]<=3)) and (BuffCount["Wild Imp"][2]>3 or Player:PrevGCD(1,S.HandOfGuldan))) or (Player:PrevGCD(1,S.HandOfGuldan) and BuffCount["Wild Imp"][3]==0) or (Player:PrevGCD(1,S.Implosion) and BuffCount["Wild Imp"][2]==0)) or (var_no_de1 or Player:PrevGCD(1,S.HandOfGuldan)) or ((S.ThalkielsAscendance:ArtifactRank() or 0)>0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) or IsCastingPet()) then
      if AR.Cast(S.DemonicEmpowerment) then return "Cast"; end
		end
		
		-- actions+=/berserking
		if AR.CDsON() and S.Berserking:IsAvailable() and S.Berserking:IsCastable() then
			if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
		end
		
		-- actions+=/soul_harvest,if=!buff.soul_harvest.remains
		if AR.CDsON() and S.SoulHarvest:IsAvailable() and S.SoulHarvest:IsCastable() and not Player:Buff(S.SoulHarvest) then
			if AR.Cast(S.SoulHarvest, Settings.Destruction.OffGCDasOffGCD.SoulHarvest) then return "Cast"; end
		end
		
		-- actions+=/shadowflame,if=charges=2&spell_targets.demonwrath<5
		if S.ShadowFlame:IsAvailable() and S.ShadowFlame:Charges()==2 and Cache.EnemiesCount[range]<5 then
			if AR.Cast(S.ShadowFlame) then return "Cast"; end
		end
		
		-- actions+=/thalkiels_consumption,if=(dreadstalker_remaining_duration>execute_time | talent.implosion.enabled & spell_targets.implosion>=3) & wild_imp_count>3 & wild_imp_remaining_duration>execute_time
		if S.TalkielConsumption:IsAvailable() and S.TalkielConsumption:IsCastable() and not (Player:IsCasting() and Player:CastID()==S.TalkielConsumption:ID()) and (GetPetRemains("Dreadstalker")>S.TalkielConsumption:ExecuteTime() or (S.Implosion:IsAvailable() and Cache.EnemiesCount[range]>=3)) and  BuffCount["Wild Imp"][3]>3 and GetPetRemains("Wild Imp")>S.TalkielConsumption:ExecuteTime() then
			if AR.Cast(S.TalkielConsumption) then return "Cast"; end
		end
		
		-- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
		if Player:ManaPercentage()<=15 or (Player:ManaPercentage()<=65 and ( (S.CallDreadStalkers:Cooldown()<=0.75 and GetFutureShard()>=2) or (S.CallDreadStalkers:Cooldown()<=(Player:GCD()*2) and (S.SummonDoomGuard:Cooldown()<=0.75 or S.GrimoireFelguard:Cooldown()<=0.75) and GetFutureShard()>=3)))then
			if AR.Cast(S.LifeTap) then return "Cast"; end
		end
		
		-- actions+=/demonwrath,chain=1,interrupt=1,if=spell_targets.demonwrath>=3
		-- actions+=/demonwrath,moving=1,chain=1,interrupt=1
		if S.DemonWrath:IsCastable() and ((AR.AoEON() and Cache.EnemiesCount[range]>=3) or GetUnitSpeed("player") ~= 0) then
			if AR.Cast(S.DemonWrath) then return "Cast"; end
		end
		
		-- actions+=/demonbolt
		if S.Demonbolt:IsAvailable() and S.Demonbolt:IsCastable() then
			if AR.Cast(S.Demonbolt) then return "Cast"; end
		end
		
		-- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains
		if not S.Demonbolt:IsAvailable() and S.ShadowBolt:IsCastable() and Player:Buff(S.ShadowyInspirationBuff) then
			if AR.Cast(S.ShadowBolt) then return "Cast"; end
		end

    -- actions+=/demonic_empowerment,if=artifact.thalkiels_ascendance.rank&talent.power_trip.enabled&!talent.demonbolt.enabled&talent.shadowy_inspiration.enabled
    if S.DemonicEmpowerment:IsCastable() and ((S.ThalkielsAscendance:ArtifactRank() or 0)>0 and S.PowerTrip:IsAvailable() and not S.Demonbolt:IsAvailable() and S.ShadowyInspiration:IsAvailable()) and not (Player:IsCasting() and Player:CastID() == S.DemonicEmpowerment:ID()) then
      if AR.Cast(S.DemonicEmpowerment) then return "Cast"; end
		end
		
		-- actions+=/shadow_bolt
		if S.ShadowBolt:IsCastable() and Player:Mana()>S.ShadowBolt:Cost() then
			if AR.Cast(S.ShadowBolt) then return "Cast"; end
		end
		
		-- actions+=/life_tap
		if AR.Cast(S.LifeTap) then return"Cast"; end
    end
  end

  AR.SetAPL(266, APL);


--- ======= SIMC =======
--- Last Update: 12/06/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=whispered_pact
-- actions.precombat+=/food,type=azshari_salad
-- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&artifact.lord_of_flames.rank>0
-- actions.precombat+=/summon_infernal,if=talent.grimoire_of_supremacy.enabled&active_enemies>1
-- actions.precombat+=/summon_doomguard,if=talent.grimoire_of_supremacy.enabled&active_enemies=1&artifact.lord_of_flames.rank=0
-- actions.precombat+=/augmentation,type=defiled
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=prolonged_power
-- actions.precombat+=/demonic_empowerment
-- actions.precombat+=/call_dreadstalkers,if=!equipped.132369
-- actions.precombat+=/demonbolt,if=equipped.132369
-- actions.precombat+=/shadow_bolt,if=equipped.132369

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
-- actions+=/thalkiels_consumption,if=(dreadstalker_remaining_duration>execute_time|talent.implosion.enabled&spell_targets.implosion>=3)&wild_imp_count>3&wild_imp_remaining_duration>execute_time
-- actions+=/life_tap,if=mana.pct<=15|(mana.pct<=65&((cooldown.call_dreadstalkers.remains<=0.75&soul_shard>=2)|((cooldown.call_dreadstalkers.remains<gcd*2)&(cooldown.summon_doomguard.remains<=0.75|cooldown.service_pet.remains<=0.75)&soul_shard>=3)))
-- actions+=/demonwrath,chain=1,interrupt=1,if=spell_targets.demonwrath>=3
-- actions+=/demonwrath,moving=1,chain=1,interrupt=1
-- actions+=/demonbolt
-- actions+=/shadow_bolt,if=buff.shadowy_inspiration.remains
-- actions+=/demonic_empowerment,if=artifact.thalkiels_ascendance.rank&talent.power_trip.enabled&!talent.demonbolt.enabled&talent.shadowy_inspiration.enabled
-- actions+=/shadow_bolt
-- actions+=/life_tap

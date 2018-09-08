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
    ArcaneTorrent		= Spell(25046),
    Berserking			= Spell(26297),
    BloodFury			= Spell(20572),
    GiftoftheNaaru		= Spell(59547),
    Shadowmeld        	= Spell(58984),
    
    -- Abilities
    DrainLife 			= Spell(234153),
    SummonTyrant		= Spell(265187),
    SummonImp 			= Spell(688),
    SummonFelguard  	= Spell(30146),
    HandOfGuldan      	= Spell(105174),
    ShadowBolt        	= Spell(686),
	Demonbolt			= Spell(264178),
    CallDreadStalkers 	= Spell(104316),
    Fear 			    = Spell(5782),
	Implosion			= Spell(196277),
	Shadowfury			= Spell(30283),
    
    -- Pet abilities
    CauterizeMaster		= Spell(119905),--imp
    Suffering			= Spell(119907),--voidwalker
    SpellLock			= Spell(119910),--Dogi
    Whiplash			= Spell(119909),--Bitch
    AxeToss				= Spell(119914),--FelGuard
    FelStorm		    = Spell(89751),--FelGuard
    
    -- Talents
    Dreadlash			= Spell(264078),
    DemonicStrength     = Spell(267171),
    BilescourgeBombers  = Spell(267211),
    
    DemonicCalling      = Spell(205145),
    PowerSiphon 	    = Spell(264130),
    Doom                = Spell(265412),
    
    DemonSkin     		= Spell(219272),
    BurningRush			= Spell(111400),
    DarkPact  			= Spell(108416),
    
    FromTheShadows      = Spell(267170),
    SoulStrike          = Spell(264057),
    SummonVilefiend     = Spell(264119),
    
    Darkfury            = Spell(264874),
    MortalCoil        	= Spell(6789),
    DemonicCircle       = Spell(268358),
    
    InnerDemons         = Spell(267216),
    SoulConduit         = Spell(215941),
    GrimoireFelguard  	= Spell(111898),
	
	SacrificedSouls		= Spell(267214),
	DemonicConsumption	= Spell(267215),
	NetherPortal		= Spell(267217),
    
    -- Defensive	
    UnendingResolve 	= Spell(104773),
    
    -- Utility
        
    -- Misc
    DemonicCallingBuff  = Spell(205146),
	DemonicCoreBuff		= Spell(264173)
  };
  local S = Spell.Warlock.Demonology;
  
  -- Items
  if not Item.Warlock then Item.Warlock = {}; end
  Item.Warlock.Demonology = {
  };
  local I = Item.Warlock.Demonology;
  
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, DebuffRemains; -- Used for cycling
  local range = 40
	-- BuffCount[x] = {nbBuffed, nbNotBuffed, nbBuffed+nbNotBuffed}
  local BuffCount={["All"] = {}, ["Wild Imp"] = {}, ["Dreadstalker"] = {}, ["Vilefiend"] = {}, ["Demonic Tyrant"] = {}}
  local var_3min, var_no_de1, var_no_de2
  local PetsInfo = {
    [55659] = {"Wild Imp", 12},
    [99737] = {"Wild Imp", 12},
    [98035] = {"Dreadstalker", 12},
	[135816] = {"Vilefiend", 12},
	[135002] = {"Demonic Tyrant", 12},
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
		return S.Suffering:IsLearned() or S.SpellLock:IsLearned() or S.Whiplash:IsLearned() or S.CauterizeMaster:IsLearned() or S.AxeToss:IsLearned() or (testBigPets and (S.ShadowLock:IsLearned() or S.MeteorStrike:IsLearned()))
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
  
  -- Get the total number of pets
  local function GetNbTotal (PetType)
    return BuffCount[PetType][3] or 0
  end
  
  local PrevTimeDebug = nil
  -- Calculate future shard count
  local function FutureShard()
    local Shard = Player:SoulShards()
	if not Player:IsCasting() then
	  return Shard
	else
	  if Player:IsCasting(S.NetherPortal) then
	    return Shard - 3
	  elseif Player:IsCasting(S.CallDreadStalkers) then
	    return Shard - 2
	  elseif Player:IsCasting(S.SummonVilefiend) then
	    return Shard - 1
	  elseif Player:IsCasting(S.SummonFelguard) then
	    return Shard - 1
	  elseif Player:IsCasting(S.HandOfGuldan) then
	    if Shard > 3 then
		  return Shard - 3
		else
		  return 0
		end
	  elseif Player:IsCasting(S.Demonbolt) then
	    if Shard >= 4 then
		  return 5
		else
	      return Shard + 2
		end
	  elseif Player:IsCasting(S.Shadowbolt) then
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

  local function CDs ()
    -- actions+=/service_pet
    if S.GrimoireFelguard:IsAvailable() and S.GrimoireFelguard:CooldownRemainsP() == 0 and FutureShard() >= 1 then
      if HR.Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard) then return ""; end
    end
	
	-- Nether Portal
	if S.NetherPortal:IsCastable(40) and FutureShard() >= 3 then
	  if HR.Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return ""; end
	end
	
	-- Demonic Tyrant
	if S.SummonTyrant:IsCastable(40) then
	  if HR.Cast(S.SummonTyrant, Settings.Demonology.GCDasOffGCD.SummonTyrant) then return ""; end
	end
    
    -- actions+=/berserking
    if S.Berserking:IsAvailable() and S.Berserking:IsCastable() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
  end

--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    HL.GetEnemies(range);
    Everyone.AoEToggleEnemiesUpdate();
    RefreshPetsTimers()
    
    -- Defensives
    if S.UnendingResolve:IsCastable() and Player:HealthPercentage() <= Settings.Demonology.UnendingResolveHP then
      if HR.Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return ""; end
    end
    
    --Precombat
    -- actions.precombat+=/summon_pet,if=!talent.grimoire_of_supremacy.enabled&(!talent.grimoire_of_sacrifice.enabled|buff.demonic_power.down)
    if S.SummonFelguard:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked() or not S.AxeToss:IsLearned()) or not IsPetInvoked()) and FutureShard() >= 1 then
      if HR.Cast(S.SummonFelguard, Settings.Demonology.GCDasOffGCD.SummonFelguard) then return ""; end
    end
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      
      -- Opener
      if Everyone.TargetIsValid() then
        
        -- actions.precombat+=/demonbolt
        -- actions.precombat+=/shadow_bolt
        if (Player:IsCasting(S.Demonbolt) or Player:IsCasting(S.ShadowBolt)) and S.CallDreadStalkers:IsCastable() and (FutureShard() >= 2 or (FutureShard() >= 1 and Player:BuffRemainsP(S.DemonicCallingBuff) > 0) then
          if HR.Cast(S.CallDreadStalkers) then return ""; end
        else
          if S.Demonbolt:IsCastable() then
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
          if HR.CDsON() and (UnitClassification("target") == "worldboss" or UnitClassification("target") == "elite" or UnitLevel("target") == -1) then
            ShouldReturn = CDs();
            if ShouldReturn then return ShouldReturn; end
          end
          
          --Movement
          if not Player:IsMoving() then	-- static and in range
		  
			-- actions+=/demonbolt with Demonic Core and 3 or less shards
            if S.Demonbolt:IsCastable() and Player:BuffRemainsP(S.DemonicCoreBuff) > 0 and Player:ManaP() >= S.Demonbolt:Cost() and FutureShard() < 4 then
              if HR.Cast(S.Demonbolt) then return ""; end
            end
			
			-- Dreadstalkers with Demonic Calling
			if S.CallDreadStalkers:CooldownRemainsP() == 0 and Player:BuffRemainsP(S.DemonicCallingBuff) > 0 and not Player:IsCasting(S.CallDreadStalkers) and FutureShard() >= 1 then
              if HR.Cast(S.CallDreadStalkers) then return ""; end
            end
			
            -- actions+=/implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsCastable() and Player:ManaP() >= S.Implosion:Cost() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsCastable() and Player:ManaP() >= S.Implosion:Cost() and Player:PrevGCDP(1, S.HandOfGuldan) and (GetPetRemains("Wild Imp") <= 3 or (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2)) then
              if HR.Cast(S.Implosion) then return ""; end
            end

            -- actions+=/call_dreadstalkers,if=((!talent.summon_darkglare.enabled|talent.power_trip.enabled)&(spell_targets.implosion<3|!talent.implosion.enabled))&!(soul_shard=5&buff.demonic_calling.remains)
            if S.CallDreadStalkers:IsCastable() and FutureShard() >= 2 and not Player:IsCasting(S.CallDreadStalkers) then
              if HR.Cast(S.CallDreadStalkers) then return ""; end
            end
			
			-- Summon Vilefiend
			if S.SummonVilefiend:IsAvailable() and S.SummonVilefiend:IsCastable() and FutureShard() >= 1 and not Player:IsCasting(S.SummonVilefiend) then
			  if HR.Cast(S.SummonVilefiend) then return ""; end
			end
			
			-- Bilescourge Bombers
			if S.BilescourgeBombers:IsAvailable() and S.BilescourgeBombers:IsCastable() and FutureShard() >= 2 and not Player:IsCasting(S.BilescourgeBombers) then
			  if HR.Cast(S.BilescourgeBombers) then return ""; end
			end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if S.Doom:IsAvailable() and Player:ManaP() >= S.Doom:Cost() and Target:DebuffRemainsP(S.Doom) == 0 and Target:TimeToDie() > S.Doom:BaseDuration() and Cache.EnemiesCount[range] == 1 then
                if HR.Cast(S.Doom) then return ""; end
            end
			
            if HR.AoEON() and S.Doom:IsAvailable() and Cache.EnemiesCount[range] > 1 and Player:ManaP() >= S.Doom:Cost() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRemainsP(S.Doom) == 0 and Value:TimeToDie() > S.Doom:BaseDuration() then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
            
            -- actions+=/hand_of_guldan,if=(soul_shard>=3&prev_gcd.1.call_dreadstalkers&!artifact.thalkiels_ascendance.rank)|soul_shard>=5|(soul_shard>=4&cooldown.summon_darkglare.remains>2)
            if S.HandOfGuldan:IsCastable() and FutureShard() >= 3 then
              if HR.Cast(S.HandOfGuldan) then return ""; end
            end
			
			-- Soul Strike
			if S.SoulStrike:IsCastable(50) and FutureShard() < 5 then
			  if HR.Cast(S.SoulStrike) then return ""; end
			end
			
			-- Demonic Strength
			if S.DemonicStrength:IsCastable() then
			  if HR.Cast(S.DemonicStrength) then return ""; end
			end
            
            -- actions+=/shadow_bolt
            if S.ShadowBolt:IsCastable() and Player:ManaP() >= S.ShadowBolt:Cost() and FutureShard() < 5 then
              if HR.Cast(S.ShadowBolt) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if S.Doom:IsAvailable() and not HR.AoEON() and Player:ManaP() >= S.Doom:Cost() and Target:DebuffRemainsP(S.Doom) == 0 and Target:TimeToDie() > S.Doom:BaseDuration() then
                if HR.Cast(S.Doom) then return ""; end
            end
            if S.Doom:IsAvailable() and HR.AoEON() and Cache.EnemiesCount[range] > 1 and Player:ManaP() >= S.Doom:Cost() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRemainsP(S.Doom) == 0 and Value:TimeToDie() > S.Doom:BaseDuration() then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
		  else -- moving and in range
		    -- Bilescourge Bombers
			if S.BilescourgeBombers:IsAvailable() and S.BilescourgeBombers:IsCastable() and FutureShard() >= 2 then
			  if HR.Cast(S.BilescourgeBombers) then return ""; end
			end
			
			-- Soul Strike
			if S.SoulStrike:IsCastable(50) and FutureShard() < 5 then
			  if HR.Cast(S.SoulStrike) then return ""; end
			end
			
			-- Demonic Strength
			if S.DemonicStrength:IsCastable() then
			  if HR.Cast(S.DemonicStrength) then return ""; end
			end
			
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if S.Doom:IsAvailable() and HR.AoEON() and Player:ManaP() >= S.Doom:Cost() and Cache.EnemiesCount[range] > 1 then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRemainsP(S.Doom) == 0 and Value:TimeToDie() > S.Doom:BaseDuration() then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
			end
          end
        else -- not in range
          --Movement
          if not Player:IsMoving() then	-- static and not in range
		    -- Soul Strike
			if S.SoulStrike:IsCastable(50) and FutureShard() < 5 then
			  if HR.Cast(S.SoulStrike) then return ""; end
			end
			
			-- Demonic Strength
			if S.DemonicStrength:IsCastable() then
			  if HR.Cast(S.DemonicStrength) then return ""; end
			end
			
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if S.Doom:IsAvailable() and HR.AoEON() and Cache.EnemiesCount[range] > 1 and Player:ManaP() >= S.Doom:Cost() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRemainsP(S.Doom) == 0 and Value:TimeToDie() > S.Doom:BaseDuration() then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
          else -- moving and not in range
		  	-- Bilescourge Bombers
			if S.BilescourgeBombers:IsAvailable() and S.BilescourgeBombers:IsCastable() and FutureShard() >= 2 then
			  if HR.Cast(S.BilescourgeBombers) then return ""; end
			end
			
			-- Soul Strike
			if S.SoulStrike:IsCastable(50) and FutureShard() < 5 then
			  if HR.Cast(S.SoulStrike) then return ""; end
			end
			
			-- Demonic Strength
			if S.DemonicStrength:IsCastable() then
			  if HR.Cast(S.DemonicStrength) then return ""; end
			end
			
            -- actions=implosion,if=wild_imp_remaining_duration<=action.shadow_bolt.execute_time&(buff.demonic_synergy.remains|talent.soul_conduit.enabled|(!talent.soul_conduit.enabled&spell_targets.implosion>1)|wild_imp_count<=4)
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and GetNbTotal("Wild Imp") > 0 and GetPetRemains("Wild Imp") <= S.ShadowBolt:ExecuteTime() and (S.SoulConduit:IsAvailable() or (not S.SoulConduit:IsAvailable() and (HR.AoEON() and Cache.EnemiesCount[range] > 1)) or GetNbTotal("Wild Imp") <= 4) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/implosion,if=prev_gcd.1.hand_of_guldan&((wild_imp_remaining_duration<=3&buff.demonic_synergy.remains)|(wild_imp_remaining_duration<=4&spell_targets.implosion>2))
            if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and Player:PrevGCDP(1, S.HandOfGuldan) and (GetPetRemains("Wild Imp") <= 4 and Cache.EnemiesCount[range]>2) then
              if HR.Cast(S.Implosion) then return ""; end
            end
            
            -- actions+=/doom,cycle_targets=1,if=(!talent.hand_of_doom.enabled&target.time_to_die>duration&(!ticking|remains<duration*0.3))&!(variable.no_de1|prev_gcd.1.hand_of_guldan)
            if S.Doom:IsAvailable() and HR.AoEON() and Player:ManaP() >= S.Doom:Cost() and Cache.EnemiesCount[range] > 1 then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
              for _, Value in pairs(Cache.Enemies[range]) do
                if Value:DebuffRemainsP(S.Doom) == 0 and Value:TimeToDie() > S.Doom:BaseDuration() then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.Doom;
                end	
              end
              if BestUnit then
                if HR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
              end
            end
          end
        end
      end
    end
  end

  HR.SetAPL(266, APL);
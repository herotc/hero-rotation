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

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
local Everyone = HR.Commons.Everyone;
local Warlock = HR.Commons.Warlock;
-- Spells
if not Spell.Warlock then Spell.Warlock = {}; end
Spell.Warlock.Demonology = {
  -- Racials
  Berserking			= Spell(26297),
  BloodFury				= Spell(20572),
  Fireblood				= Spell(265221),

  -- Abilities
  DrainLife 			= Spell(234153),
  SummonTyrant			= Spell(265187),
  SummonImp 			= Spell(688),
  SummonFelguard  		= Spell(30146),
  HandOfGuldan      	= Spell(105174),
  ShadowBolt        	= Spell(686),
  Demonbolt				= Spell(264178),
  CallDreadStalkers 	= Spell(104316),
  Fear 			    	= Spell(5782),
  Implosion				= Spell(196277),
  Shadowfury			= Spell(30283),

  -- Pet abilities
  CauterizeMaster		= Spell(119905),--imp
  Suffering				= Spell(119907),--voidwalker
  SpellLock				= Spell(119910),--Dogi
  Whiplash				= Spell(119909),--Bitch
  AxeToss				= Spell(119914),--FelGuard
  FelStorm		    	= Spell(89751),--FelGuard

  -- Talents
  Dreadlash				= Spell(264078),
  DemonicStrength     	= Spell(267171),
  BilescourgeBombers  	= Spell(267211),

  DemonicCalling      	= Spell(205145),
  PowerSiphon 	    	= Spell(264130),
  Doom                	= Spell(265412),

  DemonSkin     		= Spell(219272),
  BurningRush			= Spell(111400),
  DarkPact  			= Spell(108416),

  FromTheShadows      	= Spell(267170),
  SoulStrike          	= Spell(264057),
  SummonVilefiend     	= Spell(264119),

  Darkfury            	= Spell(264874),
  MortalCoil        	= Spell(6789),
  DemonicCircle       	= Spell(268358),

  InnerDemons         	= Spell(267216),
  SoulConduit         	= Spell(215941),
  GrimoireFelguard  	= Spell(111898),

  SacrificedSouls		= Spell(267214),
  DemonicConsumption	= Spell(267215),
  NetherPortal			= Spell(267217),
  NetherPortalBuff      = Spell(267218),

  -- Defensive
  UnendingResolve 		= Spell(104773),

  -- Azerite
  ForbiddenKnowledge    = Spell(279666),

  -- Utility

  -- Misc
  DemonicCallingBuff  	= Spell(205146),
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

-- Calculate future shard count
local function FutureShard()
  local Shard = Player:SoulShards()
  if not Player:IsCasting() then
    return Shard
  else
    if Player:IsCasting(S.NetherPortal) then
      return Shard - 3
    elseif Player:IsCasting(S.CallDreadStalkers) and Player:BuffRemainsP(S.DemonicCallingBuff) == 0 then
      return Shard - 2
    elseif Player:IsCasting(S.CallDreadStalkers) and Player:BuffRemainsP(S.DemonicCallingBuff) > 0 then
      return Shard - 1
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
  -- Demonic Tyrant
  -- Remove once pet tracking is fixed
  if S.SummonTyrant:IsCastable(40) then
    if HR.Cast(S.SummonTyrant, Settings.Demonology.GCDasOffGCD.SummonTyrant) then return ""; end
  end

  -- actions+=/berserking
  if S.Berserking:IsAvailable() and S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
end

local function BuildRot ()
  -- actions.build_a_shard=demonbolt,if=azerite.forbidden_knowledge.enabled&buff.forbidden_knowledge.react&!buff.demonic_core.react&cooldown.summon_demonic_tyrant.remains>20
  if S.Demonbolt:IsCastable() and Player:BuffRemainsP(S.ForbiddenKnowledge) > 0
    and Player:BuffRemainsP(S.DemonicCoreBuff) == 0 and S.SummonTyrant:CooldownRemainsP() > 20 then
      if HR.Cast(S.Demonbolt) then return ""; end
  end
  -- actions.build_a_shard+=/soul_strike
  if S.SoulStrike:IsCastable() then
    if HR.Cast(S.SoulStrike) then return ""; end
  end
  -- actions.build_a_shard+=/shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if HR.Cast(S.ShadowBolt) then return ""; end
  end
end

local function NetherPortalActive ()
  -- actions.nether_portal_active=grimoire_felguard,if=cooldown.summon_demonic_tyrant.remains<13|!equipped.132369
  if S.GrimoireFelguard:IsCastable() and S.SummonTyrant:CooldownRemainsP() < 13 then
    if HR.Cast(S.GrimoireFelguard) then return ""; end
  end
  -- actions.nether_portal_active+=/summon_vilefiend,if=cooldown.summon_demonic_tyrant.remains>40|cooldown.summon_demonic_tyrant.remains<12
  if S.SummonVilefiend:IsCastable() and not Player:IsCasting(S.SummonVilefiend) and (S.SummonTyrant:CooldownRemainsP() > 40 or S.SummonTyrant:CooldownRemainsP() < 12) then
    if HR.Cast(S.SummonVilefiend) then return ""; end
  end
  -- actions.nether_portal_active+=/call_dreadstalkers,if=(cooldown.summon_demonic_tyrant.remains<9&buff.demonic_calling.remains)|(cooldown.summon_demonic_tyrant.remains<11&!buff.demonic_calling.remains)|cooldown.summon_demonic_tyrant.remains>14
  if S.CallDreadStalkers:IsCastable()
    and ( (S.SummonTyrant:CooldownRemainsP() < 9 and Player:BuffRemainsP(S.DemonicCallingBuff) > 0)
    or (S.SummonTyrant:CooldownRemainsP() < 11 and Player:BuffRemainsP(S.DemonicCallingBuff) == 0)
    or S.SummonTyrant:CooldownRemainsP() < 14 ) then
      if HR.Cast(S.CallDreadStalkers) then return ""; end
  end
  -- actions.nether_portal_active+=/call_action_list,name=build_a_shard,if=soul_shard=1&(cooldown.call_dreadstalkers.remains<action.shadow_bolt.cast_time|(talent.bilescourge_bombers.enabled&cooldown.bilescourge_bombers.remains<action.shadow_bolt.cast_time))
  ShouldReturn = BuildRot()
  if ShouldReturn then return ShouldReturn; end
  -- actions.nether_portal_active+=/hand_of_guldan,if=((cooldown.call_dreadstalkers.remains>action.demonbolt.cast_time)&(cooldown.call_dreadstalkers.remains>action.shadow_bolt.cast_time))&cooldown.nether_portal.remains>(160+action.hand_of_guldan.cast_time)
  if S.HandOfGuldan:IsCastable()
    and S.CallDreadStalkers:CooldownRemainsP() > S.Demonbolt:CastTime()
    and S.CallDreadStalkers:CooldownRemainsP() > S.ShadowBolt:CastTime()
    and S.NetherPortal:CooldownRemainsP() > S.HandOfGuldan:CastTime() + 160 then
      if HR.Cast(S.HandOfGuldan) then return ""; end
  end
  -- actions.nether_portal_active+=/summon_demonic_tyrant,if=buff.nether_portal.remains<10&soul_shard=0
  if S.SummonTyrant:IsCastable() and Player:BuffRemainsP(S.NetherPortalBuff) < 10 and FutureShard() == 0 then
    if HR.Cast(S.SummonTyrant) then return ""; end
  end
  -- actions.nether_portal_active+=/summon_demonic_tyrant,if=buff.nether_portal.remains<action.summon_demonic_tyrant.cast_time+5.5
  if S.SummonTyrant:IsCastable() and Player:BuffRemainsP(S.NetherPortalBuff) < S.SummonTyrant:CastTime() + 5.5 then
    if HR.Cast(S.SummonTyrant) then return ""; end
  end
  -- actions.nether_portal_active+=/demonbolt,if=buff.demonic_core.up
  if S.Demonbolt:IsCastable() and Player:BuffRemainsP(S.DemonicCoreBuff) > 0 then
    if HR.Cast(S.Demonbolt) then return ""; end
  end
  -- actions.nether_portal_active+=/call_action_list,name=build_a_shard
  ShouldReturn = BuildRot()
  if ShouldReturn then return ShouldReturn; end
end

local function NetherPortalBuild ()
  -- actions.nether_portal_building=nether_portal,if=soul_shard>=5&(!talent.power_siphon.enabled|buff.demonic_core.up)
  if S.NetherPortal:IsCastable() and FutureShard() == 5 and (not S.PowerSiphon:IsAvailable() or Player:BuffRemainsP(S.DemonicCoreBuff) > 0) then
    if HR.Cast(S.NetherPortal) then return ""; end
  end
  -- actions.nether_portal_building+=/call_dreadstalkers
  if S.CallDreadStalkers:IsCastable() then
    if HR.Cast(S.CallDreadStalkers) then return ""; end
  end
  -- actions.nether_portal_building+=/hand_of_guldan,if=cooldown.call_dreadstalkers.remains>18&soul_shard>=3
  if S.HandOfGuldan:IsCastable() and S.CallDreadStalkers:CooldownRemainsP() > 18 and FutureShard() >= 3 then
    if HR.Cast(S.HandOfGuldan) then return ""; end
  end
  -- actions.nether_portal_building+=/power_siphon,if=buff.wild_imps.stack>=2&buff.demonic_core.stack<=2&buff.demonic_power.down&soul_shard>=3
  if S.PowerSiphon:IsCastable() and Player:BuffStackP(S.DemonicCoreBuff) <= 2 and FutureShard() >= 3 then
    if HR.Cast(S.PowerSiphon) then return ""; end
  end
  -- actions.nether_portal_building+=/hand_of_guldan,if=soul_shard>=5
  if S.HandOfGuldan:IsCastable() and FutureShard() == 5 then
    if HR.Cast(S.HandOfGuldan) then return ""; end
  end
  -- actions.nether_portal_building+=/call_action_list,name=build_a_shard
  ShouldReturn = BuildRot()
  if ShouldReturn then return ShouldReturn; end
end

local function NetherPortalRot ()
  -- actions.nether_portal=call_action_list,name=nether_portal_building,if=cooldown.nether_portal.remains<20
  if S.NetherPortal:CooldownRemainsP() < 20 then
    ShouldReturn = NetherPortalBuild()
    if ShouldReturn then return ShouldReturn; end
  end
  -- actions.nether_portal+=/call_action_list,name=nether_portal_active,if=cooldown.nether_portal.remains>160
  if S.NetherPortal:CooldownRemainsP() > 160 then
    ShouldReturn = NetherPortalActive()
    if ShouldReturn then return ShouldReturn; end
  end
end

local function ImplosionRot ()
  -- actions.implosion=implosion,if=(buff.wild_imps.stack>=6&(soul_shard<3|prev_gcd.1.call_dreadstalkers|buff.wild_imps.stack>=9|prev_gcd.1.bilescourge_bombers|(!prev_gcd.1.hand_of_guldan&!prev_gcd.2.hand_of_guldan))&!prev_gcd.1.hand_of_guldan&!prev_gcd.2.hand_of_guldan&buff.demonic_power.down)|(time_to_die<3&buff.wild_imps.stack>0)|(prev_gcd.2.call_dreadstalkers&buff.wild_imps.stack>2&!talent.demonic_calling.enabled)
  -- actions.implosion+=/grimoire_felguard,if=cooldown.summon_demonic_tyrant.remains<13|!equipped.132369
  -- actions.implosion+=/call_dreadstalkers,if=(cooldown.summon_demonic_tyrant.remains<9&buff.demonic_calling.remains)|(cooldown.summon_demonic_tyrant.remains<11&!buff.demonic_calling.remains)|cooldown.summon_demonic_tyrant.remains>14
  -- actions.implosion+=/summon_demonic_tyrant
  -- actions.implosion+=/hand_of_guldan,if=soul_shard>=5
  -- actions.implosion+=/hand_of_guldan,if=soul_shard>=3&(((prev_gcd.2.hand_of_guldan|buff.wild_imps.stack>=3)&buff.wild_imps.stack<9)|cooldown.summon_demonic_tyrant.remains<=gcd*2|buff.demonic_power.remains>gcd*2)
  -- actions.implosion+=/demonbolt,if=prev_gcd.1.hand_of_guldan&soul_shard>=1&(buff.wild_imps.stack<=3|prev_gcd.3.hand_of_guldan)&soul_shard<4&buff.demonic_core.up
  -- actions.implosion+=/summon_vilefiend,if=(cooldown.summon_demonic_tyrant.remains>40&spell_targets.implosion<=2)|cooldown.summon_demonic_tyrant.remains<12
  -- actions.implosion+=/bilescourge_bombers,if=cooldown.summon_demonic_tyrant.remains>9
  -- actions.implosion+=/soul_strike,if=soul_shard<5&buff.demonic_core.stack<=2
  -- actions.implosion+=/demonbolt,if=soul_shard<=3&buff.demonic_core.up&(buff.demonic_core.stack>=3|buff.demonic_core.remains<=gcd*5.7)
  -- actions.implosion+=/doom,cycle_targets=1,max_cycle_targets=7,if=refreshable
  -- actions.implosion+=/call_action_list,name=build_a_shard
end

--- ======= MAIN =======
local function APL ()
  -- Unit Update
  HL.GetEnemies(range);
  Everyone.AoEToggleEnemiesUpdate();

  -- Defensives
  if S.UnendingResolve:IsCastable() and Player:HealthPercentage() <= Settings.Demonology.UnendingResolveHP then
    if HR.Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return ""; end
  end

  --Precombat
  -- actions.precombat+=/summon_pet
  if S.SummonFelguard:CooldownRemainsP() == 0 and (Warlock.PetReminder() and (not IsPetInvoked() or not S.AxeToss:IsLearned()) or not IsPetInvoked()) and FutureShard() >= 1 then
    if HR.Cast(S.SummonFelguard, Settings.Demonology.GCDasOffGCD.SummonFelguard) then return ""; end
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- actions.precombat=flask
    -- actions.precombat+=/food
    -- actions.precombat+=/augmentation
	-- actions.precombat+=/inner_demons,if=talent.inner_demons.enabled
    -- actions.precombat+=/snapshot_stats
    -- actions.precombat+=/potion

    -- Opener
    if Everyone.TargetIsValid() then
      -- actions.precombat+=/demonbolt
      if Player:IsCasting(S.Demonbolt) and S.CallDreadStalkers:IsCastable() then
        if HR.Cast(S.CallDreadStalkers) then return ""; end
      else
        if S.Demonbolt:IsCastable() then
          if HR.Cast(S.Demonbolt) then return ""; end
        end
      end
    end
    return;
  -- In Combat
  else
    if Everyone.TargetIsValid() then
      if Target:IsInRange(range) then
        -- Cds Usage
        if HR.CDsON() and (UnitClassification("target") == "worldboss" or UnitClassification("target") == "elite" or UnitLevel("target") == -1) then
          ShouldReturn = CDs();
          if ShouldReturn then return ShouldReturn; end
        end

        -- actions=potion,if=pet.demonic_tyrant.active|target.time_to_die<30
        -- actions+=/use_items,if=pet.demonic_tyrant.active|target.time_to_die<=15
        -- actions+=/berserking,if=pet.demonic_tyrant.active|target.time_to_die<=15
        if S.Berserking:IsCastable() and (S.SummonTyrant:CooldownRemainsP() > 75 or Target:TimeToDie() <= 15) then
          if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/blood_fury,if=pet.demonic_tyrant.active|target.time_to_die<=15
        if S.BloodFury:IsCastable() and (S.SummonTyrant:CooldownRemainsP() > 75 or Target:TimeToDie() <= 15) then
          if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/fireblood,if=pet.demonic_tyrant.active|target.time_to_die<=15
        if S.Fireblood:IsCastable() and (S.SummonTyrant:CooldownRemainsP() > 75 or Target:TimeToDie() <= 15) then
          if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/doom,if=!ticking&time_to_die>30&spell_targets.implosion<2
        if S.Doom:IsCastable() and Cache.EnemiesCount[range] < 2 and not Target:DebuffRemainsP(S.Doom) and Target:TimeToDie() > 30 then
          if HR.Cast(S.Doom) then return ""; end
        end
        -- actions+=/demonic_strength,if=(buff.wild_imps.stack<6|buff.demonic_power.up)|spell_targets.implosion<2
        if S.DemonicStrength:IsCastable() and Cache.EnemiesCount[range] < 2 then
          if HR.Cast(S.DemonicStrength) then return ""; end
        end
        -- actions+=/call_action_list,name=nether_portal,if=talent.nether_portal.enabled&spell_targets.implosion<=2
        if S.NetherPortal:IsCastable() and Cache.EnemiesCount[range] <= 2 then
          ShouldReturn = NetherPortalRot()
          if ShouldReturn then return ShouldReturn; end
        end
        -- actions+=/call_action_list,name=implosion,if=spell_targets.implosion>1
        if S.Implosion:IsCastable() and Cache.EnemiesCount[range] > 1 then
          ShouldReturn = ImplosionRot()
          if ShouldReturn then return ShouldReturn; end
        end
        -- actions+=/grimoire_felguard,if=cooldown.summon_demonic_tyrant.remains<13|!equipped.132369
        if S.GrimoireFelguard:IsCastable() and S.SummonTyrant:CooldownRemainsP() < 13 then
          if HR.Cast(S.GrimoireFelguard) then return ""; end
        end
        -- actions+=/summon_vilefiend,if=equipped.132369|cooldown.summon_demonic_tyrant.remains>40|cooldown.summon_demonic_tyrant.remains<12
        if S.SummonVilefiend:IsCastable() and not Player:IsCasting(S.SummonVilefiend) and (S.SummonTyrant:CooldownRemainsP() > 40 or S.SummonTyrant:CooldownRemainsP() < 12) then
          if HR.Cast(S.SummonVilefiend) then return ""; end
        end
        -- actions+=/call_dreadstalkers,if=equipped.132369|(cooldown.summon_demonic_tyrant.remains<9&buff.demonic_calling.remains)|(cooldown.summon_demonic_tyrant.remains<11&!buff.demonic_calling.remains)|cooldown.summon_demonic_tyrant.remains>14
        if S.CallDreadStalkers:IsCastable()
          and ( (S.SummonTyrant:CooldownRemainsP() < 9 and Player:BuffRemainsP(S.DemonicCallingBuff) > 0)
          or (S.SummonTyrant:CooldownRemainsP() < 11 and Player:BuffRemainsP(S.DemonicCallingBuff) == 0)
          or S.SummonTyrant:CooldownRemainsP() > 14 ) then
            if HR.Cast(S.CallDreadStalkers) then return ""; end
        end
        -- actions+=/summon_demonic_tyrant,if=equipped.132369|(buff.dreadstalkers.remains>cast_time&(buff.wild_imps.stack>=3|prev_gcd.1.hand_of_guldan)&(soul_shard<3|buff.dreadstalkers.remains<gcd*2.7|buff.grimoire_felguard.remains<gcd*2.7))
        -- actions+=/power_siphon,if=buff.wild_imps.stack>=2&buff.demonic_core.stack<=2&buff.demonic_power.down&spell_targets.implosion<2
        -- actions+=/doom,if=talent.doom.enabled&refreshable&time_to_die>(dot.doom.remains+30)
        if S.Doom:IsCastable() and Target:DebuffRefreshableCP(S.Doom) and Target:TimeToDie() > Target:DebuffRemainsP(S.Doom) + 30 then
          if HR.Cast(S.Doom) then return ""; end
        end
        -- actions+=/hand_of_guldan,if=soul_shard>=5|(soul_shard>=3&cooldown.call_dreadstalkers.remains>4&(!talent.summon_vilefiend.enabled|cooldown.summon_vilefiend.remains>3))
        if S.HandOfGuldan:IsCastable()
          and (FutureShard() == 5
          or (FutureShard() >= 3 and S.CallDreadStalkers:CooldownRemainsP() > 4
          and (not S.SummonVilefiend:IsAvailable() or S.SummonVilefiend:CooldownRemainsP() > 3))) then
            if HR.Cast(S.HandOfGuldan) then return ""; end
        end
        -- actions+=/soul_strike,if=soul_shard<5&buff.demonic_core.stack<=2
        if S.SoulStrike:IsCastable() and FutureShard() < 5 and Player:BuffStackP(S.DemonicCoreBuff) <= 2 then
          if HR.Cast(S.SoulStrike) then return ""; end
        end
        -- actions+=/demonbolt,if=soul_shard<=3&buff.demonic_core.up&((cooldown.summon_demonic_tyrant.remains<10|cooldown.summon_demonic_tyrant.remains>22)|buff.demonic_core.stack>=3|buff.demonic_core.remains<5|time_to_die<25)
        if S.Demonbolt:IsCastable() and FutureShard() <= 3 and Player:BuffRemainsP(S.DemonicCoreBuff) > 0
          and ( (S.SummonTyrant:CooldownRemainsP() < 10 or S.SummonTyrant:CooldownRemainsP() > 22)
          or Player:BuffStackP(S.DemonicCoreBuff) >= 3
          or Player:BuffRemainsP(S.DemonicCoreBuff) < 5
          or Target:TimeToDie() < 25 ) then
            if HR.Cast(S.Demonbolt) then return ""; end
        end
        -- actions+=/call_action_list,name=build_a_shard
        ShouldReturn = BuildRot()
        if ShouldReturn then return ShouldReturn; end
      end
    end
  end
end

HR.SetAPL(266, APL);

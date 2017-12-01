--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC      = AethysCore;
  local Cache   = AethysCache;
  local Unit    = AC.Unit;
  local Player  = Unit.Player;
  local Target  = Unit.Target;
  local Spell   = AC.Spell;
  local Item    = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- APL Local Vars
  -- Spells
  if not Spell.Priest then Spell.Priest = {}; end
  Spell.Priest.Shadow = {
    -- Racials
		ArcaneTorrent			= Spell(25046),
		Berserking				= Spell(26297),
		BloodFury				  = Spell(20572),
		GiftoftheNaaru		= Spell(59547),
		Shadowmeld        = Spell(58984),
    
    -- Abilities
		MindBlast				  = Spell(8092),
		MindFlay				  = Spell(15407),
		VoidEruption			= Spell(228260),
		VoidBolt				  = Spell(205448),
		ShadowWordDeath		= Spell(32379),
		ShadowWordPain		= Spell(589),
		VampiricTouch			= Spell(34914),
		Shadowfiend				= Spell(34433),
    
    -- Talents
		TwistOfFate				= Spell(109142),
		FortressOfTheMind	= Spell(193195),
		ShadowWordVoid		= Spell(205351),

    MindBomb		      = Spell(205369),
    
		LingeringInsanity	= Spell(199849),
		ReaperOfSouls			= Spell(199853),
		VoidRay					  = Spell(205371),

		Sanlayn					  = Spell(199855),
		AuspiciousSpirit	= Spell(155271),
		ShadowInsight			= Spell(162452),
		
		PowerInfusion			= Spell(10060),
		Misery					  = Spell(238558),
		Mindbender				= Spell(200174),
		
		LegacyOfTheVoid		= Spell(193225),
		ShadowCrash				= Spell(205385),
		SurrenderToMadness= Spell(193223),
    
    -- Artifact
		VoidTorrent				= Spell(205065),
		MassHysteria			= Spell(194378),
		SphereOfInsanity	= Spell(194179),
		UnleashTheShadows	= Spell(194093),
		FiendingDark			= Spell(238065),
		LashOfInsanity		= Spell(238137),
    ToThePain         = Spell(193644),
    TouchOfDarkness   = Spell(194007),
    VoidCorruption    = Spell(194016),
    
    -- Defensive
		Dispersion				= Spell(47585),
		Fade					    = Spell(586),
		PowerWordShield		= Spell(17),
    
    -- Utility
		VampiricEmbrace 	= Spell(15286),
    Silence           = Spell(15487),
    
    -- Legendaries
		ZeksExterminatus	= Spell(236546),
    SephuzBuff			  = Spell(208052),
    NorgannonsBuff    = Spell(236431),
    
    -- Misc
		Shadowform				= Spell(232698),
		VoidForm				  = Spell(194249),
    PotionOfProlongedPowerBuff = Spell(229206)
    
    -- Macros
    
  };
  local S = Spell.Priest.Shadow;
  local Everyone = AR.Commons.Everyone;
  
  -- Items
  if not Item.Priest then Item.Priest = {}; end
  Item.Priest.Shadow = {
    -- Legendaries
    MotherShahrazsSeduction	= Item(132437, {3}), --3
    MangazasMadness 			  = Item(132864, {6}), --6
    ZeksExterminatus 			  = Item(137100, {15}), --15
    SephuzSecret 			      = Item(132452, {11,12}), --11/12
    
    -- Potion
    PotionOfProlongedPower  = Item(142117)
  };
  local I = Item.Priest.Shadow;
  
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb; -- Used for cycling
  local v_cdtime, v_dotswpdpgcd, v_dotvtdpgcd, v_seardpgcd, v_s2msetuptime, v_actorsFightTimeMod, v_s2mcheck, v_hasteEval, v_eruptEval
  local var_init = false
  local var_calcCombat = false
  local range = 40
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    --Commons = AR.GUISettings.APL.Priest.Commons,
    Shadow = AR.GUISettings.APL.Priest.Shadow
  };

--- APL Action Lists (and Variables)
local function ExecuteRange ()
	if Player:Buff(S.ZeksExterminatus) then return 101; end
	return S.ReaperOfSouls:IsAvailable() and 35 or 20;
end

local function InsanityThreshold ()
	return S.LegacyOfTheVoid:IsAvailable() and 65 or 100;
end

local function FutureInsanity ()
  local Insanity = Player:Insanity()
  if not Player:IsCasting() then
    return Insanity
  else
    if Player:IsCasting(S.MindBlast) then
      return Insanity + (15 * (Player:Buff(S.PowerInfusion) and 1.25 or 1.0) * (S.FortressOfTheMind:IsAvailable() and 1.2 or 1.0))
    elseif Player:IsCasting(S.VampiricTouch) then
      return Insanity + (6 * (Player:Buff(S.PowerInfusion) and 1.25 or 1.0))
    elseif Player:IsCasting(S.ShadowWordVoid) then
      return Insanity + (25 * (Player:Buff(S.PowerInfusion) and 1.25 or 1.0))
    else
      return Insanity
    end
  end 
end

local function CurrentInsanityDrain ()
	if not Player:Buff(S.VoidForm) then return 0.0; end
	return 6 + 0.67 * (Player:BuffStack(S.VoidForm) - (2 * (I.MotherShahrazsSeduction:IsEquipped() and 1 or 0)) - AC.VTTime)
end

local function Var_ActorsFightTimeMod ()
  -- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10),if=time+target.time_to_die>450&time+target.time_to_die<600
  -- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5),if=time+target.time_to_die<=450
	if (AC.CombatTime() + Target:TimeToDie()) > 450 and (AC.CombatTime() + Target:TimeToDie()) < 600 then
		v_actorsFightTimeMod = -((-450 + (AC.CombatTime() + Target:TimeToDie())) / 10)
	elseif (AC.CombatTime() + Target:TimeToDie()) <= 450 then
		v_actorsFightTimeMod = ((450 - (AC.CombatTime() + Target:TimeToDie())) / 5)
  else
    v_actorsFightTimeMod = 0
	end
end

local function Var_S2MCheck ()
  -- actions.check+=/variable,op=set,name=s2mcheck,value=variable.s2msetup_time-(variable.actors_fight_time_mod*nonexecute_actors_pct)
  -- actions.check+=/variable,op=min,name=s2mcheck,value=180
  v_s2mcheck = v_s2msetuptime - v_actorsFightTimeMod
  if  180 < v_s2mcheck then
    v_s2mcheck = 180
  end
  return v_s2mcheck;
end

local function Var_CdTime ()
  -- actions.precombat+=/variable,name=cd_time,op=set,value=(12+(2-2*talent.mindbender.enabled*set_bonus.tier20_4pc)*set_bonus.tier19_2pc+(1-3*talent.mindbender.enabled*set_bonus.tier20_4pc)*equipped.mangazas_madness+(6+5*talent.mindbender.enabled)*set_bonus.tier20_4pc+2*artifact.lash_of_insanity.rank)
  v_cdtime = 12 + ((2 - 2 * (S.Mindbender:IsAvailable() and 1 or 0) * (AC.Tier20_4Pc and 1 or 0)) * (AC.Tier19_2Pc and 1 or 0)) + ((3 - 3 * (S.Mindbender:IsAvailable() and 1 or 0) * (AC.Tier20_4Pc and 1 or 0)) * (I.MangazasMadness:IsEquipped() and 1 or 0)) + ((6 + 5 * (S.Mindbender:IsAvailable() and 1 or 0)) * (AC.Tier20_4Pc and 1 or 0)) + (2 * (S.LashOfInsanity:ArtifactRank() or 0))
end



local function Var_DotSWPDPGCD ()
  -- actions.precombat+=/variable,name=dot_swp_dpgcd,op=set,value=36.5*1.2*(1+0.06*artifact.to_the_pain.rank)*(1+0.2+stat.mastery_rating%16000)*0.75
  v_dotswpdpgcd = 36.5 * 1.2 * (1 + 0.06 * (S.ToThePain:ArtifactRank() or 0)) * (1 + 0.2 + (Player:MasteryPct() / 16000)) * 0.75
end

local function Var_DotVTDPGCD ()
  -- actions.precombat+=/variable,name=dot_vt_dpgcd,op=set,value=68*1.2*(1+0.2*talent.sanlayn.enabled)*(1+0.05*artifact.touch_of_darkness.rank)*(1+0.2+stat.mastery_rating%16000)*0.5
  v_dotvtdpgcd = 68 * 1.2 * (1 + 0.2 * (S.Sanlayn:IsAvailable() and 1 or 0)) * (1 + 0.05 * (S.TouchOfDarkness:ArtifactRank() or 0)) * (1 + 0.2 + (Player:MasteryPct() / 16000)) * 0.5
end

local function Var_SearDPGCD ()
  -- actions.precombat+=/variable,name=sear_dpgcd,op=set,value=120*1.2*(1+0.05*artifact.void_corruption.rank)
  v_seardpgcd = 120 * 1.2 * (1 + 0.05 + (S.VoidCorruption:ArtifactRank() or 0))
end

local function Var_S2MSetupTime ()
  -- actions.precombat+=/variable,name=s2msetup_time,op=set,value=(0.8*(83+(20+20*talent.fortress_of_the_mind.enabled)*set_bonus.tier20_4pc-(5*talent.sanlayn.enabled)+(30+42*(desired_targets>1)+10*talent.lingering_insanity.enabled)*set_bonus.tier21_4pc*talent.auspicious_spirits.enabled+((33-13*set_bonus.tier20_4pc)*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*equipped.mangazas_madness+(raw_haste_pct*10*(1+0.7*set_bonus.tier20_4pc))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled)))),if=talent.surrender_to_madness.enabled
  if (S.SurrenderToMadness:IsAvailable()) then
    v_s2msetuptime = 0.8 * (83 
    + ((20 + 20 * (S.FortressOfTheMind:IsAvailable() and 1 or 0)) * (AC.Tier20_4Pc and 1 or 0))
    - (5 * (S.Sanlayn:IsAvailable() and 1 or 0))
    + ((30 + 42 * ((Cache.EnemiesCount[range]>1) and 1 or 0) + 10 * (S.Sanlayn:IsAvailable() and 1 or 0)) * (AC.Tier21_4Pc and 1 or 0) * (S.AuspiciousSpirit:IsAvailable() and 1 or 0))
    + ((33 - 13 * (AC.Tier20_4Pc and 1 or 0)) * (S.ReaperOfSouls:IsAvailable() and 1 or 0))
    + (4 * (AC.Tier19_2Pc and 1 or 0))
    + (8 * (I.MangazasMadness:IsEquipped() and 1 or 0))
    + (Player:HastePct() * 10 * (1 + 0.7 * (AC.Tier20_4Pc and 1 or 0)) * (2 + (0.8 * (AC.Tier19_2Pc and 1 or 0)) + (1 * (S.ReaperOfSouls:IsAvailable() and 1 or 0)) + (2 * (S.MassHysteria:ArtifactRank() or 0)) - (1 * (S.Sanlayn:IsAvailable() and 1 or 0)))))
  else
    v_s2msetuptime = 0
  end 
end

local function Var_HasteEval ()
-- actions.precombat+=/variable,name=haste_eval,op=set,value=(raw_haste_pct-0.3)*(10+10*equipped.mangazas_madness+5*talent.fortress_of_the_mind.enabled)
-- actions.precombat+=/variable,name=haste_eval,op=max,value=0
  v_hasteEval = ((Player:HastePct() / 100) - 0.3) * (10 + 10 * (I.MangazasMadness:IsEquipped() and 1 or 0) + 5 * (S.FortressOfTheMind:IsAvailable() and 1 or 0))
  
  if v_hasteEval < 0 then
    v_hasteEval = 0
  end
end

local function Var_EruptEval ()
  -- actions.precombat+=/variable,name=erupt_eval,op=set,value=26+1*talent.fortress_of_the_mind.enabled-4*talent.Sanlayn.enabled-3*talent.Shadowy_insight.enabled+variable.haste_eval*1.5
  v_eruptEval = 26 + 1 * (S.FortressOfTheMind:IsAvailable() and 1 or 0) - 4 * (S.Sanlayn:IsAvailable() and 1 or 0) - 3 * (S.ShadowInsight:IsAvailable() and 1 or 0) + v_hasteEval * 1.5
end

--One time cal vars
local function VarInit ()
  if not var_init or (AC.CombatTime() > 0 and not var_calcCombat) then
    Var_CdTime()
    Var_DotSWPDPGCD()
    Var_DotVTDPGCD()
    Var_SearDPGCD()
    Var_S2MSetupTime()
    Var_HasteEval()
    Var_EruptEval()
    var_init=true
    var_calcCombat=true
  end
end

--When to S2M calc
local function VarCalc ()
  if (S.SurrenderToMadness:IsAvailable() and not Player:Buff(S.SurrenderToMadness)) then
    Var_ActorsFightTimeMod()
    Var_S2MCheck()
  end
end

--Calls to cooldown
local function CDs ()
	--Power Infusion
  -- actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.value>=(v_cdtime+5 * (Player:HasHeroism() and 1 or 0) *(1+1 * (AC.Tier20_4Pc and 1 or 0)))
	if Player:Buff(S.VoidForm) and S.PowerInfusion:IsAvailable() and S.PowerInfusion:IsCastable() and not Player:Buff(S.SurrenderToMadness)
    and CurrentInsanityDrain() >= (v_cdtime + 5 * (Player:HasHeroism() and 1 or 0) * (1 + 1 * (AC.Tier20_4Pc and 1 or 0)))
    and (not S.SurrenderToMadness:IsAvailable() or (S.SurrenderToMadness:IsAvailable() and Target:TimeToDie() > v_s2mcheck - CurrentInsanityDrain() + 61)) then
      if AR.Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return ""; end
	end
  -- actions.s2m+=/power_infusion,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)|target.time_to_die<=30
  if Player:Buff(S.VoidForm) and S.PowerInfusion:IsAvailable() and S.PowerInfusion:IsCastable() and Player:Buff(S.SurrenderToMadness)
    and ((S.ShadowWordDeath:ChargesP() == 0 and Player:BuffStack(S.VoidForm) > (45 + 25 * (AC.Tier20_4Pc and 1 or 0))) or Target:TimeToDie() <= 30) then
      if AR.Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return ""; end
  end 

	--SF
	-- actions.vf+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	-- actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	if Player:Buff(S.VoidForm) and not S.Mindbender:IsAvailable() and S.Shadowfiend:IsCastable() 
    and Player:BuffStack(S.VoidForm) > (15 + Settings.Shadow.MindbenderUsage)  then
      if AR.Cast(S.Shadowfiend, Settings.Shadow.GCDasOffGCD.Shadowfiend) then return ""; end
	end
  
  --Mindbender
  -- actions.vf+=/mindbender,if=buff.insanity_drain_stacks.value>=(variable.cd_time+(variable.haste_eval*!set_bonus.tier20_4pc)-(3*set_bonus.tier20_4pc*(raid_event.movement.in<15)*((active_enemies-(raid_event.adds.count*(raid_event.adds.remains>0)))=1))+(5-3*set_bonus.tier20_4pc)*buff.bloodlust.up+2*talent.fortress_of_the_mind.enabled*set_bonus.tier20_4pc)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-buff.insanity_drain_stacks.value))
  if Player:Buff(S.VoidForm) and S.Mindbender:IsAvailable() and S.Mindbender:IsCastable() and not Player:Buff(S.SurrenderToMadness)
    and CurrentInsanityDrain() >= (v_cdtime + (v_hasteEval * (AC.Tier20_4Pc and 0 or 1)) - (3 * (AC.Tier20_4Pc and 1 or 0) + (5 - 3 * (AC.Tier20_4Pc and 1 or 0)) * (Player:HasHeroism() and 1 or 0) + 2 * (S.FortressOfTheMind:IsAvailable() and 1 or 0) * (AC.Tier20_4Pc and 1 or 0)) + Settings.Shadow.MindbenderUsage)
    and (not S.SurrenderToMadness:IsAvailable() or (S.SurrenderToMadness:IsAvailable() and Target:TimeToDie() > v_s2mcheck - CurrentInsanityDrain())) then 
      if AR.Cast(S.Mindbender, Settings.Shadow.GCDasOffGCD.Mindbender) then return ""; end
  end
  -- actions.s2m+=/mindbender,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)
  if Player:Buff(S.VoidForm) and S.Mindbender:IsAvailable() and S.Mindbender:IsCastable() and Player:Buff(S.SurrenderToMadness)
    and S.ShadowWordDeath:ChargesP() == 0 and Player:BuffStack(S.VoidForm) > (45 + 25 * (AC.Tier20_4Pc and 1 or 0) + Settings.Shadow.MindbenderUsage) then
      if AR.Cast(S.Mindbender, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return ""; end
  end 

	--Berserking
  -- actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.value<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
	if Player:Buff(S.VoidForm) and S.Berserking:IsAvailable() and S.Berserking:IsCastable() and not Player:Buff(S.SurrenderToMadness) 
    and Player:BuffStack(S.VoidForm) >= 10 and CurrentInsanityDrain() <= 20 
    and (not S.SurrenderToMadness:IsAvailable() or (S.SurrenderToMadness:IsAvailable() and Target:TimeToDie() > v_s2mcheck - CurrentInsanityDrain() + 60))then
      if AR.Cast(S.Berserking, Settings.Shadow.OffGCDasOffGCD.Racials) then return ""; end
	end
	-- actions.s2m+=/berserking,if=buff.voidform.stack>=65
  if Player:Buff(S.VoidForm) and S.Berserking:IsAvailable() and S.Berserking:IsCastable() and Player:Buff(S.SurrenderToMadness) 
    and Player:BuffStack(S.VoidForm) >= 65 then
      if AR.Cast(S.Berserking, Settings.Shadow.OffGCDasOffGCD.Racials) then return ""; end
	end
	
  --Surrender To Madness
  -- actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
  -- actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.value)
	if not Player:Buff(S.VoidForm) and S.SurrenderToMadness:IsAvailable() and S.SurrenderToMadness:IsCastable()
    and Target:TimeToDie() <= v_s2mcheck then
      if AR.Cast(S.SurrenderToMadness, Settings.Shadow.OffGCDasOffGCD.SurrenderToMadness) then return ""; end
  end
  if Player:Buff(S.VoidForm) and S.SurrenderToMadness:IsAvailable() and S.SurrenderToMadness:IsCastable() and FutureInsanity() >= 25 
    and (S.VoidBolt:IsCastable() or S.VoidTorrent:IsCastable() or S.ShadowWordDeath:IsCastable() or Player:Buff(S.ShadowInsight))
    and Target:TimeToDie() <= (v_s2mcheck - CurrentInsanityDrain()) then
      if AR.Cast(S.SurrenderToMadness, Settings.Shadow.OffGCDasOffGCD.SurrenderToMadness) then return ""; end
  end
  
	--Arcane Torrent
  -- actions.vf+=/arcane_torrent,if=buff.insanity_drain_stacks.value>=20&(insanity-(current_insanity_drain*gcd.max)+15)<100
  if Player:Buff(S.VoidForm) and S.ArcaneTorrent:IsAvailable() and S.ArcaneTorrent:IsCastable() and not Player:Buff(S.SurrenderToMadness) 
    and CurrentInsanityDrain() >= 20 and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + 15) < 100 then
    if AR.Cast(S.ArcaneTorrent, Settings.Shadow.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- actions.s2m+=/arcane_torrent,if=buff.insanity_drain_stacks.value>=65& (insanity-(current_insanity_drain*gcd.max)+30)<100
  if Player:Buff(S.VoidForm) and S.ArcaneTorrent:IsAvailable() and S.ArcaneTorrent:IsCastable() and Player:Buff(S.SurrenderToMadness) 
    and CurrentInsanityDrain() >= 65 and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + 30) < 100 then
      if AR.Cast(S.ArcaneTorrent, Settings.Shadow.OffGCDasOffGCD.Racials) then return ""; end
	end

  --Potion of Prolonged Power
  -- actions=potion,if=buff.bloodlust.react|target.time_to_die<=80|(target.health.pct<35&cooldown.power_infusion.remains<30)
  if Settings.Shadow.ShowPoPP and I.PotionOfProlongedPower:IsReady() 
    and (Player:HasHeroism() or Target:TimeToDie() <= 80 or (Target:HealthPercentage() < 35 and S.PowerInfusion:IsAvailable() and S.PowerInfusion:CooldownRemains() < 30)) then
      if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
  end
end

--S2M rotation
local function s2m ()
  --Void Torrent prediction
	if Player:IsCasting(S.VoidEruption) and S.VoidTorrent:CooldownRemainsP() == 0 then
		if AR.Cast(S.VoidTorrent) then return ""; end
	end

  -- actions.s2m=silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up,cycle_targets=1
  if S.Silence:IsCastable() and I.SephuzSecret:IsEquipped() and Target:IsCasting() and Target:IsInterruptible() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 and CurrentInsanityDrain() > 10 then
    if AR.CastSuggested(S.Silence) then return ""; end
  end
  if S.Silence:IsCastable() and I.SephuzSecret:IsEquipped() and Cache.EnemiesCount[range] > 1 and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 then
    BestUnit, BestUnitSpellToCast = nil, nil;
    for Key, Value in pairs(Cache.Enemies[range]) do
      if Value:IsCasting() and Value:IsInterruptible() then
          BestUnit, BestUnitSpellToCast = Value, S.Silence;
          break
      end	
    end
    if BestUnit then
      if AR.CastSuggested(BestUnitSpellToCast) then return ""; end
    end
  end
  
  -- actions.s2m+=/void_bolt,if=buff.insanity_drain_stacks.value<6&set_bonus.tier19_4pc
  if S.VoidBolt:IsCastable() and CurrentInsanityDrain() < 6 and AC.Tier19_4Pc then
    if AR.Cast(S.VoidBolt) then return ""; end
  end 
  
  -- actions.s2m+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up,cycle_targets=1
  --TODO : when isStunnable is available
  -- if S.MindBomb:IsAvailable() and S.MindBomb:IsCastable() and I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer()>=30 and CurrentInsanityDrain()>10 then
    -- if AR.CastSuggested(S.MindBomb) then return ""; end
  -- end
  
  -- actions.s2m+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&!buff.power_infusion.up|buff.voidform.stack<5
  if S.VoidTorrent:IsAvailable() 
    and S.VoidTorrent:CooldownRemainsP() == 0
    and not Target:DebuffRefreshableCP(S.ShadowWordPain) 
    and not Target:DebuffRefreshableCP(S.VampiricTouch)
    and (not S.SurrenderToMadness:IsAvailable() or (S.SurrenderToMadness:IsAvailable() and Target:TimeToDie() > v_s2mcheck - CurrentInsanityDrain() + 60))
    and (Player:BuffRemainsP(S.PowerInfusion) == 0 or Player:BuffStack(S.VoidForm) < 5)
    and not Player:IsCasting(S.VoidTorrent)	then
      if AR.Cast(S.VoidTorrent) then return ""; end
  end
  
  -- actions.s2m+=/shadow_word_death,if=current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled)<100)
  if Target:HealthPercentage() < ExecuteRange() 
    and ((S.ShadowWordDeath:ChargesP() > 0
      and CurrentInsanityDrain() * Player:GCD() > FutureInsanity() 
      and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + (30 + 30 * (S.ReaperOfSouls:IsAvailable() and 1 or 0))) < 100 )
    or Player:Buff(S.ZeksExterminatus)) then
      if AR.Cast(S.ShadowWordDeath) then return ""; end
  end
  
  -- actions.s2m+=/void_bolt
  -- actions.s2m+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
  if S.VoidBolt:CooldownRemainsP() <= Player:GCD() * 0.28 then
    if AR.Cast(S.VoidBolt) then return ""; end
  end
  
  -- actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled))<100
  if Target:HealthPercentage() < ExecuteRange() 
    and (S.ShadowWordDeath:ChargesP() > 0
      and (not AR.AoEON() or (AR.AoEON() and (Cache.EnemiesCount[range] <= 4) or (S.ReaperOfSouls:IsAvailable() and Cache.EnemiesCount[range] <= 2)))
      and CurrentInsanityDrain() * Player:GCD() > FutureInsanity() 
      and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + (30 + 30 * (S.ReaperOfSouls:IsAvailable() and 1 or 0))) < 100) 
    or Player:Buff(S.ZeksExterminatus) then
      if AR.Cast(S.ShadowWordDeath) then return ""; end
  end
 
  -- actions.s2m+=/dispersion,if=current_insanity_drain*gcd.max>insanity & !buff.power_infusion.up | (buff.voidform.stack>76&cooldown.shadow_word_death.charges=0&current_insanity_drain*gcd.max>insanity)
  if S.Dispersion:CooldownRemainsP() == 0 and CurrentInsanityDrain() * Player:GCD() > FutureInsanity() 
    and (Player:BuffRemainsP(S.PowerInfusion) == 0 
      or (Player:BuffStack(S.VoidForm) >76 and S.ShadowWordDeath:ChargesP() == 0 and CurrentInsanityDrain() * Player:GCD() > FutureInsanity())) then
		if AR.Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return ""; end
	end
  
  -- actions.s2m+=/mind_blast,if=active_enemies<=5
  -- actions.s2m+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=5
  if S.MindBlast:CooldownRemainsP() <= Player:GCD() * 0.28 
    and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range] <= 5)) 
    and (not Player:IsCasting(S.MindBlast) or (I.MangazasMadness:IsEquipped() and S.MindBlast:ChargesP() > 1)) then 
    if AR.Cast(S.MindBlast) then return ""; end
  end 

  -- actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
  if Target:HealthPercentage() < ExecuteRange()
    and S.ShadowWordDeath:ChargesP() == 2 
    and (not AR.AoEON() or (AR.AoEON() and (Cache.EnemiesCount[range] <= 4) or (S.ReaperOfSouls:IsAvailable() and Cache.EnemiesCount[range] <= 2))) then
      if AR.Cast(S.ShadowWordDeath) then return ""; end
  end
  if AR.AoEON() and Cache.EnemiesCount[range] > 1
    and S.ShadowWordDeath:ChargesP() == 2 then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:HealthPercentage() <= ExecuteRange() then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
            break
        end	
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
  end
  
  -- actions.s2m+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+50)<100
  if S.ShadowWordVoid:IsAvailable() 
    and S.ShadowWordVoid:ChargesP() > 0
    and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + 25) < 100 then
    if AR.Cast(S.ShadowWordVoid) then return ""; end
  end
  
  -- actions.s2m+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
  -- actions.s2m+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
  -- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
  -- actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
  -- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
  -- actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
  -- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
  if Target:DebuffRemainsP(S.ShadowWordPain) < Player:GCD() then
    if AR.Cast(S.ShadowWordPain) then return ""; end
  end
  if (Target:DebuffRemainsP(S.VampiricTouch) < 3 * Player:GCD() or (S.Misery:IsAvailable() and Target:DebuffRemainsP(S.ShadowWordPain) < 3 * Player:GCD())) and not Player:IsCasting(S.VampiricTouch) then
    if AR.Cast(S.VampiricTouch) then return ""; end
  end
  if AR.AoEON() and Cache.EnemiesCount[range] > 1 then
    BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = nil, S.VampiricTouch:BaseDuration() / 3, nil, 99;
    for Key, Value in pairs(Cache.Enemies[range]) do
      if S.Misery:IsAvailable() then
        if Value:DebuffRemainsP(S.ShadowWordPain) == 0
            and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 1)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 1;
        elseif (Value:DebuffRefreshableCP(S.VampiricTouch) or Value:DebuffRefreshableCP(S.ShadowWordPain))
            and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 2)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.VampiricTouch, 2;
        end
      else
        if Value:DebuffRemainsP(S.ShadowWordPain) == 0 and Value:FilteredTimeToDie(">", 10) and Cache.EnemiesCount[range] < 5 and (S.AuspiciousSpirit:IsAvailable() or S.ShadowInsight:IsAvailable())
          and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) or not(BestUnitSpellToCastNb <= 1)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 1;
        elseif Value:DebuffRemainsP(S.VampiricTouch) == 0 and Value:FilteredTimeToDie(">", 10) and (Cache.EnemiesCount[range] < 4 or S.Sanlayn:IsAvailable() or (S.AuspiciousSpirit:IsAvailable() and S.UnleashTheShadows:ArtifactRank() > 0))
          and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 2)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.VampiricTouch, 2;
        elseif Value:DebuffRefreshableCP(S.ShadowWordPain) and Value:FilteredTimeToDie(">", 10) and Cache.EnemiesCount[range] < 5 and S.SphereOfInsanity:ArtifactRank() > 0
          and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) or not(BestUnitSpellToCastNb <= 3)) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 3;
        end
      end
    end
    if BestUnit then
      if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
    end
  end
  
  -- actions.s2m+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+60)<100&cooldown.shadow_word_death.charges>=1))
  if S.MindFlay:IsCastable() then
    if AR.Cast(S.MindFlay) then return ""; end
  end
  
	return ""
end

--Classic VoidForm rotation
local function VoidForm ()
	--Void Torrent prediction
	if Player:IsCasting(S.VoidEruption) and S.VoidTorrent:CooldownRemainsP() == 0 then
		if AR.Cast(S.VoidTorrent) then return ""; end
	end
	
	if Target:IsInRange(range) then --in range
    -- actions.vf+=/silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
    if S.Silence:IsCastable() and I.SephuzSecret:IsEquipped() and Target:IsCasting() and Target:IsInterruptible() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 and CurrentInsanityDrain() > 10 then
    	if AR.CastSuggested(S.Silence) then return ""; end
    end
    if S.Silence:IsCastable() and I.SephuzSecret:IsEquipped() and Cache.EnemiesCount[range] > 1 and S.SephuzBuff:TimeSinceLastAppliedOnPlayer() >= 30 then
      BestUnit, BestUnitSpellToCast = nil, nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if Value:IsCasting() and Value:IsInterruptible() then
            BestUnit, BestUnitSpellToCast = Value, S.Silence;
            break
        end	
      end
      if BestUnit then
        if AR.CastSuggested(BestUnitSpellToCast) then return ""; end
      end
    end
    
		--actions.vf+=/void_bolt
    --actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
		if S.VoidBolt:CooldownRemainsP() <= Player:GCD() * 0.28 then
			if AR.Cast(S.VoidBolt) then return ""; end
		end 
    
    -- actions.vf+=/shadow_word_death,if=equipped.zeks_exterminatus&equipped.mangazas_madness&buff.zeks_exterminatus.react
    if Player:Buff(S.ZeksExterminatus) then
      if AR.Cast(S.ShadowWordDeath) then return ""; end
    end
    
    -- actions.vf+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
    --TODO : when isStunnable is available
    --TODO : closer range
    -- if S.MindBomb:IsAvailable() and S.MindBomb:IsCastable() and I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer()>=30 and CurrentInsanityDrain()>10 then
    	-- if AR.CastSuggested(S.MindBomb) then return ""; end
    -- end
    
		--actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
		if S.ShadowCrash:IsAvailable() and S.ShadowCrash:CooldownRemainsP() == 0 then
      if AR.Cast(S.ShadowCrash) then return ""; end
    end
		
		if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then
			--actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
			if S.VoidTorrent:IsAvailable() 
				and S.VoidTorrent:CooldownRemainsP() == 0
				and not Target:DebuffRefreshableCP(S.ShadowWordPain) 
				and not Target:DebuffRefreshableCP(S.VampiricTouch)
        and (not S.SurrenderToMadness:IsAvailable() or (S.SurrenderToMadness:IsAvailable() and Target:TimeToDie() > v_s2mcheck - CurrentInsanityDrain() + 60))
				and not Player:IsCasting(S.VoidTorrent)	then
          if AR.Cast(S.VoidTorrent) then return ""; end
			end
      
			--actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
			if Target:HealthPercentage() < ExecuteRange() 
				and ((S.ShadowWordDeath:ChargesP() > 0
          and (not AR.AoEON() or (AR.AoEON() and (Cache.EnemiesCount[range] <= 4) or (S.ReaperOfSouls:IsAvailable() and Cache.EnemiesCount[range] <= 2)))
					and CurrentInsanityDrain() * Player:GCD() > FutureInsanity() 
					and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + (15 + 15 * (S.ReaperOfSouls:IsAvailable() and 1 or 0))) < 100 )
				or Player:Buff(S.ZeksExterminatus)) then
					if AR.Cast(S.ShadowWordDeath) then return ""; end
			end
			
			--actions.vf+=/mind_blast,if=active_enemies<=4
			--actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
			if S.MindBlast:CooldownRemainsP() <= Player:GCD() * 0.28
        and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range] <= 4)) 
				and (not Player:IsCasting(S.MindBlast) or (I.MangazasMadness:IsEquipped() and S.MindBlast:ChargesP() > 1)) then 
          if AR.Cast(S.MindBlast) then return ""; end
			end 

			--actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
			if Target:HealthPercentage() < ExecuteRange()
        and S.ShadowWordDeath:ChargesP() == 2 
				and (not AR.AoEON() or (AR.AoEON() and (Cache.EnemiesCount[range] <= 4) or (S.ReaperOfSouls:IsAvailable() and Cache.EnemiesCount[range] <= 2))) then
          if AR.Cast(S.ShadowWordDeath) then return ""; end
			end
      if AR.AoEON() and Cache.EnemiesCount[range] > 1 and S.ShadowWordDeath:ChargesP() == 2 then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
          for Key, Value in pairs(Cache.Enemies[range]) do
            if Value:HealthPercentage() <= ExecuteRange() then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
                break
            end	
          end
          if BestUnit then
            if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
          end
      end

			--actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
			if S.ShadowWordVoid:IsAvailable() 
				and S.ShadowWordVoid:ChargesP() > 0
				and (FutureInsanity() - (CurrentInsanityDrain() * Player:GCD()) + 25) < 100 then
				if AR.Cast(S.ShadowWordVoid) then return ""; end
			end
			
      -- actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
      -- actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max)&target.time_to_die>5*gcd.max,cycle_targets=1
      -- actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
      -- actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
      -- actions.vf+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
      -- actions.vf+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
      if Target:DebuffRemainsP(S.ShadowWordPain) < Player:GCD() then
        if AR.Cast(S.ShadowWordPain) then return ""; end
      end
      if (Target:DebuffRemainsP(S.VampiricTouch) < 3 * Player:GCD() or (S.Misery:IsAvailable() and Target:DebuffRemainsP(S.ShadowWordPain) < 3 * Player:GCD())) and not Player:IsCasting(S.VampiricTouch) then
        if AR.Cast(S.VampiricTouch) then return ""; end
      end
      if AR.AoEON() and Cache.EnemiesCount[range] > 1 then
        BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = nil, S.VampiricTouch:BaseDuration() / 3, nil, 99;
        for Key, Value in pairs(Cache.Enemies[range]) do
          if S.Misery:IsAvailable() then
            if Value:DebuffRemainsP(S.ShadowWordPain) == 0
                and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 1)) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 1;
						elseif (Value:DebuffRefreshableCP(S.VampiricTouch) or Value:DebuffRefreshableCP(S.ShadowWordPain))
                and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 2)) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.VampiricTouch, 2;
						end
					else
            if Value:DebuffRemainsP(S.VampiricTouch) == 0 and ((1 + 0.02 * Player:BuffStack(S.VoidForm)) * v_dotvtdpgcd * Value:TimeToDie() / (Player:GCD() * (156 + v_seardpgcd * ((Cache.EnemiesCount[range] - 1) - 1)))) > 1
              and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 1)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.VampiricTouch, 1;
            elseif  Value:DebuffRefreshableCP(S.ShadowWordPain) and ((1 + 0.02 * Player:BuffStack(S.VoidForm)) * v_dotvtdpgcd * Value:TimeToDie() / (Player:GCD() * (118 + v_seardpgcd * (Cache.EnemiesCount[range] - 1)))) > 1
              and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) or not(BestUnitSpellToCastNb <= 2)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 2;
            end
          end
        end
        if BestUnit then
          if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
        end
      end
			
			--actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
			if S.MindFlay:IsCastable() then
				if AR.Cast(S.MindFlay) then return ""; end
			end      
		else--moving
      if Target:DebuffRefreshableCP(S.ShadowWordPain) then
        if AR.Cast(S.ShadowWordPain) then return ""; end
      end
      if S.ShadowWordDeath:ChargesP() > 0 
        and (FutureInsanity() < InsanityThreshold() or S.ShadowWordDeath:ChargesP() == 2) 
        and Target:HealthPercentage() <= ExecuteRange() then
          if AR.Cast(S.ShadowWordDeath) then return ""; end
      end
      
      --SWP on other targets if worth
      if AR.AoEON() then
        BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
        for Key, Value in pairs(Cache.Enemies[range]) do
          if S.ShadowWordDeath:ChargesP() > 0 
            and (FutureInsanity() < InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:ChargesP() == 2)
            and Value:HealthPercentage() <= ExecuteRange() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
              break
          end	
          
          if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) and Value:DebuffRefreshableCP(S.ShadowWordPain) then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
          end
        end
        if BestUnit then
          if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
        end
      end

      
      --actions.main+=/shadow_word_pain
      if S.ShadowWordPain:IsCastable() then
        if AR.Cast(S.ShadowWordPain) then return ""; end
      end 
		end
	else -- not in range
    if AR.AoEON() and Cache.EnemiesCount[range] > 0 then
      BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
      for Key, Value in pairs(Cache.Enemies[range]) do
        if S.VoidBolt:CooldownRemainsP() <= Player:GCD() * 0.28 then
          BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.VoidBolt;
          break
        end 
        
        if S.ShadowWordDeath:ChargesP() > 0 
          and (FutureInsanity() < InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:ChargesP() == 2)
          and Value:HealthPercentage() <= ExecuteRange() then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
            break
        end	
        
        if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then --static
          if S.Misery:IsAvailable() then
            if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch))
              or Value:DebuffRefreshableCP(S.VampiricTouch) or Value:DebuffRefreshableCP(S.ShadowWordPain) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
            end
          else
            if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain))
              or Value:DebuffRefreshableCP(S.ShadowWordPain) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
            elseif Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch))
              or Value:DebuffRefreshableCP(S.VampiricTouch) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
            end
          end
        else--moving
          if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain))
            or Value:DebuffRefreshableCP(S.ShadowWordPain) then
              BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
          end
        end
        
      end
      if BestUnit then
        if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
      end
    end
	end
end

--- APL Main
local function APL ()
	-- Unit Update
	AC.GetEnemies(range);
  Everyone.AoEToggleEnemiesUpdate();
  VarInit()
  VarCalc()
  
	-- Defensives
	if S.Dispersion:IsCastable() and Player:HealthPercentage() <= Settings.Shadow.DispersionHP then
		if AR.Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return ""; end
	end
	
	--Shadowform icon if not in shadowform
	if not Player:Buff(S.Shadowform) and not Player:Buff(S.VoidForm) then
		if AR.Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return ""; end
	end
  
	-- Out of Combat
	if not Player:AffectingCombat() then
    --RAZ combat
    if var_calcCombat then var_calcCombat = false end
	  -- Flask
	  -- Food
	  -- Rune
	  -- PrePot w/ Bossmod Countdown
	  -- Opener
    
    --TODO : precast potion
    --TODO : MindBomb when isStunnable is available
        
		--precast
    if Everyone.TargetIsValid() and Target:IsInRange(range) then
      if not Player:IsCasting() or not Player:IsCasting(S.MindBlast) then
        if AR.Cast(S.MindBlast) then return ""; end
      elseif S.Misery:IsAvailable() then
        if AR.Cast(S.VampiricTouch) then return ""; end
      else
        if AR.Cast(S.ShadowWordPain) then return ""; end
      end
        
    end
    
		return
	end
   
	-- In Combat
	if Everyone.TargetIsValid() then  
		if Target:IsInRange(range) then --in range
			--CD usage
			if AR.CDsON() then
				ShouldReturn = CDs();
				if ShouldReturn then return ShouldReturn; end
			end
						
			--Specific APL for Voidform and Surrender
			if Player:Buff(S.VoidForm) or Player:IsCasting(S.VoidEruption) then
				--actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
				if Player:Buff(S.SurrenderToMadness) then
					ShouldReturn = s2m();
					if ShouldReturn then return ShouldReturn; end
					
				--actions+=/run_action_list,name=vf,if=buff.voidform.up
				else
					ShouldReturn = VoidForm();
					if ShouldReturn then return ShouldReturn; end
				end
			end
			
			--static
			if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then
        -- actions.main+=/shadow_word_death,if=equipped.zeks_exterminatus&equipped.mangazas_madness&buff.zeks_exterminatus.react
        if Player:Buff(S.ZeksExterminatus) then
          if AR.Cast(S.ShadowWordDeath) then return ""; end
        end
      
        -- actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
        if S.Misery:IsAvailable() and (Target:DebuffRefreshableCP(S.VampiricTouch) or Target:DebuffRefreshableCP(S.ShadowWordPain)) and not Player:IsCasting(S.VampiricTouch) then
          if AR.Cast(S.VampiricTouch) then return ""; end
        end
        if AR.AoEON() and Cache.EnemiesCount[range] > 1 and S.Misery:IsAvailable() then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, S.VampiricTouch:BaseDuration() / 3, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if  Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch))
              and (Target:DebuffRefreshableCP(S.VampiricTouch) or Target:DebuffRefreshableCP(S.ShadowWordPain)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
						end
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
        
        -- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd  
        -- actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
        if not S.Misery:IsAvailable() then
          if Target:DebuffRefreshableCP(S.ShadowWordPain) then
            if AR.Cast(S.ShadowWordPain) then return ""; end
          end
          if Target:DebuffRefreshableCP(S.VampiricTouch) and not Player:IsCasting(S.VampiricTouch) then
            if AR.Cast(S.VampiricTouch) then return ""; end
          end
        end
        -- actions.main+=/void_eruption,if=(talent.mindbender.enabled&cooldown.mindbender.remains<(variable.erupt_eval+gcd.max*4%3))|!talent.mindbender.enabled|set_bonus.tier20_4pc
				if FutureInsanity() >= InsanityThreshold() and ((S.Mindbender:IsAvailable() and S.Mindbender:CooldownRemainsP() < v_eruptEval) or not S.Mindbender:IsAvailable() or AC.Tier20_4Pc) then
						if AR.Cast(S.VoidEruption) then return ""; end
				end
				
				--actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
				if S.ShadowCrash:IsAvailable() and S.ShadowCrash:CooldownRemainsP() == 0 then
					if AR.Cast(S.ShadowCrash) then return ""; end
				end
        
        --actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)
				if S.ShadowWordDeath:ChargesP() > 0 and (FutureInsanity() < InsanityThreshold() or S.ShadowWordDeath:ChargesP() == 2) and Target:HealthPercentage() <= ExecuteRange() then
					if AR.Cast(S.ShadowWordDeath) then return ""; end
				end
        -- find other targets
        if AR.AoEON() and Cache.EnemiesCount[range] > 1
          and S.ShadowWordDeath:ChargesP() > 0
          and (FutureInsanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:ChargesP() == 2) then
            BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
            for Key, Value in pairs(Cache.Enemies[range]) do
              if Value:HealthPercentage() <= ExecuteRange() then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
                break
              end	
            end
            if BestUnit then
              if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
            end
				end
        
				--actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
				--actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
				if S.MindBlast:CooldownRemainsP() == 0
					and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range] <= 4)) 
					and FutureInsanity() < InsanityThreshold() 
					and (not Player:IsCasting(S.MindBlast) or (I.MangazasMadness:IsEquipped() and S.MindBlast:ChargesP() > 1)) then
						if AR.Cast(S.MindBlast) then return ""; end
				end
        
        --actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
        --actions.main+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
        --actions.main+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
				if AR.AoEON() and Cache.EnemiesCount[range] > 1 and not S.Misery:IsAvailable() then
					BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = nil, S.VampiricTouch:BaseDuration() / 3, nil, 99;
					for Key, Value in pairs(Cache.Enemies[range]) do
            if Value:DebuffRefreshableCP(S.ShadowWordPain) and Cache.EnemiesCount[range] < 5 and not S.Sanlayn:IsAvailable() 
            and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) or not(BestUnitSpellToCastNb <= 1)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 1;
            elseif Value:DebuffRefreshableCP(S.VampiricTouch) and (v_dotvtdpgcd * Value:TimeToDie() / (Player:GCD() * (156 + v_seardpgcd * (Cache.EnemiesCount[range] - 1)))) > 1
              and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch)) or not(BestUnitSpellToCastNb <= 2)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.VampiricTouch, 2;
            elseif  Value:DebuffRefreshableCP(S.ShadowWordPain) and (v_dotswpdpgcd * Value:TimeToDie() / (Player:GCD() * (118 + v_seardpgcd * (Cache.EnemiesCount[range] - 1)))) > 1
              and (Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) or not(BestUnitSpellToCastNb <= 3)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 3;
            end
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
					end
				end
        
				--actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=70&talent.legacy_of_the_void.enabled)|(insanity<=85&!talent.legacy_of_the_void.enabled)
        if S.ShadowWordVoid:IsAvailable() and FutureInsanity() < InsanityThreshold() and S.ShadowWordVoid:ChargesP() > 0 then
					if AR.Cast(S.ShadowWordVoid) then return ""; end
				end
				
				--actions.main+=/mind_flay,interrupt=1,chain=1
				if S.MindFlay:IsCastable() then
					if AR.Cast(S.MindFlay) then return ""; end
				end
				return
			else --moving
        if Player:Buff(S.ZeksExterminatus) then
          if AR.Cast(S.ShadowWordDeath) then return ""; end
        end
        
        if Target:DebuffRefreshableCP(S.ShadowWordPain) then
          if AR.Cast(S.ShadowWordPain) then return ""; end
        end
        if S.ShadowWordDeath:ChargesP() > 0 
          and (FutureInsanity() < InsanityThreshold() or S.ShadowWordDeath:ChargesP() == 2) 
          and Target:HealthPercentage() <= ExecuteRange() then
            if AR.Cast(S.ShadowWordDeath) then return ""; end
        end
        
        --SWP on other targets if worth
        if AR.AoEON() then
          BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
          for Key, Value in pairs(Cache.Enemies[range]) do
            if S.ShadowWordDeath:ChargesP() > 0
              and (FutureInsanity() < InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:ChargesP() == 2)
              and Value:HealthPercentage() <= ExecuteRange() then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
                break
            end	
            
            if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain)) and Value:DebuffRefreshableCP(S.ShadowWordPain) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
            end
          end
          if BestUnit then
            if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
          end
        end
      
        if S.ShadowWordPain:IsCastable() then
          if AR.Cast(S.ShadowWordPain) then return ""; end
        end 
      end
      
		else--not in range, doting other targets
      if AR.AoEON() and Cache.EnemiesCount[range] > 0 then
        BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, Player:GCD(), nil;
        for Key, Value in pairs(Cache.Enemies[range]) do
          if (S.ShadowWordDeath:ChargesP() > 0 or Player:Buff(S.ZeksExterminatus)) 
            and (FutureInsanity() < InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:ChargesP() == 2)
            and Value:HealthPercentage() <= ExecuteRange() then
              BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
              break
          end	
          
          if not Player:IsMoving() or Player:BuffRemainsP(S.NorgannonsBuff) > 0 then --static
            if S.Misery:IsAvailable() then
              if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch))
                or Value:DebuffRefreshableCP(S.VampiricTouch) or Value:DebuffRefreshableCP(S.ShadowWordPain) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
              end
            else
              if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.VampiricTouch))
                or Value:DebuffRefreshableCP(S.VampiricTouch) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
              elseif Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain))
                or Value:DebuffRefreshableCP(S.ShadowWordPain) then
                  BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
              end
            end
          else--moving
            if Value:FilteredTimeToDie(">", BestUnitTTD, - Value:DebuffRemainsP(S.ShadowWordPain))
              or Value:DebuffRefreshableCP(S.ShadowWordPain) then
                BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
            end
          end
          
        end
        if BestUnit then
          if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return ""; end
        end
      end
      
		end
	end
end

AR.SetAPL(258, APL);

--- ======= SIMC =======
--- Last Update: 28/10/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/variable,name=haste_eval,op=set,value=(raw_haste_pct-0.3)*(10+10*equipped.mangazas_madness+5*talent.fortress_of_the_mind.enabled)
-- actions.precombat+=/variable,name=haste_eval,op=max,value=0
-- actions.precombat+=/variable,name=erupt_eval,op=set,value=26+1*talent.fortress_of_the_mind.enabled-4*talent.Sanlayn.enabled-3*talent.Shadowy_insight.enabled+variable.haste_eval*1.5
-- actions.precombat+=/variable,name=cd_time,op=set,value=(12+(2-2*talent.mindbender.enabled*set_bonus.tier20_4pc)*set_bonus.tier19_2pc+(1-3*talent.mindbender.enabled*set_bonus.tier20_4pc)*equipped.mangazas_madness+(6+5*talent.mindbender.enabled)*set_bonus.tier20_4pc+2*artifact.lash_of_insanity.rank)
-- actions.precombat+=/variable,name=dot_swp_dpgcd,op=set,value=36.5*1.2*(1+0.06*artifact.to_the_pain.rank)*(1+0.2+stat.mastery_rating%16000)*0.75
-- actions.precombat+=/variable,name=dot_vt_dpgcd,op=set,value=68*1.2*(1+0.2*talent.sanlayn.enabled)*(1+0.05*artifact.touch_of_darkness.rank)*(1+0.2+stat.mastery_rating%16000)*0.5
-- actions.precombat+=/variable,name=sear_dpgcd,op=set,value=120*1.2*(1+0.05*artifact.void_corruption.rank)
-- actions.precombat+=/variable,name=s2msetup_time,op=set,value=(0.8*(83+(20+20*talent.fortress_of_the_mind.enabled)*set_bonus.tier20_4pc-(5*talent.sanlayn.enabled)+((33-13*set_bonus.tier20_4pc)*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*equipped.mangazas_madness+(raw_haste_pct*10*(1+0.7*set_bonus.tier20_4pc))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled)))),if=talent.surrender_to_madness.enabled
-- actions.precombat+=/potion
-- actions.precombat+=/shadowform,if=!buff.shadowform.up
-- actions.precombat+=/mind_blast

-- # Executed every time the actor is available.
-- actions=potion,if=buff.bloodlust.react|target.time_to_die<=80|(target.health.pct<35&cooldown.power_infusion.remains<30)
-- actions+=/call_action_list,name=check,if=talent.surrender_to_madness.enabled&!buff.surrender_to_madness.up
-- actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
-- actions+=/run_action_list,name=vf,if=buff.voidform.up
-- actions+=/run_action_list,name=main

-- actions.check=variable,op=set,name=actors_fight_time_mod,value=0
-- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10),if=time+target.time_to_die>450&time+target.time_to_die<600
-- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5),if=time+target.time_to_die<=450
-- actions.check+=/variable,op=set,name=s2mcheck,value=variable.s2msetup_time-(variable.actors_fight_time_mod*nonexecute_actors_pct)
-- actions.check+=/variable,op=min,name=s2mcheck,value=180

-- actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
-- actions.main+=/shadow_word_death,if=equipped.zeks_exterminatus&equipped.mangazas_madness&buff.zeks_exterminatus.react
-- actions.main+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd.max,moving=1,cycle_targets=1
-- actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
-- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd
-- actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
-- actions.main+=/void_eruption,if=(talent.mindbender.enabled&cooldown.mindbender.remains<(variable.erupt_eval+gcd.max*4%3))|!talent.mindbender.enabled|set_bonus.tier20_4pc
-- actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
-- actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)|(equipped.zeks_exterminatus&buff.zeks_exterminatus.react)
-- actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
-- actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
-- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
-- actions.main+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
-- actions.main+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
-- actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=75-10*talent.legacy_of_the_void.enabled)
-- actions.main+=/mind_flay,interrupt=1,chain=1
-- actions.main+=/shadow_word_pain

-- actions.s2m=silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up,cycle_targets=1
-- actions.s2m+=/void_bolt,if=buff.insanity_drain_stacks.value<6&set_bonus.tier19_4pc
-- actions.s2m+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up,cycle_targets=1
-- actions.s2m+=/shadow_crash,if=talent.shadow_crash.enabled
-- actions.s2m+=/mindbender,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)
-- actions.s2m+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&!buff.power_infusion.up|buff.voidform.stack<5
-- actions.s2m+=/berserking,if=buff.voidform.stack>=65
-- actions.s2m+=/shadow_word_death,if=current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled)<100)
-- actions.s2m+=/arcane_torrent,if=buff.insanity_drain_stacks.value>=65&(insanity-(current_insanity_drain*gcd.max)+30)<100
-- actions.s2m+=/power_infusion,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)|target.time_to_die<=30
-- actions.s2m+=/void_bolt
-- actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled))<100
-- actions.s2m+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
-- actions.s2m+=/dispersion,if=current_insanity_drain*gcd.max>insanity&!buff.power_infusion.up|(buff.voidform.stack>76&cooldown.shadow_word_death.charges=0&current_insanity_drain*gcd.max>insanity)
-- actions.s2m+=/mind_blast,if=active_enemies<=5
-- actions.s2m+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=5
-- actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
-- actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled&buff.voidform.stack>15
-- actions.s2m+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+50)<100
-- actions.s2m+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
-- actions.s2m+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
-- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
-- actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
-- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
-- actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
-- actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
-- actions.s2m+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+60)<100&cooldown.shadow_word_death.charges>=1))

-- actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.value)
-- actions.vf+=/silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
-- actions.vf+=/void_bolt
-- actions.vf+=/arcane_torrent,if=buff.insanity_drain_stacks.value>=20&(insanity-(current_insanity_drain*gcd.max)+15)<100
-- actions.vf+=/shadow_word_death,if=equipped.zeks_exterminatus&equipped.mangazas_madness&buff.zeks_exterminatus.react
-- actions.vf+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
-- actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
-- actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
-- actions.vf+=/mindbender,if=buff.insanity_drain_stacks.value>=(variable.cd_time+(variable.haste_eval*!set_bonus.tier20_4pc)-(3*set_bonus.tier20_4pc*(raid_event.movement.in<15)*((active_enemies-(raid_event.adds.count*(raid_event.adds.remains>0)))=1))+(5-3*set_bonus.tier20_4pc)*buff.bloodlust.up+2*talent.fortress_of_the_mind.enabled*set_bonus.tier20_4pc)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-buff.insanity_drain_stacks.value))
-- actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.value>=(variable.cd_time+5*buff.bloodlust.up*(1+1*set_bonus.tier20_4pc))&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+61))
-- actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.value<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
-- actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
-- actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
-- actions.vf+=/mind_blast,if=active_enemies<=4
-- actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
-- actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2|(equipped.zeks_exterminatus&buff.zeks_exterminatus.react)
-- actions.vf+=/shadowfiend,if=!talent.mindbender.enabled&buff.voidform.stack>15
-- actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
-- actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
-- actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max)&target.time_to_die>5*gcd.max,cycle_targets=1
-- actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
-- actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
-- actions.vf+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
-- actions.vf+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
-- actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
-- actions.vf+=/shadow_word_pain


--- Localize Vars
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
    -- Misc
		Shadowform				= Spell(232698),
		VoidForm				  = Spell(194249),
    SephuzBuff			  = Spell(208052),
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
    PotionOfProlongedPower  = Item(142117)
  };
  local I = Item.Priest.Shadow;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P,T194P = AC.HasTier("T19")
  local T202P,T204P = AC.HasTier("T20")
  local T212P,T214P = AC.HasTier("T21")
  local BestUnit, BestUnitTTD, BestUnitSpellToCast, BestUnitSpellToCastNb; -- Used for cycling
  local v_cdtime,v_dotswpdpgcd,v_dotvtdpgcd,v_seardpgcd,v_s2msetuptime
  local v_actorsFightTimeMod,v_s2mcheck
  local var_init=false
  local var_calcCombat=false
  local range=40
  local VTUsed
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    --Commons = AR.GUISettings.APL.Priest.Commons,
    Shadow = AR.GUISettings.APL.Priest.Shadow
  };


--- APL Action Lists (and Variables)


local function ExecuteRange()
	if Player:Buff(S.ZeksExterminatus) then return 101; end
	return S.ReaperOfSouls:IsAvailable() and 35 or 20;
end

local function InsanityThreshold()
	return S.LegacyOfTheVoid:IsAvailable() and 65 or 100;
end

local function FutureInsanity()
  --TODO : add MF ?
  local insanity = Player:Insanity()
  if not Player:IsCasting() then
    return insanity
  else
    if Player:CastID()==S.MindBlast:ID() then
      return insanity+(15*(Player:Buff(S.PowerInfusion) and 1.25 or 1.0 )*(S.FortressOfTheMind:IsAvailable() and 1.2 or 1.0))
    elseif Player:CastID()==S.VampiricTouch:ID() then
      return insanity+(6*(Player:Buff(S.PowerInfusion) and 1.25 or 1.0 ))
    elseif Player:CastID()==S.ShadowWordVoid:ID() then
      return insanity+(25*(Player:Buff(S.PowerInfusion) and 1.25 or 1.0 ))
    else
      return insanity
    end
  end 
end

local function CurrentInsanityDrain()
	if not Player:Buff(S.VoidForm) then return 0.0; end
	return 6+ 0.67*(Player:BuffStack(S.VoidForm)-(2*(I.MotherShahrazsSeduction:IsEquipped() and 1 or 0))-4*(VTUsed and 1 or 0))
end

local function Var_ActorsFightTimeMod()
-- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10),if=time+target.time_to_die>450&time+target.time_to_die<600
-- actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5),if=time+target.time_to_die<=450
	if (AC.CombatTime()+Target:TimeToDie())>450 and (AC.CombatTime()+Target:TimeToDie())<600 then
		v_actorsFightTimeMod=-((-450+(AC.CombatTime()+Target:TimeToDie()))/10)
	elseif (AC.CombatTime()+Target:TimeToDie())<=450 then
		v_actorsFightTimeMod=((450-(AC.CombatTime()+Target:TimeToDie()))/5)
  else
    v_actorsFightTimeMod=0
	end
end

local function Var_S2MCheck()
-- actions.check+=/variable,op=set,name=s2mcheck,value=variable.s2msetup_time-(variable.actors_fight_time_mod*nonexecute_actors_pct)
-- actions.check+=/variable,op=min,name=s2mcheck,value=180
  --TODO : add nonexecute_actors_pct ?
  v_s2mcheck = v_s2msetuptime - (v_actorsFightTimeMod)
  if v_s2mcheck < 180 then
    v_s2mcheck=180
  end
  return v_s2mcheck;
end

local function Var_CdTime()
-- actions.precombat+=/variable,name=cd_time,op=set,value=(10+(2-2*talent.mindbender.enabled*set_bonus.tier20_4pc)*set_bonus.tier19_2pc+(3-3*talent.mindbender.enabled*set_bonus.tier20_4pc)*equipped.mangazas_madness+(6+5*talent.mindbender.enabled)*set_bonus.tier20_4pc+2*artifact.lash_of_insanity.rank)
  v_cdtime = 10 + ((2 - 2 * (S.Mindbender:IsAvailable() and 1 or 0) * (T204P and 1 or 0)) * (T192P and 1 or 0)) + ((3 - 3 * (S.Mindbender:IsAvailable() and 1 or 0) * (T204P and 1 or 0)) * (I.MangazasMadness:IsEquipped() and 1 or 0)) + ((6 + 5 * (S.Mindbender:IsAvailable() and 1 or 0)) * (T204P and 1 or 0)) + (2 * (S.LashOfInsanity:ArtifactRank() or 0))
  -- print(v_cdtime)
end

local function Var_DotSWPDPGCD()
-- actions.precombat+=/variable,name=dot_swp_dpgcd,op=set,value=38*1.2*(1+0.06*artifact.to_the_pain.rank)*(1+0.2+stat.mastery_rating%16000)*0.75
  v_dotswpdpgcd = 38 * 1.2 * (1 + 0.06 * (S.ToThePain:ArtifactRank() or 0)) * (1+0.2+(Player:MasteryPct() / 16000)) * 0.75
  -- print(v_dotswpdpgcd)
end

local function Var_DotVTDPGCD()
-- actions.precombat+=/variable,name=dot_vt_dpgcd,op=set,value=71*1.2*(1+0.2*talent.sanlayn.enabled)*(1+0.05*artifact.touch_of_darkness.rank)*(1+0.2+stat.mastery_rating%16000)*0.5
  v_dotvtdpgcd = 71 * 1.2 * (1 + 0.2 * (S.Sanlayn:IsAvailable() and 1 or 0)) * (1 + 0.05 * (S.TouchOfDarkness:ArtifactRank() or 0)) * (1 + 0.2 + (Player:MasteryPct() / 16000)) * 0.5
  -- print(v_dotvtdpgcd)
end

local function Var_SearDPGCD()
-- actions.precombat+=/variable,name=sear_dpgcd,op=set,value=80*(1+0.05*artifact.void_corruption.rank)
  v_seardpgcd = 80 * (1 + 0.05 + (S.VoidCorruption:ArtifactRank() or 0))
  -- print(v_seardpgcd)
end

local function Var_S2MSetupTime()
-- actions.precombat+=/variable,name=s2msetup_time,op=set,value=(0.8*(83+(20+20*talent.fortress_of_the_mind.enabled)*set_bonus.tier20_4pc-(5*talent.sanlayn.enabled)+(30+42*(desired_targets>1)+10*talent.lingering_insanity.enabled)*set_bonus.tier21_4pc*talent.auspicious_spirits.enabled+((33-13*set_bonus.tier20_4pc)*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*equipped.mangazas_madness+(raw_haste_pct*10*(1+0.7*set_bonus.tier20_4pc))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled)))),if=talent.surrender_to_madness.enabled
  if (S.SurrenderToMadness:IsAvailable()) then
    v_s2msetuptime = 0.8 * (83 
    + ((20 + 20 * (S.FortressOfTheMind:IsAvailable() and 1 or 0)) * (T204P and 1 or 0))
    - (5 * (S.Sanlayn:IsAvailable() and 1 or 0))
    + ((30 + 42 * ((Cache.EnemiesCount[range]>1) and 1 or 0) + 10 * (S.Sanlayn:IsAvailable() and 1 or 0)) * (T214P and 1 or 0) * (S.AuspiciousSpirit:IsAvailable() and 1 or 0))
    + ((33 - 13 * (T204P and 1 or 0)) * (S.ReaperOfSouls:IsAvailable() and 1 or 0))
    + (4 * (T192P and 1 or 0))
    + (8 * (I.MangazasMadness:IsEquipped() and 1 or 0))
    + (Player:HastePct() * 10 * (1 + 0.7 * (T204P and 1 or 0)) * (2 + (0.8 * (T192P and 1 or 0)) + (1 * (S.ReaperOfSouls:IsAvailable() and 1 or 0)) + (2 * (S.MassHysteria:ArtifactRank() or 0)) - (1 * (S.Sanlayn:IsAvailable() and 1 or 0)))))
  else
    v_s2msetuptime = 0
  end 
  -- print(v_s2msetuptime)
end

local function VarInit()
  if not var_init or (AC.CombatTime() > 0 and not var_calcCombat) then
    Var_CdTime()
    Var_DotSWPDPGCD()
    Var_DotVTDPGCD()
    Var_SearDPGCD()
    Var_S2MSetupTime()
    var_init=true
    var_calcCombat=true
  end
end

local function VarCalc()
  if (S.SurrenderToMadness:IsAvailable() and not Player:Buff(S.SurrenderToMadness)) then
    Var_ActorsFightTimeMod()
    Var_S2MCheck()
  end
end

local function CDs ()
	--PI
  --actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.value>=(10+2*set_bonus.tier19_2pc+5*buff.bloodlust.up*(1+1*set_bonus.tier20_4pc)+3*equipped.mangazas_madness+6*set_bonus.tier20_4pc+2*artifact.lash_of_insanity.rank)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+61))
	--actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.stack>=(10+2*set_bonus.tier19_2pc+5*buff.bloodlust.up+5*variable.s2mbeltcheck)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+61))
	--TODO : S2M
	if Player:Buff(S.VoidForm) and S.PowerInfusion:IsAvailable() and S.PowerInfusion:IsCastable() and CurrentInsanityDrain()>=(10 + 2*(T192P and 1 or 0) +5*(Player:HasHeroism() and 1 or 0)*(1+1*(T204P and 1 or 0)) +3*(I.MangazasMadness:IsEquipped() and 1 or 0) +6*(T204P and 1 or 0) +2*(S.LashOfInsanity:ArtifactRank() or 0)) then
		if AR.Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "Cast"; end
	end

	--SF
	--actions.vf+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	--S2M:actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	--TODO : S2M
	if Player:Buff(S.VoidForm) and not S.Mindbender:IsAvailable() and S.Shadowfiend:IsCastable() and Player:BuffStack(S.VoidForm)> (15-4.5*(S.FiendingDark:ArtifactRank() or 0)) then
		if AR.Cast(S.Shadowfiend, Settings.Shadow.GCDasOffGCD.Shadowfiend) then return "Cast"; end
	end
  
  -- actions.vf+=/mindbender,if=set_bonus.tier20_4pc&buff.insanity_drain_stacks.value>=(25-(3*(raid_event.movement.in<15)*((active_enemies-target.adds)=1))+2*buff.bloodlust.up+2*talent.fortress_of_the_mind.enabled)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-buff.insanity_drain_stacks.value))
  -- actions.vf+=/mindbender,if=!set_bonus.tier20_4pc&buff.insanity_drain_stacks.value>=(10+2*set_bonus.tier19_2pc+5*buff.bloodlust.up+3*equipped.mangazas_madness+2*artifact.lash_of_insanity.rank)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+30))
  --TODO : S2M
  if Player:Buff(S.VoidForm) and S.Mindbender:IsAvailable() and S.Mindbender:IsCastable() and (T204P and 1 or 0) and CurrentInsanityDrain()>=(25+2*(Player:HasHeroism() and 1 or 0)+2*(S.FortressOfTheMind:IsAvailable() and 1 or 0)+2*(S.LashOfInsanity:ArtifactRank() or 0)) then 
    if AR.Cast(S.Mindbender, Settings.Shadow.GCDasOffGCD.Mindbender) then return "Cast"; end
  end
  if Player:Buff(S.VoidForm) and S.Mindbender:IsAvailable() and S.Mindbender:IsCastable() and (not T204P and 1 or 0) and CurrentInsanityDrain()>=(10+2*(T192P and 1 or 0)+5*(Player:HasHeroism() and 1 or 0)+3*(I.MangazasMadness:IsEquipped() and 1 or 0)+2*(S.LashOfInsanity:ArtifactRank() or 0)) then 
    if AR.Cast(S.Mindbender, Settings.Shadow.GCDasOffGCD.Mindbender) then return "Cast"; end
  end

	--Berserking
	--actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.stack<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
	--TODO : S2M
	if S.Berserking:IsAvailable() and S.Berserking:IsCastable() and Player:BuffStack(S.VoidForm)>=10 and CurrentInsanityDrain()<=20 then
		if AR.Cast(S.Berserking, Settings.Shadow.OffGCDasOffGCD.Racials) then return "Cast"; end
	end
	
	--actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.stack)
	--TODO : S2M
	
	--Arcane Torrent
	--TODO
  
  -- actions+=/potion,name=prolonged_power,if=buff.bloodlust.react|target.time_to_die<=80|(target.health.pct<35&cooldown.power_infusion.remains<30)
  if Settings.Shadow.ShowPoPP and I.PotionOfProlongedPower:IsReady() and (Player:HasHeroism() or Target:TimeToDie()<=80 or (Target:HealthPercentage()<35 and S.PowerInfusion:IsAvailable() and S.PowerInfusion:CooldownRemains() < 30)) then
    if AR.CastSuggested(I.PotionOfProlongedPower) then return "Cast"; end
  end
end

local function s2m()
-- actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
-- actions.main+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd.max,moving=1,cycle_targets=1
-- actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
-- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd
-- actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
-- actions.main+=/void_eruption
-- actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
-- actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)
-- actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
-- actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
-- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
-- actions.main+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&(85.2*(1+0.2+stat.mastery_rating%16000)*(1+0.2*talent.sanlayn.enabled)*0.5*target.time_to_die%(gcd.max*(138+80*(active_enemies-1))))>1,cycle_targets=1
-- actions.main+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&(47.12*(1+0.2+stat.mastery_rating%16000)*0.75*target.time_to_die%(gcd.max*(138+80*(active_enemies-1))))>1,cycle_targets=1
-- actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=75-10*talent.legacy_of_the_void.enabled)
-- actions.main+=/mind_flay,interrupt=1,chain=1
-- actions.main+=/shadow_word_pain
	return ""
end

local function VoidForm()
  
	--void bolt prediction
	if Player:CastID() == S.VoidEruption:ID() then
		if AR.Cast(S.VoidBolt) then return "Cast"; end
	end
	
	if Target:IsInRange(range) then --in range
    -- actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.value)
    -- TODO : S2M
  
    -- actions.vf+=/silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
    -- TODO : multitarget
    if S.Silence:IsCastable() and I.SephuzSecret:IsEquipped() and Target:IsCasting() and Target:IsInterruptible() and S.SephuzBuff:TimeSinceLastBuff()>=30 and CurrentInsanityDrain()>10 then
    	if AR.CastSuggested(S.Silence) then return "Cast"; end
    end
    
    -- print(S.MindBomb:IsCastable(),SephuzEquipped(),S.SephuzBuff:TimeSinceLastBuff(),CurrentInsanityDrain())
    -- actions.vf+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
    if S.MindBomb:IsCastable() and I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastBuff()>=30 and CurrentInsanityDrain()>10 then
    	if AR.CastSuggested(S.MindBomb) then return "Cast"; end
    end
    
		--actions.vf+=/void_bolt
    --actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
		if S.VoidBolt:IsCastable() or ((Player:IsCasting() or (Player:IsChanneling() and Player:ChannelName()==S.VoidTorrent:Name()))  and (Player:CastRemains() + Player:GCD()*0.28 >= S.VoidBolt:Cooldown())) or (not Player:IsCasting() and not Player:IsChanneling() and S.VoidBolt:Cooldown() < Player:GCD() * 0.28) then
			if AR.Cast(S.VoidBolt) then return "Cast"; end
		end 
    

    
		--actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
		if S.ShadowCrash:IsAvailable() and (S.ShadowCrash:IsCastable() or (Player:IsCasting() and Player:CastRemains() > S.ShadowCrash:Cooldown()+Player:GCD())) then
      if AR.Cast(S.ShadowCrash) then return "Cast"; end
    end
		
		if not Player:IsMoving() then
			--actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
			--TODO : S2M
			if S.VoidTorrent:IsAvailable() 
				and (S.VoidTorrent:IsCastable() or (Player:IsCasting() and Player:CastRemains()  >= S.VoidTorrent:Cooldown()))
				and Target:DebuffRemains(S.ShadowWordPain) > 5.5 
				and Target:DebuffRemains(S.VampiricTouch) > 5.5
				and not (Player:CastID() == S.VoidTorrent:ID())	then
				VTUsed=true
				if AR.Cast(S.VoidTorrent) then return "Cast"; end
			end
      
			--actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
			if Target:HealthPercentage() < ExecuteRange() 
				and ((S.ShadowWordDeath:Charges() > 0 or (S.ShadowWordDeath:Charges() == 0 and Player:IsCasting() and Player:CastRemains() >= S.ShadowWordDeath:Recharge())) 
					and CurrentInsanityDrain()*Player:GCD()>Player:Insanity() 
					and ((CurrentInsanityDrain()*Player:GCD())+(15+15*(S.ReaperOfSouls:IsAvailable() and 1 or 0)))<100) 
				or Player:Buff(S.ZeksExterminatus) then
					if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
			end
			
			--actions.vf+=/mind_blast,if=active_enemies<=4
			--actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
			if (S.MindBlast:IsCastable() or (Player:IsCasting() and ((Player:CastRemains() + Player:GCD()*0.28) >= S.MindBlast:Cooldown()))) 
				and (not (Player:CastID() == S.MindBlast:ID()) or (I.MangazasMadness:IsEquipped() and S.MindBlast:Charges()>1)) 
				and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range]<=4)) then 
				if AR.Cast(S.MindBlast) then return "Cast"; end
			end 

			--actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
			if S.ShadowWordDeath:Charges() == 2 and Target:HealthPercentage() < ExecuteRange()
				and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range]<=4)) then
				if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
			end

			--actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
			if S.ShadowWordVoid:IsAvailable() 
				and (S.ShadowWordVoid:IsCastable() or (Player:IsCasting() and Player:CastRemains() >= S.ShadowWordVoid:Cooldown()))
				and (Player:Insanity()-(CurrentInsanityDrain()*Player:GCD())+25)<100 then
				if AR.Cast(S.ShadowWordVoid) then return "Cast"; end
			end
			
      -- actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
      -- actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max)&target.time_to_die>5*gcd.max,cycle_targets=1
      -- actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
      -- actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
      -- actions.vf+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
      -- actions.vf+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1

			if (Target:DebuffRemains(S.VampiricTouch) < (4+(4/3))*Player:GCD() or (S.Misery:IsAvailable() and  Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD()))
				and not (Player:CastID() == S.VampiricTouch:ID()) then
					if AR.Cast(S.VampiricTouch) then return "Cast"; end
			end
			if Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD() then
					if AR.Cast(S.ShadowWordPain) then return "Cast"; end
			end
			
			--multidoting
			if AR.AoEON() and Cache.EnemiesCount[range]<5  then
				BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
				for Key, Value in pairs(Cache.Enemies[range]) do
					if S.ShadowWordDeath:Charges() > 0 and (Player:Insanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:Charges() == 2)
						and Value:HealthPercentage()<=ExecuteRange() then
							BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
							break
					end	
					
					if S.Misery:IsAvailable() then
						if Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
							and (Value:DebuffRemains(S.VampiricTouch) < 3*Player:GCD() 
							or Value:DebuffRemains(S.ShadowWordPain) < 3*Player:GCD()) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
						end
					else
						if (Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
							and Value:DebuffRemains(S.VampiricTouch)< 3*Player:GCD()) or (Value:TimeToDie() > 10 and BestUnitSpellToCast == S.ShadowWordPain and Value:DebuffRemains(S.VampiricTouch)< 3*Player:GCD()) then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
						elseif Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
							and Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() and BestUnitSpellToCast ~= S.VampiricTouch then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
						end
					end
					
				end
				if BestUnit then
					if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
				end
			end
			
			--actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
			if S.MindFlay:IsCastable() then
				if AR.Cast(S.MindFlay) then return "Cast"; end
			end
			
			return
		end
		
		--moving
		if Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD() then
			if AR.Cast(S.ShadowWordPain) then return "Cast"; end
		end
		if S.ShadowWordDeath:Charges() > 0 and Player:Insanity()<InsanityThreshold()
			and Target:HealthPercentage()<=ExecuteRange() then
				if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
		end
		
		--SWP on other targets if worth
		if AR.AoEON() then
			BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
			for Key, Value in pairs(Cache.Enemies[range]) do
				if S.ShadowWordDeath:Charges() > 0 and (Player:Insanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:Charges() == 2)
					and Value:HealthPercentage()<=ExecuteRange() then
						BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
						break
				end	
				
				if Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
					and Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() and BestUnitSpellToCast ~= S.VampiricTouch then
						BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
				end
			end
			if BestUnit then
				if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
			end
		end

		
		--actions.main+=/shadow_word_pain
		if S.ShadowWordPain:IsCastable() then
			if AR.Cast(S.ShadowWordPain) then return "Cast"; end
		end 
			
		return
	end
	
	-- not in range
	if AR.AoEON() and Cache.EnemiesCount[range]>0 then
		BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
		for Key, Value in pairs(Cache.Enemies[range]) do
			
			if S.VoidBolt:IsCastable() then
				BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.VoidBolt;
				break
			end 
		
			if  S.ShadowWordDeath:Charges() > 0 and (FutureInsanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or Cache.EnemiesCount[range]<=4 or S.ShadowWordDeath:Charges() == 2)
				and Value:HealthPercentage()<=ExecuteRange() then
					BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
					break
			end	
			
			--moving
			if Player:IsMoving() then
				if Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
					or Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() then
						BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
				end
				
			--static
			else
				if S.Misery:IsAvailable() then
					if Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
						or Value:DebuffRemains(S.VampiricTouch) < 3*Player:GCD() 
						or Value:DebuffRemains(S.ShadowWordPain) < 3*Player:GCD() then
							BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
					end
				else
					if Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
						or Value:DebuffRemains(S.VampiricTouch)< 3*Player:GCD() then
							BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
					elseif Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
						or Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() then
							BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
					end
				end
			end
			
		end
		if BestUnit then
			if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
		end
	end
	
	return
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
		if AR.Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return "Cast"; end
	end
	
	--Shadowform icon if not in shadowform
	if not Player:Buff(S.Shadowform) and not Player:Buff(S.VoidForm) then
		if AR.Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "Cast"; end
	end
  
	-- Out of Combat
	if not Player:AffectingCombat() then
    --RAZ combat
    if var_calcCombat then var_calcCombat=false end
	  -- Flask
	  -- Food
	  -- Rune
	  -- PrePot w/ Bossmod Countdown
	  -- Opener
    
    -- if AR.Cast(I.PotionOfProlongedPower,Settings.Shadow.OffGCDasOffGCD.PotionOfProlongedPower) then return "Cast"; end
    
		--precast
    if Everyone.TargetIsValid() and Target:IsInRange(range) then
      if not Player:IsCasting() then
        if AR.Cast(S.MindBlast) then return "Cast"; end
      elseif S.Misery:IsAvailable() then
        if AR.Cast(S.VampiricTouch) then return "Cast"; end
      else
        if AR.Cast(S.ShadowWordPain) then return "Cast"; end
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
			if Player:Buff(S.VoidForm) or (Player:CastID() == S.VoidEruption:ID()) then
				--actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
				--TODO : S2M
				-- if Player:Buff(S.SurrenderToMadness) then
					--ShouldReturn = s2m();
					--if ShouldReturn then return ShouldReturn; end
					
				--actions+=/run_action_list,name=vf,if=buff.voidform.up
				-- else
					ShouldReturn = VoidForm();
					if ShouldReturn then return ShouldReturn; end
				-- end
			end
			
			--static
			if not Player:IsMoving() then
        -- actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
        -- TODO : S2M
      
        -- actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
        if S.Misery:IsAvailable() and (Target:DebuffRemains(S.VampiricTouch) < 3*Player:GCD() or Target:DebuffRemains(S.ShadowWordPain) < 3*Player:GCD()) and not (Player:CastID() == S.VampiricTouch:ID()) then
          if AR.Cast(S.VampiricTouch) then return "Cast"; end
        end
        -- cycle_targets
        if AR.AoEON() and Cache.EnemiesCount[range]>1 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if S.Misery:IsAvailable() and Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
              and (Value:DebuffRemains(S.VampiricTouch) < 3*Player:GCD() 
              or Value:DebuffRemains(S.ShadowWordPain) < 3*Player:GCD()) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
						end
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
					end
				end
        
        -- actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd        
        if not S.Misery:IsAvailable() and Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD() then
          if AR.Cast(S.ShadowWordPain) then return "Cast"; end
        end
        
        -- actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
        if not S.Misery:IsAvailable() and Target:DebuffRemains(S.VampiricTouch) < (4+(4/3))*Player:GCD() and not (Player:CastID() == S.VampiricTouch:ID()) then
          if AR.Cast(S.VampiricTouch) then return "Cast"; end
        end
				
				--actions.main+=/void_eruption,if=insanity>=70|(talent.auspicious_spirits.enabled&insanity>=(65-shadowy_apparitions_in_flight*3))|set_bonus.tier19_4pc
				if FutureInsanity() >= InsanityThreshold() then
						VTUsed=false
						if AR.Cast(S.VoidEruption) then return "Cast"; end
				end
				
				--actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
				if S.ShadowCrash:IsAvailable() and (S.ShadowCrash:IsCastable() or (Player:IsCasting() and Player:CastRemains() > S.ShadowCrash:Cooldown()+Player:GCD())) then
					if AR.Cast(S.ShadowCrash) then return "Cast"; end
				end
        
        --actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)
				if (S.ShadowWordDeath:Charges() > 0 or (Player:IsCasting() and Player:CastRemains() > S.ShadowWordDeath:Recharge()+Player:GCD())) and FutureInsanity() < InsanityThreshold() and Target:HealthPercentage() <= ExecuteRange() then
						if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
				end
        -- find other targets
        if AR.AoEON() and Cache.EnemiesCount[range]<5 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[range]) do
						if S.ShadowWordDeath:Charges() > 0 and (FutureInsanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:Charges() == 2)
							and Value:HealthPercentage() <= ExecuteRange() then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
								break
						end	
          end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
					end
				end
        
				--actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
				--actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
				if (S.MindBlast:IsCastable() or (Player:IsCasting() and Player:CastRemains() > S.MindBlast:Cooldown()+Player:GCD())) 
					and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[range]<=4)) 
					and FutureInsanity()<InsanityThreshold() 
					and (not (Player:CastID() == S.MindBlast:ID()) or (I.MangazasMadness:IsEquipped() and S.MindBlast:Charges()>1)) then
						if AR.Cast(S.MindBlast) then return "Cast"; end
				end
        
        --actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
        --actions.main+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
        --actions.main+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
				if AR.AoEON() and Cache.EnemiesCount[range]>1 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast,BestUnitSpellToCastNb = nil, 10, nil, 99;
					for Key, Value in pairs(Cache.Enemies[range]) do
            -- print(Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain), BestUnitTTD, BestUnitSpellToCastNb)
            if not S.Misery:IsAvailable() and Value:DebuffRemains(S.ShadowWordPain)< Player:GCD() and Value:TimeToDie() > 10 and Cache.EnemiesCount[range]<5 and not S.Sanlayn:IsAvailable() 
            and (Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD or not(BestUnitSpellToCastNb<=1)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast,BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 1;
            elseif not S.Misery:IsAvailable() and Cache.EnemiesCount[range]>1 and Value:DebuffRemains(S.VampiricTouch)< 3*Player:GCD() and (v_dotvtdpgcd * Value:TimeToDie()/(Player:GCD()*(156+v_seardpgcd*(Cache.EnemiesCount[range]-1)))) > 1
              and (Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD or not(BestUnitSpellToCastNb<=2)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast,BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.VampiricTouch, 2;
            elseif not S.Misery:IsAvailable() and Cache.EnemiesCount[range]>1 and Value:DebuffRemains(S.ShadowWordPain)< Player:GCD() and (v_dotswpdpgcd * Value:TimeToDie()/(Player:GCD()*(118+v_seardpgcd*(Cache.EnemiesCount[range]-1)))) > 1
              and (Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD or not(BestUnitSpellToCastNb<=3)) then
                BestUnit, BestUnitTTD, BestUnitSpellToCast,BestUnitSpellToCastNb = Value, Value:TimeToDie(), S.ShadowWordPain, 3;
            end
					end
					if BestUnit then
						if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
					end
				end
        
				--actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=70&talent.legacy_of_the_void.enabled)|(insanity<=85&!talent.legacy_of_the_void.enabled)
				if S.ShadowWordVoid:IsAvailable() and FutureInsanity()<InsanityThreshold() and (S.ShadowWordVoid:IsCastable() or (Player:IsCasting() and Player:CastRemains() > S.ShadowWordVoid:Cooldown()+Player:GCD()) ) then
					if AR.Cast(S.ShadowWordVoid) then return "Cast"; end
				end
				
				--actions.main+=/mind_flay,interrupt=1,chain=1
				if S.MindFlay:IsCastable() then
					if AR.Cast(S.MindFlay) then return "Cast"; end
				end
				return
			end
			
			--moving
			if Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD() then
				if AR.Cast(S.ShadowWordPain) then return "Cast"; end
			end
			if S.ShadowWordDeath:Charges() > 0 and FutureInsanity()<InsanityThreshold()
				and Target:HealthPercentage()<=ExecuteRange() then
					if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
			end
			
			--SWP on other targets if worth
			if AR.AoEON() then
				BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
				for Key, Value in pairs(Cache.Enemies[range]) do
					if S.ShadowWordDeath:Charges() > 0 and (FutureInsanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:Charges() == 2)
						and Value:HealthPercentage()<=ExecuteRange() then
							BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
							break
					end	
					
					if Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
						and Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() and BestUnitSpellToCast ~= S.VampiricTouch then
							BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
					end
				end
				if BestUnit then
					if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
				end
			end
		
			--actions.main+=/shadow_word_pain
			if S.ShadowWordPain:IsCastable() then
				if AR.Cast(S.ShadowWordPain) then return "Cast"; end
			end 
				
			return
		end
		
		--not in range, doting other targets
		if AR.AoEON() and Cache.EnemiesCount[range]>0 then
			BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
			for Key, Value in pairs(Cache.Enemies[range]) do
				if S.ShadowWordDeath:Charges() > 0 and (FutureInsanity()<InsanityThreshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or Cache.EnemiesCount[range]<=4 or S.ShadowWordDeath:Charges() == 2)
					and Value:HealthPercentage()<=ExecuteRange() then
						BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
						break
				end	
				
				--moving
				if Player:IsMoving() then
					if Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
						or Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() then
							BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
					end
					
				--static
				else
					if S.Misery:IsAvailable() then
						if Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
							or Value:DebuffRemains(S.VampiricTouch) < 3*Player:GCD() 
							or Value:DebuffRemains(S.ShadowWordPain) < 3*Player:GCD() then
								BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
						end
					else
						if Value:TimeToDie()-Value:DebuffRemains(S.VampiricTouch) > BestUnitTTD
							or Value:DebuffRemains(S.VampiricTouch)< 3*Player:GCD() then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.VampiricTouch;
						elseif Value:TimeToDie()-Value:DebuffRemains(S.ShadowWordPain) > BestUnitTTD
							or Value:DebuffRemains(S.ShadowWordPain)< 3*Player:GCD() then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordPain;
						end
					end
				end
				
			end
			if BestUnit then
				if AR.CastLeftNameplate(BestUnit, BestUnitSpellToCast) then return "Cast"; end
			end
		end
		
		return;
	end
end

AR.SetAPL(258, APL);

--[[ 05/08/2017 generation
# Executed before combat begins. Accepts non-harmful actions only.
actions.precombat=flask,type=flask_of_the_whispered_pact
actions.precombat+=/food,type=azshari_salad
actions.precombat+=/augmentation,type=defiled
# Snapshot raid buffed stats before combat begins and pre-potting is done.
actions.precombat+=/snapshot_stats
actions.precombat+=/variable,name=cd_time,op=set,value=(10+(2-2*talent.mindbender.enabled*set_bonus.tier20_4pc)*set_bonus.tier19_2pc+(3-3*talent.mindbender.enabled*set_bonus.tier20_4pc)*equipped.mangazas_madness+(6+5*talent.mindbender.enabled)*set_bonus.tier20_4pc+2*artifact.lash_of_insanity.rank)
actions.precombat+=/variable,name=dot_swp_dpgcd,op=set,value=38*1.2*(1+0.06*artifact.to_the_pain.rank)*(1+0.2+stat.mastery_rating%16000)*0.75
actions.precombat+=/variable,name=dot_vt_dpgcd,op=set,value=71*1.2*(1+0.2*talent.sanlayn.enabled)*(1+0.05*artifact.touch_of_darkness.rank)*(1+0.2+stat.mastery_rating%16000)*0.5
actions.precombat+=/variable,name=sear_dpgcd,op=set,value=80*(1+0.05*artifact.void_corruption.rank)
actions.precombat+=/variable,name=s2msetup_time,op=set,value=(0.8*(83+(20+20*talent.fortress_of_the_mind.enabled)*set_bonus.tier20_4pc-(5*talent.sanlayn.enabled)+(30+42*(desired_targets>1)+10*talent.lingering_insanity.enabled)*set_bonus.tier21_4pc*talent.auspicious_spirits.enabled+((33-13*set_bonus.tier20_4pc)*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*equipped.mangazas_madness+(raw_haste_pct*10*(1+0.7*set_bonus.tier20_4pc))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled)))),if=talent.surrender_to_madness.enabled
actions.precombat+=/potion,name=prolonged_power
actions.precombat+=/shadowform,if=!buff.shadowform.up
actions.precombat+=/mind_blast

# Executed every time the actor is available.
actions=use_item,slot=trinket1
actions+=/potion,name=prolonged_power,if=buff.bloodlust.react|target.time_to_die<=80|(target.health.pct<35&cooldown.power_infusion.remains<30)
actions+=/call_action_list,name=check,if=talent.surrender_to_madness.enabled&!buff.surrender_to_madness.up
actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
actions+=/run_action_list,name=vf,if=buff.voidform.up
actions+=/run_action_list,name=main

actions.check=variable,op=set,name=actors_fight_time_mod,value=0
actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10),if=time+target.time_to_die>450&time+target.time_to_die<600
actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5),if=time+target.time_to_die<=450
actions.check+=/variable,op=set,name=s2mcheck,value=variable.s2msetup_time-(variable.actors_fight_time_mod*nonexecute_actors_pct)
actions.check+=/variable,op=min,name=s2mcheck,value=180

actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
actions.main+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd.max,moving=1,cycle_targets=1
actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd
actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
actions.main+=/void_eruption
actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)
actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
actions.main+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
actions.main+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&(variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=75-10*talent.legacy_of_the_void.enabled)
actions.main+=/mind_flay,interrupt=1,chain=1
actions.main+=/shadow_word_pain

actions.s2m=void_bolt,if=buff.insanity_drain_stacks.value<6&set_bonus.tier19_4pc
actions.s2m+=/shadow_crash,if=talent.shadow_crash.enabled
actions.s2m+=/mindbender,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)
actions.s2m+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&!buff.power_infusion.up|buff.voidform.stack<5
actions.s2m+=/berserking,if=buff.voidform.stack>=65
actions.s2m+=/shadow_word_death,if=current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled)<100)
actions.s2m+=/power_infusion,if=cooldown.shadow_word_death.charges=0&buff.voidform.stack>(45+25*set_bonus.tier20_4pc)|target.time_to_die<=30
actions.s2m+=/void_bolt
actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled))<100
actions.s2m+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
actions.s2m+=/dispersion,if=current_insanity_drain*gcd.max>insanity&!buff.power_infusion.up|(buff.voidform.stack>76&cooldown.shadow_word_death.charges=0&current_insanity_drain*gcd.max>insanity)
actions.s2m+=/mind_blast,if=active_enemies<=5
actions.s2m+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=5
actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled&buff.voidform.stack>15
actions.s2m+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+50)<100
actions.s2m+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
actions.s2m+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
actions.s2m+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+60)<100&cooldown.shadow_word_death.charges>=1))

actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.value)
actions.vf+=/silence,if=equipped.sephuzs_secret&(target.is_add|target.debuff.casting.react)&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
actions.vf+=/void_bolt
actions.vf+=/mind_bomb,if=equipped.sephuzs_secret&target.is_add&cooldown.buff_sephuzs_secret.remains<1&!buff.sephuzs_secret.up&buff.insanity_drain_stacks.value>10,cycle_targets=1
actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
actions.vf+=/mindbender,if=buff.insanity_drain_stacks.value>=(variable.cd_time-(3*set_bonus.tier20_4pc*(raid_event.movement.in<15)*((active_enemies-(raid_event.adds.count*(raid_event.adds.remains>0)))=1))+(5-3*set_bonus.tier20_4pc)*buff.bloodlust.up+2*talent.fortress_of_the_mind.enabled*set_bonus.tier20_4pc)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-buff.insanity_drain_stacks.value))
actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.value>=(variable.cd_time+5*buff.bloodlust.up*(1+1*set_bonus.tier20_4pc))&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+61))
actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.value<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.value)+60))
actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
actions.vf+=/mind_blast,if=active_enemies<=4
actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
actions.vf+=/shadowfiend,if=!talent.mindbender.enabled&buff.voidform.stack>15
actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max)&target.time_to_die>5*gcd.max,cycle_targets=1
actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
actions.vf+=/vampiric_touch,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_vt_dpgcd*target.time_to_die%(gcd.max*(156+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
actions.vf+=/shadow_word_pain,if=active_enemies>1&!talent.misery.enabled&!ticking&((1+0.02*buff.voidform.stack)*variable.dot_swp_dpgcd*target.time_to_die%(gcd.max*(118+variable.sear_dpgcd*(active_enemies-1))))>1,cycle_targets=1
actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
actions.vf+=/shadow_word_pain
]]--

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
		BloodFury				= Spell(20572),
		GiftoftheNaaru			= Spell(59547),
		Shadowmeld           	= Spell(58984),
    -- Abilities
		MindBlast				= Spell(8092),
		MindFlay				= Spell(15407),
		VoidEruption			= Spell(228260),
		VoidBolt				= Spell(205448),
		ShadowWordDeath			= Spell(32379),
		ShadowWordPain			= Spell(589),
		VampiricTouch			= Spell(34914),
		Shadowfiend				= Spell(34433),
    -- Talents
		TwistOfFate				= Spell(109142),
		FortressOfTheMind		= Spell(193195),
		ShadowWordVoid			= Spell(205351),

		LingeringInsanity		= Spell(199849),
		ReaperOfSouls			= Spell(199853),
		VoidRay					= Spell(205371),

		Sanlayn					= Spell(199855),
		AuspiciousSpirit		= Spell(155271),
		ShadowInsight			= Spell(162452),
		
		PowerInfusion			= Spell(10060),
		Misery					= Spell(238558),
		Mindbender				= Spell(200174),
		
		LegacyOfTheVoid			= Spell(193225),
		ShadowCrash				= Spell(190819),
		SurrendertoMadness		= Spell(193223),
    -- Artifact
		VoidTorrent				= Spell(205065),
		MassHysteria			= Spell(194378),
		SphereOfInsanity		= Spell(194179),
		UnleashTheShadows		= Spell(194093),
    -- Defensive
		Dispersion				= Spell(47585),
		Fade					= Spell(586),
		PowerWordShield			= Spell(17),
    -- Utility
		VampiricEmbrace 		= Spell(15286),
    -- Legendaries
		ZeksExterminatus		= Spell(236546),
    -- Misc
		Shadowform				= Spell(232698),
		VoidForm				= Spell(194249)
    -- Macros
    
  };
  local S = Spell.Priest.Shadow;
  -- Items
  if not Item.Priest then Item.Priest = {}; end
  Item.Priest.Shadow = {
    -- Legendaries
	MotherShahrazsSeduction		= Item(132437), --3?
	MangazasMadness 			= Item(132864), --6
	ZeksExterminatus 			= Item(137100) --15

  };
  local I = Item.Priest.Shadow;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local T192P,T194P = AC.HasTier("T19")
  local BestUnit, BestUnitTTD, BestUnitSpellToCast; -- Used for cycling
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

local function Insanity_Threshold()
	return S.LegacyOfTheVoid:IsAvailable() and 65 or 100;
end

local function CurrentInsanityDrain ()
	if not Player:Buff(S.VoidForm) then return 0.0; end
	return 6+ 0.67*(Player:BuffStack(S.VoidForm)-(2*(I.MotherShahrazsSeduction:IsEquipped(3) and 1 or 0))-4*(VTUsed and 1 or 0))
end

local function actorsFightTimeMod()
--actions.check=variable,op=set,name=actors_fight_time_mod,value=0
--actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10),if=time+target.time_to_die>450&time+target.time_to_die<600
--actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5),if=time+target.time_to_die<=450
	local value = 0
	if (AC.CombatTime()+Target:TimeToDie())>450 and (AC.CombatTime()+Target:TimeToDie())<600 then
		value=-((-(450)+(AC.CombatTime()+Target:TimeToDie()))%10)
	elseif (AC.CombatTime()+Target:TimeToDie())<=450 then
		value=((450-(AC.CombatTime()+Target:TimeToDie()))%5)
	end
	return value
end

local function nonexecuteActorsPct()

end

local function s2mbeltcheck()
	--actions.precombat+=/variable,op=set,name=s2mbeltcheck,value=cooldown.mind_blast.charges>=2
	return I.MangazasMadness:IsEquipped(6) and 1 or 0;
end

local function s2mCheck()
--actions.check+=/variable,op=set,name=s2mcheck,value=(0.8*(83-(5*talent.sanlayn.enabled)+(33*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*variable.s2mbeltcheck+((raw_haste_pct*10))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled))))-(variable.actors_fight_time_mod*nonexecute_actors_pct)
--[[	local value=0
	value = (
	0.8*(
		83-(
			5*S.Sanlayn:IsAvailable()
		)
		+(
			33*S.ReaperOfSouls:IsAvailable()
		)
		+(
			1--4*set_bonus.tier19_2pc
		)
		+(
			8*s2mbeltcheck()
		)
		+(
			(Player:HastePct()*10))
			*(
				2+(
					1--0.8*set_bonus.tier19_2pc
				)
				+(
					1*S.ReaperOfSouls:IsAvailable()
				)
				+(
					2*S.Sanlayn:MassHysteria()
				)-(
					1*S.Sanlayn:IsAvailable()
				)
			)
		)
)	
-(
	actorsFightTimeMod()*nonexecuteActorsPct
)
	
	if value < 180 then
		value=180
	end
	return value;]]
	return 0;
end

local function CDs ()
	--PI
	--actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.stack>=(10+2*set_bonus.tier19_2pc+5*buff.bloodlust.up+5*variable.s2mbeltcheck)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+61))
	--TODO : S2M
	if Player:Buff(S.VoidForm) and S.PowerInfusion:IsAvailable() and S.PowerInfusion:IsCastable() and Player:BuffStack(S.VoidForm)>=(10 + 2*(T192P and 1 or 0) + 5*s2mbeltcheck() + 2*(I.MotherShahrazsSeduction:IsEquipped(3) and 1 or 0) + 4*(VTUsed and 1 or 0) + 5*(Player:HasHeroism() and 1 or 0)) then
		if AR.Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "Cast"; end
	end

	--SF
	--actions.vf+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	--S2M:actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	--TODO : S2M
	if Player:Buff(S.VoidForm) and not S.Mindbender:IsAvailable() and S.Shadowfiend:IsCastable() and Player:BuffStack(S.VoidForm)>15 then
		if AR.Cast(S.Shadowfiend, Settings.Shadow.GCDasOffGCD.Shadowfiend) then return "Cast"; end
	end

	--Mb
	--S2M:actions.main+=/mindbender,if=talent.mindbender.enabled&((talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck+60)|!talent.surrender_to_madness.enabled)
	--S2M:actions.main+=/mindbender,if=talent.mindbender.enabled&set_bonus.tier18_2pc
	--S2M:actions.s2m+=/mindbender,if=talent.mindbender.enabled
	--S2M:actions.vf+=/mindbender,if=talent.mindbender.enabled&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+30))
	--TODO : S2M
	if Player:Buff(S.VoidForm) then
		if S.Mindbender:IsAvailable() and S.Mindbender:IsCastable() then
			if AR.Cast(S.Mindbender) then return "Cast"; end
		end
	else
		if S.Mindbender:IsAvailable() and S.Mindbender:IsCastable() and (T192P and 1 or 0) then
			if AR.Cast(S.Mindbender) then return "Cast"; end
		end
	end

	--Berserking
	--actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.stack<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
	--TODO : S2M
	if S.Berserking:IsAvailable() and S.Berserking:IsCastable() and Player:BuffStack(S.VoidForm)>=10 and CurrentInsanityDrain()<=20 then
		if AR.Cast(S.Berserking, Settings.Shadow.OffGCDasOffGCD.Berserking) then return "Cast"; end
	end
	
	--Arcane Torrent
	--TODO
end

local function s2m()
	--actions.s2m=void_bolt,if=buff.insanity_drain_stacks.stack<6&set_bonus.tier19_4pc
	--actions.s2m+=/shadow_crash,if=talent.shadow_crash.enabled
	--actions.s2m+=/mindbender,if=talent.mindbender.enabled
	--actions.s2m+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&!buff.power_infusion.up
	--actions.s2m+=/berserking,if=buff.voidform.stack>=65
	--actions.s2m+=/shadow_word_death,if=current_insanity_drain*gcd.max>insanity&!buff.power_infusion.up&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled)<100)
	--actions.s2m+=/power_infusion,if=cooldown.shadow_word_death.charges=0&cooldown.shadow_word_death.remains>3*gcd.max&buff.voidform.stack>50
	--actions.s2m+=/void_bolt
	--actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled))<100
	--actions.s2m+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
	--actions.s2m+=/dispersion,if=current_insanity_drain*gcd.max>insanity-5&!buff.power_infusion.up
	--actions.s2m+=/mind_blast,if=active_enemies<=5
	--actions.s2m+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=5
	--actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
	--actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
	--actions.s2m+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+50)<100
	--actions.s2m+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
	--actions.s2m+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
	--actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
	--actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
	--actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
	--actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
	--actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
	--actions.s2m+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+60)<100&cooldown.shadow_word_death.charges>=1))

	return ""
end

local function voidForm()
	--void bolt prediction
	if Player:CastID() == S.VoidEruption:ID() then
		AR.CastLeft(S.VoidBolt);
		if AR.Cast(S.VoidEruption) then return "Cast"; end
	end
	
	--TODO : static/moving

	--actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.stack)
	--TODO : S2M
	
	--actions.vf+=/void_bolt
	if S.VoidBolt:IsCastable() then
		if AR.Cast(S.VoidBolt) then return "Cast"; end
	end 
	
	--actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
	if S.ShadowCrash:IsAvailable() and S.ShadowCrash:IsCastable() then
		if AR.Cast(S.ShadowCrash) then return "Cast"; end
	end
	
	--actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
	--TODO : S2M
	if S.VoidTorrent:IsAvailable() and S.VoidTorrent:IsCastable() and Target:DebuffRemains(S.ShadowWordPain) > 5.5 and Target:DebuffRemains(S.VampiricTouch) > 5.5 then
		VTUsed=true
		if AR.Cast(S.VoidTorrent) then return "Cast"; end
	end
	
	--actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
	if Target:HealthPercentage() < ExecuteRange() and (S.ShadowWordDeath:Charges() > 0 and CurrentInsanityDrain()*Player:GCD()>Player:Insanity() and ((CurrentInsanityDrain()*Player:GCD())+(15+15*(S.ReaperOfSouls:IsAvailable() and 1 or 0)))<100) or Player:Buff(S.ZeksExterminatus) then
		if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
	end
	
	--actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
	if S.VoidBolt:Cooldown()<Player:GCD()*0.28 then
		if AR.Cast(S.VoidBolt) then return "Cast"; end
	end
	
	--actions.vf+=/mind_blast,if=active_enemies<=4
	--actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
	--TODO : enemies ?
	if S.MindBlast:IsCastable() or S.MindBlast:Cooldown()<Player:GCD()*0.28 then 
		if AR.Cast(S.MindBlast) then return "Cast"; end
	end 
	
	--actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
	--TODO : enemies ?
	if S.ShadowWordDeath:Charges() == 2 and Target:HealthPercentage() < ExecuteRange() then
		if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
	end
	
	--actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
	if S.ShadowWordVoid:IsAvailable() and S.ShadowWordVoid:IsCastable() and (Player:Insanity()-(CurrentInsanityDrain()*Player:GCD())+25)<100 then
		if AR.Cast(S.ShadowWordVoid) then return "Cast"; end
	end
	
	--actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
	--actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
	if S.Misery:IsAvailable() then
		if Target:DebuffRemains(S.ShadowWordPain) < Player:GCD() and GetUnitSpeed("player") ~= 0 then
			if AR.Cast(S.ShadowWordPain) then return "Cast"; end
		end
		if Target:DebuffRemains(S.VampiricTouch) < 3*Player:GCD() or Target:DebuffRemains(S.ShadowWordPain) < 3*Player:GCD() then
			if AR.Cast(S.VampiricTouch) then return "Cast"; end
		end
	else
		--actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
		--todo : enemies : and (s.AuspiciousSpirit:IsAvailable() or s.ShadowInsight:IsAvailable() or s.SphereOfInsanity:IsAvailable())
		if S.ShadowWordPain:IsCastable() and Target:DebuffRemains(S.ShadowWordPain)==0 then
			if AR.Cast(S.ShadowWordPain) then return "Cast"; end
		end
		
		--actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
		--todo : enemies and ( s.Sanlayn:IsAvailable() or (s.AuspiciousSpirit:IsAvailable() and s.UnleashTheShadows:IsAvailable())) 
		if S.VampiricTouch:IsCastable() and Target:DebuffRemains(S.VampiricTouch)==0 then
			if AR.Cast(S.VampiricTouch) then return "Cast"; end
		end
		
		--actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1		
		--todo : enemies and (s.AuspiciousSpirit:IsAvailable() or s.ShadowInsight:IsAvailable() or s.SphereOfInsanity:IsAvailable())
		--if S.ShadowWordPain:IsCastable() and not Target:Debuff(ShadowWordPain) and Target:TimeToDie()>10  then
		--	if AR.Cast(S.ShadowWordPain) then return "Cast"; end
		--end
		
		--actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
		--todo : enemies 
		--if S.VampiricTouch:IsCastable() and not Target:Debuff(VampiricTouch) and Target:TimeToDie()>10 then
		--	if AR.Cast(S.VampiricTouch) then return "Cast"; end
		--end
		
		--actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
		--todo : enemies 
		--if S.ShadowWordPain:IsCastable() and not Target:Debuff(ShadowWordPain) and Target:TimeToDie()>10  then
		--	if AR.Cast(S.ShadowWordPain) then return "Cast"; end
		--end
	end
	
	--actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
	--todo : finir
	if S.MindFlay:IsCastable() and GetUnitSpeed("player") == 0 then
		if AR.Cast(S.MindFlay) then return "Cast"; end
	end
	
	--actions.vf+=/shadow_word_pain
	if S.ShadowWordPain:IsCastable() then
		if AR.Cast(S.ShadowWordPain) then return "Cast"; end
	end 
	return ""
end

--- APL Main
local function APL ()
	-- Unit Update
	AC.GetEnemies(40);
	
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
	  -- Flask
	  -- Food
	  -- Rune
	  -- PrePot w/ Bossmod Countdown
	  -- Opener
		
		--precast
		if AR.Commons.TargetIsValid() and Target:IsInRange(40) then
			if AR.Cast(S.MindBlast) then return "Cast"; end
		end
		return
	end
	
	-- In Combat
	if AR.Commons.TargetIsValid() then
		if Target:IsInRange(40) then --in range
			
			--CD usage
			if AR.CDsON() then
				ShouldReturn = CDs();
				if ShouldReturn then return ShouldReturn; end
			end
			
			--Specific APL for Voidform and Surrender
			if Player:Buff(S.VoidForm) or (Player:CastID() == S.VoidEruption:ID()) then
				--actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
				--TODO : S2M
				if Player:Buff(S.SurrendertoMadness) then
					--ShouldReturn = s2m();
					--if ShouldReturn then return ShouldReturn; end
					
				--actions+=/run_action_list,name=vf,if=buff.voidform.up
				else
					ShouldReturn = voidForm();
					if ShouldReturn then return ShouldReturn; end
				end
			end
			
			--actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
			if S.SurrendertoMadness:IsAvailable() and S.SurrendertoMadness:IsCastable() and Target:TimeToDie()<s2mCheck()  then
				--TODO : S2M
				--if AR.Cast(S.SurrendertoMadness) then return "Cast"; end
			end
			
			--static
			if GetUnitSpeed("player") == 0 then 
				--actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
				if (Target:DebuffRemains(S.VampiricTouch) < (4+(4/3))*Player:GCD() or (S.Misery:IsAvailable() and  Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD()))
					and not (Player:CastID() == S.VampiricTouch:ID()) 
					and not (Player:CastID() == S.VoidEruption:ID()) then
						if AR.Cast(S.VampiricTouch) then return "Cast"; end
				end
				
				--actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd
				if Target:DebuffRemains(S.ShadowWordPain) < (3+(4/3))*Player:GCD() 
					and not (Player:CastID() == S.VoidEruption:ID()) then
						if AR.Cast(S.ShadowWordPain) then return "Cast"; end
				end
				
				--actions.main+=/void_eruption,if=insanity>=70|(talent.auspicious_spirits.enabled&insanity>=(65-shadowy_apparitions_in_flight*3))|set_bonus.tier19_4pc
				if Player:Insanity()>=Insanity_Threshold() 
					or (Player:CastID() == S.MindBlast:ID() and 
						((Player:Insanity()+(15*(Player:Buff(S.PowerInfusion) and 1.25 or 1.0 )*(S.FortressOfTheMind:IsAvailable() and 1.2 or 1.0)) ) >= Insanity_Threshold())) 
					or (Player:CastID() == S.VampiricTouch:ID() and 
						((Player:Insanity()+(6*(Player:Buff(S.PowerInfusion) and 1.25 or 1.0 )) ) >= Insanity_Threshold())) then
						VTUsed=false
						if AR.Cast(S.VoidEruption) then return "Cast"; end
				end
				
				--actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
				if S.ShadowCrash:IsAvailable() and S.ShadowCrash:IsCastable() then
					if AR.Cast(S.ShadowCrash) then return "Cast"; end
				end
				
				--actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&talent.legacy_of_the_void.enabled&insanity>=70,cycle_targets=1
				--actions.main+=/vampiric_touch,if=!talent.misery.enabled&!ticking&talent.legacy_of_the_void.enabled&insanity>=70,cycle_targets=1
				if AR.AoEON() and Cache.EnemiesCount[40]<5 then
					BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
					for Key, Value in pairs(Cache.Enemies[40]) do
						if S.ShadowWordDeath:Charges() > 0 and (Player:Insanity()<Insanity_Threshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:Charges() == 2)
							and Value:HealthPercentage()<=ExecuteRange() then
								BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
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
				
				--actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)
				if S.ShadowWordDeath:Charges() > 0 and Player:Insanity()<Insanity_Threshold()
					and Target:HealthPercentage()<=ExecuteRange() then
						if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
				end
				
				--actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
				--actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
				if S.MindBlast:IsCastable() and (not AR.AoEON() or (AR.AoEON() and Cache.EnemiesCount[40]<=4)) 
					and Player:Insanity()<Insanity_Threshold() and not (Player:CastID() == S.MindBlast:ID()) then
						if AR.Cast(S.MindBlast) then return "Cast"; end
				end
				
				--actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=70&talent.legacy_of_the_void.enabled)|(insanity<=85&!talent.legacy_of_the_void.enabled)
				if S.ShadowWordVoid:IsAvailable() and S.ShadowWordVoid:IsCastable() and Player:Insanity()<Insanity_Threshold() then
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
			if S.ShadowWordDeath:Charges() > 0 and Player:Insanity()<Insanity_Threshold()
				and Target:HealthPercentage()<=ExecuteRange() then
					if AR.Cast(S.ShadowWordDeath) then return "Cast"; end
			end
			
			--SWP on other targets if worth
			if AR.AoEON() then
				BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
				for Key, Value in pairs(Cache.Enemies[40]) do
					if S.ShadowWordDeath:Charges() > 0 and (Player:Insanity()<Insanity_Threshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or S.ShadowWordDeath:Charges() == 2)
						and Value:HealthPercentage()<=ExecuteRange() then
							BestUnit, BestUnitTTD, BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
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
		if AR.AoEON() and Cache.EnemiesCount[40]>0 then
			BestUnit, BestUnitTTD, BestUnitSpellToCast = nil, 10, nil;
			for Key, Value in pairs(Cache.Enemies[40]) do
				if S.ShadowWordDeath:Charges() > 0 and (Player:Insanity()<Insanity_Threshold() or (not Player:Buff(S.TwistOfFate) and S.TwistOfFate:IsAvailable()) or Cache.EnemiesCount[40]<=4 or S.ShadowWordDeath:Charges() == 2)
					and Value:HealthPercentage()<=ExecuteRange() then
						BestUnit, BestUnitTTD,BestUnitSpellToCast = Value, Value:TimeToDie(), S.ShadowWordDeath;
				end	
				
				--moving
				if GetUnitSpeed("player") ~= 0 then
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

--[[
# Executed before combat begins. Accepts non-harmful actions only.
actions.precombat=flask,type=flask_of_the_whispered_pact
actions.precombat+=/food,type=azshari_salad
actions.precombat+=/augmentation,type=defiled
# Snapshot raid buffed stats before combat begins and pre-potting is done.
actions.precombat+=/snapshot_stats
actions.precombat+=/potion,name=prolonged_power
actions.precombat+=/shadowform,if=!buff.shadowform.up
actions.precombat+=/variable,op=set,name=s2mbeltcheck,value=cooldown.mind_blast.charges>=2
actions.precombat+=/mind_blast

# Executed every time the actor is available.
actions=potion,name=prolonged_power,if=buff.bloodlust.react|target.time_to_die<=80|(target.health.pct<35&cooldown.power_infusion.remains<30)
actions+=/call_action_list,name=check,if=talent.surrender_to_madness.enabled&!buff.surrender_to_madness.up
actions+=/run_action_list,name=s2m,if=buff.voidform.up&buff.surrender_to_madness.up
actions+=/run_action_list,name=vf,if=buff.voidform.up
actions+=/run_action_list,name=main

actions.check=variable,op=set,name=actors_fight_time_mod,value=0
actions.check+=/variable,op=set,name=actors_fight_time_mod,value=-((-(450)+(time+target.time_to_die))%10),if=time+target.time_to_die>450&time+target.time_to_die<600
actions.check+=/variable,op=set,name=actors_fight_time_mod,value=((450-(time+target.time_to_die))%5),if=time+target.time_to_die<=450
actions.check+=/variable,op=set,name=s2mcheck,value=(0.8*(83-(5*talent.sanlayn.enabled)+(33*talent.reaper_of_souls.enabled)+set_bonus.tier19_2pc*4+8*variable.s2mbeltcheck+((raw_haste_pct*10))*(2+(0.8*set_bonus.tier19_2pc)+(1*talent.reaper_of_souls.enabled)+(2*artifact.mass_hysteria.rank)-(1*talent.sanlayn.enabled))))-(variable.actors_fight_time_mod*nonexecute_actors_pct)
actions.check+=/variable,op=min,name=s2mcheck,value=180

actions.main=surrender_to_madness,if=talent.surrender_to_madness.enabled&target.time_to_die<=variable.s2mcheck
actions.main+=/mindbender,if=talent.mindbender.enabled&((talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck+60)|!talent.surrender_to_madness.enabled)
actions.main+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd.max,moving=1,cycle_targets=1
actions.main+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
actions.main+=/shadow_word_pain,if=!talent.misery.enabled&dot.shadow_word_pain.remains<(3+(4%3))*gcd
actions.main+=/vampiric_touch,if=!talent.misery.enabled&dot.vampiric_touch.remains<(4+(4%3))*gcd
actions.main+=/void_eruption,if=insanity>=70|(talent.auspicious_spirits.enabled&insanity>=(65-shadowy_apparitions_in_flight*3))|set_bonus.tier19_4pc
actions.main+=/shadow_crash,if=talent.shadow_crash.enabled
actions.main+=/mindbender,if=talent.mindbender.enabled&set_bonus.tier18_2pc
actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&talent.legacy_of_the_void.enabled&insanity>=70,cycle_targets=1
actions.main+=/vampiric_touch,if=!talent.misery.enabled&!ticking&talent.legacy_of_the_void.enabled&insanity>=70,cycle_targets=1
actions.main+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2&insanity<=(85-15*talent.reaper_of_souls.enabled)
actions.main+=/mind_blast,if=active_enemies<=4&talent.legacy_of_the_void.enabled&(insanity<=81|(insanity<=75.2&talent.fortress_of_the_mind.enabled))
actions.main+=/mind_blast,if=active_enemies<=4&!talent.legacy_of_the_void.enabled|(insanity<=96|(insanity<=95.2&talent.fortress_of_the_mind.enabled))
actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
actions.main+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
actions.main+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
actions.main+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity<=70&talent.legacy_of_the_void.enabled)|(insanity<=85&!talent.legacy_of_the_void.enabled)
actions.main+=/mind_flay,interrupt=1,chain=1
actions.main+=/shadow_word_pain

actions.s2m=void_bolt,if=buff.insanity_drain_stacks.stack<6&set_bonus.tier19_4pc
actions.s2m+=/shadow_crash,if=talent.shadow_crash.enabled
actions.s2m+=/mindbender,if=talent.mindbender.enabled
actions.s2m+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&!buff.power_infusion.up
actions.s2m+=/berserking,if=buff.voidform.stack>=65
actions.s2m+=/shadow_word_death,if=current_insanity_drain*gcd.max>insanity&!buff.power_infusion.up&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled)<100)
actions.s2m+=/power_infusion,if=cooldown.shadow_word_death.charges=0&cooldown.shadow_word_death.remains>3*gcd.max&buff.voidform.stack>50
actions.s2m+=/void_bolt
actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(30+30*talent.reaper_of_souls.enabled))<100
actions.s2m+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
actions.s2m+=/dispersion,if=current_insanity_drain*gcd.max>insanity-5&!buff.power_infusion.up
actions.s2m+=/mind_blast,if=active_enemies<=5
actions.s2m+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=5
actions.s2m+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
actions.s2m+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
actions.s2m+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+50)<100
actions.s2m+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
actions.s2m+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
actions.s2m+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
actions.s2m+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
actions.s2m+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+60)<100&cooldown.shadow_word_death.charges>=1))

actions.vf=surrender_to_madness,if=talent.surrender_to_madness.enabled&insanity>=25&(cooldown.void_bolt.up|cooldown.void_torrent.up|cooldown.shadow_word_death.up|buff.shadowy_insight.up)&target.time_to_die<=variable.s2mcheck-(buff.insanity_drain_stacks.stack)
actions.vf+=/void_bolt
actions.vf+=/shadow_crash,if=talent.shadow_crash.enabled
actions.vf+=/void_torrent,if=dot.shadow_word_pain.remains>5.5&dot.vampiric_touch.remains>5.5&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
actions.vf+=/mindbender,if=talent.mindbender.enabled&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+30))
actions.vf+=/power_infusion,if=buff.insanity_drain_stacks.stack>=(10+2*set_bonus.tier19_2pc+5*buff.bloodlust.up+5*variable.s2mbeltcheck)&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+61))
actions.vf+=/berserking,if=buff.voidform.stack>=10&buff.insanity_drain_stacks.stack<=20&(!talent.surrender_to_madness.enabled|(talent.surrender_to_madness.enabled&target.time_to_die>variable.s2mcheck-(buff.insanity_drain_stacks.stack)+60))
actions.vf+=/void_bolt
actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+(15+15*talent.reaper_of_souls.enabled))<100
actions.vf+=/wait,sec=action.void_bolt.usable_in,if=action.void_bolt.usable_in<gcd.max*0.28
actions.vf+=/mind_blast,if=active_enemies<=4
actions.vf+=/wait,sec=action.mind_blast.usable_in,if=action.mind_blast.usable_in<gcd.max*0.28&active_enemies<=4
actions.vf+=/shadow_word_death,if=(active_enemies<=4|(talent.reaper_of_souls.enabled&active_enemies<=2))&cooldown.shadow_word_death.charges=2
actions.vf+=/shadowfiend,if=!talent.mindbender.enabled,if=buff.voidform.stack>15
actions.vf+=/shadow_word_void,if=talent.shadow_word_void.enabled&(insanity-(current_insanity_drain*gcd.max)+25)<100
actions.vf+=/shadow_word_pain,if=talent.misery.enabled&dot.shadow_word_pain.remains<gcd,moving=1,cycle_targets=1
actions.vf+=/vampiric_touch,if=talent.misery.enabled&(dot.vampiric_touch.remains<3*gcd.max|dot.shadow_word_pain.remains<3*gcd.max),cycle_targets=1
actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&(active_enemies<5|talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled|artifact.sphere_of_insanity.rank)
actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank))
actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&(talent.auspicious_spirits.enabled|talent.shadowy_insight.enabled)),cycle_targets=1
actions.vf+=/vampiric_touch,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<4|talent.sanlayn.enabled|(talent.auspicious_spirits.enabled&artifact.unleash_the_shadows.rank)),cycle_targets=1
actions.vf+=/shadow_word_pain,if=!talent.misery.enabled&!ticking&target.time_to_die>10&(active_enemies<5&artifact.sphere_of_insanity.rank),cycle_targets=1
actions.vf+=/mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(action.void_bolt.usable|(current_insanity_drain*gcd.max>insanity&(insanity-(current_insanity_drain*gcd.max)+30)<100&cooldown.shadow_word_death.charges>=1))
actions.vf+=/shadow_word_pain
]]--

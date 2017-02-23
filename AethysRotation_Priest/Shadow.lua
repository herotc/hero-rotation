--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCore_Cache;
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
		VoidBolt				= Spell(228266),
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
		--CallToTheVoid		
    -- Defensive
		Dispersion				= Spell(47585)
		--Fade
		--PowerWordShield
    -- Utility
		--VampiricEmbrace
    -- Legendaries
    -- Misc
    -- Macros
    
  };
  local S = Spell.Priest.Shadow;
  -- Items
  if not Item.Priest then Item.Priest = {}; end
  Item.Priest.Shadow = {
    -- Legendaries
	MangazasMadness 			= Item(132864), --6
	ZeksExterminatus 			= Item(137100) --15

  };
  local I = Item.Priest.Shadow;
  -- Rotation Var
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    --Commons = AR.GUISettings.APL.Priest.Commons,
    Shadow = AR.GUISettings.APL.Priest.Shadow
  };


--- APL Action Lists (and Variables)
local function executeRange()
	return S.ReaperOfSouls:IsAvailable() and 35 or 20;
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
	local value=0
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
	return value;
end

local function CDs ()

end

local function voidForm()

end

--- APL Main
  local function APL ()
    -- Unit Update
    AC.GetEnemies(40);
    -- Defensives
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if AR.Commons.TargetIsValid() and Target:IsInRange(40) then
        if Player:ComboPoints() >= 5 then
          if S.Nightblade:IsCastable() and not Target:Debuff(S.Nightblade) and Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset then
           if AR.Cast(S.Nightblade) then return "Cast Nightblade (OOC)"; end
          elseif S.Eviscerate:IsCastable() then
           if AR.Cast(S.Eviscerate) then return "Cast Eviscerate (OOC)"; end
          end
        elseif Player:IsStealthed(true, true) then
          if AR.AoEON() and S.ShurikenStorm:IsCastable() and Cache.EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0) then
            if AR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm (OOC)"; end
          elseif S.Shadowstrike:IsCastable() then
            if AR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (OOC)"; end
          end
        elseif S.Backstab:IsCastable() then
          if AR.Cast(S.Backstab) then return "Cast Backstab (OOC)"; end
        end
      end
      -- Opener
      
      return
    end
    -- In Combat
    if AR.Commons.TargetIsValid() then
		if S.MindBlast:IsCastable() and Target:IsInRange(40) then
			if AR.Cast(S.MindBlast) then return "Cast"; end
		end
      
      return;
    end
  end

  AR.SetAPL(258, APL);


--- Last Update: 12/31/2999

-- APL goes here

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
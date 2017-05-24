--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Pet = Unit.Pet;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Mage = AR.Commons.Mage;
  -- Spells
  if not Spell.Mage then Spell.Mage = {}; end
  Spell.Mage.Frost = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    Blizzard                      = Spell(190356),
    BrainFreeze                   = Spell(190446),
    ConeofCold                    = Spell(120),
    FingersofFrost                = Spell(44544),
    Icicles                       = Spell(205473);
    Flurry                        = Spell(44614),
    Freeze                        = Spell(33395,"Pet"),
    FrostNova                     = Spell(122),
    Frostbolt                     = Spell(116),
    FrozenOrb                     = Spell(84714),
    IceLance                      = Spell(30455),
    IcyVeins                      = Spell(12472),
    SummonWaterElemental          = Spell(31687),
    TimeWarp                      = Spell(80353),
    WaterJet                      = Spell(135029,"Pet"),
    WintersChill                  = Spell(228358),
    -- Talents
    BoneChilling                  = Spell(205027),
    BoneChillingBuff              = Spell(205766),
    CometStorm                    = Spell(153595),
    FrostBomb                     = Spell(112948),
    GlacialSpike                  = Spell(199786),
    IceFloes                      = Spell(108839),
    IceNova                       = Spell(157997),
    IncantersFlow                 = Spell(1463),
    LonelyWinter                  = Spell(205024),
    MirrorImage                   = Spell(55342),
    RayofFrost                    = Spell(205021),
    RuneofPower                   = Spell(116011),
    Shimmer                       = Spell(212653),
    SplittingIce                  = Spell(56377),
    ThermalVoid                   = Spell(155149),
    -- Artifact
    Ebonbolt                      = Spell(214634),
    IcyHand                       = Spell(220817),
    -- Defensive
    IceBarrier                    = Spell(11426),
    IceBlock                      = Spell(45438),
    Invisibility                  = Spell(66),
    -- Utility
    ColdSnap                      = Spell(235219),
    Counterspell                  = Spell(2139),
    Spellsteal                    = Spell(30449),
    -- Legendaries
    ZannesuJourney                = Spell(206397),
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Mage.Frost;
  -- Items
  if not Item.Mage then Item.Mage = {}; end
  Item.Mage.Frost = {
    -- Legendaries
    --LadyVashjsGrasp                = Item(132411, {10}) --Left commented out since this APL does not require it (stack and react are identical in AR). If LVG APL gets fully merged it will be needed though so added slot
  };
  local I = Item.Mage.Frost;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local IvStart;
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Mage.Commons,
    Frost = AR.GUISettings.APL.Mage.Frost
  };


--- ======= ACTION LISTS =======
  -- actions+=/variable,name=time_until_fof,value=10-(time-variable.iv_start-floor((time-variable.iv_start)%10)*10)
  local function TimeUntilFoF ()
    return 10 - (AC.CombatTime() - IvStart - math.floor((AC.CombatTime() - IvStart)/10)*10);
  end
  -- actions+=/variable,name=fof_react,value=buff.fingers_of_frost.react
  -- actions+=/variable,name=fof_react,value=buff.fingers_of_frost.stack,if=equipped.lady_vashjs_grasp&buff.icy_veins.up&variable.time_until_fof>9|prev_off_gcd.freeze
  -- NOTE: react == stack on simc (react in fact gives you the number of stack based on reaction time)
  local function FoFReact ()
    return Player:BuffStack(S.FingersofFrost);
  end
  -- # AoE
  local function AoE ()
    if AR.AoEON() then
      -- actions.aoe=frostbolt,if=prev_off_gcd.water_jet
      if S.Frostbolt:IsCastable() and Pet:PrevOffGCD(1, S.WaterJet) then
        if AR.Cast(S.Frostbolt) then return ""; end
      end
      -- actions.aoe+=/frozen_orb
      if S.FrozenOrb:IsCastable() then
        if AR.Cast(S.FrozenOrb) then return ""; end
      end
      -- actions.aoe+=/blizzard
      if S.Blizzard:IsCastable() then
        if AR.Cast(S.Blizzard) then return ""; end
      end
      -- actions.aoe+=/comet_storm
      if S.CometStorm:IsCastable() then
        if AR.Cast(S.CometStorm) then return ""; end
      end
      -- actions.aoe+=/ice_nova
      if S.IceNova:IsCastable() then
        if AR.Cast(S.IceNova) then return ""; end
      end
      -- actions.aoe+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<(2+artifact.icy_hand.enabled)&buff.brain_freeze.react=0
	  if S.IcyHand:ArtifactEnabled() then
	      if S.WaterJet:IsCastable() and (Player:CastID() == S.Frostbolt:ID()) and Player:BuffStack(S.FingersofFrost) < 3 and Player:BuffStack(S.BrainFreeze) == 0 then
			  if AR.Cast(S.WaterJet) then return ""; end
		  end
	  else
		  if S.WaterJet:IsCastable() and (Player:CastID() == S.Frostbolt:ID()) and Player:BuffStack(S.FingersofFrost) < 2 and Player:BuffStack(S.BrainFreeze) == 0 then
			  if AR.Cast(S.WaterJet) then return ""; end
		  end
	  end
      -- actions.aoe+=/flurry,if=prev_gcd.1.ebonbolt|prev_gcd.1.frostbolt&buff.brain_freeze.react
      if S.Flurry:IsCastable() and ((Player:CastID() == S.Ebonbolt:ID()) or ((Player:CastID() == S.Frostbolt:ID()) and Player:Buff(S.BrainFreeze))) then
        if AR.Cast(S.Flurry) then return ""; end
      end
      -- actions.aoe+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&variable.fof_react>0
      if S.FrostBomb:IsCastable() and Target:DebuffRemains(S.FrostBomb) < S.IceLance:TravelTime() and FoFReact() > 0 then
        if AR.Cast(S.FrostBomb) then return ""; end
      end
      -- actions.aoe+=/ice_lance,if=variable.fof_react>0
      if S.IceLance:IsCastable() and FoFReact()> 0 then
        if AR.Cast(S.IceLance) then return ""; end
      end
      -- actions.aoe+=/ebonbolt,if=buff.brain_freeze.react=0
      if S.Ebonbolt:IsCastable() and Player:BuffStack(S.BrainFreeze) == 0 then
        if AR.Cast(S.Ebonbolt) then return ""; end
      end
      -- actions.aoe+=/glacial_spike
      if S.GlacialSpike:IsCastable() and Player:BuffStack(S.Icicles) == 5 then
        if AR.Cast(S.GlacialSpike) then return ""; end
      end
      -- actions.aoe+=/frostbolt
      if S.Frostbolt:IsCastable() then
        if AR.Cast(S.Frostbolt) then return ""; end
      end
    end
  end
  -- # Cooldowns
  local function Cooldowns ()
    if AR.CDsON() then
      -- actions.cooldowns=rune_of_power,if=(cooldown.icy_veins.remains<cast_time|(charges_fractional>1.9&cooldown.icy_veins.remains>10)|buff.icy_veins.up|target.time_to_die.remains+5<charges_fractional*10)
      if S.RuneofPower:IsCastable() and (S.IcyVeins:Cooldown() < S.RuneofPower:CastTime() or (S.RuneofPower:ChargesFractional() > 1.9 and S.IcyVeins:Cooldown() > 10) or Player:Buff(S.IcyVeins) or Target:TimeToDie() + 5 < S.RuneofPower:ChargesFractional() * 10) then
        if AR.Cast(S.RuneofPower) then return ""; end
      end
      -- actions.cooldowns+=/potion,if=cooldown.icy_veins.remains<1
      -- actions.cooldowns+=/variable,name=iv_start,value=time,if=cooldown.icy_veins.ready&buff.icy_veins.down
      IvStart = S.IcyVeins:CooldownUp() and not Player:Buff(S.IcyVeins) and AC.CombatTime() or IvStart;
      -- actions.cooldowns+=/icy_veins,if=buff.icy_veins.down
      if S.IcyVeins:IsCastable() and not Player:Buff(S.IcyVeins) then
        if AR.Cast(S.IcyVeins) then return ""; end
      end
      -- actions.cooldowns+=/mirror_image
      if S.MirrorImage:IsCastable() then
        if AR.Cast(S.MirrorImage) then return ""; end
      end
      -- actions.cooldowns+=/blood_fury
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury) then return ""; end
      end
      -- actions.cooldowns+=/berserking
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking) then return ""; end
      end
      -- actions.cooldowns+=/arcane_torrent
	  -- Torrent has no impact on frost dps we just do it in SIMC to be lazy (since arc likes it), let user handle their own for interrupts
    end
  end
  -- # Single
  local function Single ()
    -- actions.single=ice_nova,if=debuff.winters_chill.up
    if S.IceNova:IsCastable() and Target:Debuff(S.WintersChill) then
      if AR.Cast(S.IceNova) then return ""; end
    end
    -- actions.single+=/frostbolt,if=prev_off_gcd.water_jet
    if S.Frostbolt:IsCastable() and Pet:PrevOffGCD(1, S.WaterJet) and Target:DebuffRemains(S.WaterJet) > (S.Frostbolt:TravelTime() + S.Frostbolt:CastTime()) then
      if AR.Cast(S.Frostbolt) then return ""; end
    end
    -- actions.single+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<(2+artifact.icy_hand.enabled)&buff.brain_freeze.react=0
	if S.IcyHand:ArtifactEnabled() then
	    if S.WaterJet:IsCastable() and (Player:CastID() == S.Frostbolt:ID()) and Player:BuffStack(S.FingersofFrost) < 3 and Player:BuffStack(S.BrainFreeze) == 0 then
			if AR.Cast(S.WaterJet) then return ""; end
		end
	else
		if S.WaterJet:IsCastable() and (Player:CastID() == S.Frostbolt:ID()) and Player:BuffStack(S.FingersofFrost) < 2 and Player:BuffStack(S.BrainFreeze) == 0 then
			if AR.Cast(S.WaterJet) then return ""; end
		end
	end
    -- actions.single+=/ray_of_frost,if=buff.icy_veins.up|(cooldown.icy_veins.remains>action.ray_of_frost.cooldown&buff.rune_of_power.down)
    if S.RayofFrost:IsCastable() and (Player:Buff(S.IcyVeins) or (S.IcyVeins:Cooldown() > S.RayofFrost:Cooldown() and not Player:Buff(S.RuneofPower))) then
      if AR.Cast(S.RayofFrost) then return ""; end
    end
    -- actions.single+=/flurry,if=prev_gcd.1.ebonbolt|prev_gcd.1.frostbolt&buff.brain_freeze.react
    if S.Flurry:IsCastable() and ((Player:CastID() == S.Ebonbolt:ID()) or ((Player:CastID() == S.Frostbolt:ID()) and Player:Buff(S.BrainFreeze))) then
      if AR.Cast(S.Flurry) then return ""; end
    end
    -- actions.single+=/blizzard,if=cast_time=0&active_enemies>1&variable.fof_react<3
    if S.Blizzard:IsCastable() and S.Blizzard:CastTime() == 0 and Cache.EnemiesCount[40] > 1 and FoFReact() < 3 then
      if AR.Cast(S.Blizzard) then return ""; end
    end
    -- actions.single+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&variable.fof_react>0
    if S.FrostBomb:IsCastable() and Target:DebuffRemains(S.FrostBomb) < S.IceLance:TravelTime() and FoFReact() > 0 then
      if AR.Cast(S.FrostBomb) then return ""; end
    end
    -- actions.single+=/ice_lance,if=variable.fof_react>0&cooldown.icy_veins.remains>10|variable.fof_react>2
    if S.IceLance:IsCastable() and ((FoFReact() > 0 and S.IcyVeins:Cooldown() > 10) or FoFReact() > 2) then
      if AR.Cast(S.IceLance) then return ""; end
    end
    -- actions.single+=/frozen_orb
    if S.FrozenOrb:IsCastable() then
      if AR.Cast(S.FrozenOrb) then return ""; end
    end
    -- actions.single+=/ice_nova
    if S.IceNova:IsCastable() then
      if AR.Cast(S.IceNova) then return ""; end
    end
    -- actions.single+=/comet_storm
    if S.CometStorm:IsCastable() then
      if AR.Cast(S.CometStorm) then return ""; end
    end
    -- actions.single+=/blizzard,if=active_enemies>2|active_enemies>1&!(talent.glacial_spike.enabled&talent.splitting_ice.enabled)|(buff.zannesu_journey.stack=5&buff.zannesu_journey.remains>cast_time)
    -- todo verif
    if S.Blizzard:IsCastable() and (Cache.EnemiesCount[40] > 2 or (Cache.EnemiesCount[40] > 1 and not (S.GlacialSpike:IsAvailable() and S.SplittingIce:IsAvailable())) or (Player:BuffStack(S.ZannesuJourney) == 5 and Player:BuffRemains(S.ZannesuJourney) > S.Blizzard:CastTime())) then
      if AR.Cast(S.Blizzard) then return ""; end
    end
    -- actions.single+=/ebonbolt,if=buff.brain_freeze.react=0
    if S.Ebonbolt:IsCastable() and Player:BuffStack(S.BrainFreeze) == 0 then
      if AR.Cast(S.Ebonbolt) then return ""; end
    end
    -- actions.single+=/glacial_spike
    if S.GlacialSpike:IsCastable() and Player:BuffStack(S.Icicles) == 5 then
      if AR.Cast(S.GlacialSpike) then return ""; end
    end
    -- actions.single+=/frostbolt
    if S.Frostbolt:IsCastable() then
      if AR.Cast(S.Frostbolt) then return ""; end
    end
  end



--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(40);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
	  if Pet:IsActive() == false and S.SummonWaterElemental:IsCastable() then
		if AR.Cast(S.SummonWaterElemental) then return; end
	  end
      if Everyone.TargetIsValid() and Target:IsInRange(40) then
        if S.Ebonbolt:IsCastable() then
          if AR.CastQueue(S.Ebonbolt, S.Flurry) then return; end
        end
        if S.Frostbolt:IsCastable() then
          if AR.Cast(S.Frostbolt) then return; end
        end
      end
      return;
    end
    -- In Combat
	if Pet:IsActive() == false and S.SummonWaterElemental:IsCastable() then
		if AR.Cast(S.SummonWaterElemental) then return ""; end
	end
    if Everyone.TargetIsValid() then
      -- actions+=/ice_lance,if=variable.fof_react=0&prev_gcd.1.flurry
      if S.IceLance:IsCastable() and FoFReact()== 0 and Player:PrevGCD(1, S.Flurry) then
        if AR.Cast(S.IceLance) then return ""; end
      end
      -- actions+=/time_warp,if=(time=0&buff.bloodlust.down)|(buff.bloodlust.down&equipped.132410&(cooldown.icy_veins.remains<1|target.time_to_die<50))
      -- actions+=/call_action_list,name=cooldowns
      ShouldReturn = Cooldowns();
      if ShouldReturn then return ShouldReturn; end
      -- actions+=/call_action_list,name=aoe,if=active_enemies>=4
      if Cache.EnemiesCount[40] >= 4 then
        ShouldReturn = AoE();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=single
      ShouldReturn = Single();
      if ShouldReturn then return ShouldReturn; end
      return;
    end
  end

  AR.SetAPL(64, APL);


--- ======= SIMC =======
--- Last Update: 05/12/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation,type=defiled
-- actions.precombat+=/water_elemental
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/mirror_image
-- actions.precombat+=/potion
-- actions.precombat+=/frostbolt

-- # Executed every time the actor is available.
-- actions=counterspell,if=target.debuff.casting.react
-- actions+=/variable,name=time_until_fof,value=10-(time-variable.iv_start-floor((time-variable.iv_start)%10)*10)
-- actions+=/variable,name=fof_react,value=buff.fingers_of_frost.react
-- actions+=/variable,name=fof_react,value=buff.fingers_of_frost.stack,if=equipped.lady_vashjs_grasp&buff.icy_veins.up&variable.time_until_fof>9|prev_off_gcd.freeze
-- actions+=/ice_lance,if=variable.fof_react=0&prev_gcd.1.flurry
-- actions+=/time_warp,if=(time=0&buff.bloodlust.down)|(buff.bloodlust.down&equipped.132410&(cooldown.icy_veins.remains<1|target.time_to_die<50))
-- actions+=/call_action_list,name=cooldowns
-- actions+=/call_action_list,name=aoe,if=active_enemies>=4
-- actions+=/call_action_list,name=single

-- actions.aoe=frostbolt,if=prev_off_gcd.water_jet
-- actions.aoe+=/frozen_orb
-- actions.aoe+=/blizzard
-- actions.aoe+=/comet_storm
-- actions.aoe+=/ice_nova
-- actions.aoe+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<(2+artifact.icy_hand.enabled)&buff.brain_freeze.react=0
-- actions.aoe+=/flurry,if=prev_gcd.1.ebonbolt|prev_gcd.1.frostbolt&buff.brain_freeze.react
-- actions.aoe+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&variable.fof_react>0
-- actions.aoe+=/ice_lance,if=variable.fof_react>0
-- actions.aoe+=/ebonbolt,if=buff.brain_freeze.react=0
-- actions.aoe+=/glacial_spike
-- actions.aoe+=/frostbolt

-- actions.cooldowns=rune_of_power,if=cooldown.icy_veins.remains<cast_time|charges_fractional>1.9&cooldown.icy_veins.remains>10|buff.icy_veins.up|target.time_to_die.remains+5<charges_fractional*10
-- actions.cooldowns+=/potion,if=cooldown.icy_veins.remains<1
-- actions.cooldowns+=/variable,name=iv_start,value=time,if=cooldown.icy_veins.ready&buff.icy_veins.down
-- actions.cooldowns+=/icy_veins,if=buff.icy_veins.down
-- actions.cooldowns+=/mirror_image
-- actions.cooldowns+=/blood_fury
-- actions.cooldowns+=/berserking
-- actions.cooldowns+=/arcane_torrent

-- actions.single=ice_nova,if=debuff.winters_chill.up
-- actions.single+=/frostbolt,if=prev_off_gcd.water_jet
-- actions.single+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<(2+artifact.icy_hand.enabled)&buff.brain_freeze.react=0
-- actions.single+=/ray_of_frost,if=buff.icy_veins.up|(cooldown.icy_veins.remains>action.ray_of_frost.cooldown&buff.rune_of_power.down)
-- actions.single+=/flurry,if=prev_gcd.1.ebonbolt|prev_gcd.1.frostbolt&buff.brain_freeze.react
-- actions.single+=/blizzard,if=cast_time=0&active_enemies>1&variable.fof_react<3
-- actions.single+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&variable.fof_react>0
-- actions.single+=/ice_lance,if=variable.fof_react>0&cooldown.icy_veins.remains>10|variable.fof_react>2
-- actions.single+=/frozen_orb
-- actions.single+=/ice_nova
-- actions.single+=/comet_storm
-- actions.single+=/blizzard,if=active_enemies>2|active_enemies>1&!(talent.glacial_spike.enabled&talent.splitting_ice.enabled)|(buff.zannesu_journey.stack=5&buff.zannesu_journey.remains>cast_time)
-- actions.single+=/ebonbolt,if=buff.brain_freeze.react=0
-- actions.single+=/glacial_spike
-- actions.single+=/frostbolt

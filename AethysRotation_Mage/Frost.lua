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
  ArcaneTorrent        = Spell(25046),
  Berserking           = Spell(26297),
  BloodFury            = Spell(20572),
  GiftoftheNaaru       = Spell(59547),
  Shadowmeld           = Spell(58984),
  
  -- Abilities
  Blizzard             = Spell(190356),
  BrainFreeze          = Spell(190446),
  ConeofCold           = Spell(120),
  FingersofFrost       = Spell(44544),
  Icicles              = Spell(205473);
  Flurry               = Spell(44614),
  Freeze               = Spell(33395,"Pet"),
  FrostNova            = Spell(122),
  Frostbolt            = Spell(116),
  FrozenOrb            = Spell(84714),
  IceLance             = Spell(30455),
  IcyVeins             = Spell(12472),
  SummonWaterElemental = Spell(31687),
  TimeWarp             = Spell(80353),
  WaterJet             = Spell(135029,"Pet"),
  WintersChill         = Spell(228358),
  FreezingRain         = Spell(240555),
  
  
  -- Talents
  RayofFrost           = Spell(205021),
  LonelyWinter         = Spell(205024),
  BoneChilling         = Spell(205027),
  BoneChillingBuff     = Spell(205766),
  
  Shimmer              = Spell(212653),
  IceFloes             = Spell(108839),
  GlacialInsulation    = Spell(235297),
  
  MirrorImage          = Spell(55342),
  RuneofPower          = Spell(116011),
  IncantersFlow        = Spell(1463),
  
  IceNova              = Spell(157997),
  FrozenTouch          = Spell(205030),
  SplittingIce         = Spell(56377),
  
  FrostBomb            = Spell(112948),
  UnstableMagic        = Spell(157976),
  ArticGale            = Spell(205038),
  
  ThermalVoid          = Spell(155149),
  GlacialSpike         = Spell(199786),
  GlacialSpikeBuff     = Spell(199844),
  CometStorm           = Spell(153595),
  
  -- Artifact
  Ebonbolt             = Spell(214634),
  IcyHand              = Spell(220817),
  
  -- Defensive
  IceBarrier           = Spell(11426),
  IceBlock             = Spell(45438),
  Invisibility         = Spell(66),
  
  -- Utility
  ColdSnap             = Spell(235219),
  Counterspell         = Spell(2139),
  Spellsteal           = Spell(30449),
  
  -- Legendaries
  ZannesuJourney       = Spell(206397),
  
  -- Misc
  FrozenMass           = Spell(242253),  -- Frozen Mass Tier 20 2pc bonus
  
  -- Macros
};
local S = Spell.Mage.Frost;

-- Items
if not Item.Mage then Item.Mage = {}; end
Item.Mage.Frost = {
  PotionofProlongedPower   = Item(142117), -- We define the potion to use it later
  -- Legendaries
  -- LadyVashjsGrasp          = Item(132411, {10}) --Left commented out since this APL does not require it (stack and react are identical in AR). If LVG APL gets fully merged it will be needed though so added slot
};
local I = Item.Mage.Frost;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local IvStart;
local Range = 40

-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Mage.Commons,
  Frost = AR.GUISettings.APL.Mage.Frost
};
--- ======= ACTION LISTS =======

local function Movement ()
  -- actions.movement=blink,if=movement.distance>10

  -- actions.movement+=/ice_floes,if=buff.ice_floes.down&!buff.fingers_of_frost.react
  if S.IceFloes:IsAvailable() and S.IceFloes:ChargesP() > 0 and not Player:Buff(S.IceFloes) and not Player:Buff(S.FingersofFrost) then
    if AR.Cast(S.IceFloes, Settings.Frost.OffGCDasOffGCD.IceFloes) then return ""; end
  end
end

-- # Start of AOE APL
local function AoE ()
  -- actions.aoe=frostbolt,if=prev_off_gcd.water_jet
  if S.Frostbolt:IsCastableP() and Pet:PrevOffGCD(1, S.WaterJet) then
    if AR.Cast(S.Frostbolt) then return ""; end
  end
  -- actions.aoe+=/frozen_orb
  if S.FrozenOrb:IsCastableP() then
    if AR.Cast(S.FrozenOrb) then return ""; end
  end
  -- actions.aoe+=/blizzard
  if S.Blizzard:IsCastableP() then
    if AR.Cast(S.Blizzard) then return ""; end
  end
  -- actions.aoe+=/comet_storm
  if S.CometStorm:IsCastableP() then
    if AR.Cast(S.CometStorm) then return ""; end
  end
  -- actions.aoe+=/ice_nova
  if S.IceNova:IsCastableP() then
    if AR.Cast(S.IceNova) then return ""; end
  end
  -- actions.aoe+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<3&!buff.brain_freeze.react
  if S.WaterJet:IsCastableP() and Player:PrevGCDP(1, S.Frostbolt) and Player:BuffStack(S.FingersofFrost) < 3 and not Player:Buff(S.BrainFreeze) then
    if AR.Cast(S.WaterJet) then return ""; end
  end
  -- actions.aoe+=/flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt)
  if Player:PrevGCDP(1, S.Ebonbolt) or (Player:Buff(S.BrainFreeze) and (Player:PrevGCDP(1, S.GlacialSpike) or Player:PrevGCDP(1, S.Frostbolt))) then 
    if AR.Cast (S.Flurry) then return ""; end
  end
  -- actions.aoe+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&buff.fingers_of_frost.react
  if S.FrostBomb:IsCastableP() and Target:DebuffRemainsP(S.FrostBomb) < S.IceLance:TravelTime() and Player:BuffStack(S.FingersofFrost) > 0 then
    if AR.Cast(S.FrostBomb) then return ""; end
  end
  -- actions.aoe+=/ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsCastableP() and Player:BuffStack(S.FingersofFrost) > 0 then
    if AR.Cast(S.IceLance) then return ""; end
  end
  -- actions.aoe+=/ebonbolt
  if S.Ebonbolt:IsCastableP() then
    if AR.Cast(S.Ebonbolt) then return ""; end
  end
  -- actions.aoe+=/glacial_spike
  if Player:Buff(S.GlacialSpikeBuff) or (Player:BuffStack(S.Icicles) == 4 and Player:IsCasting(S.Frostbolt)) and not Player:IsCasting(S.GlacialSpike) then
    if AR.Cast(S.GlacialSpike) then return ""; end
  end
  -- actions.aoe+=/frostbolt
  if S.Frostbolt:IsCastableP() then
    if AR.Cast(S.Frostbolt) then return ""; end
  end
  -- actions.aoe+=/cone_of_cold
  if S.ConeofCold:IsCastableP() then
    if AR.Cast(S.ConeofCold) then return ""; end
  end
  -- actions.aoe+=/iceLance
  if S.IceLance:IsCastableP() then
    if AR.Cast(S.IceLance) then return ""; end
  end
end

-- # Start of Cooldown APL
local function Cooldowns ()
  -- actions.cooldowns=rune_of_power,if=cooldown.icy_veins.remains<cast_time|charges_fractional>1.9&cooldown.icy_veins.remains>10|buff.icy_veins.up|target.time_to_die+5<charges_fractional*10
  if S.RuneofPower:IsCastable() and (S.IcyVeins:CooldownRemains() < S.RuneofPower:CastTime() or (S.RuneofPower:ChargesFractional() > 1.9 and S.IcyVeins:CooldownRemains() > 10) or Player:Buff(S.IcyVeins) or Target:TimeToDie() + 5 < S.RuneofPower:ChargesFractional() * 10) and not Player:IsCasting(S.RuneofPower) then
    if AR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return ""; end
  end
  -- actions.cooldowns+=/potion,if=cooldown.icy_veins.remains<1|target.time_to_die<70
  if I.PotionofProlongedPower:IsUsable() and Settings.Frost.ShowPoPP and I.PotionofProlongedPower:CooldownRemainsP() == 0 and (S.IcyVeins:CooldownRemains() == 0 or Player:BuffRemains(S.IcyVeins) > 0) or Target:TimeToDie() < 70 then
   if AR.CastSuggested(I.PotionofProlongedPower) then return ""; end
  end
  -- actions.cooldowns+=/icy_veins
  if S.IcyVeins:IsCastable() then
    if AR.Cast(S.IcyVeins, Settings.Frost.OffGCDasOffGCD.IcyVeins) then return ""; end
  end
  -- actions.cooldowns+=/mirror_image
  if S.MirrorImage:IsCastable() then
    if AR.Cast(S.MirrorImage, Settings.Frost.OffGCDasOffGCD.RuneofPower) then return ""; end
  end
  -- actions.cooldowns+=/blood_fury
  if S.BloodFury:IsCastable() then
    if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- actions.cooldowns+=/berserking
  if S.Berserking:IsCastable() then
    if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- actions.cooldowns+=/arcane_torrent
  -- Torrent has no impact on frost dps we just do it in SIMC to be lazy (since arc likes it), let user handle their own for interrupts
end

-- # Start of Single APL
local function Single ()
  -- actions.single=ice_nova,if=debuff.winters_chill.up
  if S.IceNova:IsCastableP() and Target:Debuff(S.WintersChill) then
    if AR.Cast(S.IceNova) then return ""; end
  end
  -- actions.single+=/frostbolt,if=prev_off_gcd.water_jet
  if S.Frostbolt:IsCastableP() and Pet:PrevOffGCD(1, S.WaterJet) and Target:DebuffRemainsP(S.WaterJet) > (S.Frostbolt:TravelTime() + S.Frostbolt:CastTime()) then
    if AR.Cast(S.Frostbolt) then return ""; end
  end
  -- actions.single+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<3&!buff.brain_freeze.react
  if S.WaterJet:IsCastableP() and Player:PrevGCDP(1, S.Frostbolt) and Player:BuffStack(S.FingersofFrost) < 3 and not Player:Buff(S.BrainFreeze) then
    if AR.Cast(S.WaterJet) then return ""; end
  end
  -- actions.single+=/ray_of_frost,if=buff.icy_veins.up|cooldown.icy_veins.remains>action.ray_of_frost.cooldown&buff.rune_of_power.down
  if S.RayofFrost:IsCastableP() and (Player:Buff(S.IcyVeins) or (S.IcyVeins:CooldownRemainsP() > S.RayofFrost:CooldownRemainsP() and not Player:Buff(S.RuneofPower))) then
    if AR.Cast(S.RayofFrost) then return ""; end
  end
  -- actions.single+=/flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<=4|cooldown.frozen_orb.remains<=10&set_bonus.tier20_2pc))
  if (Player:PrevGCDP(1, S.Ebonbolt) or Player:Buff(S.BrainFreeze) 
    and (Player:PrevGCDP(1, S.GlacialSpike) or (Player:PrevGCDP(1, S.Frostbolt) and (not S.GlacialSpike:IsAvailable() or Player:BuffStack(S.Icicles) <= 4 or (S.FrozenOrb:CooldownRemainsP() <= 10 and AC.Tier20_2Pc))))) then 
      if AR.Cast (S.Flurry) then return ""; end
  end
  -- actions.single+=/frozen_orb,if=set_bonus.tier20_2pc&buff.fingers_of_frost.react<3
  if S.FrozenOrb:IsCastableP() and AC.Tier20_2Pc and Player:BuffStack(S.FingersofFrost) < 3 then
    if AR.Cast(S.FrozenOrb) then return ""; end
  end
  -- actions.single+=/blizzard,if=cast_time=0&active_enemies>1&buff.fingers_of_frost.react<3
  if S.Blizzard:IsCastableP() and Player:BuffRemainsP(S.FreezingRain) > 0 and Cache.EnemiesCount[Range] > 1 and Player:BuffStack(S.FingersofFrost) < 3 then
    if AR.Cast(S.Blizzard) then return ""; end
  end
  -- actions.single+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&buff.fingers_of_frost.react
  if S.FrostBomb:IsCastableP() and Target:DebuffRemainsP(S.FrostBomb) < S.IceLance:TravelTime() and Player:BuffStack(S.FingersofFrost) > 0 then
    if AR.Cast(S.FrostBomb) then return ""; end
  end
  -- actions.single+=/ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsCastableP() and Player:BuffStack(S.FingersofFrost) > 0 then
    if AR.Cast(S.IceLance) then return ""; end
  end
  -- actions.single+=/ebonbolt
  if S.Ebonbolt:IsCastableP() then
    if AR.Cast(S.Ebonbolt) then return ""; end
  end
  -- actions.single+=/frozen_orb
  if S.FrozenOrb:IsCastableP() then
    if AR.Cast(S.FrozenOrb) then return ""; end
  end
  -- actions.single+=/ice_nova
  if S.IceNova:IsCastableP() then
    if AR.Cast(S.IceNova) then return ""; end
  end
  -- actions.single+=/comet_storm
  if S.CometStorm:IsCastableP() then
    if AR.Cast(S.CometStorm) then return ""; end
  end
  -- actions.single+=/blizzard,if=active_enemies>1|buff.zannesu_journey.stack=5&buff.zannesu_journey.remains>cast_time
  -- todo verif
  if S.Blizzard:IsCastableP() and (Cache.EnemiesCount[Range] > 1 or (Player:BuffStack(S.ZannesuJourney) == 5 and Player:BuffRemainsP(S.ZannesuJourney) > S.Blizzard:CastTime())) then
    if AR.Cast(S.Blizzard) then return ""; end
  end
  -- actions.single+=/frostbolt,if=buff.frozen_mass.remains>execute_time+action.glacial_spike.execute_time+action.glacial_spike.travel_time&!buff.brain_freeze.react&talent.glacial_spike.enabled
  if S.GlacialSpike:IsAvailable() and Player:BuffRemainsP(S.FrozenMass) > (S.Frostbolt:ExecuteTime() + S.GlacialSpike:ExecuteTime() + S.GlacialSpike:TravelTime()) and not Player:Buff(S.BrainFreeze) and S.GlacialSpike:IsAvailable() then
    if AR.Cast(S.Frostbolt) then return ""; end
  end
  -- actions.single+=/glacial_spike,if=cooldown.frozen_orb.remains>10|!set_bonus.tier20_2pc
  if S.GlacialSpike:IsAvailable() and (Player:Buff(S.GlacialSpikeBuff) or (Player:BuffStack(S.Icicles) == 4 and Player:IsCasting(S.Frostbolt))) and not Player:IsCasting(S.GlacialSpike) and S.FrozenOrb:CooldownRemainsP() > 10 and not AC.Tier20_2Pc  then
    if AR.Cast(S.GlacialSpike) then return ""; end
  end
  -- actions.single+=/frostbolt
  if S.Frostbolt:IsCastableP() then
    if AR.Cast(S.Frostbolt) then return ""; end
  end
  -- actions.single+=/blizzard (instant, on the move)
  -- actions.single+=/ice_lance (on the move)
end

--- ======= MAIN =======
local function APL ()
	-- Unit Update
	AC.GetEnemies(Range);
	Everyone.AoEToggleEnemiesUpdate();
  
	-- Defensives

	-- Out of Combat
	if not Player:AffectingCombat() then
		-- Flask
		-- Food
		-- Rune
		-- PrePot w/ Bossmod Countdown
		-- Opener
		if not Pet:IsActive() and S.SummonWaterElemental:IsCastable() then
			if AR.Cast(S.SummonWaterElemental) then return; end
		end
		if Everyone.TargetIsValid() and Target:IsInRange(Range) then
			if S.Ebonbolt:IsCastable() and not Player:IsCasting(S.Ebonbolt) then
        -- if AR.CastQueue(S.Ebonbolt, S.Flurry) then return; end
        if AR.Cast(S.Ebonbolt) then return; end
			end
      if Player:IsCasting(S.Ebonbolt) then
        if AR.Cast(S.Flurry) then return; end
      end
			if S.Frostbolt:IsCastable() then
        if AR.Cast(S.Frostbolt) then return; end
			end
		end
		return;
	end
  
	-- In Combat
	if not Pet:IsActive() and S.SummonWaterElemental:IsCastable() then
    if AR.Cast(S.SummonWaterElemental) then return ""; end
	end
	if Everyone.TargetIsValid() then
    -- actions=counterspell
    
    -- actions+=/ice_lance,if=!buff.fingers_of_frost.react&prev_gcd.1.flurry
    if S.IceLance:IsCastable() and not Player:Buff(S.FingersofFrost) and Player:PrevGCDP(1, S.Flurry) then
      if AR.Cast(S.IceLance) then return ""; end
    end
    
    -- actions+=/time_warp,if=buff.bloodlust.down&(buff.exhaustion.down|equipped.shard_of_the_exodar)&(cooldown.icy_veins.remains<1|target.time_to_die<50)    
    
    
    -- actions+=/call_action_list,name=movement,moving=1
    if Player:IsMoving() then
      ShouldReturn = Movement();
      if ShouldReturn then return ShouldReturn; end
    end
    
    -- actions+=/call_action_list,name=cooldowns
    if AR.CDsON() then
      ShouldReturn = Cooldowns();
      if ShouldReturn then return ShouldReturn; end
    end
    
    -- actions+=/call_action_list,name=aoe,if=active_enemies>=3
    if Cache.EnemiesCount[Range] >= 3 then
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
--- Last Update: 11/28/2017
-- # Executed every time the actor is available.
-- actions=counterspell
-- # Free Ice Lance after Flurry. This action has rather high priority to ensure that we don't cast Rune of Power, Ray of Frost, etc. after Flurry and break up the combo. If FoF was already active, we do not lose anything by delaying the Ice Lance.
-- actions+=/ice_lance,if=!buff.fingers_of_frost.react&prev_gcd.1.flurry
-- # Time Warp is used right at the start. If the actor has Shard of the Exodar, try to synchronize the second Time Warp with Icy Veins. If the target is about to die, use Time Warp regardless.
-- actions+=/time_warp,if=buff.bloodlust.down&(buff.exhaustion.down|equipped.shard_of_the_exodar)&(cooldown.icy_veins.remains<1|target.time_to_die<50)
-- actions+=/call_action_list,name=movement,moving=1
-- actions+=/call_action_list,name=cooldowns
-- actions+=/call_action_list,name=aoe,if=active_enemies>=3
-- actions+=/call_action_list,name=single

-- actions.aoe=frostbolt,if=prev_off_gcd.water_jet
-- # Make sure Frozen Orb is used before Blizzard if both are available. This is a small gain with Freezing Rain and on par without.
-- actions.aoe+=/frozen_orb
-- actions.aoe+=/blizzard
-- actions.aoe+=/comet_storm
-- actions.aoe+=/ice_nova
-- actions.aoe+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<3&!buff.brain_freeze.react
-- actions.aoe+=/flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt)
-- actions.aoe+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&buff.fingers_of_frost.react
-- actions.aoe+=/ice_lance,if=buff.fingers_of_frost.react
-- actions.aoe+=/ebonbolt
-- actions.aoe+=/glacial_spike
-- actions.aoe+=/frostbolt
-- actions.aoe+=/cone_of_cold
-- actions.aoe+=/ice_lance

-- # Rune of Power is used when going into Icy Veins and while Icy Veins are up. Outside of Icy Veins, use Rune of Power when about to cap on charges or the target is about to die.
-- actions.cooldowns=rune_of_power,if=cooldown.icy_veins.remains<cast_time|charges_fractional>1.9&cooldown.icy_veins.remains>10|buff.icy_veins.up|target.time_to_die+5<charges_fractional*10
-- actions.cooldowns+=/potion,if=cooldown.icy_veins.remains<1|target.time_to_die<70
-- actions.cooldowns+=/icy_veins
-- actions.cooldowns+=/mirror_image
-- actions.cooldowns+=/use_items
-- actions.cooldowns+=/blood_fury
-- actions.cooldowns+=/berserking
-- actions.cooldowns+=/arcane_torrent

-- actions.movement=blink,if=movement.distance>10
-- actions.movement+=/ice_floes,if=buff.ice_floes.down&!buff.fingers_of_frost.react

-- # In some circumstances, it is possible for both Ice Lance and Ice Nova to benefit from a single Winter's Chill.
-- actions.single=ice_nova,if=debuff.winters_chill.up
-- actions.single+=/frostbolt,if=prev_off_gcd.water_jet
-- # Basic Water Jet combo. Since Water Jet can only be used if the actor is not casting, we use it right after Frostbolt is executed. At the default distance, Frostbolt travels slightly over 1 s, giving Water Jet enough time to apply the DoT (Water Jet's cast time is 1 s, with haste scaling). The APL then forces another Frostbolt to guarantee getting both FoFs from the Water Jet. This works for most haste values (roughly from 0% to 160%). When changing the default distance, great care must be taken otherwise this action won't produce two FoFs.
-- actions.single+=/water_jet,if=prev_gcd.1.frostbolt&buff.fingers_of_frost.stack<3&!buff.brain_freeze.react
-- actions.single+=/ray_of_frost,if=buff.icy_veins.up|cooldown.icy_veins.remains>action.ray_of_frost.cooldown&buff.rune_of_power.down
-- # Winter's Chill from Flurry can apply to the spell cast right before (provided the travel time is long enough). This can be exploited to a great effect with Ebonbolt, Glacial Spike (which deal a lot of damage by themselves) and Frostbolt (as a guaranteed way to proc Frozen Veins and Chain Reaction). When using Glacial Spike, it is worth saving a Brain Freeze proc when Glacial Spike is right around the corner (i.e. with 5 Icicles). However, when the actor also has T20 2pc, Glacial Spike is delayed to fit into Frozen Mass, so we do not want to sit on a Brain Freeze proc for too long in that case.
-- actions.single+=/flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<=4|cooldown.frozen_orb.remains<=10&set_bonus.tier20_2pc))
-- # With T20 2pc, Frozen Orb should be used as soon as it comes off CD.
-- actions.single+=/frozen_orb,if=set_bonus.tier20_2pc&buff.fingers_of_frost.react<3
-- # Freezing Rain Blizzard. While the normal Blizzard action is usually enough, right after Frozen Orb the actor will be getting a lot of FoFs, which might delay Blizzard to the point where we miss out on Freezing Rain. Therefore, if we are not at a risk of overcapping on FoF, use Blizzard before using Ice Lance.
-- actions.single+=/blizzard,if=cast_time=0&active_enemies>1&buff.fingers_of_frost.react<3
-- actions.single+=/frost_bomb,if=debuff.frost_bomb.remains<action.ice_lance.travel_time&buff.fingers_of_frost.react
-- actions.single+=/ice_lance,if=buff.fingers_of_frost.react
-- actions.single+=/ebonbolt
-- actions.single+=/frozen_orb
-- actions.single+=/ice_nova
-- actions.single+=/comet_storm
-- # Against low number of targets, Blizzard is used as a filler. Zann'esu buffed Blizzard is used only at 5 stacks.
-- actions.single+=/blizzard,if=active_enemies>1|buff.zannesu_journey.stack=5&buff.zannesu_journey.remains>cast_time
-- # While Frozen Mass is active, we want to fish for Brain Freeze for the next Glacial Spike. Stop when Frozen Mass is about to run out and we wouldn't be able to cast Glacial Spike in time.
-- actions.single+=/frostbolt,if=buff.frozen_mass.remains>execute_time+action.glacial_spike.execute_time+action.glacial_spike.travel_time&!buff.brain_freeze.react&talent.glacial_spike.enabled
-- # Glacial Spike is generally used as it is available, unless we have T20 2pc. In that case, Glacial Spike is delayed when Frozen Mass is happening soon (in less than 10 s).
-- actions.single+=/glacial_spike,if=cooldown.frozen_orb.remains>10|!set_bonus.tier20_2pc
-- actions.single+=/frostbolt
-- # While on the move, use instant Blizzard if available.
-- actions.single+=/blizzard
-- # Otherwise just use Ice Lance to do at least some damage.
-- actions.single+=/ice_lance

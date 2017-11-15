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

     Spell.Mage.Fire = {
      -- Racials
      ArcaneTorrent                 = Spell(25046),
      Berserking                    = Spell(26297),
      BloodFury                     = Spell(20572),
      GiftoftheNaaru                = Spell(59547),
      Shadowmeld                    = Spell(58984),
      -- Abilities
      Fireball                      = Spell(133),
      Pyroblast                     = Spell(147720),
      CriticalMass                  = Spell(117216),
      Fireblast                     = Spell(108853),
      HotStreak                     = Spell(195283),
      EnchancedPyrotechnics         = Spell(157642),
      DragonsBreath                 = Spell(31661),
      Combustion                    = Spell(190319),
      Scorch                        = Spell(2948),
      Flamestrike                   = Spell(2120),
      -- Talents
      Pyromaniac                    = Spell(205020),
      Conflagaration                = Spell(205023),
      Firestarter                   = Spell(205026),
      MirrorImage                   = Spell(55342),
      RuneofPower                   = Spell(116011),
      IncantersFlow                 = Spell(1463),
      AlexstraszasFury              = Spell(235870),
      FlameOn                       = Spell(205029),
      ControlledBurn                = Spell(205033),
      LivingBomb                    = Spell(44457),
      FlamePatch                    = Spell(205037),
      Kindling                      = Spell(155148),
      Cinderstorm                   = Spell(198929),
      Meteor                        = Spell(153561),
      -- Artifact
      PheonixFlames                 = Spell(194466),
      -- Defensive
      IceBarrier                    = Spell(11426),
      IceBlock                      = Spell(45438),
      Invisibility                  = Spell(66),
      -- Legendaries
      MarqueeBindingsoftheSunKing   = Spell(132406),
      KoralonsBurningTouch          = Spell(132454),
      ShardOfExodar                 = Spell(132410),
      CantainedInfernalCore         = Spell(151809),
      SoulOfTheArchmage             = Spell(151642),
      PyrotexIgnitionCloth          = Spell(144355),
      SephuzsSecret                 = Spell(132452),
      KiljadensBurningWish          = Spell(144259),
      DarckilsDragonfireDiadem      = Spell(132863),
      NorgannonsForesight           = Spell(132455),
      BelovirsFinalStand            = Spell(133977),
      PrydazXavaricsMagnumOpus      = Spell(132444),
      -- Legendary Procs
      KaelthassUltimateAbility      = Spell(209455),  -- Fire Mage Bracer Procs
      ContainedInfernalCoreBuff     = Spell(248146),  -- Fire Shoulders Buff
	  EruptingInfernalCore          = Spell(248147)   -- Fire Shoulder Stacks


};

local S = Spell.Mage.Fire;
-- Items
if not Item.Mage then Item.Mage = {}; end
Item.Mage.Fire = {
 PotionofProlongedPower   = Spell(142117)

local I = Item.Mage.Fire;
-- Rotation Var
local ShouldReturn; -- Used to get the return string
local Combustion_Phase;
local rop_phase;
-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Mage.Commons,
  Fire = AR.GUISettings.APL.Mage.Fire
};

-------- ACTIONS --------

--actions+=/mirror_image,if=buff.combustion.down
  if  S.MirrorImage:IsCastable() and not Player:Buff(S.Combustion) then
     if AR.Cast(S.RuneOfPower) then return "";
end

--actions+=/rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die.remains<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
  if S.RuneOfPower:IsCastable() and Target:HealthPercentage() > 90 and S.RuneOfPower:Charges() = 2
       or S.Combustion:Cooldown() > 40 and not Player:Buff(S.Combustion) and not S.Kindling:IsAvailable()
	   or Target:TimeToDie() < 11
	   or S.Kindling:IsAvailable() & S.RuneOfPower:ChargesFractional() > 1.8
	   or AC.CombatTime() < 40 and S.Combustion:CooldownRemains() > 40 then
	   if AR.Cast(S.RuneOfPower) then return "";
end

--actions+=/rune_of_power,if=(buff.kaelthas_ultimate_ability.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))|(buff.erupting_infernal_core.up&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))
  if S.RuneOfPower:IsCastable() and Player:Buff(S.KaelthassUltimateAbility) and S.Combustion:Cooldown() > 40
       or S.RuneOfPower:IsCastable and Player:Buff(S.EruptingInfernalCore) and S.Combustion:Cooldown() > 40
       or S.RunOfPower:Charges() > 1 then
      if AR.Cast(S.RuneOfPower) then return "";
end

--actions+=/call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.upactive_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
local function Combustion_Phase ()
  return (
    S.Combustion:CooldownRemains() <= (S.RuneofPower:CastTime)
      + ((not S.Firestarter:IsAvailable()
          or Target:HealthPercentage() > 90 and S.Firestarter:IsAvailable()
          or Cache.EnemiesCount[8] >= (S.FlamePatch:IsAvailable() and 2 or 4))
        and (not S.Kindling:IsAvailable() and Player:GCD() or 0))
    or Player:Buff(S.Combustion)
    );
end

--actions+=/call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
local function rop_phase
   return Player:Buff(S.RuneOfPower) and not Player:Buff(S.Combustion);
end

local function standard_rotation

end

-- Start of Combustion_Phase actions.
local function combustion_phase ()

--actions.combustion_phase=rune_of_power,if=buff.combustion.down
if S.RuneOfPower:IsCastable() and not Player:Buff(S.Combustion) then
   if AR.Cast(S.RuneOfPower) then return ""; end
end

--actions.combustion_phase+=/call_action_list,name=active_talents
-- //TODO :thinking:

--actions.combustion_phase+=/combustion
if S.Combustion:IsCastable() then
   if AR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return ""; end
end
--actions.combustion_phase+=/potion
if I.PotionofProlongedPower:IsUsable()then
   if AR.CastSuggested(I.PotionofProlongedPower) then return ""; end
end

--actions.combustion_phase+=/blood_fury
if S.BloodFury:IsCastable() then
   if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
end

-- actions.cooldowns+=/berserking
if S.Berserking:IsCastable() then
   if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
end

--actions.combustion_phase+=/use_items
-- //TODO: Add when Aethys add global functionality.

--actions.combustion_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2|active_enemies>4)&buff.hot_streak.up
if S.Flamestrike:IsCastable() and Player:Buff(S.HotStreak)
   and (Cache.EnemiesCount[8] > 2 and S.FlamePatch:IsAvailable()
   or   Cache.EnemiesCount[8] > 4)  then
   if AR.Cast(S.Flamestrike) then return ""; end
end

--actions.combustion_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&buff.combustion.remains>execute_time
if S.Pyroblast:IsCastable() and Player:Buff(S.KaelthassUltimateAbility) and Player:Buff(Combustion) > S.Pyroblast:ExecuteTime() then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.combustion_phase+=/pyroblast,if=buff.hot_streak.up
if S.Pyroblast:IsCastable() and Player:Buff(S.HotStreak) then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.combustion_phase+=/fire_blast,if=buff.heating_up.up
if  S.Fireblast:IsCastable() and Player:Buff(S.HotStreak) then
    if.AR.Cast(S.Fireblast) then return ""; end
end

--actions.combustion_phase+=/phoenixs_flames
if S.PheonixFlames:IsCastable() then
   if.AR.Cast(S.PheonixFlames) then return ""; end
end

--actions.combustion_phase+=/scorch,if=buff.combustion.remains>cast_time
if S.Scorch:IsCastable() and Player:Buff(Combustion) > S.Scorch:ExecuteTime() then
   if AR.Cast(S.Fireblast) then return ""; end
end

--actions.combustion_phase+=/dragons_breath,if=buff.hot_streak.down&action.fire_blast.charges<1&action.phoenixs_flames.charges<1
if S.DragonsBreath:IsCastable() and not Player:Buff(HotStreak) and S.Fireblast:Charges < 1 and S.PheonixFlames:Charges < 1 then
   if AR.Cast(S.DragonsBreath) then return ""; end
end

--actions.combustion_phase+=/scorch,if=target.health.pct<=30&equipped.132454
if S.Scorch:IsCastable() and Target:HealthPercentage() <= 30 and I.KoralonsBurningTouch:IsEquipped() then
   if AR.Cast(S.Scorch) then return ""; end
end

local function rop_phase()

--actions.rop_phase=rune_of_power
if S.RuneOfPower:IsCastable() then
  if AR.Cast(S.RuneOfPower) then return ""; end
end

--actions.rop_phase+=/flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.up
if S.Flamestrike:IsCastable() and Player:Buff(S.HotStreak)
   and (Cache.EnemiesCount[8] > 1 and S.FlamePatch:IsAvailable()
   or   Cache.EnemiesCount[8] > 3)  then
   if AR.Cast(S.Flamestrike) then return ""; end
end

--actions.rop_phase+=/pyroblast,if=buff.hot_streak.up
if S.Pyroblast:IsCastable() and Player:Buff(S.HotStreak) then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.rop_phase+=/call_action_list,name=active_talents
--//TODO Not sure if needed?

--actions.rop_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
if S.Pyroblast:IsCastable() and Player:Buff(S.KaelthassUltimateAbility) and Player:Buff(RuneOfPower) > S.Pyroblast:ExecuteTime() then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.up&firestarter.active&charges_fractional>1.7
if S.Fireblast:IsCastable() and not Player:PrevGCD(S.Fireblast) and Player:Buff(S.HeatingUp) and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 and S.Fireblast:ChargesFractional() > 1.7 then
   if AR.Cast(S.Fireblast) then return ""; end
end

--actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames&charges_fractional>2.7&firestarter.active
if S.PheonixFlames:IsCastable() and not Player:PrevGCD(1, S.PheonixFlames) and S.PheonixFlames:ChargesFractional() > 2.7 and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 then
   if AR.Cast(S.PheonixFlames) then return ""; end
end

--actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
if S.Fireblast:IsCastable() and not Player:PrevGCD(S.Fireblast) and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 then
   if AR.Cast(S.Fireblast) then return ""; end
end
--actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames
if S.PheonixFlames:IsCastable() and not Player:PrevGCD(1, S.PheonixFlames) then
   if AR.Cast(S.PheonixFlames) then return ""; end
end
--actions.rop_phase+=/scorch,if=target.health.pct<=30&equipped.132454
if S.Scorch:IsCastable() and Target:HealthPercentage() < 30 and I.KoralonsBurningTouch:IsEquipped() then
   if AR.Cast(S.Scorch) then return ""; end
end

--actions.rop_phase+=/dragons_breath,if=active_enemies>2
if S.DragonsBreath:IsCastable() and Cache.EnemiesCount[8] > 2 then
   if AR.Cast(S.DragonsBreath) then return ""; end
end

--actions.rop_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
if S.Flamestrike:IsCastable()
   and (Cache.EnemiesCount[8] > 2 and S.FlamePatch:IsAvailable()
   or   Cache.EnemiesCount[8] > 5)  then
   if AR.Cast(S.Flamestrike) then return ""; end
end

--actions.rop_phase+=/fireball
if S.Fireball:IsCastable()
   if AR.Cast(S.Fireball) then return ""; end
end

local function standard_rotation

--actions.standard_rotation=flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.up
if S.Flamestrike:IsCastable() and Player:Buff(S.HotStreak)
   and (Cache.EnemiesCount[8] > 1 and S.FlamePatch:IsAvailable()
   or   Cache.EnemiesCount[8] > 3)  then
   if AR.Cast(S.Flamestrike) then return ""; end
end

--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&buff.hot_streak.remains<action.fireball.execute_time
if S.Pyroblast:IsCastable() and Player:Buff(S.HotStreak) and Player:BuffRemains(S.HotStreak) <  S.Fireball:ExecuteTime() then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&firestarter.active&!talent.rune_of_power.enabled
if S.Pyroblast:IsCastable() and Player:Buff(S.HotStreak) and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 and not S.RuneOfPower:IsAvailable()
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.7&active_enemies>2
if S.PheonixFlames:IsCastable() and S.PheonixFlames:ChargesFractional() > 2.7 and Cache.EnemiesCount[8] > 2
   if AR.Cast(S.PheonixFlames) then return ""; end
end

--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&!prev_gcd.1.pyroblast
if S.Pyroblast:IsCastable() and Player:Buff(S.HotStreak) and not Player:PrevGCD(1, S.Pyroblast) then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&target.health.pct<=30&equipped.132454
if S.Pyroblast:IsCastable() and Player:Buff(S.HotStreak) and Target:HealthPercentage() <= 30 and I.KoralonsBurningTouch:IsEquipped() then
    if AR.Cast(S.Pyroblast)  then return ""; end
end

--actions.standard_rotation+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
if S.Pyroblast:IsCastable() and Player:Buff(S.KaelthassUltimateAbility) and S.Pyroblast:ExecuteTime() < Player:Buff(S.KaelthassUltimateAbility) then
   if AR.Cast(S.Pyroblast) then return ""; end
end

--actions.standard_rotation+=/call_action_list,name=active_talents

--actions.standard_rotation+=/fire_blast,if=!talent.kindling.enabled&buff.heating_up.up&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die.remains<4
if S.Fireblast:IsCastable() and not S.Kindling:NotAvailable() 
   and Player:Buff(S.HeatingUp) 
   and (not S.RuneOfPower:IsAvailable 
      or S.FireBlast:ChargesFractional > 1.4
      or S.Combustion:Cooldown < 40)
   and (S.FireBlast:ChargesFractional -3) * (12 * Player:SpellHaste) < S.Combustion:CooldownRemains + 3 
      or Target:TimeToDie < 4)
   then if AR.Cast(S.FireBlast) then return ""; end
end

--actions.standard_rotation+=/fire_blast,if=talent.kindling.enabled&buff.heating_up.up&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die.remains<4
if S.Fireblast:IsCastable() and not S.Kindling:IsAvailable and Player:Buff(S.HeatingUp)
    and (not S.RuneOfPower:NotAvailable()
	   or S.FireBlast:ChargesFractional > 1.5
	   or S.Combustion:Cooldown < 40)
	and (S.FireBlast:ChargesFractional -3) * (18 * Player:SpellHaste) < S.Combustion:CooldownRemains + 3  
	   or Target:TimeToDie < 4)
   then if AR.Cast(S.FireBlast) then return ""; end
end

--actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&artifact.phoenix_reborn.enabled&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die.remains<10
if S.PheonixFlames:IsCastable and 
  (     Player:Buff(S.Combustion)
     or Player:Buff(S.RuneOfPower)
	 or Player:BuffStack > 3
	 or S.MirrorImage:IsAvailable)
  and (S.PheonixFlame:ChargesFractional - 4) * 13 < S.Combustion:CooldownRemains + 5
    or Target:TimeToDie < 4
   then if AR.Cast(S.PheonixFlames) then return ""; end
end

--actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
if S.PheonixFlames:IsCastable and 
  (     Player:Buff(S.Combustion)
     or Player:Buff(S.RuneOfPower))
  and (S.PheonixFlames:ChargesFractional - 4) * 30 < S.Combustion:CooldownRemains + 5
   then if AR.Cast(S.PheonixFlames) then return ""; end
end 

--actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
if S.PheonixFlames:IsCastable() and S.PheonixFlames:ChargesFractional() > 2.5 and S.Combustion:CooldownRemains() > 23 then
   if AR.Cast(S.PheonixFlames) then return ""; end
end

--actions.standard_rotation+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>3)|active_enemies>5
if S.Flamestrike:IsCastable() and
   and (Cache.EnemiesCount[8] > 3 and S.FlamePatch:IsAvailable()
   or   Cache.EnemiesCount[8] > 5)  then
   if AR.Cast(S.Flamestrike) then return ""; end
end

--actions.standard_rotation+=/scorch,if=target.health.pct<=30&equipped.132454
if S.Scorch:IsCastable() and Target:HealthPercentage() < 30 and I.KoralonsBurningTouch:IsEquipped() then
   if AR.Cast(S.Scorch) then return ""; end
end

--actions.standard_rotation+=/fireball
if S.Fireball:IsCastable()  then
   if AR.Cast(S.Fireball) then return ""; end
end

AR.SetAPL(63, APL);

-- Simulationcraft APL - Taken 19/09/2017

--# Executed every time the actor is available.
--actions=counterspell,if=target.debuff.casting.react
--actions+=/time_warp,if=(time=0&buff.bloodlust.down)|(buff.bloodlust.down&equipped.132410&(cooldown.combustion.remains<1|target.time_to_die.remains<50))
--actions+=/mirror_image,if=buff.combustion.down
--# Standard Talent RoP Logic.
--actions+=/rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die.remains<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
--# RoP use while using Legendary Items.
--actions+=/rune_of_power,if=(buff.kaelthas_ultimate_ability.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))|(buff.erupting_infernal_core.up&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))
--actions+=/call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
--actions+=/call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
--actions+=/call_action_list,name=standard_rotation

--actions.active_talents=blast_wave,if=(buff.combustion.down)|(buff.combustion.up&action.fire_blast.charges<1&action.phoenixs_flames.charges<1)
--actions.active_talents+=/meteor,if=cooldown.combustion.remains>40|(cooldown.combustion.remains>target.time_to_die)|buff.rune_of_power.up|firestarter.active
--actions.active_talents+=/cinderstorm,if=cooldown.combustion.remains<cast_time&(buff.rune_of_power.up|!talent.rune_on_power.enabled)|cooldown.combustion.remains>10*spell_haste&!buff.combustion.up
--actions.active_talents+=/dragons_breath,if=equipped.132863|(talent.alexstraszas_fury.enabled&buff.hot_streak.down)
--actions.active_talents+=/living_bomb,if=active_enemies>1&buff.combustion.down

--actions.combustion_phase=rune_of_power,if=buff.combustion.down
--actions.combustion_phase+=/call_action_list,name=active_talents
--actions.combustion_phase+=/combustion
--actions.combustion_phase+=/potion
--actions.combustion_phase+=/blood_fury
--actions.combustion_phase+=/berserking
--actions.combustion_phase+=/arcane_torrent
--actions.combustion_phase+=/use_items
--actions.combustion_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2|active_enemies>4)&buff.hot_streak.up
--actions.combustion_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&buff.combustion.remains>execute_time
--actions.combustion_phase+=/pyroblast,if=buff.hot_streak.up
--actions.combustion_phase+=/fire_blast,if=buff.heating_up.up
--actions.combustion_phase+=/phoenixs_flames
--actions.combustion_phase+=/scorch,if=buff.combustion.remains>cast_time
--actions.combustion_phase+=/dragons_breath,if=buff.hot_streak.down&action.fire_blast.charges<1&action.phoenixs_flames.charges<1
--actions.combustion_phase+=/scorch,if=target.health.pct<=30&equipped.132454

--actions.rop_phase=rune_of_power
--actions.rop_phase+=/flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.up
--actions.rop_phase+=/pyroblast,if=buff.hot_streak.up
--actions.rop_phase+=/call_action_list,name=active_talents
--actions.rop_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
--actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.up&firestarter.active&charges_fractional>1.7
--actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames&charges_fractional>2.7&firestarter.active
--actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
--actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames
--actions.rop_phase+=/scorch,if=target.health.pct<=30&equipped.132454
--actions.rop_phase+=/dragons_breath,if=active_enemies>2
--actions.rop_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
--actions.rop_phase+=/fireball

--actions.standard_rotation=flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.up
--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&buff.hot_streak.remains<action.fireball.execute_time
--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&firestarter.active&!talent.rune_of_power.enabled
--actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.7&active_enemies>2
--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&!prev_gcd.1.pyroblast
--actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&target.health.pct<=30&equipped.132454
--actions.standard_rotation+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
--actions.standard_rotation+=/call_action_list,name=active_talents
--actions.standard_rotation+=/fire_blast,if=!talent.kindling.enabled&buff.heating_up.up&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die.remains<4
--actions.standard_rotation+=/fire_blast,if=talent.kindling.enabled&buff.heating_up.up&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die.remains<4
--actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&artifact.phoenix_reborn.enabled&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die.remains<10
--actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
--actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
--actions.standard_rotation+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>3)|active_enemies>5
--actions.standard_rotation+=/scorch,if=target.health.pct<=30&equipped.132454
--actions.standard_rotation+=/fireball

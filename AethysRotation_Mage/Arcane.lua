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
  local ArcaneChargesMax = 4;
  local ArcaneMissilesProcMax = 3;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua

  --- ============================ CONTENT ============================
  --- ======= APL LOCALS =======
     local Everyone = AR.Commons.Everyone;
     local Mage = AR.Commons.Mage;
    -- Spells
     if not Spell.Mage then Spell.Mage = {}; end

     Spell.Mage.Arcane = {
      -- Racials
      ArcaneTorrent                 = Spell(25046),
      Berserking                    = Spell(26297),
      BloodFury                     = Spell(20572),
      GiftoftheNaaru                = Spell(59547),
      Shadowmeld                    = Spell(58984),
      -- Abilities
	  ArcaneCharges					= Spell(36032),
      ArcaneBlast                   = Spell(30451),
      ArcaneBarrage                 = Spell(44425),
      ArcaneExplosion               = Spell(1449),
      ArcaneMissiles                = Spell(5143),
      ArcaneMissilesProc            = Spell(79683),
      Evocation                     = Spell(12051),
      PresenceOfMind                = Spell(205025),
      ArcanePower                   = Spell(12042),
	  ExpandingMind					= Spell(253262),
      -- Talents
      ArcaneFamiliar                = Spell(205022),
      Amplification                 = Spell(236628),
      WordsOfPower                  = Spell(205035),
      MirrorImage                   = Spell(55342),
      RuneofPower                   = Spell(116011),
      IncantersFlow                 = Spell(1463),
      Supernova                     = Spell(157980),
      ChargedUp                     = Spell(205032),
      Resonance                     = Spell(205028),
      NetherTempest                 = Spell(114923),
      Erosion                       = Spell(205039),
      Overpowered                   = Spell(155147),
      TemporalFlux                  = Spell(234302),
      ArcaneOrb                     = Spell(153626),
      -- Artifact
      MarkOfAluneth                 = Spell(224968),
      -- Defensive
      PrismaticBarrier              = Spell(11426),
      IceBlock                      = Spell(45438),
      GreaterInvisibility           = Spell(110959),
      -- Legendaries
      MysticKiltOfTheRuneMaster     = Spell(209280),
      MantleOfTheFirstKirinTor      = Spell(248098),
      ShardOfExodar                 = Spell(132410),
      GravitySpiral                 = Spell(235273),
      SoulOfTheArchmage             = Spell(151642),
      CordOfInfinity                = Spell(209311),
      SephuzsSecret                 = Spell(132452),
      KiljadensBurningWish          = Spell(144259),
      RhoninsAssaultingArmwraps     = Spell(208080),
      NorgannonsForesight           = Spell(132455),
      BelovirsFinalStand            = Spell(133977),
      PrydazXavaricsMagnumOpus      = Spell(132444),
      -- Legendary Procs
      RhoninsAssaultingArmwrapsProc = Spell(208081),  -- Arcane Mage Bracer Buff
      CordOfInfinityProc            = Spell(209316),  -- Arcane Mage Belt Buff


};

local S = Spell.Mage.Arcane;
-- Items
if not Item.Mage then Item.Mage = {}; end
Item.Mage.Arcane = {
 PotionOfDeadlyGrace   = Spell(188027)

local I = Item.Mage.Arcane;
-- Rotation Var
local ShouldReturn; -- Used to get the return string
local build_phase;
local burn_phase;
local conserve_phase;
-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Mage.Commons,
  Arcane = AR.GUISettings.APL.Mage.Arcane
};

-------- ACTIONS --------

--actions+=/call_action_list,name=build,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&!burn_phase
local function build_phase ()
  return (
     Player:BuffStack(S.ArcaneCharges) < ArcaneChargesMax
    );
end

--actions+=/call_action_list,name=burn,if=(buff.arcane_charge.stack=buff.arcane_charge.max_stack&variable.time_until_burn=0)|burn_phase
local function burn_phase
   return (
     Player:BuffStack(S.ArcaneCharges) = ArcaneChargesMax and S.ArcanePower:IsCastable();
   );
end

--actions+=/call_action_list,name=conserve
local function conserve_phase ()
	return (
		Player:PrevGCD(1, S.Evocation)
	);

end

-- Start of Build_Phase actions.
local function build_phase ()

--actions.build=arcane_orb
if S.ArcaneOrb:IsCastable then
   if AR.Cast(S.ArcaneOrb) then return "";
end

--actions.build+=/arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3
if S.ArcaneMissiles:IsCastable() and ArcaneMissilesProc = ArcaneMissilesProcMax and Cache.EnemiesCount[8] < 3 then
   if AR.Cast(S.ArcaneMissiles) then return "";
end

--actions.build+=/arcane_explosion,if=active_enemies>1
if S.ArcaneExplosion:IsCastable() and Cache.EnemiesCount[8] > 1 then
   if AR.Cast(S.ArcaneExplosion) then return "";
end

--actions.build+=/arcane_blast
if S.ArcaneBlast:IsCastable() then
   if AR.Cast(S.ArcaneBlast) then return "";
end

--Start of Burn_Phase actions
local function burn_phase ()

--# Increment our burn phase counter. Whenever we enter the `burn` actions without being in a burn phase, it means that we are about to start one.
--actions.burn=variable,name=total_burns,op=add,value=1,if=!burn_phase
--# The burn_phase variable is a flag indicating whether or not we are in a burn phase. It is set to 1 (True) with start_burn_phase, and 0 (False) with stop_burn_phase.
--actions.burn+=/start_burn_phase,if=!burn_phase
--TODO

--# Evocation is the end of our burn phase, but we check available charges in case of Gravity Spiral. The final burn_phase_duration check is to prevent an infinite loop in SimC.
--actions.burn+=/stop_burn_phase,if=prev_gcd.1.evocation&cooldown.evocation.charges=0&burn_phase_duration>0
if Player:PrevGCD(1, S.Evocation) and S.Evocation.Charges = 0 and S.Evocation.CooldownRemains > 0 then
   return conserve_phase();
end

--# Use during pandemic refresh window or if the dot is missing.
--actions.burn+=/nether_tempest,if=refreshable|!ticking
if S.NetherTempest:IsCastable() and not Target:DebuffRemainsP(S.NetherTempest) <= (Player:GCD() + S.NetherTempest:TickTime())
	if AR.Cast(S.NetherTempest) then return "";
end

--actions.burn+=/mark_of_aluneth
if S.MarkOfAluneth:IsCastable() then
	if AR.Cast(S.MarkOfAluneth) then return "";
end

--actions.burn+=/mirror_image
if S.MirrorImage:IsCastable() then
	if AR.Cast(S.MirrorImage) then return "";
end

--# Prevents using RoP at super low mana.
--actions.burn+=/rune_of_power,if=mana.pct>30|(buff.arcane_power.up|cooldown.arcane_power.up)
if Player:ManaPercentage > 30% or ( Player.Buff(S.ArcanePower) or S.ArcanePower:IsCastable() )
	if AR.Cast(S.RuneOfPower) then return "";
end

--actions.burn+=/arcane_power
if S.ArcanePower:IsCastable()
	if AR.Cast(S.ArcanePower) then return "";
end

--actions.burn+=/blood_fury
if S.BloodFury:IsCastable()
	if AR.Cast(S.BloodFury) then return "";
end

--actions.burn+=/berserking
if S.Berserking:IsCastable()
	if AR.Cast(S.Berserking) then return "";
end

--actions.burn+=/arcane_torrent
if S.ArcaneTorrent:IsCastable()
	if AR.Cast(S.ArcaneTorrent) then return "";
end

--# For Troll/Orc, it's best to sync potion with their racial buffs.
--actions.burn+=/potion,if=buff.arcane_power.up&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))
if Player:Buff(S.Berserking) or Player:Buff(S.BloodFury)
	if AR.Use(I.PotionOfDeadlyGrace) then return "";
end

--# Pops any on-use items, e.g., Tarnished Sentinel Medallion.
--actions.burn+=/use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
--TODO : Aethys needs to work on things and stuff

--# With 2pt20 or Charged Up we are able to extend the damage buff from 2pt21.
--actions.burn+=/arcane_barrage,if=set_bonus.tier21_2pc&((set_bonus.tier20_2pc&cooldown.presence_of_mind.up)|(talent.charged_up.enabled&cooldown.charged_up.up))&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.expanding_mind.down
if ( ( AC.HasTier("T20") and S.PresenceOfMind:IsCastable() ) or S.ChargedUp:IsCastable() and Player.BuffStack(S.ArcaneCharges) = ArcaneChargesMax and Player.Buff(S.ExpandingMind) ) and S.ArcaneBarrage:IsCastable()
	if AR.Cast(S.ArcaneBarrage) then return = "";
end

--# With T20, use PoM at start of RoP/AP for damage buff. Without T20, use PoM at end of RoP/AP to cram in two final Arcane Blasts. Includes a mana condition to prevent using PoM at super low mana.
--actions.burn+=/presence_of_mind,if=((mana.pct>30|buff.arcane_power.up)&set_bonus.tier20_2pc)|buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
if ( ( ( Player.ManaPercentage > 30 or Player.Buff(ArcanePower) ) and AC.HasTier("T20") ) or Player.BuffRemains(S.RuneOfPower) <= 2 * S.ArcaneBlast.ExecuteTime or  Player.BuffRemains(S.ArcanePower) <= 2 * S.ArcaneBlast.ExecuteTime ) and S.PresenceOfMind:IsCastable()
	if AR.Cast(S.PresenceOfMind) then return "";
end

--# Use Charged Up to regain Arcane Charges after dumping to refresh 2pt21 buff.
--actions.burn+=/charged_up,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
if Player.Buff(ArcaneCharges) < ArcaneChargesMax and S.ChargedUp:IsCastable()
	if AR.Cast(S.ChargedUp) then return "";
end

--actions.burn+=/arcane_orb
if S.ArcaneOrb:IsCastable()
	if AR.Cast(S.ArcaneOrb) then return "";
end

--# Arcane Barrage has a good chance of launching an Arcane Orb at max Arcane Charge stacks.
--actions.burn+=/arcane_barrage,if=active_enemies>4&equipped.mantle_of_the_first_kirin_tor&buff.arcane_charge.stack=buff.arcane_charge.max_stack
if Cache.EnemiesCount[8] > 4 and I.MantleOfTheFirstKirinTor:IsEquipped() and Player.BuffStack(S.ArcaneCharges) = ArcaneChargesMax and S.ArcaneBarrage:IsCastable()
	if AR.Cast(S.ArcaneBarrage) then return "";
end

--# Arcane Missiles are good, but not when there's multiple targets up.
--actions.burn+=/arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3
if Player.BuffStack(S.ArcaneMissilesProc) = ArcaneMissilesProcMax and Cache.EnemiesCount[8] < 3 and S.ArcaneMissiles:IsCastable()
	if AR.Cast(S.ArcaneMissiles) then return "";
end

--# Get PoM back on cooldown as soon as possible.
--actions.burn+=/arcane_blast,if=buff.presence_of_mind.up
if Player.Buff(S.PresenceOfMind) and S.ArcaneBlast:IsCastable()
	if AR.Cast(S.ArcaneBlast) then "";
end

--actions.burn+=/arcane_explosion,if=active_enemies>1
if Cache.EnemiesCount[8] > 1 and S.ArcaneExplosion:IsCastable()
	if AR.Cast(S.ArcaneExplosion) then "";
end

--actions.burn+=/arcane_missiles,if=variable.arcane_missiles_procs
if S.ArcaneMissiles:IsCastable()
	if AR.Cast(S.ArcaneMissiles) then "";
end

--actions.burn+=/arcane_blast
if S.ArcaneBlast:IsCastable()
	if AR.Cast(S.ArcaneBlast) then "";
end

--actions.burn+=/evocation,interrupt_if=ticks=2|mana.pct>=85,interrupt_immediate=1
if Player.ManaPercentage < 15 and S.Evocation:IsCastable()
	if AR.Cast(S.Evocation) then "";
end

local function conserve_phase()

--actions.conserve=mirror_image,if=variable.time_until_burn>recharge_time|variable.time_until_burn>target.time_to_die
if S.MirrorImage:IsCastable()
	if AR.Cast(S.MirrorImage) then return "";
end

--actions.conserve+=/mark_of_aluneth,if=mana.pct<85
if S.MarkOfAluneth:IsCastable() and Player.ManaPercentage < 85
	if AR.Cast(S.MarkOfAluneth) then return "";
end

--actions.conserve+=/strict_sequence,name=miniburn,if=talent.rune_of_power.enabled&set_bonus.tier20_4pc&variable.time_until_burn>30:rune_of_power:arcane_barrage:presence_of_mind
if S.RuneOfPower:IsCastable() and AC.HasTier("T20") and S.ArcaneBarrage:IsCastable() and S.PresenceOfMind:IsCastable()
	if AR.cast(S.RuneOfPower) then
		if AR.cast(S.ArcaneBarrage) then
			if AR.Cast(S.PresenceOfMind)
				then return "";
end

--# Use if we're about to cap on stacks, or we just used MoA.
--actions.conserve+=/rune_of_power,if=full_recharge_time<=execute_time|prev_gcd.1.mark_of_aluneth
if S.RuneOfPower:IsCastable() and Player:PrevGCD(1, S.MarkOfAluneth)
	if AR.Cast(S.RuneOfPower) then return "";
end

--# We want Charged Up for our burn phase to refresh 2pt21 buff, but if we have time to let it recharge we can use it during conserve.
--actions.conserve+=/strict_sequence,name=abarr_cu_combo,if=talent.charged_up.enabled&cooldown.charged_up.recharge_time<variable.time_until_burn:arcane_barrage:charged_up
if S.ArcaneBarrage:IsCastable() and S.ChargedUp:IsCastable()
	if AR.Cast(S.ArcaneBarrage) then
		if AR.Cast(S.ChargedUp) then return "";
end

--# Arcane Missiles are good, but not when there's multiple targets up.
--actions.conserve+=/arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3
if Player.BuffStack(ArcaneMissilesProc) = ArcaneMissilesProcMax and Cache.EnemiesCount[8] < 3 and S.ArcaneMissiles:IsCastable()
	if AR.Cast(S.ArcaneMissiles) then return "";
end

--actions.conserve+=/supernova
if S.Supernova:IsCastable()
	if AR.Cast(S.Supernova) then return "";
end

--# Use during pandemic refresh window or if the dot is missing.
--actions.conserve+=/nether_tempest,if=refreshable|!ticking
if S.NetherTempest:IsCastable() and not Target:DebuffRemainsP(S.NetherTempest) <= (Player:GCD() + S.NetherTempest:TickTime())
	if AR.Cast(S.NetherTempest) then return "";
end

--# AoE until about 70% mana. We can go a little further with kilt, down to 60% mana.
--actions.conserve+=/arcane_explosion,if=active_enemies>1&(mana.pct>=70-(10*equipped.mystic_kilt_of_the_rune_master))
if S.ArcaneExplosion:IsCastable() and Cache.EnemiesCount[8] > 1 and ( Player.ManaPercentage >= 70 | ( I.MysticKiltOfTheRuneMaster:IsEquipped() & Player.ManaPercentage >= 60) )
	if AR.Cast(S.ArcaneExplosion) then return "";
end

--# Use Arcane Blast if we have the mana for it or a proc from legendary wrists. With the Kilt we can cast freely.
--actions.conserve+=/arcane_blast,if=mana.pct>=90|buff.rhonins_assaulting_armwraps.up|(buff.rune_of_power.remains>=cast_time&equipped.mystic_kilt_of_the_rune_master)
if S.ArcaneBlast:IsCastable() and ( Player.ManaPercentage >= 90 or ( Player.BuffRemains(S.RuneOfPower) >= S.ArcaneBlast.ExecuteTime and I.MysticKiltOfTheRuneMaster:IsEquipped() ) )
	if AR.Cast(S.ArcaneBlast) then return "";
end

--actions.conserve+=/arcane_missiles,if=variable.arcane_missiles_procs
if S.ArcaneMissiles:IsCastable()
	if AR.Cast(S.ArcaneMissiles) then return "";
end

--actions.conserve+=/arcane_barrage
if S.ArcaneBarrage:IsCastable()
	if AR.Cast(S.ArcaneBarrage) then return "";
end

--# The following two lines are here in case Arcane Barrage is on cooldown.
--actions.conserve+=/arcane_explosion,if=active_enemies>1
if S.ArcaneExplosion:IsCastable() and Cache.EnemiesCount[8] > 1
	if AR.Cast(S.ArcaneExplosion) then return "";
end

--actions.conserve+=/arcane_blast
if S.ArcaneBlast:IsCastable()
	if AR.Cast(S.ArcaneBlast) then return "";
end
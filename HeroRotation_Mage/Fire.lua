--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Pet = Unit.Pet;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- HeroRotation
  local AR = HeroRotation;
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
      Pyroblast                     = Spell(11366),
      CriticalMass                  = Spell(117216),
      Fireblast                     = Spell(108853),
      HotStreak                     = Spell(48108),
      HeatingUp                     = Spell(48107),
      EnchancedPyrotechnics         = Spell(157642),
      DragonsBreath                 = Spell(31661),
      Combustion                    = Spell(190319),
      Scorch                        = Spell(2948),
      Flamestrike                   = Spell(2120),
      -- Talents
      Pyromaniac                    = Spell(205020),
      Conflagaration                = Spell(205023),
      Firestarter                   = Spell(205026),
      BlastWave                     = Spell(157981),
      MirrorImage                   = Spell(55342),
      RuneOfPower                   = Spell(116011),
      RuneOfPowerAura               = Spell(116014),
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
      PhoenixFlames                 = Spell(194466),
      BigMouth                      = Spell(215796),
      -- Defensive
      IceBarrier                    = Spell(11426),
      IceBlock                      = Spell(45438),
      Invisibility                  = Spell(66),
      -- Legendary Procs
      KaelthassUltimateAbility      = Spell(209455),  -- Fire Mage Bracer Procs
      ContainedInfernalCoreBuff     = Spell(248146),  -- Fire Shoulders Buff
	    EruptingInfernalCore          = Spell(248147)   -- Fire Shoulder Stacks
    };
local S = Spell.Mage.Fire;
-- Items
if not Item.Mage then Item.Mage = {}; end
Item.Mage.Fire = {
  PotionofProlongedPower        = Item(142117),
  -- Legendaries
  MarqueeBindingsoftheSunKing   = Item(132406),
  KoralonsBurningTouch          = Item(132454),
  ShardOfExodar                 = Item(132410),
  CantainedInfernalCore         = Item(151809),
  SoulOfTheArchmage             = Item(151642),
  PyrotexIgnitionCloth          = Item(144355),
  SephuzsSecret                 = Item(132452),
  KiljadensBurningWish          = Item(144259),
  DarcklisDragonfireDiadem      = Item(132863),
  NorgannonsForesight           = Item(132455),
  BelovirsFinalStand            = Item(133977),
  PrydazXavaricsMagnumOpus      = Item(132444)
};
local I = Item.Mage.Fire;
-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Mage.Commons,
  Fire = AR.GUISettings.APL.Mage.Fire
};
-- Register for InFlight tracking
S.PhoenixFlames:RegisterInFlight();
S.Pyroblast:RegisterInFlight(S.Combustion);
DBRange = 8;
--take into account upcoming crits for rotation smoothness, return 0 = No buff , 1 = Heating Up, 2 = Hot Streak
local function HeatLevelPredicted ()
  if Player:BuffP(S.HotStreak) then
    return 2;
  end
  return math.min((Player:BuffP(S.HeatingUp) and 1 or 0) + ((Player:IsCasting(S.Scorch) and (Target:HealthPercentage() <= 30 and I.KoralonsBurningTouch:IsEquipped() or Player:BuffP(S.Combustion))) and 1 or 0) + (S.PhoenixFlames:InFlight() and 1 or 0) + (S.Pyroblast:InFlight(S.Combustion) and 1 or 0),2);
end
-- Add BuffP to improve ARParser compatibility with Heat Level and RoP Prediction
local function BuffP(Spell, AnyCaster, Offset)
  if Spell == S.HotStreak then
    return HeatLevelPredicted() == 2
  elseif Spell == S.HeatingUp then
    return HeatLevelPredicted() == 1
  elseif Spell == S.RuneOfPowerAura then
    return HL.OffsetRemains(S.RuneOfPowerAura:TimeSinceLastAppliedOnPlayer(), "Auto") <= 10
  else
    return Player:BuffP(Spell, AnyCaster, Offset)
  end
end
-------- ACTIONS --------
local function ActiveTalents ()
  -- actions.active_talents=blast_wave,if=(buff.combustion.down)|(buff.combustion.up&action.fire_blast.charges<1&action.phoenixs_flames.charges<1)
  if S.BlastWave:IsCastable()
    and (
      not BuffP(S.Combustion)
      or BuffP(S.Combustion) and S.Fireblast:Charges() < 1 and S.PhoenixFlames:Charges() < 1
    ) then
    if AR.Cast(S.BlastWave) then return ""; end
  end
  -- actions.active_talents+=/meteor,if=cooldown.combustion.remains>40|(cooldown.combustion.remains>target.time_to_die)|buff.rune_of_power.up|firestarter.active
  if S.Meteor:IsCastable()
    and (
          S.Combustion:CooldownRemainsP() > 40
      or  S.Combustion:CooldownRemainsP() > Target:TimeToDie()
      or  BuffP(S.RuneOfPowerAura)
      or  S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90
    ) then
    if AR.Cast(S.Meteor) then return ""; end
  end
  -- actions.active_talents+=/cinderstorm,if=cooldown.combustion.remains<cast_time&(buff.rune_of_power.up|!talent.rune_on_power.enabled)|cooldown.combustion.remains>10*spell_haste&!buff.combustion.up
  if S.Cinderstorm:IsCastable() and not Player:IsCasting(S.Cinderstorm)
    and (
          S.Combustion:CooldownRemainsP() < S.Cinderstorm:ExecuteTime() and (BuffP(S.RuneOfPowerAura) or not S.RuneOfPower:IsAvailable())
      or  S.Combustion:CooldownRemainsP() > 10 * Player:SpellHaste() and not BuffP(S.Combustion)
    ) then
    if AR.Cast(S.Cinderstorm) then return ""; end
  end
  -- actions.active_talents+=/dragons_breath,if=equipped.132863|(talent.alexstraszas_fury.enabled&buff.hot_streak.down)
  if S.DragonsBreath:IsCastable() and Cache.EnemiesCount[DBRange] > 0
    and (
          I.DarcklisDragonfireDiadem:IsEquipped()
      or  S.AlexstraszasFury:IsAvailable() and not BuffP(S.HotStreak)
    ) then
    if AR.Cast(S.DragonsBreath) then return ""; end
  end
  -- actions.active_talents+=/living_bomb,if=active_enemies>1&buff.combustion.down
  if S.LivingBomb:IsCastable() and Cache.EnemiesCount[40] > 1 and not BuffP(S.Combustion) then
    if AR.Cast(S.LivingBomb) then return ""; end
  end
end
-- -- Start of CombustionPhase actions.
local function CombustionPhase ()
  --actions.combustion_phase=rune_of_power,if=buff.combustion.down
  if S.RuneOfPower:IsCastable() and not Player:IsCasting(S.RuneOfPower) and not BuffP(S.Combustion) then
    if AR.Cast(S.RuneOfPower) then return ""; end
  end
  --actions.combustion_phase+=/call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents();
  if ShouldReturn then return ShouldReturn; end
  --actions.combustion_phase+=/combustion
  if S.Combustion:IsCastable() then
    if AR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return ""; end
  end
  --actions.combustion_phase+=/potion
  if I.PotionofProlongedPower:IsUsable() then
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
  if S.Flamestrike:IsCastable() and BuffP(S.HotStreak)
    and (
      Cache.EnemiesCount[40] > 2 and S.FlamePatch:IsAvailable()
      or Cache.EnemiesCount[40] > 4
    )  then
    if AR.Cast(S.Flamestrike) then return ""; end
  end
  --actions.combustion_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&buff.combustion.remains>execute_time
  if S.Pyroblast:IsCastable() and BuffP(S.KaelthassUltimateAbility) and Player:BuffRemainsP(S.Combustion) > S.Pyroblast:ExecuteTime() then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.combustion_phase+=/pyroblast,if=buff.hot_streak.up
  if S.Pyroblast:IsCastable() and BuffP(S.HotStreak) then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.combustion_phase+=/fire_blast,if=buff.heating_up.up
  if S.Fireblast:IsCastable() and BuffP(S.HeatingUp) then
    if AR.Cast(S.Fireblast) then return ""; end
  end
  --actions.combustion_phase+=/phoenixs_flames
  if S.PhoenixFlames:IsCastable() then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end
  --actions.combustion_phase+=/scorch,if=buff.combustion.remains>cast_time
  if S.Scorch:IsCastable() and Player:BuffRemainsP(S.Combustion) > S.Scorch:ExecuteTime() then
    if AR.Cast(S.Scorch) then return ""; end
  end
  --actions.combustion_phase+=/dragons_breath,if=buff.hot_streak.down&action.fire_blast.charges<1&action.phoenixs_flames.charges<1
  if S.DragonsBreath:IsCastable() and Cache.EnemiesCount[DBRange] > 0 and not BuffP(S.HotStreak) and S.Fireblast:Charges() < 1 and S.PhoenixFlames:Charges() < 1 then
    if AR.Cast(S.DragonsBreath) then return ""; end
  end
  --actions.combustion_phase+=/scorch,if=target.health.pct<=30&equipped.132454
  if S.Scorch:IsCastable() and Target:HealthPercentage() <= 30 and I.KoralonsBurningTouch:IsEquipped() then
    if AR.Cast(S.Scorch) then return ""; end
  end
end

local function RopPhase ()
  --actions.rop_phase=rune_of_power
  if S.RuneOfPower:IsCastable() then
    if AR.Cast(S.RuneOfPower) then return ""; end
  end
  --actions.rop_phase+=/flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.up
  if S.Flamestrike:IsCastable() and BuffP(S.HotStreak)
    and (
      Cache.EnemiesCount[40] > 1 and S.FlamePatch:IsAvailable()
      or Cache.EnemiesCount[40] > 3
    )  then
    if AR.Cast(S.Flamestrike) then return ""; end
  end
  --actions.rop_phase+=/pyroblast,if=buff.hot_streak.up
  if S.Pyroblast:IsCastable() and BuffP(S.HotStreak) then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.rop_phase+=/call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents();
  if ShouldReturn then return ShouldReturn; end
  --actions.rop_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains&buff.rune_of_power.remains>cast_time
  if S.Pyroblast:IsCastable() and BuffP(S.KaelthassUltimateAbility) and S.Pyroblast:ExecuteTime() < Player:BuffRemainsP(S.KaelthassUltimateAbility) and math.min(10 - HL.OffsetRemains(S.RuneOfPowerAura:TimeSinceLastAppliedOnPlayer(), "Auto"), 0) > S.Pyroblast:CastTime() then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.up&firestarter.active&charges_fractional>1.7
  if S.Fireblast:IsCastable() and not Player:PrevOffGCDP(1, S.Fireblast) and BuffP(S.HeatingUp) and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 and S.Fireblast:ChargesFractional() > 1.7 then
    if AR.Cast(S.Fireblast) then return ""; end
  end
  --actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames&charges_fractional>2.7&firestarter.active
  if S.PhoenixFlames:IsCastable() and not Player:PrevGCDP(1, S.PhoenixFlames) and S.PhoenixFlames:ChargesFractional() > 2.7 and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end
  --actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
  if S.Fireblast:IsCastable() and not Player:PrevOffGCDP(1, S.Fireblast)
    and (
      S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90
      or not S.Firestarter:IsAvailable()
    ) then
    if AR.Cast(S.Fireblast) then return ""; end
  end
  --actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames
  if S.PhoenixFlames:IsCastable() and not Player:PrevGCDP(1, S.PhoenixFlames) then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end
  --actions.rop_phase+=/scorch,if=target.health.pct<=30&equipped.132454
  if S.Scorch:IsCastable() and Target:HealthPercentage() < 30 and I.KoralonsBurningTouch:IsEquipped() then
    if AR.Cast(S.Scorch) then return ""; end
  end
  --actions.rop_phase+=/dragons_breath,if=active_enemies>2
  if S.DragonsBreath:IsCastable() and Cache.EnemiesCount[DBRange] > 2 then
    if AR.Cast(S.DragonsBreath) then return ""; end
  end
  --actions.rop_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
  if S.Flamestrike:IsCastable()
    and (
      Cache.EnemiesCount[40] > 2 and S.FlamePatch:IsAvailable()
      or Cache.EnemiesCount[40] > 5
    ) then
    if AR.Cast(S.Flamestrike) then return ""; end
  end
  --actions.rop_phase+=/fireball
  if S.Fireball:IsCastable() then
    if AR.Cast(S.Fireball) then return ""; end
  end
end

local function StandardRotation ()
  --actions.standard_rotation=flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.up
  if S.Flamestrike:IsCastable() and BuffP(S.HotStreak)
    and (
      Cache.EnemiesCount[40] > 1 and S.FlamePatch:IsAvailable()
      or   Cache.EnemiesCount[40] > 3
    )  then
    if AR.Cast(S.Flamestrike) then return ""; end
  end
  --actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&buff.hot_streak.remains<action.fireball.execute_time
  if S.Pyroblast:IsCastable() and BuffP(S.HotStreak) and Player:BuffRemainsP(S.HotStreak) <  S.Fireball:ExecuteTime() then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&firestarter.active&!talent.rune_of_power.enabled
  if S.Pyroblast:IsCastable() and BuffP(S.HotStreak) and S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 and not S.RuneOfPower:IsAvailable() then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.7&active_enemies>2
  if S.PhoenixFlames:IsCastable() 
    and (
      S.PhoenixFlames:ChargesFractional() > 2.7 and Cache.EnemiesCount[40] > 2 
    ) then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end
  --actions.standard_rotation+=/pyroblast,if=buff.hot_streak.up&(!prev_gcd.1.pyroblast|action.pyroblast.in_flight)
  if S.Pyroblast:IsCastable() and BuffP(S.HotStreak) and (not Player:PrevGCDP(1, S.Pyroblast) or S.Pyroblast:InFlight()) then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&target.health.pct<=30&equipped.132454
  if S.Pyroblast:IsCastable() and BuffP(S.HotStreak) and Target:HealthPercentage() <= 30 and I.KoralonsBurningTouch:IsEquipped() then
      if AR.Cast(S.Pyroblast)  then return ""; end
  end
  --actions.standard_rotation+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
  if S.Pyroblast:IsCastable() and BuffP(S.KaelthassUltimateAbility) and S.Pyroblast:ExecuteTime() < Player:BuffRemainsP(S.KaelthassUltimateAbility) then
    if AR.Cast(S.Pyroblast) then return ""; end
  end
  --actions.standard_rotation+=/call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents();
  if ShouldReturn then return ShouldReturn; end
  --actions.standard_rotation+=/fire_blast,if=!talent.kindling.enabled&buff.heating_up.up&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die.remains<4
  if S.Fireblast:IsCastable() 
    and (
      not S.Kindling:IsAvailable() 
        and BuffP(S.HeatingUp) 
        and (
          not S.RuneOfPower:IsAvailable() 
          or S.Fireblast:ChargesFractional() > 1.4
          or S.Combustion:CooldownRemains() < 40
        )
        and (3 - S.Fireblast:ChargesFractional()) * (12 * Player:SpellHaste()) < S.Combustion:CooldownRemains() + 3 
      or Target:TimeToDie() < 4
    ) then
    if AR.Cast(S.Fireblast) then return ""; end
  end
  --actions.standard_rotation+=/fire_blast,if=talent.kindling.enabled&buff.heating_up.up&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die.remains<4
  if S.Fireblast:IsCastable()
    and (
      S.Kindling:IsAvailable() 
        and BuffP(S.HeatingUp)
        and (
          not S.RuneOfPower:IsAvailable()
          or S.Fireblast:ChargesFractional() > 1.5
          or S.Combustion:CooldownRemains() < 40
        )
        and (3 - S.Fireblast:ChargesFractional()) * (18 * Player:SpellHaste()) < S.Combustion:CooldownRemains() + 3  
      or Target:TimeToDie() < 4
    ) then
    if AR.Cast(S.Fireblast) then return ""; end
  end
  --actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&artifact.phoenix_reborn.enabled&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die.remains<10
  if S.PhoenixFlames:IsCastable()
    and (
      (    BuffP(S.Combustion)
        or BuffP(S.RuneOfPowerAura)
        or Player:BuffStack(S.IncantersFlow) > 3
        or S.MirrorImage:IsAvailable()
      )
        and (4 - S.PhoenixFlames:ChargesFractional()) * 13 < S.Combustion:CooldownRemainsP() + 5
      or Target:TimeToDie() < 4
    ) then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end
  --actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
  if S.PhoenixFlames:IsCastable() 
    and (
      BuffP(S.Combustion)
      or BuffP(S.RuneOfPowerAura)
    )
    and (4 - S.PhoenixFlames:ChargesFractional()) * 30 < S.Combustion:CooldownRemainsP() + 5 then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end 
  --actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
  if S.PhoenixFlames:IsCastable() and S.PhoenixFlames:ChargesFractional() > 2.5 and S.Combustion:CooldownRemainsP() > 23 then
    if AR.Cast(S.PhoenixFlames) then return ""; end
  end
  --actions.standard_rotation+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>3)|active_enemies>5
  if S.Flamestrike:IsCastable() 
    and (
      Cache.EnemiesCount[40] > 3 and S.FlamePatch:IsAvailable()
      or Cache.EnemiesCount[40] > 5
    ) then
    if AR.Cast(S.Flamestrike) then return ""; end
  end
  --actions.standard_rotation+=/scorch,if=target.health.pct<=30&equipped.132454
  if S.Scorch:IsCastable() and Target:HealthPercentage() < 30 and I.KoralonsBurningTouch:IsEquipped() then
    if AR.Cast(S.Scorch) then return ""; end
  end
  --actions.standard_rotation+=/fireball
  if S.Fireball:IsCastable() and not Player:IsMoving() then
    if AR.Cast(S.Fireball) then return ""; end
  end
  --actions.standard_rotation+=/scorch
  if S.Scorch:IsCastable() then
    if AR.Cast(S.Scorch) then return ""; end
  end
end

local function APL ()
  HL.GetEnemies(40);
  DBRange = (S.BigMouth:ArtifactEnabled() and 10 or 8) + (I.DarcklisDragonfireDiadem:IsEquipped() and 30 or 0);
  if DBRange < 40 then
    HL.GetEnemies(DBRange);
  end
  Everyone.AoEToggleEnemiesUpdate();
  -- Out of Combat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and Target:IsInRange(40) then
      if S.Pyroblast:IsCastable() then
        if AR.Cast(S.Pyroblast) then return ""; end
      end
    end
    return;
  end
  -- In Combat    
  if Everyone.TargetIsValid() then
    --actions+=/mirror_image,if=buff.combustion.down
    if S.MirrorImage:IsCastable() and not BuffP(S.Combustion) then
      if AR.Cast(S.MirrorImage) then return ""; end
    end
    --actions+=/rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die.remains<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
    if S.RuneOfPower:IsCastable() and not Player:IsCasting(S.RuneOfPower)
      and (
        S.Firestarter:IsAvailable() and Target:HealthPercentage() > 90 and S.RuneOfPower:Charges() == 2
        or S.Combustion:CooldownRemainsP() > 40 and not BuffP(S.Combustion) and not S.Kindling:IsAvailable()
        or Target:TimeToDie() < 11
        or S.Kindling:IsAvailable() and S.RuneOfPower:ChargesFractional() > 1.8
        or HL.CombatTime() < 40 and S.Combustion:CooldownRemainsP() > 40
      ) then
      if AR.Cast(S.RuneOfPower) then return ""; end
    end
    --actions+=/rune_of_power,if=(buff.kaelthas_ultimate_ability.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))|(buff.erupting_infernal_core.up&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))
    if S.RuneOfPower:IsCastable() and not Player:IsCasting(S.RuneOfPower)
      and (
        BuffP(S.KaelthassUltimateAbility) and S.Combustion:CooldownRemainsP() > 40
        or S.RuneOfPower:IsCastable() and BuffP(S.EruptingInfernalCore) and S.Combustion:CooldownRemainsP() > 40
        or S.RuneOfPower:Charges() > 1
      ) then
      if AR.Cast(S.RuneOfPower) then return ""; end
    end
    --actions+=/call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
    if AR.CDsON() and (
      S.Combustion:CooldownRemainsP() <= (S.RuneOfPower:CastTime()) + ((not S.Kindling:IsAvailable() and 1 or 0) * Player:GCD())
      and (
        not S.Firestarter:IsAvailable()
        or not (Target:HealthPercentage() > 90 and S.Firestarter:IsAvailable())
        or Cache.EnemiesCount[40] >= 4
        or (Cache.EnemiesCount[40] >= 2 and S.FlamePatch:IsAvailable())
      ) 
      or BuffP(S.Combustion)
      ) then 
      local ShouldReturn = CombustionPhase();
      if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
    if BuffP(S.RuneOfPowerAura) and not BuffP(S.Combustion) then
      local ShouldReturn = RopPhase();
      if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/call_action_list,name=standard_rotation
    local ShouldReturn = StandardRotation();
    if ShouldReturn then return ShouldReturn; end
    return;
  end
end

AR.SetAPL(63, APL);

-- Simulationcraft APL - Taken 2017-11-24

-- # Executed every time the actor is available.
-- actions=counterspell,if=target.debuff.casting.react
-- actions+=/time_warp,if=(time=0&buff.bloodlust.down)|(buff.bloodlust.down&equipped.132410&(cooldown.combustion.remains<1|target.time_to_die<50))
-- actions+=/mirror_image,if=buff.combustion.down
-- # Standard Talent RoP Logic.
-- actions+=/rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
-- # RoP use while using Legendary Items.
-- actions+=/rune_of_power,if=(buff.kaelthas_ultimate_ability.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))|(buff.erupting_infernal_core.up&(cooldown.combustion.remains>40|action.rune_of_power.charges>1))
-- actions+=/call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
-- actions+=/call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
-- actions+=/call_action_list,name=standard_rotation

-- actions.active_talents=blast_wave,if=(buff.combustion.down)|(buff.combustion.up&action.fire_blast.charges<1&action.phoenixs_flames.charges<1)
-- actions.active_talents+=/meteor,if=cooldown.combustion.remains>40|(cooldown.combustion.remains>target.time_to_die)|buff.rune_of_power.up|firestarter.active
-- actions.active_talents+=/cinderstorm,if=cooldown.combustion.remains<cast_time&(buff.rune_of_power.up|!talent.rune_on_power.enabled)|cooldown.combustion.remains>10*spell_haste&!buff.combustion.up
-- actions.active_talents+=/dragons_breath,if=equipped.132863|(talent.alexstraszas_fury.enabled&!buff.hot_streak.react)
-- actions.active_talents+=/living_bomb,if=active_enemies>1&buff.combustion.down

-- actions.combustion_phase=rune_of_power,if=buff.combustion.down
-- actions.combustion_phase+=/call_action_list,name=active_talents
-- actions.combustion_phase+=/combustion
-- actions.combustion_phase+=/potion
-- actions.combustion_phase+=/blood_fury
-- actions.combustion_phase+=/berserking
-- actions.combustion_phase+=/arcane_torrent
-- actions.combustion_phase+=/use_items
-- actions.combustion_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2|active_enemies>4)&buff.hot_streak.react
-- actions.combustion_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&buff.combustion.remains>execute_time
-- actions.combustion_phase+=/pyroblast,if=buff.hot_streak.react
-- actions.combustion_phase+=/fire_blast,if=buff.heating_up.react
-- actions.combustion_phase+=/phoenixs_flames
-- actions.combustion_phase+=/scorch,if=buff.combustion.remains>cast_time
-- actions.combustion_phase+=/dragons_breath,if=!buff.hot_streak.react&action.fire_blast.charges<1&action.phoenixs_flames.charges<1
-- actions.combustion_phase+=/scorch,if=target.health.pct<=30&equipped.132454

-- actions.rop_phase=rune_of_power
-- actions.rop_phase+=/flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.react
-- actions.rop_phase+=/pyroblast,if=buff.hot_streak.react
-- actions.rop_phase+=/call_action_list,name=active_talents
-- actions.rop_phase+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains&buff.rune_of_power.remains>cast_time
-- actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.react&firestarter.active&charges_fractional>1.7
-- actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames&charges_fractional>2.7&firestarter.active
-- actions.rop_phase+=/fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
-- actions.rop_phase+=/phoenixs_flames,if=!prev_gcd.1.phoenixs_flames
-- actions.rop_phase+=/scorch,if=target.health.pct<=30&equipped.132454
-- actions.rop_phase+=/dragons_breath,if=active_enemies>2
-- actions.rop_phase+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
-- actions.rop_phase+=/fireball

-- actions.standard_rotation=flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>3)&buff.hot_streak.react
-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&firestarter.active&!talent.rune_of_power.enabled
-- actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.7&active_enemies>2
-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&(!prev_gcd.1.pyroblast|action.pyroblast.in_flight)
-- actions.standard_rotation+=/pyroblast,if=buff.hot_streak.react&target.health.pct<=30&equipped.132454
-- actions.standard_rotation+=/pyroblast,if=buff.kaelthas_ultimate_ability.react&execute_time<buff.kaelthas_ultimate_ability.remains
-- actions.standard_rotation+=/call_action_list,name=active_talents
-- actions.standard_rotation+=/fire_blast,if=!talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
-- actions.standard_rotation+=/fire_blast,if=talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
-- actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&artifact.phoenix_reborn.enabled&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die<10
-- actions.standard_rotation+=/phoenixs_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
-- actions.standard_rotation+=/phoenixs_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
-- actions.standard_rotation+=/flamestrike,if=(talent.flame_patch.enabled&active_enemies>3)|active_enemies>5
-- actions.standard_rotation+=/scorch,if=target.health.pct<=30&equipped.132454
-- actions.standard_rotation+=/fireball
-- actions.standard_rotation+=/scorch

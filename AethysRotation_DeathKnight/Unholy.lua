--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua

  --- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local DeathKnight = AR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Unholy = {
    -- Racials
  ArcaneTorrent                 = Spell(50613),
  Berserking                    = Spell(26297),
  BloodFury                     = Spell(20572),
  GiftoftheNaaru                = Spell(59547),
    -- Artifact
  Apocalypse                    = Spell(220143),
  --Abilities
  ArmyOfDead                    = Spell(42650),
  ChainsOfIce                   = Spell(45524),
  ScourgeStrike                 = Spell(55090),
  DarkTransformation            = Spell(63560),
  DeathAndDecay                 = Spell(43265),
  DeathCoil                     = Spell(47541),
  DeathStrike                   = Spell(49998),
  FesteringStrike               = Spell(85948),
  Outbreak                      = Spell(77575),
  SummonGargoyle                = Spell(49206),
  SummonPet                     = Spell(46584),
     --Talents
  BlightedRuneWeapon            = Spell(194918),
  Epidemic                      = Spell(207317),
  Castigator                    = Spell(207305),
  ClawingShadows                = Spell(207311),
  Necrosis                      = Spell(207346),
  ShadowInfusion                = Spell(198943),
  DarkArbiter                   = Spell(207349),
  Defile                        = Spell(152280),
  SoulReaper                    = Spell(130736),
  --Buffs/Procs
  MasterOfGhouls                = Spell(246995),
  SuddenDoom                    = Spell(81340),
  UnholyStrength                = Spell(53365),
  NecrosisBuff                  = Spell(216974),
  DeathAndDecayBuff             = Spell(188290),
  --Debuffs
  SoulReaperDebuff              = Spell(130736),
  FesteringWounds               = Spell(194310), --max 8 stacks
  VirulentPlagueDebuff          = Spell(191587), -- 13s debuff from Outbreak
  --Defensives
  AntiMagicShell                = Spell(48707),
  IcebornFortitute              = Spell(48792),
   -- Utility
  ControlUndead                 = Spell(45524),
  DeathGrip                     = Spell(49576),
  MindFreeze                    = Spell(47528),
  PathOfFrost                   = Spell(3714),
  WraithWalk                    = Spell(212552),
  --Legendaries Buffs/SpellIds 
  ColdHeartBuff                 = Spell(235599),
  InstructorsFourthLesson       = Spell(208713),
  KiljaedensBurningWish         = Spell(144259),
  --DarkArbiter HiddenAura
  DarkArbiterActive             = Spell(212412),
  -- Misc
  PoolForArmy                   = Spell(9999000010)
  
  
  };
  local S = Spell.DeathKnight.Unholy;
  --Items
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Unholy = {
    --Legendaries WIP
  ConvergenceofFates            = Item(140806, {13, 14}),
  InstructorsFourthLesson       = Item(132448, {9}),
  Taktheritrixs                 = Item(137075, {3}),
  ColdHeart                    = Item(151796, {5}),
  
  
  };
  local I = Item.DeathKnight.Unholy;
 --Rotation Var


  --GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DeathKnight.Commons,
    Unholy = AR.GUISettings.APL.DeathKnight.Unholy
  };
  

  --- ===== APL =====
  --- ===============
  local function AOE()
  --actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
  if S.DeathAndDecay:IsCastable() and Cache.EnemiesCount[10] >= 2 then
    if AR.Cast(S.DeathAndDecay) then return ""; end
  end
  --actions.aoe+=/epidemic,if=spell_targets.epidemic>4
  if S.Epidemic:IsCastable() and Cache.EnemiesCount[10] > 4 then
    if AR.Cast(S.Epidemic) then return ""; end
  end
  --actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(death_and_decay.ticking|defile.ticking)
  if S.ScourgeStrike:IsCastable() and (Cache.EnemiesCount[10] >= 2 and Player:Buff(S.DeathAndDecayBuff)) or Target:Debuff(S.FesteringWounds) then
    if AR.Cast(S.ScourgeStrike) then return ""; end
  end
  --actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
  if S.ClawingShadows:IsCastable() and Cache.EnemiesCount[10] >= 2 and Player:Buff(S.DeathAndDecayBuff) then
    if AR.Cast(S.ClawingShadows) then return ""; end
  end 
  --actions.aoe+=/epidemic,if=spell_targets.epidemic>2
  if S.Epidemic:IsCastable() and Cache.EnemiesCount[10] > 2 then
    if AR.Cast(S.Epidemic) then return ""; end
  end
  return;
end
 local function Generic()
  --actions.generic=scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.up
  if S.ScourgeStrike:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and Target:Debuff(S.FesteringWounds) then
    if AR.Cast(S.ScourgeStrike) then return ""; end
  end
  --actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.up
  if S.ClawingShadows:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and Target:Debuff(S.FesteringWounds) then
    if AR.Cast(S.ClawingShadows) then return ""; end
  end
  --actions.generic+=/death_coil,if=runic_power.deficit<22&(talent.shadow_infusion.enabled|(!talent.dark_arbiter.enabled|cooldown.dark_arbiter.remains>5))
  if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 22 and (S.ShadowInfusion:IsAvailable() or (not S.DarkArbiter:IsAvailable() or S.DarkArbiter:CooldownRemainsP() > 5)) then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/death_coil,if=!buff.necrosis.up&buff.sudden_doom.react&((!talent.dark_arbiter.enabled&rune<=3)|cooldown.dark_arbiter.remains>5)
  if S.DeathCoil:IsUsable() and not Player:Buff(S.NecrosisBuff) and Player:Buff(S.SuddenDoom) and ((not S.DarkArbiter:IsAvailable() and Player:Runes() <= 3) or S.DarkArbiter:CooldownRemainsP() > 5) then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
  if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 6 and S.Apocalypse:CooldownRemains() <= 6 then
    if AR.Cast(S.FesteringStrike) then return ""; end
  end
  --actions.generic+=/defile
  if S.Defile:IsAvailable() and S.Defile:IsCastable() then
    if AR.Cast(S.Defile) then return ""; end
  end
  --actions.generic+=/call_action_list,name=aoe,if=active_enemies>=2
  if AR.AoEON() and Cache.EnemiesCount[10] >= 2 then
    return AOE();
  end
  --actions.generic+=/festering_strike,if=(buff.blighted_rune_weapon.stack*2+debuff.festering_wound.stack)<=2|((buff.blighted_rune_weapon.stack*2+debuff.festering_wound.stack)<=4&talent.castigator.enabled)&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
  if S.FesteringStrike:IsCastable() and (Player:BuffStack(S.BlightedRuneWeapon) * 2 + Target:DebuffStack(S.FesteringWounds)) <= 2 or ((Player:BuffStack(S.BlightedRuneWeapon) * 2 + Target:DebuffStack(S.FesteringWounds)) <= 4 and S.Castigator:IsAvailable()) and (S.ArmyOfDead:CooldownRemainsP() > 5 or Player:RuneTimeToX(4) <= Player:GCD()) then
    if AR.Cast(S.FesteringStrike) then return ""; end
  end
  --actions.generic+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune.time_to_4>=gcd
  if S.DeathCoil:IsUsable() and not Player:Buff(S.NecrosisBuff) and S.Necrosis:IsAvailable() and Player:RuneTimeToX(4) >= Player:GCD() then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/scourge_strike,if=(buff.necrosis.up|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!(talent.castigator.enabled|equipped.132448))&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
  if S.ScourgeStrike:IsCastable() and (Player:Buff(S.NecrosisBuff) or Player:Buff(S.UnholyStrength) or Player:Runes() >= 2) and Target:DebuffStack(S.FesteringWounds) >= 1 and (Target:DebuffStack(S.FesteringWounds) >= 3 or not (S.Castigator:IsAvailable() or I.InstructorsFourthLesson:IsEquipped())) and (S.ArmyOfDead:CooldownRemainsP() > 5 or Player:RuneTimeToX(4) <= Player:GCD()) then
    if AR.Cast(S.ScourgeStrike) then return ""; end
  end
  --actions.generic+=/clawing_shadows,if=(buff.necrosis.up|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!equipped.132448)&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
  if S.ClawingShadows:IsCastable() and (Player:Buff(S.NecrosisBuff) or Player:Buff(S.UnholyStrength) or Player:Runes() >= 2) and Target:DebuffStack(S.FesteringWounds) >= 1 and (Target:DebuffStack(S.FesteringWounds) >= 3 or not I.InstructorsFourthLesson:IsEquipped()) and (S.ArmyOfDead:CooldownRemainsP() > 5 or Player:RuneTimeToX(4) <= Player:GCD()) then
    if AR.Cast(S.ClawingShadows) then return ""; end
  end
  --actions.generic+=/death_coil,if=(talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10)|!talent.dark_arbiter.enabled
  if S.DeathCoil:IsUsable() and (S.DarkArbiter:IsAvailable() and S.DarkArbiter:CooldownRemainsP() > 10) or not S.DarkArbiter:IsAvailable() then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  return;
end

 --DarkArbiter
local function DarkArbiter()
--actions.valkyr=death_coil
 if S.DeathCoil:IsUsable() and (Player:Buff(S.SuddenDoom) or Player:RunicPower() >= 45) then
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
 --actions.valkyr+=/arcane_torrent,if=runic_power<45|runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and ( Player:RunicPower() < 45 or Player:RunicPowerDeficit() > 20 ) then
  if AR.Cast(S.ArcaneTorrent, Settings.Unholy.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
 end
 --actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<3
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 6  and S.Apocalypse:CooldownRemainsP() < 3 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
 --actions.valkyr+=/call_action_list,name=aoe,if=active_enemies>=2
 if Cache.EnemiesCount[10] >= 2 then
  return AOE();
 end
 --actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=4
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 4 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
 --actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
 if S.ClawingShadows:IsCastable() and Target:Debuff(S.FesteringWounds) then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
 --actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
 if S.ScourgeStrike:IsCastable() and Target:Debuff(S.FesteringWounds) then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
  return;
end

local function DT()
  --actions.dt=dark_transformation,if=equipped.137075&talent.dark_arbiter.enabled&(talent.shadow_infusion.enabled|cooldown.dark_arbiter.remains>52)&cooldown.dark_arbiter.remains>30&!equipped.140806
  if S.DarkTransformation:IsCastable() and I.Taktheritrixs:IsEquipped() and S.DarkArbiter:IsAvailable() and (S.ShadowInfusion:IsAvailable() or S.DarkArbiter:CooldownRemainsP() > 52) and S.DarkArbiter:CooldownRemainsP() > 30 and not I.ConvergenceofFates:IsEquipped() then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
  --actions.dt+=/dark_transformation,if=equipped.137075&(talent.shadow_infusion.enabled|cooldown.dark_arbiter.remains>(52*1.333))&equipped.140806&cooldown.dark_arbiter.remains>(30*1.333)
  if S.DarkTransformation:IsCastable() and I.Taktheritrixs:IsEquipped() and (S.ShadowInfusion:IsAvailable() or S.DarkArbiter:CooldownRemainsP() > (52 * 1.333)) and I.ConvergenceofFates:IsEquipped() and S.DarkArbiter:CooldownRemainsP() > (30 * 1.333) then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
  --actions.dt+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
  if S.DarkTransformation:IsCastable() and I.Taktheritrixs:IsEquipped() and Target:TimeToDie() < S.DarkArbiter:CooldownRemainsP() - 8 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
  --actions.dt+=/dark_transformation,if=equipped.137075&(talent.shadow_infusion.enabled|cooldown.summon_gargoyle.remains>55)&cooldown.summon_gargoyle.remains>35
  if S.DarkTransformation:IsCastable() and I.Taktheritrixs:IsEquipped() and (S.ShadowInfusion:IsAvailable() or S.SummonGargoyle:CooldownRemainsP() > 55) and S.SummonGargoyle:CooldownRemainsP() > 35 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
  --actions.dt+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
  if S.DarkTransformation:IsCastable() and I.Taktheritrixs:IsEquipped() and Target:TimeToDie() < S.SummonGargoyle:CooldownRemainsP() - 8 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
  --actions.dt+=/dark_transformation,if=!equipped.137075&rune.time_to_4>=gcd
  if S.DarkTransformation:IsCastable() and not I.Taktheritrixs:IsEquipped() and Player:RuneTimeToX(4) >= Player:GCD() then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
    
  return;
end
local function ColdHeart()
  --actions.cold_heart=chains_of_ice,if=buff.unholy_strength.remains<gcd&buff.unholy_strength.react&buff.cold_heart.stack>16
  if S.ChainsOfIce:IsCastable() and Player:BuffRemainsP(S.UnholyStrength) < Player:GCD() and Player:Buff(S.UnholyStrength) and Player:BuffStack(S.ColdHeartBuff) > 16 then
    if AR.Cast(S.ChainsOfIce) then return ""; end
  end
  --actions.cold_heart+=/chains_of_ice,if=buff.master_of_ghouls.remains<gcd&buff.master_of_ghouls.up&buff.cold_heart.stack>17
  if S.ChainsOfIce:IsCastable() and Player:BuffRemainsP(S.MasterOfGhouls) < Player:GCD() and Player:Buff(S.MasterOfGhouls) and Player:BuffStack(S.ColdHeartBuff) > 17 then
    if AR.Cast(S.ChainsOfIce) then return ""; end
  end
  --actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack=20&buff.unholy_strength.react
  if S.ChainsOfIce:IsCastable() and Player:BuffStack(S.ColdHeartBuff) == 20 and Player:Buff(S.UnholyStrength) then
    if AR.Cast(S.ChainsOfIce) then return ""; end
  end
  return;
end 
local function Cooldowns()
  --actions.cooldowns=call_action_list,name=cold_heart,if=equipped.cold_heart&buff.cold_heart.stack>10&!debuff.soul_reaper.up
  if I.ColdHeart and Player:BuffStack(S.ColdHeartBuff) >= 15 and not Target:Debuff(S.SoulReaperDebuff) then
    ShouldReturn = ColdHeart();
    if ShouldReturn then return ShouldReturn; end
  end
  -- t20 gameplay
  if AR.CDsON() and S.ArmyOfDead:IsCastable() and Player:Runes() >= 3 then
    if AR.Cast(S.ArmyOfDead, Settings.Unholy.GCDasOffGCD.ArmyOfDead) then return ""; end
  elseif AR.CDsON() and (S.ArmyOfDead:IsCastable() or S.ArmyOfDead:CooldownRemainsP() <= 5) and  S.DarkArbiter:TimeSinceLastCast() > 20 and Player:Runes() <= 3 then
    if AR.Cast(S.PoolForArmy) then return "Pool For Army"; end
  end
  --actions.cooldowns+=/apocalypse,if=debuff.festering_wound.stack>=6
  if S.Apocalypse:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 6 then
    if AR.Cast(S.Apocalypse) then return ""; end
  end
  --actions.cooldowns+=/dark_arbiter,if=(!equipped.137075|cooldown.dark_transformation.remains<2)&runic_power.deficit<30
  if S.DarkArbiter:IsAvailable() and S.DarkArbiter:IsCastable() and (not I.Taktheritrixs:IsEquipped() or S.DarkTransformation:CooldownRemains() < 2) and Player:RunicPowerDeficit() < 30 then
    if AR.Cast(S.DarkArbiter, Settings.Unholy.GCDasOffGCD.DarkArbiter) then return ""; end
  end
  --actions.cooldowns+=/summon_gargoyle,if=(!equipped.137075|cooldown.dark_transformation.remains<10)&rune.time_to_4>=gcd
  if S.SummonGargoyle:IsCastable() and (not I.Taktheritrixs:IsEquipped() or S.DarkTransformation:CooldownRemainsP() < 10) and Player:RuneTimeToX(4) >= Player:GCD() then
    if AR.Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return ""; end
  end
  --actions.cooldowns+=/soul_reaper,if=(debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<=gcd)|(debuff.festering_wound.stack>=3&rune>=3&cooldown.apocalypse.remains>20)
  if (S.SoulReaper:IsAvailable() and S.SoulReaper:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 6 and S.Apocalypse:CooldownRemainsP() <= Player:GCD()) or (S.SoulReaper:IsAvailable() and S.SoulReaper:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 3 and S.Apocalypse:CooldownRemains() > 20) then
    if AR.Cast(S.SoulReaper) then return ""; end
  end
  --actions.cooldowns+=/call_action_list,name=dt,if=cooldown.dark_transformation.ready
  if S.DarkTransformation:IsReady() then
    ShouldReturn = DT();
    if ShouldReturn then return ShouldReturn; end
  end
  return;
end

local function APL()
    --UnitUpdate
  AC.GetEnemies(10);
  Everyone.AoEToggleEnemiesUpdate();
  --Defensives
  --OutOf Combat
    -- Reset Combat Variables
    -- Flask
      -- Food
      -- Rune
      -- Army w/ Bossmod Countdown 
      -- Volley toggle
      -- Opener 

    if not Player:AffectingCombat() then
    --check if we have our lovely pet with us
    if not Pet:IsActive() and S.SummonPet:IsCastable() then
    if AR.Cast(S.SummonPet) then return ""; end
    end
  --army suggestion at pull
    if Everyone.TargetIsValid() and Target:IsInRange(30) and S.ArmyOfDead:CooldownUp() then
          if AR.Cast(S.ArmyOfDead, Settings.Unholy.GCDasOffGCD.ArmyOfDead) then return ""; end
    end
  -- outbreak if virulent_plague is not  the target and we are not in combat
    if Everyone.TargetIsValid() and Target:IsInRange(30) and not Target:Debuff(S.VirulentPlagueDebuff)then
      if AR.Cast(S.Outbreak) then return ""; end
    end
      return;
    end
    --InCombat
      --actions+=/outbreak,target_if=(dot.virulent_plague.tick_time_remains+tick_time<=dot.virulent_plague.remains)&dot.virulent_plague.remains<=gcd
    if S.Outbreak:IsUsable() and not Target:Debuff(S.VirulentPlagueDebuff) or Target:DebuffRemainsP(S.VirulentPlagueDebuff) < Player:GCD()*1.5 then
      if AR.Cast(S.Outbreak) then return ""; end
    end
    --Lets call specific APLs
    if Everyone.TargetIsValid()  then
        ShouldReturn = Cooldowns();
        if ShouldReturn then return ShouldReturn; 
    end
    
    if (S.DarkArbiter:IsAvailable() and  S.DarkArbiter:TimeSinceLastCast() > 22) or S.Defile:IsAvailable() or S.SoulReaper:IsAvailable() then
    ShouldReturn = Generic();
    if ShouldReturn then return ShouldReturn; end
    end

    if S.DarkArbiter:TimeSinceLastCast() <= 22 then
       ShouldReturn = DarkArbiter();
       if ShouldReturn then return ShouldReturn;  end
    end
    return
  end
end

AR.SetAPL(252, APL);
--- ====27/11/2017======
--- ======= SIMC =======  
--# Default consumables
--potion=prolonged_power
----flask=countless_armies
--food=azshari_salad
--augmentation=defiled

--# This default action priority list is automatically created based on your character.
--# It is a attempt to provide you with a action list that is both simple and practicable,
--# while resulting in a meaningful and good simulation. It may not result in the absolutely highest possible dps.
--# Feel free to edit, adapt and improve it to your own needs.
--# SimulationCraft is always looking for updates and improvements to the default action lists.

--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/potion
--actions.precombat+=/raise_dead
--actions.precombat+=/army_of_the_dead
--actions.precombat+=/blighted_rune_weapon

--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/mind_freeze
--# Racials, Items, and other ogcds
--actions+=/arcane_torrent,if=runic_power.deficit>20
--actions+=/blood_fury
--actions+=/berserking
--actions+=/use_items
--actions+=/use_item,name=feloiled_infernal_machine,if=pet.valkyr_battlemaiden.active|!talent.dark_arbiter.enabled
--actions+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--actions+=/potion,if=buff.unholy_strength.react
--actions+=/blighted_rune_weapon,if=debuff.festering_wound.stack<=4
--# Maintain Virulent Plague
--actions+=/outbreak,target_if=(dot.virulent_plague.tick_time_remains+tick_time<=dot.virulent_plague.remains)&dot.virulent_plague.remains<=gcd
--actions+=/call_action_list,name=cooldowns
--actions+=/run_action_list,name=valkyr,if=pet.valkyr_battlemaiden.active&talent.dark_arbiter.enabled
--actions+=/call_action_list,name=generic

--# AoE rotation
--actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
--actions.aoe+=/epidemic,if=spell_targets.epidemic>4
--actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(death_and_decay.ticking|defile.ticking)
--actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(death_and_decay.ticking|defile.ticking)
--actions.aoe+=/epidemic,if=spell_targets.epidemic>2

--# Cold Heart legendary
--actions.cold_heart=chains_of_ice,if=buff.unholy_strength.remains<gcd&buff.unholy_strength.react&buff.cold_heart.stack>16
--actions.cold_heart+=/chains_of_ice,if=buff.master_of_ghouls.remains<gcd&buff.master_of_ghouls.up&buff.cold_heart.stack>17
--actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack=20&buff.unholy_strength.react

--# Cold heart and other on-gcd cooldowns
--actions.cooldowns=call_action_list,name=cold_heart,if=equipped.cold_heart&buff.cold_heart.stack>10&!debuff.soul_reaper.up
--actions.cooldowns+=/army_of_the_dead
--actions.cooldowns+=/apocalypse,if=debuff.festering_wound.stack>=6
--actions.cooldowns+=/dark_arbiter,if=(!equipped.137075|cooldown.dark_transformation.remains<2)&runic_power.deficit<30
--actions.cooldowns+=/summon_gargoyle,if=(!equipped.137075|cooldown.dark_transformation.remains<10)&rune.time_to_4>=gcd
--actions.cooldowns+=/soul_reaper,if=(debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<=gcd)|(debuff.festering_wound.stack>=3&rune>=3&cooldown.apocalypse.remains>20)
--actions.cooldowns+=/call_action_list,name=dt,if=cooldown.dark_transformation.ready

--# Dark Transformation List
--actions.dt=dark_transformation,if=equipped.137075&talent.dark_arbiter.enabled&(talent.shadow_infusion.enabled|cooldown.dark_arbiter.remains>52)&cooldown.dark_arbiter.remains>30&!equipped.140806
--actions.dt+=/dark_transformation,if=equipped.137075&(talent.shadow_infusion.enabled|cooldown.dark_arbiter.remains>(52*1.333))&equipped.140806&cooldown.dark_arbiter.remains>(30*1.333)
--actions.dt+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
--actions.dt+=/dark_transformation,if=equipped.137075&(talent.shadow_infusion.enabled|cooldown.summon_gargoyle.remains>55)&cooldown.summon_gargoyle.remains>35
--actions.dt+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
--actions.dt+=/dark_transformation,if=!equipped.137075&rune.time_to_4>=gcd

--# Default rotation
--actions.generic=scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.up
--actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.up
--actions.generic+=/death_coil,if=runic_power.deficit<22&(talent.shadow_infusion.enabled|(!talent.dark_arbiter.enabled|cooldown.dark_arbiter.remains>5))
--actions.generic+=/death_coil,if=!buff.necrosis.up&buff.sudden_doom.react&((!talent.dark_arbiter.enabled&rune<=3)|cooldown.dark_arbiter.remains>5)
--actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
--actions.generic+=/defile
--# Switch to aoe
--actions.generic+=/call_action_list,name=aoe,if=active_enemies>=2
--# Wounds management
--actions.generic+=/festering_strike,if=(buff.blighted_rune_weapon.stack*2+debuff.festering_wound.stack)<=2|((buff.blighted_rune_weapon.stack*2+debuff.festering_wound.stack)<=4&talent.castigator.enabled)&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
--actions.generic+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune.time_to_4>=gcd
--actions.generic+=/scourge_strike,if=(buff.necrosis.up|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!(talent.castigator.enabled|equipped.132448))&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
--actions.generic+=/clawing_shadows,if=(buff.necrosis.up|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!equipped.132448)&(cooldown.army_of_the_dead.remains>5|rune.time_to_4<=gcd)
--actions.generic+=/death_coil,if=(talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10)|!talent.dark_arbiter.enabled

--# Val'kyr rotation
--actions.valkyr=death_coil
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<3
--actions.valkyr+=/call_action_list,name=aoe,if=active_enemies>=2
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=4
--actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
--actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
  

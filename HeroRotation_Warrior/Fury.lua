--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = H
local CDsON      = HR.CDsON

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Fury
local I = Item.Warrior.Fury
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemies8y, Enemies20y
local EnemiesCount8, EnemiesCount20

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Fury = HR.GUISettings.APL.Warrior.Fury
}

-- Interrupts List
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
  {S.IntimidatingShout, "Cast Intimidating Shout (Interrupt)", function () return true; end},
}

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight()
end, "AZERITE_ESSENCE_ACTIVATED")
S.ConcentratedFlame:RegisterInFlight()

-- Variables
--local VarPoolingForMeta = false


HL:RegisterForEvent(function()
  --VarPoolingForMeta = false
end, "PLAYER_REGEN_ENABLED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function Precombat()
  --# Executed before combat begins. Accepts non-harmful actions only.
  --actions.precombat=flask
  --actions.precombat+=/food
  --actions.precombat+=/augmentation
  --# Snapshot raid buffed stats before combat begins and pre-potting is done.
  --actions.precombat+=/snapshot_stats
  --actions.precombat+=/use_item,name=azsharas_font_of_power
  if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.AzsharasFontofPower) then return "azsharas_font_of_power"; end
  end
  --actions.precombat+=/worldvein_resonance
  if S.WorldveinResonance:IsCastableP() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance precombat"; end
  end
  --actions.precombat+=/memory_of_lucid_dreams
  if S.MemoryofLucidDreams:IsCastableP() then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams precombat"; end
  end
  --actions.precombat+=/guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastableP() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth precombat"; end
  end
  --actions.precombat+=/recklessness
  if S.Recklessness:IsCastableP() then
    if HR.Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat"; end
  end
  --actions.precombat+=/potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury"; end
  end
end

local function Movement()
  --actions.movement=heroic_leap
  if S.HeroicLeap:IsCastableP() then
    if HR.Cast(S.HeroicLeap, Settings.Fury.GCDasOffGCD.HeroicLeap) then return "heroic_leap"; end
  end
end

local function SingleTarget()
  --actions.single_target=siegebreaker
  if S.Siegebreaker:IsCastable("Melee") and HR.CDsON() then
    if HR.Cast(S.Siegebreaker, Settings.Fury.GCDasOffGCD.Siegebreaker) then return "siegebreaker"; end
  end
  --actions.single_target+=/rampage,if=(buff.recklessness.up|buff.memory_of_lucid_dreams.up)|(buff.enrage.remains<gcd|rage>90)
  if S.Rampage:IsReady("Melee") and (Player:BuffP(S.RecklessnessBuff) or Player:BuffP(S.MemoryofLucidDreams)) or (Player:BuffRemainsP(S.EnrageBuff) < Player:GCD() or Player:Rage() > 90) then
    if HR.Cast(S.Rampage) then return "rampage"; end
  end
  --actions.single_target+=/execute
  if S.Execute:IsReady("Melee") then
    if HR.Cast(S.Execute) then return "execute"; end
  end
  --actions.single_target+=/bladestorm,if=prev_gcd.1.rampage
  if S.Bladestorm:IsCastableP("Melee") and HR.CDsON() and (Player:PrevGCDP(1, S.Rampage)) then
    if HR.Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm) then return "bladestorm"; end
  end
  --actions.single_target+=/bloodthirst,if=buff.enrage.down|azerite.cold_steel_hot_blood.rank>1
  if S.Bloodthirst:IsCastableP("Melee") and (Player:BuffDownP(S.EnrageBuff) or S.ColdSteelHotBlood:AzeriteRank() > 1) then
    if HR.Cast(S.Bloodthirst) then return "bloodthirst"; end
  end
  --actions.single_target+=/onslaught
  if S.Onslaught:IsReady("Melee") then
    if HR.Cast(S.Onslaught) then return "onslaught"; end
  end
  --actions.single_target+=/dragon_roar,if=buff.enrage.up
  if S.DragonRoar:IsCastableP(12) and HR.CDsON() and (Player:BuffP(S.EnrageBuff)) then
    if HR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar) then return "dragon_roar"; end
  end
  --actions.single_target+=/raging_blow,if=charges=2
  if S.RagingBlow:IsCastableP("Melee") and (S.RagingBlow:ChargesP() == 2) then
    if HR.Cast(S.RagingBlow) then return "raging_blow"; end
  end
  --actions.single_target+=/bloodthirst
  if S.Bloodthirst:IsCastableP("Melee") then
    if HR.Cast(S.Bloodthirst) then return "bloodthirst"; end
  end
  --actions.single_target+=/raging_blow
  if S.RagingBlow:IsCastableP("Melee") then
    if HR.Cast(S.RagingBlow) then return "raging_blow"; end
  end
  --actions.single_target+=/whirlwind
  if S.Whirlwind:IsCastableP("Melee") then
    if HR.Cast(S.Whirlwind) then return "whirlwind 74"; end
  end
end

---- Action List ----

local function APL()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  --UpdateExecuteID()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    --# Executed every time the actor is available.
    --actions=auto_attack
    --actions+=/charge
    if S.Charge:IsReady() and S.Charge:ChargesP() >= 1 then
      if HR.Cast(S.Charge, Settings.Fury.GCDasOffGCD.Charge) then return "charge"; end
    end
    --# This is mostly to prevent cooldowns from being accidentally used during movement.
    --actions+=/run_action_list,name=movement,if=movement.distance>5
    --actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if ((not Target:IsInRange("Melee")) and Target:IsInRange(40)) then
      return Movement();
    end
    --actions+=/rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
    if S.Rampage:IsReadyP("Melee") and (S.Recklessness:CooldownRemainsP() < 3 and S.RecklessAbandon:IsAvailable()) then
      if HR.Cast(S.Rampage) then return "rampage"; end
    end
    --actions+=/blood_of_the_enemy,if=(buff.recklessness.up|cooldown.recklessness.remains<1)&(rage>80&(buff.meat_cleaver.up&buff.enrage.up|spell_targets.whirlwind=1)|dot.noxious_venom.remains)
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.RecklessnessBuff) or S.Recklessness:CooldownRemainsP() < 1) and (Player:Rage() > 80) then -- this one needs some work
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
    end
    --actions+=/purifying_blast,if=!buff.recklessness.up&!buff.siegebreaker.up
    if S.PurifyingBlast:IsCastableP() and (Player:BuffDownP(S.Recklessness) and Target:DebuffDownP(S.SiegebreakerDebuff)) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast"; end
    end
    --actions+=/ripple_in_space,if=!buff.recklessness.up&!buff.siegebreaker.up
    if S.RippleInSpace:IsCastableP() and (Player:BuffDownP(S.Recklessness) and Target:DebuffDownP(S.SiegebreakerDebuff)) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
    end
    --actions+=/worldvein_resonance,if=!buff.recklessness.up&!buff.siegebreaker.up
    if S.WorldveinResonance:IsCastableP() and (Player:BuffDownP(S.Recklessness) and Target:DebuffDownP(S.SiegebreakerDebuff)) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    --actions+=/focused_azerite_beam,if=!buff.recklessness.up&!buff.siegebreaker.up
    if S.FocusedAzeriteBeam:IsCastableP() and (Player:BuffDownP(S.Recklessness) and Target:DebuffDownP(S.SiegebreakerDebuff)) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
    end
    --actions+=/reaping_flames,if=!buff.recklessness.up&!buff.siegebreaker.up
    if (Player:BuffDownP(S.Recklessness) and Target:DebuffDownP(S.SiegebreakerDebuff)) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/concentrated_flame,if=!buff.recklessness.up&!buff.siegebreaker.up&dot.concentrated_flame_burn.remains=0
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffDownP(S.Recklessness) and Target:DebuffDownP(S.SiegebreakerDebuff) and Target:DebuffDownP(S.ConcentratedFlameBurn)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame"; end
    end
    --actions+=/the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force"; end
    end
    --actions+=/guardian_of_azeroth,if=!buff.recklessness.up&(target.time_to_die>195|target.health.pct<20)
    if S.GuardianofAzeroth:IsCastableP() and (Player:BuffDownP(S.RecklessnessBuff) and (Target:TimeToDie() > 195 or Target:HealthPercentage() < 20)) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    --actions+=/memory_of_lucid_dreams,if=!buff.recklessness.up
    if S.MemoryofLucidDreams:IsCastableP() and (Player:BuffDownP(S.RecklessnessBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    --actions+=/recklessness,if=gcd.remains=0&(!essence.condensed_lifeforce.major&!essence.blood_of_the_enemy.major|cooldown.guardian_of_azeroth.remains>1|buff.guardian_of_azeroth.up|buff.blood_of_the_enemy.up)
    if S.Recklessness:IsCastableP() and HR.CDsON() and (not Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and not Spell:MajorEssenceEnabled(AE.BloodoftheEnemy) or S.GuardianofAzeroth:CooldownRemainsP() > 1 or Player:BuffP(S.GuardianofAzerothBuff) or S.BloodoftheEnemy:CooldownRemainsP() < Player:GCD()) then
      if HR.Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness"; end
    end -- double check this one hard
    --actions+=/whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
    if S.Whirlwind:IsCastableP("Melee") and (Cache.EnemiesCount[8] > 1 and Player:BuffDownP(S.MeatCleaverBuff)) then
      if HR.Cast(S.Whirlwind) then return "whirlwind"; end
    end
    --actions+=/use_item,name=ashvanes_razor_coral,if=target.time_to_die<20|!debuff.razor_coral_debuff.up|(target.health.pct<30.1&debuff.conductive_ink_debuff.up)|(!debuff.conductive_ink_debuff.up&buff.memory_of_lucid_dreams.up|prev_gcd.2.guardian_of_azeroth|prev_gcd.2.recklessness&(!essence.memory_of_lucid_dreams.major&!essence.condensed_lifeforce.major))
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:TimeToDie() < 20 or Target:DebuffDownP(S.RazorCoralDebuff) or (Target:HealthPercentage() < 30 and Target:DebuffP(S.ConductiveInkDebuff)) or (Target:DebuffDownP(S.ConductiveInkDebuff) and Player:BuffP(S.MemoryofLucidDreams) or Player:PrevGCDP(2, S.GuardianofAzeroth) or Player:PrevGCDP(2, S.Recklessness) and (Player:BuffP(S.GuardianofAzerothBuff) or not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce)))) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral"; end
    end
    if (HR.CDsON()) then
      --actions+=/blood_fury,if=buff.recklessness.up
      if S.BloodFury:IsCastableP() and (Player:BuffP(S.RecklessnessBuff)) then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
      end
      --actions+=/berserking,if=buff.recklessness.up
      if S.Berserking:IsCastableP() and (Player:BuffP(S.RecklessnessBuff)) then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking"; end
      end
      --actions+=/lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
      if S.LightsJudgment:IsCastableP() and (Player:BuffDownP(S.RecklessnessBuff) and Target:DebuffDownP(S.SiegebreakerDebuff)) then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment"; end
      end
      --actions+=/fireblood,if=buff.recklessness.up
      if S.Fireblood:IsCastableP() and (Player:BuffP(S.RecklessnessBuff)) then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
      end
      --actions+=/ancestral_call,if=buff.recklessness.up
      if S.AncestralCall:IsCastableP() and (Player:BuffP(S.RecklessnessBuff)) then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
      end
      --actions+=/bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
      if S.BagofTricks:IsCastableP() and (Player:BuffDownP(S.RecklessnessBuff) and Target:DebuffDownP(S.SiegebreakerDebuff) and Player:BuffP(S.EnrageBuff)) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks"; end
      end
    end
    --actions+=/run_action_list,name=single_target
    if (true) then
      return SingleTarget();
    end
  end

end

local function Init()
  HL.RegisterNucleusAbility(46924, 8, 6)               -- Bladestorm
  HL.RegisterNucleusAbility(118000, 12, 6)             -- Dragon Roar
  HL.RegisterNucleusAbility(190411, 8, 6)              -- Whirlwind
end

HR.SetAPL(72, APL, Init)
--- SIMC APL----
--last updated 16/10/2020

--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/use_item,name=azsharas_font_of_power
--actions.precombat+=/worldvein_resonance
--actions.precombat+=/memory_of_lucid_dreams
--actions.precombat+=/guardian_of_azeroth
--actions.precombat+=/recklessness
--actions.precombat+=/potion

--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/charge
--# This is mostly to prevent cooldowns from being accidentally used during movement.
--actions+=/run_action_list,name=movement,if=movement.distance>5
--actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
--actions+=/rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
--actions+=/blood_of_the_enemy,if=(buff.recklessness.up|cooldown.recklessness.remains<1)&(rage>80&(buff.meat_cleaver.up&buff.enrage.up|spell_targets.whirlwind=1)|dot.noxious_venom.remains)
--actions+=/purifying_blast,if=!buff.recklessness.up&!buff.siegebreaker.up
--actions+=/ripple_in_space,if=!buff.recklessness.up&!buff.siegebreaker.up
--actions+=/worldvein_resonance,if=!buff.recklessness.up&!buff.siegebreaker.up
--actions+=/focused_azerite_beam,if=!buff.recklessness.up&!buff.siegebreaker.up
--actions+=/reaping_flames,if=!buff.recklessness.up&!buff.siegebreaker.up
--actions+=/concentrated_flame,if=!buff.recklessness.up&!buff.siegebreaker.up&dot.concentrated_flame_burn.remains=0
--actions+=/the_unbound_force,if=buff.reckless_force.up
--actions+=/guardian_of_azeroth,if=!buff.recklessness.up&(target.time_to_die>195|target.health.pct<20)
--actions+=/memory_of_lucid_dreams,if=!buff.recklessness.up
--actions+=/recklessness,if=gcd.remains=0&(!essence.condensed_lifeforce.major&!essence.blood_of_the_enemy.major|cooldown.guardian_of_azeroth.remains>1|buff.guardian_of_azeroth.up|buff.blood_of_the_enemy.up)
--actions+=/whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
--actions+=/use_item,name=ashvanes_razor_coral,if=target.time_to_die<20|!debuff.razor_coral_debuff.up|(target.health.pct<30.1&debuff.conductive_ink_debuff.up)|(!debuff.conductive_ink_debuff.up&buff.memory_of_lucid_dreams.up|prev_gcd.2.guardian_of_azeroth|prev_gcd.2.recklessness&(!essence.memory_of_lucid_dreams.major&!essence.condensed_lifeforce.major))
--actions+=/blood_fury,if=buff.recklessness.up
--actions+=/berserking,if=buff.recklessness.up
--actions+=/lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
--actions+=/fireblood,if=buff.recklessness.up
--actions+=/ancestral_call,if=buff.recklessness.up
--actions+=/bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
--actions+=/run_action_list,name=single_target

--actions.movement=heroic_leap

--actions.single_target=siegebreaker
--actions.single_target+=/rampage,if=(buff.recklessness.up|buff.memory_of_lucid_dreams.up)|(buff.enrage.remains<gcd|rage>90)
--actions.single_target+=/execute
--actions.single_target+=/bladestorm,if=prev_gcd.1.rampage
--actions.single_target+=/bloodthirst,if=buff.enrage.down|azerite.cold_steel_hot_blood.rank>1
--actions.single_target+=/onslaught
--actions.single_target+=/dragon_roar,if=buff.enrage.up
--actions.single_target+=/raging_blow,if=charges=2
--actions.single_target+=/bloodthirst
--actions.single_target+=/raging_blow
--actions.single_target+=/whirlwind

--(Player:BuffP(S.RecklessnessBuff) or S.Recklessness:CooldownRemainsP() < 1) and (Player:Rage() > 80 and (Player:BuffP(S.MeatCleaverBuff) and ()(Player:BuffP(S.EnrageBuff) or Cache.EnemiesCount[8] > 1))

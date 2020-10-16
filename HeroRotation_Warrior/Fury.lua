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
local AoEON      = HR.AoEON
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



local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function Precombat()
end

local function Essences()
end

local function Cooldown()
  --actions+=/blood_fury,if=buff.recklessness.up
  --actions+=/berserking,if=buff.recklessness.up
  --actions+=/lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
  --actions+=/fireblood,if=buff.recklessness.up
  --actions+=/ancestral_call,if=buff.recklessness.up
  if S.AncestralCall:IsCastable() and (Player:BuffUp(S.RecklessnessBuff)) then
  if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
end
  --actions+=/bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
end

local function SingleTarget()
  --actions.single_target=siegebreaker
  if S.Siegebreaker:IsCastable("Melee") and HR.CDsON() then
    if HR.Cast(S.Siegebreaker, Settings.Fury.GCDasOffGCD.Siegebreaker) then return "siegebreaker "; end
  end
  --actions.single_target+=/rampage,if=(buff.recklessness.up|buff.memory_of_lucid_dreams.up)|(buff.enrage.remains<gcd|rage>90)
  if S.Rampage:IsReady("Melee") and ((Player:BuffUp(S.RecklessnessBuff) or Player:BuffUp(S.MemoryofLucidDreams)) or (Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:Rage() > 90)) then
   if HR.Cast(S.Rampage) then return "rampage"; end
  end
  --actions.single_target+=/execute
  if S.Execute:IsCastable("Melee") and (S.SuddenDeath:IsAvailable() and Player:BuffUp(S.SuddenDeathBuff)) or Target:HealthPercentage() < 21 then
    if HR.Cast(S.Execute) then return "execute"; end
  end
  --actions.single_target+=/bladestorm,if=prev_gcd.1.rampage
  if S.Bladestorm:IsCastable("Melee") and HR.CDsON() and (Player:PrevGCD(1, S.Rampage)) then
    if HR.Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm) then return "bladestorm"; end
  end
  --actions.single_target+=/bloodthirst,if=buff.enrage.down|azerite.cold_steel_hot_blood.rank>1
  if S.Bloodthirst:IsCastable("Melee") and (Player:BuffDown(S.EnrageBuff) or S.ColdSteelHotBlood:AzeriteRank() > 1) then
    if HR.Cast(S.Bloodthirst) then return "bloodthirst"; end
  end
  --actions.single_target+=/onslaught
  if S.Onslaught:IsCastable("Melee") and (Player:BuffUp(S.EnrageBuff)) then
    if HR.Cast(S.Onslaught) then return "onslaught"; end
  end
  --actions.single_target+=/dragon_roar,if=buff.enrage.up
  if S.DragonRoar:IsCastable(12) and HR.CDsON() and (Player:BuffUp(S.EnrageBuff)) then
    if HR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar) then return "dragon_roar"; end
  end
  --actions.single_target+=/raging_blow,if=charges=2
  if S.CrushingBlow:IsCastable("Melee") and (S.CrushingBlow:Charges() == 2) and (Player:BuffUp(S.RecklessnessBuff)) then
    if HR.Cast(S.CrushingBlow) then return "crushing_blow"; end
  end
  if S.RagingBlow:IsCastable("Melee") and (S.RagingBlow:Charges() == 2) then
    if HR.Cast(S.RagingBlow) then return "raging_blow"; end
  end
  --actions.single_target+=/bloodthirst
  if S.Bloodbath:IsCastable("Melee") and (Player:BuffUp(S.RecklessnessBuff)) then
    if HR.Cast(S.Bloodbath) then return "bloodbath"; end
  end
  if S.Bloodthirst:IsCastable("Melee") then
    if HR.Cast(S.Bloodthirst) then return "bloodthirst"; end
  end
  --actions.single_target+=/raging_blow
  if S.CrushingBlow:IsCastable("Melee") and (Player:BuffUp(S.RecklessnessBuff)) then
    if HR.Cast(S.CrushingBlow) then return "crushing_blow"; end
  end
  if S.RagingBlow:IsCastable("Melee") then
    if HR.Cast(S.RagingBlow) then return "raging_blow"; end
  end
  --actions.single_target+=/whirlwind
  if S.Whirlwind:IsCastable("Melee") then
    if HR.Cast(S.Whirlwind) then return "whirlwind"; end
  end
end


--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    Enemies12y = Player:GetEnemiesInMeleeRange(12) -- Dragon Roar
    EnemiesCount8 = #Enemies8y
    EnemiesCount12 = #Enemies12y
  else
    EnemiesCount8 = 1
    EnemiesCount12 = 1
  end

  if Everyone.TargetIsValid() then
  --actions=auto_attack
  --actions+=/charge
  if S.Charge:IsReady() and (not Target:IsInMeleeRange(5)) and S.Charge:Charges() >= 1 then
    if HR.Cast(S.Charge, Settings.Fury.GCDasOffGCD.Charge) then return "charge"; end
  end
  --# This is mostly to prevent cooldowns from being accidentally used during movement.
  --actions+=/run_action_list,name=movement,if=movement.distance>5
  --actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
  --actions+=/rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
  --actions+=/blood_of_the_enemy,if=(buff.recklessness.up|cooldown.recklessness.remains<1)&(rage>80&(buff.meat_cleaver.up&buff.enrage.up|spell_targets.whirlwind=1)|dot.noxious_venom.remains)
  if S.BloodoftheEnemy:IsCastable() and (Player:BuffUp(S.RecklessnessBuff)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
  end
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
  if S.Recklessness:IsCastable() and HR.CDsON() and (S.BloodoftheEnemy:CooldownRemains() < Player:GCD()) then
    if HR.Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness"; end
  end
  --actions+=/whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
  if S.Whirlwind:IsCastable("Melee") and (EnemiesCount8 > 1 and Player:BuffDown(S.MeatCleaverBuff)) then
    if HR.Cast(S.Whirlwind) then return "whirlwind"; end
  end
    if (HR.CDsON()) then
      if (true) then
        local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
      end
    end
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end

  end
end

local function Init()

end

HR.SetAPL(72, APL, Init)

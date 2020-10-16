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
  --if S.Rampage:IsReady("Melee") and (Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:Rage() > 90) then
   --if HR.Cast(S.Rampage) then return "rampage"; end
  --end
  --actions.single_target+=/execute
  if S.Execute:IsCastable("Melee") and (S.SuddenDeath:IsAvailable() and Player:BuffUp(S.SuddenDeathBuff)) or Target:HealthPercentage() < 21 then
    if HR.Cast(S.Execute) then return "execute"; end
  end
  --actions.single_target+=/bladestorm,if=prev_gcd.1.rampage
  --if S.Bladestorm:IsCastable("Melee") and HR.CDsON() and (Player:PrevGCD(1, S.Rampage)) then
    --if HR.Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm) then return "bladestorm"; end
  --end
  --actions.single_target+=/bloodthirst,if=buff.enrage.down|azerite.cold_steel_hot_blood.rank>1
  if S.Bloodthirst:IsCastable("Melee") and (Player:BuffDown(S.EnrageBuff) or S.ColdSteelHotBlood:AzeriteRank() > 1) then
    if HR.Cast(S.Bloodthirst) then return "bloodthirst"; end
  end
  --actions.single_target+=/onslaught
  --actions.single_target+=/dragon_roar,if=buff.enrage.up
  if S.DragonRoar:IsCastable(12) and HR.CDsON() and (Player:BuffUp(S.EnrageBuff)) then
    if HR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar) then return "dragon_roar"; end
  end
  --actions.single_target+=/raging_blow,if=charges=2
  if S.RagingBlow:IsCastable("Melee") and (S.RagingBlow:Charges() == 2) then
    if HR.Cast(S.RagingBlow) then return "raging_blow"; end
  end
  --actions.single_target+=/bloodthirst
  if S.Bloodthirst:IsCastable("Melee") then
    if HR.Cast(S.Bloodthirst) then return "bloodthirst"; end
  end
  --actions.single_target+=/raging_blow
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
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end

  end
end

local function Init()

end

HR.SetAPL(72, APL, Init)

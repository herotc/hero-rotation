--- Localize Vars
-- Addon
local addonName, addonTable = ...;

-- HeroLib
local HL     = HeroLib;
local Cache  = HeroCache;
local Unit   = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell  = HL.Spell;
local Item   = HL.Item;

-- HeroRotation
local HR = HeroRotation;

-- APL Local Vars
local Everyone = HR.Commons.Everyone;
-- Spells
if not Spell.Warrior then Spell.Warrior = {}; end
Spell.Warrior.Protection = {
  -- Racials
  Berserking         = Spell(26297),
  BloodFury          = Spell(20572),
  ArcaneTorrent      = Spell(28730),

  -- Abilities
  Intercept          = Spell(198304),
  ThunderClap        = Spell(6343),
  ShieldSlam         = Spell(23922),
  Revenge            = Spell(6572),
  Devastate          = Spell(20243),
  Avatar             = Spell(107574),
  VictoryRush        = Spell(34428), --20% of max hp
  DemoralizingShout  = Spell(1160),

  -- Mitigation
  ShieldBlock        = Spell(2565),

  -- Buffs
  FreeRevenge        = Spell(5302),
  ShieldBlockBuff    = Spell(132404),
  VengenceIgnorePain = Spell(202574),
  VengenceRevenge    = Spell(132404),
  AvatarBuff         = Spell(107574),
  LastStandBuff      = Spell(12975),

  -- Talents
  UnstoppableForce   = Spell(275336),
  
  -- Defensive
  IgnorePain         = Spell(190456),
  LastStand          = Spell(12975),
  
  -- Utility
  Pummel             = Spell(6552),

  -- Legendaries

  -- Misc
  PoolFocus          = Spell(9999000010)
}
local S = Spell.Warrior.Protection;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Protection = {
  -- Legendaries
  -- Misc
  PoPP                = Item(142117),
};
local I = Item.Warrior.Protection;

-- GUI Settings
local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Warrior.Commons,
    Protection = HR.GUISettings.APL.Warrior.Protection
}

local function isCurrentlyTanking()
  -- is player currently tanking any enemies within 16 yard radius
  local IsTanking = Player:IsTankingAoE(16) or Player:IsTanking(Target);
  return IsTanking;
end

-- Determine if it is optimal to cast ip. We dont want to waste rage and over cap it
local function shouldCastIp()

  if Player:Buff(S.IgnorePain) then 
    local castIP = tonumber((GetSpellDescription(190456):match("%d+%S+%d"):gsub("%D","")))
    local IPCap = math.floor(castIP * 1.3);
    local currentIp = Player:Buff(S.IgnorePain, 16, true)

    if currentIp  < (0.8 * IPCap) then
      return true
    else
      return false
    end
  else
    return true
  end
end


local function rageDump(rage)
  -- Using Vengence Talent
    --check which buff
    -- cast appropriate
    -- TODO
  -- if not using vengence talent
    -- cast either IP or Revenege depending on if tanking
    -- Ignore Pain (Dump excess rage)
  if S.IgnorePain:IsReady() and (Player:Rage() >= rage) and  isCurrentlyTanking() and shouldCastIp() then
    if HR.Cast(S.IgnorePain) then return "Cast IgnorePain" end
  end
  
  -- Revenge (Dump excess rage)
  if S.Revenge:IsReady() and (Player:Rage() >= rage) and (not isCurrentlyTanking()) then
    if HR.Cast(S.Revenge) then return "Cast Revenge" end
  end

  return nil;

end

-- APL Main
local function APL ()
  -- Unit Update
  HL.GetEnemies(8);
  Everyone.AoEToggleEnemiesUpdate();

  local gcdTime = Player:GCD();
  
  -- Out of Combat
  if not Player:AffectingCombat() then

    -- Opener Charge + 15 Rage
    if Everyone.TargetIsValid() then
      -- Intercept
      if S.Intercept:IsReady() and (not Target:IsInRange(8) and Target:IsInRange(25)) then
        if HR.Cast(S.Intercept) then return "Cast Intercept" end
      end
    end
    return
  end

  -- Interrupts
  if Settings.General.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange("Melee") then
    if S.Pummel:IsReady() then
      if HR.Cast(S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel) then return "Cast Pummel"; end
    end
  end

  -- In Combat
  if Everyone.TargetIsValid() and S.Intercept:IsReady() and (not Target:IsInRange(8) and Target:IsInRange(25)) then
    if HR.Cast(S.Intercept) then return "Cast Intercept" end
  end

  if Everyone.TargetIsValid() and Target:IsInRange("Melee") then

    -- Generates +20 Rage
    if HR.CDsON() and S.Avatar:IsReady() and (Player:Rage() <= (Player:RageMax() - 20)) then
      if HR.Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "Cast Avatar" end
    end

    -- Generates +40 Rage
    if HR.CDsON() and S.DemoralizingShout:IsReady() and (Player:Rage() <= (Player:RageMax() - 40)) then
      if HR.Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout) then return "Cast DemoralizingShout" end
    end

    -- Check for target casting mitigation check or DBM timer
    -- for mitigation check or high damage intake

    -- Mitigation + Defensive - 30 Rage
    if S.ShieldBlock:IsReady() and (not (Player:Buff(S.ShieldBlockBuff)) or Player:BuffRemains(S.ShieldBlockBuff) <= gcdTime + (gcdTime * 0.5)) and 
        (not (Player:Buff(S.LastStandBuff))) and (Player:Rage() >= 30) and isCurrentlyTanking() then
      if HR.Cast(S.ShieldBlock, Settings.Protection.OffGCDasOffGCD.ShieldBlock) then return "Shield Block" end
    end

    if S.LastStand:IsReady() and (not (Player:Buff(S.ShieldBlockBuff))) and isCurrentlyTanking() and Settings.Protection.UseLastStandToFillShieldBlockDownTime then
      if HR.Cast(S.LastStand, Settings.Protection.GCDasOffGCD.LastStand) then return "Cast LastStand" end
    end

    -- Victory Rush Check - High Priority
    if S.VictoryRush:IsReady() and Player:HealthPercentage() < 30 then
      if HR.Cast(S.VictoryRush) then return "Cast VictoryRush" end
    end

    -- Prevent rage cap 100
    local res = rageDump(Player:RageMax());
    if res then
      return res;
    end
      
    -- AOE 2+ Targets (Higher Priority when AOE) or Avatar Up and Unstoppable Force is Talented
    if Cache.EnemiesCount[8] >= 2 or (Player:Buff(S.AvatarBuff) and S.UnstoppableForce:IsAvailable()) then
      -- Thunder Clap + 6 Rage
      if S.ThunderClap:IsReady() then
        if HR.Cast(S.ThunderClap) then return "Cast ThunderClap" end
      end
      
    end
    
    -- Shield Slam + 18 Rage
    if S.ShieldSlam:IsReady() then
      if HR.Cast(S.ShieldSlam) then return "Cast ShieldSlam" end
    end

    -- Thunder Clap + 6 Rage
    if S.ThunderClap:IsReady() then
      if HR.Cast(S.ThunderClap) then return "Cast ThunderClap" end
    end

    -- Ignore Pain with vengence proc
    if S.IgnorePain:IsReady() and (Player:Buff(S.VengenceIgnorePain)) and (Player:Rage() >= 42) and isCurrentlyTanking() then
      if HR.Cast(S.IgnorePain) then return "Cast IgnorePain" end
    end

    -- Revenge with Buff (Free Revenege)
    if S.Revenge:IsReady() and (Player:Buff(S.FreeRevenge)) then
      if HR.Cast(S.Revenge) then return "Cast Revenge" end
    end

    -- Ignore Pain (Spend the rage for defensive)
    if S.IgnorePain:IsReady() and (Player:Rage() >= 55) and isCurrentlyTanking() and shouldCastIp() then
      if HR.Cast(S.IgnorePain) then return "Cast IgnorePain" end
    end

    -- Revenge with High Rage - 30 Rage
    if S.Revenge:IsReady() and (Player:Rage() >= 60) then
      if HR.Cast(S.Revenge) then return "Cast Revenge" end
    end

    -- Victory Rush Check - Low Priority
    if S.VictoryRush:IsReady() and Player:HealthPercentage() < 50 then
      if HR.Cast(S.VictoryRush) then return "Cast VictoryRush" end
    end

    -- Devastate
    if S.Devastate:IsReady() then
      if HR.Cast(S.Devastate) then return "Cast Devastate" end
    end

  end

end

HR.SetAPL(73, APL);

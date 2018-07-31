--- Localize Vars
-- /dump GetSpellLink'Ignore Pain'
-- Addon
local addonName, addonTable = ...;

-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;

-- HeroRotation
local HR = HeroRotation;

-- ip formula (strength + weapDPS * 6) * (1 + apMastery) * (1 + vers) * 3.5
-- (365+0x6)x(1+.08)x(1+0)x3.5


-- APL Local Vars
local Everyone = HR.Commons.Everyone;
-- Spells
if not Spell.Warrior then Spell.Warrior = {}; end
Spell.Warrior.Protection = {
  -- Racials
  Berserking                     = Spell(26297),
  BloodFury                      = Spell(20572),
  ArcaneTorrent                  = Spell(28730),

  -- Abilities
  Intercept   = Spell(198304),
  ThunderClap = Spell(6343),
  ShieldSlam  = Spell(23922),
  Revenge     = Spell(6572),
  Devastate   = Spell(20243),
  Avatar      = Spell(107574),
  VictoryRush = Spell(34428), --20% of max hp
  DemoralizingShout = Spell(1160),

  -- Mitigation
  ShieldBlock = Spell(2565),

  -- Buffs
  FreeRevenge = Spell(5302),
  ShieldBlockBuff = Spell(132404),
  VengenceIgnorePain = Spell(202574),
  VengenceRevenge = Spell(132404),
  AvatarBuff = Spell(12345),
  LastStandBuff = Spell(12975),


  -- Talents
  

  -- Artifact
  

  -- Defensive
  IgnorePain = Spell(190456),
  LastStand = Spell(12975),
  
  -- Utility
  Pummel = Spell(6552),

  -- Legendaries

  -- Misc
  PoolFocus                      = Spell(9999000010)
}
local S = Spell.Warrior.Protection;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Protection = {
  -- Legendaries

  -- Misc
  PoPP                      = Item(142117),
};
local I = Item.Warrior.Protection;

-- GUI Settings
local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Warrior.Commons,
    Protection = HR.GUISettings.APL.Warrior.Protection
}

-- APL Variables
--local function battle_cry_deadly_calm()
--  if Player:Buff(S.BattleCryBuff) and S.DeadlyCalm:IsAvailable() then return true
--  else return false end
--end

local function isCurrentlyTanking()
  -- is player currently tanking any enemies within 16 yard radius
  local IsTanking = Player:IsTankingAoE(16) or Player:IsTanking(Target);
  return IsTanking;
end

-- Determine if it is optimal to cast ip. We dont want to waste rage and over cap it
local function shouldCastIp()

  if Player:Buff(S.IgnorePain) then 
    local castIP = tonumber((GetSpellDescription(190456):match("up to (.-) total damage prevented."):gsub(",","")));
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
  if Everyone.TargetIsValid() and Target:IsInRange("Melee") then

    -- Generates +20 Rage
    if S.Avatar:IsReady() then
      if HR.Cast(S.Avatar) then return "Cast Avatar" end
    end

    -- Generates +40 Rage
    if S.DemoralizingShout:IsReady() then
      if HR.Cast(S.DemoralizingShout) then return "Cast DemoralizingShout" end
    end

    -- Check for target casting mitigation check or DBM timer
    -- for mitigation check or high damage intake

    -- Mitigation + Defensive
    if S.ShieldBlock:IsReady() and (not (Player:Buff(S.ShieldBlockBuff))) and (not (Player:Buff(S.LastStandBuff))) and (Player:Rage() >= 30) and isCurrentlyTanking() then
      if HR.Cast(S.ShieldBlock) then return "Cast ShieldBlock" end
    end

    if S.LastStand:IsReady() and (not (Player:Buff(S.ShieldBlockBuff))) and isCurrentlyTanking() then
      if HR.Cast(S.LastStand) then return "Cast LastStand" end
    end

    -- Victory Rush Check - High Priority
    if S.VictoryRush:IsReady() and Player:HealthPercentage() < 30 then
      if HR.Cast(S.VictoryRush) then return "Cast VictoryRush" end
    end

    -- Potion of Prolonged Power
    --if Settings.Protection.ShowPoPP and Target:MaxHealth() >= 250000000 and (I.PoPP:IsReady() and (Player:HasHeroism() or Target:TimeToDie() <= 90 or Target:HealthPercentage() < 35 or Player:Buff(S.BattleCryBuff))) then
    --  if HR.CastSuggested(I.PoPP) then return "Use PoPP" end
    --end

    -- Prevent rage cap 100
    local res = rageDump(100);
    if res then
      return res;
    end
      
    -- AOE 2+ Targets
    if Cache.EnemiesCount[8] >= 2 then
      -- Thunder Clap
      if S.ThunderClap:IsReady() then
        if HR.Cast(S.ThunderClap) then return "Cast ThunderClap" end
      end
      
    end

    -- Standard Rotatation
    -- spenders
    -- Shield Block 40 Rage
    -- Ignore Pain 40 Rage 
    -- Revenge 30 Rage

    -- Builders
    -- intercept 15
    -- Shield Slam 15
    -- ThunderClap 5 rage
    -- Avatar 20
    -- devastate 2 rage
    -- Demoralizing Shout 40 Rage

    -- optimizers
    -- vengence 33% reduced cost for revenge or ignore pain
    
    -- Shield Slam
    if S.ShieldSlam:IsReady() then
      if HR.Cast(S.ShieldSlam) then return "Cast ShieldSlam" end
    end

    -- Thunder Clap
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

    -- Victory Rush Check - Low Priority
    if S.VictoryRush:IsReady() and Player:HealthPercentage() < 80 then
      if HR.Cast(S.VictoryRush) then return "Cast VictoryRush" end
    end

    -- Devastate (Fish for SS resets)
    if S.Devastate:IsReady() then
      if HR.Cast(S.Devastate) then return "Cast Devastate" end
    end

  end
end

HR.SetAPL(73, APL);

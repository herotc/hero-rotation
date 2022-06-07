--- ======== BUILT AS A SIMPLIFICATION / EXPERIMENT MATCHING Yodakh's Surv Guide =======
-- https://docs.google.com/document/d/1U9Ca4mh-W-OD7o3K1er4OWKb2EUESPosZEPXK01Hc-c/edit
-- Presupposes the obvious M+ build with wildfire legendary.
-- Assumes 4p

--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  Survival = HR.GUISettings.APL.Hunter.Survival
}

-- Spells
local S = Spell.Hunter.Survival

-- Items
local I = Item.Hunter.Survival
local TrinketsOnUseExcludes = {
  -- I.Trinket:ID(),
}

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = Item(0)
local trinket2 = Item(0)
if equip[13] then
  trinket1 = Item(equip[13])
end
if equip[14] then
  trinket2 = Item(equip[14])
end

-- Check when equipment changes
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = Item(0)
  trinket2 = Item(0)
  if equip[13] then
    trinket1 = Item(equip[13])
  end
  if equip[14] then
    trinket2 = Item(equip[14])
  end
end, "PLAYER_EQUIPMENT_CHANGED")

-- Rotation Var
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }
local EnemyCount8ySplash, EnemyList
local RedBombDuration = 0
local BossFightRemains = 11111
local FightRemains = 11111

---S.FrozenOrb:RegisterInFlightEffect(84721)
---S.FrozenOrb:RegisterInFlight()
---HL:RegisterForEvent(function() S.FrozenOrb:RegisterInFlight() end, "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
}

-- Function to see if we're going to cap focus
local function CheckFocusCap(SpellCastTime, GenFocus)
  local GeneratedFocus = GenFocus or 0
  return (Player:Focus() + Player:FocusCastRegen(SpellCastTime) + GeneratedFocus < Player:FocusMax())
end

local function RedBombWindowDuration()
  local best_duration = 0
  for _, Enemy in pairs(EnemyList) do
    if (Enemy:AffectingCombat() or Enemy:IsDummy()) then
      local pheromone_duration = Enemy:DebuffRemains(S.PheromoneBombDebuff)
      best_duration = math.max(best_duration, pheromone_duration)
    end
  end
  return best_duration
end

local function BombInFlight()
  --return S.WildfireBomb:IsInFlight() or S.ShrapnelBomb:IsInFlight() or S.PheromoneBomb:IsInFlight() or S.VolatileBomb:IsInFlight()
  return S.WildfireBomb:TimeSinceLastCast() < Player:GCD() or 
         S.ShrapnelBomb:TimeSinceLastCast() < Player:GCD() or 
         S.PheromoneBomb:TimeSinceLastCast() < Player:GCD() or 
         S.VolatileBomb:TimeSinceLastCast() < Player:GCD()
end

local function LastGlobalWasBomb()
  --return S.WildfireBomb:IsInFlight() or S.ShrapnelBomb:IsInFlight() or S.PheromoneBomb:IsInFlight() or S.VolatileBomb:IsInFlight()
  return S.WildfireBomb:TimeSinceLastCast() <= Player:GCD() or 
         S.ShrapnelBomb:TimeSinceLastCast() <= Player:GCD() or 
         S.PheromoneBomb:TimeSinceLastCast() <= Player:GCD() or 
         S.VolatileBomb:TimeSinceLastCast() <= Player:GCD()
end


-- handles travel time on the mad bombardier proc not being consumed to stablize the predictions for bombing/carving
local function MadBombardierBuffUpP()
  if not Player:BuffUp(S.MadBombardierBuff) then return false; end
  if Player:BuffUp(S.MadBombardierBuff) and BombInFlight() then return false; end
  if Player:BuffUp(S.MadBombardierBuff) and not BombInFlight() then return true; end
end

-- we know that when we throw a bomb with mad bombardier buff up, we don't actually lose a charge, so build that prediction into our model
local function WildfireBombFullRechargeTimeP()
  if not Player:BuffUp(S.MadBombardierBuff) then return S.WildfireBomb:FullRechargeTime(); end
  if Player:BuffUp(S.MadBombardierBuff) and not BombInFlight() then return S.WildfireBomb:FullRechargeTime(); end
  if Player:BuffUp(S.MadBombardierBuff) and BombInFlight() then return S.WildfireBomb:FullRechargeTime() - S.WildfireBomb:Recharge(); end
end

-- General logic is to always kill command the highest HP target that isn't already bleeding,
-- and to serpent sting the highest hp target that isn't stung. if all of the targets are low TTD, then don't sting at all (instead consider raptor strike on highest hp)
-- TODO: if you're in redbomb window, try to only KC mobs that have been pheromone bomb'd; 
-- if none are pheremone'd (your bomb was on a target far away or one that just died) then just do a fallback kc on main target
local function CastKillCommand()
  local TargetGUID = Target:GUID()
  local BestKillCommandUnit = nil
  local min_bs_duration = 999
  local max_hp = Target:Health()
  for _, Enemy in pairs(EnemyList) do
    -- if we're in not in red bomb, any target is fine
    -- if we're in redbomb, we want to hit pheromone bomb debuffed targets only
    if not Enemy:IsFacingBlacklisted() and not Enemy:IsUserCycleBlacklisted() and (RedBombDuration < Player:GCD() or Enemy:DebuffUp(S.PheromoneBombDebuff)) then
      local bs_duration = Enemy:DebuffRemains(S.BloodseekerDebuff)
      if bs_duration < min_bs_duration then
        min_bs_duration = bs_duration
        BestKillCommandUnit = Enemy
      end
      if bs_duration == 0 and Enemy:Health() > max_hp then
        max_hp = Enemy:Health()
        BestKillCommandUnit = Enemy
      end
    end
  end
  if BestKillCommandUnit == nil then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "fall through kill command main target"; end 
  end
  if HR.Nameplate.AddIcon(BestKillCommandUnit, S.KillCommand) then
    local Texture = HR.GetTexture(S.KillCommand)
    local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(Texture);
    HR.MainIconFrame:ChangeIcon(Texture, Keybind);
    if Cast(S.KillCommand, nil, nil, not BestKillCommandUnit:IsSpellInRange(S.KillCommand)) then return "kc optimal target"; end 
  end
end

local function TryCastSerpentSting(ttd_threshold, duration_threshold)
  local BestSerpentStingUnit = nil
  local min_ss_duration = 999
  local max_hp = 0
  for _, Enemy in pairs(EnemyList) do
    local ss_duration = Enemy:DebuffRemains(S.SerpentStingDebuff)
    local ttd = Enemy:TimeToDie()
    if not Enemy:IsFacingBlacklisted() and not Enemy:IsUserCycleBlacklisted() and ttd > ttd_threshold and ss_duration <= duration_threshold then
      -- find shortest serpent sting currently active
      if ss_duration < min_ss_duration then
        min_ss_duration = ss_duration
        BestSerpentStingUnit = Enemy
      end
      -- break ties by selecting highest hp mob
      if ss_duration == 0 and Enemy:Health() > max_hp then
        max_hp = Enemy:Health()
        BestSerpentStingUnit = Enemy
      end
    end
  end
  -- In the case that there is no good unit to sting, 
  -- it might be the case that all of the potential sting targets have a TTD that's too low, so we'd rather just do something else.
  if BestSerpentStingUnit == nil then
    return nil
  end
  if HR.Nameplate.AddIcon(BestSerpentStingUnit, S.SerpentSting) then
    local Texture = HR.GetTexture(S.SerpentSting)
    local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(Texture);
    HR.MainIconFrame:ChangeIcon(Texture, Keybind);
    if Cast(S.SerpentSting, nil, nil, not BestSerpentStingUnit:IsSpellInRange(S.SerpentSting)) then return "serpent sting"; end 
  end
  HR.Print("Error state. No valid serpent sting targets.")
  -- Go do something else.
  return nil
end

local function TryCastKillShot()
  local TargetGUID = Target:GUID()
  local ValidKillShotUnit = nil
  for _, Enemy in pairs(EnemyList) do
    if not Enemy:IsFacingBlacklisted() and not Enemy:IsUserCycleBlacklisted() and Enemy:HealthPercentage() < 20 then
      ValidKillShotUnit = Enemy
      break
    end
  end
  -- In the case that there is no eligible target to killshot
  if ValidKillShotUnit == nil then
    return nil
  end
  if HR.Nameplate.AddIcon(ValidKillShotUnit, S.KillShot) then
    local Texture = HR.GetTexture(S.KillShot)
    local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(Texture);
    HR.MainIconFrame:ChangeIcon(Texture, Keybind);
    if Cast(S.KillShot, nil, nil, not ValidKillShotUnit:IsSpellInRange(S.KillShot)) then return "kill shot"; end 
  end
  -- Go do something else.
  return nil
end

-- Generic function to toss a bomb.
local function CastBomb()
  if S.ShrapnelBomb:IsCastable() then
    if Cast(S.ShrapnelBomb, nil, nil, not Target:IsSpellInRange(S.ShrapnelBomb)) then return "shrapnel_bomb"; end
  end
  if S.PheromoneBomb:IsCastable() then
    if Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "pheromone_bomb"; end
  end
  if S.VolatileBomb:IsCastable() then
    if Cast(S.VolatileBomb, nil, nil, not Target:IsSpellInRange(S.VolatileBomb)) then return "volatile_bomb"; end
  end
  if S.WildfireBomb:IsCastable() then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb"; end
  end
end


local function Precombat()
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat"; end
  end

  if not Target:DebuffUp(S.HuntersMarkDebuff) and Target:IsInBossList() then
    if Cast(S.HuntersMark, nil, nil, not Target:IsSpellInRange(S.HuntersMark)) then return "hunters mark boss precombat"; end
  end
end

local function Trinkets()
  if trinket1:IsReady() then
      if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1"; end
  end
  if trinket2:IsReady() then
      if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2"; end
  end
end

local function CDs()
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions and (FightRemains < 25 or Player:BuffUp(S.CoordinatedAssault)) then
    if Cast(I.PotionOfSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 18"; end
  end
  if S.Fleshcraft:IsCastable() and ((Player:Focus() < 70 or S.CoordinatedAssault:CooldownRemains() < Player:GCD()) and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled())) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft cds 19"; end
  end
  if S.AspectoftheEagle:IsCastable() and not Target:IsInRange(6) then
    if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle cds 30"; end
  end
  if S.WildSpirits:IsCastable() and RedBombDuration == 0 then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "wild_spirits cleave 4"; end
  end
  if S.ResonatingArrow:IsCastable() and RedBombDuration == 0 then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "resonating_arrow cleave 6"; end
  end
  if S.CoordinatedAssault:IsCastable() then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault st 12"; end
  end
end

-- 1 or 2 targets
local function ST()
  
  -- serpent_sting,target_if=min:remains,if=!dot.serpent_sting.ticking&target.time_to_die>7&(!dot.pheromone_bomb.ticking|buff.mad_bombardier.up&next_wi_bomb.pheromone)|buff.vipers_venom.up&buff.vipers_venom.remains<gcd|!set_bonus.tier28_2pc&!dot.serpent_sting.ticking&target.time_to_die>7
  --if Target:DebuffDown(S.SerpentStingDebuff) and Target:TimeToDie() > 7 and (RedBombDuration == 0 or (Player:BuffUp(S.MadBombardierBuff) and S.PheromoneBomb:IsCastable())) then
  -- one of the targets doesnt have SSting on
  if RedBombDuration == 0 or (MadBombardierBuffUpP() and S.PheromoneBomb:IsCastable()) then
    local value = TryCastSerpentSting(7, 0)
    if value ~= nil then return value; end
  end
  --if (S.WildfireBomb:FullRechargeTime() < 2*Player:GCD()) or MadBombardierBuffUpP() then
  if (WildfireBombFullRechargeTimeP() < 2*Player:GCD()) then
    return CastBomb()
  end
  if MadBombardierBuffUpP() and S.WildfireBomb:ChargesFractional() > 1.0 and not LastGlobalWasBomb() then
    return CastBomb()
  end
  --if S.KillCommand:IsReady() and not MadBombardierBuffUpP() and RedBombDuration > 0 then
  if S.KillCommand:IsReady() and not MadBombardierBuffUpP() and RedBombDuration > 0 then
    return CastKillCommand()
  end
  if S.KillShot:IsReady() then
    local value = TryCastKillShot()
    if value ~= nil then return value; end
  end
  if S.Carve:IsReady() and EnemyCount8ySplash > 1 then
    if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve st 30"; end
  end
  --if S.KillCommand:IsReady() and S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 15) then
  if S.KillCommand:IsReady() and S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 15) then
    return CastKillCommand()
  end
  if S.RaptorStrike:IsReady() and (Player:BuffStack(S.TipoftheSpearBuff) == 3 or Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if Cast(S.RaptorStrike, nil, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "ST RaptorStrike"; end
  end
  if S.SerpentSting:IsReady() then
    local value = TryCastSerpentSting(7, 3.6)
    if value ~= nil then return value; end
  end
  if S.KillCommand:IsCastable() and CheckFocusCap(S.KillCommand:ExecuteTime(), 15) then
    return CastKillCommand()
  end
  if S.RaptorStrike:IsReady() then
    if Cast(S.RaptorStrike, nil, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "ST RaptorStrike 2"; end
  end
end
-- TODO: port ST predictive code to aoe
-- 3 or more targets
local function AOE()
  -- 1. URH debuff
  if Player:DebuffRemains(S.DecryptedUrhCypherDebuff) > 0 then
    if S.WildfireBomb:FullRechargeTime() < Player:GCD() or 
       MadBombardierBuffUpP() or 
       S.WildfireBomb:Recharge() < math.min(EnemyCount8ySplash, 5) + S.Carve:CooldownRemains() then
      return CastBomb() 
    end
    if S.Carve:IsReady() then
      if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve in urh"; end
    end
    if S.KillCommand:IsReady() then
      return CastKillCommand()
    end
  end

  -- 2. Red Bomb Active:
  if RedBombDuration > 0 then
    -- Bomb at two charges or with proc
    if S.WildfireBomb:FullRechargeTime() < Player:GCD() or MadBombardierBuffUpP() then
      return CastBomb() 
    end
    -- Carve with high haste in red buff
    if (Player:HastePct() > 70.0 and S.Carve:IsReady() and S.WildfireBomb:FullRechargeTime() > math.min(EnemyCount8ySplash, 5)) or not S.KillCommand:IsReady() then
      if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve in red bomb"; end
    end
    if S.WildfireBomb:ChargesFractional() < 1.0 and S.Carve:IsReady() then
      if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve to fix mistake"; end
    end
    -- Spam kill command where possible
    if S.KillCommand:IsReady() then
      return CastKillCommand()
    end
    if S.Carve:IsReady() then
      if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve in red bomb"; end
    end
  end

  -- 3. No red bomb:
  if RedBombDuration == 0 then
    -- Bomb at two charges or if carve will overcap
    if (S.WildfireBomb:FullRechargeTime() < Player:GCD()) or (S.WildfireBomb:FullRechargeTime() < math.min(EnemyCount8ySplash, 5) + Player:GCD() and S.Carve:CooldownRemains() < Player:GCD()) then
      return CastBomb()
    end
    -- Carve if it will not overcap
    if S.Carve:IsReady() and S.WildfireBomb:FullRechargeTime() > math.min(EnemyCount8ySplash, 5) then
      if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve outside of red bomb"; end
    end
    -- Spend bomb procs
    if MadBombardierBuffUpP() then
      return CastBomb()
    end
    -- Kill command if two charges
    if S.KillCommand:FullRechargeTime() < Player:GCD() then
      return CastKillCommand()
    end

    -- Kill command if coordinated assault active and you can guarantee having a KC charge when the red bomb window starts
    -- notably, because we've already checked against the 2 charge case, we know that we only have one KC charge here, so if we KC down to zero charges, 
    -- we need the charge to come back before red bomb comes up. the charge will come up from zero to one in an amount of time T equal to S.KillCommand:FullRechargeTime() here.
    -- that value T needs to be less than the amount of time before we know we're going to redbomb to ensure a kc charge
    -- to get a red bomb in this position; you're either waiting until it hits the charge cap, or you're waiting for carve to come off CD, pressing it, then waiting for either the GCD to finish or for the rest of the bomb CD to finish
    local time_until_redbomb = math.min(S.WildfireBomb:FullRechargeTime(), S.Carve:CooldownRemains() + math.max(Player:GCD(), S.WildfireBomb:FullRechargeTime() - math.min(EnemyCount8ySplash, 5)))

    if Player:BuffUp(S.CoordinatedAssaultBuff) and S.PheromoneBomb:IsCastable() and S.KillCommand:Recharge() < time_until_redbomb then
      return CastKillCommand()
    end

    -- wildfire bomb if you will have one charge after next kill command
    if S.WildfireBomb:FullRechargeTime() < S.KillCommand:FullRechargeTime() then
      return CastBomb()
    end

    -- On low target cleave, you can pre-spread serpent stings if the next bomb is volatile.
    if EnemyCount8ySplash <= 4 and S.SerpentSting:IsReady() and S.VolatileBomb:IsCastable() then
      local value = TryCastSerpentSting(7, 3.6)
      if value ~= nil then return value; end
    end

    -- Dump kill command charges if you can guarantee at least having a kc when the red bomb window starts
    if S.KillCommand:IsReady() and S.PheromoneBomb:IsCastable() and S.KillCommand:Recharge() < time_until_redbomb then
      return CastKillCommand()
    end
  end

  -- THE FILLER SHIT ...
  if S.KillShot:IsReady() then
    local value = TryCastKillShot()
    if value ~= nil then return value; end
  end
  if S.SerpentSting:IsReady() then
    local value = TryCastSerpentSting(8, 3.6)
    if value ~= nil then return value; end
  end
  if S.RaptorStrike:IsReady() then
    if Cast(S.RaptorStrike, nil, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor strike focus dump on aoe"; end
  end
  -- This is the "out of range" case on raptor strike.
  if S.KillCommand:IsReady() then
    return CastKillCommand()
  end
end

local function APL()
  -- Target Count Checking
  local EagleUp = Player:BuffUp(S.AspectoftheEagle)
  if EagleUp and not Target:IsInMeleeRange(8) then
    EnemyCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemyCount8ySplash = #Player:GetEnemiesInRange(8)
  end

  if EagleUp then
    EnemyList = Player:GetEnemiesInRange(40)
  else
    EnemyList = Player:GetEnemiesInRange(8)
  end

  RedBombDuration = RedBombWindowDuration()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemyList, false)
    end
  end

  -- Pet Management; Conditions handled via override
  if S.SummonPet:IsCastable() then
    if Cast(SummonPetSpells[Settings.Commons2.SummonPetSlot]) then return "Summon Pet"; end
  end
  if S.RevivePet:IsCastable() then
    if Cast(S.RevivePet, Settings.Commons2.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
  end
  if S.MendPet:IsCastable() then
    if Cast(S.MendPet, Settings.Commons2.GCDasOffGCD.MendPet) then return "Mend Pet"; end
  end

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Exhilaration
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons2.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.Commons2.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
    end
    -- muzzle
    local ShouldReturn = Everyone.Interrupt(5, S.Muzzle, Settings.Survival.OffGCDasOffGCD.Muzzle, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- Manually added: If out of range, use Aspect of the Eagle, otherwise Harpoon to get back into range
    if not EagleUp and not Target:IsInMeleeRange(8) then
      if S.AspectoftheEagle:IsCastable() then
        if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle oor"; end
      end
      --if S.Harpoon:IsCastable() then
      --  if Cast(S.Harpoon, Settings.Survival.OffGCDasOffGCD.Harpoon) then return "harpoon"; end
      --end
    end
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end

    -- call_action_list,name=trinkets,if=covenant.kyrian&cooldown.coordinated_assault.remains&cooldown.resonating_arrow.remains|!covenant.kyrian&cooldown.coordinated_assault.remains
    if (CovenantID == 1 and S.CoordinatedAssault:CooldownRemains() > 0 and S.ResonatingArrow:CooldownRemains() > 0 or CovenantID ~= 1 and S.CoordinatedAssault:CooldownRemains() > 0) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    if (EnemyCount8ySplash < 3) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    if (EnemyCount8ySplash >= 3) then
      local ShouldReturn = AOE(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent if you have no focus for anything else
    if S.ArcaneTorrent:IsCastable() then
      if Cast(S.ArcaneTorrent, true, nil, not Target:IsInRange(8)) then return "arcane_torrent main 888"; end
    end
    -- PoolFocus if nothing else to do
    if Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

local function OnInit ()
  HR.Print("This is a modified custom APL based on Yoda's Survival Guide.")
end

HR.SetAPL(255, APL, OnInit)

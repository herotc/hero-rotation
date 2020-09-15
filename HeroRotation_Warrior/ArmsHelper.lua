local addonName, addonTable = ...
-- HeroLib
HL      = HeroLib;
Cache   = HeroCache;
Unit    = HL.Unit;
Player  = Unit.Player;
Pet     = Unit.Pet;
Target  = Unit.Target;
Spell   = HL.Spell;
MultiSpell = HL.MultiSpell
Item    = HL.Item;

-- HeroRotation
HR      = HeroRotation;
AE         = HL.Enum.AzeriteEssences
AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs


-- Spells
if not Spell.Warrior then Spell.Warrior = {} end
Spell.Warrior.Arms = {
  -- Racials
  AncestralCall         = Spell(274738),
  ArcanePulse           = Spell(260364),
  ArcaneTorrent         = Spell(25046),
  BagofTricks           = Spell(312411),
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),
  Fireblood             = Spell(265221),
  LightsJudgment        = Spell(255647),

  -- Core Abilities
  ColossusSmash                         = Spell(167105),
  ColossusSmashDebuff                   = Spell(208086),
  Bladestorm                            = Spell(227847),
  Slam                                  = Spell(1464),
  MortalStrike                          = Spell(12294),
  DeepWoundsDebuff                      = Spell(262115),
  Overpower                             = Spell(7384),
  OverpowerBuff                         = Spell(7384),
  Execute                               = MultiSpell(163201, 281000),
  Whirlwind                             = Spell(1680),
  SweepingStrikes                       = Spell(260708),
  SweepingStrikesBuff                   = Spell(260708),
  -- Talents
  WarMachine                            = Spell(262231),
  SuddenDeath                           = Spell(29725),
  SuddenDeathBuff                       = Spell(52437),
  Skullsplitter                         = Spell(260643),
  Massacre                              = Spell(281001),
  FervorofBattle                        = Spell(202316),
  Rend                                  = Spell(772),
  RendDebuff                            = Spell(772),
  CollateralDamage                      = Spell(268243),
  Warbreaker                            = Spell(262161),
  Cleave                                = Spell(845),
  InForTheKill                          = Spell(248261),
  Avatar                                = Spell(107574),
  DeadlyCalm                            = Spell(262228),
  DeadlyCalmBuff                        = Spell(262228),
  AngerManagement                       = Spell(152278),
  Dreadnaught                           = Spell(262150),
  Ravager                               = Spell(152277),
  -- Azerite Traits
  CrushingAssaultBuff                   = Spell(278826),
  TestofMight                           = Spell(275529),
  TestofMightBuff                       = Spell(275540),
  SeismicWave                           = Spell(277639),
  -- Essences
  BloodoftheEnemy                       = Spell(297108),
  SeethingRageBuff                      = Spell(297126), -- from blood of the enemy first part
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  GuardianofAzerothBuff                 = Spell(295855),
  ReapingFlames                         = Spell(310690),
  ConcentratedFlameBurn                 = Spell(295368),
  RecklessForceBuff                     = Spell(302932),
  -- Defensives
  DefensiveStance                       = Spell(197690),
  VictoryRush                           = Spell(34428),
  -- Utilities
  Charge                                = Spell(100),
  HeroicLeap                            = Spell(6544),
  Pummel                                = Spell(6552),
  IntimidatingShout                     = Spell(5246),
  -- Misc
  RazorCoralDebuff                      = Spell(303568),
  PoolRage                              = Spell(9999000010),
  AutoAttack                            = Spell(6603),
};
S = Spell.Warrior.Arms;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Arms = {
  PotionofFocusedResolve           = Item(168506),
  PotionofUnbridledFury            = Item(169299),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  FangOfMerektha                   = Item(158367, {13, 14}),
};
I = Item.Warrior.Arms;

-- GUI Settings
Everyone = HR.Commons.Everyone;
Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Arms = HR.GUISettings.APL.Warrior.Arms
};


function UpdateRanges()
  for _, i in ipairs({8}) do
    HL.GetEnemies(i);
  end
end

function num(val)
  if val then return 1 else return 0 end
end

function bool(val)
  return val ~= 0
end

-----------------------------------
-- Helper Functions for ARMS APL --
-----------------------------------

ExecuteThreshold = 20 + 15 * num(S.Massacre:IsAvailable())

function SwingTimerRemains() 
  local _, lastTime = WeakAuras.GetSwingTimerInfo("main")
  return lastTime - GetTime()
end

-- Return nil (or a Unit) if there is a target in execute range.
function AnyTargetInExecuteRange()
  for _, Unit in pairs(Cache.Enemies[8]) do
    if Unit:HealthPercentage() < ExecuteThreshold then return Unit; end
  end
  return nil;
end

-- Return nil (or a Unit) if there is a target that needs Deep Wounds refreshed.
function AnyTargetInDeepWoundRefreshRange()
  for _, Unit in pairs(Cache.Enemies[8]) do
    if Unit:DebuffRemainsP(S.DeepWoundsDebuff) < 1.8 then return Unit; end
  end
  return nil;
end

-- Return nil (or a Unit) if there is a target that needs Rend refreshed.
function AnyTargetInRendRefreshRange()
  for _, Unit in pairs(Cache.Enemies[8]) do
    if Unit:DebuffRemainsP(S.RendDebuff) < 3.6 then return Unit; end
  end
  return nil;
end

-- meta-handler function to resolve abilities that cost rage but may give refunds, depending on talents. arguments are:
-- base_spend: the base cost of the ability
-- base_refund: currently, only used for "execute" ability which has a native rage refund built in
-- ability_works_with_collateral_damage: used to determine if you may get a 20% rage refund
local function HandleRefunds(base_spend, base_refund, ability_works_with_collateral_damage)
    local lb_base = -base_spend
    local ub_base = -base_spend
    -- base_refund purely here for execute's baseline refund
    local lb_refund = base_refund
    local ub_refund = base_refund
    -- if deadly calm is up, rage deltas go to zero but you're still treated as spending the rage for refund purposes.
    if Player:BuffP(S.DeadlyCalmBuff) then
        lb_base = 0
        ub_base = 0
    end
    -- if collateral damage is talented and sweeping strikes is up and there's a second target, you get a 20% rage refund!
    if ability_works_with_collateral_damage and S.CollateralDamage:IsAvailable() and EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        lb_refund = lb_refund + 0.2 * base_spend
        ub_refund = ub_refund + 0.2 * base_spend
    end
    -- if lucid dreams is a minor, as an upper bound you may get 50% of the rage refunded from the proc (15% chance)
    if Spell:EssenceEnabled(AE.MemoryofLucidDreams) then
        ub_refund = ub_refund + 0.5 * base_spend
    end
    -- if lucid dreams is ACTIVE, your cumulative refund is doubled.
    if Player:BuffP(S.MemoryofLucidDreams) then
        lb_refund = lb_refund * 2.0
        ub_refund = ub_refund * 2.0
    end
    return lb_base + lb_refund, ub_base + ub_refund
end

-- This is the core of the smart logic.
-- Returns a bound [lower_bound, upper_bound] for the ability in question.
-- Negative values mean using this ability costs rage. Positive values mean it refunds rage.
function RageDeltas(ability)
  local lb = 0
  local ub = 0
  if ability == S.AutoAttack then
    lb = 25.2
    ub = lb * 1.3
    if S.WarMachine:IsAvailable() then
      lb = lb * 1.1
      ub = ub * 1.1
    end
    if Player:BuffP(S.MemoryofLucidDreams) then
      lb = lb * 2.0
      ub = ub * 2.0
    end
  -- charge and skullsplitter both generate 20 rage.
  elseif ability == S.Charge or ability == S.Skullsplitter then
    lb = 20
    ub = 20
  -- mortal strike costs 30 rage, does not default refund, and does collateral-cleave-refund.
  elseif ability == S.MortalStrike then
    lb, ub = HandleRefunds(30, 0, true)
  -- cleave costs 20 rage, does not default refund, and does not collateral-cleave-refund.
  elseif ability == S.Cleave then
    lb, ub = HandleRefunds(20, 0, false)
  -- execute costs between 20 and 40 rage, refunds 20% by default, and does collateral-cleave-refund.
  elseif ability == S.Execute then
    local base_spend = Player:Rage()
    if Player:BuffP(S.SuddenDeathBuff) or Player:BuffP(S.DeadlyCalmBuff) or Player:Rage() >= 40 then
      base_spend = 40
    end
    lb, ub = HandleRefunds(base_spend, 0.2*base_spend, true)
  -- slam costs 20 rage (zero with crussing assault), does not default refund, and does collateral-cleave-refund
  elseif ability == S.Slam then
    local base_spend = 20
    if Player:BuffP(S.CrushingAssaultBuff) then base_spend = 0 end
    lb, ub = HandleRefunds(base_spend, 0, true)
  -- whirlwind costs 30 rage (10 w/ fervor + crushing assault), does not default refund, and does collateral-cleave-refund if you have fervor-of-battle talented.
  elseif ability == S.Whirlwind then
    local base_spend = 30
    if S.FervorofBattle:IsAvailable() and Player:BuffP(S.CrushingAssaultBuff) then base_spend = 10 end
    lb, ub = HandleRefunds(base_spend, 0, S.FervorofBattle:IsAvailable())
  -- rend costs 30 rage, does not default refund, and does collateral-cleave-refund
  elseif ability == S.Rend then
    lb, ub = HandleRefunds(30, 0, true)
  end
  return lb, ub
end


-- Casts `ability` right now, using current rage.
-- uses the rage deltas function above to modify current rage.
-- fast forwards to next global, perhaps adding in rage from an auto attack
-- returns the rage bounds based on auto attack and crit values, 
-- does not handle rage from damage taken
function RageBoundsAtNextGCDAfterCasting(ability)
  local current_rage = Player:Rage()
  local lb, ub = RageDeltas(ability)
  local rage_lb = min(max(0, current_rage + lb), 100)
  local rage_ub = max(min(current_rage + ub, 100), 0)
  if SwingTimerRemains() < select(2, GetSpellCooldown(61304)) then
    auto_attack_lb, auto_attack_ub = RageDeltas(S.AutoAttack)
    rage_lb = min(max(0, rage_lb + auto_attack_lb), 100)
    rage_ub = max(min(rage_ub + auto_attack_ub, 100), 0)
  end
  return rage_lb, rage_ub
end


-- All of these functions track how much damage pressing the button on the best target would do "right now" - that includes azerite, buffs, etc.
-- When we need to spend rage, we pick the best one of these.
-- these are all from the AMR wiki
local armor_reduction = 0.3198

function GetDeepWoundsDamage(unit)
    local periodic_damage_added = 0
    local current_deep_wounds = unit:DebuffRemainsP(S.DeepWoundsDebuff)
    if current_deep_wounds < 1.8 then
        local seconds_added = min(min(6, 7.8 - current_deep_wounds), unit:TimeToDie())
        local ticks_per_second = (1 + Player:HastePct()/100) / 2
        local ticks_added = ticks_per_second * seconds_added
        periodic_damage_added = 0.125 * ticks_added * (1 + Player:MasteryPct()/100)
    end
    return periodic_damage_added
end

function GetRendDamage(unit)
    local direct_damage = 0.265 * armor_reduction
    local periodic_damage = 0
    local current_rend = unit:DebuffRemainsP(S.RendDebuff)
    if current_rend < 3.6 then
      local seconds_added = min(min(12, 15.6 - current_rend), unit:TimeToDie())
      local ticks_per_second = (1 + Player:HastePct()/100) / 3
      local ticks_added = ticks_per_second * seconds_added
      periodic_damage = 0.232 * ticks_added
    end
    if EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        direct_damage = direct_damage * 1.75
        periodic_damage = periodic_damage * 2
    end
    return direct_damage + periodic_damage
end

function GetCleaveDamage(unit)
    local direct_damage = 0.45 * armor_reduction * EnemyCount
    local wounds_damage = 0
    if EnemyCount >= 3 then
        for _, Unit in pairs(Cache.Enemies[8]) do
            wounds_damage = wounds_damage + GetDeepWoundsDamage(Unit)
        end
    end
    return direct_damage + wounds_damage
end

function GetExecuteDamage(unit)
    local rage_spent = Player:Rage()
    if Player:BuffP(S.SuddenDeathBuff) or Player:BuffP(S.DeadlyCalmBuff) or Player:Rage() >= 40 then
        rage_spent = 40
    end
    local direct_damage = 0.922 * armor_reduction * rage_spent/20
    local wounds_damage = GetDeepWoundsDamage(unit)
    if EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        direct_damage = direct_damage * 1.75
        wounds_damage = wounds_damage * 2
    end
    return direct_damage + wounds_damage
end

function GetMortalStrikeDamage(unit)
    local direct_damage = 1.26 * (1 + 0.2 * Player:BuffStackP(S.OverpowerBuff)) * armor_reduction
    local wounds_damage = GetDeepWoundsDamage(unit)
    if EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        direct_damage = direct_damage * 1.75
        wounds_damage = wounds_damage * 2
    end
    return direct_damage + wounds_damage
end

function GetWhirlwindDamage(unit) 
    local damage = 0.348 * armor_reduction * EnemyCount
    if S.FervorofBattle:IsAvailable() then
        damage = damage * 1.1 + GetSlamDamage(unit)
    end
    return damage
end

function GetSlamDamage(unit)
    -- TODO: crushing assault computation not supported
    local damage = 0.636 * armor_reduction
    if EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        damage = damage * 1.75
    end
    return damage
end

-- For any given unit, find the rage dump that is the highest damage per rage value
function ChooseBestRageDumpForUnit(unit)
    local best_move = nil
    local best_value = 0
    local hold_rage_for_cleave = S.Cleave:CooldownRemainsP() < Player:GCD() + 0.15 and EnemyCount >= 3
    local hold_rage_for_mortal_strike = S.MortalStrike:CooldownRemainsP() < Player:GCD() + 0.15 and not AnyTargetInExecuteRange() 

    rend_damage = GetRendDamage(unit)
    cleave_damage = GetCleaveDamage(unit)
    execute_damage = GetExecuteDamage(unit)
    mortal_strike_damage = GetMortalStrikeDamage(unit)
    whirlwind_damage = GetWhirlwindDamage(unit)
    slam_damage = GetSlamDamage(unit)
    -- TODO: don't try to cast ww/slam spells you don't have rage for
    -- TODO: don't try to cast ww/slam spells that would leave you below the amount of rage
    --       you need to hit cleave or MS on cooldown
    if Player:Rage() > 30 and S.Rend:IsCastableP() then
        local rend_value = rend_damage / 30
        if rend_value > best_value then
            best_move = S.Rend
            best_value = rend_value
        end
    end

    if Player:Rage() > 20 and S.Cleave:IsCastableP() then
        local cleave_value = cleave_damage / 20
        if cleave_value > best_value then
            best_move = S.Cleave
            best_value = cleave_value
        end
    end
   
    if (Player:Rage() > 20 and unit:HealthPercentage() < ExecuteThreshold) or Player:BuffP(S.SuddenDeathBuff) then
        local base_spend = Player:Rage()
        if Player:BuffP(S.SuddenDeathBuff) or Player:BuffP(S.DeadlyCalmBuff) or Player:Rage() >= 40 then
          base_spend = 40
        end
        local execute_value = execute_damage / (0.8*base_spend)
        if execute_value > best_value then
            best_move = S.Execute
            best_value = execute_value
        end
    end

    if Player:Rage() > 30 and (S.MortalStrike:IsCastableP() or S.MortalStrike:CooldownRemainsP() < 0.15) then
        local mortal_strike_value = mortal_strike_damage / 30
        if mortal_strike_value > best_value then
            best_move = S.MortalStrike
            best_value = mortal_strike_value
        end
    end

    if Player:Rage() > 30 and S.Whirlwind:IsCastableP() then
        local whirlwind_value = whirlwind_damage / 30
        if whirlwind_value > best_value then
            best_move = S.Whirlwind
            best_value = whirlwind_value
        end
    end

    if Player:Rage() > 20 and S.Slam:IsCastableP() then
        local slam_value = slam_damage / 20
        if slam_value > best_value then
            best_move = S.Slam
            best_value = slam_value
        end
    end

    return best_move, best_value
end


function ChooseBestUnitAndRageDump()
    local BestUnit = Target
    local BestMove = S.PoolRage
    local BestMoveValue = 0
    for _, Unit in pairs(Cache.Enemies[8]) do
        local best_move, best_value = ChooseBestRageDumpForUnit(Unit)
        -- prioritize hitting smash'd mobs
        local multiplier = (1 + 0.3*num(Unit:DebuffRemainsP(S.ColossusSmashDebuff)))
        best_value = best_value * multiplier
        if best_value > BestMoveValue then
            BestUnit = Unit
            BestMove = best_move
            BestMoveValue = best_value
        end
    end
    return BestUnit, BestMove
end
-- Addon
local addonName, addonTable = ...

-- HeroLib
local HL      = HeroLib;
local Cache   = HeroCache;
local Unit    = HL.Unit;
local Player  = Unit.Player;
local Pet     = Unit.Pet;
local Target  = Unit.Target;
local Spell   = HL.Spell;
local MultiSpell = HL.MultiSpell
local Item    = HL.Item;

-- HeroRotation
local HR      = HeroRotation;
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

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
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Arms = HR.GUISettings.APL.Warrior.Arms
};


local function UpdateRanges()
  for _, i in ipairs({8}) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-----------------------------------
-- Helper Functions for ARMS APL --
-----------------------------------

local ExecuteThreshold = 20 + 15 * num(S.Massacre:IsAvailable())

local function SwingTimerRemains() 
  local _, lastTime = WeakAuras.GetSwingTimerInfo("main")
  return lastTime - GetTime()
end

-- Return nil (or a Unit) if there is a target in execute range.
local function AnyTargetInExecuteRange()
  for _, Unit in pairs(Cache.Enemies[8]) do
    if Unit:HealthPercentage() < ExecuteThreshold then return Unit; end
  end
  return nil;
end

-- Return nil (or a Unit) if there is a target that needs Deep Wounds refreshed.
local function AnyTargetInDeepWoundRefreshRange()
  for _, Unit in pairs(Cache.Enemies[8]) do
    if Unit:DebuffRemainsP(S.DeepWoundsDebuff) < 1.8 then return Unit; end
  end
  return nil;
end

-- Return nil (or a Unit) if there is a target that needs Rend refreshed.
local function AnyTargetInRendRefreshRange()
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
local function RageDeltas(ability)
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
local function RageBoundsAtNextGCDAfterCasting(ability)
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
-- When we need to spend rage, we pick the most rage-efficient one of these.
-- these are all from the TC wiki
local armor_reduction = 0.3198

local function GetDeepWoundsDamage(unit)
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

local function GetRendDamage(unit)
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

local function GetCleaveDamage(unit)
    local direct_damage = 0.45 * armor_reduction * EnemyCount
    local wounds_damage = 0
    if EnemyCount >= 3 then
        for _, Unit in pairs(Cache.Enemies[8]) do
            wounds_damage = wounds_damage + GetDeepWoundsDamage(Unit)
        end
    end
    return direct_damage + wounds_damage
end

local function GetExecuteDamage(unit)
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

local function GetMortalStrikeDamage(unit)
    local direct_damage = 1.26 * (1 + 0.2 * Player:BuffStackP(S.OverpowerBuff)) * armor_reduction
    local wounds_damage = GetDeepWoundsDamage(unit)
    if EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        direct_damage = direct_damage * 1.75
        wounds_damage = wounds_damage * 2
    end
    return direct_damage + wounds_damage
end

local function GetSlamDamage(unit)
    -- TODO: crushing assault computation not supported
    local damage = 0.636 * armor_reduction
    if EnemyCount >= 2 and Player:BuffP(S.SweepingStrikesBuff) then
        damage = damage * 1.75
    end
    return damage
end

local function GetWhirlwindDamage(unit) 
    local damage = 0.348 * armor_reduction * EnemyCount
    if S.FervorofBattle:IsAvailable() then
        damage = damage * 1.1 + GetSlamDamage(unit)
    end
    return damage
end


-- For any given unit, find the rage dump that is the highest damage per rage value
local function ChooseBestRageDumpForUnit(unit)
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


local function ChooseBestUnitAndRageDump()
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
local StunInterrupts = {
  {S.IntimidatingShout, "Cast Intimidating Shout (Interrupt)", function () return true; end},
};

-- Static Rotation Variables
local SmashSpell = S.ColossusSmash
if S.Warbreaker:IsAvailable() then SmashSpell = S.Warbreaker end

local function Precombat()
  if S.MemoryofLucidDreams:IsCastableP() and (S.FervorofBattle:IsAvailable() or not S.FervorofBattle:IsAvailable() and Target:TimeToDie() > 150) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Precombat Lucid"; end
  end
  if S.GuardianofAzeroth:IsCastableP() and (S.FervorofBattle:IsAvailable() or S.Massacre:IsAvailable() and Target:TimeToDie() > 210 or S.Rend:IsAvailable() and (Target:TimeToDie() > 210 or Target:TimeToDie() < 145)) then
    if HR.Cast(S.GuardianofAzeroth) then return "Precombat Guardian"; end
  end
end

local function DamageCooldowns()
  if I.FangOfMerektha:IsEquipReady() and Settings.Commons.UseTrinkets and Player:BuffP(S.TestofMightBuff) and Player:BuffP(S.SeethingRageBuff) then
    if HR.Cast(I.FangOfMerektha, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "Fang w/ BoTE Up"; end
  end
  if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or (Target:HealthPercentage() < ExecuteThreshold and (Player:BuffP(S.MemoryofLucidDreams) and (S.MemoryofLucidDreams:CooldownRemainsP() < 106 or S.MemoryofLucidDreams:CooldownRemainsP() < 117 and Target:TimeToDie() < 20 and not S.Massacre:IsAvailable()) or Player:BuffP(S.GuardianofAzerothBuff) and Target:DebuffP(S.ColossusSmashDebuff))) or Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Target:HealthPercentage() < 20 or (Target:HealthPercentage() < 30.1 and Target:DebuffP(S.ConductiveInkDebuff) and not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce)) or (Target:DebuffDownP(S.ConductiveInkDebuff) and not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Target:DebuffP(S.ColossusSmashDebuff))) then
    if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "Use Coral"; end
  end
  if S.BloodoftheEnemy:IsCastableP() and Player:BuffP(S.TestofMightBuff) and S.Bladestorm:IsCastableP() and ((I.FangOfMerektha:IsEquipped() and I.FangOfMerektha:IsEquipReady()) or not I.FangOfMerektha:IsEquipped()) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "BoTE"; end
  end
  if S.MemoryofLucidDreams:IsCastableP() and SmashSpell:CooldownRemainsP() < 1 and (Target:TimeToDie() > 150 or Target:HealthPercentage() < ExecuteThreshold) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Lucid"; end
  end
  if S.Bladestorm:IsCastableP() and Player:BuffDownP(S.SweepingStrikesBuff) and not TestingMight and Player:BuffRemainsP(S.TestofMightBuff) > (6 / (1 + Player:HastePct() / 100)) and EnemyCount >= 2 then
    if HR.Cast(S.Bladestorm) then return "AOE Bladestorm"; end
  end
  if S.Bladestorm:IsCastableP() and Player:BuffDownP(S.SweepingStrikesBuff) and not TestingMight and Player:BuffRemainsP(S.TestofMightBuff) > (6 / (1 + Player:HastePct() / 100)) and Player:BuffDownP(S.MemoryofLucidDreams) and Player:Rage() < 30 then
    if HR.Cast(S.Bladestorm) then return "ST Bladestorm"; end
  end
end


--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  local FightRemains = HL.FightRemains("<", 40)
  local TestingMight = SmashSpell:TimeSinceLastCast() <= 10
  local TestingMightTimeLeft = 10 - SmashSpell:TimeSinceLastCast()
  local BladestormSoon = S.Bladestorm:CooldownRemainsP() < 7
  local ShouldDumpRage = TestingMight or BladestormSoon
  EnemyCount = Cache.EnemiesCount[8]

  if not Everyone.TargetIsValid() then
    return "Invalid Target"
  end
  if not Player:AffectingCombat() then
    Precombat()
  end
  if not Target:IsInRange("Melee") and Target:IsInRange(25) and S.Charge:IsReadyP() and S.Charge:ChargesP() >= 1 then
    if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge, nil, 25) then return "Charge into Melee"; end
  end
  if not Target:IsInRange("Melee") and Target:IsInRange(40) and S.HeroicLeap:IsCastableP() and S.Charge:ChargesP() < 1 then
    if HR.Cast(S.HeroicLeap, Settings.Arms.GCDasOffGCD.HeroicLeap, nil, 40) then return "Leap into Melee"; end
  end
  if S.VictoryRush:IsReady() and Player:HealthPercentage() < 50 then
    if HR.CastSuggested(S.VictoryRush) then return "Victory Rush"; end
  end

  Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts)
  DamageCooldowns()

  -- In AOE, if you have cleave talent, use it to ensure deep wounds is maintained.
  if S.Cleave:IsAvailable() and S.Cleave:CooldownRemainsP() < 0.15 and EnemyCount >= 3 and AnyTargetInDeepWoundRefreshRange() then
    if HR.Cast(S.Cleave) then return "Cleave"; end
  end

  -- In cleave, if you have sweeping strikes and the fight will last long enough, use it.
  if FightRemains >= 10 and S.SweepingStrikes:IsCastableP("Melee") and EnemyCount >= 2 and SmashSpell:CooldownRemainsP() < 2 then
    if HR.CastSuggested(S.SweepingStrikes) then return "Sweeping Strikes"; end
  end
  -- for all targets, if there are any that will live >10s, colossus smash or warbreaker them. 
  if Target:TimeToDie() >= 10 and SmashSpell:IsCastableP() then
    if HR.Cast(SmashSpell) then return "Smash"; end
  end

  -- Skull splitter if you won't cap rage if you're not testing might, or if you *are* testing might but you're gonna run out of rage.
  if (not TestingMight or Player:Rage() < 30) and S.Skullsplitter:IsCastableP("Melee") and select(2, RageBoundsAtNextGCDAfterCasting(S.Skullsplitter)) < 100 then
    if HR.Cast(S.Skullsplitter) then return "Skullsplitter while not Testing Might"; end
  end

  -- Figure out when to overpower appropriately. 
  -- TODO: this condition (mortal strike cd on 1t should actually check if we want to MS to apply deep wounds on 2t or in scenarios without cleave to spread)
  --if (not TestingMight or Player:Rage() < 60) and S.Overpower:IsCastableP() and Player:BuffDownP(S.MemoryofLucidDreams) and select(2, RageBoundsAtNextGCDAfterCasting(S.Overpower)) < 100 then
  if S.Overpower:IsCastableP() and Player:BuffDownP(S.MemoryofLucidDreams) and select(2, RageBoundsAtNextGCDAfterCasting(S.Overpower)) < 100 then
    if HR.Cast(S.Overpower) then return "Overpower while not testing might"; end
  end

  local BestUnit, BestMove = ChooseBestUnitAndRageDump()
  -- Generally, pick the best move from our logic in the other file.
  -- We overwrite in a few cases:
  -- 1) It's telling us to slam but we're so high on rage (lower bound caps rage next gcd) that we actually need to spend 30 instead of 20 rage now.
  if BestMove == S.Slam and select(1, RageBoundsAtNextGCDAfterCasting(BestMove)) > 100 then
    BestMove = S.Whirlwind
  end
  -- 2) It's telling us to cast a filler but the BEST CASE for that would take us below cleave or mortal strike rage, which we want to press on CD.
  -- TODO ^^^

  if (BestUnit:GUID() ~= Target:GUID()) and (BestMove == S.Rend or BestMove == S.Execute or BestMove == S.MortalStrike) then
    if HR.CastLeftNameplate(BestUnit, BestMove) then return "Off-target Rage Dump"; end
  else
    if HR.Cast(BestMove) then return "On-target Rage Dump"; end
  end
  if S.Overpower:IsCastableP() then
    if HR.Cast(S.Overpower) then return "Free Overpower"; end
  end
  if HR.Cast(S.PoolRage) then return "Pool"; end
end

local function Init()
  HL.RegisterNucleusAbility(152277, 8, 6)               -- Ravager
  HL.RegisterNucleusAbility(227847, 8, 6)               -- Bladestorm
  HL.RegisterNucleusAbility(845, 8, 6)                  -- Cleave
  HL.RegisterNucleusAbility(1680, 8, 6)                 -- Whirlwind
end

HR.SetAPL(71, APL, Init)

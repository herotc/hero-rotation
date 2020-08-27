--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local MouseOver  = Unit.MouseOver
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

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
  PoolRage                              = Spell(9999000010)
};
local S = Spell.Warrior.Arms;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Arms = {
  PotionofFocusedResolve           = Item(168506),
  PotionofUnbridledFury            = Item(169299),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14})
};
local I = Item.Warrior.Arms;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID()
}

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Arms = HR.GUISettings.APL.Warrior.Arms
};

-- Stuns
local StunInterrupts = {
  {S.IntimidatingShout, "Cast Intimidating Shout (Interrupt)", function () return true; end},
};

local EnemyRanges = {8}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- Rotation Variables
local ShouldReturn; -- Used to get the return string
local ExecuteThreshold = 20 + 15 * num(S.Massacre:IsAvailable())
local InExecuteRange;
local NumTargetsInMelee;

local function SomeTargetInExecuteRange()
  for _, Unit in pairs(Cache.Enemies[8]) do
    if Unit:HealthPercentage() < ExecuteThreshold then return true; end
  end
  return false;
end

-- Identify targets around you that are susceptible to executes.
-- Execute the lowest HP one of them.
local function PerformExecuteSniping()
  local BestUnit, BestUnitHP;
  HL.GetEnemies(8);
  BestUnit, BestUnitHP = nil, 100;
  local HP;
  for _, Unit in pairs(Cache.Enemies[8]) do
    HP = Unit:HealthPercentage();
    if HP < BestUnitHP and HP < ExecuteThreshold then
      BestUnit, BestUnitHP = Unit, HP;
    end
  end
  if BestUnit and Player:Rage() > 20 then
    if BestUnit:GUID() == Target:GUID() then
      if HR.Cast(S.Execute) then return "Execute main target"; end
    else
      if HR.CastLeftNameplate(BestUnit, S.Execute) then return "Execute snipe off target"; end
    end
  end
end

-- Target If handler
-- Mode is "min", "max", or "first"
-- ModeEval the target_if condition (function with a target as param)
-- IfEval the condition on the resulting target (function with a target as param)
local function CheckTargetIfTarget(Mode, ModeEvaluation, IfEvaluation)
  -- First mode: Only check target if necessary
  local TargetsModeValue = ModeEvaluation(Target);
  if Mode == "first" and TargetsModeValue ~= 0 then
    return Target;
  end

  local BestUnit, BestValue = nil, 0;
  local function RunTargetIfCycler(Range)
    for _, CycleUnit in pairs(Cache.Enemies[Range]) do
      local ValueForUnit = ModeEvaluation(CycleUnit);
      if not BestUnit and Mode == "first" then
        if ValueForUnit ~= 0 then
          BestUnit, BestValue = CycleUnit, ValueForUnit;
        end
      elseif Mode == "min" then
        if not BestUnit or ValueForUnit < BestValue then
          BestUnit, BestValue = CycleUnit, ValueForUnit;
        end
      elseif Mode == "max" then
        if not BestUnit or ValueForUnit > BestValue then
          BestUnit, BestValue = CycleUnit, ValueForUnit;
        end
      end
      -- Same mode value, prefer longer TTD
      if BestUnit and ValueForUnit == BestValue and CycleUnit:TimeToDie() > BestUnit:TimeToDie() then
        BestUnit, BestValue = CycleUnit, ValueForUnit;
      end
    end
  end

  -- Prefer melee cycle units over ranged
  RunTargetIfCycler(8);
  -- Prefer current target if equal mode value results to prevent "flickering"
  if BestUnit and BestValue == TargetsModeValue and IfEvaluation(Target) then
    return Target;
  end
  if BestUnit and IfEvaluation(BestUnit) then
    return BestUnit;
  end
  return nil
end


-- handle rage control micro.
-- functions here figure out how much an ability will change your rage by, after refunds and everything applies.
-- this function is probabilistic, so we return tuple [lower, expectation, upper] for some values.
-- a negative value means the ability costs rage
-- a positive value means the abliity generates rage
-- the idea is to use this function, combined with "will my next autoattack land before the GCD"
-- to determine if you're going to cap rage, or if you're going to have enough rage for one of the ability you want to press on CD
-- (cleave, mortal strike)
local function RageDeltas(ability_name)
  local lb = 0
  local exp = 0
  local ub = 0
  -- Compute base mainhand speed for rage generation.
  -- TODO(mrdmnd) - this doesn't really need to be recomputed every frame. cache somewhere, update on weapon change.
  -- autoattack
  -- you generate WeaponSpeed * 7 rage per hit. crits return 30% more rage. war machine stacks multiplicatively with this.
  -- WeaponSpeed is set to 3.6 for 2h'ers, thus the base rage is 25.2
  -- memory of lucid dreams active ability increases this 100% multiplicatively
  if ability_name == "auto_attack" then
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
    local crit = Player:CritChancePct()/100.0
    exp = (1-crit)*lb + crit*ub
    return lb, exp, ub
  end

  -- charge and skullsplitter
  -- charge and skullsplitter both generate 20 rage, scaling with lucid dreams
  if ability_name == "charge" or ability_name == "skullsplitter" then
    lb = 20
    exp = 20
    ub = 20
    if Player:BuffP(S.MemoryofLucidDreams) then
      lb = lb * 2.0
      exp = exp * 2.0
      ub = ub * 2.0
    end
    return lb, exp, ub
  end

  -- overpower
  -- overpower costs zero for arms.
  if ability_name == "overpower" then
    return 0, 0, 0
  end

  -- meta-handler function to resolve abilities that cost rage but may give refunds, depending on talents. arguments are:
  -- base_spend: the base cost of the ability
  -- base_refund: currently, only used for "execute" ability which has a native rage refund built in
  -- ability_works_with_collateral_damage: used to determine if you may get a 20% rage refund
  local function HandleRefunds(base_spend, base_refund, ability_works_with_collateral_damage)
    local lb = -base_spend
    local ub = -base_spend
   -- base_refund purely here for execute's baseline refund
    local refund_lb = base_refund
    local refund_ub = base_refund

    -- if deadly calm is up, rage deltas go to zero but you're still treated as spending the rage for refund purposes.
    if Player:BuffP(S.DeadlyCalmBuff) then
       lb = 0
       ub = 0
    end
     -- if collateral damage is talented and sweeping strikes is up and there's a second target, you get a 20% rage refund!
    local collateral_refund_active = S.CollateralDamage:IsAvailable() and NumTargetsInMelee >= 2 and Player:BuffP(S.SweepingStrikesBuff)
    if ability_works_with_collateral_damage and collateral_refund_active then
      refund_lb = refund_lb + 0.2 * base_spend
      refund_ub = refund_ub + 0.2 * base_spend
    end

    -- if lucid dreams is a minor, as an upper bound you may get 50% of the rage refunded from the proc (15% chance)
    if Spell:EssenceEnabled(AE.MemoryofLucidDreams) then
      refund_ub = refund_ub + 0.5 * base_spend
    end

    -- if lucid dreams is ACTIVE, your cumulative refund is doubled.
    if Player:BuffP(S.MemoryofLucidDreams) then
      refund_lb = refund_lb * 2.0
      refund_ub = refund_ub * 2.0
    end

    -- the probability of landing on final_ub is 0.15, when lucid minor procs
    local final_lb = lb + refund_lb
    local final_ub = ub + refund_ub
    local final_exp = 0.85*final_lb + 0.15*final_ub
    return final_lb, final_exp, final_ub
  end

  -- mortal strike
  -- mortal strikes costs 30 rage, does not default refund, and collateral-cleaves.
  if ability_name == "mortal_strike" then
    return HandleRefunds(30, 0, true)
  end 

  -- cleave
  -- cleave costs 20 rage, does not default refund, and does not collateral-cleave
  if ability_name == "cleave" then
    return HandleRefunds(20, 0, false)
  end

  -- execute
  -- execute costs between 20 and 40 rage, refunds 20% by default, and collateral cleaves.
  if ability_name == "execute" then
    local base_spend = Player:Rage()
    if Player:BuffP(S.SuddenDeathBuff) or Player:BuffP(S.DeadlyCalmBuff) or Player:Rage() >= 40 then
      base_spend = 40
    end
    -- execute refunds 20% of the rage spent if the target does not die (assume that we never kill a target with an execute)
    return HandleRefunds(base_spend, 0.2*base_spend, true)
  end

  -- slam
  -- slam costs 20 rage, does not default refund, and collateral-cleaves.
  -- if you have a crushing assault buff, it costs zero rage.
  if ability_name == "slam" then
    local base_spend = 20
    if Player:BuffP(S.CrushingAssaultBuff) then base_spend = 0 end
    return HandleRefunds(base_spend, 0, true)
  end

  -- whirlwind
  -- whirlwind costs 30 rage, does not default refund, and collateral-cleaves if you have fervor-of-battle talented.
  -- if you have fervor and a crushing assault buff, it costs 10 rage (converts to slam, reduced by 20)
  if ability_name == "whirlwind" then
    local base_spend = 30
    if S.FervorofBattle:IsAvailable() and Player:BuffP(S.CrushingAssaultBuff) then base_spend = 10 end
    return HandleRefunds(base_spend, 0, S.FervorofBattle:IsAvailable())
  end

  -- rend
  -- rend costs 30 rage, does not default refund, and collateral-cleaves
  if ability_name == "rend" then
    return HandleRefunds(30, 0, true)
  end

  -- TODO: special handling.
  -- ravager
  -- bladestorm
  -- rage generated from bladestorm depends on how far into the swing timer you are when you cast it.
end


local function SwingTimerRemains() 
  local _, lastTime = WeakAuras.GetSwingTimerInfo("main")
  return lastTime - GetTime()
end
-- returns the bounds based on auto attack and crit values, does not handle rage from damage taken
local function RageAtNextGCD()
  local current_rage = Player:Rage()
  if SwingTimerRemains() < select(2, GetSpellCooldown(61304)) then
    local lb, exp, ub = RageDeltas("auto_attack")
    return current_rage + lb, current_rage + exp, current_rage + ub
  else
    return current_rage, current_rage, current_rage
  end
end

local function RageAfterNextAuto()
  local current_rage = Player:Rage()
  local lb, exp, ub = RageDeltas("auto_attack")
  return current_rage + lb, current_rage + exp, current_rage + ub
end

local function Precombat()
  if Everyone.TargetIsValid() then
    -- memory_of_lucid_dreams,if=talent.fervor_of_battle.enabled|!talent.fervor_of_battle.enabled&target.time_to_die>150
    if S.MemoryofLucidDreams:IsCastableP() and (S.FervorofBattle:IsAvailable() or not S.FervorofBattle:IsAvailable() and Target:TimeToDie() > 150) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    -- guardian_of_azeroth,if=talent.fervor_of_battle.enabled|talent.massacre.enabled&target.time_to_die>210|talent.rend.enabled&(target.time_to_die>210|target.time_to_die<145)
    if S.GuardianofAzeroth:IsCastableP() and (S.FervorofBattle:IsAvailable() or S.Massacre:IsAvailable() and Target:TimeToDie() > 210 or S.Rend:IsAvailable() and (Target:TimeToDie() > 210 or Target:TimeToDie() < 145)) then
      if HR.Cast(S.GuardianofAzeroth) then return "guardian_of_azeroth"; end
    end
  end
end

local function DamageCooldowns()
  -- use_item,name=ashvanes_razor_coral,if=!debuff.razor_coral_debuff.up|((target.health.pct<20.1|talent.massacre.enabled&target.health.pct<35.1)&(buff.memory_of_lucid_dreams.up&(cooldown.memory_of_lucid_dreams.remains<106|cooldown.memory_of_lucid_dreams.remains<117&target.time_to_die<20&!talent.massacre.enabled)|buff.guardian_of_azeroth.up&debuff.colossus_smash.up))|essence.condensed_lifeforce.major&target.health.pct<20|(target.health.pct<30.1&debuff.conductive_ink_debuff.up&!essence.memory_of_lucid_dreams.major&!essence.condensed_lifeforce.major)|(!debuff.conductive_ink_debuff.up&!essence.memory_of_lucid_dreams.major&!essence.condensed_lifeforce.major&debuff.colossus_smash.up)
  if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or (TargetInExecuteRange and (Player:BuffP(S.MemoryofLucidDreams) and (S.MemoryofLucidDreams:CooldownRemainsP() < 106 or S.MemoryofLucidDreams:CooldownRemainsP() < 117 and Target:TimeToDie() < 20 and not S.Massacre:IsAvailable()) or Player:BuffP(S.GuardianofAzerothBuff) and Target:DebuffP(S.ColossusSmashDebuff))) or Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Target:HealthPercentage() < 20 or (Target:HealthPercentage() < 30.1 and Target:DebuffP(S.ConductiveInkDebuff) and not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce)) or (Target:DebuffDownP(S.ConductiveInkDebuff) and not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Target:DebuffP(S.ColossusSmashDebuff))) then
    if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 381"; end
  end
  -- blood_of_the_enemy,if=(buff.test_of_might.up|(debuff.colossus_smash.up&!azerite.test_of_might.enabled))&(target.time_to_die>90|(target.health.pct<20|talent.massacre.enabled&target.health.pct<35))
  if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.TestofMightBuff) and (Target:TimeToDie() > 90 or TargetInExecuteRange or NumTargetsInMelee > 1)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
  end
  -- memory_of_lucid_dreams,if=!talent.warbreaker.enabled&cooldown.colossus_smash.remains<1&(target.time_to_die>150|(target.health.pct<20|talent.massacre.enabled&target.health.pct<35))
  if S.MemoryofLucidDreams:IsCastableP() and (not S.Warbreaker:IsAvailable() and S.ColossusSmash:CooldownRemainsP() < 1 and (Target:TimeToDie() > 150 or TargetInExecuteRange)) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
  end
  -- memory_of_lucid_dreams,if=talent.warbreaker.enabled&cooldown.warbreaker.remains<1&(target.time_to_die>150|(target.health.pct<20|talent.massacre.enabled&target.health.pct<35))
  if S.MemoryofLucidDreams:IsCastableP() and (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 1 and (Target:TimeToDie() > 150 or TargetInExecuteRange)) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 2"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  local RageAtNextGCDLB, RageAtNextGCDExp, RageAtNextGCDUB = RageAtNextGCD()
  local RageAfterNextAutoLB, RageAfterNextAutoExp, RageAfterNextAutoUB = RageAfterNextAuto()
  local TargetInExecuteRange = Target:HealthPercentage() < ExecuteThreshold
  NumTargetsInMelee = Cache.EnemiesCount[8]

  SmashSpell = S.ColossusSmash
  if S.Warbreaker:IsAvailable() then SmashSpell = S.Warbreaker end

  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end

  if Everyone.TargetIsValid() then
    if S.Charge:IsReadyP() and S.Charge:ChargesP() >= 1 then
      if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge, nil, 25) then return "Charge"; end
    end
    if S.VictoryRush:IsReady() and Player:HealthPercentage() < 50 then
      if HR.CastSuggested(S.VictoryRush) then return "Victory Rush"; end
    end


    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = DamageCooldowns(); if ShouldReturn then return ShouldReturn; end

    -- TODO: don't spend below rage needed for cleave on aoe?
    -- TODO: do we hold this for test of might, bladestorm, or smash? probably. fix this later.
    if Target:TimeToDie() >= 10 and S.SweepingStrikes:IsCastableP("Melee") and NumTargetsInMelee >= 2 and (SmashSpell:CooldownRemainsP() < 4 or SomeTargetInExecuteRange()) then
      if HR.CastSuggested(S.SweepingStrikes) then return "Sweeping Strikes"; end
    end

    -- for all targets, if there are any that will live >10s, colossus smash or warbreaker them. 
    if Target:TimeToDie() >= 10 and SmashSpell:IsCastableP() then
      if HR.CastRightSuggested(SmashSpell) then return "Smash"; end
    end

    -- todo: have a "dump rage for bladestorm if it's coming up soon" line
    if S.Bladestorm:IsCastableP() and Player:BuffDownP(S.SweepingStrikesBuff) and Player:BuffRemainsP(S.TestofMightBuff) > 3 and NumTargetsInMelee >= 2 then
      if HR.Cast(S.Bladestorm, true, nil, 8) then return "AOE Bladestorm"; end
    end
    if S.Bladestorm:IsCastableP() and (S.MortalStrike:CooldownRemainsP() > 1 or TargetInExecuteRange) and Player:BuffDownP(S.SweepingStrikesBuff) and
       Player:BuffDownP(S.MemoryofLucidDreams) and Target:DebuffDownP(S.ColossusSmashDebuff) and Player:BuffP(S.TestofMightBuff) and Player:Rage() < 30 then
      if HR.Cast(S.Bladestorm, true, nil, 8) then return "ST Bladestorm"; end
    end

    -- cleave on CD for deep wounds if available
    if S.Cleave:IsAvailable() and S.Cleave:CooldownRemainsP() < 0.15 and NumTargetsInMelee >= 3 then
      if HR.Cast(S.Cleave) then return "Cleave"; end
    end

    -- USE FREE SHIT
    -- skull splitter when you're sure that it won't overcap - that is, when your upper bound RageAtNextGCD + upperbound skull splitter rage is less than 100
    if S.Skullsplitter:IsCastableP("Melee") and select(3, RageAtNextGCD()) + select(3, RageDeltas("skullsplitter")) < 100 then
      if HR.Cast(S.Skullsplitter) then return "Skullsplitter"; end
    end
     -- use free overpower if you won't cap rage - consider not doing this at end of TOM window?.
    if S.Overpower:IsCastableP() and Player:BuffDownP(S.MemoryofLucidDreams) and
      select(3, RageAtNextGCD()) + select(3, RageDeltas("overpower")) < 100 then
      if HR.Cast(S.Overpower) then return "non-capping free overpower"; end
    end
    -- use free slam during 1T execute if you won't cap rage
    if NumTargetsInMelee == 1 and Target:HealthPercentage() < ExecuteThreshold and 
       S.Slam:IsCastableP() and Player:BuffP(S.CrushingAssaultBuff) and Player:BuffDownP(S.MemoryofLucidDreams) and
       select(3, RageAtNextGCD()) + select(3, RageDeltas("slam")) < 100 then
      if HR.Cast(S.Slam) then return "non-capping free slam during 1T execute"; end
    end
  
    -- DEEP WOUNDS MAINTENANCE - only if you don't have cleave, or there are two targets
    -- execute or mortal strike target_if on CD to reapply deep wounds if available (30% pandemic)
    -- refresh on adjacent unit prio, then refresh on current target
    if not S.Cleave:IsAvailable() or NumTargetsInMelee == 2 then
      local function ApplyDeepWoundsTargetIfFunc(TargetUnit)
        return TargetUnit:DebuffRemainsP(S.DeepWoundsDebuff);
      end
      local function ApplyDeepWoundsIfFunc(TargetUnit)
        return (TargetUnit:DebuffRemainsP(S.DeepWoundsDebuff) < 1.8) and
              (TargetUnit:FilteredTimeToDie(">", 6, -TargetUnit:DebuffRemainsP(S.DeepWoundsDebuff)) or TargetUnit:TimeToDieIsNotValid())
      end
    
      if ApplyDeepWoundsIfFunc(Target) then
        if Player:Rage() > 20 and Target:HealthPercentage() < ExecuteThreshold then
          if HR.Cast(S.Execute) then return "Execute Main Target to refresh Deep Wounds"; end
        end
        if S.MortalStrike:CooldownRemainsP() < 0.15 then
          if HR.Cast(S.MortalStrike) then return "Mortal Strike Main Target to refresh Deep Wounds"; end
        end
      end
  
      local TargetIfUnit = CheckTargetIfTarget("min", ApplyDeepWoundsTargetIfFunc, ApplyDeepWoundsIfFunc);
      if TargetIfUnit and TargetIfUnit:GUID() ~= Target:GUID() then
        if Player:Rage() > 20 and TargetIfUnit:HealthPercentage() < ExecuteThreshold then 
          if HR.CastLeftNameplate(TargetIfUnit, S.Execute) then return "Execute off target to refresh Deep Wounds"; end
        end
        if S.MortalStrike:CooldownRemainsP() < 0.15 then 
          if HR.CastLeftNameplate(TargetIfUnit, S.MortalStrike) then return "Mortal strike off target to refresh Deep Wounds"; end
        end
      end
    end
      

    -- RAGE DUMPS
    -- use filler spell if you might cap rage (either WW or slam or execute or MS or rend)
    if RageAtNextGCDUB > 100 then
      if S.Whirlwind:IsReadyP("Melee") and NumTargetsInMelee >= 5 then -- todo: mrdmnd: determine target threshold where this is better than 2t execute or MS
        if HR.Cast(S.Whirlwind) then return "Whirlwind as 5T rage dump to prevent cap"; end
      end
      if S.Execute:IsReady("Melee") and Player:BuffP(S.SweepingStrikesBuff) and NumTargetsInMelee >= 2 then
        if HR.Cast(S.Execute) then return "Execute as sweeping-strikes rage dump to prevent cap"; end
      end
      if S.MortalStrike:CooldownRemainsP() < 0.15 and Player:BuffP(S.SweepingStrikesBuff) and NumTargetsInMelee >= 2 then
        if HR.Cast(S.MortalStrike) then return "Mortal Strike as sweeping-strikes rage dump to prevent cap"; end
      end
      if S.Whirlwind:IsReadyP("Melee") and NumTargetsInMelee >= 2 then
        if HR.Cast(S.Whirlwind) then return "Whirlwind as 2+T rage dump to prevent cap"; end
      end
      if S.Execute:IsReady("Melee") then
        if HR.Cast(S.Execute) then return "Execute as 1T rage dump to prevent cap"; end
      end
      if S.MortalStrike:CooldownRemainsP() < 0.15 then
        if HR.Cast(S.MortalStrike) then return "Mortal strike as 1T rage dump to prevent cap"; end
      end
      if S.Whirlwind:IsReadyP("Melee") then
        if HR.Cast(S.Whirlwind) then return "Whirlwind as last-ditch 1T rage dump to prevent cap"; end
      end
    end

    -- EXECUTE_SNIPING
    PerformExecuteSniping();

    -- CORE ROTATION
    if S.Whirlwind:IsReadyP("Melee") and NumTargetsInMelee >= 5 then
      if HR.Cast(S.Whirlwind) then return "5T+ Whirlwind"; end
    end
    if S.Overpower:IsCastableP("Melee") and Target:DebuffP(S.DeepWoundsDebuff) and Player:BuffDownP(S.MemoryofLucidDreams) and Target:DebuffDownP(S.ColossusSmashDebuff) then
      if HR.Cast(S.Overpower) then return "Overpower"; end
    end
    if S.Execute:IsReady("Melee") then
      if HR.Cast(S.Execute) then return "Execute"; end
    end
    if S.Whirlwind:IsReadyP("Melee") and NumTargetsInMelee >= 2 then
      if HR.Cast(S.Whirlwind) then return "2T+ Whirlwind"; end
    end
    if S.MortalStrike:CooldownRemainsP() < 0.15 and Target:HealthPercentage() > ExecuteThreshold then
      if HR.Cast(S.MortalStrike) then return "Mortal Strike"; end
    end
    -- make sure that we don't WW or Slam below the rage we need for MS
    if S.FervorofBattle:IsAvailable() and S.Whirlwind:IsReadyP("Melee") and
      select(1, RageAtNextGCD()) + select(1, RageDeltas("whirlwind")) > 30 then
      if HR.Cast(S.Whirlwind) then return "Whirlwind (safely above 30 rage)"; end
    end
    if not S.FervorofBattle:IsAvailable() and S.Slam:IsReadyP("Melee") and 
      select(1, RageAtNextGCD()) + select(1, RageDeltas("slam")) > 30 then
      if HR.Cast(S.Slam) then return "Slam (safely above 30 rage)"; end
    end
    if HR.Cast(S.PoolRage) then return "Pool"; end


  end 
end

local function Init()
  HL.RegisterNucleusAbility(152277, 8, 6)               -- Ravager
  HL.RegisterNucleusAbility(227847, 8, 6)               -- Bladestorm
  HL.RegisterNucleusAbility(845, 8, 6)                  -- Cleave
  HL.RegisterNucleusAbility(1680, 8, 6)                 -- Whirlwind
end

HR.SetAPL(71, APL, Init)

-- Addon
local addonName, addonTable = ...

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
  -- TODO: fix "TargetInExecuteRange for ST raid encounters"
  -- TODO: handle merektha sync, handle aoe vs st vs execute
  if I.FangOfMerektha:IsEquipReady() and Settings.Commons.UseTrinkets and Player:BuffP(S.TestofMightBuff) and Player:BuffP(S.SeethingRageBuff) then
    if HR.Cast(I.FangOfMerektha, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "Fang w/ BoTE Up"; end
  end
  if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or (Target:HealthPercentage() < ExecuteThreshold and (Player:BuffP(S.MemoryofLucidDreams) and (S.MemoryofLucidDreams:CooldownRemainsP() < 106 or S.MemoryofLucidDreams:CooldownRemainsP() < 117 and Target:TimeToDie() < 20 and not S.Massacre:IsAvailable()) or Player:BuffP(S.GuardianofAzerothBuff) and Target:DebuffP(S.ColossusSmashDebuff))) or Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Target:HealthPercentage() < 20 or (Target:HealthPercentage() < 30.1 and Target:DebuffP(S.ConductiveInkDebuff) and not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce)) or (Target:DebuffDownP(S.ConductiveInkDebuff) and not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and not Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Target:DebuffP(S.ColossusSmashDebuff))) then
    if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "Use Coral"; end
  end
  if S.BloodoftheEnemy:IsCastableP() and Player:BuffP(S.TestofMightBuff) and S.Bladestorm:IsCastableP() then
    if I.FangOfMerektha:IsEquipped() and I.FangOfMerektha:IsEquipReady() then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "BoTE synced w/ Fang"; end
    else
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "BoTE"; end
    end
  end
  if S.MemoryofLucidDreams:IsCastableP() and SmashSpell:CooldownRemainsP() < 1 and (Target:TimeToDie() > 150 or Target:HealthPercentage() < ExecuteThreshold) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Lucid"; end
  end
  if S.Bladestorm:IsCastableP() and Player:BuffDownP(S.SweepingStrikesBuff) and not TestingMight and Player:BuffRemainsP(S.TestofMightBuff) > (6 / (1 + Player:HastePct() / 100)) and EnemyCount >= 2 then
    if HR.CastSuggested(S.Bladestorm) then return "AOE Bladestorm"; end
  end
  if S.Bladestorm:IsCastableP() and Player:BuffDownP(S.SweepingStrikesBuff) and not TestingMight and Player:BuffRemainsP(S.TestofMightBuff) > (6 / (1 + Player:HastePct() / 100)) and Player:BuffDownP(S.MemoryofLucidDreams) and Player:Rage() < 30 then
    if HR.CastSuggested(S.Bladestorm) then return "ST Bladestorm"; end
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
  if not Target:IsInRange("Melee") and Target:IsInRange(40) and S.HeroicLeap:IsCastableP() then
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

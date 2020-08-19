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

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Warrior then Spell.Warrior = {} end
Spell.Warrior.Arms = {
  Skullsplitter                         = Spell(260643),
  DeadlyCalm                            = Spell(262228),
  DeadlyCalmBuff                        = Spell(262228),
  Ravager                               = Spell(152277),
  ColossusSmash                         = Spell(167105),
  Warbreaker                            = Spell(262161),
  ColossusSmashDebuff                   = Spell(208086),
  Bladestorm                            = Spell(227847),
  Cleave                                = Spell(845),
  Slam                                  = Spell(1464),
  CrushingAssaultBuff                   = Spell(278826),
  MortalStrike                          = Spell(12294),
  OverpowerBuff                         = Spell(7384),
  Dreadnaught                           = Spell(262150),
  ExecutionersPrecisionBuff             = Spell(242188),
  Execute                               = MultiSpell(163201, 281000),
  Overpower                             = Spell(7384),
  SweepingStrikesBuff                   = Spell(260708),
  TestofMight                           = Spell(275529),
  TestofMightBuff                       = Spell(275540),
  DeepWoundsDebuff                      = Spell(262115),
  SuddenDeathBuff                       = Spell(52437),
  StoneHeartBuff                        = Spell(225947),
  SweepingStrikes                       = Spell(260708),
  Whirlwind                             = Spell(1680),
  FervorofBattle                        = Spell(202316),
  Rend                                  = Spell(772),
  RendDebuff                            = Spell(772),
  AngerManagement                       = Spell(152278),
  SeismicWave                           = Spell(277639),
  Charge                                = Spell(100),
  HeroicLeap                            = Spell(6544),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Avatar                                = Spell(107574),
  Massacre                              = Spell(281001),
  Pummel                                = Spell(6552),
  IntimidatingShout                     = Spell(5246),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
  BloodoftheEnemy                       = Spell(297108),
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
  SeethingRageBuff                      = Spell(297126),
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

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local InExecuteRange;
local NumTargetsInMelee;

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

local function Precombat()
  if Everyone.TargetIsValid() then
    -- memory_of_lucid_dreams,if=talent.fervor_of_battle.enabled|!talent.fervor_of_battle.enabled&target.time_to_die>150
    if S.MemoryofLucidDreams:IsCastableP() and (S.FervorofBattle:IsAvailable() or not S.FervorofBattle:IsAvailable() and Target:TimeToDie() > 150) then
      if HR.Cast(S.MemoryofLucidDreams) then return "memory_of_lucid_dreams"; end
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
  ExecuteThreshold = 20 + 15 * num(S.Massacre:IsAvailable())
  TargetInExecuteRange = Target:HealthPercentage() < ExecuteThreshold
  NumTargetsInMelee = Cache.EnemiesCount[8]
  -- SmashSpell = if  S.ColossusSmash TODO: support warbreaker

  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end

  if Everyone.TargetIsValid() then
    if S.Charge:IsReadyP() and S.Charge:ChargesP() >= 1 then
      if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge, nil, 25) then return "charge 351"; end
    end

    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = DamageCooldowns(); if ShouldReturn then return ShouldReturn; end

    -- ROUGH PRIORITY
    --  Skullsplitter if you're not about to cap rage. Skull splitter generates 20 (40 w/ lucid up) rage. Auto attacks generate 25 (* 1.3), also consider that talent. need to have rage generation accounted for?
    --  Look for colossus smash targets.
    --  Use bladestorm if all the conditions are met (AOE vs ST split out)
    --  Put cleave on CD if there are 3+ targets. We don't cleave on two targets.
    --  Put sweeping strikes on CD if there are 2+ targets. 
    --  Look for execute targets.
    --  Put deep wounds on as many targets as possible that will live the full 6s duration. Things that cause deep wounds: mortal strike, execute, bladestorm
    --  Determine if it's a good time to bladestorm.
    --  Handle mortalstrike/whirlwind/overpower/slam priority
    -- TODO: handle lucid dreams doubling, handle autoattack wastage

    -- notes: don't execute below rage needed for cleave on aoe?
    -- TODO: do we hold this for test of might, bladestorm, or smash? probably. fix this later.
    if S.SweepingStrikes:IsCastableP("Melee") and NumTargetsInMelee >= 2 and Target:TimeToDie() > 10 then
      if HR.CastSuggested(S.SweepingStrikes) then return "Sweeping Strikes"; end
    end

    if S.Skullsplitter:IsCastableP("Melee") and Player:Rage() <= 55 and Player:BuffDownP(S.MemoryofLucidDreams) then
      if HR.Cast(S.Skullsplitter) then return "Skullsplitter"; end
    end

    -- for all targets, if there are any that will live >10s, colossus smash or warbreaker them. 
    --TODO: prio targets in execute range with target_if
    if Target:TimeToDie() > 10 then
      if S.Warbreaker:IsCastableP() then
        if HR.CastRightSuggested(S.Warbreaker) then return "Warbreaker"; end
      end
      if S.ColossusSmash:IsCastableP() then
        if HR.CastRightSuggested(S.ColossusSmash) then return "Colossus Smash"; end
      end
    end

    if S.Bladestorm:IsCastableP() and Player:BuffDownP(S.SweepingStrikesBuff) and Player:BuffRemainsP(S.TestofMightBuff) > 3 and NumTargetsInMelee >= 2 then
      if HR.Cast(S.Bladestorm, true, nil, 8) then return "AOE Bladestorm"; end
    end
    if S.Bladestorm:IsCastableP() and (S.MortalStrike:CooldownRemainsP() > 1 or TargetInExecuteRange) and Player:BuffDownP(S.SweepingStrikesBuff) and Player:BuffDownP(S.MemoryofLucidDreams) and Target:DebuffDownP(S.ColossusSmashDebuff) and Player:BuffP(S.TestofMightBuff) and Player:Rage() < 30 then
      if HR.Cast(S.Bladestorm, true, nil, 8) then return "ST Bladestorm"; end
    end

    if (S.Cleave:IsCastableP("Melee") or S.Cleave:CooldownRemainsP() < 0.2) and NumTargetsInMelee >= 3 then
      if HR.Cast(S.Cleave) then return "Cleave"; end
    end

    -- for all targets, if there are any in execute range, do that.
    -- TODO: loop over all targets and check these
    if TargetInExecuteRange then
      if NumTargetsInMelee == 1 and S.Slam:IsCastableP() and Player:BuffP(S.CrushingAssaultBuff) and Player:BuffDownP(S.MemoryofLucidDreams) and Player:Rage() < 68 then
        if HR.Cast(S.Slam) then return "Execute Phase: Free Slam"; end
      end
      -- TODO: put target_if selectors here and later sector
      -- TODO: put a filter here on 40 rage? (DONE, check and see)
      if S.Overpower:IsCastableP() and Player:Rage() < 40 then
        if HR.Cast(S.Overpower) then return "Execute Phase: Overpower due to sub-40 Rage"; end
      end
      if S.Execute:IsCastableP() and (Player:BuffP(S.MemoryofLucidDreams) or Player:BuffP(S.TestofMightBuff) or Target:DebuffP(S.ColossusSmashDebuff)) and (Player:Rage() > 40 or Player:BuffRemainsP(S.TestofMightBuff) < 2) then
        if HR.Cast(S.Execute) then return "Execute Phase: Buffed Full Rage Execute or Buffed Execute at end of TOM window"; end
      end
      if S.Overpower:IsCastableP() then
        if HR.Cast(S.Overpower) then return "Execute Phase: Overpower"; end
      end

      if HR.Cast(S.Execute) then return "Execute Phase: Low Rage Filler Execute"; end
    end

    -- CORE/FILLER LOOP
    if NumTargetsInMelee >= 2 then
      
      -- TODO: make this a target_if selector to spread deep wounds
      if (S.MortalStrike:IsReadyP("Melee") or S.MortalStrike:CooldownRemainsP() < 0.2) and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2 and not S.Cleave:IsAvailable() then
        if HR.Cast(S.MortalStrike) then return "Mortal Strike on AOE to spread Deep Wounds (no cleave talent)"; end
      end
      if S.Whirlwind:IsReadyP("Melee") and (Target:DebuffP(S.ColossusSmashDebuff) or (Player:BuffP(S.CrushingAssaultBuff) and S.FervorofBattle:IsAvailable())) and (Player:Rage() > 20 + (30 - 20*num(Player:BuffRemainsP(S.CrushingAssaultBuff)))) then
        if HR.Cast(S.Whirlwind) then return "Prio Whirlwind"; end
      end
      if S.Overpower:IsCastableP("Melee") and Player:Rage() < 68 then
        if HR.Cast(S.Overpower) then return "Overpower"; end
      end
      if S.Whirlwind:IsReadyP("Melee") and Player:Rage() > 60 then
        if HR.Cast(S.Whirlwind) then return "Whirlwind as Rage Dump"; end
      end
      -- note: the overpower line was here, but moved it up for testing
      --if S.Overpower:IsCastableP("Melee") then
      --  if HR.Cast(S.Overpower) then return "Overpower"; end
      --end
      -- TODO: is this correct? do you want to burn rage here?
      if S.Whirlwind:IsReadyP("Melee") then
        if HR.Cast(S.Whirlwind) then return "Filler"; end
      end
    end

    if NumTargetsInMelee < 2 then
      if S.Overpower:IsCastableP("Melee") and (Target:DebuffP(S.DeepWoundsDebuff) and Player:Rage() < 70 and Player:BuffDownP(S.MemoryofLucidDreams) and Target:DebuffDownP(S.ColossusSmashDebuff)) then
        if HR.Cast(S.Overpower) then return "ST Overpower"; end
      end
      if S.MortalStrike:IsReadyP("Melee") or S.MortalStrike:CooldownRemainsP() < 0.2 then
        if HR.Cast(S.MortalStrike) then return "ST Mortal Strike"; end
      end
      if S.Whirlwind:IsReadyP("Melee") then 
        if S.FervorofBattle:IsAvailable() then
          if (Player:BuffP(S.MemoryofLucidDreams) or Target:DebuffP(S.ColossusSmashDebuff)) and (Player:Rage() > 30 + (30 - 20*num(Player:BuffRemainsP(S.CrushingAssaultBuff))))  then
            if HR.Cast(S.Whirlwind) then return "ST Whirlwind w/ Fervor"; end
          end
        else
          if (Player:BuffP(S.MemoryofLucidDreams) or Player:Rage() > 89) and Target:DebuffP(S.ColossusSmashDebuff) and Player:BuffDownP(S.TestofMightBuff) then
            if HR.Cast(S.Whirlwind) then return "ST Whirlwind w/o Fervor to Dump Rage in Smash Window"; end
          end
        end
      end
      if S.Slam:IsReadyP("Melee") and (Player:BuffP(S.MemoryofLucidDreams) or Target:DebuffP(S.ColossusSmashDebuff)) and not S.FervorofBattle:IsAvailable() then
        if HR.Cast(S.Slam) then return "ST Slam w/o Fervor"; end
      end
      if S.Overpower:IsCastableP("Melee") then
        if HR.Cast(S.Overpower) then return "ST Overpower usage on cooldown"; end
      end
      -- TODO: are these correct? do you want to burn rage here?
      if S.Whirlwind:IsReadyP("Melee") and S.FervorofBattle:IsAvailable() and (Player:BuffP(S.TestofMightBuff) or Target:DebuffDownP(S.ColossusSmashDebuff) and Player:BuffDownP(S.TestofMightBuff) and Player:Rage() > 60) then
        if HR.Cast(S.Whirlwind) then return "ST Whirlwind w/ Fervor outside of smash window"; end
      end
      if S.Slam:IsReadyP("Melee") and not S.FervorofBattle:IsAvailable() then
        if HR.Cast(S.Slam) then return "ST Slam w/o Fervor outside of smash window"; end
      end
    end
  end
end

local function Init()
  HL.RegisterNucleusAbility(152277, 8, 6)               -- Ravager
  HL.RegisterNucleusAbility(227847, 8, 6)               -- Bladestorm
  HL.RegisterNucleusAbility(845, 8, 6)                  -- Cleave
  HL.RegisterNucleusAbility(1680, 8, 6)                 -- Whirlwind
end

HR.SetAPL(71, APL, Init)

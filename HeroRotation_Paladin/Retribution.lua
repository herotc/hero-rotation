--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
local HDBC       = HeroDBC
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
local AE         = HDBC.DBC.AzeriteEssences
local AESpellIDs = HDBC.DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Paladin then Spell.Paladin = {} end
Spell.Paladin.Retribution = {
  ArcaneTorrent                         = Spell(50613),
  WakeofAshes                           = Spell(255937),
  AvengingWrathBuff                     = Spell(31884),
  AvengingWrathCritBuff                 = Spell(294027),
  CrusadeBuff                           = Spell(231895),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  ShieldofVengeance                     = Spell(184662),
  AvengingWrath                         = Spell(31884),
  InquisitionBuff                       = Spell(84963),
  Inquisition                           = Spell(84963),
  Crusade                               = Spell(231895),
  RighteousVerdict                      = Spell(267610),
  ExecutionSentence                     = Spell(343527),
  DivineStorm                           = Spell(53385),
  DivinePurpose                         = Spell(223817),
  DivinePurposeBuff                     = Spell(223819),
  EmpyreanPowerBuff                     = Spell(286393),
  JudgmentDebuff                        = Spell(197277),
  TemplarsVerdict                       = Spell(85256),
  HammerofWrath                         = Spell(24275),
  BladeofJustice                        = Spell(184575),
  Judgment                              = Spell(20271),
  Consecration                          = Spell(26573),
  CrusaderStrike                        = Spell(35395),
  Rebuke                                = Spell(96231),
  HammerofJustice                       = Spell(853),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  SeethingRageBuff                      = Spell(297126),
  RazorCoralDebuff                      = Spell(303568)
};
local S = Spell.Paladin.Retribution;

-- Items
if not Item.Paladin then Item.Paladin = {} end
Item.Paladin.Retribution = {
  PotionofFocusedResolve           = Item(168506),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14})
};
local I = Item.Paladin.Retribution;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemyCount30y, EnemyCount8y

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Retribution = HR.GUISettings.APL.Paladin.Retribution
};

local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
};

-- Variables
local VarDsCastable = 0;
local VarHow = 0;
local PlayerGCD;

HL:RegisterForEvent(function()
  VarDsCastable = 0
  VarHow = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {30, 8, 5}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    Player:GetEnemiesInRange(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function IsSpellComingOffCooldown(spell)
  return spell:IsAvailable() and spell:CooldownRemains(true) - HL.Latency() < Player:GCDRemains()
end

local function IsCastableNext(spell)
  return spell:IsCastable() or IsSpellComingOffCooldown(spell)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_strength 4"; end
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquippedAndReady() then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.EssenceDisplayStyle) then return "azsharas_font_of_power 5"; end
    end
    -- arcane_torrent,if=!talent.wake_of_ashes.enabled
    if IsCastableNext(S.ArcaneTorrent) and HR.CDsON() and (not S.WakeofAshes:IsAvailable()) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil) then return "arcane_torrent 6"; end
    end
  end
end

local function Cooldowns()
  -- potion,if=(cooldown.guardian_of_azeroth.remains>90|!essence.condensed_lifeforce.major)&(buff.bloodlust.react|buff.avenging_wrath.up&buff.avenging_wrath.remains>18|buff.crusade.up&buff.crusade.remains<25)
  if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and ((S.GuardianofAzeroth:CooldownRemains() > 90 or not Spell:MajorEssenceEnabled(AE.CondensedLifeForce)) and (Player:HasHeroism() or Player:BuffUp(S.AvengingWrathBuff) and Player:BuffRemains(S.AvengingWrathBuff) > 18 or Player:BuffUp(S.CrusadeBuff) and Player:BuffRemains(S.CrusadeBuff) < 25)) then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_strength 10"; end
  end
  -- lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
  if IsCastableNext(S.LightsJudgment) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil) then return "lights_judgment 18"; end
  end
  -- fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
  if IsCastableNext(S.Fireblood) and (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 22"; end
  end
  -- shield_of_vengeance,if=buff.seething_rage.down&buff.memory_of_lucid_dreams.down
  if IsCastableNext(S.ShieldofVengeance) and Settings.Retribution.ShieldofVengeance and (Player:BuffDown(S.SeethingRageBuff) and Player:BuffDown(S.MemoryofLucidDreams)) then
    if HR.CastLeft(S.ShieldofVengeance) then return "shield_of_vengeance 30"; end
  end
  -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|(buff.avenging_wrath.remains>=20|buff.crusade.stack=10&buff.crusade.remains>15)&(cooldown.guardian_of_azeroth.remains>90|target.time_to_die<30|!essence.condensed_lifeforce.major)
  if I.AshvanesRazorCoral:IsEquippedAndReady() and Settings.Commons.UseTrinkets and (Target:DebuffDown(S.RazorCoralDebuff) or (Player:BuffRemains(S.AvengingWrath) >= 20 or Player:BuffStack(S.CrusadeBuff) == 10 and Player:BuffRemains(S.CrusadeBuff) > 15) and (S.GuardianofAzeroth:CooldownRemains() > 90 or Target:TimeToDie() < 30 or not Spell:MajorEssenceEnabled(AE.CondensedLifeForce))) then
    if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral"; end
  end
  -- the_unbound_force,if=time<=2|buff.reckless_force.up
  if IsCastableNext(S.TheUnboundForce) and (HL.CombatTime() <= 2 or Player:BuffUp(S.RecklessForceBuff)) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force"; end
  end
  -- blood_of_the_enemy,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
  if IsCastableNext(S.BloodoftheEnemy) and (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy"; end
  end
  -- guardian_of_azeroth,if=!talent.crusade.enabled&(cooldown.avenging_wrath.remains<5&holy_power>=3&(buff.inquisition.up|!talent.inquisition.enabled)|cooldown.avenging_wrath.remains>=45)|(talent.crusade.enabled&cooldown.crusade.remains<gcd&holy_power>=4|holy_power>=3&time<10&talent.wake_of_ashes.enabled|cooldown.crusade.remains>=45)
  if IsCastableNext(S.GuardianofAzeroth) and (not S.Crusade:IsAvailable() and (S.AvengingWrath:CooldownRemains() < 5 and Player:HolyPower() >= 3 and (Player:BuffUp(S.InquisitionBuff) or not S.Inquisition:IsAvailable()) or S.AvengingWrath:CooldownRemains() >= 45) or (S.Crusade:IsAvailable() and S.Crusade:CooldownRemains() < PlayerGCD and Player:HolyPower() >= 4 or Player:HolyPower() >= 3 and HL.CombatTime() < 10 and S.WakeofAshes:IsAvailable() or S.Crusade:CooldownRemains() >= 45)) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
  end
  -- worldvein_resonance,if=cooldown.avenging_wrath.remains<gcd&holy_power>=3|talent.crusade.enabled&cooldown.crusade.remains<gcd&holy_power>=4|cooldown.avenging_wrath.remains>=45|cooldown.crusade.remains>=45
  if IsCastableNext(S.WorldveinResonance) and (S.AvengingWrath:CooldownRemains() < PlayerGCD and Player:HolyPower() >= 3 or S.Crusade:IsAvailable() and S.Crusade:CooldownRemains() < PlayerGCD and Player:HolyPower() >= 4 or S.AvengingWrath:CooldownRemains() >= 45 or S.Crusade:CooldownRemains() >= 45) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
  end
  -- focused_azerite_beam,if=(!raid_event.adds.exists|raid_event.adds.in>30|spell_targets.divine_storm>=2)&!(buff.avenging_wrath.up|buff.crusade.up)&(cooldown.blade_of_justice.remains>gcd*3&cooldown.judgment.remains>gcd*3)
  if IsCastableNext(S.FocusedAzeriteBeam) and ((EnemyCount8y >= 2 or Settings.Retribution.UseFABST) and not (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff)) and (S.BladeofJustice:CooldownRemains() > PlayerGCD * 3 and S.Judgment:CooldownRemains() > PlayerGCD * 3)) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
  end
  -- memory_of_lucid_dreams,if=(buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10)&holy_power<=3
  if IsCastableNext(S.MemoryofLucidDreams) and ((Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10) and Player:HolyPower() <= 3) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
  end
  -- purifying_blast,if=(!raid_event.adds.exists|raid_event.adds.in>30|spell_targets.divine_storm>=2)
  if IsCastableNext(S.PurifyingBlast) and (EnemyCount8y >= 2) then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast"; end
  end
  -- use_item,effect_name=cyclotronic_blast,if=!(buff.avenging_wrath.up|buff.crusade.up)&(cooldown.blade_of_justice.remains>gcd*3&cooldown.judgment.remains>gcd*3)
  if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (not (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff)) and (S.BladeofJustice:CooldownRemains() > PlayerGCD * 3 and S.Judgment:CooldownRemains() > PlayerGCD * 3)) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "cyclotronic_blast"; end
  end
  -- avenging_wrath,if=(!talent.inquisition.enabled|buff.inquisition.up)&holy_power>=3
  if IsCastableNext(S.AvengingWrath) and ((not S.Inquisition:IsAvailable() or Player:BuffUp(S.InquisitionBuff)) and Player:HolyPower() >= 3) then
    if HR.Cast(S.AvengingWrath, Settings.Retribution.GCDasOffGCD.AvengingWrath) then return "avenging_wrath 32"; end
  end
  -- crusade,if=holy_power>=4|holy_power>=3&time<10&talent.wake_of_ashes.enabled
  if IsCastableNext(S.Crusade) and (Player:HolyPower() >= 4 or Player:HolyPower() >= 3 and HL.CombatTime() < 10 and S.WakeofAshes:IsAvailable()) then
    if HR.Cast(S.Crusade, Settings.Retribution.GCDasOffGCD.Crusade) then return "crusade 38"; end
  end
end

local function Finishers()
  -- variable,name=wings_pool,value=!equipped.169314&(!talent.crusade.enabled&cooldown.avenging_wrath.remains>gcd*3|cooldown.crusade.remains>gcd*3)|equipped.169314&(!talent.crusade.enabled&cooldown.avenging_wrath.remains>gcd*6|cooldown.crusade.remains>gcd*6)
  if (true) then
    VarWingsPool = num(
      Settings.Retribution.AllowDelayedAW or
      not I.AzsharasFontofPower:IsEquipped() and (not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemains() > PlayerGCD * 3 or S.Crusade:CooldownRemains() > PlayerGCD * 3) or
      I.AzsharasFontofPower:IsEquipped() and (not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemains() > PlayerGCD * 6 or S.Crusade:CooldownRemains() > PlayerGCD * 6)
    )
  end
  -- variable,name=ds_castable,value=spell_targets.divine_storm>=2&!talent.righteous_verdict.enabled|spell_targets.divine_storm>=3&talent.righteous_verdict.enabled|buff.empyrean_power.up&debuff.judgment.down&buff.divine_purpose.down&buff.avenging_wrath_autocrit.down
  if (true) then
    VarDsCastable = (
      num(
        EnemyCount8y >= 2 and not S.RighteousVerdict:IsAvailable() or
        EnemyCount8y >= 3 and S.RighteousVerdict:IsAvailable() or
        Player:BuffUp(S.EmpyreanPowerBuff) and Target:DebuffDown(S.JudgmentDebuff) and Player:BuffDown(S.DivinePurposeBuff) and Player:BuffDown(S.AvengingWrathCritBuff)
      )
    )
  end
  -- inquisition,if=buff.avenging_wrath.down&(buff.inquisition.down|buff.inquisition.remains<8&holy_power>=3|talent.execution_sentence.enabled&cooldown.execution_sentence.remains<10&buff.inquisition.remains<15|cooldown.avenging_wrath.remains<15&buff.inquisition.remains<20&holy_power>=3)
  if S.Inquisition:IsReady() and (Player:BuffDown(S.InquisitionBuff) and (Player:BuffDown(S.InquisitionBuff) or Player:BuffRemains(S.InquisitionBuff) < 8 and Player:HolyPower() >= 3 or S.ExecutionSentence:IsAvailable() and S.ExecutionSentence:CooldownRemains() < 10 and Player:BuffRemains(S.InquisitionBuff) < 15 or S.AvengingWrath:CooldownRemains() < 15 and Player:BuffRemains(S.InquisitionBuff) < 20 and Player:HolyPower() >= 3)) then
    if HR.Cast(S.Inquisition) then return "inquisition 46"; end
  end
  -- execution_sentence,if=spell_targets.divine_storm<=2&(!talent.crusade.enabled&cooldown.avenging_wrath.remains>10|talent.crusade.enabled&buff.crusade.down&cooldown.crusade.remains>10|buff.crusade.stack>=7)
  if (
    S.ExecutionSentence:IsReady() and
    Target:Health() > S.TemplarsVerdict:Damage() and
    Target:TimeToDie() > 8 and
    (
      EnemyCount8y <= 2 and
      (
        not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemains() > 10 or
        S.Crusade:IsAvailable() and Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 10 or
        Player:BuffStack(S.CrusadeBuff) >= 7
      )
    )
  ) then
    if HR.Cast(S.ExecutionSentence, nil, nil) then return "execution_sentence 62"; end
  end
  -- divine_storm,if=variable.ds_castable&variable.wings_pool&((!talent.execution_sentence.enabled|(spell_targets.divine_storm>=2|cooldown.execution_sentence.remains>gcd*2))|(cooldown.avenging_wrath.remains>gcd*3&cooldown.avenging_wrath.remains<10|cooldown.crusade.remains>gcd*3&cooldown.crusade.remains<10|buff.crusade.up&buff.crusade.stack<10))
  if (
    S.DivineStorm:IsReady() and
    (
      bool(VarDsCastable) and
      bool(VarWingsPool) and
      (
        (
          not S.ExecutionSentence:IsAvailable() or
          (
            EnemyCount8y >= 2 or
            S.ExecutionSentence:CooldownRemains() > PlayerGCD * 2
          )
        ) or
        (
          S.AvengingWrath:CooldownRemains() > PlayerGCD * 3 and S.AvengingWrath:CooldownRemains() < 10 or
          S.Crusade:CooldownRemains() > PlayerGCD * 3 and S.Crusade:CooldownRemains() < 10 or
          Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10)
        )
      )
  ) then
    if HR.Cast(S.DivineStorm, nil, nil) then return "divine_storm 74"; end
  end
  -- templars_verdict,if=variable.wings_pool&(!talent.execution_sentence.enabled|cooldown.execution_sentence.remains>gcd*2|cooldown.avenging_wrath.remains>gcd*3&cooldown.avenging_wrath.remains<10|cooldown.crusade.remains>gcd*3&cooldown.crusade.remains<10|buff.crusade.up&buff.crusade.stack<10)
  if S.TemplarsVerdict:IsReady() and (bool(VarWingsPool) and (not S.ExecutionSentence:IsAvailable() or S.ExecutionSentence:CooldownRemains() > PlayerGCD * 2 or S.AvengingWrath:CooldownRemains() > PlayerGCD * 3 and S.AvengingWrath:CooldownRemains() < 10 or S.Crusade:CooldownRemains() > PlayerGCD * 3 and S.Crusade:CooldownRemains() < 10 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10)) then
    if HR.Cast(S.TemplarsVerdict, nil, nil) then return "templars_verdict 92"; end
  end
  -- templars_verdict fallback, in case the user is saving AW/Crusade/ExecutionSentence
  if S.TemplarsVerdict:IsReady() and Settings.Retribution.AllowDelayedAW then
    if HR.Cast(S.TemplarsVerdict, nil, nil) then return "templars_verdict 93"; end
  end
end

local function Generators()
  -- variable,name=HoW,value=(!talent.hammer_of_wrath.enabled|target.health.pct>=20&!(buff.avenging_wrath.up|buff.crusade.up))
  if (true) then
    VarHow = num((not S.HammerofWrath:IsAvailable() or Target:HealthPercentage() >= 20 and not (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff))))
  end
  -- call_action_list,name=finishers,if=holy_power>=5|buff.memory_of_lucid_dreams.up|buff.seething_rage.up|talent.inquisition.enabled&buff.inquisition.down&holy_power>=3
  if (Player:HolyPower() >= 5 or Player:BuffUp(S.MemoryofLucidDreams) or Player:BuffUp(S.SeethingRageBuff) or S.Inquisition:IsAvailable() and Player:BuffDown(S.InquisitionBuff) and Player:HolyPower() >= 3) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15|spell_targets.wake_of_ashes>=2)&(holy_power<=0|holy_power=1&cooldown.blade_of_justice.remains>gcd)&(cooldown.avenging_wrath.remains>10|talent.crusade.enabled&cooldown.crusade.remains>10)
  if IsCastableNext(S.WakeofAshes) and ((not (EnemyCount30y > 1) or EnemyCount8y >= 2) and (Player:HolyPower() <= 0 or Player:HolyPower() == 1 and S.BladeofJustice:CooldownRemains() > PlayerGCD) and (S.AvengingWrath:CooldownRemains() > 10 or S.Crusade:IsAvailable() and S.Crusade:CooldownRemains() > 10)) then
    if HR.Cast(S.WakeofAshes, nil, nil) then return "wake_of_ashes 116"; end
  end
  -- blade_of_justice,if=holy_power<=2|(holy_power=3&(cooldown.hammer_of_wrath.remains>gcd*2|variable.HoW))
  if (
    IsCastableNext(S.BladeofJustice) and
    (
      Player:HolyPower() <= 2 or
      (Player:HolyPower() == 3 and (S.HammerofWrath:CooldownRemains() > PlayerGCD * 2 or bool(VarHow)))
    )
  ) then
    if HR.Cast(S.BladeofJustice, nil, nil) then return "blade_of_justice 122"; end
  end
  -- judgment,if=holy_power<=2|(holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|variable.HoW))
  if IsCastableNext(S.Judgment) and (Player:HolyPower() <= 2 or (Player:HolyPower() <= 4 and (S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 or bool(VarHow)))) then
    if HR.Cast(S.Judgment, nil, nil) then return "judgment 128"; end
  end
  -- hammer_of_wrath,if=holy_power<=4
  if S.HammerofWrath:IsUsable() and S.HammerofWrath:IsReady() and (Player:HolyPower() <= 4) then
    if HR.Cast(S.HammerofWrath, nil, nil) then return "hammer_of_wrath 134"; end
  end
  -- consecration,if=holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2
  if (
    IsCastableNext(S.Consecration) and
    (
      Player:HolyPower() <= 2 or
      Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 or
      Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 and S.Judgment:CooldownRemains() > PlayerGCD * 2
    )
  ) then
    if HR.Cast(S.Consecration, nil, nil) then return "consecration 136"; end
  end
  -- call_action_list,name=finishers,if=talent.hammer_of_wrath.enabled&target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up
  if (S.HammerofWrath:IsAvailable() and Target:HealthPercentage() <= 20 or Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff)) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2&cooldown.consecration.remains>gcd*2)
  if IsCastableNext(S.CrusaderStrike) and (S.CrusaderStrike:ChargesFractional() >= 1.75 and (Player:HolyPower() <= 2 or Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 and S.Judgment:CooldownRemains() > PlayerGCD * 2 and S.Consecration:CooldownRemains() > PlayerGCD * 2)) then
    if HR.Cast(S.CrusaderStrike, nil, nil) then return "crusader_strike 152"; end
  end
  -- call_action_list,name=finishers
  if (true) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- concentrated_flame
  if IsCastableNext(S.ConcentratedFlame) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame"; end
  end
  -- reaping_flames
  if (true) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- crusader_strike,if=holy_power<=4
  if IsCastableNext(S.CrusaderStrike) and (Player:HolyPower() <= 4) then
    if HR.Cast(S.CrusaderStrike, nil, nil) then return "crusader_strike 166"; end
  end
  -- arcane_torrent,if=holy_power<=4
  if IsCastableNext(S.ArcaneTorrent) and HR.CDsON() and (Player:HolyPower() <= 4) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil) then return "arcane_torrent 168"; end
  end
end

function AoEToggleEnemiesUpdate ()
  if HR.AoEON() then
    EnemyCount30y = table.getn(Player:GetEnemiesInRange(30))
    EnemyCount8y = table.getn(Player:GetEnemiesInRange(8))
  end
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  AoEToggleEnemiesUpdate()
  PlayerGCD = Player:GCD()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=generators
    if (true) then
      local ShouldReturn = Generators(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

HR.SetAPL(70, APL)

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
  ExecutionSentence                     = Spell(267798),
  DivineStorm                           = Spell(53385),
  DivinePurpose                         = Spell(223817),
  DivinePurposeBuff                     = Spell(223819),
  EmpyreanPowerBuff                     = Spell(286393),
  JudgmentDebuff                        = Spell(197277),
  TemplarsVerdict                       = Spell(85256),
  HammerofWrath                         = Spell(24275),
  BladeofJustice                        = Spell(184575),
  Judgment                              = Spell(20271),
  Consecration                          = Spell(205228),
  CrusaderStrike                        = Spell(35395),
  Rebuke                                = Spell(96231),
  HammerofJustice                       = Spell(853),
  CyclotronicBlast                      = Spell(167672),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
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
  AshvanesRazorCoral               = Item(169311),
  AzsharasFontofPower              = Item(169314),
  PocketsizedComputationDevice     = Item(167555)
};
local I = Item.Paladin.Retribution;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

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

HL:RegisterForEvent(function()
  VarDsCastable = 0
  VarHow = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {30, 8, 5}
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

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns, Finishers, Generators
  local PlayerGCD = Player:GCD()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_strength 4"; end
      end
      -- arcane_torrent,if=!talent.wake_of_ashes.enabled
      if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (not S.WakeofAshes:IsAvailable()) then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 6"; end
      end
    end
  end
  Cooldowns = function()
    -- potion,if=(cooldown.guardian_of_azeroth.remains>90|!essence.condensed_lifeforce.major)&(buff.bloodlust.react|buff.avenging_wrath.up&buff.avenging_wrath.remains>18|buff.crusade.up&buff.crusade.remains<25)
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and ((S.GuardianofAzeroth:CooldownRemainsP() > 90 or not S.GuardianofAzeroth:IsAvailable()) and (Player:HasHeroism() or Player:BuffP(S.AvengingWrathBuff) and Player:BuffRemainsP(S.AvengingWrathBuff) > 18 or Player:BuffP(S.CrusadeBuff) and Player:BuffRemainsP(S.CrusadeBuff) < 25)) then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_strength 10"; end
    end
    -- lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
    if S.LightsJudgment:IsCastableP() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 18"; end
    end
    -- fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
    if S.Fireblood:IsCastableP() and (Player:BuffP(S.AvengingWrathBuff) or Player:BuffP(S.CrusadeBuff) and Player:BuffStackP(S.CrusadeBuff) == 10) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 22"; end
    end
    -- shield_of_vengeance,if=buff.seething_rage.down&buff.memory_of_lucid_dreams.down
    if S.ShieldofVengeance:IsCastableP() and Settings.Retribution.ShieldofVengeance and (Player:BuffDownP(S.SeethingRageBuff) and Player:BuffDownP(S.MemoryofLucidDreams)) then
      if HR.CastLeft(S.ShieldofVengeance) then return "shield_of_vengeance 30"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|(buff.avenging_wrath.remains>=20|buff.crusade.stack=10&buff.crusade.remains>15)&(cooldown.guardian_of_azeroth.remains>90|target.time_to_die<30|!essence.condensed_lifeforce.major)
    if I.AshvanesRazorCoral:IsEquipped() and I.AshvanesRazorCoral:IsReady() and (Target:DebuffDownP(S.RazorCoralDebuff) or (Player:BuffRemainsP(S.AvengingWrath) >= 20 or Player:BuffStackP(S.CrusadeBuff) == 10 and Player:BuffRemainsP(S.CrusadeBuff) > 15) and (S.GuardianofAzeroth:CooldownRemainsP() > 90 or Target:TimeToDie() < 30 or not S.GuardianofAzeroth:IsAvailable())) then
      if HR.CastSuggested(I.AshvanesRazorCoral) then reutrn "ashvanes_razor_coral"; end
    end
    -- the_unbound_force,if=time<=2|buff.reckless_force.up
    if S.TheUnboundForce:IsCastableP() and (HL.CombatTime() <= 2 or Player:BuffP(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, Settings.Retribution.GCDasOffGCD.Essences) then return "the_unbound_force"; end
    end
    -- blood_of_the_enemy,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.AvengingWrathBuff) or Player:BuffP(S.CrusadeBuff) and Player:BuffStackP(S.CrusadeBuff) == 10) then
      if HR.Cast(S.BloodoftheEnemy, Settings.Retribution.GCDasOffGCD.Essences) then return "blood_of_the_enemy"; end
    end
    -- guardian_of_azeroth,if=!talent.crusade.enabled&(cooldown.avenging_wrath.remains<5&holy_power>=3&(buff.inquisition.up|!talent.inquisition.enabled)|cooldown.avenging_wrath.remains>=45)|(talent.crusade.enabled&cooldown.crusade.remains<gcd&holy_power>=4|holy_power>=3&time<10&talent.wake_of_ashes.enabled|cooldown.crusade.remains>=45)
    if S.GuardianofAzeroth:IsCastableP() and (not S.Crusade:IsAvailable() and (S.AvengingWrath:CooldownRemainsP() < 5 and Player:HolyPower() >= 3 and (Player:BuffP(S.InquisitionBuff) or not S.Inquisition:IsAvailable()) or S.AvengingWrath:CooldownRemainsP() >= 45) or (S.Crusade:IsAvailable() and S.Crusade:CooldownRemainsP() < PlayerGCD and Player:HolyPower() >= 4 or Player:HolyPower() >= 3 and HL.CombatTime() < 10 and S.WakeofAshes:IsAvailable() or S.Crusade:CooldownRemainsP() >= 45)) then
      if HR.Cast(S.GuardianofAzeroth, Settings.Retribution.GCDasOffGCD.Essences) then return "guardian_of_azeroth"; end
    end
    -- worldvein_resonance,if=cooldown.avenging_wrath.remains<gcd&holy_power>=3|cooldown.crusade.remains<gcd&holy_power>=4|cooldown.avenging_wrath.remains>=45|cooldown.crusade.remains>=45
    if S.WorldveinResonance:IsCastableP() and (S.AvengingWrath:CooldownRemainsP() < PlayerGCD and Player:HolyPower() >= 3 or S.Crusade:CooldownRemainsP() < PlayerGCD and Player:HolyPower() >= 4 or S.AvengingWrath:CooldownRemainsP() >= 45 or S.Crusade:CooldownRemainsP() >= 45) then
      if HR.Cast(S.WorldveinResonance, Settings.Retribution.GCDasOffGCD.Essences) then return "worldvein_resonance"; end
    end
    -- focused_azerite_beam,if=(!raid_event.adds.exists|raid_event.adds.in>30|spell_targets.divine_storm>=2)&(buff.avenging_wrath.down|talent.crusade.enabled&buff.crusade.down)&(cooldown.blade_of_justice.remains>gcd*3&cooldown.judgment.remains>gcd*3)
    if S.FocusedAzeriteBeam:IsCastableP() and ((Cache.EnemiesCount[8] >= 2) and (Player:BuffDownP(S.AvengingWrathBuff) or S.Crusade:IsAvailable() and Player:BuffDownP(S.CrusadeBuff)) and (S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 3 and S.Judgment:CooldownRemainsP() > PlayerGCD * 3)) then
      if HR.Cast(S.FocusedAzeriteBeam, Settings.Retribution.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- memory_of_lucid_dreams,if=(buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10)&holy_power<=3
    if S.MemoryofLucidDreams:IsCastableP() and ((Player:BuffP(S.AvengingWrathBuff) or Player:BuffP(S.CrusadeBuff) and Player:BuffStackP(S.CrusadeBuff) == 10) and Player:HolyPower() <= 3) then
      if HR.Cast(S.MemoryofLucidDreams, Settings.Retribution.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams"; end
    end
    -- purifying_blast,if=(!raid_event.adds.exists|raid_event.adds.in>30|spell_targets.divine_storm>=2)
    if S.PurifyingBlast:IsCastableP() and (Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.PurifyingBlast, Settings.Retribution.GCDasOffGCD.Essences) then return "purifying_blast"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=(buff.avenging_wrath.down|talent.crusade.enabled&buff.crusade.down)&(cooldown.blade_of_justice.remains>gcd*3&cooldown.judgment.remains>gcd*3)
    if I.PocketsizedComputationDevice:IsEquipped() and I.PocketsizedComputationDevice:IsReady() and S.CyclotronicBlast:IsAvailable() and ((Player:BuffDownP(S.AvengingWrathBuff) or S.Crusade:IsAvailable() and Player:BuffDownP(S.CrusadeBuff)) and (S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 3 and S.Judgment:CooldownRemainsP() > PlayerGCD * 3)) then
      if HR.CastSuggested(I.PocketsizedComputationDevice) then return "cyclotronic_blast"; end
    end
    -- avenging_wrath,if=(!talent.inquisition.enabled|buff.inquisition.up)&holy_power>=3
    if S.AvengingWrath:IsCastableP() and HR.CDsON() and ((not S.Inquisition:IsAvailable() or Player:BuffP(S.InquisitionBuff)) and Player:HolyPower() >= 3) then
      if HR.Cast(S.AvengingWrath, Settings.Retribution.GCDasOffGCD.AvengingWrath) then return "avenging_wrath 32"; end
    end
    -- crusade,if=holy_power>=4|holy_power>=3&time<10&talent.wake_of_ashes.enabled
    if S.Crusade:IsCastableP() and HR.CDsON() and (Player:HolyPower() >= 4 or Player:HolyPower() >= 3 and HL.CombatTime() < 10 and S.WakeofAshes:IsAvailable()) then
      if HR.Cast(S.Crusade, Settings.Retribution.GCDasOffGCD.Crusade) then return "crusade 38"; end
    end
  end
  Finishers = function()
    -- variable,name=wings_pool,value=!equipped.169314&(!talent.crusade.enabled&cooldown.avenging_wrath.remains>gcd*3|cooldown.crusade.remains>gcd*3)|equipped.169314&(!talent.crusade.enabled&cooldown.avenging_wrath.remains>gcd*6|cooldown.crusade.remains>gcd*6)
    if (true) then
      VarWingsPool = num(not I.AzsharasFontofPower:IsEquipped() and (not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemainsP() > PlayerGCD * 3 or S.Crusade:CooldownRemainsP() > PlayerGCD * 3) or I.AzsharasFontofPower:IsEquipped() and (not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemainsP() > PlayerGCD * 6 or S.Crusade:CooldownRemainsP() > PlayerGCD * 6))
    end
    -- variable,name=ds_castable,value=spell_targets.divine_storm>=2&!talent.righteous_verdict.enabled|spell_targets.divine_storm>=3&talent.righteous_verdict.enabled|buff.empyrean_power.up&debuff.judgment.down&buff.divine_purpose.down&buff.avenging_wrath_autocrit.down
    if (true) then
      VarDsCastable = num(Cache.EnemiesCount[8] >= 2 and not S.RighteousVerdict:IsAvailable() or Cache.EnemiesCount[8] >= 3 and S.RighteousVerdict:IsAvailable() or Player:BuffP(S.EmpyreanPowerBuff) and Target:DebuffDownP(S.JudgmentDebuff) and Player:BuffDownP(S.DivinePurposeBuff) and Player:BuffDownP(S.AvengingWrathCritBuff))
    end
    -- inquisition,if=buff.avenging_wrath.down&(buff.inquisition.down|buff.inquisition.remains<8&holy_power>=3|talent.execution_sentence.enabled&cooldown.execution_sentence.remains<10&buff.inquisition.remains<15|cooldown.avenging_wrath.remains<15&buff.inquisition.remains<20&holy_power>=3)
    if S.Inquisition:IsReadyP() and (Player:BuffDownP(S.InquisitionBuff) and (Player:BuffDownP(S.InquisitionBuff) or Player:BuffRemainsP(S.InquisitionBuff) < 8 and Player:HolyPower() >= 3 or S.ExecutionSentence:IsAvailable() and S.ExecutionSentence:CooldownRemainsP() < 10 and Player:BuffRemainsP(S.InquisitionBuff) < 15 or S.AvengingWrath:CooldownRemainsP() < 15 and Player:BuffRemainsP(S.InquisitionBuff) < 20 and Player:HolyPower() >= 3)) then
      if HR.Cast(S.Inquisition) then return "inquisition 46"; end
    end
    -- execution_sentence,if=spell_targets.divine_storm<=2&(!talent.crusade.enabled&cooldown.avenging_wrath.remains>10|talent.crusade.enabled&buff.crusade.down&cooldown.crusade.remains>10|buff.crusade.stack>=7)
    if S.ExecutionSentence:IsReadyP() and (Cache.EnemiesCount[8] <= 2 and (not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemainsP() > 10 or S.Crusade:IsAvailable() and Player:BuffDownP(S.CrusadeBuff) and S.Crusade:CooldownRemainsP() > 10 or Player:BuffStackP(S.CrusadeBuff) >= 7)) then
      if HR.Cast(S.ExecutionSentence) then return "execution_sentence 62"; end
    end
    -- divine_storm,if=variable.ds_castable&variable.wings_pool&((!talent.execution_sentence.enabled|(spell_targets.divine_storm>=2|cooldown.execution_sentence.remains>gcd*2))|(cooldown.avenging_wrath.remains>gcd*3&cooldown.avenging_wrath.remains<10|cooldown.crusade.remains>gcd*3&cooldown.crusade.remains<10|buff.crusade.up&buff.crusade.stack<10))
    if S.DivineStorm:IsReadyP() and (bool(VarDsCastable) and bool(VarWingsPool) and ((not S.ExecutionSentence:IsAvailable() or (Cache.EnemiesCount[8] >= 2 or S.ExecutionSentence:CooldownRemainsP() > PlayerGCD * 2)) or (S.AvengingWrath:CooldownRemainsP() > PlayerGCD * 3 and S.AvengingWrath:CooldownRemainsP() < 10 or S.Crusade:CooldownRemainsP() > PlayerGCD * 3 and S.Crusade:CooldownRemainsP() < 10 or Player:BuffP(S.CrusadeBuff) and Player:BuffStackP(S.CrusadeBuff) < 10))) then
      if HR.Cast(S.DivineStorm) then return "divine_storm 74"; end
    end
    -- templars_verdict,if=variable.wings_pool&(!talent.execution_sentence.enabled|cooldown.execution_sentence.remains>gcd*2|cooldown.avenging_wrath.remains>gcd*3&cooldown.avenging_wrath.remains<10|cooldown.crusade.remains>gcd*3&cooldown.crusade.remains<10|buff.crusade.up&buff.crusade.stack<10)
    if S.TemplarsVerdict:IsReadyP() and (bool(VarWingsPool) and (not S.ExecutionSentence:IsAvailable() or S.ExecutionSentence:CooldownRemainsP() > PlayerGCD * 2 or S.AvengingWrath:CooldownRemainsP() > PlayerGCD * 3 and S.AvengingWrath:CooldownRemainsP() < 10 or S.Crusade:CooldownRemainsP() > PlayerGCD * 3 and S.Crusade:CooldownRemainsP() < 10 or Player:BuffP(S.CrusadeBuff) and Player:BuffStackP(S.CrusadeBuff) < 10)) then
      if HR.Cast(S.TemplarsVerdict) then return "templars_verdict 92"; end
    end
    -- templars_verdict fallback, in case the user is saving AW/Crusade/ExecutionSentence
    if S.TemplarsVerdict:IsReadyP() and (not HR.CDsON()) then
      if HR.Cast(S.TemplarsVerdict) then return "templars_verdict 93"; end
    end
  end
  Generators = function()
    -- variable,name=HoW,value=(!talent.hammer_of_wrath.enabled|target.health.pct>=20&(buff.avenging_wrath.down|talent.crusade.enabled&buff.crusade.down))
    if (true) then
      VarHow = num((not S.HammerofWrath:IsAvailable() or Target:HealthPercentage() >= 20 and (Player:BuffDownP(S.AvengingWrathBuff) or S.Crusade:IsAvailable() and Player:BuffDownP(S.CrusadeBuff))))
    end
    -- call_action_list,name=finishers,if=holy_power>=5|buff.memory_of_lucid_dreams.up|buff.seething_rage.up|buff.inquisition.down&holy_power>=3
    if (Player:HolyPower() >= 5 or Player:BuffP(S.MemoryofLucidDreams) or Player:BuffP(S.SeethingRageBuff) or Player:BuffDownP(S.InquisitionBuff) and Player:HolyPower() >= 3) then
      local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
    end
    -- wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15|spell_targets.wake_of_ashes>=2)&(holy_power<=0|holy_power=1&cooldown.blade_of_justice.remains>gcd)&(cooldown.avenging_wrath.remains>10|talent.crusade.enabled&cooldown.crusade.remains>10)
    if S.WakeofAshes:IsCastableP() and ((not (Cache.EnemiesCount[30] > 1) or Cache.EnemiesCount[8] >= 2) and (Player:HolyPower() <= 0 or Player:HolyPower() == 1 and S.BladeofJustice:CooldownRemainsP() > PlayerGCD) and (S.AvengingWrath:CooldownRemainsP() > 10 or S.Crusade:IsAvailable() and S.Crusade:CooldownRemainsP() > 10)) then
      if HR.Cast(S.WakeofAshes) then return "wake_of_ashes 116"; end
    end
    -- blade_of_justice,if=holy_power<=2|(holy_power=3&(cooldown.hammer_of_wrath.remains>gcd*2|variable.HoW))
    if S.BladeofJustice:IsCastableP() and (Player:HolyPower() <= 2 or (Player:HolyPower() == 3 and (S.HammerofWrath:CooldownRemainsP() > PlayerGCD * 2 or bool(VarHow)))) then
      if HR.Cast(S.BladeofJustice) then return "blade_of_justice 122"; end
    end
    -- judgment,if=holy_power<=2|(holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|variable.HoW))
    if S.Judgment:IsCastableP() and (Player:HolyPower() <= 2 or (Player:HolyPower() <= 4 and (S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 2 or bool(VarHow)))) then
      if HR.Cast(S.Judgment) then return "judgment 128"; end
    end
    -- hammer_of_wrath,if=holy_power<=4
    if S.HammerofWrath:IsReadyP() and (Player:HolyPower() <= 4) then
      if HR.Cast(S.HammerofWrath) then return "hammer_of_wrath 134"; end
    end
    -- consecration,if=holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2
    if S.Consecration:IsCastableP() and (Player:HolyPower() <= 2 or Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 2 and S.Judgment:CooldownRemainsP() > PlayerGCD * 2) then
      if HR.Cast(S.Consecration) then return "consecration 136"; end
    end
    -- call_action_list,name=finishers,if=talent.hammer_of_wrath.enabled&target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up
    if (S.HammerofWrath:IsAvailable() and Target:HealthPercentage() <= 20 or Player:BuffP(S.AvengingWrathBuff) or Player:BuffP(S.CrusadeBuff)) then
      local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
    end
    -- crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2&cooldown.consecration.remains>gcd*2)
    if S.CrusaderStrike:IsCastableP() and (S.CrusaderStrike:ChargesFractionalP() >= 1.75 and (Player:HolyPower() <= 2 or Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemainsP() > PlayerGCD * 2 and S.Judgment:CooldownRemainsP() > PlayerGCD * 2 and S.Consecration:CooldownRemainsP() > PlayerGCD * 2)) then
      if HR.Cast(S.CrusaderStrike) then return "crusader_strike 152"; end
    end
    -- call_action_list,name=finishers
    if (true) then
      local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Settings.Retribution.GCDasOffGCD.Essences) then return "concentrated_flame"; end
    end
    -- crusader_strike,if=holy_power<=4
    if S.CrusaderStrike:IsCastableP() and (Player:HolyPower() <= 4) then
      if HR.Cast(S.CrusaderStrike) then return "crusader_strike 166"; end
    end
    -- arcane_torrent,if=holy_power<=4
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Player:HolyPower() <= 4) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 168"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- auto_attack
    -- Interrupts
    Everyone.Interrupt(5, S.Rebuke, Rebuke, StunInterrupts);
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

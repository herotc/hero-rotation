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
local Mage       = HR.Commons.Mage

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Arcane = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  ArcaneFamiliarBuff                    = Spell(210126),
  ArcaneFamiliar                        = Spell(205022),
  Equipoise                             = Spell(286027),
  MirrorImage                           = Spell(55342),
  ArcaneBlast                           = Spell(30451),
  Evocation                             = Spell(12051),
  ChargedUp                             = Spell(205032),
  ArcaneChargeBuff                      = Spell(36032),
  NetherTempest                         = Spell(114923),
  NetherTempestDebuff                   = Spell(114923),
  RuneofPowerBuff                       = Spell(116014),
  ArcanePowerBuff                       = Spell(12042),
  RuleofThreesBuff                      = Spell(264774),
  Overpowered                           = Spell(155147),
  LightsJudgment                        = Spell(255647),
  RuneofPower                           = Spell(116011),
  ArcanePower                           = Spell(12042),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  PresenceofMind                        = Spell(205025),
  PresenceofMindBuff                    = Spell(205025),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  ArcaneOrb                             = Spell(153626),
  Resonance                             = Spell(205028),
  ArcaneBarrage                         = Spell(44425),
  ArcaneExplosion                       = Spell(1449),
  ArcaneMissiles                        = Spell(5143),
  ClearcastingBuff                      = Spell(263725),
  Amplification                         = Spell(236628),
  ArcanePummeling                       = Spell(270669),
  Supernova                             = Spell(157980),
  Counterspell                          = Spell(2139),
  --Shimmer                               = Spell(212653),
  Blink                                 = MultiSpell(1953, 212653),
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
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368)
};
local S = Spell.Mage.Arcane;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Arcane = {
  PotionofFocusedResolve           = Item(168506),
  TidestormCodex                   = Item(165576, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  -- Other On Use Trinkets for VarFontDoubleOnUse
  NotoriousAspirantsBadge          = Item(167528, {13, 14}),
  NotoriousGladiatorsBadge         = Item(167380, {13, 14}),
  SinisterGladiatorsBadge          = Item(165058, {13, 14}),
  SinisterAspirantsBadge           = Item(165223, {13, 14}),
  DreadGladiatorsBadge             = Item(161902, {13, 14}),
  DreadAspirantsBadge              = Item(162966, {13, 14}),
  DreadCombatantsInsignia          = Item(161676, {13, 14}),
  NotoriousAspirantsMedallion      = Item(167525, {13, 14}),
  NotoriousGladiatorsMedallion     = Item(167377, {13, 14}),
  SinisterGladiatorsMedallion      = Item(165055, {13, 14}),
  SinisterAspirantsMedallion       = Item(165220, {13, 14}),
  DreadGladiatorsMedallion         = Item(161674, {13, 14}),
  DreadAspirantsMedallion          = Item(162897, {13, 14}),
  DreadCombatantsMedallion         = Item(161811, {13, 14}),
  IgnitionMagesFuse                = Item(159615, {13, 14}),
  TzanesBarkspines                 = Item(161411, {13, 14}),
  AzurethoseSingedPlumage          = Item(161377, {13, 14}),
  AncientKnotofWisdomAlliance      = Item(161417, {13, 14}),
  AncientKnotofWisdomHorde         = Item(166793, {13, 14}),
  ShockbitersFang                  = Item(169318, {13, 14}),
  NeuralSynapseEnhancer            = Item(168973, {13, 14}),
  BalefireBranch                   = Item(159630, {13, 14}),
  ManifestoofMadness               = Item(174103, {13, 14})
};
local I = Item.Mage.Arcane;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = { 165576, 167555, 169314 }

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

-- Variables
local VarFontDoubleOnUse = 0;
local VarConserveMana = 0;
local VarTotalBurns = 0;
local VarAverageBurnLength = 0;
local VarFontPrecombatChannel = 0;

HL:RegisterForEvent(function()
  VarFontDoubleOnUse = 0
  VarConserveMana = 0
  VarTotalBurns = 0
  VarAverageBurnLength = 0
  VarFontPrecombatChannel = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {40, 10}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Arcane.UseSplashData then
      HL.GetEnemies(range, nil, true, Target)
      return Cache.EnemiesCount[range]
    else
      UpdateRanges()
      Everyone.AoEToggleEnemiesUpdate()
      return Cache.EnemiesCount[40]
    end
  else
    return 1
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

Player.ArcaneBurnPhase = {}
local BurnPhase = Player.ArcaneBurnPhase

function BurnPhase:Reset()
  self.state = false
  self.last_start = HL.GetTime()
  self.last_stop = HL.GetTime()
end
BurnPhase:Reset()

function BurnPhase:Start()
  if Player:AffectingCombat() then
    self.state = true
    self.last_start = HL.GetTime()
  end
end

function BurnPhase:Stop()
  self.state = false
  self.last_stop = HL.GetTime()
end

function BurnPhase:On()
  return self.state or (not Player:AffectingCombat() and Player:IsCasting() and (S.ArcanePower:CooldownRemainsP() == 0 and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0))))
end

function BurnPhase:Duration()
  return self.state and (HL.GetTime() - self.last_start) or 0
end

HL:RegisterForEvent(function()
  BurnPhase:Reset()
end, "PLAYER_REGEN_DISABLED")

local function PresenceOfMindMax ()
  return 2
end

local function ArcaneMissilesProcMax ()
  return 3
end

function Player:ArcaneChargesP()
  return math.min(self:ArcaneCharges() + num(self:IsCasting(S.ArcaneBlast)),4)
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Burn, Conserve, Essences, Movement
  --local BlinkAny = S.Shimmer:IsAvailable() and S.Shimmer or S.Blink
  EnemiesCount = GetEnemiesCount(10)
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff, true) then
      if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect 111"; end
    end
    -- arcane_familiar
    if S.ArcaneFamiliar:IsCastableP() and Player:BuffDownP(S.ArcaneFamiliarBuff) then
      if HR.Cast(S.ArcaneFamiliar) then return "arcane_familiar 113"; end
    end
    -- variable,name=conserve_mana,op=set,value=60+20*azerite.equipoise.enabled
    if (true) then
      VarConserveMana = 60 + 20 * num(S.Equipoise:AzeriteEnabled())
    end
    -- variable,name=font_double_on_use,op=set,value=equipped.azsharas_font_of_power&(equipped.manifesto_of_madness|equipped.gladiators_badge|equipped.gladiators_medallion|equipped.ignition_mages_fuse|equipped.tzanes_barkspines|equipped.azurethos_singed_plumage|equipped.ancient_knot_of_wisdom|equipped.shockbiters_fang|equipped.neural_synapse_enhancer|equipped.balefire_branch)
    if (true) then
      VarFontDoubleOnUse = num(I.AzsharasFontofPower:IsEquipped() and (I.ManifestoofMadness:IsEquipped() or I.NotoriousAspirantsBadge:IsEquipped() or I.NotoriousGladiatorsBadge:IsEquipped() or I.SinisterGladiatorsBadge:IsEquipped() or I.SinisterAspirantsBadge:IsEquipped() or I.DreadGladiatorsBadge:IsEquipped() or I.DreadAspirantsBadge:IsEquipped() or I.DreadCombatantsInsignia:IsEquipped() or I.NotoriousAspirantsMedallion:IsEquipped() or I.NotoriousGladiatorsMedallion:IsEquipped() or I.SinisterGladiatorsMedallion:IsEquipped() or I.SinisterAspirantsMedallion:IsEquipped() or I.DreadGladiatorsMedallion:IsEquipped() or I.DreadAspirantsMedallion:IsEquipped() or I.DreadCombatantsMedallion:IsEquipped() or I.IgnitionMagesFuse:IsEquipped() or I.TzanesBarkspines:IsEquipped() or I.AzurethoseSingedPlumage:IsEquipped() or I.AncientKnotofWisdomAlliance:IsEquipped() or I.AncientKnotofWisdomHorde:IsEquipped() or I.ShockbitersFang:IsEquipped() or I.NeuralSynapseEnhancer:IsEquipped() or I.BalefireBranch:IsEquipped()))
    end
    -- variable,name=font_of_power_precombat_channel,op=set,value=12,if=variable.font_double_on_use&variable.font_of_power_precombat_channel=0
    if (bool(VarFontDoubleOnUse) and VarFontPrecombatChannel == 0) then
      VarFontPrecombatChannel = 12
    end
    -- snapshot_stats
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipReady() then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 114"; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 115"; end
    end
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_intellect 117"; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast, nil, nil, 40) then return "arcane_blast 119"; end
    end
  end
  Burn = function()
    -- variable,name=total_burns,op=add,value=1,if=!burn_phase
    if (not BurnPhase:On()) then
      VarTotalBurns = VarTotalBurns + 1
    end
    -- start_burn_phase,if=!burn_phase
    if (not BurnPhase:On()) then
      BurnPhase:Start()
    end
    -- stop_burn_phase,if=burn_phase&prev_gcd.1.evocation&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
    if (BurnPhase:On() and Player:PrevGCDP(1, S.Evocation) and Target:TimeToDie() > VarAverageBurnLength and BurnPhase:Duration() > 0) then
      BurnPhase:Stop()
    end
    -- charged_up,if=buff.arcane_charge.stack<=1
    if S.ChargedUp:IsCastableP() and (Player:ArcaneChargesP() <= 1) then
      if HR.Cast(S.ChargedUp, Settings.Arcane.GCDasOffGCD.ChargedUp) then return "charged_up 201"; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 203"; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Target:DebuffRefreshableCP(S.NetherTempestDebuff) or Target:DebuffDownP(S.NetherTempestDebuff)) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest, nil, nil, 40) then return "nether_tempest 205"; end
    end
    -- arcane_blast,if=buff.rule_of_threes.up&talent.overpowered.enabled&active_enemies<3
    if S.ArcaneBlast:IsReadyP() and (Player:BuffP(S.RuleofThreesBuff) and S.Overpowered:IsAvailable() and EnemiesCount < 3) then
      if HR.Cast(S.ArcaneBlast, nil, nil, 40) then return "arcane_blast 207"; end
    end
    -- lights_judgment,if=buff.arcane_power.down
    if S.LightsJudgment:IsCastableP() and (Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 209"; end
    end
    -- bag_of_tricks,if=buff.arcane_power.down
    if S.BagofTricks:IsCastableP() and (Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 222"; end
    end
    -- rune_of_power,if=!buff.arcane_power.up&(mana.pct>=50|cooldown.arcane_power.remains=0)&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.ArcanePowerBuff) and (Player:ManaPercentageP() >= 50 or S.ArcanePower:CooldownRemainsP() == 0) and (Player:ArcaneChargesP() == Player:ArcaneChargesMax())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "rune_of_power 211"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 213"; end
    end
    -- arcane_power
    if S.ArcanePower:IsCastableP() then
      if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power 215"; end
    end
    -- use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
    if (Player:BuffP(S.ArcanePowerBuff) or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 217"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 219"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 221"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastableP() then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 222"; end
    end
    -- presence_of_mind,if=(talent.rune_of_power.enabled&buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time)|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
    -- Manually added requirement that buffs have >0 time remaining and added 0.5s to the calculations to account for lag and player reaction
    if S.PresenceofMind:IsCastableP() and ((S.RuneofPower:IsAvailable() and Player:BuffRemainsP(S.RuneofPowerBuff) > 0 and Player:BuffRemainsP(S.RuneofPowerBuff) <= PresenceOfMindMax() * S.ArcaneBlast:ExecuteTime() + 0.5) or Player:BuffRemainsP(S.ArcanePowerBuff) > 0 and Player:BuffRemainsP(S.ArcanePowerBuff) <= PresenceOfMindMax() * S.ArcaneBlast:ExecuteTime() + 0.5) then
      if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind 223"; end
    end
    -- potion,if=buff.arcane_power.up&((!essence.condensed_lifeforce.major|essence.condensed_lifeforce.rank<2)&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))|buff.guardian_of_azeroth.up)|target.time_to_die<cooldown.arcane_power.remains
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.ArcanePowerBuff) and ((not Spell:MajorEssenceEnabled(AE.CondensedLifeForce) or Spell:EssenceRank(AE.CondensedLifeForce) < 2) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not (Player:IsRace("Troll") or Player:IsRace("Orc"))) or Player:BuffP(S.GuardianofAzerothBuff)) or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
      if HR.Cast(I.PotionofFocusedResolve, nil, Settings.Commons.TrinketDisplayStyle) then return "battle_potion_of_intellect 225"; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack=0|(active_enemies<3|(active_enemies<2&talent.resonance.enabled))
    if S.ArcaneOrb:IsCastableP() and (Player:ArcaneChargesP() == 0 or (EnemiesCount < 3 or (EnemiesCount < 2 and S.Resonance:IsAvailable()))) then
      if HR.Cast(S.ArcaneOrb, nil, nil, 40) then return "arcane_orb 227"; end
    end
    -- arcane_barrage,if=active_enemies>=3&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.ArcaneBarrage:IsCastableP() and (EnemiesCount >= 3 and (Player:ArcaneChargesP() == Player:ArcaneChargesMax())) then
      if HR.Cast(S.ArcaneBarrage, nil, nil, 40) then return "arcane_barrage 229"; end
    end
    -- arcane_explosion,if=active_enemies>=3
    if S.ArcaneExplosion:IsReadyP() and (EnemiesCount >= 3) then
      if HR.Cast(S.ArcaneExplosion, nil, nil, 10) then return "arcane_explosion 231"; end
    end
    -- arcane_missiles,if=buff.clearcasting.react&active_enemies<3&(talent.amplification.enabled|(!talent.overpowered.enabled&azerite.arcane_pummeling.rank>=2)|buff.arcane_power.down),chain=1
    if S.ArcaneMissiles:IsCastableP() and (bool(Player:BuffStackP(S.ClearcastingBuff)) and EnemiesCount < 3 and (S.Amplification:IsAvailable() or (not S.Overpowered:IsAvailable() and S.ArcanePummeling:AzeriteRank() >= 2) or Player:BuffDownP(S.ArcanePowerBuff))) then
      if HR.Cast(S.ArcaneMissiles, nil, nil, 40) then return "arcane_missiles 233"; end
    end
    -- arcane_blast,if=active_enemies<3
    if S.ArcaneBlast:IsReadyP() and (EnemiesCount < 3) then
      if HR.Cast(S.ArcaneBlast, nil, nil, 40) then return "arcane_blast 235"; end
    end
    -- variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+(burn_phase_duration))%variable.total_burns
    if (true) then
      VarAverageBurnLength = (VarAverageBurnLength * VarTotalBurns - VarAverageBurnLength + (BurnPhase:Duration())) / VarTotalBurns
    end
    -- evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
    if S.Evocation:IsCastableP() then
      if HR.Cast(S.Evocation) then return "evocation 237"; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() then
      if HR.Cast(S.ArcaneBarrage, nil, nil, 40) then return "arcane_barrage 239"; end
    end
  end
  Conserve = function()
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 301"; end
    end
    -- charged_up,if=buff.arcane_charge.stack=0
    if S.ChargedUp:IsCastableP() and (Player:ArcaneChargesP() == 0) then
      if HR.Cast(S.ChargedUp, Settings.Arcane.GCDasOffGCD.ChargedUp) then return "charged_up 303"; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Target:DebuffRefreshableCP(S.NetherTempestDebuff) or Target:DebuffDownP(S.NetherTempestDebuff)) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest, nil, nil, 40) then return "nether_tempest 305"; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack<=2&(cooldown.arcane_power.remains>10|active_enemies<=2)
    if S.ArcaneOrb:IsCastableP() and (Player:ArcaneChargesP() <= 2 and (S.ArcanePower:CooldownRemainsP() > 10 or EnemiesCount <= 2)) then
      if HR.Cast(S.ArcaneOrb, nil, nil, 40) then return "arcane_orb 307"; end
    end
    -- arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
    if S.ArcaneBlast:IsReadyP() and (Player:BuffP(S.RuleofThreesBuff) and Player:ArcaneChargesP() > 3) then
      if HR.Cast(S.ArcaneBlast, nil, nil, 40) then return "arcane_blast 309"; end
    end
    -- use_item,name=tidestorm_codex,if=buff.rune_of_power.down&!buff.arcane_power.react&cooldown.arcane_power.remains>20
    if I.TidestormCodex:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff) and S.ArcanePower:CooldownRemainsP() > 20) then
      if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "tidestorm_codex 311"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=buff.rune_of_power.down&!buff.arcane_power.react&cooldown.arcane_power.remains>20
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff) and S.ArcanePower:CooldownRemainsP() > 20) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device 313"; end
    end
    -- rune_of_power,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&(full_recharge_time<=execute_time|full_recharge_time<=cooldown.arcane_power.remains|target.time_to_die<=cooldown.arcane_power.remains)
    if S.RuneofPower:IsCastableP() and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() and (S.RuneofPower:FullRechargeTimeP() <= S.RuneofPower:ExecuteTime() or S.RuneofPower:FullRechargeTimeP() <= S.ArcanePower:CooldownRemainsP() or Target:TimeToDie() <= S.ArcanePower:CooldownRemainsP())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "rune_of_power 315"; end
    end
    -- arcane_missiles,if=mana.pct<=95&buff.clearcasting.react&active_enemies<3,chain=1
    if S.ArcaneMissiles:IsCastableP() and (Player:ManaPercentageP() <= 95 and bool(Player:BuffStackP(S.ClearcastingBuff)) and EnemiesCount < 3) then
      if HR.Cast(S.ArcaneMissiles, nil, nil, 40) then return "arcane_missiles 317"; end
    end
    -- arcane_barrage,if=((buff.arcane_charge.stack=buff.arcane_charge.max_stack)&((mana.pct<=variable.conserve_mana)|(talent.rune_of_power.enabled&cooldown.arcane_power.remains>cooldown.rune_of_power.full_recharge_time&mana.pct<=variable.conserve_mana+25))|(talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd&cooldown.arcane_power.remains>10))|mana.pct<=(variable.conserve_mana-10)
    if S.ArcaneBarrage:IsCastableP() and (((Player:ArcaneChargesP() == Player:ArcaneChargesMax()) and ((Player:ManaPercentageP() <= VarConserveMana) or (S.RuneofPower:IsAvailable() and S.ArcanePower:CooldownRemainsP() > S.RuneofPower:FullRechargeTimeP() and Player:ManaPercentageP() <= VarConserveMana + 25)) or (S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemainsP() <= Player:GCD() and S.ArcanePower:CooldownRemainsP() > 10)) or Player:ManaPercentageP() <= (VarConserveMana - 10)) then
      if HR.Cast(S.ArcaneBarrage, nil, nil, 40) then return "arcane_barrage 319"; end
    end
    -- supernova,if=mana.pct<=95
    if S.Supernova:IsCastableP() and (Player:ManaPercentageP() <= 95) then
      if HR.Cast(S.Supernova, nil, nil, 40) then return "supernova 321"; end
    end
    -- arcane_explosion,if=active_enemies>=3&(mana.pct>=variable.conserve_mana|buff.arcane_charge.stack=3)
    if S.ArcaneExplosion:IsReadyP() and (EnemiesCount >= 3 and (Player:ManaPercentageP() >= VarConserveMana or Player:ArcaneChargesP() == 3)) then
      if HR.Cast(S.ArcaneExplosion, nil, nil, 10) then return "arcane_explosion 323"; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast, nil, nil, 40) then return "arcane_blast 325"; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() then
      if HR.Cast(S.ArcaneBarrage, nil, nil, 40) then return "arcane_barrage 327"; end
    end
  end
  Essences = function()
    -- blood_of_the_enemy,if=burn_phase&buff.arcane_power.down&buff.rune_of_power.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack|time_to_die<cooldown.arcane_power.remains
    if S.BloodoftheEnemy:IsCastableP() and (BurnPhase:On() and Player:BuffDownP(S.ArcanePowerBuff) and Player:BuffDownP(S.RuneofPowerBuff) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 401"; end
    end
    -- concentrated_flame,line_cd=6,if=buff.rune_of_power.down&buff.arcane_power.down&(!burn_phase|time_to_die<cooldown.arcane_power.remains)&mana.time_to_max>=execute_time
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff) and (not BurnPhase:On() or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) and Player:ManaTimeToMax() >= S.ConcentratedFlame:ExecuteTime()) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 403"; end
    end
    -- reaping_flames,if=buff.rune_of_power.down&buff.arcane_power.down&(!burn_phase|time_to_die<cooldown.arcane_power.remains)&mana.time_to_max>=execute_time
    if (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff) and (not BurnPhase:On() or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) and Player:ManaTimeToMax() >= S.ReapingFlames:ExecuteTime()) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    -- focused_azerite_beam,if=buff.rune_of_power.down&buff.arcane_power.down
    if S.FocusedAzeriteBeam:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 405"; end
    end
    -- guardian_of_azeroth,if=buff.rune_of_power.down&buff.arcane_power.down
    if S.GuardianofAzeroth:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 407"; end
    end
    -- purifying_blast,if=buff.rune_of_power.down&buff.arcane_power.down
    if S.PurifyingBlast:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 409"; end
    end
    -- ripple_in_space,if=buff.rune_of_power.down&buff.arcane_power.down
    if S.RippleInSpace:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 411"; end
    end
    -- the_unbound_force,if=buff.rune_of_power.down&buff.arcane_power.down
    if S.TheUnboundForce:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 413"; end
    end
    -- memory_of_lucid_dreams,if=!burn_phase&buff.arcane_power.down&cooldown.arcane_power.remains&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(!talent.rune_of_power.enabled|action.rune_of_power.charges)|time_to_die<cooldown.arcane_power.remains
    if S.MemoryofLucidDreams:IsCastableP() and (not BurnPhase:On() and Player:BuffDownP(S.ArcanePowerBuff) and bool(S.ArcanePower:CooldownRemainsP()) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (not S.RuneofPower:IsAvailable() or bool(S.RuneofPower:Charges())) or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 415"; end
    end
    -- worldvein_resonance,if=burn_phase&buff.arcane_power.down&buff.rune_of_power.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack|time_to_die<cooldown.arcane_power.remains
    if S.WorldveinResonance:IsCastableP() and (BurnPhase:On() and Player:BuffDownP(S.ArcanePowerBuff) and Player:BuffDownP(S.RuneofPowerBuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax() or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 417"; end
    end
  end
  Movement = function()
    -- blink_any,if=movement.distance>=10
    if S.Blink:IsCastableP() and (not Target:IsInRange(S.ArcaneBlast:MaximumRange())) then
      if HR.Cast(S.Blink) then return "blink_any 501"; end
    end
    -- presence_of_mind
    if S.PresenceofMind:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind 503"; end
    end
    -- arcane_missiles
    if S.ArcaneMissiles:IsCastableP() then
      if HR.Cast(S.ArcaneMissiles, nil, nil, 40) then return "arcane_missiles 505"; end
    end
    -- arcane_orb
    if S.ArcaneOrb:IsCastableP() then
      if HR.Cast(S.ArcaneOrb, nil, nil, 40) then return "arcane_orb 507"; end
    end
    -- supernova
    if S.Supernova:IsCastableP() then
      if HR.Cast(S.Supernova, nil, nil, 40) then return "supernova 509"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false);
    -- call_action_list,name=essences
    if (true) then
      local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
    -- use_item,name=azsharas_font_of_power,if=buff.rune_of_power.down&buff.arcane_power.down&(cooldown.arcane_power.remains<=4+10*variable.font_double_on_use&cooldown.evocation.remains<=variable.average_burn_length+4+10*variable.font_double_on_use|time_to_die<cooldown.arcane_power.remains)
    if I.AzsharasFontofPower:IsEquipReady() and (Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff) and (S.ArcanePower:CooldownRemainsP() <= 4 + 10 * VarFontDoubleOnUse and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength + 4 + 10 * VarFontDoubleOnUse or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP())) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 101"; end
    end
    -- call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length
    if HR.CDsON() and (BurnPhase:On() or Target:TimeToDie() < VarAverageBurnLength) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=burn,if=(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0&buff.arcane_charge.stack<=1)))
    if HR.CDsON() and ((S.ArcanePower:CooldownRemainsP() == 0 and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0 and Player:ArcaneChargesP() <= 1)))) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=conserve,if=!burn_phase
    if (not BurnPhase:On()) then
      local ShouldReturn = Conserve(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=movement
    if (true) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(1449, 10, 6)               -- Arcane Explosion
  HL.RegisterNucleusAbility(44425, 10, 6)              -- Arcane Barrage
end

HR.SetAPL(62, APL, Init)
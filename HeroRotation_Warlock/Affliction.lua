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
if not Spell.Warlock then Spell.Warlock = {} end
Spell.Warlock.Affliction = {
  SummonPet                             = Spell(691),
  GrimoireofSacrificeBuff               = Spell(196099),
  GrimoireofSacrifice                   = Spell(108503),
  SeedofCorruptionDebuff                = Spell(27243),
  SeedofCorruption                      = Spell(27243),
  HauntDebuff                           = Spell(48181),
  Haunt                                 = Spell(48181),
  ShadowBolt                            = Spell(232670),
  PhantomSingularity                    = Spell(205179),
  SummonDarkglare                       = Spell(205180),
  DarkSoulMisery                        = Spell(113860),
  DarkSoul                              = Spell(113860),
  Fireblood                             = Spell(265221),
  BloodFury                             = Spell(20572),
  SiphonLife                            = Spell(63106),
  SiphonLifeDebuff                      = Spell(63106),
  AgonyDebuff                           = Spell(980),
  CorruptionDebuff                      = Spell(146739),
  Agony                                 = Spell(980),
  Corruption                            = Spell(172),
  CreepingDeath                         = Spell(264000),
  WritheInAgony                         = Spell(196102),
  PandemicInvocation                    = Spell(289364),
  UnstableAffliction                    = Spell(30108),
  UnstableAfflictionDebuff              = Spell(30108),
  Deathbolt                             = Spell(264106),
  NightfallBuff                         = Spell(264571),
  AbsoluteCorruption                    = Spell(196103),
  DrainLife                             = Spell(234153),
  InevitableDemiseBuff                  = Spell(273525),
  VileTaint                             = Spell(278350),
  DrainSoul                             = Spell(198590),
  ShadowEmbraceDebuff                   = Spell(32390),
  ShadowEmbrace                         = Spell(32388),
  DreadfulCalling                       = Spell(278727),
  CascadingCalamity                     = Spell(275372),
  CascadingCalamityBuff                 = Spell(275378),
  SowtheSeeds                           = Spell(196226),
  ActiveUasBuff                         = Spell(233490),
  PhantomSingularityDebuff              = Spell(205179),
  Berserking                            = Spell(26297),
  ShiverVenomDebuff                     = Spell(301624),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  VisionofPerfectionMinor               = MultiSpell(296320, 299367, 299369),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  ConcentratedFlameBurn                 = Spell(295368),
  RecklessForceBuff                     = Spell(302932)
};
local S = Spell.Warlock.Affliction;

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Affliction = {
  PotionofUnbridledFury            = Item(169299),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  RotcrustedVoodooDoll             = Item(159624, {13, 14}),
  ShiverVenomRelic                 = Item(168905, {13, 14}),
  AquipotentNautilus               = Item(169305, {13, 14}),
  TidestormCodex                   = Item(165576, {13, 14}),
  VialofStorms                     = Item(158224, {13, 14})
};
local I = Item.Warlock.Affliction;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
};

-- Variables
local VarMaintainSe = 0;
local VarUseSeed = 0;
local VarPadding = 0;

HL:RegisterForEvent(function()
  VarMaintainSe = 0
  VarUseSeed = 0
  VarPadding = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {40, 5}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Affliction.UseSplashData then
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

S.SeedofCorruption:RegisterInFlight()
S.ConcentratedFlame:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function TimeToShard()
  local ActiveAgony = S.Agony:ActiveDot()
  if ActiveAgony == 0 then
    return 10000 
  end
  return 1 / (0.16 / math.sqrt(ActiveAgony) * (ActiveAgony == 1 and 1.15 or 1) * ActiveAgony / S.Agony:TickTime())
end

local UnstableAfflictionDebuffs = {
  Spell(233490),
  Spell(233496),
  Spell(233497),
  Spell(233498),
  Spell(233499)
};

local function ActiveUAs ()
  local UACount = 0
  for _, UADebuff in pairs(UnstableAfflictionDebuffs) do
    if Target:DebuffRemainsP(UADebuff) > 0 then UACount = UACount + 1 end
  end
  return UACount
end

local function Contagion()
  local MaximumDuration = 0
  for _, UADebuff in pairs(UnstableAfflictionDebuffs) do
    local UARemains = Target:DebuffRemainsP(UADebuff)
    if UARemains > MaximumDuration then
      MaximumDuration = UARemains
    end
  end
  return MaximumDuration
end

S.ShadowBolt:RegisterInFlight()
S.SeedofCorruption:RegisterInFlight()
S.ConcentratedFlame:RegisterInFlight()

local function EvaluateTargetIfFilterAgony160(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.AgonyDebuff)
end

local function EvaluateTargetIfAgony201(TargetUnit)
  return S.CreepingDeath:IsAvailable() and S.AgonyDebuff:ActiveDot() < 6 and TargetUnit:TimeToDie() > 10 and (TargetUnit:DebuffRemainsP(S.AgonyDebuff) <= Player:GCD() or S.SummonDarkglare:CooldownRemainsP() > 10 and (TargetUnit:DebuffRemainsP(S.AgonyDebuff) < 5 or not bool(S.PandemicInvocation:AzeriteRank()) and TargetUnit:DebuffRefreshableCP(S.AgonyDebuff)))
end

local function EvaluateTargetIfFilterAgony207(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.AgonyDebuff)
end

local function EvaluateTargetIfAgony248(TargetUnit)
  return not S.CreepingDeath:IsAvailable() and S.AgonyDebuff:ActiveDot() < 8 and TargetUnit:TimeToDie() > 10 and (TargetUnit:DebuffRemainsP(S.AgonyDebuff) <= Player:GCD() or S.SummonDarkglare:CooldownRemainsP() > 10 and (TargetUnit:DebuffRemainsP(S.AgonyDebuff) < 5 or not bool(S.PandemicInvocation:AzeriteRank()) and TargetUnit:DebuffRefreshableCP(S.AgonyDebuff)))
end

local function EvaluateTargetIfFilterSiphonLife254(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.SiphonLifeDebuff)
end

local function EvaluateTargetIfSiphonLife293(TargetUnit)
  return (S.SiphonLifeDebuff:ActiveDot() < 8 - num(S.CreepingDeath:IsAvailable()) - EnemiesCount) and TargetUnit:TimeToDie() > 10 and TargetUnit:DebuffRefreshableCP(S.SiphonLifeDebuff) and (TargetUnit:DebuffDownP(S.SiphonLifeDebuff) and EnemiesCount == 1 or S.SummonDarkglare:CooldownRemainsP() > Player:SoulShardsP() * S.UnstableAffliction:ExecuteTime())
end

local function EvaluateCycleCorruption300(TargetUnit)
  return EnemiesCount < 3 + num(S.WritheInAgony:IsAvailable()) and (TargetUnit:DebuffRemainsP(S.CorruptionDebuff) <= Player:GCD() or S.SummonDarkglare:CooldownRemainsP() > 10 and TargetUnit:DebuffRefreshableCP(S.CorruptionDebuff)) and TargetUnit:TimeToDie() > 10
end

local function EvaluateCycleDrainSoul479(TargetUnit)
  return TargetUnit:TimeToDie() <= Player:GCD()
end

local function EvaluateTargetIfFilterDrainSoul485(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff)
end

local function EvaluateTargetIfDrainSoul498(TargetUnit)
  return S.ShadowEmbrace:IsAvailable() and bool(VarMaintainSe) and TargetUnit:DebuffDownP(S.ShadowEmbraceDebuff)
end

local function EvaluateTargetIfFilterDrainSoul504(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff)
end

local function EvaluateTargetIfDrainSoul515(TargetUnit)
  return S.ShadowEmbrace:IsAvailable() and bool(VarMaintainSe)
end

local function EvaluateCycleShadowBolt524(TargetUnit)
  return S.ShadowEmbrace:IsAvailable() and bool(VarMaintainSe) and TargetUnit:DebuffDownP(S.ShadowEmbraceDebuff) and not S.ShadowBolt:InFlight()
end

local function EvaluateTargetIfFilterShadowBolt540(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff)
end

local function EvaluateTargetIfShadowBolt551(TargetUnit)
  return S.ShadowEmbrace:IsAvailable() and bool(VarMaintainSe)
end

local function EvaluateCycleUnstableAffliction640(TargetUnit)
  return not bool(VarUseSeed) and (not S.Deathbolt:IsAvailable() or S.Deathbolt:CooldownRemainsP() > time_to_shard or Player:SoulShardsP() > 1) and (not S.VileTaint:IsAvailable() or Player:SoulShardsP() > 1) and contagion <= S.UnstableAffliction:CastTime() + VarPadding and (not S.CascadingCalamity:AzeriteEnabled() or Player:BuffRemainsP(S.CascadingCalamityBuff) > time_to_shard)
end

local function EvaluateCycleDrainSoul711(TargetUnit)
  return TargetUnit:TimeToDie() <= Player:GCD() and Player:SoulShardsP() < 5
end

local function EvaluateTargetIfFilterAgony751(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.AgonyDebuff)
end

local function EvaluateTargetIfAgony768(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.AgonyDebuff) <= Player:GCD() + S.ShadowBolt:ExecuteTime() and TargetUnit:TimeToDie() > 8
end

local function EvaluateCycleUnstableAffliction781(TargetUnit)
  return not bool(contagion) and TargetUnit:TimeToDie() <= 8
end

local function EvaluateTargetIfFilterDrainSoul787(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff)
end

local function EvaluateTargetIfDrainSoul802(TargetUnit)
  return S.ShadowEmbrace:IsAvailable() and bool(VarMaintainSe) and TargetUnit:DebuffP(S.ShadowEmbraceDebuff) and TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff) <= Player:GCD() * 2
end

local function EvaluateTargetIfFilterShadowBolt808(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff)
end

local function EvaluateTargetIfShadowBolt835(TargetUnit)
  return S.ShadowEmbrace:IsAvailable() and bool(VarMaintainSe) and TargetUnit:DebuffP(S.ShadowEmbraceDebuff) and TargetUnit:DebuffRemainsP(S.ShadowEmbraceDebuff) <= S.ShadowBolt:ExecuteTime() * 2 + S.ShadowBolt:TravelTime() and not S.ShadowBolt:InFlight()
end

local function EvaluateTargetIfFilterPhantomSingularity841(TargetUnit)
  return TargetUnit:TimeToDie()
end

local function EvaluateTargetIfPhantomSingularity850(TargetUnit)
  return HL.CombatTime() > 35 and TargetUnit:TimeToDie() > 16 * Player:SpellHaste() and (not S.VisionofPerfectionMinor:IsAvailable() and not bool(S.DreadfulCalling:AzeriteRank()) or S.SummonDarkglare:CooldownRemainsP() > 45 + Player:SoulShardsP() * S.DreadfulCalling:AzeriteRank() or S.SummonDarkglare:CooldownRemainsP() < 15 * Player:SpellHaste() + Player:SoulShardsP() * S.DreadfulCalling:AzeriteRank())
end

local function EvaluateTargetIfFilterVileTaint856(TargetUnit)
  return TargetUnit:TimeToDie()
end

local function EvaluateTargetIfVileTaint859(TargetUnit)
  return HL.CombatTime() > 15 and TargetUnit:TimeToDie() >= 10 and (S.SummonDarkglare:CooldownRemainsP() > 30 or S.SummonDarkglare:CooldownRemainsP() < 10 and Target:DebuffRemainsP(S.CorruptionDebuff) >= 10 and (Target:DebuffRemainsP(S.SiphonLifeDebuff) >= 10 or not S.SiphonLife:IsAvailable()))
end

local function EvaluateTargetIfFilterUnstableAffliction865(TargetUnit)
  return contagion
end

local function EvaluateTargetIfUnstableAffliction870(TargetUnit)
  return not bool(VarUseSeed) and Player:SoulShardsP() == 5
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns, DbRefresh, Dots, Fillers, Spenders
  EnemiesCount = GetEnemiesCount(10)
  HL.GetEnemies(40) -- To populate Cache.Enemies[40] for CastCycles
  time_to_shard = TimeToShard()
  contagion = Contagion()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- summon_pet
    if S.SummonPet:IsCastableP() then
      if HR.Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet 3"; end
    end
    -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireofSacrifice:IsCastableP() and Player:BuffDownP(S.GrimoireofSacrificeBuff) and (S.GrimoireofSacrifice:IsAvailable()) then
      if HR.Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireofSacrifice) then return "grimoire_of_sacrifice 5"; end
    end
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_intellect 14"; end
      end
      -- use_item,name=azsharas_font_of_power
      -- Using main icon, since only Haunt will be suggested precombat if equipped and that's optional
      if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 15"; end
      end
      -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>=3&!equipped.169314
      if S.SeedofCorruption:IsCastableP() and Player:DebuffDownP(S.SeedofCorruptionDebuff) and (EnemiesCount >= 3 and not I.AzsharasFontofPower:IsEquipped()) then
        if HR.Cast(S.SeedofCorruption) then return "seed_of_corruption 16"; end
      end
      -- haunt
      if S.Haunt:IsCastableP() and Player:DebuffDownP(S.HauntDebuff) then
        if HR.Cast(S.Haunt) then return "haunt 20"; end
      end
      -- shadow_bolt,if=!talent.haunt.enabled&spell_targets.seed_of_corruption_aoe<3&!equipped.169314
      if S.ShadowBolt:IsCastableP() and (not S.Haunt:IsAvailable() and EnemiesCount < 3 and not I.AzsharasFontofPower:IsEquipped()) then
        if HR.Cast(S.ShadowBolt) then return "shadow_bolt 24"; end
      end
    end
  end
  Cooldowns = function()
    -- use_item,name=azsharas_font_of_power,if=(!talent.phantom_singularity.enabled|cooldown.phantom_singularity.remains<4*spell_haste|!cooldown.phantom_singularity.remains)&cooldown.summon_darkglare.remains<19*spell_haste+soul_shard*azerite.dreadful_calling.rank&dot.agony.remains&dot.corruption.remains&(dot.siphon_life.remains|!talent.siphon_life.enabled)
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and ((not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownRemainsP() < 4 * Player:SpellHaste() or S.PhantomSingularity:CooldownUpP()) and S.SummonDarkglare:CooldownRemainsP() < 19 * Player:SpellHaste() + Player:SoulShardsP() * S.DreadfulCalling:AzeriteRank() and Target:DebuffP(S.AgonyDebuff) and Target:DebuffP(S.CorruptionDebuff) and (Target:DebuffP(S.SiphonLifeDebuff) or not S.SiphonLife:IsAvailable())) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 30"; end
    end
    -- potion,if=(talent.dark_soul_misery.enabled&cooldown.summon_darkglare.up&cooldown.dark_soul.up)|cooldown.summon_darkglare.up|target.time_to_die<30
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and ((S.DarkSoulMisery:IsAvailable() and S.SummonDarkglare:CooldownUpP() and S.DarkSoul:CooldownUpP()) or S.SummonDarkglare:CooldownUpP() or Target:TimeToDie() < 30) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_intellect 40"; end
    end
    -- use_items,if=cooldown.summon_darkglare.remains>70|time_to_die<20|((buff.active_uas.stack=5|soul_shard=0)&(!talent.phantom_singularity.enabled|cooldown.phantom_singularity.remains)&(!talent.deathbolt.enabled|cooldown.deathbolt.remains<=gcd|!cooldown.deathbolt.remains)&!cooldown.summon_darkglare.remains)
    -- fireblood,if=!cooldown.summon_darkglare.up
    if S.Fireblood:IsCastableP() and HR.CDsON() and (not S.SummonDarkglare:CooldownUpP()) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 51"; end
    end
    -- blood_fury,if=!cooldown.summon_darkglare.up
    if S.BloodFury:IsCastableP() and HR.CDsON() and (not S.SummonDarkglare:CooldownUpP()) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 55"; end
    end
    -- memory_of_lucid_dreams,if=time>30
    if S.MemoryofLucidDreams:IsCastableP() and (HL.CombatTime() > 30) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 59"; end
    end
    -- dark_soul,if=target.time_to_die<20+gcd|talent.sow_the_seeds.enabled&cooldown.summon_darkglare.remains>=cooldown.summon_darkglare.duration-10
    if S.DarkSoul:IsReadyP() and (Target:TimeToDie() < 20 + Player:GCD() or S.SowtheSeeds:IsAvailable() and S.SummonDarkglare:CooldownRemainsP() >= S.SummonDarkglare:BaseDuration() - 10) then
      if HR.Cast(S.DarkSoul) then return "dark_soul 60"; end
    end
    -- blood_of_the_enemy,if=pet.darkglare.remains|(!cooldown.deathbolt.remains|!talent.deathbolt.enabled)&cooldown.summon_darkglare.remains>=80&essence.blood_of_the_enemy.rank>1
    if S.BloodoftheEnemy:IsCastableP() and (S.SummonDarkglare:CooldownRemainsP() > 160 or (S.Deathbolt:CooldownUpP() or not S.Deathbolt:IsAvailable()) and S.SummonDarkglare:CooldownRemainsP() >= 80 and not S.BloodoftheEnemy:ID() == 297108) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy 61"; end
    end
    -- use_item,name=pocketsized_computation_device,if=cooldown.summon_darkglare.remains>=25&(cooldown.deathbolt.remains|!talent.deathbolt.enabled)
    if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets and (S.SummonDarkglare:CooldownRemainsP() >= 25 and (bool(S.Deathbolt:CooldownRemainsP()) or not S.Deathbolt:IsAvailable())) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "pocketsized_computation_device 50"; end
    end
    -- use_item,name=rotcrusted_voodoo_doll,if=cooldown.summon_darkglare.remains>=25&(cooldown.deathbolt.remains|!talent.deathbolt.enabled)
    if I.RotcrustedVoodooDoll:IsEquipReady() and Settings.Commons.UseTrinkets and (S.SummonDarkglare:CooldownRemainsP() >= 25 and (bool(S.Deathbolt:CooldownRemainsP()) or not S.Deathbolt:IsAvailable())) then
      if HR.Cast(I.RotcrustedVoodooDoll, nil, Settings.Commons.TrinketDisplayStyle) then return "rotcrusted_voodoo_doll"; end
    end
    -- use_item,name=shiver_venom_relic,if=cooldown.summon_darkglare.remains>=25&(cooldown.deathbolt.remains|!talent.deathbolt.enabled)
    if I.ShiverVenomRelic:IsEquipReady() and Settings.Commons.UseTrinkets and (S.SummonDarkglare:CooldownRemainsP() >= 25 and (bool(S.Deathbolt:CooldownRemainsP()) or not S.Deathbolt:IsAvailable())) then
      if HR.Cast(I.ShiverVenomRelic, nil, Settings.Commons.TrinketDisplayStyle) then return "shiver_venom_relic"; end
    end
    -- use_item,name=aquipotent_nautilus,if=cooldown.summon_darkglare.remains>=25&(cooldown.deathbolt.remains|!talent.deathbolt.enabled)
    if I.AquipotentNautilus:IsEquipReady() and Settings.Commons.UseTrinkets and (S.SummonDarkglare:CooldownRemainsP() >= 25 and (bool(S.Deathbolt:CooldownRemainsP()) or not S.Deathbolt:IsAvailable())) then
      if HR.Cast(I.AquipotentNautilus, nil, Settings.Commons.TrinketDisplayStyle) then return "aquipotent_nautilus"; end
    end
    -- use_item,name=tidestorm_codex,if=cooldown.summon_darkglare.remains>=25&(cooldown.deathbolt.remains|!talent.deathbolt.enabled)
    if I.TidestormCodex:IsEquipReady() and Settings.Commons.UseTrinkets and (S.SummonDarkglare:CooldownRemainsP() >= 25 and (bool(S.Deathbolt:CooldownRemainsP()) or not S.Deathbolt:IsAvailable())) then
      if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle) then return "tidestorm_codex"; end
    end
    -- use_item,name=vial_of_storms,if=cooldown.summon_darkglare.remains>=25&(cooldown.deathbolt.remains|!talent.deathbolt.enabled)
    if I.VialofStorms:IsEquipReady() and Settings.Commons.UseTrinkets and (S.SummonDarkglare:CooldownRemainsP() >= 25 and (bool(S.Deathbolt:CooldownRemainsP()) or not S.Deathbolt:IsAvailable())) then
      if HR.Cast(I.VialofStorms, nil, Settings.Commons.TrinketDisplayStyle) then return "vial_of_storms"; end
    end
    -- worldvein_resonance,if=buff.lifeblood.stack<3
    if S.WorldveinResonance:IsCastableP() and (Player:BuffStackP(S.LifebloodBuff) < 3) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 63"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 67"; end
    end
  end
  DbRefresh = function()
    -- siphon_life,line_cd=15,if=(dot.siphon_life.remains%dot.siphon_life.duration)<=(dot.agony.remains%dot.agony.duration)&(dot.siphon_life.remains%dot.siphon_life.duration)<=(dot.corruption.remains%dot.corruption.duration)&dot.siphon_life.remains<dot.siphon_life.duration*1.3
    if S.SiphonLife:IsCastableP() and ((Target:DebuffRemainsP(S.SiphonLifeDebuff) / S.SiphonLifeDebuff:BaseDuration()) <= (Target:DebuffRemainsP(S.AgonyDebuff) / S.AgonyDebuff:BaseDuration()) and (Target:DebuffRemainsP(S.SiphonLifeDebuff) / S.SiphonLifeDebuff:BaseDuration()) <= (Target:DebuffRemainsP(S.CorruptionDebuff) / S.CorruptionDebuff:BaseDuration()) and Target:DebuffRemainsP(S.SiphonLifeDebuff) < S.SiphonLifeDebuff:BaseDuration() * 1.3) then
      if HR.Cast(S.SiphonLife) then return "siphon_life 69"; end
    end
    -- agony,line_cd=15,if=(dot.agony.remains%dot.agony.duration)<=(dot.corruption.remains%dot.corruption.duration)&(dot.agony.remains%dot.agony.duration)<=(dot.siphon_life.remains%dot.siphon_life.duration)&dot.agony.remains<dot.agony.duration*1.3
    if S.Agony:IsCastableP() and ((Target:DebuffRemainsP(S.AgonyDebuff) / S.AgonyDebuff:BaseDuration()) <= (Target:DebuffRemainsP(S.CorruptionDebuff) / S.CorruptionDebuff:BaseDuration()) and (Target:DebuffRemainsP(S.AgonyDebuff) / S.AgonyDebuff:BaseDuration()) <= (Target:DebuffRemainsP(S.SiphonLifeDebuff) / S.SiphonLifeDebuff:BaseDuration()) and Target:DebuffRemainsP(S.AgonyDebuff) < S.AgonyDebuff:BaseDuration() * 1.3) then
      if HR.Cast(S.Agony) then return "agony 91"; end
    end
    -- corruption,line_cd=15,if=(dot.corruption.remains%dot.corruption.duration)<=(dot.agony.remains%dot.agony.duration)&(dot.corruption.remains%dot.corruption.duration)<=(dot.siphon_life.remains%dot.siphon_life.duration)&dot.corruption.remains<dot.corruption.duration*1.3
    if S.Corruption:IsCastableP() and ((Target:DebuffRemainsP(S.CorruptionDebuff) / S.CorruptionDebuff:BaseDuration()) <= (Target:DebuffRemainsP(S.AgonyDebuff) / S.AgonyDebuff:BaseDuration()) and (Target:DebuffRemainsP(S.CorruptionDebuff) / S.CorruptionDebuff:BaseDuration()) <= (Target:DebuffRemainsP(S.SiphonLifeDebuff) / S.SiphonLifeDebuff:BaseDuration()) and Target:DebuffRemainsP(S.CorruptionDebuff) < S.CorruptionDebuff:BaseDuration() * 1.3) then
      if HR.Cast(S.Corruption) then return "corruption 113"; end
    end
  end
  Dots = function()
    -- seed_of_corruption,if=dot.corruption.remains<=action.seed_of_corruption.cast_time+time_to_shard+4.2*(1-talent.creeping_death.enabled*0.15)&spell_targets.seed_of_corruption_aoe>=3+raid_event.invulnerable.up+talent.writhe_in_agony.enabled&!dot.seed_of_corruption.remains&!action.seed_of_corruption.in_flight
    if S.SeedofCorruption:IsCastableP() and (Target:DebuffRemainsP(S.CorruptionDebuff) <= S.SeedofCorruption:CastTime() + time_to_shard + 4.2 * (1 - num(S.CreepingDeath:IsAvailable()) * 0.15) and EnemiesCount >= 3 + num(S.WritheInAgony:IsAvailable()) and Target:DebuffDownP(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight()) then
      if HR.Cast(S.SeedofCorruption) then return "seed_of_corruption 135"; end
    end
    -- agony,target_if=min:remains,if=talent.creeping_death.enabled&active_dot.agony<6&target.time_to_die>10&(remains<=gcd|cooldown.summon_darkglare.remains>10&(remains<5|!azerite.pandemic_invocation.rank&refreshable))
    if S.Agony:IsCastableP() then
      if HR.CastTargetIf(S.Agony, 40, "min", EvaluateTargetIfFilterAgony160, EvaluateTargetIfAgony201) then return "agony 203" end
    end
    -- agony,target_if=min:remains,if=!talent.creeping_death.enabled&active_dot.agony<8&target.time_to_die>10&(remains<=gcd|cooldown.summon_darkglare.remains>10&(remains<5|!azerite.pandemic_invocation.rank&refreshable))
    if S.Agony:IsCastableP() then
      if HR.CastTargetIf(S.Agony, 40, "min", EvaluateTargetIfFilterAgony207, EvaluateTargetIfAgony248) then return "agony 250" end
    end
    -- siphon_life,target_if=min:remains,if=(active_dot.siphon_life<8-talent.creeping_death.enabled-spell_targets.sow_the_seeds_aoe)&target.time_to_die>10&refreshable&(!remains&spell_targets.seed_of_corruption_aoe=1|cooldown.summon_darkglare.remains>soul_shard*action.unstable_affliction.execute_time)
    if S.SiphonLife:IsCastableP() then
      if HR.CastTargetIf(S.SiphonLife, 40, "min", EvaluateTargetIfFilterSiphonLife254, EvaluateTargetIfSiphonLife293) then return "siphon_life 295" end
    end
    -- corruption,cycle_targets=1,if=spell_targets.seed_of_corruption_aoe<3+raid_event.invulnerable.up+talent.writhe_in_agony.enabled&(remains<=gcd|cooldown.summon_darkglare.remains>10&refreshable)&target.time_to_die>10
    if S.Corruption:IsCastableP() then
      if HR.CastCycle(S.Corruption, 40, EvaluateCycleCorruption300) then return "corruption 318" end
    end
  end
  Fillers = function()
    -- unstable_affliction,line_cd=15,if=cooldown.deathbolt.remains<=gcd*2&spell_targets.seed_of_corruption_aoe=1+raid_event.invulnerable.up&cooldown.summon_darkglare.remains>20
    if S.UnstableAffliction:IsReadyP() and (S.Deathbolt:CooldownRemainsP() <= Player:GCD() * 2 and EnemiesCount == 1 and S.SummonDarkglare:CooldownRemainsP() > 20) then
      if HR.Cast(S.UnstableAffliction) then return "unstable_affliction 319"; end
    end
    -- call_action_list,name=db_refresh,if=talent.deathbolt.enabled&spell_targets.seed_of_corruption_aoe=1+raid_event.invulnerable.up&(dot.agony.remains<dot.agony.duration*0.75|dot.corruption.remains<dot.corruption.duration*0.75|dot.siphon_life.remains<dot.siphon_life.duration*0.75)&cooldown.deathbolt.remains<=action.agony.gcd*4&cooldown.summon_darkglare.remains>20
    if (S.Deathbolt:IsAvailable() and EnemiesCount == 1 and (Target:DebuffRemainsP(S.AgonyDebuff) < S.AgonyDebuff:BaseDuration() * 0.75 or Target:DebuffRemainsP(S.CorruptionDebuff) < S.CorruptionDebuff:BaseDuration() * 0.75 or Target:DebuffRemainsP(S.SiphonLifeDebuff) < S.SiphonLifeDebuff:BaseDuration() * 0.75) and S.Deathbolt:CooldownRemainsP() <= S.Agony:GCD() * 4 and S.SummonDarkglare:CooldownRemainsP() > 20) then
      local ShouldReturn = DbRefresh(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=db_refresh,if=talent.deathbolt.enabled&spell_targets.seed_of_corruption_aoe=1+raid_event.invulnerable.up&cooldown.summon_darkglare.remains<=soul_shard*action.agony.gcd+action.agony.gcd*3&(dot.agony.remains<dot.agony.duration*1|dot.corruption.remains<dot.corruption.duration*1|dot.siphon_life.remains<dot.siphon_life.duration*1)
    if (S.Deathbolt:IsAvailable() and EnemiesCount == 1 and S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.Agony:GCD() + S.Agony:GCD() * 3 and (Target:DebuffRemainsP(S.AgonyDebuff) < S.AgonyDebuff:BaseDuration() * 1 or Target:DebuffRemainsP(S.CorruptionDebuff) < S.CorruptionDebuff:BaseDuration() * 1 or Target:DebuffRemainsP(S.SiphonLifeDebuff) < S.SiphonLifeDebuff:BaseDuration() * 1)) then
      local ShouldReturn = DbRefresh(); if ShouldReturn then return ShouldReturn; end
    end
    -- deathbolt,if=cooldown.summon_darkglare.remains>=30+gcd|cooldown.summon_darkglare.remains>140
    if S.Deathbolt:IsCastableP() and (S.SummonDarkglare:CooldownRemainsP() >= 30 + Player:GCD() or S.SummonDarkglare:CooldownRemainsP() > 140) then
      if HR.Cast(S.Deathbolt) then return "deathbolt 381"; end
    end
    -- shadow_bolt,if=buff.movement.up&buff.nightfall.remains
    if S.ShadowBolt:IsCastableP() and (Player:IsMoving() and Player:BuffP(S.NightfallBuff)) then
      if HR.Cast(S.ShadowBolt) then return "shadow_bolt 387"; end
    end
    -- agony,if=buff.movement.up&!(talent.siphon_life.enabled&(prev_gcd.1.agony&prev_gcd.2.agony&prev_gcd.3.agony)|prev_gcd.1.agony)
    if S.Agony:IsCastableP() and (Player:IsMoving() and not (S.SiphonLife:IsAvailable() and (Player:PrevGCDP(1, S.Agony) and Player:PrevGCDP(2, S.Agony) and Player:PrevGCDP(3, S.Agony)) or Player:PrevGCDP(1, S.Agony))) then
      if HR.Cast(S.Agony) then return "agony 391"; end
    end
    -- siphon_life,if=buff.movement.up&!(prev_gcd.1.siphon_life&prev_gcd.2.siphon_life&prev_gcd.3.siphon_life)
    if S.SiphonLife:IsCastableP() and (Player:IsMoving() and not (Player:PrevGCDP(1, S.SiphonLife) and Player:PrevGCDP(2, S.SiphonLife) and Player:PrevGCDP(3, S.SiphonLife))) then
      if HR.Cast(S.SiphonLife) then return "siphon_life 403"; end
    end
    -- corruption,if=buff.movement.up&!prev_gcd.1.corruption&!talent.absolute_corruption.enabled
    if S.Corruption:IsCastableP() and (Player:IsMoving() and not Player:PrevGCDP(1, S.Corruption) and not S.AbsoluteCorruption:IsAvailable()) then
      if HR.Cast(S.Corruption) then return "corruption 411"; end
    end
    --  drain_life,if=buff.inevitable_demise.stack>10&target.time_to_die<=10
    if S.DrainLife:IsCastableP() and (Player:BuffStackP(S.InevitableDemiseBuff) > 10 and Target:TimeToDie() <= 10) then
      if HR.Cast(S.DrainLife) then return "drain_life 412"; end
    end
    -- drain_life,if=talent.siphon_life.enabled&buff.inevitable_demise.stack>=50-20*(spell_targets.seed_of_corruption_aoe-raid_event.invulnerable.up>=2)&dot.agony.remains>5*spell_haste&dot.corruption.remains>gcd&(dot.siphon_life.remains>gcd|!talent.siphon_life.enabled)&(debuff.haunt.remains>5*spell_haste|!talent.haunt.enabled)&contagion>5*spell_haste
    if S.DrainLife:IsCastableP() and (S.SiphonLife:IsAvailable() and Player:BuffStackP(S.InevitableDemiseBuff) >= 50 - 20 * num(EnemiesCount >= 2) and Target:DebuffRemainsP(S.AgonyDebuff) > 5 * Player:SpellHaste() and Target:DebuffRemainsP(S.CorruptionDebuff) > Player:GCD() and (Target:DebuffRemainsP(S.SiphonLifeDebuff) > Player:GCD() or not S.SiphonLife:IsAvailable()) and (Target:DebuffRemainsP(S.HauntDebuff) > 5 * Player:SpellHaste() or not S.Haunt:IsAvailable()) and contagion > 5 * Player:SpellHaste()) then
      if HR.Cast(S.DrainLife) then return "drain_life 413"; end
    end
    -- drain_life,if=talent.writhe_in_agony.enabled&buff.inevitable_demise.stack>=50-20*(spell_targets.seed_of_corruption_aoe-raid_event.invulnerable.up>=3)-5*(spell_targets.seed_of_corruption_aoe-raid_event.invulnerable.up=2)&dot.agony.remains>5*spell_haste&dot.corruption.remains>gcd&(debuff.haunt.remains>5*spell_haste|!talent.haunt.enabled)&contagion>5*spell_haste
    if S.DrainLife:IsCastableP() and (S.WritheInAgony:IsAvailable() and Player:BuffStackP(S.InevitableDemiseBuff) >= 50 - 20 * num(EnemiesCount >= 3) - 5 * num(EnemiesCount == 2) and Target:DebuffRemainsP(S.AgonyDebuff) > 5 * Player:SpellHaste() and Target.DebuffRemainsP(S.CorruptionDebuff) > Player:GCD() and (Target:DebuffRemainsP(S.HauntDebuff) > 5 * Player:SpellHaste() or not S.Haunt:IsAvailable()) and contagion > 5 * Player:SpellHaste()) then
      if HR.Cast(S.DrainLife) then return "drain_life 414"; end
    end
    -- drain_life,if=talent.absolute_corruption.enabled&buff.inevitable_demise.stack>=50-20*(spell_targets.seed_of_corruption_aoe-raid_event.invulnerable.up>=4)&dot.agony.remains>5*spell_haste&(debuff.haunt.remains>5*spell_haste|!talent.haunt.enabled)&contagion>5*spell_haste
    if S.DrainLife:IsCastableP() and (S.AbsoluteCorruption:IsAvailable() and Player:BuffStackP(S.InevitableDemiseBuff) >= 50 - 20 * num(EnemiesCount >= 4) and Target:DebuffRemainsP(S.AgonyDebuff) > 5 * Player:SpellHaste() and (Target:DebuffRemainsP(S.HauntDebuff) > 5 * Player:SpellHaste() or not S.Haunt:IsAvailable()) and contagion > 5 * Player:SpellHaste()) then
      if HR.Cast(S.DrainLife) then return "drain_life 415"; end
    end
    -- haunt
    if S.Haunt:IsCastableP() then
      if HR.Cast(S.Haunt) then return "haunt 461"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 463"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast 465"; end
    end
    -- concentrated_flame,if=!dot.concentrated_flame_burn.remains&!action.concentrated_flame.in_flight
    if S.ConcentratedFlame:IsCastableP() and (Target:DebuffDownP(S.ConcentratedFlameBurn) and not S.ConcentratedFlame:InFlight()) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame 467"; end
    end
    -- drain_soul,interrupt_global=1,chain=1,interrupt=1,cycle_targets=1,if=target.time_to_die<=gcd
    if S.DrainSoul:IsCastableP() then
      if HR.CastCycle(S.DrainSoul, 40, EvaluateCycleDrainSoul479) then return "drain_soul 481" end
    end
    -- drain_soul,target_if=min:debuff.shadow_embrace.remains,chain=1,interrupt_if=ticks_remain<5,interrupt_global=1,if=talent.shadow_embrace.enabled&variable.maintain_se&!debuff.shadow_embrace.remains
    if S.DrainSoul:IsCastableP() then
      if HR.CastTargetIf(S.DrainSoul, 40, "min", EvaluateTargetIfFilterDrainSoul485, EvaluateTargetIfDrainSoul498) then return "drain_soul 500" end
    end
    -- drain_soul,target_if=min:debuff.shadow_embrace.remains,chain=1,interrupt_if=ticks_remain<5,interrupt_global=1,if=talent.shadow_embrace.enabled&variable.maintain_se
    if S.DrainSoul:IsCastableP() then
      if HR.CastTargetIf(S.DrainSoul, 40, "min", EvaluateTargetIfFilterDrainSoul504, EvaluateTargetIfDrainSoul515) then return "drain_soul 517" end
    end
    -- drain_soul,interrupt_global=1,chain=1,interrupt=1
    if S.DrainSoul:IsCastableP() then
      if HR.Cast(S.DrainSoul) then return "drain_soul 518"; end
    end
    -- shadow_bolt,cycle_targets=1,if=talent.shadow_embrace.enabled&variable.maintain_se&!debuff.shadow_embrace.remains&!action.shadow_bolt.in_flight
    if S.ShadowBolt:IsCastableP() then
      if HR.CastCycle(S.ShadowBolt, 40, EvaluateCycleShadowBolt524) then return "shadow_bolt 536" end
    end
    -- shadow_bolt,target_if=min:debuff.shadow_embrace.remains,if=talent.shadow_embrace.enabled&variable.maintain_se
    if S.ShadowBolt:IsCastableP() then
      if HR.CastTargetIf(S.ShadowBolt, 40, "min", EvaluateTargetIfFilterShadowBolt540, EvaluateTargetIfShadowBolt551) then return "shadow_bolt 553" end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastableP() then
      if HR.Cast(S.ShadowBolt) then return "shadow_bolt 554"; end
    end
  end
  Spenders = function()
    -- unstable_affliction,if=cooldown.summon_darkglare.remains<=soul_shard*(execute_time+azerite.dreadful_calling.rank)&(!talent.deathbolt.enabled|cooldown.deathbolt.remains<=soul_shard*execute_time)&(talent.sow_the_seeds.enabled|dot.phantom_singularity.remains|dot.vile_taint.remains)
    if S.UnstableAffliction:IsReadyP() and (S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * (S.UnstableAffliction:ExecuteTime() + S.DreadfulCalling:AzeriteRank()) and (not S.Deathbolt:IsAvailable() or S.Deathbolt:CooldownRemainsP() <= Player:SoulShardsP() * S.UnstableAffliction:ExecuteTime()) and (S.SowtheSeeds:IsAvailable() or Target:DebuffP(S.PhantomSingularityDebuff) or Target:DebuffP(S.VileTaint))) then
      if HR.Cast(S.UnstableAffliction) then return "unstable_affliction 556"; end
    end
    -- call_action_list,name=fillers,if=(cooldown.summon_darkglare.remains<time_to_shard*(5-soul_shard)|cooldown.summon_darkglare.up)&time_to_die>cooldown.summon_darkglare.remains
    if ((S.SummonDarkglare:CooldownRemainsP() < time_to_shard * (5 - Player:SoulShardsP()) or S.SummonDarkglare:CooldownUpP()) and Target:TimeToDie() > S.SummonDarkglare:CooldownRemainsP()) then
      local ShouldReturn = Fillers(); if ShouldReturn then return ShouldReturn; end
    end
    -- seed_of_corruption,if=variable.use_seed
    if S.SeedofCorruption:IsCastableP() and (bool(VarUseSeed)) then
      if HR.Cast(S.SeedofCorruption) then return "seed_of_corruption 590"; end
    end
    -- unstable_affliction,if=!variable.use_seed&!prev_gcd.1.summon_darkglare&(talent.deathbolt.enabled&cooldown.deathbolt.remains<=execute_time&!azerite.cascading_calamity.enabled|(soul_shard>=5&spell_targets.seed_of_corruption_aoe<2|soul_shard>=2&spell_targets.seed_of_corruption_aoe>=2)&target.time_to_die>4+execute_time&spell_targets.seed_of_corruption_aoe=1|target.time_to_die<=8+execute_time*soul_shard)
    if S.UnstableAffliction:IsReadyP() and (not bool(VarUseSeed) and not Player:PrevGCDP(1, S.SummonDarkglare) and (S.Deathbolt:IsAvailable() and S.Deathbolt:CooldownRemainsP() <= S.UnstableAffliction:ExecuteTime() and not S.CascadingCalamity:AzeriteEnabled() or (Player:SoulShardsP() >= 5 and EnemiesCount < 2 or Player:SoulShardsP() >= 2 and EnemiesCount >= 2) and Target:TimeToDie() > 4 + S.UnstableAffliction:ExecuteTime() and EnemiesCount == 1 or Target:TimeToDie() <= 8 + S.UnstableAffliction:ExecuteTime() * Player:SoulShardsP())) then
      if HR.Cast(S.UnstableAffliction) then return "unstable_affliction 594"; end
    end
    -- unstable_affliction,if=!variable.use_seed&contagion<=cast_time+variable.padding
    if S.UnstableAffliction:IsReadyP() and (not bool(VarUseSeed) and contagion <= S.UnstableAffliction:CastTime() + VarPadding) then
      if HR.Cast(S.UnstableAffliction) then return "unstable_affliction 624"; end
    end
    -- unstable_affliction,cycle_targets=1,if=!variable.use_seed&(!talent.deathbolt.enabled|cooldown.deathbolt.remains>time_to_shard|soul_shard>1)&(!talent.vile_taint.enabled|soul_shard>1)&contagion<=cast_time+variable.padding&(!azerite.cascading_calamity.enabled|buff.cascading_calamity.remains>time_to_shard)
    if S.UnstableAffliction:IsReadyP() then
      if HR.CastCycle(S.UnstableAffliction, 40, EvaluateCycleUnstableAffliction640) then return "unstable_affliction 662" end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- variable,name=use_seed,value=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption_aoe>=3+raid_event.invulnerable.up|talent.siphon_life.enabled&spell_targets.seed_of_corruption>=5+raid_event.invulnerable.up|spell_targets.seed_of_corruption>=8+raid_event.invulnerable.up
    if (true) then
      VarUseSeed = num(S.SowtheSeeds:IsAvailable() and EnemiesCount >= 3 or S.SiphonLife:IsAvailable() and EnemiesCount >= 5 or EnemiesCount >= 8)
    end
    -- variable,name=padding,op=set,value=action.shadow_bolt.execute_time*azerite.cascading_calamity.enabled
    if (true) then
      VarPadding = S.ShadowBolt:ExecuteTime() * num(S.CascadingCalamity:AzeriteEnabled())
    end
    -- variable,name=padding,op=reset,value=gcd,if=azerite.cascading_calamity.enabled&(talent.drain_soul.enabled|talent.deathbolt.enabled&cooldown.deathbolt.remains<=gcd)
    if (S.CascadingCalamity:AzeriteEnabled() and (S.DrainSoul:IsAvailable() or S.Deathbolt:IsAvailable() and S.Deathbolt:CooldownRemainsP() <= Player:GCD())) then
      VarPadding = 0
    end
    -- variable,name=maintain_se,value=spell_targets.seed_of_corruption_aoe<=1+talent.writhe_in_agony.enabled+talent.absolute_corruption.enabled*2+(talent.writhe_in_agony.enabled&talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption_aoe>2)+(talent.siphon_life.enabled&!talent.creeping_death.enabled&!talent.drain_soul.enabled)+raid_event.invulnerable.up
    if (true) then
      VarMaintainSe = num(EnemiesCount <= 1 + num(S.WritheInAgony:IsAvailable()) + num(S.AbsoluteCorruption:IsAvailable()) * 2 + num((S.WritheInAgony:IsAvailable() and S.SowtheSeeds:IsAvailable() and EnemiesCount > 2)) + num((S.SiphonLife:IsAvailable() and not S.CreepingDeath:IsAvailable() and not S.DrainSoul:IsAvailable())))
    end
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- drain_soul,interrupt_global=1,chain=1,cycle_targets=1,if=target.time_to_die<=gcd&soul_shard<5
    if S.DrainSoul:IsCastableP() then
      if HR.CastCycle(S.DrainSoul, 40, EvaluateCycleDrainSoul711) then return "drain_soul 713" end
    end
    -- haunt,if=spell_targets.seed_of_corruption_aoe<=2+raid_event.invulnerable.up
    if S.Haunt:IsCastableP() and (EnemiesCount <= 2) then
      if HR.Cast(S.Haunt) then return "haunt 714"; end
    end
    -- summon_darkglare,if=summon_darkglare,if=dot.agony.ticking&dot.corruption.ticking&(buff.active_uas.stack=5|soul_shard=0|dot.phantom_singularity.remains&dot.phantom_singularity.remains<=gcd)&(!talent.phantom_singularity.enabled|dot.phantom_singularity.remains)&(!talent.deathbolt.enabled|cooldown.deathbolt.remains<=gcd|!cooldown.deathbolt.remains|spell_targets.seed_of_corruption_aoe>1+raid_event.invulnerable.up)
    if S.SummonDarkglare:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.AgonyDebuff) and Target:DebuffP(S.CorruptionDebuff) and (ActiveUAs() == 5 or Player:SoulShardsP() == 0 or Target:DebuffP(S.PhantomSingularityDebuff) and Target:DebuffRemainsP(S.PhantomSingularityDebuff) <= Player:GCD()) and (not S.PhantomSingularity:IsAvailable() or Target:DebuffP(S.PhantomSingularityDebuff)) and (not S.Deathbolt:IsAvailable() or S.Deathbolt:CooldownRemainsP() <= Player:GCD() or S.Deathbolt:CooldownUpP() or EnemiesCount > 1)) then
      if HR.Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare 716"; end
    end
    -- deathbolt,if=cooldown.summon_darkglare.remains&spell_targets.seed_of_corruption_aoe=1+raid_event.invulnerable.up&(!essence.vision_of_perfection.minor&!azerite.dreadful_calling.rank|cooldown.summon_darkglare.remains>30)
    if S.Deathbolt:IsCastableP() and (bool(S.SummonDarkglare:CooldownRemainsP()) and EnemiesCount == 1 and (not S.VisionofPerfectionMinor:IsAvailable() and not bool(S.DreadfulCalling:AzeriteRank()) or S.SummonDarkglare:CooldownRemainsP() > 30)) then
      if HR.Cast(S.Deathbolt) then return "deathbolt 734"; end
    end
    -- the_unbound_force,if=buff.reckless_force.remains
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force 744"; end
    end
    -- agony,target_if=min:dot.agony.remains,if=remains<=gcd+action.shadow_bolt.execute_time&target.time_to_die>8
    if S.Agony:IsCastableP() then
      if HR.CastTargetIf(S.Agony, 40, "min", EvaluateTargetIfFilterAgony751, EvaluateTargetIfAgony768) then return "agony 770" end
    end
    -- memory_of_lucid_dreams,if=time<30
    if S.MemoryofLucidDreams:IsCastableP() and (HL.CombatTime() < 30) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 771"; end
    end
    -- # Temporary fix to make sure azshara's font doesn't break darkglare usage.
    -- agony,line_cd=30,if=time>30&cooldown.summon_darkglare.remains<=15&equipped.169314
    if S.Agony:IsCastableP() and (HL.CombatTime() > 30 and S.SummonDarkglare:CooldownRemainsP() <= 15 and I.AzsharasFontofPower:IsEquipped()) then
      if HR.Cast(S.Agony) then return "agony 772"; end
    end
    -- corruption,line_cd=30,if=time>30&cooldown.summon_darkglare.remains<=15&equipped.169314&!talent.absolute_corruption.enabled&(talent.siphon_life.enabled|spell_targets.seed_of_corruption_aoe>1&spell_targets.seed_of_corruption_aoe<=3)
    if S.Corruption:IsCastableP() and (HL.CombatTime() > 30 and S.SummonDarkglare:CooldownRemainsP() <= 15 and I.AzsharasFontofPower:IsEquipped() and not S.AbsoluteCorruption:IsAvailable() and (S.SiphonLife:IsAvailable() or EnemiesCount > 1 and EnemiesCount <= 3)) then
      if HR.Cast(S.Corruption) then return "corruption 773"; end
    end
    -- siphon_life,line_cd=30,if=time>30&cooldown.summon_darkglare.remains<=15&equipped.169314
    if S.SiphonLife:IsCastableP() and (HL.CombatTime() > 30 and S.SummonDarkglare:CooldownRemainsP() <= 15 and I.AzsharasFontofPower:IsEquipped()) then
      if HR.Cast(S.SiphonLife) then return "siphon_life 774"; end
    end
    -- unstable_affliction,target_if=!contagion&target.time_to_die<=8
    if S.UnstableAffliction:IsReadyP() then
      if HR.CastCycle(S.UnstableAffliction, 40, EvaluateCycleUnstableAffliction781) then return "unstable_affliction 783" end
    end
    -- drain_soul,target_if=min:debuff.shadow_embrace.remains,cancel_if=ticks_remain<5,if=talent.shadow_embrace.enabled&variable.maintain_se&debuff.shadow_embrace.remains&debuff.shadow_embrace.remains<=gcd*2
    if S.DrainSoul:IsCastableP() then
      if HR.CastTargetIf(S.DrainSoul, 40, "min", EvaluateTargetIfFilterDrainSoul787, EvaluateTargetIfDrainSoul802) then return "drain_soul 804" end
    end
    -- shadow_bolt,target_if=min:debuff.shadow_embrace.remains,if=talent.shadow_embrace.enabled&variable.maintain_se&debuff.shadow_embrace.remains&debuff.shadow_embrace.remains<=execute_time*2+travel_time&!action.shadow_bolt.in_flight
    if S.ShadowBolt:IsCastableP() then
      if HR.CastTargetIf(S.ShadowBolt, 40, "min", EvaluateTargetIfFilterShadowBolt808, EvaluateTargetIfShadowBolt835) then return "shadow_bolt 837" end
    end
    -- phantom_singularity,target_if=max:target.time_to_die,if=time>35&target.time_to_die>16*spell_haste&(!essence.vision_of_perfection.minor&!azerite.dreadful_calling.rank|cooldown.summon_darkglare.remains>45+soul_shard*azerite.dreadful_calling.rank|cooldown.summon_darkglare.remains<15*spell_haste+soul_shard*azerite.dreadful_calling.rank)
    if S.PhantomSingularity:IsCastableP() then
      if HR.CastTargetIf(S.PhantomSingularity, 40, "max", EvaluateTargetIfFilterPhantomSingularity841, EvaluateTargetIfPhantomSingularity850) then return "phantom_singularity 852" end
    end
    -- unstable_affliction,target_if=min:contagion,if=!variable.use_seed&soul_shard=5
    if S.UnstableAffliction:IsReadyP() then
      if HR.CastTargetIf(S.UnstableAffliction, 40, "min", EvaluateTargetIfFilterUnstableAffliction865, EvaluateTargetIfUnstableAffliction870) then return "unstable_affliction 872" end
    end
    -- seed_of_corruption,if=variable.use_seed&soul_shard=5
    if S.SeedofCorruption:IsCastableP() and (bool(VarUseSeed) and Player:SoulShardsP() == 5) then
      if HR.Cast(S.SeedofCorruption) then return "seed_of_corruption 873"; end
    end
    -- call_action_list,name=dots
    if (true) then
      local ShouldReturn = Dots(); if ShouldReturn then return ShouldReturn; end
    end
    -- vile_taint,target_if=max:target.time_to_die,if=time>15&target.time_to_die>=10&(cooldown.summon_darkglare.remains>30|cooldown.summon_darkglare.remains<10&dot.agony.remains>=10&dot.corruption.remains>=10&(dot.siphon_life.remains>=10|!talent.siphon_life.enabled))
    if S.VileTaint:IsCastableP() then
      if HR.CastTargetIf(S.VileTaint, 40, "max", EvaluateTargetIfFilterVileTaint856, EvaluateTargetIfVileTaint859) then return "vile_taint 861" end
    end
    -- use_item,name=azsharas_font_of_power,if=time<=3
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and (HL.CombatTime() <= 3) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 879"; end
    end
    -- phantom_singularity,if=time<=35
    if S.PhantomSingularity:IsCastableP() and (HL.CombatTime() <= 35) then
      if HR.Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity) then return "phantom_singularity 881"; end
    end
    -- vile_taint,if=time<15
    if S.VileTaint:IsCastableP() and (HL.CombatTime() < 15) then
      if HR.Cast(S.VileTaint) then return "vile_taint 883"; end
    end
    -- guardian_of_azeroth,if=cooldown.summon_darkglare.remains<15+soul_shard*azerite.dreadful_calling.enabled|(azerite.dreadful_calling.rank|essence.vision_of_perfection.rank)&time>30&target.time_to_die>=210)&(dot.phantom_singularity.remains|dot.vile_taint.remains|!talent.phantom_singularity.enabled&!talent.vile_taint.enabled)|target.time_to_die<30+gcd
    if S.GuardianofAzeroth:IsCastableP() and (S.SummonDarkglare:CooldownRemainsP() < 15 + Player:SoulShardsP() * num(S.DreadfulCalling:AzeriteEnabled()) or ((S.DreadfulCalling:AzeriteEnabled() or S.VisionofPerfectionMinor:IsAvailable()) and HL.CombatTime() > 30 and Target:TimeToDie() >= 210) and (Target:DebuffP(S.PhantomSingularityDebuff) or Target:DebuffP(S.VileTaint) or not S.PhantomSingularity:IsAvailable() and not S.VileTaint:IsAvailable()) or Target:TimeToDie() < 30 + Player:GCD()) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 884"; end
    end
    -- dark_soul,if=cooldown.summon_darkglare.remains<15+soul_shard*azerite.dreadful_calling.enabled&(dot.phantom_singularity.remains|dot.vile_taint.remains|!talent.phantom_singularity.enabled&!talent.vile_taint.enabled)|target.time_to_die<20+gcd|spell_targets.seed_of_corruption_aoe>1+raid_event.invulnerable.up
    if S.DarkSoul:IsCastableP() and HR.CDsON() and (S.SummonDarkglare:CooldownRemainsP() < 15 + Player:SoulShardsP() * num(S.DreadfulCalling:AzeriteEnabled()) and (Target:DebuffP(S.PhantomSingularityDebuff) or Target:DebuffP(S.PhantomSingularityDebuff) or not S.PhantomSingularity:IsAvailable() and not S.VileTaint:IsAvailable()) or Target:TimeToDie() < 20 + Player:GCD() or EnemiesCount > 1) then
      if HR.Cast(S.DarkSoul, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul 885"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 891"; end
    end
    -- call_action_list,name=spenders
    if (true) then
      local ShouldReturn = Spenders(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=fillers
    if (true) then
      local ShouldReturn = Fillers(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(27285, 10, 6)               -- Seed Explosion
end

HR.SetAPL(265, APL, Init)

--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Pet = Unit.Pet
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast  = HR.Cast
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Warlock = HR.Commons.Warlock

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
}

-- Spells
local S = Spell.Warlock.Affliction

-- Items
local I = Item.Warlock.Affliction
local TrinketsOnUseExcludes = {--  I.TrinketName:ID(),
  I.ArchitectsIngenuityCore:ID(),
  I.CosmicAspirantsBadgeofFerocity:ID(),
  I.CosmicGladiatorsBadgeofFerocity:ID(),
  I.CosmicGladiatorsResonator:ID(),
  I.DarkmoonDeckPutrescence:ID(),
  I.DreadfireVessel:ID(),
  I.EbonsoulVise:ID(),
  I.EmpyrealOrdnance:ID(),
  I.FigureheadoftheNaglfar:ID(),
  I.FlameofBattle:ID(),
  I.GlyphofAssimilation:ID(),
  I.GrimEclipse:ID(),
  I.HornofValor:ID(),
  I.InscrutableQuantumDevice:ID(),
  I.InstructorsDivineBell:ID(),
  I.MacabreSheetMusic:ID(),
  I.MoonlitPrism:ID(),
  I.MrrgriasFavor:ID(),
  I.ObeliskoftheVoid:ID(),
  I.OverflowingAnimaCage:ID(),
  I.ResonantReservoir:ID(),
  I.ScarsofFraternalStrife:ID(),
  I.ShadowedOrbofTorment:ID(),
  I.SinfulAspirantsBadgeofFerocity:ID(),
  I.SinfulGladiatorsBadgeofFerocity:ID(),
  I.SoulIgniter:ID(),
  I.SoullettingRuby:ID(),
  I.SunbloodAmethyst:ID(),
  I.TabletofDespair:ID(),
  I.TheFirstSigil:ID(),
  I.ToeKneesPromise:ID(),
  I.UnchainedGladiatorsShackles:ID(),
  I.WakenersFrond:ID(),
}

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

-- Enemies
local Enemies40y, Enemies40yCount, Enemies10ySplash, EnemiesCount10ySplash
local EnemiesAgonyCount, EnemiesSeedofCorruptionCount, EnemiesSiphonLifeCount, EnemiesVileTaintCount = 0, 0, 0, 0
local EnemiesWithUnstableAfflictionDebuff
local FirstTarGUID
local FightRemains

-- Legendaries
local MaleficWrathEquipped = Player:HasLegendaryEquipped(168)

-- Stuns

-- Rotation Variables
local VarDamageTrinket = false
local VarSpecialEquipped = false
local VarTrinketOne = false
local VarTrinketTwo = false
local VarTrinketSplit = false
local VarDoTsTicking = false
local VarTrinketDelay = 0

-- Register
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
  S.Haunt:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()
S.Haunt:RegisterInFlight()

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
  MaleficWrathEquipped = Player:HasLegendaryEquipped(168)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarDamageTrinket = false
  VarSpecialEquipped = false
  VarTrinketOne = false
  VarTrinketTwo = false
  VarTrinketSplit = false
  VarDoTsTicking = false
  VarTrinketDelay = 0
end, "PLAYER_REGEN_ENABLED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateCycleAgonyRemains(TargetUnit)
  --dot.agony.remains<4
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 4 and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgonyRefresh(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgonyRefreshTicking(TargetUnit)
  --refreshable&dot.agony.ticking
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff) and TargetUnit:DebuffUp(S.AgonyDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLifeNotTicking(TargetUnit)
  --!dot.siphon_life.ticking
  return (TargetUnit:DebuffDown(S.SiphonLifeDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgonyNotTicking(TargetUnit)
  --!dot.agony.ticking
  return (TargetUnit:DebuffDown(S.AgonyDebuff)and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLifeRemains(TargetUnit)
  --dot.siphon_life.remains<4
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 4) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleSiphonLifeRefresh(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.SiphonLifeDebuff)) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleCorruptionRemains(TargetUnit)
  --dot.corruption.remains<2
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 2) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleCorruptionRefresh(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.CorruptionDebuff)) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleUnstableAfflictionRemains(TargetUnit)
  --dot.unstable_affliction.remains<4
  if (EnemiesWithUnstableAfflictionDebuff == 0 and TargetUnit:DebuffUp(S.UnstableAfflictionDebuff)) then
    return (TargetUnit:DebuffRemains(S.UnstableAfflictionDebuff) < 4) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
  else
    return ((TargetUnit:GUID() == EnemiesWithUnstableAfflictionDebuff and TargetUnit:DebuffRemains(S.UnstableAfflictionDebuff) < 4) or EnemiesWithUnstableAfflictionDebuff == 0) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
  end
end

local function EvaluateCycleUnstableAfflictionRefresh(TargetUnit)
  --refreshable
  if (EnemiesWithUnstableAfflictionDebuff == 0 and TargetUnit:DebuffUp(S.UnstableAfflictionDebuff)) then
    return (TargetUnit:DebuffRefreshable(S.UnstableAfflictionDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
  else
    return ((TargetUnit:GUID() == EnemiesWithUnstableAfflictionDebuff and TargetUnit:DebuffRefreshable(S.UnstableAfflictionDebuff)) or EnemiesWithUnstableAfflictionDebuff == 0) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
  end
end

-- Counter for Debuff on other enemies
local function CalcEnemiesDotCount(Object, Enemies)
  local debuffs = 0

  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    if CycleUnit:DebuffUp(Object) then
      debuffs = debuffs + 1
    end
  end

  return debuffs
end

local function ReturnEnemiesWithDot(Object, Enemies)
  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    --if CycleUnit:DebuffTicksRemain(Object) > 0 then
    if CycleUnit:DebuffUp(Object) then
      if Object == S.UnstableAfflictionDebuff then
        return CycleUnit:GUID()
      end
    end
  end
  return 0
end

local function Precombat()
  FirstTarGUID = Target:GUID()
  -- flask
  -- food
  -- augmentation
  -- Variable declarations moved here from trinket_split_check action list
  -- variable,name=special_equipped,value=(((equipped.empyreal_ordnance^equipped.inscrutable_quantum_device)^equipped.soulletting_ruby)^equipped.sunblood_amethyst)
  VarSpecialEquipped = (((I.EmpyrealOrdnance:IsEquipped() ~= I.InscrutableQuantumDevice:IsEquipped()) ~= I.SoullettingRuby:IsEquipped()) ~= I.SunbloodAmethyst:IsEquipped())
  -- variable,name=trinket_one,value=(trinket.1.has_proc.any&trinket.1.has_cooldown)
  VarTrinketOne = (trinket1:IsUsable())
  -- variable,name=trinket_two,value=(trinket.2.has_proc.any&trinket.2.has_cooldown)
  VarTrinketTwo = (trinket2:IsUsable())
  -- variable,name=damage_trinket,value=(!(trinket.1.has_proc.any&trinket.1.has_cooldown))|(!(trinket.2.has_proc.any&trinket.2.has_cooldown))|equipped.glyph_of_assimilation
  VarDamageTrinket = (not trinket1:IsUsable() or not trinket2:IsUsable() or I.GlyphofAssimilation:IsEquipped())
  -- variable,name=trinket_split,value=(variable.trinket_one&variable.damage_trinket)|(variable.trinket_two&variable.damage_trinket)|(variable.trinket_one^variable.special_equipped)|(variable.trinket_two^variable.special_equipped)
  VarTrinketSplit = ((VarTrinketOne and VarDamageTrinket) or (VarTrinketTwo and VarDamageTrinket) or (VarTrinketOne ~= VarSpecialEquipped) or (VarTrinketTwo ~= VarSpecialEquipped))
  -- summon_pet - Moved to APL()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=tome_of_monstrous_constructions
    if I.TomeofMonstrousConstructions:IsEquippedAndReady() then
      if Cast(I.TomeofMonstrousConstructions, nil, Settings.Commons.DisplayStyle.Trinkets) then return "tome_of_monstrous_constructions precombat 2"; end
    end
    -- use_item,name=soleahs_secret_technique
    if I.SoleahsSecretTechnique:IsEquippedAndReady() then
      if Cast(I.SoleahsSecretTechnique, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soleahs_secret_technique precombat 4"; end
    end
  end
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsReady() and Player:BuffDown(S.GrimoireofSacrificeBuff) then
    if Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 6"; end
  end
  -- snapshot_stats
  -- fleshcraft
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 8"; end
  end
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>=3
  -- Note: Not handled because we can't get splash data before the pull
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt precombat 10"; end
  end
  -- unstable_affliction
  if S.UnstableAffliction:IsReady() then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction precombat 12"; end
  end
  -- Manually added: agony
  if S.Agony:IsReady() then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony precombat 14"; end
  end
end

local function Opener()
  -- haunt,if=!dot.haunt.ticking
  if S.Haunt:IsReady() and (Target:DebuffDown(S.HauntDebuff)) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt opener 2"; end
  end
  -- unstable_affliction,if=!dot.unstable_affliction.ticking
  if S.UnstableAffliction:IsReady() and (Target:DebuffDown(S.UnstableAfflictionDebuff)) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction opener 4"; end
  end
  -- agony,if=!dot.agony.ticking
  if S.Agony:IsReady() and (Target:DebuffDown(S.AgonyDebuff)) then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony opener 6"; end
  end
  -- siphon_life,if=!dot.siphon_life.ticking
  if S.SiphonLife:IsReady() and (Target:DebuffDown(S.SiphonLifeDebuff)) then
    if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life opener 8"; end
  end
  -- corruption,if=!dot.corruption.ticking
  if S.Corruption:IsReady() and (Target:DebuffDown(S.CorruptionDebuff)) then
    if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption opener 10"; end
  end
  -- drain_soul,if=active_enemies<3&talent.shadow_embrace.enabled&debuff.shadow_embrace.stack<3
  if S.DrainSoul:IsReady() and (EnemiesCount10ySplash < 3 and S.ShadowEmbrace:IsAvailable() and Target:DebuffStack(S.ShadowEmbraceDebuff) < 3) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul opener 12"; end
  end
  -- shadow_bolt,if=active_enemies<3&!talent.drain_soul.enabled&talent.shadow_embrace.enabled&debuff.shadow_embrace.stack<3
  if S.ShadowBolt:IsReady() and (EnemiesCount10ySplash < 3 and not S.DrainSoul:IsAvailable() and S.ShadowEmbrace:IsAvailable() and Target:DebuffStack(S.ShadowEmbraceDebuff) < 3) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt opener 14"; end
  end
end

local function Covenant()
  -- impending_catastrophe,if=!talent.phantom_singularity&(cooldown.summon_darkglare.remains<10|cooldown.summon_darkglare.remains>50|cooldown.summon_darkglare.remains>25&conduit.corrupting_leer)
  if S.ImpendingCatastrophe:IsReady() and CDsON() and (not S.PhantomSingularity:IsAvailable() and (S.SummonDarkglare:CooldownRemains() < 10 or S.SummonDarkglare:CooldownRemains() > 50 or S.SummonDarkglare:CooldownRemains() > 25 and S.CorruptingLeer:ConduitEnabled())) then
    if Cast(S.ImpendingCatastrophe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ImpendingCatastrophe)) then return "impending_catastrophe covenant 2"; end
  end
  -- impending_catastrophe,if=talent.phantom_singularity&dot.phantom_singularity.ticking
  if S.ImpendingCatastrophe:IsReady() and CDsON() and (S.PhantomSingularity:IsAvailable() and Target:DebuffUp(S.PhantomSingularityDebuff)) then
    if Cast(S.ImpendingCatastrophe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ImpendingCatastrophe)) then return "impending_catastrophe covenant 4"; end
  end
  -- decimating_bolt,if=cooldown.summon_darkglare.remains>5&(debuff.haunt.remains>4|!talent.haunt)
  if S.DecimatingBolt:IsReady() and (S.SummonDarkglare:CooldownRemains() > 5 and (not S.Haunt:IsAvailable() or Target:DebuffRemains(S.Haunt) > 4)) then
    if Cast(S.DecimatingBolt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DecimatingBolt)) then return "decimating_bolt covenant 6"; end
  end
  -- soul_rot,if=!talent.phantom_singularity&(cooldown.summon_darkglare.remains<5|cooldown.summon_darkglare.remains>50|cooldown.summon_darkglare.remains>25&conduit.corrupting_leer)
  if S.SoulRot:IsReady() and CDsON() and (not S.PhantomSingularity:IsAvailable() and (S.SummonDarkglare:CooldownRemains() < 5 or S.SummonDarkglare:CooldownRemains() > 50 or S.SummonDarkglare:CooldownRemains() > 25 and S.CorruptingLeer:ConduitEnabled())) then
    if Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot covenant 8"; end
  end
  -- soul_rot,if=talent.phantom_singularity&dot.phantom_singularity.ticking
  if S.SoulRot:IsReady() and CDsON() and (S.PhantomSingularity:IsAvailable() and Target:DebuffUp(S.PhantomSingularityDebuff)) then
    if Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot covenant 10"; end
  end
  -- scouring_tithe
  if S.ScouringTithe:IsReady() then
    if Cast(S.ScouringTithe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ScouringTithe)) then return "scouring_tithe covenant 12"; end
  end
end

local function Darkglare_prep()
  -- vile_taint
  if S.VileTaint:IsReady() then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint darkglare_prep 2"; end
  end
  -- dark_soul
  if S.DarkSoulMisery:IsReady() and CDsON() then
    if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul darkglare_prep 4"; end
  end
  -- potion
  if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion darkglare_prep 6"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood darkglare_prep 8"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury darkglare_prep 10"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking darkglare_prep 12"; end
  end
  -- call_action_list,name=covenant,if=!covenant.necrolord
  if (CovenantID ~= 4) then
    local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
  end
  -- summon_darkglare
  if S.SummonDarkglare:IsReady() then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare darkglare_prep 14"; end
  end
end

local function Dot_prep()
  -- agony,if=dot.agony.remains<8&cooldown.summon_darkglare.remains>dot.agony.remains
  if S.Agony:IsReady() and (Target:DebuffRemains(S.AgonyDebuff) < 8 and S.SummonDarkglare:CooldownRemains() > Target:DebuffRemains(S.AgonyDebuff)) then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony dot_prep 2"; end
  end
  -- siphon_life,if=dot.siphon_life.remains<8&cooldown.summon_darkglare.remains>dot.siphon_life.remains
  if S.SiphonLife:IsReady() and (Target:DebuffRemains(S.SiphonLifeDebuff) < 8 and S.SummonDarkglare:CooldownRemains() > Target:DebuffRemains(S.SiphonLifeDebuff)) then
    if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life dot_prep 4"; end
  end
  -- unstable_affliction,if=dot.unstable_affliction.remains<8&cooldown.summon_darkglare.remains>dot.unstable_affliction.remains
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 8 and S.SummonDarkglare:CooldownRemains() > Target:DebuffRemains(S.UnstableAfflictionDebuff)) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction dot_prep 6"; end
  end
  -- corruption,if=dot.corruption.remains<8&cooldown.summon_darkglare.remains>dot.corruption.remain
  if S.Corruption:IsReady() and (Target:DebuffRemains(S.CorruptionDebuff) < 8 and S.SummonDarkglare:CooldownRemains() > Target:DebuffRemains(S.CorruptionDebuff)) then
    if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption dot_prep 8"; end
  end
end

local function ItemFunc()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(TrinketsOnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function DelayedTrinkets()
  -- use_item,name=grim_eclipse,if=(covenant.night_fae&cooldown.soul_rot.remains<6)|(covenant.venthyr&cooldown.impending_catastrophe.remains<6)|(covenant.necrolord|covenant.kyrian|covenant.none)
  if I.GrimEclipse:IsEquippedAndReady() and ((CovenantID == 3 and S.SoulRot:CooldownRemains() < 6) or (CovenantID == 2 and S.ImpendingCatastrophe:CooldownRemains() < 6) or (CovenantID == 4 or CovenantID == 1 or CovenantID == 0)) then
    if Cast(I.GrimEclipse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "grim_eclipse delayed_trinkets 1"; end
  end
  -- use_item,name=empyreal_ordnance,if=(covenant.night_fae&cooldown.soul_rot.remains<20)|(covenant.venthyr&cooldown.impending_catastrophe.remains<20)|(covenant.necrolord|covenant.kyrian|covenant.none)
  if I.EmpyrealOrdnance:IsEquippedAndReady() and ((CovenantID == 3 and S.SoulRot:CooldownRemains() < 20) or (CovenantID == 2 and S.ImpendingCatastrophe:CooldownRemains() < 20) or (CovenantID == 4 or CovenantID == 1 or CovenantID == 0)) then
    if Cast(I.EmpyrealOrdnance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "empyreal_ordnance delayed_trinkets 2"; end
  end
  -- use_item,name=sunblood_amethyst,if=(covenant.night_fae&cooldown.soul_rot.remains<6)|(covenant.venthyr&cooldown.impending_catastrophe.remains<6)|(covenant.necrolord|covenant.kyrian|covenant.none)
  if I.SunbloodAmethyst:IsEquippedAndReady() and ((CovenantID == 3 and S.SoulRot:CooldownRemains() < 6) or (CovenantID == 2 and S.ImpendingCatastrophe:CooldownRemains() < 6) or (CovenantID == 4 or CovenantID == 1 or CovenantID == 0)) then
    if Cast(I.SunbloodAmethyst, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "sunblood_amethyst delayed_trinkets 4"; end
  end
  -- use_item,name=soulletting_ruby,if=(covenant.night_fae&cooldown.soul_rot.remains<8)|(covenant.venthyr&cooldown.impending_catastrophe.remains<8)|(covenant.necrolord|covenant.kyrian|covenant.none)
  if I.SoullettingRuby:IsEquippedAndReady() and ((CovenantID == 3 and S.SoulRot:CooldownRemains() < 8) or (CovenantID == 2 and S.ImpendingCatastrophe:CooldownRemains() < 8) or (CovenantID == 4 or CovenantID == 1 or CovenantID == 0)) then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soulletting_ruby delayed_trinkets 6"; end
  end
  -- use_item,name=shadowed_orb_of_torment,if=(covenant.night_fae&cooldown.soul_rot.remains<4)|(covenant.venthyr&cooldown.impending_catastrophe.remains<4)|(covenant.necrolord|covenant.kyrian|covenant.none)
  if I.ShadowedOrbofTorment:IsEquippedAndReady() and ((CovenantID == 3 and S.SoulRot:CooldownRemains() < 4) or (CovenantID == 2 and S.ImpendingCatastrophe:CooldownRemains() < 4) or (CovenantID == 4 or CovenantID == 1 or CovenantID == 0)) then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment delayed_trinkets 8"; end
  end
end

local function StatTrinkets()
  -- use_item,name=the_first_sigil
  if I.TheFirstSigil:IsEquippedAndReady() then
    if Cast(I.TheFirstSigil, nil, Settings.Commons.DisplayStyle.Trinkets) then return "the_first_sigil stat_trinkets 2"; end
  end
  -- use_item,name=scars_of_fraternal_strife
  if I.ScarsofFraternalStrife:IsEquippedAndReady() then
    if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife stat_trinkets 4"; end
  end
  -- use_item,name=inscrutable_quantum_device
  if I.InscrutableQuantumDevice:IsEquippedAndReady() then
    if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device stat_trinkets 6"; end
  end
  -- use_item,name=instructors_divine_bell
  if I.InstructorsDivineBell:IsEquippedAndReady() then
    if Cast(I.InstructorsDivineBell, nil, Settings.Commons.DisplayStyle.Trinkets) then return "instructors_divine_bell stat_trinkets 8"; end
  end
  -- use_item,name=overflowing_anima_cage
  if I.OverflowingAnimaCage:IsEquippedAndReady() then
    if Cast(I.OverflowingAnimaCage, nil, Settings.Commons.DisplayStyle.Trinkets) then return "overflowing_anima_cage stat_trinkets 10"; end
  end
  -- use_item,name=darkmoon_deck_putrescence
  if I.DarkmoonDeckPutrescence:IsEquippedAndReady() then
    if Cast(I.DarkmoonDeckPutrescence, nil, Settings.Commons.DisplayStyle.Trinkets) then return "darkmoon_deck_putrescence stat_trinkets 12"; end
  end
  -- use_item,name=macabre_sheet_music
  if I.MacabreSheetMusic:IsEquippedAndReady() then
    if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music stat_trinkets 14"; end
  end
  -- use_item,name=flame_of_battle
  if I.FlameofBattle:IsEquippedAndReady() then
    if Cast(I.FlameofBattle, nil, Settings.Commons.DisplayStyle.Trinkets) then return "flame_of_battle stat_trinkets 16"; end
  end
  -- use_item,name=wakeners_frond
  if I.WakenersFrond:IsEquippedAndReady() then
    if Cast(I.WakenersFrond, nil, Settings.Commons.DisplayStyle.Trinkets) then return "wakeners_frond stat_trinkets 18"; end
  end
  -- use_item,name=tablet_of_despair
  if I.TabletofDespair:IsEquippedAndReady() then
    if Cast(I.TabletofDespair, nil, Settings.Commons.DisplayStyle.Trinkets) then return "tablet_of_despair stat_trinkets 20"; end
  end
  -- use_item,name=sinful_aspirants_badge_of_ferocity
  if I.SinfulAspirantsBadgeofFerocity:IsEquippedAndReady() then
    if Cast(I.SinfulAspirantsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sinful_aspirants_badge_of_ferocity stat_trinkets 22"; end
  end
  -- use_item,name=cosmic_aspirants_badge_of_ferocity
  if I.CosmicAspirantsBadgeofFerocity:IsEquippedAndReady() then
    if Cast(I.CosmicAspirantsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "cosmic_aspirants_badge_of_ferocity stat_trinkets 24"; end
  end
  -- use_item,name=sinful_gladiators_badge_of_ferocity
  if I.SinfulGladiatorsBadgeofFerocity:IsEquippedAndReady() then
    if Cast(I.SinfulGladiatorsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sinful_gladiators_badge_of_ferocity stat_trinkets 26"; end
  end
  -- use_item,name=cosmic_gladiators_badge_of_ferocity
  if I.CosmicGladiatorsBadgeofFerocity:IsEquippedAndReady() then
    if Cast(I.CosmicGladiatorsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "cosmic_gladiators_badge_of_ferocity stat_trinkets 28"; end
  end
  -- use_item,name=obelisk_of_the_void
  if I.ObeliskoftheVoid:IsEquippedAndReady() then
    if Cast(I.CosmicGladiatorsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "obelisk_of_the_void stat_trinkets 30"; end
  end
  -- use_item,name=horn_of_valor
  if I.HornofValor:IsEquippedAndReady() then
    if Cast(I.HornofValor, nil, Settings.Commons.DisplayStyle.Trinkets) then return "horn_of_valor stat_trinkets 32"; end
  end
  -- use_item,name=moonlit_prism
  if I.MoonlitPrism:IsEquippedAndReady() then
    if Cast(I.MoonlitPrism, nil, Settings.Commons.DisplayStyle.Trinkets) then return "moonlit_prism stat_trinkets 34"; end
  end
  -- use_item,name=figurehead_of_the_naglfar
  if I.FigureheadoftheNaglfar:IsEquippedAndReady() then
    if Cast(I.FigureheadoftheNaglfar, nil, Settings.Commons.DisplayStyle.Trinkets) then return "figurehead_of_the_naglfar stat_trinkets 36"; end
  end
  if (CDsON()) then
    -- blood_fury
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury stat_trinkets 38"; end
    end
    -- fireblood
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood stat_trinkets 40"; end
    end
    -- berserking
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking stat_trinkets 42"; end
    end
  end
end

local function DamageTrinkets()
  -- use_item,name=soul_igniter
  if I.SoulIgniter:IsEquippedAndReady() then
    if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soul_igniter damage_trinkets 2"; end
  end
  -- use_item,name=dreadfire_vessel
  if I.DreadfireVessel:IsEquippedAndReady() then
    if Cast(I.DreadfireVessel, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "dreadfire_vessel damage_trinkets 4"; end
  end
  -- use_item,name=glyph_of_assimilation
  if I.GlyphofAssimilation:IsEquippedAndReady() then
    if Cast(I.GlyphofAssimilation, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "glyph_of_assimilation damage_trinkets 6"; end
  end
  -- use_item,name=unchained_gladiators_shackles
  if I.UnchainedGladiatorsShackles:IsEquippedAndReady() then
    if Cast(I.UnchainedGladiatorsShackles, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(20)) then return "unchained_gladiators_shackles damage_trinkets 8"; end
  end
  -- use_item,name=ebonsoul_vise
  if I.EbonsoulVise:IsEquippedAndReady() then
    if Cast(I.EbonsoulVise, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "ebonsoul_vise damage_trinkets 10"; end
  end
  -- use_item,name=resonant_reservoir
  if I.ResonantReservoir:IsEquippedAndReady() then
    if Cast(I.ResonantReservoir, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "resonant_reservoir damage_trinkets 12"; end
  end
  -- use_item,name=architects_ingenuity_core
  if I.ArchitectsIngenuityCore:IsEquippedAndReady() then
    if Cast(I.ArchitectsIngenuityCore, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "architects_ingenuity_core damage_trinkets 14"; end
  end
  -- use_item,name=grim_eclipse
  if I.GrimEclipse:IsEquippedAndReady() then
    if Cast(I.GrimEclipse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "grim_eclipse damage_trinkets 16"; end
  end
  -- use_item,name=toe_knees_promise
  if I.ToeKneesPromise:IsEquippedAndReady() then
    if Cast(I.ToeKneesPromise, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "toe_knees_promise damage_trinkets 18"; end
  end
  -- use_item,name=mrrgrias_favor
  if I.MrrgriasFavor:IsEquippedAndReady() then
    if Cast(I.MrrgriasFavor, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "mrrgrias_favor damage_trinkets 20"; end
  end
  -- use_item,name=cosmic_gladiators_resonator
  if I.CosmicGladiatorsResonator:IsEquippedAndReady() then
    if Cast(I.CosmicGladiatorsResonator, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "cosmic_gladiators_resonator damage_trinkets 22"; end
  end
end

local function Se()
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt se 2"; end
  end
  -- drain_soul,interrupt_global=1,interrupt_if=debuff.shadow_embrace.stack>=3
  if S.DrainSoul:IsReady() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or not S.ShadowEmbrace:IsAvailable()) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul se 4"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt se 6"; end
  end
end

local function Aoe()
  -- phantom_singularity
  if S.PhantomSingularity:IsReady() then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity aoe 2"; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt aoe 4"; end
  end
  if CDsON() then
    -- call_action_list,name=darkglare_prep,if=covenant.venthyr&dot.impending_catastrophe_dot.ticking&cooldown.summon_darkglare.ready&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
    if (CovenantID == 2 and Target:DebuffUp(S.ImpendingCatastrophe) and S.SummonDarkglare:CooldownUp() and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=covenant.night_fae&dot.soul_rot.ticking&cooldown.summon_darkglare.ready&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
    if (CovenantID == 3 and Target:DebuffUp(S.SoulRot) and S.SummonDarkglare:CooldownUp() and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&dot.phantom_singularity.ticking&dot.phantom_singularity.remains<2
    if ((CovenantID == 4 or CovenantID == 1 or CovenantID == 0) and Target:DebuffUp(S.PhantomSingularityDebuff) and Target:DebuffRemains(S.PhantomSingularityDebuff) < 2) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- seed_of_corruption,if=talent.sow_the_seeds&can_seed
  if S.SeedofCorruption:IsReady() and (S.SowtheSeeds:IsAvailable() and (EnemiesSeedofCorruptionCount <= (EnemiesCount10ySplash < 3 and EnemiesCount10ySplash or 3))) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 6"; end
  end
  -- seed_of_corruption,if=!talent.sow_the_seeds&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.refreshable
  if S.SeedofCorruption:IsReady() and (not S.SowtheSeeds:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight() and Target:DebuffRefreshable(S.CorruptionDebuff)) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 8"; end
  end
  -- agony,cycle_targets=1,if=active_dot.agony<4,target_if=!dot.agony.ticking
  if S.Agony:IsReady() and (EnemiesAgonyCount < 4) then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyNotTicking, not Target:IsSpellInRange(S.Agony)) then return "agony aoe 10"; end
  end
  -- agony,cycle_targets=1,if=active_dot.agony>=4,target_if=refreshable&dot.agony.ticking
  if S.Agony:IsReady() and (EnemiesAgonyCount >= 4) then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRefreshTicking, not Target:IsSpellInRange(S.Agony)) then return "agony aoe 12"; end
  end
  -- unstable_affliction,if=dot.unstable_affliction.refreshable
  if S.UnstableAffliction:IsReady() then
    if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAfflictionRefresh, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction aoe 14"; end
  end
  -- vile_taint,if=soul_shard>1
  if S.VileTaint:IsReady() and (Player:SoulShardsP() > 1) then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint aoe 16"; end
  end
  -- call_action_list,name=covenant,if=!covenant.necrolord
  if (CovenantID ~= 4) then
    local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
  end
  if CDsON() then
    -- call_action_list,name=darkglare_prep,if=covenant.venthyr&(cooldown.impending_catastrophe.ready|dot.impending_catastrophe_dot.ticking)&cooldown.summon_darkglare.ready&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
    if (CovenantID == 2 and (S.ImpendingCatastrophe:IsReady() or Target:DebuffUp(S.ImpendingCatastrophe)) and S.SummonDarkglare:CooldownUp() and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
    if ((CovenantID == 4 or CovenantID == 1 or CovenantID == 0) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=covenant.night_fae&(cooldown.soul_rot.ready|dot.soul_rot.ticking)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
    if (CovenantID == 3 and (S.SoulRot:IsReady() or Target:DebuffUp(S.SoulRot)) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die&(!talent.phantom_singularity|cooldown.phantom_singularity.remains>time_to_die)
    if S.DarkSoulMisery:IsReady() and (S.SummonDarkglare:CooldownRemains() > FightRemains and (not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownRemains() > FightRemains)) then
      if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul aoe 18"; end
    end
    -- dark_soul,if=cooldown.summon_darkglare.remains+cooldown.summon_darkglare.duration<time_to_die
    if S.DarkSoulMisery:IsReady() and (S.SummonDarkglare:CooldownRemains() + 20 < FightRemains) then
      if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul aoe 20"; end
    end
  end
  if (Settings.Commons.Enabled.Trinkets) then
    -- call_action_list,name=item
    if (true) then
      local ShouldReturn = ItemFunc(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=delayed_trinkets
    if (true) then
      local ShouldReturn = DelayedTrinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=damage_trinkets
    if (true) then
      local ShouldReturn = DamageTrinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=stat_trinkets,if=dot.phantom_singularity.ticking|!talent.phantom_singularity
    if (Target:DebuffUp(S.PhantomSingularityDebuff) or not S.PhantomSingularity:IsAvailable()) then
      local ShouldReturn = StatTrinkets(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- malefic_rapture,if=dot.vile_taint.ticking
  if S.MaleficRapture:IsReady() and (EnemiesVileTaintCount >= 1) then
    if Cast(S.MaleficRapture) then return "malefic_rapture aoe 22"; end
  end
  -- malefic_rapture,if=dot.soul_rot.ticking&!talent.sow_the_seeds
  if S.MaleficRapture:IsReady() and (Target:DebuffDown(S.SoulRot) and not S.SowtheSeeds:IsAvailable()) then
    if Cast(S.MaleficRapture) then return "malefic_rapture aoe 24"; end
  end
  -- malefic_rapture,if=!talent.vile_taint
  if S.MaleficRapture:IsReady() and (not S.VileTaint:IsAvailable()) then
    if Cast(S.MaleficRapture) then return "malefic_rapture aoe 26"; end
  end
  -- malefic_rapture,if=soul_shard>4
  if S.MaleficRapture:IsReady() and (Player:SoulShardsP() > 4) then
    if Cast(S.MaleficRapture) then return "malefic_rapture aoe 28"; end
  end
  -- siphon_life,cycle_targets=1,if=active_dot.siphon_life<=3,target_if=!dot.siphon_life.ticking
  if S.SiphonLife:IsReady() and (EnemiesSiphonLifeCount <= 3) then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLifeNotTicking, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life aoe 30"; end
  end
  -- call_action_list,name=covenant
  if (true) then
    local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
  end
  -- drain_life,if=buff.inevitable_demise.stack>=50|buff.inevitable_demise.up&time_to_die<5|buff.inevitable_demise.stack>=35&dot.soul_rot.ticking
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) >= 50 or Player:BuffUp(S.InevitableDemiseBuff) and FightRemains < 5 or Player:BuffStack(S.InevitableDemiseBuff) >= 35 and Target:DebuffUp(S.SoulRot)) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life aoe 32"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent,cancel_if=buff.volatile_solvent_humanoid.up
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft aoe 33"; end
  end
  -- drain_soul,interrupt=1
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 34"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt aoe 36"; end
  end
end

local function NecroMW()
  -- variable,name=dots_ticking,value=dot.corruption.remains>2&dot.agony.remains>2&dot.unstable_affliction.remains>2&(!talent.siphon_life|dot.siphon_life.remains>2)
  VarDoTsTicking = (Target:DebuffRemains(S.CorruptionDebuff) > 2 and Target:DebuffRemains(S.AgonyDebuff) > 2 and Target:DebuffRemains(S.UnstableAfflictionDebuff) > 2 and ((not S.SiphonLife:IsAvailable()) or Target:DebuffRemains(S.SiphonLifeDebuff) > 2))
  -- variable,name=trinket_delay,value=cooldown.phantom_singularity.remains,value_else=cooldown.decimating_bolt.remains,op=setif,condition=talent.shadow_embrace,if=covenant.necrolord
  -- Note: Omitting 'if', as we only end up in NecroMW if we're Necrolord
  if (S.ShadowEmbrace:IsAvailable()) then
    VarTrinketDelay = S.PhantomSingularity:CooldownRemains()
  else
    VarTrinketDelay = S.DecimatingBolt:CooldownRemains()
  end
  -- malefic_rapture,if=time_to_die<execute_time*soul_shard&dot.unstable_affliction.ticking
  if S.MaleficRapture:IsReady() and (Target:TimeToDie() < S.MaleficRapture:ExecuteTime() * Player:SoulShardsP() and Target:DebuffUp(S.UnstableAfflictionDebuff)) then
    if Cast(S.MaleficRapture) then return "malefic_rapture necro_mw 2"; end
  end
  -- haunt,if=dot.haunt.remains<2+execute_time
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 2 + S.Haunt:ExecuteTime()) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt necro_mw 4"; end
  end
  -- malefic_rapture,if=time>7&buff.malefic_wrath.remains<gcd.max+execute_time
  if S.MaleficRapture:IsReady() and (HL.CombatTime() > 7 and Player:BuffRemains(S.MaleficWrathBuff) < Player:GCD() + 0.5 + S.MaleficRapture:ExecuteTime()) then
    if Cast(S.MaleficRapture) then return "malefic_rapture necro_mw 6"; end
  end
  -- use_item,name=empyreal_ordnance,if=variable.trinket_delay<20
  if I.EmpyrealOrdnance:IsEquippedAndReady() and (VarTrinketDelay < 20) then
    if Cast(I.EmpyrealOrdnance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "empyreal_ordnance necro_mw 8"; end
  end
  -- use_item,name=sunblood_amethyst,if=variable.trinket_delay<6 
  if I.SunbloodAmethyst:IsEquippedAndReady() and (VarTrinketDelay < 6) then
    if Cast(I.SunbloodAmethyst, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "sunblood_amethyst necro_mw 10"; end
  end
  -- use_item,name=soulletting_ruby,if=variable.trinket_delay<8
  if I.SoullettingRuby:IsEquippedAndReady() and (VarTrinketDelay < 8) then
    if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soulletting_ruby necro_mw 12"; end
  end
  -- use_item,name=shadowed_orb_of_torment,if=variable.trinket_delay<4
  if I.ShadowedOrbofTorment:IsEquippedAndReady() and (VarTrinketDelay < 4) then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment necro_mw 14"; end
  end
  -- phantom_singularity,if=!talent.shadow_embrace&variable.dots_ticking
  if S.PhantomSingularity:IsReady() and ((not S.ShadowEmbrace:IsAvailable()) and VarDoTsTicking) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity necro_mw 16"; end
  end
  -- decimating_bolt,if=!talent.shadow_embrace&cooldown.phantom_singularity.remains>0
  if S.DecimatingBolt:IsReady() and ((not S.ShadowEmbrace:IsAvailable()) and S.PhantomSingularity:CooldownRemains() > 0) then
    if Cast(S.DecimatingBolt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DecimatingBolt)) then return "decimating_bolt necro_mw 18"; end
  end
  -- decimating_bolt,if=talent.shadow_embrace&variable.dots_ticking
  if S.DecimatingBolt:IsReady() and (S.ShadowEmbrace:IsAvailable() and VarDoTsTicking) then
    if Cast(S.DecimatingBolt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DecimatingBolt)) then return "decimating_bolt necro_mw 20"; end
  end
  -- phantom_singularity,if=talent.shadow_embrace&cooldown.decimating_bolt.remains>0
  if S.PhantomSingularity:IsReady() and (S.ShadowEmbrace:IsAvailable() and S.DecimatingBolt:CooldownRemains() > 0) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity necro_mw 22"; end
  end
  -- unstable_affliction,if=dot.unstable_affliction.remains<6
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 6) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction necro_mw 24"; end
  end
  -- agony,if=dot.agony.remains<4
  if S.Agony:IsReady() and (Target:DebuffRemains(S.AgonyDebuff) < 4) then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony necro_mw 26"; end
  end
  -- siphon_life,if=dot.siphon_life.remains<4
  if S.SiphonLife:IsReady() and (Target:DebuffRemains(S.SiphonLifeDebuff) < 4) then
    if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life necro_mw 28"; end
  end
  -- corruption,if=dot.corruption.remains<4
  if S.Corruption:IsReady() and (Target:DebuffRemains(S.CorruptionDebuff) < 4) then
    if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption necro_mw 30"; end
  end
  -- malefic_rapture,if=time>7&buff.malefic_wrath.remains<2*gcd.max+execute_time
  if S.MaleficRapture:IsReady() and (HL.CombatTime() > 7 and Player:BuffRemains(S.MaleficWrathBuff) < 2 * (Player:GCD() + 0.5) + S.MaleficRapture:ExecuteTime()) then
    if Cast(S.MaleficRapture) then return "malefic_rapture necro_mw 32"; end
  end
  -- call_action_list,name=darkglare_prep,if=dot.phantom_singularity.ticking
  if (Target:DebuffUp(S.PhantomSingularityDebuff)) then
    local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=stat_trinkets,if=dot.phantom_singularity.ticking
  if (Target:DebuffUp(S.PhantomSingularityDebuff)) then
    local ShouldReturn = StatTrinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- malefic_rapture,if=time>7&(buff.malefic_wrath.stack<3|buff.malefic_wrath.remains<4.5)
  if S.MaleficRapture:IsReady() and (HL.CombatTime() > 7 and (Player:BuffStack(S.MaleficWrathBuff) < 3 or Player:BuffRemains(S.MaleficWrathBuff) < 4.5)) then
    if Cast(S.MaleficRapture) then return "malefic_rapture necro_mw 34"; end
  end
  -- malefic_rapture,if=(dot.phantom_singularity.ticking|time_to_die<cooldown.phantom_singularity.remains)&(buff.malefic_wrath.stack<3|soul_shard>1)
  if S.MaleficRapture:IsReady() and ((Target:DebuffUp(S.PhantomSingularityDebuff) or Target:TimeToDie() < S.PhantomSingularity:CooldownRemains()) and (Player:BuffStack(S.MaleficWrathBuff) < 3 or Player:SoulShardsP() > 1)) then
    if Cast(S.MaleficRapture) then return "malefic_rapture necro_mw 36"; end
  end
  -- drain_soul,if=dot.phantom_singularity.ticking
  if S.DrainSoul:IsReady() and (Target:DebuffUp(S.PhantomSingularityDebuff)) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul necro_mw 38"; end
  end
  -- agony,if=refreshable
  if S.Agony:IsReady() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony necro_mw 40"; end
  end
  -- unstable_affliction,if=refreshable
  if S.UnstableAffliction:IsReady() and (Target:DebuffRefreshable(S.UnstableAfflictionDebuff)) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction necro_mw 42"; end
  end
  -- corruption,if=refreshable
  if S.Corruption:IsReady() and (Target:DebuffRefreshable(S.CorruptionDebuff)) then
    if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption necro_mw 44"; end
  end
  -- siphon_life,if=talent.siphon_life&refreshable
  -- Note: Excluded 'talent.siphon_life', as it will not pass IsReady if not talented
  if S.SiphonLife:IsReady() and (Target:DebuffRefreshable(S.SiphonLifeDebuff)) then
    if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life necro_mw 46"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent,cancel_if=buff.volatile_solvent_humanoid.up
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft necro_mw 48"; end
  end
  -- haunt,if=dot.haunt.remains<3
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt necro_mw 50"; end
  end
  -- drain_soul,if=buff.decimating_bolt.up
  if S.DrainSoul:IsReady() and (Player:BuffUp(S.DecimatingBoltBuff)) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul necro_mw 52"; end
  end
  -- drain_soul,if=talent.shadow_embrace&debuff.shadow_embrace.remains<3|debuff.shadow_embrace.stack<3,interrupt_if=debuff.shadow_embrace.stack>=3&debuff.shadow_embrace.remains>3
  if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3 or Target:DebuffStack(S.ShadowEmbraceDebuff) < 3) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul necro_mw 54"; end
  end
  -- drain_soul,interrupt=1
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul necro_mw 56"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt necro_mw 58"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    Enemies40yCount = #Enemies40y
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)

    EnemiesAgonyCount = CalcEnemiesDotCount(S.AgonyDebuff, Enemies40y)
    EnemiesSeedofCorruptionCount = CalcEnemiesDotCount(S.SeedofCorruptionDebuff, Enemies40y)
    EnemiesSiphonLifeCount = CalcEnemiesDotCount(S.SiphonLifeDebuff, Enemies40y)
    EnemiesVileTaintCount = CalcEnemiesDotCount(S.VileTaintDebuff, Enemies40y)
  else
    Enemies40yCount = 1
    EnemiesCount10ySplash = 1
  end

  EnemiesWithUnstableAfflictionDebuff = ReturnEnemiesWithDot(S.UnstableAfflictionDebuff, Enemies40y)

  -- Check remaining time in fight
  FightRemains = HL.FightRemains(Enemies10ySplash, false)

  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if (not Player:AffectingCombat()) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>3
    if (EnemiesCount10ySplash > 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Opener function to ensure that all DoTs are applied before anything else
    -- Added this because sometimes the rotation tries to go into Darkglare_prep before applying all DoTs on single target
    -- 12 seconds chosen arbitrarily, as it's enough time to get all DoTs up and not have any wear off
    if HL.CombatTime() < 12 and Target:GUID() == FirstTarGUID then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=buff.calamitous_crescendo.up
    if S.MaleficRapture:IsReady() and (Player:BuffUp(S.CalamitousCrescendo)) then
      if Cast(S.MaleficRapture) then return "malefic_rapture pre-necro_mw"; end
    end
    -- run_action_list,name=necro_mw,if=covenant.necrolord&runeforge.malefic_wrath&active_enemies=1&talent.phantom_singularity
    if (CovenantID == 4 and MaleficWrathEquipped and EnemiesCount10ySplash == 1 and S.PhantomSingularity:IsAvailable()) then
      local ShouldReturn = NecroMW(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinket_split_check,if=time<1
    -- Note: Added these variables to the Precombat function
    if (Settings.Commons.Enabled.Trinkets) then
      -- call_action_list,name=delayed_trinkets
      if (true) then
        local ShouldReturn = DelayedTrinkets(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=stat_trinkets,if=(dot.soul_rot.ticking|dot.impending_catastrophe_dot.ticking|dot.phantom_singularity.ticking)&soul_shard>3|dot.vile_taint.ticking|talent.sow_the_seeds
      if ((Target:DebuffUp(S.SoulRot) or Target:DebuffUp(S.ImpendingCatastrophe) or Target:DebuffUp(S.PhantomSingularityDebuff)) and Player:SoulShardsP() > 3 or Target:DebuffUp(S.VileTaintDebuff) or S.SowtheSeeds:IsAvailable()) then
        local ShouldReturn = StatTrinkets(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=damage_trinkets,if=covenant.night_fae&(!variable.trinket_split|cooldown.soul_rot.remains>20|(variable.trinket_one&cooldown.soul_rot.remains<trinket.1.cooldown.remains)|(variable.trinket_two&cooldown.soul_rot.remains<trinket.2.cooldown.remains))
      if (CovenantID == 3 and (not VarTrinketSplit or S.SoulRot:CooldownRemains() > 20 or (VarTrinketOne and S.SoulRot:CooldownRemains() < trinket1:CooldownRemains()) or (VarTrinketTwo and S.SoulRot:CooldownRemains() < trinket2:CooldownRemains()))) then
        local ShouldReturn = DamageTrinkets(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=damage_trinkets,if=covenant.venthyr&(!variable.trinket_split|cooldown.impending_catastrophe.remains>20|(variable.trinket_one&cooldown.impending_catastrophe.remains<trinket.1.cooldown.remains)|(variable.trinket_two&cooldown.impending_catastrophe.remains<trinket.2.cooldown.remains))
      if (CovenantID == 2 and (not VarTrinketSplit or S.ImpendingCatastrophe:CooldownRemains() > 20 or (VarTrinketOne and S.ImpendingCatastrophe:CooldownRemains() < trinket1:CooldownRemains()) or (VarTrinketTwo and S.ImpendingCatastrophe:CooldownRemains() < trinket2:CooldownRemains()))) then
        local ShouldReturn = DamageTrinkets(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=damage_trinkets,if=(covenant.necrolord|covenant.kyrian|covenant.none)&(!variable.trinket_split|cooldown.phantom_singularity.remains>20|(variable.trinket_one&cooldown.phantom_singularity.remains<trinket.1.cooldown.remains)|(variable.trinket_two&cooldown.phantom_singularity.remains<trinket.2.cooldown.remains))
      if ((CovenantID == 4 or CovenantID == 1 or CovenantID == 0) and (not VarTrinketSplit or S.PhantomSingularity:CooldownRemains() > 20 or (VarTrinketOne and S.PhantomSingularity:CooldownRemains() < trinket1:CooldownRemains()) or (VarTrinketTwo and S.PhantomSingularity:CooldownRemains() < trinket2:CooldownRemains()))) then
        local ShouldReturn = DamageTrinkets(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=damage_trinkets,if=!talent.phantom_singularity.enabled&(!variable.trinket_split|cooldown.summon_darkglare.remains>20|(variable.trinket_one&cooldown.summon_darkglare.remains<trinket.1.cooldown.remains)|(variable.trinket_two&cooldown.summon_darkglare.remains<trinket.2.cooldown.remains))
      if (not S.PhantomSingularity:IsAvailable() and (not VarTrinketSplit or S.SummonDarkglare:CooldownRemains() > 20 or (VarTrinketOne and S.SummonDarkglare:CooldownRemains() < trinket1:CooldownRemains()) or (VarTrinketTwo and S.SummonDarkglare:CooldownRemains() < trinket2:CooldownRemains()))) then
        local ShouldReturn = DamageTrinkets(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- malefic_rapture,if=time_to_die<execute_time*soul_shard&dot.unstable_affliction.ticking
    if S.MaleficRapture:IsReady() and (FightRemains < S.MaleficRapture:ExecuteTime() * Player:SoulShardsP() and Target:DebuffUp(S.UnstableAfflictionDebuff)) then
      if Cast(S.MaleficRapture) then return "malefic_rapture target_near_death"; end
    end
    if (CDsON()) then
      -- call_action_list,name=darkglare_prep,if=covenant.venthyr&dot.impending_catastrophe_dot.ticking&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
      if (CovenantID == 2 and Target:DebuffUp(S.ImpendingCatastrophe) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=covenant.night_fae&dot.soul_rot.ticking&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity)
      if (CovenantID == 3 and Target:DebuffUp(S.SoulRot) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&dot.phantom_singularity.ticking&dot.phantom_singularity.remains<2
      if ((CovenantID == 4 or CovenantID == 1 or CovenantID == 0) and Target:DebuffUp(S.PhantomSingularityDebuff) and Target:DebuffRemains(S.PhantomSingularityDebuff) < 2) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- call_action_list,name=dot_prep,if=covenant.night_fae&!dot.soul_rot.ticking&cooldown.soul_rot.remains<4
    if (CovenantID == 3 and Target:DebuffDown(S.SoulRot) and S.SoulRot:CooldownRemains() < 4) then
      local ShouldReturn = Dot_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=dot_prep,if=covenant.venthyr&!dot.impending_catastrophe_dot.ticking&cooldown.impending_catastrophe.remains<4
    if (CovenantID == 2 and Target:DebuffDown(S.ImpendingCatastrophe) and S.ImpendingCatastrophe:CooldownRemains() < 4) then
      local ShouldReturn = Dot_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=dot_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&talent.phantom_singularity&!dot.phantom_singularity.ticking&cooldown.phantom_singularity.remains<4
    if ((CovenantID == 4 or CovenantID == 1 or CovenantID == 0) and S.PhantomSingularity:IsAvailable() and Target:DebuffDown(S.PhantomSingularityDebuff) and S.PhantomSingularity:CooldownRemains() < 4) then
      local ShouldReturn = Dot_prep(); if ShouldReturn then return ShouldReturn; end
    end
    if CDsON() then
      -- dark_soul,if=dot.phantom_singularity.ticking
      if S.DarkSoulMisery:IsReady() and (Target:DebuffUp(S.PhantomSingularityDebuff)) then
        if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul main 2"; end
      end
      -- dark_soul,if=!talent.phantom_singularity&(dot.soul_rot.ticking|dot.impending_catastrophe_dot.ticking)
      if S.DarkSoulMisery:IsReady() and (not S.PhantomSingularity:IsAvailable() and (Target:DebuffUp(S.SoulRot) or Target:DebuffUp(S.ImpendingCatastrophe))) then
        if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul main 4"; end
      end
    end
    -- phantom_singularity,if=covenant.night_fae&time>5&cooldown.soul_rot.remains<1&(trinket.empyreal_ordnance.cooldown.remains<162|!equipped.empyreal_ordnance)
    if S.PhantomSingularity:IsReady() and (CovenantID == 3 and HL.CombatTime() > 5 and S.SoulRot:CooldownRemains() < 1 and (I.EmpyrealOrdnance:CooldownRemains() < 162 or not I.EmpyrealOrdnance:IsEquipped())) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 6"; end
    end
    -- phantom_singularity,if=covenant.venthyr&time>5&cooldown.impending_catastrophe.remains<1&(trinket.empyreal_ordnance.cooldown.remains<162|!equipped.empyreal_ordnance)
    if S.PhantomSingularity:IsReady() and (CovenantID == 2 and HL.CombatTime() > 5 and S.ImpendingCatastrophe:CooldownRemains() < 1 and (I.EmpyrealOrdnance:CooldownRemains() < 162 or not I.EmpyrealOrdnance:IsEquipped())) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 8"; end
    end
    -- phantom_singularity,if=covenant.necrolord&runeforge.malefic_wrath&time>5&cooldown.decimating_bolt.remains<3&(trinket.empyreal_ordnance.cooldown.remains<162|!equipped.empyreal_ordnance)
    if S.PhantomSingularity:IsReady() and (CovenantID == 4 and MaleficWrathEquipped and HL.CombatTime() > 5 and S.DecimatingBolt:CooldownRemains() < 3 and (I.EmpyrealOrdnance:CooldownRemains() < 162 or not I.EmpyrealOrdnance:IsEquipped())) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 9"; end
    end
    -- phantom_singularity,if=(covenant.kyrian|covenant.none|(covenant.necrolord&!runeforge.malefic_wrath))&(trinket.empyreal_ordnance.cooldown.remains<162|!equipped.empyreal_ordnance)
    if S.PhantomSingularity:IsReady() and ((CovenantID == 1 or CovenantID == 0 or (CovenantID == 4 and not MaleficWrathEquipped)) and (I.EmpyrealOrdnance:CooldownRemains() < 162 or not I.EmpyrealOrdnance:IsEquipped())) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 10"; end
    end
    -- phantom_singularity,if=time_to_die<16
    if S.PhantomSingularity:IsReady() and (FightRemains < 16) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 12"; end
    end
    -- call_action_list,name=covenant,if=dot.phantom_singularity.ticking&(covenant.night_fae|covenant.venthyr)
    if (Target:DebuffUp(S.PhantomSingularityDebuff) and (CovenantID == 3 or CovenantID == 2)) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- agony,cycle_targets=1,target_if=dot.agony.remains<4
    if S.Agony:IsReady() then
      if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRemains, not Target:IsSpellInRange(S.Agony)) then return "agony main 14"; end
    end
    -- haunt
    if S.Haunt:IsReady() then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 16"; end
    end
    -- seed_of_corruption,if=active_enemies>2&talent.sow_the_seeds&!dot.seed_of_corruption.ticking&!in_flight
    if S.SeedofCorruption:IsReady() and (EnemiesCount10ySplash > 2 and S.SowtheSeeds:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight()) then
      if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption main 18"; end
    end
    -- seed_of_corruption,if=active_enemies>2&talent.siphon_life&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.remains<4
    if S.SeedofCorruption:IsReady() and (EnemiesCount10ySplash > 2 and S.SiphonLife:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight() and Target:DebuffRemains(S.CorruptionDebuff) < 4) then
      if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption main 20"; end
    end
    -- vile_taint,if=(soul_shard>1|active_enemies>2)&cooldown.summon_darkglare.remains>12
    if S.VileTaint:IsReady() and ((Player:SoulShardsP() > 1 or EnemiesCount10ySplash > 2) and S.SummonDarkglare:CooldownRemains() > 12) then
      if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint main 22"; end
    end
    -- unstable_affliction,if=dot.unstable_affliction.remains<4
    if S.UnstableAffliction:IsReady() then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAfflictionRemains, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 24"; end
    end
    -- siphon_life,cycle_targets=1,target_if=dot.siphon_life.remains<4
    if S.SiphonLife:IsReady() then
      if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLifeRemains, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life main 26"; end
    end
    -- call_action_list,name=covenant,if=!covenant.necrolord
    if (CovenantID ~= 4) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- corruption,cycle_targets=1,if=active_enemies<4-(talent.sow_the_seeds|talent.siphon_life),target_if=dot.corruption.remains<2
    if S.Corruption:IsReady() and (EnemiesCount10ySplash < 4 - num(S.SowtheSeeds:IsAvailable() or S.SiphonLife:IsAvailable())) then
      if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruptionRemains, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 28"; end
    end
    -- malefic_rapture,if=soul_shard>4&time>21
    if S.MaleficRapture:IsReady() and (Player:SoulShardsP() > 4 and HL:CombatTime() > 21) then
      if Cast(S.MaleficRapture) then return "malefic_rapture main 30"; end
    end
    if CDsON() then
      -- call_action_list,name=darkglare_prep,if=covenant.venthyr&!talent.phantom_singularity&dot.impending_catastrophe_dot.ticking&cooldown.summon_darkglare.ready
      if (CovenantID == 2 and not S.PhantomSingularity:IsAvailable() and Target:DebuffUp(S.ImpendingCatastrophe) and S.SummonDarkglare:CooldownUp()) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=covenant.night_fae&!talent.phantom_singularity&dot.soul_rot.ticking&cooldown.summon_darkglare.ready
      if (CovenantID == 3 and not S.PhantomSingularity:IsAvailable() and Target:DebuffUp(S.SoulRot) and S.SummonDarkglare:CooldownUp()) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&cooldown.summon_darkglare.ready
      if ((CovenantID == 4 or CovenantID == 1 or CovenantID == 0) and S.SummonDarkglare:CooldownUp()) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die&(!talent.phantom_singularity|cooldown.phantom_singularity.remains>time_to_die)
      if S.DarkSoulMisery:IsReady() and (S.SummonDarkglare:CooldownRemains() > FightRemains and (not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownRemains() > FightRemains)) then
        if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul main 32"; end
      end
      -- dark_soul,if=!talent.phantom_singularity&cooldown.summon_darkglare.remains+cooldown.summon_darkglare.duration<time_to_die
      if S.DarkSoulMisery:IsReady() and (not S.PhantomSingularity:IsAvailable() and S.SummonDarkglare:CooldownRemains() + 20 < FightRemains) then
        if Cast(S.DarkSoulMisery, Settings.Affliction.GCDasOffGCD.DarkSoul) then return "dark_soul main 34"; end
      end
    end
    -- call_action_list,name=item
    if (Settings.Commons.Enabled.Trinkets) then
      local ShouldReturn = ItemFunc(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=se,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<(2-action.shadow_bolt.in_flight)|debuff.shadow_embrace.remains<3)
    if (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < (2 - num(S.ShadowBolt:InFlight())) or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      local ShouldReturn = Se(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=(dot.vile_taint.ticking|dot.impending_catastrophe_dot.ticking|dot.soul_rot.ticking)&(!runeforge.malefic_wrath|buff.malefic_wrath.stack<3|soul_shard>1)
    if S.MaleficRapture:IsReady() and ((Target:DebuffUp(S.VileTaintDebuff) or Target:DebuffUp(S.ImpendingCatastrophe) or Target:DebuffUp(S.SoulRot)) and (not MaleficWrathEquipped or Player:BuffStack(S.MaleficWrathBuff) < 3 or Player:SoulShardsP() > 1)) then
      if Cast(S.MaleficRapture) then return "malefic_rapture main 36"; end
    end
    -- malefic_rapture,if=runeforge.malefic_wrath&cooldown.soul_rot.remains>20&buff.malefic_wrath.remains<4
    if S.MaleficRapture:IsReady() and (MaleficWrathEquipped and S.SoulRot:CooldownRemains() > 20 and Player:BuffRemains(S.MaleficWrathBuff) < 4) then
      if Cast(S.MaleficRapture) then return "malefic_rapture main 37"; end
    end
    -- malefic_rapture,if=runeforge.malefic_wrath&(covenant.necrolord|covenant.kyrian)&buff.malefic_wrath.remains<4
    if S.MaleficRapture:IsReady() and (MaleficWrathEquipped and (CovenantID == 4 or CovenantID == 1) and Player:BuffRemains(S.MaleficWrathBuff) < 4) then
      if Cast(S.MaleficRapture) then return "malefic_rapture main 38"; end
    end
    -- malefic_rapture,if=talent.phantom_singularity&(dot.phantom_singularity.ticking|cooldown.phantom_singularity.remains>25|time_to_die<cooldown.phantom_singularity.remains)&(!runeforge.malefic_wrath|buff.malefic_wrath.stack<3|soul_shard>1)
    if S.MaleficRapture:IsReady() and (S.PhantomSingularity:IsAvailable() and (Target:DebuffUp(S.PhantomSingularityDebuff) or S.PhantomSingularity:CooldownRemains() > 25 or FightRemains < S.PhantomSingularity:CooldownRemains()) and (not MaleficWrathEquipped or Player:BuffStack(S.MaleficWrathBuff) < 3 or Player:SoulShardsP() > 1)) then
      if Cast(S.MaleficRapture) then return "malefic_rapture main 39"; end
    end
    -- malefic_rapture,if=talent.sow_the_seeds
    if S.MaleficRapture:IsReady() and (S.SowtheSeeds:IsAvailable()) then
      if Cast(S.MaleficRapture) then return "malefic_rapture main 40"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>40|buff.inevitable_demise.up&time_to_die<4
    if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 40 or Player:BuffUp(S.InevitableDemiseBuff) and FightRemains < 4) then
      if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life main 42"; end
    end
    -- call_action_list,name=covenant
    if (true) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- agony,cycle_targets=1,if=active_enemies>1,target_if=refreshable
    if S.Agony:IsReady() and (Enemies40yCount > 1) then
      if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRefresh, not Target:IsSpellInRange(S.Agony)) then return "agony main 44"; end
    end
    -- unstable_affliction,if=refreshable
    if S.UnstableAffliction:IsReady() then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAfflictionRefresh, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 46"; end
    end
    -- siphon_life,cycle_targets=1,target_if=refreshable
    if S.SiphonLife:IsReady() then
      if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLifeRefresh, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life main 48"; end
    end
    -- corruption,cycle_targets=1,if=active_enemies<4-(talent.sow_the_seeds|talent.siphon_life),target_if=refreshable
    if S.Corruption:IsReady() and (EnemiesCount10ySplash < 4 - num(S.SowtheSeeds:IsAvailable() or S.SiphonLife:IsAvailable())) then
      if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruptionRefresh, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 50"; end
    end
    -- fleshcraft,if=soulbind.volatile_solvent,cancel_if=buff.volatile_solvent_humanoid.up
    if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft main 51"; end
    end
    -- drain_soul,interrupt=1
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 52"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 54"; end
    end

    return
  end
end

local function OnInit()
  --HR.Print("Affliction Warlock rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(265, APL, OnInit)
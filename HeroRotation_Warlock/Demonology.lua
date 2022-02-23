--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Warlock    = HR.Commons.Warlock
-- lua
local GetTime    = GetTime


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Demonology
local I = Item.Warlock.Demonology

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.ArchitectsIngenuityCore:ID(),
  I.CosmicGladiatorsResonator:ID(),
  I.DarkmoonDeckPutrescence:ID(),
  I.DreadfireVessel:ID(),
  I.EbonsoulVise:ID(),
  I.EmpyrealOrdnance:ID(),
  I.GlyphofAssimilation:ID(),
  I.GrimEclipse:ID(),
  I.OverflowingAnimaCage:ID(),
  I.ResonantReservoir:ID(),
  I.ScarsofFraternalStrife:ID(),
  I.ShadowedOrbofTorment:ID(),
  I.SinfulAspirantsEmblem:ID(),
  I.SinfulGladiatorsEmblem:ID(),
  I.SoulIgniter:ID(),
  I.SoullettingRuby:ID(),
  I.SunbloodAmethyst:ID(),
  I.UnchainedGladiatorsShackles:ID(),
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

-- Rotation Var
local FightRemains
local EnemiesCount8ySplash
local VarFirstTyrantTime = 0
local VarUseBoltTimings = false
local VarNextTyrantCD = 0
local VarBuffSyncCD = 0
local BalespidersEquipped = Player:HasLegendaryEquipped(173)
local WilfredsSigilEquipped = Player:HasLegendaryEquipped(162)
local ImplosivePotentialEquipped = Player:HasLegendaryEquipped(170)
local ShardofAnnihilationEquipped = Player:HasLegendaryEquipped(249)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Demonology = HR.GUISettings.APL.Warlock.Demonology
}

-- Stuns
local StunInterrupts = {
  {S.AxeToss, "Cast Axe Toss (Interrupt)", function () return true; end},
}

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
  BalespidersEquipped = Player:HasLegendaryEquipped(173)
  WilfredsSigilEquipped = Player:HasLegendaryEquipped(162)
  ImplosivePotentialEquipped = Player:HasLegendaryEquipped(170)
  ShardofAnnihilationEquipped = Player:HasLegendaryEquipped(249)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.HandofGuldan:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.HandofGuldan:RegisterInFlight()

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

-- Function to check for imp count
local function WildImpsCount()
  return HL.GuardiansTable.ImpCount or 0
end

-- Function to check for remaining Dreadstalker duration
local function DreadStalkersTime()
  return HL.GuardiansTable.DreadstalkerDuration or 0
end

-- Function to check for remaining Grimoire Felguard duration
local function GrimoireFelguardTime()
  return HL.GuardiansTable.FelGuardDuration or 0
end

-- Function to check for remaining Vilefiend duration
local function VilefiendTime()
  return HL.GuardiansTable.VilefiendDuration or 0
end

-- Function to check for Demonic Tyrant duration
local function DemonicTyrantTime()
  return HL.GuardiansTable.DemonicTyrantDuration or 0
end

local function EvaluateCycleDoom(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.DoomDebuff)
end

local function ImpsSpawnedDuring(SpellCastTime)
  if SpellCastTime == 0 then return 0; end
  local ImpSpawned = 0
  --local SpellCastTime = ( milliseconds / 1000 ) * Player:SpellHaste()

  if GetTime() <= HL.GuardiansTable.InnerDemonsNextCast and (GetTime() + SpellCastTime) >= HL.GuardiansTable.InnerDemonsNextCast then
    ImpSpawned = ImpSpawned + 1
  end

  if Player:IsCasting(S.HandofGuldan) then
    ImpSpawned = ImpSpawned + (Player:SoulShards() >= 3 and 3 or Player:SoulShards())
  end

  ImpSpawned = ImpSpawned +  HL.GuardiansTable.ImpsSpawnedFromHoG

  return ImpSpawned
end

local function EvaluateTargetIfFilterHealth(TargetUnit)
  return TargetUnit:HealthPercentage()
end

local function EvaluateTargetIfSoullettingRuby(TargetUnit)
  local TargetDistance = 0
  if TargetUnit.UnitExists then
    TargetDistance = TargetUnit:MaxDistance()
  end
  if not TargetDistance then TargetDistance = 0 end

  return (VarBuffSyncCD < TargetDistance / 5 - (2 * (Player:GCD() + 0.5) * num(VarUseBoltTimings)))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Demonology.GCDasOffGCD.SummonPet) then return "summon_pet precombat 2"; end
  end
  if Everyone.TargetIsValid() then
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=tome_of_monstrous_constructions
      if I.TomeofMonstrousConstructions:IsEquippedAndReady() then
        if Cast(I.TomeofMonstrousConstructions, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "tome_of_monstrous_constructions precombat 8"; end
      end
      -- use_item,name=soleahs_secret_technique
      if I.SoleahsSecretTechnique:IsEquippedAndReady() then
        if Cast(I.SoleahsSecretTechnique, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soleahs_secret_technique precombat 10"; end
      end
    end
    -- snapshot_stats
    -- fleshcraft
    if S.Fleshcraft:IsCastable() then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 4"; end
    end
    -- variable,name=first_tyrant_time,op=set,value=10
    VarFirstTyrantTime = 10
    -- variable,name=use_bolt_timings,op=set,value=runeforge.balespiders_burning_core&runeforge.shard_of_annihilation
    VarUseBoltTimings = (BalespidersEquipped and ShardofAnnihilationEquipped)
    -- use_item,name=shadowed_orb_of_torment
    if I.ShadowedOrbofTorment:IsEquippedAndReady() and Settings.Commons.Enabled.Trinkets then
      if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment precombat 6"; end
    end
    -- demonbolt
    if S.Demonbolt:IsCastable() then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt precombat 12"; end
    end
  end
end

local function Covenant()
  -- soul_rot,if=soulbind.grove_invigoration&(variable.next_tyrant_cd<20|variable.next_tyrant_cd>30)
  if S.SoulRot:IsReady() and (S.GroveInvigoration:SoulbindEnabled() and (VarNextTyrantCD < 20 or VarNextTyrantCD > 30)) then
    if Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot covenant 2"; end
  end
  -- soul_rot,if=soulbind.field_of_blossoms&pet.demonic_tyrant.active
  if S.SoulRot:IsReady() and (S.FieldofBlossoms:SoulbindEnabled() and DemonicTyrantTime() > 0) then
    if Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot covenant 4"; end
  end
  -- soul_rot,if=soulbind.wild_hunt_tactics&!pet.demonic_tyrant.active&variable.next_tyrant_cd>18
  if S.SoulRot:IsReady() and (S.WildHuntTactics:SoulbindEnabled() and DemonicTyrantTime() == 0 and VarNextTyrantCD > 18) then
    if Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot covenant 6"; end
  end
  -- decimating_bolt,target_if=min:target.health.pct,if=!variable.use_bolt_timings&soulbind.lead_by_example&(pet.demonic_tyrant.active&soul_shard<2|!pet.demonic_tyrant.active&variable.next_tyrant_cd>40)
  if S.DecimatingBolt:IsReady() and ((not VarUseBoltTimings) and S.LeadByExample:SoulbindEnabled() and (DemonicTyrantTime() > 0 and Player:SoulShardsP() < 2 or DemonicTyrantTime() == 0 and VarNextTyrantCD > 40)) then
    if Everyone.CastTargetIf(S.DecimatingBolt, Enemies8ySplash, "min", EvaluateTargetIfFilterHealth, nil, not Target:IsSpellInRange(S.DecimatingBolt), nil, Settings.Commons.DisplayStyle.Covenant) then return "decimating_bolt covenant 8"; end
  end
  -- decimating_bolt,target_if=min:target.health.pct,if=!variable.use_bolt_timings&soulbind.kevins_oozeling&(pet.demonic_tyrant.active|!pet.demonic_tyrant.active&variable.next_tyrant_cd>40)
  if S.DecimatingBolt:IsReady() and ((not VarUseBoltTimings) and S.KevinsOozeling:SoulbindEnabled() and (DemonicTyrantTime() > 0 or DemonicTyrantTime() == 0 and VarNextTyrantCD > 40)) then
    if Everyone.CastTargetIf(S.DecimatingBolt, Enemies8ySplash, "min", EvaluateTargetIfFilterHealth, nil, not Target:IsSpellInRange(S.DecimatingBolt), nil, Settings.Commons.DisplayStyle.Covenant) then return "decimating_bolt covenant 9"; end
  end
  -- decimating_bolt,target_if=min:target.health.pct,if=!variable.use_bolt_timings&(soulbind.forgeborne_reveries|(soulbind.volatile_solvent&!soulbind.kevins_oozeling))&!pet.demonic_tyrant.active
  if S.DecimatingBolt:IsReady() and ((not VarUseBoltTimings) and (S.ForgeborneReveries:SoulbindEnabled() or (S.VolatileSolvent:SoulbindEnabled() and not S.KevinsOozeling:SoulbindEnabled())) and DemonicTyrantTime() == 0) then
    if Everyone.CastTargetIf(S.DecimatingBolt, Enemies8ySplash, "min", EvaluateTargetIfFilterHealth, nil, not Target:IsSpellInRange(S.DecimatingBolt), nil, Settings.Commons.DisplayStyle.Covenant) then return "decimating_bolt covenant 10"; end
  end
  -- decimating_bolt,target_if=min:target.health.pct,if=variable.use_bolt_timings&(!talent.power_siphon|cooldown.power_siphon.remains<action.decimating_bolt.execute_time)&!cooldown.summon_demonic_tyrant.up&(pet.demonic_tyrant.remains<8|cooldown.summon_demonic_tyrant.remains_expected<30)
  if S.DecimatingBolt:IsReady() and (VarUseBoltTimings and ((not S.PowerSiphon:IsAvailable()) or S.PowerSiphon:CooldownRemains() < S.DecimatingBolt:ExecuteTime()) and S.SummonDemonicTyrant:CooldownDown() and (DemonicTyrantTime() < 8 or S.SummonDemonicTyrant:CooldownRemains() < 30)) then
    if Everyone.CastTargetIf(S.DecimatingBolt, Enemies8ySplash, "min", EvaluateTargetIfFilterHealth, nil, not Target:IsSpellInRange(S.DecimatingBolt), nil, Settings.Commons.DisplayStyle.Covenant) then return "decimating_bolt covenant 12"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent&buff.volatile_solvent_humanoid.down,cancel_if=buff.volatile_solvent_humanoid.up
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft covenant 12"; end
  end
  -- scouring_tithe,if=soulbind.combat_meditation&pet.demonic_tyrant.active
  if S.ScouringTithe:IsReady() and (S.CombatMeditation:SoulbindEnabled() and DemonicTyrantTime() > 0) then
    if Cast(S.ScouringTithe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ScouringTithe)) then return "scouring_tithe covenant 13"; end
  end
  -- scouring_tithe,if=!soulbind.combat_meditation
  if S.ScouringTithe:IsReady() and (not S.CombatMeditation:SoulbindEnabled()) then
    if Cast(S.ScouringTithe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ScouringTithe)) then return "scouring_tithe covenant 14"; end
  end
  -- impending_catastrophe,if=pet.demonic_tyrant.active&soul_shard=0
  if S.ImpendingCatastrophe:IsReady() and (DemonicTyrantTime() > 0 and Player:SoulShardsP() == 0) then
    if Cast(S.ImpendingCatastrophe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ImpendingCatastrophe)) then return "impending_catastrophe covenant 16"; end
  end
end

local function TyrantSetup()
  -- nether_portal,if=variable.next_tyrant_cd<15
  if S.NetherPortal:IsReady() and (VarNextTyrantCD < 15) then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal tyrant_setup 2"; end
  end
  -- grimoire_felguard,if=variable.next_tyrant_cd<17-(action.summon_demonic_tyrant.execute_time+action.shadow_bolt.execute_time)&(cooldown.call_dreadstalkers.remains<17-(action.summon_demonic_tyrant.execute_time+action.summon_vilefiend.execute_time+action.shadow_bolt.execute_time)|pet.dreadstalker.remains>variable.next_tyrant_cd+action.summon_demonic_tyrant.execute_time)
  if S.GrimoireFelguard:IsReady() and (VarNextTyrantCD < 17 - (S.SummonDemonicTyrant:ExecuteTime() + S.ShadowBolt:ExecuteTime()) and (S.CallDreadstalkers:CooldownRemains() < 17 - (S.SummonDemonicTyrant:ExecuteTime() + S.SummonVilefiend:ExecuteTime() + S.ShadowBolt:ExecuteTime()) or DreadStalkersTime() > VarNextTyrantCD + S.SummonDemonicTyrant:ExecuteTime())) then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard tyrant_setup 4"; end
  end
  -- summon_vilefiend,if=(variable.next_tyrant_cd<15-(action.summon_demonic_tyrant.execute_time)&(cooldown.call_dreadstalkers.remains<15-(action.summon_demonic_tyrant.execute_time+action.summon_vilefiend.execute_time)|pet.dreadstalker.remains>variable.next_tyrant_cd+action.summon_demonic_tyrant.execute_time))|(!runeforge.wilfreds_sigil_of_superior_summoning&variable.next_tyrant_cd>40)
  if S.SummonVilefiend:IsReady() and ((VarNextTyrantCD < 15 - (S.SummonDemonicTyrant:ExecuteTime()) and (S.CallDreadstalkers:CooldownRemains() < 15 - (S.SummonDemonicTyrant:ExecuteTime() + S.SummonVilefiend:ExecuteTime()) or DreadStalkersTime() > VarNextTyrantCD + S.SummonDemonicTyrant:ExecuteTime())) or (not WilfredsSigilEquipped and VarNextTyrantCD > 40)) then
    if Cast(S.SummonVilefiend) then return "summon_vilefiend tyrant_setup 6"; end
  end
  -- call_dreadstalkers,if=variable.next_tyrant_cd<12-(action.summon_demonic_tyrant.execute_time+action.shadow_bolt.execute_time)
  if S.CallDreadstalkers:IsReady() and (VarNextTyrantCD < 12 - (S.SummonDemonicTyrant:ExecuteTime() + S.ShadowBolt:ExecuteTime())) then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers tyrant_setup 8"; end
  end
  -- summon_demonic_tyrant,if=time>variable.first_tyrant_time&(pet.dreadstalker.active&pet.dreadstalker.remains>action.summon_demonic_tyrant.execute_time)&(!talent.summon_vilefiend.enabled|pet.vilefiend.active)&(soul_shard=0|(pet.dreadstalker.active&pet.dreadstalker.remains<action.summon_demonic_tyrant.execute_time+action.shadow_bolt.execute_time)|(pet.vilefiend.active&pet.vilefiend.remains<action.summon_demonic_tyrant.execute_time+action.shadow_bolt.execute_time)|(buff.grimoire_felguard.up&buff.grimoire_felguard.remains<action.summon_demonic_tyrant.execute_time+action.shadow_bolt.execute_time))
  if S.SummonDemonicTyrant:IsReady() and (HL.CombatTime() > VarFirstTyrantTime and (DreadStalkersTime() > 0 and DreadStalkersTime() > S.SummonDemonicTyrant:ExecuteTime()) and (not S.SummonVilefiend:IsAvailable() or VilefiendTime() > 0) and (Player:SoulShardsP() == 0 or (DreadStalkersTime() > 0 and DreadStalkersTime() < S.SummonDemonicTyrant:ExecuteTime() + S.ShadowBolt:ExecuteTime()) or (VilefiendTime() > 0 and VilefiendTime() < S.SummonDemonicTyrant:ExecuteTime() + S.ShadowBolt:ExecuteTime()) or (GrimoireFelguardTime() > 0 and GrimoireFelguardTime() < S.SummonDemonicTyrant:ExecuteTime() + S.ShadowBolt:ExecuteTime()))) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant tyrant_setup 10"; end
  end
end

local function OGCD()
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking ogcd 2"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury ogcd 4"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood ogcd 6"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function HPTrinkets()
  -- use_item,name=sinful_gladiators_emblem
  if I.SinfulGladiatorsEmblem:IsEquippedAndReady() then
    if Cast(I.SinfulGladiatorsEmblem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sinful_gladiators_emblem hp_trinks 2"; end
  end
  -- use_item,name=sinful_aspirants_emblem
  if I.SinfulAspirantsEmblem:IsEquippedAndReady() then
    if Cast(I.SinfulAspirantsEmblem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sinful_aspirants_emblem hp_trinks 4"; end
  end
end

local function FiveYTrinkets()
  local TargetDistance = 0
  if Target.UnitExists then
    TargetDistance = Target:MaxDistance()
  end
  if not TargetDistance then TargetDistance = 0 end
  -- use_item,name=soulletting_ruby,target_if=min:target.health.pct,if=variable.buff_sync_cd<target.distance%5&time>variable.first_tyrant_time-(target.distance%5)
  if I.SoullettingRuby:IsEquippedAndReady() then
    if Everyone.CastTargetIf(I.SoullettingRuby, Enemies8ySplash, "min", EvaluateTargetIfFilterHealth, EvaluateTargetIfSoullettingRuby, not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby 5y 2"; end
  end
  -- use_item,name=sunblood_amethyst,if=variable.buff_sync_cd<target.distance%5+(2*variable.use_bolt_timings)
  if I.SunbloodAmethyst:IsEquippedAndReady() and (VarBuffSyncCD < TargetDistance / 5 + (2 * num(VarUseBoltTimings))) then
    if Cast(I.SunbloodAmethyst, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "sunblood_amethyst 5y 4"; end
  end
  -- use_item,name=empyreal_ordnance,if=variable.buff_sync_cd<(target.distance%5)+12+(2*variable.use_bolt_timings)
  if I.EmpyrealOrdnance:IsEquippedAndReady() and (VarBuffSyncCD < (TargetDistance / 5) + 12 + (2 * num(VarUseBoltTimings))) then
    if Cast(I.EmpyrealOrdnance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "empyreal_ordnance 5y 6"; end
  end
end

local function DamageTrinkets()
  -- use_item,name=grim_eclipse
  if I.GrimEclipse:IsEquippedAndReady() then
    if Cast(I.GrimEclipse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange()) then return "grim_eclipse dmg 2"; end
  end
  -- use_item,name=resonant_reservoir
  if I.ResonantReservoir:IsEquippedAndReady() then
    if Cast(I.ResonantReservoir, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange()) then return "resonant_reservoir dmg 4"; end
  end
  -- use_item,name=architects_ingenuity_core
  if I.ArchitectsIngenuityCore:IsEquippedAndReady() then
    if Cast(I.ArchitectsIngenuityCore, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange()) then return "architects_ingenuity_core dmg 6"; end
  end
  -- use_item,name=cosmic_gladiators_resonator
  if I.CosmicGladiatorsResonator:IsEquippedAndReady() then
    if Cast(I.CosmicGladiatorsResonator, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange()) then return "cosmic_gladiators_resonator dmg 8"; end
  end
  -- use_item,name=dreadfire_vessel
  if I.DreadfireVessel:IsEquippedAndReady() then
    if Cast(I.DreadfireVessel, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "dreadfire_vessel dmg 10"; end
  end
  -- use_item,name=soul_igniter
  if I.SoulIgniter:IsEquippedAndReady() then
    if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soul_igniter dmg 12"; end
  end
  -- use_item,name=glyph_of_assimilation,if=active_enemies=1
  if I.GlyphofAssimilation:IsEquippedAndReady() and (EnemiesCount8ySplash == 1) then
    if Cast(I.GlyphofAssimilation, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "glyph_of_assimilation dmg 14"; end
  end
  -- use_item,name=darkmoon_deck_putrescence
  if I.DarkmoonDeckPutrescence:IsEquippedAndReady() then
    if Cast(I.DarkmoonDeckPutrescence, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "darkmoon_deck_putrescence dmg 16"; end
  end
  -- use_item,name=ebonsoul_vise
  if I.EbonsoulVise:IsEquippedAndReady() then
    if Cast(I.EbonsoulVise, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "ebonsoul_vise dmg 18"; end
  end
  -- use_item,name=unchained_gladiators_shackles
  if I.UnchainedGladiatorsShackles:IsEquippedAndReady() then
    if Cast(I.UnchainedGladiatorsShackles, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(20)) then return "unchained_gladiators_shackles dmg 20"; end
  end
end

local function Trinkets()
  -- use_item,name=shadowed_orb_of_torment,if=variable.buff_sync_cd<22
  if I.ShadowedOrbofTorment:IsEquippedAndReady() and (VarBuffSyncCD < 22) then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment trinkets 2"; end
  end
  -- use_item,name=scars_of_fraternal_strife
  if I.ScarsofFraternalStrife:IsEquippedAndReady() then
    if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife trinkets 3"; end
  end
  -- call_action_list,name=hp_trinks,if=talent.demonic_consumption.enabled&variable.next_tyrant_cd<20
  if (S.DemonicConsumption:IsAvailable() and VarNextTyrantCD < 20) then
    local ShouldReturn = HPTrinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=5y_per_sec_trinkets
  if (true) then
    local ShouldReturn = FiveYTrinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- use_item,name=overflowing_anima_cage,if=(!variable.use_bolt_timings&pet.demonic_tyrant.active)|(variable.use_bolt_timings&buff.shard_of_annihilation.up)
  if I.OverflowingAnimaCage:IsEquippedAndReady() and (((not VarUseBoltTimings) and DemonicTyrantTime() > 0) or (VarUseBoltTimings and Player:BuffUp(S.ShardofAnnihilationBuff))) then
    if Cast(I.OverflowingAnimaCage, nil, Settings.Commons.DisplayStyle.Trinkets) then return "overflowing_anima_cage trinkets 4"; end
  end
  -- use_item,slot=trinket1,if=trinket.1.has_use_buff&((!variable.use_bolt_timings&pet.demonic_tyrant.active)|(variable.use_bolt_timings&buff.shard_of_annihilation.up))
  if trinket1:IsEquippedAndReady() and (trinket1:TrinketHasUseBuff() and (((not VarUseBoltTimings) and DemonicTyrantTime() > 0) or (VarUseBoltTimings and Player:BuffUp(S.ShardofAnnihilationBuff)))) then
    if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 trinkets 6"; end
  end
  -- use_item,slot=trinket2,if=trinket.2.has_use_buff&((!variable.use_bolt_timings&pet.demonic_tyrant.active)|(variable.use_bolt_timings&buff.shard_of_annihilation.up))
  if trinket2:IsEquippedAndReady() and (trinket2:TrinketHasUseBuff() and (((not VarUseBoltTimings) and DemonicTyrantTime() > 0) or (VarUseBoltTimings and Player:BuffUp(S.ShardofAnnihilationBuff)))) then
    if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 trinkets 8"; end
  end
  -- call_action_list,name=pure_damage_trinks,if=time>variable.first_tyrant_time&variable.buff_sync_cd>20
  if (HL.CombatTime() > VarFirstTyrantTime and VarBuffSyncCD > 20) then
    local ShouldReturn = DamageTrinkets(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Opener()
  -- soul_rot,if=soulbind.grove_invigoration
  if S.SoulRot:IsCastable() and (S.GroveInvigoration:SoulbindEnabled()) then
    if Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot opener 2"; end
  end
  -- nether_portal
  if S.NetherPortal:IsReady() then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal opener 4"; end
  end
  -- grimoire_felguard
  if S.GrimoireFelguard:IsReady() then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard opener 4"; end
  end
  -- summon_vilefiend
  if S.SummonVilefiend:IsReady() then
    if Cast(S.SummonVilefiend) then return "summon_vilefiend opener 6"; end
  end
  -- shadow_bolt,if=soul_shard<5&cooldown.call_dreadstalkers.up
  if S.ShadowBolt:IsCastable() and (Player:SoulShardsP() < 5 and S.CallDreadstalkers:CooldownUp()) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt opener 8"; end
  end
  -- shadow_bolt,if=variable.use_bolt_timings&soul_shard<5&buff.balespiders_burning_core.stack<4
  if S.ShadowBolt:IsCastable() and (VarUseBoltTimings and Player:SoulShardsP() < 5 and Player:BuffStack(S.BalespidersBuff) < 4) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt opener 9"; end
  end
  -- call_dreadstalkers
  if S.CallDreadstalkers:IsReady() then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers opener 10"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Update Enemy Counts
  if AoEON() then
    Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    Enemies8ySplash = {}
    EnemiesCount8ySplash = 1
  end

  -- Update Demonology-specific Tables
  Warlock.UpdatePetTable()
  Warlock.UpdateSoulShards()

  -- Length of fight remaining
  FightRemains = HL.FightRemains(Enemies8ySplash, false)

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    if S.SpellLock:IsAvailable() then
      local ShouldReturn = Everyone.Interrupt(40, S.SpellLock, Settings.Commons.OffGCDasOffGCD.SpellLock, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    end
    if S.AxeToss:IsAvailable() then
      local ShouldReturn = Everyone.Interrupt(30, S.AxeToss, Settings.Demonology.OffGCDasOffGCD.AxeToss, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: unending_resolve
    if S.UnendingResolve:IsCastable() and (Player:HealthPercentage() < Settings.Demonology.UnendingResolveHP) then
      if Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return "unending_resolve defensive"; end
    end
    -- variable,name=next_tyrant_cd,op=set,value=cooldown.summon_demonic_tyrant.remains_expected,if=!soulbind.field_of_blossoms|cooldown.summon_demonic_tyrant.remains_expected>cooldown.soul_rot.remains_expected
    if ((not S.FieldofBlossoms:SoulbindEnabled()) or S.SummonDemonicTyrant:CooldownRemains() > S.SoulRot:CooldownRemains()) then
      VarNextTyrantCD = S.SummonDemonicTyrant:CooldownRemains()
    end
    -- variable,name=next_tyrant_cd,op=set,value=cooldown.soul_rot.remains_expected,if=soulbind.field_of_blossoms&cooldown.summon_demonic_tyrant.remains_expected<cooldown.soul_rot.remains_expected
    if (S.FieldofBlossoms:SoulbindEnabled() and S.SummonDemonicTyrant:CooldownRemains() < S.SoulRot:CooldownRemains()) then
      VarNextTyrantCD = S.SoulRot:CooldownRemains()
    end
    -- variable,name=next_tyrant_cd,op=set,value=variable.first_tyrant_time-time,if=time<variable.first_tyrant_time
    if (HL.CombatTime() < VarFirstTyrantTime) then
      VarNextTyrantCD = VarFirstTyrantTime - HL.CombatTime()
    end
    -- variable,name=buff_sync_cd,op=set,value=variable.next_tyrant_cd,if=!variable.use_bolt_timings
    if (not VarUseBoltTimings) then
      VarBuffSyncCD = VarNextTyrantCD
    end
    -- variable,name=buff_sync_cd,op=set,value=cooldown.decimating_bolt.remains_expected,if=variable.use_bolt_timings
    if (VarUseBoltTimings) then
      VarBuffSyncCD = S.DecimatingBolt:CooldownRemains()
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd,if=(!variable.use_bolt_timings&pet.demonic_tyrant.active)|(variable.use_bolt_timings&buff.shard_of_annihilation.up&(!talent.power_siphon.enabled|buff.power_siphon.up))
    if CDsON() and (((not VarUseBoltTimings) and DemonicTyrantTime() > 0) or (VarUseBoltTimings and Player:BuffUp(S.ShardofAnnihilationBuff) and ((not S.PowerSiphon:IsAvailable()) or Player:BuffUp(S.PowerSiphon)))) then
      local ShouldReturn = OGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=opener,if=time<variable.first_tyrant_time
    if HL.CombatTime() < VarFirstTyrantTime then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- doom,if=refreshable
    if S.Doom:IsCastable() and (Target:DebuffRefreshable(S.DoomDebuff)) then
      if Cast(S.Doom, nil, nil, not Target:IsSpellInRange(S.Doom)) then return "doom main 2"; end
    end
    -- call_action_list,name=covenant_ability,if=soulbind.grove_invigoration|soulbind.field_of_blossoms|soulbind.combat_meditation|covenant.necrolord
    if (S.GroveInvigoration:SoulbindEnabled() or S.FieldofBlossoms:SoulbindEnabled() or S.CombatMeditation:SoulbindEnabled() or CovenantID == 4) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- power_siphon,if=variable.use_bolt_timings&buff.shard_of_annihilation.up
    if S.PowerSiphon:IsReady() and (VarUseBoltTimings and Player:BuffUp(S.ShardofAnnihilationBuff)) then
      if Cast(S.PowerSiphon) then return "power_siphon main 3"; end
    end
    -- potion,if=(!variable.use_bolt_timings&variable.next_tyrant_cd<gcd.max&time>variable.first_tyrant_time|soulbind.refined_palate&variable.next_tyrant_cd<38)|(variable.use_bolt_timings&buff.shard_of_annihilation.up)
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (((not VarUseBoltTimings) and VarNextTyrantCD < Player:GCD() + 0.5 and HL.CombatTime() > VarFirstTyrantTime or S.RefinedPalate:SoulbindEnabled() and VarNextTyrantCD < 38) or (VarUseBoltTimings and Player:BuffUp(S.ShardofAnnihilationBuff))) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
    end
    -- call_action_list,name=tyrant_setup
    if CDsON() then
      local ShouldReturn = TyrantSetup(); if ShouldReturn then return ShouldReturn; end
    end
    -- demonic_strength,,if=(!runeforge.wilfreds_sigil_of_superior_summoning&variable.next_tyrant_cd>9)|(pet.demonic_tyrant.active&pet.demonic_tyrant.remains<6*gcd.max)
    -- Added check to make sure that we're not suggesting this during pet's Felstorm
    if S.DemonicStrength:IsCastable() and (S.Felstorm:CooldownRemains() < 30 - (5 * (1 - (Player:HastePct() / 100)))) and ((not WilfredsSigilEquipped and VarNextTyrantCD > 9) or (DemonicTyrantTime() > 0 and DemonicTyrantTime() < 6 * Player:GCD())) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 6"; end
    end
    -- call_dreadstalkers,if=variable.use_bolt_timings&cooldown.summon_demonic_tyrant.remains_expected>22
    if S.CallDreadstalkers:IsReady() and (VarUseBoltTimings and S.SummonDemonicTyrant:CooldownRemains() > 22) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 7"; end
    end
    -- call_dreadstalkers,if=!variable.use_bolt_timings&(variable.next_tyrant_cd>20-5*!runeforge.wilfreds_sigil_of_superior_summoning)
    if S.CallDreadstalkers:IsReady() and ((not VarUseBoltTimings) and (VarNextTyrantCD > 20 - 5 * num(not WilfredsSigilEquipped))) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 8"; end
    end
    -- power_siphon,if=!variable.use_bolt_timings&buff.wild_imps.stack>1&buff.demonic_core.stack<3
    if S.PowerSiphon:IsCastable() and ((not VarUseBoltTimings) and WildImpsCount() > 1 and Player:BuffStack(S.DemonicCoreBuff) < 3) then
      if Cast(S.PowerSiphon) then return "power_siphon main 10"; end
    end
    -- bilescourge_bombers,if=buff.tyrant.down&variable.next_tyrant_cd>5
    if S.BilescourgeBombers:IsReady() and (DemonicTyrantTime() == 0 and VarNextTyrantCD > 5) then
      if Cast(S.BilescourgeBombers, nil, nil, not Target:IsInRange(40)) then return "bilescourge_bombers main 12"; end
    end
    -- implosion,if=active_enemies>1+(1*talent.sacrificed_souls.enabled)&buff.wild_imps.stack>=6&buff.tyrant.down&variable.next_tyrant_cd>5
    if AoEON() and S.Implosion:IsReady() and (EnemiesCount8ySplash > 1 + (1 * num(S.SacrificedSouls:IsAvailable())) and WildImpsCount() >= Settings.Demonology.ImpsRequiredForImplosion and DemonicTyrantTime() == 0 and VarNextTyrantCD > 5) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 14"; end
    end
    -- implosion,if=active_enemies>2&buff.wild_imps.stack>=6&buff.tyrant.down&variable.next_tyrant_cd>5&!runeforge.implosive_potential&(!talent.from_the_shadows.enabled|debuff.from_the_shadows.up)
    if AoEON() and S.Implosion:IsReady() and (EnemiesCount8ySplash > 2 and WildImpsCount() >= Settings.Demonology.ImpsRequiredForImplosion and DemonicTyrantTime() == 0 and VarNextTyrantCD > 5 and not ImplosivePotentialEquipped and (not S.FromtheShadows:IsAvailable() or Target:DebuffUp(S.FromtheShadowsDebuff))) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 16"; end
    end
    -- implosion,if=active_enemies>2&buff.wild_imps.stack>=6&buff.implosive_potential.remains<2&runeforge.implosive_potential
    if AoEON() and S.Implosion:IsReady() and (EnemiesCount8ySplash > 2 and WildImpsCount() >= Settings.Demonology.ImpsRequiredForImplosion and Player:BuffRemains(S.ImplosivePotentialBuff) < 2 and ImplosivePotentialEquipped) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 18"; end
    end
    -- implosion,if=buff.wild_imps.stack>=12&talent.soul_conduit.enabled&talent.from_the_shadows.enabled&runeforge.implosive_potential&buff.tyrant.down&variable.next_tyrant_cd>5
    if AoEON() and S.Implosion:IsReady() and (WildImpsCount() >= 12 and S.SoulConduit:IsAvailable() and S.FromtheShadows:IsAvailable() and ImplosivePotentialEquipped and DemonicTyrantTime() == 0 and VarNextTyrantCD > 5) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 20"; end
    end
    -- grimoire_felguard,if=time_to_die<30
    if CDsON() and S.GrimoireFelguard:IsReady() and (FightRemains < 30) then
      if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard main 22"; end
    end
    -- summon_vilefiend,if=time_to_die<28
    if S.SummonVilefiend:IsReady() and (FightRemains < 28) then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend main 24"; end
    end
    -- summon_demonic_tyrant,if=time_to_die<15
    if S.SummonDemonicTyrant:IsReady() and not Settings.Demonology.SuppressLateTyrant and (FightRemains < 15) then
      if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant main 26"; end
    end
    -- hand_of_guldan,if=soul_shard=5
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() == 5) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 28"; end
    end
    -- shadow_bolt,if=soul_shard<5&runeforge.balespiders_burning_core&buff.balespiders_burning_core.remains<5
    if S.ShadowBolt:IsCastable() and (Player:SoulShardsP() < 5 and BalespidersEquipped and Player:BuffRemains(S.BalespidersBuff) < 5) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 29"; end
    end
    -- hand_of_guldan,if=soul_shard>=3&(pet.dreadstalker.active|pet.demonic_tyrant.active)
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() >= 3 and (DreadStalkersTime() > 0 or DemonicTyrantTime() > 0)) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 30"; end
    end
    -- hand_of_guldan,if=soul_shard>=1&buff.nether_portal.up&cooldown.call_dreadstalkers.remains>2*gcd.max
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() >= 1 and Player:BuffUp(S.NetherPortalBuff) and S.CallDreadstalkers:CooldownRemains() > 2 * Player:GCD()) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 32"; end
    end
    -- hand_of_guldan,if=soul_shard>=1&variable.next_tyrant_cd<gcd.max&time>variable.first_tyrant_time-gcd.max
    -- Manually added DreadStalkersTime and VilefiendTime checks to avoid dumping shards without immediately casting SummonDemonicTyrant
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() >= 1 and VarNextTyrantCD < Player:GCD() and HL.CombatTime() > VarFirstTyrantTime - Player:GCD() and (DreadStalkersTime() > 0 and (not S.SummonVilefiend:IsAvailable() or VilefiendTime() > 0))) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 34"; end
    end
    -- call_action_list,name=covenant_ability,if=!covenant.venthyr
    if (CovenantID ~= 2) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- soul_strike,if=!talent.sacrificed_souls.enabled
    if S.SoulStrike:IsCastable() and (not S.SacrificedSouls:IsAvailable()) then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 36"; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4&variable.next_tyrant_cd>20
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4 and VarNextTyrantCD > 20) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 38"; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4&variable.next_tyrant_cd<12
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4 and VarNextTyrantCD < 12) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 40"; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4&(buff.demonic_core.stack>2|talent.sacrificed_souls.enabled)
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4 and (Player:BuffStack(S.DemonicCoreBuff) > 2 or S.SacrificedSouls:IsAvailable())) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 42"; end
    end
    -- demonbolt,if=set_bonus.tier28_2pc&soul_shard<4&((6-soul_shard)*action.shadow_bolt.execute_time>pet.dreadstalker.remains-action.hand_of_guldan.execute_time-action.demonbolt.execute_time)&buff.demonic_core.stack>=1
    if S.Demonbolt:IsReady() and (Player:HasTier(28, 2) and Player:SoulShardsP() < 4 and ((6 - Player:SoulShardsP()) * S.ShadowBolt:ExecuteTime() > DreadStalkersTime() - S.HandofGuldan:ExecuteTime() - S.Demonbolt:ExecuteTime()) and Player:BuffStack(S.DemonicCoreBuff) >= 1) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 43"; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4&active_enemies>1
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4 and EnemiesCount8ySplash > 1) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 44"; end
    end
    -- soul_strike
    if S.SoulStrike:IsCastable() then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 46"; end
    end
    -- call_action_list,name=covenant_ability
    if (true) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- hand_of_guldan,if=soul_shard>=3&variable.next_tyrant_cd>25&(talent.demonic_calling.enabled|cooldown.call_dreadstalkers.remains>((5-soul_shard)*action.shadow_bolt.execute_time)+action.hand_of_guldan.execute_time)
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() >= 3 and VarNextTyrantCD > 25 and (S.DemonicCalling:IsAvailable() or S.CallDreadstalkers:CooldownRemains() > ((5 - Player:SoulShardsP()) * S.ShadowBolt:ExecuteTime()) + S.HandofGuldan:ExecuteTime())) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 48"; end
    end
    -- doom,cycle_targets=1,if=refreshable&time>variable.first_tyrant_time
    if S.Doom:IsReady() and (HL.CombatTime() > VarFirstTyrantTime) then
      if Everyone.CastCycle(S.Doom, Enemies8ySplash, EvaluateCycleDoom, not Target:IsSpellInRange(S.Doom)) then return "doom main 50"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 52"; end
    end
  end
end

local function Init()
  --HR.Print("Demonology Warlock rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(266, APL, Init)

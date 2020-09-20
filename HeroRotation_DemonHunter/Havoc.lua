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
if not Spell.DemonHunter then Spell.DemonHunter = {} end
Spell.DemonHunter.Havoc = {
  -- Racials
  -- Abilities
  Annihilation                          = Spell(201427),
  BladeDance                            = Spell(188499),
  ChaosNova                             = Spell(179057),
  ChaosStrike                           = Spell(162794),
  DeathSweep                            = Spell(210152),
  DemonBlades                           = Spell(203555),
  DemonsBite                            = Spell(162243),
  Disrupt                               = Spell(183752),
  EyeBeam                               = Spell(198013),
  FelRush                               = Spell(195072),
  ImmolationAura                        = Spell(258920),
  Metamorphosis                         = Spell(191427),
  MetamorphosisBuff                     = Spell(162264),
  ThrowGlaive                           = Spell(185123),
  VengefulRetreat                       = Spell(198793),
  -- Talents
  BlindFury                             = Spell(203550),
  Demonic                               = Spell(213410),
  EssenceBreak                          = Spell(258860),
  EssenceBreakDebuff                    = Spell(320338),
  FelBarrage                            = Spell(258925),
  FelEruption                           = Spell(211881),
  Felblade                              = Spell(232893),
  FirstBlood                            = Spell(206416),
  GlaiveTempest                         = Spell(342817),
  Momentum                              = Spell(206476),
  MomentumBuff                          = Spell(208628),
  PreparedBuff                          = Spell(203650), -- Procs from Vengeful Retreat with Momentum
  TrailofRuin                           = Spell(258881),
  UnboundChaos                          = Spell(275144),
  UnboundChaosBuff                      = Spell(337313),
  -- Covenant Abilities
  ElysianDecree                         = Spell(306830),
  FoddertotheFlame                      = Spell(329554),
  SinfulBrand                           = Spell(317009),
  SinfulBrandDebuff                     = Spell(317009),
  TheHunt                               = Spell(323639),
  -- Conduits
  ExposedWoundDebuff                    = Spell(339229), -- Triggered by Serrated Glaive
  SerratedGlaive                        = Spell(339230),
  -- Item Buffs/Debuffs
  ConductiveInkDebuff                   = Spell(302565),
  RazorCoralDebuff                      = Spell(303568),
  -- Azerite Traits (BfA)
  ChaoticTransformation                 = Spell(288754),
  RevolvingBlades                       = Spell(279581),
  -- Essences (BfA)
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RecklessForceCounter                  = MultiSpell(298409, 302917),
  RippleInSpace                         = Spell(302731),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186)
};
local S = Spell.DemonHunter.Havoc;

-- Items
if not Item.DemonHunter then Item.DemonHunter = {} end
Item.DemonHunter.Havoc = {
  PotionofUnbridledFury            = Item(169299),
  GalecallersBoon                  = Item(159614, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  DribblingInkpod                  = Item(169319, {13, 14})
};
local I = Item.DemonHunter.Havoc;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.GalecallersBoon:ID(),
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
  I.DribblingInkpod:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Havoc = HR.GUISettings.APL.DemonHunter.Havoc
};

-- Interrupts List
local StunInterrupts = {
  {S.FelEruption, "Cast Fel Eruption (Interrupt)", function () return true; end},
  {S.ChaosNova, "Cast Chaos Nova (Interrupt)", function () return true; end},
};

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight();
end, "AZERITE_ESSENCE_ACTIVATED")
S.ConcentratedFlame:RegisterInFlight();

-- Variables
local VarPoolingForMeta = 0;
local VarBladeDance = 0;
local VarPoolingForBladeDance = 0;
local VarPoolingForEyeBeam = 0;
local VarWaitingForEssenceBreak = 0;
local VarWaitingForMomentum = 0;
local VarFelBarrageSync = 0;

HL:RegisterForEvent(function()
  VarPoolingForMeta = 0
  VarBladeDance = 0
  VarPoolingForBladeDance = 0
  VarPoolingForEyeBeam = 0
  VarWaitingForEssenceBreak = 0
  VarWaitingForMomentum = 0
  VarFelBarrageSync = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {40, 20, 8}
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

local function IsInMeleeRange()
  if S.Felblade:TimeSinceLastCast() <= Player:GCD() then
    return true
  elseif S.VengefulRetreat:TimeSinceLastCast() < 1.0 then
    return false
  end
  return Target:IsInRange("Melee")
end

local function CastFelRush()
  if Settings.Havoc.FelRushDisplayStyle == "Suggested" then
    return HR.CastSuggested(S.FelRush);
  elseif Settings.Havoc.FelRushDisplayStyle == "Cooldown" then
    if S.FelRush:TimeSinceLastDisplay() ~= 0 then
      return HR.Cast(S.FelRush, { true, false } );
    else
      return false;
    end
  end

  return HR.Cast(S.FelRush);
end

local function ConserveFelRush()
  return not Settings.Havoc.ConserveFelRush or S.FelRush:Charges() == 2
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 2"; end
  end
  -- use_item,name=azsharas_font_of_power
  if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.AzsharasFontofPower) then return "azsharas_font_of_power 4"; end
  end
  -- Manually added: Fel Rush if out of range
  if not Target:IsInRange("Melee") and S.FelRush:IsCastableP() then
    if HR.Cast(S.FelRush, nil, nil, 15) then return "fel_rush 6"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if Target:IsInRange("Melee") and (S.DemonsBite:IsCastableP() or S.DemonBlades:IsAvailable()) then
    if HR.Cast(S.DemonsBite, nil, nil, "Melee") then return "demons_bite or demon_blades 8"; end
  end
end

local function Essences()
  -- variable,name=fel_barrage_sync,if=talent.fel_barrage.enabled,value=cooldown.fel_barrage.ready&(((!talent.demonic.enabled|buff.metamorphosis.up)&!variable.waiting_for_momentum&raid_event.adds.in>30)|active_enemies>desired_targets)
  if (S.FelBarrage:IsAvailable()) then
    VarFelBarrageSync = num(S.FelBarrage:CooldownUpP() and (((not S.Demonic:IsAvailable() or Player:BuffP(S.MetamorphosisBuff)) and not bool(VarWaitingForMomentum)) or Cache.EnemiesCount[8] > 1))
  end
  -- concentrated_flame,if=(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
  if S.ConcentratedFlame:IsCastableP() and (Target:DebuffDownP(S.ConcentratedFlameBurn) and not S.ConcentratedFlame:InFlight() or S.ConcentratedFlame:FullRechargeTimeP() < Player:GCD()) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame"; end
  end
  -- blood_of_the_enemy,if=(!talent.fel_barrage.enabled|cooldown.fel_barrage.remains>45)&!variable.waiting_for_momentum&((!talent.demonic.enabled|buff.metamorphosis.up&!cooldown.blade_dance.ready)|target.time_to_die<=10)
  if S.BloodoftheEnemy:IsCastableP() and ((not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemainsP() > 45) and not bool(VarWaitingForMomentum) and ((not S.Demonic:IsAvailable() or Player:BuffP(S.MetamorphosisBuff) and not S.BladeDance:CooldownUpP()) or Target:TimeToDie() <= 10)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
  end
  -- blood_of_the_enemy,if=talent.fel_barrage.enabled&variable.fel_barrage_sync
  if S.BloodoftheEnemy:IsCastableP() and (S.FelBarrage:IsAvailable() and bool(VarFelBarrageSync)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy fel_barrage_sync"; end
  end
  -- guardian_of_azeroth,if=(buff.metamorphosis.up&cooldown.metamorphosis.ready)|buff.metamorphosis.remains>25|target.time_to_die<=30
  if S.GuardianofAzeroth:IsCastableP() and ((Player:BuffP(S.MetamorphosisBuff) and S.Metamorphosis:CooldownUpP()) or Player:BuffRemainsP(S.MetamorphosisBuff) > 25 or Target:TimeToDie() <= 30) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
  end
  -- focused_azerite_beam,if=spell_targets.blade_dance1>=2|raid_event.adds.in>60
  if S.FocusedAzeriteBeam:IsCastableP() and (Cache.EnemiesCount[8] >= 2 or Settings.Havoc.UseFABST) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
  end
  -- purifying_blast,if=spell_targets.blade_dance1>=2|raid_event.adds.in>60
  if S.PurifyingBlast:IsCastableP() and (Cache.EnemiesCount[8] >= 2) then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast"; end
  end
  -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
  if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffStackP(S.RecklessForceCounter) < 10) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastableP() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
  end
  -- worldvein_resonance,if=buff.metamorphosis.up|variable.fel_barrage_sync
  if S.WorldveinResonance:IsCastableP() and (Player:BuffP(S.MetamorphosisBuff) or bool(VarFelBarrageSync)) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
  end
  -- memory_of_lucid_dreams,if=fury<40&buff.metamorphosis.up
  if S.MemoryofLucidDreams:IsCastableP() and (Player:Fury() < 40 and Player:BuffP(S.MetamorphosisBuff)) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
  end
  -- cycling_variable,name=reaping_delay,op=min,if=essence.breath_of_the_dying.major,value=target.time_to_die
  -- reaping_flames,target_if=target.time_to_die<1.5|((target.health.pct>80|target.health.pct<=20)&(active_enemies=1|variable.reaping_delay>29))|(target.time_to_pct_20>30&(active_enemies=1|variable.reaping_delay>44))
  if (true) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
end

local function Cooldown()
  -- metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta)|target.time_to_die<25
  if S.Metamorphosis:IsCastableP(40) and (Player:BuffDownP(S.MetamorphosisBuff) and not (S.Demonic:IsAvailable() or bool(VarPoolingForMeta)) or Target:TimeToDie() < 25) then
    if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "metamorphosis 22"; end
  end
  -- metamorphosis,if=talent.demonic.enabled&(!azerite.chaotic_transformation.enabled|(cooldown.eye_beam.remains>20&(!variable.blade_dance|cooldown.blade_dance.remains>gcd.max)))
  if S.Metamorphosis:IsCastableP(40) and (Player:BuffDownP(S.MetamorphosisBuff) and S.Demonic:IsAvailable() and (not S.ChaoticTransformation:AzeriteEnabled() or (S.EyeBeam:CooldownRemainsP() > 12 and (not bool(VarBladeDance) or S.BladeDance:CooldownRemainsP() > Player:GCD())))) then
    if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "metamorphosis 24"; end
  end
  -- sinful_brand,if=!dot.sinful_brand.ticking
  if S.SinfulBrand:IsCastableP() and (Target:DebuffDownP(S.SinfulBrandDebuff)) then
    if HR.Cast(S.SinfulBrand, nil, nil, 30) then return "sinful_brand 26"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastableP() then
    if HR.Cast(S.TheHunt, nil, nil, 50) then return "the_hunt 28"; end
  end
  -- fodder_to_the_flame
  if S.FoddertotheFlame:IsCastableP() then
    if HR.Cast(S.FoddertotheFlame) then return "fodder_to_the_flame 30"; end
  end
  -- elysian_decree
  if S.ElysianDecree:IsCastableP() then
    if HR.Cast(S.ElysianDecree, nil, nil, 30) then return "elysian_decree 32"; end
  end
  -- potion,if=buff.metamorphosis.remains>25|target.time_to_die<60
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemainsP(S.MetamorphosisBuff) > 25 or Target:TimeToDie() < 60) then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 34"; end
  end
  if (Settings.Commons.UseTrinkets) then
    -- use_item,name=galecallers_boon,if=!talent.fel_barrage.enabled|cooldown.fel_barrage.ready
    if I.GalecallersBoon:IsEquipReady() and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownUpP()) then
      if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "galecallers_boon 36"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=buff.metamorphosis.up&buff.memory_of_lucid_dreams.down&(!variable.blade_dance|!cooldown.blade_dance.ready)
    if Everyone.CyclotronicBlastReady() and (Player:BuffP(S.MetamorphosisBuff) and Player:BuffDownP(S.MemoryofLucidDreams) and (not bool(VarBladeDance) or not S.BladeDance:IsReady())) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "cyclotronic_blast 38"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|(debuff.conductive_ink_debuff.up|buff.metamorphosis.remains>20)&target.health.pct<31|target.time_to_die<20
    if I.AshvanesRazorCoral:IsEquipReady() and (Target:DebuffDownP(S.RazorCoralDebuff) or (Target:DebuffP(S.ConductiveInkDebuff) or Player:BuffRemainsP(S.MetamorphosisBuff) > 20) and Target:HealthPercentage() < 31 or Target:TimeToDie() < 20) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 40"; end
    end
    -- use_item,name=azsharas_font_of_power,if=cooldown.metamorphosis.remains<10|cooldown.metamorphosis.remains>60
    if I.AzsharasFontofPower:IsEquipReady() and (S.Metamorphosis:CooldownRemainsP() < 10 or S.Metamorphosis:CooldownRemainsP() > 60) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 42"; end
    end
  end
  -- use_items,if=buff.metamorphosis.up
  if (Player:BuffP(S.MetamorphosisBuff)) then
    local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- call_action_list,name=essences
  -- Manually added: Player level check, as essences definitely aren't used at 60. Might as well save cycling through the Essences function.
  if (Player:Level() < 60) then
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
  end
end

local function EssenceBreak()
  -- essence_break,if=fury>=80&(cooldown.blade_dance.ready|!variable.blade_dance)
  if S.DarkSlash:IsCastableP() and IsInMeleeRange() and (Player:Fury() >= 80 and (S.BladeDance:CooldownUpP() or not bool(VarBladeDance))) then
    if HR.Cast(S.DarkSlash, nil, nil, "Melee") then return "dark_slash 62"; end
  end
  -- death_sweep,if=variable.blade_dance&debuff.essence_break.up
  -- blade_dance,if=variable.blade_dance&debuff.essence_break.up
  if IsInMeleeRange() and (bool(VarBladeDance) and Target:DebuffDownP(S.EssenceBreakDebuff)) then
    if S.DeathSweep:IsReadyP() then
      if HR.Cast(S.DeathSweep, nil, nil, "Melee") then return "death_sweep 64"; end
    end
    if S.BladeDance:IsReadyP() then
      if HR.Cast(S.BladeDance, nil, nil, "Melee") then return "blade_dance 66"; end
    end
  end
  -- annihilation,if=debuff.essence_break.up
  -- chaos_strike,if=debuff.essence_break.up
  if IsInMeleeRange() and (Target:DebuffP(S.EssenceBreakDebuff)) then
    if S.Annihilation:IsReadyP() then
      if HR.Cast(S.Annihilation, nil, nil, "Melee") then return "annihilation 68"; end
    end
    if S.ChaosStrike:IsReadyP() then
      if HR.Cast(S.ChaosStrike, nil, nil, "Melee") then return "chaos_strike 70"; end
    end
  end
end

local function Demonic()
  -- fel_rush,if=(talent.unbound_chaos.enabled&buff.unbound_chaos.up)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastableP(20, true) and ((S.UnboundChaos:IsAvailable() and Player:BuffP(S.UnboundChaosBuff)) and S.FelRush:ChargesP() == 2) then
    if HR.Cast(S.FelRush, nil, nil, 15) then return "fel_rush 82"; end
  end
  -- death_sweep,if=variable.blade_dance
  if S.DeathSweep:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance)) then
    if HR.Cast(S.DeathSweep, nil, nil, 8) then return "death_sweep 84"; end
  end
  -- glaive_tempest,if=active_enemies>desired_targets|raid_event.adds.in>10
  if S.GlaiveTempest:IsReadyP() and (Cache.EnemiesCount[8] > 1) then
    if HR.Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest, nil, 8) then return "glaive_tempest 86"; end
  end
  -- throw_glaive,if=conduit.serrated_glaive.enabled&cooldown.eye_beam.remains<6&!buff.metamorphosis.up&!debuff.exposed_wound.up
  if S.ThrowGlaive:IsCastableP() and (S.SerratedGlaive:IsAvailable() and S.EyeBeam:CooldownRemainsP() < 6 and Player:BuffDownP(S.MetamorphosisBuff) and Target:DebuffDownP(S.ExposedWoundDebuff)) then
    if HR.Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, 30) then return "throw_glaive 88"; end
  end
  -- eye_beam,if=raid_event.adds.up|raid_event.adds.in>25
  if S.EyeBeam:IsReadyP(20) then
    if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 90"; end
  end
  -- blade_dance,if=variable.blade_dance&!cooldown.metamorphosis.ready&(cooldown.eye_beam.remains>(5-azerite.revolving_blades.rank*3)|(raid_event.adds.in>cooldown&raid_event.adds.in<25))
  if S.BladeDance:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance) and (S.EyeBeam:CooldownRemainsP() > (5 - S.RevolvingBlades:AzeriteRank() * 3))) then
    if HR.Cast(S.BladeDance, nil, nil, 8) then return "blade_dance 92"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastableP() then
    if HR.Cast(S.ImmolationAura) then return "immolation_aura 94"; end
  end
  -- annihilation,if=!variable.pooling_for_blade_dance
  if S.Annihilation:IsReadyP() and IsInMeleeRange() and (not bool(VarPoolingForBladeDance)) then
    if HR.Cast(S.Annihilation, nil, nil, "Melee") then return "annihilation 96"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsCastableP(15) and (Player:FuryDeficit() >= 40) then
    if HR.Cast(S.Felblade) then return "felblade 98"; end
  end
  -- chaos_strike,if=!variable.pooling_for_blade_dance&!variable.pooling_for_eye_beam
  if S.ChaosStrike:IsReadyP() and IsInMeleeRange() and (not bool(VarPoolingForBladeDance) and not bool(VarPoolingForEyeBeam)) then
    if HR.Cast(S.ChaosStrike, nil, nil, "Melee") then return "chaos_strike 100"; end
  end
  -- fel_rush,if=talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastableP(20, true) and (S.DemonBlades:IsAvailable() and not S.EyeBeam:CooldownUpP() and ConserveFelRush()) then
    if CastFelRush() then return "fel_rush 102"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastableP() and IsInMeleeRange() then
    if HR.Cast(S.DemonsBite, nil, nil, "Melee") then return "demons_bite 104"; end
  end
  -- throw_glaive,if=buff.out_of_range.up
  if S.ThrowGlaive:IsCastableP(30) and (not IsInMeleeRange()) then
    if HR.Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive) then return "throw_glaive 106"; end
  end
  -- fel_rush,if=movement.distance>15|buff.out_of_range.up
  -- if S.FelRush:IsCastableP(20, true) and (not IsInMeleeRange() and ConserveFelRush()) then
    -- if CastFelRush() then return "fel_rush 108"; end
  -- end
  -- vengeful_retreat,if=movement.distance>15
  -- if S.VengefulRetreat:IsCastableP("Melee", true) then
    -- if HR.Cast(S.VengefulRetreat) then return "vengeful_retreat 110"; end
  -- end
  -- throw_glaive,if=talent.demon_blades.enabled
  if S.ThrowGlaive:IsCastableP(30) and (S.DemonBlades:IsAvailable()) then
    if HR.Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive) then return "throw_glaive 112"; end
  end
end

local function Normal()
  -- vengeful_retreat,if=talent.momentum.enabled&buff.prepared.down&time>1
  if S.VengefulRetreat:IsCastableP("Melee", true) and (S.Momentum:IsAvailable() and Player:BuffDownP(S.PreparedBuff) and HL.CombatTime() > 1) then
    if HR.Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat 122"; end
  end
  -- fel_rush,if=(variable.waiting_for_momentum|talent.fel_mastery.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastableP(20, true) and (bool(VarWaitingForMomentum) and ConserveFelRush()) then
    if CastFelRush() then return "fel_rush 124"; end
  end
  -- fel_barrage,if=active_enemies>desired_targets|raid_event.adds.in>30
  if S.FelBarrage:IsCastableP() and IsInMeleeRange() and (Cache.EnemiesCount[8] > 1) then
    if HR.Cast(S.FelBarrage, nil, nil, 8) then return "fel_barrage 126"; end
  end
  -- death_sweep,if=variable.blade_dance
  if S.DeathSweep:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance)) then
    if HR.Cast(S.DeathSweep, nil, nil, 8) then return "death_sweep 128"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastableP() then
    if HR.Cast(S.ImmolationAura) then return "immolation_aura 130"; end
  end
  -- glaive_tempest,if=!variable.waiting_for_momentum&(active_enemies>desired_targets|raid_event.adds.in>10)
  if S.GlaiveTempest:IsReadyP() and (not bool(VarWaitingForMomentum) and Cache.EnemiesCount[8] > 1) then
    if HR.Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest, nil, 8) then return "glaive_tempest 132"; end
  end
  -- throw_glaive,if=conduit.serrated_glaive.enabled&cooldown.eye_beam.remains<6&!buff.metamorphosis.up&!debuff.exposed_wound.up
  if S.ThrowGlaive:IsCastableP() and (S.SerratedGlaive:IsAvailable() and S.EyeBeam:CooldownRemainsP() < 6 and Player:BuffDownP(S.MetamorphosisBuff) and Target:DebuffDownP(S.ExposedWoundDebuff)) then
    if HR.Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, 30) then return "throw_glaive 134"; end
  end
  -- eye_beam,if=active_enemies>1&(!raid_event.adds.exists|raid_event.adds.up)&!variable.waiting_for_momentum
  if S.EyeBeam:IsReadyP(20) and (Cache.EnemiesCount[20] > 1 and not bool(VarWaitingForMomentum)) then
    if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 136"; end
  end
  -- blade_dance,if=variable.blade_dance
  if S.BladeDance:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance)) then
    if HR.Cast(S.BladeDance, nil, nil, 8) then return "blade_dance 138"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsCastableP(15) and (Player:FuryDeficit() >= 40) then
    if HR.Cast(S.Felblade) then return "felblade 140"; end
  end
  -- eye_beam,if=!talent.blind_fury.enabled&!variable.waiting_for_essence_break&raid_event.adds.in>cooldown
  if S.EyeBeam:IsReadyP(20) and (not S.BlindFury:IsAvailable() and not bool(VarWaitingForEssenceBreak)) then
    if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 142"; end
  end
  -- annihilation,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance&!variable.waiting_for_essence_break
  if S.Annihilation:IsReadyP() and IsInMeleeRange() and ((S.DemonBlades:IsAvailable() or not bool(VarWaitingForMomentum) or Player:FuryDeficit() < 30 or Player:BuffRemainsP(S.MetamorphosisBuff) < 5) and not bool(VarPoolingForBladeDance) and not bool(VarWaitingForEssenceBreak)) then
    if HR.Cast(S.Annihilation, nil, nil, "Melee") then return "annihilation 144"; end
  end
  -- chaos_strike,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance&!variable.waiting_for_essence_break
  if S.ChaosStrike:IsReadyP() and IsInMeleeRange() and ((S.DemonBlades:IsAvailable() or not bool(VarWaitingForMomentum) or Player:FuryDeficit() < 30) and not bool(VarPoolingForMeta) and not bool(VarPoolingForBladeDance) and not bool(VarWaitingForEssenceBreak)) then
    if HR.Cast(S.ChaosStrike, nil, nil, "Melee") then return "chaos_strike 146"; end
  end
  -- eye_beam,if=talent.blind_fury.enabled&raid_event.adds.in>cooldown
  if S.EyeBeam:IsReadyP(20) and (S.BlindFury:IsAvailable()) then
    if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 148"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastableP() and IsInMeleeRange() then
    if HR.Cast(S.DemonsBite, nil, nil, "Melee") then return "demons_bite 150"; end
  end
  -- fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&talent.demon_blades.enabled
  if S.FelRush:IsCastableP(20, true) and (not S.Momentum:IsAvailable() and S.DemonBlades:IsAvailable() and ConserveFelRush()) then
    if CastFelRush() then return "fel_rush 152"; end
  end
  -- felblade,if=movement.distance>15|buff.out_of_range.up
  -- if S.Felblade:IsCastableP(15) and (not IsInMeleeRange()) then
    -- if HR.Cast(S.Felblade) then return "felblade 154"; end
  -- end
  -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
  -- if S.FelRush:IsCastableP(20, true) and (not IsInMeleeRange() and not S.Momentum:IsAvailable() and ConserveFelRush()) then
    -- if CastFelRush() then return "fel_rush 156"; end
  -- end
  -- vengeful_retreat,if=movement.distance>15
  -- if S.VengefulRetreat:IsCastableP("Melee", true) then
    -- if HR.Cast(S.VengefulRetreat) then return "vengeful_retreat 158"; end
  -- end
  -- throw_glaive,if=talent.demon_blades.enabled
  if S.ThrowGlaive:IsCastableP(30) and (S.DemonBlades:IsAvailable()) then
    if HR.Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive) then return "throw_glaive 160"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end

    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts); if ShouldReturn then return ShouldReturn; end

    -- auto_attack

    -- Set Variables
    -- variable,name=blade_dance,value=talent.first_blood.enabled|spell_targets.blade_dance1>=(3-talent.trail_of_ruin.enabled)
    VarBladeDance = num(S.FirstBlood:IsAvailable() or Cache.EnemiesCount[8] >= (3 - num(S.TrailofRuin:IsAvailable())))
    -- variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30
    VarPoolingForMeta = num(not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemainsP() < 6 and Player:FuryDeficit() > 30)
    -- variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
    VarPoolingForBladeDance = num(bool(VarBladeDance) and (Player:Fury() < 75 - num(S.FirstBlood:IsAvailable()) * 20))
    -- variable,name=pooling_for_eye_beam,value=talent.demonic.enabled&!talent.blind_fury.enabled&cooldown.eye_beam.remains<(gcd.max*2)&fury.deficit>20
    VarPoolingForEyeBeam = num(S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and S.EyeBeam:CooldownRemainsP() < (Player:GCD() * 2) and Player:FuryDeficit() > 20)
    -- variable,name=waiting_for_essence_break,value=talent.essence_break.enabled&!variable.pooling_for_blade_dance&!variable.pooling_for_meta&cooldown.essence_break.up
    VarWaitingForEssenceBreak = num(S.EssenceBreak:IsAvailable() and (not bool(VarPoolingForBladeDance)) and (not bool(VarPoolingForMeta)) and S.EssenceBreak:CooldownUpP())
    -- variable,name=waiting_for_momentum,value=talent.momentum.enabled&!buff.momentum.up
    VarWaitingForMomentum = num(S.Momentum:IsAvailable() and Player:BuffDownP(S.MomentumBuff))

    -- call_action_list,name=cooldown,if=gcd.remains=0
    if HR.CDsON() then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end

    -- pick_up_fragment,if=demon_soul_fragments>0
    -- pick_up_fragment,if=fury.deficit>=35&(!azerite.eyes_of_rage.enabled|cooldown.eye_beam.remains>1.4)
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?

    -- call_action_list,name=essence_break,if=talent.essence_break.enabled&(variable.waiting_for_essence_break|debuff.essence_break.up)
    if (S.EssenceBreak:IsAvailable() and (bool(VarWaitingForEssenceBreak) or Target:DebuffP(S.EssenceBreakDebuff))) then
      local ShouldReturn = EssenceBreak(); if ShouldReturn then return ShouldReturn; end
    end

    -- run_action_list,name=demonic,if=talent.demonic.enabled
    if (S.Demonic:IsAvailable()) then
      local ShouldReturn = Demonic(); if ShouldReturn then return ShouldReturn; end
    end

    -- run_action_list,name=normal
    if (true) then
      local ShouldReturn = Normal(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()
end

HR.SetAPL(577, APL, Init)

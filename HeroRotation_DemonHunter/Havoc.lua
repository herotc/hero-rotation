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
if not Spell.DemonHunter then Spell.DemonHunter = {} end
Spell.DemonHunter.Havoc = {
  MetamorphosisBuff                     = Spell(162264),
  Metamorphosis                         = Spell(191427),
  ChaoticTransformation                 = Spell(288754),
  Demonic                               = Spell(213410),
  EyeBeam                               = Spell(198013),
  BladeDance                            = Spell(188499),
  Nemesis                               = Spell(206491),
  NemesisDebuff                         = Spell(206491),
  DarkSlash                             = Spell(258860),
  Annihilation                          = Spell(201427),
  DarkSlashDebuff                       = Spell(258860),
  ChaosStrike                           = Spell(162794),
  DeathSweep                            = Spell(210152),
  FelBarrage                            = Spell(211053),
  RevolvingBlades                       = Spell(279581),
  ImmolationAura                        = Spell(258920),
  Felblade                              = Spell(232893),
  FelRush                               = Spell(195072),
  DemonBlades                           = Spell(203555),
  DemonsBite                            = Spell(162243),
  ThrowGlaive                           = Spell(185123),
  VengefulRetreat                       = Spell(198793),
  Momentum                              = Spell(206476),
  PreparedBuff                          = Spell(203650),
  FelMastery                            = Spell(192939),
  BlindFury                             = Spell(203550),
  FirstBlood                            = Spell(206416),
  TrailofRuin                           = Spell(258881),
  MomentumBuff                          = Spell(208628),
  Disrupt                               = Spell(183752),
  FelEruption                           = Spell(211881),
  ChaosNova                             = Spell(179057),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
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
  LifebloodBuff                         = MultiSpell(295137, 305694),
  RecklessForceCounter                  = MultiSpell(298409, 302917),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368)
};
local S = Spell.DemonHunter.Havoc;

-- Items
if not Item.DemonHunter then Item.DemonHunter = {} end
Item.DemonHunter.Havoc = {
  PotionofFocusedResolve           = Item(168506),
  AshvanesRazorCoral               = Item(169311),
  DribblingInkpod                  = Item(169319),
  AzsharasFontofPower              = Item(169314),
  GalecallersBoon                  = Item(159614),
  PocketsizedComputationDevice     = Item(167555)
};
local I = Item.DemonHunter.Havoc;

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

-- Variables
local VarPoolingForMeta = 0;
local VarWaitingForNemesis = 0;
local VarBladeDance = 0;
local VarPoolingForBladeDance = 0;
local VarPoolingForEyeBeam = 0;
local VarWaitingForMomentum = 0;
local VarWaitingForDarkSlash = 0;

HL:RegisterForEvent(function()
  VarPoolingForMeta = 0
  VarWaitingForNemesis = 0
  VarBladeDance = 0
  VarPoolingForBladeDance = 0
  VarPoolingForEyeBeam = 0
  VarWaitingForMomentum = 0
  VarWaitingForDarkSlash = 0
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

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Essences, Cooldown, DarkSlash, Demonic, Normal
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- augmentation
    -- food
    -- snapshot_stats
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 4"; end
    end
    -- Immolation Aura
    if S.ImmolationAura:IsCastableP() then
      if HR.Cast(S.ImmolationAura) then return "immolation_aura 5"; end
    end
    -- metamorphosis,if=!azerite.chaotic_transformation.enabled
    if S.Metamorphosis:IsCastableP(40) and (Player:BuffDownP(S.MetamorphosisBuff) and not S.ChaoticTransformation:AzeriteEnabled()) then
      if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "metamorphosis 6"; end
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and HR.CDsON() then
      if HR.Cast(I.AzsharasFontofPower) then return "azsharas_font_of_power 7"; end
    end
  end
  Essences = function()
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Settings.Havoc.GCDasOffGCD.Essences) then return "concentrated_flame"; end
    end
    -- blood_of_the_enemy,if=buff.metamorphosis.up|target.time_to_die<=10
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.MetamorphosisBuff) or Target:TimeToDie() <= 10) then
      if HR.Cast(S.BloodoftheEnemy, Settings.Havoc.GCDasOffGCD.Essences) then return "blood_of_the_enemy"; end
    end
    -- guardian_of_azeroth,if=buff.metamorphosis.up|target.time_to_die<=30
    if S.GuardianofAzeroth:IsCastableP() and (Player:BuffP(S.MetamorphosisBuff) or Target:TimeToDie() <= 30) then
      if HR.Cast(S.GuardianofAzeroth, Settings.Havoc.GCDasOffGCD.Essences) then return "guardian_of_azeroth"; end
    end
    -- focused_azerite_beam,if=spell_targets.blade_dance1>=2|raid_event.adds.in>60
    if S.FocusedAzeriteBeam:IsCastableP() and (Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.FocusedAzeriteBeam, Settings.Havoc.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- purifying_blast,if=spell_targets.blade_dance1>=2|raid_event.adds.in>60
    if S.PurifyingBlast:IsCastableP() and (Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.PurifyingBlast, Settings.Havoc.GCDasOffGCD.Essences) then return "purifying_blast"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffStackP(S.RecklessForceCounter) < 10) then
      if HR.Cast(S.TheUnboundForce, Settings.Havoc.GCDasOffGCD.Essences) then return "the_unbound_force"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, Settings.Havoc.GCDasOffGCD.Essences) then return "ripple_in_space"; end
    end
    -- worldvein_resonance,if=buff.lifeblood.stack<3
    if S.WorldveinResonance:IsCastableP() and (Player:BuffStackP(S.LifebloodBuff) < 3) then
      if HR.Cast(S.WorldveinResonance, Settings.Havoc.GCDasOffGCD.Essences) then return "worldvein_resonance"; end
    end
    -- memory_of_lucid_dreams,if=fury<40&buff.metamorphosis.up
    if S.MemoryofLucidDreams:IsCastableP() and (Player:Fury() < 40 and Player:BuffP(S.MetamorphosisBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, Settings.Havoc.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams"; end
    end
  end
  Cooldown = function()
    -- metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis)|target.time_to_die<25
    if S.Metamorphosis:IsCastableP(40) and (Player:BuffDownP(S.MetamorphosisBuff) and not (S.Demonic:IsAvailable() or bool(VarPoolingForMeta) or bool(VarWaitingForNemesis)) or Target:TimeToDie() < 25) then
      if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "metamorphosis 12"; end
    end
    -- metamorphosis,if=talent.demonic.enabled&(!azerite.chaotic_transformation.enabled|(cooldown.eye_beam.remains>20&(!variable.blade_dance|cooldown.blade_dance.remains>gcd.max)))
    if S.Metamorphosis:IsCastableP(40) and (Player:BuffDownP(S.MetamorphosisBuff) and S.Demonic:IsAvailable() and (not S.ChaoticTransformation:AzeriteEnabled() or (S.EyeBeam:CooldownRemainsP() > 12 and (not bool(VarBladeDance) or S.BladeDance:CooldownRemainsP() > Player:GCD())))) then
      if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "metamorphosis 20"; end
    end
    -- nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
    -- nemesis,if=!raid_event.adds.exists
    if S.Nemesis:IsCastableP(50) and (not Cache.EnemiesCount[40] > 1) then
      if HR.Cast(S.Nemesis, Settings.Havoc.GCDasOffGCD.Nemesis) then return "nemesis 51"; end
    end
    -- potion,if=buff.metamorphosis.remains>25|target.time_to_die<60
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemainsP(S.MetamorphosisBuff) > 25 or Target:TimeToDie() < 60) then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 55"; end
    end
    -- use_item,name=galecallers_boon,if=!talent.fel_barrage.enabled|cooldown.fel_barrage.ready
    if I.GalecallersBoon:IsEquipped() and I.GalecallersBoon:IsReady() and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownUpP()) then
      if HR.CastSuggested(I.GalecallersBoon) then return "galecallers_boon 56"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=buff.metamorphosis.up&buff.memory_of_lucid_dreams.down&(!variable.blade_dance|!cooldown.blade_dance.ready)
    if I.PocketsizedComputationDevice:IsEquipped() and I.PocketsizedComputationDevice:IsReady() and S.CyclotronicBlast:IsAvailable() and (Player:BuffP(S.MetamorphosisBuff) and Player:BuffDownP(S.MemoryofLucidDreams) and (not bool(VarBladeDance) or not S.BladeDance:IsReady())) then
      if HR.CastSuggested(I.PocketsizedComputationDevice) then return "cyclotronic_blast 57"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|(debuff.conductive_ink_debuff.up|buff.metamorphosis.remains>20)&target.health.pct<31|target.time_to_die<20
    if I.AshvanesRazorCoral:IsEquipped() and I.AshvanesRazorCoral:IsReady() and (Target:DebuffDownP(S.RazorCoralDebuff) or (Target:DebuffP(S.ConductiveInkDebuff) or Player:BuffRemainsP(S.MetamorphosisBuff) > 20) and Target:HealthPercentage() < 31 or Target:TimeToDie() < 20) then
      if HR.CastSuggested(I.AshvanesRazorCoral) then return "ashvanes_razor_coral 59"; end
    end
    -- use_item,name=azsharas_font_of_power,if=cooldown.metamorphosis.remains<10|cooldown.metamorphosis.remains>60
    if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and (S.Metamorphosis:CooldownRemainsP() < 10 or S.Metamorphosis:CooldownRemainsP() > 60) then
      if HR.CastSuggested(I.AzsharasFontofPower) then return "azsharas_font_of_power 60"; end
    end
    -- use_items,if=buff.metamorphosis.up
    -- call_action_list,name=essences
    if (true) then
      local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
  end
  DarkSlash = function()
    -- dark_slash,if=fury>=80&(!variable.blade_dance|!cooldown.blade_dance.ready)
    if S.DarkSlash:IsCastableP() and IsInMeleeRange() and (Player:Fury() >= 80 and (not bool(VarBladeDance) or not S.BladeDance:CooldownUpP())) then
      if HR.Cast(S.DarkSlash) then return "dark_slash 61"; end
    end
    -- annihilation,if=debuff.dark_slash.up
    if S.Annihilation:IsReadyP() and IsInMeleeRange() and (Target:DebuffP(S.DarkSlashDebuff)) then
      if HR.Cast(S.Annihilation) then return "annihilation 67"; end
    end
    -- chaos_strike,if=debuff.dark_slash.up
    if S.ChaosStrike:IsReadyP() and IsInMeleeRange() and (Target:DebuffP(S.DarkSlashDebuff)) then
      if HR.Cast(S.ChaosStrike) then return "chaos_strike 71"; end
    end
  end
  Demonic = function()
    -- death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance)) then
      if HR.Cast(S.DeathSweep) then return "death_sweep 75"; end
    end
    -- eye_beam,if=raid_event.adds.up|raid_event.adds.in>25
    if S.EyeBeam:IsReadyP(20) then
      if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 79"; end
    end
    -- fel_barrage,if=((!cooldown.eye_beam.up|buff.metamorphosis.up)&raid_event.adds.in>30)|active_enemies>desired_targets
    if S.FelBarrage:IsCastableP() and IsInMeleeRange() and ((not S.EyeBeam:CooldownUpP() or Player:BuffP(S.MetamorphosisBuff)) or Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.FelBarrage) then return "fel_barrage 83"; end
    end
    -- blade_dance,if=variable.blade_dance&!cooldown.metamorphosis.ready&(cooldown.eye_beam.remains>(5-azerite.revolving_blades.rank*3)|(raid_event.adds.in>cooldown&raid_event.adds.in<25))
    if S.BladeDance:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance) and (S.EyeBeam:CooldownRemainsP() > (5 - S.RevolvingBlades:AzeriteRank() * 3))) then
      if HR.Cast(S.BladeDance) then return "blade_dance 95"; end
    end
    -- immolation_aura
    if S.ImmolationAura:IsCastableP() then
      if HR.Cast(S.ImmolationAura) then return "immolation_aura 109"; end
    end
    -- annihilation,if=!variable.pooling_for_blade_dance
    if S.Annihilation:IsReadyP() and IsInMeleeRange() and (not bool(VarPoolingForBladeDance)) then
      if HR.Cast(S.Annihilation) then return "annihilation 111"; end
    end
    -- felblade,if=fury.deficit>=40
    if S.Felblade:IsCastableP(15) and (Player:FuryDeficit() >= 40) then
      if HR.Cast(S.Felblade) then return "felblade 115"; end
    end
    -- chaos_strike,if=!variable.pooling_for_blade_dance&!variable.pooling_for_eye_beam
    if S.ChaosStrike:IsReadyP() and IsInMeleeRange() and (not bool(VarPoolingForBladeDance) and not bool(VarPoolingForEyeBeam)) then
      if HR.Cast(S.ChaosStrike) then return "chaos_strike 117"; end
    end
    -- fel_rush,if=talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastableP(20, true) and (S.DemonBlades:IsAvailable() and not S.EyeBeam:CooldownUpP() and ConserveFelRush()) then
      if CastFelRush() then return "fel_rush 123"; end
    end
    -- demons_bite
    if S.DemonsBite:IsCastableP() and IsInMeleeRange() then
      if HR.Cast(S.DemonsBite) then return "demons_bite 133"; end
    end
    -- throw_glaive,if=buff.out_of_range.up
    if S.ThrowGlaive:IsCastableP(30) and (not IsInMeleeRange()) then
      if HR.Cast(S.ThrowGlaive) then return "throw_glaive 135"; end
    end
    -- fel_rush,if=movement.distance>15|buff.out_of_range.up
    -- if S.FelRush:IsCastableP(20, true) and (not IsInMeleeRange() and ConserveFelRush()) then
      -- if CastFelRush() then return "fel_rush 139"; end
    -- end
    -- vengeful_retreat,if=movement.distance>15
    -- if S.VengefulRetreat:IsCastableP("Melee", true) then
      -- if HR.Cast(S.VengefulRetreat) then return "vengeful_retreat 143"; end
    -- end
    -- throw_glaive,if=talent.demon_blades.enabled
    if S.ThrowGlaive:IsCastableP(30) and (S.DemonBlades:IsAvailable()) then
      if HR.Cast(S.ThrowGlaive) then return "throw_glaive 145"; end
    end
  end
  Normal = function()
    -- vengeful_retreat,if=talent.momentum.enabled&buff.prepared.down&time>1
    if S.VengefulRetreat:IsCastableP("Melee", true) and (S.Momentum:IsAvailable() and Player:BuffDownP(S.PreparedBuff) and HL.CombatTime() > 1) then
      if HR.Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat 149"; end
    end
    -- fel_rush,if=(variable.waiting_for_momentum|talent.fel_mastery.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastableP(20, true) and ((bool(VarWaitingForMomentum) or S.FelMastery:IsAvailable()) and ConserveFelRush()) then
      if CastFelRush() then return "fel_rush 155"; end
    end
    -- fel_barrage,if=!variable.waiting_for_momentum&(active_enemies>desired_targets|raid_event.adds.in>30)
    if S.FelBarrage:IsCastableP() and IsInMeleeRange() and (not bool(VarWaitingForMomentum) and Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.FelBarrage) then return "fel_barrage 165"; end
    end
    -- death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance)) then
      if HR.Cast(S.DeathSweep) then return "death_sweep 175"; end
    end
    -- immolation_aura
    if S.ImmolationAura:IsCastableP() then
      if HR.Cast(S.ImmolationAura) then return "immolation_aura 179"; end
    end
    -- eye_beam,if=active_enemies>1&(!raid_event.adds.exists|raid_event.adds.up)&!variable.waiting_for_momentum
    if S.EyeBeam:IsReadyP(20) and (Cache.EnemiesCount[20] > 1 and not bool(VarWaitingForMomentum)) then
      if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 181"; end
    end
    -- blade_dance,if=variable.blade_dance
    if S.BladeDance:IsReadyP() and IsInMeleeRange() and (bool(VarBladeDance)) then
      if HR.Cast(S.BladeDance) then return "blade_dance 195"; end
    end
    -- felblade,if=fury.deficit>=40
    if S.Felblade:IsCastableP(15) and (Player:FuryDeficit() >= 40) then
      if HR.Cast(S.Felblade) then return "felblade 199"; end
    end
    -- eye_beam,if=!talent.blind_fury.enabled&!variable.waiting_for_dark_slash&raid_event.adds.in>cooldown
    if S.EyeBeam:IsReadyP(20) and (not S.BlindFury:IsAvailable() and not bool(VarWaitingForDarkSlash)) then
      if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 201"; end
    end
    -- annihilation,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance&!variable.waiting_for_dark_slash
    if S.Annihilation:IsReadyP() and IsInMeleeRange() and ((S.DemonBlades:IsAvailable() or not bool(VarWaitingForMomentum) or Player:FuryDeficit() < 30 or Player:BuffRemainsP(S.MetamorphosisBuff) < 5) and not bool(VarPoolingForBladeDance) and not bool(VarWaitingForDarkSlash)) then
      if HR.Cast(S.Annihilation) then return "annihilation 211"; end
    end
    -- chaos_strike,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance&!variable.waiting_for_dark_slash
    if S.ChaosStrike:IsReadyP() and IsInMeleeRange() and ((S.DemonBlades:IsAvailable() or not bool(VarWaitingForMomentum) or Player:FuryDeficit() < 30) and not bool(VarPoolingForMeta) and not bool(VarPoolingForBladeDance) and not bool(VarWaitingForDarkSlash)) then
      if HR.Cast(S.ChaosStrike) then return "chaos_strike 223"; end
    end
    -- eye_beam,if=talent.blind_fury.enabled&raid_event.adds.in>cooldown
    if S.EyeBeam:IsReadyP(20) and (S.BlindFury:IsAvailable()) then
      if HR.Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam) then return "eye_beam 235"; end
    end
    -- demons_bite
    if S.DemonsBite:IsCastableP() and IsInMeleeRange() then
      if HR.Cast(S.DemonsBite) then return "demons_bite 243"; end
    end
    -- fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&talent.demon_blades.enabled
    if S.FelRush:IsCastableP(20, true) and (not S.Momentum:IsAvailable() and S.DemonBlades:IsAvailable() and ConserveFelRush()) then
      if CastFelRush() then return "fel_rush 245"; end
    end
    -- felblade,if=movement.distance>15|buff.out_of_range.up
    -- if S.Felblade:IsCastableP(15) and (not IsInMeleeRange()) then
      -- if HR.Cast(S.Felblade) then return "felblade 255"; end
    -- end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
    -- if S.FelRush:IsCastableP(20, true) and (not IsInMeleeRange() and not S.Momentum:IsAvailable() and ConserveFelRush()) then
      -- if CastFelRush() then return "fel_rush 259"; end
    -- end
    -- vengeful_retreat,if=movement.distance>15
    -- if S.VengefulRetreat:IsCastableP("Melee", true) then
      -- if HR.Cast(S.VengefulRetreat) then return "vengeful_retreat 265"; end
    -- end
    -- throw_glaive,if=talent.demon_blades.enabled
    if S.ThrowGlaive:IsCastableP(30) and (S.DemonBlades:IsAvailable()) then
      if HR.Cast(S.ThrowGlaive) then return "throw_glaive 267"; end
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    
    -- Interrupts
    Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts);
    
    -- auto_attack
    
    -- Set Variables
    -- variable,name=blade_dance,value=talent.first_blood.enabled|spell_targets.blade_dance1>=(3-talent.trail_of_ruin.enabled)
    VarBladeDance = num(S.FirstBlood:IsAvailable() or Cache.EnemiesCount[8] >= (3 - num(S.TrailofRuin:IsAvailable())))
    -- variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
    VarWaitingForNemesis = num(not (not S.Nemesis:IsAvailable() or S.Nemesis:CooldownUpP() or S.Nemesis:CooldownRemainsP() > Target:TimeToDie() or S.Nemesis:CooldownRemainsP() > 60))
    -- variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)
    VarPoolingForMeta = num(not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemainsP() < 6 and Player:FuryDeficit() > 30 and (not bool(VarWaitingForNemesis) or S.Nemesis:CooldownRemainsP() < 10))
    -- variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
    VarPoolingForBladeDance = num(bool(VarBladeDance) and (Player:Fury() < 75 - num(S.FirstBlood:IsAvailable()) * 20))
    -- variable,name=pooling_for_eye_beam,value=talent.demonic.enabled&!talent.blind_fury.enabled&cooldown.eye_beam.remains<(gcd.max*2)&fury.deficit>20
    VarPoolingForEyeBeam = num(S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and S.EyeBeam:CooldownRemainsP() < (Player:GCD() * 2) and Player:FuryDeficit() > 20)
    -- variable,name=waiting_for_dark_slash,value=talent.dark_slash.enabled&!variable.pooling_for_blade_dance&!variable.pooling_for_meta&cooldown.dark_slash.up
    VarWaitingForDarkSlash = num(S.DarkSlash:IsAvailable() and not bool(VarPoolingForBladeDance) and not bool(VarPoolingForMeta) and S.DarkSlash:CooldownUpP())
    -- variable,name=waiting_for_momentum,value=talent.momentum.enabled&!buff.momentum.up
    VarWaitingForMomentum = num(S.Momentum:IsAvailable() and not Player:BuffP(S.MomentumBuff))
    
    -- call_action_list,name=cooldown,if=gcd.remains=0
    if HR.CDsON() then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    
    -- pick_up_fragment,if=fury.deficit>=35
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?
    
    -- call_action_list,name=dark_slash,if=talent.dark_slash.enabled&(variable.waiting_for_dark_slash|debuff.dark_slash.up)
    if (S.DarkSlash:IsAvailable() and (bool(VarWaitingForDarkSlash) or Target:DebuffP(S.DarkSlashDebuff))) then
      local ShouldReturn = DarkSlash(); if ShouldReturn then return ShouldReturn; end
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

local function Init ()
  -- Register Splash Data Nucleus Abilities
  HL.RegisterNucleusAbility(191427, 8, 6)               -- Metamorphosis
  HL.RegisterNucleusAbility(198013, 20, 6)              -- Eye Beam
  HL.RegisterNucleusAbility(188499, 8, 6)               -- Blade Dance
  HL.RegisterNucleusAbility(210152, 8, 6)               -- Death Sweep
  HL.RegisterNucleusAbility(258920, 8, 6)               -- Immolation Aura
  HL.RegisterNucleusAbility(179057, 8, 6)               -- Chaos Nova
end

HR.SetAPL(577, APL, Init)
--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet = Unit.Pet
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Monk then Spell.Monk = {} end
Spell.Monk.Brewmaster = {
  -- Racials
  AncestralCall                = Spell(274738),
  ArcaneTorrent                = Spell(50613),
  BagofTricks                  = Spell(312411),
  Berserking                   = Spell(26297),
  BloodFury                    = Spell(20572),
  Fireblood                    = Spell(265221),
  LightsJudgment               = Spell(255647),
  -- Abilities
  BreathofFire                 = Spell(115181),
  BreathofFireDotDebuff        = Spell(123725),
  CelestialBrew                = Spell(322507),
  CelestialBrewBuff            = Spell(322507),
  ExpelHarm                    = Spell(322101),
  FortifyingBrew               = Spell(115203),
  FortifyingBrewBuff           = Spell(120954),
  HealingSphere                = Spell(115072), -- New Expel Harm doesn't track spheres, but old ID seems to still work?
  InvokeNiuzaotheBlackOx       = Spell(132578),
  KegSmash                     = Spell(121253),
  LegSweep                     = Spell(119381),
  PurifyingBrew                = Spell(119582),
  SpearHandStrike              = Spell(116705),
  TigerPalm                    = Spell(100780),
  -- Talents
  BlackoutCombo                = Spell(196736),
  BlackoutComboBuff            = Spell(228563),
  BlackoutKick                 = Spell(205523),
  BlackOxBrew                  = Spell(115399),
  BobandWeave                  = Spell(280515),
  ChiBurst                     = Spell(123986),
  ChiWave                      = Spell(115098),
  DampenHarm                   = Spell(122278),
  DampenHarmBuff               = Spell(122278),
  LightBrewing                 = Spell(325093),
  RushingJadeWind              = Spell(116847),
  SpecialDelivery              = Spell(196730),
  -- Artifact Traits
  ExplodingKeg                 = Spell(214326),
  PotentKick                   = Spell(213047),
  -- Stagger Levels
  HeavyStagger                 = Spell(124273),
  ModerateStagger              = Spell(124274),
  LightStagger                 = Spell(124275),
  -- Essences
  BloodoftheEnemy              = Spell(297108),
  MemoryofLucidDreams          = Spell(298357),
  PurifyingBlast               = Spell(295337),
  RippleInSpace                = Spell(302731),
  ConcentratedFlame            = Spell(295373),
  TheUnboundForce              = Spell(298452),
  WorldveinResonance           = Spell(295186),
  FocusedAzeriteBeam           = Spell(295258),
  GuardianofAzeroth            = Spell(295840),
  SuppressingPulse             = Spell(293031),
  RecklessForceBuff            = Spell(302932),
  ConcentratedFlameBurn        = Spell(295368),
  -- Trinket Effects
  RazorCoralDebuff             = Spell(303568),
  ConductiveInkDebuff          = Spell(302565),
  -- Misc
  PoolEnergy                   = Spell(9999000010)
};
local S = Spell.Monk.Brewmaster;
if AEMajor ~= nil then
  S.HeartEssence               = Spell(AESpellIDs[AEMajor.ID])
end

-- Items
if not Item.Monk then Item.Monk = {} end
Item.Monk.Brewmaster = {
  -- BfA
  PotionofUnbridledFury        = Item(169299),
  PocketsizedComputationDevice = Item(167555, {13, 14}),
  AshvanesRazorCoral           = Item(169311, {13, 14}),
};
local I = Item.Monk.Brewmaster;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- BfA
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local IsTanking;
local PassiveEssence;
local ForceOffGCD = {true, false};

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Monk.Commons,
  Brewmaster = HR.GUISettings.APL.Monk.Brewmaster
};

-- Interrupts List
local StunInterrupts = {
  {S.LegSweep, "Cast Leg Sweep (Interrupt)", function () return true; end},
};

HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence();
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID]);
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

-- Compute healing amount available from orbs
local function HealingSphereAmount()
  return 1.5 * Player:AttackPowerDamageMod() * (1 + (Player:VersatilityDmgPct() / 100)) * S.HealingSphere:Count()
end

local function ShouldPurify ()
  local NextStaggerTick = 0;
  local NextStaggerTickMaxHPPct = 0;
  local StaggersRatioPct = 0;

  if Player:Debuff(S.HeavyStagger) then
    NextStaggerTick = Player:Debuff(S.HeavyStagger, 16)
  elseif Player:Debuff(S.ModerateStagger) then
    NextStaggerTick = Player:Debuff(S.ModerateStagger, 16)
  elseif Player:Debuff(S.LightStagger) then
    NextStaggerTick = Player:Debuff(S.LightStagger, 16)
  end

  if NextStaggerTick > 0 then
    NextStaggerTickMaxHPPct = NextStaggerTick / Player:MaxHealth();
    StaggersRatioPct = Player:Stagger() / Player:StaggerFull();
  end

  -- Do not purify at the start of a combat since the normalization is not stable yet
  if HL.CombatTime() <= 9 then return false end;

  -- Do purify only if we are loosing more than 3% HP per second (1.5% * 2 since it ticks every 500ms), i.e. above Grey level
  if NextStaggerTickMaxHPPct > 0.015 and StaggersRatioPct > 0 then
    if NextStaggerTickMaxHPPct <= 0.03 then -- Yellow: 6% HP per second, only if the stagger ratio is > 80%
      return Settings.Brewmaster.Purify.Low and StaggersRatioPct > 0.8 or false;
    elseif NextStaggerTickMaxHPPct <= 0.05 then -- Orange: <= 10% HP per second, only if the stagger ratio is > 70%
      return Settings.Brewmaster.Purify.Medium and StaggersRatioPct > 0.7 or false;
    elseif NextStaggerTickMaxHPPct <= 0.1 then -- Red: <= 20% HP per second, only if the stagger ratio value is > 50%
      return Settings.Brewmaster.Purify.High and StaggersRatioPct > 0.5 or false;
    else -- Magenta: > 20% HP per second, ASAP
      return true;
    end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 2"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastableP() then
    if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 4"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastableP() then
    if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 6"; end
  end
  -- Manually added: keg_smash,if=!talent.chi_burst.enabled&!talent.chi_wave.enabled
  if S.KegSmash:IsReadyP() and (not S.ChiBurst:IsAvailable() and not S.ChiWave:IsAvailable()) then
    if HR.Cast(S.KegSmash, nil, nil, 40) then return "keg_smash 8"; end
  end
end

local function Defensives(Tanking)

  -- dampen_harm,if=incoming_damage_1500ms&buff.fortifying_brew.down
  if Tanking and S.DampenHarm:IsCastable() and (Player:BuffDownP(S.FortifyingBrewBuff)) then
    if HR.Cast(S.DampenHarm) then return "dampen_harm 12"; end
  end
  -- fortifying_brew,if=incoming_damage_1500ms&(buff.dampen_harm.down|buff.diffuse_magic.down)
  -- Manually added ShouldPurify() to ensure enough damage to warrant the CD
  if Tanking and S.FortifyingBrew:IsCastable() and ShouldPurify() and (Player:BuffDownP(S.DampenHarmBuff)) then
    if HR.Cast(S.FortifyingBrew, Settings.Brewmaster.OffGCDasOffGCD.FortifyingBrew) then return "fortifying_brew 14"; end
  end
  -- Defensive Azerite Essence
  if Tanking and S.SuppressingPulse:IsCastableP() then
    if HR.Cast(S.SuppressingPulse, true) then return "suppressing_pulse 16"; end
  end
  -- Note : We do not use the SimC conditions but rather the usage recommended by the Normalized Stagger WA.
  if Settings.Brewmaster.Purify.Enabled and S.PurifyingBrew:IsCastableP() and ShouldPurify() then
    if HR.Cast(S.PurifyingBrew, Settings.Brewmaster.OffGCDasOffGCD.PurifyingBrew) then return "purifying_brew 18"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  HL.GetEnemies(8, true);
  HL.GetEnemies(10);
  Everyone.AoEToggleEnemiesUpdate();

  -- Misc
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);
  PassiveEssence = (Spell:MajorEssenceEnabled(AE.VisionofPerfection) or Spell:MajorEssenceEnabled(AE.ConflictandStrife) or Spell:MajorEssenceEnabled(AE.TheFormlessVoid) or Spell:MajorEssenceEnabled(AE.TouchoftheEverlasting));

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Defensives
    local ShouldReturn = Defensives(IsTanking); if ShouldReturn then return ShouldReturn; end
    -- gift_of_the_ox,if=health<health.max*0.65
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<31|target.time_to_die<20
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or Target:DebuffP(S.ConductiveInkDebuff) and Target:HealthPercentage() < 31 or Target:TimeToDie() < 20) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 32"; end
    end
    -- Manually placing PSCD here
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "PSCD 34"; end
    end
    -- use_items
    if Settings.Commons.UseTrinkets then
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 36"; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 38"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 40"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, 40) then return "lights_judgment 42"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 44"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 46"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastableP() then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, 40) then return "bag_of_tricks 48"; end
    end
    -- invoke_niuzao_the_black_ox,if=target.time_to_die>25
    if S.InvokeNiuzaotheBlackOx:IsCastableP() and (Target:TimeToDie() > 25) then
      if HR.Cast(S.InvokeNiuzaotheBlackOx, Settings.Brewmaster.OffGCDasOffGCD.InvokeNiuzaotheBlackOx, nil, 40) then return "invoke_niuzao_the_black_ox 50"; end
    end
    -- black_ox_brew,if=cooldown.brews.charges_fractional<0.5
    if S.BlackOxBrew:IsCastableP() and IsTanking and (S.PurifyingBrew:ChargesFractional() <= 0.5 and not S.CelestialBrew:CooldownUpP()) then
      if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "black_ox_brew 52"; end
    end
    -- black_ox_brew,if=(energy+(energy.regen*cooldown.keg_smash.remains))<40&buff.blackout_combo.down&cooldown.keg_smash.up
    if S.BlackOxBrew:IsCastableP() and IsTanking and ((Player:Energy() + (Player:EnergyRegen() * S.KegSmash:CooldownRemainsP())) < 40 and Player:BuffDownP(S.BlackoutComboBuff) and S.KegSmash:CooldownUpP()) then
      if S.PurifyingBrew:Charges() >= 1 and Player:StaggerPercentage() >= 1 then
        HR.Cast(S.PurifyingBrew, ForceOffGCD);
      end
      if HR.Cast(S.BlackOxBrew) then return "black_ox_brew 54"; end
    end
    -- keg_smash,if=spell_targets>=2
    if S.KegSmash:IsReadyP() and (Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.KegSmash, nil, nil, 40) then return "keg_smash 56"; end
    end
    -- tiger_palm,if=talent.rushing_jade_wind.enabled&buff.blackout_combo.up&buff.rushing_jade_wind.up
    if S.TigerPalm:IsReadyP() and (S.RushingJadeWind:IsAvailable() and Player:BuffP(S.BlackoutComboBuff) and Player:BuffP(S.RushingJadeWind)) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 58"; end
    end
    -- tiger_palm,if=(1|talent.special_delivery.enabled)&buff.blackout_combo.up
    if S.TigerPalm:IsReadyP() and (Player:BuffP(S.BlackoutComboBuff)) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 60"; end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>4
    -- Note : Extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReadyP() and (S.HealingSphere:Count() > 4 and Player:Health() + HealingSphereAmount() < Player:MaxHealth()) then
      if HR.Cast(S.ExpelHarm, nil, nil, 8) then return "expel_harm 62"; end
    end
    -- blackout_kick
    if S.BlackoutKick:IsCastableP() then
      if HR.Cast(S.BlackoutKick, nil, nil, "Melee") then return "blackout_kick 64"; end
    end
    -- keg_smash
    if S.KegSmash:IsReadyP() then
      if HR.Cast(S.KegSmash, nil, nil, 40) then return "keg_smash 66"; end
    end
    if HR.CDsON() then
      -- concentrated_flame,if=dot.concentrated_flame.remains=0
      if S.ConcentratedFlame:IsCastableP(40) and (Target:DebuffDownP(S.ConcentratedFlameBurn)) then
        if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 68"; end
      end
      -- heart_essence,if=!essence.the_crucible_of_flame.major
      if S.HeartEssence ~= nil and not PassiveEssence and S.HeartEssence:IsCastableP() and (not Spell:MajorEssenceEnabled(AE.TheCrucibleofFlame)) then
        if HR.Cast(S.HeartEssence, nil, Settings.Commons.EssenceDisplayStyle) then return "heart_essence 70"; end
      end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>=3
    -- Note : Extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReadyP() and (S.HealingSphere:Count() >= 3 and Player:Health() + HealingSphereAmount() < Player:MaxHealth()) then
      if HR.Cast(S.ExpelHarm, nil, nil, 8) then return "expel_harm 72"; end
    end
    -- rushing_jade_wind,if=buff.rushing_jade_wind.down
    if S.RushingJadeWind:IsCastableP() and (Player:BuffDownP(S.RushingJadeWind)) then
      if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 74"; end
    end
    -- breath_of_fire,if=buff.blackout_combo.down&(buff.bloodlust.down|(buff.bloodlust.up&&dot.breath_of_fire_dot.refreshable))
    if S.BreathofFire:IsCastableP() and (Player:BuffDownP(S.BlackoutComboBuff) and (Player:HasNotHeroism() or (Player:HasHeroism() and true and Target:DebuffRefreshableCP(S.BreathofFireDotDebuff)))) then
      if HR.Cast(S.BreathofFire, nil, nil, 12) then return "breath_of_fire 76"; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastableP() then
      if HR.Cast(S.ChiBurst, nil, nil, 40) then return "chi_burst 78"; end
    end
    -- chi_wave
    if S.ChiWave:IsCastableP() then
      if HR.Cast(S.ChiWave, nil, nil, 40) then return "chi_wave 80"; end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>=2
    -- Note : Extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReadyP() and (S.HealingSphere:Count() >= 2 and Player:Health() + HealingSphereAmount() < Player:MaxHealth()) then
      if HR.Cast(S.ExpelHarm, nil, nil, 8) then return "expel_harm 82"; end
    end
    -- tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>gcd&(energy+(energy.regen*(cooldown.keg_smash.remains+gcd)))>=65
    if S.TigerPalm:IsReadyP() and (not S.BlackoutCombo:IsAvailable() and S.KegSmash:CooldownRemainsP() > Player:GCD() and (Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP() + Player:GCD()))) >= 65) then
      if HR.Cast(S.TigerPalm, nil, nil, "Melee") then return "tiger_palm 84"; end
    end
    -- arcane_torrent,if=energy<31
    if HR.CDsON() and S.ArcaneTorrent:IsCastableP() and (Player:Energy() < 31) then
      if HR.Cast(S.ArcaneTorrent, Settings.Brewmaster.OffGCDasOffGCD.ArcaneTorrent, nil, 8) then return "arcane_torrent 86"; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsCastableP() then
      if HR.Cast(S.RushingJadeWind, nil, nil, 8) then return "rushing_jade_wind 88"; end
    end
    -- Trick to take in consideration the Recovery Setting (and Melee Range)
    if S.TigerPalm:IsCastable("Melee") then
      if HR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
    end
    if S.CracklingJadeLightning:IsReady() and (not Target:IsInRange("Melee")) then
      if HR.Cast(S.CracklingJadeLightning, nil, nil, 40) then return "crackling_jade_lightning 90 (OOR)"; end
    end
  end
end

HR.SetAPL(268, APL)

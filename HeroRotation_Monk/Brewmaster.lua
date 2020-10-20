--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
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
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Lua
local mathmin    = math.min
local pairs      = pairs;

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()
--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Monk.Brewmaster;
local I = Item.Monk.Brewmaster;
if AEMajor ~= nil then
  S.HeartEssence               = Spell(AESpellIDs[AEMajor.ID])
end

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- BfA
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
}

-- Rotation Var
local IsInMeleeRange, IsInAoERange
local ShouldReturn; -- Used to get the return string
local PassiveEssence;
local ForceOffGCD = {true, false};

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Brewmaster = HR.GUISettings.APL.Monk.Brewmaster
};

HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence();
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID]);
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ConcentratedFlame:RegisterInFlight()

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
end, "PLAYER_REGEN_ENABLED")

-- Melee Is In Range w/ Movement Handlers
local function IsInMeleeRange(range)
  if S.TigerPalm:TimeSinceLastCast() <= Player:GCD() then
    return true
  end
  return range and Target:IsInMeleeRange(range) or Target:IsInMeleeRange(5)
end

-- Compute healing amount available from orbs
local function HealingSphereAmount()
  return 1.5 * Player:AttackPowerDamageMod() * (1 + (Player:VersatilityDmgPct() / 100)) * S.ExpelHarm:Count()
end

local function ShouldPurify (BrewMaxCharges)
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

  -- Purify if we refreshed ISB in the last 3 seconds and we are about to cap our brews charges
  if NextStaggerTickMaxHPPct > 0 and S.Brews:ChargesFractional() >= BrewMaxCharges - 0.2 and Player:BuffRemains(S.Shuffle) >= 18 then return true end;

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

local ShuffleDuration = 5;
local function Defensives()
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);
  local BrewMaxCharges = 3 + (S.LightBrewing:IsAvailable() and 1 or 0);

  if S.SuppressingPulse:IsCastableP() then
    if HR.Cast(S.SuppressingPulse, true) then return "Suppressing Pulse"; end
  end
  -- ironskin_brew,if=buff.blackout_combo.down&incoming_damage_1999ms>(health.max*0.1+stagger.last_tick_damage_4)&buff.elusive_brawler.stack<2&!buff.ironskin_brew.up
  -- ironskin_brew,if=cooldown.brews.charges_fractional>1&cooldown.black_ox_brew.remains<3&buff.ironskin_brew.remains<15
  -- Note: Extra handling of the charge management only while tanking.
  --       "- (IsTanking and 1 + (Player:BuffRemains(S.Shuffle) <= ShuffleDuration * 0.5 and 0.5 or 0) or 0)"
  -- TODO: See if this can be optimized
  if S.IronskinBrew:IsCastableP() and Player:BuffDownP(S.BlackoutComboBuff)
      and S.Brews:ChargesFractional() >= BrewMaxCharges - 0.1 - (IsTanking and 1 + (Player:BuffRemains(S.Shuffle) <= ShuffleDuration * 0.5 and 0.5 or 0) or 0)
      and S.BlackOxBrew:CooldownRemainsP() < 3 and Player:BuffRemains(S.Shuffle) < 15 then
    if HR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return "Ironskin Brew"; end
  end
  -- purifying_brew,if=stagger.pct>(6*(3-(cooldown.brews.charges_fractional)))&(stagger.last_tick_damage_1>((0.02+0.001*(3-cooldown.brews.charges_fractional))*stagger.last_tick_damage_30))
  -- Note : We do not use the SimC conditions but rather the usage recommended by the Normalized Stagger WA.
  if Settings.Brewmaster.Purify.Enabled and S.PurifyingBrew:IsCastableP() and ShouldPurify(BrewMaxCharges) then
    if HR.Cast(S.PurifyingBrew, Settings.Brewmaster.OffGCDasOffGCD.PurifyingBrew) then return "Purifying Brew"; end
  end
  -- BlackoutCombo Stagger Pause w/ Ironskin Brew
  if S.IronskinBrew:IsCastableP() and Player:BuffP(S.BlackoutComboBuff) and Player:HealingAbsorbed() and ShouldPurify(BrewMaxCharges) then
    if HR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return "Ironskin Brew 2"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  IsInMeleeRange();
  --Everyone.AoEToggleEnemiesUpdate();

  -- Misc
  PassiveEssence = (Spell:MajorEssenceEnabled(AE.VisionofPerfection) or Spell:MajorEssenceEnabled(AE.ConflictandStrife) or Spell:MajorEssenceEnabled(AE.TheFormlessVoid) or Spell:MajorEssenceEnabled(AE.TouchoftheEverlasting));

  --- Out of Combat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "Potion of Unbridled Fury"; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastableP(10) then
      if HR.Cast(S.ChiBurst, nil, nil, 40) then return "Chi Burst"; end
    end
    -- chi_wave
    if S.ChiWave:IsCastableP(25) then
      if HR.Cast(S.ChiWave, nil, nil, 40) then return "Chi Wave"; end
    end
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, false); if ShouldReturn then return ShouldReturn; end
    -- Defensives
    ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    if HR.CDsON() and Target:IsInRange("Melee") then
      -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<31|target.time_to_die<20
      if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or Target:DebuffP(S.ConductiveInkDebuff) and Target:HealthPercentage() < 31 or Target:TimeToDie() < 20) then
        if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "Ashvanes Razor Coral"; end
      end
      -- Manually placing PSCD here
      if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "Pocketsized Computation Device"; end
      end
      -- use_items
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "Potion of Unbridled Fury 2"; end
      end
      -- blood_fury
      if S.BloodFury:IsCastableP() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Blood Fury"; end
      end
      -- berserking
      if S.Berserking:IsCastableP() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Berserking"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastableP() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, 40) then return "Lights Judgment"; end
      end
      -- fireblood
      if S.Fireblood:IsCastableP() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Fireblood"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastableP() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Ancestral Call"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastableP() then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, 40) then return "Bag of Tricks"; end
      end
      -- invoke_niuzao_the_black_ox
      if S.InvokeNiuzaotheBlackOx:IsCastableP() and Target:TimeToDie() > 25 then
        if HR.Cast(S.InvokeNiuzaotheBlackOx, Settings.Brewmaster.OffGCDasOffGCD.InvokeNiuzaotheBlackOx) then return "Invoke Niuzao the Black Ox"; end
      end
      -- black_ox_brew,if=cooldown.brews.charges_fractional<0.5
      if S.BlackOxBrew:IsCastableP() and S.Brews:ChargesFractional() <= 0.5 then
        if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "Black Ox Brew"; end
      end
      -- black_ox_brew,if=(energy+(energy.regen*cooldown.keg_smash.remains))<40&buff.blackout_combo.down&cooldown.keg_smash.up
      if S.BlackOxBrew:IsCastableP() and (Player:Energy() + (Player:EnergyRegen() * S.KegSmash:CooldownRemainsP())) < 40 and Player:BuffDownP(S.BlackoutComboBuff) and S.KegSmash:CooldownUpP() then
        if S.Brews:Charges() >= 2 and Player:StaggerPercentage() >= 1 then
          HR.Cast(S.IronskinBrew, ForceOffGCD);
          HR.Cast(S.PurifyingBrew, ForceOffGCD);
          if HR.Cast(S.BlackOxBrew) then return "Black Ox Brew 2"; end
        else
          if S.Brews:Charges() >= 1 then HR.Cast(S.IronskinBrew, ForceOffGCD); end
          if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "Black Ox Brew 3"; end
        end
      end
    end
    -- keg_smash,if=spell_targets>=2
    if S.KegSmash:IsCastableP(15) and Cache.EnemiesCount[8] >= 2 then
      if HR.Cast(S.KegSmash) then return "Keg Smash 1"; end
    end
    -- tiger_palm,if=talent.rushing_jade_wind.enabled&buff.blackout_combo.up&buff.rushing_jade_wind.up
    if S.TigerPalm:IsCastableP("Melee") and S.RushingJadeWind:IsAvailable() and Player:BuffP(S.BlackoutComboBuff) and Player:BuffP(S.RushingJadeWind) then
      if HR.Cast(S.TigerPalm) then return "Tiger Palm 1"; end
    end
    -- tiger_palm,if=(talent.invoke_niuzao_the_black_ox.enabled|talent.special_delivery.enabled)&buff.blackout_combo.up
    if S.TigerPalm:IsCastableP("Melee") and (S.InvokeNiuzaotheBlackOx:IsAvailable() or S.SpecialDelivery:IsAvailable()) and Player:BuffP(S.BlackoutComboBuff) then
      if HR.Cast(S.TigerPalm) then return "Tiger Palm 2"; end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>4
    -- Note : Extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReadyP() and S.ExpelHarm:Count() > 4 and Player:Health() + HealingSphereAmount() < Player:MaxHealth() then
      if HR.Cast(S.ExpelHarm) then return "Expel Harm 1"; end
    end
    -- blackout_strike
    if S.BlackoutKick:IsCastableP("Melee") then
      if HR.Cast(S.BlackoutKick) then return "Blackout Kick"; end
    end
    -- keg_smash
    if S.KegSmash:IsCastableP(15) then
      if HR.Cast(S.KegSmash) then return "Keg Smash 2"; end
    end
    if HR.CDsON() then
      -- concentrated_flame,if=dot.concentrated_flame.remains=0
      if S.ConcentratedFlame:IsCastableP(40) and Target:DebuffDownP(S.ConcentratedFlameBurn) then
        if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "Concentrated Flame"; end
      end
      -- heart_essence,if=!essence.the_crucible_of_flame.major
      if S.HeartEssence ~= nil and not PassiveEssence and S.HeartEssence:IsCastableP() and not Spell:MajorEssenceEnabled(AE.TheCrucibleofFlame) then
        if HR.Cast(S.HeartEssence, nil, Settings.Commons.EssenceDisplayStyle) then return "Heart Essence"; end
      end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>=3
    -- Note : Extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReadyP() and S.ExpelHarm:Count() >= 3 and Player:Health() + HealingSphereAmount() < Player:MaxHealth() then
      if HR.Cast(S.ExpelHarm) then return "Expel Harm 2"; end
    end
    -- rushing_jade_wind,if=buff.rushing_jade_wind.down
    if S.RushingJadeWind:IsCastableP() and Player:BuffDownP(S.RushingJadeWind) then
      if HR.Cast(S.RushingJadeWind) then return "Rushing Jade Wind"; end
    end
    -- breath_of_fire,if=buff.blackout_combo.down&(buff.bloodlust.down|(buff.bloodlust.up&&dot.breath_of_fire_dot.refreshable))
    if S.BreathofFire:IsCastableP(10, true) and (Player:BuffDownP(S.BlackoutComboBuff) and (Player:HasNotHeroism() or (Player:HasHeroism() and true and Target:DebuffRefreshableCP(S.BreathofFireDotDebuff)))) then
      if HR.Cast(S.BreathofFire) then return "Breath of Fire"; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastableP(10) then
      if HR.Cast(S.ChiBurst) then return "Chi Burst 2"; end
    end
    -- chi_wave
    if S.ChiWave:IsCastableP(25) then
      if HR.Cast(S.ChiWave) then return "Chi Wave 2"; end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>=2
    -- Note : Extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReadyP() and S.ExpelHarm:Count() >= 2 and Player:Health() + HealingSphereAmount() < Player:MaxHealth() then
      if HR.Cast(S.ExpelHarm) then return "Expel Harm 3"; end
    end
    -- tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>gcd&(energy+(energy.regen*(cooldown.keg_smash.remains+gcd)))>=65
    if S.TigerPalm:IsCastableP("Melee") and (not S.BlackoutCombo:IsAvailable() and S.KegSmash:CooldownRemainsP() > Player:GCD() and (Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP() + Player:GCD()))) >= 65) then
      if HR.Cast(S.TigerPalm) then return "Tiger Palm 3"; end
    end
    -- arcane_torrent,if=energy<31
    if HR.CDsON() and S.ArcaneTorrent:IsCastableP() and Player:Energy() < 31 then
      if HR.Cast(S.ArcaneTorrent, Settings.Brewmaster.OffGCDasOffGCD.ArcaneTorrent, nil, 8) then return ""; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsCastableP() then
      if HR.Cast(S.RushingJadeWind) then return "Rushing Jade Wind 2"; end
    end
    -- Trick to take in consideration the Recovery Setting (and Melee Range)
    if S.TigerPalm:IsCastable("Melee") then
      if HR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
    end
  end
end

HR.SetAPL(268, APL)

-- Last Update: 2020-05-05

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/chi_burst
-- actions.precombat+=/chi_wave

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/gift_of_the_ox,if=health<health.max*0.65
-- actions+=/dampen_harm,if=incoming_damage_1500ms&buff.fortifying_brew.down
-- actions+=/fortifying_brew,if=incoming_damage_1500ms&(buff.dampen_harm.down|buff.diffuse_magic.down)
-- actions+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<31|target.time_to_die<20
-- actions+=/use_items
-- actions+=/potion
-- actions+=/blood_fury
-- actions+=/berserking
-- actions+=/lights_judgment
-- actions+=/fireblood
-- actions+=/ancestral_call
-- actions+=/bag_of_tricks
-- actions+=/invoke_niuzao_the_black_ox,if=target.time_to_die>25
-- # Ironskin Brew priority whenever it took significant damage and ironskin brew buff is missing (adjust the health.max coefficient according to intensity of damage taken), and to dump excess charges before BoB.
-- actions+=/ironskin_brew,if=buff.blackout_combo.down&incoming_damage_1999ms>(health.max*0.1+stagger.last_tick_damage_4)&buff.elusive_brawler.stack<2&!buff.ironskin_brew.up
-- actions+=/ironskin_brew,if=cooldown.brews.charges_fractional>1&cooldown.black_ox_brew.remains<3&buff.ironskin_brew.remains<15
-- # Purifying behaviour is based on normalization (iE the late expression triggers if stagger size increased over the last 30 ticks or 15 seconds).
-- actions+=/purifying_brew,if=stagger.pct>(6*(3-(cooldown.brews.charges_fractional)))&(stagger.last_tick_damage_1>((0.02+0.001*(3-cooldown.brews.charges_fractional))*stagger.last_tick_damage_30))
-- # Black Ox Brew is currently used to either replenish brews based on less than half a brew charge available, or low energy to enable Keg Smash
-- actions+=/black_ox_brew,if=cooldown.brews.charges_fractional<0.5
-- actions+=/black_ox_brew,if=(energy+(energy.regen*cooldown.keg_smash.remains))<40&buff.blackout_combo.down&cooldown.keg_smash.up
-- # Offensively, the APL prioritizes KS on cleave, BoS else, with energy spenders and cds sorted below
-- actions+=/keg_smash,if=spell_targets>=2
-- actions+=/tiger_palm,if=talent.rushing_jade_wind.enabled&buff.blackout_combo.up&buff.rushing_jade_wind.up
-- actions+=/tiger_palm,if=(talent.invoke_niuzao_the_black_ox.enabled|talent.special_delivery.enabled)&buff.blackout_combo.up
-- actions+=/expel_harm,if=buff.gift_of_the_ox.stack>4
-- actions+=/blackout_strike
-- actions+=/keg_smash
-- actions+=/concentrated_flame,if=dot.concentrated_flame.remains=0
-- actions+=/heart_essence,if=!essence.the_crucible_of_flame.major
-- actions+=/expel_harm,if=buff.gift_of_the_ox.stack>=3
-- actions+=/rushing_jade_wind,if=buff.rushing_jade_wind.down
-- actions+=/breath_of_fire,if=buff.blackout_combo.down&(buff.bloodlust.down|(buff.bloodlust.up&&dot.breath_of_fire_dot.refreshable))
-- actions+=/chi_burst
-- actions+=/chi_wave
-- # Expel Harm has higher DPET than TP when you have at least 2 orbs.
-- actions+=/expel_harm,if=buff.gift_of_the_ox.stack>=2
-- actions+=/tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>gcd&(energy+(energy.regen*(cooldown.keg_smash.remains+gcd)))>=65
-- actions+=/arcane_torrent,if=energy<31
-- actions+=/rushing_jade_wind

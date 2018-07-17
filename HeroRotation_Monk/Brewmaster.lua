--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Monk then Spell.Monk = {} end
Spell.Monk.Brewmaster = {
  ArcaneTorrent                         = Spell(50613),
  Berserking                            = Spell(26297),
  BlackoutCombo                         = Spell(196736),
  BlackoutComboBuff                     = Spell(228563),
  BlackoutStrike                        = Spell(205523),
  BlackOxBrew                           = Spell(115399),
  BloodFury                             = Spell(20572),
  BreathofFire                          = Spell(115181),
  BreathofFireDotDebuff                 = Spell(123725),
  Brews                                 = Spell(115308),
  ChiBurst                              = Spell(123986),
  ChiWave                               = Spell(115098),
  DampenHarm                            = Spell(122278),
  DampenHarmBuff                        = Spell(122278),
  ExplodingKeg                          = Spell(214326),
  FortifyingBrew                        = Spell(115203),
  FortifyingBrewBuff                    = Spell(115203),
  InvokeNiuzaotheBlackOx                = Spell(132578),
  IronskinBrew                          = Spell(115308),
  IronskinBrewBuff                      = Spell(215479),
  KegSmash                              = Spell(121253),
  LightBrewing                          = Spell(196721),
  PotentKick                            = Spell(213047),
  PurifyingBrew                         = Spell(119582),
  RushingJadeWind                       = Spell(116847),
  TigerPalm                             = Spell(100780),
  HeavyStagger                          = Spell(124273),
  ModerateStagger                       = Spell(124274),
  LightStagger                          = Spell(124275),
  -- Misc
  PoolEnergy                            = Spell(9999000010)
};
local S = Spell.Monk.Brewmaster;

-- Items
if not Item.Monk then Item.Monk = {} end
Item.Monk.Brewmaster = {
  ProlongedPower      = Item(142117),
  StormstoutsLastGasp = Item((248044), {3}),
};
local I = Item.Monk.Brewmaster;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local ForceOffGCD = {true, false};

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Monk.Commons,
  Brewmaster = HR.GUISettings.APL.Monk.Brewmaster
};

-- Variables
local BrewmasterToolsEnabled = BrewmasterTools and true or false;
if not BrewmasterToolsEnabled then
  HR.Print("Purifying disabled. You need Brewmaster Tools to enable it.");
end

local function ShouldPurify ()
  if not BrewmasterToolsEnabled or not Settings.Brewmaster.Purify.Enabled then
    return false;
  end
  local NormalizedStagger = BrewmasterTools.GetNormalStagger();
  local NextStaggerTick = BrewmasterTools.GetNextTick();
  local NStaggerPct = NextStaggerTick > 0 and NextStaggerTick/Player:MaxHealth() or 0;
  local ProgressPct = NormalizedStagger > 0 and Player:Stagger()/NormalizedStagger or 0;
  if NStaggerPct > 0.015 and ProgressPct > 0 then
    if NStaggerPct <= 0.03 then -- Yellow (> 80%)
      return Settings.Brewmaster.Purify.Low and ProgressPct > 0.8 or false;
    elseif NStaggerPct <= 0.05 then -- Orange (> 70%)
      return Settings.Brewmaster.Purify.Medium and ProgressPct > 0.7 or false;
    elseif NStaggerPct <= 0.1 then -- Red (> 50%)
      return Settings.Brewmaster.Purify.High and ProgressPct > 0.5 or false;
    else -- Magenta
      return true;
    end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  HL.GetEnemies(8, true);
  Everyone.AoEToggleEnemiesUpdate();

  -- Misc
  local BrewMaxCharge = 3 + (S.LightBrewing:IsAvailable() and 1 or 0);
  local IronskinDuration = (6 + S.PotentKick:ArtifactRank() * 0.5);
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);

  --- Defensives
  -- purifying_brew,if=stagger.heavy|(stagger.moderate&cooldown.brews.charges_fractional>=cooldown.brews.max_charges-0.5&buff.ironskin_brew.remains>=buff.ironskin_brew.duration*2.5)
  if S.PurifyingBrew:IsCastableP() and ShouldPurify() then
    if HR.Cast(S.PurifyingBrew, Settings.Brewmaster.OffGCDasOffGCD.PurifyingBrew) then return ""; end
  end
  -- ironskin_brew,if=buff.blackout_combo.down&cooldown.brews.charges_fractional>=cooldown.brews.max_charges-0.1-(1+buff.ironskin_brew.remains<=buff.ironskin_brew.duration*0.5)&buff.ironskin_brew.remains<=buff.ironskin_brew.duration*2
  -- Note: Extra handling of the charge management only while tanking.
  --       "- (IsTanking and 1 + (Player:BuffRemains(S.IronskinBrewBuff) <= IronskinDuration * 0.5 and 0.5 or 0) or 0)"
  if S.IronskinBrew:IsCastableP() and Player:BuffDownP(S.BlackoutComboBuff)
      and S.Brews:ChargesFractional() >= BrewMaxCharge - 0.1 - (IsTanking and 1 + (Player:BuffRemains(S.IronskinBrewBuff) <= IronskinDuration * 0.5 and 0.5 or 0) or 0)
      and Player:BuffRemains(S.IronskinBrewBuff) <= IronskinDuration * 2 then
    if HR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return ""; end
  end
  -- BlackoutCombo Stagger Pause w/ Ironskin Brew
  if S.IronskinBrew:IsCastableP() and Player:BuffP(S.BlackoutComboBuff) and Player:HealingAbsorbed() and ShouldPurify() then
    if HR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return ""; end
  end
  -- black_ox_brew,if=incoming_damage_1500ms&stagger.heavy&cooldown.brews.charges_fractional<=0.75
  if S.BlackOxBrew:IsCastableP() and S.Brews:ChargesFractional() <= 0.75 and (ShouldPurify() or Player:BuffRemains(S.IronskinBrewBuff) <= IronskinDuration) then
    if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return ""; end
  end

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    -- black_ox_brew,if=(energy+(energy.regen*(cooldown.keg_smash.remains)))<40&buff.blackout_combo.down&cooldown.keg_smash.up
    -- black_ox_brew,if=(energy+(energy.regen*cooldown.keg_smash.remains))<40&buff.blackout_combo.down&cooldown.keg_smash.up
    if S.BlackOxBrew:IsCastableP() and (Player:Energy() + (Player:EnergyRegen() * S.KegSmash:CooldownRemainsP())) < 40 and Player:BuffDownP(S.BlackoutComboBuff) and S.KegSmash:CooldownUpP() then
      if S.Brews:Charges() >= 2 and Player:StaggerPercentage() >= 1 then
        HR.Cast(S.IronskinBrew, ForceOffGCD);
        HR.Cast(S.PurifyingBrew, ForceOffGCD);
        if HR.Cast(S.BlackOxBrew) then return ""; end
      else
        if S.Brews:Charges() >= 1 then HR.Cast(S.IronskinBrew, ForceOffGCD); end
        if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return ""; end
      end
    end
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Brewmaster.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Brewmaster.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- invoke_niuzao_the_black_ox
    if S.InvokeNiuzaotheBlackOx:IsCastableP(40) and HR.CDsON() then
      if HR.Cast(S.InvokeNiuzaotheBlackOx, Settings.Brewmaster.OffGCDasOffGCD.InvokeNiuzaotheBlackOx) then return ""; end
    end
    -- arcane_torrent,if=energy<31
    if HR.CDsON() and S.ArcaneTorrent:IsCastableP() and Player:Energy() < 31 then
      if HR.Cast(S.ArcaneTorrent, Settings.Brewmaster.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- keg_smash,if=spell_targets>=3
    if S.KegSmash:IsCastableP(25) and Cache.EnemiesCount[8] >= 3 then
      if HR.Cast(S.KegSmash) then return ""; end
    end
    -- tiger_palm,if=buff.blackout_combo.up
    if S.TigerPalm:IsCastableP("Melee") and Player:BuffP(S.BlackoutComboBuff) then
      if HR.Cast(S.TigerPalm) then return ""; end
    end
    -- keg_smash
    if S.KegSmash:IsCastableP(25) then
      if HR.Cast(S.KegSmash) then return ""; end
    end
    -- blackout_strike
    if S.BlackoutStrike:IsCastableP("Melee") then
      if HR.Cast(S.BlackoutStrike) then return ""; end
    end
    -- breath_of_fire,if=buff.blackout_combo.down&(buff.bloodlust.down|(buff.bloodlust.up&&dot.breath_of_fire_dot.refreshable))
    if S.BreathofFire:IsCastableP(10, true) and (Player:BuffDownP(S.BlackoutComboBuff) and (Player:HasNotHeroism() or (Player:HasHeroism() and true and Target:DebuffRefreshableCP(S.BreathofFireDotDebuff)))) then
      if HR.Cast(S.BreathofFire) then return ""; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsCastableP() then
      if HR.Cast(S.RushingJadeWind) then return ""; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastableP(10) then
      if HR.Cast(S.ChiBurst) then return ""; end
    end
    -- chi_wave
    if S.ChiWave:IsCastableP(25) then
      if HR.Cast(S.ChiWave) then return ""; end
    end
    -- tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>gcd&(energy+(energy.regen*(cooldown.keg_smash.remains+gcd)))>=55
    if S.TigerPalm:IsCastableP("Melee") and (not S.BlackoutCombo:IsAvailable() and S.KegSmash:CooldownRemainsP() > Player:GCD() and (Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP() + Player:GCD()))) >= 55) then
      if HR.Cast(S.TigerPalm) then return ""; end
    end
    -- rjw > ks if SLG
    if S.RushingJadeWind:IsCastableP() and I.StormstoutsLastGasp:IsEquipped() and S.RushingJadeWind:CooldownRemainsP() + 0.5 <= S.KegSmash:CooldownRemainsP() then
      if HR.Cast(S.RushingJadeWind) then return ""; end
    end
    -- Keg Smash coming back during the next GCD
    if Target:IsInRange(25) and S.KegSmash:CooldownRemainsP() < Player:GCD() then
      if HR.Cast(S.KegSmash) then return ""; end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.TigerPalm:IsCastable("Melee") then
      if HR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
    end
  end
end

HR.SetAPL(268, APL)

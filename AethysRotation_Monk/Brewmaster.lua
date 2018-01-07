--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- AethysCore
local AC     = AethysCore
local Cache  = AethysCache
local Unit   = AC.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = AC.Spell
local Item   = AC.Item
-- AethysRotation
local AR     = AethysRotation

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
  DiffuseMagicBuff                      = Spell(122783),
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
  -- UseItem                               = Spell()
};
local S = Spell.Monk.Brewmaster;

-- Items
if not Item.Monk then Item.Monk = {} end
Item.Monk.Brewmaster = {
  ProlongedPower                   = Item(142117)
};
local I = Item.Monk.Brewmaster;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = AR.Commons.Everyone;
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Monk.Commons,
  Brewmaster = AR.GUISettings.APL.Monk.Brewmaster
};

-- Variables

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function HealingDebuffed ()
  return false;
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  AC.GetEnemies(8, true);

  -- Defensives
  -- Purifying Brew
  if S.PurifyingBrew:IsCastableP() and Player:StaggerPercentage() >= Settings.Brewmaster.PurifyThreshold then
    if AR.Cast(S.PurifyingBrew, Settings.Brewmaster.OffGCDasOffGCD.PurifyingBrew) then return ""; end
  end
  -- ironskin_brew,if=buff.blackout_combo.down&cooldown.brews.charges_fractional>=1.9+talent.light_brewing.enabled&buff.ironskin_brew.remains<=buff.ironskin_brew.duration*3
  if S.IronskinBrew:IsCastableP() and Player:BuffDownP(S.BlackoutComboBuff)
      and S.Brews:ChargesFractionalP() >= 2.9 + (S.LightBrewing:IsAvailable() and 1 or 0) - (IsTanking and 1 or 0)
      and Player:BuffRemainsP(S.IronskinBrewBuff) <= (6 + S.PotentKick:ArtifactRank() * 0.5) * 3 then
    if AR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return ""; end
  end
  -- BlackoutCombo Stagger Pause w/ Ironskin Brew
  if S.IronskinBrew:IsCastableP() and Player:BuffP(S.BlackoutComboBuff) and Player:HealingAbsorbed() and Player:StaggerPercentage() >= 25 then
    if AR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return ""; end
  end
  -- black_ox_brew,if=incoming_damage_1500ms&stagger.moderate&cooldown.brews.charges_fractional<=0.8
  if S.BlackOxBrew:IsCastableP() and Player:StaggerPercentage() >= 40 and S.Brews:ChargesFractional() <= 0.8) then
    if AR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return ""; end
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);
    -- black_ox_brew,if=(energy+(energy.regen*(cooldown.keg_smash.remains)))<40&buff.blackout_combo.down&cooldown.keg_smash.up
    if S.BlackOxBrew:IsCastableP() and ((Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP()))) < 40 and Player:BuffDownP(S.BlackoutComboBuff) and S.KegSmash:CooldownUpP()) then
      if S.Brews:Charges() >= 2 and Player:StaggerPercentage() >= 1 then
        AR.Cast(S.IronskinBrew, true);
        AR.Cast(S.PurifyingBrew, true);
        if AR.Cast(S.BlackOxBrew, false) then return ""; end
      else
        if S.Brews:Charges() >= 1 then AR.Cast(S.IronskinBrew, true); end
        if AR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return ""; end
      end
    end
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and AR.CDsON() then
      if AR.Cast(S.BloodFury, Settings.Brewmaster.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and AR.CDsON() then
      if AR.Cast(S.Berserking, Settings.Brewmaster.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- invoke_niuzao_the_black_ox,if=target.time_to_die>45
    if S.InvokeNiuzaotheBlackOx:IsCastableP() and AR.CDsON() and (Target:TimeToDie() > 45) then
      if AR.Cast(S.InvokeNiuzaotheBlackOx, Settings.Brewmaster.OffGCDasOffGCD.InvokeNiuzaotheBlackOx) then return ""; end
    end
    -- arcane_torrent,if=energy<31
    if AR.CDsON() and S.ArcaneTorrent:IsCastableP() and Player:Energy() < 31 then
      if AR.Cast(S.ArcaneTorrent, Settings.Brewmaster.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- tiger_palm,if=buff.blackout_combo.up
    if S.TigerPalm:IsCastableP() and Player:BuffP(S.BlackoutComboBuff) then
      if AR.Cast(S.TigerPalm) then return ""; end
    end
    -- blackout_strike,if=cooldown.keg_smash.remains>0
    if S.BlackoutStrike:IsCastableP() and S.KegSmash:CooldownRemainsP() > 0 then
      if AR.Cast(S.BlackoutStrike) then return ""; end
    end
    -- keg_smash
    if S.KegSmash:IsCastableP() then
      if AR.Cast(S.KegSmash) then return ""; end
    end
    -- breath_of_fire,if=(buff.bloodlust.down&buff.blackout_combo.down)|(buff.bloodlust.up&buff.blackout_combo.down&dot.breath_of_fire_dot.remains<=0)
    if S.BreathofFire:IsCastableP() and (Player:HasNotHeroism() and Player:BuffDownP(S.BlackoutComboBuff) or (Player:HasHeroism() and Player:BuffDownP(S.BlackoutComboBuff) and Target:DebuffRemainsP(S.BreathofFireDotDebuff) <= 0)) then
      if AR.Cast(S.BreathofFire) then return ""; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsCastableP() then
      if AR.Cast(S.RushingJadeWind) then return ""; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastableP() then
      if AR.Cast(S.ChiBurst) then return ""; end
    end
    -- chi_wave
    if S.ChiWave:IsCastableP() then
      if AR.Cast(S.ChiWave) then return ""; end
    end
    -- tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>=gcd&(energy+(energy.regen*(cooldown.keg_smash.remains)))>=55
    if S.TigerPalm:IsCastableP() and (not S.BlackoutCombo:IsAvailable() and S.KegSmash:CooldownRemainsP() >= Player:GCD() and (Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP()))) >= 55) then
      if AR.Cast(S.TigerPalm) then return ""; end
    end
  end
end

AR.SetAPL(268, APL)

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
  DampenHarm                            = Spell(122278),
  ChiBurst                              = Spell(123986),
  ChiWave                               = Spell(115098),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ExplodingKeg                          = Spell(214326),
  InvokeNiuzaotheBlackOx                = Spell(132578),
  IronskinBrew                          = Spell(115308),
  IronskinBrewBuff                      = Spell(215479),
  BlackoutComboBuff                     = Spell(228563),
  Brews                                 = Spell(115308),
  BlackOxBrew                           = Spell(115399),
  KegSmash                              = Spell(121253),
  ArcaneTorrent                         = Spell(50613),
  TigerPalm                             = Spell(100780),
  BlackoutStrike                        = Spell(205523),
  BreathofFire                          = Spell(115181),
  BreathofFireDotDebuff                 = Spell(123725),
  RushingJadeWind                       = Spell(116847),
  BlackoutCombo                         = Spell(196736),
  FortifyingBrewBuff                    = Spell(115203),
  FortifyingBrew                        = Spell(115203),
  DampenHarmBuff                        = Spell(122278),
  DiffuseMagicBuff                      = Spell(122783),
  LightBrewing                          = Spell(196721),
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

--- ======= ACTION LISTS =======
local function APL()
  AC.GetEnemies(8, true);
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);
  local function Precombat()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- -- dampen_harm
    -- if S.DampenHarm:IsCastableP() and (true) then
    --   if AR.Cast(S.DampenHarm) then return ""; end
    -- end
    -- -- chi_burst
    -- if S.ChiBurst:IsCastableP() and (true) then
    --   if AR.Cast(S.ChiBurst) then return ""; end
    -- end
    -- -- chi_wave
    -- if S.ChiWave:IsCastableP() and (true) then
    --   if AR.Cast(S.ChiWave) then return ""; end
    -- end
  end
  local function St()
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and AR.CDsON() and (true) then
      if AR.Cast(S.BloodFury, Settings.Brewmaster.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and AR.CDsON() and (true) then
      if AR.Cast(S.Berserking, Settings.Brewmaster.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- -- exploding_keg
    -- if S.ExplodingKeg:IsCastableP() and (true) then
    --   if AR.Cast(S.ExplodingKeg) then return ""; end
    -- end
    -- invoke_niuzao_the_black_ox,if=target.time_to_die>45
    if S.InvokeNiuzaotheBlackOx:IsCastableP() and AR.CDsON() and (Target:TimeToDie() > 45) then
      if AR.Cast(S.InvokeNiuzaotheBlackOx, Settings.Brewmaster.OffGCDasOffGCD.InvokeNiuzaotheBlackOx) then return ""; end
    end
    -- ironskin_brew,if=buff.blackout_combo.down&cooldown.brews.charges>=1
    if S.IronskinBrew:IsCastableP() and (Player:BuffDownP(S.BlackoutComboBuff) and S.Brews:ChargesFractionalP() >= 2.9 + (S.LightBrewing:IsAvailable() and 1 or 0) - (IsTanking and 1 or 0)) then
      if AR.Cast(S.IronskinBrew, Settings.Brewmaster.OffGCDasOffGCD.IronskinBrew) then return ""; end
    end
    -- black_ox_brew,if=(energy+(energy.regen*(cooldown.keg_smash.remains)))<40&buff.blackout_combo.down&cooldown.keg_smash.up
    if S.BlackOxBrew:IsCastableP() and ((Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP()))) < 40 and Player:BuffDownP(S.BlackoutComboBuff) and S.KegSmash:CooldownUpP()) then
      if AR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return ""; end
    end
    -- arcane_torrent,if=energy<31
    if S.ArcaneTorrent:IsCastableP() and AR.CDsON() and (Player:Energy() < 31) then
      if AR.Cast(S.ArcaneTorrent, Settings.Brewmaster.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- tiger_palm,if=buff.blackout_combo.up
    if S.TigerPalm:IsCastableP() and (Player:BuffP(S.BlackoutComboBuff)) then
      if AR.Cast(S.TigerPalm) then return ""; end
    end
    -- blackout_strike,if=cooldown.keg_smash.remains>0
    if S.BlackoutStrike:IsCastableP() and (S.KegSmash:CooldownRemainsP() > 0) then
      if AR.Cast(S.BlackoutStrike) then return ""; end
    end
    -- keg_smash
    if S.KegSmash:IsCastableP() and S.KegSmash:IsUsable() and (true) then
      if AR.Cast(S.KegSmash) then return ""; end
    end
    -- breath_of_fire,if=buff.bloodlust.down&buff.blackout_combo.down|(buff.bloodlust.up&buff.blackout_combo.down&dot.breath_of_fire_dot.remains<=0)
    if S.BreathofFire:IsCastableP() and (Player:HasNotHeroism() and Player:BuffDownP(S.BlackoutComboBuff) or (Player:HasHeroism() and Player:BuffDownP(S.BlackoutComboBuff) and Target:DebuffRemainsP(S.BreathofFireDotDebuff) <= 0)) then
      if AR.Cast(S.BreathofFire) then return ""; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsCastableP() and (true) then
      if AR.Cast(S.RushingJadeWind) then return ""; end
    end
    -- tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>=gcd&(energy+(energy.regen*(cooldown.keg_smash.remains)))>=55
    if S.TigerPalm:IsCastableP() and (not S.BlackoutCombo:IsAvailable() and S.KegSmash:CooldownRemainsP() >= Player:GCD() and (Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemainsP()))) >= 55) then
      if AR.Cast(S.TigerPalm) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- auto_attack
  -- greater_gift_of_the_ox
  -- gift_of_the_ox
  -- -- dampen_harm,if=incoming_damage_1500ms&buff.fortifying_brew.down
  -- if S.DampenHarm:IsCastableP() and (bool(incoming_damage_1500ms) and Player:BuffDownP(S.FortifyingBrewBuff)) then
  --   if AR.Cast(S.DampenHarm) then return ""; end
  -- end
  -- -- fortifying_brew,if=incoming_damage_1500ms&(buff.dampen_harm.down|buff.diffuse_magic.down)
  -- if S.FortifyingBrew:IsCastableP() and (bool(incoming_damage_1500ms) and (Player:BuffDownP(S.DampenHarmBuff) or Player:BuffDownP(S.DiffuseMagicBuff))) then
  --   if AR.Cast(S.FortifyingBrew) then return ""; end
  -- end
  -- -- use_item,name=archimondes_hatred_reborn
  -- if S.UseItem:IsCastableP() and (true) then
  --   if AR.Cast(S.UseItem) then return ""; end
  -- end
  -- call_action_list,name=st
  if (true) then
    local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
  end
end

AR.SetAPL(268, APL)

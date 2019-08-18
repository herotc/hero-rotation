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
if not Spell.DeathKnight then Spell.DeathKnight = {} end
Spell.DeathKnight.Frost = {
  RemorselessWinter                     = Spell(196770),
  GatheringStorm                        = Spell(194912),
  GlacialAdvance                        = Spell(194913),
  Frostscythe                           = Spell(207230),
  FrostStrike                           = Spell(49143),
  HowlingBlast                          = Spell(49184),
  RimeBuff                              = Spell(59052),
  KillingMachineBuff                    = Spell(51124),
  RunicAttenuation                      = Spell(207104),
  Obliterate                            = Spell(49020),
  HornofWinter                          = Spell(57330),
  ArcaneTorrent                         = Spell(50613),
  PillarofFrost                         = Spell(51271),
  ChainsofIce                           = Spell(45524),
  ColdHeartBuff                         = Spell(281209),
  PillarofFrostBuff                     = Spell(51271),
  FrostwyrmsFury                        = Spell(279302),
  EmpowerRuneWeaponBuff                 = Spell(47568),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  EmpowerRuneWeapon                     = Spell(47568),
  BreathofSindragosa                    = Spell(152279),
  ColdHeart                             = Spell(281208),
  RazoriceDebuff                        = Spell(51714),
  FrozenPulseBuff                       = Spell(194909),
  FrozenPulse                           = Spell(194909),
  FrostFeverDebuff                      = Spell(55095),
  IcyTalonsBuff                         = Spell(194879),
  Obliteration                          = Spell(281238),
  DeathStrike                           = Spell(49998),
  DeathStrikeBuff                       = Spell(101568),
  FrozenTempest                         = Spell(278487),
  UnholyStrengthBuff                    = Spell(53365),
  IcyCitadel                            = Spell(272718),
  IcyCitadelBuff                        = Spell(272719),
  MindFreeze                            = Spell(47528),
  RazorCoralDebuff                      = Spell(303568),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForceCounter                  = MultiSpell(298409, 302917),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  ChillStreak                           = Spell(305392),
  PoolRange                             = Spell(9999000010)
};
local S = Spell.DeathKnight.Frost;

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Frost = {
  PotionofUnbridledFury            = Item(169299),
  RazdunksBigRedButton             = Item(159611),
  MerekthasFang                    = Item(158367),
  KnotofAncientFuryAlliance        = Item(161413),
  KnotofAncientFuryHorde           = Item(166795),
  FirstMatesSpyglass               = Item(158163),
  GrongsPrimalRage                 = Item(165574),
  AzsharasFontofPower              = Item(169314),
  LurkersInsidiousGift             = Item(167866),
  PocketsizedComputationDevice     = Item(167555),
  AshvanesRazorCoral               = Item(169311),
  -- "Other On Use"
  NotoriousGladiatorsBadge         = Item(167380),
  NotoriousGladiatorsMedallion     = Item(167377),
  SinisterGladiatorsBadge          = Item(165058),
  SinisterGladiatorsMedallion      = Item(165055),
  VialofAnimatedBlood              = Item(159625),
  JesHowler                        = Item(159627)
};
local I = Item.DeathKnight.Frost;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Frost = HR.GUISettings.APL.DeathKnight.Frost
};

-- Functions
local EnemyRanges = {10, 8}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i, true);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function DeathStrikeHeal()
  return (Settings.General.SoloMode and Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP) and true or false;
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, VarOoUE, Aoe, BosPooling, BosTicking, ColdHeart, Cooldowns, Essences, Obliteration, Standard
  local no_heal = not DeathStrikeHeal()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.Cast(I.PotionofUnbridledFury, Settings.Commons.OffGCDasOffGCD.Potions) then return ""; end
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipReady() then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
    end
    -- variable,name=other_on_use_equipped,value=(equipped.notorious_gladiators_badge|equipped.sinister_gladiators_badge|equipped.sinister_gladiators_medallion|equipped.vial_of_animated_blood|equipped.first_mates_spyglass|equipped.jes_howler|equipped.notorious_gladiators_medallion|equipped.ashvanes_razor_coral)
    if (true) then
      VarOoUE = (I.NotoriousGladiatorsBadge:IsEquipped() or I.SinisterGladiatorsBadge:IsEquipped() or I.SinisterGladiatorsMedallion:IsEquipped() or I.VialofAnimatedBlood:IsEquipped() or I.FirstMatesSpyglass:IsEquipped() or I.JesHowler:IsEquipped() or I.NotoriousGladiatorsMedallion:IsEquipped() or I.AshvanesRazorCoral:IsEquipped())
    end
    -- opener
    if Everyone.TargetIsValid() then
      if S.BreathofSindragosa:IsAvailable() and S.Obliterate:IsCastableP("Melee") then
        if HR.Cast(S.Obliterate) then return ""; end
      end
      if S.HowlingBlast:IsCastableP(30, true) and (not Target:DebuffP(S.FrostFeverDebuff)) then
        if HR.Cast(S.HowlingBlast) then return ""; end
      end
    end
  end
  Aoe = function()
    -- remorseless_winter,if=talent.gathering_storm.enabled|(azerite.frozen_tempest.rank&spell_targets.remorseless_winter>=3&!buff.rime.up)
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable() or (bool(S.FrozenTempest:AzeriteRank()) and Cache.EnemiesCount[8] >= 3 and not Player:BuffP(S.RimeBuff))) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- glacial_advance,if=talent.frostscythe.enabled
    if no_heal and S.GlacialAdvance:IsReadyP() and (S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled&!talent.frostscythe.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and S.RemorselessWinter:CooldownRemainsP() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable() and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (S.RemorselessWinter:CooldownRemainsP() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:BuffP(S.RimeBuff)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up
    if S.Frostscythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and (Player:BuffP(S.KillingMachineBuff)) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- glacial_advance,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if no_heal and S.GlacialAdvance:IsReadyP() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit<(15+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frostscythe
    if S.Frostscythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>(25+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance
    if no_heal and S.GlacialAdvance:IsReadyP() then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!talent.frostscythe.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frost_strike
    if no_heal and S.FrostStrike:IsReadyP("Melee") then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- horn_of_winter
    if S.HornofWinter:IsCastableP() then
      if HR.Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornofWinter) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
  end
  BosPooling = function()
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:BuffP(S.RimeBuff)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>=25&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() >= 25 and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>=25
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() >= 25) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=runic_power.deficit<20&spell_targets.glacial_advance>=2&cooldown.pillar_of_frost.remains>5
    if no_heal and S.GlacialAdvance:IsReadyP() and (Player:RunicPowerDeficit() < 20 and Cache.EnemiesCount[10] >= 2 and S.PillarofFrost:CooldownRemainsP() > 5) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit<20&!talent.frostscythe.enabled&cooldown.pillar_of_frost.remains>5
    if no_heal and S.FrostStrike:IsReadyP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() < 20 and not S.Frostscythe:IsAvailable() and S.PillarofFrost:CooldownRemainsP() > 5) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>5
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (Player:RunicPowerDeficit() < 20 and S.PillarofFrost:CooldownRemainsP() > 5) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&runic_power.deficit>(15+talent.runic_attenuation.enabled*3)&spell_targets.frostscythe>=2
    if S.Frostscythe:IsCastableP() and (Player:BuffP(S.KillingMachineBuff) and Player:RunicPowerDeficit() > (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- frostscythe,if=runic_power.deficit>=(35+talent.runic_attenuation.enabled*3)&spell_targets.frostscythe>=2
    if S.Frostscythe:IsCastableP() and (Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3) and Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>=(35+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>=(35+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
    if no_heal and S.GlacialAdvance:IsReadyP() and (S.PillarofFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and Cache.EnemiesCount[10] >= 2) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&!talent.frostscythe.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and S.PillarofFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frost_strike,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (S.PillarofFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- wait for resources
    if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Pooling"; end
  end
  BosTicking = function()
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power<=30&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPower() <= 30 and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=runic_power<=30
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPower() <= 32) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:BuffP(S.RimeBuff)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&rune.time_to_5<gcd|runic_power<=45&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RuneTimeToX(5) < Player:GCD() or Player:RunicPower() <= 45 and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=rune.time_to_5<gcd|runic_power<=45
    if S.Obliterate:IsCastableP("Melee") and (Player:RuneTimeToX(5) < Player:GCD() or Player:RunicPower() <= 45) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&spell_targets.frostscythe>=2
    if S.Frostscythe:IsCastableP() and (Player:BuffP(S.KillingMachineBuff) and Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- horn_of_winter,if=runic_power.deficit>=32&rune.time_to_3>gcd
    if S.HornofWinter:IsCastableP() and (Player:RunicPowerDeficit() >= 30 and Player:RuneTimeToX(3) > Player:GCD()) then
      if HR.Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornofWinter) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frostscythe,if=spell_targets.frostscythe>=2
    if S.Frostscythe:IsCastableP() and (Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>25|rune>3&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() > 25 or Player:Rune() > 3 and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>25|rune>3
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() > 25 or Player:Rune() > 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- arcane_torrent,if=runic_power.deficit>20
    if S.ArcaneTorrent:IsCastableP() and (Player:RunicPowerDeficit() > 20) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- wait for resources
    if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Ticking"; end
  end
  ColdHeart = function()
    -- chains_of_ice,if=buff.cold_heart.stack>5&target.time_to_die<gcd
    if S.ChainsofIce:IsCastableP() and (Player:BuffStackP(S.ColdHeartBuff) > 5 and Target:TimeToDie() < Player:GCD()) then
      if HR.Cast(S.ChainsofIce) then return ""; end
    end
    -- chains_of_ice,if=(buff.pillar_of_frost.remains<=gcd*(1+cooldown.frostwyrms_fury.ready)|buff.pillar_of_frost.remains<rune.time_to_3)&buff.pillar_of_frost.up&azerite.icy_citadel.rank<=2
    if S.ChainsofIce:IsCastableP() and ((Player:BuffRemainsP(S.PillarofFrostBuff) <= Player:GCD() * (1 + num(S.FrostwyrmsFury:CooldownUpP())) or Player:BuffRemainsP(S.PillarofFrostBuff) < Player:RuneTimeToX(3)) and Player:BuffP(S.PillarofFrostBuff) and S.IcyCitadel:AzeriteRank() <= 2) then
      if HR.Cast(S.ChainsofIce) then return ""; end
    end
    -- chains_of_ice,if=buff.pillar_of_frost.remains<8&buff.unholy_strength.remains<gcd*(1+cooldown.frostwyrms_fury.ready)&buff.unholy_strength.remains&buff.pillar_of_frost.up&azerite.icy_citadel.rank<=2
    if S.ChainsofIce:IsCastableP() and (Player:BuffRemainsP(S.PillarofFrostBuff) < 8 and Player:BuffRemainsP(S.UnholyStrengthBuff) < Player:GCD() * (1 + num(S.FrostwyrmsFury:CooldownUpP())) and Player:BuffP(S.UnholyStrengthBuff) and Player:BuffP(S.PillarofFrostBuff) and S.IcyCitadel:AzeriteRank() <= 2) then
      if HR.Cast(S.ChainsofIce) then return ""; end
    end
    -- chains_of_ice,if=(buff.icy_citadel.remains<=gcd*(1+cooldown.frostwyrms_fury.ready)|buff.icy_citadel.remains<rune.time_to_3)&buff.icy_citadel.up&azerite.icy_citadel.enabled&azerite.icy_citadel.rank>2
    if S.ChainsofIce:IsCastableP() and ((Player:BuffRemainsP(S.IcyCitadelBuff) <= Player:GCD() * (1 + num(S.FrostwyrmsFury:CooldownUpP())) or Player:BuffRemainsP(S.IcyCitadelBuff) < Player:RuneTimeToX(3)) and Player:BuffP(S.IcyCitadelBuff) and S.IcyCitadel:AzeriteEnabled() and S.IcyCitadel:AzeriteRank() > 2) then
      if HR.Cast(S.ChainsofIce) then return ""; end
    end
    -- chains_of_ice,if=buff.icy_citadel.remains<8&buff.unholy_strength.remains<gcd*(1+cooldown.frostwyrms_fury.ready)&buff.unholy_strength.remains&buff.icy_citadel.up&!azerite.icy_citadel.enabled&azerite.icy_citadel.rank>2
    -- This will always return false based on the last two checks, ignoring the "not enabled" check as that wasn't in the other updates on 1/12
    if S.ChainsofIce:IsCastableP() and (Player:BuffRemainsP(S.IcyCitadelBuff) < 8 and Player:BuffRemainsP(S.UnholyStrengthBuff) < Player:GCD() * (1 + num(S.FrostwyrmsFury:CooldownUpP())) and Player:BuffP(S.UnholyStrengthBuff) and Player:BuffP(S.IcyCitadelBuff) and S.IcyCitadel:AzeriteRank() > 2) then
      if HR.Cast(S.ChainsofIce) then return ""; end
    end
  end
  Cooldowns = function()
    if (Settings.Commons.UseTrinkets) then
      -- use_item,name=azsharas_font_of_power,if=(cooldown.empowered_rune_weapon.ready&!variable.other_on_use_equipped)|(cooldown.pillar_of_frost.remains<=10&variable.other_on_use_equipped)
      if I.AzsharasFontofPower:IsEquipReady() and ((S.EmpowerRuneWeapon:CooldownUpP() and not bool(VarOoUE)) or (S.PillarofFrost:CooldownRemainsP() <= 10 and bool(VarOoUE))) then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
      end
      -- use_item,name=lurkers_insidious_gift,if=talent.breath_of_sindragosa.enabled&((cooldown.pillar_of_frost.remains<=10&variable.other_on_use_equipped)|(buff.pillar_of_frost.up&!variable.other_on_use_equipped))|(buff.pillar_of_frost.up&!talent.breath_of_sindragosa.enabled)
      if I.LurkersInsidiousGift:IsEquipReady() and (S.BreathofSindragosa:IsAvailable() and ((S.PillarofFrost:CooldownRemainsP() <= 10 and bool(VarOoUE)) or (Player:BuffP(S.PillarofFrostBuff) and not bool(VarOoUE))) or (Player:BuffP(S.PillarofFrostBuff) and not S.BreathofSindragosa:IsAvailable())) then
        if HR.Cast(I.LurkersInsidiousGift, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
      end
      -- use_item,name=cyclotronic_blast,if=!buff.pillar_of_frost.up
      if Everyone.CyclotronicBlastReady() and (Player:BuffDownP(S.PillarofFrostBuff)) then
        if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
      end
      -- use_items,if=(cooldown.pillar_of_frost.ready|cooldown.pillar_of_frost.remains>20)&(!talent.breath_of_sindragosa.enabled|cooldown.empower_rune_weapon.remains>95)
      if (S.PillarofFrost:CooldownUpP() or S.PillarofFrost:CooldownRemainsP() > 20) and (not S.BreathofSindragosa:IsAvailable() or S.EmpowerRuneWeaponBuff:CooldownRemainsP() > 95) then
        -- use_item,name=ashvanes_razor_coral,if=cooldown.empower_rune_weapon.remains>90&debuff.razor_coral_debuff.up&variable.other_on_use_equipped|buff.breath_of_sindragosa.up&debuff.razor_coral_debuff.up&!variable.other_on_use_equipped|buff.empower_rune_weapon.up&debuff.razor_coral_debuff.up&!talent.breath_of_sindragosa.enabled|target.1.time_to_die<21
        if I.AshvanesRazorCoral:IsEquipReady() and (S.EmpowerRuneWeapon:CooldownRemainsP() > 90 and Target:DebuffP(S.RazorCoralDebuff) and bool(VarOoUE) or Player:BuffP(S.BreathofSindragosa) and Target:DebuffP(S.RazorCoralDebuff) and not bool(VarOoUE) or Player:BuffP(S.EmpowerRuneWeaponBuff) and Target:DebuffP(S.RazorCoralDebuff) and not S.BreathofSindragosa:IsAvailable() or Target:TimeToDie() < 21) then
          if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        -- use_item,name=jes_howler,if=(equipped.lurkers_insidious_gift&buff.pillar_of_frost.remains)|(!equipped.lurkers_insidious_gift&buff.pillar_of_frost.remains<12&buff.pillar_of_frost.up)
        if I.JesHowler:IsEquipReady() and ((I.LurkersInsidiousGift:IsEquipped() and Player:BuffP(S.PillarofFrostBuff)) or (not I.LurkersInsidiousGift:IsEquipped() and Player:BuffRemainsP(S.PillarofFrostBuff) < 12 and Player:BuffP(S.PillarofFrostBuff))) then
          if HR.Cast(I.JesHowler, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        -- use_item,name=knot_of_ancient_fury,if=cooldown.empower_rune_weapon.remains>40
        -- Two lines, since Horde and Alliance versions of the trinket have different IDs
        if I.KnotofAncientFuryAlliance:IsEquipReady() and (S.EmpowerRuneWeapon:CooldownRemainsP() > 40) then
          if HR.Cast(I.KnotofAncientFuryAlliance, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        if I.KnotofAncientFuryHorde:IsEquipReady() and (S.EmpowerRuneWeapon:CooldownRemainsP() > 40) then
          if HR.Cast(I.KnotofAncientFuryHorde, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        -- use_item,name=grongs_primal_rage,if=rune<=3&!buff.pillar_of_frost.up&(!buff.breath_of_sindragosa.up|!talent.breath_of_sindragosa.enabled)
        if I.GrongsPrimalRage:IsEquipReady() and (Player:Rune() <= 3 and Player:BuffDownP(S.PillarofFrostBuff) and (Player:BuffDownP(S.BreathofSindragosa) or not S.BreathofSindragosa:IsAvailable())) then
          if HR.Cast(I.GrongsPrimalRage, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        -- use_item,name=razdunks_big_red_button
        if I.RazdunksBigRedButton:IsEquipReady() then
          if HR.Cast(I.RazdunksBigRedButton, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        -- use_item,name=merekthas_fang,if=!dot.breath_of_sindragosa.ticking&!buff.pillar_of_frost.up
        if I.MerekthasFang:IsEquipReady() and (not Player:BuffP(S.BreathofSindragosa) and not Player:BuffP(S.PillarofFrostBuff)) then
          if HR.Cast(I.MerekthasFang, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
        -- use_item,name=first_mates_spyglass,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
        if I.FirstMatesSpyglass:IsEquipReady() and (Player:BuffP(S.PillarofFrostBuff) and Player:BuffP(S.EmpowerRuneWeaponBuff)) then
          if HR.Cast(I.FirstMatesSpyglass, nil, Settings.Commons.TrinketDisplayStyle) then return ""; end
        end
      end
    end
    -- potion,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.PillarofFrostBuff) and Player:BuffP(S.EmpowerRuneWeaponBuff)) then
      if HR.Cast(I.PotionofUnbridledFury, Settings.Commons.OffGCDasOffGCD.Potions) then return ""; end
    end
    -- blood_fury,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
    if S.BloodFury:IsCastableP() and (Player:BuffP(S.PillarofFrostBuff) and Player:BuffP(S.EmpowerRuneWeaponBuff)) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- berserking,if=buff.pillar_of_frost.up
    if S.Berserking:IsCastableP() and (Player:BuffP(S.PillarofFrostBuff)) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- pillar_of_frost,if=cooldown.empower_rune_weapon.remains
    if S.PillarofFrost:IsCastableP() and (bool(S.EmpowerRuneWeapon:CooldownRemainsP())) then
      if HR.Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarofFrost) then return ""; end
    end
    -- breath_of_sindragosa,if=cooldown.empower_rune_weapon.remains&cooldown.pillar_of_frost.remains
    if S.BreathofSindragosa:IsCastableP() and (bool(S.EmpowerRuneWeapon:CooldownRemainsP()) and bool(S.PillarofFrost:CooldownRemainsP())) then
      if HR.Cast(S.BreathofSindragosa, Settings.Frost.GCDasOffGCD.BreathofSindragosa) then return ""; end
    end
    -- empower_rune_weapon,if=cooldown.pillar_of_frost.ready&!talent.breath_of_sindragosa.enabled&rune.time_to_5>gcd&runic_power.deficit>=10|target.1.time_to_die<20
    if S.EmpowerRuneWeapon:IsCastableP() and (S.PillarofFrost:CooldownUpP() and not S.BreathofSindragosa:IsAvailable() and Player:RuneTimeToX(5) > Player:GCD() and Player:RunicPowerDeficit() >= 10 or Target:TimeToDie() < 20) then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end
    -- empower_rune_weapon,if=(cooldown.pillar_of_frost.ready|target.time_to_die<20)&talent.breath_of_sindragosa.enabled&runic_power>60
    if S.EmpowerRuneWeapon:IsCastableP() and ((S.PillarofFrost:CooldownUpP() or Target:TimeToDie() < 20) and S.BreathofSindragosa:IsAvailable() and Player:RunicPower() > 60) then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end
    -- call_action_list,name=cold_heart,if=talent.cold_heart.enabled&((buff.cold_heart.stack>=10&debuff.razorice.stack=5)|target.time_to_die<=gcd)
    if (S.ColdHeart:IsAvailable() and ((Player:BuffStackP(S.ColdHeartBuff) >= 10 and Target:DebuffStackP(S.RazoriceDebuff) == 5) or Target:TimeToDie() <= Player:GCD())) then
      local ShouldReturn = ColdHeart(); if ShouldReturn then return ShouldReturn; end
    end
    -- frostwyrms_fury,if=(buff.pillar_of_frost.remains<=gcd|(buff.pillar_of_frost.remains<8&buff.unholy_strength.remains<=gcd&buff.unholy_strength.up))&buff.pillar_of_frost.up&azerite.icy_citadel.rank<=2
    if S.FrostwyrmsFury:IsCastableP() and ((Player:BuffRemainsP(S.PillarofFrostBuff) <= Player:GCD() or (Player:BuffRemainsP(S.PillarofFrostBuff) < 8 and Player:BuffRemainsP(S.UnholyStrengthBuff) <= Player:GCD() and Player:BuffP(S.UnholyStrengthBuff))) and Player:BuffP(S.PillarofFrostBuff) and S.IcyCitadel:AzeriteRank() <= 2) then
      if HR.Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury) then return ""; end
    end
    -- frostwyrms_fury,if=(buff.icy_citadel.remains<=gcd|(buff.icy_citadel.remains<8&buff.unholy_strength.remains<=gcd&buff.unholy_strength.up))&buff.icy_citadel.up&azerite.icy_citadel.rank>2
    if S.FrostwyrmsFury:IsCastableP() and ((Player:BuffRemainsP(S.IcyCitadelBuff) <= Player:GCD() or (Player:BuffRemainsP(S.IcyCitadelBuff) < 8 and Player:BuffRemainsP(S.UnholyStrengthBuff) <= Player:GCD() and Player:BuffP(S.UnholyStrengthBuff))) and Player:BuffP(S.IcyCitadelBuff) and S.IcyCitadel:AzeriteRank() > 2) then
      if HR.Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury) then return ""; end
    end
    -- frostwyrms_fury,if=target.time_to_die<gcd|(target.time_to_die<cooldown.pillar_of_frost.remains&buff.unholy_strength.up)
    if S.FrostwyrmsFury:IsCastableP() and (Target:TimeToDie() < Player:GCD() or (Target:TimeToDie() < S.PillarofFrost:CooldownRemainsP() and Player:BuffP(S.UnholyStrengthBuff))) then
      if HR.Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury) then return ""; end
    end
  end
  Essences = function()
    -- blood_of_the_enemy,if=buff.pillar_of_frost.remains<10&cooldown.breath_of_sindragosa.remains|buff.pillar_of_frost.remains<10&!talent.breath_of_sindragosa.enabled
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffRemainsP(S.PillarofFrostBuff) < 10 and bool(S.BreathofSindragosa:CooldownRemainsP()) or Player:BuffRemainsP(S.PillarofFrostBuff) < 10 and not S.BreathofSindragosa:IsAvailable()) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    -- chill_streak,if=buff.pillar_of_frost.remains<5|target.1.time_to_die<5
    if S.ChillStreak:IsCastableP() and (Player:BuffRemainsP(S.PillarofFrostBuff) < 5 or Target:TimeToDie() < 5) then
      if HR.Cast(S.ChillStreak, nil, Settings.Commons.EssenceDisplayStyle) then return "chill_streak"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<11
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffStackP(S.RecklessForceCounter) < 11) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force"; end
    end
    -- focused_azerite_beam,if=!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up
    if S.FocusedAzeriteBeam:IsCastableP() and (not Player:BuffP(S.PillarofFrostBuff) and not Player:BuffP(S.BreathofSindragosa)) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
    end
    -- concentrated_flame,if=!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up&dot.concentrated_flame_burn.remains=0
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffDownP(S.PillarofFrostBuff) and Player:BuffDownP(S.BreathofSindragosa) and Target:DebuffDownP(S.ConcentratedFlameBurn)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame"; end
    end
    -- purifying_blast,if=!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up
    if S.PurifyingBlast:IsCastableP() and (not Player:BuffP(S.PillarofFrostBuff) and not Player:BuffP(S.BreathofSindragosa)) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast"; end
    end
    -- worldvein_resonance,if=!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up
    if S.WorldveinResonance:IsCastableP() and (not Player:BuffP(S.PillarofFrostBuff) and not Player:BuffP(S.BreathofSindragosa)) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    -- ripple_in_space,if=!buff.pillar_of_frost.up&!buff.breath_of_sindragosa.up
    if S.RippleInSpace:IsCastableP() and (not Player:BuffP(S.PillarofFrostBuff) and not Player:BuffP(S.BreathofSindragosa)) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
    end
    -- memory_of_lucid_dreams,if=buff.empower_rune_weapon.remains<5&buff.breath_of_sindragosa.up|(rune.time_to_2>gcd&runic_power<50)
    if S.MemoryofLucidDreams:IsCastableP() and (Player:BuffRemainsP(S.EmpowerRuneWeaponBuff) < 5 and Player:BuffP(S.BreathofSindragosa) or (Player:RuneTimeToX(2) > Player:GCD() and Player:RunicPower() < 50)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
  end
  Obliteration = function()
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and not S.Frostscythe:IsAvailable() and not Player:BuffP(S.RimeBuff) and Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
    if S.Obliterate:IsCastableP("Melee") and (not S.Frostscythe:IsAvailable() and not Player:BuffP(S.RimeBuff) and Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frostscythe,if=(buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance)))&spell_targets.frostscythe>=2
    if S.Frostscythe:IsCastableP() and ((bool(Player:BuffStackP(S.KillingMachineBuff)) or (Player:BuffP(S.KillingMachineBuff) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) and Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and bool(Player:BuffStackP(S.KillingMachineBuff)) or (Player:BuffP(S.KillingMachineBuff) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate,if=buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
    if S.Obliterate:IsCastableP("Melee") and (bool(Player:BuffStackP(S.KillingMachineBuff)) or (Player:BuffP(S.KillingMachineBuff) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=(!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd)&spell_targets.glacial_advance>=2
    if no_heal and S.GlacialAdvance:IsReadyP() and ((not Player:BuffP(S.RimeBuff) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) and Cache.EnemiesCount[10] >= 2) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- howling_blast,if=buff.rime.up&spell_targets.howling_blast>=2
    if S.HowlingBlast:IsCastableP(30, true) and (Player:BuffP(S.RimeBuff) and Cache.EnemiesCount[10] >= 2) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd&!talent.frostscythe.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and not Player:BuffP(S.RimeBuff) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD() and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frost_strike,if=!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (not Player:BuffP(S.RimeBuff) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:BuffP(S.RimeBuff)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!talent.frostscythe.enabled
    if S.Obliterate:IsCastableP("Melee") and ((Target:DebuffStackP(S.RazoriceDebuff) < 5 or Target:DebuffRemainsP(S.RazoriceDebuff) < 10) and not S.Frostscythe:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- obliterate
    if S.Obliterate:IsCastableP("Melee") then
      if HR.Cast(S.Obliterate) then return ""; end
    end
  end
  Standard = function()
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (S.RemorselessWinter:CooldownRemainsP() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:BuffP(S.RimeBuff)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse.enabled
    if S.Obliterate:IsCastableP("Melee") and (not Player:BuffP(S.FrozenPulseBuff) and S.FrozenPulse:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&rune.time_to_4>=gcd
    if S.Frostscythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and (Player:BuffP(S.KillingMachineBuff) and Player:RuneTimeToX(4) >= Player:GCD()) then
      if HR.Cast(S.Frostscythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frost_strike
    if no_heal and S.FrostStrike:IsReadyP("Melee") then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- horn_of_winter
    if S.HornofWinter:IsCastableP() then
      if HR.Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornofWinter) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- use DeathStrike on low HP in Solo Mode
    if not no_heal and S.DeathStrike:IsReadyP("Melee") then
      if HR.Cast(S.DeathStrike) then return ""; end
    end
    -- use DeathStrike with Proc in Solo Mode
    if Settings.General.SoloMode and S.DeathStrike:IsReadyP("Melee") and Player:BuffP(S.DeathStrikeBuff) then
      if HR.Cast(S.DeathStrike) then return ""; end
    end
    -- Interrupts
    Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, false);
    -- auto_attack
    -- howling_blast,if=!dot.frost_fever.ticking&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.HowlingBlast:IsCastableP(30, true) and (not Target:DebuffP(S.FrostFeverDebuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if no_heal and S.GlacialAdvance:IsReadyP() and (Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and Cache.EnemiesCount[10] >= 2 and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if no_heal and S.FrostStrike:IsReadyP("Melee") and (Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- call_action_list,name=essences
    if (true) then
      local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&((cooldown.breath_of_sindragosa.remains=0&cooldown.pillar_of_frost.remains<10)|(cooldown.breath_of_sindragosa.remains<20&target.time_to_die<35))
    if (HR.CDsON() and S.BreathofSindragosa:IsAvailable() and ((S.BreathofSindragosa:CooldownRemainsP() == 0 and S.PillarofFrost:CooldownRemainsP() < 10) or (S.BreathofSindragosa:CooldownRemainsP() < 20 and Target:TimeToDie() < 35))) then
      return BosPooling();
    end
    -- run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
    if (Player:BuffP(S.BreathofSindragosa)) then
      return BosTicking();
    end
    -- run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration.enabled
    if (Player:BuffP(S.PillarofFrostBuff) and S.Obliteration:IsAvailable()) then
      return Obliteration();
    end
    -- run_action_list,name=aoe,if=active_enemies>=2
    if HR.AoEON() and Cache.EnemiesCount[10] >= 2 then
      return Aoe();
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(196770, 8, 6)               -- Remorseless Winter
  HL.RegisterNucleusAbility(207230, 8, 6)               -- Frostscythe
  HL.RegisterNucleusAbility(49184, 10, 6)               -- Howling Blast
end

HR.SetAPL(251, APL, Init)

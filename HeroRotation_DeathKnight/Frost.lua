--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
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
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.DeathKnight then Spell.DeathKnight = {} end
Spell.DeathKnight.Frost = {
  -- Abilities
  RaiseDead                             = Spell(46585),
  SacrificialPact                       = Spell(327574),
  DeathAndDecay                         = Spell(43265),
  DeathStrike                           = Spell(49998),
  RemorselessWinter                     = Spell(196770),
  FrostStrike                           = Spell(49143),
  Obliterate                            = Spell(49020),
  HowlingBlast                          = Spell(49184),
  ChainsofIce                           = Spell(45524),
  FrostwyrmsFury                        = Spell(279302),
  EmpowerRuneWeapon                     = Spell(47568),
  PillarofFrost                         = Spell(51271),
  -- Talents
  GatheringStorm                        = Spell(194912),
  GlacialAdvance                        = Spell(194913),
  Frostscythe                           = Spell(207230),
  RunicAttenuation                      = Spell(207104),
  FrozenPulse                           = Spell(194909),
  HornofWinter                          = Spell(57330),
  ColdHeart                             = Spell(281208),
  Icecap                                = Spell(207126),
  Obliteration                          = Spell(281238),
  BreathofSindragosa                    = Spell(152279),
  -- Covenant Abilities
  ShackleTheUnworthy                    = Spell(312202),
  SwarmingMist                          = Spell(311648),
  AbominationLimb                       = Spell(315443),
  DeathsDue                             = Spell(324128),
  -- Conduit Effects
  -- Buffs
  RimeBuff                              = Spell(59052),
  KillingMachineBuff                    = Spell(51124),
  PillarofFrostBuff                     = Spell(51271),
  ColdHeartBuff                         = Spell(281209),
  FrozenPulseBuff                       = Spell(194909),
  EmpowerRuneWeaponBuff                 = Spell(47568),
  IcyTalonsBuff                         = Spell(194879),
  DeathStrikeBuff                       = Spell(101568),
  UnholyStrengthBuff                    = Spell(53365),
  -- Debuffs
  RazoriceDebuff                        = Spell(51714),
  FrostFeverDebuff                      = Spell(55095),
  -- Racials
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcanePulse                           = Spell(260364),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  -- Interrupts
  MindFreeze                            = Spell(47528),
  -- Custom
  PoolRange                             = Spell(999910)
};
local S = Spell.DeathKnight.Frost;

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Frost = {
  -- Potions/Trinkets
  -- "Other On Use"
};
local I = Item.DeathKnight.Frost;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local VarOoUE;
local no_heal;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Frost = HR.GUISettings.APL.DeathKnight.Frost
};

-- Functions
--Functions
local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff))) and true or false;
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- variable,name=other_on_use_equipped,value=
  -- raise_dead
  if S.RaiseDead:IsCastable() then
    if HR.CastSuggested(S.RaiseDead) then return "raise_dead precombat"; end
  end
  -- opener
  if Everyone.TargetIsValid() then
    if S.HowlingBlast:IsCastable() and (Target:DebuffDown(S.FrostFeverDebuff)) then
      if HR.Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast precombat"; end
    end
    if S.Obliterate:IsCastable() and (S.BreathofSindragosa:IsAvailable()) then
      if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate precombat"; end
    end
  end
end

local function Aoe()
  -- remorseless_winter,if=talent.gathering_storm.enabled
  if S.RemorselessWinter:IsCastable() and S.GatheringStorm:IsAvailable() then
    if HR.Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter aoe 1"; end
  end
  -- glacial_advance,if=talent.frostscythe.enabled
  if no_heal and S.GlacialAdvance:IsReady() and (S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.GlacialAdvance, nil, nil, not TargetIsInRange[30]) then return "glacial_advance aoe 2"; end
  end
  -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled&!talent.frostscythe.enabled
  if no_heal and S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable() and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike aoe 3"; end
  end
  -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
  if no_heal and S.FrostStrike:IsReady() and (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike aoe 4"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if HR.Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast aoe 5"; end
  end
  -- frostscythe,if=buff.killing_machine.up
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff)) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe aoe 6"; end
  end
  -- glacial_advance,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
  if no_heal and S.GlacialAdvance:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if HR.Cast(S.GlacialAdvance, nil, nil, not TargetIsInRange[30]) then return "glacial_advance aoe 7"; end
  end
  -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit<(15+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
  if no_heal and S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike aoe 8"; end
  end
  -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
  if no_heal and S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike aoe 9"; end
  end
  -- remorseless_winter
  if S.RemorselessWinter:IsCastable() then
    if HR.Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter aoe 10"; end
  end
  -- frostscythe
  if S.Frostscythe:IsCastable() then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe aoe 11"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>(25+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate aoe 12"; end
  end
  -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
  if S.Obliterate:IsCastable() and (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate aoe 13"; end
  end
  -- glacial_advance
  if no_heal and S.GlacialAdvance:IsReady() then
    if HR.Cast(S.GlacialAdvance, nil, nil, not TargetIsInRange[30]) then return "glacial_advance aoe 14"; end
  end
  -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!talent.frostscythe.enabled
  if no_heal and S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike aoe 15"; end
  end
  -- frost_strike
  if no_heal and S.FrostStrike:IsReady() then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike aoe 16"; end
  end
  -- horn_of_winter
  if S.HornofWinter:IsCastable() then
    if HR.Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornofWinter) then return "horn_of_winter aoe 17"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and HR.CDsON() then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_torrent aoe 18"; end
  end
end

local function BosPooling()
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable(30, true) and (Player:BuffUp(S.RimeBuff)) then
    if HR.Cast(S.HowlingBlast) then return "howling_blast bos 1"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>=25&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() >= 25 and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos 2"; end
  end
  -- obliterate,if=runic_power.deficit>=25
  if S.Obliterate:IsCastable() and (Player:RunicPowerDeficit() >= 25) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos 3"; end
  end
  -- glacial_advance,if=runic_power.deficit<20&spell_targets.glacial_advance>=2&cooldown.pillar_of_frost.remains>5
  if no_heal and S.GlacialAdvance:IsReady() and (Player:RunicPowerDeficit() < 20 and EnemiesCount10yd >= 2 and S.PillarofFrost:CooldownRemains() > 5) then
    if HR.Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance bos 4"; end
  end
  -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit<20&!talent.frostscythe.enabled&cooldown.pillar_of_frost.remains>5
  if no_heal and S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() < 20 and not S.Frostscythe:IsAvailable() and S.PillarofFrost:CooldownRemains() > 5) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike bos 5"; end
  end
  -- frost_strike,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>5
  if no_heal and S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < 20 and S.PillarofFrost:CooldownRemains() > 5) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike bos 6"; end
  end
  -- frostscythe,if=buff.killing_machine.up&runic_power.deficit>(15+talent.runic_attenuation.enabled*3)&spell_targets.frostscythe>=2
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and Player:RunicPowerDeficit() > (15 + num(S.RunicAttenuation:IsAvailable()) * 3) and EnemiesMeleeCount >= 2) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos 7"; end
  end
  -- frostscythe,if=runic_power.deficit>=(35+talent.runic_attenuation.enabled*3)&spell_targets.frostscythe>=2
  if S.Frostscythe:IsCastable() and (Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3) and EnemiesMeleeCount >= 2) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos 8"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>=(35+talent.runic_attenuation.enabled*3)&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3) and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos 9"; end
  end
  -- obliterate,if=runic_power.deficit>=(35+talent.runic_attenuation.enabled*3)
  if S.Obliterate:IsCastable() and (Player:RunicPowerDeficit() >= (35 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos 10"; end
  end
  -- glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
  if no_heal and S.GlacialAdvance:IsReady() and (S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and EnemiesCount10yd >= 2) then
    if HR.Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance bos 11"; end
  end
  -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&!talent.frostscythe.enabled
  if no_heal and S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike bos 12"; end
  end
  -- frost_strike,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
  if no_heal and S.FrostStrike:IsReady() and (S.PillarofFrost:CooldownRemains() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike bos 13"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Pooling"; end
end

local function BosTicking()
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power<=32&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPower() <= 32 and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos ticking 1"; end
  end
  -- obliterate,if=runic_power<=32
  if S.Obliterate:IsCastable() and (Player:RunicPower() <= 32) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos ticking 2"; end
  end
  -- remorseless_winter,if=talent.gathering_storm.enabled
  if S.RemorselessWinter:IsCastable() and (S.GatheringStorm:IsAvailable()) then
    if HR.Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter bos ticking 3"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if HR.Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast bos ticking 4"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&rune.time_to_5<gcd|runic_power<=45&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RuneTimeToX(5) < Player:GCD() or Player:RunicPower() <= 45 and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos ticking 5"; end
  end
  -- obliterate,if=rune.time_to_5<gcd|runic_power<=45
  if S.Obliterate:IsCastable() and (Player:RuneTimeToX(5) < Player:GCD() or Player:RunicPower() <= 45) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos ticking 6"; end
  end
  -- frostscythe,if=buff.killing_machine.up&spell_targets.frostscythe>=2
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and EnemiesMeleeCount >= 2) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos ticking 7"; end
  end
  -- horn_of_winter,if=runic_power.deficit>=32&rune.time_to_3>gcd
  if S.HornofWinter:IsCastable() and (Player:RunicPowerDeficit() >= 30 and Player:RuneTimeToX(3) > Player:GCD()) then
    if HR.Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornofWinter) then return "horn_of_winter bos ticking 8"; end
  end
  -- remorseless_winter
  if S.RemorselessWinter:IsCastable() then
    if HR.Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter bos ticking 9"; end
  end
  -- frostscythe,if=spell_targets.frostscythe>=2
  if S.Frostscythe:IsCastable() and (EnemiesMeleeCount >= 2) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe bos ticking 10"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&runic_power.deficit>25|rune>3&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:RunicPowerDeficit() > 25 or Player:Rune() > 3 and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos ticking 11"; end
  end
  -- obliterate,if=runic_power.deficit>25|rune>3
  if S.Obliterate:IsCastable() and (Player:RunicPowerDeficit() > 25 or Player:Rune() > 3) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate bos ticking 12"; end
  end
  -- arcane_torrent,if=runic_power.deficit>50
  if S.ArcaneTorrent:IsCastable() and HR.CDsON() and (Player:RunicPowerDeficit() > 50) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_torrent bos ticking 13"; end
  end
  -- wait for resources
  if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Ticking"; end
end

local function ColdHeart()
  -- chains_of_ice,if=buff.cold_heart.stack>5&target.1.time_to_die<gcd|buff.pillar_of_frost.remains<3
  if S.ChainsofIce:IsCastable() and (Player:BuffStack(S.ColdHeartBuff) > 5 and Target:TimeToDie() < Player:GCD() * 2 or Player:BuffRemains(S.PillarofFrostBuff) < 3) then
    if HR.Cast(S.ChainsofIce, nil, nil, not TargetIsInRange[30]) then return "chains_of_ice coldheart"; end
  end
end

local function Cooldowns()
  if (Settings.Commons.UseTrinkets) then
    -- pillar_of_frost,if=(cooldown.empower_rune_weapon.remains|talent.icecap.enabled)&!buff.pillar_of_frost.up
    if S.PillarofFrost:IsCastable() and (bool(S.EmpowerRuneWeapon:CooldownRemains()) or S.Icecap:IsAvailable()) and Player:BuffDown(S.PillarofFrostBuff) then
      if HR.Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarofFrost) then return "pillar_of_frost cd 1"; end
    end
    -- breath_of_sindragosa,use_off_gcd=1,if=cooldown.empower_rune_weapon.remains&cooldown.pillar_of_frost.remains
    if S.BreathofSindragosa:IsCastable() and (bool(S.EmpowerRuneWeapon:CooldownRemains()) and bool(S.PillarofFrost:CooldownRemains())) then
      if HR.Cast(S.BreathofSindragosa, nil, Settings.Frost.BoSDisplayStyle, not TargetIsInRange[8]) then return "breath_of_sindragosa cd 2"; end
    end
    -- empower_rune_weapon,if=cooldown.pillar_of_frost.ready&talent.obliteration.enabled&rune.time_to_5>gcd&runic_power.deficit>=10|target.1.time_to_die<20
    if S.EmpowerRuneWeapon:IsCastable() and (S.PillarofFrost:CooldownUp() and S.Obliteration:IsAvailable() and Player:RuneTimeToX(5) > Player:GCD() and Player:RunicPowerDeficit() >= 10 or Target:TimeToDie() < 20) then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cd 3"; end
    end
    -- empower_rune_weapon,if=(cooldown.pillar_of_frost.ready|target.1.time_to_die<20)&talent.breath_of_sindragosa.enabled&runic_power>60
    if S.EmpowerRuneWeapon:IsCastable() and ((S.PillarofFrost:CooldownUp() or Target:TimeToDie() < 20) and S.BreathofSindragosa:IsAvailable() and Player:RunicPower() > 60) then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cd 4"; end
    end
    -- empower_rune_weapon,if=talent.icecap.enabled&rune<3
    if S.EmpowerRuneWeapon:IsCastable() and (S.Icecap:IsAvailable() and Player:Rune() < 3) then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cd 5"; end
    end
    -- frostwyrms_fury,if=buff.pillar_of_frost.remains<(3+talent.cold_heart.enabled*1)
    if S.FrostwyrmsFury:IsCastable() and (Player:BuffRemains(S.PillarofFrostBuff) < (3 + num(S.RunicAttenuation:IsAvailable()) * 1)) then
      if HR.Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not TargetIsInRange[40]) then return "frostwyrms_fury cd 6"; end
    end
    -- frostwyrms_fury,if=active_enemies>=2&cooldown.pillar_of_frost.remains+15>target.time_to_die|target.1.time_to_die<gcd
    if S.FrostwyrmsFury:IsCastable() and (EnemiesMeleeCount >= 2 and S.PillarofFrost:CooldownRemains() + 15 > Target:TimeToDie() or Target:TimeToDie() < Player:GCD()) then
      if HR.Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not TargetIsInRange[40]) then return "frostwyrms_fury cd 7"; end
    end
    -- raise_dead
    if S.RaiseDead:IsCastable() then
      if HR.CastSuggested(S.RaiseDead) then return "raise_dead cd 8"; end
    end
    -- sacrificial_pact,if=(buff.pillar_of_frost.up&buff.pillar_of_frost.remains=<1|cooldown.raise_dead.remains<63)&pet.risen_ghoul.active
    if S.SacrificialPact:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffRemains(S.PillarofFrostBuff) <= 1 or S.RaiseDead:CooldownRemains() < 63) and Pet:IsActive() then
      if HR.Cast(S.SacrificialPact, Settings.Commons.GCDasOffGCD.SacrificialPact, nil, not TargetIsInRange[8]) then return "sacrificial pact cd 9"; end
    end
  end
end

local function Obliteration()
  -- remorseless_winter,if=talent.gathering_storm.enabled
  if S.RemorselessWinter:IsCastable() and (S.GatheringStorm:IsAvailable()) then
    if HR.Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter obliteration 1"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and not S.Frostscythe:IsAvailable() and Player:BuffDown(S.RimeBuff) and EnemiesCount10yd >= 3) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate obliteration 2"; end
  end
  -- obliterate,if=!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
  if S.Obliterate:IsCastable() and (not S.Frostscythe:IsAvailable() and Player:BuffDown(S.RimeBuff) and EnemiesCount10yd >= 3) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate obliteration 3"; end
  end
  -- frostscythe,if=(buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance)))&spell_targets.frostscythe>=2
  if S.Frostscythe:IsCastable() and ((bool(Player:BuffStack(S.KillingMachineBuff)) or (Player:BuffUp(S.KillingMachineBuff) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) and EnemiesMeleeCount >= 2) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe obliteration 4"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and bool(Player:BuffStack(S.KillingMachineBuff)) or (Player:BuffUp(S.KillingMachineBuff) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate obliteration 5"; end
  end
  -- obliterate,if=buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
  if S.Obliterate:IsCastable() and (bool(Player:BuffStack(S.KillingMachineBuff)) or (Player:BuffUp(S.KillingMachineBuff) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate obliteration 6"; end
  end
  -- glacial_advance,if=(!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd)&spell_targets.glacial_advance>=2
  if no_heal and S.GlacialAdvance:IsReady() and ((Player:BuffDown(S.RimeBuff) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) and EnemiesCount10yd >= 2) then
    if HR.Cast(S.GlacialAdvance, nil, nil, TargetIsInRange[100]) then return "glacial_advance obliteration 7"; end
  end
  -- howling_blast,if=buff.rime.up&spell_targets.howling_blast>=2
  if S.HowlingBlast:IsCastable(30, true) and (Player:BuffUp(S.RimeBuff) and EnemiesCount10yd >= 2) then
    if HR.Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast obliteration 8"; end
  end
  -- frost_strike,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd&!talent.frostscythe.enabled
  if no_heal and S.FrostStrike:IsReady() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and Player:BuffDown(S.RimeBuff) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD() and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike obliteration 9"; end
  end
  -- frost_strike,if=!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd
  if no_heal and S.FrostStrike:IsReady() and (Player:BuffDown(S.RimeBuff) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike obliteration 10"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if HR.Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast obliteration 11"; end
  end
  -- obliterate,target_if=(debuff.razorice.stack<5|debuff.razorice.remains<10)&!talent.frostscythe.enabled
  if S.Obliterate:IsCastable() and ((Target:DebuffStack(S.RazoriceDebuff) < 5 or Target:DebuffRemains(S.RazoriceDebuff) < 10) and not S.Frostscythe:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate obliteration 12"; end
  end
  -- obliterate
  if S.Obliterate:IsCastable() then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate obliteration 13"; end
  end
end

local function Standard()
  -- remorseless_winter
  if S.RemorselessWinter:IsCastable() then
    if HR.Cast(S.RemorselessWinter, nil, nil, not TargetIsInRange[8]) then return "remorseless_winter standard 1"; end
  end
  -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
  if no_heal and S.FrostStrike:IsReady() and (S.RemorselessWinter:CooldownRemains() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 2"; end
  end
  -- howling_blast,if=buff.rime.up
  if S.HowlingBlast:IsCastable() and (Player:BuffUp(S.RimeBuff)) then
    if HR.Cast(S.HowlingBlast, nil, nil, not TargetIsInRange[30]) then return "howling_blast standard 3"; end
  end
  -- obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse.enabled
  if S.Obliterate:IsCastable() and (Player:BuffDown(S.FrozenPulseBuff) and S.FrozenPulse:IsAvailable()) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate standard 4"; end
  end
  -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
  if no_heal and S.FrostStrike:IsReady() and (Player:RunicPowerDeficit() < (15 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 5"; end
  end
  -- frostscythe,if=buff.killing_machine.up&rune.time_to_4>=gcd
  if S.Frostscythe:IsCastable() and (Player:BuffUp(S.KillingMachineBuff) and Player:RuneTimeToX(4) >= Player:GCD()) then
    if HR.Cast(S.Frostscythe, nil, nil, not TargetIsInRange[8]) then return "frostscythe standard 6"; end
  end
  -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
  if S.Obliterate:IsCastable() and (Player:RunicPowerDeficit() > (25 + num(S.RunicAttenuation:IsAvailable()) * 3)) then
    if HR.Cast(S.Obliterate, nil, nil, not TargetIsInRange[8]) then return "obliterate standard 7"; end
  end
  -- frost_strike
  if no_heal and S.FrostStrike:IsReady() then
    if HR.Cast(S.FrostStrike, nil, nil, not TargetIsInRange[8]) then return "frost_strike standard 8"; end
  end
  -- horn_of_winter
  if S.HornofWinter:IsCastable() then
    if HR.Cast(S.HornofWinter, Settings.Frost.GCDasOffGCD.HornofWinter) then return "horn_of_winter standard 9"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and HR.CDsON() then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent standard 10"; end
  end
end

local function Racials()
  if (HR.CDsON()) then
    --blood_fury,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
    if S.BloodFury:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial 1"; end
    end
    --berserking,if=buff.pillar_of_frost.up
    if S.Berserking:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial 2"; end
    end
    --arcane_pulse,if=(!buff.pillar_of_frost.up&active_enemies>=2)|!buff.pillar_of_frost.up&(rune.deficit>=5&runic_power.deficit>=60)
    if S.ArcanePulse:IsCastable() and ((Player:BuffUp(S.PillarofFrostBuff) and EnemiesMeleeCount >= 2) and Player:BuffDown(S.PillarofFrostBuff) and (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
      if HR.Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_pulse racial 3"; end
    end
    --lights_judgment,if=buff.pillar_of_frost.up
    if S.LightsJudgment:IsCastable() and Player:BuffUp(S.PillarofFrostBuff) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "lights_judgment racial 4"; end
    end
    --ancestral_call,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
    if S.AncestralCall:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial 5"; end
    end
    --fireblood,if=buff.pillar_of_frost.remains<=8&buff.empower_rune_weapon.up
    if S.Fireblood:IsCastable() and (Player:BuffRemains(S.PillarofFrostBuff) <= 8 and Player:BuffUp(S.EmpowerRuneWeaponBuff)) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial 6"; end
    end
    --bag_of_tricks,if=buff.pillar_of_frost.up&(buff.pillar_of_frost.remains<5&talent.cold_heart.enabled|!talent.cold_heart.enabled&buff.pillar_of_frost.remains<3)&active_enemies=1|buff.seething_rage.up&active_enemies=1
    if S.BagofTricks:IsCastable() and (Player:BuffUp(S.PillarofFrostBuff) and (Player:BuffRemains(S.PillarofFrostBuff) < 5 and S.ColdHeart:IsAvailable() or not S.ColdHeart:IsAvailable() and Player:BuffRemains(S.PillarofFrostBuff) < 3) and EnemiesMeleeCount == 1) then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "bag_of_tricks racial 7"; end
    end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(8)
  Enemies10yd = Player:GetEnemiesInMeleeRange(10)
  EnemiesCount10yd = #Enemies10yd
  EnemiesMeleeCount = #EnemiesMelee
  ComputeTargetRange()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady("Melee") and not no_heal then
      if HR.Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, false); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- howling_blast,if=!dot.frost_fever.ticking&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.HowlingBlast:IsCastable(30, true) and (Target:DebuffDown(S.FrostFeverDebuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 15)) then
      if HR.Cast(S.HowlingBlast) then return "howling_blast 1"; end
    end
    -- glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if no_heal and S.GlacialAdvance:IsReady() and (Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffUp(S.IcyTalonsBuff) and EnemiesCount10yd >= 2 and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 15)) then
      if HR.Cast(S.GlacialAdvance, nil, nil, 100) then return "glacial_advance 3"; end
    end
    -- frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if no_heal and S.FrostStrike:IsReady("Melee") and (Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffUp(S.IcyTalonsBuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemains() > 15)) then
      if HR.Cast(S.FrostStrike) then return "frost_strike 5"; end
    end
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cold_heart,if=talent.cold_heart.enabled&((buff.cold_heart.stack>=10&debuff.razorice.stack=5)|target.1.time_to_die<=gcd)
    if (S.ColdHeart:IsAvailable() and ((Player:BuffStack(S.ColdHeartBuff) >= 10 and Target:DebuffStack(S.RazoriceDebuff) == 5) or Target:TimeToDie() <= Player:GCD())) then
      local ShouldReturn = ColdHeart(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_ticking,if=buff.breath_of_sindragosa.up
    if (Player:BuffUp(S.BreathofSindragosa)) then
      return BosTicking();
    end
    -- run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&((cooldown.breath_of_sindragosa.remains=0&cooldown.pillar_of_frost.remains<10)|(cooldown.breath_of_sindragosa.remains<20&target.1.time_to_die<35))
    if (not Settings.Frost.DisableBoSPooling and S.BreathofSindragosa:IsAvailable() and ((S.BreathofSindragosa:CooldownRemains() == 0 and S.PillarofFrost:CooldownRemains() < 10) or (S.BreathofSindragosa:CooldownRemains() < 20 and Target:TimeToDie() < 35))) then
      return BosPooling();
    end
    -- run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration.enabled
    if (Player:BuffUp(S.PillarofFrostBuff) and S.Obliteration:IsAvailable()) then
      return Obliteration();
    end
    -- run_action_list,name=aoe,if=active_enemies>=2
    if HR.AoEON() and EnemiesCount10yd >= 2 then
      return Aoe();
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- racials
    if (true) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resouces
    if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(251, APL, Init)

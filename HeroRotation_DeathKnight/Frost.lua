--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- HeroRotation
  local HR = HeroRotation;
  -- Lua



--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = HR.Commons.Everyone;
  local DeathKnight = HR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Frost = {
    -- Racials
    ArcaneTorrent                 = Spell(50613),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),

    -- Abilities
    ChainsOfIce                   = Spell(45524),
    EmpowerRuneWeapon             = Spell(47568),
    FrostFever                    = Spell(55095),
    FrostStrike                   = Spell(49143),
    HowlingBlast                  = Spell(49184),
    Obliterate                    = Spell(49020),
    PillarOfFrost                 = Spell(51271),
    RazorIce                      = Spell(51714),
    RemorselessWinter             = Spell(196770),
    KillingMachine                = Spell(51124),
    Rime                          = Spell(59052),
    UnholyStrength                = Spell(53365),
    -- Talents
    BreathofSindragosa            = Spell(152279),
    BreathofSindragosaTicking     = Spell(155166),
    FrostScythe                   = Spell(207230),
    FrozenPulse                   = Spell(194909),
    FreezingFog                   = Spell(207060),
    GatheringStorm                = Spell(194912),
    GatheringStormBuff            = Spell(211805),
    GlacialAdvance                = Spell(194913),
    HornOfWinter                  = Spell(57330),
    IcyTalons                     = Spell(194878),
    IcyTalonsBuff                 = Spell(194879),
    MurderousEfficiency           = Spell(207061),
    Obliteration                  = Spell(281238),
    RunicAttenuation              = Spell(207104),
    ShatteringStrikes             = Spell(207057),
    Icecap                        = Spell(207126),
    ColdHeartTalent               = Spell(281208),
    ColdHeartBuff                 = Spell(281209),
    ColdHeartItemBuff             = Spell(235599),
    FrostwyrmsFury                = Spell(279302),
    -- Defensive
    AntiMagicShell                = Spell(48707),
    DeathStrike                   = Spell(49998),
    IceboundFortitude             = Spell(48792),
    -- Utility
    ControlUndead                 = Spell(45524),
    DeathGrip                     = Spell(49576),
    MindFreeze                    = Spell(47528),
    PathOfFrost                   = Spell(3714),
    WraithWalk                    = Spell(212552),
    -- Misc
    PoolRange                   = Spell(9999000010)
    -- Macros

  };
  local S = Spell.DeathKnight.Frost;
  -- Items
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Frost = {
    -- Legendaries
    ConvergenceofFates            = Item(140806, {13, 14}),
    ColdHeart                     = Item(151796, {5}),
    ConsortsColdCore              = Item(144293, {8}),
    KiljaedensBurningWish         = Item(144259, {13, 14}),
    KoltirasNewfoundWill          = Item(132366, {6}),
    SealOfNecrofantasia           = Item(137223, {11, 12}),
    ToravonsWhiteoutBindings      = Item(132458, {9}),
    --Trinkets
    --Potion
    ProlongedPower                = Item(142117)

  };
  local I = Item.DeathKnight.Frost;
  -- Rotation Var
  local T192P,T194P = HL.HasTier("T19")
  local T202P,T204P = HL.HasTier("T20")
  local T212P,T214P = HL.HasTier("T21")

  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    DeathKnight = HR.GUISettings.APL.DeathKnight

  };

--- ======= ACTION LISTS =======
  local function Standard()
    -- howling_blast,if=!dot.frost_fever.ticking&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.HowlingBlast:IsCastableP() and (not Target:DebuffP(S.FrostFever) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.GlacialAdvance:IsCastableP() and (Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and Cache.EnemiesCount[30] >= 2 and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.FrostStrike:IsUsable() and (Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
    if S.FrostStrike:IsUsable() and (S.RemorselessWinter:CooldownRemainsP() <= (2 * Player:GCD()) and S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP() and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse.enabled
    if S.Obliterate:IsCastableP() and (not Player:BuffP(S.FrozenPulseBuff) and S.FrozenPulse:IsAvailable()) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if S.FrostStrike:IsUsable() and (Player:RunicPowerDeficit() < (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&rune.time_to_4>=gcd
    if S.FrostScythe:IsCastableP() and (Player:BuffP(S.KillingMachine) and Player:RuneTimeToX(4) >= Player:GCD()) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP() and (Player:RunicPowerDeficit() > (25 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frost_strike
    if S.FrostStrike:IsUsable() then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- horn_of_winter
    if S.HornOfWinter:IsCastableP() then
      if HR.Cast(S.HornOfWinter) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Frost.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    return false;
  end
  local function AOE()
    if HR.AoEON() then
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- glacial_advance,if=talent.frostscythe.enabled
    if S.GlacialAdvance:IsCastableP() and (S.FrostScythe:IsAvailable()) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
    if S.FrostStrike:IsUsable() and (S.RemorselessWinter:CooldownRemainsP() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP() and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up
    if S.FrostScythe:IsCastableP() and (Player:BuffP(S.KillingMachine)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- glacial_advance,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if S.GlacialAdvance:IsCastableP() and (Player:RunicPowerDeficit() < (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if S.FrostStrike:IsUsable() and (Player:RunicPowerDeficit() < (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frostscythe
    if S.FrostScythe:IsCastableP() then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP() and (Player:RunicPowerDeficit() > (25 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance
    if S.GlacialAdvance:IsCastableP() then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike
    if S.FrostStrike:IsUsable() then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- horn_of_winter
    if S.HornOfWinter:IsCastableP() then
      if HR.Cast(S.HornOfWinter) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Frost.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
  end
  return false;
  end

  local function ColdHeart()
    -- chains_of_ice,if=(buff.cold_heart_item.stack>5|buff.cold_heart_talent.stack>5)&target.time_to_die<gcd
    if S.ChainsOfIce:IsCastableP() and ((Player:BuffStackP(S.ColdHeartItemBuff) > 5 or Player:BuffStackP(S.ColdHeartBuff) > 5) and Target:TimeToDie() < Player:GCD()) then
      if HR.Cast(S.ChainsOfIce) then return ""; end
    end
    -- chains_of_ice,if=(buff.pillar_of_frost.remains<=gcd*(1+cooldown.frostwyrms_fury.ready)|buff.pillar_of_frost.remains<rune.time_to_3)&buff.pillar_of_frost.up
    if S.ChainsOfIce:IsCastableP() and ((Player:BuffRemainsP(S.PillarOfFrost) <= Player:GCD() * (1 + (S.FrostwyrmsFury:IsReady() and 1 or 0)) or Player:BuffRemainsP(S.PillarOfFrost) < Player:RuneTimeToX(3)) and Player:BuffP(S.PillarOfFrost)) then
      if HR.Cast(S.ChainsOfIce) then return ""; end
    end
    return false;
  end

  local function BoS_Pooling()
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP() and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=rune.time_to_4<gcd&runic_power.deficit>=25
    if S.Obliterate:IsCastableP() and (Player:RuneTimeToX(4) < Player:GCD() and Player:RunicPowerDeficit() >= 25) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>rune.time_to_4
    if S.GlacialAdvance:IsCastableP() and (Player:RunicPowerDeficit() < 20 and S.PillarOfFrost:CooldownRemainsP() > Player:RuneTimeToX(4)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&runic_power.deficit>(15+talent.runic_attenuation.enabled*3)
    if S.FrostScythe:IsCastableP() and (Player:BuffP(S.KillingMachine) and Player:RunicPowerDeficit() > (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>=(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP() and (Player:RunicPowerDeficit() >= (25 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastableP() and (S.PillarOfFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and Cache.EnemiesCount[30] >= 2) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
    if S.FrostStrike:IsUsable() and (S.PillarOfFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    return false;
  end

  local function BoS_Ticking()
    -- obliterate,if=runic_power<=30
    if S.Obliterate:IsCastableP() and (Player:RunicPower() <= 30) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP() and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=rune.time_to_5<gcd|runic_power<=45
    if S.Obliterate:IsCastableP() and (Player:RuneTimeToX(5) < Player:GCD() or Player:RunicPower() <= 45) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up
    if S.FrostScythe:IsCastableP() and (Player:BuffP(S.KillingMachine)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- horn_of_winter,if=runic_power.deficit>=30&rune.time_to_3>gcd
    if S.HornOfWinter:IsCastableP() and (Player:RunicPowerDeficit() >= 30 and Player:RuneTimeToX(3) > Player:GCD()) then
      if HR.Cast(S.HornOfWinter) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frostscythe,if=spell_targetS.FrostScythe:>=2
    if S.FrostScythe:IsCastableP() and (Cache.EnemiesCount[8] >= 2) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>25|rune>3
    if S.Obliterate:IsCastableP() and (Player:RunicPowerDeficit() > 25 or Player:Runes() > 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- arcane_torrent,if=runic_power.deficit>20
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Player:RunicPowerDeficit() > 20) then
      if HR.Cast(S.ArcaneTorrent, Settings.Frost.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    return false;
  end

  local function Obliteration()
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- obliterate,if=!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
    if S.Obliterate:IsCastableP() and (not S.FrostScythe:IsAvailable() and not Player:Buff(S.Rime) and Cache.EnemiesCount[30] >= 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frostscythe,if=(buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance)))&(rune.time_to_4>gcd|spell_targets.frostscythe>=2)
    if S.FrostScythe:IsCastableP() and ((Player:BuffP(S.KillingMachine) or (Player:BuffP(S.KillingMachine) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) and (Player:RuneTimeToX(4) > Player:GCD() or Cache.EnemiesCount[8] >= 2)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
    if S.Obliterate:IsCastableP() and Player:BuffP(S.KillingMachine) or (Player:BuffP(S.KillingMachine) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance))) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=(!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd)&spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastableP() and ((not Player:Buff(S.Rime) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) and Cache.EnemiesCount[30] >= 2) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- howling_blast,if=buff.rime.up&spell_targets.howling_blast>=2
    if S.HowlingBlast:IsCastableP() and (Player:Buff(S.Rime) and Cache.EnemiesCount[30] >= 2) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frost_strike,if=!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd
    if S.FrostStrike:IsUsable() and not Player:Buff(S.Rime) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD() then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP() and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate
    if S.Obliterate:IsCastableP() then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    return false;
  end

  local function Cooldowns()
    -- use_item,name=horn_of_valor,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
    --if I.HornofValor:IsReady() and (Player:BuffP(S.PillarOfFrost) and not S.BreathofSindragosa:IsAvailable() or not S.BreathofSindragosa:CooldownRemainsP()) then
      --if HR.CastSuggested(I.HornofValor) then return ""; end
    --end
    -- potion,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
    --if I.ProlongedPower:IsReady() and Settings.DeathKnight.Commons.UsePotions and (Player:BuffP(S.PillarOfFrost) and Player:BuffP(S.EmpowerRuneWeapon)) then
      --if HR.CastLeft(I.ProlongedPower) then return ""; end
    --end
    -- blood_fury,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
    --if S.BloodFury:IsCastableP() and (Player:BuffP(S.PillarOfFrost) and Player:BuffP(S.EmpowerRuneWeapon)) then
      --if HR.Cast(S.BloodFury, Settings.Frost.OffGCDasOffGCD.BloodFury) then return ""; end
    --end
    -- berserking,if=buff.pillar_of_frost.up
    --if S.Berserking:IsCastableP() and (Player:BuffP(S.PillarOfFrost)) then
      --if HR.Cast(S.Berserking, Settings.Frost.OffGCDasOffGCD.Berserking) then return ""; end
    --end
    -- pillar_of_frost,if=cooldown.empower_rune_weapon.remains
    if S.PillarOfFrost:IsCastableP() and S.EmpowerRuneWeapon:CooldownRemainsP() > 0 then
      if HR.Cast(S.PillarOfFrost, Settings.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost) then return ""; end
    end
    -- empower_rune_weapon,if=cooldown.pillar_of_frost.ready&!talent.breath_of_sindragosa.enabled&rune.time_to_5>gcd&runic_power.deficit>=10
    if S.EmpowerRuneWeapon:IsCastable() and S.PillarOfFrost:IsReady() and not S.BreathofSindragosa:IsAvailable() and Player:RuneTimeToX(5) < Player:GCD() and Player:RunicPowerDeficit() >= 40 then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.DeathKnight.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end
     --empower_rune_weapon,if=cooldown.pillar_of_frost.ready&talent.breath_of_sindragosa.enabled&rune>=3&runic_power>60
    if S.EmpowerRuneWeapon:IsCastable() and S.PillarOfFrost:IsReady() and S.BreathofSindragosa:IsAvailable() and Player:Runes() >= 3 and Player:RunicPower() > 60 then
      if HR.Cast(S.EmpowerRuneWeapon, Settings.DeathKnight.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end
     --breath_of_sindragosa,if=cooldown.empower_rune_weapon.remains&cooldown.pillar_of_frost.remains
    if S.BreathofSindragosa:IsCastableP() and S.EmpowerRuneWeapon:CooldownRemainsP() > 0 and S.PillarOfFrost:CooldownRemainsP() > 0 then
      if HR.Cast(S.BreathofSindragosa) then return ""; end
    end
    -- call_action_list,name=cold_heart,if=(equipped.cold_heart|talent.cold_heart.enabled)&(((buff.cold_heart_item.stack>=10|buff.cold_heart_talent.stack>=10)&debuff.razorice.stack=5)|target.time_to_die<=gcd)
    if (I.ColdHeart:IsEquipped() or S.ColdHeartTalent:IsAvailable()) and (((Player:BuffStackP(S.ColdHeartItemBuff) >= 10 or Player:BuffStackP(S.ColdHeartBuff) >= 10) and Target:DebuffStack(S.RazorIce) == 5) or Target:TimeToDie() <= Player:GCD()) then
      return ColdHeart();
    end
    -- frostwyrms_fury,if=(buff.pillar_of_frost.remains<=gcd&buff.pillar_of_frost.up)
    if S.FrostwyrmsFury:IsCastableP() and ((Player:BuffRemainsP(S.PillarOfFrost) <= Player:GCD() and Player:BuffP(S.PillarOfFrost))) then
      if HR.Cast(S.FrostwyrmsFury) then return ""; end
    end
  return false;
  end

--- ======= MAIN =======
local function APL ()
    -- Unit Update
    HL.GetEnemies("Melee");
    HL.GetEnemies(8,true);
    HL.GetEnemies(10,true);
    HL.GetEnemies(30,true);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives

    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Reset Combat Variables
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Volley toggle
      -- Opener
    if Everyone.TargetIsValid() and Target:IsInRange(30) and not Target:Debuff(S.FrostFever) then
      if HR.Cast(S.HowlingBlast) then return ""; end
      end
    return;
  end

  -- In Combat
    if Everyone.TargetIsValid() and Target:IsInRange("Melee") then
      if HR.CDsON() then
      -- actions+=/call_action_list,name=cooldowns
      ShouldReturn = Cooldowns();
      --print("Cooldowns");
      if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<5
      if (S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemainsP() < 5) then
        ShouldReturn = BoS_Pooling();
        --print("BosPooling");
        if ShouldReturn then return ShouldReturn; end
        end

      --actions+=/run_action_list,name=bos_ticking,if=talent.breath_of_sindragosa.enabled&dot.breath_of_sindragosa.ticking
      if Player:Buff(S.BreathofSindragosa) then
        ShouldReturn = BoS_Ticking();
        --print("BOSTICKING");
        if ShouldReturn then return ShouldReturn; end
      end

      -- run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration.enabled
      if (Player:BuffP(S.PillarOfFrost) and S.Obliteration:IsAvailable()) then
        ShouldReturn = Obliteration();
        --print("Oblit");
        if ShouldReturn then return ShouldReturn; end
      end
      -- run_action_list,name=aoe,if=active_enemies>=2
      if HR.AoEON() and Cache.EnemiesCount[30] >= 2 then
        ShouldReturn = AOE();
        --print("AOE");
        if ShouldReturn then return ShouldReturn; end
      end

      --actions+=/call_action_list,name=standard
      if S.Obliteration:IsAvailable() or S.BreathofSindragosa:IsAvailable() or S.Icecap:IsAvailable() then
        ShouldReturn = Standard();
        --print("Standard");
        if ShouldReturn then return ShouldReturn; end
      end

    --else -- OOR
      --if S.FrostStrike:IsUsable() then
        --if HR.Cast(S.FrostStrike) then return ""; end
      --elseif S.HowlingBlast:IsCastable() and Player:Runes() >= 3 then
        --if HR.Cast(S.HowlingBlast) then return ""; end
      --else
        --if HR.CastAnnotated(S.PoolRange, false, "GO MELEE") then return "";end
      --end
      return;
    end
end


  HR.SetAPL(251, APL);
--- ====11/07/2018======
--- ======= SIMC =======
--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/potion
--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/mind_freeze
--actions+=/call_action_list,name=cooldowns
--actions+=/run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<15
--actions+=/run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
--actions+=/run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration.enabled
--actions+=/call_action_list,name=standard
--# Breath of Sindragosa pooling rotation : starts 15s before the cd becomes available
--actions.bos_pooling=remorseless_winter,if=talent.gathering_storm.enabled
--actions.bos_pooling+=/howling_blast,if=buff.rime.up&rune.time_to_4<(gcd*2)
--actions.bos_pooling+=/obliterate,if=rune.time_to_6<gcd&!talent.gathering_storm.enabled
--actions.bos_pooling+=/obliterate,if=rune.time_to_4<gcd&(cooldown.breath_of_sindragosa.remains|runic_power.deficit>=30)
--actions.bos_pooling+=/frost_strike,if=runic_power.deficit<5&set_bonus.tier19_4pc&cooldown.breath_of_sindragosa.remains
--actions.bos_pooling+=/remorseless_winter,if=buff.rime.up&equipped.perseverance_of_the_ebon_martyr
--actions.bos_pooling+=/howling_blast,if=buff.rime.up&(buff.remorseless_winter.up|cooldown.remorseless_winter.remains>gcd|(!equipped.perseverance_of_the_ebon_martyr&!talent.gathering_storm.enabled))
--actions.bos_pooling+=/obliterate,if=!buff.rime.up&!(talent.gathering_storm.enabled&!(cooldown.remorseless_winter.remains>(gcd*2)|rune>4))&rune>3
--actions.bos_pooling+=/frost_strike,if=runic_power.deficit<30
--actions.bos_pooling+=/frostscythe,if=buff.killing_machine.react&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
--actions.bos_pooling+=/glacial_advance,if=spell_targets.glacial_advance>=2
--actions.bos_pooling+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
--actions.bos_pooling+=/frostscythe,if=spell_targets.frostscythe>=3
--actions.bos_pooling+=/frost_strike,if=(cooldown.remorseless_winter.remains<(gcd*2)|buff.gathering_storm.stack=10)&cooldown.breath_of_sindragosa.remains>rune.time_to_4&talent.gathering_storm.enabled
--actions.bos_pooling+=/obliterate,if=!buff.rime.up&(!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>gcd)
--actions.bos_pooling+=/frost_strike,if=cooldown.breath_of_sindragosa.remains>rune.time_to_4
--# Breath of Sindragosa uptime rotation
--actions.bos_ticking=remorseless_winter,if=runic_power>=30&((buff.rime.up&equipped.perseverance_of_the_ebon_martyr)|(talent.gathering_storm.enabled&(buff.remorseless_winter.remains<=gcd|!buff.remorseless_winter.remains)))
--action.sbos_ticking+=/howling_blast,if=((runic_power>=20&set_bonus.tier19_4pc)|runic_power>=30)&buff.rime.up
--actions.bos_ticking+=/frost_strike,if=set_bonus.tier20_2pc&runic_power.deficit<=15&rune<=3&buff.pillar_of_frost.up
--actions.bos_ticking+=/obliterate,if=runic_power<=45|rune.time_to_5<gcd
--actions.bos_ticking+=/horn_of_winter,if=runic_power.deficit>=30&rune.time_to_3>gcd
--actions.bos_ticking+=/frostscythe,if=buff.killing_machine.react&(!equipped.koltiras_newfound_will|talent.gathering_storm.enabled|spell_targets.frostscythe>=2)
--actions.bos_ticking+=/glacial_advance,if=spell_targets.glacial_advance>=2
--actions.bos_ticking+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
--actions.bos_ticking+=/obliterate,if=runic_power.deficit>25|rune>3
--actions.bos_ticking+=/empower_rune_weapon,if=runic_power<30&rune.time_to_2>gcd
--# Cold heart conditions
--actions.cold_heart=chains_of_ice,if=buff.cold_heart_item.stack=20&buff.unholy_strength.react&cooldown.pillar_of_frost.remains>6
--actions.cold_heart+=/chains_of_ice,if=buff.cold_heart_item.stack>=16&buff.pillar_of_frost.up
--actions.cold_heart+=/chains_of_ice,if=buff.pillar_of_frost.up&buff.pillar_of_frost.remains<gcd&(buff.cold_heart_item.stack>=11|(buff.cold_heart_item.stack>=10&set_bonus.tier20_4pc))
--actions.cold_heart+=/chains_of_ice,if=buff.cold_heart_item.stack>=17&buff.unholy_strength.react&buff.unholy_strength.remains<gcd&cooldown.pillar_of_frost.remains>6
--actions.cold_heart+=/chains_of_ice,if=buff.cold_heart_item.stack>=4&target.time_to_die<=gcd

--actions.cooldowns=arcane_torrent,if=runic_power.deficit>=20&!talent.breath_of_sindragosa.enabled
--actions.cooldowns+=/arcane_torrent,if=dot.breath_of_sindragosa.ticking&runic_power.deficit>=50&rune<2
--actions.cooldowns+=/blood_fury,if=buff.pillar_of_frost.up
--actions.cooldowns+=/berserking,if=buff.pillar_of_frost.up
--actions.cooldowns+=/use_items
--actions.cooldowns+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--actions.cooldowns+=/use_item,name=horn_of_valor,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
--actions.cooldowns+=/use_item,name=draught_of_souls,if=rune.time_to_5<3&(!dot.breath_of_sindragosa.ticking|runic_power>60)
--actions.cooldowns+=/potion,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|dot.breath_of_sindragosa.ticking)
--# Pillar of frost conditions
--actions.cooldowns+=/pillar_of_frost,if=!talent.breath_of_sindragosa.enabled
--actions.cooldowns+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.ready&runic_power>50
--actions.cooldowns+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains>40
--actions.cooldowns+=/breath_of_sindragosa,if=buff.pillar_of_frost.up
--actions.cooldowns+=/call_action_list,name=cold_heart,if=equipped.cold_heart&((buff.cold_heart_item.stack>=10&debuff.razorice.stack=5)|target.time_to_die<=gcd)
--# Obliteration rotation
--actions.obliteration=remorseless_winter,if=talent.gathering_storm.enabled
--actions.obliteration+=/frostscythe,if=(buff.killing_machine.up&(buff.killing_machine.react|prev_gcd.1.frost_strike|prev_gcd.1.howling_blast))&spell_targets.frostscythe>1
--actions.obliteration+=/obliterate,if=(buff.killing_machine.up&(buff.killing_machine.react|prev_gcd.1.frost_strike|prev_gcd.1.howling_blast))|(spell_targets.howling_blast>=3&!buff.rime.up&!talent.frostscythe.enabled)
--actions.obliteration+=/howling_blast,if=buff.rime.up&spell_targets.howling_blast>1
--actions.obliteration+=/frost_strike,if=!buff.rime.up|rune.time_to_1>=gcd|runic_power.deficit<20
--actions.obliteration+=/howling_blast,if=buff.rime.up
--actions.obliteration+=/obliterate
--# Standard rotation
--actions.standard=frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<=gcd
--actions.standard+=/remorseless_winter,if=(buff.rime.up&equipped.perseverance_of_the_ebon_martyr)|talent.gathering_storm.enabled
--actions.standard+=/obliterate,if=(equipped.koltiras_newfound_will&talent.frozen_pulse.enabled&set_bonus.tier19_2pc=1)|rune.time_to_4<gcd
--actions.standard+=/frost_strike,if=runic_power.deficit<10
--actions.standard+=/howling_blast,if=buff.rime.up
--actions.standard+=/obliterate,if=(equipped.koltiras_newfound_will&talent.frozen_pulse.enabled&set_bonus.tier19_2pc=1)|rune.time_to_5<gcd
--actions.standard+=/frost_strike,if=runic_power.deficit<10
--actions.standard+=/frostscythe,if=buff.killing_machine.react&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
--actions.standard+=/obliterate,if=buff.killing_machine.react
--actions.standard+=/frost_strike,if=runic_power.deficit<20
--actions.standard+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
--actions.standard+=/glacial_advance,if=spell_targets.glacial_advance>=2
--actions.standard+=/frostscythe,if=spell_targets.frostscythe>=3
--actions.standard+=/obliterate,if=!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>(gcd*2)
--actions.standard+=/horn_of_winter,if=rune.time_to_2>gcd|!talent.frozen_pulse.enabled
--actions.standard+=/frost_strike
--actions.standard+=/obliterate,if=!talent.gathering_storm.enabled|talent.icy_talons.enabled
--actions.standard+=/empower_rune_weapon,if=!talent.breath_of_sindragosa.enabled|target.time_to_die<cooldown.breath_of_sindragosa.remains

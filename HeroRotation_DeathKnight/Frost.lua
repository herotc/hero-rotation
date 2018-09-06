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


--- ======================== CUSTOM BUTTONS =========================
  if not HR.CustomButtons then HR.CustomButtons = {}; end
  HR.CustomButtons[251] = {
    [1] = {"P", "Start pooling resources for Breath of Sindragosa"},
    [2] = {"B", "Use Breath of Sindragosa" }
  };
  local PoolBreathofSindragosa = HR.Custom1;
  local UseBreathofSindragosa = function() return HR.Custom2() and HR.Custom1(); end

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
    GatheringStorm                = Spell(194912),
    GatheringStormBuff            = Spell(211805),
    GlacialAdvance                = Spell(194913),
    HornOfWinter                  = Spell(57330),
    IcyTalons                     = Spell(194878),
    IcyTalonsBuff                 = Spell(194879),
    MurderousEfficiency           = Spell(207061),
    Obliteration                  = Spell(281238),
    RunicAttenuation              = Spell(207104),
    Icecap                        = Spell(207126),
    ColdHeart                     = Spell(281208),
    ColdHeartBuff                 = Spell(281209),
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
  local function DeathStrikeHeal()
    return (Settings.General.SoloMode and Player:HealthPercentage() < Settings.DeathKnight.Commons.UseDeathStrikeHP) and true or false;
  end

  local function Standard()
    -- howling_blast,if=!dot.frost_fever.ticking&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.HowlingBlast:IsCastableP(30, true) and (not Target:DebuffP(S.FrostFever) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if not DeathStrikeHeal() and S.GlacialAdvance:IsCastableP() and (Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and Cache.EnemiesCount[30] >= 2 and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and (Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and (S.RemorselessWinter:CooldownRemainsP() <= (2 * Player:GCD()) and S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse.enabled
    if S.Obliterate:IsCastableP("Melee") and Player:Runes() > 3 and S.FrozenPulse:IsAvailable() then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and (Player:RunicPowerDeficit() < (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&rune.time_to_4>=gcd
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and (Player:BuffP(S.KillingMachine) and Player:RuneTimeToX(4) >= Player:GCD()) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() > (25 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frost_strike
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- horn_of_winter
    if S.HornOfWinter:IsCastableP() then
      if HR.Cast(S.HornOfWinter) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.DeathKnight.Frost.GCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    return false;
  end

  local function AOE()
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- glacial_advance,if=talent.frostscythe.enabled
    if S.GlacialAdvance:IsCastableP() and (S.FrostScythe:IsAvailable()) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and (S.RemorselessWinter:CooldownRemainsP() <= 2 * Player:GCD() and S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and (Player:BuffP(S.KillingMachine)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- glacial_advance,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if S.GlacialAdvance:IsCastableP() and (Player:RunicPowerDeficit() < (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and (Player:RunicPowerDeficit() < (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- remorseless_winter
    if S.RemorselessWinter:IsCastableP() then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- frostscythe
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() > (25 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance
    if S.GlacialAdvance:IsCastableP() then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- horn_of_winter
    if S.HornOfWinter:IsCastableP() then
      if HR.Cast(S.HornOfWinter) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.DeathKnight.Frost.GCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    return false;
  end

  local function BoS_Pooling()
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and Player:Buff(S.Rime) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=rune.time_to_4<gcd&runic_power.deficit>=25
    if S.Obliterate:IsCastableP("Melee") and (Player:RuneTimeToX(4) < Player:GCD() and Player:RunicPowerDeficit() >= 25) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>rune.time_to_4
    if S.GlacialAdvance:IsCastableP() and (Player:RunicPowerDeficit() < 20 and S.PillarOfFrost:CooldownRemainsP() > Player:RuneTimeToX(4)) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up&runic_power.deficit>(15+talent.runic_attenuation.enabled*3)
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and (Player:Buff(S.KillingMachine) and Player:RunicPowerDeficit() > (15 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=runic_power.deficit>=(25+talent.runic_attenuation.enabled*3)
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() >= (25 + (S.RunicAttenuation:IsAvailable() and 1 or 0) * 3)) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastableP() and (S.PillarOfFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40 and Cache.EnemiesCount[30] >= 2) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and (S.PillarOfFrost:CooldownRemainsP() > Player:RuneTimeToX(4) and Player:RunicPowerDeficit() < 40) then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    return false;
  end

  local function BoS_Ticking()
    -- obliterate,if=runic_power<=30
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPower() <= 30) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- obliterate,if=rune.time_to_5<gcd|runic_power<=45
    if S.Obliterate:IsCastableP("Melee") and (Player:RuneTimeToX(5) < Player:GCD() or Player:RunicPower() <= 45) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frostscythe,if=buff.killing_machine.up
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and (Player:BuffP(S.KillingMachine)) then
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
    if S.Obliterate:IsCastableP("Melee") and (Player:RunicPowerDeficit() > 25 or Player:Runes() > 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- arcane_torrent,if=runic_power.deficit>20
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Player:RunicPowerDeficit() > 20) then
      if HR.Cast(S.ArcaneTorrent, Settings.DeathKnight.Frost.GCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    return false;
  end

  local function Obliteration()
    -- remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastableP() and (S.GatheringStorm:IsAvailable()) then
      if HR.Cast(S.RemorselessWinter) then return ""; end
    end
    -- obliterate,if=!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
    if S.Obliterate:IsCastableP("Melee") and (not S.FrostScythe:IsAvailable() and not Player:Buff(S.Rime) and Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- frostscythe,if=(buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance)))&(rune.time_to_4>gcd|spell_targets.frostscythe>=2)
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 1 and ((Player:BuffP(S.KillingMachine) or (Player:BuffP(S.KillingMachine) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance)))) and (Player:RuneTimeToX(4) > Player:GCD() or Cache.EnemiesCount[8] >= 2)) then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate,if=buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
    if S.Obliterate:IsCastableP("Melee") and Player:BuffP(S.KillingMachine) or (Player:BuffP(S.KillingMachine) and (Player:PrevGCDP(1, S.FrostStrike) or Player:PrevGCDP(1, S.HowlingBlast) or Player:PrevGCDP(1, S.GlacialAdvance))) then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    -- glacial_advance,if=(!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd)&spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastableP() and ((not Player:Buff(S.Rime) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD()) and Cache.EnemiesCount[30] >= 2) then
      if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- howling_blast,if=buff.rime.up&spell_targets.howling_blast>=2
    if S.HowlingBlast:IsCastableP(30, true) and (Player:Buff(S.Rime) and Cache.EnemiesCount[10] >= 2) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frost_strike,if=!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and not Player:Buff(S.Rime) or Player:RunicPowerDeficit() < 10 or Player:RuneTimeToX(2) > Player:GCD() then
      if HR.Cast(S.FrostStrike) then return ""; end
    end
    -- howling_blast,if=buff.rime.up
    if S.HowlingBlast:IsCastableP(30, true) and (Player:Buff(S.Rime)) then
      if HR.Cast(S.HowlingBlast) then return ""; end
    end
    -- frostscythe, if=spell_targets.frostscythe>=2
    if S.FrostScythe:IsCastableP() and Cache.EnemiesCount[8] >= 2 then
      if HR.Cast(S.FrostScythe) then return ""; end
    end
    -- obliterate
    if S.Obliterate:IsCastableP("Melee") then
      if HR.Cast(S.Obliterate) then return ""; end
    end
    return false;
  end

  local function Cooldowns()
      -- actions.cooldowns=use_items
      -- actions.cooldowns+=/use_item,name=horn_of_valor,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
      -- actions.cooldowns+=/potion,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
      if Settings.DeathKnight.Commons.UsePotions and I.ProlongedPower:IsReady() and Player:Buff(S.PillarOfFrost) and Player:Buff(S.EmpowerRuneWeapon) then
        if HR.CastLeft(I.ProlongedPower) then return ""; end
      end
      -- actions.cooldowns+=/blood_fury,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
      -- actions.cooldowns+=/berserking,if=buff.pillar_of_frost.up
      -- # Frost cooldowns
      -- actions.cooldowns+=/pillar_of_frost,if=cooldown.empower_rune_weapon.remains
      if S.PillarOfFrost:IsCastableP() and S.EmpowerRuneWeapon:CooldownDown() then
        if HR.Cast(S.PillarOfFrost, Settings.DeathKnight.Frost.GCDasOffGCD.PillarOfFrost) then return ""; end
      end
      -- actions.cooldowns+=/empower_rune_weapon,if=cooldown.pillar_of_frost.ready&!talent.breath_of_sindragosa.enabled&rune.time_to_5>gcd&runic_power.deficit>=10
      if S.EmpowerRuneWeapon:IsCastable() and S.PillarOfFrost:CooldownUp() and not S.BreathofSindragosa:IsAvailable() and Player:RuneTimeToX(5) < Player:GCD() and Player:RunicPowerDeficit() >= 40 then
        if HR.Cast(S.EmpowerRuneWeapon, Settings.DeathKnight.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return ""; end
      end
      -- actions.cooldowns+=/empower_rune_weapon,if=cooldown.pillar_of_frost.ready&talent.breath_of_sindragosa.enabled&rune>=3&runic_power>60
      if UseBreathofSindragosa() and S.EmpowerRuneWeapon:IsCastable() and S.PillarOfFrost:CooldownUp() and S.BreathofSindragosa:IsAvailable() and Player:Runes() >= 3 and Player:RunicPower() > 60 then
        if HR.Cast(S.EmpowerRuneWeapon, Settings.DeathKnight.Frost.GCDasOffGCD.EmpowerRuneWeapon) then return ""; end
      end
      --actions.cooldowns+=/call_action_list,name=cold_heart,if=talent.cold_heart.enabled&((buff.cold_heart.stack>=10&debuff.razorice.stack=5)|target.time_to_die<=gcd)
      if S.ColdHeart:IsAvailable() and ((Player:BuffStack(S.ColdHeartBuff) >= 10 and Target:DebuffStack(S.RazorIce) == 5) or Target:TimeToDie() <= Player:GCD()) then
          --[[COLD HEART LEGENDARY APL]] --
          -- actions.cold_heart=chains_of_ice,if=buff.cold_heart.stack>5&target.time_to_die<gcd
          if S.ChainsOfIce:IsCastableP(30) and Player:BuffStack(S.ColdHeartBuff) > 5 and Target:TimeToDie() < Player:GCD() then
            if HR.Cast(S.ChainsOfIce) then return ""; end
          end
          -- actions.cold_heart+=/chains_of_ice,if=(buff.pillar_of_frost.remains<=gcd*(1+cooldown.frostwyrms_fury.ready)|buff.pillar_of_frost.remains<rune.time_to_3)&buff.pillar_of_frost.up
          if S.ChainsOfIce:IsCastableP(30) and (Player:BuffRemainsP(S.PillarOfFrost) <= Player:GCD() * (1 + (S.FrostwyrmsFury:CooldownUp() and 1 or 0)) or Player:BuffRemainsP(S.PillarOfFrost) < Player:RuneTimeToX(3)) and Player:BuffP(S.PillarOfFrost) then
            if HR.Cast(S.ChainsOfIce) then return ""; end
          end
            --[[END OF COLD HEART APL]] --
        end
        -- actions.cooldowns+=/frostwyrms_fury,if=(buff.pillar_of_frost.remains<=gcd&buff.pillar_of_frost.up)
        if S.FrostwyrmsFury:IsCastable() and Player:BuffRemains(S.PillarOfFrost) <= Player:GCD() * 2 and Player:Buff(S.PillarOfFrost) then
            if HR.Cast(S.FrostwyrmsFury, Settings.DeathKnight.Frost.GCDasOffGCD.FrostwyrmsFury) then return ""; end
        end

      return false;
    end
--- ======= MAIN =======
local function APL ()
    -- Unit Update
    HL.GetEnemies("Melee");
    HL.GetEnemies(8,true);  -- Frostscythe 8yd
    HL.GetEnemies(10,true); -- Howling Blast 10yd
    HL.GetEnemies(30,true); -- Glacial Advance 30yd
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
  if Everyone.TargetIsValid() then
    -- heal DK in SoloMode
    if DeathStrikeHeal() and S.DeathStrike:IsReady("Melee") then
        if HR.Cast(S.DeathStrike) then return ""; end
    end
    --actions+=/howling_blast,if=!dot.frost_fever.ticking&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.HowlingBlast:IsCastable(30, true) and not Target:Debuff(S.FrostFever) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15) then
        if HR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions+=/glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if S.GlacialAdvance:IsCastableP() and Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and (Cache.EnemiesCount[10] >= 2) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15) then
        if HR.Cast(S.GlacialAdvance) then return ""; end
    end
    -- frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<=gcd
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and S.IcyTalons:IsAvailable() and Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() then
        if HR.Cast(S.FrostStrike) then return ""; end
    end
    --actions+=/frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
    if not DeathStrikeHeal() and S.FrostStrike:IsReady(13) and Player:BuffRemainsP(S.IcyTalonsBuff) <= Player:GCD() and Player:BuffP(S.IcyTalonsBuff) and (not S.BreathofSindragosa:IsAvailable() or S.BreathofSindragosa:CooldownRemainsP() > 15) then
        if HR.Cast(S.FrostStrike) then return ""; end
    end
    --actions+=/breath_of_sindragosa,if=cooldown.empower_rune_weapon.remains&cooldown.pillar_of_frost.remains
    if UseBreathofSindragosa() and S.BreathofSindragosa:IsCastable() and S.EmpowerRuneWeapon:CooldownRemainsP() > 0 and S.PillarOfFrost:CooldownRemainsP() > 0 then
        if HR.Cast(S.BreathofSindragosa, Settings.DeathKnight.Frost.GCDasOffGCD.BreathofSindragosa) then return ""; end
    end
  end
    --actions+=/call_action_list,name=cooldowns
    if HR.CDsON() then
    ShouldReturn = Cooldowns();
    if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<5
    if PoolBreathofSindragosa() and S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemainsP() < 5 then
        ShouldReturn = BoS_Pooling();
        if ShouldReturn then return ShouldReturn; end
        if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Pooling"; end
    end
    --actions+=/run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
    if Player:Buff(S.BreathofSindragosa) then
        ShouldReturn = BoS_Ticking();
        if ShouldReturn then return ShouldReturn; end
        if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait Resources BoS Ticking"; end
    end
    --actions+=/run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration.enabled
    if (Player:BuffP(S.PillarOfFrost) and S.Obliteration:IsAvailable()) then
        ShouldReturn = Obliteration();
        if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/run_action_list,name=aoe,if=active_enemies>=2
    if HR.AoEON() and Cache.EnemiesCount[10] >= 2 then
      ShouldReturn = AOE();
      if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/call_action_list,name=standard
    ShouldReturn = Standard();
    if ShouldReturn then return ShouldReturn; end

    if HR.CastAnnotated(S.PoolRange, false, "WAIT") then return "Wait/Pool Resources"; end

    return;
  end

  HR.SetAPL(251, APL);
--- ====18/07/2018======
--- ======= SIMC =======
-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/mind_freeze
-- # Apply Frost Fever and maintain Icy Talons
-- actions+=/howling_blast,if=!dot.frost_fever.ticking&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
-- actions+=/glacial_advance,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&spell_targets.glacial_advance>=2&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
-- actions+=/frost_strike,if=buff.icy_talons.remains<=gcd&buff.icy_talons.up&(!talent.breath_of_sindragosa.enabled|cooldown.breath_of_sindragosa.remains>15)
-- actions+=/breath_of_sindragosa,if=cooldown.empower_rune_weapon.remains&cooldown.pillar_of_frost.remains
-- actions+=/call_action_list,name=cooldowns
-- actions+=/run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<5
-- actions+=/run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
-- actions+=/run_action_list,name=obliteration,if=buff.pillar_of_frost.up&talent.obliteration.enabled
-- actions+=/run_action_list,name=aoe,if=active_enemies>=2
-- actions+=/call_action_list,name=standard
--
-- actions.aoe=remorseless_winter,if=talent.gathering_storm.enabled
-- actions.aoe+=/glacial_advance,if=talent.frostscythe.enabled
-- actions.aoe+=/frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
-- actions.aoe+=/howling_blast,if=buff.rime.up
-- actions.aoe+=/frostscythe,if=buff.killing_machine.up
-- actions.aoe+=/glacial_advance,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
-- actions.aoe+=/frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
-- actions.aoe+=/remorseless_winter
-- actions.aoe+=/frostscythe
-- actions.aoe+=/obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
-- actions.aoe+=/glacial_advance
-- actions.aoe+=/frost_strike
-- actions.aoe+=/horn_of_winter
-- actions.aoe+=/arcane_torrent
--
-- # Breath of Sindragosa pooling rotation : starts 15s before the cd becomes available
-- actions.bos_pooling=howling_blast,if=buff.rime.up
-- actions.bos_pooling+=/obliterate,if=rune.time_to_4<gcd&runic_power.deficit>=25
-- actions.bos_pooling+=/glacial_advance,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>rune.time_to_4
-- actions.bos_pooling+=/frost_strike,if=runic_power.deficit<20&cooldown.pillar_of_frost.remains>rune.time_to_4
-- actions.bos_pooling+=/frostscythe,if=buff.killing_machine.up&runic_power.deficit>(15+talent.runic_attenuation.enabled*3)
-- actions.bos_pooling+=/obliterate,if=runic_power.deficit>=(25+talent.runic_attenuation.enabled*3)
-- actions.bos_pooling+=/glacial_advance,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40&spell_targets.glacial_advance>=2
-- actions.bos_pooling+=/frost_strike,if=cooldown.pillar_of_frost.remains>rune.time_to_4&runic_power.deficit<40
--
-- actions.bos_ticking=obliterate,if=runic_power<=30
-- actions.bos_ticking+=/remorseless_winter,if=talent.gathering_storm.enabled
-- actions.bos_ticking+=/howling_blast,if=buff.rime.up
-- actions.bos_ticking+=/obliterate,if=rune.time_to_5<gcd|runic_power<=45
-- actions.bos_ticking+=/frostscythe,if=buff.killing_machine.up
-- actions.bos_ticking+=/horn_of_winter,if=runic_power.deficit>=30&rune.time_to_3>gcd
-- actions.bos_ticking+=/remorseless_winter
-- actions.bos_ticking+=/frostscythe,if=spell_targets.frostscythe>=2
-- actions.bos_ticking+=/obliterate,if=runic_power.deficit>25|rune>3
-- actions.bos_ticking+=/arcane_torrent,if=runic_power.deficit>20
--
-- # Cold heart conditions
-- actions.cold_heart=chains_of_ice,if=(buff.cold_heart_item.stack>5|buff.cold_heart_talent.stack>5)&target.time_to_die<gcd
-- actions.cold_heart+=/chains_of_ice,if=(buff.pillar_of_frost.remains<=gcd*(1+cooldown.frostwyrms_fury.ready)|buff.pillar_of_frost.remains<rune.time_to_3)&buff.pillar_of_frost.up
--
-- actions.cooldowns=use_items
-- actions.cooldowns+=/use_item,name=horn_of_valor,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
-- actions.cooldowns+=/potion,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
-- actions.cooldowns+=/blood_fury,if=buff.pillar_of_frost.up&buff.empower_rune_weapon.up
-- actions.cooldowns+=/berserking,if=buff.pillar_of_frost.up
-- # Frost cooldowns
-- actions.cooldowns+=/pillar_of_frost,if=cooldown.empower_rune_weapon.remains
-- actions.cooldowns+=/empower_rune_weapon,if=cooldown.pillar_of_frost.ready&!talent.breath_of_sindragosa.enabled&rune.time_to_5>gcd&runic_power.deficit>=10
-- actions.cooldowns+=/empower_rune_weapon,if=cooldown.pillar_of_frost.ready&talent.breath_of_sindragosa.enabled&rune>=3&runic_power>60
-- actions.cooldowns+=/call_action_list,name=cold_heart,if=(equipped.cold_heart|talent.cold_heart.enabled)&(((buff.cold_heart_item.stack>=10|buff.cold_heart_talent.stack>=10)&debuff.razorice.stack=5)|target.time_to_die<=gcd)
-- actions.cooldowns+=/frostwyrms_fury,if=(buff.pillar_of_frost.remains<=gcd&buff.pillar_of_frost.up)
--
-- # Obliteration rotation
-- actions.obliteration=remorseless_winter,if=talent.gathering_storm.enabled
-- actions.obliteration+=/obliterate,if=!talent.frostscythe.enabled&!buff.rime.up&spell_targets.howling_blast>=3
-- actions.obliteration+=/frostscythe,if=(buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance)))&(rune.time_to_4>gcd|spell_targets.frostscythe>=2)
-- actions.obliteration+=/obliterate,if=buff.killing_machine.react|(buff.killing_machine.up&(prev_gcd.1.frost_strike|prev_gcd.1.howling_blast|prev_gcd.1.glacial_advance))
-- actions.obliteration+=/glacial_advance,if=(!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd)&spell_targets.glacial_advance>=2
-- actions.obliteration+=/howling_blast,if=buff.rime.up&spell_targets.howling_blast>=2
-- actions.obliteration+=/frost_strike,if=!buff.rime.up|runic_power.deficit<10|rune.time_to_2>gcd
-- actions.obliteration+=/howling_blast,if=buff.rime.up
-- actions.obliteration+=/frostscythe,if=spell_targets.frostscythe>=2
-- actions.obliteration+=/obliterate
--
-- actions.standard=remorseless_winter
-- actions.standard+=/frost_strike,if=cooldown.remorseless_winter.remains<=2*gcd&talent.gathering_storm.enabled
-- actions.standard+=/howling_blast,if=buff.rime.up
-- actions.standard+=/obliterate,if=!buff.frozen_pulse.up&talent.frozen_pulse.enabled
-- actions.standard+=/frost_strike,if=runic_power.deficit<(15+talent.runic_attenuation.enabled*3)
-- actions.standard+=/frostscythe,if=buff.killing_machine.up&rune.time_to_4>=gcd
-- actions.standard+=/obliterate,if=runic_power.deficit>(25+talent.runic_attenuation.enabled*3)
-- actions.standard+=/frost_strike
-- actions.standard+=/horn_of_winter
-- actions.standard+=/arcane_torrent
--

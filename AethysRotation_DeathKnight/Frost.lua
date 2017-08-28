--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local DeathKnight = AR.Commons.DeathKnight;
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
    HungeringRuneWeapon           = Spell(207127),
    IcyTalons                     = Spell(194878),
    IcyTalonsBuff                 = Spell(194879),
    MurderousEfficiency           = Spell(207061),
    Obliteration                  = Spell(207256),
    RunicAttenuation              = Spell(207104),
    ShatteringStrikes             = Spell(207057),
    Icecap                        = Spell(207126),
    -- Artifact
    SindragosasFury               = Spell(190778),
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
        -- Legendaries
    ChilledHearth                 = Spell(235599),
    ConsortsColdCore              = Spell(235605),
    KiljaedensBurningWish         = Spell(144259),
    KoltirasNewfoundWill          = Spell(208782),
    PerseveranceOfTheEbonMartyre  = Spell(216059),
    SealOfNecrofantasia           = Spell(212216),
    ToravonsWhiteoutBindings      = Spell(205628)
           
    -- Misc
    
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
    PerseveranceOfTheEbonMartyre  = Item(132459, {1}),
    SealOfNecrofantasia           = Item(137223, {11, 12}),
    ToravonsWhiteoutBindings      = Item(132458, {9}),
    --Trinkets
    FelOiledInfernalMachine       = Item(144482, {13, 14}),
    --Potion
    ProlongedPower                = Item(142117)
    
  };
  local I = Item.DeathKnight.Frost;
  -- Rotation Var
  local T192P,T194P = AC.HasTier("T19")
  local T202P,T204P = AC.HasTier("T20")
  local T212P,T214P = AC.HasTier("T21")

  if S.Obliteration:IsAvailable() or S.HungeringRuneWeapon:IsAvailable () then
  AR.Print("|cffff0000Frost DeathKnight 7.3|r - |cFF00FF96Hungering Rune Weapon and Obliteration APL's are on BETA|r - Please report any bugs or optimizations on GitHub or Discord.");
  end
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    DeathKnight = AR.GUISettings.APL.DeathKnight

  };

--- ======= ACTION LISTS =======
  local function Standard()
    --actions.standard=/frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<=gcd
    if S.FrostStrike:IsUsable() and S.IcyTalons:IsAvailable() and Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.standard+=/frost_strike,if=talent.shattering_strikes.enabled&debuff.razorice.stack=5&buff.gathering_storm.stack<2&!buff.rime.up
    if S.FrostStrike:IsUsable() and S.ShatteringStrikes:IsAvailable() and Target:DebuffStack(S.RazorIce) == 5 and Player:BuffStack(S.GatheringStormBuff) < 2 and not Player:Buff(S.Rime) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.standard+=/remorseless_winter,if=(buff.rime.react&equipped.perseverance_of_the_ebon_martyr)|talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastable() and (Player:Buff(S.Rime) and I.PerseveranceOfTheEbonMartyre:IsEquipped() or S.GatheringStorm:IsAvailable()) then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.standard+=/howling_blast,if=buff.rime.react
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.standard+=/obliterate,if=(equipped.koltiras_newfound_will&talent.frozen_pulse.enabled&set_bonus.tier19_2pc=1)|rune.time_to_5<gcd
    if S.Obliterate:IsCastable() and (I.KoltirasNewfoundWill:IsEquipped() and S.FrozenPulse:IsAvailable() and T192P) or Player:RuneTimeToX(5) < Player:GCD() then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.standard+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5
    if S.SindragosasFury:IsCastable() and (I.ConsortsColdCore:IsEquipped() or Player:Buff(S.PillarOfFrost)) and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.RazorIce) == 5 then
      if AR.Cast(S.SindragosasFury) then return ""; end
    end
    --actions.standard+=/hungering_rune_weapon,if=!buff.hungering_rune_weapon.up&rune.time_to_3>gcd*2&runic_power<25&rune<2
    if S.HungeringRuneWeapon:IsCastable() and not Player:Buff(S.HungeringRuneWeapon) and Player:RuneTimeToX(3) > Player:GCD() * 2 and Player:RunicPower() < 25 and Player:Runes() < 2 then
      if AR.Cast(S.HungeringRuneWeapon, Settings.DeathKnight.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return ""; end
    end
    --actions.standard+=/frost_strike,if=runic_power>=90
    if S.FrostStrike:IsUsable() and Player:RunicPower() >= 90 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.standard+=/frostscythe,if=buff.killing_machine.up&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
    if S.FrostScythe:IsCastable() and Player:Buff(S.KillingMachine) and (not I.KoltirasNewfoundWill:IsEquipped() or Cache.EnemiesCount[8] >= 2) then
      if AR.Cast(S.FrostScythe) then return ""; end
    end
    --actions.standard+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
    if S.RemorselessWinter:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.standard+=/glacial_advance,if=spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.GlacialAdvance) then return ""; end
    end
    --actions.standard+=/frostscythe,if=spell_targets.frostscythe>=3
    if S.FrostScythe:IsCastable() and Cache.EnemiesCount[8] >= 3 then
      if AR.Cast(S.FrostScythe) then return ""; end
    end
    --actions.standard+=/obliterate,if=buff.killing_machine.react
    if S.Obliterate:IsCastable() and Player:Buff(S.KillingMachine) then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.standard+=/frost_strike,if=runic_power>=80
    if S.FrostStrike:IsUsable() and Player:RunicPower() >= 80 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.standard+=/obliterate
    if S.Obliterate:IsCastable() then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.standard+=/horn_of_winter,if=!buff.hungering_rune_weapon.up&(rune.time_to_2>gcd|!talent.frozen_pulse.enabled)
    if S.HornOfWinter:IsCastable() and not Player:Buff(S.HungeringRuneWeapon) and (Player:RuneTimeToX(2) > Player:GCD() or not S.FrozenPulse:IsAvailable()) then
      if AR.Cast(S.HornOfWinter, Settings.DeathKnight.Frost.OffGCDasOffGCD.HornOfWinter) then return ""; end
    end
    --actions.standard+=/frost_strike,if=!(runic_power<50&talent.obliteration.enabled&cooldown.obliteration.remains<=gcd)
    if S.FrostStrike:IsUsable() and not (Player:RunicPower() < 50 and S.Obliteration:IsAvailable() and S.Obliteration:CooldownRemains() <= Player:GCD())  then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.standard+=/empower_rune_weapon,if=!talent.breath_of_sindragosa.enabled|target.time_to_die<cooldown.breath_of_sindragosa.remains
    if S.EmpowerRuneWeapon:IsCastable() and not S.BreathofSindragosa:IsAvailable() or Target:TimeToDie() < S.BreathofSindragosa:CooldownRemains() then
      if AR.Cast(S.EmpowerRuneWeapon, Settings.DeathKnight.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end
    return false;
  end

  local function BoS_Pooling()
    --actions.bos_pooling=remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastable() and S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.bos_pooling+=/howling_blast,if=buff.rime.react&rune.time_to_4<(gcd*2)
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and Player:RuneTimeToX(4) < (Player:GCD()*2) then 
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.bos_pooling+=/obliterate,if=rune.time_to_6<gcd&!talent.gathering_storm.enabled
    if S.Obliterate:IsCastable() and Player:RuneTimeToX(6) < Player:GCD() and not S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.bos_pooling+=/obliterate,if=rune.time_to_4<gcd&(cooldown.breath_of_sindragosa.remains|runic_power<70)
    if S.Obliterate:IsCastable() and Player:RuneTimeToX(4) < Player:GCD() and (S.BreathofSindragosa:CooldownRemains() or Player:RunicPower() < 70) then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.bos_pooling+=/frost_strike,if=runic_power>=95&set_bonus.tier19_4pc&cooldown.breath_of_sindragosa.remains&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
    if S.FrostStrike:IsUsable() and Player:RunicPower() >= 95 and T194P and S.BreathofSindragosa:CooldownRemains() and ( not S.ShatteringStrikes:IsAvailable() or Target:DebuffStack(S.RazorIce) < 5 or S.BreathofSindragosa:CooldownRemains() > 6) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.bos_pooling+=/remorseless_winter,if=buff.rime.react&equipped.perseverance_of_the_ebon_martyr
    if S.RemorselessWinter:IsCastable() and Player:Buff(S.Rime) and I.PerseveranceOfTheEbonMartyre:IsEquipped() then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.bos_pooling+=/howling_blast,if=buff.rime.react&(buff.remorseless_winter.up|cooldown.remorseless_winter.remains>gcd|(!equipped.perseverance_of_the_ebon_martyr&!talent.gathering_storm.enabled))
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and (Player:Buff(S.RemorselessWinter) or S.RemorselessWinter:CooldownRemains() > Player:GCD() or (not I.PerseveranceOfTheEbonMartyre:IsEquipped() and not S.GatheringStorm:IsAvailable())) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.bos_pooling+=/obliterate,if=!buff.rime.react&!(talent.gathering_storm.enabled&!(cooldown.remorseless_winter.remains>(gcd*2)|rune>4))&rune>3
    if S.Obliterate:IsCastable() and not Player:Buff(S.Rime) and not (S.GatheringStorm:IsAvailable() and not (S.RemorselessWinter:CooldownRemains() > (Player:GCD()*2) or Player:Runes() > 4)) and Player:Runes() > 3 then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.bos_pooling+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5&!buff.obliteration.up
    if S.SindragosasFury:IsCastable() and (I.ConsortsColdCore:IsEquipped() or Player:Buff(S.PillarOfFrost)) and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.RazorIce) ==5 and not Player:Buff(Obliteration) then
      if AR.Cast(S.SindragosasFury) then return ""; end
    end
    --actions.bos_pooling+=/frost_strike,if=runic_power>=70&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>rune.time_to_4)
    if S.FrostStrike:IsUsable() and Player:RunicPower() >= 70 and (not S.ShatteringStrikes:IsAvailable() or Target:DebuffStack(S.RazorIce) < 5 or S.BreathofSindragosa:CooldownRemains() > Player:RuneTimeToX(4)) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.bos_pooling+=/frostscythe,if=buff.killing_machine.up&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
    if S.FrostScythe:IsCastable() and Player:Buff(S.KillingMachine) and (not I.KoltirasNewfoundWill:IsEquipped() or Cache.EnemiesCount[8] >= 2) then
      if AR.Cast(S.FrostScythe) then return ""; end
    end
    --actions.bos_pooling+=/glacial_advance,if=spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.GlacialAdvance) then return ""; end
    end
    --actions.bos_pooling+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
    if S.RemorselessWinter:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.bos_pooling+=/frostscythe,if=spell_targets.frostscythe>=3
    if S.FrostScythe:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.FrostScythe) then return ""; end
    end
    --actions.bos_pooling+=/frost_strike,if=(cooldown.remorseless_winter.remains<(gcd*2)|buff.gathering_storm.stack=10)&cooldown.breath_of_sindragosa.remains>rune.time_to_4&talent.gathering_storm.enabled&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
    if S.FrostStrike:IsUsable() and (S.RemorselessWinter:CooldownRemains() < (Player:GCD()*2) or Player:BuffStack(S.GatheringStormBuff) == 10) and S.BreathofSindragosa:CooldownRemains() > Player:RuneTimeToX(4) and S.GatheringStorm:IsAvailable() and (not S.ShatteringStrikes:IsAvailable() or Target:DebuffStack(S.RazorIce) < 5 or S.BreathofSindragosa:CooldownRemains() > 6) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.bos_pooling+=/obliterate,if=!buff.rime.react&(!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>gcd)
    if S.Obliterate:IsCastable() and not Player:Buff(S.Rime) and (not S.GatheringStorm:IsAvailable() or S.RemorselessWinter:CooldownRemains() > Player:GCD()) then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.bos_pooling+=/frost_strike,if=cooldown.breath_of_sindragosa.remains>rune.time_to_4&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
    if S.FrostStrike:IsUsable() and S.BreathofSindragosa:CooldownRemains() > Player:RuneTimeToX(4) and (not S.ShatteringStrikes:IsAvailable() or Target:DebuffStack(S.RazorIce) < 5 or S.BreathofSindragosa:CooldownRemains() > 6) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    return false;
  end

  local function BoS_Ticking()
    --actions.bos_ticking=frost_strike,if=talent.shattering_strikes.enabled&runic_power<40&rune.time_to_2>2&cooldown.empower_rune_weapon.remains&debuff.razorice.stack=5&(cooldown.horn_of_winter.remains|!talent.horn_of_winter.enabled)
    if S.FrostStrike:IsUsable() and S.ShatteringStrikes:IsAvailable() and Player:RunicPower() < 40 and Player:RuneTimeToX(2) > 2 and S.EmpowerRuneWeapon:CooldownRemains() and Target:DebuffStack(S.RazorIce) == 5 and (S.HornOfWinter:CooldownRemains() or not S.HornOfWinter:IsAvailable()) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.bos_ticking+=/remorseless_winter,if=(runic_power>=30|buff.hungering_rune_weapon.up)&((buff.rime.react&equipped.perseverance_of_the_ebon_martyr)|(talent.gathering_storm.enabled&(buff.remorseless_winter.remains<=gcd|!buff.remorseless_winter.remains)))
    if S.RemorselessWinter:IsCastable() and (Player:RunicPower() >= 30 or Player:Buff(S.HungeringRuneWeapon)) and ((Player:Buff(S.Rime) and I.PerseveranceOfTheEbonMartyre:IsEquipped()) or (S.GatheringStorm:IsAvailable() and (Player:BuffRemains(S.RemorselessWinter) <= Player:GCD() or not Player:BuffRemains(S.RemorselessWinter)))) then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.bos_ticking+=/howling_blast,if=((runic_power>=20&set_bonus.tier19_4pc)|runic_power>=30|buff.hungering_rune_weapon.up)&buff.rime.react
    if S.HowlingBlast:IsCastable() and ((Player:RunicPower() >= 20 and T192P) or Player:RunicPower() >= 30 or Player:Buff(S.HungeringRuneWeapon)) and Player:Buff(S.Rime) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.bos_ticking+=/frost_strike,if=set_bonus.tier20_2pc&runic_power>85&rune<=3&buff.pillar_of_frost.up&!talent.shattering_strikes.enabled
    if S.FrostStrike:IsUsable() and T202P and Player:RunicPower() > 85 and Player:Runes() <= 3 and Player:Buff(S.PillarOfFrost) and not S.ShatteringStrikes:IsAvailable() then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.bos_ticking+=/obliterate,if=runic_power<=45|rune.time_to_5<gcd|buff.hungering_rune_weapon.remains>=2
    if S.Obliterate:IsCastable() and Player:RunicPower() <= 45 or Player:RuneTimeToX(5) < Player:GCD() or Player:BuffRemains(S.HungeringRuneWeapon) >= 2 then
      if AR.Cast(S.Obliterate) then return ""; end 
    end
    --actions.bos_ticking+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5&!buff.obliteration.up
    if S.SindragosasFury:IsCastable() and (I.ConsortsColdCore:IsEquipped() or Player:Buff(S.PillarOfFrost)) and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.RazorIce) == 5 and not Player:Buff(S.Obliteration) then
      if AR.Cast(S.SindragosasFury) then return ""; end
    end
    --actions.bos_ticking+=/horn_of_winter,if=runic_power<70&rune.time_to_3>gcd
    if S.HornOfWinter:IsCastable() and Player:RunicPower() < 70 and Player:RuneTimeToX(3) > Player:GCD() then
      if AR.Cast(S.HornOfWinter, Settings.DeathKnight.Frost.OffGCDasOffGCD.HornOfWinter) then return ""; end
    end
    --actions.bos_ticking+=/frostscythe,if=buff.killing_machine.up&(!equipped.koltiras_newfound_will|talent.gathering_storm.enabled|spell_targets.frostscythe>=2)
    if S.FrostScythe:IsCastable() and Player:Buff(S.KillingMachine) and (not I.KoltirasNewfoundWill:IsEquipped() or S.GatheringStorm:IsAvailable() or Cache.EnemiesCount[8] >= 2) then
      if AR.Cast(S.FrostScythe) then return ""; end
    end
    --actions.bos_ticking+=/glacial_advance,if=spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.GlacialAdvance) then return ""; end
    end
    --actions.bos_ticking+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
    if S.RemorselessWinter:IsCastable() and Cache.EnemiesCount[8] >= 2 then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.bos_ticking+=/obliterate,if=runic_power<=75|rune>3
    if S.Obliterate:IsCastable() and Player:RunicPower() <= 75 or Player:Runes() > 3 then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.bos_ticking+=/empower_rune_weapon,if=runic_power<30&rune.time_to_2>gcd
    if S.EmpowerRuneWeapon:IsCastable() and Player:RunicPower() < 30 and Player:RuneTimeToX(2) > Player:GCD() then
      if AR.Cast(S.EmpowerRuneWeapon, Settings.DeathKnight.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end
    return false;
  end

  local function Obliteration()
    --actions.obliteration=remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastable() and S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end
    --actions.obliteration+=/howling_blast,if=buff.rime.up&!buff.killing_machine.up&spell_targets.howling_blast>1
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and not Player:Buff(S.KillingMachine) and Cache.EnemiesCount[8] > 1 then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.obliteration+=/howling_blast,if=!buff.rime.up&!buff.killing_machine.up&spell_targets.howling_blast>2&rune>3&talent.freezing_fog.enabled&talent.gathering_storm.enabled
    if S.HowlingBlast:IsCastable() and not Player:Buff(S.Rime) and not Player:Buff(S.KillingMachine) and Cache.EnemiesCount[8] > 2 and Player:Runes() > 3 and S.FreezingFog:IsAvailable() and S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.obliteration+=/frost_strike,if=!buff.killing_machine.up&(!buff.rime.up|rune.time_to_1>=gcd|runic_power>=80)
    if S.FrostStrike:IsUsable() and not Player:Buff(S.KillingMachine) and (not Player:Buff(S.Rime) or Player:RuneTimeToX(1) >= Player:GCD() or Player:RunicPower() >= 80) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.obliteration+=/frostscythe,if=buff.killing_machine.up&spell_targets.frostscythe>1
    if S.FrostScythe:IsCastable() and Player:Buff(S.KillingMachine) and Cache.EnemiesCount[8] > 1 then
      if AR.Cast(S.FrostScythe) then return ""; end
    end
    --actions.obliteration+=/howling_blast,if=buff.rime.up&!buff.killing_machine.up
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and not Player:Buff(S.KillingMachine) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end
    --actions.obliteration+=/obliterate,if=buff.killing_machine.up
    if S.Obliterate:IsCastable() and Player:Buff(S.KillingMachine) then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    --actions.obliteration+=/frost_strike,if=!buff.killing_machine.up&rune.time_to_1>=gcd
    if S.FrostStrike:IsUsable() and not Player:Buff(S.KillingMachine) and Player:RuneTimeToX(1) >= Player:GCD() then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    --actions.obliteration+=/obliterate
    if S.Obliterate:IsCastable() then
      if AR.Cast(S.Obliterate) then return ""; end
    end
    return false;
  end

  local function CDS()
    if AR.CDsON() then
    --actions.cds=arcane_torrent,if=runic_power.deficit>20&!talent.breath_of_sindragosa.enable
    if S.ArcaneTorrent:IsCastable() and Player:RunicPowerDeficit() > 20 and not S.BreathofSindragosa:IsAvailable() then
      if AR.Cast(S.ArcaneTorrent, Settings.DeathKnight.Frost.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    --actions.cds+=/arcane_torrent,if=dot.breath_of_sindragosa.ticking&runic_power<50&rune<2
    if S.ArcaneTorrent:IsCastable() and Player:Buff(S.BreathofSindragosa) and Player:RunicPower() < 50 and Player:Runes() < 2 then
      if AR.Cast(S.ArcaneTorrent, Settings.DeathKnight.Frost.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    --actions.cds+=/blood_fury,if=buff.pillar_of_frost.up
    --actions.cds+=/berserking,if=buff.pillar_of_frost.up
    --actions.cds+=/use_item,name=feloiled_infernal_machine,if=!talent.obliteration.enabled|buff.obliteration.up
    if Settings.DeathKnight.Commons.UseTrinkets and I.FelOiledInfernalMachine:IsEquipped() and (not S.Obliteration:IsAvailable() or Player:Buff(S.Obliteration)) then
      if AR.CastSuggested(I.FelOiledInfernalMachine) then return ""; end
    end
    --actions.cds+=/potion,if=buff.pillar_of_frost.up&(dot.breath_of_sindragosa.ticking|buff.obliteration.up|talent.hungering_rune_weapon.enabled)
    if Settings.DeathKnight.Commons.UsePotions and I.ProlongedPower:IsReady() and Player:Buff(S.PillarOfFrost) and (Player:Buff(S.BreathofSindragosa) or Player:Buff(S.Obliteration) or S.HungeringRuneWeapon:IsAvailable()) then
      if AR.CastLeft(I.ProlongedPower) then return ""; end
    end
    --actions.cds+=/pillar_of_frost,if=talent.obliteration.enabled&(cooldown.obliteration.remains>20|cooldown.obliteration.remains<10|!talent.icecap.enabled)
    if S.PillarOfFrost:IsCastable() and S.Obliteration:IsAvailable() and (S.Obliteration:CooldownRemains() > 20 or S.Obliteration:CooldownRemains() < 10 or not S.Icecap:IsAvailable()) then
      if AR.Cast(S.PillarOfFrost, Settings.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost) then return ""; end
    end
    --actions.cds+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.ready&runic_power>50
    if S.PillarOfFrost:IsCastable() and S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:IsReady() and Player:RunicPower() > 50 then
      if AR.Cast(S.PillarOfFrost, Settings.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost) then return ""; end
    end
    --actions.cds+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains>40
    if S.PillarOfFrost:IsCastable() and S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemains() > 40 then
      if AR.Cast(S.PillarOfFrost, Settings.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost) then return ""; end
    end
    --actions.cds+=/pillar_of_frost,if=talent.hungering_rune_weapon.enabled
    if S.PillarOfFrost:IsCastable() and S.HungeringRuneWeapon:IsAvailable() then
      if AR.Cast(S.PillarOfFrost, Settings.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost) then return ""; end
    end
    --actions.cds+=/breath_of_sindragosa,if=buff.pillar_of_frost.up
    if S.BreathofSindragosa:IsCastable() and Player:Buff(S.PillarOfFrost) then
      if AR.Cast(S.BreathofSindragosa) then return ""; end
    end
    --actions.cds+=/call_action_list,name=cold_heart,if=equipped.cold_heart&((buff.cold_heart.stack>=10&!buff.obliteration.up)|target.time_to_die<=gcd)
    if I.ColdHeart:IsEquipped() and ((Player:BuffStack(S.ChilledHearth) >= 10 and not Player:Buff(S.Obliteration)) or Target:TimeToDie() <= Player:GCD()) then
    --[[COLD HEART LEGENDARY APL]]--
    --actions.cold_heart=chains_of_ice,if=buff.cold_heart.stack=20&buff.unholy_strength.up&cooldown.pillar_of_frost.remains>6
      if S.ChainsOfIce:IsCastable() and Player:BuffStack(S.ChilledHearth) == 20 and Player:Buff(S.UnholyStrength) and S.PillarOfFrost:CooldownRemains() > 6 then
        if AR.Cast(S.ChainsOfIce) then return ""; end
      end
    --actions.cold_heart+=/chains_of_ice,if=buff.pillar_of_frost.up&buff.pillar_of_frost.remains<gcd&(buff.cold_heart.stack>=11|(buff.cold_heart.stack>=10&set_bonus.tier20_4pc))
      if S.ChainsOfIce:IsCastable() and Player:Buff(S.PillarOfFrost) and Player:BuffRemains(S.PillarOfFrost) < Player:GCD() and (Player:BuffStack(S.ChilledHearth) >= 11 or (Player:BuffStack(S.ChilledHearth) >= 10 and T204P)) then
        if AR.Cast(S.ChainsOfIce) then return ""; end
      end
    --actions.cold_heart+=/chains_of_ice,if=buff.unholy_strength.up&buff.unholy_strength.remains<gcd&buff.cold_heart.stack>16&cooldown.pillar_of_frost.remains>6
      if S.ChainsOfIce:IsCastable() and Player:Buff(S.UnholyStrength) and Player:BuffRemains(S.UnholyStrength) < Player:GCD() and Player:BuffStack(S.ChilledHearth) > 16 and S.PillarOfFrost:CooldownRemains() > 6 then
        if AR.Cast(S.ChainsOfIce) then return ""; end
      end
    --actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack>=5&target.time_to_die<=gcd
      if S.ChainsOfIce:IsCastable() and Player:BuffStack(S.ChilledHearth) >= 5 and Target:TimeToDie() <= Player:GCD() then
        if AR.Cast(S.ChainsOfIce) then return ""; end
      end
    end
    --[[END OF COLD HEART APL]]--
    --actions.cds+=/obliteration,if=rune>=1&runic_power>=20&(!talent.frozen_pulse.enabled|rune<2|buff.pillar_of_frost.remains<12)&(!talent.gathering_storm.enabled|!cooldown.remorseless_winter.ready)&(buff.pillar_of_frost.up|!talent.icecap.enabled)
    if S.Obliteration:IsCastable() and Player:Runes() >= 1 and Player:RunicPower() >= 20 and (not S.FrozenPulse:IsAvailable() or Player:Runes() < 2 or Player:BuffRemains(S.PillarOfFrost) < 12) and (not S.GatheringStorm:IsAvailable() or not S.RemorselessWinter:IsReady()) and (Player:Buff(S.PillarOfFrost) or not S.Icecap:IsAvailable()) then
      if AR.Cast(S.Obliteration, Settings.DeathKnight.Frost.OffGCDasOffGCD.Obliteration) then return ""; end
    end
    --actions.cds+=/hungering_rune_weapon,if=!buff.hungering_rune_weapon.up&rune.time_to_2>gcd&runic_power<40&(buff.pillar_of_frost.remains>=12|target.time_to_die<(cooldown.pillar_of_frost.remains+20))
    if S.HungeringRuneWeapon:IsCastable() and not Player:Buff(S.HungeringRuneWeapon) and Player:RuneTimeToX(2) > Player:GCD() and Player:RunicPower() < 40 and (Player:BuffRemains(S.PillarOfFrost) >= 12 or Target:TimeToDie() < (S.PillarOfFrost:CooldownRemains() + 20)) then
      if AR.Cast(S.HungeringRuneWeapon, Settings.DeathKnight.OffGCDasOffGCD.Frost.HungeringRuneWeapon) then return ""; end
    end
    return false;
  end
  end
  

--- ======= MAIN =======
local function APL ()
    -- Unit Update
    AC.GetEnemies(8);
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
      if AR.Cast(S.HowlingBlast) then return ""; end
      end
    return;
  end
   
  -- In Combat
    if Everyone.TargetIsValid() then
  
    -- actions+=/call_action_list,name=cooldowns
      ShouldReturn = CDS();
      if ShouldReturn then return ShouldReturn; 
      end 

      --actions+=/run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<15
      if S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemains() < 15 then
        ShouldReturn = BoS_Pooling();
        if ShouldReturn then return ShouldReturn; end
        end

      --actions+=/run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
      if Player:Buff(S.BreathofSindragosa) then
        ShouldReturn = BoS_Ticking();
        if ShouldReturn then return ShouldReturn; end
        end

      --actions+=/run_action_list,name=obliteration,if=buff.obliteration.up
      if Player:Buff(S.Obliteration) then
        ShouldReturn = Obliteration();
        if ShouldReturn then return ShouldReturn; end
        end

      --actions+=/call_action_list,name=standard
      if S.BreathofSindragosa:IsAvailable() or S.Obliteration:IsAvailable() or S.HungeringRuneWeapon:IsAvailable() then
        ShouldReturn = Standard();
        if ShouldReturn then return ShouldReturn; end
        end

      return;
    end
end

  AR.SetAPL(251, APL);
--- ====28/08/2017======
--- ======= SIMC ======= 
--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/mind_freeze
--actions+=/call_action_list,name=cds
--actions+=/run_action_list,name=bos_pooling,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains<15
--actions+=/run_action_list,name=bos_ticking,if=dot.breath_of_sindragosa.ticking
--actions+=/run_action_list,name=obliteration,if=buff.obliteration.up
--actions+=/call_action_list,name=standard
 
--actions.bos_pooling=remorseless_winter,if=talent.gathering_storm.enabled
--actions.bos_pooling+=/howling_blast,if=buff.rime.react&rune.time_to_4<(gcd*2)
--actions.bos_pooling+=/obliterate,if=rune.time_to_6<gcd&!talent.gathering_storm.enabled
--actions.bos_pooling+=/obliterate,if=rune.time_to_4<gcd&(cooldown.breath_of_sindragosa.remains|runic_power<70)
--actions.bos_pooling+=/frost_strike,if=runic_power>=95&set_bonus.tier19_4pc&cooldown.breath_of_sindragosa.remains&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
--actions.bos_pooling+=/remorseless_winter,if=buff.rime.react&equipped.perseverance_of_the_ebon_martyr
--actions.bos_pooling+=/howling_blast,if=buff.rime.react&(buff.remorseless_winter.up|cooldown.remorseless_winter.remains>gcd|(!equipped.perseverance_of_the_ebon_martyr&!talent.gathering_storm.enabled))
--actions.bos_pooling+=/obliterate,if=!buff.rime.react&!(talent.gathering_storm.enabled&!(cooldown.remorseless_winter.remains>(gcd*2)|rune>4))&rune>3
--actions.bos_pooling+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5&!buff.obliteration.up
--actions.bos_pooling+=/frost_strike,if=runic_power>=70&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>rune.time_to_4)
--actions.bos_pooling+=/frostscythe,if=buff.killing_machine.up&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
--actions.bos_pooling+=/glacial_advance,if=spell_targets.glacial_advance>=2
--actions.bos_pooling+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
--actions.bos_pooling+=/frostscythe,if=spell_targets.frostscythe>=3
--actions.bos_pooling+=/frost_strike,if=(cooldown.remorseless_winter.remains<(gcd*2)|buff.gathering_storm.stack=10)&cooldown.breath_of_sindragosa.remains>rune.time_to_4&talent.gathering_storm.enabled&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
--actions.bos_pooling+=/obliterate,if=!buff.rime.react&(!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>gcd)
--actions.bos_pooling+=/frost_strike,if=cooldown.breath_of_sindragosa.remains>rune.time_to_4&(!talent.shattering_strikes.enabled|debuff.razorice.stack<5|cooldown.breath_of_sindragosa.remains>6)
 
--actions.bos_ticking=frost_strike,if=talent.shattering_strikes.enabled&runic_power<40&rune.time_to_2>2&cooldown.empower_rune_weapon.remains&debuff.razorice.stack=5&(cooldown.horn_of_winter.remains|!talent.horn_of_winter.enabled)
--actions.bos_ticking+=/remorseless_winter,if=(runic_power>=30|buff.hungering_rune_weapon.up)&((buff.rime.react&equipped.perseverance_of_the_ebon_martyr)|(talent.gathering_storm.enabled&(buff.remorseless_winter.remains<=gcd|!buff.remorseless_winter.remains)))
--actions.bos_ticking+=/howling_blast,if=((runic_power>=20&set_bonus.tier19_4pc)|runic_power>=30|buff.hungering_rune_weapon.up)&buff.rime.react
--actions.bos_ticking+=/frost_strike,if=set_bonus.tier20_2pc&runic_power>85&rune<=3&buff.pillar_of_frost.up&!talent.shattering_strikes.enabled
--actions.bos_ticking+=/obliterate,if=runic_power<=45|rune.time_to_5<gcd|buff.hungering_rune_weapon.remains>=2
--actions.bos_ticking+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5&!buff.obliteration.up
--actions.bos_ticking+=/horn_of_winter,if=runic_power<70&rune.time_to_3>gcd
--actions.bos_ticking+=/frostscythe,if=buff.killing_machine.up&(!equipped.koltiras_newfound_will|talent.gathering_storm.enabled|spell_targets.frostscythe>=2)
--actions.bos_ticking+=/glacial_advance,if=spell_targets.glacial_advance>=2
--actions.bos_ticking+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
--actions.bos_ticking+=/obliterate,if=runic_power<=75|rune>3
--actions.bos_ticking+=/empower_rune_weapon,if=runic_power<30&rune.time_to_2>gcd

--actions.cds=arcane_torrent,if=runic_power.deficit>20&!talent.breath_of_sindragosa.enabled
--actions.cds+=/arcane_torrent,if=dot.breath_of_sindragosa.ticking&runic_power<50&rune<2
--actions.cds+=/blood_fury,if=buff.pillar_of_frost.up
--actions.cds+=/berserking,if=buff.pillar_of_frost.up
--actions.cds+=/use_items
--actions.cds+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--actions.cds+=/use_item,name=horn_of_valor,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
--actions.cds+=/use_item,name=draught_of_souls,if=rune.time_to_5>3&(!dot.breath_of_sindragosa.ticking|runic_power>60)
--actions.cds+=/use_item,name=feloiled_infernal_machine,if=!talent.obliteration.enabled|buff.obliteration.up
--actions.cds+=/potion,if=buff.pillar_of_frost.up&(dot.breath_of_sindragosa.ticking|buff.obliteration.up|talent.hungering_rune_weapon.enabled)
--actions.cds+=/pillar_of_frost,if=talent.obliteration.enabled&(cooldown.obliteration.remains>20|cooldown.obliteration.remains<10|!talent.icecap.enabled)
--actions.cds+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.ready&runic_power>50
--actions.cds+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains>40
--actions.cds+=/pillar_of_frost,if=talent.hungering_rune_weapon.enabled
--actions.cds+=/breath_of_sindragosa,if=buff.pillar_of_frost.up
--actions.cds+=/call_action_list,name=cold_heart,if=equipped.cold_heart&((buff.cold_heart.stack>=10&!buff.obliteration.up)|target.time_to_die<=gcd)
--actions.cds+=/obliteration,if=rune>=1&runic_power>=20&(!talent.frozen_pulse.enabled|rune<2|buff.pillar_of_frost.remains<12)&(!talent.gathering_storm.enabled|!cooldown.remorseless_winter.ready)&(buff.pillar_of_frost.up|!talent.icecap.enabled)
--actions.cds+=/hungering_rune_weapon,if=!buff.hungering_rune_weapon.up&rune.time_to_2>gcd&runic_power<40&(buff.pillar_of_frost.remains>=12|target.time_to_die<(cooldown.pillar_of_frost.remains+20))

--actions.cold_heart=chains_of_ice,if=buff.cold_heart.stack=20&buff.unholy_strength.up&cooldown.pillar_of_frost.remains>6
--actions.cold_heart+=/chains_of_ice,if=buff.pillar_of_frost.up&buff.pillar_of_frost.remains<gcd&(buff.cold_heart.stack>=11|(buff.cold_heart.stack>=10&set_bonus.tier20_4pc))
--actions.cold_heart+=/chains_of_ice,if=buff.unholy_strength.up&buff.unholy_strength.remains<gcd&buff.cold_heart.stack>16&cooldown.pillar_of_frost.remains>6
--actions.cold_heart+=/chains_of_ice,if=buff.cold_heart.stack>=5&target.time_to_die<=gcd
 
--actions.obliteration=remorseless_winter,if=talent.gathering_storm.enabled
--actions.obliteration+=/howling_blast,if=buff.rime.up&!buff.killing_machine.up&spell_targets.howling_blast>1
--actions.obliteration+=/howling_blast,if=!buff.rime.up&!buff.killing_machine.up&spell_targets.howling_blast>2&rune>3&talent.freezing_fog.enabled&talent.gathering_storm.enabled
--actions.obliteration+=/frost_strike,if=!buff.killing_machine.up&(!buff.rime.up|rune.time_to_1>=gcd|runic_power>=80)
--actions.obliteration+=/frostscythe,if=buff.killing_machine.up&spell_targets.frostscythe>1
--actions.obliteration+=/howling_blast,if=buff.rime.up&!buff.killing_machine.up
--actions.obliteration+=/obliterate,if=buff.killing_machine.up
--actions.obliteration+=/frost_strike,if=!buff.killing_machine.up&rune.time_to_1>=gcd
--actions.obliteration+=/obliterate

--actions.standard=/frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<=gcd
--actions.standard+=/frost_strike,if=talent.shattering_strikes.enabled&debuff.razorice.stack=5&buff.gathering_storm.stack<2&!buff.rime.up
--actions.standard+=/remorseless_winter,if=(buff.rime.react&equipped.perseverance_of_the_ebon_martyr)|talent.gathering_storm.enabled
--actions.standard+=/howling_blast,if=buff.rime.react
--actions.standard+=/obliterate,if=(equipped.koltiras_newfound_will&talent.frozen_pulse.enabled&set_bonus.tier19_2pc=1)|rune.time_to_5<gcd
--actions.standard+=/sindragosas_fury,if=(equipped.consorts_cold_core|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5
--actions.standard+=/hungering_rune_weapon,if=!buff.hungering_rune_weapon.up&rune.time_to_3>gcd*2&runic_power<25&rune<2
--actions.standard+=/frost_strike,if=runic_power>=90
--actions.standard+=/frostscythe,if=buff.killing_machine.up&(!equipped.koltiras_newfound_will|spell_targets.frostscythe>=2)
--actions.standard+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
--actions.standard+=/glacial_advance,if=spell_targets.glacial_advance>=2
--actions.standard+=/frostscythe,if=spell_targets.frostscythe>=3
--actions.standard+=/obliterate,if=buff.killing_machine.react
--actions.standard+=/frost_strike,if=runic_power>=80
--actions.standard+=/obliterate
--actions.standard+=/horn_of_winter,if=!buff.hungering_rune_weapon.up&(rune.time_to_2>gcd|!talent.frozen_pulse.enabled)
--actions.standard+=/frost_strike,if=!(runic_power<50&talent.obliteration.enabled&cooldown.obliteration.remains<=gcd)
--actions.standard+=/empower_rune_weapon,if=!talent.breath_of_sindragosa.enabled|target.time_to_die<cooldown.breath_of_sindragosa.remains

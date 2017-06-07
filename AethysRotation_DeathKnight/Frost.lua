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
    ArcaneTorrent                 = Spell(80483),
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
    ChilledHearth                 = Spell(235592),
    ConsortsColdCore              = Spell(235605),
    KiljaedensBurningWish         = Spell(144259),
    KoltirasNewfoundWill          = Spell(208782),
    PerseveranceOfTheEbonMartyre  = Spell(216059),
    SealOfNecrofantasia           = Spell(212216),
    ToravonsWhiteoutBindings      = Spell(205628),
           
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.DeathKnight.Frost;
  -- Items
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Frost = {
    -- Legendaries
    ConvergenceofFates            = Item(140806, {13, 14}),
    ColdHearth                    = Item(151796, {5}), 
    ConsortsColdCore              = Item(144293, {8}),
    KiljaedensBurningWish         = Item(144259, {13, 14}),
    KoltirasNewfoundWill          = Item(132366, {6}),
    PerseveranceOfTheEbonMartyre  = Item(132459, {1}),
    SealOfNecrofantasia           = Item(137223, {11, 12}),
    ToravonsWhiteoutBindings      = Item(132458, {9}),
    
  };
  local I = Item.DeathKnight.Frost;
  -- Rotation Var
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DeathKnight.Commons,
    Frost = AR.GUISettings.APL.DeathKnight.Frost
  };


   
--- ======= ACTION LISTS =======
  local function Generic()
    --actions.generic=obliteration,if=(!talent.frozen_pulse.enabled|(rune<2&runic_power<28))&!talent.gathering_storm.enabled
    if S.Obliteration:IsCastable() and (not S.FrozenPulse:IsAvailable() or (Player:Runes() < 2 and Player:RunicPower() < 28)) and not S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.Obliteration, Settings.Frost.OffGCDasOffGCD.Obliteration) then return; end
    end

    -- actions.generic+=/frost_strike,if=buff.icy_talons.remains<=gcd&talent.icy_talons.enabled
    if S.FrostStrike:IsCastable() and (S.IcyTalons:IsAvailable() and Player:BuffRemains(S.IcyTalonsBuff) < Player:GCD() * 1.5) and Player:RunicPower() >= 25 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    -- actions.generic+=/frost_strike,if=talent.shattering_strikes.enabled&debuff.razorice.stack=5
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25  and S.ShatteringStrikes:IsAvailable() and Target:DebuffStack(S.RazorIce) == 5 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.generic+=/howling_blast,target_if=!dot.frost_fever.ticking
    if S.HowlingBlast:IsCastable() and not Target:Debuff(S.FrostFever) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    -- actions.generic+=/remorseless_winter,if=(buff.rime.react&equipped.132459&!(buff.obliteration.up&spell_targets.howling_blast<2))|talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastable() and (Player:Buff(S.Rime) and I.PerseveranceOfTheEbonMartyre:IsEquipped() and not (Player:Buff(S.Obliteration) and Cache.EnemiesCount[10] < 2) or S.GatheringStorm:IsAvailable()) then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    --  actions.generic+=/howling_blast,if=buff.rime.react&!(buff.obliteration.up&spell_targets.howling_blast<2)&!(equipped.132459&talent.gathering_storm.enabled)
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and not((Player:Buff(S.Obliteration) and Cache.EnemiesCount[10] < 2) and  not I.PerseveranceOfTheEbonMartyre:IsEquipped()) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    -- actions.generic+=/howling_blast,if=buff.rime.react&!(buff.obliteration.up&spell_targets.howling_blast<2)&equipped.132459&talent.gathering_storm.enabled&(debuff.perseverance_of_the_ebon_martyr.up|cooldown.remorseless_winter.remains>3)
    if S.HowlingBlast:IsCastable()  and Player:Buff(S.Rime) and not (Player:Buff(S.Obliteration) and Cache.EnemiesCount[10] < 2) and I.PerseveranceOfTheEbonMartyre:IsEquipped() and (Target:Debuff(S.PerseveranceOfTheEbonMartyre) or S.RemorselessWinter:Cooldown()>3) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    --  actions.generic+=/obliterate,if=!buff.obliteration.up&(equipped.132366&talent.frozen_pulse.enabled&(set_bonus.tier19_2pc=1|set_bonus.tier19_4pc=1))|rune.time_to_5<gcd
    if S.Obliterate:IsCastable() and (not Player:Buff(S.Obliteration) and (I.PerseveranceOfTheEbonMartyre:IsEquipped() and S.FrozenPulse:IsAvailable() and (AC.Tier19_2Pc or AC.Tier19_4Pc )) or Player:RuneTimeToX(5) < Player:GCD()) then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.generic+=/frost_strike,if=runic_power.deficit<=10
    if S.FrostStrike:IsCastable() and  Player:RunicPowerDeficit() <= 10 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.generic+=/frost_strike,if=buff.obliteration.up&!buff.killing_machine.react
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25 and Player:Buff(S.Obliteration) and not Player:Buff(S.KillingMachine) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.generic+=/remorseless_winter,if=spell_targets.remorseless_winter>=2&!(talent.frostscythe.enabled&buff.killing_machine.react&spell_targets.frostscythe>=2)
    if S.RemorselessWinter:IsCastable() and Cache.EnemiesCount[10] >= 2 and not (S.FrostScythe:IsAvailable() and Player:Buff(S.KillingMachine)) then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    --  actions.generic+=/frostscythe,if=(buff.killing_machine.react&spell_targets.frostscythe>=2)
    if S.FrostScythe:IsCastable() and Player:Buff(S.KillingMachine) and Cache.EnemiesCount[10] >= 2 then
      AR.CastSuggested(S.FrostScythe); 
    end

    --  actions.generic+=/glacial_advance,if=spell_targets.glacial_advance>=2
    if S.GlacialAdvance:IsCastable() and Cache.EnemiesCount[10] >= 2 then
      AR.CastSuggested(S.GlacialAdvance); 
    end

    --  actions.generic+=/frostscythe,if=spell_targets.frostscythe>=3
    if S.FrostScythe:IsCastable() and Cache.EnemiesCount[10] >= 4 then
      AR.CastSuggested(S.FrostScythe); 
    end

    --  actions.generic+=/obliterate,if=buff.killing_machine.react
    if S.Obliterate:IsCastable() and Player:Buff(S.KillingMachine) then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    -- actions.generic+=/frost_strike,if=talent.gathering_storm.enabled&talent.murderous_efficiency.enabled&(set_bonus.tier19_2pc=1|set_bonus.tier19_4pc=1)
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25 and S.GatheringStorm:IsAvailable() and S.MurderousEfficiency:IsAvailable() and (AC.tier19_2Pc or AC.Tier19_4Pc)  then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.generic+=/frost_strike,if=(talent.horn_of_winter.enabled|talent.hungering_Rune_weapon.enabled)&(set_bonus.tier19_2pc=1|set_bonus.tier19_4pc=1)
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25 and (S.HornOfWinter:IsAvailable() or S.HungeringRuneWeapon:IsAvailable()) and (AC.Tier19_2Pc or AC.Tier19_4Pc) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.generic+=/obliterate
    if S.Obliterate:IsCastable() then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.generic+=/glacial_advance
    if S.GlacialAdvance:IsCastable() then
      if AR.Cast(S.GlacialAdvance) then return ""; end
    end

    --  actions.generic+=/horn_of_winter,if=!buff.hungering_Rune_weapon.up
    if S.HornOfWinter:IsCastable() and not Player.Buff(S.HungeringRuneWeapon) then
      if AR.Cast(S.HornOfWinter) then return ""; end
    end

    --  actions.generic+=/frost_strike
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25  then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.generic+=/empower_Rune_weapon
    if S.EmpowerRuneWeapon:IsCastable() and Player:Runes() < 2 and Player:RunicPower() < 25 and not ( S.Obliteration:IsCastable() or S.Obliteration:IsCastable()) then
      if AR.Cast(S.EmpowerRuneWeapon, Settings.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ""; end
    end

    --  actions.generic+=/hungering_Rune_weapon,if=!buff.hungering_Rune_weapon.up
    if S.HungeringRuneWeapon:IsCastable() and not Player:Buff(S.HungeringRuneWeapon) and Player:Runes() < 2 and Player:RunicPower() < 25 and not ( S.Obliteration:IsCastable() or S.Obliteration:IsCastable()) then
      if AR.Cast(S.HungeringRuneWeapon, Settings.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return ""; end
    end
    return false;
  end

  local function BOS()

    --  actions.bos=frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<gcd&cooldown.breath_of_sindragosa.remains>rune.time_to_4
    if S.FrostStrike:IsCastable()  and S.IcyTalons:IsAvailable() and Player:BuffRemains(S.IcyTalonsBuff) < Player:GCD() and S.BreathofSindragosa:Cooldown() > Player:RuneTimeToX(4) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.bos+=/remorseless_winter,if=talent.gathering_storm.enabled
    if S.RemorselessWinter:IsCastable()  and S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    --  actions.bos+=/howling_blast,target_if=!dot.frost_fever.ticking
    if S.HowlingBlast:IsCastable() and not Target:Debuff(S.FrostFever) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    -- actions.bos+=/howling_blast,if=buff.rime.react&rune.time_to_4<(gcd*2)
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and Player:RuneTimeToX(4) < (Player:GCD() * 2) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    -- actions.bos+=/obliterate,if=rune.time_to_6<gcd&!talent.gathering_storm.enabled
    if S.Obliterate:IsCastable() and Player:RuneTimeToX(6) < Player:GCD() and not S.GatheringStorm:IsAvailable()   then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    -- actions.bos+=/obliterate,if=rune.time_to_4<gcd&(cooldown.breath_of_sindragosa.remains|runic_power<70)
    if S.Obliterate:IsCastable() and Player:RuneTimeToX(4) < Player:GCD() and (not S.BreathofSindragosa:IsCastable() or Player:RunicPower() < 70 )  then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.bos+=/frost_strike,if=runic_power>=90&set_bonus.tier19_4pc&cooldown.breath_of_sindragosa.remains
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 90 and AC.Tier19_4Pc and not S.BreathofSindragosa:IsCastable() then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.bos+=/remorseless_winter,if=buff.rime.react&equipped.132459
    if S.RemorselessWinter:IsCastable()  and Player:Buff(S.Rime) and I.PerseveranceOfTheEbonMartyre:IsEquipped() then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    --  actions.bos+=/howling_blast,if=buff.rime.react&(dot.remorseless_winter.ticking|cooldown.remorseless_winter.remains>gcd|(!equipped.132459&!talent.gathering_storm.enabled))
    if S.HowlingBlast:IsCastable()  and Player:Buff(S.Rime) and (Player:Buff(S.RemorselessWinter) or S.RemorselessWinter:Cooldown() > Player:GCD()) or ( not I.PerseveranceOfTheEbonMartyre:IsEquipped() and not S.GatheringStorm:IsAvailable()) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    --  actions.bos+=/obliterate,if=!buff.rime.react&!(talent.gathering_storm.enabled&!(cooldown.remorseless_winter.remains>(gcd*2)|rune>4))&rune>3
    if S.Obliterate:IsCastable()  and not Player:Buff(S.Rime) and not ((S.GatheringStorm:IsAvailable() and not (S.RemorselessWinter:Cooldown() > Player:GCD() * 2) or Player:Runes() > 4 )) and Player:Runes() > 3 then
      if AR.Cast(S.Obliterate) then return ""; end
    end

       
    -- actions.bos+=/frost_strike,if=runic_power>=70
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 70 and S.HungeringRuneWeapon:Cooldown() >= 10 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    -- actions.bos+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
    if S.RemorselessWinter:IsCastable() and Cache.EnemiesCount[10] > 2 then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    -- actions.bos+=/obliterate,if=!buff.rime.react&(!talent.gathering_storm.enabled|cooldown.remorseless_winter.remains>(gcd))
    if S.Obliterate:IsCastable() and not Player:Buff(S.Rime) and (not S.GatheringStorm:IsAvailable() or S.RemorselessWinter:Cooldown() > Player:GCD()) then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    -- actions.bos+=/frost_strike,if=(cooldown.remorseless_winter.remains<(gcd*2)|buff.gathering_storm.stack=10)&cooldown.breath_of_sindragosa.remains>rune.time_to_4&talent.gathering_storm.enabled    
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25 and (S.RemorselessWinter:Cooldown() < (Player:GCD()*2) or Player:BuffStack(S.GatheringStorm) == 10) and S.BreathofSindragosa:Cooldown() > Player:RuneTimeToX(4) and S.GatheringStorm:IsAvailable() then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    -- actions.bos+=/horn_of_winter,if=cooldown.breath_of_sindragosa.remains>15&runic_power<=70&rune.time_to_3>gcd
    if S.HornOfWinter:IsCastable() and S.BreathofSindragosa:Cooldown() > 15 and Player:RunicPower() <=70 and Player:RuneTimeToX(3) > Player:GCD()  then
      if AR.Cast(S.HornOfWinter) then return ""; end
    end

    --  actions.bos+=/frost_strike,if=cooldown.breath_of_sindragosa.remains>rune.time_to_4
    if S.FrostStrike:IsCastable() and Player:RunicPower() >= 25 and S.BreathofSindragosa:Cooldown() > Player:RuneTimeToX(4)   then
      if AR.Cast(S.FrostStrike) then return ""; end
    end
    return false;
  end

  local function BOS_Ticking()
    -- actions.bos_ticking=howling_blast,target_if=!dot.frost_fever.ticking
    if S.HowlingBlast:IsCastable() and not Target:Debuff(S.FrostFever) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    --  actions.bos_ticking+=/remorseless_winter,if=(runic_power>=30|buff.hungering_rune_weapon.up)&((buff.rime.react&equipped.132459)|(talent.gathering_storm.enabled&(dot.remorseless_winter.remains<=gcd|!dot.remorseless_winter.ticking)))
    if S.RemorselessWinter:IsCastable() and (Player:RunicPower() > 30 or Player:Buff(S.HungeringRuneWeapon)) and ((I.PerseveranceOfTheEbonMartyre:IsEquipped() and Player:Buff(S.Rime)) or (S.GatheringStorm:IsAvailable() and (Player:BuffRemains(S.RemorselessWinter) < Player:GCD()  or not Target:Debuff(S.RemorselessWinter)))) then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    -- actions.bos_ticking+=/howling_blast,if=((runic_power>=20&set_bonus.tier19_4pc)|runic_power>=30|buff.hungering_rune_weapon.up)&buff.rime.react
    if S.HowlingBlast:IsCastable() and ((Player:RunicPower() >= 40 and AC.Tier19_4Pc ) or Player:RunicPower() >= 50 or Player:Buff(S.HungeringRuneWeapon)) and Player:Buff(S.Rime) and S.RemorselessWinter:Cooldown() > Player:GCD() then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    --  actions.bos_ticking+=/obliterate,if=runic_power<=45|rune.time_to_5<gcd|buff.hungering_rune_weapon.remains>=2
    if S.Obliterate:IsCastable() and S.RemorselessWinter:Cooldown() > Player:GCD() and (Player:RunicPower() <= 45 or Player:RuneTimeToX(5) < Player:GCD() or Player:BuffRemains(S.HungeringRuneWeapon) > 2 ) then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.bos_ticking+=/remorseless_winter,if=spell_targets.remorseless_winter>=2
    if S.RemorselessWinter:IsCastable() and Cache.EnemiesCount[10] >= 2 then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    --  actions.bos_ticking+=/obliterate,if=runic_power<=75|rune>3
    if S.Obliterate:IsCastable() and Player:RunicPower() <= 75 or Player:Runes() > 3  then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.bos_ticking+=/horn_of_winter,if=runic_power<70&!buff.hungering_rune_weapon.up&rune.time_to_3>gcd
    if S.HornOfWinter:IsCastable() and Player:RunicPower() < 70 and not Player:Buff(S.HungeringRuneWeapon) and Player:RuneTimeToX(3) > Player:GCD() then
      if AR.Cast(S.HornOfWinter) then return ""; end
    end

    --  actions.bos_ticking+=/hungering_rune_weapon,if=runic_power<70&!buff.hungering_rune_weapon.up&rune<2&cooldown.breath_of_sindragosa.remains>35&equipped.140806
    if S.HungeringRuneWeapon:IsCastable() and Player:RunicPower() < 70 and not Player:Buff(S.HungeringRuneWeapon) and Player:Runes() < 2 and S.BreathofSindragosa:Cooldown() > 35 and I.ConvergenceofFates:IsEquipped()  then
      if AR.Cast(S.HungeringRuneWeapon, Settings.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return; end
    end

    -- actions.bos_ticking+=/hungering_rune_weapon,if=runic_power<50&!buff.hungering_rune_weapon.up&rune.time_to_2>=3&cooldown.breath_of_sindragosa.remains>30
    if S.HungeringRuneWeapon:IsCastable() and Player:RunicPower() < 50 and not Player:Buff(S.HungeringRuneWeapon) and Player:RuneTimeToX(2) == 3 and S.BreathofSindragosa:Cooldown() > 30   then 
      if AR.Cast(S.HungeringRuneWeapon, Settings.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return ; end
    end

    --  actions.bos_ticking+=/hungering_Rune_weapon,if=runic_power<35&!buff.hungering_Rune_weapon.up&Runes()<1
    if S.HungeringRuneWeapon:IsCastable() and Player:RunicPower() < 35 and not Player:Buff(S.HungeringRuneWeapon) and Player:Runes() < 1  then
      if AR.Cast(S.HungeringRuneWeapon, Settings.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return; end
    end

    --  actions.bos_ticking+=/hungering_Rune_weapon,if=runic_power<25&!buff.hungering_Rune_weapon.up&Runes()<2
    if S.HungeringRuneWeapon:IsCastable() and Player:RunicPower() < 45 and not Player:Buff(S.HungeringRuneWeapon) and Player:Runes() < 2  then
      if AR.Cast(S.HungeringRuneWeapon, Settings.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return ; end
      end

    --  actions.bos_ticking+=/empower_Rune_weapon,if=runic_power<20
    if S.EmpowerRuneWeapon:IsCastable() and Player:RunicPower() < 20 then
      if AR.Cast(S.EmpowerRuneWeapon, Settings.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ; end
    end
    return false;
  end

  local function GS_Ticking()
    --  actions.gs_ticking=frost_strike,if=buff.icy_talons.remains<=gcd&talent.icy_talons.enabled
    if S.FrostStrike:IsCastable() and Player:RunicPower() >=25  and Player:BuffRemains(S.IcyTalonsBuff) < Player:GCD() and S.IcyTalons:IsAvailable() then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.gs_ticking+=/remorseless_winter
    if S.RemorselessWinter:IsCastable() then
      if AR.Cast(S.RemorselessWinter) then return ""; end
    end

    --  actions.gs_ticking+=/howling_blast,if=!dot.frost_fever.ticking
    if S.HowlingBlast:IsCastable() and not Target:Debuff(S.FrostFever) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    -- actions.gs_ticking+=/howling_blast,if=buff.rime.react&!(buff.obliteration.up&spell_targets.howling_blast<2)
    if S.HowlingBlast:IsCastable() and Player:Buff(S.Rime) and not (Player:Buff(S.Obliteration) and Cache.EnemiesCount[10] < 1 ) then
      if AR.Cast(S.HowlingBlast) then return ""; end
    end

    --  actions.gs_ticking+=/obliteration,if=(!talent.frozen_pulse.enabled|(Runes()<2&runic_power<28))
    if S.Obliteration:IsCastable() and (not S.FrozenPulse:IsAvailable() or ((Player:Runes() < 2 and Player:RunicPower() < 28 ))) then
      if AR.Cast(S.Obliteration, Settings.Commons.OffGCDasOffGCD.Obliteration) then return; end
    end

    --  actions.gs_ticking+=/obliterate,if=rune.time_to_5<gcd|buff.killing_machine.react|buff.obliteration.up
    if S.Obliterate:IsCastable() and (Player:RuneTimeToX(5) < Player:GCD() or Player:Buff(S.KillingMachine) or Player:Buff(S.KillingMachine)) then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.gs_ticking+=/frost_strike,if=runic_power>80|(buff.obliteration.up&!buff.killing_machine.react)
    if S.FrostStrike:IsCastable() and (Player:RunicPower() > 80 or (Player:Buff(S.Obliteration) and not Player:Buff(S.KillingMachine))) then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.gs_ticking+=/obliterate
    if S.Obliterate:IsCastable() then
      if AR.Cast(S.Obliterate) then return ""; end
    end

    --  actions.gs_ticking+=/horn_of_winter,if=runic_power<70&!buff.hungering_Rune_weapon.up
    if S.HornOfWinter:IsCastable() and Player:RunicPower() < 70 and not Player:Buff(S.HungeringRuneWeapon) then
      if AR.Cast(S.HornOfWinter) then return ""; end
    end

    --  actions.gs_ticking+=/glacial_advance
    if S.GlacialAdvance:IsCastable() then
      if AR.Cast(S.GlacialAdvance) then return ""; end
    end

    --  actions.gs_ticking+=/frost_strike
    if S.FrostStrike:IsCastable() and Player:RunicPower() >=25 then
      if AR.Cast(S.FrostStrike) then return ""; end
    end

    --  actions.gs_ticking+=/hungering_Rune_weapon,if=!buff.hungering_Rune_weapon.up
    if S.HungeringRuneWeapon:IsCastable() and not Player:Buff(S.HungeringRuneWeapon) then
      if AR.Cast(S.HungeringRuneWeapon, Settings.Frost.OffGCDasOffGCD.HungeringRuneWeapon) then return ; end
    end

    --  actions.gs_ticking+=/empower_Rune_weapon
    if S.EmpowerRuneWeapon:IsCastable() then
      if AR.Cast(S.EmpowerRuneWeapon, Settings.Frost.OffGCDasOffGCD.EmpowerRuneWeapon) then return ; end
    end
    return false;
  end

  local function CDS()
    --actions+=/pillar_of_frost,if=!talent.breath_of_sindragosa.enabled
    if S.PillarOfFrost:IsCastable() and not S.BreathofSindragosa:IsAvailable() then
      if AR.Cast(S.PillarOfFrost, Settings.Frost.OffGCDasOffGCD.PillarOfFrost) then return ; end
    end

    --actions+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&cooldown.breath_of_sindragosa.remains>40
    if S.PillarOfFrost:IsCastable() and S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:Cooldown() > 40 then
      if AR.Cast(S.PillarOfFrost, Settings.Frost.OffGCDasOffGCD.PillarOfFrost) then return ; end
    end

    --actions+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&!cooldown.breath_of_sindragosa.remains&runic_power>=50&equipped.140806&cooldown.hungering_rune_weapon.remains<10
    if S.PillarOfFrost:IsCastable() and S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:IsCastable() and Player:RunicPower() >=70 and Player:Runes() >= 2 and I.ConvergenceofFates:IsEquipped() and S.HungeringRuneWeapon:Cooldown() < 10 then
      if AR.Cast(S.PillarOfFrost, Settings.Frost.OffGCDasOffGCD.PillarOfFrost) then return ; end
    end

    --actions+=/pillar_of_frost,if=talent.breath_of_sindragosa.enabled&!cooldown.breath_of_sindragosa.remains&runic_power>=50&!equipped.140806&(cooldown.hungering_rune_weapon.remains<15|target.time_to_die>135)
    if S.PillarOfFrost:IsCastable() and S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:IsCastable() and Player:RunicPower() >=70 and Player:Runes() >= 2 and not I.ConvergenceofFates:IsEquipped() and (S.HungeringRuneWeapon:Cooldown() < 10 or Target:TimeToDie() > 135) then
      if AR.Cast(S.PillarOfFrost, Settings.Frost.OffGCDasOffGCD.PillarOfFrost) then return ; end
    end

    --actions+=/breath_of_sindragosa,if=buff.pillar_of_frost.up
    if S.BreathofSindragosa:IsCastable()  and Player:Buff(S.PillarOfFrost) then
      if AR.Cast(S.BreathofSindragosa) then return ""; end
    end

    --  actions.bos+=/sindragosas_fury,if=(equipped.144293|buff.pillar_of_frost.up)&buff.unholy_strength.up&debuff.razorice.stack=5&!buff.obliteration.up
    if S.SindragosasFury:IsCastable() and(I.ConsortsColdCore:IsEquipped() or Player:Buff(S.PillarOfFrost)) and Player:Buff(S.UnholyStrength) and not Player:Buff(S.Obliteration) and Player:RunicPower() >= 70 then
      AR.CastSuggested(S.SindragosasFury);
    end

    return false;
  end

--- ======= MAIN =======
local function APL ()
    -- Unit Update
    AC.GetEnemies(10);
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

      --  actions+=/call_action_list,name=generic,if=!talent.breath_of_sindragosa.enabled&!(talent.gathering_storm.enabled&buff.remorseless_winter.remains)
     if not S.BreathofSindragosa:IsAvailable() and not  (S.GatheringStorm:IsAvailable() and Player:Buff(S.RemorselessWinter)) then
         ShouldReturn = Generic();
      if ShouldReturn then return ShouldReturn; end
     end
      --  actions+=/call_action_list,name=bos,if=talent.breath_of_sindragosa.enabled&!dot.breath_of_sindragosa.ticking 
      if S.BreathofSindragosa:IsAvailable() and not Player:Buff(S.BreathofSindragosa) then
        ShouldReturn = BOS();
        if ShouldReturn then return ShouldReturn;end
      end

      --  actions+=/call_action_list,name=bos_ticking,if=talent.breath_of_sindragosa.enabled&dot.breath_of_sindragosa.ticking
       if S.BreathofSindragosa:IsAvailable() and Player:Buff(S.BreathofSindragosa) then
        ShouldReturn = BOS_Ticking();
        if ShouldReturn then return ShouldReturn; end
      end

      --  actions+=/call_action_list,name=gs_ticking,if=talent.gathering_storm.enabled&buff.remorseless_winter.remains&!talent.breath_of_sindragosa.enabled  
      if not S.BreathofSindragosa:IsAvailable() and S.GatheringStorm:IsAvailable() and Player:Buff(S.RemorselessWinter) then
        ShouldReturn = GS_Ticking();
        if ShouldReturn then return ShouldReturn; end
      end

      return;
    end
end

  AR.SetAPL(251, APL);

--- ======= SIMC =======
-- actions+=/pillar_of_frost,if=!equipped.140806|!talent.breath_of_sindragosa.enabled
-- actions+=/pillar_of_frost,if=equipped.140806&talent.breath_of_sindragosa.enabled&((runic_power>=50&cooldown.hungering_Rune_weapon.remains<10)|(cooldown.breath_of_sindragosa.remains>20))
-- actions+=/mind_freeze
-- actions+=/arcane_torrent,if=runic_power.deficit>20&!talent.breath_of_sindragosa.enabled
-- actions+=/arcane_torrent,if=talent.breath_of_sindragosa.enabled&dot.breath_of_sindragosa.ticking&runic_power<30&Runes()<2
-- actions+=/blood_fury,if=buff.pillar_of_frost.up
-- actions+=/berserking,if=buff.pillar_of_frost.up
--  actions+=/use_items
--  actions+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--  actions+=/potion,if=buff.pillar_of_frost.up&(!talent.breath_of_sindragosa.enabled|!cooldown.breath_of_sindragosa.remains)
--  actions+=/sindragosas_fury,if=!equipped.144293&buff.pillar_of_frost.up&(buff.unholy_strength.up|(buff.pillar_of_frost.remains<3&target.time_to_die<60))&debuff.razorice.stack=5&!buff.obliteration.up
--  actions+=/sindragosas_fury,if=equipped.144293&buff.unholy_strength.up&cooldown.pillar_of_frost.remains>20
--  actions+=/obliteration,if=(!talent.frozen_pulse.enabled|(Runes()<2&runic_power<28))&!talent.gathering_storm.enabled
--  actions+=/call_action_list,name=generic,if=!talent.breath_of_sindragosa.enabled&!(talent.gathering_storm.enabled&buff.remorseless_winter.remains)
--  actions+=/call_action_list,name=bos,if=talent.breath_of_sindragosa.enabled&!dot.breath_of_sindragosa.ticking
--  actions+=/call_action_list,name=bos_ticking,if=talent.breath_of_sindragosa.enabled&dot.breath_of_sindragosa.ticking
--  actions+=/call_action_list,name=gs_ticking,if=talent.gathering_storm.enabled&buff.remorseless_winter.remains&!talent.breath_of_sindragosa.enabled

--  actions.bos=frost_strike,if=talent.icy_talons.enabled&buff.icy_talons.remains<1.5&cooldown.breath_of_sindragosa.remains>6
--  actions.bos+=/remorseless_winter,if=talent.gathering_storm.enabled
--  actions.bos+=/howling_blast,target_if=!dot.frost_fever.ticking
--  actions.bos+=/breath_of_sindragosa,if=runic_power>=50&(!equipped.140806|cooldown.hungering_Rune_weapon.remains<10)
--  actions.bos+=/frost_strike,if=runic_power>=90&set_bonus.tier19_4pc
--  actions.bos+=/remorseless_winter,if=buff.rime.react&equipped.132459
--  actions.bos+=/howling_blast,if=buff.rime.react&(dot.remorseless_winter.ticking|cooldown.remorseless_winter.remains>1.5|(!equipped.132459&!talent.gathering_storm.enabled))
--  actions.bos+=/obliterate,if=!buff.rime.react&!(talent.gathering_storm.enabled&!(cooldown.remorseless_winter.remains>2|Runes()>4))&Runes()>3
--  actions.bos+=/frost_strike,if=runic_power>=70|((talent.gathering_storm.enabled&cooldown.remorseless_winter.remains<3&cooldown.breath_of_sindragosa.remains>10)&Runes()<5)|(buff.gathering_storm.stack=10&cooldown.breath_of_sindragosa.remains>15)
--  actions.bos+=/obliterate,if=!buff.rime.react&(!talent.gathering_storm.enabled|(cooldown.remorseless_winter.remains>2|Runes()>4))
--  actions.bos+=/horn_of_winter,if=cooldown.breath_of_sindragosa.remains>15&runic_power<=70&Runes()<4
--  actions.bos+=/frost_strike,if=cooldown.breath_of_sindragosa.remains>15
--  actions.bos+=/remorseless_winter,if=cooldown.breath_of_sindragosa.remains>10

--  actions.bos_ticking=howling_blast,target_if=!dot.frost_fever.ticking
--  actions.bos_ticking+=/remorseless_winter,if=runic_power>=30&((buff.rime.react&equipped.132459)|(talent.gathering_storm.enabled&(dot.remorseless_winter.remains<=gcd|!dot.remorseless_winter.ticking)))
--  actions.bos_ticking+=/howling_blast,if=((runic_power>=20&set_bonus.tier19_4pc)|runic_power>=30)&buff.rime.react
--  actions.bos_ticking+=/obliterate,if=runic_power<=75|Runes()>3
--  actions.bos_ticking+=/remorseless_winter,if=(buff.rime.react&equipped.132459)|(talent.gathering_storm.enabled&(dot.remorseless_winter.remains<=gcd|!dot.remorseless_winter.ticking))
--  actions.bos_ticking+=/howling_blast,if=buff.rime.react
--  actions.bos_ticking+=/horn_of_winter,if=runic_power<70&!buff.hungering_Rune_weapon.up&Runes()<5
--  actions.bos_ticking+=/hungering_Rune_weapon,if=equipped.140806&(runic_power<30|(runic_power<70&talent.gathering_storm.enabled)|(talent.horn_of_winter.enabled&talent.gathering_storm.enabled&runic_power<55))&!buff.hungering_Rune_weapon.up&Runes()<2
--  actions.bos_ticking+=/hungering_Rune_weapon,if=talent.runic_attenuation.enabled&runic_power<30&!buff.hungering_Rune_weapon.up&Runes()<2
--  actions.bos_ticking+=/hungering_Rune_weapon,if=runic_power<35&!buff.hungering_Rune_weapon.up&Runes()<1
--  actions.bos_ticking+=/hungering_Rune_weapon,if=runic_power<25&!buff.hungering_Rune_weapon.up&Runes()<2
--  actions.bos_ticking+=/empower_Rune_weapon,if=runic_power<20
--  actions.bos_ticking+=/remorseless_winter,if=talent.gathering_storm.enabled|!set_bonus.tier19_4pc|runic_power<30

--  actions.generic=frost_strike,if=!talent.shattering_strikes.enabled&(buff.icy_talons.remains<1.5&talent.icy_talons.enabled)
--  actions.generic+=/frost_strike,if=talent.shattering_strikes.enabled&debuff.razorice.stack=5
--  actions.generic+=/howling_blast,target_if=!dot.frost_fever.ticking
--  actions.generic+=/remorseless_winter,if=(buff.rime.react&equipped.132459&!(buff.obliteration.up&spell_targets.howling_blast<2))|talent.gathering_storm.enabled
--  actions.generic+=/howling_blast,if=buff.rime.react&!(buff.obliteration.up&spell_targets.howling_blast<2)&!(equipped.132459&talent.gathering_storm.enabled)
--  actions.generic+=/howling_blast,if=buff.rime.react&!(buff.obliteration.up&spell_targets.howling_blast<2)&equipped.132459&talent.gathering_storm.enabled&(debuff.perseverance_of_the_ebon_martyr.up|cooldown.remorseless_winter.remains>3)
--  actions.generic+=/obliterate,if=!buff.obliteration.up&(equipped.132366&talent.frozen_pulse.enabled&(set_bonus.tier19_2pc=1|set_bonus.tier19_4pc=1))
--  actions.generic+=/frost_strike,if=runic_power.deficit<=10
--  actions.generic+=/frost_strike,if=buff.obliteration.up&!buff.killing_machine.react
--  actions.generic+=/remorseless_winter,if=spell_targets.remorseless_winter>=2&!(talent.frostscythe.enabled&buff.killing_machine.react&spell_targets.frostscythe>=2)
--  actions.generic+=/frostscythe,if=(buff.killing_machine.react&spell_targets.frostscythe>=2)
--  actions.generic+=/glacial_advance,if=spell_targets.glacial_advance>=2
--  actions.generic+=/frostscythe,if=spell_targets.frostscythe>=3
--  actions.generic+=/obliterate,if=buff.killing_machine.react
--  actions.generic+=/frost_strike,if=talent.gathering_storm.enabled&talent.murderous_efficiency.enabled&(set_bonus.tier19_2pc=1|set_bonus.tier19_4pc=1)
--  actions.generic+=/frost_strike,if=(talent.horn_of_winter.enabled|talent.hungering_Rune_weapon.enabled)&(set_bonus.tier19_2pc=1|set_bonus.tier19_4pc=1)
--  actions.generic+=/obliterate
--  actions.generic+=/glacial_advance
--  actions.generic+=/horn_of_winter,if=!buff.hungering_Rune_weapon.up
--  actions.generic+=/frost_strike
--  actions.generic+=/remorseless_winter,if=talent.frozen_pulse.enabled
--  actions.generic+=/empower_Rune_weapon
--  actions.generic+=/hungering_Rune_weapon,if=!buff.hungering_Rune_weapon.up

--  actions.gs_ticking=frost_strike,if=buff.icy_talons.remains<1.5&talent.icy_talons.enabled
--  actions.gs_ticking+=/remorseless_winter
--  actions.gs_ticking+=/howling_blast,if=!dot.frost_fever.ticking
--  actions.gs_ticking+=/howling_blast,if=buff.rime.react&!(buff.obliteration.up&spell_targets.howling_blast<2)
--  actions.gs_ticking+=/obliteration,if=(!talent.frozen_pulse.enabled|(Runes()<2&runic_power<28))
--  actions.gs_ticking+=/obliterate,if=Runes()>3|buff.killing_machine.react|buff.obliteration.up
--  actions.gs_ticking+=/frost_strike,if=runic_power>80|(buff.obliteration.up&!buff.killing_machine.react)
--  actions.gs_ticking+=/obliterate
--  actions.gs_ticking+=/horn_of_winter,if=runic_power<70&!buff.hungering_Rune_weapon.up
--  actions.gs_ticking+=/glacial_advance
--  actions.gs_ticking+=/frost_strike
--  actions.gs_ticking+=/hungering_Rune_weapon,if=!buff.hungering_Rune_weapon.up
--  actions.gs_ticking+=/empower_Rune_weapon

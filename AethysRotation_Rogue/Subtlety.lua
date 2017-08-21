--- Localize Vars
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
local pairs = pairs;
local tableinsert = table.insert;


--- APL Local Vars
-- Commons
  local Everyone = AR.Commons.Everyone;
  local Rogue = AR.Commons.Rogue;
-- Spells
  if not Spell.Rogue then Spell.Rogue = {}; end
  Spell.Rogue.Subtlety = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    Backstab                      = Spell(53),
    Eviscerate                    = Spell(196819),
    Nightblade                    = Spell(195452),
    ShadowBlades                  = Spell(121471),
    ShadowDance                   = Spell(185313),
    ShadowDanceBuff               = Spell(185422),
    Shadowstrike                  = Spell(185438),
    ShurikenStorm                 = Spell(197835),
    ShurikenToss                  = Spell(114014),
    Stealth                       = Spell(1784),
    SymbolsofDeath                = Spell(212283),
    Vanish                        = Spell(1856),
    VanishBuff                    = Spell(115193),
    ShurikenComboBuff             = Spell(245640),
    -- Talents
    Alacrity                      = Spell(193539),
    AlacrityBuff                  = Spell(193538),
    Anticipation                  = Spell(114015),
    DarkShadow                    = Spell(245687),
    DeathfromAbove                = Spell(152150),
    DeeperStratagem               = Spell(193531),
    EnvelopingShadows             = Spell(238104),
    Gloomblade                    = Spell(200758),
    MarkedforDeath                = Spell(137619),
    MasterofShadows               = Spell(196976),
    MasterofShadowsBuff           = Spell(196980),
    MasterOfSubtlety              = Spell(31223),
    MasterOfSubtletyBuff          = Spell(31665),
    ShadowFocus                   = Spell(108209),
    Subterfuge                    = Spell(108208),
    Vigor                         = Spell(14983),
    -- Artifact
    WeakPoint                     = Spell(238068),
    FeedingFrenzy                 = Spell(242705),
    FinalityEviscerate            = Spell(197496),
    FinalityNightblade            = Spell(197498),
    FlickeringShadows             = Spell(197256),
    GoremawsBite                  = Spell(209782),
    LegionBlade                   = Spell(214930),
    ShadowFangs                   = Spell(221856),
    ShadowsoftheUncrowned         = Spell(241154),
    -- Defensive
    CrimsonVial                   = Spell(185311),
    Feint                         = Spell(1966),
    -- Utility
    Blind                         = Spell(2094),
    CheapShot                     = Spell(1833),
    Kick                          = Spell(1766),
    KidneyShot                    = Spell(408),
    Sprint                        = Spell(2983),
    -- Legendaries
    DreadlordsDeceit              = Spell(228224),
    TheFirstoftheDead             = Spell(248210),
    -- Misc
    PoolEnergy                    = Spell(9999000010),
  };
  local S = Spell.Rogue.Subtlety;
  S.Eviscerate:RegisterDamage(
    -- Eviscerate DMG Formula (Pre-Mitigation):
    --  AP * CP * EviscR1_APCoef * EviscR2_M * Aura_M * F:Evisc_M * ShadowFangs_M * MoS_M * DS_M * SoD_M * ShC_M * Mastery_M * Versa_M * LegionBlade_M * ShUncrowned_M
    function ()
      return
        -- Attack Power
        Player:AttackPower() *
        -- Combo Points
        Rogue.CPSpend() *
        -- Eviscerate R1 AP Coef
        0.98130 *
        -- Eviscerate R2 Multiplier
        1.5 *
        -- Aura Multiplier (SpellID: 137035)
        1.25 *
        -- Finality: Eviscerate Multiplier
        (Player:Buff(S.FinalityEviscerate) and 1 + Player:Buff(S.FinalityEviscerate, 17) / 100 or 1) *
        -- Shadow Fangs Multiplier
        (S.ShadowFangs:ArtifactEnabled() and 1.04 or 1) *
        -- Master of Subtlety Multiplier
        (Player:Buff(S.MasterOfSubtletyBuff) and 1.1 or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Symbols of Death Multiplier
        (Player:Buff(S.SymbolsofDeath) and 1.15+(AC.Tier20_2Pc and 0.1 or 0) or 1) *
        -- Shuriken Combo Multiplier
        (Player:Buff(S.ShurikenComboBuff) and 1 + Player:Buff(S.ShurikenComboBuff, 17) / 100 or 1) *
        -- Mastery Finisher Multiplier
        (1 + Player:MasteryPct()/100) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct()/100) *
        -- Legion Blade Multiplier
        (S.LegionBlade:ArtifactEnabled() and 1.05 or 1) *
        -- Shadows of the Uncrowned Multiplier
        (S.ShadowsoftheUncrowned:ArtifactEnabled() and 1.1 or 1);
    end
  );
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Subtlety = {
    -- Legendaries
    DenialoftheHalfGiants         = Item(137100, {9}),
    DraughtofSouls                = Item(140808, {13, 14}),
    InsigniaOfRavenholdt          = Item(137049, {11, 12}),
    MantleoftheMasterAssassin     = Item(144236, {3}),
    ShadowSatyrsWalk              = Item(137032, {8}),
    TheFirstoftheDead             = Item(151818, {10}),
  };
  local I = Item.Rogue.Subtlety;
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD; -- Used for cycling
  local NightbladeThreshold; -- Used to compute the NB threshold (Cycling Performance)
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Subtlety = AR.GUISettings.APL.Rogue.Subtlety
  };

-- Melee Is In Range w/ DfA Handler
local function IsInMeleeRange ()
  return (Target:IsInRange(5) or S.DeathfromAbove:TimeSinceLastCast() <= 1.5) and true or false;
end
-- Shadow Satry's Walk Bug
local ExtraSSWRefundTable = {
  [101002] = 2, -- Nighthold: Krosus
  [114537] = 2 -- Trial of Valor: Helya
};
local function SSW_RefundOffset ()
  return ExtraSSWRefundTable[Target:NPCID()] or 0;
end

-- APL Action Lists (and Variables)
-- actions.precombat+=/variable,name=ssw_refund,value=equipped.shadow_satyrs_walk*(6+ssw_refund_offset)
local function SSW_Refund ()
  return I.ShadowSatyrsWalk:IsEquipped() and 6+SSW_RefundOffset() or 0;
end
-- actions.precombat+=/variable,name=stealth_threshold,value=(65+talent.vigor.enabled*35+talent.master_of_shadows.enabled*10+variable.ssw_refund)
local function Stealth_Threshold ()
  return 65 + (S.Vigor:IsAvailable() and 35 or 0) + (S.MasterofShadows:IsAvailable() and 10 or 0) + SSW_Refund();
end
-- actions.precombat+=/variable,name=shd_fractional,value=1.725+0.725*talent.enveloping_shadows.enabled
local function ShD_Fractional ()
  return 1.725 + (S.EnvelopingShadows:IsAvailable() and 0.725 or 0);
end
-- actions=variable,name=dsh_dfa,value=talent.death_from_above.enabled&talent.dark_shadow.enabled&spell_targets.death_from_above<4
local function DSh_DfA ()
  return S.DeathfromAbove:IsAvailable() and S.DarkShadow:IsAvailable() and Cache.EnemiesCount[8] < 4;
end
-- # Finishers
-- ReturnSpellOnly has been added to Predict Finisher in case of Stealth Macros (happens only when ShD Charges ~= 3)
local function Finish (ReturnSpellOnly)
  if S.Nightblade:IsCastable() then
    NightbladeThreshold = (6+Rogue.CPSpend()*(2+(AC.Tier19_2Pc and 2 or 0)))*0.3;
    -- actions.finish=nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&(mantle_duration=0|remains<=mantle_duration)&((refreshable&(!finality|buff.finality_nightblade.up|variable.dsh_dfa))|remains<tick_time*2)&(spell_targets.shuriken_storm<4&!variable.dsh_dfa|!buff.symbols_of_death.up)
    if IsInMeleeRange() and (not S.DarkShadow:IsAvailable() or not Player:Buff(S.ShadowDanceBuff))
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.Nightblade)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
      and (Rogue.MantleDuration() == 0 or Target:DebuffRemains(S.Nightblade) <= Rogue.MantleDuration())
      and ((Target:DebuffRefreshable(S.Nightblade, NightbladeThreshold) and (not AC.Finality(Target) or Player:Buff(S.FinalityNightblade) or DSh_DfA()))
        or Target:DebuffRemains(S.Nightblade) < 4)
      and (Cache.EnemiesCount[8] < 4 and not DSh_DfA() or not Player:Buff(S.SymbolsofDeath)) then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if AR.Cast(S.Nightblade) then return ""; end
      end
    end
    -- actions.finish+=/nightblade,cycle_targets=1,if=(!talent.death_from_above.enabled|set_bonus.tier19_2pc)&(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>12&mantle_duration=0&((refreshable&(!finality|buff.finality_nightblade.up|variable.dsh_dfa))|remains<tick_time*2)&(spell_targets.shuriken_storm<4&!variable.dsh_dfa|!buff.symbols_of_death.up)
    if AR.AoEON() and (not S.DeathfromAbove:IsAvailable() or AC.Tier19_2Pc) and (not S.DarkShadow:IsAvailable() or not Player:Buff(S.ShadowDanceBuff)) and Rogue.MantleDuration() == 0 then
      BestUnit, BestUnitTTD = nil, 12;
      for _, Unit in pairs(Cache.Enemies[5]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemains(S.Nightblade))
          and Everyone.CanDoTUnit(Unit, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
          and ((Unit:DebuffRefreshable(S.Nightblade, NightbladeThreshold) and (not AC.Finality(Unit) or Player:Buff(S.FinalityNightblade) or DSh_DfA()))
            or Unit:DebuffRemains(S.Nightblade) < 4)
          and (Cache.EnemiesCount[8] < 4 and not DSh_DfA() or not Player:Buff(S.SymbolsofDeath)) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Nightblade);
      end
    end
    -- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5+(combo_points=6)&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
    if IsInMeleeRange() and Target:DebuffRemains(S.Nightblade) < S.SymbolsofDeath:CooldownRemains() + 10
      and S.SymbolsofDeath:CooldownRemains() <= 5 + (Player:ComboPoints() == 6 and 1 or 0)
      and (Target:FilteredTimeToDie(">", 5 + S.SymbolsofDeath:CooldownRemains(), -Target:DebuffRemains(S.Nightblade)) or Target:TimeToDieIsNotValid()) then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if AR.Cast(S.Nightblade) then return ""; end
      end
    end
  end
  -- actions.finish+=/death_from_above,if=!talent.dark_shadow.enabled|(!buff.shadow_dance.up|spell_targets>=4)&(buff.symbols_of_death.up|cooldown.symbols_of_death.remains>=10+set_bonus.tier20_4pc*5)&buff.the_first_of_the_dead.remains<1&(buff.finality_eviscerate.up|spell_targets.shuriken_storm<4)
  if S.DeathfromAbove:IsCastable() and Target:IsInRange(15)
    and (not S.DarkShadow:IsAvailable()
      or (not Player:Buff(S.ShadowDanceBuff) or Cache.EnemiesCount[8] >= 4)
        and (Player:Buff(S.SymbolsofDeath) or S.SymbolsofDeath:CooldownRemains() >= 10 + (AC.Tier20_4Pc and 5 or 0))
        and Player:BuffRemains(S.TheFirstoftheDead) < 1
        and (Player:Buff(S.FinalityEviscerate) or Cache.EnemiesCount[8] < 4)) then
    if ReturnSpellOnly then
      return S.DeathfromAbove;
    else
      if AR.Cast(S.DeathfromAbove) then return ""; end
    end
  end
  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and IsInMeleeRange() then
    if ReturnSpellOnly then
      return S.Eviscerate;
    else
      if AR.Cast(S.Eviscerate) then return ""; end
    end
  end
  return false;
end
local MacroTable;
local function StealthMacro (StealthSpell)
  MacroTable = {StealthSpell};
  -- Will we do a Eviscerate (ShD Charges ~= 3) or ShurikenStorm or Shadowstrike?
  -- Shadow Dance
  if StealthSpell:ID() == S.ShadowDance:ID() then
    -- actions.stealthed=call_action_list,name=finish,if=combo_points>=5&(spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
    if Player:ComboPoints() >= 5 and (Cache.EnemiesCount[8] >= 3 + (I.ShadowSatyrsWalk:IsEquipped() and 1 or 0)
        or (Rogue.MantleDuration() <= 1.3 and Rogue.MantleDuration()-Player:GCDRemains() >= 0.3)) then
      tableinsert(MacroTable, Finish(true));
    -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1&buff.the_dreadlords_deceit.stack>=29))
    elseif S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
        and ((Player:ComboPointsDeficit() >= 3 and Cache.EnemiesCount[8] >= 3 + (I.ShadowSatyrsWalk:IsEquipped() and 1 or 0))
          or (AR.AoEON() and IsInMeleeRange() and Player:ComboPointsDeficit() >= 1 and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
      tableinsert(MacroTable, S.ShurikenStorm);
    -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&combo_points.deficit<3+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
    elseif Player:ComboPoints() >= 5
      and Player:ComboPointsDeficit() < 3 + (Player:Buff(S.ShadowBlades) and 1 or 0) - (I.MantleoftheMasterAssassin:IsEquipped() and 1 or 0) then
      tableinsert(MacroTable, Finish(true));
    -- actions.stealthed+=/shadowstrike
    else
      tableinsert(MacroTable, S.Shadowstrike);
    end
  -- Vanish
  elseif StealthSpell:ID() == S.Vanish:ID() then
    -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1&buff.the_dreadlords_deceit.stack>=29))
    if S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
        and ((Player:ComboPointsDeficit() >= 3 and Cache.EnemiesCount[8] >= 3 + (I.ShadowSatyrsWalk:IsEquipped() and 1 or 0))
          or (AR.AoEON() and IsInMeleeRange() and Player:ComboPointsDeficit() >= 1 and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
      tableinsert(MacroTable, S.ShurikenStorm);
    else
      tableinsert(MacroTable, S.Shadowstrike);
    end
  -- Shadowmeld
  else
    tableinsert(MacroTable, S.Shadowstrike);
  end
  return AR.CastQueue(unpack(MacroTable));
end
-- # Builders
local function Build ()
  -- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2+buff.the_first_of_the_dead.up
  if Cache.EnemiesCount[8] >= 2 + (Player:Buff(S.TheFirstoftheDead) and 1 or 0) and S.ShurikenStorm:IsCastable() then
    if AR.Cast(S.ShurikenStorm) then return ""; end
  end
  if IsInMeleeRange() then
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if AR.Cast(S.Gloomblade) then return ""; end
    -- actions.build+=/backstab
    elseif S.Backstab:IsCastable() then
      if AR.Cast(S.Backstab) then return ""; end
    end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  if IsInMeleeRange() then
    if AR.CDsON() then
      -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
        -- TODO: Add Potion Suggestion
      -- actions.cds+=/use_item,name=specter_of_betrayal,if=!buff.stealth.up&!buff.vanish.up
        -- TODO: Trinkets handling
      -- Racials
      if Player:IsStealthed(true, false) then
        -- actions.cds+=/blood_fury,if=stealthed.rogue
        if S.BloodFury:IsCastable() then
          if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions.cds+=/berserking,if=stealthed.rogue
        if S.Berserking:IsCastable() then
          if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
        if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 70 then
          if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
        end
      end
    end
    if S.SymbolsofDeath:IsCastable() then
      if not S.DeathfromAbove:IsAvailable() then
        -- actions.cds+=/symbols_of_death,if=!talent.death_from_above.enabled&((time>10&energy.deficit>=40-stealthed.all*30)|(time<10&dot.nightblade.ticking))
        -- Note: Using the predicted energy deficit to prevent pop and depop of the icon in the middle of GCD.
        if (AC.CombatTime() > 10 and Player:EnergyDeficitPredicted() >= 40 - (Player:IsStealthed(true, true) and 30 or 0)) or (AC.CombatTime() < 10 and Target:Debuff(S.Nightblade)) then
          if AR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return ""; end
        end
      else
        -- actions.cds+=/symbols_of_death,if=(talent.death_from_above.enabled&cooldown.death_from_above.remains<=3&(dot.nightblade.remains>=cooldown.death_from_above.remains+3|target.time_to_die-dot.nightblade.remains<=6)&(time>=3|set_bonus.tier20_4pc|equipped.the_first_of_the_dead))|target.time_to_die-remains<=10
        if S.DeathfromAbove:CooldownRemains() <= 3 and (Target:DebuffRemains(S.Nightblade) >= S.DeathfromAbove:CooldownRemains() + 3 or Target:FilteredTimeToDie("<=", 6) or not Target:TimeToDieIsNotValid()) and (AC.CombatTime() >= 3 or AC.Tier20_4Pc or I.TheFirstoftheDead:IsEquipped()) or Target:FilteredTimeToDie("<=", 10) or Target:TimeToDieIsNotValid() then
          if AR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return ""; end
        end
      end
    end
    if AR.CDsON() then
      -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
      -- Note: Done at the start of the Rotation (Rogue Commmon)
      -- actions.cds+=/marked_for_death,if=raid_event.adds.in>40&!stealthed.all&combo_points.deficit>=cp_max_spend
      if S.MarkedforDeath:IsCastable() then
        if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()) or (Settings.Subtlety.STMfDAsDPSCD and not Player:IsStealthed(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend()) then
          if AR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast"; end
        elseif Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
          AR.CastSuggested(S.MarkedforDeath);
        end
      end
      -- actions.cds+=/shadow_blades,if=(time>10&combo_points.deficit>=2+stealthed.all-equipped.mantle_of_the_master_assassin)|(time<10&(!talent.marked_for_death.enabled|combo_points.deficit>=3|dot.nightblade.ticking))
      if S.ShadowBlades:IsCastable() and not Player:Buff(S.ShadowBlades)
        and ((AC.CombatTime() > 10 and Player:ComboPointsDeficit() >= 2 + (Player:IsStealthed(true, true) and 1 or 0) - (I.MantleoftheMasterAssassin:IsEquipped() and 1 or 0))
          or (AC.CombatTime() < 10 and (not S.MarkedforDeath:IsAvailable() or Player:ComboPointsDeficit() >= 3 or Target:Debuff(S.Nightblade)))) then
        if AR.Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return ""; end
      end
      -- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=variable.ShD_Fractional&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
      if S.GoremawsBite:IsCastable() and not Player:IsStealthed(true, true) and S.ShadowDance:ChargesFractional() <= ShD_Fractional()
          and ((Player:ComboPointsDeficit() >= 4-(AC.CombatTime() < 10 and 2 or 0)
              and Player:EnergyDeficit() > 50+(S.Vigor:IsAvailable() and 25 or 0)-(AC.CombatTime() >= 10 and 15 or 0))
            or (Player:ComboPointsDeficit() >= 1 and Target:TimeToDie(10) < 8)) then
        if AR.Cast(S.GoremawsBite) then return ""; end
      end
      -- actions.cds+=/vanish,if=energy>=55-talent.shadow_focus.enabled*10&variable.dsh_dfa&(!equipped.mantle_of_the_master_assassin|buff.symbols_of_death.up)&cooldown.shadow_dance.charges_fractional<=variable.shd_fractional&!buff.shadow_dance.up&!buff.stealth.up&mantle_duration=0&(dot.nightblade.remains>=cooldown.death_from_above.remains+6|target.time_to_die-dot.nightblade.remains<=6)&cooldown.death_from_above.remains<=1|target.time_to_die<=7
      -- Disable vanish while mantle buff is up, we put mantle_duration=0 as a mandatory condition. This isn't seen in SimC since combat length < 5s are rare, might be worth to port it tho. It won't hurt.
      -- Removed the TTD part for now.
      if AR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
        and Rogue.MantleDuration() == 0 and DSh_DfA() and (not I.MantleoftheMasterAssassin:IsEquipped() or Player:Buff(S.SymbolsofDeath))
          and S.ShadowDance:ChargesFractional() <= ShD_Fractional() and not Player:Buff(S.ShadowDanceBuff) and not Player:Buff(S.Stealth)
          and (Target:DebuffRemains(S.Nightblade) >= S.DeathfromAbove:CooldownRemains() + 6
            or Target:FilteredTimeToDie("<=", 6, -Target:DebuffRemains(S.Nightblade)) or not Target:TimeToDieIsNotValid())
          and S.DeathfromAbove:CooldownRemains() <= 1 then
        -- actions.cds+=/pool_resource,for_next=1,extra_amount=65-talent.shadow_focus.enabled*10
        if Player:EnergyPredicted() < 55 - (S.ShadowFocus:IsAvailable() and 10 or 0) then
          if AR.Cast(S.PoolEnergy) then return "Pool for Vanish"; end
        end
        if StealthMacro(S.Vanish) then return ""; end
      end
      -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=4+talent.subterfuge.enabled
      if S.ShadowDance:IsCastable() and not Player:Buff(S.ShadowDance) and Target:FilteredTimeToDie("<=", 4 + (S.Subterfuge:IsAvailable() and 1 or 0)) then
        if StealthMacro(S.ShadowDance) then return ""; end
      end
    end
  end
  return false;
end
-- # Stealth Cooldowns
local function Stealth_CDs ()
  if IsInMeleeRange() then
    -- actions.stealth_cds=vanish,if=!variable.dsh_dfa&mantle_duration=0&cooldown.shadow_dance.charges_fractional<variable.shd_fractional+(equipped.mantle_of_the_master_assassin&time<30)*0.3&(!equipped.mantle_of_the_master_assassin|buff.symbols_of_death.up)
    if AR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and not DSh_DfA() and Rogue.MantleDuration() == 0
      and S.ShadowDance:ChargesFractional() < ShD_Fractional()+(I.MantleoftheMasterAssassin:IsEquipped() and AC.CombatTime() < 30 and 0.3 or 0)
      and (not I.MantleoftheMasterAssassin:IsEquipped() or Player:Buff(S.SymbolsofDeath)) then
      if StealthMacro(S.Vanish) then return ""; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=charges_fractional>=variable.shd_fractional
    -- actions.stealth_cds+=/shadow_dance,if=charges_fractional>=variable.shd_fractional|target.time_to_die<cooldown.symbols_of_death.remains
    if (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and (S.ShadowDance:ChargesFractional() >= ShD_Fractional()
        or (Target:IsInBossList() and Target:FilteredTimeToDie("<", Player:BuffRemains(S.SymbolsofDeath)))) then
      if StealthMacro(S.ShadowDance) then return ""; end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10+variable.ssw_refund
    if AR.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and GetUnitSpeed("player") == 0 and Player:EnergyDeficit() > 10+SSW_Refund() then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
      if Player:EnergyPredicted() < 40 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Shadowmeld"; end
      end
      if StealthMacro(S.Shadowmeld) then return ""; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=!variable.dsh_dfa&combo_points.deficit>=2+talent.subterfuge.enabled*2&(buff.symbols_of_death.remains>=1.2+gcd.remains|cooldown.symbols_of_death.remains>=12+(talent.dark_shadow.enabled&set_bonus.tier20_4pc)*3-(!talent.dark_shadow.enabled&set_bonus.tier20_4pc)*4|mantle_duration>0)&(spell_targets.shuriken_storm>=4|!buff.the_first_of_the_dead.up)
    if (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0))) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1 and not DSh_DfA()
      and Player:ComboPointsDeficit() >= 2 + (S.Subterfuge:IsAvailable() and 2 or 0)
      and (Player:BuffRemains(S.SymbolsofDeath) >= 1.2 + Player:GCDRemains() or S.SymbolsofDeath:CooldownRemains() >= 12 + (S.DarkShadow:IsAvailable() and AC.Tier20_4Pc and 3 or 0) - (not S.DarkShadow:IsAvailable() and AC.Tier20_4Pc and 4 or 0))
      and (Cache.EnemiesCount[8] >= 4 or not Player:Buff(S.TheFirstoftheDead)) then
      if StealthMacro(S.ShadowDance) then return ""; end
    end
  end
  return false;
end
-- # Stealth Action List Starter
local function Stealth_ALS ()
  -- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold-25*(!cooldown.goremaws_bite.up&!buff.feeding_frenzy.up)&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=variable.shd_fractional|energy.deficit>=10)
  if (Player:EnergyDeficit() <= Stealth_Threshold() - ((not S.GoremawsBite:CooldownUp() and not Player:Buff(S.FeedingFrenzy)) and 25 or 0)
    and (not I.ShadowSatyrsWalk:IsEquipped() or S.ShadowDance:ChargesFractional() >= ShD_Fractional() or Player:EnergyDeficit() >= 10))
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=mantle_duration>2.3
    or Rogue.MantleDuration() > 2.3
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=4
    or Cache.EnemiesCount[8] >= 4
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
    or (S.Shadowmeld:CooldownUp() and not S.Vanish:CooldownUp() and S.ShadowDance:Charges() <= 1)
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)
    or (Target:IsInBossList() and Target:TimeToDie() < 12*S.ShadowDance:ChargesFractional()*(I.ShadowSatyrsWalk:IsEquipped() and 1.5 or 1)) then
   return Stealth_CDs();
  end
  return false;
end
-- # Stealthed Rotation
local function Stealthed ()
  -- # If stealth is up, we really want to use Shadowstrike to benefits from the passive bonus, even if we are at max cp (from the precombat MfD).
  -- actions.stealthed=shadowstrike,if=buff.stealth.up
  if S.Shadowstrike:IsCastable() and IsInMeleeRange() and Player:Buff(S.Stealth) then
    if AR.Cast(S.Shadowstrike) then return ""; end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&(spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
  if Player:ComboPoints() >= 5 and (Cache.EnemiesCount[8] >= 3 + (I.ShadowSatyrsWalk:IsEquipped() and 1 or 0)
      or (Rogue.MantleDuration() <= 1.3 and Rogue.MantleDuration()-Player:GCDRemains() >= 0.3)) then
    return Finish();
  end
  -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=2+equipped.insignia_of_ravenholdt&spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1&buff.the_dreadlords_deceit.stack>=29))
  if S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
      and ((Player:ComboPointsDeficit() >= 2 + (I.InsigniaOfRavenholdt:IsEquipped() and 1 or 0) and Cache.EnemiesCount[8] >= 3 + (I.ShadowSatyrsWalk:IsEquipped() and 1 or 0))
        or (AR.AoEON() and IsInMeleeRange() and Player:ComboPointsDeficit() >= 1 and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
    if AR.Cast(S.ShurikenStorm) then return ""; end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&combo_points.deficit<3+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
  if Player:ComboPoints() >= 5
    and Player:ComboPointsDeficit() < 3 + (Player:Buff(S.ShadowBlades) and 1 or 0) - (I.MantleoftheMasterAssassin:IsEquipped() and 1 or 0) then
    return Finish();
  end
  -- actions.stealthed+=/shadowstrike
  if S.Shadowstrike:IsCastable() and IsInMeleeRange() then
    if AR.Cast(S.Shadowstrike) then return ""; end
  end
  return false;
end
local SappedSoulSpells = {
  {S.Kick, "Cast Kick (Sappel Soul)", function () return IsInMeleeRange; end},
  {S.Feint, "Cast Feint (Sappel Soul)", function () return true; end},
  {S.CrimsonVial, "Cast Crimson Vial (Sappel Soul)", function () return true; end}
};
local function MythicDungeon ()
  -- Sapped Soul
  if AC.MythicDungeon() == "Sapped Soul" then
    for i = 1, #SappedSoulSpells do
      if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
        AR.ChangePulseTimer(1);
        AR.Cast(SappedSoulSpells[i][1]);
        return SappedSoulSpells[i][2];
      end
    end
  end
  return false;
end
local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
    -- Kidney Shot
    if IsInMeleeRange() and S.KidneyShot:IsCastable() and Player:ComboPoints() > 0 then
      if AR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end

-- APL Main
local function APL ()
  -- Spell ID Changes check
  S.Stealth = S.Subterfuge:IsAvailable() and Spell(115191) or Spell(1784); -- w/ or w/o Subterfuge Talent
  -- Unit Update
  AC.GetEnemies(8); -- Shuriken Storm & Death from Above
  AC.GetEnemies(5); -- Melee
  Everyone.AoEToggleEnemiesUpdate();
  --- Defensives
    -- Crimson Vial
    ShouldReturn = Rogue.CrimsonVial (S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = Rogue.Feint (S.Feint);
    if ShouldReturn then return ShouldReturn; end
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = Rogue.Stealth(S.Stealth);
      if ShouldReturn then return ShouldReturn; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() and IsInMeleeRange() then
        -- # If stealth is up, we really want to use Shadowstrike to benefits from the passive bonus, even if we are at max cp (from the precombat MfD).
        -- Note: Hence why IsStealthed is above Finishers.
        if Player:IsStealthed(true, true) then
          if S.ShurikenStorm:IsCastable() and Cache.EnemiesCount[8] >= 3 + (I.ShadowSatyrsWalk:IsEquipped() and 1 or 0) then
            if AR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm (OOC)"; end
          elseif S.Shadowstrike:IsCastable() then
            if AR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (OOC)"; end
          end
        elseif Player:ComboPoints() >= 5 then
          if S.Nightblade:IsCastable() and not Target:Debuff(S.Nightblade)
            and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset) then
            if AR.Cast(S.Nightblade) then return "Cast Nightblade (OOC)"; end
          elseif S.Eviscerate:IsCastable() then
            if AR.Cast(S.Eviscerate) then return "Cast Eviscerate (OOC)"; end
          end
        elseif S.Backstab:IsCastable() then
          if AR.Cast(S.Backstab) then return "Cast Backstab (OOC)"; end
        end
      end
      return;
    end
  -- In Combat
    -- MfD Sniping
    Rogue.MfDSniping(S.MarkedforDeath);
    if Everyone.TargetIsValid() then
      -- Mythic Dungeon
      ShouldReturn = MythicDungeon();
      if ShouldReturn then return ShouldReturn; end
      -- Training Scenario
      ShouldReturn = TrainingScenario();
      if ShouldReturn then return ShouldReturn; end
      -- Interrupts
      Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, {
        {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
        {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end},
        {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:IsStealthed(true, true); end}
      });
      -- # This let us to use Shadow Dance right before the 2nd part of DfA lands. Only with Dark Shadow.
      -- actions+=/shadow_dance,if=talent.dark_shadow.enabled&(!stealthed.all|buff.subterfuge.up)&buff.death_from_above.up&buff.death_from_above.remains<=0.15
      -- Note: DfA execute time is 1.475s, the buff is modeled to lasts 1.475s on SimC, while it's 1s in-game. So we retrieve it from TimeSinceLastCast.
      if S.DarkShadow:IsAvailable() and (not Player:IsStealthed(true, true) or Player:Buff(S.Subterfuge)) and S.DeathfromAbove:TimeSinceLastCast() <= 1.325
        and (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
        and S.ShadowDance:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.ShadowDance:Charges() >= 1 then
          if AR.Cast(S.ShadowDance) then return "Cast Shadow Dance (DfA)"; end
      end
      -- # This is triggered only with DfA talent since we check shadow_dance even while the gcd is ongoing, it's purely for simulation performance.
      -- actions+=/wait,sec=0.1,if=buff.shadow_dance.up&gcd.remains>0
      -- actions+=/call_action_list,name=cds
      ShouldReturn = CDs();
      if ShouldReturn then return ShouldReturn; end
      -- actions+=/run_action_list,name=stealthed,if=stealthed.all
      if Player:IsStealthed(true, true) then
        ShouldReturn = Stealthed();
        if ShouldReturn then return ShouldReturn; end
        -- run_action_list forces the return
        if Player:Energy() < 30 then -- To avoid pooling icon spam
          if AR.Cast(S.PoolEnergy) then return "Stealthed Pooling"; end
        else
          return "Stealthed Pooling";
        end
      end
      -- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
      if S.Nightblade:IsCastable() and IsInMeleeRange()
        and (Target:FilteredTimeToDie(">", 6) or Target:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
        and Target:DebuffRemains(S.Nightblade) < Player:GCD() and Player:ComboPoints() >= 4 - (AC.CombatTime() < 10 and 2 or 0) then
        if AR.Cast(S.Nightblade) then return ""; end
      end
      if S.DarkShadow:IsAvailable() then
        -- actions+=/call_action_list,name=stealth_als,if=talent.dark_shadow.enabled&combo_points.deficit>=2+buff.shadow_blades.up&(dot.nightblade.remains>4+talent.subterfuge.enabled|cooldown.shadow_dance.charges_fractional>=1.9&(!equipped.denial_of_the_halfgiants|time>10))
        if Player:ComboPointsDeficit() >= 2 + (Player:Buff(S.ShadowBlades) and 1 or 0) and (Target:DebuffRemains(S.Nightblade) > 4 + (S.Subterfuge:IsAvailable() and 1 or 0) or (S.ShadowDance:ChargesFractional() >= 1.9 and (not I.DenialoftheHalfGiants:IsEquipped() or AC.CombatTime() > 10))) then
          ShouldReturn = Stealth_ALS();
          if ShouldReturn then return ShouldReturn; end
        end
      else
        -- actions+=/call_action_list,name=stealth_als,if=!talent.dark_shadow.enabled&(combo_points.deficit>=2+buff.shadow_blades.up|cooldown.shadow_dance.charges_fractional>=1.9+talent.enveloping_shadows.enabled)
        if Player:ComboPointsDeficit() >= 2 + (Player:Buff(S.ShadowBlades) and 1 or 0) or S.ShadowDance:ChargesFractional() >= 1.9 + (S.EnvelopingShadows:IsAvailable() and 1 or 0) then
          ShouldReturn = Stealth_ALS();
          if ShouldReturn then return ShouldReturn; end
        end
      end
      -- actions+=/call_action_list,name=finish,if=combo_points>=5+3*(buff.the_first_of_the_dead.up&talent.anticipation.enabled)+(talent.deeper_stratagem.enabled&!buff.shadow_blades.up&(mantle_duration=0|set_bonus.tier20_4pc)&(!buff.the_first_of_the_dead.up|variable.dsh_dfa))|(combo_points>=4&combo_points.deficit<=2&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)|(target.time_to_die<=1&combo_points>=3)
      if Player:ComboPoints() >= 5 + (Player:Buff(S.TheFirstoftheDead) and S.Anticipation:IsAvailable() and 3 or 0) + (S.DeeperStratagem:IsAvailable() and not Player:Buff(S.ShadowBlades) and (Rogue.MantleDuration() == 0 or AC.Tier20_4Pc)
          and (not Player:Buff(S.TheFirstoftheDead) or DSh_DfA()) and 1 or 0)
        or (Player:ComboPoints() >= 4 and Cache.EnemiesCount[8] >= 3 and Cache.EnemiesCount[8] <= 4)
        or (Target:FilteredTimeToDie("<=", 1) and Player:ComboPoints() >= 3) then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=finish,if=variable.dsh_dfa&cooldown.symbols_of_death.remains<=1&combo_points>=2&equipped.the_first_of_the_dead&spell_targets.shuriken_storm<2
      if DSh_DfA() and S.SymbolsofDeath:CooldownRemains() <= 1 and Player:ComboPoints() >= 2 and I.TheFirstoftheDead:IsEquipped() and Cache.EnemiesCount[8] < 2 then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
      if Player:EnergyDeficit() <= Stealth_Threshold() then
        ShouldReturn = Build();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Shuriken Toss Out of Range
      if S.ShurikenToss:IsCastable() and not Target:IsInRange(10) and Target:IsInRange(30) and not Player:IsStealthed(true, true) and not Player:Buff(S.Sprint)
        and Player:EnergyDeficit() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if AR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Shadowstrike:IsCastable() and IsInMeleeRange() then
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(261, APL);

-- Last Update: 08/21/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- # Defined variables that doesn't change during the fight.
-- actions.precombat+=/variable,name=ssw_refund,value=equipped.shadow_satyrs_walk*(6+ssw_refund_offset)
-- actions.precombat+=/variable,name=stealth_threshold,value=(65+talent.vigor.enabled*35+talent.master_of_shadows.enabled*10+variable.ssw_refund)
-- actions.precombat+=/variable,name=shd_fractional,value=1.725+0.725*talent.enveloping_shadows.enabled
-- actions.precombat+=/stealth
-- actions.precombat+=/marked_for_death,precombat=1
-- actions.precombat+=/potion

-- # Executed every time the actor is available.
-- actions=variable,name=dsh_dfa,value=talent.death_from_above.enabled&talent.dark_shadow.enabled&spell_targets.death_from_above<4
-- # This let us to use Shadow Dance right before the 2nd part of DfA lands. Only with Dark Shadow.
-- actions+=/shadow_dance,if=talent.dark_shadow.enabled&(!stealthed.all|buff.subterfuge.up)&buff.death_from_above.up&buff.death_from_above.remains<=0.15
-- # This is triggered only with DfA talent since we check shadow_dance even while the gcd is ongoing, it's purely for simulation performance.
-- actions+=/wait,sec=0.1,if=buff.shadow_dance.up&gcd.remains>0
-- actions+=/call_action_list,name=cds
-- # Fully switch to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
-- actions+=/call_action_list,name=stealth_als,if=talent.dark_shadow.enabled&combo_points.deficit>=2+buff.shadow_blades.up&(dot.nightblade.remains>4+talent.subterfuge.enabled|cooldown.shadow_dance.charges_fractional>=1.9&(!equipped.denial_of_the_halfgiants|time>10))
-- actions+=/call_action_list,name=stealth_als,if=!talent.dark_shadow.enabled&(combo_points.deficit>=2+buff.shadow_blades.up|cooldown.shadow_dance.charges_fractional>=1.9+talent.enveloping_shadows.enabled)
-- actions+=/call_action_list,name=finish,if=combo_points>=5+3*(buff.the_first_of_the_dead.up&talent.anticipation.enabled)+(talent.deeper_stratagem.enabled&!buff.shadow_blades.up&(mantle_duration=0|set_bonus.tier20_4pc)&(!buff.the_first_of_the_dead.up|variable.dsh_dfa))|(combo_points>=4&combo_points.deficit<=2&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)|(target.time_to_die<=1&combo_points>=3)
-- actions+=/call_action_list,name=finish,if=variable.dsh_dfa&cooldown.symbols_of_death.remains<=1&combo_points>=2&equipped.the_first_of_the_dead&spell_targets.shuriken_storm<2
-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold

-- # Builders
-- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2+buff.the_first_of_the_dead.up
-- actions.build+=/gloomblade
-- actions.build+=/backstab

-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
-- actions.cds+=/use_item,name=specter_of_betrayal,if=talent.dark_shadow.enabled&!buff.stealth.up&!buff.vanish.up&buff.shadow_dance.up&(buff.symbols_of_death.up|(!talent.death_from_above.enabled&((mantle_duration>=3|!equipped.mantle_of_the_master_assassin)|cooldown.vanish.remains>=43)))
-- actions.cds+=/use_item,name=specter_of_betrayal,if=!talent.dark_shadow.enabled&!buff.stealth.up&!buff.vanish.up&(mantle_duration>=3|!equipped.mantle_of_the_master_assassin)
-- actions.cds+=/blood_fury,if=stealthed.rogue
-- actions.cds+=/berserking,if=stealthed.rogue
-- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
-- actions.cds+=/symbols_of_death,if=!talent.death_from_above.enabled&((time>10&energy.deficit>=40-stealthed.all*30)|(time<10&dot.nightblade.ticking))
-- actions.cds+=/symbols_of_death,if=(talent.death_from_above.enabled&cooldown.death_from_above.remains<=3&(dot.nightblade.remains>=cooldown.death_from_above.remains+3|target.time_to_die-dot.nightblade.remains<=6)&(time>=3|set_bonus.tier20_4pc|equipped.the_first_of_the_dead))|target.time_to_die-remains<=10
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>40&!stealthed.all&combo_points.deficit>=cp_max_spend
-- actions.cds+=/shadow_blades,if=(time>10&combo_points.deficit>=2+stealthed.all-equipped.mantle_of_the_master_assassin)|(time<10&(!talent.marked_for_death.enabled|combo_points.deficit>=3|dot.nightblade.ticking))
-- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=variable.shd_fractional&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
-- actions.cds+=/pool_resource,for_next=1,extra_amount=55-talent.shadow_focus.enabled*10
-- actions.cds+=/vanish,if=energy>=55-talent.shadow_focus.enabled*10&variable.dsh_dfa&(!equipped.mantle_of_the_master_assassin|buff.symbols_of_death.up)&cooldown.shadow_dance.charges_fractional<=variable.shd_fractional&!buff.shadow_dance.up&!buff.stealth.up&mantle_duration=0&(dot.nightblade.remains>=cooldown.death_from_above.remains+6|target.time_to_die-dot.nightblade.remains<=6)&cooldown.death_from_above.remains<=1|target.time_to_die<=7
-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=4+talent.subterfuge.enabled

-- # Finishers
-- actions.finish=nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&(mantle_duration=0|remains<=mantle_duration)&((refreshable&(!finality|buff.finality_nightblade.up|variable.dsh_dfa))|remains<tick_time*2)&(spell_targets.shuriken_storm<4&!variable.dsh_dfa|!buff.symbols_of_death.up)
-- actions.finish+=/nightblade,cycle_targets=1,if=(!talent.death_from_above.enabled|set_bonus.tier19_2pc)&(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>12&mantle_duration=0&((refreshable&(!finality|buff.finality_nightblade.up|variable.dsh_dfa))|remains<tick_time*2)&(spell_targets.shuriken_storm<4&!variable.dsh_dfa|!buff.symbols_of_death.up)
-- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5+(combo_points=6)&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
-- actions.finish+=/death_from_above,if=!talent.dark_shadow.enabled|(!buff.shadow_dance.up|spell_targets>=4)&(buff.symbols_of_death.up|cooldown.symbols_of_death.remains>=10+set_bonus.tier20_4pc*5)&buff.the_first_of_the_dead.remains<1&(buff.finality_eviscerate.up|spell_targets.shuriken_storm<4)
-- actions.finish+=/eviscerate

-- # Stealth Action List Starter
-- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold-25*(!cooldown.goremaws_bite.up&!buff.feeding_frenzy.up)&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=variable.shd_fractional|energy.deficit>=10)
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=mantle_duration>2.3
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=4
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)

-- # Stealth Cooldowns
-- actions.stealth_cds=vanish,if=!variable.dsh_dfa&mantle_duration=0&cooldown.shadow_dance.charges_fractional<variable.shd_fractional+(equipped.mantle_of_the_master_assassin&time<30)*0.3&(!equipped.mantle_of_the_master_assassin|buff.symbols_of_death.up)
-- actions.stealth_cds+=/shadow_dance,if=charges_fractional>=variable.shd_fractional|target.time_to_die<cooldown.symbols_of_death.remains
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10+variable.ssw_refund
-- actions.stealth_cds+=/shadow_dance,if=!variable.dsh_dfa&combo_points.deficit>=2+talent.subterfuge.enabled*2&(buff.symbols_of_death.remains>=1.2+gcd.remains|cooldown.symbols_of_death.remains>=12+(talent.dark_shadow.enabled&set_bonus.tier20_4pc)*3-(!talent.dark_shadow.enabled&set_bonus.tier20_4pc)*4|mantle_duration>0)&(spell_targets.shuriken_storm>=4|!buff.the_first_of_the_dead.up)

-- # Stealthed Rotation
-- # If stealth is up, we really want to use Shadowstrike to benefits from the passive bonus, even if we are at max cp (from the precombat MfD).
-- actions.stealthed=shadowstrike,if=buff.stealth.up
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&(spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
-- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=2+equipped.insignia_of_ravenholdt&spell_targets.shuriken_storm>=3+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1&buff.the_dreadlords_deceit.stack>=29))
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&combo_points.deficit<3+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
-- actions.stealthed+=/shadowstrike

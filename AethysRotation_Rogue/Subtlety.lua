--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCore_Cache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- AethysRotation
local AR = AethysRotation;
-- Lua
local mathmin = math.min;
local pairs = pairs;
local tableinsert = table.insert;


--- APL Local Vars
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
    Shadowstrike                  = Spell(185438),
    ShurikenStorm                 = Spell(197835),
    ShurikenToss                  = Spell(114014),
    Stealth                       = Spell(1784),
    SymbolsofDeath                = Spell(212283),
    Vanish                        = Spell(1856),
    VanishBuff                    = Spell(115193),
    -- Talents
    Alacrity                      = Spell(193539),
    AlacrityBuff                  = Spell(193538),
    Anticipation                  = Spell(114015),
    DeathfromAbove                = Spell(152150),
    DeeperStratagem               = Spell(193531),
    EnvelopingShadows             = Spell(206237),
    Gloomblade                    = Spell(200758),
    MarkedforDeath                = Spell(137619),
    MasterofShadows               = Spell(196976),
    MasterOfSubtlety              = Spell(31223),
    MasterOfSubtletyBuff          = Spell(31665),
    Premeditation                 = Spell(196979),
    ShadowFocus                   = Spell(108209),
    Subterfuge                    = Spell(108208),
    Vigor                         = Spell(14983),
    -- Artifact
    FinalityEviscerate            = Spell(197496),
    FinalityNightblade            = Spell(197498),
    FlickeringShadows             = Spell(197256),
    GoremawsBite                  = Spell(209782),
    LegionBlade                   = Spell(214930),
    ShadowFangs                   = Spell(221856),
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
    -- Misc
    PoolEnergy                    = Spell(9999000010),
  };
  local S = Spell.Rogue.Subtlety;
  S.Eviscerate:RegisterDamage(
    -- Eviscerate DMG Formula (Pre-Mitigation):
    --  AP * CP * EviscR1_APCoef * EviscR2_M * F:Evisc_M * ShadowFangs_M * LegionBlade_M * MoS_M * DS_M * SoD_M * Mastery_M * Versa_M
    function ()
      return
        -- Attack Power
        Player:AttackPower() *
        -- Combo Points
        Player:ComboPoints() *
        -- Eviscerate R1 AP Coef
        0.98130 *
        -- Eviscerate R2 Multiplier
        1.5 *
        -- Finality: Eviscerate Multiplier | Used 1.2 atm
        -- TODO: Check the % from Tooltip or do an Event Listener
        (Player:Buff(S.FinalityEviscerate) and 1.2 or 1) *
        -- Shadow Fangs Multiplier
        (S.ShadowFangs:ArtifactEnabled() and 1.04 or 1) *
        -- Legion Blade Multiplier
        (S.LegionBlade:ArtifactEnabled() and 1.05+0.005*(S.LegionBlade:ArtifactRank()-1) or 1) *
        -- Master of Subtlety Multiplier
        (Player:Buff(S.MasterOfSubtletyBuff) and 1.1 or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Symbols of Death Multiplier
        (Player:Buff(S.SymbolsofDeath) and 1.2 or 1) *
        -- Mastery Finisher Multiplier
        (1 + Player:MasteryPct()/100) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct()/100);
    end
  );
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Subtlety = {
    -- Legendaries
    DenialoftheHalfGiants         = Item(137100, {9}),
    DraughtofSouls                = Item(140808, {13, 14}),
    MantleoftheMasterAssassin     = Item(144236, {3}),
    ShadowSatyrsWalk              = Item(137032, {8})
  };
  local I = Item.Rogue.Subtlety;
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD; -- Used for cycling
  local ShadowstrikeRange; -- Related to Shadowstrike Max Range setting
  local NightbladeThreshold; -- Used to compute the NB threshold (Cycling Performance)
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Subtlety = AR.GUISettings.APL.Rogue.Subtlety
  };

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
-- actions.precombat+=/variable,name=stealth_threshold,value=(15+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+variable.ssw_refund)
local function Stealth_Threshold ()
  return 15 + (S.Vigor:IsAvailable() and 35 or 0) + (S.MasterofShadows:IsAvailable() and 25 or 0) + SSW_Refund();
end
-- actions.precombat+=/variable,name=shd_fractionnal,value=2.45
local function ShD_Fractionnal ()
  return 2.45;
end
-- # Builders
local function Build ()
  -- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2
  if Cache.EnemiesCount[8] >= 2 and S.ShurikenStorm:IsCastable() then
    if AR.Cast(S.ShurikenStorm) then return ""; end
  end
  if Target:IsInRange(5) then
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
  if Target:IsInRange(5) then
    -- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|buff.shadow_blades.up
    -- TODO: Add Potion Suggestion
    -- Racials
    if Player:IsStealthed(true, false) then
      -- actions.cds+=/blood_fury,if=stealthed.rogue
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return ""; end
      end
      -- actions.cds+=/berserking,if=stealthed.rogue
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return ""; end
      end
      -- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
      if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 70 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
      end
    end
    -- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all-equipped.mantle_of_the_master_assassin&(cooldown.sprint.remains>buff.shadow_blades.duration*(0.4+equipped.denial_of_the_halfgiants*0.2)|mantle_duration>0|cooldown.shadow_dance.charges_fractional>variable.shd_fractionnal|cooldown.vanish.up|target.time_to_die<=buff.shadow_blades.duration*1.1)
    -- TODO : SBlades duration (SB Traits)
    if S.ShadowBlades:IsCastable() and not Player:Buff(S.ShadowBlades)
      and Player:ComboPointsDeficit() >= 2+(Player:IsStealthed(true, true) and 1 or 0)-(I.MantleoftheMasterAssassin:IsEquipped() and 1 or 0)
      and (S.Sprint:Cooldown() > 25*(0.4+(I.DenialoftheHalfGiants:IsEquipped() and 0.2 or 0)) or AR.Commons.Rogue.MantleDuration() > 0 or S.ShadowDance:ChargesFractional() > ShD_Fractionnal()
        or not S.Vanish:IsOnCooldown() or Target:TimeToDie() <= 25*1.1) then
      if AR.Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return ""; end
    end
    -- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=variable.shd_fractionnal&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
    if S.GoremawsBite:IsCastable() and not Player:IsStealthed(true, true) and S.ShadowDance:ChargesFractional() <= ShD_Fractionnal()
        and ((Player:ComboPointsDeficit() >= 4-(AC.CombatTime() < 10 and 2 or 0)
            and Player:EnergyDeficit() > 50+(S.Vigor:IsAvailable() and 25 or 0)-(AC.CombatTime() >= 10 and 15 or 0))
          or (Player:ComboPointsDeficit() >= 1 and Target:TimeToDie(10) < 8)) then
      if AR.Cast(S.GoremawsBite) then return ""; end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and (Target:TimeToDie() < Player:ComboPointsDeficit() or Player:ComboPointsDeficit() >= AR.Commons.Rogue.CPMaxSpend()) then
      AR.CastSuggested(S.MarkedforDeath);
    end
  end
  return false;
end
-- # Finishers
-- ReturnSpellOnly has been added to Predict Finisher in case of Stealth Macros (happens only when ShD Charges ~= 3)
local function Finish (ReturnSpellOnly)
  -- actions.finish=enveloping_shadows,if=buff.enveloping_shadows.remains<target.time_to_die&buff.enveloping_shadows.remains<=combo_points*1.8
  if S.EnvelopingShadows:IsCastable() and Player:BuffRemains(S.EnvelopingShadows) < Target:TimeToDie() and Player:BuffRemains(S.EnvelopingShadows) < Player:ComboPoints()*1.8 then
    if ReturnSpellOnly then
      return S.EnvelopingShadows;
    else
      if AR.Cast(S.EnvelopingShadows) then return ""; end
    end
  end
  -- actions.finish+=/death_from_above,if=spell_targets.death_from_above>=5
  if S.DeathfromAbove:IsCastable() and Cache.EnemiesCount[8] >= 5 and Target:IsInRange(15) then
    if ReturnSpellOnly then
      return S.DeathfromAbove;
    else
      if AR.Cast(S.DeathfromAbove) then return ""; end
    end
  end
  -- actions.finish+=/nightblade,cycle_targets=1,if=target.time_to_die-remains>10&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time*2)
  if S.Nightblade:IsCastable() then
    NightbladeThreshold = (6+mathmin(Player:ComboPoints(), 5+(S.DeeperStratagem:IsAvailable() and 1 or 0))*(2+(AC.Tier19_2Pc and 2 or 0)))*0.3;
    -- actions.finish+=/nightblade,if=target.time_to_die-remains>8&(mantle_duration=0|remains<=mantle_duration)&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time*2)
    if Target:IsInRange(5) and Target:TimeToDie() < 7777 and Target:TimeToDie()-Target:DebuffRemains(S.Nightblade) > 8
      and (Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset or Target:IsDummy())
      and (AR.Commons.Rogue.MantleDuration() == 0 or Target:DebuffRemains(S.Nightblade) <= AR.Commons.Rogue.MantleDuration())
      and ((Target:DebuffRefreshable(S.Nightblade, NightbladeThreshold) and (not AC.Finality(Target) or Player:Buff(S.FinalityNightblade)))
        or Target:DebuffRemains(S.Nightblade) < 4) then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if AR.Cast(S.Nightblade) then return ""; end
      end
    end
    -- actions.finish+=/nightblade,cycle_targets=1,if=target.time_to_die-remains>8&mantle_duration=0&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time*2)
    if AR.AoEON() and AR.Commons.Rogue.MantleDuration() == 0 then
      BestUnit, BestUnitTTD = nil, 8;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and not Value:IsUserCycleBlacklisted()
          and Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Nightblade) > BestUnitTTD
          and (Value:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset or Value:IsDummy())
          and ((Value:DebuffRefreshable(S.Nightblade, NightbladeThreshold) and (not AC.Finality(Value) or Player:Buff(S.FinalityNightblade)))
            or Value:DebuffRemains(S.Nightblade) < 4) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Nightblade);
      end
    end
  end
  -- actions.finish+=/death_from_above
  if S.DeathfromAbove:IsCastable() and Target:IsInRange(15) then
    if ReturnSpellOnly then
      return S.DeathfromAbove;
    else
      if AR.Cast(S.DeathfromAbove) then return ""; end
    end
  end
  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and Target:IsInRange(5) then
    if ReturnSpellOnly then
      return S.Eviscerate;
    else
      if AR.Cast(S.Eviscerate) then return ""; end
    end
  end
  return false;
end
-- # Sprinted
local function Sprinted ()
  -- actions.sprinted=cancel_autoattack
  -- actions.sprinted+=/use_item,name=draught_of_souls
end
local MacroTable;
local function StealthMacro(StealthSpell)
  MacroTable = {StealthSpell}
  -- Will we SoD ?
  if S.SymbolsofDeath:IsCastable() and Player:BuffRemains(S.SymbolsofDeath) < Target:TimeToDie(10)-4 and Player:BuffRefreshable(S.SymbolsofDeath, 10.5)
    and (AR.Commons.Rogue.MantleDuration() == 0 
      or (I.MantleoftheMasterAssassin:IsEquipped() and StealthSpell:ID() == S.Vanish:ID() and Player:BuffRemains(S.SymbolsofDeath) <= 9)
      or Player:BuffRemains(S.SymbolsofDeath) <= AR.Commons.Rogue.MantleDuration()) then
    tableinsert(MacroTable, S.SymbolsofDeath);
  end
  -- Will we do a Eviscerate (ShD Charges ~= 3) or ShurikenStorm or Shadowstrike?
  -- Shadow Dance
  if StealthSpell:ID() == S.ShadowDance:ID() then
    -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&(spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
    -- TODO: Add DfA (and maybe Nightblade)
    if Player:ComboPoints() >= 5 and (Cache.EnemiesCount[8] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped() and 1 or 0)
        or (AR.Commons.Rogue.MantleDuration() <= 1.3 and AR.Commons.Rogue.MantleDuration()-Player:GCDRemains() >= 0.3)) then
      tableinsert(MacroTable, Finish(true));
    -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1+buff.shadow_blades.up&buff.the_dreadlords_deceit.stack>=29))
    elseif S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
        and ((Player:ComboPointsDeficit() >= 3 and Cache.EnemiesCount[8] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped() and 1 or 0))
          or (AR.AoEON() and Target:IsInRange(5) and Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(Player:Buff(S.ShadowBlades) and 1 or 0)
            and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
      tableinsert(MacroTable, S.ShurikenStorm);
    -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&combo_points.deficit<2+talent.premeditation.enabled+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
    elseif Player:ComboPoints() >= 5
      and Player:ComboPointsDeficit() < 2+(S.Premeditation:IsAvailable() and 1 or 0)+(Player:Buff(S.ShadowBlades) and 1 or 0)-(I.MantleoftheMasterAssassin:IsEquipped() and 1 or 0) then
      tableinsert(MacroTable, Finish(true));
    -- actions.stealthed+=/shadowstrike
    else
      tableinsert(MacroTable, S.Shadowstrike);
    end
  -- Vanish
  elseif StealthSpell:ID() == S.Vanish:ID() then
    -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1+buff.shadow_blades.up&buff.the_dreadlords_deceit.stack>=29))
    if S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
        and ((Player:ComboPointsDeficit() >= 3 and Cache.EnemiesCount[8] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped() and 1 or 0))
          or (AR.AoEON() and Target:IsInRange(5) and Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(Player:Buff(S.ShadowBlades) and 1 or 0)
            and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
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
-- # Stealth Cooldowns
local function Stealth_CDs ()
  if Target:IsInRange(5) then
    -- actions.stealth_cds=vanish,if=mantle_duration=0&cooldown.shadow_dance.charges_fractional<variable.shd_fractionnal+(equipped.mantle_of_the_master_assassin&time<30)*0.3
    if AR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and AR.Commons.Rogue.MantleDuration() == 0
      and (S.ShadowDance:ChargesFractional() < ShD_Fractionnal()+(I.MantleoftheMasterAssassin:IsEquipped() and AC.CombatTime() < 30 and 0.3 or 0)) then
      if StealthMacro(S.Vanish) then return ""; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=charges_fractional>=variable.shd_fractionnal
    if (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:ChargesFractional() >= ShD_Fractionnal() then
      if StealthMacro(S.ShadowDance) then return ""; end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40-variable.ssw_refund&energy.deficit>=10+variable.ssw_refund
    if AR.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and GetUnitSpeed("player") == 0 and Player:EnergyDeficit() > 10+SSW_Refund() then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40-variable.ssw_refund
      if Player:Energy() < 40 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Shadowmeld"; end
      end
      if StealthMacro(S.Shadowmeld) then return ""; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=combo_points.deficit>=5-talent.vigor.enabled
    if (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and Player:ComboPointsDeficit() >= 5-(S.Vigor:IsAvailable() and 1 or 0) then
      if StealthMacro(S.ShadowDance) then return ""; end
    end
  end
  return false;
end
-- # Stealth Action List Starter
local function Stealth_ALS ()
  -- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=variable.shd_fractionnal|energy.deficit>=10)
  if (Player:EnergyDeficit() <= Stealth_Threshold()
    and (not I.ShadowSatyrsWalk:IsEquipped() or S.ShadowDance:ChargesFractional() >= ShD_Fractionnal() or Player:EnergyDeficit() >= 10))
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=mantle_duration>2.3
    or AR.Commons.Rogue.MantleDuration() > 2.3
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=5
    or Cache.EnemiesCount[8] >= 5
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
    or (not S.Shadowmeld:IsOnCooldown() and S.Vanish:IsOnCooldown() and S.ShadowDance:Charges() <= 1)
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)
    or (Target:TimeToDie() < 12*S.ShadowDance:ChargesFractional()*(I.ShadowSatyrsWalk:IsEquipped() and 1.5 or 1)) then
   return Stealth_CDs();
  end
  return false;
end
-- # Stealthed Rotation
local function Stealthed ()
  -- actions.stealthed=symbols_of_death,if=buff.symbols_of_death.remains<target.time_to_die&buff.symbols_of_death.remains<=buff.symbols_of_death.duration*0.3&(mantle_duration=0|buff.symbols_of_death.remains<=mantle_duration)
  -- Note: Added condition to check stealth won't expire until we can cast it (with an offset of 0.1s) : Player:IsStealthedRemains(true, true) > Player:EnergyTimeToX(35, 0.1)
  if S.SymbolsofDeath:IsCastable() and Player:IsStealthedRemains(true, true) > Player:EnergyTimeToX(35, 0.1)
    and Player:BuffRemains(S.SymbolsofDeath) < Target:TimeToDie(10)-4 and Player:BuffRefreshable(S.SymbolsofDeath, 10.5)
    and (AR.Commons.Rogue.MantleDuration() == 0 or Player:BuffRemains(S.SymbolsofDeath) <= AR.Commons.Rogue.MantleDuration() ) then
    if AR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return ""; end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&(spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
  if Player:ComboPoints() >= 5 and (Cache.EnemiesCount[8] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped() and 1 or 0)
      or (AR.Commons.Rogue.MantleDuration() <= 1.3 and AR.Commons.Rogue.MantleDuration()-Player:GCDRemains() >= 0.3)) then
    return Finish();
  end
  -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1+buff.shadow_blades.up&buff.the_dreadlords_deceit.stack>=29))
  if S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
      and ((Player:ComboPointsDeficit() >= 3 and Cache.EnemiesCount[8] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped() and 1 or 0))
        or (AR.AoEON() and Target:IsInRange(5) and Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(Player:Buff(S.ShadowBlades) and 1 or 0)
          and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
    if AR.Cast(S.ShurikenStorm) then return ""; end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&combo_points.deficit<2+talent.premeditation.enabled+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
  if Player:ComboPoints() >= 5
    and Player:ComboPointsDeficit() < 2+(S.Premeditation:IsAvailable() and 1 or 0)+(Player:Buff(S.ShadowBlades) and 1 or 0)-(I.MantleoftheMasterAssassin:IsEquipped() and 1 or 0) then
    return Finish();
  end
  -- actions.stealthed+=/shadowstrike
  if S.Shadowstrike:IsCastable() and Target:IsInRange(ShadowstrikeRange) then
    if AR.Cast(S.Shadowstrike) then return ""; end
  end
  return false;
end
local SappedSoulSpells = {
  {S.Kick, "Cast Kick (Sappel Soul)", function () return Target:IsInRange(5); end},
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
    if Target:IsInRange(5) and S.KidneyShot:IsCastable() and Player:ComboPoints() > 0 then
      if AR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end

-- APL Main
local function APL ()
  -- Spell ID Changes check
  S.Stealth = S.Subterfuge:IsAvailable() and Spell(115191) or Spell(1784); -- w/ or w/o Subterfuge Talent
  ShadowstrikeRange = 5+(Settings.Subtlety.ShadowstrikeMaxRange and 10 or 0);
  -- Unit Update
  AC.GetEnemies(8); -- Shuriken Storm & Death from Above
  AC.GetEnemies(5); -- Melee
  AR.Commons.AoEToggleEnemiesUpdate();
  --- Defensives
    -- Crimson Vial
    ShouldReturn = AR.Commons.Rogue.CrimsonVial (S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = AR.Commons.Rogue.Feint (S.Feint);
    if ShouldReturn then return ShouldReturn; end
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = AR.Commons.Rogue.Stealth(S.Stealth);
      if ShouldReturn then return ShouldReturn; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Symbols of Death
      if S.SymbolsofDeath:IsCastable() and Player:IsStealthed(true, true)
        and (AC.BMPullTime() == 60 or (AC.BMPullTime() <= 15 and AC.BMPullTime() >= 14) or (AC.BMPullTime() <= 4 and AC.BMPullTime() >= 3)) then
        if AR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death (OOC)"; end
      end
      -- Opener
      if AR.Commons.TargetIsValid() and Target:IsInRange(5) then
        if Player:ComboPoints() >= 5 then
          if S.Nightblade:IsCastable() and not Target:Debuff(S.Nightblade)
            and (Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset or Target:IsDummy()) then
            if AR.Cast(S.Nightblade) then return "Cast Nightblade (OOC)"; end
          elseif S.Eviscerate:IsCastable() then
            if AR.Cast(S.Eviscerate) then return "Cast Eviscerate (OOC)"; end
          end
        elseif Player:IsStealthed(true, true) then
          if S.ShurikenStorm:IsCastable() and Cache.EnemiesCount[8] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped() and 1 or 0) then
            if AR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm (OOC)"; end
          elseif S.Shadowstrike:IsCastable() then
            if AR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (OOC)"; end
          end
        elseif S.Backstab:IsCastable() then
          if AR.Cast(S.Backstab) then return "Cast Backstab (OOC)"; end
        end
      end
      return;
    end
  -- In Combat
    -- MfD Sniping
    AR.Commons.Rogue.MfDSniping(S.MarkedforDeath);
    if AR.Commons.TargetIsValid() then
      -- Mythic Dungeon
      ShouldReturn = MythicDungeon();
      if ShouldReturn then return ShouldReturn; end
      -- Training Scenario
      ShouldReturn = TrainingScenario();
      if ShouldReturn then return ShouldReturn; end
      -- Interrupts
      AR.Commons.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, {
        {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
        {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end},
        {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:IsStealthed(true, true); end}
      });
      -- actions=run_action_list,name=sprinted,if=buff.faster_than_light_trigger.up
      -- TODO
      -- actions+=/call_action_list,name=cds
      if AR.CDsON() then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
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
      -- actions+=/nightblade,if=target.time_to_die>8&remains<gcd.max&combo_points>=4
      if S.Nightblade:IsCastable() and Target:IsInRange(5) and Target:TimeToDie() < 7777 and Target:TimeToDie() > 8
        and (Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset or Target:IsDummy())
        and Target:DebuffRemains(S.Nightblade) < Player:GCD() and Player:ComboPoints() >= 4 then
        if AR.Cast(S.Nightblade) then return ""; end
      end
      if S.Sprint:IsCastable() and AR.Commons.Rogue.MantleDuration() == 0 then
        if not I.DraughtofSouls:IsEquipped() then
          -- actions+=/sprint,if=!equipped.draught_of_souls&mantle_duration=0&energy.time_to_max>=1.5&cooldown.shadow_dance.charges_fractional<variable.shd_fractionnal&!cooldown.vanish.up&target.time_to_die>=8&(dot.nightblade.remains>=14|target.time_to_die<=45)
          if Player:EnergyTimeToMax() >= 1.5 and S.ShadowDance:ChargesFractional() < ShD_Fractionnal() and S.Vanish:IsOnCooldown() and Target:TimeToDie() >= 8
            and (Target:DebuffRemains(S.Nightblade) >= 14 or Target:TimeToDie() <= 45) then
            AR.CastSuggested(S.Sprint);
          end
        else
          -- actions+=/sprint,if=equipped.draught_of_souls&trinket.cooldown.up&mantle_duration=0
          -- TODO: DoS CD
          if false then
            AR.CastSuggested(S.Sprint);
          end
        end
      end
      -- actions+=/call_action_list,name=stealth_als,if=(combo_points.deficit>=2+talent.premeditation.enabled|cooldown.shadow_dance.charges_fractional>=2.9)
      if Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0) or S.ShadowDance:ChargesFractional() >= 2.9 then
        ShouldReturn = Stealth_ALS();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=finish,if=combo_points>=5|(combo_points>=4&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)
      if Player:ComboPoints() >= 5 or (Player:ComboPoints() >= 4 and Cache.EnemiesCount[8] >= 3 and Cache.EnemiesCount[8] <= 4) then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
      if Player:EnergyDeficit() <= Stealth_Threshold() then
        ShouldReturn = Build();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Shuriken Toss Out of Range
      if S.ShurikenToss:IsCastable() and not Target:IsInRange(10) and Target:IsInRange(20) and not Player:IsStealthed(true, true) and not Player:Buff(S.Sprint)
          and Player:EnergyDeficit() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2)
      then
        if AR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Shadowstrike:IsCastable() and Target:IsInRange(5) then
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(261, APL);

-- Last Update: 03/12/2017


-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,name=flask_of_the_seventh_demon
-- actions.precombat+=/augmentation,name=defiled
-- actions.precombat+=/food,name=nightborne_delicacy_platter
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/stealth
-- actions.precombat+=/potion,name=prolonged_power
-- actions.precombat+=/marked_for_death,if=raid_event.adds.in>40
-- # Defined variables that doesn't change during the fight
-- actions.precombat+=/variable,name=ssw_refund,value=equipped.shadow_satyrs_walk*(6+ssw_refund_offset)
-- actions.precombat+=/variable,name=stealth_threshold,value=(15+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+variable.ssw_refund)
-- actions.precombat+=/variable,name=shd_fractionnal,value=2.45
-- actions.precombat+=/enveloping_shadows,if=combo_points>=5
-- # In 7.1.5, casting Shadow Dance before going in combat let you extends the stealth buff, so it's worth to use with Subterfuge talent. Will likely be fixed in 7.2!
-- actions.precombat+=/shadow_dance,if=talent.subterfuge.enabled&bugs
-- actions.precombat+=/symbols_of_death

-- # Executed every time the actor is available.
-- actions=run_action_list,name=sprinted,if=buff.faster_than_light_trigger.up
-- actions+=/call_action_list,name=cds
-- # Fully switch to the Stealthed Rotation (by doing so, it forces pooling if nothing is available)
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- actions+=/nightblade,if=target.time_to_die>8&remains<gcd.max&combo_points>=4
-- actions+=/sprint,if=!equipped.draught_of_souls&mantle_duration=0&energy.time_to_max>=1.5&cooldown.shadow_dance.charges_fractional<variable.shd_fractionnal&!cooldown.vanish.up&target.time_to_die>=8&(dot.nightblade.remains>=14|target.time_to_die<=45)
-- actions+=/sprint,if=equipped.draught_of_souls&trinket.cooldown.up&mantle_duration=0
-- actions+=/call_action_list,name=stealth_als,if=(combo_points.deficit>=2+talent.premeditation.enabled|cooldown.shadow_dance.charges_fractional>=2.9)
-- actions+=/call_action_list,name=finish,if=combo_points>=5|(combo_points>=4&combo_points.deficit<=2&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)
-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold

-- # Builders
-- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2
-- actions.build+=/gloomblade
-- actions.build+=/backstab

-- # Cooldowns
-- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|buff.shadow_blades.up
-- actions.cds+=/blood_fury,if=stealthed.rogue
-- actions.cds+=/berserking,if=stealthed.rogue
-- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
-- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all-equipped.mantle_of_the_master_assassin&(cooldown.sprint.remains>buff.shadow_blades.duration*(0.4+equipped.denial_of_the_halfgiants*0.2)|mantle_duration>0|cooldown.shadow_dance.charges_fractional>variable.shd_fractionnal|cooldown.vanish.up|target.time_to_die<=buff.shadow_blades.duration*1.1)
-- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=variable.shd_fractionnal&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)

-- # Finishers
-- actions.finish=enveloping_shadows,if=buff.enveloping_shadows.remains<target.time_to_die&buff.enveloping_shadows.remains<=combo_points*1.8
-- actions.finish+=/death_from_above,if=spell_targets.death_from_above>=5
-- actions.finish+=/nightblade,if=target.time_to_die-remains>8&(mantle_duration=0|remains<=mantle_duration)&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time*2)
-- actions.finish+=/nightblade,cycle_targets=1,if=target.time_to_die-remains>8&mantle_duration=0&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time*2)
-- actions.finish+=/death_from_above
-- actions.finish+=/eviscerate

-- # Sprinted
-- actions.sprinted=cancel_autoattack
-- actions.sprinted+=/use_item,name=draught_of_souls

-- # Stealth Action List Starter
-- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=variable.shd_fractionnal|energy.deficit>=10)
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=mantle_duration>2.3
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=5
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)

-- # Stealth Cooldowns
-- actions.stealth_cds=vanish,if=mantle_duration=0&cooldown.shadow_dance.charges_fractional<variable.shd_fractionnal+(equipped.mantle_of_the_master_assassin&time<30)*0.3
-- actions.stealth_cds+=/shadow_dance,if=charges_fractional>=variable.shd_fractionnal
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10+variable.ssw_refund
-- actions.stealth_cds+=/shadow_dance,if=combo_points.deficit>=5-talent.vigor.enabled

-- # Stealthed Rotation
-- actions.stealthed=symbols_of_death,if=buff.symbols_of_death.remains<target.time_to_die&buff.symbols_of_death.remains<=buff.symbols_of_death.duration*0.3&(mantle_duration=0|buff.symbols_of_death.remains<=mantle_duration)
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&(spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk|(mantle_duration<=1.3&mantle_duration-gcd.remains>=0.3))
-- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1+buff.shadow_blades.up&buff.the_dreadlords_deceit.stack>=29))
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&combo_points.deficit<2+talent.premeditation.enabled+buff.shadow_blades.up-equipped.mantle_of_the_master_assassin
-- actions.stealthed+=/shadowstrike

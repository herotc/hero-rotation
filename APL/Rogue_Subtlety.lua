-- Pull Addon Vars
local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua
local pairs = pairs;

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
    DeathFromAbove                = Spell(152150),
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
    FinalityNightblade            = Spell(195452),
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
    DeathlyShadows                = Spell(188700),
    PoolEnergy                    = Spell(9999000001),
    -- Macros
    Macros = {
      ShDSS                       = Spell(9999261001),
      ShDShStorm                  = Spell(9999261002),
      ShDSoDSS                    = Spell(9999261003),
      ShDSoDShStorm               = Spell(9999261004),
      VanSS                       = Spell(9999261005),
      VanShStorm                  = Spell(9999261006),
      VanSoDSS                    = Spell(9999261007),
      VanSoDShStorm               = Spell(9999261008),
      SMSS                        = Spell(9999261009),
      SMSoDSS                     = Spell(9999261010)
    }
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
    DenialoftheHalfGiants = Item(137100), -- 9
    ShadowSatyrsWalk = Item(137032) -- 8
  };
  local I = Item.Rogue.Subtlety;
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local BestUnit, BestUnitTTD; -- Used for cycling
  local MacroLookupSpell = {
    [9999261001] = S.Macros.ShDSS,
    [9999261002] = S.Macros.ShDShStorm,
    [9999261003] = S.Macros.ShDSoDSS,
    [9999261004] = S.Macros.ShDSoDShStorm,
    [9999261005] = S.Macros.VanSS,
    [9999261006] = S.Macros.VanShStorm,
    [9999261007] = S.Macros.VanSoDSS,
    [9999261008] = S.Macros.VanSoDShStorm,
    [9999261009] = S.Macros.SMSS,
    [9999261010] = S.Macros.SMSoDSS
  };
-- GUI Settings
  local Settings = {
    General = ER.GUISettings.General,
    Commons = ER.GUISettings.APL.Rogue.Commons,
    Subtlety = ER.GUISettings.APL.Rogue.Subtlety
  };

local ExtraSSWRefundTable = {
  [101002] = 2, -- Nighthold: Krosus
  [114537] = 2 -- Trial of Valor: Helya
};
local function SSW_RefundOffset ()
  return ExtraSSWRefundTable[Target:NPCID()] or 0;
end

-- APL Action Lists (and Variables)
-- actions.precombat+=/variable,name=ssw_refund,value=equipped.shadow_satyrs_walk*(4+ssw_refund_offset)
local function SSW_Refund ()
  return I.ShadowSatyrsWalk:IsEquipped(8) and 6+SSW_RefundOffset() or 0;
end
-- actions.precombat+=/variable,name=stealth_threshold,value=(15+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+variable.ssw_refund)
local function Stealth_Threshold ()
  return 15 + (S.Vigor:IsAvailable() and 35 or 0) + (S.MasterofShadows:IsAvailable() and 25 or 0) + SSW_Refund();
end
-- # Builders
local function Build ()
  -- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2
  if ER.AoEON() and ER.Cache.EnemiesCount[10] >= 2 and S.ShurikenStorm:IsCastable() then
    if ER.Cast(S.ShurikenStorm) then return "Cast"; end
  end
  if Target:IsInRange(5) then
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if ER.Cast(S.Gloomblade) then return "Cast"; end
    -- actions.build+=/backstab
    elseif S.Backstab:IsCastable() then
      if ER.Cast(S.Backstab) then return "Cast"; end
    end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  if Target:IsInRange(5) then
   -- Racials
   if Player:IsStealthed(true, false) then
     -- actions.cds+=/blood_fury,if=stealthed.rogue
     if S.BloodFury:IsCastable() then
       if ER.Cast(S.BloodFury, Settings.Subtlety.OffGCDasOffGCD.BloodFury) then return "Cast"; end
     end
     -- actions.cds+=/berserking,if=stealthed.rogue
     if S.Berserking:IsCastable() then
       if ER.Cast(S.Berserking, Settings.Subtlety.OffGCDasOffGCD.Berserking) then return "Cast"; end
     end
     -- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
     if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 70 then
       if ER.Cast(S.ArcaneTorrent, Settings.Subtlety.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
     end
   end
   -- actions.cds+=/shadow_blades
   if S.ShadowBlades:IsCastable() and not Player:Buff(S.ShadowBlades) then
    if ER.Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return "Cast"; end
   end
   -- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=2.45&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
   if S.GoremawsBite:IsCastable() and not Player:IsStealthed(true, true) and S.ShadowDance:ChargesFractional() <= 2.45
       and ((Player:ComboPointsDeficit() >= 4-(ER.CombatTime() < 10 and 2 or 0) and Player:EnergyDeficit() > 50 + (S.Vigor:IsAvailable() and 25 or 0) - (ER.CombatTime() >= 10 and 15 or 0))
         or (Player:ComboPointsDeficit() >= 1 and Target:TimeToDie(10) < 8))
   then
    if ER.Cast(S.GoremawsBite) then return "Cast"; end
   end
   -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|(raid_event.adds.in>40&combo_points.deficit>=4+talent.deeper_strategem.enabled+talent.anticipation.enabled)
   --[[Normal MfD
   if not S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= 4+(S.DeeperStratagem:IsAvailable() and 1 or 0)+(S.Anticipation:IsAvailable() and 1 or 0) then
    if ER.Cast(S.MarkedforDeath, Settings.Subtlety.OffGCDasOffGCD.MarkedforDeath) then return "Cast"; end
   end]]
  end
  return false;
end
-- # Finishers
local function Finish ()
  -- actions.finish=enveloping_shadows,if=buff.enveloping_shadows.remains<target.time_to_die&buff.enveloping_shadows.remains<=combo_points*1.8
  if S.EnvelopingShadows:IsCastable() and Player:BuffRemains(S.EnvelopingShadows) < Target:TimeToDie() and Player:BuffRemains(S.EnvelopingShadows) < Player:ComboPoints()*1.8 then
    if ER.Cast(S.EnvelopingShadows) then return "Cast"; end
  end
  -- actions.finish+=/death_from_above,if=spell_targets.death_from_above>=6
  if ER.AoEON() and ER.Cache.EnemiesCount[8] >= 6 and Target:IsInRange(15) and S.DeathFromAbove:IsCastable() then
    if ER.Cast(S.DeathFromAbove) then return "Cast"; end
  end
  -- actions.finish+=/nightblade,target_if=max:target.time_to_die,if=target.time_to_die>8&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time)
  if S.Nightblade:IsCastable() then
    if Target:IsInRange(5) and Target:TimeToDie() < 7777 and Target:TimeToDie()-Target:DebuffRemains(S.Nightblade) > 10 and
      Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset and
      ((Target:DebuffRefreshable(S.Nightblade, (6+Player:ComboPoints()*2)*0.3) and (not ER.Finality(Target) or Player:Buff(S.FinalityNightblade))) or
      Target:DebuffRemains(S.Nightblade) < 3) then
      if ER.Cast(S.Nightblade) then return "Cast"; end
    end
    if ER.AoEON() then
      BestUnit, BestUnitTTD = nil, 10;
      for Key, Value in pairs(ER.Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and not Value:IsUserCycleBlacklisted() and
          Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Nightblade) > BestUnitTTD and
          Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset and
          ((Value:DebuffRefreshable(S.Nightblade, (6+Player:ComboPoints()*2)*0.3) and
          (not ER.Finality(Target) or Player:Buff(S.FinalityNightblade))) or
          Value:DebuffRemains(S.Nightblade) < 3) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        ER.Nameplate.AddIcon(BestUnit, S.Nightblade);
      end
    end
  end
  -- actions.finish+=/death_from_above
  if Target:IsInRange(15) and S.DeathFromAbove:IsCastable() then
    if ER.Cast(S.DeathFromAbove) then return "Cast"; end
  end
  -- actions.finish+=/eviscerate
  if Target:IsInRange(5) and S.Eviscerate:IsCastable() then
    if ER.Cast(S.Eviscerate) then return "Cast"; end
  end
  return false;
end
local SoDMacro, ShStormMacro;
local function StealthMacro(MacroType)
  SoDMacro, ShStormMacro = false, false;
  -- Will we SoD ?
  if S.SymbolsofDeath:IsCastable() and Player:BuffRemains(S.SymbolsofDeath) < Target:TimeToDie(10)-4 and Player:BuffRefreshable(S.SymbolsofDeath, 10.5) then
    SoDMacro = true;
  end
  -- Will we Shuriken Storm ?
  if ER.AoEON() and S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
      and ((Player:ComboPointsDeficit() >= 3 and ER.Cache.EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0))
        or (Target:IsInRange(5) and Player:ComboPointsDeficit() >= 2 + (S.Premeditation:IsAvailable() and 1 or 0)
          + (Player:Buff(S.ShadowBlades) and 1 or 0) and Player:BuffStack(S.DreadlordsDeceit) >= 29))
  then
    ShStormMacro = true;
  end
  if MacroType == "ShD" then
    if ShStormMacro then
      return SoDMacro and 9999261004 or 9999261002;
    else
      return SoDMacro and 9999261003 or 9999261001;
    end
  elseif MacroType == "Van" then
    if ShStormMacro then
      return SoDMacro and 9999261008 or 9999261006;
    else
      return SoDMacro and 9999261007 or 9999261005;
    end
  elseif MacroType == "SM" then
    return SoDMacro and 9999261010 or 9999261009;
  end
end
-- # Stealth Cooldowns
local function Stealth_CDs ()
  if Target:IsInRange(5) then
    -- actions.stealth_cds=shadow_dance,if=charges_fractional>=2.45
    if (ER.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:ChargesFractional() >= 2.45 then
      if ER.Cast(MacroLookupSpell[StealthMacro("ShD")]) then return "Cast"; end
    end
    -- actions.stealth_cds+=/vanish
    if ER.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target) and S.ShadowDance:ChargesFractional() < 2.45 then
      if ER.Cast(MacroLookupSpell[StealthMacro("Van")]) then return "Cast"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=charges>=2&combo_points<=1
    if (ER.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 2 and Player:ComboPoints() <= 1 then
      if ER.Cast(MacroLookupSpell[StealthMacro("ShD")]) then return "Cast"; end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40-variable.ssw_refund&energy.deficit>=10+variable.ssw_refund
    if ER.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target) and S.ShadowDance:ChargesFractional() < 2.45 and GetUnitSpeed("player") == 0 and Player:EnergyDeficit() > 10+SSW_Refund() then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40-variable.ssw_refund
      if Player:Energy() < 40 then
        if ER.Cast(S.PoolEnergy) then return "Pool for Shadowmeld"; end
      end
      if ER.Cast(MacroLookupSpell[StealthMacro("SM")]) then return "Cast"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=combo_points<=1
    if (ER.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and Player:ComboPoints() <= 1 and S.ShadowDance:Charges() >= 1 then
      if ER.Cast(MacroLookupSpell[StealthMacro("ShD")]) then return "Cast"; end
    end
  end
  return false;
end
-- # Stealth Action List Starter
local function Stealth_ALS ()
  -- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=2.45|energy.deficit>=10)
  if (Player:EnergyDeficit() <= Stealth_Threshold() and (not I.ShadowSatyrsWalk:IsEquipped(8) or S.ShadowDance:ChargesFractional() >= 2.45 or Player:EnergyDeficit() >= 10))
  -- actions.stealth_als+=/sprint_offensive,if=energy.time_to_max>3
  -- TODO: Sprint thing.
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=5
   or ER.Cache.EnemiesCount[10] >= 5
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
   or (not S.Shadowmeld:IsOnCooldown() and S.Vanish:IsOnCooldown() and S.ShadowDance:Charges() <= 1)
  -- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)
   or (Target:TimeToDie() < 12*S.ShadowDance:ChargesFractional()*(I.ShadowSatyrsWalk:IsEquipped(8) and 1.5 or 1))
  then
   return Stealth_CDs();
  end
  return false;
end
-- # Stealthed Rotation
local function Stealthed ()
  -- actions.stealthed=symbols_of_death,if=buff.symbols_of_death.remains<target.time_to_die-4&buff.symbols_of_death.remains<=buff.symbols_of_death.duration*0.3
  -- TODO: Added condition to check stealth won't expire until we can cast it.
  if S.SymbolsofDeath:IsCastable() and Player:BuffRemains(S.SymbolsofDeath) < Target:TimeToDie(10)-4 and Player:BuffRefreshable(S.SymbolsofDeath, 10.5) then
    if ER.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast"; end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk
  if Player:ComboPoints() >= 5 and ER.Cache.EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0) then
    return Finish();
  end
  -- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1+buff.shadow_blades.up&buff.the_dreadlords_deceit.stack>=29))
  if ER.AoEON() and S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld)
      and ((Player:ComboPointsDeficit() >= 3 and ER.Cache.EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0))
        or (Target:IsInRange(5) and Player:ComboPointsDeficit() >= 2 + (S.Premeditation:IsAvailable() and 1 or 0)
          + (Player:Buff(S.ShadowBlades) and 1 or 0) and Player:BuffStack(S.DreadlordsDeceit) >= 29))
  then
    if ER.Cast(S.ShurikenStorm) then return "Cast"; end
  end
  -- actions.stealthed+=/shadowstrike,if=combo_points.deficit>=2+talent.premeditation.enabled+buff.shadow_blades.up
  if Target:IsInRange(5) and S.Shadowstrike:IsCastable()
      and Player:ComboPointsDeficit() >= 2
        + (S.Premeditation:IsAvailable() and 1 or 0)
        + (Player:Buff(S.ShadowBlades) and 1 or 0)
  then
    if ER.Cast(S.Shadowstrike) then return "Cast"; end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5
  if Player:ComboPoints() >= 5 then
    return Finish();
  end
  -- actions.stealthed+=/shadowstrike
  if Target:IsInRange(5) and S.Shadowstrike:IsCastable() then
    if ER.Cast(S.Shadowstrike) then return "Cast"; end
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
  if ER.MythicDungeon() == "Sapped Soul" then
    for i = 1, #SappedSoulSpells do
      if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
        ER.ChangePulseTimer(1);
        ER.Cast(SappedSoulSpells[i][1]);
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
      if ER.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end

-- APL Main
local function APL ()
  -- Spell ID Changes check
  S.Stealth = S.Subterfuge:IsAvailable() and Spell(115191) or Spell(1784); -- w/ or w/o Subterfuge Talent
  -- Unit Update
  ER.GetEnemies(10); -- Shuriken Storm
  ER.GetEnemies(8); -- Death From Above
  ER.GetEnemies(5); -- Melee
  --- Defensives
    -- Crimson Vial
    ShouldReturn = ER.Commons.Rogue.CrimsonVial (S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = ER.Commons.Rogue.Feint (S.Feint);
    if ShouldReturn then return ShouldReturn; end
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = ER.Commons.Rogue.Stealth (S.Stealth);
      if ShouldReturn then return ShouldReturn; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Symbols of Death
      if S.SymbolsofDeath:IsCastable() and Player:IsStealthed(true, true) and (ER.BMPullTime() == 60 or (ER.BMPullTime() <= 15 and ER.BMPullTime() >= 14) or (ER.BMPullTime() <= 4 and ER.BMPullTime() >= 3)) then
        if ER.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death (OOC)"; end
      end
      -- Opener
      if ER.Commons.TargetIsValid() and Target:IsInRange(5) then
        if Player:ComboPoints() >= 5 then
          if S.Nightblade:IsCastable() and not Target:Debuff(S.Nightblade) and Target:Health() >= S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset then
           if ER.Cast(S.Nightblade) then return "Cast Nightblade (OOC)"; end
          elseif S.Eviscerate:IsCastable() then
           if ER.Cast(S.Eviscerate) then return "Cast Eviscerate (OOC)"; end
          end
        elseif Player:IsStealthed(true, true) then
          if ER.AoEON() and S.ShurikenStorm:IsCastable() and ER.Cache.EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0) then
            if ER.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm (OOC)"; end
          elseif S.Shadowstrike:IsCastable() then
            if ER.Cast(S.Shadowstrike) then return "Cast Shadowstrike (OOC)"; end
          end
        elseif S.Backstab:IsCastable() then
          if ER.Cast(S.Backstab) then return "Cast Backstab (OOC)"; end
        end
      end
      return;
    end
  -- In Combat
    -- MfD Sniping
    ER.Commons.Rogue.MfDSniping(S.MarkedforDeath);
    if ER.Commons.TargetIsValid() then
      -- Mythic Dungeon
      ShouldReturn = MythicDungeon();
      if ShouldReturn then return ShouldReturn; end
      -- Training Scenario
      ShouldReturn = TrainingScenario();
      if ShouldReturn then return ShouldReturn; end
      -- Interrupts
      ER.Commons.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, {
        {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
        {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end},
        {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:IsStealthed(true, true); end}
      });
      -- actions+=/call_action_list,name=cds
      if ER.CDsON() then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/run_action_list,name=stealthed,if=stealthed.all
      if Player:IsStealthed(true, true) then
        ShouldReturn = Stealthed();
        if ShouldReturn then return ShouldReturn; end
        -- run_action_list forces the return
        if Player:Energy() < 30 then -- To avoid pooling icon spam
          if ER.Cast(S.PoolEnergy) then return "Stealthed Pooling"; end
        else
          return "Stealthed Pooling";
        end
      end
      -- actions+=/call_action_list,name=finish,if=combo_points>=5|(combo_points>=4&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)
      if Player:ComboPoints() >= 5 or (ER.AoEON() and Player:ComboPoints() >= 4 and ER.Cache.EnemiesCount[10] >= 3 and ER.Cache.EnemiesCount[10] <= 4) then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=stealth_als,if=combo_points.deficit>=2+talent.premeditation.enabled
      if Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0) then
        ShouldReturn = Stealth_ALS();
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
        if ER.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Shadowstrike:IsCastable() then
        if ER.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

ER.SetAPL(261, APL);

-- Last Update: 02/06/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,name=flask_of_the_seventh_demon
-- actions.precombat+=/augmentation,name=defiled
-- actions.precombat+=/food,name=seedbattered_fish_plate
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/stealth
-- actions.precombat+=/potion,name=old_war
-- actions.precombat+=/marked_for_death,if=raid_event.adds.in>40
-- # Defined variables that doesn't change during the fight
-- actions.precombat+=/variable,name=ssw_refund,value=equipped.shadow_satyrs_walk*(4+ssw_refund_offset)
-- actions.precombat+=/variable,name=stealth_threshold,value=(15+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+variable.ssw_refund)
-- actions.precombat+=/enveloping_shadows,if=combo_points>=5
-- actions.precombat+=/symbols_of_death

-- # Executed every time the actor is available.
-- actions=call_action_list,name=cds
-- # Fully switch to the Stealthed Rotation (by doing so, it forces pooling if nothing is available)
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- actions+=/call_action_list,name=finish,if=combo_points>=5|(combo_points>=4&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)
-- actions+=/call_action_list,name=stealth_als,if=combo_points.deficit>=2+talent.premeditation.enabled
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
-- actions.cds+=/shadow_blades,if=combo_points<=2|(equipped.denial_of_the_halfgiants&combo_points>=1)
-- actions.cds+=/goremaws_bite,if=!stealthed.all&cooldown.shadow_dance.charges_fractional<=2.45&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|(combo_points.deficit>=1&target.time_to_die<8))
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|(raid_event.adds.in>40&combo_points.deficit>=4+talent.deeper_strategem.enabled+talent.anticipation.enabled)

-- # Finishers
-- actions.finish=enveloping_shadows,if=buff.enveloping_shadows.remains<target.time_to_die&buff.enveloping_shadows.remains<=combo_points*1.8
-- actions.finish+=/death_from_above,if=spell_targets.death_from_above>=6
-- actions.finish+=/nightblade,cycle_targets=1,if=target.time_to_die>8&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time)
-- actions.finish+=/death_from_above
-- actions.finish+=/eviscerate

-- # Stealth Action List Starter
-- actions.stealth_als=call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&(!equipped.shadow_satyrs_walk|cooldown.shadow_dance.charges_fractional>=2.45|energy.deficit>=10)
-- actions.stealth_als+=/sprint_offensive,if=energy.time_to_max>3
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=spell_targets.shuriken_storm>=5
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)
-- actions.stealth_als+=/call_action_list,name=stealth_cds,if=target.time_to_die<12*cooldown.shadow_dance.charges_fractional*(1+equipped.shadow_satyrs_walk*0.5)

-- # Stealth Cooldowns
-- actions.stealth_cds=shadow_dance,if=charges_fractional>=2.45
-- actions.stealth_cds+=/vanish
-- actions.stealth_cds+=/shadow_dance,if=charges>=2&combo_points<=1
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10+variable.ssw_refund
-- actions.stealth_cds+=/shadow_dance,if=combo_points<=1

-- # Stealthed Rotation
-- actions.stealthed=symbols_of_death,if=buff.symbols_of_death.remains<target.time_to_die-4&buff.symbols_of_death.remains<=buff.symbols_of_death.duration*0.3
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk
-- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|(combo_points.deficit>=1+buff.shadow_blades.up&buff.the_dreadlords_deceit.stack>=29))
-- actions.stealthed+=/shadowstrike,if=combo_points.deficit>=2+talent.premeditation.enabled+buff.shadow_blades.up
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5
-- actions.stealthed+=/shadowstrike

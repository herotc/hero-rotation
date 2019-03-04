--- Localize Vars
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
local pairs = pairs;
local tableinsert = table.insert;


--- APL Local Vars
-- Commons
  local Everyone = HR.Commons.Everyone;
  local Rogue = HR.Commons.Rogue;
-- Spells
  if not Spell.Rogue then Spell.Rogue = {}; end
  Spell.Rogue.Subtlety = {
    -- Racials
    ArcanePulse                           = Spell(260364),
    ArcaneTorrent                         = Spell(50613),
    Berserking                            = Spell(26297),
    BloodFury                             = Spell(20572),
    LightsJudgment                        = Spell(255647),
    Shadowmeld                            = Spell(58984),
    -- Abilities
    Backstab                              = Spell(53),
    Eviscerate                            = Spell(196819),
    Nightblade                            = Spell(195452),
    ShadowBlades                          = Spell(121471),
    ShurikenComboBuff                     = Spell(245640),
    ShadowDance                           = Spell(185313),
    ShadowDanceBuff                       = Spell(185422),
    Shadowstrike                          = Spell(185438),
    ShurikenStorm                         = Spell(197835),
    ShurikenToss                          = Spell(114014),
    Stealth                               = Spell(1784),
    Stealth2                              = Spell(115191), -- w/ Subterfuge Talent
    SymbolsofDeath                        = Spell(212283),
    Vanish                                = Spell(1856),
    VanishBuff                            = Spell(11327),
    VanishBuff2                           = Spell(115193), -- w/ Subterfuge Talent
    -- Talents
    Alacrity                              = Spell(193539),
    DarkShadow                            = Spell(245687),
    DeeperStratagem                       = Spell(193531),
    EnvelopingShadows                     = Spell(238104),
    FindWeakness                          = Spell(91023),
    FindWeaknessDebuff                    = Spell(91021),
    Gloomblade                            = Spell(200758),
    MarkedforDeath                        = Spell(137619),
    MasterofShadows                       = Spell(196976),
    Nightstalker                          = Spell(14062),
    SecretTechnique                       = Spell(280719),
    ShadowFocus                           = Spell(108209),
    ShurikenTornado                       = Spell(277925),
    Subterfuge                            = Spell(108208),
    Vigor                                 = Spell(14983),
    Weaponmaster                          = Spell(193537),
    -- Azerite Traits
    BladeInTheShadows                     = Spell(275896),
    Inevitability                         = Spell(278683),
    NightsVengeancePower                  = Spell(273418),
    NightsVengeanceBuff                   = Spell(273424),
    TheFirstDance                         = Spell(278681),
    -- Defensive
    CrimsonVial                           = Spell(185311),
    Feint                                 = Spell(1966),
    -- Utility
    Blind                                 = Spell(2094),
    CheapShot                             = Spell(1833),
    Kick                                  = Spell(1766),
    KidneyShot                            = Spell(408),
    Sprint                                = Spell(2983),
    -- Misc
    TheDreadlordsDeceit                   = Spell(228224),
    PoolEnergy                            = Spell(9999000010)
  };
  local S = Spell.Rogue.Subtlety;
  S.Eviscerate:RegisterDamage(
    -- Eviscerate DMG Formula (Pre-Mitigation):
    --- Player Modifier
      -- AP * CP * EviscR1_APCoef * EviscR2_M * Aura_M * NS_M * DS_M * DSh_M * SoD_M * ShC_M * Mastery_M * Versa_M
    --- Target Modifier
      -- NB_M
    function ()
      return
        --- Player Modifier
          -- Attack Power
          Player:AttackPowerDamageMod() *
          -- Combo Points
          Rogue.CPSpend() *
          -- Eviscerate R1 AP Coef
          0.16074 *
          -- Eviscerate R2 Multiplier
          1.5 *
          -- Aura Multiplier (SpellID: 137035)
          1.28 *
          -- Nightstalker Multiplier
          (S.Nightstalker:IsAvailable() and Player:IsStealthedP(true) and 1.12 or 1) *
          -- Deeper Stratagem Multiplier
          (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
          -- Dark Shadow Multiplier
          (S.DarkShadow:IsAvailable() and Player:BuffP(S.ShadowDanceBuff) and 1.25 or 1) *
          -- Symbols of Death Multiplier
          (Player:BuffP(S.SymbolsofDeath) and 1.15 or 1) *
          -- Shuriken Combo Multiplier
          (Player:BuffP(S.ShurikenComboBuff) and (1 + Player:Buff(S.ShurikenComboBuff, 16) / 100) or 1) *
          -- Mastery Finisher Multiplier
          (1 + Player:MasteryPct() / 100) *
          -- Versatility Damage Multiplier
          (1 + Player:VersatilityDmgPct() / 100) *
        --- Target Modifier
          -- Nightblade Multiplier
          (Target:DebuffP(S.Nightblade) and 1.15 or 1);
    end
  );
  S.Nightblade:RegisterPMultiplier(
    {function ()
      return S.Nightstalker:IsAvailable() and Player:IsStealthed(true, false) and 1.12 or 1;
    end}
  );
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Subtlety = {
    -- Nothing here yet
  };
  local I = Item.Rogue.Subtlety;
  local AoETrinkets = { };

-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local Stealth, VanishBuff;
-- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Rogue.Commons,
    Subtlety = HR.GUISettings.APL.Rogue.Subtlety
  };

-- Melee Is In Range Handler
local function IsInMeleeRange ()
  return Target:IsInRange("Melee") and true or false;
end

local function MayBurnShadowDance()
  if Settings.Subtlety.BurnShadowDance == "On Bosses not in Dungeons" and Player:IsInDungeon() then
    return false
  elseif Settings.Subtlety.BurnShadowDance ~= "Always" and not Target:IsInBossList() then
    return false
  else
    return true
  end
end

local function UsePriorityRotation()
  if Cache.EnemiesCount[10] < 2 then
    return false
  end
  if Settings.Subtlety.UsePriorityRotation == "Always" then
    return true
  end
  if Settings.Subtlety.UsePriorityRotation == "On Bosses" and Target:IsInBossList() then
    return true
  end
  -- Zul Mythic
  if Player:InstanceDifficulty() == 16 and Target:NPCID() == 138967 then
    return true
  end
  return false
end

local function num(val)
  if val then return 1 else return 0 end
end

-- APL Action Lists (and Variables)
-- actions+=/variable,name=stealth_threshold,value=25+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+talent.shadow_focus.enabled*20+talent.alacrity.enabled*10+15*(spell_targets.shuriken_storm>=3)
local function Stealth_Threshold ()
  return 25 + num(S.Vigor:IsAvailable()) * 35 + num(S.MasterofShadows:IsAvailable()) * 25 + num(S.ShadowFocus:IsAvailable()) * 20 + num(S.Alacrity:IsAvailable()) * 10 + num(Cache.EnemiesCount[10] >= 3) * 15;
end
-- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=1.75
local function ShD_Threshold ()
  return S.ShadowDance:ChargesFractional() >= 1.75
end

-- # Finishers
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Finish (ReturnSpellOnly, StealthSpell)
  local ShadowDanceBuff = Player:BuffP(S.ShadowDanceBuff) or (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID())

  -- actions.finish=eviscerate,if=talent.shadow_focus.enabled&buff.nights_vengeance.up&spell_targets.shuriken_storm>=2+3*talent.secret_technique.enabled
  if S.Eviscerate:IsCastable() and IsInMeleeRange() and S.ShadowFocus:IsAvailable() and Player:BuffP(S.NightsVengeanceBuff)
    and Cache.EnemiesCount[10] >= 2 + 3 * num(S.SecretTechnique:IsAvailable()) then
    if ReturnSpellOnly then
      return S.Eviscerate;
    else
      if HR.Cast(S.Eviscerate) then return "Cast Eviscerate (Nights Vengeance)"; end
    end
  end

  if S.Nightblade:IsCastable() then
    local NightbladeThreshold = (6+Rogue.CPSpend()*2)*0.3;
    -- actions.finish+=/nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&remains<tick_time*2
    if IsInMeleeRange() and (not S.DarkShadow:IsAvailable() or not ShadowDanceBuff)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Nightblade)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
      and Target:DebuffRemainsP(S.Nightblade) < 4 then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if HR.Cast(S.Nightblade) then return "Cast Nightblade 1"; end
      end
    end
    -- actions.finish+=/nightblade,cycle_targets=1,if=spell_targets.shuriken_storm>=2&!buff.shadow_dance.up&target.time_to_die>=(5+(2*combo_points))&refreshable
    -- NYI, FIXME, waiting for Replicating Shadows fixes:
    -- actions.finish+=/nightblade,cycle_targets=1,if=!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&(azerite.nights_vengeance.enabled|!azerite.replicating_shadows.enabled|spell_targets.shuriken_storm-active_dot.nightblade>=2)&!buff.shadow_dance.up&target.time_to_die>=(5+(2*combo_points))&refreshable
    if HR.AoEON() and not UsePriorityRotation() and Cache.EnemiesCount[10] >= 2 and not ShadowDanceBuff then
      local BestUnit, BestUnitTTD = nil, 5 + 2 * Player:ComboPoints();
      for _, Unit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemainsP(S.Nightblade))
          and Everyone.CanDoTUnit(Unit, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
          and Unit:DebuffRefreshableP(S.Nightblade, NightbladeThreshold) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        HR.CastLeftNameplate(BestUnit, S.Nightblade);
      end
    end
    -- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
    if IsInMeleeRange() and Target:DebuffRemainsP(S.Nightblade) < S.SymbolsofDeath:CooldownRemainsP() + 10
      and S.SymbolsofDeath:CooldownRemainsP() <= 5
      and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
      and (Target:FilteredTimeToDie(">", 5 + S.SymbolsofDeath:CooldownRemainsP(), -Target:DebuffRemainsP(S.Nightblade)) or Target:TimeToDieIsNotValid()) then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if HR.Cast(S.Nightblade) then return "Cast Nightblade 2"; end
      end
    end
  end
  -- actions.finish+=/secret_technique,if=buff.symbols_of_death.up&(!talent.dark_shadow.enabled|buff.shadow_dance.up)
  if S.SecretTechnique:IsCastable() and Player:BuffP(S.SymbolsofDeath) and (not S.DarkShadow:IsAvailable() or ShadowDanceBuff) then
    if ReturnSpellOnly then
      return S.SecretTechnique;
    else
      if HR.Cast(S.SecretTechnique) then return "Cast Secret Technique"; end
    end
  end
  -- actions.finish+=/secret_technique,if=spell_targets.shuriken_storm>=2+talent.dark_shadow.enabled+talent.nightstalker.enabled
  if S.SecretTechnique:IsCastable() and Cache.EnemiesCount[10] >= 2 + num(S.DarkShadow:IsAvailable()) + num(S.Nightstalker:IsAvailable()) then
    if ReturnSpellOnly then
      return S.SecretTechnique;
    else
      if HR.Cast(S.SecretTechnique) then return "Cast Secret Technique"; end
    end
  end
  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and IsInMeleeRange() then
    if ReturnSpellOnly then
      return S.Eviscerate;
    else
      -- Since Eviscerate costs more than Nightblade, show pooling icon in case conditions change while gaining Energy
      if Player:EnergyPredicted() < S.Eviscerate:Cost() then
        if HR.Cast(S.PoolEnergy) then return "Pool for Finisher"; end
      else
        if HR.Cast(S.Eviscerate) then return "Cast Eviscerate"; end
      end
    end
  end
  return false;
end

-- # Stealthed Rotation
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Stealthed (ReturnSpellOnly, StealthSpell)
  local StealthBuff = Player:Buff(Stealth) or (StealthSpell and StealthSpell:ID() == Stealth:ID())
  -- # If stealth is up, we really want to use Shadowstrike to benefits from the passive bonus, even if we are at max cp (from the precombat MfD).
  -- actions.stealthed=shadowstrike,if=buff.stealth.up
  if StealthBuff and S.Shadowstrike:IsCastable() and (Target:IsInRange(S.Shadowstrike) or IsInMeleeRange()) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 1"; end
    end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&(buff.vanish.up|azerite.the_first_dance.enabled&!talent.dark_shadow.enabled&!talent.subterfuge.enabled&spell_targets.shuriken_storm<3))
  if Player:ComboPointsDeficit() <= 1 - num(S.DeeperStratagem:IsAvailable() and (Player:BuffP(VanishBuff) or S.TheFirstDance:AzeriteEnabled() and not S.DarkShadow:IsAvailable() and not S.Subterfuge:IsAvailable() and Cache.EnemiesCount[10] < 3)) then
    return Finish(ReturnSpellOnly, StealthSpell);
  end
  -- actions.stealthed+=/shadowstrike,cycle_targets=1,if=talent.secret_technique.enabled&talent.find_weakness.enabled&debuff.find_weakness.remains<1&spell_targets.shuriken_storm=2&target.time_to_die-remains>6
  -- !!!NYI!!! (Is this worth it? How do we want to display it in an understandable way?)
  -- actions.stealthed+=/shadowstrike,if=!talent.deeper_stratagem.enabled&azerite.blade_in_the_shadows.rank=3&spell_targets.shuriken_storm=3
  if S.Shadowstrike:IsCastableP() and not S.DeeperStratagem:IsAvailable() and S.BladeInTheShadows:AzeriteRank() == 3 and Cache.EnemiesCount[10] == 3 then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (3T BitS)"; end
    end
  end
  -- actions.stealthed+=/shadowstrike,if=variable.use_priority_rotation&(talent.find_weakness.enabled&debuff.find_weakness.remains<1|talent.weaponmaster.enabled&spell_targets.shuriken_storm<=4|azerite.inevitability.enabled&buff.symbols_of_death.up&spell_targets.shuriken_storm<=3+azerite.blade_in_the_shadows.enabled)
  if S.Shadowstrike:IsCastableP() and UsePriorityRotation() and (S.FindWeakness:IsAvailable() and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 or S.Weaponmaster:IsAvailable() and Cache.EnemiesCount[10] <= 4 or S.Inevitability:AzeriteEnabled() and Player:BuffP(S.SymbolsofDeath) and Cache.EnemiesCount[10] <= 3 + num(S.BladeInTheShadows:AzeriteEnabled())) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (Prio Rotation)"; end
    end
  end
  -- actions.stealthed+=/shuriken_storm,if=spell_targets>=3
  if HR.AoEON() and S.ShurikenStorm:IsCastable() and Cache.EnemiesCount[10] >= 3 then
    if ReturnSpellOnly then
      return S.ShurikenStorm
    else
      if HR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm"; end
    end
  end
  -- actions.stealthed+=/shadowstrike
  if S.Shadowstrike:IsCastable() and (Target:IsInRange(S.Shadowstrike) or IsInMeleeRange()) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 2"; end
    end
  end
  return false;
end

-- # Stealth Macros
-- This returns a table with the original Stealth spell and the result of the Stealthed action list as if the applicable buff was present
local function StealthMacro (StealthSpell)
  local MacroTable = {StealthSpell};

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if StealthSpell == S.Vanish and not Settings.Subtlety.StealthMacro.Vanish then
    if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish"; end
    return false;
  elseif StealthSpell == S.Shadowmeld and not Settings.Subtlety.StealthMacro.Shadowmeld then
    if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld"; end
    return false;
  elseif StealthSpell == S.ShadowDance and not Settings.Subtlety.StealthMacro.ShadowDance then
    if HR.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance"; end
    return false;
  end

  tableinsert(MacroTable, Stealthed(true, StealthSpell))

   -- Note: In case DfA is adviced (which can only be a combo for ShD), we swap them to let understand it's DfA then ShD during DfA (DfA - ShD bug)
  if MacroTable[1] == S.ShadowDance and MacroTable[2] == S.DeathfromAbove then
    return HR.CastQueue(MacroTable[2], MacroTable[1]);
  else
    return HR.CastQueue(unpack(MacroTable));
  end
end

-- # Cooldowns
local function CDs ()
  if IsInMeleeRange() then
    if HR.CDsON() then
      -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
      -- TODO: Add Potion Suggestion

      -- Racials
      if Player:IsStealthedP(true, false) then
        -- actions.cds+=/blood_fury,if=stealthed.rogue
        if S.BloodFury:IsCastable() then
          if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
        end
        -- actions.cds+=/berserking,if=stealthed.rogue
        if S.Berserking:IsCastable() then
          if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
        end
      end
    end

    if Player:Buff(S.ShurikenTornado) then
      -- actions.cds+=/shadow_dance,off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
      if not Player:Buff(S.SymbolsofDeath) and not Player:Buff(S.ShadowDance) then
        if HR.CastQueue(S.SymbolsofDeath, S.ShadowDance) then return "Dance + Symbols (during Tornado)"; end
      elseif not Player:Buff(S.SymbolsofDeath) then
        if HR.Cast(S.SymbolsofDeath) then return "Cast Symbols of Death (during Tornado)"; end
      elseif not Player:Buff(S.ShadowDanceBuff) then
        if HR.Cast(S.ShadowDance) then return "Cast Shadow Dance (during Tornado)"; end
      end
    end
    -- actions.cds+=/symbols_of_death,if=dot.nightblade.ticking&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|spell_targets.shuriken_storm<3|!cooldown.shuriken_tornado.up)
    if S.SymbolsofDeath:IsCastable() and Target:DebuffP(S.Nightblade)
      and (not S.ShurikenTornado:IsAvailable() or S.ShadowFocus:IsAvailable() or Cache.EnemiesCount[10] < 3 or not S.ShurikenTornado:CooldownUp()) then
      if HR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death"; end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
    if S.MarkedforDeath:IsCastable() and Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()) then
      if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death"; end
    end
    -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
    -- Note: Without Settings.Subtlety.STMfDAsDPSCD
    if not Settings.Subtlety.STMfDAsDPSCD and S.MarkedforDeath:IsCastable() and not Player:IsStealthedP(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
      HR.CastSuggested(S.MarkedforDeath);
    end
    if HR.CDsON() then
      -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
      -- Note: With Settings.Subtlety.STMfDAsDPSCD
      if Settings.Subtlety.STMfDAsDPSCD and S.MarkedforDeath:IsCastable() and not Player:IsStealthedP(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death"; end
      end
      -- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all
      if S.ShadowBlades:IsCastable() and not Player:Buff(S.ShadowBlades)
        and Player:ComboPointsDeficit() >= 2 + num(Player:IsStealthedP(true, true)) then
        if HR.Cast(S.ShadowBlades, Settings.Subtlety.GCDasOffGCD.ShadowBlades) then return "Cast Shadow Blades"; end
      end
      -- actions.cds+=/shuriken_tornado,if=spell_targets>=3&!talent.shadow_focus.enabled&dot.nightblade.ticking&!stealthed.all&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1
      if S.ShurikenTornado:IsCastableP() and Cache.EnemiesCount[10] >= 3 and not S.ShadowFocus:IsAvailable() and Target:DebuffP(S.Nightblade) and not Player:IsStealthedP(true, true) and S.SymbolsofDeath:CooldownUp() and S.ShadowDance:Charges() >= 1 then
        if HR.Cast(S.ShurikenTornado) then return "Shuriken Tornado into SoD and Dance"; end
      end
      -- actions.cds+=/shuriken_tornado,if=spell_targets>=3&talent.shadow_focus.enabled&dot.nightblade.ticking&buff.symbols_of_death.up
      if S.ShurikenTornado:IsCastableP() and Cache.EnemiesCount[10] >= 3 and S.ShadowFocus:IsAvailable() and Target:DebuffP(S.Nightblade) and Player:BuffP(S.SymbolsofDeath) then
        if HR.Cast(S.ShurikenTornado) then return "Cast Shuriken Tornado (SF)"; end
      end
      -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=5+talent.subterfuge.enabled
      if S.ShadowDance:IsCastable() and MayBurnShadowDance() and not Player:BuffP(S.ShadowDanceBuff) and Target:FilteredTimeToDie("<=", 5 + num(S.Subterfuge:IsAvailable())) then
        if StealthMacro(S.ShadowDance) then return "Shadow Dance Macro"; end
      end
    end
  end
  return false;
end

-- # Stealth Cooldowns
local function Stealth_CDs ()
  if IsInMeleeRange() then
    -- actions.stealth_cds+=/vanish,if=!variable.shd_threshold&debuff.find_weakness.remains<1&combo_points.deficit>1
    if HR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and not ShD_Threshold() and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 and Player:ComboPointsDeficit() > 1 then
      if StealthMacro(S.Vanish) then return "Vanish Macro"; end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&debuff.find_weakness.remains<1&combo_points.deficit>1
    if HR.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and GetUnitSpeed("player") == 0 and Player:EnergyDeficitPredicted() > 10
      and not ShD_Threshold() and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 and Player:ComboPointsDeficit() > 1 then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
      if Player:Energy() < 40 then
        if HR.Cast(S.PoolEnergy) then return "Pool for Shadowmeld"; end
      end
      if StealthMacro(S.Shadowmeld) then return "Shadowmeld Macro"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=(!talent.dark_shadow.enabled|dot.nightblade.remains>=5+talent.subterfuge.enabled)&(!talent.nightstalker.enabled&!talent.dark_shadow.enabled|!variable.use_priority_rotation|combo_points.deficit<=1+2*azerite.the_first_dance.enabled)&(variable.shd_threshold|buff.symbols_of_death.remains>=1.2|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)
    if (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and (not S.DarkShadow:IsAvailable() or Target:DebuffRemainsP(S.Nightblade) >= 5 + num(S.Subterfuge:IsAvailable()))
      and (not S.Nightstalker:IsAvailable() and not S.DarkShadow:IsAvailable() or not UsePriorityRotation() or Player:ComboPointsDeficit() <= 1 + 2 * num(S.TheFirstDance:AzeriteEnabled()))
      and (ShD_Threshold() or Player:BuffRemainsP(S.SymbolsofDeath) >= 1.2 or (Cache.EnemiesCount[10] >= 4 and S.SymbolsofDeath:CooldownRemainsP() > 10)) then
      if StealthMacro(S.ShadowDance) then return "ShadowDance Macro 1"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=target.time_to_die<cooldown.symbols_of_death.remains
    if (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and MayBurnShadowDance() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and Target:TimeToDie() < S.SymbolsofDeath:CooldownRemainsP() then
      if StealthMacro(S.ShadowDance) then return "ShadowDance Macro 2"; end
    end
  end
  return false;
end

-- # Builders
local function Build ()
  -- actions.build=shuriken_storm,if=spell_targets>=2|buff.the_dreadlords_deceit.stack>=29
  if HR.AoEON() and S.ShurikenStorm:IsCastableP() and (Cache.EnemiesCount[10] >= 2 or Player:BuffStackP(S.TheDreadlordsDeceit) >= 29) then
    if HR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm"; end
  end
  if IsInMeleeRange() then
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if HR.Cast(S.Gloomblade) then return "Cast Gloomblade"; end
    -- actions.build+=/backstab
    elseif S.Backstab:IsCastable() then
      if HR.Cast(S.Backstab) then return "Cast Backstab"; end
    end
  end
  return false;
end

local MythicDungeon;
do
  local SappedSoulSpells = {
    {S.Kick, "Cast Kick (Sapped Soul)", function () return IsInMeleeRange(); end},
    {S.Feint, "Cast Feint (Sapped Soul)", function () return true; end},
    {S.CrimsonVial, "Cast Crimson Vial (Sapped Soul)", function () return true; end}
  };
  MythicDungeon = function ()
    -- Sapped Soul
    if HL.MythicDungeon() == "Sapped Soul" then
      for i = 1, #SappedSoulSpells do
        local Spell = SappedSoulSpells[i];
        if Spell[1]:IsCastable() and Spell[3]() then
          HR.ChangePulseTimer(1);
          HR.Cast(Spell[1]);
          return Spell[2];
        end
      end
    end
    return false;
  end
end
local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
    -- Kidney Shot
    if IsInMeleeRange() and S.KidneyShot:IsCastable() and Player:ComboPoints() > 0 then
      if HR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end
local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end},
  {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:IsStealthedP(true, true); end}
};

-- APL Main
local function APL ()
  -- Spell ID Changes check
  if S.Subterfuge:IsAvailable() then
    Stealth = S.Stealth2;
    VanishBuff = S.VanishBuff2;
  else
    Stealth = S.Stealth;
    VanishBuff = S.VanishBuff;
  end
  -- Unit Update
  HL.GetEnemies(10, true); -- Shuriken Storm & Death from Above
  HL.GetEnemies("Melee"); -- Melee
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
      -- Note: Since 7.2.5, Blizzard disallowed Stealth cast under ShD (workaround to prevent the Extended Stealth bug)
      if not Player:Buff(S.ShadowDanceBuff) and not Player:Buff(VanishBuff) then
        ShouldReturn = Rogue.Stealth(Stealth);
        if ShouldReturn then return ShouldReturn; end
      end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() and (Target:IsInRange(S.Shadowstrike) or IsInMeleeRange()) then
        -- Precombat CDs
        if HR.CDsON() then
          if S.MarkedforDeath:IsCastableP() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
            if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)"; end
          end
          if S.ShadowBlades:IsCastable() and not Player:Buff(S.ShadowBlades) then
            if HR.Cast(S.ShadowBlades, Settings.Subtlety.GCDasOffGCD.ShadowBlades) then return "Cast Shadow Blades (OOC)"; end
          end
        end
        if Player:IsStealthedP(true, true) then
          ShouldReturn = Stealthed();
          if ShouldReturn then return ShouldReturn .. " (OOC)"; end
          if Player:EnergyPredicted() < 30 then -- To avoid pooling icon spam
            if HR.Cast(S.PoolEnergy) then return "Stealthed Pooling (OOC)"; end
          else
            return "Stealthed Pooling (OOC)";
          end
        elseif Player:ComboPoints() >= 5 then
          ShouldReturn = Finish();
          if ShouldReturn then return ShouldReturn .. " (OOC)"; end
        elseif S.Backstab:IsCastable() then
          if HR.Cast(S.Backstab) then return "Cast Backstab (OOC)"; end
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
      Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, Interrupts);

      -- # Check CDs at first
      -- actions=call_action_list,name=cds
      ShouldReturn = CDs();
      if ShouldReturn then return "CDs: " .. ShouldReturn; end

      -- SPECIAL HACK FOR SHURIKEN TORNADO
      -- Show a finisher if we can assume we will have enough CP with the next global
      if Player:Buff(S.ShurikenTornado) and (Player:ComboPointsDeficit() - Cache.EnemiesCount[10] - num(Player:BuffP(S.ShadowBlades))) <= 1 then
        ShouldReturn = Finish();
        if ShouldReturn then return "Finish (during Tornado): " .. ShouldReturn; end
      end

      -- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
      -- actions+=/run_action_list,name=stealthed,if=stealthed.all
      if Player:IsStealthedP(true, true) then
        ShouldReturn = Stealthed();
        if ShouldReturn then return "Stealthed: " .. ShouldReturn; end
        -- run_action_list forces the return
        if Player:EnergyPredicted() < 30 then -- To avoid pooling icon spam
          if HR.Cast(S.PoolEnergy) then return "Stealthed Pooling"; end
        else
          return "Stealthed Pooling";
        end
      end

      -- # Apply Nightblade at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
      -- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
      if S.Nightblade:IsCastableP() and IsInMeleeRange()
        and (Target:FilteredTimeToDie(">", 6) or Target:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage() * Settings.Subtlety.EviscerateDMGOffset)
        and Target:DebuffRemainsP(S.Nightblade) < Player:GCD() and Player:ComboPoints() >= 4 - (HL.CombatTime() < 10 and 2 or 0) then
        if HR.Cast(S.Nightblade) then return "Cast Nightblade (Low Duration)"; end
      end

      -- actions+=/call_action_list,name=stealth_cds,if=variable.use_priority_rotation
      if UsePriorityRotation() then
        local ShouldReturn = Stealth_CDs();
        if ShouldReturn then return "Stealth CDs: (Priority Rotation)" .. ShouldReturn; end
      end

      -- # Consider using a Stealth CD when reaching the energy threshold and having space for at least 4 CP
      -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&combo_points.deficit>=4
      if Player:EnergyDeficit() <= Stealth_Threshold() and Player:ComboPointsDeficit() >= 4 then
        local ShouldReturn = Stealth_CDs();
        if ShouldReturn then return "Stealth CDs: " .. ShouldReturn; end
      end
      -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&talent.dark_shadow.enabled&talent.secret_technique.enabled&cooldown.secret_technique.up&spell_targets.shuriken_storm<=4
      if Player:EnergyDeficit() <= Stealth_Threshold() and S.DarkShadow:IsAvailable() and S.SecretTechnique:IsAvailable() and S.SecretTechnique:CooldownUp()
        and Cache.EnemiesCount[10] <= 4 then
        local ShouldReturn = Stealth_CDs();
        if ShouldReturn then return "Stealth CDs: (SecTec) " .. ShouldReturn; end
      end

      -- # Finish at 4+ without DS, 5+ with DS (outside stealth)
      -- actions+=/call_action_list,name=finish,if=combo_points.deficit<=1|target.time_to_die<=1&combo_points>=3
      if Player:ComboPointsDeficit() <= 1 or (Target:FilteredTimeToDie("<=", 1) and Player:ComboPoints() >= 3) then
        ShouldReturn = Finish();
        if ShouldReturn then return "Finish: " .. ShouldReturn; end
      end

      -- actions+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
      if Cache.EnemiesCount[10] == 4 and Player:ComboPoints() >= 4 then
        ShouldReturn = Finish();
        if ShouldReturn then return "Finish 4T: " .. ShouldReturn; end
      end

      -- # Use a builder when reaching the energy threshold
      -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
      if Player:EnergyDeficitPredicted() <= Stealth_Threshold() then
        ShouldReturn = Build();
        if ShouldReturn then return "Build: " .. ShouldReturn; end
      end

      -- # Lowest priority in all of the APL because it causes a GCD
      -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
      if S.ArcaneTorrent:IsCastableP("Melee") and Player:EnergyDeficitPredicted() > 15 + Player:EnergyRegen() then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsCastableP("Melee") then
        if HR.Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse"; end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsCastableP("Melee") then
        if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment"; end
      end

      -- Shuriken Toss Out of Range
      if S.ShurikenToss:IsCastable(30) and not Target:IsInRange(10) and not Player:IsStealthedP(true, true) and not Player:BuffP(S.Sprint)
        and Player:EnergyDeficitPredicted() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if HR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Shadowstrike:IsCastable() and IsInMeleeRange() then
        if HR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

HR.SetAPL(261, APL);

-- Last Update: 2019-03-04

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/stealth
-- actions.precombat+=/marked_for_death,precombat_seconds=15
-- actions.precombat+=/shadow_blades,precombat_seconds=1
-- actions.precombat+=/potion
--
-- # Check CDs at first
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- actions+=/call_action_list,name=cds
-- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- # Apply Nightblade at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
-- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
-- # Only change rotation if we have priority_rotation set and multiple targets up.
-- actions+=/variable,name=use_priority_rotation,value=priority_rotation&spell_targets.shuriken_storm>=2
-- # Priority Rotation? Let's give a crap about energy for the stealth CDs (builder still respect it). Yup, it can be that simple.
-- actions+=/call_action_list,name=stealth_cds,if=variable.use_priority_rotation
-- # Used to define when to use stealth CDs or builders
-- actions+=/variable,name=stealth_threshold,value=25+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+talent.shadow_focus.enabled*20+talent.alacrity.enabled*10+15*(spell_targets.shuriken_storm>=3)
-- # Consider using a Stealth CD when reaching the energy threshold and having space for at least 4 CP
-- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&combo_points.deficit>=4
-- # With Dark Shadow, also use a Stealth CD when reaching the energy threshold and Secret Technique is ready. Only a gain up to 4 targets.
-- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&talent.dark_shadow.enabled&talent.secret_technique.enabled&cooldown.secret_technique.up&spell_targets.shuriken_storm<=4
-- # Finish at 4+ without DS, 5+ with DS (outside stealth)
-- actions+=/call_action_list,name=finish,if=combo_points.deficit<=1|target.time_to_die<=1&combo_points>=3
-- # With DS also finish at 4+ against exactly 4 targets (outside stealth)
-- actions+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
-- # Use a builder when reaching the energy threshold
-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
-- # Lowest priority in all of the APL because it causes a GCD
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
--
-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|buff.symbols_of_death.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=10)
-- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
-- actions.cds+=/berserking,if=buff.symbols_of_death.up
-- # Use Dance off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds+=/shadow_dance,use_off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- # (Unless already up because we took Shadow Focus) use Symbols off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds+=/symbols_of_death,use_off_gcd=1,if=buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- # Use Symbols on cooldown (after first Nightblade) unless we are going to pop Tornado and do not have Shadow Focus.
-- actions.cds+=/symbols_of_death,if=dot.nightblade.ticking&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|spell_targets.shuriken_storm<3|!cooldown.shuriken_tornado.up)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or not stealthed without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.all&combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD on boss without any CP and no stealth.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.all&combo_points.deficit>=cp_max_spend
-- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all
-- # At 3+ without Shadow Focus use Tornado with SoD and Dance ready. We will pop those before the first storm comes in.
-- actions.cds+=/shuriken_tornado,if=spell_targets>=3&!talent.shadow_focus.enabled&dot.nightblade.ticking&!stealthed.all&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1
-- # At 3+ with Shadow Focus use Tornado with SoD already up.
-- actions.cds+=/shuriken_tornado,if=spell_targets>=3&talent.shadow_focus.enabled&dot.nightblade.ticking&buff.symbols_of_death.up
-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=5+talent.subterfuge.enabled&!raid_event.adds.up
--
-- # Stealth Cooldowns
-- # Helper Variable
-- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=1.75
-- # Vanish unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/vanish,if=!variable.shd_threshold&debuff.find_weakness.remains<1&combo_points.deficit>1
-- # Pool for Shadowmeld + Shadowstrike unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&debuff.find_weakness.remains<1&combo_points.deficit>1
-- # With Dark Shadow only Dance when Nightblade will stay up. Use during Symbols or above threshold. Only before finishers if we have amp talents and priority rotation.
-- actions.stealth_cds+=/shadow_dance,if=(!talent.dark_shadow.enabled|dot.nightblade.remains>=5+talent.subterfuge.enabled)&(!talent.nightstalker.enabled&!talent.dark_shadow.enabled|!variable.use_priority_rotation|combo_points.deficit<=1+2*azerite.the_first_dance.enabled)&(variable.shd_threshold|buff.symbols_of_death.remains>=1.2|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)
-- actions.stealth_cds+=/shadow_dance,if=target.time_to_die<cooldown.symbols_of_death.remains&!raid_event.adds.up
--
-- # Stealthed Rotation
-- # If stealth is up, we really want to use Shadowstrike to benefits from the passive bonus, even if we are at max cp (from the precombat MfD).
-- actions.stealthed=shadowstrike,if=buff.stealth.up
-- # Finish at 4+ CP without DS, 5+ with DS, and 6 with DS after Vanish or The First Dance and no Dark Shadow + no Subterfuge
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&(buff.vanish.up|azerite.the_first_dance.enabled&!talent.dark_shadow.enabled&!talent.subterfuge.enabled&spell_targets.shuriken_storm<3))
-- # At 2 targets with Secret Technique keep up Find Weakness by cycling Shadowstrike.
-- actions.stealthed+=/shadowstrike,cycle_targets=1,if=talent.secret_technique.enabled&talent.find_weakness.enabled&debuff.find_weakness.remains<1&spell_targets.shuriken_storm=2&target.time_to_die-remains>6
-- # Without Deeper Stratagem and 3 Ranks of Blade in the Shadows it is worth using Shadowstrike on 3 targets.
-- actions.stealthed+=/shadowstrike,if=!talent.deeper_stratagem.enabled&azerite.blade_in_the_shadows.rank=3&spell_targets.shuriken_storm=3
-- # For priority rotation, use Shadowstrike over Storm 1) with WM against up to 4 targets, 2) if FW is running off (on any amount of targets), or 3) to maximize SoD extension with Inevitability on 3 targets (4 with BitS).
-- actions.stealthed+=/shadowstrike,if=variable.use_priority_rotation&(talent.find_weakness.enabled&debuff.find_weakness.remains<1|talent.weaponmaster.enabled&spell_targets.shuriken_storm<=4|azerite.inevitability.enabled&buff.symbols_of_death.up&spell_targets.shuriken_storm<=3+azerite.blade_in_the_shadows.enabled)
-- actions.stealthed+=/shuriken_storm,if=spell_targets>=3
-- actions.stealthed+=/shadowstrike
--
-- # Finishers
-- # Eviscerate highest priority at 2+ targets with Shadow Focus (5+ with Secret Technique in addition) and Night's Vengeance up.
-- actions.finish=eviscerate,if=talent.shadow_focus.enabled&buff.nights_vengeance.up&spell_targets.shuriken_storm>=2+3*talent.secret_technique.enabled
-- # Keep up Nightblade if it is about to run out. Do not use NB during Dance, if talented into Dark Shadow.
-- actions.finish+=/nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&remains<tick_time*2
-- # Multidotting outside Dance on targets that will live for the duration of Nightblade, refresh during pandemic. Multidot as long as 2+ targets do not have Nightblade up with Replicating Shadows (unless you have Night's Vengeance too).
-- actions.finish+=/nightblade,cycle_targets=1,if=!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&(azerite.nights_vengeance.enabled|!azerite.replicating_shadows.enabled|spell_targets.shuriken_storm-active_dot.nightblade>=2)&!buff.shadow_dance.up&target.time_to_die>=(5+(2*combo_points))&refreshable
-- # Refresh Nightblade early if it will expire during Symbols. Do that refresh if SoD gets ready in the next 5s.
-- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
-- # Secret Technique during Symbols. With Dark Shadow only during Shadow Dance (until threshold in next line).
-- actions.finish+=/secret_technique,if=buff.symbols_of_death.up&(!talent.dark_shadow.enabled|buff.shadow_dance.up)
-- # With enough targets always use SecTec on CD.
-- actions.finish+=/secret_technique,if=spell_targets.shuriken_storm>=2+talent.dark_shadow.enabled+talent.nightstalker.enabled
-- actions.finish+=/eviscerate
--
-- # Builders
-- actions.build=shuriken_storm,if=spell_targets>=2
-- actions.build+=/gloomblade
-- actions.build+=/backstab

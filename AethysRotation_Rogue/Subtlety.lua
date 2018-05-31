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
    ArcanePulse                           = Spell(260364),
    ArcaneTorrent                         = Spell(50613),
    Berserking                            = Spell(26297),
    BloodFury                             = Spell(20572),
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
    DarkShadow                            = Spell(245687),
    DeeperStratagem                       = Spell(193531),
    EnvelopingShadows                     = Spell(238104),
    FindWeaknessDebuff                    = Spell(91021),
    Gloomblade                            = Spell(200758),
    MarkedforDeath                        = Spell(137619),
    MasterofShadows                       = Spell(196976),
    Nightstalker                          = Spell(14062),
    ShurikenTornado                       = Spell(277925),
    Subterfuge                            = Spell(108208),
    Vigor                                 = Spell(14983),
    -- Azerite Traits
    SharpenedBladesBuff                   = Spell(272916),
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
          1.25 *
          -- Nightstalker Multiplier
          (S.Nightstalker:IsAvailable() and Player:IsStealthed(true) and 1.12 or 1) *
          -- Deeper Stratagem Multiplier
          (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
          -- Dark Shadow Multiplier
          (S.DarkShadow:IsAvailable() and Player:BuffP(S.ShadowDanceBuff) and 1.25 or 1) *
          -- Symbols of Death Multiplier
          (Player:BuffP(S.SymbolsofDeath) and 1.15+(AC.Tier20_2Pc and 0.1 or 0) or 1) *
          -- Shuriken Combo Multiplier
          (Player:BuffP(S.ShurikenComboBuff) and 1 + Player:Buff(S.ShurikenComboBuff,  16) / 100 or 1) *
          -- Mastery Finisher Multiplier
          (1 + Player:MasteryPct()/100) *
          -- Versatility Damage Multiplier
          (1 + Player:VersatilityDmgPct()/100) *
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
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Subtlety = AR.GUISettings.APL.Rogue.Subtlety
  };

-- Melee Is In Range Handler
local function IsInMeleeRange ()
  return Target:IsInRange("Melee") and true or false;
end

local function num(val)
  if val then return 1 else return 0 end
end

-- APL Action Lists (and Variables)
-- actions.precombat+=/variable,name=stealth_threshold,value=60+talent.vigor.enabled*35+talent.master_of_shadows.enabled*10
local function Stealth_Threshold ()
  return 60 + num(S.Vigor:IsAvailable()) * 35 + num(S.MasterofShadows:IsAvailable()) * 10;
end
-- actions.stealth_cds=variable,name=capping_shd,value=cooldown.shadow_dance.charges_fractional>=1.725+0.725*talent.enveloping_shadows.enabled
local function Capping_ShD ()
  return S.ShadowDance:ChargesFractional() >= 1.725 + 0.725 * num(S.EnvelopingShadows:IsAvailable())
end

-- # Finishers
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Finish (ReturnSpellOnly, StealthSpell)
  local ShadowDanceBuff = Player:BuffP(S.ShadowDanceBuff) or (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID())

  if S.Nightblade:IsCastable() then
    local NightbladeThreshold = (6+Rogue.CPSpend()*2)*0.3;
    -- actions.finish=nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&remains<tick_time*2&(spell_targets.shuriken_storm<4|!buff.symbols_of_death.up)
    if IsInMeleeRange() and (not S.DarkShadow:IsAvailable() or not ShadowDanceBuff)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Nightblade)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
      and Target:DebuffRemainsP(S.Nightblade) < 4
      and (Cache.EnemiesCount[10] < 4 or not Player:BuffP(S.SymbolsofDeath)) then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if AR.Cast(S.Nightblade) then return "Cast Nightblade 1"; end
      end
    end
    -- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5+(combo_points=6)&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
    if IsInMeleeRange() and Target:DebuffRemainsP(S.Nightblade) < S.SymbolsofDeath:CooldownRemainsP() + 10
      and S.SymbolsofDeath:CooldownRemainsP() <= 5 + (Player:ComboPoints() == 6 and 1 or 0)
      and (Target:FilteredTimeToDie(">", 5 + S.SymbolsofDeath:CooldownRemainsP(), -Target:DebuffRemainsP(S.Nightblade)) or Target:TimeToDieIsNotValid()) then
      if ReturnSpellOnly then
        return S.Nightblade;
      else
        if AR.Cast(S.Nightblade) then return "Cast Nightblade 2"; end
      end
    end
  end
  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and IsInMeleeRange() then
    if ReturnSpellOnly then
      return S.Eviscerate;
    else
      -- Since Eviscerate costs more than Nightblade, show pooling icon in case conditions change while gaining Energy
      if Player:EnergyPredicted() < S.Eviscerate:Cost() then
        if AR.Cast(S.PoolEnergy) then return "Pool for Finisher"; end
      else
        if AR.Cast(S.Eviscerate) then return "Cast Eviscerate"; end
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
      if AR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 1"; end
    end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&buff.vanish.up)
  if Player:ComboPointsDeficit() <= 1 - num(S.DeeperStratagem:IsAvailable() and Player:BuffP(VanishBuff)) then
    return Finish(ReturnSpellOnly, StealthSpell);
  end
  -- actions.stealthed+=/shuriken_storm,if=spell_targets.shuriken_storm>=3
  if S.ShurikenStorm:IsCastable() and Cache.EnemiesCount[10] >= 3 then
    if ReturnSpellOnly then
      return S.ShurikenStorm
    else
      if AR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm"; end
    end
  end
  -- actions.stealthed+=/shadowstrike
  if S.Shadowstrike:IsCastable() and (Target:IsInRange(S.Shadowstrike) or IsInMeleeRange()) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if AR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 2"; end
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
    if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish"; end
    return false;
  elseif StealthSpell == S.Shadowmeld and not Settings.Subtlety.StealthMacro.Shadowmeld then
    if AR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld"; end
    return false;
  elseif StealthSpell == S.ShadowDance and not Settings.Subtlety.StealthMacro.ShadowDance then
    if AR.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance"; end
    return false;
  end

  tableinsert(MacroTable, Stealthed(true, StealthSpell))

   -- Note: In case DfA is adviced (which can only be a combo for ShD), we swap them to let understand it's DfA then ShD during DfA (DfA - ShD bug)
  if MacroTable[1] == S.ShadowDance and MacroTable[2] == S.DeathfromAbove then
    return AR.CastQueue(MacroTable[2], MacroTable[1]);
  else
    return AR.CastQueue(unpack(MacroTable));
  end
end

-- # Cooldowns
local function CDs ()
  if IsInMeleeRange() then
    if AR.CDsON() then
      -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
      -- TODO: Add Potion Suggestion

      -- Racials
      if Player:IsStealthed(true, false) then
        -- actions.cds+=/blood_fury,if=stealthed.rogue
        if S.BloodFury:IsCastable() then
          if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
        end
        -- actions.cds+=/berserking,if=stealthed.rogue
        if S.Berserking:IsCastable() then
          if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
        end
      end
    end
    -- actions.cds+=/arcane_torrent,if=energy.deficit>70
    --if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficitPredicted() > 70 then
    --  if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
    --end

    -- actions.cds+=/symbols_of_death
    if S.SymbolsofDeath:IsCastable() then
      if AR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death"; end
    end
    if AR.CDsON() then
      -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
      -- Note: Done at the start of the Rotation (Rogue Commmon)
      -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
      if S.MarkedforDeath:IsCastable() then
        if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()) or (Settings.Subtlety.STMfDAsDPSCD and not Player:IsStealthed(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend()) then
          if AR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death"; end
        elseif Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
          AR.CastSuggested(S.MarkedforDeath);
        end
      end
      -- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all
      if S.ShadowBlades:IsCastable() and not Player:Buff(S.ShadowBlades)
        and Player:ComboPointsDeficit() >= 2 + num(Player:IsStealthed(true, true)) then
        if AR.Cast(S.ShadowBlades) then return "Cast Shadow Blades"; end
      end
      -- actions.cds+=/shuriken_tornado,if=spell_targets>=3&dot.nightblade.ticking&buff.symbols_of_death.up&buff.shadow_dance.up
      if S.ShurikenTornado:IsCastableP() and Cache.EnemiesCount[10] >= 3 and Target:DebuffP(S.Nightblade) and Player:BuffP(S.SymbolsofDeath) and Player:BuffP(S.ShadowDanceBuff) then
        if AR.Cast(S.ShurikenTornado) then return "Cast Shuriken Tornado"; end
      end
      -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=5+talent.subterfuge.enabled
      if S.ShadowDance:IsCastable() and not Player:BuffP(S.ShadowDanceBuff) and Target:FilteredTimeToDie("<=", 5 + num(S.Subterfuge:IsAvailable())) then
        if StealthMacro(S.ShadowDance) then return "Shadow Dance Macro"; end
      end
    end
  end
  return false;
end

-- # Stealth Cooldowns
local function Stealth_CDs ()
  if IsInMeleeRange() then
    -- actions.stealth_cds+=/vanish,if=!variable.capping_shd&debuff.find_weakness.remains<1
    if AR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and not Capping_ShD() and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 then
      if StealthMacro(S.Vanish) then return "Vanish Macro"; end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.capping_shd&debuff.find_weakness.remains<1
    if AR.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and GetUnitSpeed("player") == 0 and Player:EnergyDeficitPredicted() > 10
      and not Capping_ShD() and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
      if Player:Energy() < 40 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Shadowmeld"; end
      end
      if StealthMacro(S.Shadowmeld) then return "Shadowmeld Macro"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=(!talent.dark_shadow.enabled|dot.nightblade.remains>=5+talent.subterfuge.enabled)&(variable.capping_shd|buff.symbols_of_death.remains>=1.2cooldown.symbols_of_death.remains>=12)
    if (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and (not S.DarkShadow:IsAvailable() or Target:DebuffRemainsP(S.Nightblade) >= 5 + num(S.Subterfuge:IsAvailable()))
      and (Capping_ShD() or Player:BuffRemainsP(S.SymbolsofDeath) >= 1.2 or S.SymbolsofDeath:CooldownRemainsP() >= 12) then
      if StealthMacro(S.ShadowDance) then return "ShadowDance Macro 1"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=target.time_to_die<cooldown.symbols_of_death.remains
    if (AR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and Target:TimeToDie() < S.SymbolsofDeath:CooldownRemainsP() then
      if StealthMacro(S.ShadowDance) then return "ShadowDance Macro 2"; end
    end
  end
  return false;
end

-- # Builders
local function Build ()
  -- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2
  if S.ShurikenStorm:IsCastableP() and Cache.EnemiesCount[10] >= 2 then
    if AR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm"; end
  end
  -- actions.build=shuriken_toss,if=buff.sharpened_blades.stack>=19
  if S.ShurikenToss:IsCastableP() and (Player:BuffStackP(S.SharpenedBladesBuff) >= 19) then
    if AR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
  end
  if IsInMeleeRange() then
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if AR.Cast(S.Gloomblade) then return "Cast Gloomblade"; end
    -- actions.build+=/backstab
    elseif S.Backstab:IsCastable() then
      if AR.Cast(S.Backstab) then return "Cast Backstab"; end
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
    if AC.MythicDungeon() == "Sapped Soul" then
      for i = 1, #SappedSoulSpells do
        local Spell = SappedSoulSpells[i];
        if Spell[1]:IsCastable() and Spell[3]() then
          AR.ChangePulseTimer(1);
          AR.Cast(Spell[1]);
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
      if AR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end
local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end},
  {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:IsStealthed(true, true); end}
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
  AC.GetEnemies(10, true); -- Shuriken Storm & Death from Above
  AC.GetEnemies("Melee"); -- Melee
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
        if Player:IsStealthed(true, true) then
          ShouldReturn = Stealthed();
          if ShouldReturn then return ShouldReturn .. " (OOC)"; end
          if Player:EnergyPredicted() < 30 then -- To avoid pooling icon spam
            if AR.Cast(S.PoolEnergy) then return "Stealthed Pooling (OOC)"; end
          else
            return "Stealthed Pooling (OOC)";
          end
        elseif Player:ComboPoints() >= 5 then
          ShouldReturn = Finish();
          if ShouldReturn then return ShouldReturn .. " (OOC)"; end
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
      Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, Interrupts);

      -- # Check CDs at first
      -- actions=call_action_list,name=cds
      ShouldReturn = CDs();
      if ShouldReturn then return "CDs: " .. ShouldReturn; end

      -- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
      -- actions+=/run_action_list,name=stealthed,if=stealthed.all
      if Player:IsStealthed(true, true) then
        ShouldReturn = Stealthed();
        if ShouldReturn then return "Stealthed: " .. ShouldReturn; end
        -- run_action_list forces the return
        if Player:EnergyPredicted() < 30 then -- To avoid pooling icon spam
          if AR.Cast(S.PoolEnergy) then return "Stealthed Pooling"; end
        else
          return "Stealthed Pooling";
        end
      end

      -- # Apply Nightblade at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
      -- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
      if S.Nightblade:IsCastableP() and IsInMeleeRange()
        and (Target:FilteredTimeToDie(">", 6) or Target:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(Target, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
        and Target:DebuffRemainsP(S.Nightblade) < Player:GCD() and Player:ComboPoints() >= 4 - (AC.CombatTime() < 10 and 2 or 0) then
        if AR.Cast(S.Nightblade) then return "Cast Nightblade (Low Duration)"; end
      end

      -- # Consider using a Stealth CD when reaching the energy threshold and having space for at least 4 CP
      -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&combo_points.deficit>=4
      if (Player:EnergyDeficit() <= Stealth_Threshold() and Player:ComboPointsDeficit() >= 4) then
        local ShouldReturn = Stealth_CDs();
        if ShouldReturn then return "Stealth CDs: " .. ShouldReturn; end
      end

      -- # Finish at 4+ without DS, 5+ with DS (outside stealth)
      -- actions+=/call_action_list,name=finish,if=combo_points>=4+talent.deeper_stratagem.enabled|target.time_to_die<=1&combo_points>=3
      if Player:ComboPoints() >= 4 + num(S.DeeperStratagem:IsAvailable())
        or (Target:FilteredTimeToDie("<=", 1) and Player:ComboPoints() >= 3) then
        ShouldReturn = Finish();
        if ShouldReturn then return "Finish: " .. ShouldReturn; end
      end
      -- # Wait for Shadow Techniques proc if you are at 5 CP, 30+ energy missing and the proc will happen within the next second (DS, out of stealth, no Blades)
      -- actions+=/wait,sec=time_to_sht.5,if=combo_points=5&time_to_sht.5<=1&energy.deficit>=30&!buff.shadow_blades.up
      if Player:ComboPoints() == 5 and Player:EnergyDeficitPredicted() >= 30 and not Player:Buff(S.ShadowBlades) and Player:TimeToSht(5) <= 1 then
        if AR.Cast(S.PoolEnergy) then return "Wait for Shadow Techniques"; end
      end

      -- # Use a builder when reaching the energy threshold
      -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
      if Player:EnergyDeficitPredicted() <= Stealth_Threshold() then
        ShouldReturn = Build();
        if ShouldReturn then return "Build: " .. ShouldReturn; end
      end

      -- # Lowest priority in all of the APL because it causes a GCD
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsCastableP() and IsInMeleeRange() then
        if AR.Cast(S.ArcanePulse) then return "Cast Arcane Pulse"; end
      end

      -- Shuriken Toss Out of Range
      if S.ShurikenToss:IsCastable(30) and not Target:IsInRange(10) and not Player:IsStealthed(true, true) and not Player:BuffP(S.Sprint)
        and Player:EnergyDeficitPredicted() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if AR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Shadowstrike:IsCastable() and IsInMeleeRange() then
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(261, APL);

-- Last Update: 2018-05-23

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- # Defined variables that don't change during the fight.
-- # Used to define when to use stealth CDs or builders
-- actions.precombat+=/variable,name=stealth_threshold,value=60+talent.vigor.enabled*35+talent.master_of_shadows.enabled*10
-- actions.precombat+=/stealth
-- actions.precombat+=/marked_for_death,precombat=1
-- actions.precombat+=/shadow_blades
-- actions.precombat+=/potion

-- # Check CDs at first
-- actions=call_action_list,name=cds
-- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- # Apply Nightblade at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
-- actions+=/nightblade,if=target.time_to_die>6&remains<gcd.max&combo_points>=4-(time<10)*2
-- # Consider using a Stealth CD when reaching the energy threshold and having space for at least 4 CP
-- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold&combo_points.deficit>=4
-- # Finish at 4+ without DS, 5+ with DS (outside stealth)
-- actions+=/call_action_list,name=finish,if=combo_points>=4+talent.deeper_stratagem.enabled|target.time_to_die<=1&combo_points>=3
-- # Wait for Shadow Techniques proc if you are at 5 CP, 30+ energy missing and the proc will happen within the next second (DS, out of stealth, no Blades)
-- actions+=/wait,sec=time_to_sht.5,if=combo_points=5&time_to_sht.5<=1&energy.deficit>=30&!buff.shadow_blades.up
-- # Use a builder when reaching the energy threshold
-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
-- # Lowest priority in all of the APL because it causes a GCD
-- actions+=/arcane_pulse

-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
-- actions.cds+=/blood_fury,if=stealthed.rogue
-- actions.cds+=/berserking,if=stealthed.rogue
-- actions.cds+=/arcane_torrent,if=energy.deficit>70
-- actions.cds+=/lights_judgment,if=stealthed.rogue
-- actions.cds+=/symbols_of_death
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
-- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all
-- actions.cds+=/shuriken_tornado,if=spell_targets>=3&dot.nightblade.ticking&buff.symbols_of_death.up&buff.shadow_dance.up
-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=5+talent.subterfuge.enabled

-- # Stealth Cooldowns
-- # Helper Variable
-- actions.stealth_cds=variable,name=capping_shd,value=cooldown.shadow_dance.charges_fractional>=1.725+0.725*talent.enveloping_shadows.enabled
-- # Vanish unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/vanish,if=!variable.capping_shd&debuff.find_weakness.remains<1
-- # Pool for Shadowmeld + Shadowstrike unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.capping_shd&debuff.find_weakness.remains<1
-- # With Dark Shadow only Dance when Nightblade will stay up. If not capping on charges, use during Symbols or if Symbols is at least 12 seconds away.
-- actions.stealth_cds+=/shadow_dance,if=(!talent.dark_shadow.enabled|dot.nightblade.remains>=5+talent.subterfuge.enabled)&(variable.capping_shd|buff.symbols_of_death.remains>=1.2cooldown.symbols_of_death.remains>=12)
-- actions.stealth_cds+=/shadow_dance,if=target.time_to_die<cooldown.symbols_of_death.remains

-- # Stealthed Rotation
-- # If stealth is up, we really want to use Shadowstrike to benefits from the passive bonus, even if we are at max cp (from the precombat MfD).
-- actions.stealthed=shadowstrike,if=buff.stealth.up
-- # Finish at 4+ CP without DS, 5+ with DS, and 6 with DS after Vanish
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&buff.vanish.up)
-- actions.stealthed+=/shuriken_storm,if=spell_targets.shuriken_storm>=3
-- actions.stealthed+=/shadowstrike

-- # Finishers
-- # Keep up Nightblade if it is about to run out. Do not use NB during Dance, if talented into Dark Shadow.
-- actions.finish=nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&remains<tick_time*2&(spell_targets.shuriken_storm<4!buff.symbols_of_death.up)
-- # NB Cycling seems to be not worth it, but is performing somewhat equally. Commented out the old line for now.
-- #actions.finish+=/nightblade,cycle_targets=1,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>12&remains<tick_time*2&(spell_targets.shuriken_storm<4|-- !buff.symbols_of_death.up)
-- # Refresh Nightblade early if it will expire during Symbols. Do that refresh if SoD gets ready in the next 5s.
-- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5+(combo_points=6)&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
-- actions.finish+=/eviscerate

-- # Builders
-- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2
-- actions.build+=/shuriken_toss,if=buff.sharpened_blades.stack>=19
-- actions.build+=/gloomblade
-- actions.build+=/backstab

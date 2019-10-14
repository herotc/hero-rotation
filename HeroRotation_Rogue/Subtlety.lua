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
local MultiSpell = HL.MultiSpell;
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
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  Shadowmeld                            = Spell(58984),
  -- Abilities
  Backstab                              = Spell(53),
  Eviscerate                            = Spell(196819),
  Nightblade                            = Spell(195452),
  ShadowBlades                          = Spell(121471),
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
  Perforate                             = Spell(277673),
  ReplicatingShadows                    = Spell(286121),
  TheFirstDance                         = Spell(278681),
  -- Essences
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  BloodoftheEnemyDebuff                 = Spell(297108),
  RecklessForceBuff                     = Spell(302932),
  RecklessForceCounter                  = Spell(302917),
  LifebloodBuff                         = Spell(295137),
  ConcentratedFlameBurn                 = Spell(295368),
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
  ConductiveInkDebuff                   = Spell(302565),
  VigorTrinketBuff                      = Spell(287916),
  RazorCoralDebuff                      = Spell(303568),
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
        0.176 *
        -- Eviscerate R2 Multiplier
        1.5 *
        -- Aura Multiplier (SpellID: 137035)
        1.21 *
        -- Nightstalker Multiplier
        (S.Nightstalker:IsAvailable() and Player:IsStealthedP(true) and 1.12 or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Dark Shadow Multiplier
        (S.DarkShadow:IsAvailable() and Player:BuffP(S.ShadowDanceBuff) and 1.25 or 1) *
        -- Symbols of Death Multiplier
        (Player:BuffP(S.SymbolsofDeath) and 1.15 or 1) *
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
  -- Trinkets
  GalecallersBoon       = Item(159614, {13, 14}),
  InvocationOfYulon     = Item(165568, {13, 14}),
  LustrousGoldenPlumage = Item(159617, {13, 14}),
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
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

  -- actions.finish=eviscerate,if=buff.nights_vengeance.up
  if S.Eviscerate:IsCastable() and IsInMeleeRange() and Player:BuffP(S.NightsVengeanceBuff) then
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
    -- actions.finish+=/nightblade,cycle_targets=1,if=!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&(azerite.nights_vengeance.enabled|!azerite.replicating_shadows.enabled|spell_targets.shuriken_storm-active_dot.nightblade>=2)&!buff.shadow_dance.up&target.time_to_die>=(5+(2*combo_points))&refreshable
    if HR.AoEON() and not UsePriorityRotation() and Cache.EnemiesCount[10] >= 2 and not ShadowDanceBuff then
      local BestUnit, BestUnitTTD = nil, 5 + 2 * Player:ComboPoints();
      local NBCount = 0;
      for _, Unit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemainsP(S.Nightblade))
          and Everyone.CanDoTUnit(Unit, S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset)
          and Unit:DebuffRefreshableP(S.Nightblade, NightbladeThreshold) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
        if Unit:DebuffP(S.Nightblade) then
          NBCount = NBCount + 1;
        end
      end
      if BestUnit and (S.NightsVengeancePower:AzeriteEnabled() or not S.ReplicatingShadows:AzeriteEnabled() or (Cache.EnemiesCount[10] - NBCount) >= 2) then
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
  -- actions.finish+=/secret_technique
  if S.SecretTechnique:IsCastable() then
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
  local VanishBuffCheck = Player:Buff(VanishBuff) or (StealthSpell and StealthSpell:ID() == S.Vanish:ID())
  -- actions.stealthed=shadowstrike,if=(talent.find_weakness.enabled|spell_targets.shuriken_storm<3)&(buff.stealth.up|buff.vanish.up)
  if S.Shadowstrike:IsCastable() and (Target:IsInRange(S.Shadowstrike) or IsInMeleeRange())
    and (S.FindWeakness:IsAvailable() or Cache.EnemiesCount[10] < 3) and (StealthBuff or VanishBuffCheck) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 1"; end
    end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
  -- DONE IN DEFAULT PART!
  -- actions.stealthed+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
  if Cache.EnemiesCount[10] == 4 and Player:ComboPoints() >= 4 then
    return Finish(ReturnSpellOnly, StealthSpell);
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&(buff.vanish.up|azerite.the_first_dance.enabled&!talent.dark_shadow.enabled&!talent.subterfuge.enabled&spell_targets.shuriken_storm<3))
  if Player:ComboPointsDeficit() <= 1 - num(S.DeeperStratagem:IsAvailable() and (VanishBuffCheck or S.TheFirstDance:AzeriteEnabled() and not S.DarkShadow:IsAvailable() and not S.Subterfuge:IsAvailable() and Cache.EnemiesCount[10] < 3)) then
    return Finish(ReturnSpellOnly, StealthSpell);
  end
  -- actions.stealthed+=/gloomblade,if=azerite.perforate.rank>=2&spell_targets.shuriken_storm<=2
  if S.Gloomblade:IsCastableP() and S.Perforate:AzeriteRank() >= 2 and Cache.EnemiesCount[10] <= 2 then
    if ReturnSpellOnly then
      return S.Gloomblade
    else
      if HR.Cast(S.Gloomblade) then return "Cast Gloomblade (Perforate)"; end
    end
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

-- # Essences
local function Essences ()
  -- blood_of_the_enemy,if=cooldown.symbols_of_death.up|target.time_to_die<=10
  if S.BloodoftheEnemy:IsCastableP() and (S.SymbolsofDeath:CooldownUpP() or Target:FilteredTimeToDie("<=", 10)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast BloodoftheEnemy"; end
  end
  -- concentrated_flame,if=energy.time_to_max>1&!buff.symbols_of_death.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
  if S.ConcentratedFlame:IsCastableP() and Player:EnergyTimeToMaxPredicted() > 1 and not Player:BuffP(S.SymbolsofDeath) and (not Target:DebuffP(S.ConcentratedFlameBurn) and not Player:PrevGCD(1, S.ConcentratedFlame) or S.ConcentratedFlame:FullRechargeTime() < Player:GCD() + Player:GCDRemains()) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast ConcentratedFlame"; end
  end
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastableP() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast GuardianofAzeroth"; end
  end
  -- actions.essences+=/focused_azerite_beam,if=(spell_targets.shuriken_storm>=2|raid_event.adds.in>60)&!cooldown.symbols_of_death.up&!buff.symbols_of_death.up&energy.deficit>=30
  if S.FocusedAzeriteBeam:IsCastableP() and not S.SymbolsofDeath:CooldownUpP() and not Player:BuffP(S.SymbolsofDeath) and Player:EnergyDeficitPredicted() >= 30 then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast FocusedAzeriteBeam"; end
  end
  -- purifying_blast
  if S.PurifyingBlast:IsCastableP() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast PurifyingBlast"; end
  end
  -- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
  if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffStackP(S.RecklessForceCounter) < 10) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast TheUnboundForce"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastableP() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast RippleInSpace"; end
  end
  -- worldvein_resonance,if=buff.lifeblood.stack<3
  if S.WorldveinResonance:IsCastableP() and Player:BuffStackP(S.LifebloodBuff) < 3 then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast WorldveinResonance"; end
  end
  -- memory_of_lucid_dreams,if=energy<40&buff.symbols_of_death.up
  if S.MemoryofLucidDreams:IsCastableP() and Player:EnergyPredicted() < 40 and Player:BuffP(S.SymbolsofDeath) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast MemoryofLucidDreams"; end
  end
  return false;
end

-- # Cooldowns
local function CDs ()
  if IsInMeleeRange() then
    if Player:Buff(S.ShurikenTornado) then
      -- actions.cds+=/shadow_dance,off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
      if S.SymbolsofDeath:IsCastable() and S.ShadowDance:IsCastable() and not Player:Buff(S.SymbolsofDeath) and not Player:Buff(S.ShadowDance) then
        if HR.CastQueue(S.SymbolsofDeath, S.ShadowDance) then return "Dance + Symbols (during Tornado)"; end
      elseif S.SymbolsofDeath:IsCastable() and not Player:Buff(S.SymbolsofDeath) then
        if HR.Cast(S.SymbolsofDeath) then return "Cast Symbols of Death (during Tornado)"; end
      elseif S.ShadowDance:IsCastable() and not Player:Buff(S.ShadowDanceBuff) then
        if HR.Cast(S.ShadowDance) then return "Cast Shadow Dance (during Tornado)"; end
      end
    end
    -- actions.cds+=/call_action_list,name=essences,if=!stealthed.all&dot.nightblade.ticking
    if not Player:IsStealthedP(true, true) and Target:DebuffP(S.Nightblade) then
      ShouldReturn = Essences();
      if ShouldReturn then return ShouldReturn; end
    end
    -- actions.cds+=/shuriken_tornado,if=energy>=60&dot.nightblade.ticking&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1
    if S.ShurikenTornado:IsCastableP() and Target:DebuffP(S.Nightblade) and S.SymbolsofDeath:CooldownUpP() and S.ShadowDance:Charges() >= 1 then
      -- actions.cds+=/pool_resource,for_next=1,if=!talent.shadow_focus.enabled
      if Player:Energy() >= 60 then
        if HR.Cast(S.ShurikenTornado) then return "Cast Shuriken Tornado"; end
      elseif not S.ShadowFocus:IsAvailable() then
        if HR.Cast(S.PoolEnergy) then return "Pool for Shuriken Tornado"; end
      end
    end
    -- actions.cds+=/symbols_of_death,if=dot.nightblade.ticking&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|cooldown.shuriken_tornado.remains>2)&(!essence.blood_of_the_enemy.major|cooldown.blood_of_the_enemy.remains>2)&(azerite.nights_vengeance.rank<2|buff.nights_vengeance.up)
    if S.SymbolsofDeath:IsCastable() and Target:DebuffP(S.Nightblade)
      and (not S.ShurikenTornado:IsAvailable() or S.ShadowFocus:IsAvailable() or S.ShurikenTornado:CooldownRemainsP() > 2)
      and (not S.BloodoftheEnemy:IsAvailable() or S.BloodoftheEnemy:CooldownRemainsP() > 2)
      and (S.NightsVengeancePower:AzeriteRank() < 2 or Player:BuffP(S.NightsVengeanceBuff)) then
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
      -- actions.cds+=/shuriken_tornado,if=talent.shadow_focus.enabled&dot.nightblade.ticking&buff.symbols_of_death.up
      if S.ShurikenTornado:IsCastableP() and S.ShadowFocus:IsAvailable() and Target:DebuffP(S.Nightblade) and Player:BuffP(S.SymbolsofDeath) then
        if HR.Cast(S.ShurikenTornado) then return "Cast Shuriken Tornado (SF)"; end
      end
      -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=5+talent.subterfuge.enabled
      if S.ShadowDance:IsCastable() and MayBurnShadowDance() and not Player:BuffP(S.ShadowDanceBuff) and Target:FilteredTimeToDie("<=", 5 + num(S.Subterfuge:IsAvailable())) then
        if StealthMacro(S.ShadowDance) then return "Shadow Dance Macro"; end
      end

      -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
      -- TODO: Add Potion Suggestion

      -- Racials
      if Player:IsStealthedP(true, false) then
        -- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
        if S.BloodFury:IsCastable() and Player:BuffP(S.SymbolsofDeath) then
          if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
        end
        -- actions.cds+=/berserking,if=buff.symbols_of_death.up
        if S.Berserking:IsCastable() and Player:BuffP(S.SymbolsofDeath) then
          if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
        end
        -- actions.cds+=/fireblood,if=buff.symbols_of_death.up
        if S.Fireblood:IsCastable() and Player:BuffP(S.SymbolsofDeath) then
          if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood"; end
        end
        -- actions.cds+=/ancestral_call,if=buff.symbols_of_death.up
        if S.AncestralCall:IsCastable() and Player:BuffP(S.SymbolsofDeath) then
          if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call"; end
        end
      end

      -- Trinkets
      -- actions.cds+=/use_items,if=buff.symbols_of_death.up|target.time_to_die<20
      if Settings.Commons.UseTrinkets then
        local DefaultTrinketCondition = Player:BuffP(S.SymbolsofDeath) or Target:FilteredTimeToDie("<", 20);
        if I.GalecallersBoon:IsEquipped() and I.GalecallersBoon:IsReady() and DefaultTrinketCondition then
          if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast GalecallersBoon"; end
        end
        if I.LustrousGoldenPlumage:IsEquipped() and I.LustrousGoldenPlumage:IsReady() and DefaultTrinketCondition then
          if HR.Cast(I.LustrousGoldenPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast LustrousGoldenPlumage"; end
        end
        if I.InvocationOfYulon:IsEquipped() and I.InvocationOfYulon:IsReady() and DefaultTrinketCondition then
          if HR.Cast(I.InvocationOfYulon, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast InvocationOfYulon"; end
        end
        -- actions.cds+=/use_item,name=azsharas_font_of_power,if=!buff.shadow_dance.up&cooldown.symbols_of_death.remains<10
        if I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() and not Player:BuffP(S.SymbolsofDeath) and S.SymbolsofDeath:CooldownRemainsP() < 10 then
          if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast FontOfPower"; end
        end
        -- if=!stealthed.all&dot.nightblade.ticking&!buff.symbols_of_death.up&energy.deficit>=30
        if I.ComputationDevice:IsEquipped() and I.ComputationDevice:IsReady() and not Player:IsStealthedP(true, true)
          and Target:DebuffP(S.Nightblade) and not Player:BuffP(S.SymbolsofDeath) and Player:EnergyDeficitPredicted() >= 30 then
          if HR.Cast(I.ComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast ComputationDevice"; end
        end
        -- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<32&target.health.pct>=30|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=25-10*debuff.blood_of_the_enemy.up|target.time_to_die<40)&buff.symbols_of_death.remains>8
        if I.RazorCoral:IsEquipped() and I.RazorCoral:IsReady() then
          local CastRazorCoral;
          if S.RazorCoralDebuff:ActiveCount() == 0 then
            CastRazorCoral = true;
          else
            local ConductiveInkUnit = S.ConductiveInkDebuff:MaxDebuffStackPUnit()
            if ConductiveInkUnit then
              -- Cast if we are at 31%, if the enemy will die within 20s, or if the time to reach 30% will happen within 3s
              CastRazorCoral = ConductiveInkUnit:HealthPercentage() <= 32 or (Target:IsInBossList() and Target:FilteredTimeToDie("<", 20)) or
                (ConductiveInkUnit:HealthPercentage() <= 35 and ConductiveInkUnit:TimeToX(30) < 3);
            else
              CastRazorCoral = (S.RazorCoralDebuff:MaxDebuffStackP() >= 25 - 10 * num(Target:DebuffP(S.BloodoftheEnemyDebuff)) or Target:FilteredTimeToDie("<", 40))
                and Player:BuffRemainsP(S.SymbolsofDeath) > 8 or (Target:IsInBossList() and Target:FilteredTimeToDie("<", 20));
            end
          end
          if CastRazorCoral then
            if HR.Cast(I.RazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast RazorCoral"; end
          end
        end
        -- Emulate SimC default behavior to use at max stacks
        if I.VigorTrinket:IsEquipped() and I.VigorTrinket:IsReady() and Player:BuffStack(S.VigorTrinketBuff) == 6 then
          if HR.Cast(I.VigorTrinket, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast VigorTrinket"; end
        end
      end
    end
  end
  return false;
end

-- # Stealth Cooldowns
local function Stealth_CDs ()
  if IsInMeleeRange() then
    -- actions.stealth_cds+=/vanish,if=!variable.shd_threshold&combo_points.deficit>1&debuff.find_weakness.remains<1&cooldown.symbols_of_death.remains>=3
    if HR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and not ShD_Threshold() and Player:ComboPointsDeficit() > 1 and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 and S.SymbolsofDeath:CooldownRemainsP() >= 3 then
      if StealthMacro(S.Vanish) then return "Vanish Macro"; end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&combo_points.deficit>1&debuff.find_weakness.remains<1
    if HR.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and GetUnitSpeed("player") == 0 and Player:EnergyDeficitPredicted() > 10
      and not ShD_Threshold() and Player:ComboPointsDeficit() > 1 and Target:DebuffRemainsP(S.FindWeaknessDebuff) < 1 then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
      if Player:Energy() < 40 then
        if HR.Cast(S.PoolEnergy) then return "Pool for Shadowmeld"; end
      end
      if StealthMacro(S.Shadowmeld) then return "Shadowmeld Macro"; end
    end
    -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=4
    local ShdComboPoints = Player:ComboPointsDeficit() >= 4;
    -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1+2*azerite.the_first_dance.enabled,if=variable.use_priority_rotation&(talent.nightstalker.enabled|talent.dark_shadow.enabled)
    if UsePriorityRotation() and (S.Nightstalker:IsAvailable() or S.DarkShadow:IsAvailable()) then
      ShdComboPoints = Player:ComboPointsDeficit() <= 1 + 2 * num(S.TheFirstDance:AzeriteEnabled());
    end
    -- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&(!talent.dark_shadow.enabled|dot.nightblade.remains>=5+talent.subterfuge.enabled)&(variable.shd_threshold|buff.symbols_of_death.remains>=1.2|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)&(azerite.nights_vengeance.rank<2|buff.nights_vengeance.up)
    if (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and ShdComboPoints
      and (not S.DarkShadow:IsAvailable() or Target:DebuffRemainsP(S.Nightblade) >= 5 + num(S.Subterfuge:IsAvailable()))
      and (ShD_Threshold() or Player:BuffRemainsP(S.SymbolsofDeath) >= 1.2 or (Cache.EnemiesCount[10] >= 4 and S.SymbolsofDeath:CooldownRemainsP() > 10))
      and (S.NightsVengeancePower:AzeriteRank() < 2 or Player:BuffP(S.NightsVengeanceBuff)) then
      if StealthMacro(S.ShadowDance) then return "ShadowDance Macro 1"; end
    end
    -- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&target.time_to_die<cooldown.symbols_of_death.remains&!raid_event.adds.up
    if (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (S.DarkShadow:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and MayBurnShadowDance() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and ShdComboPoints and Target:TimeToDie() < S.SymbolsofDeath:CooldownRemainsP() then
      if StealthMacro(S.ShadowDance) then return "ShadowDance Macro 2"; end
    end
  end
  return false;
end

-- # Builders
local function Build ()
  -- actions.build=shuriken_storm,if=spell_targets>=2+(talent.gloomblade.enabled&azerite.perforate.rank>=2)|buff.the_dreadlords_deceit.stack>=29
  if HR.AoEON() and S.ShurikenStorm:IsCastableP() and (Cache.EnemiesCount[10] >= 2 + num(S.Gloomblade:IsAvailable() and S.Perforate:AzeriteRank() >= 2) or Player:BuffStackP(S.TheDreadlordsDeceit) >= 29) then
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
          -- actions.precombat+=/use_item,name=azsharas_font_of_power
          if Settings.Commons.UseTrinkets and I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() then
            if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Font of Power"; end
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
      -- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
      if Player:Buff(S.ShurikenTornado) and (Player:ComboPointsDeficit() - Cache.EnemiesCount[10] - num(Player:BuffP(S.ShadowBlades))) <= 1 + num(Player:IsStealthedP(true, false)) then
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

      -- # Consider using a Stealth CD when reaching the energy threshold
      -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
      if Player:EnergyDeficit() <= Stealth_Threshold() then
        local ShouldReturn = Stealth_CDs();
        if ShouldReturn then return "Stealth CDs: " .. ShouldReturn; end
      end

      -- if=azerite.nights_vengeance.enabled&!buff.nights_vengeance.up&combo_points.deficit>1&(spell_targets.shuriken_storm<2|variable.use_priority_rotation)&(cooldown.symbols_of_death.remains<=3|(azerite.nights_vengeance.rank>=2&buff.symbols_of_death.remains>3&!stealthed.all&cooldown.shadow_dance.charges_fractional>=0.9))
      if S.Nightblade:IsCastableP() and IsInMeleeRange()
        and S.NightsVengeancePower:AzeriteEnabled() and not Player:BuffP(S.NightsVengeanceBuff) and Player:ComboPoints() >= 1 and Player:ComboPointsDeficit() > 1
        and (Cache.EnemiesCount[10] < 2 or UsePriorityRotation())
        and (S.SymbolsofDeath:CooldownRemainsP() <= 3 or (S.NightsVengeancePower:AzeriteRank() >= 2 and Player:BuffRemainsP(S.SymbolsofDeath) > 3 and not Player:IsStealthedP(true, true) and S.ShadowDance:ChargesFractional() >= 0.9))
         then
        if HR.Cast(S.Nightblade) then return "Cast Nightblade (Nights Vengeance)"; end
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

local function Init ()
  S.RazorCoralDebuff:RegisterAuraTracking();
  S.ConductiveInkDebuff:RegisterAuraTracking();
end

HR.SetAPL(261, APL, Init);

-- Last Update: 2019-09-12

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
-- actions.precombat+=/use_item,name=azsharas_font_of_power
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
-- # Consider using a Stealth CD when reaching the energy threshold
-- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
-- # Night's Vengeance: Nightblade before Symbols at low CP to combine early refresh with getting the buff up. Also low CP during Symbols between Dances with 2+ NV.
-- actions+=/nightblade,if=azerite.nights_vengeance.enabled&!buff.nights_vengeance.up&combo_points.deficit>1&(spell_targets.shuriken_storm<2|variable.use_priority_rotation)&(cooldown.symbols_of_death.remains<=3|(azerite.nights_vengeance.rank>=2&buff.symbols_of_death.remains>3&!stealthed.all&cooldown.shadow_dance.charges_fractional>=0.9))
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
-- # Use Dance off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds=shadow_dance,use_off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- # (Unless already up because we took Shadow Focus) use Symbols off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds+=/symbols_of_death,use_off_gcd=1,if=buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- actions.cds+=/call_action_list,name=essences,if=!stealthed.all&dot.nightblade.ticking
-- # Pool for Tornado pre-SoD with ShD ready when not running SF.
-- actions.cds+=/pool_resource,for_next=1,if=!talent.shadow_focus.enabled
-- # Use Tornado pre SoD when we have the energy whether from pooling without SF or just generally.
-- actions.cds+=/shuriken_tornado,if=energy>=60&dot.nightblade.ticking&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1
-- # Use Symbols on cooldown (after first Nightblade) unless we are going to pop Tornado and do not have Shadow Focus.
-- actions.cds+=/symbols_of_death,if=dot.nightblade.ticking&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|cooldown.shuriken_tornado.remains>2)&(!essence.blood_of_the_enemy.major|cooldown.blood_of_the_enemy.remains>2)&(azerite.nights_vengeance.rank<2|buff.nights_vengeance.up)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or not stealthed without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.all&combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD on boss without any CP and no stealth.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.all&combo_points.deficit>=cp_max_spend
-- actions.cds+=/shadow_blades,if=combo_points.deficit>=2+stealthed.all
-- # With SF, if not already done, use Tornado with SoD up.
-- actions.cds+=/shuriken_tornado,if=talent.shadow_focus.enabled&dot.nightblade.ticking&buff.symbols_of_death.up
-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&target.time_to_die<=5+talent.subterfuge.enabled&!raid_event.adds.up
--
-- actions.cds+=/potion,if=buff.bloodlust.react|buff.symbols_of_death.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=10)
-- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
-- actions.cds+=/berserking,if=buff.symbols_of_death.up
-- actions.cds+=/fireblood,if=buff.symbols_of_death.up
-- actions.cds+=/ancestral_call,if=buff.symbols_of_death.up
--
-- actions.cds+=/use_item,effect_name=cyclotronic_blast,if=!stealthed.all&dot.nightblade.ticking&!buff.symbols_of_death.up&energy.deficit>=30
-- actions.cds+=/use_item,name=azsharas_font_of_power,if=!buff.shadow_dance.up&cooldown.symbols_of_death.remains<10
-- # Very roughly rule of thumbified maths below: Use for Inkpod crit, otherwise with SoD at 25+ stacks or 15+ with also Blood up.
-- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<32&target.health.pct>=30|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=25-10*debuff.blood_of_the_enemy.up|target.time_to_die<40)&buff.symbols_of_death.remains>8
-- actions.cds+=/use_item,name=mydas_talisman
-- # Default fallback for usable items: Use with Symbols of Death.
-- actions.cds+=/use_items,if=buff.symbols_of_death.up|target.time_to_die<20
--
-- # Essences
-- actions.essences=concentrated_flame,if=energy.time_to_max>1&!buff.symbols_of_death.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
-- actions.essences+=/blood_of_the_enemy,if=cooldown.symbols_of_death.up|target.time_to_die<=10
-- actions.essences+=/guardian_of_azeroth
-- actions.essences+=/focused_azerite_beam,if=(spell_targets.shuriken_storm>=2|raid_event.adds.in>60)&!cooldown.symbols_of_death.up&!buff.symbols_of_death.up&energy.deficit>=30
-- actions.essences+=/purifying_blast,if=spell_targets.shuriken_storm>=2|raid_event.adds.in>60
-- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
-- actions.essences+=/ripple_in_space
-- actions.essences+=/worldvein_resonance,if=buff.lifeblood.stack<3
-- actions.essences+=/memory_of_lucid_dreams,if=energy<40&buff.symbols_of_death.up
--
-- # Stealth Cooldowns
-- # Helper Variable
-- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=1.75
-- # Vanish unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/vanish,if=!variable.shd_threshold&combo_points.deficit>1&debuff.find_weakness.remains<1&cooldown.symbols_of_death.remains>=3
-- # Pool for Shadowmeld + Shadowstrike unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&combo_points.deficit>1&debuff.find_weakness.remains<1
-- # CP requirement: Dance at low CP by default.
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=4
-- # CP requirement: Dance only before finishers if we have amp talents and priority rotation.
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1+2*azerite.the_first_dance.enabled,if=variable.use_priority_rotation&(talent.nightstalker.enabled|talent.dark_shadow.enabled)
-- # With Dark Shadow only Dance when Nightblade will stay up. Use during Symbols or above threshold. Wait for NV buff with 2+NV.
-- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&(!talent.dark_shadow.enabled|dot.nightblade.remains>=5+talent.subterfuge.enabled)&(variable.shd_threshold|buff.symbols_of_death.remains>=1.2|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)&(azerite.nights_vengeance.rank<2|buff.nights_vengeance.up)
-- # Burn remaining Dances before the target dies if SoD won't be ready in time.
-- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&target.time_to_die<cooldown.symbols_of_death.remains&!raid_event.adds.up
--
-- # Stealthed Rotation
-- # If Stealth/vanish are up, use Shadowstrike to benefit from the passive bonus and Find Weakness, even if we are at max CP (from the precombat MfD).
-- actions.stealthed=shadowstrike,if=(talent.find_weakness.enabled|spell_targets.shuriken_storm<3)&(buff.stealth.up|buff.vanish.up)
-- # Finish at 3+ CP without DS / 4+ with DS with Shuriken Tornado buff up to avoid some CP waste situations.
-- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
-- # Also safe to finish at 4+ CP with exactly 4 targets. (Same as outside stealth.)
-- actions.stealthed+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
-- # Finish at 4+ CP without DS, 5+ with DS, and 6 with DS after Vanish or The First Dance and no Dark Shadow + no Subterfuge
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&(buff.vanish.up|azerite.the_first_dance.enabled&!talent.dark_shadow.enabled&!talent.subterfuge.enabled&spell_targets.shuriken_storm<3))
-- # Use Gloomblade over Shadowstrike and Storm with 2+ Perforate at 2 or less targets.
-- actions.stealthed+=/gloomblade,if=azerite.perforate.rank>=2&spell_targets.shuriken_storm<=2&position_back
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
-- actions.finish=pool_resource,for_next=1
-- # Eviscerate has highest priority with Night's Vengeance up.
-- actions.finish+=/eviscerate,if=buff.nights_vengeance.up
-- # Keep up Nightblade if it is about to run out. Do not use NB during Dance, if talented into Dark Shadow.
-- actions.finish+=/nightblade,if=(!talent.dark_shadow.enabled|!buff.shadow_dance.up)&target.time_to_die-remains>6&remains<tick_time*2
-- # Multidotting outside Dance on targets that will live for the duration of Nightblade, refresh during pandemic. Multidot as long as 2+ targets do not have Nightblade up with Replicating Shadows (unless you have Night's Vengeance too).
-- actions.finish+=/nightblade,cycle_targets=1,if=!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&(azerite.nights_vengeance.enabled|!azerite.replicating_shadows.enabled|spell_targets.shuriken_storm-active_dot.nightblade>=2)&!buff.shadow_dance.up&target.time_to_die>=(5+(2*combo_points))&refreshable
-- # Refresh Nightblade early if it will expire during Symbols. Do that refresh if SoD gets ready in the next 5s.
-- actions.finish+=/nightblade,if=remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
-- actions.finish+=/secret_technique
-- actions.finish+=/eviscerate
--
-- # Builders
-- actions.build=shuriken_storm,if=spell_targets>=2+(talent.gloomblade.enabled&azerite.perforate.rank>=2&position_back)
-- actions.build+=/gloomblade
-- actions.build+=/backstab

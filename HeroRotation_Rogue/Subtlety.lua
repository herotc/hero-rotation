--- Localize Vars
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua
local pairs = pairs
local tableinsert = table.insert


--- APL Local Vars
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue
-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
-- Define S/I for spell and item arrays
local S = Spell.Rogue.Subtlety
local I = Item.Rogue.Subtlety

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.ComputationDevice:ID(),
  I.VigorTrinket:ID(),
  I.FontOfPower:ID(),
  I.RazorCoral:ID()
}

S.Eviscerate:RegisterDamageFormula(
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
        -- Aura Multiplier (SpellID: 137035)
        1.21 *
        -- Nightstalker Multiplier
        (S.Nightstalker:IsAvailable() and Player:StealthUp(true) and 1.12 or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Shadow Dance Multiplier
        (S.DarkShadow:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and 1.3 or 1) *
        (not S.DarkShadow:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and 1.15 or 1) *
        -- Symbols of Death Multiplier
        (Player:BuffUp(S.SymbolsofDeath) and 1.15 or 1) *
        -- Mastery Finisher Multiplier
        (1 + Player:MasteryPct() / 100) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct() / 100) *
      --- Target Modifier
        -- Eviscerate R2 Multiplier
        (Target:DebuffUp(S.FindWeaknessDebuff) and 1.5 or 1)
  end
)
S.Rupture:RegisterPMultiplier(
  function ()
    return S.Nightstalker:IsAvailable() and Player:StealthUp(true, false) and 1.12 or 1
  end
)

-- Rotation Var
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y
local ShouldReturn; -- Used to get the return string
local PoolingAbility, PoolingEnergy; -- Used to store an ability we might want to pool for as a fallback in the current situation
local Stealth, VanishBuff
local RuptureThreshold, RuptureDMGThreshold
local ComboPoints, ComboPointsDeficit
local PriorityRotation
-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Subtlety = HR.GUISettings.APL.Rogue.Subtlety
}

local function SetPoolingAbility(PoolingSpell, EnergyThreshold)
  if not PoolingAbility then
    PoolingAbility = PoolingSpell
    PoolingEnergy = EnergyThreshold or 0
  end
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
  if MeleeEnemies10yCount < 2 then
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
local function Stealth_Threshold ()
  -- actions+=/variable,name=stealth_threshold,value=25+talent.vigor.enabled*20+talent.master_of_shadows.enabled*20+talent.shadow_focus.enabled*25+talent.alacrity.enabled*20+25*(spell_targets.shuriken_storm>=4)
  return 25 + num(S.Vigor:IsAvailable()) * 20 + num(S.MasterofShadows:IsAvailable()) * 20 + num(S.ShadowFocus:IsAvailable()) * 25 + num(S.Alacrity:IsAvailable()) * 20 + num(MeleeEnemies10yCount >= 4) * 25
end
local function ShD_Threshold ()
  -- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=1.75
  return S.ShadowDance:ChargesFractional() >= 1.75
end
local function SnD_Condition ()
  -- actions+=/variable,name=snd_condition,value=buff.slice_and_dice.up|spell_targets.shuriken_storm>=6
  return Player:BuffUp(S.SliceandDice) or MeleeEnemies10yCount >= 6
end
local function Skip_Rupture (ShadowDanceBuff)
  -- actions.finish+=/variable,name=skip_rupture,value=master_assassin_remains>0|!talent.nightstalker.enabled&talent.dark_shadow.enabled&buff.shadow_dance.up|spell_targets.shuriken_storm>=6
  return Rogue.MasterAssassinsMarkRemains() > 0
    or not S.Nightstalker:IsAvailable() and S.DarkShadow:IsAvailable() and ShadowDanceBuff
    or MeleeEnemies10yCount >= 6
end

-- # Finishers
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Finish (ReturnSpellOnly, StealthSpell)
  local ShadowDanceBuff = Player:BuffUp(S.ShadowDanceBuff) or (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID())

  -- actions.finish=slice_and_dice,if=spell_targets.shuriken_storm<6&!buff.shadow_dance.up&buff.slice_and_dice.remains<fight_remains&buff.slice_and_dice.remains<(1+combo_points)*1.8
  if S.SliceandDice:IsReady() and Target:IsInMeleeRange(5)
    and MeleeEnemies10yCount < 6 and not ShadowDanceBuff
    and HL.FilteredFightRemains(MeleeEnemies5y, ">", Player:BuffRemains(S.SliceandDice))
    and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints * 1.8) then
    if ReturnSpellOnly then
      return S.SliceandDice
    else
      if HR.Cast(S.SliceandDice) then return "Cast Slice and Dice" end
    end
  end

  local SkipRupture = Skip_Rupture(ShadowDanceBuff)
  if S.Rupture:IsReady() and not SkipRupture then
    -- actions.finish+=/rupture,if=!variable.skip_rupture&target.time_to_die-remains>6&refreshable
    if Target:IsInMeleeRange(5)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.Rupture)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold)
      and Target:DebuffRefreshable(S.Rupture, RuptureThreshold) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if HR.Cast(S.Rupture) then return "Cast Rupture 1" end
      end
    end
  end
  -- actions.finish+=/secret_technique
  if S.SecretTechnique:IsReady() then
    if ReturnSpellOnly then
      return S.SecretTechnique
    else
      if HR.Cast(S.SecretTechnique) then return "Cast Secret Technique" end
    end
  end
  if S.Rupture:IsReady() and not SkipRupture then
    -- actions.finish+=/rupture,cycle_targets=1,if=!variable.skip_rupture&!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&target.time_to_die>=(5+(2*combo_points))&refreshable
    if HR.AoEON() and not PriorityRotation and MeleeEnemies10yCount >= 2 then
      local BestUnit, BestUnitTTD = nil, 5 + 2 * ComboPoints
      for _, CycleUnit in pairs(MeleeEnemies5y) do
        if Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(S.Rupture))
          and Everyone.CanDoTUnit(CycleUnit, RuptureDMGThreshold)
          and CycleUnit:DebuffRefreshable(S.Rupture, RuptureThreshold) then
          BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
        end
      end
      if BestUnit then
        HR.CastLeftNameplate(BestUnit, S.Rupture)
      end
    end
    -- actions.finish+=/rupture,if=!variable.skip_rupture&remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
    if Target:IsInMeleeRange(5) and Target:DebuffRemains(S.Rupture) < S.SymbolsofDeath:CooldownRemains() + 10
      and S.SymbolsofDeath:CooldownRemains() <= 5
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold)
      and (Target:FilteredTimeToDie(">", 5 + S.SymbolsofDeath:CooldownRemains(), -Target:DebuffRemains(S.Rupture)) or Target:TimeToDieIsNotValid()) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if HR.Cast(S.Rupture) then return "Cast Rupture 2" end
      end
    end
  end
  -- actions.finish+=/shadow_vault,if=!variable.use_priority_rotation&spell_targets>=3
  if S.ShadowVault:IsReady() and MeleeEnemies10yCount >= 3 then
    if ReturnSpellOnly then
      return S.ShadowVault
    else
      if HR.CastPooling(S.ShadowVault) then return "Cast Shadow Vault" end
    end
  end
  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and Target:IsInMeleeRange(5) then
    if ReturnSpellOnly then
      return S.Eviscerate
    else
      if HR.CastPooling(S.Eviscerate) then return "Cast Eviscerate" end
    end
  end
  return false
end

-- # Stealthed Rotation
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Stealthed (ReturnSpellOnly, StealthSpell)
  local PredictedCP = ComboPoints
  if S.TheFirstDance:AzeriteEnabled() and (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID()) then
    PredictedCP = math.min(PredictedCP + 2, Rogue.CPMaxSpend())
  end
  local PredictedCPDeficit = Player:ComboPointsMax() - PredictedCP
  local StealthBuff = Player:BuffUp(Stealth) or (StealthSpell and StealthSpell:ID() == Stealth:ID())
  local VanishBuffCheck = Player:BuffUp(VanishBuff) or (StealthSpell and StealthSpell:ID() == S.Vanish:ID())
  local ShadowDanceBuff = Player:BuffUp(S.ShadowDanceBuff) or (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID())
  local ShadowstrikeIsCastable = S.Shadowstrike:IsCastable() and (StealthBuff or VanishBuffCheck or ShadowDanceBuff)

  -- actions.stealthed+=/shadowstrike,if=(buff.stealth.up|buff.vanish.up)
  if ShadowstrikeIsCastable and (Target:IsSpellInRange(S.Shadowstrike) or Target:IsInMeleeRange(5))
    and (StealthBuff or VanishBuffCheck) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 1" end
    end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
  -- DONE IN DEFAULT PART!
  -- actions.stealthed+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
  if MeleeEnemies10yCount == 4 and PredictedCP >= 4 then
    return Finish(ReturnSpellOnly, StealthSpell)
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&buff.vanish.up)
  if PredictedCPDeficit <= 1 - num(S.DeeperStratagem:IsAvailable() and VanishBuffCheck) then
    return Finish(ReturnSpellOnly, StealthSpell)
  end

  -- TODO: actions.stealthed+=/shiv,if=talent.nightstalker.enabled&runeforge.tiny_toxic_blade.equipped

  -- actions.stealthed+=/shadowstrike,if=level<52&debuff.find_weakness.remains<1&target.time_to_die-remains>6
  if ShadowstrikeIsCastable and Player:Level() < 52 and Target:DebuffRemains(S.FindWeaknessDebuff) < 1 and Target:FilteredTimeToDie(">", 6) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (FW Refresh)" end
    end
  end

  -- !!!NYI!!! (Is this worth it? How do we want to display it in an understandable way?)
  -- actions.stealthed+=/shadowstrike,cycle_targets=1,if=debuff.find_weakness.remains<1&spell_targets.shuriken_storm<=3&target.time_to_die-remains>6

  -- actions.stealthed+=/shadowstrike,if=!talent.deeper_stratagem.enabled&azerite.blade_in_the_shadows.rank=3&spell_targets.shuriken_storm=3
  if ShadowstrikeIsCastable and not S.DeeperStratagem:IsAvailable() and S.BladeInTheShadows:AzeriteRank() == 3 and MeleeEnemies10yCount == 3 then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (3T BitS)" end
    end
  end
  -- actions.stealthed+=/shadowstrike,if=variable.use_priority_rotation&(debuff.find_weakness.remains<1|talent.weaponmaster.enabled&spell_targets.shuriken_storm<=5|azerite.inevitability.enabled&buff.symbols_of_death.up&spell_targets.shuriken_storm<=3+azerite.blade_in_the_shadows.enabled)
  if ShadowstrikeIsCastable and PriorityRotation
    and (Target:DebuffRemains(S.FindWeaknessDebuff) < 1 or S.Weaponmaster:IsAvailable() and MeleeEnemies10yCount <= 5
      or S.Inevitability:AzeriteEnabled() and Player:BuffUp(S.SymbolsofDeath) and MeleeEnemies10yCount <= 3 + num(S.BladeInTheShadows:AzeriteEnabled())) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (Prio Rotation)" end
    end
  end
  -- actions.stealthed+=/shuriken_storm,if=spell_targets>=3+(buff.premeditation.up|buff.the_rotten.up|runeforge.akaaris_soul_fragment.equipped&conduit.deeper_daggers.rank>=7)
  -- TODO: lego and conduit
  if HR.AoEON() and S.ShurikenStorm:IsCastable() and MeleeEnemies10yCount >= 3 + num(Player:BuffUp(S.PremeditationBuff) or Player:BuffUp(S.TheRottenBuff)) then
    if ReturnSpellOnly then
      return S.ShurikenStorm
    else
      if HR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm" end
    end
  end

  -- TODO: actions.stealthed+=/gloomblade,if=!runeforge.akaaris_soul_fragment.equipped&buff.perforated_veins.stack>=3&conduit.perforated_veins.rank>=13-(9*conduit.deeper_dagger.enabled+conduit.deeper_dagger.rank)
  -- TODO: actions.stealthed+=/gloomblade,if=runeforge.akaaris_soul_fragment.equipped&buff.perforated_veins.stack>=3&(conduit.perforated_veins.rank+conduit.deeper_dagger.rank)>=16

  -- actions.stealthed+=/shadowstrike
  if ShadowstrikeIsCastable and (Target:IsSpellInRange(S.Shadowstrike) or Target:IsInMeleeRange(5)) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 2" end
    end
  end
  return false
end

-- # Stealth Macros
-- This returns a table with the original Stealth spell and the result of the Stealthed action list as if the applicable buff was present
local function StealthMacro (StealthSpell, EnergyThreshold)
  local MacroTable = {StealthSpell}

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if StealthSpell == S.Vanish and not Settings.Subtlety.StealthMacro.Vanish then
    if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish" end
    return false
  elseif StealthSpell == S.Shadowmeld and not Settings.Subtlety.StealthMacro.Shadowmeld then
    if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
    return false
  elseif StealthSpell == S.ShadowDance and not Settings.Subtlety.StealthMacro.ShadowDance then
    if HR.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
    return false
  end

  tableinsert(MacroTable, Stealthed(true, StealthSpell))

  -- Set the stealth spell only as a pooling fallback if we did not meet the threshold
  if EnergyThreshold and Player:EnergyPredicted() < EnergyThreshold then
    SetPoolingAbility(MacroTable, EnergyThreshold)
    return false
  end

   -- Note: In case DfA is adviced (which can only be a combo for ShD), we swap them to let understand it's DfA then ShD during DfA (DfA - ShD bug)
  if MacroTable[1] == S.ShadowDance and MacroTable[2] == S.DeathfromAbove then
    return HR.CastQueue(MacroTable[2], MacroTable[1])
  else
    return HR.CastQueue(unpack(MacroTable))
  end
end

-- # Essences
local function Essences ()
  -- blood_of_the_enemy,if=!cooldown.shadow_blades.up&cooldown.symbols_of_death.up|fight_remains<=10
  if S.BloodoftheEnemy:IsCastable() and (not S.ShadowBlades:CooldownUp() and S.SymbolsofDeath:CooldownUp() or HL.BossFilteredFightRemains("<=", 10)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast BloodoftheEnemy" end
  end
  -- concentrated_flame,if=energy.time_to_max>1&!buff.symbols_of_death.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
  if S.ConcentratedFlame:IsCastable() and Player:EnergyTimeToMaxPredicted() > 1 and not Player:BuffUp(S.SymbolsofDeath) and (not Target:DebuffUp(S.ConcentratedFlameBurn) and not Player:PrevGCD(1, S.ConcentratedFlame) or S.ConcentratedFlame:FullRechargeTime() < Player:GCD() + Player:GCDRemains()) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast ConcentratedFlame" end
  end
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastable() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast GuardianofAzeroth" end
  end
  -- actions.essences+=/focused_azerite_beam,if=(spell_targets.shuriken_storm>=2|raid_event.adds.in>60)&!cooldown.symbols_of_death.up&!buff.symbols_of_death.up&energy.deficit>=30
  if S.FocusedAzeriteBeam:IsCastable() and not S.SymbolsofDeath:CooldownUp() and not Player:BuffUp(S.SymbolsofDeath) and Player:EnergyDeficitPredicted() >= 30 then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast FocusedAzeriteBeam" end
  end
  -- purifying_blast
  if S.PurifyingBlast:IsCastable() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast PurifyingBlast" end
  end
  -- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
  if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff) or Player:BuffStack(S.RecklessForceCounter) < 10) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast TheUnboundForce" end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast RippleInSpace" end
  end
  -- worldvein_resonance,if=cooldown.symbols_of_death.remains<5|fight_remains<18
  if S.WorldveinResonance:IsCastable() and (S.SymbolsofDeath:CooldownRemains() < 5 or HL.BossFilteredFightRemains("<", 18)) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast WorldveinResonance" end
  end
  -- memory_of_lucid_dreams,if=energy<40&buff.symbols_of_death.up
  if S.MemoryofLucidDreams:IsCastable() and Player:EnergyPredicted() < 40 and Player:BuffUp(S.SymbolsofDeath) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast MemoryofLucidDreams" end
  end
  -- reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30
  ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle)
  if ShouldReturn then return ShouldReturn end

  return false
end

-- # Cooldowns
local function CDs ()
  if Target:IsInMeleeRange(5) then
    if Player:BuffUp(S.ShurikenTornado) then
      -- actions.cds+=/shadow_dance,off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
      if S.SymbolsofDeath:IsCastable() and S.ShadowDance:IsCastable() and not Player:BuffUp(S.SymbolsofDeath) and not Player:BuffUp(S.ShadowDance) then
        if HR.CastQueue(S.SymbolsofDeath, S.ShadowDance) then return "Dance + Symbols (during Tornado)" end
      elseif S.SymbolsofDeath:IsCastable() and not Player:BuffUp(S.SymbolsofDeath) then
        if HR.Cast(S.SymbolsofDeath) then return "Cast Symbols of Death (during Tornado)" end
      elseif S.ShadowDance:IsCastable() and not Player:BuffUp(S.ShadowDanceBuff) then
        if HR.Cast(S.ShadowDance) then return "Cast Shadow Dance (during Tornado)" end
      end
    end
    -- Quick and dirty Flagellation
    if S.Flagellation:IsCastable() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.Flagellation) then return "Cast Flrgrrlation" end
    end
    if S.FlagellationMastery:IsCastable() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.FlagellationMastery, Settings.Commons.OffGCDasOffGCD.FlagellationMastery) then return "Cast Flrgrrlation Mastery" end
    end
    -- TODO: actions.cds+=/flagellation,if=variable.snd_condition&!stealthed.mantle
    -- TODO: actions.cds+=/flagellation_cleanse,if=debuff.flagellation.remains<2|debuff.flagellation.stack>=40
    -- TODO: actions.cds+=/vanish,if=(runeforge.mark_of_the_master_assassin.equipped|runeforge.deathly_shadows.equipped)&buff.symbols_of_death.up&buff.shadow_dance.up&master_assassin_remains=0&buff.deathly_shadows.down&(combo_points<1|!runeforge.deathly_shadows.equipped)
    -- actions.cds+=/call_action_list,name=essences,if=!stealthed.all&variable.snd_condition|essence.breath_of_the_dying.major&time>=2
    if not Player:StealthUp(true, true) and SnD_Condition() or Spell:MajorEssenceEnabled(AE.BreathoftheDying) and HL.CombatTime() >= 2 then
      ShouldReturn = Essences()
      if ShouldReturn then return ShouldReturn end
    end
    -- actions.cds+=/shuriken_tornado,if=energy>=60&variable.snd_condition&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1
    if S.ShurikenTornado:IsCastable() and SnD_Condition() and S.SymbolsofDeath:CooldownUp() and S.ShadowDance:Charges() >= 1 then
      -- actions.cds+=/pool_resource,for_next=1,if=!talent.shadow_focus.enabled
      if Player:Energy() >= 60 then
        if HR.Cast(S.ShurikenTornado) then return "Cast Shuriken Tornado" end
      elseif not S.ShadowFocus:IsAvailable() then
        if HR.CastPooling(S.ShurikenTornado) then return "Pool for Shuriken Tornado" end
      end
    end
    -- actions.cds+=/serrated_bone_spike,cycle_targets=1,if=variable.snd_condition&!dot.serrated_bone_spike_dot.ticking|fight_remains<=5
    if HR.AoEON() and S.SerratedBoneSpike:IsCastable() and (SnD_Condition() or HL.BossFilteredFightRemains("<=", 5)) then
      local BestUnit, BestUnitTTD = nil, 30
      for _, CycleUnit in pairs(Enemies30y) do -- Shoule we increase range here to match spike range? Not sure about false positives.
        local TTD = CycleUnit:TimeToDie()
        if not CycleUnit:DebuffUp(S.SerratedBoneSpikeDot) and (not BestUnit or TTD < BestUnitTTD) then
          BestUnit, BestUnitTTD = CycleUnit, TTD
        end
      end
      if BestUnit and BestUnit:GUID() ~= Target:GUID() then
        HR.CastLeftNameplate(BestUnit, S.SerratedBoneSpike)
      elseif BestUnit then
        if HR.CastPooling(S.SerratedBoneSpike) then return "Cast Serrated Bone Spike" end
      end
    end
    -- actions.cds+=/symbols_of_death,if=variable.snd_condition&!cooldown.shadow_blades.up&(talent.enveloping_shadows.enabled|cooldown.shadow_dance.charges>=1)&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|cooldown.shuriken_tornado.remains>2)&(!essence.blood_of_the_enemy.major|cooldown.blood_of_the_enemy.remains>2)
    if S.SymbolsofDeath:IsCastable() and SnD_Condition() and (not S.ShadowBlades:CooldownUp() or not HR.CDsON())
      and (S.EnvelopingShadows:IsAvailable() or S.ShadowDance:Charges() >= 1)
      and (not S.ShurikenTornado:IsAvailable() or S.ShadowFocus:IsAvailable() or S.ShurikenTornado:CooldownRemains() > 2)
      and (not Spell:MajorEssenceEnabled(AE.BloodoftheEnemy) or S.BloodoftheEnemy:CooldownRemains() > 2) then
      if HR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death" end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
    if S.MarkedforDeath:IsCastable() and Target:FilteredTimeToDie("<", ComboPointsDeficit) then
      if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
    end
    -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
    -- Note: Without Settings.Subtlety.STMfDAsDPSCD
    if not Settings.Subtlety.STMfDAsDPSCD and S.MarkedforDeath:IsCastable() and not Player:StealthUp(true, true) and ComboPointsDeficit >= Rogue.CPMaxSpend() then
      HR.CastSuggested(S.MarkedforDeath)
    end
    if HR.CDsON() then
      -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
      -- Note: With Settings.Subtlety.STMfDAsDPSCD
      if Settings.Subtlety.STMfDAsDPSCD and S.MarkedforDeath:IsCastable() and not Player:StealthUp(true, true) and ComboPointsDeficit >= Rogue.CPMaxSpend() then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      end
      -- actions.cds+=/shadow_blades,if=!stealthed.all&variable.snd_condition&combo_points.deficit>=2
      if S.ShadowBlades:IsCastable() and not Player:BuffUp(S.ShadowBlades)
        and not Player:StealthUp(true, true) and SnD_Condition() and ComboPointsDeficit >= 2 then
        if HR.Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return "Cast Shadow Blades" end
      end
      -- actions.cds+=/echoing_reprimand,if=variable.snd_condition&combo_points.deficit>=3&spell_targets.shuriken_storm<=4
      if S.EchoingReprimand:IsCastable() and SnD_Condition() and ComboPointsDeficit >= 3 and MeleeEnemies10yCount <= 4 then
        if HR.Cast(S.EchoingReprimand) then return "Cast Echoing Reprimand" end
      end
      -- actions.cds+=/shuriken_tornado,if=talent.shadow_focus.enabled&variable.snd_condition&buff.symbols_of_death.up
      if S.ShurikenTornado:IsCastable() and S.ShadowFocus:IsAvailable() and SnD_Condition() and Player:BuffUp(S.SymbolsofDeath) then
        if HR.Cast(S.ShurikenTornado) then return "Cast Shuriken Tornado (SF)" end
      end
      -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&fight_remains<=8+talent.subterfuge.enabled
      if S.ShadowDance:IsCastable() and MayBurnShadowDance() and not Player:BuffUp(S.ShadowDanceBuff) and HL.BossFilteredFightRemains("<=", 8 + num(S.Subterfuge:IsAvailable())) then
        if StealthMacro(S.ShadowDance) then return "Shadow Dance Macro" end
      end

      -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|(buff.vanish.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=30))
      -- TODO: Add Potion Suggestion

      -- Racials
      if Player:StealthUp(true, false) then
        -- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
        if S.BloodFury:IsCastable() and Player:BuffUp(S.SymbolsofDeath) then
          if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
        end
        -- actions.cds+=/berserking,if=buff.symbols_of_death.up
        if S.Berserking:IsCastable() and Player:BuffUp(S.SymbolsofDeath) then
          if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
        end
        -- actions.cds+=/fireblood,if=buff.symbols_of_death.up
        if S.Fireblood:IsCastable() and Player:BuffUp(S.SymbolsofDeath) then
          if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
        end
        -- actions.cds+=/ancestral_call,if=buff.symbols_of_death.up
        if S.AncestralCall:IsCastable() and Player:BuffUp(S.SymbolsofDeath) then
          if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
        end
      end

      -- Trinkets
      if Settings.Commons.UseTrinkets then
        local DefaultTrinketCondition = Player:BuffUp(S.SymbolsofDeath) or HL.BossFilteredFightRemains("<", 20)
        -- actions.cds+=/use_item,name=azsharas_font_of_power,if=!buff.shadow_dance.up&cooldown.symbols_of_death.remains<10
        if I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() and not Player:BuffUp(S.SymbolsofDeath) and S.SymbolsofDeath:CooldownRemains() < 10 then
          if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast FontOfPower" end
        end
        -- if=!stealthed.all&variable.snd_condition&!buff.symbols_of_death.up&energy.deficit>=30
        if I.ComputationDevice:IsEquipped() and I.ComputationDevice:IsReady() and not Player:StealthUp(true, true)
          and SnD_Condition() and not Player:BuffUp(S.SymbolsofDeath) and Player:EnergyDeficitPredicted() >= 30 then
          if HR.Cast(I.ComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast ComputationDevice" end
        end
        -- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<32&target.health.pct>=30|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=25-10*debuff.blood_of_the_enemy.up|target.time_to_die<40)&buff.symbols_of_death.remains>8
        if I.RazorCoral:IsEquipped() and I.RazorCoral:IsReady() then
          local CastRazorCoral
          if S.RazorCoralDebuff:AuraActiveCount() == 0 then
            CastRazorCoral = true
          else
            local ConductiveInkUnit = S.ConductiveInkDebuff:MaxDebuffStackUnit()
            if ConductiveInkUnit then
              -- Cast if we are at 31%, if the enemy will die within 20s, or if the time to reach 30% will happen within 3s
              CastRazorCoral = ConductiveInkUnit:HealthPercentage() <= 32 or (Target:IsInBossList() and Target:FilteredTimeToDie("<", 20)) or
                (ConductiveInkUnit:HealthPercentage() <= 35 and ConductiveInkUnit:TimeToX(30) < 3)
            else
              CastRazorCoral = (S.RazorCoralDebuff:MaxDebuffStack() >= 25 - 10 * num(Target:DebuffUp(S.BloodoftheEnemyDebuff)) or Target:FilteredTimeToDie("<", 40))
                and Player:BuffRemains(S.SymbolsofDeath) > 8 or (Target:IsInBossList() and Target:FilteredTimeToDie("<", 20))
            end
          end
          if CastRazorCoral then
            if HR.Cast(I.RazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast RazorCoral" end
          end
        end
        -- Emulate SimC default behavior to use at max stacks
        if I.VigorTrinket:IsEquipped() and I.VigorTrinket:IsReady() and Player:BuffStack(S.VigorTrinketBuff) == 6 then
          if HR.Cast(I.VigorTrinket, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast VigorTrinket" end
        end
        -- actions.cds+=/use_items,if=buff.symbols_of_death.up|fight_remains<20
        if DefaultTrinketCondition then
          local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
          if TrinketToUse then
            if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
          end
        end
      end
    end
  end
  return false
end

-- # Stealth Cooldowns
local function Stealth_CDs (EnergyThreshold)
  if Target:IsInMeleeRange(5) then
    -- actions.stealth_cds+=/vanish,if=!variable.shd_threshold&combo_points.deficit>1
    -- actions.stealth_cds+=/vanish,if=(!variable.shd_threshold|!talent.nightstalker.enabled&talent.dark_shadow.enabled)&combo_points.deficit>1&!runeforge.mark_of_the_master_assassin.equipped
    -- TODO: MA item check
    if HR.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and (not ShD_Threshold() or not S.Nightstalker:IsAvailable() and S.DarkShadow:IsAvailable()) and ComboPointsDeficit > 1 then
      if StealthMacro(S.Vanish, EnergyThreshold) then return "Vanish Macro" end
    end
    -- actions.stealth_cds+=/sepsis
    if HR.CDsON() and S.Sepsis:IsCastable() and not Player:IsTanking(Target) then
      if HR.Cast(S.Sepsis) then return "Cast Sepsis" end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&combo_points.deficit>1&debuff.find_weakness.remains<1
    if HR.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target)
      and not Player:IsMoving() and Player:EnergyDeficitPredicted() > 10
      and not ShD_Threshold() and ComboPointsDeficit > 1 and Target:DebuffRemains(S.FindWeaknessDebuff) < 1 then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
      if Player:Energy() < 40 then
        if HR.CastPooling(S.Shadowmeld, Player:EnergyTimeToX(40)) then return "Pool for Shadowmeld" end
      end
      if StealthMacro(S.Shadowmeld, EnergyThreshold) then return "Shadowmeld Macro" end
    end
    -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=4
    local ShdComboPoints = ComboPointsDeficit >= 4
    -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1,if=variable.use_priority_rotation
    if PriorityRotation then
      ShdComboPoints = ComboPointsDeficit <= 1
    end
    -- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&(variable.shd_threshold|buff.symbols_of_death.remains>=1.2|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)
    if (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (not S.EnvelopingShadows:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and ShdComboPoints
      and (ShD_Threshold() or Player:BuffRemains(S.SymbolsofDeath) >= 1.2 or (MeleeEnemies10yCount >= 4 and S.SymbolsofDeath:CooldownRemains() > 10)) then
      if StealthMacro(S.ShadowDance, EnergyThreshold) then return "ShadowDance Macro 1" end
    end
    -- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&fight_remains<cooldown.symbols_of_death.remains
    if (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (not S.EnvelopingShadows:IsAvailable() and 0.75 or 0)))
      and S.ShadowDance:IsCastable() and MayBurnShadowDance() and S.Vanish:TimeSinceLastDisplay() > 0.3
      and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 1
      and ShdComboPoints and HL.BossFilteredFightRemains("<", S.SymbolsofDeath:CooldownRemains()) then
      if StealthMacro(S.ShadowDance, EnergyThreshold) then return "ShadowDance Macro 2" end
    end
  end
  return false
end

-- # Builders
local function Build (EnergyThreshold)
  local ThresholdMet = not EnergyThreshold or Player:EnergyPredicted() >= EnergyThreshold
  -- TODO: actions.build=shiv,if=!talent.nightstalker.enabled&runeforge.tiny_toxic_blade.equipped

  -- actions.build=shuriken_storm,if=spell_targets>=2+(talent.gloomblade.enabled&azerite.perforate.rank>=2&position_back)
  -- Note: missing back check
  if HR.AoEON() and S.ShurikenStorm:IsCastable() and (MeleeEnemies10yCount >= 2 + num(S.Gloomblade:IsAvailable() and S.Perforate:AzeriteRank() >= 2)) then
    if ThresholdMet and HR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm" end
    SetPoolingAbility(S.ShurikenStorm, EnergyThreshold)
  end
  -- actions.build+=/serrated_bone_spike,if=cooldown.serrated_bone_spike.charges_fractional>=2.75
  if S.SerratedBoneSpike:IsCastable() and S.SerratedBoneSpike:ChargesFractional() >= 2.75 then
    if ThresholdMet and HR.Cast(S.SerratedBoneSpike) then return "Cast Serrated Bone Spike (Capping Filler)" end
    SetPoolingAbility(S.SerratedBoneSpike, EnergyThreshold)
  end
  if Target:IsInMeleeRange(5) then
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if ThresholdMet and HR.Cast(S.Gloomblade) then return "Cast Gloomblade" end
      SetPoolingAbility(S.Gloomblade, EnergyThreshold)
    -- actions.build+=/backstab
    elseif S.Backstab:IsCastable() then
      if ThresholdMet and HR.Cast(S.Backstab) then return "Cast Backstab" end
      SetPoolingAbility(S.Backstab, EnergyThreshold)
    end
  end
  return false
end

local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return ComboPoints > 0 end},
  {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:StealthUp(true, true) end}
}

-- APL Main
local function APL ()
  -- Spell ID Changes check
  if S.Subterfuge:IsAvailable() then
    Stealth = S.Stealth2
    VanishBuff = S.VanishBuff2
  else
    Stealth = S.Stealth
    VanishBuff = S.VanishBuff
  end

  -- Reset pooling cache
  PoolingAbility = nil
  PoolingEnergy = 0

  -- Unit Update
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Serrated Bone Spike
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10) -- Shuriken Storm & Shadow Vault
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(5) -- Melee cycle
  else
    MeleeEnemies10yCount = 1
  end

  -- Cache updates
  ComboPoints = Player:ComboPoints()
  ComboPointsDeficit = Player:ComboPointsDeficit()
  RuptureThreshold = (4 + ComboPoints * 4) * 0.3
  RuptureDMGThreshold = S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.
  PriorityRotation = UsePriorityRotation()

  --- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial (S.CrimsonVial)
  if ShouldReturn then return ShouldReturn end
  -- Feint
  ShouldReturn = Rogue.Feint (S.Feint)
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  local PoisonRefreshTime = Player:AffectingCombat() and Settings.Subtlety.PoisonRefreshCombat*60 or Settings.Subtlety.PoisonRefresh*60
  -- Lethal Poison
  if Player:BuffRemains(S.InstantPoison) <= PoisonRefreshTime then
    HR.CastSuggested(S.InstantPoison)
  end
  -- Non-Lethal Poisons
  if (Player:BuffUp(S.CripplingPoison) and Player:BuffRemains(S.CripplingPoison) <= PoisonRefreshTime)
    or (Player:BuffUp(S.NumbingPoison) and Player:BuffRemains(S.NumbingPoison) <= PoisonRefreshTime) then
    if Player:BuffUp(S.NumbingPoison) then
      HR.CastSuggested(S.NumbingPoison)
    else
      HR.CastSuggested(S.CripplingPoison)
    end
  end

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    -- Note: Since 7.2.5, Blizzard disallowed Stealth cast under ShD (workaround to prevent the Extended Stealth bug)
    if not Player:BuffUp(S.ShadowDanceBuff) and not Player:BuffUp(VanishBuff) then
      ShouldReturn = Rogue.Stealth(Stealth)
      if ShouldReturn then return ShouldReturn end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and (Target:IsSpellInRange(S.Shadowstrike) or Target:IsInMeleeRange(5)) then
      -- Precombat CDs
      if HR.CDsON() then
        if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
        -- actions.precombat+=/use_item,name=azsharas_font_of_power
        if Settings.Commons.UseTrinkets and I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() then
          if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Font of Power" end
        end
      end
      if Player:StealthUp(true, true) then
        PoolingAbility = Stealthed(true)
        if PoolingAbility then -- To avoid pooling icon spam
          if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
            if HR.CastQueuePooling(nil, unpack(PoolingAbility)) then return "Stealthed Macro Cast or Pool (OOC): ".. PoolingAbility[1]:Name() end
          else
            if HR.CastPooling(PoolingAbility) then return "Stealthed Cast or Pool (OOC): "..PoolingAbility:Name() end
          end
        end
      elseif Player:ComboPoints() >= 5 then
        ShouldReturn = Finish()
        if ShouldReturn then return ShouldReturn .. " (OOC)" end
      elseif S.Backstab:IsCastable() then
        if HR.Cast(S.Backstab) then return "Cast Backstab (OOC)" end
      end
    end
    return
  end

  -- In Combat
  -- MfD Sniping
  Rogue.MfDSniping(S.MarkedforDeath)
  Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle)

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- # Check CDs at first
    -- actions=call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end

    -- SPECIAL HACK FOR SHURIKEN TORNADO
    -- Show a finisher if we can assume we will have enough CP with the next global
    -- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
    if Player:BuffUp(S.ShurikenTornado) and (Player:ComboPointsDeficit() - MeleeEnemies10yCount - num(Player:BuffUp(S.ShadowBlades))) <= 1 + num(Player:StealthUp(true, false)) then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish (during Tornado): " .. ShouldReturn end
    end

    -- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
    -- actions+=/run_action_list,name=stealthed,if=stealthed.all
    if Player:StealthUp(true, true) then
      PoolingAbility = Stealthed(true)
      if PoolingAbility then -- To avoid pooling icon spam
        if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
          if HR.CastQueuePooling(nil, unpack(PoolingAbility)) then return "Macro Cast or Pool: ".. PoolingAbility[1]:Name() end
        else
          if HR.CastPooling(PoolingAbility) then return "Cast "..PoolingAbility:Name() end
        end
      else
        return "Stealthed Pooling"
      end
    end

    -- # Apply Slice and Dice at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
    -- actions+=/slice_and_dice,if=target.time_to_die>6&buff.slice_and_dice.remains<gcd.max&combo_points>=4-(time<10)*2
    if S.SliceandDice:IsCastable() and Target:IsInMeleeRange(5)
      and (Target:FilteredTimeToDie(">", 6) or Target:TimeToDieIsNotValid())
      and Player:BuffRemains(S.SliceandDice) < Player:GCD() and Player:ComboPoints() >= 4 - (HL.CombatTime() < 10 and 2 or 0) then
      if HR.Cast(S.SliceandDice) then return "Cast Slice and Dice (Low Duration)" end
    end

    -- actions+=/call_action_list,name=stealth_cds,if=variable.use_priority_rotation
    if PriorityRotation then
      ShouldReturn = Stealth_CDs()
      if ShouldReturn then return "Stealth CDs: (Priority Rotation)" .. ShouldReturn end
    end

    -- # Consider using a Stealth CD when reaching the energy threshold, called with params to register potential pooling
    -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
    ShouldReturn = Stealth_CDs(Player:EnergyMax() - Stealth_Threshold())
    if ShouldReturn then return "Stealth CDs: " .. ShouldReturn end

    -- TODO: actions+=/call_action_list,name=finish,if=runeforge.deathly_shadows.equipped&dot.sepsis.ticking&dot.sepsis.remains<=2&combo_points>=2
    -- TODO: actions+=/call_action_list,name=finish,if=combo_points=animacharged_cp

    -- # Finish at 4+ without DS, 5+ with DS (outside stealth)
    -- actions+=/call_action_list,name=finish,if=combo_points.deficit<=1|fight_remains<=1&combo_points>=3
    if Player:ComboPointsDeficit() <= 1 or (HL.BossFilteredFightRemains("<=", 1) and Player:ComboPoints() >= 3) then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: " .. ShouldReturn end
    end

    -- actions+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
    if MeleeEnemies10yCount == 4 and Player:ComboPoints() >= 4 then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish 4T: " .. ShouldReturn end
    end

    -- # Use a builder when reaching the energy threshold
    -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
    ShouldReturn = Build(Player:EnergyMax() - Stealth_Threshold())
    if ShouldReturn then return "Build: " .. ShouldReturn end

    -- # Lowest priority in all of the APL because it causes a GCD
    -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
    if S.ArcaneTorrent:IsCastable() and Target:IsInMeleeRange(5) and Player:EnergyDeficitPredicted() > 15 + Player:EnergyRegen() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse" end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
    end
    -- actions+=/bag_of_tricks
    if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
    end

    -- Shuriken Toss Out of Range
    if S.ShurikenToss:IsCastable() and Target:IsInRange(30) and not Target:IsInRange(10) and not Player:StealthUp(true, true) and not Player:BuffUp(S.Sprint)
      and Player:EnergyDeficitPredicted() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
      if HR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss" end
    end
    -- Show what ever was first stored for pooling
    if PoolingAbility and Target:IsInMeleeRange(5) then
      if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
        if HR.CastQueuePooling(Player:EnergyTimeToX(PoolingEnergy), unpack(PoolingAbility)) then return "Macro pool towards ".. PoolingAbility[1]:Name() .. " at " .. PoolingEnergy end
      elseif PoolingAbility:IsCastable() then
        if HR.CastPooling(PoolingAbility, Player:EnergyTimeToX(PoolingEnergy)) then return "Pool towards: " .. PoolingAbility:Name() .. " at " .. PoolingEnergy end
      end
    end
  end
end

local function Init ()
  S.RazorCoralDebuff:RegisterAuraTracking()
  S.ConductiveInkDebuff:RegisterAuraTracking()
end

HR.SetAPL(261, APL, Init)

-- Last Update: 2020-10-18
-- PRELIMINARY for Shadowlands Prepatch and basic Covenants
-- TODO: Conduits and Legendaries

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/stealth
-- actions.precombat+=/marked_for_death,precombat_seconds=15
-- actions.precombat+=/slice_and_dice,precombat_seconds=1
-- actions.precombat+=/shadow_blades,if=runeforge.mark_of_the_master_assassin.equipped
-- actions.precombat+=/use_item,name=azsharas_font_of_power
--
-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Used to determine whether cooldowns wait for SnD based on targets.
-- actions+=/variable,name=snd_condition,value=buff.slice_and_dice.up|spell_targets.shuriken_storm>=6
-- # Check CDs at first
-- actions+=/call_action_list,name=cds
-- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- # Apply Slice and Dice at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
-- actions+=/slice_and_dice,if=spell_targets.shuriken_storm<6&fight_remains>6&buff.slice_and_dice.remains<gcd.max&combo_points>=4-(time<10)*2
-- # Only change rotation if we have priority_rotation set and multiple targets up.
-- actions+=/variable,name=use_priority_rotation,value=priority_rotation&spell_targets.shuriken_storm>=2
-- # Priority Rotation? Let's give a crap about energy for the stealth CDs (builder still respect it). Yup, it can be that simple.
-- actions+=/call_action_list,name=stealth_cds,if=variable.use_priority_rotation
-- # Used to define when to use stealth CDs or builders
-- actions+=/variable,name=stealth_threshold,value=25+talent.vigor.enabled*20+talent.master_of_shadows.enabled*20+talent.shadow_focus.enabled*25+talent.alacrity.enabled*20+25*(spell_targets.shuriken_storm>=4)
-- # Consider using a Stealth CD when reaching the energy threshold
-- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
-- actions+=/call_action_list,name=finish,if=runeforge.deathly_shadows.equipped&dot.sepsis.ticking&dot.sepsis.remains<=2&combo_points>=2
-- actions+=/call_action_list,name=finish,if=combo_points=animacharged_cp
-- # Finish at 4+ without DS, 5+ with DS (outside stealth)
-- actions+=/call_action_list,name=finish,if=combo_points.deficit<=1|fight_remains<=1&combo_points>=3
-- # With DS also finish at 4+ against exactly 4 targets (outside stealth)
-- actions+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
-- # Use a builder when reaching the energy threshold
-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
-- # Lowest priority in all of the APL because it causes a GCD
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks
--
-- # Builders
-- actions.build=shiv,if=!talent.nightstalker.enabled&runeforge.tiny_toxic_blade.equipped
-- actions.build+=/shuriken_storm,if=spell_targets>=2+(talent.gloomblade.enabled&azerite.perforate.rank>=2&position_back)
-- actions.build+=/serrated_bone_spike,if=cooldown.serrated_bone_spike.charges_fractional>=2.75
-- actions.build+=/gloomblade
-- actions.build+=/backstab
--
-- # Cooldowns
-- # Use Dance off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds=shadow_dance,use_off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- # (Unless already up because we took Shadow Focus) use Symbols off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds+=/symbols_of_death,use_off_gcd=1,if=buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- actions.cds+=/flagellation,if=variable.snd_condition&!stealthed.mantle
-- actions.cds+=/flagellation_cleanse,if=debuff.flagellation.remains<2|debuff.flagellation.stack>=40
-- actions.cds+=/vanish,if=(runeforge.mark_of_the_master_assassin.equipped&combo_points.deficit<=3|runeforge.deathly_shadows.equipped&combo_points<1)&buff.symbols_of_death.up&buff.shadow_dance.up&master_assassin_remains=0&buff.deathly_shadows.down
-- actions.cds+=/call_action_list,name=essences,if=!stealthed.all&variable.snd_condition|essence.breath_of_the_dying.major&time>=2
-- # Pool for Tornado pre-SoD with ShD ready when not running SF.
-- actions.cds+=/pool_resource,for_next=1,if=!talent.shadow_focus.enabled
-- # Use Tornado pre SoD when we have the energy whether from pooling without SF or just generally.
-- actions.cds+=/shuriken_tornado,if=energy>=60&variable.snd_condition&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1
-- actions.cds+=/serrated_bone_spike,cycle_targets=1,if=variable.snd_condition&!dot.serrated_bone_spike_dot.ticking|fight_remains<=5
-- # Use Symbols on cooldown (after first SnD) unless we are going to pop Tornado and do not have Shadow Focus.
-- actions.cds+=/symbols_of_death,if=variable.snd_condition&!cooldown.shadow_blades.up&(talent.enveloping_shadows.enabled|cooldown.shadow_dance.charges>=1)&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|cooldown.shuriken_tornado.remains>2)&(!essence.blood_of_the_enemy.major|cooldown.blood_of_the_enemy.remains>2)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or not stealthed without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.all&combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
-- actions.cds+=/shadow_blades,if=variable.snd_condition&combo_points.deficit>=2
-- actions.cds+=/echoing_reprimand,if=variable.snd_condition&combo_points.deficit>=3&spell_targets.shuriken_storm<=4
-- # With SF, if not already done, use Tornado with SoD up.
-- actions.cds+=/shuriken_tornado,if=talent.shadow_focus.enabled&variable.snd_condition&buff.symbols_of_death.up
-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&fight_remains<=8+talent.subterfuge.enabled
-- actions.cds+=/potion,if=buff.bloodlust.react|buff.symbols_of_death.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=10)
-- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
-- actions.cds+=/berserking,if=buff.symbols_of_death.up
-- actions.cds+=/fireblood,if=buff.symbols_of_death.up
-- actions.cds+=/ancestral_call,if=buff.symbols_of_death.up
-- actions.cds+=/use_item,effect_name=cyclotronic_blast,if=!stealthed.all&variable.snd_condition&!buff.symbols_of_death.up&energy.deficit>=30
-- actions.cds+=/use_item,name=azsharas_font_of_power,if=!buff.shadow_dance.up&cooldown.symbols_of_death.remains<10
-- # Very roughly rule of thumbified maths below: Use for Inkpod crit, otherwise with SoD at 25+ stacks or 15+ with also Blood up.
-- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<32&target.health.pct>=30|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=25-10*debuff.blood_of_the_enemy.up|fight_remains<40)&buff.symbols_of_death.remains>8
-- actions.cds+=/use_item,name=mydas_talisman
-- # Default fallback for usable items: Use with Symbols of Death.
-- actions.cds+=/use_items,if=buff.symbols_of_death.up|fight_remains<20
--
-- # Essences
-- actions.essences=concentrated_flame,if=energy.time_to_max>1&!buff.symbols_of_death.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
-- actions.essences+=/blood_of_the_enemy,if=!cooldown.shadow_blades.up&cooldown.symbols_of_death.up|fight_remains<=10
-- actions.essences+=/guardian_of_azeroth
-- actions.essences+=/focused_azerite_beam,if=(spell_targets.shuriken_storm>=2|raid_event.adds.in>60)&!cooldown.symbols_of_death.up&!buff.symbols_of_death.up&energy.deficit>=30
-- actions.essences+=/purifying_blast,if=spell_targets.shuriken_storm>=2|raid_event.adds.in>60
-- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
-- actions.essences+=/ripple_in_space
-- actions.essences+=/worldvein_resonance,if=cooldown.symbols_of_death.remains<5|fight_remains<18
-- actions.essences+=/memory_of_lucid_dreams,if=energy<40&buff.symbols_of_death.up
-- # Hold Reaping Flames for execute range or kill buffs, if possible. Always try to get the lowest cooldown based on available enemies.
-- actions.essences+=/cycling_variable,name=reaping_delay,op=min,if=essence.breath_of_the_dying.major,value=target.time_to_die
-- actions.essences+=/reaping_flames,target_if=target.time_to_die<1.5|((target.health.pct>80|target.health.pct<=20)&(active_enemies=1|variable.reaping_delay>29))|(target.time_to_pct_20>30&(active_enemies=1|variable.reaping_delay>44))
--
-- # Finishers
-- actions.finish=slice_and_dice,if=spell_targets.shuriken_storm<6&!buff.shadow_dance.up&buff.slice_and_dice.remains<fight_remains&buff.slice_and_dice.remains<(1+combo_points)*1.8
-- # Helper Variable for Rupture. Skip during Master Assassin or during Dance with Dark and no Nightstalker.
-- actions.finish+=/variable,name=skip_rupture,value=master_assassin_remains>0|!talent.nightstalker.enabled&talent.dark_shadow.enabled&buff.shadow_dance.up|spell_targets.shuriken_storm>=6
-- # Keep up Rupture if it is about to run out.
-- actions.finish+=/rupture,if=!variable.skip_rupture&target.time_to_die-remains>6&refreshable
-- actions.finish+=/secret_technique
-- # Multidotting targets that will live for the duration of Rupture, refresh during pandemic.
-- actions.finish+=/rupture,cycle_targets=1,if=!variable.skip_rupture&!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&target.time_to_die>=(5+(2*combo_points))&refreshable
-- # Refresh Rupture early if it will expire during Symbols. Do that refresh if SoD gets ready in the next 5s.
-- actions.finish+=/rupture,if=!variable.skip_rupture&remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
-- actions.finish+=/shadow_vault,if=!variable.use_priority_rotation&spell_targets>=3
-- actions.finish+=/eviscerate
--
-- # Stealth Cooldowns
-- # Helper Variable
-- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=1.75
-- # Vanish if we are capping on Dance charges. Early before first dance if we have no Nightstalker but Dark Shadow in order to get Rupture up (no Master Assassin).
-- actions.stealth_cds+=/vanish,if=(!variable.shd_threshold|!talent.nightstalker.enabled&talent.dark_shadow.enabled)&combo_points.deficit>1&!runeforge.mark_of_the_master_assassin.equipped
-- actions.stealth_cds+=/sepsis
-- # Pool for Shadowmeld + Shadowstrike unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&combo_points.deficit>1&debuff.find_weakness.remains<1
-- # CP requirement: Dance at low CP by default.
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=4
-- # CP requirement: Dance only before finishers if we have priority rotation.
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1,if=variable.use_priority_rotation
-- # Dance during Symbols or above threshold.
-- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&(variable.shd_threshold|buff.symbols_of_death.remains>=1.2|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)
-- # Burn remaining Dances before the fight ends if SoD won't be ready in time.
-- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&fight_remains<cooldown.symbols_of_death.remains
--
-- # Stealthed Rotation
-- # If Stealth/vanish are up, use Shadowstrike to benefit from the passive bonus and Find Weakness, even if we are at max CP (from the precombat MfD).
-- actions.stealthed=shadowstrike,if=(buff.stealth.up|buff.vanish.up)
-- # Finish at 3+ CP without DS / 4+ with DS with Shuriken Tornado buff up to avoid some CP waste situations.
-- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
-- # Also safe to finish at 4+ CP with exactly 4 targets. (Same as outside stealth.)
-- actions.stealthed+=/call_action_list,name=finish,if=spell_targets.shuriken_storm=4&combo_points>=4
-- # Finish at 4+ CP without DS, 5+ with DS, and 6 with DS after Vanish
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&buff.vanish.up)
-- actions.stealthed+=/shiv,if=talent.nightstalker.enabled&runeforge.tiny_toxic_blade.equipped
-- # For pre-patch, keep Find Weakness up on the primary target due to no Shadow Vault
-- actions.stealthed+=/shadowstrike,if=level<52&debuff.find_weakness.remains<1&target.time_to_die-remains>6
-- # Up to 3 targets keep up Find Weakness by cycling Shadowstrike.
-- actions.stealthed+=/shadowstrike,cycle_targets=1,if=debuff.find_weakness.remains<1&spell_targets.shuriken_storm<=3&target.time_to_die-remains>6
-- # Without Deeper Stratagem and 3 Ranks of Blade in the Shadows it is worth using Shadowstrike on 3 targets.
-- actions.stealthed+=/shadowstrike,if=!talent.deeper_stratagem.enabled&azerite.blade_in_the_shadows.rank=3&spell_targets.shuriken_storm=3
-- # For priority rotation, use Shadowstrike over Storm 1) with WM against up to 4 targets, 2) if FW is running off (on any amount of targets), or 3) to maximize SoD extension with Inevitability on 3 targets (4 with BitS).
-- actions.stealthed+=/shadowstrike,if=variable.use_priority_rotation&(debuff.find_weakness.remains<1|talent.weaponmaster.enabled&spell_targets.shuriken_storm<=4|azerite.inevitability.enabled&buff.symbols_of_death.up&spell_targets.shuriken_storm<=3+azerite.blade_in_the_shadows.enabled)
-- actions.stealthed+=/shuriken_storm,if=spell_targets>=3+(buff.premeditation.up|buff.the_rotten.up|runeforge.akaaris_soul_fragment.equipped&conduit.deeper_daggers.rank>=7)
-- # Shadowstrike to refresh Find Weakness and to ensure we can carry over a full FW into the next SoD if possible.
-- actions.stealthed+=/shadowstrike,if=debuff.find_weakness.remains<=1|cooldown.symbols_of_death.remains<18&debuff.find_weakness.remains<cooldown.symbols_of_death.remains
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/gloomblade,if=!runeforge.akaaris_soul_fragment.equipped&buff.perforated_veins.stack>=3&conduit.perforated_veins.rank>=13-(9*conduit.deeper_dagger.enabled+conduit.deeper_dagger.rank)
-- actions.stealthed+=/gloomblade,if=runeforge.akaaris_soul_fragment.equipped&buff.perforated_veins.stack>=3&(conduit.perforated_veins.rank+conduit.deeper_dagger.rank)>=16
-- actions.stealthed+=/shadowstrike

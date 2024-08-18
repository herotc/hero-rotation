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
local BoolToInt = HL.Utils.BoolToInt
local ValueIsInArray = HL.Utils.ValueIsInArray
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast = HR.Cast
local CastLeftNameplate = HR.CastLeftNameplate
local CastPooling = HR.CastPooling
local CastQueue = HR.CastQueue
local CastQueuePooling = HR.CastQueuePooling
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num
local bool = HR.Commons.Everyone.bool
-- Lua
local pairs = pairs
local tableinsert = table.insert
local mathmin = math.min
local mathmax = math.max
local mathabs = math.abs
local Delay = C_Timer.After

--- APL Local Vars
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue
-- Define S/I for spell and item arrays
local S = Spell.Rogue.Subtlety
local I = Item.Rogue.Subtlety

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.ImperfectAscendancySerum:ID(),
  I.TreacherousTransmitter:ID()
}

-- Rotation Var
local MeleeRange, AoERange, TargetInMeleeRange, TargetInAoERange
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y
local ShouldReturn; -- Used to get the return string
local PoolingAbility, PoolingEnergy, PoolingFinisher; -- Used to store an ability we might want to pool for as a fallback in the current situation
local RuptureThreshold, RuptureDMGThreshold
local EffectiveComboPoints, ComboPoints, ComboPointsDeficit, StealthEnergyRequired
local PriorityRotation

-- Trinkets
local trinket1, trinket2 = Player:GetTrinketItems()
-- If we don't have trinket items, try again in 2 seconds.
if trinket1:ID() == 0 or trinket2:ID() == 0 then
  Delay(2, function()
    trinket1, trinket2 = Player:GetTrinketItems()
  end
  )
end

HL:RegisterForEvent(function()
  trinket1, trinket2 = Player:GetTrinketItems()
end, "PLAYER_EQUIPMENT_CHANGED" )

S.Eviscerate:RegisterDamageFormula(
  -- Eviscerate DMG Formula (Pre-Mitigation):
  --- Player Modifier
    -- AP * CP * EviscR1_APCoef * Aura_M * NS_M * DS_M * DSh_M * SoD_M * Finality_M * Mastery_M * Versa_M
  --- Target Modifier
    -- EviscR2_M * Sinful_M
  function ()
    return
      --- Player Modifier
        -- Attack Power
        Player:AttackPowerDamageMod() *
        -- Combo Points
        EffectiveComboPoints *
        -- Eviscerate R1 AP Coef
        0.176 *
        -- Aura Multiplier (SpellID: 137035)
        1.21 *
        -- Nightstalker Multiplier
        (S.Nightstalker:IsAvailable() and Player:StealthUp(true, false) and 1.08 or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Shadow Dance Multiplier
        (S.DarkShadow:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and 1.3 or 1) *
        -- Symbols of Death Multiplier
        (Player:BuffUp(S.SymbolsofDeath) and 1.1 or 1) *
        -- Finality Multiplier
        (Player:BuffUp(S.FinalityEviscerateBuff) and 1.3 or 1) *
        -- Mastery Finisher Multiplier
        (1 + Player:MasteryPct() / 100) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct() / 100) *
      --- Target Modifier
        -- Eviscerate R2 Multiplier
        (Target:DebuffUp(S.FindWeaknessDebuff) and 1.5 or 1)
  end
)

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  CommonsDS = HR.GUISettings.APL.Rogue.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Rogue.CommonsOGCD,
  Subtlety = HR.GUISettings.APL.Rogue.Subtlety
}

local function SetPoolingAbility(PoolingSpell, EnergyThreshold)
  if not PoolingAbility then
    PoolingAbility = PoolingSpell
    PoolingEnergy = EnergyThreshold or 0
  end
end

local function SetPoolingFinisher(PoolingSpell)
  if not PoolingFinisher then
    PoolingFinisher = PoolingSpell
  end
end

local function MayBurnShadowDance()
  if Settings.Subtlety.BurnShadowDance == "On Bosses not in Dungeons" and Player:IsInDungeonArea() then
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
  elseif Settings.Subtlety.UsePriorityRotation == "Always" then
    return true
  elseif Settings.Subtlety.UsePriorityRotation == "On Bosses" and Target:IsInBossList() then
    return true
  elseif Settings.Subtlety.UsePriorityRotation == "Auto" then
    -- Zul Mythic
    if Player:InstanceDifficulty() == 16 and Target:NPCID() == 138967 then
      return true
    -- Council of Blood
    elseif Target:NPCID() == 166969 or Target:NPCID() == 166971 or Target:NPCID() == 166970 then
      return true
    -- Anduin (Remnant of a Fallen King/Monstrous Soul)
    elseif Target:NPCID() == 183463 or Target:NPCID() == 183671 then
      return true
    end
  end

  return false
end

-- Handle CastLeftNameplate Suggestions for DoT Spells
local function SuggestCycleDoT(DoTSpell, DoTEvaluation, DoTMinTTD, Enemies)
  -- Prefer melee cycle units
  local BestUnit, BestUnitTTD = nil, DoTMinTTD
  local TargetGUID = Target:GUID()
  for _, CycleUnit in pairs(Enemies) do
    if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(DoTSpell))
    and DoTEvaluation(CycleUnit) then
      BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
    end
  end
  if BestUnit then
    CastLeftNameplate(BestUnit, DoTSpell)
  -- Check ranged units next, if the RangedMultiDoT option is enabled
  elseif Settings.Commons.RangedMultiDoT then
    BestUnit, BestUnitTTD = nil, DoTMinTTD
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(DoTSpell))
      and DoTEvaluation(CycleUnit) then
        BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
      end
    end
    if BestUnit then
      CastLeftNameplate(BestUnit, DoTSpell)
    end
  end
end

-- APL Action Lists (and Variables)
local function Stealth_Threshold ()
  -- actions+=/ variable,name=stealth_threshold,value=20+talent.vigor.rank*25+talent.thistle_tea*20+talent.shadowcraft*20
  return 20 + S.Vigor:TalentRank() * 25 + num(S.ThistleTea:IsAvailable()) * 20 + num(S.Shadowcraft:IsAvailable()) * 20
end

local function SnD_Condition ()
  -- actions+=/variable,name=snd_condition,value=buff.slice_and_dice.up
  return Player:BuffUp(S.SliceandDice)
end

local function Skip_Rupture (ShadowDanceBuff)
  -- actions.finish+=/variable,name=skip_rupture,value=buff.thistle_tea.up&spell_targets.shuriken_storm=1
  -- |buff.shadow_dance.up&(spell_targets.shuriken_storm=1|dot.rupture.ticking&spell_targets.shuriken_storm>=2)|buff.darkest_night.up
  return Player:BuffUp(S.ThistleTea) and MeleeEnemies10yCount == 1
    or ShadowDanceBuff and (MeleeEnemies10yCount == 1 or Target:DebuffUp(S.Rupture) and MeleeEnemies10yCount >= 2)
    or Player:BuffUp(S.DarkestNightBuff)
end

local function Rupture_Before_Flag()
  -- actions.cds=variable,name=ruptures_before_flag,value=spell_targets<=4|talent.invigorating_shadowdust
  -- &!talent.follow_the_blood|(talent.replicating_shadows&(spell_targets>=5&active_dot.rupture>=spell_targets-2))
  -- |!talent.replicating_shadows
  return MeleeEnemies10yCount <= 4 or S.InvigoratingShadowdust:IsAvailable()
    and not S.FollowTheBlood:IsAvailable() or (S.ReplicatingShadows:IsAvailable() and (MeleeEnemies10yCount >= 5 and S.Rupture:AuraActiveCount() >= MeleeEnemies10yCount - 2))
    or not S.ReplicatingShadows:IsAvailable()
end

local function Used_For_Danse(Spell)
  return Player:BuffUp(S.ShadowDanceBuff) and Spell:TimeSinceLastCast() < S.ShadowDance:TimeSinceLastCast()
end

local function Secret_Condition()
  -- actions.finish=variable,name=secret_condition,value=!buff.darkest_night.up
  -- &(buff.danse_macabre.stack>=2|!talent.danse_macabre|(talent.unseen_blade&buff.shadow_dance.up&buff.escalating_blade.stack>=2))
  return Player:BuffDown(S.DarkestNightBuff) and (Player:BuffStack(S.DanseMacabreBuff) >= 2 or not S.DanseMacabre:IsAvailable()
  or (S.UnseenBlade:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and Player:BuffStack(S.EscalatingBlade) >= 2))
end

local function Trinket_Sync_Slot()
  -- actions.precombat+=/variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps
  -- &(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
  -- actions.precombat+=/variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps
  -- &(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  local TrinketSyncSlot = 0

  if trinket1:HasStatAnyDps() and (not trinket2:HasStatAnyDps() or trinket1:Cooldown() >= trinket1:Cooldown()) then
    TrinketSyncSlot = 1
  elseif trinket2:HasStatAnyDps() and (not trinket1:HasStatAnyDps() or trinket2:Cooldown() > trinket2:Cooldown()) then
    TrinketSyncSlot = 2
  end

  return TrinketSyncSlot
end

-- # Finishers
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Finish (ReturnSpellOnly, StealthSpell)
  local ShadowDanceBuff = Player:BuffUp(S.ShadowDanceBuff)
  local ShadowDanceBuffRemains = Player:BuffRemains(S.ShadowDanceBuff)
  local SymbolsofDeathBuffRemains = Player:BuffRemains(S.SymbolsofDeath)
  local FinishComboPoints = ComboPoints
  local ColdBloodCDRemains = S.ColdBlood:CooldownRemains()
  local SymbolsCDRemains = S.SymbolsofDeath:CooldownRemains()

  -- State changes based on predicted Stealth casts
  local PremeditationBuff = Player:BuffUp(S.PremeditationBuff) or (StealthSpell and S.Premeditation:IsAvailable())
  if StealthSpell and StealthSpell:ID() == S.ShadowDance:ID() then
    ShadowDanceBuff = true
    ShadowDanceBuffRemains = 8 + S.ImprovedShadowDance:TalentRank()
    if S.TheFirstDance:IsAvailable() then
      FinishComboPoints = mathmin(Player:ComboPointsMax(), ComboPoints + 4)
    end
    if Player:HasTier(30, 2) then
      SymbolsofDeathBuffRemains = mathmax(SymbolsofDeathBuffRemains, 6)
    end
  end

  if StealthSpell and StealthSpell:ID() == S.Vanish:ID() then
    ColdBloodCDRemains = mathmin(0, S.ColdBlood:CooldownRemains() - (15*S.InvigoratingShadowdust:TalentRank()))
    SymbolsCDRemains = mathmin(0, S.SymbolsofDeath:CooldownRemains() - (15*S.InvigoratingShadowdust:TalentRank()))
  end

  -- action.finish+=/rupture,if=!dot.rupture.ticking&target.time_to_die-remains>6
  -- Apply Rupture if its not up
  if S.Rupture:IsCastable() and S.Rupture:IsReady() then
    if Target:DebuffDown(S.Rupture) and Target:TimeToDie() > 6 then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if S.Rupture:IsReady() and Cast(S.Rupture) then return "Cast Rupture 1" end
        SetPoolingFinisher(S.Rupture)
      end
    end
  end

  -- actions.finish+=/rupture,if=(!variable.skip_rupture|variable.priority_rotation)&target.time_to_die-remains>6&refreshable
  if (not Skip_Rupture(ShadowDanceBuff) or PriorityRotation) and Target:TimeToDie() > 6 and Target:DebuffRefreshable(S.Rupture, RuptureThreshold) then
    if ReturnSpellOnly then
      return S.Rupture
    else
      if S.Rupture:IsReady() and Cast(S.Rupture) then return "Cast Rupture 2" end
      SetPoolingFinisher(S.Rupture)
    end
  end

  -- actions.finish+=/coup_de_grace,if=debuff.fazed.up&(buff.shadow_dance.up|(buff.symbols_of_death.up&cooldown.shadow_dance.charges_fractional<=0.85))
  if S.CoupDeGrace:IsReady() and S.CoupDeGrace:IsCastable() then
    if Target:DebuffUp(S.FazedDebuff) and (Player:BuffUp(S.ShadowDanceBuff) or Player:BuffUp(S.SymbolsofDeath)
      and S.ShadowDance:ChargesFractional() <= 0.85) then
        if ReturnSpellOnly then
          return S.CoupDeGrace
        else
          if S.CoupDeGrace:IsReady() and Cast(S.CoupDeGrace) then return "Cast Coup De Grace 1" end
          SetPoolingFinisher(S.CoupDeGrace)
        end
    end
  end

  -- actions.finish+=/cold_blood,if=variable.secret_condition&cooldown.secret_technique.ready
  if S.ColdBlood:IsReady() and Secret_Condition(ShadowDanceBuff, PremeditationBuff) and S.SecretTechnique:IsReady() then
    if Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood then
      Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood)
    else
      if ReturnSpellOnly then return S.ColdBlood end
      if Cast(S.ColdBlood) then return "Cast Cold Blood (SecTec)" end
    end
  end

  -- actions.finish+=/secret_technique,if=variable.secret_condition&(!talent.cold_blood|cooldown.cold_blood.remains>buff.shadow_dance.remains-2
  -- |!talent.improved_shadow_dance)
  -- Attention: Due to the SecTec/ColdBlood interaction, this adaption has additional checks not found in the APL string
  if S.SecretTechnique:IsReady() then
    if Secret_Condition(ShadowDanceBuff, PremeditationBuff)
      and (not S.ColdBlood:IsAvailable() or (Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood and S.ColdBlood:IsReady())
      or Player:BuffUp(S.ColdBlood) or ColdBloodCDRemains > ShadowDanceBuffRemains - 2 or not S.ImprovedShadowDance:IsAvailable()) then
      if ReturnSpellOnly then return S.SecretTechnique end
      if Cast(S.SecretTechnique) then return "Cast Secret Technique" end
    end
  end

  if not Skip_Rupture(ShadowDanceBuff) and S.Rupture:IsCastable() then
    -- actions.finish+=/rupture,cycle_targets=1,if=!variable.skip_rupture&!variable.priority_rotation&spell_targets.shuriken_storm>=2
    -- &target.time_to_die>=(2*combo_points)&refreshable
    if not ReturnSpellOnly and HR.AoEON() and not PriorityRotation and MeleeEnemies10yCount >= 2 then
      local function Evaluate_Rupture_Target(TargetUnit)
        return Everyone.CanDoTUnit(TargetUnit, RuptureDMGThreshold)
          and TargetUnit:DebuffRefreshable(S.Rupture, RuptureThreshold)
      end
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, (2 * FinishComboPoints), MeleeEnemies5y)
    end

    -- actions.finish+=/rupture,if=!variable.skip_rupture&buff.finality_rupture.up
    --&(cooldown.symbols_of_death.remains<=3|buff.symbols_of_death.up)
    if Player:BuffUp(S.FinalityRuptureBuff) and (S.SymbolsofDeath:CooldownRemains() <= 3 or Player:BuffUp(S.SymbolsofDeath)) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if S.Rupture:IsReady() and Cast(S.Rupture) then return "Cast Rupture 2" end
        SetPoolingFinisher(S.Rupture)
      end
    end
  end

  -- # deathstalker bp
  -- actions.finish+=/black_powder,if=!variable.priority_rotation&talent.deathstalkers_mark&spell_targets>=3&!buff.darkest_night.up
  if S.BlackPowder:IsCastable() and not PriorityRotation and S.DeathStalkersMark:IsAvailable() and MeleeEnemies10yCount >= 3
    and Player:BuffDown(S.DarkestNightBuff) then
      if ReturnSpellOnly then
        return S.BlackPowder
      else
        if S.BlackPowder:IsReady() and Cast(S.BlackPowder) then return "Cast Black Powder 1" end
        SetPoolingFinisher(S.BlackPowder)
      end
  end

  -- # trickster bp
  -- actions.finish+=/black_powder,if=!variable.priority_rotation&talent.unseen_blade
  -- &((buff.escalating_blade.stack=4&!buff.shadow_dance.up)|spell_targets>=3&!buff.flawless_form.up|spell_targets>10
  -- |(!used_for_danse&buff.shadow_dance.up&talent.shuriken_tornado&spell_targets>=3))
  if S.BlackPowder:IsCastable() and not PriorityRotation and S.UnseenBlade:IsAvailable()
    and ((Player:BuffStack(S.EscalatingBlade) == 4 and Player:BuffDown(S.ShadowDanceBuff)) or MeleeEnemies10yCount >= 3
    and Player:BuffDown(S.FlawlessFormBuff) or MeleeEnemies10yCount > 10 or (not Used_For_Danse(S.BlackPowder)
    and Player:BuffUp(S.ShadowDanceBuff) and S.ShurikenTornado:IsAvailable() and MeleeEnemies10yCount >= 3)) then
      if ReturnSpellOnly then
        return S.BlackPowder
      else
        if S.BlackPowder:IsReady() and Cast(S.BlackPowder) then return "Cast BlackPowder 2" end
        SetPoolingFinisher(S.BlackPowder)
      end
  end

  -- actions.finish+=/coup_de_grace,if=debuff.fazed.up
  if S.CoupDeGrace:IsCastable() and TargetInMeleeRange and Target:DebuffUp(S.FazedDebuff) then
    if ReturnSpellOnly then
      return S.CoupDeGrace
    else
      if S.CoupDeGrace:IsReady() and Cast(S.CoupDeGrace) then return "Cast Coup De Grace 2" end
      SetPoolingFinisher(S.CoupDeGrace)
    end
  end

  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and TargetInMeleeRange then
    if ReturnSpellOnly then
      return S.Eviscerate
    else
      if S.Eviscerate:IsReady() and Cast(S.Eviscerate) then return "Cast Eviscerate" end
      SetPoolingFinisher(S.Eviscerate)
    end
  end

  return false
end

-- # Stealthed Rotation
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Stealthed (ReturnSpellOnly, StealthSpell)
  local ShadowDanceBuff = Player:BuffUp(S.ShadowDanceBuff)
  local ShadowDanceBuffRemains = Player:BuffRemains(S.ShadowDanceBuff)
  local TheRottenBuff = Player:BuffUp(S.TheRottenBuff)
  local StealthComboPoints, StealthComboPointsDeficit = ComboPoints, ComboPointsDeficit

  -- State changes based on predicted Stealth casts
  local PremeditationBuff = Player:BuffUp(S.PremeditationBuff) or (StealthSpell and S.Premeditation:IsAvailable())
  local StealthBuff = Player:BuffUp(Rogue.StealthSpell()) or (StealthSpell and StealthSpell:ID() == Rogue.StealthSpell():ID())
  local VanishBuffCheck = Player:BuffUp(Rogue.VanishBuffSpell()) or (StealthSpell and StealthSpell:ID() == S.Vanish:ID())
  if StealthSpell and StealthSpell:ID() == S.ShadowDance:ID() then
    ShadowDanceBuff = true
    ShadowDanceBuffRemains = 8 + S.ImprovedShadowDance:TalentRank()
    if S.TheRotten:IsAvailable() and Player:HasTier(30, 2) then
      TheRottenBuff = true
    end
    if S.TheFirstDance:IsAvailable() then
      StealthComboPoints = mathmin(Player:ComboPointsMax(), ComboPoints + 4)
      StealthComboPointsDeficit = Player:ComboPointsMax() - StealthComboPoints
    end
  end

  local StealthEffectiveComboPoints = Rogue.EffectiveComboPoints(StealthComboPoints)
  local ShadowstrikeIsCastable = S.Shadowstrike:IsCastable() or StealthBuff or VanishBuffCheck or ShadowDanceBuff or Player:BuffUp(S.SepsisBuff)
  if StealthBuff or VanishBuffCheck then
    ShadowstrikeIsCastable = ShadowstrikeIsCastable and Target:IsInRange(25)
  else
    ShadowstrikeIsCastable = ShadowstrikeIsCastable and TargetInMeleeRange
  end

  -- actions.stealthed=shadowstrike,if=talent.deathstalkers_mark&!debuff.deathstalkers_mark.up&!buff.darkest_night.up
  if ShadowstrikeIsCastable and S.DeathStalkersMark:IsAvailable() and Target:DebuffDown(S.DeathStalkersMarkDebuff)
    and Player:BuffDown(S.DarkestNightBuff) then
      if ReturnSpellOnly then
        return S.Shadowstrike
      else
        if Cast(S.Shadowstrike) then return "Cast Shadowstrike (Stealth 1)" end
      end
  end

  -- actions.stealthed+=/call_action_list,name=finish,if=buff.darkest_night.up&combo_points==cp_max_spend
  if Player:BuffUp(S.DarkestNightBuff) and ComboPoints == Rogue.CPMaxSpend() then
    return Finish(ReturnSpellOnly, StealthSpell)
  end

  -- actions.stealthed+=/call_action_list,name=finish,if=effective_combo_points>=cp_max_spend&!buff.darkest_night.up
  if EffectiveComboPoints >= Rogue.CPMaxSpend() and Player:BuffDown(S.DarkestNightBuff) then
    return Finish(ReturnSpellOnly, StealthSpell)
  end

  -- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2&!buff.darkest_night.up
  if Player:BuffUp(S.ShurikenTornado) and StealthComboPointsDeficit <= 2 and Player:BuffDown(S.DarkestNightBuff) then
    return Finish(ReturnSpellOnly, StealthSpell)
  end

  -- actions.stealthed+=/call_action_list,name=finish,if=(combo_points.deficit<=1+talent.deathstalkers_mark)&!buff.darkest_night.up
  if (ComboPointsDeficit <= 1 + num(S.DeathStalkersMark:IsAvailable())) and Player:BuffDown(S.DarkestNightBuff) then
    return Finish(ReturnSpellOnly, StealthSpell)
  end

  -- actions.stealthed+=/shadowstrike,if=(!used_for_danse&buff.shadow_blades.up)|(talent.unseen_blade&spell_targets>=2)
  if ShadowstrikeIsCastable and (not Used_For_Danse(S.Shadowstrike) and Player:BuffUp(S.ShadowBlades))
    or (S.UnseenBlade:IsAvailable() and MeleeEnemies10yCount >= 2) then
      if ReturnSpellOnly then
        return S.Shadowstrike
      else
        if Cast(S.Shadowstrike) then return "Cast Shadowstrike (Stealth 2)" end
      end
  end

  -- actions.stealthed+=/shuriken_storm,if=!buff.premeditation.up&spell_targets>=4
  if S.ShurikenStorm:IsCastable() then
    if Player:BuffDown(S.PremeditationBuff) and MeleeEnemies10yCount >= 4 then
      if ReturnSpellOnly then
        return S.ShurikenStorm
      else
        if Cast(S.ShurikenStorm) then return "Cast ShurikenStorm (Stealth)" end
      end
    end
  end

  -- actions.stealthed+=/gloomblade,if=buff.lingering_shadow.remains>=10&buff.shadow_blades.up&spell_targets=1
  if S.Gloomblade:IsAvailable() then
    if Player:BuffRemains(S.LingeringShadowBuff) >= 10 and Player:BuffUp(S.ShadowBlades) and MeleeEnemies10yCount == 1 then
      if ReturnSpellOnly then
        -- If calling from a Stealth macro, we don't need the PV suggestion since it's already a macro cast
        if StealthSpell then
          return S.Gloomblade
        else
          return { S.Gloomblade, S.Stealth }
        end
      else
        if CastQueue(S.Gloomblade, S.Stealth) then return "Cast Gloomblade (Danse)" end
      end
    end
  end

  -- actions.stealthed+=/shadowstrike
  if ShadowstrikeIsCastable then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if Cast(S.Shadowstrike) then return "Cast Shadowstrike" end
    end
  end

  return false
end

-- # Stealth Macros
-- This returns a table with the original Stealth spell and the result of the Stealthed action list as if the applicable buff was present
local function StealthMacro (StealthSpell, EnergyThreshold)
  -- Fetch the predicted ability to use after the stealth spell
  local MacroAbility = Stealthed(true, StealthSpell)

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if StealthSpell:ID() == S.Vanish:ID() and (not Settings.Subtlety.StealthMacro.Vanish or not MacroAbility) then
    if Cast(S.Vanish, Settings.CommonsOGCD.OffGCDasOffGCD.Vanish) then return "Cast Vanish" end
    return false
  elseif StealthSpell:ID() == S.Shadowmeld:ID() and (not Settings.Subtlety.StealthMacro.Shadowmeld or not MacroAbility) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
    return false
  elseif StealthSpell:ID() == S.ShadowDance:ID() and (not Settings.Subtlety.StealthMacro.ShadowDance or not MacroAbility) then
    if Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
    return false
  end

  local MacroTable = {StealthSpell, MacroAbility}

  -- Set the stealth spell only as a pooling fallback if we did not meet the threshold
  if EnergyThreshold and Player:EnergyPredicted() < EnergyThreshold then
    SetPoolingAbility(MacroTable, EnergyThreshold)
    return false
  end

  ShouldReturn = CastQueue(unpack(MacroTable))
  if ShouldReturn then return "| " .. MacroTable[2]:Name() end

  return false
end

-- # Cooldowns
local function CDs ()
  -- actions.cds+=/cold_blood,if=!talent.secret_technique&combo_points>=6
  if HR.CDsON() and S.ColdBlood:IsReady() and not S.SecretTechnique:IsAvailable() and ComboPoints >= 6 then
    if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then return "Cast Cold Blood" end
  end

  -- actions.cds+=/sepsis,if=variable.snd_condition&(cooldown.shadow_blades.remains<=3
  -- &cooldown.symbols_of_death.remains<=3|fight_remains<=12)
  if HR.CDsON() and S.Sepsis:IsAvailable() and S.Sepsis:IsReady() then
    if SnD_Condition() and (S.ShadowBlades:CooldownRemains() <= 3
      and S.SymbolsofDeath:CooldownRemains() <= 3 or HL.BossFilteredFightRemains("<=", 12)) then
      if Cast(S.Sepsis, nil, Settings.CommonsDS.DisplayStyle.Sepsis) then return "Cast Sepsis" end
    end
  end

  -- actions.cds+=/flagellation,target_if=max:target.time_to_die,if=variable.snd_condition&variable.ruptures_before_flag
  -- &combo_points>=6&target.time_to_die>10&(cooldown.shadow_blades.remains<=2|fight_remains<=24)
  -- &(!talent.invigorating_shadowdust|cooldown.symbols_of_death.remains<=3|buff.symbols_of_death.remains>3)
  if HR.CDsON() and S.Flagellation:IsAvailable() and S.Flagellation:IsReady() then
    if SnD_Condition() and Rupture_Before_Flag() and EffectiveComboPoints >= 6 and Target:TimeToDie() > 10
      and (S.ShadowBlades:CooldownRemains() <= 2 or HL.BossFilteredFightRemains("<=", 24))
      and (not S.InvigoratingShadowdust:IsAvailable() or S.SymbolsofDeath:CooldownRemains() <= 3 or Player:BuffRemains(S.SymbolsofDeath) >3 ) then
      if Cast(S.Flagellation, nil, Settings.CommonsDS.DisplayStyle.Flagellation) then return "Cast Flagellation" end
    end
  end

  -- # Symbols without Invigorating Shadowdust
  -- actions.cds+=/symbols_of_death,if=!talent.invigorating_shadowdust&variable.snd_condition
  -- &(buff.shadow_blades.up|cooldown.shadow_blades.remains>20)
  if HR.CDsON() and S.SymbolsofDeath:IsReady() then
    if not S.InvigoratingShadowdust:IsAvailable() and SnD_Condition()
      and (Player:BuffUp(S.ShadowBlades) or S.ShadowBlades:CooldownRemains() > 20) then
        if Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death without Dust" end
    end
  end

  -- # Symbols with Invigorating Shadowdust
  -- actions.cds+=/symbols_of_death,if=talent.invigorating_shadowdust&variable.snd_condition
  -- &buff.symbols_of_death.remains<=3&!buff.the_rotten.up&(cooldown.flagellation.remains>10|cooldown.flagellation.up
  -- &cooldown.shadow_blades.remains>=20|buff.shadow_dance.remains>=2)
  if HR.CDsON() and S.SymbolsofDeath:IsReady() then
    if S.InvigoratingShadowdust:IsAvailable() and SnD_Condition() and Player:BuffRemains(S.SymbolsofDeath) <= 3
      and Player:BuffDown(S.TheRottenBuff) and (S.Flagellation:CooldownRemains() > 10 or S.Flagellation:IsReady()
      and S.ShadowBlades:CooldownRemains() >= 20 or Player:BuffRemains(S.ShadowDanceBuff) >= 2) then
      if Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death with Dust" end
    end
  end

  -- actions.cds+=/shadow_blades,if=variable.snd_condition&combo_points<=1&(buff.flagellation_buff.up
  -- |!talent.flagellation)|fight_remains<=20
  if HR.CDsON() and S.ShadowBlades:IsReady() then
    if SnD_Condition() and EffectiveComboPoints <= 1 and (Player:BuffUp(S.Flagellation) or not S.Flagellation:IsAvailable())
      or HL.BossFilteredFightRemains("<=", 20) then
    if Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return "Cast Shadow Blades" end
    end
  end

  -- actions.cds+=/echoing_reprimand,if=variable.snd_condition&combo_points.deficit>=3
  -- &(!talent.the_rotten|!talent.reverberation|buff.shadow_dance.up)
  if HR.CDsON() and S.EchoingReprimand:IsCastable() and S.EchoingReprimand:IsAvailable() then
    if SnD_Condition() and ComboPointsDeficit >= 3
      and (not S.TheRotten:IsAvailable() or not S.Reverberation:IsAvailable() or Player:BuffUp(S.ShadowDance)) then
        if Cast(S.EchoingReprimand, nil, Settings.CommonsDS.DisplayStyle.EchoingReprimand) then return "Cast Echoing Reprimand" end
    end
  end

  -- actions.cds+=/shuriken_tornado,if=variable.snd_condition&buff.symbols_of_death.up&combo_points<=2
  -- &!buff.premeditation.up&(!talent.flagellation|cooldown.flagellation.remains>20)&spell_targets.shuriken_storm>=3
  -- Shuriken Tornado with Symbols of Death on 3 and more targets
  if HR.CDsON() and S.ShurikenTornado:IsAvailable() and S.ShurikenTornado:IsReady() then
    if SnD_Condition() and Player:BuffUp(S.SymbolsofDeath) and EffectiveComboPoints <= 2 and not Player:BuffUp(S.PremeditationBuff)
      and (not S.Flagellation:IsAvailable() or S.Flagellation:CooldownRemains() > 20) and MeleeEnemies10yCount >= 3 then
        if Cast(S.ShurikenTornado, Settings.Subtlety.GCDasOffGCD.ShurikenTornado) then return "Cast Shuriken Tornado 1" end
    end
  end

  -- actions.cds+=/shuriken_tornado,if=variable.snd_condition&!buff.shadow_dance.up&!buff.flagellation_buff.up&!buff.flagellation_persist.up
  -- &!buff.shadow_blades.up&spell_targets.shuriken_storm<=2&!raid_event.adds.up
  -- Shuriken Tornado only outside of cooldowns
  if HR.CDsON() and S.ShurikenTornado:IsAvailable() and S.ShurikenTornado:IsReady() then
    if SnD_Condition() and Player:BuffDown(S.ShadowDanceBuff) and Player:BuffDown(S.Flagellation)
      and Player:BuffDown(S.FlagellationPersistBuff) and Player:BuffDown(S.ShadowBlades) and MeleeEnemies10yCount <= 2 then
        if Cast(S.ShurikenTornado, Settings.Subtlety.GCDasOffGCD.ShurikenTornado) then return "Cast Shuriken Tornado 2" end
    end
  end

  -- actions.cds+=/vanish,if=buff.shadow_dance.up&talent.invigorating_shadowdust&talent.unseen_blade&(combo_points.deficit>1)
  -- &(cooldown.flagellation.remains>=60|!talent.flagellation|fight_remains<=(30*cooldown.vanish.charges))
  -- &(cooldown.secret_technique.remains>=10&!raid_event.adds.up)
  if HR.CDsON() and S.Vanish:IsReady() then
    if Player:BuffUp(S.ShadowDanceBuff) and S.InvigoratingShadowdust:IsAvailable() and S.UnseenBlade:IsAvailable()
      and ComboPointsDeficit > 1 and (S.Flagellation:CooldownRemains() >= 60 or not S.Flagellation:IsAvailable() or HL.BossFilteredFightRemains("<=", 30*S.Vanish:Charges()))
      and S.SecretTechnique:CooldownRemains() >= 10 then
      if Cast(S.Vanish) then return "Cast Vanish" end
    end
  end

  -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&fight_remains<=8+talent.subterfuge.enabled

  -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&fight_remains<=8+talent.subterfuge.enabled
  if HR.CDsON() and S.ShadowDance:IsAvailable() and MayBurnShadowDance() and S.ShadowDance:IsReady() then
    if not Player:BuffUp(S.ShadowDanceBuff) and HL.BossFilteredFightRemains("<=", 8 + num(S.Subterfuge:IsAvailable())) then
      if Cast(S.ShadowDance) then return "Cast Shadow Dance CDs 1" end
    end
  end

  -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&talent.invigorating_shadowdust&talent.deathstalkers_mark
  -- &buff.shadow_blades.up&(buff.subterfuge.up&spell_targets>=4|buff.subterfuge.remains>=3)
  if HR.CDsON() and S.ShadowDance:IsAvailable() and S.ShadowDance:IsReady() then
    if Player:BuffDown(S.ShadowDanceBuff) and S.InvigoratingShadowdust:IsAvailable() and S.DeathStalkersMark:IsAvailable()
      and Player:BuffUp(S.ShadowBlades) and (Player:BuffUp(S.Subterfuge) and MeleeEnemies10yCount >= 4
      or Player:BuffRemains(S.Subterfuge) >= 3) then
        if Cast(S.ShadowDance) then return "Cast Shadow Dance CDs 2" end
    end
  end

  -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&talent.unseen_blade&talent.invigorating_shadowdust
  -- &dot.rupture.ticking&variable.snd_condition&(buff.symbols_of_death.remains>=6&!buff.flagellation_buff.up
  -- |buff.symbols_of_death.up&buff.shadow_blades.up|buff.shadow_blades.up&!talent.invigorating_shadowdust)
  -- &(cooldown.secret_technique.remains<10+12*!talent.invigorating_shadowdust|buff.shadow_blades.up)
  -- &(!talent.the_first_dance|(combo_points.deficit>=7&!buff.shadow_blades.up|buff.shadow_blades.up))
  if HR.CDsON() and S.ShadowDance:IsAvailable() and S.ShadowDance:IsReady() then
    if Player:BuffDown(S.ShadowDanceBuff) and S.UnseenBlade:IsAvailable() and S.InvigoratingShadowdust:IsAvailable()
    and Target:DebuffUp(S.Rupture) and SnD_Condition() and (Player:BuffRemains(S.SymbolsofDeath) >= 6 and Player:BuffDown(S.Flagellation)
    or Player:BuffUp(S.SymbolsofDeath) and Player:BuffUp(S.ShadowBlades) or Player:BuffUp(S.ShadowBlades) and not S.InvigoratingShadowdust:IsAvailable())
    and (S.SecretTechnique:CooldownRemains() <= 10 + 12 * num(not S.InvigoratingShadowdust:IsAvailable() or Player:BuffUp(S.ShadowBlades))
      and (not S.TheFirstDance:IsAvailable() or (ComboPointsDeficit >= 7 and Player:BuffDown(S.ShadowBlades) or Player:BuffUp(S.ShadowBlades)))) then
        if Cast(S.ShadowDance) then return "Cast Shadow Dance CDs 3" end
    end
  end

  -- actions.cds+=/goremaws_bite,if=variable.snd_condition&combo_points.deficit>=3
  -- &(!cooldown.shadow_dance.up|talent.double_dance&buff.shadow_dance.up&!talent.invigorating_shadowdust
  -- |spell_targets.shuriken_storm<4&!talent.invigorating_shadowdust|talent.the_rotten|raid_event.adds.up)
  -- Goremaws Bite during Shadow Dance if possible.
  if HR.CDsON() and S.GoremawsBite:IsAvailable() and S.GoremawsBite:IsReady() then
    if SnD_Condition() and ComboPointsDeficit >= 3 and (not S.ShadowDance:IsReady() or S.DoubleDance:IsAvailable()
      and Player:BuffUp(S.ShadowDanceBuff) and not S.InvigoratingShadowdust:IsAvailable() or MeleeEnemies10yCount < 4
      and not S.InvigoratingShadowdust:IsAvailable() or S.TheRotten:IsAvailable() ) then
        if Cast(S.GoremawsBite) then return "Cast Goremaw's Bite" end
    end
  end

  -- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(buff.shadow_dance.remains>=4
  -- &buff.shadow_blades.up|buff.shadow_dance.remains>=4&cooldown.cold_blood.remains<=3)
  -- |fight_remains<=(6*cooldown.thistle_tea.charges)
  if S.ThistleTea:IsReady() then
    if Player:BuffDown(S.ThistleTea) and (Player:BuffRemains(S.ShadowDanceBuff) >= 4
    and Player:BuffUp(S.ShadowBlades) or Player:BuffRemains(S.ShadowDanceBuff) >= 4 and S.ColdBlood:CooldownRemains() <= 3)
    or HL.BossFilteredFightRemains("<=", 6*S.ThistleTea:Charges()) then
      if Cast(S.ThistleTea, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "Thistle Tea"; end
    end
  end

  -- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.symbols_of_death.up
  -- &(buff.shadow_blades.up|cooldown.shadow_blades.remains<=10)
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (Player:BloodlustUp() or HL.BossFilteredFightRemains("<", 30) or Player:BuffUp(S.SymbolsofDeath)
    and (Player:BuffUp(S.ShadowBlades) or S.ShadowBlades:CooldownRemains() <= 10)) then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "Cast Potion"; end
    end
  end

  -- variable,name=racial_sync,value=buff.shadow_blades.up|!talent.shadow_blades&buff.symbols_of_death.up|fight_remains<20
  local racial_sync = Player:BuffUp(S.ShadowBlades) or not S.ShadowBlades:IsAvailable() and Player:BuffUp(S.SymbolsofDeath) or HL.BossFilteredFightRemains("<", 20)

  -- actions.cds+=/blood_fury,if=variable.racial_sync
  if S.BloodFury:IsCastable() and racial_sync then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
  end

  -- actions.cds+=/berserking,if=variable.racial_sync
  if S.Berserking:IsCastable() and racial_sync then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
  end

  -- actions.cds+=/fireblood,if=variable.racial_sync
  if S.Fireblood:IsCastable() and racial_sync and Player:BuffUp(S.ShadowDanceBuff) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
  end

  -- actions.cds+=/ancestral_call,if=variable.racial_sync
  if S.AncestralCall:IsCastable() and racial_sync then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
  end

  return false
end

-- # Items
local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- actions.items+=/use_item,name=treacherous_transmitter,if=buff.shadow_blades.up|fight_remains<=15
    if I.TreacherousTransmitter:IsEquippedAndReady() then
      if Player:BuffUp(S.ShadowBlades) or HL.BossFilteredFightRemains("<=", 15) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "Treacherous Transmitter" end
      end
    end

    --actions.items+=/use_item,name=imperfect_ascendancy_serum,use_off_gcd=1,if=dot.rupture.ticking&buff.flagellation_buff.up
    if I.ImperfectAscendancySerum:IsEquippedAndReady() then
      if  Target:DebuffUp(S.Rupture) and Player:BuffUp(S.Flagellation) then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "Imperfect Ascendancy Serum" end
      end
    end

    local TrinketSpell
    local TrinketRange = 100
    --actions.items+=/use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(buff.shadow_blades.up
    -- |(1+cooldown.shadow_blades.remains)>=trinket.1.cooldown.duration|fight_remains<=20)|(variable.trinket_sync_slot=2
    -- &(!trinket.2.cooldown.ready&!buff.shadow_blades.up&cooldown.shadow_blades.remains>20))|!variable.trinket_sync_slot)
    if trinket1 then
      TrinketSpell = trinket1:OnUseSpell()
      TrinketRange = (TrinketSpell and TrinketSpell.MaximumRange > 0 and TrinketSpell.MaximumRange <= 100) and TrinketSpell.MaximumRange or 100
    end
    if trinket1:IsEquippedAndReady() and not ValueIsInArray(OnUseExcludes, trinket1:ID()) and (Trinket_Sync_Slot() == 1 and (Player:BuffUp(S.ShadowBlades) or (1+S.ShadowBlades:CooldownRemains()) >= trinket1:CooldownRemains()
      or HL.BossFilteredFightRemains("<=", 20)) or (Trinket_Sync_Slot() == 2 and (not trinket2:IsReady() and not Player:BuffUp(S.ShadowBlades)
      and S.ShadowBlades:CooldownRemains() > 20)) or Trinket_Sync_Slot() == 0) then
        if Cast(trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(TrinketRange)) then return "Generic use_items for " .. trinket1:Name() end
    end

    --actions.items+=/use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(buff.shadow_blades.up
    -- |(1+cooldown.shadow_blades.remains)>=trinket.2.cooldown.duration|fight_remains<=20)|(variable.trinket_sync_slot=1
    -- &(!trinket.1.cooldown.ready&!buff.shadow_blades.up&cooldown.shadow_blades.remains>20))|!variable.trinket_sync_slot)
    if trinket2 then
      TrinketSpell = trinket2:OnUseSpell()
      TrinketRange = (TrinketSpell and TrinketSpell.MaximumRange > 0 and TrinketSpell.MaximumRange <= 100) and TrinketSpell.MaximumRange or 100
    end
    if trinket2:IsEquippedAndReady() and not ValueIsInArray(OnUseExcludes, trinket2:ID()) and (Trinket_Sync_Slot() == 2 and (Player:BuffUp(S.ShadowBlades) or (1+S.ShadowBlades:CooldownRemains()) >= trinket2:CooldownRemains()
      or HL.BossFilteredFightRemains("<=", 20)) or (Trinket_Sync_Slot() == 1 and (not trinket1:IsReady() and not Player:BuffUp(S.ShadowBlades)
      and S.ShadowBlades:CooldownRemains() > 20)) or Trinket_Sync_Slot() == 0) then
      if Cast(trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(TrinketRange)) then return "Generic use_items for " .. trinket2:Name() end
    end
  end

  return false
end

-- # Stealth Cooldowns
local function Stealth_CDs (EnergyThreshold)
  if HR.CDsON() and not (Everyone.IsSoloMode() and Player:IsTanking(Target)) then
    local cb = not S.ColdBlood:IsAvailable() or S.ColdBlood:CooldownRemains() < 4 or S.ColdBlood:CooldownRemains() > 10

    -- actions.stealth_cds=vanish,if=!talent.invigorating_shadowdust&!talent.subterfuge&combo_points.deficit>=3
    -- &(!dot.rupture.ticking|(buff.shadow_blades.up&buff.symbols_of_death.up)|talent.premeditation|fight_remains<10)
    if S.Vanish:IsCastable() then
      if not S.InvigoratingShadowdust:IsAvailable() and not S.Subterfuge:IsAvailable() and ComboPointsDeficit >= 3
        and (Target:DebuffDown(S.Rupture) or (Player:BuffUp(S.ShadowBlades) and Player:BuffUp(S.SymbolsofDeath))
        or S.Premeditation:IsAvailable() or HL.BossFilteredFightRemains("<", 10)) then
          ShouldReturn = StealthMacro(S.Vanish, EnergyThreshold)
          if ShouldReturn then return "Vanish Macro 1 No Dust" .. ShouldReturn end
      end
    end

    -- actions.stealth_cds+=/vanish,if=!buff.shadow_dance.up&talent.invigorating_shadowdust&talent.deathstalkers_mark
    -- &(combo_points.deficit>1|buff.shadow_blades.up)&(cooldown.flagellation.remains>=60|!talent.flagellation
    -- |fight_remains<=(30*cooldown.vanish.charges))&(cooldown.secret_technique.remains>=10&!raid_event.adds.up)
    if S.Vanish:IsCastable() then
      if Player:BuffDown(S.ShadowDanceBuff) and S.InvigoratingShadowdust:IsAvailable() and S.DeathStalkersMark:IsAvailable()
        and (ComboPointsDeficit > 1 or Player:BuffUp(S.ShadowBlades)) and (S.Flagellation:CooldownRemains() >= 60
        or not S.Flagellation:IsAvailable() or HL.BossFilteredFightRemains("<=", 30*S.Vanish:Charges()))
        and S.SecretTechnique:CooldownRemains() >= 10 then
          ShouldReturn = StealthMacro(S.Vanish, EnergyThreshold)
          if ShouldReturn then return "Vanish Macro 2 Dust" .. ShouldReturn end
      end
    end

    -- actions.stealth_cds+=/shadow_dance,if=dot.rupture.ticking&variable.snd_condition
    -- &(buff.symbols_of_death.remains>=6&!buff.flagellation_buff.up|buff.symbols_of_death.up&buff.shadow_blades.up
    -- |buff.shadow_blades.up&!talent.invigorating_shadowdust)
    -- &cooldown.secret_technique.remains<10+12*!talent.invigorating_shadowdust
    -- &(!talent.the_first_dance|(combo_points.deficit>=7&!buff.shadow_blades.up|buff.shadow_blades.up))
    if S.ShadowDance:IsReady() and S.ShadowDance:IsCastable() then
      if Target:DebuffUp(S.Rupture) and SnD_Condition() and (Player:BuffRemains(S.SymbolsofDeath) >= 6 and Player:BuffDown(S.Flagellation)
        or Player:BuffUp(S.SymbolsofDeath) and Player:BuffUp(S.ShadowBlades) or Player:BuffUp(S.ShadowBlades) and not S.InvigoratingShadowdust:IsAvailable())
        and S.SecretTechnique:CooldownRemains() < 10 + 12 * num(S.InvigoratingShadowdust:IsAvailable())
        and (not S.TheFirstDance:IsAvailable() or (ComboPointsDeficit >= 7 and Player:BuffDown(S.ShadowBlades) or Player:BuffUp(S.ShadowBlades))) then
          ShouldReturn = StealthMacro(S.ShadowDance, EnergyThreshold)
          if ShouldReturn then return "Shadow Dance Macro 1 " .. ShouldReturn end
      end
    end

    -- actions.stealth_cds+=/vanish,if=!talent.invigorating_shadowdust&talent.subterfuge&combo_points.deficit>=3
    -- &(buff.symbols_of_death.up|cooldown.symbols_of_death.remains>=3)
    if S.Vanish:IsCastable() then
      if not S.InvigoratingShadowdust:IsAvailable() and not S.Subterfuge:IsAvailable() and ComboPointsDeficit >= 3
        and (Player:BuffUp(S.SymbolsofDeath) or S.SymbolsofDeath:CooldownRemains() >= 3) then
        ShouldReturn = StealthMacro(S.Vanish, EnergyThreshold)
        if ShouldReturn then return "Vanish Macro 3 No Dust Subterfuge " .. ShouldReturn end
      end
    end

    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&combo_points.deficit>3
    -- Pool for Shadowmeld unless we are about to cap on Dance charges.
    if Settings.Commons.ShowPooling and Player:Energy() < 40 and S.Shadowmeld:IsCastable() and ComboPointsDeficit > 3 then
      if CastPooling(S.Shadowmeld, Player:EnergyTimeToX(40)) then return "Pool for Shadowmeld" end
    end
  end

  return false
end

-- # Builders
local function Build (EnergyThreshold)
  local ThresholdMet = not EnergyThreshold or Player:EnergyPredicted() >= EnergyThreshold

  -- actions.build=shuriken_storm,if=spell_targets>=2+(talent.gloomblade&buff.lingering_shadow.remains>=6|buff.perforated_veins.up)
    -- &(buff.flawless_form.up|!talent.unseen_blade)
  if HR.AoEON() and S.ShurikenStorm:IsCastable()
    and MeleeEnemies10yCount >= 2 + BoolToInt(S.Gloomblade:IsAvailable() and Player:BuffRemains(S.LingeringShadowBuff) >= 6 or Player:BuffUp(S.PerforatedVeinsBuff))
    and (Player:BuffUp(S.FlawlessFormBuff) or not S.UnseenBlade:IsAvailable()) then
      if ThresholdMet and Cast(S.ShurikenStorm) then return "Cast Shuriken Storm" end
        SetPoolingAbility(S.ShurikenStorm, EnergyThreshold)
  end

  -- actions.build+=/shuriken_storm,if=buff.clear_the_witnesses.up&(!buff.symbols_of_death.up|!talent.inevitability)
  -- &(buff.lingering_shadow.remains<=6|!talent.lingering_shadow)
  if HR.AoEON() and S.ShurikenStorm:IsCastable() then
    if Player:BuffUp(S.ClearTheWitnessesBuff) and (Player:BuffDown(S.SymbolsofDeath) or not S.Inevitability:IsAvailable())
      and (Player:BuffRemains(S.LingeringShadowBuff) <= 6 or not S.LingeringShadow:IsAvailable()) then
        if ThresholdMet and Cast(S.ShurikenStorm) then return "Cast Shuriken Storm Deathstalker ST" end
          SetPoolingAbility(S.ShurikenStorm, EnergyThreshold)
    end
  end

  if TargetInMeleeRange then
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if ThresholdMet and Cast(S.Gloomblade) then return "Cast Gloomblade" end
      SetPoolingAbility(S.Gloomblade, EnergyThreshold)

    -- actions.build+=/backstab
    elseif S.Backstab:IsCastable() then
      if ThresholdMet and Cast(S.Backstab) then return "Cast Backstab" end
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
  -- Reset pooling cache
  PoolingAbility = nil
  PoolingFinisher = nil
  PoolingEnergy = 0

  -- Unit Update
  MeleeRange = 5
  AoERange = 10
  TargetInMeleeRange = Target:IsInMeleeRange(MeleeRange)
  TargetInAoERange = Target:IsInMeleeRange(AoERange)
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Serrated Bone Spike
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(AoERange) -- Shuriken Storm & Black Powder
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(MeleeRange) -- Melee cycle
  else
    Enemies30y = {}
    MeleeEnemies10y = {}
    MeleeEnemies10yCount = 1
    MeleeEnemies5y = {}
  end

  -- Cache updates
  ComboPoints = Player:ComboPoints()
  EffectiveComboPoints = Rogue.EffectiveComboPoints(ComboPoints)
  ComboPointsDeficit = Player:ComboPointsDeficit()
  PriorityRotation = UsePriorityRotation()
  StealthEnergyRequired = Player:EnergyMax() - Stealth_Threshold()

  -- Shuriken Tornado Combo Point Prediction
  if Player:BuffUp(S.ShurikenTornado, nil, true) and ComboPoints < Rogue.CPMaxSpend() then
    local TimeToNextTornadoTick = Rogue.TimeToNextTornado()
    if TimeToNextTornadoTick <= Player:GCDRemains() or mathabs(Player:GCDRemains() - TimeToNextTornadoTick) < 0.25 then
      local PredictedComboPointGeneration = MeleeEnemies10yCount + num(Player:BuffUp(S.ShadowBlades))
      ComboPoints = mathmin(ComboPoints + PredictedComboPointGeneration, Rogue.CPMaxSpend())
      ComboPointsDeficit = mathmax(ComboPointsDeficit - PredictedComboPointGeneration, 0)
      if EffectiveComboPoints < Rogue.CPMaxSpend() then
        EffectiveComboPoints = ComboPoints
      end
    end
  end

  -- Damage Cache updates (after EffectiveComboPoints adjustments)
  RuptureThreshold = (4 + EffectiveComboPoints * 4) * 0.3
  RuptureDMGThreshold = S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.

  --- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial()
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  Rogue.Poisons()

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    -- Note: Since 7.2.5, Blizzard disallowed Stealth cast under ShD (workaround to prevent the Extended Stealth bug)
    if not Player:BuffUp(S.ShadowDanceBuff) and not Player:BuffUp(Rogue.VanishBuffSpell()) then
      ShouldReturn = Rogue.Stealth(Rogue.StealthSpell())
      if ShouldReturn then return ShouldReturn end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and (Target:IsSpellInRange(S.Shadowstrike) or TargetInMeleeRange) then
      -- Precombat CDs
      if Player:StealthUp(true, true) then
        PoolingAbility = Stealthed(true)
        if PoolingAbility then -- To avoid pooling icon spam
          if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
            if CastQueuePooling(nil, unpack(PoolingAbility)) then return "Stealthed Macro Cast or Pool (OOC): ".. PoolingAbility[1]:Name() end
          else
            if CastPooling(PoolingAbility) then return "Stealthed Cast or Pool (OOC): "..PoolingAbility:Name() end
          end
        end
      elseif ComboPoints >= 5 then
        ShouldReturn = Finish()
        if ShouldReturn then return ShouldReturn .. " (OOC)" end
      elseif S.Backstab:IsCastable() then
        if Cast(S.Backstab) then return "Cast Backstab (OOC)" end
      end
    end
    return
  end

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(S.Kick, Settings.CommonsDS.DisplayStyle.Interrupts, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- # Check CDs at first
    -- actions=call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end

  -- actions+=/call_action_list,name=items,if=variable.trinket_sync_slot=1
    ShouldReturn = Items()
    if ShouldReturn then return "Items: " .. ShouldReturn end

    -- actions+=/slice_and_dice,if=combo_points>=1&!variable.snd_condition
    if S.SliceandDice:IsCastable() and ComboPoints >= 1 and not SnD_Condition() then
      if S.SliceandDice:IsReady() and Cast(S.SliceandDice) then return "Cast Slice and Dice" end
    end

    -- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
    -- actions+=/run_action_list,name=stealthed,if=stealthed.all
    if Player:StealthUp(true, true) then
      PoolingAbility = Stealthed(true)
      if PoolingAbility then -- To avoid pooling icon spam
        if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
          if CastQueuePooling(nil, unpack(PoolingAbility)) then return "Stealthed Macro " .. PoolingAbility[1]:Name() .. "|" .. PoolingAbility[2]:Name() end
        else
          -- Special case for Shuriken Tornado
          if Player:BuffUp(S.ShurikenTornado) and ComboPoints ~= Player:ComboPoints()
            and (PoolingAbility == S.BlackPowder or PoolingAbility == S.Eviscerate or PoolingAbility == S.Rupture or PoolingAbility == S.SliceandDice) then
            if CastQueuePooling(nil, S.ShurikenTornado, PoolingAbility) then return "Stealthed Tornado Cast  " .. PoolingAbility:Name() end
          else
            if CastPooling(PoolingAbility) then return "Stealthed Cast " .. PoolingAbility:Name() end
          end
        end
      end
      Cast(S.PoolEnergy)
      return "Stealthed Pooling"
    end

    -- actions+=/call_action_list,name=stealth_cds
    ShouldReturn = Stealth_CDs(StealthEnergyRequired)
    if ShouldReturn then return "Stealth CDs: " .. ShouldReturn end

    -- actions+=/call_action_list,name=finish,if=buff.darkest_night.up&combo_points==cp_max_spend
    if Player:BuffUp(S.DarkestNightBuff) and ComboPoints == Rogue.CPMaxSpend() then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: 1 " .. ShouldReturn end
    end

    -- actions+=/call_action_list,name=finish,if=effective_combo_points>=cp_max_spend&!buff.darkest_night.up
    if EffectiveComboPoints >= Rogue.CPMaxSpend() and Player:BuffDown(S.DarkestNightBuff) then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: 2 " .. ShouldReturn end
    end

    -- actions+=/call_action_list,name=finish,if=(combo_points.deficit<=1+talent.deathstalkers_mark|fight_remains<=1&effective_combo_points>=3)
    -- &!buff.darkest_night.up
    if (ComboPointsDeficit <= 1 + num(S.DeathStalkersMark:IsAvailable()) or HL.FilteredFightRemains(MeleeEnemies10y, "<=", 1) and EffectiveComboPoints >= 3)
      and Player:BuffDown(S.DarkestNightBuff) then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: 3 " .. ShouldReturn end
    end

    -- Set Finisher as pooling ability before the builders are checked
    if PoolingFinisher then SetPoolingAbility(PoolingFinisher) end

    -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
    ShouldReturn = Build(StealthEnergyRequired)
    if ShouldReturn then return "Build: " .. ShouldReturn end

    if HR.CDsON() then
      -- # Lowest priority in all of the APL because it causes a GCD
      -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
      if S.ArcaneTorrent:IsReady() and TargetInMeleeRange and Player:EnergyDeficitPredicted() >= 15 + Player:EnergyRegen() then
        if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsReady() and TargetInMeleeRange then
        if Cast(S.ArcanePulse, Settings.CommonsOGCD.GCDasOffGCD.Racials) then return "Cast Arcane Pulse" end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsReady() then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
      end
      -- actions+=/bag_of_tricks
      if S.BagofTricks:IsReady() then
        if Cast(S.BagofTricks, Settings.CommonsOGCD.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
      end
    end

    -- Show what ever was first stored for pooling
    if PoolingAbility and TargetInMeleeRange then
      if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
        if CastQueuePooling(Player:EnergyTimeToX(PoolingEnergy), unpack(PoolingAbility)) then return "Macro pool towards ".. PoolingAbility[1]:Name() .. " at " .. PoolingEnergy end
      elseif PoolingAbility:IsCastable() then
        PoolingEnergy = mathmax(PoolingEnergy, PoolingAbility:Cost())
        if CastPooling(PoolingAbility, Player:EnergyTimeToX(PoolingEnergy)) then return "Pool towards: " .. PoolingAbility:Name() .. " at " .. PoolingEnergy end
      end
    end

    -- Shuriken Toss Out of Range
    if S.ShurikenToss:IsCastable() and Target:IsInRange(30) and not TargetInAoERange and not Player:StealthUp(true, true) and not Player:BuffUp(S.Sprint)
      and Player:EnergyDeficitPredicted() < 20 and (ComboPointsDeficit >= 1 or Player:EnergyTimeToMax() <= 1.2) then
      if CastPooling(S.ShurikenToss) then return "Cast Shuriken Toss" end
    end
  end
end

local function Init ()
  S.Rupture:RegisterAuraTracking()

  HR.Print("Subtlety Rogue rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(261, APL, Init)

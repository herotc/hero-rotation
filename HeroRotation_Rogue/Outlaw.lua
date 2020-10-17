--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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
local mathmin = math.min


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Assassination = HR.GUISettings.APL.Rogue.Assassination,
  Outlaw = HR.GUISettings.APL.Rogue.Outlaw,
}

-- Define S/I for spell and item arrays
local S = Spell.Rogue.Outlaw
local I = Item.Rogue.Outlaw

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.ComputationDevice:ID(),
  I.VigorTrinket:ID(),
  I.FontOfPower:ID(),
  I.RazorCoral:ID()
}

-- Rotation Var
local Enemies30y, EnemiesBF, EnemiesBFCount
local ShouldReturn; -- Used to get the return string
local BladeFlurryRange = 6
local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function () return true end },
}

-- Utils
local function num(val)
  if val then return 1 else return 0 end
end
local function EnergyTimeToMaxRounded ()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10
end
local function EnergyPredictedRounded ()
  -- Round to the nearesth int to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyPredicted() + 0.5)
end


--- ======= ACTION LISTS =======
local RtB_BuffsList = {
  S.Broadside,
  S.BuriedTreasure,
  S.GrandMelee,
  S.RuthlessPrecision,
  S.SkullandCrossbones,
  S.TrueBearing
}
local function RtB_List (Type, List)
  if not Cache.APLVar.RtB_List then Cache.APLVar.RtB_List = {} end
  if not Cache.APLVar.RtB_List[Type] then Cache.APLVar.RtB_List[Type] = {} end
  local Sequence = table.concat(List)
  -- All
  if Type == "All" then
    if not Cache.APLVar.RtB_List[Type][Sequence] then
      local Count = 0
      for i = 1, #List do
        if Player:BuffUp(RtB_BuffsList[List[i]]) then
          Count = Count + 1
        end
      end
      Cache.APLVar.RtB_List[Type][Sequence] = Count == #List and true or false
    end
  -- Any
  else
    if not Cache.APLVar.RtB_List[Type][Sequence] then
      Cache.APLVar.RtB_List[Type][Sequence] = false
      for i = 1, #List do
        if Player:BuffUp(RtB_BuffsList[List[i]]) then
          Cache.APLVar.RtB_List[Type][Sequence] = true
          break
        end
      end
    end
  end
  return Cache.APLVar.RtB_List[Type][Sequence]
end
local function RtB_BuffRemains ()
  if not Cache.APLVar.RtB_BuffRemains then
    Cache.APLVar.RtB_BuffRemains = 0
    for i = 1, #RtB_BuffsList do
      if Player:BuffUp(RtB_BuffsList[i]) then
        Cache.APLVar.RtB_BuffRemains = Player:BuffRemains(RtB_BuffsList[i])
        break
      end
    end
  end
  return Cache.APLVar.RtB_BuffRemains
end
-- Get the number of Roll the Bones buffs currently on
local function RtB_Buffs ()
  if not Cache.APLVar.RtB_Buffs then
    Cache.APLVar.RtB_Buffs = 0
    for i = 1, #RtB_BuffsList do
      if Player:BuffUp(RtB_BuffsList[i]) then
        Cache.APLVar.RtB_Buffs = Cache.APLVar.RtB_Buffs + 1
      end
    end
  end
  return Cache.APLVar.RtB_Buffs
end
-- RtB rerolling strategy, return true if we should reroll
local function RtB_Reroll ()
  if not Cache.APLVar.RtB_Reroll then
    -- 1+ Buff
    if Settings.Outlaw.RolltheBonesLogic == "1+ Buff" then
      Cache.APLVar.RtB_Reroll = (RtB_Buffs() <= 0) and true or false
    -- Broadside
    elseif Settings.Outlaw.RolltheBonesLogic == "Broadside" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.Broadside)) and true or false
    -- Buried Treasure
    elseif Settings.Outlaw.RolltheBonesLogic == "Buried Treasure" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.BuriedTreasure)) and true or false
    -- Grand Melee
    elseif Settings.Outlaw.RolltheBonesLogic == "Grand Melee" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.GrandMelee)) and true or false
    -- Skull and Crossbones
    elseif Settings.Outlaw.RolltheBonesLogic == "Skull and Crossbones" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.SkullandCrossbones)) and true or false
    -- Ruthless Precision
    elseif Settings.Outlaw.RolltheBonesLogic == "Ruthless Precision" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.RuthlessPrecision)) and true or false
    -- True Bearing
    elseif Settings.Outlaw.RolltheBonesLogic == "True Bearing" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.TrueBearing)) and true or false
    -- SimC Default
    else
      -- # Reroll for 2+ buffs with Loaded Dice up. Otherwise reroll for 2+ or Grand Melee or Ruthless Precision.
      -- actions=variable,name=rtb_reroll,value=rtb_buffs<2&(buff.loaded_dice.up|!buff.grand_melee.up&!buff.ruthless_precision.up)
      -- # Reroll for 2+ buffs or Broadside with Deadshot.
      -- actions+=/variable,name=rtb_reroll,op=set,if=azerite.deadshot.enabled,value=rtb_buffs<2&(buff.loaded_dice.up|!buff.broadside.up)
      -- # Reroll for 2+ buffs or Ruthless Precision with Ace up your Sleeve, unless there are more Deadshot ranks.
      -- actions+=/variable,name=rtb_reroll,op=set,if=azerite.ace_up_your_sleeve.enabled&azerite.ace_up_your_sleeve.rank>=azerite.deadshot.rank,value=rtb_buffs<2&(buff.loaded_dice.up|buff.ruthless_precision.remains<=cooldown.between_the_eyes.remains)
      -- # Always reroll for 2+ buffs with Snake Eyes.
      -- actions+=/variable,name=rtb_reroll,op=set,if=azerite.snake_eyes.rank>=2,value=rtb_buffs<2
      -- actions+=/variable,name=rtb_reroll,op=set,if=buff.blade_flurry.up,value=rtb_buffs-buff.skull_and_crossbones.up<2&(buff.loaded_dice.up|!buff.grand_melee.up&!buff.ruthless_precision.up&!buff.broadside.up)
      if Player:BuffUp(S.LoadedDiceBuff) then
        Cache.APLVar.RtB_Reroll = (RtB_Buffs() - num(Player:BuffUp(S.BuriedTreasure)) < 2 or RtB_BuffRemains() <= 12.6) and true or false
      elseif Player:BuffUp(S.BladeFlurry) then
        Cache.APLVar.RtB_Reroll = (RtB_Buffs() - num(Player:BuffUp(S.SkullandCrossbones)) < 2 and (Player:BuffUp(S.LoadedDiceBuff) or
          (not Player:BuffUp(S.GrandMelee) and not Player:BuffUp(S.RuthlessPrecision) and not Player:BuffUp(S.Broadside)))) and true or false
      elseif S.SnakeEyesPower:AzeriteRank() >= 2 then
        Cache.APLVar.RtB_Reroll = (RtB_Buffs() < 2) and true or false
        -- # Do not reroll if Snake Eyes is at 2+ stacks of the buff (1+ stack with Broadside up)
        -- actions+=/variable,name=rtb_reroll,op=reset,if=azerite.snake_eyes.rank>=2&buff.snake_eyes.stack>=2-buff.broadside.up
        if Player:BuffStack(S.SnakeEyesBuff) >= 2 - num(Player:BuffUp(S.Broadside)) then
          Cache.APLVar.RtB_Reroll = false
        end
      elseif S.AceUpYourSleeve:AzeriteEnabled() and S.AceUpYourSleeve:AzeriteRank() >= S.Deadshot:AzeriteRank() and Rogue.BaseAttackCrit() < 42 then
        Cache.APLVar.RtB_Reroll = (RtB_Buffs() < 2 and (Player:BuffUp(S.LoadedDiceBuff) or
          Player:BuffRemains(S.RuthlessPrecision) <= S.BetweentheEyes:CooldownRemains())) and true or false
      elseif S.Deadshot:AzeriteEnabled() or Rogue.BaseAttackCrit() >= 42 then
        Cache.APLVar.RtB_Reroll = (RtB_Buffs() < 2 and (Player:BuffUp(S.LoadedDiceBuff) or not Player:BuffUp(S.Broadside))) and true or false
      else
        Cache.APLVar.RtB_Reroll = (RtB_Buffs() < 2 and (Player:BuffUp(S.LoadedDiceBuff) or
          (not Player:BuffUp(S.GrandMelee) and not Player:BuffUp(S.RuthlessPrecision)))) and true or false
      end
    end

    -- Defensive Override : Grand Melee if HP < 60
    if Everyone.IsSoloMode() then
      if Player:BuffUp(S.GrandMelee) then
        if Player:IsTanking(Target) or Player:HealthPercentage() < mathmin(Settings.Outlaw.RolltheBonesLeechKeepHP, Settings.Outlaw.RolltheBonesLeechRerollHP) then
          Cache.APLVar.RtB_Reroll = false
        end
      elseif Player:HealthPercentage() < Settings.Outlaw.RolltheBonesLeechRerollHP then
        Cache.APLVar.RtB_Reroll = true
      end
    end
  end

  return Cache.APLVar.RtB_Reroll
end
-- # Condition to use Stealth cooldowns for Ambush
local function Ambush_Condition ()
  -- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&cooldown.ghostly_strike.remains<1)+buff.broadside.up&energy>60&!buff.skull_and_crossbones.up&!buff.keep_your_wits_about_you.up
  return Player:ComboPointsDeficit() >= 2 + 2 * ((S.GhostlyStrike:IsAvailable() and S.GhostlyStrike:CooldownRemains() < 1) and 1 or 0)
    + (Player:BuffUp(S.Broadside) and 1 or 0) and EnergyPredictedRounded() > 60 and not Player:BuffUp(S.SkullandCrossbones) and not Player:BuffUp(S.KeepYourWitsBuff)
end
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.up
local function Blade_Flurry_Sync ()
  return not AoEON() or EnemiesBFCount < 2 or Player:BuffUp(S.BladeFlurry)
end

-- # Essences
local function Essences ()
  -- blood_of_the_enemy,if=variable.blade_flurry_sync&cooldown.between_the_eyes.up&variable.bte_condition|fight_remains<=10
  if S.BloodoftheEnemy:IsCastable() and (Blade_Flurry_Sync() and S.BetweentheEyes:CooldownUp() or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast BloodoftheEnemy" end
  end
  -- concentrated_flame,if=energy.time_to_max>1&!buff.blade_flurry.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
  if S.ConcentratedFlame:IsCastable() and EnergyTimeToMaxRounded() > 1 and not Player:BuffUp(S.BladeFlurry) and (not Target:DebuffUp(S.ConcentratedFlameBurn)
    and not Player:PrevGCD(1, S.ConcentratedFlame) or S.ConcentratedFlame:FullRechargeTime() < Player:GCD() + Player:GCDRemains()) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast ConcentratedFlame" end
  end
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastable() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast GuardianofAzeroth" end
  end
  -- focused_azerite_beam,if=spell_targets.blade_flurry>=2|raid_event.adds.in>60&!buff.adrenaline_rush.up|fight_remains<10
  if S.FocusedAzeriteBeam:IsCastable() and (EnemiesBFCount >= 2 or not Player:BuffUp(S.AdrenalineRush) or HL.BossFilteredFightRemains("<", 10)) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast FocusedAzeriteBeam" end
  end
  -- purifying_blast,if=spell_targets.blade_flurry>=2|raid_event.adds.in>60|fight_remains<10
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
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastable() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast WorldveinResonance" end
  end
  -- memory_of_lucid_dreams,if=energy<45
  if S.MemoryofLucidDreams:IsCastable() and EnergyPredictedRounded() < 45 then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast MemoryofLucidDreams" end
  end
  -- reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30
  ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle)
  if ShouldReturn then return ShouldReturn end

  return false
end

local function CDs ()
  if Target:IsSpellInRange(S.SinisterStrike) then
    -- Quick and dirty Flagellation
    if S.Flagellation:IsCastable() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.Flagellation) then return "Cast Flrgrrlation" end
    end
    if S.FlagellationMastery:IsCastable() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.FlagellationMastery, Settings.Commons.OffGCDasOffGCD.FlagellationMastery) then return "Cast Flrgrrlation Mastery" end
    end

    -- actions.cds+=/call_action_list,name=essences,if=!stealthed.all
    if CDsON() and not Player:StealthUp(true, true) then
      ShouldReturn = Essences()
      if ShouldReturn then return ShouldReturn end
    end

    -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!equipped.azsharas_font_of_power|cooldown.latent_arcana.remains>20)
    if CDsON() and S.AdrenalineRush:IsCastable() and not Player:BuffUp(S.AdrenalineRush) and (not I.FontOfPower:IsEquipped() or I.FontOfPower:CooldownRemains() > 20) then
      if HR.Cast(S.AdrenalineRush, Settings.Outlaw.GCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush" end
    end

    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
    if S.MarkedforDeath:IsCastable() then
      -- Note: Increased the SimC condition by 50% since we are slower.
      if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()*1.5) or (Target:FilteredTimeToDie("<", 2) and Player:ComboPointsDeficit() > 0)
        or (((Player:BuffRemains(S.TrueBearing) > 15 - (Player:BuffUp(S.AdrenalineRush) and 5 or 0)) or Target:IsDummy())
          and not Player:StealthUp(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1) then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      elseif not Player:StealthUp(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1 then
        HR.CastSuggested(S.MarkedforDeath)
      end
    end
    if CDsON() then
      -- actions.cds+=/blade_flurry,if=spell_targets.blade_flurry>=2&!buff.blade_flurry.up
      if AoEON() and S.BladeFlurry:IsCastable() and EnemiesBFCount >= 2 and not Player:BuffUp(S.BladeFlurry) then
        if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
          HR.CastSuggested(S.BladeFlurry)
        else
          if HR.Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
        end
      end
      if Blade_Flurry_Sync() then
        -- actions.cds+=/ghostly_strike,if=variable.blade_flurry_sync&combo_points.deficit>=1+buff.broadside.up
        if S.GhostlyStrike:IsCastable() and Target:IsSpellInRange(S.GhostlyStrike) and Player:ComboPointsDeficit() >= (1 + (Player:BuffUp(S.Broadside) and 1 or 0)) then
          if HR.Cast(S.GhostlyStrike, Settings.Outlaw.GCDasOffGCD.GhostlyStrike) then return "Cast Ghostly Strike" end
        end
        -- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&(energy.time_to_max>5|energy<15)
        if S.KillingSpree:IsCastable() and Target:IsSpellInRange(S.KillingSpree) and (EnergyTimeToMaxRounded() > 5 or EnergyPredictedRounded() < 15) then
          if HR.Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle) then return "Cast Killing Spree" end
        end
        -- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&energy.time_to_max>1&(!buff.adrenaline_rush.up|energy<45)
        if S.BladeRush:IsCastable() and Target:IsSpellInRange(S.BladeRush) and EnergyTimeToMaxRounded() > 1
          and (not Player:BuffUp(S.AdrenalineRush) or EnergyPredictedRounded() < 45) then
          if HR.Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush) then return "Cast Blade Rush" end
        end
      end
      if Settings.Outlaw.UseDPSVanish and not Player:StealthUp(true, true) then
        -- # Using Vanish/Ambush is only a very tiny increase, so in reality, you're absolutely fine to use it as a utility spell.
        -- actions.cds+=/vanish,if=!stealthed.all&variable.ambush_condition
        if S.Vanish:IsCastable() and Ambush_Condition() and not Player:BuffUp(S.MasterAssassinsMark) then
          if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish" end
        end
        -- actions.cds+=/shadowmeld,if=!stealthed.all&variable.ambush_condition
        if S.Shadowmeld:IsCastable() and Ambush_Condition() then
          if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
        end
      end
    end

    -- Placeholder Roll the Bones
    if S.RolltheBones:IsCastable() and (RtB_BuffRemains() <= 3 or RtB_Reroll()) then
      if HR.CastPooling(S.RolltheBones) then return "Cast Roll the Bones" end
    end

    -- Placeholder Bone Spike
    if CDsON() and S.SerratedBoneSpike:IsCastable() and not Player:StealthUp(true, true) and Player:ComboPointsDeficit() > 1 then
      if not Target:DebuffUp(S.SerratedBoneSpikeDebuff) then
        if HR.Cast(S.SerratedBoneSpike) then return "Cast Serrated Bone Spike" end
      else
        if AoEON() then
          -- Prefer melee cycle units
          local BestUnit, BestUnitTTD = nil, 4
          local TargetGUID = Target:GUID()
          for _, CycleUnit in pairs(Enemies30y) do
            if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(S.SerratedBoneSpike))
            and not CycleUnit:DebuffUp(S.SerratedBoneSpikeDebuff) then
              BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
            end
          end
          if BestUnit then
            HR.CastLeftNameplate(BestUnit, S.SerratedBoneSpike)
          end
        end
        if S.SerratedBoneSpike:ChargesFractional() > 2.9 then
          if HR.Cast(S.SerratedBoneSpike) then return "Cast Serrated Bone Spike Filler" end
        end
      end
    end

    -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|buff.adrenaline_rush.up

    -- Trinkets
    if Settings.Commons.UseTrinkets and CDsON() then
      -- actions.cds+=/use_item,name=azsharas_font_of_power,if=!buff.adrenaline_rush.up&!buff.blade_flurry.up&cooldown.adrenaline_rush.remains<15
      if I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() and not Player:BuffUp(S.AdrenalineRush) and not Player:BuffUp(S.BladeFlurry) and S.AdrenalineRush:CooldownRemains() < 15 then
        if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast FontOfPower" end
      end
      -- if=!stealthed.all&buff.adrenaline_rush.down&buff.memory_of_lucid_dreams.down&energy.time_to_max>4&rtb_buffs<5
      if I.ComputationDevice:IsEquipped() and I.ComputationDevice:IsReady() and not Player:StealthUp(true, true)
        and not Player:BuffUp(S.AdrenalineRush) and not Player:BuffUp(S.LucidDreamsBuff) and EnergyTimeToMaxRounded() > 4 and RtB_Buffs() < 5 then
        if HR.Cast(I.ComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast ComputationDevice" end
      end
      -- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<32&target.health.pct>=30|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=20-10*debuff.blood_of_the_enemy.up|target.time_to_die<60)&buff.adrenaline_rush.remains>18
      if I.RazorCoral:IsEquipped() and I.RazorCoral:IsReady() then
        local CastRazorCoral
        if S.RazorCoralDebuff:AuraActiveCount() == 0 then
          CastRazorCoral = true
        else
          local ConductiveInkUnit = S.ConductiveInkDebuff:MaxDebuffStackUnit()
          if ConductiveInkUnit then
            -- Cast if we are at 31%, if the enemy will die within 20s, or if the time to reach 30% will happen within 3s
            CastRazorCoral = ConductiveInkUnit:HealthPercentage() <= 32 or HL.BossFilteredFightRemains("<", 20) or
              (ConductiveInkUnit:HealthPercentage() <= 35 and ConductiveInkUnit:TimeToX(30) < 3)
          else
            CastRazorCoral = (S.RazorCoralDebuff:MaxDebuffStack() >= 20 - 10 * num(Target:DebuffUp(S.BloodoftheEnemyDebuff)) or Target:FilteredTimeToDie("<", 60))
              and Player:BuffRemains(S.AdrenalineRush) > 18 or HL.BossFilteredFightRemains("<", 20)
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
      -- actions.cds+=/use_items,if=buff.bloodlust.react|fight_remains<=20|combo_points.deficit<=2
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse and (Player:BloodlustUp() or HL.BossFilteredFightRemains("<", 20) or Player:ComboPointsDeficit() <= 2) then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
      end
    end

    -- Racials
    if CDsON() then
      -- actions.cds+=/blood_fury
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
      end
      -- actions.cds+=/berserking
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
      end
      -- actions.cds+=/fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
      end
      -- actions.cds+=/ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
      end
    end
  end
end

local function Stealth ()
  if Target:IsSpellInRange(S.SinisterStrike) then
    -- actions.stealth=ambush
    if S.Ambush:IsCastable() then
      if HR.Cast(S.Ambush) then return "Cast Ambush" end
    end
  end
end

local function Finish ()
  -- # BtE over RtB rerolls with 2+ Deadshot traits or Ruthless Precision.
  -- actions.finish=between_the_eyes,if=variable.bte_condition
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) then
    if HR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (Pre RtB)" end
  end
  -- actions.finish=slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&buff.slice_and_dice.remains<(1+combo_points)*1.8
  -- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
  if S.SliceandDice:IsCastable() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
    and Player:BuffRemains(S.SliceandDice) < (1 + Player:ComboPoints()) * 1.8 then
    if HR.Cast(S.SliceandDice) then return "Cast Slice and Dice" end
  end
  -- # BtE with the Ace Up Your Sleeve or Deadshot traits.
  -- actions.finish+=/between_the_eyes,if=azerite.ace_up_your_sleeve.enabled|azerite.deadshot.enabled
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) and (S.AceUpYourSleeve:AzeriteEnabled() or S.Deadshot:AzeriteEnabled()) then
    if HR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes" end
  end
  -- actions.finish+=/dispatch
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
  -- OutofRange BtE
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) and not Target:IsInRange(10) then
    if HR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (OOR)" end
  end
end

local function Build ()
  -- actions.build=pistol_shot,if=buff.opportunity.up&(buff.keep_your_wits_about_you.stack<10|buff.deadshot.up|energy<45)
  if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and Player:BuffUp(S.Opportunity) and (Player:BuffStack(S.KeepYourWitsBuff) < 14 or Player:BuffUp(S.DeadshotBuff) or EnergyPredictedRounded() < 45) then
    if HR.Cast(S.PistolShot) then return "Cast Pistol Shot" end
  end
  -- actions.build+=/sinister_strike
  if S.SinisterStrike:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
    if HR.CastPooling(S.SinisterStrike) then return "Cast Sinister Strike" end
  end
end


--- ======= MAIN =======
local function APL ()
  -- Local Update
  BladeFlurryRange = S.AcrobaticStrikes:IsAvailable() and 9 or 6
  -- Unit Update
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Serrated Bone Spike cycle
    EnemiesBF = Player:GetEnemiesInRange(BladeFlurryRange)
    EnemiesBFCount = #EnemiesBF
  else
    EnemiesBFCount = 1
  end

  -- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial(S.CrimsonVial)
  if ShouldReturn then return ShouldReturn end
  -- Feint
  ShouldReturn = Rogue.Feint(S.Feint)
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  local PoisonRefreshTime = Player:AffectingCombat() and Settings.Assassination.PoisonRefreshCombat*60 or Settings.Assassination.PoisonRefresh*60
  -- Lethal Poison
  if Player:BuffRemains(S.InstantPoison) <= PoisonRefreshTime then
    HR.CastSuggested(S.InstantPoison)
  end
  -- Non-Lethal Poisons
  if (Player:BuffUp(S.CripplingPoison) and Player:BuffRemains(S.CripplingPoison) <= PoisonRefreshTime) or (Player:BuffUp(S.NumblingPoison) and Player:BuffRemains(S.NumblingPoison) <= PoisonRefreshTime) then
    if Player:BuffUp(S.NumblingPoison) then
      HR.CastSuggested(S.NumblingPoison)
    else
      HR.CastSuggested(S.CripplingPoison)
    end
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Precombat CDs
    if CDsON() then
      if Everyone.TargetIsValid() then
        if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
        local usingTrinket = false
        -- actions.precombat+=/use_item,name=azsharas_font_of_power
        if Settings.Commons.UseTrinkets and I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() then
          usingTrinket = true
          if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Font of Power" end
        end
        -- actions.precombat+=/use_item,effect_name=cyclotronic_blast,if=!raid_event.invulnerable.exists
        if Settings.Commons.UseTrinkets and I.ComputationDevice:IsEquipped() and I.ComputationDevice:IsReady() then
          usingTrinket = true
          if HR.Cast(I.ComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Computation Device" end
        end
      end
    end
    -- Stealth
    if not Player:BuffUp(S.VanishBuff) then
      ShouldReturn = Rogue.Stealth(S.Stealth)
      if ShouldReturn then return ShouldReturn end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() then
      if Player:ComboPoints() >= 5 then
        ShouldReturn = Finish()
        if ShouldReturn then return "Finish: " .. ShouldReturn end
      elseif Target:IsSpellInRange(S.SinisterStrike) then
        if Player:StealthUp(true, true) and S.Ambush:IsCastable() then
          if HR.Cast(S.Ambush) then return "Cast Ambush (Opener)" end
        elseif S.SinisterStrike:IsCastable() then
          if HR.Cast(S.SinisterStrike) then return "Cast Sinister Strike (Opener)" end
        end
      end
    end
    return
  end

  -- In Combat
  -- MfD Sniping
  Rogue.MfDSniping(S.MarkedforDeath)
  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- actions+=/call_action_list,name=stealth,if=stealthed.all
    if Player:StealthUp(true, true) then
      ShouldReturn = Stealth()
      if ShouldReturn then return "Stealth: " .. ShouldReturn end
    end
    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end
    -- actions+=/run_action_list,name=finish,if=combo_points>=cp_max_spend-(buff.broadside.up+buff.opportunity.up)*(talent.quick_draw.enabled&(!talent.marked_for_death.enabled|cooldown.marked_for_death.remains>1))*(azerite.ace_up_your_sleeve.rank<2|!cooldown.between_the_eyes.up|!buff.roll_the_bones.up)
    if Player:ComboPoints() >= Rogue.CPMaxSpend() - (num(Player:BuffUp(S.Broadside)) + num(Player:BuffUp(S.Opportunity))) * num(S.QuickDraw:IsAvailable() and (not S.MarkedforDeath:IsAvailable() or S.MarkedforDeath:CooldownRemains() > 1)) * num(S.AceUpYourSleeve:AzeriteRank() < 2 or not S.BetweentheEyes:CooldownUp() or RtB_Buffs() < 1) then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: " .. ShouldReturn end
      -- run_action_list forces the return
      return "Waiting to Finish..."
    end
    -- actions+=/call_action_list,name=build
    ShouldReturn = Build()
    if ShouldReturn then return "Build: " .. ShouldReturn end
    -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
    if S.ArcaneTorrent:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) and Player:EnergyDeficitPredicted() > 15 + Player:EnergyRegen() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
      if HR.Cast(S.ArcanePulse) then return "Cast Arcane Pulse" end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
    end
    -- actions+=/bag_of_tricks
    if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
    end
    -- OutofRange Pistol Shot
    if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and not Target:IsInRange(BladeFlurryRange) and not Player:StealthUp(true, true)
      and Player:EnergyDeficitPredicted() < 25 and (Player:ComboPointsDeficit() >= 1 or EnergyTimeToMaxRounded() <= 1.2) then
      if HR.Cast(S.PistolShot) then return "Cast Pistol Shot (OOR)" end
    end
  end
end

local function Init ()
  S.RazorCoralDebuff:RegisterAuraTracking()
  S.ConductiveInkDebuff:RegisterAuraTracking()
end

HR.SetAPL(260, APL, Init)

--- ======= SIMC =======
-- Last Update: 2020-03-09

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/marked_for_death,precombat_seconds=5,if=raid_event.adds.in>40
-- actions.precombat+=/stealth,if=(!equipped.pocketsized_computation_device|!cooldown.cyclotronic_blast.duration|raid_event.invulnerable.exists)
-- actions.precombat+=/roll_the_bones,precombat_seconds=2
-- actions.precombat+=/slice_and_dice,precombat_seconds=2
-- actions.precombat+=/adrenaline_rush,precombat_seconds=1,if=(!equipped.pocketsized_computation_device|!cooldown.cyclotronic_blast.duration|raid_event.invulnerable.exists)
-- actions.precombat+=/use_item,name=azsharas_font_of_power
-- actions.precombat+=/use_item,effect_name=cyclotronic_blast,if=!raid_event.invulnerable.exists

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Reroll for 2+ buffs with Loaded Dice up. Otherwise reroll for 2+ or Grand Melee or Ruthless Precision.
-- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(buff.loaded_dice.up|!buff.grand_melee.up&!buff.ruthless_precision.up)
-- # Reroll for 2+ buffs or Broadside with Deadshot.
-- actions+=/variable,name=rtb_reroll,op=set,if=azerite.deadshot.enabled,value=rtb_buffs<2&(buff.loaded_dice.up|!buff.broadside.up)
-- # Reroll for 2+ buffs or Ruthless Precision with Ace up your Sleeve, unless there are more Deadshot ranks.
-- actions+=/variable,name=rtb_reroll,op=set,if=azerite.ace_up_your_sleeve.enabled&azerite.ace_up_your_sleeve.rank>=azerite.deadshot.rank,value=rtb_buffs<2&(buff.loaded_dice.up|buff.ruthless_precision.remains<=cooldown.between_the_eyes.remains)
-- # 2+ Snake Eyes: Always reroll for 2+ buffs.
-- actions+=/variable,name=rtb_reroll,op=set,if=azerite.snake_eyes.rank>=2,value=rtb_buffs<2
-- # 2+ Snake Eyes: Do not reroll with 2+ stacks of the Snake Eyes buff (1+ stack with Broadside up).
-- actions+=/variable,name=rtb_reroll,op=reset,if=azerite.snake_eyes.rank>=2&buff.snake_eyes.stack>=2-buff.broadside.up
-- # With Blade Flurry up, ignore rules above and take everything that is 2+ (not counting SaC) or single BS, GM, RP
-- actions+=/variable,name=rtb_reroll,op=set,if=buff.blade_flurry.up,value=rtb_buffs-buff.skull_and_crossbones.up<2&(buff.loaded_dice.up|!buff.grand_melee.up&!buff.ruthless_precision.up&!buff.broadside.up)
-- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&cooldown.ghostly_strike.remains<1)+buff.broadside.up&energy>60&!buff.skull_and_crossbones.up&!buff.keep_your_wits_about_you.up
-- actions+=/variable,name=bte_condition,value=buff.ruthless_precision.up|(azerite.deadshot.enabled|azerite.ace_up_your_sleeve.enabled)&buff.roll_the_bones.up
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.up
-- actions+=/call_action_list,name=stealth,if=stealthed.all
-- actions+=/call_action_list,name=cds
-- # Finish at maximum CP. Substract one for each Broadside and Opportunity when Quick Draw is selected and MfD is not ready after the next second. Always max BtE with 2+ Ace.
-- actions+=/run_action_list,name=finish,if=combo_points>=cp_max_spend-(buff.broadside.up+buff.opportunity.up)*(talent.quick_draw.enabled&(!talent.marked_for_death.enabled|cooldown.marked_for_death.remains>1))*(azerite.ace_up_your_sleeve.rank<2|!cooldown.between_the_eyes.up|!buff.roll_the_bones.up)
-- actions+=/call_action_list,name=build
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Builders
-- # Use Pistol Shot if it won't cap combo points and the Oppotunity buff is up. Avoid using when Keep Your Wits stacks are high unless the Deadshot buff is also up.
-- actions.build=pistol_shot,if=buff.opportunity.up&(buff.keep_your_wits_about_you.stack<14|buff.deadshot.up|energy<45)
-- actions.build+=/sinister_strike

-- # Cooldowns
-- actions.cds=call_action_list,name=essences,if=!stealthed.all
-- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!equipped.azsharas_font_of_power|cooldown.latent_arcana.remains>20)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1
-- # Blade Flurry on 2+ enemies. With adds: Use if they stay for 8+ seconds or if your next charge will be ready in time for the next wave.
-- actions.cds+=/blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up&(!raid_event.adds.exists|raid_event.adds.remains>8|raid_event.adds.in>(2-cooldown.blade_flurry.charges_fractional)*25)
-- actions.cds+=/ghostly_strike,if=variable.blade_flurry_sync&combo_points.deficit>=1+buff.broadside.up
-- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&(energy.time_to_max>5|energy<15)
-- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&energy.time_to_max>1&(!buff.adrenaline_rush.up|energy<45)
-- # Using Vanish/Ambush is only a very tiny increase, so in reality, you're absolutely fine to use it as a utility spell.
-- actions.cds+=/vanish,if=!stealthed.all&variable.ambush_condition
-- actions.cds+=/shadowmeld,if=!stealthed.all&variable.ambush_condition
-- actions.cds+=/potion,if=buff.bloodlust.react|buff.adrenaline_rush.up
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/fireblood
-- actions.cds+=/ancestral_call
-- actions.cds+=/use_item,effect_name=cyclotronic_blast,if=!stealthed.all&buff.adrenaline_rush.down&buff.memory_of_lucid_dreams.down&energy.time_to_max>4&rtb_buffs<5
-- actions.cds+=/use_item,name=azsharas_font_of_power,if=!buff.adrenaline_rush.up&!buff.blade_flurry.up&cooldown.adrenaline_rush.remains<15
-- # Very roughly rule of thumbified maths below: Use for Inkpod crit, otherwise with AR at 20+ stacks or 10+ with also Blood up.
-- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.health.pct<32&target.health.pct>=30|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=20-10*debuff.blood_of_the_enemy.up|target.time_to_die<60)&buff.adrenaline_rush.remains>18
-- # Default fallback for usable items.
-- actions.cds+=/use_items,if=buff.bloodlust.react|target.time_to_die<=20|combo_points.deficit<=2

-- # Essences
-- actions.essences=concentrated_flame,if=energy.time_to_max>1&!buff.blade_flurry.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
-- actions.essences+=/blood_of_the_enemy,if=variable.blade_flurry_sync&cooldown.between_the_eyes.up&variable.bte_condition
-- actions.essences+=/guardian_of_azeroth
-- actions.essences+=/focused_azerite_beam,if=spell_targets.blade_flurry>=2|raid_event.adds.in>60&!buff.adrenaline_rush.up
-- actions.essences+=/purifying_blast,if=spell_targets.blade_flurry>=2|raid_event.adds.in>60
-- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
-- actions.essences+=/ripple_in_space
-- actions.essences+=/worldvein_resonance
-- actions.essences+=/memory_of_lucid_dreams,if=energy<45
-- actions.essences+=/reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30

-- # Finishers
-- # BtE over RtB rerolls with Deadshot/Ace traits or Ruthless Precision.
-- actions.finish=between_the_eyes,if=variable.bte_condition
-- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<target.time_to_die&buff.slice_and_dice.remains<(1+combo_points)*1.8
-- actions.finish+=/roll_the_bones,if=buff.roll_the_bones.remains<=3|variable.rtb_reroll
-- # BtE with the Ace Up Your Sleeve or Deadshot traits.
-- actions.finish+=/between_the_eyes,if=azerite.ace_up_your_sleeve.enabled|azerite.deadshot.enabled
-- actions.finish+=/dispatch

-- # Stealth
-- actions.stealth=ambush

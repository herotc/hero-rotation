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
  Commons2 = HR.GUISettings.APL.Rogue.Commons2,
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

-- Legendaries
local TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
local MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)

HL.RegisterForEvent(function()
  TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
  MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
end, "PLAYER_EQUIPMENT_CHANGED")

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
      -- # Reroll single BT/GM/TB buffs when possible
      -- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(buff.buried_treasure.up|buff.grand_melee.up|buff.true_bearing.up)
      Cache.APLVar.RtB_Reroll = (RtB_Buffs() < 2 and
        (Player:BuffUp(S.GrandMelee) or Player:BuffUp(S.BuriedTreasure) or Player:BuffUp(S.TrueBearing))) and true or false
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
  -- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+buff.broadside.up&energy>=50
  return Player:ComboPointsDeficit() >= 2 + num(Player:BuffUp(S.Broadside)) and EnergyPredictedRounded() > 50
end
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.up
local function Blade_Flurry_Sync ()
  return not AoEON() or EnemiesBFCount < 2 or Player:BuffUp(S.BladeFlurry)
end

local function CDs ()
  if Target:IsSpellInRange(S.SinisterStrike) then
    -- # Using Ambush is a 2% increase, so Vanish can be sometimes be used as a utility spell unless using Master Assassin or Deathly Shadows
    -- actions.cds=vanish,if=!stealthed.all&variable.ambush_condition&master_assassin_remains=0&buff.deathly_shadows.down
    if Settings.Outlaw.UseDPSVanish and CDsON() and S.Vanish:IsCastable()
      and not Player:StealthUp(true, true) and Ambush_Condition()
      and Rogue.MasterAssassinsMarkRemains() <= 0 and not Player:BuffUp(S.DeathlyShadowsBuff) then
      if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish" end
    end
    -- actions.cds+=/flagellation
    if CDsON() and S.Flagellation:IsReady() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.Flagellation) then return "Cast Flagellation" end
    end
    -- actions.cds+=/flagellation_cleanse,if=debuff.flagellation.remains<2
    if S.FlagellationCleanse:IsReady() and Target:DebuffUp(S.Flagellation) and Target:DebuffRemains(S.Flagellation) < 2 then
      if HR.Cast(S.FlagellationCleanse) then return "Cast Flagellation Cleanse" end
    end
    -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!cooldown.killing_spree.up|!talent.killing_spree.enabled)
    if CDsON() and S.AdrenalineRush:IsCastable() and not Player:BuffUp(S.AdrenalineRush)
      and (not S.KillingSpree:CooldownUp() or not S.KillingSpree:IsAvailable()) then
      if HR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush" end
    end
    -- actions.cds+=/roll_the_bones,if=buff.roll_the_bones.remains<=3|variable.rtb_reroll
    if S.RolltheBones:IsReady() and (Rogue.RtBRemains() <= 3 or RtB_Reroll()) then
      if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones" end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
    if S.MarkedforDeath:IsCastable() then
      -- Note: Increased the SimC condition by 50% since we are slower.
      if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()*1.5) or (Target:FilteredTimeToDie("<", 2) and Player:ComboPointsDeficit() > 0)
        or (((Player:BuffRemains(S.TrueBearing) > 15 - (Player:BuffUp(S.AdrenalineRush) and 5 or 0)) or Target:IsDummy())
          and not Player:StealthUp(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1) then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      elseif CDsON() and not Player:StealthUp(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1 then
        if Settings.Commons.STMfDAsDPSCD then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
        else
          HR.CastSuggested(S.MarkedforDeath)
        end
      end
    end
    if CDsON() then
      -- actions.cds+=/blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up
      if S.BladeFlurry:IsReady() and AoEON() and EnemiesBFCount >= 2 and not Player:BuffUp(S.BladeFlurry) then
        if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
          HR.CastSuggested(S.BladeFlurry)
        else
          if HR.Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
        end
      end
      -- actions.cds+=/ghostly_strike,if=combo_points.deficit>=1+buff.broadside.up
      if S.GhostlyStrike:IsReady() and Target:IsSpellInRange(S.GhostlyStrike) and Player:ComboPointsDeficit() >= (1 + (Player:BuffUp(S.Broadside) and 1 or 0)) then
        if HR.Cast(S.GhostlyStrike, Settings.Outlaw.GCDasOffGCD.GhostlyStrike) then return "Cast Ghostly Strike" end
      end
      if Blade_Flurry_Sync() then
        -- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&energy.time_to_max>2
        if S.KillingSpree:IsCastable() and Target:IsSpellInRange(S.KillingSpree) and EnergyTimeToMaxRounded() > 2 then
          if HR.Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle) then return "Cast Killing Spree" end
        end
        -- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&energy.time_to_max>2
        if S.BladeRush:IsCastable() and Target:IsSpellInRange(S.BladeRush) and EnergyTimeToMaxRounded() > 2 then
          if HR.Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush) then return "Cast Blade Rush" end
        end
      end
      -- actions.cds+=/shadowmeld,if=!stealthed.all&variable.ambush_condition
      if Settings.Outlaw.UseDPSVanish and S.Shadowmeld:IsCastable() and Ambush_Condition() then
        if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
      end
      -- actions.cds+=/dreadblades,if=!stealthed.all&combo_points<=1
      if S.Dreadblades:IsReady() and Target:IsSpellInRange(S.Dreadblades) and not Player:StealthUp(true, true) and Player:ComboPoints() < 2 then
        if HR.Cast(S.Dreadblades, Settings.Outlaw.GCDasOffGCD.Dreadblades) then return "Cast Dreadblades" end
      end
      -- actions.cds+=/sepsis,if=!stealthed.all
      if S.Sepsis:IsReady() and not Player:StealthUp(true, true) then
        if HR.Cast(S.Sepsis) then return "Cast Sepsis" end
      end
    end

    -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|buff.adrenaline_rush.up

    -- Trinkets
    if Settings.Commons.UseTrinkets and CDsON() then
      -- actions.cds+=/use_items,if=buff.bloodlust.react|fight_remains<=20|combo_points.deficit<=2
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
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
  if Target:IsSpellInRange(S.Ambush) then
    -- actions.stealth=ambush
    if S.Ambush:IsCastable() then
      if HR.CastPooling(S.Ambush) then return "Cast Ambush" end
    end
  end
end

local function Finish ()
  -- # BtE on cooldown to keep the Crit debuff up
  -- actions.finish=between_the_eyes
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) then
    if HR.CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
  end
  -- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&buff.slice_and_dice.remains<(1+combo_points)*1.8
  -- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
  if S.SliceandDice:IsCastable() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
    and Player:BuffRemains(S.SliceandDice) < (1 + Player:ComboPoints()) * 1.8 then
    if HR.CastPooling(S.SliceandDice) then return "Cast Slice and Dice" end
  end
  -- actions.finish+=/dispatch
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
end

local function Build ()
  -- actions.build=shiv,if=runeforge.tiny_toxic_blade.equipped
  if S.Shiv:IsReady() and TinyToxicBladeEquipped then
    if HR.Cast(S.Shiv) then return "Cast Shiv (TTB)" end
  end
  -- actions.build+=/echoing_reprimand
  if CDsON() and S.EchoingReprimand:IsReady() and Target:IsInMeleeRange(5) then
    if HR.Cast(S.EchoingReprimand) then return "Cast Echoing Reprimand" end
  end
  -- actions.build+=/serrated_bone_spike,cycle_targets=1,if=buff.slice_and_dice.up&!dot.serrated_bone_spike_dot.ticking|fight_remains<=5|cooldown.serrated_bone_spike.charges_fractional>=2.75
  if CDsON() and S.SerratedBoneSpike:IsReady() then
    if (Player:BuffUp(S.SliceandDice) and not Target:DebuffUp(S.SerratedBoneSpikeDot)) or HL.BossFilteredFightRemains("<", 5) then
      if HR.Cast(S.SerratedBoneSpike) then return "Cast Serrated Bone Spike" end
    end
    if AoEON() then
      -- Prefer melee cycle units
      local BestUnit, BestUnitTTD = nil, 4
      local TargetGUID = Target:GUID()
      for _, CycleUnit in pairs(Enemies30y) do
        if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(S.SerratedBoneSpike))
        and not CycleUnit:DebuffUp(S.SerratedBoneSpikeDot) then
          BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
        end
      end
      if BestUnit then
        HR.CastLeftNameplate(BestUnit, S.SerratedBoneSpike)
      end
    end
    if S.SerratedBoneSpike:ChargesFractional() > 2.75 then
      if HR.Cast(S.SerratedBoneSpike) then return "Cast Serrated Bone Spike Filler" end
    end
  end
  if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and Player:BuffUp(S.Opportunity) then
    -- actions.build+=/pistol_shot,if=buff.opportunity.up&(energy<45|talent.quick_draw.enabled)
    if EnergyPredictedRounded() < 45 or S.QuickDraw:IsAvailable() then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
    end
    -- actions.build+=/pistol_shot,if=buff.opportunity.up&(buff.greenskins_wickers.up|buff.concealed_blunderbuss.up)
    if Player:BuffUp(S.GreenskinsWickers) or Player:BuffUp(S.ConcealedBlunderbuss) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (Buffed)" end
    end
  end
  -- actions.build+=/sinister_strike
  if S.SinisterStrike:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
    if HR.CastPooling(S.SinisterStrike) then return "Cast Sinister Strike" end
  end
  -- actions.build+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1+buff.broadside.up
  -- TODO
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
  ShouldReturn = Rogue.CrimsonVial()
  if ShouldReturn then return ShouldReturn end
  -- Feint
  ShouldReturn = Rogue.Feint()
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  Rogue.Poisons()

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Precombat CDs
    if Everyone.TargetIsValid() then
      if CDsON() and S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
        if Settings.Commons.STMfDAsDPSCD then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        else
          if HR.CastSuggested(S.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
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
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons2.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- actions+=/call_action_list,name=stealth,if=stealthed.all
    if Player:StealthUp(true, true) then
      ShouldReturn = Stealth()
      if ShouldReturn then return "Stealth: " .. ShouldReturn end
    end
    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end
    -- actions+=/run_action_list,name=finish,if=combo_points>=cp_max_spend-buff.broadside.up-(buff.opportunity.up*talent.quick_draw.enabled)|combo_points=animacharged_cp
    if Player:ComboPoints() >= (Rogue.CPMaxSpend() - num(Player:BuffUp(S.Broadside)) - (num(Player:BuffUp(S.Opportunity)) * num(S.QuickDraw:IsAvailable())))
      or Player:ComboPoints() == Rogue.AnimachargedCP() then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: " .. ShouldReturn end
      -- run_action_list forces the return
      HR.Cast(S.PoolEnergy)
      return "Finish Pooling"
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
-- Last Update: 2020-12-05

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/marked_for_death,precombat_seconds=5,if=raid_event.adds.in>40
-- actions.precombat+=/stealth,if=raid_event.invulnerable.exists
-- actions.precombat+=/roll_the_bones,precombat_seconds=1
-- actions.precombat+=/slice_and_dice,precombat_seconds=2

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Reroll single BT/GM/TB buffs when possible
-- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(buff.buried_treasure.up|buff.grand_melee.up|buff.true_bearing.up)
-- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+buff.broadside.up&energy>=50
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.up
-- actions+=/call_action_list,name=stealth,if=stealthed.all
-- actions+=/call_action_list,name=cds
-- # Finish at maximum CP but avoid wasting Broadside and Quick Draw bonus combo points
-- actions+=/run_action_list,name=finish,if=combo_points>=cp_max_spend-buff.broadside.up-(buff.opportunity.up*talent.quick_draw.enabled)|combo_points=animacharged_cp
-- actions+=/call_action_list,name=build
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Builders
-- actions.build=shiv,if=runeforge.tiny_toxic_blade
-- actions.build+=/echoing_reprimand
-- actions.build+=/serrated_bone_spike,cycle_targets=1,if=buff.slice_and_dice.up&!dot.serrated_bone_spike_dot.ticking|fight_remains<=5|cooldown.serrated_bone_spike.charges_fractional>=2.75
-- # Use Pistol Shot with Opportunity if below 45 energy, or when using Quick Draw
-- actions.build+=/pistol_shot,if=buff.opportunity.up&(energy<45|talent.quick_draw.enabled)
-- actions.build+=/pistol_shot,if=buff.opportunity.up&(buff.greenskins_wickers.up|buff.concealed_blunderbuss.up)
-- actions.build+=/sinister_strike
-- actions.build+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1+buff.broadside.up

-- # Cooldowns
-- # Using Ambush is a 2% increase, so Vanish can be sometimes be used as a utility spell unless using Master Assassin or Deathly Shadows
-- actions.cds=vanish,if=!stealthed.all&variable.ambush_condition&master_assassin_remains=0&buff.deathly_shadows.down
-- actions.cds+=/flagellation
-- actions.cds+=/flagellation_cleanse,if=debuff.flagellation.remains<2
-- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!cooldown.killing_spree.up|!talent.killing_spree.enabled)
-- actions.cds+=/roll_the_bones,if=buff.roll_the_bones.remains<=3|variable.rtb_reroll
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1
-- # Blade Flurry on 2+ enemies
-- actions.cds+=/blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up
-- actions.cds+=/ghostly_strike,if=combo_points.deficit>=1+buff.broadside.up
-- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&energy.time_to_max>2
-- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&energy.time_to_max>2
-- actions.cds+=/dreadblades,if=!stealthed.all&combo_points<=1
-- actions.cds+=/shadowmeld,if=!stealthed.all&variable.ambush_condition
-- actions.cds+=/sepsis,if=!stealthed.all
-- actions.cds+=/potion,if=buff.bloodlust.react|buff.adrenaline_rush.up
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/fireblood
-- actions.cds+=/ancestral_call
-- # Default fallback for usable items.
-- actions.cds+=/use_items,if=buff.bloodlust.react|fight_remains<=20|combo_points.deficit<=2

-- # Finishers
-- # BtE on cooldown to keep the Crit debuff up
-- actions.finish=between_the_eyes
-- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&buff.slice_and_dice.remains<(1+combo_points)*1.8
-- actions.finish+=/dispatch

-- # Stealth
-- actions.stealth=cheap_shot,target_if=min:debuff.prey_on_the_weak.remains,if=talent.prey_on_the_weak.enabled&!target.is_boss
-- actions.stealth+=/ambush

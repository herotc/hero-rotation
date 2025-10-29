--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local Item          = HL.Item
local Action        = HL.Action
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastSuggested = HR.CastSuggested
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- WoW API
local Delay         = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Hunter.BeastMastery
local I = Item.Hunter.BeastMastery

-- Define array of summon_pet spells
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.ItemName:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Hunter = HR.Commons.Hunter
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  CommonsDS = HR.GUISettings.APL.Hunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Hunter.CommonsOGCD,
  BeastMastery = HR.GUISettings.APL.Hunter.BeastMastery
}

--- ===== Rotation Variables =====
local BossFightRemains = 11111
local FightRemains = 11111
local TWW3_2pc = Player:HasTier("TWW3", 2)
local TWW3_4pc = Player:HasTier("TWW3", 4)
local CotWCD = (Player:HeroTreeID() == 44 and TWW3_2pc) and 60 or 120
local Enemies40y, PetEnemiesMixed, PetEnemiesMixedCount
local TargetInRange40y, TargetInRange30y
local TargetInRangePet30y

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarStrongerTrinketSlot
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  -- variable,name=stronger_trinket_slot,op=setif,value=1,value_else=2,condition=!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration)|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))
  VarStrongerTrinketSlot = 2
  if not Trinket2:HasCooldown() or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD)) then
    VarStrongerTrinketSlot = 1
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end },
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  TWW3_2pc = Player:HasTier("TWW3", 2)
  TWW3_4pc = Player:HasTier("TWW3", 4)
  CotWCD = (Player:HeroTreeID() == 44 and TWW3_2pc) and 60 or 120
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  -- Note: Swapping talent trees can have a slight delay before the API returns proper values.
  Delay(2, function()
      CotWCD = (Player:HeroTreeID() == 44 and TWW3_2pc) and 60 or 120
    end
  )
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function HowlSummonReady()
  return Player:BuffUp(S.HowlBearBuff) or Player:BuffUp(S.HowlBoarBuff) or Player:BuffUp(S.HowlWyvernBuff)
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBarbedShot(TargetUnit)
  -- target_if=min:dot.barbed_shot.remains
  return (TargetUnit:DebuffRemains(S.BarbedShotDebuff))
end

local function EvaluateTargetIfFilterKillCommand(TargetUnit)
  -- target_if=max:(target.health.pct<35|!talent.killer_instinct)*2+dot.a_murder_of_crows.refreshable
  return num(TargetUnit:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable()) * 2 + num(TargetUnit:DebuffRefreshable(S.AMurderofCrows))
end

local function EvaluateTargetIfFilterSerpentSting(TargetUnit)
  -- target_if=min:dot.serpent_sting.remains
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff))
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfKillShotST(TargetUnit)
  -- if=talent.venoms_bite&(!active_dot.serpent_sting|dot.serpent_sting.refreshable)
  -- Note: venoms_bite handled before CastTargetIf.
  return S.SerpentStingDebuff:AuraActiveCount() == 0 or TargetUnit:DebuffRefreshable(S.SerpentStingDebuff)
end

local function EvaluateTargetIfBarbedShotST(TargetUnit)
  -- if=talent.wild_call&charges_fractional>1.4|buff.call_of_the_wild.up|full_recharge_time<gcd&cooldown.bestial_wrath.remains|talent.scent_of_blood&(cooldown.bestial_wrath.remains<12+gcd)|talent.furious_assault|talent.black_arrow&(talent.barbed_scales|talent.savagery)|fight_remains<9
  return (S.WildCall:IsAvailable() and S.BarbedShot:ChargesFractional() > 1.4 or Player:BuffUp(S.CalloftheWildBuff) or S.BarbedShot:FullRechargeTime() < Player:GCD() and S.BestialWrath:CooldownDown() or S.ScentofBlood:IsAvailable() and (S.BestialWrath:CooldownRemains() < 12 + Player:GCD()) or S.FuriousAssault:IsAvailable() or S.BlackArrow:IsAvailable() and (S.BarbedScales:IsAvailable() or S.Savagery:IsAvailable()) or BossFightRemains < 9)
end

local function EvaluateTargetIfBlackArrowST(TargetUnit)
  -- if=talent.venoms_bite&dot.serpent_sting.refreshable
  return TargetUnit:DebuffRefreshable(S.SerpentStingDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- summon_pet
  -- Handled in APL()
  -- snapshot_stats
  -- variable,name=stronger_trinket_slot,op=setif,value=1,value_else=2,condition=!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration)|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- Manually added opener abilities
  -- hunters_mark,if=debuff.hunters_mark.down
  if S.HuntersMark:IsCastable() and (Target:DebuffDown(S.HuntersMarkDebuff, true)) then
    if Cast(S.HuntersMark, Settings.CommonsOGCD.GCDasOffGCD.HuntersMark) then return "hunters_mark precombat 2"; end
  end
  -- barbed_shot
  if S.BarbedShot:IsCastable() and S.BarbedShot:Charges() >= 2 then
    if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot precombat 8"; end
  end
end

local function CDs()
  -- invoke_external_buff,name=power_infusion,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains<30)|fight_remains<16
  -- Note: Not handling external buffs.
  if CDsON() then
    -- berserking,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<13
    if S.Berserking:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 13) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
    end
    -- blood_fury,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<16
    if S.BloodFury:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 16) then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
    end
    -- ancestral_call,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<16
    if S.AncestralCall:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 16) then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 10"; end
    end
    -- fireblood,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<9
    if S.Fireblood:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 9) then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 12"; end
    end
  end
  -- potion,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<31
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or BossFightRemains < 31) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 14"; end
    end
  end
end

local function DRCleave()
  -- kill_shot
  if S.BlackArrow:IsReady() then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "kill_shot dr_cleave 2"; end
  end
  -- bestial_wrath,if=cooldown.call_of_the_wild.remains>20|!talent.call_of_the_wild
  if CDsON() and S.BestialWrath:IsCastable() and (S.CalloftheWild:CooldownRemains() > 20 or not S.CalloftheWild:IsAvailable()) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath dr_cleave 4"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd|buff.thrill_of_the_hunt.remains<1.5*gcd
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or Player:BuffRemains(S.ThrilloftheHuntBuff) < Player:GCD() * 1.5) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_cleave 6"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed dr_cleave 8"; end
  end
  -- multishot,if=pet.main.buff.beast_cleave.down&(!talent.bloody_frenzy|cooldown.call_of_the_wild.remains)
  if S.MultiShot:IsReady() and (Pet:BuffDown(S.BeastCleavePetBuff) and (not S.BloodyFrenzy:IsAvailable() or S.CalloftheWild:CooldownDown())) then
    if Cast(S.MultiShot, nil, nil, not Target:IsSpellInRange(S.MultiShot)) then return "multishot dr_cleave 10"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild dr_cleave 12"; end
  end
  -- explosive_shot,if=talent.thundering_hooves
  if S.ExplosiveShot:IsReady() and (S.ThunderingHooves:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_cleave 14"; end
  end
  if not Settings.BeastMastery.BypassWitheringFireChecks then
    -- Localize buff.withering_fire.tick_time_remains
    local WFTTR = 999
    if Player:BuffUp(S.WitheringFireBuff) then
      WFTTR = 4 - S.BlackArrow:TimeSinceLastCast()
    end
    -- kill_command,if=buff.withering_fire.tick_time_remains>gcd&buff.withering_fire.tick_time_remains<3|buff.withering_fire.down
    if S.KillCommand:IsReady() and (WFTTR > Player:GCD() and WFTTR < 3 or Player:BuffDown(S.WitheringFireBuff)) then
      if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command dr_cleave 16"; end
    end
    -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=buff.withering_fire.tick_time_remains>0.5&buff.withering_fire.tick_time_remains<3|buff.withering_fire.down
    if S.BarbedShot:IsCastable() and (WFTTR > 0.5 and WFTTR < 3 or Player:BuffDown(S.WitheringFireBuff)) then
      if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_cleave 18"; end
    end
  else
    -- Simplified version, if bypass setting is enabled.
    if S.KillCommand:IsReady() then
      if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command dr_cleave 20"; end
    end
    if S.BarbedShot:IsCastable() then
      if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_cleave 22"; end
    end
  end
  -- cobra_shot,if=buff.withering_fire.down&focus.time_to_max<gcd*2
  if S.CobraShot:IsReady() and (Player:BuffDown(S.WitheringFireBuff) and Player:FocusTimeToMax() < Player:GCD() * 2) then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot dr_cleave 24"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot dr_cleave 26"; end
  end
end

local function DRST()
  -- kill_shot
  if S.BlackArrow:IsReady() then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "kill_shot dr_st 2"; end
  end
  -- bestial_wrath,if=cooldown.call_of_the_wild.remains>30|!talent.call_of_the_wild|time_to_die.remains<cooldown.call_of_the_wild.remains
  if CDsON() and S.BestialWrath:IsCastable() and (S.CalloftheWild:CooldownRemains() > 30 or not S.CalloftheWild:IsAvailable() or Target:TimeToDie() < S.CalloftheWild:CooldownRemains()) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath dr_st 4"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed dr_st 6"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild dr_st 8"; end
  end
  if not Settings.BeastMastery.BypassWitheringFireChecks then
    -- Localize buff.withering_fire.tick_time_remains
    local WFTTR = 999
    if Player:BuffUp(S.WitheringFireBuff) then
      WFTTR = 4 - S.BlackArrow:TimeSinceLastCast()
    end
    -- kill_command,if=buff.withering_fire.tick_time_remains>gcd&buff.withering_fire.tick_time_remains<3|buff.withering_fire.down
    if S.KillCommand:IsReady() and (WFTTR > Player:GCD() and WFTTR < 3 or Player:BuffDown(S.WitheringFireBuff)) then
      if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command dr_st 10"; end
    end
    -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=buff.withering_fire.tick_time_remains>0.5&buff.withering_fire.tick_time_remains<3|buff.withering_fire.down
    -- Note: ST function, so only using Cast instead of CastTargetIf.
    if S.BarbedShot:IsCastable() and (WFTTR > 0.5 and WFTTR < 3 or Player:BuffDown(S.WitheringFireBuff)) then
      if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_st 12"; end
    end
    -- cobra_shot,if=buff.withering_fire.down
    if S.CobraShot:IsReady() and (Player:BuffDown(S.WitheringFireBuff)) then
      if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot dr_st 14"; end
    end
  else
    -- Simplified version, if bypass setting is enabled.
    if S.BarbedShot:IsCastable() and (Player:BuffRemains(S.ThrilloftheHuntBuff) < Player:GCD() * 1.5) then
      if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_st 16"; end
    end
    if S.KillCommand:IsReady() then
      if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command dr_st 18"; end
    end
    if S.BarbedShot:IsCastable() then
      if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot dr_st 20"; end
    end
    if S.CobraShot:IsReady() then
      if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot dr_st 22"; end
    end
  end
end

local function Cleave()
  -- bestial_wrath,if=buff.howl_of_the_pack_leader_cooldown.remains-buff.lead_from_the_front.duration<buff.lead_from_the_front.duration%gcd*0.5|!set_bonus.tww3_4pc|talent.multishot
  if CDsON() and S.BestialWrath:IsCastable() and (Player:BuffRemains(S.HowlofthePackLeaderCDBuff) - 12 < 12 / Player:GCD() * 0.5 or not Player:HasTier("TWW3", 4) or S.MultiShot:IsAvailable()) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath cleave 2"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd|charges_fractional>=cooldown.kill_command.charges_fractional|talent.call_of_the_wild&cooldown.call_of_the_wild.ready|howl_summon.ready&full_recharge_time<8
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or S.BarbedShot:ChargesFractional() >= S.KillCommand:ChargesFractional() or S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp() or HowlSummonReady() and S.BarbedShot:FullRechargeTime() < 8) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 4"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed cleave 6"; end
  end
  -- multishot,if=pet.main.buff.beast_cleave.down&(!talent.bloody_frenzy|cooldown.call_of_the_wild.remains)
  if S.MultiShot:IsReady() and (Pet:BuffDown(S.BeastCleavePetBuff) and (not S.BloodyFrenzy:IsAvailable() or S.CalloftheWild:CooldownDown() or not CDsON())) then
    if Cast(S.MultiShot, nil, nil, not Target:IsSpellInRange(S.MultiShot)) then return "multishot cleave 8"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild cleave 10"; end
  end
  -- explosive_shot,if=talent.thundering_hooves
  if S.ExplosiveShot:IsReady() and (S.ThunderingHooves:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot cleave 12"; end
  end
  -- kill_command
  if S.KillCommand:IsReady() then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command cleave 14"; end
  end
  -- cobra_shot,if=focus.time_to_max<gcd*2|buff.hogstrider.stack>3|!talent.multishot
  if S.CobraShot:IsReady() and (Player:FocusTimeToMax() < Player:GCD() * 2 or Player:BuffStack(S.HogstriderBuff) > 3 or not S.MultiShot:IsAvailable()) then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot cleave 16"; end
  end
end

local function ST()
  -- bestial_wrath,if=buff.howl_of_the_pack_leader_cooldown.remains-buff.lead_from_the_front.duration<buff.lead_from_the_front.duration%gcd*0.5|!set_bonus.tww3_4pc
  if CDsON() and S.BestialWrath:IsCastable() and (Player:BuffRemains(S.HowlofthePackLeaderCDBuff) - 12 < 12 / Player:GCD() * 0.5 or not Player:HasTier("TWW3", 4)) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath st 2"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD()) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 4"; end
  end
  -- Main Target backup
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD()) then
    if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st mt_backup 6"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild st 8"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed st 10"; end
  end
  -- kill_command,if=charges_fractional>=cooldown.barbed_shot.charges_fractional&!(buff.lead_from_the_front.remains>gcd&buff.lead_from_the_front.remains<gcd*2&!howl_summon.ready&full_recharge_time>gcd)
  if S.KillCommand:IsReady() and (S.KillCommand:ChargesFractional() >= S.BarbedShot:ChargesFractional() and not (Player:BuffRemains(S.LeadFromTheFrontBuff) > Player:GCD() and Player:BuffRemains(S.LeadFromTheFrontBuff) < Player:GCD() * 2 + 0.5 and not HowlSummonReady() and S.KillCommand:FullRechargeTime() > Player:GCD())) then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 12"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 14"; end
  end
  -- cobra_shot
  if S.CobraShot:IsReady() then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot st 16"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    local VarQuiver, VarBW
    -- variable,name=quiver_variable,op=set,value=0,if=cooldown.call_of_the_wild.remains<30
    -- variable,name=quiver_variable,op=set,value=1,if=buff.blighted_quiver.stack>5&buff.latent_energy.stack>10|equipped.arazs_ritual_forge&(buff.blighted_quiver.stack>5|buff.latent_energy.stack>10)|buff.latent_energy.stack>16|fight_remains<(cooldown.call_of_the_wild.duration+20)
    if S.CalloftheWild:CooldownRemains() < 30 then
      VarQuiver = false
    elseif Player:BuffStack(S.BlightedQuiverBuff) > 5 and Player:BuffStack(S.LatentEnergyBuff) > 10 or I.ArazsRitualForge:IsEquipped() and (Player:BuffStack(S.BlightedQuiverBuff) > 5 or Player:BuffStack(S.LatentEnergyBuff) > 10) or Player:BuffStack(S.LatentEnergyBuff) > 16 or FightRemains < (CotWCD + 20) then
      VarQuiver = true
    end
    -- variable,name=bw_variable,op=set,value=0,if=!buff.bestial_wrath.up
    -- variable,name=bw_variable,op=set,value=1,if=!talent.call_of_the_wild&buff.bestial_wrath.up&(buff.latent_energy.stack>0|equipped.arazs_ritual_forge&buff.latent_energy.stack>10)
    if Player:BuffDown(S.BestialWrathBuff) then
      VarBW = false
    elseif not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) and (Player:BuffUp(S.LatentEnergyBuff) or I.ArazsRitualForge:IsEquipped() and Player:BuffStack(S.LatentEnergyBuff) > 10) then
      VarBW = true
    end
    local T1Check = Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1)
    local T2Check = Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2)
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!equipped.unyielding_netherprism&this_trinket.has_use_buff&(this_trinket.cooldown.duration%%cooldown.call_of_the_wild.duration=0&buff.call_of_the_wild.remains>14|!talent.call_of_the_wild&(other_trinket.has_use_buff|prev_gcd.1.bestial_wrath))
    if T1Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket1:HasUseBuff() and (VarTrinket1CD % CotWCD == 0 and Player:BuffRemains(S.CalloftheWildBuff) > 14 or not S.CalloftheWild:IsAvailable() and (Trinket2:HasUseBuff() or Player:PrevGCD(1, S.BestialWrath)))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 2"; end
    end
    if T2Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket2:HasUseBuff() and (VarTrinket2CD % CotWCD == 0 and Player:BuffRemains(S.CalloftheWildBuff) > 14 or not S.CalloftheWild:IsAvailable() and (Trinket1:HasUseBuff() or Player:PrevGCD(1, S.BestialWrath)))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 4"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!equipped.unyielding_netherprism&this_trinket.has_use_buff&(other_trinket.cooldown.duration%%cooldown.call_of_the_wild.duration=0&(buff.call_of_the_wild.remains>14&other_trinket.cooldown.remains|cooldown.call_of_the_wild.remains>20&other_trinket.cooldown.remains<=cooldown.call_of_the_wild.remains)|!talent.call_of_the_wild&other_trinket.cooldown.remains)
    if T1Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket1:HasUseBuff() and (VarTrinket2CD % CotWCD == 0 and (Player:BuffRemains(S.CalloftheWildBuff) > 14 and Trinket2:CooldownDown() or S.CalloftheWild:CooldownRemains() > 20 and Trinket2:CooldownRemains() <= S.CalloftheWild:CooldownRemains()) or not S.CalloftheWild:IsAvailable() and Trinket2:CooldownDown())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 6"; end
    end
    if T2Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket2:HasUseBuff() and (VarTrinket1CD % CotWCD == 0 and (Player:BuffRemains(S.CalloftheWildBuff) > 14 and Trinket1:CooldownDown() or S.CalloftheWild:CooldownRemains() > 20 and Trinket1:CooldownRemains() <= S.CalloftheWild:CooldownRemains()) or not S.CalloftheWild:IsAvailable() and Trinket1:CooldownDown())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 8"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!equipped.arazs_ritual_forge&this_trinket.is.unyielding_netherprism&(variable.quiver_variable&prev_gcd.1.call_of_the_wild|fight_remains<22&(buff.latent_energy.stack>8|!other_trinket.has_use_buff|other_trinket.cooldown.remains)|variable.bw_variable&prev_gcd.1.bestial_wrath)
    if T1Check and (not I.ArazsRitualForge:IsEquipped() and Trinket1:ID() == I.UnyieldingNetherprism:ID() and (VarQuiver and Player:PrevGCD(1, S.CalloftheWild) or BossFightRemains < 22 and (Player:BuffStack(S.LatentEnergyBuff) > 8 or not Trinket2:HasUseBuff() or Trinket2:CooldownDown()) or VarBW and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 10"; end
    end
    if T2Check and (not I.ArazsRitualForge:IsEquipped() and Trinket2:ID() == I.UnyieldingNetherprism:ID() and (VarQuiver and Player:PrevGCD(1, S.CalloftheWild) or BossFightRemains < 22 and (Player:BuffStack(S.LatentEnergyBuff) > 8 or not Trinket1:HasUseBuff() or Trinket1:CooldownDown()) or VarBW and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 12"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!this_trinket.is.unyielding_netherprism&this_trinket.has_use_buff&(other_trinket.is.unyielding_netherprism&fight_remains<cooldown.call_of_the_wild.remains+cooldown.call_of_the_wild.duration+10&cooldown.call_of_the_wild.remains>20|buff.call_of_the_wild.remains>14|buff.call_of_the_wild.up&fight_remains<cooldown.call_of_the_wild.remains+15|fight_remains<42|!talent.call_of_the_wild&prev_gcd.1.bestial_wrath)
    if T1Check and (VarTrinket1ID ~= I.UnyieldingNetherprism:ID() and Trinket1:HasUseBuff() and (VarTrinket2ID == I.UnyieldingNetherprism:ID() and FightRemains < S.CalloftheWild:CooldownRemains() + CotWCD + 10 and S.CalloftheWild:CooldownRemains() > 20 or Player:BuffRemains(S.CalloftheWildBuff) > 14 or Player:BuffUp(S.CalloftheWildBuff) and BossFightRemains < S.CalloftheWild:CooldownRemains() + 15 or BossFightRemains < 42 or not S.CalloftheWild:IsAvailable() and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 14"; end
    end
    if T2Check and (VarTrinket2ID ~= I.UnyieldingNetherprism:ID() and Trinket2:HasUseBuff() and (VarTrinket1ID == I.UnyieldingNetherprism:ID() and FightRemains < S.CalloftheWild:CooldownRemains() + CotWCD + 10 and S.CalloftheWild:CooldownRemains() > 20 or Player:BuffRemains(S.CalloftheWildBuff) > 14 or Player:BuffUp(S.CalloftheWildBuff) and BossFightRemains < S.CalloftheWild:CooldownRemains() + 15 or BossFightRemains < 42 or not S.CalloftheWild:IsAvailable() and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 16"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=this_trinket.is.unyielding_netherprism&(variable.quiver_variable&prev_gcd.1.call_of_the_wild|fight_remains<22&(buff.latent_energy.stack>8|!other_trinket.has_use_buff|other_trinket.cooldown.remains)|variable.bw_variable&prev_gcd.1.bestial_wrath)
    if T1Check and (VarTrinket1ID == I.UnyieldingNetherprism:ID() and (VarQuiver and Player:PrevGCD(1, S.CalloftheWild) or BossFightRemains < 22 and (Player:BuffStack(S.LatentEnergyBuff) > 8 or not Trinket2:HasUseBuff() or Trinket2:CooldownDown()) or VarBW and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 18"; end
    end
    if T2Check and (VarTrinket2ID == I.UnyieldingNetherprism:ID() and (VarQuiver and Player:PrevGCD(1, S.CalloftheWild) or BossFightRemains < 22 and (Player:BuffStack(S.LatentEnergyBuff) > 8 or not Trinket1:HasUseBuff() or Trinket1:CooldownDown()) or VarBW and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 20"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!equipped.arazs_ritual_forge&other_trinket.has_use_buff&this_trinket.is.unyielding_netherprism&(buff.call_of_the_wild.remains>14|!talent.call_of_the_wild&buff.bestial_wrath.remains>14)&buff.latent_energy.stack>3&(buff.latent_energy.stack+floor((fight_remains-20)%cooldown.call_of_the_wild.duration)*(cooldown.call_of_the_wild.duration%10))>17
    if T1Check and (not I.ArazsRitualForge:IsEquipped() and Trinket2:HasUseBuff() and VarTrinket1ID == I.UnyieldingNetherprism:ID() and (Player:BuffRemains(S.CalloftheWildBuff) > 14 or not S.CalloftheWild:IsAvailable() and Player:BuffRemains(S.BestialWrathBuff) > 14) and Player:BuffStack(S.LatentEnergyBuff) > 3 and (Player:BuffStack(S.LatentEnergyBuff) + mathfloor((FightRemains - 20) / CotWCD) * (CotWCD / 10)) > 17) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 22"; end
    end
    if T2Check and (not I.ArazsRitualForge:IsEquipped() and Trinket1:HasUseBuff() and VarTrinket2ID == I.UnyieldingNetherprism:ID() and (Player:BuffRemains(S.CalloftheWildBuff) > 14 or not S.CalloftheWild:IsAvailable() and Player:BuffRemains(S.BestialWrathBuff) > 14) and Player:BuffStack(S.LatentEnergyBuff) > 3 and (Player:BuffStack(S.LatentEnergyBuff) + mathfloor((FightRemains - 20) / CotWCD) * (CotWCD / 10)) > 17) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 24"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=this_trinket.has_use_damage&(cooldown.call_of_the_wild.remains>20|!talent.call_of_the_wild&prev_gcd.1.bestial_wrath)
    if T1Check and (Trinket1:HasUseDamage() and (S.CalloftheWild:CooldownRemains() > 20 or not S.CalloftheWild:IsAvailable() and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 26"; end
    end
    if T2Check and (Trinket2:HasUseDamage() and (S.CalloftheWild:CooldownRemains() > 20 or not S.CalloftheWild:IsAvailable() and Player:PrevGCD(1, S.BestialWrath))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 28"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- Manually added: use_items for non-trinkets
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 30"; end
    end
  end
end

--- ======= MAIN =======
local function APL()
  -- HeroLib SplashData Tracking Update (used as fallback if pet abilities are not in action bars)
  if S.Stomp:IsAvailable() then
    HL.SplashEnemies.ChangeFriendTargetsTracking("Mine Only")
  else
    HL.SplashEnemies.ChangeFriendTargetsTracking("All")
  end

  -- Enemies Update
  local PetCleaveAbility = (S.BloodBolt:IsPetKnown() and Action.FindBySpellID(S.BloodBolt:ID()) and S.BloodBolt)
    or (S.Bite:IsPetKnown() and Action.FindBySpellID(S.Bite:ID()) and S.Bite)
    or (S.Claw:IsPetKnown() and Action.FindBySpellID(S.Claw:ID()) and S.Claw)
    or (S.Smack:IsPetKnown() and Action.FindBySpellID(S.Smack:ID()) and S.Smack)
    or nil
  local PetRangeAbility = (S.Growl:IsPetKnown() and Action.FindBySpellID(S.Growl:ID()) and S.Growl) or nil
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40) -- Barbed Shot Cycle
    PetEnemiesMixed = (PetCleaveAbility and Player:GetEnemiesInSpellActionRange(PetCleaveAbility)) or Target:GetEnemiesInSplashRange(8)
    PetEnemiesMixedCount = (PetCleaveAbility and #PetEnemiesMixed) or Target:GetEnemiesInSplashRangeCount(8) -- Beast Cleave (through Multi-Shot)
  else
    Enemies40y = {}
    PetEnemiesMixed = Target or {}
    PetEnemiesMixedCount = 0
  end
  TargetInRange40y = Target:IsInRange(40) -- Most abilities
  TargetInRange30y = Target:IsInRange(30) -- Stampede
  TargetInRangePet30y = (PetRangeAbility and Target:IsSpellInActionRange(PetRangeAbility)) or Target:IsInRange(30) -- Kill Command

  -- Calculate FightRemains
  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies40y, false)
    end
  end

  -- Defensives
  -- Exhilaration
  if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
    if Cast(S.Exhilaration, Settings.CommonsOGCD.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
  end

  -- Pet Management; Conditions handled via override
  if S.SummonPet:IsCastable() then
    if Cast(SummonPetSpells[Settings.Commons.SummonPetSlot], Settings.CommonsOGCD.GCDasOffGCD.SummonPet) then return "Summon Pet"; end
  end
  if S.RevivePet:IsCastable() then
    if Cast(S.RevivePet, Settings.CommonsOGCD.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
  end
  if S.MendPet:IsCastable() then
    if Cast(S.MendPet, Settings.CommonsOGCD.GCDasOffGCD.MendPet) then return "Mend Pet High Priority"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
     local ShouldReturn = Everyone.Interrupt(S.CounterShot, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_shot
    -- call_action_list,name=cds
    if CDsON() or Settings.Commons.Enabled.Potions then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    if S.BlackArrow:IsAvailable() then
      -- call_action_list,name=drst,if=talent.black_arrow&(active_enemies<2|!talent.beast_cleave&active_enemies<3)
      if PetEnemiesMixedCount < 2 or not S.BeastCleave:IsAvailable() and PetEnemiesMixedCount < 3 then
        local ShouldReturn = DRST(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=drcleave,if=talent.black_arrow&(active_enemies>2|talent.beast_cleave&active_enemies>1)
      if PetEnemiesMixedCount > 2 or S.BeastCleave:IsAvailable() and PetEnemiesMixedCount > 1 then
        local ShouldReturn = DRCleave(); if ShouldReturn then return ShouldReturn; end
      end
    else
      -- call_action_list,name=st,if=!talent.black_arrow&(active_enemies<2|!talent.beast_cleave&active_enemies<3)
      if PetEnemiesMixedCount < 2 or not S.BeastCleave:IsAvailable() and PetEnemiesMixedCount < 3 then
        local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=cleave,if=!talent.black_arrow&(active_enemies>2|talent.beast_cleave&active_enemies>1)
      if PetEnemiesMixedCount > 2 or S.BeastCleave:IsAvailable() and PetEnemiesMixedCount > 1 then
        local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- Manually added pet healing
    -- Conditions handled via Overrides
    if S.MendPet:IsCastable() then
      if Cast(S.MendPet) then return "Mend Pet Low Priority (w/ Target)"; end
    end
    -- Pool Focus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end

  -- Note: We have to put it again in case we don't have a target but our pet is dying.
  -- Conditions handled via Overrides
  if S.MendPet:IsCastable() then
    if Cast(S.MendPet) then return "Mend Pet Low Priority (w/o Target)"; end
  end
end

local function OnInit ()
  S.BarbedShotDebuff:RegisterAuraTracking()
  S.SerpentStingDebuff:RegisterAuraTracking()

  HR.Print("Beast Mastery can use pet abilities to better determine AoE. Make sure you have Growl and Blood Bolt / Bite / Claw / Smack on your player action bars.")
  HR.Print("Beast Mastery Hunter rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(253, APL, OnInit)

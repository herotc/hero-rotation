--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastPooling   = HR.CastPooling
local CastAnnotated = HR.CastAnnotated
local CastSuggested = HR.CastSuggested
local Evoker        = HR.Commons.Evoker
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- lua
local mathmax       = math.max
local mathmin       = math.min
-- WoW API
local Delay       = C_Timer.After
local GetMastery  = GetMastery

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Evoker.Augmentation
local I = Item.Evoker.Augmentation

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.AberrantSpellforge:ID(),
  I.FlarendosPilotLight:ID(),
  I.HouseofCards:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
  -- TWW Items
  I.BestinSlotsCaster:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Evoker.Commons,
  CommonsDS = HR.GUISettings.APL.Evoker.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Evoker.CommonsOGCD,
  Augmentation = HR.GUISettings.APL.Evoker.Augmentation
}

--- ===== Rotation Variables =====
local PrescienceTargets = {}
local MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
local FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
local FlameAbility = S.ChronoFlames:IsLearned() and S.ChronoFlames or S.LivingFlame
local BossFightRemains = 11111
local FightRemains = 11111
local CombatTime
local DungeonRoute
local VarSpamHeal
local VarMinOpenerDelay
local VarOpenerDelay
local VarOpenerCDs
local VarHoldEmpowerFor = 6
local VarEbonMightPandemicThreshold = 0.4
local VarWingleaderForceTimings = false
local VarTempWound
local VarEonsRemains
local VarPoolForID

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinket1OGCDCast, VarTrinket2OGCDCast
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority, VarDamageTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0)or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

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

  -- Note: Hopefully nobody in 11.1 is using Ruby Whelp Shell or Whispering Incarnate Icon...
  VarTrinket1Exclude = VarTrinket1ID == I.OvinaxsMercurialEgg:ID() or VarTrinket1ID == I.AberrantSpellforge:ID()
  VarTrinket2Exclude = VarTrinket2ID == I.OvinaxsMercurialEgg:ID() or VarTrinket1ID == I.AberrantSpellforge:ID()

  -- Note: Hopefully nobody in 11.1 is using Nymue's...
  VarTrinket1Manual = VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1ID == I.TreacherousTransmitter:ID() or VarTrinket1ID == I.HouseofCards:ID()
  VarTrinket2Manual = VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.TreacherousTransmitter:ID() or VarTrinket2ID == I.HouseofCards:ID()

  -- Note: Hopefully nobody in 11.1 is using Beacon to the Beyond...
  VarTrinket1OGCDCast = false
  VarTrinket2OGCDCast = false

  VarTrinket1Buffs = Trinket1:HasUseBuff() and not VarTrinket1Exclude and VarTrinket1ID ~= I.FlarendosPilotLight:ID()
  VarTrinket2Buffs = Trinket2:HasUseBuff() and not VarTrinket2Exclude and VarTrinket2ID ~= I.FlarendosPilotLight:ID()

  VarTrinket1Sync = 0.5
  if VarTrinket1Buffs and (VarTrinket1CD % 120 == 0) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (VarTrinket2CD % 120 == 0) then
    VarTrinket2Sync = 1
  end

  -- Note: If BuffDuration is 0, set to 1 to avoid divide by zero errors.
  local T1BuffDur = Trinket1:BuffDuration() > 0 and Trinket1:BuffDuration() or 1
  local T2BuffDur = Trinket2:BuffDuration() > 0 and Trinket2:BuffDuration() or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs and (Trinket2:HasCooldown() and not VarTrinket2Exclude or not Trinket1:HasCooldown()) or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDur) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDur) * (VarTrinket1Sync) * (1 + ((VarTrinket1Level - VarTrinket2Level) / 100))) then
    VarTrinketPriority = 2
  end
  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and VarTrinket2Level >= VarTrinket1Level then
    VarDamageTrinketPriority = 2
  end

  -- Note: Hopefully nobody is using Nymue's in 11.1. Manually setting priority to 1.
  VarTrinketPriority = 1
end
SetTrinketVariables()

local function SetPrecombatVariables()
  VarSpamHeal = true
  VarMinOpenerDelay = Settings.Augmentation.MinOpenerDelay
  VarOpenerDelay = 0
  if not S.InterwovenThreads:IsAvailable() then
    VarOpenerDelay = VarMinOpenerDelay
  else
    VarOpenerDelay = VarMinOpenerDelay + (VarOpenerDelay or 0)
  end
  VarOpenerCDs = false
  VarHoldEmpowerFor = 6
  VarEbonMightPandemicThreshold = 0.4
  VarWingleaderForceTimings = false
end
SetPrecombatVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  SetPrecombatVariables()
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
  FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
  FlameAbility = S.ChronoFlames:IsLearned() and S.ChronoFlames or S.LivingFlame
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function SoMCheck()
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    return false
  end

  local SoMTarget = nil
  for _, Char in pairs(Group) do
    if Char:Exists() and Char:BuffUp(S.SourceofMagicBuff) then
      SoMTarget = Char
    end
  end

  if SoMTarget == nil then return true end
  return false
end

local function BlisteringScalesCheck()
  -- if Blistering Scales option is disabled, return 99 (always higher than required stacks, which should result in no suggestion)
  if not Settings.Augmentation.ShowBlisteringScales then return 99 end
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    -- If solo, just return our own stacks
    return Player:BuffStack(S.BlisteringScalesBuff)
  end

  if Group == Unit.Party then
    for unitID, Char in pairs(Group) do
      -- Check for the buff on the group tank only
      if Char:Exists() and UnitGroupRolesAssigned(unitID) == "TANK" then
        return Char:BuffStack(S.BlisteringScalesBuff)
      end
    end
  elseif Group == Unit.Raid then
    for unitID, Char in pairs(Group) do
      -- Check for the buff on the raid's ACTIVE tank only
      if Char:Exists() and (Char:IsTankingAoE(8) or Char:IsTanking(Target)) and UnitGroupRolesAssigned(unitID) == "TANK" then
        return Char:BuffStack(S.BlisteringScalesBuff)
      end
    end
  end

  return 99
end

local function PrescienceCheck()
  -- If Prescience suggestions are disabled in settings, always return false.
  if not Settings.Augmentation.ShowPrescience then return false end
  -- Always return true in a raid, as the odds of running out of dps to buff is low.
  if UnitInRaid("player") then
    return true
  -- In a 5-man, suggest Prescience on a dps without the Prescience buff or on the tank if neither dps will lose uptime.
  elseif UnitInParty("player") then
    local DPSBuffOne = nil
    local DPSBuffTwo = nil
    local TankBuff = nil
    local PrescienceCD = S.Prescience:Cooldown()
    for unitID, Char in pairs(Unit.Party) do
      if Char:Exists() then
        local CharRole = UnitGroupRolesAssigned(unitID)
        if CharRole == "DAMAGER" then
          if DPSBuffOne == nil then
            DPSBuffOne = Char:BuffRemains(S.PrescienceBuff)
          else
            DPSBuffTwo = Char:BuffRemains(S.PrescienceBuff)
          end
        end
        if CharRole == "TANK" then
          TankBuff = Char:BuffRemains(S.PrescienceBuff)
        end
      end
    end
    if DPSBuffOne == 0 or DPSBuffTwo == 0 then
      return true
    end
    return false
  -- Always return false when playing solo.
  else
    return false
  end
end

local function PrescienceCount()
  -- Determine group type. Return 0 if solo.
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    return 0
  end
  -- Count active Prescience buffs if in party or raid.
  local Count = 0
  for _, Char in pairs(Group) do
    if Char:Exists() and Char:BuffUp(S.PrescienceBuff) then
      Count = Count + 1
    end
  end
  return Count
end

local function ShiftingSandsCount()
  -- Count the number of friendlies with the Shifting Sands buff.
  local Group
  local Count = 0
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    return 0
  end

  for _, CycleUnit in pairs(Group) do
    if CycleUnit:Exists() and CycleUnit:BuffUp(S.ShiftingSandsBuff) then
      Count = Count + 1
    end
  end

  return Count
end

local function TemporalWoundCalc(Enemies)
  -- variable,name=temp_wound,value=debuff.temporal_wound.remains,target_if=max:debuff.temporal_wound.remains
  local HighestTW = 0
  for _, CycleUnit in pairs(Enemies) do
    local Remains = CycleUnit:DebuffRemains(S.TemporalWoundDebuff)
    HighestTW = mathmax(Remains, HighestTW)
  end
  return HighestTW
end

local function EMSelfBuffDuration()
  return S.EbonMightSelfBuff:BaseDuration() * (1 + ((GetMastery() / 2) / 100))
end

local function AllyCount()
  local Group
  local Count = 0
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    return 0
  end

  for _, CycleUnit in pairs(Group) do
    if CycleUnit:Exists() then
      Count = Count + 1
    end
  end

  return Count
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBombardments(TargetUnit)
  -- target_if=max:debuff.bombardments.remains
  return TargetUnit:DebuffRemains(S.BombardmentsDebuff)
end

--- ===== CastTargetIf Functions =====
local function EvaluateTargetIfLF(TargetUnit)
  -- if=talent.mass_eruption&buff.mass_eruption_stacks.up&!buff.imminent_destruction.up&buff.essence_burst.stack<buff.essence_burst.max_stack&essence.deficit>1&(buff.ebon_might_self.remains>=6|cooldown.ebon_might.remains<=6)&debuff.bombardments.remains<action.eruption.execute_time&(talent.pupil_of_alexstrasza|active_enemies=1)
  -- Note: All but debuff check handled before CastTargetIf.
  return TargetUnit:DebuffRemains(S.BombardmentsDebuff) < S.Eruption:ExecuteTime()
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- variable,name=spam_heal,default=1,op=reset
  -- variable,name=minimum_opener_delay,op=reset,default=0
  -- variable,name=opener_delay,value=variable.minimum_opener_delay,if=!talent.interwoven_threads
  -- variable,name=opener_delay,value=variable.minimum_opener_delay+variable.opener_delay,if=talent.interwoven_threads
  -- variable,name=opener_cds_detected,op=reset,default=0
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon|trinket.1.is.ovinaxs_mercurial_egg|trinket.1.is.aberrant_spellforge
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon|trinket.2.is.ovinaxs_mercurial_egg|trinket.2.is.aberrant_spellforge
  -- variable,name=trinket_1_manual,value=trinket.1.is.nymues_unraveling_spindle|trinket.1.is.spymasters_web|trinket.1.is.treacherous_transmitter|trinket.1.is.house_of_cards
  -- variable,name=trinket_2_manual,value=trinket.2.is.nymues_unraveling_spindle|trinket.2.is.spymasters_web|trinket.2.is.treacherous_transmitter|trinket.2.is.house_of_cards
  -- variable,name=trinket_1_ogcd_cast,value=trinket.1.is.beacon_to_the_beyond
  -- variable,name=trinket_2_ogcd_cast,value=trinket.2.is.beacon_to_the_beyond
  -- variable,name=trinket_1_buffs,value=(trinket.1.has_use_buff|(trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)&!variable.trinket_1_exclude)&(!trinket.1.is.flarendos_pilot_light)
  -- variable,name=trinket_2_buffs,value=(trinket.2.has_use_buff|(trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)&!variable.trinket_2_exclude)&(!trinket.2.is.flarendos_pilot_light)
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%120=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%120=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown&!variable.trinket_2_exclude|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(0.5+trinket.2.has_buff.intellect*3+trinket.2.has_buff.mastery)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(0.5+trinket.1.has_buff.intellect*3+trinket.1.has_buff.mastery)*(variable.trinket_1_sync)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=trinket.1.is.nymues_unraveling_spindle&trinket.2.has_buff.intellect|trinket.2.is.nymues_unraveling_spindle&!trinket.1.has_buff.intellect,if=(trinket.1.is.nymues_unraveling_spindle|trinket.2.is.nymues_unraveling_spindle)&(variable.trinket_1_buffs&variable.trinket_2_buffs)
  -- variable,name=hold_empower_for,op=reset,default=6
  -- variable,name=ebon_might_pandemic_threshold,op=reset,default=0.4
  -- variable,name=wingleader_force_timings,op=reset,default=0
  SetPrecombatVariables()
  -- Manually added: Group buff check
  if S.BlessingoftheBronze:IsCastable() and Everyone.GroupBuffMissing(S.BlessingoftheBronzeBuff) then
    if Cast(S.BlessingoftheBronze, Settings.CommonsOGCD.GCDasOffGCD.BlessingOfTheBronze) then return "blessing_of_the_bronze precombat 2"; end
  end
  -- Manually added: source_of_magic,if=group&active_dot.source_of_magic=0
  if S.SourceofMagic:IsCastable() and SoMCheck() then
    if Cast(S.SourceofMagic) then return "source_of_magic precombat 4"; end
  end
  -- Manually added: black_attunement,if=buff.black_attunement.down
  if S.BlackAttunement:IsCastable() and Player:BuffDown(S.BlackAttunementBuff) then
    if Cast(S.BlackAttunement) then return "black_attunement precombat 6"; end
  end
  -- Manually added: bronze_attunement,if=buff.bronze_attunement.down&buff.black_attunement.up&!buff.black_attunement.mine
  if S.BronzeAttunement:IsCastable() and (Player:BuffDown(S.BronzeAttunementBuff) and Player:BuffUp(S.BlackAttunementBuff) and not Player:BuffUp(S.BlackAttunementBuff, false)) then
    if Cast(S.BronzeAttunement) then return "bronze_attunement precombat 8"; end
  end
  -- use_item,name=aberrant_spellforge
  if I.AberrantSpellforge:IsEquippedAndReady() then
    if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge precombat 10"; end
  end
  -- blistering_scales,target_if=target.role.tank
  if S.BlisteringScales:IsCastable() and (BlisteringScalesCheck() < 10) then
    if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales precombat 12"; end
  end
  -- living_flame
  if FlameAbility:IsCastable() then
    if Cast(FlameAbility, nil, nil, not Target:IsSpellInRange(FlameAbility)) then return "living_flame precombat 14"; end
  end
end

local function EbonLogic()
  -- ebon_might
  if S.EbonMight:IsReady() then
    if Cast(S.EbonMight, Settings.Augmentation.GCDasOffGCD.EbonMight) then return "ebon_might ebon_logic 2"; end
  end
end

local function FB()
  -- tip_the_scales,if=cooldown.fire_breath.ready&buff.ebon_might_self.up
  if CDsON() and S.TipTheScales:IsCastable() and (S.FireBreath:CooldownUp() and Player:BuffUp(S.EbonMightSelfBuff)) then
    if Cast(S.TipTheScales, Settings.CommonsOGCD.GCDasOffGCD.TipTheScales) then return "tip_the_scales fb 2"; end
  end
  -- fire_breath,empower_to=4,target_if=target.time_to_die>4,if=talent.font_of_magic&(buff.ebon_might_self.remains>duration&(!talent.molten_embers|cooldown.upheaval.remains<=(20+4*talent.blast_furnace-6*3))|buff.tip_the_scales.up)
  -- fire_breath,empower_to=3,target_if=target.time_to_die>8,if=(buff.ebon_might_self.remains>duration&(!talent.molten_embers|cooldown.upheaval.remains<=(20+4*talent.blast_furnace-6*2))|buff.tip_the_scales.up)
  -- fire_breath,empower_to=2,target_if=target.time_to_die>12,if=buff.ebon_might_self.remains>duration&(!talent.molten_embers|cooldown.upheaval.remains<=(20+4*talent.blast_furnace-6*1))
  -- fire_breath,empower_to=1,target_if=target.time_to_die>16,if=buff.ebon_might_self.remains>duration&(!talent.molten_embers|cooldown.upheaval.remains<=(20+4*talent.blast_furnace-6*0))
  -- fire_breath,empower_to=4,target_if=target.time_to_die>4,if=talent.font_of_magic&(buff.ebon_might_self.remains>duration)
  -- fire_breath,empower_to=3,target_if=target.time_to_die>8,if=talent.font_of_magic&set_bonus.tww2_2pc&talent.molten_embers
  local FBEmpower = 0
  if S.FireBreath:IsCastable() then
    -- Note: Using Player:EmpowerCastTime() in place of duration in the below lines. Intention seems to be whether we can get the spell off before Ebom Might ends.
    if S.FontofMagic:IsAvailable() and (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(4) and (not S.MoltenEmbers:IsAvailable() or S.Upheaval:CooldownRemains() <= (20 + 4 * num(S.BlastFurnace:IsAvailable()) - 6 * 3)) or Player:BuffUp(S.TipTheScales)) and Target:TimeToDie() > 4 then
      FBEmpower = 4
    elseif (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(3) or Player:BuffUp(S.TipTheScales) and not S.FontofMagic:IsAvailable()) and (not S.MoltenEmbers:IsAvailable() or S.Upheaval:CooldownRemains() <= (20 + 4 * num(S.BlastFurnace:IsAvailable()) - 6 * 2)) and Target:TimeToDie() > 8 then
      FBEmpower = 3
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(2) and (not S.MoltenEmbers:IsAvailable() or S.Upheaval:CooldownRemains() <= (20 + 4 * num(S.BlastFurnace:IsAvailable()) - 6 * 1)) and Target:TimeToDie() > 12 then
      FBEmpower = 2
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(1) and (not S.MoltenEmbers:IsAvailable() or S.Upheaval:CooldownRemains() <= (20 + 4 * num(S.BlastFurnace:IsAvailable()) - 6 * 0)) and Target:TimeToDie() > 16 then
      FBEmpower = 1
    elseif S.FontofMagic:IsAvailable() and Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(4) then
      FBEmpower = 4
    elseif S.FontofMagic:IsAvailable() and Player:HasTier("TWW2", 2) and S.MoltenEmbers:IsAvailable() then
      FBEmpower = 3
    end
  end
  if FBEmpower > 0 then
    if CastAnnotated(S.FireBreath, false, FBEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower_to=" .. FBEmpower .. " fb 4"; end
  end
end

local function Filler()
  -- living_flame,if=(buff.ancient_flame.up|mana>=200000|!talent.dream_of_spring|variable.spam_heal=0)&(active_enemies=1|talent.pupil_of_alexstrasza)
  if FlameAbility:IsReady() and ((Player:BuffUp(S.AncientFlameBuff) or Player:Mana() >= 200000 or not S.DreamofSpring:IsAvailable() or VarSpamHeal == 0) and (EnemiesCount8ySplash == 1 or S.PupilofAlexstrasza:IsAvailable())) then
    if Cast(FlameAbility, nil, nil, not Target:IsSpellInRange(FlameAbility)) then return "living_flame filler 2"; end
  end
  -- emerald_blossom,if=!buff.ebon_might_self.up&talent.ancient_flame&talent.scarlet_adaptation&!talent.dream_of_spring&!buff.ancient_flame.up&active_enemies=1
  if S.EmeraldBlossom:IsReady() and (Player:BuffDown(S.EbonMightSelfBuff) and S.AncientFlame:IsAvailable() and S.ScarletAdaptation:IsAvailable() and not S.DreamofSpring:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and EnemiesCount8ySplash == 1) then
    if Cast(S.EmeraldBlossom, Settings.Augmentation.GCDasOffGCD.EmeraldBlossom) then return "emerald_blossom filler 4"; end
  end
  -- verdant_embrace,if=!buff.ebon_might_self.up&talent.ancient_flame&talent.scarlet_adaptation&!buff.ancient_flame.up&(!talent.dream_of_spring|mana>=200000)&active_enemies=1
  if S.VerdantEmbrace:IsReady() and (Player:BuffDown(S.EbonMightSelfBuff) and S.AncientFlame:IsAvailable() and S.ScarletAdaptation:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and (not S.DreamofSpring:IsAvailable() or Player:Mana() >= 200000) and EnemiesCount8ySplash == 1) then
    if Cast(S.VerdantEmbrace, Settings.Augmentation.GCDasOffGCD.VerdantEmbrace) then return "verdant_embrace filler 6"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike filler 8"; end
  end
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=nymues_unraveling_spindle,if=cooldown.breath_of_eons.remains<=3&(trinket.1.is.nymues_unraveling_spindle&variable.trinket_priority=1|trinket.2.is.nymues_unraveling_spindle&variable.trinket_priority=2)|(cooldown.fire_breath.remains<=4|cooldown.upheaval.remains<=4)&cooldown.breath_of_eons.remains>10&!(debuff.temporal_wound.up|prev_gcd.1.breath_of_eons)&(trinket.1.is.nymues_unraveling_spindle&variable.trinket_priority=2|trinket.2.is.nymues_unraveling_spindle&variable.trinket_priority=1)
    -- Note: Skipping this. Hopefully nobody is using Nymue's in 11.1...
    -- use_item,name=aberrant_spellforge
    if I.AberrantSpellforge:IsEquippedAndReady() then
      if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge items 2"; end
    end
    -- use_item,name=flarendos_pilot_light,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&trinket.2.is.flarendos_pilot_light|!variable.trinket_2_buffs&!variable.trinket_2_manual&trinket.1.is.flarendos_pilot_light
    if I.FlarendosPilotLight:IsEquippedAndReady() and (not VarTrinket1Buffs and not VarTrinket1Manual and VarTrinket2ID == I.FlarendosPilotLight:ID() or not VarTrinket2Buffs and not VarTrinket2Manual and VarTrinket1ID == I.FlarendosPilotLight:ID()) then
      if Cast(I.FlarendosPilotLight, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "flarendos_pilot_light items 4"; end
    end
    -- use_item,name=treacherous_transmitter,if=cooldown.allied_virtual_cd_time.remains<=10|cooldown.breath_of_eons.remains<=10&talent.wingleader|fight_remains<=15
    if I.TreacherousTransmitter:IsEquippedAndReady() then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter items 6"; end
    end
    -- do_treacherous_transmitter_task,use_off_gcd=1,if=(debuff.temporal_wound.up|prev_gcd.1.breath_of_eons|fight_remains<=15)
    -- TODO: Handle the above.
     -- use_item,name=spymasters_web,if=(debuff.temporal_wound.up|prev_gcd.1.breath_of_eons)&(fight_remains<=130-(30+12*talent.interwoven_threads)*talent.wingleader-20*talent.time_skip*(cooldown.time_skip.remains<=90)*!talent.interwoven_threads)|(fight_remains<=20|evoker.allied_cds_up>0&fight_remains<=60)&(trinket.1.is.spymasters_web&(trinket.2.cooldown.duration=0|trinket.2.cooldown.remains>=10|variable.trinket_2_exclude)|trinket.2.is.spymasters_web&(trinket.1.cooldown.duration=0|trinket.1.cooldown.remains>=10|variable.trinket_1_exclude))&!buff.spymasters_web.up
    if I.SpymastersWeb:IsEquippedAndReady() and ((Target:DebuffUp(S.TemporalWoundDebuff) or Player:PrevGCDP(1, S.BreathofEons)) and (FightRemains < 130 - (30 + 12 * num(S.InterwovenThreads:IsAvailable())) * num(S.Wingleader:IsAvailable()) - 20 * num(S.TimeSkip:IsAvailable()) * num(S.TimeSkip:CooldownRemains() <= 90) * num(not S.InterwovenThreads:IsAvailable())) or (FightRemains <= 60) and (VarTrinket1ID == I.SpymastersWeb:ID() and (VarTrinket2CD == 0 or Trinket2:CooldownRemains() >= 10 or VarTrinket2Exclude) or VarTrinket2ID == I.SpymastersWeb:ID() and (VarTrinket1CD == 0 or Trinket1:CooldownRemains() >= 10 or VarTrinket1Exclude)) and Player:BuffDown(S.SpymastersWebBuff)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web items 8"; end
    end
    -- use_item,name=house_of_cards,if=evoker.shifting_buffs>=2|evoker.shifting_buffs>=1&(cooldown.fire_breath.remains<=7|cooldown.upheaval.remains<=7)
    local ShiftingBuffs = ShiftingSandsCount()
    if I.HouseofCards:IsEquippedAndReady() and (ShiftingBuffs >= 2 or ShiftingBuffs >= 1 and (S.FireBreath:CooldownRemains() <= 7 or S.Upheaval:CooldownRemains() <= 7)) then
      if Cast(I.HouseofCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "house_of_cards items 10"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&!variable.trinket_1_exclude&((debuff.temporal_wound.up|prev_gcd.1.breath_of_eons|!talent.breath_of_eons&buff.ebon_might_self.up&active_enemies>=1)|variable.trinket_2_buffs&!trinket.2.cooldown.up&(prev_gcd.1.fire_breath|prev_gcd.1.upheaval)&buff.ebon_might_self.up)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and not VarTrinket1Manual and not VarTrinket1Exclude and ((Target:DebuffUp(S.TemporalWoundDebuff) or Player:PrevGCDP(1, S.BreathofEons) or not S.BreathofEons:IsAvailable() and Player:BuffUp(S.EbonMightSelfBuff) and EnemiesCount8ySplash >= 1) or VarTrinket2Buffs and Trinket2:CooldownDown() and (Player:PrevGCDP(1, S.FireBreath) or Player:PrevGCDP(1, S.Upheaval)) and Player:BuffUp(S.EbonMightSelfBuff)) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 12"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&!variable.trinket_2_exclude&((debuff.temporal_wound.up|prev_gcd.1.breath_of_eons|!talent.breath_of_eons&buff.ebon_might_self.up&active_enemies>=1)|variable.trinket_1_buffs&!trinket.1.cooldown.up&(prev_gcd.1.fire_breath|prev_gcd.1.upheaval)&buff.ebon_might_self.up)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and not VarTrinket2Manual and not VarTrinket1Exclude and ((Target:DebuffUp(S.TemporalWoundDebuff) or Player:PrevGCDP(1, S.BreathofEons) or not S.BreathofEons:IsAvailable() and Player:BuffUp(S.EbonMightSelfBuff) and EnemiesCount8ySplash >= 1) or VarTrinket1Buffs and Trinket1:CooldownDown() and (Player:PrevGCDP(1, S.FireBreath) or Player:PrevGCDP(1, S.Upheaval)) and Player:BuffUp(S.EbonMightSelfBuff)) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 14"; end
    end
  end
  -- azure_strike,if=cooldown.item_cd_1141.up&(variable.trinket_1_ogcd_cast&trinket.1.cooldown.up&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains)|variable.trinket_2_ogcd_cast&trinket.2.cooldown.up&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains))
  -- Note: item_cd_1141 appears to refer to Concoction: Kiss of Death.
  -- https://github.com/simulationcraft/simc/blob/797e8b6148d5054c7dd8da1b3158b6c8f7679e69/engine/player/unique_gear_thewarwithin.cpp#L4600
  if S.AzureStrike:IsReady() and (I.ConcoctionKissofDeath:IsEquippedAndReady() and (VarTrinket1OGCDCast and Trinket1:CooldownUp() and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown()) or VarTrinket2OGCDCast and Trinket2:CooldownUp() and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown()))) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsInRange(20)) then return "azure_strike items 16"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&!variable.trinket_1_exclude&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|trinket.2.is.spymasters_web&buff.spymasters_report.stack<30|variable.eons_remains>=20|!talent.breath_of_eons|trinket.2.cooldown.duration=0|variable.trinket_2_exclude)&(gcd.remains>0.1&variable.trinket_1_ogcd_cast)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and not VarTrinket1Manual and not VarTrinket1Exclude and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or VarTrinket2ID == I.SpymastersWeb:ID() and Player:BuffStack(S.SpymastersReportBuff) < 30 or VarEonsRemains >= 20 or not S.BreathofEons:IsAvailable() or VarTrinket2CD == 0 or VarTrinket2Exclude)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 18"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&!variable.trinket_2_exclude&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|trinket.1.is.spymasters_web&buff.spymasters_report.stack<30|variable.eons_remains>=20|!talent.breath_of_eons|trinket.1.cooldown.duration=0|variable.trinket_1_exclude)&(gcd.remains>0.1&variable.trinket_2_ogcd_cast)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and not VarTrinket2Manual and not VarTrinket2Exclude and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or VarTrinket1ID == I.SpymastersWeb:ID() and Player:BuffStack(S.SpymastersReportBuff) < 30 or VarEonsRemains >= 20 or not S.BreathofEons:IsAvailable() or VarTrinket1CD == 0 or VarTrinket1Exclude)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 20"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&!variable.trinket_1_exclude&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|trinket.2.is.spymasters_web&buff.spymasters_report.stack<30|variable.eons_remains>=20|!talent.breath_of_eons|trinket.2.cooldown.duration=0|variable.trinket_2_exclude)&(!variable.trinket_1_ogcd_cast)
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&!variable.trinket_2_exclude&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|trinket.1.is.spymasters_web&buff.spymasters_report.stack<30|variable.eons_remains>=20|!talent.breath_of_eons|trinket.1.cooldown.duration=0|variable.trinket_1_exclude)&(!variable.trinket_2_ogcd_cast)
    -- Note: Skipping the above lines, as they're just on-GCD versions of the lines above them. HR doesn't differentiate between on-GCD and OffGCD trinket usage.
  end
  -- use_item,name=bestinslots,use_off_gcd=1,if=buff.ebon_might_self.up&(!variable.trinket_1_buffs|trinket.1.cooldown.duration<=20|trinket.1.cooldown.remains>=10)&(!variable.trinket_2_buffs|trinket.2.cooldown.duration<=20|trinket.2.cooldown.remains>=10)
  if Settings.Commons.Enabled.Items and I.BestinSlotsCaster:IsEquippedAndReady() and (Player:BuffUp(S.EbonMightSelfBuff) and (not VarTrinket1Buffs or VarTrinket1CD <= 20 or Trinket1:CooldownRemains() >= 10) and (not VarTrinket2Buffs or VarTrinket2CD <= 20 or Trinket2:CooldownRemains() >= 10)) then
    if Cast(I.BestinSlotsCaster, nil, Settings.CommonsDS.DisplayStyle.Items) then return "bestinslots items 22"; end
  end
  -- use_item,slot=main_hand,use_off_gcd=1,if=gcd.remains>=gcd.max*0.6&!equipped.bestinslots
  -- Note: Expanding to include all non-trinket items.
  -- Note: Skipping bestinslots check, as it's excluded by OnUseExcludes.
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ItemToUse:IsReady() then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "use_item for non-trinket (" .. ItemToUse:Name() .. ") items 20"; end 
    end
  end
end

local function OpenerFiller()
  -- variable,name=opener_delay,value=variable.opener_delay>?variable.minimum_opener_delay,if=!variable.opener_cds_detected&evoker.allied_cds_up>0
  if not VarOpenerCDs then
    VarOpenerDelay = mathmin(VarOpenerDelay, VarMinOpenerDelay)
  end
  -- variable,name=opener_delay,value=variable.opener_delay-1
  -- Note: Instead of decrementing, just set to 0 if we've reached the opener delay.
  if CombatTime >= VarOpenerDelay then VarOpenerDelay = 0 end
  -- variable,name=opener_cds_detected,value=1,if=!variable.opener_cds_detected&evoker.allied_cds_up>0
  if not VarOpenerCDs then
    VarOpenerCDs = true
  end
  -- eruption,if=variable.opener_delay>=3
  if S.Eruption:IsReady() and VarOpenerDelay >= 3 then
    if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption opener_filler 2"; end
  end
  -- living_flame,if=active_enemies=1|talent.pupil_of_alexstrasza
  if FlameAbility:IsReady() and (EnemiesCount8ySplash == 1 or S.PupilofAlexstrasza:IsAvailable()) then
    if Cast(FlameAbility, nil, nil, not Target:IsSpellInRange(FlameAbility)) then return "living_flame opener_filler 4"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike opener_filler 6"; end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies25y = Player:GetEnemiesInRange(25)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if (AoEON()) then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies25y, false)
    end

    -- Localize HL.CombatTime()
    CombatTime = HL.CombatTime()
  end

  if Everyone.TargetIsValid() then
    DungeonRoute = Player:IsInDungeonArea()
    -- Precombat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.Quell, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: unravel
    if S.Unravel:IsReady() then
      if Cast(S.Unravel, Settings.CommonsOGCD.GCDasOffGCD.Unravel, nil, not Target:IsSpellInRange(S.Unravel)) then return "unravel main 2"; end
    end
    -- variable,name=temp_wound,value=debuff.temporal_wound.remains,target_if=max:debuff.temporal_wound.remains
    VarTempWound = TemporalWoundCalc(Enemies25y)
    -- variable,name=eons_remains,op=setif,value=cooldown.allied_virtual_cd_time.remains,value_else=cooldown.breath_of_eons.remains,condition=!talent.wingleader|variable.wingleader_force_timings,if=talent.breath_of_eons
    -- variable,name=eons_remains,op=set,value=cooldown.allied_virtual_cd_time.remains,if=!talent.breath_of_eons
    VarEonsRemains = S.BreathofEons:IsAvailable() and S.BreathofEons:CooldownRemains() or 0
    -- variable,name=pool_for_id,if=talent.imminent_destruction,default=0,op=set,value=(variable.eons_remains<8&talent.breath_of_eons&(target.time_to_die>13&raid_event.adds.in>15|fight_remains<30&!fight_style.dungeonroute)|cooldown.deep_breath.remains<8&!talent.breath_of_eons)&essence.deficit>=1&!buff.essence_burst.react
    VarPoolForID = false
    if S.ImminentDestruction:IsAvailable() then
      VarPoolForID = (VarEonsRemains < 8 and S.BreathofEons:IsAvailable() and (Target:TimeToDie() > 13 or BossFightRemains < 30 and not DungeonRoute) or S.DeepBreath:CooldownRemains() < 8 and not S.BreathofEons:IsAvailable()) and Player:EssenceDeficitP() >= 1 and Player:BuffDown(S.EssenceBurstBuff)
    end
    -- hover,use_off_gcd=1,if=gcd.remains>=0.5&(!raid_event.movement.exists&(trinket.1.is.ovinaxs_mercurial_egg|trinket.2.is.ovinaxs_mercurial_egg)|raid_event.movement.in<=6)
    -- Note: Not handling hover.
    -- prescience,target_if=min:(debuff.prescience.remains-200*(target.role.attack|target.role.spell|target.role.dps)+50*target.spec.augmentation),if=((full_recharge_time<=gcd.max*3|cooldown.ebon_might.remains<=gcd.max*3&(buff.ebon_might_self.remains-gcd.max*3)<=buff.ebon_might_self.duration*variable.ebon_might_pandemic_threshold|fight_remains<=30&!fight_style.dungeonroute)|variable.eons_remains<=8|talent.anachronism&buff.imminent_destruction.up&essence<1&!cooldown.fire_breath.up&!cooldown.upheaval.up)&debuff.prescience.remains<gcd.max*2&(!talent.anachronism|buff.essence_burst.stack<buff.essence_burst.max_stack|time<=10)
    -- Note: Not handling target_if, as user will have to decide on a target.
    -- TODO: Handle debuff.prescience.remains.
    if S.Prescience:IsCastable() and PrescienceCheck() and ((S.Prescience:FullRechargeTime() <= Player:GCD() * 3 or S.EbonMight:CooldownRemains() <= Player:GCD() * 3 and (Player:BuffRemains(S.EbonMightSelfBuff) - Player:GCD() * 3) <= EMSelfBuffDuration() * VarEbonMightPandemicThreshold or BossFightRemains <= 30 and not DungeonRoute) or VarEonsRemains <= 8 or S.Anachronism:IsAvailable() and Player:BuffUp(S.ImminentDestructionBuff) and Player:EssenceP() < 1 and S.FireBreath:CooldownDown() and S.Upheaval:CooldownDown() and (not S.Anachronism:IsAvailable() or Player:EssenceBurst() < Player:MaxEssenceBurst() or CombatTime <= 10)) then
      if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience main 4"; end
    end
    -- prescience,target_if=min:(debuff.prescience.remains-200*(target.spec.augmentation|target.role.tank)),if=full_recharge_time<=gcd.max*3&debuff.prescience.remains<gcd.max*2&(target.spec.augmentation|target.role.tank)&(!talent.anachronism|buff.essence_burst.stack<buff.essence_burst.max_stack|time<=5)
    -- Note: Skipping this line, as it appears to only be for tanks and other Augs. We can't handle specific prescience targets.
    -- potion,if=variable.eons_remains<=0|fight_remains<=30&!fight_style.dungeonroute
    if Settings.Commons.Enabled.Potions and (VarEonsRemains <= 0 or BossFightRemains <= 30 and not DungeonRoute) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected then
        if PotionSelected:IsReady() then
          if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 6"; end
        end
      end
    end
    -- call_action_list,name=ebon_logic,if=(buff.ebon_might_self.remains-cast_time)<=buff.ebon_might_self.duration*variable.ebon_might_pandemic_threshold&(active_enemies>0|raid_event.adds.in<=3)&(variable.eons_remains>0|!talent.breath_of_eons&cooldown.deep_breath.remains>0|raid_event.adds.in<=3|time>30|talent.molten_embers&(set_bonus.tww2_2pc|!talent.breath_of_eons|talent.overlord))&(!buff.imminent_destruction.up|buff.ebon_might_self.remains<=gcd.max)
    if (Player:BuffRemains(S.EbonMightSelfBuff) - S.EbonMight:CastTime()) <= EMSelfBuffDuration() * VarEbonMightPandemicThreshold and (VarEonsRemains > 0 or not S.BreathofEons:IsAvailable() and S.DeepBreath:CooldownDown() or CombatTime > 30 or S.MoltenEmbers:IsAvailable() and (Player:HasTier("TWW2", 2) or not S.BreathofEons:IsAvailable() or S.Overlord:IsAvailable())) and (Player:BuffDown(S.ImminentDestructionBuff) or Player:BuffRemains(S.EbonMightSelfBuff) <= Player:GCD()) then
      local ShouldReturn = EbonLogic(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=opener_filler,if=variable.opener_delay>0&!fight_style.dungeonroute
    if VarOpenerDelay > 0 and not Player:IsInDungeonArea() then
      local ShouldReturn = OpenerFiller(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for OpenerFiller()"; end
    end
    -- fury_of_the_aspects,if=talent.time_convergence&!buff.time_convergence_intellect.up&(essence>=2|buff.essence_burst.react)&variable.eons_remains>=8
    -- Note: When to Bloodlust is going to vary by raid team. Not suggesting fury_of_the_aspects.
    -- tip_the_scales,if=talent.threads_of_fate&(prev_gcd.1.breath_of_eons|prev_gcd.1.deep_breath|fight_remains<=30&!fight_style.dungeonroute)
    if S.TipTheScales:IsReady() and (S.ThreadsofFate:IsAvailable() and (Player:PrevGCDP(1, S.BreathofEons) or Player:PrevGCDP(1, S.DeepBreath) or BossFightRemains <= 30 and not DungeonRoute)) then
      if Cast(S.TipTheScales, Settings.CommonsOGCD.GCDasOffGCD.TipTheScales, nil, not Target:IsInRange(50)) then return "tip_the_scales main 8"; end
    end
    -- call_action_list,name=fb,if=(raid_event.adds.remains>6|raid_event.adds.in>20|evoker.allied_cds_up>0|!raid_event.adds.exists)&(!talent.molten_embers|cooldown.upheaval.remains<=(8+4*talent.blast_furnace-6*talent.font_of_magic.enabled))
    if not S.MoltenEmbers:IsAvailable() or S.Upheaval:CooldownRemains() <= (8 + 4 * num(S.BlastFurnace:IsAvailable()) - 6 * num(S.FontofMagic:IsAvailable())) then
      local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
    end
    -- deep_breath
    if S.DeepBreath:IsReady() then
      if Cast(S.DeepBreath, Settings.Augmentation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath main 10"; end
    end
    if S.BreathofEons:IsReady() and (
      -- breath_of_eons,if=talent.wingleader&(fight_style.dungeonroute|fight_style.dungeonslice)&target.time_to_die>=13&evoker.allied_cds_up>0
      (S.Wingleader:IsAvailable() and DungeonRoute and Target:TimeToDie() >= 13) or
      -- breath_of_eons,if=talent.wingleader&(target.time_to_die>=13&(raid_event.adds.in>=25|!raid_event.adds.exists|raid_event.adds.remains>=13&raid_event.adds.count%1.5<active_enemies))&!variable.wingleader_force_timings&(time%%240<=230&time%%240>=3|fight_style.dungeonroute|fight_style.dungeonslice)|fight_remains<=30&!fight_style.dungeonroute
      (S.Wingleader:IsAvailable() and Target:TimeToDie() >= 13 and not VarWingleaderForceTimings and (CombatTime % 240 <= 230 and CombatTime % 240 >= 3 or DungeonRoute) or BossFightRemains <= 30 and not DungeonRoute) or
      -- breath_of_eons,if=(target.time_to_die>13&raid_event.adds.in>15|fight_remains<30&!fight_style.dungeonroute)&cooldown.allied_virtual_cd_time.up|fight_remains<=15&(talent.imminent_destruction|talent.melt_armor)&!fight_style.dungeonroute
      ((Target:TimeToDie() > 13 or BossFightRemains < 30 and not DungeonRoute) or BossFightRemains <= 15 and (S.ImminentDestruction:IsAvailable() or S.MeltArmor:IsAvailable()) and not DungeonRoute) or
      -- breath_of_eons,if=fight_style.dungeonroute&(target.time_to_die>=13&(raid_event.adds.in>=25|!raid_event.adds.exists|raid_event.adds.remains>=13&raid_event.adds.count%1.5<active_enemies))
      (DungeonRoute and Target:TimeToDie() >= 13)
    ) then
      if Cast(S.BreathofEons, Settings.Augmentation.GCDasOffGCD.BreathOfEons, nil, not Target:IsInRange(50)) then return "breath_of_eons main 12"; end
    end    
    -- upheaval,target_if=target.time_to_die>duration+0.2,empower_to=1,if=buff.ebon_might_self.remains>duration&(raid_event.adds.remains>10|evoker.allied_cds_up>0|!raid_event.adds.exists|raid_event.adds.in>20)&(!talent.molten_embers|dot.fire_breath_damage.ticking|cooldown.fire_breath.remains>=10)&(buff.essence_burst.stack<buff.essence_burst.max_stack|!set_bonus.tww2_4pc&!talent.rockfall|!buff.essence_burst.react)
    if S.Upheaval:IsReady() and (Target:TimeToDie() > Player:EmpowerCastTime(1) + 0.7 and (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(1) + 0.5 and (not S.MoltenEmbers:IsAvailable() or S.FireBreathDebuff:AuraActiveCount() > 0 or S.FireBreath:CooldownRemains() >= 10) and (Player:EssenceBurst() < Player:MaxEssenceBurst() or not Player:HasTier("TWW2", 4) and not S.Rockfall:IsAvailable() or Player:BuffDown(S.EssenceBurstBuff)))) then
      if CastAnnotated(S.Upheaval, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "upheaval empower_to=1 main 14"; end
    end
    -- time_skip,target_if=max:debuff.bombardments.remains,if=(((cooldown.fire_breath.remains>?20)+(cooldown.upheaval.remains>?20)))>=30&(cooldown.breath_of_eons.remains>=20&talent.breath_of_eons|!talent.breath_of_eons&cooldown.deep_breath.remains>=20)&(!buff.imminent_destruction.up|talent.temporal_burst&buff.temporal_burst.remains>=15)
    if S.TimeSkip:IsReady() and (((mathmin(S.FireBreath:CooldownRemains(), 20) + mathmin(S.Upheaval:CooldownRemains(), 20))) >= 30 and (S.BreathofEons:CooldownRemains() >= 20 and S.BreathofEons:IsAvailable() or not S.BreathofEons:IsAvailable() and S.DeepBreath:CooldownRemains() >= 20) and (Player:BuffDown(S.ImminentDestructionBuff) or S.TemporalBurst:IsAvailable() and Player:BuffRemains(S.TemporalBurstBuff) > 15)) then
      if Cast(S.TimeSkip, Settings.Augmentation.GCDasOffGCD.TimeSkip) then return "time_skip main 16"; end
    end
    -- emerald_blossom,if=talent.dream_of_spring&buff.essence_burst.react&(variable.spam_heal=2|variable.spam_heal=1&!buff.ancient_flame.up&talent.ancient_flame)&(buff.ebon_might_self.up|essence.deficit=0|buff.essence_burst.stack=buff.essence_burst.max_stack&cooldown.ebon_might.remains>4)
    if S.EmeraldBlossom:IsReady() and (S.DreamofSpring:IsAvailable() and Player:BuffUp(S.EssenceBurstBuff) and (VarSpamHeal == 2 or VarSpamHeal == 1 and Player:BuffDown(S.AncientFlameBuff) and S.AncientFlame:IsAvailable()) and (Player:BuffUp(S.EbonMightSelfBuff) or Player:EssenceDeficitP() == 0 or Player:EssenceBurst() == Player:MaxEssenceBurst() and S.EbonMight:CooldownRemains() > 4)) then
      if Cast(S.EmeraldBlossom, Settings.Augmentation.GCDasOffGCD.EmeraldBlossom) then return "emerald_blossom main 18"; end
    end
    -- living_flame,target_if=max:debuff.bombardments.remains,if=talent.mass_eruption&buff.mass_eruption_stacks.up&!buff.imminent_destruction.up&buff.essence_burst.stack<buff.essence_burst.max_stack&essence.deficit>1&(buff.ebon_might_self.remains>=6|cooldown.ebon_might.remains<=6)&debuff.bombardments.remains<action.eruption.execute_time&(talent.pupil_of_alexstrasza|active_enemies=1)
    if S.LivingFlame:IsReady() and (S.MassEruption:IsAvailable() and Player:BuffUp(S.MassEruptionBuff) and Player:BuffDown(S.ImminentDestructionBuff) and Player:EssenceBurst() < Player:MaxEssenceBurst() and Player:EssenceDeficitP() > 1 and (Player:BuffRemains(S.EbonMightSelfBuff) >= 6 or S.EbonMight:CooldownRemains() <= 6) and (S.PupilofAlexstrasza:IsAvailable() or EnemiesCount8ySplash == 1)) then
      if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterBombardments, EvaluateTargetIfLF, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 20"; end
    end
    -- azure_strike,target_if=max:debuff.bombardments.remains,if=talent.mass_eruption&buff.mass_eruption_stacks.up&!buff.imminent_destruction.up&buff.essence_burst.stack<buff.essence_burst.max_stack&essence.deficit>1&(buff.ebon_might_self.remains>=6|cooldown.ebon_might.remains<=6)&debuff.bombardments.remains<action.eruption.execute_time&(talent.echoing_strike&active_enemies>1)
    -- Note: CTI function is not a typo. Uses the same check as LF above.
    if S.AzureStrike:IsReady() and (S.MassEruption:IsAvailable() and Player:BuffUp(S.MassEruptionBuff) and Player:BuffDown(S.ImminentDestructionBuff) and Player:EssenceBurst() < Player:MaxEssenceBurst() and Player:EssenceDeficitP() > 1 and (Player:BuffRemains(S.EbonMightSelfBuff) >= 6 or S.EbonMight:CooldownRemains() <= 6) and (S.EchoingStrike:IsAvailable() and EnemiesCount8ySplash > 1)) then
      if Everyone.CastTargetIf(S.AzureStrike, Enemies8ySplash, "max", EvaluateTargetIfFilterBombardments, EvaluateTargetIfLF, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike main 22"; end
    end
    -- eruption,target_if=min:debuff.bombardments.remains,if=(buff.ebon_might_self.remains>execute_time|essence.deficit=0|buff.essence_burst.stack=buff.essence_burst.max_stack&cooldown.ebon_might.remains>4|buff.essence_burst.react&set_bonus.tww2_4pc)&!variable.pool_for_id&(buff.imminent_destruction.up|essence.deficit<=2|buff.essence_burst.up|variable.ebon_might_pandemic_threshold>0)
    -- Note: Ignoring target_if, as it will hit everything in the area of the primary target.
    if S.Eruption:IsReady() and ((Player:BuffRemains(S.EbonMightSelfBuff) > S.Eruption:ExecuteTime() or Player:EssenceDeficitP() == 0 or Player:EssenceBurst() == Player:MaxEssenceBurst() and S.EbonMight:CooldownRemains() > 4 or Player:BuffUp(S.EssenceBurstBuff) and Player:HasTier("TWW2", 4)) and not VarPoolForID and (Player:BuffUp(S.ImminentDestructionBuff) or Player:EssenceDeficitP() <= 2 or Player:BuffUp(S.EssenceBurstBuff) or VarEbonMightPandemicThreshold > 0)) then
      if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption main 24"; end
    end
    -- blistering_scales,target_if=target.role.tank,if=!evoker.scales_up&buff.ebon_might_self.down
    if S.BlisteringScales:IsReady() and (BlisteringScalesCheck() == 0 and Player:BuffDown(S.EbonMightSelfBuff)) then
      if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales main 26"; end
    end
    -- run_action_list,name=filler
    local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
    -- pool if nothing else to do
    if CastAnnotated(S.Pool, false, "WAIT") then return "Pool Resources"; end
  end
end

local function Init()
  S.FireBreathDebuff:RegisterAuraTracking()
  S.PrescienceBuff:RegisterAuraTracking()

  HR.Print("Augmentation Evoker rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(1473, APL, Init);

-- Profile Notes:
-- 1. TODO: Handle allied_virtual_cd_time, if even possible.
-- 2. Since we can't handle allied_virtual_cd_time, we'll just assume phrases using it are always true and its '.remains' value is always 0.
-- 3. variable.wingleader_force_timings appears to function a setting value. This setting is not yet implemented, so leaving it at the default of false.

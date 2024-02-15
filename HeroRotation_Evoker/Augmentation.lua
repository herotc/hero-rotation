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
local max           = math.max
local min           = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Evoker.Augmentation
local I = Item.Evoker.Augmentation

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AshesoftheEmbersoul:ID(),
  I.BalefireBranch:ID(),
  I.BeacontotheBeyond:ID(),
  I.BelorrelostheSuncaller:ID(),
  I.IrideusFragment:ID(),
  I.MirrorofFracturedTomorrows:ID(),
  I.NymuesUnravelingSpindle:ID(),
  I.SpoilsofNeltharus:ID(),
}

-- Trinket Objects and Variables
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

local T1ID = Trinket1:ID()
local T1Spell = Trinket1:OnUseSpell()
local T1Range = (T1Spell and T1Spell.MaximumRange > 0 and T1Spell.MaximumRange <= 100) and T1Spell.MaximumRange or 100
local T2ID = Trinket2:ID()
local T2Spell = Trinket2:OnUseSpell()
local T2Range = (T2Spell and T2Spell.MaximumRange > 0 and T2Spell.MaximumRange <= 100) and T2Spell.MaximumRange or 100
local VarTrinket1Exclude = T1ID == I.RubyWhelpShell:ID() or T1ID == I.WhisperingIncarnateIcon:ID()
local VarTrinket2Exclude = T2ID == I.RubyWhelpShell:ID() or T2ID == I.WhisperingIncarnateIcon:ID()
local VarTrinket1Manual = T1ID == I.NymuesUnravelingSpindle:ID()
local VarTrinket2Manual = T2ID == I.NymuesUnravelingSpindle:ID()
local VarTrinket1OGCDCast = T1ID == I.BeacontotheBeyond:ID() or T1ID == I.BelorrelostheSuncaller:ID()
local VarTrinket2OGCDCast = T2ID == I.BeacontotheBeyond:ID() or T2ID == I.BelorrelostheSuncaller:ID()
local VarTrinket1Buffs = Trinket1:HasUseBuff() and not VarTrinket1Exclude
local VarTrinket2Buffs = Trinket2:HasUseBuff() and not VarTrinket2Exclude
local VarTrinket1Sync = (VarTrinket1Buffs and (Trinket1:Cooldown() % 120 == 0)) and 1 or 0.5
local VarTrinket2Sync = (VarTrinket2Buffs and (Trinket2:Cooldown() % 120 == 0)) and 1 or 0.5
local VarTrinketPriority = 2
local VarDamageTrinketPriority = 2

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Evoker.Commons,
  Augmentation = HR.GUISettings.APL.Evoker.Augmentation
}

-- Rotation Variables
local PrescienceTargets = {}
local MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
local FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax = Player:GCD() + 0.25
local VarEssenceBurstMaxStacks = 2
local VarSpamHeal = true
local VarMinOpenerDelay = Settings.Augmentation.MinOpenerDelay
local VarOpenerDelay = 0
local VarOpenerCDs = false
local InDungeon

-- Stun Interrupts
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

-- Reset variables after fights
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
  T1ID = Trinket1:ID()
  T1Spell = Trinket1:OnUseSpell()
  T1Range = (T1Spell and T1Spell.MaximumRange > 0 and T1Spell.MaximumRange <= 100) and T1Spell.MaximumRange or 100
  T2ID = Trinket2:ID()
  T2Spell = Trinket2:OnUseSpell()
  T2Range = (T2Spell and T2Spell.MaximumRange > 0 and T2Spell.MaximumRange <= 100) and T2Spell.MaximumRange or 100
  VarTrinket1Exclude = T1ID == I.RubyWhelpShell:ID() or T1ID == I.WhisperingIncarnateIcon:ID()
  VarTrinket2Exclude = T2ID == I.RubyWhelpShell:ID() or T2ID == I.WhisperingIncarnateIcon:ID()
  VarTrinket1Manual = T1ID == I.NymuesUnravelingSpindle:ID()
  VarTrinket2Manual = T2ID == I.NymuesUnravelingSpindle:ID()
  VarTrinket1OGCDCast = T1ID == I.BeacontotheBeyond:ID() or T1ID == I.BelorrelostheSuncaller:ID()
  VarTrinket2OGCDCast = T2ID == I.BeacontotheBeyond:ID() or T2ID == I.BelorrelostheSuncaller:ID()
  VarTrinket1Buffs = Trinket1:HasUseBuff() and not VarTrinket1Exclude
  VarTrinket2Buffs = Trinket2:HasUseBuff() and not VarTrinket2Exclude
  VarTrinket1Sync = (VarTrinket1Buffs and (Trinket1:Cooldown() % 120 == 0)) and 1 or 0.5
  VarTrinket2Sync = (VarTrinket2Buffs and (Trinket2:Cooldown() % 120 == 0)) and 1 or 0.5
  VarTrinketPriority = 2
  VarDamageTrinketPriority = 2
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
  FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

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
  local Group
  -- Always return true in a raid, as the odds of running out of dps to buff is low.
  if UnitInRaid("player") then
    return true
  -- In a 5-man, only suggest Prescience on a dps without the Prescience buff.
  elseif UnitInParty("player") then
    for unitID, Char in pairs(Unit.Party) do
      if Char:Exists() and UnitGroupRolesAssigned(unitID) == "DAMAGER" then
        if Char:BuffRemains(S.PrescienceBuff) <= Player:GCDRemains() then
          return true
        end
      end
    end
    return false
  -- Always return false when playing solo.
  else
    return false
  end
end

local function TemporalWoundCalc(Enemies)
  -- variable,name=temp_wound,value=debuff.temporal_wound.remains,target_if=max:debuff.temporal_wound.remains
  local HighestTW = 0
  for _, CycleUnit in pairs(Enemies) do
    local Remains = CycleUnit:DebuffRemains(S.TemporalWoundDebuff)
    HighestTW = max(Remains, HighestTW)
  end
  return HighestTW
end

local function EMSelfBuffDuration()
  return S.EbonMightSelfBuff:BaseDuration() * (1 + (Player:CritChancePct() / 100))
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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=spam_heal,default=1,op=reset
  VarSpamHeal = true
  -- variable,name=minimum_opener_delay,op=reset,default=0
  VarMinOpenerDelay = Settings.Augmentation.MinOpenerDelay
  -- variable,name=opener_delay,value=variable.minimum_opener_delay,if=!talent.interwoven_threads
  -- variable,name=opener_delay,value=variable.minimum_opener_delay+variable.opener_delay,if=talent.interwoven_threads
  if not S.InterwovenThreads:IsAvailable() then
    VarOpenerDelay = VarMinOpenerDelay
  else
    VarOpenerDelay = VarMinOpenerDelay + (VarOpenerDelay or 0)
  end
  -- variable,name=opener_cds_detected,op=reset,default=0
  VarOpenerCDs = false
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_manual,value=trinket.1.is.nymues_unraveling_spindle
  -- variable,name=trinket_2_manual,value=trinket.2.is.nymues_unraveling_spindle
  -- variable,name=trinket_1_ogcd_cast,value=trinket.1.is.beacon_to_the_beyond|trinket.1.is.belorrelos_the_suncaller
  -- variable,name=trinket_2_ogcd_cast,value=trinket.2.is.beacon_to_the_beyond|trinket.2.is.belorrelos_the_suncaller
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)&!variable.trinket_1_exclude
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)&!variable.trinket_2_exclude
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%120=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%120=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown&!variable.trinket_2_exclude|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(0.5+trinket.2.has_buff.intellect*3+trinket.2.has_buff.mastery)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(0.5+trinket.1.has_buff.intellect*3+trinket.1.has_buff.mastery)*(variable.trinket_1_sync)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=trinket.1.is.nymues_unraveling_spindle&trinket.2.has_buff.intellect|trinket.2.is.nymues_unraveling_spindle&!trinket.1.has_buff.intellect,if=(trinket.1.is.nymues_unraveling_spindle|trinket.2.is.nymues_unraveling_spindle)&(variable.trinket_1_buffs&variable.trinket_2_buffs)
  -- Note1: Moved all trinket variable handling to variable declaration and PLAYER_EQUIPMENT_CHANGED.
  -- Note2: Can't handle some of these conditions, such as has_buff.intellect, has_buff.mastery, and ilvl. As such, defaulting priority to Trinket2. The dps difference should be negligible.
  -- Manually added: Group buff check
  if S.BlessingoftheBronze:IsCastable() and Everyone.GroupBuffMissing(S.BlessingoftheBronzeBuff) then
    if Cast(S.BlessingoftheBronze, Settings.Commons.GCDasOffGCD.BlessingOfTheBronze) then return "blessing_of_the_bronze precombat"; end
  end
  -- Manually added: source_of_magic,if=group&active_dot.source_of_magic=0
  if S.SourceofMagic:IsCastable() and SoMCheck() then
    if Cast(S.SourceofMagic) then return "source_of_magic precombat"; end
  end
  -- Manually added: black_attunement,if=buff.black_attunement.down
  if S.BlackAttunement:IsCastable() and Player:BuffDown(S.BlackAttunementBuff) then
    if Cast(S.BlackAttunement) then return "black_attunement precombat"; end
  end
  -- Manually added: bronze_attunement,if=buff.bronze_attunement.down&buff.black_attunement.up&!buff.black_attunement.mine
  if S.BronzeAttunement:IsCastable() and (Player:BuffDown(S.BronzeAttunementBuff) and Player:BuffUp(S.BlackAttunementBuff) and not Player:BuffUp(S.BlackAttunementBuff, false)) then
    if Cast(S.BronzeAttunement) then return "bronze_attunement precombat"; end
  end
  -- blistering_scales,target_if=target.role.tank
  if S.BlisteringScales:IsCastable() and (BlisteringScalesCheck() < 10) then
    if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales precombat 2"; end
  end
  -- living_flame
  if S.LivingFlame:IsCastable() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame precombat 10"; end
  end
end

local function EbonLogic()
  -- ebon_might
  if S.EbonMight:IsReady() then
    if Cast(S.EbonMight, Settings.Augmentation.GCDasOffGCD.EbonMight) then return "ebon_might ebon_logic 2"; end
  end
end

local function OpenerFiller()
  -- variable,name=opener_delay,value=variable.opener_delay>?variable.minimum_opener_delay,if=!variable.opener_cds_detected&evoker.allied_cds_up>0
  -- Note: Can't track others' CDs.
  if not VarOpenerCDs then
    VarOpenerDelay = min(VarOpenerDelay, VarMinOpenerDelay)
  end
  -- variable,name=opener_delay,value=variable.opener_delay-1
  VarOpenerDelay = VarOpenerDelay - 1
  -- variable,name=opener_cds_detected,value=1,if=!variable.opener_cds_detected&evoker.allied_cds_up>0
  if not VarOpenerCDs then
    VarOpenerCDs = true
  end
  -- variable,name=opener_delay,value=variable.opener_delay-2,if=equipped.nymues_unraveling_spindle&trinket.nymues_unraveling_spindle.cooldown.up
  if I.NymuesUnravelingSpindle:IsEquipped() and I.NymuesUnravelingSpindle:CooldownRemains() <= Player:GCD() then
    VarOpenerDelay = VarOpenerDelay - 2
  end
  -- living_flame,if=active_enemies=1|talent.pupil_of_alexstrasza
  if S.LivingFlame:IsReady() and (EnemiesCount8ySplash == 1 or S.PupilofAlexstrasza:IsAvailable()) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame opener_filler 4"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike opener_filler 6"; end
  end
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=nymues_unraveling_spindle,if=cooldown.breath_of_eons.remains<=3&(trinket.1.is.nymues_unraveling_spindle&variable.trinket_priority=1|trinket.2.is.nymues_unraveling_spindle&variable.trinket_priority=2)|(cooldown.fire_breath.remains<=4|cooldown.upheaval.remains<=4)&cooldown.breath_of_eons.remains>10&!debuff.temporal_wound.up&(trinket.1.is.nymues_unraveling_spindle&variable.trinket_priority=2|trinket.2.is.nymues_unraveling_spindle&variable.trinket_priority=1)
    if I.NymuesUnravelingSpindle:IsEquipped() and I.NymuesUnravelingSpindle:CooldownRemains() <= Player:GCD() and (S.BreathofEons:CooldownRemains() <= 3 and (T1ID == I.NymuesUnravelingSpindle:ID() and VarTrinketPriority == 1 or T2ID == I.NymuesUnravelingSpindle:ID() and VarTrinketPriority == 2) or (S.FireBreath:CooldownRemains() <= 4 or S.Upheaval:CooldownRemains() <= 4) and S.BreathofEons:CooldownRemains() > 10 and Target:DebuffDown(S.TemporalWoundDebuff) and (T1ID == I.NymuesUnravelingSpindle:ID() and VarTrinketPriority == 2 or T2ID == I.NymuesUnravelingSpindle:ID() and VarTrinketPriority == 1)) then
      if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle items 2"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(debuff.temporal_wound.up|variable.trinket_2_buffs&!trinket.2.cooldown.up&(prev_gcd.1.fire_breath|prev_gcd.1.upheaval)&buff.ebon_might_self.up)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    if Trinket1:IsReady() and (VarTrinket1Buffs and not VarTrinket1Manual and (Target:DebuffUp(S.TemporalWoundDebuff) or VarTrinket2Buffs and Trinket2:CooldownDown() and (Player:PrevGCDP(1, S.FireBreath) or Player:PrevGCDP(1, S.Upheaval)) and Player:BuffUp(S.EbonMightSelfBuff)) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= FightRemains) then
      if Cast(Trinket1, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(T1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 4"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(debuff.temporal_wound.up|variable.trinket_1_buffs&!trinket.1.cooldown.up&(prev_gcd.1.fire_breath|prev_gcd.1.upheaval)&buff.ebon_might_self.up)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    if Trinket2:IsReady() and (VarTrinket2Buffs and not VarTrinket2Manual and (Target:DebuffUp(S.TemporalWoundDebuff) or VarTrinket1Buffs and Trinket1:CooldownDown() and (Player:PrevGCDP(1, S.FireBreath) or Player:PrevGCDP(1, S.Upheaval)) and Player:BuffUp(S.EbonMightSelfBuff)) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= FightRemains) then
      if Cast(Trinket2, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(T2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 6"; end
    end
    -- azure_strike,if=cooldown.item_cd_1141.up&(variable.trinket_1_ogcd_cast&trinket.1.cooldown.up&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains)|variable.trinket_2_ogcd_cast&trinket.2.cooldown.up&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains))
    -- Note: Skipping this line
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains)&(gcd.remains>0.1|!variable.trinket_1_ogcd_cast)
    if Trinket1:IsReady() and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown())) then
      if Cast(Trinket1, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(T1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 10"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains)&(gcd.remains>0.1|!variable.trinket_2_ogcd_cast)
    if Trinket2:IsReady() and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown())) then
      if Cast(Trinket2, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(T2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 12"; end
    end
  end
  -- use_item,slot=main_hand,use_off_gcd=1,if=gcd.remains>=gcd.max*0.6
  if Settings.Commons.Enabled.Items then
    local MainHandOnUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
    if MainHandOnUse and MainHandOnUse:IsReady() then
      if Cast(MainHandOnUse, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(MainHandRange)) then return "use_item for main_hand (" .. MainHandOnUse:Name() .. ") items 22"; end
    end
  end
end

local function FB()
  -- tip_the_scales,if=cooldown.fire_breath.ready&buff.ebon_might_self.up
  if CDsON() and S.TipTheScales:IsCastable() and (S.FireBreath:CooldownUp() and Player:BuffUp(S.EbonMightSelfBuff)) then
    if Cast(S.TipTheScales, Settings.Commons.GCDasOffGCD.TipTheScales) then return "tip_the_scales fb 2"; end
  end
  local FBEmpower = 0
  -- Note: Using Player:EmpowerCastTime() in place of duration in the below lines. Intention seems to be whether we can get the spell off before Ebom Might ends.
  if S.FireBreath:IsCastable() then
    if I.NeltharionsCalltoChaos:IsEquipped() then
      -- fire_breath,empower_to=1,target_if=target.time_to_die>16,if=buff.ebon_might_self.remains>duration&equipped.neltharions_call_to_chaos
      if Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(1) and Target:TimeToDie() > 16 then
        FBEmpower = 1
      -- fire_breath,empower_to=2,target_if=target.time_to_die>12,if=buff.ebon_might_self.remains>duration&equipped.neltharions_call_to_chaos
      elseif Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(2) and Target:TimeToDie() > 12 then
        FBEmpower = 2
      -- fire_breath,empower_to=3,target_if=target.time_to_die>8,if=buff.ebon_might_self.remains>duration&equipped.neltharions_call_to_chaos
      elseif (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(3) or Player:BuffUp(S.TipTheScales) and not S.FontofMagic:IsAvailable()) and Target:TimeToDie() > 8 then
        FBEmpower = 3
      end
    end
    -- fire_breath,empower_to=4,target_if=target.time_to_die>4,if=talent.font_of_magic&(buff.ebon_might_self.remains>duration|buff.tip_the_scales.up)
    -- Note: Moved max empower to the bottom so it doesn't get overwritten.
    if not I.NeltharionsCalltoChaos:IsEquipped() then
      -- fire_breath,empower_to=3,target_if=target.time_to_die>8,if=(buff.ebon_might_self.remains>duration|buff.tip_the_scales.up)&!equipped.neltharions_call_to_chaos
      -- fire_breath,empower_to=2,target_if=target.time_to_die>12,if=buff.ebon_might_self.remains>duration&!equipped.neltharions_call_to_chaos
      -- fire_breath,empower_to=1,target_if=target.time_to_die>16,if=buff.ebon_might_self.remains>duration&!equipped.neltharions_call_to_chaos
      -- Note: Re-ordered below so a lower empower can't overwrite a higher empower.
      if Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(1) and Target:TimeToDie() > 16 then
        FBEmpower = 1
      elseif Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(2) and Target:TimeToDie() > 12 then
        FBEmpower = 2
      elseif (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(3) or Player:BuffUp(S.TipTheScales) and not S.FontofMagic:IsAvailable()) and Target:TimeToDie() > 8 then
        FBEmpower = 3
      end
    end
    -- Max empower moved from above.
    if S.FontofMagic:IsAvailable() and (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(4) or Player:BuffUp(S.TipTheScales)) and Target:TimeToDie() > 4 then
      FBEmpower = 4
    end
    if FBEmpower > 0 then
      if CastAnnotated(S.FireBreath, false, FBEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower_to=" .. FBEmpower .. " fb 4"; end
    end
  end
end

local function Filler()
  -- living_flame,if=(buff.ancient_flame.up|mana>=200000|!talent.dream_of_spring|variable.spam_heal=0)&(active_enemies=1|talent.pupil_of_alexstrasza)
  if S.LivingFlame:IsReady() and ((Player:BuffUp(S.AncientFlameBuff) or Player:Mana() >= 200000 or not S.DreamofSpring:IsAvailable() or VarSpamHeal == 0) and (EnemiesCount8ySplash == 1 or S.PupilofAlexstrasza:IsAvailable())) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame filler 2"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike filler 4"; end
  end
end

-- APL Main
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

    -- Calculate GCDMax
    GCDMax = Player:GCD() + 0.25

    -- Are we running a dungeon (non-raid)
    InDungeon = Player:IsInParty() and not Player:IsInRaid()
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.Quell, Settings.Commons.OffGCDasOffGCD.Quell, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: unravel
    if S.Unravel:IsReady() then
      if Cast(S.Unravel, Settings.Commons.GCDasOffGCD.Unravel, nil, not Target:IsSpellInRange(S.Unravel)) then return "unravel main 2"; end
    end
    -- variable,name=temp_wound,value=debuff.temporal_wound.remains,target_if=max:debuff.temporal_wound.remains
    VarTempWound = TemporalWoundCalc(Enemies25y)
    -- prescience,target_if=min:debuff.prescience.remains+1000*(target=self&active_allies>2)+1000*target.spec.augmentation,if=(full_recharge_time<=gcd.max*3|cooldown.ebon_might.remains<=gcd.max*3&(buff.ebon_might_self.remains-gcd.max*3)<=buff.ebon_might_self.duration*0.4|variable.temp_wound>=(gcd.max+action.eruption.cast_time)|fight_remains<=30)&(buff.trembling_earth.stack+evoker.prescience_buffs)<=(5+(full_recharge_time<=gcd.max*3))
    -- Note: Not handling target_if, as user will have to decide on a target.
    if S.Prescience:IsCastable() and PrescienceCheck() and ((S.Prescience:FullRechargeTime() <= GCDMax * 3 or S.EbonMight:CooldownRemains() <= GCDMax * 3 and (Player:BuffRemains(S.EbonMightSelfBuff) - GCDMax * 3) <= EMSelfBuffDuration() * 0.4 or VarTempWound >= (GCDMax + S.Eruption:CastTime()) or FightRemains <= 30) and (Player:BuffStack(S.TremblingEarthBuff) + S.PrescienceBuff:AuraActiveCount()) <= (5 + num(S.Prescience:FullRechargeTime() <= GCDMax * 3))) then
      if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience main 4"; end
    end
    -- call_action_list,name=ebon_logic,if=(buff.ebon_might_self.remains-cast_time)<=buff.ebon_might_self.duration*0.4&(active_enemies>0|raid_event.adds.in<=3)&(evoker.prescience_buffs>=2&time<=10|evoker.prescience_buffs>=3|fight_style.dungeonroute|fight_style.dungeonslice|buff.ebon_might_self.remains>=action.ebon_might.cast_time|active_allies<=2)
    if (Player:BuffRemains(S.EbonMightSelfBuff) - S.EbonMight:CastTime()) <= EMSelfBuffDuration() * 0.4 and (S.PrescienceBuff:AuraActiveCount() >= 2 and HL.CombatTime() <= 10 or S.PrescienceBuff:AuraActiveCount() >= 3 or InDungeon or Player:BuffRemains(S.EbonMightSelfBuff) >= S.EbonMight:CastTime() or AllyCount() <= 2) then
      local ShouldReturn = EbonLogic(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=opener_filler,if=variable.opener_delay>0&!fight_style.dungeonroute
    if VarOpenerDelay > 0 and HL.CombatTime() < VarOpenerDelay and not InDungeon then
      local ShouldReturn = OpenerFiller(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for OpenerFiller()"; end
    end
    -- potion,if=debuff.temporal_wound.up&buff.ebon_might_self.up
    if Settings.Commons.Enabled.Potions and (Target:DebuffUp(S.TemporalWoundDebuff) and Player:BuffUp(S.EbonMightSelfBuff)) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- call_action_list,name=items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- deep_breath
    if S.DeepBreath:IsCastable() then
      if Cast(S.DeepBreath, Settings.Augmentation.GCDasOffGCD.BreathOfEons, nil, not Target:IsInRange(50)) then return "deep_breath main 8"; end
    end
    -- call_action_list,name=fb,if=cooldown.time_skip.up&talent.time_skip&!talent.interwoven_threads
    if S.TimeSkip:IsAvailable() and S.TimeSkip:CooldownUp() and not S.InterwovenThreads:IsAvailable() then
      local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
    end
    -- upheaval,target_if=target.time_to_die>duration+0.2,empower_to=1,if=buff.ebon_might_self.remains>duration&cooldown.time_skip.up&talent.time_skip&!talent.interwoven_threads
    if S.Upheaval:IsCastable() and (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(1) and S.TimeSkip:IsAvailable() and S.TimeSkip:CooldownUp() and not S.InterwovenThreads:IsAvailable()) then
      if CastAnnotated(S.Upheaval, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "upheaval empower_to=1 main 10"; end
    end
    -- breath_of_eons,if=((cooldown.ebon_might.remains<=4|buff.ebon_might_self.up)&target.time_to_die>15&raid_event.adds.in>15&(!equipped.nymues_unraveling_spindle|trinket.nymues_unraveling_spindle.cooldown.remains>=10|fight_remains<30|trinket.1.is.nymues_unraveling_spindle&variable.trinket_priority=2|trinket.2.is.nymues_unraveling_spindle&variable.trinket_priority=1)|fight_remains<30)&!fight_style.dungeonroute,line_cd=117
    -- breath_of_eons,if=evoker.allied_cds_up>0&((cooldown.ebon_might.remains<=4|buff.ebon_might_self.up)&target.time_to_die>15&(!equipped.nymues_unraveling_spindle|trinket.nymues_unraveling_spindle.cooldown.remains>=10|fight_remains<30|trinket.1.is.nymues_unraveling_spindle&variable.trinket_priority=2|trinket.2.is.nymues_unraveling_spindle&variable.trinket_priority=1)|fight_remains<30)&fight_style.dungeonroute
    -- Note: Combined both lines. Only difference seems to be a line_cd if not in a dungeon.
    if CDsON() and S.BreathofEons:IsCastable() and (S.BreathofEons:TimeSinceLastCast() >= 117 or InDungeon) and ((S.EbonMight:CooldownRemains() <= 4 or Player:BuffUp(S.EbonMightSelfBuff)) and Target:TimeToDie() > 15 and (not I.NymuesUnravelingSpindle:IsEquipped() or I.NymuesUnravelingSpindle:CooldownRemains() >= 10 or FightRemains < 30 or T1ID == I.NymuesUnravelingSpindle:ID() and VarTrinketPriority == 2 or T2ID == I.NymuesUnravelingSpindle:ID() and VarTrinketPriority == 1) or FightRemains < 30) then
      if Cast(S.BreathofEons, Settings.Augmentation.GCDasOffGCD.BreathOfEons, nil, not Target:IsInRange(50)) then return "breath_of_eons main 12"; end
    end
    -- living_flame,if=buff.leaping_flames.up&cooldown.fire_breath.up&fight_style.dungeonroute
    if S.LivingFlame:IsReady() and (Player:BuffUp(S.LeapingFlamesBuff) and S.FireBreathDebuff:CooldownUp() and InDungeon) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 14"; end
    end
    -- living_flame,if=cooldown.breath_of_eons.up&evoker.allied_cds_up=0&target.time_to_die>15&fight_style.dungeonroute
    if S.LivingFlame:IsReady() and (S.BreathofEons:CooldownUp() and Target:TimeToDie() > 15 and InDungeon) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 15"; end
    end
    -- call_action_list,name=fb,if=(raid_event.adds.remains>13|raid_event.adds.in>20|evoker.allied_cds_up>0|!raid_event.adds.exists)
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
    -- upheaval,target_if=target.time_to_die>duration+0.2,empower_to=1,if=buff.ebon_might_self.remains>duration&(raid_event.adds.remains>13|!raid_event.adds.exists|raid_event.adds.in>20)
    if S.Upheaval:IsCastable() and (Player:BuffRemains(S.EbonMightSelfBuff) > Player:EmpowerCastTime(1)) then
      if CastAnnotated(S.Upheaval, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "upheaval empower_to=1 main 16"; end
    end
    -- time_skip,if=(cooldown.fire_breath.remains+cooldown.upheaval.remains+cooldown.prescience.full_recharge_time)>=35
    if CDsON() and S.TimeSkip:IsCastable() and (S.FireBreath:CooldownRemains() + S.Upheaval:CooldownRemains() + S.Prescience:FullRechargeTime() > 35) then
      if Cast(S.TimeSkip, Settings.Augmentation.GCDasOffGCD.TimeSkip) then return "time_skip main 18"; end
    end
    -- emerald_blossom,if=talent.dream_of_spring&buff.essence_burst.up&(variable.spam_heal=2|variable.spam_heal=1&!buff.ancient_flame.up)&(buff.ebon_might_self.up|essence.deficit=0|buff.essence_burst.stack=buff.essence_burst.max_stack&cooldown.ebon_might.remains>4)
    if S.EmeraldBlossom:IsReady() and (S.DreamofSpring:IsAvailable() and Player:BuffUp(S.EssenceBurstBuff) and (VarSpamHeal == 2 or VarSpamHeal == 1 and Player:BuffDown(S.AncientFlameBuff)) and (Player:BuffUp(S.EbonMightSelfBuff) or Player:EssenceDeficit() == 0 or Player:BuffStack(S.EssenceBurstBuff) == VarEssenceBurstMaxStacks and S.EbonMight:CooldownRemains() > 4)) then
      if Cast(S.EmeraldBlossom, Settings.Augmentation.GCDasOffGCD.EmeraldBlossom) then return "emerald_blossom main 20"; end
    end
    -- eruption,if=buff.ebon_might_self.remains>execute_time|essence.deficit=0|buff.essence_burst.stack=buff.essence_burst.max_stack&cooldown.ebon_might.remains>4
    if S.Eruption:IsReady() and (Player:BuffRemains(S.EbonMightSelfBuff) > S.Eruption:ExecuteTime() or Player:EssenceDeficit() == 0 or Player:BuffStack(S.EssenceBurstBuff) == VarEssenceBurstMaxStacks and S.EbonMight:CooldownRemains() > 4) then
      if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption main 22"; end
    end
    -- blistering_scales,target_if=target.role.tank,if=!evoker.scales_up&buff.ebon_might_self.down
    if S.BlisteringScales:IsCastable() and (BlisteringScalesCheck() == 0 and Player:BuffDown(S.EbonMightSelfBuff)) then
      if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales main 24"; end
    end
    -- emerald_blossom,if=!buff.ebon_might_self.up&talent.ancient_flame&talent.scarlet_adaptation&!talent.dream_of_spring&!buff.ancient_flame.up&active_enemies=1
    if S.EmeraldBlossom:IsReady() and (Player:BuffDown(S.EbonMightSelfBuff) and S.AncientFlame:IsAvailable() and S.ScarletAdaptation:IsAvailable() and not S.DreamofSpring:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and EnemiesCount8ySplash == 1) then
      if Cast(S.EmeraldBlossom, Settings.Augmentation.GCDasOffGCD.EmeraldBlossom) then return "emerald_blossom main 26"; end
    end
    -- verdant_embrace,if=!buff.ebon_might_self.up&talent.ancient_flame&talent.scarlet_adaptation&!buff.ancient_flame.up&(!talent.dream_of_spring|mana>=200000)&active_enemies=1
    if S.VerdantEmbrace:IsReady() and (Player:BuffDown(S.EbonMightSelfBuff) and S.AncientFlame:IsAvailable() and S.ScarletAdaptation:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and (not S.DreamofSpring:IsAvailable() or Player:Mana() >= 200000) and EnemiesCount8ySplash == 1) then
      if Cast(S.VerdantEmbrace, Settings.Augmentation.GCDasOffGCD.VerdantEmbrace) then return "verdant_embrace main 28"; end
    end
    -- run_action_list,name=filler
    local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
    -- pool if nothing else to do
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool"; end
  end
end

local function Init()
  S.PrescienceBuff:RegisterAuraTracking()

  HR.Print("Augmentation Evoker rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(1473, APL, Init);

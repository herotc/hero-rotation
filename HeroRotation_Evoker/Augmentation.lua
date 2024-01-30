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

-- Trinket Objects
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

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
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Manual, VarTrinket2Manual
local VarSpamHeal = true
local VarMinOpenerDelay = Settings.Augmentation.MinOpenerDelay
local VarOpenerDelay = 0
local VarOpenerCDs = false

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
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
  FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

local function PrescienceCheck()
end

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
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    Group = Player
  end

  if Group == Player then
    return Player:BuffStack(S.BlisteringScalesBuff)
  else
    for unitID, Char in pairs(Group) do
      if Char:Exists() and (Char:IsTankingAoE(8) or Char:IsTanking(Target)) and UnitGroupRolesAssigned(unitID) == "TANK" then
        return Char:BuffStack(S.BlisteringScalesBuff)
      end
    end
  end

  return 0
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
  -- variable,name=trinket_1_exclude,value=trinket.1.is.irideus_fragment|trinket.1.is.balefire_branch|trinket.1.is.ashes_of_the_embersoul|trinket.1.is.nymues_unraveling_spindle|trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.spoils_of_neltharus
  local T1ID = Trinket1:ID()
  VarTrinket1Exclude = T1ID == I.IrideusFragment:ID() or T1ID == I.BalefireBranch:ID() or T1ID == I.AshesoftheEmbersoul:ID() or T1ID == I.NymuesUnravelingSpindle:ID() or T1ID == I.MirrorofFracturedTomorrows:ID() or T1ID == I.SpoilsofNeltharus:ID()
  -- variable,name=trinket_2_exclude,value=trinket.2.is.irideus_fragment|trinket.2.is.balefire_branch|trinket.2.is.ashes_of_the_embersoul|trinket.2.is.nymues_unraveling_spindle|trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.spoils_of_neltharus
  local T2ID = Trinket2:ID()
  VarTrinket2Exclude = T2ID == I.IrideusFragment:ID() or T2ID == I.BalefireBranch:ID() or T2ID == I.AshesoftheEmbersoul:ID() or T2ID == I.NymuesUnravelingSpindle:ID() or T2ID == I.MirrorofFracturedTomorrows:ID() or T2ID == I.SpoilsofNeltharus:ID()
  -- variable,name=trinket_1_manual,value=trinket.1.is.irideus_fragment|trinket.1.is.balefire_branch|trinket.1.is.ashes_of_the_embersoul|trinket.1.is.nymues_unraveling_spindle|trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.spoils_of_neltharus|trinket.1.is.beacon_to_the_beyond|trinket.1.is.belorrelos_the_suncaller
  VarTrinket1Manual = VarTrinket1Exclude or T1ID == I.BeacontotheBeyond:ID() or T1ID == I.BelorrelostheSuncaller:ID()
  -- variable,name=trinket_2_manual,value=trinket.2.is.irideus_fragment|trinket.2.is.balefire_branch|trinket.2.is.ashes_of_the_embersoul|trinket.2.is.nymues_unraveling_spindle|trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.spoils_of_neltharus|trinket.2.is.beacon_to_the_beyond|trinket.2.is.belorrelos_the_suncaller
  VarTrinket2Manual = VarTrinket2Exclude or T2ID == I.BeacontotheBeyond:ID() or T2ID == I.BelorrelostheSuncaller:ID()
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
  -- ebon_might,if=raid_event.adds.remains>10|raid_event.adds.in>20
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
  if I.NymuesUnravelingSpindle:IsEquippedAndReady() then
    VarOpenerDelay = VarOpenerDelay - 2
  end
  -- use_item,name=nymues_unraveling_spindle,if=cooldown.breath_of_eons.remains<=3
  if Settings.Commons.Enabled.Trinkets and I.NymuesUnravelingSpindle:IsEquippedAndReady() and (S.BreathofEons:CooldownRemains() <= 3) then
    if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle opener_filler 2"; end
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
    -- use_item,name=nymues_unraveling_spindle,if=cooldown.breath_of_eons.remains<=3
    if I.NymuesUnravelingSpindle:IsEquippedAndReady() and (S.BreathofEons:CooldownRemains() <= 3) then
      if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle items 2"; end
    end
    if Target:DebuffUp(S.TemporalWoundDebuff) or FightRemains <= 30 and Player:BuffUp(S.EbonMightSelfBuff) then
      -- use_item,name=irideus_fragment,if=debuff.temporal_wound.up|fight_remains<=30&buff.ebon_might_self.up
      if I.IrideusFragment:IsEquippedAndReady() then
        if Cast(I.IrideusFragment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "irideus_fragment items 4"; end
      end
      -- use_item,name=ashes_of_the_embersoul,if=debuff.temporal_wound.up|fight_remains<=30&buff.ebon_might_self.up
      if I.AshesoftheEmbersoul:IsEquippedAndReady() then
        if Cast(I.AshesoftheEmbersoul, nil, Settings.Commons.DisplayStyle.Trinkets) then return "ashes_of_the_embersoul items 6"; end
      end
      -- use_item,name=mirror_of_fractured_tomorrows,if=debuff.temporal_wound.up|fight_remains<=30&buff.ebon_might_self.up
      if I.MirrorofFracturedTomorrows:IsEquippedAndReady() then
        if Cast(I.MirrorofFracturedTomorrows, nil, Settings.Commons.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows items 8"; end
      end
      -- use_item,name=balefire_branch,if=debuff.temporal_wound.up|fight_remains<=30&buff.ebon_might_self.up
      if I.BalefireBranch:IsEquippedAndReady() then
        if Cast(I.BalefireBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "balefire_branch items 10"; end
      end
    end
    -- use_item,name=spoils_of_neltharus,if=buff.spoils_of_neltharus_mastery.up&(!((trinket.1.is.irideus_fragment|trinket.1.is.mirror_of_fractured_tomorrows)&trinket.1.cooldown.up|(trinket.is.2.irideus_fragment|trinket.2.is.mirror_of_fractured_tomorrows)&trinket.2.cooldown.up)|!(time%%120<=20|fight_remains>=190&fight_remains<=250&&time%%60<=25|fight_remains<=25))
    if I.SpoilsofNeltharus:IsEquippedAndReady() and (Player:BuffUp(S.SpoilsofNeltharusMastery) and (not ((Trinket1:ID() == I.IrideusFragment:ID() or Trinket1:ID() == I.MirrorofFracturedTomorrows:ID()) and Trinket1:CooldownUp() or (Trinket2:ID() == I.IrideusFragment:ID() or Trinket2:ID() == I.MirrorofFracturedTomorrows:ID()) and Trinket2:CooldownUp()) or not (HL.CombatTime() % 120 <= 20 or FightRemains >= 190 and FightRemains <= 250 and HL.CombatTime() % 60 <= 25 or FightRemains <= 25))) then
      if Cast(I.SpoilsofNeltharus, nil, Settings.Commons.DisplayStyle.Trinkets) then return "spoils_of_neltharus items 12"; end
    end
    -- use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=gcd.remains>0.1&((!debuff.temporal_wound.up&((trinket.1.cooldown.remains>=20|!variable.trinket_1_exclude)&(trinket.2.cooldown.remains>=20|!variable.trinket_2_exclude))|variable.trinket_1_exclude&variable.trinket_2_exclude))&(!raid_event.adds.exists|raid_event.adds.up|spell_targets.beacon_to_the_beyond>=5|raid_event.adds.in>60)|fight_remains<20
    if I.BeacontotheBeyond:IsEquippedAndReady() and ((Target:DebuffDown(S.TemporalWoundDebuff) and ((Trinket1:CooldownRemains() >= 20 or not VarTrinket1Exclude) and (Trinket2:CooldownRemains() >= 20 or not VarTrinket2Exclude)) or VarTrinket1Exclude and VarTrinket2Exclude) or FightRemains < 20) then
      if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond items 14"; end
    end
    -- use_item,name=belorrelos_the_suncaller,use_off_gcd=1,if=gcd.remains>0.1&((!debuff.temporal_wound.up&((trinket.1.cooldown.remains>=20|!variable.trinket_1_exclude)&(trinket.2.cooldown.remains>=20|!variable.trinket_2_exclude))|variable.trinket_1_exclude&variable.trinket_2_exclude))&(!raid_event.adds.exists|raid_event.adds.up|spell_targets.beacon_to_the_beyond>=5|raid_event.adds.in>60)|fight_remains<20
    if I.BelorrelostheSuncaller:IsEquippedAndReady() and ((Target:DebuffDown(S.TemporalWoundDebuff) and ((Trinket1:CooldownRemains() >= 20 or not VarTrinket1Exclude) and (Trinket2:CooldownRemains() >= 20 or not VarTrinket2Exclude)) or VarTrinket1Exclude and VarTrinket2Exclude) or FightRemains < 20) then
      if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller items 16"; end
    end
    -- use_item,slot=trinket1,if=!debuff.temporal_wound.up&(cooldown.breath_of_eons.remains>=30|!variable.trinket_2_exclude)&!variable.trinket_1_manual
    if Trinket1:IsReady() and (Target:DebuffDown(S.TemporalWoundDebuff) and (S.BreathofEons:CooldownRemains() >= 30 or not VarTrinket2Exclude) and not VarTrinket1Manual) then
      if Cast(Trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "use_item for " .. Trinket1:Name() .. " items 18"; end
    end
    -- use_item,slot=trinket2,if=!debuff.temporal_wound.up&(cooldown.breath_of_eons.remains>=30|!variable.trinket_1_exclude)&!variable.trinket_2_manual
    if Trinket2:IsReady() and (Target:DebuffDown(S.TemporalWoundDebuff) and (S.BreathofEons:CooldownRemains() >= 30 or not VarTrinket1Exclude) and not VarTrinket2Manual) then
      if Cast(Trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "use_item for " .. Trinket2:Name() .. " items 20"; end
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
  if S.FireBreath:IsCastable() then
    -- fire_breath,empower_to=1,target_if=target.time_to_die>16,if=buff.ebon_might_self.remains>duration&equipped.neltharions_call_to_chaos
    if Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 16 then
      FBEmpower = 1
    -- fire_breath,empower_to=2,target_if=target.time_to_die>12,if=buff.ebon_might_self.remains>duration&equipped.neltharions_call_to_chaos
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 12 then
      FBEmpower = 2
    -- fire_breath,empower_to=3,target_if=target.time_to_die>8,if=buff.ebon_might_self.remains>duration&equipped.neltharions_call_to_chaos
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 8 then
      FBEmpower = 3
    -- fire_breath,empower_to=4,target_if=target.time_to_die>4,if=talent.font_of_magic&(buff.ebon_might_self.remains>duration|buff.tip_the_scales.up)
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 4 then
      FBEmpower = 4
    -- fire_breath,empower_to=3,target_if=target.time_to_die>8,if=(buff.ebon_might_self.remains>duration|buff.tip_the_scales.up)&!equipped.neltharions_call_to_chaos
    elseif Player:BuffUp(S.TipTheScales) and not I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 8 then
      FBEmpower = 3
    -- fire_breath,empower_to=2,target_if=target.time_to_die>12,if=buff.ebon_might_self.remains>duration&!equipped.neltharions_call_to_chaos
    -- Note: Moved below the following APL line to allow our if statement to flow properly.
    -- fire_breath,empower_to=1,target_if=target.time_to_die>16,if=buff.ebon_might_self.remains>duration&!equipped.neltharions_call_to_chaos
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and not I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 16 then
      FBEmpower = 1
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and not I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 12 then
      FBEmpower = 2
    elseif Player:BuffRemains(S.EbonMightSelfBuff) > S.FireBreath:ExecuteTime() and not I.NeltharionsCalltoChaos:IsEquipped() and Target:TimeToDie() > 8 then
      FBEmpower = 3
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
    if S.Prescience:IsCastable() and ((S.Prescience:FullRechargeTime() <= GCDMax * 3 or S.EbonMight:CooldownRemains() <= GCDMax * 3 and (Player:BuffRemains(S.EbonMightSelfBuff) - GCDMax * 3) <= EMSelfBuffDuration() * 0.4 or VarTempWound >= (GCDMax + S.Eruption:CastTime()) or FightRemains <= 30) and (Player:BuffStack(S.TremblingEarthBuff) + S.PrescienceBuff:AuraActiveCount()) <= (5 + num(S.Prescience:FullRechargeTime() <= GCDMax * 3))) then
      if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience main 4"; end
    end
    -- call_action_list,name=ebon_logic,if=(buff.ebon_might_self.remains-cast_time)<=buff.ebon_might_self.duration*0.4&(active_enemies>0|raid_event.adds.in<=3)&(evoker.prescience_buffs>=2&time<=10|evoker.prescience_buffs>=3|buff.ebon_might_self.remains>=action.ebon_might.cast_time|active_allies<=2)
    if (Player:BuffRemains(S.EbonMightSelfBuff) - S.EbonMight:CastTime()) <= EMSelfBuffDuration() * 0.4 and (S.PrescienceBuff:AuraActiveCount() >= 2 and HL.CombatTime() <= 10 or S.PrescienceBuff:AuraActiveCount() >= 3 or Player:BuffRemains(S.EbonMightSelfBuff) >= S.EbonMight:CastTime() or AllyCount() <= 2) then
      local ShouldReturn = EbonLogic(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=opener_filler,if=variable.opener_delay>0
    if VarOpenerDelay > 0 and HL.CombatTime() < VarOpenerDelay then
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
    -- breath_of_eons,if=(cooldown.ebon_might.remains<=4|buff.ebon_might_self.up)&target.time_to_die>15&raid_event.adds.in>15&(!equipped.nymues_unraveling_spindle|trinket.nymues_unraveling_spindle.cooldown.remains>=10|fight_remains<30)|fight_remains<30,line_cd=117
    if CDsON() and S.BreathofEons:IsCastable() and S.BreathofEons:TimeSinceLastCast() >= 117 and ((S.EbonMight:CooldownRemains() <= 4 or Player:BuffUp(S.EbonMightSelfBuff)) and Target:TimeToDie() > 15 and (not I.NymuesUnravelingSpindle:IsEquipped() or I.NymuesUnravelingSpindle:CooldownRemains() >= 10 or FightRemains < 30) or FightRemains < 30) then
      if Cast(S.BreathofEons, Settings.Augmentation.GCDasOffGCD.BreathOfEons, nil, not Target:IsInRange(50)) then return "breath_of_eons main 12"; end
    end
    -- living_flame,if=buff.leaping_flames.up&cooldown.fire_breath.up
    if S.LivingFlame:IsReady() and (Player:BuffUp(S.LeapingFlamesBuff) and S.FireBreathDebuff:CooldownUp()) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 14"; end
    end
    -- call_action_list,name=fb,if=(raid_event.adds.remains>13|evoker.allied_cds_up>0|!raid_event.adds.exists)
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
    -- upheaval,target_if=target.time_to_die>duration+0.2,empower_to=1,if=buff.ebon_might_self.remains>duration&(raid_event.adds.remains>13|!raid_event.adds.exists)
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

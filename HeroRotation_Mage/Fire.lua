--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CastLeft   = HR.CastLeft
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
local FBCast, PBCast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local max        = math.max
local ceil       = math.ceil
-- WoW API
local Delay      = C_Timer.After
-- Commons
local Mage       = HR.Commons.Mage

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Fire
local I = Item.Mage.Fire

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW GladiatorsBadge
  I.ForgedGladiatorsBadge:ID(),
  I.PrizedGladiatorsBadge:ID(),
  -- Other TWW Trinkets
  I.FlarendosPilotLight:ID(),
  I.FunhouseLens:ID(),
  I.HouseOfCards:ID(),
  I.QuickwickCandlestick:ID(),
  I.SignetOfThePriory:ID(),
  I.SoullettingRuby:ID(),
  -- Older Items
  I.HyperthreadWristwraps:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  CommonsDS = HR.GUISettings.APL.Mage.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Mage.CommonsOGCD,
  Fire = HR.GUISettings.APL.Mage.Fire
}

--- ===== Rotation Variables =====
local VarKindlingReduction = (S.Kindling:IsAvailable()) and 0.4 or 1
local VarSKBMaxStack = 10
local VarImprovedScorchMaxStack = 2
local VarCastRemainsTime = 1
local VarPoolingTime = 10 + 10 * num(S.FrostfireBolt:IsAvailable())
local VarFFCombustionFlamestrike = 999
local VarFFFillerFlamestrike = 999
local VarSFCombustionFlamestrike = 999
local VarSFFillerFlamestrike = 999
local VarCombustionPrecastTime = 0
local CombustionUp
local CombustionDown
local CombustionRemains
local HeatingUp, HotStreak = false, false
local ShiftingPowerTickReduction = 3
local EnemiesCount8ySplash,EnemiesCount16ySplash
local Enemies8ySplash,Enemies16ySplash
local BossFightRemains = 11111
local FightRemains = 11111
local Bolt = S.FrostfireBolt:IsAvailable() and S.FrostfireBolt or S.Fireball

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarCombustionOnUse
local VarTreacherousTransmitterPrecombatCast
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

  VarCombustionOnUse = I.ForgedGladiatorsBadge:IsEquipped() or I.PrizedGladiatorsBadge:IsEquipped() or I.SignetOfThePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped() or I.SoullettingRuby:IsEquipped() or I.FunhouseLens:IsEquipped() or I.HouseOfCards:IsEquipped() or I.FlarendosPilotLight:IsEquipped()

  VarTreacherousTransmitterPrecombatCast = 12
end
SetTrinketVariables()

--- ===== Precombat Variables =====
local function SetPrecombatVariables()
  VarCastRemainsTime = 1
  VarPoolingTime = 10 + 10 * num(S.FrostfireBolt:IsAvailable())
  VarFFCombustionFlamestrike = 999
  VarFFFillerFlamestrike = 999
  if S.FrostfireBolt:IsAvailable() then
    VarFFCombustionFlamestrike = 4 + num(S.Firefall:IsAvailable()) * 99 - num(S.MarkoftheFirelord:IsAvailable() and S.Quickflame:IsAvailable() and S.Firefall:IsAvailable()) * 96 + num(not S.MarkoftheFirelord:IsAvailable() and not S.Quickflame:IsAvailable() and not S.FlamePatch:IsAvailable()) * 99 + num(S.MarkoftheFirelord:IsAvailable() and not (S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable())) * 2 + num(not S.MarkoftheFirelord:IsAvailable() and (S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable())) * 3
    VarFFFillerFlamestrike = 4 + num(S.Firefall:IsAvailable()) * 99 - num(S.MarkoftheFirelord:IsAvailable() and S.FlamePatch:IsAvailable() and S.Firefall:IsAvailable()) * 96 + num(not S.MarkoftheFirelord:IsAvailable() and not S.Quickflame:IsAvailable() and not S.FlamePatch:IsAvailable()) * 99 + num(S.MarkoftheFirelord:IsAvailable() and not (S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable())) * 2 + num(not S.MarkoftheFirelord:IsAvailable() and (S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable())) * 3
  end
  VarSFCombustionFlamestrike = 999
  VarSFFillerFlamestrike = 999
  if S.SpellfireSpheres:IsAvailable() then
    VarSFCombustionFlamestrike = 5 + num(not S.MarkoftheFirelord:IsAvailable()) * 99 + num(not (S.FlamePatch:IsAvailable() or S.Quickflame:IsAvailable()) and S.Firefall:IsAvailable()) * 99 + num(S.Firefall:IsAvailable()) + num(not (S.FlamePatch:IsAvailable() or S.Quickflame:IsAvailable())) * 3
    VarSFFillerFlamestrike = 4 + num(S.Firefall:IsAvailable()) + num(not (S.FlamePatch:IsAvailable() or S.Quickflame:IsAvailable())) + num(not S.MarkoftheFirelord:IsAvailable() and not (S.FlamePatch:IsAvailable() or S.Quickflame:IsAvailable())) * 2 + num(not S.MarkoftheFirelord:IsAvailable() and not (S.FlamePatch:IsAvailable() or S.Quickflame:IsAvailable()) and S.Firefall:IsAvailable()) * 99
  end
end
SetPrecombatVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.Pyroblast:RegisterInFlight()
  S.Fireball:RegisterInFlight()
  S.FrostfireBolt:RegisterInFlightEffect(468655)
  S.FrostfireBolt:RegisterInFlight()
  S.Meteor:RegisterInFlightEffect(351140)
  S.Meteor:RegisterInFlight()
  S.PhoenixFlames:RegisterInFlightEffect(257542)
  S.PhoenixFlames:RegisterInFlight()
  S.Pyroblast:RegisterInFlight(S.CombustionBuff)
  S.Fireball:RegisterInFlight(S.CombustionBuff)
  S.FrostfireBolt:RegisterInFlight(S.CombustionBuff)
  Bolt = S.FrostfireBolt:IsAvailable() and S.FrostfireBolt or S.Fireball
  SetPrecombatVariables()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.Pyroblast:RegisterInFlight()
S.Fireball:RegisterInFlight()
S.FrostfireBolt:RegisterInFlightEffect(468655)
S.FrostfireBolt:RegisterInFlight()
S.Meteor:RegisterInFlightEffect(351140)
S.Meteor:RegisterInFlight()
S.PhoenixFlames:RegisterInFlightEffect(257542)
S.PhoenixFlames:RegisterInFlight()
S.Pyroblast:RegisterInFlight(S.CombustionBuff)
S.Fireball:RegisterInFlight(S.CombustionBuff)
S.FrostfireBolt:RegisterInFlight(S.CombustionBuff)

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

--- ===== Helper Functions =====
local function ScorchExecuteActive()
  return Target:HealthPercentage() <= 30
end

local function FirestarterActive()
  return S.Firestarter:IsAvailable() and Target:HealthPercentage() >= 90
end

local function FirestarterRemains()
  return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90) or 0) or 0
end

local function ImprovedScorchActive()
  return S.ImprovedScorch:IsAvailable() and Target:HealthPercentage() < 30
end

local function ShiftingPowerFullReduction()
  return ShiftingPowerTickReduction * S.ShiftingPower:BaseDuration() / S.ShiftingPower:BaseTickTime()
end

local function FreeCastAvailable()
  local FSInFlight = FirestarterActive() and (num(S.Pyroblast:InFlight()) + num(Bolt:InFlight())) or 0
  FSInFlight = FSInFlight + num(S.PhoenixFlames:InFlight() or Player:PrevGCDP(1, S.PhoenixFlames))
  return Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.HyperthermiaBuff) or (Player:BuffUp(S.HeatingUpBuff) and (Target:HealthPercentage() < 30 and Player:IsCasting(S.Scorch) or FirestarterActive() and (Player:IsCasting(Bolt) or FSInFlight > 0)))
end

-- Currently unused. Left as a commented function for potential future use.
-- local function UnitsWithIgnite(enemies)
--   local WithIgnite = 0
--   for _, CycleUnit in pairs(enemies) do
--     if CycleUnit:DebuffUp(S.IgniteDebuff) then
--       WithIgnite = WithIgnite + 1
--     end
--   end
--   return WithIgnite
-- end

local function HotStreakInFlight()
  local Count = 0
  -- Check Pyroblast in flight
  if S.Pyroblast:InFlight() then Count = Count + 1 end
  -- Check Phoenix Flames in flight
  if S.PhoenixFlames:InFlight() then Count = Count + 1 end
  -- Check Frostfire Bolt or Fireball in flight
  if Bolt:InFlight() then Count = Count + 1 end
  return Count
end

--- ===== Rotation Functions =====
local function Precombat()
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
    if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- variable,name=cast_remains_time,value=0.3
  -- variable,name=pooling_time,value=10+10*talent.frostfire_bolt
  -- variable,name=ff_combustion_flamestrike,if=talent.frostfire_bolt,value=4+talent.firefall*99-(talent.mark_of_the_firelord&talent.quickflame&talent.firefall)*96+(!talent.mark_of_the_firelord&!talent.quickflame&!talent.flame_patch)*99+(talent.mark_of_the_firelord&!(talent.quickflame|talent.flame_patch))*2+(!talent.mark_of_the_firelord&(talent.quickflame|talent.flame_patch))*3
  -- variable,name=ff_filler_flamestrike,if=talent.frostfire_bolt,value=4+talent.firefall*99-(talent.mark_of_the_firelord&talent.flame_patch&talent.firefall)*96+(!talent.mark_of_the_firelord&!talent.quickflame&!talent.flame_patch)*99+(talent.mark_of_the_firelord&!(talent.quickflame|talent.flame_patch))*2+(!talent.mark_of_the_firelord&(talent.quickflame|talent.flame_patch))*3
  -- variable,name=sf_combustion_flamestrike,if=talent.spellfire_spheres,value=5+(!talent.mark_of_the_firelord)*99+(!(talent.flame_patch|talent.quickflame)&talent.firefall)*99+talent.firefall+(!(talent.flame_patch|talent.quickflame))*3
  -- variable,name=sf_filler_flamestrike,if=talent.spellfire_spheres,value=4+talent.firefall+!talent.mark_of_the_firelord+!(talent.flame_patch|talent.quickflame)+(!talent.mark_of_the_firelord&!(talent.flame_patch|talent.quickflame))*2+(!talent.mark_of_the_firelord&!(talent.flame_patch|talent.quickflame)&talent.firefall)*99
  -- variable,name=treacherous_transmitter_precombat_cast,value=12,if=equipped.treacherous_transmitter
  -- Note: Handled in SetPrecombatVariables.
  -- use_item,name=treacherous_transmitter
  if I.TreacherousTransmitter:IsEquippedAndReady() then
    if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat 4"; end
  end
  -- use_item,name=ingenious_mana_battery,target=self
  if I.IngeniousManaBattery:IsEquippedAndReady() then
    if Cast(I.IngeniousManaBattery, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "ingenious_mana_battery precombat 6"; end
  end
  -- snapshot_stats
  -- mirror_image
  if CDsON() and Settings.Fire.MirrorImagesBeforePull and S.MirrorImage:IsCastable() then
    if Cast(S.MirrorImage, Settings.Fire.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 8"; end
  end
  -- frostfire_bolt,if=talent.frostfire_bolt
  if S.FrostfireBolt:IsReady() then
    if Cast(S.FrostfireBolt, nil, nil, not Target:IsSpellInRange(S.FrostfireBolt)) then return "frostfire_bolt precombat 10"; end
  end
  -- pyroblast
  if S.Pyroblast:IsReady() then
    -- Check if we have a free cast available
    if FreeCastAvailable() then
      if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast precombat 12"; end
    else
      -- Use regular Cast if not a free cast
      if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast precombat 14"; end
    end
  end
end

local function CDs()
  -- phoenix_flames,if=time=0&!talent.firestarter
  -- Moved to Precombat, since we can't hit time=0 otherwise.
  -- variable,name=combustion_precast_time,value=(talent.frostfire_bolt*(cooldown.meteor.ready+action.fireball.cast_time*!improved_scorch.active+action.scorch.cast_time*improved_scorch.active)+talent.spellfire_spheres*action.scorch.cast_time)-variable.cast_remains_time
  VarCombustionPrecastTime = (num(S.FrostfireBolt:IsAvailable()) * (num(S.Meteor:CooldownUp()) + Bolt:CastTime() * num(not ImprovedScorchActive()) + S.Scorch:CastTime() * num(ImprovedScorchActive())) + num(S.SpellfireSpheres:IsAvailable()) * S.Scorch:CastTime()) - VarCastRemainsTime
  -- potion,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<35
  if Settings.Commons.Enabled.Potions and (not S.SunKingsBlessing:IsAvailable() and S.Combustion:CooldownRemains() <= VarCombustionPrecastTime or CombustionRemains > 7 or BossFightRemains < 35) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 2"; end
    end
  end
  -- Note: All of the following lines use this same condition set, so wrapping them all.
  if not S.SunKingsBlessing:IsAvailable() and S.Combustion:CooldownRemains() <= VarCombustionPrecastTime or CombustionRemains > 7 or BossFightRemains < 20 then
    -- use_item,name=neural_synapse_enhancer,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
    if Settings.Commons.Enabled.Items and I.NeuralSynapseEnhancer:IsEquippedAndReady() then
      if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Items) then return "neural_synapse_enhancer cds 4"; end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,effect_name=gladiators_badge,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.ForgedGladiatorsBadge:IsEquippedAndReady() then
        if Cast(I.ForgedGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (forged) cds 6"; end
      end
      if I.PrizedGladiatorsBadge:IsEquippedAndReady() then
        if Cast(I.PrizedGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (prized) cds 8"; end
      end
      -- use_item,name=flarendos_pilot_light,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.FlarendosPilotLight:IsEquippedAndReady() then
        if Cast(I.FlarendosPilotLight, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "flarendos_pilot_light cds 10"; end
      end
      -- use_item,name=house_of_cards,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.HouseOfCards:IsEquippedAndReady() then
        if Cast(I.HouseOfCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "house_of_cards cds 12"; end
      end
      -- use_item,name=signet_of_the_priory,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.SignetOfThePriory:IsEquippedAndReady() then
        if Cast(I.SignetOfThePriory, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "signet_of_the_priory cds 14"; end
      end
      -- use_item,name=funhouse_lens,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.FunhouseLens:IsEquippedAndReady() then
        if Cast(I.FunhouseLens, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "funhouse_lens cds 16"; end
      end
      -- use_item,name=soulletting_ruby,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.SoullettingRuby:IsEquippedAndReady() then
        if Cast(I.SoullettingRuby, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soulletting_ruby cds 18"; end
      end
      -- use_item,name=quickwick_candlestick,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
      if I.QuickwickCandlestick:IsEquippedAndReady() then
        if Cast(I.QuickwickCandlestick, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "quickwick_candlestick cds 20"; end
      end
    end
  end
  -- use_item,name=hyperthread_wristwraps,if=hyperthread_wristwraps.fire_blast>=2&buff.combustion.remains&action.fire_blast.charges=0
  if Settings.Commons.Enabled.Items and I.HyperthreadWristwraps:IsEquippedAndReady() then
    local HTWWCount = num(Mage.FBTracker.PrevOne == S.FireBlast:ID()) + num(Mage.FBTracker.PrevTwo == S.FireBlast:ID()) + num(Mage.FBTracker.PrevThree == S.FireBlast:ID())
    if HTWWCount >= 2 and CombustionUp and S.FireBlast:Charges() == 0 then
      if Cast(I.HyperthreadWristwraps, nil, Settings.CommonsDS.DisplayStyle.Items) then return "hyperthread_wristwraps cds 22"; end
    end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~=13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for "..ItemToUse:Name().." cds 24"; end
      end
    end
  end
  if CDsON() then
    -- blood_fury,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
    if S.BloodFury:IsCastable() and (not S.SunKingsBlessing:IsAvailable() and S.Combustion:CooldownRemains() <= VarCombustionPrecastTime or CombustionRemains > 7 or BossFightRemains < 20) then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 26"; end
    end
    -- berserking,if=buff.combustion.remains>7|fight_remains<20
    if S.Berserking:IsCastable() and (CombustionRemains > 7 or BossFightRemains < 20) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 28"; end
    end
    -- fireblood,if=buff.combustion.remains>7|fight_remains<10
    if S.Fireblood:IsCastable() and (CombustionRemains > 7 or BossFightRemains < 10) then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 30"; end
    end
    -- ancestral_call,if=!talent.sun_kings_blessing&cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20
    if S.AncestralCall:IsCastable() and (not S.SunKingsBlessing:IsAvailable() and S.Combustion:CooldownRemains() <= VarCombustionPrecastTime or CombustionRemains > 7 or BossFightRemains < 20) then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 32"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down&(cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.remains>7|fight_remains<20)
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs.
end

local function FFCombustion()
  -- From lower in the function: fire_blast
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (Player:GCDRemains() < Player:GCD() and CombustionUp and not HotStreak and HotStreakInFlight() + num(HeatingUp) * num(Player:GCDRemains() > 0) < 2 and (Player:BuffDown(S.FuryoftheSunKingBuff) or Player:IsCasting(S.Pyroblast))) then
    if FBCast(S.FireBlast) then return "fire_blast ff_combustion 2"; end
  end
  -- combustion,use_off_gcd=1,use_while_casting=1,if=buff.combustion.down&(action.fireball.executing&action.fireball.execute_remains<variable.cast_remains_time|action.meteor.in_flight&action.meteor.in_flight_remains<variable.cast_remains_time|action.pyroblast.executing&action.pyroblast.execute_remains<variable.cast_remains_time|action.scorch.executing&action.scorch.execute_remains<variable.cast_remains_time)
  if S.Combustion:IsReady() and (CombustionDown and (Player:IsCasting(Bolt) and Bolt:ExecuteRemains() < VarCastRemainsTime or S.Meteor:InFlight() and S.Meteor:InFlightRemains() < VarCastRemainsTime or Player:IsCasting(S.Pyroblast) and S.Pyroblast:ExecuteRemains() < VarCastRemainsTime or Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < VarCastRemainsTime)) then
    if Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion ff_combustion 4"; end
  end
  -- meteor,if=buff.combustion.down|buff.combustion.remains>2
  if S.Meteor:IsReady() and (CombustionDown or CombustionRemains > 2) then
    if Cast(S.Meteor, Settings.Fire.GCDasOffGCD.Meteor, nil, not Target:IsInRange(40)) then return "meteor ff_combustion 6"; end
  end
  -- scorch,if=buff.combustion.down&(buff.heat_shimmer.react&talent.improved_scorch|improved_scorch.active)&!prev_gcd.1.scorch
  if S.Scorch:IsReady() and (CombustionDown and (Player:BuffUp(S.HeatShimmerBuff) and S.ImprovedScorch:IsAvailable() or ImprovedScorchActive()) and not Player:PrevGCDP(1, S.Scorch)) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch ff_combustion 8"; end
  end
  -- flamestrike,if=buff.fury_of_the_sun_king.up&active_enemies>=variable.ff_combustion_flamestrike
  if AoEON() and S.Flamestrike:IsReady() and (Player:BuffUp(S.FuryoftheSunKingBuff) and EnemiesCount8ySplash >= VarFFCombustionFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike ff_combustion 10"; end
  end
  -- pyroblast,if=buff.fury_of_the_sun_king.up
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.FuryoftheSunKingBuff)) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast ff_combustion 12"; end
  end
  -- fireball,if=buff.combustion.down
  if Bolt:IsReady() and (CombustionDown) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "fireball ff_combustion 14"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&gcd.remains<gcd.max&buff.combustion.up&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react*(gcd.remains>0)<2&(buff.fury_of_the_sun_king.down|action.pyroblast.executing)
  -- Note: Moved to top of function, as this is a use_while_casting.
  -- flamestrike,if=buff.hyperthermia.react&active_enemies>=variable.ff_combustion_flamestrike
  -- flamestrike,if=buff.hot_streak.react&active_enemies>=variable.ff_combustion_flamestrike
  -- Note: Combinining above lines.
  if AoEON() and S.Flamestrike:IsReady() and (FreeCastAvailable() and EnemiesCount8ySplash >= VarFFCombustionFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike ff_combustion 16"; end
  end
  -- pyroblast,if=buff.hyperthermia.react
  -- pyroblast,if=buff.hot_streak.react
  -- Note: Combinining above lines.
  if S.Pyroblast:IsReady() and (FreeCastAvailable()) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast ff_combustion 18"; end
  end
  -- phoenix_flames,if=buff.excess_frost.up&(!action.pyroblast.in_flight|!buff.heating_up.react)
  if S.PhoenixFlames:IsCastable() and (Player:BuffUp(S.ExcessFrostBuff) and (not S.Pyroblast:InFlight() or not HeatingUp)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames ff_combustion 20"; end
  end
  -- fireball
  if Bolt:IsReady() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "fireball ff_combustion 22"; end
  end
end

local function FFFiller()
  -- meteor,if=cooldown.combustion.remains>variable.pooling_time
  if S.Meteor:IsReady() and (S.Combustion:CooldownRemains() > VarPoolingTime) then
    if Cast(S.Meteor, Settings.Fire.GCDasOffGCD.Meteor, nil, not Target:IsInRange(40)) then return "meteor ff_filler 2"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&buff.heating_up.react&action.fireball.executing&action.fireball.execute_remains<0.5&(cooldown.combustion.remains>variable.pooling_time|talent.sun_kings_blessing)
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&!buff.heating_up.react&!buff.hot_streak.react&action.scorch.executing&action.scorch.execute_remains<0.5&(cooldown.combustion.remains>variable.pooling_time|talent.sun_kings_blessing)
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&charges=3
  -- Note: Using VarCastRemainsTime instead of 0.5 here. We've set it to 1 to allow for better human reaction time.
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (
    (HeatingUp and Player:IsCasting(Bolt) and Bolt:ExecuteRemains() < VarCastRemainsTime and (S.Combustion:CooldownRemains() > VarPoolingTime or S.SunKingsBlessing:IsAvailable())) or
    (not HeatingUp and not HotStreak and Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < VarCastRemainsTime and (S.Combustion:CooldownRemains() > VarPoolingTime or S.SunKingsBlessing:IsAvailable())) or
    (S.FireBlast:Charges() == 3)
  ) then
    if FBCast(S.FireBlast) then return "fire_blast ff_filler 4"; end
  end
  -- scorch,if=(improved_scorch.active|buff.heat_shimmer.react&talent.improved_scorch)&debuff.improved_scorch.remains<3*gcd.max&!prev_gcd.1.scorch
  if S.Scorch:IsReady() and ((ImprovedScorchActive() or Player:BuffUp(S.HeatShimmerBuff) and S.ImprovedScorch:IsAvailable()) and Target:DebuffRemains(S.ImprovedScorchDebuff) < 3 * Player:GCD() and not Player:PrevGCDP(1, S.Scorch)) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch ff_filler 6"; end
  end
  -- flamestrike,if=buff.fury_of_the_sun_king.up&active_enemies>=variable.ff_filler_flamestrike
  -- flamestrike,if=buff.hyperthermia.react&active_enemies>=variable.ff_filler_flamestrike
  -- flamestrike,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies>=variable.ff_filler_flamestrike
  -- flamestrike,if=buff.hot_streak.react&active_enemies>=variable.ff_filler_flamestrike
  if AoEON() and S.Flamestrike:IsReady() and (
    (Player:BuffUp(S.FuryoftheSunKingBuff) and EnemiesCount8ySplash >= VarFFFillerFlamestrike) or
    (Player:BuffUp(S.HyperthermiaBuff) and EnemiesCount8ySplash >= VarFFFillerFlamestrike) or
    (Player:PrevGCDP(1, S.Scorch) and HeatingUp and EnemiesCount8ySplash >= VarFFFillerFlamestrike) or
    (HotStreak and EnemiesCount8ySplash >= VarFFFillerFlamestrike)
  ) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike ff_filler 8"; end
  end
  -- pyroblast,if=buff.fury_of_the_sun_king.up
  -- pyroblast,if=buff.hyperthermia.react
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react
  -- pyroblast,if=buff.hot_streak.react
  if S.Pyroblast:IsReady() and (
    (Player:BuffUp(S.FuryoftheSunKingBuff)) or
    (Player:BuffUp(S.HyperthermiaBuff)) or
    (Player:PrevGCDP(1, S.Scorch) and HeatingUp) or
    (HotStreak)
  ) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast ff_filler 10"; end
  end
  -- shifting_power,if=cooldown.combustion.remains>10&!firestarter.active
  if S.ShiftingPower:IsReady() and (S.Combustion:CooldownRemains() > 10 and not FirestarterActive()) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ff_filler 12"; end
  end
  -- fireball,if=talent.sun_kings_blessing&buff.frostfire_empowerment.react
  if Bolt:IsReady() and (S.SunKingsBlessing:IsAvailable() and Player:BuffUp(S.FrostfireEmpowermentBuff)) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "fireball ff_filler 14"; end
  end
  -- phoenix_flames,if=buff.excess_frost.up|talent.sun_kings_blessing
  if S.PhoenixFlames:IsCastable() and (Player:BuffUp(S.ExcessFrostBuff) or S.SunKingsBlessing:IsAvailable()) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames ff_filler 16"; end
  end
  -- scorch,if=talent.sun_kings_blessing&(scorch_execute.active|buff.heat_shimmer.react)
  if S.Scorch:IsReady() and (S.SunKingsBlessing:IsAvailable() and (ScorchExecuteActive() or Player:BuffUp(S.HeatShimmerBuff))) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch ff_filler 18"; end
  end
  -- fireball
  if Bolt:IsReady() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "fireball ff_filler 20"; end
  end
end

local function SFCombustion()
  -- From lower in the function: fire_blast
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (Player:GCDRemains() < Player:GCD() and CombustionUp and not HotStreak and HotStreakInFlight() + num(HeatingUp) * num(Player:GCDRemains() > 0) < 2) then
    if FBCast(S.FireBlast) then return "fire_blast sf_combustion 2"; end
  end
  -- combustion,use_off_gcd=1,use_while_casting=1,if=buff.combustion.down&(action.fireball.executing&action.fireball.execute_remains<variable.cast_remains_time|action.scorch.executing&action.scorch.execute_remains<variable.cast_remains_time)
  if S.Combustion:IsReady() and (CombustionDown and (Player:IsCasting(Bolt) and Bolt:ExecuteRemains() < VarCastRemainsTime or Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < VarCastRemainsTime)) then
    if Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion sf_combustion 4"; end
  end
  -- scorch,if=buff.combustion.down
  if S.Scorch:IsReady() and (CombustionDown) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch sf_combustion 6"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&gcd.remains<gcd.max&buff.combustion.up&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react*(gcd.remains>0)<2
  -- Note: Moved to top of function, as this is a use_while_casting.
  -- flamestrike,if=buff.hyperthermia.react&active_enemies>=variable.sf_combustion_flamestrike
  -- flamestrike,if=buff.hot_streak.react&active_enemies>=variable.sf_combustion_flamestrike
  -- flamestrike,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies>=variable.sf_combustion_flamestrike
  -- Note: Combinining above lines.
  if AoEON() and S.Flamestrike:IsReady() and (FreeCastAvailable() and EnemiesCount8ySplash >= VarSFCombustionFlamestrike or Player:PrevGCDP(1, S.Scorch) and HeatingUp and EnemiesCount8ySplash >= VarSFCombustionFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike sf_combustion 8"; end
  end
  -- pyroblast,if=buff.hyperthermia.react
  -- pyroblast,if=buff.hot_streak.react
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react
  -- Note: Combinining above lines.
  if S.Pyroblast:IsReady() and (FreeCastAvailable() or Player:PrevGCDP(1, S.Scorch) and HeatingUp) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast sf_combustion 10"; end
  end
  -- scorch,if=buff.heat_shimmer.react&!scorch_execute.active
  if S.Scorch:IsReady() and (Player:BuffUp(S.HeatShimmerBuff) and not ScorchExecuteActive()) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch sf_combustion 12"; end
  end
  -- phoenix_flames
  if S.PhoenixFlames:IsCastable() then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames sf_combustion 14"; end
  end
  -- scorch
  if S.Scorch:IsReady() then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch sf_combustion 16"; end
  end
end

local function SFFiller()
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&buff.heating_up.react&buff.hyperthermia.react&cooldown.combustion.remains>variable.pooling_time
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&buff.heating_up.react&action.fireball.executing&action.fireball.execute_remains<0.5&cooldown.combustion.remains>variable.pooling_time
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&!buff.heating_up.react&!buff.hot_streak.react&action.scorch.executing&action.scorch.execute_remains<0.5&cooldown.combustion.remains>variable.pooling_time
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=cooldown_react&charges=3&cooldown.combustion.remains>variable.pooling_time*0.3
  -- fire_blast,use_off_gcd=1,if=active_enemies>=2&cooldown_react&buff.glorious_incandescence.react&!buff.heating_up.react&!buff.hot_streak.react&cooldown.combustion.remains>variable.pooling_time
  -- Note: Using VarCastRemainsTime instead of 0.5 here. We've set it to 1 to allow for better human reaction time.
  if S.FireBlast:IsReady() and (
    (HeatingUp and Player:BuffUp(S.HyperthermiaBuff) and S.Combustion:CooldownRemains() > VarPoolingTime) or
    (HeatingUp and Player:IsCasting(Bolt) and Bolt:ExecuteRemains() < VarCastRemainsTime and S.Combustion:CooldownRemains() > VarPoolingTime) or
    (not HeatingUp and not HotStreak and Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < VarCastRemainsTime and S.Combustion:CooldownRemains() > VarPoolingTime) or
    (S.FireBlast:Charges() == 3 and S.Combustion:CooldownRemains() > VarPoolingTime * 0.3) or
    (EnemiesCount8ySplash >= 2 and Player:BuffUp(S.GloriousIncandescenceBuff) and not HeatingUp and not HotStreak and S.Combustion:CooldownRemains() > VarPoolingTime)
  ) then
    if FBCast(S.FireBlast) then return "fire_blast sf_filler 2"; end
  end
  -- flamestrike,if=buff.hyperthermia.react&active_enemies>=variable.sf_filler_flamestrike
  -- flamestrike,if=buff.hot_streak.react&active_enemies>=variable.sf_filler_flamestrike
  -- flamestrike,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies>=variable.sf_filler_flamestrike
  -- Note: Combinining above lines.
  if AoEON() and S.Flamestrike:IsReady() and (FreeCastAvailable() and EnemiesCount8ySplash >= VarSFFillerFlamestrike or Player:PrevGCDP(1, S.Scorch) and HeatingUp and EnemiesCount8ySplash >= VarSFFillerFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike sf_filler 8"; end
  end
  -- pyroblast,if=buff.hyperthermia.react
  -- pyroblast,if=buff.hot_streak.react&cooldown.combustion.remains>variable.pooling_time*0.3
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&cooldown.combustion.remains>variable.pooling_time*0.3
  if S.Pyroblast:IsReady() and (
    (Player:BuffUp(S.HyperthermiaBuff)) or
    (HotStreak and S.Combustion:CooldownRemains() > VarPoolingTime * 0.3) or
    (Player:PrevGCDP(1, S.Scorch) and HeatingUp and S.Combustion:CooldownRemains() > VarPoolingTime * 0.3)
  ) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast sf_filler 10"; end
  end
  -- shifting_power,if=cooldown.combustion.remains>8
  if S.ShiftingPower:IsReady() and (S.Combustion:CooldownRemains() > 8) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power sf_filler 12"; end
  end
  -- scorch,if=buff.heat_shimmer.react
  if S.Scorch:IsReady() and (Player:BuffUp(S.HeatShimmerBuff)) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch sf_filler 14"; end
  end
  -- meteor,if=active_enemies>=2
  if S.Meteor:IsReady() and (EnemiesCount8ySplash >= 2) then
    if Cast(S.Meteor, Settings.Fire.GCDasOffGCD.Meteor, nil, not Target:IsInRange(40)) then return "meteor sf_filler 16"; end
  end
  -- phoenix_flames
  if S.PhoenixFlames:IsCastable() then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames sf_filler 18"; end
  end
  -- scorch,if=scorch_execute.active
  if S.Scorch:IsReady() and (ScorchExecuteActive()) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch sf_filler 20"; end
  end
  -- fireball
  if Bolt:IsReady() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "fireball sf_filler 22"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Check which cast style we should use for Fire Blast/Pyroblast
  if Settings.Fire.ShowFireBlastLeft then
    FBCast = CastLeft
  else
    FBCast = Cast
  end
  if Settings.Fire.ShowPyroblastLeft then
    PBCast = CastLeft
  else
    PBCast = Cast
  end

  -- Update our enemy tables
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  Enemies16ySplash = Target:GetEnemiesInSplashRange(16)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  else
    EnemiesCount8ySplash = 1
    EnemiesCount16ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Check how many units have ignite
    -- Note: Currently unused. Leaving in as a comment in case we need it later.
    --UnitsWithIgniteCount = UnitsWithIgnite(Enemies8ySplash)

    -- Get our Combustion status
    CombustionUp = Player:BuffUp(S.CombustionBuff)
    CombustionDown = not CombustionUp
    CombustionRemains = CombustionUp and Player:BuffRemains(S.CombustionBuff) or 0

    -- Get our Heating Up and Hot Streak status
    HeatingUp = Player:BuffUp(S.HeatingUpBuff)
    HotStreak = Player:BuffUp(S.HotStreakBuff)
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts, false); if ShouldReturn then return ShouldReturn; end
    -- From CDs(): phoenix_flames,if=time=0&!talent.firestarter
    if HL.CombatTime() < 2 and (Player:IsCasting(S.Pyroblast) or Player:PrevGCDP(1, S.Pyroblast)) and CDsON() then
      if S.PhoenixFlames:IsCastable() and (not S.Firestarter:IsAvailable()) then
        if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames precombat 16"; end
      end
    end
    -- Manually added: Scorch sniping
    if Settings.Fire.UseScorchSniping and AoEON() and Target:HealthPercentage() > 30 then
      for _, CycleUnit in pairs(Enemies16ySplash) do
        if CycleUnit:Exists() and CycleUnit:GUID() ~= Target:GUID() and not CycleUnit:IsDeadOrGhost() and CycleUnit:HealthPercentage() < 30 and CycleUnit:IsSpellInRange(S.Scorch) then
          if HR.CastLeftNameplate(CycleUnit, S.Scorch) then return "Scorch Sniping on "..CycleUnit:Name().." main 2"; end
        end
      end
    end
    -- call_action_list,name=cds,if=!(buff.hot_streak.up&prev_gcd.1.scorch)
    -- Note: Not checking CDsON() here because potions and items are handled in CDs()
    if not (HotStreak and Player:PrevGCDP(1, S.Scorch)) then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=ff_combustion,if=talent.frostfire_bolt&(cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.react|buff.combustion.remains>5)
    if S.FrostfireBolt:IsAvailable() and (S.Combustion:CooldownRemains() <= VarCombustionPrecastTime or CombustionUp or CombustionRemains > 5) then
      local ShouldReturn = FFCombustion(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=sf_combustion,if=cooldown.combustion.remains<=variable.combustion_precast_time|buff.combustion.react|buff.combustion.remains>5
    if not S.FrostfireBolt:IsAvailable() and (S.Combustion:CooldownRemains() <= VarCombustionPrecastTime or CombustionUp or CombustionRemains > 5) then
      local ShouldReturn = SFCombustion(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=ff_filler,if=talent.frostfire_bolt
    if S.FrostfireBolt:IsAvailable() then
      local ShouldReturn = FFFiller(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=sf_filler
    if not S.FrostfireBolt:IsAvailable() then
      local ShouldReturn = SFFiller(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()
  HR.Print("Fire Mage rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(63, APL, Init)

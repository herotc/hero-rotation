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
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CastQueue  = HR.CastQueue
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local strsplit   = strsplit
-- WoW API
local Delay                = C_Timer.After
local GetInventoryItemLink = GetInventoryItemLink
local IsEquippedItemType   = C_Item.IsEquippedItemType

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Frost
local I = Item.DeathKnight.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  CommonsDS = HR.GUISettings.APL.DeathKnight.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DeathKnight.CommonsOGCD,
  Frost = HR.GUISettings.APL.DeathKnight.Frost
}

--- ===== Rotation Variables =====
local VarPillarCD = (S.Icecap:IsAvailable()) and 45 or 60
local MainHandLink, OffHandLink
local MainHandRuneforge, OffHandRuneforge
local UsingRazorice, UsingFallenCrusader
local Var2HCheck
local VarSTPlanning, VarAddsRemain, VarSendingCDs
local VarCDCheck, VarFWFBuffs
local VarRunePooling, VarRPPooling, VarFrostscythePrio
local EnemiesMelee, EnemiesMeleeCount
local BossFightRemains = 11111
local FightRemains = 11111
local Ghoul = HR.Commons.DeathKnight.GhoulTable

--- ===== Pillar Macro Functions =====
-- Frost DK macro optimization for maximizing GCDs during Pillar of Frost windows.
-- Without macros, delays between casting Pillar and the next GCD ability can cost
-- valuable GCDs during Obliteration buff windows, reducing overall DPS.

local function DeterminePillarFollowUp()
  -- Frost DK priority for the GCD ability to pair with Pillar of Frost.
  -- Follows Obliteration guide priorities: KM procs > Rime procs > default abilities.
  
  if Player:BuffUp(S.KillingMachineBuff) then
    if EnemiesMeleeCount >= VarFrostscythePrio and S.Frostscythe:IsReady() then
      return S.Frostscythe
    elseif S.Obliterate:IsReady() then
      return S.Obliterate
    end
  elseif Player:BuffUp(S.RimeBuff) and S.HowlingBlast:IsReady() then
    return S.HowlingBlast
  else
    if EnemiesMeleeCount >= 3 and S.GlacialAdvance:IsReady() then
      return S.GlacialAdvance
    elseif S.FrostStrike:IsReady() then
      return S.FrostStrike
    end
  end
  
  -- Fallback order ensures we always have a GCD ability for the macro
  if S.Obliterate:IsReady() then return S.Obliterate end
  if S.FrostStrike:IsReady() then return S.FrostStrike end
  if S.HowlingBlast:IsReady() then return S.HowlingBlast end
  
  return nil
end

local function ShouldUsePillarMacro()
  -- Only show macros for Obliteration builds where GCD efficiency matters most.
  return S.Obliteration:IsAvailable() and Settings.Frost.UsePillarMacros
end

local function PillarMacro()
  -- Builds Frost DK-specific macro combinations based on hero tree and talent setup.
  -- Hero tree determines additional abilities: Deathbringer adds Reaper's Mark,
  -- Breath builds add Breath of Sindragosa, all builds include Raise Dead + GCD ability.
  
  if not S.PillarofFrost:IsCastable() then return false end
  
  local MacroTable = {S.PillarofFrost}
  
  -- Breath builds: Add Breath when ready (follows APL conditions but bundles with Pillar)
  if S.BreathofSindragosa:IsAvailable() and Player:BuffDown(S.BreathofSindragosa) and S.BreathofSindragosa:IsReady() then
    table.insert(MacroTable, S.BreathofSindragosa)
  end
  
  -- Deathbringer tree: Always pair Pillar with Reaper's Mark due to shared cooldowns
  if Player:HeroTreeID() == 33 and S.ReapersMark:IsReady() then
    table.insert(MacroTable, S.ReapersMark)
  end
  
  -- Universal: Raise Dead as off-GCD filler (can cast without affecting GCD timing)
  if S.RaiseDead:IsCastable() then
    table.insert(MacroTable, S.RaiseDead)
  end
  
  -- Always end with optimal GCD ability for current situation
  local FollowUp = DeterminePillarFollowUp()
  if FollowUp then
    table.insert(MacroTable, FollowUp)
  end
  
  -- Only show macro if we have meaningful abilities beyond just Pillar
  if #MacroTable > 1 then
    local ShouldReturn = CastQueue(unpack(MacroTable))
    if ShouldReturn then
      -- Build debug string showing macro components (up to 4 abilities max)
      local ReturnString = "| " .. MacroTable[2]:Name()
      if #MacroTable > 2 then
        ReturnString = ReturnString .. " | " .. MacroTable[3]:Name()
      end
      if #MacroTable > 3 then
        ReturnString = ReturnString .. " | " .. MacroTable[4]:Name()
      end
      return ReturnString
    end
  end
  
  return false
end

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Duration, VarTrinket2Duration
local VarTrinketPriority, VarDamageTrinketPriority
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
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
  VarTrinket2Spell = T2.Spell
  VarTrinket1Range = T1.Range
  VarTrinket2Range = T2.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(talent.pillar_of_frost&!talent.breath_of_sindragosa&(trinket.1.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.1.cooldown.duration=0))
  VarTrinket1Sync = 0.5
  if Trinket1:HasUseBuff() and (S.PillarofFrost:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and (VarTrinket1CD % VarPillarCD == 0) or S.BreathofSindragosa:IsAvailable() and (120 % VarTrinket1CD == 0)) then
    VarTrinket1Sync = 1
  end
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(talent.pillar_of_frost&!talent.breath_of_sindragosa&(trinket.2.cooldown.duration%%cooldown.pillar_of_frost.duration=0)|talent.breath_of_sindragosa&(cooldown.breath_of_sindragosa.duration%%trinket.2.cooldown.duration=0))
  VarTrinket2Sync = 0.5
  if Trinket2:HasUseBuff() and (S.PillarofFrost:IsAvailable() and not S.BreathofSindragosa:IsAvailable() and (VarTrinket2CD % VarPillarCD == 0) or S.BreathofSindragosa:IsAvailable() and (120 % VarTrinket2CD == 0)) then
    VarTrinket2Sync = 1
  end

  -- variable,name=trinket_1_buffs,value=trinket.1.has_cooldown&!trinket.1.is.improvised_seaforium_pacemaker&(trinket.1.has_use_buff|trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)
  VarTrinket1Buffs = Trinket1:HasCooldown() and not (VarTrinket1ID == I.ImprovisedSeaforiumPacemaker:ID()) and (Trinket1:HasUseBuff() or Trinket1:HasStatAnyDps())
  -- variable,name=trinket_2_buffs,value=trinket.2.has_cooldown&!trinket.2.is.improvised_seaforium_pacemaker&(trinket.2.has_use_buff|trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)
  VarTrinket2Buffs = Trinket2:HasCooldown() and not (VarTrinket2ID == I.ImprovisedSeaforiumPacemaker:ID()) and (Trinket2:HasUseBuff() or Trinket2:HasStatAnyDps())

  -- variable,name=trinket_1_duration,value=trinket.1.proc.any_dps.duration
  VarTrinket1Duration = Trinket1:BuffDuration()
  if VarTrinket1Duration == 0 then
    VarTrinket1Duration = T1.ProcDuration > 0 and T1.ProcDuration or (T1.Cooldown > 0 and T1.Cooldown or 1)
  end
  -- variable,name=trinket_2_duration,value=trinket.2.proc.any_dps.duration
  VarTrinket2Duration = Trinket2:BuffDuration()
  if VarTrinket2Duration == 0 then
    VarTrinket2Duration = T2.ProcDuration > 0 and T2.ProcDuration or (T2.Cooldown > 0 and T2.Cooldown or 1)
  end

  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync)*(1+((trinket.2.ilvl-trinket.1.ilvl)%100)))>((trinket.1.cooldown.duration%variable.trinket_1_duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  VarTrinketPriority = 1
  if (not VarTrinket1Buffs and VarTrinket2Buffs and (Trinket2:HasCooldown() or not Trinket1:HasCooldown())) or 
     (VarTrinket2Buffs and ((VarTrinket2CD / VarTrinket2Duration) * (1.5 + num(Trinket2:HasStrengthBuff())) * VarTrinket2Sync * (1 + ((VarTrinket2Level - VarTrinket1Level) / 100))) > 
     ((VarTrinket1CD / VarTrinket1Duration) * (1.5 + num(Trinket1:HasStrengthBuff())) * VarTrinket1Sync * (1 + ((VarTrinket1Level - VarTrinket2Level) / 100)))) then
    VarTrinketPriority = 2
  end

  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and VarTrinket2Level >= VarTrinket1Level then
    VarDamageTrinketPriority = 2
  end

  -- variable,name=trinket_1_manual,value=0
  VarTrinket1Manual = false
  -- variable,name=trinket_2_manual,value=0
  VarTrinket2Manual = false
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- trinket setup
  SetTrinketVariables()
end

local function Variables()
  -- variable,name=st_planning,op=setif,value=1,value_else=0,condition=active_enemies=1&(!raid_event.adds.exists|!raid_event.adds.in|raid_event.adds.in>15)
  VarSTPlanning = EnemiesMeleeCount == 1 or not AoEON()
  -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|!raid_event.pull.exists&raid_event.adds.remains>5|raid_event.pull.exists&raid_event.adds.in>20)
  VarAddsRemain = EnemiesMeleeCount >= 2 and AoEON()
  -- variable,name=sending_cds,value=(variable.st_planning|variable.adds_remain)
  VarSendingCDs = VarSTPlanning or VarAddsRemain
  -- variable,name=cooldown_check,value=(talent.pillar_of_frost&buff.pillar_of_frost.up)|!talent.pillar_of_frost|fight_remains<20
  VarCDCheck = (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff)) or not S.PillarofFrost:IsAvailable() or FightRemains < 20
  -- variable,name=fwf_buffs,value=(buff.pillar_of_frost.remains<gcd.max|(buff.unholy_strength.up&buff.unholy_strength.remains<gcd.max)|(talent.bonegrinder.rank=2&buff.bonegrinder_frost.up&buff.bonegrinder_frost.remains<gcd.max))&(active_enemies>1|debuff.razorice.stack=5|talent.shattering_blade)
  VarFWFBuffs = (Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() or (Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD()) or (S.Bonegrinder:TalentRank() == 2 and Player:BuffUp(S.BonegrinderFrostBuff) and Player:BuffRemains(S.BonegrinderFrostBuff) < Player:GCD())) and (EnemiesMeleeCount > 1 or Target:DebuffStack(S.RazoriceDebuff) == 5 or S.ShatteringBlade:IsAvailable())
  -- variable,name=rune_pooling,value=hero_tree.deathbringer&cooldown.reapers_mark.remains<6&rune<3&variable.sending_cds
  VarRunePooling = Player:HeroTreeID() == 33 and S.ReapersMark:CooldownRemains() < 6 and Player:Rune() < 3 and VarSendingCDs
  -- variable,name=rp_pooling,value=talent.breath_of_sindragosa&cooldown.breath_of_sindragosa.remains<4*gcd.max&runic_power<60+(35+5*buff.icy_onslaught.up)-(10*rune)&variable.sending_cds
  VarRPPooling = S.BreathofSindragosa:IsAvailable() and S.BreathofSindragosa:CooldownRemains() < 4 * Player:GCD() and Player:RunicPower() < (60 + (35 + 5 * num(Player:BuffUp(S.IcyOnslaughtBuff))) - (10 * Player:Rune())) and VarSendingCDs
  -- variable,name=frostscythe_prio,value=3+(1*(set_bonus.tww3_rider_of_the_apocalypse_4pc&!(talent.cleaving_strikes&buff.remorseless_winter.up)))
  -- Note: For tier set, using TWW2 as pattern since all other examples use TWW2. The simc might be referencing a different season/tier that maps to TWW2.
  VarFrostscythePrio = 3 + (1 * num(Player:HasTier("TWW2", 4) and Player:HeroTreeID() == 32 and not (S.CleavingStrikes:IsAvailable() and Player:BuffUp(S.RemorselessWinterBuff))))
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,if=!trinket.1.cast_time>0&variable.trinket_1_buffs&!variable.trinket_1_manual&buff.pillar_of_frost.remains&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1CastTime == 0 and VarTrinket1Buffs and not VarTrinket1Manual and Player:BuffUp(S.PillarofFrostBuff) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 trinkets 2"; end
    end
    -- use_item,slot=trinket2,if=!trinket.2.cast_time>0&variable.trinket_2_buffs&!variable.trinket_2_manual&buff.pillar_of_frost.remains&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2CastTime == 0 and VarTrinket2Buffs and not VarTrinket2Manual and Player:BuffUp(S.PillarofFrostBuff) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 trinkets 4"; end
    end
    -- use_item,slot=trinket1,use_off_gcd=1,if=trinket.1.cast_time>0&variable.trinket_1_buffs&!variable.trinket_1_manual&cooldown.pillar_of_frost.remains<trinket.1.cast_time&variable.sending_cds&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|variable.trinket_1_duration>=fight_remains
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1CastTime > 0 and VarTrinket1Buffs and not VarTrinket1Manual and S.PillarofFrost:CooldownRemains() < VarTrinket1CastTime and VarSendingCDs and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or VarTrinket1Duration >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 off_gcd trinkets 6"; end
    end
    -- use_item,slot=trinket2,use_off_gcd=1,if=trinket.2.cast_time>0&variable.trinket_2_buffs&!variable.trinket_2_manual&cooldown.pillar_of_frost.remains<trinket.2.cast_time&variable.sending_cds&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|variable.trinket_2_duration>=fight_remains
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2CastTime > 0 and VarTrinket2Buffs and not VarTrinket2Manual and S.PillarofFrost:CooldownRemains() < VarTrinket2CastTime and VarSendingCDs and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or VarTrinket2Duration >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 off_gcd trinkets 8"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|(!trinket.2.has_cooldown|trinket.2.cooldown.remains))&((trinket.1.cast_time>0&(!talent.breath_of_sindragosa|!buff.breath_of_sindragosa.up)&!buff.pillar_of_frost.up|!trinket.1.cast_time>0)&(!variable.trinket_2_buffs|cooldown.pillar_of_frost.remains>20)|!talent.pillar_of_frost)|fight_remains<15
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or (not Trinket2:HasCooldown() or Trinket2:CooldownDown())) and ((VarTrinket1CastTime > 0 and (not S.BreathofSindragosa:IsAvailable() or Player:BuffDown(S.BreathofSindragosa)) and Player:BuffDown(S.PillarofFrostBuff) or VarTrinket1CastTime == 0) and (not VarTrinket2Buffs or S.PillarofFrost:CooldownRemains() > 20) or not S.PillarofFrost:IsAvailable()) or FightRemains < 15) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 damage trinkets 10"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|(!trinket.1.has_cooldown|trinket.1.cooldown.remains))&((trinket.2.cast_time>0&(!talent.breath_of_sindragosa|!buff.breath_of_sindragosa.up)&!buff.pillar_of_frost.up|!trinket.2.cast_time>0)&(!variable.trinket_1_buffs|cooldown.pillar_of_frost.remains>20)|!talent.pillar_of_frost)|fight_remains<15
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or (not Trinket1:HasCooldown() or Trinket1:CooldownDown())) and ((VarTrinket2CastTime > 0 and (not S.BreathofSindragosa:IsAvailable() or Player:BuffDown(S.BreathofSindragosa)) and Player:BuffDown(S.PillarofFrostBuff) or VarTrinket2CastTime == 0) and (not VarTrinket1Buffs or S.PillarofFrost:CooldownRemains() > 20) or not S.PillarofFrost:IsAvailable()) or FightRemains < 15) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 damage trinkets 12"; end
    end
  end
  -- use_item,slot=main_hand,if=buff.pillar_of_frost.up|(buff.breath_of_sindragosa.up&cooldown.pillar_of_frost.remains)|(variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.1.cooldown.remains<cooldown.pillar_of_frost.remains|trinket.2.cooldown.remains<cooldown.pillar_of_frost.remains)&cooldown.pillar_of_frost.remains>20)|fight_remains<15
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and (Player:BuffUp(S.PillarofFrostBuff) or (Player:BuffUp(S.BreathofSindragosa) and S.PillarofFrost:CooldownDown()) or (VarTrinket1Buffs and VarTrinket2Buffs and (Trinket1:CooldownRemains() < S.PillarofFrost:CooldownRemains() or Trinket2:CooldownRemains() < S.PillarofFrost:CooldownRemains()) and S.PillarofFrost:CooldownRemains() > 20) or FightRemains < 15) then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "use_item main_hand trinkets 14"; end
    end
  end
end

local function HighPrioActions()
  -- mind_freeze,if=target.debuff.casting.react
  local ShouldReturn = Everyone.Interrupt(S.MindFreeze, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
  -- invoke_external_buff,name=power_infusion,if=variable.cooldown_check
  -- Note: Not handling external buffs.
  -- antimagic_shell,if=runic_power.deficit>40&death_knight.first_ams_cast<time
  if Settings.Commons.UseAMSAMZOffensively and CDsON() and S.AntiMagicShell:IsCastable() and (Player:RunicPowerDeficit() > 40 and 20 < HL.CombatTime()) then
    if Cast(S.AntiMagicShell, Settings.CommonsOGCD.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell high_prio_actions 2"; end
  end
end

local function Cooldowns()
  -- potion,use_off_gcd=1,if=variable.cooldown_check|fight_remains<25
  if Settings.Commons.Enabled.Potions and (VarCDCheck or BossFightRemains < 25) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldowns 2"; end
    end
  end
  -- remorseless_winter,if=variable.sending_cds&(active_enemies>1|talent.gathering_storm)|(buff.gathering_storm.stack=10&buff.remorseless_winter.remains<gcd.max)&fight_remains>10
  if S.RemorselessWinter:IsReady() and (VarSendingCDs and (EnemiesMeleeCount > 1 or S.GatheringStorm:IsAvailable()) or (Player:BuffStack(S.GatheringStormBuff) == 10 and Player:BuffRemains(S.RemorselessWinterBuff) < Player:GCD()) and FightRemains > 10) then
    if Cast(S.RemorselessWinter, nil, nil, not Target:IsInMeleeRange(8)) then return "remorseless_winter cooldowns 4"; end
  end
  -- frostwyrms_fury,if=hero_tree.rider_of_the_apocalypse&talent.apocalypse_now&variable.sending_cds&(cooldown.pillar_of_frost.remains<gcd.max|fight_remains<20)&!talent.breath_of_sindragosa
  if S.FrostwyrmsFury:IsCastable() and (Player:HeroTreeID() == 32 and S.ApocalypseNow:IsAvailable() and VarSendingCDs and (S.PillarofFrost:CooldownRemains() < Player:GCD() or FightRemains < 20) and not S.BreathofSindragosa:IsAvailable()) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 6"; end
  end
  -- frostwyrms_fury,if=hero_tree.rider_of_the_apocalypse&talent.apocalypse_now&variable.sending_cds&(cooldown.pillar_of_frost.remains<gcd.max|fight_remains<20)&talent.breath_of_sindragosa&runic_power>=60
  if S.FrostwyrmsFury:IsCastable() and (Player:HeroTreeID() == 32 and S.ApocalypseNow:IsAvailable() and VarSendingCDs and (S.PillarofFrost:CooldownRemains() < Player:GCD() or FightRemains < 20) and S.BreathofSindragosa:IsAvailable() and Player:RunicPower() >= 60) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 8"; end
  end
  -- pillar_of_frost,if=!talent.breath_of_sindragosa&variable.sending_cds&(!hero_tree.deathbringer|rune>=2)|fight_remains<20
  if S.PillarofFrost:IsCastable() and (not S.BreathofSindragosa:IsAvailable() and VarSendingCDs and (Player:HeroTreeID() ~= 33 or Player:Rune() >= 2) or FightRemains < 20) then
    -- Try macro optimization first (Obliteration builds only)
    if ShouldUsePillarMacro() then
      local ShouldReturn = PillarMacro()
      if ShouldReturn then return "pillar_macro cooldowns 10"; end
    else
      if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 10"; end
    end
  end
  -- pillar_of_frost,if=talent.breath_of_sindragosa&variable.sending_cds&(cooldown.breath_of_sindragosa.remains>20|(cooldown.breath_of_sindragosa.up&runic_power>=(60-20*hero_tree.deathbringer)))&(!hero_tree.deathbringer|rune>=2)
  if S.PillarofFrost:IsCastable() and (S.BreathofSindragosa:IsAvailable() and VarSendingCDs and (S.BreathofSindragosa:CooldownRemains() > 20 or (S.BreathofSindragosa:CooldownUp() and Player:RunicPower() >= (60 - 20 * num(Player:HeroTreeID() == 33)))) and (Player:HeroTreeID() ~= 33 or Player:Rune() >= 2)) then
    -- Try macro optimization first (Obliteration builds only)
    if ShouldUsePillarMacro() then
      local ShouldReturn = PillarMacro()
      if ShouldReturn then return "pillar_macro cooldowns 12"; end
    else
      if Cast(S.PillarofFrost, Settings.Frost.GCDasOffGCD.PillarOfFrost) then return "pillar_of_frost cooldowns 12"; end
    end
  end
  -- breath_of_sindragosa,use_off_gcd=1,if=!buff.breath_of_sindragosa.up&(buff.pillar_of_frost.up|fight_remains<20)
  if S.BreathofSindragosa:IsReady() and (Player:BuffDown(S.BreathofSindragosa) and (Player:BuffUp(S.PillarofFrostBuff) or FightRemains < 20)) then
    if Cast(S.BreathofSindragosa, Settings.Frost.GCDasOffGCD.BreathOfSindragosa, nil, not Target:IsInRange(12)) then return "breath_of_sindragosa cooldowns 14"; end
  end
  -- reapers_mark,target_if=first:debuff.reapers_mark_debuff.down,if=buff.pillar_of_frost.up|cooldown.pillar_of_frost.remains>5|fight_remains<20
  if S.ReapersMark:IsReady() and (Player:BuffUp(S.PillarofFrostBuff) or S.PillarofFrost:CooldownRemains() > 5 or FightRemains < 20) then
    local function EvaluateCycleReapersMark(TargetUnit)
      return TargetUnit:DebuffDown(S.ReapersMarkDebuff)
    end
    if Everyone.CastCycle(S.ReapersMark, EnemiesMelee, EvaluateCycleReapersMark, not Target:IsInMeleeRange(5), Settings.Frost.GCDasOffGCD.ReapersMark) then return "reapers_mark cooldowns 16"; end
  end
  -- frostwyrms_fury,if=!talent.apocalypse_now&active_enemies=1&(talent.pillar_of_frost&buff.pillar_of_frost.up&!talent.obliteration|!talent.pillar_of_frost)&(!raid_event.adds.exists|raid_event.adds.in>cooldown.frostwyrms_fury.duration+raid_event.adds.duration)&variable.fwf_buffs|fight_remains<3
  if S.FrostwyrmsFury:IsCastable() and (not S.ApocalypseNow:IsAvailable() and EnemiesMeleeCount == 1 and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and not S.Obliteration:IsAvailable() or not S.PillarofFrost:IsAvailable()) and VarFWFBuffs or FightRemains < 3) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 18"; end
  end
  -- frostwyrms_fury,if=!talent.apocalypse_now&active_enemies>=2&(talent.pillar_of_frost&buff.pillar_of_frost.up|raid_event.adds.exists&raid_event.adds.up&raid_event.adds.in<cooldown.pillar_of_frost.remains-raid_event.adds.in-raid_event.adds.duration)&variable.fwf_buffs
  if S.FrostwyrmsFury:IsCastable() and (not S.ApocalypseNow:IsAvailable() and EnemiesMeleeCount >= 2 and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff)) and VarFWFBuffs) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 20"; end
  end
  -- frostwyrms_fury,if=!talent.apocalypse_now&talent.obliteration&(talent.pillar_of_frost&buff.pillar_of_frost.up&!main_hand.2h|!buff.pillar_of_frost.up&main_hand.2h&cooldown.pillar_of_frost.remains|!talent.pillar_of_frost)&variable.fwf_buffs&(!raid_event.adds.exists|raid_event.adds.in>cooldown.frostwyrms_fury.duration+raid_event.adds.duration)
  if S.FrostwyrmsFury:IsCastable() and (not S.ApocalypseNow:IsAvailable() and S.Obliteration:IsAvailable() and (S.PillarofFrost:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and not Var2HCheck or Player:BuffDown(S.PillarofFrostBuff) and Var2HCheck and S.PillarofFrost:CooldownDown() or not S.PillarofFrost:IsAvailable()) and VarFWFBuffs) then
    if Cast(S.FrostwyrmsFury, Settings.Frost.GCDasOffGCD.FrostwyrmsFury, nil, not Target:IsInRange(40)) then return "frostwyrms_fury cooldowns 22"; end
  end
  -- raise_dead,use_off_gcd=1
  if S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 24"; end
  end
  -- soul_reaper,if=talent.reaper_of_souls&buff.reaper_of_souls.up&buff.killing_machine.react<2
  if S.SoulReaper:IsReady() and (S.ReaperofSouls:IsAvailable() and Player:BuffUp(S.ReaperofSoulsBuff) and Player:BuffStack(S.KillingMachineBuff) < 2) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper cooldowns 26"; end
  end
  -- empower_rune_weapon,use_off_gcd=1,if=(rune<2|!buff.killing_machine.react)&runic_power<35+(talent.icy_onslaught*buff.icy_onslaught.stack*5)&gcd.remains<0.5
  if S.EmpowerRuneWeapon:IsCastable() and ((Player:Rune() < 2 or Player:BuffDown(S.KillingMachineBuff)) and Player:RunicPower() < 35 + (num(S.IcyOnslaught:IsAvailable()) * Player:BuffStack(S.IcyOnslaughtBuff) * 5) and Player:GCDRemains() < 0.5) then
    if Cast(S.EmpowerRuneWeapon, Settings.CommonsOGCD.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 28"; end
  end
  -- empower_rune_weapon,use_off_gcd=1,if=cooldown.empower_rune_weapon.full_recharge_time<=6&buff.killing_machine.react<1+(1*talent.killing_streak)&gcd.remains<0.5
  if S.EmpowerRuneWeapon:IsCastable() and (S.EmpowerRuneWeapon:FullRechargeTime() <= 6 and Player:BuffStack(S.KillingMachineBuff) < (1 + num(S.KillingStreak:IsAvailable())) and Player:GCDRemains() < 0.5) then
    if Cast(S.EmpowerRuneWeapon, Settings.CommonsOGCD.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 30"; end
  end
end

local function Racials()
  -- blood_fury,use_off_gcd=1,if=variable.cooldown_check
  if S.BloodFury:IsCastable() and VarCDCheck then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racials 2"; end
  end
  -- berserking,use_off_gcd=1,if=variable.cooldown_check
  if S.Berserking:IsCastable() and VarCDCheck then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racials 4"; end
  end
  -- arcane_pulse,if=variable.cooldown_check
  if S.ArcanePulse:IsCastable() and VarCDCheck then
    if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
  end
  -- lights_judgment,if=variable.cooldown_check
  if S.LightsJudgment:IsCastable() and VarCDCheck then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call,use_off_gcd=1,if=variable.cooldown_check
  if S.AncestralCall:IsCastable() and VarCDCheck then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- fireblood,use_off_gcd=1,if=variable.cooldown_check
  if S.Fireblood:IsCastable() and VarCDCheck then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racials 12"; end
  end
  -- bag_of_tricks,if=talent.obliteration&!buff.pillar_of_frost.up&buff.unholy_strength.up
  if S.BagofTricks:IsCastable() and (S.Obliteration:IsAvailable() and Player:BuffDown(S.PillarofFrostBuff) and Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 14"; end
  end
  -- bag_of_tricks,if=!talent.obliteration&buff.pillar_of_frost.up&(buff.unholy_strength.up&buff.unholy_strength.remains<gcd*3|buff.pillar_of_frost.remains<gcd*3)
  if S.BagofTricks:IsCastable() and (not S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff) and (Player:BuffUp(S.UnholyStrengthBuff) and Player:BuffRemains(S.UnholyStrengthBuff) < Player:GCD() * 3 or Player:BuffRemains(S.PillarofFrostBuff) < Player:GCD() * 3)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks racials 16"; end
  end
end

local function AoE()
  -- frostscythe,if=(buff.killing_machine.react=2|(buff.killing_machine.react&rune>=3))&active_enemies>=variable.frostscythe_prio
  if S.Frostscythe:IsReady() and ((Player:BuffStack(S.KillingMachineBuff) == 2 or (Player:BuffUp(S.KillingMachineBuff) and Player:Rune() >= 3)) and EnemiesMeleeCount >= VarFrostscythePrio) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe aoe 2"; end
  end
  -- obliterate,target_if=max:(hero_tree.rider_of_the_apocalypse&debuff.chains_of_ice_trollbane_slow.react),if=buff.killing_machine.react=2|(buff.killing_machine.react&rune>=3)
  if S.Obliterate:IsReady() and (Player:BuffStack(S.KillingMachineBuff) == 2 or (Player:BuffUp(S.KillingMachineBuff) and Player:Rune() >= 3)) then
    local function EvaluateTargetIfFilterAoEObliterate(TargetUnit)
      return (Player:HeroTreeID() == 32 and TargetUnit:DebuffUp(S.TrollbaneSlowDebuff)) and 1 or 0
    end
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterAoEObliterate, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 4"; end
  end
  -- howling_blast,if=buff.rime.react&talent.frostbound_will|!dot.frost_fever.ticking
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff) and S.FrostboundWill:IsAvailable() or Target:DebuffDown(S.FrostFeverDebuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 6"; end
  end
  -- frost_strike,target_if=max:(talent.shattering_blade&debuff.razorice.react=5),if=debuff.razorice.react=5&buff.frostbane.react
  if S.FrostStrike:IsReady() and S.Frostbane:IsAvailable() then
    local function EvaluateTargetIfFilterAoEFrostStrike(TargetUnit)
      return (S.ShatteringBlade:IsAvailable() and TargetUnit:DebuffStack(S.RazoriceDebuff) == 5) and 1 or 0
    end
    local function EvaluateTargetIfAoEFrostStrike(TargetUnit)
      return TargetUnit:DebuffStack(S.RazoriceDebuff) == 5 and Player:BuffUp(S.FrostbaneBuff)
    end
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterAoEFrostStrike, EvaluateTargetIfAoEFrostStrike, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike aoe 8"; end
  end
  -- frost_strike,target_if=max:(talent.shattering_blade&debuff.razorice.react=5),if=debuff.razorice.react=5&talent.shattering_blade&active_enemies<5&!variable.rp_pooling&!talent.frostbane
  if S.FrostStrike:IsReady() and not S.Frostbane:IsAvailable() then
    local function EvaluateTargetIfFilterAoEFrostStrike2(TargetUnit)
      return (S.ShatteringBlade:IsAvailable() and TargetUnit:DebuffStack(S.RazoriceDebuff) == 5) and 1 or 0
    end
    local function EvaluateTargetIfAoEFrostStrike2(TargetUnit)
      return TargetUnit:DebuffStack(S.RazoriceDebuff) == 5 and S.ShatteringBlade:IsAvailable() and EnemiesMeleeCount < 5 and not VarRPPooling
    end
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterAoEFrostStrike2, EvaluateTargetIfAoEFrostStrike2, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike aoe 10"; end
  end
  -- frostscythe,if=buff.killing_machine.react&!variable.rune_pooling&active_enemies>=variable.frostscythe_prio
  if S.Frostscythe:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarRunePooling and EnemiesMeleeCount >= VarFrostscythePrio) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe aoe 12"; end
  end
  -- obliterate,target_if=max:(hero_tree.rider_of_the_apocalypse&debuff.chains_of_ice_trollbane_slow.react),if=buff.killing_machine.react&!variable.rune_pooling
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarRunePooling) then
    local function EvaluateTargetIfFilterAoEObliterate2(TargetUnit)
      return (Player:HeroTreeID() == 32 and TargetUnit:DebuffUp(S.TrollbaneSlowDebuff)) and 1 or 0
    end
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterAoEObliterate2, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 14"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 16"; end
  end
  -- glacial_advance,if=!variable.rp_pooling
  if S.GlacialAdvance:IsReady() and (not VarRPPooling) then
    if Cast(S.GlacialAdvance, nil, nil, not Target:IsInRange(100)) then return "glacial_advance aoe 18"; end
  end
  -- frostscythe,if=!variable.rune_pooling&!(talent.obliteration&buff.pillar_of_frost.up)&active_enemies>=variable.frostscythe_prio
  if S.Frostscythe:IsReady() and (not VarRunePooling and not (S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff)) and EnemiesMeleeCount >= VarFrostscythePrio) then
    if Cast(S.Frostscythe, nil, nil, not Target:IsInMeleeRange(8)) then return "frostscythe aoe 20"; end
  end
  -- obliterate,target_if=max:(hero_tree.rider_of_the_apocalypse&debuff.chains_of_ice_trollbane_slow.react),if=!variable.rune_pooling&!(talent.obliteration&buff.pillar_of_frost.up)
  if S.Obliterate:IsReady() and (not VarRunePooling and not (S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff))) then
    local function EvaluateTargetIfFilterAoEObliterate3(TargetUnit)
      return (Player:HeroTreeID() == 32 and TargetUnit:DebuffUp(S.TrollbaneSlowDebuff)) and 1 or 0
    end
    if Everyone.CastTargetIf(S.Obliterate, EnemiesMelee, "max", EvaluateTargetIfFilterAoEObliterate3, nil, not Target:IsInMeleeRange(5)) then return "obliterate aoe 22"; end
  end
  -- howling_blast,if=!buff.killing_machine.react&(talent.obliteration&buff.pillar_of_frost.up)
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and (S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff))) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast aoe 24"; end
  end
end

local function SingleTarget()
  -- obliterate,if=buff.killing_machine.react=2|(buff.killing_machine.react&rune>=3)
  if S.Obliterate:IsReady() and (Player:BuffStack(S.KillingMachineBuff) == 2 or (Player:BuffUp(S.KillingMachineBuff) and Player:Rune() >= 3)) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 2"; end
  end
  -- howling_blast,if=buff.rime.react&talent.frostbound_will
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff) and S.FrostboundWill:IsAvailable()) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 4"; end
  end
  -- frost_strike,target_if=max:(talent.shattering_blade&debuff.razorice.react=5),if=debuff.razorice.react=5&talent.shattering_blade&!variable.rp_pooling
  if S.FrostStrike:IsReady() and S.ShatteringBlade:IsAvailable() then
    local function EvaluateTargetIfFilterSTFrostStrike(TargetUnit)
      return (S.ShatteringBlade:IsAvailable() and TargetUnit:DebuffStack(S.RazoriceDebuff) == 5) and 1 or 0
    end
    local function EvaluateTargetIfSTFrostStrike(TargetUnit)
      return TargetUnit:DebuffStack(S.RazoriceDebuff) == 5 and not VarRPPooling
    end
    if Everyone.CastTargetIf(S.FrostStrike, EnemiesMelee, "max", EvaluateTargetIfFilterSTFrostStrike, EvaluateTargetIfSTFrostStrike, not Target:IsSpellInRange(S.FrostStrike), Settings.Frost.GCDasOffGCD.FrostStrike) then return "frost_strike single_target 6"; end
  end
  -- howling_blast,if=buff.rime.react
  if S.HowlingBlast:IsReady() and (Player:BuffUp(S.RimeBuff)) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 8"; end
  end
  -- frost_strike,if=!talent.shattering_blade&!variable.rp_pooling&runic_power.deficit<30
  if S.FrostStrike:IsReady() and (not S.ShatteringBlade:IsAvailable() and not VarRPPooling and Player:RunicPowerDeficit() < 30) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 10"; end
  end
  -- obliterate,if=buff.killing_machine.react&!variable.rune_pooling
  if S.Obliterate:IsReady() and (Player:BuffUp(S.KillingMachineBuff) and not VarRunePooling) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 12"; end
  end
  -- frost_strike,if=!variable.rp_pooling
  if S.FrostStrike:IsReady() and (not VarRPPooling) then
    if Cast(S.FrostStrike, Settings.Frost.GCDasOffGCD.FrostStrike, nil, not Target:IsInMeleeRange(5)) then return "frost_strike single_target 14"; end
  end
  -- obliterate,if=!variable.rune_pooling&!(talent.obliteration&buff.pillar_of_frost.up)
  if S.Obliterate:IsReady() and (not VarRunePooling and not (S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff))) then
    if Cast(S.Obliterate, nil, nil, not Target:IsInMeleeRange(5)) then return "obliterate single_target 16"; end
  end
  -- howling_blast,if=!buff.killing_machine.react&(talent.obliteration&buff.pillar_of_frost.up)
  if S.HowlingBlast:IsReady() and (Player:BuffDown(S.KillingMachineBuff) and (S.Obliteration:IsAvailable() and Player:BuffUp(S.PillarofFrostBuff))) then
    if Cast(S.HowlingBlast, nil, nil, not Target:IsSpellInRange(S.HowlingBlast)) then return "howling_blast single_target 18"; end
  end
end

--- ===== APL Main =====
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
  else
    EnemiesMeleeCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Main APL
    -- auto_attack
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=high_prio_actions
    local ShouldReturn = HighPrioActions(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if CDsON() then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=3
    if EnemiesMeleeCount >= 3 and AoEON() then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AoE()"; end
    end
    -- run_action_list,name=single_target
    if EnemiesMeleeCount < 3 or not AoEON() then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
    -- nothing to cast, wait for resources
    if HR.CastRuneForging(S.RuneoftheFallenCrusader, S.RuneofRazorice) then return "rune_forging"; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FrostFeverDebuff:RegisterAuraTracking()

  HR.Print("Frost Death Knight rotation has been updated with new APL for patch 11.2.0.")
end

HR.SetAPL(251, APL, Init)
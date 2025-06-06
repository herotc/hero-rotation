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
local VarBuffSyncActive = false
local VarBuffSyncReady = false
local VarBuffSyncRemains = 0
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
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

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
  return (S.WildCall:IsAvailable() and S.BarbedShot:ChargesFractional() > 1.4 or Player:BuffUp(S.CalloftheWildBuff) or S.BarbedShot:FullRechargeTime() < Player:GCD() and S.BestialWrath:CooldownDown() or S.ScentofBlood:IsAvailable() and (S.BestialWrath:CooldownRemains() < 12 + Player:GCD()) or S.FuriousAssault:IsAvailable() or S.BlackArrowTalent:IsAvailable() and (S.BarbedScales:IsAvailable() or S.Savagery:IsAvailable()) or BossFightRemains < 9)
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
  if S.HuntersMark:IsCastable() and (Target:DebuffDown(S.HuntersMark)) then
    if Cast(S.HuntersMark, Settings.CommonsOGCD.GCDasOffGCD.HuntersMark) then return "hunters_mark precombat 2"; end
  end
  -- barbed_shot
  if S.BarbedShot:IsCastable() and S.BarbedShot:Charges() >= 2 then
    if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot precombat 8"; end
  end
end

local function CDs()
  -- invoke_external_buff,name=power_infusion,if=buff.call_of_the_wild.up|talent.bloodshed&(prev_gcd.1.bloodshed)|!talent.call_of_the_wild&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains<30)|fight_remains<16
  -- Note: Not handling external buffs.
  if CDsON() then
    -- berserking,if=buff.call_of_the_wild.up|talent.bloodshed&(prev_gcd.1.bloodshed)|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<13
    if S.Berserking:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 13) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
    end
    -- blood_fury,if=buff.call_of_the_wild.up|talent.bloodshed&(prev_gcd.1.bloodshed)|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<16
    if S.BloodFury:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 16) then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
    end
    -- ancestral_call,if=buff.call_of_the_wild.up|talent.bloodshed&(prev_gcd.1.bloodshed)|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<16
    if S.AncestralCall:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 16) then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 10"; end
    end
    -- fireblood,if=buff.call_of_the_wild.up|talent.bloodshed&(prev_gcd.1.bloodshed)|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<9
    if S.Fireblood:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 9) then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 12"; end
    end
  end
  -- potion,if=buff.call_of_the_wild.up|talent.bloodshed&(prev_gcd.1.bloodshed)|!talent.call_of_the_wild&!talent.bloodshed&buff.bestial_wrath.up|fight_remains<31
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.CalloftheWildBuff) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or not S.CalloftheWild:IsAvailable() and not S.Bloodshed:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or BossFightRemains < 31) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 14"; end
    end
  end
end

local function Cleave()
  -- bestial_wrath,target_if=min:dot.barbed_shot.remains
  if CDsON() and S.BestialWrath:IsCastable() then
    if Everyone.CastTargetIf(S.BestialWrath, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not TargetInRange40y, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath cleave 2"; end
  end
  -- dire_beast,if=talent.huntmasters_call&buff.huntmasters_call.stack=2
  if S.DireBeast:IsCastable() and (S.HuntmastersCall:IsAvailable() and Player:BuffStack(S.HuntmastersCallBuff) == 2) then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast cleave 4"; end
  end
  -- kill_shot,if=talent.black_arrow&buff.beast_cleave.remains&buff.withering_fire.up
  if S.BlackArrow:IsReady() and (Pet:BuffUp(S.BeastCleavePetBuff) and Player:BuffUp(S.WitheringFireBuff)) then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "black_arrow cleave 6"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd|charges_fractional>=cooldown.kill_command.charges_fractional|talent.call_of_the_wild&cooldown.call_of_the_wild.ready|howl_summon.ready&full_recharge_time<8
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or S.BarbedShot:ChargesFractional() >= S.KillCommand:ChargesFractional() or S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp() or HowlSummonReady() and S.BarbedShot:FullRechargeTime() < 8) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 8"; end
  end
  -- multishot,if=pet.main.buff.beast_cleave.down&(!talent.bloody_frenzy|cooldown.call_of_the_wild.remains)
  if S.MultiShot:IsReady() and (Pet:BuffDown(S.BeastCleavePetBuff) and (not S.BloodyFrenzy:IsAvailable() or S.CalloftheWild:CooldownDown() or not CDsON())) then
    if Cast(S.MultiShot, nil, nil, not Target:IsSpellInRange(S.MultiShot)) then return "multishot cleave 10"; end
  end
  -- kill_shot,if=talent.black_arrow&buff.beast_cleave.remains
  if S.BlackArrow:IsReady() and (Pet:BuffUp(S.BeastCleavePetBuff)) then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "black_arrow cleave 12"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild cleave 14"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed cleave 16"; end
  end
  -- dire_beast,if=talent.shadow_hounds|talent.dire_cleave
  if S.DireBeast:IsCastable() and (S.ShadowHounds:IsAvailable() or S.DireCleave:IsAvailable()) then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast cleave 18"; end
  end
  -- explosive_shot,if=talent.thundering_hooves
  if S.ExplosiveShot:IsReady() and (S.ThunderingHooves:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot cleave 20"; end
  end
  -- kill_command,target_if=max:(target.health.pct<35|!talent.killer_instinct)*2+dot.a_murder_of_crows.refreshable
  if S.KillCommand:IsReady() then
    if Everyone.CastTargetIf(S.KillCommand, Enemies40y, "max", EvaluateTargetIfFilterKillCommand, nil, not Target:IsInRange(50)) then return "kill_command cleave 22"; end
  end
  -- lights_judgment,if=buff.bestial_wrath.down|target.time_to_die<5
  if CDsON() and S.LightsJudgment:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(5)) then return "lights_judgment cleave 24"; end
  end
  -- cobra_shot,if=focus.time_to_max<gcd*2|buff.hogstrider.stack>3
  if S.CobraShot:IsReady() and (Player:FocusTimeToMax() < Player:GCD() * 2 or Player:BuffStack(S.HogstriderBuff) > 3) then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot cleave 26"; end
  end
  -- dire_beast
  if S.DireBeast:IsCastable() then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast cleave 28"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot cleave 30"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and CDsON() and (Player:BuffDown(S.BestialWrathBuff) or FightRemains < 5) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks cleave 32"; end
  end
  -- arcane_torrent,if=(focus+focus.regen+30)<focus.max
  if S.ArcaneTorrent:IsCastable() and CDsON() and ((Player:Focus() + Player:FocusRegen() + 30) < Player:FocusMax()) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent cleave 34"; end
  end
end

local function ST()
  -- dire_beast,if=talent.huntmasters_call
  if S.DireBeast:IsCastable() and (S.HuntmastersCall:IsAvailable()) then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast st 2"; end
  end
  -- bestial_wrath
  if CDsON() and S.BestialWrath:IsCastable() then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath st 4"; end
  end
  -- kill_shot,if=talent.black_arrow&buff.withering_fire.up
  if S.BlackArrow:IsReady() and (Player:BuffUp(S.WitheringFireBuff)) then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "black_arrow st 6"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd|charges_fractional>=cooldown.kill_command.charges_fractional|talent.call_of_the_wild&cooldown.call_of_the_wild.ready|howl_summon.ready&full_recharge_time<8
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or S.BarbedShot:ChargesFractional() >= S.KillCommand:ChargesFractional() or S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp() or HowlSummonReady() and S.BarbedShot:FullRechargeTime() < 8) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 8"; end
  end
  -- Main Target backup
  if S.BarbedShot:IsCastable() and (S.BarbedShot:FullRechargeTime() < Player:GCD() or S.BarbedShot:ChargesFractional() >= S.KillCommand:ChargesFractional() or S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp() or HowlSummonReady() and S.BarbedShot:FullRechargeTime() < 8) then
    if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st mt_backup 10"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild st 12"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed st 14"; end
  end
  -- kill_command
  if S.KillCommand:IsReady() then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 16"; end
  end
  -- kill_shot,if=talent.black_arrow
  if S.BlackArrow:IsReady() then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "black_arrow st 18"; end
  end
  -- explosive_shot,if=talent.thundering_hooves
  if S.ExplosiveShot:IsReady() and (S.ThunderingHooves:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot st 20"; end
  end
  -- lights_judgment,if=buff.bestial_wrath.down|target.time_to_die<5
  if CDsON() and S.LightsJudgment:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(5)) then return "lights_judgment st 22"; end
  end
  -- cobra_shot
  if S.CobraShot:IsReady() then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot st 24"; end
  end
  -- dire_beast
  if S.DireBeast:IsCastable() then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast st 26"; end
  end
  if CDsON() then
    -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
    if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or FightRemains < 5) then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks st 28"; end
    end
    -- arcane_pulse,if=buff.bestial_wrath.down|target.time_to_die<5
    if S.ArcanePulse:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or FightRemains < 5) then
      if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_pulse st 30"; end
    end
    -- arcane_torrent,if=(focus+focus.regen+15)<focus.max
    if S.ArcaneTorrent:IsCastable() and ((Player:Focus() + Player:FocusRegen() + 15) < Player:FocusMax()) then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent st 32"; end
    end
  end
end

local function Trinkets()
  -- variable,name=buff_sync_ready,value=talent.call_of_the_wild&(prev_gcd.1.call_of_the_wild)|talent.bloodshed&(prev_gcd.1.bloodshed)|(!talent.call_of_the_wild&!talent.bloodshed)&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains_guess<5)
  VarBuffSyncReady = S.CalloftheWild:IsAvailable() and Player:PrevGCD(1, S.CalloftheWild) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or (not S.CalloftheWild:IsAvailable() and not S.Bloodshed:IsAvailable()) and (Player:BuffUp(S.BestialWrathBuff) or S.BestialWrath:CooldownRemains() < 5)
  -- variable,name=buff_sync_remains,op=setif,value=cooldown.bestial_wrath.remains_guess,value_else=cooldown.call_of_the_wild.remains|cooldown.bloodshed.remains,condition=!talent.call_of_the_wild&!talent.bloodshed
  VarBuffSyncRemains = (not S.CalloftheWild:IsAvailable() and not S.Bloodshed:IsAvailable()) and S.BestialWrath:CooldownRemains() or (S.CalloftheWild:CooldownRemains() or S.Bloodshed:CooldownRemains())
  -- variable,name=buff_sync_active,value=talent.call_of_the_wild&buff.call_of_the_wild.up|talent.bloodshed&prev_gcd.1.bloodshed|(!talent.call_of_the_wild&!talent.bloodshed)&buff.bestial_wrath.up
  VarBuffSyncActive = S.CalloftheWild:IsAvailable() and Player:BuffUp(S.CalloftheWildBuff) or S.Bloodshed:IsAvailable() and Player:PrevGCD(1, S.Bloodshed) or (not S.CalloftheWild:IsAvailable() and not S.Bloodshed:IsAvailable()) and Player:BuffUp(S.BestialWrathBuff)
  -- variable,name=damage_sync_active,value=1
  local VarDamageSyncActive = true
  -- variable,name=damage_sync_remains,value=0
  local VarDamageSyncRemains = 0
  if Settings.Commons.Enabled.Trinkets then
    -- use_items,slots=trinket1:trinket2,if=this_trinket.has_use_buff&(variable.buff_sync_ready&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)|!variable.buff_sync_ready&(variable.stronger_trinket_slot=this_trinket_slot&(variable.buff_sync_remains>this_trinket.cooldown.duration%3&fight_remains>this_trinket.cooldown.duration+20|other_trinket.has_use_buff&other_trinket.cooldown.remains>variable.buff_sync_remains-15&other_trinket.cooldown.remains-5<variable.buff_sync_remains&variable.buff_sync_remains+45>fight_remains)|variable.stronger_trinket_slot!=this_trinket_slot&(other_trinket.cooldown.remains&(other_trinket.cooldown.remains-5<variable.buff_sync_remains&variable.buff_sync_remains>=20|other_trinket.cooldown.remains-5>=variable.buff_sync_remains&(variable.buff_sync_remains>this_trinket.cooldown.duration%3|this_trinket.cooldown.duration<fight_remains&(variable.buff_sync_remains+this_trinket.cooldown.duration>fight_remains)))|other_trinket.cooldown.ready&variable.buff_sync_remains>20&variable.buff_sync_remains<other_trinket.cooldown.duration%3)))|!this_trinket.has_use_buff&(this_trinket.cast_time=0|!variable.buff_sync_active)&(!this_trinket.is.junkmaestros_mega_magnet|buff.junkmaestros_mega_magnet.stack>10)&(!other_trinket.has_cooldown&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|!this_trinket.is.junkmaestros_mega_magnet&variable.damage_sync_remains>this_trinket.cooldown.duration%3)|other_trinket.has_cooldown&(!other_trinket.has_use_buff&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|variable.damage_sync_remains>this_trinket.cooldown.duration%3&!this_trinket.is.junkmaestros_mega_magnet|other_trinket.cooldown.remains-5<variable.damage_sync_remains&variable.damage_sync_remains>=20)|other_trinket.has_use_buff&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|!this_trinket.is.junkmaestros_mega_magnet&variable.damage_sync_remains>this_trinket.cooldown.duration%3)&(other_trinket.cooldown.remains>=20|other_trinket.cooldown.remains-5>variable.buff_sync_remains)))|fight_remains<25&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (Trinket1:HasUseBuff() and (VarBuffSyncReady and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown()) or not VarBuffSyncReady and (VarStrongerTrinketSlot == 1 and (VarBuffSyncRemains > VarTrinket1CD / 3 and BossFightRemains > VarTrinket1CD + 20 or Trinket2:HasUseBuff() and Trinket2:CooldownRemains() > VarBuffSyncRemains - 15 and Trinket2:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains + 45 > BossFightRemains) or VarStrongerTrinketSlot ~= 1 and (Trinket2:CooldownDown() and (Trinket2:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains >= 20 or Trinket2:CooldownRemains() - 5 >= VarBuffSyncRemains and (VarBuffSyncRemains > VarTrinket1CD / 3 or VarTrinket1CD < BossFightRemains and (VarBuffSyncRemains + VarTrinket1CD > BossFightRemains))) or Trinket2:CooldownUp() and VarBuffSyncRemains > 20 and VarBuffSyncRemains < VarTrinket2CD / 3))) or not Trinket1:HasUseBuff() and (VarTrinket1CastTime == 0 or not VarBuffSyncActive) and (Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Player:BuffStack(S.JunkmaestrosBuff) > 10) and (not Trinket2:HasCooldown() and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket1CD / 3) or Trinket2:HasCooldown() and (not Trinket2:HasUseBuff() and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown()) and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or VarDamageSyncRemains > VarTrinket1CD / 3 and Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Trinket2:CooldownRemains() - 5 < VarDamageSyncRemains and VarDamageSyncRemains >= 20) or Trinket2:HasUseBuff() and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket1CD / 3) and (Trinket2:CooldownRemains() >= 20 or Trinket2:CooldownRemains() - 5 > VarBuffSyncRemains))) or BossFightRemains < 25 and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 2"; end
    end
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (Trinket2:HasUseBuff() and (VarBuffSyncReady and (VarStrongerTrinketSlot == 2 or Trinket1:CooldownDown()) or not VarBuffSyncReady and (VarStrongerTrinketSlot == 2 and (VarBuffSyncRemains > VarTrinket2CD / 3 and BossFightRemains > VarTrinket2CD + 20 or Trinket1:HasUseBuff() and Trinket1:CooldownRemains() > VarBuffSyncRemains - 15 and Trinket1:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains + 45 > BossFightRemains) or VarStrongerTrinketSlot ~= 2 and (Trinket1:CooldownDown() and (Trinket1:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains >= 20 or Trinket1:CooldownRemains() - 5 >= VarBuffSyncRemains and (VarBuffSyncRemains > VarTrinket2CD / 3 or VarTrinket2CD < BossFightRemains and (VarBuffSyncRemains + VarTrinket2CD > BossFightRemains))) or Trinket1:CooldownUp() and VarBuffSyncRemains > 20 and VarBuffSyncRemains < VarTrinket1CD / 3))) or not Trinket2:HasUseBuff() and (VarTrinket2CastTime == 0 or not VarBuffSyncActive) and (Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Player:BuffStack(S.JunkmaestrosBuff) > 10) and (not Trinket1:HasCooldown() and (VarDamageSyncActive or Trinket2:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket2CD / 3) or Trinket1:HasCooldown() and (not Trinket1:HasUseBuff() and (VarStrongerTrinketSlot == 2 or Trinket1:CooldownDown()) and (VarDamageSyncActive or Trinket2:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or VarDamageSyncRemains > VarTrinket2CD / 3 and Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Trinket1:CooldownRemains() - 5 < VarDamageSyncRemains and VarDamageSyncRemains >= 20) or Trinket1:HasUseBuff() and (VarDamageSyncActive or Trinket2:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket2CD / 3) and (Trinket1:CooldownRemains() >= 20 or Trinket1:CooldownRemains() - 5 > VarBuffSyncRemains))) or BossFightRemains < 25 and (VarStrongerTrinketSlot == 2 or Trinket1:CooldownDown())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 4"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- Manually added: use_items for non-trinkets
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 6"; end
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
    -- call_action_list,name=st,if=active_enemies<2|!talent.beast_cleave&active_enemies<3
    if PetEnemiesMixedCount < 2 or not S.BeastCleave:IsAvailable() and PetEnemiesMixedCount < 3 then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>2|talent.beast_cleave&active_enemies>1
    if PetEnemiesMixedCount > 2 or S.BeastCleave:IsAvailable() and PetEnemiesMixedCount > 1 then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
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
  HR.Print("Beast Mastery Hunter rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(253, APL, OnInit)

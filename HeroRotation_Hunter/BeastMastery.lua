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
local VarSyncActive = false
local VarSyncReady = false
local VarSyncRemains = 0
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
local VarTrinket1Stronger, VarTrinket2Stronger
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

  VarTrinket1Stronger = VarTrinket1CD == 0 or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or not T1.ID == I.MirrorofFracturedTomorrows:ID() and (T2.ID == I.MirrorofFracturedTomorrows:ID() or VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD)) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD))
  VarTrinket2Stronger = not VarTrinket1Stronger
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
local function EvaluateTargetIfBarbedShotCleave(TargetUnit)
  -- if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd+0.25|pet.main.buff.frenzy.stack<3&(cooldown.bestial_wrath.ready&(!pet.main.buff.frenzy.up|talent.scent_of_blood)|talent.call_of_the_wild&cooldown.call_of_the_wild.ready)
  return 
end

local function EvaluateTargetIfKillShotCleave(TargetUnit)
  -- if=talent.venoms_bite&dot.serpent_sting.remains<gcd&target.time_to_die>10
  return TargetUnit:DebuffRemains(S.SerpentStingDebuff) < Player:GCD() and TargetUnit:TimeToDie() > 10
end

local function EvaluateTargetIfKillShotST(TargetUnit)
  -- if=talent.venoms_bite&(!active_dot.serpent_sting|dot.serpent_sting.refreshable)
  -- Note: venoms_bite handled before CastTargetIf.
  return S.SerpentStingDebuff:AuraActiveCount() == 0 or TargetUnit:DebuffRefreshable(S.SerpentStingDebuff)
end

local function EvaluateTargetIfBarbedShotST(TargetUnit)
  -- if=talent.wild_call&charges_fractional>1.4|buff.call_of_the_wild.up|full_recharge_time<gcd&cooldown.bestial_wrath.remains|talent.scent_of_blood&(cooldown.bestial_wrath.remains<12+gcd)|talent.furious_assault|talent.black_arrow&(talent.barbed_scales|talent.savagery)|fight_remains<9
  return (S.WildCall:IsAvailable() and S.BarbedShot:ChargesFractional() > 1.4 or Player:BuffUp(S.CalloftheWildBuff) or S.BarbedShot:FullRechargeTime() < Player:GCD() and S.BestialWrath:CooldownDown() or S.ScentofBlood:IsAvailable() and (S.BestialWrath:CooldownRemains() < 12 + Player:GCD()) or S.FuriousAssault:IsAvailable() or S.BlackArrowTalent:IsAvailable() and (S.BarbedScales:IsAvailable() or S.Savagery:IsAvailable()) or BossFightRemains < 9)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- Handled in APL()
  -- snapshot_stats
  -- variable,name=trinket_1_stronger,value=!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|!trinket.1.is.mirror_of_fractured_tomorrows&(trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))
  -- variable,name=trinket_2_stronger,value=!variable.trinket_1_stronger
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- Manually added opener abilities
  -- hunters_mark,if=debuff.hunters_mark.down
  if S.HuntersMark:IsCastable() and (Target:DebuffDown(S.HuntersMark)) then
    if Cast(S.HuntersMark, Settings.CommonsOGCD.GCDasOffGCD.HuntersMark) then return "hunters_mark precombat 2"; end
  end
  -- bestial_wrath,if=talent.vicious_hunt
  if S.BestialWrath:IsCastable() and (S.ViciousHunt:IsAvailable()) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath precombat 4"; end
  end
  -- barbed_shot
  if S.BarbedShot:IsCastable() and S.BarbedShot:Charges() >= 2 then
    if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot precombat 8"; end
  end
end

local function CDs()
  -- invoke_external_buff,name=power_infusion,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains<30)|fight_remains<16
  -- Note: Not handling external buffs.
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
  -- potion,if=buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up|fight_remains<31
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff) or FightRemains < 31) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 14"; end
    end
  end
end

local function Cleave()
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd+0.25|pet.main.buff.frenzy.stack<3&(cooldown.bestial_wrath.ready&(!pet.main.buff.frenzy.up|talent.scent_of_blood)|talent.call_of_the_wild&cooldown.call_of_the_wild.ready)
  if S.BarbedShot:IsCastable() and (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= Player:GCD() + 0.25 or Pet:BuffStack(S.FrenzyPetBuff) < 3 and (S.BestialWrath:CooldownUp() and (Pet:BuffDown(S.FrenzyPetBuff) or S.ScentofBlood:IsAvailable()) or S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp())) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 2"; end
  end
  -- multishot,if=pet.main.buff.beast_cleave.remains<0.25+gcd&(!talent.bloody_frenzy|cooldown.call_of_the_wild.remains)
  if S.MultiShot:IsReady() and (Pet:BuffRemains(S.BeastCleavePetBuff) < 0.25 + Player:GCD() and (not S.BloodyFrenzy:IsAvailable() or S.CalloftheWild:CooldownDown())) then
    if Cast(S.MultiShot, nil, nil, not Target:IsSpellInRange(S.MultiShot)) then return "multishot cleave 4"; end
  end
  -- black_arrow,if=buff.beast_cleave.remains
  if S.BlackArrow:IsReady() and (Pet:BuffUp(S.BeastCleavePetBuff)) then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "black_arrow cleave 6"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild cleave 8"; end
  end
  -- bestial_wrath
  if CDsON() and S.BestialWrath:IsCastable() then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath cleave 10"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed cleave 12"; end
  end
  -- kill_command,target_if=max:(target.health.pct<35|!talent.killer_instinct)*2+dot.a_murder_of_crows.refreshable
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, Enemies40y, "max", EvaluateTargetIfFilterKillCommand, nil, not Target:IsInRange(50)) then return "kill_command cleave 14"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=buff.call_of_the_wild.up|talent.wild_call&charges_fractional>1.2|talent.furious_assault|talent.black_arrow&(talent.barbed_scales|talent.savagery)|fight_remains<9
  if S.BarbedShot:IsCastable() and (Player:BuffUp(S.CalloftheWildBuff) or S.WildCall:IsAvailable() and S.BarbedShot:ChargesFractional() > 1.2 or S.FuriousAssault:IsAvailable() or S.BlackArrowTalent:IsAvailable() and (S.BarbedScales:IsAvailable() or S.Savagery:IsAvailable()) or BossFightRemains < 9) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot cleave 16"; end
  end
  -- cobra_shot,if=buff.bestial_wrath.up&talent.killer_cobra
  if S.CobraShot:IsReady() and (Player:BuffUp(S.BestialWrathBuff) and S.KillerCobra:IsAvailable()) then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot cleave 18"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot cleave 20"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot cleave 22"; end
  end
  -- dire_beast
  if S.DireBeast:IsCastable() then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast cleave 24"; end
  end
  -- lights_judgment,if=buff.bestial_wrath.down|target.time_to_die<5
  if CDsON() and S.LightsJudgment:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(5)) then return "lights_judgment cleave 26"; end
  end
  -- cobra_shot,if=focus.time_to_max<gcd*2
  if S.CobraShot:IsReady() and (Player:FocusTimeToMax() < Player:GCD() * 2) then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot cleave 28"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and CDsON() and (Player:BuffDown(S.BestialWrathBuff) or FightRemains < 5) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks cleave 30"; end
  end
  -- arcane_torrent,if=(focus+focus.regen+30)<focus.max
  if S.ArcaneTorrent:IsCastable() and CDsON() and ((Player:Focus() + Player:FocusRegen() + 30) < Player:FocusMax()) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent cleave 32"; end
  end
end

local function ST()
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd+0.25|pet.main.buff.frenzy.stack<3&(cooldown.bestial_wrath.ready&(!pet.main.buff.frenzy.up|talent.scent_of_blood)|talent.call_of_the_wild&cooldown.call_of_the_wild.ready)
  if S.BarbedShot:IsCastable() and (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= Player:GCD() + 0.25 or Pet:BuffStack(S.FrenzyPetBuff) < 3 and (S.BestialWrath:CooldownUp() and (Pet:BuffDown(S.FrenzyPetBuff) or S.ScentofBlood:IsAvailable()) or S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownUp())) then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st 2"; end
  end
  -- Main Target backup
  if S.BarbedShot:IsCastable() and (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= Player:GCD() + 0.25 or Pet:BuffStack(S.FrenzyPetBuff) < 3 and (S.ScentofBlood:IsAvailable() and (S.BestialWrath:CooldownUp() or S.CalloftheWild:CooldownUp()) or S.BestialWrath:CooldownDown())) then
    if Cast(S.BarbedShot, nil, nil, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st mt_backup 4"; end
  end
  -- kill_command,if=talent.call_of_the_wild&cooldown.call_of_the_wild.remains<gcd+0.25
  if S.KillCommand:IsReady() and (S.CalloftheWild:IsAvailable() and S.CalloftheWild:CooldownRemains() < Player:GCD() + 0.25) then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 6"; end
  end
  -- kill_shot,target_if=min:dot.serpent_sting.remains,if=talent.venoms_bite&(!active_dot.serpent_sting|dot.serpent_sting.refreshable)
  if S.KillShot:IsReady() and (S.VenomsBite:IsAvailable()) then
    if Everyone.CastTargetIf(S.KillShot, Enemies40y, "min", EvaluateTargetIfFilterSerpentSting, EvaluateTargetIfKillShotST, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot st 8"; end
  end
  -- call_of_the_wild
  if CDsON() and S.CalloftheWild:IsCastable() then
    if Cast(S.CalloftheWild, Settings.BeastMastery.GCDasOffGCD.CallOfTheWild) then return "call_of_the_wild st 10"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed, nil, not Target:IsSpellInRange(S.Bloodshed)) then return "bloodshed st 12"; end
  end
  -- bestial_wrath
  if CDsON() and S.BestialWrath:IsCastable() then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath st 14"; end
  end
  -- kill_command,if=cooldown.kill_command.full_recharge_time<1.25*gcd
  if S.KillCommand:IsCastable() and (S.KillCommand:FullRechargeTime() < 1.25 * Player:GCD()) then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 16"; end
  end
  -- multishot,if=buff.beast_cleave.remains<gcd*1.25&talent.bleak_powder&(buff.deathblow.up|(cooldown.black_arrow.remains<gcd&(target.health.pct<20|target.health.pct>81)))
  if S.MultiShot:IsReady() and (Pet:BuffRemains(S.BeastCleavePetBuff) < Player:GCD() * 1.25 and S.BleakPowder:IsAvailable() and (Player:BuffUp(S.DeathblowBuff) or (S.BlackArrow:CooldownRemains() < Player:GCD() and (Target:HealthPercentage() < 20 or Target:HealthPercentage() > 81)))) then
    if Cast(S.MultiShot, nil, nil, not Target:IsSpellInRange(S.MultiShot)) then return "multishot st 18"; end
  end
  -- black_arrow
  if S.BlackArrow:IsReady() then
    if Cast(S.BlackArrow, nil, nil, not Target:IsSpellInRange(S.BlackArrow)) then return "black_arrow st 20"; end
  end
  -- kill_command
  if S.KillCommand:IsReady() then
    if Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 22"; end
  end
  -- dire_beast
  if S.DireBeast:IsCastable() then
    if Cast(S.DireBeast, Settings.BeastMastery.GCDasOffGCD.DireBeast, nil, not Target:IsSpellInRange(S.DireBeast)) then return "dire_beast st 24"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=talent.wild_call&charges_fractional>1.4|buff.call_of_the_wild.up|full_recharge_time<gcd&cooldown.bestial_wrath.remains|talent.scent_of_blood&(cooldown.bestial_wrath.remains<12+gcd)|talent.furious_assault|talent.black_arrow&(talent.barbed_scales|talent.savagery)|fight_remains<9
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateTargetIfFilterBarbedShot, EvaluateTargetIfBarbedShotST, not Target:IsSpellInRange(S.BarbedShot)) then return "barbed_shot st 26"; end
  end
  -- cobra_shot,if=buff.bestial_wrath.up&talent.killer_cobra
  if S.CobraShot:IsReady() and (Player:BuffUp(S.BestialWrathBuff) and S.KillerCobra:IsAvailable()) then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot st 28"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot st 30"; end
  end
  -- lights_judgment,if=buff.bestial_wrath.down|target.time_to_die<5
  if CDsON() and S.LightsJudgment:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(5)) then return "lights_judgment st 32"; end
  end
  -- cobra_shot
  if S.CobraShot:IsReady() then
    if Cast(S.CobraShot, nil, nil, not Target:IsSpellInRange(S.CobraShot)) then return "cobra_shot st 34"; end
  end
  if CDsON() then
    -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
    if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or FightRemains < 5) then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks st 36"; end
    end
    -- arcane_pulse,if=buff.bestial_wrath.down|target.time_to_die<5
    if S.ArcanePulse:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or FightRemains < 5) then
      if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_pulse st 38"; end
    end
    -- arcane_torrent,if=(focus+focus.regen+15)<focus.max
    if S.ArcaneTorrent:IsCastable() and ((Player:Focus() + Player:FocusRegen() + 15) < Player:FocusMax()) then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent st 40"; end
    end
  end
end

local function Trinkets()
  -- variable,name=sync_ready,value=talent.call_of_the_wild&(prev_gcd.1.call_of_the_wild)|!talent.call_of_the_wild&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains_guess<5)
  VarSyncReady = S.CalloftheWild:IsAvailable() and Player:PrevGCD(1, S.CalloftheWild) or not S.CalloftheWild:IsAvailable() and (Player:BuffUp(S.BestialWrathBuff) or S.BestialWrath:CooldownRemains() < 5)
  -- variable,name=sync_active,value=talent.call_of_the_wild&buff.call_of_the_wild.up|!talent.call_of_the_wild&buff.bestial_wrath.up
  VarSyncActive = S.CalloftheWild:IsAvailable() and Player:BuffUp(S.CalloftheWildBuff) or not S.CalloftheWild:IsAvailable() and Player:BuffUp(S.BestialWrathBuff)
  -- variable,name=sync_remains,op=setif,value=cooldown.bestial_wrath.remains_guess,value_else=cooldown.call_of_the_wild.remains,condition=!talent.call_of_the_wild
  VarSyncRemains = (not S.CalloftheWild:IsAvailable()) and S.BestialWrath:CooldownRemains() or S.CalloftheWild:CooldownRemains()
  -- use_item,use_off_gcd=1,slot=trinket1,if=trinket.1.has_use_buff&(variable.sync_ready&(variable.trinket_1_stronger|trinket.2.cooldown.remains)|!variable.sync_ready&(variable.trinket_1_stronger&(variable.sync_remains>trinket.1.cooldown.duration%3&fight_remains>trinket.1.cooldown.duration+20|trinket.2.has_use_buff&trinket.2.cooldown.remains>variable.sync_remains-15&trinket.2.cooldown.remains-5<variable.sync_remains&variable.sync_remains+45>fight_remains)|variable.trinket_2_stronger&(trinket.2.cooldown.remains&(trinket.2.cooldown.remains-5<variable.sync_remains&variable.sync_remains>=20|trinket.2.cooldown.remains-5>=variable.sync_remains&(variable.sync_remains>trinket.1.cooldown.duration%3|trinket.1.cooldown.duration<fight_remains&(variable.sync_remains+trinket.1.cooldown.duration>fight_remains)))|trinket.2.cooldown.ready&variable.sync_remains>20&variable.sync_remains<trinket.2.cooldown.duration%3)))|!trinket.1.has_use_buff&(trinket.1.cast_time=0|!variable.sync_active)&(!trinket.2.has_use_buff&(variable.trinket_1_stronger|trinket.2.cooldown.remains)|trinket.2.has_use_buff&(!variable.sync_active&variable.sync_remains>20|trinket.2.cooldown.remains>20))|fight_remains<25&(variable.trinket_1_stronger|trinket.2.cooldown.remains)
  if Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (Trinket1:HasUseBuff() and (VarSyncReady and (VarTrinket1Stronger or Trinket2:CooldownDown()) or not VarSyncReady and (VarTrinket1Stronger and (VarSyncRemains > VarTrinket1CD / 3 and FightRemains > VarTrinket1CD + 20 or Trinket2:HasUseBuff() and Trinket2:CooldownRemains() > VarSyncRemains - 15 and Trinket2:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains + 45 > FightRemains) or VarTrinket2Stronger and (Trinket2:CooldownDown() and (Trinket2:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains >= 20 or Trinket2:CooldownRemains() - 5 >= VarSyncRemains and (VarSyncRemains > VarTrinket1CD / 3 or VarTrinket1CD < FightRemains and (VarSyncRemains + VarTrinket1CD > FightRemains))) or Trinket2:CooldownUp() and VarSyncRemains > 20 and VarSyncRemains < VarTrinket2CD / 3))) or not Trinket1:HasUseBuff() and (VarTrinket1CastTime == 0 or not VarSyncActive) and (not Trinket2:HasUseBuff() and (VarTrinket1Stronger or Trinket2:CooldownDown()) or Trinket2:HasUseBuff() and (not VarSyncActive and VarSyncRemains > 20 or Trinket2:CooldownRemains() > 20)) or FightRemains < 25 and (VarTrinket1Stronger or Trinket2:CooldownDown())) then
    if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for "..Trinket1:Name().." trinkets 2"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=trinket.2.has_use_buff&(variable.sync_ready&(variable.trinket_2_stronger|trinket.1.cooldown.remains)|!variable.sync_ready&(variable.trinket_2_stronger&(variable.sync_remains>trinket.2.cooldown.duration%3&fight_remains>trinket.2.cooldown.duration+20|trinket.1.has_use_buff&trinket.1.cooldown.remains>variable.sync_remains-15&trinket.1.cooldown.remains-5<variable.sync_remains&variable.sync_remains+45>fight_remains)|variable.trinket_1_stronger&(trinket.1.cooldown.remains&(trinket.1.cooldown.remains-5<variable.sync_remains&variable.sync_remains>=20|trinket.1.cooldown.remains-5>=variable.sync_remains&(variable.sync_remains>trinket.2.cooldown.duration%3|trinket.2.cooldown.duration<fight_remains&(variable.sync_remains+trinket.2.cooldown.duration>fight_remains)))|trinket.1.cooldown.ready&variable.sync_remains>20&variable.sync_remains<trinket.1.cooldown.duration%3)))|!trinket.2.has_use_buff&(trinket.2.cast_time=0|!variable.sync_active)&(!trinket.1.has_use_buff&(variable.trinket_2_stronger|trinket.1.cooldown.remains)|trinket.1.has_use_buff&(!variable.sync_active&variable.sync_remains>20|trinket.1.cooldown.remains>20))|fight_remains<25&(variable.trinket_2_stronger|trinket.1.cooldown.remains)
  if Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (Trinket2:HasUseBuff() and (VarSyncReady and (VarTrinket2Stronger or Trinket1:CooldownDown()) or not VarSyncReady and (VarTrinket2Stronger and (VarSyncRemains > VarTrinket2CD / 3 and FightRemains > VarTrinket2CD + 20 or Trinket1:HasUseBuff() and Trinket1:CooldownRemains() > VarSyncRemains - 15 and Trinket1:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains + 45 > FightRemains) or VarTrinket1Stronger and (Trinket1:CooldownDown() and (Trinket1:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains >= 20 or Trinket1:CooldownRemains() - 5 >= VarSyncRemains and (VarSyncRemains > VarTrinket2CD / 3 or VarTrinket2CD < FightRemains and (VarSyncRemains + VarTrinket2CD > FightRemains))) or Trinket1:CooldownUp() and VarSyncRemains > 20 and VarSyncRemains < VarTrinket1CD / 3))) or not Trinket2:HasUseBuff() and (VarTrinket2CastTime == 0 or not VarSyncActive) and (not Trinket1:HasUseBuff() and (VarTrinket2Stronger or Trinket1:CooldownDown()) or Trinket1:HasUseBuff() and (not VarSyncActive and VarSyncRemains > 20 or Trinket1:CooldownRemains() > 20)) or FightRemains < 25 and (VarTrinket2Stronger or Trinket1:CooldownDown())) then
    if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for "..Trinket2:Name().." trinkets 4"; end
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
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
     local ShouldReturn = Everyone.Interrupt(S.CounterShot, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_shot
    -- call_action_list,name=cds
    if CDsON() then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets then
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
  S.SerpentStingDebuff:RegisterAuraTracking()

  HR.Print("Beast Mastery can use pet abilities to better determine AoE. Make sure you have Growl and Blood Bolt / Bite / Claw / Smack on your player action bars.")
  HR.Print("Beast Mastery Hunter rotation has been updated for patch 11.0.5.")
end

HR.SetAPL(253, APL, OnInit)

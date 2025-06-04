--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- WoW API
local Delay      = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Hunter.Survival
local I = Item.Hunter.Survival

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.ItemName.ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Hunter = HR.Commons.Hunter
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  CommonsDS = HR.GUISettings.APL.Hunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Hunter.CommonsOGCD,
  Survival = HR.GUISettings.APL.Hunter.Survival
}

--- ===== Rotation Variables =====
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }
local MBRS = S.MongooseBite:IsAvailable() and S.MongooseBite or S.RaptorStrike
local EnemyList, EnemyCount
local BossFightRemains = 11111
local FightRemains = 11111
local MBRSRange = 5

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
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

  VarStrongerTrinketSlot = 2
  if VarTrinket2ID ~= I.HouseofCards:ID() and (VarTrinket1ID == I.HouseofCards:ID() or not Trinket2:HasCooldown() or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD))) then
    VarStrongerTrinketSlot = 1
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  MBRS = S.MongooseBite:IsAvailable() and S.MongooseBite or S.RaptorStrike
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function CheckFocusCap(SpellCastTime, GenFocus)
  local GeneratedFocus = GenFocus or 0
  return (Player:Focus() + Player:FocusCastRegen(SpellCastTime) + GeneratedFocus < Player:FocusMax())
end

local function HowlSummonReady()
  return Player:BuffUp(S.HowlBearBuff) or Player:BuffUp(S.HowlBoarBuff) or Player:BuffUp(S.HowlWyvernBuff)
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBloodseekerRemains(TargetUnit)
  -- target_if=min:bloodseeker.remains
  return (TargetUnit:DebuffRemains(S.BloodseekerDebuff))
end

local function EvaluateTargetIfFilterSerpentStingRemains(TargetUnit)
  -- target_if=min:dot.serpent_sting.remains
  return TargetUnit:DebuffRemains(S.SerpentStingDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfMBRSPLST(TargetUnit)
  -- if=!dot.serpent_sting.ticking&target.time_to_die>12&(!talent.contagious_reagents|active_dot.serpent_sting=0)
  -- Note: Parenthetical is handled before CastTargetIf.
  return TargetUnit:DebuffDown(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 12
end

local function EvaluateTargetIfMBRSPLST2(TargetUnit)
  -- if=talent.contagious_reagents&active_dot.serpent_sting<active_enemies&dot.serpent_sting.remains
  -- Note: Talent and active_dot conditions handled before CastTargetIf.
  return TargetUnit:DebuffUp(S.SerpentStingDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- summon_pet
  -- Moved to Pet Management section in APL()
  -- snapshot_stats
  -- variable,name=stronger_trinket_slot,op=setif,value=1,value_else=2,condition=!trinket.2.is.house_of_cards&(trinket.1.is.house_of_cards|!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration)|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration)))
  -- Manually added: harpoon
  if S.Harpoon:IsCastable() and (Player:BuffDown(S.AspectoftheEagle) or not Target:IsInRange(30)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon precombat 4"; end
  end
  -- Manually added: mongoose_bite or raptor_strike
  if MBRS:IsReady() and Target:IsInRange(MBRSRange) then
    if Cast(MBRS) then return "mongoose_bite precombat 6"; end
  end
end

local function CDs()
  -- blood_fury,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  if CDsON() and S.BloodFury:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 2"; end
  end
  -- invoke_external_buff,name=power_infusion,if=(buff.coordinated_assault.up&buff.coordinated_assault.remains>7&!buff.power_infusion.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault)
  -- Note: Not handling external buffs.
  -- harpoon,if=prev.kill_command
  if S.Harpoon:IsCastable() and (Player:PrevGCD(1, S.KillCommand)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon cds 4"; end
  end
  if CDsON() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    -- ancestral_call,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
    end
    -- fireblood,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
    end
  end
  -- berserking,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault|time_to_die<13
  if CDsON() and S.Berserking:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable() or BossFightRemains < 13) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 10"; end
  end
  -- muzzle
  -- Handled via Interrupt in APL()
  -- potion,if=target.time_to_die<25|buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 25 or Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 12"; end
    end
  end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and Settings.Survival.AspectOfTheEagle and not Target:IsInRange(5) then
    if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle cds 14"; end
  end
end

local function PLCleave()
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, Settings.Survival.GCDasOffGCD.Spearhead, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead plcleave 2"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains,if=buff.strike_it_rich.up&buff.strike_it_rich.remains<gcd|buff.hogstrider.remains&boar_charge.remains>0|buff.hogstrider.remains<gcd&buff.hogstrider.up|buff.hogstrider.remains&buff.strike_it_rich.remains|raid_event.adds.exists&raid_event.adds.remains<4
  if MBRS:IsReady() and (Player:BuffUp(S.StrikeItRichBuff) and Player:BuffRemains(S.StrikeItRichBuff) < Player:GCD() or Player:BuffUp(S.HogstriderBuff) and Hunter.PackLeader.BoarChargesRemaining > 0 or Player:BuffRemains(S.HogstriderBuff) < Player:GCD() and Player:BuffUp(S.HogstriderBuff) or Player:BuffUp(S.HogstriderBuff) and Player:BuffUp(S.StrikeItRichBuff)) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plcleave 4"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1
  if S.KillCommand:IsCastable() and (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command plcleave 6"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle plcleave 8"; end
  end
  -- explosive_shot,if=buff.tip_of_the_spear.stack>0
  if S.ExplosiveShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plcleave 10"; end
  end
  -- wildfire_bomb
  if S.WildfireBomb:IsReady() then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb plcleave 12"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=(buff.howl_of_the_pack_leader_wyvern.remains|buff.howl_of_the_pack_leader_boar.remains|buff.howl_of_the_pack_leader_bear.remains)
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.HowlWyvernBuff) or Player:BuffUp(S.HowlBoarBuff) or Player:BuffUp(S.HowlBearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command plcleave 14"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack=2|buff.tip_of_the_spear.stack=1
  if S.FlankingStrike:IsReady() and (Player:BuffStack(S.TipoftheSpearBuff) == 2 or Player:BuffStack(S.TipoftheSpearBuff) == 1) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike plcleave 16"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery plcleave 18"; end
  end
  -- coordinated_assault
  if CDsON() and S.CoordinatedAssault:IsCastable() then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault plcleave 20"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  -- Note: Duplicate of several lines above...
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command plcleave 22"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plcleave 24"; end
  end
  -- kill_shot,if=buff.deathblow.remains&talent.sic_em
  if S.KillShot:IsReady() and (Player:BuffUp(S.DeathblowBuff) and S.SicEm:IsAvailable()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot plcleave 26"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!talent.contagious_reagents
  -- raptor_bite,target_if=max:dot.serpent_sting.remains
  -- Note: Second line covers the condition of the first line...
  if MBRS:IsReady() then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plcleave 28"; end
  end  
end

local function PLST()
  -- kill_command,target_if=min:bloodseeker.remains,if=(buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1)|(buff.howl_of_the_pack_leader_wyvern.remains|buff.howl_of_the_pack_leader_boar.remains|buff.howl_of_the_pack_leader_bear.remains)
  if S.KillCommand:IsCastable() and ((S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffDown(S.TipoftheSpearBuff)) or (Player:BuffUp(S.HowlWyvernBuff) or Player:BuffUp(S.HowlBoarBuff) or Player:BuffUp(S.HowlBearBuff))) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command plst 2"; end
  end
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, Settings.Survival.GCDasOffGCD.Spearhead, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead plst 4"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack>0
  if S.FlankingStrike:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike plst 6"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!dot.serpent_sting.ticking&target.time_to_die>12&(!talent.contagious_reagents|active_dot.serpent_sting=0)
  if MBRS:IsReady() and (not S.ContagiousReagents:IsAvailable() or S.SerpentStingDebuff:AuraActiveCount() == 0) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plst 8"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains,if=talent.contagious_reagents&active_dot.serpent_sting<active_enemies&dot.serpent_sting.remains
  if MBRS:IsReady() and (S.ContagiousReagents:IsAvailable() and S.SerpentStingDebuff:AuraActiveCount() < EnemyCount) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST2, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plst 10"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery plst 12"; end
  end
  -- kill_command,if=buff.strike_it_rich.remains&buff.tip_of_the_spear.stack<1
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.StrikeItRichBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command plst 14"; end
  end
  -- raptor_bite,if=buff.strike_it_rich.remains&buff.tip_of_the_spear.stack>0
  if MBRS:IsReady() and (Player:BuffUp(S.StrikeItRichBuff) and Player:BuffStack(S.TipoftheSpearBuff) > 0) then
    if Cast(MBRS, nil, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plst 16"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.in>40)
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle plst 18"; end
  end
  -- coordinated_assault
  if CDsON() and S.CoordinatedAssault:IsCastable() then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault plst 20"; end
  end
  -- wildfire_bomb
  if S.WildfireBomb:IsReady() then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb plst 22"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains,if=buff.howl_of_the_pack_leader_cooldown.up&buff.howl_of_the_pack_leader_cooldown.remains<2*gcd
  if MBRS:IsReady() and (Player:BuffUp(S.HowlofthePackLeaderCDBuff) and Player:BuffRemains(S.HowlofthePackLeaderCDBuff) < 2 * Player:GCD()) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plst 24"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&(!buff.relentless_primal_ferocity.up|(buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1|focus<30))
  if S.KillCommand:IsReady() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and (not (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff)) or (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffStack(S.TipoftheSpearBuff) < 2 or Player:Focus() < 30))) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command plst 26"; end
  end
  -- explosive_shot,if=active_enemies=2
  if S.ExplosiveShot:IsReady() and (EnemyCount == 2) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plst 28"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!talent.contagious_reagents
  -- raptor_bite,target_if=max:dot.serpent_sting.remains
  -- Note: Second line covers the condition of the first line...
  if MBRS:IsReady() then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " plst 30"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot plst 32"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plst 34"; end
  end
  
end

local function SentCleave()
  -- wildfire_bomb,if=!buff.lunar_storm_cooldown.remains
  if S.WildfireBomb:IsReady() and (Player:BuffDown(S.LunarStormCDBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentcleave 2"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1
  if S.KillCommand:IsCastable() and (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentcleave 4"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9|(talent.bombardier&cooldown.coordinated_assault.remains<2*gcd)|talent.butchery&cooldown.butchery.remains<gcd
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9 or (S.Bombardier:IsAvailable() and S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) or S.Butchery:IsAvailable() and S.Butchery:CooldownRemains() < Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentcleave 6"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle sentcleave 8"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains,if=buff.strike_it_rich.up&buff.strike_it_rich.remains<gcd
  if MBRS:IsReady() and (Player:BuffUp(S.StrikeItRichBuff) and Player:BuffRemains(S.StrikeItRichBuff) < Player:GCD() or Player:BuffUp(S.HogstriderBuff)) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " sentcleave 10"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery sentcleave 12"; end
  end
  -- explosive_shot,if=buff.tip_of_the_spear.stack>0
  if S.ExplosiveShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot sentcleave 14"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault sentcleave 16"; end
  end
  -- flanking_strike,if=(buff.tip_of_the_spear.stack=2|buff.tip_of_the_spear.stack=1)
  if S.FlankingStrike:IsReady() and (Player:BuffStack(S.TipoftheSpearBuff) == 2 or Player:BuffStack(S.TipoftheSpearBuff) == 1) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike sentcleave 18"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentcleave 20"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentcleave 22"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot sentcleave 24"; end
  end
  -- kill_shot,if=buff.deathblow.remains&talent.sic_em
  if S.KillShot:IsReady() and (Player:BuffUp(S.DeathblowBuff) and S.SicEm:IsAvailable()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot sentcleave 26"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!talent.contagious_reagents4
  -- raptor_bite,target_if=max:dot.serpent_sting.remains
  -- Note: Second line covers the condition of the first line...
  if MBRS:IsReady() then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " sentcleave 28"; end
  end
end

local function SentST()
  -- wildfire_bomb,if=!buff.lunar_storm_cooldown.remains
  if S.WildfireBomb:IsReady() and (Player:BuffDown(S.LunarStormCDBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentst 2"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=(buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1)
  if S.KillCommand:IsCastable() and (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentst 4"; end
  end
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, Settings.Survival.GCDasOffGCD.Spearhead, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead sentst 6"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack>0
  if S.FlankingStrike:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike sentst 8"; end
  end
  -- kill_command,if=buff.strike_it_rich.remains&buff.tip_of_the_spear.stack<1
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.StrikeItRichBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentst 10"; end
  end
  -- mongoose_bite,if=buff.strike_it_rich.remains&buff.coordinated_assault.up
  if MBRS:IsReady() and (Player:BuffUp(S.StrikeItRichBuff) and Player:BuffUp(S.CoordinatedAssaultBuff)) then
    if Cast(MBRS, nil, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " sentst 12"; end
  end
  -- wildfire_bomb,if=(buff.lunar_storm_cooldown.remains>full_recharge_time-gcd)&(buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9)|(talent.bombardier&cooldown.coordinated_assault.remains<2*gcd)
  if S.WildfireBomb:IsReady() and ((Player:BuffRemains(S.LunarStormCDBuff) > S.WildfireBomb:FullRechargeTime() - Player:GCD()) and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9) or (S.Bombardier:IsAvailable() and S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD())) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentst 14"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery sentst 16"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault sentst 18"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle sentst 20"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=buff.tip_of_the_spear.stack<1&cooldown.flanking_strike.remains<gcd
  if S.KillCommand:IsReady() and (Player:BuffDown(S.TipoftheSpearBuff) and S.FlankingStrike:CooldownRemains() < Player:GCD()) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentst 22"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&(!buff.relentless_primal_ferocity.up|(buff.relentless_primal_ferocity.up&(buff.tip_of_the_spear.stack<1|focus<30)))4
  if S.KillCommand:IsReady() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and (not (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff)) or (S.RelentlessPrimalFerocity:IsAvailable() and Player:BuffUp(S.CoordinatedAssaultBuff) and (Player:BuffDown(S.TipoftheSpearBuff) or Player:Focus() < 30)))) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentst 24"; end
  end
  -- mongoose_bite,if=buff.mongoose_fury.remains<gcd&buff.mongoose_fury.stack>0
  -- Note: Reversed conditions so we don't bother checking BuffRemains if buff is down.
  if MBRS:IsReady() and (Player:BuffUp(S.MongooseFuryBuff) and Player:BuffRemains(S.MongooseFuryBuff) < Player:GCD()) then
    if Cast(MBRS, nil, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " sentst 26"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&buff.lunar_storm_cooldown.remains>full_recharge_time&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.in>15)
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and Player:BuffRemains(S.LunarStormCDBuff) > S.WildfireBomb:FullRechargeTime()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentst 28"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot sentst 30"; end
  end
  -- mongoose_bite,if=buff.mongoose_fury.remains
  if MBRS:IsReady() and (Player:BuffUp(S.MongooseFuryBuff)) then
    if Cast(MBRS, nil, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " sentst 32"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot sentst 34"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!talent.contagious_reagents
  -- raptor_bite,target_if=max:dot.serpent_sting.remains
  -- Note: Second line covers the condition of the first line...
  if MBRS:IsReady() then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInRange(MBRSRange)) then return MBRS:Name() .. " sentst 36"; end
  end
end

local function Trinkets()
  -- variable,name=buff_sync_ready,value=buff.coordinated_assault.up
  local VarBuffSyncReady = Player:BuffUp(S.CoordinatedAssaultBuff)
  -- variable,name=buff_sync_remains,value=cooldown.coordinated_assault.remains
  local VarBuffSyncRemains = S.CoordinatedAssault:CooldownRemains()
  -- variable,name=buff_sync_active,value=buff.coordinated_assault.up
  local VarBuffSyncActive = Player:BuffUp(S.CoordinatedAssaultBuff)
  -- variable,name=damage_sync_active,value=1
  local VarDamageSyncActive = true
  -- variable,name=damage_sync_remains,value=0
  local VarDamageSyncRemains = 0
  if Settings.Commons.Enabled.Trinkets then
    -- use_items,slots=trinket1:trinket2,if=this_trinket.has_use_buff&(variable.buff_sync_ready&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)|!variable.buff_sync_ready&(variable.stronger_trinket_slot=this_trinket_slot&(variable.buff_sync_remains>this_trinket.cooldown.duration%3&fight_remains>this_trinket.cooldown.duration+20|other_trinket.has_use_buff&other_trinket.cooldown.remains>variable.buff_sync_remains-15&other_trinket.cooldown.remains-5<variable.buff_sync_remains&variable.buff_sync_remains+45>fight_remains)|variable.stronger_trinket_slot!=this_trinket_slot&(other_trinket.cooldown.remains&(other_trinket.cooldown.remains-5<variable.buff_sync_remains&variable.buff_sync_remains>=20|other_trinket.cooldown.remains-5>=variable.buff_sync_remains&(variable.buff_sync_remains>this_trinket.cooldown.duration%3|this_trinket.cooldown.duration<fight_remains&(variable.buff_sync_remains+this_trinket.cooldown.duration>fight_remains)))|other_trinket.cooldown.ready&variable.buff_sync_remains>20&variable.buff_sync_remains<other_trinket.cooldown.duration%3)))|!this_trinket.has_use_buff&(this_trinket.cast_time=0|!variable.buff_sync_active)&(!this_trinket.is.junkmaestros_mega_magnet|buff.junkmaestros_mega_magnet.stack>10)&(!other_trinket.has_cooldown&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|!this_trinket.is.junkmaestros_mega_magnet&variable.damage_sync_remains>this_trinket.cooldown.duration%3)|other_trinket.has_cooldown&(!other_trinket.has_use_buff&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|variable.damage_sync_remains>this_trinket.cooldown.duration%3&!this_trinket.is.junkmaestros_mega_magnet|other_trinket.cooldown.remains-5<variable.damage_sync_remains&variable.damage_sync_remains>=20)|other_trinket.has_use_buff&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|!this_trinket.is.junkmaestros_mega_magnet&variable.damage_sync_remains>this_trinket.cooldown.duration%3)&(other_trinket.cooldown.remains>=20|other_trinket.cooldown.remains-5>variable.buff_sync_remains)))|fight_remains<25&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (Trinket1:HasUseBuff() and (VarBuffSyncReady and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown()) or not VarBuffSyncReady and (VarStrongerTrinketSlot == 1 and (VarBuffSyncRemains > VarTrinket1CD / 3 and BossFightRemains > VarTrinket1CD + 20 or Trinket2:HasUseBuff() and Trinket2:CooldownRemains() > VarBuffSyncRemains - 15 and Trinket2:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains + 45 > BossFightRemains) or VarStrongerTrinketSlot ~= 1 and (Trinket2:CooldownDown() and (Trinket2:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains >= 20 or Trinket2:CooldownRemains() - 5 >= VarBuffSyncRemains and (VarBuffSyncRemains > VarTrinket1CD / 3 or VarTrinket1CD < BossFightRemains and (VarBuffSyncRemains + VarTrinket1CD > BossFightRemains))) or Trinket2:CooldownUp() and VarBuffSyncRemains > 20 and VarBuffSyncRemains < VarTrinket2CD / 3))) or not Trinket1:HasUseBuff() and (VarTrinket1CastTime == 0 or not VarBuffSyncActive) and (Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Player:BuffStack(S.JunkmaestrosBuff) > 10) and (not Trinket2:HasCooldown() and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket1CD / 3) or Trinket2:HasCooldown() and (not Trinket2:HasUseBuff() and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown()) and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or VarDamageSyncRemains > VarTrinket2CD / 3 and Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Trinket2:CooldownRemains() - 5 < VarDamageSyncRemains and VarDamageSyncRemains >= 20) or Trinket2:HasUseBuff() and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket2CD / 3) and (Trinket2:CooldownRemains() >= 20 or Trinket2:CooldownRemains() - 5 > VarBuffSyncRemains))) or BossFightRemains < 25 and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown())) then
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

--- ===== APL Main =====
local function APL()
  -- Target Count Checking
  local EagleUp = Player:BuffUp(S.AspectoftheEagle)
  if EagleUp then
    MBRS = S.MongooseBiteEagle:IsLearned() and S.MongooseBiteEagle or S.RaptorStrikeEagle
    MBRSRange = 40
  else
    MBRS = S.MongooseBite:IsAvailable() and S.MongooseBite or S.RaptorStrike
    MBRSRange = 5
  end
  if AoEON() then
    if EagleUp and not Target:IsInMeleeRange(8) then
      EnemyList = Target:GetEnemiesInSplashRange(8)
      EnemyCount = Target:GetEnemiesInSplashRangeCount(8)
    else
      EnemyList = Player:GetEnemiesInRange(8)
      EnemyCount = #EnemyList
    end
  else
    EnemyCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemyList, false)
    end
  end

  -- Pet Management; Conditions handled via override
  if not (Player:IsMounted() or Player:IsInVehicle()) then
    if S.SummonPet:IsCastable() then
      if Cast(SummonPetSpells[Settings.Commons.SummonPetSlot]) then return "Summon Pet"; end
    end
    if S.RevivePet:IsCastable() then
      if Cast(S.RevivePet, Settings.CommonsOGCD.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
    end
    if S.MendPet:IsCastable() then
      if Cast(S.MendPet, Settings.CommonsOGCD.GCDasOffGCD.MendPet) then return "Mend Pet"; end
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Exhilaration
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.CommonsOGCD.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
    end
    -- muzzle
    local ShouldReturn = Everyone.Interrupt(S.Muzzle, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- Manually added: If out of range, use Aspect of the Eagle, otherwise Harpoon to get back into range
    if not EagleUp and not Target:IsInMeleeRange(8) then
      if S.AspectoftheEagle:IsCastable() and Settings.Survival.AspectOfTheEagle then
        if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle oor"; end
      end
      if S.Harpoon:IsCastable() then
        if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon oor"; end
      end
    end
    -- call_action_list,name=cds
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=plst,if=active_enemies<3&talent.howl_of_the_pack_leader
    if EnemyCount < 3 and S.HowlofthePackLeader:IsAvailable() then
      local ShouldReturn = PLST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=plcleave,if=active_enemies>2&talent.howl_of_the_pack_leader
    if EnemyCount > 2 and S.HowlofthePackLeader:IsAvailable() then
      local ShouldReturn = PLCleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentst,if=active_enemies<3&!talent.howl_of_the_pack_leader
    if EnemyCount < 3 and not S.HowlofthePackLeader:IsAvailable() then
      local ShouldReturn = SentST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentcleave,if=active_enemies>2&!talent.howl_of_the_pack_leader
    if EnemyCount > 2 and not S.HowlofthePackLeader:IsAvailable() then
      local ShouldReturn = SentCleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if CDsON() and S.ArcaneTorrent:IsCastable() then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 2"; end
    end
    -- bag_of_tricks
    if CDsON() and S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 4"; end
    end
    -- lights_judgment
    if CDsON() and S.LightsJudgment:IsCastable() then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 6"; end
    end
    -- PoolFocus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function OnInit ()
  S.SerpentStingDebuff:RegisterAuraTracking()

  HR.Print("Survival Hunter rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(255, APL, OnInit)

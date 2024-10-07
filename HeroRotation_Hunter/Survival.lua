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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Hunter.Survival
local I = Item.Hunter.Survival

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.ManicGrieftorch:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
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
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- Moved to Pet Management section in APL()
  -- use_item,name=imperfect_ascendancy_serum
  if I.ImperfectAscendancySerum:IsEquippedAndReady() then
    if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum precombat 2"; end
  end
  -- snapshot_stats
  -- Manually added: harpoon
  if S.Harpoon:IsCastable() and (Player:BuffDown(S.AspectoftheEagle) or not Target:IsInRange(30)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon precombat 4"; end
  end
  -- Manually added: mongoose_bite or raptor_strike
  if MBRS:IsReady() and Target:IsInMeleeRange(MBRSRange) then
    if Cast(MBRS) then return "mongoose_bite precombat 6"; end
  end
end

local function CDs()
  -- blood_fury,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 2"; end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  -- Note: Not handling external buffs.
  -- harpoon,if=prev.kill_command
  if S.Harpoon:IsCastable() and (Player:PrevGCD(1, S.KillCommand)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon cds 4"; end
  end
  if (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
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
  if S.Berserking:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable() or BossFightRemains < 13) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 12"; end
  end
  -- muzzle
  -- Handled via Interrupt in APL()
  -- potion,if=target.time_to_die<25|buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 25 or Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 14"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=algethar_puzzle_box,use_off_gcd=1
    if I.AlgetharPuzzleBox:IsEquippedAndReady() then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box cds 16"; end
    end
    -- use_item,name=manic_grieftorch
    if I.ManicGrieftorch:IsEquippedAndReady() then
      if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "manic_grieftorch cds 18"; end
    end
    -- use_item,name=beacon_to_the_beyond
    if I.BeacontotheBeyond:IsEquippedAndReady() then
      if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.BeacontotheBeyond)) then return "beacon_to_the_beyond cds 20"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    -- use_items,if=cooldown.coordinated_assault.remains|cooldown.spearhead.remains
    if S.CoordinatedAssault:CooldownDown() or S.Spearhead:CooldownDown() then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
  end
  -- use_item,name=mad_queens_mandate,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&(time_to_die<10|time_to_die>120)&(trinket.skardyns_grace.cooldown.remains|!equipped.skardyns_grace)|time_to_die<10
  if Settings.Commons.Enabled.Trinkets and I.MadQueensMandate:IsEquippedAndReady() and ((Target:TimeToDie() < 10 or Target:TimeToDie() > 120) and (I.SkardynsGrace:CooldownDown() or not I.SkardynsGrace:IsEquipped()) or Target:TimeToDie() < 10) then
    if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "mad_queens_mandate cds 22"; end
  end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and Settings.Survival.AspectOfTheEagle and not Target:IsInRange(5) then
    if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle cds 24"; end
  end
end

local function PLST()
  -- kill_command,target_if=min:bloodseeker.remains,if=(buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1)
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.RelentlessPrimalFerocityBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command plst 2"; end
  end
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead plst 4"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!dot.serpent_sting.ticking&target.time_to_die>12&(!talent.contagious_reagents|active_dot.serpent_sting=0)
  if MBRS:IsReady() and (not S.ContagiousReagents:IsAvailable() or S.SerpentStingDebuff:AuraActiveCount() == 0) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " plst 6"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains,if=talent.contagious_reagents&active_dot.serpent_sting<active_enemies&dot.serpent_sting.remains
  if MBRS:IsReady() and (S.ContagiousReagents:IsAvailable() and S.SerpentStingDebuff:AuraActiveCount() < EnemyCount) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST2, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " plst 8"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9|cooldown.coordinated_assault.remains<2*gcd
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9 or S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb plst 10"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault plst 12"; end
  end
  -- kill_shot,if=(buff.tip_of_the_spear.stack>0|talent.sic_em)
  if S.KillShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) or S.SicEm:IsAvailable()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot plst 14"; end
  end
  -- flanking_strike
  if S.FlankingStrike:IsCastable() then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike plst 16"; end
  end
  -- explosive_shot,if=(talent.spearhead&(!talent.symbiotic_adrenaline&(buff.tip_of_the_spear.stack>0|buff.bombardier.remains)&cooldown.spearhead.remains>20|cooldown.spearhead.remains<2))|((talent.symbiotic_adrenaline|!talent.spearhead)&(buff.tip_of_the_spear.stack>0|buff.bombardier.remains)&cooldown.coordinated_assault.remains>20|cooldown.coordinated_assault.remains<2)
  if S.ExplosiveShot:IsReady() and ((S.Spearhead:IsAvailable() and (not S.SymbioticAdrenaline:IsAvailable() and (Player:BuffUp(S.TipoftheSpearBuff) or Player:BuffUp(S.BombardierBuff)) and S.Spearhead:CooldownRemains() > 20 or S.Spearhead:CooldownRemains() < 2)) or ((S.SymbioticAdrenaline:IsAvailable() or not S.Spearhead:IsAvailable()) and (Player:BuffUp(S.TipoftheSpearBuff) or Player:BuffUp(S.BombardierBuff)) and S.CoordinatedAssault:CooldownRemains() > 20 or S.CoordinatedAssault:CooldownRemains() < 2)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plst 18"; end
  end
  -- raptor_bite,if=(buff.furious_assault.up&buff.tip_of_the_spear.stack>0)&(!talent.mongoose_bite|buff.mongoose_fury.stack>4)
  if MBRS:IsReady() and ((Player:BuffUp(S.FuriousAssaultBuff) and Player:BuffUp(S.TipoftheSpearBuff)) and (not S.MongooseBite:IsAvailable() or Player:BuffStack(S.MongooseFuryBuff) > 4)) then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. "plst 20"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command plst 22"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.in>15)
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb plst 24"; end
  end
  -- fury_of_the_eagle,interrupt=1,if=(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.in>40)
  if S.FuryoftheEagle:IsCastable() then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle plst 26"; end
  end
  -- butchery,if=active_enemies>1&(talent.merciless_blows&buff.merciless_blows.down|!talent.merciless_blows)
  if S.Butchery:IsReady() and (EnemyCount > 1 and (S.MercilessBlows:IsAvailable() and Player:BuffDown(S.MercilessBlowsBuff) or not S.MercilessBlows:IsAvailable())) then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery plst 28"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!talent.contagious_reagents
  if MBRS:IsReady() and (not S.ContagiousReagents:IsAvailable()) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " plst 30"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains
  if MBRS:IsReady() then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " plst 32"; end
  end
end

local function PLCleave()
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead plcleave 2"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.RelentlessPrimalFerocityBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command plcleave 4"; end
  end
  -- explosive_shot,if=buff.bombardier.remains
  if S.ExplosiveShot:IsReady() and (Player:BuffUp(S.BombardierBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plcleave 6"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9|cooldown.coordinated_assault.remains<2*gcd
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9 or S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb plcleave 8"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault plcleave 10"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack=2|buff.tip_of_the_spear.stack=1
  if S.FlankingStrike:IsCastable() and (Player:BuffStack(S.TipoftheSpearBuff) == 2 or Player:BuffStack(S.TipoftheSpearBuff) == 1) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike plcleave 12"; end
  end
  -- explosive_shot,if=(buff.tip_of_the_spear.stack>0|buff.bombardier.remains)&((cooldown.coordinated_assault.remains>20&(cooldown.coordinated_assault.remains<80|buff.coordinated_assault.remains))|(cooldown.coordinated_assault.remains>12&cooldown.coordinated_assault.remains<20))|cooldown.coordinated_assault.remains<2
  if S.ExplosiveShot:IsReady() and ((Player:BuffUp(S.TipoftheSpearBuff) or Player:BuffUp(S.BombardierBuff)) and ((S.CoordinatedAssault:CooldownRemains() > 20 and (S.CoordinatedAssault:CooldownRemains() < 80 or Player:BuffUp(S.CoordinatedAssaultBuff))) or (S.CoordinatedAssault:CooldownRemains() > 12 and S.CoordinatedAssault:CooldownRemains() < 20)) or S.CoordinatedAssault:CooldownRemains() < 2) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot plcleave 14"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle plcleave 16"; end
  end
  -- kill_shot,if=buff.sic_em.remains
  if S.KillShot:IsReady() and (Player:BuffUp(S.SicEmBuff)) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot plcleave 18"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max|buff.exposed_flank.remains&buff.tip_of_the_spear.stack<2
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) or Player:BuffUp(S.ExposedFlankBuff) and Player:BuffStack(S.TipoftheSpearBuff) < 2) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command plcleave 20"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb plcleave 22"; end
  end
  -- butchery,if=charges_fractional>2.8&cooldown.wildfire_bomb.charges_fractional<1.5
  if S.Butchery:IsReady() and (S.Butchery:ChargesFractional() > 2.8 and S.WildfireBomb:ChargesFractional() < 1.5) then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery plcleave 24"; end
  end
  -- raptor_bite,if=buff.merciless_blows.up
  if MBRS:IsReady() and (Player:BuffUp(S.MercilessBlowsBuff)) then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " plcleave 26"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery plcleave 28"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot plcleave 30"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command plcleave 32"; end
  end
  -- raptor_bite
  if MBRS:IsReady() then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " plcleave 34"; end
  end
end

local function SentST()
  -- wildfire_bomb,if=!cooldown.lunar_storm.remains
  if S.WildfireBomb:IsReady() and (S.LunarStorm:CooldownUp()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentst 1"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=(buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1)
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.RelentlessPrimalFerocityBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command sentst 2"; end
  end
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead sentst 4"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!dot.serpent_sting.ticking&target.time_to_die>12&(!talent.contagious_reagents|active_dot.serpent_sting=0)
  if MBRS:IsReady() and (not S.ContagiousReagents:IsAvailable() or S.SerpentStingDebuff:AuraActiveCount() == 0) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " sentst 6"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains,if=talent.contagious_reagents&active_dot.serpent_sting<active_enemies&dot.serpent_sting.remains
  if MBRS:IsReady() and (S.ContagiousReagents:IsAvailable() and S.SerpentStingDebuff:AuraActiveCount() < EnemyCount) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfMBRSPLST2, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " sentst 8"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack=2|buff.tip_of_the_spear.stack=1
  if S.FlankingStrike:IsReady() and (Player:BuffStack(S.TipoftheSpearBuff) == 2 or Player:BuffStack(S.TipoftheSpearBuff) == 1) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike sentst 10"; end
  end
  -- wildfire_bomb,if=(cooldown.lunar_storm.remains>full_recharge_time-gcd)&(buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9)|cooldown.coordinated_assault.remains<2*gcd
  if S.WildfireBomb:IsReady() and ((S.LunarStorm:CooldownRemains() > S.WildfireBomb:FullRechargeTime() - Player:GCD()) and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9) or S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentst 12"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault sentst 14"; end
  end
  -- explosive_shot,if=(talent.spearhead&(!talent.symbiotic_adrenaline&(buff.tip_of_the_spear.stack>0|buff.bombardier.remains)&cooldown.spearhead.remains>20|cooldown.spearhead.remains<2))|((talent.symbiotic_adrenaline|!talent.spearhead)&(buff.tip_of_the_spear.stack>0|buff.bombardier.remains)&cooldown.coordinated_assault.remains>20|cooldown.coordinated_assault.remains<2)
  if S.ExplosiveShot:IsReady() and ((S.Spearhead:IsAvailable() and (not S.SymbioticAdrenaline:IsAvailable() and (Player:BuffUp(S.TipoftheSpearBuff) or Player:BuffUp(S.BombardierBuff)) and S.Spearhead:CooldownRemains() > 20 or S.Spearhead:CooldownRemains() < 2)) or ((S.SymbioticAdrenaline:IsAvailable() or not S.Spearhead:IsAvailable()) and (Player:BuffUp(S.TipoftheSpearBuff) or Player:BuffUp(S.BombardierBuff)) and S.CoordinatedAssault:CooldownRemains() > 20 or S.CoordinatedAssault:CooldownRemains() < 2)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot sentst 16"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0&talent.ruthless_marauder
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff) and S.RuthlessMarauder:IsAvailable()) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle sentst 17"; end
  end
  -- kill_shot,if=buff.tip_of_the_spear.stack>0|talent.sic_em
  if S.KillShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) or S.SicEm:IsAvailable()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot sentst 18"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=buff.tip_of_the_spear.stack<1&cooldown.flanking_strike.remains<gcd
  if S.KillCommand:IsReady() and (Player:BuffDown(S.TipoftheSpearBuff) and S.FlankingStrike:CooldownRemains() < Player:GCD()) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentst 19"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&(!buff.relentless_primal_ferocity.up||(buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<2))
  if S.KillCommand:IsReady() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and (Player:BuffDown(S.RelentlessPrimalFerocityBuff) or (Player:BuffUp(S.RelentlessPrimalFerocityBuff) and Player:BuffStack(S.TipoftheSpearBuff) < 2))) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsInRange(50)) then return "kill_command sentst 20"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.lunar_storm.remains>full_recharge_time&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.in>15)
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.LunarStorm:CooldownRemains() > S.WildfireBomb:FullRechargeTime()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentst 22"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle sentst 24"; end
  end
  -- butchery,if=active_enemies>1&(talent.merciless_blows&buff.merciless_blows.down|!talent.merciless_blows)
  if S.Butchery:IsReady() and (EnemyCount > 1 and (S.MercilessBlows:IsAvailable() and Player:BuffDown(S.MercilessBlowsBuff) or not S.MercilessBlows:IsAvailable())) then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery sentst 26"; end
  end
  -- raptor_bite,target_if=min:dot.serpent_sting.remains,if=!talent.contagious_reagents
  if MBRS:IsReady() and (not S.ContagiousReagents:IsAvailable()) then
    if Everyone.CastTargetIf(MBRS, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " sentst 28"; end
  end
  -- raptor_bite,target_if=max:dot.serpent_sting.remains
  if MBRS:IsReady() then
    if Everyone.CastTargetIf(MBRS, EnemyList, "max", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " sentst 30"; end
  end
end

local function SentCleave()
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead sentcleave 2"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=buff.relentless_primal_ferocity.up&buff.tip_of_the_spear.stack<1
  if S.KillCommand:IsCastable() and (Player:BuffUp(S.RelentlessPrimalFerocityBuff) and Player:BuffDown(S.TipoftheSpearBuff)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command sentcleave 4"; end
  end
  -- explosive_shot,if=buff.bombardier.remains
  if S.ExplosiveShot:IsReady() and (Player:BuffUp(S.BombardierBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot sentcleave 6"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9|cooldown.coordinated_assault.remains<2*gcd
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9 or S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentcleave 8"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault sentcleave 10"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack=2|buff.tip_of_the_spear.stack=1
  if S.FlankingStrike:IsCastable() and (Player:BuffStack(S.TipoftheSpearBuff) == 2 or Player:BuffStack(S.TipoftheSpearBuff) == 1) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike sentcleave 12"; end
  end
  -- explosive_shot,if=(buff.tip_of_the_spear.stack>0|buff.bombardier.remains)&((cooldown.coordinated_assault.remains>20&(cooldown.coordinated_assault.remains<80|buff.coordinated_assault.remains))|(cooldown.coordinated_assault.remains>12&cooldown.coordinated_assault.remains<20))|cooldown.coordinated_assault.remains<2
  if S.ExplosiveShot:IsReady() and ((Player:BuffUp(S.TipoftheSpearBuff) or Player:BuffUp(S.BombardierBuff)) and ((S.CoordinatedAssault:CooldownRemains() > 20 and (S.CoordinatedAssault:CooldownRemains() < 80 or Player:BuffUp(S.CoordinatedAssaultBuff))) or (S.CoordinatedAssault:CooldownRemains() > 12 and S.CoordinatedAssault:CooldownRemains() < 20)) or S.CoordinatedAssault:CooldownRemains() < 2) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot sentcleave 14"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.FuryOfTheEagle, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle sentcleave 16"; end
  end
  -- kill_shot,if=buff.sic_em.remains&active_enemies<4
  if S.KillShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) or S.SicEm:IsAvailable()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot sentcleave 18"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command sentcleave 20"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb sentcleave 22"; end
  end
  -- raptor_bite,if=buff.merciless_blows.up
  if MBRS:IsReady() and (Player:BuffUp(S.MercilessBlowsBuff)) then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " sentcleave 24"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery sentcleave 26"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot sentcleave 28"; end
  end
  -- raptor_bite
  if MBRS:IsReady() then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " sentcleave 30"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Target Count Checking
  local EagleUp = Player:BuffUp(S.AspectoftheEagle)
  MBRSRange = EagleUp and 40 or 5
  if AoEON() then
    if EagleUp and not Target:IsInMeleeRange(8) then
      EnemyList = Player:GetEnemiesInRange(40)
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
      if S.AspectoftheEagle:IsCastable() then
        if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle oor"; end
      end
      if S.Harpoon:IsCastable() then
        if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon oor"; end
      end
    end
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=plst,if=active_enemies<3&talent.vicious_hunt
    if EnemyCount < 3 and S.ViciousHunt:IsAvailable() then
      local ShouldReturn = PLST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=plcleave,if=active_enemies>2&talent.vicious_hunt
    if EnemyCount > 2 and S.ViciousHunt:IsAvailable() then
      local ShouldReturn = PLCleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentst,if=active_enemies<3&!talent.vicious_hunt
    if EnemyCount < 3 and not S.ViciousHunt:IsAvailable() then
      local ShouldReturn = SentST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentcleave,if=active_enemies>2&!talent.vicious_hunt
    if EnemyCount > 2 and not S.ViciousHunt:IsAvailable() then
      local ShouldReturn = SentCleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 2"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 4"; end
    end
    -- PoolFocus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function OnInit ()
  S.SerpentStingDebuff:RegisterAuraTracking()

  HR.Print("Survival Hunter rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(255, APL, OnInit)

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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  Survival = HR.GUISettings.APL.Hunter.Survival
}

-- Spells
local S = Spell.Hunter.Survival

-- Items
local I = Item.Hunter.Survival
local TrinketsOnUseExcludes = {
  I.DreadfireVessel:ID(),
}

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Legendaries
local NessingwarysTrappingEquipped = Player:HasLegendaryEquipped(67)
local SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
local RylakstalkersConfoundingEquipped = Player:HasLegendaryEquipped(79)
HL:RegisterForEvent(function()
  NessingwarysTrappingEquipped = Player:HasLegendaryEquipped(67)
  SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
  RylakstalkersConfoundingEquipped = Player:HasLegendaryEquipped(79)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Rotation Var
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }
local EnemyCount8ySplash, EnemyList
local MBRSCost = S.MongooseBite:IsAvailable() and S.MongooseBite:Cost() or S.RaptorStrike:Cost()

HL:RegisterForEvent(function()
  MBRSCost = S.MongooseBite:IsAvailable() and S.MongooseBite:Cost() or S.RaptorStrike:Cost()
end, "PLAYER_TALENT_UPDATE")

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
}

-- Function to see if we're going to cap focus
local function CheckFocusCap(SpellCastTime, GenFocus)
  local GeneratedFocus = GenFocus or 0
  return (Player:Focus() + Player:FocusCastRegen(SpellCastTime) + GeneratedFocus < Player:FocusMax())
end

-- CastCycle/CastTargetIf functions
-- target_if=min:remains
local function EvaluateTargetIfFilterSerpentStingRemains(TargetUnit)
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff))
end

-- target_if=min:bloodseeker.remains
local function EvaluateTargetIfFilterKillCommandRemains(TargetUnit)
  return (TargetUnit:DebuffRemains(S.BloodseekerDebuff))
end

-- target_if=max:debuff.latent_poison_injection.stack
local function EvaluateTargetIfFilterRaptorStrikeLatentStacks(TargetUnit)
  return (TargetUnit:DebuffStack(S.LatentPoisonDebuff))
end

-- if=!dot.serpent_sting.ticking&target.time_to_die>7|buff.vipers_venom.up&buff.vipers_venom.remains<gcd
local function EvaluateTargetIfSerpentStingST(TargetUnit)
  return (TargetUnit:DebuffDown(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 7 or Player:BuffUp(S.VipersVenomBuff) and Player:BuffRemains(S.VipersVenomBuff) < Player:GCD())
end

-- if=refreshable&target.time_to_die>7|buff.vipers_venom.up
local function EvaluateTargetIfSerpentStingST2(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 7 or Player:BuffUp(S.VipersVenomBuff))
end

-- if=refreshable&talent.hydras_bite.enabled&target.time_to_die>8
local function EvaluateTargetIfSerpentStingCleave(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and S.HydrasBite:IsAvailable() and TargetUnit:TimeToDie() > 8)
end

-- if=refreshable
local function EvaluateTargetIfSerpentStingCleave2(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff))
end

-- if=full_recharge_time<gcd&focus+cast_regen<focus.max
local function EvaluateKillCommandCycleCondition1(TargetUnit)
  return (S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 15))
end

-- if=full_recharge_time<gcd&focus+cast_regen<focus.max
local function EvaluateTargetIfKillCommandST(TargetUnit)
  return (S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 15))
end

-- if=focus+cast_regen<focus.max
local function EvaluateTargetIfKillCommandST2(TargetUnit)
  return (CheckFocusCap(S.KillCommand:ExecuteTime(), 15))
end

-- if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
local function EvaluateTargetIfRaptorStrikeST(TargetUnit)
  return (Player:BuffStack(S.TipoftheSpearBuff) == 3 or TargetUnit:DebuffUp(S.ShrapnelBombDebuff))
end

-- if=talent.alpha_predator.enabled&(buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(variable.mb_rs_cost-cast_regen)*gcd&!buff.wild_spirits.remains|buff.mongoose_fury.remains&next_wi_bomb.pheromone)
local function EvaluateTargetIfMongooseBiteST(TargetUnit) 
  return (S.AlphaPredator:IsAvailable() and (Player:BuffUp(S.MongooseFuryBuff) and Player:BuffRemains(S.MongooseFuryBuff) < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD() and not TargetUnit:DebuffRemains(S.WildSpiritsDebuff) or Player:BuffRemains(S.MongooseFuryBuff) and S.PheromoneBomb:IsCastable()))
end

-- if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max-15|dot.shrapnel_bomb.ticking|buff.wild_spirits.remains
local function EvaluateTargetIfMongooseBiteST2(TargetUnit) 
  return (Player:BuffUp(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 15 or TargetUnit:DebuffUp(S.ShrapnelBombDebuff) or TargetUnit:DebuffRemains(S.WildSpiritsDebuff))
end

-- if=buff.vipers_venom.remains&(buff.vipers_venom.remains<gcd|refreshable)
local function EvaluateTargetIfSerpentStingBOP(TargetUnit)
  return (Player:BuffUp(S.VipersVenomBuff) and (Player:BuffRemains(S.VipersVenomBuff) < Player:GCD() or TargetUnit:DebuffRefreshable(S.SerpentStingDebuff)))
end

-- if=focus+cast_regen<focus.max&buff.nesingwarys_trapping_apparatus.up|focus+cast_regen<focus.max+10&buff.nesingwarys_trapping_apparatus.up&buff.nesingwarys_trapping_apparatus.remains<gcd
local function EvaluateTargetIfKillCommandBOP(TargetUnit)
  return (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and Player:BuffUp(S.NessingwarysTrappingBuff) or Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() + 10 and Player:BuffUp(S.NessingwarysTrappingBuff) and Player:BuffRemains(S.NessingwarysTrappingBuff) < Player:GCD())
end

-- if=focus+cast_regen<focus.max&(!runeforge.nessingwarys_trapping_apparatus|focus<variable.mb_rs_cost)
local function EvaluateTargetIfKillCommandBOP2(TargetUnit)
  return (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and (not NessingwarysTrappingEquipped or Player:Focus() < MBRSCost))
end

-- if=focus+cast_regen<focus.max&runeforge.nessingwarys_trapping_apparatus&cooldown.freezing_trap.remains>(focus%(variable.mb_rs_cost-cast_regen)*gcd)&cooldown.tar_trap.remains>(focus%(variable.mb_rs_cost-cast_regen)*gcd)&(!talent.steel_trap|talent.steel_trap&cooldown.steel_trap.remains>(focus%(variable.mb_rs_cost-cast_regen)*gcd))
local function EvaluateTargetIfKillCommandBOP3(TargetUnit)
  local FocusCap = CheckFocusCap(S.KillCommand:ExecuteTime(), 15)
  local KCFCR = Player:FocusCastRegen(S.KillCommand:ExecuteTime())
  local CurFocus = Player:Focus()
  local CurGCD = Player:GCD()
  local FreezingTrapCheck = S.FreezingTrap:CooldownRemains() > (Player:Focus() / (MBRSCost - KCFCR) * CurGCD)
  local TarTrapCheck = S.TarTrap:CooldownRemains() > (Player:Focus() / (MBRSCost - KCFCR) * CurGCD)
  local SteelTrapCheck = S.SteelTrap:IsAvailable() and (S.SteelTrap:CooldownRemains() > (Player:Focus() / (MBRSCost - KCFCR) * CurGCD))
  return (FocusCap and NessingwarysTrappingEquipped and FreezingTrapCheck and TarTrapCheck and (not S.SteelTrap:IsAvailable() or SteelTrapCheck))
end

-- if=buff.coordinated_assault.up&buff.coordinated_assault.remains<1.5*gcd
local function EvaluateTargetIfRaptorStrikeBOP(TargetUnit)
  return (Player:BuffUp(S.CoordinatedAssault) and Player:BuffRemains(S.CoordinatedAssault) < 1.5 * Player:GCD())
end

-- if=dot.serpent_sting.refreshable&!buff.coordinated_assault.up
local function EvaluateTargetIfSerpentStingBOP2(TargetUnit)
  return (Target:DebuffRefreshable(S.SerpentStingDebuff) and Player:BuffDown(S.CoordinatedAssault))
end

-- if=focus+cast_regen<focus.max&full_recharge_time<gcd&(runeforge.nessingwarys_trapping_apparatus.equipped&cooldown.freezing_trap.remains&cooldown.tar_trap.remains|!runeforge.nessingwarys_trapping_apparatus.equipped)
local function EvaluateTargetIfKillCommandCleave(TargetUnit)
  return (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and S.KillCommand:FullRechargeTime() < Player:GCD() and (NessingwarysTrappingEquipped and not S.FreezingTrap:CooldownUp() and not S.TarTrap:CooldownUp() or not NessingwarysTrappingEquipped))
end

-- target_if=focus+cast_regen<focus.max&(runeforge.nessingwarys_trapping_apparatus.equipped&cooldown.freezing_trap.remains&cooldown.tar_trap.remains|!runeforge.nessingwarys_trapping_apparatus.equipped)
local function EvaluateCycleKillCommandCleave(TargetUnit)
  return (CheckFocusCap(S.KillCommand:ExecuteTime(), 15) and (NessingwarysTrappingEquipped and not S.FreezingTrap:CooldownUp() and not S.TarTrap:CooldownUp() or not NessingwarysTrappingEquipped))
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- variable,name=mb_rs_cost,op=setif,value=action.mongoose_bite.cost,value_else=action.raptor_strike.cost,condition=talent.mongoose_bite
  -- Defined with profile variables
  -- summon_pet
  -- Moved to Pet Management section in APL()
  -- snapshot_stats
  -- fleshcraft
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 4"; end
  end
  -- Manually added: kill_shot
  -- Could be removed?
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot precombat 6"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap precombat 7"; end
  end
  -- Manually added: flare,if=runeforge.soulforge_embers&prev_gcd.1.tar_trap
  if S.Flare:IsCastable() and (SoulForgeEmbersEquipped and Player:PrevGCD(1, S.TarTrap)) then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare precombat 10"; end
  end
  -- steel_trap,precast_time=20
  if S.SteelTrap:IsCastable() and Target:DebuffDown(S.SteelTrapDebuff) then
    if Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap precombat 12"; end
  end
  -- Manually added: harpoon
  if S.Harpoon:IsCastable() and (Player:BuffDown(S.AspectoftheEagle) or not Target:IsInRange(40)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon precombat 14"; end
  end
  -- Manually added: mongoose_bite or raptor_strike
  if Target:IsInMeleeRange(5) or (Player:BuffUp(S.AspectoftheEagle) and Target:IsInRange(40)) then
    if S.MongooseBite:IsReady() then
      if Cast(S.MongooseBite) then return "mongoose_bite precombat 16"; end
    elseif S.RaptorStrike:IsReady() then
      if Cast(S.RaptorStrike) then return "raptor_strike precombat 18"; end
    end
  end
end

local function CDs()
  -- harpoon,if=talent.terms_of_engagement.enabled&focus<focus.max
  if S.Harpoon:IsCastable() and (S.TermsofEngagement:IsAvailable() and Player:Focus() < Player:FocusMax()) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon cds 2"; end
  end
  if (Player:BuffUp(S.CoordinatedAssault)) then
    -- blood_fury,if=buff.coordinated_assault.up
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 6"; end
    end
    -- ancestral_call,if=buff.coordinated_assault.up
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 8"; end
    end
    -- fireblood,if=buff.coordinated_assault.up
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 10"; end
    end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 12"; end
  end
  -- bag_of_tricks,if=cooldown.kill_command.full_recharge_time>gcd
  if S.BagofTricks:IsCastable() and (S.KillCommand:FullRechargeTime() > Player:GCD()) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cds 14"; end
  end
  -- berserking,if=buff.coordinated_assault.up|time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.CoordinatedAssault) or Target:TimeToDie() < 13) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 16"; end
  end
  -- muzzle
  -- potion,if=target.time_to_die<60|buff.coordinated_assault.up
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions and (Target:TimeToDie() < 60 or Player:BuffUp(S.CoordinatedAssault)) then
    if Cast(I.PotionOfSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 18"; end
  end
  -- fleshcraft,cancel_if=channeling&!soulbind.pustule_eruption,if=(focus<70|cooldown.coordinated_assault.remains<gcd)&(soulbind.pustule_eruption|soulbind.volatile_solvent)
  if S.Fleshcraft:IsCastable() and ((Player:Focus() < 70 or S.CoordinatedAssault:CooldownRemains() < Player:GCD()) and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled())) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft cds 19"; end
  end
  -- tar_trap,if=focus+cast_regen<focus.max&runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd&(active_enemies>1|active_enemies=1&time_to_die>5*gcd)
  if S.TarTrap:IsCastable() and (CheckFocusCap(S.TarTrap:ExecuteTime()) and SoulForgeEmbersEquipped and Target:DebuffDown(S.SoulforgeEmbersDebuff) and (EnemyCount8ySplash > 1 or EnemyCount8ySplash == 1 and Target:TimeToDie() > 5 * Player:GCD())) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap cds 20"; end
  end
  
  -- flare,if=focus+cast_regen<focus.max&tar_trap.up&runeforge.soulforge_embers.equipped&time_to_die>4*gcd
  if S.Flare:IsCastable() and (CheckFocusCap(S.Flare:ExecuteTime()) and SoulForgeEmbersEquipped and Target:TimeToDie() > 4 * Player:GCD()) then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare cds 22"; end
  end
  -- kill_shot,if=active_enemies=1&target.time_to_die<focus%(variable.mb_rs_cost-cast_regen)*gcd
  if S.KillShot:IsReady() and (EnemyCount8ySplash == 1 and Target:TimeToDie() < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.KillShot:ExecuteTime())) * Player:GCD()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot cds 24"; end
  end
  -- mongoose_bite,if=active_enemies=1&target.time_to_die<focus%(variable.mb_rs_cost-cast_regen)*gcd
  if S.MongooseBite:IsReady() and (EnemyCount8ySplash == 1 and Target:TimeToDie() < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD()) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite cds 26"; end
  end
  -- raptor_strike,if=active_enemies=1&target.time_to_die<focus%(variable.mb_rs_cost-cast_regen)*gcd
  if S.RaptorStrike:IsReady() and (EnemyCount8ySplash == 1 and Target:TimeToDie() < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD()) then
    if Cast(S.RaptorStrike, nil, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike cds 28"; end
  end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and not Target:IsInRange(6) then
    if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle cds 30"; end
  end
end

local function NTA()
  -- steel_trap
  if S.SteelTrap:IsCastable() then
    if Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap nta 2"; end
  end
  -- freezing_trap,if=!buff.wild_spirits.remains|buff.wild_spirits.remains&cooldown.kill_command.remains
  if S.FreezingTrap:IsCastable() and (Target:DebuffDown(S.WildSpiritsDebuff) or Target:DebuffUp(S.WildSpiritsDebuff) and not S.KillCommand:CooldownUp()) then
    if Cast(S.FreezingTrap, Settings.Commons.GCDasOffGCD.FreezingTrap, nil, not Target:IsInRange(40)) then return "freezing_trap nta 4"; end
  end
  -- tar_trap,if=!buff.wild_spirits.remains|buff.wild_spirits.remains&cooldown.kill_command.remains
  if S.TarTrap:IsCastable() and (Target:DebuffDown(S.WildSpiritsDebuff) or Target:DebuffUp(S.WildSpiritsDebuff) and not S.KillCommand:CooldownUp()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap nta 6"; end
  end
end

local function ST()
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (CheckFocusCap(S.DeathChakram:ExecuteTime())) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DeathChakram)) then return "death_chakram st 2"; end
  end
  -- serpent_sting,target_if=min:remains,if=!dot.serpent_sting.ticking&target.time_to_die>7|buff.vipers_venom.up&buff.vipers_venom.remains<gcd
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingST, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting st 4"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.FlayedShot)) then return "flayed_shot st 6"; end
  end
  if CDsON() then
    -- resonating_arrow
    if S.ResonatingArrow:IsCastable() then
      if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "resonating_arrow st 8"; end
    end
    -- wild_spirits
    if S.WildSpirits:IsCastable() then
      if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "wild_spirits st 10"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastable() then
      if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault st 12"; end
    end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot st 14"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (CheckFocusCap(S.FlankingStrike:ExecuteTime())) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike st 16"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() and CDsON() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not Target:IsSpellInRange(S.AMurderofCrows)) then return "a_murder_of_crows st 18"; end
  end
  -- wildfire_bomb,if=full_recharge_time<gcd|focus+cast_regen<focus.max&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)|time_to_die<10
  if S.PheromoneBomb:IsReady() and (S.WildfireBomb:FullRechargeTime() < Player:GCD() or CheckFocusCap(S.WildfireBomb:ExecuteTime()) and Player:BuffDown(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3 or Target:TimeToDie() < 10) then
    if Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "pheromone_bomb st 20"; end
  end
  if S.VolatileBomb:IsReady() and (S.WildfireBomb:FullRechargeTime() < Player:GCD() or CheckFocusCap(S.WildfireBomb:ExecuteTime()) and Target:DebuffUp(S.SerpentStingDebuff) and Target:DebuffRefreshable(S.SerpentStingDebuff) or Target:TimeToDie() < 10) then
    if Cast(S.VolatileBomb, nil, nil, not Target:IsSpellInRange(S.VolatileBomb)) then return "volatile_bomb st 22"; end
  end
  -- carve,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped
  if S.Carve:IsReady() and (EnemyCount8ySplash > 1 and not RylakstalkersConfoundingEquipped) then
    if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve st 24"; end
  end
  -- butchery,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped&cooldown.wildfire_bomb.full_recharge_time>spell_targets&(charges_fractional>2.5|dot.shrapnel_bomb.ticking)
  if S.Butchery:IsReady() and (EnemyCount8ySplash > 1 and not RylakstalkersConfoundingEquipped and S.WildfireBomb:FullRechargeTime() > EnemyCount8ySplash and (S.Butchery:ChargesFractional() > 2.5 or Target:DebuffUp(S.ShrapnelBombDebuff))) then
    if Cast(S.Butchery, nil, nil, not Target:IsInRange(8)) then return "butchery st 26"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (CheckFocusCap(S.SteelTrap:ExecuteTime())) then
    if Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap st 28"; end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=talent.alpha_predator.enabled&(buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(variable.mb_rs_cost-cast_regen)*gcd&!buff.wild_spirits.remains|buff.mongoose_fury.remains&next_wi_bomb.pheromone)
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, EvaluateTargetIfMongooseBiteST, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite st 30"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterKillCommandRemains, EvaluateTargetIfKillCommandST, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 32"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack,if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, EvaluateTargetIfRaptorStrikeST, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike st 34"; end
  end
  -- mongoose_bite,if=dot.shrapnel_bomb.ticking
  if S.MongooseBite:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite st 36"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>7|buff.vipers_venom.up
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingST2, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting st 38"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.shrapnel&focus>variable.mb_rs_cost*2&dot.serpent_sting.remains>5*gcd
  if S.ShrapnelBomb:IsCastable() and (Player:Focus() > MBRSCost * 2 and Target:DebuffRemains(S.SerpentStingDebuff) > 5 * Player:GCD()) then
    if Cast(S.ShrapnelBomb, nil, nil, not Target:IsSpellInRange(S.ShrapnelBomb)) then return "shrapnel_bomb st 40"; end
  end
  -- chakrams
  if S.Chakrams:IsReady() then
    if Cast(S.Chakrams, nil, nil, not Target:IsSpellInRange(S.Chakrams)) then return "chakrams st 42"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterKillCommandRemains, EvaluateTargetIfKillCommandST2, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 44"; end
  end
  -- wildfire_bomb,if=runeforge.rylakstalkers_confounding_strikes.equipped
  if RylakstalkersConfoundingEquipped then
    if S.ShrapnelBomb:IsCastable() then
      if Cast(S.ShrapnelBomb, nil, nil, not Target:IsSpellInRange(S.ShrapnelBomb)) then return "shrapnel_bomb st 46"; end
    end
    if S.PheromoneBomb:IsCastable() then
      if Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "pheromone_bomb st 48"; end
    end
    if S.VolatileBomb:IsCastable() then
      if Cast(S.VolatileBomb, nil, nil, not Target:IsSpellInRange(S.VolatileBomb)) then return "volatile_bomb st 50"; end
    end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max-15|dot.shrapnel_bomb.ticking|buff.wild_spirits.remains
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, EvaluateTargetIfMongooseBiteST2, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite st 52"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike st 54"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
  if S.VolatileBomb:IsCastable() and (Target:DebuffUp(S.SerpentStingDebuff)) then
    if Cast(S.VolatileBomb, nil, nil, not Target:IsSpellInRange(S.VolatileBomb)) then return "volatile_bomb st 56"; end
  end
  if S.PheromoneBomb:IsCastable() then
    if Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "pheromone_bomb st 58"; end
  end
  if S.ShrapnelBomb:IsCastable() and (Player:Focus() > 50) then
    if Cast(S.ShrapnelBomb, nil, nil, not Target:IsSpellInRange(S.ShrapnelBomb)) then return "shrapnel_bomb st 60"; end
  end
end

local function BOP()
  -- serpent_sting,target_if=min:remains,if=buff.vipers_venom.remains&(buff.vipers_venom.remains<gcd|refreshable)
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingBOP, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting bop 2"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.nesingwarys_trapping_apparatus.up|focus+cast_regen<focus.max+10&buff.nesingwarys_trapping_apparatus.up&buff.nesingwarys_trapping_apparatus.remains<gcd
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterKillCommandRemains, EvaluateTargetIfKillCommandBOP, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command bop 6"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot bop 4"; end
  end
  -- wildfire_bomb,if=focus+cast_regen<focus.max&!ticking&full_recharge_time<gcd
  if S.WildfireBomb:IsCastable() and (CheckFocusCap(S.WildfireBomb:ExecuteTime()) and Target:DebuffDown(S.WildfireBombDebuff) and S.WildfireBomb:FullRechargeTime() < Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb bop 8"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (CheckFocusCap(S.FlankingStrike:ExecuteTime())) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike bop 10"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.FlayedShot)) then return "flayed_shot bop 12"; end
  end
  -- call_action_list,name=nta,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus<variable.mb_rs_cost
  if (NessingwarysTrappingEquipped and Player:Focus() < MBRSCost) then
    local ShouldReturn = NTA(); if ShouldReturn then return ShouldReturn; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (CheckFocusCap(S.DeathChakram:ExecuteTime())) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DeathChakram)) then return "death_chakram bop 14"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack,if=buff.coordinated_assault.up&buff.coordinated_assault.remains<1.5*gcd
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, EvaluateTargetIfRaptorStrikeBOP, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike bop 16"; end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.coordinated_assault.up&buff.coordinated_assault.remains<1.5*gcd
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, EvaluateTargetIfRaptorStrikeBOP, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite bop 18"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not Target:IsSpellInRange(S.AMurderofCrows)) then return "a_murder_of_crows bop 20"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack,if=buff.tip_of_the_spear.stack=3
  if S.RaptorStrike:IsReady() and (Player:BuffStack(S.TipoftheSpearBuff) == 3) then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike bop 22"; end
  end
  -- wildfire_bomb,if=focus+cast_regen<focus.max&!ticking&(full_recharge_time<gcd|!dot.wildfire_bomb.ticking&buff.mongoose_fury.remains>full_recharge_time-1*gcd|!dot.wildfire_bomb.ticking&!buff.mongoose_fury.remains)|time_to_die<18&!dot.wildfire_bomb.ticking
  if S.WildfireBomb:IsCastable() and (CheckFocusCap(S.WildfireBomb:ExecuteTime()) and Target:DebuffDown(S.WildfireBombDebuff) and (S.WildfireBomb:FullRechargeTime() < Player:GCD() or Target:DebuffDown(S.WildfireBombDebuff) and Player:BuffRemains(S.MongooseFuryBuff) > S.WildfireBomb:FullRechargeTime() - Player:GCD() or Target:DebuffDown(S.WildfireBombDebuff) and Player:BuffDown(S.MongooseFuryBuff)) or Target:TimeToDie() < 18 and Target:DebuffDown(S.WildfireBombDebuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb bop 24"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&(!runeforge.nessingwarys_trapping_apparatus|focus<variable.mb_rs_cost)
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterKillCommandRemains, EvaluateTargetIfKillCommandBOP2, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command bop 26"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&runeforge.nessingwarys_trapping_apparatus&cooldown.freezing_trap.remains>(focus%(variable.mb_rs_cost-cast_regen)*gcd)&cooldown.tar_trap.remains>(focus%(variable.mb_rs_cost-cast_regen)*gcd)&(!talent.steel_trap|talent.steel_trap&cooldown.steel_trap.remains>(focus%(variable.mb_rs_cost-cast_regen)*gcd))
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterKillCommandRemains, EvaluateTargetIfKillCommandBOP3, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command bop 28"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (CheckFocusCap(S.SteelTrap:ExecuteTime())) then
    if Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap bop 32"; end
  end
  -- serpent_sting,target_if=min:remains,if=dot.serpent_sting.refreshable&!buff.coordinated_assault.up
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingBOP2, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting bop 34"; end
  end
  if CDsON() then
    -- resonating_arrow
    if S.ResonatingArrow:IsCastable() then
      if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "resonating_arrow bop 36"; end
    end
    -- wild_spirits
    if S.WildSpirits:IsCastable() then
      if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "wild_spirits bop 38"; end
    end
    -- coordinated_assault,if=!buff.coordinated_assault.up
    if S.CoordinatedAssault:IsCastable() then
      if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault bop 40"; end
    end
  end
  -- mongoose_bite,if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max|buff.coordinated_assault.up
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) > Player:FocusMax() or Player:BuffUp(S.CoordinatedAssault)) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite bop 42"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike bop 44"; end
  end
  -- wildfire_bomb,if=dot.wildfire_bomb.refreshable
  if S.WildfireBomb:IsCastable() and (Target:DebuffRefreshable(S.WildfireBombDebuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb bop 46"; end
  end
  -- serpent_sting,target_if=min:remains,if=buff.vipers_venom.up
  if S.SerpentSting:IsReady() and (Player:BuffUp(S.VipersVenomBuff)) then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting bop 48"; end
  end
end

local function Cleave()
  -- serpent_sting,target_if=min:remains,if=talent.hydras_bite.enabled&buff.vipers_venom.remains&buff.vipers_venom.remains<gcd
  if S.SerpentSting:IsReady() and (S.HydrasBite:IsAvailable() and Player:BuffUp(S.VipersVenomBuff) and Player:BuffRemains(S.VipersVenomBuff) < Player:GCD()) then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting cleave 2"; end
  end
  if CDsON() then
    -- wild_spirits
    if S.WildSpirits:IsCastable() then
      if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "wild_spirits cleave 4"; end
    end
    -- resonating_arrow
    if S.ResonatingArrow:IsCastable() then
      if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "resonating_arrow cleave 6"; end
    end
  end
  -- coordinated_assault
  if S.CoordinatedAssault:IsCastable() then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault cleave 7"; end
  end
  -- wildfire_bomb,if=full_recharge_time<gcd
  if S.WildfireBomb:FullRechargeTime() < Player:GCD() then
    if S.WildfireInfusion:IsAvailable() then
      if S.ShrapnelBomb:IsCastable() then
        if Cast(S.ShrapnelBomb, nil, nil, not Target:IsSpellInRange(S.ShrapnelBomb)) then return "shrapnel_bomb cleave 8"; end
      end
      if S.PheromoneBomb:IsCastable() then
        if Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "pheromone_bomb cleave 8"; end
      end
      if S.VolatileBomb:IsCastable() then
        if Cast(S.VolatileBomb, nil, nil, not Target:IsSpellInRange(S.VolatileBomb)) then return "volatile_bomb cleave 8"; end
      end
    else
      if S.WildfireBomb:IsCastable() then
        if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb cleave 8"; end
      end
    end
  end
  -- call_action_list,name=nta,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus<variable.mb_rs_cost
  if (NessingwarysTrappingEquipped and Player:Focus() < MBRSCost) then
    local ShouldReturn = NTA(); if ShouldReturn then return ShouldReturn; end
  end
  -- chakrams
  if S.Chakrams:IsReady() then
    if Cast(S.Chakrams, nil, nil, not Target:IsSpellInRange(S.Chakrams)) then return "chakrams cleave 10"; end
  end
  -- butchery,if=dot.shrapnel_bomb.ticking&(dot.internal_bleeding.stack<2|dot.shrapnel_bomb.remains<gcd)
  if S.Butchery:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff) and (Target:DebuffStack(S.InternalBleedingDebuff) < 2 or Target:DebuffRemains(S.ShrapnelBombDebuff) < Player:GCD())) then
    if Cast(S.Butchery, nil, nil, not Target:IsInRange(8)) then return "butchery cleave 12"; end
  end
  -- carve,if=dot.shrapnel_bomb.ticking
  if S.Carve:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve cleave 14"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (CheckFocusCap(S.DeathChakram:ExecuteTime())) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DeathChakram)) then return "death_chakram cleave 16"; end
  end
  -- butchery,if=charges_fractional>2.5&cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  if S.Butchery:IsReady() and (S.Butchery:ChargesFractional() > 2.5 and S.WildfireBomb:FullRechargeTime() > EnemyCount8ySplash / 2) then
    if Cast(S.Butchery, nil, nil, not Target:IsInRange(8)) then return "butchery cleave 20"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (CheckFocusCap(S.FlankingStrike:ExecuteTime())) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike cleave 22"; end
  end
  -- carve,if=cooldown.wildfire_bomb.full_recharge_time>spell_targets%2&talent.alpha_predator.enabled
  if S.Carve:IsReady() and (S.WildfireBomb:FullRechargeTime() > EnemyCount8ySplash / 2 and S.AlphaPredator:IsAvailable()) then
    if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve cleave 24"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&full_recharge_time<gcd&(runeforge.nessingwarys_trapping_apparatus.equipped&cooldown.freezing_trap.remains&cooldown.tar_trap.remains|!runeforge.nessingwarys_trapping_apparatus.equipped)
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterKillCommandRemains, EvaluateTargetIfKillCommandCleave, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command cleave 26"; end
  end
  -- wildfire_bomb,if=!dot.wildfire_bomb.ticking
  if S.WildfireBomb:IsCastable() and (Target:DebuffDown(S.WildfireBombDebuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb cleave 28"; end
  end
  -- butchery,if=(!next_wi_bomb.shrapnel|!talent.wildfire_infusion.enabled)&cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  if S.Butchery:IsReady() and ((not S.ShrapnelBomb:IsCastable() or not S.WildfireInfusion:IsAvailable()) and S.WildfireBomb:FullRechargeTime() > EnemyCount8ySplash / 2) then
    if Cast(S.Butchery, nil, nil, not Target:IsInRange(8)) then return "butchery cleave 30"; end
  end
  -- carve,if=cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  if S.Carve:IsReady() and (S.WildfireBomb:FullRechargeTime() > EnemyCount8ySplash / 2) then
    if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve cleave 32"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot cleave 34"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.FlayedShot)) then return "flayed_shot cleave 36"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() and CDsON() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not Target:IsSpellInRange(S.AMurderofCrows)) then return "a_murder_of_crows cleave 38"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (CheckFocusCap(S.SteelTrap:ExecuteTime())) then
    if Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap cleave 40"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&talent.hydras_bite.enabled&target.time_to_die>8
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingCleave, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting cleave 42"; end
  end
  -- carve
  if S.Carve:IsReady() then
    if Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "carve cleave 44"; end
  end
  -- kill_command,target_if=focus+cast_regen<focus.max&(runeforge.nessingwarys_trapping_apparatus.equipped&cooldown.freezing_trap.remains&cooldown.tar_trap.remains|!runeforge.nessingwarys_trapping_apparatus.equipped)
  if S.KillCommand:IsCastable() then
    if Everyone.CastCycle(S.KillCommand, EnemyList, EvaluateCycleKillCommandCleave, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command cleave 46"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingCleave2, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting cleave 48"; end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "mongoose_bite cleave 50"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterRaptorStrikeLatentStacks, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "raptor_strike cleave 52"; end
  end
end

local function APL()
  -- Target Count Checking
  local EagleUp = Player:BuffUp(S.AspectoftheEagle)
  if AoEON() then
    if EagleUp and not Target:IsInMeleeRange(8) then
      EnemyCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    else
      EnemyCount8ySplash = #Player:GetEnemiesInRange(8)
    end
  else
    EnemyCount8ySplash = 1
  end

  if EagleUp then
    EnemyList = Player:GetEnemiesInRange(40)
  else
    EnemyList = Player:GetEnemiesInRange(8)
  end

  -- Pet Management; Conditions handled via override
  if S.SummonPet:IsCastable() then
    if Cast(SummonPetSpells[Settings.Commons2.SummonPetSlot]) then return "Summon Pet"; end
  end
  if S.RevivePet:IsCastable() then
    if Cast(S.RevivePet, Settings.Commons2.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
  end
  if S.MendPet:IsCastable() then
    if Cast(S.MendPet, Settings.Commons2.GCDasOffGCD.MendPet) then return "Mend Pet"; end
  end

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Exhilaration
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons2.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.Commons2.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
    end
    -- muzzle
    local ShouldReturn = Everyone.Interrupt(5, S.Muzzle, Settings.Survival.OffGCDasOffGCD.Muzzle, StunInterrupts); if ShouldReturn then return ShouldReturn; end
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
    -- use_item,name=jotungeirr_destinys_call,if=buff.coordinated_assault.up|time_to_die<30
    if I.Jotungeirr:IsReady() and (Player:BuffUp(S.CoordinatedAssault) or Target:TimeToDie() < 30) then
      if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call main 2"; end
    end
    -- use_items
    if Settings.Commons.Enabled.Trinkets then
      local TrinketToUse = Player:GetUseableTrinkets(TrinketsOnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- newfound_resolve,if=soulbind.newfound_resolve&(buff.resonating_arrow.up|cooldown.resonating_arrow.remains>10|target.time_to_die<16)
    -- Unable to handle player facing
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=bop,if=active_enemies<3&talent.birds_of_prey.enabled
    if (EnemyCount8ySplash < 3 and S.BirdsofPrey:IsAvailable()) then
      local ShouldReturn = BOP(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3&!talent.birds_of_prey.enabled
    if (EnemyCount8ySplash < 3 and not S.BirdsofPrey:IsAvailable()) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>2
    if (EnemyCount8ySplash > 2) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 888"; end
    end
    -- PoolFocus if nothing else to do
    if Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

local function OnInit ()
  HR.Print("Survival Hunter rotation is currently a work in progress, but has been updated for patch 9.1.")
end

HR.SetAPL(255, APL, OnInit)

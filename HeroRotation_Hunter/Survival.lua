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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999
-- Define S/I for spell and item arrays
local S = Spell.Hunter.Survival
local I = Item.Hunter.Survival

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemy8y, Enemy40y, Enemy50y
local EnemyCount8y, EnemyCount40y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  Survival = HR.GUISettings.APL.Hunter.Survival
}

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
}

-- Legendaries
local SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
HL:RegisterForEvent(function()
  SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
end, "PLAYER_EQUIPMENT_CHANGED")

--Helpers
-- target_if=min:dot.serpent_sting.remains
local function EvaluateSerpentStingCycleTargetIfCondition(TargetUnit)
  return TargetUnit:DebuffRemains(S.SerpentStingDebuff)
end

-- if=!dot.serpent_sting.ticking&target.time_to_die>7
local function EvaluateSerpentStingCycleCondition1(TargetUnit)
  return TargetUnit:DebuffDown(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 7
end

-- if=refreshable&target.time_to_die>7
local function EvaluateSerpentStingCycleCondition2(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 7 
end

-- target_if=min:bloodseeker.remains
local function EvaluateKillCommandCycleTargetIfCondition(TargetUnit)
  return TargetUnit:DebuffRemains(S.BloodseekerDebuff)
end

-- if=full_recharge_time<gcd&focus+cast_regen<focus.max
local function EvaluateKillCommandCycleCondition1(TargetUnit)
  return S.KillCommand:FullRechargeTime() < Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax()
end

-- if=focus+cast_regen<focus.max
local function EvaluateKillCommandCycleCondition2(TargetUnit)
  return Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax()
end

-- target_if=max:debuff.latent_poison_injection.stack
local function EvaluateRaptorStrikeTargetIfCondition(TargetUnit)
  return TargetUnit:DebuffStack(S.LatentPoisonDebuff)
end

-- if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
local function EvaluateRaptorStrikeCycleCondition1(TargetUnit)
  return Player:BuffStack(S.TipoftheSpearBuff) == 3 or TargetUnit:DebuffUp(S.ShrapnelBombDebuff)
end

-- if=buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(action.mongoose_bite.cost-cast_regen)*gcd&!buff.wild_spirits.remains|buff.mongoose_fury.remains&next_wi_bomb.pheromone
local function EvaluateMangooseBiteCycleCondition1(TargetUnit) 
  return Player:BuffUp(S.MongooseFuryBuff) and Player:BuffRemains(S.MongooseFuryBuff) < Player:Focus() / (S.MongooseBite:Cost() - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD() and not Player:BuffRemains(S.WildSpiritsBuff) or Player:BuffRemains(S.MongooseFuryBuff) and S.PheromoneBomb:IsCastable()
end

-- if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max-15|dot.shrapnel_bomb.ticking|buff.wild_spirits.remains
local function EvaluateMangooseBiteCycleCondition2(TargetUnit) 
  return Player:BuffUp(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 15 or TargetUnit:DebuffUp(S.ShrapnelBombDebuff) or Player:BuffRemains(S.WildSpiritsBuff)
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- Kill Shot
    if S.KillShot:IsCastable() then
      if HR.Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "Kill Shot (PreCombat)"; end
    end
    -- REMOVE coordinated_assault
    if S.CoordinatedAssault:IsCastable() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault 6"; end
    end
    -- tar_trap,if=runeforge.soulforge_embers
    if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
      if HR.Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare st 5"; end
    end
    -- steel_trap,precast_time=20
    if S.SteelTrap:IsCastable() and Player:DebuffDown(S.SteelTrapDebuff) then
      if HR.Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap 10"; end
    end
    -- REMOVE harpoon
    if S.Harpoon:IsCastable() then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsInRange(30)) then return "harpoon 12"; end
    end
  end
end

local function Cds()
  if S.Harpoon:IsReady() and S.TermsofEngagement:IsAvailable() and Player:Focus() < Player:FocusMax() then
    if HR.Cast(S.Harpoon, nil, nil, not Target:IsInRange(30)) then return "[CDs] Harpoon CDs 379"; end
  end
  -- blood_fury,if=cooldown.coordinated_assault.remains>30
  if S.BloodFury:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 30) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "[CDs] blood_fury 284"; end
  end
  -- ancestral_call,if=cooldown.coordinated_assault.remains>30
  if S.AncestralCall:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 30) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "[CDs] ancestral_call 288"; end
  end
  -- fireblood,if=cooldown.coordinated_assault.remains>30
  if S.Fireblood:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 30) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "[CDs] fireblood 292"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "[CDs] lights_judgment 296"; end
  end
  -- bag_of_tricks,if=cooldown.kill_command.full_recharge_time>gcd
  -- berserking,if=cooldown.coordinated_assault.remains>60|time_to_die<13
  if S.Berserking:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 60 or Target:TimeToDie() < 13) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "[CDs] berserking 298"; end
  end
  -- Kill Command
  -- if S.KillCommand:IsCastable() and Target:IsInRange(40) then
  --   if HR.Cast(S.KillCommand) then return "[CDs] Kill Shot (2)"; end
  -- end
  -- potion,if=target.time_to_die<60|buff.coordinated_assault.up
  -- steel_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max
  -- freezing_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max
  -- tar_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max|focus+cast_regen<focus.max&runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd&(active_enemies>1|active_enemies=1&time_to_die>5*gcd)
  -- flare,if=focus+cast_regen<focus.max&tar_trap.up&runeforge.soulforge_embers.equipped&time_to_die>4*gcd
  -- kill_shot,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
  if S.KillShot:IsCastable() and (EnemyCount8y == 1 and Target:TimeToDie() < Player:Focus() / (S.KillShot:Cost() - Player:FocusCastRegen(S.KillShot:ExecuteTime())) * Player:GCD()) then
    if HR.Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "[CDs] KillShot CD"; end
  end
  -- mongoose_bite,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
  if S.MongooseBite:IsCastable() and (EnemyCount8y == 1 and Target:TimeToDie() < Player:Focus() / (S.MongooseBite:Cost() - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD()) then
    if HR.Cast(S.MongooseBite, nil, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "[CDs] MongooseBite CD"; end
  end
  -- raptor_strike,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
  if S.RaptorStrike:IsReady() and (EnemyCount8y == 1 and Target:TimeToDie() < Player:Focus() / (S.MongooseBite:Cost() - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD()) then
    if HR.Cast(S.RaptorStrike, nil, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "[CDs] RaptorStrike CD"; end
  end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and not Target:IsInRange(6) then
    if HR.Cast(S.AspectoftheEagle) then return "[CDs] AspectoftheEagle"; end
  end
end

local function bop()
  return "BOP"
end

local function apbop()
  return "APBOP"
end

local function apst()
  -- death_chakram,if=focus+cast_regen<focus.max
  -- serpent_sting,target_if=min:remains,if=!dot.serpent_sting.ticking&target.time_to_die>7
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, Enemy40y, "min", EvaluateSerpentStingCycleTargetIfCondition, EvaluateSerpentStingCycleCondition1) then return "[APST] SerpentSting 1"; end
    -- if EvaluateSerpentStingCycleCondition1(Target) then
    --     if HR.Cast(S.SerpentSting, nil, nil, not Target:IsInRange(40)) then return "[APST] SerpentSting 1@Target"; end
    -- end
  end
  -- flayed_shot
  -- resonating_arrow
  -- wild_spirits
  if CDsON() and S.WildSpirits:IsCastable() then
    if HR.Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "[APST] Wild Spirits"; end
  end
  -- coordinated_assault
  if CDsON() and S.CoordinatedAssault:IsCastable() then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "[APST] CoordinatedAssault"; end
  end
  -- kill_shot,if=target.health.pct<=20
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if HR.Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "[APST] Kill Shot"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  -- a_murder_of_crows
  if S.AMurderofCrows:IsCastable() then
    if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows, nil, not Target:IsSpellInRange(S.AMurderofCrows)) then return "[APST] AMurderofCrows"; end
  end
  -- wildfire_bomb,if=full_recharge_time<gcd|focus+cast_regen<focus.max&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)|time_to_die<10
  -- if S.WildfireBomb:IsAvailable() then
  --     if S.WildfireBomb:FullRechargeTime() < Player:GCD() or Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and (S.VolatileBomb:IsCastable() and Target:DebuffUp(S.SerpentStingDebuff) and Target:DebuffRefreshable(S.SerpentStingDebuff) or S.PheromoneBomb:IsCastable() and not Player:BuffUp(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime())*3) or Target:TimeToDie() < 10 then
  --         if HR.Cast(S.WildfireBomb, nil, nil, not Target:IsInRange(40)) then return "[APST] wildfire_bomb 64"; end
  --     end
  -- end

  if S.PheromoneBomb:IsReady() then
    -- HL.Print("Pheromone Bomb is ready")
    if S.PheromoneBomb:FullRechargeTime() < Player:GCD() or Player:Focus() + Player:FocusCastRegen(S.PheromoneBomb:ExecuteTime()) < Player:FocusMax() and (not Player:BuffUp(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.PheromoneBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime())*3) or Target:TimeToDie() < 10 then
      if HR.Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "[APST] PheromoneBomb 64"; end
    end
  end

  if S.VolatileBomb:IsReady() then
    -- HL.Print("Volatile Bomb is ready")
    if S.VolatileBomb:FullRechargeTime() < Player:GCD() or Player:Focus() + Player:FocusCastRegen(S.VolatileBomb:ExecuteTime()) < Player:FocusMax() and (Target:DebuffUp(S.SerpentStingDebuff) and Target:DebuffRefreshable(S.SerpentStingDebuff)) or Target:TimeToDie() < 10 then
      if HR.Cast(S.VolatileBomb, nil, nil, not Target:IsSpellInRange(S.VolatileBomb)) then return "[APST] VolatileBomb 64"; end
    end
  end

  -- if S.PheromoneBomb:IsCastable() and (not Player:BuffUp(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(45) or Target:TimeToDie() < 10) then
  --     if HR.Cast(S.PheromoneBomb, nil, nil, not Target:IsInRange(40)) then return "[APST] PheromoneBomb"; end
  -- end

  -- if S.VolatileBomb:IsCastable() and (Target:DebuffUp(S.SerpentStingDebuff) and Target:DebuffRefreshable(S.SerpentStingDebuff) or Target:TimeToDie() < 10) then
  --     if HR.Cast(S.VolatileBomb, nil, nil, not Target:IsInRange(40)) then return "[APST] PheromoneBomb"; end
  -- end

  -- wildfire_bomb,if=next_wi_bomb.shrapnel&focus>action.mongoose_bite.cost*2&dot.serpent_sting.remains>5*gcd ***
  if S.ShrapnelBomb:IsReady() then
    -- HL.Print("Shrapnel Bomb is ready")
    if (Player:Focus() > S.MongooseBite:Cost()*2 and Target:DebuffRemains(S.SerpentStingDebuff) > 5 * Player:GCD()) or (Player:Focus() + Player:FocusCastRegen(S.ShrapnelBomb:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.ShrapnelBomb, nil, nil, not Target:IsSpellInRange(S.ShrapnelBomb)) then return "[APST] WildfireBomb shrapnel burst"; end
    end
  end
  -- carve,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped
  if S.Carve:IsReady() and (EnemyCount8y > 1) then
    if HR.Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "[APST] carve 379"; end
  end
  -- butchery,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped&cooldown.wildfire_bomb.full_recharge_time>spell_targets&(charges_fractional>2.5|dot.shrapnel_bomb.ticking)
  -- steel_trap,if=focus+cast_regen<focus.max
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(action.mongoose_bite.cost-cast_regen)*gcd&!buff.wild_spirits.remains|buff.mongoose_fury.remains&next_wi_bomb.pheromone
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, Enemy8y, "max", EvaluateRaptorStrikeTargetIfCondition, EvaluateMangooseBiteCycleCondition1) then return "[APST] MongooseBite 1"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, Enemy50y, "min", EvaluateKillCommandCycleTargetIfCondition, EvaluateKillCommandCycleCondition1) then return "[APST] Kill Command 1"; end
    -- if EvaluateKillCommandCycleTargetIfCondition(Target) then
    --     if HR.Cast(S.KillCommand, nil, nil, not Player:GetEnemiesInRange(50)) then return "[APST] Kill Command 2"; end
    -- end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack,if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, Enemy8y, "max", EvaluateRaptorStrikeTargetIfCondition, EvaluateRaptorStrikeCycleCondition1) then return "[APST] RaptorStrike 1"; end
    -- if EvaluateRaptorStrikeTargetIfCondition(Target) then
    --     if HR.Cast(S.RaptorStrike, nil, nil, not Player:GetEnemiesInMeleeRange(8)) then return "[APST] RaptorStrike 2"; end
    -- end
  end
  -- mongoose_bite,if=dot.shrapnel_bomb.ticking
  if S.MongooseBite:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if HR.Cast(S.MongooseBite, nil, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "[APST] MongooseBite 2"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>7
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, Enemy40y, "min", EvaluateSerpentStingCycleTargetIfCondition, EvaluateSerpentStingCycleCondition2) then return "[APST] SerpentSting 2"; end
    -- if EvaluateSerpentStingCycleCondition2(Target) then
    --     if HR.Cast(S.SerpentSting, nil, nil, not Target:IsInRange(40)) then return "[APST] SerpentSting 1@Target"; end
    -- end
  end
  -- chakrams
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, Enemy50y, "min", EvaluateKillCommandCycleTargetIfCondition, EvaluateKillCommandCycleCondition2) then return "[APST] Kill Command 3"; end
    -- if EvaluateKillCommandCycleTargetIfCondition(Target) then
    --     if HR.Cast(S.KillCommand, nil, nil, not Player:GetEnemiesInRange(50)) then return "[APST] Kill Command 4"; end
    -- end
  end
  -- Kill_Command
  if S.KillCommand:IsCastable() and Player:Focus() < 45 then
    if HR.Cast(S.KillCommand, nil, nil, not Target:IsSpellInRange(S.KillCommand)) then return "[APST] Kill Command"; end
  end
  -- wildfire_bomb,if=runeforge.rylakstalkers_confounding_strikes.equipped
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max-15|dot.shrapnel_bomb.ticking|buff.wild_spirits.remains
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, Enemy8y, "max", EvaluateRaptorStrikeTargetIfCondition, EvaluateMangooseBiteCycleCondition2) then return "[APST] MongooseBite 3"; end
    if EvaluateRaptorStrikeTargetIfCondition(Target) then
      if HR.Cast(S.MongooseBite, nil, nil, not Target:IsSpellInRange(S.MongooseBite)) then return "[APST] MongooseBite 4"; end
    end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, Enemy8y, "max", EvaluateRaptorStrikeTargetIfCondition) then return "[APST] RaptorStrike 3"; end
    if EvaluateRaptorStrikeTargetIfCondition(Target) then
      if HR.Cast(S.RaptorStrike, nil, nil, not Target:IsSpellInRange(S.RaptorStrike)) then return "[APST] RaptorStrike 4"; end
    end
  end
  -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
  if S.WildfireBomb:IsCastable() then
    if (S.VolatileBomb.IsCastable() and Target:DebuffUp(S.SerpentStingDebuff)) or (S.PheromoneBomb.IsCastable() or S.ShrapnelBomb.IsCastable()) and Player:Focus() > 50 then
      if HR.Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "[APST] Wildfire Bomb"; end
    end
  end
end

local function st()
  return "ST"
end

local function cleave()
  -- serpent_sting,target_if=min:remains,if=talent.hydras_bite.enabled&buff.vipers_venom.remains&buff.vipers_venom.remains<gcd
  -- wild_spirits
  if CDsON() and S.WildSpirits:IsCastable() then
    if HR.Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "[Cleave] Wild Spirits"; end
  end
  -- resonating_arrow
  -- wildfire_bomb,if=full_recharge_time<gcd
  if S.WildfireBomb:IsReady() then
    if S.WildfireBomb:FullRechargeTime() < Player:GCD() then
      if HR.Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "[Cleave] Wildfire Bomb"; end
    end
  end
  -- chakrams
  -- butchery,if=dot.shrapnel_bomb.ticking&(dot.internal_bleeding.stack<2|dot.shrapnel_bomb.remains<gcd)
  -- carve,if=dot.shrapnel_bomb.ticking
  if S.Carve:IsReady() then
    if Target:DebuffUp(S.ShrapnelBombDebuff) then
      if HR.Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "[Cleave] Carve 1"; end
    end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  -- coordinated_assault
  if S.CoordinatedAssault:IsReady() then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault 6"; end
  end
  -- butchery,if=charges_fractional>2.5&cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  -- flanking_strike,if=focus+cast_regen<focus.max
  -- carve,if=cooldown.wildfire_bomb.full_recharge_time>spell_targets%2&talent.alpha_predator.enabled
  if S.Carve:IsReady() then
    if S.Carve:FullRechargeTime() > (EnemyCount8y / 2) and S.AlphaPredator:IsLearned() then
      if HR.Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "[Cleave] Carve 2"; end
    end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&full_recharge_time<gcd&(runeforge.nessingwarys_trapping_apparatus.equipped&cooldown.freezing_trap.remains&cooldown.tar_trap.remains|!runeforge.nessingwarys_trapping_apparatus.equipped)
  -- wildfire_bomb,if=!dot.wildfire_bomb.ticking
  -- butchery,if=(!next_wi_bomb.shrapnel|!talent.wildfire_infusion.enabled)&cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  -- carve,if=cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  if S.Carve:IsReady() then
    if S.WildfireBomb:FullRechargeTime() > (EnemyCount8y / 2) then
      if HR.Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "[Cleave] Carve 3"; end
    end
  end
  -- kill_shot
  if S.KillShot:IsCastable() then
    if HR.Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "[Cleave] Kill Shot"; end
  end
  -- flayed_shot
  -- a_murder_of_crows
  -- steel_trap
  -- serpent_sting,target_if=min:remains,if=refreshable&talent.hydras_bite.enabled&target.time_to_die>8
  -- carve
  if S.Carve:IsReady() then
    if HR.Cast(S.Carve, nil, nil, not Target:IsInRange(8)) then return "[Cleave] Carve 4"; end
  end
  -- kill_command,target_if=focus+cast_regen<focus.max&(runeforge.nessingwarys_trapping_apparatus.equipped&cooldown.freezing_trap.remains&cooldown.tar_trap.remains|!runeforge.nessingwarys_trapping_apparatus.equipped)
  -- serpent_sting,target_if=min:remains,if=refreshable
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, Enemy40y, "min", EvaluateSerpentStingCycleTargetIfCondition, EvaluateSerpentStingCycleCondition2) then return "[Cleave] SerpentSting 1"; end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison_injection.stack
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, Enemy8y, "max", EvaluateRaptorStrikeTargetIfCondition) then return "[Cleave] MongooseBite 1"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison_injection.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, Enemy8y, "max", EvaluateRaptorStrikeTargetIfCondition) then return "[Cleave] RaptorStrike 1"; end
  end
end

local function APL()
  -- Target Count Checking
  Enemy8y = Player:GetEnemiesInRange(8)
  Enemy40y = Player:GetEnemiesInRange(40)
  Enemy50y = Player:GetEnemiesInRange(50)
  if AoEON() then
    EnemyCount8y = #Enemy8y
    EnemyCount40y = #Enemy40y
  else
    EnemyCount8y = 1
    EnemyCount40y = 1
  end

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end

  -- Exhilaration
  if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons2.ExhilarationHP then
    if HR.Cast(S.Exhilaration, Settings.Commons2.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
  end
  if Everyone.TargetIsValid() then
    -- muzzle
    local ShouldReturn = Everyone.Interrupt(5, S.Muzzle, Settings.Survival.OffGCDasOffGCD.Muzzle, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- kill_shot,if=target.health.pct<=20
    if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
      if HR.Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "[APL] Kill Shot"; end
    end
    -- use_items
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=bop,if=active_enemies<3&!talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    if (EnemyCount8y < 3 and not S.AlphaPredator:IsAvailable() and not S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = bop(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apbop,if=active_enemies<3&talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    if (EnemyCount8y < 3 and S.AlphaPredator:IsAvailable() and not S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = apbop(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apst,if=active_enemies<3&talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    if (EnemyCount8y < 3 and S.AlphaPredator:IsAvailable() and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = apst(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3&!talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    if (EnemyCount8y < 3 and not S.AlphaPredator:IsAvailable() and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = st(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>2
    if (EnemyCount8y > 2) then
      local ShouldReturn = cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent 888"; end
    end
    if HR.Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

local function OnInit ()
  HL.Print("Survival is very WIP. The only currently supported build is Alpha Predator/Wildfire Infusion.")
end

HR.SetAPL(255, APL, OnInit)

--[[
  Priorities (actions.precombat):
    flask
    augmentation
    food
    summon_pet
    snapshot_stats
    tar_trap,if=runeforge.soulforge_embers
    steel_trap,precast_time=20

  Priorities (actions.default):
    auto_attack
    use_items
    call_action_list,name=cds
    call_action_list,name=bop,if=active_enemies<3&!talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    call_action_list,name=apbop,if=active_enemies<3&talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    call_action_list,name=apst,if=active_enemies<3&talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    call_action_list,name=st,if=active_enemies<3&!talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    call_action_list,name=cleave,if=active_enemies>2
    arcane_torrent
    
  Priorities (actions.cds):
    harpoon,if=talent.terms_of_engagement.enabled&focus<focus.max
    blood_fury,if=cooldown.coordinated_assault.remains>30
    ancestral_call,if=cooldown.coordinated_assault.remains>30
    fireblood,if=cooldown.coordinated_assault.remains>30
    lights_judgment
    bag_of_tricks,if=cooldown.kill_command.full_recharge_time>gcd
    berserking,if=cooldown.coordinated_assault.remains>60|time_to_die<13
    muzzle
    potion,if=target.time_to_die<60|buff.coordinated_assault.up
    steel_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max
    freezing_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max
    tar_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max|focus+cast_regen<focus.max&runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd&(active_enemies>1|active_enemies=1&time_to_die>5*gcd)
    flare,if=focus+cast_regen<focus.max&tar_trap.up&runeforge.soulforge_embers.equipped&time_to_die>4*gcd
    kill_shot,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    mongoose_bite,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    raptor_strike,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    aspect_of_the_eagle,if=target.distance>=6

  Priorities (actions.apst):
    death_chakram,if=focus+cast_regen<focus.max
    serpent_sting,target_if=min:remains,if=!dot.serpent_sting.ticking&target.time_to_die>7
    flayed_shot
    resonating_arrow
    wild_spirits
    coordinated_assault
    kill_shot
    flanking_strike,if=focus+cast_regen<focus.max
    a_murder_of_crows
    wildfire_bomb,if=full_recharge_time<gcd|focus+cast_regen<focus.max&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)|time_to_die<10
    carve,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped
    butchery,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped&cooldown.wildfire_bomb.full_recharge_time>spell_targets&(charges_fractional>2.5|dot.shrapnel_bomb.ticking)
    steel_trap,if=focus+cast_regen<focus.max
    mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(action.mongoose_bite.cost-cast_regen)*gcd&!buff.wild_spirits.remains|buff.mongoose_fury.remains&next_wi_bomb.pheromone
    kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max
    raptor_strike,target_if=max:debuff.latent_poison_injection.stack,if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
    mongoose_bite,if=dot.shrapnel_bomb.ticking
    serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>7
    wildfire_bomb,if=next_wi_bomb.shrapnel&focus>action.mongoose_bite.cost*2&dot.serpent_sting.remains>5*gcd
    chakrams
    kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
    wildfire_bomb,if=runeforge.rylakstalkers_confounding_strikes.equipped
    mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max-15|dot.shrapnel_bomb.ticking|buff.wild_spirits.remains
    raptor_strike,target_if=max:debuff.latent_poison_injection.stack
    wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
--]]

--[[ MONGOOSE BYTE RAIDSIM
Priorities (actions.precombat):
    flask
    augmentation
    food
    summon_pet
    snapshot_stats
    tar_trap,if=runeforge.soulforge_embers
    steel_trap,precast_time=20

    Priorities (actions.default):
    auto_attack
    use_items
    call_action_list,name=cds
    call_action_list,name=bop,if=active_enemies<3&!talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    call_action_list,name=apbop,if=active_enemies<3&talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    call_action_list,name=apst,if=active_enemies<3&talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    call_action_list,name=st,if=active_enemies<3&!talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    call_action_list,name=cleave,if=active_enemies>2
    arcane_torrent

Priorities (actions.cds):
    harpoon,if=talent.terms_of_engagement.enabled&focus<focus.max
    blood_fury,if=cooldown.coordinated_assault.remains>30
    ancestral_call,if=cooldown.coordinated_assault.remains>30
    fireblood,if=cooldown.coordinated_assault.remains>30
    lights_judgment
    bag_of_tricks,if=cooldown.kill_command.full_recharge_time>gcd
    berserking,if=cooldown.coordinated_assault.remains>60|time_to_die<13
    muzzle
    potion,if=target.time_to_die<60|buff.coordinated_assault.up
    steel_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max
    freezing_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max
    tar_trap,if=runeforge.nessingwarys_trapping_apparatus.equipped&focus+cast_regen<focus.max|focus+cast_regen<focus.max&runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd&(active_enemies>1|active_enemies=1&time_to_die>5*gcd)
    flare,if=focus+cast_regen<focus.max&tar_trap.up&runeforge.soulforge_embers.equipped&time_to_die>4*gcd
    kill_shot,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    mongoose_bite,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    raptor_strike,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    aspect_of_the_eagle,if=target.distance>=6

Priorities (actions.apst):
    death_chakram,if=focus+cast_regen<focus.max
    serpent_sting,target_if=min:remains,if=!dot.serpent_sting.ticking&target.time_to_die>7
    flayed_shot
    resonating_arrow
    wild_spirits
    coordinated_assault
    kill_shot
    flanking_strike,if=focus+cast_regen<focus.max
    a_murder_of_crows
    wildfire_bomb,if=full_recharge_time<gcd|focus+cast_regen<focus.max&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)|time_to_die<10
    carve,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped
    butchery,if=active_enemies>1&!runeforge.rylakstalkers_confounding_strikes.equipped&cooldown.wildfire_bomb.full_recharge_time>spell_targets&(charges_fractional>2.5|dot.shrapnel_bomb.ticking)
    steel_trap,if=focus+cast_regen<focus.max
    mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(action.mongoose_bite.cost-cast_regen)*gcd&!buff.wild_spirits.remains|buff.mongoose_fury.remains&next_wi_bomb.pheromone
    kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max
    raptor_strike,target_if=max:debuff.latent_poison_injection.stack,if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
    mongoose_bite,if=dot.shrapnel_bomb.ticking
    serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>7
    wildfire_bomb,if=next_wi_bomb.shrapnel&focus>action.mongoose_bite.cost*2&dot.serpent_sting.remains>5*gcd
    chakrams
    kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
    wildfire_bomb,if=runeforge.rylakstalkers_confounding_strikes.equipped
    mongoose_bite,target_if=max:debuff.latent_poison_injection.stack,if=buff.mongoose_fury.up|focus+action.kill_command.cast_regen>focus.max-15|dot.shrapnel_bomb.ticking|buff.wild_spirits.remains
    raptor_strike,target_if=max:debuff.latent_poison_injection.stack
    wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
--]]
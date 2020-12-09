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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999
-- Define S/I for spell and item arrays
local S = Spell.Hunter.Survival;
local I = Item.Hunter.Survival;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.GalecallersBoon:ID(),
  -- I.AshvanesRazorCoral:ID(),
  -- I.AzsharasFontofPower:ID(),
  -- I.DribblingInkpod:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  Survival = HR.GUISettings.APL.Hunter.Survival
};

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
};

-- Variables
local VarCarveCdr = 0;

HL:RegisterForEvent(function()
  VarCarveCdr = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {8, 15, 50}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    Player:GetEnemiesInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateTargetIfFilterMongooseBite396(TargetUnit)
  return TargetUnit:DebuffStack(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfMongooseBite405(TargetUnit)
  return TargetUnit:DebuffStack(S.LatentPoisonDebuff) > 8
end

local function EvaluateTargetIfFilterKillCommand413(TargetUnit)
  return TargetUnit:DebuffRemains(S.BloodseekerDebuff)
end

local function EvaluateTargetIfKillCommand426(TargetUnit)
  return Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax()
end

local function EvaluateTargetIfFilterSerpentSting462(TargetUnit)
  return TargetUnit:DebuffRemains(S.SerpentStingDebuff)
end

local function EvaluateTargetIfSerpentSting479(TargetUnit)
  return bool(Player:BuffStack(S.VipersVenomBuff))
end

local function EvaluateTargetIfFilterSerpentSting497(TargetUnit)
  return TargetUnit:DebuffRemains(S.SerpentStingDebuff)
end

local function EvaluateTargetIfSerpentSting520(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and Player:BuffStack(S.TipoftheSpearBuff) < 3 or S.VolatileBomb:IsLearned() or Target:DebuffRefreshable(S.SerpentStingDebuff) and S.LatentPoison:AzeriteEnabled())
end

local function EvaluateTargetIfFilterMongooseBite526(TargetUnit)
  return TargetUnit:DebuffStack(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfFilterRaptorStrike537(TargetUnit)
  return TargetUnit:DebuffStack(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfKillCommand543(TargetUnit)
  return (S.KillCommand:FullRechargeTime() < 1.5 * Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax())
end

local function EvaluateTargetIfKillCommand545(TargetUnit)
  return (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (Player:BuffStack(S.MongooseFuryBuff) < 5 or Player:Focus() < S.MongooseBite:Cost()))
end

local function EvaluateTargetIfKillCommand547(TargetUnit)
  return (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) + 15 < Player:FocusMax())
end

local function EvaluateTargetIfKillCommand549(TargetUnit)
  return (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() - Player:FocusRegen())
end

local function EvaluateTargetIfKillCommand551(TargetUnit)
  return (S.KillCommand:FullRechargeTime() < 1.5 * Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() - 20)
end

local function EvaluateTargetIfKillCommand553(TargetUnit)
  return (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (Player:BuffStack(S.MongooseFuryBuff) < 5 or Player:Focus() < S.MongooseBite:Cost()))
end

local function EvaluateTargetIfFilterMongooseBite555(TargetUnit)
  return TargetUnit:TimeToDie()
end

local function EvaluateTargetIfMongooseBite557(TargetUnit)
  return (TargetUnit:DebuffStack(S.LatentPoisonDebuff) > (#Enemies8y or 9) and TargetUnit:TimeToDie() < #Enemies8y * Player:GCD())
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- if S.SummonPet:IsCastable() then
  --   if HR.Cast(S.SummonPet, Settings.Survival.GCDasOffGCD.SummonPet) then return "summon_pet 3"; end
  -- end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastable() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, 100) then return "coordinated_assault 6"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastable() and Player:DebuffDown(S.SteelTrapDebuff) then
      if HR.Cast(S.SteelTrap, nil, nil, 40) then return "steel_trap 10"; end
    end
    -- harpoon
    if S.Harpoon:IsCastable() then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, 30) then return "harpoon 12"; end
    end
  end
end

local function Apst()
  -- mongoose_bite,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.CoordinatedAssaultBuff) and (Player:BuffRemains(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 14"; end
  end
  -- raptor_strike,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
  if S.RaptorStrike:IsReady() and (Player:BuffUp(S.CoordinatedAssaultBuff) and (Player:BuffRemains(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 24"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.FlankingStrike, nil, nil, 15) then return "flanking_strike 34"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<1.5*gcd&focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand543) then return "kill_command 42"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.SteelTrap, nil, nil, 40) then return "steel_trap 54"; end
  end
  -- wildfire_bomb,if=focus+cast_regen<focus.max&!ticking&!buff.memory_of_lucid_dreams.up&(full_recharge_time<1.5*gcd|!dot.wildfire_bomb.ticking&!buff.coordinated_assault.up|!dot.wildfire_bomb.ticking&buff.mongoose_fury.stack<1)|time_to_die<18&!dot.wildfire_bomb.ticking
  if S.WildfireBomb:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and Target:DebuffDown(S.WildfireBombDebuff) and Player:BuffDown(S.MemoryofLucidDreams) and (S.WildfireBomb:FullRechargeTime() < 1.5 * Player:GCD() or Target:DebuffDown(S.WildfireBombDebuff) and Player:BuffDown(S.CoordinatedAssaultBuff) or Target:DebuffDown(S.WildfireBombDebuff) and Player:BuffStack(S.MongooseFuryBuff) < 1) or Target:TimeToDie() < 18 and Target:DebuffDown(S.WildfireBombDebuff)) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 64"; end
  end
  -- serpent_sting,if=!dot.serpent_sting.ticking&!buff.coordinated_assault.up
  if S.SerpentSting:IsReady() and (Target:DebuffDown(S.SerpentStingDebuff) and Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 90"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&(buff.mongoose_fury.stack<5|focus<action.mongoose_bite.cost)
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand545) then return "kill_command 96"; end
  end
  -- serpent_sting,if=refreshable&!buff.coordinated_assault.up&buff.mongoose_fury.stack<5
  if S.SerpentSting:IsReady() and (Target:DebuffRefreshable(S.SerpentStingDebuff) and Player:BuffDown(S.CoordinatedAssaultBuff) and Player:BuffStack(S.MongooseFuryBuff) < 5) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 110"; end
  end
  -- a_murder_of_crows,if=!buff.coordinated_assault.up
  if S.AMurderofCrows:IsCastable() and (Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows, nil, 40) then return "a_murder_of_crows 122"; end
  end
  -- coordinated_assault,if=!buff.coordinated_assault.up
  if S.CoordinatedAssault:IsCastable() and HR.CDsON() and (Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, 100) then return "coordinated_assault 126"; end
  end
  -- mongoose_bite,if=buff.mongoose_fury.up|focus+cast_regen>focus.max-10|buff.coordinated_assault.up
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 10 or Player:BuffUp(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 128"; end
  end
  -- raptor_strike
  if S.RaptorStrike:IsReady() then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 140"; end
  end
  -- wildfire_bomb,if=!ticking
  if S.WildfireBomb:IsCastable() and (Target:DebuffDown(S.WildfireBombDebuff)) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 142"; end
  end
end

local function Apwfi()
  -- mongoose_bite,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < Player:GCD()) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 150"; end
  end
  -- raptor_strike,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
  if S.RaptorStrike:IsReady() and (Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < Player:GCD()) then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 156"; end
  end
  -- serpent_sting,if=!dot.serpent_sting.ticking
  if S.SerpentSting:IsReady() and (Target:DebuffDown(S.SerpentStingDebuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 162"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsCastable() then
    if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows, nil, 40) then return "a_murder_of_crows 166"; end
  end
  -- wildfire_bomb,if=full_recharge_time<1.5*gcd|focus+cast_regen<focus.max&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
  if S.WildfireBomb:IsCastable() and (S.WildfireBomb:FullRechargeTime() < 1.5 * Player:GCD() or Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and (S.VolatileBomb:IsLearned() and Target:DebuffUp(S.SerpentStingDebuff) and Target:DebuffRefreshable(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() and Player:BuffDown(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3)) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 168"; end
  end
  -- coordinated_assault
  if S.CoordinatedAssault:IsCastable() and HR.CDsON() then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, 100) then return "coordinated_assault 204"; end
  end
  -- mongoose_bite,if=buff.mongoose_fury.remains&next_wi_bomb.pheromone
  if S.MongooseBite:IsReady() and (bool(Player:BuffRemains(S.MongooseFuryBuff)) and S.PheromoneBomb:IsLearned()) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 206"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<1.5*gcd&focus+cast_regen<focus.max-20
  -- if S.KillCommand:IsCastable() then
  --   -- function Commons.CastTargetIf(Object, Enemies, TargetIfMode, TargetIfCondition, Condition, OutofRange)
  --   if Everyone.CastTargetIf(S.KillCommand, Player:GetEnemiesInRange(15), "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand551, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command 210"; end
  -- end
  
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, Enemies8y, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand551) then return "Kill Command"; end
    if EvaluateTargetIfFilterKillCommand413(Target) then
      if HR.Cast(S.KillCommand, nil, nil, not Enemies8y) then return "Kill Command"; end
    end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.SteelTrap, nil, nil, 40) then return "steel_trap 222"; end
  end
  -- raptor_strike,if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
  if S.RaptorStrike:IsReady() and (Player:BuffStack(S.TipoftheSpearBuff) == 3 or Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 232"; end
  end
  -- mongoose_bite,if=dot.shrapnel_bomb.ticking
  if S.MongooseBite:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 238"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.shrapnel&focus>30&dot.serpent_sting.remains>5*gcd
  if S.WildfireBomb:IsCastable() and (S.ShrapnelBomb:IsLearned() and Player:Focus() > 30 and Target:DebuffRemains(S.SerpentStingDebuff) > 5 * Player:GCD()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 242"; end
  end
  -- chakrams,if=!buff.mongoose_fury.remains
  if S.Chakrams:IsCastable() and (Player:BuffDown(S.MongooseFuryBuff)) then
    if HR.Cast(S.Chakrams, nil, nil, 40) then return "chakrams 246"; end
  end
  -- serpent_sting,if=refreshable
  if S.SerpentSting:IsReady() and (Target:DebuffRefreshable(S.SerpentStingDebuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 250"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&(buff.mongoose_fury.stack<5|focus<action.mongoose_bite.cost)
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand553) then return "kill_command 258"; end
  end
  -- raptor_strike
  if S.RaptorStrike:IsReady() then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 272"; end
  end
  -- mongoose_bite,if=buff.mongoose_fury.up|focus>40|dot.shrapnel_bomb.ticking
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.MongooseFuryBuff) or Player:Focus() > 40 or Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 274"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
  if S.WildfireBomb:IsCastable() and (S.VolatileBomb:IsLearned() and Target:DebuffUp(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() or S.ShrapnelBomb:IsLearned() and Player:Focus() > 50) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 280"; end
  end
end

local function Cds()
  -- blood_fury,if=cooldown.coordinated_assault.remains>30
  if S.BloodFury:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 30) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 284"; end
  end
  -- ancestral_call,if=cooldown.coordinated_assault.remains>30
  if S.AncestralCall:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 30) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 288"; end
  end
  -- fireblood,if=cooldown.coordinated_assault.remains>30
  if S.Fireblood:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 30) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 292"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 296"; end
  end
  -- berserking,if=cooldown.coordinated_assault.remains>60|time_to_die<13
  if S.Berserking:IsCastable() and (S.CoordinatedAssault:CooldownRemains() > 60 or Target:TimeToDie() < 13) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 298"; end
  end
  -- potion,if=buff.guardian_of_azeroth.up&(buff.berserking.up|buff.blood_fury.up|!race.troll)|(consumable.potion_of_unbridled_fury&target.time_to_die<61|target.time_to_die<26)|!essence.condensed_lifeforce.major&buff.coordinated_assault.up
  -- if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.GuardianofAzerothBuff) and (Player:BuffUp(S.BerserkingBuff) or Player:BuffUp(S.BloodFuryBuff) or not Player:IsRace("Troll")) or Target:TimeToDie() < 61 or not Spell:MajorEssenceEnabled(AE.CondensedLifeForce) and Player:BuffUp(S.CoordinatedAssaultBuff)) then
  --   if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_agility 308"; end
  -- end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and (not Target:IsInRange(8) and Target:IsInRange(40)) then
    if HR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return "aspect_of_the_eagle 320"; end
  end
  -- use_item,name=ashvanes_razor_coral,if=buff.memory_of_lucid_dreams.up&target.time_to_die<cooldown.memory_of_lucid_dreams.remains+15|buff.guardian_of_azeroth.stack=5&target.time_to_die<cooldown.guardian_of_azeroth.remains+20|debuff.razor_coral_debuff.down|target.time_to_die<21|buff.worldvein_resonance.remains&target.time_to_die<cooldown.worldvein_resonance.remains+18|!talent.birds_of_prey.enabled&target.time_to_die<cooldown.coordinated_assault.remains+20&buff.coordinated_assault.remains
  -- if not S.BirdsofPrey:IsAvailable() and Target:TimeToDie() < S.CoordinatedAssault:CooldownRemains() + 20 and Player:BuffUp(S.CoordinatedAssaultBuff)) then
  --   if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 321"; end
  -- end
  -- use_item,name=galecallers_boon,if=cooldown.memory_of_lucid_dreams.remains|talent.wildfire_infusion.enabled&cooldown.coordinated_assault.remains|!essence.memory_of_lucid_dreams.major&cooldown.coordinated_assault.remains
  -- if I.GalecallersBoon:IsEquipReady() and Settings.Commons.UseTrinkets and (bool(S.MemoryofLucidDreams:CooldownRemains()) or S.WildfireInfusion:IsAvailable() and bool(S.CoordinatedAssault:CooldownRemains()) or not Spell:MajorEssenceEnabled(AE.MemoryofLucidDreams) and bool(S.CoordinatedAssault:CooldownRemains())) then
  --   if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "galecallers_boon 322"; end
  -- end
  -- use_item,name=azsharas_font_of_power
  -- if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
  --   if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 323"; end
  -- end
  -- focused_azerite_beam,if=raid_event.adds.in>90&focus<focus.max-25|(active_enemies>1&!talent.birds_of_prey.enabled|active_enemies>2)&(buff.blur_of_talons.up&buff.blur_of_talons.remains>3*gcd|!buff.blur_of_talons.up)
  -- if S.FocusedAzeriteBeam:IsCastable() and (Player:Focus() < Player:FocusMax() - 25 or (#Enemies8y > 1 and not S.BirdsofPrey:IsAvailable() or #Enemies8y > 2) and (Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) > 3 * Player:GCD() or Player:BuffDown(S.BlurofTalonsBuff))) then
  --   if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 324"; end
  -- end
  -- blood_of_the_enemy,if=((raid_event.adds.remains>90|!raid_event.adds.exists)|(active_enemies>1&!talent.birds_of_prey.enabled|active_enemies>2))&focus<focus.max
  -- if S.BloodoftheEnemy:IsCastable() and (((#Enemies8y == 1) or (#Enemies8y > 1 and not S.BirdsofPrey:IsAvailable() or #Enemies8y > 2)) and Player:Focus() < Player:FocusMax()) then
  --   if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy 328"; end
  -- end
  -- purifying_blast,if=((raid_event.adds.remains>60|!raid_event.adds.exists)|(active_enemies>1&!talent.birds_of_prey.enabled|active_enemies>2))&focus<focus.max
  -- if S.PurifyingBlast:IsCastable() and (((#Enemies8y == 1) or (#Enemies8y > 1 and not S.BirdsofPrey:IsAvailable() or #Enemies8y > 2)) and Player:Focus() < Player:FocusMax()) then
  --   if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast 332"; end
  -- end
  -- guardian_of_azeroth
  -- if S.GuardianofAzeroth:IsCastable() then
  --   if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 334"; end
  -- end
  -- ripple_in_space
  -- if S.RippleInSpace:IsCastable() then
  --   if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 336"; end
  -- end
  -- concentrated_flame,if=full_recharge_time<1*gcd
  -- if S.ConcentratedFlame:IsCastable() and (S.ConcentratedFlame:FullRechargeTime() < 1 * Player:GCD()) then
  --   if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 338"; end
  -- end
  -- the_unbound_force,if=buff.reckless_force.up
  -- if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff)) then
  --   if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force 344"; end
  -- end
  -- worldvein_resonance
  -- if S.WorldveinResonance:IsCastable() then
  --   if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 348"; end
  -- end
  -- reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30
  -- if (Target:HealthPercentage() > 80 or Target:HealthPercentage() <= 20 or Target:TimeToX(20) > 30) then
  --   local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  -- end
  -- serpent_sting,if=essence.memory_of_lucid_dreams.major&refreshable&buff.vipers_venom.up&!cooldown.memory_of_lucid_dreams.remains
  if S.SerpentSting:IsReady() and Target:DebuffRefreshable(S.SerpentStingDebuff) and Player:BuffUp(S.VipersVenomBuff) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 352"; end
  end
  -- mongoose_bite,if=essence.memory_of_lucid_dreams.major&!cooldown.memory_of_lucid_dreams.remains
  if S.MongooseBite:IsReady() then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 354"; end
  end
  -- wildfire_bomb,if=essence.memory_of_lucid_dreams.major&full_recharge_time<1.5*gcd&focus<action.mongoose_bite.cost&!cooldown.memory_of_lucid_dreams.remains
  if S.WildfireBomb:IsCastable() and (S.WildfireBomb:FullRechargeTime() < 1.5 * Player:GCD() and Player:Focus() < S.MongooseBite:Cost()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 356"; end
  end
  -- memory_of_lucid_dreams,if=focus<action.mongoose_bite.cost&buff.coordinated_assault.up
  -- if (Player:Focus() < S.MongooseBite:Cost() and Player:BuffUp(S.CoordinatedAssaultBuff)) then
  --   if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 358"; end
  -- end
end

local function Cleave()
  -- variable,name=carve_cdr,op=setif,value=active_enemies,value_else=5,condition=active_enemies<5
  VarCarveCdr = math.min(#Enemies8y, 5)
  -- mongoose_bite,if=azerite.blur_of_talons.rank>0&(buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd|buff.coordinated_assault.remains&!buff.blur_of_talons.remains))
  if S.MongooseBite:IsReady() and (S.BlurofTalons:AzeriteEnabled() and (Player:BuffUp(S.CoordinatedAssaultBuff) and (Player:BuffRemains(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < 1.5 * Player:GCD() or Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffDown(S.BlurofTalonsBuff)))) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 371"; end
  end
  -- mongoose_bite,target_if=min:time_to_die,if=debuff.latent_poison.stack>(active_enemies|9)&target.time_to_die<active_enemies*gcd
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, 15, "min", EvaluateTargetIfFilterMongooseBite555, EvaluateTargetIfMongooseBite557) then return "mongoose_bite 373"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsCastable() then
    if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows, nil, 40) then return "a_murder_of_crows 375"; end
  end
  -- coordinated_assault
  if S.CoordinatedAssault:IsCastable() and HR.CDsON() then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, 100) then return "coordinated_assault 377"; end
  end
  -- carve,if=dot.shrapnel_bomb.ticking&!talent.hydras_bite.enabled|dot.shrapnel_bomb.ticking&active_enemies>5
  if S.Carve:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff) and not S.HydrasBite:IsAvailable() or Target:DebuffUp(S.ShrapnelBombDebuff) and #Enemies8y > 5) then
    if HR.Cast(S.Carve, nil, nil, 8) then return "carve 379"; end
  end
  -- wildfire_bomb,if=!talent.guerrilla_tactics.enabled|full_recharge_time<gcd|raid_event.adds.remains<6&raid_event.adds.exists
  if S.WildfireBomb:IsCastable() and (not S.GuerrillaTactics:IsAvailable() or S.WildfireBomb:FullRechargeTime() < Player:GCD()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 383"; end
  end
  -- butchery,if=charges_fractional>2.5|dot.shrapnel_bomb.ticking|cooldown.wildfire_bomb.remains>active_enemies-gcd|debuff.blood_of_the_enemy.remains|raid_event.adds.remains<5&raid_event.adds.exists
  if S.Butchery:IsReady() and (S.Butchery:ChargesFractional() > 2.5 or Target:DebuffUp(S.ShrapnelBombDebuff) or S.WildfireBomb:CooldownRemains() > #Enemies8y - Player:GCD() or Target:DebuffUp(S.BloodoftheEnemy)) then
    if HR.Cast(S.Butchery, nil, nil, 8) then return "butchery 385"; end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison.stack,if=debuff.latent_poison.stack>8
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, 8, "max", EvaluateTargetIfFilterMongooseBite396, EvaluateTargetIfMongooseBite405) then return "mongoose_bite 407" end
  end
  -- chakrams
  if S.Chakrams:IsCastable() then
    if HR.Cast(S.Chakrams, nil, nil, 40) then return "chakrams 408"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand551, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command 210"; end
    -- if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand426) then return "kill_command 428" end
  end
  -- harpoon,if=talent.terms_of_engagement.enabled
  if S.Harpoon:IsCastable() and (S.TermsofEngagement:IsAvailable()) then
    if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, 30) then return "harpoon 430"; end
  end
  -- carve,if=talent.guerrilla_tactics.enabled
  if S.Carve:IsReady() and (S.GuerrillaTactics:IsAvailable()) then
    if HR.Cast(S.Carve, nil, nil, 8) then return "carve 441"; end
  end
  -- butchery,if=cooldown.wildfire_bomb.remains>(active_enemies|5)
  if S.Butchery:IsReady() and (S.WildfireBomb:CooldownRemains() > (#Enemies8y or 5)) then
    if HR.Cast(S.Butchery, nil, nil, 8) then return "butchery 443"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.FlankingStrike, nil, nil, 15) then return "flanking_strike 445"; end
  end
  -- wildfire_bomb,if=dot.wildfire_bomb.refreshable|talent.wildfire_infusion.enabled
  if S.WildfireBomb:IsCastable() and (Target:DebuffRefreshable(S.WildfireBombDebuff) or S.WildfireInfusion:IsAvailable()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 453"; end
  end
  -- serpent_sting,target_if=min:remains,if=buff.vipers_venom.react
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, 8, "min", EvaluateTargetIfFilterSerpentSting462, EvaluateTargetIfSerpentSting479) then return "serpent_sting 481" end
  end
  -- carve,if=cooldown.wildfire_bomb.remains>variable.carve_cdr%2
  if S.Carve:IsReady() and (S.WildfireBomb:CooldownRemains() > VarCarveCdr / 2) then
    if HR.Cast(S.Carve, nil, nil, 8) then return "carve 482"; end
  end
  -- steel_trap
  if S.SteelTrap:IsCastable() then
    if HR.Cast(S.SteelTrap, nil, nil, 40) then return "steel_trap 488"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&buff.tip_of_the_spear.stack<3&next_wi_bomb.volatile|refreshable&azerite.latent_poison.rank>0
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, 8, "min", EvaluateTargetIfFilterSerpentSting497, EvaluateTargetIfSerpentSting520) then return "serpent_sting 522" end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison.stack
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, 8, "max", EvaluateTargetIfFilterMongooseBite526) then return "mongoose_bite 533" end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, 8, "max", EvaluateTargetIfFilterRaptorStrike537) then return "raptor_strike 544" end
  end
end

local function St()
  -- harpoon,if=talent.terms_of_engagement.enabled
  if S.Harpoon:IsCastable() and (S.TermsofEngagement:IsAvailable()) then
    if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, 30) then return "harpoon 545"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.FlankingStrike, nil, nil, 15) then return "flanking_strike 549"; end
  end
  -- raptor_strike,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
  if S.RaptorStrike:IsReady() and (Player:BuffUp(S.CoordinatedAssaultBuff) and (Player:BuffRemains(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 557"; end
  end
  -- mongoose_bite,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.CoordinatedAssaultBuff) and (Player:BuffRemains(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 567"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand547) then return "kill_command 568"; end
  end
  -- serpent_sting,if=buff.vipers_venom.up&buff.vipers_venom.remains<1*gcd
  if S.SerpentSting:IsCastable() and (Player:BuffUp(S.VipersVenomBuff) and Player:BuffRemains(S.VipersVenomBuff) < 1 * Player:GCD()) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 570"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.SteelTrap, nil, nil, 40) then return "steel_trap 577"; end
  end
  -- wildfire_bomb,if=focus+cast_regen<focus.max&refreshable&full_recharge_time<gcd&!buff.memory_of_lucid_dreams.up|focus+cast_regen<focus.max&(!dot.wildfire_bomb.ticking&(!buff.coordinated_assault.up|buff.mongoose_fury.stack<1|time_to_die<18|!dot.wildfire_bomb.ticking&azerite.wilderness_survival.rank>0))&!buff.memory_of_lucid_dreams.up
  if S.WildfireBomb:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and Target:DebuffRefreshable(S.WildfireBombDebuff) and S.WildfireBomb:FullRechargeTime() < Player:GCD() and Player:BuffDown(S.MemoryofLucidDreams) or Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and (Target:DebuffDown(S.WildfireBombDebuff) and (Player:BuffDown(S.CoordinatedAssaultBuff) or Player:BuffStack(S.MongooseFuryBuff) < 1 or Target:TimeToDie() < 18 or Target:DebuffDown(S.WildfireBombDebuff) and S.WildernessSurvival:AzeriteEnabled())) and Player:BuffDown(S.MemoryofLucidDreams)) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 587"; end
  end
  -- serpent_sting,if=buff.vipers_venom.up&dot.serpent_sting.remains<4*gcd|dot.serpent_sting.refreshable&!buff.coordinated_assault.up
  if S.SerpentSting:IsReady() and (Player:BuffUp(S.VipersVenomBuff) and Target:DebuffRemains(S.SerpentStingDebuff) < 4 * Player:GCD() or Target:DebuffRefreshable(S.SerpentStingDebuff) and Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 619"; end
  end
  -- a_murder_of_crows,if=!buff.coordinated_assault.up
  if S.AMurderofCrows:IsCastable() and (Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows, nil, 40) then return "a_murder_of_crows 629"; end
  end
  -- coordinated_assault,if=!buff.coordinated_assault.up
  if S.CoordinatedAssault:IsCastable() and HR.CDsON() and (Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, 100) then return "coordinated_assault 633"; end
  end
  -- mongoose_bite,if=buff.mongoose_fury.up|focus+cast_regen>focus.max-20&talent.vipers_venom.enabled|focus+cast_regen>focus.max-1&talent.terms_of_engagement.enabled|buff.coordinated_assault.up
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 20 and S.VipersVenom:IsAvailable() or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 1 and S.TermsofEngagement:IsAvailable() or Player:BuffUp(S.CoordinatedAssaultBuff)) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 635"; end
  end
  -- raptor_strike
  if S.RaptorStrike:IsReady() then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 657"; end
  end
  -- wildfire_bomb,if=dot.wildfire_bomb.refreshable
  if S.WildfireBomb:IsCastable() and (Target:DebuffRefreshable(S.WildfireBombDebuff)) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 659"; end
  end
  -- serpent_sting,if=buff.vipers_venom.up
  if S.SerpentSting:IsReady() and (Player:BuffUp(S.VipersVenomBuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 663"; end
  end
  
  -- kill_shot,if=buff.flayers_mark.remains<5|target.health.pct<=20
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "Kill Shot (ST)"; end
  end
end

local function Wfi()
  -- harpoon,if=focus+cast_regen<focus.max&talent.terms_of_engagement.enabled
  if S.Harpoon:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.Harpoon:ExecuteTime()) < Player:FocusMax() and S.TermsofEngagement:IsAvailable()) then
    if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, 30) then return "harpoon 667"; end
  end
  -- mongoose_bite,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < Player:GCD()) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 677"; end
  end
  -- raptor_strike,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
  if S.RaptorStrike:IsReady() and (Player:BuffUp(S.BlurofTalonsBuff) and Player:BuffRemains(S.BlurofTalonsBuff) < Player:GCD()) then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 683"; end
  end
  -- serpent_sting,if=buff.vipers_venom.up&buff.vipers_venom.remains<1.5*gcd|!dot.serpent_sting.ticking
  if S.SerpentSting:IsReady() and (Player:BuffUp(S.VipersVenomBuff) and Player:BuffRemains(S.VipersVenomBuff) < 1.5 * Player:GCD() or Target:DebuffDown(S.SerpentStingDebuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 689"; end
  end
  -- wildfire_bomb,if=full_recharge_time<1.5*gcd&focus+cast_regen<focus.max|(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
  if S.WildfireBomb:IsCastable() and (S.WildfireBomb:FullRechargeTime() < 1.5 * Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() or (S.VolatileBomb:IsLearned() and Target:DebuffUp(S.SerpentStingDebuff) and Target:DebuffRefreshable(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() and Player:BuffDown(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3)) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 697"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max-focus.regen
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, 15, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand549) then return "kill_command 733"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsCastable() then
    if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows, nil, 40) then return "a_murder_of_crows 741"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.SteelTrap, nil, nil, 40) then return "steel_trap 743"; end
  end
  -- wildfire_bomb,if=full_recharge_time<1.5*gcd
  if S.WildfireBomb:IsCastable() and (S.WildfireBomb:FullRechargeTime() < 1.5 * Player:GCD()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 753"; end
  end
  -- coordinated_assault
  if S.CoordinatedAssault:IsCastable() and HR.CDsON() then
    if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, 100) then return "coordinated_assault 761"; end
  end
  -- serpent_sting,if=buff.vipers_venom.up&dot.serpent_sting.remains<4*gcd
  if S.SerpentSting:IsReady() and (Player:BuffUp(S.VipersVenomBuff) and Target:DebuffRemains(S.SerpentStingDebuff) < 4 * Player:GCD()) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 763"; end
  end
  -- mongoose_bite,if=dot.shrapnel_bomb.ticking|buff.mongoose_fury.stack=5
  if S.MongooseBite:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff) or Player:BuffStack(S.MongooseFuryBuff) == 5) then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 769"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.shrapnel&dot.serpent_sting.remains>5*gcd
  if S.WildfireBomb:IsCastable() and (S.ShrapnelBomb:IsLearned() and Target:DebuffRemains(S.SerpentStingDebuff) > 5 * Player:GCD()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 775"; end
  end
  -- serpent_sting,if=refreshable
  if S.SerpentSting:IsReady() and (Target:DebuffRefreshable(S.SerpentStingDebuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 779"; end
  end
  -- chakrams,if=!buff.mongoose_fury.remains
  if S.Chakrams:IsCastable() and (Player:BuffDown(S.MongooseFuryBuff)) then
    if HR.Cast(S.Chakrams, nil, nil, 40) then return "chakrams 787"; end
  end
  -- mongoose_bite
  if S.MongooseBite:IsReady() then
    if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 791"; end
  end
  -- raptor_strike
  if S.RaptorStrike:IsReady() then
    if HR.Cast(S.RaptorStrike, nil, nil, "Melee") then return "raptor_strike 793"; end
  end
  -- serpent_sting,if=buff.vipers_venom.up
  if S.SerpentSting:IsReady() and (Player:BuffUp(S.VipersVenomBuff)) then
    if HR.Cast(S.SerpentSting, nil, nil, 40) then return "serpent_sting 795"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel
  if S.WildfireBomb:IsCastable() and (S.VolatileBomb:IsLearned() and Target:DebuffUp(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() or S.ShrapnelBomb:IsLearned()) then
    if HR.Cast(S.WildfireBomb, nil, nil, 40) then return "wildfire_bomb 799"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- UpdateRanges()
  -- Everyone.AoEToggleEnemiesUpdate()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = #Enemies8y -- AOE Toogle

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Self heal, if below setting value
    -- if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
    --   if HR.Cast(S.Exhilaration, Settings.Commons.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    -- end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Muzzle, Settings.Survival.OffGCDasOffGCD.Muzzle, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- use_items
    -- local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
    -- if TrinketToUse then
    --   if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    -- end
    -- call_action_list,name=cds
    if (HR.CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- mongoose_bite,if=active_enemies=1&target.time_to_die<focus%(action.mongoose_bite.cost-cast_regen)*gcd
    if S.MongooseBite:IsReady() and (#Enemies8y == 1 and Target:TimeToDie() < Player:Focus() % (S.MongooseBite:Cost() - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD()) then
      if HR.Cast(S.MongooseBite, nil, nil, "Melee") then return "mongoose_bite 999"; end
    end
    -- call_action_list,name=apwfi,if=active_enemies<3&talent.chakrams.enabled&talent.alpha_predator.enabled
    if (#Enemies8y < 3 and S.Chakrams:IsAvailable() and S.AlphaPredator:IsAvailable()) then
      local ShouldReturn = Apwfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=wfi,if=active_enemies<3&talent.chakrams.enabled
    if (#Enemies8y < 3 and S.Chakrams:IsAvailable()) then
      local ShouldReturn = Wfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3&!talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    if (#Enemies8y < 3 and not S.AlphaPredator:IsAvailable() and not S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apst,if=active_enemies<3&talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    if (#Enemies8y < 3 and S.AlphaPredator:IsAvailable() and not S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = Apst(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apwfi,if=active_enemies<3&talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    if (#Enemies8y < 3 and S.AlphaPredator:IsAvailable() and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = Apwfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=wfi,if=active_enemies<3&!talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    if (#Enemies8y < 3 and not S.AlphaPredator:IsAvailable() and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = Wfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1&!talent.birds_of_prey.enabled|active_enemies>2
    if (#Enemies8y > 1 and not S.BirdsofPrey:IsAvailable() or #Enemies8y > 2) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- kill_shot,if=buff.flayers_mark.remains<5|target.health.pct<=20
    if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
      if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "Kill Shot (ST)"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 888"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastable() and HR.CDsON() then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 890"; end
    end
  end
end

local function Init ()
  -- HL.RegisterNucleusAbility(187708, 8, 6)                           -- Carve
  -- HL.RegisterNucleusAbility(212436, 8, 6)                           -- Butchery
  -- HL.RegisterNucleusAbility({259495, 270335, 270323, 271045}, 8, 6) -- Bombs
  -- HL.RegisterNucleusAbility(259391, 40, 6)                          -- Chakrams
end

HR.SetAPL(255, APL, Init)

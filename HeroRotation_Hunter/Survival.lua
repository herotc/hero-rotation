--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Hunter then Spell.Hunter = {} end
Spell.Hunter.Survival = {
  SummonPet                             = Spell(883),
  SteelTrapDebuff                       = Spell(162487),
  SteelTrap                             = Spell(162488),
  Harpoon                               = Spell(190925),
  BloodFury                             = Spell(20572),
  CoordinatedAssault                    = Spell(266779),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  Berserking                            = Spell(26297),
  BerserkingBuff                        = Spell(26297),
  CoordinatedAssaultBuff                = Spell(266779),
  BloodFuryBuff                         = Spell(20572),
  AspectoftheEagle                      = Spell(186289),
  AMurderofCrows                        = Spell(131894),
  Carve                                 = Spell(187708),
  ShrapnelBombDebuff                    = Spell(270339),
  WildfireBomb                          = Spell(259495),
  GuerrillaTactics                      = Spell(264332),
  WildfireBombDebuff                    = Spell(269747),
  MongooseBite                          = Spell(259387),
  LatentPoisonDebuff                    = Spell(273286),
  Chakrams                              = Spell(259391),
  KillCommand                           = Spell(259489),
  BloodseekerDebuff                     = Spell(259277),
  Butchery                              = Spell(212436),
  WildfireInfusion                      = Spell(271014),
  InternalBleedingDebuff                = Spell(270343),
  FlankingStrike                        = Spell(269751),
  SerpentSting                          = Spell(259491),
  SerpentStingDebuff                    = Spell(259491),
  VipersVenomBuff                       = Spell(268552),
  TermsofEngagement                     = Spell(265895),
  TipoftheSpearBuff                     = Spell(260286),
  RaptorStrike                          = Spell(186270),
  MongooseFuryBuff                      = Spell(259388),
  LatentPoison                          = Spell(273283),
  VenomousFangs                         = Spell(274590),
  BirdsofPrey                           = Spell(260331),
  BlurofTalonsBuff                      = Spell(277969),
  AlphaPredator                         = Spell(269737),
  VipersVenom                           = Spell(268501),
  BlurofTalons                          = Spell(277653),
  WildernessSurvival                    = Spell(278532),
  ArcaneTorrent                         = Spell(50613)
};
local S = Spell.Hunter.Survival;

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.Survival = {
  BattlePotionofAgility            = Item(163223)
};
local I = Item.Hunter.Survival;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Survival = HR.GUISettings.APL.Hunter.Survival
};

-- Variables
local VarCarveCdr = 0;

HL:RegisterForEvent(function()
  VarCarveCdr = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {8}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end


local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

S.WildfireBombNormal  = Spell(259495)
S.ShrapnelBomb        = Spell(270335)
S.PheromoneBomb       = Spell(270323)
S.VolatileBomb        = Spell(271045)

local WildfireInfusions = {
  S.ShrapnelBomb,
  S.PheromoneBomb,
  S.VolatileBomb,
}

local function CurrentWildfireInfusion ()
  if S.WildfireInfusion:IsAvailable() then
    for _, infusion in pairs(WildfireInfusions) do
      if infusion:IsLearned() then return infusion end
    end
  end
  return S.WildfireBombNormal
end

S.RaptorStrikeNormal  = Spell(186270)
S.RaptorStrikeEagle   = Spell(265189)
S.MongooseBiteNormal  = Spell(259387)
S.MongooseBiteEagle   = Spell(265888)

local function CurrentRaptorStrike ()
  return S.RaptorStrikeEagle:IsLearned() and S.RaptorStrikeEagle or S.RaptorStrikeNormal
end

local function CurrentMongooseBite ()
  return S.MongooseBiteEagle:IsLearned() and S.MongooseBiteEagle or S.MongooseBiteNormal
end

local function EvaluateCycleCarveCdr62(TargetUnit)
  return (Cache.EnemiesCount[8] < 5) and (Cache.EnemiesCount[8] < 5)
end

local function EvaluateTargetIfFilterMongooseBite98(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfMongooseBite107(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff) == 10
end

local function EvaluateTargetIfFilterKillCommand115(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.BloodseekerDebuff)
end

local function EvaluateTargetIfKillCommand128(TargetUnit)
  return Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax()
end

local function EvaluateTargetIfFilterSerpentSting164(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.SerpentStingDebuff)
end

local function EvaluateTargetIfSerpentSting181(TargetUnit)
  return bool(Player:BuffStackP(S.VipersVenomBuff))
end

local function EvaluateTargetIfFilterSerpentSting199(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.SerpentStingDebuff)
end

local function EvaluateTargetIfSerpentSting222(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.SerpentStingDebuff) and Player:BuffStackP(S.TipoftheSpearBuff) < 3
end

local function EvaluateTargetIfFilterMongooseBite228(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfFilterRaptorStrike239(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff)
end
--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cds, Cleave, MbApWfiSt, St, WfiSt
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  S.WildfireBomb = CurrentWildfireInfusion()
  S.RaptorStrike = CurrentRaptorStrike()
  S.MongooseBite = CurrentMongooseBite()
  Precombat = function()
    -- flask
    -- augmentation
    -- food
    -- summon_pet
    if S.SummonPet:IsCastableP() then
      if HR.Cast(S.SummonPet, Settings.Survival.GCDasOffGCD.SummonPet) then return "summon_pet 3"; end
    end
    -- snapshot_stats
    -- potion
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 6"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() and Player:DebuffDownP(S.SteelTrapDebuff) and Everyone.TargetIsValid() then
      if HR.Cast(S.SteelTrap) then return "steel_trap 8"; end
    end
    -- harpoon
    if S.Harpoon:IsCastableP() and Everyone.TargetIsValid() then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 12"; end
    end
  end
  Cds = function()
    -- blood_fury,if=cooldown.coordinated_assault.remains>30
    if S.BloodFury:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 14"; end
    end
    -- ancestral_call,if=cooldown.coordinated_assault.remains>30
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 18"; end
    end
    -- fireblood,if=cooldown.coordinated_assault.remains>30
    if S.Fireblood:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 22"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 26"; end
    end
    -- berserking,if=cooldown.coordinated_assault.remains>60|time_to_die<11
    if S.Berserking:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 60 or Target:TimeToDie() < 11) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 28"; end
    end
    -- potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)|time_to_die<26
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not Player:IsRace("Troll") and not Player:IsRace("Orc")) or Target:TimeToDie() < 26) then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 38"; end
    end
    -- aspect_of_the_eagle,if=target.distance>=6
    if S.AspectoftheEagle:IsCastableP() and HR.CDsON() and (not Target:IsInRange("Melee")) then
      if HR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return "aspect_of_the_eagle 50"; end
    end
  end
  Cleave = function()
    -- variable,name=carve_cdr,op=setif,value=active_enemies,value_else=5,condition=active_enemies<5
    if true then
      if HR.CastCycle(VarCarveCdr, 8, EvaluateCycleCarveCdr62) then return "carve_cdr 76" end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 77"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 79"; end
    end
    -- carve,if=dot.shrapnel_bomb.ticking
    if S.Carve:IsReadyP() and (Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.Carve) then return "carve 81"; end
    end
    -- wildfire_bomb,if=!talent.guerrilla_tactics.enabled|full_recharge_time<gcd
    if S.WildfireBomb:IsCastableP() and (not S.GuerrillaTactics:IsAvailable() or S.WildfireBomb:FullRechargeTimeP() < Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 85"; end
    end
    -- mongoose_bite,target_if=max:debuff.latent_poison.stack,if=debuff.latent_poison.stack=10
    if S.MongooseBite:IsReadyP() then
      if HR.CastTargetIf(S.MongooseBite, 8, "max", EvaluateTargetIfFilterMongooseBite98, EvaluateTargetIfMongooseBite107) then return "mongoose_bite 109" end
    end
    -- chakrams
    if S.Chakrams:IsCastableP() then
      if HR.Cast(S.Chakrams) then return "chakrams 110"; end
    end
    -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
    if S.KillCommand:IsCastableP() then
      if HR.CastTargetIf(S.KillCommand, 8, "min", EvaluateTargetIfFilterKillCommand115, EvaluateTargetIfKillCommand128) then return "kill_command 130" end
    end
    -- butchery,if=full_recharge_time<gcd|!talent.wildfire_infusion.enabled|dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3
    if S.Butchery:IsCastableP() and (S.Butchery:FullRechargeTimeP() < Player:GCD() or not S.WildfireInfusion:IsAvailable() or Target:DebuffP(S.ShrapnelBombDebuff) and Target:DebuffStackP(S.InternalBleedingDebuff) < 3) then
      if HR.Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery) then return "butchery 131"; end
    end
    -- carve,if=talent.guerrilla_tactics.enabled
    if S.Carve:IsReadyP() and (S.GuerrillaTactics:IsAvailable()) then
      if HR.Cast(S.Carve) then return "carve 143"; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return "flanking_strike 147"; end
    end
    -- wildfire_bomb,if=dot.wildfire_bomb.refreshable|talent.wildfire_infusion.enabled
    if S.WildfireBomb:IsCastableP() and (Target:DebuffRefreshableCP(S.WildfireBombDebuff) or S.WildfireInfusion:IsAvailable()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 155"; end
    end
    -- serpent_sting,target_if=min:remains,if=buff.vipers_venom.react
    if S.SerpentSting:IsReadyP() then
      if HR.CastTargetIf(S.SerpentSting, 8, "min", EvaluateTargetIfFilterSerpentSting164, EvaluateTargetIfSerpentSting181) then return "serpent_sting 183" end
    end
    -- carve,if=cooldown.wildfire_bomb.remains>variable.carve_cdr%2
    if S.Carve:IsReadyP() and (S.WildfireBomb:CooldownRemainsP() > VarCarveCdr / 2) then
      if HR.Cast(S.Carve) then return "carve 184"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() then
      if HR.Cast(S.SteelTrap) then return "steel_trap 190"; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 192"; end
    end
    -- serpent_sting,target_if=min:remains,if=refreshable&buff.tip_of_the_spear.stack<3
    if S.SerpentSting:IsReadyP() then
      if HR.CastTargetIf(S.SerpentSting, 8, "min", EvaluateTargetIfFilterSerpentSting199, EvaluateTargetIfSerpentSting222) then return "serpent_sting 224" end
    end
    -- mongoose_bite,target_if=max:debuff.latent_poison.stack
    if S.MongooseBite:IsReadyP() then
      if HR.CastTargetIf(S.MongooseBite, 8, "max", EvaluateTargetIfFilterMongooseBite228) then return "mongoose_bite 235" end
    end
    -- raptor_strike,target_if=max:debuff.latent_poison.stack
    if S.RaptorStrike:IsReadyP() then
      if HR.CastTargetIf(S.RaptorStrike, 8, "max", EvaluateTargetIfFilterRaptorStrike239) then return "raptor_strike 246" end
    end
  end
  MbApWfiSt = function()
    -- serpent_sting,if=!dot.serpent_sting.ticking
    if S.SerpentSting:IsReadyP() and (not Target:DebuffP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 247"; end
    end
    -- wildfire_bomb,if=full_recharge_time<gcd|(focus+cast_regen<focus.max)&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
    if S.WildfireBomb:IsCastableP() and (S.WildfireBomb:FullRechargeTimeP() < Player:GCD() or (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax()) and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) and Target:DebuffRefreshableCP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() and not Player:BuffP(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 251"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 287"; end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 289"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() then
      if HR.Cast(S.SteelTrap) then return "steel_trap 291"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.remains&next_wi_bomb.pheromone
    if S.MongooseBite:IsReadyP() and (bool(Player:BuffRemainsP(S.MongooseFuryBuff)) and S.PheromoneBomb:IsLearned()) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 293"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&(buff.mongoose_fury.stack<5|focus<action.mongoose_bite.cost)
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (Player:BuffStackP(S.MongooseFuryBuff) < 5 or Player:Focus() < S.MongooseBite:Cost())) then
      if HR.Cast(S.KillCommand) then return "kill_command 297"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.shrapnel&focus>60&dot.serpent_sting.remains>3*gcd
    if S.WildfireBomb:IsCastableP() and (S.ShrapnelBomb:IsLearned() and Player:Focus() > 60 and Target:DebuffRemainsP(S.SerpentStingDebuff) > 3 * Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 311"; end
    end
    -- serpent_sting,if=refreshable&(next_wi_bomb.volatile&!dot.shrapnel_bomb.ticking|azerite.latent_poison.enabled|azerite.venomous_fangs.enabled)
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff) and (S.VolatileBomb:IsLearned() and not Target:DebuffP(S.ShrapnelBombDebuff) or S.LatentPoison:AzeriteEnabled() or S.VenomousFangs:AzeriteEnabled())) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 315"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus>60|dot.shrapnel_bomb.ticking
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60 or Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 329"; end
    end
    -- serpent_sting,if=refreshable
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 335"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
    if S.WildfireBomb:IsCastableP() and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() or S.ShrapnelBomb:IsLearned() and Player:Focus() > 50) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 343"; end
    end
  end
  St = function()
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 347"; end
    end
    -- mongoose_bite,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&(buff.coordinated_assault.remains<gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd)
    if S.MongooseBite:IsReadyP() and (S.BirdsofPrey:IsAvailable() and Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffRemainsP(S.CoordinatedAssaultBuff) < Player:GCD() or Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < Player:GCD())) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 349"; end
    end
    -- raptor_strike,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&(buff.coordinated_assault.remains<gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd)
    if S.RaptorStrike:IsReadyP() and (S.BirdsofPrey:IsAvailable() and Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffRemainsP(S.CoordinatedAssaultBuff) < Player:GCD() or Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < Player:GCD())) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 361"; end
    end
    -- serpent_sting,if=buff.vipers_venom.react&buff.vipers_venom.remains<gcd
    if S.SerpentSting:IsReadyP() and (bool(Player:BuffStackP(S.VipersVenomBuff)) and Player:BuffRemainsP(S.VipersVenomBuff) < Player:GCD()) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 373"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&(!talent.alpha_predator.enabled|full_recharge_time<gcd)
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (not S.AlphaPredator:IsAvailable() or S.KillCommand:FullRechargeTimeP() < Player:GCD())) then
      if HR.Cast(S.KillCommand) then return "kill_command 379"; end
    end
    -- wildfire_bomb,if=focus+cast_regen<focus.max&(full_recharge_time<gcd|!dot.wildfire_bomb.ticking&(buff.mongoose_fury.down|full_recharge_time<4.5*gcd))
    if S.WildfireBomb:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and (S.WildfireBomb:FullRechargeTimeP() < Player:GCD() or not Target:DebuffP(S.WildfireBombDebuff) and (Player:BuffDownP(S.MongooseFuryBuff) or S.WildfireBomb:FullRechargeTimeP() < 4.5 * Player:GCD()))) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 393"; end
    end
    -- serpent_sting,if=buff.vipers_venom.react&dot.serpent_sting.remains<4*gcd|!talent.vipers_venom.enabled&!dot.serpent_sting.ticking&!buff.coordinated_assault.up
    if S.SerpentSting:IsReadyP() and (bool(Player:BuffStackP(S.VipersVenomBuff)) and Target:DebuffRemainsP(S.SerpentStingDebuff) < 4 * Player:GCD() or not S.VipersVenom:IsAvailable() and not Target:DebuffP(S.SerpentStingDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 419"; end
    end
    -- serpent_sting,if=refreshable&(azerite.latent_poison.rank>2|azerite.latent_poison.enabled&azerite.venomous_fangs.enabled|(azerite.latent_poison.enabled|azerite.venomous_fangs.enabled)&(!azerite.blur_of_talons.enabled|!talent.birds_of_prey.enabled|!buff.coordinated_assault.up))
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff) and (S.LatentPoison:AzeriteRank() > 2 or S.LatentPoison:AzeriteEnabled() and S.VenomousFangs:AzeriteEnabled() or (S.LatentPoison:AzeriteEnabled() or S.VenomousFangs:AzeriteEnabled()) and (not S.BlurofTalons:AzeriteEnabled() or not S.BirdsofPrey:IsAvailable() or not Player:BuffP(S.CoordinatedAssaultBuff)))) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 431"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() then
      if HR.Cast(S.SteelTrap) then return "steel_trap 455"; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 457"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 461"; end
    end
    -- chakrams
    if S.Chakrams:IsCastableP() then
      if HR.Cast(S.Chakrams) then return "chakrams 463"; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return "flanking_strike 465"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&(buff.mongoose_fury.stack<4|focus<action.mongoose_bite.cost)
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (Player:BuffStackP(S.MongooseFuryBuff) < 4 or Player:Focus() < S.MongooseBite:Cost())) then
      if HR.Cast(S.KillCommand) then return "kill_command 473"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus>60
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 487"; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsReadyP() then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 491"; end
    end
    -- serpent_sting,if=dot.serpent_sting.refreshable&!buff.coordinated_assault.up
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 493"; end
    end
    -- wildfire_bomb,if=dot.wildfire_bomb.refreshable
    if S.WildfireBomb:IsCastableP() and (Target:DebuffRefreshableCP(S.WildfireBombDebuff)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 499"; end
    end
  end
  WfiSt = function()
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 503"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 505"; end
    end
    -- mongoose_bite,if=azerite.wilderness_survival.enabled&next_wi_bomb.volatile&dot.serpent_sting.remains>2.1*gcd&dot.serpent_sting.remains<3.5*gcd&cooldown.wildfire_bomb.remains>2.5*gcd
    if S.MongooseBite:IsReadyP() and (S.WildernessSurvival:AzeriteEnabled() and S.VolatileBomb:IsLearned() and Target:DebuffRemainsP(S.SerpentStingDebuff) > 2.1 * Player:GCD() and Target:DebuffRemainsP(S.SerpentStingDebuff) < 3.5 * Player:GCD() and S.WildfireBomb:CooldownRemainsP() > 2.5 * Player:GCD()) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 507"; end
    end
    -- wildfire_bomb,if=full_recharge_time<gcd|(focus+cast_regen<focus.max)&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
    if S.WildfireBomb:IsCastableP() and (S.WildfireBomb:FullRechargeTimeP() < Player:GCD() or (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax()) and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) and Target:DebuffRefreshableCP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() and not Player:BuffP(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 517"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3&(!talent.alpha_predator.enabled|buff.mongoose_fury.stack<5|focus<action.mongoose_bite.cost)
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and Player:BuffStackP(S.TipoftheSpearBuff) < 3 and (not S.AlphaPredator:IsAvailable() or Player:BuffStackP(S.MongooseFuryBuff) < 5 or Player:Focus() < S.MongooseBite:Cost())) then
      if HR.Cast(S.KillCommand) then return "kill_command 553"; end
    end
    -- raptor_strike,if=dot.internal_bleeding.stack<3&dot.shrapnel_bomb.ticking&!talent.mongoose_bite.enabled
    if S.RaptorStrike:IsReadyP() and (Target:DebuffStackP(S.InternalBleedingDebuff) < 3 and Target:DebuffP(S.ShrapnelBombDebuff) and not S.MongooseBite:IsAvailable()) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 571"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.shrapnel&buff.mongoose_fury.down&(cooldown.kill_command.remains>gcd|focus>60)&!dot.serpent_sting.refreshable
    if S.WildfireBomb:IsCastableP() and (S.ShrapnelBomb:IsLearned() and Player:BuffDownP(S.MongooseFuryBuff) and (S.KillCommand:CooldownRemainsP() > Player:GCD() or Player:Focus() > 60) and not Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 579"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() then
      if HR.Cast(S.SteelTrap) then return "steel_trap 587"; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return "flanking_strike 589"; end
    end
    -- serpent_sting,if=buff.vipers_venom.react|refreshable&(!talent.mongoose_bite.enabled|!talent.vipers_venom.enabled|next_wi_bomb.volatile&!dot.shrapnel_bomb.ticking|azerite.latent_poison.enabled|azerite.venomous_fangs.enabled|buff.mongoose_fury.stack=5)
    if S.SerpentSting:IsReadyP() and (bool(Player:BuffStackP(S.VipersVenomBuff)) or Target:DebuffRefreshableCP(S.SerpentStingDebuff) and (not S.MongooseBite:IsAvailable() or not S.VipersVenom:IsAvailable() or S.VolatileBomb:IsLearned() and not Target:DebuffP(S.ShrapnelBombDebuff) or S.LatentPoison:AzeriteEnabled() or S.VenomousFangs:AzeriteEnabled() or Player:BuffStackP(S.MongooseFuryBuff) == 5)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 597"; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 619"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus>60|dot.shrapnel_bomb.ticking
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60 or Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 623"; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsReadyP() then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 629"; end
    end
    -- serpent_sting,if=refreshable
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 631"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
    if S.WildfireBomb:IsCastableP() and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() or S.ShrapnelBomb:IsLearned() and Player:Focus() > 50) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 639"; end
    end
  end
  if Everyone.TargetIsValid() then
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
    -- auto_attack
    -- use_items
    -- call_action_list,name=cds
    if (true) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=mb_ap_wfi_st,if=active_enemies<3&talent.wildfire_infusion.enabled&talent.alpha_predator.enabled&talent.mongoose_bite.enabled
    if (Cache.EnemiesCount[8] < 3 and S.WildfireInfusion:IsAvailable() and S.AlphaPredator:IsAvailable() and S.MongooseBite:IsAvailable()) then
      local ShouldReturn = MbApWfiSt(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=wfi_st,if=active_enemies<3&talent.wildfire_infusion.enabled
    if (Cache.EnemiesCount[8] < 3 and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = WfiSt(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<2
    if (Cache.EnemiesCount[8] < 2) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1
    if (Cache.EnemiesCount[8] > 1) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 688"; end
    end
  end
end

HR.SetAPL(255, APL)

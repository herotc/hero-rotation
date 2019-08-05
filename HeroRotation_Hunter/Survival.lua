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

-- Spells
if not Spell.Hunter then Spell.Hunter = {} end
Spell.Hunter.Survival = {
  SummonPet                             = Spell(883),
  SteelTrapDebuff                       = Spell(162487),
  SteelTrap                             = Spell(162488),
  Harpoon                               = Spell(190925),
  MongooseBite                          = MultiSpell(259387, 265888),
  CoordinatedAssaultBuff                = Spell(266779),
  BlurofTalonsBuff                      = Spell(277969),
  RaptorStrike                          = MultiSpell(186270, 265189),
  FlankingStrike                        = Spell(269751),
  KillCommand                           = Spell(259489),
  WildfireBomb                          = MultiSpell(259495, 270335, 270323, 271045),
  WildfireBombDebuff                    = Spell(269747),
  ShrapnelBomb                          = Spell(270335),
  PheromoneBomb                         = Spell(270323),
  VolatileBomb                          = Spell(271045),
  SerpentSting                          = Spell(259491),
  SerpentStingDebuff                    = Spell(259491),
  MongooseFuryBuff                      = Spell(259388),
  AMurderofCrows                        = Spell(131894),
  CoordinatedAssault                    = Spell(266779),
  TipoftheSpearBuff                     = Spell(260286),
  ShrapnelBombDebuff                    = Spell(270339),
  Chakrams                              = Spell(259391),
  BloodFury                             = Spell(20572),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  Berserking                            = Spell(26297),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  AspectoftheEagle                      = Spell(186289),
  Exhilaration                          = Spell(109304),
  Muzzle                                = Spell(187707),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  Carve                                 = Spell(187708),
  GuerrillaTactics                      = Spell(264332),
  LatentPoisonDebuff                    = Spell(273286),
  BloodseekerDebuff                     = Spell(259277),
  Butchery                              = Spell(212436),
  WildfireInfusion                      = Spell(271014),
  InternalBleedingDebuff                = Spell(270343),
  VipersVenomBuff                       = Spell(268552),
  TermsofEngagement                     = Spell(265895),
  VipersVenom                           = Spell(268501),
  AlphaPredator                         = Spell(269737),
  ArcaneTorrent                         = Spell(50613),
  RazorCoralDebuff                      = Spell(303568),
  CyclotronicBlast                      = Spell(167672)
};
local S = Spell.Hunter.Survival;

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.Survival = {
  PotionofUnbridledFury            = Item(169299),
  AshvanesRazorCoral               = Item(169311),
  PocketsizedComputationDevice     = Item(167555),
  GalecallersBoon                  = Item(159614),
  AzsharasFontofPower              = Item(169314)
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

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
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

local function EvaluateTargetIfFilterMongooseBite396(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfMongooseBite405(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff) == 10
end

local function EvaluateTargetIfFilterKillCommand413(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.BloodseekerDebuff)
end

local function EvaluateTargetIfKillCommand426(TargetUnit)
  return Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax()
end

local function EvaluateTargetIfFilterSerpentSting462(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.SerpentStingDebuff)
end

local function EvaluateTargetIfSerpentSting479(TargetUnit)
  return bool(Player:BuffStackP(S.VipersVenomBuff))
end

local function EvaluateTargetIfFilterSerpentSting497(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.SerpentStingDebuff)
end

local function EvaluateTargetIfSerpentSting520(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.SerpentStingDebuff) and Player:BuffStackP(S.TipoftheSpearBuff) < 3
end

local function EvaluateTargetIfFilterMongooseBite526(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff)
end

local function EvaluateTargetIfFilterRaptorStrike537(TargetUnit)
  return TargetUnit:DebuffStackP(S.LatentPoisonDebuff)
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Apst, Apwfi, Cds, Cleave, St, Wfi
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- augmentation
    -- food
    -- summon_pet
    if S.SummonPet:IsCastableP() then
      if HR.Cast(S.SummonPet, Settings.Survival.GCDasOffGCD.SummonPet) then return "summon_pet 3"; end
    end
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_agility 6"; end
      end
      -- use_item,name=azsharas_font_of_power
      if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and HR.CDsON() then
        if HR.CastSuggested(I.AzsharasFontofPower) then return "azsharas_font_of_power 7"; end
      end
      -- use_item,effect_name=cyclotronic_blast,if=!raid_event.invulnerable.exists
      if I.PocketsizedComputationDevice:IsEquipped() and I.PocketsizedComputationDevice:IsReady() and S.CyclotronicBlast:IsAvailable() and HR.CDsON() then
        if HR.CastSuggested(I.PocketsizedComputationDevice) then return "pocketsized_computation_device 8"; end
      end
      -- guardian_of_azeroth
      if S.GuardianofAzeroth:IsCastableP() then
        if HR.Cast(S.GuardianofAzeroth, Settings.Survival.GCDasOffGCD.Essences) then return "guardian_of_azeroth 9"; end
      end
      -- steel_trap
      if S.SteelTrap:IsCastableP() and Player:DebuffDownP(S.SteelTrapDebuff) then
        if HR.Cast(S.SteelTrap) then return "steel_trap 10"; end
      end
      -- harpoon
      if S.Harpoon:IsCastableP() then
        if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 12"; end
      end
    end
  end
  Apst = function()
    -- mongoose_bite,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffRemainsP(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 14"; end
    end
    -- raptor_strike,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
    if S.RaptorStrike:IsReadyP() and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffRemainsP(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 24"; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return "flanking_strike 34"; end
    end
    -- kill_command,if=full_recharge_time<1.5*gcd&focus+cast_regen<focus.max-10
    if S.KillCommand:IsCastableP() and (S.KillCommand:FullRechargeTimeP() < 1.5 * Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() - 10) then
      if HR.Cast(S.KillCommand) then return "kill_command 42"; end
    end
    -- steel_trap,if=focus+cast_regen<focus.max
    if S.SteelTrap:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.SteelTrap) then return "steel_trap 54"; end
    end
    -- wildfire_bomb,if=focus+cast_regen<focus.max&!ticking&!buff.memory_of_lucid_dreams.up&(full_recharge_time<1.5*gcd|!dot.wildfire_bomb.ticking&!buff.coordinated_assault.up)
    if S.WildfireBomb:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and not Target:DebuffP(S.WildfireBombDebuff) and not Player:BuffP(S.MemoryofLucidDreams) and (S.WildfireBomb:FullRechargeTimeP() < 1.5 * Player:GCD() or not Target:DebuffP(S.WildfireBombDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff))) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 64"; end
    end
    -- serpent_sting,if=!dot.serpent_sting.ticking&!buff.coordinated_assault.up
    if S.SerpentSting:IsReadyP() and (not Target:DebuffP(S.SerpentStingDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 90"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&(buff.mongoose_fury.stack<5|focus<action.mongoose_bite.cost)
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (Player:BuffStackP(S.MongooseFuryBuff) < 5 or Player:Focus() < S.MongooseBite:Cost())) then
      if HR.Cast(S.KillCommand) then return "kill_command 96"; end
    end
    -- serpent_sting,if=refreshable&!buff.coordinated_assault.up&buff.mongoose_fury.stack<5
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff) and Player:BuffStackP(S.MongooseFuryBuff) < 5) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 110"; end
    end
    -- a_murder_of_crows,if=!buff.coordinated_assault.up
    if S.AMurderofCrows:IsCastableP() and (not Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 122"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 126"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus+cast_regen>focus.max-10|buff.coordinated_assault.up
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 10 or Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 128"; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsReadyP() then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 140"; end
    end
    -- wildfire_bomb,if=!ticking
    if S.WildfireBomb:IsCastableP() and (not Target:DebuffP(S.WildfireBombDebuff)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 142"; end
    end
  end
  Apwfi = function()
    -- mongoose_bite,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < Player:GCD()) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 150"; end
    end
    -- raptor_strike,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
    if S.RaptorStrike:IsReadyP() and (Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < Player:GCD()) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 156"; end
    end
    -- serpent_sting,if=!dot.serpent_sting.ticking
    if S.SerpentSting:IsReadyP() and (not Target:DebuffP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 162"; end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 166"; end
    end
    -- wildfire_bomb,if=full_recharge_time<1.5*gcd|focus+cast_regen<focus.max&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
    if S.WildfireBomb:IsCastableP() and (S.WildfireBomb:FullRechargeTimeP() < 1.5 * Player:GCD() or Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) and Target:DebuffRefreshableCP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() and not Player:BuffP(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 168"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 204"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.remains&next_wi_bomb.pheromone
    if S.MongooseBite:IsReadyP() and (bool(Player:BuffRemainsP(S.MongooseFuryBuff)) and S.PheromoneBomb:IsLearned()) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 206"; end
    end
    -- kill_command,if=full_recharge_time<1.5*gcd&focus+cast_regen<focus.max-20
    if S.KillCommand:IsCastableP() and (S.KillCommand:FullRechargeTimeP() < 1.5 * Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() - 20) then
      if HR.Cast(S.KillCommand) then return "kill_command 210"; end
    end
    -- steel_trap,if=focus+cast_regen<focus.max
    if S.SteelTrap:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.SteelTrap) then return "steel_trap 222"; end
    end
    -- raptor_strike,if=buff.tip_of_the_spear.stack=3|dot.shrapnel_bomb.ticking
    if S.RaptorStrike:IsReadyP() and (Player:BuffStackP(S.TipoftheSpearBuff) == 3 or Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 232"; end
    end
    -- mongoose_bite,if=dot.shrapnel_bomb.ticking
    if S.MongooseBite:IsReadyP() and (Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 238"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.shrapnel&focus>30&dot.serpent_sting.remains>5*gcd
    if S.WildfireBomb:IsCastableP() and (S.ShrapnelBomb:IsLearned() and Player:Focus() > 30 and Target:DebuffRemainsP(S.SerpentStingDebuff) > 5 * Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 242"; end
    end
    -- chakrams,if=!buff.mongoose_fury.remains
    if S.Chakrams:IsCastableP() and (not bool(Player:BuffRemainsP(S.MongooseFuryBuff))) then
      if HR.Cast(S.Chakrams) then return "chakrams 246"; end
    end
    -- serpent_sting,if=refreshable
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 250"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&(buff.mongoose_fury.stack<5|focus<action.mongoose_bite.cost)
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and (Player:BuffStackP(S.MongooseFuryBuff) < 5 or Player:Focus() < S.MongooseBite:Cost())) then
      if HR.Cast(S.KillCommand) then return "kill_command 258"; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsReadyP() then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 272"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus>40|dot.shrapnel_bomb.ticking
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 40 or Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 274"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
    if S.WildfireBomb:IsCastableP() and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() or S.ShrapnelBomb:IsLearned() and Player:Focus() > 50) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 280"; end
    end
  end
  Cds = function()
    -- blood_fury,if=cooldown.coordinated_assault.remains>30
    if S.BloodFury:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 284"; end
    end
    -- ancestral_call,if=cooldown.coordinated_assault.remains>30
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 288"; end
    end
    -- fireblood,if=cooldown.coordinated_assault.remains>30
    if S.Fireblood:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 292"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 296"; end
    end
    -- berserking,if=cooldown.coordinated_assault.remains>60|time_to_die<13
    if S.Berserking:IsCastableP() and HR.CDsON() and (S.CoordinatedAssault:CooldownRemainsP() > 60 or Target:TimeToDie() < 13) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 298"; end
    end
    -- potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)|(consumable.potion_of_unbridled_fury&target.time_to_die<61|target.time_to_die<26)
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not Player:IsRace("Troll") and not Player:IsRace("Orc")) or Target:TimeToDie() < 61) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_agility 308"; end
    end
    -- aspect_of_the_eagle,if=target.distance>=6
    if S.AspectoftheEagle:IsCastableP() and HR.CDsON() and (not Target:IsInRange(8) and Target:IsInRange(40)) then
      if HR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return "aspect_of_the_eagle 320"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=buff.memory_of_lucid_dreams.up|buff.guardian_of_azeroth.up|debuff.razor_coral_debuff.down|target.time_to_die<20
    if I.AshvanesRazorCoral:IsEquipped() and I.AshvanesRazorCoral:IsReady() and (Player:BuffP(S.MemoryofLucidDreams) or Player:BuffP(S.GuardianofAzeroth) or Target:DebuffDownP(S.RazorCoralDebuff) or Target:TimeToDie() < 20) then
      if HR.CastSuggested(I.AshvanesRazorCoral) then return "ashvanes_razor_coral 321"; end
    end
    -- use_item,name=galecallers_boon,if=cooldown.memory_of_lucid_dreams.remains|talent.wildfire_infusion.enabled&cooldown.coordinated_assault.remains|cooldown.cyclotronic_blast.remains|!essence.memory_of_lucid_dreams.major&cooldown.coordinated_assault.remains
    if I.GalecallersBoon:IsEquipped() and I.GalecallersBoon:IsReady() and (bool(S.MemoryofLucidDreams:CooldownRemainsP()) or S.WildfireInfusion:IsAvailable() and bool(S.CoordinatedAssault:CooldownRemainsP()) or bool(S.CyclotronicBlast:CooldownRemainsP()) or not S.MemoryofLucidDreams:IsAvailable() and bool(S.CoordinatedAssault:CooldownRemainsP())) then
      if HR.CastSuggested(I.GalecallersBoon) then return "galecallers_boon 322"; end
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() then
      if HR.CastSuggested(I.AzsharasFontofPower) then return "azsharas_font_of_power 323"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, Settings.Survival.GCDasOffGCD.Essences) then return "focused_azerite_beam 324"; end
    end
    -- memory_of_lucid_dreams,if=focus<focus.max-30&buff.coordinated_assault.up
    if S.MemoryofLucidDreams:IsCastableP() and (Player:FocusDeficit() > 30 and Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, Settings.Survival.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams 325"; end
    end
    -- blood_of_the_enemy,if=buff.coordinated_assault.up
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.BloodoftheEnemy, Settings.Survival.GCDasOffGCD.Essences) then return "blood_of_the_enemy 328"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, Settings.Survival.GCDasOffGCD.Essences) then return "purifying_blast 332"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, Settings.Survival.GCDasOffGCD.Essences) then return "guardian_of_azeroth 334"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, Settings.Survival.GCDasOffGCD.Essences) then return "ripple_in_space 336"; end
    end
    -- concentrated_flame,if=full_recharge_time<1*gcd
    if S.ConcentratedFlame:IsCastableP() and (S.ConcentratedFlame:FullRechargeTimeP() < 1 * Player:GCD()) then
      if HR.Cast(S.ConcentratedFlame, Settings.Survival.GCDasOffGCD.Essences) then return "concentrated_flame 338"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, Settings.Survival.GCDasOffGCD.Essences) then return "the_unbound_force 344"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance, Settings.Survival.GCDasOffGCD.Essences) then return "worldvein_resonance 348"; end
    end
  end
  Cleave = function()
    -- variable,name=carve_cdr,op=setif,value=active_enemies,value_else=5,condition=active_enemies<5
    VarCarveCdr = math.min(Cache.EnemiesCount[8], 5)
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 375"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 377"; end
    end
    -- carve,if=dot.shrapnel_bomb.ticking
    if S.Carve:IsReadyP() and (Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.Carve) then return "carve 379"; end
    end
    -- wildfire_bomb,if=!talent.guerrilla_tactics.enabled|full_recharge_time<gcd
    if S.WildfireBomb:IsCastableP() and (not S.GuerrillaTactics:IsAvailable() or S.WildfireBomb:FullRechargeTimeP() < Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 383"; end
    end
    -- mongoose_bite,target_if=max:debuff.latent_poison.stack,if=debuff.latent_poison.stack=10
    if S.MongooseBite:IsReadyP() then
      if HR.CastTargetIf(S.MongooseBite, 8, "max", EvaluateTargetIfFilterMongooseBite396, EvaluateTargetIfMongooseBite405) then return "mongoose_bite 407" end
    end
    -- chakrams
    if S.Chakrams:IsCastableP() then
      if HR.Cast(S.Chakrams) then return "chakrams 408"; end
    end
    -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
    if S.KillCommand:IsCastableP() then
      if HR.CastTargetIf(S.KillCommand, 8, "min", EvaluateTargetIfFilterKillCommand413, EvaluateTargetIfKillCommand426) then return "kill_command 428" end
    end
    -- butchery,if=full_recharge_time<gcd|!talent.wildfire_infusion.enabled|dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3
    if S.Butchery:IsCastableP() and (S.Butchery:FullRechargeTimeP() < Player:GCD() or not S.WildfireInfusion:IsAvailable() or Target:DebuffP(S.ShrapnelBombDebuff) and Target:DebuffStackP(S.InternalBleedingDebuff) < 3) then
      if HR.Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery) then return "butchery 429"; end
    end
    -- carve,if=talent.guerrilla_tactics.enabled
    if S.Carve:IsReadyP() and (S.GuerrillaTactics:IsAvailable()) then
      if HR.Cast(S.Carve) then return "carve 441"; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return "flanking_strike 445"; end
    end
    -- wildfire_bomb,if=dot.wildfire_bomb.refreshable|talent.wildfire_infusion.enabled
    if S.WildfireBomb:IsCastableP() and (Target:DebuffRefreshableCP(S.WildfireBombDebuff) or S.WildfireInfusion:IsAvailable()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 453"; end
    end
    -- serpent_sting,target_if=min:remains,if=buff.vipers_venom.react
    if S.SerpentSting:IsReadyP() then
      if HR.CastTargetIf(S.SerpentSting, 8, "min", EvaluateTargetIfFilterSerpentSting462, EvaluateTargetIfSerpentSting479) then return "serpent_sting 481" end
    end
    -- carve,if=cooldown.wildfire_bomb.remains>variable.carve_cdr%2
    if S.Carve:IsReadyP() and (S.WildfireBomb:CooldownRemainsP() > VarCarveCdr / 2) then
      if HR.Cast(S.Carve) then return "carve 482"; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() then
      if HR.Cast(S.SteelTrap) then return "steel_trap 488"; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 490"; end
    end
    -- serpent_sting,target_if=min:remains,if=refreshable&buff.tip_of_the_spear.stack<3
    if S.SerpentSting:IsReadyP() then
      if HR.CastTargetIf(S.SerpentSting, 8, "min", EvaluateTargetIfFilterSerpentSting497, EvaluateTargetIfSerpentSting520) then return "serpent_sting 522" end
    end
    -- mongoose_bite,target_if=max:debuff.latent_poison.stack
    if S.MongooseBite:IsReadyP() then
      if HR.CastTargetIf(S.MongooseBite, 8, "max", EvaluateTargetIfFilterMongooseBite526) then return "mongoose_bite 533" end
    end
    -- raptor_strike,target_if=max:debuff.latent_poison.stack
    if S.RaptorStrike:IsReadyP() then
      if HR.CastTargetIf(S.RaptorStrike, 8, "max", EvaluateTargetIfFilterRaptorStrike537) then return "raptor_strike 544" end
    end
  end
  St = function()
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 545"; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return "flanking_strike 549"; end
    end
    -- raptor_strike,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
    if S.RaptorStrike:IsReadyP() and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffRemainsP(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 557"; end
    end
    -- mongoose_bite,if=buff.coordinated_assault.up&(buff.coordinated_assault.remains<1.5*gcd|buff.blur_of_talons.up&buff.blur_of_talons.remains<1.5*gcd)
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffRemainsP(S.CoordinatedAssaultBuff) < 1.5 * Player:GCD() or Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < 1.5 * Player:GCD())) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 567"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) + 15 < Player:FocusMax()) then
      if HR.Cast(S.KillCommand) then return "kill_command 568"; end
    end
    -- steel_trap,if=focus+cast_regen<focus.max
    if S.SteelTrap:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.SteelTrap) then return "steel_trap 577"; end
    end
    -- wildfire_bomb,if=focus+cast_regen<focus.max&!ticking&!buff.memory_of_lucid_dreams.up&(full_recharge_time<1.5*gcd|!dot.wildfire_bomb.ticking&!buff.coordinated_assault.up)
    if S.WildfireBomb:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and not Target:DebuffP(S.WildfireBombDebuff) and not Player:BuffP(S.MemoryofLucidDreams) and (S.WildfireBomb:FullRechargeTimeP() < 1.5 * Player:GCD() or not Target:DebuffP(S.WildfireBombDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff))) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 587"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.stack>5&!cooldown.coordinated_assault.remains
    if S.MongooseBite:IsReadyP() and (Player:BuffStackP(S.MongooseFuryBuff) > 5 and not bool(S.CoordinatedAssault:CooldownRemainsP())) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 613"; end
    end
    -- serpent_sting,if=buff.vipers_venom.up&dot.serpent_sting.remains<4*gcd|dot.serpent_sting.refreshable&!buff.coordinated_assault.up
    if S.SerpentSting:IsReadyP() and (Player:BuffP(S.VipersVenomBuff) and Target:DebuffRemainsP(S.SerpentStingDebuff) < 4 * Player:GCD() or Target:DebuffRefreshableCP(S.SerpentStingDebuff) and not Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 619"; end
    end
    -- a_murder_of_crows,if=!buff.coordinated_assault.up
    if S.AMurderofCrows:IsCastableP() and (not Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 629"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 633"; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus+cast_regen>focus.max-20&talent.vipers_venom.enabled|focus+cast_regen>focus.max-1&talent.terms_of_engagement.enabled|buff.coordinated_assault.up
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 20 and S.VipersVenom:IsAvailable() or Player:Focus() + Player:FocusCastRegen(S.MongooseBite:ExecuteTime()) > Player:FocusMax() - 1 and S.TermsofEngagement:IsAvailable() or Player:BuffP(S.CoordinatedAssaultBuff)) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 635"; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsReadyP() then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 657"; end
    end
    -- wildfire_bomb,if=dot.wildfire_bomb.refreshable
    if S.WildfireBomb:IsCastableP() and (Target:DebuffRefreshableCP(S.WildfireBombDebuff)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 659"; end
    end
    -- serpent_sting,if=buff.vipers_venom.up
    if S.SerpentSting:IsReadyP() and (Player:BuffP(S.VipersVenomBuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 663"; end
    end
  end
  Wfi = function()
    -- harpoon,if=focus+cast_regen<focus.max&talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.Harpoon:ExecuteTime()) < Player:FocusMax() and S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return "harpoon 667"; end
    end
    -- mongoose_bite,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
    if S.MongooseBite:IsReadyP() and (Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < Player:GCD()) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 677"; end
    end
    -- raptor_strike,if=buff.blur_of_talons.up&buff.blur_of_talons.remains<gcd
    if S.RaptorStrike:IsReadyP() and (Player:BuffP(S.BlurofTalonsBuff) and Player:BuffRemainsP(S.BlurofTalonsBuff) < Player:GCD()) then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 683"; end
    end
    -- serpent_sting,if=buff.vipers_venom.up&buff.vipers_venom.remains<1.5*gcd|!dot.serpent_sting.ticking
    if S.SerpentSting:IsReadyP() and (Player:BuffP(S.VipersVenomBuff) and Player:BuffRemainsP(S.VipersVenomBuff) < 1.5 * Player:GCD() or not Target:DebuffP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 689"; end
    end
    -- wildfire_bomb,if=full_recharge_time<1.5*gcd&focus+cast_regen<focus.max|(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&!buff.mongoose_fury.up&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
    if S.WildfireBomb:IsCastableP() and (S.WildfireBomb:FullRechargeTimeP() < 1.5 * Player:GCD() and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() or (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) and Target:DebuffRefreshableCP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() and not Player:BuffP(S.MongooseFuryBuff) and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3)) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 697"; end
    end
    -- kill_command,if=focus+cast_regen<focus.max-focus.regen
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() - Player:FocusRegen()) then
      if HR.Cast(S.KillCommand) then return "kill_command 733"; end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.Survival.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 741"; end
    end
    -- steel_trap,if=focus+cast_regen<focus.max
    if S.SteelTrap:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.SteelTrap:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.SteelTrap) then return "steel_trap 743"; end
    end
    -- wildfire_bomb,if=full_recharge_time<1.5*gcd
    if S.WildfireBomb:IsCastableP() and (S.WildfireBomb:FullRechargeTimeP() < 1.5 * Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 753"; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return "coordinated_assault 761"; end
    end
    -- serpent_sting,if=buff.vipers_venom.up&dot.serpent_sting.remains<4*gcd
    if S.SerpentSting:IsReadyP() and (Player:BuffP(S.VipersVenomBuff) and Target:DebuffRemainsP(S.SerpentStingDebuff) < 4 * Player:GCD()) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 763"; end
    end
    -- mongoose_bite,if=dot.shrapnel_bomb.ticking|buff.mongoose_fury.stack=5
    if S.MongooseBite:IsReadyP() and (Target:DebuffP(S.ShrapnelBombDebuff) or Player:BuffStackP(S.MongooseFuryBuff) == 5) then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 769"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.shrapnel&dot.serpent_sting.remains>5*gcd
    if S.WildfireBomb:IsCastableP() and (S.ShrapnelBomb:IsLearned() and Target:DebuffRemainsP(S.SerpentStingDebuff) > 5 * Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 775"; end
    end
    -- serpent_sting,if=refreshable
    if S.SerpentSting:IsReadyP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 779"; end
    end
    -- chakrams,if=!buff.mongoose_fury.remains
    if S.Chakrams:IsCastableP() and (not bool(Player:BuffRemainsP(S.MongooseFuryBuff))) then
      if HR.Cast(S.Chakrams) then return "chakrams 787"; end
    end
    -- mongoose_bite
    if S.MongooseBite:IsReadyP() then
      if HR.Cast(S.MongooseBite) then return "mongoose_bite 791"; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsReadyP() then
      if HR.Cast(S.RaptorStrike) then return "raptor_strike 793"; end
    end
    -- serpent_sting,if=buff.vipers_venom.up
    if S.SerpentSting:IsReadyP() and (Player:BuffP(S.VipersVenomBuff)) then
      if HR.Cast(S.SerpentSting) then return "serpent_sting 795"; end
    end
    -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel
    if S.WildfireBomb:IsCastableP() and (S.VolatileBomb:IsLearned() and Target:DebuffP(S.SerpentStingDebuff) or S.PheromoneBomb:IsLearned() or S.ShrapnelBomb:IsLearned()) then
      if HR.Cast(S.WildfireBomb) then return "wildfire_bomb 799"; end
    end
  end
  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Self heal, if below setting value
    if S.Exhilaration:IsCastableP() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if HR.Cast(S.Exhilaration, Settings.Commons.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    Everyone.Interrupt(5, S.Muzzle, Settings.Survival.OffGCDasOffGCD.Muzzle, StunInterrupts);
    -- auto_attack
    -- use_items
    -- call_action_list,name=cds
    if (HR.CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apwfi,if=active_enemies<3&talent.chakrams.enabled&talent.alpha_predator.enabled
    if (Cache.EnemiesCount[8] < 3 and S.Chakrams:IsAvailable() and S.AlphaPredator:IsAvailable()) then
      local ShouldReturn = Apwfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=wfi,if=active_enemies<3&talent.chakrams.enabled
    if (Cache.EnemiesCount[8] < 3 and S.Chakrams:IsAvailable()) then
      local ShouldReturn = Wfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3&!talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    if (Cache.EnemiesCount[8] < 3 and not S.AlphaPredator:IsAvailable() and not S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apst,if=active_enemies<3&talent.alpha_predator.enabled&!talent.wildfire_infusion.enabled
    if (Cache.EnemiesCount[8] < 3 and S.AlphaPredator:IsAvailable() and not S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = Apst(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=apwfi,if=active_enemies<3&talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    if (Cache.EnemiesCount[8] < 3 and S.AlphaPredator:IsAvailable() and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = Apwfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=wfi,if=active_enemies<3&!talent.alpha_predator.enabled&talent.wildfire_infusion.enabled
    if (Cache.EnemiesCount[8] < 3 and not S.AlphaPredator:IsAvailable() and S.WildfireInfusion:IsAvailable()) then
      local ShouldReturn = Wfi(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1
    if (Cache.EnemiesCount[8] > 1) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Settings.Survival.GCDasOffGCD.Essences) then return "concentrated_flame 886"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 888"; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(187708, 8, 6)                           -- Carve
  HL.RegisterNucleusAbility(212436, 8, 6)                           -- Butchery
  HL.RegisterNucleusAbility({259495, 270335, 270323, 271045}, 8, 6) -- Bombs
  HL.RegisterNucleusAbility(259391, 40, 6)                          -- Chakrams
end

HR.SetAPL(255, APL, Init)

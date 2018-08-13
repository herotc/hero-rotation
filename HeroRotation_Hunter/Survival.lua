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
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  ArcaneTorrent                         = Spell(80483),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  -- Abilities
  Harpoon                               = Spell(190925),
  CoordinatedAssault                    = Spell(266779),
  KillCommand                           = Spell(259489),
  CoordinatedAssaultBuff                = Spell(266779),
  Carve                                 = Spell(187708),
  SerpentSting                          = Spell(259491),
  SerpentStingDebuff                    = Spell(259491),
  RaptorStrikeEagle                     = Spell(265189),
  RaptorStrike                          = Spell(186270),
  -- Pet
  CallPet                               = Spell(883),
  Intimidation                          = Spell(19577),
  MendPet                               = Spell(136),
  RevivePet                             = Spell(982),
  -- Talents
  SteelTrapDebuff                       = Spell(162487),
  SteelTrap                             = Spell(162488),
  AMurderofCrows                        = Spell(131894),
  PheromoneBomb                         = Spell(270323),
  VolatileBomb                          = Spell(271045),
  ShrapnelBomb                          = Spell(270335),
  ShrapnelBombDebuff                    = Spell(270339),
  WildfireBomb                          = Spell(259495),
  GuerrillaTactics                      = Spell(264332),
  WildfireBombDebuff                    = Spell(269747),
  Chakrams                              = Spell(259391),
  Butchery                              = Spell(212436),
  WildfireInfusion                      = Spell(271014),
  InternalBleedingDebuff                = Spell(270343),
  FlankingStrike                        = Spell(269751),
  VipersVenomBuff                       = Spell(268552),
  TermsofEngagement                     = Spell(265895),
  TipoftheSpearBuff                     = Spell(260286),
  MongooseBiteEagle                     = Spell(265888),
  MongooseBite                          = Spell(259387),
  BirdsofPrey                           = Spell(260331),
  MongooseFuryBuff                      = Spell(259388),
  VipersVenom                           = Spell(268501),
  -- Defensive
  AspectoftheTurtle                     = Spell(186265),
  Exhilaration                          = Spell(109304),
  -- Utility
  AspectoftheEagle                      = Spell(186289)
  -- Misc
};
local S = Spell.Hunter.Survival;

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.Survival = {
  ProlongedPower                   = Item(142117)
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

local EnemyRanges = {40, "Melee", 8}
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

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cds, Cleave, St, WfiSt
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- augmentation
    -- food
    -- call pet
    if not Pet:IsActive() then
      if HR.Cast(S.CallPet, Settings.Survival.GCDasOffGCD.CallPet) then return ""; end
    end
    -- Exhilaration
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Survival.ExhilarationHP then
      if HR.Cast(S.Exhilaration, Settings.Survival.OffGCDasOffGCD.Exhilaration) then return "Cast"; end
    end
    -- snapshot_stats
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() and Player:DebuffDownP(S.SteelTrapDebuff) and (true) then
      if HR.Cast(S.SteelTrap) then return ""; end
    end
    -- harpoon
    if not Target:IsInRange(5) and Target:IsInRange(40) and S.Harpoon:IsCastable() then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return ""; end
    end
  end
  Cds = function()
    if HR.CDsON() then
      -- berserking,if=cooldown.coordinated_assault.remains>30
      if S.Berserking:IsCastableP() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
        if HR.Cast(S.Berserking, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- blood_fury,if=cooldown.coordinated_assault.remains>30
      if S.BloodFury:IsCastableP() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
        if HR.Cast(S.BloodFury, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- ancestral_call,if=cooldown.coordinated_assault.remains>30
      if S.AncestralCall:IsCastableP() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
        if HR.Cast(S.AncestralCall) then return ""; end
      end
      -- fireblood,if=cooldown.coordinated_assault.remains>30
      if S.Fireblood:IsCastableP() and (S.CoordinatedAssault:CooldownRemainsP() > 30) then
        if HR.Cast(S.Fireblood, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastableP() and (true) then
        if HR.Cast(S.LightsJudgment) then return ""; end
      end
      -- arcane_torrent,if=cooldown.kill_command.remains>gcd.max&focus<=30
      if S.ArcaneTorrent:IsCastableP() and (S.KillCommand:CooldownRemainsP() > Player:GCD() and Player:Focus() <= 30) then
        if HR.Cast(S.ArcaneTorrent, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)
      if I.ProlongedPower:IsReady() and Settings.Survival.UsePotions and (Player:BuffP(S.CoordinatedAssaultBuff) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not Player:IsRace("Troll") and not Player:IsRace("Orc"))) then
        if HR.CastSuggested(I.ProlongedPower) then return ""; end
      end
      -- aspect_of_the_eagle,if=target.distance>=6
      if S.AspectoftheEagle:IsCastableP() and (not Target:IsInRange(6) and Target:IsInRange(40)) then
        if HR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
      end
    end
  end
  Cleave = function()
    -- variable,name=carve_cdr,op=setif,value=active_enemies,value_else=5,condition=active_enemies<5
    if (Cache.EnemiesCount["Melee"] < 5) then
      VarCarveCdr = Cache.EnemiesCount["Melee"]
    else
      VarCarveCdr = 5
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() and (true) then
      if HR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return ""; end
    end
    -- carve,if=dot.shrapnel_bomb.ticking
    if S.Carve:IsCastableP() and (Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.Carve) then return ""; end
    end
    -- wildfire_bomb,if=!talent.guerrilla_tactics.enabled|full_recharge_time<gcd
    if S.WildfireBomb:IsCastableP() and (not S.GuerrillaTactics:IsAvailable() or S.WildfireBomb:FullRechargeTimeP() < Player:GCD()) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
    -- chakrams
    if S.Chakrams:IsCastableP() and (true) then
      if HR.Cast(S.Chakrams) then return ""; end
    end
    -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.KillCommand) then return ""; end
    end
    -- butchery,if=full_recharge_time<gcd|!talent.wildfire_infusion.enabled|dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3
    if S.Butchery:IsCastableP() and (S.Butchery:FullRechargeTimeP() < Player:GCD() or not S.WildfireInfusion:IsAvailable() or Target:DebuffP(S.ShrapnelBombDebuff) and Target:DebuffStackP(S.InternalBleedingDebuff) < 3) then
      if HR.Cast(S.Butchery) then return ""; end
    end
    -- carve,if=talent.guerrilla_tactics.enabled
    if S.Carve:IsCastableP() and (S.GuerrillaTactics:IsAvailable()) then
      if HR.Cast(S.Carve) then return ""; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return ""; end
    end
    -- wildfire_bomb,if=dot.wildfire_bomb.refreshable|talent.wildfire_infusion.enabled
    if (S.WildfireBomb:IsCastableP() or S.VolatileBomb:IsCastableP() or S.ShrapnelBomb:IsCastableP() or S.PheromoneBomb:IsCastableP()) and (Target:DebuffRefreshableCP(S.WildfireBombDebuff) or S.WildfireInfusion:IsAvailable()) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
    -- serpent_sting,target_if=min:remains,if=buff.vipers_venom.up
    if S.SerpentSting:IsCastableP() and (Player:BuffP(S.VipersVenomBuff)) then
      if HR.Cast(S.SerpentSting) then return ""; end
    end
    -- carve,if=cooldown.wildfire_bomb.remains>variable.carve_cdr%2
    if S.Carve:IsCastableP() and (S.WildfireBomb:CooldownRemainsP() > VarCarveCdr / 2) then
      if HR.Cast(S.Carve) then return ""; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() and (true) then
      if HR.Cast(S.SteelTrap) then return ""; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return ""; end
    end
    -- serpent_sting,target_if=min:remains,if=refreshable&buff.tip_of_the_spear.stack<3
    if S.SerpentSting:IsCastableP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff) and Player:BuffStackP(S.TipoftheSpearBuff) < 3) then
      if HR.Cast(S.SerpentSting) then return ""; end
    end
    -- mongoose_bite_eagle
    if S.MongooseBiteEagle:IsCastableP() and Player:Buff(S.AspectoftheEagle) then
      if HR.Cast(S.MongooseBiteEagle) then return ""; end
    end
    -- mongoose_bite
    if S.MongooseBite:IsCastableP() and (true) then
      if HR.Cast(S.MongooseBite) then return ""; end
    end
    -- raptor_strike_eagle
    if S.RaptorStrikeEagle:IsCastableP() and Player:Buff(S.AspectoftheEagle) then
      if HR.Cast(S.RaptorStrikeEagle) then return ""; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsCastableP() and (true) then
      if HR.Cast(S.RaptorStrike) then return ""; end
    end
  end
  St = function()
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() and (true) then
      if HR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return ""; end
    end
    -- raptor_strike_eagle,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
    if S.RaptorStrikeEagle:IsCastableP() and (S.BirdsofPrey:IsAvailable() and Player:BuffP(S.CoordinatedAssaultBuff) and Player:BuffRemainsP(S.CoordinatedAssaultBuff) < Player:GCD()) then
      if HR.Cast(S.RaptorStrikeEagle) then return ""; end
    end
    -- raptor_strike,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
    if S.RaptorStrike:IsCastableP() and (S.BirdsofPrey:IsAvailable() and Player:BuffP(S.CoordinatedAssaultBuff) and Player:BuffRemainsP(S.CoordinatedAssaultBuff) < Player:GCD()) then
      if HR.Cast(S.RaptorStrike) then return ""; end
    end
    -- mongoose_bite_eagle,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
    if S.MongooseBiteEagle:IsCastableP() and (S.BirdsofPrey:IsAvailable() and Player:BuffP(S.CoordinatedAssaultBuff) and Player:BuffRemainsP(S.CoordinatedAssaultBuff) < Player:GCD()) then
      if HR.Cast(S.MongooseBiteEagle) then return ""; end
    end
    -- mongoose_bite,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
    if S.MongooseBite:IsCastableP() and (S.BirdsofPrey:IsAvailable() and Player:BuffP(S.CoordinatedAssaultBuff) and Player:BuffRemainsP(S.CoordinatedAssaultBuff) < Player:GCD()) then
      if HR.Cast(S.MongooseBite) then return ""; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and Player:BuffStackP(S.TipoftheSpearBuff) < 3) then
      if HR.Cast(S.KillCommand) then return ""; end
    end
    -- chakrams
    if S.Chakrams:IsCastableP() and (true) then
      if HR.Cast(S.Chakrams) then return ""; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() and (true) then
      if HR.Cast(S.SteelTrap) then return ""; end
    end
    -- wildfire_bomb,if=focus+cast_regen<focus.max&(full_recharge_time<gcd|dot.wildfire_bomb.refreshable&buff.mongoose_fury.down)
    if S.WildfireBomb:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() and (S.WildfireBomb:FullRechargeTimeP() < Player:GCD() or Target:DebuffRefreshableCP(S.WildfireBombDebuff) and Player:BuffDownP(S.MongooseFuryBuff))) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return ""; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return ""; end
    end
    -- serpent_sting,if=buff.vipers_venom.up|refreshable&(!talent.mongoose_bite.enabled&focus<90|!talent.vipers_venom.enabled)
    if S.SerpentSting:IsCastableP() and (Player:BuffP(S.VipersVenomBuff) or Target:DebuffRefreshableCP(S.SerpentStingDebuff) and (not S.MongooseBite:IsAvailable() and Player:Focus() < 90 or not S.VipersVenom:IsAvailable())) then
      if HR.Cast(S.SerpentSting) then return ""; end
    end
    -- mongoose_bite_eagle,if=buff.mongoose_fury.up|focus>60
    if S.MongooseBiteEagle:IsCastableP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60) then
      if HR.Cast(S.MongooseBiteEagle) then return ""; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus>60
    if S.MongooseBite:IsCastableP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60) then
      if HR.Cast(S.MongooseBite) then return ""; end
    end
    -- raptor_strike_eagle
    if S.RaptorStrikeEagle:IsCastableP() and (true) then
      if HR.Cast(S.RaptorStrikeEagle) then return ""; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsCastableP() and (true) then
      if HR.Cast(S.RaptorStrike) then return ""; end
    end
    -- wildfire_bomb,if=dot.wildfire_bomb.refreshable
    if S.WildfireBomb:IsCastableP() and (Target:DebuffRefreshableCP(S.WildfireBombDebuff)) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
    -- serpent_sting,if=refreshable
    if S.SerpentSting:IsCastableP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return ""; end
    end
  end
  WfiSt = function()
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() and (true) then
      if HR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- coordinated_assault
    if S.CoordinatedAssault:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault) then return ""; end
    end
    -- kill_command,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
    if S.KillCommand:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) < Player:FocusMax() and Player:BuffStackP(S.TipoftheSpearBuff) < 3) then
      if HR.Cast(S.KillCommand) then return ""; end
    end
    -- raptor_strike,if=dot.internal_bleeding.stack<3&dot.shrapnel_bomb.ticking&!talent.mongoose_bite.enabled
    if S.RaptorStrike:IsCastableP() and (Target:DebuffStackP(S.InternalBleedingDebuff) < 3 and Target:DebuffP(S.ShrapnelBombDebuff) and not S.MongooseBite:IsAvailable()) then
      if HR.Cast(S.RaptorStrike) then return ""; end
    end
    -- wildfire_bomb,if=full_recharge_time<gcd|(focus+cast_regen<focus.max)&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
    if (S.WildfireBomb:FullRechargeTimeP() < Player:GCD() or (Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax()) and ((S.VolatileBomb:IsCastableP() and Target:DebuffP(S.SerpentStingDebuff) and Target:DebuffRefreshableCP(S.SerpentStingDebuff)) or (S.PheromoneBomb:IsCastableP() and Player:Focus() + Player:FocusCastRegen(S.WildfireBomb:ExecuteTime()) < Player:FocusMax() - Player:FocusCastRegen(S.KillCommand:ExecuteTime()) * 3))) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
    -- wildfire_bomb,if=next_wi_bomb.shrapnel&buff.mongoose_fury.down&(cooldown.kill_command.remains>gcd|focus>60)
    if (S.ShrapnelBomb:IsCastableP() and Player:BuffDownP(S.MongooseFuryBuff) and (S.KillCommand:CooldownRemainsP() > Player:GCD() or Player:Focus() > 60)) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
    -- steel_trap
    if S.SteelTrap:IsCastableP() and (true) then
      if HR.Cast(S.SteelTrap) then return ""; end
    end
    -- flanking_strike,if=focus+cast_regen<focus.max
    if S.FlankingStrike:IsCastableP() and (Player:Focus() + Player:FocusCastRegen(S.FlankingStrike:ExecuteTime()) < Player:FocusMax()) then
      if HR.Cast(S.FlankingStrike) then return ""; end
    end
    -- serpent_sting,if=buff.vipers_venom.up|refreshable&(!talent.mongoose_bite.enabled|next_wi_bomb.volatile&!dot.shrapnel_bomb.ticking)
    if S.SerpentSting:IsCastableP() and (Player:BuffP(S.VipersVenomBuff) or Target:DebuffRefreshableCP(S.SerpentStingDebuff) and (not S.MongooseBite:IsAvailable() or S.VolatileBomb:IsCastableP() and not Target:DebuffP(S.ShrapnelBombDebuff))) then
      if HR.Cast(S.SerpentSting) then return ""; end
    end
    -- harpoon,if=talent.terms_of_engagement.enabled
    if S.Harpoon:IsCastableP() and (S.TermsofEngagement:IsAvailable()) then
      if HR.Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon) then return ""; end
    end
    -- mongoose_bite_eagle,if=buff.mongoose_fury.up|focus>60|dot.shrapnel_bomb.ticking
    if S.MongooseBiteEagle:IsCastableP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60 or Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.MongooseBiteEagle) then return ""; end
    end
    -- mongoose_bite,if=buff.mongoose_fury.up|focus>60|dot.shrapnel_bomb.ticking
    if S.MongooseBite:IsCastableP() and (Player:BuffP(S.MongooseFuryBuff) or Player:Focus() > 60 or Target:DebuffP(S.ShrapnelBombDebuff)) then
      if HR.Cast(S.MongooseBite) then return ""; end
    end
    -- raptor_strike_eagle
    if S.RaptorStrikeEagle:IsCastableP() and (true) then
      if HR.Cast(S.RaptorStrikeEagle) then return ""; end
    end
    -- raptor_strike
    if S.RaptorStrike:IsCastableP() and (true) then
      if HR.Cast(S.RaptorStrike) then return ""; end
    end
    -- serpent_sting,if=refreshable
    if S.SerpentSting:IsCastableP() and (Target:DebuffRefreshableCP(S.SerpentStingDebuff)) then
      if HR.Cast(S.SerpentSting) then return ""; end
    end
    -- wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50
    if (S.VolatileBomb:IsCastableP() and Target:DebuffP(S.SerpentStingDebuff) or S.PheromoneBomb:IsCastableP() or S.ShrapnelBomb:IsCastableP() and Player:Focus() > 50) then
      if HR.Cast(S.WildfireBomb) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if not Everyone.TargetIsValid() then
    return
  end
  -- auto_attack
  -- use_items
  -- call_action_list,name=cds
  if (true) then
    local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=wfi_st,if=active_enemies<2&talent.wildfire_infusion.enabled
  if (Cache.EnemiesCount[8] < 2 and S.WildfireInfusion:IsAvailable()) then
    local ShouldReturn = WfiSt(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=st,if=active_enemies<2&!talent.wildfire_infusion.enabled
  if (Cache.EnemiesCount[8] < 2 and not S.WildfireInfusion:IsAvailable()) then
    local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=cleave,if=active_enemies>1
  if (Cache.EnemiesCount[8] > 1) then
    local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
  end
  -- heal pet
  if Pet:IsActive() and Pet:HealthPercentage() <= 75 and not Pet:Buff(S.MendPet) then
    if HR.Cast(S.MendPet, Settings.Survival.GCDasOffGCD.MendPet) then return ""; end
  end
end

HR.SetAPL(255, APL)


--- Last Update: 08/12/2018

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/use_items
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=wfi_st,if=active_enemies<2&talent.wildfire_infusion.enabled
-- actions+=/call_action_list,name=st,if=active_enemies<2&!talent.wildfire_infusion.enabled
-- actions+=/call_action_list,name=cleave,if=active_enemies>1

-- actions.cds=berserking,if=cooldown.coordinated_assault.remains>30
-- actions.cds+=/blood_fury,if=cooldown.coordinated_assault.remains>30
-- actions.cds+=/ancestral_call,if=cooldown.coordinated_assault.remains>30
-- actions.cds+=/fireblood,if=cooldown.coordinated_assault.remains>30
-- actions.cds+=/lights_judgment
-- actions.cds+=/arcane_torrent,if=cooldown.kill_command.remains>gcd.max&focus<=30
-- actions.cds+=/potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)
-- actions.cds+=/aspect_of_the_eagle,if=target.distance>=6

-- actions.cleave=variable,name=carve_cdr,op=setif,value=active_enemies,value_else=5,condition=active_enemies<5
-- actions.cleave+=/a_murder_of_crows
-- actions.cleave+=/coordinated_assault
-- actions.cleave+=/carve,if=dot.shrapnel_bomb.ticking
-- actions.cleave+=/wildfire_bomb,if=!talent.guerrilla_tactics.enabled|full_recharge_time<gcd
-- actions.cleave+=/chakrams
-- actions.cleave+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
-- actions.cleave+=/butchery,if=full_recharge_time<gcd|!talent.wildfire_infusion.enabled|dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3
-- actions.cleave+=/carve,if=talent.guerrilla_tactics.enabled
-- actions.cleave+=/flanking_strike,if=focus+cast_regen<focus.max
-- actions.cleave+=/wildfire_bomb,if=dot.wildfire_bomb.refreshable|talent.wildfire_infusion.enabled
-- actions.cleave+=/serpent_sting,target_if=min:remains,if=buff.vipers_venom.up
-- actions.cleave+=/carve,if=cooldown.wildfire_bomb.remains>variable.carve_cdr%2
-- actions.cleave+=/steel_trap
-- actions.cleave+=/harpoon,if=talent.terms_of_engagement.enabled
-- actions.cleave+=/serpent_sting,target_if=min:remains,if=refreshable&buff.tip_of_the_spear.stack<3
-- actions.cleave+=/mongoose_bite_eagle
-- actions.cleave+=/mongoose_bite
-- actions.cleave+=/raptor_strike_eagle
-- actions.cleave+=/raptor_strike

-- actions.st=a_murder_of_crows
-- actions.st+=/coordinated_assault
-- actions.st+=/raptor_strike_eagle,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
-- actions.st+=/raptor_strike,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
-- actions.st+=/mongoose_bite_eagle,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
-- actions.st+=/mongoose_bite,if=talent.birds_of_prey.enabled&buff.coordinated_assault.up&buff.coordinated_assault.remains<gcd
-- actions.st+=/kill_command,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
-- actions.st+=/chakrams
-- actions.st+=/steel_trap
-- actions.st+=/wildfire_bomb,if=focus+cast_regen<focus.max&(full_recharge_time<gcd|dot.wildfire_bomb.refreshable&buff.mongoose_fury.down)
-- actions.st+=/harpoon,if=talent.terms_of_engagement.enabled
-- actions.st+=/flanking_strike,if=focus+cast_regen<focus.max
-- actions.st+=/serpent_sting,if=buff.vipers_venom.up|refreshable&(!talent.mongoose_bite.enabled&focus<90|!talent.vipers_venom.enabled)
-- actions.st+=/mongoose_bite_eagle,if=buff.mongoose_fury.up|focus>60
-- actions.st+=/mongoose_bite,if=buff.mongoose_fury.up|focus>60
-- actions.st+=/raptor_strike_eagle
-- actions.st+=/raptor_strike
-- actions.st+=/wildfire_bomb,if=dot.wildfire_bomb.refreshable
-- actions.st+=/serpent_sting,if=refreshable

-- actions.wfi_st=a_murder_of_crows
-- actions.wfi_st+=/coordinated_assault
-- actions.wfi_st+=/kill_command,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
-- actions.wfi_st+=/raptor_strike,if=dot.internal_bleeding.stack<3&dot.shrapnel_bomb.ticking&!talent.mongoose_bite.enabled
-- actions.wfi_st+=/wildfire_bomb,if=full_recharge_time<gcd|(focus+cast_regen<focus.max)&(next_wi_bomb.volatile&dot.serpent_sting.ticking&dot.serpent_sting.refreshable|next_wi_bomb.pheromone&focus+cast_regen<focus.max-action.kill_command.cast_regen*3)
-- actions.wfi_st+=/wildfire_bomb,if=next_wi_bomb.shrapnel&buff.mongoose_fury.down&(cooldown.kill_command.remains>gcd|focus>60)
-- actions.wfi_st+=/steel_trap
-- actions.wfi_st+=/flanking_strike,if=focus+cast_regen<focus.max
-- actions.wfi_st+=/serpent_sting,if=buff.vipers_venom.up|refreshable&(!talent.mongoose_bite.enabled|next_wi_bomb.volatile&!dot.shrapnel_bomb.ticking)
-- actions.wfi_st+=/harpoon,if=talent.terms_of_engagement.enabled
-- actions.wfi_st+=/mongoose_bite_eagle,if=buff.mongoose_fury.up|focus>60|dot.shrapnel_bomb.ticking
-- actions.wfi_st+=/mongoose_bite,if=buff.mongoose_fury.up|focus>60|dot.shrapnel_bomb.ticking
-- actions.wfi_st+=/raptor_strike_eagle
-- actions.wfi_st+=/raptor_strike
-- actions.wfi_st+=/serpent_sting,if=refreshable
-- actions.wfi_st+=/wildfire_bomb,if=next_wi_bomb.volatile&dot.serpent_sting.ticking|next_wi_bomb.pheromone|next_wi_bomb.shrapnel&focus>50

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
Spell.Hunter.BeastMastery = {
  SummonPet                             = Spell(883),
  AspectoftheWildBuff                   = Spell(193530),
  AspectoftheWild                       = Spell(193530),
  PrimalInstinctsBuff                   = Spell(279810),
  PrimalInstincts                       = Spell(279806),
  BestialWrathBuff                      = Spell(19574),
  BestialWrath                          = Spell(19574),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  KillerInstinct                        = Spell(273887),
  BarbedShot                            = Spell(217200),
  FrenzyBuff                            = Spell(272790),
  LightsJudgment                        = Spell(255647),
  SpittingCobra                         = Spell(194407),
  AMurderofCrows                        = Spell(131894),
  Stampede                              = Spell(201430),
  Multishot                             = Spell(2643),
  BeastCleaveBuff                       = Spell(118455, "pet"),
  Barrage                               = Spell(120360),
  ChimaeraShot                          = Spell(53209),
  KillCommand                           = Spell(34026),
  DireBeast                             = Spell(120679),
  CobraShot                             = Spell(193455),
  ArcaneTorrent                         = Spell(50613)
};
local S = Spell.Hunter.BeastMastery;

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.BeastMastery = {
  BattlePotionofAgility            = Item(163223)
};
local I = Item.Hunter.BeastMastery;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  BeastMastery = HR.GUISettings.APL.Hunter.BeastMastery
};


local EnemyRanges = {40}
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
  local Precombat
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- augmentation
    -- food
    -- summon_pet
    if S.SummonPet:IsCastableP() then
      if HR.Cast(S.SummonPet, Settings.BeastMastery.GCDasOffGCD.SummonPet) then return "summon_pet 3"; end
    end
    -- snapshot_stats
    -- potion
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 6"; end
    end
    -- aspect_of_the_wild,precast_time=1.1,if=!azerite.primal_instincts.enabled
    if S.AspectoftheWild:IsCastableP() and Player:BuffDownP(S.AspectoftheWildBuff) and (not S.PrimalInstincts:AzeriteEnabled()) then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 8"; end
    end
    -- bestial_wrath,precast_time=1.5,if=azerite.primal_instincts.enabled
    if S.BestialWrath:IsCastableP() and Player:BuffDownP(S.BestialWrathBuff) and (S.PrimalInstincts:AzeriteEnabled()) then
      if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 16"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- auto_shot
    -- use_items
    -- berserking,if=cooldown.bestial_wrath.remains>30
    if S.Berserking:IsCastableP() and HR.CDsON() and (S.BestialWrath:CooldownRemainsP() > 30) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 27"; end
    end
    -- blood_fury,if=cooldown.bestial_wrath.remains>30
    if S.BloodFury:IsCastableP() and HR.CDsON() and (S.BestialWrath:CooldownRemainsP() > 30) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 31"; end
    end
    -- ancestral_call,if=cooldown.bestial_wrath.remains>30
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (S.BestialWrath:CooldownRemainsP() > 30) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 35"; end
    end
    -- fireblood,if=cooldown.bestial_wrath.remains>30
    if S.Fireblood:IsCastableP() and HR.CDsON() and (S.BestialWrath:CooldownRemainsP() > 30) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 39"; end
    end
    -- potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up&(target.health.pct<35|!talent.killer_instinct.enabled)|target.time_to_die<25
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.BestialWrathBuff) and Player:BuffP(S.AspectoftheWildBuff) and (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable()) or Target:TimeToDie() < 25) then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 43"; end
    end
    -- barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max|full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
    if S.BarbedShot:IsCastableP() and (Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) <= Player:GCD() or S.BarbedShot:FullRechargeTimeP() < Player:GCD() and bool(S.BestialWrath:CooldownRemainsP())) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 51"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 63"; end
    end
    -- spitting_cobra
    if S.SpittingCobra:IsCastableP() then
      if HR.Cast(S.SpittingCobra, Settings.BeastMastery.GCDasOffGCD.SpittingCobra) then return "spitting_cobra 65"; end
    end
    -- aspect_of_the_wild
    if S.AspectoftheWild:IsCastableP() then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 67"; end
    end
    -- a_murder_of_crows,if=active_enemies=1
    if S.AMurderofCrows:IsCastableP() and (Cache.EnemiesCount[40] == 1) then
      if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 69"; end
    end
    -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
    if S.Stampede:IsCastableP() and (Player:BuffP(S.AspectoftheWildBuff) and Player:BuffP(S.BestialWrathBuff) or Target:TimeToDie() < 15) then
      if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede) then return "stampede 77"; end
    end
    -- multishot,if=spell_targets>2&gcd.max-pet.cat.buff.beast_cleave.remains>0.25
    if S.Multishot:IsCastableP() and (Cache.EnemiesCount[40] > 2 and Player:GCD() - Pet:BuffRemainsP(S.BeastCleaveBuff) > 0.25) then
      if HR.Cast(S.Multishot) then return "multishot 83"; end
    end
    -- bestial_wrath,if=cooldown.aspect_of_the_wild.remains>20|target.time_to_die<15
    if S.BestialWrath:IsCastableP() and (S.AspectoftheWild:CooldownRemainsP() > 20 or Target:TimeToDie() < 15) then
      if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 93"; end
    end
    -- barrage,if=active_enemies>1
    if S.Barrage:IsReadyP() and (Cache.EnemiesCount[40] > 1) then
      if HR.Cast(S.Barrage) then return "barrage 97"; end
    end
    -- chimaera_shot,if=spell_targets>1
    if S.ChimaeraShot:IsCastableP() and (Cache.EnemiesCount[40] > 1) then
      if HR.Cast(S.ChimaeraShot) then return "chimaera_shot 105"; end
    end
    -- multishot,if=spell_targets>1&gcd.max-pet.cat.buff.beast_cleave.remains>0.25
    if S.Multishot:IsCastableP() and (Cache.EnemiesCount[40] > 1 and Player:GCD() - Pet:BuffRemainsP(S.BeastCleaveBuff) > 0.25) then
      if HR.Cast(S.Multishot) then return "multishot 113"; end
    end
    -- kill_command
    if S.KillCommand:IsCastableP() then
      if HR.Cast(S.KillCommand) then return "kill_command 123"; end
    end
    -- chimaera_shot
    if S.ChimaeraShot:IsCastableP() then
      if HR.Cast(S.ChimaeraShot) then return "chimaera_shot 125"; end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 127"; end
    end
    -- dire_beast
    if S.DireBeast:IsCastableP() then
      if HR.Cast(S.DireBeast) then return "dire_beast 129"; end
    end
    -- barbed_shot,if=pet.cat.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<6&azerite.primal_instincts.enabled|target.time_to_die<9
    if S.BarbedShot:IsCastableP() and (Pet:BuffDownP(S.FrenzyBuff) and (S.BarbedShot:ChargesFractionalP() > 1.8 or Player:BuffP(S.BestialWrathBuff)) or S.AspectoftheWild:CooldownRemainsP() < 6 and S.PrimalInstincts:AzeriteEnabled() or Target:TimeToDie() < 9) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 131"; end
    end
    -- barrage
    if S.Barrage:IsReadyP() then
      if HR.Cast(S.Barrage) then return "barrage 145"; end
    end
    -- cobra_shot,if=(active_enemies<2|cooldown.kill_command.remains>focus.time_to_max)&(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd)&cooldown.kill_command.remains>1
    if S.CobraShot:IsCastableP() and ((Cache.EnemiesCount[40] < 2 or S.KillCommand:CooldownRemainsP() > Player:FocusTimeToMaxPredicted()) and (Player:Focus() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemainsP() - 1) > S.KillCommand:Cost() or S.KillCommand:CooldownRemainsP() > 1 + Player:GCD()) and S.KillCommand:CooldownRemainsP() > 1) then
      if HR.Cast(S.CobraShot) then return "cobra_shot 147"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 171"; end
    end
  end
end

HR.SetAPL(253, APL)

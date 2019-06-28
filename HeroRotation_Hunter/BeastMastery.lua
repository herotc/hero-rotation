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
Spell.Hunter.BeastMastery = {
  SummonPet                             = Spell(883),
  AspectoftheWildBuff                   = Spell(193530),
  AspectoftheWild                       = Spell(193530),
  PrimalInstinctsBuff                   = Spell(279810),
  PrimalInstincts                       = Spell(279806),
  BestialWrathBuff                      = Spell(19574),
  BestialWrath                          = Spell(19574),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  Berserking                            = Spell(26297),
  BerserkingBuff                        = Spell(26297),
  KillerInstinct                        = Spell(273887),
  BloodFury                             = Spell(20572),
  BloodFuryBuff                         = Spell(20572),
  LightsJudgment                        = Spell(255647),
  FrenzyBuff                            = Spell(272790),
  BarbedShot                            = Spell(217200),
  Multishot                             = Spell(2643),
  BeastCleaveBuff                       = Spell(118455, "pet"),
  Stampede                              = Spell(201430),
  ChimaeraShot                          = Spell(53209),
  AMurderofCrows                        = Spell(131894),
  Barrage                               = Spell(120360),
  KillCommand                           = Spell(34026),
  RapidReload                           = Spell(278530),
  DireBeast                             = Spell(120679),
  CobraShot                             = Spell(193455),
  SpittingCobra                         = Spell(194407),
  Intimidation                          = Spell(19577),
  CounterShot                           = Spell(147362),
  Exhilaration                          = Spell(109304),
  -- Essences
  BloodOfTheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryOfLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianOfAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForce                         = Spell(302932),
  -- Misc
  PoolFocus                             = Spell(9999000010),
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
local EnemiesCount, GCDMax;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  BeastMastery = HR.GUISettings.APL.Hunter.BeastMastery
};

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
};

local EnemyRanges = {40}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.BeastMastery.UseSplashData then
      HL.GetEnemies(range, nil, true, Target)
      return Cache.EnemiesCount[range]
    else
      UpdateRanges()
      Everyone.AoEToggleEnemiesUpdate()
      return Cache.EnemiesCount[40]
    end
  else
    return 1
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- Register Splash Data Nucleus Abilities
HL.RegisterNucleusAbility(2643, 8, 6)               -- Multi-Shot
HL.RegisterNucleusAbility(194392, 8, 6)             -- Volley
HL.RegisterNucleusAbility({171454, 171457}, 8, 6)   -- Chimaera Shot
HL.RegisterNucleusAbility(118459, 10, 6)            -- Beast Cleave
HL.RegisterNucleusAbility(201754, 10, 6)            -- Stomp
HL.RegisterNucleusAbility(271686, 3, 6)             -- Head My Call

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cds, Cleave, St

  -- GCD Max + Latency Grace Period
  -- BM APL uses a lot of gcd.max specific timing that is slightly tight for real-world suggestions
  GCDMax = Player:GCD() + 0.150
  EnemiesCount = GetEnemiesCount(8)

  Precombat = function()
    -- flask
    -- augmentation
    -- food
    -- summon_pet
    if S.SummonPet:IsCastableP() then
      if HR.Cast(S.SummonPet, Settings.BeastMastery.GCDasOffGCD.SummonPet) then return "summon_pet 3"; end
    end
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 6"; end
      end
      -- worldvein_resonance
      if S.WorldveinResonance:IsCastableP() then
        if HR.Cast(S.WorldveinResonance, Settings.BeastMastery.GCDasOffGCD.Essences) then return "worldvein_resonance"; end
      end
      -- guardian_of_azeroth
      if S.GuardianOfAzeroth:IsCastableP() then
        if HR.Cast(S.GuardianOfAzeroth, Settings.BeastMastery.GCDasOffGCD.Essences) then return "guardian_of_azeroth"; end
      end
      -- memory_of_lucid_dreams
      if S.MemoryOfLucidDreams:IsCastableP() then
        if HR.Cast(S.MemoryOfLucidDreams, Settings.BeastMastery.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams"; end
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
  end
  Cds = function()
    -- ancestral_call,if=cooldown.bestial_wrath.remains>30
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (S.BestialWrath:CooldownRemainsP() > 30) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 24"; end
    end
    -- fireblood,if=cooldown.bestial_wrath.remains>30
    if S.Fireblood:IsCastableP() and HR.CDsON() and (S.BestialWrath:CooldownRemainsP() > 30) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 28"; end
    end
    -- berserking,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<13
    if S.Berserking:IsCastableP() and HR.CDsON() and (Player:BuffP(S.AspectoftheWildBuff) and (Target:TimeToDie() > S.Berserking:BaseDuration() + S.BerserkingBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 13) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 32"; end
    end
    -- blood_fury,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<16
    if S.BloodFury:IsCastableP() and HR.CDsON() and (Player:BuffP(S.AspectoftheWildBuff) and (Target:TimeToDie() > S.BloodFury:BaseDuration() + S.BloodFuryBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 16) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 46"; end
    end
    -- lights_judgment,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains>gcd.max|!pet.cat.buff.frenzy.up
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) > GCDMax or not Pet:BuffP(S.FrenzyBuff)) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 60"; end
    end
    -- potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up&(target.health.pct<35|!talent.killer_instinct.enabled)|target.time_to_die<25
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.BestialWrathBuff) and Player:BuffP(S.AspectoftheWildBuff) and (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable()) or Target:TimeToDie() < 25) then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 68"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance, Settings.BeastMastery.GCDasOffGCD.Essences) then return "worldvein_resonance"; end
    end
    -- guardian_of_azeroth
    if S.GuardianOfAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianOfAzeroth, Settings.BeastMastery.GCDasOffGCD.Essences) then return "guardian_of_azeroth"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.MemoryOfLucidDreams, Settings.BeastMastery.GCDasOffGCD.Essences) then return "ripple_in_space"; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryOfLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryOfLucidDreams, Settings.BeastMastery.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams"; end
    end
  end
  Cleave = function()
    -- barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max
    if S.BarbedShot:IsCastableP() and (Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) <= GCDMax) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 76"; end
    end
    -- multishot,if=gcd.max-pet.cat.buff.beast_cleave.remains>0.25
    if S.Multishot:IsCastableP() and (GCDMax - Pet:BuffRemainsP(S.BeastCleaveBuff) > 0.25) then
      if HR.Cast(S.Multishot) then return "multishot 82"; end
    end
    -- barbed_shot,if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
    if S.BarbedShot:IsCastableP() and (S.BarbedShot:FullRechargeTimeP() < GCDMax and bool(S.BestialWrath:CooldownRemainsP())) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 86"; end
    end
    -- aspect_of_the_wild
    if S.AspectoftheWild:IsCastableP() then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 94"; end
    end
    -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
    if S.Stampede:IsCastableP() and (Player:BuffP(S.AspectoftheWildBuff) and Player:BuffP(S.BestialWrathBuff) or Target:TimeToDie() < 15) then
      if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede) then return "stampede 96"; end
    end
    -- bestial_wrath,if=cooldown.aspect_of_the_wild.remains>20|target.time_to_die<15
    if S.BestialWrath:IsCastableP() and (S.AspectoftheWild:CooldownRemainsP() > 20 or Target:TimeToDie() < 15) then
      if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 102"; end
    end
    -- chimaera_shot
    if S.ChimaeraShot:IsCastableP() then
      if HR.Cast(S.ChimaeraShot) then return "chimaera_shot 106"; end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 108"; end
    end
    -- barrage
    if S.Barrage:IsReadyP() then
      if HR.Cast(S.Barrage) then return "barrage 110"; end
    end
    -- kill_command,if=active_enemies<4|!azerite.rapid_reload.enabled
    if S.KillCommand:IsCastableP() and (EnemiesCount < 4 or not S.RapidReload:AzeriteEnabled()) then
      if HR.Cast(S.KillCommand) then return "kill_command 112"; end
    end
    -- dire_beast
    if S.DireBeast:IsCastableP() then
      if HR.Cast(S.DireBeast) then return "dire_beast 122"; end
    end
    -- barbed_shot,if=pet.cat.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.cat.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|target.time_to_die<9
    if S.BarbedShot:IsCastableP() and (Pet:BuffDownP(S.FrenzyBuff) and (S.BarbedShot:ChargesFractionalP() > 1.8 or Player:BuffP(S.BestialWrathBuff)) or S.AspectoftheWild:CooldownRemainsP() < S.FrenzyBuff:BaseDuration() - GCDMax and S.PrimalInstincts:AzeriteEnabled() or Target:TimeToDie() < 9) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 124"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- blood_of_the_enemy
    if S.BloodOfTheEnemy:IsCastableP() then
      if HR.Cast(S.BloodOfTheEnemy, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- multishot,if=azerite.rapid_reload.enabled&active_enemies>2
    if S.Multishot:IsCastableP() and (S.RapidReload:AzeriteEnabled() and EnemiesCount > 2) then
      if HR.Cast(S.Multishot) then return "multishot 140"; end
    end
    -- cobra_shot,if=cooldown.kill_command.remains>focus.time_to_max&(active_enemies<3|!azerite.rapid_reload.enabled)
    if S.CobraShot:IsCastableP() and (S.KillCommand:CooldownRemainsP() > Player:FocusTimeToMaxPredicted() and (EnemiesCount < 3 or not S.RapidReload:AzeriteEnabled())) then
      if HR.Cast(S.CobraShot) then return "cobra_shot 150"; end
    end
    -- spitting_cobra
    if S.SpittingCobra:IsCastableP() then
      if HR.Cast(S.SpittingCobra, Settings.BeastMastery.GCDasOffGCD.SpittingCobra) then return "spitting_cobra 162"; end
    end
  end
  St = function()
    -- barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max|full_recharge_time<gcd.max&cooldown.bestial_wrath.remains|azerite.primal_instincts.enabled&cooldown.aspect_of_the_wild.remains<gcd
    if S.BarbedShot:IsCastableP() and (Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) <= GCDMax or S.BarbedShot:FullRechargeTimeP() < GCDMax and bool(S.BestialWrath:CooldownRemainsP()) or S.PrimalInstincts:AzeriteEnabled() and S.AspectoftheWild:CooldownRemainsP() < GCDMax) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 164"; end
    end
    -- aspect_of_the_wild
    if S.AspectoftheWild:IsCastableP() then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 180"; end
    end
    -- a_murder_of_crows
    if S.AMurderofCrows:IsCastableP() then
      if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 182"; end
    end
    -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
    if S.Stampede:IsCastableP() and (Player:BuffP(S.AspectoftheWildBuff) and Player:BuffP(S.BestialWrathBuff) or Target:TimeToDie() < 15) then
      if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede) then return "stampede 184"; end
    end
    -- bestial_wrath,if=cooldown.aspect_of_the_wild.remains>20|target.time_to_die<15
    if S.BestialWrath:IsCastableP() and (S.AspectoftheWild:CooldownRemainsP() > 20 or Target:TimeToDie() < 15) then
      if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 190"; end
    end
    -- kill_command
    if S.KillCommand:IsCastableP() then
      if HR.Cast(S.KillCommand) then return "kill_command 194"; end
    end
    -- chimaera_shot
    if S.ChimaeraShot:IsCastableP() then
      if HR.Cast(S.ChimaeraShot) then return "chimaera_shot 196"; end
    end
    -- dire_beast
    if S.DireBeast:IsCastableP() then
      if HR.Cast(S.DireBeast) then return "dire_beast 198"; end
    end
    -- barbed_shot,if=pet.cat.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.cat.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|target.time_to_die<9
    if S.BarbedShot:IsCastableP() and (Pet:BuffDownP(S.FrenzyBuff) and (S.BarbedShot:ChargesFractionalP() > 1.8 or Player:BuffP(S.BestialWrathBuff)) or S.AspectoftheWild:CooldownRemainsP() < S.FrenzyBuff:BaseDuration() - GCDMax and S.PrimalInstincts:AzeriteEnabled() or Target:TimeToDie() < 9) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 200"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- blood_of_the_enemy
    if S.BloodOfTheEnemy:IsCastableP() then
      if HR.Cast(S.BloodOfTheEnemy, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, Setting.BeastMastery.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- barrage
    if S.Barrage:IsReadyP() then
      if HR.Cast(S.Barrage) then return "barrage 216"; end
    end
    -- Special pooling line for HeroRotation -- negiligible effective DPS loss (0.1%), but better for prediction accounting for latency
    -- Avoids cases where Cobra Shot would be suggested but the GCD of Cobra Shot + latency would allow Barbed Shot to fall off
    -- wait,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max*2&focus.time_to_max>gcd.max*2
    if Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) <= GCDMax * 2 and Player:FocusTimeToMaxPredicted() > GCDMax * 2 then
      if HR.Cast(S.PoolFocus) then return "Barbed Shot Pooling"; end
    end
    -- cobra_shot,if=(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd|buff.memory_of_lucid_dreams.up)&cooldown.kill_command.remains>1
    if S.CobraShot:IsCastableP() and ((Player:Focus() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemainsP() - 1) > S.KillCommand:Cost() or S.KillCommand:CooldownRemainsP() > 1 + GCDMax or Player:BuffP(S.MemoryOfLucidDreams)) and S.KillCommand:CooldownRemainsP() > 1) then
      if HR.Cast(S.CobraShot) then return "cobra_shot 218"; end
    end
    -- spitting_cobra
    if S.SpittingCobra:IsCastableP() then
      if HR.Cast(S.SpittingCobra, Settings.BeastMastery.GCDasOffGCD.SpittingCobra) then return "spitting_cobra 234"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Self heal, if below setting value
    if S.Exhilaration:IsCastableP() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if HR.Cast(S.Exhilaration, Settings.Commons.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    Everyone.Interrupt(40, S.CounterShot, Settings.Commons.OffGCDasOffGCD.CounterShot, StunInterrupts);
    -- auto_shot
    -- use_items
    -- call_action_list,name=cds
    if (true) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<2
    if (EnemiesCount < 2) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1
    if (EnemiesCount > 1) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    if HR.Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

HR.SetAPL(253, APL)

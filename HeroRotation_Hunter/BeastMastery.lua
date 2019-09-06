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
  OneWithThePack                        = Spell(199528),
  Intimidation                          = Spell(19577),
  CounterShot                           = Spell(147362),
  Exhilaration                          = Spell(109304),
  RazorCoralDebuff                      = Spell(303568),
  DanceofDeath                          = Spell(274441),
  DanceofDeathBuff                      = Spell(274443),
  -- Essences
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  RecklessForceCounter                  = MultiSpell(298409, 302917),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  -- Misc
  PoolFocus                             = Spell(9999000010),
};
local S = Spell.Hunter.BeastMastery;

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.BeastMastery = {
  PotionofUnbridledFury            = Item(169299),
  AshvanesRazorCoral               = Item(169311),
  PocketsizedComputationDevice     = Item(167555),
  AzsharasFontofPower              = Item(169314)
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

S.ConcentratedFlame:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateTargetIfFilterBarbedShot74(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.BarbedShot)
end

local function EvaluateTargetIfBarbedShot75(TargetUnit)
  return (Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) <= Player:GCD() + 0.150)
end

local function EvaluateTargetIfBarbedShot85(TargetUnit)
  return (S.BarbedShot:FullRechargeTimeP() < Player:GCD() + 0.150 and bool(S.BestialWrath:CooldownRemainsP()))
end

local function EvaluateTargetIfBarbedShot123(TargetUnit)
  return (Pet:BuffDownP(S.FrenzyBuff) and (S.BarbedShot:ChargesFractionalP() > 1.8 or Player:BuffP(S.BestialWrathBuff)) or S.AspectoftheWild:CooldownRemainsP() < S.FrenzyBuff:BaseDuration() - Player:GCD() + 0.150 and S.PrimalInstincts:AzeriteEnabled() or S.BarbedShot:ChargesFractionalP() > 1.4 or Target:TimeToDie() < 9)
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cds, Cleave, St

  -- GCD Max + Latency Grace Period
  -- BM APL uses a lot of gcd.max specific timing that is slightly tight for real-world suggestions
  GCDMax = Player:GCD() + 0.150
  EnemiesCount = GetEnemiesCount(8)
  HL.GetEnemies(40) -- To populate Cache.Enemies[40] for CastCycles

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
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_agility 6"; end
      end
      -- use_item,name=azsharas_font_of_power
      if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power"; end
      end
      -- worldvein_resonance
      if S.WorldveinResonance:IsCastableP() then
        if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
      end
      -- guardian_of_azeroth
      if S.GuardianofAzeroth:IsCastableP() then
        if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
      end
      -- memory_of_lucid_dreams
      if S.MemoryofLucidDreams:IsCastableP() then
        if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
      end
      -- use_item,effect_name=cyclotronic_blast,if=!raid_event.invulnerable.exists&(trinket.1.has_cooldown+trinket.2.has_cooldown<2|equipped.variable_intensity_gigavolt_oscillating_reactor)
      -- Needs to be updated to the 2nd half of the condition
      if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "cyclotronic_blast precombat"; end
      end
      -- focused_azerite_beam,if=!raid_event.invulnerable.exists
      if S.FocusedAzeriteBeam:IsCastableP() then
        if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
      end
      -- aspect_of_the_wild,precast_time=1.1,if=!azerite.primal_instincts.enabled&!essence.essence_of_the_focusing_iris.major&(equipped.azsharas_font_of_power|!equipped.cyclotronic_blast)
      if S.AspectoftheWild:IsCastableP() and (not S.PrimalInstincts:AzeriteEnabled() and not S.FocusedAzeriteBeam:IsAvailable() and (I.AzsharasFontofPower:IsEquipped() or not Everyone.PSCDEquipped())) then
        if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 8"; end
      end
      -- bestial_wrath,precast_time=1.5,if=azerite.primal_instincts.enabled&!essence.essence_of_the_focusing_iris.major&(equipped.azsharas_font_of_power|!equipped.cyclotronic_blast)
      if S.BestialWrath:IsCastableP() and (S.PrimalInstincts:AzeriteEnabled() and not S.FocusedAzeriteBeam:IsAvailable() and (I.AzsharasFontofPower:IsEquipped() or not Everyone.PSCDEquipped())) then
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
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment 60"; end
    end
    -- potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up&(target.health.pct<35|!talent.killer_instinct.enabled)|(consumable.potion_of_unbridled_fury&target.time_to_die<61|target.time_to_die<26)
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.BestialWrathBuff) and Player:BuffP(S.AspectoftheWildBuff) and (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable()) or Target:TimeToDie() < 61) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_agility 68"; end
    end
    -- worldvein_resonance,if=buff.lifeblood.stack<4
    if S.WorldveinResonance:IsCastableP() and (Player:BuffStackP(S.LifebloodBuff) < 4) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    -- guardian_of_azeroth,if=cooldown.aspect_of_the_wild.remains<10|target.time_to_die>cooldown+duration|target.time_to_die<30
    if S.GuardianofAzeroth:IsCastableP() and (S.AspectoftheWild:CooldownRemainsP() < 10 or Target:TimeToDie() > 180 + S.GuardianofAzeroth:BaseDuration() or Target:TimeToDie() < 30) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryofLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
  end
  Cleave = function()
    -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max
    if S.BarbedShot:IsCastableP() then
      if HR.CastTargetIf(S.BarbedShot, 40, "min", EvaluateTargetIfFilterBarbedShot74, EvaluateTargetIfBarbedShot75) then return "barbed_shot 76"; end
    end
    -- multishot,if=gcd.max-pet.cat.buff.beast_cleave.remains>0.25
    if S.Multishot:IsCastableP() and (GCDMax - Pet:BuffRemainsP(S.BeastCleaveBuff) > 0.25) then
      if HR.Cast(S.Multishot) then return "multishot 82"; end
    end
    -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
    if S.BarbedShot:IsCastableP() then
      if HR.CastTargetIf(S.BarbedShot, 40, "min", EvaluateTargetIfFilterBarbedShot74, EvaluateTargetIfBarbedShot85) then return "barbed_shot 86"; end
    end
    -- aspect_of_the_wild
    if S.AspectoftheWild:IsCastableP() then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 94"; end
    end
    -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
    if S.Stampede:IsCastableP() and (Player:BuffP(S.AspectoftheWildBuff) and Player:BuffP(S.BestialWrathBuff) or Target:TimeToDie() < 15) then
      if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede) then return "stampede 96"; end
    end
    -- bestial_wrath,if=cooldown.aspect_of_the_wild.remains>20|talent.one_with_the_pack.enabled|target.time_to_die<15
    if S.BestialWrath:IsCastableP() and (S.AspectoftheWild:CooldownRemainsP() > 20 or S.OneWithThePack:IsAvailable() or Target:TimeToDie() < 15) then
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
    -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.cat.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.cat.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|charges_fractional>1.4|target.time_to_die<9
    if S.BarbedShot:IsCastableP() then
      if HR.CastTargetIf(S.BarbedShot, 40, "min", EvaluateTargetIfFilterBarbedShot74, EvaluateTargetIfBarbedShot123) then return "barbed_shot 124"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 126"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast 128"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame 130"; end
    end
    -- blood_of_the_enemy
    if S.BloodoftheEnemy:IsCastableP() then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy 132"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffStackP(S.RecklessForceCounter) < 10) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force 134"; end
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
    -- barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<gcd|cooldown.bestial_wrath.remains&(full_recharge_time<gcd|azerite.primal_instincts.enabled&cooldown.aspect_of_the_wild.remains<gcd)
    if S.BarbedShot:IsCastableP() and (Pet:BuffP(S.FrenzyBuff) and Pet:BuffRemainsP(S.FrenzyBuff) < GCDMax or bool(S.BestialWrath:CooldownRemainsP()) and (S.BarbedShot:FullRechargeTimeP() < GCDMax or S.PrimalInstincts:AzeriteEnabled() and S.AspectoftheWild:CooldownRemainsP() < GCDMax)) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 164"; end
    end
    -- concentrated_flame,if=focus+focus.regen*gcd<focus.max&buff.bestial_wrath.down&(!dot.concentrated_flame_burn.remains&!action.concentrated_flame.in_flight)|full_recharge_time<gcd|target.time_to_die<5
    if S.ConcentratedFlame:IsCastableP() and (Player:Focus() + Player:FocusRegen() * Player:GCD() < Player:FocusMax() and Player:BuffDownP(S.BestialWrathBuff) and (Target:DebuffDownP(S.ConcentratedFlameBurn) and not S.ConcentratedFlame:InFlight()) or S.ConcentratedFlame:FullRechargeTimeP() < Player:GCD() or Target:TimeToDie() < 5) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame 165"; end
    end
    -- aspect_of_the_wild,if=cooldown.barbed_shot.charges<2|pet.cat.buff.frenzy.stack>2|!azerite.primal_instincts.enabled
    if S.AspectoftheWild:IsCastableP() and (S.BarbedShot:ChargesP() < 2 or Pet:BuffStackP(S.FrenzyBuff) > 2 or not S.PrimalInstincts:AzeriteEnabled()) then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 180"; end
    end
    -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
    if S.Stampede:IsCastableP() and (Player:BuffP(S.AspectoftheWildBuff) and Player:BuffP(S.BestialWrathBuff) or Target:TimeToDie() < 15) then
      if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede) then return "stampede 182"; end
    end
    -- a_murder_of_crows,if=cooldown.bestial_wrath.remains
    if S.AMurderofCrows:IsCastableP() and (bool(S.BestialWrath:CooldownRemainsP())) then
      if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return "a_murder_of_crows 183"; end
    end
    -- focused_azerite_beam,if=buff.bestial_wrath.down|target.time_to_die<5
    if S.FocusedAzeriteBeam:IsCastableP() and (Player:BuffDownP(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 184"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10|target.time_to_die<5
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffStackP(S.RecklessForceCounter) < 10 or Target:TimeToDie() < 5) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force 185"; end
    end
    -- bestial_wrath
    if S.BestialWrath:IsCastableP() then
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
    -- barbed_shot,if=pet.cat.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.cat.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|azerite.dance_of_death.rank>1&buff.dance_of_death.down&crit_pct_current>40|target.time_to_die<9
    if S.BarbedShot:IsCastableP() and (Pet:BuffDownP(S.FrenzyBuff) and (S.BarbedShot:ChargesFractionalP() > 1.8 or Player:BuffP(S.BestialWrathBuff)) or S.AspectoftheWild:CooldownRemainsP() < S.FrenzyBuff:BaseDuration() - GCDMax and S.PrimalInstincts:AzeriteEnabled() or S.DanceofDeath:AzeriteRank() > 1 and Player:BuffDownP(S.DanceofDeathBuff) and Player:CritChancePct() > 40 or Target:TimeToDie() < 9) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 200"; end
    end
    -- purifying_blast,if=buff.bestial_wrath.down|target.time_to_die<8
    if S.PurifyingBlast:IsCastableP() and (Player:BuffDownP(S.BestialWrathBuff) or Target:TimeToDie() < 8) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
    end
    -- blood_of_the_enemy
    if S.BloodoftheEnemy:IsCastableP() then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
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
    if S.CobraShot:IsCastableP() and ((Player:Focus() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemainsP() - 1) > S.KillCommand:Cost() or S.KillCommand:CooldownRemainsP() > 1 + GCDMax or Player:BuffP(S.MemoryofLucidDreams)) and S.KillCommand:CooldownRemainsP() > 1) then
      if HR.Cast(S.CobraShot) then return "cobra_shot 218"; end
    end
    -- spitting_cobra
    if S.SpittingCobra:IsCastableP() then
      if HR.Cast(S.SpittingCobra, Settings.BeastMastery.GCDasOffGCD.SpittingCobra) then return "spitting_cobra 234"; end
    end
    -- barbed_shot,if=charges_fractional>1.4
    if S.BarbedShot:IsCastableP() and (S.BarbedShot:ChargesFractionalP() > 1.4) then
      if HR.Cast(S.BarbedShot) then return "barbed_shot 235"; end
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
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.up&(prev_gcd.1.aspect_of_the_wild|!equipped.cyclotronic_blast&buff.aspect_of_the_wild.up)&(target.health.pct<35|!essence.condensed_lifeforce.major)|(debuff.razor_coral_debuff.down|target.time_to_die<26)&target.time_to_die>(24*(cooldown.cyclotronic_blast.remains+4<target.time_to_die))
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffP(S.RazorCoralDebuff) and (Player:PrevGCDP(1, S.AspectoftheWild) or not Everyone.PSCDEquipped() and Player:BuffP(S.AspectoftheWildBuff)) and (Target:HealthPercentage() < 35 or not S.GuardianofAzeroth:IsAvailable()) or (Target:DebuffDownP(S.RazorCoralDebuff) or Target:TimeToDie() < 26) and Target:TimeToDie() > (24 * num(I.PocketsizedComputationDevice:CooldownRemainsP() + 4 < Target:TimeToDie()))) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=buff.bestial_wrath.down|target.time_to_die<5
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "cyclotronic_blast"; end
    end
    -- call_action_list,name=cds
    if (HR.CDsON()) then
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

local function Init ()
  -- Register Splash Data Nucleus Abilities
  HL.RegisterNucleusAbility(2643, 8, 6)               -- Multi-Shot
  HL.RegisterNucleusAbility(194392, 8, 6)             -- Volley
  HL.RegisterNucleusAbility({171454, 171457}, 8, 6)   -- Chimaera Shot
  HL.RegisterNucleusAbility(118459, 10, 6)            -- Beast Cleave
  HL.RegisterNucleusAbility(201754, 8, 6)            -- Stomp
  HL.RegisterNucleusAbility(271686, 3, 6)             -- Head My Call
end

HR.SetAPL(253, APL, Init)

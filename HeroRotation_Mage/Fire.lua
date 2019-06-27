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
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Fire = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  MirrorImage                           = Spell(55342),
  Pyroblast                             = Spell(11366),
  BlastWave                             = Spell(157981),
  CombustionBuff                        = Spell(190319),
  FireBlast                             = Spell(108853),
  Meteor                                = Spell(153561),
  Combustion                            = Spell(190319),
  RuneofPowerBuff                       = Spell(116014),
  DragonsBreath                         = Spell(31661),
  AlexstraszasFury                      = Spell(235870),
  HotStreakBuff                         = Spell(48108),
  LivingBomb                            = Spell(44457),
  LightsJudgment                        = Spell(255647),
  RuneofPower                           = Spell(116011),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  Flamestrike                           = Spell(2120),
  FlamePatch                            = Spell(205037),
  PyroclasmBuff                         = Spell(269651),
  HeatingUpBuff                         = Spell(48107),
  PhoenixFlames                         = Spell(257541),
  Scorch                                = Spell(2948),
  SearingTouch                          = Spell(269644),
  Fireball                              = Spell(133),
  Kindling                              = Spell(155148),
  IncantersFlowBuff                     = Spell(1463),
  Preheat                               = Spell(273331),
  PreheatDebuff                         = Spell(273333),
  Firestarter                           = Spell(205026),
  Counterspell                          = Spell(2139),
  BlasterMaster                         = Spell(274596),
  BlasterMasterBuff                     = Spell(274598),
  FlameOn                               = Spell(205029),
  BloodOfTheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryOfLucidDreams                   = MultiSpell(298357, 299372, 299374),
  MemoryOfLucidDreamsMinor              = MultiSpell(298268, 299371, 299373),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianOfAzeroth                     = MultiSpell(295840, 299355, 299358),
  RecklessForce                         = Spell(302932)
};
local S = Spell.Mage.Fire;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Fire = {
  BattlePotionOfInt                = Item(163222),
  TidestormCodex                   = Item(165576),
  MalformedHeraldsLegwraps         = Item(167835)
};
local I = Item.Mage.Fire;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;
local combustion_rop_cutoff, fire_blast_pooling, phoenix_pooling;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Fire = HR.GUISettings.APL.Mage.Fire
};

-- Variables

local EnemyRanges = {40}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Fire.UseSplashData then
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

S.PhoenixFlames:RegisterInFlight();
S.Meteor:RegisterInFlight();
S.Pyroblast:RegisterInFlight(S.CombustionBuff);
S.Fireball:RegisterInFlight(S.CombustionBuff);

function S.Firestarter:ActiveStatus()
    return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90)) and 1 or 0
end

function S.Firestarter:ActiveRemains()
    return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90, 3) or 0) or 0
end

HL.RegisterNucleusAbility(157981, 8, 6)               -- Blast Wave
HL.RegisterNucleusAbility(153561, 8, 6)               -- Meteor
HL.RegisterNucleusAbility(31661, 8, 6)                -- Dragon's Breath
HL.RegisterNucleusAbility(44457, 10, 6)               -- Living Bomb
HL.RegisterNucleusAbility(2120, 8, 6)                 -- Flamestrike
HL.RegisterNucleusAbility(257541, 8, 6)               -- Phoenix Flames

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, ActiveTalents, BMCombustionPhase, CombustionPhase, RopPhase, StandardRotation
  EnemiesCount = GetEnemiesCount(8)
  HL.GetEnemies(40) -- For interrupts
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff, true) then
      if HR.Cast(S.ArcaneIntellect) then return ""; end
    end
    if Everyone.TargetIsValid() then
      -- variable,name=combustion_rop_cutoff,op=set,value=60
      combustion_rop_cutoff = 60
      -- snapshot_stats
      -- mirror_image
      if S.MirrorImage:IsCastableP() then
        if HR.Cast(S.MirrorImage) then return ""; end
      end
      -- potion
      if I.BattlePotionOfInt:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.BattlePotionOfInt) then return ""; end
      end
      -- pyroblast
      if S.Pyroblast:IsCastableP() then
        if HR.Cast(S.Pyroblast) then return ""; end
      end
    end
  end
  ActiveTalents = function()
    -- living_bomb,if=active_enemies>1&buff.combustion.down&(cooldown.combustion.remains>cooldown.living_bomb.duration|cooldown.combustion.ready)
    if S.LivingBomb:IsCastableP() and (EnemiesCount > 1 and Player:BuffDownP(S.CombustionBuff) and (S.Combustion:CooldownRemainsP() > S.LivingBomb:Cooldown() or S.Combustion:IsReadyP())) then
      if HR.Cast(S.LivingBomb) then return ""; end
    end
    -- meteor,if=buff.rune_of_power.up&(firestarter.remains>cooldown.meteor.duration|!firestarter.active)|cooldown.rune_of_power.remains>target.time_to_die&action.rune_of_power.charges<1|(cooldown.meteor.duration<cooldown.combustion.remains|cooldown.combustion.ready)&!talent.rune_of_power.enabled&(cooldown.meteor.duration<firestarter.remains|!talent.firestarter.enabled|!firestarter.active)
    if S.Meteor:IsCastableP() and (Player:BuffP(S.RuneofPowerBuff) and (S.Firestarter:ActiveRemains() > S.Meteor:Cooldown() or not bool(S.Firestarter:ActiveStatus())) or S.RuneofPower:CooldownRemainsP() > Target:TimeToDie() and S.RuneofPower:ChargesP() < 1 or (S.Meteor:Cooldown() < S.Combustion:CooldownRemainsP() or S.Combustion:IsReadyP()) and not S.RuneofPower:IsAvailable() and (S.Meteor:Cooldown() < S.Firestarter:ActiveRemains() or not S.Firestarter:IsAvailable() or not bool(S.Firestarter:ActiveStatus()))) then
      if HR.Cast(S.Meteor) then return ""; end
    end
  end
  BMCombustionPhase = function()
    -- lights_judgment,if=buff.combustion.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.LightsJudgment) then return ""; end
    end
    -- living_bomb,if=buff.combustion.down&active_enemies>1
    if S.LivingBomb:IsCastableP() and (Player:BuffDownP(S.CombustionBuff) and EnemiesCount > 1) then
      if HR.Cast(S.LivingBomb) then return ""; end
    end
    -- rune_of_power,if=buff.combustion.down
    if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- fire_blast,use_while_casting=1,if=buff.blaster_master.down&(talent.rune_of_power.enabled&action.rune_of_power.executing&action.rune_of_power.execute_remains<0.6|(cooldown.combustion.ready|buff.combustion.up)&!talent.rune_of_power.enabled&!action.pyroblast.in_flight&!action.fireball.in_flight)
    if S.FireBlast:IsCastableP() and (Player:BuffDownP(S.BlasterMasterBuff) and (S.RuneofPower:IsAvailable() and Player:IsCasting(S.RuneofPower) and Player:CastRemains() < 0.6 or (S.Combustion:IsReady() or Player:BuffP(S.CombustionBuff)) and not S.RuneofPower:IsAvailable() and not S.Pyroblast:InFlight() and not S.Fireball:InFlight())) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- combustion,use_off_gcd=1,use_while_casting=1,if=azerite.blaster_master.enabled&((action.meteor.in_flight&action.meteor.in_flight_remains<0.2)|!talent.meteor.enabled|prev_gcd.1.meteor)&(buff.rune_of_power.up|!talent.rune_of_power.enabled)
    if S.Combustion:IsCastableP() and (S.BlasterMaster:IsAvailable() and ((S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() > 2.8) or not S.Meteor:IsAvailable() or Player:PrevGCDP(1, S.Meteor)) and (Player:BuffP(S.RuneofPower) or not S.RuneofPower:IsAvailable())) then
      if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return ""; end
    end
    -- potion
    if I.BattlePotionOfInt:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionOfInt) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- use_items
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.up
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.combustion.remains
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemainsP(S.CombustionBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- phoenix_flames
    if S.PhoenixFlames:IsCastableP() then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,if=buff.blaster_master.stack=1&buff.hot_streak.down&!buff.pyroclasm.react&prev_gcd.1.pyroblast&(buff.blaster_master.remains<0.15|gcd.remains<0.15)
    if S.FireBlast:IsCastableP() and (Player:BuffStack(S.BlasterMasterBuff) == 1 and Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.PyroclasmBuff) and Player:PrevGCDP(1, S.Pyroblast) and (Player:BuffRemainsP(S.BlasterMasterBuff) < 0.15 or Player:GCDRemains() < 0.15)) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- fire_blast,use_while_casting=1,if=buff.blaster_master.stack=1&(action.scorch.executing&action.scorch.execute_remains<0.15|buff.blaster_master.remains<0.15)
    if S.FireBlast:IsCastableP() and (Player:BuffStack(S.BlasterMasterBuff) == 1 and (Player:IsCasting(S.Scorch) and Player:CastRemains() < 0.15 or Player:BuffRemainsP(S.BlasterMasterBuff) < 0.15)) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- scorch,if=buff.hot_streak.down&(cooldown.fire_blast.remains<cast_time|action.fire_blast.charges>0)
    if S.Scorch:IsCastableP() and (Player:BuffDownP(S.HotStreakBuff) and (S.FireBlast:CooldownRemainsP() < S.Scorch:CastTime() or S.FireBlast:ChargesP() > 0)) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- fire_blast,use_while_casting=1,use_off_gcd=1,if=buff.blaster_master.stack>1&(prev_gcd.1.scorch&!buff.hot_streak.up&!action.scorch.executing|buff.blaster_master.remains<0.15)
    if S.FireBlast:IsCastableP() and (Player:BuffStack(S.BlasterMasterBuff) > 1 and (Player:PrevGCDP(1, S.Scorch) and Player:BuffDownP(S.HotStreakBuff) and not Player:IsCasting(S.Scorch) or Player:BuffRemainsP(S.BlasterMasterBuff) < 0.15)) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
    if S.LivingBomb:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and EnemiesCount > 1) then
      if HR.Cast(S.LivingBomb) then return ""; end
    end
    -- dragons_breath,if=buff.combustion.remains<gcd.max
    if S.DragonsBreath:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD()) then
      if HR.Cast(DragonsBreath) then return ""; end
    end
    -- scorch
    if S.Scorch:IsCastableP() then
      if HR.Cast(S.Scorch) then return ""; end
    end
  end
  CombustionPhase = function()
    -- lights_judgment,if=buff.combustion.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.LightsJudgment) then return ""; end
    end
    -- call_action_list,name=bm_combustion_phase,if=azerite.blaster_master.enabled&talent.flame_on.enabled&!essence.memory_of_lucid_dreams.enabled
    if S.BlasterMaster:IsAvailable() and S.FlameOn:IsAvailable() and not S.MemoryOfLucidDreamsMinor:IsAvailable() then
      local ShouldReturn = BMCombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- blood_of_the_enemy
    if S.BloodOfTheEnemy:IsCastableP() then
      if HR.Cast(S.BloodOfTheEnemy, Settings.Fire.GCDasOffGCD.Essences) then return ""; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryOfLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryOfLucidDreams, Settings.Fire.GCDasOffGCD.Essences) then return ""; end
    end
    -- guardian_of_azeroth
    if S.GuardianOfAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianOfAzeroth, Settings.Fire.GCDasOffGCD.Essences) then return ""; end
    end
    -- rune_of_power,if=buff.combustion.down
    if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- call_action_list,name=active_talents,if=(azerite.blaster_master.enabled&buff.blaster_master.stack>=3)|!azerite.blaster_master.enabled
    if (S.BlasterMaster:IsAvailable() and Player:BuffStackP(S.BlasterMasterBuff) >= 3) or not S.BlasterMaster:IsAvailable() then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- combustion,use_off_gcd=1,use_while_casting=1,if=!essence.memory_of_lucid_dreams.enabled&(!azerite.blaster_master.enabled|!talent.flame_on.enabled)&((action.meteor.in_flight&action.meteor.in_flight_remains<=0.5)|!talent.meteor.enabled)&(buff.rune_of_power.up|!talent.rune_of_power.enabled)
    if S.Combustion:IsCastableP() and HR.CDsON() and (not S.MemoryOfLucidDreamsMinor:IsAvailable() and (not S.BlasterMaster:IsAvailable() or not S.FlameOn:IsAvailable()) and ((S.Meteor:InFlight() and S.Meteor:TimeSinceLastCast() >= 2.5) or not S.Meteor:IsAvailable()) and (Player:BuffP(S.RuneofPowerBuff) or not S.RuneofPower:IsAvailable())) then
      if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return ""; end
    end
    -- combustion,use_off_gcd=1,use_while_casting=1,if=essence.memory_of_lucid_dreams.enabled&(buff.rune_of_power.up|!talent.rune_of_power.enabled)
    if S.Combustion:IsCastableP() and HR.CDsON() and (S.MemoryOfLucidDreamsMinor:IsAvailable() and (Player:BuffP(S.RuneofPowerBuff) or not S.RuneofPower:IsAvailable())) then
      if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return ""; end
    end
    -- potion
    if I.BattlePotionOfInt:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionOfInt) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- use_items
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>2)|active_enemies>6)&buff.hot_streak.react&!azerite.blaster_master.enabled
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 2) or EnemiesCount > 6) and Player:BuffP(S.HotStreakBuff) and not S.BlasterMaster:IsAvailable()) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- pyroblast,if=buff.pyroclasm.react&buff.combustion.remains>execute_time
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and Player:BuffRemainsP(S.CombustionBuff) > S.Pyroblast:ExecuteTime()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=essence.memory_of_lucid_dreams.enabled&((buff.combustion.up&(buff.heating_up.react&!action.pyroblast.in_flight&!action.scorch.executing)|(action.scorch.execute_remains&buff.heating_up.down&buff.hot_streak.down&!action.pyroblast.in_flight)))
    if S.FireBlast:IsCastableP() and (S.MemoryOfLucidDreamsMinor:IsAvailable() and (Player:BuffP(S.CombustionBuff) and (Player:BuffP(S.HeatingUpBuff) and not S.Pyroblast:InFlight() and not Player:IsCasting(S.Scorch)) or (Player:IsCasting(S.Scorch) and Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff) and not S.Pyroblast:InFlight()))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!essence.memory_of_lucid_dreams.enabled&(!azerite.blaster_master.enabled|!talent.flame_on.enabled)&((buff.combustion.up&(buff.heating_up.react&!action.pyroblast.in_flight&!action.scorch.executing)|(action.scorch.execute_remains&buff.heating_up.down&buff.hot_streak.down&!action.pyroblast.in_flight)))
    if S.FireBlast:IsCastableP() and (not S.MemoryOfLucidDreamsMinor:IsAvailable() and (not S.BlasterMaster:IsAvailable() or not S.FlameOn:IsAvailable()) and ((Player:BuffP(S.CombustionBuff) and (Player:BuffP(S.HeatingUpBuff) and not S.Pyroblast:InFlight() and not Player:IsCasting(S.Scorch)) or (Player:IsCasting(S.Scorch) and Player:BuffDownP(S.HotStreakBuff) and not S.Pyroblast:InFlight())))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- phoenix_flames
    if S.PhoenixFlames:IsCastableP() then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- scorch,if=buff.combustion.remains>cast_time&buff.combustion.up|buff.combustion.down
    if S.Scorch:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) > S.Scorch:CastTime() and Player:BuffP(S.CombustionBuff) or Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
    if S.LivingBomb:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and EnemiesCount > 1) then
      if HR.Cast(S.LivingBomb) then return ""; end
    end
    -- dragons_breath,if=buff.combustion.remains<gcd.max&buff.combustion.up
    if S.DragonsBreath:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) < Player:GCD() and Player:BuffP(S.CombustionBuff)) then
      if HR.Cast(S.DragonsBreath) then return ""; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return ""; end
    end
  end
  RopPhase = function()
    -- rune_of_power
    if S.RuneofPower:IsCastableP() then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>4)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 1) or EnemiesCount > 4) and Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0|firestarter.active&buff.rune_of_power.up)&(!buff.heating_up.react&!buff.hot_streak.react&!prev_off_gcd.fire_blast&(action.fire_blast.charges>=2|(action.phoenix_flames.charges>=1&talent.phoenix_flames.enabled)|(talent.alexstraszas_fury.enabled&cooldown.dragons_breath.ready)|(talent.searing_touch.enabled&target.health.pct<=30)|(talent.firestarter.enabled&firestarter.active)))
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 or bool(S.Firestarter:ActiveStatus()) and Player:BuffP(S.RuneofPowerBuff)) and (Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff) and not Player:PrevOffGCDP(1, S.FireBlast) and S.FireBlast:ChargesP() >= 2 or (S.PhoenixFlames:ChargesP() >= 1 and S.PhoenixFlames:IsAvailable()) or (S.AlexstraszasFury:IsAvailable() and S.DragonsBreath:IsReady()) or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30) or (S.Firestarter:IsAvailable() and bool(S.Firestarter:ActiveStatus())))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- pyroblast,if=buff.pyroclasm.react&execute_time<buff.pyroclasm.remains&buff.rune_of_power.remains>cast_time
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:ExecuteTime() < Player:BuffRemainsP(S.PyroclasmBuff) and Player:BuffRemainsP(S.RuneofPowerBuff) > S.Pyroblast:CastTime()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0|firestarter.active&buff.rune_of_power.up)&(buff.heating_up.react&(target.health.pct>=30|!talent.searing_touch.enabled))
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 or bool(S.Firestarter:ActiveStatus()) and Player:BuffP(S.RuneofPowerBuff)) and (Player:BuffP(S.HeatingUpBuff) and (Target:HealthPercentage() >= 30 or not S.SearingTouch:IsAvailable()))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0|firestarter.active&buff.rune_of_power.up)&talent.searing_touch.enabled&target.health.pct<=30&(buff.heating_up.react&!action.scorch.executing|!buff.heating_up.react&!buff.hot_streak.react)
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 or bool(S.Firestarter:ActiveStatus()) and Player:BuffP(S.RuneofPowerBuff)) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and (Player:BuffP(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up&talent.searing_touch.enabled&target.health.pct<=30&(!talent.flame_patch.enabled|active_enemies=1)
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff) and S.SearingTouch:IsAvailable() or Target:HealthPercentage() <= 30 and (not S.FlamePatch:IsAvailable() or EnemiesCount == 1)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- phoenix_flames,if=!prev_gcd.1.phoenix_flames&buff.heating_up.react
    if S.PhoenixFlames:IsCastableP() and (not Player:PrevGCDP(1, S.PhoenixFlames) and Player:BuffP(S.HeatingUpBuff)) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- dragons_breath,if=active_enemies>2
    if S.DragonsBreath:IsCastableP() and (EnemiesCount > 2) then
      if HR.Cast(S.DragonsBreath) then return ""; end
    end
    -- flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
    if S.Flamestrike:IsCastableP() and ((S.FlamePatch:IsAvailable() and EnemiesCount > 2) or EnemiesCount > 5) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- fireball
    if S.Fireball:IsCastableP() then
      if HR.Cast(S.Fireball) then return ""; end
    end
  end
  StandardRotation = function()
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>1&!firestarter.active)|active_enemies>4)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and EnemiesCount > 1 and not bool(S.Firestarter:ActiveStatus())) or EnemiesCount > 4) and Player:BuffP(S.HotStreakBuff)) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and Player:BuffRemainsP(S.HotStreakBuff) < S.Fireball:ExecuteTime()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&(prev_gcd.1.fireball|firestarter.active|action.pyroblast.in_flight)
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and (Player:PrevGCDP(1, S.Fireball) or bool(S.Firestarter:ActiveStatus()) or S.Pyroblast:InFlight())) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&target.health.pct<=30&talent.searing_touch.enabled
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.HotStreakBuff) and Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains
    if S.Pyroblast:IsCastableP() and (Player:BuffP(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemainsP(S.PyroclasmBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=(cooldown.combustion.remains>0&buff.rune_of_power.down|firestarter.active)&!talent.kindling.enabled&!variable.fire_blast_pooling&(((action.fireball.executing|action.pyroblast.executing)&(buff.heating_up.react|firestarter.active&!buff.hot_streak.react&!buff.heating_up.react))|(talent.searing_touch.enabled&target.health.pct<=30&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!action.pyroblast.in_flight&!action.fireball.in_flight))|(firestarter.active&(action.pyroblast.in_flight|action.fireball.in_flight)&!buff.heating_up.react&!buff.hot_streak.react))
    if S.FireBlast:IsCastableP() and ((S.Combustion:CooldownRemainsP() > 0 and Player:BuffDownP(S.RuneofPowerBuff) or bool(S.Firestarter:ActiveStatus())) and not S.Kindling:IsAvailable() and not bool(fire_blast_pooling) and (((Player:IsCasting(S.Fireball) or Player:IsCasting(S.Pyroblast)) and (Player:BuffP(S.HeatingUpBuff) or bool(S.Firestarter:ActiveStatus()) and Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.HeatingUpBuff))) or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and (Player:BuffP(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDownP(S.HotStreakBuff) and Player:BuffDownP(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not S.Pyroblast:InFlight() and not S.Fireball:InFlight())) or (bool(S.Firestarter:ActiveStatus()) and (S.Pyroblast:InFlight() or S.Fireball:InFlight()) and Player:BuffDownP(S.HeatingUpBuff) and Player:BuffDownP(S.HotStreakBuff)))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- fire_blast,if=talent.kindling.enabled&buff.heating_up.react&(cooldown.combustion.remains>full_recharge_time+2+talent.kindling.enabled|firestarter.remains>full_recharge_time|(!talent.rune_of_power.enabled|cooldown.rune_of_power.remains>target.time_to_die&action.rune_of_power.charges<1)&cooldown.combustion.remains>target.time_to_die)
    if S.FireBlast:IsCastableP() and (S.Kindling:IsAvailable() and Player:BuffP(S.HeatingUpBuff) and (S.Combustion:CooldownRemainsP() > S.FireBlast:FullRechargeTimeP() + 2 + num(S.Kindling:IsAvailable()) or S.Firestarter:ActiveRemains() > S.FireBlast:FullRechargeTimeP() or (not S.RuneofPower:IsAvailable() or S.RuneofPower:CooldownRemainsP() > Target:TimeToDie() and S.RuneofPower:ChargesP() < 1) and S.Combustion:CooldownRemainsP() > Target:TimeToDie())) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.up&talent.searing_touch.enabled&target.health.pct<=30&((talent.flame_patch.enabled&active_enemies=1&!firestarter.active)|(active_enemies<4&!talent.flame_patch.enabled))
    if S.Pyroblast:IsCastableP() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffP(S.HeatingUpBuff) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and ((S.FlamePatch:IsAvailable() and EnemiesCount == 1 and not bool(S.Firestarter:ActiveStatus())) or (EnemiesCount < 4 and not S.FlamePatch:IsAvailable()))) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- phoenix_flames,if=(buff.heating_up.react|(!buff.hot_streak.react&(action.fire_blast.charges>0|talent.searing_touch.enabled&target.health.pct<=30)))&!variable.phoenix_pooling
    if S.PhoenixFlames:IsCastableP() and ((Player:BuffP(S.HeatingUpBuff) or (Player:BuffDownP(S.HotStreakBuff) and (S.FireBlast:ChargesP() > 0 or S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30))) and not bool(phoenix_pooling)) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- dragons_breath,if=active_enemies>1
    if S.DragonsBreath:IsCastableP() and (EnemiesCount > 1) then
      if HR.Cast(S.DragonsBreath) then return ""; end
    end
    -- use_item,name=tidestorm_codex,if=cooldown.combustion.remains>20|talent.firestarter.enabled&firestarter.remains>20
    if I.TidestormCodex:IsReady() and (S.Combustion:CooldownRemainsP() > 20 or S.Firestarter:IsAvailable() and S.Firestarter:ActiveRemains() > 20) then
      if HR.Cast(I.TidestormCodex) then return ""; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- fireball
    if S.Fireball:IsCastableP() then
      if HR.Cast(S.Fireball) then return ""; end
    end
    -- scorch
    if S.Scorch:IsCastableP() then
      if HR.Cast(S.Scorch) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell,if=target.debuff.casting.react
    Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false);
    -- mirror_image,if=buff.combustion.down
    if S.MirrorImage:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, Settings.Fire.GCDasOffGCD.Essences) then return "concentrated_flame"; end
    end
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam, Settings.Fire.GCDasOffGCD.Essences) then return "focused_azerite_beam"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, Settings.Fire.GCDasOffGCD.Essences) then return "purifying_blast"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, Settings.Fire.GCDasOffGCD.Essences) then return "ripple_in_space"; end
    end
    -- the_unbound_force
    if S.TheUnboundForce:IsCastableP() then
      if HR.Cast(S.TheUnboundForce, Settings.Fire.GCDasOffGCD.Essences) then return "the_unbound_force"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance, Settings.Fire.GCDasOffGCD.Essences) then return "worldvein_resonance"; end
    end
    -- rune_of_power,if=talent.firestarter.enabled&firestarter.remains>full_recharge_time|cooldown.combustion.remains>variable.combustion_rop_cutoff&buff.combustion.down|target.time_to_die<cooldown.combustion.remains&buff.combustion.down
    if S.RuneofPower:IsCastableP() and (S.Firestarter:IsAvailable() and S.Firestarter:ActiveRemains() > S.RuneofPower:FullRechargeTimeP() or S.RuneofPower:CooldownRemainsP() > combustion_rop_cutoff and Player:BuffDownP(S.CombustionBuff) or Target:TimeToDie() < S.Combustion:CooldownRemainsP() and Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- use_item,name=malformed_heralds_legwraps,if=cooldown.combustion.remains>55
    if I.MalformedHeraldsLegwraps:IsReady() and (S.Combustion:CooldownRemainsP() > 55) then
      if HR.Cast(I.MalformedHeraldsLegwraps) then return ""; end
    end
    -- call_action_list,name=combustion_phase,if=(talent.rune_of_power.enabled&cooldown.combustion.remains<=action.rune_of_power.cast_time|cooldown.combustion.ready)&!firestarter.active|buff.combustion.up
    if HR.CDsON() and ((S.RuneofPower:IsAvailable() and S.Combustion:CooldownRemainsP() <= S.RuneofPower:CastTime() or S.Combustion:IsReadyP()) and not bool(S.Firestarter:ActiveStatus()) or Player:BuffP(S.CombustionBuff)) then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
    if (Player:BuffP(S.RuneofPowerBuff) and Player:BuffDownP(S.CombustionBuff)) then
      local ShouldReturn = RopPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=fire_blast_pooling,value=talent.rune_of_power.enabled&cooldown.rune_of_power.remains<cooldown.fire_blast.full_recharge_time&(cooldown.combustion.remains>variable.combustion_rop_cutoff|firestarter.active)&(cooldown.rune_of_power.remains<target.time_to_die|action.rune_of_power.charges>0)|cooldown.combustion.remains<action.fire_blast.full_recharge_time+cooldown.fire_blast.duration*azerite.blaster_master.enabled&!firestarter.active&cooldown.combustion.remains<target.time_to_die|talent.firestarter.enabled&firestarter.active&firestarter.remains<cooldown.fire_blast.full_recharge_time+cooldown.fire_blast.duration*azerite.blaster_master.enabled
    if S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemainsP() < S.FireBlast:FullRechargeTimeP() and (S.Combustion:CooldownRemainsP() > combustion_rop_cutoff or bool(S.Firestarter:ActiveStatus())) and (S.RuneofPower:CooldownRemainsP() < Target:TimeToDie() or S.RuneofPower:ChargesP() > 0) or S.Combustion:CooldownRemainsP() < S.FireBlast:FullRechargeTimeP() + S.FireBlast:Cooldown() * num(S.BlasterMaster:IsAvailable()) and not bool(S.Firestarter:ActiveStatus()) and S.Combustion:CooldownRemainsP() < Target:TimeToDie() or S.Firestarter:IsAvailable() and bool(S.Firestarter:ActiveStatus()) and S.Firestarter:ActiveRemains() < S.FireBlast:FullRechargeTimeP() + S.FireBlast:Cooldown() * num(S.BlasterMaster:IsAvailable()) then
      fire_blast_pooling = 1
    else
      fire_blast_pooling = 0
    end
    -- variable,name=phoenix_pooling,value=talent.rune_of_power.enabled&cooldown.rune_of_power.remains<cooldown.phoenix_flames.full_recharge_time&cooldown.combustion.remains>variable.combustion_rop_cutoff&(cooldown.rune_of_power.remains<target.time_to_die|action.rune_of_power.charges>0)|cooldown.combustion.remains<action.phoenix_flames.full_recharge_time&cooldown.combustion.remains<target.time_to_die
    if S.PhoenixFlames:IsAvailable() and (S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemainsP() < S.PhoenixFlames:FullRechargeTimeP() and S.Combustion:CooldownRemainsP() > combustion_rop_cutoff and (S.RuneofPower:CooldownRemainsP() < Target:TimeToDie() or S.RuneofPower:ChargesP() > 0) or S.Combustion:CooldownRemainsP() < S.PhoenixFlames:FullRechargeTimeP() and S.Combustion:CooldownRemainsP() < Target:TimeToDie()) then
      phoenix_pooling = 1
    else
      phoenix_pooling = 0
    end
    -- call_action_list,name=standard_rotation
    if (true) then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

HR.SetAPL(63, APL)

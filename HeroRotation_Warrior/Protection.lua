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
if not Spell.Warrior then Spell.Warrior = {} end
Spell.Warrior.Protection = {
  ThunderClap                           = Spell(6343),
  DemoralizingShout                     = Spell(1160),
  BoomingVoice                          = Spell(202743),
  DragonRoar                            = Spell(118000),
  Revenge                               = Spell(6572),
  FreeRevenge                           = Spell(5302),
  Ravager                               = Spell(228920),
  ShieldBlock                           = Spell(2565),
  ShieldSlam                            = Spell(23922),
  ShieldBlockBuff                       = Spell(132404),
  UnstoppableForce                      = Spell(275336),
  AvatarBuff                            = Spell(107574),
  BraceForImpact                        = Spell(277636),
  DeafeningCrash                        = Spell(272824),
  Devastate                             = Spell(20243),
  Intercept                             = Spell(198304),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  IgnorePain                            = Spell(190456),
  Avatar                                = Spell(107574),
  LastStand                             = Spell(12975),
  LastStandBuff                         = Spell(12975),
  VictoryRush                           = Spell(34428),
  ImpendingVictory                      = Spell(202168),
  Pummel                                = Spell(6552),
  IntimidatingShout                     = Spell(5246),
  RazorCoralDebuff                      = Spell(303568),
  BloodofTheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  AnimaofDeath                          = MultiSpell(294926, 300002, 300003),
  AnimaofLife                           = MultiSpell(294964, 300004, 300005),
  ConcentratedFlameBurn                 = Spell(295368),
  RecklessForceBuff                     = Spell(302932)
};
local S = Spell.Warrior.Protection;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Protection = {
  SuperiorBattlePotionofStrength   = Item(168500),
  GrongsPrimalRage                 = Item(165574),
  AshvanesRazorCoral               = Item(169311)
};
local I = Item.Warrior.Protection;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Protection = HR.GUISettings.APL.Warrior.Protection
};

-- Stuns
local StunInterrupts = {
  {S.IntimidatingShout, "Cast Intimidating Shout (Interrupt)", function () return true; end},
};

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

local function isCurrentlyTanking()
  -- is player currently tanking any enemies within 16 yard radius
  local IsTanking = Player:IsTankingAoE(16) or Player:IsTanking(Target);
  return IsTanking;
end

local function shouldCastIp()
  if Player:Buff(S.IgnorePain) then 
    local castIP = tonumber((GetSpellDescription(190456):match("%d+%S+%d"):gsub("%D","")))
    local IPCap = math.floor(castIP * 1.3);
    local currentIp = Player:Buff(S.IgnorePain, 16, true)

    -- Dont cast IP if we are currently at 50% of IP Cap remaining
    if currentIp  < (0.5 * IPCap) then
      return true
    else
      return false
    end
  else
    -- No IP buff currently
    return true
  end
end

local function offensiveShieldBlock()
  if Settings.Protection.UseShieldBlockDefensively == false then
    return true
  else
    return false
  end
end

local function offensiveRage()
  if Settings.Protection.UseRageDefensively == false then
    return true
  else
    return false
  end
end

HL.RegisterNucleusAbility(6343, 8, 6)               -- Thunder Clap
HL.RegisterNucleusAbility(118000, 12, 6)            -- Dragon Roar
HL.RegisterNucleusAbility(6572, 8, 6)               -- Revenge
HL.RegisterNucleusAbility(228920, 8, 6)             -- Ravager

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Aoe, St, Defensive
  local gcdTime = Player:GCD()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.SuperiorBattlePotionofStrength:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.SuperiorBattlePotionofStrength) then return "battle_potion_of_strength 4"; end
      end
      -- memory_of_lucid_dreams
      if S.MemoryofLucidDreams:IsCastableP() then
        if HR.Cast(S.MemoryofLucidDreams) then return "memory_of_lucid_dreams"; end
      end
      -- guardian_of_azeroth
      if S.GuardianofAzeroth:IsCastableP() then
        if HR.Cast(S.GuardianofAzeroth) then return "guardian_of_azeroth"; end
      end
    end
  end
  Defensive = function()
    if S.ShieldBlock:IsReadyP() and (((not Player:Buff(S.ShieldBlockBuff)) or Player:BuffRemains(S.ShieldBlockBuff) <= gcdTime + (gcdTime * 0.5)) and 
      (not Player:Buff(S.LastStandBuff)) and Player:Rage() >= 30) then
        if HR.Cast(S.ShieldBlock, Settings.Protection.OffGCDasOffGCD.ShieldBlock) then return "shield_block defensive" end
    end
    if S.LastStand:IsCastableP() and ((not Player:Buff(S.ShieldBlockBuff)) and Settings.Protection.UseLastStandToFillShieldBlockDownTime
      and S.ShieldBlock:RechargeP() > (gcdTime * 2)) then
        if HR.Cast(S.LastStand, Settings.Protection.GCDasOffGCD.LastStand) then return "last_stand defensive" end
    end
  end
  Aoe = function()
    -- thunder_clap
    if S.ThunderClap:IsCastableP() then
      if HR.Cast(S.ThunderClap) then return "thunder_clap 6"; end
    end
    -- memory_of_lucid_dreams,if=buff.avatar.down
    if S.MemoryofLucidDreams:IsCastableP() and (Player:BuffDownP(S.AvatarBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, Settings.Protection.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams 7"; end
    end
    -- demoralizing_shout,if=talent.booming_voice.enabled
    if S.DemoralizingShout:IsCastableP() and (S.BoomingVoice:IsAvailable() and Player:RageDeficit() >= 40) then
      if HR.Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout) then return "demoralizing_shout 8"; end
    end
    -- anima_of_death,if=buff.last_stand.up
    if S.AnimaofDeath:IsCastableP() and (Player:BuffP(S.LastStandBuff)) then
      if HR.Cast(S.AnimaofDeath, Settings.Protection.GCDasOffGCD.Essences) then return "anima_of_death 9"; end
    end
    -- dragon_roar
    if S.DragonRoar:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar) then return "dragon_roar 12"; end
    end
    -- revenge
    if S.Revenge:IsReadyP() and (Player:Buff(S.FreeRevenge) or offensiveRage() or Player:Rage() >= 75 or ((not isCurrentlyTanking()) and Player:Rage() >= 50)) then
      if HR.Cast(S.Revenge) then return "revenge 14"; end
    end
    -- ravager
    if S.Ravager:IsCastableP() then
      if HR.Cast(S.Ravager) then return "ravager 16"; end
    end
    -- shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down
    if S.ShieldBlock:IsReadyP() and (S.ShieldSlam:CooldownUpP() and Player:BuffDownP(S.ShieldBlockBuff) and offensiveShieldBlock()) then
      if HR.Cast(S.ShieldBlock, Settings.Protection.OffGCDasOffGCD.ShieldBlock) then return "shield_block 18"; end
    end
    -- shield_slam
    if S.ShieldSlam:IsCastableP() then
      if HR.Cast(S.ShieldSlam) then return "shield_slam 24"; end
    end
	-- devastate
    if S.Devastate:IsCastableP() then
      if HR.Cast(S.Devastate) then return "devastate 80"; end
    end
  end
  St = function()
    -- thunder_clap,if=spell_targets.thunder_clap=2&talent.unstoppable_force.enabled&buff.avatar.up
    if S.ThunderClap:IsCastableP() and (Cache.EnemiesCount[8] == 2 and S.UnstoppableForce:IsAvailable() and Player:BuffP(S.AvatarBuff)) then
      if HR.Cast(S.ThunderClap) then return "thunder_clap 26"; end
    end
    -- shield_block,if=cooldown.shield_slam.ready&buff.shield_block.down
    if S.ShieldBlock:IsReadyP() and (S.ShieldSlam:CooldownUpP() and Player:BuffDownP(S.ShieldBlockBuff)) then
      if HR.Cast(S.ShieldBlock, Settings.Protection.OffGCDasOffGCD.ShieldBlock) then return "shield_block 32"; end
    end
    -- shield_slam,if=buff.shield_block.up
    if S.ShieldSlam:IsCastableP() and (Player:BuffP(S.ShieldBlockBuff)) then
      if HR.Cast(S.ShieldSlam) then return "shield_slam 44"; end
    end
    -- thunder_clap,if=(talent.unstoppable_force.enabled&buff.avatar.up)
    if S.ThunderClap:IsCastableP() and ((S.UnstoppableForce:IsAvailable() and Player:BuffP(S.AvatarBuff))) then
      if HR.Cast(S.ThunderClap) then return "thunder_clap 54"; end
    end
    -- demoralizing_shout,if=talent.booming_voice.enabled
    if S.DemoralizingShout:IsCastableP() and (S.BoomingVoice:IsAvailable() and Player:RageDeficit() >= 40) then
      if HR.Cast(S.DemoralizingShout, Settings.Protection.GCDasOffGCD.DemoralizingShout) then return "demoralizing_shout 60"; end
    end
    -- anima_of_death,if=buff.last_stand.up
    if S.AnimaofDeath:IsCastableP() and (Player:BuffP(S.LastStandBuff)) then
      if HR.Cast(S.AnimaofDeath, Settings.Protection.GCDasOffGCD.Essences) then return "anima_of_death 61"; end
    end
    -- shield_slam
    if S.ShieldSlam:IsCastableP() then
      if HR.Cast(S.ShieldSlam) then return "shield_slam 70"; end
    end
    -- use_item,name=ashvanes_razor_coral,target_if=debuff.razor_coral_debuff.stack=0
    if I.AshvanesRazorCoral:IsCastableP() and (Target:DebuffStackP(S.RazorCoralDebuff) == 0) then
      if HR.CastSuggested(I.AshvanesRazorCoral) then return "ashvanes_razor_coral 71"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.stack>7&(cooldown.avatar.remains<5|buff.avatar.up)
    if I.AshvanesRazorCoral:IsCastableP() and (Target:DebuffStackP(S.RazorCoralDebuff) > 7 and (S.Avatar:CooldownRemainsP() < 5 or Player:BuffP(S.AvatarBuff))) then
      if HR.CastSuggested(I.AshvanesRazorCoral) then return "ashvanes_razor_coral 72"; end
    end
    -- dragon_roar
    if S.DragonRoar:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.DragonRoar, Settings.Protection.GCDasOffGCD.DragonRoar) then return "dragon_roar 73"; end
    end
    -- thunder_clap
    if S.ThunderClap:IsCastableP() then
      if HR.Cast(S.ThunderClap) then return "thunder_clap 74"; end
    end
    -- revenge
    if S.Revenge:IsReadyP() and (Player:Buff(S.FreeRevenge) or offensiveRage() or Player:Rage() >= 75 or ((not isCurrentlyTanking()) and Player:Rage() >= 50)) then
      if HR.Cast(S.Revenge) then return "revenge 76"; end
    end
    -- ravager
    if S.Ravager:IsCastableP() then
      if HR.Cast(S.Ravager) then return "ravager 78"; end
    end
    -- devastate
    if S.Devastate:IsCastableP() then
      if HR.Cast(S.Devastate) then return "devastate 80"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Check defensives if tanking
    if isCurrentlyTanking() then
      local ShouldReturn = Defensive(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupt
    Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts);
    -- auto_attack
    -- intercept,if=time=0
    if S.Intercept:IsCastableP() and (HL.CombatTime() == 0 and not Target:IsInRange(8)) then
      if HR.Cast(S.Intercept) then return "intercept 84"; end
    end
    -- use_items,if=cooldown.avatar.remains>20
    -- use_item,name=grongs_primal_rage,if=buff.avatar.down
    if I.GrongsPrimalRage:IsReady() and (Player:BuffDownP(S.AvatarBuff)) then
      if HR.CastSuggested(I.GrongsPrimalRage) then return "grongs_primal_rage 87"; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 91"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 93"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 95"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 97"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 99"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 101"; end
    end
    -- potion,if=buff.avatar.up|target.time_to_die<25
    if I.SuperiorBattlePotionofStrength:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.AvatarBuff) or Target:TimeToDie() < 25) then
      if HR.CastSuggested(I.SuperiorBattlePotionofStrength) then return "battle_potion_of_strength 103"; end
    end
    if Player:HealthPercentage() < 30 and S.VictoryRush:IsReady() then
      if HR.Cast(S.VictoryRush) then return "victory_rush defensive" end
    end
    if Player:HealthPercentage() < 30 and S.ImpendingVictory:IsReadyP() then
      if HR.Cast(S.ImpendingVictory) then return "impending_victory defensive" end
    end
    -- ignore_pain,if=rage.deficit<25+20*talent.booming_voice.enabled*cooldown.demoralizing_shout.ready
    if S.IgnorePain:IsReadyP() and (Player:RageDeficit() < 25 + 20 * num(S.BoomingVoice:IsAvailable()) * num(S.DemoralizingShout:CooldownUpP()) and shouldCastIp() and isCurrentlyTanking()) then
      if HR.Cast(S.IgnorePain, Settings.Protection.OffGCDasOffGCD.IgnorePain) then return "ignore_pain 107"; end
    end
    -- worldvein_resonance,if=cooldown.avatar.remains<=2
    if S.WorldveinResonance:IsCastableP() and (S.Avatar:CooldownRemainsP() <= 2) then
      if HR.Cast(S.WorldveinResonance, Settings.Protection.GCDasOffGCD.Essences) then return "worldvein_resonance 108"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, Settings.Protection.GCDasOffGCD.Essences) then return "ripple_in_space 109"; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryofLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryofLucidDreams, Settings.Protection.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams 110"; end
    end
    -- concentrated_flame,if=buff.avatar.down
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffDownP(S.AvatarBuff)) then
      if HR.Cast(S.ConcentratedFlame, Settings.Protection.GCDasOffGCD.Essences) then return "concentrated_flame 111"; end
    end
    -- last_stand,if=cooldown.anima_of_death.remains<=2
    if S.LastStand:IsCastableP() and (S.AnimaofDeath:CooldownRemainsP() <= 2) then
      if HR.Cast(S.LastStand, Settings.Protection.GCDasOffGCD.LastStand) then return "last_stand 112"; end
    end
    -- avatar
    if S.Avatar:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Avatar, Settings.Protection.GCDasOffGCD.Avatar) then return "avatar 113"; end
    end
    -- run_action_list,name=aoe,if=spell_targets.thunder_clap>=3
    if (Cache.EnemiesCount[8] >= 3) then
      return Aoe();
    end
    -- call_action_list,name=st
    if (true) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

HR.SetAPL(73, APL)

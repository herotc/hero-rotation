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
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Guardian = {
  BearForm                              = Spell(5487),
  CatForm                               = Spell(768),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  Barkskin                              = Spell(22812),
  LunarBeam                             = Spell(204066),
  BristlingFur                          = Spell(155835),
  Maul                                  = Spell(6807),
  Ironfur                               = Spell(192081),
  LayeredMane                           = Spell(279552),
  Pulverize                             = Spell(80313),
  PulverizeBuff                         = Spell(158792),
  ThrashBearDebuff                      = Spell(192090),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
  Incarnation                           = Spell(102558),
  --ThrashCat                             = Spell(106830),
  Thrash                                = MultiSpell(77758, 106830),
  IncarnationBuff                       = Spell(102558),
  --SwipeCat                              = Spell(106785),
  Swipe                                 = MultiSpell(213771, 106785),
  Mangle                                = Spell(33917),
  GalacticGuardianBuff                  = Spell(213708),
  PoweroftheMoon                        = Spell(273367),
  FrenziedRegeneration                  = Spell(22842),
  BalanceAffinity                       = Spell(197488),
  WildChargeTalent                      = Spell(102401),
  WildChargeBear                        = Spell(16979),
  SurvivalInstincts                     = Spell(61336),
  SkullBash                             = Spell(106839),
  MemoryOfLucidDreams                   = MultiSpell(298357, 299372, 299374),
  Conflict                              = MultiSpell(303823, 304088, 304121),
  HeartEssence                          = Spell(298554),
  SharpenedClawsBuff                    = Spell(279943)
};
local S = Spell.Druid.Guardian;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Guardian = {
  PotionofFocusedResolve                = Item(168506)
};
local I = Item.Druid.Guardian;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local IsTanking;
local AoERadius; -- Range variables
local EnemiesCount;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Guardian = HR.GUISettings.APL.Druid.Guardian
};

local EnemyRanges = {11, 8}
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

--[[local function Swipe()
  if Player:Buff(S.CatForm) then
    return S.SwipeCat;
  else
    return S.SwipeBear;
  end
end

local function Thrash()
  if Player:Buff(S.CatForm) then
    return S.ThrashCat;
  else
    return S.ThrashBear;
  end
end]]

local function EvaluateCyclePulverize77(TargetUnit)
  return TargetUnit:DebuffStackP(S.ThrashBearDebuff) == 3 and not Player:BuffP(S.PulverizeBuff)
end

local function EvaluateCycleMoonfire88(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff) and EnemiesCount < 2
end

local function EvaluateCycleMoonfire139(TargetUnit)
  return Player:BuffP(S.GalacticGuardianBuff) and EnemiesCount < 2
end

HL.RegisterNucleusAbility(77758, 8, 6)               -- Thrash (Bear)
HL.RegisterNucleusAbility(213771, 8, 6)              -- Swipe (Bear)

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns
  -- Determine ranges
  if S.BalanceAffinity:IsAvailable() then
    AoERadius = 11
  else
    AoERadius = 8
  end
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  EnemiesCount = Cache.EnemiesCount[AoERadius]
  IsTanking = Player:IsTankingAoE(AoERadius) or Player:IsTanking(Target)
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- memory_of_lucid_dreams
    if S.MemoryOfLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryOfLucidDreams, Settings.Guardian.GCDasOffGCD.Essences) then return "memory_of_lucid_dreams"; end
    end
    -- bear_form
    if S.BearForm:IsCastableP() and Player:BuffDownP(S.BearForm) then
      if HR.Cast(S.BearForm) then return "bear_form 3"; end
    end
    -- snapshot_stats
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 8"; end
    end
  end
  Cooldowns = function()
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 10"; end
    end
    -- heart_essence
    if S.HeartEssence:IsCastableP() then
      if HR.Cast(S.HeartEssence, Settings.Guardian.GCDasOffGCD.Essences) then return "heart_essence"; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 12"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 14"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 16"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 18"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 20"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 22"; end
    end
    -- Defensives and Bristling Fur
    if IsTanking and Player:BuffP(S.BearForm) then
      if Player:HealthPercentage() < Settings.Guardian.FrenziedRegenHP and S.FrenziedRegeneration:IsCastableP() and Player:Rage() > 10
        and not Player:Buff(S.FrenziedRegeneration) and not Player:HealingAbsorbed() then
        if HR.Cast(S.FrenziedRegeneration, Settings.Guardian.GCDasOffGCD.FrenziedRegen) then return "frenzied_regen defensive"; end
      end
      if S.Ironfur:IsCastableP() and Player:Rage() >= S.Ironfur:Cost() + 1 and IsTanking and (not Player:Buff(S.Ironfur) 
        or (Player:BuffStack(S.Ironfur) < 2 and Player:BuffRefreshableP(S.Ironfur, 2.4))) then
        if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur defensive"; end
      end
      -- barkskin,if=buff.bear_form.up
      if S.Barkskin:IsCastableP() and Player:HealthPercentage() < Settings.Guardian.BarkskinHP then
        if HR.Cast(S.Barkskin, Settings.Guardian.OffGCDasOffGCD.Barkskin) then return "barkskin 24"; end
      end
      -- lunar_beam,if=buff.bear_form.up
      if S.LunarBeam:IsCastableP() and Player:HealthPercentage() < Settings.Guardian.LunarBeamHP then
        if HR.Cast(S.LunarBeam, Settings.Guardian.GCDasOffGCD.LunarBeam) then return "lunar_beam 28"; end
      end
      -- Survival Instincts
      if S.SurvivalInstincts:IsCastableP() and Player:HealthPercentage() < Settings.Guardian.SurvivalInstinctsHP then
        if HR.Cast(S.SurvivalInstincts, Settings.Guardian.OffGCDasOffGCD.SurvivalInstincts) then return "survival_instincts defensive"; end
      end
      -- bristling_fur,if=buff.bear_form.up
      if S.BristlingFur:IsCastableP() and Player:Rage() < Settings.Guardian.BristlingFurRage then
        if HR.Cast(S.BristlingFur) then return "bristling_fur 32"; end
      end
    end
    -- incarnation,if=(dot.moonfire.ticking|active_enemies>1)&dot.thrash_bear.ticking
    if S.Incarnation:IsReadyP() and ((Target:DebuffP(S.MoonfireDebuff) or EnemiesCount > 1) and Target:DebuffP(S.ThrashBearDebuff)) then
      if HR.Cast(S.Incarnation) then return "incarnation 33"; end
    end
    -- use_items
  end
  -- call precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Charge if out of range
    if S.WildChargeTalent:IsAvailable() and S.WildChargeBear:IsCastableP() and not Target:IsInRange(AoERadius) and Target:IsInRange(25) then
      if HR.Cast(S.WildChargeBear) then return "wild_charge in_combat"; end
    end
    -- Interrupts
    Everyone.Interrupt(13, S.SkullBash, Settings.Commons.OffGCDasOffGCD.SkullBash, false);
    -- auto_attack
    -- call_action_list,name=cooldowns
    if (true) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- maul,if=rage.deficit<10&active_enemies<4
    if S.Maul:IsReadyP() and (Player:RageDeficit() < 10 and EnemiesCount < 4) then
      if HR.Cast(S.Maul) then return "maul 41"; end
    end
    -- maul,if=essence.conflict_and_strife.major&!buff.sharpened_claws.up
    if S.Maul:IsReadyP() and (S.Conflict:IsAvailable() and Player:BuffDownP(S.SharpenedClawsBuff)) then
      if HR.Cast(S.Maul) then return "maul 42"; end
    end
    -- ironfur,if=cost=0|(rage>cost&azerite.layered_mane.enabled&active_enemies>2)
    if S.Ironfur:IsCastableP() and (S.Ironfur:Cost() == 0 or (Player:Rage() > S.Ironfur:Cost() and S.LayeredMane:AzeriteEnabled() and EnemiesCount > 2)) then
      if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur 49"; end
    end
    -- pulverize,target_if=dot.thrash_bear.stack=dot.thrash_bear.max_stacks
    if S.Pulverize:IsCastableP() then
      if HR.CastCycle(S.Pulverize, AoERadius, EvaluateCyclePulverize77) then return "pulverize 83" end
    end
    if S.Pulverize:IsCastableP() and Target:DebuffStackP(S.ThrashBearDebuff) == 3 then
      if HR.Cast(S.Pulverize) then return "pulverize 84"; end
    end
    -- moonfire,target_if=dot.moonfire.refreshable&active_enemies<2
    if S.Moonfire:IsCastableP() then
      if HR.CastCycle(S.Moonfire, AoERadius, EvaluateCycleMoonfire88) then return "moonfire 100" end
    end
    -- thrash,if=(buff.incarnation.down&active_enemies>1)|(buff.incarnation.up&active_enemies>4)
    if S.Thrash:IsCastableP() and ((Player:BuffDownP(S.IncarnationBuff) and EnemiesCount > 1) or (Player:BuffP(S.IncarnationBuff) and EnemiesCount > 4)) then
      if HR.Cast(S.Thrash) then return "thrash 103"; end
    end
    -- swipe,if=buff.incarnation.down&active_enemies>4
    if S.Swipe:IsCastableP() and (Player:BuffDownP(S.IncarnationBuff) and EnemiesCount > 4) then
      if HR.Cast(S.Swipe) then return "swipe 121"; end
    end
    -- mangle,if=dot.thrash_bear.ticking
    if S.Mangle:IsCastableP() and (Target:DebuffP(S.ThrashBearDebuff)) then
      if HR.Cast(S.Mangle) then return "mangle 131"; end
    end
    -- moonfire,target_if=buff.galactic_guardian.up&active_enemies<2
    if S.Moonfire:IsCastableP() then
      if HR.CastCycle(S.Moonfire, AoERadius, EvaluateCycleMoonfire139) then return "moonfire 151" end
    end
    -- thrash
    if S.Thrash:IsCastableP() then
      if HR.Cast(S.Thrash) then return "thrash 152"; end
    end
    -- maul
    if S.Maul:IsReadyP() and (not IsTanking or (Player:HealthPercentage() >= 80 and Player:Rage() > 85)) then
      if HR.Cast(S.Maul) then return "maul 154"; end
    end
    -- swipe
    if S.Swipe:IsCastableP() then
      if HR.Cast(S.Swipe) then return "swipe 168"; end
    end
  end
end

HR.SetAPL(104, APL)
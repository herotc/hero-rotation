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
local Druid  = HR.Commons.Druid

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
  ThrashCat                             = Spell(106830),
  ThrashBear                            = Spell(77758),
  IncarnationBuff                       = Spell(102558),
  SwipeCat                              = Spell(106785),
  SwipeBear                             = Spell(213771),
  Mangle                                = Spell(33917),
  GalacticGuardianBuff                  = Spell(213708),
  PoweroftheMoon                        = Spell(273367),
  FrenziedRegeneration                  = Spell(22842),
  BalanceAffinity                       = Spell(197488),
  WildChargeTalent                      = Spell(102401),
  WildChargeBear                        = Spell(16979),
  SurvivalInstincts                     = Spell(61336),
  SkullBash                             = Spell(106839)
};
local S = Spell.Druid.Guardian;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Guardian = {
  BattlePotionofAgility            = Item(163223)
};
local I = Item.Druid.Guardian;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local IsTanking;
local AoERadius, RangedRange; -- Range variables
local AoETar, RangedTar; -- Target variables

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Guardian = HR.GUISettings.APL.Druid.Guardian
};

local EnemyRanges = {}
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

local function Swipe()
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
end

local function GetEnemiesCount(range)
  if range == nil then range = 8 end
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Guardian.UseSplashData then
      Druid.UpdateSplashCount(Target, range)
      return Druid.GetSplashCount(Target, range)
    else
      UpdateRanges()
      Everyone.AoEToggleEnemiesUpdate()
      return Cache.EnemiesCount[8]
    end
  else
    return 1
  end
end

local function EvaluateCyclePulverize77(TargetUnit)
  return TargetUnit:DebuffStackP(S.ThrashBearDebuff) == 3 and not Player:BuffP(S.PulverizeBuff)
end

local function EvaluateCycleMoonfire88(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff) and RangedTar < 2
end

local function EvaluateCycleMoonfire139(TargetUnit)
  return Player:BuffP(S.GalacticGuardianBuff) and RangedTar < 2
end
--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns
  -- Determine ranges
  if S.BalanceAffinity:IsAvailable() then
    AoERadius = 11
    RangedRange = 43
  else
    AoERadius = 8
    RangedRange = 40
  end
  EnemyRanges = {RangedRange, AoERadius}
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  AoETar = GetEnemiesCount(AoERadius)
  RangedTar = GetEnemiesCount(RangedRange)
  IsTanking = Player:IsTankingAoE(AoERadius) or Player:IsTanking(Target)
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- bear_form
    if S.BearForm:IsCastableP() and Player:BuffDownP(S.BearForm) then
      if HR.Cast(S.BearForm) then return "bear_form 3"; end
    end
    -- snapshot_stats
    -- potion
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 8"; end
    end
  end
  Cooldowns = function()
    -- potion
    if I.BattlePotionofAgility:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionofAgility) then return "battle_potion_of_agility 10"; end
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
    if S.Maul:IsReadyP() and (Player:RageDeficit() < 10 and AoETar < 4) then
      if HR.Cast(S.Maul) then return "maul 41"; end
    end
    -- ironfur,if=cost=0|(rage>cost&azerite.layered_mane.enabled&active_enemies>2)
    if S.Ironfur:IsCastableP() and (S.Ironfur:Cost() == 0 or (Player:Rage() > S.Ironfur:Cost() and S.LayeredMane:AzeriteEnabled() and AoETar > 2)) then
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
      if HR.CastCycle(S.Moonfire, RangedRange, EvaluateCycleMoonfire88) then return "moonfire 100" end
    end
    -- incarnation
    if S.Incarnation:IsCastableP() then
      if HR.Cast(S.Incarnation) then return "incarnation 101"; end
    end
    -- thrash,if=(buff.incarnation.down&active_enemies>1)|(buff.incarnation.up&active_enemies>4)
    if Thrash():IsCastableP() and ((Player:BuffDownP(S.IncarnationBuff) and AoETar > 1) or (Player:BuffP(S.IncarnationBuff) and AoETar > 4)) then
      if HR.Cast(Thrash()) then return "thrash 103"; end
    end
    -- swipe,if=buff.incarnation.down&active_enemies>4
    if Swipe():IsCastableP() and (Player:BuffDownP(S.IncarnationBuff) and AoETar > 4) then
      if HR.Cast(Swipe()) then return "swipe 121"; end
    end
    -- mangle,if=dot.thrash_bear.ticking
    if S.Mangle:IsCastableP() and (Target:DebuffP(S.ThrashBearDebuff)) then
      if HR.Cast(S.Mangle) then return "mangle 131"; end
    end
    -- moonfire,target_if=buff.galactic_guardian.up&active_enemies<2
    if S.Moonfire:IsCastableP() then
      if HR.CastCycle(S.Moonfire, RangedRange, EvaluateCycleMoonfire139) then return "moonfire 151" end
    end
    -- thrash
    if Thrash():IsCastableP() then
      if HR.Cast(Thrash()) then return "thrash 152"; end
    end
    -- maul
    if S.Maul:IsReadyP() and (not IsTanking or (Player:HealthPercentage() >= 80 and Player:Rage() > 85)) then
      if HR.Cast(S.Maul) then return "maul 154"; end
    end
    -- moonfire,if=azerite.power_of_the_moon.rank>1&active_enemies=1
    if S.Moonfire:IsCastableP() and (S.PoweroftheMoon:AzeriteRank() > 1 and AoETar == 1) then
      if HR.Cast(S.Moonfire) then return "moonfire 156"; end
    end
    -- swipe
    if Swipe():IsCastableP() then
      if HR.Cast(Swipe()) then return "swipe 168"; end
    end
  end
end

HR.SetAPL(104, APL)
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

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

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
  BagofTricks                           = Spell(312411),
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
  IncarnationBuff                       = Spell(102558),
  Thrash                                = MultiSpell(77758, 106830),
  Swipe                                 = MultiSpell(213771, 106785),
  Mangle                                = Spell(33917),
  GalacticGuardian                      = Spell(203964),
  GalacticGuardianBuff                  = Spell(213708),
  PoweroftheMoon                        = Spell(273367),
  FrenziedRegeneration                  = Spell(22842),
  BalanceAffinity                       = Spell(197488),
  WildChargeTalent                      = Spell(102401),
  WildChargeBear                        = Spell(16979),
  SurvivalInstincts                     = Spell(61336),
  SkullBash                             = Spell(106839),
  AnimaofDeath                          = Spell(294926),
  MemoryofLucidDreams                   = Spell(298357),
  Conflict                              = Spell(303823),
  WorldveinResonance                    = Spell(295186),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  SharpenedClawsBuff                    = Spell(279943),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565)
};
local S = Spell.Druid.Guardian;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Guardian = {
  PotionofFocusedResolve           = Item(168506),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14})
};
local I = Item.Druid.Guardian;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local IsTanking;
local AoERadius; -- Range variables
local EnemiesCount;
local UseMaul;

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

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight();
end, "LEARNED_SPELL_IN_TAB")
S.ConcentratedFlame:RegisterInFlight();

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateCyclePulverize77(TargetUnit)
  return TargetUnit:DebuffStackP(S.ThrashBearDebuff) == 3 and Player:BuffDownP(S.PulverizeBuff)
end

local function EvaluateCycleMoonfire88(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff) and EnemiesCount < 2
end

local function EvaluateCycleMoonfire139(TargetUnit)
  return Player:BuffP(S.GalacticGuardianBuff) and EnemiesCount < 2
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- memory_of_lucid_dreams
  if S.MemoryofLucidDreams:IsCastableP() then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
  end
  -- bear_form
  if S.BearForm:IsCastableP() and Player:BuffDownP(S.BearForm) then
    if HR.Cast(S.BearForm) then return "bear_form 3"; end
  end
  -- potion
  if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 8"; end
  end
end

local function Cleave()
  -- maul,if=rage.deficit<=10
  if S.Maul:IsReadyP() and UseMaul and (Player:RageDeficit() <= 10) then
    if HR.Cast(S.Maul, nil, nil, "Melee") then return "maul 51"; end
  end
  -- ironfur,if=cost<=0
  if S.Ironfur:IsReadyP() and (S.Ironfur:Cost() <= 0) then
    if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur 53"; end
  end
  -- pulverize,target_if=dot.thrash_bear.stack=dot.thrash_bear.max_stacks
  if S.Pulverize:IsReadyP() and (Target:DebuffStackP(S.ThrashBearDebuff) == 3) then
    if HR.Cast(S.Pulverize, nil, nil, "Melee") then return "pulverize 55"; end
  end
  -- moonfire,target_if=!dot.moonfire.ticking
  if S.Moonfire:IsCastableP() and (Target:DebuffDownP(S.MoonfireDebuff)) then
    if HR.Cast(S.Moonfire, nil, nil, 40) then return "moonfire 57"; end
  end
  -- mangle,if=dot.thrash_bear.ticking
  if S.Mangle:IsCastableP() and (Target:DebuffP(S.ThrashBearDebuff)) then
    if HR.Cast(S.Mangle, nil, nil, "Melee") then return "mangle 59"; end
  end
  -- moonfire,target_if=buff.galactic_guardian.up&active_enemies=1|dot.moonfire.refreshable
  if S.Moonfire:IsCastableP() and (Player:BuffP(S.GalacticGuardianBuff) and Cache.EnemiesCount[8] == 1 or Target:DebuffRefreshableCP(S.MoonfireDebuff)) then
    if HR.Cast(S.Moonfire, nil, nil, 40) then return "moonfire 61"; end
  end
  -- maul
  if S.Maul:IsReadyP() and UseMaul then
    if HR.Cast(S.Maul, nil, nil, "Melee") then return "maul 63"; end
  end
  -- thrash
  if S.Thrash:IsCastableP() then
    if HR.Cast(S.Thrash, nil, nil, 8) then return "thrash 65"; end
  end
  -- swipe
  if S.Swipe:IsCastableP() then
    if HR.Cast(S.Swipe, nil, nil, 8) then return "swipe 67"; end
  end
end

local function Essences()
  -- concentrated_flame,if=essence.the_crucible_of_flame.major&((!dot.concentrated_flame_burn.ticking&!action.concentrated_flame_missile.in_flight)^time_to_die<=7)
  if S.ConcentratedFlame:IsCastableP() and ((Target:DebuffDownP(S.ConcentratedFlameBurn) and not S.ConcentratedFlame:InFlight()) or Target:TimeToDie() <= 7) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame 71"; end
  end
  -- anima_of_death,if=essence.anima_of_life_and_death.major
  if S.AnimaofDeath:IsCastableP() then
    if HR.Cast(S.AnimaofDeath, nil, Settings.Commons.EssenceDisplayStyle, 8) then return "anima_of_death 73"; end
  end
  -- memory_of_lucid_dreams,if=essence.memory_of_lucid_dreams.major
  if S.MemoryofLucidDreams:IsCastableP() then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 75"; end
  end
  -- worldvein_resonance,if=essence.worldvein_resonance.major
  if S.WorldveinResonance:IsCastableP() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 77"; end
  end
  -- ripple_in_space,if=essence.ripple_in_space.major
  if S.RippleInSpace:IsCastableP() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 79"; end
  end
end

local function Multi()
  -- maul,if=essence.conflict_and_strife.major&!buff.sharpened_claws.up
  if S.Maul:IsReadyP() and UseMaul and (Spell:MajorEssenceEnabled(AE.ConflictandStrife) and Player:BuffDownP(S.SharpenedClawsBuff)) then
    if HR.Cast(S.Maul, nil, nil, "Melee") then return "maul 91"; end
  end
  -- ironfur,if=(rage>=cost&azerite.layered_mane.enabled)|rage.deficit<10
  if S.Ironfur:IsReadyP() and (S.LayeredMane:AzeriteEnabled() or Player:RageDeficit() < 10) then
    if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur 93"; end
  end
  -- thrash,if=(buff.incarnation.up&active_enemies>=4)|cooldown.thrash_bear.up
  if S.Thrash:IsCastableP() and ((Player:BuffP(S.IncarnationBuff) and Cache.EnemiesCount[8] >= 4) or S.Thrash:CooldownUpP()) then
    if HR.Cast(S.Thrash, nil, nil, 8) then return "thrash 95"; end
  end
  -- mangle,if=buff.incarnation.up&active_enemies=3&dot.thrash_bear.ticking
  if S.Mangle:IsCastableP() and (Player:BuffP(S.IncarnationBuff) and Cache.EnemiesCount[8] == 3 and Target:DebuffP(S.ThrashBearDebuff)) then
    if HR.Cast(S.Mangle, nil, nil, "Melee") then return "mangle 97"; end
  end
  -- moonfire,if=dot.moonfire.refreshable&active_enemies<=4
  if S.Moonfire:IsCastableP() and (Target:DebuffRefreshableCP(S.MoonfireDebuff) and Cache.EnemiesCount[8] <= 4) then
    if HR.Cast(S.Moonfire, nil, nil, 40) then return "moonfire 98"; end
  end
  -- swipe,if=buff.incarnation.down
  if S.Swipe:IsCastableP() and (Player:BuffDownP(S.IncarnationBuff)) then
    if HR.Cast(S.Swipe, nil, nil, 8) then return "swipe 99"; end
  end
end

local function Cooldowns()
  -- potion
  if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 10"; end
  end
  if (HR.CDsON()) then
    -- blood_fury
    if S.BloodFury:IsCastableP() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 12"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 14"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 16"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 18"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 20"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 22"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastableP() then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 24"; end
    end
  end
  -- Defensives and Bristling Fur
  if IsTanking and Player:BuffP(S.BearForm) then
    if Player:HealthPercentage() < Settings.Guardian.FrenziedRegenHP and S.FrenziedRegeneration:IsCastableP() and Player:Rage() > 10 and Player:BuffDown(S.FrenziedRegeneration) and not Player:HealingAbsorbed() then
      if HR.Cast(S.FrenziedRegeneration, Settings.Guardian.GCDasOffGCD.FrenziedRegen) then return "frenzied_regen defensive"; end
    end
    if S.Ironfur:IsCastableP() and Player:Rage() >= S.Ironfur:Cost() + 1 and IsTanking and (Player:BuffDown(S.Ironfur) or (Player:BuffStack(S.Ironfur) < 2 and Player:BuffRefreshableP(S.Ironfur, 2.4))) then
      if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur defensive"; end
    end
    -- barkskin,if=buff.bear_form.up
    if S.Barkskin:IsCastableP() and Player:HealthPercentage() < Settings.Guardian.BarkskinHP then
      if HR.Cast(S.Barkskin, Settings.Guardian.OffGCDasOffGCD.Barkskin) then return "barkskin 24"; end
    end
    -- lunar_beam,if=buff.bear_form.up
    if S.LunarBeam:IsCastableP() and Player:HealthPercentage() < Settings.Guardian.LunarBeamHP then
      if HR.Cast(S.LunarBeam, Settings.Guardian.GCDasOffGCD.LunarBeam, nil, 40) then return "lunar_beam 28"; end
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
    if HR.Cast(S.Incarnation, Settings.Guardian.GCDasOffGCD.Incarnation) then return "incarnation 33"; end
  end
  -- use_item,name=ashvanes_razor_coral,if=((equipped.cyclotronic_blast&cooldown.cyclotronic_blast.remains>25&debuff.razor_coral_debuff.down)|debuff.razor_coral_debuff.down|(debuff.razor_coral_debuff.up&debuff.conductive_ink_debuff.up&target.time_to_pct_30<=2)|(debuff.razor_coral_debuff.up&time_to_die<=20))
  if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (((Everyone.PSCDEquipped() and I.PocketsizedComputationDevice:CooldownRemains() > 25 and Target:DebuffDownP(S.RazorCoralDebuff)) or Target:DebuffDownP(S.RazorCoralDebuff) or (Target:DebuffP(S.RazorCoralDebuff) and Target:DebuffP(S.ConductiveInkDebuff) and Target:TimeToX(30) <= 2) or (Target:DebuffP(S.RazorCoralDebuff) and Target:TimeToDie() <= 20))) then
    if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 35"; end
  end
  -- use_item,effect_name=cyclotronic_blast
  if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "cyclotronic_blast 37"; end
  end
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  AoERadius = S.BalanceAffinity:IsAvailable() and 11 or 8
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  EnemiesCount = Cache.EnemiesCount[AoERadius]
  IsTanking = Player:IsTankingAoE(AoERadius) or Player:IsTanking(Target)
  UseMaul = false
  if (not Settings.Guardian.UseRageDefensively or (Settings.Guardian.UseRageDefensively and (not IsTanking or Player:RageDeficit() <= 10))) then
    UseMaul = true
  end

  -- call precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Charge if out of range
    if S.WildChargeTalent:IsAvailable() and S.WildChargeBear:IsCastableP() and not Target:IsInRange(AoERadius) and Target:IsInRange(25) then
      if HR.Cast(S.WildChargeBear, nil, nil, 25) then return "wild_charge in_combat"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(13, S.SkullBash, Settings.Commons.OffGCDasOffGCD.SkullBash, false); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- call_action_list,name=cooldowns
    if (true) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=essences
    if (true) then
      local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies<=2
    if (Cache.EnemiesCount[8] <= 2) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=multi,if=active_enemies>=3
    if (Cache.EnemiesCount[8] >= 3) then
      local ShouldReturn = Multi(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(104, APL, Init)

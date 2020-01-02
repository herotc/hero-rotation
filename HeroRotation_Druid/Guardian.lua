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
  IncarnationBuff                       = Spell(102558),
  Thrash                                = MultiSpell(77758, 106830),
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
  AnimaofDeath                          = MultiSpell(294926, 300002, 300003),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  Conflict                              = MultiSpell(303823, 304088, 304121),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlameMajor                = MultiSpell(295373, 299349, 299353),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  HeartEssence                          = Spell(298554),
  SharpenedClawsBuff                    = Spell(279943),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565)
};
local S = Spell.Druid.Guardian;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Guardian = {
  PotionofFocusedResolve           = Item(168506),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14})
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

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cleave, Essences, Multi, Cooldowns
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
  Cleave = function()
    -- maul,if=rage.deficit<=10
    if S.Maul:IsReadyP() and (Player:RageDeficit() <= 10) then
      if HR.Cast(S.Maul) then return "maul 51"; end
    end
    -- ironfur,if=cost<=0
    if S.Ironfur:IsReadyP() and (S.Ironfur:Cost() <= 0) then
      if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur 53"; end
    end
    -- pulverize,target_if=dot.thrash_bear.stack=dot.thrash_bear.max_stacks
    if S.Pulverize:IsReadyP() and (Target:DebuffStackP(S.ThrashBearDebuff) == 3) then
      if HR.Cast(S.Pulverize) then return "pulverize 55"; end
    end
    -- moonfire,target_if=!dot.moonfire.ticking
    if S.Moonfire:IsCastableP() and (Target:DebuffDownP(S.MoonfireDebuff)) then
      if HR.Cast(S.Moonfire) then return "moonfire 57"; end
    end
    -- mangle,if=dot.thrash_bear.ticking
    if S.Mangle:IsCastableP() and (Target:DebuffP(S.ThrashBearDebuff)) then
      if HR.Cast(S.Mangle) then return "mangle 59"; end
    end
    -- moonfire,target_if=buff.galactic_guardian.up&active_enemies=1|dot.moonfire.refreshable
    if S.Moonfire:IsCastableP() and (Player:BuffP(S.GalacticGuardianBuff) and Cache.EnemiesCount[8] == 1 or Target:DebuffRefreshableCP(S.Moonfire)) then
      if HR.Cast(S.Moonfire) then return "moonfire 61"; end
    end
    -- maul
    if S.Maul:IsReadyP() then
      if HR.Cast(S.Maul) then return "maul 63"; end
    end
    -- thrash
    if S.Thrash:IsCastableP() then
      if HR.Cast(S.Thrash) then return "thrash 65"; end
    end
    -- swipe
    if S.Swipe:IsCastableP() then
      if HR.Cast(S.Swipe) then return "swipe 67"; end
    end
  end
  Essences = function()
    -- concentrated_flame,if=essence.the_crucible_of_flame.major&((!dot.concentrated_flame_burn.ticking&!action.concentrated_flame_missile.in_flight)^time_to_die<=7)
    if S.ConcentratedFlame:IsCastableP() and ((Target:DebuffDownP(S.ConcentratedFlameBurn) and not S.ConcentratedFlame:InFlight()) or Target:TimeToDie() <= 7) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame 71"; end
    end
    -- anima_of_death,if=essence.anima_of_life_and_death.major
    if S.AnimaofDeath:IsCastableP() then
      if HR.Cast(S.AnimaofDeath, nil, Settings.Commons.EssenceDisplayStyle) then return "anima_of_death 73"; end
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
  Multi = function()
    -- maul,if=essence.conflict_and_strife.major&!buff.sharpened_claws.up
    if S.Maul:IsReadyP() and (not S.Conflict:IsAvailable() and Player:BuffDownP(S.SharpenedClawsBuff)) then
      if HR.Cast(S.Maul) then return "maul 91"; end
    end
    -- ironfur,if=(rage>=cost&azerite.layered_mane.enabled)|rage.deficit<10
    if S.Ironfur:IsReadyP() and (S.LayeredMane:AzeriteEnabled() or Player:RageDeficit() < 10) then
      if HR.Cast(S.Ironfur, Settings.Guardian.OffGCDasOffGCD.Ironfur) then return "ironfur 93"; end
    end
    -- thrash,if=(buff.incarnation.up&active_enemies>=4)|cooldown.thrash_bear.up
    if S.Thrash:IsCastableP() and ((Player:BuffP(S.IncarnationBuff) and Cache.EnemiesCount[8] >= 4) or S.Thrash:CooldownUpP()) then
      if HR.Cast(S.Thrash) then return "thrash 95"; end
    end
    -- mangle,if=buff.incarnation.up&active_enemies=3&dot.thrash_bear.ticking
    if S.Mangle:IsCastableP() and (Player:BuffP(S.IncarnationBuff) Cache.EnemiesCount[8] == 3 and Target:DebuffP(S.ThrashBearDebuff)) then
      if HR.Cast(S.Mangle) then return "mangle 97"; end
    end
    -- moonfire,if=dot.moonfire.refreshable&active_enemies<=4
    if S.Moonfire:IsCastableP() and (Target:DebuffRefreshableCP(S.MoonfireDebuff) and Cache.EnemiesCount[8] <= 4) then
      if HR.Cast(S.Moonfire) then return "moonfire 98"; end
    end
    -- swipe,if=buff.incarnation.down
    if S.Swipe:IsCastableP() and (Player:BuffDownP(S.IncarnationBuff)) then
      if HR.Cast(S.Swipe) then return "swipe 99"; end
    end
  end
  Cooldowns = function()
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 10"; end
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
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment 18"; end
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
        and Player:BuffDown(S.FrenziedRegeneration) and not Player:HealingAbsorbed() then
        if HR.Cast(S.FrenziedRegeneration, Settings.Guardian.GCDasOffGCD.FrenziedRegen) then return "frenzied_regen defensive"; end
      end
      if S.Ironfur:IsCastableP() and Player:Rage() >= S.Ironfur:Cost() + 1 and IsTanking and (Player:BuffDown(S.Ironfur) 
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
    -- use_item,name=ashvanes_razor_coral,if=((equipped.cyclotronic_blast&cooldown.cyclotronic_blast.remains>25&debuff.razor_coral_debuff.down)|debuff.razor_coral_debuff.down|(debuff.razor_coral_debuff.up&debuff.conductive_ink_debuff.up&target.time_to_pct_30<=2)|(debuff.razor_coral_debuff.up&time_to_die<=20))
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (((Everyone.PSCDEquipped() and I.PocketsizedComputationDevice:CooldownRemainsP() > 25 and Target:DebuffDownP(S.RazorCoralDebuff)) or Target:DebuffDownP(S.RazorCoralDebuff) or (Target:DebuffP(S.RazorCoralDebuff) and Target:DebuffP(S.ConductiveInkDebuff) and Target:TimeToX(30) <= 2) or (Target:DebuffP(S.RazorCoralDebuff) and Target:TimeToDie() <= 20))) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral 35"; end
    end
    -- use_item,effect_name=cyclotronic_blast
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "cyclotronic_blast 37"; end
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

local function Init ()
  HL.RegisterNucleusAbility(77758, 8, 6)               -- Thrash (Bear)
  HL.RegisterNucleusAbility(213771, 8, 6)              -- Swipe (Bear)
end

HR.SetAPL(104, APL, Init)
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
Spell.Druid.Feral = {
  Regrowth                              = Spell(8936),
  BloodtalonsBuff                       = Spell(145152),
  Bloodtalons                           = Spell(155672),
  WildFleshrending                      = Spell(279527),
  CatFormBuff                           = Spell(768),
  CatForm                               = Spell(768),
  ProwlBuff                             = Spell(5215),
  Prowl                                 = Spell(5215),
  BerserkBuff                           = Spell(106951),
  Berserk                               = Spell(106951),
  TigersFury                            = Spell(5217),
  TigersFuryBuff                        = Spell(5217),
  Berserking                            = Spell(26297),
  FeralFrenzy                           = Spell(274837),
  Incarnation                           = Spell(102543),
  IncarnationBuff                       = Spell(102543),
  BalanceAffinity                       = Spell(197488),
  Shadowmeld                            = Spell(58984),
  Rake                                  = Spell(1822),
  RakeDebuff                            = Spell(155722),
  SavageRoar                            = Spell(52610),
  SavageRoarBuff                        = Spell(52610),
  PrimalWrath                           = Spell(285381),
  RipDebuff                             = Spell(1079),
  Rip                                   = Spell(1079),
  Sabertooth                            = Spell(202031),
  Maim                                  = Spell(22570),
  IronJawsBuff                          = Spell(276026),
  FerociousBiteMaxEnergy                = Spell(22568),
  FerociousBite                         = Spell(22568),
  PredatorySwiftnessBuff                = Spell(69369),
  LunarInspiration                      = Spell(155580),
  BrutalSlash                           = Spell(202028),
  ThrashCat                             = Spell(106830),
  ThrashCatDebuff                       = Spell(106830),
  ScentofBlood                          = Spell(285564),
  ScentofBloodBuff                      = Spell(285646),
  SwipeCat                              = Spell(106785),
  MoonfireCat                           = Spell(155625),
  MoonfireCatDebuff                     = Spell(155625),
  ClearcastingBuff                      = Spell(135700),
  Shred                                 = Spell(5221),
  SkullBash                             = Spell(106839),
  ShadowmeldBuff                        = Spell(58984),
  JungleFury                            = Spell(274424),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  ReapingFlames                         = Spell(310690),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  Thorns                                = Spell(236696),
  -- Icon for pooling energy
  PoolResource                          = Spell(9999000010)
};
local S = Spell.Druid.Feral;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Feral = {
  PotionofFocusedResolve                = Item(168506),
  AzsharasFontofPower                   = Item(169314, {13, 14}),
  AshvanesRazorCoral                    = Item(169311, {13, 14}),
  PocketsizedComputationDevice          = Item(167555, {13, 14})
};
local I = Item.Druid.Feral;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = { 169314, 169311, 167555 }

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local MeleeRange = 5;
local EightRange = 8;
local InterruptRange = 13;
local FortyRange = 40;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Feral = HR.GUISettings.APL.Druid.Feral
};

-- Variables
local VarUseThrash = 0;
local VarOpenerDone = 0;
local VarReapingDelay = 0;
local LastRakeAP = 0;

HL:RegisterForEvent(function()
  VarUseThrash = 0
  VarOpenerDone = 0
  VarReapingDelay = 0
  LastRakeAP = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {40, 8, 5}
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

local function LowestTTD()
  local lowTTD = 0
  for _, CycleUnit in pairs(Cache.Enemies[EightRange]) do
    if (lowTTD == 0 or CycleUnit:TimeToDie() < lowTTD) then
      lowTTD = CycleUnit:TimeToDie()
    end
  end
  return lowTTD
end

local function SwipeBleedMult()
  return (Target:DebuffP(S.RipDebuff) or Target:DebuffP(S.RakeDebuff) or Target:DebuffP(S.ThrashCatDebuff)) and 1.2 or 1;
end

local function RakeBleedTick()
  return LastRakeAP * 0.15561 * (1 + Player:VersatilityDmgPct()/100);
end

S.Rake:RegisterDamage(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() * 
      -- Rake Modifier
      0.18225 *
      -- Stealth Modifier
      (Player:IsStealthed(true, false) and 2 or 1) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);

S.Shred:RegisterDamage(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Shred Modifier
      0.46 * 
      ((math.min(Player:Level(), 19) * 18 + 353) / 695) *
      -- Bleeding Bonus
      SwipeBleedMult() *
      -- Stealth Modifier
      (Player:IsStealthed(true, false) and 1.3 or 1) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);

S.SwipeCat:RegisterDamage(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Swipe Modifier
      0.2875 * 
      -- Bleeding Bonus
      SwipeBleedMult() *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);

S.BrutalSlash:RegisterDamage(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() * 
      -- Brutal Slash Modifier
      0.69 *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);

S.FerociousBiteMaxEnergy.CustomCost = {
  [3] = function ()
          if (Player:BuffP(S.IncarnationBuff) or Player:BuffP(S.BerserkBuff)) then return 25
          else return 50
          end
        end
}

S.Rip:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15})
S.Rake:RegisterPMultiplier(
  S.RakeDebuff,
  {function ()
    return Player:IsStealthed(true, true) and 2 or 1;
  end},
  {S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15}
)

local function EvaluateCyclePrimalWrath95(TargetUnit)
  return Cache.EnemiesCount[MeleeRange] > 1 and TargetUnit:DebuffRemainsP(S.RipDebuff) < 4
end

local function EvaluateCyclePrimalWrath106(TargetUnit)
  return Cache.EnemiesCount[MeleeRange] >= 2
end

local function EvaluateCycleRip115(TargetUnit)
  return TargetUnit:DebuffDownP(S.RipDebuff) or (TargetUnit:DebuffRemainsP(S.RipDebuff) <= S.RipDebuff:BaseDuration() * 0.3) and (not S.Sabertooth:IsAvailable()) or (TargetUnit:DebuffRemainsP(S.RipDebuff) <= S.RipDebuff:BaseDuration() * 0.8 and Player:PMultiplier(S.Rip) > TargetUnit:PMultiplier(S.Rip)) and TargetUnit:TimeToDie() > 8
end

local function EvaluateCycleRake228(TargetUnit)
  return TargetUnit:DebuffDownP(S.RakeDebuff) or (not S.Bloodtalons:IsAvailable() and TargetUnit:DebuffRemainsP(S.RakeDebuff) < S.RakeDebuff:BaseDuration() * 0.3) and TargetUnit:TimeToDie() > 4
end

local function EvaluateCycleRake257(TargetUnit)
  return S.Bloodtalons:IsAvailable() and Player:BuffP(S.BloodtalonsBuff) and ((TargetUnit:DebuffRemainsP(S.RakeDebuff) <= 7) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake) * 0.85) and TargetUnit:TimeToDie() > 4
end

local function EvaluateCycleMoonfireCat302(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireCatDebuff)
end

local function EvaluateCycleFerociousBite418(TargetUnit)
  return TargetUnit:DebuffP(S.RipDebuff) and TargetUnit:DebuffRemainsP(S.RipDebuff) < 3 and TargetUnit:TimeToDie() > 10 and (S.Sabertooth:IsAvailable())
end

local function EvaluateCycleReapingFlames420(TargetUnit)
  return TargetUnit:TimeToDie() < 1.5 or ((TargetUnit:HealthPercentage() > 80 or TargetUnit:HealthPercentage() <= 20) and VarReapingDelay > 29) or (TargetUnit:TimeToX(20) > 30 and VarReapingDelay > 44)
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns, Finishers, Generators, Opener
  --UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  if (Player:PrevGCD(1, S.Rake)) then
    LastRakeAP = Player:AttackPowerDamageMod()
  end
  MeleeRange = S.BalanceAffinity:IsAvailable() and 8 or 5
  EightRange = S.BalanceAffinity:IsAvailable() and 11 or 8
  InterruptRange = S.BalanceAffinity:IsAvailable() and 16 or 13
  FortyRange = S.BalanceAffinity:IsAvailable() and 43 or 40
  HL.GetEnemies(MeleeRange)
  HL.GetEnemies(EightRange)
  HL.GetEnemies(InterruptRange)
  HL.GetEnemies(FortyRange)
  HL.GetEnemies("Melee")
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- variable,name=use_thrash,value=0
      if (true) then
        VarUseThrash = 0
      end
      -- variable,name=use_thrash,value=2,if=azerite.wild_fleshrending.enabled
      if (S.WildFleshrending:AzeriteEnabled()) then
        VarUseThrash = 2
      end
      -- regrowth,if=talent.bloodtalons.enabled
      if S.Regrowth:IsCastableP() and (S.Bloodtalons:IsAvailable()) then
        if HR.Cast(S.Regrowth) then return "regrowth 3"; end
      end
      -- use_item,name=azsharas_font_of_power
      if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 10"; end
      end
      -- cat_form
      if S.CatForm:IsCastableP() and Player:BuffDownP(S.CatFormBuff) then
        if HR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "cat_form 15"; end
      end
      -- prowl
      if S.Prowl:IsCastableP() and Player:BuffDownP(S.ProwlBuff) then
        if HR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return "prowl 19"; end
      end
      -- potion,dynamic_prepot=1
      if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 24"; end
      end
      -- berserk
      if S.Berserk:IsCastableP() and Player:BuffDownP(S.BerserkBuff) and HR.CDsON() then
        if HR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "berserk 26"; end
      end
    end
  end
  Cooldowns = function()
    -- berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
    if S.Berserk:IsCastableP() and HR.CDsON() and (Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 5 or Player:BuffP(S.TigersFuryBuff))) then
      if HR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "berserk 30"; end
    end
    -- tigers_fury,if=energy.deficit>=60
    if S.TigersFury:IsCastableP() and (Player:EnergyDeficitPredicted() >= 60) then
      if HR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury 36"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 38"; end
    end
    -- thorns,if=active_enemies>desired_targets|raid_event.adds.in>45
    if S.Thorns:IsCastableP() and (Cache.EnemiesCount[EightRange] > 1) then
      if HR.Cast(S.Thorns, nil, Settings.Commons.EssenceDisplayStyle) then return "thorns"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up|buff.tigers_fury.up
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or Player:BuffP(S.TigersFuryBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force"; end
    end
    -- memory_of_lucid_dreams,if=buff.tigers_fury.up&buff.berserk.down
    if S.MemoryofLucidDreams:IsCastableP() and (Player:BuffP(S.TigersFuryBuff) and Player:BuffDownP(S.BerserkBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    -- blood_of_the_enemy,if=buff.tigers_fury.up
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.TigersFuryBuff)) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
    end
    -- feral_frenzy,if=combo_points=0
    if S.FeralFrenzy:IsCastableP() and (Player:ComboPoints() == 0) then
      if HR.Cast(S.FeralFrenzy, nil, nil, MeleeRange) then return "feral_frenzy 40"; end
    end
    -- focused_azerite_beam,if=active_enemies>desired_targets|(raid_event.adds.in>90&energy.deficit>=50)
    if S.FocusedAzeriteBeam:IsCastableP() and (Cache.EnemiesCount[EightRange] > 1 or Settings.Feral.UseFABST) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
    end
    -- purifying_blast,if=active_enemies>desired_targets|raid_event.adds.in>60
    if S.PurifyingBlast:IsCastableP() and (Cache.EnemiesCount[EightRange] > 1) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast"; end
    end
    -- guardian_of_azeroth,if=buff.tigers_fury.up
    if S.GuardianofAzeroth:IsCastableP() and (Player:BuffP(S.TigersFuryBuff)) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    -- concentrated_flame,if=buff.tigers_fury.up
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffP(S.TigersFuryBuff)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame"; end
    end
    -- ripple_in_space,if=buff.tigers_fury.up
    if S.RippleInSpace:IsCastableP() and (Player:BuffP(S.TigersFuryBuff)) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
    end
    -- worldvein_resonance,if=buff.tigers_fury.up
    if S.WorldveinResonance:IsCastableP() and (Player:BuffP(S.TigersFuryBuff)) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    -- reaping_flames,target_if=target.time_to_die<1.5|((target.health.pct>80|target.health.pct<=20)&variable.reaping_delay>29)|(target.time_to_pct_20>30&variable.reaping_delay>44)
    if S.ReapingFlames:IsCastableP() then
      if HR.CastCycle(S.ReapingFlames, EightRange, EvaluateCycleReapingFlames420) then return "reaping_flames 41"; end
    end
    -- incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
    if S.Incarnation:IsCastableP() and HR.CDsON() and (Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 15 or Player:BuffP(S.TigersFuryBuff))) then
      if HR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Incarnation) then return "incarnation 42"; end
    end
    -- potion,if=target.time_to_die<65|(time_to_die<180&(buff.berserk.up|buff.incarnation.up))
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Target:TimeToDie() < 65 or (Target:TimeToDie() < 180 and (Player:BuffP(S.BerserkBuff) or Player:BuffP(S.IncarnationBuff)))) then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 48"; end
    end
    -- shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
    if S.Shadowmeld:IsCastableP() and HR.CDsON() and (Player:ComboPoints() < 5 and Player:EnergyPredicted() >= S.Rake:Cost() and Target:PMultiplier(S.Rake) < 2.1 and Player:BuffP(S.TigersFuryBuff) and (Player:BuffP(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and (not S.Incarnation:IsAvailable() or S.Incarnation:CooldownRemainsP() > 18) and Player:BuffDownP(S.IncarnationBuff)) then
      if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld 58"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|debuff.conductive_ink_debuff.up&target.time_to_pct_30<1.5|!debuff.conductive_ink_debuff.up&(debuff.razor_coral_debuff.stack>=25-10*debuff.blood_of_the_enemy.up|target.time_to_die<40)&buff.tigers_fury.remains>10
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or Target:DebuffP(S.ConductiveInkDebuff) and Target:TimeToX(30) < 1.5 or Target:DebuffDownP(S.ConductiveInkDebuff) and (Target:DebuffStackP(S.RazorCoralDebuff) >= 25 - 10 * num(Target:DebuffP(S.BloodoftheEnemy)) or Target:TimeToDie() < 40) and Player:BuffRemainsP(S.TigersFuryBuff) > 10) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "ashvanes_razor_coral 59"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=(energy.deficit>=energy.regen*3)&buff.tigers_fury.down&!azerite.jungle_fury.enabled
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and ((Player:EnergyDeficitPredicted() >= Player:EnergyRegen() * 3) and Player:BuffDownP(S.TigersFuryBuff) and not S.JungleFury:AzeriteEnabled()) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "cyclotronic_blast 60"; end
    end
    -- use_item,effect_name=cyclotronic_blast,if=buff.tigers_fury.up&azerite.jungle_fury.enabled
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffP(S.TigersFuryBuff) and S.JungleFury:AzeriteEnabled()) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "cyclotronic_blast 61"; end
    end
    -- use_item,effect_name=azsharas_font_of_power,if=energy.deficit>=50
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:EnergyDeficitPredicted() >= 50) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 62"; end
    end
    -- use_items,if=buff.tigers_fury.up|target.time_to_die<20
    if (Player:BuffP(S.TigersFuryBuff) or Target:TimeToDie() < 20) then
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
  end
  Finishers = function()
    -- pool_resource,for_next=1
    -- savage_roar,if=buff.savage_roar.down
    if S.SavageRoar:IsCastableP() and (Player:BuffDownP(S.SavageRoarBuff)) then
      if HR.CastPooling(S.SavageRoar) then return "savage_roar 84"; end
    end
    -- pool_resource,for_next=1
    -- primal_wrath,target_if=spell_targets.primal_wrath>1&dot.rip.remains<4
    if S.PrimalWrath:IsCastableP() then
      if HR.CastCycle(S.PrimalWrath, EightRange, EvaluateCyclePrimalWrath95) then return "primal_wrath 99" end
    end
    -- pool_resource,for_next=1
    -- primal_wrath,target_if=spell_targets.primal_wrath>=2
    if S.PrimalWrath:IsCastableP() then
      if HR.CastCycle(S.PrimalWrath, EightRange, EvaluateCyclePrimalWrath106) then return "primal_wrath 108" end
    end
    -- pool_resource,for_next=1
    -- rip,target_if=!ticking|(remains<=duration*0.3)&(!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
    if S.Rip:IsCastableP() then
      if HR.CastCycle(S.Rip, EightRange, EvaluateCycleRip115) then return "rip 155" end
    end
    -- pool_resource,for_next=1
    -- savage_roar,if=buff.savage_roar.remains<12
    if S.SavageRoar:IsCastableP() and (Player:BuffRemainsP(S.SavageRoarBuff) < 12) then
      if HR.CastPooling(S.SavageRoar) then return "savage_roar 157"; end
    end
    -- pool_resource,for_next=1
    -- maim,if=buff.iron_jaws.up
    if S.Maim:IsCastableP() and (Player:BuffP(S.IronJawsBuff)) then
      if HR.CastPooling(S.Maim, nil, nil, MeleeRange) then return "maim 163"; end
    end
    -- ferocious_bite,max_energy=1
    if S.FerociousBiteMaxEnergy:IsReadyP() and Player:ComboPoints() > 0 then
      if HR.Cast(S.FerociousBiteMaxEnergy, nil, nil, MeleeRange) then return "ferocious_bite 168"; end
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.Cast(S.PoolResource) then return "pool_resource"; end
    end
  end
  Generators = function()
    -- regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
    if S.Regrowth:IsCastableP() and (S.Bloodtalons:IsAvailable() and Player:BuffP(S.PredatorySwiftnessBuff) and Player:BuffDownP(S.BloodtalonsBuff) and Player:ComboPoints() == 4 and Target:DebuffRemainsP(S.RakeDebuff) < 4) then
      if HR.Cast(S.Regrowth) then return "regrowth 174"; end
    end
    -- regrowth,if=talent.bloodtalons.enabled&buff.bloodtalons.down&buff.predatory_swiftness.up&talent.lunar_inspiration.enabled&dot.rake.remains<1
    if S.Regrowth:IsCastableP() and (S.Bloodtalons:IsAvailable() and Player:BuffDownP(S.BloodtalonsBuff) and Player:BuffP(S.PredatorySwiftnessBuff) and S.LunarInspiration:IsAvailable() and Target:DebuffRemainsP(S.RakeDebuff) < 1) then
      if HR.Cast(S.Regrowth) then return "regrowth 184"; end
    end
    -- brutal_slash,if=spell_targets.brutal_slash>desired_targets
    if S.BrutalSlash:IsCastableP() and (Cache.EnemiesCount[EightRange] > 1) then
      if HR.Cast(S.BrutalSlash, nil, nil, EightRange) then return "brutal_slash 196"; end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,if=(refreshable)&(spell_targets.thrash_cat>2)
    if S.ThrashCat:IsCastableP() and ((Target:DebuffRefreshableCP(S.ThrashCatDebuff)) and (Cache.EnemiesCount[EightRange] > 2)) then
      if HR.CastPooling(S.ThrashCat, nil, nil, EightRange) then return "thrash_cat 199"; end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,if=(talent.scent_of_blood.enabled&buff.scent_of_blood.down)&spell_targets.thrash_cat>3
    if S.ThrashCat:IsCastableP() and ((S.ScentofBlood:IsAvailable() and Player:BuffDownP(S.ScentofBloodBuff)) and Cache.EnemiesCount[EightRange] > 3) then
      if HR.CastPooling(S.ThrashCat, nil, nil, EightRange) then return "thrash_cat 209"; end
    end
    -- pool_resource,for_next=1
    -- swipe_cat,if=buff.scent_of_blood.up|(action.swipe_cat.damage*spell_targets.swipe_cat>(action.rake.damage+(action.rake_bleed.tick_damage*5)))
    if S.SwipeCat:IsCastableP() and (Player:BuffP(S.ScentofBloodBuff) or ((S.SwipeCat:Damage() * Cache.EnemiesCount[EightRange]) > (S.Rake:Damage() + (RakeBleedTick() * 5)))) then
      if HR.CastPooling(S.SwipeCat, nil, nil, EightRange) then return "swipe_cat 217"; end
    end
    -- pool_resource,for_next=1
    -- rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
    if S.Rake:IsCastableP() then
      if HR.CastCycle(S.Rake, EightRange, EvaluateCycleRake228) then return "rake 250" end
    end
    -- pool_resource,for_next=1
    -- rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
    if S.Rake:IsCastableP() then
      if HR.CastCycle(S.Rake, EightRange, EvaluateCycleRake257) then return "rake 275" end
    end
    -- moonfire_cat,if=buff.bloodtalons.up&buff.predatory_swiftness.down&combo_points<5
    if S.MoonfireCat:IsCastableP() and (Player:BuffP(S.BloodtalonsBuff) and Player:BuffDownP(S.PredatorySwiftnessBuff) and Player:ComboPoints() < 5) then
      if HR.Cast(S.MoonfireCat, nil, nil, FortyRange) then return "moonfire_cat 276"; end
    end
    -- brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))&(spell_targets.brutal_slash*action.brutal_slash.damage%action.brutal_slash.cost)>(action.shred.damage%action.shred.cost)
    if S.BrutalSlash:IsCastableP() and ((Player:BuffP(S.TigersFuryBuff) and (10000000000 > (1 + S.BrutalSlash:MaxCharges() - S.BrutalSlash:ChargesFractionalP()) * S.BrutalSlash:RechargeP())) and (Cache.EnemiesCount[EightRange] * S.BrutalSlash:Damage() % S.BrutalSlash:Cost()) > (S.Shred:Damage() % S.Shred:Cost())) then
      if HR.Cast(S.BrutalSlash, nil, nil, EightRange) then return "brutal_slash 282"; end
    end
    -- moonfire_cat,target_if=refreshable
    if S.MoonfireCat:IsCastableP() then
      if HR.CastCycle(S.MoonfireCat, FortyRange, EvaluateCycleMoonfireCat302) then return "moonfire_cat 310" end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,if=refreshable&((variable.use_thrash=2&(!buff.incarnation.up|azerite.wild_fleshrending.enabled))|spell_targets.thrash_cat>1)
    if S.ThrashCat:IsCastableP() and (Target:DebuffRefreshableCP(S.ThrashCatDebuff) and ((VarUseThrash == 2 and (Player:BuffDownP(S.IncarnationBuff) or S.WildFleshrending:AzeriteEnabled())) or Cache.EnemiesCount[EightRange] > 1)) then
      if HR.CastPooling(S.ThrashCat, nil, nil, EightRange) then return "thrash_cat 312"; end
    end
    -- thrash_cat,if=refreshable&variable.use_thrash=1&buff.clearcasting.react&(!buff.incarnation.up|azerite.wild_fleshrending.enabled)
    if S.ThrashCat:IsCastableP() and (Target:DebuffRefreshableCP(S.ThrashCatDebuff) and VarUseThrash == 1 and bool(Player:BuffStackP(S.ClearcastingBuff)) and (Player:BuffDownP(S.IncarnationBuff) or S.WildFleshrending:AzeriteEnabled())) then
      if HR.Cast(S.ThrashCat, nil, nil, EightRange) then return "thrash_cat 327"; end
    end
    -- pool_resource,for_next=1
    -- swipe_cat,if=spell_targets.swipe_cat>1
    if S.SwipeCat:IsCastableP() and (Cache.EnemiesCount[EightRange] > 1) then
      if HR.CastPooling(S.SwipeCat, nil, nil, EightRange) then return "swipe_cat 344"; end
    end
    -- shred,if=dot.rake.remains>(action.shred.cost+action.rake.cost-energy)%energy.regen|buff.clearcasting.react
    if S.Shred:IsCastableP() and (Target:DebuffRemainsP(S.RakeDebuff) > (S.Shred:Cost() + S.Rake:Cost() - Player:EnergyPredicted()) / Player:EnergyRegen() or bool(Player:BuffStackP(S.ClearcastingBuff))) then
      if HR.Cast(S.Shred, nil, nil, MeleeRange) then return "shred 347"; end
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.Cast(S.PoolResource) then return "pool_resource"; end
    end
  end
  Opener = function()
    -- tigers_fury
    if S.TigersFury:IsCastableP() then
      if HR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury 363"; end
    end
    -- rake,if=!ticking|buff.prowl.up
    if S.Rake:IsCastableP() and (Target:DebuffDownP(S.RakeDebuff) or Player:BuffP(S.ProwlBuff)) then
      if HR.Cast(S.Rake, nil, nil, MeleeRange) then return "rake 365"; end
    end
    -- variable,name=opener_done,value=dot.rip.ticking
    if (true) then
      VarOpenerDone = num(Target:DebuffP(S.RipDebuff))
    end
    -- wait,sec=0.001,if=dot.rip.ticking
    -- moonfire_cat,if=!ticking
    if S.MoonfireCat:IsCastableP() and (Target:DebuffDownP(S.MoonfireCatDebuff)) then
      if HR.Cast(S.MoonfireCat, nil, nil, FortyRange) then return "moonfire_cat 380"; end
    end
    -- rip,if=!ticking
    -- Manual addition: Use Primal Wrath if >= 2 targets or Rip if only 1 target
    if S.PrimalWrath:IsCastableP() and (S.PrimalWrath:IsAvailable() and Target:DebuffDownP(S.RipDebuff) and Cache.EnemiesCount[EightRange] >= 2) then
      if HR.Cast(S.PrimalWrath, nil, nil, EightRange) then return "primal_wrath opener"; end
    end
    if S.Rip:IsCastableP() and (Target:DebuffDownP(S.RipDebuff)) then
      if HR.Cast(S.Rip, nil, nil, MeleeRange) then return "rip 388"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    Everyone.Interrupt(InterruptRange, S.SkullBash, Settings.Commons.OffGCDasOffGCD.SkullBash, false);
    -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
    -- run_action_list,name=opener,if=variable.opener_done=0
    if (VarOpenerDone == 0) then
      return Opener();
    end
    -- cat_form,if=!buff.cat_form.up
    if S.CatForm:IsCastableP() and (Player:BuffDownP(S.CatFormBuff)) then
      if HR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "cat_form 402"; end
    end
    -- rake,if=buff.prowl.up|buff.shadowmeld.up
    if S.Rake:IsCastableP() and (Player:BuffP(S.ProwlBuff) or Player:BuffP(S.ShadowmeldBuff)) then
      if HR.Cast(S.Rake, nil, nil, MeleeRange) then return "rake 406"; end
    end
    -- variable,name=reaping_delay,value=target.time_to_die,if=variable.reaping_delay=0
    if (VarReapingDelay == 0) then
      VarReapingDelay = Target:TimeToDie()
    end
    -- cycling_variable,name=reaping_delay,op=min,value=target.time_to_die
    if (true) then
      VarReapingDelay = LowestTTD()
    end
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- ferocious_bite,target_if=dot.rip.ticking&dot.rip.remains<3&target.time_to_die>10&(talent.sabertooth.enabled)
    if S.FerociousBite:IsReadyP() and Player:ComboPoints() > 0 then
      if HR.CastCycle(S.FerociousBite, EightRange, EvaluateCycleFerociousBite418) then return "ferocious_bite 426" end
    end
    -- regrowth,if=combo_points=5&buff.predatory_swiftness.up&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8)
    if S.Regrowth:IsCastableP() and (Player:ComboPoints() == 5 and Player:BuffP(S.PredatorySwiftnessBuff) and S.Bloodtalons:IsAvailable() and Player:BuffDownP(S.BloodtalonsBuff) and (Player:BuffDownP(S.IncarnationBuff) or Target:DebuffRemainsP(S.RipDebuff) < 8)) then
      if HR.Cast(S.Regrowth) then return "regrowth 427"; end
    end
    -- run_action_list,name=finishers,if=combo_points>4
    if (Player:ComboPoints() > 4) then
      return Finishers();
    end
    -- run_action_list,name=generators
    if (true) then
      return Generators();
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.Cast(S.PoolResource) then return "pool_resource"; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(285381, 8, 6)               -- Primal Wrath
  HL.RegisterNucleusAbility(202028, 8, 6)               -- Brutal Slash
  HL.RegisterNucleusAbility(106830, 8, 6)               -- Thrash (Cat)
  HL.RegisterNucleusAbility(106785, 8, 6)               -- Swipe (Cat)
end

HR.SetAPL(103, APL, Init)

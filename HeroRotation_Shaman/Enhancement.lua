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
if not Spell.Shaman then Spell.Shaman = {} end
Spell.Shaman.Enhancement = {
  LightningShield                       = Spell(192106),
  CrashLightning                        = Spell(187874),
  CrashLightningBuff                    = Spell(187874),
  Rockbiter                             = Spell(193786),
  Landslide                             = Spell(197992),
  LandslideBuff                         = Spell(202004),
  Windstrike                            = Spell(115356),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  AscendanceBuff                        = Spell(114051),
  Ascendance                            = Spell(114051),
  FeralSpirit                           = Spell(51533),
  MoltenWeaponBuff                      = Spell(224125),
  IcyEdgeBuff                           = Spell(224126),
  CracklingSurgeBuff                    = Spell(224127),
  EarthenSpikeDebuff                    = Spell(188089),
  EarthenSpike                          = Spell(188089),
  Stormstrike                           = Spell(17364),
  LightningConduit                      = Spell(275388),
  LightningConduitDebuff                = Spell(275391),
  StormbringerBuff                      = Spell(201845),
  GatheringStormsBuff                   = Spell(198300),
  LightningBolt                         = Spell(187837),
  Overcharge                            = Spell(210727),
  Sundering                             = Spell(197214),
  SunderingDebuff                       = Spell(197214),
  Thundercharge                         = Spell(204366),
  ForcefulWinds                         = Spell(262647),
  Flametongue                           = Spell(193796),
  SearingAssault                        = Spell(192087),
  LavaLash                              = Spell(60103),
  PrimalPrimer                          = Spell(272992),
  HotHand                               = Spell(201900),
  HotHandBuff                           = Spell(215785),
  StrengthofEarthBuff                   = Spell(273465),
  CrashingStorm                         = Spell(192246),
  Frostbrand                            = Spell(196834),
  Hailstorm                             = Spell(210853),
  FrostbrandBuff                        = Spell(196834),
  PrimalPrimerDebuff                    = Spell(273006),
  FlametongueBuff                       = Spell(194084),
  FuryofAir                             = Spell(197211),
  FuryofAirBuff                         = Spell(197211),
  TotemMastery                          = Spell(262395),
  NaturalHarmony                        = Spell(278697),
  NaturalHarmonyFrostBuff               = Spell(279029),
  NaturalHarmonyFireBuff                = Spell(279028),
  NaturalHarmonyNatureBuff              = Spell(279033),
  WindShear                             = Spell(57994),
  Boulderfist                           = Spell(246035),
  StrengthofEarth                       = Spell(273461),
  CapacitorTotem                        = Spell(192058),
  ElementalSpirits                      = Spell(262624),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
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
  RecklessForceBuff                     = Spell(302932),
  RecklessForceCounter                  = Spell(302917),
  SeethingRageBuff                      = Spell(297126),
  ConcentratedFlameBurn                 = Spell(295368),
};
local S = Spell.Shaman.Enhancement;

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Enhancement = {
  PotionofUnbridledFury            = Item(169299),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14})
};
local I = Item.Shaman.Enhancement;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Enhancement = HR.GUISettings.APL.Shaman.Enhancement
};

-- Variables
local VarFurycheckCl = 0;
local VarCooldownSync = 0;
local VarFurycheckEs = 0;
local VarFurycheckSs = 0;
local VarFurycheckLb = 0;
local VarOcpoolSs = 0;
local VarOcpoolCl = 0;
local VarOcpoolLl = 0;
local VarFurycheckLl = 0;
local VarFurycheckFb = 0;
local VarClpoolLl = 0;
local VarClpoolSs = 0;
local VarFreezerburnEnabled = 0;
local VarOcpool = 0;
local VarOcpoolFb = 0;
local VarRockslideEnabled = 0;

HL:RegisterForEvent(function()
  VarFurycheckCl = 0
  VarCooldownSync = 0
  VarFurycheckEs = 0
  VarFurycheckSs = 0
  VarFurycheckLb = 0
  VarOcpoolSs = 0
  VarOcpoolCl = 0
  VarOcpoolLl = 0
  VarFurycheckLl = 0
  VarFurycheckFb = 0
  VarClpoolLl = 0
  VarClpoolSs = 0
  VarFreezerburnEnabled = 0
  VarOcpool = 0
  VarOcpoolFb = 0
  VarRockslideEnabled = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {8, 5}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function ResonanceTotemTime()
  for index=1,4 do
    local _, totemName, startTime, duration = GetTotemInfo(index)
    if totemName == S.TotemMastery:Name() then
      return (floor(startTime + duration - GetTime() + 0.5)) or 0
    end
  end
  return 0
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function FeralSpiritRemains()
  if S.FeralSpirit:CooldownRemainsP() == 0 then return 0; end
  if S.ElementalSpirits:IsAvailable() then
    return (S.FeralSpirit:CooldownRemainsP() - 74)
  else
    return (S.FeralSpirit:CooldownRemainsP() - 104)
  end
end

local function SetVariables()
  -- variable,name=cooldown_sync,value=(talent.ascendance.enabled&(buff.ascendance.up|cooldown.ascendance.remains>50))|(!talent.ascendance.enabled&(feral_spirit.remains>5|cooldown.feral_spirit.remains>50))
  VarCooldownSync = num((S.Ascendance:IsAvailable() and (Player:BuffP(S.AscendanceBuff) or S.Ascendance:CooldownRemainsP() > 50)) or (not S.Ascendance:IsAvailable() and (FeralSpiritRemains() > 5 or S.FeralSpirit:CooldownRemainsP() > 50)))
  -- variable,name=furyCheck_SS,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.stormstrike.cost))
  VarFurycheckSs = num(Player:Maelstrom() >= (num(S.FuryofAir:IsAvailable()) * (6 + S.Stormstrike:Cost())))
  -- variable,name=furyCheck_LL,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.lava_lash.cost))
  VarFurycheckLl = num(Player:Maelstrom() >= (num(S.FuryofAir:IsAvailable()) * (6 + S.LavaLash:Cost())))
  -- variable,name=furyCheck_CL,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.crash_lightning.cost))
  VarFurycheckCl = num(Player:Maelstrom() >= (num(S.FuryofAir:IsAvailable()) * (6 + S.CrashLightning:Cost())))
  -- variable,name=furyCheck_FB,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.frostbrand.cost))
  VarFurycheckFb = num(Player:Maelstrom() >= (num(S.FuryofAir:IsAvailable()) * (6 + S.Frostbrand:Cost())))
  -- variable,name=furyCheck_ES,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.earthen_spike.cost))
  VarFurycheckEs = num(Player:Maelstrom() >= (num(S.FuryofAir:IsAvailable()) * (6 + S.EarthenSpike:Cost())))
  -- variable,name=furyCheck_LB,value=maelstrom>=(talent.fury_of_air.enabled*(6+40))
  VarFurycheckLb = num(Player:Maelstrom() >= (num(S.FuryofAir:IsAvailable()) * (6 + 40)))
  -- variable,name=OCPool,value=(active_enemies>1|(cooldown.lightning_bolt.remains>=2*gcd))
  VarOcpool = num((Cache.EnemiesCount[8] > 1 or (S.LightningBolt:CooldownRemainsP() >= 2 * Player:GCD())))
  -- variable,name=OCPool_SS,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.stormstrike.cost)))
  VarOcpoolSs = num((bool(VarOcpool) or Player:Maelstrom() >= (num(S.Overcharge:IsAvailable()) * (40 + S.Stormstrike:Cost()))))
  -- variable,name=OCPool_LL,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.lava_lash.cost)))
  VarOcpoolLl = num((bool(VarOcpool) or Player:Maelstrom() >= (num(S.Overcharge:IsAvailable()) * (40 + S.LavaLash:Cost()))))
  -- variable,name=OCPool_CL,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.crash_lightning.cost)))
  VarOcpoolCl = num((bool(VarOcpool) or Player:Maelstrom() >= (num(S.Overcharge:IsAvailable()) * (40 + S.CrashLightning:Cost()))))
  -- variable,name=OCPool_FB,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.frostbrand.cost)))
  VarOcpoolFb = num((bool(VarOcpool) or Player:Maelstrom() >= (num(S.Overcharge:IsAvailable()) * (40 + S.Frostbrand:Cost()))))
  -- variable,name=CLPool_LL,value=active_enemies=1|maelstrom>=(action.crash_lightning.cost+action.lava_lash.cost)
  VarClpoolLl = num(Cache.EnemiesCount[8] == 1 or Player:Maelstrom() >= (S.CrashLightning:Cost() + S.LavaLash:Cost()))
  -- variable,name=CLPool_SS,value=active_enemies=1|maelstrom>=(action.crash_lightning.cost+action.stormstrike.cost)
  VarClpoolSs = num(Cache.EnemiesCount[8] == 1 or Player:Maelstrom() >= (S.CrashLightning:Cost() + S.Stormstrike:Cost()))
  -- variable,name=freezerburn_enabled,value=(talent.hot_hand.enabled&talent.hailstorm.enabled&azerite.primal_primer.enabled)
  VarFreezerburnEnabled = num((S.HotHand:IsAvailable() and S.Hailstorm:IsAvailable() and S.PrimalPrimer:AzeriteEnabled()))
  -- variable,name=rockslide_enabled,value=(!variable.freezerburn_enabled&(talent.boulderfist.enabled&talent.landslide.enabled&azerite.strength_of_earth.enabled))
  VarRockslideEnabled = num((not bool(VarFreezerburnEnabled) and (S.Boulderfist:IsAvailable() and S.Landslide:IsAvailable() and S.StrengthofEarth:AzeriteEnabled())))
end

local function EvaluateCycleStormstrike119(TargetUnit)
  return Cache.EnemiesCount[8] > 1 and S.LightningConduit:AzeriteEnabled() and not TargetUnit:DebuffP(S.LightningConduitDebuff) and bool(VarFurycheckSs)
end

local function EvaluateTargetIfFilterLavaLash281(TargetUnit)
  return TargetUnit:DebuffStackP(S.PrimalPrimerDebuff)
end

local function EvaluateTargetIfLavaLash296(TargetUnit)
  return S.PrimalPrimer:AzeriteRank() >= 2 and TargetUnit:DebuffStackP(S.PrimalPrimerDebuff) == 10 and bool(VarFurycheckLl) and bool(VarClpoolLl)
end

local function EvaluateCycleStormstrike307(TargetUnit)
  return Cache.EnemiesCount[8] > 1 and S.LightningConduit:AzeriteEnabled() and not TargetUnit:DebuffP(S.LightningConduitDebuff) and bool(VarFurycheckSs)
end

-- Stuns
local StunInterrupts = {
  {S.Sundering, "Cast Sundering (Interrupt)", function () return true; end},
  {S.CapacitorTotem, "Cast Capacitor Totem (Interrupt)", function () return true; end},
}

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Asc, Cds, DefaultCore, Filler, FreezerburnCore, Maintenance, Priority
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 4"; end
      end
      -- lightning_shield
      if S.LightningShield:IsCastableP() and Player:BuffDownP(S.LightningShield) then
        if HR.Cast(S.LightningShield) then return "lightning_shield 6"; end
      end
      -- use_item,name=azsharas_font_of_power
      if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 8"; end
      end
      -- rockbiter,if=maelstrom<15&time<gcd
      if S.Rockbiter:IsCastableP() then
        if HR.Cast(S.Rockbiter) then return "rockbiter 9"; end
      end
    end
  end
  Asc = function()
    -- crash_lightning,if=!buff.crash_lightning.up&active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (Player:BuffDownP(S.CrashLightningBuff) and Cache.EnemiesCount[8] > 1 and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 10"; end
    end
    -- rockbiter,if=talent.landslide.enabled&!buff.landslide.up&charges_fractional>1.7
    if S.Rockbiter:IsCastableP() and (S.Landslide:IsAvailable() and Player:BuffDownP(S.LandslideBuff) and S.Rockbiter:ChargesFractionalP() > 1.7) then
      if HR.Cast(S.Rockbiter) then return "rockbiter 24"; end
    end
    -- windstrike
    if S.Windstrike:IsReadyP() then
      if HR.Cast(S.Windstrike) then return "windstrike 34"; end
    end
  end
  Cds = function()
    -- bloodlust,if=azerite.ancestral_resonance.enabled
    -- berserking,if=variable.cooldown_sync
    if S.Berserking:IsCastableP() and HR.CDsON() and (bool(VarCooldownSync)) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 37"; end
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 41"; end
    end
    -- blood_fury,if=variable.cooldown_sync
    if S.BloodFury:IsCastableP() and HR.CDsON() and (bool(VarCooldownSync)) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 43"; end
    end
    -- fireblood,if=variable.cooldown_sync
    if S.Fireblood:IsCastableP() and HR.CDsON() and (bool(VarCooldownSync)) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 47"; end
    end
    -- ancestral_call,if=variable.cooldown_sync
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (bool(VarCooldownSync)) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 51"; end
    end
    -- potion,if=buff.ascendance.up|!talent.ascendance.enabled&feral_spirit.remains>5|target.time_to_die<=60
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.AscendanceBuff) or not S.Ascendance:IsAvailable() and FeralSpiritRemains() > 5 or Target:TimeToDie() <= 60) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 55"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastableP() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 61"; end
    end
    -- feral_spirit
    if S.FeralSpirit:IsCastableP() and Settings.Enhancement.EnableFS then
      if HR.Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit 65"; end
    end
    -- blood_of_the_enemy,if=raid_event.adds.in>90|active_enemies>1
    if S.BloodoftheEnemy:IsCastableP() then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy 67"; end
    end
    -- ascendance,if=cooldown.strike.remains>0
    -- Storm Strike???
    if S.Ascendance:IsCastableP() and (S.Stormstrike:CooldownRemainsP() > 0) then
      if HR.Cast(S.Ascendance, Settings.Enhancement.GCDasOffGCD.Ascendance) then return "ascendance 69"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|(target.time_to_die<20&debuff.razor_coral_debuff.stack>2)
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or (Target:TimeToDie() < 20 and Target:DebuffStackP(S.RazorCoralDebuff) > 2)) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral 73"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.stack>2&debuff.conductive_ink_debuff.down&(buff.ascendance.remains>10|buff.molten_weapon.remains>10|buff.crackling_surge.remains>10|buff.icy_edge.remains>10|debuff.earthen_spike.remains>6)
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffStackP(S.RazorCoralDebuff) > 2 and Target:DebuffDownP(S.ConductiveInkDebuff) and (Player:BuffRemainsP(S.AscendanceBuff) > 10 or Player:BuffRemainsP(S.MoltenWeaponBuff) > 10 or Player:BuffRemainsP(S.CracklingSurgeBuff) > 10 or Player:BuffRemainsP(S.IcyEdgeBuff) > 10 or Target:DebuffRemainsP(S.EarthenSpikeDebuff) > 6)) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral 79"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=(debuff.conductive_ink_debuff.up|buff.ascendance.remains>10|buff.molten_weapon.remains>10|buff.crackling_surge.remains>10|buff.icy_edge.remains>10|debuff.earthen_spike.remains>6)&target.health.pct<31
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and ((Target:DebuffP(S.ConductiveInkDebuff) or Player:BuffRemainsP(S.AscendanceBuff) > 10 or Player:BuffRemainsP(S.MoltenWeaponBuff) > 10 or Player:BuffRemainsP(S.CracklingSurgeBuff) > 10 or Player:BuffRemainsP(S.IcyEdgeBuff) > 10 or Target:DebuffRemainsP(S.EarthenSpikeDebuff) > 6) and Target:HealthPercentage() < 31) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral 95"; end
    end
    -- use_items
    -- earth_elemental
  end
  DefaultCore = function()
    -- earthen_spike,if=variable.furyCheck_ES
    if S.EarthenSpike:IsReadyP() and (bool(VarFurycheckEs)) then
      if HR.Cast(S.EarthenSpike) then return "earthen_spike 111"; end
    end
    -- stormstrike,cycle_targets=1,if=active_enemies>1&azerite.lightning_conduit.enabled&!debuff.lightning_conduit.up&variable.furyCheck_SS
    if S.Stormstrike:IsReadyP() then
      if HR.CastCycle(S.Stormstrike, 8, EvaluateCycleStormstrike119) then return "stormstrike 133" end
    end
    -- stormstrike,if=buff.stormbringer.up|(active_enemies>1&buff.gathering_storms.up&variable.furyCheck_SS)
    if S.Stormstrike:IsReadyP() and (Player:BuffP(S.StormbringerBuff) or (Cache.EnemiesCount[8] > 1 and Player:BuffP(S.GatheringStormsBuff) and bool(VarFurycheckSs))) then
      if HR.Cast(S.Stormstrike) then return "stormstrike 134"; end
    end
    -- crash_lightning,if=active_enemies>=3&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (Cache.EnemiesCount[8] >= 3 and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 148"; end
    end
    -- lightning_bolt,if=talent.overcharge.enabled&active_enemies=1&variable.furyCheck_LB&maelstrom>=40
    if S.LightningBolt:IsCastableP() and (S.Overcharge:IsAvailable() and Cache.EnemiesCount[8] == 1 and bool(VarFurycheckLb) and Player:Maelstrom() >= 40) then
      if HR.Cast(S.LightningBolt) then return "lightning_bolt 160"; end
    end
    -- stormstrike,if=variable.OCPool_SS&variable.furyCheck_SS
    if S.Stormstrike:IsReadyP() and (bool(VarOcpoolSs) and bool(VarFurycheckSs)) then
      if HR.Cast(S.Stormstrike) then return "stormstrike 172"; end
    end
  end
  Filler = function()
    -- sundering,if=raid_event.adds.in>40
    if S.Sundering:IsReadyP() then
      if HR.Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering) then return "sundering 178"; end
    end
    -- focused_azerite_beam,if=raid_event.adds.in>90&!buff.ascendance.up&!buff.molten_weapon.up&!buff.icy_edge.up&!buff.crackling_surge.up&!debuff.earthen_spike.up
    if S.FocusedAzeriteBeam:IsCastableP() and (Player:BuffDownP(S.AscendanceBuff) and Player:BuffDownP(S.MoltenWeaponBuff) and Player:BuffDownP(S.IcyEdgeBuff) and Player:BuffDownP(S.CracklingSurgeBuff) and not Target:DebuffP(S.EarthenSpikeDebuff)) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 188"; end
    end
    -- purifying_blast,if=raid_event.adds.in>60
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast 200"; end
    end
    -- ripple_in_space,if=raid_event.adds.in>60
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 202"; end
    end
    -- thundercharge
    if S.Thundercharge:IsCastableP() then
      if HR.Cast(S.Thundercharge) then return "thundercharge 204"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame 206"; end
    end
    -- crash_lightning,if=talent.forceful_winds.enabled&active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (S.ForcefulWinds:IsAvailable() and Cache.EnemiesCount[8] > 1 and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 212"; end
    end
    -- flametongue,if=talent.searing_assault.enabled
    if S.Flametongue:IsCastableP() and (S.SearingAssault:IsAvailable()) then
      if HR.Cast(S.Flametongue) then return "flametongue 226"; end
    end
    -- lava_lash,if=!azerite.primal_primer.enabled&talent.hot_hand.enabled&buff.hot_hand.react
    if S.LavaLash:IsReadyP() and (not S.PrimalPrimer:AzeriteEnabled() and S.HotHand:IsAvailable() and bool(Player:BuffStackP(S.HotHandBuff))) then
      if HR.Cast(S.LavaLash) then return "lava_lash 230"; end
    end
    -- crash_lightning,if=active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (Cache.EnemiesCount[8] > 1 and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 238"; end
    end
    -- rockbiter,if=maelstrom<70&!buff.strength_of_earth.up
    if S.Rockbiter:IsCastableP() and (Player:Maelstrom() < 70 and Player:BuffDownP(S.StrengthofEarthBuff)) then
      if HR.Cast(S.Rockbiter) then return "rockbiter 250"; end
    end
    -- crash_lightning,if=talent.crashing_storm.enabled&variable.OCPool_CL
    if S.CrashLightning:IsReadyP() and (S.CrashingStorm:IsAvailable() and bool(VarOcpoolCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 254"; end
    end
    -- lava_lash,if=variable.OCPool_LL&variable.furyCheck_LL
    if S.LavaLash:IsReadyP() and (bool(VarOcpoolLl) and bool(VarFurycheckLl)) then
      if HR.Cast(S.LavaLash) then return "lava_lash 260"; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryofLucidDreams:IsCastableP() then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 63"; end
    end
    -- rockbiter
    if S.Rockbiter:IsCastableP() then
      if HR.Cast(S.Rockbiter) then return "rockbiter 266"; end
    end
    -- frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8+gcd&variable.furyCheck_FB
    if S.Frostbrand:IsReadyP() and (S.Hailstorm:IsAvailable() and Player:BuffRemainsP(S.FrostbrandBuff) < 4.8 + Player:GCD() and bool(VarFurycheckFb)) then
      if HR.Cast(S.Frostbrand) then return "frostbrand 268"; end
    end
    -- flametongue
    if S.Flametongue:IsCastableP() then
      if HR.Cast(S.Flametongue) then return "flametongue 276"; end
    end
    -- worldvein_resonance,if=buff.lifeblood.stack<4
    if S.WorldveinResonance:IsCastableP() and (Player:BuffStackP(S.LifebloodBuff) < 4) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 208"; end
    end
  end
  FreezerburnCore = function()
    -- lava_lash,target_if=max:debuff.primal_primer.stack,if=azerite.primal_primer.rank>=2&debuff.primal_primer.stack=10&variable.furyCheck_LL&variable.CLPool_LL
    if S.LavaLash:IsReadyP() then
      if HR.CastTargetIf(S.LavaLash, 8, "max", EvaluateTargetIfFilterLavaLash281, EvaluateTargetIfLavaLash296) then return "lava_lash 298" end
    end
    -- earthen_spike,if=variable.furyCheck_ES
    if S.EarthenSpike:IsReadyP() and (bool(VarFurycheckEs)) then
      if HR.Cast(S.EarthenSpike) then return "earthen_spike 299"; end
    end
    -- stormstrike,cycle_targets=1,if=active_enemies>1&azerite.lightning_conduit.enabled&!debuff.lightning_conduit.up&variable.furyCheck_SS
    if S.Stormstrike:IsReadyP() then
      if HR.CastCycle(S.Stormstrike, 8, EvaluateCycleStormstrike307) then return "stormstrike 321" end
    end
    -- stormstrike,if=buff.stormbringer.up|(active_enemies>1&buff.gathering_storms.up&variable.furyCheck_SS)
    if S.Stormstrike:IsReadyP() and (Player:BuffP(S.StormbringerBuff) or (Cache.EnemiesCount[8] > 1 and Player:BuffP(S.GatheringStormsBuff) and bool(VarFurycheckSs))) then
      if HR.Cast(S.Stormstrike) then return "stormstrike 322"; end
    end
    -- crash_lightning,if=active_enemies>=3&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (Cache.EnemiesCount[8] >= 3 and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 336"; end
    end
    -- lightning_bolt,if=talent.overcharge.enabled&active_enemies=1&variable.furyCheck_LB&maelstrom>=40
    if S.LightningBolt:IsCastableP() and (S.Overcharge:IsAvailable() and Cache.EnemiesCount[8] == 1 and bool(VarFurycheckLb) and Player:Maelstrom() >= 40) then
      if HR.Cast(S.LightningBolt) then return "lightning_bolt 348"; end
    end
    -- lava_lash,if=azerite.primal_primer.rank>=2&debuff.primal_primer.stack>7&variable.furyCheck_LL&variable.CLPool_LL
    if S.LavaLash:IsReadyP() and (S.PrimalPrimer:AzeriteRank() >= 2 and Target:DebuffStackP(S.PrimalPrimerDebuff) > 7 and bool(VarFurycheckLl) and bool(VarClpoolLl)) then
      if HR.Cast(S.LavaLash) then return "lava_lash 360"; end
    end
    -- stormstrike,if=variable.OCPool_SS&variable.furyCheck_SS&variable.CLPool_SS
    if S.Stormstrike:IsReadyP() and (bool(VarOcpoolSs) and bool(VarFurycheckSs) and bool(VarClpoolSs)) then
      if HR.Cast(S.Stormstrike) then return "stormstrike 370"; end
    end
    -- lava_lash,if=debuff.primal_primer.stack=10&variable.furyCheck_LL
    if S.LavaLash:IsReadyP() and (Target:DebuffStackP(S.PrimalPrimerDebuff) == 10 and bool(VarFurycheckLl)) then
      if HR.Cast(S.LavaLash) then return "lava_lash 378"; end
    end
  end
  Maintenance = function()
    -- flametongue,if=!buff.flametongue.up
    if S.Flametongue:IsCastableP() and (Player:BuffDownP(S.FlametongueBuff)) then
      if HR.Cast(S.Flametongue) then return "flametongue 384"; end
    end
    -- frostbrand,if=talent.hailstorm.enabled&!buff.frostbrand.up&variable.furyCheck_FB
    if S.Frostbrand:IsReadyP() and (S.Hailstorm:IsAvailable() and Player:BuffDownP(S.FrostbrandBuff) and bool(VarFurycheckFb)) then
      if HR.Cast(S.Frostbrand) then return "frostbrand 388"; end
    end
  end
  Priority = function()
    -- crash_lightning,if=active_enemies>=(8-(talent.forceful_winds.enabled*3))&variable.freezerburn_enabled&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (Cache.EnemiesCount[8] >= (8 - (num(S.ForcefulWinds:IsAvailable()) * 3)) and bool(VarFreezerburnEnabled) and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 398"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up|time<5
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff) or HL.CombatTime() < 5) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force 414"; end
    end
    -- lava_lash,if=azerite.primal_primer.rank>=2&debuff.primal_primer.stack=10&active_enemies=1&variable.freezerburn_enabled&variable.furyCheck_LL
    if S.LavaLash:IsReadyP() and (S.PrimalPrimer:AzeriteRank() >= 2 and Target:DebuffStackP(S.PrimalPrimerDebuff) == 10 and Cache.EnemiesCount[8] == 1 and bool(VarFreezerburnEnabled) and bool(VarFurycheckLl)) then
      if HR.Cast(S.LavaLash) then return "lava_lash 418"; end
    end
    -- crash_lightning,if=!buff.crash_lightning.up&active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsReadyP() and (Player:BuffDownP(S.CrashLightningBuff) and Cache.EnemiesCount[8] > 1 and bool(VarFurycheckCl)) then
      if HR.Cast(S.CrashLightning) then return "crash_lightning 434"; end
    end
    -- fury_of_air,if=!buff.fury_of_air.up&maelstrom>=20&spell_targets.fury_of_air_damage>=(1+variable.freezerburn_enabled)
    if S.FuryofAir:IsCastableP() and (Player:BuffDownP(S.FuryofAirBuff) and Player:Maelstrom() >= 20 and Cache.EnemiesCount[5] >= (1 + VarFreezerburnEnabled)) then
      if HR.Cast(S.FuryofAir) then return "fury_of_air 448"; end
    end
    -- fury_of_air,if=buff.fury_of_air.up&&spell_targets.fury_of_air_damage<(1+variable.freezerburn_enabled)
    if S.FuryofAir:IsCastableP() and (Player:BuffP(S.FuryofAirBuff) and true and Cache.EnemiesCount[5] < (1 + VarFreezerburnEnabled)) then
      if HR.Cast(S.FuryofAir) then return "fury_of_air 454"; end
    end
    -- totem_mastery,if=buff.resonance_totem.remains<=2*gcd
    if S.TotemMastery:IsCastableP() and (ResonanceTotemTime() <= 2 * Player:GCD()) then
      if HR.Cast(S.TotemMastery) then return "totem_mastery 460"; end
    end
    -- sundering,if=active_enemies>=3&(!essence.blood_of_the_enemy.major|(essence.blood_of_the_enemy.major&(buff.seething_rage.up|cooldown.blood_of_the_enemy.remains>40)))
    if S.Sundering:IsReadyP() and (Cache.EnemiesCount[8] >= 3 and (not S.BloodoftheEnemy:IsAvailable() or (S.BloodoftheEnemy:IsAvailable() and (Player:BuffP(S.SeethingRageBuff) or S.BloodoftheEnemy:CooldownRemainsP() > 40)))) then
      if HR.Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering) then return "sundering 464"; end
    end
    -- focused_azerite_beam,if=active_enemies>1
    if S.FocusedAzeriteBeam:IsCastableP() and (Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 478"; end
    end
    -- purifying_blast,if=active_enemies>1
    if S.PurifyingBlast:IsCastableP() and (Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast 486"; end
    end
    -- ripple_in_space,if=active_enemies>1
    if S.RippleInSpace:IsCastableP() and (Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 494"; end
    end
    -- rockbiter,if=talent.landslide.enabled&!buff.landslide.up&charges_fractional>1.7
    if S.Rockbiter:IsCastableP() and (S.Landslide:IsAvailable() and Player:BuffDownP(S.LandslideBuff) and S.Rockbiter:ChargesFractionalP() > 1.7) then
      if HR.Cast(S.Rockbiter) then return "rockbiter 502"; end
    end
    -- frostbrand,if=(azerite.natural_harmony.enabled&buff.natural_harmony_frost.remains<=2*gcd)&talent.hailstorm.enabled&variable.furyCheck_FB
    if S.Frostbrand:IsReadyP() and ((S.NaturalHarmony:AzeriteEnabled() and Player:BuffRemainsP(S.NaturalHarmonyFrostBuff) <= 2 * Player:GCD()) and S.Hailstorm:IsAvailable() and bool(VarFurycheckFb)) then
      if HR.Cast(S.Frostbrand) then return "frostbrand 512"; end
    end
    -- flametongue,if=(azerite.natural_harmony.enabled&buff.natural_harmony_fire.remains<=2*gcd)
    if S.Flametongue:IsCastableP() and ((S.NaturalHarmony:AzeriteEnabled() and Player:BuffRemainsP(S.NaturalHarmonyFireBuff) <= 2 * Player:GCD())) then
      if HR.Cast(S.Flametongue) then return "flametongue 522"; end
    end
    -- rockbiter,if=(azerite.natural_harmony.enabled&buff.natural_harmony_nature.remains<=2*gcd)&maelstrom<70
    if S.Rockbiter:IsCastableP() and ((S.NaturalHarmony:AzeriteEnabled() and Player:BuffRemainsP(S.NaturalHarmonyNatureBuff) <= 2 * Player:GCD()) and Player:Maelstrom() < 70) then
      if HR.Cast(S.Rockbiter) then return "rockbiter 528"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- wind_shear/interrupts
    Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, StunInterrupts)
    -- Set Variables; Moved to function for cleanliness
    if (true) then
      SetVariables();
    end
    -- auto_attack
    -- call_action_list,name=opener -- Moved to Precombat
    -- call_action_list,name=asc,if=buff.ascendance.up
    if (Player:BuffP(S.AscendanceBuff)) then
      local ShouldReturn = Asc(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=priority
    if (true) then
      local ShouldReturn = Priority(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=maintenance,if=active_enemies<3
    if (Cache.EnemiesCount[8] < 3) then
      local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds
    if (HR.CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=freezerburn_core,if=variable.freezerburn_enabled
    if (bool(VarFreezerburnEnabled)) then
      local ShouldReturn = FreezerburnCore(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=default_core,if=!variable.freezerburn_enabled
    if (not bool(VarFreezerburnEnabled)) then
      local ShouldReturn = DefaultCore(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=maintenance,if=active_enemies>=3
    if (Cache.EnemiesCount[8] >= 3) then
      local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=filler
    if (true) then
      local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(187874, 8, 6)               -- Bladestorm
  HL.RegisterNucleusAbility(197214, 11, 6)              -- Sundering
  HL.RegisterNucleusAbility(197211, 8, 6)               -- Fury of Air
end

HR.SetAPL(263, APL, Init)

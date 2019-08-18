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
if not Spell.Paladin then Spell.Paladin = {} end
Spell.Paladin.Protection = {
  ConsecrationBuff                      = Spell(188370),
  Consecration                          = Spell(26573),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AvengingWrathBuff                     = Spell(31884),
  Seraphim                              = Spell(152262),
  ShieldoftheRighteous                  = Spell(53600),
  AvengingWrath                         = Spell(31884),
  SeraphimBuff                          = Spell(152262),
  BastionofLight                        = Spell(204035),
  Judgment                              = Spell(275779),
  CrusadersJudgment                     = Spell(204023),
  AvengersShield                        = Spell(31935),
  AvengersValorBuff                     = Spell(197561),
  BlessedHammer                         = Spell(204019),
  HammeroftheRighteous                  = Spell(53595),
  Rebuke                                = Spell(96231),
  RazorCoralDebuff                      = Spell(303568),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  AnimaofDeath                          = MultiSpell(294926, 300002, 300003),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  HeartEssence                          = Spell(298554),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368)
};
local S = Spell.Paladin.Protection;

-- Items
if not Item.Paladin then Item.Paladin = {} end
Item.Paladin.Protection = {
  PotionofUnbridledFury            = Item(169299),
  AzsharasFontofPower              = Item(169314),
  GrongsPrimalRage                 = Item(165574),
  MerekthasFang                    = Item(158367),
  RazdunksBigRedButton             = Item(159611),
  AshvanesRazorCoral               = Item(169311),
  PocketsizedComputationDevice     = Item(167555)
};
local I = Item.Paladin.Protection;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Protection = HR.GUISettings.APL.Paladin.Protection
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

-- Stuns
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
};

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns
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
      -- consecration
      if S.Consecration:IsCastableP() and Player:BuffDownP(S.ConsecrationBuff) then
        if HR.Cast(S.Consecration) then return "consecration 6"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastableP() and HR.CDsON() then
        if HR.Cast(S.LightsJudgment) then return "lights_judgment 10"; end
      end
    end
  end
  Cooldowns = function()
    -- fireblood,if=buff.avenging_wrath.up
    if S.Fireblood:IsCastableP() and HR.CDsON() and (Player:BuffP(S.AvengingWrathBuff)) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 12"; end
    end
    -- use_item,name=azsharas_font_of_power,if=cooldown.seraphim.remains<=10|!talent.seraphim.enabled
    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets and (S.Seraphim:CooldownRemainsP() <= 10 or not S.Seraphim:IsAvailable()) then
      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 16"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=(debuff.razor_coral_debuff.stack>7&buff.avenging_wrath.up)|debuff.razor_coral_debuff.stack=0
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and ((Target:DebuffStackP(S.RazorCoralDebuff) > 7 and Player:BuffP(S.AvengingWrathBuff)) or Target:DebuffStackP(S.RazorCoralDebuff) == 0) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral 18"; end
    end
    -- seraphim,if=cooldown.shield_of_the_righteous.charges_fractional>=2
    if S.Seraphim:IsCastableP() and (S.ShieldoftheRighteous:ChargesFractionalP() >= 2) then
      if HR.Cast(S.Seraphim) then return "seraphim 22"; end
    end
    -- avenging_wrath,if=buff.seraphim.up|cooldown.seraphim.remains<2|!talent.seraphim.enabled
    if S.AvengingWrath:IsCastableP() and HR.CDsON() and (Player:BuffP(S.SeraphimBuff) or S.Seraphim:CooldownRemainsP() < 2 or not S.Seraphim:IsAvailable()) then
      if HR.Cast(S.AvengingWrath, Settings.Protection.GCDasOffGCD.AvengingWrath) then return "avenging_wrath 26"; end
    end
    -- memory_of_lucid_dreams,if=!talent.seraphim.enabled|cooldown.seraphim.remains<=gcd|buff.seraphim.up
    if S.MemoryofLucidDreams:IsCastableP() and (not S.Seraphim:IsAvailable() or S.Seraphim:CooldownRemainsP() <= Player:GCD() or Player:BuffP(S.SeraphimBuff)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 28"; end
    end
    -- bastion_of_light,if=cooldown.shield_of_the_righteous.charges_fractional<=0.5
    if S.BastionofLight:IsCastableP() and (S.ShieldoftheRighteous:ChargesFractionalP() <= 0.5) then
      if HR.Cast(S.BastionofLight) then return "bastion_of_light 34"; end
    end
    -- potion,if=buff.avenging_wrath.up
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.AvengingWrathBuff)) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 38"; end
    end
    -- use_items,if=buff.seraphim.up|!talent.seraphim.enabled
    -- use_item,name=grongs_primal_rage,if=cooldown.judgment.full_recharge_time>4&cooldown.avengers_shield.remains>4&(buff.seraphim.up|cooldown.seraphim.remains+4+gcd>expected_combat_length-time)&consecration.up
    if I.GrongsPrimalRage:IsEquipReady() and Settings.Commons.UseTrinkets and (S.Judgment:FullRechargeTimeP() > 4 and S.AvengersShield:CooldownRemainsP() > 4 and (Player:BuffP(S.SeraphimBuff) or S.Seraphim:CooldownRemainsP() + 4 + Player:GCD() > Target:TimeToDie()) and Player:BuffP(S.ConsecrationBuff)) then
      if HR.Cast(I.GrongsPrimalRage, nil, Settings.Commons.TrinketDisplayStyle) then return "grongs_primal_rage 43"; end
    end
    -- use_item,name=pocketsized_computation_device,if=cooldown.judgment.full_recharge_time>4*spell_haste&cooldown.avengers_shield.remains>4*spell_haste&(!equipped.grongs_primal_rage|!trinket.grongs_primal_rage.cooldown.up)&consecration.up
    if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets and (S.Judgment:FullRechargeTimeP() > 4 * Player:SpellHaste() and S.AvengersShield:CooldownRemainsP() > 4 * Player:SpellHaste() and (not I.GrongsPrimalRage:IsEquipped() or not I.GrongsPrimalRage:IsReady()) and Player:BuffP(S.ConsecrationBuff)) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "pocketsized_computation_device"; end
    end
    -- use_item,name=merekthas_fang,if=!buff.avenging_wrath.up&(buff.seraphim.up|!talent.seraphim.enabled)
    if I.MerekthasFang:IsEquipReady() and Settings.Commons.UseTrinkets and (not Player:BuffP(S.AvengingWrathBuff) and (Player:BuffP(S.SeraphimBuff) or not S.Seraphim:IsAvailable())) then
      if HR.Cast(I.MerekthasFang, nil, Settings.Commons.TrinketDisplayStyle) then return "merekthas_fang 57"; end
    end
    -- use_item,name=razdunks_big_red_button
    if I.RazdunksBigRedButton:IsEquipReady() and Settings.Commons.UseTrinkets then
      if HR.Cast(I.RazdunksBigRedButton, nil, Settings.Commons.TrinketDisplayStyle) then return "razdunks_big_red_button 65"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, StunInterrupts);
    -- auto_attack
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- worldvein_resonance,if=buff.lifeblood.stack<3
    if S.WorldveinResonance:IsCastableP() and (Player:BuffStackP(S.LifebloodBuff) < 3) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    -- shield_of_the_righteous,if=(buff.avengers_valor.up&cooldown.shield_of_the_righteous.charges_fractional>=2.5)&(cooldown.seraphim.remains>gcd|!talent.seraphim.enabled)
    if S.ShieldoftheRighteous:IsCastableP() and ((Player:BuffP(S.AvengersValorBuff) and S.ShieldoftheRighteous:ChargesFractionalP() >= 2.5) and (S.Seraphim:CooldownRemainsP() > Player:GCD() or not S.Seraphim:IsAvailable())) then
      if HR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous) then return "shield_of_the_righteous 71"; end
    end
    -- shield_of_the_righteous,if=(buff.avenging_wrath.up&!talent.seraphim.enabled)|buff.seraphim.up&buff.avengers_valor.up
    if S.ShieldoftheRighteous:IsCastableP() and ((Player:BuffP(S.AvengingWrathBuff) and not S.Seraphim:IsAvailable()) or Player:BuffP(S.SeraphimBuff) and Player:BuffP(S.AvengersValorBuff)) then
      if HR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous) then return "shield_of_the_righteous 81"; end
    end
    -- shield_of_the_righteous,if=(buff.avenging_wrath.up&buff.avenging_wrath.remains<4&!talent.seraphim.enabled)|(buff.seraphim.remains<4&buff.seraphim.up)
    if S.ShieldoftheRighteous:IsCastableP() and ((Player:BuffP(S.AvengingWrathBuff) and Player:BuffRemainsP(S.AvengingWrathBuff) < 4 and not S.Seraphim:IsAvailable()) or (Player:BuffRemainsP(S.SeraphimBuff) < 4 and Player:BuffP(S.SeraphimBuff))) then
      if HR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous) then return "shield_of_the_righteous 91"; end
    end
    -- lights_judgment,if=buff.seraphim.up&buff.seraphim.remains<3
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffP(S.SeraphimBuff) and Player:BuffRemainsP(S.SeraphimBuff) < 3) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 103"; end
    end
    -- consecration,if=!consecration.up
    if S.Consecration:IsCastableP() and (Player:BuffDownP(S.ConsecrationBuff)) then
      if HR.Cast(S.Consecration) then return "consecration 109"; end
    end
    -- judgment,if=(cooldown.judgment.remains<gcd&cooldown.judgment.charges_fractional>1&cooldown_react)|!talent.crusaders_judgment.enabled
    if S.Judgment:IsCastableP() and ((S.Judgment:CooldownRemainsP() < Player:GCD() and S.Judgment:ChargesFractionalP() > 1 and S.Judgment:CooldownUpP()) or not S.CrusadersJudgment:IsAvailable()) then
      if HR.Cast(S.Judgment) then return "judgment 111"; end
    end
    -- avengers_shield,if=cooldown_react
    if S.AvengersShield:IsCastableP() and (S.AvengersShield:CooldownUpP()) then
      if HR.Cast(S.AvengersShield) then return "avengers_shield 123"; end
    end
    -- judgment,if=cooldown_react|!talent.crusaders_judgment.enabled
    if S.Judgment:IsCastableP() and (S.Judgment:CooldownUpP() or not S.CrusadersJudgment:IsAvailable()) then
      if HR.Cast(S.Judgment) then return "judgment 129"; end
    end
    -- concentrated_flame,if=buff.seraphim.up&!dot.concentrated_flame_burn.remains>0|essence.the_crucible_of_flame.rank<3
    if S.ConcentratedFlame:IsCastableP() and (Player:BuffP(S.SeraphimBuff) and Target:DebuffDownP(S.ConcentratedFlameBurn) or (S.ConcentratedFlame:ID() == 295373 or S.ConcentratedFlame:ID() == 299349)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame"; end
    end
    -- lights_judgment,if=!talent.seraphim.enabled|buff.seraphim.up
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (not S.Seraphim:IsAvailable() or Player:BuffP(S.SeraphimBuff)) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 137"; end
    end
    -- anima_of_death
    if S.AnimaofDeath:IsCastableP() then
      if HR.Cast(S.AnimaofDeath, nil, Settings.Commons.EssenceDisplayStyle) then return "anima_of_death"; end
    end
    -- blessed_hammer,strikes=3
    if S.BlessedHammer:IsCastableP() then
      if HR.Cast(S.BlessedHammer) then return "blessed_hammer 143"; end
    end
    -- hammer_of_the_righteous
    if S.HammeroftheRighteous:IsCastableP() then
      if HR.Cast(S.HammeroftheRighteous) then return "hammer_of_the_righteous 145"; end
    end
    -- consecration
    if S.Consecration:IsCastableP() then
      if HR.Cast(S.Consecration) then return "consecration 147"; end
    end
    -- heart_essence,if=!essence.the_crucible_of_flame.major|!essence.worldvein_resonance.major|!essence.anima_of_life_and_death.major|!essence.memory_of_lucid_dreams.major
    if S.HeartEssence:IsCastableP() and (not S.ConcentratedFlame:IsAvailable() or not S.WorldveinResonance:IsAvailable() or not S.AnimaofDeath:IsAvailable() or not S.MemoryofLucidDreams:IsAvailable()) then
      if HR.Cast(S.HeartEssence, nil, Settings.Commons.EssenceDisplayStyle) then return "heart_essence"; end
    end
  end
end

HR.SetAPL(66, APL)

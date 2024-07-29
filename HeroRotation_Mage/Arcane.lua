--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local Mage          = HR.Commons.Mage
local Cast          = HR.Cast
local CastAnnotated = HR.CastAnnotated
local CastLeft      = HR.CastLeft
local CDsON         = HR.CDsON
local AoEON         = HR.AoEON
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- WoW API
local GetItemCount  = GetItemCount

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Arcane;
local I = Item.Mage.Arcane;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- DF Trinkets
  I.BeacontotheBeyond:ID(),
  I.BelorrelostheSuncaller:ID(),
  I.ConjuredChillglobe:ID(),
  I.DesperateInvokersCodex:ID(),
  I.IcebloodDeathsnare:ID(),
  I.NymuesUnravelingSpindle:ID(),
  -- TWW Trinkets
  I.AberrantSpellforge:ID(),
  I.HighSpeakersAccretion:ID(),
  I.MadQueensMandate:ID(),
  I.MereldarsToll:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
  -- Other On-Use
  I.Dreambinder:ID(),
  I.IridaltheEarthsMaster:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  CommonsDS = HR.GUISettings.APL.Mage.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Mage.CommonsOGCD,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

--- ===== InFlight Registrations =====
S.ArcaneBlast:RegisterInFlight()
S.ArcaneBarrage:RegisterInFlight()

--- ===== Rotation Variables =====
local VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
local VarOpener = true
local VarAltRotation = S.HighVoltage:IsAvailable()
local VarSteroidTrinketEquipped
local Enemies8ySplash, EnemiesCount8ySplash
local ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
local BossFightRemains = 11111
local FightRemains = 11111
local CastAE
local GCDMax

--- ===== Trinket Item Objects =====
local Trinket1, Trinket2 = Player:GetTrinketItems()

--- ===== Trinket Variables =====
local function SetTrinketVariables()
  VarTrinket1ID = Trinket1:ID()
  VarTrinket2ID = Trinket2:ID()

  local Trinket1Spell = Trinket1:OnUseSpell()
  VarTrinket1Range = (Trinket1Spell and Trinket1Spell.MaximumRange > 0 and Trinket1Spell.MaximumRange <= 100) and Trinket1Spell.MaximumRange or 100
  local Trinket2Spell = Trinket2:OnUseSpell()
  VarTrinket2Range = (Trinket2Spell and Trinket2Spell.MaximumRange > 0 and Trinket2Spell.MaximumRange <= 100) and Trinket2Spell.MaximumRange or 100

  VarTrinket1CD = Trinket1:Cooldown()
  VarTrinket2CD = Trinket2:Cooldown()

  VarSteroidTrinketEquipped = I.ForgedGladiatorsBadge:IsEquipped() or I.CrimsonGladiatorsBadge:IsEquipped() or I.DraconicGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.VerdantGladiatorsBadge:IsEquipped()
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
  VarOpener = true
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
  VarAltRotation = S.HighVoltage:IsAvailable()
  ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  Trinket1, Trinket2 = Player:GetTrinketItems()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  -- Note: Moved to top of APL()
  -- variable,name=aoe_target_count,op=reset,default=2
  -- variable,name=aoe_target_count,op=set,value=9,if=!talent.arcing_cleave
  -- variable,name=opener,op=set,value=1
  -- variable,name=alt_rotation,op=set,if=talent.high_voltage,value=1
  -- Note: Moved to variable declarations and Event Registrations to avoid potential nil errors.
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.irideus_fragment|equipped.spoils_of_neltharus|equipped.timebreaching_talon|equipped.ashes_of_the_embersoul|equipped.nymues_unraveling_spindle|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.treacherous_transmitter
  -- Note: Moved to SetTrinketVariables().
  -- snapshot_stats
  -- mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 2"; end
  end
  -- arcane_blast,if=!talent.evocation
  if S.ArcaneBlast:IsReady() and (not S.Evocation:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 4"; end
  end
  -- evocation,if=talent.evocation
  if S.Evocation:IsReady() then
    if Cast(S.Evocation) then return "evocation precombat 6"; end
  end
end

local function CDOpener()
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage&(action.arcane_barrage.in_flight_remains<=0.5|gcd.remains<=0.5)
  -- Note: Added an extra half second buffer time.
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage) and (S.ArcaneBarrage:TravelTime() - S.ArcaneBarrage:TimeSinceLastCast() <= 1 or Player:GCDRemains() <= 1)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi, nil, not Target:IsSpellInRange(S.TouchoftheMagi)) then return "touch_of_the_magi cd_opener 2"; end
  end
  -- supernova,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.unerring_proficiency.stack=30
  if S.Supernova:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax and Player:BuffStack(S.UnerringProficiencyBuff) == 30) then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova cd_opener 4"; end
  end
  -- cancel_buff,name=presence_of_mind,use_off_gcd=1,if=prev_gcd.1.arcane_blast&buff.presence_of_mind.stack=1
  -- TODO: Handle cancel_buff.
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.nether_precision.up&active_enemies<variable.aoe_target_count&!talent.unerring_proficiency
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash < VarAoETargetCount and not S.UnerringProficiency:IsAvailable()) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind cd_opener 6"; end
  end
  -- wait,sec=0.05,if=buff.presence_of_mind.up,line_cd=15
  -- arcane_blast,if=buff.presence_of_mind.up
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cd_opener 8"; end
  end
  -- arcane_orb,if=variable.opener,line_cd=10
  if S.ArcaneOrb:IsReady() and S.ArcaneOrb:TimeSinceLastCast() >= 10 and (VarOpener) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb cd_opener 10"; end
  end
  -- evocation,if=cooldown.arcane_surge.remains<gcd.max*2
  if S.Evocation:IsCastable() and (S.ArcaneSurge:CooldownRemains() < GCDMax * 2) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation cd_opener 12"; end
  end
  -- arcane_missiles,if=variable.opener,interrupt_if=!gcd.remains,interrupt_immediate=1,interrupt_global=1,line_cd=10
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and Player:GCDRemains() == 0 then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt cd_opener 14"; end
  end
  if S.ArcaneMissiles:IsReady() and S.ArcaneMissiles:TimeSinceLastCast() >= 10 and (VarOpener) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cd_opener 16"; end
  end
  -- arcane_surge
  if S.ArcaneSurge:IsCastable() then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge cd_opener 18"; end
  end
  -- shifting_power,if=((buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>15&cooldown.touch_of_the_magi.remains>15)&(cooldown.arcane_orb.remains&action.arcane_orb.charges=0)&fight_remains>10)|(prev_gcd.1.arcane_barrage&(buff.arcane_surge.up|debuff.touch_of_the_magi.up|cooldown.evocation.remains<20)&talent.shifting_shards),interrupt_if=(cooldown.evocation.ready&cooldown.arcane_surge.remains<3),interrupt_immediate=1,interrupt_global=1
  if Settings.Arcane.Enabled.ShiftingPowerInterrupts and Player:IsChanneling(S.ShiftingPower) and (S.Evocation:IsReady() and S.ArcaneSurge:CooldownRemains() < 3) then
    if CastAnnotated(S.StopAM, false, "STOP SP") then return "shifting_power interrupt cd_opener 20"; end
  end
  if S.ShiftingPower:IsReady() and (((Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and S.Evocation:CooldownRemains() > 15 and S.TouchoftheMagi:CooldownRemains() > 15) and (S.ArcaneOrb:CooldownDown() and S.ArcaneOrb:Charges() == 0) and FightRemains > 10) or (Player:PrevGCDP(1, S.ArcaneBarrage) and (Player:BuffUp(S.ArcaneSurgeBuff) or Target:DebuffUp(S.TouchoftheMagiDebuff) or S.Evocation:CooldownRemains() < 20) and S.ShiftingShards:IsAvailable())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power cd_opener 22"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<2&(cooldown.touch_of_the_magi.remains>18|!active_enemies>=variable.aoe_target_count)
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2 and (S.TouchoftheMagi:CooldownRemains() > 18 or EnemiesCount8ySplash < VarAoETargetCount)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb cd_opener 24"; end
  end
end

local function RotationAoE()
  -- arcane_blast,if=active_enemies>=variable.aoe_target_count&debuff.touch_of_the_magi.up&talent.magis_spark,line_cd=15
  if S.ArcaneBlast:IsReady() and S.ArcaneBlast:TimeSinceLastCast() >= 15 and (EnemiesCount8ySplash >= VarAoETargetCount and Target:DebuffUp(S.TouchoftheMagiDebuff) and S.MagisSpark:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation_aoe 2"; end
  end
  -- arcane_barrage,if=(talent.arcane_tempo&buff.arcane_tempo.remains<gcd.max)|((buff.intuition.up&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|!variable.alt_rotation))&buff.nether_precision.up)|(buff.nether_precision.up&action.arcane_blast.executing)
  if S.ArcaneBarrage:IsCastable() and ((S.ArcaneTempo:IsAvailable() and Player:BuffRemains(S.ArcaneTempoBuff) < GCDMax) or ((Player:BuffUp(S.IntuitionBuff) and (Player:ArcaneCharges() == Player:ArcaneChargesMax() or not VarAltRotation)) and Player:BuffUp(S.NetherPrecisionBuff)) or (Player:BuffUp(S.NetherPrecisionBuff) and Player:IsCasting(S.ArcaneBlast))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation_aoe 4"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&((variable.alt_rotation&buff.arcane_charge.stack<buff.arcane_charge.max_stack)|buff.aether_attunement.up|talent.arcane_harmony)&((variable.alt_rotation&buff.arcane_charge.stack<buff.arcane_charge.max_stack)|!buff.nether_precision.up),interrupt_if=!gcd.remains,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (Player:GCDRemains() == 0) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt rotation_aoe 6"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and ((VarAltRotation and Player:ArcaneCharges() < Player:ArcaneChargesMax()) or Player:BuffUp(S.AetherAttunementBuff) or S.ArcaneHarmony:IsAvailable()) and ((VarAltRotation and Player:ArcaneCharges() < Player:ArcaneChargesMax()) or Player:BuffDown(S.NetherPrecisionBuff))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation_aoe 8"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation_aoe 10"; end
  end
  -- arcane_explosion
  if S.ArcaneExplosion:IsReady() then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion rotation_aoe 12"; end
  end
end

local function RotationDefault()
  -- arcane_missiles,if=buff.clearcasting.react&(buff.nether_precision.down|(buff.clearcasting.stack=3&!talent.splintering_sorcery)|(variable.alt_rotation&buff.nether_precision.stack=1&buff.arcane_charge.stack<4)),interrupt_if=!gcd.remains&(!variable.alt_rotation|buff.arcane_charge.stack=buff.arcane_charge.max_stack),interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (Player:GCDRemains() == 0 and (not VarAltRotation or Player:ArcaneCharges() == Player:ArcaneChargesMax())) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt rotation_default 2"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and (Player:BuffDown(S.NetherPrecisionBuff) or (Player:BuffStack(S.ClearcastingBuff) == 3 and not S.SplinteringSorcery:IsAvailable()) or (VarAltRotation and Player:BuffStack(S.NetherPrecisionBuff) == 1 and Player:ArcaneCharges() < 4))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation_default 4"; end
  end
  -- arcane_barrage,if=(buff.arcane_charge.stack=buff.arcane_charge.max_stack&((buff.nether_precision.stack=1&((buff.clearcasting.up|action.arcane_orb.charges>0)&time-action.arcane_blast.last_used<0.015)&buff.arcane_harmony.stack>12)|(cooldown.touch_of_the_magi.ready&(buff.nether_precision.up|!talent.magis_spark))))|(talent.arcane_tempo&buff.arcane_tempo.remains<(gcd.max*2))|buff.intuition.up
  if S.ArcaneBarrage:IsReady() and ((Player:ArcaneCharges() == Player:ArcaneChargesMax() and ((Player:BuffStack(S.NetherPrecisionBuff) == 1 and ((Player:BuffUp(S.ClearcastingBuff) or S.ArcaneOrb:Charges() > 0) and S.ArcaneBlast:TimeSinceLastCast() < 0.265) and Player:BuffStack(S.ArcaneHarmonyBuff) > 12) or (S.TouchoftheMagi:CooldownUp() and (Player:BuffUp(S.NetherPrecisionBuff) or not S.MagisSpark:IsAvailable())))) or (S.ArcaneTempo:IsAvailable() and Player:BuffRemains(S.ArcaneTempoBuff) < (GCDMax * 2)) or Player:BuffUp(S.IntuitionBuff)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation_default 6"; end
  end
  -- arcane_blast,if=buff.nether_precision.stack=2|(buff.nether_precision.stack=1&!prev_gcd.1.arcane_blast)
  if S.ArcaneBlast:IsReady() and (Player:BuffStack(S.NetherPrecisionBuff) == 2 or (Player:BuffStack(S.NetherPrecisionBuff) == 1 and not Player:PrevGCDP(1, S.ArcaneBlast))) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation_default 8"; end
  end
  -- arcane_barrage,if=buff.arcane_surge.down&(mana.pct<70&cooldown.arcane_surge.remains>45&cooldown.touch_of_the_magi.remains>6)|(mana.deficit>(mana.max-action.arcane_blast.cost))|cooldown.touch_of_the_magi.ready|(cooldown.shifting_power.ready&cooldown.arcane_orb.ready)
  if S.ArcaneBarrage:IsReady() and (Player:BuffDown(S.ArcaneSurgeBuff) and (Player:ManaPercentage() < 70 and S.ArcaneSurge:CooldownRemains() > 45 and S.TouchoftheMagi:CooldownRemains() > 6) or (Player:ManaDeficit() > (Player:ManaMax() - S.ArcaneBlast:Cost())) or S.TouchoftheMagi:CooldownUp() or (S.ShiftingPower:CooldownUp() and S.ArcaneOrb:CooldownUp())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation_default 10"; end
  end
  -- arcane_blast,if=!talent.splintering_sorcery|(buff.arcane_charge.stack>2&buff.nether_precision.down)
  if S.ArcaneBlast:IsReady() and (not S.SplinteringSorcery:IsAvailable() or (Player:ArcaneCharges() > 2 and Player:BuffDown(S.NetherPrecisionBuff))) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation_default 12"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsReady() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation_default 14"; end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    GCDMax = Player:GCD() + 0.25

    -- Set which cast function to use for ArcaneExplosion
    CastAE = (Settings.Arcane.AEMainIcon) and Cast or CastLeft
  end

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    -- Note: Moved from of precombat
    if S.ArcaneIntellect:IsCastable() and (S.ArcaneFamiliar:IsAvailable() and Player:BuffDown(S.ArcaneFamiliarBuff) or Everyone.GroupBuffMissing(S.ArcaneIntellect)) then
      if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- potion,if=buff.siphon_storm.up|(!talent.evocation&cooldown.arcane_surge.ready)
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.SiphonStormBuff) or (not S.Evocation:IsAvailable() and S.ArcaneSurge:CooldownUp())) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    if CDsON() then
      -- lights_judgment,if=buff.arcane_surge.down&debuff.touch_of_the_magi.down&active_enemies>=2
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 4"; end
      end
      if Player:PrevGCDP(1, S.ArcaneSurge) then
        -- berserking,if=prev_gcd.1.arcane_surge
        if S.Berserking:IsCastable() then
          if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
        end
        -- blood_fury,if=prev_gcd.1.arcane_surge
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 8"; end
        end
        -- fireblood,if=prev_gcd.1.arcane_surge
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 10"; end
        end
        -- ancestral_call,if=prev_gcd.1.arcane_surge
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 12"; end
        end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=prev_gcd.1.arcane_surge
    -- invoke_external_buff,name=blessing_of_summer,if=prev_gcd.1.arcane_surge
    -- invoke_external_buff,name=blessing_of_autumn,if=cooldown.touch_of_the_magi.remains>5
    -- Note: Not handling external buffs.
    -- use_items,if=prev_gcd.1.arcane_surge|prev_gcd.1.evocation|fight_remains<20|!variable.steroid_trinket_equipped
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse and (Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation) or BossFightRemains < 20 or not VarSteroidTrinketEquipped) then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " main 14"; end
        end
      end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=high_speakers_accretion,if=(prev_gcd.1.arcane_surge|prev_gcd.1.evocation)|cooldown.evocation.remains<7|fight_remains<20
      if I.HighSpeakersAccretion:IsEquippedAndReady() and ((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation)) or S.Evocation:CooldownRemains() < 7 or BossFightRemains < 20) then
        if Cast(I.HighSpeakersAccretion, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.HighSpeakersAccretion)) then return "high_speakers_accretion main 16"; end
      end
      -- use_item,name=treacherous_transmitter,if=((prev_gcd.1.arcane_surge|prev_gcd.1.evocation)&variable.opener)|cooldown.evocation.remains<6|fight_remains<20
      if I.TreacherousTransmitter:IsEquippedAndReady() and (((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation)) and VarOpener) or S.Evocation:CooldownRemains() < 6 or BossFightRemains < 20) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter main 18"; end
      end
      -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.siphon_storm.up|fight_remains<20
      -- use_item,name=spymasters_web,if=(prev_gcd.1.arcane_surge|prev_gcd.1.evocation)&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment)|fight_remains<20
      if I.SpymastersWeb:IsEquippedAndReady() and ((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation)) and (FightRemains < 80 or Target:HealthPercentage() < 35 or not S.ArcaneBombardment:IsAvailable()) or BossFightRemains < 20) then
        if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web main 20"; end
      end
      -- use_item,name=aberrant_spellforge,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down|(equipped.spymasters_web&target.health.pct>35)
      if I.AberrantSpellforge:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff) or (I.SpymastersWeb:IsEquipped() and Target:HealthPercentage() > 35)) then
        if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge main 22"; end
      end
      -- use_item,name=mad_queens_mandate,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.MadQueensMandate:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.MadQueensMandate)) then return "mad_queens_mandate main 24"; end
      end
      -- use_item,name=mereldars_toll,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.MereldarsToll:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.MereldarsToll, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.MereldarsToll)) then return "mereldars_toll main 26"; end
      end
      -- use_item,name=nymues_unraveling_spindle,if=cooldown.arcane_surge.remains<=(gcd.max*4)|cooldown.arcane_surge.ready|fight_remains<=24
      if I.NymuesUnravelingSpindle:IsEquippedAndReady() and (S.ArcaneSurge:CooldownRemains() <= (GCDMax * 4) or S.ArcaneSurge:CooldownUp() or BossFightRemains <= 24) then
        if Cast(I.NymuesUnravelingSpindle, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.NymuesUnravelingSpindle)) then return "nymues_unraveling_spindle main 28"; end
      end
      -- use_item,name=belorrelos_the_suncaller,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.BelorrelostheSuncaller:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.BelorrelostheSuncaller, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller main 30"; end
      end
      -- use_item,name=beacon_to_the_beyond,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.BeacontotheBeyond:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond main 32"; end
      end
      -- use_item,name=iceblood_deathsnare,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.IcebloodDeathsnare:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.IcebloodDeathsnare, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "iceblood_deathsnare main 34"; end
      end
      -- use_item,name=desperate_invokers_codex,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.DesperateInvokersCodex:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.DesperateInvokersCodex, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "desperate_invokers_codex main 36"; end
      end
      -- use_item,name=conjured_chillglobe,if=mana.pct>65&!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.ConjuredChillglobe:IsEquippedAndReady() and (Player:ManaPercentage() > 65 and not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.ConjuredChillglobe, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "conjured_chillglobe main 38"; end
      end
    end
    if Settings.Commons.Enabled.Items then
      -- use_item,name=dreambinder_loom_of_the_great_cycle
      if I.Dreambinder:IsEquippedAndReady() then
        if Cast(I.Dreambinder, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(45)) then return "dreambinder_loom_of_the_great_cycle main 40"; end
      end
      -- use_item,name=iridal_the_earths_master,use_off_gcd=1,if=gcd.remains
      if I.IridaltheEarthsMaster:IsEquippedAndReady() then
        if Cast(I.IridaltheEarthsMaster, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(40)) then return "iridal_the_earths_master main 42"; end
      end
    end
    -- variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
    -- Note: Added extra TotM checks so we don't get stuck in the opener if TotM is on CD or not talented.
    if (Target:DebuffUp(S.TouchoftheMagiDebuff) or S.TouchoftheMagi:CooldownDown() or not S.TouchoftheMagi:IsAvailable()) and VarOpener then
      VarOpener = false
    end
    -- arcane_barrage,if=fight_remains<2
    if S.ArcaneBarrage:IsReady() and (FightRemains < 2) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 44"; end
    end
    -- call_action_list,name=cd_opener
    if CDsON() then
      local ShouldReturn = CDOpener(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rotation_aoe,if=active_enemies>=(variable.aoe_target_count+talent.impetus+talent.splintering_sorcery)
    if EnemiesCount8ySplash >= (VarAoETargetCount + num(S.Impetus:IsAvailable()) + num(S.SplinteringSorcery:IsAvailable())) then
      local ShouldReturn = RotationAoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rotation_default
    local ShouldReturn = RotationDefault(); if ShouldReturn then return ShouldReturn; end
    -- arcane_barrage
    if S.ArcaneBarrage:IsReady() then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 46"; end
    end
  end
end

local function Init()
  HR.Print("Arcane Mage rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(62, APL, Init)

--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
}

-- Spells
local S = Spell.Warlock.Affliction

-- Items
local I = Item.Warlock.Affliction
local TrinketsOnUseExcludes = {
  I.ConjuredChillglobe:ID(),
  I.DesperateInvokersCodex:ID(),
}

-- Enemies
local Enemies40y, Enemies10ySplash, EnemiesCount10ySplash
local VarPSUp, VarVTUp, VarSRUp, VarCDDoTsUp, VarHasCDs, VarCDsActive
local BossFightRemains = 11111
local FightRemains = 11111

-- Register
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
  S.Haunt:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()
S.Haunt:RegisterInFlight()

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function EvaluateAgony(TargetUnit)
  -- target_if=remains<5,if=active_dot.agony<5
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateAgonyRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff))
end

local function EvaluateSiphonLife(TargetUnit)
  -- target_if=remains<5,if=active_dot.siphon_life<3
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 3)
end

local function EvaluateCorruption(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5)
end

local function EvaluateCorruptionRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.CorruptionDebuff))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet - Moved to APL()
  -- variable,name=cleave_apl,default=0,op=reset
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() then
    if Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>3
  -- NYI precombat multi target
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt precombat 6"; end
  end
  -- unstable_affliction,if=!talent.soul_swap
  if S.UnstableAffliction:IsReady() and (not S.SoulSwap:IsAvailable()) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction precombat 8"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 10"; end
  end
end

local function Variables()
  -- variable,name=ps_up,op=set,value=dot.phantom_singularity.ticking|!talent.phantom_singularity
  VarPSUp = (Target:DebuffUp(S.PhantomSingularityDebuff) or not S.PhantomSingularity:IsAvailable())
  -- variable,name=vt_up,op=set,value=dot.vile_taint_dot.ticking|!talent.vile_taint
  VarVTUp = (Target:DebuffUp(S.VileTaintDebuff) or not S.VileTaint:IsAvailable())
  -- variable,name=sr_up,op=set,value=dot.soul_rot.ticking|!talent.soul_rot
  VarSRUp = (Target:DebuffUp(S.SoulRotDebuff) or not S.SoulRot:IsAvailable())
  -- variable,name=cd_dots_up,op=set,value=variable.ps_up&variable.vt_up&variable.sr_up
  VarCDDoTsUp = (VarPSUp and VarVTUp and VarSRUp)
  -- variable,name=has_cds,op=set,value=talent.phantom_singularity|talent.vile_taint|talent.soul_rot|talent.summon_darkglare
  VarHasCDs = (S.PhantomSingularity:IsAvailable() or S.VileTaint:IsAvailable() or S.SoulRot:IsAvailable() or S.SummonDarkglare:IsAvailable())
  -- variable,name=cds_active,op=set,value=!variable.has_cds|(pet.darkglare.active|variable.cd_dots_up|buff.power_infusion.react)
  VarCDsActive = ((not VarHasCDs) or (HL.GuardiansTable.DarkglareDuration > 0 or VarCDDoTsUp or Player:BuffUp(S.PowerInfusionBuff)))
end

local function Items()
  -- use_items,if=variable.cds_active
  if (VarCDsActive) then
    local TrinketToUse = Player:GetUseableTrinkets(TrinketsOnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- use_item,name=desperate_invokers_codex
  if I.DesperateInvokersCodex:IsEquippedAndReady() then
    if Cast(I.DesperateInvokersCodex, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "desperate_invokers_codex items 2"; end
  end
  -- use_item,name=conjured_chillglobe
  if I.ConjuredChillglobe:IsEquippedAndReady() then
    if Cast(I.ConjuredChillglobe, nil, Settings.Commons.DisplayStyle.Trinkets) then return "conjured_chillglobe items 4"; end
  end
end

local function oGCD()
  if VarCDsActive then
    -- potion,if=variable.cds_active
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion ogcd 2"; end
      end
    end
    -- berserking,if=variable.cds_active
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking ogcd 4"; end
    end
    -- blood_fury,if=variable.cds_active
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury ogcd 6"; end
    end
    -- invoke_external_buff,name=power_infusion,if=variable.cds_active
    -- Note: Not handling external buffs
    -- fireblood,if=variable.cds_active
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood ogcd 8"; end
    end
  end
end

local function AoE()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if CDsON() and Settings.Commons.Enabled.Trinkets then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt aoe 2"; end
  end
  -- vile_taint
  if CDsON() and S.VileTaint:IsReady() then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint aoe 4"; end
  end
  -- phantom_singularity
  if CDsON() and S.PhantomSingularity:IsCastable() then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity aoe 6"; end
  end
  -- soul_rot
  if CDsON() and S.SoulRot:IsReady() then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot aoe 8"; end
  end
  -- seed_of_corruption,if=dot.corruption.remains<5
  if S.SeedofCorruption:IsReady() and Target:DebuffRemains(S.SeedofCorruptionDebuff) < 5 then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "soul_rot aoe 10"; end
  end
  -- agony,target_if=remains<5,if=active_dot.agony<5
  if S.Agony:IsReady() then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateAgony, not Target:IsSpellInRange(S.Agony)) then return "agony aoe 12"; end
  end
  -- summon_darkglare
  if CDsON() and S.SummonDarkglare:IsCastable() then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare aoe 14"; end
  end
  -- seed_of_corruption,if=talent.sow_the_seeds
  if S.SeedofCorruption:IsReady() and S.SowTheSeeds:IsAvailable() then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "soul_rot aoe 16"; end
  end
  -- malefic_rapture
  if S.MaleficRapture:IsReady() then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture aoe 18"; end
  end
  -- drain_life,if=(buff.soul_rot.up|!talent.soul_rot)&buff.inevitable_demise.stack>10
  if S.DrainLife:IsReady() and (Target:DebuffUp(S.SoulRotDebuff) or not S.SoulRot:IsAvailable()) and Player:BuffStack(S.InevitableDemiseBuff) > 10 then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life aoe 20"; end
  end
  -- summon_soulkeeper,if=buff.tormented_soul.stack=10|buff.tormented_soul.stack>3&time_to_die<10
  if S.SummonSoulkeeper:IsReady() and (S.SummonSoulkeeper:Count() == 10 or S.SummonSoulkeeper:Count() > 3 and FightRemains < 10) then
    if Cast(S.SummonSoulkeeper) then return "soul_strike aoe 22"; end
  end
  -- siphon_life,target_if=remains<5,if=active_dot.siphon_life<3
  if S.SiphonLife:IsReady() then
    if Cast(S.SiphonLife, Enemies40y, EvaluateSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life aoe 24"; end
  end
  -- drain_soul,interrupt_global=1
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 26"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt aoe 28"; end
  end
end

local function Cleave()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if CDsON() and Settings.Commons.Enabled.Trinkets then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt cleave 2"; end
  end
  -- unstable_affliction,if=remains<5
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction cleave 6"; end
  end
  -- agony,if=remains<5
  if S.Agony:IsReady() and Target:DebuffRemains(S.AgonyDebuff) < 5 then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 8"; end
  end
  -- agony,target_if=!(target=self.target)&remains<5
  if S.Agony:IsReady() then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateAgony, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 10"; end
  end
  -- siphon_life,if=remains<5
  if S.SiphonLife:IsCastable() and (Target:DebuffRemains(S.SiphonLifeDebuff) < 5) then
    if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life cleave 12"; end
  end
  -- siphon_life,target_if=!(target=self.target)&remains<3
  if S.SiphonLife:IsReady() then
    if Cast(S.SiphonLife, Enemies40y, EvaluateSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life cleave 14"; end
  end
  -- seed_of_corruption,if=!talent.absolute_corruption&dot.corruption.remains<5
  if S.SeedofCorruption:IsReady() and not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.CorruptionDebuff) < 5 then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption cleave 16"; end
  end
  -- corruption,target_if=remains<5&(talent.absolute_corruption|!talent.seed_of_corruption)
  if S.Corruption:IsCastable() and (S.AbsoluteCorruption:IsAvailable() or not S.SeedofCorruption:IsAvailable()) then
    if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCorruption, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 18"; end
  end
  -- phantom_singularity
  if CDsON() and S.PhantomSingularity:IsCastable() then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity cleave 20"; end
  end
  -- vile_taint
  if CDsON() and S.VileTaint:IsReady() then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint cleave 22"; end
  end
  -- soul_rot
  if CDsON() and S.SoulRot:IsReady() then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot cleave 24"; end
  end
  -- summon_darkglare
  if CDsON() and S.SummonDarkglare:IsCastable() then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare cleave 26"; end
  end
  -- malefic_rapture,if=talent.malefic_affliction&buff.malefic_affliction.stack<3
  if S.MaleficRapture:IsReady() and S.MaleficAffliction:IsAvailable() and Player:BuffStack(S.MaleficAfflictionBuff) < 3 then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 28"; end
  end
  -- malefic_rapture,if=talent.dread_touch&debuff.dread_touch.remains<gcd
  if S.MaleficRapture:IsReady() and S.DreadTouch:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < Player:GCD() then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 30"; end
  end
  -- malefic_rapture,if=!talent.dread_touch&buff.tormented_crescendo.up
  if S.MaleficRapture:IsReady() and not S.DreadTouch:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 32"; end
  end
  -- malefic_rapture,if=!talent.dread_touch&(dot.soul_rot.remains>cast_time|dot.phantom_singularity.remains>cast_time|dot.vile_taint_dot.remains>cast_time|pet.darkglare.active)
  if S.MaleficRapture:IsReady() and not S.DreadTouch:IsAvailable() and (Target:DebuffRemains(S.SoulRotDebuff) > S.MaleficRapture:CastTime() or Target:DebuffRemains(S.PhantomSingularityDebuff) > S.MaleficRapture:CastTime() or Target:DebuffRemains(S.VileTaintDebuff) > S.MaleficRapture:CastTime() or HL.GuardiansTable.DarkglareDuration > 0) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 34"; end
  end
  -- drain_soul,if=buff.nightfall.react
  if S.DrainSoul:IsReady() and Player:BuffUp(S.NightfallBuff) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul cleave 36"; end
  end
  -- shadow_bolt,if=buff.nightfall.react
  if S.ShadowBolt:IsReady() and Player:BuffUp(S.NightfallBuff) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt cleave 38"; end
  end
  -- drain_life,if=buff.inevitable_demise.stack>48|buff.inevitable_demise.stack>20&time_to_die<4
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 48 or Player:BuffStack(S.InevitableDemiseBuff) > 20 and FightRemains < 4) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life cleave 40"; end
  end
  -- drain_life,if=buff.soul_rot.up&buff.inevitable_demise.stack>10
  if S.DrainLife:IsReady() and Target:DebuffUp(S.SoulRotDebuff) and Player:BuffStack(S.InevitableDemiseBuff) > 10 then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life cleave 42"; end
  end
  -- agony,target_if=refreshable
  if S.Agony:IsReady() then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateAgonyRefreshable, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 44"; end
  end
  -- corruption,target_if=refreshable
  if S.Corruption:IsCastable() then
    if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCorruptionRefreshable, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 46"; end
  end
  -- drain_soul,interrupt_global=1
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul cleave 48"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt cleave 50"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesCount10ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end
  end

  -- summon_pet 
  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if (not Player:AffectingCombat()) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=cleave,if=active_enemies!=1&active_enemies<4|variable.cleave_apl
    if (EnemiesCount10ySplash > 1 and EnemiesCount10ySplash < 4) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>3
    if (EnemiesCount10ySplash > 3) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd
    if CDsON() then
      local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if CDsON() and Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- unstable_affliction,if=remains<5
    if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
      if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 4"; end
    end
    -- agony,if=remains<5
    if S.Agony:IsCastable() and (Target:DebuffRemains(S.AgonyDebuff) < 5) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 6"; end
    end
    -- corruption,if=remains<5
    if S.Corruption:IsCastable() and (Target:DebuffRemains(S.CorruptionDebuff) < 5) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 8"; end
    end
    -- siphon_life,if=remains<5
    if S.SiphonLife:IsCastable() and (Target:DebuffRemains(S.SiphonLifeDebuff) < 5) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life main 10"; end
    end
    -- haunt
    if S.Haunt:IsReady() then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 12"; end
    end
    -- drain_soul,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
    if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 14"; end
    end
    -- shadow_bolt,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
    if S.ShadowBolt:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 16"; end
    end
    -- phantom_singularity,if=!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|!talent.summon_darkglare
    if CDsON() and S.PhantomSingularity:IsCastable() and ((not S.SoulRot:IsAvailable()) or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or not S.SummonDarkglare:IsAvailable()) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 18"; end
    end
    -- vile_taint,if=!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<2&cooldown.soul_rot.remains>=12
    if CDsON() and S.VileTaint:IsReady() and ((not S.SoulRot:IsAvailable()) or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() or S.SouleatersGluttony:TalentRank() < 2 and S.SoulRot:CooldownRemains() >= 12) then
      if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint main 20"; end
    end
    -- soul_rot,if=variable.ps_up&variable.vt_up|!talent.summon_darkglare
    if CDsON() and S.SoulRot:IsReady() and (VarPSUp and VarVTUp or not S.SummonDarkglare:IsAvailable()) then
      if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot main 22"; end
    end
    -- summon_darkglare,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
    -- Note: Not handling Power Infusion
    if CDsON() and S.SummonDarkglare:IsCastable() and (VarPSUp and VarVTUp and VarSRUp) then
      if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare main 24"; end
    end
    if S.MaleficRapture:IsReady() and (
      -- malefic_rapture,if=soul_shard>4|(talent.tormented_crescendo&buff.tormented_crescendo.stack=1&soul_shard>3)
      (Player:SoulShardsP() > 4 or (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and Player:SoulShardsP() > 3)) or
      -- malefic_rapture,if=talent.dread_touch&talent.malefic_affliction&debuff.dread_touch.remains<2&buff.malefic_affliction.stack=3
      (S.DreadTouch:IsAvailable() and S.MaleficAffliction:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < 2 and Player:BuffStack(S.MaleficAfflictionBuff) == 3) or
      -- malefic_rapture,if=talent.malefic_affliction&buff.malefic_affliction.stack<3
      (S.MaleficAffliction:IsAvailable() and Player:BuffStack(S.MaleficAfflictionBuff) < 3) or
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react&!debuff.dread_touch.react
      (S.TormentedCrescendo:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Target:DebuffDown(S.DreadTouchDebuff)) or
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.stack=2
      (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 2) or
      -- malefic_rapture,if=variable.cd_dots_up|dot.vile_taint_dot.ticking&soul_shard>1
      (VarCDDoTsUp or Target:DebuffUp(S.VileTaintDebuff) and Player:SoulShardsP() > 1) or
      -- malefic_rapture,if=talent.tormented_crescendo&talent.nightfall&buff.tormented_crescendo.react&buff.nightfall.react
      (S.TormentedCrescendo:IsAvailable() and S.Nightfall:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Player:BuffUp(S.NightfallBuff))
    ) then
        if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 26"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>48|buff.inevitable_demise.stack>20&time_to_die<4
    if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 48 or Player:BuffStack(S.InevitableDemiseBuff) > 20 and FightRemains < 4) then
      if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life main 28"; end
    end
    -- drain_soul,if=buff.nightfall.react
    if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 30"; end
    end
    -- shadow_bolt,if=buff.nightfall.react
    if S.ShadowBolt:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 32"; end
    end
    -- agony,if=refreshable
    if S.Agony:IsCastable() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 34"; end
    end
    -- corruption,if=refreshable
    if S.Corruption:IsCastable() and (Target:DebuffRefreshable(S.CorruptionDebuff)) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 36"; end
    end
    -- drain_soul,interrupt=1
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 40"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 42"; end
    end
  end
end

local function OnInit()
  HR.Print("Affliction Warlock rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(265, APL, OnInit)
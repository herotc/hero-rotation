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
local MultiSpell    = HL.MultiSpell
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
  Commons = HR.GUISettings.APL.Druid.Commons,
  Guardian = HR.GUISettings.APL.Druid.Guardian
}

-- Spells
local S = Spell.Druid.Guardian

-- Items
local I = Item.Druid.Guardian
local OnUseExcludes = {
  I.Djaruun:ID(),
  I.Jotungeirr:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Variables
local ActiveMitigationNeeded
local IsTanking
local UseMaul
local VarIFBuild = (S.ThornsofIron:IsAvailable() and S.ReinforcedFur:IsAvailable())

-- Enemies Variables
local MeleeEnemies11y, MeleeEnemies11yCount

-- Event Registrations
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  IFBuild = (S.ThornsofIron:IsAvailable() and S.ReinforcedFur:IsAvailable())
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

-- Functions
local function NoToothandClaw(enemies)
  for _, CycleUnit in pairs(enemies) do
    if CycleUnit:DebuffUp(S.ToothandClawDebuff) then
      return false
    end
  end
  return true
end

-- Cycle Functions
local function EvaluateCycleMoonfire(TargetUnit)
  -- if=(((!ticking&time_to_die>12)|(refreshable&time_to_die>12))&active_enemies<7&talent.fury_of_nature.enabled)|(((!ticking&time_to_die>12)|(refreshable&time_to_die>12))&active_enemies<4&!talent.fury_of_nature.enabled)
  -- Note: !ticking and refreshable are both covered by DebuffRefreshable
  -- Note: Combined both halves of the line for ease
  return ((TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12) and (MeleeEnemies11yCount < 7 and S.FuryofNature:IsAvailable() or MeleeEnemies11yCount < 4 and not S.FuryofNature:IsAvailable()))
end

local function EvaluateCycleThrash(TargetUnit)
  -- target_if=refreshable|(dot.thrash_bear.stack<5&talent.flashing_claws.rank=2|dot.thrash_bear.stack<4&talent.flashing_claws.rank=1|dot.thrash_bear.stack<3&!talent.flashing_claws.enabled)
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff) or (Target:DebuffStack(S.ThrashDebuff) < 5 and S.FlashingClaws:TalentRank() == 2 or Target:DebuffStack(S.ThrashDebuff) < 4 and S.FlashingClaws:TalentRank() == 1 or Target:DebuffStack(S.ThrashDebuff) < 3 and not S.FlashingClaws:IsAvailable()))
end

local function EvaluateCycleThrash2(TargetUnit)
  -- target_if=refreshable|dot.thrash_bear.stack<3|active_enemies>=5
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff) or TargetUnit:DebuffStack(S.ThrashDebuff) < 3 or MeleeEnemies11yCount >= 5)
end

local function EvaluateCyclePulverize(TargetUnit)
  -- target_if=dot.thrash_bear.stack>2
  return (TargetUnit:DebuffStack(S.ThrashDebuff) > 2)
end

local function Defensives()
  if Player:HealthPercentage() < Settings.Guardian.FrenziedRegenHP and S.FrenziedRegeneration:IsReady() and Player:BuffDown(S.FrenziedRegenerationBuff) and not Player:HealingAbsorbed() then
    if Cast(S.FrenziedRegeneration, nil, Settings.Guardian.DisplayStyle.Defensives) then return "frenzied_regeneration defensive 2"; end
  end
  if S.Regrowth:IsCastable() and Player:BuffUp(S.DreamofCenariusBuff) and (Player:BuffDown(S.PoPHealBuff) and Player:HealthPercentage() < Settings.Guardian.DoCRegrowthNoPoPHP or Player:BuffUp(S.PoPHealBuff) and Player:HealthPercentage() < Settings.Guardian.DoCRegrowthWithPoPHP) then
    if Cast(S.Regrowth, nil, Settings.Guardian.DisplayStyle.Defensives) then return "regrowth defensive 4"; end
  end
  if S.Renewal:IsCastable() and Player:HealthPercentage() < Settings.Guardian.RenewalHP then
    if Cast(S.Renewal, nil, Settings.Guardian.DisplayStyle.Defensives) then return "renewal defensive 6"; end
  end
  if S.Ironfur:IsReady() and (Player:BuffDown(S.IronfurBuff) or Player:BuffStack(S.IronfurBuff) < 2 and Player:BuffRefreshable(S.Ironfur)) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur defensive 8"; end
  end
  if S.Barkskin:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.BarkskinHP and Player:BuffDown(S.IronfurBuff) or Player:HealthPercentage() < Settings.Guardian.BarkskinHP * 0.75) then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin defensive 10"; end
  end
  if S.SurvivalInstincts:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.SurvivalInstinctsHP) then
    if Cast(S.SurvivalInstincts, nil, Settings.Guardian.DisplayStyle.Defensives) then return "survival_instincts defensive 12"; end
  end
  if S.BristlingFur:IsCastable() and (Player:Rage() < Settings.Guardian.BristlingFurRage) then
    if Cast(S.BristlingFur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "bristling_fur defensive 14"; end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=If_build,value=1,value_else=0,if=talent.thorns_of_iron.enabled&talent.reinforced_fur.enabled
  -- Note: Moved to variable declarations and PLAYER_TALENT_UPDATE registration
  -- cat_form,if=(druid.catweave_bear=1&(cooldown.pause_action.remains|time>30))
  -- moonkin_form,if=(!druid.catweave_bear=1)&(cooldown.pause_action.remains|time>30)
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled
  -- prowl,if=druid.catweave_bear=1&(cooldown.pause_action.remains|time>30)
  -- NOTE: Not handling cat-weaving or owl-weaving, so skipping above 4 lines
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and Everyone.GroupBuffMissing(S.MarkoftheWildBuff) then
    if Cast(S.MarkoftheWild, Settings.Commons.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat 2"; end
  end
  -- bear_form,if=(!buff.prowl.up)
  if S.BearForm:IsCastable() then
    if Cast(S.BearForm) then return "bear_form precombat 4"; end
  end
  -- Manually added: moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire precombat 8"; end
  end
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (Target:IsInRange(25) and not Target:IsInRange(8)) then
    if Cast(S.WildCharge) then return "wild_charge precombat 10"; end
  end
  -- Manually added: thrash_bear
  if S.Thrash:IsCastable() and Target:IsInRange(8) then
    if Cast(S.Thrash) then return "thrash precombat 12"; end
  end
  -- Manually added: mangle
  if S.Mangle:IsCastable() and Target:IsInMeleeRange(5) then
    if Cast(S.Mangle) then return "mangle precombat 14"; end
  end
end

local function CatWeave()
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up&!buff.cat_form.up
  -- cat_form,if=!buff.cat_form.up
  -- rake,if=buff.prowl.up
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up
  -- rake,if=dot.rake.refreshable|energy<45
  -- rip,if=dot.rip.refreshable&combo_points>=1
  -- convoke_the_spirits
  -- ferocious_bite,if=combo_points>=4&energy>50
  -- shred,if=combo_points<=5
end

local function Bear()
  -- bear_form,if=!buff.bear_form.up
  if S.BearForm:IsCastable() then
    if Cast(S.BearForm) then return "bear_form bear 2"; end
  end
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled
  if S.HeartoftheWild:IsCastable() then
    if Cast(S.HeartoftheWild, Settings.Guardian.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild bear 4"; end
  end
  -- moonfire,cycle_targets=1,if=(((!ticking&time_to_die>12)|(refreshable&time_to_die>12))&active_enemies<7&talent.fury_of_nature.enabled)|(((!ticking&time_to_die>12)|(refreshable&time_to_die>12))&active_enemies<4&!talent.fury_of_nature.enabled)
  if S.Moonfire:IsReady() then
    if Everyone.CastCycle(S.Moonfire, MeleeEnemies11y, EvaluateCycleMoonfire, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 6"; end
  end
  -- thrash_bear,target_if=refreshable|(dot.thrash_bear.stack<5&talent.flashing_claws.rank=2|dot.thrash_bear.stack<4&talent.flashing_claws.rank=1|dot.thrash_bear.stack<3&!talent.flashing_claws.enabled)
  if S.Thrash:IsCastable() then
    if Everyone.CastCycle(S.Thrash, MeleeEnemies11y, EvaluateCycleThrash, not Target:IsInMeleeRange(8)) then return "thrash bear 8"; end
  end
  -- bristling_fur,if=!cooldown.pause_action.remains
  -- Note: Handled in Defensives()
  -- barkskin,if=!buff.bear_form.up
  if S.Barkskin:IsReady() and (Player:BuffDown(S.BearForm)) then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin bear 10"; end
  end
  if CDsON() then
    -- convoke_the_spirits
    if S.ConvoketheSpirits:IsCastable() then
      if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature) then return "convoke_the_spirits bear 12"; end
    end
    -- berserk_bear
    if S.Berserk:IsCastable() then
      if Cast(S.Berserk, Settings.Guardian.OffGCDasOffGCD.Berserk) then return "berserk bear 14"; end
    end
    -- incarnation
    if S.Incarnation:IsCastable() then
      if Cast(S.Incarnation, Settings.Guardian.OffGCDasOffGCD.Incarnation) then return "incarnation bear 16"; end
    end
  end
  -- lunar_beam
  if S.LunarBeam:IsReady() and CDsON() then
    if Cast(S.LunarBeam) then return "lunar_beam bear 18"; end
  end
  -- rage_of_the_sleeper,if=buff.incarnation_guardian_of_ursoc.down&cooldown.incarnation_guardian_of_ursoc.remains>60|buff.incarnation_guardian_of_ursoc.up|(talent.convoke_the_spirits.enabled)
  if S.RageoftheSleeper:IsCastable() and (IsTanking) and (Player:BuffDown(S.IncarnationBuff) and S.Incarnation:CooldownRemains() > 60 or Player:BuffUp(S.IncarnationBuff) or S.ConvoketheSpirits:IsAvailable()) then
    if Cast(S.RageoftheSleeper) then return "rage_of_the_sleeper bear 20"; end
  end
  -- berserking,if=(buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)
  if S.Berserking:IsCastable() and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.IncarnationBuff)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking bear 22"; end
  end
  -- maul,if=(buff.rage_of_the_sleeper.up&buff.tooth_and_claw.stack>0&active_enemies<=6&!talent.raze.enabled&variable.If_build=0)|(buff.rage_of_the_sleeper.up&buff.tooth_and_claw.stack>0&active_enemies=1&talent.raze.enabled&variable.If_build=0)
  -- Note: Simplified the condition.
  if S.Maul:IsReady() and UseMaul and ((Player:BuffUp(S.RageoftheSleeper) and Player:BuffStack(S.ToothandClawBuff) > 0 and not VarIFBuild) and (MeleeEnemies11yCount <= 6 and not S.Raze:IsAvailable() or MeleeEnemies11yCount == 1 and S.Raze:IsAvailable())) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(8)) then return "maul bear 24"; end
  end
  -- raze,if=buff.rage_of_the_sleeper.up&buff.tooth_and_claw.stack>0&variable.If_build=0&active_enemies>1
  if S.Raze:IsReady() and (Player:BuffUp(S.RageoftheSleeper) and Player:BuffStack(S.ToothandClawBuff) > 0 and not VarIFBuild and MeleeEnemies11yCount > 1) then
    if Cast(S.Raze, nil, nil, not Target:IsInMeleeRange(5)) then return "raze bear 26"; end
  end
  -- maul,if=(((buff.incarnation.up|buff.berserk_bear.up)&active_enemies<=5&!talent.raze.enabled&(buff.tooth_and_claw.stack>=1))&variable.If_build=0)|(((buff.incarnation.up|buff.berserk_bear.up)&active_enemies=1&talent.raze.enabled&(buff.tooth_and_claw.stack>=1))&variable.If_build=0)
  -- Note: Simplified the condition.
  if S.Maul:IsReady() and UseMaul and (((Player:BuffUp(S.IncarnationBuff) or Player:BuffUp(S.BerserkBuff)) and Player:BuffStack(S.ToothandClawBuff) >= 1) and not VarIFBuild and (MeleeEnemies11yCount <= 5 and not S.Raze:IsAvailable() or MeleeEnemies11yCount == 1 and S.Raze:IsAvailable())) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(8)) then return "maul bear 28"; end
  end
  -- raze,if=(buff.incarnation.up|buff.berserk_bear.up)&(variable.If_build=0)&active_enemies>1
  if S.Raze:IsReady() and ((Player:BuffUp(S.IncarnationBuff) or Player:BuffUp(S.BerserkBuff)) and not VarIFBuild and MeleeEnemies11yCount > 1) then
    if Cast(S.Raze, nil, nil, not Target:IsInMeleeRange(5)) then return "raze bear 30"; end
  end
  -- ironfur,target_if=!debuff.tooth_and_claw_debuff.up,if=!buff.ironfur.up&rage>50&!cooldown.pause_action.remains&variable.If_build=0&!buff.rage_of_the_sleeper.up|rage>90&variable.If_build=0&!buff.rage_of_the_sleeper.up
  if S.Ironfur:IsReady() and not VarIFBuild and Settings.Guardian.UseIronfurOffensively and (Target:DebuffDown(S.ToothandClawDebuff) and (Player:BuffDown(S.IronfurBuff) and Player:Rage() > 50 and IsTanking and Player:BuffDown(S.RageoftheSleeper) or Player:Rage() > 90 and Player:BuffDown(S.RageoftheSleeper))) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur bear 32"; end
  end
  -- ironfur,if=rage>90&variable.If_build=1|(buff.incarnation.up|buff.berserk_bear.up)&rage>20&variable.If_build=1
  if S.Ironfur:IsReady() and Settings.Guardian.UseIronfurOffensively and (Player:Rage() > 90 and VarIFBuild or (Player:BuffUp(S.IncarnationBuff) or Player:BuffUp(S.BerserkBuff)) and Player:Rage() > 20 and VarIFBuild) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur bear 34"; end
  end
  -- raze,if=(buff.tooth_and_claw.up)&active_enemies>1
  if S.Raze:IsReady() and (Player:BuffUp(S.ToothandClawBuff) and MeleeEnemies11yCount > 1) then
    if Cast(S.Raze, nil, nil, not Target:IsInMeleeRange(5)) then return "raze bear 36"; end
  end
  -- raze,if=(variable.If_build=0)&active_enemies>1
  if S.Raze:IsReady() and not VarIFBuild and (MeleeEnemies11yCount > 1) then
    if Cast(S.Raze, nil, nil, not Target:IsInMeleeRange(5)) then return "raze bear 38"; end
  end
  -- mangle,if=buff.gore.up&active_enemies<11|buff.vicious_cycle_mangle.stack=3
  if S.Mangle:IsCastable() and (Player:BuffUp(S.GoreBuff) and MeleeEnemies11yCount < 11 or Player:BuffStack(S.ViciousCycleMaulBuff) == 3) then
    if Cast(S.Mangle, nil, nil, not Target:IsInMeleeRange(8)) then return "mangle bear 40"; end
  end
  -- maul,if=(buff.tooth_and_claw.up&active_enemies<=5&!talent.raze.enabled)|(buff.tooth_and_claw.up&active_enemies=1&talent.raze.enabled)
  -- Note: Simplified the condition
  if S.Maul:IsReady() and (Player:BuffUp(S.ToothandClawBuff) and (MeleeEnemies11yCount <= 5 and not S.Raze:IsAvailable() or MeleeEnemies11yCount == 1 and S.Raze:IsAvailable())) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 42"; end
  end
  -- maul,if=(active_enemies<=5&!talent.raze.enabled&variable.If_build=0)|(active_enemies=1&talent.raze.enabled&variable.If_build=0)
  if S.Maul:IsReady() and not VarIFBuild and (MeleeEnemies11yCount <= 5 and not S.Raze:IsAvailable() or MeleeEnemies11yCount == 1 and S.Raze:IsAvailable()) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 44"; end
  end
  -- thrash_bear,target_if=active_enemies>=5
  if S.Thrash:IsCastable() and (MeleeEnemies11yCount >= 5) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bear 46"; end
  end
  -- swipe,if=buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&active_enemies>=11
  if S.Swipe:IsCastable() and (Player:BuffDown(S.IncarnationBuff) and Player:BuffDown(S.BerserkBuff) and MeleeEnemies11yCount >= 11) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe bear 48"; end
  end
  -- mangle,if=(buff.incarnation.up&active_enemies<=4)|(buff.incarnation.up&talent.soul_of_the_forest.enabled&active_enemies<=5)|((rage<90)&active_enemies<11)|((rage<85)&active_enemies<11&talent.soul_of_the_forest.enabled)
  if S.Mangle:IsCastable() and ((Player:BuffUp(S.IncarnationBuff) and MeleeEnemies11yCount <= 4) or (Player:BuffUp(S.IncarnationBuff) and S.SouloftheForest:IsAvailable() and MeleeEnemies11yCount <= 5) or (Player:Rage() < 90 and MeleeEnemies11yCount < 11) or (Player:Rage() < 85 and MeleeEnemies11yCount < 11 and S.SouloftheForest:IsAvailable())) then
    if Cast(S.Mangle, nil, nil, not Target:IsInMeleeRange(8)) then return "mangle bear 50"; end
  end
  -- thrash_bear,if=active_enemies>1
  if S.Thrash:IsCastable() and (MeleeEnemies11yCount > 1) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash bear 52"; end
  end
  -- pulverize,target_if=dot.thrash_bear.stack>2
  if S.Pulverize:IsReady() then
    if Everyone.CastCycle(S.Pulverize, MeleeEnemies11y, EvaluateCyclePulverize, not Target:IsInMeleeRange(8)) then return "pulverize bear 54"; end
  end
  -- thrash_bear
  if S.Thrash:IsCastable() then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash bear 56"; end
  end
  -- moonfire,if=buff.galactic_guardian.up
  if S.Moonfire:IsCastable() and (Player:BuffUp(S.GalacticGuardianBuff)) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 58"; end
  end
  -- swipe_bear
  if S.Swipe:IsCastable() then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe bear 60"; end
  end
end

local function APL()
  -- Enemies Update
  if AoEON() then
    MeleeEnemies11y = Player:GetEnemiesInMeleeRange(11)
    MeleeEnemies11yCount = #MeleeEnemies11y
  else
    MeleeEnemies11y = {}
    MeleeEnemies11yCount = 1
  end

  ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  UseMaul = false
  if ((Player:Rage() >= S.Maul:Cost() + 20 and not IsTanking) or Player:RageDeficit() <= 10 or not Settings.Guardian.UseRageDefensively) then
    UseMaul = true
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(13, S.SkullBash, Settings.Guardian.OffGCDasOffGCD.SkullBash, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: run_action_list,name=defensives
    if (IsTanking and Player:BuffUp(S.BearForm)) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: wild_charge if not in range
    if S.WildCharge:IsCastable() and not Target:IsInRange(8) then
      if Cast(S.WildCharge, Settings.Commons.GCDasOffGCD.WildCharge, nil, not Target:IsInRange(28)) then return "wild_charge main"; end
    end
    -- auto_attack,if=!buff.prowl.up
    -- use_item,name=jotungeirr_destinys_call,if=!buff.prowl.up&!covenant.venthyr
    if Settings.Commons.Enabled.Items and I.Jotungeirr:IsEquippedAndReady() then
      if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call main 2"; end
    end
    -- use_item,slot=trinket1
    -- use_item,slot=trinket2
    if Settings.Commons.Enabled.Trinkets then
      local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
      if Trinket1ToUse then
        if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name(); end
      end
      local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
      if Trinket2ToUse then
        if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name(); end
      end
    end
    -- use_item,name=djaruun_pillar_of_the_elder_flame,if=dot.moonfire.ticking
    if Settings.Commons.Enabled.Items and I.Djaruun:IsEquippedAndReady() and (Target:DebuffUp(S.MoonfireDebuff)) then
      if Cast(I.Djaruun, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame main 4"; end
    end
    -- potion,if=((talent.heart_of_the_wild.enabled&buff.heart_of_the_wild.up)|((buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)&(!druid.catweave_bear&!druid.owlweave_bear)))
    if Settings.Commons.Enabled.Potions and ((S.HeartoftheWild:IsAvailable() and Player:BuffUp(S.HeartoftheWild)) or (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.Incarnation))) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- run_action_list,name=catweave,if=(target.cooldown.pause_action.remains|time>=30)&druid.catweave_bear=1&buff.tooth_and_claw.remains>1.5&(buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down)&(cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0&dot.moonfire.remains>=2)|(buff.cat_form.up&energy>25&druid.catweave_bear=1&buff.tooth_and_claw.remains>1.5)|(buff.heart_of_the_wild.up&energy>90&druid.catweave_bear=1&buff.tooth_and_claw.remains>1.5)
    -- run_action_list,name=owlweave,if=(target.cooldown.pause_action.remains|time>=30)&buff.tooth_and_claw.remains<1.5&((druid.owlweave_bear=1)&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&cooldown.starsurge.up)
    -- Skipping the above lists, as we're not handling catweaving or owlweaving
    -- run_action_list,name=bear
    local ShouldReturn = Bear(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pool if nothing to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function OnInit()
  HR.Print("Guardian Druid rotation is currently a work in progress, but has been updated for patch 10.1.5.")
end

HR.SetAPL(104, APL, OnInit)

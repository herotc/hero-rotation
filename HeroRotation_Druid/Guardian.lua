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
-- lua
local mathfloor     = math.floor

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Druid.Guardian
local I = Item.Druid.Guardian

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.Item:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  CommonsDS = HR.GUISettings.APL.Druid.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Druid.CommonsOGCD,
  Guardian = HR.GUISettings.APL.Druid.Guardian
}

--- ===== Rotation Variables =====
local MeleeRange, AoERange
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local UseMaul
local MeleeEnemies8y, MeleeEnemies8yCount

--- ===== CastCycle Functions =====
local function EvaluateCycleMoonfire(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.MoonfireDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and Everyone.GroupBuffMissing(S.MarkoftheWildBuff) then
    if Cast(S.MarkoftheWild, Settings.CommonsOGCD.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat 2"; end
  end
  -- bear_form
  if S.BearForm:IsCastable() then
    if Cast(S.BearForm) then return "bear_form precombat 4"; end
  end
  -- Manually added: moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire precombat 8"; end
  end
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (Target:IsInRange(S.WildCharge.MaximumRange) and not Target:IsInRange(S.WildCharge.MinimumRange)) then
    if Cast(S.WildCharge) then return "wild_charge precombat 10"; end
  end
  -- Manually added: thrash_bear
  if S.Thrash:IsCastable() and IsInAoERange then
    if Cast(S.Thrash) then return "thrash precombat 12"; end
  end
  -- Manually added: mangle
  if S.Mangle:IsCastable() and IsInMeleeRange then
    if Cast(S.Mangle) then return "mangle precombat 14"; end
  end
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
  if S.BristlingFur:IsCastable() and (Player:Rage() < Settings.Guardian.BristlingFurRage and S.RageoftheSleeper:CooldownRemains() > 8) then
    if Cast(S.BristlingFur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "bristling_fur defensive 14"; end
  end
end

local function APL()
  -- Enemies Update
  MeleeEnemies8y = Player:GetEnemiesInMeleeRange(8)
  if AoEON() then
    MeleeEnemies8yCount = #MeleeEnemies8y
  else
    MeleeEnemies8yCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

    UseMaul = false
    if ((Player:Rage() >= S.Maul:Cost() + 20 and not IsTanking) or Player:RageDeficit() <= 10 or not Settings.Guardian.UseRageDefensively) then
      UseMaul = true
    end

    IsInMeleeRange = Target:IsInRange(5)
    IsInAoERange = Target:IsInRange(8)
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(S.SkullBash, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: run_action_list,name=defensives
    if (IsTanking and Player:BuffUp(S.BearForm)) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: wild_charge if not in range
    if S.WildCharge:IsCastable() and not Target:IsInRange(8) then
      if Cast(S.WildCharge, Settings.CommonsOGCD.GCDasOffGCD.WildCharge, nil, not Target:IsInRange(S.WildCharge.MaximumRange)) then return "wild_charge main 2"; end
    end
    -- use_items
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " main 4"; end
        end
      end
    end
    -- auto_attack
    -- incarnation
    if CDsON() and S.Incarnation:IsCastable() then
      if Cast(S.Incarnation, Settings.Guardian.OffGCDasOffGCD.Incarnation) then return "incarnation main 6"; end
    end
    -- berserk
    if CDsON() and S.Berserk:IsCastable() then
      if Cast(S.Berserk, Settings.Guardian.OffGCDasOffGCD.Berserk) then return "berserk main 8"; end
    end
    -- heart_of_the_wild
    if CDsON() and S.HeartoftheWild:IsCastable() then
      if Cast(S.HeartoftheWild, Settings.Guardian.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild main 10"; end
    end
    -- natures_vigil
    if CDsON() and S.NaturesVigil:IsCastable() then
      if Cast(S.NaturesVigil, Settings.Guardian.OffGCDasOffGCD.NaturesVigil) then return "natures_vigil main 12"; end
    end
    -- convoke_the_spirits
    if CDsON() and S.ConvoketheSpirits:IsCastable() then
      if Cast(S.ConvoketheSpirits, nil, Settings.CommonsDS.DisplayStyle.ConvokeTheSpirits) then return "convoke_the_spirits main 14"; end
    end
    -- stampeding_roar
    -- Note: Not adding movement speed boost.
    -- growl
    -- Note: Not adding taunt.
    -- frenzied_regeneration
    -- barkskin
    -- survival_instincts
    -- Note: Above 3 lines are handled in Defensives.
    -- pulverize
    if S.Pulverize:IsReady() then
      if Cast(S.Pulverize, nil, nil, not IsInMeleeRange) then return "pulverize main 16"; end
    end
    -- rage_of_the_sleeper
    if CDsON() and S.RageoftheSleeper:IsCastable() then
      if Cast(S.RageoftheSleeper) then return "rage_of_the_sleeper main 18"; end
    end
    -- lunar_beam
    if CDsON() and S.LunarBeam:IsReady() then
      if Cast(S.LunarBeam) then return "lunar_beam main 20"; end
    end
    -- bristling_fur
    -- ironfur,if=!buff.ironfur.up
    -- Note: Above 2 lines are handled in Defensives.
    -- moonfire,target_if=refreshable
    if S.Moonfire:IsCastable() then
      if Everyone.CastCycle(S.Moonfire, MeleeEnemies8y, EvaluateCycleMoonfire, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire main 22"; end
    end
    -- maul
    if S.Maul:IsReady() and UseMaul then
      if Cast(S.Maul, nil, nil, not IsInMeleeRange) then return "maul main 24"; end
    end
    -- mangle
    if S.Mangle:IsCastable() then
      if Cast(S.Mangle, nil, nil, not IsInMeleeRange) then return "mangle main 26"; end
    end
    -- thrash_bear
    if S.Thrash:IsCastable() then
      if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash main 28"; end
    end
    -- swipe_bear
    if S.Swipe:IsCastable() then
      if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe main 30"; end
    end
    -- Manually added: Pool if nothing to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function OnInit()
  HR.Print("Guardian Druid rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(104, APL, OnInit)

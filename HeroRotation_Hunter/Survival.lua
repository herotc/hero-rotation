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
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Hunter.Survival
local I = Item.Hunter.Survival

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.ManicGrieftorch:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  CommonsDS = HR.GUISettings.APL.Hunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Hunter.CommonsOGCD,
  Survival = HR.GUISettings.APL.Hunter.Survival
}

--- ===== Rotation Variables =====
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }
local MBRS = S.MongooseBite:IsAvailable() and S.MongooseBite or S.RaptorStrike
local EnemyList, EnemyCount
local BossFightRemains = 11111
local FightRemains = 11111
local MBRSRange = 5

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  MBRS = S.MongooseBite:IsAvailable() and S.MongooseBite or S.RaptorStrike
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function CheckFocusCap(SpellCastTime, GenFocus)
  local GeneratedFocus = GenFocus or 0
  return (Player:Focus() + Player:FocusCastRegen(SpellCastTime) + GeneratedFocus < Player:FocusMax())
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBloodseekerRemains(TargetUnit)
  -- target_if=min:bloodseeker.remains
  return (TargetUnit:DebuffRemains(S.BloodseekerDebuff))
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- Moved to Pet Management section in APL()
  -- snapshot_stats
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 2"; end
  end
  -- Manually added: harpoon
  if S.Harpoon:IsCastable() and (Player:BuffDown(S.AspectoftheEagle) or not Target:IsInRange(30)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon precombat 4"; end
  end
  -- Manually added: mongoose_bite or raptor_strike
  if MBRS:IsReady() and Target:IsInMeleeRange(MBRSRange) then
    if Cast(MBRS) then return "mongoose_bite precombat 6"; end
  end
end

local function CDs()
  -- blood_fury,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 2"; end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  -- Note: Not handling external buffs.
  -- harpoon,if=prev.kill_command
  if S.Harpoon:IsCastable() and (Player:PrevGCD(1, S.KillCommand)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon cds 4"; end
  end
  if (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    -- ancestral_call,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
    end
    -- fireblood,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
    end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
  end
  -- berserking,if=buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault|time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable() or BossFightRemains < 13) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 12"; end
  end
  -- muzzle
  -- Handled via Interrupt in APL()
  -- potion,if=target.time_to_die<25|buff.coordinated_assault.up|!talent.coordinated_assault&cooldown.spearhead.remains|!talent.spearhead&!talent.coordinated_assault
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 25 or Player:BuffUp(S.CoordinatedAssaultBuff) or not S.CoordinatedAssault:IsAvailable() and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 14"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=algethar_puzzle_box,use_off_gcd=1
    if I.AlgetharPuzzleBox:IsEquippedAndReady() then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box cds 16"; end
    end
    -- use_item,name=manic_grieftorch
    if I.ManicGrieftorch:IsEquippedAndReady() then
      if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "manic_grieftorch cds 18"; end
    end
    -- use_item,name=beacon_to_the_beyond
    if I.BeacontotheBeyond:IsEquippedAndReady() then
      if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond cds 20"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    -- use_items,if=cooldown.coordinated_assault.remains|cooldown.spearhead.remains
    if S.CoordinatedAssault:CooldownDown() or S.Spearhead:CooldownDown() then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
  end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and Settings.Survival.AspectOfTheEagle and not Target:IsInRange(5) then
    if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle cds 22"; end
  end
end

local function Cleave()
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead cleave 2"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9|cooldown.coordinated_assault.remains<2*gcd
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9 or S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb cleave 4"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault cleave 6"; end
  end
  -- flanking_strike,if=buff.tip_of_the_spear.stack<2
  if S.FlankingStrike:IsCastable() and (Player:BuffStack(S.TipoftheSpearBuff) < 2) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike cleave 8"; end
  end
  -- explosive_shot,if=buff.tip_of_the_spear.stack>0
  if S.ExplosiveShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot cleave 10"; end
  end
  -- fury_of_the_eagle,if=buff.tip_of_the_spear.stack>0
  if S.FuryoftheEagle:IsCastable() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.FuryoftheEagle, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInMeleeRange(5)) then return "fury_of_the_eagle cleave 12"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command cleave 16"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb cleave 16"; end
  end
  -- mongoose_bite,if=buff.merciless_blows.up
  -- raptor_strike,if=buff.merciless_blows.up
  if MBRS:IsReady() and (Player:BuffUp(S.MercilessBlowsBuff)) then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " cleave 18"; end
  end
  -- butchery
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(5)) then return "butchery cleave 20"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot cleave 22"; end
  end
  -- mongoose_bite
  -- raptor_strike
  if MBRS:IsReady() then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " cleave 24"; end
  end
end

local function ST()
  -- spearhead,if=cooldown.coordinated_assault.remains
  if CDsON() and S.Spearhead:IsCastable() and (S.CoordinatedAssault:CooldownDown()) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead st 2"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0&cooldown.wildfire_bomb.charges_fractional>1.7|cooldown.wildfire_bomb.charges_fractional>1.9|cooldown.coordinated_assault.remains<2*gcd
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff) and S.WildfireBomb:ChargesFractional() > 1.7 or S.WildfireBomb:ChargesFractional() > 1.9 or S.CoordinatedAssault:CooldownRemains() < 2 * Player:GCD()) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb st 4"; end
  end
  -- coordinated_assault,if=!talent.bombardier|talent.bombardier&cooldown.wildfire_bomb.charges_fractional<1
  if CDsON() and S.CoordinatedAssault:IsCastable() and (not S.Bombardier:IsAvailable() or S.Bombardier:IsAvailable() and S.WildfireBomb:ChargesFractional() < 1) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault st 6"; end
  end
  -- fury_of_the_eagle,interrupt=1,if=set_bonus.tier31_2pc
  
  -- flanking_strike,if=buff.tip_of_the_spear.stack<2
  if S.FlankingStrike:IsCastable() and (Player:BuffStack(S.TipoftheSpearBuff) < 2) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike st 10"; end
  end
  -- kill_shot,if=buff.tip_of_the_spear.stack>0|talent.sic_em
  
  -- explosive_shot,if=buff.tip_of_the_spear.stack>0
  if S.ExplosiveShot:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot st 14"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 15)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 16"; end
  end
  -- wildfire_bomb,if=buff.tip_of_the_spear.stack>0
  if S.WildfireBomb:IsReady() and (Player:BuffUp(S.TipoftheSpearBuff)) then
    if Cast(S.WildfireBomb, nil, nil, not Target:IsSpellInRange(S.WildfireBomb)) then return "wildfire_bomb st 18"; end
  end
  -- mongoose_bite
  -- raptor_strike
  if MBRS:IsReady() then
    if Cast(MBRS, nil, nil, not Target:IsInMeleeRange(MBRSRange)) then return MBRS:Name() .. " cleave 24"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Target Count Checking
  local EagleUp = Player:BuffUp(S.AspectoftheEagle)
  MBRSRange = EagleUp and 40 or 5
  if AoEON() then
    if EagleUp and not Target:IsInMeleeRange(8) then
      EnemyList = Player:GetEnemiesInRange(40)
      EnemyCount = Target:GetEnemiesInSplashRangeCount(8)
    else
      EnemyList = Player:GetEnemiesInRange(8)
      EnemyCount = #EnemyList
    end
  else
    EnemyCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemyList, false)
    end
  end

  -- Pet Management; Conditions handled via override
  if not (Player:IsMounted() or Player:IsInVehicle()) then
    if S.SummonPet:IsCastable() then
      if Cast(SummonPetSpells[Settings.Commons.SummonPetSlot]) then return "Summon Pet"; end
    end
    if S.RevivePet:IsCastable() then
      if Cast(S.RevivePet, Settings.CommonsOGCD.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
    end
    if S.MendPet:IsCastable() then
      if Cast(S.MendPet, Settings.CommonsOGCD.GCDasOffGCD.MendPet) then return "Mend Pet"; end
    end
  end

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Exhilaration
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.CommonsOGCD.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
    end
    -- muzzle
    local ShouldReturn = Everyone.Interrupt(S.Muzzle, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- Manually added: If out of range, use Aspect of the Eagle, otherwise Harpoon to get back into range
    if not EagleUp and not Target:IsInMeleeRange(8) then
      if S.AspectoftheEagle:IsCastable() then
        if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle oor"; end
      end
      if S.Harpoon:IsCastable() then
        if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon oor"; end
      end
    end
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>2
    if (EnemyCount > 2) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemyCount < 3) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 2"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 4"; end
    end
    -- PoolFocus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function OnInit ()
  HR.Print("Survival Hunter rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(255, APL, OnInit)

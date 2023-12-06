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
-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  Survival = HR.GUISettings.APL.Hunter.Survival
}

-- Spells
local S = Spell.Hunter.Survival

-- Items
local I = Item.Hunter.Survival
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.Djaruun:ID(),
  I.ManicGrieftorch:ID(),
}

-- Rotation Var
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }
local EnemyCount8ySplash, EnemyList
local BossFightRemains = 11111
local FightRemains = 11111
local MBRSCost = S.MongooseBite:IsAvailable() and S.MongooseBite:Cost() or S.RaptorStrike:Cost()
local MeleeRange = 5

HL:RegisterForEvent(function()
  MBRSCost = S.MongooseBite:IsAvailable() and S.MongooseBite:Cost() or S.RaptorStrike:Cost()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
}

-- Bombs
local Bombs = { S.WildfireBomb, S.ShrapnelBomb, S.PheromoneBomb, S.VolatileBomb }
local BombDebuffs = { S.WildfireBombDebuff, S.ShrapnelBombDebuff, S.PheromoneBombDebuff, S.VolatileBombDebuff }

-- Function to see if we're going to cap focus
local function CheckFocusCap(SpellCastTime, GenFocus)
  local GeneratedFocus = GenFocus or 0
  return (Player:Focus() + Player:FocusCastRegen(SpellCastTime) + GeneratedFocus < Player:FocusMax())
end

-- CastCycle/CastTargetIf functions
local function EvaluateTargetIfFilterSerpentStingRemains(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff))
end

local function EvaluateTargetIfFilterBloodseekerRemains(TargetUnit)
  -- target_if=min:bloodseeker.remains
  return (TargetUnit:DebuffRemains(S.BloodseekerDebuff))
end

local function EvaluateTargetIfFilterLatentStacks(TargetUnit)
  -- target_if=max:debuff.latent_poison.stack
  return (TargetUnit:DebuffStack(S.LatentPoisonDebuff))
end

local function EvaluateTargetIfKillCommandST(TargetUnit)
  -- if=cooldown.wildfire_bomb.full_recharge_time<2*gcd&debuff.shredded_armor.down&set_bonus.tier30_4pc
  -- Note: All but debuff check handled before CastTargetIf.
  return (TargetUnit:DebuffDown(S.ShreddedArmorDebuff))
end

local function EvaluateTargetIfKillCommandST2(TargetUnit)
  -- if=full_recharge_time<gcd&focus+cast_regen<focus.max&(cooldown.flanking_strike.remains|!talent.flanking_strike)
  return (S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 21) and (S.FlankingStrike:CooldownDown() or not S.FlankingStrike:IsAvailable()))
end

local function EvaluateTargetIfKillCommandST3(TargetUnit)
  -- if=talent.spearhead&debuff.shredded_armor.stack<1&cooldown.spearhead.remains<2*gcd
  return (TargetUnit:DebuffDown(S.ShreddedArmorDebuff))
end

local function EvaluateTargetIfRaptorStrikeCleave(TargetUnit)
  -- if=debuff.latent_poison.stack>8
  return (TargetUnit:DebuffStack(S.LatentPoisonDebuff) > 8)
end

local function EvaluateTargetIfSerpentStingCleave(TargetUnit)
  -- if=refreshable&target.time_to_die>12&(!talent.vipers_venom|talent.hydras_bite)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 12 and (not S.VipersVenom:IsAvailable() or S.HydrasBite:IsAvailable()))
end

local function EvaluateTargetIfSerpentStingST(TargetUnit)
  -- if=!dot.serpent_sting.ticking&target.time_to_die>7&!talent.vipers_venom
  return (TargetUnit:DebuffDown(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > 7)
end

local function EvaluateTargetIfSerpentStingST2(TargetUnit)
  -- if=refreshable&!talent.vipers_venom
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff))
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- variable,name=mb_rs_cost,op=setif,value=action.mongoose_bite.cost,value_else=action.raptor_strike.cost,condition=talent.mongoose_bite
  -- Defined with profile variables
  -- summon_pet
  -- Moved to Pet Management section in APL()
  -- snapshot_stats
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 2"; end
  end
  -- steel_trap,precast_time=2
  if S.SteelTrap:IsCastable() and Target:DebuffDown(S.SteelTrapDebuff) then
    if Cast(S.SteelTrap, nil, nil, not Target:IsInRange(40)) then return "steel_trap precombat 4"; end
  end
  -- Manually added: harpoon
  if S.Harpoon:IsCastable() and (Player:BuffDown(S.AspectoftheEagle) or not Target:IsInRange(30)) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon precombat 6"; end
  end
  -- Manually added: mongoose_bite or raptor_strike
  if Target:IsInMeleeRange(MeleeRange) or (Player:BuffUp(S.AspectoftheEagle) and Target:IsInRange(40)) then
    if S.MongooseBite:IsReady() then
      if Cast(S.MongooseBite) then return "mongoose_bite precombat 8"; end
    elseif S.RaptorStrike:IsReady() then
      if Cast(S.RaptorStrike) then return "raptor_strike precombat 10"; end
    end
  end
end

local function CDs()
  -- blood_fury,if=buff.coordinated_assault.up|buff.spearhead.up|!talent.spearhead&!talent.coordinated_assault
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or Player:BuffUp(S.SpearheadBuff) or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 2"; end
  end
  -- harpoon,if=talent.terms_of_engagement.enabled&focus<focus.max
  if S.Harpoon:IsCastable() and (S.TermsofEngagement:IsAvailable() and Player:Focus() < Player:FocusMax()) then
    if Cast(S.Harpoon, Settings.Survival.GCDasOffGCD.Harpoon, nil, not Target:IsSpellInRange(S.Harpoon)) then return "harpoon cds 4"; end
  end
  if (Player:BuffUp(S.CoordinatedAssaultBuff) or Player:BuffUp(S.SpearheadBuff) or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    -- ancestral_call,if=buff.coordinated_assault.up|buff.spearhead.up|!talent.spearhead&!talent.coordinated_assault
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
    end
    -- fireblood,if=buff.coordinated_assault.up|buff.spearhead.up|!talent.spearhead&!talent.coordinated_assault
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
    end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
  end
  -- bag_of_tricks,if=cooldown.kill_command.full_recharge_time>gcd
  if S.BagofTricks:IsCastable() and (S.KillCommand:FullRechargeTime() > Player:GCD()) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cds 12"; end
  end
  -- berserking,if=buff.coordinated_assault.up|buff.spearhead.up|!talent.spearhead&!talent.coordinated_assault|time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.CoordinatedAssaultBuff) or Player:BuffUp(S.SpearheadBuff) or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable() or FightRemains < 13) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 14"; end
  end
  -- muzzle
  -- Handled via Interrupt in APL()
  -- potion,if=target.time_to_die<25|buff.coordinated_assault.up|buff.spearhead.up|!talent.spearhead&!talent.coordinated_assault
  if Settings.Commons.Enabled.Potions and (FightRemains < 25 or Player:BuffUp(S.CoordinatedAssaultBuff) or Player:BuffUp(S.SpearheadBuff) or not S.Spearhead:IsAvailable() and not S.CoordinatedAssault:IsAvailable()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 16"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=algethar_puzzle_box,use_off_gcd=1,if=gcd.remains>gcd.max-0.1
    -- Note: Widened the available window by half a second to account for player reaction.
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and (Player:GCDRemains() > Player:GCD() - 0.6) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cds 18"; end
    end
    -- use_item,name=manic_grieftorch,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&!buff.spearhead.up
    if I.ManicGrieftorch:IsEquippedAndReady() and (Player:GCDRemains() > Player:GCD() - 0.6 and Player:BuffDown(S.SpearheadBuff)) then
      if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "manic_grieftorch cds 20"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    -- use_items,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&!buff.spearhead.up
    if Player:BuffDown(S.SpearheadBuff) then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
  end
  -- aspect_of_the_eagle,if=target.distance>=6
  if S.AspectoftheEagle:IsCastable() and Settings.Survival.AspectOfTheEagle and not Target:IsInRange(MeleeRange) then
    if Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectOfTheEagle) then return "aspect_of_the_eagle cds 22"; end
  end
end

local function Cleave()
  -- kill_shot,if=buff.coordinated_assault_empower.up&talent.birds_of_prey
  if S.KillShot:IsReady() and ((Player:BuffUp(S.CoordinatedAssaultEmpowerBuff) or Settings.Survival.CAKSMacro and Player:BuffUp(S.CoordinatedAssaultBuff) and (S.Bite:IsReady() or S.Claw:IsReady() or S.Smack:IsReady())) and S.BirdsofPrey:IsAvailable()) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot cleave 2"; end
  end
  -- death_chakram,if=cooldown.death_chakram.duration=45
  -- Note: Can't get CD duration from death_chakram.
  if S.DeathChakram:IsCastable() then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.DeathChakram)) then return "death_chakram cleave 4"; end
  end
  -- wildfire_bomb
  for _, Bomb in pairs(Bombs) do
    if Bomb:IsCastable() then
      if Cast(Bomb, nil, nil, not Target:IsSpellInRange(Bomb)) then return "wildfire_bomb cleave 6"; end
    end
  end
  -- stampede
  if S.Stampede:IsCastable() and CDsON() then
    if Cast(S.Stampede, nil, nil, not Target:IsSpellInRange(S.Stampede)) then return "stampede cleave 8"; end
  end
  -- coordinated_assault,if=(cooldown.fury_of_the_eagle.remains|!talent.fury_of_the_eagle)
  if S.CoordinatedAssault:IsCastable() and CDsON() and (S.FuryoftheEagle:CooldownDown() or not S.FuryoftheEagle:IsAvailable()) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault cleave 10"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.Commons2.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot cleave 12"; end
  end
  -- carve,if=cooldown.wildfire_bomb.full_recharge_time>spell_targets%2
  if S.Carve:IsReady() and (S.WildfireBomb:FullRechargeTime() > EnemyCount8ySplash / 2) then
    if Cast(S.Carve, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "carve cleave 14"; end
  end
  -- use_item,name=djaruun_pillar_of_the_elder_flame
  if I.Djaruun:IsEquippedAndReady() then
    if Cast(I.Djaruun, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame cleave 16"; end
  end
  -- fury_of_the_eagle,if=raid_event.adds.exists
  if S.FuryoftheEagle:IsCastable() then
    if Cast(S.FuryoftheEagle, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(MeleeRange)) then return "fury_of_the_eagle cleave 18"; end
  end
  -- butchery,if=raid_event.adds.exists
  if S.Butchery:IsReady() then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(MeleeRange)) then return "butchery cleave 20"; end
  end
  -- butchery,if=(full_recharge_time<gcd|dot.shrapnel_bomb.ticking&(dot.internal_bleeding.stack<2|dot.shrapnel_bomb.remains<gcd|raid_event.adds.remains<10))&!raid_event.adds.exists
  if S.Butchery:IsReady() and (S.Butchery:FullRechargeTime() < Player:GCD() or Target:DebuffUp(S.ShrapnelBombDebuff) and (Target:DebuffStack(S.InternalBleedingDebuff) < 2 or Target:DebuffRemains(S.ShrapnelBombDebuff) < Player:GCD())) then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(MeleeRange)) then return "butchery cleave 22"; end
  end
  -- fury_of_the_eagle,if=!raid_event.adds.exists
  if S.FuryoftheEagle:IsCastable() then
    if Cast(S.FuryoftheEagle, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(MeleeRange)) then return "fury_of_the_eagle cleave 22"; end
  end
  -- carve,if=dot.shrapnel_bomb.ticking
  if S.Carve:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if Cast(S.Carve, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "carve cleave 24"; end
  end
  -- butchery,if=(!next_wi_bomb.shrapnel|!talent.wildfire_infusion)
  if S.Butchery:IsReady() and (not S.ShrapnelBomb:IsCastable() or not S.WildfireInfusion:IsAvailable()) then
    if Cast(S.Butchery, Settings.Survival.GCDasOffGCD.Butchery, nil, not Target:IsInMeleeRange(8)) then return "butchery cleave 26"; end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison.stack,if=debuff.latent_poison.stack>8
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterLatentStacks, EvaluateTargetIfRaptorStrikeCleave, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite cleave 28"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison.stack,if=debuff.latent_poison.stack>8
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterLatentStacks, EvaluateTargetIfRaptorStrikeCleave, not Target:IsInMeleeRange(MeleeRange)) then return "raptor_strike cleave 30"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&full_recharge_time<gcd
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime()) and S.KillCommand:FullRechargeTime() < Player:GCD()) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command cleave 32"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (CheckFocusCap(S.FlankingStrike:ExecuteTime(), 30)) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike cleave 34"; end
  end
  -- carve
  if S.Carve:IsReady() then
    if Cast(S.Carve, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "carve cleave 36"; end
  end
  -- kill_shot,if=!buff.coordinated_assault.up
  if S.KillShot:IsReady() and (Player:BuffDown(S.CoordinatedAssaultBuff)) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot cleave 38"; end
  end
  -- steel_trap,if=focus+cast_regen<focus.max
  if S.SteelTrap:IsCastable() and (CheckFocusCap(S.SteelTrap:ExecuteTime())) then
    if Cast(S.SteelTrap, Settings.Commons2.GCDasOffGCD.SteelTrap, nil, not Target:IsInRange(40)) then return "steel_trap cleave 40"; end
  end
  -- spearhead
  if S.Spearhead:IsCastable() and CDsON() then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead cleave 42"; end
  end
  -- mongoose_bite,target_if=min:dot.serpent_sting.remains,if=buff.spearhead.remains
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.SpearheadBuff)) then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite cleave 44"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>12&(!talent.vipers_venom|talent.hydras_bite)
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingCleave, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting cleave 46"; end
  end
  -- mongoose_bite,target_if=min:dot.serpent_sting.remains
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite cleave 48"; end
  end
  -- raptor_strike,target_if=min:dot.serpent_sting.remains
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, nil, not Target:IsInMeleeRange(MeleeRange)) then return "raptor_strike cleave 50"; end
  end
end

local function ST()
  -- kill_shot,if=buff.coordinated_assault_empower.up
  if S.KillShot:IsReady() and (Player:BuffUp(S.CoordinatedAssaultEmpowerBuff) or Settings.Survival.CAKSMacro and Player:BuffUp(S.CoordinatedAssaultBuff) and (S.Bite:IsReady() or S.Claw:IsReady() or S.Smack:IsReady())) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot st 2"; end
  end
  -- wildfire_bomb,if=talent.spearhead&cooldown.spearhead.remains<2*gcd&full_recharge_time<gcd|talent.bombardier&(cooldown.coordinated_assault.remains<gcd&cooldown.fury_of_the_eagle.remains|buff.coordinated_assault.up&buff.coordinated_assault.remains<2*gcd)|full_recharge_time<gcd|prev.fury_of_the_eagle&set_bonus.tier31_2pc|buff.contained_explosion.remains&(next_wi_bomb.pheromone&dot.pheromone_bomb.refreshable|next_wi_bomb.volatile&dot.volatile_bomb.refreshable|next_wi_bomb.shrapnel&dot.shrapnel_bomb.refreshable)|cooldown.fury_of_the_eagle.remains<gcd&full_recharge_time<gcd&set_bonus.tier31_2pc|(cooldown.fury_of_the_eagle.remains<gcd&talent.ruthless_marauder&set_bonus.tier31_2pc)&!raid_event.adds.exists
  if (S.Spearhead:IsAvailable() and S.Spearhead:CooldownRemains() < 2 * Player:GCD() and S.WildfireBomb:FullRechargeTime() < Player:GCD() or S.Bombardier:IsAvailable() and (S.CoordinatedAssault:CooldownRemains() < Player:GCD() and S.FuryoftheEagle:CooldownDown() or Player:BuffUp(S.CoordinatedAssaultBuff) and Player:BuffRemains(S.CoordinatedAssaultBuff) < 2 * Player:GCD()) or S.WildfireBomb:FullRechargeTime() < Player:GCD() or Player:PrevGCD(1, S.FuryoftheEagle) and Player:HasTier(31, 2) or Player:BuffUp(S.ContainedExplosionBuff) and (S.PheromoneBomb:IsCastable() and Target:DebuffRefreshable(S.PheromoneBombDebuff) or S.VolatileBomb:IsCastable() and Target:DebuffRefreshable(S.VolatileBombDebuff) or S.ShrapnelBomb:IsCastable() and Target:DebuffRefreshable(S.ShrapnelBombDebuff)) or S.FuryoftheEagle:CooldownRemains() < Player:GCD() and S.WildfireBomb:FullRechargeTime() < Player:GCD() and Player:HasTier(31, 2) or (S.FuryoftheEagle:CooldownRemains() < Player:GCD() and S.RuthlessMarauder:IsAvailable() and Player:HasTier(31, 2))) then
    for _, Bomb in pairs(Bombs) do
      if Bomb:IsCastable() then
        if Cast(Bomb, nil, nil, not Target:IsSpellInRange(Bomb)) then return "wildfire_bomb st 4"; end
      end
    end
  end
  -- death_chakram,if=focus+cast_regen<focus.max|talent.spearhead&!cooldown.spearhead.remains&cooldown.fury_of_the_eagle.remains|talent.bombardier&!cooldown.fury_of_the_eagle.remains
  if S.DeathChakram:IsCastable() and (CheckFocusCap(S.DeathChakram:ExecuteTime()) or S.Spearhead:IsAvailable() and S.Spearhead:CooldownUp() and S.FuryoftheEagle:CooldownDown() or S.Bombardier:IsAvailable() and S.FuryoftheEagle:CooldownUp()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.DeathChakram)) then return "death_chakram st 6"; end
  end
  -- mongoose_bite,if=prev.fury_of_the_eagle
  if S.MongooseBite:IsReady() and (Player:PrevGCD(1, S.FuryoftheEagle)) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite st 8"; end
  end
  -- use_item,name=djaruun_pillar_of_the_elder_flame,if=!talent.fury_of_the_eagle|talent.spearhead
  if I.Djaruun:IsEquippedAndReady() and (not S.FuryoftheEagle:IsAvailable() or S.Spearhead:IsAvailable()) then
    if Cast(I.Djaruun, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame st 10"; end
  end
  -- fury_of_the_eagle,interrupt_if=(cooldown.wildfire_bomb.full_recharge_time<gcd&talent.ruthless_marauder|!talent.ruthless_marauder),if=(!raid_event.adds.exists&set_bonus.tier31_2pc|raid_event.adds.exists&raid_event.adds.in>40&set_bonus.tier31_2pc)
  -- Note: Unable to handle raid_event conditions, but both include set_bonus.tier31_2pc.
  if S.FuryoftheEagle:IsCastable() and (Player:HasTier(31, 2)) then
    if Cast(S.FuryoftheEagle, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(MeleeRange)) then return "fury_of_the_eagle st 12"; end
  end
  -- spearhead,if=focus+action.kill_command.cast_regen>focus.max-10&(cooldown.death_chakram.remains|!talent.death_chakram)
  if S.Spearhead:IsCastable() and CDsON() and (Player:Focus() + Player:FocusCastRegen(S.KillCommand:ExecuteTime()) + 21 > Player:FocusMax() - 10 and (S.DeathChakram:CooldownDown() or not S.DeathChakram:IsAvailable())) then
    if Cast(S.Spearhead, nil, nil, not Target:IsSpellInRange(S.Spearhead)) then return "spearhead st 14"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max&(buff.deadly_duo.stack>2|talent.flankers_advantage&buff.deadly_duo.stack>1|buff.spearhead.remains&dot.pheromone_bomb.remains)
  if S.KillCommand:IsCastable() and (S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 21) and (Player:BuffStack(S.DeadlyDuoBuff) > 2 or S.FlankersAdvantage:IsAvailable() and Player:BuffStack(S.DeadlyDuoBuff) > 1 or Player:BuffUp(S.SpearheadBuff) and Target:DebuffRemains(S.PheromoneBombDebuff))) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 16"; end
  end
  -- mongoose_bite,if=active_enemies=1&target.time_to_die<focus%(variable.mb_rs_cost-cast_regen)*gcd|buff.mongoose_fury.up&buff.mongoose_fury.remains<gcd|buff.spearhead.remains
  if S.MongooseBite:IsReady() and (EnemyCount8ySplash == 1 and Target:TimeToDie() < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD() or Player:BuffUp(S.MongooseFuryBuff) and Player:BuffRemains(S.MongooseFuryBuff) < Player:GCD() or Player:BuffUp(S.SpearheadBuff)) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite st 18"; end
  end
  -- kill_shot,if=!buff.coordinated_assault.up&!buff.spearhead.up
  if S.KillShot:IsReady() and (Player:BuffDown(S.CoordinatedAssaultEmpowerBuff) and Player:BuffDown(S.SpearheadBuff)) then
    if Cast(S.KillShot, nil, nil, not Target:IsSpellInRange(S.KillShot)) then return "kill_shot st 20"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max&dot.pheromone_bomb.remains&talent.fury_of_the_eagle&cooldown.fury_of_the_eagle.remains>gcd
  if S.KillCommand:IsCastable() and (S.KillCommand:FullRechargeTime() < Player:GCD() and CheckFocusCap(S.KillCommand:ExecuteTime(), 21) and Target:DebuffUp(S.PheromoneBombDebuff) and S.FuryoftheEagle:IsAvailable() and S.FuryoftheEagle:CooldownRemains() > Player:GCD()) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 22"; end
  end
  -- raptor_strike,if=active_enemies=1&target.time_to_die<focus%(variable.mb_rs_cost-cast_regen)*gcd
  if S.RaptorStrike:IsReady() and (EnemyCount8ySplash == 1 and Target:TimeToDie() < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.RaptorStrike:ExecuteTime())) * Player:GCD()) then
    if Cast(S.RaptorStrike, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "raptor_strike st 24"; end
  end
  -- serpent_sting,target_if=min:remains,if=!dot.serpent_sting.ticking&target.time_to_die>7&!talent.vipers_venom
  if S.SerpentSting:IsReady() and (not S.VipersVenom:IsAvailable()) then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingST, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting st 26"; end
  end
  -- fury_of_the_eagle,if=equipped.djaruun_pillar_of_the_elder_flame&buff.seething_rage.up&buff.seething_rage.remains<3*gcd&(!raid_event.adds.exists|active_enemies>1)|raid_event.adds.exists&raid_event.adds.in>40&buff.seething_rage.up&buff.seething_rage.remains<3*gcd
  if S.FuryoftheEagle:IsCastable() and (I.Djaruun:IsEquipped() and Player:BuffUp(S.SeethingRageBuff) and Player:BuffRemains(S.SeethingRageBuff) < 3 * Player:GCD()) then
    if Cast(S.FuryoftheEagle, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(MeleeRange)) then return "fury_of_the_eagle st 28"; end
  end
  -- use_item,name=djaruun_pillar_of_the_elder_flame,if=talent.coordinated_assault|talent.fury_of_the_eagle&cooldown.fury_of_the_eagle.remains<5
  if I.Djaruun:IsEquippedAndReady() and (S.CoordinatedAssault:IsAvailable() or S.FuryoftheEagle:IsAvailable() and S.FuryoftheEagle:CooldownRemains() < 5) then
    if Cast(I.Djaruun, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame st 30"; end
  end
  -- mongoose_bite,if=talent.alpha_predator&buff.mongoose_fury.up&buff.mongoose_fury.remains<focus%(variable.mb_rs_cost-cast_regen)*gcd|equipped.djaruun_pillar_of_the_elder_flame&buff.seething_rage.remains&active_enemies=1|next_wi_bomb.pheromone&cooldown.wildfire_bomb.remains<focus%(variable.mb_rs_cost-cast_regen)*gcd&set_bonus.tier31_2pc
  if S.MongooseBite:IsReady() and (S.AlphaPredator:IsAvailable() and Player:BuffUp(S.MongooseFuryBuff) and Player:BuffRemains(S.MongooseFuryBuff) < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD() or I.Djaruun:IsEquipped() and Player:BuffUp(S.SeethingRageBuff) and EnemyCount8ySplash == 1 or S.PheromoneBomb:IsCastable() and S.WildfireBomb:CooldownRemains() < Player:Focus() / (MBRSCost - Player:FocusCastRegen(S.MongooseBite:ExecuteTime())) * Player:GCD() and Player:HasTier(31, 2)) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite st 32"; end
  end
  -- flanking_strike,if=focus+cast_regen<focus.max
  if S.FlankingStrike:IsCastable() and (CheckFocusCap(S.FlankingStrike:ExecuteTime(), 30)) then
    if Cast(S.FlankingStrike, nil, nil, not Target:IsSpellInRange(S.FlankingStrike)) then return "flanking_strike st 34"; end
  end
  -- stampede
  if S.Stampede:IsCastable() and CDsON() then
    if Cast(S.Stampede, Settings.Commons2.GCDasOffGCD.Stampede, nil, not Target:IsSpellInRange(S.Stampede)) then return "stampede st 36"; end
  end
  -- coordinated_assault,if=(!talent.coordinated_kill&target.health.pct<20&(!buff.spearhead.remains&cooldown.spearhead.remains|!talent.spearhead)|talent.coordinated_kill&(!buff.spearhead.remains&cooldown.spearhead.remains|!talent.spearhead))&(!raid_event.adds.exists|raid_event.adds.in>90)
  if S.CoordinatedAssault:IsCastable() and CDsON() and (not S.CoordinatedKill:IsAvailable() and Target:HealthPercentage() < 20 and (Player:BuffDown(S.SpearheadBuff) and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable()) or S.CoordinatedKill:IsAvailable() and (Player:BuffDown(S.SpearheadBuff) and S.Spearhead:CooldownDown() or not S.Spearhead:IsAvailable())) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault st 38"; end
  end
  -- wildfire_bomb,if=next_wi_bomb.pheromone&focus<variable.mb_rs_cost&set_bonus.tier31_2pc
  if S.PheromoneBomb:IsCastable() and (Player:Focus() < MBRSCost and Player:HasTier(31, 2)) then
    if Cast(S.PheromoneBomb, nil, nil, not Target:IsSpellInRange(S.PheromoneBomb)) then return "wildfire_bomb (pheromone) st 40"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=full_recharge_time<gcd&focus+cast_regen<focus.max&(cooldown.flanking_strike.remains|!talent.flanking_strike)
  if S.KillCommand:IsCastable() then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, EvaluateTargetIfKillCommandST2, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 42"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&!talent.vipers_venom
  if S.SerpentSting:IsReady() and (not S.VipersVenom:IsAvailable()) then
    if Everyone.CastTargetIf(S.SerpentSting, EnemyList, "min", EvaluateTargetIfFilterSerpentStingRemains, EvaluateTargetIfSerpentStingST2, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting st 44"; end
  end
  -- mongoose_bite,if=dot.shrapnel_bomb.ticking
  if S.MongooseBite:IsReady() and (Target:DebuffUp(S.ShrapnelBombDebuff)) then
    if Cast(S.MongooseBite, nil, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite st 46"; end
  end
  -- wildfire_bomb,if=raid_event.adds.in>cooldown.wildfire_bomb.full_recharge_time-(cooldown.wildfire_bomb.full_recharge_time%3.5)&(!dot.wildfire_bomb.ticking&focus+cast_regen<focus.max|active_enemies>1)
  if Target:DebuffDown(S.WildfireBombDebuff) and CheckFocusCap(S.WildfireBomb:ExecuteTime()) or EnemyCount8ySplash > 1 then
    for _, Bomb in pairs(Bombs) do
      if Bomb:IsCastable() then
        if Cast(Bomb, nil, nil, not Target:IsSpellInRange(Bomb)) then return "wildfire_bomb st 48"; end
      end
    end
  end
  -- mongoose_bite,target_if=max:debuff.latent_poison.stack,if=buff.mongoose_fury.up
  if S.MongooseBite:IsReady() and (Player:BuffUp(S.MongooseFuryBuff)) then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterLatentStacks, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite st 50"; end
  end
  -- steel_trap
  if S.SteelTrap:IsCastable() then
    if Cast(S.SteelTrap, Settings.Commons2.GCDasOffGCD.SteelTrap, nil, not Target:IsInRange(40)) then return "steel_trap st 52"; end
  end
  -- explosive_shot,if=talent.ranger&(!raid_event.adds.exists|raid_event.adds.in>28)
  if S.ExplosiveShot:IsReady() and (S.Ranger:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.Commons2.GCDasOffGCD.ExplosiveShot, nil, not Target:IsSpellInRange(S.ExplosiveShot)) then return "explosive_shot st 54"; end
  end
  -- fury_of_the_eagle,if=(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.in>40)
  if S.FuryoftheEagle:IsCastable() then
    if Cast(S.FuryoftheEagle, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(MeleeRange)) then return "fury_of_the_eagle st 56"; end
  end
  -- mongoose_bite
  if S.MongooseBite:IsReady() then
    if Everyone.CastTargetIf(S.MongooseBite, EnemyList, "max", EvaluateTargetIfFilterLatentStacks, nil, not Target:IsInMeleeRange(MeleeRange)) then return "mongoose_bite st 58"; end
  end
  -- raptor_strike,target_if=max:debuff.latent_poison.stack
  if S.RaptorStrike:IsReady() then
    if Everyone.CastTargetIf(S.RaptorStrike, EnemyList, "max", EvaluateTargetIfFilterLatentStacks, nil, not Target:IsInMeleeRange(MeleeRange)) then return "raptor_strike st 60"; end
  end
  -- kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max
  if S.KillCommand:IsCastable() and (CheckFocusCap(S.KillCommand:ExecuteTime(), 21)) then
    if Everyone.CastTargetIf(S.KillCommand, EnemyList, "min", EvaluateTargetIfFilterBloodseekerRemains, nil, not Target:IsSpellInRange(S.KillCommand)) then return "kill_command st 62"; end
  end
  -- coordinated_assault,if=!talent.coordinated_kill&time_to_die>140
  if S.CoordinatedAssault:IsCastable() and (not S.CoordinatedKill:IsAvailable() and Target:TimeToDie() > 140) then
    if Cast(S.CoordinatedAssault, Settings.Survival.GCDasOffGCD.CoordinatedAssault, nil, not Target:IsSpellInRange(S.CoordinatedAssault)) then return "coordinated_assault st 64"; end
  end
end

local function APL()
  -- Target Count Checking
  local EagleUp = Player:BuffUp(S.AspectoftheEagle)
  MeleeRange = EagleUp and 40 or 5
  if AoEON() then
    if EagleUp and not Target:IsInMeleeRange(8) then
      EnemyCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    else
      EnemyCount8ySplash = #Player:GetEnemiesInRange(8) > 0 and #Player:GetEnemiesInRange(8) or 1
    end
  else
    EnemyCount8ySplash = 1
  end

  if EagleUp then
    EnemyList = Player:GetEnemiesInRange(40)
  else
    EnemyList = Player:GetEnemiesInRange(8)
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
      if Cast(SummonPetSpells[Settings.Commons2.SummonPetSlot]) then return "Summon Pet"; end
    end
    if S.RevivePet:IsCastable() then
      if Cast(S.RevivePet, Settings.Commons2.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
    end
    if S.MendPet:IsCastable() then
      if Cast(S.MendPet, Settings.Commons2.GCDasOffGCD.MendPet) then return "Mend Pet"; end
    end
  end

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Exhilaration
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons2.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.Commons2.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
    end
    -- muzzle
    local ShouldReturn = Everyone.Interrupt(5, S.Muzzle, Settings.Survival.OffGCDasOffGCD.Muzzle, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- invoke_external_buff,name=power_infusion,if=buff.coordinated_assault.up|buff.spearhead.up|!talent.coordinated_assault&!talent.spearhead
    -- Note: Not handling external buffs.
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
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemyCount8ySplash < 3) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>2
    if (EnemyCount8ySplash > 2) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main"; end
    end
    -- PoolFocus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function OnInit ()
  HR.Print("Survival Hunter rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(255, APL, OnInit)

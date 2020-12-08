--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
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

local S = Spell.Druid.Feral;
local I = Item.Druid.Feral;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local MeleeRange = 5;
local EightRange = 8;
local InterruptRange = 13;
local FortyRange = 40;

local EnemiesMelee
local Enemies8y
local EnemiesInterrupt
local EnemiesForty


-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Feral = HR.GUISettings.APL.Druid.Feral
};

-- Variables
local VarUseThrash = Settings.Feral.ThrashST and 1 or 0;
local VarOpenerDone = 0;
local LastRakeAP = 0;

HL:RegisterForEvent(function()
  VarUseThrash = Settings.Feral.ThrashST and 1 or 0
  VarOpenerDone = 0
  LastRakeAP = 0
end, "PLAYER_REGEN_ENABLED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function SwipeBleedMult()
  return (Target:DebuffUp(S.RipDebuff) or Target:DebuffUp(S.RakeDebuff) or Target:DebuffUp(S.ThrashCatDebuff)) and 1.2 or 1;
end

local function RakeBleedTick()
  return LastRakeAP * 0.15561 * (1 + Player:VersatilityDmgPct()/100);
end

S.Rake:RegisterDamageFormula(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Rake Modifier
      0.18225 *
      -- Stealth Modifier
      (Player:StealthUp(true) and 2 or 1) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);

S.Shred:RegisterDamageFormula(
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
      (Player:StealthUp(true) and 1.3 or 1) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);

S.SwipeCat:RegisterDamageFormula(
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

S.BrutalSlash:RegisterDamageFormula(
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
          if (Player:BuffUp(S.IncarnationBuff) or Player:BuffUp(S.BerserkBuff)) then return 25
          else return 50
          end
        end
}

local function ComputeRakeDebuggPMultiplier ()
	return Player:StealthUp(true, true) and 2 or 1;
end


S.Rip:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15})
S.Rake:RegisterPMultiplier(ComputeRakeDebuggPMultiplier) 


local function EvaluateCyclePrimalWrath95(TargetUnit)
  return HR.AoEON() and #Player:GetEnemiesInMeleeRange(MeleeRange) > 1 and TargetUnit:DebuffRemains(S.RipDebuff) < 4
end

local function EvaluateCyclePrimalWrath106(TargetUnit)
  return HR.AoEON() and #Player:GetEnemiesInMeleeRange(MeleeRange) >= 2
end

local function EvaluateCycleRip115(TargetUnit)
  return TargetUnit:DebuffDown(S.RipDebuff) or (TargetUnit:DebuffRemains(S.RipDebuff) <= S.RipDebuff:BaseDuration() * 0.3) and (not S.Sabertooth:IsAvailable()) or (TargetUnit:DebuffRemains(S.RipDebuff) <= S.RipDebuff:BaseDuration() * 0.8 and Player:PMultiplier(S.Rip) > TargetUnit:PMultiplier(S.Rip)) and TargetUnit:TimeToDie() > 8
end

local function EvaluateCycleRake228(TargetUnit)
  return TargetUnit:DebuffDown(S.RakeDebuff) or (not S.Bloodtalons:IsAvailable() and TargetUnit:DebuffRemains(S.RakeDebuff) < S.RakeDebuff:BaseDuration() * 0.3) and TargetUnit:TimeToDie() > 4
end

local function EvaluateCycleRake257(TargetUnit)
  return S.Bloodtalons:IsAvailable() and Player:BuffUp(S.BloodtalonsBuff) and ((TargetUnit:DebuffRemains(S.RakeDebuff) <= 7) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake) * 0.85) and TargetUnit:TimeToDie() > 4
end

local function EvaluateCycleMoonfireCat302(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.MoonfireCatDebuff)
end

local function EvaluateCycleFerociousBite418(TargetUnit)
  return TargetUnit:DebuffUp(S.RipDebuff) and TargetUnit:DebuffRemains(S.RipDebuff) < 3 and TargetUnit:TimeToDie() > 10 and (S.Sabertooth:IsAvailable())
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- variable,name=use_thrash,value=0
    if (true) then
      VarUseThrash = Settings.Feral.ThrashST and 1 or 0
    end
    -- regrowth,if=talent.bloodtalons.enabled
    if S.Regrowth:IsCastable() and (S.Bloodtalons:IsAvailable()) then
      if HR.Cast(S.Regrowth) then return "regrowth 3"; end
    end
    -- use_item,name=azsharas_font_of_power
--    if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
--      if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 10"; end
--    end
    -- cat_form
    if S.CatForm:IsCastable() and Player:BuffDown(S.CatFormBuff) then
      if HR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "cat_form 15"; end
    end
    -- prowl
    if S.Prowl:IsCastable() and Player:BuffDown(S.ProwlBuff) then
      if HR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return "prowl 19"; end
    end
    -- potion,dynamic_prepot=1
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 24"; end
    end
    -- berserk
    if S.Berserk:IsCastable() and Player:BuffDown(S.BerserkBuff) and HR.CDsON() then
      if HR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "berserk 26"; end
    end
  end
end

local function Cooldowns()
  -- berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
  if S.Berserk:IsCastable() and HR.CDsON() and (Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemains() > 5 or Player:BuffUp(S.TigersFuryBuff))) then
    if HR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "berserk 30"; end
  end
  -- tigers_fury,if=energy.deficit>=60
  if S.TigersFury:IsCastable() and (Player:EnergyDeficitPredicted() >= 60) then
    if HR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury 36"; end
  end
  -- berserking
  if S.Berserking:IsCastable() and HR.CDsON() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 38"; end
  end
  -- thorns,if=active_enemies>desired_targets|raid_event.adds.in>45
  if S.Thorns:IsCastable() and HR.AoEON() and (#Enemies8y > 1) then
    if HR.Cast(S.Thorns, nil, Settings.Commons.EssenceDisplayStyle) then return "thorns"; end
  end
  -- the_unbound_force,if=buff.reckless_force.up|buff.tigers_fury.up
  if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff) or Player:BuffUp(S.TigersFuryBuff)) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force"; end
  end
  -- memory_of_lucid_dreams,if=buff.tigers_fury.up&buff.berserk.down
  if S.MemoryofLucidDreams:IsCastable() and (Player:BuffUp(S.TigersFuryBuff) and Player:BuffDown(S.BerserkBuff)) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
  end
  -- blood_of_the_enemy,if=buff.tigers_fury.up
  if S.BloodoftheEnemy:IsCastable() and (Player:BuffUp(S.TigersFuryBuff)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
  end
  -- feral_frenzy,if=combo_points=0
  if S.FeralFrenzy:IsCastable() and (Player:ComboPoints() == 0) then
    if HR.Cast(S.FeralFrenzy, nil, nil, MeleeRange) then return "feral_frenzy 40"; end
  end
  -- purifying_blast,if=active_enemies>desired_targets|raid_event.adds.in>60
  if S.PurifyingBlast:IsCastable() and HR.AoEON() and (#Enemies8y > 1) then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast"; end
  end
  -- guardian_of_azeroth,if=buff.tigers_fury.up
  if S.GuardianofAzeroth:IsCastable() and (Player:BuffUp(S.TigersFuryBuff)) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
  end
  -- concentrated_flame,if=buff.tigers_fury.up
  if S.ConcentratedFlame:IsCastable() and (Player:BuffUp(S.TigersFuryBuff)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame"; end
  end
  -- ripple_in_space,if=buff.tigers_fury.up
  if S.RippleInSpace:IsCastable() and (Player:BuffUp(S.TigersFuryBuff)) then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
  end
  -- worldvein_resonance,if=buff.tigers_fury.up
  if S.WorldveinResonance:IsCastable() and (Player:BuffUp(S.TigersFuryBuff)) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
  end
  -- incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
  if S.Incarnation:IsCastable() and HR.CDsON() and (Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemains() > 15 or Player:BuffUp(S.TigersFuryBuff))) then
    if HR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Incarnation) then return "incarnation 42"; end
  end
  -- potion,if=target.time_to_die<65|(time_to_die<180&(buff.berserk.up|buff.incarnation.up))
  if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Target:TimeToDie() < 65 or (Target:TimeToDie() < 180 and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.IncarnationBuff)))) then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "battle_potion_of_agility 48"; end
  end
  -- shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
  if S.Shadowmeld:IsCastable() and HR.CDsON() and (Player:ComboPoints() < 5 and Player:EnergyPredicted() >= S.Rake:Cost() and Target:PMultiplier(S.Rake) < 2.1 and Player:BuffUp(S.TigersFuryBuff) and (Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and (not S.Incarnation:IsAvailable() or S.Incarnation:CooldownRemains() > 18) and Player:BuffDown(S.IncarnationBuff)) then
    if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld 58"; end
  end
  -- use_items,if=buff.tigers_fury.up|target.time_to_die<20
  if (Player:BuffUp(S.TigersFuryBuff) or Target:TimeToDie() < 20) then
    if Settings.Commons.UseTrinkets then
	  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludeTrinkets)
	  if (TrinketToUse ~= nil) then
		if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
	  end
    end
  end
end

local function Finishers()
  -- pool_resource,for_next=1
  -- savage_roar,if=buff.savage_roar.down
  if S.SavageRoar:IsCastable() and (Player:BuffDown(S.SavageRoarBuff)) then
    if HR.CastPooling(S.SavageRoar) then return "savage_roar 84"; end
  end
  -- pool_resource,for_next=1
  -- primal_wrath,target_if=spell_targets.primal_wrath>1&dot.rip.remains<4
  if S.PrimalWrath:IsCastable() then
    if Everyone.CastCycle(S.PrimalWrath, Enemies8y, EvaluateCyclePrimalWrath95) then return "primal_wrath 99" end
  end
  -- pool_resource,for_next=1
  -- primal_wrath,target_if=spell_targets.primal_wrath>=2
  if S.PrimalWrath:IsCastable() then
    if Everyone.CastCycle(S.PrimalWrath, Enemies8y, EvaluateCyclePrimalWrath106) then return "primal_wrath 108" end
  end
  -- pool_resource,for_next=1
  -- rip,target_if=!ticking|(remains<=duration*0.3)&(!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
  if S.Rip:IsCastable() then
    if Everyone.CastCycle(S.Rip, Enemies8y, EvaluateCycleRip115) then return "rip 155" end
  end
  -- pool_resource,for_next=1
  -- savage_roar,if=buff.savage_roar.remains<12
  if S.SavageRoar:IsCastable() and (Player:BuffRemainsP(S.SavageRoarBuff) < 12) then
    if HR.CastPooling(S.SavageRoar) then return "savage_roar 157"; end
  end
  -- pool_resource,for_next=1
  -- maim,if=buff.iron_jaws.up
  if S.Maim:IsCastable() and (Player:BuffUp(S.IronJawsBuff)) then
    if HR.CastPooling(S.Maim, nil, MeleeRange) then return "maim 163"; end
  end
  -- ferocious_bite,max_energy=1
  if S.FerociousBiteMaxEnergy:IsReady() and Player:ComboPoints() > 0 then
    if HR.Cast(S.FerociousBiteMaxEnergy, nil, nil, MeleeRange) then return "ferocious_bite 168"; end
  end
  -- Pool if nothing else to do
  if (true) then
    if HR.Cast(S.PoolResource) then return "pool_resource"; end
  end
end

local function Generators()

  -- regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
  if S.Regrowth:IsCastable() and (S.Bloodtalons:IsAvailable() and Player:BuffUp(S.PredatorySwiftnessBuff) and Player:BuffDown(S.BloodtalonsBuff) and Player:ComboPoints() == 4 and Target:DebuffRemains(S.RakeDebuff) < 4) then
    if HR.Cast(S.Regrowth) then return "regrowth 174"; end
  end
  -- regrowth,if=talent.bloodtalons.enabled&buff.bloodtalons.down&buff.predatory_swiftness.up&talent.lunar_inspiration.enabled&dot.rake.remains<1
  if S.Regrowth:IsCastable() and (S.Bloodtalons:IsAvailable() and Player:BuffDown(S.BloodtalonsBuff) and Player:BuffUp(S.PredatorySwiftnessBuff) and S.LunarInspiration:IsAvailable() and Target:DebuffRemains(S.RakeDebuff) < 1) then
    if HR.Cast(S.Regrowth) then return "regrowth 184"; end
  end
  -- brutal_slash,if=spell_targets.brutal_slash>desired_targets
  if S.BrutalSlash:IsCastable() and HR.AoEON() and (#Enemies8y > 1) then
    if HR.Cast(S.BrutalSlash, nil, nil, EightRange) then return "brutal_slash 196"; end
  end
  -- pool_resource,for_next=1
  -- thrash_cat,if=(refreshable)&(spell_targets.thrash_cat>2)
  if S.ThrashCat:IsCastable() and ((Target:DebuffRefreshable(S.ThrashCatDebuff)) and (#Enemies8y > 2)) then
    if HR.CastPooling(S.ThrashCat, nil, EightRange) then return "thrash_cat 199"; end
  end
  -- pool_resource,for_next=1
  -- thrash_cat,if=(talent.scent_of_blood.enabled&buff.scent_of_blood.down)&spell_targets.thrash_cat>3
  if S.ThrashCat:IsCastable() and ((S.ScentofBlood:IsAvailable() and Player:BuffDown(S.ScentofBloodBuff)) and #Enemies8y > 3) then
    if HR.CastPooling(S.ThrashCat, nil, EightRange) then return "thrash_cat 209"; end
  end
  -- pool_resource,for_next=1
  -- swipe_cat,if=buff.scent_of_blood.up|(action.swipe_cat.damage*spell_targets.swipe_cat>(action.rake.damage+(action.rake_bleed.tick_damage*5)))
  if S.SwipeCat:IsCastable() and (Player:BuffUp(S.ScentofBloodBuff) or ((S.SwipeCat:Damage() * #Enemies8y) > (S.Rake:Damage() + (RakeBleedTick() * 5)))) then
    if HR.CastPooling(S.SwipeCat, nil, EightRange) then return "swipe_cat 217"; end
  end
  -- pool_resource,for_next=1
  -- rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
  if S.Rake:IsCastable() then
    if Everyone.CastCycle(S.Rake, Enemies8y, EvaluateCycleRake228) then return "rake 250" end
  end
  -- pool_resource,for_next=1
  -- rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
  if S.Rake:IsCastable() then
    if Everyone.CastCycle(S.Rake, Enemies8y, EvaluateCycleRake257) then return "rake 275" end
  end
  -- moonfire_cat,if=buff.bloodtalons.up&buff.predatory_swiftness.down&combo_points<5
  if S.MoonfireCat:IsCastable() and (Player:BuffUp(S.BloodtalonsBuff) and Player:BuffDown(S.PredatorySwiftnessBuff) and Player:ComboPoints() < 5) then
    if HR.Cast(S.MoonfireCat, nil, nil, FortyRange) then return "moonfire_cat 276"; end
  end
  -- brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))&(spell_targets.brutal_slash*action.brutal_slash.damage%action.brutal_slash.cost)>(action.shred.damage%action.shred.cost)
  if S.BrutalSlash:IsCastable() and HR.AoEON() and ((Player:BuffUp(S.TigersFuryBuff) and (10000000000 > (1 + S.BrutalSlash:MaxCharges() - S.BrutalSlash:ChargesFractionalP()) * S.BrutalSlash:RechargeP())) and (#Enemies8y * S.BrutalSlash:Damage() % S.BrutalSlash:Cost()) > (S.Shred:Damage() % S.Shred:Cost())) then
    if HR.Cast(S.BrutalSlash, nil, nil, EightRange) then return "brutal_slash 282"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.MoonfireCat:IsCastable() then
    if Everyone.CastCycle(S.MoonfireCat, EnemiesForty, EvaluateCycleMoonfireCat302) then return "moonfire_cat 310" end
  end
  -- pool_resource,for_next=1
  -- thrash_cat,if=refreshable&((variable.use_thrash=2&(!buff.incarnation.up))|spell_targets.thrash_cat>1)
  if S.ThrashCat:IsCastable() and (Target:DebuffRefreshable(S.ThrashCatDebuff) and ((VarUseThrash == 2 and (Player:BuffDown(S.IncarnationBuff))) or #Enemies8y > 1)) then
    if HR.CastPooling(S.ThrashCat, nil, EightRange) then return "thrash_cat 312"; end
  end
  -- thrash_cat,if=refreshable&variable.use_thrash=1&buff.clearcasting.react&(!buff.incarnation.up
  if S.ThrashCat:IsCastable() and (Target:DebuffRefreshable(S.ThrashCatDebuff) and VarUseThrash == 1 and bool(Player:BuffStackP(S.ClearcastingBuff)) and (Player:BuffDown(S.IncarnationBuff))) then
    if HR.Cast(S.ThrashCat, nil, nil, EightRange) then return "thrash_cat 327"; end
  end
  -- pool_resource,for_next=1
  -- swipe_cat,if=spell_targets.swipe_cat>1
  if S.SwipeCat:IsCastable() and (#Enemies8y > 1) then
    if HR.CastPooling(S.SwipeCat, nil, EightRange) then return "swipe_cat 344"; end
  end
  
  -- shred,if=dot.rake.remains>(action.shred.cost+action.rake.cost-energy)%energy.regen|buff.clearcasting.react
  if S.Shred:IsCastable() and 
  (Target:DebuffRemains(S.RakeDebuff) > (S.Shred:Cost() + S.Rake:Cost() - Player:EnergyPredicted()) / Player:EnergyRegen()
  or bool(Player:BuffStack(S.ClearcastingBuff))) then 	
    if HR.Cast(S.Shred, nil, nil, MeleeRange) then return "shred 347"; end
  end
  -- Pool if nothing else to do
  if (true) then
    if HR.Cast(S.PoolResource) then return "pool_resource"; end
  end
end

local function Opener()
  -- tigers_fury
  if S.TigersFury:IsCastable() then
    if HR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury 363"; end
  end
  -- rake,if=!ticking|buff.prowl.up
  if S.Rake:IsCastable() and (Target:DebuffDown(S.RakeDebuff) or Player:BuffUp(S.ProwlBuff)) then
    if HR.Cast(S.Rake, nil, nil, MeleeRange) then return "rake 365"; end
  end
  -- variable,name=opener_done,value=dot.rip.ticking
  if (true) then
	if S.Rip:IsAvailable() then
		VarOpenerDone = num(Target:DebuffUp(S.RipDebuff))
	else
		VarOpenerDone = 1
	end
  end
  -- wait,sec=0.001,if=dot.rip.ticking
  -- moonfire_cat,if=!ticking
  if S.MoonfireCat:IsCastable() and (Target:DebuffDown(S.MoonfireCatDebuff)) then
    if HR.Cast(S.MoonfireCat, nil, nil, FortyRange) then return "moonfire_cat 380"; end
  end
  -- rip,if=!ticking
  -- Manual addition: Use Primal Wrath if >= 2 targets or Rip if only 1 target
  if S.PrimalWrath:IsCastable() and HR.AoEON() and (S.PrimalWrath:IsAvailable() and Target:DebuffDown(S.RipDebuff) and #Enemies8y >= 2) then
    if HR.Cast(S.PrimalWrath, nil, nil, EightRange) then return "primal_wrath opener"; end
  end
  if S.Rip:IsCastable() and (Target:DebuffDown(S.RipDebuff)) then
    if HR.Cast(S.Rip, nil, nil, MeleeRange) then return "rip 388"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if (Player:PrevGCD(1, S.Rake)) then
    LastRakeAP = Player:AttackPowerDamageMod()
  end
  MeleeRange = S.BalanceAffinity:IsAvailable() and 8 or 5
  EightRange = S.BalanceAffinity:IsAvailable() and 11 or 8
  InterruptRange = S.BalanceAffinity:IsAvailable() and 16 or 13
  FortyRange = S.BalanceAffinity:IsAvailable() and 43 or 40
  
  EnemiesMelee = Player:GetEnemiesInMeleeRange(MeleeRange)
  Enemies8y = Player:GetEnemiesInRange(EightRange)
  EnemiesInterrupt = Player:GetEnemiesInRange(InterruptRange)
  EnemiesForty = Target:GetEnemiesInSplashRange(FortyRange)
  
  -- ?? Everyone.AoEToggleEnemiesUpdate()
  
  
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  
  if Everyone.TargetIsValid() then
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(InterruptRange, S.SkullBash, Settings.Commons.OffGCDasOffGCD.SkullBash, false); if ShouldReturn then return ShouldReturn; end
    -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
    -- run_action_list,name=opener,if=variable.opener_done=0
    if (VarOpenerDone == 0) then
		Opener()
      -- return "OPENER: " .. tostring(Opener())
    end
    -- cat_form,if=!buff.cat_form.up
    if S.CatForm:IsCastable() and (Player:BuffDown(S.CatFormBuff)) then
      if HR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "cat_form 402"; end
    end
    -- rake,if=buff.prowl.up|buff.shadowmeld.up
    if S.Rake:IsCastable() and (Player:BuffUp(S.ProwlBuff) or Player:BuffUp(S.ShadowmeldBuff)) then	
      if HR.Cast(S.Rake, nil, nil, MeleeRange) then return "rake 406"; end
    end
	
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- ferocious_bite,target_if=dot.rip.ticking&dot.rip.remains<3&target.time_to_die>10&(talent.sabertooth.enabled)
    if S.FerociousBite:IsReady() and Player:ComboPoints() > 0 then
      if Everyone.CastCycle(S.FerociousBite, Enemies8y, EvaluateCycleFerociousBite418) then return "ferocious_bite 426" end
    end
    -- regrowth,if=combo_points=5&buff.predatory_swiftness.up&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8)
    if S.Regrowth:IsCastable() and (Player:ComboPoints() == 5 and Player:BuffUp(S.PredatorySwiftnessBuff) and S.Bloodtalons:IsAvailable() and Player:BuffDown(S.BloodtalonsBuff) and (Player:BuffDown(S.IncarnationBuff) or Target:DebuffRemains(S.RipDebuff) < 8)) then
      if HR.Cast(S.Regrowth) then return "regrowth 427"; end
    end
    -- run_action_list,name=finishers,if=combo_points>4
    if (Player:ComboPoints() > 4) then	
      return "Finishers: " ..  Finishers();
    end
    -- run_action_list,name=generators
    if (true) then
      return "Generators: " ..  Generators();
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.Cast(S.PoolResource) then return "pool_resource"; end
    end
	
	return "APL"
  end
end

local function Init()
--  HL.RegisterNucleusAbility(285381, 8, 6)               -- Primal Wrath
--  HL.RegisterNucleusAbility(202028, 8, 6)               -- Brutal Slash
--  HL.RegisterNucleusAbility(106830, 8, 6)               -- Thrash (Cat)
--  HL.RegisterNucleusAbility(106785, 8, 6)               -- Swipe (Cat)
end

HR.SetAPL(103, APL, Init)

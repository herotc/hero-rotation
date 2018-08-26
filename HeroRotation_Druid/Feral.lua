--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Feral = {
  Regrowth                              = Spell(8936),
  BloodtalonsBuff                       = Spell(145152),
  Bloodtalons                           = Spell(155672),
  CatFormBuff                           = Spell(768),
  CatForm                               = Spell(768),
  ProwlBuff                             = Spell(5215),
  Prowl                                 = Spell(5215),
  IncarnationBuff                       = Spell(102543),
  JungleStalkerBuff                     = Spell(252071),
  Berserk                               = Spell(106951),
  TigersFury                            = Spell(5217),
  TigersFuryBuff                        = Spell(5217),
  Berserking                            = Spell(26297),
  FeralFrenzy                           = Spell(274837),
  Incarnation                           = Spell(102543),
  BerserkBuff                           = Spell(106951),
  Shadowmeld                            = Spell(58984),
  Rake                                  = Spell(1822),
  RakeDebuff                            = Spell(155722),
  ShadowmeldBuff                        = Spell(58984),
  FerociousBite                         = Spell(22568),
  RipDebuff                             = Spell(1079),
  Sabertooth                            = Spell(202031),
  PredatorySwiftnessBuff                = Spell(69369),
  ApexPredatorBuff                      = Spell(252752),
  MomentofClarity                       = Spell(236068),
  SavageRoar                            = Spell(52610),
  PoolResource                          = Spell(9999000010),
  SavageRoarBuff                        = Spell(52610),
  Rip                                   = Spell(1079),
  FerociousBiteMaxEnergy                = Spell(22568),
  BrutalSlash                           = Spell(202028),
  ThrashCat                             = Spell(106830),
  ThrashCatDebuff                       = Spell(106830),
  MoonfireCat                           = Spell(155625),
  MoonfireCatDebuff                     = Spell(155625),
  ClearcastingBuff                      = Spell(135700),
  SwipeCat                              = Spell(106785),
  Shred                                 = Spell(5221),
  LunarInspiration                      = Spell(155580)
};
local S = Spell.Druid.Feral;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Feral = {
  LuffaWrappings                   = Item(137056),
  OldWar                           = Item(127844),
  AiluroPouncers                   = Item(137024)
};
local I = Item.Druid.Feral;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Feral = HR.GUISettings.APL.Druid.Feral
};

-- Variables
local VarUseThrash = 0;

local EnemyRanges = {8}
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

S.FerociousBiteMaxEnergy.CustomCost = {
  [3] = function ()
          if Player:BuffP(S.ApexPredatorBuff) then return 0
          elseif (Player:BuffP(S.IncarnationBuff) or Player:BuffP(S.BerserkBuff)) then return 25
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
--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Cooldowns, SingleTarget, StFinishers, StGenerators
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- regrowth,if=talent.bloodtalons.enabled
    if S.Regrowth:IsCastableP() and (S.Bloodtalons:IsAvailable()) then
      if HR.Cast(S.Regrowth) then return ""; end
    end
    -- variable,name=use_thrash,value=0
    if (true) then
      VarUseThrash = 0
    end
    -- variable,name=use_thrash,value=1,if=equipped.luffa_wrappings
    if (I.LuffaWrappings:IsEquipped()) then
      VarUseThrash = 1
    end
    -- cat_form
    if S.CatForm:IsCastableP() and Player:BuffDownP(S.CatFormBuff) then
      if HR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return ""; end
    end
    -- prowl
    if S.Prowl:IsCastableP() and Player:BuffDownP(S.ProwlBuff) then
      if HR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return ""; end
    end
    -- snapshot_stats
    -- potion
    if I.OldWar:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.OldWar) then return ""; end
    end
  end
  Cooldowns = function()
    -- dash,if=!buff.cat_form.up
    -- prowl,if=buff.incarnation.remains<0.5&buff.jungle_stalker.up
    if S.Prowl:IsCastableP() and (Player:BuffRemainsP(S.IncarnationBuff) < 0.5 and Player:BuffP(S.JungleStalkerBuff)) then
      if HR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return ""; end
    end
    -- berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
    if S.Berserk:IsCastableP() and HR.CDsON() and (Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 5 or Player:BuffP(S.TigersFuryBuff))) then
      if HR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return ""; end
    end
    -- tigers_fury,if=energy.deficit>=60
    if S.TigersFury:IsCastableP() and (Player:EnergyDeficitPredicted() >= 60) then
      if HR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- feral_frenzy,if=combo_points=0
    if S.FeralFrenzy:IsCastableP() and (Player:ComboPoints() == 0) then
      if HR.Cast(S.FeralFrenzy) then return ""; end
    end
    -- incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
    if S.Incarnation:IsCastableP() and HR.CDsON() and (Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 15 or Player:BuffP(S.TigersFuryBuff))) then
      if HR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Incarnation) then return ""; end
    end
    -- potion,name=prolonged_power,if=target.time_to_die<65|(time_to_die<180&(buff.berserk.up|buff.incarnation.up))
    if I.OldWar:IsReady() and Settings.Commons.UsePotions and (Target:TimeToDie() < 65 or (Target:TimeToDie() < 180 and (Player:BuffP(S.BerserkBuff) or Player:BuffP(S.IncarnationBuff)))) then
      if HR.CastSuggested(I.OldWar) then return ""; end
    end
    -- shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
    if S.Shadowmeld:IsCastableP() and HR.CDsON() and (Player:ComboPoints() < 5 and Player:EnergyPredicted() >= S.Rake:Cost() and Target:PMultiplier(S.Rake) < 2.1 and Player:BuffP(S.TigersFuryBuff) and (Player:BuffP(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and (not S.Incarnation:IsAvailable() or S.Incarnation:CooldownRemainsP() > 18) and not Player:BuffP(S.IncarnationBuff)) then
      if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- use_items
  end
  SingleTarget = function()
    -- cat_form,if=!buff.cat_form.up
    if S.CatForm:IsCastableP() and (not Player:BuffP(S.CatFormBuff)) then
      if HR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return ""; end
    end
    -- rake,if=buff.prowl.up|buff.shadowmeld.up
    if S.Rake:IsCastableP() and (Player:BuffP(S.ProwlBuff) or Player:BuffP(S.ShadowmeldBuff)) then
      if HR.Cast(S.Rake) then return ""; end
    end
    -- auto_attack
    -- call_action_list,name=cooldowns
    if (true) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- ferocious_bite,target_if=dot.rip.ticking&dot.rip.remains<3&target.time_to_die>10&(target.health.pct<25|talent.sabertooth.enabled)
    if S.FerociousBite:IsCastableP() and (Target:DebuffP(S.RipDebuff) and Target:DebuffRemainsP(S.RipDebuff) < 3 and Target:TimeToDie() > 10 and (Target:HealthPercentage() < 25 or S.Sabertooth:IsAvailable())) then
      if HR.Cast(S.FerociousBite) then return ""; end
    end
    -- regrowth,if=combo_points=5&buff.predatory_swiftness.up&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8)
    if S.Regrowth:IsCastableP() and (Player:ComboPoints() == 5 and Player:BuffP(S.PredatorySwiftnessBuff) and S.Bloodtalons:IsAvailable() and Player:BuffDownP(S.BloodtalonsBuff) and (not Player:BuffP(S.IncarnationBuff) or Target:DebuffRemainsP(S.RipDebuff) < 8)) then
      if HR.Cast(S.Regrowth) then return ""; end
    end
    -- regrowth,if=combo_points>3&talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.apex_predator.up&buff.incarnation.down
    if S.Regrowth:IsCastableP() and (Player:ComboPoints() > 3 and S.Bloodtalons:IsAvailable() and Player:BuffP(S.PredatorySwiftnessBuff) and Player:BuffP(S.ApexPredatorBuff) and Player:BuffDownP(S.IncarnationBuff)) then
      if HR.Cast(S.Regrowth) then return ""; end
    end
    -- ferocious_bite,if=buff.apex_predator.up&((combo_points>4&(buff.incarnation.up|talent.moment_of_clarity.enabled))|(talent.bloodtalons.enabled&buff.bloodtalons.up&combo_points>3))
    if S.FerociousBite:IsCastableP() and (Player:BuffP(S.ApexPredatorBuff) and ((Player:ComboPoints() > 4 and (Player:BuffP(S.IncarnationBuff) or S.MomentofClarity:IsAvailable())) or (S.Bloodtalons:IsAvailable() and Player:BuffP(S.BloodtalonsBuff) and Player:ComboPoints() > 3))) then
      if HR.Cast(S.FerociousBite) then return ""; end
    end
    -- run_action_list,name=st_finishers,if=combo_points>4
    if (Player:ComboPoints() > 4) then
      return StFinishers();
    end
    -- run_action_list,name=st_generators
    if (true) then
      return StGenerators();
    end
  end
  StFinishers = function()
    -- pool_resource,for_next=1
    -- savage_roar,if=buff.savage_roar.down
    if S.SavageRoar:IsCastableP() and (Player:BuffDownP(S.SavageRoarBuff)) then
      if S.SavageRoar:IsUsablePPool() then
        if HR.Cast(S.SavageRoar) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- pool_resource,for_next=1
    -- rip,target_if=!ticking|(remains<=duration*0.3)&(target.health.pct>25&!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
    if S.Rip:IsCastableP() and (not Target:DebuffP(S.RipDebuff) or (Target:DebuffRemainsP(S.RipDebuff) <= S.RipDebuff:BaseDuration() * 0.3) and (Target:HealthPercentage() > 25 and not S.Sabertooth:IsAvailable()) or (Target:DebuffRemainsP(S.RipDebuff) <= S.RipDebuff:BaseDuration() * 0.8 and Player:PMultiplier(S.Rip) > Target:PMultiplier(S.Rip)) and Target:TimeToDie() > 8) then
      if S.Rip:IsUsablePPool() then
        if HR.Cast(S.Rip) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- pool_resource,for_next=1
    -- savage_roar,if=buff.savage_roar.remains<12
    if S.SavageRoar:IsCastableP() and (Player:BuffRemainsP(S.SavageRoarBuff) < 12) then
      if S.SavageRoar:IsUsablePPool() then
        if HR.Cast(S.SavageRoar) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- ferocious_bite,max_energy=1
    if S.FerociousBiteMaxEnergy:IsCastableP() and S.FerociousBiteMaxEnergy:IsUsableP() then
      if HR.Cast(S.FerociousBiteMaxEnergy) then return ""; end
    end
  end
  StGenerators = function()
    -- regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
    if S.Regrowth:IsCastableP() and (S.Bloodtalons:IsAvailable() and Player:BuffP(S.PredatorySwiftnessBuff) and Player:BuffDownP(S.BloodtalonsBuff) and Player:ComboPoints() == 4 and Target:DebuffRemainsP(S.RakeDebuff) < 4) then
      if HR.Cast(S.Regrowth) then return ""; end
    end
    -- regrowth,if=equipped.ailuro_pouncers&talent.bloodtalons.enabled&(buff.predatory_swiftness.stack>2|(buff.predatory_swiftness.stack>1&dot.rake.remains<3))&buff.bloodtalons.down
    if S.Regrowth:IsCastableP() and (I.AiluroPouncers:IsEquipped() and S.Bloodtalons:IsAvailable() and (Player:BuffStackP(S.PredatorySwiftnessBuff) > 2 or (Player:BuffStackP(S.PredatorySwiftnessBuff) > 1 and Target:DebuffRemainsP(S.RakeDebuff) < 3)) and Player:BuffDownP(S.BloodtalonsBuff)) then
      if HR.Cast(S.Regrowth) then return ""; end
    end
    -- brutal_slash,if=spell_targets.brutal_slash>desired_targets
    if S.BrutalSlash:IsCastableP() and (Cache.EnemiesCount[8] > 1) then
      if HR.Cast(S.BrutalSlash) then return ""; end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,if=refreshable&(spell_targets.thrash_cat>2)
    if S.ThrashCat:IsCastableP() and (Target:DebuffRefreshableCP(S.ThrashCatDebuff) and (Cache.EnemiesCount[8] > 2)) then
      if S.ThrashCat:IsUsablePPool() then
        if HR.Cast(S.ThrashCat) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,if=spell_targets.thrash_cat>3&equipped.luffa_wrappings&talent.brutal_slash.enabled
    if S.ThrashCat:IsCastableP() and (Cache.EnemiesCount[8] > 3 and I.LuffaWrappings:IsEquipped() and S.BrutalSlash:IsAvailable()) then
      if S.ThrashCat:IsUsablePPool() then
        if HR.Cast(S.ThrashCat) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- pool_resource,for_next=1
    -- rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
    if S.Rake:IsCastableP() and (not Target:DebuffP(S.RakeDebuff) or (not S.Bloodtalons:IsAvailable() and Target:DebuffRemainsP(S.RakeDebuff) < S.RakeDebuff:BaseDuration() * 0.3) and Target:TimeToDie() > 4) then
      if S.Rake:IsUsablePPool() then
        if HR.Cast(S.Rake) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- pool_resource,for_next=1
    -- rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
    if S.Rake:IsCastableP() and (S.Bloodtalons:IsAvailable() and Player:BuffP(S.BloodtalonsBuff) and ((Target:DebuffRemainsP(S.RakeDebuff) <= 7) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake) * 0.85) and Target:TimeToDie() > 4) then
      if S.Rake:IsUsablePPool() then
        if HR.Cast(S.Rake) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))
    if S.BrutalSlash:IsCastableP() and ((Player:BuffP(S.TigersFuryBuff) and (10000000000 > (1 + S.BrutalSlash:MaxCharges() - S.BrutalSlash:ChargesFractional()) * S.BrutalSlash:RechargeP()))) then
      if HR.Cast(S.BrutalSlash) then return ""; end
    end
    -- moonfire_cat,target_if=refreshable
    if S.MoonfireCat:IsCastableP() and (Target:DebuffRefreshableCP(S.MoonfireCatDebuff)) then
      if HR.Cast(S.MoonfireCat) then return ""; end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,if=refreshable&(variable.use_thrash=2|spell_targets.thrash_cat>1)
    if S.ThrashCat:IsCastableP() and (Target:DebuffRefreshableCP(S.ThrashCatDebuff) and (VarUseThrash == 2 or Cache.EnemiesCount[8] > 1)) then
      if S.ThrashCat:IsUsablePPool() then
        if HR.Cast(S.ThrashCat) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- thrash_cat,if=refreshable&variable.use_thrash=1&buff.clearcasting.react
    if S.ThrashCat:IsCastableP() and (Target:DebuffRefreshableCP(S.ThrashCatDebuff) and VarUseThrash == 1 and bool(Player:BuffStackP(S.ClearcastingBuff))) then
      if HR.Cast(S.ThrashCat) then return ""; end
    end
    -- pool_resource,for_next=1
    -- swipe_cat,if=spell_targets.swipe_cat>1
    if S.SwipeCat:IsCastableP() and (Cache.EnemiesCount[8] > 1) then
      if S.SwipeCat:IsUsablePPool() then
        if HR.Cast(S.SwipeCat) then return ""; end
      else
        if HR.Cast(S.PoolResource) then return ""; end
      end
    end
    -- shred,if=dot.rake.remains>(action.shred.cost+action.rake.cost-energy)%energy.regen|buff.clearcasting.react
    if S.Shred:IsCastableP() and (Target:DebuffRemainsP(S.RakeDebuff) > (S.Shred:Cost() + S.Rake:Cost() - Player:EnergyPredicted()) / Player:EnergyRegen() or bool(Player:BuffStackP(S.ClearcastingBuff))) then
      if HR.Cast(S.Shred) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- run_action_list,name=single_target,if=dot.rip.ticking|time>15
  if (Target:DebuffP(S.RipDebuff) or HL.CombatTime() > 15) then
    return SingleTarget();
  end
  -- rake,if=!ticking|buff.prowl.up
  if S.Rake:IsCastableP() and (not Target:DebuffP(S.RakeDebuff) or Player:BuffP(S.ProwlBuff)) then
    if HR.Cast(S.Rake) then return ""; end
  end
  -- dash,if=!buff.cat_form.up
  -- auto_attack
  -- moonfire_cat,if=talent.lunar_inspiration.enabled&!ticking
  if S.MoonfireCat:IsCastableP() and (S.LunarInspiration:IsAvailable() and not Target:DebuffP(S.MoonfireCatDebuff)) then
    if HR.Cast(S.MoonfireCat) then return ""; end
  end
  -- savage_roar,if=!buff.savage_roar.up
  if S.SavageRoar:IsCastableP() and (not Player:BuffP(S.SavageRoarBuff)) then
    if HR.Cast(S.SavageRoar) then return ""; end
  end
  -- berserk
  if S.Berserk:IsCastableP() and HR.CDsON() then
    if HR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return ""; end
  end
  -- incarnation
  if S.Incarnation:IsCastableP() and HR.CDsON() then
    if HR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Incarnation) then return ""; end
  end
  -- tigers_fury
  if S.TigersFury:IsCastableP() then
    if HR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return ""; end
  end
  -- regrowth,if=(talent.sabertooth.enabled|buff.predatory_swiftness.up)&talent.bloodtalons.enabled&buff.bloodtalons.down&combo_points=5
  if S.Regrowth:IsCastableP() and ((S.Sabertooth:IsAvailable() or Player:BuffP(S.PredatorySwiftnessBuff)) and S.Bloodtalons:IsAvailable() and Player:BuffDownP(S.BloodtalonsBuff) and Player:ComboPoints() == 5) then
    if HR.Cast(S.Regrowth) then return ""; end
  end
  -- rip,if=combo_points=5
  if S.Rip:IsCastableP() and (Player:ComboPoints() == 5) then
    if HR.Cast(S.Rip) then return ""; end
  end
  -- thrash_cat,if=!ticking&variable.use_thrash>0
  if S.ThrashCat:IsCastableP() and (not Target:DebuffP(S.ThrashCatDebuff) and VarUseThrash > 0) then
    if HR.Cast(S.ThrashCat) then return ""; end
  end
  -- shred
  if S.Shred:IsCastableP() then
    if HR.Cast(S.Shred) then return ""; end
  end
end

HR.SetAPL(103, APL)

--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
local Action     = HL.Action
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
local CastSuggested = HR.CastSuggested
-- Lua
local mathmax    = math.max


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Hunter = HR.Commons.Hunter

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  BeastMastery = HR.GUISettings.APL.Hunter.BeastMastery
}

-- Spells
local S = Spell.Hunter.BeastMastery;
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }

-- Items
local I = Item.Hunter.BeastMastery;
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Legendaries
local ElderAntlersEquipped = Player:HasLegendaryEquipped(254)
local NessingwarysEquipped = Player:HasLegendaryEquipped(67)
local SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
local QaplaEredunWarOrderEquipped = Player:HasLegendaryEquipped(72)
local PouchofRazorFragmentsEquipped = Player:HasLegendaryEquipped(255)
HL:RegisterForEvent(function()
  ElderAntlersEquipped = Player:HasLegendaryEquipped(254)
  NessingwarysEquipped = Player:HasLegendaryEquipped(67)
  SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
  QaplaEredunWarOrderEquipped = Player:HasLegendaryEquipped(72)
  PouchofRazorFragmentsEquipped = Player:HasLegendaryEquipped(255)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Enemies
local Enemies40y, PetEnemiesMixedy, PetEnemiesMixedyCount

-- Range
local TargetInRange40y, TargetInRange30y
local TargetInRangePet30y

-- Rotation Variables
local GCDMax

-- Interrupts
local Interrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end },
};


--- ======= HELPERS =======
-- BM APL uses a lot of gcd.max specific timing that is slightly tight for real-world suggestions without adjustements
local function UpdateGCDMax()
  -- GCD Max + Reaction Grace Period (150ms)
  GCDMax = Player:GCD() + 0.150
  -- Aspect of the Wild reduces GCD by 0.2s, before Haste modifiers are applied, reduce the benefit since Haste is applied in Player:GCD()
  if Player:BuffUp(S.AspectoftheWildBuff) then
    GCDMax = mathmax(0.75, GCDMax - 0.2 / (1 + Player:HastePct() / 100))
  end
end

local function bool(val)
  return val ~= 0
end

-- target_if=min:dot.barbed_shot.remains
local function EvaluateBarbedShotCycleTargetIfCondition(ThisUnit)
  return ThisUnit:DebuffRemains(S.BarbedShot)
end

-- if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd|buff.wild_spirits.up&charges_fractional>1.4&runeforge.fragments_of_the_elder_antlers
local function EvaluateBarbedShotCycleCondition1(ThisUnit)
  return (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= GCDMax or Player:BuffUp(S.WildSpiritsBuff) and S.BarbedShot:ChargesFractional() > 1.4 and ElderAntlersEquipped)
end

-- if=full_recharge_time<gcd&cooldown.bestial_wrath.remains|cooldown.bestial_wrath.remains<12+gcd&talent.scent_of_blood
local function EvaluateBarbedShotCycleCondition2(ThisUnit)
  return (S.BarbedShot:FullRechargeTime() < GCDMax and bool(S.BestialWrath:CooldownRemains())) or (S.BestialWrath:CooldownRemains() < 12 + GCDMax and S.ScentOfBlood:IsAvailable())
end

-- if=target.time_to_die<9
local function EvaluateBarbedShotCycleCondition3(ThisUnit)
  return ThisUnit:TimeToDie() < 9 and S.Bloodletting:ConduitEnabled()
end

--- ======= ACTION LISTS =======
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- snapshot_stats
  -- fleshcraft
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 2"; end
  end
  -- tar_trap,precast_time=1.5,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped or NessingwarysEquipped) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap precombat 4"; end
  end
  -- bestial_wrath,precast_time=1.5,if=!talent.scent_of_blood&!runeforge.soulforge_embers
  if S.BestialWrath:IsCastable() and CDsON() and ((not S.ScentOfBlood:IsAvailable()) and (not SoulForgeEmbersEquipped)) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath precombat 6"; end
  end
  -- Manually added opener abilities
  -- Barbed Shot
  if S.BarbedShot:IsCastable() and S.BarbedShot:Charges() >= 2 then
    if Cast(S.BarbedShot) then return "barbed_shot precombat 8"; end
  end
  -- Kill Shot
  if S.KillShot:IsCastable() then
    if Cast(S.KillShot) then return "kill_shot precombat 10"; end
  end
  -- Kill Command
  if S.KillCommand:IsCastable() and TargetInRangePet30y then
    if Cast(S.KillCommand) then return "kill_command precombat 12"; end
  end
  if PetEnemiesMixedyCount > 1 then
    -- Multi Shot
    if S.MultiShot:IsCastable()  then
      if Cast(S.MultiShot) then return "multishot precombat 14"; end
    end
  else
    -- Cobra Shot
    if S.CobraShot:IsCastable()  then
      if Cast(S.CobraShot) then return "cobra_shot precombat 16"; end
    end
  end
end

local function CDs()
  -- ancestral_call,if=cooldown.bestial_wrath.remains>30
  if S.AncestralCall:IsCastable() and (S.BestialWrath:CooldownRemains() > 30) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 2"; end
  end
  -- fireblood,if=cooldown.bestial_wrath.remains>30
  if S.Fireblood:IsCastable() and (S.BestialWrath:CooldownRemains() > 30) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 4"; end
  end
  -- berserking,if=(buff.wild_spirits.up|!covenant.night_fae&buff.aspect_of_the_wild.up&buff.bestial_wrath.up)&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct))|target.time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:TimeToDie() > 180 + S.BerserkingBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 13) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 6"; end
  end
  -- blood_fury,if=(buff.wild_spirits.up|!covenant.night_fae&buff.aspect_of_the_wild.up&buff.bestial_wrath.up)&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct))|target.time_to_die<16
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:TimeToDie() > 120 + S.BloodFuryBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 16) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() and (Pet:BuffRemains(S.FrenzyPetBuff) > GCDMax or Pet:BuffDown(S.FrenzyPetBuff)) then
    if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials, nil, 40) then return "lights_judgment cds 10"; end
  end
  -- potion,if=buff.aspect_of_the_wild.up|target.time_to_die<26
  if Settings.Commons.Enabled.Potions and I.PotionOfSpectralAgility:IsReady() and (Player:BuffUp(S.AspectoftheWildBuff) or Target:TimeToDie() < 26) then
    if Cast(I.PotionOfSpectralAgility, Settings.Commons.DisplayStyle.Potions) then return "potion cds 12"; end
  end
end

local function Cleave()
  -- aspect_of_the_wild,if=!raid_event.adds.exists|raid_event.adds.remains>=10|active_enemies>=raid_event.adds.count*2
  if S.AspectoftheWild:IsCastable() and CDsON() then
    if Cast(S.AspectoftheWild, Settings.BeastMastery.OffGCDasOffGCD.AspectOfTheWild) then return "aspect_of_the_wild cleave 2"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd|buff.wild_spirits.up&charges_fractional>1.4&runeforge.fragments_of_the_elder_antlers
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition1) then return "barbed_shot cleave 4"; end
    if EvaluateBarbedShotCycleCondition1(Target) then
      if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "barbed_shot @target cleave 4"; end
    end
  end
  -- multishot,if=gcd-pet.main.buff.beast_cleave.remains>0.25
  -- Check both the player and pet buffs since the pet buff can be impacted by latency
  if S.MultiShot:IsReady() and (GCDMax - Pet:BuffRemains(S.BeastCleavePetBuff) > 0.25 or GCDMax - Player:BuffRemains(S.BeastCleaveBuff) > 0.25) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot cleave 6"; end
  end
  -- kill_shot,if=runeforge.pouch_of_razor_fragments&buff.flayers_mark.up
  if S.KillShot:IsCastable() and (PouchofRazorFragmentsEquipped and Player:BuffUp(S.FlayersMarkBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot cleave 8"; end
  end
  -- flayed_shot,if=runeforge.pouch_of_razor_fragments
  if S.FlayedShot:IsCastable() and (PouchofRazorFragmentsEquipped) then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant) then return "flayed_shot cleave 10"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  -- TODO: Find a way to track traps
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap cleave 12"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  -- TODO: Find a way to track traps
  if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare cleave 14"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant) then return "death_chakram cleave 16"; end
  end
  -- wild_spirits,if=!raid_event.adds.exists|raid_event.adds.remains>=10|active_enemies>=raid_event.adds.count*2
  if S.WildSpirits:IsCastable() and CDsON() then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "wild_spirits cleave 18"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd&cooldown.bestial_wrath.remains|cooldown.bestial_wrath.remains<12+gcd&talent.scent_of_blood
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition2) then return "barbed_shot cleave 20"; end
    if EvaluateBarbedShotCycleCondition2(Target) then
      if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "barbed_shot @target cleave 20"; end
    end
  end
  -- bestial_wrath,if=!raid_event.adds.exists|raid_event.adds.remains>=5|active_enemies>=raid_event.adds.count*2
  if S.BestialWrath:IsCastable() and CDsON() then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath cleave 22"; end
  end
  -- resonating_arrow,if=!raid_event.adds.exists|raid_event.adds.remains>=5|active_enemies>=raid_event.adds.count*2
  if S.ResonatingArrow:IsCastable() and CDsON() then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant) then return "resonating_arrow cleave 24"; end
  end
  -- stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
  if S.Stampede:IsCastable() and CDsON() and (Player:BuffUp(S.AspectoftheWildBuff) or Target:TimeToDie() < 15) then
    if Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetInRange30y) then return "stampede cleave 26"; end
  end
  -- wailing_arrow,if=pet.main.buff.frenzy.remains>execute_time
  if S.WailingArrow:IsReady() and CDsON() and Player:BuffUp(S.BestialWrathBuff) and (Pet:BuffRemains(S.FrenzyPetBuff) > S.WailingArrow:ExecuteTime()) then
    if Cast(S.WailingArrow, Settings.BeastMastery.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow cleave 28"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant) then return "flayed_shot cleave 30"; end
  end
  -- kill_shot
  if S.KillShot:IsCastable() then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot cleave 32"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot cleave 34"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() and CDsON() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "bloodshed cleave 36"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() and CDsON() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "a_murder_of_crows cleave 38"; end
  end
  -- barrage,if=pet.main.buff.frenzy.remains>execute_time
  if S.Barrage:IsReady() and Pet:BuffRemains(S.BeastCleavePetBuff) > S.Barrage:ExecuteTime() and Player:BuffRemains(S.BeastCleaveBuff) > S.Barrage:ExecuteTime() then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage cleave 40"; end
  end
  -- kill_command,if=focus>cost+action.multishot.cost
  if S.KillCommand:IsReady() and (Player:Focus() > S.KillCommand:Cost() + S.MultiShot:Cost()) then
    if Cast(S.KillCommand) then return "kill_command cleave 42"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not TargetInRange40y) then return "bag_of_tricks cleave 44"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if Cast(S.DireBeast, nil, nil, not TargetInRange40y) then return "dire_beast cleave 46"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=target.time_to_die<9|charges_fractional>1.2&conduit.bloodletting
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition3) then return "barbed_shot cleave 48"; end
    if EvaluateBarbedShotCycleCondition3(Target) then
      if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "barbed_shot @target cleave 48"; end
    end
  end
  -- cobra_shot,if=focus.time_to_max<gcd*2
  if S.CobraShot:IsCastable() and Player:FocusTimeToMaxPredicted() < GCDMax * 2 then
    if Cast(S.CobraShot) then return "multishot cleave 50"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
  -- freezing_trap,if=runeforge.nessingwarys_trapping_apparatus
  -- arcane_torrent,if=(focus+focus.regen+30)<focus.max
  if S.ArcaneTorrent:IsCastable() and CDsON() and ((Player:Focus() + Player:FocusRegen() + 30) < Player:FocusMax()) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent cleave 56"; end
  end
end

local function ST()
  -- aspect_of_the_wild,if=!raid_event.adds.exists|!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<20|(raid_event.adds.count=1&covenant.kyrian))|raid_event.adds.up&raid_event.adds.remains>19
  if S.AspectoftheWild:IsCastable() and CDsON() then
    if Cast(S.AspectoftheWild, Settings.BeastMastery.OffGCDasOffGCD.AspectOfTheWild) then return "aspect_of_the_wild st 2"; end
  end
  -- barbed_shot,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd|buff.wild_spirits.up&charges_fractional>1.4&runeforge.fragments_of_the_elder_antlers
  if S.BarbedShot:IsCastable() and (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= GCDMax or Player:BuffUp(S.WildSpiritsBuff) and S.BarbedShot:ChargesFractional() > 1.4 and ElderAntlersEquipped) then
    if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "barbed_shot st 4"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  -- TODO: Find a way to track traps
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped and Target:BuffDown(S.SoulforgeEmbersDebuff) and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap st 6"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  -- TODO: Find a way to track traps
  if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare st 8"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() and CDsON() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "bloodshed st 10"; end
  end
  -- wild_spirits,if=!raid_event.adds.exists|!raid_event.adds.up&raid_event.adds.duration+raid_event.adds.in<20|raid_event.adds.up&raid_event.adds.remains>19
  if S.WildSpirits:IsCastable() and CDsON() then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "wild_spirits st 12"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant) then return "flayed_shot st 14"; end
  end
  -- kill_shot
  if S.KillShot:IsCastable() then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 16"; end
  end
  -- wailing_arrow,if=pet.main.buff.frenzy.remains>execute_time&(cooldown.resonating_arrow.remains<gcd&(!talent.explosive_shot|buff.bloodlust.up)|!covenant.kyrian)|target.time_to_die<5
  -- Note: Explosive Shot doesn't exist for BM, so ignoring that block
  if S.WailingArrow:IsReady() and Player:BuffUp(S.BestialWrathBuff) and CDsON() and (Pet:BuffRemains(S.FrenzyPetBuff) > S.WailingArrow:ExecuteTime() and (S.ResonatingArrow:CooldownRemains() < Player:GCD() or CovenantID ~= 1) or Target:TimeToDie() < 5) then
    if Cast(S.WailingArrow, Settings.BeastMastery.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow st 18"; end
  end
  -- barbed_shot,if=cooldown.bestial_wrath.remains<12*charges_fractional+gcd&talent.scent_of_blood|full_recharge_time<gcd&cooldown.bestial_wrath.remains|target.time_to_die<9
  if S.BarbedShot:IsCastable() and ((S.BestialWrath:CooldownRemains() < 12 * S.BarbedShot:ChargesFractional() + GCDMax and S.ScentOfBlood:IsAvailable()) or (S.BarbedShot:FullRechargeTime() < GCDMax and bool(S.BestialWrath:CooldownRemains())) or Target:TimeToDie() < 9) then
    if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "barbed_shot st 20"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant) then return "death_chakram st 22"; end
  end
  -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
  if S.Stampede:IsCastable() and CDsON() and ((Player:BuffUp(S.AspectoftheWildBuff) and Player:BuffUp(S.BestialWrathBuff)) or Target:TimeToDie() < 15) then
    if Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetInRange30y) then return "stampede st 24"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() and CDsON() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "a_murder_of_crows st 26"; end
  end
  -- resonating_arrow,if=(buff.bestial_wrath.up|target.time_to_die<10)&(!raid_event.adds.exists|!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<20|raid_event.adds.count=1)|raid_event.adds.up&raid_event.adds.remains>19)
  if S.ResonatingArrow:IsCastable() and CDsON() and (Player:BuffUp(S.BestialWrathBuff) or Target:TimeToDie() < 10) then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant) then return "resonating_arrow st 28"; end
  end
  -- bestial_wrath,if=(cooldown.wild_spirits.remains>15|covenant.kyrian&(cooldown.resonating_arrow.remains<5|cooldown.resonating_arrow.remains>20)|target.time_to_die<15|(!covenant.night_fae&!covenant.kyrian))&(!raid_event.adds.exists|!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<20|raid_event.adds.count=1)|raid_event.adds.up&raid_event.adds.remains>19)
  if S.BestialWrath:IsCastable() and CDsON() and (not S.WildSpirits:IsAvailable() or S.WildSpirits:CooldownRemains() > 15 or CovenantID == 1 and (S.ResonatingArrow:CooldownRemains() < 5 or S.ResonatingArrow:CooldownRemains() > 20) or Target:TimeToDie() < 15 or (CovenantID ~= 3 and CovenantID ~= 1)) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath st 30"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot st 32"; end
  end
  -- kill_command
  if S.KillCommand:IsReady() then
    if Cast(S.KillCommand) then return "kill_command st 34"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not TargetInRange40y) then return "bag_of_tricks st 36"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if Cast(S.DireBeast, nil, nil, not TargetInRange40y) then return "dire_beast st 38"; end
  end
  -- cobra_shot,if=(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd)|(buff.bestial_wrath.up|buff.nessingwarys_trapping_apparatus.up)&!runeforge.qapla_eredun_war_order|target.time_to_die<3
  if S.CobraShot:IsReady() and (((Player:Focus() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemains() - 1) > S.KillCommand:Cost())or (S.KillCommand:CooldownRemains() > 1 + GCDMax)) or ((Player:BuffUp(S.BestialWrathBuff) or Player:BuffUp(S.NessingwarysTrappingApparatusBuff)) and not QaplaEredunWarOrderEquipped) or Target:TimeToDie() < 3) then
    if Cast(S.CobraShot, nil, nil, not TargetInRange40y) then return "cobra_shot st 40"; end
  end
  -- barbed_shot,if=buff.wild_spirits.up|charges_fractional>1.2&conduit.bloodletting
  if S.BarbedShot:IsCastable() and (Player:BuffUp(S.WildSpiritsBuff) or S.BarbedShot:ChargesFractional() > 1.2 and S.Bloodletting:ConduitEnabled()) then
    if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "barbed_shot st 42"; end
  end
  -- arcane_pulse,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.ArcanePulse:IsCastable() and CDsON() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse st 44"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
  -- freezing_trap,if=runeforge.nessingwarys_trapping_apparatus
  -- arcane_torrent,if=(focus+focus.regen+15)<focus.max
  if S.ArcaneTorrent:IsCastable() and CDsON() and ((Player:Focus() + Player:FocusRegen() + 15) < Player:FocusMax()) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent st 50"; end
  end
end

local function Trinkets()
  -- variable,name=sync_up,value=buff.resonating_arrow.up|buff.aspect_of_the_wild.up
  -- variable,name=strong_sync_up,value=covenant.kyrian&buff.resonating_arrow.up&buff.aspect_of_the_wild.up|!covenant.kyrian&buff.aspect_of_the_wild.up
  -- variable,name=strong_sync_remains,op=setif,condition=covenant.kyrian,value=cooldown.resonating_arrow.remains<?cooldown.aspect_of_the_wild.remains,value_else=cooldown.aspect_of_the_wild.remains,if=buff.aspect_of_the_wild.down
  -- variable,name=strong_sync_remains,op=setif,condition=covenant.kyrian,value=cooldown.resonating_arrow.remains,value_else=cooldown.aspect_of_the_wild.remains,if=buff.aspect_of_the_wild.up
  -- variable,name=sync_remains,op=setif,condition=covenant.kyrian,value=cooldown.resonating_arrow.remains>?cooldown.aspect_of_the_wild.remains,value_else=cooldown.aspect_of_the_wild.remains
  -- use_items,slots=trinket1,if=(trinket.1.has_use_buff|covenant.kyrian&trinket.1.has_cooldown)&(variable.strong_sync_up&(!covenant.kyrian&!trinket.2.has_use_buff|covenant.kyrian&!trinket.2.has_cooldown|trinket.2.cooldown.remains|trinket.1.has_use_buff&(!trinket.2.has_use_buff|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|trinket.1.has_cooldown&!trinket.2.has_use_buff&trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|!variable.strong_sync_up&(!trinket.2.has_use_buff&(trinket.1.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.1.cooldown.duration%2)|trinket.2.has_use_buff&(trinket.1.has_use_buff&trinket.1.cooldown.duration>=trinket.2.cooldown.duration&(trinket.1.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.1.cooldown.duration%2)|(!trinket.1.has_use_buff|trinket.2.cooldown.duration>=trinket.1.cooldown.duration)&(trinket.2.cooldown.ready&trinket.2.cooldown.duration-5>variable.sync_remains&variable.sync_remains<trinket.2.cooldown.duration%2|!trinket.2.cooldown.ready&(trinket.2.cooldown.remains-5<variable.strong_sync_remains&variable.strong_sync_remains>20&(trinket.1.cooldown.duration-5<variable.sync_remains|trinket.2.cooldown.remains-5<variable.sync_remains&trinket.2.cooldown.duration-10+variable.sync_remains<variable.strong_sync_remains|variable.sync_remains>trinket.1.cooldown.duration%2|variable.sync_up)|trinket.2.cooldown.remains-5>variable.strong_sync_remains&(trinket.1.cooldown.duration-5<variable.strong_sync_remains|!trinket.1.has_use_buff&(variable.sync_remains>trinket.1.cooldown.duration%2|variable.sync_up))))))|target.time_to_die<variable.sync_remains)|!trinket.1.has_use_buff&!covenant.kyrian&(trinket.2.has_use_buff&((!variable.sync_up|trinket.2.cooldown.remains>5)&(variable.sync_remains>20|trinket.2.cooldown.remains-5>variable.sync_remains))|!trinket.2.has_use_buff&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|trinket.2.cooldown.duration>=trinket.1.cooldown.duration))
  -- use_items,slots=trinket2,if=(trinket.2.has_use_buff|covenant.kyrian&trinket.2.has_cooldown)&(variable.strong_sync_up&(!covenant.kyrian&!trinket.1.has_use_buff|covenant.kyrian&!trinket.1.has_cooldown|trinket.1.cooldown.remains|trinket.2.has_use_buff&(!trinket.1.has_use_buff|trinket.2.cooldown.duration>=trinket.1.cooldown.duration)|trinket.2.has_cooldown&!trinket.1.has_use_buff&trinket.2.cooldown.duration>=trinket.1.cooldown.duration)|!variable.strong_sync_up&(!trinket.1.has_use_buff&(trinket.2.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.2.cooldown.duration%2)|trinket.1.has_use_buff&(trinket.2.has_use_buff&trinket.2.cooldown.duration>=trinket.1.cooldown.duration&(trinket.2.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.2.cooldown.duration%2)|(!trinket.2.has_use_buff|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)&(trinket.1.cooldown.ready&trinket.1.cooldown.duration-5>variable.sync_remains&variable.sync_remains<trinket.1.cooldown.duration%2|!trinket.1.cooldown.ready&(trinket.1.cooldown.remains-5<variable.strong_sync_remains&variable.strong_sync_remains>20&(trinket.2.cooldown.duration-5<variable.sync_remains|trinket.1.cooldown.remains-5<variable.sync_remains&trinket.1.cooldown.duration-10+variable.sync_remains<variable.strong_sync_remains|variable.sync_remains>trinket.2.cooldown.duration%2|variable.sync_up)|trinket.1.cooldown.remains-5>variable.strong_sync_remains&(trinket.2.cooldown.duration-5<variable.strong_sync_remains|!trinket.2.has_use_buff&(variable.sync_remains>trinket.2.cooldown.duration%2|variable.sync_up))))))|target.time_to_die<variable.sync_remains)|!trinket.2.has_use_buff&!covenant.kyrian&(trinket.1.has_use_buff&((!variable.sync_up|trinket.1.cooldown.remains>5)&(variable.sync_remains>20|trinket.1.cooldown.remains-5>variable.sync_remains))|!trinket.1.has_use_buff&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|trinket.1.cooldown.duration>=trinket.2.cooldown.duration))
  -- Until we can better handle trinkets (.has_cooldown, for example), here's a basic trinket usage line...
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

--- ======= MAIN =======
local function APL()
  -- HeroLib SplashData Tracking Update (used as fallback if pet abilities are not in action bars)
  if S.Stomp:IsAvailable() then
    HL.SplashEnemies.ChangeFriendTargetsTracking("Mine Only")
  else
    HL.SplashEnemies.ChangeFriendTargetsTracking("All")
  end

  -- Rotation Variables Update
  UpdateGCDMax()

  -- Enemies Update
  local PetCleaveAbility = (S.BloodBolt:IsPetKnown() and Action.FindBySpellID(S.BloodBolt:ID()) and S.BloodBolt)
    or (S.Bite:IsPetKnown() and Action.FindBySpellID(S.Bite:ID()) and S.Bite)
    or (S.Claw:IsPetKnown() and Action.FindBySpellID(S.Claw:ID()) and S.Claw)
    or (S.Smack:IsPetKnown() and Action.FindBySpellID(S.Smack:ID()) and S.Smack)
    or nil
  local PetRangeAbility = (S.Growl:IsPetKnown() and Action.FindBySpellID(S.Growl:ID()) and S.Growl) or nil
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40) -- Barbed Shot Cycle
    PetEnemiesMixedyCount = (PetCleaveAbility and #Player:GetEnemiesInSpellActionRange(PetCleaveAbility)) or Target:GetEnemiesInSplashRangeCount(8) -- Beast Cleave (through Multi-Shot)
  else
    Enemies40y = {}
    PetEnemiesMixedyCount = 0
  end
  TargetInRange40y = Target:IsInRange(40) -- Most abilities
  TargetInRange30y = Target:IsInRange(30) -- Stampede
  TargetInRangePet30y = (PetRangeAbility and Target:IsSpellInActionRange(PetRangeAbility)) or Target:IsInRange(30) -- Kill Command

  -- Defensives
  -- Exhilaration
  if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons2.ExhilarationHP then
    if Cast(S.Exhilaration, Settings.Commons2.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
  end

  -- Pet Management
  if S.SummonPet:IsCastable() then
    if Cast(SummonPetSpells[Settings.Commons2.SummonPetSlot], Settings.Commons2.GCDasOffGCD.SummonPet) then return "Summon Pet"; end
  end
  if Pet:IsDeadOrGhost() and S.RevivePet:IsCastable() then
    if Cast(S.RevivePet, Settings.Commons2.GCDasOffGCD.RevivePet) then return "Revive Pet"; end
  end
  if S.AnimalCompanion:IsAvailable() and Hunter.PetTable.LastPetSpellCount == 1 and Player:AffectingCombat() then
    -- Show a reminder that the Animal Companion has not spawned yet
    CastSuggested(S.AnimalCompanion);
  end
  if not Pet:IsDeadOrGhost() and S.MendPet:IsCastable() and Pet:HealthPercentage() <= Settings.Commons2.MendPetHighHP then
    if Cast(S.MendPet) then return "Mend Pet High Priority"; end
  end

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
     local ShouldReturn = Everyone.Interrupt(40, S.CounterShot, Settings.Commons2.OffGCDasOffGCD.CounterShot, Interrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_shot
    -- counter_shot,line_cd=30,if=runeforge.sephuzs_proclamation|soulbind.niyas_tools_poison|(conduit.reversal_of_fortune&!runeforge.sephuzs_proclamation)
    -- Interrupts handled above.
    -- newfound_resolve,if=soulbind.newfound_resolve&(buff.resonating_arrow.up|cooldown.resonating_arrow.remains>10|target.time_to_die<16)
    -- APL Comment: Delay facing your doubt until you have put Resonating Arrow down, or if the cooldown is too long to delay facing your Doubt. If none of these conditions are able to met within the 10 seconds leeway, the sim faces your Doubt automatically.
    -- call_action_list,name=trinkets,if=covenant.kyrian&cooldown.aspect_of_the_wild.remains&cooldown.resonating_arrow.remains|!covenant.kyrian&cooldown.aspect_of_the_wild.remains
    if (Settings.Commons.Enabled.Trinkets and (CovenantID == 1 and S.AspectoftheWild:CooldownDown() and S.ResonatingArrow:CooldownDown() or CovenantID ~= 1 and S.AspectoftheWild:CooldownDown())) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<2
    if (PetEnemiesMixedyCount < 2) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1
    if (PetEnemiesMixedyCount > 1) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added pet healing
    if not Pet:IsDeadOrGhost() and S.MendPet:IsCastable() and Pet:HealthPercentage() <= Settings.Commons2.MendPetLowHP then
      if Cast(S.MendPet) then return "Mend Pet Low Priority (w/ Target)"; end
    end
    -- Pool Focus if nothing else to do
    if Cast(S.PoolFocus) then return "Pooling Focus"; end
  end

  -- Note: We have to put it again in case we don't have a target but our pet is dying.
  if not Pet:IsDeadOrGhost() and S.MendPet:IsCastable() and Pet:HealthPercentage() <= Settings.Commons2.MendPetLowHP then
    if Cast(S.MendPet) then return "Mend Pet Low Priority (w/o Target)"; end
  end
end

local function OnInit ()
  HR.Print("Beast Mastery can use pet abilities to better determine AoE. Make sure you have Growl and Blood Bolt / Bite / Claw / Smack in your player action bars.")
  --HR.Print("Beast Mastery Hunter rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(253, APL, OnInit)

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
-- HeroRotation
local HR         = HeroRotation

-- Lua
local mathmax    = math.max;
-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Hunter.BeastMastery;
local I = Item.Hunter.BeastMastery;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Hunter = HR.Commons.Hunter
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  BeastMastery = HR.GUISettings.APL.Hunter.BeastMastery
};

-- Stuns
local StunInterrupts = {
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
};

-- Variables
local SoulForgeEmbersEquipped = (I.SoulForgeEmbersChest:IsEquipped() or I.SoulForgeEmbersHead:IsEquipped())

-- Pet Spells
local SummonPetSpells = {
  S.SummonPet,
  S.SummonPet2,
  S.SummonPet3,
  S.SummonPet4,
  S.SummonPet5
}

-- Function
local function UpdateGCDMax()
  -- GCD Max + Latency Grace Period
  -- BM APL uses a lot of gcd.max specific timing that is slightly tight for real-world suggestions
  GCDMax = Player:GCD() + 0.150
  -- Aspect of the Wild reduces GCD by 0.2s, before Haste modifiers are applied, reduce the benefit since Haste is applied in Player:GCD()
  if Player:BuffUp(S.AspectoftheWildBuff) then
    GCDMax = mathmax(0.75, GCDMax - 0.2 / (1 + Player:HastePct() / 100))
  end
end

local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function bool(val)
  return val ~= 0
end

-- target_if=min:dot.barbed_shot.remains
local function EvaluateTargetIfFilterBarbedShot74(TargetUnit)
  return TargetUnit:DebuffRemains(S.BarbedShot)
end

-- if=pet.turtle.buff.frenzy.up&pet.turtle.buff.frenzy.remains<=gcd.max
local function EvaluateTargetIfBarbedShot75(TargetUnit)
  return (Pet:BuffUp(S.FrenzyBuff) and Pet:BuffRemains(S.FrenzyBuff) <= GCDMax)
end

-- if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
local function EvaluateTargetIfBarbedShot85(TargetUnit)
  return (S.BarbedShot:FullRechargeTime() < GCDMax and bool(S.BestialWrath:CooldownRemains()))
end

-- if=pet.turtle.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.turtle.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|charges_fractional>1.4|target.time_to_die<9
local function EvaluateTargetIfBarbedShot123(TargetUnit)
  return (Pet:BuffDown(S.FrenzyBuff) and (S.BarbedShot:ChargesFractional() > 1.8 or Player:BuffUp(S.BestialWrathBuff))
    or S.AspectoftheWild:CooldownRemains() < S.FrenzyBuff:BaseDuration() - GCDMax
    or S.BarbedShot:ChargesFractional() > 1.4 or Target:BossTimeToDie() < 9)
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- tar_trap,if=runeforge.soulforge_embers.equipped
    if S.TarTrap:IsCastable() and SoulForgeEmbersEquipped then
      if HR.Cast(S.TarTrap) then return "tar_trap soulforge_embers equipped"; end
    end
    -- aspect_of_the_wild,precast_time=1.3
    if S.AspectoftheWild:IsCastable() and HR.CDsON() then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 8"; end
    end
    -- wild_spirits
    if S.WildSpirits:IsCastable() and HR.CDsON() then
      if HR.Cast(S.WildSpirits, Settings.Commons.GCDasOffGCD.WildSpirits) then return "wild_spirits fae covenant"; end
    end
    -- bestial_wrath,precast_time=1.5,if=!talent.scent_of_blood.enabled&!runeforge.soulforge_embers.equipped
    if S.BestialWrath:IsCastable() and HR.CDsON() and (not S.ScentOfBlood:IsAvailable() and not SoulForgeEmbersEquipped)  then
      if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 16"; end
    end
  end
end

local function Cds()
  -- ancestral_call,if=cooldown.bestial_wrath.remains>30
  if S.AncestralCall:IsCastable() and (S.BestialWrath:CooldownRemains() > 30) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 24"; end
  end
  -- fireblood,if=cooldown.bestial_wrath.remains>30
  if S.Fireblood:IsCastable() and (S.BestialWrath:CooldownRemains() > 30) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 28"; end
  end
  -- berserking,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:BossTimeToDie() > 180 + S.BerserkingBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:BossTimeToDie() < 13) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 32"; end
  end
  -- blood_fury,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<16
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:BossTimeToDie() > 120 + S.BloodFuryBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:BossTimeToDie() < 16) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 46"; end
  end
  -- lights_judgment,if=pet.turtle.buff.frenzy.up&pet.turtle.buff.frenzy.remains>gcd.max|!pet.turtle.buff.frenzy.up
  if S.LightsJudgment:IsCastable() and (Pet:BuffRemains(S.FrenzyBuff) > GCDMax or Pet:BuffDown(S.FrenzyBuff)) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 60"; end
  end
  -- potion
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionOfSpectralAgility) then return "potion_of_spectral_agility"; end
  end
end

local function Cleave()
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.turtle.buff.frenzy.up&pet.turtle.buff.frenzy.remains<=gcd.max
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40yd, "min", EvaluateTargetIfFilterBarbedShot74, EvaluateTargetIfBarbedShot75) then return "barbed_shot 76"; end
    if EvaluateTargetIfBarbedShot75(Target) then
      if HR.Cast(S.BarbedShot, nil, nil, not TargetIsInRange[40]) then return "barbed_shot 76 fallback"; end
    end
  end

  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
  -- NOTE: Moved TargetIf logic above the Beast Cleave refresh to avoid flickering. This is a 0 DPS loss according to SimC.
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40yd, "min", EvaluateTargetIfFilterBarbedShot74, EvaluateTargetIfBarbedShot85) then return "barbed_shot 86"; end
    if EvaluateTargetIfBarbedShot85(Target) then
      if HR.Cast(S.BarbedShot, nil, nil, not TargetIsInRange[40]) then return "barbed_shot 86 fallback"; end
    end
  end
  -- multishot,if=gcd.max-pet.turtle.buff.beast_cleave.remains>0.25
  -- Check both the player and pet buffs since the pet buff can be impacted by latency
  if S.Multishot:IsReady() and Pet:BuffRemains(S.BeastCleaveBuff) < GCDMax then
    if HR.Cast(S.Multishot, nil, nil, not TargetIsInRange[40]) then return "multishot 82"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped and not S.TarTrap:CooldownRemains() < Player:GCD() and S.Flare:CooldownRemains() < Player:GCD()) then
    if HR.Cast(S.TarTrap, Settings.Commons.GCDasOffGCD.TarTrap) then return "tar_trap"; end
  end
  -- flare,if=tar_trap.up
  if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() then
    if HR.Cast(S.Flare, Settings.Commons.GCDasOffGCD.Flare) then return "flare"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.DeathChakram, nil, Settings.Commons.CovenantDisplayStyle) then return "dark_chakram necrolords covenant"; end
  end
  -- wild_spirits
  if S.WildSpirits:IsCastable() and HR.CDsON() then
    if HR.Cast(S.WildSpirits, nil, Settings.Commons.CovenantDisplayStyle) then return "wild_spirits fae covenant"; end
  end
  -- aspect_of_the_wild
  if S.AspectoftheWild:IsCastable() and HR.CDsON() and Player:BuffDown(S.AspectoftheWildBuff) then
    if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 94"; end
  end
  -- bestial_wrath,if=cooldown.aspect_of_the_wild.remains>20|talent.one_with_the_pack.enabled|target.time_to_die<15
  if S.BestialWrath:IsCastable() and HR.CDsON() and (S.AspectoftheWild:CooldownRemains() > 20 or S.OneWithThePack:IsAvailable() or Target:BossTimeToDie() < 15) then
    if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 102"; end
  end
  -- resonating_arrow
  if S.ResonatingArrow:IsCastable() then
    if HR.Cast(S.ResonatingArrow, nil, Settings.Commons.CovenantDisplayStyle) then return "resonating_arrow kyrian covenant"; end
  end
  -- stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
  if S.Stampede:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) or Target:BossTimeToDie() < 15) then
    if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetIsInRange[30]) then return "stampede 96"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if HR.Cast(S.FlayedShot, nil, Settings.Commons.CovenantDisplayStyle) then return "flayed_shot venthyr covenant"; end
  end
  -- kill_shot
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if HR.Cast(S.KillShot) then return "kill_shot_cleave"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if HR.Cast(S.ChimaeraShot, nil, nil, not TargetIsInRange[40]) then return "chimaera_shot 106"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if HR.Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "bloodshed"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows, nil, not TargetIsInRange[40]) then return "a_murder_of_crows 108"; end
  end
  -- barrage
  if S.Barrage:IsReady() then
    if HR.Cast(S.Barrage, nil, nil, not TargetIsInRange[40]) then return "barrage 110"; end
  end
  -- kill_command,if=focus>cost+action.multishot.cost
  if S.KillCommand:IsReady() and (Player:Focus() > S.KillCommand:Cost() + S.Multishot:Cost()) then
    if HR.Cast(S.KillCommand) then return "kill_command 112"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "bag_of_tricks"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if HR.Cast(S.DireBeast, nil, nil, not TargetIsInRange[40]) then return "dire_beast 122"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.turtle.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.turtle.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|charges_fractional>1.4|target.time_to_die<9
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40yd, "min", EvaluateTargetIfFilterBarbedShot74, EvaluateTargetIfBarbedShot123) then return "barbed_shot 124"; end
    if EvaluateTargetIfBarbedShot123(Target) then
      if HR.Cast(S.BarbedShot, nil, nil, not TargetIsInRange[40]) then return "barbed_shot 124 fallback"; end
    end
  end
  -- NOTE: Experimental line here for non-RR builds. SimC seems to show this as a gain. Submitted for consideration.
  -- multishot,if=cooldown.kill_command.remains>focus.time_to_max&active_enemies>8
  if S.Multishot:IsCastable() and (S.KillCommand:CooldownRemains() > Player:FocusTimeToMaxPredicted() and EnemiesCount10 > 8) then
    if HR.CastPooling(S.Multishot) then return "multishot focus dump"; end
  end
  -- arcane_shot,if=focus.time_to_max<gcd*2
  if S.ArcaneShot:IsCastable() and (Player:FocusTimeToMaxPredicted() < Player:GCD() * 2) then
    if HR.Cast(S.ArcaneShot) then return "arcane_shot"; end
  end
end

local function St()
  -- barbed_shot,if=pet.turtle.buff.frenzy.up&pet.turtle.buff.frenzy.remains<gcd|cooldown.bestial_wrath.remains&(full_recharge_time<gcd|azerite.primal_instincts.enabled&cooldown.aspect_of_the_wild.remains<gcd)
  -- barbed_shot,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd|full_recharge_time<gcd&cooldown.bestial_wrath.remains|cooldown.bestial_wrath.remains<12+gcd&talent.scent_of_blood.enabled
  if S.BarbedShot:IsCastable() and ((Pet:BuffUp(S.FrenzyBuff) and Pet:BuffRemains(S.FrenzyBuff) < GCDMax)
    or (bool(S.BestialWrath:CooldownRemains()) and S.BarbedShot:FullRechargeTime() < GCDMax)
    or (S.BestialWrath:CooldownRemains() < 12 + Player:GCD() and S.ScentOfBlood:IsAvailable())) then
    if HR.Cast(S.BarbedShot, nil, nil, not TargetIsInRange[40]) then return "barbed_shot 164"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped and not S.TarTrap:CooldownRemains() < Player:GCD() and S.Flare:CooldownRemains() < Player:GCD()) then
    if HR.Cast(S.TarTrap, Settings.Commons.GCDasOffGCD.TarTrap) then return "tar_trap"; end
  end
  -- flare,if=tar_trap.up
  if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() then
    if HR.Cast(S.Flare, Settings.Commons.GCDasOffGCD.Flare) then return "flare"; end
  end
  -- wild_spirits
  if S.WildSpirits:IsCastable() and HR.CDsON() then
    if HR.Cast(S.WildSpirits, nil, Settings.Commons.CovenantDisplayStyle) then return "wild_spirits fae covenant"; end
  end
  -- kill_shot
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if HR.Cast(S.KillShot, nil, nil, not TargetIsInRange[40]) then return "kill_shot"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsCastable() then
    if HR.Cast(S.FlayedShot, nil, Settings.Commons.CovenantDisplayStyle) then return "flayed_shot venthyr covenant"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.DeathChakram, nil, Settings.Commons.CovenantDisplayStyle) then return "dark_chakram necrolords covenant"; end
  end
  -- bloodshed
  if S.Bloodshed:IsCastable() then
    if HR.Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "bloodshed"; end
  end
  -- aspect_of_the_wild
  if S.AspectoftheWild:IsCastable() and HR.CDsON() and Player:BuffDown(S.AspectoftheWildBuff) then
    if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "aspect_of_the_wild 180"; end
  end
  -- stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
  if S.Stampede:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) or Target:TimeToDie() < 15) then
    if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetIsInRange[30]) then return "stampede 182"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows, nil, not TargetIsInRange[40]) then return "a_murder_of_crows 183"; end
  end
  -- bestial_wrath
  if S.BestialWrath:IsCastable() and HR.CDsON() then
    if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "bestial_wrath 190"; end
  end
  -- resonating_arrow
  if S.ResonatingArrow:IsCastable() then
    if HR.Cast(S.ResonatingArrow, nil, Settings.Commons.CovenantDisplayStyle) then return "resonating_arrow kyrian covenant"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if HR.Cast(S.ChimaeraShot, nil, nil, not TargetIsInRange[40]) then return "chimaera_shot 196"; end
  end
  -- kill_command
  if S.KillCommand:IsReady() then
    if HR.Cast(S.KillCommand) then return "kill_command 194"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "bag_of_tricks"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if HR.Cast(S.DireBeast, nil, nil, not TargetIsInRange[40]) then return "dire_beast 198"; end
  end
  -- barbed_shot,if=target.time_to_die<9
  if S.BarbedShot:IsCastable() and Target:TimeToDie() < 9 then
    if HR.Cast(S.BarbedShot, nil, nil, not TargetIsInRange[40]) then return "barbed_shot 200"; end
  end
  -- barrage
  if S.Barrage:IsReady() then
    if HR.Cast(S.Barrage, nil, nil, not TargetIsInRange[40]) then return "barrage 216"; end
  end
  --cobra_shot,if=(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd&cooldown.bestial_wrath.remains_guess>focus.time_to_max)&cooldown.kill_command.remains>1|target.time_to_die<3
  if S.CobraShot:IsReady() and ((Player:FocusPredicted() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemains() - 1) > S.KillCommand:Cost())
    or (S.KillCommand:CooldownRemains() > 1 + GCDMax) and S.BestialWrath:CooldownRemains() > Player:FocusTimeToMaxPredicted() and S.KillCommand:CooldownRemains() > 1)
    or Target:TimeToDie() < 3 then
    -- Special pooling line for HeroRotation -- negiligible effective DPS loss (0.1%), but better for prediction accounting for latency
    -- Avoids cases where Cobra Shot would be suggested but the GCD of Cobra Shot + latency would allow Barbed Shot to fall off
    -- wait,if=!buff.bestial_wrath.up&pet.turtle.buff.frenzy.up&pet.turtle.buff.frenzy.remains<=gcd.max*2&focus.time_to_max>gcd.max*2
    if Player:BuffDown(S.BestialWrathBuff) and Pet:BuffUp(S.FrenzyBuff) and Pet:BuffRemains(S.FrenzyBuff) <= GCDMax * 2 and Player:FocusTimeToMaxPredicted() > GCDMax * 2 then
      if HR.Cast(S.PoolFocus) then return "Barbed Shot Pooling"; end
    end
    if HR.Cast(S.CobraShot, nil, nil, not TargetIsInRange[40]) then return "cobra_shot 218"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount10 = Target:GetEnemiesInSplashRangeCount(10) -- AOE Toogle
  Enemies40yd = Player:GetEnemiesInRange(40)
  UpdateGCDMax()    -- Update the GCDMax variable
  ComputeTargetRange()

  -- Pet Management
  if S.SummonPet:IsCastable() then
    if HR.Cast(SummonPetSpells[Settings.Commons.SummonPetSlot], Settings.BeastMastery.GCDasOffGCD.SummonPet) then return "summon_pet"; end
  end
  if Pet:IsDeadOrGhost() and S.RevivePet:IsCastable() then
    if HR.Cast(S.RevivePet, Settings.BeastMastery.GCDasOffGCD.RevivePet) then return "revive_pet"; end
  end
  if S.AnimalCompanion:IsAvailable() and Hunter.PetTable.LastPetSpellCount == 1 and Player:AffectingCombat() then
    -- Show a reminder that the Animal Companion has not spawned yet
    HR.CastSuggested(S.AnimalCompanion);
  end

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Self heal, if below setting value
    if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if HR.Cast(S.Exhilaration, Settings.Commons.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(40, S.CounterShot, Settings.Commons.OffGCDasOffGCD.CounterShot, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_shot
    -- use_items,if=prev_gcd.1.aspect_of_the_wild|target.time_to_die<20
    -- NOTE: Above line is very non-optimal and feedback has been given to the SimC APL devs, following logic will be used for now:
    --  if=buff.aspect_of_the_wild.remains>10|cooldown.aspect_of_the_wild.remains>60|target.time_to_die<20
    if Player:BuffRemains(S.AspectoftheWildBuff) > 10 or S.AspectoftheWild:CooldownRemains() > 60 or Target:BossTimeToDie() < 20 then
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- call_action_list,name=cds
    if (HR.CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<2
    if (EnemiesCount10 < 2) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1
    if (EnemiesCount10 > 1) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    if HR.Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

local function Init ()
  HR.Print("BM APL is WIP")
end

HR.SetAPL(253, APL, Init)

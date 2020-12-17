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
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast = HR.Cast
local CastSuggested = HR.CastSuggested
-- Lua
local mathmax    = math.max;


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
local TrinketsOnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Legendaries
local SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
local QaplaEredunWarOrderEquipped = Player:HasLegendaryEquipped(72)
HL:RegisterForEvent(function()
  SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
  QaplaEredunWarOrderEquipped = Player:HasLegendaryEquipped(72)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Enemies
local Enemies40y, PetEnemiesMixedy, PetEnemiesMixedyCount

-- Range
local TargetInRange40y, TargetInRange30y
local TargetInRangePet30y

-- Rotation Variables
local ShouldReturn -- Used to get the return string
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

-- if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd
local function EvaluateBarbedShotCycleCondition1(ThisUnit)
  return (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= GCDMax)
end

-- if=full_recharge_time<gcd&cooldown.bestial_wrath.remains|cooldown.bestial_wrath.remains<12+gcd&talent.scent_of_blood
local function EvaluateBarbedShotCycleCondition2(ThisUnit)
  return (S.BarbedShot:FullRechargeTime() < GCDMax and bool(S.BestialWrath:CooldownRemains())) or (S.BestialWrath:CooldownRemains() < 12 + GCDMax and S.ScentOfBlood:IsAvailable())
end

-- if=target.time_to_die<9
local function EvaluateBarbedShotCycleCondition3(ThisUnit)
  return ThisUnit:TimeToDie() < 9
end

--- ======= ACTION LISTS =======
local function PreCombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet
  -- snapshot_stats
  if Everyone.TargetIsValid() and TargetInRange40y then
    if CDsON() then
      if S.BestialWrath:IsCastable() then
        if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "Bestial Wrath (PreCombat)"; end
      end
    else
      -- Barbed Shot
      if S.BarbedShot:IsCastable() and S.BarbedShot:Charges() >= 2 then
        if Cast(S.BarbedShot) then return "Barbed Shot (PreCombat)"; end
      end
      -- Kill Shot
      if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
        if Cast(S.KillShot) then return "Kill Shot (PreCombat)"; end
      end
      -- Kill Command
      -- if S.KillCommand:IsCastable() and TargetInRangePet30y then
      --   if Cast(S.KillCommand) then return "Kill Shot (PreCombat)"; end
      -- end
      if PetEnemiesMixedyCount > 1 then
        -- Multi Shot
        if S.MultiShot:IsCastable()  then
          if Cast(S.MultiShot) then return "Multi-Shot (PreCombat)"; end
        end
      else
        -- Cobra Shot
        if S.CobraShot:IsCastable()  then
          if Cast(S.CobraShot) then return "Cobra Shot (PreCombat)"; end
        end
      end
    end
  end
end

local function CDs()
  -- ancestral_call,if=cooldown.bestial_wrath.remains>30
  if S.AncestralCall:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Ancestral Call"; end
  end
  -- fireblood,if=cooldown.bestial_wrath.remains>30
  if S.Fireblood:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Fireblood"; end
  end
  -- berserking,if=(buff.wild_spirits.up|!covenant.night_fae&buff.aspect_of_the_wild.up&buff.bestial_wrath.up)&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct))|target.time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:TimeToDie() > 180 + S.BerserkingBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 13) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Berserking"; end
  end
  -- blood_fury,if=(buff.wild_spirits.up|!covenant.night_fae&buff.aspect_of_the_wild.up&buff.bestial_wrath.up)&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct))|target.time_to_die<16
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:TimeToDie() > 120 + S.BloodFuryBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 16) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Blood Fury"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() and (Pet:BuffRemains(S.FrenzyPetBuff) > GCDMax or Pet:BuffDown(S.FrenzyPetBuff)) then
    if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials, nil, 40) then return "Light's Judgment"; end
  end
  -- potion,if=buff.aspect_of_the_wild.up|target.time_to_die<26
  if Settings.Commons.Enabled.Potions and I.PotionOfSpectralAgility:IsReady() then
    if Cast(I.PotionOfSpectralAgility, Settings.Commons.DisplayStyle.Potions) then return "Potion of Spectral Agility"; end
  end
end

local function Cleave()
  -- aspect_of_the_wild
  if CDsON() and S.AspectoftheWild:IsCastable() then
    if Cast(S.AspectoftheWild, Settings.BeastMastery.OffGCDasOffGCD.AspectoftheWild) then return "Aspect of the Wild (Cleave)"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition1) then return "Barbed Shot (Cleave - 1)"; end
    if EvaluateBarbedShotCycleCondition1(Target) then
      if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (Cleave - 1@Target)"; end
    end
  end
  -- multishot,if=gcd-pet.main.buff.beast_cleave.remains>0.25
  -- Check both the player and pet buffs since the pet buff can be impacted by latency
  if S.MultiShot:IsReady() and (GCDMax - Pet:BuffRemains(S.BeastCleavePetBuff) > 0.25 or GCDMax - Player:BuffRemains(S.BeastCleaveBuff) > 0.25) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "Multi-Shot (Cleave - 1)"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  -- TODO: Find a way to track traps
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped and Target:BuffDown(S.SoulforgeEmbersDebuff) and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap st 4"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  -- TODO: Find a way to track traps
  if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare st 5"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if CDsON() and S.DeathChakram:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- wild_spirits
  if CDsON() and S.WildSpirits:IsCastable() then
    Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd&cooldown.bestial_wrath.remains|cooldown.bestial_wrath.remains<12+gcd&talent.scent_of_blood
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition2) then return "Barbed Shot (Cleave - 2)"; end
    if EvaluateBarbedShotCycleCondition2(Target) then
      if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (Cleave - 2@Target)"; end
    end
  end
  -- bestial_wrath
  if CDsON() and S.BestialWrath:IsCastable() then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "Bestial Wrath (Cleave)"; end
  end
  -- resonating_arrow
  if CDsON() and S.ResonatingArrow:IsCastable() then
    Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
  if CDsON() and S.Stampede:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) or Target:TimeToDie() < 15) then
    if Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetInRange30y) then return "Stampede (Cleave)"; end
  end
  -- flayed_shot
  if CDsON() and S.FlayedShot:IsCastable() then
    Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- kill_shot
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "Kill Shot (Cleave)"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "Chimaera Shot (Cleave)"; end
  end
  -- bloodshed
  if CDsON() and S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "Bloodshed (ST)"; end
  end
  -- a_murder_of_crows
  if CDsON() and S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "A Murder of Crows (Cleave)"; end
  end
  -- barrage,if=pet.main.buff.frenzy.remains>execute_time
  if S.Barrage:IsReady() and Pet:BuffRemains(S.BeastCleavePetBuff) > S.Barrage:ExecuteTime() and Player:BuffRemains(S.BeastCleaveBuff) > S.Barrage:ExecuteTime() then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "Barrage (Cleave)"; end
  end
  -- kill_command,if=focus>cost+action.multishot.cost
  if S.KillCommand:IsReady() and (Player:Focus() > S.KillCommand:Cost() + S.MultiShot:Cost()) then
    if Cast(S.KillCommand) then return "Kill Command (Cleave)"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not TargetInRange40y) then return "Bag of Tricks (ST)"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if Cast(S.DireBeast, nil, nil, not TargetInRange40y) then return "Dire Beast (Cleave)"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=target.time_to_die<9
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition3) then return "Barbed Shot (Cleave - 3)"; end
    if EvaluateBarbedShotCycleCondition3(Target) then
      if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (Cleave - 3@Target)"; end
    end
  end
  -- cobra_shot,if=focus.time_to_max<gcd*2
  if S.CobraShot:IsCastable() and Player:FocusTimeToMaxPredicted() < GCDMax * 2 then
    if Cast(S.CobraShot) then return "Multi-Shot (Cleave)"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
  -- freezing_trap,if=runeforge.nessingwarys_trapping_apparatus
end

local function ST()
  -- aspect_of_the_wild
  if CDsON() and S.AspectoftheWild:IsCastable() then
    if Cast(S.AspectoftheWild, Settings.BeastMastery.OffGCDasOffGCD.AspectoftheWild) then return "Aspect of the Wild (ST)"; end
  end
  -- barbed_shot,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd
  if S.BarbedShot:IsCastable() and (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) < GCDMax) then
    if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 1)"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  -- TODO: Find a way to track traps
  if S.TarTrap:IsCastable() and (SoulForgeEmbersEquipped and Target:BuffDown(S.SoulforgeEmbersDebuff) and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap st 4"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  -- TODO: Find a way to track traps
  if S.Flare:IsCastable() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare st 5"; end
  end
  -- bloodshed
  if CDsON() and S.Bloodshed:IsCastable() then
    if Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "Bloodshed (ST)"; end
  end
  -- wild_spirits
  if CDsON() and S.WildSpirits:IsCastable() then
    Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- flayed_shot
  if CDsON() and S.FlayedShot:IsCastable() then
    Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- kill_shot,if=buff.flayers_mark.remains<5|target.health.pct<=20
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "Kill Shot (ST)"; end
  end
  -- barbed_shot,if=(cooldown.wild_spirits.remains>full_recharge_time|!covenant.night_fae)
  --   &(cooldown.bestial_wrath.remains<12*charges_fractional+gcd&talent.scent_of_blood
  --     |full_recharge_time<gcd&cooldown.bestial_wrath.remains)
  --   |target.time_to_die<9
  if S.BarbedShot:IsCastable() and (((not S.WildSpirits:IsAvailable() or S.WildSpirits:CooldownRemains() > S.BarbedShot:FullRechargeTime())
    and ((S.BestialWrath:CooldownRemains() < 12 * S.BarbedShot:ChargesFractional() + GCDMax and S.ScentOfBlood:IsAvailable())
      or (S.BarbedShot:FullRechargeTime() < GCDMax and bool(S.BestialWrath:CooldownRemains()))))
    or Target:TimeToDie() < 9) then
    if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 1)"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if CDsON() and S.DeathChakram:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
  if S.Stampede:IsCastable() and ((Player:BuffUp(S.AspectoftheWildBuff) and Player:BuffUp(S.BestialWrathBuff)) or Target:TimeToDie() < 15) then
    if Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetInRange30y) then return "Stampede (ST)"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "A Murder of Crows (ST)"; end
  end
  -- resonating_arrow,if=buff.bestial_wrath.up|target.time_to_die<10
  if CDsON() and S.ResonatingArrow:IsCastable() and (Player:BuffUp(S.BestialWrathBuff) or Target:TimeToDie() < 10) then
    Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant)
  end
  -- bestial_wrath,if=cooldown.wild_spirits.remains>15|!covenant.night_fae|target.time_to_die<15
  if CDsON() and S.BestialWrath:IsCastable() and (not S.WildSpirits:IsAvailable() or S.WildSpirits:CooldownRemains() > 15 or Target:TimeToDie() < 15) then
    if Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "Bestial Wrath (ST)"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "Chimaera Shot (ST)"; end
  end
  -- kill_command
  if S.KillCommand:IsReady() then
    if Cast(S.KillCommand) then return "Kill Command (ST)"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not TargetInRange40y) then return "Bag of Tricks (ST)"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if Cast(S.DireBeast, nil, nil, not TargetInRange40y) then return "Dire Beast (ST)"; end
  end
  -- cobra_shot,if=(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd)
  --   |(buff.bestial_wrath.up|buff.nesingwarys_trapping_apparatus.up)&!runeforge.qapla_eredun_war_order
  --   |target.time_to_die<3
  if S.CobraShot:IsReady() and (((Player:Focus() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemains() - 1) > S.KillCommand:Cost())or (S.KillCommand:CooldownRemains() > 1 + GCDMax))
    or ((Player:BuffUp(S.BestialWrathBuff) or Player:BuffUp(S.NesingwarysTrappingApparatusBuff)) and not QaplaEredunWarOrderEquipped)
    or Target:TimeToDie() < 3) then
    if Cast(S.CobraShot, nil, nil, not TargetInRange40y) then return "Cobra Shot (ST)"; end
  end
  -- barbed_shot,if=buff.wild_spirits.up
  if S.BarbedShot:IsCastable() and Player:BuffUp(S.WildSpiritsBuff) then
    if Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 3)"; end
  end
  -- arcane_pulse,if=buff.bestial_wrath.down|target.time_to_die<5
  -- tar_trap,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
  -- freezing_trap,if=runeforge.nessingwarys_trapping_apparatus
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

  -- Out of Combat
  if not Player:AffectingCombat() then
    ShouldReturn = PreCombat();
    if ShouldReturn then return ShouldReturn; end
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Interrupts
     ShouldReturn = Everyone.Interrupt(40, S.CounterShot, Settings.Commons2.OffGCDasOffGCD.CounterShot, Interrupts);
     if ShouldReturn then return ShouldReturn; end

    -- auto_shot

    -- use_items,if=prev_gcd.1.aspect_of_the_wild|target.time_to_die<20
    -- NOTE: Above line is very non-optimal and feedback has been given to the SimC APL devs, following logic will be used for now:
    --  if=buff.aspect_of_the_wild.remains>10|cooldown.aspect_of_the_wild.remains>60|target.time_to_die<20
    if CDsON() and Settings.Commons.Enabled.Trinkets and (Player:BuffRemains(S.AspectoftheWildBuff) > 10 or S.AspectoftheWild:CooldownRemains() > 60 or Target:TimeToDie() < 20) then
      local TrinketToUse = Player:GetUseableTrinkets(TrinketsOnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end

    -- call_action_list,name=cds
    if CDsON() then
      ShouldReturn = CDs();
      if ShouldReturn then return ShouldReturn; end
    end

    if PetEnemiesMixedyCount > 1 then
      -- call_action_list,name=cleave,if=active_enemies>1
      ShouldReturn = Cleave();
    else
      -- call_action_list,name=st,if=active_enemies<2
      ShouldReturn = ST();
    end
    if ShouldReturn then return ShouldReturn; end

    if not Pet:IsDeadOrGhost() and S.MendPet:IsCastable() and Pet:HealthPercentage() <= Settings.Commons2.MendPetLowHP then
      if Cast(S.MendPet) then return "Mend Pet Low Priority (w/ Target)"; end
    end

    if Cast(S.PoolFocus) then return "Pooling Focus"; end
  end

  -- Note: We have to put it again in case we don't have a target but our pet is dying.
  if not Pet:IsDeadOrGhost() and S.MendPet:IsCastable() and Pet:HealthPercentage() <= Settings.Commons2.MendPetLowHP then
    if Cast(S.MendPet) then return "Mend Pet Low Priority (w/o Target)"; end
  end
end

local function OnInit ()
  HL.Print("BeastMastery can use pet abilities to better determine AoE, makes sure you have Growl and Blood Bolt / Bite / Claw / Smack in your player action bars.")
end

HR.SetAPL(253, APL, OnInit)


--- ======= SIMC =======
-- Last Update: 11/29/2020

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/tar_trap,precast_time=1.5,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
-- actions.precombat+=/bestial_wrath,precast_time=1.5,if=!talent.scent_of_blood&!runeforge.soulforge_embers

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/counter_shot,line_cd=30,if=runeforge.sephuzs_proclamation|soulbind.niyas_tools_poison|(conduit.reversal_of_fortune&!runeforge.sephuzs_proclamation)
-- actions+=/use_items
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=st,if=active_enemies<2
-- actions+=/call_action_list,name=cleave,if=active_enemies>1

-- actions.cds=ancestral_call,if=cooldown.bestial_wrath.remains>30
-- actions.cds+=/fireblood,if=cooldown.bestial_wrath.remains>30
-- actions.cds+=/berserking,if=(buff.wild_spirits.up|!covenant.night_fae&buff.aspect_of_the_wild.up&buff.bestial_wrath.up)&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct))|target.time_to_die<13
-- actions.cds+=/blood_fury,if=(buff.wild_spirits.up|!covenant.night_fae&buff.aspect_of_the_wild.up&buff.bestial_wrath.up)&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct))|target.time_to_die<16
-- actions.cds+=/lights_judgment
-- actions.cds+=/potion,if=buff.aspect_of_the_wild.up|target.time_to_die<26

-- actions.cleave=aspect_of_the_wild
-- actions.cleave+=/barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd
-- actions.cleave+=/multishot,if=gcd-pet.main.buff.beast_cleave.remains>0.25
-- actions.cleave+=/tar_trap,if=runeforge.soulforge_embers&tar_trap.remains<gcd&cooldown.flare.remains<gcd
-- actions.cleave+=/flare,if=tar_trap.up&runeforge.soulforge_embers
-- actions.cleave+=/death_chakram,if=focus+cast_regen<focus.max
-- actions.cleave+=/wild_spirits
-- actions.cleave+=/barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd&cooldown.bestial_wrath.remains|cooldown.bestial_wrath.remains<12+gcd&talent.scent_of_blood
-- actions.cleave+=/bestial_wrath
-- actions.cleave+=/resonating_arrow
-- actions.cleave+=/stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
-- actions.cleave+=/flayed_shot
-- actions.cleave+=/kill_shot
-- actions.cleave+=/chimaera_shot
-- actions.cleave+=/bloodshed
-- actions.cleave+=/a_murder_of_crows
-- actions.cleave+=/barrage,if=pet.main.buff.frenzy.remains>execute_time
-- actions.cleave+=/kill_command,if=focus>cost+action.multishot.cost
-- actions.cleave+=/bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
-- actions.cleave+=/dire_beast
-- actions.cleave+=/barbed_shot,target_if=min:dot.barbed_shot.remains,if=target.time_to_die<9
-- actions.cleave+=/cobra_shot,if=focus.time_to_max<gcd*2
-- actions.cleave+=/tar_trap,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
-- actions.cleave+=/freezing_trap,if=runeforge.nessingwarys_trapping_apparatus

-- actions.st=aspect_of_the_wild
-- actions.st+=/barbed_shot,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd
-- actions.st+=/tar_trap,if=runeforge.soulforge_embers&tar_trap.remains<gcd&cooldown.flare.remains<gcd
-- actions.st+=/flare,if=tar_trap.up&runeforge.soulforge_embers
-- actions.st+=/bloodshed
-- actions.st+=/wild_spirits
-- actions.st+=/flayed_shot
-- actions.st+=/kill_shot,if=buff.flayers_mark.remains<5|target.health.pct<=20
-- actions.st+=/barbed_shot,if=(cooldown.wild_spirits.remains>full_recharge_time|!covenant.night_fae)&(cooldown.bestial_wrath.remains<12*charges_fractional+gcd&talent.scent_of_blood|full_recharge_time<gcd&cooldown.bestial_wrath.remains)|target.time_to_die<9
-- actions.st+=/death_chakram,if=focus+cast_regen<focus.max
-- actions.st+=/stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
-- actions.st+=/a_murder_of_crows
-- actions.st+=/resonating_arrow,if=buff.bestial_wrath.up|target.time_to_die<10
-- actions.st+=/bestial_wrath,if=cooldown.wild_spirits.remains>15|!covenant.night_fae|target.time_to_die<15
-- actions.st+=/chimaera_shot
-- actions.st+=/kill_command
-- actions.st+=/bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
-- actions.st+=/dire_beast
-- actions.st+=/cobra_shot,if=(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd)|(buff.bestial_wrath.up|buff.nesingwarys_trapping_apparatus.up)&!runeforge.qapla_eredun_war_order|target.time_to_die<3
-- actions.st+=/barbed_shot,if=buff.wild_spirits.up
-- actions.st+=/arcane_pulse,if=buff.bestial_wrath.down|target.time_to_die<5
-- actions.st+=/tar_trap,if=runeforge.soulforge_embers|runeforge.nessingwarys_trapping_apparatus
-- actions.st+=/freezing_trap,if=runeforge.nessingwarys_trapping_apparatus

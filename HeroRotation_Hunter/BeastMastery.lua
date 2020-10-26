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
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua
local mathmax    = math.max;
-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Hunter = HR.Commons.Hunter

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
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

-- Enemies
local Enemies40y, Enemies40yCount
local SplashEnemies10yCount, SplashEnemies8yCount

-- Range
local TargetInRange40y, TargetInRange30y
local TargetInRangePet50y, TargetInMeleeRangePet5y

-- Stuns
local StunInterrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end },
};

-- Rotation Variables
local ShouldReturn -- Used to get the return string
local SoulForgeEmbersEquipped = (I.SoulForgeEmbersChest:IsEquipped() or I.SoulForgeEmbersHead:IsEquipped())
local GCDMax


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

-- if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd.max
local function EvaluateBarbedShotCycleCondition1(ThisUnit)
  return (Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) <= GCDMax)
end

-- if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
local function EvaluateBarbedShotCycleCondition2(ThisUnit)
  return (S.BarbedShot:FullRechargeTime() < GCDMax and bool(S.BestialWrath:CooldownRemains()))
end

-- pet.main.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)
-- |cooldown.aspect_of_the_wild.remains<pet.main.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled
-- |charges_fractional>1.4
-- |target.time_to_die<9
local function EvaluateBarbedShotCycleCondition3(ThisUnit)
  return (Pet:BuffDown(S.FrenzyPetBuff) and (S.BarbedShot:ChargesFractional() > 1.8 or Player:BuffUp(S.BestialWrathBuff)))
    or (S.AspectoftheWild:CooldownRemains() < S.FrenzyPetBuff:BaseDuration() - GCDMax and bool(S.PrimalInstincts:AzeriteEnabled()))
    or S.BarbedShot:ChargesFractional() > 1.4
    or ThisUnit:TimeToDie() < 9
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
      if S.PrimalInstincts:AzeriteEnabled() then
        -- bestial_wrath,precast_time=1.5,if=azerite.primal_instincts.enabled&!essence.essence_of_the_focusing_iris.major&(equipped.azsharas_font_of_power|!equipped.cyclotronic_blast)
      if S.BestialWrath:IsCastable() then
        if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "Bestial Wrath (PreCombat)"; end
      end
      else
        -- aspect_of_the_wild,precast_time=1.3,if=!azerite.primal_instincts.enabled&!essence.essence_of_the_focusing_iris.major&(equipped.azsharas_font_of_power|!equipped.cyclotronic_blast)
        if S.AspectoftheWild:IsCastable() then
          if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "Aspect of the Wild (PreCombat)"; end
        end
      end
    else
      -- Barbed Shot
      if S.BarbedShot:IsCastable() and S.BarbedShot:Charges() >= 2 then
        if HR.Cast(S.BarbedShot) then return "Barbed Shot (PreCombat)"; end
      end
      -- Kill Shot
      if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
        if HR.Cast(S.KillShot) then return "Kill Shot (PreCombat)"; end
      end
      -- Kill Command
      if S.KillCommand:IsCastable() and TargetInRangePet50y then
        if HR.Cast(S.KillCommand) then return "Kill Shot (PreCombat)"; end
      end
      if SplashEnemies8yCount > 1 then
        -- Multi Shot
        if S.MultiShot:IsCastable()  then
          if HR.Cast(S.MultiShot) then return "Multi-Shot (PreCombat)"; end
        end
      else
        -- Cobra Shot
        if S.CobraShot:IsCastable()  then
          if HR.Cast(S.CobraShot) then return "Cobra Shot (PreCombat)"; end
        end
      end
    end
  end
end

local function CDs()
  -- ancestral_call,if=cooldown.bestial_wrath.remains>30
  if S.AncestralCall:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 24"; end
  end
  -- fireblood,if=cooldown.bestial_wrath.remains>30
  if S.Fireblood:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 28"; end
  end
  -- berserking,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<13
  if S.Berserking:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:TimeToDie() > 180 + S.BerserkingBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 13) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 32"; end
  end
  -- blood_fury,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<16
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) and (Target:TimeToDie() > 120 + S.BloodFuryBuff:BaseDuration() or (Target:HealthPercentage() < 35 or not S.KillerInstinct:IsAvailable())) or Target:TimeToDie() < 16) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 46"; end
  end
  -- lights_judgment,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains>gcd.max|!pet.main.buff.frenzy.up
  if S.LightsJudgment:IsCastable() and (Pet:BuffRemains(S.FrenzyPetBuff) > GCDMax or Pet:BuffDown(S.FrenzyPetBuff)) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 60"; end
  end
  -- potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up&target.health.pct<35|((consumable.potion_of_unbridled_fury|consumable.unbridled_fury)&target.time_to_die<61|target.time_to_die<26)
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionOfSpectralAgility) then return "potion_of_spectral_agility"; end
  end
  -- worldvein_resonance,if=(prev_gcd.1.aspect_of_the_wild|cooldown.aspect_of_the_wild.remains<gcd|targ
  -- TODO
  -- guardian_of_azeroth,if=cooldown.aspect_of_the_wild.remains<10|target.time_to_die>cooldown+duration
  -- TODO
  -- ripple_in_space
  -- TODO
  -- memory_of_lucid_dreams
  -- TODO
  -- reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30
  -- TODO
end

local function Cleave()
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd.max
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition1) then return "Barbed Shot (Cleave - 1)"; end
    if EvaluateBarbedShotCycleCondition1(Target) then
      if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (Cleave - 1@Target)"; end
    end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
  -- NOTE: Moved TargetIf logic above the Beast Cleave refresh to avoid flickering. This is a 0 DPS loss according to SimC.
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition2) then return "Barbed Shot (Cleave - 2)"; end
    if EvaluateBarbedShotCycleCondition2(Target) then
      if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (Cleave - 2@Target)"; end
    end
  end
  -- multishot,if=gcd.max-pet.main.buff.beast_cleave.remains>0.25
  -- Check both the player and pet buffs since the pet buff can be impacted by latency
  if S.MultiShot:IsReady() and (GCDMax - Pet:BuffRemains(S.BeastCleavePetBuff) > 0.25 or GCDMax - Player:BuffRemains(S.BeastCleaveBuff) > 0.25) then
    if HR.Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "Multi-Shot (Cleave - 1)"; end
  end
  -- aspect_of_the_wild
  if CDsON() and S.AspectoftheWild:IsCastable() and Player:BuffDown(S.AspectoftheWildBuff) then
    if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "Aspect of the Wild (Cleave)"; end
  end
  -- stampede,if=buff.aspect_of_the_wild.up|target.time_to_die<15
  if CDsON() and S.Stampede:IsCastable() and (Player:BuffUp(S.AspectoftheWildBuff) or Target:TimeToDie() < 15) then
    if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetInRange30y) then return "Stampede (Cleave)"; end
  end
  -- bestial_wrath,if=cooldown.aspect_of_the_wild.remains>20|talent.one_with_the_pack.enabled|target.time_to_die<15
  if CDsON() and S.BestialWrath:IsCastable() and (S.AspectoftheWild:CooldownRemains() > 20 or S.OneWithThePack:IsAvailable() or Target:TimeToDie() < 15) then
    if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "Bestial Wrath (Cleave)"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if HR.Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "Chimaera Shot (Cleave)"; end
  end
  -- a_murder_of_crows
  if CDsON() and S.AMurderofCrows:IsReady() then
    if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "A Murder of Crows (Cleave)"; end
  end
  -- barrage
  if S.Barrage:IsReady() then
    if HR.Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "Barrage (Cleave)"; end
  end
  -- kill_command,if=focus>cost+action.multishot.cost
  if S.KillCommand:IsReady() and (Player:Focus() > S.KillCommand:Cost() + S.MultiShot:Cost()) then
    if HR.Cast(S.KillCommand) then return "Kill Command (Cleave)"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if HR.Cast(S.DireBeast, nil, nil, not TargetInRange40y) then return "Dire Beast (Cleave)"; end
  end
  -- barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.main.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|charges_fractional>1.4|target.time_to_die<9
  if S.BarbedShot:IsCastable() then
    if Everyone.CastTargetIf(S.BarbedShot, Enemies40y, "min", EvaluateBarbedShotCycleTargetIfCondition, EvaluateBarbedShotCycleCondition3) then return "Barbed Shot (Cleave - 3)"; end
    if EvaluateBarbedShotCycleCondition3(Target) then
      if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (Cleave - 3@Target)"; end
    end
  end
  -- focused_azerite_beam
  -- TODO
  -- purifying_blast
  -- TODO
  -- concentrated_flame
  -- TODO
  -- blood_of_the_enemy
  -- TODO
  -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
  -- TODO
  -- multishot,if=azerite.rapid_reload.enabled&active_enemies>2
  if S.MultiShot:IsCastable() and S.RapidReload:AzeriteEnabled() and SplashEnemies10yCount > 2 then
    if HR.CastPooling(S.MultiShot) then return "Multi-Shot (Cleave - 2)"; end
  end
  -- cobra_shot,if=cooldown.kill_command.remains>focus.time_to_max&(active_enemies<3|!azerite.rapid_reload.enabled)
  if S.CobraShot:IsCastable() and S.KillCommand:CooldownRemains() > Player:FocusTimeToMaxPredicted() and (SplashEnemies10yCount < 3 or not S.RapidReload:AzeriteEnabled()) then
    if HR.Cast(S.CobraShot) then return "Multi-Shot (Cleave)"; end
  end
end

local function ST()
  -- kill_shot
  if S.KillShot:IsCastable() and Target:HealthPercentage() <= 20 then
    if HR.Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "Kill Shot (ST)"; end
  end
  -- bloodshed
  if CDsON() and S.Bloodshed:IsCastable() then
    if HR.Cast(S.Bloodshed, Settings.BeastMastery.GCDasOffGCD.Bloodshed) then return "Bloodshed (ST)"; end
  end
  -- barbed_shot,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<gcd
  --                |cooldown.bestial_wrath.remains&(full_recharge_time<gcd|azerite.primal_instincts.enabled&cooldown.aspect_of_the_wild.remains<gcd)
  if S.BarbedShot:IsCastable() and ((Pet:BuffUp(S.FrenzyPetBuff) and Pet:BuffRemains(S.FrenzyPetBuff) < GCDMax)
    or (bool(S.BestialWrath:CooldownRemains()) and (S.BarbedShot:FullRechargeTime() < GCDMax or (S.PrimalInstincts:AzeriteEnabled() and S.AspectoftheWild:CooldownRemains() < GCDMax)))) then
    if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 1)"; end
  end
  -- concentrated_flame,if=focus+focus.regen*gcd<focus.max&buff.bestial_wrath.down&(!dot.concentrated_flame_burn.remains&!action.concentrated_flame.in_flight)|full_recharge_time<gcd|target.time_to_die<5
  -- TODO
  -- aspect_of_the_wild,if=buff.aspect_of_the_wild.down&(cooldown.barbed_shot.charges<1|!azerite.primal_instincts.enabled)
  if CDsON() and S.AspectoftheWild:IsCastable() and Player:BuffDown(S.AspectoftheWildBuff) and (S.BarbedShot:Charges() < 1 or not S.PrimalInstincts:AzeriteEnabled()) then
    if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return "Aspect of the Wild (ST)"; end
  end
  -- stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
  if S.Stampede:IsCastable() and ((Player:BuffUp(S.AspectoftheWildBuff) and Player:BuffUp(S.BestialWrathBuff)) or Target:TimeToDie() < 15) then
    if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede, nil, not TargetInRange30y) then return "Stampede (ST)"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "A Murder of Crows (ST)"; end
  end
  -- focused_azerite_beam,if=buff.bestial_wrath.down|target.time_to_die<5
  -- TODO
  -- the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10|target.time_to_die<5
  -- TODO
  -- bestial_wrath,if=talent.one_with_the_pack.enabled&buff.bestial_wrath.remains<gcd
  --                  |buff.bestial_wrath.down&cooldown.aspect_of_the_wild.remains>15
  --                  |target.time_to_die<15+gcd
  if CDsON() and S.BestialWrath:IsCastable() and ((S.OneWithThePack:IsAvailable() and S.BestialWrath:CooldownRemains() < GCDMax)
    or (Player:BuffDown(S.BestialWrathBuff) and S.AspectoftheWild:CooldownRemains() > 15)
    or Target:TimeToDie() < 15 + GCDMax) then
    if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return "Bestial Wrath (ST)"; end
  end
  -- barbed_shot,if=azerite.dance_of_death.rank>1&buff.dance_of_death.remains<gcd
  if S.BarbedShot:IsCastable() and S.DanceofDeath:AzeriteRank() > 1 and Player:BuffRemains(S.DanceofDeath) < GCDMax then
    if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 2)"; end
  end
  -- blood_of_the_enemy,if=buff.aspect_of_the_wild.remains>10+gcd|target.time_to_die<10+gcd
  -- TODO
  -- kill_command
  if S.KillCommand:IsReady() then
    if HR.Cast(S.KillCommand) then return "Kill Command (ST)"; end
  end
  -- bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.BestialWrathBuff) or Target:TimeToDie() < 5) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetInRange40y) then return "Bag of Tricks (ST)"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsCastable() then
    if HR.Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "Chimaera Shot (ST)"; end
  end
  -- dire_beast
  if S.DireBeast:IsReady() then
    if HR.Cast(S.DireBeast, nil, nil, not TargetInRange40y) then return "Dire Beast (ST)"; end
  end
  -- barbed_shot,if=talent.one_with_the_pack.enabled&charges_fractional>1.5
  --                |charges_fractional>1.8
  --                |cooldown.aspect_of_the_wild.remains<pet.main.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled
  --                |target.time_to_die<9
  if S.BarbedShot:IsCastable() and ((S.OneWithThePack:IsAvailable() and S.BarbedShot:ChargesFractional() > 1.5)
    or S.BarbedShot:ChargesFractional() > 1.8
    or (S.AspectoftheWild:CooldownRemains() < Pet:BuffDuration(S.FrenzyPetBuff) - GCDMax and S.PrimalInstincts:AzeriteEnabled())
    or Target:TimeToDie() < 9) then
    if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 3)"; end
  end
  -- purifying_blast,if=buff.bestial_wrath.down|target.time_to_die<8
  -- TODO
  -- barrage
  if S.Barrage:IsReady() then
    if HR.Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "Barrage (ST)"; end
  end
  --cobra_shot,if=(
  --                focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost
  --                |cooldown.kill_command.remains>1+gcd&cooldown.bestial_wrath.remains_guess>focus.time_to_max|buff.memory_of_lucid_dreams.up
  --              )&cooldown.kill_command.remains>1
  --              |target.time_to_die<3
  -- TODO: Add lucid dream buff
  if S.CobraShot:IsReady() and (
      (Player:FocusPredicted() - S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemains() - 1) > S.KillCommand:Cost())
      or (S.KillCommand:CooldownRemains() > 1 + GCDMax) and S.BestialWrath:CooldownRemains() > Player:FocusTimeToMaxPredicted()
    ) and S.KillCommand:CooldownRemains() > 1
    or Target:TimeToDie() < 3 then
    if HR.Cast(S.CobraShot, nil, nil, not TargetInRange40y) then return "Cobra Shot (ST)"; end
  end
  -- barbed_shot,if=pet.main.buff.frenzy.duration-gcd>full_recharge_time
  if S.BarbedShot:IsCastable() and  Pet:BuffDuration(S.FrenzyPetBuff) - GCDMax > S.BarbedShot:FullRechargeTime() then
    if HR.Cast(S.BarbedShot, nil, nil, not TargetInRange40y) then return "Barbed Shot (ST - 4)"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Rotation Variables Update
  UpdateGCDMax()

  -- Unit Update
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40) -- Barbed Shot Cycle
    Enemies40yCount = #Enemies40y
    SplashEnemies10yCount = Target:GetEnemiesInSplashRangeCount(10) -- Beast Cleave
    SplashEnemies8yCount = Target:GetEnemiesInSplashRangeCount(8) -- Multi-Shot
  else
    Enemies40y = { Target }
    Enemies40yCount = 1
    SplashEnemies10yCount = 1
    SplashEnemies8yCount = 1
  end
  TargetInRange40y = Target:IsInRange(40) -- Most abilities
  TargetInRange30y = Target:IsInRange(30) -- Stampede
  TargetInRangePet50y = Target:IsInRange(50) -- Kill Command TODO: Use Pet range once supported in HeroLib
  TargetInMeleeRangePet5y = Target:IsInMeleeRange(5) -- Melee Abilities TODO: Use Pet range once supported in HeroLib

  -- Defensives
  -- Exhilaration
  if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
    if HR.Cast(S.Exhilaration, Settings.Commons.GCDasOffGCD.Exhilaration) then return "Exhilaration"; end
  end

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

  -- Out of Combat
  if not Player:AffectingCombat() then
    ShouldReturn = PreCombat();
    if ShouldReturn then return ShouldReturn; end
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Interrupts
     ShouldReturn = Everyone.Interrupt(40, S.CounterShot, Settings.Commons.OffGCDasOffGCD.CounterShot, StunInterrupts);
     if ShouldReturn then return ShouldReturn; end

    -- auto_shot

    -- use_items,if=prev_gcd.1.aspect_of_the_wild|target.time_to_die<20
    -- NOTE: Above line is very non-optimal and feedback has been given to the SimC APL devs, following logic will be used for now:
    --  if=buff.aspect_of_the_wild.remains>10|cooldown.aspect_of_the_wild.remains>60|target.time_to_die<20
    if Player:BuffRemains(S.AspectoftheWildBuff) > 10 or S.AspectoftheWild:CooldownRemains() > 60 or Target:TimeToDie() < 20 then
      local TrinketToUse = HL.UseTrinkets(TrinketsOnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end

    -- use_item,name=azsharas_font_of_power,if=cooldown.aspect_of_the_wild.remains_guess<15&target.time_to_die>10
    -- TODO

    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.up&(!equipped.azsharas_font_of_power|trinket.azsharas_font_of_power.cooldown.remains>86|essence.blood_of_the_enemy.major)&(prev_gcd.1.aspect_of_the_wild|!equipped.cyclotronic_blast&buff.aspect_of_the_wild.remains>9)&(!essence.condensed_lifeforce.major|buff.guardian_of_azeroth.up)&(target.health.pct<35|!essence.condensed_lifeforce.major|!talent.killer_instinct.enabled)|(debuff.razor_coral_debuff.down|target.time_to_die<26)&target.time_to_die>(24*(cooldown.cyclotronic_blast.remains+4<target.time_to_die))
    -- TODO

    -- use_item,effect_name=cyclotronic_blast,if=buff.bestial_wrath.down|target.time_to_die<5
    -- TODO

    -- call_action_list,name=cds
    if CDsON() then
      ShouldReturn = CDs();
      if ShouldReturn then return ShouldReturn; end
    end

    if SplashEnemies8yCount > 1 then
      -- call_action_list,name=cleave,if=active_enemies>1
      ShouldReturn = Cleave();
    else
      -- call_action_list,name=st,if=active_enemies<2
      ShouldReturn = ST();
    end
    if ShouldReturn then return ShouldReturn; end

    if HR.Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

local function OnInit ()
end

HR.SetAPL(253, APL, OnInit)


--- ======= SIMC =======
-- Last Update: 12/31/2999

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/use_item,name=azsharas_font_of_power
-- actions.precombat+=/worldvein_resonance
-- actions.precombat+=/guardian_of_azeroth
-- actions.precombat+=/memory_of_lucid_dreams
-- actions.precombat+=/use_item,effect_name=cyclotronic_blast,if=!raid_event.invulnerable.exists&(trinket.1.has_cooldown+trinket.2.has_cooldown<2|equipped.variable_intensity_gigavolt_oscillating_reactor)
-- actions.precombat+=/focused_azerite_beam,if=!raid_event.invulnerable.exists
-- # Adjusts the duration and cooldown of Aspect of the Wild and Primal Instincts by the duration of an unhasted GCD when they're used precombat. Because Aspect of the Wild reduces GCD by 200ms, this is 1.3 seconds.
-- actions.precombat+=/aspect_of_the_wild,precast_time=1.3,if=!azerite.primal_instincts.enabled&!essence.essence_of_the_focusing_iris.major&(equipped.azsharas_font_of_power|!equipped.cyclotronic_blast)
-- # Adjusts the duration and cooldown of Bestial Wrath and Haze of Rage by the duration of an unhasted GCD when they're used precombat.
-- actions.precombat+=/bestial_wrath,precast_time=1.5,if=azerite.primal_instincts.enabled&!essence.essence_of_the_focusing_iris.major&(equipped.azsharas_font_of_power|!equipped.cyclotronic_blast)
-- actions.precombat+=/potion,dynamic_prepot=1

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/use_items,if=prev_gcd.1.aspect_of_the_wild|target.time_to_die<20
-- actions+=/use_item,name=azsharas_font_of_power,if=cooldown.aspect_of_the_wild.remains_guess<15&target.time_to_die>10
-- actions+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.up&(!equipped.azsharas_font_of_power|trinket.azsharas_font_of_power.cooldown.remains>86|essence.blood_of_the_enemy.major)&(prev_gcd.1.aspect_of_the_wild|!equipped.cyclotronic_blast&buff.aspect_of_the_wild.remains>9)&(!essence.condensed_lifeforce.major|buff.guardian_of_azeroth.up)&(target.health.pct<35|!essence.condensed_lifeforce.major|!talent.killer_instinct.enabled)|(debuff.razor_coral_debuff.down|target.time_to_die<26)&target.time_to_die>(24*(cooldown.cyclotronic_blast.remains+4<target.time_to_die))
-- actions+=/use_item,effect_name=cyclotronic_blast,if=buff.bestial_wrath.down|target.time_to_die<5
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=st,if=active_enemies<2
-- actions+=/call_action_list,name=cleave,if=active_enemies>1

-- actions.cds=ancestral_call,if=cooldown.bestial_wrath.remains>30
-- actions.cds+=/fireblood,if=cooldown.bestial_wrath.remains>30
-- actions.cds+=/berserking,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<13
-- actions.cds+=/blood_fury,if=buff.aspect_of_the_wild.up&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<35|!talent.killer_instinct.enabled))|target.time_to_die<16
-- actions.cds+=/lights_judgment,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains>gcd.max|!pet.main.buff.frenzy.up
-- actions.cds+=/potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up&target.health.pct<35|((consumable.potion_of_unbridled_fury|consumable.unbridled_fury)&target.time_to_die<61|target.time_to_die<26)
-- actions.cds+=/worldvein_resonance,if=(prev_gcd.1.aspect_of_the_wild|cooldown.aspect_of_the_wild.remains<gcd|target.time_to_die<20)|!essence.vision_of_perfection.minor
-- actions.cds+=/guardian_of_azeroth,if=cooldown.aspect_of_the_wild.remains<10|target.time_to_die>cooldown+duration|target.time_to_die<30
-- actions.cds+=/ripple_in_space
-- actions.cds+=/memory_of_lucid_dreams
-- actions.cds+=/reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30

-- actions.cleave=barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<=gcd.max
-- actions.cleave+=/multishot,if=gcd.max-pet.main.buff.beast_cleave.remains>0.25
-- actions.cleave+=/barbed_shot,target_if=min:dot.barbed_shot.remains,if=full_recharge_time<gcd.max&cooldown.bestial_wrath.remains
-- actions.cleave+=/aspect_of_the_wild
-- actions.cleave+=/stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
-- actions.cleave+=/bestial_wrath,if=cooldown.aspect_of_the_wild.remains_guess>20|talent.one_with_the_pack.enabled|target.time_to_die<15
-- actions.cleave+=/chimaera_shot
-- actions.cleave+=/a_murder_of_crows
-- actions.cleave+=/barrage
-- actions.cleave+=/kill_command,if=active_enemies<4|!azerite.rapid_reload.enabled
-- actions.cleave+=/dire_beast
-- actions.cleave+=/barbed_shot,target_if=min:dot.barbed_shot.remains,if=pet.main.buff.frenzy.down&(charges_fractional>1.8|buff.bestial_wrath.up)|cooldown.aspect_of_the_wild.remains<pet.main.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|charges_fractional>1.4|target.time_to_die<9
-- actions.cleave+=/focused_azerite_beam
-- actions.cleave+=/purifying_blast
-- actions.cleave+=/concentrated_flame
-- actions.cleave+=/blood_of_the_enemy
-- actions.cleave+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
-- actions.cleave+=/multishot,if=azerite.rapid_reload.enabled&active_enemies>2
-- actions.cleave+=/cobra_shot,if=cooldown.kill_command.remains>focus.time_to_max&(active_enemies<3|!azerite.rapid_reload.enabled)

-- actions.st=kill_shot
-- actions.st+=/bloodshed
-- actions.st+=/barbed_shot,if=pet.main.buff.frenzy.up&pet.main.buff.frenzy.remains<gcd|cooldown.bestial_wrath.remains&(full_recharge_time<gcd|azerite.primal_instincts.enabled&cooldown.aspect_of_the_wild.remains<gcd)
-- actions.st+=/concentrated_flame,if=focus+focus.regen*gcd<focus.max&buff.bestial_wrath.down&(!dot.concentrated_flame_burn.remains&!action.concentrated_flame.in_flight)|full_recharge_time<gcd|target.time_to_die<5
-- actions.st+=/aspect_of_the_wild,if=buff.aspect_of_the_wild.down&(cooldown.barbed_shot.charges<1|!azerite.primal_instincts.enabled)
-- actions.st+=/stampede,if=buff.aspect_of_the_wild.up&buff.bestial_wrath.up|target.time_to_die<15
-- actions.st+=/a_murder_of_crows
-- actions.st+=/focused_azerite_beam,if=buff.bestial_wrath.down|target.time_to_die<5
-- actions.st+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10|target.time_to_die<5
-- actions.st+=/bestial_wrath,if=talent.one_with_the_pack.enabled&buff.bestial_wrath.remains<gcd|buff.bestial_wrath.down&cooldown.aspect_of_the_wild.remains>15|target.time_to_die<15+gcd
-- actions.st+=/barbed_shot,if=azerite.dance_of_death.rank>1&buff.dance_of_death.remains<gcd
-- actions.st+=/blood_of_the_enemy,if=buff.aspect_of_the_wild.remains>10+gcd|target.time_to_die<10+gcd
-- actions.st+=/kill_command
-- actions.st+=/bag_of_tricks,if=buff.bestial_wrath.down|target.time_to_die<5
-- actions.st+=/chimaera_shot
-- actions.st+=/dire_beast
-- actions.st+=/barbed_shot,if=talent.one_with_the_pack.enabled&charges_fractional>1.5|charges_fractional>1.8|cooldown.aspect_of_the_wild.remains<pet.main.buff.frenzy.duration-gcd&azerite.primal_instincts.enabled|target.time_to_die<9
-- actions.st+=/purifying_blast,if=buff.bestial_wrath.down|target.time_to_die<8
-- actions.st+=/barrage
-- actions.st+=/cobra_shot,if=(focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost|cooldown.kill_command.remains>1+gcd&cooldown.bestial_wrath.remains_guess>focus.time_to_max|buff.memory_of_lucid_dreams.up)&cooldown.kill_command.remains>1|target.time_to_die<3
-- actions.st+=/barbed_shot,if=pet.main.buff.frenzy.duration-gcd>full_recharge_time

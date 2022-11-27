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
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Arms
local I = Item.Warrior.Arms

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Variables
local TargetInMeleeRange

-- Enemies Variables
local Enemies8y
local EnemiesCount8y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Arms = HR.GUISettings.APL.Warrior.Arms
}

-- Interrupts List
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
}

-- Legendaries
local BattlelordEquipped = Player:HasLegendaryEquipped(183)
local SinfulSurgeEquipped = Player:HasLegendaryEquipped(215)
local EnduringBlowEquipped = Player:HasLegendaryEquipped(182)
local SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)

-- Event Registrations
HL:RegisterForEvent(function()
  BattlelordEquipped = Player:HasLegendaryEquipped(183)
  SinfulSurgeEquipped = Player:HasLegendaryEquipped(215)
  EnduringBlowEquipped = Player:HasLegendaryEquipped(182)
  SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.BattleShout:IsCastable() and (Player:BuffDown(S.BattleShoutBuff, true) or Everyone.GroupBuffMissing(S.BattleShoutBuff)) then
    if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- fleshcraft
  if S.Fleshcraft:IsReady() then
    if Cast(S.Fleshcraft) then return "fleshcraft precombat 4"; end
  end
  -- conquerors_banner
  if S.ConquerorsBanner:IsReady() then
    if Cast(S.ConquerorsBanner) then return "conquerors_banner precombat 6"; end
  end
  -- Manually added opener abilties
  if S.Charge:IsCastable() and not TargetInMeleeRange then
    if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge) then return "charge precombat 8"; end
  end
  if TargetInMeleeRange then
    if S.Skullsplitter:IsCastable() then
      if Cast(S.Skullsplitter) then return "skullsplitter precombat 10"; end
    end
    if S.ColossusSmash:IsCastable() then
      if Cast(S.ColossusSmash) then return "colossus_smash precombat 12"; end
    end
    if S.Warbreaker:IsCastable() then
      if Cast(S.Warbreaker) then return "warbreaker precombat 14"; end
    end
    if S.Overpower:IsCastable() then
      if Cast(S.Overpower) then return "overpower precombat 16"; end
    end
  end
  if S.HeroicThrow:IsCastable() then
    if Cast(S.HeroicThrow) then return "heroic_throw precombat 18"; end
  end
  if S.Charge:IsCastable() then
    if Cast(S.Charge) then return "charge precombat 20"; end
  end
end

local function Execute()
  -- sweeping_strikes,if=spell_targets.whirlwind>1
  if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1) then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes execute 2"; end
  end
  -- rend,if=remains<=gcd&(!talent.warbreaker&cooldown.colossus_smash.remains<4|talent.warbreaker&cooldown.warbreaker.remains<4)&target.time_to_die>12
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and ((not S.Warbreaker:IsAvailable()) and S.ColossusSmash:CooldownRemains() < 4 or S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 4) and Target:TimeToDie() > 12) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend execute 4"; end
  end
  -- avatar,if=gcd.remains=0|target.time_to_die<20
  if S.Avatar:IsCastable() and CDsON() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar execute 6"; end
  end
  -- conquerors_banner
  if CDsON() and S.ConquerorsBanner:IsReady() then
    if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Signature) then return "conquerors_banner execute 8"; end
  end
  -- condemn,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd|buff.juggernaut.up&buff.juggernaut.remains<gcd
  if S.Condemn:IsReady() and (Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD() or Player:BuffUp(S.JuggernautBuff) and Player:BuffRemains(S.JuggernautBuff)) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Signature, not TargetInMeleeRange) then return "condemn execute 10"; end
  end
  -- thunderous_roar,if=buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (Player:BuffUp(S.TestofMightBuff) or (not S.TestofMight:IsAvailable()) and Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Cast(S.ThunderousRoar, Settings.Commons.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar execute 12"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker execute 14"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash execute 16"; end
  end
  if CDsON() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    -- spear_of_bastion,if=debuff.colossus_smash.up|buff.test_of_might.up
    if S.SpearofBastion:IsCastable() then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion execute 18"; end
    end
    -- kyrian_spear,if=debuff.colossus_smash.up|buff.test_of_might.up
    if S.SpearofBastionCov:IsReady() then
      if Cast(S.SpearofBastionCov, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "kyrian_spear execute 20"; end
    end
    -- ancient_aftershock,if=debuff.colossus_smash.up|buff.test_of_might.up
    if S.AncientAftershock:IsCastable() then
      if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Signature, not TargetInMeleeRange) then return "ancient_aftershock execute 22"; end
    end
  end
  -- mortal_strike,if=dot.deep_wounds.remains<=gcd
  if S.MortalStrike:IsReady() and (Target:DebuffRemains(S.DeepWoundsDebuff) <= Player:GCD()) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike execute 24"; end
  end
  -- cleave,if=spell_targets.whirlwind>1&dot.deep_wounds.remains<gcd
  if S.Cleave:IsReady() and (EnemiesCount8y > 1 and Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave execute 26"; end
  end
  -- condemn
  if S.Condemn:IsReady() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Signature, not TargetInMeleeRange) then return "condemn execute 28"; end
  end
  -- skullsplitter,if=rage<40
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 40) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter execute 30"; end
  end
  -- mortal_strike,if=debuff.executioners_precision.stack=2|dot.deep_wounds.remains<=gcd
  if S.MortalStrike:IsReady() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 or Target:DebuffRemains(S.DeepWoundsDebuff) <= Player:GCD()) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike execute 32"; end
  end
  -- rend,if=remains<duration*0.3&debuff.colossus_smash.down
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff) and Target:DebuffDown(S.ColossusSmashDebuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend execute 34"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute execute 36"; end
  end
  -- shockwave,if=talent.sonic_boom
  if S.Shockwave:IsCastable() and (S.SonicBoom:IsAvailable()) then
    if Cast(S.Shockwave, Settings.Commons.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave execute 38"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower execute 40"; end
  end
end

local function SingleTarget()
  -- sweeping_strikes,if=spell_targets.whirlwind>1
  if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1) then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes single_target 2"; end
  end
  -- rend,if=remains<=gcd|talent.tide_of_blood&cooldown.skullsplitter.remains<=gcd&(cooldown.colossus_smash.remains<=gcd|debuff.colossus_smash.up)&dot.rend.remains<duration*0.85
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() or S.TideofBlood:IsAvailable() and S.Skullsplitter:CooldownRemains() <= Player:GCD() and (S.ColossusSmash:CooldownRemains() <= Player:GCD() or Target:DebuffUp(S.ColossusSmashDebuff)) and Target:DebuffRemains(S.RendDebuff) < S.RendDebuff:BaseDuration() * 0.85) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 4"; end
  end
  -- conquerors_banner,if=target.time_to_die>140
  if CDsON() and S.ConquerorsBanner:IsReady() and (Target:TimeToDie() > 140) then
    if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Signature) then return "conquerors_banner single_target 6"; end
  end
  -- avatar,if=gcd.remains=0
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar single_target 8"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker single_target 10"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash single_target 12"; end
  end
  -- thunderous_roar,if=debuff.colossus_smash.up|buff.test_of_might.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    if Cast(S.ThunderousRoar, Settings.Commons.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar single_target 14"; end
  end
  -- spear_of_bastion,if=debuff.colossus_smash.up|buff.test_of_might.up
  if CDsON() and S.SpearofBastion:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion single_target 16"; end
  end
  -- kyrian_spear,if=debuff.colossus_smash.up|buff.test_of_might.up
  if CDsON() and S.SpearofBastionCov:IsReady() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    if Cast(S.SpearofBastionCov, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "kyrian_spear single_target 18"; end
  end
  -- ancient_aftershock,if=debuff.colossus_smash.up|buff.test_of_might.up
  if S.AncientAftershock:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Signature, not TargetInMeleeRange) then return "ancient_aftershock single_target 20"; end
  end
  -- bladestorm,if=talent.hurricane&(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)|debuff.colossus_smash.up&talent.unhinged
  if S.Bladestorm:IsCastable() and (S.Hurricane:IsAvailable() and (Player:BuffUp(S.TestofMightBuff) or (not S.TestofMight:IsAvailable()) and Target:DebuffUp(S.ColossusSmashDebuff)) or Target:DebuffUp(S.ColossusSmashDebuff) and S.Unhinged:IsAvailable()) then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm single_target 22"; end
  end
  -- skullsplitter,if=talent.tide_of_blood&dot.rend.remains&(buff.sweeping_strikes.up&active_enemies>=2|debuff.colossus_smash.up|buff.test_of_might.up)|rage<40
  if S.Skullsplitter:IsCastable() and (S.TideofBlood:IsAvailable() and Target:DebuffUp(S.RendDebuff) and (Player:BuffUp(S.SweepingStrikesBuff) and EnemiesCount8y >= 2 or Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) or Player:Rage() < 40) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter single_target 24"; end
  end
  -- mortal_strike,if=runeforge.enduring_blow|runeforge.battlelord|dot.deep_wounds.remains<=gcd|debuff.executioners_precision.stack=2
  if S.MortalStrike:IsReady() and (EnduringBlowEquipped or BattlelordEquipped or Target:DebuffRemains(S.DeepWoundsDebuff) <= Player:GCD() or Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike single_target 26"; end
  end
  -- execute,if=buff.sudden_death.react
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 28"; end
  end
  -- condemn,if=buff.sudden_death.react
  if S.Condemn:IsReady() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Signature, not TargetInMeleeRange) then return "condemn single_target 30"; end
  end
  -- shockwave,if=talent.sonic_boom.enabled
  if S.Shockwave:IsCastable() and (S.SonicBoom:IsAvailable()) then
    if Cast(S.Shockwave, Settings.Commons.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave single_target 32"; end
  end
  -- whirlwind,if=spell_targets.whirlwind>1&buff.merciless_bonegrinder.up
  if S.Whirlwind:IsReady() and (EnemiesCount8y > 1 and Player:BuffUp(S.MercilessBonegrinderBuff)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 34"; end
  end
  -- overpower,if=charges=2&(!talent.test_of_might|talent.test_of_might&debuff.colossus_smash.down)
  if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2 and ((not S.TestofMight:IsAvailable()) or S.TestofMight:IsAvailable() and Target:DebuffDown(S.ColossusSmashDebuff))) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 36"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike single_target 38"; end
  end
  -- rend,if=remains<duration*0.3
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 40"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave single_target 42"; end
  end
  -- overpower,if=rage<70&debuff.colossus_smash.down|rage<30
  if S.Overpower:IsCastable() and (Player:Rage() < 70 and Target:DebuffDown(S.ColossusSmashDebuff) or Player:Rage() < 30) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 44"; end
  end
  -- slam,if=!talent.fervor_of_battle.enabled|spell_targets.whirlwind=1
  if S.Slam:IsReady() and ((not S.FervorofBattle:IsAvailable()) or EnemiesCount8y == 1) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 46"; end
  end
  -- whirlwind,if=talent.fervor_of_battle.enabled&spell_targets.whirlwind>1
  if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable() and EnemiesCount8y > 1) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind single_target 48"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw single_target 46"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCount8y = 1
  end

  -- Range check
  TargetInMeleeRange = Target:IsInMeleeRange(5)

  if Everyone.TargetIsValid() then
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- charge
    if S.Charge:IsCastable() and (not TargetInMeleeRange) then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsReady() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal"; end
      end
    end
    -- auto_attack
    -- potion,if=gcd.remains=0&debuff.colossus_smash.remains>8|target.time_to_die<25
    if Settings.Commons.Enabled.Potions and (Target:DebuffRemains(S.ColossusSmashDebuff) > 8 or Target:TimeToDie() < 25) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
      end
    end
    if CDsON() then
      -- arcane_torrent,if=cooldown.mortal_strike.remains>1.5&rage<50
      if S.ArcaneTorrent:IsCastable() and (S.MortalStrike:CooldownRemains() > 1.5 and Player:Rage() < 50) then
        if Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 6"; end
      end
      -- lights_judgment,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.LightsJudgment:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 8"; end
      end
      -- bag_of_tricks,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.BagofTricks:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 10"; end
      end
      -- berserking,if=debuff.colossus_smash.remains>6
      if S.Berserking:IsCastable() and (Target:DebuffRemains(S.ColossusSmashDebuff) > 6) then
        if Cast(S.Berserking, Settings.Commons.GCDasOffGCD.Racials) then return "berserking main 12"; end
      end
      -- blood_fury,if=debuff.colossus_smash.up
      if S.BloodFury:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.BloodFury, Settings.Commons.GCDasOffGCD.Racials) then return "blood_fury main 14"; end
      end
      -- fireblood,if=debuff.colossus_smash.up
      if S.Fireblood:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.Fireblood, Settings.Commons.GCDasOffGCD.Racials) then return "fireblood main 16"; end
      end
      -- ancestral_call,if=debuff.colossus_smash.up
      if S.AncestralCall:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.AncestralCall, Settings.Commons.GCDasOffGCD.Racials) then return "ancestral_call main 18"; end
      end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>15)
    if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1 and S.Bladestorm:CooldownRemains() > 15) then
      if Cast(S.SweepingStrikes, nil, nil, not Target:IsInRange(8)) then return "sweeping_strikes main 20"; end
    end
    -- call_action_list,name=execute,target_if=max:target.health.pct,if=target.health.pct>80&covenant.venthyr
    -- call_action_list,name=execute,target_if=min:target.health.pct,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
    -- Note: Combined both lines
    if ((S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20 or (Target:HealthPercentage() > 80 and CovenantID == 2)) then
      local ShouldReturn = Execute(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Arms Warrior rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(71, APL, Init)

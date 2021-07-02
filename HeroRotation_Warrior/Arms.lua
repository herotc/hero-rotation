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

-- Legendaries
local BattlelordEquipped = Player:HasLegendaryEquipped(183)
local SinfulSurgeEquipped = Player:HasLegendaryEquipped(215)
local EnduringBlowEquipped = Player:HasLegendaryEquipped(182)
local SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)

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

-- Event Registrations
HL:RegisterForEvent(function()
  BattlelordEquipped = Player:HasLegendaryEquipped(183)
  SinfulSurgeEquipped = Player:HasLegendaryEquipped(215)
  EnduringBlowEquipped = Player:HasLegendaryEquipped(182)
  SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
end, "PLAYER_EQUIPMENT_CHANGED")

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
  if Everyone.TargetIsValid() then
    -- Manually added: battle_shout,if=buff.battle_shout.remains<60
    if S.BattleShout:IsCastable() and (Player:BuffRemains(S.BattleShoutBuff, true) < 60) then
      if Cast(S.BattleShout, Settings.Arms.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
    end
    -- Manually added opener abilties
    if S.Charge:IsCastable() and S.Charge:Charges() >= 1 and not TargetInMeleeRange then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge) then return "charge precombat 4"; end
    end
    if TargetInMeleeRange then
      if S.Skullsplitter:IsCastable() then
        if Cast(S.Skullsplitter) then return "skullsplitter precombat 6"; end
      end
      if S.ColossusSmash:IsCastable() then
        if Cast(S.ColossusSmash) then return "colossus_smash precombat 8"; end
      end
      if S.Warbreaker:IsCastable() then
        if Cast(S.Warbreaker) then return "warbreaker precombat 10"; end
      end
      if S.Overpower:IsCastable() then
        if Cast(S.Overpower) then return "overpower precombat 12"; end
      end
    end
  end
end

local function Hac()
  -- skullsplitter,if=rage<60&buff.deadly_calm.down
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 60 and Player:BuffDown(S.DeadlyCalmBuff)) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter hac 2"; end
  end
  if CDsON() then
    -- conquerors_banner
    if S.ConquerorsBanner:IsCastable() then
      if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner hac 4"; end
    end
    -- avatar,if=cooldown.colossus_smash.remains<1
    if S.Avatar:IsCastable() and (S.ColossusSmash:CooldownRemains() < 1) then
      if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar hac 6"; end
    end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker hac 8"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash hac 10"; end
  end
  -- cleave,if=dot.deep_wounds.remains<=gcd
  if S.Cleave:IsReady() and (Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
    if Cast(S.Cleave, nil, nil, not Target:IsInRange(8)) then return "cleave hac 12"; end
  end
  -- bladestorm
  if S.Bladestorm:IsCastable() and CDsON() then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm hac 14"; end
  end
  -- ravager
  if S.Ravager:IsCastable() and CDsON() then
    if Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager hac 16"; end
  end
  -- rend,if=remains<=duration*0.3&buff.sweeping_strikes.up
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff) and Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend hac 18"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not Target:IsInRange(8)) then return "cleave hac 20"; end
  end
  -- mortal_strike,if=buff.sweeping_strikes.up|dot.deep_wounds.remains<gcd&!talent.cleave.enabled
  if S.MortalStrike:IsReady() and (Player:BuffUp(S.SweepingStrikesBuff) or Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD() and not S.Cleave:IsAvailable()) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike hac 22"; end
  end
  -- overpower,if=talent.dreadnaught.enabled
  if S.Overpower:IsCastable() and (S.Dreadnaught:IsAvailable()) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower hac 24"; end
  end
  -- condemn
  if S.Condemn:IsCastable() and S.Condemn:IsUsable() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn hac 26"; end
  end
  -- execute,if=buff.sweeping_strikes.up
  if S.Execute:IsCastable() and S.Execute:IsUsable() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute hac 28"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower hac 30"; end
  end
  -- whirlwind
  if S.Whirlwind:IsReady() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind hac 32"; end
  end
  
end

local function Execute()
  -- deadly_calm
  if S.DeadlyCalm:IsCastable() and CDsON() then
    if Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm execute 2"; end
  end
  --[[ // rend,if=remains<=duration*0.3
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend"; end
  end]]
  -- conquerors_banner
  if CDsON() and S.ConquerorsBanner:IsCastable() then
    if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner execute 4"; end
  end
  -- cancel_buff,name=bladestorm,if=spell_targets.whirlwind=1&gcd.remains=0&(rage>75|rage>50&buff.recklessness.up)
  -- avatar,if=gcd.remains=0|target.time_to_die<20
  if S.Avatar:IsCastable() and CDsON() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar execute 6"; end
  end
  -- condemn,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd&conduit.ashen_juggernaut.rank>1
  if S.Condemn:IsCastable() and (Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD() and S.AshenJuggernaut:ConduitRank() > 1) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn execute 8"; end
  end
  -- execute,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd&conduit.ashen_juggernaut.rank>1
  if S.Execute:IsCastable() and (Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD() and S.AshenJuggernaut:ConduitRank() > 1) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute execute 10"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager execute 12"; end
  end
  -- rend,if=remains<=gcd&(!talent.warbreaker.enabled&cooldown.colossus_smash.remains<4|talent.warbreaker.enabled&cooldown.warbreaker.remains<4)&target.time_to_die>12
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and (not S.Warbreaker:IsAvailable() and S.ColossusSmash:CooldownRemains() < 4 or S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 4) and Target:TimeToDie() > 12) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend execute 14"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker execute 16"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash execute 18"; end
  end
  if CDsON() then
    -- ancient_aftershock,if=debuff.colossus_smash.up
    if S.AncientAftershock:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
      if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "ancient_aftershock execute 20"; end
    end
    -- spear_of_bastion
    if S.SpearofBastion:IsCastable() then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion execute 22"; end
    end
  end
  -- condemn,if=runeforge.signet_of_tormented_kings&(rage.deficit<25|debuff.colossus_smash.up&rage>40|buff.sudden_death.react|buff.deadly_calm.up)
  if S.Condemn:IsCastable() and (SignetofTormentedKingsEquipped and (Player:RageDeficit() < 25 or Target:DebuffUp(S.ColossusSmashDebuff) and Player:Rage() > 40 or Player:BuffUp(S.SuddenDeathBuff) or Player:BuffUp(S.DeadlyCalmBuff))) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn execute 24"; end
  end
  -- overpower,if=charges=2
  if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower execute 26"; end
  end
  -- cleave,if=spell_targets.whirlwind>1&dot.deep_wounds.remains<gcd
  if S.Cleave:IsReady() and (EnemiesCount8y > 1 and Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave execute 28"; end
  end
  -- mortal_strike,if=dot.deep_wounds.remains<=gcd|runeforge.enduring_blow|buff.overpower.stack=2&debuff.exploiter.stack=2|buff.battlelord.up
  if S.MortalStrike:IsReady() and (Target:DebuffRemains(S.DeepWoundsDebuff) <= Player:GCD() or EnduringBlowEquipped or Player:BuffStack(S.OverpowerBuff) == 2 and Target:DebuffStack(S.ExploiterDebuff) == 2 or Player:BuffUp(S.BattlelordBuff)) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike execute 30"; end
  end
  -- condemn,if=rage.deficit<25|buff.deadly_calm.up
  if S.Condemn:IsCastable() and (Player:RageDeficit() < 25 or Player:BuffUp(S.DeadlyCalmBuff)) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn execute 32"; end
  end
  -- skullsplitter,if=rage<45
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 45) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter execute 34"; end
  end
  -- bladestorm,if=buff.deadly_calm.down&(rage<20|!runeforge.sinful_surge&rage<50)
  if CDsON() and S.Bladestorm:IsCastable() and (Player:BuffDown(S.DeadlyCalmBuff) and (Player:Rage() < 20 or not SinfulSurgeEquipped and Player:Rage() < 50)) then
    if Cast(S.Bladestorm, nil, nil, not TargetInMeleeRange) then return "bladestorm execute 36"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower execute 38"; end
  end
  -- condemn
  if S.Condemn:IsCastable() and S.Condemn:IsUsable() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn execute 40"; end
  end
  -- execute
  if S.Execute:IsCastable() and S.Execute:IsUsable() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute execute 42"; end
  end
end

local function SingleTarget()
  -- rend,if=remains<=gcd
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD()) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 2"; end
  end
  -- conquerors_banner,if=target.time_to_die>140
  if CDsON() and S.ConquerorsBanner:IsCastable() and (Target:TimeToDie() > 140) then
    if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner single_target 4"; end
  end
  -- avatar,if=gcd.remains=0
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar single_target 6"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    if Cast(S.Ravager, nil, nil, not Target:IsInRange(40)) then return "ravager single_target 8"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker single_target 10"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash single_target 12"; end
  end
  if CDsON() then
    -- ancient_aftershock,if=debuff.colossus_smash.up
    if S.AncientAftershock:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
      if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "ancient_aftershock single_target 14"; end
    end
    -- spear_of_bastion
    if S.SpearofBastion:IsCastable() then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion single_target 16"; end
    end
  end
  -- overpower,if=charges=2
  if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 18"; end
  end
  -- mortal_strike,if=runeforge.enduring_blow|runeforge.battlelord|buff.overpower.stack>=2
  if S.MortalStrike:IsReady() and (EnduringBlowEquipped or BattlelordEquipped or Player:BuffStack(S.OverpowerBuff) >= 2) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike single_target 20"; end
  end
  -- condemn,if=buff.sudden_death.react
  if S.Condemn:IsCastable() and S.Condemn:IsUsable() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn single_target 22"; end
  end
  -- execute,if=buff.sudden_death.react
  if S.Execute:IsCastable() and S.Execute:IsUsable() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 24"; end
  end
  -- skullsplitter,if=rage.deficit>45&buff.deadly_calm.down
  if S.Skullsplitter:IsCastable() and (Player:RageDeficit() > 45 and Player:BuffDown(S.DeadlyCalmBuff)) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter single_target 26"; end
  end
  -- bladestorm,if=buff.deadly_calm.down&rage<30
  if CDsON() and S.Bladestorm:IsCastable() and (Player:BuffDown(S.DeadlyCalmBuff) and Player:Rage() < 30) then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm single_target 28"; end
  end
  -- deadly_calm
  if CDsON() and S.DeadlyCalm:IsCastable() then
    if Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm single_target 30"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 32"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike single_target 34"; end
  end
  -- rend,if=remains<duration*0.3
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 36"; end
  end
  -- cleave,if=spell_targets.whirlwind>1
  if S.Cleave:IsReady() and (EnemiesCount8y > 1) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave single_target 38"; end
  end
  -- whirlwind,if=talent.fervor_of_battle.enabled|spell_targets.whirlwind>4|spell_targets.whirlwind>2&buff.sweeping_strikes.down
  if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable() or EnemiesCount8y > 4 or EnemiesCount8y > 2 and Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind single_target 40"; end
  end
  -- slam,if=!talent.fervor_of_battle.enabled&(rage>50|debuff.colossus_smash.up|!runeforge.enduring_blow)
  if S.Slam:IsReady() and (not S.FervorofBattle:IsAvailable() and (Player:Rage() > 50 or Target:DebuffUp(S.ColossusSmashDebuff) or not EnduringBlowEquipped)) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 42"; end
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

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- charge
    if S.Charge:IsCastable() and (not TargetInMeleeRange) then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsCastable() and S.VictoryRush:IsUsable() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() and S.VictoryRush:IsUsable() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal"; end
      end
    end
    -- auto_attack
    -- potion,if=gcd.remains=0&debuff.colossus_smash.remains>8|target.time_to_die<25
    if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions and (Target:DebuffRemains(S.ColossusSmashDebuff) > 8 or Target:TimeToDie() < 25) then
      if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
    end
    if CDsON() then
      -- arcane_torrent,if=cooldown.mortal_strike.remains>1.5&rage<50
      if S.ArcaneTorrent:IsCastable() and (S.MortalStrike:CooldownRemains() > 1.5 and Player:Rage() < 50) then
        if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 6"; end
      end
      -- lights_judgment,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.LightsJudgment:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 8"; end
      end
      -- bag_of_tricks,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.BagofTricks:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 10"; end
      end
      -- berserking,if=debuff.colossus_smash.remains>6
      if S.Berserking:IsCastable() and (Target:DebuffRemains(S.ColossusSmashDebuff) > 6) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 12"; end
      end
      -- blood_fury,if=debuff.colossus_smash.up
      if S.BloodFury:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 14"; end
      end
      -- fireblood,if=debuff.colossus_smash.up
      if S.Fireblood:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 16"; end
      end
      -- ancestral_call,if=debuff.colossus_smash.up
      if S.AncestralCall:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 18"; end
      end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>15|talent.ravager.enabled)
    if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1 and (S.Bladestorm:CooldownRemains() > 15 or S.Ravager:IsAvailable())) then
      if Cast(S.SweepingStrikes, nil, nil, not Target:IsInRange(8)) then return "sweeping_strikes main 20"; end
    end
    -- run_action_list,name=hac,if=raid_event.adds.exists
    if (EnemiesCount8y >= 3) then
      local ShouldReturn = Hac(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20|(target.health.pct>80&covenant.venthyr)
    if ((S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20 or (Target:HealthPercentage() > 80 and Player:Covenant() == "Venthyr")) then
      local ShouldReturn = Execute(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(71, APL, Init)

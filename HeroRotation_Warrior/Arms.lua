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

-- Rotation Var
local ShouldReturn -- Used to get the return string
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
    -- Manually added opener abilties
    if S.Charge:IsCastable() and S.Charge:Charges() >= 1 and not Target:IsInMeleeRange(5) then
      if HR.Cast(S.Charge) then return "charge"; end
    end
    if Target:IsInMeleeRange(5) then
      if S.Skullsplitter:IsCastable() then
        if HR.Cast(S.Skullsplitter) then return "skullsplitter"; end
      end
      if S.ColossusSmash:IsCastable() then
        if HR.Cast(S.ColossusSmash) then return "colossus_smash"; end
      end
      if S.Warbreaker:IsCastable() then
        if HR.Cast(S.Warbreaker) then return "warbreaker"; end
      end
      if S.Overpower:IsCastable() then
        if HR.Cast(S.Overpower) then return "overpower"; end
      end
    end
  end
end

local function Hac()
	-- skullsplitter,if=rage<60&buff.deadly_calm.down
	if S.Skullsplitter:IsCastable() and (Player:Rage() < 60 and Player:BuffDown(S.DeadlyCalmBuff)) then
		if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
	end
	-- avatar,if=cooldown.colossus_smash.remains<1
	if S.Avatar:IsCastable() and (S.ColossusSmash:CooldownRemains() < 1) then
		if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar"; end
	end
	-- cleave,if=dot.deep_wounds.remains<=gcd
	if S.Cleave:IsReady() and (Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
		if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
	end
	-- warbreaker
	if S.Warbreaker:IsCastable() then
		if HR.Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker"; end
	end
	-- bladestorm
	if S.Bladestorm:IsCastable() then
		if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm"; end
	end
	-- ravager
	if S.Ravager:IsCastable() then
		if HR.Cast(S.Ravager, nil, nil, not Target:IsInRange(40)) then return "ravager"; end
	end
	-- colossus_smash
	if S.ColossusSmash:IsCastable() then
		if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
	end
	-- rend,if=remains<=duration*0.3&buff.sweeping_strikes.up
	if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff) and Player:BuffUp(S.SweepingStrikesBuff)) then
		if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
	end
	-- cleave
	if S.Cleave:IsReady() then
		if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
	end
	-- mortal_strike,if=buff.sweeping_strikes.up|dot.deep_wounds.remains<gcd&!talent.cleave.enabled
	if S.MortalStrike:IsReady() and (Player:BuffUp(S.SweepingStrikesBuff) or Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD() and not S.Cleave:IsAvailable()) then
		if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
	end
	-- overpower,if=talent.dreadnaught.enabled
	if S.Overpower:IsCastable() and (S.Dreadnaught:IsAvailable()) then
		if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
	end
	-- Ancient Aftershock
	if S.AncientAftershock:IsCastable() then
		if HR.Cast(S.AncientAftershock, nil, nil, not Target:IsInRange(8)) then return "ancient_aftershock"; end
	end
	-- condemn
	if S.Condemn:IsReady() then
		if HR.Cast(S.Condemn, nil, nil, not Target:IsSpellInRange(S.Condemn)) then return "condemn"; end
	end
	-- execute,if=buff.sweeping_strikes.up
	if S.Execute:IsReady() and ((Target:HealthPercentage() < 20 or (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35)) or Player:BuffUp(S.SuddenDeathBuff)) and Player:BuffUp(S.SweepingStrikesBuff) then
		if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
	end
	-- overpower
	if S.Overpower:IsCastable() then
		if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
	end
	-- whirlwind
	if S.Whirlwind:IsReady() then
		if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
	end
	
end

local function FiveTarget()
end

local function Execute()
	-- deadly_calm
	if S.DeadlyCalm:IsCastable() then
		if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm"; end
	end
	-- rend,if=remains<=duration*0.3
	if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
		if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
	end
	-- skullsplitter,if=rage<60&(!talent.deadly_calm.enabled|buff.deadly_calm.down)
	if S.Skullsplitter:IsCastable() and (Player:Rage() < 50 and (not S.DeadlyCalm:IsAvailable() or Player:BuffDown(S.DeadlyCalmBuff))) then
		if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
	end
	-- avatar,if=cooldown.colossus_smash.remains<1
	if S.Avatar:IsCastable() and (S.ColossusSmash:CooldownRemains() < 1) then
		if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar"; end
	end
	-- cleave,if=spell_targets.whirlwind>1&dot.deep_wounds.remains<gcd
	if S.Cleave:IsReady() and (EnemiesCount8y > 1 and Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
		if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
	end
	-- warbreaker
	if S.Warbreaker:IsCastable() then
		if HR.Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker"; end
	end
	-- colossus_smash
	if S.ColossusSmash:IsCastable() then
		if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
	end
	-- overpower,if=charges=2
	if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2) then
		if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
	end
	-- mortal_strike,if=dot.deep_wounds.remains<gcd
	if S.MortalStrike:IsReady() and (Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
		if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
	end
	-- skullsplitter,if=rage<40
	if S.Skullsplitter:IsCastable() and (Player:Rage() < 40) then
		if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
	end
	-- overpower
	if S.Overpower:IsCastable() then
		if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
	end
	-- condemn
	if S.Condemn:IsReady() then
		if HR.Cast(S.Condemn, nil, nil, not Target:IsSpellInRange(S.Condemn)) then return "condemn"; end
	end
	-- execute
	if S.Execute:IsReady() then
		if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
	end
	-- bladestorm,if=rage<80
	if S.Bladestorm:IsCastable() and (Player:Rage() < 80) then
		if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm"; end
	end
	-- ravager,if=rage<80
	if S.Ravager:IsCastable() and (Player:Rage() < 80) then
		if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager"; end
	end
		
end

local function SingleTarget()
	-- avatar,if=cooldown.colossus_smash.remains<1
	if S.Avatar:IsCastable() and (S.ColossusSmash:CooldownRemains() < 1) then
		if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar"; end
	end
	-- rend,if=remains<=duration*0.3
	if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
		if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
	end
	-- cleave,if=spell_targets.whirlwind>1&dot.deep_wounds.remains<gcd
	if S.Cleave:IsReady() and (EnemiesCount8y > 1 and Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
		if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
	end
	-- warbreaker
	if S.Warbreaker:IsCastable() then
		if HR.Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker"; end
	end
	-- colossus_smash
	if S.ColossusSmash:IsCastable() then
		if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
	end
	-- bladestorm,if=debuff.colossus_smash.up&!covenant.venthyr
	if S.Bladestorm:IsCastable() and ((Target:DebuffUp(S.ColossusSmashDebuff) and (Player:Covenant() ~= "Venthyr"))) then
		if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm"; end
	end
	-- ravager,if=debuff.colossus_smash.up&!covenant.venthyr
	if S.Ravager:IsCastable() and (Target:DebuffUp(ColossusSmashDebuff) and Player:Covenant() ~= "Venthyr") then
		if HR.Cast(S.Ravager, nil, nil, not Target:IsInRange(40)) then return "ravager"; end
	end
	-- overpower,if=charges=2
	if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2) then
		if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
	end
	-- mortal_strike,if=buff.overpower.stack>=2&buff.deadly_calm.down|dot.deep_wounds.remains<=gcd
	if S.MortalStrike:IsReady() and ((Player:BuffUp(S.OverpowerBuff) and S.OverpowerBuff:Charges() >= 2) and Player.BuffDown(S.DeadlyCalmBuff) or Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
		if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
	end
	-- deadly_calm
	if S.DeadlyCalm:IsCastable() then
		if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm"; end
	end
	-- skullsplitter,if=rage<60&buff.deadly_calm.down
	if S.Skullsplitter:IsCastable() and (Player:Rage() < 60 and Player:BuffDown(S.DeadlyCalmBuff)) then
		if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
	end
	-- overpower
	if S.Overpower:IsCastable() then
		if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
	end
	-- condemn,if=buff.sudden_death.react
	if S.Condemn:IsReady() and (Player:BuffUp(SuddenDeathBuff)) then
		if HR.Cast(S.Condemn, nil, nil, not Target:IsSpellInRange(S.Condemn)) then return "condemn"; end
	end
	-- execute,if=buff.sudden_death.react
	if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff)) then
		if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
	end
	-- Ancient Aftershock
	if S.AncientAftershock:IsCastable() and (Player:Covenant() == "Night Fae") then
		if HR.Cast(S.AncientAftershock, nil, nil, not Target:IsInRange(5)) then return "ancient_aftershock"; end
	end
	-- mortal_strike
	if S.MortalStrike:IsReady() then
		if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
	end
	-- bladestorm,if=debuff.colossus_smash.up&covenant.venthyr
	if S.Bladestorm:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) and Player:Covenant() == "Venthyr") then
		if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm"; end
	end
	-- whirlwind,if=talent.fervor_of_battle.enabled&rage>60
	if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable() and Player:Rage() > 60) then
		if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
	end
	-- slam,if=rage>50
	if S.Slam:IsReady() and (Player:Rage() > 50 and (not S.FervorofBattle:IsAvailable())) then
		if HR.Cast(S.Slam, nil, nil, not Target:IsSpellInRange(S.Slam)) then return "slam"; end
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

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- charge
    if S.Charge:IsCastable() and (not Target:IsInMeleeRange(5)) then
      if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge, nil, not Target:IsSpellInRange(S.Charge)) then return "charge"; end
    end
    -- auto_attack
    -- potion
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofPhantomFire) then return "potion"; end
    end
    if CDsON() then
		-- blood_fury,if=debuff.colossus_smash.up
		if S.BloodFury:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
			if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
		end
		-- berserking,if=debuff.colossus_smash.remains>6
		if S.Berserking:IsCastable() and (Target:DebuffRemains(S.ColossusSmashDebuff) > 6) then
			if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking"; end
		end
		-- arcane_torrent,if=cooldown.mortal_strike.remains>1.5&rage<50
		if S.ArcaneTorrent:IsCastable() and (S.MortalStrike:CooldownRemains() > 1.5 and Player:Rage() < 50) then
			if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent"; end
		end
		-- lights_judgment,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
		if S.LightsJudgment:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
			if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment"; end
        end
		-- fireblood,if=debuff.colossus_smash.up
		if S.Fireblood:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
			if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
		end
		-- ancestral_call,if=debuff.colossus_smash.up
		if S.AncestralCall:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
			if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
		end
		-- bag_of_tricks,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
		if S.BagofTricks:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
			if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks"; end
        end
    end
    if (Settings.Commons.UseTrinkets) then
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- sweeping_strikes,if=spell_targets.whirlwind>1&cooldown.bladestorm.remains>12
    if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1 and (S.Bladestorm:CooldownRemains() > 12)) then
      if HR.Cast(S.SweepingStrikes, nil, nil, not Target:IsSpellInRange(S.SweepingStrikes)) then return "sweeping_strikes"; end
    end
	-- run_action_list,name=hac,if=raid_event.adds.exists
	if EnemiesCount8y >= 3 then
		local ShouldReturn = Hac(); if ShouldReturn then return ShouldReturn; end
	end
    -- run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20|(target.health.pct>80&covenant.venthyr)
    if (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or (Target:HealthPercentage() < 20) or (Target:HealthPercentage() > 80 and Player:Covenant() == "Venthyr") then
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

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
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
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
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and Settings.Commons.UseTrinkets then
      if HR.Cast(I.AzsharasFontofPower) then return "azsharas_font_of_power"; end
    end
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion"; end
    end
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
end

local function FiveTarget()
end

local function Execute()
  -- rend,if=remains<=duration*0.3
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
    if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
  end
  -- deadly_calm
  if S.DeadlyCalm:IsCastable() then
    if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm"; end
  end
  -- skullsplitter,if=rage<52&buff.memory_of_lucid_dreams.down|rage<20
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 52 and (Player:BuffDown(S.MemoryofLucidDreams) or Player:Rage() < 20)) then
    if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
  end
  -- ravager,if=cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2)
  if S.Ravager:IsCastable() and HR.CDsON() and (S.ColossusSmash:CooldownRemains() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 2)) then
   if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager, nil, not Target:IsSpellInRange(S.Ravager)) then return "ravager"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if HR.Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker"; end
  end
  -- mortal_strike,if=dot.deep_wounds.remains<=duration*0.3&(spell_targets.whirlwind=1|!spell_targets.whirlwind>1&!talent.cleave.enabled)
  if S.MortalStrike:IsReady() and (Target:DebuffRefreshable(S.DeepWoundsDebuff) and (EnemiesCount8y == 1 or not (EnemiesCount8y > 1) and not S.Cleave:IsAvailable())) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  -- cleave,if=(spell_targets.whirlwind>2&dot.deep_wounds.remains<=duration*0.3)|(spell_targets.whirlwind>3)
  if S.Cleave:IsReady() and ((EnemiesCount8y > 2 and Target:DebuffRefreshable(S.DeepWoundsDebuff)) or EnemiesCount8y > 3)  then
    if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
  end
  -- bladestorm,if=!buff.memory_of_lucid_dreams.up&buff.test_of_might.up&rage<30&!buff.deadly_calm.up
  if S.Bladestorm:IsCastable() and HR.CDsON() and (Player:BuffDown(S.MemoryofLucidDreams) and Player:BuffUp(S.TestofMightBuff) and Player:Rage() < 30 and Player:BuffDown(S.DeadlyCalmBuff)) then
    if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm 32"; end
  end
  -- execute,if=buff.memory_of_lucid_dreams.up|buff.deadly_calm.up|debuff.colossus_smash.up|buff.test_of_might.up
  if S.Execute:IsReady() and (Player:BuffUp(S.MemoryofLucidDreams) or Player:BuffUp(S.DeadlyCalmBuff) or Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
  -- slam,if=buff.crushing_assault.up&buff.memory_of_lucid_dreams.down
  if S.Slam:IsReady() and (Player:BuffUp(S.CrushingAssaultBuff) and Player:BuffDown(S.MemoryofLucidDreams)) then
    if HR.Cast(S.Slam, nil, nil, not Target:IsSpellInRange(S.Slam)) then return "slam"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
end

local function SingleTarget()
  -- rend,if=remains<=duration*0.3
  if S.Rend:IsReady() and (Target:DebuffRefreshable(S.RendDebuff)) then
      if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
  end
  -- deadly_calm
  if S.DeadlyCalm:IsCastable() then
    if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm"; end
  end
  -- skullsplitter,if=rage<60&buff.deadly_calm.down&buff.memory_of_lucid_dreams.down|rage<20
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 60 and Player:BuffDown(S.DeadlyCalmBuff) and Player:BuffDown(S.MemoryofLucidDreams) or Player:Rage() < 20) then
    if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
  end
  -- ravager,if=(cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))
  if S.Ravager:IsCastable() and HR.CDsON() and (S.ColossusSmash:CooldownRemains() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 2)) then
   if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager"; end
  end
  -- mortal_strike,if=dot.deep_wounds.remains<=duration*0.3&(spell_targets.whirlwind=1|!talent.cleave.enabled)
  if S.MortalStrike:IsReady() and (Target:DebuffRefreshable(S.DeepWoundsDebuff) and (EnemiesCount8y == 1 or not S.Cleave:IsAvailable())) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  -- cleave,if=spell_targets.whirlwind>2&dot.deep_wounds.remains<=duration*0.3
  if S.Cleave:IsReady() and (EnemiesCount8y > 2 and Target:DebuffRefreshable(S.DeepWoundsDebuff)) then
    if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
  end
  if (not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 50)) or (S.Massacre:IsAvailable() and (Target:TimeToX(35) > 10 or Target:TimeToDie() > 50)) then
    -- colossus_smash,if=!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>50)|talent.massacre.enabled&(target.time_to_pct_35>10|target.time_to_die>50)
    if S.ColossusSmash:IsCastable() then
      if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
    end
    -- warbreaker,if=!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>50)|talent.massacre.enabled&(target.time_to_pct_35>10|target.time_to_die>50)
    if S.Warbreaker:IsCastable() then
      if HR.Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "colossus_smash"; end
    end
  end
  -- execute,if=buff.sudden_death.react
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
  -- bladestorm,if=cooldown.mortal_strike.remains&debuff.colossus_smash.down&(!talent.deadly_calm.enabled|buff.deadly_calm.down)&rage<40
  if S.Bladestorm:IsReady() and HR.CDsON() and (not S.MortalStrike:CooldownUp() and Target:DebuffDown(S.ColossusSmashDebuff) and (not S.DeadlyCalm:IsAvailable() or Player:BuffDown(S.DeadlyCalmBuff)) and Player:Rage() < 40) then
    if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm"; end
  end
  -- mortal_strike,if=spell_targets.whirlwind=1|!talent.cleave.enabled
  if S.MortalStrike:IsReady() and (EnemiesCount8y == 1 or not S.Cleave:IsAvailable()) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  -- cleave,if=spell_targets.whirlwind>2
  if S.Cleave:IsReady() and (EnemiesCount8y > 2) then
    if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
  end
  -- whirlwind,if=(((buff.memory_of_lucid_dreams.up)|(debuff.colossus_smash.up)|(buff.deadly_calm.up))&talent.fervor_of_battle.enabled)|((buff.memory_of_lucid_dreams.up|rage>89)&debuff.colossus_smash.up&buff.test_of_might.down&!talent.fervor_of_battle.enabled)
  if S.Whirlwind:IsReady() and (((Player:BuffUp(S.MemoryofLucidDreams) or Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.DeadlyCalmBuff)) and S.FervorofBattle:IsAvailable()) or ((Player:BuffUp(S.MemoryofLucidDreams) or Player:Rage() > 89) and Target:DebuffUp(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff) and not S.FervorofBattle:IsAvailable())) then
    if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
  end
  -- slam,if=!talent.fervor_of_battle.enabled&(buff.memory_of_lucid_dreams.up|debuff.colossus_smash.up)
  if S.Slam:IsReady() and (not S.FervorofBattle:IsAvailable() and (Player:BuffUp(S.MemoryofLucidDreams) or Target:DebuffUp(S.ColossusSmashDebuff))) then
    if HR.Cast(S.Slam, nil, nil, not Target:IsSpellInRange(S.Slam)) then return "slam"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
  end
  -- whirlwind,if=talent.fervor_of_battle.enabled&(buff.test_of_might.up|debuff.colossus_smash.down&buff.test_of_might.down&rage>60)
  if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable() and (Player:BuffUp(S.TestofMightBuff) or Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff) and Player:Rage() > 80)) then
    if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
  end
  -- slam,if=!talent.fervor_of_battle.enabled
  if S.Slam:IsReady() and (not S.FervorofBattle:IsAvailable()) then
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
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion"; end
    end
    if CDsON() then
      -- arcane_torrent,if=cooldown.mortal_strike.remains>1.5&buff.memory_of_lucid_dreams.down&rage<50
      if S.ArcaneTorrent:IsCastable() and (S.MortalStrike:CooldownRemains() > 1.5 and Player:BuffUp(S.MemoryofLucidDreams) and Player:Rage() < 50) then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent"; end
      end
      if (Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.MemoryofLucidDreams) and not S.MortalStrike:CooldownUp()) then
        -- lights_judgment,if=debuff.colossus_smash.down&buff.memory_of_lucid_dreams.down&cooldown.mortal_strike.remains
        if S.LightsJudgment:IsCastable() then
          if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment"; end
        end
        -- bag_of_tricks,if=debuff.colossus_smash.down&buff.memory_of_lucid_dreams.down&cooldown.mortal_strike.remains
        if S.BagofTricks:IsCastable() then
          if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks"; end
        end
      end
      if Target:DebuffUp(S.ColossusSmashDebuff) then
        -- berserking,if=debuff.colossus_smash.up
        if S.Berserking:IsCastable() then
          if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking"; end
        end
        -- blood_fury,if=debuff.colossus_smash.up
        if S.BloodFury:IsCastable() then
          if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
        end
        -- fireblood,if=debuff.colossus_smash.up
        if S.Fireblood:IsCastable() then
          if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
        end
        -- ancestral_call,if=debuff.colossus_smash.up
        if S.AncestralCall:IsCastable() then
          if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
        end
      end
    end
    if (Settings.Commons.UseTrinkets) then
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- avatar
    if S.Avatar:IsCastable() and HR.CDsON() then
      if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar"; end
    end
    -- sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>10|cooldown.colossus_smash.remains>8)
    if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1 and (S.Bladestorm:CooldownRemains() > 10 or S.ColossusSmash:CooldownRemains() > 8)) then
      if HR.Cast(S.SweepingStrikes, nil, nil, not Target:IsSpellInRange(S.SweepingStrikes)) then return "sweeping_strikes"; end
    end
    -- run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
    if ((S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20) then
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

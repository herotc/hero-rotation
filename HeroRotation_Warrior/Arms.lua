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

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Arms
local I = Item.Warrior.Arms
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

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
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastable() then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    -- memory_of_lucid_dreams
    if S.MemoryofLucidDreams:IsCastable() then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    -- guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastable() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
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
  if (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffUp(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemains() > 10)) then
    -- colossus_smash,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
    if S.ColossusSmash:IsCastable() then
      if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
    end
    -- warbreaker,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
    if S.Warbreaker:IsCastable() then
      if HR.Cast(S.Warbreaker, nil, nil, not Target:IsSpellInRange(S.Warbreaker)) then return "warbreaker"; end
    end
  end
  -- mortal_strike,if=dot.deep_wounds.remains<=duration*0.3&(spell_targets.whirlwind=1|!spell_targets.whirlwind>1&!talent.cleave.enabled)
  if S.MortalStrike:IsCastable() and (Target:DebuffRefreshable(S.DeepWoundsDebuff) and (EnemiesCount8y == 1 or (not EnemiesCount8y > 1) and not S.Cleave:IsAvailable())) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  -- cleave,if=(spell_targets.whirlwind>2&dot.deep_wounds.remains<=duration*0.3)|(spell_targets.whirlwind>3)
  if S.Cleave:IsCastable() and ((EnemiesCount8y > 2 and Target:DebuffRefreshable(S.DeepWoundsDebuff)) or EnemiesCount8y > 3)  then
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
  if S.MortalStrike:IsCastable() and (Target:DebuffRefreshable(S.DeepWoundsDebuff) and (EnemiesCount8y == 1 or not S.Cleave:IsAvailable())) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  -- cleave,if=spell_targets.whirlwind>2&dot.deep_wounds.remains<=duration*0.3
  if S.Cleave:IsCastable() and (EnemiesCount8y > 2 and Target:DebuffRefreshable(S.DeepWoundsDebuff)) then
    if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
  end
  if (not Spell:EssenceEnabled(AE.CondensedLifeForce) and not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 50) or Spell:EssenceEnabled(AE.CondensedLifeForce) and not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 80) or S.Massacre:IsAvailable() and (Target:TimeToX(35) > 10 or Target:TimeToDie() > 50)) then
    -- colossus_smash,if=!essence.condensed_lifeforce.enabled&!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>50)|essence.condensed_lifeforce.enabled&!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>80)|talent.massacre.enabled&(target.time_to_pct_35>10|target.time_to_die>50)
    if S.ColossusSmash:IsCastable() then
      if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
    end
    -- warbreaker,if=!essence.condensed_lifeforce.enabled&!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>50)|essence.condensed_lifeforce.enabled&!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>80)|talent.massacre.enabled&(target.time_to_pct_35>10|target.time_to_die>50)
    if S.Warbreaker:IsCastable() then
      if HR.Cast(S.Warbreaker, nil, nil, not Target:IsSpellInRange(S.Warbreaker)) then return "colossus_smash"; end
    end
  end
  -- execute,if=buff.sudden_death.react
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
  -- bladestorm,if=cooldown.mortal_strike.remains&debuff.colossus_smash.down&(!talent.deadly_calm.enabled|buff.deadly_calm.down)&((debuff.colossus_smash.up&!azerite.test_of_might.enabled)|buff.test_of_might.up)&buff.memory_of_lucid_dreams.down&rage<40
  if S.Bladestorm:IsReady() and HR.CDsON() and (not S.MortalStrike:CooldownUp() and Target:DebuffDown(S.ColossusSmashDebuff) and (not S.DeadlyCalm:IsAvailable() or Player:BuffDown(S.DeadlyCalmBuff)) and ((Target:DebuffUp(S.ColossusSmashDebuff) and not S.TestofMight:AzeriteEnabled()) or Player:BuffUp(S.TestofMight)) and Player:BuffDown(S.MemoryofLucidDreams) and Player:Rage() < 40) then
    if HR.Cast(S.Bladestorm, nil, nil, not Target:IsSpellInRange(S.Bladestorm)) then return "bladestorm"; end
  end
  -- mortal_strike,if=spell_targets.whirlwind=1|!talent.cleave.enabled
  if S.MortalStrike:IsReady() and (EnemiesCount8y == 1 or not S.Cleave:IsAvailable()) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  -- cleave,if=spell_targets.whirlwind>2
  if S.Cleave:IsCastable() and (EnemiesCount8y > 2) then
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
  if S.Whirlwind:IsCastable() and (S.FervorofBattle:IsAvailable() and (Player:BuffUp(S.TestofMight) or Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMight) and Player:Rage() > 80)) then
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
    -- potion,if=target.health.pct<21&buff.memory_of_lucid_dreams.up|!essence.memory_of_lucid_dreams.major
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Target:HealthPercentage() < 21 and Player:BuffUp(S.MemoryofLucidDreams) or not S.MemoryofLucidDreams:IsAvailable()) then
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
      if (Player:BuffRemains(S.MemoryofLucidDreams) < 5 or (not S.MemoryofLucidDreams:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff))) then
        -- berserking,if=buff.memory_of_lucid_dreams.up|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
        if S.Berserking:IsCastable() then
          if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then reutrn "berserking"; end
        end
        -- blood_fury,if=buff.memory_of_lucid_dreams.remains<5|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
        if S.BloodFury:IsCastable() then
          if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
        end
        -- fireblood,if=buff.memory_of_lucid_dreams.remains<5|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
        if S.Fireblood:IsCastable() then
          if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
        end
        -- ancestral_call,if=buff.memory_of_lucid_dreams.remains<5|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
        if S.AncestralCall:IsCastable() then
          if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
        end
      end
    end
    if (Settings.Commons.UseTrinkets) then
      -- use_item,name=ashvanes_razor_coral,if=!debuff.razor_coral_debuff.up|(target.health.pct<20.1&buff.memory_of_lucid_dreams.up&cooldown.memory_of_lucid_dreams.remains<117)|(target.health.pct<30.1&debuff.conductive_ink_debuff.up&!essence.memory_of_lucid_dreams.major)|(!debuff.conductive_ink_debuff.up&!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)|target.time_to_die<30
      if I.AshvanesRazorCoral:IsEquipped() and I.AshvanesRazorCoral:IsReady() and (Target:DebuffDown(S.RazorCoralDebuff) or (Target:HealthPercentage() <= 20 and Player:BuffUp(S.MemoryofLucidDreams) and S.MemoryofLucidDreams:CooldownRemains() < 117) or (Target:HealthPercentage() <= 30 and Target:DebuffUp(S.ConductiveInkDebuff) and not S.MemoryofLucidDreams:IsAvailable()) or (Target:DebuffDown(S.ConductiveInkDebuff) and not S.MemoryofLucidDreams:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff)) or Target:TimeToDie() < 30) then
        if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(40)) then return "ashvanes_razor_coral"; end
      end
      -- use_item,name=azsharas_font_of_power,if=target.time_to_die<70&(cooldown.colossus_smash.remains<12|(talent.warbreaker.enabled&cooldown.warbreaker.remains<12))|!debuff.colossus_smash.up&!buff.test_of_might.up&!buff.memory_of_lucid_dreams.up&target.time_to_die>150
      if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and (Target:TimeToDie() < 70 and (S.ColossusSmash:CooldownRemains() < 12 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 12)) or Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff) and Player:BuffDown(S.MemoryofLucidDreams) and Target:TimeToDie() > 150) then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power"; end
      end
      -- use_item,name=grongs_primal_rage,if=equipped.grongs_primal_rage&!debuff.colossus_smash.up&!buff.test_of_might.up
      if I.GrongsPrimalRage:IsEquipped() and I.GrongsPrimalRage:IsReady() and (Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff)) then
        if HR.Cast(I.GrongsPrimalRage, nil, Settings.Commons.TrinketDisplayStyle) then return "grongs_primal_rage"; end
      end
      -- pocketsized_computation_device,if=!debuff.colossus_smash.up&!buff.test_of_might.up&!buff.memory_of_lucid_dreams.up
      if Everyone.CyclotronicBlastReady() and (Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff) and Player:BuffDown(S.MemoryofLucidDreams)) then
        if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(40)) then return "pocketsized_computation_device"; end
      end
      -- use_items
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- avatar,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>45)
    if S.Avatar:IsCastable() and HR.CDsON() and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffUp(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemains() > 45)) then
      if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar"; end
    end
    -- sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>10|cooldown.colossus_smash.remains>8|azerite.test_of_might.enabled)
    if S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1 and (S.Bladestorm:CooldownRemains() > 10 or S.ColossusSmash:CooldownRemains() > 8 or S.TestofMight:AzeriteEnabled())) then
      if HR.Cast(S.SweepingStrikes, nil, nil, not Target:IsSpellInRange(S.SweepingStrikes)) then return "sweeping_strikes"; end
    end
    -- blood_of_the_enemy,if=buff.test_of_might.up|(debuff.colossus_smash.up&!azerite.test_of_might.enabled)
    if S.BloodoftheEnemy:IsCastable() and (Player:BuffUp(S.TestofMightBuff) or (Target:DebuffUp(S.ColossusSmashDebuff) and not S.TestofMight:AzeriteEnabled())) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(12)) then return "blood_of_the_enemy"; end
    end
    if (Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff)) then
      -- purifying_blast,if=!debuff.colossus_smash.up&!buff.test_of_might.up
      if S.PurifyingBlast:IsCastable() then
        if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "purifying_blast"; end
      end
      -- ripple_in_space,if=!debuff.colossus_smash.up&!buff.test_of_might.up
      if S.RippleInSpace:IsCastable() then
        if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
      end
      -- worldvein_resonance,if=!debuff.colossus_smash.up&!buff.test_of_might.up
      if S.WorldveinResonance:IsCastable() then 
        if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
      end
      -- focused_azerite_beam,if=!debuff.colossus_smash.up&!buff.test_of_might.up
      if S.FocusedAzeriteBeam:IsCastable() then
        if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
      end
      -- reaping_flames,if=!debuff.colossus_smash.up&!buff.test_of_might.up
      if (true) then
        local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
      end
      -- concentrated_flame,if=!debuff.colossus_smash.up&!buff.test_of_might.up&dot.concentrated_flame_burn.remains=0
      if S.ConcentratedFlame:IsCastable() and (Target:DebuffDown(S.ConcentratedFlameBurn)) then
        if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.ConcentratedFlame)) then return "concentrated_flame"; end
      end
    end
    -- the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force"; end
    end
    -- guardian_of_azeroth,if=cooldown.colossus_smash.remains<10
    if S.GuardianofAzeroth:IsCastable() and (S.ColossusSmash:CooldownRemains() < 10) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    -- memory_of_lucid_dreams,if=!talent.warbreaker.enabled&cooldown.colossus_smash.remains<gcd&(target.time_to_die>150|target.health.pct<20)
    if S.MemoryofLucidDreams:IsCastable() and (not S.Warbreaker:IsAvailable() and S.ColossusSmash:CooldownRemains() < Player:GCD() and (Target:TimeToDie() > 150 or Target:HealthPercentage() < 20)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    -- memory_of_lucid_dreams,if=talent.warbreaker.enabled&cooldown.warbreaker.remains<gcd&(target.time_to_die>150|target.health.pct<20)
    if S.MemoryofLucidDreams:IsCastable() and (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < Player:GCD() and (Target:TimeToDie() > 150 or Target:HealthPercentage() < 20)) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    -- run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
    if ((S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20) then
      local ShouldReturn = Execute(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(71, APL, Init)

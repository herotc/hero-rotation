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
local Enemies8y, Enemies20y
local EnemiesCount8, EnemiesCount20

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

  end
end

local function SingleTarget()
  --actions.single_target=rend,if=remains<=duration*0.3
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Target:DebuffDuration(S.RendDebuff) * 0.3) then
      if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
  end
  --actions.single_target+=/deadly_calm
  if S.DeadlyCalm:IsCastable() then
    if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm"; end
  end
  --actions.single_target+=/skullsplitter,if=rage<60&buff.deadly_calm.down&buff.memory_of_lucid_dreams.down|rage<20
  if S.Skullsplitter:IsCastable() and Player:Rage() < 60 and Player:BuffDown(S.DeadlyCalmBuff) and (Player:BuffDown(S.MemoryofLucidDreams) or Player:Rage() < 20 ) then
    if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
  end
  --actions.single_target+=/ravager,if=(cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))
  if S.Ravager:IsCastable(40) and HR.CDsON() and (S.ColossusSmash:CooldownRemains() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 2)) then
   if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager) then return "ravager"; end
  end
  --actions.single_target+=/mortal_strike,if=dot.deep_wounds.remains<=duration*0.3&(spell_targets.whirlwind=1|!talent.cleave.enabled)
  if S.MortalStrike:IsCastable() and Target:DebuffRemains(S.DeepWoundsDebuff) <= S.DeepWoundsDebuff:BaseDuration() * 0.3 and (EnemiesCount8 == 1 or not S.Cleave:IsAvailable()) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  --actions.single_target+=/cleave,if=spell_targets.whirlwind>2&dot.deep_wounds.remains<=duration*0.3
  if S.Cleave:IsCastable() and EnemiesCount8 > 2 and Target:DebuffRemains(S.DeepWoundsDebuff) <= S.DeepWoundsDebuff:BaseDuration() * 0.3 then
    if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
  end
  --actions.single_target+=/colossus_smash,if=!essence.condensed_lifeforce.enabled&!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>50)|essence.condensed_lifeforce.enabled&!talent.massacre.enabled&(target.time_to_pct_20>10|target.time_to_die>80)|talent.massacre.enabled&(target.time_to_pct_35>10|target.time_to_die>50)
  if S.ColossusSmash:IsCastable() and HR.CDsON() and (not Spell:EssenceEnabled(AE.CondensedLifeForce) and not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 50) or Spell:EssenceEnabled(AE.CondensedLifeForce) and not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 80) or S.Massacre:IsAvailable() and (Target:TimeToX(35) > 10 or Target:TimeToDie() > 50)) then
    if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
  end
  if S.Warbreaker:IsCastable() and HR.CDsON() and (not Spell:EssenceEnabled(AE.CondensedLifeForce) and not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 50) or Spell:EssenceEnabled(AE.CondensedLifeForce) and not S.Massacre:IsAvailable() and (Target:TimeToX(20) > 10 or Target:TimeToDie() > 80) or S.Massacre:IsAvailable() and (Target:TimeToX(35) > 10 or Target:TimeToDie() > 50)) then
    if HR.Cast(S.Warbreaker, nil, nil, not Target:IsSpellInRange(S.Warbreaker)) then return "colossus_smash"; end
  end
  --actions.single_target+=/execute,if=buff.sudden_death.react
  if S.Execute:IsCastable() and Player:BuffUp(S.SuddenDeathBuff) then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
  --actions.single_target+=/bladestorm,if=cooldown.mortal_strike.remains&debuff.colossus_smash.down&(!talent.deadly_calm.enabled|buff.deadly_calm.down)&((debuff.colossus_smash.up&!azerite.test_of_might.enabled)|buff.test_of_might.up)&buff.memory_of_lucid_dreams.down&rage<40
  if S.Bladestorm:IsReady() and HR.CDsON() and (not S.MortalStrike:CooldownRemains() and Target:DebuffDown(S.ColossusSmashDebuff) and (not S.DeadlyCalm:IsAvailable() or Player:BuffDown(S.DeadlyCalmBuff)) and ((Target:DebuffUp(S.ColossusSmashDebuff) and S.TestofMight:AzeriteRank() >= 1 ) or Player:BuffUp(S.TestofMight)) and Player:BuffDown(S.MemoryofLucidDreams) and Player:Rage() < 40) then -- this line still being a dick
    if HR.Cast(S.Bladestorm, nil, nil, not Target:IsSpellInRange(S.Bladestorm)) then return "bladestorm"; end
  end
  --actions.single_target+=/mortal_strike,if=spell_targets.whirlwind=1|!talent.cleave.enabled
  if S.MortalStrike:IsReady() and (EnemiesCount8 == 1 or not S.Cleave:IsAvailable()) then
    if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
  end
  --actions.single_target+=/cleave,if=spell_targets.whirlwind>2
  if S.Cleave:IsCastable() and EnemiesCount8 > 2 then
    if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
  end
  --actions.single_target+=/whirlwind,if=(((buff.memory_of_lucid_dreams.up)|(debuff.colossus_smash.up)|(buff.deadly_calm.up))&talent.fervor_of_battle.enabled)|((buff.memory_of_lucid_dreams.up|rage>89)&debuff.colossus_smash.up&buff.test_of_might.down&!talent.fervor_of_battle.enabled)
  if S.Whirlwind:IsReady() and ((((Player:BuffUp(S.MemoryofLucidDreams)) or (Target:DebuffUp(S.ColossusSmashDebuff)) or (Player:BuffUp(S.DeadlyCalmBuff))) and S.FervorofBattle:IsAvailable()) or ((Player:BuffUp(S.MemoryofLucidDreams) or Player:Rage() > 89) and Target:DebuffUp(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMightBuff) and not S.FervorofBattle:IsAvailable())) then
    if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
  end
  --actions.single_target+=/slam,if=!talent.fervor_of_battle.enabled&(buff.memory_of_lucid_dreams.up|debuff.colossus_smash.up)
  if S.Slam:IsReady() and (not S.FervorofBattle:IsAvailable() and (Player:BuffUp(S.MemoryofLucidDreams) or Target:DebuffUp(S.ColossusSmashDebuff))) then
    if HR.Cast(S.Slam, nil, nil, not Target:IsSpellInRange(S.Slam)) then return "slam"; end
  end
  --actions.single_target+=/overpower
  if S.Overpower:IsCastable() then
    if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
  end
  --actions.single_target+=/whirlwind,if=talent.fervor_of_battle.enabled&(buff.test_of_might.up|debuff.colossus_smash.down&buff.test_of_might.down&rage>60)
  if S.Whirlwind:IsCastable() and S.FervorofBattle:IsAvailable()  and (Player:BuffUp(S.TestofMight) or (Target:DebuffDown(S.ColossusSmashDebuff) and Player:BuffDown(S.TestofMight) and Player:Rage() > 80)) then
    if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
  end
  --actions.single_target+=/slam,if=!talent.fervor_of_battle.enabled
  if S.Slam:IsReady() and not S.FervorofBattle:IsAvailable() then
    if HR.Cast(S.Slam, nil, nil, not Target:IsSpellInRange(S.Slam)) then return "slam"; end
  end

end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    Enemies12y = Player:GetEnemiesInMeleeRange(12) -- Dragon Roar
    EnemiesCount8 = #Enemies8y
    EnemiesCount12 = #Enemies12y
  else
    EnemiesCount8 = 1
    EnemiesCount12 = 1
  end

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
  --actions=charge
  if S.Charge:IsCastable() and (not Target:IsInMeleeRange(5)) then
    if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge, nil, not Target:IsSpellInRange(S.Charge)) then return "charge"; end
  end
  --actions+=/auto_attack
  --actions+=/blood_fury,if=buff.memory_of_lucid_dreams.remains<5|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
  --actions+=/berserking,if=buff.memory_of_lucid_dreams.up|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
  --actions+=/arcane_torrent,if=cooldown.mortal_strike.remains>1.5&buff.memory_of_lucid_dreams.down&rage<50
  --actions+=/lights_judgment,if=debuff.colossus_smash.down&buff.memory_of_lucid_dreams.down&cooldown.mortal_strike.remains
  --actions+=/fireblood,if=buff.memory_of_lucid_dreams.remains<5|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
  --actions+=/ancestral_call,if=buff.memory_of_lucid_dreams.remains<5|(!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)
 if S.AncestralCall:IsCastable() and HR.CDsON() and (Player:BuffRemains(S.MemoryofLucidDreams) < 5 or (not S.MemoryofLucidDreams:IsAvailable() and Target:DebuffUp(S.ColossusSmash))) then
   if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
 end
  --actions+=/bag_of_tricks,if=debuff.colossus_smash.down&buff.memory_of_lucid_dreams.down&cooldown.mortal_strike.remains
  --actions+=/use_item,name=ashvanes_razor_coral,if=!debuff.razor_coral_debuff.up|(target.health.pct<20.1&buff.memory_of_lucid_dreams.up&cooldown.memory_of_lucid_dreams.remains<117)|(target.health.pct<30.1&debuff.conductive_ink_debuff.up&!essence.memory_of_lucid_dreams.major)|(!debuff.conductive_ink_debuff.up&!essence.memory_of_lucid_dreams.major&debuff.colossus_smash.up)|target.time_to_die<30
  --actions+=/avatar,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>45)
  if S.Avatar:IsCastable() and HR.CDsON() and S.Avatar:IsAvailable() and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffUp(S.MemoryofLucidDreams) or (S.MemoryofLucidDreams:CooldownRemains()) < 45)) then
    if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar"; end
  end
  --actions+=/sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>10|cooldown.colossus_smash.remains>8|azerite.test_of_might.enabled)
  --actions+=/blood_of_the_enemy,if=buff.test_of_might.up|(debuff.colossus_smash.up&!azerite.test_of_might.enabled)
  --actions+=/purifying_blast,if=!debuff.colossus_smash.up&!buff.test_of_might.up
  --actions+=/ripple_in_space,if=!debuff.colossus_smash.up&!buff.test_of_might.up
  --actions+=/worldvein_resonance,if=!debuff.colossus_smash.up&!buff.test_of_might.up
  --actions+=/focused_azerite_beam,if=!debuff.colossus_smash.up&!buff.test_of_might.up
  --actions+=/reaping_flames,if=!debuff.colossus_smash.up&!buff.test_of_might.up
  --actions+=/concentrated_flame,if=!debuff.colossus_smash.up&!buff.test_of_might.up&dot.concentrated_flame_burn.remains=0
  --actions+=/the_unbound_force,if=buff.reckless_force.up
  --actions+=/guardian_of_azeroth,if=cooldown.colossus_smash.remains<10
  --actions+=/memory_of_lucid_dreams,if=!talent.warbreaker.enabled&cooldown.colossus_smash.remains<gcd&(target.time_to_die>150|target.health.pct<20)
  --actions+=/memory_of_lucid_dreams,if=talent.warbreaker.enabled&cooldown.warbreaker.remains<gcd&(target.time_to_die>150|target.health.pct<20)

    --actions+=/run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
    if (S.Massacre:IsAvailable() and Target:HealthPercentage() <= 35) or Target:HealthPercentage() <= 20 then
      --actions.execute=rend,if=remains<=duration*0.3
      if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Target:DebuffDuration(S.RendDebuff) * 0.3) then
          if HR.Cast(S.Rend, nil, nil, not Target:IsSpellInRange(S.Rend)) then return "rend"; end
      end
      --actions.execute+=/deadly_calm
      if S.DeadlyCalm:IsCastable() then
        if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm"; end
      end
      --actions.execute+=/skullsplitter,if=rage<52&buff.memory_of_lucid_dreams.down|rage<20
      if S.Skullsplitter:IsCastable() and Player:Rage() < 52 and (Player:BuffDown(S.MemoryofLucidDreams) or Player:Rage() < 20 ) then
        if HR.Cast(S.Skullsplitter, nil, nil, not Target:IsSpellInRange(S.Skullsplitter)) then return "skullsplitter"; end
      end
      --actions.execute+=/ravager,,if=cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2)
      if S.Ravager:IsCastable(40) and HR.CDsON() and (S.ColossusSmash:CooldownRemains() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 2)) then
       if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager) then return "ravager"; end
      end
      --actions.execute+=/colossus_smash,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
      if S.ColossusSmash:IsCastable() and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffUp(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemains() > 10)) then
        if HR.Cast(S.ColossusSmash, nil, nil, not Target:IsSpellInRange(S.ColossusSmash)) then return "colossus_smash"; end
      end
      --actions.execute+=/warbreaker,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
      if S.Warbreaker:IsCastable() and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffUp(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemains() > 10)) then
        if HR.Cast(S.Warbreaker, nil, nil, not Target:IsSpellInRange(S.Warbreaker)) then return "warbreaker"; end
      end
      --actions.execute+=/mortal_strike,if=dot.deep_wounds.remains<=duration*0.3&(spell_targets.whirlwind=1|!spell_targets.whirlwind>1&!talent.cleave.enabled)
      if S.MortalStrike:IsCastable() and Target:DebuffRemains(S.DeepWoundsDebuff) <= S.DeepWoundsDebuff:BaseDuration() * 0.3 and (EnemiesCount8 == 1 or (not EnemiesCount8 == 1 and not S.Cleave:IsAvailable())) then
        if HR.Cast(S.MortalStrike, nil, nil, not Target:IsSpellInRange(S.MortalStrike)) then return "mortal_strike"; end
      end
      --actions.execute+=/cleave,if=(spell_targets.whirlwind>2&dot.deep_wounds.remains<=duration*0.3)|(spell_targets.whirlwind>3)
      if S.Cleave:IsCastable() and ((EnemiesCount8 > 2 and Target:DebuffRemains(S.DeepWoundsDebuff) <= S.DeepWoundsDebuff:BaseDuration() * 0.3) or EnemiesCount8 > 3)  then
        if HR.Cast(S.Cleave, nil, nil, not Target:IsSpellInRange(S.Cleave)) then return "cleave"; end
      end
      --actions.execute+=/bladestorm,if=!buff.memory_of_lucid_dreams.up&buff.test_of_might.up&rage<30&!buff.deadly_calm.up
      if S.Bladestorm:IsCastable() and HR.CDsON() and (Player:BuffDown(S.MemoryofLucidDreams) and Player:BuffUp(S.TestofMightBuff) and Player:Rage() < 30 and Player:BuffDown(S.DeadlyCalmBuff)) then
        if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, 8) then return "bladestorm 32"; end
      end
      --actions.execute+=/execute,if=buff.memory_of_lucid_dreams.up|buff.deadly_calm.up|debuff.colossus_smash.up|buff.test_of_might.up
      if S.Execute:IsReady() and (Player:BuffUp(S.MemoryofLucidDreams) or Player:BuffUp(S.DeadlyCalmBuff) or Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
        if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
      end
      --actions.execute+=/slam,if=buff.crushing_assault.up&buff.memory_of_lucid_dreams.down
      if S.Slam:IsReady() and (Player:BuffUp(S.CrushingAssaultBuff) and Player:BuffDown(S.MemoryofLucidDreams)) then
        if HR.Cast(S.Slam, nil, nil, not Target:IsSpellInRange(S.Slam)) then return "slam"; end
      end
      --actions.execute+=/overpower
      if S.Overpower:IsCastable() then
        if HR.Cast(S.Overpower, nil, nil, not Target:IsSpellInRange(S.Overpower)) then return "overpower"; end
      end
      --actions.execute+=/execute
      if S.Execute:IsCastable() then
        if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
      end
    end
        --actions+=/run_action_list,name=single_target
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(71, APL, Init)

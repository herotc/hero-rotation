--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua

  --- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local DeathKnight = AR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Unholy = {
    -- Racials
  ArcaneTorrent                 = Spell(50613),
  Berserking                    = Spell(26297),
  BloodFury                     = Spell(20572),
  GiftoftheNaaru                = Spell(59547),
    -- Artifact
  Apocalypse                    = Spell(220143),
  --Abilities
  ArmyOfDead                    = Spell(42650),
  ChainsOfIce                   = Spell(45524),
  ScourgeStrike                 = Spell(55090),
  DarkTransformation            = Spell(63560),
  DeathAndDecay                 = Spell(43265),
  DeathCoil                     = Spell(47541),
  DeathStrike                   = Spell(49958),
  FesteringStrike               = Spell(85948),
  Outbreak                      = Spell(77575),
  SummonGargoyle                = Spell(49206),
  SummonPet                     = Spell(46584),
     --Talents
  BlightedRuneWeapon            = Spell(194918),
  Epidemic                      = Spell(207317),
  Castigator                    = Spell(207305),
  ClawingShadows                = Spell(207311),
  Necrosis                      = Spell(207346),
  ShadowInfusion                = Spell(198943),
  DarkArbiter                   = Spell(207349),
  Defile                        = Spell(152280),
  SoulReaper                    = Spell(130736),
  --Buffs/Procs
  SuddenDoom                    = Spell(81340),
  UnholyStrength                = Spell(53365),
  NecrosisBuff                  = Spell(216974),
  DeathAndDecayBuff             = Spell(188290),
  --Debuffs
  SoulReaperDebuff              = Spell(130736),
  FesteringWounds               = Spell(194310), --max 8 stacks
  VirulentPlagueDebuff          = Spell(191587), -- 13s debuff from Outbreak
  --Defensives
  AntiMagicShell                = Spell(48707),
  IcebornFortitute              = Spell(48792),
   -- Utility
  ControlUndead                 = Spell(45524),
  DeathGrip                     = Spell(49576),
  MindFreeze                    = Spell(47528),
  PathOfFrost                   = Spell(3714),
  WraithWalk                    = Spell(212552),
  --Legendaries Buffs/SpellIds 
  ColdHeartBuff                 = Spell(235599),
  InstructorsFourthLesson       = Spell(208713),
  KiljaedensBurningWish         = Spell(144259),
  --DarkArbiter HiddenAura
  DarkArbiterActive             = Spell(212412),
  -- Misc
  PoolForArmy                   = Spell(9999000010)
  
  
  };
  local S = Spell.DeathKnight.Unholy;
  --Items
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Unholy = {
    --Legendaries WIP
  ConvergenceofFates            = Item(140806, {13, 14}),
  InstructorsFourthLesson       = Item(132448, {9}),
  Taktheritrixs                 = Item(137075, {3}),
  ColdHearth                    = Item(151796, {5}),
  
  
  };
  local I = Item.DeathKnight.Unholy;
 --Rotation Var


  --GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DeathKnight.Commons,
    Unholy = AR.GUISettings.APL.DeathKnight.Unholy
  };
  

  --- ===== APL =====
  --- ===============
 local function Generic() 
 if S.Outbreak:IsUsable() and not Target:Debuff(S.VirulentPlagueDebuff) or Target:DebuffRemains(S.VirulentPlagueDebuff) < Player:GCD()*1.5 then
  if AR.Cast(S.Outbreak) then return ""; end
  end
  --[[actions.generic=outbreak,if=runic_power.deficit<30&((!cooldown.dark_arbiter.remains|cooldown.dark_arbiter.remains<gcd)&dot.virulent_plague.remains<6
  if S.Outbreak:IsUsable() and  ((S.DarkArbiter:IsCastable() or S.DarkArbiter:CooldownRemains() < Player:GCD()) and Target:DebuffRemains(S.VirulentPlagueDebuff) < 6) then
    if AR.Cast(S.Outbreak) then return ""; end
  end]]
 --actions.generic=dark_arbiter,if=!equipped.137075&runic_power.deficit<30
  if AR.CDsON() and S.DarkArbiter:IsCastable() and not I.Taktheritrixs:IsEquipped() and Player:RunicPowerDeficit() < 30 then
    if AR.Cast(S.DarkArbiter, Settings.Unholy.OffGCDasOffGCD.DarkArbiter) then return ; end
  end
 --generic apocalypse if=equipped.137075&debuff.festering_wound.stack>=6&talent.dark_arbiter.
  if S.Apocalypse:IsCastable() and I.Taktheritrixs:IsEquipped() and Target:DebuffStack(S.FesteringWounds) >= 6 and S.DarkArbiter:IsAvailable() then
    if AR.Cast(S.Apocalypse) then return ""; end
  end
 --actions.generic+=/dark_arbiter,if=equipped.137075&runic_power.deficit<30&cooldown.dark_transformation.remains<2
  if AR.CDsON() and S.DarkArbiter:IsCastable() and I.Taktheritrixs:IsEquipped() and Player:RunicPowerDeficit() < 30 and S.DarkTransformation:Cooldown() < 2 then
    if AR.Cast(S.DarkArbiter, Settings.Unholy.OffGCDasOffGCD.DarkArbiter) then return "" ; end
  end
  --actions.generic+=/summon_gargoyle,if=!equipped.137075,if=rune<=3
  if AR.CDsON() and S.SummonGargoyle:IsCastable() and not S.DarkArbiter:IsAvailable() and not I.Taktheritrixs:IsEquipped() and Player:Runes() <= 3 then
    if AR.Cast(S.SummonGargoyle, Settings.Unholy.OffGCDasOffGCD.SummonGargoyle) then return "" ; end
  end
  --actions.generic+=/summon_gargoyle,if=equipped.137075&cooldown.dark_transformation.remains<10&rune<=3
  if AR.CDsON() and S.SummonGargoyle:IsCastable() and not S.DarkArbiter:IsAvailable() and I.Taktheritrixs:IsEquipped() and S.DarkTransformation:Cooldown() < 10 and Player:Runes() <= 3 then
    if AR.Cast(S.SummonGargoyle, Settings.Unholy.OffGCDasOffGCD.SummonGargoyle) then return "" ; end
  end
 -- t20 gameplay
  if AR.CDsON() and S.ArmyOfDead:IsCastable() and Player:Runes() >= 3 then
    if AR.Cast(S.ArmyOfDead, Settings.Unholy.OffGCDasOffGCD.ArmyOfDead) then return ""; end
  elseif AR.CDsON() and (S.ArmyOfDead:IsCastable() or S.ArmyOfDead:Cooldown() <= 5) and  S.DarkArbiter:TimeSinceLastCast() > 20 and Player:Runes() <= 3 then
    if AR.Cast(S.PoolForArmy) then return "Pool For Army"; end
  end
  --actions.generic+=/chains_of_ice,if=buff.unholy_strength.up&buff.cold_heart.stack>19
  if S.ChainsOfIce:IsCastable() and Player:Buff(S.UnholyStrength) and Player:BuffStack(S.ColdHeartBuff) > 19 then
    if AR.Cast(S.ChainsOfIce) then return ""; end
  end
  --actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<4 -- Player:Rune() > 1 (SR cost)
  if S.SoulReaper:IsAvailable() and S.SoulReaper:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 6 and S.Apocalypse:Cooldown() < 4 then
    if AR.Cast(S.SoulReaper) then return ""; end
  end
  --actions.generic+=/apocalypse,if=debuff.festering_wound.stack>=6
  if S.Apocalypse:IsCastable() and Target:DebuffStack(S.FesteringWounds) >=6 then
    if AR.Cast(S.Apocalypse) then return ""; end
  end
  --actions.generic+=/death_coil,if=runic_power.deficit<10
  if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 10 then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/death_coil,if=!talent.dark_arbiter.enabled&buff.sudden_doom.up&!buff.necrosis.up&rune<=3
  if S.DeathCoil:IsUsable() and not S.DarkArbiter:IsAvailable() and Player:Buff(S.SuddenDoom) and not Player:Buff(S.NecrosisBuff) and Player:Runes() <= 3 then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/death_coil,if=talent.dark_arbiter.enabled&buff.sudden_doom.up&cooldown.dark_arbiter.remains>5&rune<=3
  if S.DeathCoil:IsUsable() and S.DarkArbiter:IsAvailable() and Player:Buff(S.SuddenDoom) and S.DarkArbiter:Cooldown() > 5 and Player:Runes() <= 3 then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
  if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 6 and S.Apocalypse:Cooldown() <= 6 then
    if AR.Cast(S.FesteringStrike) then return ""; end
  end
  --actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=3
  if S.SoulReaper:IsAvailable() and S.SoulReaper:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 3 then
    if AR.Cast(S.SoulReaper) then return ""; end
  end
  --actions.generic+=/festering_strike,if=debuff.soul_reaper.up&!debuff.festering_wound.up
  if S.FesteringStrike:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and not Target:Debuff(S.FesteringWounds) then
    if AR.Cast(S.FesteringStrike) then return ""; end
  end
  --actions.generic+=/scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
  if S.ScourgeStrike:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and Target:DebuffStack(S.FesteringWounds) >= 1 then
    if AR.Cast(S.ScourgeStrike) then return ""; end
  end
  --actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
  if S.ClawingShadows:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and Target:DebuffStack(S.FesteringWounds) >= 1 then
    if AR.Cast(S.ClawingShadows) then return ""; end
  end
  --actions.generic+=/defile
  if S.Defile:IsAvailable() and S.Defile:IsCastable() then
    if AR.Cast(S.Defile) then return ""; end
  end
  --              --
  --    AOE APL   --
  if AR.AoEON() and Cache.EnemiesCount[8] >= 2 then
  --actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
  if S.DeathAndDecay:IsCastable() and Cache.EnemiesCount[8] >= 2 then
    if AR.Cast(S.DeathAndDecay) then return ""; end
  end
  --actions.aoe+=/epidemic,if=spell_targets.epidemic>4
  if S.Epidemic:IsCastable() and Cache.EnemiesCount[8] > 4 then
    if AR.Cast(S.Epidemic) then return ""; end
  end 
  --actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
  if S.ScourgeStrike:IsCastable() and Cache.EnemiesCount[8] >= 2 and Player:Buff(S.DeathAndDecayBuff) then
    if AR.Cast(S.ScourgeStrike) then return ""; end
  end 
  --actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
  if S.ClawingShadows:IsCastable() and Cache.EnemiesCount[8] >= 2 and Player:Buff(S.DeathAndDecayBuff) then
    if AR.Cast(S.ClawingShadows) then return ""; end
  end
  --actions.aoe+=/epidemic,if=spell_targets.epidemic>2
  if S.Epidemic:IsCastable() and Cache.EnemiesCount[8] > 2 then
    if AR.Cast(S.Epidemic) then return ""; end
  end
  end
  --actions.generic+=/festering_strike,if=debuff.festering_wound.stack<=2&(debuff.festering_wound.stack<=4|(buff.blighted_rune_weapon.up|talent.castigator.enabled))&runic_power.deficit>5&(runic_power.deficit>23|!talent.castigator.enabled)
  if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 2 and (Target:DebuffStack(S.FesteringWounds) <= 4 or (Player:Buff(S.BlightedRuneWeapon) or S.Castigator:IsAvailable())) and Player:RunicPowerDeficit() > 5 and (Player:RunicPowerDeficit() > 23 or S.Castigator:IsAvailable()) then
    if AR.Cast(S.FesteringStrike) then return ""; end
  end
  --actions.generic+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune.time_to_4>gcd
  if S.DeathCoil:IsUsable() and not Player:Buff(S.NecrosisBuff) and S.Necrosis:IsAvailable() and Player:RuneTimeToX(4) > Player:GCD() then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/scourge_strike,if=(buff.necrosis.react|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!(talent.castigator.enabled|equipped.132448))&runic_power.deficit>9&(runic_power.deficit>23|!talent.castigator.enabled)
  if S.ScourgeStrike:IsCastable() and (Player:Buff(S.NecrosisBuff) or Player:Buff(S.UnholyStrength) or Player:Runes() >= 2) and Target:DebuffStack(S.FesteringWounds) >= 1 and (Target:DebuffStack(S.FesteringWounds) >= 3 or not (S.Castigator:IsAvailable() or I.InstructorsFourthLesson:IsEquipped())) and Player:RunicPowerDeficit() > 9 and (Player:RunicPowerDeficit() > 23 or not S.Castigator:IsAvailable()) then
    if AR.Cast(S.ScourgeStrike) then return ""; end
  end
  -- actions.generic+=/clawing_shadows,if=(buff.necrosis.react|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!equipped.132448)&runic_power.deficit>9
  if S.ClawingShadows:IsCastable() and (Player:Buff(S.NecrosisBuff) or Player:Buff(S.UnholyStrength) or Player:Runes() >= 2) and Target:DebuffStack(S.FesteringWounds) >= 1 and (Target:DebuffStack(S.FesteringWounds) >= 3 or not I.InstructorsFourthLesson:IsEquipped()) and Player:RunicPowerDeficit() > 9 then
    if AR.Cast(S.ClawingShadows) then return ""; end
  end
  --actions.generic+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>15
  if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) and S.DarkArbiter:CooldownRemains() > 15 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
  --actions.generic+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
  if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>15
  if S.DeathCoil:IsUsable() and S.DarkArbiter:IsAvailable() and S.DarkArbiter:CooldownRemains() > 10 then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  --actions.generic+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled
  if S.DeathCoil:IsUsable() and not S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() then
    if AR.Cast(S.DeathCoil) then return ""; end
  end
  return false;
end

 --DarkArbiter
local function DarkArbiter()
--actions.valkyr=death_coil
 if S.DeathCoil:IsUsable() and (Player:Buff(S.SuddenDoom) or Player:RunicPower() >= 45) then
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
 --actions.valkyr+=/arcane_torrent,if=runic_power<45|runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and ( Player:RunicPower() < 45 or Player:RunicPowerDeficit() > 20 ) then
  if AR.Cast(S.ArcaneTorrent, Settings.Unholy.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
 end
--actions.valkyr+=/apocalypse,if=debuff.festering_wound.stack=6
 if S.Apocalypse:IsCastable()  and Target:DebuffStack(S.FesteringWounds) == 6 then
  if AR.Cast(S.Apocalypse) then return ""; end
 end 
 --actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<3
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 6  and S.Apocalypse:Cooldown() < 3 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end 
 --actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=4
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 4 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
 --actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
 if S.ClawingShadows:IsCastable() and Target:Debuff(S.FesteringWounds) then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
 --actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
 if S.ScourgeStrike:IsCastable() and Target:Debuff(S.FesteringWounds) then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
  return false;
end
--ShortCDS as DT , BRW
local function ShortCDS()
  if Target:IsInRange(30) and not Target:Debuff(S.VirulentPlagueDebuff)then
    if AR.Cast(S.Outbreak) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&cooldown.dark_arbiter.remains>165
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.DarkArbiter:Cooldown() > 165 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>55
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and not S.ShadowInfusion:IsAvailable() and S.DarkArbiter:Cooldown() > 55 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>35
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.ShadowInfusion:IsAvailable() and S.DarkArbiter:Cooldown() > 35 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
 
      --actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and Target:TimeToDie() < S.DarkArbiter:Cooldown() - 8 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&cooldown.summon_gargoyle.remains>160
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.SummonGargoyle:Cooldown() > 160 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>55
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and not S.ShadowInfusion:IsAvailable() and S.SummonGargoyle:Cooldown() > 55 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>35
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.ShadowInfusion:IsAvailable() and S.SummonGargoyle:Cooldown() > 35 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and Target:TimeToDie() < S.SummonGargoyle:Cooldown() - 8 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/dark_transformation,if=!equipped.137075&rune<=3
  if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and not I.Taktheritrixs:IsEquipped() and Player:Runes() <= 3 then
    if AR.Cast(S.DarkTransformation) then return ""; end
  end
      --actions+=/blighted_rune_weapon,if=rune<=3
  if AR.CDsON() and S.BlightedRuneWeapon:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 4 then
    if AR.Cast(S.BlightedRuneWeapon, Settings.Unholy.OffGCDasOffGCD.BlightedRuneWeapon) then return ; end
  end
  return false;
end

local function APL()
    --UnitUpdate
  AC.GetEnemies(8)
  Everyone.AoEToggleEnemiesUpdate();
  --Defensives
  --OutOf Combat
    -- Reset Combat Variables
    -- Flask
      -- Food
      -- Rune
      -- Army w/ Bossmod Countdown 
      -- Volley toggle
      -- Opener 
    if not Player:AffectingCombat() then
    --check if we have our lovely pet with us
    if Pet:IsActive() == false and S.SummonPet:IsCastable() then
    if AR.Cast(S.SummonPet) then return ""; end
    end
  --army suggestion at pull
    if Everyone.TargetIsValid() and Target:IsInRange(30) and not S.ArmyOfDead:IsOnCooldown() then
          if AR.Cast(S.ArmyOfDead) then return ""; end
    end
  -- outbreak if virulent_plague is not  the target and we are not in combat
    if Everyone.TargetIsValid() and Target:IsInRange(30) and not Target:Debuff(S.VirulentPlagueDebuff)then
      if AR.Cast(S.Outbreak) then return ""; end
    end
      return;
    end
 --InCombat
    if Everyone.TargetIsValid()  then
        ShouldReturn = ShortCDS();
        if ShouldReturn then return ShouldReturn; 
    end
    if (S.DarkArbiter:IsAvailable() and  S.DarkArbiter:TimeSinceLastCast() > 20) or S.Defile:IsAvailable() or S.SoulReaper:IsAvailable() then
    ShouldReturn = Generic();
    if ShouldReturn then return ShouldReturn; end
    end

    if S.DarkArbiter:TimeSinceLastCast() <= 20 then
       ShouldReturn = DarkArbiter();
       if ShouldReturn then return ShouldReturn;  end
    end
    

   return;
   end
   end
   
   
   

AR.SetAPL(252, APL);
--- ====25/08/2017======
--- ======= SIMC =======  
--actions=auto_attack
--actions+=/mind_freeze
--actions+=/arcane_torrent,if=runic_power.deficit>20
--actions+=/blood_fury
--actions+=/berserking
--actions+=/use_items
--actions+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--actions+=/potion,if=buff.unholy_strength.react
--actions+=/outbreak,target_if=(dot.virulent_plague.tick_time_remains+tick_time<=dot.virulent_plague.remains)&dot.virulent_plague.remains<=gcd
--actions+=/army_of_the_dead
--actions+=/dark_transformation,if=equipped.137075&cooldown.dark_arbiter.remains>165
--actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>55
--actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>35
--actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
--actions+=/dark_transformation,if=equipped.137075&cooldown.summon_gargoyle.remains>160
--actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>55
--actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>35
--actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
--actions+=/dark_transformation,if=!equipped.137075&rune<=3
--actions+=/blighted_rune_weapon,if=festering_wound<=4
--actions+=/run_action_list,name=valkyr,if=talent.dark_arbiter.enabled&pet.valkyr_battlemaiden.active
--actions+=/call_action_list,name=generic

--actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
--actions.aoe+=/epidemic,if=spell_targets.epidemic>4
--actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(death_and_decay.ticking|defile.ticking)
--actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(death_and_decay.ticking|defile.ticking)
--actions.aoe+=/epidemic,if=spell_targets.epidemic>2

--actions.generic=dark_arbiter,if=!equipped.137075&runic_power.deficit<30
--actions.generic+=/apocalypse,if=equipped.137075&debuff.festering_wound.stack>=6&talent.dark_arbiter.enabled
--actions.generic+=/dark_arbiter,if=equipped.137075&runic_power.deficit<30&cooldown.dark_transformation.remains<2
--actions.generic+=/summon_gargoyle,if=!equipped.137075,if=rune<=3
--actions.generic+=/chains_of_ice,if=buff.unholy_strength.up&buff.cold_heart.stack>19
--actions.generic+=/summon_gargoyle,if=equipped.137075&cooldown.dark_transformation.remains<10&rune<=3
--actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<4
--actions.generic+=/apocalypse,if=debuff.festering_wound.stack>=6
--actions.generic+=/death_coil,if=runic_power.deficit<10
--actions.generic+=/death_coil,if=!talent.dark_arbiter.enabled&buff.sudden_doom.up&!buff.necrosis.up&rune<=3
--actions.generic+=/death_coil,if=talent.dark_arbiter.enabled&buff.sudden_doom.up&cooldown.dark_arbiter.remains>5&rune<=3
--actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
--actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=3
--actions.generic+=/festering_strike,if=debuff.soul_reaper.up&!debuff.festering_wound.up
--actions.generic+=/scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
--actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
--actions.generic+=/defile
--actions.generic+=/call_action_list,name=aoe,if=active_enemies>=2
--actions.generic+=/festering_strike,if=debuff.festering_wound.stack<=2&(debuff.festering_wound.stack<=4|(buff.blighted_rune_weapon.up|talent.castigator.enabled))&runic_power.deficit>5&(runic_power.deficit>23|!talent.castigator.enabled)
--actions.generic+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune.time_to_4>gcd
--actions.generic+=/scourge_strike,if=(buff.necrosis.react|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!(talent.castigator.enabled|equipped.132448))&runic_power.deficit>9&(runic_power.deficit>23|!talent.castigator.enabled)
--actions.generic+=/clawing_shadows,if=(buff.necrosis.react|buff.unholy_strength.react|rune>=2)&debuff.festering_wound.stack>=1&(debuff.festering_wound.stack>=3|!equipped.132448)&runic_power.deficit>9
--actions.generic+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>15
--actions.generic+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
--actions.generic+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>15
--actions.generic+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled

--actions.valkyr=death_coil
--actions.valkyr+=/apocalypse,if=debuff.festering_wound.stack>=6
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<3
--actions.valkyr+=/call_action_list,name=aoe,if=active_enemies>=2
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=4
--actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
--actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
  

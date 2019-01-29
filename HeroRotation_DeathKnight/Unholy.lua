--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- HeroRotation
  local HR = HeroRotation;
  -- Lua

  --- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = HR.Commons.Everyone;
  local DeathKnight = HR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Unholy = {
    -- Racials
    ArcaneTorrent                 = Spell(50613),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    --Abilities
    ArmyOfTheDead                 = Spell(42650),
    Apocalypse                    = Spell(275699),
    ChainsOfIce                   = Spell(45524),
    ScourgeStrike                 = Spell(55090),
    DarkTransformation            = Spell(63560),
    DeathAndDecay                 = Spell(43265),
    DeathCoil                     = Spell(47541),
    DeathStrike                   = Spell(49998),
    FesteringStrike               = Spell(85948),
    Outbreak                      = Spell(77575),
    SummonPet                     = Spell(46584),
       --Talents
    InfectedClaws                 = Spell(207272),
    AllWillServe                  = Spell(194916),
    ClawingShadows                = Spell(207311),
    PestilentPustules             = Spell(194917),
    BurstingSores                 = Spell(207264),
    EbonFever                     = Spell(207269),
    UnholyBlight                  = Spell(115989),
    HarbringerOfDoom              = Spell(276023),
    SoulReaper                    = Spell(130736),
    Pestilence                    = Spell(277234),
    Defile                        = Spell(152280),
    Epidemic                      = Spell(207317),
    ArmyOfTheDammed               = Spell(276837),
    UnholyFrenzy                  = Spell(207289),
    SummonGargoyle                = Spell(49206),
    --Buffs/Procs
    MasterOfGhouls                = Spell(246995), -- ??
    SuddenDoom                    = Spell(81340),
    UnholyStrength                = Spell(53365),
    DeathAndDecayBuff             = Spell(188290),
    --Debuffs
    FesteringWound                = Spell(194310), --max 8 stacks
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
    --SummonGargoyle HiddenAura
    SummonGargoyleActive          = Spell(212412), --tbc
    -- Misc
    PoolForResources              = Spell(9999000010)
    };
  local S = Spell.DeathKnight.Unholy;
  --Items
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Unholy = {
    --Legendaries (Legion)
  Taktheritrixs                 = Item(137075, {3})

  };
  local I = Item.DeathKnight.Unholy;

  --GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.DeathKnight.Commons,
    Unholy = HR.GUISettings.APL.DeathKnight.Unholy
  };

  -- Variables
  local function PoolingForGargoyle()
    --(cooldown.summon_gargoyle.remains<5&(cooldown.dark_transformation.remains<5|!equipped.137075))&talent.summon_gargoyle.enabled
    return S.SummonGargoyle:CooldownRemains() < 5 and S.SummonGargoyle:IsAvailable()
  end

  --- ===== APL =====
  --- ===============
  local function AOE()
  -- death_and_decay,if=cooldown.apocalypse.remains
  if S.DeathAndDecay:IsCastable() and S.Apocalypse:CooldownDown() then
    if HR.Cast(S.DeathAndDecay) then return ""; end
  end
  -- defile
  if S.Defile:IsCastable() then
    if HR.Cast(S.Defile) then return ""; end
  end
  -- epidemic,if=death_and_decay.ticking&rune<2&!variable.pooling_for_gargoyle
  if S.Epidemic:IsAvailable() and S.Epidemic:IsUsable() and Player:Buff(S.DeathAndDecayBuff) and Player:Rune() < 2 and not PoolingForGargoyle() then
    if HR.Cast(S.Epidemic) then return ""; end
  end
  -- death_coil,if=death_and_decay.ticking&rune<2&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and Player:Buff(S.DeathAndDecayBuff) and Player:Rune() < 2 and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- scourge_strike,if=death_and_decay.ticking&cooldown.apocalypse.remains
  if S.ScourgeStrike:IsCastable() and Player:Buff(S.DeathAndDecayBuff) and S.Apocalypse:CooldownDown() then
    if HR.Cast(S.ScourgeStrike) then return ""; end
  end
  -- clawing_shadows,if=death_and_decay.ticking&cooldown.apocalypse.remains
  if S.ClawingShadows:IsCastable() and Player:Buff(S.DeathAndDecayBuff) and S.Apocalypse:CooldownDown() then
    if HR.Cast(S.ClawingShadows) then return ""; end
  end
  -- epidemic,if=!variable.pooling_for_gargoyle
  if S.Epidemic:IsAvailable() and S.Epidemic:IsUsable() and not PoolingForGargoyle() then
    if HR.Cast(S.Epidemic) then return ""; end
  end
  -- festering_strike,target_if=debuff.festering_wound.stack<=1&cooldown.death_and_decay.remains
  if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWound) <= 1 and S.DeathAndDecay:CooldownDown() then
    if HR.Cast(S.FesteringStrike) then return ""; end
  end
  -- festering_strike,if=talent.bursting_sores.enabled&spell_targets.bursting_sores>=2&debuff.festering_wound.stack<=1
  if S.FesteringStrike:IsCastable() and (S.BurstingSores:IsAvailable() and Cache.EnemiesCount[8] >= 2 and Target:DebuffStack(S.FesteringWound) <= 1) then
    if HR.Cast(S.FesteringStrike) then return ""; end
  end
  -- death_coil,if=buff.sudden_doom.react&rune.deficit>=4
  if S.DeathCoil:IsUsable() and Player:Buff(S.SuddenDoom) and Player:Rune() <= 2 then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsable() and Player:Buff(S.SuddenDoom) and not PoolingForGargoyle() or S.SummonGargoyle:TimeSinceLastCast() <= 22 then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- death_coil,if=runic_power.deficit<14&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 14 and (S.Apocalypse:CooldownRemainsP() > 5 or Target:DebuffStackP(S.FesteringWound) > 4) and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- scourge_strike,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
  if S.ScourgeStrike:IsCastable() and (((Target:Debuff(S.FesteringWound) and S.Apocalypse:CooldownRemainsP() > 5) or Target:DebuffStack(S.FesteringWound) > 4) and S.ArmyOfTheDead:CooldownRemainsP() > 5 or S.ArmyOfTheDead:IsCastable())  then
    if HR.Cast(S.ScourgeStrike) then return ""; end
  end
  -- clawing_shadows,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
  if S.ClawingShadows:IsCastable() and (((Target:Debuff(S.FesteringWound) and S.Apocalypse:CooldownRemainsP() > 5) or Target:DebuffStack(S.FesteringWound) > 4) and S.ArmyOfTheDead:CooldownRemainsP() > 5 or S.ArmyOfTheDead:IsCastable()) then
    if HR.Cast(S.ClawingShadows) then return ""; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 20 and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- festering_strike,if=((((debuff.festering_wound.stack<4&!buff.unholy_frenzy.up)|debuff.festering_wound.stack<3)&cooldown.apocalypse.remains<3)|debuff.festering_wound.stack<1)&cooldown.army_of_the_dead.remains>5
  if S.FesteringStrike:IsCastable() and (((((Target:DebuffStack(S.FesteringWound) < 4 and not Player:Buff(S.UnholyFrenzy)) or Target:DebuffStack(S.FesteringWound) < 3) and S.Apocalypse:CooldownRemainsP() < 3) or Target:DebuffStack(S.FesteringWound) < 1) and S.ArmyOfTheDead:CooldownRemainsP() > 5 or S.ArmyOfTheDead:IsCastable()) then
    if HR.Cast(S.FesteringStrike) then return ""; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  return false;
end


 local function Generic()
  -- death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsable() and Player:Buff(S.SuddenDoom) and (not PoolingForGargoyle() or S.SummonGargoyle:TimeSinceLastCast() <= 22) then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- death_coil,if=runic_power.deficit<14&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 14 and (S.Apocalypse:CooldownRemainsP() > 5 or Target:DebuffStackP(S.FesteringWound) > 4) and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- death_and_decay,if=talent.pestilence.enabled&cooldown.apocalypse.remains
  if S.DeathAndDecay:IsCastable() and S.Pestilence:IsAvailable() and S.Apocalypse:CooldownDown() then
    if HR.Cast(S.DeathAndDecay) then return ""; end
  end
  -- defile,if=cooldown.apocalypse.remains
  if S.Defile:IsCastable() and S.Apocalypse:CooldownDown() then
    if HR.Cast(S.Defile) then return ""; end
  end
  -- scourge_strike,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
  if S.ScourgeStrike:IsCastable() and (((Target:Debuff(S.FesteringWound) and S.Apocalypse:CooldownRemainsP() > 5) or Target:DebuffStack(S.FesteringWound) > 4) and (S.ArmyOfTheDead:CooldownRemainsP() > 5 or S.ArmyOfTheDead:IsCastable())) then
    if HR.Cast(S.ScourgeStrike) then return ""; end
  end
  -- clawing_shadows,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
  if S.ClawingShadows:IsCastable() and (((Target:Debuff(S.FesteringWound) and S.Apocalypse:CooldownRemainsP() > 5) or Target:DebuffStack(S.FesteringWound) > 4) and (S.ArmyOfTheDead:CooldownRemainsP() > 5 or S.ArmyOfTheDead:IsCastable())) then
    if HR.Cast(S.ClawingShadows) then return ""; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 20 and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  -- festering_strike,if=((((debuff.festering_wound.stack<4&!buff.unholy_frenzy.up)|debuff.festering_wound.stack<3)&cooldown.apocalypse.remains<3)|debuff.festering_wound.stack<1)&cooldown.army_of_the_dead.remains>5
  if S.FesteringStrike:IsCastable() and (((((Target:DebuffStack(S.FesteringWound) < 4 and not Player:Buff(S.UnholyFrenzy)) or Target:DebuffStack(S.FesteringWound) < 3) and S.Apocalypse:CooldownRemainsP() < 3) or Target:DebuffStack(S.FesteringWound) < 1) and (S.ArmyOfTheDead:CooldownRemainsP() > 5 or S.ArmyOfTheDead:IsCastable())) then
    if HR.Cast(S.FesteringStrike) then return ""; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and not PoolingForGargoyle() then
    if HR.Cast(S.DeathCoil) then return ""; end
  end
  return false;
end

local function Cooldowns()
    -- army_of_the_dead
    if S.ArmyOfTheDead:IsCastable() then
      if HR.Cast(S.ArmyOfTheDead, Settings.Unholy.GCDasOffGCD.ArmyOfTheDead) then return ""; end
    end
    -- dark_transformation
    if S.DarkTransformation:IsCastable() and Pet:IsActive() then
      if HR.Cast(S.DarkTransformation) then return ""; end
    end
    -- summon_gargoyle,if=runic_power.deficit<14
    if S.SummonGargoyle:IsCastable() and Player:RunicPowerDeficit() < 14 then
      if HR.Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return ""; end
    end
    -- unholy_frenzy, if= debuff.festering_wound.stack < 4
    if S.UnholyFrenzy:IsCastable() and Target:DebuffStack(S.FesteringWound) < 4 then
      if HR.Cast(S.UnholyFrenzy, Settings.Unholy.GCDasOffGCD.UnholyFrenzy) then return ""; end
    end
    -- unholy_frenzy,if=active_enemies>=2&((cooldown.death_and_decay.remains<=gcd&!talent.defile.enabled)|(cooldown.defile.remains<=gcd&talent.defile.enabled))
    if S.UnholyFrenzy:IsCastable() and Cache.EnemiesCount[10] >= 2 and ((S.DeathAndDecay:CooldownRemainsP() <= Player:GCD() and not S.Defile:IsAvailable()) or (S.Defile:CooldownRemainsP() <= Player:GCD() and S.Defile:IsAvailable())) then
      if HR.Cast(S.UnholyFrenzy, Settings.Unholy.GCDasOffGCD.UnholyFrenzy) then return ""; end
    end
    -- soul_reaper,target_if=(target.time_to_die<8|rune<=2)&!buff.unholy_frenzy.up
    if S.SoulReaper:IsCastable() then
      if HR.Cast(S.SoulReaper, Settings.Unholy.GCDasOffGCD.SoulReaper) then return ""; end
    end
    -- unholy_blight
    if S.UnholyBlight:IsCastable() then
      if HR.Cast(S.UnholyBlight) then return ""; end
    end
    return false;
  end

local function APL()
    --UnitUpdate
  HL.GetEnemies(8); -- Melee Range / Bursting Sores 8yd
  HL.GetEnemies(10); -- DnD 10yd
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
    if not Pet:IsActive() and S.SummonPet:IsCastable() then
    if HR.Cast(S.SummonPet) then return ""; end
    end
  --army suggestion at pull
    if Everyone.TargetIsValid() and Target:IsInRange(30) and S.ArmyOfTheDead:CooldownUp() and HR.CDsON() then
          if HR.Cast(S.ArmyOfTheDead, Settings.Unholy.GCDasOffGCD.ArmyOfTheDead) then return ""; end
    end
  -- outbreak if virulent_plague is not  the target and we are not in combat
    if Everyone.TargetIsValid() and Target:IsInRange(30) and not Target:Debuff(S.VirulentPlagueDebuff)then
      if HR.Cast(S.Outbreak) then return ""; end
    end
      return;
    end
    --InCombat
      --actions+=/outbreak,target_if=(dot.virulent_plague.tick_time_remains+tick_time<=dot.virulent_plague.remains)&dot.virulent_plague.remains<=gcd
    if S.Outbreak:IsUsable() and not Target:Debuff(S.VirulentPlagueDebuff) or Target:DebuffRemainsP(S.VirulentPlagueDebuff) < Player:GCD()*1.5 then
      if HR.Cast(S.Outbreak) then return ""; end
    end
    -- apocalypse,if=debuff.festering_wound.stack>=4
    if S.Apocalypse:IsCastable() and Target:DebuffStack(S.FesteringWound) >= 4 then
      if HR.Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse) then return ""; end
    end
    --Lets call specific APLs
    if HR.CDsON() then
        ShouldReturn = Cooldowns();
        if ShouldReturn then return ShouldReturn; end
    end
    if HR.AoEON() and Cache.EnemiesCount[10] >= 2 then
      ShouldReturn = AOE();
      if ShouldReturn then return ShouldReturn; end
    end
    -- gargoyle apl doesnt have a proper apl yet, lets use the standard one incase someone select that talent for now even if its not optimal
    if --[[(S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:TimeSinceLastCast() > 22)]] S.SummonGargoyle:IsAvailable() or S.ArmyOfTheDammed:IsAvailable() or S.UnholyFrenzy:IsAvailable() then
    ShouldReturn = Generic();
    if ShouldReturn then return ShouldReturn; end
    end
    if HR.CastAnnotated(S.PoolForResources, false, "WAIT") then return "Wait/Pool Resources"; end
    return
  end


HR.SetAPL(252, APL);
--- ====31/07/2018======
--- ======= SIMC =======
--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/potion
--actions.precombat+=/raise_dead
--actions.precombat+=/army_of_the_dead
--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/mind_freeze
--actions+=/variable,name=pooling_for_gargoyle,value=(cooldown.summon_gargoyle.remains<5&(cooldown.dark_transformation.remains<5|!equipped.137075))&talent.summon_gargoyle.enabled
--# Racials, Items, and other ogcds
--actions+=/arcane_torrent,if=runic_power.deficit>65&(pet.gargoyle.active|!talent.summon_gargoyle.enabled)&rune.deficit>=5
--actions+=/blood_fury,if=pet.gargoyle.active|!talent.summon_gargoyle.enabled
--actions+=/berserking,if=pet.gargoyle.active|!talent.summon_gargoyle.enabled
--actions+=/use_items
--actions+=/use_item,name=feloiled_infernal_machine,if=pet.gargoyle.active|!talent.summon_gargoyle.enabled
--actions+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--actions+=/potion,if=cooldown.army_of_the_dead.ready|pet.gargoyle.active|buff.unholy_frenzy.up
--# Maintain Virulent Plague
--actions+=/outbreak,target_if=(dot.virulent_plague.tick_time_remains+tick_time<=dot.virulent_plague.remains)&dot.virulent_plague.remains<=gcd
--actions+=/call_action_list,name=cooldowns
--actions+=/run_action_list,name=aoe,if=active_enemies>=2
--actions+=/call_action_list,name=generic
--# AoE rotation
--actions.aoe=death_and_decay,if=cooldown.apocalypse.remains
--actions.aoe+=/defile
--actions.aoe+=/epidemic,if=death_and_decay.ticking&rune<2&!variable.pooling_for_gargoyle
--actions.aoe+=/death_coil,if=death_and_decay.ticking&rune<2&!variable.pooling_for_gargoyle
--actions.aoe+=/scourge_strike,if=death_and_decay.ticking&cooldown.apocalypse.remains
--actions.aoe+=/clawing_shadows,if=death_and_decay.ticking&cooldown.apocalypse.remains
--actions.aoe+=/epidemic,if=!variable.pooling_for_gargoyle
--actions.aoe+=/festering_strike,if=talent.bursting_sores.enabled&spell_targets.bursting_sores>=2&debuff.festering_wound.stack<=1
--actions.aoe+=/death_coil,if=buff.sudden_doom.react&rune.deficit>=4
--actions.aoe+=/death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
--actions.aoe+=/death_coil,if=runic_power.deficit<14&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&!variable.pooling_for_gargoyle
--actions.aoe+=/scourge_strike,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
--actions.aoe+=/clawing_shadows,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
--actions.aoe+=/death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
--actions.aoe+=/festering_strike,if=((((debuff.festering_wound.stack<4&!buff.unholy_frenzy.up)|debuff.festering_wound.stack<3)&cooldown.apocalypse.remains<3)|debuff.festering_wound.stack<1)&cooldown.army_of_the_dead.remains>5
--actions.aoe+=/death_coil,if=!variable.pooling_for_gargoyle
--# Cold Heart legendary
--actions.cold_heart=chains_of_ice,if=buff.unholy_strength.remains<gcd&buff.unholy_strength.react&buff.cold_heart_item.stack>16
--actions.cold_heart+=/chains_of_ice,if=buff.master_of_ghouls.remains<gcd&buff.master_of_ghouls.up&buff.cold_heart_item.stack>17
--actions.cold_heart+=/chains_of_ice,if=buff.cold_heart_item.stack=20&buff.unholy_strength.react
--# Cold heart and other on-gcd cooldowns
--actions.cooldowns=call_action_list,name=cold_heart,if=equipped.cold_heart&buff.cold_heart_item.stack>10
--actions.cooldowns+=/army_of_the_dead
--actions.cooldowns+=/apocalypse,if=debuff.festering_wound.stack>=4
--actions.cooldowns+=/dark_transformation,if=(equipped.137075&cooldown.summon_gargoyle.remains>40)|(!equipped.137075|!talent.summon_gargoyle.enabled)
--actions.cooldowns+=/summon_gargoyle,if=runic_power.deficit<14
--actions.cooldowns+=/unholy_frenzy,if=debuff.festering_wound.stack<4
--actions.cooldowns+=/unholy_frenzy,if=active_enemies>=2&((cooldown.death_and_decay.remains<=gcd&!talent.defile.enabled)|(cooldown.defile.remains<=gcd&talent.defile.enabled))
--actions.cooldowns+=/soul_reaper,target_if=(target.time_to_die<8|rune<=2)&!buff.unholy_frenzy.up
--actions.cooldowns+=/unholy_blight
--actions.generic=death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
--actions.generic+=/death_coil,if=runic_power.deficit<14&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&!variable.pooling_for_gargoyle
--actions.generic+=/death_and_decay,if=talent.pestilence.enabled&cooldown.apocalypse.remains
--actions.generic+=/defile,if=cooldown.apocalypse.remains
--actions.generic+=/scourge_strike,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
--actions.generic+=/clawing_shadows,if=((debuff.festering_wound.up&cooldown.apocalypse.remains>5)|debuff.festering_wound.stack>4)&cooldown.army_of_the_dead.remains>5
--actions.generic+=/death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
--actions.generic+=/festering_strike,if=((((debuff.festering_wound.stack<4&!buff.unholy_frenzy.up)|debuff.festering_wound.stack<3)&cooldown.apocalypse.remains<3)|debuff.festering_wound.stack<1)&cooldown.army_of_the_dead.remains>5
--actions.generic+=/death_coil,if=!variable.pooling_for_gargoyle

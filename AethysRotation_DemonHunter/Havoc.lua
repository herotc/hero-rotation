--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  -- Spells
  if not Spell.DemonHunter then Spell.DemonHunter = {}; end
  Spell.DemonHunter.Havoc = {
    -- Racials
    ArcaneTorrent                 = Spell(80483),
    -- Abilities
    Annihilation                  = Spell(201427),
    BladeDance                    = Spell(188499),
    ChaosStrike                   = Spell(162794),
    DeathSweep                    = Spell(210152),
    DemonsBite                    = Spell(162243),
    EyeBeam                       = Spell(198013),
    FelRush                       = Spell(195072),
    Metamorphosis                 = Spell(191427),
    ThrowGlaive                   = Spell(204157),
    VengefulRetreat               = Spell(198793),
    -- Talents
    BlindFury                     = Spell(203550),
    Bloodlet                      = Spell(206473),
    ChaosBlades                   = Spell(211048),
    ChaosCleave                   = Spell(206475),
    DemonBlades                   = Spell(203555),
    Demonic                       = Spell(213410),
    DemonicAppetite               = Spell(206478),
    DemonReborn                   = Spell(193897),
    FelBarrage                    = Spell(211053),
    FelBlade                      = Spell(232893),
    FelEruption                   = Spell(211881),
    FelMastery                    = Spell(192939),
    FirstBlood                    = Spell(206416),
    MasteroftheGlaive             = Spell(203556),
    Momentum                      = Spell(206476),
    Nemesis                       = Spell(206491),
    Prepared                      = Spell(203551),
    

    -- Artifact
    FuryoftheIllidari             = Spell(201467),
    -- Defensive
    
    -- Utility
    
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.DemonHunter.Havoc;
  -- Items
  if not Item.DemonHunter then Item.DemonHunter = {}; end
  Item.DemonHunter.Havoc = {
    -- Legendaries
    
  };
  local I = Item.DemonHunter.Havoc;
  -- Rotation Var
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DemonHunter.Commons,
    Havoc = AR.GUISettings.APL.DemonHunter.Havoc
  };


--- ======= ACTION LISTS =======
  -- actions+=/call_action_list,name=cooldown
  local function CDs ()
    -- actions.cooldown=nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>60)
    -- if S.Nemesis:IsCastable() and
      -- if AR.Cast(S.Nemesis) then return ""; end
    -- end
    -- actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
    -- actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=12
    -- if S.ChaosBlades:IsCastable() and Player:Buff(S.Metamorphosis) or 
    --   if AR.Cast(S.ChaosBlades) then return; end
    -- end
    -- actions.cooldown+=/use_item,slot=trinket2,if=!buff.metamorphosis.up&(!talent.first_blood.enabled|!cooldown.blade_dance.ready)&(!talent.nemesis.enabled|cooldown.nemesis.remains>30|target.time_to_die<cooldown.nemesis.remains+3)
    -- actions.cooldown+=/metamorphosis,if=!variable.pooling_for_meta&(!talent.demonic.enabled|!cooldown.eye_beam.ready)
    if S.Metamorphosis:IsCastable() and not Pooling_for_Meta () and (not S.Demonic:IsAvailable() and not S.EyeBeam:Cooldown()) then
      if AR.Cast(S.Metamorphosis) then return ""; end
    end
    -- actions.cooldown+=/potion,name=old_war,if=buff.metamorphosis.remains>25|target.time_to_die<30
  end
  -- # "Getting ready to use meta" conditions, this is used in a few places.
  -- actions+=/variable,name=pooling_for_meta,value=cooldown.metamorphosis.remains<6&fury.deficit>30&!talent.demonic.enabled
  local function Pooling_for_Meta ()
    return S.Metamorphosis:Cooldown() < 6 and Player:FuryDeficit() > 30 and not S.Demonic:IsAvailable();
  end
  -- # Blade Dance conditions. Always if First Blood is talented, otherwise 5+ targets with Chaos Cleave or 3+ targets without.
  -- actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*2)
  local function Blade_Dance ()
    return (S.FirstBlood:IsAvailable() or Cache.EnemiesCount[10] >= 3 + (S.ChaosCleave:IsAvailable() * 2));
  end
  -- # Blade Dance pooling condition, so we don't spend too much fury when we need it soon. No need to pool on
  -- # single target since First Blood already makes it cheap enough and delaying it a tiny bit isn't a big deal.
  -- actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&fury-40<35-talent.first_blood.enabled*20&(spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*2))
  local function Pooling_for_Blade_Dance ()
    return Blade_Dance () and Player:Fury() - 40 < 35 - S.FirstBlood:IsAvailable() * 20 and (Cache.EnemiesCount[10] >= 3 + (S.ChaosCleave:IsAvailable() * 2));
  end
  -- # Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
  -- actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
  local function Pooling_for_Chaos_Strike ()
    return S.ChaosCleave:IsAvailable() and Player:FuryDeficit() > 40;
  end


--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() then
       if AR.CDsON() then
          if S.Nemesis:IsCastable() then
            if AR.Cast(S.Nemesis) then return; end
          end
        end
        if S.FelBlade:IsCastable() then
          if AR.Cast(S.FelBlade) then return; end
        end 
        if S.FelRush:IsCastable() then
          if AR.Cast(S.FelRush) then return; end
        end  
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      
      
      -- actions+=/pick_up_fragment,if=talent.demonic_appetite.enabled&fury.deficit>=35&(!talent.demonic.enabled|cooldown.eye_beam.remains>5)
      -- actions+=/consume_magic
      -- # Vengeful Retreat backwards through the target to minimize downtime.
      -- actions+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
      if S.VengefulRetreat:IsCastable() and (S.Prepared:IsAvailable() or S.Momentum:IsAvailable()) and not Player:Buff(S.Prepared) and not Player:Buff(S.Momentum) then
        if AR.Cast(S.VengefulRetreat) then return ""; end
      end
      -- # Fel Rush for Momentum and for fury from Fel Mastery.
      -- actions+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
      if S.FelRush:IsCastable() and (S.Momentum:IsAvailable() or S.FelMastery:IsAvailable()) and (not S.Momentum:IsAvailable() or (S.FelRush:Charges() == 2 or S.VengefulRetreat > 4) and not Player:Buff(S.Momentum)) and (not S.FelMastery:IsAvailable() or Player:FuryDeficit() >= 25) and S.FelRush:Charges() == 2 then
        if AR.Cast(S.FelRush) then return ""; end
      end
      -- # Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
      -- actions+=/fel_barrage,if=charges>=5&(buff.momentum.up|!talent.momentum.enabled)&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>30)
      -- if S.FelBarrage:IsCastable() and S.FelBarrage:Charges() >= 5 and (Player:Buff(S.Momentum) or not S.Momentum:IsAvailable()) then
        -- if AR.Cast(S.FelBarrage) then return ""; end
      -- end
      -- actions+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
      if S.ThrowGlaive:IsCastable() and S.Bloodlet:IsAvailable() and (not S.Momentum:IsAvailable() or Player:Buff(S.Momentum)) and S.ThrowGlaive:Charges() == 2 then
        if AR.Cast(S.ThrowGlaive) then return ""; end
      end
      -- actions+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
      if S.FelBlade:IsCastable() and Player:Fury() < 15 and (S.DeathSweep:Cooldown() < 2 * Player:GCD() or S.BladeDance:Cooldown() < 2 * Player:GCD()) then
        if AR.Cast(S.FelBlade) then return ""; end
      end
      -- actions+=/death_sweep,if=variable.blade_dance
      if S.DeathSweep:IsCastable() and Blade_Dance () then
        if AR.Cast(S.DeathSweep) then return ""; end
      end
      -- actions+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled
      if S.FelRush:IsCastable() and S.FelRush:Charges() == 2 and not S.Momentum:IsAvailable() and not S.FelMastery:IsAvailable() then
        if AR.Cast(S.FelRush) then return ""; end
      end
      -- actions+=/fel_eruption
      if S.FelEruption:IsCastable() then
        if AR.Cast(S.FelEruption) then return ""; end
      end
      -- actions+=/fury_of_the_illidari,if=(active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains)
      -- actions+=/eye_beam,if=talent.demonic.enabled&(talent.demon_blades.enabled|(talent.blind_fury.enabled&fury.deficit>=35)|(!talent.blind_fury.enabled&fury.deficit<30))&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>30)
      -- if S.EyeBeam:IsCastable() and S.Demonic:IsAvailable() and (S.DemonBlades:IsAvailable() or (S.BlindFury:IsAvailable() and Player:FuryDeficit() >= 35) or (not S.BlindFury:IsAvailable() and Player:FuryDeficit() < 30)) and 
        -- if AR.Cast(S.EyeBeam) then return ""; end
      -- end
      -- actions+=/blade_dance,if=variable.blade_dance&(!talent.demonic.enabled|cooldown.eye_beam.remains>5)&(!cooldown.metamorphosis.ready)
      if S.BladeDance:IsCastable() and Blade_Dance () and (not S.Demonic:IsAvailable() or S.EyeBeam:Cooldown() > 5) and (not S.Metamorphosis:Cooldown()) then
        if AR.Cast(S.BladeDance) then return ""; end
      end
      -- actions+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
      -- if S.ThrowGlaive:IsCastable() and S.Bloodlet:IsAvailable and Cache.EnemiesCount[5] >= 2 and (not S.MasteroftheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum)) and 
        -- if AR.Cast(S.ThrowGlaive) then return ""; end
      -- end
      -- actions+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
      if S.FelBlade:IsCastable() and Player:FuryDeficit() >= 30 + Player:Buff(S.Prepared) * 8 then
        if AR.Cast(S.FelBlade) then return ""; end
      end
      -- actions+=/eye_beam,if=talent.blind_fury.enabled&(spell_targets.eye_beam_tick>desired_targets|fury.deficit>=35)
      -- if S.EyeBeam:IsCastable() and S.BlindFury:IsAvailable() and 
        -- if AR.Cast(S.EyeBeam) then return ""; end
      -- end
      -- actions+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
      if S.Annihilation:IsCastable() and (S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum) or Player:FuryDeficit() < 30 + Player:Buff(S.Prepared) * 8 or Player:BuffRemains(S.Metamorphosis) < 5) and not Pooling_for_Blade_Dance () then
        if AR.Cast(S.Annihilation) then return ""; end
      end
      -- actions+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
      -- if S.ThrowGlaive:IsCastable() and S.Bloodlet:IsAvailable() and (not S.MasteroftheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum)) and 
        -- if AR.Cast(S.ThrowGlaive) then return ""; end
      -- end
      -- actions+=/eye_beam,if=!talent.demonic.enabled&!talent.blind_fury.enabled&((spell_targets.eye_beam_tick>desired_targets&active_enemies>1)|(!set_bonus.tier19_4pc&raid_event.adds.in>45&!variable.pooling_for_meta&buff.metamorphosis.down&(artifact.anguish_of_the_deceiver.enabled|active_enemies>1)&!talent.chaos_cleave.enabled))
      -- if S.EyeBeam:IsCastable() and not S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and (())
        -- if AR.Cast(S.EyeBeam) then return ""; end
      -- end
      -- # If Demonic is talented, pool fury as Eye Beam is coming off cooldown.
      -- actions+=/demons_bite,if=talent.demonic.enabled&!talent.blind_fury.enabled&buff.metamorphosis.down&cooldown.eye_beam.remains<gcd&fury.deficit>=20
      if S.DemonsBite:IsCastable() and S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and not Player:Buff(S.Metamorphosis) and S.EyeBeam:Cooldown() < Player:GCD() and Player:FuryDeficit() >= 20 then
        if AR.Cast(S.DemonsBite) then return ""; end
      end
      -- actions+=/demons_bite,if=talent.demonic.enabled&!talent.blind_fury.enabled&buff.metamorphosis.down&cooldown.eye_beam.remains<2*gcd&fury.deficit>=45
      if S.DemonsBite:IsCastable() and S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and not Player:Buff(S.Metamorphosis) and S.EyeBeam:Cooldown() < 2 * Player:GCD() and Player:FuryDeficit() >= 45 then
        if AR.Cast(S.DemonsBite) then return ""; end
      end
      -- actions+=/throw_glaive,if=buff.metamorphosis.down&spell_targets>=2
      if S.ThrowGlaive:IsCastable() and not Player:Buff(S.Metamorphosis) and Cache.EnemiesCount[5] >= 2 then
        if AR.Cast(S.ThrowGlaive) then return ""; end
      end
      -- actions+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance&(!talent.demonic.enabled|!cooldown.eye_beam.ready|(talent.blind_fury.enabled&fury.deficit<35))
      if S.ChaosStrike:IsCastable() and (S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum) or Player:FuryDeficit() < 30 + Player:Buff(S.Prepared) * 8) and not Pooling_for_Chaos_Strike () and not Pooling_for_Meta () and not Pooling_for_Blade_Dance () and (not S.Demonic:IsAvailable() or S.EyeBeam:Cooldown() or (S.BlindFury:IsAvailable() and Player:FuryDeficit() < 35)) then
        if AR.Cast(S.ChaosStrike) then return ""; end
      end
      -- # Use Fel Barrage if its nearing max charges, saving it for Momentum and adds if possible.
      -- actions+=/fel_barrage,if=charges=4&buff.metamorphosis.down&(buff.momentum.up|!talent.momentum.enabled)&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>30)
      -- if S.FelBarrage:IsCastable() and S.FelBarrage:Charges() == 4 and not Player:Buff(S.Metamorphosis) and (Player:Buff(S.Momentum) and S.Momentum:IsAvailable()) and 
      --   if AR.Cast(S.FelBarrage) then return ""; end
      -- end
      -- actions+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
      -- if S.FelRush:IsCastable() and not S.Momentum:IsAvailable() and 
      --   if AR.Cast(S.FelRush) then return ""; end
      -- end
      -- actions+=/demons_bite
      if S.DemonsBite:IsCastable() then
        if AR.Cast(S.DemonsBite) then return ""; end
      end
      -- actions+=/throw_glaive,if=buff.out_of_range.up
      -- if S.ThrowGlaive:IsCastable() and 
      --   if AR.Cast(S.ThrowGlaive) then return ""; end
      -- end
      -- actions+=/felblade,if=movement.distance|buff.out_of_range.up
      -- if S.FelBlade:IsCastable() and 
      --   if AR.Cast(S.FelBlade) then return ""; end
      -- end
      -- actions+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
      -- if S.FelRush:IsCastable() and 
      --   if AR.Cast(S.FelRush) then return ""; end
      -- end
      -- actions+=/vengeful_retreat,if=movement.distance>15
      -- if S.VengefulRetreat:IsCastable() and 
      --   if AR.Cast(S.VengefulRetreat) then return ""; end
      -- end
      -- actions+=/throw_glaive,if=!talent.bloodlet.enabled
      if S.ThrowGlaive:IsCastable() and not S.Bloodlet:IsAvailable() then
        if AR.Cast(S.ThrowGlaive) then return ""; end
      end
      return;
    end
  end

  AR.SetAPL(000, APL);


--- ======= SIMC =======
--- Last Update: 03/01/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=flask_of_the_seventh_demon
-- actions.precombat+=/food,type=nightborne_delicacy_platter
-- actions.precombat+=/augmentation,type=defiled
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=old_war
-- actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&talent.demonic.enabled)

-- # Executed every time the actor is available.
-- actions=auto_attack
-- # "Getting ready to use meta" conditions, this is used in a few places.
-- actions+=/variable,name=pooling_for_meta,value=cooldown.metamorphosis.remains<6&fury.deficit>30&!talent.demonic.enabled
-- # Blade Dance conditions. Always if First Blood is talented, otherwise 5+ targets with Chaos Cleave or 3+ targets without.
-- actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*2)
-- # Blade Dance pooling condition, so we don't spend too much fury when we need it soon. No need to pool on
-- # single target since First Blood already makes it cheap enough and delaying it a tiny bit isn't a big deal.
-- actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&fury-40<35-talent.first_blood.enabled*20&(spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*2))
-- # Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
-- actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
-- actions+=/call_action_list,name=cooldown
-- actions+=/pick_up_fragment,if=talent.demonic_appetite.enabled&fury.deficit>=35&(!talent.demonic.enabled|cooldown.eye_beam.remains>5)
-- actions+=/consume_magic
-- # Vengeful Retreat backwards through the target to minimize downtime.
-- actions+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
-- # Fel Rush for Momentum and for fury from Fel Mastery.
-- actions+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
-- # Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
-- actions+=/fel_barrage,if=charges>=5&(buff.momentum.up|!talent.momentum.enabled)&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>30)
-- actions+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
-- actions+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
-- actions+=/death_sweep,if=variable.blade_dance
-- actions+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled
-- actions+=/fel_eruption
-- actions+=/fury_of_the_illidari,if=(active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains)
-- actions+=/eye_beam,if=talent.demonic.enabled&(talent.demon_blades.enabled|(talent.blind_fury.enabled&fury.deficit>=35)|(!talent.blind_fury.enabled&fury.deficit<30))&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>30)
-- actions+=/blade_dance,if=variable.blade_dance&(!talent.demonic.enabled|cooldown.eye_beam.remains>5)&(!cooldown.metamorphosis.ready)
-- actions+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
-- actions+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
-- actions+=/eye_beam,if=talent.blind_fury.enabled&(spell_targets.eye_beam_tick>desired_targets|fury.deficit>=35)
-- actions+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
-- actions+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
-- actions+=/eye_beam,if=!talent.demonic.enabled&!talent.blind_fury.enabled&((spell_targets.eye_beam_tick>desired_targets&active_enemies>1)|(!set_bonus.tier19_4pc&raid_event.adds.in>45&!variable.pooling_for_meta&buff.metamorphosis.down&(artifact.anguish_of_the_deceiver.enabled|active_enemies>1)&!talent.chaos_cleave.enabled))
-- # If Demonic is talented, pool fury as Eye Beam is coming off cooldown.
-- actions+=/demons_bite,if=talent.demonic.enabled&!talent.blind_fury.enabled&buff.metamorphosis.down&cooldown.eye_beam.remains<gcd&fury.deficit>=20
-- actions+=/demons_bite,if=talent.demonic.enabled&!talent.blind_fury.enabled&buff.metamorphosis.down&cooldown.eye_beam.remains<2*gcd&fury.deficit>=45
-- actions+=/throw_glaive,if=buff.metamorphosis.down&spell_targets>=2
-- actions+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance&(!talent.demonic.enabled|!cooldown.eye_beam.ready|(talent.blind_fury.enabled&fury.deficit<35))
-- # Use Fel Barrage if its nearing max charges, saving it for Momentum and adds if possible.
-- actions+=/fel_barrage,if=charges=4&buff.metamorphosis.down&(buff.momentum.up|!talent.momentum.enabled)&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>30)
-- actions+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
-- actions+=/demons_bite
-- actions+=/throw_glaive,if=buff.out_of_range.up
-- actions+=/felblade,if=movement.distance|buff.out_of_range.up
-- actions+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
-- actions+=/vengeful_retreat,if=movement.distance>15
-- actions+=/throw_glaive,if=!talent.bloodlet.enabled

-- actions.cooldown=nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&((active_enemies>desired_targets&active_enemies>1)|raid_event.adds.in>60)
-- actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
-- actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=12
-- actions.cooldown+=/use_item,slot=trinket2,if=!buff.metamorphosis.up&(!talent.first_blood.enabled|!cooldown.blade_dance.ready)&(!talent.nemesis.enabled|cooldown.nemesis.remains>30|target.time_to_die<cooldown.nemesis.remains+3)
-- actions.cooldown+=/metamorphosis,if=!variable.pooling_for_meta&(!talent.demonic.enabled|!cooldown.eye_beam.ready)
-- actions.cooldown+=/potion,name=old_war,if=buff.metamorphosis.remains>25|target.time_to_die<30

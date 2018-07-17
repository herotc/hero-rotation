--- Localize Vars
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



--- APL Local Vars
-- Commons
  local Everyone = HR.Commons.Everyone;
  local Hunter = HR.Commons.Hunter;
  -- Spells
  if not Spell.Hunter then Spell.Hunter = {}; end
  Spell.Hunter.BeastMastery = {
    -- Racials
    ArcaneTorrent                 = Spell(80483),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    -- Abilities
    AspectoftheWild               = Spell(193530),
    BeastCleave                   = Spell(115939),
    BeastCleaveBuff               = Spell(118455),
    BestialWrath                  = Spell(19574),
    CobraShot                     = Spell(193455),
    DireBeast                     = Spell(120679),
    KillCommand                   = Spell(34026),
    MultiShot                     = Spell(2643),
    -- Talents
    AMurderofCrows                = Spell(131894),
    AspectoftheBeast              = Spell(191384),
    Barrage                       = Spell(120360),
    BestialFerocity               = Spell(191413),
    BindingShot                   = Spell(109248),
    ChimaeraShot                  = Spell(53209),
    DireFrenzy                    = Spell(217200),
    DireStable                    = Spell(193532),
    OnewiththePack                = Spell(199528),
    Stampede                      = Spell(201430),
    Volley                        = Spell(194386),
    -- Artifact
    TitansThunder                 = Spell(207068),
    -- Defensive
    AspectoftheTurtle             = Spell(186265),
    Exhilaration                  = Spell(109304),
    -- Utility
    AspectoftheCheetah            = Spell(186257),
    CounterShot                   = Spell(147362),
    Disengage                     = Spell(781),
    FreezingTrap                  = Spell(187650),
    FeignDeath                    = Spell(5384),
    TarTrap                       = Spell(187698),
    -- Legendaries
    ParselsTongueBuff             = Spell(248084),
    -- Misc
    PoolFocus                     = Spell(9999000010),
    PotionOfProlongedPowerBuff    = Spell(229206),
    SephuzBuff                    = Spell(208052),
    -- Macros
  };
  local S = Spell.Hunter.BeastMastery;
  -- Items
  if not Item.Hunter then Item.Hunter = {}; end
  Item.Hunter.BeastMastery = {
    -- Legendaries
    CalloftheWild                 = Item(137101, {9}),
    TheMantleofCommand            = Item(144326, {3}),
    ParselsTongue                 = Item(151805, {5}),
    QaplaEredunWarOrder           = Item(137227, {8}),
    SephuzSecret                  = Item(132452, {11,12}),
    -- Trinkets
    ConvergenceofFates            = Item(140806, {13, 14}),
    -- Potions
    PotionOfProlongedPower        = Item(142117),
  };
  local I = Item.Hunter.BeastMastery;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Hunter.Commons,
    BeastMastery = HR.GUISettings.APL.Hunter.BeastMastery
  };


--- APL Action Lists (and Variables)



--- APL Main
  local function APL ()
    -- Unit Update
    HL.GetEnemies(40);
    -- Defensives
      -- Exhilaration
      if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.BeastMastery.ExhilarationHP then
        if HR.Cast(S.Exhilaration, Settings.BeastMastery.OffGCDasOffGCD.Exhilaration) then return "Cast"; end
      end
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Volley toggle
      if S.Volley:IsCastable() and not Player:Buff(S.Volley) then
        if HR.Cast(S.Volley, Settings.BeastMastery.GCDasOffGCD.Volley) then return; end
      end
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange(40) then
        if HR.CDsON() then
          if S.AMurderofCrows:IsCastable() then
            if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return; end
          end
        end
        if S.KillCommand:IsCastable() then
          if HR.Cast(S.KillCommand) then return; end
        end
        if S.CobraShot:IsCastable() then
          if HR.Cast(S.CobraShot) then return ""; end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- actions+=/counter_shot,if=target.debuff.casting.react // Sephuz Specific
      if S.CounterShot:IsCastable() and Target:IsInterruptible() and (Settings.Commons.CounterShot or (I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer()>=30 and Settings.BeastMastery.CounterShotSephuz)) then
        if HR.CastSuggested(S.CounterShot) then return ""; end
      end
      if HR.CDsON() then
        -- actions+=/arcane_torrent,if=focus.deficit>=30
        if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 then
          if HR.Cast(S.ArcaneTorrent, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/berserking,if=buff.bestial_wrath.remains>7
        if S.Berserking:IsCastable() and Player:BuffRemains(S.BestialWrath) > 7 then
          if HR.Cast(S.Berserking, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/blood_fury,if=buff.bestial_wrath.remains>7
        if S.BloodFury:IsCastable() and Player:BuffRemains(S.BestialWrath) > 7 then
          if HR.Cast(S.BloodFury, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
        end
      end
      -- actions+=/volley,toggle=on
      if S.Volley:IsCastable() and not Player:Buff(S.Volley) then
        if HR.Cast(S.Volley, Settings.BeastMastery.GCDasOffGCD.Volley) then return ""; end
      end
      -- actions+=/potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up
      if Settings.BeastMastery.ShowPoPP and I.PotionOfProlongedPower:IsReady() and Player:Buff(S.BestialWrath) and Player:Buff(S.AspectoftheWild) then
        if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
      end
      -- actions+=/a_murder_of_crows,if=cooldown.bestial_wrath.remains<3|cooldown.bestial_wrath.remains>30|target.time_to_die<16
      if HR.CDsON() and Target:IsInRange(40) and S.AMurderofCrows:IsCastable() and (S.BestialWrath:CooldownRemains() < 3 or S.BestialWrath:CooldownRemains() > 30 or Target:TimeToDie() < 16) then
        if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return ""; end
      end
      -- actions+=/stampede,if=buff.bloodlust.up|buff.bestial_wrath.up|cooldown.bestial_wrath.remains<=2|target.time_to_die<=14
      if HR.CDsON() and S.Stampede:IsCastable() and (Player:HasHeroism() or Player:Buff(S.BestialWrath) or ((S.BestialWrath:CooldownRemains() <= 2 or not HR.CDsON()) or (Target:TimeToDie() <= 14))) then
        if HR.Cast(S.Stampede) then return ""; end
      end
      -- actions+=/bestial_wrath,if=!buff.bestial_wrath.up
      if HR.CDsON() and S.BestialWrath:IsCastable() and not Player:Buff(S.BestialWrath) then
        if HR.Cast(S.BestialWrath, Settings.BeastMastery.OffGCDasOffGCD.BestialWrath) then return ""; end
      end
      -- # With both AotW cdr sources and OwtP, there's no visible benefit if it's delayed, use it on cd. With only one or neither, pair it with Bestial Wrath. Also use it if the fight will end when the buff does.
      -- actions+=/aspect_of_the_wild,if=(equipped.call_of_the_wild&equipped.convergence_of_fates&talent.one_with_the_pack.enabled)|buff.bestial_wrath.remains>7|target.time_to_die<12
      if HR.CDsON() and S.AspectoftheWild:IsCastable() and ((I.CalloftheWild:IsEquipped() and I.ConvergenceofFates:IsEquipped() and S.OnewiththePack:IsAvailable()) or Player:BuffRemains(S.BestialWrath) > 7 or Target:TimeToDie() < 12) then
        if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.OffGCDasOffGCD.AspectoftheWild) then return ""; end
      end
      -- actions+=/kill_command,target_if=min:bestial_ferocity.remains,if=equipped.qapla_eredun_war_order
      if S.AspectoftheBeast:IsAvailable() and S.KillCommand:IsCastable() and I.QaplaEredunWarOrder:IsEquipped() then
        if Target:DebuffRefreshable(S.BestialFerocity, 1.8) then
          if HR.Cast(S.KillCommand) then return ""; end
        end
        if HR.AoEON() then
          local BestUnit, BestUnitBFRemains;
          BestUnit, BestUnitBFRemains = nil, 10;
          for _, Unit in pairs(Cache.Enemies[40]) do
            local BFRemains = Unit:DebuffRemains(S.BestialFerocity);
            if Everyone.UnitIsCycleValid(Unit) and BFRemains < BestUnitBFRemains then
              BestUnit, BestUnitBFRemains = Unit, BFRemains;
            end
          end
          if BestUnit then
            HR.CastLeftNameplate(BestUnit, S.KillCommand);
          end
        end
      end
      -- # Hold charges of Dire Beast as long as possible to take advantage of T20 2pc unless T19 2pc is on. With Qa'pla, also try not to waste Kill Command cdr if it is just about to come off cooldown.
      -- NOTE : Change cooldown.kill_command.remains>=1 to cooldown.kill_command.remains>=gcd.max
      -- actions+=/dire_beast,if=((!equipped.qapla_eredun_war_order|cooldown.kill_command.remains>=1)&(set_bonus.tier19_2pc|!buff.bestial_wrath.up))|full_recharge_time<gcd.max|cooldown.titans_thunder.up|spell_targets>1
      if S.DireBeast:IsCastable() and (((not I.QaplaEredunWarOrder:IsEquipped() or S.KillCommand:CooldownRemains() >= Player:GCD()) and (HL.Tier19_2Pc or not Player:Buff(S.BestialWrath))) or S.DireBeast:FullRechargeTime() < Player:GCD() or S.TitansThunder:CooldownUp() or Cache.EnemiesCount[40] > 1) then
        if HR.Cast(S.DireBeast) then return ""; end
      end
      -- actions+=/dire_frenzy,if=(pet.cat.buff.dire_frenzy.remains<=gcd.max*1.2)|full_recharge_time<gcd.max|target.time_to_die<9
      if S.DireFrenzy:IsCastable() and ((Pet:BuffRemains(S.DireFrenzy) < Player:GCD() * 1.2) or S.DireFrenzy:FullRechargeTime() < Player:GCD() or Target:TimeToDie() < 9) then
        if HR.Cast(S.DireFrenzy) then return ""; end
      end
      -- actions+=/barrage,if=spell_targets.barrage>1
      if HR.AoEON() and S.Barrage:IsCastable() and Cache.EnemiesCount[40] > 1 then
        HR.CastSuggested(S.Barrage);
      end
      -- actions+=/titans_thunder,if=(talent.dire_frenzy.enabled&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains>35))|buff.bestial_wrath.up
      if HR.CDsON() and S.TitansThunder:IsCastable() and ((S.DireFrenzy:IsAvailable() and (Player:Buff(S.BestialWrath) or S.BestialWrath:CooldownRemains() > 35)) or Player:Buff(S.BestialWrath)) then
        if HR.Cast(S.TitansThunder, Settings.BeastMastery.OffGCDasOffGCD.TitansThunder) then return ""; end
      end
      -- actions+=/multishot,if=spell_targets>4&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
      if HR.AoEON() and S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 4 and (Pet:BuffRemains(S.BeastCleaveBuff) < Player:GCD() or not Pet:Buff(S.BeastCleaveBuff)) then
        if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
      end
      -- actions+=/kill_command
      if S.KillCommand:IsCastable() then
        if HR.Cast(S.KillCommand) then return ""; end
      end
      -- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
      if HR.AoEON() and S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and (Pet:BuffRemains(S.BeastCleaveBuff) < Player:GCD() or not Pet:Buff(S.BeastCleaveBuff)) then
        if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
      end
      -- actions+=/chimaera_shot,if=focus<90
      if S.ChimaeraShot:IsCastable() and Target:IsInRange(40) and Player:Focus() < 90 then
        if HR.Cast(S.ChimaeraShot) then return ""; end
      end
      -- actions+=/cobra_shot,if=(cooldown.kill_command.remains>focus.time_to_max&cooldown.bestial_wrath.remains>focus.time_to_max)|(buff.bestial_wrath.up&(spell_targets.multishot=1|focus.regen*cooldown.kill_command.remains>action.kill_command.cost))|target.time_to_die<cooldown.kill_command.remains|(equipped.parsels_tongue&buff.parsels_tongue.remains<=gcd.max*2)
      if S.CobraShot:IsCastable() and Target:IsInRange(40) and ((S.KillCommand:CooldownRemains() > Player:FocusTimeToMax() and (S.BestialWrath:CooldownRemains() > Player:FocusTimeToMax() or not HR.CDsON())) or (Player:Buff(S.BestialWrath) and (Player:FocusRegen()*S.KillCommand:CooldownRemains() > S.KillCommand:Cost())) or Target:TimeToDie() < S.KillCommand:CooldownRemains() or (I.ParselsTongue:IsEquipped() and Player:BuffRemains(S.ParselsTongueBuff) <= Player:GCD() * 2)) then
        if HR.Cast(S.CobraShot) then return ""; end
      end
      -- actions+=/dire_beast,if=buff.bestial_wrath.up
      if S.DireBeast:IsCastable() and Player:Buff(S.BestialWrath) then
        if HR.Cast(S.DireBeast) then return ""; end
      end
      -- Pool
      if HR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      return;
    end
  end

  HR.SetAPL(253, APL);


--- Last Update: 09/19/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/counter_shot,if=target.debuff.casting.react
-- actions+=/use_items
-- actions+=/arcane_torrent,if=focus.deficit>=30
-- actions+=/berserking,if=buff.bestial_wrath.remains>7
-- actions+=/blood_fury,if=buff.bestial_wrath.remains>7
-- actions+=/volley,toggle=on
-- actions+=/potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up
-- actions+=/a_murder_of_crows,if=cooldown.bestial_wrath.remains<3|cooldown.bestial_wrath.remains>30|target.time_to_die<16
-- actions+=/stampede,if=buff.bloodlust.up|buff.bestial_wrath.up|cooldown.bestial_wrath.remains<=2|target.time_to_die<=14
-- actions+=/bestial_wrath,if=!buff.bestial_wrath.up
-- # With both AotW cdr sources and OwtP, there's no visible benefit if it's delayed, use it on cd. With only one or neither, pair it with Bestial Wrath. Also use it if the fight will end when the buff does.
-- actions+=/aspect_of_the_wild,if=(equipped.call_of_the_wild&equipped.convergence_of_fates&talent.one_with_the_pack.enabled)|buff.bestial_wrath.remains>7|target.time_to_die<12
-- actions+=/kill_command,target_if=min:bestial_ferocity.remains,if=equipped.qapla_eredun_war_order
-- # Hold charges of Dire Beast as long as possible to take advantage of T20 2pc unless T19 2pc is on. With Qa'pla, also try not to waste Kill Command cdr if it is just about to come off cooldown.
-- actions+=/dire_beast,if=((!equipped.qapla_eredun_war_order|cooldown.kill_command.remains>=1)&(set_bonus.tier19_2pc|!buff.bestial_wrath.up))|full_recharge_time<gcd.max|cooldown.titans_thunder.up|spell_targets>1
-- actions+=/dire_frenzy,if=(pet.cat.buff.dire_frenzy.remains<=gcd.max*1.2)|full_recharge_time<gcd.max|target.time_to_die<9
-- actions+=/barrage,if=spell_targets.barrage>1
-- actions+=/titans_thunder,if=(talent.dire_frenzy.enabled&(buff.bestial_wrath.up|cooldown.bestial_wrath.remains>35))|buff.bestial_wrath.up
-- actions+=/multishot,if=spell_targets>4&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
-- actions+=/kill_command
-- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
-- actions+=/chimaera_shot,if=focus<90
-- actions+=/cobra_shot,if=(cooldown.kill_command.remains>focus.time_to_max&cooldown.bestial_wrath.remains>focus.time_to_max)|(buff.bestial_wrath.up&(spell_targets.multishot=1|focus.regen*cooldown.kill_command.remains>action.kill_command.cost))|target.time_to_die<cooldown.kill_command.remains|(equipped.parsels_tongue&buff.parsels_tongue.remains<=gcd.max*2)
-- actions+=/dire_beast,if=buff.bestial_wrath.up

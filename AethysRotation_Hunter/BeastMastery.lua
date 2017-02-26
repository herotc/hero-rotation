--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCore_Cache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- APL Local Vars
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
    BeastialWrath                 = Spell(19574),
    CobraShot                     = Spell(193455),
    DireBeast                     = Spell(120679),
    KillCommand                   = Spell(34026),
    MultiShot                     = Spell(2643),
    -- Talents
    AMurderofCrows                = Spell(131894),
    Barrage                       = Spell(120360),
    BindingShot                   = Spell(109248),
    ChimaeraShot                  = Spell(53209),
    DireFrenzy                    = Spell(217200),
    DireStable                    = Spell(193532),
    Stampede                      = Spell(201430),
    Volley                        = Spell(194386),
    -- Artifact
    TitansThunder                  = Spell(207068),
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
    -- Misc
    PoolFocus                     = Spell(9999000010),
    -- Macros
  };
  local S = Spell.Hunter.BeastMastery;
  -- Items
  if not Item.Hunter then Item.Hunter = {}; end
  Item.Hunter.BeastMastery = {
    -- Legendaries
    TheMantleofCommand            = Item(144326) -- 3
  };
  local I = Item.Hunter.BeastMastery;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Hunter.Commons,
    BeastMastery = AR.GUISettings.APL.Hunter.BeastMastery
  };


--- APL Action Lists (and Variables)
  


--- APL Main
  local function APL ()
    -- Unit Update
    AC.GetEnemies(40);
    -- Defensives
      -- Exhilaration
      ShouldReturn = AR.Commons.Hunter.Exhilaration(S.Exhilaration);
      if ShouldReturn then return ShouldReturn; end
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Volley toggle
      if S.Volley:IsCastable() and not Player:Buff(S.Volley) then
        if AR.Cast(S.Volley, Settings.BeastMastery.GCDasOffGCD.Volley) then return; end
      end
      -- Opener
      if AR.Commons.TargetIsValid() and Target:IsInRange(40) then
        if AR.CDsON() then
          if S.AMurderofCrows:IsCastable() then
            if AR.Cast(S.AMurderofCrows) then return; end
          end
          if S.BeastialWrath:IsCastable() then
            if AR.Cast(S.BeastialWrath) then return; end
          end
        end
        if S.KillCommand:IsCastable() then
          if AR.Cast(S.KillCommand) then return; end
        end
      end
      return;
    end
    -- In Combat
    if AR.Commons.TargetIsValid() then
      if AR.CDsON() then
        -- actions+=/arcane_torrent,if=focus.deficit>=30
        if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 then
          if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return; end
        end
        -- actions+=/berserking
        if S.Berserking:IsCastable() then
          if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return; end
        end
        -- actions+=/blood_fury
        if S.BloodFury:IsCastable() then
          if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return; end
        end
      end
      -- actions+=/volley,toggle=on
      if S.Volley:IsCastable() and not Player:Buff(S.Volley) then
        if AR.Cast(S.Volley, Settings.BeastMastery.GCDasOffGCD.Volley) then return; end
      end
      -- actions+=/potion,name=prolonged_power,if=buff.bestial_wrath.remains|!cooldown.beastial_wrath.remains
      -- if I.PotionofProlongedPower:IsUsable() and (Player:BuffRemains(BeastialWrath) or not S.BeastialWrath:Cooldown())
        -- if AR.UsePotion(I.PotionofProlongedPower) then return; end
      -- end
      -- actions+=/a_murder_of_crows
      if AR.CDsON() and Target:IsInRange(40) and S.AMurderofCrows:IsCastable() then
        if AR.Cast(S.AMurderofCrows) then return; end
      end
      -- actions+=/stampede,if=buff.bloodlust.up|buff.bestial_wrath.up|cooldown.bestial_wrath.remains<=2|target.time_to_die<=14
      if AR.CDsON() and S.Stampede:IsCastable() and (Player:HasHeroism() or Player:Buff(S.BeastialWrath) or ((S.BeastialWrath:Cooldown() <= 2 or not AR.CDsON()) or (Target:TimeToDie() <= 14))) then
        if AR.Cast(S.Stampede) then return; end
      end
      -- actions+=/dire_beast,if=cooldown.bestial_wrath.remains>3
      if S.DireBeast:IsCastable() and (S.BeastialWrath:Cooldown() > 3 or not AR.CDsON())  then
        if AR.Cast(S.DireBeast) then return; end
      end
      -- actions+=/dire_frenzy,if=(cooldown.bestial_wrath.remains>6&(!equipped.the_mantle_of_command|pet.cat.buff.dire_frenzy.remains<=gcd.max*1.2))|(charges>=2&focus.deficit>=25+talent.dire_stable.enabled*12)|target.time_to_die<9
      -- NOTE: Increased gcd.max*1.2 to gcd.max*2.2 to take in concideration human factor.
      if S.DireFrenzy:IsCastable() and (((S.BeastialWrath:Cooldown() > 6 or not AR.CDsON()) and (not I.TheMantleofCommand:IsEquipped(3) 
      or Pet:BuffRemains(S.DireFrenzy) <= Player:GCD() * 2.2 )) or (S.DireFrenzy:Charges() >= 2 and Player:FocusDeficit() >= 25 + (S.DireStable:IsAvailable() and 25 or 0)) 
      or (Target:TimeToDie() < 9)) then
        if AR.Cast(S.DireFrenzy) then return; end
      end
      -- actions+=/aspect_of_the_wild,if=buff.bestial_wrath.up|target.time_to_die<12
      if AR.CDsON() and S.AspectoftheWild:IsCastable() and (Player:Buff(S.BeastialWrath) or Target:TimeToDie() < 12) then
        if AR.Cast(S.AspectoftheWild, Settings.BeastMastery.OffGCDasOffGCD.AspectoftheWild) then return; end
      end
      -- actions+=/barrage,if=spell_targets.barrage>1
      if AR.AoEON() and S.Barrage:IsCastable() and Cache.EnemiesCount[40] > 1 then
        AR.CastSuggested(S.Barrage);
      end
      -- actions+=/titans_thunder,if=talent.dire_frenzy.enabled|cooldown.dire_beast.remains>=3|(buff.bestial_wrath.up&pet.dire_beast.active)
      if AR.CDsON() and S.TitansThunder:IsCastable() and (S.DireFrenzy:IsAvailable() or S.DireBeast:Cooldown() >= 3 or (Player:Buff(S.BeastialWrath) and Player:Buff(S.DireBeast))) then
        if AR.Cast(S.TitansThunder, Settings.BeastMastery.OffGCDasOffGCD.TitansThunder) then return; end
      end
      -- actions+=/bestial_wrath
      if AR.CDsON() and S.BeastialWrath:IsCastable() then
        if AR.Cast(S.BeastialWrath, Settings.BeastMastery.OffGCDasOffGCD.BeastialWrath) then return; end
      end
      -- actions+=/multishot,if=spell_targets>4&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
      if AR.AoEON() and S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 4 and (Pet:BuffRemains(S.BeastCleaveBuff) < Player:GCD() or not Pet:Buff(S.BeastCleaveBuff)) then
        AR.CastSuggested(S.MultiShot);
      end
      -- actions+=/kill_command
      if S.KillCommand:IsCastable() then
        if AR.Cast(S.KillCommand) then return; end
      end
      -- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max*2|pet.cat.buff.beast_cleave.down)
      if AR.AoEON() and S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and (Pet:BuffRemains(S.BeastCleaveBuff) < Player:GCD() * 2 or not Pet:Buff(S.BeastCleaveBuff)) then
        AR.CastSuggested(S.MultiShot);
      end
      -- actions+=/chimaera_shot,if=focus<90
      if S.ChimaeraShot:IsCastable() and Target:IsInRange(40) and Player:Focus() < 90 then
        if AR.Cast(S.ChimaeraShot) then return; end
      end
      -- actions+=/cobra_shot,if=(cooldown.kill_command.remains>focus.time_to_max&cooldown.bestial_wrath.remains>focus.time_to_max)|(buff.bestial_wrath.up&focus.regen*cooldown.kill_command.remains>30)|target.time_to_die<cooldown.kill_command.remains
      if S.CobraShot:IsCastable() and Target:IsInRange(40) and ((S.KillCommand:Cooldown() > Player:FocusTimeToMax() and (S.BeastialWrath:Cooldown() > Player:FocusTimeToMax() or not AR.CDsON())) or (Player:Buff(S.BeastialWrath) and Player:FocusRegen()*S.KillCommand:Cooldown() > 30) or Target:TimeToDie() < S.KillCommand:Cooldown()) then
        if AR.Cast(S.CobraShot) then return; end
      end
      if AR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      return;
    end
  end

  AR.SetAPL(253, APL);


--- Last Update: 02/25/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=flask_of_the_seventh_demon
-- actions.precombat+=/food,type=nightborne_delicacy_platter
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=prolonged_power
-- actions.precombat+=/augmentation,type=defiled

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/arcane_torrent,if=focus.deficit>=30
-- actions+=/berserking
-- actions+=/blood_fury
-- actions+=/volley,toggle=on
-- actions+=/potion,name=prolonged_power,if=buff.bestial_wrath.remains|!cooldown.beastial_wrath.remains
-- actions+=/a_murder_of_crows
-- actions+=/stampede,if=buff.bloodlust.up|buff.bestial_wrath.up|cooldown.bestial_wrath.remains<=2|target.time_to_die<=14
-- actions+=/dire_beast,if=cooldown.bestial_wrath.remains>3
-- actions+=/dire_frenzy,if=(cooldown.bestial_wrath.remains>6&(!equipped.the_mantle_of_command|pet.cat.buff.dire_frenzy.remains<=gcd.max*1.2))|(charges>=2&focus.deficit>=25+talent.dire_stable.enabled*12)|target.time_to_die<9
-- actions+=/aspect_of_the_wild,if=buff.bestial_wrath.up|target.time_to_die<12
-- actions+=/barrage,if=spell_targets.barrage>1
-- actions+=/titans_thunder,if=talent.dire_frenzy.enabled|cooldown.dire_beast.remains>=3|(buff.bestial_wrath.up&pet.dire_beast.active)
-- actions+=/bestial_wrath
-- actions+=/multishot,if=spell_targets>4&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
-- actions+=/kill_command
-- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max*2|pet.cat.buff.beast_cleave.down)
-- actions+=/chimaera_shot,if=focus<90
-- actions+=/cobra_shot,if=(cooldown.kill_command.remains>focus.time_to_max&cooldown.bestial_wrath.remains>focus.time_to_max)|(buff.bestial_wrath.up&focus.regen*cooldown.kill_command.remains>30)|target.time_to_die<cooldown.kill_command.remains
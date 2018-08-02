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
    AncestralCall                 = Spell(274738),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    Fireblood                     = Spell(265221),
    GiftoftheNaaru                = Spell(59547),
    LightsJudgment                = Spell(255647),
    -- Abilities
    AspectoftheWild               = Spell(193530),
    BardedShot                    = Spell(217200),
    Frenzy                        = Spell(272790),
    BeastCleave                   = Spell(115939),
    BeastCleaveBuff               = Spell(118455),
    BestialWrath                  = Spell(19574),
    CobraShot                     = Spell(193455),
    KillCommand                   = Spell(34026),
    MultiShot                     = Spell(2643),
    -- Pet
    CallPet                       = Spell(883),
    Intimidation                  = Spell(19577),
    MendPet                       = Spell(136),
    RevivePet                     = Spell(982),
    -- Talents
    AMurderofCrows                = Spell(131894),
    AnimalCompanion               = Spell(267116),
    AspectoftheBeast              = Spell(191384),
    Barrage                       = Spell(120360),
    BindingShot                   = Spell(109248),
    ChimaeraShot                  = Spell(53209),
    DireBeast                     = Spell(120679),
    KillerInstinct                = Spell(273887),
    OnewiththePack                = Spell(199528),
    ScentofBlood                  = Spell(193532),
    SpittingCobra                 = Spell(194407),
    Stampede                      = Spell(201430),
    ThrilloftheHunt               = Spell(257944),
    VenomousBite                  = Spell(257891),
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
    -- Opener
    if Everyone.TargetIsValid() and Target:IsInRange(40) then
      if HR.CDsON() then
        if S.AMurderofCrows:IsCastable() then
          if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return; end
        end
      end
      if HR.CDsON() and S.BestialWrath:IsCastable() and not Player:Buff(S.BestialWrath) then
        if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return ""; end
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
    -- call pet
    if not Pet:IsActive() then
      if HR.Cast(S.CallPet, Settings.BeastMastery.GCDasOffGCD.CallPet) then return ""; end
    end
    -- actions+=/counter_shot,if=target.debuff.casting.react // Sephuz Specific
    if S.CounterShot:IsCastable() and Target:IsInterruptible() and (Settings.Commons.CounterShot or (I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer()>=30 and Settings.BeastMastery.CounterShotSephuz)) then
      if HR.CastSuggested(S.CounterShot) then return ""; end
    end
    -- same for Intimidation
    if S.Intimidation:IsCastable() and Target:IsInterruptible() and (Settings.BeastMastery.GCDasOffGCD.Intimidation or (I.SephuzSecret:IsEquipped() and S.SephuzBuff:TimeSinceLastAppliedOnPlayer()>=30 and Settings.BeastMastery.IntimidationSephuz)) then
      if HR.CastSuggested(S.Intimidation) then return ""; end
    end
    if HR.CDsON() then
      -- actions+=/arcane_torrent,if=focus.deficit>=30
      if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 then
        if HR.Cast(S.ArcaneTorrent, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- actions+=/berserking,if=cooldown.bestial_wrath.remains>30
      if S.Berserking:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
        if HR.Cast(S.Berserking, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- actions+=/blood_fury,if=buff.bestial_wrath.remains>7
      if S.BloodFury:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
        if HR.Cast(S.BloodFury, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- actions+=/ancestral_call,if=cooldown.bestial_wrath.remains>30
      if S.AncestralCall:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
        if HR.Cast(S.AncestralCall, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- actions+=/fireblood,if=cooldown.bestial_wrath.remains>30
      if S.Fireblood:IsCastable() and S.BestialWrath:CooldownRemains() > 30 then
        if HR.Cast(S.Fireblood, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsCastable() then
        if HR.Cast(S.LightsJudgment, Settings.BeastMastery.OffGCDasOffGCD.Racials) then return ""; end
      end
    end
    -- actions+=/potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up
    if Settings.BeastMastery.ShowPoPP and I.PotionOfProlongedPower:IsReady() and Player:Buff(S.BestialWrath) and Player:Buff(S.AspectoftheWild) then
      if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
    end
    -- actions+=/barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max
    if S.BardedShot:IsCastable() and (Pet:Buff(S.Frenzy) and (Pet:BuffRemains(S.Frenzy) < Player:GCD() * 1.5)) then
        if HR.Cast(S.BardedShot) then return ""; end
    end
    -- actions+=/a_murder_of_crows
    if HR.CDsON() and Target:IsInRange(40) and S.AMurderofCrows:IsCastable() then
      if HR.Cast(S.AMurderofCrows, Settings.BeastMastery.GCDasOffGCD.AMurderofCrows) then return ""; end
    end
    -- actions+=/spitting_cobra
    if HR.CDsON() and Target:IsInRange(40) and S.SpittingCobra:IsCastable() then
      if HR.Cast(S.SpittingCobra, Settings.BeastMastery.GCDasOffGCD.SpittingCobra) then return ""; end
    end
    -- actions+=/stampede,if=buff.bestial_wrath.up|cooldown.bestial_wrath.remains<gcd|target.time_to_die<15
    if HR.CDsON() and S.Stampede:IsCastable() and (Player:Buff(S.BestialWrath) or ((S.BestialWrath:CooldownRemains() <= 2 or not AR.CDsON()) or (Target:TimeToDie() <= 15))) then
      if HR.Cast(S.Stampede, Settings.BeastMastery.GCDasOffGCD.Stampede) then return ""; end
    end
    -- actions+=/aspect_of_the_wild
    if HR.CDsON() and S.AspectoftheWild:IsCastable() then
      if HR.Cast(S.AspectoftheWild, Settings.BeastMastery.GCDasOffGCD.AspectoftheWild) then return ""; end
    end
    -- actions+=/bestial_wrath,if=!buff.bestial_wrath.up
    if HR.CDsON() and S.BestialWrath:IsCastable() and not Player:Buff(S.BestialWrath) then
      if HR.Cast(S.BestialWrath, Settings.BeastMastery.GCDasOffGCD.BestialWrath) then return ""; end
    end
    -- actions+=/multishot,if=spell_targets>2&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
    if HR.AoEON() and S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 2 and (Pet:BuffRemains(S.BeastCleaveBuff) < Player:GCD() or not Pet:Buff(S.BeastCleaveBuff)) then
      if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
    end
    -- actions+=/chimaera_shot
    if S.ChimaeraShot:IsCastable() then
      if HR.Cast(S.ChimaeraShot) then return ""; end
    end
    -- actions+=/kill_command
    if S.KillCommand:IsCastable() then
      if HR.Cast(S.KillCommand) then return ""; end
    end
    -- actions+=/dire_beast
    if S.DireBeast:IsCastable() then
      if HR.Cast(S.DireBeast) then return ""; end
    end
    -- actions+=/barbed_shot,if=pet.cat.buff.frenzy.down&charges_fractional>1.4|full_recharge_time<gcd.max|target.time_to_die<9
    if S.BardedShot:IsCastable() and (not Pet:Buff(S.Frenzy) and S.BardedShot:ChargesFractional() > 1.4 or S.BardedShot:FullRechargeTime() < Player:GCD() or Target:TimeToDie() < 9) then
      if HR.Cast(S.BardedShot) then return ""; end
    end
    -- actions+=/barrage
    if HR.AoEON() and S.Barrage:IsCastable() then
      HR.CastSuggested(S.Barrage);
    end
    -- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
    if HR.AoEON() and S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and (Pet:BuffRemains(S.BeastCleaveBuff) < Player:GCD() or not Pet:Buff(S.BeastCleaveBuff)) then
      if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
    end
    -- actions+=/cobra_shot,if=(active_enemies<2|cooldown.kill_command.remains>focus.time_to_max)&(buff.bestial_wrath.up&active_enemies>1|cooldown.kill_command.remains>1+gcd&cooldown.bestial_wrath.remains>focus.time_to_max|focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost)
    if S.CobraShot:IsCastable() and Target:IsInRange(40) and ((Cache.EnemiesCount[40] < 2 or S.KillCommand:CooldownRemains() > Player:FocusTimeToMax()) and (Player:Buff(S.BestialWrath) and Cache.EnemiesCount[40] > 1 or S.KillCommand:CooldownRemains() > 1 + Player:GCD() and S.BestialWrath:CooldownRemains() > Player:FocusTimeToMax() or S.CobraShot:Cost() + Player:FocusRegen() * (S.KillCommand:CooldownRemains() - 1) > S.KillCommand:Cost())) then
      if HR.Cast(S.CobraShot) then return ""; end
    end
    -- Pool
    if HR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      return;
    end
    -- heal pet
    if Pet:IsActive() and Pet:HealthPercentage() <= 75 and not Pet:Buff(S.MendPet) then
      if HR.Cast(S.MendPet, Settings.BeastMastery.GCDasOffGCD.MendPet) then return ""; end
    end
  end

HR.SetAPL(253, APL);


--- Last Update: 07/17/2018

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/aspect_of_the_wild

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/counter_shot,if=equipped.sephuzs_secret&target.debuff.casting.react&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up
-- actions+=/use_items
-- actions+=/berserking,if=cooldown.bestial_wrath.remains>30
-- actions+=/blood_fury,if=cooldown.bestial_wrath.remains>30
-- actions+=/ancestral_call,if=cooldown.bestial_wrath.remains>30
-- actions+=/fireblood,if=cooldown.bestial_wrath.remains>30
-- actions+=/lights_judgment
-- actions+=/potion,if=buff.bestial_wrath.up&buff.aspect_of_the_wild.up
-- actions+=/barbed_shot,if=pet.cat.buff.frenzy.up&pet.cat.buff.frenzy.remains<=gcd.max
-- actions+=/a_murder_of_crows
-- actions+=/spitting_cobra
-- actions+=/stampede,if=buff.bestial_wrath.up|cooldown.bestial_wrath.remains<gcd|target.time_to_die<15
-- actions+=/aspect_of_the_wild
-- actions+=/bestial_wrath,if=!buff.bestial_wrath.up
-- actions+=/multishot,if=spell_targets>2&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
-- actions+=/chimaera_shot
-- actions+=/kill_command
-- actions+=/dire_beast
-- actions+=/barbed_shot,if=pet.cat.buff.frenzy.down&charges_fractional>1.4|full_recharge_time<gcd.max|target.time_to_die<9
-- actions+=/barrage
-- actions+=/multishot,if=spell_targets>1&(pet.cat.buff.beast_cleave.remains<gcd.max|pet.cat.buff.beast_cleave.down)
-- actions+=/cobra_shot,if=(active_enemies<2|cooldown.kill_command.remains>focus.time_to_max)&(buff.bestial_wrath.up&active_enemies>1|cooldown.kill_command.remains>1+gcd&cooldown.bestial_wrath.remains>focus.time_to_max|focus-cost+focus.regen*(cooldown.kill_command.remains-1)>action.kill_command.cost)


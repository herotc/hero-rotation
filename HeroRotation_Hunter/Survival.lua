--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
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
  Spell.Hunter.Survival = {
    -- Racials
    ArcaneTorrent                 = Spell(80483),
    AncestralCall                 = Spell(274738),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    Fireblood                     = Spell(265221),
    GiftoftheNaaru                = Spell(59547),
    LightsJudgment                = Spell(255647),
    -- Abilities
    AspectoftheEagle              = Spell(186289),
    Carve                         = Spell(187708),
    CoordinatedAssault            = Spell(266779),
    Harpoon                       = Spell(190925),
    KillCommand                   = Spell(259489),
    RaptorStrike                  = Spell(186270),
    RaptorStrikeRanged            = Spell(265189),
    SerpentSting                  = Spell(259491),
    WildfireBomb                  = Spell(259495),
    WildfireBombDot               = Spell(269747),
    -- Talents
    AlphaPredator                 = Spell(269737),
    AMurderofCrows                = Spell(131894),
    BirdsofPrey                   = Spell(260331),
    Bloodseeker                   = Spell(260248),
    KillCommandDot                = Spell(259277),
    Butchery                      = Spell(212436),
    Chakrams                      = Spell(259391),
    FlankingStrike                = Spell(269751),
    GuerrillaTactics              = Spell(264332),
    InternalBleeding              = Spell(270343),
    HydrasBite                    = Spell(260241),
    MongooseBite                  = Spell(259387),
    MongooseFury                  = Spell(259388),
    ShrapnelBomb                  = Spell(270335),
    SteelTrap                     = Spell(162488),
    SteelTrapDot                  = Spell(162487),
    TermsofEngagement             = Spell(265895),
    TipoftheSpear                 = Spell(260285),
    TipoftheSpearBuff             = Spell(260286),
    VipersVenom                   = Spell(268501),
    WildfireInfusion              = Spell(271014),
    -- Defensive
    AspectoftheTurtle             = Spell(186265),
    Exhilaration                  = Spell(109304),
    -- Utility
    -- Legendaries
    -- Misc
    ExposedFlank                  = Spell(252094),
    PotionOfProlongedPowerBuff    = Spell(229206),
    SephuzBuff                    = Spell(208052),
    PoolFocus                     = Spell(9999000010)
    -- Macros
  };
  local S = Spell.Hunter.Survival;
  -- Items
  if not Item.Hunter then Item.Hunter = {}; end
  Item.Hunter.Survival = {
    -- Legendaries
    FrizzosFinger                 = Item(137043, {11, 12}),
    SephuzSecret                  = Item(132452, {11,12}),
    -- Trinkets
    ConvergenceofFates            = Item(140806, {13, 14}),
    -- Potions
    PotionOfProlongedPower        = Item(142117)
  };
  local I = Item.Hunter.Survival;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Hunter.Commons,
    Survival = HR.GUISettings.APL.Hunter.Survival
  };


--- APL Action Lists (and Variables)
  -- actions+=/variable,name=can_gcd,value=!talent.mongoose_bite.enabled|buff.mongoose_fury.down|(buff.mongoose_fury.remains-(((buff.mongoose_fury.remains*focus.regen+focus)%action.mongoose_bite.cost)*gcd.max)>gcd.max)
  local function CanGCD ()
    return not S.MongooseBite:IsAvailable() or not Player:Buff(S.MongooseFury) or (Player:BuffRemains(S.MongooseFury) - (((Player:BuffRemains(S.MongooseFury) * Player:FocusRegen() + Player:Focus()) % S.MongooseBite:Cost()) * Player:GCD()) > Player:GCD());
  end

--- APL Main
  local function APL ()
    -- Unit Update
    HL.GetEnemies(40);
    HL.GetEnemies(12);
    HL.GetEnemies(8);
    HL.GetEnemies(5);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
      -- Exhilaration
      if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Survival.ExhilarationHP then
        if HR.Cast(S.Exhilaration, Settings.Survival.GCDasOffGCD.Exhilaration) then return "Cast"; end
      end
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown

      -- Opener
      if Everyone.TargetIsValid() then
        if not Target:IsInRange(5) and Target:IsInRange(40) and S.Harpoon:IsCastable() then
          if HR.Cast(S.Harpoon) then return ""; end
        end
        if Target:IsInRange(5) then
          if S.RaptorStrike:IsCastable() then
            if HR.Cast(S.RaptorStrike) then return ""; end
          end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- actions+=/use_items
      if HR.CDsON() then
        -- actions+=/arcane_torrent,if=focus.deficit>=30
        if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 then
          if HR.Cast(S.ArcaneTorrent, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/berserking,if=cooldown.coordinated_assault.remains>30
        if S.Berserking:IsCastable() and S.CoordinatedAssault:CooldownRemains() > 30 then
          if HR.Cast(S.Berserking, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/blood_fury,if=cooldown.coordinated_assault.remains>30
        if S.BloodFury:IsCastable() and S.CoordinatedAssault:CooldownRemains() > 30 then
          if HR.Cast(S.BloodFury, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/ancestral_call,if=cooldown.coordinated_assault.remains>30
        if S.AncestralCall:IsCastable() and S.CoordinatedAssault:CooldownRemains() > 30 then
          if HR.Cast(S.AncestralCall, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/fireblood,if=cooldown.coordinated_assault.remains>30
        if S.Fireblood:IsCastable() and S.CoordinatedAssault:CooldownRemains() > 30 then
          if HR.Cast(S.Fireblood, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/lights_judgment
        if S.LightsJudgment:IsCastable() then
          if HR.Cast(S.LightsJudgment, Settings.Survival.OffGCDasOffGCD.Racials) then return ""; end
        end
      end
      -- actions+=/potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)
      if Settings.Survival.ShowPoPP and I.PotionOfProlongedPower:IsReady() and Player:Buff(S.CoordinatedAssault) then
        if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
      end
      -- actions+=/steel_trap
      if HR.CDsON() and Target:IsInRange(40) and S.SteelTrap:IsCastable() then
        if HR.Cast(S.SteelTrap) then return ""; end
      end
      -- actions+=/a_murder_of_crows
      if HR.CDsON() and Target:IsInRange(40) and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 30 then
        if HR.Cast(S.AMurderofCrows) then return ""; end
      end
      -- actions+=/coordinated_assault
      if HR.CDsON() and S.CoordinatedAssault:IsCastable() then
        if HR.Cast(S.CoordinatedAssault) then return ""; end
      end
      -- actions+=/chakrams,if=active_enemies>1
      if HR.CDsON() and Target:IsInRange(40) and S.Chakrams:IsCastable() and Player:FocusPredicted(0.2) > 30 and Cache.EnemiesCount[40] > 1 then
        if HR.Cast(S.Chakrams) then return ""; end
      end
      -- actions+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3&active_enemies<2
      if Target:IsInRange(50) and S.KillCommand:IsCastable() and (Target:DebuffRefreshable(S.KillCommandDot, 2.4) and (Player:Focus() + Player:FocusCastRegen (Player:GCD()) < Player:FocusMax() and Player:BuffStack(S.TipoftheSpearBuff) < 3 and Cache.EnemiesCount[12] < 2)) then
        if HR.Cast(S.KillCommand) then return ""; end
      end
      -- actions+=/wildfire_bomb,if=(focus+cast_regen<focus.max|active_enemies>1)&(dot.wildfire_bomb.refreshable&buff.mongoose_fury.down|full_recharge_time<gcd)
      if Target:IsInRange(40) and S.WildfireBomb:IsCastable() and ((Player:Focus() + Player:FocusCastRegen (Player:GCD()) < Player:FocusMax() or Cache.EnemiesCount[5] > 1) and (Target:DebuffRefreshable(S.WildfireBombDot, 1.8) and not Player:Buff(S.MongooseFury) or S.WildfireBomb:FullRechargeTime() < Player:GCD())) then
        if HR.Cast(S.WildfireBomb) then return ""; end
      end
      -- actions+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
      if Target:IsInRange(50) and S.KillCommand:IsCastable() and (Player:Focus() + Player:FocusCastRegen (Player:GCD()) < Player:FocusMax() and Player:BuffStack(S.TipoftheSpearBuff) < 3) then
        if HR.Cast(S.KillCommand) then return ""; end
      end
      -- actions+=/butchery,if=(!talent.wildfire_infusion.enabled|full_recharge_time<gcd)&active_enemies>3|(dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3)
      if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 30 and (not S.WildfireInfusion:IsAvailable() or S.Butchery:FullRechargeTime() < Player:GCD()) and Cache.EnemiesCount[8] > 3 or (Target:Debuff(S.ShrapnelBomb) and Target:DebuffStack(S.InternalBleeding) < 3) then
        if HR.Cast(S.Butchery) then return ""; end
      end
      -- -- actions+=/serpent_sting,if=(active_enemies<2&refreshable&(buff.mongoose_fury.down|(variable.can_gcd&!talent.vipers_venom.enabled)))|buff.vipers_venom.up
      if S.SerpentSting:IsCastable() and Target:IsInRange(40) and Player:FocusPredicted(0.2) > 20 and (Cache.EnemiesCount[8] < 2 and Target:DebuffRefreshable(S.SerpentSting, 2.7) and (not Player:Buff(S.MongooseFury) or (CanGCD() and not S.VipersVenom:IsAvailable()))) or Player:Buff(S.VipersVenom) then
        if HR.Cast(S.SerpentSting) then return ""; end
      end
      -- actions+=/carve,if=active_enemies>2&(active_enemies<6&active_enemies+gcd<cooldown.wildfire_bomb.remains|5+gcd<cooldown.wildfire_bomb.remains)
      if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and Cache.EnemiesCount[5] > 2 and (Cache.EnemiesCount[5] < 6 and Cache.EnemiesCount[5] + Player:GCD() < S.WildfireBomb:CooldownRemains() or 5 + Player:GCD() < S.WildfireBomb:CooldownRemains()) then
        if HR.Cast(S.Carve) then return ""; end
      end
      -- actions+=/harpoon,if=talent.terms_of_engagement.enabled
      if HR.CDsON() and Target:IsInRange(S.Harpoon) and S.Harpoon:IsCastable() and S.TermsofEngagement:IsAvailable() then
        if HR.Cast(S.Harpoon) then return ""; end
      end
      -- actions+=/flanking_strike
      if HR.CDsON() and Target:IsInRange(15) and S.FlankingStrike:IsCastable() then
        if HR.Cast(S.FlankingStrike) then return ""; end
      end
      -- actions+=/chakrams
      if HR.CDsON() and Target:IsInRange(40) and S.Chakrams:IsCastable() and Player:FocusPredicted(0.2) > 30 then
        if HR.Cast(S.Chakrams) then return ""; end
      end
      -- actions+=/serpent_sting,target_if=min:remains,if=refreshable&buff.mongoose_fury.down|buff.vipers_venom.up
      if S.SerpentSting:IsCastable() and Target:IsInRange(40) and Player:FocusPredicted(0.2) > 20 and Target:DebuffRefreshable(S.SerpentSting, 2.7) and ( not Player:Buff(S.MongooseFury) or Player:Buff(S.VipersVenom)) then
        if HR.Cast(S.SerpentSting) then return ""; end
      end
      -- actions+=/mongoose_bite,target_if=min:dot.internal_bleeding.stack,if=buff.mongoose_fury.up|focus>60
      if S.MongooseBite:IsCastable() and (Player:Buff(S.MongooseFury) or Player:Focus() > 60) then
        if HR.Cast(S.MongooseBite) then return ""; end
      end
      -- actions+=/butchery
      if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 30 then
        if HR.Cast(S.Butchery) then return ""; end
      end
      -- actions+=/raptor_strike,target_if=min:dot.internal_bleeding.stack
      if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 30 then
        if HR.Cast(S.RaptorStrike) then return ""; end
      end
      -- Blizzard change the id of Raptor Strike when you use Aspect of the Eagle
      if S.RaptorStrikeRanged:IsCastable() and Player:FocusPredicted(0.2) > 30 then
        if HR.Cast(S.RaptorStrikeRanged) then return ""; end
      end
    -- Pool
    if HR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      return;
    end
  end

  HR.SetAPL(255, APL);


--- Last Update: 11/28/2017


-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/steel_trap
-- actions.precombat+=/harpoon

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/muzzle,if=equipped.sephuzs_secret&target.debuff.casting.react&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up
-- actions+=/use_items
-- actions+=/berserking,if=cooldown.coordinated_assault.remains>30
-- actions+=/blood_fury,if=cooldown.coordinated_assault.remains>30
-- actions+=/ancestral_call,if=cooldown.coordinated_assault.remains>30
-- actions+=/fireblood,if=cooldown.coordinated_assault.remains>30
-- actions+=/lights_judgment
-- actions+=/potion,if=buff.coordinated_assault.up&(buff.berserking.up|buff.blood_fury.up|!race.troll&!race.orc)
-- actions+=/variable,name=can_gcd,value=!talent.mongoose_bite.enabled|buff.mongoose_fury.down|(buff.mongoose_fury.remains-(((buff.mongoose_fury.remains*focus.regen+focus)%action.mongoose_bite.cost)*gcd.max)>gcd.max)
-- actions+=/steel_trap
-- actions+=/a_murder_of_crows
-- actions+=/coordinated_assault
-- actions+=/chakrams,if=active_enemies>1
-- actions+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3&active_enemies<2
-- actions+=/wildfire_bomb,if=(focus+cast_regen<focus.max|active_enemies>1)&(dot.wildfire_bomb.refreshable&buff.mongoose_fury.down|full_recharge_time<gcd)
-- actions+=/kill_command,target_if=min:bloodseeker.remains,if=focus+cast_regen<focus.max&buff.tip_of_the_spear.stack<3
-- actions+=/butchery,if=(!talent.wildfire_infusion.enabled|full_recharge_time<gcd)&active_enemies>3|(dot.shrapnel_bomb.ticking&dot.internal_bleeding.stack<3)
-- actions+=/serpent_sting,if=(active_enemies<2&refreshable&(buff.mongoose_fury.down|(variable.can_gcd&!talent.vipers_venom.enabled)))|buff.vipers_venom.up
-- actions+=/carve,if=active_enemies>2&(active_enemies<6&active_enemies+gcd<cooldown.wildfire_bomb.remains|5+gcd<cooldown.wildfire_bomb.remains)
-- actions+=/harpoon,if=talent.terms_of_engagement.enabled
-- actions+=/flanking_strike
-- actions+=/chakrams
-- actions+=/serpent_sting,target_if=min:remains,if=refreshable&buff.mongoose_fury.down|buff.vipers_venom.up
-- actions+=/mongoose_bite,target_if=min:dot.internal_bleeding.stack,if=buff.mongoose_fury.up|focus>60
-- actions+=/butchery
-- actions+=/raptor_strike,target_if=min:dot.internal_bleeding.stack

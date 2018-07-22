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
  Spell.Hunter.Marksmanship = {
    -- Racials
    ArcaneTorrent                 = Spell(80483),
    AncestralCall                 = Spell(274738),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    Fireblood                     = Spell(265221),
    GiftoftheNaaru                = Spell(59547),
    LightsJudgment                = Spell(255647),
    -- Abilities
    AimedShot                     = Spell(19434),
    ArcaneShot                    = Spell(185358),
    BurstingShot                  = Spell(186387),
    HuntersMark                   = Spell(185365),
    MultiShot                     = Spell(257620),
    PreciseShots                  = Spell(260242),
    RapidFire                     = Spell(257044),
    SteadyShot                    = Spell(56641),
    TrickShots                    = Spell(257622),
    TrueShot                      = Spell(193526),
    -- Talents
    AMurderofCrows                = Spell(131894),
    Barrage                       = Spell(120360),
    BindingShot                   = Spell(109248),
    CallingtheShots               = Spell(260404),
    DoubleTap                     = Spell(260402),
    ExplosiveShot                 = Spell(212431),
    HuntersMark                   = Spell(257284),
    LethalShots                   = Spell(260393),
    LockandLoad                   = Spell(194594),
    MasterMarksman                = Spell(260309),
    PiercingShot                  = Spell(198670),
    SerpentSting                  = Spell(271788),
    SerpentStingDebuff            = Spell(271788),
    SteadyFocus                   = Spell(193533),
    Volley                        = Spell(260243),
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
    SentinelsSight                = Spell(208913),
    -- Misc
    CriticalAimed                 = Spell(242243),
    PotionOfProlongedPowerBuff    = Spell(229206),
    SephuzBuff                    = Spell(208052),
    MKIIGyroscopicStabilizer      = Spell(235691),
    PoolFocus                     = Spell(9999000010),
    -- Macros
  };
  local S = Spell.Hunter.Marksmanship;
  -- Items
  if not Item.Hunter then Item.Hunter = {}; end
  Item.Hunter.Marksmanship = {
    -- Legendaries
    SephuzSecret                  = Item(132452, {11,12}),
    -- Trinkets
    ConvergenceofFates            = Item(140806, {13, 14}),
    -- Potions
    PotionOfProlongedPower        = Item(142117),
  };
  local I = Item.Hunter.Marksmanship;
  -- Rotation Var
  local ShouldReturn; -- Used to get the return string
  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Hunter.Commons,
    Marksmanship = HR.GUISettings.APL.Hunter.Marksmanship
  };
  -- Register for InFlight tracking
  S.AimedShot:RegisterInFlight();

  local GCDPrev = Player:GCDRemains();
  local function OffsetRemainsAuto (ExpirationTime, Offset)
    if type( Offset ) == "number" then
      ExpirationTime = ExpirationTime - Offset;
    elseif type( Offset ) == "string" then
      if Offset == "Auto" then
        local GCDRemain = Player:GCDRemains()
        local GCDelta = GCDRemain - GCDPrev;
        if GCDelta <= 0 or (GCDelta > 0 and Player.MMHunter.GCDDisable > 0) or Player:IsCasting() then
          ExpirationTime = ExpirationTime - math.max(GCDRemain , Player:CastRemains() );
          GCDPrev = GCDRemain;
        else
          ExpirationTime = ExpirationTime - 0;
        end
      end
    else
      error( "Invalid Offset." );
    end
    return ExpirationTime;
  end

  local function DebuffRemains ( Spell, AnyCaster, Offset )
    local ExpirationTime = Target:Debuff( Spell, 7, AnyCaster );
    if ExpirationTime then
      if Offset then
        ExpirationTime = OffsetRemainsAuto(ExpirationTime, Offset);
      end
      local Remains = ExpirationTime - HL.GetTime();
      return Remains >= 0 and Remains or 0;
    else
      return 0;
    end
  end

  local function DebuffRemainsP (Spell, AnyCaster, Offset)
    return DebuffRemains(Spell, AnyCaster, Offset or "Auto");
  end

  local function DebuffP (Spell, AnyCaster, Offset)
    return DebuffRemains(Spell, AnyCaster, Offset or "Auto") > 0;
  end


  local function PlayerFocusRemainingCastRegen (Offset)
    if Player:FocusRegen() == 0 then return -1; end
    -- If we are casting, we check what we will regen until the end of the cast
    if Player:IsCasting() then
      return Player:FocusRegen() * (Player:CastRemains() + (Offset or 0));
    -- Else we'll use the remaining GCD as "CastTime"
    else
      return Player:FocusRegen() * (Player:GCDRemains() + (Offset or 0));
    end
  end

  local function PlayerFocusDeficitPredicted (Offset)
    return Player:FocusMax() - PlayerFocusPredicted(Offset);
  end


  local function IsCastableM (Spell)
    if not Player:IsMoving() or not Settings.Marksmanship.EnableMovementRotation then return true; end
    --Aimed Shot can sometimes be cast while moving
    if Spell == S.AimedShot then
      return Player:Buff(S.LockandLoad) or Player:Buff(S.MKIIGyroscopicStabilizer);
    end
    return true
  end

  local function IsCastableP (Spell)
    if Spell == S.AimedShot then
      return Spell:IsCastable() and PlayerFocusPredicted() > Spell:Cost();
    else
      return Spell:IsCastable();
    end
  end

--- APL Action Lists (and Variables)


--- APL Main
  local function APL ()
    -- Unit Update
    HL.GetEnemies(40);
    Everyone.AoEToggleEnemiesUpdate();
    Hunter.UpdateSplashCount(Target, 8)
    -- Defensives
      -- Exhilaration
      if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Marksmanship.ExhilarationHP then
        if HR.Cast(S.Exhilaration, Settings.Marksmanship.OffGCDasOffGCD.Exhilaration) then return "Cast"; end
      end
    -- Out of Combat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      -- Reset Combat Variables
      if TrueshotCooldown ~= 0 then TrueshotCooldown = 0; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange(40) then
        if S.AimedShot:IsCastable() then
          if HR.Cast(S.AimedShot) then return; end
        end
        if S.ArcaneShot:IsCastable() then
          if HR.Cast(S.ArcaneShot) then return; end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- actions+=/use_items
      -- actions+=/hunters_mark,if=debuff.hunters_mark.down
      if S.HuntersMark:IsCastable() and not Target:Debuff(S.HuntersMark) then
        if HR.Cast(S.HuntersMark) then return ""; end
      end
      -- actions+=/double_tap,if=cooldown.rapid_fire.remains<gcd
      if S.DoubleTap:IsCastable() and S.RapidFire:CooldownRemains() < Player:GCD() then
        if HR.Cast(S.DoubleTap) then return ""; end
      end
      if HR.CDsON() then
        -- actions+=/arcane_torrent,if=focus.deficit>=30
        if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 then
          if HR.Cast(S.ArcaneTorrent, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/berserking,if=cooldown.trueshot.remains>30
        if S.Berserking:IsCastable() and S.TrueShot:CooldownRemains() > 30 then
          if HR.Cast(S.Berserking, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/blood_fury,if=cooldown.trueshot.remains>30
        if S.BloodFury:IsCastable() and S.TrueShot:CooldownRemains() > 30 then
          if HR.Cast(S.BloodFury, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/ancestral_call,if=cooldown.trueshot.remains>30
        if S.AncestralCall:IsCastable() and S.TrueShot:CooldownRemains() > 30 then
          if HR.Cast(S.AncestralCall, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/fireblood,if=cooldown.trueshot.remains>30
        if S.Fireblood:IsCastable() and S.TrueShot:CooldownRemains() > 30 then
          if HR.Cast(S.Fireblood, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
        end
        -- actions+=/lights_judgment
        if S.LightsJudgment:IsCastable() then
          if HR.Cast(S.LightsJudgment, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
        end
      end
      -- actions+=/potion,if=(buff.trueshot.react&buff.bloodlust.react)|((consumable.prolonged_power&target.time_to_die<62)|target.time_to_die<31)
      if Settings.Marksmanship.ShowPoPP and I.PotionOfProlongedPower:IsReady() and ((Player:Buff(S.TrueShot) and Player:HasHeroism()) or ((Player:Buff(S.PotionOfProlongedPowerBuff) and Target:TimeToDie() < 62) or Target:TimeToDie() < 31)) then
        if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
      end
      -- actions+=/trueshot,if=cooldown.aimed_shot.charges<1
      if HR.CDsON() and S.TrueShot:IsCastable() and S.AimedShot:Charges() < 1 then
        if HR.Cast(S.TrueShot, Settings.Marksmanship.GCDasOffGCD.TrueShot) then return ""; end
      end
      -- actions+=/barrage,if=active_enemies>1
      if HR.CDsON() and S.Barrage:IsCastable() and Hunter.GetSplashCount(Target,8) > 1 then
        HR.CastSuggested(S.Barrage);
      end
      -- actions+=/explosive_shot,if=active_enemies>1
      if HR.CDsON() and S.ExplosiveShot:IsCastable() and Hunter.GetSplashCount(Target,8) > 1 then
        if HR.Cast(S.ExplosiveShot) then return ""; end
      end
      -- actions+=/multishot,if=active_enemies>2&buff.precise_shots.up&cooldown.aimed_shot.full_recharge_time<gcd*buff.precise_shots.stack+action.aimed_shot.cast_time
      if S.MultiShot:IsCastable() and (Hunter.GetSplashCount(Target,8) > 2 and Player:Buff(S.PreciseShots) and S.AimedShot:FullRechargeTime() < Player:GCD() * Player:BuffStack(S.PreciseShots) + S.AimedShot:CastTime()) then
        if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
      end
      -- actions+=/arcane_shot,if=active_enemies<3&buff.precise_shots.up&cooldown.aimed_shot.full_recharge_time<gcd*buff.precise_shots.stack+action.aimed_shot.cast_time
      if S.ArcaneShot:IsCastable() and (Hunter.GetSplashCount(Target,8) < 3 and Player:Buff(S.PreciseShots) and S.AimedShot:FullRechargeTime() < Player:GCD() * Player:BuffStack(S.PreciseShots) + S.AimedShot:CastTime()) then
        if HR.Cast(S.ArcaneShot) then return ""; end
      end
      -- actions+=/aimed_shot,if=buff.precise_shots.down&buff.double_tap.down&(active_enemies>2&buff.trick_shots.up|active_enemies<3&full_recharge_time<cast_time+gcd)
      if S.AimedShot:IsCastable() and (not Player:Buff(S.PreciseShots) and not Player:Buff(S.DoubleTap) and ((Hunter.GetSplashCount(Target,8) > 2 and Player:Buff(S.TrickShots)) or Hunter.GetSplashCount(Target,8) < 3 and S.AimedShot:FullRechargeTime() < S.AimedShot:CastTime() + Player:GCD())) then
        if not IsCastableM(S.AimedShot) then HR.CastSuggested(S.AimedShot) elseif HR.Cast(S.AimedShot) then return ""; end
      end
      -- actions+=/rapid_fire,if=active_enemies<3|buff.trick_shots.up
      if S.RapidFire:IsCastable() and (Hunter.GetSplashCount(Target,8) < 3 or Player:Buff(S.TrickShots)) then
        if HR.Cast(S.RapidFire) then return ""; end
      end
      -- actions+=/explosive_shot
      if HR.CDsON() and S.ExplosiveShot:IsCastable() then
        if HR.Cast(S.ExplosiveShot) then return ""; end
      end
      -- actions+=/barrage
      if HR.CDsON() and S.Barrage:IsCastable() then
        HR.CastSuggested(S.Barrage);
      end
      -- actions+=/piercing_shot
      if HR.CDsON() and S.PiercingShot:IsAvailable() then
        if HR.Cast(S.PiercingShot) then return ""; end
      end
      -- actions+=/a_murder_of_crows
      if HR.CDsON() and S.AMurderofCrows:IsCastable() then
        if HR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return ""; end
      end
      -- actions+=/multishot,if=active_enemies>2&buff.trick_shots.down
      if S.MultiShot:IsCastable() and Hunter.GetSplashCount(Target,8) > 2 and Player:Buff(S.PreciseShots) and S.AimedShot:FullRechargeTime() < Player:GCD() * Player:BuffStack(S.PreciseShots) + S.AimedShot:CastTime() then
        if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
      end
      -- actions+=/aimed_shot,if=buff.precise_shots.down&(focus>70|buff.steady_focus.down)
      if S.AimedShot:IsCastable() and not Player:Buff(S.PreciseShots) and (Player:Focus() > 70 or not Player:Buff(S.SteadyFocus)) then
        if not IsCastableM(S.AimedShot) then HR.CastSuggested(S.AimedShot) elseif HR.Cast(S.AimedShot) then return ""; end
      end
      -- actions+=/multishot,if=active_enemies>2&(focus>90|buff.precise_shots.up&(focus>70|buff.steady_focus.down&focus>45))
      if S.MultiShot:IsCastable() and Hunter.GetSplashCount(Target,8) > 2 and (Player:Focus() > 90 or Player:Buff(S.PreciseShots) and (Player:Focus() > 70 or not Player:Buff(S.SteadyFocus) and Player:Focus() > 45)) then
        if Hunter.MultishotInMain() and HR.Cast(S.MultiShot) then return "" else HR.CastSuggested(S.MultiShot) end
      end
      -- actions+=/arcane_shot,if=active_enemies<3&(focus>70|buff.steady_focus.down&(focus>60|buff.precise_shots.up))
      if S.ArcaneShot:IsCastable() and Hunter.GetSplashCount(Target,8) < 3 and (Player:Focus() > 70 or not Player:Buff(S.SteadyFocus) and (Player:Focus() > 60 or Player:Buff(S.PreciseShots))) then
        if HR.Cast(S.ArcaneShot) then return ""; end
      end
      -- actions+=/serpent_sting,if=refreshable
      if S.SerpentSting:IsCastable() and Target:DebuffRefreshable(S.SerpentStingDebuff, 3.6) then
        if HR.Cast(S.SerpentSting) then return ""; end
      end
      -- actions+=/steady_shot
      if S.SteadyShot:IsAvailable() then
        if HR.Cast(S.SteadyShot) then return ""; end
      end
      -- Pool
      if HR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      return;
    end
  end

  HR.SetAPL(254, APL);


--- Last Update: 07/17/2018

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/hunters_mark
-- actions.precombat+=/double_tap,precast_time=5
-- actions.precombat+=/aimed_shot,if=active_enemies<3
-- actions.precombat+=/explosive_shot,if=active_enemies>2

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/counter_shot,if=equipped.sephuzs_secret&target.debuff.casting.react&cooldown.buff_sephuzs_secret.up&!buff.sephuzs_secret.up
-- actions+=/use_items
-- actions+=/hunters_mark,if=debuff.hunters_mark.down
-- actions+=/double_tap,if=cooldown.rapid_fire.remains<gcd
-- actions+=/berserking,if=cooldown.trueshot.remains>30
-- actions+=/blood_fury,if=cooldown.trueshot.remains>30
-- actions+=/ancestral_call,if=cooldown.trueshot.remains>30
-- actions+=/fireblood,if=cooldown.trueshot.remains>30
-- actions+=/lights_judgment
-- actions+=/potion,if=(buff.trueshot.react&buff.bloodlust.react)|((consumable.prolonged_power&target.time_to_die<62)|target.time_to_die<31)
-- actions+=/trueshot,if=cooldown.aimed_shot.charges<1
-- actions+=/barrage,if=active_enemies>1
-- actions+=/explosive_shot,if=active_enemies>1
-- actions+=/multishot,if=active_enemies>2&buff.precise_shots.up&cooldown.aimed_shot.full_recharge_time<gcd*buff.precise_shots.stack+action.aimed_shot.cast_time
-- actions+=/arcane_shot,if=active_enemies<3&buff.precise_shots.up&cooldown.aimed_shot.full_recharge_time<gcd*buff.precise_shots.stack+action.aimed_shot.cast_time
-- actions+=/aimed_shot,if=buff.precise_shots.down&buff.double_tap.down&(active_enemies>2&buff.trick_shots.up|active_enemies<3&full_recharge_time<cast_time+gcd)
-- actions+=/rapid_fire,if=active_enemies<3|buff.trick_shots.up
-- actions+=/explosive_shot
-- actions+=/barrage
-- actions+=/piercing_shot
-- actions+=/a_murder_of_crows
-- actions+=/multishot,if=active_enemies>2&buff.trick_shots.down
-- actions+=/aimed_shot,if=buff.precise_shots.down&(focus>70|buff.steady_focus.down)
-- actions+=/multishot,if=active_enemies>2&(focus>90|buff.precise_shots.up&(focus>70|buff.steady_focus.down&focus>45))
-- actions+=/arcane_shot,if=active_enemies<3&(focus>70|buff.steady_focus.down&(focus>60|buff.precise_shots.up))
-- actions+=/serpent_sting,if=refreshable
-- actions+=/steady_shot

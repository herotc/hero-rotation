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
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- APL Local Vars
-- Commons
  local Everyone = AR.Commons.Everyone;
  local Hunter = AR.Commons.Hunter;
  -- Spells
  if not Spell.Hunter then Spell.Hunter = {}; end
  Spell.Hunter.Marksmanship = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    AimedShot                     = Spell(19434),
    ArcaneShot                    = Spell(185358),
    BurstingShot                  = Spell(186387),
    HuntersMark                   = Spell(185365),
    MarkedShot                    = Spell(185901),
    MarkingTargets                = Spell(223138),
    MultiShot                     = Spell(2643),
    TrueShot                      = Spell(193526),
    Vulnerability                 = Spell(187131),
    -- Talents
    AMurderofCrows                = Spell(131894),
    Barrage                       = Spell(120360),
    BindingShot                   = Spell(109248),
    BlackArrow                    = Spell(194599),
    ExplosiveShot                 = Spell(212431),
    LockandLoad                   = Spell(194594),
    PatientSniper                 = Spell(234588),
    PiercingShot                  = Spell(198670),
    Sentinel                      = Spell(206817),
    Sidewinders                   = Spell(214579),
    TrickShot                     = Spell(199522),
    Volley                        = Spell(194386),
    -- Artifact
    Windburst                     = Spell(204147),
    BullsEye                      = Spell(204090),
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
    PoolingSpell                  = Spell(9999000010), 
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
  local TrueshotCooldown = 0;
  local Vuln_Window, Vuln_Aim_Casts, Can_GCD, WaitingForSentinel;
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Hunter.Commons,
    Marksmanship = AR.GUISettings.APL.Hunter.Marksmanship
  };
  -- Register for InFlight tracking
  S.AimedShot:RegisterInFlight();
  S.Windburst:RegisterInFlight();
  S.MarkedShot:RegisterInFlight();
  S.ArcaneShot:RegisterInFlight(S.MarkingTargets);
  S.MultiShot:RegisterInFlight(S.MarkingTargets);
  S.Sidewinders:RegisterInFlight(S.MarkingTargets);

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

  local function TargetDebuffRemainsP (Spell, AnyCaster, Offset)
    if Spell == S.Vulnerability and (S.Windburst:InFlight() or S.MarkedShot:InFlight() or Player:PrevGCDP(1, S.Windburst, true)) then
      return 7;
    else
      return DebuffRemainsP(Spell);
    end
  end

  local function TargetDebuffP (Spell, AnyCaster, Offset)
    if Spell == S.Vulnerability then
      return DebuffP(Spell) or S.Windburst:InFlight() or S.MarkedShot:InFlight() or Player:PrevGCDP(1, S.Windburst, true);
    elseif Spell == S.HuntersMark then
      return DebuffP(Spell) or S.ArcaneShot:InFlight(S.MarkingTargets) or S.MultiShot:InFlight(S.MarkingTargets) or S.Sidewinders:InFlight(S.MarkingTargets);
    else
      return DebuffP(Spell);
    end
  end

  local function PlayerFocusLossOnCastEnd ()
    if Player:IsCasting() then
      return Spell(Player:CastID()):Cost();
    elseif Player:PrevGCDP(1, S.AimedShot, true) then
      return S.AimedShot:Cost();
    elseif Player:PrevGCDP(1, S.Windburst, true) then
      return S.Windburst:Cost();
    else
      return 0;
    end
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

  local PFPPrev = math.floor((Player:Focus() + math.min(Player:FocusDeficit(), PlayerFocusRemainingCastRegen(Offset)) - PlayerFocusLossOnCastEnd()) + 0.5);
  local function PlayerFocusPredicted (Offset)
    if Player:FocusRegen() == 0 then return -1; end
      --v2
    local FocusP = math.floor((Player:Focus() + math.min(Player:FocusDeficit(), PlayerFocusRemainingCastRegen(Offset)) - PlayerFocusLossOnCastEnd()) + 0.5);
    local FocusDelta = FocusP - PFPPrev
    --if (FocusDelta < -3 or FocusDelta > 0 and FocusDelta < 8 or S.ArcaneShot:TimeSinceLastCast() < 0.1 or S.MarkedShot:TimeSinceLastCast() < 0.1 or S.Sidewinders:TimeSinceLastCast() < 0.1 or S.MultiShot:TimeSinceLastCast() < 0.1 or Player:IsCasting()) then 
    if (FocusDelta < -3 or FocusDelta > 0 and (FocusDelta < 8 or Player.MMHunter.GCDDisable > 0)) then 
      PFPPrev = FocusP;
      return FocusP;
    else
      return PFPPrev;
    end
      --v1
    -- if math.abs(FocusP - 50) <= (8 - (Player:GCD() * Player:FocusRegen())) then
    --   return (Player:PrevGCD(1, S.ArcaneShot) and 60 or 49);
    -- else
    --   return FocusP;
  end

  local function PlayerFocusDeficitPredicted (Offset)
    return Player:FocusMax() - PlayerFocusPredicted(Offset);
  end


  local function IsCastableM (Spell)
    if not Player:IsMoving() or not Settings.Marksmanship.EnableMovementRotation then return true; end
    --Aimed Shot can sometimes be cast while moving
    if Spell == S.AimedShot then
      return Player:Buff(S.LockandLoad) or Player:Buff(S.MKIIGyroscopicStabilizer);
    elseif Spell == S.Windburst then 
      return false; 
    end  
    return true
  end

  local function IsCastableP (Spell)
    if Spell == S.AimedShot then
      return Spell:IsCastable() and PlayerFocusPredicted() > Spell:Cost();
    elseif Spell == S.MarkedShot then
      return Spell:IsCastable() and PlayerFocusPredicted() > Spell:Cost() and TargetDebuffP(S.HuntersMark);
    elseif Spell == S.Windburst then
      return Spell:IsCastable() and not Player:PrevGCDP(1, S.Windburst, true) and not Player:IsCasting(S.Windburst);
    else
      return Spell:IsCastable();
    end
  end
--- APL Action Lists (and Variables)
  -- actions+=/variable,name=pooling_for_piercing,value=talent.piercing_shot.enabled&cooldown.piercing_shot.remains<5&lowest_vuln_within.5>0&lowest_vuln_within.5>cooldown.piercing_shot.remains&(buff.trueshot.down|spell_targets=1)
  local function PoolingforPiercing ()
    return S.PiercingShot:IsAvailable() and S.PiercingShot:CooldownRemains() < 5 and TargetDebuffRemainsP(S.Vulnerability) > 0 and TargetDebuffRemainsP(S.Vulnerability) > S.PiercingShot:CooldownRemains() and (not Player:Buff(S.TrueShot) or Cache.EnemiesCount[40] == 1);
  end
  -- # Cooldowns
  local function CDs ()
    -- actions.cooldowns=arcane_torrent,if=focus.deficit>=30&(!talent.sidewinders.enabled|cooldown.sidewinders.charges<2)
    if S.ArcaneTorrent:IsCastable() and PlayerFocusDeficitPredicted() >= 30 and (not S.Sidewinders:IsAvailable() or S.Sidewinders:Charges() < 2) then
      if AR.Cast(S.ArcaneTorrent, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions.cooldowns+=/berserking,if=buff.trueshot.up
    if S.Berserking:IsCastable() and Player:Buff(S.TrueShot) then
      if AR.Cast(S.Berserking, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions.cooldowns+=/blood_fury,if=buff.trueshot.up
    if S.BloodFury:IsCastable() and Player:Buff(S.TrueShot) then
      if AR.Cast(S.BloodFury, Settings.Marksmanship.OffGCDasOffGCD.Racials) then return ""; end
    end
  -- actions.cooldowns+=/potion,if=(buff.trueshot.react&buff.bloodlust.react)|buff.bullseye.react>=23|((consumable.prolonged_power&target.time_to_die<62)|target.time_to_die<31)
    if Settings.Marksmanship.ShowPoPP and I.PotionOfProlongedPower:IsReady() and ((Player:Buff(S.TrueShot) and Player:HasHeroism()) or Player:BuffStack(S.BullsEye) >= 23 or ((Player:Buff(S.PotionOfProlongedPowerBuff) and Target:TimeToDie() < 62) or Target:TimeToDie() < 31)) then
      if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
    end
    -- actions.cooldowns+=/variable,name=trueshot_cooldown,op=set,value=time*1.1,if=time>15&cooldown.trueshot.up&variable.trueshot_cooldown=0
    if TrueshotCooldown == 0 and HL.CombatTime() > 15 and S.TrueShot:CooldownUp() then
      TrueshotCooldown = HL.CombatTime() * 1.1;
    end
    -- actions.cooldowns+=/trueshot,if=variable.trueshot_cooldown=0|buff.bloodlust.up|(variable.trueshot_cooldown>0&target.time_to_die>(variable.trueshot_cooldown+duration))|buff.bullseye.react>25|target.time_to_die<16
    if AR.CDsON() and S.TrueShot:IsCastable() and (TrueshotCooldown == 0 or Player:HasHeroism() or (TrueshotCooldown > 0 and Target:TimeToDie() > (TrueshotCooldown + 15)) or Player:BuffStack(S.BullsEye) > 25 or Target:TimeToDie() < 16) then
      if AR.Cast(S.TrueShot, Settings.Marksmanship.OffGCDasOffGCD.TrueShot) then return ""; end
    end
    return false;
  end

  -- # Non_Patient_Sniper
  local function Non_Patient_Sniper ()
    -- actions.non_patient_sniper=variable,name=waiting_for_sentinel,value=talent.sentinel.enabled&(buff.marking_targets.up|buff.trueshot.up)&action.sentinel.marks_next_gcd
    WaitingForSentinel = S.Sentinel:IsAvailable() and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot));
    -- actions.non_patient_sniper=explosive_shot
    if AR.CDsON() and IsCastableP(S.ExplosiveShot) then
      if AR.Cast(S.ExplosiveShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/piercing_shot,if=lowest_vuln_within.5>0&focus>100
    if AR.CDsON() and IsCastableP(S.PiercingShot) and TargetDebuffRemainsP(S.Vulnerability) > 0 and PlayerFocusPredicted() > 100 then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=spell_targets>1&debuff.vulnerability.remains>cast_time&(talent.trick_shot.enabled|buff.lock_and_load.up)&buff.sentinels_sight.stack=20
    if IsCastableP(S.AimedShot) and Hunter.GetSplashCount(Target,8) > 1 and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() and (S.TrickShot:IsAvailable() or Player:Buff(S.LockandLoad)) and Player:BuffStack(S.SentinelsSight) == 20 then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=spell_targets>1&debuff.vulnerability.remains>cast_time&talent.trick_shot.enabled&set_bonus.tier20_2pc&!buff.t20_2p_critical_aimed_damage.up&action.aimed_shot.in_flight
    if IsCastableP(S.AimedShot) and Hunter.GetSplashCount(Target,8) > 1 and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() and S.TrickShot:IsAvailable() and HL.Tier20_2Pc and not Player:Buff(S.CriticalAimed) and S.AimedShot:InFlight() then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/marked_shot,if=spell_targets>1
    if IsCastableP(S.MarkedShot) and Hunter.GetSplashCount(Target,8) > 1 then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/multishot,if=spell_targets>1&(buff.marking_targets.up|buff.trueshot.up)
    if IsCastableP(S.MultiShot) and Hunter.GetSplashCount(Target,8) > 1 and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot)) then
      if Hunter.MultishotInMain() and AR.Cast(S.MultiShot) then return "" else AR.CastSuggested(S.MultiShot) end
    end
    -- actions.non_patient_sniper+=/sentinel,if=!debuff.hunters_mark.up
    if AR.AoEON() and IsCastableP(S.Sentinel) and not TargetDebuffP(S.HuntersMark) then
      AR.CastSuggested(S.Sentinel);
    end
    -- actions.non_patient_sniper+=/black_arrow,if=talent.sidewinders.enabled|spell_targets.multishot<6
    if IsCastableP(S.BlackArrow) and (S.Sidewinders:IsAvailable() or Hunter.GetSplashCount(Target,8) < 6) then
      if AR.Cast(S.BlackArrow) then return ""; end
    end
    -- actions.non_patient_sniper+=/a_murder_of_crows,if=target.time_to_die>=cooldown+duration|target.health.pct<20
    if AR.CDsON() and S.AMurderofCrows:IsCastableP() and PlayerFocusPredicted() > S.AMurderofCrows:Cost() and (Target:TimeToDie() >= 60 + 15 or Target:HealthPercentage() < 20) then
      if AR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return ""; end
    end
    -- actions.non_patient_sniper+=/windburst
    if IsCastableP(S.Windburst) then
      if not IsCastableM(S.Windburst) then AR.CastSuggested(S.Windburst) elseif AR.Cast(S.Windburst) then return ""; end
    end
    -- actions.non_patient_sniper+=/barrage,if=spell_targets>2|(target.health.pct<20&buff.bullseye.stack<25)
    if IsCastableP(S.Barrage) and PlayerFocusPredicted() > S.Barrage:Cost() and (Cache.EnemiesCount[40] > 2 or (Target:HealthPercentage() < 20 and Player:BuffStack(S.BullsEye) < 25)) then
      AR.CastSuggested(S.Barrage);
    end
    -- actions.non_patient_sniper+=/marked_shot,if=buff.marking_targets.up|buff.trueshot.up
    if IsCastableP(S.MarkedShot) and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot)) then 
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/sidewinders,if=!variable.waiting_for_sentinel&(debuff.hunters_mark.down|(buff.trueshot.down&buff.marking_targets.down))&((buff.marking_targets.up|buff.trueshot.up)|charges_fractional>1.8)&(focus.deficit>cast_regen)
    if IsCastableP(S.Sidewinders) and not WaitingForSentinel and (not TargetDebuffP(S.HuntersMark) or (not Player:Buff(S.TrueShot) and not Player:Buff(S.MarkingTargets)) and 
    ((Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot) or S.Sidewinders:ChargesFractional() > 1.8) and (PlayerFocusDeficitPredicted() > Player:FocusRegen()))) then
      if AR.Cast(S.Sidewinders) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time
    if IsCastableP(S.AimedShot) and S.Sidewinders:IsAvailable() and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- NOTE : Change if=!talent.sidewinders.enabled to if=talent.piercing_shot.enabled for add new apl for meme build and add a line for proc lock_and_load.
    -- actions.non_patient_sniper+=/aimed_shot,if=talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|(buff.lock_and_load.up&lowest_vuln_within.5>gcd.max))&(spell_targets.multishot<4|talent.trick_shot.enabled|buff.sentinels_sight.stack=20)
    if IsCastableP(S.AimedShot)
      and S.PiercingShot:IsAvailable() and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime()
      and (not PoolingforPiercing() or (Player:Buff(S.LockandLoad) and TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()))
      and (Cache.EnemiesCount[40] < 4 or S.TrickShot:IsAvailable() or Player:BuffStack(S.SentinelsSight) == 20)
      and not Player:Buff(S.MarkingTargets) and not Player:Buff(S.TrueShot) and not TargetDebuffP(S.HuntersMark) then
        if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    if S.AimedShot:IsCastableP() and Player:Buff(S.LockandLoad) and TargetDebuffRemainsP(S.Vulnerability) > Player:GCD() then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- NOTE : Change if=!talent.sidewinders.enabled to if=talent.trick_shot.enabled for add new apl for meme build.
    -- actions.non_patient_sniper+=/aimed_shot,if=talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|(buff.lock_and_load.up&lowest_vuln_within.5>gcd.max))&(spell_targets.multishot<4|talent.trick_shot.enabled|buff.sentinels_sight.stack=20)
    if IsCastableP(S.AimedShot)
      and S.TrickShot:IsAvailable() and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime()
      and (not PoolingforPiercing() or (Player:Buff(S.LockandLoad) and TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()))
      and (Cache.EnemiesCount[40] < 4 or S.TrickShot:IsAvailable() or Player:BuffStack(S.SentinelsSight) == 20) then
        if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/marked_shot
    if IsCastableP(S.MarkedShot) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=focus+cast_regen>focus.max&!buff.sentinels_sight.up
    if IsCastableP(S.AimedShot) and PlayerFocusPredicted() + Player:FocusCastRegen(S.AimedShot:CastTime()) > Player:FocusMax() and not Player:Buff(S.SentinelsSight) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/multishot,if=spell_targets.multishot>1&!variable.waiting_for_sentinel
    if IsCastableP(S.MultiShot) and Hunter.GetSplashCount(Target, 8) > 1 and not WaitingForSentinel then
      if Hunter.MultishotInMain() and AR.Cast(S.MultiShot) then return "" else AR.CastSuggested(S.MultiShot) end
    end
    -- actions.non_patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&!variable.waiting_for_sentinel
    if IsCastableP(S.ArcaneShot) and not WaitingForSentinel then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    if AR.Cast(S.PoolingSpell) then return ""; end
    return false;
  end

  -- # Patient_Sniper
  local function Patient_Sniper ()
    -- actions.patient_sniper=variable,name=vuln_window,op=set,value=debuff.vulnerability.remains
    Vuln_Window = TargetDebuffRemainsP(S.Vulnerability);
    -- actions.patient_sniper+=/variable,name=vuln_window,op=set,value=(24-cooldown.sidewinders.charges_fractional*12)*attack_haste,if=talent.sidewinders.enabled&(24-cooldown.sidewinders.charges_fractional*12)*attack_haste<variable.vuln_window
    if S.Sidewinders:IsAvailable() and (24 - S.Sidewinders:ChargesFractional() * 12) * Player:HastePct() < Vuln_Window then
      Vuln_Window = (24 - S.Sidewinders:ChargesFractional() * 12) * Player:HastePct();
    end
    -- actions.patient_sniper=variable,name=vuln_window,op=setif,value=cooldown.sidewinders.full_recharge_time,value_else=debuff.vulnerability.remains,condition=talent.sidewinders.enabled&cooldown.sidewinders.full_recharge_time<variable.vuln_window
    if S.Sidewinders:IsAvailable() and S.Sidewinders:FullRechargeTime() < Vuln_Window then
      Vuln_Window = S.Sidewinders:FullRechargeTime();
    else
      Vuln_Window = TargetDebuffRemainsP(S.Vulnerability);
    end
    -- actions.patient_sniper+=/variable,name=vuln_aim_casts,op=set,value=floor(variable.vuln_window%action.aimed_shot.execute_time)
    Vuln_Aim_Casts = math.floor(Vuln_Window/S.AimedShot:ExecuteTime());
    -- actions.patient_sniper+=/variable,name=vuln_aim_casts,op=set,value=floor((focus+action.aimed_shot.cast_regen*(variable.vuln_aim_casts-1))%action.aimed_shot.cost),if=variable.vuln_aim_casts>0&variable.vuln_aim_casts>floor((focus+action.aimed_shot.cast_regen*(variable.vuln_aim_casts-1))%action.aimed_shot.cost)
    if Vuln_Aim_Casts > 0 and Vuln_Aim_Casts > math.floor((PlayerFocusPredicted() + Player:FocusCastRegen(S.AimedShot:ExecuteTime()) * (Vuln_Aim_Casts - 1)) / S.AimedShot:Cost()) then
      Vuln_Aim_Casts = math.floor((PlayerFocusPredicted() + Player:FocusCastRegen(S.AimedShot:ExecuteTime()) * (Vuln_Aim_Casts - 1)) / S.AimedShot:Cost());
    end
    -- actions.patient_sniper+=/variable,name=can_gcd,value=variable.vuln_window<action.aimed_shot.cast_time|variable.vuln_window>variable.vuln_aim_casts*action.aimed_shot.execute_time+gcd.max+0.1
    Can_GCD = Vuln_Window < S.AimedShot:CastTime() or Vuln_Window > Vuln_Aim_Casts * S.AimedShot:ExecuteTime() + Player:GCD() + 0.1;
    -- actions.patient_sniper+=/piercing_shot,if=cooldown.piercing_shot.up&spell_targets=1&lowest_vuln_within.5>0&lowest_vuln_within.5<1
    if AR.CDsON() and S.PiercingShot:IsAvailable() and S.PiercingShot:CooldownUp() and Hunter.GetSplashCount(Target,8) == 1 and TargetDebuffRemainsP(S.Vulnerability) > 0 and TargetDebuffRemainsP(S.Vulnerability) < 1 then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.patient_sniper+=/piercing_shot,if=cooldown.piercing_shot.up&spell_targets>1&lowest_vuln_within.5>0&((!buff.trueshot.up&focus>80&(lowest_vuln_within.5<1|debuff.hunters_mark.up))|(buff.trueshot.up&focus>105&lowest_vuln_within.5<6))
    if AR.CDsON() and S.PiercingShot:IsAvailable() and S.PiercingShot:CooldownUp() and Hunter.GetSplashCount(Target,8) > 1 and TargetDebuffRemainsP(S.Vulnerability) > 0 and ((not Player:Buff(S.TrueShot) and PlayerFocusPredicted() > 80 and (TargetDebuffRemainsP(S.Vulnerability) < 1 or TargetDebuffP(S.HuntersMark))) or (Player:Buff(S.TrueShot) and PlayerFocusPredicted() > 105 and TargetDebuffRemainsP(S.Vulnerability) < 6)) then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=spell_targets>1&talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(buff.sentinels_sight.stack>=spell_targets.multishot*5|buff.sentinels_sight.stack+(spell_targets.multishot%2)>20|buff.lock_and_load.up|(set_bonus.tier20_2pc&!buff.t20_2p_critical_aimed_damage.up&action.aimed_shot.in_flight))
    if IsCastableP(S.AimedShot) and S.TrickShot:IsAvailable() and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() and (Player:BuffStack(S.SentinelsSight) >= Cache.EnemiesCount[40] * 5 or Player:BuffStack(S.SentinelsSight) + (Cache.EnemiesCount[40] / 2) > 20 or Player:Buff(S.LockandLoad) or (HL.Tier20_2Pc and not Player:Buff(S.CriticalAimed) and S.AimedShot:InFlight())) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/marked_shot,if=spell_targets>1
    if IsCastableP(S.MarkedShot) and Hunter.GetSplashCount(Target,8) > 1 then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.patient_sniper+=/multishot,if=spell_targets>1&(buff.marking_targets.up|buff.trueshot.up)
    if IsCastableP(S.MultiShot) and Hunter.GetSplashCount(Target,8) > 1 and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot)) then
      if Hunter.MultishotInMain() and AR.Cast(S.MultiShot) then return "" else AR.CastSuggested(S.MultiShot) end
    end
    -- actions.patient_sniper+=/windburst,if=variable.vuln_aim_casts<1&!variable.pooling_for_piercing
    if IsCastableP(S.Windburst) and Vuln_Aim_Casts < 1 and not PoolingforPiercing() then
      if not IsCastableM(S.Windburst) then AR.CastSuggested(S.Windburst) elseif AR.Cast(S.Windburst) then return ""; end
    end
    -- actions.patient_sniper+=/black_arrow,if=variable.can_gcd&(!variable.pooling_for_piercing|(lowest_vuln_within.5>gcd.max&focus>85))
    if IsCastableP(S.BlackArrow) and Can_GCD and (not PoolingforPiercing() or (TargetDebuffRemainsP(S.Vulnerability) > Player:GCD() and PlayerFocusPredicted() > 85)) then
      if AR.Cast(S.BlackArrow) then return ""; end
    end
    -- actions.patient_sniper+=/a_murder_of_crows,if=(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)&(target.time_to_die>=cooldown+duration|target.health.pct<20|target.time_to_die<16)&variable.vuln_aim_casts=0
    if AR.CDsON() and IsCastableP(S.AMurderofCrows) and PlayerFocusPredicted() > S.AMurderofCrows:Cost() and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()) and (Target:TimeToDie() >= 60 + 15 or (Target:HealthPercentage() < 20 or Target:TimeToDie() < 16)) and Vuln_Aim_Casts == 0 then
      if AR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return ""; end
    end
    -- actions.patient_sniper+=/barrage,if=spell_targets>2|(target.health.pct<20&buff.bullseye.stack<25)
    if IsCastableP(S.Barrage) and PlayerFocusPredicted() > S.Barrage:Cost() and (Cache.EnemiesCount[40] > 2 or (Target:HealthPercentage() < 20 and Player:BuffStack(S.BullsEye) < 25)) then
      AR.CastSuggested(S.Barrage);
    end
    -- actions.patient_sniper+=/aimed_shot,if=action.windburst.in_flight&focus+action.arcane_shot.cast_regen+cast_regen>focus.max
    if IsCastableP(S.AimedShot) and S.Windburst:InFlight() and PlayerFocusPredicted() + Player:FocusCastRegen(S.ArcaneShot:ExecuteTime()) + Player:FocusCastRegen(S.AimedShot:ExecuteTime()) > Player:FocusMax() then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=debuff.vulnerability.up&buff.lock_and_load.up&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if IsCastableP(S.AimedShot) and TargetDebuffP(S.Vulnerability) and Player:Buff(S.LockandLoad) and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=spell_targets.multishot>1&debuff.vulnerability.remains>execute_time&(!variable.pooling_for_piercing|(focus>100&lowest_vuln_within.5>(execute_time+gcd.max)))
    if IsCastableP(S.AimedShot) and Hunter.GetSplashCount(Target,8) > 1 and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:ExecuteTime() and (not PoolingforPiercing() or (PlayerFocusPredicted() > 100 and 
    TargetDebuffRemainsP(S.Vulnerability) > (S.AimedShot:ExecuteTime() + Player:GCD()))) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/multishot,if=spell_targets>1&variable.can_gcd&focus+cast_regen+action.aimed_shot.cast_regen<focus.max&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if IsCastableP(S.MultiShot) and Hunter.GetSplashCount(Target,8) > 1 and Can_GCD and PlayerFocusPredicted() + Player:FocusCastRegen(S.AimedShot:ExecuteTime()) < Player:FocusMax() and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()) then
      if Hunter.MultishotInMain() and AR.Cast(S.MultiShot) then return "" else AR.CastSuggested(S.MultiShot) end
    end
    -- actions.patient_sniper+=/arcane_shot,if=spell_targets.multi_shot=1&(!set_bonus.tier20_2pc|!action.aimed_shot.in_flight|buff.t20_2p_critical_aimed_damage.remains>action.aimed_shot.execute_time+gcd)&variable.vuln_aim_casts>0&variable.can_gcd&focus+cast_regen+action.aimed_shot.cast_regen<focus.max&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd)
    if IsCastableP(S.ArcaneShot) 
      and ((not HL.Tier20_2Pc or not S.AimedShot:InFlight() or Player:BuffRemains(S.CriticalAimed) > S.AimedShot:ExecuteTime() + Player:GCD()) 
      and Vuln_Aim_Casts > 0 
      and Can_GCD 
      and PlayerFocusPredicted() + Player:FocusCastRegen(S.ArcaneShot:ExecuteTime()) + Player:FocusCastRegen(S.AimedShot:ExecuteTime()) < Player:FocusMax() 
      and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > Player:GCD())) then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    	-- actions.patient_sniper+=/aimed_shot,if=talent.sidewinders.enabled&(debuff.vulnerability.remains>cast_time|(buff.lock_and_load.down&action.windburst.in_flight))&(variable.vuln_window-(execute_time*variable.vuln_aim_casts)<1|focus.deficit<25|buff.trueshot.up)&(spell_targets.multishot=1|focus>100)
    if IsCastableP(S.AimedShot) and S.Sidewinders:IsAvailable() and (TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() or (not Player:Buff(S.LockandLoad) and S.Windburst:InFlight())) and (Vuln_Window - (S.AimedShot:ExecuteTime() * Vuln_Aim_Casts) < 1 or (PlayerFocusDeficitPredicted() < 25 or Player:Buff(S.TrueShot))) and (Cache.EnemiesCount[40] == 1 or PlayerFocusPredicted() > 100) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=!talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|lowest_vuln_within.5>execute_time+gcd.max)
    if IsCastableP(S.AimedShot) and not S.Sidewinders:IsAvailable() and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:ExecuteTime() + Player:GCD()) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/marked_shot,if=!talent.sidewinders.enabled&!variable.pooling_for_piercing&!action.windburst.in_flight&(focus>65|buff.trueshot.up|(1%attack_haste)>1.171)
    if IsCastableP(S.MarkedShot) and (not S.Sidewinders:IsAvailable() and not PoolingforPiercing() and not S.Windburst:InFlight() and (PlayerFocusPredicted() > 65 or Player:Buff(S.TrueShot) or (1 / (1 + (Player:HastePct() / 100))) > 1.171)) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.patient_sniper+=/marked_shot,if=talent.sidewinders.enabled&(variable.vuln_aim_casts<1|buff.trueshot.up|variable.vuln_window<action.aimed_shot.cast_time)
    if IsCastableP(S.MarkedShot) and (S.Sidewinders:IsAvailable() and (Vuln_Aim_Casts < 1 or Player:Buff(S.TrueShot) or Vuln_Window < S.AimedShot:CastTime())) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=focus+cast_regen>focus.max&!buff.sentinels_sight.up
    if IsCastableP(S.AimedShot) and PlayerFocusPredicted() + Player:FocusCastRegen(S.AimedShot:ExecuteTime()) > Player:FocusMax() and not Player:Buff(S.SentinelsSight) then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/sidewinders,if=(!debuff.hunters_mark.up|(!buff.marking_targets.up&!buff.trueshot.up))&((buff.marking_targets.up&variable.vuln_aim_casts<1)|buff.trueshot.up|charges_fractional>1.9)
    if IsCastableP(S.Sidewinders) and (not TargetDebuffP(S.HuntersMark) or (not Player:Buff(S.MarkingTargets) and not Player:Buff(S.TrueShot))) and ((Player:Buff(S.MarkingTargets) and Vuln_Aim_Casts < 1) or Player:Buff(S.TrueShot) or S.Sidewinders:ChargesFractional() >1.9) then
      if AR.Cast(S.Sidewinders) then return ""; end
    end
    -- actions.patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if IsCastableP(S.ArcaneShot) and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()) then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    -- actions.patient_sniper+=/multishot,if=spell_targets>1&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if IsCastableP(S.MultiShot) and Hunter.GetSplashCount(Target,8) > 1 and (not PoolingforPiercing() or TargetDebuffRemainsP(S.Vulnerability) > Player:GCD()) then
      if Hunter.MultishotInMain() and AR.Cast(S.MultiShot) then return "" else AR.CastSuggested(S.MultiShot) end
    end
    if AR.Cast(S.PoolingSpell) then return ""; end
    return false;
  end

  -- # Targetdie
  local function TargetDie () 
    -- actions.targetdie=piercing_shot,if=debuff.vulnerability.up
    if AR.CDsON() and IsCastableP(S.PiercingShot) and TargetDebuffP(S.Vulnerability) then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.targetdie+=/windburst
    if IsCastableP(S.Windburst) then
      if not IsCastableM(S.Windburst) then AR.CastSuggested(S.Windburst) elseif AR.Cast(S.Windburst) then return ""; end
    end
    -- actions.targetdie+=/aimed_shot,if=debuff.vulnerability.remains>cast_time&target.time_to_die>cast_time
    if IsCastableP(S.AimedShot) and TargetDebuffRemainsP(S.Vulnerability) > S.AimedShot:CastTime() and Target:TimeToDie() > S.AimedShot:CastTime() then
      if not IsCastableM(S.AimedShot) then AR.CastSuggested(S.AimedShot) elseif AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.targetdie+=/marked_shot
    if IsCastableP(S.MarkedShot) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.targetdie+=/sidewinders
    if IsCastableP(S.Sidewinders) then
      if AR.Cast(S.Sidewinders) then return ""; end
    end
    -- actions.targetdie+=/arcane_shot
    if IsCastableP(S.ArcaneShot) then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    return false;
  end

--- APL Main
  local function APL ()
    -- Unit Update
    HL.GetEnemies(40);
    Everyone.AoEToggleEnemiesUpdate();
    Hunter.UpdateSplashCount(Target, 8)
    -- Defensives
      -- Exhilaration
      if IsCastableP(S.Exhilaration) and Player:HealthPercentage() <= Settings.Marksmanship.ExhilarationHP then
        if AR.Cast(S.Exhilaration, Settings.Marksmanship.OffGCDasOffGCD.Exhilaration) then return "Cast"; end
      end
    -- Out of Combat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      -- Reset Combat Variables
      if TrueshotCooldown ~= 0 then TrueshotCooldown = 0; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Volley toggle
      if IsCastableP(S.Volley) and not Player:Buff(S.Volley) then
        if AR.Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley) then return; end
      end
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange(40) then
        if IsCastableP(S.AMurderofCrows) and PlayerFocusPredicted() > S.AMurderofCrows:Cost() then
          if AR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return; end
        end
        if IsCastableP(S.Windburst) then
          if AR.Cast(S.Windburst) then return; end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- actions+=/volley,toggle=on
      if IsCastableP(S.Volley) and not Player:Buff(S.Volley) then
        if AR.Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley) then return; end
      end
      -- actions+=/use_item,name=tarnished_sentinel_medallion,if=((cooldown.trueshot.remains<6|cooldown.trueshot.remains>45)&(target.time_to_die>cooldown+duration))|target.time_to_die<25|buff.bullseye.react=30
      -- actions+=/call_action_list,name=cooldowns
      ShouldReturn = CDs();
      if ShouldReturn then return ShouldReturn; end
      -- actions+=/call_action_list,name=targetdie,if=target.time_to_die<6&spell_targets.multishot=1
      if Target:TimeToDie() < 6 and Hunter.GetSplashCount(Target,8) == 1 then
        ShouldReturn = TargetDie();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=patient_sniper,if=talent.patient_sniper.enabled
      if S.PatientSniper:IsAvailable() then
        ShouldReturn = Patient_Sniper();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=non_patient_sniper,if=!talent.patient_sniper.enabled
      if not S.PatientSniper:IsAvailable() then
        ShouldReturn = Non_Patient_Sniper();
        if ShouldReturn then return ShouldReturn; end
      end
      return;
    end
  end

  AR.SetAPL(254, APL);


--- Last Update: 11/22/2017
-- NOTE: Due to WoW API limitation, "lowest_vuln_within" is replaced by the Vulnerability duration from the current target.


-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/counter_shot,if=target.debuff.casting.react
-- actions+=/use_item,name=tarnished_sentinel_medallion,if=((cooldown.trueshot.remains<6|cooldown.trueshot.remains>45)&(target.time_to_die>cooldown+duration))|target.time_to_die<25|buff.bullseye.react=30
-- actions+=/use_items
-- actions+=/volley,toggle=on
-- # Start being conservative with focus if expecting a Piercing Shot at the end of the current Vulnerable debuff. The expression lowest_vuln_within.<range> is used to check the lowest Vulnerable debuff duration on all enemies within the specified range from the target.
-- actions+=/variable,name=pooling_for_piercing,value=talent.piercing_shot.enabled&cooldown.piercing_shot.remains<5&lowest_vuln_within.5>0&lowest_vuln_within.5>cooldown.piercing_shot.remains&(buff.trueshot.down|spell_targets=1)
-- actions+=/call_action_list,name=cooldowns
-- actions+=/call_action_list,name=patient_sniper,if=talent.patient_sniper.enabled
-- actions+=/call_action_list,name=non_patient_sniper,if=!talent.patient_sniper.enabled

-- actions.cooldowns=arcane_torrent,if=focus.deficit>=30&(!talent.sidewinders.enabled|cooldown.sidewinders.charges<2)
-- actions.cooldowns+=/berserking,if=buff.trueshot.up
-- actions.cooldowns+=/blood_fury,if=buff.trueshot.up
-- actions.cooldowns+=/potion,if=(buff.trueshot.react&buff.bloodlust.react)|buff.bullseye.react>=23|((consumable.prolonged_power&target.time_to_die<62)|target.time_to_die<31)
-- # Estimate the real Trueshot cooldown based on the first, fudging it a bit to account for Bloodlust.
-- actions.cooldowns+=/variable,name=trueshot_cooldown,op=set,value=time*1.1,if=time>15&cooldown.trueshot.up&variable.trueshot_cooldown=0
-- actions.cooldowns+=/trueshot,if=variable.trueshot_cooldown=0|buff.bloodlust.up|(variable.trueshot_cooldown>0&target.time_to_die>(variable.trueshot_cooldown+duration))|buff.bullseye.react>25|target.time_to_die<16

-- # Prevent wasting a Marking Targets proc if the Hunter's Mark debuff could be overwritten by an active Sentinel before we can use Marked Shot. The expression action.sentinel.marks_next_gcd is used to determine if an active Sentinel will mark the targets in its area within the next gcd.
-- actions.non_patient_sniper=variable,name=waiting_for_sentinel,value=talent.sentinel.enabled&(buff.marking_targets.up|buff.trueshot.up)&action.sentinel.marks_next_gcd
-- actions.non_patient_sniper+=/explosive_shot
-- actions.non_patient_sniper+=/piercing_shot,if=lowest_vuln_within.5>0&focus>100
-- actions.non_patient_sniper+=/aimed_shot,if=spell_targets>1&debuff.vulnerability.remains>cast_time&(talent.trick_shot.enabled|buff.lock_and_load.up)&buff.sentinels_sight.stack=20
-- actions.non_patient_sniper+=/aimed_shot,if=spell_targets>1&debuff.vulnerability.remains>cast_time&talent.trick_shot.enabled&set_bonus.tier20_2pc&!buff.t20_2p_critical_aimed_damage.up&action.aimed_shot.in_flight
-- actions.non_patient_sniper+=/marked_shot,if=spell_targets>1
-- actions.non_patient_sniper+=/multishot,if=spell_targets>1&(buff.marking_targets.up|buff.trueshot.up)
-- actions.non_patient_sniper+=/sentinel,if=!debuff.hunters_mark.up
-- actions.non_patient_sniper+=/black_arrow,if=talent.sidewinders.enabled|spell_targets.multishot<6
-- actions.non_patient_sniper+=/a_murder_of_crows,if=target.time_to_die>=cooldown+duration|target.health.pct<20
-- actions.non_patient_sniper+=/windburst
-- actions.non_patient_sniper+=/barrage,if=spell_targets>2|(target.health.pct<20&buff.bullseye.stack<25)
-- actions.non_patient_sniper+=/marked_shot,if=buff.marking_targets.up|buff.trueshot.up
-- actions.non_patient_sniper+=/sidewinders,if=!variable.waiting_for_sentinel&(debuff.hunters_mark.down|(buff.trueshot.down&buff.marking_targets.down))&((buff.marking_targets.up|buff.trueshot.up)|charges_fractional>1.8)&(focus.deficit>cast_regen)
-- actions.non_patient_sniper+=/aimed_shot,if=talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time
-- actions.non_patient_sniper+=/aimed_shot,if=!talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|(buff.lock_and_load.up&lowest_vuln_within.5>gcd.max))&(talent.trick_shot.enabled|buff.sentinels_sight.stack=20)
-- actions.non_patient_sniper+=/marked_shot
-- actions.non_patient_sniper+=/aimed_shot,if=focus+cast_regen>focus.max&!buff.sentinels_sight.up
-- actions.non_patient_sniper+=/multishot,if=spell_targets.multishot>1&!variable.waiting_for_sentinel
-- actions.non_patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&!variable.waiting_for_sentinel

-- # Sidewinders charges could cap sooner than the Vulnerable debuff ends, so clip the current window to the recharge time if it will.
-- actions.patient_sniper=variable,name=vuln_window,op=setif,value=cooldown.sidewinders.full_recharge_time,value_else=debuff.vulnerability.remains,condition=talent.sidewinders.enabled&cooldown.sidewinders.full_recharge_time<variable.vuln_window
-- # Determine the number of Aimed Shot casts that are possible according to available focus and remaining Vulnerable duration.
-- actions.patient_sniper+=/variable,name=vuln_aim_casts,op=set,value=floor(variable.vuln_window%action.aimed_shot.execute_time)
-- actions.patient_sniper+=/variable,name=vuln_aim_casts,op=set,value=floor((focus+action.aimed_shot.cast_regen*(variable.vuln_aim_casts-1))%action.aimed_shot.cost),if=variable.vuln_aim_casts>0&variable.vuln_aim_casts>floor((focus+action.aimed_shot.cast_regen*(variable.vuln_aim_casts-1))%action.aimed_shot.cost)
-- actions.patient_sniper+=/variable,name=can_gcd,value=variable.vuln_window<action.aimed_shot.cast_time|variable.vuln_window>variable.vuln_aim_casts*action.aimed_shot.execute_time+gcd.max+0.1
-- actions.patient_sniper+=/call_action_list,name=targetdie,if=target.time_to_die<variable.vuln_window&spell_targets.multishot=1
-- actions.patient_sniper+=/piercing_shot,if=cooldown.piercing_shot.up&spell_targets=1&lowest_vuln_within.5>0&lowest_vuln_within.5<1
-- # For multitarget, the possible Marked Shots that might be lost while waiting for Patient Sniper to stack are not worth losing, so fire Piercing as soon as Marked Shot is ready before resetting the window. Basically happens immediately under Trushot.
-- actions.patient_sniper+=/piercing_shot,if=cooldown.piercing_shot.up&spell_targets>1&lowest_vuln_within.5>0&((!buff.trueshot.up&focus>80&(lowest_vuln_within.5<1|debuff.hunters_mark.up))|(buff.trueshot.up&focus>105&lowest_vuln_within.5<6))
-- # For multitarget, Aimed Shot is generally only worth using with Trickshot, and depends on if Lock and Load is triggered or Warbelt is equipped and about half of your next multishot's additional Sentinel's Sight stacks would be wasted. Once either of those condition are met, the next Aimed is forced immediately afterwards to trigger the Tier 20 2pc.
-- actions.patient_sniper+=/aimed_shot,if=spell_targets>1&talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(buff.sentinels_sight.stack>=spell_targets.multishot*5|buff.sentinels_sight.stack+(spell_targets.multishot%2)>20|buff.lock_and_load.up|(set_bonus.tier20_2pc&!buff.t20_2p_critical_aimed_damage.up&action.aimed_shot.in_flight))
-- actions.patient_sniper+=/marked_shot,if=spell_targets>1
-- actions.patient_sniper+=/multishot,if=spell_targets>1&(buff.marking_targets.up|buff.trueshot.up)
-- actions.patient_sniper+=/windburst,if=variable.vuln_aim_casts<1&!variable.pooling_for_piercing
-- actions.patient_sniper+=/black_arrow,if=variable.can_gcd&(!variable.pooling_for_piercing|(lowest_vuln_within.5>gcd.max&focus>85))
-- actions.patient_sniper+=/a_murder_of_crows,if=(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)&(target.time_to_die>=cooldown+duration|target.health.pct<20|target.time_to_die<16)&variable.vuln_aim_casts=0
-- actions.patient_sniper+=/barrage,if=spell_targets>2|(target.health.pct<20&buff.bullseye.stack<25)
-- actions.patient_sniper+=/aimed_shot,if=action.windburst.in_flight&focus+action.arcane_shot.cast_regen+cast_regen>focus.max
-- actions.patient_sniper+=/aimed_shot,if=debuff.vulnerability.up&buff.lock_and_load.up&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
-- actions.patient_sniper+=/aimed_shot,if=spell_targets.multishot>1&debuff.vulnerability.remains>execute_time&(!variable.pooling_for_piercing|(focus>100&lowest_vuln_within.5>(execute_time+gcd.max)))
-- actions.patient_sniper+=/multishot,if=spell_targets>1&variable.can_gcd&focus+cast_regen+action.aimed_shot.cast_regen<focus.max&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
-- # Attempts to use Arcane early in Vulnerable windows if it will not break an Aimed pair while Critical Aimed is down, lose possible Aimed casts in the window, cap focus, or miss the opportunity to use Piercing.
-- actions.patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&(!set_bonus.tier20_2pc|!action.aimed_shot.in_flight|buff.t20_2p_critical_aimed_damage.remains>action.aimed_shot.execute_time+gcd)&variable.vuln_aim_casts>0&variable.can_gcd&focus+cast_regen+action.aimed_shot.cast_regen<focus.max&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd)
-- actions.patient_sniper+=/aimed_shot,if=talent.sidewinders.enabled&(debuff.vulnerability.remains>cast_time|(buff.lock_and_load.down&action.windburst.in_flight))&(variable.vuln_window-(execute_time*variable.vuln_aim_casts)<1|focus.deficit<25|buff.trueshot.up)&(spell_targets.multishot=1|focus>100)
-- actions.patient_sniper+=/aimed_shot,if=!talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|lowest_vuln_within.5>execute_time+gcd.max)
-- actions.patient_sniper+=/marked_shot,if=!talent.sidewinders.enabled&!variable.pooling_for_piercing&!action.windburst.in_flight&(focus>65|buff.trueshot.up|(1%attack_haste)>1.171)
-- actions.patient_sniper+=/marked_shot,if=talent.sidewinders.enabled&(variable.vuln_aim_casts<1|buff.trueshot.up|variable.vuln_window<action.aimed_shot.cast_time)
-- actions.patient_sniper+=/aimed_shot,if=focus+cast_regen>focus.max&!buff.sentinels_sight.up
-- actions.patient_sniper+=/sidewinders,if=(!debuff.hunters_mark.up|(!buff.marking_targets.up&!buff.trueshot.up))&((buff.marking_targets.up&variable.vuln_aim_casts<1)|buff.trueshot.up|charges_fractional>1.9)
-- actions.patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
-- actions.patient_sniper+=/multishot,if=spell_targets>1&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)

-- actions.targetdie=piercing_shot,if=debuff.vulnerability.up
-- actions.targetdie+=/windburst
-- actions.targetdie+=/aimed_shot,if=debuff.vulnerability.remains>cast_time&target.time_to_die>cast_time
-- actions.targetdie+=/marked_shot
-- actions.targetdie+=/arcane_shot
-- actions.targetdie+=/sidewinders

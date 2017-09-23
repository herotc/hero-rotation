--- Localize Vars
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


--- APL Action Lists (and Variables)
  -- actions+=/variable,name=pooling_for_piercing,value=talent.piercing_shot.enabled&cooldown.piercing_shot.remains<5&lowest_vuln_within.5>0&lowest_vuln_within.5>cooldown.piercing_shot.remains&(buff.trueshot.down|spell_targets=1)
  local function PoolingforPiercing ()
    return S.PiercingShot:IsAvailable() and S.PiercingShot:Cooldown() < 5 and Target:DebuffRemains(S.Vulnerability) > 0 and Target:DebuffRemains(S.Vulnerability) > S.PiercingShot:Cooldown() and (not Player:Buff(S.TrueShot) or Cache.EnemiesCount[40] == 1);
  end
  -- # Cooldowns
  local function CDs ()
    -- actions.cooldowns=arcane_torrent,if=focus.deficit>=30&(!talent.sidewinders.enabled|cooldown.sidewinders.charges<2)
    if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 and (not S.Sidewinders:IsAvailable() or S.Sidewinders:Charges() < 2) then
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
    if TrueshotCooldown == 0 and AC.CombatTime() > 15 and not S.TrueShot:IsOnCooldown() then
      TrueshotCooldown = AC.CombatTime() * 1.1;
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
    if AR.CDsON() and S.ExplosiveShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 15*0.85 or 15) then
      if AR.Cast(S.ExplosiveShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/piercing_shot,if=lowest_vuln_within.5>0&focus>100
    if AR.CDsON() and S.PiercingShot:IsCastable() and Target:DebuffRemains(S.Vulnerability) > 0 and Player:FocusPredicted(0.2) > 100 then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=spell_targets>1&debuff.vulnerability.remains>cast_time&(talent.trick_shot.enabled|buff.lock_and_load.up)&buff.sentinels_sight.stack=20
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Cache.EnemiesCount[40] > 1 and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() and (S.TrickShot:IsAvailable() or Player:Buff(S.LockandLoad)) and Player:BuffStack(S.SentinelsSight) == 20 then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=spell_targets>1&debuff.vulnerability.remains>cast_time&talent.trick_shot.enabled&set_bonus.tier20_2pc&!buff.t20_2p_critical_aimed_damage.up&action.aimed_shot.in_flight
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Cache.EnemiesCount[40] > 1 and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() and S.TrickShot:IsAvailable() and AC.Tier20_2Pc and not Player:Buff(S.CriticalAimed) and S.AimedShot:IsInFlight() then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/marked_shot,if=spell_targets>1
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 20*0.85 or 20) and Target:Debuff(S.HuntersMark) and Cache.EnemiesCount[40] > 1 then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/multishot,if=spell_targets>1&(buff.marking_targets.up|buff.trueshot.up)
    if S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot)) then
      AR.CastSuggested(S.MultiShot);
    end
    -- actions.non_patient_sniper+=/sentinel,if=!debuff.hunters_mark.up
    if AR.AoEON() and S.Sentinel:IsCastable() and not Target:Debuff(S.HuntersMark) then
      AR.CastSuggested(S.Sentinel);
    end
    -- actions.non_patient_sniper+=/black_arrow,if=talent.sidewinders.enabled|spell_targets.multishot<6
    if S.BlackArrow:IsCastable() and (S.Sidewinders:IsAvailable() or Cache.EnemiesCount[40] < 6) then
      if AR.Cast(S.BlackArrow) then return ""; end
    end
    -- actions.non_patient_sniper+=/a_murder_of_crows,if=target.time_to_die>=cooldown+duration|target.health.pct<20
    if AR.CDsON() and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 25*0.85 or 25) and (Target:TimeToDie() >= 60 + 15 or Target:HealthPercentage() < 20) then
      if AR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return ""; end
    end
    -- actions.non_patient_sniper+=/windburst
    if S.Windburst:IsCastable() then
      if AR.Cast(S.Windburst) then return ""; end
    end
    -- actions.non_patient_sniper+=/barrage,if=spell_targets>2|(target.health.pct<20&buff.bullseye.stack<25)
    if S.Barrage:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 55*0.85 or 55) and (Cache.EnemiesCount[40] > 2 or (Target:HealthPercentage() < 20 and Player:BuffStack(S.BullsEye) < 25)) then
      AR.CastSuggested(S.Barrage);
    end
    -- actions.non_patient_sniper+=/marked_shot,if=buff.marking_targets.up|buff.trueshot.up
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 20*0.85 or 20) and Target:Debuff(S.HuntersMark) and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot)) then 
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/sidewinders,if=!variable.waiting_for_sentinel&(debuff.hunters_mark.down|(buff.trueshot.down&buff.marking_targets.down))&((buff.marking_targets.up|buff.trueshot.up)|charges_fractional>1.8)&(focus.deficit>cast_regen)
    if S.Sidewinders:IsCastable() and not WaitingForSentinel() and (not Target:Debuff(S.HuntersMark) or (not Player:Buff(S.TrueShot) and not Player:Buff(S.MarkingTargets)) and 
    ((Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot) or S.Sidewinders:ChargesFractional() > 1.8) and (Player:FocusDeficit() > Player:FocusRegen()))) then
      if AR.Cast(S.Sidewinders) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and S.Sidewinders:IsAvailable() and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- NOTE : Change if=!talent.sidewinders.enabled to if=talent.piercing_shot.enabled for add new apl for meme build and add a line for proc lock_and_load.
    -- actions.non_patient_sniper+=/aimed_shot,if=talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|(buff.lock_and_load.up&lowest_vuln_within.5>gcd.max))&(spell_targets.multishot<4|talent.trick_shot.enabled|buff.sentinels_sight.stack=20)
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45)
      and S.PiercingShot:IsAvailable() and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime()
      and (not PoolingforPiercing() or (Player:Buff(S.LockandLoad) and Target:DebuffRemains(S.Vulnerability) > Player:GCD()))
      and (Cache.EnemiesCount[40] < 4 or S.TrickShot:IsAvailable() or Player:BuffStack(S.SentinelsSight) == 20)
      and not Player:Buff(S.MarkingTargets) and not Player:Buff(S.TrueShot) and not Target:Debuff(S.HuntersMark) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    if S.AimedShot:IsCastable() and Player:Buff(S.LockandLoad) and Target:DebuffRemains(S.Vulnerability) > Player:GCD() then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- NOTE : Change if=!talent.sidewinders.enabled to if=talent.trick_shot.enabled for add new apl for meme build.
    -- actions.non_patient_sniper+=/aimed_shot,if=talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|(buff.lock_and_load.up&lowest_vuln_within.5>gcd.max))&(spell_targets.multishot<4|talent.trick_shot.enabled|buff.sentinels_sight.stack=20)
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45)
      and S.TrickShot:IsAvailable() and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime()
      and (not PoolingforPiercing() or (Player:Buff(S.LockandLoad) and Target:DebuffRemains(S.Vulnerability) > Player:GCD()))
      and (Cache.EnemiesCount[40] < 4 or S.TrickShot:IsAvailable() or Player:BuffStack(S.SentinelsSight) == 20) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/marked_shot
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 20*0.85 or 20) and Target:Debuff(S.HuntersMark) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/aimed_shot,if=focus+cast_regen>focus.max&!buff.sentinels_sight.up
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Player:FocusCastRegen(S.AimedShot:CastTime()) > Player:FocusMax() and not Player:Buff(S.SentinelsSight) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.non_patient_sniper+=/multishot,if=spell_targets.multishot>1&!variable.waiting_for_sentinel
    if S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and not WaitingForSentinel() then
      AR.CastSuggested(S.MultiShot);
    end
    -- actions.non_patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&!variable.waiting_for_sentinel
    if S.ArcaneShot:IsCastable() and not WaitingForSentinel() then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    return false;
  end

  -- # Patient_Sniper
  local function Patient_Sniper ()
    -- actions.patient_sniper=variable,name=vuln_window,op=set,value=debuff.vulnerability.remains
    Vuln_Window = Target:DebuffRemains(S.Vulnerability);
    -- actions.patient_sniper+=/variable,name=vuln_window,op=set,value=(24-cooldown.sidewinders.charges_fractional*12)*attack_haste,if=talent.sidewinders.enabled&(24-cooldown.sidewinders.charges_fractional*12)*attack_haste<variable.vuln_window
    if S.Sidewinders:IsAvailable() and (24 - S.Sidewinders:ChargesFractional() * 12) * Player:HastePct() < Vuln_Window then
      Vuln_Window = (24 - S.Sidewinders:ChargesFractional() * 12) * Player:HastePct();
    end
    -- actions.patient_sniper=variable,name=vuln_window,op=setif,value=cooldown.sidewinders.full_recharge_time,value_else=debuff.vulnerability.remains,condition=talent.sidewinders.enabled&cooldown.sidewinders.full_recharge_time<variable.vuln_window
    if S.Sidewinders:IsAvailable() and S.Sidewinders:FullRechargeTime() < Vuln_Window then
      Vuln_Window = S.Sidewinders:FullRechargeTime();
    else
      Vuln_Window = Target:DebuffRemains(S.Vulnerability);
    end
    -- actions.patient_sniper+=/variable,name=vuln_aim_casts,op=set,value=floor(variable.vuln_window%action.aimed_shot.execute_time)
    Vuln_Aim_Casts = math.floor(Vuln_Window/S.AimedShot:ExecuteTime());
    -- actions.patient_sniper+=/variable,name=vuln_aim_casts,op=set,value=floor((focus+action.aimed_shot.cast_regen*(variable.vuln_aim_casts-1))%action.aimed_shot.cost),if=variable.vuln_aim_casts>0&variable.vuln_aim_casts>floor((focus+action.aimed_shot.cast_regen*(variable.vuln_aim_casts-1))%action.aimed_shot.cost)
    if Vuln_Aim_Casts > 0 and Vuln_Aim_Casts > math.floor((Player:FocusPredicted(0.2) + Player:FocusCastRegen(S.AimedShot:CastTime()) * (Vuln_Aim_Casts - 1)) / (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45)) then
      Vuln_Aim_Casts = math.floor((Player:FocusPredicted(0.2) + Player:FocusCastRegen(S.AimedShot:CastTime()) * (Vuln_Aim_Casts - 1)) / (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45));
    end
    -- actions.patient_sniper+=/variable,name=can_gcd,value=variable.vuln_window<action.aimed_shot.cast_time|variable.vuln_window>variable.vuln_aim_casts*action.aimed_shot.execute_time+gcd.max+0.1
    Can_GCD = Vuln_Window < S.AimedShot:CastTime() or Vuln_Window > Vuln_Aim_Casts * S.AimedShot:ExecuteTime() + Player:GCD() + 0.1;
    -- actions.patient_sniper+=/piercing_shot,if=cooldown.piercing_shot.up&spell_targets=1&lowest_vuln_within.5>0&lowest_vuln_within.5<1
    if AR.CDsON() and S.PiercingShot:IsAvailable() and S.PiercingShot:CooldownUp() and Cache.EnemiesCount[40] == 1 and Target:DebuffRemains(S.Vulnerability) > 0 and Target:DebuffRemains(S.Vulnerability) < 1 then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.patient_sniper+=/piercing_shot,if=cooldown.piercing_shot.up&spell_targets>1&lowest_vuln_within.5>0&((!buff.trueshot.up&focus>80&(lowest_vuln_within.5<1|debuff.hunters_mark.up))|(buff.trueshot.up&focus>105&lowest_vuln_within.5<6))
    if AR.CDsON() and S.PiercingShot:IsAvailable() and S.PiercingShot:CooldownUp() and Cache.EnemiesCount[40] > 1 and Target:DebuffRemains(S.Vulnerability) > 0 and ((not Player:Buff(S.TrueShot) and Player:FocusPredicted(0.2) > 80 and (Target:DebuffRemains(S.Vulnerability) < 1 or Target:Debuff(S.HuntersMark))) or (Player:Buff(S.TrueShot) and Player:FocusPredicted(0.2) > 105 and Target:DebuffRemains(S.Vulnerability) < 6)) then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=spell_targets>1&talent.trick_shot.enabled&debuff.vulnerability.remains>cast_time&(buff.sentinels_sight.stack>=spell_targets.multishot*5|buff.sentinels_sight.stack+(spell_targets.multishot%2)>20|buff.lock_and_load.up|(set_bonus.tier20_2pc&!buff.t20_2p_critical_aimed_damage.up&action.aimed_shot.in_flight))
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and S.TrickShot:IsAvailable() and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() and (Player:BuffStack(S.SentinelsSight) >= Cache.EnemiesCount[40] * 5 or Player:BuffStack(S.SentinelsSight) + (Cache.EnemiesCount[40] / 2) > 20 or Player:Buff(S.LockandLoad) or (AC.Tier20_2Pc and not Player:Buff(S.CriticalAimed) and S.AimedShot:IsInFlight())) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/marked_shot,if=spell_targets>1
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 20*0.85 or 20) and Target:Debuff(S.HuntersMark) and Cache.EnemiesCount[40] > 1 then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.patient_sniper+=/multishot,if=spell_targets>1&(buff.marking_targets.up|buff.trueshot.up)
    if S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and (Player:Buff(S.MarkingTargets) or Player:Buff(S.TrueShot)) then
      AR.CastSuggested(S.MultiShot);
    end
    -- actions.patient_sniper+=/windburst,if=variable.vuln_aim_casts<1&!variable.pooling_for_piercing
    if S.Windburst:IsCastable() and Vuln_Aim_Casts < 1 and not PoolingforPiercing() then
      if AR.Cast(S.Windburst) then return ""; end
    end
    -- actions.patient_sniper+=/black_arrow,if=variable.can_gcd&(!variable.pooling_for_piercing|(lowest_vuln_within.5>gcd.max&focus>85))
    if S.BlackArrow:IsCastable() and Can_GCD and (not PoolingforPiercing() or (Target:DebuffRemains(S.Vulnerability) > Player:GCD() and Player:FocusPredicted(0.2) > 85)) then
      if AR.Cast(S.BlackArrow) then return ""; end
    end
    -- actions.patient_sniper+=/a_murder_of_crows,if=(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)&(target.time_to_die>=cooldown+duration|target.health.pct<20|target.time_to_die<16)&variable.vuln_aim_casts=0
    if AR.CDsON() and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 25*0.85 or 25) and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > Player:GCD()) and (Target:TimeToDie() >= 60 + 15 or (Target:HealthPercentage() < 20 or Target:TimeToDie() < 16)) and Vuln_Aim_Casts == 0 then
      if AR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return ""; end
    end
    -- actions.patient_sniper+=/barrage,if=spell_targets>2|(target.health.pct<20&buff.bullseye.stack<25)
    if S.Barrage:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 55*0.85 or 55) and (Cache.EnemiesCount[40] > 2 or (Target:HealthPercentage() < 20 and Player:BuffStack(S.BullsEye) < 25)) then
      AR.CastSuggested(S.Barrage);
    end
    -- actions.patient_sniper+=/aimed_shot,if=debuff.vulnerability.up&buff.lock_and_load.up&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Target:Debuff(S.Vulnerability) and Player:Buff(S.LockandLoad) and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > Player:GCD()) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=spell_targets.multishot>1&debuff.vulnerability.remains>execute_time&(!variable.pooling_for_piercing|(focus>100&lowest_vuln_within.5>(execute_time+gcd.max)))
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Cache.EnemiesCount[40] > 1 and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:ExecuteTime() and (not PoolingforPiercing() or (Player:FocusPredicted(0.2) > 100 and 
    Target:DebuffRemains(S.Vulnerability) > (S.AimedShot:ExecuteTime() + Player:GCD()))) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/multishot,if=spell_targets>1&variable.can_gcd&focus+cast_regen+action.aimed_shot.cast_regen<focus.max&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and Can_GCD and Player:FocusPredicted(0.2) + Player:FocusCastRegen(S.AimedShot:CastTime()) < Player:FocusMax() and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > Player:GCD()) then
      AR.CastSuggested(S.MultiShot);
    end
    -- actions.patient_sniper+=/arcane_shot,if=spell_targets.multi_shot=1&(!set_bonus.tier20_2pc|!action.aimed_shot.in_flight|buff.t20_2p_critical_aimed_damage.remains>action.aimed_shot.execute_time+gcd)&variable.vuln_aim_casts>0&variable.can_gcd&focus+cast_regen+action.aimed_shot.cast_regen<focus.max&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd)
    if S.ArcaneShot:IsCastable() and ((not AC.Tier20_2Pc or not S.AimedShot:IsInFlight() or 
    Player:BuffRemains(S.CriticalAimed) > S.AimedShot:ExecuteTime() + Player:GCD()) and Vuln_Aim_Casts > 0 and Can_GCD and Player:FocusPredicted(0.2) + Player:FocusCastRegen(S.AimedShot:CastTime()) < Player:FocusMax() and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > Player:GCD())) then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    	-- actions.patient_sniper+=/aimed_shot,if=talent.sidewinders.enabled&(debuff.vulnerability.remains>cast_time|(buff.lock_and_load.down&action.windburst.in_flight))&(variable.vuln_window-(execute_time*variable.vuln_aim_casts)<1|focus.deficit<25|buff.trueshot.up)&(spell_targets.multishot=1|focus>100)
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and S.Sidewinders:IsAvailable() and (Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() or (not Player:Buff(S.LockandLoad) and S.Windburst:IsInFlight())) and (Vuln_Window - (S.AimedShot:ExecuteTime() * Vuln_Aim_Casts) < 1 or (Player:FocusDeficit() < 25 or Player:Buff(S.TrueShot))) and (Cache.EnemiesCount[40] == 1 or Player:FocusPredicted(0.2) > 100) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=!talent.sidewinders.enabled&debuff.vulnerability.remains>cast_time&(!variable.pooling_for_piercing|lowest_vuln_within.5>execute_time+gcd.max)
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and not S.Sidewinders:IsAvailable() and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > S.AimedShot:ExecuteTime() + Player:GCD()) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/marked_shot,if=!talent.sidewinders.enabled&!variable.pooling_for_piercing&!action.windburst.in_flight&(focus>65|buff.trueshot.up|(1%attack_haste)>1.171)
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > 20 and Target:Debuff(S.HuntersMark) and (not S.Sidewinders:IsAvailable() and not PoolingforPiercing() and not S.Windburst:IsInFlight() and (Player:FocusPredicted(0.2) > 65 or Player:Buff(S.TrueShot) or (1 / Player:HastePct()) > 1.171)) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.patient_sniper+=/marked_shot,if=talent.sidewinders.enabled&(variable.vuln_aim_casts<1|buff.trueshot.up|variable.vuln_window<action.aimed_shot.cast_time)
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > 20 and Target:Debuff(S.HuntersMark) and (S.Sidewinders:IsAvailable() and (Vuln_Aim_Casts < 1 or Player:Buff(S.TrueShot) or Vuln_Window < S.AimedShot:CastTime())) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.patient_sniper+=/aimed_shot,if=focus+cast_regen>focus.max&!buff.sentinels_sight.up
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Player:FocusCastRegen(S.AimedShot:CastTime()) > Player:FocusMax() and not Player:Buff(S.SentinelsSight) then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.patient_sniper+=/sidewinders,if=(!debuff.hunters_mark.up|(!buff.marking_targets.up&!buff.trueshot.up))&((buff.marking_targets.up&variable.vuln_aim_casts<1)|buff.trueshot.up|charges_fractional>1.9)
    if S.Sidewinders:IsCastable() and (not Target:Debuff(S.HuntersMark) or (not Player:Buff(S.MarkingTargets) and not Player:Buff(S.TrueShot))) and ((Player:Buff(S.MarkingTargets) and Vuln_Aim_Casts < 1) or Player:Buff(S.TrueShot) or S.Sidewinders:ChargesFractional() >1.9) then
      if AR.Cast(S.Sidewinders) then return ""; end
    end
    -- actions.patient_sniper+=/arcane_shot,if=spell_targets.multishot=1&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if S.ArcaneShot:IsCastable() and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > Player:GCD()) then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    -- actions.patient_sniper+=/multishot,if=spell_targets>1&(!variable.pooling_for_piercing|lowest_vuln_within.5>gcd.max)
    if S.MultiShot:IsCastable() and Cache.EnemiesCount[40] > 1 and (not PoolingforPiercing() or Target:DebuffRemains(S.Vulnerability) > Player:GCD()) then
      AR.CastSuggested(S.MultiShot);
    end
    return false;
  end

  -- # Targetdie
  local function TargetDie () 
    -- actions.targetdie=piercing_shot,if=debuff.vulnerability.up
    if AR.CDsON() and S.PiercingShot:IsCastable() and Target:Debuff(S.Vulnerability) then
      if AR.Cast(S.PiercingShot) then return ""; end
    end
    -- actions.targetdie+=/windburst
    if S.Windburst:IsCastable() then
      if AR.Cast(S.Windburst) then return ""; end
    end
    -- actions.targetdie+=/aimed_shot,if=debuff.vulnerability.remains>cast_time&target.time_to_die>cast_time
    if S.AimedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 45*0.85 or 45) and Target:DebuffRemains(S.Vulnerability) > S.AimedShot:CastTime() and Target:TimeToDie() > S.AimedShot:CastTime() then
      if AR.Cast(S.AimedShot) then return ""; end
    end
    -- actions.targetdie+=/marked_shot
    if S.MarkedShot:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 20*0.85 or 20) and Target:Debuff(S.HuntersMark) then
      if AR.Cast(S.MarkedShot) then return ""; end
    end
    -- actions.targetdie+=/sidewinders
    if S.Sidewinders:IsCastable() then
      if AR.Cast(S.Sidewinders) then return ""; end
    end
    -- actions.targetdie+=/arcane_shot
    if S.ArcaneShot:IsCastable() then
      if AR.Cast(S.ArcaneShot) then return ""; end
    end
    return false;
  end

--- APL Main
  local function APL ()
    -- Unit Update
    AC.GetEnemies(40);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
      -- Exhilaration
      if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Marksmanship.ExhilarationHP then
        if AR.Cast(S.Exhilaration, Settings.Marksmanship.OffGCDasOffGCD.Exhilaration) then return "Cast"; end
      end
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Reset Combat Variables
      if TrueshotCooldown ~= 0 then TrueshotCooldown = 0; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Volley toggle
      if S.Volley:IsCastable() and not Player:Buff(S.Volley) then
        if AR.Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley) then return; end
      end
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange(40) then
        if S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > (Player:Buff(S.TrueShot) and AC.Tier19_4Pc and 25*0.85 or 25) then
          if AR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows) then return; end
        end
        if S.Windburst:IsCastable() then
          if AR.Cast(S.Windburst) then return; end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- actions+=/volley,toggle=on
      if S.Volley:IsCastable() and not Player:Buff(S.Volley) then
        if AR.Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley) then return; end
      end
      -- actions+=/call_action_list,name=cooldowns
      ShouldReturn = CDs();
      if ShouldReturn then return ShouldReturn; end
      -- actions+=/call_action_list,name=targetdie,if=target.time_to_die<6&spell_targets.multishot=1
      if Target:TimeToDie() < 6 and Cache.EnemiesCount[40] == 1 then
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


--- Last Update: 09/20/2017
-- NOTE: Due to WoW API limitation, "lowest_vuln_within" is replaced by the Vulnerability duration from the current target.

-- # Executed every time the actor is available.
-- actions=auto_shot
-- actions+=/counter_shot,if=target.debuff.casting.react
-- actions+=/use_item,name=tarnished_sentinel_medallion,if=((cooldown.trueshot.remains<6|cooldown.trueshot.remains>30)&(target.time_to_die>cooldown+duration))|target.time_to_die<25|buff.bullseye.react=30
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

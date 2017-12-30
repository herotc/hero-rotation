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
  local Druid = AR.Commons.Druid;

  -- Spells
  if not Spell.Druid then Spell.Druid = {}; end
  Spell.Druid.Feral = {
    -- Racials
    Berserking          = Spell(26297),
    Shadowmeld          = Spell(58984),
    -- Abilities
    Berserk             = Spell(106951),
    FerociousBite       = Spell(22568),
    Maim                = Spell(22570),
    MoonfireCat         = Spell(155625),
    PredatorySwiftness  = Spell(69369),
    Prowl               = Spell(5215),
    ProwlJungleStalker  = Spell(102547),
    Rake                = Spell(1822),
    RakeDebuff          = Spell(155722),
    Rip                 = Spell(1079),
    Shred               = Spell(5221),
    Swipe               = Spell(106785),
    Thrash              = Spell(106830),
    TigersFury          = Spell(5217),
    WildCharge          = Spell(49376),
    -- Talents
    BalanceAffinity     = Spell(197488),
    Bloodtalons         = Spell(155672),
    BloodtalonsBuff     = Spell(145152),
    BrutalSlash         = Spell(202028),
    ElunesGuidance      = Spell(202060),
    GuardianAffinity    = Spell(217615),
    Incarnation         = Spell(102543),
    JungleStalker       = Spell(252071),
    JaggedWounds        = Spell(202032),
    LunarInspiration    = Spell(155580),
    RestorationAffinity = Spell(197492),
    Sabertooth          = Spell(202031),
    SavageRoar          = Spell(52610),
    -- Artifact
    AshamanesFrenzy     = Spell(210722),
    -- Defensive
    Regrowth            = Spell(8936),
    Renewal             = Spell(108238),
    SurvivalInstincts   = Spell(61336),
    -- Utility
    SkullBash           = Spell(106839),
    -- Shapeshift
    BearForm            = Spell(5487),
    CatForm             = Spell(768),
    MoonkinForm         = Spell(197625),
    TravelForm          = Spell(783),
    -- Legendaries
    FieryRedMaimers     = Spell(236757),
    -- Tier Set
    ApexPredator        = Spell(252752), -- TODO: Verify T21 4-Piece Buff SpellID
    -- Misc
    Clearcasting        = Spell(135700),
    PoolEnergy          = Spell(9999000010)
    -- Macros
    
  };
  local S = Spell.Druid.Feral;
  S.Rip:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15});
  --S.Thrash:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15}); Don't need it but add moment of clarity scaling if we add it
  S.Rake:RegisterPMultiplier(
    S.RakeDebuff,
    {function ()
      return Player:IsStealthed(true, true) and 2 or 1;
    end},
    {S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15}
  );

  -- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Feral = {
    -- Legendaries
    LuffaWrappings = Item(137056, {9}),
    AiluroPouncers = Item(137024, {8})
  };
  local I = Item.Druid.Feral;

  -- Rotation Var
  local RakeAura, RipAura, ThrashAura;
  do
    local JW = 0.8;
    local Pandemic = 0.3;
    local ComputeDurations = function (Nominal)
      return {
        BaseDuration = Nominal,
        JWDuration = Nominal * JW;
        BaseThreshold = Nominal * Pandemic,
        JWThreshold = Nominal * (Pandemic * JW);
      };
    end
    RakeAura = ComputeDurations(S.RakeDebuff:BaseDuration());
    RipAura = ComputeDurations(S.Rip:BaseDuration());
    ThrashAura = ComputeDurations(S.Thrash:BaseDuration());
  end
  local MoonfireThreshold = S.MoonfireCat:PandemicThreshold();

  function Player:EnergyTimeToXP (Amount, Offset)
    if self:EnergyRegen() == 0 then return -1; end
    return Amount > self:EnergyPredicted() and (Amount - self:EnergyPredicted()) / (self:EnergyRegen() * (1 - (Offset or 0))) or 0;
  end

  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Druid.Commons,
    Feral = AR.GUISettings.APL.Druid.Feral
  };


--- ======= ACTION LISTS =======
-- Put here acti lists only if they are called multiple times in the APL
-- If it's only put one time, it's doing a closure call for nothing.
  


--- ======= MAIN =======
  local function APL()
    -- Local Update
    -- TODO: Move Affinity & JW check on an Event Handler on talent update.
    local MeleeRange, AoERadius, RangedRange;
    if S.BalanceAffinity:IsAvailable() then
      -- Have to use the spell itself since Balance Affinity is a special range increase
      MeleeRange = S.Shred;
      AoERadius = 13;
      ThrashRadius = I.LuffaWrappings:IsEquipped() and 16.25 or AoERadius;
      RangedRange = 45;
    else
      MeleeRange = "Melee";
      AoERadius = 8;
      ThrashRadius = I.LuffaWrappings:IsEquipped() and 10 or AoERadius;
      RangedRange = 40;
    end
    local RakeDuration, RipDuration, ThrashDuration;
    local RakeThreshold, RipThreshold, ThrashThreshold;
    if S.JaggedWounds:IsAvailable() then
      RakeDuration, RakeThreshold = RakeAura.JWDuration, RakeAura.JWThreshold;
      RipDuration, RipThreshold = RipAura.JWDuration, RipAura.JWThreshold;
      ThrashDuration, ThrashThreshold = ThrashAura.JWDuration, ThrashAura.JWThreshold;
    else
      RakeDuration, RakeThreshold = RakeAura.BaseDuration, RakeAura.BaseThreshold;
      RipDuration, RipThreshold = RipAura.BaseDuration, RipAura.BaseThreshold;
      ThrashDuration, ThrashThreshold = ThrashAura.BaseDuration, ThrashAura.BaseThreshold;
    end

    -- Unit Update
    AC.GetEnemies(ThrashRadius, true); -- Thrash
    AC.GetEnemies(AoERadius, true); -- Swipe
    Everyone.AoEToggleEnemiesUpdate();

    -- Defensives
    if S.Renewal:IsCastable() and Player:HealthPercentage() <= Settings.Feral.RenewalHP then
      if AR.Cast(S.Renewal, Settings.Feral.OffGCDasOffGCD.Renewal) then return "Renewal"; end
    end
    if S.SurvivalInstincts:IsCastable() and (not Player:Buff(S.SurvivalInstincts)) and Player:HealthPercentage() <= Settings.Feral.SurvivalInstinctsHP then
      if AR.Cast(S.SurvivalInstincts, Settings.Feral.OffGCDasOffGCD.SurvivalInstincts) then return "Survival Instincts"; end
    end
    if S.Regrowth:IsCastable() and Player:Buff(S.PredatorySwiftness) and Player:HealthPercentage() <= Settings.Feral.RegrowthHP then
      if AR.Cast(S.Regrowth, Settings.Feral.GCDasOffGCD.RegrowthHeal) then return "Regrowth (Healing)"; end
    end

    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Prowl
      if not InCombatLockdown() and S.Prowl:CooldownUp() and not Player:IsStealthed() and GetNumLootItems() == 0 and not UnitExists("npc") and AC.OutOfCombatTime() > 1 then
        if AR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return "Cast"; end
      end
      -- Cat Form
      if S.CatForm:IsCastable() and not Player:Buff(S.CatForm) then
        if AR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "OOC Cat Form"; end
      end
      -- Wild Charge
      if S.WildCharge:IsCastable(S.WildCharge) and not Target:IsInRange(8) and not Target:IsInRange(MeleeRange) then
        if AR.Cast(S.WildCharge, Settings.Feral.OffGCDasOffGCD.WildCharge) then return "Cast"; end
      end
      -- Opener: Rake
      if Everyone.TargetIsValid() and S.Rake:IsCastable() then
        if AR.Cast(S.Rake) then return "Rake Opener"; end
      end
      return;
    end

    -- In Combat
    if Everyone.TargetIsValid() then
      -- Cat Rotation
      if Player:Buff(S.CatForm) then
        -- Skull Bash
        if Settings.General.InterruptEnabled and S.SkullBash:IsCastable(S.SkullBash) and Target:IsInterruptible() then
          if AR.Cast(S.SkullBash) then return "Cast Kick"; end
        end
        -- Wild Charge
        if S.WildCharge:IsCastable(S.WildCharge) and not Target:IsInRange(8) and not Target:IsInRange(MeleeRange) then
          if AR.Cast(S.WildCharge, Settings.Feral.OffGCDasOffGCD.WildCharge) then return "Cast"; end
        end
        -- run_action_list,name=single_target,if=dot.rip.ticking|time>15
        if Target:DebuffRemainsP(S.Rip) > 0 or AC.CombatTime() > 15 then
          if Target:IsInRange(MeleeRange) then
            -- cat_form,if=!buff.cat_form.up
            if S.CatForm:IsCastable(MeleeRange) and not Player:Buff(S.CatForm) then
              if AR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "Cast"; end
            end
            -- rake,if=buff.prowl.up|buff.shadowmeld.up
            if S.Rake:IsCastable() and (Player:Buff(S.Prowl) or Player:Buff(S.Shadowmeld)) then
              if AR.Cast(S.Rake) then return "Cast"; end
            end
            -- actions.single_target+=/auto_attack
            -- call_action_list,name=cooldowns
              -- actions.cooldowns+=/prowl,if=buff.incarnation.remains<0.5&buff.jungle_stalker.up
              if S.ProwlJungleStalker:IsCastable() and (Player:BuffRemainsP(S.Incarnation) < 0.5) and Player:Buff(S.JungleStalker) then
                if Settings.Feral.StealthMacro.JungleStalker then
                  if AR.CastQueue(S.Prowl, S.Rake) then return "Prowl to Rake as Macro"; end
                else
                  if AR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return "Prowl to Rake"; end
                end
              end
              -- berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
              if AR.CDsON() and S.Berserk:IsCastable() and Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 5 or Player:Buff(S.TigersFury)) then
                if AR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
              end
              -- tigers_fury,if=energy.deficit>=60
              if S.TigersFury:IsCastable() and Player:EnergyDeficitPredicted() >= 60 then
                if AR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "Cast"; end
              end
              -- actions.cooldowns+=/berserking
              if AR.CDsON() and S.Berserking:IsCastable() then
                if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
              end
              -- elunes_guidance,if=combo_points=0&energy>=50
              if S.ElunesGuidance:IsCastable() and Player:ComboPoints() == 0 and Player:EnergyPredicted() >= 50 then
                if AR.Cast(S.ElunesGuidance, Settings.Feral.OffGCDasOffGCD.ElunesGuidance) then return "Cast"; end
              end
              if AR.CDsON() then
                -- incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
                if S.Incarnation:IsCastable() and Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 15 or Player:Buff(S.TigersFury)) then
                  if AR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
                end
                -- ashamanes_frenzy,if=combo_points>=2&(!talent.bloodtalons.enabled|buff.bloodtalons.up)
                if S.AshamanesFrenzy:IsCastable() and Player:ComboPoints() >= 2 and (not S.Bloodtalons:IsAvailable() or Player:Buff(S.BloodtalonsBuff)) then
                  if AR.Cast(S.AshamanesFrenzy) then return "Cast"; end
                end
                -- shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
                if S.Shadowmeld:IsCastable() and Player:ComboPoints() < 5 and Player:Energy() >= S.Rake:Cost() and Target:PMultiplier(S.Rake) < 2.1
                  and Player:Buff(S.TigersFury) and (Player:Buff(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable())
                  and (not S.Incarnation:IsAvailable() or S.Incarnation:CooldownRemainsP() > 18) and not Player:Buff(S.Incarnation) then
                  if Settings.Feral.StealthMacro.Shadowmeld then
                    if AR.CastQueue(S.Shadowmeld, S.Rake) then return "Shadowmeld to Rake as Macro"; end
                  else
                    if AR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Shadowmeld to Rake"; end
                  end
                end
              end
          end
          -- actions.single_target+=/ferocious_bite,target_if=dot.rip.ticking&dot.rip.remains<3&target.time_to_die>10&(target.health.pct<25|talent.sabertooth.enabled)
          if S.FerociousBite:IsCastable() and Target:DebuffP(S.Rip) and Target:DebuffRemainsP(S.Rip) < 3 and Target:TimeToDie() > 10 and ((Target:HealthPercentage() < 25) or S.Sabertooth:IsAvailable()) then
            if AR.Cast(S.FerociousBite) then return ""; end
          end
          -- actions.single_target+=/regrowth,if=combo_points=5&buff.predatory_swiftness.up&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8)
          if S.Regrowth:IsCastable() and Player:ComboPoints() == 5 and Player:BuffP(S.PredatorySwiftness) and S.Bloodtalons:IsAvailable() and Player:BuffDownP(S.BloodtalonsBuff) and (Player:BuffDownP(S.Incarnation) or (Target:DebuffRemainsP(S.Rip) < 8)) then
            if AR.Cast(S.Regrowth) then return ""; end
          end
          -- actions.single_target+=/regrowth,if=combo_points>3&talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.apex_predator.up&buff.incarnation.down
          if S.Regrowth:IsCastable() and Player:ComboPoints() > 3 and S.Bloodtalons:IsAvailable() and Player:BuffP(S.PredatorySwiftness) and Player:BuffP(S.ApexPredator) and Player:BuffDownP(S.Incarnation) then
            if AR.Cast(S.Regrowth) then return ""; end
          end
          -- actions.single_target+=/ferocious_bite,if=buff.apex_predator.up
          if S.FerociousBite:IsCastable() and Player:ComboPoints() >= 1 and Player:BuffP(S.ApexPredator) then
            if AR.Cast(S.FerociousBite) then return ""; end
          end
          -- run_action_list,name=st_finishers,if=combo_points>4
          if Player:ComboPoints() > 4 and Target:IsInRange(MeleeRange) then
            -- savage_roar,if=buff.savage_roar.down
            if S.SavageRoar:IsCastable() and not Player:Buff(S.SavageRoar) then
              if AR.Cast(S.SavageRoar) then return "Cast"; end
            end
            -- rip,target_if=!ticking|(remains<=duration*0.3)&(target.health.pct>25&!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
            if S.Rip:IsCastable()
              and (Target:DebuffRefreshableP(S.Rip, 0)
                or (Target:DebuffRefreshableP(S.Rip, RipThreshold) and Target:HealthPercentage() >= 25 and not S.Sabertooth:IsAvailable())
                or (Target:DebuffRefreshableP(S.Rip, RipDuration * 0.8) and Player:PMultiplier(S.Rip) > Target:PMultiplier(S.Rip) and Target:TimeToDie() > 8)) then
                if AR.Cast(S.Rip) then return "Cast"; end
            end
            -- savage_roar,if=buff.savage_roar.remains<12
            if S.SavageRoar:IsCastable() and Player:BuffRemainsP(S.SavageRoar) < 12 then
              if AR.Cast(S.SavageRoar) then return "Cast"; end
            end
            -- maim,if=buff.fiery_red_maimers.up
            if S.Maim:IsCastable() and Player:Buff(S.FieryRedMaimers) then
              if AR.Cast(S.Maim) then return "Cast"; end
            end
            -- ferocious_bite,max_energy=1
            if S.FerociousBite:IsCastable() then
              if Player:EnergyPredicted() < 50 and (Target:HealthPercentage() >= 25 or Player:EnergyTimeToX(50) < Target:DebuffRemainsP(S.Rip)) then
                if AR.Cast(S.PoolEnergy) then return "Pooling for Ferocious Bite"; end
              else
                if AR.Cast(S.FerociousBite) then return "Cast"; end
              end
            end
          end
          -- run_action_list,name=st_generators
            if S.Regrowth:IsCastable() then
              if S.Bloodtalons:IsAvailable() and Player:Buff(S.PredatorySwiftness) and not Player:Buff(S.BloodtalonsBuff) then
                -- regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points>=2&cooldown.ashamanes_frenzy.remains<gcd
                if Player:ComboPoints() >= 2 and (S.AshamanesFrenzy:CooldownRemainsP() < Player:GCD()) then
                  if AR.Cast(S.Regrowth) then return "Cast"; end
                end
                -- regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
                if Player:ComboPoints() == 4 and Target:DebuffRemainsP(S.RakeDebuff) < 4 then
                  if AR.Cast(S.Regrowth) then return "Cast"; end
                end
              end
              -- regrowth,if=equipped.ailuro_pouncers&talent.bloodtalons.enabled&(buff.predatory_swiftness.stack>2|(buff.predatory_swiftness.stack>1&dot.rake.remains<3))&buff.bloodtalons.down
              if I.AiluroPouncers:IsEquipped() and S.Bloodtalons:IsAvailable() and (Player:BuffStack(S.PredatorySwiftness) > 2 or (Player:BuffStack(S.PredatorySwiftness) > 1 and Target:DebuffRemainsP(S.RakeDebuff) < 3)) and not Player:Buff(S.BloodtalonsBuff) then
                if AR.Cast(S.Regrowth) then return "Cast"; end
              end
            end
            -- brutal_slash,if=spell_targets.brutal_slash>desired_targets
            -- TODO: desired_targets
            if S.BrutalSlash:IsCastable() and Cache.EnemiesCount[AoERadius] > 1 then
              if AR.Cast(S.BrutalSlash) then return "Cast"; end
            end
            -- actions.st_generators+=/thrash_cat,if=refreshable&(spell_targets.thrash_cat>2)
            -- TODO: TTD check?
            if S.Thrash:IsCastable() and Target:FilteredTimeToDie(">=", 6, -Target:DebuffRemainsP(S.Thrash)) and Target:DebuffRefreshableP(S.Thrash, ThrashThreshold) and (Cache.EnemiesCount[ThrashRadius] > 2) then
              if AR.Cast(S.Thrash) then return ""; end
            end
            -- actions.st_generators+=/thrash_cat,if=spell_targets.thrash_cat>3&equipped.luffa_wrappings&talent.brutal_slash.enabled
            if S.Thrash:IsCastable() and (Cache.EnemiesCount[ThrashRadius] > 3) and I.LuffaWrappings:IsEquipped() and S.BrutalSlash:IsAvailable() then
              if AR.Cast(S.Thrash) then return ""; end
            end
            if S.Rake:IsCastable(MeleeRange)
              and (Target:DebuffRefreshableP(S.RakeDebuff, 0)
                or (Target:TimeToDie() > 4
                  -- rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
                  and (not S.Bloodtalons:IsAvailable() and Target:DebuffRefreshableP(S.RakeDebuff, RakeThreshold)
                  -- rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
                    or (S.Bloodtalons:IsAvailable() and Player:Buff(S.BloodtalonsBuff) and (Target:DebuffRemainsP(S.RakeDebuff) <= 7 and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake) * 0.85))))) then
              if AR.Cast(S.Rake) then return "Cast"; end
            end
            -- brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))
            -- TODO: raid_events.adds
            if S.BrutalSlash:IsCastable(AoERadius, true) and Player:Buff(S.TigersFury) then
              if AR.Cast(S.BrutalSlash) then return "Cast"; end
            end
            -- actions.st_generators+=/moonfire_cat,target_if=refreshable
            if S.LunarInspiration:IsAvailable() and S.MoonfireCat:IsCastable(RangedRange) and Target:DebuffRefreshableP(S.MoonfireCat, MoonfireThreshold) then
              if AR.Cast(S.MoonfireCat) then return "Cast"; end
            end
            if S.Thrash:IsCastable(ThrashRadius, true) and Target:FilteredTimeToDie(">=", 6, -Target:DebuffRemainsP(S.Thrash)) and Target:DebuffRefreshableP(S.Thrash, ThrashThreshold)
              -- thrash_cat,if=refreshable&(variable.use_thrash=2|spell_targets.thrash_cat>1)
              -- Note: variable.use_thrash=2 is used to maintain thrash
              -- TODO: add an option for variable.use_thrash=2: 'Maintain thrash in Single Target'
              and (Cache.EnemiesCount[ThrashRadius] >= 2
              -- thrash_cat,if=refreshable&variable.use_thrash=1&buff.clearcasting.react
                or I.LuffaWrappings:IsEquipped() and Player:Buff(S.Clearcasting)) then
                if AR.Cast(S.Thrash) then return "Cast"; end
            end
            -- swipe_cat,if=spell_targets.swipe_cat>1
            if S.Swipe:IsCastable() and AR.AoEON() and Cache.EnemiesCount[AoERadius] >= 2 then
              if AR.Cast(S.Swipe) then return "Cast"; end
            end
            -- actions.st_generators+=/shred,if=dot.rake.remains>(action.shred.cost+action.rake.cost-energy)%energy.regen|buff.clearcasting.react
            if S.Shred:IsCastable() 
            and (
              Target:DebuffRemainsP(S.RakeDebuff) > Player:EnergyTimeToXP(S.Shred:Cost() + S.Rake:Cost())
              or Player:BuffP(S.Clearcasting)
            ) then
              if AR.Cast(S.Shred) then return "Cast"; end
            end
            if AR.Cast(S.PoolEnergy) then return "Pooling"; end
        end
        -- rake,if=!ticking|buff.prowl.up
        if S.Rake:IsCastable() and (Target:DebuffRefreshableP(S.RakeDebuff, 0) or Player:IsStealthed()) then
          if AR.Cast(S.Rake) then return "Cast"; end
        end
        -- moonfire_cat,if=talent.lunar_inspiration.enabled&!ticking
        if S.LunarInspiration:IsAvailable() and S.MoonfireCat:IsCastable() and Target:DebuffRefreshableP(S.MoonfireCat, 0) then
          if AR.Cast(S.MoonfireCat) then return "Cast"; end
        end
        -- savage_roar,if=!buff.savage_roar.up
        if S.SavageRoar:IsCastable() and not Player:Buff(S.SavageRoar) then
          if AR.Cast(S.SavageRoar) then return "Cast"; end
        end
        if AR.CDsON() then
          -- berserk
          if S.Berserk:IsCastable() then
            if AR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
          end
          -- incarnation
          if S.Incarnation:IsCastable() then
            if AR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
          end
        end
        -- tigers_fury
        if S.TigersFury:IsCastable() then
          if AR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "Cast"; end
        end
        -- regrowth,if=(talent.sabertooth.enabled|buff.predatory_swiftness.up)&talent.bloodtalons.enabled&buff.bloodtalons.down&combo_points=5
        if S.Regrowth:IsCastable() and (Player:ComboPoints() == 5) and (not Player:Buff(S.BloodtalonsBuff)) and S.Bloodtalons:IsAvailable() and (S.Sabertooth:IsAvailable() or Player:Buff(S.PredatorySwiftness)) then
          if AR.Cast(S.Regrowth) then return "Cast"; end
        end
        -- rip,if=combo_points=5 // Putting this above ashamanes like in the APL to accomodate entering a fight with 5 Combopoints at this stage
        if S.Rip:IsCastable() and Player:ComboPoints() == 5 then
          if AR.Cast(S.Rip) then return "Cast"; end
        end
        -- ashamanes_frenzy
        if AR.CDsON() and S.AshamanesFrenzy:IsCastable() then
          if AR.Cast(S.AshamanesFrenzy) then return "Cast"; end
        end
        -- thrash_cat,if=!ticking&variable.use_thrash>0
        if S.Thrash:IsCastable() and I.LuffaWrappings:IsEquipped() and (not (Target:DebuffRemainsP(S.Thrash) > 1)) then
          if AR.Cast(S.Thrash) then return "Cast"; end
        end
        -- shred
        if S.Shred:IsCastable() then
          if AR.Cast(S.Shred) then return "Cast"; end
        end
      else
        if S.CatForm:IsCastable() then
          if AR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "Cast"; end
        end
      end
      return;
    end
  end
  AR.SetAPL(103, APL);


--- ======= SIMC =======
-- Imported Current APL on 2017-12-02, 07:56 CEST
-- # Default consumables
-- potion=potion_of_prolonged_power
-- flask=seventh_demon
-- food=lemon_herb_filet
-- augmentation=defiled

-- # This default action priority list is automatically created based on your character.
-- # It is a attempt to provide you with a action list that is both simple and practicable,
-- # while resulting in a meaningful and good simulation. It may not result in the absolutely highest possible dps.
-- # Feel free to edit, adapt and improve it to your own needs.
-- # SimulationCraft is always looking for updates and improvements to the default action lists.

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/regrowth,if=talent.bloodtalons.enabled
-- actions.precombat+=/variable,name=use_thrash,value=0
-- actions.precombat+=/variable,name=use_thrash,value=1,if=equipped.luffa_wrappings
-- actions.precombat+=/cat_form
-- actions.precombat+=/prowl
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion

-- # Executed every time the actor is available.
-- actions=run_action_list,name=single_target,if=dot.rip.ticking|time>15
-- actions+=/rake,if=!ticking|buff.prowl.up
-- actions+=/dash,if=!buff.cat_form.up
-- actions+=/auto_attack
-- actions+=/moonfire_cat,if=talent.lunar_inspiration.enabled&!ticking
-- actions+=/savage_roar,if=!buff.savage_roar.up
-- actions+=/berserk
-- actions+=/incarnation
-- actions+=/tigers_fury
-- actions+=/ashamanes_frenzy
-- actions+=/regrowth,if=(talent.sabertooth.enabled|buff.predatory_swiftness.up)&talent.bloodtalons.enabled&buff.bloodtalons.down&combo_points=5
-- actions+=/rip,if=combo_points=5
-- actions+=/thrash_cat,if=!ticking&variable.use_thrash>0
-- actions+=/shred

-- actions.cooldowns=dash,if=!buff.cat_form.up
-- actions.cooldowns+=/prowl,if=buff.incarnation.remains<0.5&buff.jungle_stalker.up
-- actions.cooldowns+=/berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
-- actions.cooldowns+=/tigers_fury,if=energy.deficit>=60
-- actions.cooldowns+=/berserking
-- actions.cooldowns+=/elunes_guidance,if=combo_points=0&energy>=50
-- actions.cooldowns+=/incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
-- actions.cooldowns+=/potion,name=prolonged_power,if=target.time_to_die<65|(time_to_die<180&(buff.berserk.up|buff.incarnation.up))
-- actions.cooldowns+=/ashamanes_frenzy,if=combo_points>=2&(!talent.bloodtalons.enabled|buff.bloodtalons.up)
-- actions.cooldowns+=/shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
-- actions.cooldowns+=/use_items

-- actions.single_target=cat_form,if=!buff.cat_form.up
-- actions.single_target+=/rake,if=buff.prowl.up|buff.shadowmeld.up
-- actions.single_target+=/auto_attack
-- actions.single_target+=/call_action_list,name=cooldowns
-- actions.single_target+=/ferocious_bite,target_if=dot.rip.ticking&dot.rip.remains<3&target.time_to_die>10&(target.health.pct<25|talent.sabertooth.enabled)
-- actions.single_target+=/regrowth,if=combo_points=5&buff.predatory_swiftness.up&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8)
-- actions.single_target+=/regrowth,if=combo_points>3&talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.apex_predator.up&buff.incarnation.down
-- actions.single_target+=/ferocious_bite,if=buff.apex_predator.up
-- actions.single_target+=/run_action_list,name=st_finishers,if=combo_points>4
-- actions.single_target+=/run_action_list,name=st_generators

-- actions.st_finishers=pool_resource,for_next=1
-- actions.st_finishers+=/savage_roar,if=buff.savage_roar.down
-- actions.st_finishers+=/pool_resource,for_next=1
-- actions.st_finishers+=/rip,target_if=!ticking|(remains<=duration*0.3)&(target.health.pct>25&!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
-- actions.st_finishers+=/pool_resource,for_next=1
-- actions.st_finishers+=/savage_roar,if=buff.savage_roar.remains<12
-- actions.st_finishers+=/maim,if=buff.fiery_red_maimers.up
-- actions.st_finishers+=/ferocious_bite,max_energy=1

-- actions.st_generators=regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points>=2&cooldown.ashamanes_frenzy.remains<gcd
-- actions.st_generators+=/regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
-- actions.st_generators+=/regrowth,if=equipped.ailuro_pouncers&talent.bloodtalons.enabled&(buff.predatory_swiftness.stack>2|(buff.predatory_swiftness.stack>1&dot.rake.remains<3))&buff.bloodtalons.down
-- actions.st_generators+=/brutal_slash,if=spell_targets.brutal_slash>desired_targets
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/thrash_cat,if=refreshable&(spell_targets.thrash_cat>2)
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/thrash_cat,if=spell_targets.thrash_cat>3&equipped.luffa_wrappings&talent.brutal_slash.enabled
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
-- actions.st_generators+=/brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))
-- actions.st_generators+=/moonfire_cat,target_if=refreshable
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/thrash_cat,if=refreshable&(variable.use_thrash=2|spell_targets.thrash_cat>1)
-- actions.st_generators+=/thrash_cat,if=refreshable&variable.use_thrash=1&buff.clearcasting.react
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/swipe_cat,if=spell_targets.swipe_cat>1
-- actions.st_generators+=/shred,if=dot.rake.remains>(action.shred.cost+action.rake.cost-energy)%energy.regen|buff.clearcasting.react

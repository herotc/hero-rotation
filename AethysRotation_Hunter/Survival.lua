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
  Spell.Hunter.Survival = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    AspectoftheEagle              = Spell(186289),
    Carve                         = Spell(187708),
    ExplosiveTrap                 = Spell(191433),
    ExplosiveTrapDot              = Spell(13812),
    FlankingStrike                = Spell(202800),
    Harpoon                       = Spell(190925),
    Lacerate                      = Spell(185855),
    MongooseBite                  = Spell(190928),
    MongooseFury                  = Spell(190931),
    RaptorStrike                  = Spell(186270),
    -- Talents
    AMurderofCrows                = Spell(206505),
    AnimalInstincts               = Spell(204315),
    Butchery                      = Spell(212436),
    Caltrops                      = Spell(187698),
    CaltropsDebuff                = Spell(194279),
    CaltropsTalent                = Spell(194277),
    DragonsfireGrenade            = Spell(194855),
    MokNathalTactics              = Spell(201081),
    SerpentSting                  = Spell(87935),
    SerpentStingDebuff            = Spell(118253),
    SnakeHunter                   = Spell(201078),
    SpittingCobra                 = Spell(194407),
    SteelTrap                     = Spell(187650),
    SteelTrapDebuff               = Spell(162487),
    SteelTrapTalent               = Spell(162488),
    ThrowingAxes                  = Spell(200163),
    WayoftheMokNathal             = Spell(201082),
    -- Artifact
    FuryoftheEagle                = Spell(203415),
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
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Hunter.Commons,
    Survival = AR.GUISettings.APL.Hunter.Survival
  };


--- APL Action Lists (and Variables)
  -- actions=variable,name=frizzosEquipped,value=(equipped.137043)
  local function FrizzosEquipped ()
    return I.FrizzosFinger:IsEquipped();
  end
  -- actions+=/variable,name=mokTalented,value=(talent.way_of_the_moknathal.enabled)
  local function MokTalented ()
    return S.WayoftheMokNathal:IsAvailable();
  end
  local function CDs ()
    if AR.CDsON() then
      -- actions.CDs=arcane_torrent,if=focus<=30
      if S.ArcaneTorrent:IsCastable() and Player:Focus() <= 30 then
        if AR.Cast(S.ArcaneTorrent) then return ""; end
      end
      -- actions.CDs+=/berserking,if=buff.aspect_of_the_eagle.up
      if S.Berserking:IsCastable() and Player:Buff(S.AspectoftheEagle) then
        if AR.Cast(S.Berserking) then return ""; end
      end
      -- actions.CDs+=/blood_fury,if=buff.aspect_of_the_eagle.up
      if S.BloodFury:IsCastable() and Player:Buff(S.AspectoftheEagle) then
        if AR.Cast(S.BloodFury) then return ""; end
      end
      -- actions.CDs+=/potion,if=buff.aspect_of_the_eagle.up&(buff.berserking.up|buff.blood_fury.up)
      if Settings.Survival.ShowPoPP and I.PotionOfProlongedPower:IsReady() and Player:BuffP(S.AspectoftheEagle) and (Player:BuffP(S.Berserking) or Player:BuffP(S.BloodFury)) then
        if AR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
      end
      -- actions.CDs+=/snake_hunter,if=cooldown.mongoose_bite.charges=0&buff.mongoose_fury.remains>3*gcd&(cooldown.aspect_of_the_eagle.remains>5&!buff.aspect_of_the_eagle.up)
      if S.SnakeHunter:IsCastable() and S.MongooseBite:Charges() == 0 and Player:BuffRemains(S.MongooseFury) > 3 * Player:GCD() and (S.AspectoftheEagle:CooldownRemains() > 5 and not Player:BuffP(S.AspectoftheEagle)) then
        if AR.Cast(S.SnakeHunter, Settings.Survival.OffGCDasOffGCD.SnakeHunter) then return ""; end
      end
      -- actions.CDs+=/aspect_of_the_eagle,if=buff.mongoose_fury.up&(cooldown.mongoose_bite.charges=0|buff.mongoose_fury.remains<11)
      if S.AspectoftheEagle:IsCastable() and Player:BuffP(S.MongooseFury) and (S.MongooseBite:Charges() == 0 or Player:BuffRemainsP(S.MongooseFury) < 11) then
        if AR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
      end
    end
  end
  local function AoE ()
    if AR.AoEON() then
      -- actions.aoe=butchery
      if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 40 then
        if AR.Cast(S.Butchery) then return ""; end
      end
      -- actions.aoe+=/caltrops,if=!ticking
      if S.Caltrops:IsCastable() and S.CaltropsTalent:CooldownUp() and not Target:Debuff(S.CaltropsDebuff) and not S.SteelTrapTalent:IsAvailable() then
        if AR.Cast(S.Caltrops) then return ""; end
      end
      -- actions.aoe+=/explosive_trap
      if S.ExplosiveTrap:IsCastable() then
        if AR.Cast(S.ExplosiveTrap) then return ""; end
      end
      -- actions.aoe+=/carve,if=(talent.serpent_sting.enabled&dot.serpent_sting.refreshable)|(active_enemies>5)
      if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and ((S.SerpentSting:IsAvailable() and Target:DebuffRefreshable(S.SerpentStingDebuff, 3.6)) or (Cache.EnemiesCount[5] > 5)) then
        if AR.Cast(S.Carve) then return ""; end
      end
    end
  end
  local function BitePhase ()
    -- actions.bitePhase=mongoose_bite,if=cooldown.mongoose_bite.charges=3
    if S.MongooseBite:IsCastable() and S.MongooseBite:Charges() == 3 then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.bitePhase+=/flanking_strike,if=buff.mongoose_fury.remains>(gcd*(cooldown.mongoose_bite.charges+1))
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and Player:BuffRemainsP(S.MongooseFury) > (Player:GCD() *(S.MongooseBite:Charges() + 1)) then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.bitePhase+=/fury_of_the_eagle,if=(!variable.mokTalented|(buff.moknathal_tactics.remains>(gcd*(8%3))))&!buff.aspect_of_the_eagle.up,interrupt_immediate=1,interrupt_if=cooldown.mongoose_bite.charges=3|(ticks_remain<=1&buff.moknathal_tactics.remains<0.7)
    -- Keep the ancient line because of interrupt_immediate=1,interrupt_if
    -- actions.bitePhase=fury_of_the_eagle,if=(!talent.way_of_the_moknathal.enabled|buff.moknathal_tactics.remains>(gcd*(8%3)))&buff.mongoose_fury.stack=6,interrupt_if=(talent.way_of_the_moknathal.enabled&buff.moknathal_tactics.remains<=tick_time)
    if AR.CDsON() and S.FuryoftheEagle:IsCastable() and (not S.WayoftheMokNathal:IsAvailable() or Player:BuffRemains(S.MokNathalTactics) > (Player:GCD() * (8 / 3))) and Player:BuffStack(S.MongooseFury) == 6 then 
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.bitePhase+=/mongoose_bite,if=buff.mongoose_fury.up
    if S.MongooseBite:IsCastable() and Player:Buff(S.MongooseFury) then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.bitePhase+=/lacerate,if=dot.lacerate.refreshable&(focus+35>(45-((cooldown.flanking_strike.remains%gcd)*(focus.regen*gcd))))
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Target:DebuffRefreshable(S.Lacerate, 3.6) and (Player:Focus() + 35 >(45 -((S.FlankingStrike:CooldownRemains() / Player:GCD()) * (Player:FocusRegen() * Player:GCD())))) then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.bitePhase+=/raptor_strike,if=buff.t21_2p_exposed_flank.up
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:BuffP(S.ExposedFlank) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.bitePhase+=/spitting_cobra
    if S.SpittingCobra:IsCastable() then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.bitePhase+=/dragonsfire_grenade
    if S.DragonsfireGrenade:IsCastable() then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.bitePhase+=/steel_trap
    if S.SteelTrap:IsCastable() and S.SteelTrapTalent:CooldownUp() and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.bitePhase+=/a_murder_of_crows
    if S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 30 then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.bitePhase+=/caltrops,if=!ticking
    if S.Caltrops:IsCastable() and S.CaltropsTalent:CooldownUp() and not Target:Debuff(S.CaltropsDebuff) and not S.SteelTrapTalent:IsAvailable() then
      if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.bitePhase+=/explosive_trap
    if S.ExplosiveTrap:IsCastable() then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
  end
  local function BiteTrigger ()
    -- actions.biteTrigger=lacerate,if=remains<14&set_bonus.tier20_4pc&cooldown.mongoose_bite.remains<gcd*3
    if S.Lacerate:IsCastable() and Target:DebuffRemainsP(S.Lacerate) < 14 and AC.Tier20_4Pc and S.MongooseBite:CooldownRemains() < Player:GCD() * 3 then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.biteTrigger+=/mongoose_bite,if=charges>=2
    if S.MongooseBite:IsCastable() and S.MongooseBite:Charges() >= 3 then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
  end
  local function Fillers ()
    -- actions.fillers=flanking_strike,if=cooldown.mongoose_bite.charges<3
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and S.MongooseBite:Charges() < 3 then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.fillers+=/spitting_cobra
    if S.SpittingCobra:IsCastable() then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.fillers+=/dragonsfire_grenade
    if S.DragonsfireGrenade:IsCastable() then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.fillers+=/lacerate,if=refreshable|!ticking
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and (Target:DebuffRefreshable(S.Lacerate, 3.6) or not Target:Debuff(S.Lacerate)) then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.fillers+=/raptor_strike,if=buff.t21_2p_exposed_flank.up&!variable.mokTalented
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:BuffP(S.ExposedFlank) and not MokTalented() then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.fillers+=/raptor_strike,if=(talent.serpent_sting.enabled&!dot.serpent_sting.ticking)
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and (S.SerpentSting:IsAvailable() and not Target:Debuff(S.SerpentStingDebuff)) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.fillers+=/steel_trap,if=refreshable|!ticking
    if S.SteelTrap:IsCastable() and S.SteelTrapTalent:CooldownUp() and not S.CaltropsTalent:IsAvailable() and (Target:DebuffRefreshable(S.SteelTrapDebuff, 3.6) or not Target:Debuff(S.SteelTrapTalent)) then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.fillers+=/caltrops,if=refreshable|!ticking
    if S.Caltrops:IsCastable() and S.CaltropsTalent:CooldownUp() and not S.SteelTrapTalent:IsAvailable() and (Target:DebuffRefreshable(S.CaltropsDebuff, 3.6) or not Target:Debuff(S.CaltropsDebuff)) then
      if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.fillers+=/explosive_trap
    if S.ExplosiveTrap:IsCastable() then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.fillers+=/butchery,if=variable.frizzosEquipped&dot.lacerate.refreshable&(focus+40>(50-((cooldown.flanking_strike.remains%gcd)*(focus.regen*gcd))))
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 40 and FrizzosEquipped() and Target:DebuffRefreshable(S.Lacerate, 3.6) and (Player:Focus() + 40 >(50 -((S.FlankingStrike:CooldownRemains() / Player:GCD()) * (Player:FocusRegen() * Player:GCD())))) then
      if AR.Cast(S.Butchery) then return ""; end
    end
  end
  local function MokMaintain ()
    -- actions.mokMaintain=raptor_strike,if=(buff.moknathal_tactics.remains<(gcd)|(buff.moknathal_tactics.stack<3))
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and ((Player:BuffRemainsP(S.MokNathalTactics) < (Player:GCD())) or (Player:BuffStack(S.MokNathalTactics) < 3)) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
  end
--- APL Main
  local function APL ()
    -- Unit Update
    AC.GetEnemies(8);
    AC.GetEnemies(5);
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
      -- Exhilaration
      if S.Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.Survival.ExhilarationHP then
        if AR.Cast(S.Exhilaration, Settings.Survival.OffGCDasOffGCD.Exhilaration) then return "Cast"; end
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
          if AR.Cast(S.Harpoon) then return ""; end
        end
        if Target:IsInRange(5) then
          if S.Lacerate:IsCastable() then
            if AR.Cast(S.Lacerate) then return ""; end
          end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      
      -- actions+=/call_action_list,name=mokMaintain,if=variable.mokTalented
      if MokTalented() then
        ShouldReturn = MokMaintain();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=CDs
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      -- actions+=/call_action_list,name=aoe,if=active_enemies>=3
      if Cache.EnemiesCount[5] >= 3 then
        ShouldReturn = AoE();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=fillers,if=!buff.mongoose_fury.up
      if not Player:BuffP(S.MongooseFury) then
        ShouldReturn = Fillers();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=biteTrigger,if=!buff.mongoose_fury.up
      if not Player:BuffP(S.MongooseFury) then
        ShouldReturn = BiteTrigger();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=bitePhase,if=buff.mongoose_fury.up
      if Player:BuffP(S.MongooseFury) then
        ShouldReturn = BitePhase();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Pooling
      if S.RaptorStrike:IsCastable() and Target:IsInRange(5) then
        if AR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      end
      return;
    end
  end

  AR.SetAPL(255, APL);


--- Last Update: 11/28/2017


-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/explosive_trap
-- actions.precombat+=/steel_trap
-- actions.precombat+=/dragonsfire_grenade
-- actions.precombat+=/harpoon

-- # Executed every time the actor is available.
-- actions=variable,name=frizzosEquipped,value=(equipped.137043)
-- actions+=/variable,name=mokTalented,value=(talent.way_of_the_moknathal.enabled)
-- actions+=/use_items
-- actions+=/muzzle,if=target.debuff.casting.react
-- actions+=/auto_attack
-- actions+=/call_action_list,name=mokMaintain,if=variable.mokTalented
-- actions+=/call_action_list,name=CDs
-- actions+=/call_action_list,name=aoe,if=active_enemies>=3
-- actions+=/call_action_list,name=fillers,if=!buff.mongoose_fury.up
-- actions+=/call_action_list,name=biteTrigger,if=!buff.mongoose_fury.up
-- actions+=/call_action_list,name=bitePhase,if=buff.mongoose_fury.up

-- actions.CDs=arcane_torrent,if=focus<=30
-- actions.CDs+=/berserking,if=buff.aspect_of_the_eagle.up
-- actions.CDs+=/blood_fury,if=buff.aspect_of_the_eagle.up
-- actions.CDs+=/potion,if=buff.aspect_of_the_eagle.up&(buff.berserking.up|buff.blood_fury.up)
-- actions.CDs+=/snake_hunter,if=cooldown.mongoose_bite.charges=0&buff.mongoose_fury.remains>3*gcd&(cooldown.aspect_of_the_eagle.remains>5&!buff.aspect_of_the_eagle.up)
-- actions.CDs+=/aspect_of_the_eagle,if=buff.mongoose_fury.up&(cooldown.mongoose_bite.charges=0|buff.mongoose_fury.remains<11)

-- actions.aoe=butchery
-- actions.aoe+=/caltrops,if=!ticking
-- actions.aoe+=/explosive_trap
-- actions.aoe+=/carve,if=(talent.serpent_sting.enabled&dot.serpent_sting.refreshable)|(active_enemies>5)

-- actions.bitePhase=mongoose_bite,if=cooldown.mongoose_bite.charges=3
-- actions.bitePhase+=/flanking_strike,if=buff.mongoose_fury.remains>(gcd*(cooldown.mongoose_bite.charges+1))
-- actions.bitePhase+=/mongoose_bite,if=buff.mongoose_fury.up
-- actions.bitePhase+=/fury_of_the_eagle,if=(!variable.mokTalented|(buff.moknathal_tactics.remains>(gcd*(8%3))))&!buff.aspect_of_the_eagle.up,interrupt_immediate=1,interrupt_if=cooldown.mongoose_bite.charges=3|(ticks_remain<=1&buff.moknathal_tactics.remains<0.7)
-- actions.bitePhase+=/lacerate,if=dot.lacerate.refreshable&(focus+35>(45-((cooldown.flanking_strike.remains%gcd)*(focus.regen*gcd))))
-- actions.bitePhase+=/raptor_strike,if=buff.t21_2p_exposed_flank.up
-- actions.bitePhase+=/spitting_cobra
-- actions.bitePhase+=/dragonsfire_grenade
-- actions.bitePhase+=/steel_trap
-- actions.bitePhase+=/a_murder_of_crows
-- actions.bitePhase+=/caltrops,if=!ticking
-- actions.bitePhase+=/explosive_trap

-- actions.biteTrigger=lacerate,if=remains<14&set_bonus.tier20_4pc&cooldown.mongoose_bite.remains<gcd*3
-- actions.biteTrigger+=/mongoose_bite,if=charges>=2

-- actions.fillers=flanking_strike,if=cooldown.mongoose_bite.charges<3
-- actions.fillers+=/spitting_cobra
-- actions.fillers+=/dragonsfire_grenade
-- actions.fillers+=/lacerate,if=refreshable|!ticking
-- actions.fillers+=/raptor_strike,if=buff.t21_2p_exposed_flank.up&!variable.mokTalented
-- actions.fillers+=/raptor_strike,if=(talent.serpent_sting.enabled&!dot.serpent_sting.ticking)
-- actions.fillers+=/steel_trap,if=refreshable|!ticking
-- actions.fillers+=/caltrops,if=refreshable|!ticking
-- actions.fillers+=/explosive_trap
-- actions.fillers+=/butchery,if=variable.frizzosEquipped&dot.lacerate.refreshable&(focus+40>(50-((cooldown.flanking_strike.remains%gcd)*(focus.regen*gcd))))
-- actions.fillers+=/carve,if=variable.frizzosEquipped&dot.lacerate.refreshable&(focus+40>(50-((cooldown.flanking_strike.remains%gcd)*(focus.regen*gcd))))
-- actions.fillers+=/flanking_strike
-- actions.fillers+=/raptor_strike,if=(variable.mokTalented&buff.moknathal_tactics.remains<gcd*4)|(focus>((25-focus.regen*gcd)+55))

-- actions.mokMaintain=raptor_strike,if=(buff.moknathal_tactics.remains<(gcd)|(buff.moknathal_tactics.stack<3))

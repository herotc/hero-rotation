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
    PoolFocus                     = Spell(9999000010)
    -- Macros
  };
  local S = Spell.Hunter.Survival;
  -- Items
  if not Item.Hunter then Item.Hunter = {}; end
  Item.Hunter.Survival = {
    -- Legendaries
    FrizzosFinger                 = Item(137043, {11, 12})
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
      -- actions.CDs+=/potion,if=buff.aspect_of_the_eagle.up
      -- actions.CDs+=/snake_hunter,if=cooldown.mongoose_bite.charges=0&buff.mongoose_fury.remains>3*gcd
      if S.SnakeHunter:IsCastable() and S.MongooseBite:Charges() == 0 and Player:BuffRemains(S.MongooseFury) > 3 * Player:GCD() then
        if AR.Cast(S.SnakeHunter, Settings.Survival.OffGCDasOffGCD.SnakeHunter) then return ""; end
      end
      -- actions.CDs+=/aspect_of_the_eagle,if=(buff.mongoose_fury.remains<=11&buff.mongoose_fury.up)&(cooldown.fury_of_the_eagle.remains>buff.mongoose_fury.remains)
      if S.AspectoftheEagle:IsCastable() and (Player:BuffRemains(S.MongooseFury) <= 11 and Player:Buff(S.MongooseFury)) and (S.FuryoftheEagle:CooldownRemains() > Player:BuffRemains(S.MongooseFury)) then
        if AR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
      end 
      -- actions.CDs+=/aspect_of_the_eagle,if=(buff.mongoose_fury.remains<=7&buff.mongoose_fury.up)
      if S.AspectoftheEagle:IsCastable() and (Player:BuffRemains(S.MongooseFury) <= 7 and Player:Buff(S.MongooseFury)) then
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
      -- actions.aoe+=/caltrops,if=!dot.caltrops.ticking
      if S.Caltrops:IsCastable() and not S.CaltropsTalent:CooldownDown() and not Target:Debuff(S.CaltropsDebuff) and not S.SteelTrapTalent:IsAvailable() then
        if AR.Cast(S.Caltrops) then return ""; end
      end
      -- actions.aoe+=/explosive_trap
      if S.ExplosiveTrap:IsCastable() then
        if AR.Cast(S.ExplosiveTrap) then return ""; end
      end
      -- actions.aoe+=/carve,if=talent.serpent_sting.enabled&!dot.serpent_sting.ticking
      if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and S.SerpentSting:IsAvailable() and not Target:Debuff(S.SerpentStingDebuff) then
        if AR.Cast(S.Carve) then return ""; end
      end
      -- actions.aoe+=/carve,if=active_enemies>5
      if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and Cache.EnemiesCount[5] > 5 then
        if AR.Cast(S.Carve) then return ""; end
      end
    end
  end
  local function BiteFill ()
    -- actions.biteFill=spitting_cobra
    if S.SpittingCobra:IsCastable() then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.biteFill+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 40 and I.FrizzosFinger:IsEquipped() and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.biteFill+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and I.FrizzosFinger:IsEquipped() and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.biteFill+=/lacerate,if=dot.lacerate.remains<3.6
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.biteFill+=/raptor_strike,if=active_enemies=1&talent.serpent_sting.enabled&!dot.serpent_sting.ticking
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Cache.EnemiesCount[5] == 1 and S.SerpentSting:IsAvailable() and not Target:Debuff(S.SerpentStingDebuff) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.biteFill+=/steel_trap
    if S.SteelTrap:IsCastable() and not S.SteelTrapTalent:CooldownDown() and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.biteFill+=/a_murder_of_crows
    if S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 30 then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.biteFill+=/dragonsfire_grenade
    if S.DragonsfireGrenade:IsCastable() then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.biteFill+=/explosive_trap
    if S.ExplosiveTrap:IsCastable() then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.biteFill+=/caltrops,if=!dot.caltrops.ticking
    if S.Caltrops:IsCastable() and not S.CaltropsTalent:CooldownDown() and not Target:Debuff(S.CaltropsDebuff) and not S.SteelTrapTalent:IsAvailable() then
        if AR.Cast(S.Caltrops) then return ""; end
    end
  end
  local function BitePhase ()
    -- actions.bitePhase=fury_of_the_eagle,if=(!talent.way_of_the_moknathal.enabled|buff.moknathal_tactics.remains>(gcd*(8%3)))&buff.mongoose_fury.stack=6,interrupt_if=(talent.way_of_the_moknathal.enabled&buff.moknathal_tactics.remains<=tick_time)
    -- TODO add interrupt if...
    if AR.CDsON() and S.FuryoftheEagle:IsCastable() and (not S.WayoftheMokNathal:IsAvailable() or Player:BuffRemains(S.MokNathalTactics) > (Player:GCD() * (8 / 3))) and Player:BuffStack(S.MongooseFury) == 6 then 
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.bitePhase+=/mongoose_bite,if=charges>=2&cooldown.mongoose_bite.remains<gcd*2
    if S.MongooseBite:IsCastable() and S.MongooseBite:Charges() >= 2 and S.MongooseBite:CooldownRemains() < Player:GCD() * 2 then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.bitePhase+=/flanking_strike,if=((buff.mongoose_fury.remains>(gcd*(cooldown.mongoose_bite.charges+2)))&cooldown.mongoose_bite.charges<=1)&!buff.aspect_of_the_eagle.up
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and ((Player:BuffRemains(S.MongooseFury) > (Player:GCD() * (S.MongooseBite:Charges() + 2 ))) and S.MongooseBite:Charges() <= 1) and not Player:Buff(S.AspectoftheEagle) then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.bitePhase+=/mongoose_bite,if=buff.mongoose_fury.up
    if S.MongooseBite:IsCastable() and Player:Buff(S.MongooseFury) then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.bitePhase+=/flanking_strike
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
  end
  local function Fillers ()
    -- actions.fillers=carve,if=active_enemies>1&talent.serpent_sting.enabled&!dot.serpent_sting.ticking
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and Cache.EnemiesCount[5] > 1 and S.SerpentSting:IsAvailable() and not Target:Debuff(S.SerpentStingDebuff) then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.fillers+=/throwing_axes
    if S.ThrowingAxes:IsCastable() then
      if AR.Cast(S.ThrowingAxes) then return ""; end
    end
    -- actions.fillers+=/carve,if=active_enemies>2
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and Cache.EnemiesCount[5] > 2 then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.fillers+=/raptor_strike,if=(talent.way_of_the_moknathal.enabled&buff.moknathal_tactics.remains<gcd*4)
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and (S.WayoftheMokNathal:IsAvailable() and Player:BuffRemains(S.MokNathalTactics) < Player:GCD() * 4) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.fillers+=/raptor_strike,if=focus>((25-focus.regen*gcd)+55)
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:Focus() > ((25 - Player:FocusRegen() * Player:GCD()) + 55) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
  end
  local function MokMaintain ()
    -- actions.mokMaintain=raptor_strike,if=buff.moknathal_tactics.remains<gcd
    -- Add gdc*2 for human reactivity
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:BuffRemains(S.MokNathalTactics) < Player:GCD() * 2 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.mokMaintain+=/raptor_strike,if=buff.moknathal_tactics.stack<2
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:BuffStack(S.MokNathalTactics) < 2 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
  end
  local function PreBitePhase ()
    -- actions.preBitePhase=flanking_strike,if=cooldown.mongoose_bite.charges<3
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and S.MongooseBite:Charges() < 3 then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.preBitePhase+=/spitting_cobra
    if S.SpittingCobra:IsCastable() then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.preBitePhase+=/lacerate,if=!dot.lacerate.ticking
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and not Target:Debuff(S.Lacerate) then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.preBitePhase+=/raptor_strike,if=active_enemies=1&talent.serpent_sting.enabled&!dot.serpent_sting.ticking
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 25 and Cache.EnemiesCount[5] == 1 and S.SerpentSting:IsAvailable() and not Target:Debuff(S.SerpentStingDebuff) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.preBitePhase+=/steel_trap
    if S.SteelTrap:IsCastable() and not S.SteelTrapTalent:CooldownDown() and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.preBitePhase+=/a_murder_of_crows
    if S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 30 then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.preBitePhase+=/dragonsfire_grenade
    if S.DragonsfireGrenade:IsCastable() then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.preBitePhase+=/explosive_trap
    if S.ExplosiveTrap:IsCastable() then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.preBitePhase+=/caltrops,if=!dot.caltrops.ticking
    if S.Caltrops:IsCastable() and not S.CaltropsTalent:CooldownDown() and not Target:Debuff(S.CaltropsDebuff) and not S.SteelTrapTalent:IsAvailable() then
        if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.preBitePhase+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 40 and I.FrizzosFinger:IsEquipped() and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.preBitePhase+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and I.FrizzosFinger:IsEquipped() and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.preBitePhase+=/lacerate,if=dot.lacerate.remains<3.6
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Lacerate) then return ""; end
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
      -- actions+=/call_action_list,name=mokMaintain,if=talent.way_of_the_moknathal.enabled
      if S.WayoftheMokNathal:IsAvailable() then
        ShouldReturn = MokMaintain();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=CDs,if=buff.moknathal_tactics.stack>=2|!talent.way_of_the_moknathal.enabled
      if ((S.WayoftheMokNathal:IsAvailable() and Player:BuffRemains(S.MokNathalTactics) >= 2) or not S.WayoftheMokNathal:IsAvailable()) then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=preBitePhase,if=!buff.mongoose_fury.up
      if not Player:Buff(S.MongooseFury) then
        ShouldReturn = PreBitePhase();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=aoe,if=active_enemies>=3
      if Cache.EnemiesCount[5] >= 3 then
        ShouldReturn = AoE();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=bitePhase
      ShouldReturn = BitePhase();
      if ShouldReturn then return ShouldReturn; end
      -- actions+=/call_action_list,name=biteFill
      ShouldReturn = BiteFill();
      if ShouldReturn then return ShouldReturn; end
      -- actions+=/call_action_list,name=fillers
      ShouldReturn = Fillers();
      if ShouldReturn then return ShouldReturn; end
      -- Pooling
      if S.RaptorStrike:IsCastable() and Target:IsInRange(5) then
        if AR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      end
      return;
    end
  end

  AR.SetAPL(255, APL);


--- Last Update: 05/04/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation,type=defiled
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
-- actions=auto_attack
-- actions+=/muzzle,if=target.debuff.casting.react
-- actions+=/call_action_list,name=mokMaintain,if=talent.way_of_the_moknathal.enabled
-- actions+=/call_action_list,name=CDs,if=buff.moknathal_tactics.stack>=2|!talent.way_of_the_moknathal.enabled
-- actions+=/call_action_list,name=preBitePhase,if=!buff.mongoose_fury.up
-- actions+=/call_action_list,name=aoe,if=active_enemies>=3
-- actions+=/call_action_list,name=bitePhase
-- actions+=/call_action_list,name=biteFill
-- actions+=/call_action_list,name=fillers

-- actions.CDs=arcane_torrent,if=focus<=30
-- actions.CDs+=/berserking,if=buff.aspect_of_the_eagle.up
-- actions.CDs+=/blood_fury,if=buff.aspect_of_the_eagle.up
-- actions.CDs+=/potion,if=buff.aspect_of_the_eagle.up
-- actions.CDs+=/berserking,if=buff.aspect_of_the_eagle.up
-- actions.CDs+=/snake_hunter,if=cooldown.mongoose_bite.charges=0&buff.mongoose_fury.remains>3*gcd
-- actions.CDs+=/aspect_of_the_eagle,if=(buff.mongoose_fury.remains<=11&buff.mongoose_fury.up)&(cooldown.fury_of_the_eagle.remains>buff.mongoose_fury.remains)
-- actions.CDs+=/aspect_of_the_eagle,if=(buff.mongoose_fury.remains<=7&buff.mongoose_fury.up)

-- actions.aoe=butchery
-- actions.aoe+=/caltrops,if=!dot.caltrops.ticking
-- actions.aoe+=/explosive_trap
-- actions.aoe+=/carve,if=talent.serpent_sting.enabled&!dot.serpent_sting.ticking
-- actions.aoe+=/carve,if=active_enemies>5

-- actions.biteFill=spitting_cobra
-- actions.biteFill+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
-- actions.biteFill+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
-- actions.biteFill+=/lacerate,if=dot.lacerate.remains<3.6
-- actions.biteFill+=/raptor_strike,if=active_enemies=1&talent.serpent_sting.enabled&!dot.serpent_sting.ticking
-- actions.biteFill+=/steel_trap
-- actions.biteFill+=/a_murder_of_crows
-- actions.biteFill+=/dragonsfire_grenade
-- actions.biteFill+=/explosive_trap
-- actions.biteFill+=/caltrops,if=!dot.caltrops.ticking

-- actions.bitePhase=fury_of_the_eagle,if=(!talent.way_of_the_moknathal.enabled|buff.moknathal_tactics.remains>(gcd*(8%3)))&buff.mongoose_fury.stack=6,interrupt_if=(talent.way_of_the_moknathal.enabled&buff.moknathal_tactics.remains<=tick_time)
-- actions.bitePhase+=/mongoose_bite,if=charges>=2&cooldown.mongoose_bite.remains<gcd*2
-- actions.bitePhase+=/flanking_strike,if=((buff.mongoose_fury.remains>(gcd*(cooldown.mongoose_bite.charges+2)))&cooldown.mongoose_bite.charges<=1)&!buff.aspect_of_the_eagle.up
-- actions.bitePhase+=/mongoose_bite,if=buff.mongoose_fury.up
-- actions.bitePhase+=/flanking_strike

-- actions.fillers=carve,if=active_enemies>1&talent.serpent_sting.enabled&!dot.serpent_sting.ticking
-- actions.fillers+=/throwing_axes
-- actions.fillers+=/carve,if=active_enemies>2
-- actions.fillers+=/raptor_strike,if=(talent.way_of_the_moknathal.enabled&buff.moknathal_tactics.remains<gcd*4)
-- actions.fillers+=/raptor_strike,if=focus>((25-focus.regen*gcd)+55)

-- actions.mokMaintain=raptor_strike,if=buff.moknathal_tactics.remains<gcd
-- actions.mokMaintain+=/raptor_strike,if=buff.moknathal_tactics.stack<2

-- actions.preBitePhase=flanking_strike,if=cooldown.mongoose_bite.charges<3
-- actions.preBitePhase+=/spitting_cobra
-- actions.preBitePhase+=/lacerate,if=!dot.lacerate.ticking
-- actions.preBitePhase+=/raptor_strike,if=active_enemies=1&talent.serpent_sting.enabled&!dot.serpent_sting.ticking
-- actions.preBitePhase+=/steel_trap
-- actions.preBitePhase+=/a_murder_of_crows
-- actions.preBitePhase+=/dragonsfire_grenade
-- actions.preBitePhase+=/explosive_trap
-- actions.preBitePhase+=/caltrops,if=!dot.caltrops.ticking
-- actions.preBitePhase+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
-- actions.preBitePhase+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.remains<3.6
-- actions.preBitePhase+=/lacerate,if=dot.lacerate.remains<3.6

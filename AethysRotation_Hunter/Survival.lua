--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCore_Cache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- APL Local Vars
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
    FrizzosFinger                 = Item(137043)  -- 11 & 12
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
  -- # MokNathal
  local function MokNathal ()
    -- actions.moknathal=raptor_strike,if=buff.moknathal_tactics.stack<=1
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Player:BuffStack(S.MokNathalTactics) <= 1 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.moknathal+=/raptor_strike,if=buff.moknathal_tactics.remains<gcd
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Player:BuffRemains(S.MokNathalTactics) < Player:GCD() * 2 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.moknathal+=/fury_of_the_eagle,if=buff.mongoose_fury.stack>=4&buff.mongoose_fury.remains<gcd
    if S.FuryoftheEagle:IsCastable() and Player:BuffStack(S.MongooseFury) >= 4 and Player:BuffRemains(S.MongooseFury) < Player:GCD() then
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.moknathal+=/raptor_strike,if=buff.mongoose_fury.stack>=4&buff.mongoose_fury.remains>gcd&buff.moknathal_tactics.stack>=3&buff.moknathal_tactics.remains<4&cooldown.fury_of_the_eagle.remains<buff.mongoose_fury.remains
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Player:BuffStack(S.MongooseFury) >= 4 and Player:BuffRemains(S.MongooseFury) > Player:GCD() and Player:BuffStack(S.MokNathalTactics) == 3 and Player:BuffRemains(S.MokNathalTactics) < 4 and S.FuryoftheEagle:Cooldown() < Player:BuffRemains(S.MongooseFury) then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.moknathal+=/snake_hunter,if=cooldown.mongoose_bite.charges<=0&buff.mongoose_fury.remains>3*gcd&time>15
    if AR.CDsON() and S.SnakeHunter:IsCastable() and S.MongooseBite:Cooldown() <= 0 and Player:BuffRemains(S.MongooseFury) > 3 * Player:GCD() and AC.CombatTime() > 15 then
      if AR.Cast(S.SnakeHunter) then return ""; end
    end
    -- actions.moknathal+=/spitting_cobra,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4&buff.moknathal_tactics.stack=3
    if AR.CDsON() and S.SpittingCobra:IsCastable() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() >= 0 and Player:BuffStack(S.MongooseFury) < 4 and Player:BuffStack(S.MokNathalTactics) == 3 then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.moknathal+=/steel_trap,if=buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<1
    if S.SteelTrap:IsCastable() and not S.SteelTrapTalent:IsOnCooldown() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and Player:BuffStack(S.MongooseFury) < 1 and not Target:Debuff(S.SteelTrapDebuff) and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.moknathal+=/a_murder_of_crows,if=focus>55-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.stack<4&buff.mongoose_fury.duration>=gcd
    if AR.CDsON() and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:Focus() > 55 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() and Player:BuffStack(S.MongooseFury) < 4 and Player:BuffDuration(S.MongooseFury) >= Player:GCD() then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.moknathal+=/flanking_strike,if=cooldown.mongoose_bite.charges<=1&focus>75-buff.moknathal_tactics.remains*focus.regen
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and S.MongooseBite:Charges() <= 1 and Player:Focus() > 75 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.moknathal+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.remains>=gcd
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() and Player:BuffRemains(S.MongooseFury) >= Player:GCD() then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.moknathal+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.remains>=gcd
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() and Player:BuffRemains(S.MongooseFury) >= Player:GCD() then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.moknathal+=/lacerate,if=refreshable&((focus>55-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges=0&buff.mongoose_fury.stack<3)|(focus>65-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.down&cooldown.mongoose_bite.charges<3))
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Target:DebuffRefreshable(S.Lacerate, 3.6) and ((Player:Focus() > 55 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() == 0 and Player:BuffStack(S.MongooseFury) < 3 ) or
    (Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() and not Player:Buff(S.MongooseFury) and S.MongooseBite:Charges() < 3 )) then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.moknathal+=/caltrops,if=(buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<1&!dot.caltrops.ticking)
    if S.Caltrops:IsCastable() and (Player:BuffDuration(S.MongooseFury) >= Player:GCD() and Player:BuffStack(S.MongooseFury) < 1 and not Target:Debuff(S.CaltropsDebuff)) and not S.CaltropsTalent:IsOnCooldown() and not S.SteelTrapTalent:IsAvailable() then
      if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.moknathal+=/explosive_trap,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges=0&buff.mongoose_fury.stack<1
    if S.ExplosiveTrap:IsCastable() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() == 0 and Player:BuffStack(S.MongooseFury) < 1 then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.moknathal+=/butchery,if=active_enemies>1&focus>65-buff.moknathal_tactics.remains*focus.regen&(buff.mongoose_fury.down|buff.mongoose_fury.remains>gcd*cooldown.mongoose_bite.charges)
    if S.Butchery:IsCastable() and Cache.EnemiesCount[8] > 1 and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() (not Player:Buff(S.MongooseFury) or Player:BuffRemains(S.MongooseFury) > Player:GCD() * S.MongooseBite:Charges()) then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.moknathal+=/carve,if=active_enemies>1&focus>65-buff.moknathal_tactics.remains*focus.regen&(buff.mongoose_fury.down&focus>65-buff.moknathal_tactics.remains*focus.regen|buff.mongoose_fury.remains>gcd*cooldown.mongoose_bite.charges&focus>70-buff.moknathal_tactics.remains*focus.regen)
    if S.Carve:IsCastable() and Cache.EnemiesCount[5] > 1 and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() and (not Player:Buff(S.MongooseFury) and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() or
    Player:BuffRemains(S.MongooseFury) > Player:GCD() * S.MongooseBite:Charges() and Player:Focus() > 70 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen()) then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.moknathal+=/raptor_strike,if=buff.moknathal_tactics.stack=2
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Player:BuffStack(S.MokNathalTactics) == 2 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.moknathal+=/dragonsfire_grenade,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<1
    if S.DragonsfireGrenade:IsCastable() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() >= Player:BuffStack(S.MongooseFury) < 1 then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.moknathal+=/raptor_strike,if=buff.moknathal_tactics.remains<4&buff.mongoose_fury.stack=6&buff.mongoose_fury.remains>cooldown.fury_of_the_eagle.remains&cooldown.fury_of_the_eagle.remains<=5
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Player:BuffRemains(S.MokNathalTactics) < 4 and Player:BuffStack(S.MongooseFury) == 6 and Player:BuffRemains(S.MongooseFury) > S.FuryoftheEagle:Cooldown() and S.FuryoftheEagle:Cooldown() <= 5 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.moknathal+=/fury_of_the_eagle,if=buff.moknathal_tactics.remains>4&buff.mongoose_fury.stack=6&cooldown.mongoose_bite.charges<=1
    if AR.CDsON() and S.FuryoftheEagle:IsCastable() and Player:BuffRemains(S.MokNathalTactics) > 4 and Player:BuffStack(S.MongooseFury) == 6 and S.MongooseBite:Charges() <= 1 then
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.moknathal+=/mongoose_bite,if=buff.aspect_of_the_eagle.up&buff.mongoose_fury.up&buff.moknathal_tactics.stack>=4
    if S.MongooseBite:IsCastable() and Player:Buff(S.AspectoftheEagle) and Player:Buff(S.MongooseFury) and Player:BuffStack(S.MokNathalTactics) >= 4 then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.moknathal+=/raptor_strike,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<=3*gcd&buff.moknathal_tactics.remains<4+gcd&cooldown.fury_of_the_eagle.remains<gcd
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and Player:Buff(S.MongooseFury) and Player:BuffRemains(S.MongooseFury) <= 3 * Player:GCD() and Player:BuffRemains(S.MokNathalTactics) < 4 + Player:GCD() and S.FuryoftheEagle:Cooldown() < Player:GCD() then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.moknathal+=/fury_of_the_eagle,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<=2*gcd
    if AR.CDsON() and S.FuryoftheEagle:IsCastable() and Player:Buff(S.MongooseFury) and Player:BuffRemains(S.MongooseFury) <= 2 * Player:GCD() then
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.moknathal+=/aspect_of_the_eagle,if=buff.mongoose_fury.stack>4&time<15
    if AR.CDsON() and S.AspectoftheEagle:IsCastable() and Player:BuffStack(S.MongooseFury) > 4 and AC.CombatTime() < 15 then
      if AR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
    end
    -- actions.moknathal+=/aspect_of_the_eagle,if=buff.mongoose_fury.stack>1&time>15
    if AR.CDsON() and S.AspectoftheEagle:IsCastable() and Player:BuffStack(S.MongooseFury) > 1 and AC.CombatTime() > 15 then
      if AR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
    end
    -- actions.moknathal+=/aspect_of_the_eagle,if=buff.mongoose_fury.up&buff.mongoose_fury.remains>6&cooldown.mongoose_bite.charges<2
    if AR.CDsON() and S.AspectoftheEagle:IsCastable() and Player:Buff(S.MongooseFury) and Player:BuffRemains(S.MongooseFury) > 6 and S.MongooseBite:Charges() < 2 then
      if AR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
    end
    -- actions.moknathal+=/mongoose_bite,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<cooldown.aspect_of_the_eagle.remains
    if S.MongooseBite:IsCastable() and Player:Buff(S.MongooseFury) and Player:BuffRemains(S.MongooseFury) < S.AspectoftheEagle:Cooldown() then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.moknathal+=/spitting_cobra
    if AR.CDsON() and S.SpittingCobra:IsCastable() then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.moknathal+=/steel_trap
    if S.SteelTrap:IsCastable() and not S.SteelTrapTalent:IsOnCooldown() and not Target:Debuff(S.SteelTrapDebuff) and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.moknathal+=/a_murder_of_crows,if=focus>55-buff.moknathal_tactics.remains*focus.regen
    if AR.CDsON() and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 25 and Player:Focus() > 55 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.moknathal+=/caltrops,if=(!dot.caltrops.ticking)
    if S.Caltrops:IsCastable() and not S.CaltropsTalent:IsOnCooldown() and not Target:Debuff(S.CaltropsDebuff) and not S.SteelTrapTalent:IsAvailable() then
      if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.moknathal+=/explosive_trap
    if S.ExplosiveTrap:IsCastable() then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.moknathal+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.moknathal+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.moknathal+=/lacerate,if=refreshable&focus>55-buff.moknathal_tactics.remains*focus.regen
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 55 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.moknathal+=/dragonsfire_grenade
    if S.DragonsfireGrenade:IsCastable() then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.moknathal+=/mongoose_bite,if=(charges>=2&cooldown.mongoose_bite.remains<=gcd|charges=3)
    if S.MongooseBite:IsCastable() and (S.MongooseBite:Charges() >= 2 and S.MongooseBite:Cooldown() <= Player:GCD() or S.MongooseBite:Charges() == 3) then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.moknathal+=/flanking_strike
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.moknathal+=/butchery,if=focus>65-buff.moknathal_tactics.remains*focus.regen
    if S.Butchery:IsCastable() and Player:Focus() > 65 - Player:BuffRemains(S.MokNathalTactics) * Player:FocusRegen() then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.moknathal+=/raptor_strike,if=focus>75-cooldown.flanking_strike.remains*focus.regen
    if S.RaptorStrike:IsCastable() and Player:Focus() > 75 - S.FlankingStrike:Cooldown() * Player:FocusRegen() then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    return false;
  end
  -- # NoMok
  local function NoMok ()
    -- actions.nomok=spitting_cobra,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4
    if AR.CDsON() and S.SpittingCobra:IsCastable() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() >= 0 and Player:BuffStack(S.MongooseFury) < 4 then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.nomok+=/steel_trap,if=buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<1
    if S.SteelTrap:IsCastable() and not S.SteelTrapTalent:IsOnCooldown() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and Player:BuffStack(S.MongooseFury) < 1 and not Target:Debuff(S.SteelTrapDebuff) and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.nomok+=/a_murder_of_crows,if=cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4
    if AR.CDsON() and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 25 and S.MongooseBite:Charges() >= 0 and Player:BuffStack(S.MongooseFury) < 4 then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.nomok+=/snake_hunter,if=action.mongoose_bite.charges<=0&buff.mongoose_fury.remains>3*gcd&time>15
    if AR.CDsON() and S.SnakeHunter:IsCastable() and S.MongooseBite:Charges() <= 0 and Player:BuffRemains(S.MongooseFury) > 3 * Player:GCD() and AC.CombatTime() > 15 then
      if AR.Cast(S.SnakeHunter) then return ""; end
    end
    -- actions.nomok+=/caltrops,if=(buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<4&!dot.caltrops.ticking)
    if S.Caltrops:IsCastable() and (Player:BuffDuration(S.MongooseFury) >= Player:GCD() and Player:BuffStack(S.MongooseFury) < 4 and not Target:Debuff(S.CaltropsDebuff)) and not S.CaltropsTalent:IsOnCooldown() and not S.SteelTrapTalent:IsAvailable() then
      if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.nomok+=/flanking_strike,if=cooldown.mongoose_bite.charges<=1&buff.aspect_of_the_eagle.remains>=gcd
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and S.MongooseBite:Charges() <= 1 and Player:BuffRemains(S.AspectoftheEagle) >= Player:GCD() then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.nomok+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65&buff.mongoose_fury.remains>=gcd
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 and Player:BuffRemains(S.MongooseFury) >= Player:GCD() then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.nomok+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65&buff.mongoose_fury.remains>=gcd
     if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 and Player:BuffRemains(S.MongooseFury) >= Player:GCD() then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.nomok+=/lacerate,if=buff.mongoose_fury.duration>=gcd&refreshable&cooldown.mongoose_bite.charges=0&buff.mongoose_fury.stack<2|buff.mongoose_fury.down&cooldown.mongoose_bite.charges<3&refreshable
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and Target:DebuffRefreshable(S.Lacerate, 3.6) and S.MongooseBite:Charges() == 0 and Player:BuffStack(S.MongooseFury) < 2 or not Player:Buff(S.MongooseFury) and S.MongooseBite:Charges() < 3 and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Lacerate) then return ""; end
      end
    -- AOE
    -- actions.nomok+=/butchery,if=active_enemies>1&focus>65
    if S.Butchery:IsCastable() and Cache.EnemiesCount[8] > 1 and Player:Focus() > 65 then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- AOE
    -- actions.nomok+=/carve,if=active_enemies>1&talent.serpent_sting.enabled&dot.serpent_sting.refreshable
    if S.Carve:IsCastable() and Cache.EnemiesCount[5] > 1 and Player:FocusPredicted(0.2) > 35 and S.SerpentSting:IsAvailable() and Target:DebuffRefreshable(S.SerpentStingDebuff, 4.5) then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.nomok+=/dragonsfire_grenade,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges<=1&buff.mongoose_fury.stack<3|buff.mongoose_fury.down&cooldown.mongoose_bite.charges<3
    if S.DragonsfireGrenade:IsCastable() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() <= 1 and (Player:BuffStack(S.MongooseFury) < 3 or not Player:Buff(S.MongooseFury) and S.MongooseFury:Charges() < 3) then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.nomok+=/explosive_trap,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4
    if S.ExplosiveTrap:IsCastable() and Player:BuffDuration(S.MongooseFury) >= Player:GCD() and S.MongooseBite:Charges() >= 0 and Player:BuffStack(S.MongooseFury) < 4 then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.nomok+=/raptor_strike,if=talent.serpent_sting.enabled&dot.serpent_sting.refreshable&buff.mongoose_fury.stack<3&cooldown.mongoose_bite.charges<1
    if S.RaptorStrike:IsCastable() and Player:FocusPredicted(0.2) > 20 and S.SerpentSting:IsAvailable() and Target:DebuffRefreshable(S.SerpentStingDebuff, 4.5) and Player:BuffStack(S.MongooseFury) < 3 and S.MongooseBite:Charges() < 1 then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    -- actions.nomok+=/fury_of_the_eagle,if=buff.mongoose_fury.stack=6&cooldown.mongoose_bite.charges<=1
    if AR.CDsON() and S.FuryoftheEagle:IsCastable() and Player:BuffStack(S.MongooseFury) == 6 and S.MongooseBite:ChargesFractional() <= 1.8 then
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.nomok+=/mongoose_bite,if=buff.aspect_of_the_eagle.up&buff.mongoose_fury.up
    if S.MongooseBite:IsCastable() and Player:Buff(S.AspectoftheEagle) and Player:Buff(S.MongooseFury) then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.nomok+=/aspect_of_the_eagle,if=buff.mongoose_fury.up&buff.mongoose_fury.duration>6&cooldown.mongoose_bite.charges>=2
    if AR.CDsON() and S.AspectoftheEagle:IsCastable() and Player:Buff(S.MongooseFury) and Player:BuffDuration(S.MongooseFury) > 6 and S.MongooseBite:Charges() >= 2 then
      if AR.Cast(S.AspectoftheEagle, Settings.Survival.OffGCDasOffGCD.AspectoftheEagle) then return ""; end
    end
    -- actions.nomok+=/fury_of_the_eagle,if=!set_bonus.tier19_4pc=1&cooldown.mongoose_bite.charges<=1&buff.mongoose_fury.duration>6
    if AR.CDsON() and S.FuryoftheEagle:IsCastable() and not AC.Tier19_4Pc and S.MongooseBite:ChargesFractional() <= 1.8 and Player:BuffDuration(S.MongooseFury) > 6 then
      if AR.Cast(S.FuryoftheEagle) then return ""; end
    end
    -- actions.nomok+=/flanking_strike,if=cooldown.mongoose_bite.charges<=1&buff.mongoose_fury.remains>(1+action.mongoose_bite.charges*gcd)
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and S.MongooseBite:Charges() <= 1 and Player:BuffRemains(S.MongooseFury) > ( 1 + S.MongooseBite:Charges() * Player:GCD()) then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.nomok+=/mongoose_bite,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<cooldown.aspect_of_the_eagle.remains
    if S.MongooseBite:IsCastable() and Player:Buff(S.MongooseFury) and Player:BuffRemains(S.MongooseFury) < S.AspectoftheEagle:Cooldown() then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.nomok+=/flanking_strike,if=talent.animal_instincts.enabled&cooldown.mongoose_bite.charges<3
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 and S.AnimalInstincts:IsAvailable() and S.MongooseBite:Charges() < 3 then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.nomok+=/spitting_cobra
    if AR.CDsON() and S.SpittingCobra:IsCastable() then
      if AR.Cast(S.SpittingCobra) then return ""; end
    end
    -- actions.nomok+=/steel_trap
    if S.SteelTrap:IsCastable() and not S.SteelTrapTalent:IsOnCooldown() and not S.CaltropsTalent:IsAvailable() then
      if AR.Cast(S.SteelTrap) then return ""; end
    end
    -- actions.nomok+=/a_murder_of_crows
    if AR.CDsON() and S.AMurderofCrows:IsCastable() and Player:FocusPredicted(0.2) > 25 then
      if AR.Cast(S.AMurderofCrows) then return ""; end
    end
    -- actions.nomok+=/caltrops,if=(!dot.caltrops.ticking)
     if S.Caltrops:IsCastable() and not Target:Debuff(S.CaltropsDebuff) and not S.CaltropsTalent:IsOnCooldown() and not S.SteelTrapTalent:IsAvailable() then
      if AR.Cast(S.Caltrops) then return ""; end
    end
    -- actions.nomok+=/explosive_trap
    if S.ExplosiveTrap:IsCastable() then
      if AR.Cast(S.ExplosiveTrap) then return ""; end
    end
    -- actions.nomok+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65
    if S.Carve:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 then
      if AR.Cast(S.Carve) then return ""; end
    end
    -- actions.nomok+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 35 and (I.FrizzosFinger:IsEquipped(11) or I.FrizzosFinger:IsEquipped(12)) and Target:Debuff(S.Lacerate) and Target:DebuffRefreshable(S.Lacerate, 3.6) and Player:Focus() > 65 then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.nomok+=/lacerate,if=refreshable
    if S.Lacerate:IsCastable() and Player:FocusPredicted(0.2) > 30 and Target:DebuffRefreshable(S.Lacerate, 3.6) then
      if AR.Cast(S.Lacerate) then return ""; end
    end
    -- actions.nomok+=/dragonsfire_grenade
    if S.DragonsfireGrenade:IsCastable() then
      if AR.Cast(S.DragonsfireGrenade) then return ""; end
    end
    -- actions.nomok+=/throwing_axes,if=cooldown.throwing_axes.charges=2
    if S.ThrowingAxes:IsCastable() and S.ThrowingAxes:Cooldown() == 2 then
      if AR.Cast(S.ThrowingAxes) then return ""; end
    end
    -- actions.nomok+=/mongoose_bite,if=(charges>=2&cooldown.mongoose_bite.remains<=gcd|charges=3)
    if S.MongooseBite:IsCastable() and (S.MongooseBite:Charges() >= 2 and S.MongooseBite:Cooldown() <= Player:GCD() or S.MongooseBite:Charges() == 3) then
      if AR.Cast(S.MongooseBite) then return ""; end
    end
    -- actions.nomok+=/flanking_strike
    if S.FlankingStrike:IsCastable() and Player:FocusPredicted(0.2) > 45 then
      if AR.Cast(S.FlankingStrike) then return ""; end
    end
    -- actions.nomok+=/butchery
    if S.Butchery:IsCastable() and Player:FocusPredicted(0.2) > 35 then
      if AR.Cast(S.Butchery) then return ""; end
    end
    -- actions.nomok+=/throwing_axes
    if S.ThrowingAxes:IsCastable() then
      if AR.Cast(S.ThrowingAxes) then return ""; end
    end
    -- actions.nomok+=/raptor_strike,if=focus>75-cooldown.flanking_strike.remains*focus.regen
    if S.RaptorStrike:IsCastable() and Player:Focus() > 75 - S.FlankingStrike:Cooldown() * Player:FocusRegen() then
      if AR.Cast(S.RaptorStrike) then return ""; end
    end
    return false;
  end
--- APL Main
  local function APL ()
    -- Unit Update
    AC.GetEnemies(8);
    AC.GetEnemies(5);
    AR.Commons.AoEToggleEnemiesUpdate();
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
      
      -- Opener
      if AR.Commons.TargetIsValid() then
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
    if AR.Commons.TargetIsValid() then
      if AR.CDsON() then
        -- actions+=/arcane_torrent,if=focus.deficit>=30
        if S.ArcaneTorrent:IsCastable() and Player:FocusDeficit() >= 30 then
          if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
        end
        -- actions+=/berserking,if=(buff.spitting_cobra.up&buff.mongoose_fury.stack>2&buff.aspect_of_the_eagle.up)|(!talent.spitting_cobra.enabled&buff.aspect_of_the_eagle.up)
        if S.Berserking:IsCastable() and (Player:Buff(S.SpittingCobra) and Player:BuffStack(S.MongooseFury) > 2 and Player:Buff(S.AspectoftheEagle)) or (not S.SpittingCobra:IsAvailable() and Player:Buff(S.AspectoftheEagle)) then
          if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return ""; end
        end
        -- actions+=/blood_fury,if=(buff.spitting_cobra.up&buff.mongoose_fury.stack>2&buff.aspect_of_the_eagle.up)|(!talent.spitting_cobra.enabled&buff.aspect_of_the_eagle.up)
        if S.BloodFury:IsCastable() and (Player:Buff(S.SpittingCobra) and Player:BuffStack(S.MongooseFury) > 2 and Player:Buff(S.AspectoftheEagle)) or (not S.SpittingCobra:IsAvailable() and Player:Buff(S.AspectoftheEagle)) then
          if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return ""; end
        end
      end
      -- actions+=/call_action_list,name=moknathal,if=talent.way_of_the_moknathal.enabled
      if S.WayoftheMokNathal:IsAvailable() then
        ShouldReturn = MokNathal();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=nomok,if=!talent.way_of_the_moknathal.enabled
      if not S.WayoftheMokNathal:IsAvailable() then
        ShouldReturn = NoMok();
        if ShouldReturn then return ShouldReturn; end
      end
      if S.RaptorStrike:IsCastable() and Target:IsInRange(5) then
        if AR.Cast(S.PoolFocus) then return "Normal Pooling"; end
      end
      return;
    end
  end

  AR.SetAPL(255, APL);


--- Last Update: 03/04/2017

-- NOTE: For human reactivity, "cooldown.mongoose_bite.charges<=1" is replaced by ChargesFractional <= 1.8 in this action:
-- actions.nomok+=/fury_of_the_eagle,if=buff.mongoose_fury.stack=6&cooldown.mongoose_bite.charges<=1

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=flask_of_the_seventh_demon
-- actions.precombat+=/food,type=azshari_salad
-- actions.precombat+=/summon_pet
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=prolonged_power
-- actions.precombat+=/augmentation,type=defiled
-- actions.precombat+=/explosive_trap
-- actions.precombat+=/steel_trap
-- actions.precombat+=/dragonsfire_grenade
-- actions.precombat+=/harpoon

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/arcane_torrent,if=focus.deficit>=30
-- actions+=/berserking,if=(buff.spitting_cobra.up&buff.mongoose_fury.stack>2&buff.aspect_of_the_eagle.up)|(!talent.spitting_cobra.enabled&buff.aspect_of_the_eagle.up)
-- actions+=/blood_fury,if=(buff.spitting_cobra.up&buff.mongoose_fury.stack>2&buff.aspect_of_the_eagle.up)|(!talent.spitting_cobra.enabled&buff.aspect_of_the_eagle.up)
-- actions+=/potion,name=prolonged_power,if=(talent.spitting_cobra.enabled&buff.spitting_cobra.remains)|(!talent.spitting_cobra.enabled&buff.aspect_of_the_eagle.remains)
-- actions+=/call_action_list,name=moknathal,if=talent.way_of_the_moknathal.enabled
-- actions+=/call_action_list,name=nomok,if=!talent.way_of_the_moknathal.enabled

-- actions.moknathal=raptor_strike,if=buff.moknathal_tactics.stack<=1
-- actions.moknathal+=/raptor_strike,if=buff.moknathal_tactics.remains<gcd
-- actions.moknathal+=/fury_of_the_eagle,if=buff.mongoose_fury.stack>=4&buff.mongoose_fury.remains<gcd
-- actions.moknathal+=/raptor_strike,if=buff.mongoose_fury.stack>=4&buff.mongoose_fury.remains>gcd&buff.moknathal_tactics.stack>=3&buff.moknathal_tactics.remains<4&cooldown.fury_of_the_eagle.remains<buff.mongoose_fury.remains
-- actions.moknathal+=/snake_hunter,if=cooldown.mongoose_bite.charges<=0&buff.mongoose_fury.remains>3*gcd&time>15
-- actions.moknathal+=/spitting_cobra,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4&buff.moknathal_tactics.stack=3
-- actions.moknathal+=/steel_trap,if=buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<1
-- actions.moknathal+=/a_murder_of_crows,if=focus>55-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.stack<4&buff.mongoose_fury.duration>=gcd
-- actions.moknathal+=/flanking_strike,if=cooldown.mongoose_bite.charges<=1&focus>75-buff.moknathal_tactics.remains*focus.regen
-- actions.moknathal+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.remains>=gcd
-- actions.moknathal+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.remains>=gcd
-- actions.moknathal+=/lacerate,if=refreshable&((focus>55-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges=0&buff.mongoose_fury.stack<3)|(focus>65-buff.moknathal_tactics.remains*focus.regen&buff.mongoose_fury.down&cooldown.mongoose_bite.charges<3))
-- actions.moknathal+=/caltrops,if=(buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<1&!dot.caltrops.ticking)
-- actions.moknathal+=/explosive_trap,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges=0&buff.mongoose_fury.stack<1
-- actions.moknathal+=/butchery,if=active_enemies>1&focus>65-buff.moknathal_tactics.remains*focus.regen&(buff.mongoose_fury.down|buff.mongoose_fury.remains>gcd*cooldown.mongoose_bite.charges)
-- actions.moknathal+=/carve,if=active_enemies>1&focus>65-buff.moknathal_tactics.remains*focus.regen&(buff.mongoose_fury.down&focus>65-buff.moknathal_tactics.remains*focus.regen|buff.mongoose_fury.remains>gcd*cooldown.mongoose_bite.charges&focus>70-buff.moknathal_tactics.remains*focus.regen)
-- actions.moknathal+=/raptor_strike,if=buff.moknathal_tactics.stack=2
-- actions.moknathal+=/dragonsfire_grenade,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<1
-- actions.moknathal+=/raptor_strike,if=buff.moknathal_tactics.remains<4&buff.mongoose_fury.stack=6&buff.mongoose_fury.remains>cooldown.fury_of_the_eagle.remains&cooldown.fury_of_the_eagle.remains<=5
-- actions.moknathal+=/fury_of_the_eagle,if=buff.moknathal_tactics.remains>4&buff.mongoose_fury.stack=6&cooldown.mongoose_bite.charges<=1
-- actions.moknathal+=/mongoose_bite,if=buff.aspect_of_the_eagle.up&buff.mongoose_fury.up&buff.moknathal_tactics.stack>=4
-- actions.moknathal+=/raptor_strike,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<=3*gcd&buff.moknathal_tactics.remains<4+gcd&cooldown.fury_of_the_eagle.remains<gcd
-- actions.moknathal+=/fury_of_the_eagle,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<=2*gcd
-- actions.moknathal+=/aspect_of_the_eagle,if=buff.mongoose_fury.stack>4&time<15
-- actions.moknathal+=/aspect_of_the_eagle,if=buff.mongoose_fury.stack>1&time>15
-- actions.moknathal+=/aspect_of_the_eagle,if=buff.mongoose_fury.up&buff.mongoose_fury.remains>6&cooldown.mongoose_bite.charges<2
-- actions.moknathal+=/mongoose_bite,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<cooldown.aspect_of_the_eagle.remains
-- actions.moknathal+=/spitting_cobra
-- actions.moknathal+=/steel_trap
-- actions.moknathal+=/a_murder_of_crows,if=focus>55-buff.moknathal_tactics.remains*focus.regen
-- actions.moknathal+=/caltrops,if=(!dot.caltrops.ticking)
-- actions.moknathal+=/explosive_trap
-- actions.moknathal+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen
-- actions.moknathal+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65-buff.moknathal_tactics.remains*focus.regen
-- actions.moknathal+=/lacerate,if=refreshable&focus>55-buff.moknathal_tactics.remains*focus.regen
-- actions.moknathal+=/dragonsfire_grenade
-- actions.moknathal+=/mongoose_bite,if=(charges>=2&cooldown.mongoose_bite.remains<=gcd|charges=3)
-- actions.moknathal+=/flanking_strike
-- actions.moknathal+=/butchery,if=focus>65-buff.moknathal_tactics.remains*focus.regen
-- actions.moknathal+=/raptor_strike,if=focus>75-cooldown.flanking_strike.remains*focus.regen

-- actions.nomok=spitting_cobra,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4
-- actions.nomok+=/steel_trap,if=buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<1
-- actions.nomok+=/a_murder_of_crows,if=cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4
-- actions.nomok+=/snake_hunter,if=action.mongoose_bite.charges<=0&buff.mongoose_fury.remains>3*gcd&time>15
-- actions.nomok+=/caltrops,if=(buff.mongoose_fury.duration>=gcd&buff.mongoose_fury.stack<4&!dot.caltrops.ticking)
-- actions.nomok+=/flanking_strike,if=cooldown.mongoose_bite.charges<=1&buff.aspect_of_the_eagle.remains>=gcd
-- actions.nomok+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65&buff.mongoose_fury.remains>=gcd
-- actions.nomok+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65&buff.mongoose_fury.remains>=gcd
-- actions.nomok+=/lacerate,if=buff.mongoose_fury.duration>=gcd&refreshable&cooldown.mongoose_bite.charges=0&buff.mongoose_fury.stack<2|buff.mongoose_fury.down&cooldown.mongoose_bite.charges<3&refreshable
-- actions.nomok+=/carve,if=active_enemies>1&talent.serpent_sting.enabled&dot.serpent_sting.refreshable
-- actions.nomok+=/butchery,if=active_enemies>1&focus>65
-- actions.nomok+=/dragonsfire_grenade,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges<=1&buff.mongoose_fury.stack<3|buff.mongoose_fury.down&cooldown.mongoose_bite.charges<3
-- actions.nomok+=/explosive_trap,if=buff.mongoose_fury.duration>=gcd&cooldown.mongoose_bite.charges>=0&buff.mongoose_fury.stack<4
-- actions.nomok+=/raptor_strike,if=talent.serpent_sting.enabled&dot.serpent_sting.refreshable&buff.mongoose_fury.stack<3&cooldown.mongoose_bite.charges<1
-- actions.nomok+=/fury_of_the_eagle,if=buff.mongoose_fury.stack=6&cooldown.mongoose_bite.charges<=1
-- actions.nomok+=/mongoose_bite,if=buff.aspect_of_the_eagle.up&buff.mongoose_fury.up
-- actions.nomok+=/aspect_of_the_eagle,if=buff.mongoose_fury.up&buff.mongoose_fury.duration>6&cooldown.mongoose_bite.charges>=2
-- actions.nomok+=/fury_of_the_eagle,if=!set_bonus.tier19_4pc=1&cooldown.mongoose_bite.charges<=1&buff.mongoose_fury.duration>6
-- actions.nomok+=/flanking_strike,if=cooldown.mongoose_bite.charges<=1&buff.mongoose_fury.remains>(1+action.mongoose_bite.charges*gcd)
-- actions.nomok+=/mongoose_bite,if=buff.mongoose_fury.up&buff.mongoose_fury.remains<cooldown.aspect_of_the_eagle.remains
-- actions.nomok+=/flanking_strike,if=talent.animal_instincts.enabled&cooldown.mongoose_bite.charges<3
-- actions.nomok+=/spitting_cobra
-- actions.nomok+=/steel_trap
-- actions.nomok+=/a_murder_of_crows
-- actions.nomok+=/caltrops,if=(!dot.caltrops.ticking)
-- actions.nomok+=/explosive_trap
-- actions.nomok+=/carve,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65
-- actions.nomok+=/butchery,if=equipped.frizzos_fingertrap&dot.lacerate.ticking&dot.lacerate.refreshable&focus>65
-- actions.nomok+=/lacerate,if=refreshable
-- actions.nomok+=/dragonsfire_grenade
-- actions.nomok+=/throwing_axes,if=cooldown.throwing_axes.charges=2
-- actions.nomok+=/mongoose_bite,if=(charges>=2&cooldown.mongoose_bite.remains<=gcd|charges=3)
-- actions.nomok+=/flanking_strike
-- actions.nomok+=/butchery
-- actions.nomok+=/throwing_axes
-- actions.nomok+=/raptor_strike,if=focus>75-cooldown.flanking_strike.remains*focus.regen

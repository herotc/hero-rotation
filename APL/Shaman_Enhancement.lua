-- Pull Addon Vars
local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua
local pairs = pairs;

--- APL Local Vars
-- Spells
  if not Spell.Shaman then Spell.Shaman = {}; end
  Spell.Shaman.Enhancement = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    CrashLightning                = Spell(187874),
    CrashLightningBuff            = Spell(187878),
    FeralSpirit                   = Spell(51533),
    FeralSpiritPassive            = Spell(231723),
    Flametongue                   = Spell(193796),
    FlametongueBuff               = Spell(194084),
    Frostbrand                    = Spell(196834),
    FrostbrandBuff                = Spell(196834),
    Bloodlust                     = Spell(2825),
    Heroism                       = Spell(32182),
    LavaLash                      = Spell(60103),
    LightningBolt                 = Spell(187837),
    MaelstromWeapon               = Spell(187880),
    Rockbiter                     = Spell(193786),
    Stormstrike                   = Spell(17364),
    Stormbringer                  = Spell(201845),
    StormbringerBuff              = Spell(201846),
    Stormlash                     = Spell(195255),
    StormlashBuff                 = Spell(207835),
    Windfurry                     = Spell(33757),
    -- Talents
    AncestralSwiftness            = Spell(192087),
    Ascendance                    = Spell(114049),
    AscendanceBuff                = Spell(114051),
    Boulderfist                   = Spell(201897),
    BoulderfistBuff               = Spell(218825),
    CrashingStorm                 = Spell(192246),
    EarthgrabTotem                = Spell(51485),
    EarthenSpike                  = Spell(188089),
    EmpowerStormlash              = Spell(210731),
    FeralLunge                    = Spell(196884),
    FuryOfAir                     = Spell(197211),
    FuryOfAirBuff                 = Spell(197385),
    Hailstotrm                    = Spell(210853),
    HotHand                       = Spell(201900),
    HotHandBuff                   = Spell(215785),
    Landslide                     = Spell(197992),
    LandslideBuff                 = Spell(202004),
    LightningShield               = Spell(192106),
    LightningShieldBuff           = Spell(192109),
    LighningSurgeTotem            = Spell(192058),
    Overchage                     = Spell(210727),
    Rainfall                      = Spell(215864),
    Sundering                     = Spell(197214),
    Tempest                       = Spell(192234),
    VoodooTotem                   = Spell(196932),
    WindRushTotem                 = Spell(192077),
    Windsong                      = Spell(201898),
    WindsongBuff                  = Spell(201898),
    -- Artifact
    AlphaWolf                     = Spell(198434),
    AlphaWolfBuff                 = Spell(198434),
    DoomWinds                     = Spell(204945),
    DoomWindsBuff                 = Spell(204945),
    GatheringStorms               = Spell(198299),
    GatheringStormsBuff           = Spell(198299),
    WindStrikes                   = Spell(198292),
    WindStrikesBuff               = Spell(198292),
    -- Defensive
    AstralShift                   = Spell(108271),
    HealingSurge                  = Spell(),
    -- Utility
    CleanseSpirit                 = Spell(),
    GhostWolf                     = Spell(),
    Hex                           = Spell(),
    Purge                         = Spell(),
    Reincarnation                 = Spell(),
    SpiritWalking                 = Spell(),
    WaterWalking                  = Spell(),
    WindShear                     = Spell(),
    -- Legendaries
    EmalonChargedCore             = Spell(),
    StormTempest                  = Spell(),
    -- Misc

    -- Macros
    Macros = {}
    };

-- APL Main
local function APL ()
  -- Unit Update
  ER.GetEnemies(5); -- Melee
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      return;
    end
  --- In Combat
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then

    end
end

ER.SetAPL(263, APL);
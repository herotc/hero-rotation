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
    FeralSpirit                   = Spell(51533),
    FeralSpiritPassive            = Spell(231723),
    Flametongue                   = Spell(193796),
    Frostbrand                    = Spell(196834),
    Bloodlust                     = Spell(2825),
    Heroism                       = Spell(32182),
    LavaLash                      = Spell(60103),
    LightningBolt                 = Spell(187837),
    MaelstromWeapon               = Spell(187880),
    Rockbiter                     = Spell(193786),
    Stormstrike                   = Spell(17364),
    Stormbringer                  = Spell(201845),
    Stormlash                     = Spell(195255),
    Windfurry                     = Spell(33757),
    -- Talents
    Alacrity                      = Spell(193539),
    AlacrityBuff                  = Spell(193538),
    Anticipation                  = Spell(114015),
    DeathFromAbove                = Spell(152150),
    DeeperStratagem               = Spell(193531),
    EnvelopingShadows             = Spell(206237),
    Gloomblade                    = Spell(200758),
    MarkedforDeath                = Spell(137619),
    MasterofShadows               = Spell(196976),
    MasterOfSubtlety              = Spell(31223),
    MasterOfSubtletyBuff          = Spell(31665),
    Premeditation                 = Spell(196979),
    ShadowFocus                   = Spell(108209),
    Subterfuge                    = Spell(108208),
    Vigor                         = Spell(14983),
    -- Artifact
    FinalityEviscerate            = Spell(197496),
    FinalityNightblade            = Spell(195452),
    FlickeringShadows             = Spell(197256),
    GoremawsBite                  = Spell(209782),
    LegionBlade                   = Spell(214930),
    ShadowFangs                   = Spell(221856),
    -- Defensive
    CrimsonVial                   = Spell(185311),
    Feint                         = Spell(1966),
    -- Utility
    Blind                         = Spell(2094),
    CheapShot                     = Spell(1833),
    Kick                          = Spell(1766),
    KidneyShot                    = Spell(408),
    Sprint                        = Spell(2983),
    -- Legendaries
    DreadlordsDeceit              = Spell(228224),
    -- Misc
    DeathlyShadows                = Spell(188700),
    PoolEnergy                    = Spell(161576),
    -- Macros
    Macros = {
      ShDSS                       = Spell(9999261001),
      ShDShStorm                  = Spell(9999261002),
      ShDSoDSS                    = Spell(9999261003),
      ShDSoDShStorm               = Spell(9999261004),
      VanSS                       = Spell(9999261005),
      VanShStorm                  = Spell(9999261006),
      VanSoDSS                    = Spell(9999261007),
      VanSoDShStorm               = Spell(9999261008),
      SMSS                        = Spell(9999261009),
      SMSoDSS                     = Spell(9999261010)
    }
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
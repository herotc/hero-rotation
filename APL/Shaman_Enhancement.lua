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
    Windstrike                    = Spell(),
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
    Hailstorm                     = Spell(210853),
    HotHand                       = Spell(201900),
    HotHandBuff                   = Spell(215785),
    Landslide                     = Spell(197992),
    LandslideBuff                 = Spell(202004),
    LightningShield               = Spell(192106),
    LightningShieldBuff           = Spell(192109),
    LighningSurgeTotem            = Spell(192058),
    Overcharge                    = Spell(210727),
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
    AstralShift             = Spell(108271),
    HealingSurge            = Spell(188070),
    -- Utility
    CleanseSpirit           = Spell(51886),
    GhostWolf               = Spell(2645),
    Hex                     = Spell(51514),
    Purge                   = Spell(370),
    Reincarnation           = Spell(20608),
    SpiritWalk              = Spell(58875),
    WaterWalking            = Spell(546),
    WindShear               = Spell(57994),
    -- Legendaries
    EmalonChargedCore       = Spell(208742),
    StormTempest            = Spell(214265),
    -- Misc

    -- Macros
    Macros = {}
    };
    local S = Spell.Shaman.Enhancement;

    --Items 
    if not Item.Shaman then Item.Shaman = {}; end
    Item.Shaman.Enhancement = {
        --Legendaries
        EmalonChargedCore = Item(),
        StormTempests = Item()
    };
    local I = Item.Shaman.Enhancement;

--Cooldowns

--AOE

-- APL Main
local function APL ()
  -- Unit Update
  ER.GetEnemies(8); -- Melee
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
        if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
            if S.Boulderfist:IsCastable()  then
                if ER.Cast(S.Boulderfist) then return "Cast Boulderfist"; end
            elseif S.Rockbiter:IsCastable()  then 
                if ER.Cast(S.Rockbiter) then return "Cast Rockbiter"; end
            elseif S.Flametongue:IsCastable() then
                if ER.Cast(S.Flametongue) then return "Cast Flametongue"; end
            end
        end
        return;
    end

  --- Interrupts 
    if Settings.General.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(30) then
        if S.WindShear:IsCastable() then 
            if ER.Cast(S.WindShear) then return "Cast"; end
        end
    end

  --- In Combat
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
                --actions+=/boulderfist,if=buff.boulderfist.remains<gcd|(maelstrom<=50&active_enemies>=3)
                --actions+=/boulderfist,if=buff.boulderfist.remains<gcd|(charges_fractional>1.75&maelstrom<=100&active_enemies<=2)
            if S.Boulderfist:IsCastable() and Player:BuffRemains(S.BoulderfistBuff) < Player:GCD() then
                if ER.Cast(S.Boulderfist) then return "Cast Boulderfist"; end
            end
                --actions+=/rockbiter,if=talent.landslide.enabled&buff.landslide.remains<gcd
            if S.Rockbiter:IsCastable and Player:IsKnown(S.Landslide) and Player:BuffRemains(S.LandslideBuff) < Player:GCD() then 
                if ER.Cast(S.Rockbiter) then return "Cast Rockbiter"; end
            end
                -- actions+=/fury_of_air,if=!ticking&maelstrom>22
            if not Player:Buff(S.FuryOfAirBuff) and S.FuryOfAir:IsCastable() and Player:Maelstrom() > 15 then 
                if ER.Cast(S.FuryOfAir) then return "Cast FuryOfAir"; end
            end
                -- actions+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<gcd
            if Player:IsKnown(Hailstorm) and Player:BuffRemains(S.FrostbrandBuff) < Player:GCD() then
                if ER.Cast(S.Frostbrand) then return "Cast Frostbrand"; end
            end
                -- actions+=/flametongue,if=buff.flametongue.remains<gcd|(cooldown.doom_winds.remains<6&buff.flametongue.remains<4)
            if S.Flametongue:IsCastable() and Player:BuffRemains(S.FlametongueBuff) < Player:GCD() then
                if ER.Cast(S.Flametongue) then return "Cast Flametongue"; end
            end
                -- actions+=/doom_winds
            if S.DoomWinds:IsCastable() then 
                if ER.Cast(S.DoomWinds) then return "Cast DoomWinds";end
            end
                -- actions+=/crash_lightning,if=talent.crashing_storm.enabled&active_enemies>=3&(!talent.hailstorm.enabled|buff.frostbrand.remains>gcd)
            if ER.AoEON() and S.CrashLightning:IsCastable() and Player:IsKnown(S.CrashingStorm) and ER.Cache.EnnemiesCount[8] >= 3 
                and (not Player:IsKnown(S.Hailstorm) or Player:BuffRemains(FrostbrandBuff) > Player:GCD()) then
                if ER.Cast(S.CrashLightning) then return "Cast CrashLightning"; end
            end
                -- actions+=/earthen_spike
            if S.EarthenSpike:IsCastable() then 
                if ER.Cast(S.EarthenSpike) then return "Cast EarthenSpike"; end
            end
                -- actions+=/lightning_bolt,if=(talent.overcharge.enabled&maelstrom>=40&!talent.fury_of_air.enabled)|(talent.overcharge.enabled&talent.fury_of_air.enabled&maelstrom>46)
            if S.LightningBolt:IsCastable() and ((Player:IsKnown(S.Overcharge) and Player:Maelstrom() >= 40 and not S.FuryOfAir:IsCastable()) 
                or (Player:IsKnown(S.Overcharge) and S.FuryOfAir:IsCastable() and Player:Maelstrom() >= 46 )) then
                if ER.Cast(LightningBolt) then return "Cast LightningBolt"; end
            end
            -- actions+=/crash_lightning,if=buff.crash_lightning.remains<gcd&active_enemies>=2
            if  ER.AoEON() and S.CrashLightning:IsCastable() and Player:BuffRemains(CrashLightningBuff) < Player:GCD() and ER.Cache.EnnemiesCount[8] >= 2 then
                if ER.Cast(S.CrashLightning) then return "Cast CrashLightning"; end
            end
                -- actions+=/windsong
            if S.Windsong:IsCastable() then
                if ER.Cast(S.Windsong) then return "Cast Windsong"; end
            end
                -- actions+=/ascendance,if=buff.stormbringer.react
            if S.Ascendance:IsCastable() and Player:Buff(S.StormbringerBuff) then
                if  ER.Cast(S.Ascendance) then return "Cast Ascendance"; end
            end
                -- actions+=/windstrike,if=buff.stormbringer.react&((talent.fury_of_air.enabled&maelstrom>=26)|(!talent.fury_of_air.enabled))
            if S.WindStrike:IsCastable() and Player:Buff(S.StormbringerBuff) and ((S.FuryOfAir:IsCastable() and Player:Maelstrom() >= 26)
                or (not Player:IsKnown(S.FuryOfAir))) then
                if ER.Cast(S.Windstrike) then return "Cast Windstrike"; end
            end
                -- actions+=/stormstrike,if=buff.stormbringer.react&((talent.fury_of_air.enabled&maelstrom>=26)|(!talent.fury_of_air.enabled))
            if S.Stormstrike:IsCastable() and Player:Buff(S.StormbringerBuff) and ((S.FuryOfAir:IsCastable() and Player:Maelstrom() >= 26)
                or (not Player:IsKnown(S.FuryOfAir))) then
                if ER.Cast(S.Stormstrike) then return "Cast Stormstrike"; end
            end
                -- actions+=/lava_lash,if=talent.hot_hand.enabled&buff.hot_hand.react
            if S.LavaLash:IsCastable() and Player:IsKnown(S.HotHand) and Player:Buff(S.HotHandBuff) then
                if ER.Cast(S.LavaLash) then return "Cast LavaLash"; end
            end
                -- actions+=/crash_lightning,if=active_enemies>=4
            if ER.AoEON() and S.CrashLightning:IsCastable() and ER.Cache.EnnemiesCount[8] >= 4 then
                if ER.Cast(S.CrashLightning) then return "Cast CrashLightning";end
            end
                -- actions+=/windstrike
            if S.Windstrike:IsCastable() then
                if ER.Cast(S.Windstrike) then return "Cast WindStrike"; end
            end
                -- actions+=/stormstrike,if=talent.overcharge.enabled&cooldown.lightning_bolt.remains<gcd&maelstrom>80
            if S.Stormstrike:IsCastable() and Player:IsKnown(S.Overcharge) and  S.LightningBolt:Cooldown() > Player:GCD() and Player:Maelstrom() > 80 then
                if ER.Cast(S.Stormstrike) then return "Cast Stormstrike"; end
            end
                -- actions+=/stormstrike,if=talent.fury_of_air.enabled&maelstrom>46&(cooldown.lightning_bolt.remains>gcd|!talent.overcharge.enabled)
            if S.Stormstrike:IsCastable() and S.FuryOfAir:IsCastable() and Player:Maelstrom() > 46 and (S.LightningBolt:Cooldown()>Player:GCD() or not Player:IsKnown(S.Overcharge)) then
                if ER.Cast(S.Stormstrike) then return "Cast Stormstrike"; end
            end
                -- actions+=/stormstrike,if=!talent.overcharge.enabled&!talent.fury_of_air.enabled
            if S.Stormstrike:IsCastable() and not (S.FuryOfAir:IsCastable() and Player:IsKnown(S.Overcharge)) then
                if ER.Cast(S.Stormstrike) then return "Cast Stormstrike"; end
            end
                -- actions+=/crash_lightning,if=((active_enemies>1|talent.crashing_storm.enabled|talent.boulderfist.enabled)&!set_bonus.tier19_4pc)|feral_spirit.remains>5
            if S.CrashLightning:IsCastable() and (((ER.Cache.EnnemiesCount[8]>1 or Player.IsKnown(S.CrashingStorm) or Player.IsKnown(S.Boulderfist))and not ER.Tier19_4pc) or S.FeralSpirit:BuffRemains()>5) then
                if ER.Cast(S.CrashLightning) then return "Cast CrashLightning"; end 
            end
                -- actions+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8
            if S.Frostbrand:IsCastable() and Player:IsKnown(S.Hailstorm) and Player:BuffRemains(S.FrostbrandBuff) < 4.8 then
                if ER.Cast(S.Frostbrand) then return "Cast Frostbrand"; end
            end
            -- actions+=/lava_lash,if=talent.fury_of_air.enabled&talent.overcharge.enabled&(set_bonus.tier19_4pc&maelstrom>=80)
            if S.LavaLash:IsCastable() and S.FuryOfAir:IsCastable() and Player:IsKnown(S.Overcharge) and ER.Tier19_4pc and Player:Maelstrom() >= 80 then
                if ER.Cast(S.LavaLash) then return "Cast LavaLash"; end
            end
                -- actions+=/lava_lash,if=talent.fury_of_air.enabled&!talent.overcharge.enabled&(set_bonus.tier19_4pc&maelstrom>=53)
             if S.LavaLash:IsCastable() and S.FuryOfAir:IsCastable() and not Player:IsKnown(S.Overcharge) and ER.Tier19_4pc and Player:Maelstrom() >= 53 then
                if ER.Cast(S.LavaLash) then return "Cast LavaLash"; end
            end
                -- actions+=/lava_lash,if=(!set_bonus.tier19_4pc&maelstrom>=120)|(!talent.fury_of_air.enabled&set_bonus.tier19_4pc&maelstrom>=40)
             if S.LavaLash:IsCastable() and ((not ER.Tier19_4pc and Player:Maelstrom()>=120) or (not S.FuryOfAir:IsCastable() and ER.Tier19_4pc and Player:Maelstrom()>=40)) then
                if ER.Cast(S.LavaLash) then return "Cast LavaLash"; end
            end
                -- actions+=/flametongue,if=buff.flametongue.remains<4.8
            if S.Flametongue:IsCastable() and Player:BuffRemains(S.FlametongueBuff)<4.8 then
                if ER.Cast(S.Flametongue) then return "Cast Flametongue"; end
            end
                -- actions+=/sundering
            if S.Sundering:IsCastable() then
                if ER.Cast(S.Sundering) then return "Cast Sundering"; end
            end
                -- actions+=/rockbiter
            if S.Rockbiter:IsCastable() then
                if ER.Cast(S.Rockbiter) then return "Cast Rockbiter"; end
            end
                -- actions+=/flametongue
            if S.Flametongue:IsCastable() then
                if ER.Cast(S.Flametongue) then return "Cast Flametongue"; end
            end
                -- actions+=/boulderfist
            if S.Boulderfist:IsCastable() then
                if ER.Cast(S.Boulderfist) then return "Cast Boulderfist"; end
            end



   -- actions+=/feral_spirit,if=!artifact.alpha_wolf.rank|(maelstrom>=20&cooldown.crash_lightning.remains<=gcd)
   -- actions+=/crash_lightning,if=artifact.alpha_wolf.rank&prev_gcd.1.feral_spirit
   --actions+=/berserking,if=buff.ascendance.up|!talent.ascendance.enabled|level<100
--actions+=/blood_fury
--actions+=/potion,name=prolonged_power,if=feral_spirit.remains>5|target.time_to_die<=60
--actions+=/boulderfist,if=buff.boulderfist.remains<gcd|(maelstrom<=50&active_enemies>=3)
--actions+=/boulderfist,if=buff.boulderfist.remains<gcd|(charges_fractional>1.75&maelstrom<=100&active_enemies<=2)
--actions+=/rockbiter,if=talent.landslide.enabled&buff.landslide.remains<gcd
-- actions+=/fury_of_air,if=!ticking&maelstrom>22
-- actions+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<gcd
-- actions+=/flametongue,if=buff.flametongue.remains<gcd|(cooldown.doom_winds.remains<6&buff.flametongue.remains<4)
-- actions+=/doom_winds
-- actions+=/crash_lightning,if=talent.crashing_storm.enabled&active_enemies>=3&(!talent.hailstorm.enabled|buff.frostbrand.remains>gcd)
-- actions+=/earthen_spike
-- actions+=/lightning_bolt,if=(talent.overcharge.enabled&maelstrom>=40&!talent.fury_of_air.enabled)|(talent.overcharge.enabled&talent.fury_of_air.enabled&maelstrom>46)
-- actions+=/crash_lightning,if=buff.crash_lightning.remains<gcd&active_enemies>=2
-- actions+=/windsong
-- actions+=/ascendance,if=buff.stormbringer.react
-- actions+=/windstrike,if=buff.stormbringer.react&((talent.fury_of_air.enabled&maelstrom>=26)|(!talent.fury_of_air.enabled))
-- actions+=/stormstrike,if=buff.stormbringer.react&((talent.fury_of_air.enabled&maelstrom>=26)|(!talent.fury_of_air.enabled))
-- actions+=/lava_lash,if=talent.hot_hand.enabled&buff.hot_hand.react
-- actions+=/crash_lightning,if=active_enemies>=4
-- actions+=/windstrike
-- actions+=/stormstrike,if=talent.overcharge.enabled&cooldown.lightning_bolt.remains<gcd&maelstrom>80
-- actions+=/stormstrike,if=talent.fury_of_air.enabled&maelstrom>46&(cooldown.lightning_bolt.remains>gcd|!talent.overcharge.enabled)
-- actions+=/stormstrike,if=!talent.overcharge.enabled&!talent.fury_of_air.enabled
-- actions+=/crash_lightning,if=((active_enemies>1|talent.crashing_storm.enabled|talent.boulderfist.enabled)&!set_bonus.tier19_4pc)|feral_spirit.remains>5
-- actions+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8
-- actions+=/lava_lash,if=talent.fury_of_air.enabled&talent.overcharge.enabled&(set_bonus.tier19_4pc&maelstrom>=80)
-- actions+=/lava_lash,if=talent.fury_of_air.enabled&!talent.overcharge.enabled&(set_bonus.tier19_4pc&maelstrom>=53)
-- actions+=/lava_lash,if=(!set_bonus.tier19_4pc&maelstrom>=120)|(!talent.fury_of_air.enabled&set_bonus.tier19_4pc&maelstrom>=40)
-- actions+=/flametongue,if=buff.flametongue.remains<4.8
-- actions+=/sundering
-- actions+=/rockbiter
-- actions+=/flametongue
-- actions+=/boulderfist



end

ER.SetAPL(263, APL);
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
    WindStrike                    = Spell(115356),
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
    AstralShift                   = Spell(108271),
    HealingSurge                  = Spell(188070),
    -- Utility
    CleanseSpirit                 = Spell(51886),
    GhostWolf                     = Spell(2645),
    Hex                           = Spell(51514),
    Purge                         = Spell(370),
    Reincarnation                 = Spell(20608),
    SpiritWalk                    = Spell(58875),
    WaterWalking                  = Spell(546),
    WindShear                     = Spell(57994),
    -- Legendaries
    SmolderingHeart               = Spell(248029),
	AkainusAbsoluteJustice        = Spell(213359),
    -- Misc

    -- Macros
    Macros = {}
    };
    local S = Spell.Shaman.Enhancement;

    --Items
    if not Item.Shaman then Item.Shaman = {}; end
    Item.Shaman.Enhancement = {
        --Legendaries
		SmolderingHeart           = Item(151819),
		AkainusAbsoluteJustice    = Item(137084)
    };
    local I = Item.Shaman.Enhancement;

-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Enhancement = AR.GUISettings.APL.Shaman.Enhancement
  };

--Cooldowns
-- FeralSpirit expire


--AOE

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(20); -- Boulderfist,Flametongue
  AC.GetEnemies(8); -- CrashLightning
  AC.GetEnemies(5); -- Melee

  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
        if Target:Exists() and Player:CanAttack(Target) and Target:IsInRange(20) and not Target:IsDeadOrGhost() then
            if S.Boulderfist:IsCastable()  then
                if AR.Cast(S.Boulderfist) then return "Cast Boulderfist"; end
            elseif S.Rockbiter:IsCastable()  then
                if AR.Cast(S.Rockbiter) then return "Cast Rockbiter"; end
            elseif S.Flametongue:IsCastable() then
                if AR.Cast(S.Flametongue) then return "Cast Flametongue"; end
            end
        end
        return;
    end

  --- Interrupts
    if Settings.General.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(30) then
        if S.WindShear:IsCastable() then
            if AR.Cast(S.WindShear, Settings.Enhancement.OffGCDasOffGCD.WindShear) then return "Cast"; end
        end
    end

  --- Legendaries

    --- In Combat
    if Target:Exists() and Player:CanAttack(Target) and Target:IsInRange(5) and not Target:IsDeadOrGhost() then

        -- actions+=/windstrike,if=(variable.heartEquipped|set_bonus.tier19_2pc)&(!talent.earthen_spike.enabled|(cooldown.earthen_spike.remains>1&cooldown.doom_winds.remains>1)|debuff.earthen_spike.up)
	    if (I.EmalonChargedCore:IsEquipped() or AC.Tier19_2Pc) and (not S.EarthenSpike:IsAvailable() or (S.EarthenSpike:Cooldown() < 1 and S.DoomWinds:Cooldown() > 1) and Target:Debuff(S.EarthenSpike))
            return "Cast WindStrike"
        end

        -- actions.buffs=rockbiter,if=talent.landslide.enabled&!buff.landslide.up
		if S.Landslide:IsAvailable() and not Player:Buff(S.LandslideBuff)) then
			return "Cast Rockbiter"
		end

		-- actions.buffs+=/fury_of_air,if=buff.ascendance.up|(feral_spirit.remains>5)|level<100
		if Player:Buff(S.AscendanceBuff) and S.FeralSpirit:TimeSinceLastCast() < 10 then
			return "Cast FuryOfAir"
		end

		-- actions.buffs+=/crash_lightning,if=artifact.alpha_wolf.rank&prev_gcd.1.feral_spirit
        if S.AlphaWolf:ArtifactEnabled() and S.FeralSpirit:TimeSinceLastCast() < 14 then
            if AR.Cast(S.CrashLightning) then return "Cast CrashLightning"; end
        end

		-- actions.buffs+=/flametongue,if=!buff.flametongue.up
		if not Player:Buff(S.FlametongueBuff) then
			return "Cast Flametongue"
		end

		-- actions.buffs+=/frostbrand,if=talent.hailstorm.enabled&!buff.frostbrand.up&variable.furyCheck45
		if S.Hailstorm:IsAvailable() and not Player:Buff(S.FrostbrandBuff) and (S.FuryOfAir:IsAvailable() and Player:Maelstrom()>=45)
			return "Cast Frostbrand"
		end

		-- actions.buffs+=/flametongue,if=buff.flametongue.remains<6+gcd&cooldown.doom_winds.remains<gcd*2
		if Player:BuffRemains(S.FlametongueBuff) < 6 + Player:GCD() and S.DoomWinds:Cooldown() < Player:GCD() * 2 then
			return "Cast Flametongue"
		end

		-- actions.buffs+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<6+gcd&cooldown.doom_winds.remains<gcd*2
		if S.Hailstorm:IsAvailable() and Player:BuffRemains(S.FrostbrandBuff) < 6 + Player:GCD() and S.DoomWinds:Cooldown() < Player:GCD() * 2
			return "Cast Hailstorm"
		end

		-- Racials are supposed to go here.

		-- actions.CDs+=/feral_spirit
		if S.FeralSpirit:IsAvailable() then
			return "Cast FeralSpirit"
		end

		-- actions.CDs+=/doom_winds,if=debuff.earthen_spike.up&talent.earthen_spike.enabled|!talent.earthen_spike.enabled
		if Target:Debuff(S.EarthenSpike) and S.EarthenSpike:IsAvalible() or not S.EarthenSpike:IsAvalible() then
			return "Cast DoomWinds"
		end

		-- actions.CDs+=/ascendance,if=buff.doom_winds.up
		if Player:Buff(S.DoomWindsBuff) then
			return "Cast Ascendance"
		end

		-- actions.core=earthen_spike,if=variable.furyCheck25
		if (S.FuryOfAir:IsAvailable() and Player:Maelstrom()>=25) then
			return "Cast EarthenSpike"
		end

		-- actions.core+=/crash_lightning,if=!buff.crash_lightning.up&active_enemies>=2
		if Player:Buff(S.CrashLightningBuff) and (AR.AoEON() and Cache.EnemiesCount[8] >= 2) then
			return "Cast CrashLightning"
		end

		-- actions.core+=/windsong
		if S.Windsong:IsAvailable() then
			return "Cast Windsong"
		end

		-- actions.core+=/crash_lightning,if=active_enemies>=8|(active_enemies>=6&talent.crashing_storm.enabled)
		if (AR.AoEON() and Cache.EnemiesCount[8] >= 2) or (AR.AoEON() and Cache.EnemiesCount[8] >= 6 and S.CrashingStorm:IsAvalible()) then
			return "Cast CrashLightning"
		end

		-- actions.core+=/windsong
		if S.WindStrike:IsAvailable() then
			return "Cast WindStrike"
		end

		-- actions.core+=/stormstrike,if=buff.stormbringer.up&variable.furyCheck25
		if Player:Buff(S.StormbringerBuff) and (S.FuryOfAir:IsAvailable() and Player:Maelstrom()>=25) then
			return "Cast Stormstrike"
		end

		-- actions.core+=/crash_lightning,if=active_enemies>=4|(active_enemies>=2&talent.crashing_storm.enabled)
		if (AR.AoEON() and Cache.EnemiesCount[8] >= 4) or (AR.AoEON() and Cache.EnemiesCount[8] >= 2) and S.CrashingStorm:IsAvalible() then
			return "Cast CrashLightning"
		end

		-- actions.core+=/lightning_bolt,if=talent.overcharge.enabled&variable.furyCheck45&maelstrom>=40
		if S.Overcharge:IsAvalible() and (S.FuryOfAir:IsAvailable() and Player:Maelstrom()>=45) then
			return "Cast LightningBolt"
		end

		-- actions.core+=/stormstrike,if=(!talent.overcharge.enabled&variable.furyCheck45)|(talent.overcharge.enabled&variable.furyCheck80)
		if (S.Overcharge:IsAvailable() and (S.FuryOfAir:IsAvailable() and Player:Maelstrom()>=45)) or (S.Overcharge:IsAvalible() and (S.FuryOfAir:IsAvailable() and Player:Maelstrom()>=80)) then
			return "Cast Stormstrike"
		end

		-- actions.core+=/frostbrand,if=variable.akainuAS
		-- actions+=/variable,name=akainuAS,value=(variable.akainuEquipped&buff.hot_hand.react&!buff.frostbrand.up)
		if I.AkainusAbsoluteJustice:IsEquipped() and Player:Buff(S.HotHandBuff) and not Player:Buff(S.FrostbrandBuff) then
			return "Cast Frostbrand"
		end

		-- actions.core+=/lava_lash,if=buff.hot_hand.react&((variable.akainuEquipped&buff.frostbrand.up)|!variable.akainuEquipped)
		if Player:Buff(S.HotHandBuff) and (I.AkainusAbsoluteJustice:IsEquipped() and Player:Buff(HotHandBuff) and not Player:Buff(S.FrostbrandBuff)) then
			return "Cast LavaLash"
		end

		-- actions.core+=/sundering,if=active_enemies>=3
		if AR.AoEON() and Cache.EnemiesCount[8] >= 3 and S.Sundering:IsAvailable() then
			return "Cast Sundering"
		end

		-- actions.core+=/crash_lightning,if=active_enemies>=3|variable.LightningCrashNotUp|variable.alphaWolfCheck
		-- actions+=/variable,name=LightningCrashNotUp,value=(!buff.lightning_crash.up&set_bonus.tier20_2pc)
		-- actions+=/variable,name=alphaWolfCheck,value=((pet.frost_wolf.buff.alpha_wolf.remains<2&pet.fiery_wolf.buff.alpha_wolf.remains<2&pet.lightning_wolf.buff.alpha_wolf.remains<2)&feral_spirit.remains>4)
		if AR.AoEON() and Cache.EnemiesCount[8] >= 3 or (not Player:Buff(CrashLightningBuff) and AC.Tier20_2Pc) or (S.FeralSpirit:TimeSinceLastCast() < 11) then
			return "Cast CrashLightning"
		end

		-- actions.filler=rockbiter,if=maelstrom<120
		if Player:Maelstrom() < 120 then
			return "Cast Rockbiter"
		end

		-- actions.filler+=/flametongue,if=buff.flametongue.remains<4.8
		if Player:BuffRemains(S.FlametongueBuff) < 5 then
			return "Cast Flametongue"
		end

		-- actions.filler+=/rockbiter,if=maelstrom<=40
		if Player:Maelstrom() <= 40 then
			return "Cast Rockbiter"
		end

		-- actions.filler+=/crash_lightning,if=(talent.crashing_storm.enabled|active_enemies>=2)&debuff.earthen_spike.up&maelstrom>=40&variable.OCPool60
		-- actions+=/variable,name=OCPool60,value=(!talent.overcharge.enabled|(talent.overcharge.enabled&maelstrom>60))
		if (S.CrashingStorm:IsAvailable() or (AR.AoEON() and Cache.EnemiesCount[8] >= 2)) and Target:Debuff(S.EarthenSpike) and Player:Maelstrom() >= 40 and (not S.Overcharge:IsAvailable() or (S.Overcharge:IsAvalible() and Player:Maelstrom() > 60)) then
			return "Cast CrashLightning"
		end

		-- actions.filler+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8&maelstrom>40
		if S.Hailstorm:IsAvalible() and Player:BuffRemains(S.FrostbrandBuff) < 5 and Player:Maelstrom() > 40 then
			return "Cast Frostbrand"
		end

		-- actions.filler+=/frostbrand,if=variable.akainuEquipped&!buff.frostbrand.up&maelstrom>=75
		if I.AkainusAbsoluteJustice:IsEquipped() and not Player:Buff(S.FrostbrandBuff) and Player:Maelstrom() >= 75 then
			return "Cast Frostbrand"
		end

		-- actions.filler+=/sundering
		if S.Sundering:IsAvailable() then
			return "Cast Sundering"
		end

		-- actions.filler+=/lava_lash,if=maelstrom>=50&variable.OCPool70&variable.furyCheck80
		-- actions+=/variable,name=OCPool70,value=(!talent.overcharge.enabled|(talent.overcharge.enabled&maelstrom>70))
		-- actions+=/variable,name=furyCheck80,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>80))
		if Player:Maelstrom() >= 50 and () and (not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 80)) then
			return "Cast LavaLash"
		end

		-- actions.filler+=/rockbiter

		-- actions.filler+=/crash_lightning,if=(maelstrom>=65|talent.crashing_storm.enabled|active_enemies>=2)&variable.OCPool60&variable.furyCheck45

		-- actions.filler+=/flametongue
    end




end

AR.SetAPL(263, APL);

--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua

  --- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local DeathKnight = AR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Unholy = {
    -- Racials
        ArcaneTorrent                 = Spell(80483),
        Berserking                    = Spell(26297),
        BloodFury                     = Spell(20572),
        GiftoftheNaaru                = Spell(59547),
    -- Artifact
	Apocalypse                    = Spell(220143),
	--Abilities
	ArmyOfDead                    = Spell(42650),
	ChainsOfIce                   = Spell(45524),
	ScourgeStrike                 = Spell(55090),
	DarkTransformation            = Spell(63560),
	DeathAndDecay                 = Spell(43265),
	DeathCoil                     = Spell(47541),
	DeathStrike                   = Spell(49958),
	FesteringStrike               = Spell(85948),
	Outbreak                      = Spell(77575),
	SummonGargoyle                = Spell(49206),
     --Talents
	BlightedRuneWeapon            = Spell(194918),
	Epidemic                      = Spell(207317),
	Castigator                    = Spell(207305),
	ClawingShadows                = Spell(207311),
	Necrosis                      = Spell(207346),
	ShadowInfusion                = Spell(198943),
	DarkArbiter                   = Spell(207349),
	Defile                        = Spell(152280),
	SoulReaper                    = Spell(130736),
	--Buffs/Procs
	SuddenDoom                    = Spell(81340),
	UnholyStrength                = Spell(53365),
	NecrosisBuff                  = Spell(216974),
	DeathAndDecayBuff             = Spell(188290),
	--Debuffs
	SoulReaperDebuff              = Spell(130736),
	FesteringWounds		      = Spell(194310), --max 8 stacks
	VirulentPlagueDebuff          = Spell(191587), -- 13s debuff from Outbreak
	--Defensives
	AntiMagicShell                = Spell(48707),
	IcebornFortitute              = Spell(48792),
	 -- Utility
        ControlUndead                 = Spell(45524),
        DeathGrip                     = Spell(49576),
        MindFreeze                    = Spell(47528),
        PathOfFrost                   = Spell(3714),
        WraithWalk                    = Spell(212552),
	--Legendaries Buffs/SpellIds 
	ColdHeartBuff                 = Spell(235592),
	InstructorsFourthLesson       = Spell(208713),
	KiljaedensBurningWish         = Spell(144259),
	--DarkArbiter HiddenAura
	DarkArbiterActive             = Spell(212412),
	
	
  };
  local S = Spell.DeathKnight.Unholy;
  --Items
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Unholy = {
    --Legendaries WIP
	ConvergenceofFates            = Item(140806, {13, 14}),
	InstructorsFourthLesson       = Item(132448, {9}),
	Taktheritrixs                 = Item(137075, {3}),
	ColdHearth                    = Item(151796, {5}),
	
	
  };
  local I = Item.DeathKnight.Unholy;
  --Rotation Var
  
  --GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DeathKnight.Commons,
    Unholy = AR.GUISettings.APL.DeathKnight.Unholy
  };
  

  --- ===== APL =====
  --- ===============
 local function Generic() 
 if S.Outbreak:IsCastable() and not Target:Debuff(S.VirulentPlagueDebuff) then
  if AR.Cast(S.Outbreak) then return ""; end
  end
 --actions.generic=dark_arbiter,if=!equipped.137075&runic_power.deficit<30
 if AR.CDsON() and S.DarkArbiter:IsCastable() and not I.Taktheritrixs:IsEquipped() and Player:RunicPowerDeficit() < 30 then
  if AR.Cast(S.DarkArbiter, Settings.Unholy.OffGCDasOffGCD.DarkArbiter) then return ; end
  end
 
 --actions.generic+=/dark_arbiter,if=equipped.137075&runic_power.deficit<30&cooldown.dark_transformation.remains<2
 if AR.CDsON() and S.DarkArbiter:IsCastable() and I.Taktheritrixs:IsEquipped() and Player:RunicPowerDeficit() < 30 and S.DarkTransformation:Cooldown() < 2 then
  if AR.Cast(S.DarkArbiter, Settings.Unholy.OffGCDasOffGCD.DarkArbiter) then return ; end
 end
  --actions.generic+=/summon_gargoyle,if=!equipped.137075,if=rune<=3
 if AR.CDsON() and S.SummonGargoyle:IsCastable() and not S.DarkArbiter:IsAvailable() and not I.Taktheritrixs:IsEquipped() and Player:Runes() <= 3 then
  if AR.Cast(S.SummonGargoyle, Settings.Unholy.OffGCDasOffGCD.SummonGargoyle) then return ; end
 end
  --actions.generic+=/summon_gargoyle,if=equipped.137075&cooldown.dark_transformation.remains<10&rune<=3
 if AR.CDsON() and S.SummonGargoyle:IsCastable() and not S.DarkArbiter:IsAvailable() and I.Taktheritrixs:IsEquipped() and S.DarkTransformation:Cooldown() < 10 and Player:Runes() <= 3 then
  if AR.Cast(S.SummonGargoyle, Settings.Unholy.OffGCDasOffGCD.SummonGargoyle) then return ; end
 end
  --actions.generic+=/chains_of_ice,if=buff.unholy_strength.up&buff.cold_heart.stack>19
 if S.ChainsOfIce:IsCastable() and Player:Buff(S.ColdHeartBuff) and Player:BuffStack(S.ColdHeartBuff) > 19 then
  if AR.Cast(S.ChainsOfIce) then return ""; end
 end
  --actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<4 -- Player:Rune() > 1 (SR cost)
 if S.SoulReaper:IsAvailable() and S.SoulReaper:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 6 and S.Apocalypse:Cooldown() < 4 and Player:Runes() >= 1 then
  if AR.Cast(S.SoulReaper) then return ""; end
 end
  --actions.generic+=/apocalypse,if=debuff.festering_wound.stack>=6
 if S.Apocalypse:IsCastable() and Target:DebuffStack(S.FesteringWounds) >=6 then
  if AR.Cast(S.Apocalypse) then return ""; end
 end
  --actions.generic+=/death_coil,if=runic_power.deficit<10
 if S.DeathCoil:IsUsable() and Player:RunicPowerDeficit() < 10 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
  --actions.generic+=/death_coil,if=!talent.dark_arbiter.enabled&buff.sudden_doom.up&!buff.necrosis.up&rune<=3
 if S.DeathCoil:IsUsable() and not S.DarkArbiter:IsAvailable() and Player:Buff(S.SuddenDoom) and not Player:Buff(S.NecrosisBuff) and Player:Runes() <= 3 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
  --actions.generic+=/death_coil,if=talent.dark_arbiter.enabled&buff.sudden_doom.up&cooldown.dark_arbiter.remains>5&rune<=3
 if S.DeathCoil:IsUsable() and S.DarkArbiter:IsAvailable() and Player:Buff(S.SuddenDoom) and S.DarkArbiter:Cooldown() > 5 and Player:Runes() <= 3 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
  --actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 6 and S.Apocalypse:Cooldown() <= 6 and Player:Runes() >= 2 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
  --actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=3
 if S.SoulReaper:IsAvailable() and S.SoulReaper:IsCastable() and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:Runes() >= 1 then
  if AR.Cast(S.SoulReaper) then return ""; end
 end
  --actions.generic+=/festering_strike,if=debuff.soul_reaper.up&!debuff.festering_wound.up
 if S.FesteringStrike:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and not Target:Debuff(S.FesteringWounds) and Player:Runes() >= 2 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
  --actions.generic+=/scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
 if S.ScourgeStrike:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end
  --actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
 if S.ClawingShadows:IsCastable() and Target:Debuff(S.SoulReaperDebuff) and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
  --actions.generic+=/defile
 if S.Defile:IsAvailable() and S.Defile:IsCastable() and Player:Runes() >= 1 then
  if AR.Cast(S.Defile) then return ""; end
  end
  return false;
end
local function Castigator()
--actions.castigator=festering_strike,if=debuff.festering_wound.stack<=4&runic_power.deficit>23
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 4 and Player:RunicPowerDeficit() > 23 then
  if AR.Cast(S.FesteringStrike) then return ""; end
  end
--actions.castigator+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune<=3
 if S.DeathCoil:IsUsable() and not Player:Buff(S.NecrosisBuff) and S.Necrosis:IsAvailable() and Player:Runes() <= 3 then
  if AR.Cast(S.DeathCoil) then return ""; end
  end
--actions.castigator+=/scourge_strike,if=buff.necrosis.react&debuff.festering_wound.stack>=3&runic_power.deficit>23
 if S.ScourgeStrike:IsCastable() and Player:Buff(S.NecrosisBuff) and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 23 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
  end
--actions.castigator+=/scourge_strike,if=buff.unholy_strength.react&debuff.festering_wound.stack>=3&runic_power.deficit>23
 if S.ScourgeStrike:IsCastable() and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() >23 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
  end
--actions.castigator+=/scourge_strike,if=rune>=2&debuff.festering_wound.stack>=3&runic_power.deficit>23
 if S.ScourgeStrike:IsCastable() and Player:Runes() >= 2 and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 23 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
  end
--actions.castigator+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>15
 if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) and S.DarkArbiter:Cooldown() > 15 then
  if AR.Cast(S.DeathCoil) then return ""; end
  end
--actions.castigator+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
 if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) then
  if AR.Cast(S.DeathCoil) then return ""; end
  end
--actions.castigator+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>15
 if S.DeathCoil:IsUsable() and S.DarkArbiter:IsAvailable() and S.DarkArbiter:Cooldown() > 15 then
  if AR.Cast(S.DeathCoil) then return ""; end
  end
--actions.castigator+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled
 if S.DeathCoil:IsUsable() and not S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() then
  if AR.Cast(S.DeathCoil) then return ""; end
  end
  return false;
end
--Instructors Fourth Lesson
local function Instructors()
--actions.instructors=festering_strike,if=debuff.festering_wound.stack<=3&runic_power.deficit>13
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 2 and Player:RunicPowerDeficit() > 5 and Player:Runes() >=2 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end 
--actions.instructors+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune<=3
if S.DeathCoil:IsUsable() and not Player:Buff(S.NecrosisBuff) and S.Necrosis:IsAvailable() and Player:Runes() <= 3 then
 if AR.Cast(S.DeathCoil) then return ""; end --TODO: maybe add sudden_doom buff condition and RP >= 35
 end 
--actions.instructors+=/scourge_strike,if=buff.necrosis.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
 if S.ScourgeStrike:IsCastable() and Player:Buff(S.NecrosisBuff) and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
--actions.instructors+=/clawing_shadows,if=buff.necrosis.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
 if S.ClawingShadows:IsCastable() and Player:Buff(S.NecrosisBuff) and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
-- actions.instructors+=/scourge_strike,if=buff.unholy_strength.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
 if S.ScourgeStrike:IsCastable() and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end
--actions.instructors+=/clawing_shadows,if=buff.unholy_strength.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
 if S.ClawingShadows:IsCastable() and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
--actions.instructors+=/scourge_strike,if=rune>=2&debuff.festering_wound.stack>=3&runic_power.deficit>9
 if S.ScourgeStrike:IsCastable() and Player:Runes() >= 2 and Player:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 9 then 
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
--actions.instructors+=/clawing_shadows,if=rune>=2&debuff.festering_wound.stack>=3&runic_power.deficit>9
 if S.ClawingShadows:IsCastable() and Player:Runes() >= 2 and Target:DebuffStack(S.FesteringWounds) >= 3 and Player:RunicPowerDeficit() > 9 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
--actions.instructors+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>10
 if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) and S.DarkArbiter:Cooldown() > 10 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
--actions.instructors+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
 if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) then 
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
--actions.instructors+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10
 if S.DeathCoil:IsUsable() and S.DarkArbiter:IsAvailable() and  S.DarkArbiter:Cooldown() > 10 then 
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
--actions.instructors+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled
 if S.DeathCoil:IsUsable() and not S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
  
-- just making sure sudden_doom procs are used with Instructors
 if S.DeathCoil:IsUsable() and Player:Buff(S.SuddenDoom) and not Player:Buff(S.NecrosisBuff) then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
   return false;
end
  --STANDARD
 local function Standard()
--actions.standard=festering_strike,if=debuff.festering_wound.stack<=3&runic_power.deficit>13
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 2 and Player:RunicPowerDeficit() > 5 and Player:Runes() >= 2 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
  --actions.standard+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune<=3
 if S.DeathCoil:IsUsable() and not Player:Buff(S.NecrosisBuff) and S.Necrosis:IsAvailable() and Player:Runes() <= 3 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
--actions.standard+=/scourge_strike,if=buff.necrosis.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
 if S.ScourgeStrike:IsCastable() and Player:Buff(S.NecrosisBuff) and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:RunicPowerDeficit() >9 and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
--actions.standard+=/clawing_shadows,if=buff.necrosis.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
 if S.ClawingShadows:IsCastable() and Player:Buff(S.NecrosisBuff) and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end 
--actions.standard+=/scourge_strike,if=buff.unholy_strength.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
 if S.ScourgeStrike:IsCastable() and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
--actions.standard+=/clawing_shadows,if=buff.unholy_strength.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
 if S.ClawingShadows:IsCastable() and Player:Buff(S.UnholyStrength) and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:RunicPowerDeficit() > 9 and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end 
--actions.standard+=/scourge_strike,if=rune>=2&debuff.festering_wound.stack>=1&runic_power.deficit>9
 if S.ScourgeStrike:IsCastable() and Player:Runes() >= 2 and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:RunicPowerDeficit() > 9 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
--actions.standard+=/clawing_shadows,if=rune>=2&debuff.festering_wound.stack>=1&runic_power.deficit>9
 if S.ClawingShadows:IsCastable() and Player:Runes() >= 2 and Target:DebuffStack(S.FesteringWounds) >= 1 and Player:RunicPowerDeficit() > 9 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end 
--actions.standard+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>10
 if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) and S.DarkArbiter:Cooldown() > 10 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
--actions.standard+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
 if S.DeathCoil:IsUsable() and S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() and not Pet:Buff(S.DarkTransformation) then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
 --actions.standard+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10
 if S.DeathCoil:IsUsable() and S.DarkArbiter:IsAvailable() and S.DarkArbiter:Cooldown() > 10 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
--actions.standard+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled
 if S.DeathCoil:IsUsable() and not S.ShadowInfusion:IsAvailable() and not S.DarkArbiter:IsAvailable() then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
 --sudden_doom usage
 if S.DeathCoil:IsUsable() and Player:Buff(S.SuddenDoom) and not Player:Buff(S.NecrosisBuff) then
  if AR.Cast(S.DeathCoil) then return ""; end
 end
   return false;
end
 --DarkArbiter
local function DarkArbiter()
--actions.valkyr+=/apocalypse,if=debuff.festering_wound.stack=8
 if S.Apocalypse:IsCastable()  and Target:DebuffStack(S.FesteringWounds) == 8 then
  if AR.Cast(S.Apocalypse) then return ""; end
 end 
 --actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
 if S.ClawingShadows:IsCastable() and Target:Debuff(S.FesteringWounds) and Player:RunicPower() < 35 and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
--actions.valkyr=death_coil
 if S.DeathCoil:IsUsable() and Player:Buff(S.SuddenDoom) or Player:RunicPower() >= 35 then
  if AR.Cast(S.DeathCoil) then return ""; end
 end 
 
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=3
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) <= 3 and Player:RunicPower() < 35 and Player:Runes() >= 2 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
 -- less festering wounds needed if valkyr is active and dc is usable with t194 pc
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 1 and Player:RunicPower() < 35 and Player:Runes() >= 2 and AC.Tier19_4Pc then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<8&cooldown.apocalypse.remains<5
 if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWounds) < 6 and Player:RunicPower() < 35 and S.Apocalypse:Cooldown() < 6 and Player:Runes() >= 2 then
  if AR.Cast(S.FesteringStrike) then return ""; end
 end 

 --actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
 if S.ScourgeStrike:IsCastable() and Target:Debuff(S.FesteringWounds) and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
 
   return false;
end
--CDS

--AOE
local function AOE()
 if  AR.AoEON() then
--actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
 if S.DeathAndDecay:IsCastable() and Cache.EnemiesCount[10] >= 2 and Player:Runes() >= 1 then
  if AR.Cast(S.DeathAndDecay) then return ""; end
 end
--actions.aoe+=/epidemic,if=spell_targets.epidemic>4
 if S.Epidemic:IsCastable() and Cache.EnemiesCount[10] > 4 and Player:Runes() >= 1 then
  if AR.Cast(S.Epidemic) then return ""; end
 end 
--actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
 if S.ScourgeStrike:IsCastable() and Cache.EnemiesCount[10] >= 2 and Player:Buff(S.DeathAndDecayBuff) and Player:Runes() >= 1 then
  if AR.Cast(S.ScourgeStrike) then return ""; end
 end 
--actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
 if S.ClawingShadows:IsCastable() and Cache.EnemiesCount[10] >= 2 and Player:Buff(S.DeathAndDecayBuff) and Player:Runes() >= 1 then
  if AR.Cast(S.ClawingShadows) then return ""; end
 end
--actions.aoe+=/epidemic,if=spell_targets.epidemic>2
 if S.Epidemic:IsCastable() and Cache.EnemiesCount[10] > 2 and Player:Runes() >= 1 then
  if AR.Cast(S.Epidemic) then return ""; end
 end
   return false;
 end
 end

local function APL()
    --UnitUpdaate
	AC.GetEnemies(10)
	Everyone.AoEToggleEnemiesUpdate();
	--Defensives
	--OutOf Combat
    -- Reset Combat Variables
    -- Flask
      -- Food
      -- Rune
      -- Army w/ Bossmod Countdown 
      -- Volley toggle
      -- Opener 
	  if not Player:AffectingCombat() then
	--army suggestion at pull
	  if Everyone.TargetIsValid() and Target:IsInRange(30) and not S.ArmyOfDead:IsOnCooldown() then
	        if AR.Cast(S.ArmyOfDead) then return ""; end
	  end
	-- outbreak if virulent_plague is not  the target and we are not in combat
	  if Everyone.TargetIsValid() and Target:IsInRange(30) and not Target:Debuff(S.VirulentPlagueDebuff)then
			if AR.Cast(S.Outbreak) then return ""; end
	  end
	
	 return;
   end
 --InCombat
    if Everyone.TargetIsValid()  then
	      ShouldReturn = Generic();
	      if ShouldReturn then return ShouldReturn;  end
		  
	   if Everyone.TargetIsValid() and Target:IsInRange(30) and not Target:Debuff(S.VirulentPlagueDebuff)then
			if AR.Cast(S.Outbreak) then return ""; end
	   end
       --actions+=/dark_transformation,if=equipped.137075&cooldown.dark_arbiter.remains>165
       if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.DarkArbiter:Cooldown() > 165 then
          if AR.Cast(S.DarkTransformation) then return ""; end
       end
 
       --actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>55
       if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and not S.ShadowInfusion:IsAvailable() and S.DarkArbiter:Cooldown() > 55 then
          if AR.Cast(S.DarkTransformation) then return ""; end
       end
 
       --actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>35
       if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.ShadowInfusion:IsAvailable() and S.DarkArbiter:Cooldown() > 35 then
         if AR.Cast(S.DarkTransformation) then return ""; end
       end
 
       --actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
       if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and Target:TimeToDie() < S.DarkArbiter:Cooldown() - 8 then
         if AR.Cast(S.DarkTransformation) then return ""; end
       end
 
      --actions+=/dark_transformation,if=equipped.137075&cooldown.summon_gargoyle.remains>160
      if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.SummonGargoyle:Cooldown() > 160 then
        if AR.Cast(S.DarkTransformation) then return ""; end
      end
 
      --actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>55
      if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and not S.ShadowInfusion:IsAvailable() and S.SummonGargoyle:Cooldown() > 55 then
         if AR.Cast(S.DarkTransformation) then return ""; end
      end
 
      --actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>35
      if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and S.ShadowInfusion:IsAvailable() and S.SummonGargoyle:Cooldown() > 35 then
        if AR.Cast(S.DarkTransformation) then return ""; end
      end
 
      --actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
      if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and I.Taktheritrixs:IsEquipped() and Target:TimeToDie() < S.SummonGargoyle:Cooldown() - 8 then
        if AR.Cast(S.DarkTransformation) then return ""; end
      end
 
      --actions+=/dark_transformation,if=!equipped.137075&rune<=3
      if S.DarkTransformation:IsCastable() and Pet:IsActive() == true and not I.Taktheritrixs:IsEquipped() and Player:Runes() <= 3 then
        if AR.Cast(S.DarkTransformation) then return ""; end
      end
 
      --actions+=/blighted_rune_weapon,if=rune<=3
      if AR.CDsON() and S.BlightedRuneWeapon:IsCastable() and Player:Runes() >= 3 then
        if AR.Cast(S.BlightedRuneWeapon, Settings.Unholy.OffGCDasOffGCD.BlightedRuneWeapon) then return ; end
     end
	 
	  if S.DarkArbiter:IsAvailable() and S.DarkArbiterActive:Cooldown() >= 165 then
	     ShouldReturn = DarkArbiter();
		if ShouldReturn then return ShouldReturn;  end
		 end
		 
	  --actions+=/call_action_list,name=generic 
	   if not S.DarkArbiter:IsAvailable() then
	     ShouldReturn = Generic();
		 if ShouldReturn then return ShouldReturn;  end
		 end
		 
		 
	  --actions.generic+=/call_action_list,name=instructors,if=equipped.132448
	  if  I.InstructorsFourthLesson:IsEquipped() then
	      ShouldReturn = Instructors();
	      if ShouldReturn then return ShouldReturn; end
	    end

	  --actions.generic+=/call_action_list,name=aoe,if=active_enemies>=2
	  if Cache.EnemiesCount[10] >= 2 then
	     ShouldReturn = AOE();
	     if ShouldReturn then return ShouldReturn; end
		 end
		 
	  --actions.generic+=/call_action_list,name=standard,if=!talent.castigator.enabled&!equipped.132448
	    if  not S.DarkArbiter:IsAvailable() or S.DarkArbiterActive:Cooldown() < 165 and not S.Castigator:IsAvailable() and not I.InstructorsFourthLesson:IsEquipped()   then
	         ShouldReturn = Standard();
	         if ShouldReturn then return ShouldReturn; end
	    end
	 
      --actions.generic+=/call_action_list,name=castigator,if=talent.castigator.enabled&!equipped.132448
	  if S.Castigator:IsAvailable() and not S.DarkArbiter:IsAvailable() and not I.InstructorsFourthLesson:IsEquipped() then
	     ShouldReturn = Castigator();
	     if ShouldReturn then return ShouldReturn; end
	 end	  
 	
	--actions.valkyr+=/call_action_list,name=aoe,if=active_enemies>=2
	  if S.DarkArbiter:IsAvailable() and  Cache.EnemiesCount[10] >= 2 then
	     ShouldReturn = AOE();
	     if ShouldReturn then return ShouldReturn; end
	 end
	 
	 return;
	 end
	 end
	 
	 
	 

AR.SetAPL(252, APL);
--- ====24/06/2017======
--- ======= SIMC =======  
--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/potion
--actions.precombat+=/raise_dead
--actions.precombat+=/army_of_the_dead
--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/mind_freeze
--actions+=/arcane_torrent,if=runic_power.deficit>20
--actions+=/blood_fury
--actions+=/berserking
--actions+=/use_items
--actions+=/use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack=0&target.time_to_die>60)|target.time_to_die<60
--actions+=/potion,if=buff.unholy_strength.react
--actions+=/outbreak,target_if=!dot.virulent_plague.ticking
--actions+=/army_of_the_dead
--actions+=/dark_transformation,if=equipped.137075&cooldown.dark_arbiter.remains>165
--actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>55
--actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.dark_arbiter.remains>35
--actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.dark_arbiter.remains-8
--actions+=/dark_transformation,if=equipped.137075&cooldown.summon_gargoyle.remains>160
--actions+=/dark_transformation,if=equipped.137075&!talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>55
--actions+=/dark_transformation,if=equipped.137075&talent.shadow_infusion.enabled&cooldown.summon_gargoyle.remains>35
--actions+=/dark_transformation,if=equipped.137075&target.time_to_die<cooldown.summon_gargoyle.remains-8
--actions+=/dark_transformation,if=!equipped.137075&rune<=3
--actions+=/blighted_rune_weapon,if=rune<=3
--actions+=/run_action_list,name=valkyr,if=talent.dark_arbiter.enabled&pet.valkyr_battlemaiden.active
--actions+=/call_action_list,name=generic

--actions.aoe=death_and_decay,if=spell_targets.death_and_decay>=2
--actions.aoe+=/epidemic,if=spell_targets.epidemic>4
--actions.aoe+=/scourge_strike,if=spell_targets.scourge_strike>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
--actions.aoe+=/clawing_shadows,if=spell_targets.clawing_shadows>=2&(dot.death_and_decay.ticking|dot.defile.ticking)
--actions.aoe+=/epidemic,if=spell_targets.epidemic>2

--actions.castigator=festering_strike,if=debuff.festering_wound.stack<=4&runic_power.deficit>23
--actions.castigator+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune<=3
--actions.castigator+=/scourge_strike,if=buff.necrosis.react&debuff.festering_wound.stack>=3&runic_power.deficit>23
--actions.castigator+=/scourge_strike,if=buff.unholy_strength.react&debuff.festering_wound.stack>=3&runic_power.deficit>23
--actions.castigator+=/scourge_strike,if=rune>=2&debuff.festering_wound.stack>=3&runic_power.deficit>23
--actions.castigator+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>15
--actions.castigator+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
--actions.castigator+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>15
--actions.castigator+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled

--actions.generic=dark_arbiter,if=!equipped.137075&runic_power.deficit<30
--actions.generic+=/dark_arbiter,if=equipped.137075&runic_power.deficit<30&cooldown.dark_transformation.remains<2
--actions.generic+=/summon_gargoyle,if=!equipped.137075,if=rune<=3
--actions.generic+=/chains_of_ice,if=buff.unholy_strength.up&buff.cold_heart.stack>19
--actions.generic+=/summon_gargoyle,if=equipped.137075&cooldown.dark_transformation.remains<10&rune<=3
--actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=6&cooldown.apocalypse.remains<4
--actions.generic+=/apocalypse,if=debuff.festering_wound.stack>=6
--actions.generic+=/death_coil,if=runic_power.deficit<10
--actions.generic+=/death_coil,if=!talent.dark_arbiter.enabled&buff.sudden_doom.up&!buff.necrosis.up&rune<=3
--actions.generic+=/death_coil,if=talent.dark_arbiter.enabled&buff.sudden_doom.up&cooldown.dark_arbiter.remains>5&rune<=3
--actions.generic+=/festering_strike,if=debuff.festering_wound.stack<6&cooldown.apocalypse.remains<=6
--actions.generic+=/soul_reaper,if=debuff.festering_wound.stack>=3
--actions.generic+=/festering_strike,if=debuff.soul_reaper.up&!debuff.festering_wound.up
--actions.generic+=/scourge_strike,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
--actions.generic+=/clawing_shadows,if=debuff.soul_reaper.up&debuff.festering_wound.stack>=1
--actions.generic+=/defile
--actions.generic+=/call_action_list,name=aoe,if=active_enemies>=2
--actions.generic+=/call_action_list,name=instructors,if=equipped.132448
--actions.generic+=/call_action_list,name=standard,if=!talent.castigator.enabled&!equipped.132448
--actions.generic+=/call_action_list,name=castigator,if=talent.castigator.enabled&!equipped.132448

--actions.instructors=festering_strike,if=debuff.festering_wound.stack<=2&runic_power.deficit>5
--actions.instructors+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune<=3
--actions.instructors+=/scourge_strike,if=buff.necrosis.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
--actions.instructors+=/clawing_shadows,if=buff.necrosis.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
--actions.instructors+=/scourge_strike,if=buff.unholy_strength.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
--actions.instructors+=/clawing_shadows,if=buff.unholy_strength.react&debuff.festering_wound.stack>=3&runic_power.deficit>9
--actions.instructors+=/scourge_strike,if=rune>=2&debuff.festering_wound.stack>=3&runic_power.deficit>9
--actions.instructors+=/clawing_shadows,if=rune>=2&debuff.festering_wound.stack>=3&runic_power.deficit>9
--actions.instructors+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>10
--actions.instructors+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
--actions.instructors+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10
--actions.instructors+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled

--actions.standard=festering_strike,if=debuff.festering_wound.stack<=2&runic_power.deficit>5
--actions.standard+=/death_coil,if=!buff.necrosis.up&talent.necrosis.enabled&rune<=3
--actions.standard+=/scourge_strike,if=buff.necrosis.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
--actions.standard+=/clawing_shadows,if=buff.necrosis.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
--actions.standard+=/scourge_strike,if=buff.unholy_strength.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
--actions.standard+=/clawing_shadows,if=buff.unholy_strength.react&debuff.festering_wound.stack>=1&runic_power.deficit>9
--actions.standard+=/scourge_strike,if=rune>=2&debuff.festering_wound.stack>=1&runic_power.deficit>9
--actions.standard+=/clawing_shadows,if=rune>=2&debuff.festering_wound.stack>=1&runic_power.deficit>9
--actions.standard+=/death_coil,if=talent.shadow_infusion.enabled&talent.dark_arbiter.enabled&!buff.dark_transformation.up&cooldown.dark_arbiter.remains>10
--actions.standard+=/death_coil,if=talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled&!buff.dark_transformation.up
--actions.standard+=/death_coil,if=talent.dark_arbiter.enabled&cooldown.dark_arbiter.remains>10
--actions.standard+=/death_coil,if=!talent.shadow_infusion.enabled&!talent.dark_arbiter.enabled

--actions.valkyr=death_coil
--actions.valkyr+=/apocalypse,if=debuff.festering_wound.stack=8
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<8&cooldown.apocalypse.remains<5
--actions.valkyr+=/call_action_list,name=aoe,if=active_enemies>=2
--actions.valkyr+=/festering_strike,if=debuff.festering_wound.stack<=3
--actions.valkyr+=/scourge_strike,if=debuff.festering_wound.up
--actions.valkyr+=/clawing_shadows,if=debuff.festering_wound.up
	

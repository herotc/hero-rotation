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
local tostring = tostring;

--- APL Local Vars
-- Spells
  if not Spell.Rogue then Spell.Rogue = {}; end
  Spell.Rogue.Outlaw = {
    -- Racials
    ArcaneTorrent = Spell(25046),
    Berserking = Spell(26297),
    BloodFury = Spell(20572),
    GiftoftheNaaru = Spell(59547),
    Shadowmeld = Spell(58984),
    -- Abilities
    Alacrity = Spell(193539),
    AlacrityBuff = Spell(193538),
    Ambush = Spell(8676),
    Anticipation = Spell(114015),
    BetweentheEyes = Spell(199804),
    BladeFlurry = Spell(13877),
    DeathfromAbove = Spell(152150),
    DeeperStratagem = Spell(193531),
    GhostlyStrike = Spell(196937),
    HiddenBlade = Spell(202754),
    Opportunity = Spell(195627),
    PistolShot = Spell(185763),
    QuickDraw = Spell(196938),
    RolltheBones = Spell(193316),
    RunThrough = Spell(2098),
    SaberSlash = Spell(193315),
    SliceandDice = Spell(5171),
    Stealth = Spell(1784),
    -- Offensive
    AdrenalineRush = Spell(13750),
    CannonballBarrage = Spell(185767),
    CurseoftheDreadblades = Spell(202665),
    KillingSpree = Spell(51690),
    MarkedforDeath = Spell(137619),
    Vanish = Spell(1856),
    -- Defensive
    CrimsonVial = Spell(185311),
    Feint = Spell(1966),
    -- Utility
    Kick = Spell(1766),
    Sprint = Spell(2983),
    -- Roll the Bones
    Broadsides = Spell(193356),
    BuriedTreasure = Spell(199600),
    GrandMelee = Spell(193358),
    JollyRoger = Spell(199603),
    SharkInfestedWaters = Spell(193357),
    TrueBearing = Spell(193359)
  };
  local S = Spell.Rogue.Outlaw;
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Outlaw = {
    -- Legendaries
    GreenskinsWaterloggedWristcuffs = Item(137099), -- 9
    ShivarranSymmetry = Item(141321), -- 10
    ThraxisTricksyTreads = Item(137031) -- 8
  };
  local I = Item.Rogue.Outlaw;
-- Rotation Var
  local EnemiesCount = {
    [8] = 1,
    [6] = 1
  };
  local BFTimer, BFReset = 0, nil; -- Blade Flurry Expiration Offset
  local Sequence; -- RtB_List
  local Count; -- Used when Counting Units
  local BestUnit, BestUnitTTD; -- Used for cycling
-- GUI Settings
  local Settings = {
    General = ER.GUISettings.General,
    Outlaw = ER.GUISettings.APL.Rogue.Outlaw
  };

-- APL Action Lists (and Variables)
local RtB_BuffsList = {
  S.Broadsides,
  S.BuriedTreasure,
  S.GrandMelee,
  S.JollyRoger,
  S.SharkInfestedWaters,
  S.TrueBearing
};
local function RtB_List (Type, List)
  if not ER.Cache.APLVar.RtB_List then ER.Cache.APLVar.RtB_List = {}; end
  if not ER.Cache.APLVar.RtB_List[Type] then ER.Cache.APLVar.RtB_List[Type] = {}; end
  Sequence = "";
  for i = 1, #List do
    Sequence = Sequence..tostring(List[i]);
  end
  -- All
  if Type == "All" then
    if not ER.Cache.APLVar.RtB_List[Type][Sequence] then
      Count = 0;
      for i = 1, #List do
        if Player:Buff(RtB_BuffsList[List[i]]) then
          Count = Count + 1;
        end
      end
      ER.Cache.APLVar.RtB_List[Type][Sequence] = Count == #List and true or false;
    end
  -- Any
  else
    if not ER.Cache.APLVar.RtB_List[Type][Sequence] then
      ER.Cache.APLVar.RtB_List[Type][Sequence] = false;
      for i = 1, #List do
        if Player:Buff(RtB_BuffsList[List[i]]) then
          ER.Cache.APLVar.RtB_List[Type][Sequence] = true;
          break;
        end
      end
    end
  end
  return ER.Cache.APLVar.RtB_List[Type][Sequence];
end
local function RtB_BuffRemains ()
  if not ER.Cache.APLVar.RtB_BuffRemains then
    ER.Cache.APLVar.RtB_BuffRemains = 0;
    for i = 1, #RtB_BuffsList do
      if Player:Buff(RtB_BuffsList[i]) then
        ER.Cache.APLVar.RtB_BuffRemains = Player:BuffRemains(RtB_BuffsList[i]);
        break;
      end
    end
  end
  return ER.Cache.APLVar.RtB_BuffRemains;
end
-- Get the number of Roll the Bones buffs currently on
local function RtB_Buffs ()
  if not ER.Cache.APLVar.RtB_Buffs then
    ER.Cache.APLVar.RtB_Buffs = 0;
    for i = 1, #RtB_BuffsList do
      if Player:Buff(RtB_BuffsList[i]) then
        ER.Cache.APLVar.RtB_Buffs = ER.Cache.APLVar.RtB_Buffs + 1;
      end
    end
  end
  return ER.Cache.APLVar.RtB_Buffs;
end
-- # Condition to continue rerolling RtB (2- or not TB alone or not SIW alone during CDs); If SnD: consider that you never have to reroll.
local function RtB_Reroll ()
  -- actions=variable,name=rtb_reroll,value=!talent.slice_and_dice.enabled&(rtb_buffs<=1&!rtb_list.any.6&((!buff.curse_of_the_dreadblades.up&!buff.adrenaline_rush.up)|!rtb_list.any.5))
  if not ER.Cache.APLVar.RtB_Reroll then
    -- Defensive Override : Grand Melee if HP < 60
    if Settings.Outlaw.RolltheBonesLeechHP and Player:HealthPercentage() < Settings.Outlaw.RolltheBonesLeechHP then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.GrandMelee)) and true or false;
    -- 1+ Buff
    elseif Settings.Outlaw.RolltheBonesLogic == "1+ Buff" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and RtB_Buffs() <= 0) and true or false;
    -- Broadsides
    elseif Settings.Outlaw.RolltheBonesLogic == "Broadsides" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.Broadsides)) and true or false;
    -- Buried Treasure
    elseif Settings.Outlaw.RolltheBonesLogic == "Buried Treasure" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.BuriedTreasure)) and true or false;
    -- Grand Melee
    elseif Settings.Outlaw.RolltheBonesLogic == "Grand Melee" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.GrandMelee)) and true or false;
    -- Jolly Roger
    elseif Settings.Outlaw.RolltheBonesLogic == "Jolly Roger" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.JollyRoger)) and true or false;
    -- Shark Infested Waters
    elseif Settings.Outlaw.RolltheBonesLogic == "Shark Infested Waters" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.SharkInfestedWaters)) and true or false;
    -- True Bearing
    elseif Settings.Outlaw.RolltheBonesLogic == "True Bearing" then
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.TrueBearing)) and true or false;
    -- SimC Default
    else
      ER.Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and (RtB_Buffs() <= 1 and not RtB_List("Any", {6}) and ((not Player:Debuff(S.CurseoftheDreadblades) and not Player:Buff(S.AdrenalineRush)) or not RtB_List("Any", {5})))) and true or false;
    end
  end
  return ER.Cache.APLVar.RtB_Reroll;
end
-- # Condition to use Saber Slash when not rerolling RtB or when using SnD
local function SS_Useable_NoReroll ()
  -- actions+=/variable,name=ss_useable_noreroll,value=(combo_points<5+talent.deeper_stratagem.enabled-(buff.broadsides.up|buff.jolly_roger.up)-(talent.alacrity.enabled&buff.alacrity.stack<=4))
  if not ER.Cache.APLVar.SS_Useable_NoReroll then
    ER.Cache.APLVar.SS_Useable_NoReroll = (Player:ComboPoints() < 5+(S.DeeperStratagem:IsAvailable() and 1 or 0)-((Player:Buff(S.Broadsides) or Player:Buff(S.JollyRoger)) and 1 or 0)-((S.Alacrity:IsAvailable() and Player:BuffStack(S.AlacrityBuff) <= 4) and 1 or 0)) and true or false;
  end
  return ER.Cache.APLVar.SS_Useable_NoReroll;
end
-- # Condition to use Saber Slash, when you have RtB or not
local function SS_Useable ()
  -- actions+=/variable,name=ss_useable,value=(talent.anticipation.enabled&combo_points<4)|(!talent.anticipation.enabled&((variable.rtb_reroll&combo_points<4+talent.deeper_stratagem.enabled)|(!variable.rtb_reroll&variable.ss_useable_noreroll)))
  if not ER.Cache.APLVar.SS_Useable then
    ER.Cache.APLVar.SS_Useable = ((S.Anticipation:IsAvailable() and Player:ComboPoints() < 4) or (not S.Anticipation:IsAvailable() and ((RtB_Reroll() and Player:ComboPoints() < 4+(S.DeeperStratagem:IsAvailable() and 1 or 0)) or (not RtB_Reroll() and SS_Useable_NoReroll())))) and true or false;
  end
  return ER.Cache.APLVar.SS_Useable;
end
-- # Condition to use Stealth abilities
local function Stealth_Condition ()
  -- actions.stealth=variable,name=stealth_condition,value=(combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&!debuff.ghostly_strike.up)+buff.broadsides.up&energy>60&!buff.jolly_roger.up&!buff.hidden_blade.up&!buff.curse_of_the_dreadblades.up)
  if not ER.Cache.APLVar.Stealth_Condition then
    ER.Cache.APLVar.Stealth_Condition = (Player:ComboPointsDeficit() >= 2+2*((S.GhostlyStrike:IsAvailable() and not Target:Debuff(S.GhostlyStrike)) and 1 or 0)+(Player:Buff(S.Broadsides) and 1 or 0) and Player:Energy() > 60 and not Player:Buff(S.JollyRoger) and not Player:Buff(S.HiddenBlade) and not Player:Debuff(S.CurseoftheDreadblades)) and true or false;
  end
  return ER.Cache.APLVar.Stealth_Condition;
end
-- # Blade Flurry
local function BF ()
  -- actions.bf=cancel_buff,name=blade_flurry,if=equipped.shivarran_symmetry&cooldown.blade_flurry.up&buff.blade_flurry.up&spell_targets.blade_flurry>=2|spell_targets.blade_flurry<2&buff.blade_flurry.up
  if Player:Buff(S.BladeFlurry) and ((EnemiesCount[6] < 2 and ER.GetTime() > BFTimer) or (I.ShivarranSymmetry:IsEquipped(10) and not S.BladeFlurry:IsOnCooldown() and EnemiesCount[6] >= 2)) then
    if ER.Cast(S.BladeFlurry, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cast"; end
  end
  -- actions.bf+=/blade_flurry,if=spell_targets.blade_flurry>=2&!buff.blade_flurry.up
  if not S.BladeFlurry:IsOnCooldown() and not Player:Buff(S.BladeFlurry) and EnemiesCount[6] >= 2 then
    if ER.Cast(S.BladeFlurry, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cast"; end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  -- actions.cds=potion,name=deadly_grace,if=buff.bloodlust.react|target.time_to_die<=25|buff.adrenaline_rush.up
  -- TODO: Add Potion
  -- actions.cds+=/cannonball_barrage,if=spell_targets.cannonball_barrage>=1
  if ER.AoEON() and S.CannonballBarrage:IsAvailable() and EnemiesCount[8] >= 1 and not S.CannonballBarrage:IsOnCooldown() then
    if ER.Cast(S.CannonballBarrage) then return "Cast Cannonball Barrage"; end
  end
  if Target:IsInRange(5) then
    -- actions.cds+=/blood_fury
    if S.BloodFury:IsCastable() then
      if ER.Cast(S.BloodFury, Settings.Outlaw.OffGCDasOffGCD.BloodFury) then return "Cast"; end
    end
    -- actions.cds+=/berserking
    if S.Berserking:IsCastable() then
      if ER.Cast(S.Berserking, Settings.Outlaw.OffGCDasOffGCD.Berserking) then return "Cast"; end
    end
    -- actions.cds+=/arcane_torrent,if=energy.deficit>40
    if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 40 then
      if ER.Cast(S.ArcaneTorrent, Settings.Outlaw.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
    end
    -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&energy.deficit>0
    if S.AdrenalineRush:IsCastable() and not Player:Buff(S.AdrenalineRush) and Player:EnergyDeficit() > 0 then
      if ER.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast"; end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15)&combo_points.deficit>=4+talent.deeper_strategem.enabled+talent.anticipation.enabled)
    --[[Normal MfD
    if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= 4+(S.DeeperStratagem:IsAvailable() and 1 or 0)+(S.Anticipation:IsAvailable() and 1 or 0) then
      if ER.Cast(S.MarkedforDeath, Settings.Outlaw.OffGCDasOffGCD.MarkedforDeath) then return "Cast"; end
    end]]
    -- actions.cds+=/sprint,if=equipped.thraxis_tricksy_treads&!variable.ss_useable
    if I.ThraxisTricksyTreads:IsEquipped(8) and S.Sprint:IsCastable() and not SS_Useable() then
      if ER.Cast(S.Sprint, Settings.Outlaw.OffGCDasOffGCD.Sprint) then return "Cast"; end
    end
    -- actions.cds+=/curse_of_the_dreadblades,if=combo_points.deficit>=4&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)
    if S.CurseoftheDreadblades:IsCastable() and Player:ComboPointsDeficit() >= 4 and (not S.GhostlyStrike:IsAvailable() or Target:Debuff(S.GhostlyStrike)) then
      if ER.Cast(S.CurseoftheDreadblades, Settings.Outlaw.OffGCDasOffGCD.CurseoftheDreadblades) then return "Cast"; end
    end
  end
  return false;
end
-- # Stealth
local function Stealth ()
  if Target:IsInRange(5) then
    -- actions.stealth+=/ambush
    if Player:IsStealthed(true, true) and S.Ambush:IsCastable() then
      if ER.Cast(S.Ambush) then return "Cast Ambush"; end
    else
      if ER.CDsON() and Stealth_Condition() and not Player:IsTanking(Target) then
        -- actions.stealth+=/vanish,if=variable.stealth_condition
        if S.Vanish:IsCastable() then
          if ER.Cast(S.Vanish, Settings.Outlaw.OffGCDasOffGCD.Vanish) then return "Cast"; end
        -- actions.stealth+=/shadowmeld,if=variable.stealth_condition
        elseif S.Shadowmeld:IsCastable() then
          if ER.Cast(S.Shadowmeld, Settings.Outlaw.OffGCDasOffGCD.Shadowmeld) then return "Cast"; end
        end
      end
    end
  end
  return false;
end
-- # Finishers
local function Finish ()
  -- actions.finish=between_the_eyes,if=equipped.greenskins_waterlogged_wristcuffs&buff.shark_infested_waters.up
  if I.GreenskinsWaterloggedWristcuffs:IsEquipped(9) and Target:IsInRange(20) and S.BetweentheEyes:IsCastable() and Player:Buff(S.SharkInfestedWaters) then
    if ER.Cast(S.BetweentheEyes) then return "Cast Between the Eyes"; end
  end
  -- actions.finish+=/run_through,if=!talent.death_from_above.enabled|energy.time_to_max<cooldown.death_from_above.remains+3.5
  if (not S.DeathfromAbove:IsAvailable() or Player:EnergyTimeToMax() < S.DeathfromAbove:Cooldown() + 3.5) and Target:IsInRange(6) and S.RunThrough:IsCastable() then
    if ER.Cast(S.RunThrough) then return "Cast Run Through"; end
  end
  -- OutofRange BtE
  if not Target:IsInRange(10) and Target:IsInRange(20) and S.BetweentheEyes:IsCastable() then
    if ER.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (OoR)"; end
  end
  return false;
end
-- # Builders
local function Build ()
  -- actions.build=ghostly_strike,if=(debuff.ghostly_strike.remains<debuff.ghostly_strike.duration*0.3|(cooldown.curse_of_the_dreadblades.remains<3&debuff.ghostly_strike.remains<14))&combo_points.deficit>=1+buff.broadsides.up&!buff.curse_of_the_dreadblades.up&(combo_points>=3|variable.rtb_reroll&time>=10)
  if Target:IsInRange(5) and S.GhostlyStrike:IsCastable() and (Target:DebuffRefreshable(S.GhostlyStrike, 4.5) or (ER.CDsON() and S.CurseoftheDreadblades:IsAvailable() and S.CurseoftheDreadblades:Cooldown() < 3 and Target:DebuffRemains(S.GhostlyStrike) < 14)) and Player:ComboPointsDeficit() >= 1+(Player:Buff(S.Broadsides) and 1 or 0) and not Player:Debuff(S.CurseoftheDreadblades) and (Player:ComboPoints() >= 3 or (RtB_Reroll() and ER.CombatTime() >= 10)) then
    if ER.Cast(S.GhostlyStrike) then return "Cast Ghostly Strike"; end
  end
  -- actions.build+=/pistol_shot,if=buff.opportunity.up&energy.time_to_max>2-talent.quick_draw.enabled&combo_points.deficit>=1+buff.broadsides.up
  if Target:IsInRange(20) and S.PistolShot:IsCastable() and Player:Buff(S.Opportunity) and Player:EnergyTimeToMax() > 2-(S.QuickDraw:IsAvailable() and 1 or 0) and Player:ComboPointsDeficit() >= 1+(Player:Buff(S.Broadsides) and 1 or 0) then
    if ER.Cast(S.PistolShot) then return "Cast Pistol Shot"; end
  end
  -- actions.build+=/saber_slash,if=variable.ss_useable
  if Target:IsInRange(5) and S.SaberSlash:IsCastable() and SS_Useable() then
    if ER.Cast(S.SaberSlash) then return "Cast Saber Slash"; end
  end
  return false;
end
local SappedSoulSpells = {
  {S.Kick, "Cast Kick (Sappel Soul)", function () return Target:IsInRange(5); end},
  {S.Feint, "Cast Feint (Sappel Soul)", function () return true; end},
  {S.CrimsonVial, "Cast Crimson Vial (Sappel Soul)", function () return true; end}
};
local function MythicDungeon ()
  -- Sapped Soul
  if ER.MythicDungeon() == "Sapped Soul" then
    for i = 1, #SappedSoulSpells do
      if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
        ER.ChangePulseTimer(1);
        ER.Cast(SappedSoulSpells[i][1]);
        return SappedSoulSpells[i][2];
      end
    end
  end
  return false;
end
local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
    -- Between the Eyes
    if Player:ComboPoints() > 0 and not S.BetweentheEyes:IsOnCooldown() and Target:IsInRange(20) then
      if ER.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (Training Scenario)"; end
    end
  end
  return false;
end

-- APL Main
local function APL ()
  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    if S.Stealth:IsCastable() and not Player:IsStealthed() then
      if ER.Cast(S.Stealth, Settings.Outlaw.OffGCDasOffGCD.Stealth) then return "Cast"; end
    end
    -- Crimson Vial
    if S.CrimsonVial:IsCastable() and Player:HealthPercentage() <= 80 then
      if ER.Cast(S.CrimsonVial, Settings.Outlaw.GCDasOffGCD.CrimsonVial) then return "Cast"; end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) then
      if Player:ComboPoints() >= 5 then
        if S.RunThrough:IsCastable() then
          if ER.Cast(S.RunThrough) then return "Cast Run Through (Opener)"; end
        end
      elseif Player:IsStealthed(true, true) and S.Ambush:IsCastable() then
        if ER.Cast(S.Ambush) then return "Cast Ambush (Opener)"; end
      elseif S.SaberSlash:IsCastable() then
        if ER.Cast(S.SaberSlash) then return "Cast Saber Slash (Opener)"; end
      end
    end
    return;
  end
  -- In Combat
    -- Unit Update
    if S.MarkedforDeath:IsAvailable() then ER.GetEnemies(30); end
    ER.GetEnemies(8); -- Cannonball Barrage
    ER.GetEnemies(6); -- Blade Flurry
    ER.GetEnemies(5); -- Melee
    if ER.AoEON() then
      for Key, Value in pairs(EnemiesCount) do
        EnemiesCount[Key] = #ER.Cache.Enemies[Key];
      end
    else
      for Key, Value in pairs(EnemiesCount) do
        EnemiesCount[Key] = 1;
      end
    end
    -- Blade Flurry Expiration Offset
    if EnemiesCount[6] == 1 and BFReset then
      BFTimer, BFReset = ER.GetTime() + Settings.Outlaw.BFOffset, false;
    elseif EnemiesCount[6] > 1 then
      BFReset = true;
    end
    -- MfD Sniping
    if S.MarkedforDeath:IsCastable() then
      BestUnit, BestUnitTTD = nil, 60;
      for Key, Value in pairs(ER.Cache.Enemies[30]) do
        if not Value:IsMfdBlacklisted() and
          Value:TimeToDie() < Player:ComboPointsDeficit()*1.5 and
          Value:TimeToDie() < BestUnitTTD then -- I increased the SimC condition since we are slower.
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        ER.Nameplate.AddIcon(BestUnit, S.MarkedforDeath);
      end
    end
    -- Crimson Vial
    if S.CrimsonVial:IsCastable() and Player:HealthPercentage() <= 35 then
      if ER.Cast(S.CrimsonVial, Settings.Outlaw.GCDasOffGCD.CrimsonVial) then return "Cast Crimson Vial"; end
    end
    -- Feint
    if S.Feint:IsCastable() and not Player:Buff(S.Feint) and Player:HealthPercentage() <= 10 then
      if ER.Cast(S.Feint, Settings.Outlaw.GCDasOffGCD.Feint) then return "Cast Feint"; end
    end
    -- actions+=/call_action_list,name=bf
    if BF() then
      return;
    end
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      -- Mythic Dungeon
      if MythicDungeon() then
        return;
      end
      -- Training Scenario
      if TrainingScenario() then
        return;
      end
      -- Kick
      if Settings.General.InterruptEnabled and Target:IsInRange(5) and S.Kick:IsCastable() and Target:IsInterruptible() then
        if ER.Cast(S.Kick, Settings.Outlaw.OffGCDasOffGCD.Kick) then return "Cast Kick"; end
      end
      -- actions+=/call_action_list,name=cds
      if ER.CDsON() and CDs() then
        return;
      end
      -- # Conditions are here to avoid worthless check if nothing is available
      -- actions+=/call_action_list,name=stealth,if=stealthed|cooldown.vanish.up|cooldown.shadowmeld.up
      if Stealth() then
        return;
      end
      -- actions+=/death_from_above,if=energy.time_to_max>2&!variable.ss_useable_noreroll
      if S.DeathfromAbove:IsCastable() and not SS_Useable_NoReroll() and Player:EnergyTimeToMax() > 2 then
        if ER.Cast(S.DeathfromAbove) then return "Cast Death from above"; end
      end
      if not SS_Useable() then
        -- actions+=/slice_and_dice,if=!variable.ss_useable&buff.slice_and_dice.remains<target.time_to_die&buff.slice_and_dice.remains<(1+combo_points)*1.8
        if S.SliceandDice:IsAvailable() then
          if S.SliceandDice:IsCastable() and Player:BuffRemains(S.SliceandDice) < Target:TimeToDie() and Player:BuffRemains(S.SliceandDice) < (1+Player:ComboPoints())*1.8 then
            if ER.Cast(S.SliceandDice) then return "Cast Slice and Dice"; end
          end
        -- actions+=/roll_the_bones,if=!variable.ss_useable&buff.roll_the_bones.remains<target.time_to_die&(buff.roll_the_bones.remains<=3|variable.rtb_reroll)
        else
          if S.RolltheBones:IsCastable() and RtB_BuffRemains() < Target:TimeToDie() and (RtB_BuffRemains() <= 3 or RtB_Reroll()) then
            if ER.Cast(S.RolltheBones) then return "Cast Roll the Bones"; end
          end
        end
      end
      -- actions+=/killing_spree,if=energy.time_to_max>5|energy<15
      if ER.CDsON() and S.KillingSpree:IsCastable() and (Player:EnergyTimeToMax() > 5 or Player:Energy() < 15) then
        if ER.Cast(S.KillingSpree) then return "Cast Killing Spree"; end
      end
      -- actions+=/call_action_list,name=build
      if Build() then
        return;
      end
      -- actions+=/call_action_list,name=finish,if=!variable.ss_useable
      if not SS_Useable() then
        if Finish() then
          return;
        end
      end
      -- OutofRange Pistol Shot
      if not Target:IsInRange(10) and Target:IsInRange(20) and S.PistolShot:IsCastable() and not Player:IsStealthed(true, true) and Player:EnergyDeficit() < 25 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if ER.Cast(S.PistolShot) then return "Cast Pistol Shot"; end
      end
    end
end

ER.SetAPL(260, APL);

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
local tableconcat = table.concat;
local tostring = tostring;


--- APL Local Vars
-- Commons
  local Everyone = AR.Commons.Everyone;
  local Rogue = AR.Commons.Rogue;
-- Spells
  if not Spell.Rogue then Spell.Rogue = {}; end
  Spell.Rogue.Outlaw = {
    -- Racials
    ArcaneTorrent                   = Spell(25046),
    Berserking                      = Spell(26297),
    BloodFury                       = Spell(20572),
    Darkflight                      = Spell(68992),
    GiftoftheNaaru                  = Spell(59547),
    Shadowmeld                      = Spell(58984),
    -- Abilities
    AdrenalineRush                  = Spell(13750),
    Ambush                          = Spell(8676),
    BetweentheEyes                  = Spell(199804),
    BladeFlurry                     = Spell(13877),
    BladeFlurry2                    = Spell(103828), -- Icon: Prot. Warrior Warbringer
    Opportunity                     = Spell(195627),
    PistolShot                      = Spell(185763),
    RolltheBones                    = Spell(193316),
    RunThrough                      = Spell(2098),
    SaberSlash                      = Spell(193315),
    Stealth                         = Spell(1784),
    Vanish                          = Spell(1856),
    VanishBuff                      = Spell(11327),
    -- Talents
    Alacrity                        = Spell(193539),
    AlacrityBuff                    = Spell(193538),
    Anticipation                    = Spell(114015),
    CannonballBarrage               = Spell(185767),
    DeathfromAbove                  = Spell(152150),
    DeeperStratagem                 = Spell(193531),
    DirtyTricks                     = Spell(108216),
    GhostlyStrike                   = Spell(196937),
    KillingSpree                    = Spell(51690),
    MarkedforDeath                  = Spell(137619),
    QuickDraw                       = Spell(196938),
    SliceandDice                    = Spell(5171),
    Vigor                           = Spell(14983),
    -- Artifact
    Blunderbuss                     = Spell(202895),
    CurseoftheDreadblades           = Spell(202665),
    HiddenBlade                     = Spell(202754),
    LoadedDice                      = Spell(240837),
    -- Defensive
    CrimsonVial                     = Spell(185311),
    Feint                           = Spell(1966),
    -- Utility
    Gouge                           = Spell(1776),
    Kick                            = Spell(1766),
    Sprint                          = Spell(2983),
    -- Roll the Bones
    Broadsides                      = Spell(193356),
    BuriedTreasure                  = Spell(199600),
    GrandMelee                      = Spell(193358),
    JollyRoger                      = Spell(199603),
    SharkInfestedWaters             = Spell(193357),
    TrueBearing                     = Spell(193359),
    -- Legendaries
    GreenskinsWaterloggedWristcuffs = Spell(209423)
  };
  local S = Spell.Rogue.Outlaw;
  -- Choose a persistent PistolShot icon to avoid Blunderbuss icon
  S.PistolShot.TextureSpellID = 242277;
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Outlaw = {
    -- Legendaries
    GreenskinsWaterloggedWristcuffs = Item(137099, {9}),
    MantleoftheMasterAssassin       = Item(144236, {3}),
    ShivarranSymmetry               = Item(141321, {10}),
    ThraxisTricksyTreads            = Item(137031, {8})
  };
  local I = Item.Rogue.Outlaw;
-- Spells Damage / PMultiplier
  local function ImprovedSliceAndDice()
    return Player:Buff(S.SliceandDice) and Player:Buff(S.SliceandDice, 17) > 125;
  end
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
  local RTIdentifier, SSIdentifier = tostring(S.RunThrough:ID()), tostring(S.SaberSlash:ID());
  local BFTimer, BFReset = 0, nil; -- Blade Flurry Expiration Offset
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Outlaw = AR.GUISettings.APL.Rogue.Outlaw
  };

-- APL Action Lists (and Variables)
local SappedSoulSpells = {
  {S.Kick, "Cast Kick (Sapped Soul)", function () return Target:IsInRange(S.SaberSlash); end},
  {S.Feint, "Cast Feint (Sapped Soul)", function () return true; end},
  {S.CrimsonVial, "Cast Crimson Vial (Sapped Soul)", function () return true; end}
};
local RtB_BuffsList = {
  S.Broadsides,
  S.BuriedTreasure,
  S.GrandMelee,
  S.JollyRoger,
  S.SharkInfestedWaters,
  S.TrueBearing
};
local function RtB_List (Type, List)
  if not Cache.APLVar.RtB_List then Cache.APLVar.RtB_List = {}; end
  if not Cache.APLVar.RtB_List[Type] then Cache.APLVar.RtB_List[Type] = {}; end
  local Sequence = table.concat(List);
  -- All
  if Type == "All" then
    if not Cache.APLVar.RtB_List[Type][Sequence] then
      local Count = 0;
      for i = 1, #List do
        if Player:Buff(RtB_BuffsList[List[i]]) then
          Count = Count + 1;
        end
      end
      Cache.APLVar.RtB_List[Type][Sequence] = Count == #List and true or false;
    end
  -- Any
  else
    if not Cache.APLVar.RtB_List[Type][Sequence] then
      Cache.APLVar.RtB_List[Type][Sequence] = false;
      for i = 1, #List do
        if Player:Buff(RtB_BuffsList[List[i]]) then
          Cache.APLVar.RtB_List[Type][Sequence] = true;
          break;
        end
      end
    end
  end
  return Cache.APLVar.RtB_List[Type][Sequence];
end
local function RtB_BuffRemains ()
  if not Cache.APLVar.RtB_BuffRemains then
    Cache.APLVar.RtB_BuffRemains = 0;
    for i = 1, #RtB_BuffsList do
      if Player:Buff(RtB_BuffsList[i]) then
        Cache.APLVar.RtB_BuffRemains = Player:BuffRemainsP(RtB_BuffsList[i]);
        break;
      end
    end
  end
  return Cache.APLVar.RtB_BuffRemains;
end
-- Get the number of Roll the Bones buffs currently on
local function RtB_Buffs ()
  if not Cache.APLVar.RtB_Buffs then
    Cache.APLVar.RtB_Buffs = 0;
    for i = 1, #RtB_BuffsList do
      if Player:BuffP(RtB_BuffsList[i]) then
        Cache.APLVar.RtB_Buffs = Cache.APLVar.RtB_Buffs + 1;
      end
    end
  end
  return Cache.APLVar.RtB_Buffs;
end
-- # Reroll when Loaded Dice is up and if you have less than 2 buffs or less than 4 and no True Bearing. With SnD, consider that we never have to reroll.
local function RtB_Reroll ()
  if not Cache.APLVar.RtB_Reroll then
    -- Defensive Override : Grand Melee if HP < 60
    if Settings.General.SoloMode and Player:HealthPercentage() < Settings.Outlaw.RolltheBonesLeechHP then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.GrandMelee)) and true or false;
    -- 1+ Buff
    elseif Settings.Outlaw.RolltheBonesLogic == "1+ Buff" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and RtB_Buffs() <= 0) and true or false;
    -- Broadsides
    elseif Settings.Outlaw.RolltheBonesLogic == "Broadsides" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.Broadsides)) and true or false;
    -- Buried Treasure
    elseif Settings.Outlaw.RolltheBonesLogic == "Buried Treasure" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.BuriedTreasure)) and true or false;
    -- Grand Melee
    elseif Settings.Outlaw.RolltheBonesLogic == "Grand Melee" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.GrandMelee)) and true or false;
    -- Jolly Roger
    elseif Settings.Outlaw.RolltheBonesLogic == "Jolly Roger" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.JollyRoger)) and true or false;
    -- Shark Infested Waters
    elseif Settings.Outlaw.RolltheBonesLogic == "Shark Infested Waters" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.SharkInfestedWaters)) and true or false;
    -- True Bearing
    elseif Settings.Outlaw.RolltheBonesLogic == "True Bearing" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:BuffP(S.TrueBearing)) and true or false;
    -- SimC Default
    -- actions=variable,name=rtb_reroll,value=!talent.slice_and_dice.enabled&buff.loaded_dice.up&(rtb_buffs<2|(rtb_buffs<4&!buff.true_bearing.up))
    else
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and Player:BuffP(S.LoadedDice) and
        (RtB_Buffs() < 2 or (RtB_Buffs() < 4 and not Player:BuffP(S.TrueBearing)))) and true or false;
    end
  end
  return Cache.APLVar.RtB_Reroll;
end
-- # Condition to use Saber Slash when not rerolling RtB or when using SnD
local function SS_Useable_NoReroll ()
  -- actions+=/variable,name=ss_useable_noreroll,value=(combo_points<4+talent.deeper_stratagem.enabled)
  if not Cache.APLVar.SS_Useable_NoReroll then
    Cache.APLVar.SS_Useable_NoReroll = (Player:ComboPoints() < (4 + (S.DeeperStratagem:IsAvailable() and 1 or 0))) and true or false;
  end
  return Cache.APLVar.SS_Useable_NoReroll;
end
-- # Condition to use Saber Slash, when you have RtB or not
local function SS_Useable ()
  -- actions+=/variable,name=ss_useable,value=(talent.anticipation.enabled&combo_points<5)|(!talent.anticipation.enabled&((variable.rtb_reroll&combo_points<4+talent.deeper_stratagem.enabled)|(!variable.rtb_reroll&variable.ss_useable_noreroll)))
  if not Cache.APLVar.SS_Useable then
    Cache.APLVar.SS_Useable = ((S.Anticipation:IsAvailable() and Player:ComboPoints() < 5)
      or (not S.Anticipation:IsAvailable() and ((RtB_Reroll() and Player:ComboPoints() < 4+(S.DeeperStratagem:IsAvailable() and 1 or 0))
        or (not RtB_Reroll() and SS_Useable_NoReroll())))) and true or false;
  end
  return Cache.APLVar.SS_Useable;
end

local function EnergyTimeToMaxRounded ()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10;
end

local function MythicDungeon ()
  -- Sapped Soul
  if AC.MythicDungeon() == "Sapped Soul" then
    for i = 1, #SappedSoulSpells do
      if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
        AR.ChangePulseTimer(1);
        AR.Cast(SappedSoulSpells[i][1]);
        return SappedSoulSpells[i][2];
      end
    end
  end
end

local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
    -- Between the Eyes
    if S.BetweentheEyes:IsCastable(20) and Player:ComboPoints() > 0 then
      if AR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (Training Scenario)"; end
    end
  end
end

local function BladeFlurry ()
  -- Blade Flurry Expiration Offset
  if Cache.EnemiesCount[RTIdentifier] == 1 and BFReset then
    BFTimer, BFReset = AC.GetTime() + Settings.Outlaw.BFOffset, false;
  elseif Cache.EnemiesCount[RTIdentifier] > 1 then
    BFReset = true;
  end

  if Player:Buff(S.BladeFlurry) then
    -- actions.bf=cancel_buff,name=blade_flurry,if=spell_targets.blade_flurry<2&buff.blade_flurry.up
    if Cache.EnemiesCount[RTIdentifier] < 2 and AC.GetTime() > BFTimer then
      if AR.Cast(S.BladeFlurry2, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cancel Blade Flurry"; end
    end
    -- actions.bf+=/cancel_buff,name=blade_flurry,if=equipped.shivarran_symmetry&cooldown.blade_flurry.up&buff.blade_flurry.up&spell_targets.blade_flurry>=2
    if I.ShivarranSymmetry:IsEquipped() and S.BladeFlurry:CooldownUp() and Cache.EnemiesCount[RTIdentifier] >= 2 then
      if AR.Cast(S.BladeFlurry2, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cancel Blade Flurry (Shivarran Symmetry)"; end
    end
  else
    -- actions.bf+=/blade_flurry,if=spell_targets.blade_flurry>=2&!buff.blade_flurry.up
    if S.BladeFlurry:IsCastable() and Cache.EnemiesCount[RTIdentifier] >= 2 then
      if AR.Cast(S.BladeFlurry, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cast Blade Flurry"; end
    end
  end
end

local function CDs ()
  if AR.CDsON() then
    -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|buff.adrenaline_rush.up
    -- TODO: Add Potion
    -- actions.cds+=/use_item,if=buff.bloodlust.react|target.time_to_die<=20|combo_points.deficit<=2
    -- TODO: Add Items
    -- actions.cds+=/cannonball_barrage,if=spell_targets.cannonball_barrage>=1
    if AR.AoEON() and S.CannonballBarrage:IsCastable() and Cache.EnemiesCount[8] >= 1 then
      if AR.Cast(S.CannonballBarrage) then return "Cast Cannonball Barrage"; end
    end
  end
  if Target:IsInRange(S.SaberSlash) then
    if AR.CDsON() then
      -- actions.cds+=/blood_fury
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
      end
      -- actions.cds+=/berserking
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
      end
      -- actions.cds+=/arcane_torrent,if=energy.deficit>40
      if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficitPredicted() > 40 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
      end
      -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&energy.deficit>0
      if S.AdrenalineRush:IsCastable() and not Player:BuffP(S.AdrenalineRush) and Player:EnergyDeficitPredicted() > 0 then
        if AR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush"; end
      end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
    if S.MarkedforDeath:IsCastable() then
      -- Note: Increased the SimC condition by 50% since we are slower.
      if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()*1.5) or (Target:FilteredTimeToDie("<", 2) and Player:ComboPointsDeficit() > 0)
        or (((Cache.EnemiesCount[30] == 1 and Player:BuffRemainsP(S.TrueBearing) > 15 - (Player:BuffP(S.AdrenalineRush) and 5 or 0))
          or Target:IsDummy()) and not Player:IsStealthed(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1) then
        if AR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death"; end
      elseif not Player:IsStealthed(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1 then
        AR.CastSuggested(S.MarkedforDeath);
      end
    end
    if AR.CDsON() then
      if I.ThraxisTricksyTreads:IsEquipped() and not SS_Useable() then
        -- actions.cds+=/sprint,if=!talent.death_from_above.enabled&equipped.thraxis_tricksy_treads&!variable.ss_useable
        if S.Sprint:IsCastable() and not S.DeathfromAbove:IsAvailable() then
          AR.CastSuggested(S.Sprint);
        end
        -- actions.cds+=/darkflight,if=equipped.thraxis_tricksy_treads&!variable.ss_useable&buff.sprint.down
        if S.Darkflight:IsCastable() and not Player:BuffP(S.Sprint) then
          AR.CastSuggested(S.Darkflight);
        end
      end
      -- actions.cds+=/curse_of_the_dreadblades,if=combo_points.deficit>=4&(buff.true_bearing.up|buff.adrenaline_rush.up|time_to_die<20)
      if S.CurseoftheDreadblades:IsCastable() and Player:ComboPointsDeficit() >= 4 and
        (Player:BuffP(S.TrueBearing) or Player:BuffP(S.AdrenalineRush) or Target:FilteredTimeToDie("<", 20)) then
        if AR.Cast(S.CurseoftheDreadblades, Settings.Outlaw.OffGCDasOffGCD.CurseoftheDreadblades) then return "Cast Curse of the Dreadblades"; end
      end
    end
  end
end

local function Stealth ()
  if Target:IsInRange(S.SaberSlash) then
    -- actions.stealth=variable,name=ambush_condition,value=combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&!debuff.ghostly_strike.up)+buff.broadsides.up&energy>60&!buff.jolly_roger.up&!buff.hidden_blade.up
    local Ambush_Condition = (Player:ComboPointsDeficit() >= 2+2*((S.GhostlyStrike:IsAvailable() and not Target:Debuff(S.GhostlyStrike)) and 1 or 0)
      + (Player:Buff(S.Broadsides) and 1 or 0) and Player:EnergyPredicted() > 60 and not Player:Buff(S.JollyRoger) and not Player:Buff(S.HiddenBlade)) and true or false;
    -- actions.stealth+=/ambush,if=variable.ambush_condition
    if Player:IsStealthed(true, true) and S.Ambush:IsCastable() and Ambush_Condition then
      if AR.Cast(S.Ambush) then return "Cast Ambush"; end
    else
      if AR.CDsON() and not Player:IsTanking(Target) then
        -- actions.stealth+=/vanish,if=(variable.ambush_condition|equipped.mantle_of_the_master_assassin&!variable.rtb_reroll&!variable.ss_useable)&mantle_duration=0
        if S.Vanish:IsCastable() and (Ambush_Condition or (I.MantleoftheMasterAssassin:IsEquipped() and not RtB_Reroll() and not SS_Useable()))
          and Rogue.MantleDuration() == 0 then
          if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish"; end
        end
        -- actions.stealth+=/shadowmeld,if=variable.ambush_condition
        if S.Shadowmeld:IsCastable() and Ambush_Condition then
          if AR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld"; end
        end
      end
    end
  end
end

local function Build ()
  -- actions.build=ghostly_strike,if=combo_points.deficit>=1+buff.broadsides.up&refreshable
  if S.GhostlyStrike:IsCastable(S.SaberSlash)
    and Player:ComboPointsDeficit() >= (1+(Player:BuffP(S.Broadsides) and 1 or 0)) and Target:DebuffRefreshableP(S.GhostlyStrike, 4.5) then
  if AR.Cast(S.GhostlyStrike) then return "Cast Ghostly Strike"; end
  end
  -- actions.build+=/pistol_shot,if=combo_points.deficit>=1+buff.broadsides.up+talent.quick_draw.enabled&buff.opportunity.up&(energy.time_to_max>2-talent.quick_draw.enabled|(buff.greenskins_waterlogged_wristcuffs.up&(buff.blunderbuss.up|buff.greenskins_waterlogged_wristcuffs.remains<2)))
  if (S.PistolShot:IsCastable(20) or S.Blunderbuss:IsCastable(20))
    and Player:ComboPointsDeficit() >= (1+(Player:BuffP(S.Broadsides) and 1 or 0)+(S.QuickDraw:IsAvailable() and 1 or 0))
    and Player:BuffP(S.Opportunity) and (EnergyTimeToMaxRounded() > (2-(S.QuickDraw:IsAvailable() and 1 or 0))
      or (Player:BuffP(S.GreenskinsWaterloggedWristcuffs) and (S.Blunderbuss:IsCastable() or Player:BuffRemainsP(S.GreenskinsWaterloggedWristcuffs) < 2))) then
  if AR.Cast(S.PistolShot) then return "Cast Pistol Shot"; end
  end
  -- actions.build+=/saber_slash,if=variable.ss_useable
  if S.SaberSlash:IsCastable(S.SaberSlash) and SS_Useable() then
  if AR.Cast(S.SaberSlash) then return "Cast Saber Slash"; end
  end
end

local function Finish ()
  -- # BTE in mantle used to be DPS neutral but is a loss due to t21
  -- actions.finish=between_the_eyes,if=equipped.greenskins_waterlogged_wristcuffs&!buff.greenskins_waterlogged_wristcuffs.up
  if S.BetweentheEyes:IsCastable(20) and I.GreenskinsWaterloggedWristcuffs:IsEquipped() and not Player:BuffP(S.GreenskinsWaterloggedWristcuffs) then
    if AR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes"; end
  end
  -- actions.finish+=/run_through,if=!talent.death_from_above.enabled|energy.time_to_max<cooldown.death_from_above.remains+3.5
  if S.RunThrough:IsCastable(S.RunThrough) and (not S.DeathfromAbove:IsAvailable()
    or EnergyTimeToMaxRounded() < S.DeathfromAbove:CooldownRemainsP() + 3.5) then
    if AR.Cast(S.RunThrough) then return "Cast Run Through"; end
  end
  -- OutofRange BtE
  if S.BetweentheEyes:IsCastable(20) and not Target:IsInRange(10) then
    if AR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (OOR)"; end
  end
end

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(8); -- Cannonball Barrage
  AC.GetEnemies(S.RunThrough); -- Blade Flurry
  AC.GetEnemies(S.SaberSlash); -- Melee
  Everyone.AoEToggleEnemiesUpdate();

  -- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial(S.CrimsonVial);
  if ShouldReturn then return ShouldReturn; end
  -- Feint
  ShouldReturn = Rogue.Feint(S.Feint);
  if ShouldReturn then return ShouldReturn; end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    if not Player:Buff(S.VanishBuff) then
      ShouldReturn = Rogue.Stealth(S.Stealth);
      if ShouldReturn then return ShouldReturn; end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and Target:IsInRange(S.SaberSlash) then
      if Player:ComboPoints() >= 5 then
        if S.RunThrough:IsCastable() then
          if AR.Cast(S.RunThrough) then return "Cast Run Through (Opener)"; end
        end
      else
        -- actions.precombat+=/curse_of_the_dreadblades,if=combo_points.deficit>=4
        if AR.CDsON() and S.CurseoftheDreadblades:IsCastable() and Player:ComboPointsDeficit() >= 4 then
          if AR.Cast(S.CurseoftheDreadblades, Settings.Outlaw.OffGCDasOffGCD.CurseoftheDreadblades) then 
            return "Cast Curse of the Dreadblades (Opener)";
          end
        end
        if Player:IsStealthed(true, true) and S.Ambush:IsCastable() then
          if AR.Cast(S.Ambush) then return "Cast Ambush (Opener)"; end
        elseif S.SaberSlash:IsCastable() then
          if AR.Cast(S.SaberSlash) then return "Cast Saber Slash (Opener)"; end
        end
      end
    end
    return;
  end

  -- In Combat
  -- MfD Sniping
  Rogue.MfDSniping(S.MarkedforDeath);
  if Everyone.TargetIsValid() then
    -- Mythic Dungeon
    ShouldReturn = MythicDungeon();
    if ShouldReturn then return ShouldReturn; end
    -- Training Scenario
    ShouldReturn = TrainingScenario();
    if ShouldReturn then return ShouldReturn; end
    -- Kick
    if Settings.General.InterruptEnabled and S.Kick:IsCastable(S.SaberSlash) and Target:IsInterruptible() then
      if AR.Cast(S.Kick, Settings.Commons.OffGCDasOffGCD.Kick) then return "Cast Kick"; end
    end

    -- actions+=/call_action_list,name=bf
    ShouldReturn = BladeFlurry();
    if ShouldReturn then return "BladeFlurry: " .. ShouldReturn; end
    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs();
    if ShouldReturn then return "CDs: " .. ShouldReturn; end
    -- # Conditions are here to avoid worthless check if nothing is available
    -- actions+=/call_action_list,name=stealth,if=stealthed|cooldown.vanish.up|cooldown.shadowmeld.up
    if Player:IsStealthed(true, true) or S.Vanish:IsCastable() or S.Shadowmeld:IsCastable() then
      ShouldReturn = Stealth();
      if ShouldReturn then return "Stealth: " .. ShouldReturn; end
    end
    -- actions+=/death_from_above,if=energy.time_to_max>2&!variable.ss_useable_noreroll
    if S.DeathfromAbove:IsCastable(15) and not SS_Useable_NoReroll() and EnergyTimeToMaxRounded() > 2 then
      if AR.Cast(S.DeathfromAbove) then return "Cast Death from above"; end
    end
    -- Note: DfA execute time is 1.475s, the buff is modeled to lasts 1.475s on SimC, while it's 1s in-game. So we retrieve it from TimeSinceLastCast.
    if S.DeathfromAbove:TimeSinceLastCast() <= 1.325 then
      -- actions+=/sprint,if=equipped.thraxis_tricksy_treads&buff.death_from_above.up&buff.death_from_above.remains<=0.15
      if S.Sprint:IsCastable() and I.ThraxisTricksyTreads:IsEquipped() then
        if AR.Cast(S.Sprint) then
          -- Set the cooldown on the main frame to be equal to the delay we actually want, not the full GCD duration
          AR.MainIconFrame:SetCooldown(S.DeathfromAbove.LastCastTime, 1.325);
          return "Cast Sprint (DfA)";
        end
      end
      -- actions+=/adrenaline_rush,if=buff.death_from_above.up&buff.death_from_above.remains<=0.15
      if S.AdrenalineRush:IsCastable() then
        if AR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
          -- Set the cooldown on the main frame to be equal to the delay we actually want, not the full GCD duration
          AR.MainIconFrame:SetCooldown(S.DeathfromAbove.LastCastTime, 1.325);
          return "Cast Adrenaline Rush (DfA)";
        end
      end
    end
    if S.SliceandDice:IsAvailable() and S.SliceandDice:IsCastable() then
      -- actions+=/slice_and_dice,if=!variable.ss_useable&buff.slice_and_dice.remains<target.time_to_die&buff.slice_and_dice.remains<(1+combo_points)*1.8&!buff.slice_and_dice.improved&!buff.loaded_dice.up
      -- Note: Added Player:BuffRemainsP(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
      if not SS_Useable() and (Target:FilteredTimeToDie(">", Player:BuffRemainsP(S.SliceandDice)) or Player:BuffRemainsP(S.SliceandDice) == 0)
        and Player:BuffRemainsP(S.SliceandDice) < (1+Player:ComboPoints())*1.8 and not ImprovedSliceAndDice() and not Player:Buff(S.LoadedDice) then
        if AR.Cast(S.SliceandDice) then return "Cast Slice and Dice 1"; end
      end
      -- actions+=/slice_and_dice,if=buff.loaded_dice.up&combo_points>=cp_max_spend&(!buff.slice_and_dice.improved|buff.slice_and_dice.remains<4)
      if Player:Buff(S.LoadedDice) and Player:ComboPoints() >= Rogue.CPMaxSpend()
        and (not ImprovedSliceAndDice() or Player:BuffRemainsP(S.SliceandDice) < 4) then
        if AR.Cast(S.SliceandDice) then return "Cast Slice and Dice 2"; end
      end
      -- actions+=/slice_and_dice,if=buff.slice_and_dice.improved&buff.slice_and_dice.remains<=2&combo_points>=2&!buff.loaded_dice.up
      if ImprovedSliceAndDice() and Player:BuffRemainsP(S.SliceandDice) <= 2 and Player:ComboPoints() >= 2 and not Player:Buff(S.LoadedDice) then
        if AR.Cast(S.SliceandDice) then return "Cast Slice and Dice 3"; end
      end
    end
    -- actions+=/roll_the_bones,if=!variable.ss_useable&(target.time_to_die>20|buff.roll_the_bones.remains<target.time_to_die)&(buff.roll_the_bones.remains<=3|variable.rtb_reroll)
    -- Note: Added RtB_BuffRemains() == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
    if S.RolltheBones:IsCastable() and not SS_Useable() and (Target:FilteredTimeToDie(">", 20)
      or Target:FilteredTimeToDie(">", RtB_BuffRemains()) or RtB_BuffRemains() == 0) and (RtB_BuffRemains() <= 3 or RtB_Reroll()) then
      if AR.Cast(S.RolltheBones) then return "Cast Roll the Bones"; end
    end
    -- actions+=/killing_spree,if=energy.time_to_max>5|energy<15
    if AR.CDsON() and S.KillingSpree:IsCastable(10) and (EnergyTimeToMaxRounded() > 5 or Player:EnergyPredicted() < 15) then
      if AR.Cast(S.KillingSpree) then return "Cast Killing Spree"; end
    end
    -- actions+=/call_action_list,name=build
    ShouldReturn = Build();
    if ShouldReturn then return "Build: " .. ShouldReturn; end
    -- actions+=/call_action_list,name=finish,if=!variable.ss_useable
    if not SS_Useable() then
      ShouldReturn = Finish();
      if ShouldReturn then return "Finish: " .. ShouldReturn; end
    end
    -- # Gouge is used as a CP Generator while nothing else is available and you have Dirty Tricks talent. It's unlikely that you'll be able to do this optimally in-game since it requires to move in front of the target, but it's here so you can quantifiy its value.
    -- actions+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1
    if S.Gouge:IsCastable(S.SaberSlash) and S.DirtyTricks:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
      if AR.Cast(S.Gouge) then return "Cast Gouge (Dirty Tricks)"; end
    end
    -- OutofRange Pistol Shot
    if not Target:IsInRange(10) and (S.PistolShot:IsCastable(20) or S.Blunderbuss:IsCastable(20)) and not Player:IsStealthed(true, true)
      and Player:EnergyDeficitPredicted() < 25 and (Player:ComboPointsDeficit() >= 1 or EnergyTimeToMaxRounded() <= 1.2) then
      if AR.Cast(S.PistolShot) then return "Cast Pistol Shot (OOR)"; end
    end
  end
end

AR.SetAPL(260, APL);

-- Last Update: 12/05/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/stealth
-- actions.precombat+=/potion
-- actions.precombat+=/marked_for_death,if=raid_event.adds.in>40
-- actions.precombat+=/roll_the_bones,if=!talent.slice_and_dice.enabled
-- actions.precombat+=/curse_of_the_dreadblades,if=combo_points.deficit>=4

-- # Executed every time the actor is available.
-- # Reroll when Loaded Dice is up and if you have less than 2 buffs or less than 4 and no True Bearing. With SnD, consider that we never have to reroll.
-- actions=variable,name=rtb_reroll,value=!talent.slice_and_dice.enabled&buff.loaded_dice.up&(rtb_buffs<2|(rtb_buffs<4&!buff.true_bearing.up))
-- # Condition to use Saber Slash when not rerolling RtB or when using SnD
-- actions+=/variable,name=ss_useable_noreroll,value=(combo_points<4+talent.deeper_stratagem.enabled)
-- # Condition to use Saber Slash, when you have RtB or not
-- actions+=/variable,name=ss_useable,value=(talent.anticipation.enabled&combo_points<5)|(!talent.anticipation.enabled&((variable.rtb_reroll&combo_points<4+talent.deeper_stratagem.enabled)|(!variable.rtb_reroll&variable.ss_useable_noreroll)))
-- # Normal rotation
-- actions+=/call_action_list,name=bf
-- actions+=/call_action_list,name=cds
-- # Conditions are here to avoid worthless check if nothing is available
-- actions+=/call_action_list,name=stealth,if=stealthed.rogue|cooldown.vanish.up|cooldown.shadowmeld.up
-- actions+=/death_from_above,if=energy.time_to_max>2&!variable.ss_useable_noreroll
-- actions+=/sprint,if=equipped.thraxis_tricksy_treads&buff.death_from_above.up&buff.death_from_above.remains<=0.15
-- actions+=/adrenaline_rush,if=buff.death_from_above.up&buff.death_from_above.remains<=0.15
-- actions+=/slice_and_dice,if=!variable.ss_useable&buff.slice_and_dice.remains<target.time_to_die&buff.slice_and_dice.remains<(1+combo_points)*1.8&!buff.slice_and_dice.improved&!buff.loaded_dice.up
-- actions+=/slice_and_dice,if=buff.loaded_dice.up&combo_points>=cp_max_spend&(!buff.slice_and_dice.improved|buff.slice_and_dice.remains<4)
-- actions+=/slice_and_dice,if=buff.slice_and_dice.improved&buff.slice_and_dice.remains<=2&combo_points>=2&!buff.loaded_dice.up
-- actions+=/roll_the_bones,if=!variable.ss_useable&(target.time_to_die>20|buff.roll_the_bones.remains<target.time_to_die)&(buff.roll_the_bones.remains<=3|variable.rtb_reroll)
-- actions+=/killing_spree,if=energy.time_to_max>5|energy<15
-- actions+=/call_action_list,name=build
-- actions+=/call_action_list,name=finish,if=!variable.ss_useable
-- # Gouge is used as a CP Generator while nothing else is available and you have Dirty Tricks talent. It's unlikely that you'll be able to do this optimally in-game since it requires to move in front of the target, but it's here so you can quantifiy its value.
-- actions+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1

-- # Blade Flurry
-- actions.bf=cancel_buff,name=blade_flurry,if=spell_targets.blade_flurry<2&buff.blade_flurry.up
-- actions.bf+=/cancel_buff,name=blade_flurry,if=equipped.shivarran_symmetry&cooldown.blade_flurry.up&buff.blade_flurry.up&spell_targets.blade_flurry>=2
-- actions.bf+=/blade_flurry,if=spell_targets.blade_flurry>=2&!buff.blade_flurry.up

-- # Builders
-- actions.build=ghostly_strike,if=combo_points.deficit>=1+buff.broadsides.up&refreshable
-- actions.build+=/pistol_shot,if=combo_points.deficit>=1+buff.broadsides.up+talent.quick_draw.enabled&buff.opportunity.up&(energy.time_to_max>2-talent.quick_draw.enabled|(buff.greenskins_waterlogged_wristcuffs.up&(buff.blunderbuss.up|buff.greenskins_waterlogged_wristcuffs.remains<2)))
-- actions.build+=/saber_slash,if=variable.ss_useable

-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|buff.adrenaline_rush.up
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/arcane_torrent,if=energy.deficit>40
-- actions.cds+=/cannonball_barrage,if=spell_targets.cannonball_barrage>=1
-- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&energy.deficit>0
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
-- actions.cds+=/sprint,if=!talent.death_from_above.enabled&equipped.thraxis_tricksy_treads&!variable.ss_useable
-- actions.cds+=/darkflight,if=equipped.thraxis_tricksy_treads&!variable.ss_useable&buff.sprint.down
-- actions.cds+=/curse_of_the_dreadblades,if=combo_points.deficit>=4&(buff.true_bearing.up|buff.adrenaline_rush.up|time_to_die<20)

-- # Finishers
-- # BTE in mantle used to be DPS neutral but is a loss due to t21
-- actions.finish=between_the_eyes,if=equipped.greenskins_waterlogged_wristcuffs&!buff.greenskins_waterlogged_wristcuffs.up
-- actions.finish+=/run_through,if=!talent.death_from_above.enabled|energy.time_to_max<cooldown.death_from_above.remains+3.5

-- # Stealth
-- actions.stealth=variable,name=ambush_condition,value=combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&!debuff.ghostly_strike.up)+buff.broadsides.up&energy>60&!buff.jolly_roger.up&!buff.hidden_blade.up
-- actions.stealth+=/ambush,if=variable.ambush_condition
-- actions.stealth+=/vanish,if=(variable.ambush_condition|equipped.mantle_of_the_master_assassin&!variable.rtb_reroll&!variable.ss_useable)&mantle_duration=0
-- actions.stealth+=/shadowmeld,if=variable.ambush_condition

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
  {S.Kick, "Cast Kick (Sappel Soul)", function () return Target:IsInRange(S.SaberSlash, SSIdentifier); end},
  {S.Feint, "Cast Feint (Sappel Soul)", function () return true; end},
  {S.CrimsonVial, "Cast Crimson Vial (Sappel Soul)", function () return true; end}
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
        Cache.APLVar.RtB_BuffRemains = Player:BuffRemains(RtB_BuffsList[i]);
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
      if Player:Buff(RtB_BuffsList[i]) then
        Cache.APLVar.RtB_Buffs = Cache.APLVar.RtB_Buffs + 1;
      end
    end
  end
  return Cache.APLVar.RtB_Buffs;
end
-- # Fish for '2 Buffs' when Loaded Dice is up. Also try to get TB with Loaded Dice and 2 other buffs up. With SnD, consider that we never have to reroll.
local function RtB_Reroll ()
  -- actions=variable,name=rtb_reroll,value=!talent.slice_and_dice.enabled&buff.loaded_dice.up&(rtb_buffs<2|rtb_buffs=2&!buff.true_bearing.up)
  if not Cache.APLVar.RtB_Reroll then
    -- Defensive Override : Grand Melee if HP < 60
    if Settings.General.SoloMode and Player:HealthPercentage() < Settings.Outlaw.RolltheBonesLeechHP then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.GrandMelee)) and true or false;
    -- 1+ Buff
    elseif Settings.Outlaw.RolltheBonesLogic == "1+ Buff" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and RtB_Buffs() <= 0) and true or false;
    -- Broadsides
    elseif Settings.Outlaw.RolltheBonesLogic == "Broadsides" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.Broadsides)) and true or false;
    -- Buried Treasure
    elseif Settings.Outlaw.RolltheBonesLogic == "Buried Treasure" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.BuriedTreasure)) and true or false;
    -- Grand Melee
    elseif Settings.Outlaw.RolltheBonesLogic == "Grand Melee" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.GrandMelee)) and true or false;
    -- Jolly Roger
    elseif Settings.Outlaw.RolltheBonesLogic == "Jolly Roger" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.JollyRoger)) and true or false;
    -- Shark Infested Waters
    elseif Settings.Outlaw.RolltheBonesLogic == "Shark Infested Waters" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.SharkInfestedWaters)) and true or false;
    -- True Bearing
    elseif Settings.Outlaw.RolltheBonesLogic == "True Bearing" then
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and not Player:Buff(S.TrueBearing)) and true or false;
    -- SimC Default
    else
      Cache.APLVar.RtB_Reroll = (not S.SliceandDice:IsAvailable() and Player:Buff(S.LoadedDice) and (RtB_Buffs() < 2 or not Player:Buff(S.TrueBearing))) and true or false;
    end
  end
  return Cache.APLVar.RtB_Reroll;
end
-- # Condition to use Saber Slash when not rerolling RtB or when using SnD
local function SS_Useable_NoReroll ()
  -- actions+=/variable,name=ss_useable_noreroll,value=(combo_points<5+talent.deeper_stratagem.enabled-(buff.broadsides.up|buff.jolly_roger.up)-(talent.alacrity.enabled&buff.alacrity.stack<=4))
  if not Cache.APLVar.SS_Useable_NoReroll then
    Cache.APLVar.SS_Useable_NoReroll = (Player:ComboPoints() < 5+(S.DeeperStratagem:IsAvailable() and 1 or 0)-((Player:Buff(S.Broadsides) or Player:Buff(S.JollyRoger)) and 1 or 0)-((S.Alacrity:IsAvailable() and Player:BuffStack(S.AlacrityBuff) <= 4) and 1 or 0)) and true or false;
  end
  return Cache.APLVar.SS_Useable_NoReroll;
end
-- # Condition to use Saber Slash, when you have RtB or not
local function SS_Useable ()
  -- actions+=/variable,name=ss_useable,value=(talent.anticipation.enabled&combo_points<5)|(!talent.anticipation.enabled&((variable.rtb_reroll&combo_points<4+talent.deeper_stratagem.enabled)|(!variable.rtb_reroll&variable.ss_useable_noreroll)))
  if not Cache.APLVar.SS_Useable then
    Cache.APLVar.SS_Useable = ((S.Anticipation:IsAvailable() and Player:ComboPoints() < 5) or (not S.Anticipation:IsAvailable() and ((RtB_Reroll() and Player:ComboPoints() < 4+(S.DeeperStratagem:IsAvailable() and 1 or 0)) or (not RtB_Reroll() and SS_Useable_NoReroll())))) and true or false;
  end
  return Cache.APLVar.SS_Useable;
end

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(8); -- Cannonball Barrage
  AC.GetEnemies(S.RunThrough, RTIdentifier); -- Blade Flurry
  AC.GetEnemies(S.SaberSlash, SSIdentifier); -- Melee
  Everyone.AoEToggleEnemiesUpdate();
  -- Defensives
    -- Crimson Vial
    ShouldReturn = Rogue.CrimsonVial (S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = Rogue.Feint (S.Feint);
    if ShouldReturn then return ShouldReturn; end
  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    ShouldReturn = Rogue.Stealth(S.Stealth);
    if ShouldReturn then return ShouldReturn; end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and Target:IsInRange(S.SaberSlash, SSIdentifier) then
      if Player:ComboPoints() >= 5 then
        if S.RunThrough:IsCastable() then
          if AR.Cast(S.RunThrough) then return "Cast Run Through (Opener)"; end
        end
      else
        -- actions.precombat+=/curse_of_the_dreadblades,if=combo_points.deficit>=4
        if AR.CDsON() and S.CurseoftheDreadblades:IsCastable() and Player:ComboPointsDeficit() >= 4 then
          if AR.Cast(S.CurseoftheDreadblades, Settings.Outlaw.OffGCDasOffGCD.CurseoftheDreadblades) then return "Cast Curse of the Dreadblades (Opener)"; end
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
      -- Training Scenario
        if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
          -- Between the Eyes
          if S.BetweentheEyes:IsCastable() and Target:IsInRange(20) and Player:ComboPoints() > 0 then
            if AR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (Training Scenario)"; end
          end
        end
      -- Kick
      if Settings.General.InterruptEnabled and Target:IsInRange(S.SaberSlash, SSIdentifier) and S.Kick:IsCastable() and Target:IsInterruptible() then
        if AR.Cast(S.Kick, Settings.Commons.OffGCDasOffGCD.Kick) then return "Cast Kick"; end
      end
      -- Blade Flurry Expiration Offset
      if Cache.EnemiesCount[RTIdentifier] == 1 and BFReset then
        BFTimer, BFReset = AC.GetTime() + Settings.Outlaw.BFOffset, false;
      elseif Cache.EnemiesCount[RTIdentifier] > 1 then
        BFReset = true;
      end
      -- actions+=/call_action_list,name=bf
        if Player:Buff(S.BladeFlurry) then
          -- actions.bf=cancel_buff,name=blade_flurry,if=spell_targets.blade_flurry<2&buff.blade_flurry.up
          if Cache.EnemiesCount[RTIdentifier] < 2 and AC.GetTime() > BFTimer then
            if AR.Cast(S.BladeFlurry2, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cast"; end
          end
          -- actions.bf+=/cancel_buff,name=blade_flurry,if=equipped.shivarran_symmetry&cooldown.blade_flurry.up&buff.blade_flurry.up&spell_targets.blade_flurry>=2
          if I.ShivarranSymmetry:IsEquipped() and S.BladeFlurry:CooldownUp() and Cache.EnemiesCount[RTIdentifier] >= 2 then
            if AR.Cast(S.BladeFlurry2, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cast"; end
          end
        end
        -- actions.bf+=/blade_flurry,if=spell_targets.blade_flurry>=2&!buff.blade_flurry.up
        if S.BladeFlurry:IsCastable() and not Player:Buff(S.BladeFlurry) and Cache.EnemiesCount[RTIdentifier] >= 2 then
          if AR.Cast(S.BladeFlurry, Settings.Outlaw.OffGCDasOffGCD.BladeFlurry) then return "Cast"; end
        end
      -- actions+=/call_action_list,name=cds
        if AR.CDsON() then
          -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=25|buff.adrenaline_rush.up
          -- TODO: Add Potion
          -- actions.cds+=/use_item,if=buff.bloodlust.react|target.time_to_die<=20|combo_points.deficit<=2
          -- TODO: Add Items
          -- actions.cds+=/cannonball_barrage,if=spell_targets.cannonball_barrage>=1
          if AR.AoEON() and S.CannonballBarrage:IsCastable() and Cache.EnemiesCount[8] >= 1 then
            if AR.Cast(S.CannonballBarrage) then return "Cast Cannonball Barrage"; end
          end
        end
        if Target:IsInRange(S.SaberSlash, SSIdentifier) then
          if AR.CDsON() then
            -- actions.cds+=/blood_fury
            if S.BloodFury:IsCastable() then
              if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
            end
            -- actions.cds+=/berserking
            if S.Berserking:IsCastable() then
              if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
            end
            -- actions.cds+=/arcane_torrent,if=energy.deficit>40
            if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 40 then
              if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
            end
            -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&energy.deficit>0
            if S.AdrenalineRush:IsCastable() and not Player:Buff(S.AdrenalineRush) and Player:EnergyDeficit() > 0 then
              if AR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast"; end
            end
          end
          -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
          if S.MarkedforDeath:IsCastable() then
            -- Note: Increased the SimC condition by 50% since we are slower.
            if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit()*1.5) or (Target:FilteredTimeToDie("<", 2) and Player:ComboPointsDeficit() > 0) or (((Cache.EnemiesCount[30] == 1 and Player:BuffRemains(S.TrueBearing) > 15 - (Player:Buff(S.AdrenalineRush) and 5 or 0)) or Target:IsDummy()) and not Player:IsStealthed(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1) then
              if AR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast"; end
            elseif not Player:IsStealthed(true, true) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1 then
              AR.CastSuggested(S.MarkedforDeath);
            end
          end
          if AR.CDsON() then
            if I.ThraxisTricksyTreads:IsEquipped() and not SS_Useable() then
              -- actions.cds+=/sprint,if=equipped.thraxis_tricksy_treads&!variable.ss_useable
              if S.Sprint:IsCastable() then
                AR.CastSuggested(S.Sprint);
              end
              -- actions.cds+=/darkflight,if=equipped.thraxis_tricksy_treads&!variable.ss_useable&buff.sprint.down
              if S.Darkflight:IsCastable() and not Player:Buff(S.Sprint) then
                AR.CastSuggested(S.Darkflight);
              end
            end
            -- actions.cds+=/curse_of_the_dreadblades,if=combo_points.deficit>=4&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)
            if S.CurseoftheDreadblades:IsCastable() and Player:ComboPointsDeficit() >= 4 and (not S.GhostlyStrike:IsAvailable() or Target:Debuff(S.GhostlyStrike)) then
              if AR.Cast(S.CurseoftheDreadblades, Settings.Outlaw.OffGCDasOffGCD.CurseoftheDreadblades) then return "Cast"; end
            end
          end
        end
      -- # Conditions are here to avoid worthless check if nothing is available
      -- actions+=/call_action_list,name=stealth,if=stealthed|cooldown.vanish.up|cooldown.shadowmeld.up
        if Target:IsInRange(S.SaberSlash, SSIdentifier) then
          -- actions.stealth=variable,name=ambush_condition,value=combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&!debuff.ghostly_strike.up)+buff.broadsides.up&energy>60&!buff.jolly_roger.up&!buff.hidden_blade.up
          local Ambush_Condition = (Player:ComboPointsDeficit() >= 2+2*((S.GhostlyStrike:IsAvailable() and not Target:Debuff(S.GhostlyStrike)) and 1 or 0)+(Player:Buff(S.Broadsides) and 1 or 0) and Player:Energy() > 60 and not Player:Buff(S.JollyRoger) and not Player:Buff(S.HiddenBlade)) and true or false;
          -- actions.stealth+=/ambush,if=variable.ambush_condition
          if Player:IsStealthed(true, true) and S.Ambush:IsCastable() and Ambush_Condition then
            if AR.Cast(S.Ambush) then return "Cast Ambush"; end
          else
            if AR.CDsON() and not Player:IsTanking(Target) then
              -- actions.stealth+=/vanish,if=variable.ambush_condition|(equipped.mantle_of_the_master_assassin&mantle_duration=0&!variable.rtb_reroll&!variable.ss_useable)
              if S.Vanish:IsCastable() and (Ambush_Condition or (I.MantleoftheMasterAssassin:IsEquipped() and Rogue.MantleDuration() == 0 and not RtB_Reroll() and not SS_Useable())) then
                if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
              end
              -- actions.stealth+=/shadowmeld,if=variable.ambush_condition
              if S.Shadowmeld:IsCastable() and Ambush_Condition then
                if AR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
              end
            end
          end
        end
      -- actions+=/death_from_above,if=energy.time_to_max>2&!variable.ss_useable_noreroll
      if S.DeathfromAbove:IsCastable() and not SS_Useable_NoReroll() and Player:EnergyTimeToMax() > 2 then
        if AR.Cast(S.DeathfromAbove) then return "Cast Death from above"; end
      end
      if not SS_Useable() then
        -- actions+=/slice_and_dice,if=!variable.ss_useable&buff.slice_and_dice.remains<target.time_to_die&buff.slice_and_dice.remains<(1+combo_points)*1.8
        -- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
        if S.SliceandDice:IsAvailable() then
          if S.SliceandDice:IsCastable() and (Target:FilteredTimeToDie(">", Player:BuffRemains(S.SliceandDice)) or Player:BuffRemains(S.SliceandDice) == 0) and Player:BuffRemains(S.SliceandDice) < (1+Player:ComboPoints())*1.8 then
            if AR.Cast(S.SliceandDice) then return "Cast Slice and Dice"; end
          end
        -- actions+=/roll_the_bones,if=!variable.ss_useable&(target.time_to_die>20|buff.roll_the_bones.remains<target.time_to_die)&(buff.roll_the_bones.remains<=3|variable.rtb_reroll)
        -- Note: Added RtB_BuffRemains() == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
        else
          if S.RolltheBones:IsCastable() and (Target:FilteredTimeToDie(">", 20) or Target:FilteredTimeToDie(">", RtB_BuffRemains()) or RtB_BuffRemains() == 0) and (RtB_BuffRemains() <= 3 or RtB_Reroll()) then
            if AR.Cast(S.RolltheBones) then return "Cast Roll the Bones"; end
          end
        end
      end
      -- actions+=/killing_spree,if=energy.time_to_max>5|energy<15
      if AR.CDsON() and S.KillingSpree:IsCastable() and (Player:EnergyTimeToMax() > 5 or Player:Energy() < 15) then
        if AR.Cast(S.KillingSpree) then return "Cast Killing Spree"; end
      end
      -- actions+=/call_action_list,name=build
        -- actions.build=ghostly_strike,if=combo_points.deficit>=1+buff.broadsides.up&!buff.curse_of_the_dreadblades.up&(debuff.ghostly_strike.remains<debuff.ghostly_strike.duration*0.3|(cooldown.curse_of_the_dreadblades.remains<3&debuff.ghostly_strike.remains<14))&(combo_points>=3|(variable.rtb_reroll&time>=10))
        if S.GhostlyStrike:IsCastable() and Target:IsInRange(S.SaberSlash, SSIdentifier) and Player:ComboPointsDeficit() >= 1+(Player:Buff(S.Broadsides) and 1 or 0) and not Player:Debuff(S.CurseoftheDreadblades) and (Target:DebuffRefreshable(S.GhostlyStrike, 4.5) or (AR.CDsON() and S.CurseoftheDreadblades:IsAvailable() and S.CurseoftheDreadblades:CooldownRemains() < 3 and Target:DebuffRemains(S.GhostlyStrike) < 14)) and (Player:ComboPoints() >= 3 or (RtB_Reroll() and AC.CombatTime() >= 10)) then
          if AR.Cast(S.GhostlyStrike) then return "Cast Ghostly Strike"; end
        end
        -- actions.build+=/pistol_shot,if=combo_points.deficit>=1+buff.broadsides.up&buff.opportunity.up&(energy.time_to_max>2-talent.quick_draw.enabled|(buff.blunderbuss.up&buff.greenskins_waterlogged_wristcuffs.up))
        if (S.PistolShot:IsCastable() or S.Blunderbuss:IsCastable()) and Target:IsInRange(20) and Player:ComboPointsDeficit() >= 1+(Player:Buff(S.Broadsides) and 1 or 0) and Player:Buff(S.Opportunity) and (Player:EnergyTimeToMax() > 2-(S.QuickDraw:IsAvailable() and 1 or 0) or (S.Blunderbuss:IsCastable() and Player:Buff(S.GreenskinsWaterloggedWristcuffs))) then
          if AR.Cast(S.PistolShot) then return "Cast Pistol Shot"; end
        end
        -- actions.build+=/saber_slash,if=variable.ss_useable
        if Target:IsInRange(S.SaberSlash, SSIdentifier) and S.SaberSlash:IsCastable() and SS_Useable() then
          if AR.Cast(S.SaberSlash) then return "Cast Saber Slash"; end
        end
      -- actions+=/call_action_list,name=finish,if=!variable.ss_useable
      if not SS_Useable() then
        -- actions.finish=between_the_eyes,if=(mantle_duration>=0.2&!equipped.thraxis_tricksy_treads)|(equipped.greenskins_waterlogged_wristcuffs&!buff.greenskins_waterlogged_wristcuffs.up)
        if S.BetweentheEyes:IsCastable() and Target:IsInRange(20) and ((Rogue.MantleDuration() >= 0.2 and not I.ThraxisTricksyTreads:IsEquipped()) or (I.GreenskinsWaterloggedWristcuffs:IsEquipped() and not Player:Buff(S.GreenskinsWaterloggedWristcuffs))) then
          if AR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes"; end
        end
        -- actions.finish+=/run_through,if=!talent.death_from_above.enabled|energy.time_to_max<cooldown.death_from_above.remains+3.5
        if S.RunThrough:IsCastable() and Target:IsInRange(S.RunThrough, RTIdentifier) and (not S.DeathfromAbove:IsAvailable() or Player:EnergyTimeToMax() < S.DeathfromAbove:CooldownRemains() + 3.5) then
          if AR.Cast(S.RunThrough) then return "Cast Run Through"; end
        end
        -- OutofRange BtE
        if S.BetweentheEyes:IsCastable() and not Target:IsInRange(10) and Target:IsInRange(20) then
          if AR.Cast(S.BetweentheEyes) then return "Cast Between the Eyes (OoR)"; end
        end
      end
      -- # Gouge is used as a CP Generator while nothing else is available and you have Dirty Tricks talent. It's unlikely that you'll be able to do this optimally in-game since it requires to move in front of the target, but it's here so you can quantifiy its value.
      -- actions+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1
      if S.Gouge:IsCastable() and Target:IsInRange(S.SaberSlash, SSIdentifier) and S.DirtyTricks:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
        if AR.Cast(S.Gouge) then return "Cast Gouge"; end
      end
      -- OutofRange Pistol Shot
      if not Target:IsInRange(10) and Target:IsInRange(20) and (S.PistolShot:IsCastable() or S.Blunderbuss:IsCastable()) and not Player:IsStealthed(true, true) and Player:EnergyDeficit() < 25 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if S.Blunderbuss:IsCastable() then
          if AR.Cast(S.Blunderbuss) then return "Cast Blunderbuss"; end
        else
          if AR.Cast(S.PistolShot) then return "Cast Pistol Shot"; end
        end
      end
    end
end

AR.SetAPL(260, APL);

-- Last Update: 08/15/2017

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
-- # Fish for '2 Buffs' when Loaded Dice is up. Also try to get TB with Loaded Dice and 2 other buffs up. With SnD, consider that we never have to reroll.
-- actions=variable,name=rtb_reroll,value=!talent.slice_and_dice.enabled&buff.loaded_dice.up&(rtb_buffs<2|rtb_buffs=2&!buff.true_bearing.up)
-- # Condition to use Saber Slash when not rerolling RtB or when using SnD
-- actions+=/variable,name=ss_useable_noreroll,value=(combo_points<5+talent.deeper_stratagem.enabled-(buff.broadsides.up|buff.jolly_roger.up)-(talent.alacrity.enabled&buff.alacrity.stack<=4))
-- # Condition to use Saber Slash, when you have RtB or not
-- actions+=/variable,name=ss_useable,value=(talent.anticipation.enabled&combo_points<5)|(!talent.anticipation.enabled&((variable.rtb_reroll&combo_points<4+talent.deeper_stratagem.enabled)|(!variable.rtb_reroll&variable.ss_useable_noreroll)))
-- # Normal rotation
-- actions+=/call_action_list,name=bf
-- actions+=/call_action_list,name=cds
-- # Conditions are here to avoid worthless check if nothing is available
-- actions+=/call_action_list,name=stealth,if=stealthed.rogue|cooldown.vanish.up|cooldown.shadowmeld.up
-- actions+=/death_from_above,if=energy.time_to_max>2&!variable.ss_useable_noreroll
-- actions+=/slice_and_dice,if=!variable.ss_useable&buff.slice_and_dice.remains<target.time_to_die&buff.slice_and_dice.remains<(1+combo_points)*1.8
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
-- actions.build=ghostly_strike,if=combo_points.deficit>=1+buff.broadsides.up&!buff.curse_of_the_dreadblades.up&(debuff.ghostly_strike.remains<debuff.ghostly_strike.duration*0.3|(cooldown.curse_of_the_dreadblades.remains<3&debuff.ghostly_strike.remains<14))&(combo_points>=3|(variable.rtb_reroll&time>=10))
-- actions.build+=/pistol_shot,if=combo_points.deficit>=1+buff.broadsides.up&buff.opportunity.up&(energy.time_to_max>2-talent.quick_draw.enabled|(buff.blunderbuss.up&buff.greenskins_waterlogged_wristcuffs.up))
-- actions.build+=/saber_slash,if=variable.ss_useable

-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=25|buff.adrenaline_rush.up
-- actions.cds+=/use_item,name=vial_of_ceaseless_toxins,if=buff.bloodlust.react|target.time_to_die<=20|combo_points.deficit<=2
-- actions.cds+=/use_item,name=specter_of_betrayal,if=buff.bloodlust.react|target.time_to_die<=20|combo_points.deficit<=2
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/arcane_torrent,if=energy.deficit>40
-- actions.cds+=/cannonball_barrage,if=spell_targets.cannonball_barrage>=1
-- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&energy.deficit>0
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
-- actions.cds+=/sprint,if=equipped.thraxis_tricksy_treads&!variable.ss_useable
-- actions.cds+=/darkflight,if=equipped.thraxis_tricksy_treads&!variable.ss_useable&buff.sprint.down
-- actions.cds+=/curse_of_the_dreadblades,if=combo_points.deficit>=4&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)

-- # Finishers
-- actions.finish=between_the_eyes,if=(mantle_duration>=0.2&!equipped.thraxis_tricksy_treads)|(equipped.greenskins_waterlogged_wristcuffs&!buff.greenskins_waterlogged_wristcuffs.up)
-- actions.finish+=/run_through,if=!talent.death_from_above.enabled|energy.time_to_max<cooldown.death_from_above.remains+3.5

-- # Stealth
-- actions.stealth=variable,name=ambush_condition,value=combo_points.deficit>=2+2*(talent.ghostly_strike.enabled&!debuff.ghostly_strike.up)+buff.broadsides.up&energy>60&!buff.jolly_roger.up&!buff.hidden_blade.up
-- actions.stealth+=/ambush,if=variable.ambush_condition
-- actions.stealth+=/vanish,if=variable.ambush_condition|(equipped.mantle_of_the_master_assassin&mantle_duration=0&!variable.rtb_reroll&!variable.ss_useable)
-- actions.stealth+=/shadowmeld,if=variable.ambush_condition

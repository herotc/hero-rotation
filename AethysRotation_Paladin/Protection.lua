--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Party = Unit.Party;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Paladin = AR.Commons.Paladin;
  -- Spells
  if not Spell.Paladin then Spell.Paladin = {}; end
  Spell.Paladin.Protection = {
    -- Racials
    
    -- Abilities
    AvengersShield           = Spell(31935),
    AvengingWrath            = Spell(31884),
    Consecration             = Spell(26573),
    ConsecrationBuff         = Spell(188370),
    HammeroftheRighteous     = Spell(53595),
    Judgment                 = Spell(20271),
    ShieldoftheRighteous     = Spell(53600),
    ShieldoftheRighteousBuff = Spell(132403),
    GrandCrusader            = Spell(85043),
    -- Talents
    BlessedHammer            = Spell(204019),
    ConsecratedHammer        = Spell(203785),
    CrusadersJudgment        = Spell(204023),
    -- Artifact
    EyeofTyr                 = Spell(209202),
    -- Defensive
    LightoftheProtector      = Spell(184092),
    HandoftheProtector       = Spell(213652),
    -- Utility
    
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Paladin.Protection;
  -- Items
  if not Item.Paladin then Item.Paladin = {}; end
  Item.Paladin.Protection = {
    -- Legendaries
    
  };
  local I = Item.Paladin.Protection;
  -- Rotation Var
  local T202PC, T204PC = AC.HasTier("T20");
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Paladin.Commons,
    Protection = AR.GUISettings.APL.Paladin.Protection
  };


--- ======= ACTION LISTS =======


--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    AC.GetEnemies(10, true);
    Everyone.AoEToggleEnemiesUpdate();
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange(30) then
        -- Avenger's Shield
        if S.AvengersShield:IsCastable() then
          if AR.Cast(S.AvengersShield) then return; end
        end
        -- Judgment
        if S.Judgment:IsCastable() then
          if AR.Cast(S.Judgment) then return; end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      -- CDs
        -- SotR (HP or (AS on CD and 3 Charges))
        if S.ShieldoftheRighteous:IsCastable("Melee") and Player:BuffRefreshable(S.ShieldoftheRighteousBuff, 4) and (Player:ActiveMitigationNeeded() or Player:HealthPercentage() <= Settings.Protection.ShieldoftheRighteousHP or (not S.AvengersShield:CooldownUp() and S.ShieldoftheRighteous:ChargesFractional() >= 2.65)) then
          if AR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous) then return; end
        end
        -- Avengin Wrath (CDs On)
        if AR.CDsON() and S.AvengingWrath:IsCastable("Melee") then
          if AR.Cast(S.AvengingWrath, Settings.Protection.OffGCDasOffGCD.AvengingWrath) then return; end
        end
        -- Eye of Tyr (HP)
        if S.EyeofTyr:IsCastable(8, true) and Player:HealthPercentage() <= Settings.Protection.EyeofTyrHP then
          if AR.Cast(S.EyeofTyr) then return; end
        end
      -- Defensives
      if Target:IsInRange(10) then
        if not Player:HealingAbsorbed() then
          if S.HandoftheProtector:IsCastable() and Player:HealthPercentage() <= Settings.Protection.HandoftheProtectorHP - 35 then
            if AR.Cast(S.HandoftheProtector, Settings.Protection.OffGCDasOffGCD.HandoftheProtector) then return; end
          end
          -- LotP (HP) / HotP (HP)
          if S.LightoftheProtector:IsCastable() and Player:HealthPercentage() <= Settings.Protection.LightoftheProtectorHP then
            if AR.Cast(S.LightoftheProtector, Settings.Protection.OffGCDasOffGCD.LightoftheProtector) then return; end
          end
          if S.HandoftheProtector:IsCastable() and Player:HealthPercentage() <= Settings.Protection.HandoftheProtectorHP then
            if AR.Cast(S.HandoftheProtector, Settings.Protection.OffGCDasOffGCD.HandoftheProtector) then return; end
          end
        end
      end
      -- Avenger's Shield
      if S.AvengersShield:IsCastable(30) then
        if AR.Cast(S.AvengersShield) then return; end
      end
      -- Consecration 
      if S.Consecration:IsCastable("Melee") then
        if AR.Cast(S.Consecration) then return; end
      end
      -- Judgment
      if S.Judgment:IsCastable(30) then
        if AR.Cast(S.Judgment) then return; end
      end
      -- Blessed Hammer
      if S.BlessedHammer:IsCastable(10, true) and S.BlessedHammer:Charges() > 1 then
        if AR.Cast(S.BlessedHammer) then return; end
      end
      if Target:IsInRange("Melee") then
        -- Shield of the Righteous
         if S.ShieldoftheRighteous:IsCastable() and S.ShieldoftheRighteous:Charges() == 3 then
          if AR.Cast(S.ShieldoftheRighteous) then return; end
        end
        -- Hammer of the Righteous
        if (S.ConsecratedHammer:IsAvailable() or S.HammeroftheRighteous:IsCastable()) then
          if AR.Cast(S.HammeroftheRighteous) then return; end
        end
      end
      return;
    end
  end

  AR.SetAPL(66, APL);


--- ======= SIMC =======
--- Last Update: 04/30/2017
-- I did it for my Paladin alt to tank Dungeons, so I took these talents: 3133121

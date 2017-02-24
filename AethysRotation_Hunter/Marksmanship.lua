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
  Spell.Hunter.Marksmanship = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    AimedShot                     = Spell(19434),
    ArcaneShot                    = Spell(185358),
    BurstingShot                  = Spell(186387),
    HuntersMark                   = Spell(185365),
    MarkedShot                    = Spell(185901),
    MultiShot                     = Spell(2643),
    TrueShot                      = Spell(193526),
    Vulnerable                    = Spell(187131),
    
    -- Talents
    AMurderofCrows                = Spell(131894),
    Barrage                       = Spell(120360),
    BindingShot                   = Spell(109248),
    BlackArrow                    = Spell(194599),
    ExplosiveShot                 = Spell(212431),
    PiercingShot                  = Spell(198670),
    Sentinel                      = Spell(206817),
    Sidewinders                   = Spell(214579),
    Volley                        = Spell(194386),
    -- Artifact
    Windburst                     = Spell(204147),
    -- Defensive
    AspectoftheTurtle             = Spell(186265),
    Exhilaration                  = Spell(109304),
    -- Utility
    AspectoftheCheetah            = Spell(186257),
    CounterShot                   = Spell(147362),
    Disengage                     = Spell(781),
    FreezingTrap                  = Spell(187650),
    FeignDeath                    = Spell(5384),
    TarTrap                       = Spell(187698),
    
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Hunter.Marksmanship;
  -- Items
  if not Item.Hunter then Item.Hunter = {}; end
  Item.Hunter.Marksmanship = {
    -- Legendaries
    
  };
  local I = Item.Hunter.Marksmanship;
  -- Rotation Var
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Hunter.Commons,
    Marksmanship = AR.GUISettings.APL.Hunter.Marksmanship
  };


--- APL Action Lists (and Variables)
  


--- APL Main
  local function APL ()
    -- Unit Update
    
    -- Defensives
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      
      -- Opener
      if AR.Commons.TargetIsValid() and Target:IsInRange(40) then
        if S.AMurderofCrows:IsCastable() then
          if AR.Cast(S.AMurderofCrows) then return; end
        end
        if S.Windburst:IsCastable() then
          if AR.Cast(S.Windburst) then return; end
        end
        -- MarkedShot
      end
      return;
    end
    -- In Combat
    if AR.Commons.TargetIsValid() then
      -- MarkedShot
      if S.MarkedShot:IsCastable() and Player:Focus() >= 25 and Target:Debuff(S.HuntersMark) and not Target:Debuff(S.Vulnerable) then
        if AR.Cast(S.MarkedShot) then return; end
      end
      -- AimedShot
      if S.AimedShot:IsCastable() and Player:Focus() >= 50 and Target:Debuff(S.Vulnerable) and Target:DebuffRemains(S.Vulnerable) > S.AimedShot:CastTime()+Player:GCDRemains()+0.3 then
        if AR.Cast(S.AimedShot) then return; end
      end
      -- ArcaneShot
      if S.ArcaneShot:IsCastable() then
        if AR.Cast(S.ArcaneShot) then return; end
      end
      return;
    end
  end

  AR.SetAPL(254, APL);


--- Last Update: 12/31/2999

-- APL goes here

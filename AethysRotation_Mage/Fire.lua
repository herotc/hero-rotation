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
  local Pet = Unit.Pet;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua

  --- ============================ CONTENT ============================
  --- ======= APL LOCALS =======
     local Everyone = AR.Commons.Everyone;
     local Mage = AR.Commons.Mage;
    -- Spells
     if not Spell.Mage then Spell.Mage = {}; end

     Spell.Mage.Fire = {
      -- Racials
      ArcaneTorrent                 = Spell(25046),
      Berserking                    = Spell(26297),
      BloodFury                     = Spell(20572),
      GiftoftheNaaru                = Spell(59547),
      Shadowmeld                    = Spell(58984),
      -- Abilities
      Fireball                      = Spell(133),
      Pyroblast                     = Spell(147720),
      CriticalMass                  = Spell(117216),
      Fireblast                     = Spell(108853),
      HotStreak                     = Spell(195283),
      EnchancedPyrotechnics         = Spell(157642),
      Dragons Breath                = Spell(31661),
      Combustion                    = Spell(190319),
      Scorch                        = Spell(2948),
      Flamestrike                   = Spell(2120),
      -- Talents
      Pyromaniac                    = Spell(205020),
      Conflagaration                = Spell(205023),
      Firestarter                   = Spell(205026),
      MirrorImage                   = Spell(55342),
      RuneofPower                   = Spell(116011),
      IncantersFlow                 = Spell(1463),
      AlexstraszasFury              = Spell(235870),
      FlameOn                       = Spell(205029),
      ControlledBurn                = Spell(205033),
      LivingBomb                    = Spell(44457),
      FlamePatch                    = Spell(205037),
      Kindling                      = Spell(155148),
      Cinderstorm                   = Spell(198929),
      Meteor                        = Spell(153561),
      -- Artifact
      PheonixFlames                 = Spell(194466),
      -- Defensive
      IceBarrier                    = Spell(11426),
      IceBlock                      = Spell(45438),
      Invisibility                  = Spell(66),
      -- Legendaries
      MarqueeBindingsoftheSunKing   = Spell(132406),
      KoralonsBurningTouch          = Spell(132454),
      ShardOfExodar                 = Spell(132410),
      CantainedInfernalCore         = Spell(151809),
      SoulOfTheArchmage             = Spell(151642),
      PyrotexIgnitionCloth          = Spell(144355),
      SephuzsSecret                 = Spell(132452),
      KiljadensBurningWish          = Spell(144259),
      DarckilsDragonfireDiadem      = Spell(132863),
      NorgannonsForesight           = Spell(132455),
      BelovirsFinalStand            = Spell(133977),
      PrydazXavaricsMagnumOpus      = Spell(132444),
      -- Legendary Procs
      KaelthassUltimateAbility      = Spell(209455),  -- Fire Mage Bracer Procs
      ContainedInfernalCoreBuff     = Spell(248146),  -- Fire Shoulders Buff


};

local S = Spell.Mage.Fire;
-- Items
if not Item.Mage then Item.Mage = {}; end
Item.Mage.Fire = {
 PotionofProlongedPower   = Spell(142117),

local I = Item.Mage.Fire;
-- Rotation Var
local ShouldReturn; -- Used to get the return string
local IvStart;
-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Mage.Commons,
  Frost = AR.GUISettings.APL.Mage.Fire
};

-- Actions

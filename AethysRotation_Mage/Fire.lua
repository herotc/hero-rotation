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
      Fireball                      = Spell(),
      Pyroblast                     = Spell(),
      CriticalMass                  = Spell(),
      Fireblast                     = Spell(),
      HotStreak                     = Spell(),
      EnchancedPyrotechnics         = Spell(),
      Dragons Breath                = Spell(),
      Combustion                    = Spell(),
      Scorch                        = Spell(),
      Flamestrike                   = Spell(),
      -- Talents
      Pyromaniac                    = Spell(),
      Conflagaration                = Spell(),
      Firestarter                   = Spell(),
      Shimmer                       = Spell(),
      BlastWave                     = Spell(),
      BlazingSoul                   = Spell(),
      MirrorImage                   = Spell(),
      RuneofPower                   = Spell(),
      IncantersFlow                 = Spell(),
      AlexstraszasFury              = Spell(),
      FlameOn                       = Spell(),
      ControlledBurn                = Spell(),
      FrenticSpeed                  = Spell(),
      RingOfFrost                   = Spell(),
      IceWard                       = Spell(),
      LivingBomb                    = Spell(),
      FlamePatch                    = Spell(),
      Kindling                      = Spell(),
      Cinderstorm                   = Spell(),
      Meteor                        = Spell(),
      -- Artifact

      PheonixFlames                 = Spell(),
      -- Defensive
      IceBarrier                    = Spell(11426),
      IceBlock                      = Spell(45438),
      Invisibility                  = Spell(66),
      -- Legendaries
      MarqueeBindingsoftheSunKing   = Spell(),
      KoralonsBurningTouch          = Spell(),
      ShardOfExodar                 = Spell(),
      CantainedInfernalCore         = Spell(),
      SoulOfTheArchmage             = Spell(),
      PyrotexIgnitionCloth          = Spell(),
      SephuzsSecret                 = Spell(),
      KiljadensBurningWish          = Spell(),
      DarckilsDragonfireDiadem      = Spell(),
      NorgannonsForesight           = Spell(),
      BelovirsFinalStand            = Spell(),
      PrydazXavaricsMagnumOpus      = Spell(),
 
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

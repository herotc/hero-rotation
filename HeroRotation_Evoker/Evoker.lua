--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
local MergeTableByKey = HL.Utils.MergeTableByKey
-- HeroRotation
local HR         = HeroRotation

--- ============================ CONTENT ============================

-- Spell
if not Spell.Evoker then Spell.Evoker = {} end
Spell.Evoker.Commons = {
  -- Racials
  TailSwipe                             = Spell(368970),
  WingBuffet                            = Spell(357214),
  -- Abilities
  AzureStrike                           = Spell(362969),
  DeepBreath                            = Spell(357210),
  Disintegrate                          = Spell(356995),
  FireBreath                            = MultiSpell(357208,382266), -- with and without Font of Magic
  LivingFlame                           = Spell(361469),
  -- Talents
  TipTheScales                          = Spell(370553),
  -- Buffs/Debuffs
  FireBreathDebuff                      = Spell(357209),
  LeapingFlamesBuff                     = Spell(370901),
  -- Utility
  Quell                                 = Spell(351338),
  -- Other
  Pool                                  = Spell(999910)
}

Spell.Evoker.Devastation = MergeTableByKey(Spell.Evoker.Commons, {
  -- Talents
  Dragonrage                            = Spell(375087),
  EssenceAttunement                     = Spell(375722),
  EternitySurge                         = MultiSpell(359073,382411), -- with and without Font of Magic
  EternitysSpan                         = Spell(375757),
  Firestorm                             = Spell(368847),
  FontofMagic                           = Spell(375783),
  Pyre                                  = Spell(357211),
  Ruin                                  = Spell(376888),
  ShatteringStar                        = Spell(370452),
  -- Buffs/Debuffs
  BurnoutBuff                           = Spell(375802),
  ChargedBlastBuff                      = Spell(370454),
  EssenceBurstBuff                      = Spell(359618),
})

-- Items
if not Item.Evoker then Item.Evoker = {} end
Item.Evoker.Commons = {
  -- Potions
  PotionofSpectralIntellect             = Item(171273),
}

Item.Evoker.Devastation = MergeTableByKey(Item.Evoker.Commons, {
})

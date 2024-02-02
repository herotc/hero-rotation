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
  BlessingoftheBronze                   = Spell(364342),
  DeepBreath                            = Spell(357210),
  Disintegrate                          = Spell(356995),
  EmeraldBlossom                        = Spell(355913),
  FireBreath                            = MultiSpell(357208,382266), -- with and without Font of Magic
  Hover                                 = Spell(358267),
  LivingFlame                           = Spell(361469),
  -- Talents
  AncientFlame                          = Spell(369990),
  BlastFurnace                          = Spell(375510),
  LeapingFlames                         = Spell(369939),
  ObsidianScales                        = Spell(363916),
  ScarletAdaptation                     = Spell(372469),
  SourceofMagic                         = Spell(369459),
  TipTheScales                          = Spell(370553),
  Unravel                               = Spell(368432),
  VerdantEmbrace                        = Spell(360995),
  -- Buffs/Debuffs
  AncientFlameBuff                      = Spell(375583),
  BlessingoftheBronzeBuff               = Spell(381748),
  FireBreathDebuff                      = Spell(357209),
  HoverBuff                             = Spell(358267),
  LeapingFlamesBuff                     = Spell(370901),
  ScarletAdaptationBuff                 = Spell(372470),
  SourceofMagicBuff                     = Spell(369459),
  -- Trinket Effects
  SpoilsofNeltharusCrit                 = Spell(381954),
  SpoilsofNeltharusHaste                = Spell(381955),
  SpoilsofNeltharusMastery              = Spell(381956),
  SpoilsofNeltharusVers                 = Spell(381957),
  -- Utility
  Quell                                 = Spell(351338),
  -- Other
  Pool                                  = Spell(999910)
}

Spell.Evoker.Augmentation = MergeTableByKey(Spell.Evoker.Commons, {
  -- Attunements
  BlackAttunement                       = Spell(403264),
  BronzeAttunement                      = Spell(403265),
  -- Talents
  BlisteringScales                      = Spell(360827),
  BreathofEons                          = Spell(403631),
  DreamofSpring                         = Spell(414969),
  EbonMight                             = Spell(395152),
  Eruption                              = Spell(395160),
  FontofMagic                           = Spell(408083),
  InterwovenThreads                     = Spell(412713),
  Prescience                            = Spell(409311),
  PupilofAlexstrasza                    = Spell(407814),
  TimeSkip                              = Spell(404977),
  Upheaval                              = Spell(408092),
  -- Buffs
  BlackAttunementBuff                   = Spell(403264),
  BlisteringScalesBuff                  = Spell(360827),
  BronzeAttunementBuff                  = Spell(403265),
  EbonMightOtherBuff                    = Spell(395152),
  EbonMightSelfBuff                     = Spell(395296),
  EssenceBurstBuff                      = Spell(392268),
  PrescienceBuff                        = Spell(410089),
  TremblingEarthBuff                    = Spell(424368), -- T31 4pc
  -- Debuffs
  TemporalWoundDebuff                   = Spell(409560),
})

Spell.Evoker.Devastation = MergeTableByKey(Spell.Evoker.Commons, {
  -- Talents
  Animosity                             = Spell(375797),
  ArcaneVigor                           = Spell(386342),
  Burnout                               = Spell(375801),
  Catalyze                              = Spell(386283),
  Causality                             = Spell(375777),
  ChargedBlast                          = Spell(370455),
  Dragonrage                            = Spell(375087),
  EngulfingBlaze                        = Spell(370837),
  EssenceAttunement                     = Spell(375722),
  EternitySurge                         = MultiSpell(359073,382411), -- with and without Font of Magic
  EternitysSpan                         = Spell(375757),
  EventHorizon                          = Spell(411164),
  EverburningFlame                      = Spell(370819),
  EyeofInfinity                         = Spell(369375),
  FeedtheFlames                         = Spell(369846),
  Firestorm                             = Spell(368847),
  FontofMagic                           = Spell(375783),
  ImminentDestruction                   = Spell(370781),
  Pyre                                  = Spell(357211),
  RagingInferno                         = Spell(405659),
  RubyEmbers                            = Spell(365937),
  Scintillation                         = Spell(370821),
  ShatteringStar                        = Spell(370452),
  Snapfire                              = Spell(370783),
  Tyranny                               = Spell(376888),
  Volatility                            = Spell(369089),
  -- Buffs
  BlazingShardsBuff                     = Spell(409848),
  BurnoutBuff                           = Spell(375802),
  ChargedBlastBuff                      = Spell(370454),
  EmeraldTranceBuff                     = Spell(424155), -- T31 2pc
  EssenceBurstBuff                      = Spell(359618),
  IridescenceBlueBuff                   = MultiSpell(386399,399370),
  IridescenceRedBuff                    = Spell(386353),
  LimitlessPotentialBuff                = Spell(394402),
  PowerSwellBuff                        = Spell(376850),
  SnapfireBuff                          = Spell(370818),
  -- Debuffs
  LivingFlameDebuff                     = Spell(361500),
})

-- Items
if not Item.Evoker then Item.Evoker = {} end
Item.Evoker.Commons = {
  -- Trinkets
  AshesoftheEmbersoul                   = Item(207167, {13, 14}),
  BalefireBranch                        = Item(159630, {13, 14}),
  BeacontotheBeyond                     = Item(203963, {13, 14}),
  BelorrelostheSuncaller                = Item(207172, {13, 14}),
  DragonfireBombDispenser               = Item(202610, {13, 14}),
  IrideusFragment                       = Item(193743, {13, 14}),
  MirrorofFracturedTomorrows            = Item(207581, {13, 14}),
  NeltharionsCalltoChaos                = Item(204201, {13, 14}),
  NymuesUnravelingSpindle               = Item(208615, {13, 14}),
  SpoilsofNeltharus                     = Item(193773, {13, 14}),
  -- Items
  Dreambinder                           = Item(208616, {16}),
  Iridal                                = Item(208321, {16}),
  KharnalexTheFirstLight                = Item(195519, {16}),
  -- Trinkets (SL)
  ShadowedOrbofTorment                  = Item(186428, {13, 14}),
}

Item.Evoker.Augmentation = MergeTableByKey(Item.Evoker.Commons, {
})

Item.Evoker.Devastation = MergeTableByKey(Item.Evoker.Commons, {
})

--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
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
-- HeroRotation
local HR         = HeroRotation

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

if not Spell.Paladin then Spell.Paladin = {} end
Spell.Paladin.Holy = {
  --ConsecrationDebuff                    = Spell(81297),
  --ConsecrationDebuff                    = Spell(26573),
  Consecration                          = Spell(26573),
  AvengingWrathBuff                     = Spell(31884),
  AvengingWrath                         = Spell(31884),
  HolyAvengerBuff                       = Spell(105809),
  HolyAvenger                           = Spell(105809),
  HolyShock                             = Spell(20473),
  GlimmerOfLightBuff                    = Spell(287280),
  CrusaderStrike                        = Spell(35395),
  JudgementDebuff                       = Spell(275773),
  Judgment                              = Spell(275773),
  HammerofJustice                       = Spell(853),
};

local S = Spell.Paladin.Holy;
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

-- Rotation Vars
local PassiveEssence;

-- Special Item Handlers
if not Item.Paladin then Item.Paladin = {} end
Item.Paladin.Holy = {
  PotionofUnbridledFury            = Item(169299),
  --MerekthasFang                    = Item(158367, {13, 14}),
  --RazdunksBigRedButton             = Item(159611, {13, 14}),
};
local I = Item.Paladin.Holy;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- examples
  -- I.AshvanesRazorCoral:ID(),
  -- I.AzsharasFontofPower:ID()
}

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Holy = HR.GUISettings.APL.Paladin.Holy
};

-- Update enemy details
local EnemyRanges = {8, 30, 40}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function ConsecrationTimeRemaining()
  for index=1,4 do
    local _, totemName, startTime, duration = GetTotemInfo(index)
    if totemName == S.Consecration:Name() then
      return (floor(startTime + duration - GetTime() + 0.5)) or 0
    end
  end
  return 0
end



HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence();
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID]);
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateTargetIfFilterGlimmer(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.GlimmerOfLightBuff)
end

local function EvaluateTargetIfGlimmer(TargetUnit)
  return true
end

local function Precombat()
  if Everyone.TargetIsValid() then
    -- beacon someone
    -- if S.Beacon:IsC then
    -- end
  end
end

local function Defensives()
end


local function Cooldowns()
  if S.HolyAvenger:IsCastableP() then
    if HR.Cast(S.HolyAvenger, Settings.Holy.GCDasOffGCD.HolyAvenger) then return "holy_avenger"; end
  end

  if S.AvengingWrath:IsCastableP() then
    if HR.Cast(S.AvengingWrath, Settings.Holy.GCDasOffGCD.AvengingWrath) then return "avenging_wrath"; end
  end
end

local function APL()
  PassiveEssence = (Spell:MajorEssenceEnabled(AE.VisionofPerfection) or Spell:MajorEssenceEnabled(AE.ConflictandStrife) or Spell:MajorEssenceEnabled(AE.TheFormlessVoid) or Spell:MajorEssenceEnabled(AE.TouchoftheEverlasting))
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end

  if Everyone.TargetIsValid() then
    -- call_action_list,name=defensives
    if (true) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end

    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end

    if S.HolyShock:IsCastableP() then
      if HR.CastTargetIf(S.HolyShock, 40, "min", EvaluateTargetIfFilterGlimmer, EvaluateTargetIfGlimmer) then return "holy shock"; end
    end

    if S.CrusaderStrike:IsCastableP() and S.HolyShock:CooldownRemains() > 1.5 + Player:GCD() and S.CrusaderStrike:Charges() == 1 and S.CrusaderStrike:RechargeP() <= Player:GCD() then
      if HR.Cast(S.CrusaderStrike, nil, nil, "Melee") then return "crusader strike"; end
    end

    if S.Judgment:IsCastableP() and S.HolyShock:CooldownRemains() > Player:GCD() then
      if HR.Cast(S.Judgment, nil, nil, 30) then return "judgment"; end
    end

    if S.Consecration:IsCastableP() and ConsecrationTimeRemaining() <= 0 and S.HolyShock:CooldownRemains() > Player:GCD() then
      if HR.Cast(S.Consecration, nil, nil, "Melee") then return "consecration application"; end
    end

    if S.CrusaderStrike:IsCastableP() and S.HolyShock:CooldownRemains() > 1.5 + Player:GCD() then
      if HR.Cast(S.CrusaderStrike, nil, nil, "Melee") then return "crusader strike"; end
    end

    if S.Consecration:IsCastableP() and S.HolyShock:CooldownRemains() > Player:GCD() then
      if HR.Cast(S.Consecration, nil, nil, "Melee") then return "filler consecrate refresh"; end
    end
  end
end

HR.SetAPL(65, APL)

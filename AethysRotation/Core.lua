--- Localize Vars
-- Addon
local addonName, AR = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCore_Cache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- Lua
local print = print;
local select = select;
local stringlower = string.lower;
local tostring = tostring;

--- Globalize Vars
-- Addon
AethysRotation = AR;


-- Print with ER Prefix
function AR.Print (...)
  print("[|cFFFF6600Aethys Rotation|r]", ...);
end

-- Defines the APL
AR.APLs = {};
function AR.SetAPL (Spec, APL)
  AR.APLs[Spec] = APL;
end

-- Get the texture (and cache it until next reload).
function AR.GetTexture (Object)
  if Object.SpellID then
    if not Cache.Persistent.Texture.Spell[Object.SpellID] then
      -- Check if the SpellID is the one from Custom Icons or a Reguler WoW Spell
      if Object.SpellID >= 9999000000 then
        if Object.SpellID >= 9999000000 and Object.SpellID <= 9999000001 then
          Cache.Persistent.Texture.Spell[Object.SpellID] = "Interface\\Addons\\AethysRotation\\Textures\\"..tostring(Object.SpellID);
        else
          Cache.Persistent.Texture.Spell[Object.SpellID] = "Interface\\Addons\\AethysRotation_" .. AC.SpecID_Classes[tonumber(string.sub(tostring(Object.SpellID), 5, 7))] .. "\\Textures\\"..tostring(Object.SpellID);
        end
      else
        Cache.Persistent.Texture.Spell[Object.SpellID] = GetSpellTexture(Object.SpellID);
      end
    end
    return Cache.Persistent.Texture.Spell[Object.SpellID];
  elseif Object.ItemID then
    if not Cache.Persistent.Texture.Item[Object.ItemID] then
      Cache.Persistent.Texture.Item[Object.ItemID] = ({GetItemInfo(Object.ItemID)})[10];
    end
    return Cache.Persistent.Texture.Item[Object.ItemID];
  end
end

-- Display the Spell to cast.
AR.CastOffGCDOffset = 1;
function AR.Cast (Object, OffGCD)
  if OffGCD and OffGCD[1] then
    if AR.CastOffGCDOffset <= 2 then
      AR.SmallIconFrame:ChangeSmallIcon(AR.CastOffGCDOffset, AR.GetTexture(Object));
      AR.CastOffGCDOffset = AR.CastOffGCDOffset + 1;
      Object.LastDisplayTime = AC.GetTime();
      return OffGCD[2] and "Should Return" or false;
    end
  else
    AR.MainIconFrame:ChangeMainIcon(AR.GetTexture(Object));
    AR.MainIconFrame:SetCooldown(GetSpellCooldown(61304)); -- Put the GCD as Cast Cooldown
    Object.LastDisplayTime = AC.GetTime();
    return "Should Return";
  end
  return false;
end

function AR.CmdHandler (Message)
  _T.Argument = stringlower(Message);
  if _T.Argument == "cds" then
    AethysRotationDB.Toggles[1] = not AethysRotationDB.Toggles[1];
    AR.Print("CDs are now "..(AethysRotationDB.Toggles[1] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
  elseif _T.Argument == "aoe" then
    AethysRotationDB.Toggles[2] = not AethysRotationDB.Toggles[2];
    AR.Print("AoE is now "..(AethysRotationDB.Toggles[2] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
  elseif _T.Argument == "toggle" then
    AethysRotationDB.Toggles[3] = not AethysRotationDB.Toggles[3];
    AR.Print("AethysRotation is now "..(AethysRotationDB.Toggles[3] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
  elseif _T.Argument == "help" then
    AR.Print("CDs : /eraid cds | AoE : /eraid cds | Toggle : /eraid toggle");
  end
end
SLASH_EASYRAID1 = "/eraid"
SlashCmdList["EASYRAID"] = AR.CmdHandler;

-- Get if the CDs are enabled.
function AR.CDsON ()
  return AethysRotationDB.Toggles[1];
end

-- Get if the AoE is enabled.
function AR.AoEON ()
  return AethysRotationDB.Toggles[2];
end

-- Get if the main toggle is on.
function AR.ON ()
  return AethysRotationDB.Toggles[3];
end

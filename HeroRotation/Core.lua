--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, HR = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache, Utils = HeroCache, HL.Utils;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- Lua
  local mathmin = math.min;
  local print = print;
  local select = select;
  local stringlower = string.lower;
  local strsplit = strsplit;
  local tostring = tostring;
  -- File Locals


--- ======= GLOBALIZE =======
  -- Addon
  HeroRotation = HR;


--- ============================ CONTENT ============================
--- ======= CORE =======
  -- Print with ER Prefix
  function HR.Print (...)
    print("[|cFFFF6600Hero Rotation|r]", ...);
  end

  -- Defines the APL
  HR.APLs = {};
  HR.APLInits = {};
  function HR.SetAPL (Spec, APL, APLInit)
    HR.APLs[Spec] = APL;
    HR.APLInits[Spec] = APLInit;
  end

  -- Get the texture (and cache it until next reload).
  -- TODO: Implements GetTexture as Actions method (Item:GetTexture() / Spell:GetTexture() / Macro:GetTexture())
  --       So we can simplify this part.
  function HR.GetTexture (Object)
    -- Spells
    local SpellID = Object.SpellID;
    if SpellID then
      local TextureCache = Cache.Persistent.Texture.Spell;
      if not TextureCache[SpellID] then
        -- Check if the SpellID is the one from Custom Textures or a Regular WoW Spell
        if SpellID >= 999900 then
          TextureCache[SpellID] = "Interface\\Addons\\HeroRotation\\Textures\\"..tostring(SpellID);
        elseif Object.TextureSpellID then
          TextureCache[SpellID] = GetSpellTexture(Object.TextureSpellID);
        else
          TextureCache[SpellID] = GetSpellTexture(SpellID);
        end
      end
      return TextureCache[SpellID];
    end
    -- Items
    local ItemID = Object.ItemID;
    if ItemID then
      local TextureCache = Cache.Persistent.Texture.Item;
      if not TextureCache[ItemID] then
        -- name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
        local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(ItemID);
        TextureCache[ItemID] = texture;
      end
      return TextureCache[ItemID];
    end
  end

--- ======= CASTS =======
  local GCDSpell = Spell(61304);
  local CooldownSpell, CooldownSpellDisplayTime, CooldownSpellCastDuration;
  local function DisplayCooldown (Object, DisplayPoolingSwirl, CustomTime)
    local StartTime, CastDuration

    -- Default GCD and Casting Swirls
    local CurrentTime = GetTime()
    if Player:IsCasting() or Player:IsChanneling() then
      StartTime = Player:CastStart()
      CastDuration = Player:CastDuration()
    else
      StartTime, CastDuration = GCDSpell:CooldownInfo()
    end

    -- Tracking Values for Current Spell
    if CooldownSpell ~= Object then
      CooldownSpell = Object
      CooldownSpellDisplayTime = CurrentTime
      CooldownSpellCastDuration = 0
    end

    -- Resource Pooling Display Swirls
    if DisplayPoolingSwirl then
      local TimeToResource
      if CustomTime then
        TimeToResource = CustomTime
      else
        local Resource = Object:CostInfo(nil, "type")
        if Resource then
          TimeToResource = Player.TimeToXResourceMap[Resource](Object:Cost())
        end
      end
      if TimeToResource and TimeToResource > 0 then
        -- Only display the resource-based swirl if the duration is greater than the GCD/Cast swirl
        if TimeToResource > ((StartTime + CastDuration) - CurrentTime) then
          local AdjustedCastDuration = CurrentTime - CooldownSpellDisplayTime + TimeToResource
          -- 0.25s minimum, don't display an increase unless it is greater than 0.5s
          if (CooldownSpellCastDuration == 0 and AdjustedCastDuration > 0.25) or CooldownSpellCastDuration > AdjustedCastDuration
            or (AdjustedCastDuration - CooldownSpellCastDuration) > 0.5 then
            CooldownSpellCastDuration = AdjustedCastDuration
          end
          StartTime = CooldownSpellDisplayTime
          CastDuration = CooldownSpellCastDuration
        end
      end
    end

    -- Reset tracking if the current cooldown is finished
    if((StartTime + CastDuration) < CurrentTime) then
      StartTime = 0
      CastDuration = 0
      CooldownSpell = nil
    end

    HR.MainIconFrame:SetCooldown(StartTime, CastDuration);
  end
  -- Main Cast
  HR.CastOffGCDOffset = 1;
  function HR.Cast (Object, OffGCD, DisplayStyle, OutofRange, CustomTime)
    local ObjectTexture = HR.GetTexture(Object);
    local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(ObjectTexture);
    if OffGCD or DisplayStyle == "Cooldown" then
      -- If this is the second cooldown, check to ensure we don't have a duplicate icon in the first slot
      if HR.CastOffGCDOffset == 1 or (HR.CastOffGCDOffset == 2 and HR.SmallIconFrame:GetIcon(1) ~= ObjectTexture) then
        HR.SmallIconFrame:ChangeIcon(HR.CastOffGCDOffset, ObjectTexture, Keybind, OutofRange);
        HR.CastOffGCDOffset = HR.CastOffGCDOffset + 1;
        Object.LastDisplayTime = GetTime();
        return false;
      end
    elseif DisplayStyle == "Suggested" then
      HR.CastSuggested(Object, OutofRange);
    elseif DisplayStyle == "SuggestedRight" then
      HR.CastRightSuggested(Object, OutofRange);
    else
      local PoolResource = 999910
      local Usable = Object.SpellID == PoolResource or Object:IsUsable();
      local ShowPooling = DisplayStyle == "Pooling"

      local OutofRange = OutofRange or false
      HR.MainIconFrame:ChangeIcon(ObjectTexture, Keybind, Usable, OutofRange, Object:ID());
      DisplayCooldown(Object, ShowPooling, CustomTime);
      Object.LastDisplayTime = GetTime();
      return true;
    end
    return nil;
  end
  -- Overload for Main Cast (with text)
  function HR.CastAnnotated (Object, OffGCD, Text)
    local Result = HR.Cast(Object, OffGCD);
    -- TODO: handle small icon frame if OffGCD is true
    if not OffGCD then
      HR.MainIconFrame:OverlayText(Text);
    end
    return Result;
  end
  -- Overload for Main Cast (with resource pooling swirl)
  function HR.CastPooling (Object, CustomTime, OutofRange)
    return HR.Cast(Object, false, "Pooling", OutofRange, CustomTime)
  end

  -- Queued Casting Support
  local QueueSpellTable, QueueLength, QueueTextureTable, QueueKeybindTable;
  HR.MaxQueuedCasts = 3;
  local function DisplayQueue (...)
    QueueSpellTable = {...};
    QueueLength = mathmin(#QueueSpellTable, HR.MaxQueuedCasts);
    QueueTextureTable = {};
    QueueKeybindTable = {};
    for i = 1, QueueLength do
      QueueTextureTable[i] = HR.GetTexture(QueueSpellTable[i]);
      QueueSpellTable[i].LastDisplayTime = GetTime();
      QueueKeybindTable[i] = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(QueueTextureTable[i]);
    end
    -- Call ChangeIcon so that the main icon exists to be able to display a cooldown sweep, even though it gets overlapped
    HR.MainIconFrame:ChangeIcon(QueueTextureTable[1], QueueKeybindTable[1], QueueSpellTable[1]:IsUsable(), false, QueueSpellTable[1]:ID());
    HR.MainIconFrame:SetupParts(QueueTextureTable, QueueKeybindTable);
  end
  -- Main Cast Queue
  function HR.CastQueue (...)
    DisplayQueue(...);
    DisplayCooldown();
    return "Should Return";
  end
  -- Pooling Cast Queue
  function HR.CastQueuePooling (CustomTime, ...)
    DisplayQueue(...);

    -- If there is a custom time, just pass in the first spell
    if CustomTime then
      DisplayCooldown(QueueSpellTable[1], true, CustomTime)
    else
      -- Find the largest cost in the table to use as the cooldown object
      local CostObject, MaxCost = nil, 0;
      for i = 1, #QueueSpellTable do
        if QueueSpellTable[i]:Cost() > MaxCost then
          MaxCost = QueueSpellTable[i]:Cost()
          CostObject = QueueSpellTable[i]
        end
      end
      DisplayCooldown(CostObject, true)
    end

    return "Should Return";
  end

  -- Left (+ Nameplate) Cast
  HR.CastLeftOffset = 1;
  function HR.CastLeftCommon (Object)
    local Texture = HR.GetTexture(Object)
    local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(Texture);
    HR.LeftIconFrame:ChangeIcon(Texture, Keybind);
    HR.CastLeftOffset = HR.CastLeftOffset + 1;
    Object.LastDisplayTime = GetTime();
  end
  function HR.CastLeft (Object)
    if HR.CastLeftOffset == 1 then
      HR.CastLeftCommon(Object);
    end
    return false;
  end
  function HR.CastLeftNameplate (ThisUnit, Object)
    if HR.CastLeftOffset == 1 and HR.Nameplate.AddIcon(ThisUnit, Object) then
      HR.CastLeftCommon(Object);
    end
    return false;
  end

  -- Suggested Icon Cast
  HR.CastSuggestedOffset = 1;
  function HR.CastSuggested (Object, OutofRange)
    if HR.CastSuggestedOffset == 1 then
      local Texture = HR.GetTexture(Object)
      local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(Texture);
      HR.SuggestedIconFrame:ChangeIcon(Texture, Keybind, OutofRange, Object:ID());
      HR.CastSuggestedOffset = HR.CastSuggestedOffset + 1;
      Object.LastDisplayTime = GetTime();
    end
    return false;
  end

  -- Suggested Icon (Right) Cast
  HR.CastRightSuggestedOffset = 1;
  function HR.CastRightSuggested (Object, OutofRange)
    if HR.CastRightSuggestedOffset == 1 then
      local Texture = HR.GetTexture(Object)
      local Keybind = not HR.GUISettings.General.HideKeyBinds and HL.Action.TextureHotKey(Texture);
      HR.RightSuggestedIconFrame:ChangeIcon(Texture, Keybind, OutofRange, Object:ID());
      HR.CastRightSuggestedOffset = HR.CastRightSuggestedOffset + 1;
      Object.LastDisplayTime = GetTime();
    end
    return false;
  end


--- ======= COMMANDS =======
  -- Command Handler
  function HR.CmdHandler (Message)
    local Argument1, Argument2, Argument3 = strsplit(" ", stringlower(Message));
    if Argument1 == "cds" then
      HeroRotationCharDB.Toggles[1] = not HeroRotationCharDB.Toggles[1];
      HR.ToggleIconFrame:UpdateButtonText(1);
      HR.Print("CDs are now "..(HeroRotationCharDB.Toggles[1] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
    elseif Argument1 == "aoe" then
      HeroRotationCharDB.Toggles[2] = not HeroRotationCharDB.Toggles[2];
      HR.ToggleIconFrame:UpdateButtonText(2);
      HR.Print("AoE is now "..(HeroRotationCharDB.Toggles[2] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
    elseif Argument1 == "toggle" then
      HeroRotationCharDB.Toggles[3] = not HeroRotationCharDB.Toggles[3];
      HR.ToggleIconFrame:UpdateButtonText(3);
      HR.Print("HeroRotation is now "..(HeroRotationCharDB.Toggles[3] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
    elseif Argument1 == "unlock" then
      HR.MainFrame:Unlock();
      HR.Print("HeroRotation UI is now |cff00ff00unlocked|r.");
    elseif Argument1 == "lock" then
      HR.MainFrame:Lock();
      HR.Print("HeroRotation UI is now |cffff0000locked|r.");
    elseif Argument1 == "scale" then
      if Argument2 and Argument3 then
        Argument3 = tonumber(Argument3);
        if Argument3 and type(Argument3) == "number" and Argument3 > 0 and Argument3 <= 10 then
          if Argument2 == "ui" then
            HR.MainFrame:ResizeUI(Argument3);
          elseif Argument2 == "buttons" then
            HR.MainFrame:ResizeButtons(Argument3);
          elseif Argument2 == "all" then
            HR.MainFrame:ResizeUI(Argument3);
            HR.MainFrame:ResizeButtons(Argument3);
          else
            HR.Print("Invalid |cff88ff88[Type]|r for Scale.");
            HR.Print("Should be |cff8888ff/hr scale|r |cff88ff88[Type]|r |cffff8888[Size]|r.");
            HR.Print("Type accepted are |cff88ff88ui|r, |cff88ff88buttons|r, |cff88ff88all|r.");
          end
        else
          HR.Print("Invalid |cffff8888[Size]|r for Scale.");
          HR.Print("Should be |cff8888ff/hr scale|r |cff88ff88[Type]|r |cffff8888[Size]|r.");
          HR.Print("Size accepted are |cffff8888number > 0 and <= 10|r.");
        end
      else
        HR.Print("Invalid arguments for Scale.");
        HR.Print("Should be |cff8888ff/hr scale|r |cff88ff88[Type]|r |cffff8888[Size]|r.");
        HR.Print("Type accepted are |cff88ff88ui|r, |cff88ff88buttons|r, |cff88ff88all|r.");
        HR.Print("Size accepted are |cffff8888number > 0 and <= 10|r.");
      end
    elseif Argument1 == "resetbuttons" then
      HR.ToggleIconFrame:ResetAnchor();
    elseif Argument1 == "help" then
      HR.Print("|cffffff00--[Toggles]--|r");
      HR.Print("  On/Off: |cff8888ff/hr toggle|r");
      HR.Print("  CDs: |cff8888ff/hr cds|r");
      HR.Print("  AoE: |cff8888ff/hr aoe|r");
      HR.Print("|cffffff00--[User Interface]--|r");
      HR.Print("  UI Lock: |cff8888ff/hr lock|r");
      HR.Print("  UI Unlock: |cff8888ff/hr unlock|r");
      HR.Print("  UI Scale: |cff8888ff/hr scale|r |cff88ff88[Type]|r |cffff8888[Size]|r");
      HR.Print("    [Type]: |cff88ff88ui|r, |cff88ff88buttons|r, |cff88ff88all|r");
      HR.Print("    [Size]: |cffff8888number > 0 and <= 10|r");
      HR.Print("  Button Anchor Reset : |cff8888ff/hr resetbuttons|r");
    else
      HR.Print("Invalid arguments.");
      HR.Print("Type |cff8888ff/hr help|r for more infos.");
    end
  end
  SLASH_HEROROTATION1 = "/hr"
  SLASH_HEROROTATION2 = "/ar"
  SlashCmdList["HEROROTATION"] = HR.CmdHandler;

  -- Get if the CDs are enabled.
  function HR.CDsON ()
    return HeroRotationCharDB.Toggles[1];
  end

  -- Get if the AoE is enabled.
  do
    local AoEImmuneNPCID = {
      --- Legion
        ----- Dungeons (7.0 Patch) -----
        --- Mythic+ Affixes
          -- Fel Explosives (7.2 Patch)
          [120651] = true
    }
    -- Disable the AoE if we target an unit that is immune to AoE spells.
    function HR.AoEON ()
      return HeroRotationCharDB.Toggles[2] and not AoEImmuneNPCID[Target:NPCID()];
    end
  end

  -- Get if the main toggle is on.
  function HR.ON ()
    return HeroRotationCharDB.Toggles[3];
  end

  -- Get if the UI is locked.
  function HR.Locked ()
    return HeroRotationDB.Locked;
  end

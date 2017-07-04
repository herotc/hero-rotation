--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AR = ...;
  -- AethysCore
  local AC = AethysCore;
  -- File Locals



--- ============================ CONTENT ============================
  AR.GUI = {};
  function AR.GUI.LoadSettingsRecursively (Table, KeyChain)
    local KeyChain = KeyChain or "";
    for Key, Value in pairs(Table) do
      -- Generate the NewKeyChain
      local NewKeyChain;
      if KeyChain ~= "" then
        NewKeyChain = KeyChain .. "." .. Key;
      else
        NewKeyChain = Key;
      end
      -- Continue the table browsing
      if type(Value) == "table" then
        AR.GUI.LoadSettingsRecursively(Value, NewKeyChain);
      -- Update the value
      else
        local DBSetting = AethysRotationDB.GUISettings[NewKeyChain];
        -- Take the saved value
        if DBSetting ~= nil then
          Table[Key] = DBSetting;
        -- Save the default value
        else
          AethysRotationDB.GUISettings[NewKeyChain] = Value;
        end
      end
    end
  end

# Intended for use developing Syn's alternate WW file.
# python3 swap_experimental.lua
# will go back and forth as appropriate.
import os


if __name__ == "__main__":
    if os.path.exists("Windwalker_OLD.lua"):
        os.rename("Windwalker.lua", "Windwalker_EXPERIMENTAL.lua")
        os.rename("Windwalker_OLD.lua", "Windwalker.lua")
    else:
        os.rename("Windwalker.lua", "Windwalker_OLD.lua")
        os.rename("Windwalker_EXPERIMENTAL.lua", "Windwalker.lua")

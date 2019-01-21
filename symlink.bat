REM Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
REM WoWRep  : World of warcraft main directory
REM GHRep   : Where your github projects are stored (by default in Documents/GitHub)
set WoWRep="G:\World of Warcraft"
set GHRep="C:\Users\justi\Documents\GitHub"


REM Don't touch anything bellow this if you aren't experienced

mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroLib" %GHRep%"\hero-lib\HeroLib"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroCache" %GHRep%"\hero-lib\HeroCache"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation" %GHRep%"\hero-rotation\HeroRotation"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_DeathKnight" %GHRep%"\hero-rotation\HeroRotation_DeathKnight"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_DemonHunter" %GHRep%"\hero-rotation\HeroRotation_DemonHunter"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Druid" %GHRep%"\hero-rotation\HeroRotation_Druid"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Hunter" %GHRep%"\hero-rotation\HeroRotation_Hunter"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Mage" %GHRep%"\hero-rotation\HeroRotation_Mage"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Monk" %GHRep%"\hero-rotation\HeroRotation_Monk"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Paladin" %GHRep%"\hero-rotation\HeroRotation_Paladin"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Priest" %GHRep%"\hero-rotation\HeroRotation_Priest"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Rogue" %GHRep%"\hero-rotation\HeroRotation_Rogue"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Shaman" %GHRep%"\hero-rotation\HeroRotation_Shaman"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Warrior" %GHRep%"\hero-rotation\HeroRotation_Warrior"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Warlock" %GHRep%"\hero-rotation\HeroRotation_Warlock"
REM mklink /J %WoWRep%"\_retail_\Interface\AddOns\AethysTools" %GHRep%"\AethysTools"

pause

REM Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
REM WoWRep  : World of warcraft main directory
REM GHRep   : Where you github project are stored (by default in mydocuments/Github)
set WoWRep="D:\World of Warcraft"
set GHRep="D:\My documents\GitHub"


REM don't touch anything bellow this
mklink /J %WoWRep%"\Interface\AddOns\HeroLib" %GHRep%"\hero-lib\HeroLib"
mklink /J %WoWRep%"\Interface\AddOns\HeroCache" %GHRep%"\hero-lib\HeroCache"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation" %GHRep%"\hero-rotation\HeroRotation"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_DeathKnight" %GHRep%"\hero-rotation\HeroRotation_DeathKnight"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_DemonHunter" %GHRep%"\hero-rotation\HeroRotation_DemonHunter"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Druid" %GHRep%"\hero-rotation\HeroRotation_Druid"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Hunter" %GHRep%"\hero-rotation\HeroRotation_Hunter"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Mage" %GHRep%"\hero-rotation\HeroRotation_Mage"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Monk" %GHRep%"\hero-rotation\HeroRotation_Monk"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Paladin" %GHRep%"\hero-rotation\HeroRotation_Paladin"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Priest" %GHRep%"\hero-rotation\HeroRotation_Priest"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Rogue" %GHRep%"\hero-rotation\HeroRotation_Rogue"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Shaman" %GHRep%"\hero-rotation\HeroRotation_Shaman"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Warrior" %GHRep%"\hero-rotation\HeroRotation_Warrior"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Warlock" %GHRep%"\hero-rotation\HeroRotation_Warlock"
mklink /J %WoWRep%"\Interface\AddOns\AethysTools" %GHRep%"\AethysTools"

pause

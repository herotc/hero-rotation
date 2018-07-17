REM Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
REM WoWRep  : World of warcraft main directory
REM GHRep   : Where you github project are stored (by default in mydocuments/Github)
set WoWRep="D:\World of Warcraft"
set GHRep="D:\My documents\GitHub"


REM don't touch anything bellow this
mklink /J %WoWRep%"\Interface\AddOns\HeroLib" %GHRep%"\hero-lib\HeroLib"
mklink /J %WoWRep%"\Interface\AddOns\HeroCache" %GHRep%"\hero-lib\HeroCache"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation" %GHRep%"\HeroRotation\HeroRotation"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_DeathKnight" %GHRep%"\HeroRotation\HeroRotation_DeathKnight"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_DemonHunter" %GHRep%"\HeroRotation\HeroRotation_DemonHunter"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Druid" %GHRep%"\HeroRotation\HeroRotation_Druid"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Hunter" %GHRep%"\HeroRotation\HeroRotation_Hunter"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Mage" %GHRep%"\HeroRotation\HeroRotation_Mage"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Monk" %GHRep%"\HeroRotation\HeroRotation_Monk"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Paladin" %GHRep%"\HeroRotation\HeroRotation_Paladin"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Priest" %GHRep%"\HeroRotation\HeroRotation_Priest"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Rogue" %GHRep%"\HeroRotation\HeroRotation_Rogue"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Shaman" %GHRep%"\HeroRotation\HeroRotation_Shaman"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Warrior" %GHRep%"\HeroRotation\HeroRotation_Warrior"
mklink /J %WoWRep%"\Interface\AddOns\HeroRotation_Warlock" %GHRep%"\HeroRotation\HeroRotation_Warlock"
mklink /J %WoWRep%"\Interface\AddOns\AethysTools" %GHRep%"\AethysTools"

pause

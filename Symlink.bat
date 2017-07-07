REM Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
REM WoWRep  : World of warcraft main directory
REM GHRep   : Where you github project are stored (by default in mydocuments/Github)
set WoWRep="D:\World of Warcraft"
set GHRep="D:\My documents\GitHub"


REM don't touch anything bellow this
mklink /J %WoWRep%"\Interface\AddOns\AethysCore" %GHRep%"\AethysCore\AethysCore"
mklink /J %WoWRep%"\Interface\AddOns\AethysCache" %GHRep%"\AethysCore\AethysCache"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation" %GHRep%"\AethysRotation\AethysRotation"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_DeathKnight" %GHRep%"\AethysRotation\AethysRotation_DeathKnight"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_DemonHunter" %GHRep%"\AethysRotation\AethysRotation_DemonHunter"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Druid" %GHRep%"\AethysRotation\AethysRotation_Druid"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Hunter" %GHRep%"\AethysRotation\AethysRotation_Hunter"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Mage" %GHRep%"\AethysRotation\AethysRotation_Mage"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Monk" %GHRep%"\AethysRotation\AethysRotation_Monk"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Paladin" %GHRep%"\AethysRotation\AethysRotation_Paladin"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Priest" %GHRep%"\AethysRotation\AethysRotation_Priest"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Rogue" %GHRep%"\AethysRotation\AethysRotation_Rogue"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Shaman" %GHRep%"\AethysRotation\AethysRotation_Shaman"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Warrior" %GHRep%"\AethysRotation\AethysRotation_Warrior"
mklink /J %WoWRep%"\Interface\AddOns\AethysRotation_Warlock" %GHRep%"\AethysRotation\AethysRotation_Warlock"
'mklink /J %WoWRep%"\Interface\AddOns\AethysTools" %GHRep%"\AethysTools"

pause

REM Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
REM WoWRep  : World of warcraft main directory
REM GHRep   : Where your github projects are stored (by default in Documents/GitHub)
set WoWRep="c:\Spiele\World of Warcraft"
set CWD=%cd%

REM Don't touch anything bellow this if you aren't experienced
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation" %CWD%"\HeroRotation"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_DeathKnight" %CWD%"\HeroRotation_DeathKnight"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_DemonHunter" %CWD%"\HeroRotation_DemonHunter"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Druid" %CWD%"\HeroRotation_Druid"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Hunter" %CWD%"\HeroRotation_Hunter"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Mage" %CWD%"\HeroRotation_Mage"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Monk" %CWD%"\HeroRotation_Monk"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Paladin" %CWD%"\HeroRotation_Paladin"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Priest" %CWD%"\HeroRotation_Priest"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Rogue" %CWD%"\HeroRotation_Rogue"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Shaman" %CWD%"\HeroRotation_Shaman"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Warrior" %CWD%"\HeroRotation_Warrior"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Warlock" %CWD%"\HeroRotation_Warlock"

pause

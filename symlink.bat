REM Modify the WoWRep var so it match you own setup. Make sure you have it surrounded by double quotes
REM WoWRep  : World of warcraft main directory
set WoWRep="C:\Program Files (x86)\World of Warcraft"
set CWD=%cd%

REM Don't touch anything bellow this if you aren't experienced
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation" %CWD%"\hero-rotation\HeroRotation"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_DeathKnight" %CWD%"\hero-rotation\HeroRotation_DeathKnight"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_DemonHunter" %CWD%"\hero-rotation\HeroRotation_DemonHunter"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Druid" %CWD%"\hero-rotation\HeroRotation_Druid"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Hunter" %CWD%"\hero-rotation\HeroRotation_Hunter"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Mage" %CWD%"\hero-rotation\HeroRotation_Mage"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Monk" %CWD%"\hero-rotation\HeroRotation_Monk"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Paladin" %CWD%"\hero-rotation\HeroRotation_Paladin"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Priest" %CWD%"\hero-rotation\HeroRotation_Priest"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Rogue" %CWD%"\hero-rotation\HeroRotation_Rogue"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Shaman" %CWD%"\hero-rotation\HeroRotation_Shaman"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Warrior" %CWD%"\hero-rotation\HeroRotation_Warrior"
mklink /J %WoWRep%"\_retail_\Interface\AddOns\HeroRotation_Warlock" %CWD%"\hero-rotation\HeroRotation_Warlock"

pause

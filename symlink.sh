#!/bin/bash

# Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
# WoWRep  : World of warcraft main directory
# GHRep   : Where you github project are stored (by default in mydocuments/Github)
WoWRep="/Applications/World of Warcraft"
GHRep=$(pwd)

# Don't touch anything bellow this
#ln -s "$GHRep/hero-lib/HeroLib" "$WoWRep/Interface/AddOns/HeroLib"
#ln -s "$GHRep/AethysCore/AethysCache" "$WoWRep/Interface/AddOns/AethysCache"
ln -s "$GHRep/AethysRotation" "$WoWRep/Interface/AddOns/AethysRotation"
ln -s "$GHRep/AethysRotation_DeathKnight" "$WoWRep/Interface/AddOns/AethysRotation_DeathKnight"
ln -s "$GHRep/AethysRotation_DemonHunter" "$WoWRep/Interface/AddOns/AethysRotation_DemonHunter"
ln -s "$GHRep/AethysRotation_Druid" "$WoWRep/Interface/AddOns/AethysRotation_Druid"
ln -s "$GHRep/AethysRotation_Hunter" "$WoWRep/Interface/AddOns/AethysRotation_Hunter"
ln -s "$GHRep/AethysRotation_Mage" "$WoWRep/Interface/AddOns/AethysRotation_Mage"
ln -s "$GHRep/AethysRotation_Monk" "$WoWRep/Interface/AddOns/AethysRotation_Monk"
ln -s "$GHRep/AethysRotation_Paladin" "$WoWRep/Interface/AddOns/AethysRotation_Paladin"
ln -s "$GHRep/AethysRotation_Priest" "$WoWRep/Interface/AddOns/AethysRotation_Priest"
ln -s "$GHRep/AethysRotation_Rogue" "$WoWRep/Interface/AddOns/AethysRotation_Rogue"
ln -s "$GHRep/AethysRotation_Shaman" "$WoWRep/Interface/AddOns/AethysRotation_Shaman"
ln -s "$GHRep/AethysRotation_Warrior" "$WoWRep/Interface/AddOns/AethysRotation_Warrior"
ln -s "$GHRep/AethysRotation_Warlock" "$WoWRep/Interface/AddOns/AethysRotation_Warlock"
#ln -s "$GHRep/AethysTools" "$WoWRep/Interface/AddOns/AethysTools"

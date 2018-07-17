#!/bin/bash

# Modify the two vars so it match you own setup. Make sure you have it surrounded by double quotes
# WoWRep  : World of warcraft main directory
# GHRep   : Where you github project are stored (by default in mydocuments/Github)
WoWRep="/Applications/World of Warcraft"
GHRep=$(pwd)

# Don't touch anything bellow this
#ln -s "$GHRep/../hero-lib/HeroLib" "$WoWRep/Interface/AddOns/HeroLib"
#ln -s "$GHRep/../hero-lib/HeroCache" "$WoWRep/Interface/AddOns/HeroCache"
ln -s "$GHRep/HeroRotation" "$WoWRep/Interface/AddOns/HeroRotation"
ln -s "$GHRep/HeroRotation_DeathKnight" "$WoWRep/Interface/AddOns/HeroRotation_DeathKnight"
ln -s "$GHRep/HeroRotation_DemonHunter" "$WoWRep/Interface/AddOns/HeroRotation_DemonHunter"
ln -s "$GHRep/HeroRotation_Druid" "$WoWRep/Interface/AddOns/HeroRotation_Druid"
ln -s "$GHRep/HeroRotation_Hunter" "$WoWRep/Interface/AddOns/HeroRotation_Hunter"
ln -s "$GHRep/HeroRotation_Mage" "$WoWRep/Interface/AddOns/HeroRotation_Mage"
ln -s "$GHRep/HeroRotation_Monk" "$WoWRep/Interface/AddOns/HeroRotation_Monk"
ln -s "$GHRep/HeroRotation_Paladin" "$WoWRep/Interface/AddOns/HeroRotation_Paladin"
ln -s "$GHRep/HeroRotation_Priest" "$WoWRep/Interface/AddOns/HeroRotation_Priest"
ln -s "$GHRep/HeroRotation_Rogue" "$WoWRep/Interface/AddOns/HeroRotation_Rogue"
ln -s "$GHRep/HeroRotation_Shaman" "$WoWRep/Interface/AddOns/HeroRotation_Shaman"
ln -s "$GHRep/HeroRotation_Warrior" "$WoWRep/Interface/AddOns/HeroRotation_Warrior"
ln -s "$GHRep/HeroRotation_Warlock" "$WoWRep/Interface/AddOns/HeroRotation_Warlock"
#ln -s "$GHRep/../AethysTools" "$WoWRep/Interface/AddOns/AethysTools"

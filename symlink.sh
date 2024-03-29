#!/usr/bin/env bash

# Modify the WoWRep var so it match you own setup. Make sure you have it surrounded by double quotes
# WoWRep  : World of warcraft main directory
WoWRep="/Applications/World of Warcraft"
CWD=$(pwd)

# Don't touch anything bellow this if you aren't experienced
ln -s "$CWD/../hero-rotation/HeroRotation" "$WoWRep/_retail_/Interface/AddOns/HeroRotation"
ln -s "$CWD/../hero-rotation/HeroRotation_DeathKnight" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_DeathKnight"
ln -s "$CWD/../hero-rotation/HeroRotation_DemonHunter" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_DemonHunter"
ln -s "$CWD/../hero-rotation/HeroRotation_Druid" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Druid"
ln -s "$CWD/../hero-rotation/HeroRotation_Evoker" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Evoker"
ln -s "$CWD/../hero-rotation/HeroRotation_Hunter" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Hunter"
ln -s "$CWD/../hero-rotation/HeroRotation_Mage" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Mage"
ln -s "$CWD/../hero-rotation/HeroRotation_Monk" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Monk"
ln -s "$CWD/../hero-rotation/HeroRotation_Paladin" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Paladin"
ln -s "$CWD/../hero-rotation/HeroRotation_Priest" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Priest"
ln -s "$CWD/../hero-rotation/HeroRotation_Rogue" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Rogue"
ln -s "$CWD/../hero-rotation/HeroRotation_Shaman" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Shaman"
ln -s "$CWD/../hero-rotation/HeroRotation_Warrior" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Warrior"
ln -s "$CWD/../hero-rotation/HeroRotation_Warlock" "$WoWRep/_retail_/Interface/AddOns/HeroRotation_Warlock"

**If you are using Curse Client V5, please update it to Twitch Client or download manually the addon, it's not longer supported by Curse and contains bugged updates.**

**If you are experiencing issues with AoE rotation (likely Abilities not being recommended), be sure to have enemies nameplates enabled and enough nameplate shown (camera can hide them).**

# AethysRotation

AethysRotation is a World of Warcraft addon to provide the player useful and precise information to execute the best possible DPS rotation in every situation.
The project is hosted on [GitHub](https://github.com/SimCMinMax/AethysRotation) and powered by [AethysCore](https://github.com/SimCMinMax/AethysCore).
It is maintained by [Aethys](https://github.com/Aethys256/) and the [SimCMinMax](https://github.com/orgs/SimCMinMax/people) team.
Also, you can find it on [Curse](https://mods.curse.com/project/103143) and [CurseForge](https://www.curseforge.com/projects/103143/).

**There are a lot of helpful commands, do '/aer help' to see them in-game !
Although, most of the commands and options are being moving to Addons Panels, you can see them by going into Interface -> Addons -> AethysRotation.**

Feel free to join our [Discord](https://discord.gg/tFR2uvK). Feedback is highly appreciated !

## Key Features
- Main Icon that shows the next ability you should cast.
- Two smaller icons above the previous one that shows the useful OffGCD abilities to use.
- One medium icon on the left that shows every ability that should be cycled (i.e. multi-dotting).
- One medium-small icon on the upper-left that does proposals about situational abilities (trinkets, potions, ...).
- Toggles to turn On/Off the CDs or AoE to adjust the rotation according to the situation (the addon can be disabled this way aswell).

_Toggles can now use directly key bindings, set them in 'Game Menu -> Key Bindings -> AddOns'_

Every rotation is based on [SimulationCraft](http://simulationcraft.org/) [Action Priority Lists](https://github.com/simulationcraft/simc/wiki/ActionLists).

## Special Features
- Handle both Single Target and AoE rotations (it auto adapts).
- Optimized pooling of resources when needed (ex: energy before using cooldowns as a rogue).
- Accurate TimeToDie prediction.
- Next cast prediction for casters.
- Special handlers for tricky abilities (ex: Finality or Exsanguinated bleeds for rogues).
- Solo Mode to prioritize survivability over DPS. (If implemented in the rotation)

## Supported Rotations
- Death Knight Frost ([chrislopez24](https://github.com/chrislopez24) & [3L00DStrike](https://github.com/3L00DStrike))
- Death Knight Unholy ([chrislopez24](https://github.com/chrislopez24))
- Demon Hunter Vengeance **[Outdated]**
- Druid Balance ([KutiKuti](https://github.com/Kutikuti)) **[WIP]**
- Hunter BeastMastery ([Nia](https://github.com/Nianel))
- Hunter Marskmanship ([Nia](https://github.com/Nianel))
- Hunter Survival ([Nia](https://github.com/Nianel))
- Mage Frost ([Glynny](https://github.com/Glynnyx) & [Zulandia](https://github.com/AlexanderKenny) & [Nia](https://github.com/Nianel))
- Monk Windwalker ([Lockem90](https://github.com/Lockem90))
- Paladin Protection ([Aethys](https://github.com/Aethys256) & [chrislopez24](https://github.com/chrislopez24))
- Paladin Retribution ([Aethys](https://github.com/Aethys256))
- Priest Shadow ([KutiKuti](https://github.com/Kutikuti))
- Rogue Assassination ([Aethys](https://github.com/Aethys256) & [Mystler](https://github.com/Mystler))
- Rogue Outlaw ([Aethys](https://github.com/Aethys256) & [Mystler](https://github.com/Mystler))
- Rogue Subtlety ([Aethys](https://github.com/Aethys256) & [Mystler](https://github.com/Mystler))
- Shaman Elemental ([lithium720](https://github.com/lithium720)) **[WIP]**
- Shaman Enhancement ([lithium720](https://github.com/lithium720) & [Tael](https://github.com/Tae-l))
- Warlock Demonology ([KutiKuti](https://github.com/Kutikuti))
- Warlock Destruction ([KutiKuti](https://github.com/Kutikuti))
- Warrior Arms ([lithium720](https://github.com/lithium720))
- Warrior Fury ([Lockem90](https://github.com/Lockem90) & [Nia](https://github.com/Nianel))

## Special Mention About SimC APL
As said earlier, every rotation is based on SimulationCraft Action Priority Lists (APL).
What it means is, it heavily relies on how optimized those APLs are, especially for some talents, tier bonuses and legendaries support.
Do remember that what the addon tells you is what the "robot" on SimulationCraft would do in your situation.
It also means that you can improve the current APL by using the addon and report the issues you might encounter.
I (Aethys) am one of the main Rogue theorycrafter and contributor to the SimulationCraft Rogue Module, both SimC APL and Addon Rotation are 100% synced. I use both tools to improve the APL and do Rogue Theorycrafting.

## Special Thanks
- [SimulationCraft](http://simulationcraft.org/) for everything the project gives to the whole WoW Community.
- [KutiKuti](https://github.com/Kutikuti) & [Nia](https://github.com/Nianel) for their daily support.
- [Skasch](https://github.com/skasch) for what we built together and the motivation he gave to me.
- [Riff](https://github.com/tombell) for his great feedback and UI tweaks.
- [Mystler](https://github.com/Mystler) for his help on everything related to rogues that frees me a lot of time.
- [lithium720](https://github.com/lithium720), [Lockem90](https://github.com/Lockem90), [3L00DStrike](https://github.com/3L00DStrike), [chrislopez24](https://github.com/chrislopez24), [Zulandia](https://github.com/AlexanderKenny), [Glynny](https://github.com/orgs/SimCMinMax/people/Glynnyx) for the daily maintenance of rotations.
- [Tael](https://github.com/Tae-l) for his past contributions.

## Advanced Users / Developper Notes
If you want to use the addon directly from the [GitHub repository](https://github.com/SimCMinMax/AethysRotation), you would have to symlink every folders from this repository (AethysRotation folder and every class modules but the template) to your WoW Addons folder.
Furthermore, to make it working, you need to add the only dependency that is [AethysCore](https://github.com/SimCMinMax/AethysCore) following the same processus (symlink AethysCore & AethysCache from the repository).
There is a script that does this for you, open symlink.bat and modify the two vars (WoWRep and GHRep) to match your local setup.
Make sure AethysRotation's directories doesn't already exist as it will not override them.
Finally, launch symlink.bat

Stay tuned !

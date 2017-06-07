# AethysRotation

AethysRotation is a World of Warcraft addon to provide the player useful and precise information to execute the best possible DPS rotation in every situation.
The project is hosted on [GitHub](https://github.com/SimCMinMax/AethysRotation) and powered by [AethysCore](https://github.com/SimCMinMax/AethysRotation).
It is maintained by [Aethys](https://github.com/Aethys256/) and the [SimCMinMax](https://github.com/orgs/SimCMinMax/people) team.
Also, you can find it on [Curse](https://mods.curse.com/addons/wow/aethysrotation) and [CurseForge](https://wow.curseforge.com/projects/aethysrotation).

_There are a lot of helpful commands, do '/aer help' to see them in-game !_

Feel free to join our [Discord](https://discord.gg/tFR2uvK). Feedback is highly appreciated !

## Key Features
- Main Icon that shows the next ability you should cast.
- Two smaller icons above the previous one that shows the useful CDs/OffGCD-Abilities to use.
- One medium icon on the left that shows every ability that should be cycled (i.e. multi-dotting).
- One medium-small icon on the upper-left that does proposals about situational abilities (trinkets, potions, ...).
- Toggles to turn On/Off the CDs or AoE to adjust the rotation according to the situation (the addon can be disabled this way aswell).

_Toggles can now use directly key bindings, set them in 'Game Menu -> Key Bindings -> AddOns'_

Every rotation is based on [SimulationCraft](http://simulationcraft.org/) [Action Priority Lists](https://github.com/simulationcraft/simc/wiki/ActionLists).

## Special Features
- Handle both Single Target and AoE rotations (it auto adapts).
- Optimized Pooling of resources when needed (ex: energy before using cooldowns for Rogue).
- Accurate TimeToDie prediction.
- Next cast prediction for Casters.
- Special handlers for tricky abilities (ex: Finality or Exsanguinated Bleed for Rogue).
- Solo Mode to prioritize survivability over DPS.

## Supported Rotations
- Death Knight Frost _[Beta]_ (Credits: [3L00DStrike](https://github.com/3L00DStrike))
- Demon Hunter Vengeance _[Beta]_
- Hunter BeastMastery (Credits: [Nia](https://github.com/Nianel))
- Hunter Marskmanship _[Beta]_ (Credits: [Nia](https://github.com/Nianel))
- Hunter Survival (Credits: [Nia](https://github.com/Nianel))
- Paladin Retribution _[Outdated]_
- Priest Shadow (Credits: [KutiKuti](https://github.com/Kutikuti))
- Rogue Assassination
- Rogue Outlaw
- Rogue Subtlety
- Shaman Enhancement (Credits: [Tael](https://github.com/Tae-l))
- Warrior Fury _[Beta]_ (Credits: [Nia](https://github.com/Nianel))

## Special Mention About SimC APL
As said earlier, every rotation is based on SimulationCraft Action Priority Lists (APL).
What it means is, it heavily relies on how optimized those APLs are, especially for some talents, tier bonuses and legendaries support.
Do remember that what the addon tells you is what the "robot" on SimulationCraft would do if they were in your situation.
It also means that you can improve the current APL by using the addon and report the issues you might encounter.
I (Aethys) am one of the main Rogue theorycrafter and contributor to the SimulationCraft Rogue Module, both SimC APL and Addon Rotation are 100% synced. I use both tools to improve the APL and do Rogue Theorycrafting.

## Special Thanks
- [SimulationCraft](http://simulationcraft.org/) for everything the project gives to the whole WoW Community.
- [KutiKuti](https://github.com/Kutikuti), [Nia](https://github.com/Nianel) & [Tael](https://github.com/Tae-l) for their contributions to the project.
- [Skasch](https://github.com/skasch) for what we built together and the motivation he gave to me.
- [Riff](https://github.com/tombell) for his great feedback.


More features including a GUI are coming when more rotations will be done. Currently every rotation settings are in the Settings.lua file.
Stay tuned !

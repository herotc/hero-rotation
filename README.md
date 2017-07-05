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
- Death Knight Frost **7.2.5 Ready** (Credits: [3L00DStrike](https://github.com/3L00DStrike))
- Death Knight Unholy **7.2.5 Ready** (Credits: [chrislopez24](https://github.com/chrislopez24))
- Demon Hunter Vengeance _Outdated?_
- Hunter BeastMastery **7.2.5 Ready** (Credits: [Nia](https://github.com/Nianel))
- Hunter Marskmanship **7.2.5 Ready** (Credits: [Nia](https://github.com/Nianel))
- Hunter Survival **7.2.5 Ready** (Credits: [Nia](https://github.com/Nianel))
- Monk Windwalker (Credits: [Lockem90](https://github.com/Lockem90))
- Paladin Retribution **7.2.5 Ready**
- Priest Shadow **7.2.5 Ready** (Credits: [KutiKuti](https://github.com/Kutikuti))
- Rogue Assassination **7.2.5 Ready**
- Rogue Outlaw **7.2.5 Ready**
- Rogue Subtlety **7.2.5 Ready**
- Shaman Enhancement **7.2.5 Ready** (Credits: [Tael](https://github.com/Tae-l) & [lithium720](https://github.com/lithium720))
- Warlock Destruction beta **7.2.5 Ready** (Credits: [KutiKuti](https://github.com/Kutikuti))
- Warlock Demonology beta **7.2.5 Ready** (Credits: [KutiKuti](https://github.com/Kutikuti))
- Warrior Fury (Credits: [Nia](https://github.com/Nianel) & [Lockem90](https://github.com/Lockem90))
- Warrior Arms **7.2.5 Ready** (Credits: [lithium720](https://github.com/lithium720))

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

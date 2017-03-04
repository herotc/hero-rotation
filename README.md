# AethysRotation

AethysRotation is a World of Warcraft addon to provide the player useful and precise information to execute the best possible DPS rotation in every situation.
The project is hosted on [GitHub](https://github.com/Aethys256/AethysRotation) and powered by [AethysCore](https://github.com/Aethys256/AethysRotation).
It is maintained by [Aethys](https://github.com/Aethys256/) and the [SimCMinMax](https://github.com/orgs/SimCMinMax/people) team.
Also, you can find it on [Curse](https://mods.curse.com/addons/wow/aethysrotation) and [CurseForge](https://wow.curseforge.com/projects/aethysrotation).

_There are a lot of helpful commands, do '/aer help' to see them in-game !._

Feel free to join our [Discord](https://discord.gg/tFR2uvK). Feedback is highly appreciated !

## Key Features
- Main Icon that shows the next ability you should cast.
- Two smaller icons above the previous one that shows the useful CDs/OffGCD-Abilities to use.
- One medium icon on the left that shows every abilities that should be cycled (i.e. multi-dotting).
- One medium-small icon on the upper-left that do proposals about situational abilities (trinkets, potions, ...).

Every rotations are based on [SimulationCraft](http://simulationcraft.org/) [Action Priority Lists](https://github.com/simulationcraft/simc/wiki/ActionLists).

## Special Features
- Handle both Single Target and AoE rotations (it auto adapts).
- Optimized Pooling of Ressources when needed (ex: Energy before Cooldowns for Rogue).
- Accurate TimeToDie Prediction.
- Next Cast Prediction for Casters.
- Special handlers for tricky abilities (ex: Finality or Exsanguinated Bleed for Rogue).
- Solo Mode to improve the survivability to the detriment of DPS.

## Supported Rotations
- Demon Hunter Vengeance _[Beta]_
- Hunter BeastMastery (Credits: [Nia](https://github.com/Nianel))
- Hunter Survival (Credits: [Nia](https://github.com/Nianel))
- Paladin Retribution _[Beta]_
- Priest Shadow _[Beta]_ (Credits: [KutiKuti](https://github.com/Kutikuti))
- Rogue Assassination
- Rogue Outlaw
- Rogue Subtlety
- Shaman Enhancement _[Beta]_ (Credits: [Tael](https://github.com/Tae-l))

## Special Mention About SimC APL
As said earlier, every rotations are based on Simulationcraft Action Priority Lists (APL).
What does it means is, it heavily relies on how optimized those APLs are, especially for some talents, tier bonuses and legendaries support.
Do remember that what the addon tells you is what the "robot" on Simulationcraft would do if he was in your situation.
It also means that you can improve the current APL by using the addon and reporting the issues you might encounter.
I (Aethys) am one of the Main Rogue Theorycrafter and contributor to the Simulationcraft Rogue Module, both SimC APL and Addon Rotation are 100% synced. I use both tools to improve the APL and do Rogue Theorycrafting.

## Special Thanks
- [Simulationcraft](http://simulationcraft.org/) for everything the project gives to the whole WoW Community.
- [KutiKuti](https://github.com/Kutikuti), [Nia](https://github.com/Nianel) & [Tael](https://github.com/Tae-l) for their contributions to the project.
- [Skasch](https://github.com/skasch) for what we built together and the motivation he gaves to me.
- [Riff](https://github.com/tombell) for his great feedback.


More features including a GUI are coming when more rotations will be done. Currently every rotation settings are in the Settings.lua file.
Stay tuned !

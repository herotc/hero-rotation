
**If you are using Curse Client V5, please upgrade to Twitch Client or download manually the addon, it's no longer supported by Curse and contains bugged updates.**

**If you are experiencing issues with AoE rotation (likely Abilities not being recommended), be sure to have enemies nameplates enabled and enough nameplates shown (camera can hide them).**

# AethysRotation
[![GitHub license](https://img.shields.io/badge/license-EUPL-blue.svg)](https://raw.githubusercontent.com/SimCMinMax/AethysRotation/master/LICENSE) [![GitHub forks](https://img.shields.io/github/forks/SimCMinMax/AethysRotation.svg)](https://github.com/SimCMinMax/AethysRotation/network) [![GitHub stars](https://img.shields.io/github/stars/SimCMinMax/AethysRotation.svg)](https://github.com/SimCMinMax/AethysRotation/stargazers) [![GitHub issues](https://img.shields.io/github/issues/SimCMinMax/AethysRotation.svg)](https://github.com/SimCMinMax/AethysRotation/issues)

AethysRotation is a World of Warcraft addon to provide the player useful and precise information to execute the best possible DPS rotation in every situation at max level.
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
| Class        | Specs                                                                                 |                                                                                   |                                                                                 |
| :---         | :---                                                                                  | :---                                                                              | :---                                                                            |
| Death Knight | [![Blood](https://img.shields.io/badge/Blood-OK-brightgreen.svg)]()                   | [![Frost](https://img.shields.io/badge/Frost-OK-brightgreen.svg)]()               | [![Unholy](https://img.shields.io/badge/Unholy-OK-brightgreen.svg)]()           |
| Demon Hunter | [![Vengeance](https://img.shields.io/badge/Vengeance-OK-brightgreen.svg)]()                 | [![Havoc](https://img.shields.io/badge/Havoc-OK-brightgreen.svg)]()               |                                                                                 |
| Druid        | [![Balance](https://img.shields.io/badge/Balance-OK-brightgreen.svg)]()               | [![Guardian](https://img.shields.io/badge/Guardian-OK-brightgreen.svg)]()         | [![Feral](https://img.shields.io/badge/Feral-OK-brightgreen.svg)]()             |
| Hunter       | [![Beast Mastery](https://img.shields.io/badge/Beast%20Mastery-OK-brightgreen.svg)]() | [![Marksmanship](https://img.shields.io/badge/Marksmanship-OK-brightgreen.svg)]() | [![Survival](https://img.shields.io/badge/Survival-OK-brightgreen.svg)]()       |
| Mage         | [![Frost](https://img.shields.io/badge/Frost-OK-brightgreen.svg)]()                   | [![Fire](https://img.shields.io/badge/Fire-OK-brightgreen.svg)]()                     | [![Arcane](https://img.shields.io/badge/Arcane-OK-brightgreen.svg)]()               |
| Monk         | [![Brewmaster](https://img.shields.io/badge/Brewmaster-OK-brightgreen.svg)]()         | [![Windwalker](https://img.shields.io/badge/Windwalker-OK-brightgreen.svg)]()     |                                                                                 |
| Paladin      | [![Protection](https://img.shields.io/badge/Protection-OK-brightgreen.svg)]()         | [![Retribution](https://img.shields.io/badge/Retribution-OK-brightgreen.svg)]()   |                                                                                 |
| Priest       | [![Shadow](https://img.shields.io/badge/Shadow-OK-brightgreen.svg)]()                 |                                                                                   |                                                                                 |
| Rogue        | [![Assassination](https://img.shields.io/badge/Assassination-OK-brightgreen.svg)]()   | [![Outlaw](https://img.shields.io/badge/Outlaw-OK-brightgreen.svg)]()             | [![Subtlety](https://img.shields.io/badge/Subtlety-OK-brightgreen.svg)]()       |
| Shaman       | [![Elemental](https://img.shields.io/badge/Elemental-OK-brightgreen.svg)]()           | [![Enhancement](https://img.shields.io/badge/Enhancement-OK-brightgreen.svg)]()   |                                                                                 |
| Warlock      | [![Affliction](https://img.shields.io/badge/Affliction-OK-brightgreen.svg)]()         | [![Demonology](https://img.shields.io/badge/Demonology-OK-brightgreen.svg)]()     | [![Destruction](https://img.shields.io/badge/Destruction-OK-brightgreen.svg)]() |
| Warrior      | [![Arms](https://img.shields.io/badge/Arms-OK-brightgreen.svg)]()                     | [![Fury](https://img.shields.io/badge/Fury-OK-brightgreen.svg)]()                 |                                                                                 |

## Support the team
| Name                                        | Maintaining                    | Since     | Donate                                                                                                    | Watch                                                                                                |
| :---                                        | :---                           | ---:      | :---:                                                                                                     | :---:                                                                                                |
| [Aethys](https://github.com/Aethys256)      | Core, Rogue, Tanks             |  Aug 2016 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/Aethys/5)        | [![Stream](https://img.shields.io/badge/Stream-Twitch-6441a4.svg)](https://www.twitch.tv/aethys)     |
| [Nia](https://github.com/Nianel)            | Hunter, Fury                   |  Feb 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/Nianel/5)        | [![Stream](https://img.shields.io/badge/Stream-Twitch-6441a4.svg)](https://www.twitch.tv/nianel)     |
| [KutiKuti](https://github.com/Kutikuti)     | Core, Priest, Warlock, Balance |  Mar 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/kutikuti/5)      |                                                                                                      |
| [Mystler](https://github.com/Mystler)       | Rogue                          |  May 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/Mystler/5)       |                                                                                                      |
| [Krich](https://github.com/chrislopez24)    | Death Knight                   |  Jun 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/krige/5)         |                                                                                                      |
| [Lithium](https://github.com/lithium720)    | Shaman, Arms                   |  Jun 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/lithium720/5)    | [![Stream](https://img.shields.io/badge/Stream-Twitch-6441a4.svg)](https://www.twitch.tv/lithium720) |
| [Glynny](https://github.com/Glynnyx)        | Mage                           |  Aug 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/Glynnyx/5)       | [![Stream](https://img.shields.io/badge/Stream-Twitch-6441a4.svg)](https://www.twitch.tv/glynnylol)   |
| [Kojiyama](https://github.com/EvanMichaels) | Havoc, Rogue                   |  Sep 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/kojiyama/5)      |                                                                                                      |
| [Blackytemp](https://github.com/ghr74)      | Feral, Rogue, Fire             |  Oct 2017 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/blackytempdev/5) |                                                                                                      |


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
- [Tael](https://github.com/Tae-l), [Locke](https://github.com/Lockem90), [3L00DStrike](https://github.com/3L00DStrike), [Zulandia](https://github.com/AlexanderKenny), [Kojiyama](https://github.com/EvanMichaels), [Blackytemp](https://github.com/ghr74) for the contributions.

## Advanced Users / Developper Notes
If you want to use the addon directly from the [GitHub repository](https://github.com/SimCMinMax/AethysRotation), you would have to symlink every folders from this repository (AethysRotation folder and every class modules but the template) to your WoW Addons folder.
Furthermore, to make it working, you need to add the only dependency that is [AethysCore](https://github.com/SimCMinMax/AethysCore) following the same processus (symlink AethysCore & AethysCache from the repository).
There is a script that does this for you, open symlink.bat and modify the two vars (WoWRep and GHRep) to match your local setup.
Make sure AethysRotation's directories doesn't already exist as it will not override them.
Finally, launch symlink.bat

Stay tuned !

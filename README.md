**Not everything is updated for The War Within, so please check the table below (Supported Rotations). If a spec is in WIP or KO status, please do not report an issue about it.**

**If you are missing dependencies, ([HeroDBC](https://www.curseforge.com/wow/addons/herodbc) and [HeroLib](https://www.curseforge.com/wow/addons/herolib)), you have to install them.**

**If you are experiencing issues with AoE rotations (likely abilities not being recommended), be sure to have enemies nameplates enabled and enough nameplates shown (camera can hide them). Also, (for casters, especially) you or a member of your party/raid must use an AoE ability before we can determine the number of targets near that enemy.**

**If you see an icon with "POOL" written inside, it means you have to pool your resources. It's a normal behavior. Please see this [link explaining resource pooling](https://wow.gamepedia.com/Resource_pooling).**

**If you update the addon via the Curse Client and wish to get every change as they are released, please set the addon type to Alpha by right clicking the addon name and selecting Alpha under Release Type. This is dependent upon Curse grabbing updates from GitHub, which it doesn't always do properly, so some updates may be missed. Note that this can potentially include updates that break functionality!**

**If you would like to update the addon directly from GitHub via [WowUp](https://wowup.io), go to the Get Addons tab, click Install from URL, enter the GitHub repo address (https://github.com/herotc/hero-rotation), and click Import. Remember to do the same with HeroLib (https://github.com/herotc/hero-lib) and HeroDBC (https://github.com/herotc/hero-dbc).**

# HeroRotation

[![GitHub license](https://img.shields.io/badge/license-EUPL-blue.svg)](https://raw.githubusercontent.com/herotc/hero-rotation/master/LICENSE)
[![GitHub contributors](https://img.shields.io/github/contributors/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/graphs/contributors)
[![GitHub forks](https://img.shields.io/github/forks/herotc/hero-rotation.svg)](https://github.com/herotc/hero-rotation/network)
[![GitHub stars](https://img.shields.io/github/stars/herotc/hero-rotation.svg)](https://github.com/herotc/hero-rotation/stargazers)\
[![GitHub issues](https://img.shields.io/github/issues/herotc/hero-rotation.svg)](https://github.com/herotc/hero-rotation/issues?q=is%3Aopen+is%3Aissue)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/pulls?q=is%3Aopen+is%3Apr)
[![GitHub closed issues](https://img.shields.io/github/issues-closed/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/pulls?q=is%3Apr+is%3Aclosed)\
[![GitHub release](https://img.shields.io/github/v/release/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/releases)
[![GitHub Release Date](https://img.shields.io/github/release-date/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/releases)
[![GitHub commits since latest release (by date)](https://img.shields.io/github/commits-since/herotc/hero-rotation/latest)](https://github.com/herotc/hero-rotation/commits/master)
[![GitHub last commit](https://img.shields.io/github/last-commit/herotc/hero-rotation)](https://github.com/herotc/hero-rotation/commits/master)

HeroRotation is a World of Warcraft addon to provide the player useful and precise information to execute the best possible DPS rotation in every PvE situation at max level.\
The project is hosted on [GitHub](https://github.com/herotc/hero-rotation) and powered by [HeroLib](https://github.com/herotc/hero-lib) & [HeroDBC](https://github.com/herotc/hero-dbc).\
It is maintained by [Aethys](https://github.com/aethys256/) and the [HeroTC](https://github.com/herotc) team.\
Also, you can find it on [CurseForge](https://www.curseforge.com/wow/addons/herorotation).

**There are a lot of helpful commands. Do '/hr help' to see them in-game!**\
**Most of the commands and options are being moved to Addons Panels, and you can see them by going into Interface -> Addons -> HeroRotation.**

Feel free to join our [Discord](https://discord.gg/tFR2uvK). Feedback is highly appreciated!

## Key Features

- Main icon that shows the next ability you should cast.
- Two smaller icons above the previous one that shows the useful abilities to use (they are mostly off-gcd).
- One medium icon on the left that shows every ability that should be cycled (i.e. multi-dotting) using nameplates.
- One medium-small icon on the upper-left that does proposals about situational offensive/utility abilities (trinkets, potions, ...).
- One medium-small icon on the upper-left that does proposals about situational defensive abilities (trinkets, potions, ...).
- Toggles to turn On/Off the CDs or AoE to adjust the rotation according to the situation (the addon can be paused this way aswell).

_Toggles can assigned to keybinds. Set them in 'Game Menu -> Key Bindings -> AddOns'._

Every rotation is based on [SimulationCraft](http://simulationcraft.org/) [Action Priority Lists](https://github.com/simulationcraft/simc/wiki/ActionLists).\
**This means that the accuracy of the addon heavily depends on how well the SimC APL is made.**\
**Be aware that some APLs are pretty good in some simulations circumstances but behaves pretty poorly in-game due to too much sequencing / lack of priority. We do our best to account for this in HeroRotation.**

## Special Features

- Handle both single target and AoE rotations (it auto adapts).
- Range radar to also detect enemies around the target (the more players in your party, the more accurate it is).
- Optimized pooling of resources when needed (ex: energy before using cooldowns as a rogue).
- Next cast prediction (mainly for casters).
- Accurate TimeToDie / FightRemains prediction.
- Special handlers for tricky abilities (ex: finality or exsanguinated bleeds for rogues).
- Solo mode to prioritize survivability over DPS. (Not available in every rotation, disabled in dungeon/raid)

## Supported Rotations

| Class        | Specs                                                                               |                                                                                     |                                                                                     |
| :----------- | :---------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------- |
| Death Knight | ![Blood](https://img.shields.io/badge/Blood-Good-brightgreen.svg)                   | ![Frost](https://img.shields.io/badge/Frost-Good-brightgreen.svg)                   | ![Unholy](https://img.shields.io/badge/Unholy-Good-brightgreen.svg)                 |
| Demon Hunter | ![Havoc](https://img.shields.io/badge/Havoc-Good-brightgreen.svg)                   | ![Vengeance](https://img.shields.io/badge/Vengeance-Good-brightgreen.svg)           |                                                                                     |
| Druid        | ![Balance](https://img.shields.io/badge/Balance-Good-brightgreen.svg)               | ![Feral](https://img.shields.io/badge/Feral-Good-brightgreen.svg)                   | ![Guardian](https://img.shields.io/badge/Guardian-Good-brightgreen.svg)             |
| Evoker       | ![Augmentation](https://img.shields.io/badge/Augmentation-Good-brightgreen.svg)     | ![Devastation](https://img.shields.io/badge/Devastation-Good-brightgreen.svg)       |                                                                                     |
| Hunter       | ![Beast Mastery](https://img.shields.io/badge/Beast%20Mastery-Good-brightgreen.svg) | ![Marksmanship](https://img.shields.io/badge/Marksmanship-Good-brightgreen.svg)     | ![Survival](https://img.shields.io/badge/Survival-Good-brightgreen.svg)             |
| Mage         | ![Arcane](https://img.shields.io/badge/Arcane-Good-brightgreen.svg) :warning:       | ![Fire](https://img.shields.io/badge/Fire-Good-brightgreen.svg) :warning:           | ![Frost](https://img.shields.io/badge/Frost-Good-brightgreen.svg) :warning:         |
| Monk         | ![Brewmaster](https://img.shields.io/badge/Brewmaster-Good-brightgreen.svg)         | ![Windwalker](https://img.shields.io/badge/Windwalker-Good-brightgreen.svg) :warning: |                                                                                   |
| Paladin      | ![Protection](https://img.shields.io/badge/Protection-Good-brightgreen.svg)         | ![Retribution](https://img.shields.io/badge/Retribution-Good-brightgreen.svg) :warning: |                                                                                 |
| Priest       | ![Shadow](https://img.shields.io/badge/Shadow-Good-brightgreen.svg)                 |                                                                                     |                                                                                     |
| Rogue        | ![Assassination](https://img.shields.io/badge/Assassination-Good-brightgreen.svg)   | ![Outlaw](https://img.shields.io/badge/Outlaw-WIP-orange.svg)                       | ![Subtlety](https://img.shields.io/badge/Subtlety-Good-brightgreen.svg)             |
| Shaman       | ![Elemental](https://img.shields.io/badge/Elemental-Good-brightgreen.svg)           | ![Enhancement](https://img.shields.io/badge/Enhancement-Good-brightgreen.svg)       |                                                                                     |
| Warlock      | ![Affliction](https://img.shields.io/badge/Affliction-Good-brightgreen.svg) :warning: | ![Demonology](https://img.shields.io/badge/Demonology-Good-brightgreen.svg) :warning: | ![Destruction](https://img.shields.io/badge/Destruction-Good-brightgreen.svg)   |
| Warrior      | ![Arms](https://img.shields.io/badge/Arms-Good-brightgreen.svg)                     | ![Fury](https://img.shields.io/badge/Fury-Good-brightgreen.svg)                     | ![Protection](https://img.shields.io/badge/Protection-Good-brightgreen.svg)         |

![Spec](https://img.shields.io/badge/Spec-Good-brightgreen.svg) - The rotation does have an optimal SimC APL and is optimally implemented in the addon.\
![Spec](https://img.shields.io/badge/Spec-OK-green.svg) - The rotation does not have an optimal SimC APL but is optimally implemented in the addon.\
![Spec](https://img.shields.io/badge/Spec-WIP-orange.svg) - The rotation is not optimally implemented in the addon.\
![Spec](https://img.shields.io/badge/Spec-KO-red.svg) - The rotation is not supported on SimC or is not yet implemented in the addon.\
:warning: - The rotation is maintained by the community (through Pull Requests) and not by the core team.

Do you want to contribute? Feel free to open a [pull request](https://github.com/herotc/hero-rotation/pulls), an [issue](https://github.com/herotc/hero-rotation/issues) or ask around in our [Discord](https://discord.gg/tFR2uvK).\
You can look at our [Battle for Azeroth](https://github.com/herotc/hero-rotation/tree/bfa), [Legion](https://github.com/herotc/hero-rotation/tree/legion), [Shadowlands](https://github.com/herotc/hero-rotation/tree/shadowlands), and [Dragonflight](https://github.com/herotc/hero-rotation/tree/dragonflight) branches too if you want to see earlier versions.
Rogue rotations are usually the most polished ones, so you can take inspiration from them.

## Support the team

| Name                                        | Maintaining                         |  Since   |                                                                                                Donate                                                                                                |                                               Watch                                               |
| :------------------------------------------ | :---------------------------------- | :------: |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:| :-----------------------------------------------------------------------------------------------: |
| [Aethys](https://github.com/Aethys256)      | Project Founder                     | Aug 2016 |                                                  [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/Aethys/5)                                                  | [![Stream](https://img.shields.io/badge/Stream-Twitch-6441a4.svg)](https://www.twitch.tv/aethys)  |
| [KutiKuti](https://github.com/Kutikuti)     | Core, Mage                          | Mar 2017 |                                                 [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/kutikuti/5)                                                 |                                                                                                   |
| [Kojiyama](https://github.com/EvanMichaels) | Core, DH, Rogue                     | Sep 2017 |                                                 [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/kojiyama/5)                                                 |                                                                                                   |
| [Cilraaz](https://github.com/Cilraaz)       | Core, VDH, Evoker, all but Rogue    | Jan 2019 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/Cilraaz/5) [![Donate](https://img.shields.io/badge/Donate-Patreon-f96854.svg)](https://patreon.com/cilraaz) | [![Stream](https://img.shields.io/badge/Stream-Twitch-6441a4.svg)](https://www.twitch.tv/cilraaz) |
| [Synecdoche](https://github.com/mrdmnd)     | Rogue, Tanks                        | Apr 2019 |                                                                                                                                                                                                      |                                                                                                   |
| [Seny](https://github.com/Seny951)          | Rogue                               | Oct 2024 | [![Donate](https://img.shields.io/badge/Donate-PayPal-003087.svg)](https://www.paypal.me/seny951/5) [![Donate](https://img.shields.io/badge/Donate-Patreon-f96854.svg)](https://patreon.com/Seny951) |                                                                                                   |

### Past members

[Skasch](https://github.com/skasch), [Riff](https://github.com/tombell), [Tael](https://github.com/Tae-l), [Locke](https://github.com/Lockem90), [3L00DStrike](https://github.com/3L00DStrike), [Lithium](https://github.com/lithium720), [Glynny](https://github.com/Glynnyx), [Nia](https://github.com/Nianel), [Mystler](https://github.com/Mystler), [Krich](https://github.com/chrislopez24), [Blackytemp](https://github.com/ghr74), [Hinalover](https://github.com/Hinalover)

## Special Mention About SimC APL

As said earlier, every rotation is based on SimulationCraft Action Priority Lists (APL).\
What this means is it heavily relies on how optimized those APLs are, especially for some talents, items and any specific mechanic/gimmick.\
Do remember that what the addon tells you is what the robot on SimulationCraft would do in your situation (except he never fails, so you could end up in situations that were never seen).\
It also means that you can improve the current APL by using the addon and reporting any issues you might encounter.\
Rogue theorycrafters uses both SimulationCraft and HeroRotation, so both SimC APL and addon rotations are 100% synced. Both tools are used to do Rogue theorycrafting.

## Special Thanks

- [SimulationCraft](http://simulationcraft.org/) for everything the project gives to the whole WoW Community.
- [KutiKuti](https://github.com/Kutikuti) & [Nia](https://github.com/Nianel) for their daily support.
- [Skasch](https://github.com/skasch) for what we built together and the motivation he gave to me.
- [Mystler](https://github.com/Mystler) & [Kojiyama](https://github.com/EvanMichaels) & [Fuu](https://github.com/fuu1) for their work on everything related to rogues that frees me a lot of time.

## Advanced Users / Developer Notes

If you want to use the addon directly from the [GitHub repository](https://github.com/herotc/hero-rotation), you would have to symlink every folder from this repository (HeroRotation folder and every class module, except for the template) to your WoW Addons folder.\
Furthermore, to make it work, you need to add the dependencies, which are [HeroLib](https://github.com/herotc/hero-lib) (includes HeroCache as well) and [HeroDBC](https://github.com/herotc/hero-dbc), following the same process (symlink HeroLib, HeroCache, and HeroDBC from the repositories).\
There is a script that does this for you. Open symlink.bat (or symlink.sh) and modify the two vars (WoWRep and GHRep) to match your local setup.\
Make sure HeroRotation's directories doesn't already exist as it will not override them.\
Finally, launch symlink.bat.

Stay tuned !
Aethys

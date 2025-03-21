# Haste Info
FFXI Windower addon that informs the GearSwap addon about haste potency (from buffs) and dual wield on the player.

HasteInfo is designed to give people the ability to use more optimal gearsets in GearSwap based on
their current Haste buffs. For example, if you have enough haste between magic buffs, JA buffs, and gear,
you do not need to wear any Dual Wield gear. In fact, wearing Dual Wield gear when you don't get any
attack speed benefit from it (because you may already be attack speed capped) is actually bad for you
because Dual Wield reduces the amount of TP per hit you get from auto attacks.

## Purpose

This addon is meant to replace the GearInfo addon for the purposes of haste potency calculation and 
the subsequent feeding of this info to GearSwap. There are several problems I've identified with GearInfo's
haste calculations that I'm attempting to solve with HasteInfo:
* GearSwap-GearInfo feedback loop
  - If you have GearSwap set up to change sets automatically based on the haste calculation from GearInfo
  you will sometimes find yourself in a position where GearInfo says "you need 16 Dual Wield" and GearSwap
  then changes into 16 DW set that you've defined, which coincidentally adds 1 extra point of gear Haste too.
  Then GearInfo says, "Oh, GearSwap you can get by with only 11 DW now" and GearSwap changes back to a different
  set with less DW only to realize that it coincidentally has lost 1% Haste again. Then this repeats forever.
  - TL;DR: GearInfo should not tell GearSwap about haste from gear or it creates a feedback loop. I believe it
    does have the ability to set equipment haste to a specific value to stop this from happening, but it is not
    default behavior.
* Subpar potency detection
  - Potencies are often wrong. Even when manually setting BRD potency (override) to +8 on songs, double march is
    not being detected as capped magic haste.
* Bloat
  - GearInfo calculates a lot of various stats, not just Haste. But GearSwap only cares about Haste (if you're just
    using it for DW set calculations).
* Random error spam
  - Specifically, there seems to be some occasions where Honor March can get GearInfo into a state where
    it just spams error messages, and cannot be fixed without a full addon reload.
* Performance
  - GearInfo recalculates stats 2 times per second, or more if you have higher than 30 fps because its update loop is tied to the prerender loop
  - HasteInfo is event-driven which means it recalculates only when a change to haste has been detected, and also only reports updates at that same
    frequency too; "reports" meaning updates to its own UI as well as pushing updates over to GearSwap. It does accept commands to provide a report
    on demand in case someone wants it outside of the normal reporting cycle such as when first loading a new job or perhaps when switching from
    non-DW to DW weapons.

## How to Install

Download the addon and place the HasteInfo folder into your windower `addons` folder.
In game, run this command: `lua load hasteinfo`

If you want it to load automatically when you log in, I highly recommend configuring it in the Plugin Manager addon, which you can get in the Windower
launcher. Plugin Manager details can be found at https://docs.windower.net/addons/pluginmanager/

## How to Use

HasteInfo just reports what dual wield you need to hit haste cap. You decide what to do with it. The most common use is likely going to be that you want
your GearSwap to be told what DW value it needs, then respond by equipping some set of gear. There are two main ways to accomplish this:
1. Enable the HasteInfo feature in SilverLibs
2. Add all the necessary hooks into your GearSwap files yourself.

### Customization

Customization options can be done through in-game commands. Type `//hasteinfo` to see the Help menu. By default it shows everything which is "verbose" mode
and probably more than you care to see on a daily basis. All customization options are:

| Command                             | Aliases                                                | Description |
| ----------------------------------- | ------------------------------------------------------ | ----------- |
| reload                              | r                                                      | Reload addon |
| visible                             | vis                                                    | Toggle UI on or off |
| show                                |                                                        | Display the UI. If already visible, does nothing |
| hide                                |                                                        | Hide the UI. If already hidden, does nothing |
| resetpos                            |                                                        | Reset position of the UI to the top left corner |
| detail                              | details                                                | If UI is hidden, makes it visible. If visible, toggle between a collapsed/expanded UI mode |
| detail fractions                    | fraction, frac, percentage, percentages, percent, perc | Toggle display of haste values in the UI between fractions and percentages |
| detail summary                      |                                                        | Cycle through 3 pre-defined UI display modes for the summary line: off, minimal, verbose |
| detail party                        |                                                        | Toggle display of party info |
| detail breakdown                    | effect, effects                                        | Toggle display of buff/debuff details |
| detail expand                       | verbose                                                | Set UI to verbose summary, show party details, show breakdown |
| detail collapse                     | collapsed, min, minimal                                | Set UI to minimal summary, hides party details, hides breakdown |
| detail reset                        |                                                        | Reset UI to defaults for summary, party details, breakdown |
| report                              |                                                        | Force send a report of stats to the UI and GearSwap without recalculating them |
| pause                               | freeze, stop, halt, off, disable                       | Stop calculating your stats and stops reports, turns UI red, continues tracking buffs/debuffs |
| unpause                             | play, resume, continue, start, on, enable              | Resume calculating buffs, sending reports, and sets UI back to normal colors |
| defaultpotency                      |                                                        | Toggle the default assumed potencies of geomancy and march spells between min and max values |
| defaultpotency geomancy `value`     | geo, g, indi                                           | Set default assumed potency of geomancy spells to specified value |
| defaultpotency march `value`        | song, m, s, brd                                        | Set default assumed potency of march spells to specified value |
| whitelist                           | wl                                                     | Toggle whitelist enable/disable |
| whitelist `name` `category` `value` |                                                        | Add player to whitelist. Category must be `geo` or `brd`. Value must be a number. This sets the player's assumed potency for that spell type. |
| whitelist remove `name`             | rm, r, delete, d                                       | Remove player from whitelist |
| debug                               |                                                        | Toggle debug mode. Currently does nothing. |
| help                                |                                                        | Put help info about HasteInfo commands into game chat (only visible to self) |
| test                                |                                                        | Print some info about the tracked players |

More info about customization options:
* "Whitelist" is a bit of a misnomer. I kept the same name that GearInfo uses for familiarity. It allows you to override the assumed default geomancy and march potencies that you get from other players.
  * Trusts are already calculated with correct potencies and do not need to be added to this list.

### Enable HasteInfo via SilverLibs

SilverLibs is a GearSwap library that makes adding new features quick and easy. This is a perfect example of that. Implementing HasteInfo using SilverLibs
only requires 2 steps. However, the initial setup for SilverLibs can end up taking longer than implementing HasteInfo the manual way (for a single job).
If you plan to add HasteInfo integration for multiple jobs, using SilverLibs is highly recommended.

Here is the documentation for SilverLibs installation: https://github.com/shastaxc/silver-libs/wiki/Installation

Here are the instructions for enabling HasteInfo using SilverLibs: https://github.com/shastaxc/silver-libs/wiki/Integrate-HasteInfo

Here is an example implementation: https://github.com/shastaxc/gearswap-data/blob/main/Silvermutt-THF.lua

### Add HasteInfo Hooks in GearSwap Manually

Implementing HasteInfo into GearSwap this way requires more steps. If you have to do this for multiple jobs, SilverLibs is recommended. Here's an example
of doing it the manual way without SilverLibs:

Initialize your `dw_needed` variable in the function that triggers when you change main/sub jobs. This function is `user_setup()` in Mote's library and
`job_setup()` in Selindrile's library. Mote's example:
```lua
function user_setup()
  dw_needed = 0
end
```

Next, set up your job lua to listen for reports from HasteInfo. Reports are sent only when the value changes, or if you call the `//hasteinfo report` command
manually. If using Mote's library, modify function `job_self_command`. If using Selindrile's library, it is called `user_self_command`. Mote's example:
```lua
function job_self_command(cmdParams, eventArgs)
  process_hasteinfo(cmdParams, eventArgs)
end

function process_hasteinfo(cmdParams, eventArgs)
  if cmdParams[1] == 'hasteinfo' then
    dw_needed = tonumber(cmdParams[2])
    if not midaction() then
      job_update()
    end
  end
end
```

This will track your 'DW Needed' amount (according to HasteInfo) in a variable named `dw_needed`. And you can do whatever you want with it. You can reference
this file for ideas/reference for a manual implementation of HasteInfo: https://github.com/shastaxc/gearswap-data/blob/main/Silvermutt-COR.lua

To get your engaged sets to swap based on the reports from HasteInfo you must also implement the following:

Add an initial call for HasteInfo to produce a report when you load a job file:
```lua
function get_sets()
  coroutine.schedule(function()
    send_command('hasteinfo report')
  end, 3)
end
```

Define the function that will set your CombatForm state:
```lua
function update_combat_form()
  if dw_needed <= 0 then
    state.CombatForm:reset()
  else
    if dw_needed > 0 and dw_needed <= 11 then
      state.CombatForm:set('LowDW')
    elseif dw_needed > 11 and dw_needed <= 18 then
      state.CombatForm:set('MidDW')
    elseif dw_needed > 18 and dw_needed <= 31 then
      state.CombatForm:set('HighDW')
    elseif dw_needed > 31 and dw_needed <= 42 then
      state.CombatForm:set('SuperDW')
    elseif dw_needed > 42 then
      state.CombatForm:set('MaxDW')
    end
  end
end
```

Hook into the gear-equipping function to have it update your combat form when gear updates are triggered:
```lua
function job_handle_equipping_gear(playerStatus, eventArgs)
  update_combat_form()
end
```

## How It Works

HasteInfo starts by tracking haste-related actions performed on you (by reading an incoming network packet), and from there can determine what effect this
has on your overall haste. It also listens for haste-related buffs on you reported by the server (by reading a different incoming network packet), and links
it to haste effects already recorded by action packets. In the ideal scenario, these will match up perfectly, but lost action packets can cause some 
information to be lost and assumptions must be made during reconciliation (see "Assumptions" section below for more details).

To help reconcile some discrepancies due to packet loss, HasteInfo uses the buff packet, which lists your buffs and their durations, as the source of truth
for which buffs you actually have on. Unfortunately, it doesn't include info such as who casted that buff or which spell it came from (all BRD Marches just
show as "March" and doesn't tell you which spell effect it is). Because of this, it is not the first choice in determining potencies but it can be used to 
help in maintaining a relatively accurate measure of your haste buffs.

Additionally, Geomancy buffs (Indi-Haste and Geo-Haste) do not require any action to be taken on yourself in order for you to gain the buff effect, and their
potencies can change based on abilities used on other players (e.g. Entrust Indi-Haste is different potency than non-Entrusted). For this reason, HasteInfo also
monitors actions performed on your party members and buffs on your party members. If those action packets are lost, we have to reconcile that using assumptions
when the buff update packets come in.

Note: HasteInfo will give you a value of -1 if you are currently unable to dual wield at all.

### Sources of Haste

Sources of Haste accounted for:
* GEO-Haste, Indi-Haste
* Haste Samba
* Embrava
* Haste, Haste II spells
* Hastega, Hastega II (Garuda blood pact)
* Honor March, Victory March, Advancing March
* Refueling, Erratic Flutter, Animating Wail, Mighty Guard
* Hasso
* DRG Spirit Link
* Last Resort
* Catastrophe aftermath with Apocalypse ilvl 119

### Assumptions

* HasteInfo assumes that your equipment haste is always capped in order to avoid one of the shortfalls of GearInfo that I explained above (the feedback loop
  with GearSwap).
* All GEOs have Idris (can override per-player with the whitelist feature)
* All BRDs have max bonus to Marches (can override per-player with the whitelist feature)
* BRDs are not overwriting other BRD's songs (but ok if they overwrite their own), and that all their song durations are consistent (at least within a song
  type like same duration for all Marches).
* Haste Samba is from sub DNC, unless there is a main DNC in your party. Main DNC assumed to have 5/5 Haste Samba potency merits if it's not yourself. It will
  detect your actual merit allocations if you are the DNC.
* SCH casting Embrava has 500+ Enhancing Magic skill (capped Embrava potency)
* Assumes DRG Spirit Link Haste is already on if reloading addon (no buff on player to tell for sure)
* Assumes no Haste Samba is active if reloading addon (no buff on player to tell for sure)
* Is Haste aura from Entrusted Indi-Haste vs Indi-Haste/Geo-Haste?
  - First priority is listening to packets and detecting when an Indi-Haste is casted, then mark the target. If the
  target is the same as the caster, it's not entrusted.
  - By tracking all party member buffs. Watch for the "coloure active" buff to appear, and then capture the aura buff
  that appears on them right after. If the Coloure Active buff and Indi buff appear on them within the same update
  packet, assume that's the one that was applied.
  - If multiple GEO Haste buffs are active in your party, it is assumed that you have the strongest one. For example,
    if there is an Entrusted and non-Entrusted Indi-Haste active in your party, it's assumed you have the non-Entrusted one.
* Unknown sources of Haste will be assumed to be 150/1024 (~15%).
  - This includes additional effect items such as Blurred Knife +1. The client receives no indication at all where that form of haste comes from, only that you
    received the buff.
* Unknown sources of Slow will be assumed to be -300/1024 (~29.3%).
* Unknown sources of Elegy will be assumed to be -512/1024 (50%).
* Magic haste can only be summed to a cap of 1024/1024 before subtracting debuffs before applying the usual magic haste cap. For example, if we have Haste II,
  Embrava, Idris Geo-Haste, Victory March, Honor March, and Weakness without the assumed summation cap of 1024, that should add up to 1469 (buffs) - 1024 (weakness) = 445,
  which is almost capped for magic haste. However, I believe it would really end up capping the buff summation at 1024 and then weakness subtracts 1024 and we're
  left with a magic haste of 0.

## Misc Info

* Anonymous players must have their jobs deduced by the spells and abilities used. Also, examining someone will parse through their equipped gear and try to find
  a piece that can only be equipped by a single job, then marks them as having that main job.
* Catastrophe comes from Apocalypse ilvl 119, making it JA haste. All lower ilvl of Apoc grant equipment haste instead, which is ignored by HasteInfo.
* If an action is taken on a party member who already has the corresponding buff, the result may be either "no effect" or overriding the current buff. If overriding
  the current buff, it could be either the same or stronger potency so this has to be updated. There is no incoming party buff packet (id 0x076) when this happens
  because the buff icons do not change, so we have to rely on the action packet and if it gets dropped, haste values simply remain incorrect. For the primary player
  though, we receive buff durations along with their buff update packet, and this can be used to match with current buffs to determine if there was a change but there's
   no way to determine the source so we'll assume it was the same effect that refreshed it. This is part of the reason songs are not tracked for party members.
* GEO spells can have an effect on the primary user even though no action was performed on them. Indi- spells are tracked by pegging them to the player who was targeted
  (in case of Entrusted spells) as well as tracking who casted them (since the caster affects potency too as long as it's not an Entrusted spell). Geo- spells are pegged
  to the caster since they cannot ever be "owned" by another player. When a GEO buff appears on a player, we can look up the previous actions taken and determine who
  casted it, and therefore its potency.
* Sambas are not detected as buffs, but can be detected based on the spike animation when you perform a melee attack. It is then tracked in a special table called `samba`
  which tracks the expiration timestamp of the effect based on the time of your melee attack that gained you the buff. It remains tracked until HasteInfo has to report
  haste values. At that point, it is determined if the buff is expired or not. Alternatively, disengaging from a mob or performing a melee attack that lacks the animation
  will also clear the tracked samba effect.
* Bard songs are annoying in the sense that buff IDs are not specific for individual songs. All marches have the same buff ID (214), and simply appear that you have
  multiple of the same buff. This is the only situation where you can have multiple buff IDs active at the same time (at least as far as haste-related buffs go). For
  this reason, active bard songs are maintained separately from the other buffs because it doesn't fit the logic used for all other buffs.
* When a spell is gained or lost, it triggers packet 0x063. This packet contains info on all your current buffs and their durations. This is used as the source of truth
  to reconcile info lost in dropped action packets. Assumptions are made as necessary when there is missing data such as potency.
* When party members are out of zone, the game does not send us job updates for them. Their job will remain the same in the HasteInfo UI, but it may not be their actual
  job if they changed while out of zone. Players who are out of zone will show as slightly darker on the UI so just keep in mind that their job may not be accurate.

## TODO / Known Issues
* [Bug] Hasso counting toward haste when 2h not equipped.
* [Bug] Desperate Blows buff is being counted even if wielding 1h weapon, which is not true.
* [Bug] Due to dropped packets, Slow/Elegy debuffs can get stuck and never stop being tracked until you zone. Workaround is to reload HasteInfo.
* Add setting to allow user to set Hasso value. This is to account for gear bonuses to Hasso.
* Add setting to allow user to override the assumed equipment haste value.
* Verify if trust Dancers give 5% or 10% haste with Haste Samba.
* Add tracking for BST's raaz pet Zealous Snort ability.
* When summary line is hidden in the UI, the first line of remaining UI elements is not aligned properly the left side of the UI box.

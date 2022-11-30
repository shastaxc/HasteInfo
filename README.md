# Haste Info
FFXI gearswap library that informs the GearSwap addon about haste potency (from buffs) on the player.

HasteInfo is designed to give people the ability to use more optimal gearsets in GearSwap based on
their current Haste buffs. For example, if you have enough haste between magic buffs, JA buffs, and gear,
you do not need to wear any Dual Wield gear. In fact, wearing Dual Wield gear when you don't get any
attack speed benefit from it (because you may already be attack speed capped) is actually bad for you
because Dual Wield reduces the amount of TP per hit you get from auto attacks.

## Purpose

This library is meant to replace the GearInfo addon for the purposes of haste potency calculation and 
the subsequent feeding of this info to GearSwap. There are several problems I've identified with GearInfo's
haste calculations that I'm attempting to solve with HasteInfo:
* GearSwap-GearInfo feedback loop
  - If you have GearSwap set up to change sets automatically based on the haste calculation from GearInfo
  you will sometimes find yourself in a position where GearInfo says "you need 16 Dual Wield" and GearSwap
  thinks changes into 16 DW set, which coincidentally adds 1 extra point of gear Haste too. Then GearInfo
  says, "Oh, GearSwap you can get by with only 11 DW now" and GearSwap changes back to a different set with
  less DW only to realize that it coincidentally has gained 1% Haste back again.
  - TL;DR: GearInfo should not tell GearSwap about haste from gear or it creates a feedback loop
* Subpar potency detection
  - Potencies are often wrong. Even when manually setting BRD potency (override) to +8 on songs, double march is not being detected as capped magic haste.
* Bloat
  - GearInfo calculates a lot of various stats, not just Haste. But GearSwap only cares about Haste.
* Random error spam
  - Specifically, there seems to be some occasions where BRD songs can get GearInfo into a state where
  it just spams error messages, and cannot be fixed without a full addon reload.

## Installation/Usage

Include this at the top of your Globals file:
```
hasteinfo = include('HasteInfo')
```

It does not need to be put into each individual job lua, but you can do so if you wish.

You can enable optional features using the following commands:
| Feature | Enabling Command | Description |
| ------- | ---------------- | ----------- |
| Show UI | hasteinfo.show_ui() | Display the UI |

## How It Works

HasteInfo starts by tracking haste-related actions performed on you and haste buffs on you, and links them together to determine potency based on a variety of factors (see "Sources of Haste" section below). This is the ideal scenario, but lost action packets can cause some information to be lost and assumptions must be made (see "Assumptions" section below).

To help reconcile some discrepancies due to packet loss, HasteInfo also listens to character update packets that list your buffs and their durations and uses that as the source of truth for which buffs you actually have on. Unfortunately, it doesn't include info such as who casted that buff or which spell it came from (all BRD Marches just show as "March" and doesn't tell you which spell effect it is). Because of this, it is not the first choice in determining potencies but it can be used to help in maintaining a relatively accurate measure of your haste buffs.

Additionally, Geomancy buffs (Indi-Haste and Geo-Haste) do not require any action to be taken on yourself in order for you to gain the buff effect. For this reason, HasteInfo also monitors actions by your party members and buffs on your party members. If those action packets are lost, we have to reconcile that using assumptions as well when the buff update packets come in.

### Sources of Haste

HasteInfo assumes that your equipment haste is always capped in order to avoid one of the shortfalls of GearInfo that I explained above.

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
* Other weapon additional effect such as Blurred Knife

### Assumptions

* All GEOs have Idris (will add whitelist and blacklist feature later)
* All BRDs have max bonus to Marches (will add whitelist and blacklist feature later)
* BRDs are not overwriting other BRD's songs (but ok if they overwrite their own), and that all their song durations are consistent (at least within a song type like same duration for all Marches).
* Haste Samba is from sub DNC, unless there is a main DNC in your party. Main DNC assumed to have 5/5 Haste Samba potency merits if it's not yourself.
* SCH casting Embrava has 500 Enhancing Magic skill (capped Embrava potency)
* Assumes DRG Spirit Link Haste is already on if reloading addon (no buff on player to tell for sure)
* Assumes no Haste Samba is active if reloading addon (no buff on player to tell for sure)
* Is Haste aura from Entrusted Indi-Haste vs Indi-Haste/Geo-Haste?
  - First priority is listening to packets and detecting when an Indi-Haste is casted, then mark the target. If the
  target is the same as the caster, it's not entrusted. If Geo-Haste is casted, assume there's no 2nd Entrusted Indi-Haste.
  - By tracking all buffs on the party's GEOs. Watch for the "coloure active" buff to appear on the GEO, and then
  capture the aura buff that appears on them right after. If the Coloure Active buff and Indi buff appear on them
  within the same polling cycle, assume that's the one that was applied. By tracking all buffs on all players, you can
  ignore certain effects that may apply or fall off of the GEO to avoid race conditions.
* Catastrophe comes from Apocalypse ilvl 119, making it JA haste. All lower ilvl of Apoc grant equipment haste instead, which is
ignored by HasteInfo.
* Slow potency is assumed to be max of 300/1024 (~29.3%). This will apply to both normal Slow debuff as well as aura Slow debuff.
* Unknown sources of Haste will be assumed to be 150/1024 (~15%).
  - This includes additional effect items such as Blurred Knife +1. The client receives no indication at all where that form of haste comes from, only that you received the buff.
* Anonymous jobs must be deduced by the spells and abilities used. Only DNC really needs to be tracked.

## Misc Info

* If an action is taken on a player who already has the corresponding buff, the result may be either "no effect" or overriding the current buff. If overriding the current buff, it could be either the same or stronger potency so this has to be updated. There is no incoming party buff packet (id 0x076) or "gain buff" event when this happens because the buff icons do not change.
* GEO spells can have an effect on the primary user even though no action was performed on them. Indi- spells are tracked by pegging them to the player who was targeted (in case of Entrusted spells) as well as who casted them (since the caster affects potency too). Geo- spells are pegged to the caster since they cannot ever be "owned" by another player. When a GEO buff appears on a player, we can look up the previous actions taken and determine who casted it, and therefore its potency.
* Sambas are not detected as buffs, but can be detected based on the spike animation when you perform a melee attack. It is then tracked in a special attribute called samba_start which tracks the most recent timestamp of your melee attack that gained you the buff. It remains tracked until something checks your haste values. At that point, it is determined if the buff is expired or not. Alternatively, disengaging from a mob will also clear the tracked samba effect.
* Bard songs are annoying in the sense that buff IDs are not specific for individual songs. All marches have the same buff ID (214), and simply appear that you have multiple of the same buff. This is the only situation where you can have multiple buff IDs active at the same time. For this reason, active bard songs are maintained separately from the other buffs because it doesn't fit the logic used for all other buffs.
* When a spell is gained or lost, it triggers packet 0x063. This packet contains info on all your current buffs and their durations. This is used as the source of truth to reconcile info lost in dropped action packets. Assumptions are made as necessary when there is missing data such as potency.

## TODO
* Find a way to reset appropriate haste effects when leaving the Odyssey lobby and going into a boss fight.
* Enhance initialization
  - Determine DW traits
* Detect job for party members (if not already informed via update packets) by detecting actions that only 1 job could perform.
* Account for Bolster, Blaze of Glory, and Ecliptic Attrition potency
* Account for Marcato, Soul Voice potency
* Detect zone change events for other players and call the `remove_zoned_effects()` function
* Figure out what dispel packets look like. They should say exactly what haste effect was removed (e.g. "___ loses the effect of Victory March" has to come from the packet)
* Remove party members if they are not present in the party buff packet
* Convert this to an addon
  - Implement commands:
    - Stop reporting
    - Toggle UI visibility
    - Reset UI position
* Implement UI
  - Display current haste value
  - Display current DW value
  - Option to display haste effects breakdown
  - Option to display tracked party members and their jobs
* Account for debuff effects:
  - Battlefield Elegy (-256/1024)
  - Carnage Elegy (-512/1024)
  - Weakness (-1024/1024)
  - Slow/Slow II (-300/1024)
  - Indi/Geo-Slow (-204/1024)
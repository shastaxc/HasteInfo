# Haste Info
FFXI gearswap library that informs the GearSwap addon about haste potency (from buffs) on the player.

HasteInfo is designed to give people the ability to use more optimal gearsets in GearSwap based on
their current Haste buffs. For example, if you have enough haste between magic buffs, JA buffs, and gear,
you do not need to wear any Dual Wield gear. In fact, wearing Dual Wield gear when you don't get any
attack speed benefit from it (because you may already be attack speed capped) is actually bad for you
because Dual Wield reduces the amount of TP per hit you get from auto attacks.

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
  - Potencies are often wrong. Even when manually setting BRD potency manually (override) to +8 on songs, double march is not being detected as capped magic haste.
* Bloat
  - GearInfo calculates a lot of various stats, not just Haste. But GearSwap only cares about Haste.
* Random error spam
  - Specifically, there seems to be some occasions where BRD songs can get GearInfo into a state where
  it just spams error messages, and cannot be fixed without a full addon reload.

HasteInfo assumes that your equipment haste is always capped in order to avoid one of the points I made above.

Sources of Haste accounted for:
* GEO-Haste, Indi-Haste
* Haste Samba
* Embrava
* Haste, Haste II spells
* Hastega II (Garuda blood pact)
* Honor March, Victory March
* Hasso
* DRG Spirit Link

Haste potency assumptions:
* All GEOs have Idris (will add whitelist and blacklist feature later)
* All BRDs have max bonus to Marches (will add whitelist and blacklist feature later)
* Haste Samba is from sub DNC, unless there is a main DNC in your party
* SCH casting Embrava has 500 Enhancing Magic skill (capped Embrava potency)
* Assumes DRG Spirit Link Haste is already on if reloading addon (no buff on master to tell for sure)
* Is Haste aura from Entrusted Indi-Haste vs Indi-Haste/Geo-Haste?
  - First priority is listening to packets and detecting when an Indi-Haste is casted, then mark the target. If the
  target is the same as the caster, it's not entrusted. If Geo-Haste is casted, assume there's no 2nd Entrusted Indi-Haste.
  - By tracking all buffs on the party's GEOs. Watch for the "coloure active" buff to appear on the GEO, and then
  capture the aura buff that appears on them right after. If the Coloure Active buff and Indi buff appear on them
  within the same polling cycle, assume that's the one that was applied. By tracking all buffs on all players, you can
  ignore certain effects that may apply or fall off of the GEO to avoid race conditions.
* Slow potency is assumed to be max of 300/1024 (~29.3%)
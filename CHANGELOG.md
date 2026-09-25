## 1.1.0

- Optional decimal cast counts (off by default): show tenths that update as mana regenerates (e.g. 2.5 -> 2.7)
- Whole casts and zero never show a trailing .0 -- display 0 / 2 / 12, not 0.0 / 2.0
- Options preview and style chips follow the decimal setting
- Forever-safe formatting via SetFormattedText when power values are secret
## 1.0.9

- Mana delay countdown on the player frame (`4,2` format), draggable in options
- Default layout matches Ice: size 19 count, countdown to the right of the mana bar

## 1.0.8

- Mana spark starts when mana is actually spent, not on cast-success, and holds the last pixel so it lines up with regen

## 1.0.7

- Options are a single page: toggles, preview, styles, and font controls together
- Cast count, pulse, and mana spark are on by default
- Default count look: Arial Narrow, thick outline, size 19, ice cyan

## 1.0.6

- Removed the health-bar spark
- Removed the missing-power bar on spell icons
- Mana spark moves every frame and is sized to the portrait mana bar height

## 1.0.5

- Spark now attaches to Forever's player portrait bars (not the old Classic `PlayerFrameManaBar` name)
- Spark position no longer reads bar width in Lua, so secret unit-frame sizes cannot hide it
- Missing-power bar has a dark track so the fill on the spell icon is visible
- After `/reload` or toggling the spark option, the mana spark runs once so you can see it


## 1.0.4

- Designer: font color chips and picker, border, bold, shadow color and size
- Five premade styles: Classic, Goldleaf, Ice, Night, Punch

## 1.0.3

- Forever energy and mana fill continuously (no Classic 2-second ticks). Removed the energy-tick spark and the post-delay mana ticks
- Pulse uses `GetPowerRegenForPowerType` instead of a 20-energy tick
- Options: dropped Energy tick; Five-second rule is now an optional mana-delay spark, off by default

## 1.0.2

- Designer tab: sample action button with Frostbolt, drag the cast count and missing-power bar, resize with +/−, mouse wheel, or the bar corner grip
- Font, outline, lock, and reset layout

## 1.0.1

- Cast counts and missing-power bars now display when player power is a Forever secret value (no Lua math on secrets)
- Overlay is a StatusBar + outlined font string on top of the cooldown swipe
- Attach via Blizzard action-button mixins as well as named bars / LibActionButton
- Five-second rule starts from successful player casts, not only power deltas

## 1.0.0

- First public release for Classic Forever
- Missing-power bar and cast count on action buttons
- Pulse when the next energy/mana tick would make a spell affordable
- Five-second rule spark on the mana bar
- Energy and health regen tick sparks

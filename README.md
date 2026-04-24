# FDS Audio Register Viewer

This program tests/displays the FDS' read-only audio registers when toggling bit 1 of $4023 while playing wavetable audio.

It builds on top of ongoing research into $4023 interactions: [FDS-4023-Test](https://github.com/TakuikaNinja/FDS-4023-Test)

Forum thread: https://forums.nesdev.org/viewtopic.php?t=26313

Hardware Recording from a Twin Famicom: TODO

## Usage

Simply load the program into an FDS, whether it be original hardware or on an emulator. 
$4023 = `%10000011` on startup/reset, bits 0 and 7 cannot be changed. (IYKYK)

### Interface

- $4023 state at top of screen.
- Hex dump of $4090-$4097 below. (the second row containing 0s is meaningless)

### Controls

- B toggles bit 1 of $4023 (sound registers).
- A plays a sound on the FDS' wavetable channel.

## Building

The CC65 toolchain is required to build the program: https://cc65.github.io/
A simple `make` should then work.

## Acknowledgements

- `Jroatch-chr-sheet.chr` was converted from the following placeholder CHR sheet: https://www.nesdev.org/wiki/File:Jroatch-chr-sheet.chr.png
  - It contains tiles from Generitiles by Drag, Cavewoman by Sik, and Chase by shiru.
- `AccuracyCoin-Hex.chr` was taken from 100th_Coin's [AccuracyCoin](https://github.com/100thCoin/AccuracyCoin).
- Hardware testing was done using a Sharp Twin Famicom + [FDSKey](https://github.com/ClusterM/fdskey).
- The NESdev Wiki, Forums, and Discord have been a massive help. Kudos to everyone keeping this console generation alive!


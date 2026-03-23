# NES

## Architecture analysis

### CPU

The NES CPU is a Ricoh 2A03 which is based on the MOS technology 6502 8-bit microprocessor. It was manufactured by the company of the same name and also used as a sound chip/secondary CPU in a few Nintendo arcade games.

The 2A03 is quite similar to the 6502, both featuring the 6502 instruction set architecture, three general purpose registers X, Y (for indexes) and A (accumulator), an 8-bit data bus and 16-bit address bus and an 8-bit ALU and stack pointer.
The main difference between the 2 processors is the absence of the Binary-Coded Decimal mode in the 2A03 (replaced by the Audio Processing Unit), meaning that NES developers could not natively perform floating point number calculations without using alternative methods and tricks.

The CPU also has access to a 2KB SRAM (Static RAM) chip called the WRAM for ‘Work RAM’ which is used to store mutable data for games (score, health…).

### PPU (Picture Processing Unit)

The PPU works alongside the CPU as a co-processor that is tasked to store, process and display sprite graphics. Its function is similar to that of a modern-day GPU. However, unlike the CPU, it cannot be directly programmed, even though it also has its own dedicated 2KB SRAM called the VRAM for ‘Video RAM’.

This said memory is divided into 4 main sections. The first one is the pattern tables, of which there are two. Each of them contains 256 sprite tiles all measuring 8x8 pixels and occupy a total of 64KB. These sprites are used as the basic graphical building blocks for rendering the game components such as the background, characters or objects.

[![Pattern Tables](img/pattern_table.png)](https://pikuma.com/blog/game-console-history-for-programmers)

<p align="center">
  <em>Pattern tables for Super Mario Bros. (1985)</em>
</p>

The second one is the nametables, grids of 32x30 tiles taken from the pattern tables used to set-up the game background.

[![Nametables](img/nametables.png)](https://forums.nesdev.org/viewtopic.php?t=12636)

<p align="center">
  <em>Nametables for Super Mario Bros. 3 (1988)</em>
</p>

The third one is the palettes, which can go up to 8 (4 for the background and 4 for the foreground). Color data is not contained in the pattern tables, nor is it in the nametables. Rather, palettes are applied to tiles to color them. The NES is capable of producing 54 different colors, but palettes can only contain 4 at the time, with the first of them being set as a transparent one. This means that every tile from the pattern table can have 3 different colors at the time (excluding transparency). This also allows sprites to be used in a more versatile manner as color can easily be swapped.

[![Palettes](img/palettes.png)](https://youtu.be/7Co_8dC2zb8?si=y_qEafB4RluErYe6&t=543)

<p align="center">
  <em>Palette comparison between overworld and ground levels in Super Mario Bros. (1985)</em>
</p>

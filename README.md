# Hello World for the NES (6502 assembly version for the ca65 assembler)

Work in progress, but solution currently shows sprites, displays a background, and moves the sprites around with a d-pad.

## Project contents
 - hello_world.s - ca65 source file
 - hello.chr - sprite data.  Needs program like YY-CHR to open and edit.
 - hello_world.nes - Latest compiled ROM.
 - nes.cfg - configuration used by ca65 to build the rom.
 - compile.sh - Bash script to build the rom from source files.  Commands in it should be very similar to run if in Windows.
 - ca65_generic.mac, ca65_longbranch.mac - ca65 macros for quality-of-life improvements to the assembly. Source included under zlib license, from the CC65 project.




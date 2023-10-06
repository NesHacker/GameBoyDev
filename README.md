# GameBoyDev
An example gameboy game project.

## How to Build the ROM

### Depedencies
* [RGBDS](https://github.com/rednex/rgbds) - Game Boy Assembly & Linking Tools
* [GNU Make](https://gnuwin32.sourceforge.net/packages/make.htm) - Build system
tool (installation should only be required on Windows).

### Use Make to Build the ROM
With the assembler installed, open a command-line and run make:

```
$ make
```

This will run the make script and produce the `bin/GameBoyDev.gb` rom.

### Easy Build in VS Code

* Use the command pallette (`CTRL/CMD + SHIFT + P`) and select
`Tasks: Run Build Task`.

### Build Settings (ROM name, etc.)
For changes to how the game is assembled and linked, change the parameters in
[project.mk](./project.mk) (don't make changes to the [MakeFile](./Makefile)
directly).

## Suggested Emulators

* Windows - [BGB](https://bgb.bircd.org/)
  *(note: this should work fine on mac/linux using wine)*
* Mac / Linux - [Emulicious](https://emulicious.net/)

## VS Code Extensions

* `RGBDS Z80` [Web Link](https://marketplace.visualstudio.com/items?itemName=donaldhays.rgbds-z80) -
  Adds full language support for Game Boy Z80 Assembly (syntax highlighting & intellisense).

## Attribution
This project was derived from
[gb-boilerplate](https://github.com/ISSOtm/gb-boilerplate), for further details
please see [README-gb-boilerplate.md](./README-gb-boilerplate.md).

# meshcli_batch.sh
Batch Scipt for MeshCore USB Serial Programming.

## Info
Only tested with Heltec v4 as that is all I have access to currently.\
Handy to setup and configure multiple nodes at the same time and with consistent settings.\
I made notes in each file for what they do. I'll try and list how it all works below, but if you have any trouble consider looking in the files.\

### Background
I could not get the flasher or config web apps to work using the Chromimium borwser. Instead I had to confiure my nodes manually over serial. *I think they didn't work because they require google and that is blocked on my network. Those apps spam them alot.*\
I also had to revert firmware versions on all of my devices, including one on my roof. Having this script up there and being able to revert the firmware and configure it with a few key presses was nice, instead of having to type them all in. 

## Usage
- Place meshcli_batch.sh and all needed files in the same directory. 
- Make meshcli_batch.sh executable with `sudo chmod +x meshcli_batch.sh`
- Execute script with `/your/directory/meshcli_batch.sh`\
  - I like to change to the directory the script is in and run it with `./meshcli_batch.sh`

## Files

### Core Files
Script
- File: meshcli_batch.sh
- The script that brings it all together. `meshcli_batch.sh -h`

Devices
- File: devices.txt
- Format
 - A single line with Regio=(Your Region)
  - Region=US
 - No spaces in names.
 - Order, comma separated
 - Serial/MAC,Role,Name
  - AA:BB:CC:DD:EE:FF,CU,MechCoreUSBCompanion
  - 11:22:33:44:55:66,BD,MeshCoreBaseRepater


Regions
- File: regions.txt
- Format
 - Order, equal sign separated
 - Region=Command to set radio
  - US=set radio 910.525,62.5,7,5
- Provides some default regions that can be specified in devices.txt to keep you out of trouble and give newcomers a saftey net.
- I added a few custom regions I found on the www with thier sources. 

### Roles and Associated Files Used

CB = Companion Bluetooth
- File: cmd_com.txt

CU = Companion USB
- File: cmd_com.txt

BR = Base Repeater
- File: cmd_rep.txt
- File: cmd_rep_bas.txt

MR = Mobile Repeater
- File: cmd_rep.txt
- File: cmd_rep_mob.txt

RS = Room Server
- File: cmd_roo.txt

RB = Room Server/Base Repeater (Not recommended per MeshCore Documentation)
- File: cmd_roo.txt
- File: cmd_rep.txt
- File: cmd_rep_bas.txt

RM = Room Server/Mobile Repeater (Not recommended per MeshCore Documentation)
- File: cmd_roo.txt
- File: cmd_rep.txt
- File: cmd_rep_mob.txt

# Thanks to
austinmesh.org for the great info they provide.

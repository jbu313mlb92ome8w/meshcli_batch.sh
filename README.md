# meshcli_batch.sh
Batch Scipt for MeshCore USB Serial Programming.

## Info
Only tested with Heltec v4 as that is all I have access to currently.<br>
Handy to setup and configure multiple nodes at the same time and with consistent settings.<br>
I made notes in each file for what they do. I'll try and list how it all works below, but if you have any trouble consider looking in the files.<br>
I dont't have a micro$lop OS to test this setup on. Someone let me know if it works?<br>

### Background
I could not get the flasher or config web apps to work using the Chromimium borwser. Instead I had to confiure my nodes manually over serial. *I think they didn't work because they require google and that is blocked on my network. Those apps spam them alot.*<br>
I also had to revert firmware versions on all of my devices, including one on my roof. Having this script up there and being able to revert the firmware and configure it with a few key presses was nice, instead of having to type them all in.<br>

## Usage
- Place meshcli_batch.sh and all needed files in the same directory. 
- Make meshcli_batch.sh executable with `sudo chmod +x meshcli_batch.sh`
- Execute script with `/your/directory/meshcli_batch.sh`
  - `sudo` is not needed to run this script.
  - Your user may need to be part of the `dialout` group to access serial USB devices.
  - I like to change to the directory the script is in and run it with `./meshcli_batch.sh`
- Edit the listed Core Files below to configure and automate identifying your devices with thier name and Serial/MAC, device name, device role, your region/frequencies.
  - Quick example (or not), associating a device Serial/MAC with a name in devices.txt will mean that anytime you run the script the name will be updated. Great for firmware reverts or changing firmware roles... You can also associate a role in devices.txt too to run more in-depth mesh-cli commands. 
- Edit the listed role files below to issue certian commands based on the role/purpose your node is going to play on the MeshCore network.
  - Another example, you have a base and mobile repeater. No need for the mobile to be cooking at the full 28dB like the base station so you can set it to 21dB. Each one specified in their respective .txt.
> [!TIP]
> **Look in the [example folder](/examples) to see a scenario on how this script can be used.**
  - I haven't played with the Room Server (or a no-no Room Repeater) firmware yet so I don't have that .txt filled out. However, I have implented the files and script to work with them. 

## Files

### Core Files
Script
- File: meshcli_batch.sh
- The script that brings it all together. `meshcli_batch.sh -h`

Devices
- File: devices.txt
- Format
  - A single line with Region=(Your Region)
  - Two examples below. Only define one "Region=".
    - Region=US
    - Region=US-CA-SO
  - No spaces in names
  - Order, comma separated
  - Serial/MAC,Role,Name
    - AA:BB:CC:DD:EE:FF,***CU***,MechCoreUSBCompanion
    - 11:22:33:44:55:66,***BD***,MeshCoreBaseRepater

Regions
- File: regions.txt
- Format
  - Order, equal sign separated
  - Region=Command to set radio   
    - Region naming format, dash separated
    - Country-State/Territory/Etc-Additional Area
      - US=set radio 910.525,62.5,7,5
      - US-CA-SO=set radio 927.875,62.5,7,8
- Provides some default regions that can be specified in devices.txt to keep you out of trouble and give newcomers a saftey net.
- I added a few custom regions I found on the www with thier sources. 

### Roles and Associated Files Used

***CB*** = Companion Bluetooth
- File: cmd_com.txt

***CU*** = Companion USB
- File: cmd_com.txt

***BR*** = Base Repeater
- File: cmd_rep.txt
- File: cmd_rep_bas.txt

***MR*** = Mobile Repeater
- File: cmd_rep.txt
- File: cmd_rep_mob.txt

***RS*** = Room Server
- File: cmd_roo.txt

***RB*** = Room Server/Base Repeater (Not recommended per MeshCore Documentation)
- File: cmd_roo.txt
- File: cmd_rep.txt
- File: cmd_rep_bas.txt

***RM*** = Room Server/Mobile Repeater (Not recommended per MeshCore Documentation)
- File: cmd_roo.txt
- File: cmd_rep.txt
- File: cmd_rep_mob.txt

## Useful Resources

https://pypi.org/project/meshcore-cli/
- Check `meshcli` version
<br>

https://deepwiki.com/ripplebiz/MeshCore/10.2-basic-configuration
- Big Help
<br>

https://github.com/meshcore-dev/MeshCore/blob/main/docs/faq.md#513-q-can-i-use-a-raspberry-pi-to-update-a-meshcore-radio
- Manual USB serial flashing. Didn't find until after I solved that myself.
  - "Non-merged bin keeps the existing Bluetooth pairing database"
  - "Merged bin overwrites everything including the bootloader, existing Bluetooth pairing database, but keeps configurations."
- esptool flasher for MeshCore soming soon!
<br>

https://wiki.meshcoreaus.org/books/doc-firmware/page/doc-cli-reference
- Just found. Seems useful and will be checking out.
<br>

# Thanks To
Tommy Ekstrand of [Austin Mesh](austinmesh.org) for the great info they provide. Also, for providing a [Github](https://github.com/austinmesh/www) that I've seen other meshes use as a website template. 

## Advanced

```
# Putting "bash " at the beginning of a line executes a bash command.
# All other lines are prefixed with "meshcli -s " or "meshcli -s -r -j " depending on if the device is marked as a repeater or not.
```
All included .txt files have a variation of these two lines at the top. However, these two exact lines are the most common and most powerful. As you can see in the first line you can trigger bash commands from these files. Be very careful of that.
<br>
<br>
```
# The "Region=" in "devices.txt" will take care of your frequency. Sometimes certain nodes need separate coding rates, that is what this code block can be used for.
# Copy this block to other "cmd_*.txt" files if separate coding rate is needed for specific roles.
# set radio breakout:
# frequency,bandwidth,spread factor,coding rate
# Uncomment (aka delete #) to use
#####
set radio 910.525,62.5,7,8
bash echo -e "\033[0;31mThese errors are part of the reboot process.\033[0m"
reboot
bash echo -e "\033[0;31mBoard rebooting.\033[0m"
bash sleep 5
bash echo -e "\033[0;31mBoard reboot complete... hopefully.\033[0m"
#####
```
This code block is in the [example/cmd_rep_bas.txt](/examples/cmd_rep_bas.txt) and [blanks/cmd_pre.txt](/blanks/cmd_pre.txt) files commented out. You can see the purpose of it listed in the commented out portion. I use this to change the coding rate to 8 on my base repeater while leaving everything else at the US default of 5.<br>
I left it commented out in the provided .txts in case someone chose a region besides the US and didn't see this code block or wasn't sure of it's purpose.
<br>
<br>
Companions do not seem to throw errors when the `meshcli reboot` command is issued. The repeaters do. I am not sure about room servers yet, but i am guessg they throw the errors as well being that they appear to run the same commands. I haven't had an issue with reconnecting to the specified device, even with other LoRa boards conneted at the same time, after the reboot with the five second sleep. It could possibibly be tuned down, but I figure it would take more time to tune then it would save me a few spare seconds every now and then. Alos, other devices LoRa and computer may need a bit londeger to boot or read the device again.
<br>
<br>
<br>
<br>
Funny story while adding the region.txt support into this script involving these two code blocks. I copied and pasted the set radio code block directly into the script and ran it thinking the `reboot` command was going to be run within `meshcli`... it did not... and my computer rebooted.

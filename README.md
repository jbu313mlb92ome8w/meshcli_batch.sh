# meshcli_batch.sh
Batch Scipt for MeshCore USB Serial Programming.

## Info
- Only tested with Heltec v4 as that is all I have access to currently.
- Handy to setup and configure multiple nodes at the same time and with consistent settings.
- I made notes in each file for what they do. I'll try and list how it all works below, but if you have any trouble consider looking in the files. 

### Background
I could not get the flasher or config web apps to work using the Chromimium borwser. Instead I had to confiure my nodes manually over serial. 
- <sub>I think they didn't work because they require google and that is blocked on my network. Those apps spam them bad.<sub>

## Usage
#### place meshcli_batch.sh and all needed files in the same directory. 
##### make meshcli_batch.sh executable with `sudo chmod +x meshcli_batch.sh`
#### execute script with `/your/directory/meshcli_batch.sh`
##### I like to change to the directory the script is in and run it with `./meshcli_batch.sh`






## Roles and associated files used

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

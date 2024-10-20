# what does this module do ?
- This module monitor the status of the `com.android.systemui` and detect potential crashed and bootloops
- if installing any fishy module caused the system to behave abnormal , this module takes action and disables problematic modules to recover the system.
- If the device fails to complete boot within  90 seconds  the script disables all modules
- It also checks for repeated boot attempts and identifies if the device is stuck in a boot loop. If a boot loop is detected, script disables the modules, and trigger reboot.
- if the SystemUI is stopped for more than 40 seconds  , this module takes action to prevent further issues,  disables all KernelSU/Magisk modules except itself and trigger a reboot.
- you can change the threshold and monitor time by yourseld by editing `service.sh`
  
- logs are stored in `/data/local/tmp/`




# Anti bootloop features
Protection from bootloop. Press your button combination at boot to disable magisk modules
> [Vol-] + [Power key], [Vol+] + [Power key], [Power key] + [Power key], [Vol+] + [Vol-]... OR just [Power key], [Vol+] and etc.
###### [Touch screen] option
[Touch screen] option is avaliable only in the button combination, this is trigering the module when you move your finger across the screen. [Touch screen] + [Vol+] for example


#Bugs

if you get any , you can write [here](https://t.me/rhyphxc)

# system-setup

Tooling to help with the fresh installation of a Debian system, using the 2 submodules:

- **init-instroot**: initialises the installation root directory by setting up devices, configures encyption, formats filesystems, initializes swap devices, and generates fstab and crypttab entries.
- **debian-setup**: installs and configures a fresh Debian system on the installation root directory initialised earlier by the **init-instroot** script.
- **tests**: extensive end-to-end testing framework to run various installation configurations using Qemu/KVM virtual machines.

## How to Contribute

To file issues, regarding the end-to-end installation process, please file the issue to this repository.
If the issue is specific to one of the submodules, please file the issue for their relevant submodule.

Debian system setup
===================

Installation instructions:

1. Boot from a [Debian Live image](https://www.debian.org/CD/live/)
2. Install packages in order to run the system setup:

        sudo apt update
        sudo apt install git guile-2.2

3. Clone this repo:

        git clone --recursive https://github.com/dadinn/system-setup

4. Format hard drives

   Go into the `init-instroot` directory and follow instructions

5. Install the Debian operating system

   Go into the `debian-setup` directory and follow instructions

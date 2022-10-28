# my home

I will keep this project called "my home" for now. As in, `~/`.

It can be your home too.

A lot more information will be added to this
README in the near future (hopefully).

![Screenshot](https://user-images.githubusercontent.com/100702441/198291280-8a2f9624-3ebb-4518-9f30-92d7de686360.png "Screenshot")

## About this project

The aim of this project is ***not*** to create a new distribution,
or a new desktop environment. There is a lot to choose from.

Instead, this project tries to be something like
a `Dockerfile` to your workstation -
the whole installation process defined, for example in a `Bash` file
and the system configuration tracked in a `git` repository,
so every change is always visible and easily reversible.

This means that you have to install once, track changes
easily using `git`, and whenever you need to reinstall,
install from your latest backup (in this case a commit),
and you always get to your very last state.

This is probably not very useful for casual users,
but might be very useful to developers or administrators,
who benefit from being able to tune their system exactly
to their needs and have minimal hassle when needing to reinstall.

Currently, this whole project is based on
[openSUSE Tumbleweed](https://get.opensuse.org/tumbleweed/),
but this idea could be turned into a multi-distribution
project very easily.
[Arch Linux](https://archlinux.org/) would be essential,
but I would currently need a maintainer for that. I could add
[Debian](https://www.debian.org/) support quite easily,
meaning this could be used for creating easily-reproducible
devices like kiosks, as it would run pretty smoothly on Raspberry Pis too!
In fact, I am already using it on all my Raspberry Pis,
I just need to merge those into this project.

However, **advantages** of openSUSE Tumbleweed:

openSUSE Tumbleweed is upstream of
[SUSE Linux Enterprise](https://en.wikipedia.org/wiki/SUSE_Linux_Enterprise).
Thanks to their unique
[Open Build Service](https://en.wikipedia.org/wiki/Open_Build_Service),
all updates are individually tested and very stable.
Built from latest kernel releases, so you always have the latest
drivers for your hardware.

With a single command you can update thousands of packages,
rollback to last week’s snapshot, fast-forward again,
and even preview upcoming releases.

It's also secure.

### How to install and use

#### Install the base system
Currently, the very first installation must be carried
by the distro's official installer, but every other reinstall
of the same machine is automatic!

So for your first install, you can just download
the official ISO file from openSUSE and
[follow the official instructions](https://get.opensuse.org/tumbleweed/).

During the installation process, choose to install the "server"
version, which is the smallest base preset you can install.

#### Getting your home
As this is your initial install, clone this repository
into your home directory.

It is expected that this is a clean install and that **conflicting
files will be overwritten with the repository files**.

You can do it like this:

```
cd ~
git init .
git remote add origin https://github.com/frantisekstanko/my-home
git fetch origin
git checkout -f origin/main
git checkout main
git merge origin/main
```

Now, all the configuration is downloaded and tracked in your home
folder. You can easily edit and commit back to your local branch.
You can push to your backup server. You can reinstall from your
backup server and reset to your last checkpoint easily!

#### Install everything on top of the base system

Along with the configuration, a very important bash script
was merged into your home and that is
[~/bin/update](https://github.com/frantisekstanko/my-home/blob/main/bin/update).

This script performs either an initial install of everything
custom on top of the base system, or updates it at
any point in time.

You can just run it from your command line like this:

```
$ update
```

And follow the instructions on-screen.

The beautiful thing about this `update` script, which I consider
a ***core*** of this whole project, is that it is designed
to be executed over and over again safely. This ensures 4 things:

- the same procedure can be executed from any starting point of the system

- if the script fails, there is no need to "rollback" to anywhere;
simply see what has gone wrong, fix the problem,
and execute the script again, without even needing to reboot

- as this script is already tracked with `git`,  you can commit
any fixes or changes and in a future reinstall, already start
with those fixes applied (or open a pull request and share with us!)

- when you are on a deployed system and decide to add/install
something, you do it once and for all; simply by adding it to the
script itself

How cool is that?

### So what now

After the install, your desktop environment is ready with:

- [i3gaps](https://github.com/Airblader/i3) - a tiling window manager,
which can be set to stacking with just one config parameter
- [polybar](https://github.com/polybar/polybar) - a fast and easy-to-use
tool for creating status bars
- [kitty](https://github.com/kovidgoyal/kitty) - the fast, feature-rich,
cross-platform, GPU based terminal

All your favorite software can be installed easily, for example:

- Steam
- Spotify
- Google Chrome
- VirtualBox
- even PHPStorm
- and Nvidia drivers, thanks to openSUSE

### How to track changes and edit everything to your liking

In `~/.config/updater/profiles/`, a profile for this install
is created. The profile contains 2 important files:

- `.env` - the main configuration of this profile.
You can edit this file whenever you want by executing
`update --env`. you can change this configuration,
save it, then run `update` again and the new configuration
will be applied
- `DATETIME-clean.install.xml` - this file
can be later used for unattended reinstall of this
workstation

Both files can, and should be, commited to your local repository;
for backup purposes, for example.

#### If you don't like anything

Look at `~/bin/update` and see how the system was installed.
Change whatever you don't like, or add anything you need.
Edit any of the configuration files. Open pull requests.
Open issues. Tell me what you think!

## Cool default configuration

Thanks to an amazing work by
[Justin Buchanan](https://github.com/justbuchanan/i3scripts),
we have a beautiful and ingenious task manager for i3. In this example,
you can see 3 workspaces with various apps running.
The second workspace holds 3 instances of Firefox.

![1666892801](https://user-images.githubusercontent.com/100702441/198362002-adc83818-5529-48ed-8b6f-76abdc841f30.png)

The bar is [easily configurable](https://github.com/polybar/polybar/wiki).

Here's a git status, cpu status, available RAM, volume,
amount of CO2 in my room, battery and backlight:

![1666892380](https://user-images.githubusercontent.com/100702441/198362004-682f014b-cb5b-41fb-8f2a-3df01aeee1ec.png)

White values are notices. Red values are danger. The ranges can be configured.

### Things that work out of the box:

Nvidia drivers work perfectly if you're on Optimus (enterprise notebooks,
mostly Dell).

i3 keyboard shortcuts are preconfigured and all can be changed
easily. By default:

- `ALT+Enter` opens a terminal
- `ALT+D` opens a "start menu" to look for whatever
- `ALT+P` saves a screenshot to `~/screenshots/`
- `ALT+O` locks the screen
- `ALT+Tab` switches between windows
- `ALT+Shift+Q` closes a window
- Media/volume and brightness keys also work by default
- `ALT+[` and `ALT+]` increase and decrease the notebook
screen brightness, so if you're using an external keyboard,
you don't need to reach your notebook

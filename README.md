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
but I would need a maintainer for that. I could add
[Debian](https://www.debian.org/) support quite easily,
meaning this could be used for creating easily-reproducible
devices like kiosks, as it would run pretty smoothly on Raspberry Pis too!

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

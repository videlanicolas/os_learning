# Learning to make an OS
I always wanted to learn how everything in an operating system works, I learnt the theory while in university but never made one myself. This repository is released to the public domain, because I don't intend to code nor support a new OS. All the code in this repository is used for learning.

## Resources

The main resource website is [OS dev wiki](https://wiki.osdev.org/), but in there they already say that we're going to need more resources to make an OS.

## OS devlog

I documented all my progress at https://learning-os-from-scratch.readthedocs.io/en/latest, so you can read that to deep dive into all the things I learnt from developing this OS.

### Development

Install Sphinx:

```bash
$ pip install -U sphinx sphinx-autobuild
```

Run a local build:

```bash
$ sphinx-autobuild source build
```

## Getting started

Install the required things:

```bash
$ sudo apt install qemu-system nasm
```

### Running

```bash
$ make run_courses
```

ALT + 2 then `quit`.
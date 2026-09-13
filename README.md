# 42 Homebrew for macOS Catalina

A lightweight Homebrew bootstrapper for **42 school Macs running macOS Catalina 10.15 on Intel (`x86_64`)**.

It installs Homebrew inside `~/goinfre`, requires **no sudo/root access**, and pins Homebrew plus its taps to versions that still work on Catalina.

> Modern Homebrew no longer supports macOS Catalina. This project keeps a frozen legacy setup specifically for old 42 sessions.

## Install

Run this directly in your terminal:

```sh
curl -fSs https://raw.githubusercontent.com/admansar/42homebrew/refs/heads/main/brew_install.sh | sh
```

Then reload your shell:

```sh
source ~/.zshrc
```

Check that Homebrew is available:

```sh
brew --version
```

## Example

```sh
brew install tree
tree --version
```

Or:

```sh
brew install lolcat
ls | lolcat
```

## What the installer does

The script is designed for restricted 42 sessions where users do not have root access.

It:

- installs Homebrew in `~/goinfre/homebrew`
- does not use `sudo`
- does not write to `/usr/local` or `/opt/homebrew`
- pins Homebrew to `4.4.32`
- freezes `homebrew-core` to a matching historical commit
- freezes `homebrew-cask` to a matching historical commit
- disables Homebrew automatic updates
- disables Formula API installation so Homebrew uses the frozen local taps
- adds the Homebrew environment to `~/.zshrc`
- adds a small `brew()` wrapper so the legacy protections are always enabled
- fixes the common world-writable `~/Library/Python` permission warning when needed
- cleans the common NVM/npm `/usr/local` prefix conflict when detected

## Why is Homebrew frozen?

Current Homebrew no longer runs normally on macOS Catalina.

Using a recent Homebrew checkout on Catalina can result in errors such as:

```text
ERROR: Your version of macOS (10.15.7) is too old to run Homebrew!
```

Using an older Homebrew binary with modern formula definitions can also fail with errors such as:

```text
undefined method `compatibility_version'
```

This installer avoids that mismatch by keeping these components from the same compatible period:

```text
macOS Catalina 10.15
        |
        +-- Homebrew 4.4.32
        +-- matching homebrew-core
        +-- matching homebrew-cask
        +-- HOMEBREW_NO_AUTO_UPDATE=1
        +-- HOMEBREW_NO_INSTALL_FROM_API=1
```

## Important

Do **not** run:

```sh
brew update
```

The installation is intentionally frozen. Updating Homebrew can move it back to a version that no longer supports Catalina.

Normal package installs are still done with:

```sh
brew install <package>
```

## Requirements

- 42 school Mac or another machine with a usable `~/goinfre` directory
- macOS Catalina `10.15.x`
- Intel `x86_64`
- Git
- curl
- Xcode or Xcode Command Line Tools already available
- no root access required

The script checks the environment before installing.

## Installation location

Homebrew itself:

```text
~/goinfre/homebrew
```

Installed formulae:

```text
~/goinfre/homebrew/Cellar
```

The real 42 storage path is commonly something similar to:

```text
/goinfre/$USER/homebrew
```

because `~/goinfre` is usually a symlink to the user's goinfre storage.

## Shell configuration

The installer manages a block in `~/.zshrc` between:

```text
# >>> 42 CATALINA HOMEBREW >>>
...
# <<< 42 CATALINA HOMEBREW <<<
```

This makes the installer safe to run again without duplicating the Homebrew configuration block.

To verify the wrapper after installation:

```sh
type brew
```

You should see that `brew` is defined as a shell function.

You can also verify the protections:

```sh
echo $HOMEBREW_NO_AUTO_UPDATE
echo $HOMEBREW_NO_INSTALL_FROM_API
```

Both should print:

```text
1
```

## Reinstall

You can simply run the installer again:

```sh
curl -fSs https://raw.githubusercontent.com/admansar/42homebrew/refs/heads/main/brew_install.sh | sh
```

The script removes the previous `~/goinfre/homebrew` installation and recreates the compatible setup.

## Uninstall

Remove Homebrew:

```sh
rm -rf ~/goinfre/homebrew
```

Then remove the block between these markers from `~/.zshrc`:

```text
# >>> 42 CATALINA HOMEBREW >>>
# <<< 42 CATALINA HOMEBREW <<<
```

Reload the shell:

```sh
source ~/.zshrc
```

## Notes

This project is a compatibility workaround for legacy 42 Catalina machines, not an officially supported Homebrew configuration.

Some newer formulae may still require a newer macOS, compiler, SDK, or Xcode version even when Homebrew itself works.

## Credits

Created by [admansar](https://github.com/admansar).

Inspired by the original [kube/42homebrew](https://github.com/kube/42homebrew) project for installing Homebrew on 42 sessions.

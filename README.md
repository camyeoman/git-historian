## Git Historian

This cli tool scrapes your git commit history to print out a pretty summary of what you did, and when. Useful for filling in timesheets. See example
output of the cli tool below.

<div align="center">
   <img
      width="830"
      alt="image"
      src="https://github.com/user-attachments/assets/b7badd06-6187-4bc0-b9cc-a89c74d90ebd"
   />
</div>

## Quickstart Guide

### Installation

1. Install nushell, if you have nodejs installed the simplest way is just to run `npm i -g nushell`, or see [official documentation](https://www.nushell.sh/book/installation.html)
2. Then run the following commands
   ```nushell
   $ nu
   $ mkdir ~/.scripts
   $ cd ~/.scripts
   $ git clone https://github.com/camyeoman/git-historian.git
   ```

### Setup

>[!NOTE]
> The exact command to run depends on what shell you are in, but you need to provide a valid path to the script. So for windows users,
> the command prompt path would be `%homepath%\.scripts\git-historian\cli.nu`, but for powershell or Mac/Linux users the path would
> simply be `~/.scripts/git-historian/cli.nu`. To avoid having to think about paths, run `nu` before running script to enter the nushell shell,
> and use the `~/.scripts/git-historian/cli.nu` style path. Use the `exit` command after you are done to get back to your original shell if you want.
> Otherwise substitute the path as needed for your shell.

You can run the tool using `$ nu ~/.scripts/git-historian/cli.nu logs` in your project's directory, but if you want it to parse the git
history of multiple local git repositories at once, i.e you work on multiple projects, then you will need to save the filepaths to these
as 'saved projects'. To do this,

1. Open a terminal or navigate to the relevant git repository, e.g `cd ~/Code/stratex/`
2. Run `$ nu ~/.scripts/git-historian/cli.nu project save`

Or you can simply run `$ nu ~/.scripts/git-historian/cli.nu project save ~/Code/stratex ~/Code/vportal`.

### Running the script

Now simply run the relevant command for the interactive mode. Use the `--help` flag to get more documentation.

### Powershell or Linux/Mac shells
```nushell
  $ nu ~/.scripts/git-historian/cli.nu logs
```

### Command Prompt (Windows)
```nushell
  $ nu %homepath%\.scripts\git-historian\cli.nu logs
```

### Generic command to work in any shell
```nushell
  $ nu
  $ nu ~/.scripts/git-historian/cli.nu logs
```



## Quickstart Guide

1. Install nushell, simplest way is just to run `npm i -g nushell`, or see [installation documentation here](https://www.nushell.sh/book/installation.html)
2. Clone the git repository. I would recommend creating a ~/.scripts folder and putting it there, but where you put it is up to you.
3. Next you need to save the paths to all the relevant local git repositories that you want to track. To do this, either
   1. Use cli commands as follows
       1. Open a terminal or navigate to the relevant git repository
       2. Run `$ nu {path-to-this-repo}/cli.nu project save`
       3. Repeat these steps for all relevant local git repositories.
   2. or Edit the `./saved-projects.yml` file directly, it is just a list of filepaths
4. Now simply run `$ nu {path-to-this-repo}/cli.nu logs` and navigate forward/backwards using left and right arrow keys

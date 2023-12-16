# Obsidian-Sync

![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/pourmand1376/Obsidian-Sync/pre-commit.yaml)

Obsidian Sync with Android

This script is written for the Termux application.

Prerequisite:
You should have created a git repository containing only your notes in obsidian. Then you'll be able to follow along with this tutorial.

Use this script via

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pourmand1376/obsidian-sync/main/obsidian.sh)"
```

Then follow the steps in the script to sync the Obsidian git repo you have created.

You can just follow the numbers from 1 to 7 and you are done. Don't worry it would take only 5 minutes or less!

1. First, you choose 1. At this step all required dependencies like git would be installed.

2. Then you would grant Termux the access your files. This is needed since obsidian can not see Termux files. We should save obsidian files inside a shared directory. We will save them inside your downloads folder.

3. You enter your name and your email address. Then an SSH-Key is generated for you. You should upload the content of this ssh-key to your [github](https://github.com/settings/keys) acccount (or any git server you are using).

4. You enter the url of your obsidian git repository and we will fork it. The url has to be SSH url, it is in the form of `git@github.com:your_name/your_repo.git`

5. Then you choose your obsidian folder and we will add some files to make git commits automatic.

6. You choose your obsidian folder and suggest an alias to be used for ease of use.

After that you only need to open obsidian and type the alias you created to sync the repository.

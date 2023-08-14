# Guide: Sign Git commits

- [Guide: Sign Git commits](#guide-sign-git-commits)
  - [Overview](#overview)
  - [Signing commits using GPG](#signing-commits-using-gpg)
    - [Generate GPG key](#generate-gpg-key)
    - [Configure Git](#configure-git)
    - [Configure GitHub](#configure-github)
    - [Troubleshooting](#troubleshooting)
    - [Additional settings](#additional-settings)
  - [Signing commits using SSH](#signing-commits-using-ssh)
    - [Generate SSH key](#generate-ssh-key)
    - [Configure Git](#configure-git-1)
    - [Configure GitHub](#configure-github-1)
  - [Testing](#testing)

## Overview

Signing Git commits is a good practice and ensures the correct web of trust has been established for the distributed version control management, e.g. [Bitwarden](https://bitwarden.com/).

There are two ways to sign commits in GitHub, using a GPG or an SSH signature. Detailed information about this can be found in the following [documentation](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification). It is recommended to use the GPG method for signing commits as GPG keys can be set to expire or be revoked if needed. Below is a step-by-step guide on how to set it up.

## Signing commits using GPG

### Generate GPG key

<!-- markdownlint-disable-next-line no-inline-html -->
If you do not have it already generate a new pair of GPG keys. Please, change the passphrase (<span style="color:red">pleaseChooseYourKeyPassphrase</span>) below and save it in your password manager.

```shell
USER_NAME="Your Name"
USER_EMAIL="your.name@email"
file=$(echo $USER_EMAIL | sed "s/[^[:alpha:]]/-/g")

mkdir -p "$HOME/.gnupg"
chmod 0700 "$HOME/.gnupg"
cd "$HOME/.gnupg"
cat > "$file.gpg-key.script" <<EOF
  %echo Generating a GPG key
  Key-Type: ECDSA
  Key-Curve: nistp256
  Subkey-Type: ECDH
  Subkey-Curve: nistp256
  Name-Real: $USER_NAME
  Name-Email: $USER_EMAIL
  Expire-Date: 0
  Passphrase: pleaseChooseYourKeyPassphrase
  %commit
  %echo done
EOF
gpg --batch --generate-key "$file.gpg-key.script"
rm "$file.gpg-key.script"
# or do it manually by running `gpg --full-gen-key`
```

Make note of the ID and save the keys.

```shell
gpg --list-secret-keys --keyid-format LONG $USER_EMAIL
```

You should see a similar output to this:

```shell
sec   nistp256/AAAAAAAAAAAAAAAA 2023-01-01 [SCA]
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
uid                 [ultimate] Your Name <your.name@email>
ssb   nistp256/BBBBBBBBBBBBBBBB 2023-01-01 [E]
```

Export your keys.

```shell
ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
gpg --armor --export $ID > $file.gpg-key.pub
gpg --armor --export-secret-keys $ID > $file.gpg-key
```

Import already existing private key. GPG keys are stored in the `~/.gnupg` directory.

```shell
gpg --import $file.gpg-key
```

Remove keys from the GPG agent if no longer needed.

```shell
gpg --delete-secret-keys $ID
gpg --delete-keys $ID
```

### Configure Git

Use the [following commands](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-gpg-key) to set your default signing key in Git to the ID of the GPG key you generated. Replace `$ID` with your actual GPG key ID from the script above.

  ```shell
  git config --global user.signingkey $ID
  ```

Then enable automatic signing of Git commits by running:

```shell
git config --global commit.gpgsign true
```

### Configure GitHub

To [add your GPG public key to your GitHub account](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account) follow these steps:

1. Navigate to your GitHub account settings.
2. From the sidebar, click on "**SSH and GPG keys**".
3. Click on the "**New GPG key**" button.
4. In the "**Title**" field, enter a descriptive name for the key, like "My GitHub signing key".
5. Copy the contents of your public key file and paste it into the "**Key**" field.

   ```shell
   cat $file.gpg-key.pub
   ```

6. Click "**Add GPG key**" to save.

After completing these steps, your new signing key will be listed in the "**SSH and GPG keys**" section of your GitHub profile.

### Troubleshooting

If you receive the error message "error: gpg failed to sign the data", make sure you added `export GPG_TTY=$(tty)` to your `~/.zshrc` or `~/.bashrc`, and restarted your terminal.

```shell
sed -i '/^export GPG_TTY/d' ~/.exports
echo "export GPG_TTY=\$TTY" >> ~/.exports
```

### Additional settings

Configure caching git commit signature passphrase for 3 hours

```shell
source ~/.zshrc # or ~/.bashrc
mkdir -p ~/.gnupg
sed -i '/^pinentry-program/d' ~/.gnupg/gpg-agent.conf 2>/dev/null ||:
echo "pinentry-program $(whereis -q pinentry)" >> ~/.gnupg/gpg-agent.conf
sed -i '/^default-cache-ttl/d' ~/.gnupg/gpg-agent.conf
echo "default-cache-ttl 10800" >> ~/.gnupg/gpg-agent.conf
sed -i '/^max-cache-ttl/d' ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 10800" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
git config --global credential.helper cache
#git config --global --unset credential.helper
```

## Signing commits using SSH

### Generate SSH key

You should not do this if you already have GPG signing set up. One or the other is fine, but not both.

If you do not already have SSH key access set up on your GitHub account, first [generate a new SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent). To create a new SSH key, you need to run the following command. This will generate a new SSH key of the type `ed25519` and associate it with your email address. Please replace your.name@email with your actual email address.

```shell
ssh-keygen -t ed25519 -C "your.name@email" -f "~/.ssh/github-signing-key"
```

When you run this command, it will ask you to enter a passphrase. Choose a strong passphrase and make sure to remember it, as you will need to provide it when your key is loaded by the SSH agent.

### Configure Git

If you are signing commits locally using an SSH key, you need to [configure Git](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key) accordingly since it is not the default method.

Run the following command to instruct Git to use the SSH signing key format, instead of the default GPG:

```shell
git config --global gpg.format ssh
```

Next, specify the private key for Git to use:

```shell
git config --global user.signingkey ~/.ssh/github-signing-key
```

Lastly, instruct Git to sign all of your commits:

```shell
git config --global commit.gpgsign true
```

### Configure GitHub

To [add your SSH public key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) follow these steps:

1. Navigate to your GitHub account settings.
2. From the sidebar, click on "**SSH and GPG keys**".
3. Click on the "**New SSH key**" button.
4. In the "**Title**" field, enter a descriptive name for the key, like "My GitHub signing key".
5. Copy the contents of your public key file and paste it into the "**Key**" field.

   ```shell
   cat ~/.ssh/github-signing-key.pub
   ```

6. Ensure to select "**Signing Key**" from the "**Key type**" dropdown.
7. Click "**Add SSH key**" to save.

After completing these steps, your new signing key will be listed in the "**SSH and GPG keys**" section of your GitHub profile.

## Testing

To ensure your configuration works as expected, make a commit to a branch locally and push it to GitHub. When you view the commit history of the branch on GitHub, [your latest commit](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#about-commit-signature-verification) should now display a `Verified` tag, which indicates successful signing with your GPG or SSH key.

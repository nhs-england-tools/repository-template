# Guide: Sign Git commits

- [Guide: Sign Git commits](#guide-sign-git-commits)
  - [Overview](#overview)
  - [Setup](#setup)
  - [Troubleshooting](#troubleshooting)
  - [Additional settings](#additional-settings)

## Overview

Signing Git commits is a good practice and ensures the correct web of trust has been established for the distributed version control management, e.g. [Bitwarden](https://bitwarden.com/).

## Setup

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

You should see a similar output to this

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

Import already existing private key.

```shell
gpg --import $file.gpg-key
```

Remove keys from the GPG agent if no longer needed.

```shell
gpg --delete-secret-keys $ID
gpg --delete-keys $ID
```

Configure Git to use the new key.

```shell
git config user.signingkey $ID
```

Upload the public key to your GitHub profile into the [GPG keys](https://github.com/settings/keys) section. After doing so, please make sure your email address appears as verified against the commits pushed to the remote.

```shell
cat $file.gpg-key.pub
```

## Troubleshooting

If you receive the error message "error: gpg failed to sign the data", make sure you added `export GPG_TTY=$(tty)` to your `~/.zshrc` or `~/.bashrc`, and restarted your terminal.

```shell
sed -i '/^export GPG_TTY/d' ~/.exports
echo "export GPG_TTY=\$TTY" >> ~/.exports
```

## Additional settings

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

# Sign Git commits

- [Sign Git commits](#sign-git-commits)
  - [Sign with GPG](#sign-with-gpg)
    - [Generate GPG key](#generate-gpg-key)
    - [Back up, import or remove a GPG key](#back-up-import-or-remove-a-gpg-key)
    - [Configure Git for GPG](#configure-git-for-gpg)
    - [Add the GPG key to GitHub](#add-the-gpg-key-to-github)
    - [Troubleshoot and configure GPG agent](#troubleshoot-and-configure-gpg-agent)
  - [Sign with SSH](#sign-with-ssh)
    - [Generate or select an SSH key](#generate-or-select-an-ssh-key)
    - [Configure Git for SSH](#configure-git-for-ssh)
    - [Add the SSH signing key to GitHub](#add-the-ssh-signing-key-to-github)
  - [Verify signing](#verify-signing)

This template does not configure commit signing or manage signing keys. Git
signs commits locally, and GitHub verifies signatures made with a key on your
account. Choose GPG or SSH. See GitHub's
[commit signature documentation](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
for account-specific requirements.

> [!WARNING]
>
> A batch file containing a passphrase and a private-key export both contain
> sensitive material. Keep them outside the repository, restrict access, and
> remove or protect copies after use. `Expire-Date: 0` creates a key without an
> expiry, and `git config --global` changes signing for all repositories. Choose
> settings that meet your organisation's policy.

## Sign with GPG

### Generate GPG key

First check whether you already have a signing key:

```shell
gpg --list-secret-keys --keyid-format LONG
```

If you need a new key, generate it interactively and choose a passphrase and
expiry when prompted. Do not put a passphrase in a command or temporary file:

```shell
gpg --full-generate-key
```

To create the original example's ECDSA P-256 primary key and ECDH P-256
encryption subkey without prompts, use a GnuPG batch parameter file. Replace the
name, email and passphrase before running this. `Expire-Date: 0` means the key
does not expire; change it to a duration such as `1y` if you want an expiry. The
parameter file contains your passphrase in plain text until removed. The quoted
`'EOF'` keeps the passphrase literal, so the shell does not expand `$`,
backticks or `$(...)` in it. GnuPG ignores leading and trailing spaces in the
passphrase:

```shell
USER_NAME="Your Name"
USER_EMAIL="your.name@example.com"
key_params="$(mktemp "${TMPDIR:-/tmp}/gpg-key.XXXXXXXX")"
chmod 600 "$key_params"
{
  cat <<'EOF'
Key-Type: ECDSA
Key-Curve: nistp256
Subkey-Type: ECDH
Subkey-Curve: nistp256
Expire-Date: 0
Passphrase: replace-with-your-passphrase
EOF
  printf 'Name-Real: %s\nName-Email: %s\n' "$USER_NAME" "$USER_EMAIL"
  echo '%commit'
} > "$key_params"
gpg --batch --pinentry-mode loopback --generate-key "$key_params"
rm -- "$key_params"
```

The second curve field is `Subkey-Curve`, not another `Key-Curve`. Do not run
these commands with a real passphrase where your terminal history or session
logs might capture it. If generation is interrupted, remove the parameter file
before leaving the terminal. Check the key ID and fingerprint:

```shell
gpg --list-secret-keys --keyid-format LONG "$USER_EMAIL"
```

An ECDSA/ECDH key from this example has an output shape like this:

```text
sec   nistp256/AAAAAAAAAAAAAAAA YYYY-MM-DD [SCA]
  <primary-key-fingerprint>
uid   [ultimate] Your Name <your.name@example.com>
ssb   nistp256/BBBBBBBBBBBBBBBB YYYY-MM-DD [E]
  <subkey-fingerprint>
```

### Back up, import or remove a GPG key

Make a portable backup if your key-transfer process requires one. Set `KEY_ID`
to the primary key ID from the listing above. The second export contains your
**private key**, not just its public half. `umask 077` creates that file
readable only by you, and `chmod 600` also fixes a file left by an earlier
export:

```shell
KEY_ID=YOUR_KEY_ID
gpg --list-secret-keys --keyid-format LONG "$KEY_ID"
gpg --armor --export "$KEY_ID" > "$HOME/.gnupg/github-signing-key.pub.asc"
(umask 077 && gpg --armor --export-secret-keys "$KEY_ID" > "$HOME/.gnupg/github-signing-key.private.asc")
chmod 600 "$HOME/.gnupg/github-signing-key.private.asc"
```

Transfer the private backup through your organisation's approved secure process.
Keep it outside the repository and remove any temporary copy once the backup is
verified. To restore it on another machine, import the private backup from its
secure location and confirm that the secret key appears:

```shell
gpg --import /path/to/secure-backup.asc
gpg --list-secret-keys --keyid-format LONG
```

If you need to remove a key locally, first confirm the ID and that you have a
usable backup. These commands delete the private key, then its public key from
your local GnuPG keyring; they do not remove keys from your GitHub account:

```shell
KEY_ID=YOUR_KEY_ID
gpg --delete-secret-keys "$KEY_ID"
gpg --delete-keys "$KEY_ID"
```

### Configure Git for GPG

Replace `YOUR_KEY_ID` below with the long ID of the key you want to use. Git
uses that key for future commits. The key's email identity must match your Git
committer email and a verified email on your GitHub account. Check your Git
identity with `git config user.email`. For an existing key with a different
identity, see GitHub's
[email association guidance](https://docs.github.com/en/authentication/managing-commit-signature-verification/associating-an-email-with-your-gpg-key).

```shell
git config --global gpg.format openpgp
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
```

### Add the GPG key to GitHub

Export the **public** key to your terminal for the GitHub website. Never upload
the private-key backup:

```shell
gpg --armor --export YOUR_KEY_ID
```

1. Open your GitHub profile menu and select **Settings**.
2. In the **Access** section, open **SSH and GPG keys**.
3. Select **New GPG key** and enter a descriptive title.
4. Paste the complete public key from the command above into **Key**.
5. Select **Add GPG key** and confirm your account access if prompted.

Alternatively, use GitHub CLI after signing in with `gh auth login`. The default
`gh` login scopes do not include `write:gpg_key`, so add it first. The CLI reads
a public-key file, so export one if you have not already done so:

```shell
gh auth refresh -h github.com -s write:gpg_key
gpg --armor --export YOUR_KEY_ID > "$HOME/.gnupg/github-signing-key.pub.asc"
gh gpg-key add "$HOME/.gnupg/github-signing-key.pub.asc" --title "My signing key"
```

See GitHub's
[GPG key instructions](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account).

### Troubleshoot and configure GPG agent

If GPG reports `gpg failed to sign the data`, try setting `GPG_TTY` in your
current terminal:

```shell
export GPG_TTY="$(tty)"
```

If it helps, add that export to the shell startup file you actually use so it is
set for each new terminal. On macOS, if GnuPG needs a graphical passphrase
prompt, find an installed pinentry program with `command -v pinentry-mac` and
set `pinentry-program` to its full path in `$HOME/.gnupg/gpg-agent.conf`.

To cache the GPG signing passphrase for up to three hours, set these options in
`$HOME/.gnupg/gpg-agent.conf`. Edit existing entries instead of adding
duplicates. A longer cache increases the time an unlocked key is available:

```text
default-cache-ttl 10800
max-cache-ttl 10800
```

Stop the agent after changing the file; GnuPG restarts it on the next use:

```shell
gpgconf --kill gpg-agent
```

`git config --global credential.helper cache` is a separate optional setting for
Git authentication credentials. It does not cache your GPG signing passphrase.

## Sign with SSH

### Generate or select an SSH key

Use an existing SSH key or generate a dedicated signing key. If you create one,
use an unused path and enter its passphrase interactively. If you already have a
key, use its path in the commands below instead:

```shell
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -C "your.name@example.com" \
  -f "$HOME/.ssh/github-signing-key"
```

### Configure Git for SSH

Tell Git to sign future commits with that private key:

```shell
git config --global gpg.format ssh
git config --global user.signingkey "$HOME/.ssh/github-signing-key"
git config --global commit.gpgsign true
```

### Add the SSH signing key to GitHub

Display only the public key. If you are using an existing SSH key, substitute
its public-key path:

```shell
cat "$HOME/.ssh/github-signing-key.pub"
```

1. Open your GitHub profile menu and select **Settings**.
2. In the **Access** section, open **SSH and GPG keys**.
3. Select **New SSH key** and enter a descriptive title.
4. Set **Key type** to **Signing Key**.
5. Paste the public key from the command above into **Key**.
6. Select **Add SSH key** and confirm your account access if prompted.

If this key is already registered as an authentication key, add it again as a
signing key. Alternatively, use GitHub CLI after signing in with
`gh auth login`. Add the `write:ssh_signing_key` scope first, then use the
public-key path you chose:

```shell
gh auth refresh -h github.com -s write:ssh_signing_key
gh ssh-key add "$HOME/.ssh/github-signing-key.pub" --type signing --title "My signing key"
```

See GitHub's
[SSH key instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).
If Git cannot prompt for your key's passphrase, follow GitHub's
[ssh-agent setup](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
to load the key securely.

## Verify signing

After your next normal commit and push, check that GitHub shows **Verified**
beside the commit. This confirms that GitHub recognised the signature and its
associated public key, not that the template configured signing for you. If a
GPG signature is **Unverified**, check that the uploaded public key, the key's
email identity and `git config user.email` agree with your verified GitHub
email. For other failures, see GitHub's
[signature troubleshooting](https://docs.github.com/en/authentication/troubleshooting-commit-signature-verification/checking-your-commit-and-tag-signature-verification-status).

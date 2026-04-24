# Naima

NixOS EC2 instance with Docker and Claude Code Remote Control.
Fully autonomous after first deploy — no operator presence needed at runtime.

## Prerequisites

NixOS, `opentofu` and `colmena` are installed by `shell.nix`

``` bash
eval $(ssh-agent) && ssh-add ~/.ssh/id_ed25519
```

Subscription: Claude Code Remote Control requires a **Pro or Max** claude.ai plan.

## Usage

If your session token has expired (you've been away long enough that the auth is stale), re-run the activation script: 

```bash
$ ./scripts/activate-session.sh
```

This will SSH in, let you re-authenticate claude via the browser link, seal the new token, and restart the claude-code-remote service.

If you think the token is still valid and the service just needs a kick (e.g., the connection dropped but auth is fine), you can just restart the service:

```bash
$ ssh root@$(cat secrets/instance-ip.txt) systemctl restart claude-code-remote
```

Then reconnect from https://claude.ai/code.

Also note: if your IP changed while you were away, the EC2 security group will block SSH. Run `tofu apply` first to update it.

## Deployment

### 1. Configure

```bash
cd tofu
cp terraform.tfvars.example terraform.tfvars
# Set: nixos_ami_id, ssh_public_key, repo_url
```

Find NixOS AMIs: https://nixos.org/download/#nixos-amazon

### 2. Deploy

```bash
tofu init && tofu apply
```

This provisions EC2, generates a deploy key, seals credentials on the
instance, and runs `colmena apply` automatically.

SSH access is restricted to your current public IP, detected automatically
via `ifconfig.me` at apply time. If your IP changes, run `tofu apply` again
to update the security group.

### 3. Add deploy key to GitHub

```bash
tofu output deploy_key_public
```

Copy the output and add it to:
GitHub -> repo -> Settings -> Deploy keys -> Add deploy key
Title: `naima` | Allow write access: **No**

Then restart the git-clone service (or wait for next boot):

```bash
ssh root@$(cat ../secrets/instance-ip.txt) systemctl restart git-clone-project
```

### 4. Activate Claude session

```bash
./scripts/activate-session.sh
```

This opens an interactive SSH session. Run `claude`, authenticate via browser,
then type `exit`. The script seals the real session token and restarts the service.

## Local testing

Test the full NixOS configuration locally using a `nixos-container`
(systemd-nspawn). Credentials and Docker are stubbed out — this verifies
that skills, instructions, and services deploy correctly without touching
the remote instance.

```bash
./test/test-container.sh
```

Once inside the container, verify:

```bash
ls /etc/claude-skills/                        # skill files
ls /root/.claude/skills/                      # symlinks
ls /etc/llm-instructions/                     # instruction files
systemctl status claude-skills-link           # "Linked 3 skill(s)"
```

The container is destroyed automatically when you exit.

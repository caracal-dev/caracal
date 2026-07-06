## Adapted from https://github.com/ublue-os/aurora
## Credit to the Aurora developers

import os
import subprocess
import argparse
import re


GITHUB_REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
GIT_REF_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")


def parse_pkg_list(filepath):
    pkgs = {}
    if not os.path.exists(filepath):
        return pkgs
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("|")
            if len(parts) == 2:
                pkgs[parts[0]] = parts[1]
    return pkgs


def get_pkg_version(pkgs, name):
    if name in pkgs:
        return pkgs[name]
    for k, v in pkgs.items():
        if name in k:
            return v
    return "Not Installed"


def validate_github_repo(repo):
    if not GITHUB_REPO_RE.fullmatch(repo):
        raise argparse.ArgumentTypeError(f"invalid GitHub repository: {repo}")
    return repo


def validate_git_ref(ref):
    if not GIT_REF_RE.fullmatch(ref) or ".." in ref or "@{" in ref:
        raise argparse.ArgumentTypeError(f"invalid git ref: {ref}")
    return ref


def get_git_log(repo, prev_tag, tag):
    pretty_format = f"* [%h](https://github.com/{repo}/commit/%H) %s (%an)"
    try:
        res = subprocess.run(
            [
                "git",
                "log",
                f"--pretty=format:{pretty_format}",
                f"{prev_tag}..{tag}",
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return res.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running git log: {e.stderr}")
        return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--current", required=True, help="Path to current pkg list")
    parser.add_argument("--previous", required=True, help="Path to previous pkg list")
    parser.add_argument(
        "--tag", required=True, type=validate_git_ref, help="Current tag"
    )
    parser.add_argument(
        "--prev-tag", required=False, type=validate_git_ref, help="Previous tag"
    )
    parser.add_argument(
        "--repo",
        required=True,
        type=validate_github_repo,
        help="GitHub repository, e.g. owner/repo",
    )
    parser.add_argument(
        "--output", required=True, help="Path to write changelog markdown"
    )
    args = parser.parse_args()

    curr_pkgs = parse_pkg_list(args.current)
    prev_pkgs = parse_pkg_list(args.previous)

    # Major packages
    major_pkg_names = {
        "Kernel": "kernel-core",
        "KDE Plasma": "plasma-desktop",
        "Mesa": "mesa-dri-drivers",
        "Podman": "podman",
        "Nvidia": "xorg-x11-drv-nvidia",
        "Wine": "wine-core",
        "Yabridge": "yabridge",
    }

    major_pkg_lines = []
    for pretty_name, search_name in major_pkg_names.items():
        curr_ver = get_pkg_version(curr_pkgs, search_name)
        prev_ver = get_pkg_version(prev_pkgs, search_name)
        if curr_ver != "Not Installed":
            if prev_ver != "Not Installed" and prev_ver != curr_ver:
                ver_str = f"{prev_ver} ➡️ {curr_ver}"
            else:
                ver_str = curr_ver
        else:
            ver_str = "Not Installed"
        major_pkg_lines.append(f"| **{pretty_name}** | {ver_str} |")

    major_pkg_table = "\n".join(major_pkg_lines)

    # Git commits
    commits_md = ""
    if args.prev_tag and args.tag:
        git_log = get_git_log(args.repo, args.prev_tag, args.tag)
        if git_log:
            # Filter merge/chore commits
            lines = []
            for line in git_log.split("\n"):
                if not line.strip():
                    continue
                if (
                    "merge pull request" in line.lower()
                    or "merge branch" in line.lower()
                ):
                    continue
                lines.append(line)
            commits_md = "\n".join(lines)

    if not commits_md:
        commits_md = "*No commits found.*"

    # Package changes
    pkg_changes = []
    all_names = sorted(list(set(curr_pkgs.keys()) | set(prev_pkgs.keys())))

    for name in all_names:
        if name not in prev_pkgs:
            pkg_changes.append(f"| ✨ | {name} | | {curr_pkgs[name]} |")
        elif name not in curr_pkgs:
            pkg_changes.append(f"| ❌ | {name} | {prev_pkgs[name]} | |")
        elif prev_pkgs[name] != curr_pkgs[name]:
            pkg_changes.append(
                f"| 🔄 | {name} | {prev_pkgs[name]} | {curr_pkgs[name]} |"
            )

    if pkg_changes:
        package_changes_table = "\n".join(pkg_changes)
    else:
        package_changes_table = "| | No package changes detected. | | |"

    changelog_content = f"""This is an automatically generated changelog for release `{args.tag}`.

### Major packages
| Name | Version |
| --- | --- |
{major_pkg_table}

### Commits
{commits_md}

### Package changes
| | Name | Previous | New |
| --- | --- | --- | --- |
{package_changes_table}

### How to rebase
For current users, run the following command to rebase to this version:
```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/{args.repo.lower()}:{args.tag}
```
"""

    with open(args.output, "w") as f:
        f.write(changelog_content)

    print("Changelog generated successfully.")


if __name__ == "__main__":
    main()

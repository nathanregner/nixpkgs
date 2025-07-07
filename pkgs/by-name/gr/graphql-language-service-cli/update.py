#!/usr/bin/env nix-shell
#!nix-shell -i python3 shell.nix

import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime

import requests_cache
from attr import dataclass
from packaging.version import Version

client = requests_cache.CachedSession(backend="filesystem")
github_token = os.environ.get("GITHUB_TOKEN")
if github_token:
    client.auth = ("", github_token)


def fetch_tags():
    url = "https://api.github.com/repos/graphql/graphiql/git/refs/tags/graphql-language-service-"
    response = client.get(url)
    response.raise_for_status()
    return response.json()


def group_latest_tags(tags):
    components = {}

    for tag in tags:
        match = re.match(r"refs/tags/([^@]*)@([\d.]+)", tag["ref"])
        if not match:
            print(f"skipping invalid tag {tag['ref']}")
            continue

        name = match.group(1)
        version = Version(match.group(2))

        component = components.get(name)
        if not component or component["version"] < version:
            components[name] = {
                "version": version,
                "url": tag["object"]["url"],
            }

    return components.values()


@dataclass(frozen=True)
class Commit:
    date: datetime
    sha: str

    @staticmethod
    def fetch_latest(tags):
        latest = None

        for tag in tags:
            print(f"fetch tag {tag['url']}", file=sys.stderr)
            response = client.get(tag["url"])
            response.raise_for_status()
            data = response.json()
            commit = Commit(
                date=datetime.fromisoformat(data["tagger"]["date"]),
                sha=data["object"]["sha"],
            )
            if latest is None or latest.date < commit.date:
                latest = commit

        if latest is None:
            raise Exception("No tags provided")

        return latest

    def get_file(self, path: str):
        response = client.get(
            f"https://raw.githubusercontent.com/graphql/graphiql/{self.sha}/{path}"
        )
        response.raise_for_status()
        return response


def fetch_yarn_hashes(commit: Commit):
    print("prefetch-yarn-deps", file=sys.stderr)
    with (
        tempfile.NamedTemporaryFile() as yarn_lock,
        tempfile.NamedTemporaryFile() as missing_hashes,
    ):
        response = commit.get_file("yarn.lock")
        yarn_lock.write(response.content)

        subprocess.run(
            ["yarn-berry-fetcher", "missing-hashes", yarn_lock.name],
            stdout=missing_hashes,
            check=True,
        )

        yarn_hash = subprocess.run(
            [
                "yarn-berry-fetcher",
                "prefetch",
                yarn_lock.name,
                "missing-hashes.json",
            ],
            capture_output=True,
            text=True,
            check=True,
        )

        return (
            yarn_hash.stdout,
            missing_hashes.read().decode(),
        )


def fetch_version(commit: Commit):
    package_json = commit.get_file(
        "packages/graphql-language-service-cli/package.json"
    ).json()
    return f"{package_json['version']}-unstable-{commit.date.date().isoformat()}"


def fetch_source_hash(commit: Commit):
    res = subprocess.run(
        ["nix-prefetch-github", "graphql", "graphiql", "--rev", commit.sha],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(res.stdout)["hash"]


def main():
    tags = group_latest_tags(fetch_tags())
    commit = Commit.fetch_latest(tags)
    version = fetch_version(commit)

    prev_version = os.getenv("UPDATE_NIX_OLD_VERSION")
    if prev_version == version:
        print("No update available", file=sys.stderr)
        exit()

    print(f"fetching yarn hashes for {commit.sha}")
    yarn_hash, missing_hashes = fetch_yarn_hashes(commit)

    print(f"fetching source hash for {commit.sha}")
    src_hash = fetch_source_hash(commit)

    with open("manifest.json", "w") as f:
        manifest = {
            "version": version,
            "src": {"rev": commit.sha, "hash": src_hash},
            "yarn": {"hash": yarn_hash, "missingHashes": missing_hashes},
        }
        f.write(json.dumps(manifest, indent=True))


if __name__ == "__main__":
    main()

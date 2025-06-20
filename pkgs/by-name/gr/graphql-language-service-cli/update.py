#!/usr/bin/env nix-shell
#!nix-shell -i python -p "python3.withPackages (ps: with ps; [ ps.requests ps.requests-cache ])"

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


def fetch_yarn_hashes(tag: Commit):
    print("prefetch-yarn-deps", file=sys.stderr)
    with tempfile.NamedTemporaryFile() as tmp:
        response = tag.get_file("yarn.lock")
        tmp.write(response.content)

        with open("missing-hashes.json", "w") as f:
            subprocess.run(
                ["yarn-berry-fetcher", "missing-hashes", tmp.name],
                stdout=f,
                check=True,
            )

        with open("yarn-hash", "w") as f:
            subprocess.run(
                [
                    "yarn-berry-fetcher",
                    "prefetch",
                    tmp.name,
                    "missing-hashes.json",
                ],
                stdout=f,
                check=True,
            )


def get_version(tag: Commit):
    package_json = tag.get_file(
        "packages/graphql-language-service-cli/package.json"
    ).json()
    return f"{package_json['version']}-unstable-{tag.date.date().isoformat()}"


def main():
    tags = group_latest_tags(fetch_tags())
    commit = Commit.fetch_latest(tags)
    version = get_version(commit)

    prev_version = os.getenv("UPDATE_NIX_OLD_VERSION")
    if prev_version == version:
        print("No update available", file=sys.stderr)
        exit()

    # fetch_yarn_hashes(tag)
    print()


if __name__ == "__main__":
    main()

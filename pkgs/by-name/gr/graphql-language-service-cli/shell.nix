{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShellNoCC {
  packages = with pkgs; [
    (python3.withPackages (ps: [
      ps.packaging
      ps.requests
      ps.requests-cache
    ]))

    nix-prefetch-github
    yarn-berry_4.yarn-berry-fetcher
  ];
}

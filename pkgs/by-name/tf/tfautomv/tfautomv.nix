{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule {
  pname = "tfautomv";
  version = "v0.6.2";
  src = fetchFromGitHub {
    owner = "busser";
    repo = "tfautomv";
    rev = "v0.6.2";
    fetchSubmodules = false;
    sha256 = "sha256-qUeIbHJqxGkt2esMm4w6fM52ZE16jWnxugVXxqBh1Qc=";
  };

  vendorHash = "sha256-BZ8IhVPxZTPQXBotFBrxV3dfwvst0te8R84I/urq3gY=";

  passthru.updateScript = nix-update-script { };

  doCheck = false; # skip tests that require terraform, which is non-free

  meta = with lib; {
    description = "Generate Terraform moved blocks automatically for painless refactoring";
    homepage = "https://github.com/busser/tfautomv";
    license = licenses.asl20;
    # maintainers = with maintainers; [];
    mainProgram = "tfautomv";
  };
}

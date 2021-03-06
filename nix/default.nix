let nixpkgs = import ./nixpkgs.nix;
in
{
  pkgs ? import nixpkgs {
    overlays = import ./overlay.nix {};
  }
}:
with pkgs;

let callPackage = lib.callPackageWith haskellPackages;
    pkg = callPackage ./pkg.nix {inherit stdenv;};
    systemDeps = [ makeWrapper cacert ];
    testDeps = [ postgresql ];
in
  haskell.lib.overrideCabal pkg (drv: {
    setupHaskellDepends =
      if drv ? "setupHaskellDepends"
      then drv.setupHaskellDepends ++ systemDeps
      else systemDeps;
    testSystemDepends =
      if drv ? "testSystemDepends"
      then drv.testSystemDepends ++ testDeps
      else testDeps;
    isExecutable = true;
    enableSharedExecutables = false;
    enableLibraryProfiling = false;
    isLibrary = false;
    doHaddock = false;
    preCheck = ''
      source ./nix/export-test-envs.sh;
      sh ./nix/spawn-test-deps.sh;
    '';
    postCheck = ''
      sh ./nix/shutdown-test-deps.sh
    '';
    postFixup = ''
      rm -rf $out/lib $out/nix-support $out/share/doc
      cp -R ./static $out/static
      cp -R ./config $out/config
    '';
    postInstall = ''
      wrapProgram "$out/bin/rentier" \
        --set SYSTEM_CERTIFICATE_PATH "${cacert}/etc/ssl/certs"
    '';
  })

{ inputs }:
let
  # Ignore these from the `depends` list.
  idris2BuiltinLibs = [
    "base"
    "contrib"
    "idris2"
    "linear"
    "network"
    "prelude"
    "test"
  ];

  # These require patches for stuff like external system deps, or they depend
  # on another broken package.
  broken = [
    "array"
    "async"
    "bytestring"
    "chem"
    "cozippable"
    "crypt"
    "data-uv-data"
    "dependent-vect"
    "distribution"
    "dot-parse"
    "hedgehog"
    "hmac"
    "idrall"
    "idris2"
    "idrisGL"
    "indexed-graph"
    "lsp-lib"
    "monocle"
    "ncurses-idris"
    "pg"
    "pg-idris"
    "posix"
    "rtlsdr"
    "scram"
    "spidr"
    "sqlite3"
    "summary-stat"
    "swirl"
    "typelevel-emptiness-collections"
    "uv-data"
    "web-server-racket"
  ];

  path = "${inputs.nix-idris2-packages}/idris2-pack-db/pack-db-resolved.json";
  jsonfile = builtins.readFile path;
  jsonattrs = builtins.fromJSON jsonfile;
  nameNotBroken = n: builtins.all (m: n != m) broken;
  depsNotBroken = v: builtins.all (n: nameNotBroken n) (v.ipkgJson.depends or [ ]);
  jsonattrsWorking = lib.filterAttrs (n: v: nameNotBroken n && depsNotBroken v) jsonattrs;

  # Creates a nixpkgs-style derivation function for the given package name and
  # its attrs loaded from the pack-db-resolved.json file.
  mkPackdbPackageFn =
    name: attrs:
    {
      fetchgit,
      idris2Packages,
      stdenv,
    }:
    idris2Packages.buildIdris {
      pname = attrs.packName;
      ipkgName = attrs.ipkgName;
      version = attrs.ipkgJson.version or "0.0.0";
      src = fetchgit attrs.src;
      idrisLibraries =
        map (dep: (idris2Packages.packdb.${dep} or idris2Packages.${dep}).library { withSource = true; })
          (
            builtins.filter (n: builtins.all (m: n != m) (idris2BuiltinLibs ++ broken)) attrs.ipkgJson.depends
          );
    };

  lib = inputs.nixpkgs.lib;
  packdbPackageFns = lib.mapAttrs mkPackdbPackageFn jsonattrsWorking;
  mkPackdbPackages = pkgs: lib.mapAttrs (_: f: pkgs.callPackage f { }) packdbPackageFns;
in
final: prev: {
  idris2Packages = (
    prev.idris2Packages
    // {
      packdb = mkPackdbPackages final;
      all = final.symlinkJoin {
        name = "allIdris2Packages";
        paths = map (p: p.library { withSource = true; }) (lib.attrValues final.idris2Packages.packdb);
      };
    }
  );
}

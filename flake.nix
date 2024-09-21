{
  description = ''
    All idris2 pack-db packages, exposed via overlay and package outputs.

    All pack-db packages are exposed in the overlay via `pkgs.idris2Packages.packdb.*`.

    Includes src for all libraries by default.

    This uses `pack-db-resolved.json` from the `nix-idris2-packages`, but only
    includes packages working with the nixpkgs idris2.
  '';

  inputs = {
    # Include as non-flake, as we only use the JSON file.
    nix-idris2-packages = {
      url = "github:mattpolzin/nix-idris2-packages";
      flake = false;
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    let
      overlays = [ inputs.self.overlays.default ];
      perSystemPkgs =
        f:
        inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed (
          system: f (import inputs.nixpkgs { inherit overlays system; })
        );
    in
    {
      overlays = {
        idris2pkgs = import ./overlay.nix { inherit inputs; };
        default = inputs.self.overlays.idris2pkgs;
      };

      packages = perSystemPkgs (
        pkgs:
        {
          all = pkgs.idris2Packages.all;
        }
        // (inputs.nixpkgs.lib.mapAttrs (n: v: v.library { withSource = true; }) pkgs.idris2Packages.packdb)
      );

      formatter = perSystemPkgs (pkgs: pkgs.nixfmt-rfc-style);
    };
}

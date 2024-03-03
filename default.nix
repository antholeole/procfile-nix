let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  nixpkgs' = fetchTarball {
    url = lock.nodes.nixpkgs.locked.url or "https://github.com/NixOS/nixpkgs/archive/${lock.nodes.nixpkgs.locked.rev}.tar.gz";
    sha256 = lock.nodes.nixpkgs.locked.narHash;
  };
in
  {
    nixpkgs ?
      import nixpkgs' {
        config = {};
        overlays = [];
        inherit system;
      },
    system ? builtins.currentSystem,
  }: let
    pkgs = nixpkgs;
    inherit (nixpkgs) lib;

    toProcfile = procGroup:
      lib.concatLines (
        lib.mapAttrsToList (name: cmd: "${name}: ${cmd}") procGroup
      );

    mkRunCommand = procRunner: procfile: let
      procRunnerName = (builtins.parseDrvName procRunner).name;
      procRunners = {
        overmind = ''
          set -x
          overmind start -f ${procfile} --root "$PWD" "$@"
        '';

        prox = ''
          echo blah blah
        '';

        default = "${lib.getExe procRunner} ${procfile}";
      };
    in builtins.trace procfile procfile;
      # procRunners."${procRunnerName}" or procRunners.default;

  in {
    mkProcfileRunner = {
      name,
      procGroup,
      procRunner,
    }: let
      procFile = (pkgs.writeText name (toProcfile procGroup));
    in
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [procRunner];
        text = mkRunCommand procRunner procFile;
      };
  }

{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
    buildInputs = [
      pkgs.neovim
      pkgs.stylua
      pkgs.git
      pkgs.pkg-config
      pkgs.luajit
      pkgs.luajitPackages.busted
      pkgs.luajitPackages.tl
    ];
}

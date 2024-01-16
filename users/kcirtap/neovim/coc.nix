#https://github.com/neoclide/coc.nvim
{ pkgs, ... }:
{
  programs.neovim = {
    coc = {
      enable = true;
    };

    extraPackages = [
      pkgs.nodejs # coc requires nodejs
    ];
  };
}
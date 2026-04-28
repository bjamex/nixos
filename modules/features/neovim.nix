{ self, inputs, ... }: {

  flake.nixosModules.neovim = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      neovim
      gcc         
      tree-sitter 
      ripgrep    
      fd          
      nodejs    
      unzip     
      trash-cli 
    ];
  };
}

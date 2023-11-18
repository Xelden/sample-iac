{
  description = "Integración Terraform-Ansible para curso IpTI";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        # IAC
        ansible
        ansible-language-server
        ansible-lint
        terraform
        terraform-providers.azurerm
        terraform-ls
        azure-cli
        yaml-language-server

        # ToDo App
        nodejs_20
      ];
    };
  };
}

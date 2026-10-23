# Distrust CA roots whose intermediates have leaked keys. Shared by all three
# hosts (common.nix + hades).
#
# 2026-10 eMudhra incident (https://emudhra.we-have-a-problem.com/): eight
# eMudhra intermediate CAs had keys generated so badly that the private key
# can be recovered from the certificate itself — anyone can mint a trusted
# cert for any site. They chain to these two roots; this drops both from the
# system bundle (/etc/ssl/certs), the advisory's own NixOS workaround.
#
# Remove once nixpkgs' cacert is >= 3.131.1 (merged to master 2026-10-20 as
# "cacert: 3.126 -> 3.131.1") — check with
# `nix eval --raw .#nixosConfigurations.styx.pkgs.cacert.version`.
# Browsers and Electron apps carry their own root stores and aren't covered.
{
  flake.nixosModules.caDistrust = {
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
      "emSign ECC Root CA - G3"
    ];
  };
}

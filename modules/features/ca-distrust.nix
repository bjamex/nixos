# Distrust CA roots whose intermediates have leaked keys. Shared by all three
# hosts (common.nix + hades).
#
# 2026-10 eMudhra incident (https://emudhra.we-have-a-problem.com/): eight
# eMudhra intermediate CAs had keys generated so badly that the private key
# can be recovered from the certificate itself — anyone can mint a trusted
# cert for any site. They chain to these two roots; this drops both from the
# system bundle (/etc/ssl/certs), the advisory's own NixOS workaround.
#
# cacert 3.131.1 (nixpkgs 2026-10-27) dropped "emSign ECC Root CA - G3" itself,
# so it's gone from this list — the cacert builder fails on a blocklist entry
# that isn't in the store. It still ships "Comodo AAA Services root", so that
# block stays; remove this module once
#   grep '^Comodo AAA' $(nix build --no-link --print-out-paths \
#     .#nixosConfigurations.styx.pkgs.cacert)/etc/ssl/certs/ca-bundle.crt
# comes back empty. Browsers and Electron apps carry their own root stores and
# aren't covered.
{
  flake.nixosModules.caDistrust = {
    security.pki.caCertificateBlacklist = [ "Comodo AAA Services root" ];
  };
}

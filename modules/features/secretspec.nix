{ self, inputs, ... }:
{
  # Reusable SecretSpec wiring for services (primarily oci-containers).
  #
  # SecretSpec (https://secretspec.dev) keeps the *declaration* of required
  # secrets in the repo (`secretspec.toml`, non-secret: names + descriptions)
  # while the *values* live in a provider backend, never committed. This module
  # turns that into per-service systemd glue: a privileged ExecStartPre resolves
  # the secrets a unit needs into a root-only env file, which the unit then
  # loads via `environmentFiles` (podman `--env-file`).
  #
  # See docs/hades-roadmap.md (Phases 3-4) for the migration workflow.
  flake.nixosModules.secretspec =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.secretspec;
      # /etc copy so the headless box can run `secretspec set`/`check` and the
      # automation can find the spec without a flake checkout present.
      specFile = "/etc/secretspec.toml";
      isDotenv = lib.hasPrefix "dotenv:" cfg.provider;
      dotenvPath = lib.removePrefix "dotenv:" cfg.provider;
    in
    {
      options.services.secretspec = {
        provider = lib.mkOption {
          type = lib.types.str;
          default = "dotenv:/var/lib/secretspec/secrets.env";
          example = "gcsm://my-project";
          description = ''
            SecretSpec provider used to resolve secret values at runtime.

            Defaults to a root-only dotenv file placed on the host out-of-band
            (never committed). The `keyring` provider is deliberately NOT the
            default: on Linux it uses the D-Bus Secret Service, which needs an
            unlocked keyring / graphical session and is impractical for a
            headless systemd service running as root. Override per-host for a
            managed backend (e.g. `gcsm://<project>` for Google Cloud Secret
            Manager, `vault://…`, `onepassword://…`).
          '';
        };

        providerEnvironment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            GOOGLE_APPLICATION_CREDENTIALS = "/var/lib/secretspec/gcp-sa.json";
          };
          description = ''
            Extra environment variables exported before `secretspec` runs, for
            provider auth. Values are non-secret (paths, endpoints) — the actual
            credential (e.g. the GCP service-account key file) lives at the
            referenced path on the host, out-of-band and never committed.
          '';
        };

        secrets = lib.mkOption {
          default = { };
          description = ''
            Map of systemd unit name (e.g. "podman-adguard") -> secret wiring.
            Each entry adds a privileged ExecStartPre that resolves the declared
            secrets whose env names start with `prefix` into the root-only file
            at `.envFile`; point the unit's `environmentFiles` at that path.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  prefix = lib.mkOption {
                    type = lib.types.str;
                    example = "ADGUARD_";
                    description = "Only secrets whose env name starts with this prefix are written to the env file.";
                  };
                  envFile = lib.mkOption {
                    type = lib.types.str;
                    readOnly = true;
                    default = "/run/secretspec/${name}.env";
                    description = "Resolved env-file path; set the unit's `environmentFiles` to this.";
                  };
                };
              }
            )
          );
        };
      };

      config = lib.mkIf (cfg.secrets != { }) {
        # CLI on the box for `secretspec set` / `check` / `audit`.
        environment.systemPackages = [ pkgs.secretspec ];
        environment.etc."secretspec.toml".source = ../../secretspec.toml;

        # Root-only state dir for provider bootstrap material (the dotenv values
        # file, or the GCP service-account key, etc.). Always created; for a
        # dotenv provider pointed elsewhere, also create that directory.
        systemd.tmpfiles.rules = lib.unique (
          [ "d /var/lib/secretspec 0700 root root - -" ]
          ++ lib.optional isDotenv "d ${builtins.dirOf dotenvPath} 0700 root root - -"
        );

        systemd.services = lib.mapAttrs (
          unit: opts:
          let
            resolve = pkgs.writeShellScript "secretspec-${unit}" ''
              set -euo pipefail
              umask 077
              mkdir -p /run/secretspec
              export SECRETSPEC_FILE=${specFile}
              export SECRETSPEC_REASON="systemd unit ${unit}"
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg v}") cfg.providerEnvironment
              )}
              ${pkgs.secretspec}/bin/secretspec run --provider ${lib.escapeShellArg cfg.provider} -- \
                ${pkgs.coreutils}/bin/printenv \
                | ${pkgs.gnugrep}/bin/grep -E ${lib.escapeShellArg "^${opts.prefix}[A-Za-z0-9_]*="} \
                > ${opts.envFile}
            '';
          in
          {
            # "+" runs the resolver as root regardless of the unit's User=, so it
            # can read the provider and write into /run/secretspec.
            serviceConfig.ExecStartPre = [ "+${resolve}" ];
          }
        ) cfg.secrets;
      };
    };
}

# TODO

- Merge changes stored in the `refactor-scan-dependencies` branch
- Rename `docs/guides` to `docs/user-guides`
- Remove leading `.` from all the file names in the `scripts/config` directory
- Add the `scripts/config/.repository-template.yaml` config file
- List all the features in the `README.md` file
- Improve the main diagram
- Add a note on packages for [consistent GNU/Linux-like CLI experience on macOS](https://github.com/nhs-england-tools/dotfiles/blob/f0d6fbe913e5b35bcd3feb13fe3a61da12c61f5d/assets/20-install-base-packages.macos.sh#L29)
- Docker scripts
  - Image spec test, e.g. [dgoss](https://github.com/goss-org/goss/tree/master/extras/dgoss)
  - Create an Alpine image repository with GNU utils
  - Generate SBOM and scan for CVEs
  - Documentation
  - Integrate this work with the "Update from Template" app
    - Add Docker test suite and example to the ignore list of the repository

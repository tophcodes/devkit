# Agents

- Run `just` to list the recipes. `just test` runs the tests, `just fmt`
  formats.
- Run `just check` before calling a change done. It runs everything CI runs:
  formatting, linters, prose-check and the tests.
- Layout: a standalone tool lives in `tools/<name>/` with its flake-parts
  module in `tools/<name>/default.nix`. Every `.nix` file under `nix/` and
  `tools/` is a flake-parts module.
- Changes are specified with OpenSpec: `openspec/specs/` holds the binding
  specification, `/openspec-propose` starts a change against it.

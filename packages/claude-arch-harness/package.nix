{
  mkClaudePlugin,
  jq,
  arch-check,
}:
mkClaudePlugin {
  name = "arch-harness";
  version = "0.1.0";
  description = "Holds architecture decisions to their checks: runs docs/constraints.md on Stop and reports drift at SessionStart.";
  runtimeInputs = [jq arch-check];
  skills = ./skills;
  hooks = {
    Stop = [{hooks = [{script = ./hooks/arch-stop.sh;}];}];
    SessionStart = [{hooks = [{script = ./hooks/arch-status.sh;}];}];
    PostToolUse = [
      {
        matcher = "Write|Edit";
        hooks = [{script = ./hooks/arch-plan-written.sh;}];
      }
    ];
  };
}

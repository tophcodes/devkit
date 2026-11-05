{
  mkClaudePlugin,
  jq,
  prose-check,
}:
mkClaudePlugin {
  name = "prose-guard";
  version = "0.1.0";
  description = "Checks written prose against the anti-slop rules: flags a file after it is written, refuses an issue, PR or commit message before it goes out.";
  runtimeInputs = [jq prose-check];
  hooks = {
    PostToolUse = [
      {
        matcher = "Write|Edit";
        hooks = [{script = ./hooks/prose-written.sh;}];
      }
    ];
    PreToolUse = [
      {
        matcher = "Bash";
        hooks = [{script = ./hooks/prose-outbound.sh;}];
      }
    ];
  };
}

{
  mkClaudePlugin,
  jq,
}:
mkClaudePlugin {
  name = "jj-guard";
  version = "0.1.0";
  description = "In colocated jj repos, keeps the agent's git read-only and answers with the jj equivalent.";
  runtimeInputs = [jq];
  hooks.PreToolUse = [
    {
      matcher = "Bash";
      hooks = [
        {
          "if" = "Bash(git *)";
          script = ./hooks/git-readonly.sh;
        }
      ];
    }
  ];
}

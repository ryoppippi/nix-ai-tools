{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  npmDepsFetcherVersion = 2;
  pname = "claude-agent-acp";
  version = "0.55.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    tag = "v${version}";
    hash = "sha256-HVhXJJshq41qMqyaxWkNi//TeZUp+PZwKnppJ1lYaIw=";
  };

  npmDepsHash = "sha256-Isn8Z19QHc7Z350HyGj1aXe3nZbFtFWf7BrCU5MpeqM=";
  makeCacheWritable = true;

  # Disable install scripts to avoid platform-specific dependency fetching issues
  npmFlags = [ "--ignore-scripts" ];

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "An ACP-compatible coding agent powered by the Claude Code SDK (TypeScript)";
    homepage = "https://github.com/agentclientprotocol/claude-agent-acp";
    changelog = "https://github.com/agentclientprotocol/claude-agent-acp/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "claude-agent-acp";
    platforms = platforms.all;
  };
}

{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  npmDepsFetcherVersion = 2;
  pname = "claude-agent-acp";
  version = "0.52.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-w8lrc/4cW7QZNDMvq663eas7Dl4tnya4JCM9xkLF8S8=";
  };

  npmDepsHash = "sha256-u7bz28+19RGImS0GGXHv7G47jkr6e5PNk3m5lAl/5oE=";
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

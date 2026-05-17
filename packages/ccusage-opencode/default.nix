{
  pkgs,
  perSystem,
  ...
}:
pkgs.lib.warnOnInstantiate "'ccusage-opencode' has been consolidated into 'ccusage'. Please update your references." perSystem.self.ccusage
// {
  passthru.hideFromDocs = true;
}

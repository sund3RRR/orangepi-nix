{ fetchFromGitHub
, linuxManualConfig
, ubootTools
, ...
}:
(linuxManualConfig {
  version = "5.10.160-rockchip-rk3588";
  modDirVersion = "5.10.160";

  src = fetchFromGitHub {
    owner = "armbian";
    repo = "linux-rockchip";
    rev = "c2e9a95ab59937a5f0aad0ac6e12fe81f26ea2e0";
    hash = "";
  }

  configfile = ./orangepi5_config;

  extraMeta.branch = "5.10";

  allowImportFromDerivation = true;
}).overrideAttrs (old: {
  name = "k"; # dodge uboot length limits
  nativeBuildInputs = old.nativeBuildInputs ++ [ ubootTools ];
})

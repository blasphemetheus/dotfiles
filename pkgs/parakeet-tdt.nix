# Parakeet TDT 0.6b v3 (ONNX) — the speech model hyprwhspr-rs dictation runs
# ("provider": "parakeet" in hyprwhspr/.config/hyprwhspr-rs/config.jsonc).
# Same files upstream's scripts/download-parakeet-tdt.sh fetches, pinned to
# one HuggingFace revision so every machine gets the identical model with no
# manual download step. modules/home/dotfiles.nix links this directory to
# ~/.local/share/hyprwhspr-rs/models/parakeet/parakeet-tdt-0.6b-v3-onnx.
#
# int8 = true: the repo's pre-quantized encoder/decoder (~670 MB instead of
# ~2.5 GB, faster on a laptop CPU, slightly lower accuracy). They're stored
# under the fp32 names because hyprwhspr-rs's startup check only accepts
# encoder-model.onnx / decoder_joint-model.onnx (parakeet-rs itself would
# also take the .int8 names). The int8 encoder embeds its weights, so it has
# no .onnx.data file.
#
# Hashes: the LFS oids from the HF tree API (vocab.txt isn't LFS; prefetched).
# Files are copied, not symlinked: the fp32 encoder finds its external
# weights (.onnx.data) relative to its own path, so both must sit in one real
# directory. The fetchurl outputs are build-time only; GC reclaims them.
{ fetchurl, runCommand, int8 ? false }:
let
  rev = "8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce";
  # file <name in the model dir> <name upstream> <sha256>
  file = name: upstream: sha256: {
    inherit name;
    src = fetchurl {
      inherit sha256;
      name = upstream;
      url = "https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/${rev}/${upstream}";
    };
  };
  vocab = file "vocab.txt" "vocab.txt" "0pf3wcvps76wq7iadw37lk7xcjs7gpmlbxficg2nmg54krkl91fm";
  files =
    if int8 then [
      (file "encoder-model.onnx" "encoder-model.int8.onnx" "6139d2fa7e1b086097b277c7149725edbab89cc7c7ae64b23c741be4055aff09")
      (file "decoder_joint-model.onnx" "decoder_joint-model.int8.onnx" "eea7483ee3d1a30375daedc8ed83e3960c91b098812127a0d99d1c8977667a70")
      vocab
    ] else [
      (file "encoder-model.onnx" "encoder-model.onnx" "98a74b21b4cc0017c1e7030319a4a96f4a9506e50f0708f3a516d02a77c96bb1")
      (file "encoder-model.onnx.data" "encoder-model.onnx.data" "9a22d372c51455c34f13405da2520baefb7125bd16981397561423ed32d24f36")
      (file "decoder_joint-model.onnx" "decoder_joint-model.onnx" "e978ddf6688527182c10fde2eb4b83068421648985ef23f7a86be732be8706c1")
      vocab
    ];
in
runCommand "parakeet-tdt-0.6b-v3-onnx${if int8 then "-int8" else ""}" { } ''
  mkdir $out
  ${builtins.concatStringsSep "\n  " (map (f: "cp ${f.src} $out/${f.name}") files)}
''

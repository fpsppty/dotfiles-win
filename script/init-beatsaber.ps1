$src = "~/AppData/locallow/hyperbolic magnetism/beat saber"
if (Test-Path $src) {
  Remove-Item -Recurse -Force -Confirm:$true $src
}

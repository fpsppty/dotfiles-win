$env.config.show_banner = false

let vendor = ($nu.data-dir | path join "vendor/autoload")
mkdir $vendor

# https://carapace-sh.github.io/carapace-bin/setup.html
if (which carapace | is-not-empty) {
    carapace _carapace nushell | save --force ($vendor | path join "carapace.nu")
}
# https://mise.jdx.dev/installing-mise.html#nushell
if (which mise | is-not-empty) {
    mise activate nu | save --force ($vendor | path join "mise.nu")
}
# https://starship.rs
if (which starship | is-not-empty) {
    starship init nu | save --force ($vendor | path join "starship.nu")
}
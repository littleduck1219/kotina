# Third-Party Notices

## Kiwi 0.23.2

Kotina uses the Kiwi Korean morphological analyzer by Min-Hyeong Park.

- Source: https://github.com/bab2min/Kiwi
- Runtime asset: `kiwi_mac_arm64_v0.23.2.tgz`
- Model asset: `kiwi_model_v0.23.2_base.tgz`
- License: GNU Lesser General Public License, version 3.0

Kotina embeds Kiwi as a replaceable dynamic library in the application bundle. The
downloaded runtime, headers, and model are not committed to this repository; use
`scripts/fetch-kiwi.sh` to obtain the pinned official assets and verify their
SHA-256 checksums before use. Kiwi's complete license and corresponding source are
available from the upstream repository and release linked above.

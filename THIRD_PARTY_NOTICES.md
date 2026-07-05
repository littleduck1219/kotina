# Third-Party Notices

## Kiwi 0.23.2

Kotina uses the Kiwi Korean morphological analyzer and its base Korean model by
Min-Hyeong Park.

- Source: https://github.com/bab2min/Kiwi
- Runtime asset: `kiwi_mac_arm64_v0.23.2.tgz`
- Model asset: `kiwi_model_v0.23.2_base.tgz`
- License: GNU Lesser General Public License, version 3.0
- License text: https://www.gnu.org/licenses/lgpl-3.0.html
- Corresponding source: https://github.com/bab2min/Kiwi/tree/v0.23.2

Kotina embeds Kiwi as a replaceable dynamic library in the application bundle. The
downloaded runtime, headers, and model are not committed to this repository; use
`scripts/fetch-kiwi.sh` to obtain the pinned official assets and verify their
SHA-256 checksums before use. Kiwi's complete license and corresponding source are
available from the upstream repository and release linked above.

The release archive keeps `libkiwi.0.dylib` as a separate file under
`Kotina.app/Contents/Frameworks`. An interface-compatible replacement can be put
at that path without modifying the Kotina executable. The base model is copied
unchanged from the checksum-verified upstream model archive.

# Before/After Comparison — `react-rust-postgres` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-rust-postgres:original`) | Slim (`dip-react-rust-postgres:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 85.39MB | 9.88MB | **-88.4%** |
| SBOM components (Syft) | 88 | 0 | -88 |
| Vulnerabilities (Grype) | 211 | 0 | -211 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## The only example where the SBOM legitimately goes to zero

Every other image in this project keeps some components after minimization. Here Syft
reports **nothing at all**, and for once that is not the scanner-blindness caveat: the
final image is a single statically-laid-out actix-web release binary on `debian-slim`,
and Slim removed the entire Debian userland around it — including `/var/lib/dpkg`, which
is the only thing Syft had to read. There are no Rust crate manifests in a compiled
binary to fall back on. The 177 vulnerabilities were all Debian package CVEs; the ones
attributable to the crates linked into the binary were never visible in either scan.

So the honest reading is that the *measured* surface went to zero because the OS
distribution went away, not that the code is provably CVE-free. What did genuinely
happen is that 26.7 MB of shell, package manager and libc userland stopped shipping.

## The result depended on repairing the build first

This example spent most of the project in the excluded set. The vendored Dockerfile
pins `rust:buster`, a tag frozen at Rust 1.79 because Debian buster is EOL, while the
project ships no `Cargo.lock` — so `cargo fetch` resolves `tokio-postgres` to 0.7.18,
whose manifest requires `edition2024` and Rust ≥ 1.85. Unpinned dependencies against a
pinned-by-abandonment compiler. `examples/react-rust-postgres/Dockerfile.patched` moves
the build to `rust:1.90-slim-bookworm` / `debian:bookworm-slim`; no source change was
needed. See `docs/methodology.md` §6.

## Functional validation

- `GET /users` returns 200 with a JSON array. Any failure in the deadpool checkout, the
  connection, or the prepared `SELECT` returns 500, so a 200 already proves all three.
  It also proves the startup migration ran — the `users` table exists only because
  `migrate_up()` executed SQL embedded via `include_str!`.
- A row is then seeded directly in postgres and re-queried, because the empty-list
  response never exercises `impl From<Row> for User` or serde's serialization of it.
  Both paths pass on the minimized image.

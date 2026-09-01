# Sub-analysis: baseline measured against the Dockerfile's final stage

These artifacts measure **a different baseline** from the ones in the parent directory,
and are kept deliberately rather than discarded.

The vendor compose file for this example pins `target: builder`, so what the example
ships — and what `pipeline/run-pipeline.sh` therefore builds and measures — is the
builder stage. The artifacts here predate the pipeline's migration to compose-driven
builds (commit 499af57) and instead measure the Dockerfile's **final** `FROM scratch`
stage, which the example defines but never builds.

That makes them the measurement behind `docs/methodology.md` §7: a static Go binary on
`scratch` gives Slim nothing to remove, and Slim's own metadata makes the image
marginally larger. The parent directory holds the shipped-stage measurement instead.

Read the two together and the example yields three figures, which is the point:

| Image | Size |
|---|---|
| What compose ships (builder stage) | see `../comparison.json` |
| Retargeting the build to the final stage — a one-line compose change, no Slim | see `comparison.json` here |
| Slim applied on top of that final stage | see `comparison.json` here |

The first-to-second step is the "free" minimization noted in `docs/methodology.md` §1;
the second-to-third step is what Slim adds, which for this shape is negative.

# Academic website

A [Quarto](https://quarto.org) website (litera theme), managed as an RStudio project.
Open `academic-website.Rproj` in RStudio to work on it.

## Filling in content

Every spot that needs real content is marked with `PLACEHOLDER`. To find them all:

```bash
grep -rn PLACEHOLDER . --exclude-dir=_site --exclude-dir=.quarto
```

Also replace `images/profile.jpg` with a real photo (keep the filename, or update the
path in `index.qmd`).

## Structure

| Path | Purpose |
|---|---|
| `index.qmd` | Bio, contact links, "Statistical Projects I Love" |
| `research/` | Data, past projects & theses, future research ideas |
| `publications.qmd` | Hand-maintained publications table |
| `talks/` | Teaching (TA), seminars, conferences |
| `cv.qmd` | CV rendered from the CSVs in `cv_data/` |
| `cv_data/` | `positions.csv`, `education.csv`, `talks.csv` |
| `noice/` | Blog listing + posts under `noice/posts/` |

## Preview locally

```bash
quarto preview
```

If `quarto` isn't on your PATH, the RStudio-bundled copy works:
`/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto`

## Publishing

Deployed to [Quarto Pub](https://quartopub.com). Future updates are just:
edit the `.qmd` / `.csv` files, then

```bash
quarto publish quartopub
```

The first run prompts for Quarto Pub account authorization in the browser and writes
`_publish.yml`, which records the site's URL — keep that file committed so later
publishes update the same site rather than creating a new one.

## Requirements

The CV page renders through R, so it needs R plus the `readr` and `gt` packages
(`install.packages(c("readr", "gt"))`). Without `gt` it falls back to `knitr::kable`.

## Notes

- New blog post: create `noice/posts/<slug>/index.qmd` with `title`, `date`, and
  `author` in the YAML front matter — the listing picks it up automatically.
- The publications page is a plain markdown table. If you'd rather have auto-formatted
  citations later, it can be switched to a `references.bib` file plus Quarto's
  [citation rendering](https://quarto.org/docs/authoring/citations.html).

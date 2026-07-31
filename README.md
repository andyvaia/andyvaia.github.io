# Academic website

A [Quarto](https://quarto.org) website, managed as an RStudio project.
Open `academic-website.Rproj` in RStudio to work on it.

## Look & feel

The theme is a custom Sass file, `editorial.scss`: Playfair Display serif headings over a
Source Sans 3 body, deep burgundy (`#7b2d26`) accent, white navbar with an accent rule
beneath it. Both fonts load from Google Fonts. To change the accent colour or the
typefaces, edit the variables in the `scss:defaults` block at the top of that file.

Talks, teaching and past projects use `.entry` blocks (styled in `styles.css`) rather than
tables — a bold title line followed by a muted detail line. To add an entry, copy an
existing `::: {.entry} ... :::` block.

## Filling in content

Content spots are marked `PLACEHOLDER`; personal details are marked `[YOUR NAME]`,
`[YOUR EMAIL]`, `[YOUR HANDLE]`. To find all of them:

```bash
grep -rnE "PLACEHOLDER|\[YOUR " --include="*.qmd" --include="*.csv" --include="*.yml" .
```

Don't miss `_quarto.yml` — the site title and the two navbar icons (email, GitHub) have
`[YOUR ...]` slots there, and they won't turn up in a search for `PLACEHOLDER` alone.

Also replace `images/profile.jpg` with a real photo (keep the filename, or update the
path in `index.qmd`).

## Structure

| Path | Purpose |
|---|---|
| `index.qmd` | Bio, contact links, "Statistical Projects I Love" |
| `research.qmd` | Single page: Data, Past Projects & Theses, Future Research Ideas |
| `publications.qmd` | Generated from `cv_source/bibliocv.bib`, see below |
| `talks/` | Teaching (TA), seminars, conferences |
| `cv.qmd` | CV page — generated from the LaTeX CV, see below |
| `cv_source/` | The LaTeX CV (`.tex` + `bibliocv.bib`) and `build-pdf.sh` |
| `R/` | `parse_europasscv.R` and `parse_bib.R`, the two parsers |
| `noice/` | Blog — currently on hold, see below |

Nothing on this site is maintained in two places: the CV and the publication list are
both generated from the files in `cv_source/`, which are the same files that build the
PDF CV.

## The CV

`cv_source/CV_Andrea_Vaiano_no_dati.tex` is the single source of truth. The CV page reads
it at render time and lays out every section it finds, so updating the CV means editing
the `.tex` and re-rendering — nothing on the website needs touching.

`R/parse_europasscv.R` reads four macros and ignores everything else:

| Macro | Becomes |
|---|---|
| `\ecvsection{Name}` | a section heading |
| `\ecvtitle{Dates}{Title}` | an entry |
| `\ecvtitlelevel{Dates}{Title}{Level}` | an entry, level in parentheses |
| `\ecvitem{}{Text}` | a detail line under the current entry |

Anything commented out with `%` is skipped, so entries you've hidden in the PDF stay off
the website too. `\textit`, `\textbf`, `` ``quotes" `` and `--` dashes are converted.

If you start using a macro the parser doesn't know, its content simply won't appear —
check the page after adding one. A section whose entries all use unknown macros is
dropped entirely (this is what happens to Personal skills, which uses the language
macros).

To rebuild the downloadable PDF from the same source:

```bash
./cv_source/build-pdf.sh
```

That runs pdflatex → biber → pdflatex twice and copies the result to `cv.pdf` at the
project root, which is what the page's "Download PDF" button links to. LaTeX build
artefacts in `cv_source/` are gitignored; `cv.pdf` is committed so the published site
always has one.

### Hiding a CV section from the website

Some sections are better served by their own page. `cv.qmd` has a `skip_sections` vector
near the top:

```r
skip_sections <- c("Conferences and Seminars")
```

Names must match the `\ecvsection{...}` text exactly. Remove a name to bring the section
back; add one to hide it. The `.tex` is untouched either way, so the PDF still has
everything.

## Publications

`publications.qmd` is generated from `cv_source/bibliocv.bib` — the same file the LaTeX
CV cites. Add a BibTeX entry there and it appears on both the PDF and the website.

`R/parse_bib.R` groups entries by year, newest first, formats authors as initials plus
surname with `Vaiano` in bold, and links the `doi` field when present. It understands
`@article` (journal, volume, number, pages) and `@techreport` (series, number); anything
else falls back to `booktitle` / `publisher` / `institution`.

## The blog

`noice/` is on hold. The files are still in the repo but the site does not build or
publish them, via this line in `_quarto.yml`:

```yaml
project:
  render:
    - "**/*.qmd"
    - "!noice/**"
```

To bring the blog back: delete the `"!noice/**"` line and uncomment the two `noice`
lines in the navbar further down the same file. Nothing else is needed — the listing
page and the starter post are untouched.

## Preview locally

```bash
quarto preview
```

If `quarto` isn't on your PATH, the RStudio-bundled copy works:
`/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto`

## Publishing

Deployed to [Quarto Pub](https://quartopub.com). Future updates are just:
edit the `.qmd` / `.tex` files, then

```bash
quarto publish quartopub
```

The first run prompts for Quarto Pub account authorization in the browser and writes
`_publish.yml`, which records the site's URL — keep that file committed so later
publishes update the same site rather than creating a new one.

## Requirements

The CV page runs an R chunk to parse the `.tex`, so rendering the site needs R — but only
base R, no packages. Rebuilding `cv.pdf` additionally needs a LaTeX distribution with the
`europasscv` class and `biber` (both present in TeX Live 2024).

## Notes

- New blog post (once the blog is re-enabled): create `noice/posts/<slug>/index.qmd` with
  `title`, `date`, and `author` in the YAML front matter — the listing picks it up
  automatically.
- Both parsers in `R/` are base R only, so rendering the site never requires installing
  a package. If you'd rather hand-format citations one day, replace the code chunk in
  `publications.qmd` with a plain markdown list — nothing else depends on it.

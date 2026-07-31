# Parse a BibTeX file into the publication list shown on the website.
#
# cv_source/bibliocv.bib is the single source of truth: it feeds both the LaTeX CV's
# bibliography and the Publications page. Add a paper there and both follow.
#
# Deliberately dependency-free (base R only), like R/parse_europasscv.R, so rendering
# the site never needs a package install.

# Split "a = {b}, c = {d}" on commas that sit at brace depth zero.
split_top_level <- function(x, sep = ",") {
  chars <- strsplit(x, "", fixed = TRUE)[[1]]
  depth <- 0L
  out <- character(0)
  buf <- character(0)
  for (i in seq_along(chars)) {
    ch <- chars[i]
    if (ch == "{") depth <- depth + 1L
    if (ch == "}") depth <- depth - 1L
    if (ch == sep && depth == 0L) {
      out <- c(out, paste(buf, collapse = ""))
      buf <- character(0)
    } else {
      buf <- c(buf, ch)
    }
  }
  c(out, paste(buf, collapse = ""))
}

# Strip one layer of wrapping braces or quotes, plus LaTeX escapes we care about.
clean_field <- function(x) {
  x <- trimws(x)
  x <- sub('^\\{(.*)\\}$', "\\1", x)
  x <- sub('^"(.*)"$', "\\1", x)
  x <- gsub("\\\\_", "_", x)
  x <- gsub("\\\\&", "&", x)
  x <- gsub("\\\\%", "%", x)
  x <- gsub("[{}]", "", x)
  x <- gsub("[[:space:]\n]+", " ", x)
  trimws(x)
}

parse_bib <- function(path) {
  if (!file.exists(path)) {
    stop("Bibliography not found: ", path)
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  # Drop whole-line comments (% at start of a line).
  text <- gsub("(?m)^%.*$", "", text, perl = TRUE)

  chars <- strsplit(text, "", fixed = TRUE)[[1]]
  entries <- list()
  i <- 1L
  n <- length(chars)

  while (i <= n) {
    if (chars[i] != "@") { i <- i + 1L; next }
    # Read the entry type up to the opening brace.
    j <- i + 1L
    while (j <= n && chars[j] != "{") j <- j + 1L
    if (j > n) break
    type <- tolower(trimws(paste(chars[(i + 1):(j - 1)], collapse = "")))

    # Find the matching close brace for the whole entry.
    depth <- 0L
    k <- j
    while (k <= n) {
      if (chars[k] == "{") depth <- depth + 1L
      if (chars[k] == "}") {
        depth <- depth - 1L
        if (depth == 0L) break
      }
      k <- k + 1L
    }
    body <- paste(chars[(j + 1):(k - 1)], collapse = "")

    parts <- split_top_level(body)
    # Stored as `bibtype`, not `type`: BibTeX entries may carry their own `type` field
    # (techreport uses it for "Working Paper"), which would otherwise clobber this.
    fields <- list(bibtype = type)
    # parts[1] is the citation key (which may itself contain a URL); skip it.
    for (p in parts[-1]) {
      eq <- regexpr("=", p, fixed = TRUE)
      if (eq < 0) next
      key <- tolower(trimws(substr(p, 1, eq - 1)))
      val <- clean_field(substr(p, eq + 1, nchar(p)))
      if (nzchar(key)) fields[[key]] <- val
    }
    entries[[length(entries) + 1L]] <- fields
    i <- k + 1L
  }
  entries
}

# "Longo, Umile Giuseppe and Vaiano, Andrea" -> "U. G. Longo, **A. Vaiano**"
# `highlight` is a surname rendered in bold (your own papers stand out).
format_authors <- function(author_field, highlight = NULL) {
  if (is.null(author_field) || !nzchar(author_field)) return("")
  people <- trimws(strsplit(author_field, " and ", fixed = TRUE)[[1]])
  formatted <- vapply(people, function(p) {
    if (grepl(",", p, fixed = TRUE)) {
      bits <- trimws(strsplit(p, ",", fixed = TRUE)[[1]])
      surname <- bits[1]
      given <- if (length(bits) > 1) bits[2] else ""
    } else {
      bits <- trimws(strsplit(p, "[[:space:]]+")[[1]])
      surname <- bits[length(bits)]
      given <- paste(bits[-length(bits)], collapse = " ")
    }
    initials <- ""
    if (nzchar(given)) {
      gs <- trimws(strsplit(given, "[[:space:]]+")[[1]])
      gs <- gs[nzchar(gs)]
      initials <- paste0(paste0(substr(gs, 1, 1), "."), collapse = " ")
    }
    name <- trimws(paste(initials, surname))
    if (!is.null(highlight) && identical(tolower(surname), tolower(highlight))) {
      name <- paste0("**", name, "**")
    }
    name
  }, character(1), USE.NAMES = FALSE)

  if (length(formatted) == 1) return(formatted)
  paste0(paste(formatted[-length(formatted)], collapse = ", "),
         " & ", formatted[length(formatted)])
}

# Where the work appeared, assembled from whichever fields the entry type uses.
format_venue <- function(e) {
  if (identical(e$bibtype, "article") && !is.null(e$journal)) {
    v <- paste0("*", e$journal, "*")
    if (!is.null(e$volume)) {
      v <- paste0(v, ", ", e$volume)
      if (!is.null(e$number)) v <- paste0(v, "(", e$number, ")")
    }
    if (!is.null(e$pages)) v <- paste0(v, ", ", e$pages)
    return(v)
  }
  if (identical(e$bibtype, "techreport")) {
    # Prefer the series name (it usually already names the institution).
    bits <- c(e$series %||% e$institution,
              if (!is.null(e$number)) paste("no.", e$number))
    return(paste(Filter(Negate(is.null), bits), collapse = ", "))
  }
  paste(Filter(Negate(is.null), c(e$booktitle, e$publisher, e$institution)), collapse = ", ")
}

doi_url <- function(doi) {
  if (is.null(doi) || !nzchar(doi)) return(NULL)
  if (grepl("^https?://", doi)) doi else paste0("https://doi.org/", doi)
}

# Emit publications as .entry blocks, newest first, grouped under year labels.
render_publications <- function(entries, highlight = "Vaiano") {
  years <- vapply(entries, function(e) {
    y <- suppressWarnings(as.integer(e$year %||% NA))
    if (is.na(y)) 0L else y
  }, integer(1))
  entries <- entries[order(-years)]
  years <- sort(years, decreasing = TRUE)

  out <- character(0)
  last_year <- NULL
  for (idx in seq_along(entries)) {
    e <- entries[[idx]]
    y <- as.character(years[idx])
    if (is.null(last_year) || !identical(y, last_year)) {
      out <- c(out, paste0("[", y, "]{.entry-group}"), "")
      last_year <- y
    }
    out <- c(out, "::: {.entry}", paste0("**", e$title, "**"), "")
    out <- c(out, format_authors(e$author, highlight), "")

    body <- format_venue(e)
    url <- doi_url(e$doi)
    if (!is.null(url)) {
      body <- paste0(if (nzchar(body)) paste0(body, " · ") else "", "[DOI](", url, ")")
    }
    if (nzchar(body)) out <- c(out, body, "")
    out <- c(out, ":::", "")
  }
  paste(out, collapse = "\n")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Parse a europasscv LaTeX CV into a structure the website can render.
#
# The CV in cv_source/ is the single source of truth: edit the .tex, re-render the
# site, and the CV page follows. Only the macros listed below are read; anything else
# in the .tex (personal info, languages, bibliography) is ignored.
#
#   \ecvsection{Name}                  -> starts a section
#   \ecvtitle{Dates}{Title}            -> starts an entry
#   \ecvtitlelevel{Dates}{Title}{Lvl}  -> starts an entry (third argument appended)
#   \ecvitem{}{Text}                   -> a detail line on the current entry
#
# Commented-out lines are skipped, so anything you have %-ed out in the CV stays off
# the website too.

# Read the argument that starts at `start` (the position of an opening brace),
# respecting nesting. Returns the contents and the position just past the closing brace.
read_braced_arg <- function(chars, start) {
  if (start > length(chars) || chars[start] != "{") {
    return(list(value = NA_character_, next_pos = start))
  }
  depth <- 0L
  i <- start
  while (i <= length(chars)) {
    ch <- chars[i]
    escaped <- i > 1 && chars[i - 1] == "\\"
    if (!escaped && ch == "{") depth <- depth + 1L
    if (!escaped && ch == "}") {
      depth <- depth - 1L
      if (depth == 0L) {
        value <- paste(chars[(start + 1):(i - 1)], collapse = "")
        if (i == start + 1) value <- ""
        return(list(value = value, next_pos = i + 1L))
      }
    }
    i <- i + 1L
  }
  stop("Unbalanced braces in the .tex starting at character ", start)
}

# Strip LaTeX comments: a % that isn't escaped comments out the rest of the line.
strip_comments <- function(lines) {
  vapply(lines, function(line) {
    chars <- strsplit(line, "", fixed = TRUE)[[1]]
    if (!length(chars)) return("")
    for (i in seq_along(chars)) {
      if (chars[i] == "%" && (i == 1 || chars[i - 1] != "\\")) {
        return(if (i == 1) "" else paste(chars[seq_len(i - 1)], collapse = ""))
      }
    }
    line
  }, character(1), USE.NAMES = FALSE)
}

# Turn a LaTeX fragment into markdown.
tex_to_markdown <- function(x) {
  if (is.na(x) || !nzchar(x)) return("")
  x <- gsub("\\\\textit\\{([^{}]*)\\}", "*\\1*", x)
  x <- gsub("\\\\emph\\{([^{}]*)\\}", "*\\1*", x)
  x <- gsub("\\\\textbf\\{([^{}]*)\\}", "**\\1**", x)
  x <- gsub("\\\\LaTeX\\b", "LaTeX", x)
  x <- gsub("``([^\"]*)\"", "“\\1”", x)   # ``quoted" -> curly quotes
  x <- gsub("---", "—", x, fixed = TRUE)
  x <- gsub("--", "–", x, fixed = TRUE)
  x <- gsub("\\\\&", "&", x)
  x <- gsub("\\\\%", "%", x)
  x <- gsub("\\\\_", "_", x)
  x <- gsub("~", " ", x, fixed = TRUE)
  x <- gsub("[{}]", "", x)                          # leftover grouping braces
  x <- gsub("[[:space:]]+", " ", x)
  trimws(x)
}

parse_europasscv <- function(path) {
  if (!file.exists(path)) {
    stop("CV source not found: ", path,
         "\nExpected the .tex file in cv_source/ — see README.")
  }
  text <- paste(strip_comments(readLines(path, warn = FALSE)), collapse = "\n")
  chars <- strsplit(text, "", fixed = TRUE)[[1]]

  sections <- list()
  cur_section <- NULL
  cur_entry <- NULL

  flush_entry <- function() {
    if (!is.null(cur_entry) && !is.null(cur_section)) {
      cur_section$entries[[length(cur_section$entries) + 1L]] <<- cur_entry
    }
    cur_entry <<- NULL
  }
  flush_section <- function() {
    flush_entry()
    if (!is.null(cur_section)) {
      sections[[length(sections) + 1L]] <<- cur_section
    }
    cur_section <<- NULL
  }

  # Longest macro name first so \ecvtitlelevel isn't matched as \ecvtitle.
  macros <- c("ecvsection", "ecvtitlelevel", "ecvtitle", "ecvitem")
  i <- 1L
  n <- length(chars)

  while (i <= n) {
    if (chars[i] != "\\") { i <- i + 1L; next }

    rest <- paste(chars[i:min(i + 20L, n)], collapse = "")
    hit <- NULL
    for (m in macros) {
      if (startsWith(rest, paste0("\\", m))) { hit <- m; break }
    }
    if (is.null(hit)) { i <- i + 1L; next }

    a1 <- read_braced_arg(chars, i + nchar(hit) + 1L)

    if (hit == "ecvsection") {
      flush_section()
      cur_section <- list(name = tex_to_markdown(a1$value), entries = list())
      i <- a1$next_pos
      next
    }

    a2 <- read_braced_arg(chars, a1$next_pos)

    if (hit == "ecvitem") {
      # First argument is a label (always empty in this CV); second is the text.
      if (!is.null(cur_entry)) {
        txt <- tex_to_markdown(a2$value)
        if (nzchar(txt)) cur_entry$items <- c(cur_entry$items, txt)
      }
      i <- a2$next_pos
      next
    }

    # ecvtitle / ecvtitlelevel
    flush_entry()
    dates <- tex_to_markdown(a1$value)
    title <- tex_to_markdown(a2$value)
    next_i <- a2$next_pos
    if (hit == "ecvtitlelevel") {
      a3 <- read_braced_arg(chars, a2$next_pos)
      lvl <- tex_to_markdown(a3$value)
      if (nzchar(lvl)) title <- paste0(title, " (", lvl, ")")
      next_i <- a3$next_pos
    }
    cur_entry <- list(dates = dates, title = title, items = character(0))
    i <- next_i
  }
  flush_section()

  # Drop sections that contain no parseable entries (e.g. Personal skills, which uses
  # language macros this parser deliberately ignores).
  Filter(function(s) length(s$entries) > 0, sections)
}

# Emit the parsed CV as markdown .entry blocks, matching the rest of the site.
render_cv_sections <- function(sections, heading_level = 2) {
  hashes <- strrep("#", heading_level)
  out <- character(0)
  for (s in sections) {
    out <- c(out, paste(hashes, s$name), "")
    for (e in s$entries) {
      out <- c(out, "::: {.entry}", paste0("**", e$title, "**"), "")
      out <- c(out, e$dates, "")
      if (length(e$items)) {
        out <- c(out, paste(e$items, collapse = "\n\n"), "")
      }
      out <- c(out, ":::", "")
    }
  }
  paste(out, collapse = "\n")
}

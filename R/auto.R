#' Automatically or manually toggle light, dark, or favorite themes
#'
#' These functions help manage switching between preferred themes. Use
#' `set_theme_light()` and `set_theme_dark()` to declare your preferred
#' light/dark themes that can be toggled or selected automatically with
#' `use_theme_toggle()` or `use_theme_auto()` or their corresponding RStudio
#' addins. Alternatively, you can create a list of favorite themes with
#' `set_theme_favorite()`. You can then cycle through this list with
#' `use_theme_favorite()` or by using the RStudio addin.
#'
#' For best results, set your preferred themes in your `~/.Rprofile` using the
#' instructions in the section below.
#'
#' @section Set preferred theme in `.Rprofile`:
#'
#' Add the following to your `~/.Rprofile` (see [usethis::edit_r_profile()]) to
#' declare your default themes:
#'
#' ```
#' if (interactive() && requireNamespace("rsthemes", quietly = TRUE)) {
#'   # Set preferred themes if not handled elsewhere..
#'   rsthemes::set_theme_light("One Light {rsthemes}")  # light theme
#'   rsthemes::set_theme_dark("One Dark {rsthemes}") # dark theme
#'   rsthemes::set_theme_favorite(c(
#'     "GitHub {rsthemes}", "Solarized Dark {rsthemes}", "Fairyfloss {rsthemes}"
#'   ))
#'
#'
#'   # Whenever the R session restarts inside RStudio...
#'   setHook("rstudio.sessionInit", function(isNewSession) {
#'     # Automatically choose the correct theme based on time of day
#'     rsthemes::use_theme_auto(dark_start = "18:00", dark_end = "6:00")
#'   }, action = "append")
#' }
#' ```
#'
#' If you'd rather not use this approach, you can simply declare the global
#' options that declare the default themes, but you won't be able to use
#' [use_theme_auto()] at startup.
#'
#' ```
#' # ~/.Rprofile
#' rsthemes::set_theme_light("One Light {rsthemes}")
#' rsthemes::set_theme_dark("One Dark {rsthemes}")
#' rsthemes::set_theme_favorite(c(
#'   "GitHub {rsthemes}", "Solarized Dark {rsthemes}", "Fairyfloss {rsthemes}"
#' ))
#' ```
#'
#' ```
#' # ~/.Rprofile
#' options(
#'   rsthemes.theme_light = "One Light {rsthemes}",
#'   rsthemes.theme_dark = "One Dark {rsthemes}"
#'   rsthemes.theme_favorite = c("GitHub {rsthemes}", "One Light {rsthemes}")
#' )
#' ```
#'
#' @section RStudio Addins:
#'
#' \pkg{rsthemes} includes five RStudio addins to help you easily switch between
#' light and dark modes. You can set the default dark or light theme to the
#' current theme. You can also toggle between light and dark mode or switch
#' to the automatically chosen light/dark theme based on time of day. You can
#' set a keyboard shortcut to **Toggle Dark Mode**, **Next Favorite Theme**, or
#' **Auto Choose Dark or Light Theme** from the _Modify Keyboard Shortcuts..._
#' window under the RStudio _Tools_ menu.
#'
#' @param theme The name of the theme, or `NULL` to use current theme.
#' @param quietly Suppress confirmation messages
#' @param dark_start Start time of dark mode, in 24-hour `"HH:MM"` format.
#' @param dark_end End time of dark mode, in 24-hour `"HH:MM"` format.
#' @name auto_theme
NULL

#' @describeIn auto_theme Set default light theme
#' @export
set_theme_light <- function(theme = NULL) {
  set_theme_light_dark(theme, "light")
}

#' @describeIn auto_theme Set default dark theme
#' @export
set_theme_dark <- function(theme = NULL) {
  set_theme_light_dark(theme, "dark")
}

#' @describeIn auto_theme Set favorite themes
#' @param append \[set_theme_favorite\] Should the theme be appended to the list
#'   of favorite themes? If `FALSE`, then `theme` replaces the current list of
#'   favorite themes.
#' @export
set_theme_favorite <- function(theme = NULL, append = TRUE) {
  for (i in seq_along(theme)) {
    theme[i] <- get_or_check_theme(theme[i])
  }
  favorite_themes <- if (isTRUE(append)) get_theme_option("favorite") else c()
  favorite_already <- intersect(theme, favorite_themes)
  if (length(favorite_already)) {
    favorite_already <- gsub(" ", "\u00a0", favorite_already)
    cli::cli_alert_warning("{.emph {favorite_already}} already {?is a/are} favorite theme{?s}")
    return(invisible())
  }
  theme <- setdiff(theme, favorite_already)
  options(rsthemes.theme_favorite = c(favorite_themes, theme))
  invisible(theme)
}

get_or_check_theme <- function(theme = NULL, style = NULL) {
  if (is.null(theme)) {
    if (!in_rstudio()) return(NULL)
    theme <- get_current_theme_name()
  }
  if (in_rstudio()) {
    theme <- stop_if_theme_not_valid(theme)
    if (!is.null(style)) {
      warn_theme_style_mismatch(theme, style)
    }
  }
  theme
}

set_theme_light_dark <- function(theme = NULL, style = c("light", "dark")) {
  style <- match.arg(style)
  theme <- get_or_check_theme(theme, style)

  switch(
    style,
    "light" = options("rsthemes.theme_light" = theme),
    "dark" = options("rsthemes.theme_dark" = theme),
  )
  invisible(theme)
}

#' @describeIn auto_theme Use default light theme
#' @export
use_theme_light <- function(quietly = FALSE) use_theme("light", quietly)

#' @describeIn auto_theme Use default dark theme
#' @export
use_theme_dark <- function(quietly = FALSE) use_theme("dark", quietly)

use_theme <- function(style = c("light", "dark"), quietly = FALSE) {
  if (!in_rstudio()) return(invisible())

  theme <- switch(
    match.arg(style),
    "light" = getOption("rsthemes.theme_light", NULL),
    "dark" = getOption("rsthemes.theme_dark", NULL)
  )
  apply_Theme(theme, quietly, style)
}

apply_theme <- function(theme, quietly = FALSE, style = NULL) {
  stop_if_theme_not_set(theme)
  if (theme == get_current_theme_name()) {
    return(invisible())
  }
  if (!quietly) {
    if (!is.null(style)) {
      cli::cli_alert("Switching to {style} theme: {.emph {theme}}")
    } else {
      cli::cli_alert("{.emph {theme}}")
    }
  }
  if (!theme %in% get_theme_names()) {
    cli::cli_alert_danger("{.emph {theme}} is not installed")
    return(invisible())
  }
  rstudioapi::applyTheme(theme)
  invisible(theme)
}

#' @describeIn auto_theme Toggle between dark and light themes
#' @export
use_theme_toggle <- function(quietly = FALSE) {
  theme_current <- rstudioapi::getThemeInfo()
  if (isTRUE(theme_current$dark)) {
    use_theme_light(quietly)
  } else {
    use_theme_dark(quietly)
  }
}

#' @describeIn auto_theme Auto switch between dark and light themes
#' @export
use_theme_auto <- function(dark_start = "18:00", dark_end = "6:00", quietly = FALSE) {
  dark_start <- hms::parse_hm(dark_start)
  dark_end <- hms::parse_hm(dark_end)
  now <- hms::as_hms(Sys.time())

  pre_start <- use_theme_dark

  if (dark_end > dark_start) {
    # if light mode overnight, swap dark start/end
    .dark_start <- dark_start
    dark_start <- dark_end
    dark_end <- .dark_start
    pre_start <- use_theme_light
  }

  if (now > dark_start) {
    use_theme_dark(quietly)
  } else if (now > dark_end) {
    use_theme_light(quietly)
  } else {
    pre_start(quietly)
  }
}

#' @describeIn auto_theme Walk through a list of favorite themes
#' @export
use_theme_favorite <- function(quietly = FALSE) {
  themes <- get_theme_option("favorite")
  if (!length(themes)) {
    cli::cli_alert_warning("No favorite themes are set")
    cli::cli_alert_info("Use {.code rsthemes::set_theme_favorite()} to set your favorite theme list")
    return(invisible())
  }
  current <- get_current_theme_name()
  idx <- which(current == themes)
  if (!length(idx)) idx <- 0
  if (length(idx) > 1) idx <- idx[1]
  idx <- idx + 1
  if (idx > length(themes)) idx <- 1
  apply_theme(themes[idx], quietly)
}

get_theme_option <- function(style = c("light", "dark", "favorite")) {
  switch(
    match.arg(style),
    "light" = getOption("rsthemes.theme_light", NULL),
    "dark" = getOption("rsthemes.theme_dark", NULL),
    "favorite" = getOption("rsthemes.theme_favorite", NULL),
    stop("Unkown theme style: '", style, "'", call. = FALSE)
  )
}

get_current_theme_name <- function() {
  rstudioapi::getThemeInfo()$editor
}

stop_if_theme_not_set <- function(theme_opt = NULL, style = c("light", "dark")) {
  if (!is.null(theme_opt)) {
    return(theme_opt)
  }
  style <- match.arg(style)
  stop(
    "Default ", style, " theme not set, please use `rsthemes::",
    switch(
      style,
      "light" = "set_theme_light()",
      "dark" = "set_theme_dark()"
    ),
    "`` to set the default theme.",
    call. = FALSE
  )
}

stop_if_theme_not_valid <- function(theme) {
  if (!in_rstudio()) return(theme)
  if (theme %in% get_theme_names()) return(theme)
  stop("'", theme, '" is not the name of an installed theme.', call. = FALSE)
}

get_theme_names <- function() {
  unname(sapply(rstudioapi::getThemes(), function(x) x$name))
}

get_theme_info <- function(theme) {
  stop_if_theme_not_valid(theme)

  theme <- Filter(function(x) x$name == theme, rstudioapi::getThemes())
  if (length(theme) == 1) {
    theme[[1]]
  } else {
    theme
  }
}

warn_theme_style_mismatch <- function(theme, style = c("light", "dark")) {
  style <- match.arg(style)
  stopifnot(length(theme) == 1)
  theme_info <- get_theme_info(theme)
  if (theme_info$isDark != (style == "dark")) {
    warning(
      "You are setting the default ", style, " theme, but ",
      "'", theme_info$name, "' is a ",
      if (theme_info$isDark) "dark" else "light",
      " style theme.",
      call. = FALSE
    )
  }
  theme
}

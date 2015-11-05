
#' @importFrom utils as.person

parse_authors_at_r <- function(x) {

  if (is.null(x)) return(NULL)

  out <- tryCatch(
    {
      out <- eval(parse(text = x))
      if (!inherits(out, "person")) {
        out <- do.call("c", lapply(x, as.person))
      }
      out
    },
    error = identity
  )
  if (inherits(out, "error")) NULL else out
}


deparse_authors_at_r <- function(x) {
  fmt <- format(x, style = "R")
  paste0(paste0("    ", fmt, collapse = "\n"), "\n")
}


set_author_field <- function(authors, which, field, value) {
  rval <- unclass(authors)
  for (w in which) rval[[w]][[field]] <- value
  class(rval) <- class(authors)
  rval
}


ensure_authors_at_r <- function(obj) {
  if (! obj$has_fields("Authors@R")) {
    stop("No 'Authors@R' field!\n",
         "You can create one with $add_author or $to_authors_at_r")
  }
}


## Find an author in the Authors@R field, based on a partical
## specification. E.g. it is enough to give the first name.

search_for_author <- function(authors, given = NULL, family = NULL,
                              email = NULL, role = NULL, comment = NULL) {

  matching <-
    ngrepl(given, authors$given) &
    ngrepl(family, authors$family) &
    ngrepl(email, authors$email) &
    ngrepl(role, authors$role) &
    ngrepl(comment, authors$comment)

  list(index = which(matching), authors = authors[matching])
}


desc_get_authors <- function(self, private, ensure = TRUE) {
  if (ensure) ensure_authors_at_r(self)
  parse_authors_at_r(self$get("Authors@R"))
}


desc_set_authors <- function(self, private, authors) {
  self$set("Authors@R", deparse_authors_at_r(authors))
}


desc_add_author <- function(self, private, given, family, email, role,
                            comment) {
  orig <- desc_get_authors(self, private, ensure = FALSE)
  newp <- person(given = given, family = family, email = email,
                 role = role, comment = comment)
  self$set_authors(c(orig, newp))
}


desc_add_role <- function(self, private, role, given, family, email,
                          comment) {
  orig <- desc_get_authors(self, private, ensure = FALSE)
  wh <- search_for_author(
    orig, given = given, family = family, email = email, comment = comment,
    role = NULL
  )

  for (w in wh$index) {
    orig <- set_author_field(
      orig,
      w,
      "role",
      unique(c(orig[[w]]$role, role))
    )
  }

  self$set_authors(orig)
}


desc_del_author <- function(self, private, given, family, email, role,
                            comment) {

  orig <- desc_get_authors(self, private, ensure = FALSE)
  wh <- search_for_author(
    orig, given = given, family = family, email = email, comment = comment
  )

  if (length(wh$index) == 0) {
    message("Could not find author to remove.")
  } else {
    au <- if (length(wh$index) == 1) "Author" else "Authors"
    message(
      au, "removed: ",
      paste(wh$authors$given, wh$authors$family, collapse = ", "),
      "."
    )
    self$set_authors(orig[-wh$index])
  }

  invisible(self)
}


desc_del_role <- function(self, private, role, given, family, email,
                          comment) {

  orig <- desc_get_authors(self, private, ensure = FALSE)
  wh <- search_for_author(
    orig, given = given, family = family, email = email, comment = comment,
    role = NULL
  )

  for (w in wh$index) {
    orig <- set_author_field(
      orig,
      w,
      "role",
      setdiff(orig[[w]]$role, role)
    )
  }

  self$set_authors(orig)
}


desc_change_maintainer <- function(self, private, given, family, email,
                                   comment) {
  ensure_authors_at_r(self)
  self$del_role(role = "cre")
  self$add_role(role = "cre", given = given, family = family,
                email = email, comment = comment)
}


desc_add_me <- function(self, private, role, comment) {
  check_for_package("whoami", "$add_me needs the 'whoami' package")
  fn <- strsplit(whoami::fullname(), "[ ]+")[[1]]
  family <- tail(fn, 1)
  given <- paste(fn[-length(fn)], collapse = " ")
  email <- whoami::email_address()
  self$add_author(given = given, family = family, email = email,
                  comment = comment, role = role)
}

## Try to parse the 'Author' and 'Maintainer' fields in some
## sensible way

desc_to_authors_at_r <- function(self, private) {

  if (self$has_fields("Authors@R")) {
    stop("There is an 'Authors@R field' already")
  }
  
  author <- str_trim(self$get("Author"))
  maint <- str_trim(self$get("Maintainer"))

  if (is.na(author) && is.na(maint)) {
    stop("No 'Author' and 'Maintainer' fields, no author information")
  }

  authors <- structure(list(), class = "person")

  ## Maintainer is simple, because it is standardized
  
  if (!is.na(maint)) {
    m <- re_groups("^(.*)\\s([^\\s]+)\\s+<(.*)>$", maint, perl = TRUE)
    maint_person <- person(
      given = m[1],
      family = m[2],
      email = m[3],
      role = c("cre", "ctb")
    )
    authors <- append(authors, maint_person)
  }

  ## Author is pretty much guessing
  
  if (!is.na(author)) {
    
  }
  
  if (!is.na(author)) self$del('Author')
  if (!is.na(maint)) self$del('Maintainer')

  self$set_authors(authors)
}
#!/usr/bin/env Rscript

repo_path <- Sys.getenv("SD_REPO_PATH", ".")
upgrade_remotes <- Sys.getenv("SD_UPGRADE_REMOTES", "")

cat("\n==================================\n")
cat("Running system dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat("==================================\n")

# Install the remotes package
if (!require("remotes")) {
  install.packages(
    "remotes",
    repos = "https://cloud.r-project.org/"
  )
}

# Upgrade the remotes package to get the latest bugfixes
if (upgrade_remotes == "true") {
  remotes::install_github("r-lib/remotes@main")
  # Reload remotes
  require(remotes)
}

os_release_file <- "/etc/os-release"
if (file.exists(os_release_file)) { # linux-base OS
  os_info <- read.csv(os_release_file, sep = "=", header = FALSE)
  v_os_info <- setNames(os_info$V2, os_info$V1)
  if (v_os_info[["NAME"]] == "Ubuntu") {
    ubuntu_version <- as.character(v_os_info[["VERSION_ID"]])
    cat(paste("Ubuntu version: \"", ubuntu_version, "\"\n", sep = ""))
    sys_deps_for_pkg <- remotes::system_requirements(
      os = "ubuntu",
      os_release = ubuntu_version,
      path = repo_path
    )
    sys_pgks <- gsub("^apt-get install -y ", "", sys_deps_for_pkg)
    sys_pgks <- c("libgit2-dev", sys_pgks) # For installing staged.dependencies
    has_pkgs <- vapply(
      sys_pgks,
      function(pkg) {
        system2(
          "sudo",
          c("dpkg", "-l", pkg),
          stdout = NULL,
          stderr = NULL
        ) == 0
      },
      logical(1)
    )
    if (any(!has_pkgs)) {
      system2("sudo", c("apt-get", "update"))
      system2("sudo", c("apt-get", "install", "-y", sys_pgks[!has_pkgs]))
    }
  } else {
    cat(paste(
      "System dependencies not implemented for os:",
      v_os_info[["NAME"]]
    ))
  }
} else { # macos
  systemname <- sessionInfo()$running
  cat(paste(
    "Checking system",
    systemname
  ))
  if (grepl("macos", systemname, ignore.case = TRUE)) {
    macos_req_for_pkg <- function(pkgname) {
      sysreqs_url <- sprintf("https://sysreqs.r-hub.io/pkg/%s", pkgname)
      res <- httr::HEAD(sysreqs_url)
      if (res$status_code == 200) {
        res <- httr::GET(sysreqs_url)
        sysreq <- httr::content(res)
        sysreq_chars <- unique(unlist(lapply(sysreq, function(x) {
          x[[1]]$platforms[["OSX/brew"]]
        })))
        return(sysreq_chars)
      }
    }
    desc_file <- file.path(repo_path, "DESCRIPTION")
    if (file.exists(desc_file)) {
      # Install the desc package
      if (!require("desc")) {
        install.packages(
          "desc",
          repos = "https://cloud.r-project.org/"
        )
      }
      # Install the httr package
      if (!require("httr")) {
        install.packages(
          "httr",
          repos = "https://cloud.r-project.org/"
        )
      }
      deps <- desc::desc_get_deps(desc_file)
      deps_pkgs <- deps[deps$type != "Suggests", ]$package
      cat(paste(
        "Dependencies:",
        paste(deps_pkgs, collapse = ", "),
        "\"\n"
      ))
      sys_pkgs <- unique(unlist(lapply(deps_pkgs, macos_req_for_pkg)))
      cat(paste(
        "Installing sys deps:",
        paste(sys_pkgs, collapse = ", "),
        "\"\n"
      ))
      if (length(sys_pkgs) > 0) {
        lapply(
          sys_pkgs,
          function(pkg) {
            system(
              sprintf("brew list %s || brew install %s", pkg, pkg),
              intern = TRUE
            )
          }
        )
      }
    } else {
      cat(paste(
        desc_file,
        " doesn't exist",
        "\"\n"
      ))
    }
  } else {
    cat(paste(
      "System dependencies not implemented for os:",
      systemname
    ))
  }
}

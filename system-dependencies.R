#!/usr/bin/env Rscript

repo_path <- Sys.getenv("SD_REPO_PATH", ".")
upgrade_remotes <- Sys.getenv("SD_UPGRADE_REMOTES", "")
sd_quiet <- isTRUE(as.logical(Sys.getenv("SD_QUIET", "true")))

cat("\n==================================\n")
cat("Running system dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat(paste("sd_quiet: \"", sd_quiet, "\"\n", sep = ""))
cat(paste("upgrade_remotes: \"", upgrade_remotes, "\"\n", sep = ""))
cat("==================================\n")

# Install the remotes package
if (!require("remotes", quietly = sd_quiet) && upgrade_remotes != "true") {
  install.packages(
    "remotes",
    upgrade = "never",
    Ncpus = threads
  )
}

# Upgrade the remotes package to get the latest bugfixes
if (upgrade_remotes == "true") {
  print("Upgrading the remotes package to get the latest version from GitHub")
  old_wd <- getwd()
  tmp_dir <- tempdir()
  setwd(tmp_dir)
  print("Downloading the remotes package source")
  download.file(
    url = "https://github.com/r-lib/remotes/archive/refs/heads/main.zip",
    dest = "remotes.zip"
  )
  print("Extracting the remotes package source")
  unzip("remotes.zip")
  file.rename("remotes-main", "remotes")
  print("Building the remotes package from source")
  system2(
    command = "R",
    args = c(
      "CMD", "build",
      "--no-manual", "--no-build-vignettes", "--force",
      "remotes"
    )
  )
  print("Installing the remotes package")
  system2(
    command = "R",
    args = c(
      "CMD", "INSTALL",
      "--no-docs",
      "remotes_*.tar.gz"
    )
  )
  setwd(old_wd)
}

os_info <- read.csv("/etc/os-release", sep = "=", header = FALSE)
v_os_info <- setNames(os_info$V2, os_info$V1)

if (v_os_info[["NAME"]] == "Ubuntu") {
  ubuntu_version <- as.character(v_os_info[["VERSION_ID"]])
  cat(paste("Ubuntu version: \"", ubuntu_version, "\"\n", sep = ""))
  # The following is a workaround until we have a newer
  # version of remotes that supports Ubuntu 22.04
  if (ubuntu_version == "22.04") {
    ubuntu_version <- "20.04"
  }
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

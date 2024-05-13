#!/usr/bin/env Rscript

repo_path <- Sys.getenv("SD_REPO_PATH", ".")
upgrade_remotes <- Sys.getenv("SD_UPGRADE_REMOTES", "")

# temporary fix for remotes : 
Sys.setenv(RSPM_ROOT = "https://packagemanager.posit.co")

cat("\n==================================\n")
cat("Running system dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat("==================================\n")

# Install the pak package
if (!require("pak")) {
  install.packages(
<<<<<<< HEAD
    "pak",
    upgrade = "never",
=======
    "remotes",
>>>>>>> main
    repos = "https://cloud.r-project.org/"
  )
}

# Upgrade the remotes package to get the latest bugfixes
if (upgrade_remotes == "true") {
  remotes::install_github("r-lib/remotes@main")
  # Reload remotes
  require(remotes)
}

os_info <- read.csv("/etc/os-release", sep = "=", header = FALSE)
v_os_info <- setNames(os_info$V2, os_info$V1)

if (v_os_info[["NAME"]] == "Ubuntu") {
  ubuntu_version <- as.character(v_os_info[["VERSION_ID"]])
  cat(paste("Ubuntu version: \"", ubuntu_version, "\"\n", sep = ""))
  sys_reqs <- pak::pkg_sysreqs(read.dcf(file.path(repo_path, 'DESCRIPTION'))[,'Package'])
  sys_pkgs <- strsplit(gsub("^apt-get -y install ", "", sys_reqs["install_scripts"]), '\\s')
  sys_pkgs <- c("libgit2-dev", sys_pkgs) # For installing staged.dependencies
  cat(paste0("Ensuring that the following dependencies are installed: ", sys_pkgs, "\n\n"))
  has_pkgs <- vapply(
    sys_pkgs,
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
  cat(paste0("The following system dependencies will be installed: ", sys_pkgs[!has_pkgs], "\n\n"))
  if (any(!has_pkgs)) {
    system2("sudo", c("apt-get", "update"))
    system2("sudo", c("apt-get", "install", "-y", sys_pkgs[!has_pkgs]))
  }
} else {
  cat(paste(
    "System dependencies not implemented for os:",
    v_os_info[["NAME"]]
  ))
}

#!/usr/bin/env Rscript

repo_path <- Sys.getenv("SD_REPO_PATH", ".")

cat("\n==================================\n")
cat("Running system dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat("==================================\n")

# Install the pak package
if (!require("pak")) {
  install.packages(
    "pak",
    upgrade = "never",
    repos = "https://cloud.r-project.org/"
  )
}

os_info <- read.csv("/etc/os-release", sep = "=", header = FALSE)
v_os_info <- setNames(os_info$V2, os_info$V1)

if (v_os_info[["NAME"]] == "Ubuntu") {
  ubuntu_version <- as.character(v_os_info[["VERSION_ID"]])
  cat(paste("Ubuntu version: \"", ubuntu_version, "\"\n", sep = ""))
  sys_reqs <- pak::pkg_sysreqs(read.dcf(file.path(repo_path, 'DESCRIPTION'))[,'Package'])
  sys_pkgs <- c(unlist(strsplit(gsub("^apt-get -y install ", "", sys_reqs["install_scripts"]), '\\s')))
  sys_pkgs <- c("libgit2-dev", sys_pkgs) # For installing staged.dependencies
  cat("\nChecking if the following dependencies are installed:\n")
  cat(sys_pkgs)
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
  if (any(!has_pkgs)) {
    cat("\nThe following system dependencies will be installed:\n")
    cat(sys_pkgs[!has_pkgs])
    system2("sudo", c("apt-get", "update"))
    system2("sudo", c("apt-get", "install", "-y", sys_pkgs[!has_pkgs]))
  } else {
    cat("\nLooks like all the required system dependencies are installed.\n")
  }
} else {
  cat(paste(
    "System dependencies not implemented for os:",
    v_os_info[["NAME"]]
  ))
}

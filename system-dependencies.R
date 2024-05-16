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
  tryCatch(
    {
      sys_reqs <- pak::pkg_sysreqs(
        read.dcf(file.path(repo_path, "DESCRIPTION"))[,"Package"]
      )
      sys_pkgs <- c(unlist(strsplit(
        gsub("^apt-get -y install ", "", sys_reqs["install_scripts"]), "\\s"
      )))
      if (length(sys_pkgs) > 0) {
        # For installing staged.dependencies
        sys_pkgs <- c("libgit2-dev", sys_pkgs)
      } else {
        sys_pkgs <- c("libgit2-dev")
      }
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
        cat(
          "\nLooks like all the required system dependencies are installed.\n"
        )
      }
    },
    # This error handling is with pak::pkg_sysreqs() in mind.
    # If a package is missing from pak database
    # (e.g. because it's not publicly available),
    # pak will fail to determine system dependencies.
    error = function(x) {
      cat("An error occurred while installing system dependencies:\n")
      message(conditionMessage(x))
    },
    warning = function(x) {
      cat("A warning occurred while installing system dependencies:\n")
      message(conditionMessage(x))
    }
  )

} else {
  cat(paste(
    "System dependencies not implemented for os:",
    v_os_info[["NAME"]]
  ))
}

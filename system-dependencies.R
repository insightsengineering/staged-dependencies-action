#!/usr/bin/env Rscript

repo_path <- Sys.getenv("SD_REPO_PATH", ".")

cat("\n==================================\n")
cat("\nRunning system dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat("==================================\n")


os_info <- read.csv("/etc/os-release", sep = "=", header = FALSE)

v_os_info <- setNames(os_info$V2, os_info$V1)

if (v_os_info[["NAME"]] == "Ubuntu") {
  ubuntu_version <- v_os_info[["VERSION_ID"]]
  sys_deps_for_pkg <- remotes::system_requirements(
    "ubuntu", ubuntu_version,
    path = repo_path
  )
  sys_pgks <- gsub("^apt-get install -y ", "", sys_deps_for_pkg)
  has_pkgs <- vapply(
    sys_pgks,
    function(pkg) {
      system2(
        "dpkg",
        c("-l", pkg),
        stdout = NULL,
        stderr = NULL
      ) == 0
    },
    logical(1)
  )
  if (any(!has_pkgs)) {
    system2("apt-get", "update")
    system2("apt-get", c("install", "-y", sys_pgks[!has_pkgs]))
  }
} else {
  cat(paste(
    "System dependencies not implemented for os:",
    v_os_info[["NAME"]]
  ))
}

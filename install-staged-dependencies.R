#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
stopifnot(length(args) == 2)

repo_path = args[1]
setwd(repo_name)

sd_version = args[2] # staged.dependencies package version

cat(paste("Path:", repo_path, "\n"))
cat(paste("Staged dependencies version:", sd_version, "\n"))


os_info <- read.csv("/etc/os-release", sep = "=", header = FALSE)
v_os_info <- setNames(os_info$V2, os_info$V1)
if (v_os_info[['NAME']] == "Ubuntu") {
ubuntu_version <- v_os_info[['VERSION_ID']]
sys_deps_for_pkg <- remotes::system_requirements("ubuntu", ubuntu_version, path = repo_path)
sys_pgks <- gsub("^apt-get install -y ", "", sys_deps_for_pkg)
has_pkgs <- vapply(sys_pgks, function(pkg) system2("dpkg", c("-l", pkg), stdout = NULL, stderr = NULL) == 0,  logical(1))
if (any(!has_pkgs)) {
    system2("apt-get", "update")
    system2("apt-get", c("install", "-y", sys_pgks[!has_pkgs]))
}
} else {
cat(paste("Script not implemented for:", v_os_info[['NAME']])
}


setwd(repo_path)
options(repos = c(CRAN = "https://cloud.r-project.org/"))
ncores <- parallel::detectCores(all.tests = FALSE, logical = TRUE)
cat(paste("\n\nnumber of cores detected:", ncores, "\n\n"))
if (file.exists("renv.lock")) {
renv::restore()
} else {
remotes::install_deps(dependencies = TRUE, upgrade = "never", Ncpus = ncores)
}
if (file.exists("staged_dependencies.yaml")) {
cat("\nInstall Staged Dependencies\n\n\n")
if (!require("staged.dependencies")) {
    remotes::install_github("openpharma/staged.dependencies", ref = sd_version, Ncpus = ncores, upgrade = "never")
}
cat("\nCalculating Staged Dependency Table for ref: ${{ github.ref }} ...\n\n")
ref = "${{ github.ref }}"
if (startsWith(ref, "refs/tags")){
    x <- staged.dependencies::dependency_table(ref=ref)
}
else {
    x <- staged.dependencies::dependency_table()
}
print(x, width = 120)
cat("\n\n")
staged.dependencies::install_deps(dep_structure = x, install_project = FALSE, verbose = TRUE)
}
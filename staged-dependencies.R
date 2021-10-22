#!/usr/bin/env Rscript

split_to_map = function(args){
    tmp = strsplit(x =unlist(strsplit(args, ",")), "=")
    content = unlist(lapply(tmp, function(x) x[2]))
    names(content) = unlist(lapply(tmp, function(x) x[1]))
    return(content)
}

repo_path <- Sys.getenv("SD_REPO_PATH", ".")
staged_version <- Sys.getenv("SD_STAGED_DEPENDENCIES_VERSION", "v0.2.2")
git_ref <- Sys.getenv("SD_GIT_REF")
threads <- Sys.getenv("SD_THREADS", "auto")
cran_repos <- Sys.getenv("SD_CRAN_REPOSITORIES", "CRAN=https://cloud.r-project.org/")
cran_repos_biomarker <- Sys.getenv("SD_ENABLE_BIOMERKER_REPOSITORIES", "false")
token_mapping <- Sys.getenv("SD_TOKEN_MAPPING", "https://github.com=GITHUB_PAT,https://gitlab.com=GITLAB_PAT")
check <- Sys.getenv("SD_ENABLE_CHECK", "true")

cat("\n==================================\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep=""))
cat(paste("staged_version: \"", staged_version, "\"\n", sep=""))
cat(paste("git_ref: \"", git_ref, "\"\n", sep=""))
cat(paste("threads: \"", threads, "\"\n", sep=""))
cat(paste("check: \"", check, "\"\n", sep=""))
cat(paste("cran_repos: \"", cran_repos, "\"\n", sep=""))
cat(paste("cran_repos_biomarker: \"", cran_repos_biomarker, "\"\n", sep=""))
cat(paste("token_mapping: \"", token_mapping, "\"\n", sep=""))
cat("==================================\n")

setwd(repo_path)

if (cran_repos_biomarker) {
    options(repos = c(split_to_map(cran_repos), BiocManager::repositories()))
} else {
    options(repos = split_to_map(cran_repos))
}

if (threads == "auto") {
    threads <- parallel::detectCores(all.tests = FALSE, logical = TRUE)
    cat(paste("Number of cores detected:", threads, "\n\n"))
}

options(
    staged.dependencies.token_mapping = split_to_map(token_mapping)
)


if (file.exists("renv.lock")) {
    renv::restore()
} else {
    remotes::install_deps(dependencies = TRUE, upgrade = "never", Ncpus = threads)
}
if (file.exists("staged_dependencies.yaml")) {
    cat("Install Staged Dependencies\n\n")
    if (!require("staged.dependencies")) {
        remotes::install_github("openpharma/staged.dependencies", ref = staged_version, Ncpus = threads, upgrade = "never")
    }

    cat(paste("\nCalculating Staged Dependency Table for ref: ", git_ref, "...\n\n"))

    if (git_ref != ""){
        x <- staged.dependencies::dependency_table(ref=git_ref)
    } else {
        x <- staged.dependencies::dependency_table()
    }


    print(x, width = 120)
    cat("\n\n")

    if(check){
        cat("\nRunning check yaml consistent...\n\n")
        staged.dependencies::check_yamls_consistent(x, skip_if_missing_yaml = TRUE)
    }

    staged.dependencies::install_deps(dep_structure = x, install_project = FALSE, verbose = TRUE)
}
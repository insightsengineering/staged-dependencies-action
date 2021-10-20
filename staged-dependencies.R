#!/usr/bin/env Rscript

library("optparse")

split_to_map = function(args){
    tmp = strsplit(x =unlist(strsplit(args, ",")), "=")
    content = unlist(lapply(tmp, function(x) x[2]))
    names(content) = unlist(lapply(tmp, function(x) x[1]))
    return(content)
}

option_list <- list( 
    make_option(c("-r", "--repo_path"), type="character", default=".",
        help="Path to directory containing the R package files. [default: \".\"]"),
    make_option(c("-s", "--staged_version"), type="character", default="v0.2.2",
        help="Staged dependencies version. [default: \"v0.2.2\"]"),
    make_option(c("-g", "--git_ref"), type="character", default="",
        help="Git reference. [default: \"\"]"),
    make_option(c("-t", "--threads"), type="integer", default=0, 
        help="Number of theads to use during catalog render. 0 means autodetect [default: 0]"),
    make_option(c("-e", "--cran_repos"), type="character", default="CRAN=https://cloud.r-project.org/", 
        help="Cran repository list, sparated by comma. [default: CRAN=https://cloud.r-project.org/]"),
    make_option(c("-b", "--cran_repos_biomarker"), action="store_true", default=FALSE, 
        help="Add biomarker repos to cran repos"),
    make_option(c("-c", "--check"), action="store_true", default=FALSE, 
        help="Run check_yamls_consistent")
    )

args <- parse_args(OptionParser(option_list=option_list))

cat(paste("\nrepo_path: \"", args$repo_path, "\"\n", sep=""))
cat(paste("staged_version: \"", args$staged_version, "\"\n", sep=""))
cat(paste("git_ref: \"", args$git_ref, "\"\n", sep=""))
cat(paste("threads: \"", args$threads, "\"\n", sep=""))
cat(paste("check: \"", args$check, "\"\n", sep=""))
cat(paste("cran_repos: \"", args$cran_repos, "\"\n", sep=""))
cat(paste("cran_repos_biomarker: \"", args$cran_repos_biomarker, "\"\n", sep=""))

setwd(args$repo_path)

if (args$cran_repos_biomarker) {
    options(repos = c(split_to_map(args$cran_repos), BiocManager::repositories()))
} else {
    options(repos = split_to_map(args$cran_repos))
}

if (args$threads == 0) {
    args$threads <- parallel::detectCores(all.tests = FALSE, logical = TRUE)
    cat(paste("Number of cores detected:", args$threads, "\n\n"))
}

if (file.exists("renv.lock")) {
    renv::restore()
} else {
    remotes::install_deps(dependencies = TRUE, upgrade = "never", Ncpus = args$threads)
}
if (file.exists("staged_dependencies.yaml")) {
    cat("Install Staged Dependencies\n\n")
    if (!require("staged.dependencies")) {
        remotes::install_github("openpharma/staged.dependencies", ref = args$staged_version, Ncpus = args$threads, upgrade = "never")
    }

    cat(paste("\nCalculating Staged Dependency Table for ref: ", args$git_ref, "...\n\n"))
    if (startsWith(args$git_ref, "refs/tags")){
        x <- staged.dependencies::dependency_table(ref=args$git_ref)
    }
    else {
        x <- staged.dependencies::dependency_table()
    }

    print(x, width = 120)
    cat("\n\n")

    if(args$check){
        cat("\nRunning check yaml consistent...\n\n")
        staged.dependencies::check_yamls_consistent(x, skip_if_missing_yaml = TRUE)
    }

    staged.dependencies::install_deps(dep_structure = x, install_project = FALSE, verbose = TRUE)
}
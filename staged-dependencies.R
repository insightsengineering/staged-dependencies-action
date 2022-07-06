#!/usr/bin/env Rscript

split_to_map <- function(args) {
  tmp <- strsplit(x = unlist(strsplit(args, ",")), "=")
  content <- unlist(lapply(tmp, function(x) x[2]))
  names(content) <- unlist(lapply(tmp, function(x) x[1]))
  return(content)
}

repo_path <- Sys.getenv("SD_REPO_PATH", ".")
sd_version <- Sys.getenv("SD_STAGED_DEPENDENCIES_VERSION", "v0.2.7")
git_ref <- Sys.getenv("SD_GIT_REF")
threads <- Sys.getenv("SD_THREADS", "auto")
cran_repos <- Sys.getenv(
  "SD_CRAN_REPOSITORIES",
  "CRAN=https://cloud.r-project.org/"
)
cran_repos_biomarker <- Sys.getenv("SD_ENABLE_BIOMARKER_REPOSITORIES", "false")
token_mapping <- Sys.getenv(
  "SD_TOKEN_MAPPING",
  "https://github.com=GITHUB_PAT,https://gitlab.com=GITLAB_PAT"
)
check <- Sys.getenv("SD_ENABLE_CHECK", "true")

cat("\n==================================\n")
cat("Running staged dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat(paste("sd_version: \"", sd_version, "\"\n", sep = ""))
cat(paste("git_ref: \"", git_ref, "\"\n", sep = ""))
cat(paste("threads: \"", threads, "\"\n", sep = ""))
cat(paste("check: \"", check, "\"\n", sep = ""))
cat(paste("cran_repos: \"", cran_repos, "\"\n", sep = ""))
cat(paste("cran_repos_biomarker: \"", cran_repos_biomarker, "\"\n", sep = ""))
cat(paste("token_mapping: \"", token_mapping, "\"\n", sep = ""))
cat("==================================\n")

setwd(repo_path)

if (cran_repos_biomarker == "true") {
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

# Install and run staged.dependencies if config file exists
if (file.exists("staged_dependencies.yaml")) {
  cat("Install Staged Dependencies\n\n")
  if (!require("staged.dependencies")) {
    remotes::install_github(
      "openpharma/staged.dependencies",
      ref = sd_version,
      Ncpus = threads,
      upgrade = "never"
    )
  }

  # Read the DESCRIPTION file
  pkg_description <- desc::desc()

  # Get upstream repo names from staged.dependencies config
  upstream_repos <- names(
    staged.dependencies:::get_yaml_deps_info(".")$upstream_repos
  )

  if (pkg_description$has_fields("Remotes")) {
    # If there are remote dependencies that are also
    # specified in the staged.dependencies configuration,
    # then remove those from the DESCRIPTION file
    remote_deps <- pkg_description$get_remotes()
    # Remove versions from remotes
    remote_deps_sans_version <- gsub("@.*$", "", remote_deps)
    # Get setdiff of deps in SD configuration
    # and the Remotes field in DESCRIPTION file
    filtered_remotes <- setdiff(remote_deps_sans_version, upstream_repos)
    # Restore versions for the Remotes field
    if (length(filtered_remotes) > 0) {
      remotes_to_install <- c()
      for (remote in filtered_remotes) {
        remotes_to_install <- append(
          remotes_to_install,
          remote_deps[grep(remote, remote_deps, ignore.case = TRUE)]
        )
      }
      # Set cleaned up Remotes field
      pkg_description$set_remotes(remotes_to_install)
      pkg_description$write()
    }
  }
}

# Install dependencies from renv or via remotes::install_deps
if (file.exists("renv.lock")) {
  renv::restore()
} else {
  remotes::install_deps(dependencies = TRUE, upgrade = "never", Ncpus = threads)
}

# Get staged dependencies graph and install dependencies
if (file.exists("staged_dependencies.yaml")) {
  cat(paste(
    "\nCalculating Staged Dependency Table for ref: ", git_ref, "...\n\n"
  ))

  if (git_ref != "" && !startsWith(git_ref, "refs/pull")
    && !startsWith(git_ref, "refs/head")) {
    x <- staged.dependencies::dependency_table(ref = git_ref)
  } else {
    x <- staged.dependencies::dependency_table()
  }

  print(x, width = 120)
  cat("\n\n")

  if (check == "true") {
    cat("\nRunning check yaml consistent...\n\n")
    staged.dependencies::check_yamls_consistent(x, skip_if_missing_yaml = TRUE)
  }

  staged.dependencies::install_deps(
    dep_structure = x,
    install_project = FALSE,
    verbose = TRUE
  )
}

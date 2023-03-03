#!/usr/bin/env Rscript

split_to_map <- function(args) {
  tmp <- strsplit(x = unlist(strsplit(args, ",")), "=")
  content <- unlist(lapply(tmp, function(x) x[2]))
  names(content) <- unlist(lapply(tmp, function(x) x[1]))
  return(content)
}

git_user_name <- Sys.getenv("SD_GIT_USER_NAME", "github-actions[bot]")
git_user_email <- Sys.getenv(
  "SD_GIT_USER_EMAIL",
  "27856297+dependabot-preview[bot]@users.noreply.github.com"
)
repo_path <- Sys.getenv("SD_REPO_PATH", ".")
sd_version <- Sys.getenv("SD_STAGED_DEPENDENCIES_VERSION", "v0.2.7")
git_ref <- Sys.getenv("SD_GIT_REF")
threads <- Sys.getenv("SD_THREADS", "auto")
direction <- Sys.getenv("SD_DIRECTION", "all")
if (direction == "") direction <- "all"

cran_repos <- Sys.getenv(
  "SD_CRAN_REPOSITORIES",
  "CRAN=https://cloud.r-project.org/"
)
enable_bioc_repos <- Sys.getenv("SD_ENABLE_BIOC_REPOSITORIES", "false")
token_mapping <- Sys.getenv(
  "SD_TOKEN_MAPPING",
  "https://github.com=GITHUB_PAT,https://gitlab.com=GITLAB_PAT"
)
check <- Sys.getenv("SD_ENABLE_CHECK", "false")
renv_restore <- Sys.getenv("SD_RENV_RESTORE", "true")
sd_quiet <- isTRUE(as.logical(Sys.getenv("SD_QUIET", "true")))
upgrade_remotes <- isTRUE(as.logical(Sys.getenv("SD_UPGRADE_REMOTES", "false")))

cat("\n==================================\n")
cat("Running staged dependencies installer\n")
cat(paste("repo_path: \"", repo_path, "\"\n", sep = ""))
cat(paste("sd_version: \"", sd_version, "\"\n", sep = ""))
cat(paste("git_ref: \"", git_ref, "\"\n", sep = ""))
cat(paste("threads: \"", threads, "\"\n", sep = ""))
cat(paste("check: \"", check, "\"\n", sep = ""))
cat(paste("cran_repos: \"", cran_repos, "\"\n", sep = ""))
cat(paste("enable_bioc_repos: \"", enable_bioc_repos, "\"\n", sep = ""))
cat(paste("token_mapping: \"", token_mapping, "\"\n", sep = ""))
cat(paste("git_user_name: \"", git_user_name, "\"\n", sep = ""))
cat(paste("git_user_email: \"", git_user_email, "\"\n", sep = ""))
cat(paste("renv_restore: \"", renv_restore, "\"\n", sep = ""))
cat(paste("sd_quiet: \"", sd_quiet, "\"\n", sep = ""))
cat(paste("upgrade_remotes: \"", upgrade_remotes, "\"\n", sep = ""))
cat(paste("direction: \"", direction, "\"\n", sep = ""))
cat("==================================\n")

setwd(repo_path)

repos <- split_to_map(cran_repos)
if (enable_bioc_repos == "true") {
  repos <- c(split_to_map(cran_repos), BiocManager::repositories())
}

if (threads == "auto") {
  threads <- parallel::detectCores(all.tests = FALSE, logical = TRUE)
  cat(paste("Number of cores detected:", threads, "\n\n"))
}

# Install the remotes package
if (!require("remotes", quietly = sd_quiet)) {
  install.packages(
    "remotes",
    upgrade = "never",
    Ncpus = threads
  )
}

# Upgrade the remotes package to get the latest bugfixes
## TODO: Install directly from GitHub repository instead of
## using remotes. To precent the "Inception" effect
if (upgrade_remotes == "true") {
  remotes::install_github("r-lib/remotes@main")
  # Reload remotes
  require(remotes)
}

options(
  repos = repos,
  staged.dependencies.token_mapping = split_to_map(token_mapping)
)

# Install dependencies from renv
if (file.exists("renv.lock") && renv_restore == "true") {
  if (!require("renv", quietly = sd_quiet)) {
    install.packages(
      "renv",
      upgrade = "never",
      Ncpus = threads,
      quiet = sd_quiet
    )
  }
  renv::restore()
}

# Get staged dependencies graph and install dependencies
if (file.exists("staged_dependencies.yaml")) {
  install_sd <- FALSE
  if (!require("staged.dependencies", quietly = sd_quiet)) {
    install_sd <- TRUE
  }
  if (require("staged.dependencies", quietly = sd_quiet)) {
    if (paste0("v", packageVersion("staged.dependencies")) != sd_version) {
      install_sd <- TRUE
    }
  }
  if (install_sd) {
    cat("Installing Staged Dependencies\n\n")
    remotes::install_github(
      "openpharma/staged.dependencies",
      ref = sd_version,
      Ncpus = threads,
      upgrade = "never",
      force = TRUE,
      quiet = sd_quiet
    )
  }

  # git signature setup
  git2r::config(
    git2r::repository("."),
    user.name = git_user_email,
    user.email = git_user_email
  )

  cat(paste(
    "\nCalculating Staged Dependency Table for ref: ", git_ref, "...\n\n"
  ))

  if (git_ref != "" &&
    !startsWith(git_ref, "refs/pull") &&
    !startsWith(git_ref, "refs/head")) {
    x <- staged.dependencies::dependency_table(ref = git_ref, direction = direction)
  } else {
    x <- staged.dependencies::dependency_table(direction = direction)
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
    verbose = 1,
    install_external_deps = TRUE,
    upgrade = "never",
    Ncpus = threads,
    quiet = sd_quiet
  )
}

# Install any remaining dependencies
if (!file.exists("renv.lock") || renv_restore != "true") {
  remotes::install_deps(
    dependencies = TRUE,
    upgrade = "never",
    Ncpus = threads,
    quiet = sd_quiet
  )
}

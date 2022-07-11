# Staged-Dependencies-Action

Github Actions to implement R development stages for package development

The [staged.dependencies] package simplifies the development process for developing a set of
inter-dependent R packages. In each repository of the set of R packages you are co-developing you should
specify a `staged_dependencies.yaml` file containing *upstream* (i.e. those packages your current repo depends on) and
*downstream* (i.e. those packages which depend on your current repo's package) 
dependency packages within your development set of packages.

## Table of Contents

- [Staged-Dependencies-Action](#staged-dependencies-action)
  - [Table of Contents](#table-of-contents)
  - [How to use](#how-to-use)
  - [Usage Options](#usage-options)

## How to use

To use this GitHub Action you will need to complete the following:

1. Create `staged_dependencies.yaml` file with [this guide][structure-of-staged_dependenciesyaml-file]
2. Create a new file in your repository called `.github/workflows/r-check.yml`
3. Copy the example workflow from below into that new file, no extra configuration required
4. Commit that file to a new branch
5. Open up a pull request and observe the action working
6. Enjoy your more stable, and cleaner codebase

```yml
---
name: Check R package

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  check:
    runs-on: ubuntu-latest
    name: Check
    container:
      image: rocker/verse:4.1.0
    steps:
      - name: Checkout repo
        uses: actions/checkout@v2

      - name: Run Staged dependencies
        uses: insightsengineering/staged-dependencies-action@v1
        with:
          run-system-dependencies: true
        env:
          GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build R package
        run: |
          R CMD build ${{ github.event.repository.name }}
          echo "PKGBUILD=$(echo *.tar.gz)" >> $GITHUB_ENV
        shell: bash

      - name: Check R package
        run: R CMD check --no-manual ${{ env.PKGBUILD }}
        shell: bash

      - name: Install R package
        run: R CMD INSTALL ${{ env.PKGBUILD }}
        shell: bash
```

## Usage Options

The following options are available are available for this action:

| **Option** | **Default Value** | **Notes** |
| --- | --- | --- |
| **run-system-dependencies** | `false` | Check for and install system dependencies |

This action allows you to pass the following `ENV` variables to be able to trigger different functionality.

| **ENV VAR** | **Default Value** | **Notes** |
| ----------- | ----------------- | --------- |
| **SD_REPO_PATH** | `.` | path to the R package |
| **SD_STAGED_DEPENDENCIES_VERSION** | `v0.2.7` | version of [staged.dependencies] to use. Action is compatilble with `>=0.2.2` |
| **SD_THREADS** | `auto` | Number of threads that is use in `Ncpus` |
| **SD_CRAN_REPOSITORIES** | `CRAN=https://cloud.r-project.org/` | Map of cran option repos delimited by comma |
| **SD_ENABLE_BIOMARKER_REPOSITORIES** | `false` | Add `BiocManager::repositories()` to option repos |
| **SD_TOKEN_MAPPING** | `https://github.com=GITHUB_PAT,https://gitlab.com=GITLAB_PAT` | Token mapping that is used in `staged.dependencies.token_mapping` delimited by comma. Note that you will need to set these tokens with their respective values as environment variables while using this action |
| **SD_ENABLE_CHECK** | `true` | Run `check_yamls_consistent` before installation of dependencies |
| **SD_GIT_REF** | `${{ github.ref }}` | Git reference |
| **SD_GIT_USER_NAME** | `github-actions[bot]` | Git user.name configuration for fetching remote staged dependencies |
| **SD_GIT_USER_EMAIL** | `27856297+dependabot-preview[bot]@users.noreply.github.com` | Git user.email configuration for fetching remote staged dependencies |
| **SD_RENV_RESTORE** | `true` | Restore dependencies from `renv.lock`, if it exists |

[staged.dependencies]: https://github.com/openpharma/staged.dependencies
[structure-of-staged_dependenciesyaml-file]: https://github.com/openpharma/staged.dependencies#structure-of-staged_dependenciesyaml-file

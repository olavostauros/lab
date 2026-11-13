#!/usr/bin/env bats

load test_helper

@test "standard skeleton surfaces exist" {
  for path in \
    mise.toml \
    README.tsx \
    README.md \
    CONTRIBUTING.md \
    .mise/tasks/test \
    .mise/tasks/validate \
    .mise/tasks/doctor \
    .github/workflows/test.yml \
    lib/lab.sh \
    lib/lineage-names
  do
    [ -e "$REPO_DIR/$path" ]
  done
}

@test "public test task owns the complete BATS runner" {
  run grep -n '^exec bats ' "$REPO_DIR/.mise/tasks/test"
  [ "$status" -eq 0 ]
  [ ! -e "$REPO_DIR/libexec/test" ]
}

@test "Codebase uses the stable lab name and evolving all group" {
  run grep -n -x -F 'name = "lab"' "$REPO_DIR/mise.toml"
  [ "$status" -eq 0 ]

  run grep -n -x -F 'lint = ["@all"]' "$REPO_DIR/mise.toml"
  [ "$status" -eq 0 ]
}

@test "README.md is generated from README.tsx" {
  run bash -c 'cd "$REPO_DIR" && readme build --check'
  [ "$status" -eq 0 ]
}

@test "doctor is the product's lab check: the tool repo itself is not a lab" {
  require_lab_tasks doctor
  run lab doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a lab"* ]]
}

@test "public tasks provide examples through their real help" {
  while IFS= read -r task_file; do
    relative_path="${task_file#"$REPO_DIR/.mise/tasks/"}"
    task_name="${relative_path%/_default}"
    task_name="${task_name//\//:}"

    run lab "$task_name" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples:"* ]]
  done < <(find "$REPO_DIR/.mise/tasks" -type f -print | sort)
}

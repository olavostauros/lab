#!/usr/bin/env bats

load test_helper

@test "the shim's surface is init, doctor, version and agent add/home, plus the skeleton's test and validate; nothing is hidden" {
  require_lab_tasks init agent/add agent/home doctor version
  run bash -c "cd '$REPO_DIR' && mise tasks ls --json --hidden | jq -r 'sort_by(.name)[] | \"\\(.name) \\(.hide)\"'"
  assert_success
  [ "$output" = "agent:add false
agent:home false
doctor false
init false
test false
validate false
version false" ]
}

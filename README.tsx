/** @jsxImportSource jsx-md */

import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

import {
  Badge,
  Badges,
  Bold,
  Cell,
  Center,
  Code,
  CodeBlock,
  Details,
  HR,
  Heading,
  Item,
  LineBreak,
  Link,
  List,
  Paragraph,
  Raw,
  Section,
  Sub,
  Table,
  TableHead,
  TableRow,
} from "readme";

const PROJECT = {
  name: "lab",
  oneLine: "The starting point of a lab of agents.",
  tagline: "The rules, the roster, the queue and the checks — in place before the first agent wakes.",
  license: "MIT",
};

const REPO_DIR = resolve(import.meta.dirname);
const TASK_DIR = join(REPO_DIR, ".mise/tasks");
const TEST_DIR = join(REPO_DIR, "test");
const WORKFLOW = join(REPO_DIR, ".github/workflows/test.yml");

interface TaskInfo {
  name: string;
  description: string;
}

function read(path: string): string {
  return readFileSync(path, "utf8");
}

function walkFiles(dir: string, predicate: (path: string) => boolean): string[] {
  if (!existsSync(dir)) return [];

  const results: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(full, predicate));
    } else if (predicate(full)) {
      results.push(full);
    }
  }
  return results;
}

function discoverTasks(dir = TASK_DIR, prefix = ""): TaskInfo[] {
  if (!existsSync(dir)) return [];

  const tasks: TaskInfo[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;
    const full = join(dir, entry.name);
    const name = prefix ? `${prefix}:${entry.name}` : entry.name;

    if (entry.isDirectory()) {
      tasks.push(...discoverTasks(full, name));
      continue;
    }

    const mode = statSync(full).mode;
    if ((mode & 0o111) === 0) continue;

    const src = read(full);
    const description = src.match(/^#MISE description="(.+)"$/m)?.[1] ?? "";
    tasks.push({ name, description });
  }

  return tasks.sort((a, b) => a.name.localeCompare(b.name));
}

function countBatsTests(): number {
  return walkFiles(TEST_DIR, (path) => path.endsWith(".bats"))
    .map(read)
    .join("\n")
    .match(/@test\s+"/g)?.length ?? 0;
}

function configuredLints(): string[] {
  const miseToml = read(join(REPO_DIR, "mise.toml"));
  const start = miseToml.indexOf("[_.codebase]");
  if (start === -1) return [];

  const lines = miseToml.slice(start).split("\n");
  const block: string[] = [];
  for (const [index, line] of lines.entries()) {
    if (index > 0 && line.startsWith("[")) break;
    block.push(line);
  }

  const list = block.join("\n").match(/lint\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  return [...list.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function workflowOses(): string[] {
  if (!existsSync(WORKFLOW)) return [];
  const match = read(WORKFLOW).match(/os:\s*\[([^\]]+)\]/);
  if (!match) return [];
  return match[1].split(",").map((os) => os.trim()).filter(Boolean);
}

function status(path: string): string {
  return existsSync(join(REPO_DIR, path)) ? "✓" : "missing";
}

const tasks = discoverTasks();
const testCount = countBatsTests();
const lints = configuredLints();
const oses = workflowOses();

const scaffold = [
  ["mise.toml", "tools, settings, and codebase lint config"],
  ["README.tsx", "programmable README source"],
  ["CONTRIBUTING.md", "repo-entry orientation surface"],
  [".mise/tasks/test", "complete public BATS command workflow"],
  [".mise/tasks/validate", "aggregate validation, private logs, and final outcome"],
  [".mise/tasks/doctor", "local health check plus hook hint"],
  [".github/workflows/test.yml", "Ubuntu/macOS CI"],
  ["test/", "BATS smoke coverage"],
  ["lib/", "shared sourced code starts here when needed"],
];

const readme = (
  <>
    <Center>
      <Heading level={1}>{PROJECT.name}</Heading>

      <Paragraph>
        <Bold>{PROJECT.oneLine}</Bold>
      </Paragraph>

      <Paragraph>{PROJECT.tagline}</Paragraph>

      <Badges>
        <Badge label="shape" value="mise + BATS" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tests" value={`${testCount}`} color="brightgreen" href="test/" />
        <Badge label="lints" value={lints.join(" + ") || "none"} color="blue" />
        <Badge label="README" value="TSX" color="f472b6" />
        <Badge label="License" value={PROJECT.license} color="blue" href="LICENSE" />
      </Badges>
    </Center>

    <LineBreak />

    <Section title="What this is">
      <Paragraph>
        <Code>lab</Code>
        {" scaffolds a lab of agents — a contract, a roster, a work queue, a commit guard and a steward — under any agent harness or none. It runs on git, bash and "}
        <Code>mise</Code>
        {", and it is a rewrite of "}
        <Link href="https://github.com/olavostauros/lab_old">lab_old</Link>
        {" on the "}
        <Link href="https://github.com/KnickKnackLabs/trahmpolina">KnickKnackLabs skeleton</Link>
        {": mise-managed tasks, parallel BATS tests, codebase convention lints, generated README, and CI."}
      </Paragraph>

      <Paragraph>
        {"The rewrite is in progress. "}
        <Link href="AGENTS.md"><Code>AGENTS.md</Code></Link>
        {" is the product contract — what a change must preserve — and the commands land as they port from lab_old."}
      </Paragraph>
    </Section>

    <Section title="Quick start">
      <CodeBlock lang="bash">{`gh repo clone olavostauros/lab
cd lab

mise trust
mise install
mise run validate
mise run doctor

# Optional local safety net: installs .git/hooks/pre-commit.d/codebase
codebase pre-commit`}</CodeBlock>
    </Section>

    <Section title="Goodies baked in">
      <Table>
        <TableHead>
          <Cell>Goodie</Cell>
          <Cell>Why it exists</Cell>
          <Cell>Where</Cell>
        </TableHead>
        <TableRow>
          <Cell>Generated README</Cell>
          <Cell>TSX can count tests, list tasks, and keep docs honest in CI.</Cell>
          <Cell><Code>README.tsx</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Doctor hook check</Cell>
          <Cell>Local pre-commit hooks are clone-local, so the repo can report them without pretending they are tracked.</Cell>
          <Cell><Code>mise run doctor</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Convention lints</Cell>
          <Cell>Best-practice drift gets caught as code, not folklore.</Cell>
          <Cell><Code>[_.codebase].lint</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Real test path</Cell>
          <Cell>BATS tests call tasks through <Code>mise run</Code>, not raw scripts.</Cell>
          <Cell><Code>test/test_helper.bash</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Public test workflow</Cell>
          <Cell>The complete BATS runner stays visible and testable at the public task boundary.</Cell>
          <Cell><Code>.mise/tasks/test</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Reference validation workflow</Cell>
          <Cell>One gate owns explicit check ordering, private evidence, interruption, and the final verdict. Local and CI use the same path.</Cell>
          <Cell><Code>.mise/tasks/validate</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Parallel BATS</Cell>
          <Cell>The KKL Bats fork and Rush schedule isolated tests concurrently across and within files.</Cell>
          <Cell><Code>.mise/tasks/test</Code></Cell>
        </TableRow>
        <TableRow>
          <Cell>Mac + Linux CI</Cell>
          <Cell>Bash and tooling differences show up before merge.</Cell>
          <Cell>{oses.join(" + ") || "workflow pending"}</Cell>
        </TableRow>
      </Table>
    </Section>

    <Section title="Scaffold inventory">
      <Table>
        <TableHead>
          <Cell>Path</Cell>
          <Cell>Status</Cell>
          <Cell>Purpose</Cell>
        </TableHead>
        {scaffold.map(([path, purpose]) => (
          <TableRow>
            <Cell><Code>{path}</Code></Cell>
            <Cell>{status(path)}</Cell>
            <Cell>{purpose}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="Tasks">
      <Table>
        <TableHead>
          <Cell>Task</Cell>
          <Cell>Description</Cell>
        </TableHead>
        {tasks.map((task) => (
          <TableRow>
            <Cell><Code>{`mise run ${task.name}`}</Code></Cell>
            <Cell>{task.description}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="Parallel tests">
      <Paragraph>
        {"The canonical test task uses the "}
        <Link href="https://github.com/KnickKnackLabs/bats-core">KKL-maintained Bats fork</Link>
        {" with "}
        <Link href="https://github.com/shenwei356/rush">Rush</Link>
        {" and a measured four-job default. Isolated tests can run concurrently across separate files and within one file."}
      </Paragraph>
      <CodeBlock lang="bash">{`mise run test                         # measured four-job default
mise run test --jobs 4                # explicit job count
BATS_NUMBER_OF_PARALLEL_JOBS=2 mise run test
mise run test --jobs 1                # serial debugging`}</CodeBlock>
      <Paragraph>
        {"Parallel suites must isolate mutable state per test and process. Use "}
        <Code>$BATS_TEST_TMPDIR</Code>
        {", unique ports, and fixture-local repositories instead of shared files, services, HOME overrides, or repository mutations."}
      </Paragraph>
    </Section>

    <Section title="Skeleton conventions">
      <List ordered>
        <Item>Rewrite this README around the actual tool as it grows, keeping the dynamic counters if they help.</Item>
        <Item>Keep the complete test runner in <Code>.mise/tasks/test</Code> so the public task is the tested workflow.</Item>
        <Item>Keep other public <Code>.mise/tasks</Code> readable and command-shaped; extract sourced Bash under <Code>lib/</Code> only when multiple commands share one domain contract.</Item>
        <Item>If the installed tool resolves caller-relative paths, read the shiv-provided <Code>{"<PACKAGE>_CALLER_PWD"}</Code> variable, not generic <Code>CALLER_PWD</Code>.</Item>
        <Item>Keep parallel tests isolated per test/process, or opt the suite into serial execution until shared state is removed.</Item>
        <Item>Preserve the <Link href="CONTRIBUTING.md#reference-validation-workflow">validation ownership and evidence contracts</Link> when adding checks, dependencies, or shared writes.</Item>
      </List>
    </Section>

    <Details summary="Current convention checks">
      <Paragraph>
        {"This repo currently asks "}
        <Link href="https://github.com/KnickKnackLabs/codebase">codebase</Link>
        {" to run these lint rules:"}
      </Paragraph>
      <CodeBlock>{lints.join("\n")}</CodeBlock>
    </Details>

    <Section title="Validation">
      <CodeBlock lang="bash">{`mise run validate                      # compact results, private full logs
mise run validate --verbose            # full output for ephemeral CI
BATS_NUMBER_OF_PARALLEL_JOBS=1 mise run validate`}</CodeBlock>

      <Paragraph>
        {"The gate runs tests, Codebase lint, generated-README verification, and whitespace checks. Those checks are independent and run serially; BATS/Rush still owns test parallelism. A failed check does not suppress its independent peers. Interruption stops later checks and contains the active process group."}
      </Paragraph>
      <Paragraph>
        {"Every invocation prints its private log directory and one timed result per check. Full logs, command arguments, and per-check receipts remain there; failures include a bounded excerpt. The final "}
        <Code>report.tsv</Code>
        {" distinguishes passing checks from the whole-run outcome after cleanup. A partial run or cleanup failure cannot report overall success. Logs are private, not redacted; remove them when no longer needed."}
      </Paragraph>
      <Paragraph>
        {"CI calls the same gate with "}<Code>--verbose</Code>
        {" so detailed failures survive in its masked job log. The explicit "}
        <Code>ci_lint_gate</Code>
        {" declaration tells Codebase that this tested aggregate owns lint; it is not automatic inspection of the task. Read the "}
        <Link href="CONTRIBUTING.md#reference-validation-workflow">adoption guide</Link>
        {" for the report format, prerequisite example, concurrency ownership, process-group limits, and when shared writes require an exclusion boundary. The individual commands remain available for focused checks."}
      </Paragraph>

      <Paragraph>
        {"The starter suite currently has "}
        <Bold>{`${testCount} tests`}</Bold>
        {" and "}
        <Bold>{`${tasks.length} public tasks`}</Bold>
        {". Those numbers are read from the repo at README build time."}
      </Paragraph>
    </Section>

    <Center>
      <HR />
      <Sub>
        {"This README was generated from "}
        <Code>README.tsx</Code>
        {" with "}
        <Link href="https://github.com/KnickKnackLabs/readme">KnickKnackLabs/readme</Link>
        {"."}
        <Raw>{"<br />"}</Raw>
        {"A skeleton is a kindness to whoever has to remember the boring parts tomorrow."}
      </Sub>
    </Center>
  </>
);

console.log(readme);

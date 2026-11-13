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

const tasks = discoverTasks();
const testCount = countBatsTests();
const lints = configuredLints();
const oses = workflowOses();

const emitted = [
  ["AGENTS.md", "the contract: what the lab is, who owns it, the roster, how the owner merges, the three rules that protect the guard and the shared checkout, a Domain rules section, the tiers, the loosenings table, the two-key rule, the Read-first table"],
  [".agents/roster.tsv", "who counts as an agent, with role, owned directory and kind — read by the guard, agent-env, welcome and doctor; the steward is its first row"],
  [".agents/notes/work-queue.md", "the owner files entries here, each addressed to one agent"],
  [".agents/notes/lab-backlog.md", "Tier 2 proposals; empty"],
  [".agents/notes/lab-style.md", "how the lab likes its work done — wired to Read-first; practice, not authority, and the owner's to change"],
  [".agents/notes/steward.md", "the steward's identity note; its home is .agents/notes/steward-home.md"],
  [".agents/hooks/agent-identity", "pre-commit guard: refuses an author not on the roster unless <LAB>_OWNER_COMMIT=1"],
  [".agents/tasks/{welcome,test,agent-env,install-hooks}", "the task surface; agent-env sets <name>@<lab>.invalid as the git author — a label on a reserved name that claims no domain — or, with LAB_GH_EMAIL set in mise.toml, an address GitHub attributes to the owner"],
  [".agents/test/*.bats", "the lab's own checks, roster-driven so they stay true as agents join"],
  [".agents/secrets/", "granted credentials, git-ignored and machine-local: each <name>/ holds an age identity and a secrets sops vault"],
  ["notes/ at the work root", "the product's written memory — docs under notes/docs/, numbered decisions under notes/decisions/, learned facts flat; shared and append-only, and never .agents/notes/, which stays the lab's"],
  ["mise.toml, README.md, .gitignore", "the rest; the README carries the one line of attribution a lab keeps, Started from lab on <date>, at <version> — the version lab version printed when the lab was made, which lab doctor reads back against the version checking it"],
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
        {"For anyone who runs a roster of agents against a repository — under any agent harness, or none — and wants the rules, the roster, the queue and the checks in place before the first agent wakes. It runs on git, bash and "}
        <Code>mise</Code>
        {", and it is a rewrite of "}
        <Link href="https://github.com/olavostauros/lab_old">lab_old</Link>
        {" on the "}
        <Link href="https://github.com/KnickKnackLabs/trahmpolina">KnickKnackLabs skeleton</Link>
        {": mise-managed tasks, parallel BATS tests, codebase convention lints, a generated README, and CI on "}
        {oses.join(" + ") || "CI"}.
      </Paragraph>

      <Paragraph>
        {"A "}
        <Bold>lab</Bold>
        {" is a directory where a roster of agents wake, read their rules, take work from a queue, and return. "}
        <Code>lab init</Code>
        {" gives you one, complete: a contract that says what an agent may do without asking and what only you decide, a roster, a work queue, a lab style, a commit guard that refuses an author who is not on the roster, a steward that keeps the record true, and a set of checks. "}
        <Code>lab agent add</Code>
        {" puts an agent on it, and "}
        <Code>lab doctor</Code>
        {" measures the lab against the shape every lab shares. The command is "}
        <Code>lab</Code>.
      </Paragraph>

      <Paragraph>
        {"lab is "}
        <Link href="LICENSE">MIT-licensed</Link>
        {". A lab it writes belongs to whoever generated it and is not bound by the framework's license."}
      </Paragraph>

      <Paragraph>
        {"A lab does not depend on any agent harness. Everything it generates is markdown, bash, git and "}
        <Code>mise</Code>
        {"; what a runner needs is already in the roster and in each agent's home, and the runner's own files are written outside the lab, by you."}
      </Paragraph>

      <Paragraph>
        {"The framework asserts, and a fresh lab is complete. There is no menu of styles, packages or rule sets to choose from, and no question left in the contract for you to answer: the shape and the opinions are the framework's, and what you supply is facts — a name, a project, an owner, a roster — and, later, dated widenings in the contract. "}
        <Code>lab doctor</Code>
        {" calls the lab healthy on the day it is made. "}
        <Code>.agents/notes/</Code>
        {" encrypts at rest from the first commit — readable in an unlocked checkout, opaque in git. Each larger capability — per-agent accounts and keys, mail, chat, CI wakes — is yours to file and switch on, in your own turn."}
      </Paragraph>
    </Section>

    <Section title="Prerequisites">
      <Paragraph>{"To run "}<Code>lab</Code>{":"}</Paragraph>
      <List>
        <Item>bash 4 or newer, first on <Code>PATH</Code></Item>
        <Item>
          <Link href="https://git-scm.com">git</Link>
          {" 2.28 or newer, with "}
          <Code>user.name</Code>
          {" and "}
          <Code>user.email</Code>
          {" set: "}
          <Code>lab init</Code>
          {" makes a bootstrap commit"}
        </Item>
        <Item>
          {"curl, jq, CA certificates for HTTPS, and "}
          <Code>sha256sum</Code>
          {" or "}
          <Code>shasum</Code>
          {": shiv's installer refuses without curl, git and jq; mise's installer checks its download with a sha tool; the "}
          <Code>lab</Code>
          {" shim resolves "}
          <Code>lab agent add</Code>
          {" to "}
          <Code>agent:add</Code>
          {" through jq"}
        </Item>
        <Item>
          <Link href="https://github.com/KnickKnackLabs/shiv">shiv</Link>
          {", which installs "}
          <Link href="https://mise.jdx.dev">mise</Link>
          {" if it is absent; mise runs every "}
          <Code>lab</Code>
          {" command, and "}
          <Code>mise install</Code>
          {" in the clone brings the tools "}
          <Code>mise.toml</Code>
          {" pins"}
        </Item>
      </List>
      <Paragraph>
        {"To live in a lab: git, bash and mise. A generated lab's own tasks never call shiv, and "}
        <Code>lab doctor</Code>
        {" checks the list above — the bash and git versions, the git identity, mise and jq on "}
        <Code>PATH</Code>
        {" — and prints the fix for each line it fails. An agent the owner has given an account also needs "}
        <Link href="https://github.com/KnickKnackLabs/secrets">secrets</Link>
        {" and "}
        <Link href="https://github.com/getsops/sops">sops</Link>
        {" on "}
        <Code>PATH</Code>
        {"; "}
        <Code>doctor</Code>
        {" says so when the grant is there and the tools are not, and asks for neither otherwise."}
      </Paragraph>
    </Section>

    <Section title="Install">
      <CodeBlock lang="bash">{`curl -fsSL shiv.knacklabs.co/install.sh | bash   # installs mise too, if absent
mkdir -p ~/.config/shiv/sources                  # source file: see below
echo '{"lab": "olavostauros/lab"}' > ~/.config/shiv/sources/lab.json
MISE_JOBS=1 shiv install lab                   # serial: see below
lab --version`}</CodeBlock>

      <Paragraph>
        {"Restart the shell once after the first line: the installer adds a line to your shell rc and needs it. The source file is needed until "}
        <Code>lab</Code>
        {" is in shiv's own index ("}
        <Link href="https://github.com/KnickKnackLabs/shiv/pull/176">KnickKnackLabs/shiv#176</Link>
        {" is the request): without it, "}
        <Code>shiv install lab</Code>
        {" stops at "}
        <Code>'lab' not found in package index</Code>
        {". Once that merges, the two source-file lines go; a fork under another name stays the same one line away from being installable as "}
        <Code>lab</Code>
        {" for its owner."}
      </Paragraph>

      <Paragraph>
        {"Bare "}
        <Code>shiv install lab</Code>
        {" takes the newest release tag; "}
        <Code>shiv install lab@main</Code>
        {" tracks "}
        <Code>main</Code>
        {", "}
        <Code>shiv install lab@v0.1.0</Code>
        {" pins, and "}
        <Code>shiv update lab</Code>
        {" moves an install to the newest release. "}
        <Code>lab --version</Code>
        {" is what a bug report quotes: the tag at the install's "}
        <Code>HEAD</Code>
        {", else its short commit, then the branch and the age of the last commit. "}
        <Code>lab version</Code>
        {" is the same tag or short commit from the inside, and it is what a lab records when it is made."}
      </Paragraph>

      <Paragraph>
        {"Three things to know about the chain before running it. The installer "}
        <Code>eval</Code>
        {"s a terminal-UI library fetched over the network at run time, and falls back silently when the fetch fails. The installer does not install shiv's own tools; the first "}
        <Code>shiv</Code>
        {" command does, and two of them ("}
        <Code>shiv:codebase</Code>
        {", "}
        <Code>shiv:readme</Code>
        {") race on the backend's clone when mise installs them side by side ("}
        <Link href="https://github.com/KnickKnackLabs/vfox-shiv/issues/22">KnickKnackLabs/vfox-shiv#22</Link>
        {"), which on a clean machine fails every time — "}
        <Code>MISE_JOBS=1</Code>
        {" on that first command serializes them. And those two are floating "}
        <Code>shiv:</Code>
        {" ranges in shiv's own "}
        <Code>mise.toml</Code>
        {"; they are shiv's, not a lab's, and "}
        <Code>doctor</Code>
        {" does not read them."}
      </Paragraph>

      <Heading level={3}>From a checkout</Heading>
      <CodeBlock lang="bash">{`git clone https://github.com/olavostauros/lab
cd lab && mise trust && mise install`}</CodeBlock>
      <Paragraph>
        <Code>mise trust</Code>
        {" is asked once, because "}
        <Code>mise.toml</Code>
        {" sets tool and task settings for this directory. Every "}
        <Code>lab</Code>
        {" command in this README is a "}
        <Code>mise run</Code>
        {" task of this checkout ("}
        <Code>lab init</Code>
        {" is "}
        <Code>mise run init</Code>
        {", "}
        <Code>lab agent add</Code>
        {" is "}
        <Code>mise run agent:add</Code>
        {", "}
        <Code>lab version</Code>
        {" is "}
        <Code>mise run version</Code>
        {"), which is how CI runs it:"}
      </Paragraph>
      <CodeBlock lang="bash">{`mise run init example --at /path/to/example`}</CodeBlock>
      <Paragraph>
        {"To put a working clone on "}
        <Code>PATH</Code>
        {" as "}
        <Code>lab</Code>
        {" — the way to try the shim against a branch — register the checkout itself as a local-path package:"}
      </Paragraph>
      <CodeBlock lang="bash">{`shiv install lab "$PWD"`}</CodeBlock>
    </Section>

    <Section title="Quick start">
      <Paragraph>
        {"Run "}
        <Code>lab init</Code>
        {" with no name and it asks for each fact it needs — where the lab lives, its name, its owner — scaffolds, then offers the roster, the hooks and a first check. Given a name it asks nothing: the flags are the same facts, and CI never sees a prompt."}
      </Paragraph>
      <CodeBlock lang="bash">{`# A lab inside the project it works on — AGENTS.md + .agents/ at the repo root
cd ~/project && lab init example --embedded

# A lab that is a repo of its own and works on other repos
lab init example --at ~/example --owner 'Your Name'

cd ~/project
lab agent add builder --role implementation --owns src/ \
  --charge 'Builds what the queue asks for, under src/.'
lab agent add judge --role review \
  --charge 'Reads every pull request into main before the owner merges it.'

mise run install-hooks
mise run welcome
lab doctor            # healthy`}</CodeBlock>

      <Paragraph>
        <Code>--owner</Code>
        {" defaults to "}
        <Code>git config user.name</Code>
        {", and "}
        <Code>init</Code>
        {" fails when neither names anyone: the owner's name is the one fact only the owner can supply."}
      </Paragraph>

      <Paragraph>
        <Code>--embedded</Code>
        {" with no "}
        <Code>--at</Code>
        {" puts the lab at the project repo's root — "}
        <Code>AGENTS.md</Code>
        {" beside the project's own files and "}
        <Code>.agents/</Code>
        {" holding the roster, notes, guard and tasks. An existing "}
        <Code>AGENTS.md</Code>
        {", "}
        <Code>mise.toml</Code>
        {" or "}
        <Code>.gitignore</Code>
        {" is kept, never overwritten: "}
        <Code>init</Code>
        {" prints what to merge (the markers, the env block, the "}
        <Code>.agents/secrets/</Code>
        {" ignore) and "}
        <Code>lab doctor</Code>
        {" fails until it is in. The lab's name is "}
        <Code>LAB_NAME</Code>
        {" in its "}
        <Code>mise.toml</Code>
        {", never the directory's; "}
        <Code>--at</Code>
        {" still takes any path inside the repo."}
      </Paragraph>

      <Paragraph>
        {"Where the shape came from is history, kept in git and nowhere in the tree: the bootstrap commit names the labs it was distilled from, and "}
        <Code>lib/lineage-names</Code>
        {" lists them only so "}
        <Code>doctor</Code>
        {" can reject them in a lab."}
      </Paragraph>
    </Section>

    <Section title="What init writes">
      <Table>
        <TableHead>
          <Cell>Path</Cell>
          <Cell>What it is</Cell>
        </TableHead>
        {emitted.map(([path, what]) => (
          <TableRow>
            <Cell><Code>{path}</Code></Cell>
            <Cell>{what}</Cell>
          </TableRow>
        ))}
      </Table>
      <Paragraph>
        {"A standalone lab gets its own repo and a bootstrap commit, which is where the framework's name goes. An embedded lab is a directory of the project repo; you commit it as the owner, and "}
        <Code>notes/</Code>
        {" lands at that repo's root rather than inside the lab."}
      </Paragraph>
    </Section>

    <Section title="What is yours">
      <Paragraph>
        {"The facts: the lab's name and path, the project and the owner, given to "}
        <Code>init</Code>
        {". The roster, and each agent's role, directory and charge, given to "}
        <Code>agent add</Code>
        {". The loosenings table, one dated row at a time, in your own turn. A granted account, as a row in that table and two files in "}
        <Code>.agents/secrets/&lt;name&gt;/</Code>
        {": an age identity you mint and a "}
        <Code>secrets</Code>
        {" sops vault. A lighter attribution needs no account: set "}
        <Code>LAB_GH_EMAIL</Code>
        {" in the lab's "}
        <Code>mise.toml</Code>
        {" to an address GitHub attributes to you — your "}
        <Code>users.noreply.github.com</Code>
        {" address works — and "}
        <Code>agent-env</Code>
        {" stamps it, so every commit still names its agent and links to your account. Everything under "}
        <Code>.agents/notes/</Code>
        {", including the lab style and each agent's Stance, which the framework writes and you may change. The contract itself is Tier 2 for every agent and yours alone to edit."}
      </Paragraph>

      <Paragraph>
        {"What is not yours is the shape: the tiers, the two-key rule, the markers, the guard, one steward. "}
        <Code>lab doctor</Code>
        {" checks that shape, and it also fails on a leftover "}
        <Code>{"{{KEY}}"}</Code>
        {" or on the name of a lab the framework grew out of (the list is "}
        <Code>lib/lineage-names</Code>
        {"; "}
        <Code>KnickKnackLabs</Code>
        {" outside the tool pin is added), because those are the framework's leftovers and never your text. The lab's own name and project are never counted, so a lab that happens to share a name with one of those passes. Where an identity file sits under an agent's workspace, "}
        <Code>doctor</Code>
        {" also checks what "}
        <Code>secrets</Code>
        {" will check before an activation can fail on it — the directory and both files owner-only, one age key, a recipient line — proves the identity opens the vault with one "}
        <Code>secrets list</Code>
        {", and fails any such file under the steward's workspace. Without the file it says nothing."}
      </Paragraph>

      <Paragraph>
        {"If your git config signs commits, "}
        <Code>init</Code>
        {" says so and names the key before the passphrase prompt can appear, and "}
        <Code>--no-commit</Code>
        {" avoids it. Every lab's "}
        <Code>mise run welcome</Code>
        {" reports the same state, and the lab README's "}
        <Bold>Signing</Bold>
        {" section says what a signing machine means for the agents: their commits carry the owner's key, and a stalled prompt is reported, never worked around."}
      </Paragraph>
    </Section>

    <Section title="The steward">
      <Paragraph>
        {"Every lab has exactly one, and it is always named "}
        <Code>steward</Code>
        {". "}
        <Code>init</Code>
        {" adds it; a second one, or one under another name, is refused by "}
        <Code>agent add</Code>
        {" and failed by "}
        <Code>doctor</Code>
        {". Its work is standing and needs no filing: it measures the queue, the backlog, the notes, the roster and the branches against what is on disk, fixes verified-false facts in "}
        <Code>.agents/notes/</Code>
        {" on a local branch, files everything else as a backlog proposal, and reports to the owner in the session."}
      </Paragraph>
      <Paragraph>
        {"The steward is the lab speaking, so its identity is the lab's. Its home note is "}
        <Code>.agents/notes/steward-home.md</Code>
        {" — an encrypted note like every agent's — and a runner's definition for it, where one exists, is named after the lab."}
      </Paragraph>
      <Paragraph>
        {"It carries "}
        <Bold>no GitHub account, no signing key and no mail, permanently.</Bold>
        {" Its note and its home say so, and the contract excludes it from any identity entry the owner files for the other agents. It reads GitHub through the owner's login and writes nothing there; it pushes nothing. The record can be trusted because the one agent whose job is the record has no voice outside the lab."}
      </Paragraph>
    </Section>

    <Section title="What agent add writes">
      <List>
        <Item>
          {"a row on "}
          <Code>.agents/roster.tsv</Code>
          {": name, role, owned directory, kind"}
        </Item>
        <Item>
          <Code>.agents/notes/&lt;name&gt;.md</Code>
          {", the lab-visible identity, with a Stance the framework writes for the kind — narrowing it is the agent's, widening it is yours"}
        </Item>
        <Item>a bullet under "Who lives here" and a row in the Read-first table</Item>
        <Item>
          <Code>.agents/notes/&lt;name&gt;-home.md</Code>
          {" and "}
          <Code>.agents/notes/&lt;name&gt;-scratchpad.md</Code>
          {" — the agent's own startup contract and session memory, encrypted at rest with the rest of the notes; "}
          <Code>lab agent home &lt;name&gt;</Code>
          {" rebuilds them if they are ever lost"}
        </Item>
      </List>
      <Paragraph>
        {"Three kinds, and the kind is derived. "}
        <Code>--owns &lt;dir&gt;/</Code>
        {" makes a "}
        <Bold>builder</Bold>
        {": takes queue entries, works on "}
        <Code>&lt;name&gt;/&lt;topic&gt;</Code>
        {" branches under its directory, opens PRs, may edit and write. Without "}
        <Code>--owns</Code>
        {" it is a "}
        <Bold>judge</Bold>
        {": owns nothing, answers in the written record, reads and researches but never patches. The name "}
        <Code>steward</Code>
        {" makes the one above. Whatever the kind, the owner merges and the owner files the queue."}
      </Paragraph>
    </Section>

    <Section title="Domain rules">
      <Paragraph>
        {"A rule set binds one named agent: five or six lines the code can be checked against, in the contract's \"Domain rules\" section. That section says when to write one — when an agent's mistakes would be permanent or expensive — and the shape it takes, and you write it there, in your own turn. The framework ships none: it does not know your domain."}
      </Paragraph>
    </Section>

    <Section title="Harnesses">
      <Paragraph>
        {"Nothing above knows which runner the agents wake under, and no generated file names one. What a runner needs is already in the lab: "}
        <Code>.agents/roster.tsv</Code>
        {" (name, role, owned directory, kind), each home's "}
        <Code>AGENTS.md</Code>
        {" as the agent's brief, and the rule that the steward's file is named after the lab. A runner's definition is a projection of those, written outside the lab by you, in your own turn; the lab contract makes every such definition Tier 2, and nothing in this repository writes one. The framework names no runner."}
      </Paragraph>
    </Section>

    <Section title="Invariants">
      <Paragraph>{"These hold in every lab, and "}<Code>lab doctor</Code>{" checks the ones a script can:"}</Paragraph>
      <List>
        <Item>
          <Bold>The contract is authority-only</Bold>
          {" and enumerated once. Tiers, loosenings and the owner-only list live in "}
          <Code>AGENTS.md</Code>
          {" and nowhere else; definitions, homes and notes link to them and never restate them."}
        </Item>
        <Item>
          <Bold>Narrowing is the agent's; widening is the owner's</Bold>
          {", in the owner's own turn, as a dated row in the loosenings table."}
        </Item>
        <Item>
          <Bold>Relayed approval is not approval.</Bold>
          {" Only the owner's turn or a permission prompt is consent."}
        </Item>
        <Item>
          <Bold>Nobody merges but the owner</Bold>
          {", until a loosening says otherwise."}
        </Item>
        <Item>
          <Bold>The roster is one file</Bold>
          {", and the guard fails closed without it."}
        </Item>
        <Item>
          <Bold>Homes are the agent's boundary</Bold>
          {", not the lab's: "}
          <Code>agent add</Code>
          {" creates them once and never overwrites them."}
        </Item>
        <Item>
          <Bold>The lab is harness-agnostic.</Bold>
          {" "}
          <Code>init</Code>
          {", "}
          <Code>agent add</Code>
          {" and "}
          <Code>doctor</Code>
          {" never read or write a runner's files."}
        </Item>
        <Item>
          <Bold>There is one steward, named steward, homed at .agents/notes/steward-home.md.</Bold>
          {" It has no outward identity, and no upgrade path gives it one."}
        </Item>
        <Item>
          <Bold>A fresh lab is complete.</Bold>
          {" The framework asserts; the owner supplies facts and grants widenings. "}
          <Code>lab init x && lab doctor --lab x</Code>
          {" exits 0, and no generated file names a lineage or a runner, or depends on a toolchain outside the "}
          <Code>bats</Code>
          {" pin."}
        </Item>
      </List>
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
      <Paragraph>
        {"Every public task is also a shim command — "}
        <Code>lab init</Code>
        {", "}
        <Code>lab doctor</Code>
        {", "}
        <Code>lab version</Code>
        {", "}
        <Code>lab agent add</Code>
        {", "}
        <Code>lab agent home</Code>
        {", "}
        <Code>lab test</Code>
        {", "}
        <Code>lab validate</Code>
        {" — and nothing is hidden; the shim resolves "}
        <Code>agent add</Code>
        {" to "}
        <Code>agent:add</Code>
        {" through jq."}
      </Paragraph>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`mise trust
mise install
mise run validate      # tests, codebase lint, generated-README check, whitespace
mise run test          # parallel BATS only, for focused runs
readme build           # regenerate README.md after editing README.tsx
mise run version       # what a lab made from this checkout records
git diff --check`}</CodeBlock>

      <Paragraph>
        {"The tests scaffold labs into temporary directories — homes included — and "}
        <Code>LAB_DEFINITIONS_DIR</Code>
        {" points at an empty directory they assert stays empty: nothing here writes a runner's files. Nothing under your home is touched."}
      </Paragraph>

      <Paragraph>
        {"The canonical test task uses the "}
        <Link href="https://github.com/KnickKnackLabs/bats-core">KKL-maintained Bats fork</Link>
        {" with "}
        <Link href="https://github.com/shenwei356/rush">Rush</Link>
        {" and a measured four-job default. Isolated tests can run concurrently across separate files and within one file:"}
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

      <Paragraph>
        {"How a release is cut and how to propose a change is in "}
        <Link href="CONTRIBUTING.md">CONTRIBUTING.md</Link>
        {"; what a change must preserve is in "}
        <Link href="AGENTS.md">AGENTS.md</Link>
        {"."}
      </Paragraph>
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
        {"The suite currently has "}
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

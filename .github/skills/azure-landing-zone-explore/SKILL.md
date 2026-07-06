---
name: azure-landing-zone-explore
description: "Explore Azure Landing Zone repositories end-to-end. Use when you need repo mapping, architecture orientation, one-by-one study plans, Terraform/Bicep path decisions, dependency tracing, risk spotting, and where-to-change guidance across ALZ ecosystem repos."
argument-hint: "goal=<question>, mode=<overview|one-by-one|impact>, track=<terraform|bicep|mixed>, depth=<quick|medium|thorough>, start=<repo-name>"
user-invocable: true
---

# Azure Landing Zone Explore

## Outcome
Produce a clear, evidence-based exploration of ALZ ecosystem repositories so the user can:
- understand how repos relate to each other
- choose the right learning order
- deep-dive one repo at a time
- identify safe change points and test impact

Use repo groups from [ALZ repo groups](./references/repo-groups.md) and the per-repo format in [study template](./references/study-template.md).

## When To Use
Use this skill when the user asks to:
- explore ALZ related repos
- understand relationships across Terraform, Bicep, accelerator, governance, and tooling repos
- study repos one by one with guided outputs
- decide what repo to learn first based on their track

Do not use this skill for:
- implementing code changes directly (switch to normal coding flow after exploration)
- non-ALZ ecosystems with no shared repo graph

## Inputs
Accept natural language or structured args:
- `goal`: what to discover
- `mode`: `overview`, `one-by-one`, or `impact`
- `track`: `terraform`, `bicep`, or `mixed`
- `depth`: `quick`, `medium`, or `thorough`
- `start`: repo name to begin with

Defaults:
- `mode=one-by-one`
- `track=mixed`
- `depth=medium`
- `start=Azure-Landing-Zones`

## Procedure
1. Frame scope and assumptions.
- Restate goal in one sentence.
- Confirm mode, track, and depth (infer defaults if missing).
- If repo list is provided, map it to known groups.

2. Build repository graph.
- Classify repos into foundation, orchestration, implementation, CI/CD, governance, utilities, and samples.
- Identify handoff edges between groups.
- Separate confirmed relationships from assumptions.

3. Branch by mode.
- `overview`: provide grouped map + recommended order + key decisions.
- `one-by-one`: generate a single focused study doc for the current repo using the standard template.
- `impact`: trace change impact from a target repo to downstream repos/tests.

4. Branch by track.
- `terraform`: prioritize Azure-Landing-Zones -> Azure-Landing-Zones-Library -> ALZ-PowerShell-Module -> alz-terraform-accelerator -> AVM Terraform repos -> vending -> CI/CD.
- `bicep`: prioritize Azure-Landing-Zones -> Azure-Landing-Zones-Library -> ALZ-PowerShell-Module -> alz-bicep-accelerator -> ALZ-Bicep -> bicep-lz-vending -> CI/CD.
- `mixed`: deliver two parallel orders and highlight divergence points.

5. Handle private or inaccessible repos explicitly.
- If a repo is private or access is unavailable, keep a placeholder section for that repo.
- Include: known purpose, expected interfaces, what to verify when access is granted.
- Provide a substitute study path using nearest public repos until access is available.

6. For one-by-one mode, produce the repo study artifact.
- Use the exact section order from [study template](./references/study-template.md).
- Include one relationship diagram and one input/process/output flow.
- Add a 60-90 minute task list and pass/fail self-check.
- Output exactly one repo document per response in one-by-one mode.

7. Validate quality before final answer.
- Every major claim references repo names and concrete context.
- Includes decision points and what to study next.
- Keeps facts vs assumptions explicit.

## Decision Points
- If user asks "which first", always start from architecture/foundation before implementation repos.
- If track is unknown, default to mixed and state it explicitly.
- If user asks "slowly, one by one", generate exactly one repo deep dive per turn and propose the next repo.
- If a repo is sample/demo only, treat it as late-stage learning unless user asks otherwise.
- If a repo is private/inaccessible, keep placeholder content and provide nearest public alternatives.

## Quality Checks
Before finalizing each response:
- provide a clear next repo recommendation with reason
- include at least one visual flow using Mermaid
- include completion checks/questions for the current repo
- avoid mixing Terraform and Bicep implementation details unless mode is mixed
- in one-by-one mode, do not include more than one repo deep dive in the same output

## Output Format
For `overview` mode:
1. Repo groups and relationships
2. Recommended learning order
3. Decision points
4. Next action

For `one-by-one` mode:
1. Repo positioning summary
2. Relationship diagram
3. Study steps (60-90 min)
4. Common pitfalls
5. Self-check questions
6. Private/inaccessible repo placeholder (only when needed)
7. Next repo recommendation

For `impact` mode:
1. Findings by severity
2. Impacted repos and interfaces
3. Risk and test gaps
4. Suggested safe change plan

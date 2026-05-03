

## 🛠️ Skill Integration and Environment Context

Skills provide reusable behaviors that allow agents to perform specialized tasks (e.g., `git-release`). When integrating skills, always follow these guidelines:

1.  **Skill Definition**: Define the skill logic in a dedicated folder structure (`<skill_name>/SKILL.md`) following the documentation's YAML frontmatter rules (`name`, `description`).
2.  **.cursor Context**: The `.cursor` environment directory should be treated as an additional source of specialized skills or context, similar to how OpenCode discovers skills from specific paths (e.g., `.opencode/skills/`). If a skill defined in `.cursor` is relevant, ensure its `SKILL.md` adheres to the required frontmatter structure for proper discovery.
3.  **Workflow**: When a task requires both environment context and specialized logic, use the skills tool (`skill({ name: "..." })`) *after* ensuring all necessary environmental settings are accounted for.

By adhering to these rules, we ensure that agents can utilize both the project's specific local configurations (`.cursor`) and reusable system behaviors (Skills).

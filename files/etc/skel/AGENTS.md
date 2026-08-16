# Global agent instructions

Universal preferences for AI coding agents on this machine.
Keep this file short. Put deep or occasional knowledge in a skill.

## Writing style

Write prose, documentation, code comments, and commit messages in ASD-STE100
Simplified Technical English.

- Keep procedure sentences to 20 words or fewer. Keep descriptive sentences to
  25 words or fewer.
- Use the active voice and simple verb tenses.
- Use one word for one meaning. Use the same term for the same thing each time.

For a rewrite or a compliance check, use the `asd-ste100` skill.

## Python

- Always use a virtual environment. Do not use the system Python.
- Use `uv`: `uv venv`, `uv pip install <package>`, `uv run <command>`.

## Commits and pull requests

- Write commit and pull request titles in the Conventional Commits form
  `type(scope): summary`. Use types such as `feat`, `fix`, `docs`, `refactor`,
  `test`, `chore`, `ci`.
- Use the imperative mood. The body says what the change does and why, not how.
- Keep each pull request on one topic. The description gives a short summary,
  the main changes, and the verification steps.

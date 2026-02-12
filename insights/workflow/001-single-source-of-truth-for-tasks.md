# Insight 001: Single Source of Truth for Task Numbering

## Context

In collaborative development environments, especially those involving multiple agents (human or AI), managing sequential task numbering and indexing can become a source of inconsistency and conflict. Relying on ad-hoc methods or incomplete listings leads to errors, duplicate numbers, and re-synchronization overhead.

## Insight

It is critically important to establish and strictly adhere to a **single, explicitly defined source of truth for sequential numbering and indexing in task management systems.** This ensures consistency, prevents numbering discrepancies, and provides a clear, shared understanding of the task landscape.

For this project, the `platform-services/tasks/README.md` serves as this authoritative index for all `platform-services` tasks.

## Key Principles for Maintaining a Single Source of Truth

1.  **Centralized Index**: Designate a specific document (e.g., `tasks/README.md`) as the authoritative index for all tasks.
2.  **Numbering Authority**: This index is the *only* place to determine the next available sequential number for new tasks or specs.
3.  **Strict Process for New Tasks**:
    *   **Consult First**: Before creating any new task file, developers (or AI agents) *must* consult the central index to find the highest sequential number.
    *   **Reserve Number**: Assign the next available number (`Highest + 1`).
    *   **Update Index Immediately**: Add the new task to the central index *before* creating the actual task file content. This reserves the number and keeps the index perpetually up-to-date.
    *   **File Name Match**: Task file names (`NNN-description.md`) *must* exactly match the number and description in the central index.
4.  **Backlog Integration**: Integrate backlog management (e.g., `tasks/backlog/` indexed by `tasks/BACKLOG.md`) into this system, with clear rules for promoting backlog items to active tasks (which would then follow the above numbering process).
5.  **Automation Potential**: Where feasible, automate the process of assigning numbers and updating the index (e.g., via scripts or AI tools) to minimize human error.

## Benefits

*   **Prevents Numbering Conflicts**: Eliminates duplicate task numbers.
*   **Ensures Consistency**: All participants (human and AI) operate from the same understanding of task sequencing.
*   **Reduces Re-synchronization Efforts**: Avoids time-consuming corrections due to out-of-sync documentation.
*   **Improves Traceability**: Every task has a clear, unique identifier.
*   **Enhances AI Collaboration**: AI agents can reliably interpret task status and generate new tasks without creating conflicts.

## Related Insight/Lesson

This insight was developed during the process of correcting conflicting task numbers and refining the `platform-services` task management workflow. It directly informs the updated instructions in `platform-services/DEVELOPMENT.md` and `platform-services/tasks/README.md`.

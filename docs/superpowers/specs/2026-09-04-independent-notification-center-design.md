# Independent Notification Center Design

**Status:** Approved

Titonium separates passive notifications from attention-critical Center presentation. Native low/normal notifications create a top-right toast and enter a session history. Native critical notifications and explicit internal `job_failed`, `job_requires_action`, and `timer_finished` events enter the same history and a FIFO Center banner queue without creating a duplicate toast.

`NotificationService` remains the only native `NotificationServer` owner. A new notification policy/rules layer normalizes descriptors and applies, in order, block, per-application custom override, internal-event policy, native urgency, then normal fallback. It never infers severity from title or body. Stable public keys are namespaced strings. Standard actions are supported; inline reply and images remain out of scope.

Settings adds automatic/custom policy mode, per-application `follow|quiet|normal|critical|block`, `allowCriticalOnIsland`, and `keepCriticalUnread`. Invalid values fall back safely. The Notification bell is always present and opens one top-right history panel on the clicked screen. The panel marks current entries read only after opening successfully and supports standard actions, per-item dismissal, and clear all.

The critical queue holds at most 16 items and history at most 100. Each critical item receives 4000 ms of readable time. Hover pauses the remaining deadline and leaving resumes it. Center banner geometry remains stable while content cross-fades/slides between FIFO items. Expanded or user-owned Center interaction is never preempted. Reduced Motion removes animation without changing queue/timer behavior.

System battery warnings are deferred until a dedicated system-battery producer exists. All existing uncommitted user work outside the isolated feature worktree is preserved.

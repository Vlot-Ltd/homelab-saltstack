# PEP-HL-SLT-014: friday rebuildable from Salt

**ID:** PEP-HL-SLT-014  
**Title:** friday rebuildable from Salt  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Infrastructure  
**Priority:** Medium  
**Created:** 2026-10-10  
**Updated:** 2026-10-10  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Make friday, the second-brain box (LiteLLM, vault jobs), rebuildable from Salt (vault-tidy-and-second-brain in the vault). Was blocked on Salt-Vault, fixed 2026-10-09.

## Motivation

Why is this change needed? What problem does it solve?

Known hand-made config on `friday` to capture (2026-10-10):

- `/etc/systemd/system/litellm.service`: LiteLLM in Docker, published on `127.0.0.1:4000` only (changed from `0.0.0.0` on 2026-10-10)
- Tailscale Service `llm`: `tailscale serve --bg --service=svc:llm --https=443 http://localhost:4000` (covered by PEP-HL-SLT-019's per-host Services pillar)
- `/home/proxmox/litellm/config.yaml`: `local` route uses `ollama_chat/` (changed 2026-10-09)

## Specification

### Requirements

- Functional requirements
- Non-functional requirements
- Constraints

### Implementation Approach

- High-level design
- Technology choices
- Integration points

### Success Criteria

- Measurable outcomes
- Acceptance criteria

## Implementation Plan

### Phase 1: [Phase Name]

- Tasks
- Timeline
- Dependencies

### Phase 2: [Phase Name]

- Tasks
- Timeline
- Dependencies

## Testing Strategy

- Unit tests
- Integration tests
- Validation criteria

## Documentation Requirements

- User documentation
- Technical documentation
- Runbooks/operational docs

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| | | | |

## References

- Related PEPs
- External documentation
- Standards/best practices

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-10-10 | Timo Vlot | Initial draft |

# PEP-HL-SLT-009: Salt master hardening and SaltGUI revival

**ID:** PEP-HL-SLT-009  
**Title:** Salt master hardening and SaltGUI revival  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Security  
**Priority:** High  
**Created:** 2026-10-10  
**Updated:** 2026-10-10  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

Harden the homelab Salt master. Found 2026-10-09 in conf/master.active: rest_cherrypy on 0.0.0.0:9191 with disable_ssl: true, and PAM user testuser with .*, @wheel, @runner, @jobs (root on every minion over plain HTTP). salt-api was disabled the same day as a stopgap. Remove testuser and the stale 'peer: gibson' rule, manage master config from the repo, and bring back salt-api for SaltGUI only with TLS and a least-privilege eauth user.

## Motivation

Why is this change needed? What problem does it solve?

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

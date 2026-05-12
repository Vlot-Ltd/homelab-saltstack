# PEP-003: Fix SQL Injection in PostgreSQL State Management

**PEP:** 003  
**Title:** Fix SQL Injection in PostgreSQL State Management  
**Author:** Timo Vlot  
**Status:** Draft  
**Type:** Feature  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

`salt/database/postgres/database.sls` interpolates pillar-supplied passwords directly into SQL strings using Jinja, with no escaping. A password containing a single quote breaks the SQL and could allow arbitrary SQL execution. This PEP replaces the vulnerable `cmd.run` pattern with Salt's built-in `postgres` execution module.

## Motivation

The current state uses this pattern:

```jinja
cmd.run:
  - name: psql -U postgres -c "CREATE USER {{ user['name'] }} WITH LOGIN ENCRYPTED PASSWORD '{{ user['password'] }}'"
```

If `user['password']` is `hunter2'-- `, the resulting SQL is:

```sql
CREATE USER myuser WITH LOGIN ENCRYPTED PASSWORD 'hunter2'-- '
```

This truncates the statement unpredictably. A more carefully crafted value could drop tables or create additional users. Even without malicious intent, passwords with special characters (apostrophes, backslashes) will silently fail or corrupt state.

## Specification

### Requirements

- No pillar-derived value may be interpolated into a raw SQL string
- User creation, database creation, and privilege grants use Salt's `postgres` module states (`postgres_user.present`, `postgres_database.present`, `postgres_privileges.present`)
- The fix must not require changes to pillar data structure — existing pillar format is preserved
- Idempotency is maintained: re-running the state does not error on already-existing users/databases

### Implementation Approach

Replace `cmd.run` SQL calls in `salt/database/postgres/database.sls` with native Salt postgres states:

**Before (vulnerable):**

```yaml
create_user_{{ user['name'] }}:
  cmd.run:
    - name: psql -U postgres -c "CREATE USER {{ user['name'] }} WITH LOGIN ENCRYPTED PASSWORD '{{ user['password'] }}'"
    - unless: psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='{{ user['name'] }}'" | grep -q 1
    - runas: postgres
```

**After (safe):**

```yaml
postgres_user_{{ user['name'] }}:
  postgres_user.present:
    - name: {{ user['name'] }}
    - password: {{ user['password'] | yaml_encode }}
    - login: True
    - encrypted: True
    - require:
      - service: postgresql
```

The `postgres_user.present` state passes the password through the Python `psycopg2` driver using parameterised queries — no string interpolation into SQL occurs.

The same pattern applies to:
- Database creation → `postgres_database.present`
- GRANT statements → `postgres_privileges.present`

### Success Criteria

- `salt/database/postgres/database.sls` contains no `psql -c "...{{ ... }}..."` patterns
- Passwords containing `'`, `"`, `\`, and `;` are handled correctly (validate with a test user)
- State is idempotent: running twice produces no changes on second run

## Implementation Plan

### Phase 1: Audit Current State

- List every `cmd.run` in `database.sls` that includes user-supplied data in SQL
- Confirm which Salt postgres module states are available on the target minion (`salt <minion> sys.doc postgres_user`)

### Phase 2: Rewrite database.sls

- Replace each vulnerable `cmd.run` block with the appropriate `postgres_user.present`, `postgres_database.present`, or `postgres_privileges.present` state
- Preserve the existing pillar data structure (`databases` and `users` lists)
- Add `require: service: postgresql` to all database states

### Phase 3: Test

- Apply state to a test minion with a password containing `'hunter2' OR '1'='1`
- Confirm user is created with that literal password, not interpreted as SQL
- Apply state twice and confirm idempotency (no "already exists" errors)

## Claude Prompt Context

### Context for AI Assistance

```
You are helping implement PEP-003 for a homelab SaltStack project.
Goal: Fix SQL injection in salt/database/postgres/database.sls by replacing cmd.run+psql with Salt postgres module states.
Technology stack: SaltStack, PostgreSQL, Jinja2
Pillar structure: pillar data contains 'databases' list and 'users' list, each with 'name' and 'password' keys
Salt modules available: postgres_user, postgres_database, postgres_privileges
Constraint: Must not change pillar data structure — only state file changes
Current status: Draft - database.sls still uses raw SQL interpolation
```

### Specific AI Tasks

- [ ] Rewrite `salt/database/postgres/database.sls` using `postgres_user.present`, `postgres_database.present`, `postgres_privileges.present`
- [ ] Generate test cases for passwords with special characters
- [ ] Verify `require` chain is correct so states apply in dependency order

## Testing Strategy

- Create a test user via pillar with password `test'injection";\DROP TABLE pg_user;--`
- Run `salt <minion> state.apply database.postgres.database` and confirm no SQL error
- Connect to postgres and verify the user exists with the exact password string
- Run state a second time and confirm no changes reported

## Documentation Requirements

- Add a comment in `database.sls` explaining why `postgres_user.present` is used instead of `cmd.run`

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| `postgres` Salt module not available on minion | State fails to apply | Low | Install `python3-psycopg2` on target; verify with `sys.doc postgres_user` |
| Existing users have passwords with special chars that were being silently truncated | Users locked out after fix | Low | Test login for all managed users post-migration |
| `postgres_privileges.present` syntax differs from expected grant | Wrong permissions applied | Low | Test on non-production database first |

## References

- `salt/database/postgres/database.sls` — file to be modified
- Salt docs: `postgres_user.present`, `postgres_database.present`, `postgres_privileges.present`
- CWE-89: SQL Injection

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial draft from audit findings |

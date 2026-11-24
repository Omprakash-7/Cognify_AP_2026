# CP5 Individual Analysis: Account Deletion and Cascades

## Dependency behavior

The schema uses `ON DELETE CASCADE` from `users` to several user-owned records,
including credentials, profiles, baselines, role assignments, and other
dependent data. This is convenient for referential cleanup, but deleting one
account can fan out across a substantial history of study and audit records.

## Product and audit implications

Before using a hard delete as an account-erasure workflow, decide which records
must be erased, which must be retained for security or legal reasons, and
whether retained records can be de-identified. Cascades encode a database
dependency policy; they do not establish the full retention policy. In
particular, audit evidence may need a different lifecycle from learner profile
data.

## Operational implications

A large cascade is one transaction and may hold locks while child rows are
deleted and indexes maintained. For a production-scale account with extensive
review history, measure the deletion duration and lock impact. A staged,
audited deletion process may be more appropriate than one synchronous request.

## Evidence

Inspect the foreign-key actions in `dbms/03_schema.sql`, especially the user
references from credentials, profiles, and activity tables. This note records
design questions for CP5 discussion; it does not change the schema's current
delete behavior.

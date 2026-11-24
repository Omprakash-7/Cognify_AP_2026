# CP5 Individual Analysis: Authentication Query Projection

## Observation

R1 returns the password hash, salt, and MFA secret together with the user
identity and assigned roles. The query is described as authentication, so the
application may need credential material during verification, but it should
not carry those fields into unrelated response objects or logs.

## Minimize exposure

Keep credential verification inside a narrowly scoped authentication path.
After checking the password and MFA challenge, return only the user identity,
active status, and role claims needed by the caller. Avoid logging the full R1
row, since query debugging and exception logging can otherwise expose secrets.

## Query semantics

The `INNER JOIN` to credentials means users without a credential row cannot
authenticate through this query. The active-user predicate excludes disabled
accounts, while the left joins allow a valid user with no assigned roles to
still be returned with an empty role array.

## Evidence

See R1 in `dbms/04_queries.sql` and the one-to-one credential relationship in
`dbms/03_schema.sql`. The SQL result shape is a database boundary; the
application layer should map it to a smaller response type before returning or
logging data.

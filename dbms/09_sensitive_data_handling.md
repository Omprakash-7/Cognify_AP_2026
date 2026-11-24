# Sensitive Data Handling in the DBMS Queries

## Authentication fields

R1 selects `password_hash`, `salt`, and `mfa_secret` because an authentication
service needs them to verify credentials. Keep this query server-side: never
return those columns in an API response, application log, analytics event, or
client-visible error. Select only the credential fields needed for the current
verification step, and keep password/MFA verification outside SQL.

## Audit records

W15 records an IP address and user-agent string. Treat both as personal/security
data: restrict access to audit queries, define retention for expired records,
and avoid copying the raw values into general-purpose logs. R15 should remain
behind an authorized security or administrator role.

## Query inputs

Use typed bind parameters as described in `dbms/07_parameter_binding.md`. Do
not concatenate login strings, UUIDs, time zones, IP addresses, or search terms
into SQL text. Validate authorization separately from the existence of a row;
an identifier supplied by a client is not proof of access rights.

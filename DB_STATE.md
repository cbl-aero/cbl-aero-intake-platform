\# Database State – Authoritative Snapshot



All schema assumptions must be derived from the DDL files in db/ddl.



\## Files



\- 00\_schema\_core\_delivery.sql

\- 01\_functions.sql

\- 02\_extensions.sql

\- 03\_types.sql (if enums exist)



Any DB change requires:

1\. Applying change in Supabase

2\. Re-exporting DDL

3\. Committing updated DDL




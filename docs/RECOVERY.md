# Preserve and recover local data

In Companion, choose **Prepare recovery copy**, then **Save recovery files** and
save to a location you control. A running app uses SQLite's backup API, so the copy
includes committed WAL data, pending outbox mutations and conflicts consistently.
Keychain credentials are not exported. Preparing a copy does not unpair, clear,
or migrate the live store. Copies remain in the app's Documents recovery folder
until removed with the app container; save needed copies outside the app first.

If startup rejects a newer, protocol-one or corrupt database, its failure screen
can copy the original database and every surviving `-wal`/`-shm` sidecar. Save all
files together. This is preservation, not a repaired or verified database. Do not
open or replace the original while investigating it.

For recovery, first work on a duplicate using a build that supports that local
schema. Verify SQLite integrity, domain graphs, outbox operations and server
identity before considering restoration. The supported normal reconnection path
uses the same desktop identity and certificate. Automatic restoration, schema-one
migration, a different desktop identity and certificate replacement are not
implemented; do not clear state or discard an outbox to bypass those checks.
A reviewed recovery/migration tool and an additional preserved copy are required
before changing identity or restoring data into the live container.

The app displays version/build/source in Companion and on its failure screen.
CI unsigned builds embed the workflow build number and exact source commit.
A local Xcode build defaults to build 1 / source `development` unless overridden.

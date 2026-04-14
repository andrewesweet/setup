# gcloud Data-Plane Audit (Agent alpha)

**Source artifact**: `macos-dev/docs/research/gcloud-cli-commands.json` (gcloud 564.0.0, 134 services, 5,302 stable leaves).
**Scope**: every top-level non-alpha/beta service. Alpha/beta are covered by a separate blanket ask and are excluded here.
**Definition used**:
- **Metadata** = information *about* a resource (name, size, IAM policy, labels, schema, shard count, timestamps, operation status).
- **Data** = content the resource holds (object bytes, secret values, log entries, messages, rows, documents, predictions, plaintext/ciphertext, SQL results, user-supplied payloads).

Per the plan, object-level storage operations are treated as data-plane even where the verb is "list" / "describe" (so `storage objects *` is demoted). Other services keep the safe-verb allows intact — only genuinely data-reading/writing subcommands are flagged.

## Matrix

### ai

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| ai | `ai endpoints predict` | data-mixed | Sends a user payload to a deployed model and returns a prediction — both sides are data. | `"gcloud ai endpoints predict*": "ask"` |
| ai | `ai endpoints raw-predict` | data-mixed | Raw prediction variant; user payload in, model output out. | `"gcloud ai endpoints raw-predict*": "ask"` |
| ai | `ai endpoints direct-predict` | data-mixed | Low-latency direct prediction path; same data shape. | `"gcloud ai endpoints direct-predict*": "ask"` |
| ai | `ai endpoints direct-raw-predict` | data-mixed | Direct raw prediction variant. | `"gcloud ai endpoints direct-raw-predict*": "ask"` |
| ai | `ai endpoints stream-direct-predict` | data-mixed | Streamed prediction; user payload in, stream out. | `"gcloud ai endpoints stream-direct-predict*": "ask"` |
| ai | `ai endpoints stream-direct-raw-predict` | data-mixed | Streamed raw prediction. | `"gcloud ai endpoints stream-direct-raw-predict*": "ask"` |
| ai | `ai endpoints stream-raw-predict` | data-mixed | Streamed raw prediction. | `"gcloud ai endpoints stream-raw-predict*": "ask"` |
| ai | `ai endpoints explain` | data-mixed | Returns a prediction + feature attributions for a user payload. | `"gcloud ai endpoints explain*": "ask"` |

### ai-platform (legacy Vertex / Cloud ML Engine)

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| ai-platform | `ai-platform predict` | data-mixed | Sends a prediction request with instance payloads to a model version. | `"gcloud ai-platform predict*": "ask"` |
| ai-platform | `ai-platform local predict` | data-mixed | Runs a prediction locally against a saved model using user instances. | `"gcloud ai-platform local predict*": "ask"` |
| ai-platform | `ai-platform jobs submit prediction` | data-write | Submits a batch prediction job over user data in GCS. | `"gcloud ai-platform jobs submit prediction*": "ask"` |

### alloydb

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| alloydb | `alloydb clusters export` | data-read | Exports full database contents to GCS. | `"gcloud alloydb clusters export*": "ask"` |
| alloydb | `alloydb clusters import` | data-write | Imports database contents from GCS into a cluster. | `"gcloud alloydb clusters import*": "ask"` |

### app (App Engine)

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| app | `app logs read` | data-read | Reads application log entries. | `"gcloud app logs read*": "ask"` |
| app | `app logs tail` | data-read | Streams application log entries. | `"gcloud app logs tail*": "ask"` |

### artifacts

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| artifacts | `artifacts attachments download` | data-read | Downloads attachment bytes. | `"gcloud artifacts attachments download*": "ask"` |
| artifacts | `artifacts files download` | data-read | Downloads file content from a repo. | `"gcloud artifacts files download*": "ask"` |
| artifacts | `artifacts generic download` | data-read | Downloads generic artifact bytes. | `"gcloud artifacts generic download*": "ask"` |
| artifacts | `artifacts generic upload` | data-write | Uploads generic artifact bytes. | `"gcloud artifacts generic upload*": "ask"` |
| artifacts | `artifacts apt upload` | data-write | Uploads apt package bytes. | `"gcloud artifacts apt upload*": "ask"` |
| artifacts | `artifacts apt import` | data-write | Imports apt package content into repo. | `"gcloud artifacts apt import*": "ask"` |
| artifacts | `artifacts yum upload` | data-write | Uploads yum package bytes. | `"gcloud artifacts yum upload*": "ask"` |
| artifacts | `artifacts yum import` | data-write | Imports yum package content into repo. | `"gcloud artifacts yum import*": "ask"` |
| artifacts | `artifacts go upload` | data-write | Uploads Go module bytes. | `"gcloud artifacts go upload*": "ask"` |
| artifacts | `artifacts sbom load` | data-write | Loads a user-supplied SBOM document. | `"gcloud artifacts sbom load*": "ask"` |
| artifacts | `artifacts sbom export` | data-read | Emits SBOM bytes for an artifact (uncertain — borderline metadata-about-content; recommend ask to be conservative). | `"gcloud artifacts sbom export*": "ask"` |
| artifacts | `artifacts vulnerabilities load-vex` | data-write | Loads a VEX document describing vulnerabilities in user artifacts. | `"gcloud artifacts vulnerabilities load-vex*": "ask"` |

### asset

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| asset | `asset export` | data-read | Exports the full asset inventory (can include resource-config data) to GCS/BQ. | `"gcloud asset export*": "ask"` |
| asset | `asset query` | data-read | Runs a user SQL query over the asset inventory and returns rows. | `"gcloud asset query*": "ask"` |
| asset | `asset get-history` | data-read | Returns resource-state history snapshots (resource-payload content). | `"gcloud asset get-history*": "ask"` |

### backup-dr

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| backup-dr | `backup-dr backups restore compute` | data-write | Restores a backup (materializes backup-bytes into a live compute resource). | `"gcloud backup-dr backups restore *": "ask"` |
| backup-dr | `backup-dr backups restore disk` | data-write | Restores disk backup payload. | `"gcloud backup-dr backups restore *": "ask"` |

### bigtable

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| bigtable | `bigtable backups copy` | data-write | Copies a backup (contents of rows) across clusters. | `"gcloud bigtable backups copy*": "ask"` |
| bigtable | `bigtable instances tables restore` | data-write | Restores table rows from a backup. | `"gcloud bigtable instances tables restore*": "ask"` |
| bigtable | `bigtable tables restore` | data-write | Restores table rows from a backup. | `"gcloud bigtable tables restore*": "ask"` |

### builds

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| builds | `builds log` | data-read | Streams build log output. Uncertain — recommend ask. | `"gcloud builds log*": "ask"` |

### composer

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| composer | `composer environments storage dags export` | data-read | Copies DAG source files out of the environment bucket. | `"gcloud composer environments storage dags export*": "ask"` |
| composer | `composer environments storage dags import` | data-write | Uploads DAG source files into the environment. | `"gcloud composer environments storage dags import*": "ask"` |
| composer | `composer environments storage data export` | data-read | Exports data files from the env bucket. | `"gcloud composer environments storage data export*": "ask"` |
| composer | `composer environments storage data import` | data-write | Imports data files into the env bucket. | `"gcloud composer environments storage data import*": "ask"` |
| composer | `composer environments storage plugins export` | data-read | Exports plugin source code. | `"gcloud composer environments storage plugins export*": "ask"` |
| composer | `composer environments storage plugins import` | data-write | Imports plugin source code. | `"gcloud composer environments storage plugins import*": "ask"` |
| composer | `composer environments snapshots load` | data-write | Loads a DB+storage snapshot back into an environment. | `"gcloud composer environments snapshots load*": "ask"` |

### compute

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| compute | `compute copy-files` | data-mixed | Copies files to/from instances (scp wrapper). | `"gcloud compute copy-files*": "ask"` |
| compute | `compute diagnose export-logs` | data-read | Collects and copies out instance diagnostic logs. | `"gcloud compute diagnose export-logs*": "ask"` |
| compute | `compute images export` | data-read | Exports the bytes of a VM image to GCS. | `"gcloud compute images export*": "ask"` |
| compute | `compute images import` | data-write | Imports VM image bytes from GCS. | `"gcloud compute images import*": "ask"` |
| compute | `compute machine-images import` | data-write | Imports a machine image (VM disk bytes). | `"gcloud compute machine-images import*": "ask"` |
| compute | `compute instances export` | data-read | Exports an instance config file (mostly metadata but includes user-data / startup-scripts which can be data). Uncertain — recommend ask. | `"gcloud compute instances export*": "ask"` |
| compute | `compute instances import` | data-write | Imports OVA/OVF including disk bytes. | `"gcloud compute instances import*": "ask"` |
| compute | `compute instances get-serial-port-output` | data-read | Reads serial console output (can contain sensitive boot logs / credentials). | `"gcloud compute instances get-serial-port-output*": "ask"` |
| compute | `compute instances get-screenshot` | data-read | Captures the framebuffer bytes of a running VM. | `"gcloud compute instances get-screenshot*": "ask"` |
| compute | `compute instances tail-serial-port-output` | data-read | Streams serial console output. | `"gcloud compute instances tail-serial-port-output*": "ask"` |
| compute | `compute routers download-route-policy` | data-read | Downloads the custom route-policy document attached to a router. Uncertain — recommend ask. | `"gcloud compute routers download-route-policy*": "ask"` |
| compute | `compute routers upload-route-policy` | data-write | Uploads a custom route-policy document. | `"gcloud compute routers upload-route-policy*": "ask"` |
| compute | `compute sign-url` | data-write | Signs a URL with HMAC material — crypto signing op on user input. | `"gcloud compute sign-url*": "ask"` |

Note: plain resource-config `export`/`import` verbs (backend-services, forwarding-rules, security-policies, target-*-proxies, url-maps, firewall-policies, network-firewall-policies) are metadata YAML round-trips; they fall out through the generic `*: ask` for import/export if the team chooses, but are NOT data-plane content. Not included here.

### datastore

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| datastore | `datastore export` | data-read | Exports entity data to GCS. | `"gcloud datastore export*": "ask"` |
| datastore | `datastore import` | data-write | Imports entity data from GCS. | `"gcloud datastore import*": "ask"` |

### developer-connect

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| developer-connect | `developer-connect connections git-repository-links fetch-read-token` | data-write | Mints a credential token granting read access to a user-linked git repo. Uncertain — borderline auth vs data; recommend ask. | `"gcloud developer-connect connections git-repository-links fetch-read-token*": "ask"` |
| developer-connect | `developer-connect connections git-repository-links fetch-read-write-token` | data-write | Mints a read/write credential token for a linked git repo. | `"gcloud developer-connect connections git-repository-links fetch-read-write-token*": "ask"` |

### eventarc

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| eventarc | `eventarc message-buses publish` | data-write | Publishes a user-supplied CloudEvent onto a message bus. | `"gcloud eventarc message-buses publish*": "ask"` |

### firestore

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| firestore | `firestore export` | data-read | Exports document collections to GCS. | `"gcloud firestore export*": "ask"` |
| firestore | `firestore import` | data-write | Imports document collections from GCS. | `"gcloud firestore import*": "ask"` |
| firestore | `firestore bulk-delete` | data-write | Deletes a set of user documents in bulk. | `"gcloud firestore bulk-delete*": "ask"` |

### functions

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| functions | `functions logs read` | data-read | Reads function logs (user-generated log entries). | `"gcloud functions logs read*": "ask"` |
| functions | `functions call` | data-mixed | Invokes a function with a user-supplied payload and returns the function's response. | `"gcloud functions call*": "ask"` |

### healthcare

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| healthcare | `healthcare dicom-stores export bq` | data-read | Exports DICOM (medical imaging) content. | `"gcloud healthcare dicom-stores export *": "ask"` |
| healthcare | `healthcare dicom-stores export gcs` | data-read | Exports DICOM content to GCS. | `"gcloud healthcare dicom-stores export *": "ask"` |
| healthcare | `healthcare dicom-stores import gcs` | data-write | Imports DICOM content. | `"gcloud healthcare dicom-stores import *": "ask"` |
| healthcare | `healthcare fhir-stores export bq` | data-read | Exports FHIR (patient-record) content. | `"gcloud healthcare fhir-stores export *": "ask"` |
| healthcare | `healthcare fhir-stores export gcs` | data-read | Exports FHIR content to GCS. | `"gcloud healthcare fhir-stores export *": "ask"` |
| healthcare | `healthcare fhir-stores import gcs` | data-write | Imports FHIR content. | `"gcloud healthcare fhir-stores import *": "ask"` |
| healthcare | `healthcare hl7v2-stores export gcs` | data-read | Exports HL7v2 message content. | `"gcloud healthcare hl7v2-stores export *": "ask"` |
| healthcare | `healthcare hl7v2-stores import gcs` | data-write | Imports HL7v2 message content. | `"gcloud healthcare hl7v2-stores import *": "ask"` |
| healthcare | `healthcare datasets deidentify` | data-mixed | Reads PHI from a source dataset and writes de-identified copies. | `"gcloud healthcare datasets deidentify*": "ask"` |
| healthcare | `healthcare dicom-stores deidentify` | data-mixed | Reads PHI from DICOM and writes de-identified output. | `"gcloud healthcare dicom-stores deidentify*": "ask"` |
| healthcare | `healthcare fhir-stores deidentify` | data-mixed | Reads PHI from FHIR and writes de-identified output. | `"gcloud healthcare fhir-stores deidentify*": "ask"` |
| healthcare | `healthcare consent-stores check-data-access` | data-read | Evaluates a user-supplied data-access request against consent records. Uncertain — recommend ask. | `"gcloud healthcare consent-stores check-data-access*": "ask"` |
| healthcare | `healthcare consent-stores query-accessible-data` | data-read | Returns the data accessible under a given consent. | `"gcloud healthcare consent-stores query-accessible-data*": "ask"` |
| healthcare | `healthcare consent-stores evaluate-user-consents` | data-read | Evaluates user consents over PHI. Uncertain — recommend ask. | `"gcloud healthcare consent-stores evaluate-user-consents*": "ask"` |

### iam

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| iam | `iam service-accounts sign-blob` | data-write | Crypto-signs a user-supplied blob with a service-account key. | `"gcloud iam service-accounts sign-blob*": "ask"` |
| iam | `iam service-accounts sign-jwt` | data-write | Crypto-signs a user-supplied JWT payload. | `"gcloud iam service-accounts sign-jwt*": "ask"` |

### infra-manager

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| infra-manager | `infra-manager deployments export-statefile` | data-read | Exports Terraform state (may contain secrets). | `"gcloud infra-manager deployments export-statefile*": "ask"` |
| infra-manager | `infra-manager deployments import-statefile` | data-write | Imports Terraform state. | `"gcloud infra-manager deployments import-statefile*": "ask"` |
| infra-manager | `infra-manager deployments export-lock` | data-read | Exports Terraform state lock. Uncertain — recommend ask. | `"gcloud infra-manager deployments export-lock*": "ask"` |
| infra-manager | `infra-manager revisions export-statefile` | data-read | Exports Terraform state for a revision. | `"gcloud infra-manager revisions export-statefile*": "ask"` |

### kms

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| kms | `kms encrypt` | data-mixed | Encrypts user plaintext; plaintext is data. | `"gcloud kms encrypt*": "ask"` |
| kms | `kms decrypt` | data-mixed | Decrypts user ciphertext; plaintext output is data. | `"gcloud kms decrypt*": "ask"` |
| kms | `kms raw-encrypt` | data-mixed | Raw (no-AEAD) encryption of user plaintext. | `"gcloud kms raw-encrypt*": "ask"` |
| kms | `kms raw-decrypt` | data-mixed | Raw (no-AEAD) decryption. | `"gcloud kms raw-decrypt*": "ask"` |
| kms | `kms asymmetric-decrypt` | data-mixed | Decrypts with asymmetric key. | `"gcloud kms asymmetric-decrypt*": "ask"` |
| kms | `kms asymmetric-sign` | data-write | Signs user data with asymmetric key. | `"gcloud kms asymmetric-sign*": "ask"` |
| kms | `kms mac-sign` | data-write | Generates MAC over user data. | `"gcloud kms mac-sign*": "ask"` |
| kms | `kms mac-verify` | data-read | Verifies MAC over user-supplied data + tag. | `"gcloud kms mac-verify*": "ask"` |
| kms | `kms decapsulate` | data-mixed | Post-quantum KEM decapsulation — user ciphertext → shared secret (user data). | `"gcloud kms decapsulate*": "ask"` |
| kms | `kms keys versions import` | data-write | Imports externally-held key material into KMS. | `"gcloud kms keys versions import*": "ask"` |

Note: the draft does not list `asymmetric-verify` — the stable enumeration does not have that leaf in 564.0.0, so it's not added. `kms decapsulate` is newly present in 564.0.0 and is an addition over the draft.

### logging

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| logging | `logging read` | data-read | Reads log entries. | `"gcloud logging read*": "ask"` |
| logging | `logging tail` | data-read | Streams log entries. | `"gcloud logging tail*": "ask"` |
| logging | `logging write` | data-write | Writes log entries. | `"gcloud logging write*": "ask"` |
| logging | `logging copy` | data-mixed | Copies log entries between buckets. | `"gcloud logging copy*": "ask"` |

### looker

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| looker | `looker instances export` | data-read | Exports instance state including user dashboards / data models. | `"gcloud looker instances export*": "ask"` |
| looker | `looker instances import` | data-write | Imports instance state. | `"gcloud looker instances import*": "ask"` |

### lustre

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| lustre | `lustre instances export-data` | data-read | Exports filesystem contents from a Lustre instance. | `"gcloud lustre instances export-data*": "ask"` |
| lustre | `lustre instances import-data` | data-write | Imports filesystem contents into a Lustre instance. | `"gcloud lustre instances import-data*": "ask"` |

### memorystore

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| memorystore | `memorystore backup-collections backups export` | data-read | Exports Memorystore backup content (actual cached data). | `"gcloud memorystore backup-collections backups export*": "ask"` |

### metastore (Dataproc Metastore)

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| metastore | `metastore services export gcs` | data-read | Exports Hive metadata store content. Uncertain — this is metadata-about-tables but treated as data-plane since schema-of-user-data leaks schema shape. Recommend ask. | `"gcloud metastore services export *": "ask"` |
| metastore | `metastore services import gcs` | data-write | Imports Hive metadata store content. | `"gcloud metastore services import *": "ask"` |
| metastore | `metastore services query-metadata` | data-read | Runs a metadata query against the store. Uncertain — recommend ask. | `"gcloud metastore services query-metadata*": "ask"` |

### ml

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| ml | `ml language analyze-entities` | data-mixed | Sends user text to NLP API and returns analysis. | `"gcloud ml language *": "ask"` |
| ml | `ml language analyze-entity-sentiment` | data-mixed | User text in, sentiment out. | `"gcloud ml language *": "ask"` |
| ml | `ml language analyze-sentiment` | data-mixed | User text in, sentiment out. | `"gcloud ml language *": "ask"` |
| ml | `ml language analyze-syntax` | data-mixed | User text in, syntax analysis out. | `"gcloud ml language *": "ask"` |
| ml | `ml language classify-text` | data-mixed | User text in, classification out. | `"gcloud ml language *": "ask"` |
| ml | `ml speech recognize` | data-mixed | User audio in, transcript out. | `"gcloud ml speech recognize*": "ask"` |
| ml | `ml speech recognize-long-running` | data-mixed | Long-running audio transcription. | `"gcloud ml speech recognize-long-running*": "ask"` |
| ml | `ml video detect-*` | data-mixed | User video in, detections out (labels / shot-changes / explicit-content). | `"gcloud ml video detect-*": "ask"` |
| ml | `ml vision detect-*` | data-mixed | User image in, detections out (faces, labels, landmarks, logos, objects, safe-search, text, web, image-properties). | `"gcloud ml vision detect-*": "ask"` |
| ml | `ml vision suggest-crop` | data-mixed | User image in, crop hints out. | `"gcloud ml vision suggest-crop*": "ask"` |

A blanket `"gcloud ml * *": "ask"` per the draft covers all of the above and any future additions.

### model-armor

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| model-armor | `model-armor templates sanitize-user-prompt` | data-mixed | Sends user prompt text for safety scanning, returns classification. | `"gcloud model-armor templates sanitize-user-prompt*": "ask"` |
| model-armor | `model-armor templates sanitize-model-response` | data-mixed | Sends model response text for safety scanning. | `"gcloud model-armor templates sanitize-model-response*": "ask"` |

### netapp

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| netapp | `netapp kms-configs encrypt` | data-mixed | Encrypts user data under NetApp KMS config. | `"gcloud netapp kms-configs encrypt*": "ask"` |
| netapp | `netapp kms-configs verify` | data-mixed | Verifies encrypt/decrypt round-trip (handles plaintext). Uncertain — recommend ask. | `"gcloud netapp kms-configs verify*": "ask"` |
| netapp | `netapp volumes restore-backup-files` | data-write | Restores specific files from a volume backup (writes backup bytes). | `"gcloud netapp volumes restore-backup-files*": "ask"` |

### policy-intelligence

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| policy-intelligence | `policy-intelligence query-activity` | data-read | Queries user-activity logs. | `"gcloud policy-intelligence query-activity*": "ask"` |

### pubsub

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| pubsub | `pubsub subscriptions pull` | data-read | Pulls messages off a subscription. | `"gcloud pubsub subscriptions pull*": "ask"` |
| pubsub | `pubsub subscriptions ack` | data-write | Acknowledges messages (modifies stream state based on message IDs). | `"gcloud pubsub subscriptions ack*": "ask"` |
| pubsub | `pubsub topics publish` | data-write | Publishes a user-supplied message. | `"gcloud pubsub topics publish*": "ask"` |
| pubsub | `pubsub lite-topics publish` | data-write | Publishes a user message to Pub/Sub Lite. | `"gcloud pubsub lite-topics publish*": "ask"` |
| pubsub | `pubsub lite-subscriptions ack-up-to` | data-write | Advances ack cursor. Uncertain — recommend ask. | `"gcloud pubsub lite-subscriptions ack-up-to*": "ask"` |
| pubsub | `pubsub message-transforms test` | data-mixed | Runs a user-supplied message through a transform and returns the result. | `"gcloud pubsub message-transforms test*": "ask"` |
| pubsub | `pubsub schemas validate-message` | data-mixed | Validates a user-supplied message against a schema. | `"gcloud pubsub schemas validate-message*": "ask"` |

### redis

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| redis | `redis instances export` | data-read | Exports the Redis data (RDB) to GCS. | `"gcloud redis instances export*": "ask"` |
| redis | `redis instances import` | data-write | Imports Redis data from GCS. | `"gcloud redis instances import*": "ask"` |
| redis | `redis clusters backups export` | data-read | Exports cluster backup bytes. | `"gcloud redis clusters backups export*": "ask"` |

### run

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| run | `run services logs read` | data-read | Reads service logs. | `"gcloud run services logs read*": "ask"` |
| run | `run jobs logs read` | data-read | Reads job logs. | `"gcloud run jobs logs read*": "ask"` |

### scc (Security Command Center)

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| scc | `scc findings export-to-bigquery` | data-write | Streams findings content to a BigQuery dataset. Uncertain — borderline metadata-about-assets; recommend ask. | `"gcloud scc findings export-to-bigquery*": "ask"` |

### secrets

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| secrets | `secrets versions access` | data-read | Returns the secret payload bytes. | `"gcloud secrets versions access*": "ask"` |

### spanner

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| spanner | `spanner databases execute-sql` | data-read | Runs a user SQL query over Spanner data. | `"gcloud spanner databases execute-sql*": "ask"` |
| spanner | `spanner rows insert` | data-write | Inserts user-supplied row values. | `"gcloud spanner rows insert*": "ask"` |
| spanner | `spanner rows update` | data-write | Updates user-supplied row values. | `"gcloud spanner rows update*": "ask"` |
| spanner | `spanner rows delete` | data-write | Deletes user rows. | `"gcloud spanner rows delete*": "ask"` |
| spanner | `spanner cli` | data-mixed | Interactive SQL shell against Spanner. Also interactive — covered by `* cli` ask if present; recommend explicit ask. | `"gcloud spanner cli*": "ask"` |

Note: `spanner databases sessions execute-sql` in the draft does not appear in the 564.0.0 stable enumeration (only `sessions delete|list` exist as stable leaves). Keeping the pattern as protection for future versions and for alpha/beta is fine, but not strictly required by this version.

### sql (Cloud SQL)

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| sql | `sql export bak` / `sql export csv` / `sql export sql` / `sql export tde` | data-read | Exports database contents to GCS. | `"gcloud sql export *": "ask"` |
| sql | `sql import bak` / `sql import csv` / `sql import sql` / `sql import tde` | data-write | Imports database contents from GCS. | `"gcloud sql import *": "ask"` |
| sql | `sql instances export` | data-read | Exports DB content (legacy flat verb). | `"gcloud sql instances export*": "ask"` |
| sql | `sql instances import` | data-write | Imports DB content. | `"gcloud sql instances import*": "ask"` |
| sql | `sql instances execute-sql` | data-read | Runs arbitrary SQL against a Cloud SQL instance. | `"gcloud sql instances execute-sql*": "ask"` |

(`sql connect` is interactive — Agent beta's domain; already listed in the plan's INTERACTIVE section.)

### storage

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| storage | `storage ls` | data-mixed | Lists (and by default `-L` can fetch metadata per object, but object names are treated as data). | `"gcloud storage ls*": "ask"` |
| storage | `storage cat` | data-read | Streams object bytes to stdout. | `"gcloud storage cat*": "ask"` |
| storage | `storage cp` | data-mixed | Copies object bytes. | `"gcloud storage cp*": "ask"` |
| storage | `storage mv` | data-mixed | Moves object bytes. | `"gcloud storage mv*": "ask"` |
| storage | `storage rm` | data-write | Deletes objects (data destruction). | `"gcloud storage rm*": "ask"` |
| storage | `storage du` | data-read | Reads per-object sizes (enumerates object-level data). | `"gcloud storage du*": "ask"` |
| storage | `storage rsync` | data-mixed | Bidirectional sync of object bytes. | `"gcloud storage rsync*": "ask"` |
| storage | `storage hash` | data-read | Computes hash of local file or object bytes. | `"gcloud storage hash*": "ask"` |
| storage | `storage sign-url` | data-write | Issues a credential granting direct object access. | `"gcloud storage sign-url*": "ask"` |
| storage | `storage restore` | data-write | Restores soft-deleted objects. | `"gcloud storage restore*": "ask"` |
| storage | `storage objects compose` | data-write | Concatenates object bytes into a new object. | `"gcloud storage objects compose*": "ask"` |
| storage | `storage objects describe` | data-read | Reveals per-object metadata (treated as data-plane per the plan). | `"gcloud storage objects describe*": "ask"` |
| storage | `storage objects list` | data-read | Enumerates objects in a bucket (treated as data-plane per the plan). | `"gcloud storage objects list*": "ask"` |
| storage | `storage objects update` | data-write | Updates per-object metadata (treated as data-plane). | `"gcloud storage objects update*": "ask"` |
| storage | `storage managed-folders create` / `delete` / `describe` / `list` | data-mixed | Treated as data-plane per the plan's short-list (object-level storage ops). | `"gcloud storage managed-folders *": "ask"` |
| storage | `storage folders create` / `delete` / `describe` / `list` | data-mixed | Same rationale as managed-folders — object/path-level operations. Uncertain — recommend ask. | `"gcloud storage folders *": "ask"` |
| storage | `storage batch-operations jobs create` | data-write | Creates a batch job that modifies many objects' data or metadata. | `"gcloud storage batch-operations jobs create*": "ask"` |
| storage | `storage batch-operations jobs cancel` | data-write | Cancels an in-progress batch data operation. | `"gcloud storage batch-operations jobs cancel*": "ask"` |

### transfer

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| transfer | `transfer jobs run` | data-mixed | Triggers a transfer run that moves bytes between sources. | `"gcloud transfer jobs run*": "ask"` |
| transfer | `transfer jobs create` | data-mixed | Creates a transfer job definition (data-movement config; borderline metadata). Uncertain — recommend ask. | `"gcloud transfer jobs create*": "ask"` |

### vector-search

| Service | Subcommand | Kind | Why it's data-plane | Proposed pattern |
|---|---|---|---|---|
| vector-search | `vector-search collections data-objects aggregate` | data-read | Aggregates over user data objects. | `"gcloud vector-search collections data-objects aggregate*": "ask"` |
| vector-search | `vector-search collections data-objects batch-create` | data-write | Bulk inserts data objects. | `"gcloud vector-search collections data-objects batch-create*": "ask"` |
| vector-search | `vector-search collections data-objects batch-delete` | data-write | Bulk deletes data objects. | `"gcloud vector-search collections data-objects batch-delete*": "ask"` |
| vector-search | `vector-search collections data-objects batch-search` | data-read | Bulk searches user data objects. | `"gcloud vector-search collections data-objects batch-search*": "ask"` |
| vector-search | `vector-search collections data-objects batch-update` | data-write | Bulk updates data objects. | `"gcloud vector-search collections data-objects batch-update*": "ask"` |
| vector-search | `vector-search collections data-objects create` | data-write | Creates a single data object. | `"gcloud vector-search collections data-objects create*": "ask"` |
| vector-search | `vector-search collections data-objects delete` | data-write | Deletes a single data object. | `"gcloud vector-search collections data-objects delete*": "ask"` |
| vector-search | `vector-search collections data-objects describe` | data-read | Returns the contents of a single data object. | `"gcloud vector-search collections data-objects describe*": "ask"` |
| vector-search | `vector-search collections data-objects query` | data-read | Runs a query over data objects. | `"gcloud vector-search collections data-objects query*": "ask"` |
| vector-search | `vector-search collections data-objects search` | data-read | Searches data objects (vector similarity). | `"gcloud vector-search collections data-objects search*": "ask"` |
| vector-search | `vector-search collections data-objects update` | data-write | Updates a single data object. | `"gcloud vector-search collections data-objects update*": "ask"` |
| vector-search | `vector-search collections export-data-objects` | data-read | Exports the full data-object set. | `"gcloud vector-search collections export-data-objects*": "ask"` |
| vector-search | `vector-search collections import-data-objects` | data-write | Imports a data-object set. | `"gcloud vector-search collections import-data-objects*": "ask"` |

A single pattern `"gcloud vector-search collections data-objects *": "ask"` plus `"gcloud vector-search collections *-data-objects*": "ask"` covers all of these.

---

## Services with NO data-plane commands (metadata only)

Audited and cleared (no data-plane subcommand surfaced that isn't already in the matrix above or out of scope):

access-approval, access-context-manager, active-directory, anthos, api-gateway, apigee (apps/products are developer-facing metadata), apihub, apphub, assured, audit-manager, auth (auth token prints are covered by the plan's auth section, not data-plane), batch, beyondcorp, biglake (iceberg catalogs/namespaces are catalog metadata), billing, bms, bq (only migration-workflows leaves — metadata), certificate-manager, cheat-sheet, cloudlocationfinder, cloud-shell (ssh/scp are interactive, not data per the distinction), colab (runtime/session metadata only — kernel I/O happens inside the runtime, not via gcloud), compliance-manager, components, config, container (note: `get-credentials` is credential-plane, not data-plane; handled by Agent beta), data-catalog (entries/tags/taxonomies are catalog metadata; `export`/`import` of taxonomies is metadata), database-migration (job orchestration metadata; `objects list/lookup` is metadata about source objects), datastream (objects are change-stream object metadata, not row payloads), deploy (pipelines/releases/targets export/import are config YAML), deployment-manager, design-center, dns (record-sets export/import is zone metadata), docker, domains, edge-cache (config YAML export/import), edge-cloud, endpoints, essential-contacts, feedback, filestore, firebase, gemini (settings only), help, ids, identity, init, managed-kafka (cluster metadata only — message I/O goes via Kafka API, not gcloud), migration (image-imports are VM migration metadata), monitoring, network-connectivity, network-management, network-security (config YAML export/import), network-services (config YAML export/import), notebooks, observability, oracle-database, org-policies, organizations, pam, parametermanager, preview, privateca (certificate export is public cert data; borderline but treated as public metadata), projects, publicca, recaptcha, recommender, resource-manager, scheduler, service-directory, service-extensions (config YAML import), services, source / source-manager (repo metadata; `source repos clone` is interactive and handled by Agent beta), survey, tasks (`tasks buffer` is debatable — see uncertainty note below), telco-automation, topic, transcoder (media-transcoder job metadata only), version, vmware, workflows (config + orchestration; execution payloads pass through but `workflows execute` is covered by the plan's execute/run defaults), workspace-add-ons, workstations (workstation SSH is handled by Agent beta, not data), info, feedback, cheat-sheet, emulators (start is interactive).

### Services with residual uncertainty (flagged for human judgement)

- **tasks** — `tasks buffer`, `tasks create-app-engine-task`, `tasks create-http-task`, `tasks run`: each takes a user-supplied task body (HTTP body or App Engine payload) and enqueues/executes it. Arguably data-write (message payload). The stable allowlist pattern `*: ask` fall-through covers them via `create`/`run` defaults, but explicit pattern asks are safer. Recommend treating as data-plane.
- **workflows** — `workflows execute` / `workflows run`: these accept a user-supplied JSON input and start an execution. Arguably data-mixed. Covered by the mutating-verb fall-through but callers may want an explicit pattern.
- **dataflow** — `dataflow flex-template run`, `dataflow jobs run`, `dataflow yaml run`: start a pipeline that processes user data, but the gcloud call itself only submits job parameters (metadata). Treating as metadata is defensible; flagging because the pipeline operates on user data even though the CLI is orchestration.
- **dataproc** — `dataproc jobs submit *`, `dataproc batches submit *`: submit a job that processes user data; the CLI itself transmits only job-config metadata. Same judgement call as dataflow.
- **datastream** — `datastream objects start-backfill` / `stop-backfill`: trigger a CDC backfill that moves row data; CLI only carries object-identifier metadata.
- **composer** — `composer environments run`: executes an Airflow CLI subcommand inside the environment (may print DAG state / task logs = data). Borderline interactive/data.
- **backup-dr** — `backup-dr backup-plan-associations trigger-backup`: creates backup payload; treated as mutating metadata since the CLI carries only the trigger, not the data.
- **privateca** — `privateca certificates export`: public certificate material; treated as public metadata.
- **functions** — `functions detach`: no data flow. OK.

None of these uncertainties change the blanket `*: ask` default — they only affect whether an explicit pattern is added to make the intent visible.

---

## Diff vs. starting draft

Additions proposed beyond the draft's data-plane short-list, each with one line of evidence:

1. `gcloud ai endpoints raw-predict*` — present in 564.0.0 leaves alongside `predict`; same data-plane role.
2. `gcloud ai endpoints direct-predict*`, `direct-raw-predict*`, `stream-direct-predict*`, `stream-direct-raw-predict*`, `stream-raw-predict*` — all variant prediction paths in the enumeration, same risk profile.
3. `gcloud ai endpoints explain*` — returns predictions + attributions, data-plane.
4. `gcloud ai-platform local predict*` — local prediction variant that loads user instance payloads.
5. `gcloud ai-platform jobs submit prediction*` — batch-prediction job submission over user data in GCS.
6. `gcloud alloydb clusters export/import*` — database content import/export not in the draft.
7. `gcloud app logs read/tail*` — reads GAE application log entries.
8. `gcloud artifacts attachments|files|generic download*` + `generic|apt|yum|go upload*` + `apt|yum import*` + `sbom load/export*` + `vulnerabilities load-vex*` — all move user artifact bytes.
9. `gcloud asset export|query|get-history*` — user-inventory content and user-SQL-query results.
10. `gcloud backup-dr backups restore compute|disk*` — restores backup payload.
11. `gcloud bigtable backups copy*`, `bigtable instances tables restore*`, `bigtable tables restore*` — row-data restore and cross-cluster backup copy.
12. `gcloud builds log*` — streams build logs (user-generated content). Uncertain.
13. `gcloud composer environments storage (dags|data|plugins) export/import*` + `snapshots load*` — move DAG source, data files, and snapshot bytes.
14. `gcloud compute copy-files*`, `compute diagnose export-logs*`, `compute images export/import*`, `compute machine-images import*`, `compute instances import*`, `compute instances get-serial-port-output*`, `compute instances get-screenshot*`, `compute instances tail-serial-port-output*`, `compute routers download-route-policy*`/`upload-route-policy*`, `compute sign-url*` — VM image bytes, serial console bytes, screenshots, signed URLs.
15. `gcloud datastore export/import*` — already in the plan's data-plane list; moved into explicit matrix form.
16. `gcloud developer-connect connections git-repository-links fetch-read-token*` / `fetch-read-write-token*` — mints credential tokens giving access to user code content.
17. `gcloud eventarc message-buses publish*` — publishes user CloudEvent payloads.
18. `gcloud firestore bulk-delete*` — deletes user documents (data-write beyond export/import).
19. `gcloud functions call*` — invokes function with user payload and returns response.
20. `gcloud functions logs read*` — reads function logs.
21. `gcloud healthcare datasets|dicom-stores|fhir-stores|hl7v2-stores (export|import)*` — all PHI-handling exports/imports (more specific than the draft's "healthcare" gap).
22. `gcloud healthcare datasets deidentify*`, `dicom-stores deidentify*`, `fhir-stores deidentify*` — read PHI and write de-identified output.
23. `gcloud healthcare consent-stores check-data-access*`, `query-accessible-data*`, `evaluate-user-consents*` — inspect/enforce PHI access.
24. `gcloud iam service-accounts sign-blob*`, `sign-jwt*` — sign user-supplied data with a service-account key.
25. `gcloud infra-manager deployments export-statefile|import-statefile|export-lock*`, `revisions export-statefile*` — Terraform state (may include secrets).
26. `gcloud kms decapsulate*` — PQC KEM decapsulation (ciphertext → shared secret).
27. `gcloud kms keys versions import*` — imports externally-held key material.
28. `gcloud logging copy*` — copies log entries between buckets (data-mixed, not in draft).
29. `gcloud looker instances export/import*` — instance state including user dashboards and LookML.
30. `gcloud lustre instances export-data/import-data*` — filesystem bytes.
31. `gcloud memorystore backup-collections backups export*` — Memorystore backup bytes.
32. `gcloud metastore services export/import/query-metadata*` — Hive metadata (schema of user data).
33. `gcloud model-armor templates sanitize-user-prompt/sanitize-model-response*` — processes user prompt / model output through a safety filter.
34. `gcloud netapp kms-configs encrypt/verify*` — NetApp-level crypto ops over user data.
35. `gcloud netapp volumes restore-backup-files*` — file-level backup restore.
36. `gcloud policy-intelligence query-activity*` — queries user-activity logs.
37. `gcloud pubsub subscriptions ack*` — acknowledges messages (touches per-message state).
38. `gcloud pubsub lite-topics publish*`, `lite-subscriptions ack-up-to*` — Pub/Sub Lite variants.
39. `gcloud pubsub message-transforms test*`, `schemas validate-message*` — process user messages.
40. `gcloud redis instances export/import*`, `clusters backups export*` — Redis data bytes.
41. `gcloud run services logs read*`, `run jobs logs read*` — Cloud Run logs.
42. `gcloud scc findings export-to-bigquery*` — streams findings content to BigQuery. Uncertain.
43. `gcloud spanner rows insert/update/delete*`, `spanner cli*` — row-level data writes and interactive SQL shell.
44. `gcloud sql instances execute-sql*` — new execute-sql leaf (not in draft).
45. `gcloud sql instances export/import*` — legacy flat verbs alongside new `sql export/import *`.
46. `gcloud storage folders (create|delete|describe|list)*` — path/folder-level operations, mirroring managed-folders. Uncertain.
47. `gcloud storage batch-operations jobs create/cancel*` — batch data jobs over many objects.
48. `gcloud transfer jobs create*` — creates a transfer job definition. Uncertain (borderline metadata).
49. `gcloud vector-search collections data-objects *` (all 11 leaves) and `collections export-data-objects*`/`import-data-objects*` — entire data-plane for Vertex Vector Search, not in the draft.

### Confirmations of the starting draft (no change)

- `storage ls|cp|mv|rm|cat|du|rsync|sign-url|hash` + `storage objects *` + `storage managed-folders create|delete|update`: all present, confirmed.
- `storage restore*`: present in stable leaves; included.
- `secrets versions access`: present; no siblings to add.
- `logging read|tail|write`: present; `logging copy` added.
- `pubsub subscriptions pull`, `pubsub topics publish`: confirmed.
- `kms encrypt|decrypt|raw-*|asymmetric-decrypt|asymmetric-sign|mac-sign|mac-verify`: confirmed. Draft's `asymmetric-verify` and `asymmetric-encrypt` do NOT appear in 564.0.0 stable leaves — they are alpha-only. Keep patterns for forward-compat; they'll be no-ops in 564.0.0.
- `spanner databases execute-sql`: confirmed. Draft's `spanner databases sessions execute-sql` does NOT appear in 564.0.0 stable leaves (only `sessions delete|list`). Keep the pattern for defence-in-depth.
- `firestore|datastore export|import`: confirmed.
- `transfer jobs run`: confirmed.
- `ai endpoints predict`, `ai-platform predict`, `ml * *`: confirmed and expanded above.

# Webhooks

Redmine can send webhooks whenever issues or wiki pages change. A webhook delivers
an HTTP POST request to an external service with a JSON payload that describes
the event.

## Enabling webhooks
1. Go to **Administration → Settings → API** and enable **Enable webhooks**.
2. Ensure background jobs are running so delivery jobs can be processed.
   Webhook deliveries are enqueued as Active Job jobs, so they need a queue
   runner:
   - **Default (development/test)**: Rails uses the `:async` adapter, which
     runs jobs in background threads inside the Redmine process. No extra
     setup is required, but jobs stop if the process stops.
   - **Production**: Configure a persistent queue adapter (for example
     `:delayed_job` or `:sidekiq`) and run a worker process. With
     `:delayed_job`, start a worker using `bundle exec rake jobs:work` and
     supervise it via systemd, a service manager, or a cron-launched wrapper
     so it restarts if it exits. With Sidekiq, run the Sidekiq process and
     point it at the same Redis instance you configured for Active Job. Remember
     to restart Sidekiq after patching the code!

## Permissions
Only users with the **Use webhooks** permission can create webhooks. The current
implementation grants this permission to project members. Each webhook also
respects the visibility of projects and issues for the webhook owner when
selecting projects and when delivering events.

## Creating a webhook
1. Open **My account → Webhooks**.
2. Click **New webhook**, then fill in the URL, optional secret, events,
   projects, and (for issue events) **trackers**.
3. Save the webhook. Active webhooks will enqueue a delivery job for each
   matching event.

### Tracker filters for issue events
- Trackers determine which issues will trigger `issue.*` events. If you select
  any issue events, you must pick at least one tracker; issues using other
  trackers are skipped.
- Choose only the trackers you care about to reduce traffic. When your project
  list changes, the tracker list automatically narrows to the trackers used by
  the projects you can select.

### Secrets and signatures
If you set a secret, Redmine includes an `X-Redmine-Signature-256` header. It is
an HMAC SHA-256 signature of the request body using the provided secret.

## Events and payload
Supported events:
- `issue.created`, `issue.updated`, `issue.closed`, `issue.deleted`
- `wiki_page.created`, `wiki_page.updated`, `wiki_page.deleted`

### When does a webhook fire?
- The event is enqueued after the database transaction commits (so failed
  saves do not send anything).
- The webhook must be **active** and belong to a **user who is still active**.
- The webhook’s user must have the **Use webhooks** permission on the project.
- The issue or wiki page must be **visible to the webhook owner**; if the owner
  cannot see the record, the event is skipped.
- For issue events, the issue’s **tracker must be selected** on the webhook.
- `issue.closed` fires only when an issue changes from a non-closed status to a
  closed status.
- Events are triggered regardless of which user performs the change. For
  example, if Alice owns a webhook for Project A, and Bob updates or deletes an
  issue in Project A, Alice’s webhook will still fire as long as she can see
  the issue and has permission on that project.

The request body is a JSON object with:
- `type`: the event name, for example `issue.updated`
- `timestamp`: ISO8601 timestamp of the event
- `data`: object with the payload

Issue payloads include the Redmine API representation of the issue, and for
updates they also include the last journal entry with visible details for the
webhook owner.

Wiki payloads include the page and, for updates, the version number.

## Safety checks
Webhook endpoints must use HTTP(S) and cannot target loopback, link-local, or
private addresses unless they are explicitly allowlisted. You can further
restrict or block destinations:

- **Blocklist** (`webhook_blocklist` in `config/configuration.yml`): a list of
  hostnames (exact or `*.example.com` wildcards) or IP/CIDR entries that are
  rejected. This is useful to prevent callbacks to internal hosts.
- **Allowlist** (`webhook_allowlist` in `config/configuration.yml`): if set,
  only hostnames or IPs/CIDRs that match the list are accepted. A hostname
  entry covers all IPs it resolves to (including private ranges if you choose
  to allow them). Both lists use the same syntax, for example:

  ```yaml
  production:
    webhook_allowlist:
      - hooks.example.com        # exact host
      - "*.hooks.example.org"   # wildcard host
      - 203.0.113.0/24           # CIDR range
      - 10.254.80.0/24           # allow a private range (use with care)
    webhook_blocklist:
      - 10.0.0.0/8
      - intranet.example.com
  ```

Leading and trailing whitespace around entries is ignored. If no allowlist is
defined, any public host passes unless blocked or private.

Endpoints are validated when saved and again before delivery. The validation
error includes the reason (for example, blocked host, outside allowlist, or
private address). A failed delivery logs the error but does not raise to users.

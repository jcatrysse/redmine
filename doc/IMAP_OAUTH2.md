# IMAP inbound mail over OAuth 2.0

Setting up a mailbox that Redmine reads with `redmine:email:receive_imap` when
the provider no longer accepts a password. Microsoft 365 and Gmail both stopped
accepting one for IMAP, so this is the only way left to fetch mail from either.

This file is specific to this installation. Upstream Redmine keeps provider
walk-throughs on the `EmailConfiguration` wiki page rather than in `doc/`, which
is why the two rake task descriptions point there; the same text is in
`docs/features/imap-oauth/dossier.md` on the `geoxyz/framework` branch, ready to
be pasted onto that wiki page once the patch is accepted. Change both together.

Both providers follow the same three steps: register an application, write a
credentials file, run `redmine:email:oauth2_authorize` once.

**The browser part is not a stunt, and it works on a server with no browser.**
The task prints a URL. Open it on your own laptop, sign in as the mailbox
owner, approve. The provider then redirects your browser to
`http://localhost`, which shows "This site can't be reached" - that is
expected and it is the whole point: the address bar now holds
`http://localhost/?code=0.AXoA...`. Copy that entire address and paste it back
into the terminal. Nothing has to be reachable, nothing listens on that port,
and the redirect happens in your browser and not on the server.

## Microsoft 365 / Exchange Online

1. Microsoft Entra admin center, **App registrations**, **New registration**.
   Name it something recognisable, keep "Accounts in this organizational
   directory only", and add a redirect URI of platform **Web** with the value
   `http://localhost`. Under the Web platform, `http://localhost` is the one
   address allowed without https.
2. Note the **Application (client) ID** and the **Directory (tenant) ID** from
   the overview page.
3. **Certificates & secrets**, **New client secret**. Copy the value now; it is
   shown once.
4. **API permissions**, **Add a permission**, **APIs my organization uses**,
   search for *Office 365 Exchange Online*, **Delegated permissions**, tick
   `IMAP.AccessAsUser.All`. Add it, and grant admin consent if your tenant
   requires it.
5. Make sure IMAP is on for the mailbox. In Exchange Online PowerShell:
   `Set-CASMailbox -Identity mailbox@example.com -ImapEnabled $true`

Credentials file, `/etc/redmine/imap_oauth2.yml`:

```yaml
authorize_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/authorize
token_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token
client_id: APPLICATION_CLIENT_ID
client_secret: CLIENT_SECRET_VALUE
scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
redirect_uri: http://localhost
```

`offline_access` in the scope is what makes Microsoft hand back a refresh
token. Without it the authorize task ends with "returned no refresh token".

Then:

```
rake redmine:email:oauth2_authorize RAILS_ENV=production \
  oauth2_credentials=/etc/redmine/imap_oauth2.yml
```

Add the `refresh_token:` line it prints to the same file, and fetch mail with:

```
rake redmine:email:receive_imap RAILS_ENV=production \
  host=outlook.office365.com port=993 ssl=1 \
  username=mailbox@example.com \
  oauth2_credentials=/etc/redmine/imap_oauth2.yml \
  project=support
```

## Gmail and Google Workspace

1. Google Cloud console, create or pick a project, and **enable the Gmail API**
   for it.
2. **OAuth consent screen**: choose *Internal* for a Workspace domain. For a
   personal Gmail account only *External* is available, and an External app
   left in *Testing* has its refresh tokens expire after seven days - publish
   the app, or expect to re-authorize weekly.
3. **Credentials**, **Create credentials**, **OAuth client ID**, application
   type **Desktop app**. Note the client ID and client secret. A Desktop app
   client is the one that accepts a `http://localhost` redirect.
4. Enable IMAP in the mailbox itself: Gmail settings, *Forwarding and POP/IMAP*,
   *Enable IMAP*.

Credentials file:

```yaml
authorize_url: https://accounts.google.com/o/oauth2/v2/auth
token_url: https://oauth2.googleapis.com/token
client_id: SOMETHING.apps.googleusercontent.com
client_secret: CLIENT_SECRET
scope: https://mail.google.com/
redirect_uri: http://localhost
authorize_params:
  access_type: offline
  prompt: consent
```

Google's equivalent of `offline_access` is `access_type: offline`, and it only
returns a refresh token on the *first* consent, so `prompt: consent` keeps it
working when you re-authorize. Those two are exactly why `authorize_params`
exists: the provider's quirks live in the administrator's file, not in
Redmine's code.

Then the same two commands, with `host=imap.gmail.com port=993 ssl=1`.

## Afterwards

- The file holds a client secret and a refresh token. Give it to the Redmine
  user only: `chown redmine: /etc/redmine/imap_oauth2.yml && chmod 600` it.
- `oauth2_authorize` printed the refresh token to your terminal. Clear the
  scrollback and the shell history of that session, and delete any transcript
  of it, once the line is in the file.
- A refresh token is long lived but not eternal. It stops working if it is
  revoked, if the account's password policy forces it, or in the Google
  *Testing* case above. Re-run `oauth2_authorize` and replace the line; nothing
  else changes.
- `receive_imap` says which of the two it is:
  `invalid_grant` means the refresh token is no longer accepted, `invalid_client`
  means the client id or secret is wrong.

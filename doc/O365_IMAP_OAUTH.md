# Office 365 IMAP OAuth2 Setup

This guide explains how to authorize Redmine to access an Office 365 mailbox via IMAP using OAuth2.

## Register an Azure application
1. Sign in at [portal.azure.com](https://portal.azure.com/).
2. Create a **New registration** allowing any account type.
3. On the initial form, use `http://localhost/` as the redirect URI.
4. Under **Authentication**, choose **Mobile and desktop**, keep the same redirect URI and enable **public client**.
5. Under **API permissions**, add:
   - `offline_access`
   - `User.Read`
   - `IMAP.AccessAsUser.All`
   - `POP.AccessAsUser.All`
   - `SMTP.Send`
6. Note the **Application (client) ID** and **Directory (tenant) ID**.
7. If creating a private app, generate a **client secret**; public apps can omit this.

## Initializing the token
Run the rake task interactively to obtain the refresh token:

```sh
rake redmine:email:o365_oauth2_init token_file=/app/redmine/config/email_oauth2_mytokenname \
  client=CLIENT_ID tenant=TENANT_ID secret=CLIENT_SECRET
```

Tokens are stored in `config/email_oauth2_mytokenname.yml` and `config/email_oauth2_mytokenname_client.yml`.

## Receiving mail
Use the OAuth token instead of a password when fetching messages:

```sh
rake redmine:email:receive_imap_oauth2 token_file=/app/redmine/config/email_oauth2_mytokenname \
  host=HOST username=EMAIL
```
Other parameters match those of `redmine:email:receive_imap`.

SSL/TLS is enabled by default. Pass `ssl=0` to disable it and, if desired,
enable explicit TLS with `starttls=1`. The `starttls` option is ignored when
`ssl` is enabled.

## Revoking access
To revoke the grant and start over, remove the application from [Microsoft account permissions](https://myaccount.microsoft.com/consents) and delete the token files before re-running the initialization task.

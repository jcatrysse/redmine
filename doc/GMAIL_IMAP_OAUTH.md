# Gmail IMAP OAuth2 Setup

This guide explains how to authorize Redmine to access a Gmail mailbox via IMAP using OAuth2.

## Enable IMAP in Gmail
1. Open Gmail and go to **Settings** → **See all settings**.
2. Under **Forwarding and POP/IMAP**, enable **IMAP access**.

## Configure the OAuth consent screen
1. Visit [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Open **APIs & Services** → **OAuth consent screen** and complete the configuration.

## Create an OAuth client
1. In **APIs & Services** → **Credentials**, create a new **OAuth client ID** of type **Desktop app**.
2. Note the generated **Client ID** and **Client Secret**.

## Required scope
The rake task requests the following scope when authorizing:

```
https://mail.google.com/
```

## Obtaining the refresh token
Run the rake task and follow the instructions:

```
rake redmine:email:google_oauth2_init token_file=/app/redmine/config/email_oauth2_mytokenname client=CLIENT_ID secret=CLIENT_SECRET
```

After authorization, the task stores the access and refresh tokens in `config/email_oauth2_mytokenname.yml`.

## Receiving mail
Fetch messages with OAuth2 credentials instead of a password:

```sh
rake redmine:email:receive_imap_oauth2 token_file=/app/redmine/config/email_oauth2_mytokenname \
  host=HOST username=EMAIL
```
The task accepts the `ssl` and `starttls` environment variables. SSL/TLS is
enabled by default; set `ssl=0` to disable it. When SSL is disabled you can
enable STARTTLS with `starttls=1` (the option is ignored if `ssl` is enabled).

## Revoking consent
To revoke the authorization and obtain a new refresh token:
1. Visit [Google Account Permissions](https://myaccount.google.com/permissions).
2. Remove the application from **Third-party apps with account access**.
3. Run the rake task again.

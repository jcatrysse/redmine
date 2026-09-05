// G9 for ldap-mail-prefs. Run it three times against a live instance, with the
// rake task in between; SHOT_PREFIX names which pass this is.
//
//   SHOT_PREFIX=before node verify/ldap-mail-prefs.mjs
//   ... rake redmine:users:set_ldap_notification_defaults ... apply=1
//   SHOT_PREFIX=after  node verify/ldap-mail-prefs.mjs
//   ... rake redmine:users:undo_ldap_notification_defaults ... apply=1
//   SHOT_PREFIX=undone node verify/ldap-mail-prefs.mjs
//
// LDAP_USER_ID is an account with an authentication source, LOCAL_USER_ID one
// without: the second is the control that must never change.
import { session, report } from '../tools/verify-lib.mjs';

const s = await session(process.env.SHOT_DIR || '/tmp');
const prefix = process.env.SHOT_PREFIX || 'after';
const ldap = process.env.LDAP_USER_ID || '5';
const local = process.env.LOCAL_USER_ID || '1';

// The three preferences the task writes all live on the user's own edit form.
async function settings(id) {
  await s.go(`/users/${id}/edit`);
  return s.page.evaluate(() => ({
    mail_notification: document.querySelector('#user_mail_notification')?.value,
    no_self_notified: document.querySelector('#pref_no_self_notified')?.checked,
    auto_watch_on: [...document.querySelectorAll('input[name="pref[auto_watch_on][]"]')]
      .filter(i => i.checked).map(i => i.value)
  }));
}

console.log(`${prefix}  ldap user ${ldap}:`, await settings(ldap));
await s.shot(`${prefix}-ldap-account`,
             `An LDAP account's notification settings, ${prefix} the run`);

console.log(`${prefix}  local user ${local}:`, await settings(local));
await s.shot(`${prefix}-local-account`,
             `A local account is not selected and does not change, ${prefix} the run`);

report(s.shots);
await s.browser.close();

/* GEOxyz Material theme: Jira-style left sidebar navigation.
 *
 * Only rearranges menus that Redmine already renders, so permissions and
 * plugin menu entries are respected. The project menu (#main-menu) is moved
 * into the sidebar; responsive.js still finds it by id for the mobile flyout.
 * The general links are copied, not moved, because responsive.js expects them
 * inside #top-menu. Below 900px the sidebar is hidden by CSS and Redmine's own
 * mobile menu takes over. If an expected element is missing, nothing changes.
 */
(function () {
  'use strict';

  var STORAGE_KEY = 'material-sidenav-collapsed';

  function el(tag, attrs, text) {
    var node = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (key) { node.setAttribute(key, attrs[key]); });
    if (text) node.textContent = text;
    return node;
  }

  function section(title) {
    var wrap = el('div', { 'class': 'm-sidenav__section' });
    if (title) wrap.appendChild(el('div', { 'class': 'm-sidenav__title' }, title));
    return wrap;
  }

  function readCollapsed() {
    try { return window.localStorage.getItem(STORAGE_KEY) === '1'; } catch (e) { return false; }
  }

  function writeCollapsed(value) {
    try { window.localStorage.setItem(STORAGE_KEY, value ? '1' : '0'); } catch (e) { /* storage unavailable */ }
  }

  function markCurrent(list) {
    var here = window.location.pathname;
    list.querySelectorAll('a[href]').forEach(function (link) {
      var path = link.getAttribute('href').split('?')[0];
      if (path && path !== '/' && here === path) {
        link.classList.add('m-current');
      }
    });
  }

  function build() {
    var wrapper = document.getElementById('wrapper');
    var topMenu = document.getElementById('top-menu');
    if (!wrapper || !topMenu || document.getElementById('m-sidenav')) return;

    var nav = el('nav', { id: 'm-sidenav', 'aria-label': 'Navigation' });

    var homeLink = topMenu.querySelector('.general-menu a.home');
    var brand = el('a', { 'class': 'm-sidenav__brand', href: homeLink ? homeLink.getAttribute('href') : '/' },
      document.title.split(' - ').pop() || 'Redmine');
    nav.appendChild(brand);

    var general = topMenu.querySelector('.general-menu .top-menu__links > ul');
    if (general) {
      var generalSection = section('');
      var copy = general.cloneNode(true);
      copy.removeAttribute('id');
      markCurrent(copy);
      generalSection.appendChild(copy);
      nav.appendChild(generalSection);
    }

    var mainMenu = document.getElementById('main-menu');
    var headerParent = mainMenu ? mainMenu.parentNode : null;
    var headerNext = mainMenu ? mainMenu.nextSibling : null;
    var projectSection = null;
    if (mainMenu) {
      var heading = document.querySelector('#header h1');
      var projectName = heading ? heading.textContent.trim().split('»').pop().trim() : '';
      projectSection = section(projectName || 'Project');
      projectSection.classList.add('m-sidenav__project');
      var newObject = mainMenu.querySelector('a.new-object');
      if (newObject && newObject.textContent.trim() === '+') newObject.textContent = '+ New';
      projectSection.appendChild(mainMenu);
      nav.appendChild(projectSection);
    }

    // Collapsed: the project menu goes back to the header as tabs, so it stays reachable.
    function placeProjectMenu(collapsed) {
      if (!mainMenu || !projectSection || !headerParent) return;
      if (collapsed) {
        headerParent.insertBefore(mainMenu, headerNext && headerNext.parentNode === headerParent ? headerNext : null);
      } else {
        projectSection.appendChild(mainMenu);
      }
      // let Redmine recalculate the tab scroll buttons for the new position
      if (window.jQuery) window.jQuery(window).trigger('resize');
    }

    var toggle = el('button', { type: 'button', 'class': 'm-sidenav__toggle', 'aria-label': 'Collapse sidebar', title: 'Collapse sidebar' });
    toggle.innerHTML = '&#x2039;';
    toggle.addEventListener('click', function () {
      var collapsed = !document.documentElement.classList.contains('m-sidenav-collapsed');
      document.documentElement.classList.toggle('m-sidenav-collapsed', collapsed);
      toggle.innerHTML = collapsed ? '&#x203A;' : '&#x2039;';
      toggle.setAttribute('title', collapsed ? 'Expand sidebar' : 'Collapse sidebar');
      placeProjectMenu(collapsed);
      writeCollapsed(collapsed);
    });

    wrapper.insertBefore(nav, wrapper.firstChild);
    document.body.appendChild(toggle);

    if (readCollapsed()) {
      document.documentElement.classList.add('m-sidenav-collapsed');
      toggle.innerHTML = '&#x203A;';
      toggle.setAttribute('title', 'Expand sidebar');
      placeProjectMenu(true);
    }
    document.documentElement.classList.add('m-has-sidenav');
  }

  /* Notification bell (Jira-style).
   *
   * Reads Redmine's own Atom feeds with the normal login session (the JSON API would need an
   * API key), so Redmine itself is not changed and its permissions apply (private notes stay hidden):
   * - the issue changes feed (/issues/changes): every note or field change on issues the user is
   *   assigned to, watches or reported;
   * - the issue feed (/issues.atom), which is dated by creation: new issues assigned to the user.
   * Changes and issues made by the user are left out. Read state lives in this browser
   * (localStorage), per user: opening the panel clears the badge, an item stays marked new until it
   * is opened or "Mark all as read" is used.
   */
  var BELL_REFRESH_MS = 5 * 60 * 1000;
  var BELL_FIRST_DAYS = 7;
  var BELL_MAX_ITEMS = 20;

  function bellUserId() {
    var link = document.querySelector('.flyout-menu__avatar a[href*="/users/"]');
    var match = link && link.getAttribute('href').match(/\/users\/(\d+)/);
    return match ? match[1] : null;
  }

  function bellRoot() {
    var home = document.querySelector('#top-menu a.home');
    var href = home ? home.getAttribute('href') : '/';
    return href.replace(/\/$/, '');
  }

  function bellFeeds(root) {
    var all = '?set_filter=1&f[]=status_id&op[status_id]=*';
    function mine(field) { return '&f[]=' + field + '&op[' + field + ']==&v[' + field + '][]=me'; }
    return [
      { kind: 'change', url: root + '/issues/changes' + all + mine('assigned_to_id') },
      { kind: 'change', url: root + '/issues/changes' + all + mine('watcher_id') },
      { kind: 'change', url: root + '/issues/changes' + all + mine('author_id') },
      { kind: 'created', url: root + '/issues.atom' + all + mine('assigned_to_id') +
        '&f[]=author_id&op[author_id]=!&v[author_id][]=me&sort=id:desc' }
    ];
  }

  function bellText(html, max) {
    // DOMParser, not innerHTML: a parsed document runs no scripts or image handlers
    var parsed = new DOMParser().parseFromString(html, 'text/html');
    // field changes (li) and the note (p) are separate blocks: keep them apart with " · "
    var parts = [];
    parsed.body.querySelectorAll('li, p').forEach(function (node) {
      var piece = (node.textContent || '').replace(/\s+/g, ' ').trim();
      if (piece) parts.push(piece);
    });
    var text = parts.length ? parts.join(' · ') : (parsed.body.textContent || '').replace(/\s+/g, ' ').trim();
    return text.length > max ? text.slice(0, max - 1) + '…' : text;
  }

  function bellLoadState(key) {
    var state = null;
    try { state = JSON.parse(window.localStorage.getItem(key)); } catch (e) { state = null; }
    if (!state || !state.seenAll) {
      state = { seenAll: new Date(Date.now() - BELL_FIRST_DAYS * 864e5).toISOString(), badgeSeen: null, read: {} };
    }
    state.read = state.read || {};
    return state;
  }

  function bellSaveState(key, state) {
    try { window.localStorage.setItem(key, JSON.stringify(state)); } catch (e) { /* storage unavailable */ }
  }

  // One item per change (or per new issue). Titles look like
  // "Project - Bug #3: subject" (changes) or "Project - Bug #3 (New): subject" (issues).
  function bellParse(xmlText, kind, myName) {
    var doc = new DOMParser().parseFromString(xmlText, 'application/xml');
    var items = [];
    doc.querySelectorAll('entry').forEach(function (entry) {
      var link = entry.querySelector('link');
      var href = link ? link.getAttribute('href') : '';
      var issueMatch = href.match(/\/issues\/(\d+)/);
      var entryId = (entry.querySelector('id') || {}).textContent || '';
      var journalMatch = entryId.match(/journal_id=(\d+)/);
      var title = (entry.querySelector('title') || {}).textContent || '';
      var parts = title.match(/^(.*) - (.+?) #(\d+)(?: \(.+?\))?: (.*)$/);
      var updated = (entry.querySelector('updated') || {}).textContent || '';
      var author = (entry.querySelector('author name') || {}).textContent || '';
      if (!issueMatch || !updated || (myName && author === myName)) return;
      var path = href.replace(/^https?:\/\/[^/]+/, '');
      var key = kind === 'change' && journalMatch ? 'j' + journalMatch[1] : 'i' + issueMatch[1];
      items.push({
        key: key,
        href: path, // open the issue at the top, like Jira (Ansif's choice, 2026-11-11)
        project: parts ? parts[1] : '',
        issue: parts ? parts[2] + ' #' + parts[3] + ': ' + parts[4] : title,
        author: author,
        what: kind === 'created' ? 'created this issue for you'
          : bellText((entry.querySelector('content') || {}).textContent || '', 90) || 'updated the issue',
        updated: new Date(updated).toISOString()
      });
    });
    return items;
  }

  function bellAgo(iso) {
    var minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
    if (minutes < 1) return 'just now';
    if (minutes < 60) return minutes + ' min ago';
    var hours = Math.round(minutes / 60);
    if (hours < 24) return hours + ' h ago';
    var days = Math.round(hours / 24);
    return days + (days === 1 ? ' day ago' : ' days ago');
  }

  function buildBell() {
    var userId = bellUserId();
    var profileMenu = document.querySelector('#top-menu .profile-menu');
    var header = document.getElementById('header');
    if (!userId || !profileMenu || !header || document.getElementById('m-bell')) return;

    var root = bellRoot();
    var storeKey = 'material-bell:' + userId;
    var state = bellLoadState(storeKey);
    var items = [];

    var wrap = el('div', { id: 'm-bell', 'class': 'm-bell' });
    var button = el('button', { type: 'button', 'class': 'm-bell__button', 'aria-haspopup': 'true', 'aria-expanded': 'false', title: 'Notifications' });
    button.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0"/></svg>';
    var badge = el('span', { 'class': 'm-bell__badge', hidden: 'hidden' });
    button.appendChild(badge);

    var panel = el('div', { 'class': 'm-bell__panel', role: 'dialog', 'aria-label': 'Notifications', hidden: 'hidden' });
    var head = el('div', { 'class': 'm-bell__head' });
    head.appendChild(el('span', { 'class': 'm-bell__title' }, 'Notifications'));
    var markAll = el('button', { type: 'button', 'class': 'm-bell__markall' }, 'Mark all as read');
    head.appendChild(markAll);
    var list = el('ul', { 'class': 'm-bell__list' });
    var foot = el('div', { 'class': 'm-bell__foot' },
      'Changes by others on issues you are assigned to, watch or reported, and new issues assigned to you. Read state is kept in this browser.');
    panel.appendChild(head);
    panel.appendChild(list);
    panel.appendChild(foot);
    wrap.appendChild(button);
    wrap.appendChild(panel);

    var myNameEl = document.querySelector('#account .user-info .user-name');
    var myName = myNameEl ? myNameEl.textContent.trim() : '';

    function isUnread(item) {
      return item.updated > state.seenAll && !state.read[item.key];
    }

    function render() {
      var unread = items.filter(isUnread);
      var fresh = unread.filter(function (item) { return !state.badgeSeen || item.updated > state.badgeSeen; });
      badge.textContent = fresh.length > 9 ? '9+' : String(fresh.length);
      if (fresh.length) badge.removeAttribute('hidden'); else badge.setAttribute('hidden', 'hidden');
      button.setAttribute('title', unread.length ? 'Notifications (' + unread.length + ' new)' : 'Notifications');
      markAll.disabled = unread.length === 0;

      list.textContent = '';
      if (!items.length) {
        list.appendChild(el('li', { 'class': 'm-bell__empty' }, 'Nothing new from others in your issues.'));
        return;
      }
      items.forEach(function (item) {
        var li = el('li', { 'class': 'm-bell__item' + (isUnread(item) ? ' is-unread' : '') });
        var link = el('a', { href: item.href, 'class': 'm-bell__link' });
        var who = el('span', { 'class': 'm-bell__who' });
        who.appendChild(el('strong', {}, item.author || 'Someone'));
        who.appendChild(document.createTextNode(' ' + (item.what === 'created this issue for you' ? item.what : 'updated')));
        link.appendChild(who);
        link.appendChild(el('span', { 'class': 'm-bell__subject' }, item.issue));
        if (item.what !== 'created this issue for you') {
          link.appendChild(el('span', { 'class': 'm-bell__snippet' }, item.what));
        }
        link.appendChild(el('span', { 'class': 'm-bell__meta' },
          [item.project, bellAgo(item.updated)].filter(Boolean).join(' · ')));
        link.addEventListener('click', function () {
          state.read[item.key] = true;
          bellSaveState(storeKey, state);
        });
        li.appendChild(link);
        list.appendChild(li);
      });
    }

    function load() {
      Promise.all(bellFeeds(root).map(function (feed) {
        return fetch(feed.url, { credentials: 'same-origin', headers: { Accept: 'application/atom+xml' } })
          .then(function (response) { return response.ok ? response.text() : ''; })
          .then(function (text) { return bellParse(text, feed.kind, myName); })
          .catch(function () { return []; });
      })).then(function (lists) {
        var byKey = {};
        lists.forEach(function (found) {
          found.forEach(function (item) { byKey[item.key] = item; });
        });
        items = Object.keys(byKey).map(function (key) { return byKey[key]; })
          .sort(function (a, b) { return a.updated < b.updated ? 1 : -1; })
          .slice(0, BELL_MAX_ITEMS);
        // forget read marks of items that dropped out of the list
        Object.keys(state.read).forEach(function (key) { if (!byKey[key]) delete state.read[key]; });
        bellSaveState(storeKey, state);
        render();
      });
    }

    function open(show) {
      if (show) {
        panel.removeAttribute('hidden');
        state.badgeSeen = new Date().toISOString();
        bellSaveState(storeKey, state);
        render();
      } else {
        panel.setAttribute('hidden', 'hidden');
      }
      button.setAttribute('aria-expanded', show ? 'true' : 'false');
    }

    button.addEventListener('click', function (event) {
      event.stopPropagation();
      open(panel.hasAttribute('hidden'));
    });
    markAll.addEventListener('click', function () {
      state.seenAll = new Date().toISOString();
      state.read = {};
      bellSaveState(storeKey, state);
      render();
    });
    document.addEventListener('click', function (event) {
      if (!wrap.contains(event.target)) open(false);
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && !panel.hasAttribute('hidden')) { open(false); button.focus(); }
    });

    // Top bar on wide screens (next to the avatar, like Jira); in the header on phones,
    // because Redmine hides the top bar below 900px.
    var narrow = window.matchMedia('(max-width: 899px)');
    function place() {
      if (narrow.matches) {
        header.appendChild(wrap);
      } else {
        profileMenu.insertBefore(wrap, profileMenu.firstChild);
      }
    }
    if (narrow.addEventListener) narrow.addEventListener('change', place); else narrow.addListener(place);
    place();

    load();
    window.setInterval(function () { if (!document.hidden) load(); }, BELL_REFRESH_MS);
    document.addEventListener('visibilitychange', function () { if (!document.hidden) load(); });
  }

  function start() {
    build();
    buildBell();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();

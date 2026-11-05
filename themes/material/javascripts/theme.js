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
    if (mainMenu) {
      var heading = document.querySelector('#header h1');
      var projectName = heading ? heading.textContent.trim().split('»').pop().trim() : '';
      var projectSection = section(projectName || 'Project');
      projectSection.classList.add('m-sidenav__project');
      var newObject = mainMenu.querySelector('a.new-object');
      if (newObject && newObject.textContent.trim() === '+') newObject.textContent = '+ New';
      projectSection.appendChild(mainMenu);
      nav.appendChild(projectSection);
    }

    var toggle = el('button', { type: 'button', 'class': 'm-sidenav__toggle', 'aria-label': 'Collapse sidebar', title: 'Collapse sidebar' });
    toggle.innerHTML = '&#x2039;';
    toggle.addEventListener('click', function () {
      var collapsed = !document.documentElement.classList.contains('m-sidenav-collapsed');
      document.documentElement.classList.toggle('m-sidenav-collapsed', collapsed);
      toggle.innerHTML = collapsed ? '&#x203A;' : '&#x2039;';
      toggle.setAttribute('title', collapsed ? 'Expand sidebar' : 'Collapse sidebar');
      writeCollapsed(collapsed);
    });

    wrapper.insertBefore(nav, wrapper.firstChild);
    document.body.appendChild(toggle);

    if (readCollapsed()) {
      document.documentElement.classList.add('m-sidenav-collapsed');
      toggle.innerHTML = '&#x203A;';
      toggle.setAttribute('title', 'Expand sidebar');
    }
    document.documentElement.classList.add('m-has-sidenav');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
})();

# patches/

One directory per feature slug, holding exactly what was attached to a
redmine.org issue:

    patches/<slug>/<date>-r<trunk-rev>-feature.patch    code + en.yml
    patches/<slug>/<date>-r<trunk-rev>-locales.patch    nl, fr, de, es

Committed so that later feedback can be diffed against what was actually
submitted. Generated with `git format-patch origin/master --stdout` from the
patch branch, and only after `tools/check-patch-clean.sh` passes.

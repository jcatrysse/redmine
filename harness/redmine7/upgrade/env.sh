# shared settings for the 5.1 -> 7.0 upgrade rehearsal
export S=/tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/upgrade
export U51=/home/user/r70h/upg51
export U70=/home/user/r70h/upg70
export LOGS=$S/logs
export RAILS_ENV=production
export PGPASSWORD=redmine
export PGHOST=127.0.0.1 PGUSER=redmine
mkdir -p "$LOGS"

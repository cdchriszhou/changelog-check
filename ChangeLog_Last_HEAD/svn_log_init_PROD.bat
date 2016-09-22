#svn propdel svn:sync-lock --revprop -r 0 file:///Z:/regulus_repos
#svnsync sync file:///Z:/regulus_repos

rm -rf ./export/*config.ini

perl svn_log_init_PROD.pl

mv ./export/*config.ini ./export/checklist_config.ini

rm -rf ./checklist_config.ini

cp ./export/checklist_config.ini ./

rm -rf ./dist/*

perl chk_svn_log.pl

mv ./dist/*NULL_JIRA_ChangeLog.csv ./dist/NULL_JIRA_ChangeLog_PROD.csv
mv ./dist/*JIRA_ChangeLog.csv ./dist/JIRA_ChangeLog_PROD.csv
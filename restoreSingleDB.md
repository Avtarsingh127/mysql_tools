<br />
Percona Xtrabackup does not have any direct way to import single database. I have found a script to restore single database written by <i>Phil Buescher</i>. I have made few changes in the script. There are few perquisite to run the script. You can download the script from <a href="https://github.com/Avtarsingh127/mysql_tools/blob/dev/restoreSingleDB.sh" target="_blank">here</a>.<br />
<br />
<br />
You need to use mysql-utility mysqlfrm to get the structure of the table from backup. But mysqlfrm works only for innodb tables.<br />
<br />
Prerequisite:<br />
&nbsp;&nbsp;&nbsp; 1. Table should be innodb engine.<br />
&nbsp;&nbsp;&nbsp; 2. innodb_file_per_table option should be enabled on the source server<br />
&nbsp;&nbsp;&nbsp; &nbsp;&nbsp; before taking the backup.<br />
&nbsp;&nbsp;&nbsp; 3. If you have any view inside your backup directory, script will fail. It will<br />
&nbsp;&nbsp;&nbsp; &nbsp;&nbsp; print the name of the file where it failed. You need to go inside backup directory and delete all the files related to those views.<br />
<br />
For restoring DB we need to have all the following backups. I am referring to the directory structure created by the <a href="https://github.com/Avtarsingh127/mysql_tools/blob/dev/backup.sh" target="_blank">script</a> I mentioned in my earlier <a href="https://db-gyaan.blogspot.com/2017/04/mysql-backup-with-incremental-levels.html" target="_blank">blog post</a>.<br />
&nbsp; <br />
1. Copy the full weekly database.<br />
2. Copy the daily database upto which day you want to restore.<br />
3. Inside daily database directory, you will find incr directory.<br />
4. Inside incr directory, you will have multiple backups, you can keep the<br />
folders upto what time you want to restore your backup.<br />
<br />
<br />

For more information you can check my <a href="https://db-gyaan.blogspot.com/2018/03/restore-single-database-from-full.html" target="_blank">blog post</a>.

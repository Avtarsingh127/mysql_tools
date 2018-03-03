<div class="separator" style="clear: both; text-align: center;">
</div>
<div style="margin-left: 1em; margin-right: 1em;">
</div>
<div style="margin-left: 1em; margin-right: 1em;">
<br />
The script is written to take backup of MySQL Database using Percona Xtrabackup. The innobackupex tool is a Perl script that acts as a wrapper for the xtrabackup C program. It allows us to take backup of Innodb without any locking and also takes backup of other engines like MyISAM with minimum locking. To read more about innobackupex, read the following links.</div>
<span style="background-color: white; color: #333333; font-family: &quot;open sans&quot; , sans-serif; font-size: 15px;"></span><br />
<a href="https://www.percona.com/doc/percona-xtrabackup/2.1/innobackupex/innobackupex_script.html">Innobackupex Script</a><br />
<a href="https://www.percona.com/doc/percona-xtrabackup/2.3/innobackupex/how_innobackupex_works.html">How Innobackupex Works?</a><br />
<br />
You can download full script&nbsp;<a href="https://github.com/Avtarsingh127/mysql_tools/blob/master/backup.sh">here</a>.<br />
<br />
Innobackupex provides 2 types of backups:-<br />
<ul>
<li><b>Full</b>: Which will take the full backup of the given database from start to end.</li>
<li><b>Incremental</b>: It will only take the backup of changed blocks since last base backup or LSN(Log Sequence Number).</li>
</ul>
<br />
The script will take setting from the variables defined and take backups accordingly. I have currently set it up as below.<br />
<br />
Every Sunday, it will take full backup of the DB provided. Every day at 0000 hours, it will take an incremental backup since last full backup (<a href="https://1.bp.blogspot.com/-HwfxjlF4hTk/WOT6vdqCcPI/AAAAAAAAByY/R1XNRF1CC_EE_qhE25n-IlbieUh1CHZwACLcB/s1600/daily%2Bbackup.001.jpeg">Figure 1</a>). It is going to take the backup&nbsp;since&nbsp;last full backup, so its size will be increasing every day.<br />
<br />
<br />
<div class="separator" style="clear: both; text-align: center;">
<a href="https://1.bp.blogspot.com/-HwfxjlF4hTk/WOT6vdqCcPI/AAAAAAAAByY/R1XNRF1CC_EE_qhE25n-IlbieUh1CHZwACLcB/s1600/daily%2Bbackup.001.jpeg" style="margin-left: 1em; margin-right: 1em;"><img border="0" height="256" src="https://1.bp.blogspot.com/-HwfxjlF4hTk/WOT6vdqCcPI/AAAAAAAAByY/R1XNRF1CC_EE_qhE25n-IlbieUh1CHZwACLcB/s400/daily%2Bbackup.001.jpeg" width="400" /></a></div>
<br />
<br />
<br />
<br />
&nbsp;If&nbsp;cron&nbsp;job is setup to run after every 3 hours, it will take the incremental backup since last incremental backup as shown in figure below (<a href="https://4.bp.blogspot.com/-I9dgm2LuLDs/WOT6vUXMdwI/AAAAAAAAByc/pyiEByktV_UabgIKXKSpya4RqrhOan2IwCLcB/s1600/daily%2Bbackup.002.jpeg">Figure 2</a>).<br />
<br />
<br />
<div class="separator" style="clear: both; text-align: center;">
<a href="https://4.bp.blogspot.com/-I9dgm2LuLDs/WOT6vUXMdwI/AAAAAAAAByc/pyiEByktV_UabgIKXKSpya4RqrhOan2IwCLcB/s1600/daily%2Bbackup.002.jpeg" style="margin-left: 1em; margin-right: 1em;"><img border="0" height="228" src="https://4.bp.blogspot.com/-I9dgm2LuLDs/WOT6vUXMdwI/AAAAAAAAByc/pyiEByktV_UabgIKXKSpya4RqrhOan2IwCLcB/s400/daily%2Bbackup.002.jpeg" width="400" /></a></div>
<div class="separator" style="clear: both; text-align: center;">
<br /></div>
<span style="font-size: large;">Precautions:</span><br />
<br />
<ul>
<li><span style="font-family: inherit;">Do not setup cron job to run this script more than once in an hour, otherwise it will take multiple full backups in one hour which is unnecessary.</span></li>
</ul>
<br />
<span style="font-size: large;">Assumptions:&nbsp;</span><br />
<br />
<ul>
<li>Operating System: Ubuntu 14.04</li>
<li>MySQL Version: 5.6+</li>
<li>Percona Xtrabackup (<a href="https://www.percona.com/doc/percona-xtrabackup/2.3/installation/apt_repo.html">Xtrabackup installation instructions</a>).</li>
</ul>
<br />
<br />

For understanding the script step by step, check my <a href="https://db-gyaan.blogspot.in/2017/04/mysql-backup-with-incremental-levels.html">Blog Post </a><br />. 

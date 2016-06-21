After script running
1. Setup Jenkins
2. Run jenkins-jobs
3. Add credentials to JENKINS_HOME DIR
4. Trigger "update config" job
5. Add key for zuul to /etc/zuul/gerrit
6. Start zuul
7. Add key for nodepool to /etc/nodepool/id_dsa
8. Add full permissions on nodepool key
9. Start nodepool
10. Enable apache2 sites (start from jenkins.conf file)

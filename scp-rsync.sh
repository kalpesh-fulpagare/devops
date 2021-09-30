# EMM
scp -P 911 ril-deployment.tar.gz deploy@10.130.31.113:/var/apps/downloads
rsync --progress -rt kalpesh@192.168.100.1:/home/kalpesh/projects/ /home/kalpesh/projects/ 
rsync --progress -rt --exclude 'abc.txt' kalpesh@192.168.100.1:/home/kalpesh/projects/ /home/kalpesh/projects/ 
rsync --progress -rt --exclude 'configurations' kalpesh@192.168.100.1:/home/kalpesh/projects/ /home/kalpesh/projects/ 
rsync -avzh -e 'ssh -p 911' --progress shared/vendor kalpesh@192.168.100.1:/var/www/demo-project/shared/

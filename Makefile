deploy:
	rm -f ltepi2-service.tgz && \
	tar --exclude=.git --exclude=ltepi2-service.tgz -zcf ltepi2-service.tgz . && \
	scp ./ltepi2-service.tgz pi@raspberrypi.local:~

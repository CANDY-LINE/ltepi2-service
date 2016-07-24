deploy:
	./install.sh pack && \
	scp ./ltepi2-service-*.tgz pi@raspberrypi.local:~

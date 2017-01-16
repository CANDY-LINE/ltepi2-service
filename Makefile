PI_HOST ?= raspberrypi.local 

deploy:
	./install.sh pack && \
	scp ./ltepi2-service-*.tgz pi@$(PI_HOST):~

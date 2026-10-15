CC = cc
NAME = world
OBJS = a.o b.o

all: hello vars
	@echo all done

hello:
	@echo hello $(NAME)

vars:
	@echo objs=$(OBJS) sub=$(OBJS:.o=.c) up=$(shell echo shell-ok)
	@echo words=$(words $(OBJS)) first=$(firstword $(OBJS)) patsubst=$(patsubst %.o,%.x,$(OBJS))

%.out: %.in
	@echo build $@ from $<
	@cp $< $@
	@cat $@
	@rm -f $@

multi:
	@echo one; \
	echo two
	@echo three | sed 's/three/3/'

fail:
	@false

.PHONY: all hello vars multi fail
